#!/bin/bash
# PATCH 280 - THE CHECKLIST ON EVERY MESSAGE + HOW FRESH THE FUTURES MONEY IS (Rama, 14 Nov: "in order for the shares to move up all should move together -
#   tell me what all 3 are - and when you give the alarm and the message you should mention that also").
#   · every 🌪 BIG MOVER, 🔄 TURN, 🎯 BOOK HALF, 🚪 EXIT now says, line by line:
#       THE 3 THAT MUST MOVE TOGETHER (n of 3): ✅/❌ the price (0.6%+ in 3 min) · ✅/❌ the futures money (NEW money its way) · ✅/❌ its sector
#       HELPERS (n of 3): ✅/❌ the order book (buyers / sellers waiting) · ✅/❌ the option writers · ✅/❌ the whole market (55%+ of F&O shares)
#     (⚪ = not known / no new money - forced out is not new money)
#   · BIG MONEY's LIVE column: ✔ 3/3 +2/3 per share · the strip: how often Zerodha's futures OI really changes (seconds) and the market now
#   · a card's result counts the half booked at target 1 (half +1%, the rest at the buy price = +0.5%, not 0)
#   Edits windwatch.py home.html. Tested: 7 cases + the old turns (7) and wind (8). Restarts the wind watcher and the page server.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 278" $D/home.html && grep -q "class Opts" $D/windwatch.py || { echo "patch 278 first"; exit 1; }
if grep -q "patch 280" $D/home.html && grep -q "def checklist" $D/windwatch.py; then echo "patch 280 - already in"; exit 0; fi
F="windwatch.py home.html"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-windwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel · 278: the option writers every 5 s, the 🎫 card on every big mover, then 🎯 BOOK HALF / 🚪 EXIT · 280: THE CHECKLIST on every message, how fresh the futures OI is): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
GIR's engine already holds, second by second, every F&O share's price, its futures price + OPEN INTEREST and the ORDER BOOK (buyers / sellers
waiting) - but only the price reached the rest of GIR every second; the money and the book came through slower rounds (5-min candles, sweeps).
Patch 275 makes the engine write them every second (data/fut_live.json) and this watcher reads them every 3 s:
  price move in 3 min · futures OI change in 3 min (new money: long / short build-up · or forced out: short covering / long unwinding) ·
  buyers vs sellers waiting in the book · its sector moving the same way
  -> data/wind.json (the live picture - the MOVE / TRADE CARD reads it: seconds old instead of minutes)
  -> tomorrow.db wind_calls: every early wind signal (score 3 of 4+), so windscore.sh can measure it before it is allowed to ring
READ ONLY (no orders, nothing sent).   python3 windwatch.py run | show"""
import os, sys, json, time, sqlite3, collections, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
EVERY, LOOK, KEEP = 3, 180, 900
PX_MIN, OI_MIN, BOOK_X, REPEAT_S = 0.5, 0.5, 1.5, 1800


def _load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None


def sectors_of():
    try:
        import sectors
        return sectors.load()
    except Exception:
        return {}


class Wind:
    def __init__(self, secmap=None):
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=int(KEEP // EVERY) + 5))
        self.sec = secmap if secmap is not None else sectors_of()
        self.of = {}
        for k, v in self.sec.items():
            for s in v:
                self.of.setdefault(s, k)
        self.said = {}
        self.oi_last, self.oi_gap = {}, collections.deque(maxlen=6000)      # patch 280: how often Zerodha's futures OI really changes
        self.br = (0, 0, 0)

    def oi_every(self):
        """the median seconds between two changes of a share's futures OI (the last few thousand changes, all shares)"""
        g = sorted(self.oi_gap)
        return round(g[len(g) // 2], 1) if len(g) >= 20 else None

    def feed(self, t, q, f):
        """q: {sym: [px, chg%]} (quotes_live) · f: {sym: [fut px, fut OI, buy qty, sell qty]} (fut_live)"""
        for s, v in (q or {}).items():
            if not isinstance(v, (list, tuple)) or not v or not v[0]:
                continue
            x = (f or {}).get(s) or [None, None, 0, 0]
            if x[1]:
                lo = self.oi_last.get(s)
                if lo is None or lo[0] != x[1]:
                    if lo is not None and t - lo[1] < 600:
                        self.oi_gap.append(t - lo[1])
                    self.oi_last[s] = (x[1], t)
            self.h[s].append((t, float(v[0]), v[1] if len(v) > 1 else None, x[1], x[2] or 0, x[3] or 0))

    def _ago(self, s, t):
        d = self.h.get(s)
        if not d or len(d) < 2 or t - d[0][0] < LOOK * 0.8:
            return None, None
        old = next((r for r in d if r[0] >= t - LOOK), d[0])
        return old, d[-1]

    def read(self, t):
        """-> {sym: {dir, kind, px3, oi3, book, sec, sec_up, sec_dn, score}} for every share moving now"""
        mv = {}
        for s in list(self.h):
            old, new = self._ago(s, t)
            if not old or not old[1]:
                continue
            px3 = (new[1] / old[1] - 1) * 100
            oi3 = ((new[3] / old[3] - 1) * 100) if (new[3] and old[3]) else None
            book = (new[4] / new[5]) if (new[4] and new[5]) else None
            mv[s] = (px3, oi3, book, new)
        self.br = (sum(1 for v in mv.values() if v[0] > 0.1), sum(1 for v in mv.values() if v[0] < -0.1), len(mv))     # patch 280: the whole market
        out = {}
        for s, (px3, oi3, book, new) in mv.items():
            d = 1 if px3 >= PX_MIN else -1 if px3 <= -PX_MIN else 0
            if not d:
                continue
            kind = "PRICE ONLY"
            if oi3 is not None and oi3 >= OI_MIN:
                kind = "LONG BUILD-UP" if d > 0 else "SHORT BUILD-UP"             # new money its way
            elif oi3 is not None and oi3 <= -OI_MIN:
                kind = "SHORT COVERING" if d > 0 else "LONG UNWINDING"            # the other side forced out
            sec = self.of.get(s)
            peers = [mv[p][0] for p in (self.sec.get(sec) or []) if p != s and p in mv]
            up, dn = sum(1 for x in peers if x > 0.2), sum(1 for x in peers if x < -0.2)
            sec_ok = bool(peers) and (up if d > 0 else dn) * 2 >= len(peers)
            book_ok = book is not None and (book >= BOOK_X if d > 0 else book <= 1 / BOOK_X)
            score = (abs(px3) >= 0.6) + (kind in ("LONG BUILD-UP", "SHORT BUILD-UP")) + book_ok + sec_ok
            out[s] = {"dir": d, "kind": kind, "px3": round(px3, 2), "oi3": None if oi3 is None else round(oi3, 2), "book": None if book is None else round(book, 2),
                      "sec": sec, "sec_up": up, "sec_dn": dn, "sec_n": len(peers), "score": int(score), "px": new[1], "chg": new[2],
                      "mk_up": self.br[0], "mk_dn": self.br[1], "mk_n": self.br[2]}
        return out

    def calls(self, t, W):
        """the early wind signals worth measuring: score 3+ of 4, once a share-side in 30 min"""
        out = []
        for s, w in W.items():
            k = (s, w["dir"])
            if w["score"] >= 3 and (k not in self.said or t - self.said[k] >= REPEAT_S):
                self.said[k] = t
                out.append((s, w))
        return out


def line(w, age=None):
    """the live words for the cards: 'LIVE 4 s ago: futures OI +1.4% in 3 min (new buyers) · buyers 2.1x sellers · its sector 4 of 5 up'"""
    if not w:
        return None
    d = w["dir"]
    k = {"LONG BUILD-UP": "new buyers", "SHORT BUILD-UP": "new sellers", "SHORT COVERING": "sellers forced out", "LONG UNWINDING": "buyers giving up"}.get(w["kind"])
    bits = ["price %+.1f%% in 3 min" % w["px3"]]
    if w.get("oi3") is not None:
        bits.append("futures OI %+.1f%%%s" % (w["oi3"], (" (%s)" % k) if k else ""))
    if w.get("book"):
        b = w["book"]
        bits.append(("buyers %.1fx sellers waiting" % b) if b >= 1 else ("sellers %.1fx buyers waiting" % (1 / b)))
    if w.get("ce3") is not None:                                        # patch 278: the option writers, 5 s old
        bits.append(opt_words(w))
    if w.get("sec") and w.get("sec_n"):
        bits.append("its sector %d of %d %s" % (w["sec_up"] if d > 0 else w["sec_dn"], w["sec_n"], "up" if d > 0 else "down"))
    return "LIVE%s: %s · wind %d of 4" % ((" %d s ago" % age) if age is not None else "", " · ".join(bits), w["score"])


# ---------------- patch 276: THE TURNS (Rama, 14 Nov: "for CE who is building, and from CE to PE who is pulling; for PE who is losing, and from PE to CE
# who is building - the option trader works both ways") ----------------
DAY_PX, DAY_OI, STEADY, TURN_S = 0.3, 0.5, 3, 1200
BASEF = os.path.join(BASE, "data", "wind_base.json")
CE_SIDE, PE_SIDE = ("LONG BUILD-UP", "SHORT COVERING"), ("SHORT BUILD-UP", "LONG UNWINDING")


def day_kind(chg, doi):
    """the day so far: price vs yesterday's close and futures OI vs the day's first reading"""
    if chg is None or doi is None or abs(chg) < DAY_PX or abs(doi) < DAY_OI:
        return None
    if chg > 0:
        return "LONG BUILD-UP" if doi > 0 else "SHORT COVERING"
    return "SHORT BUILD-UP" if doi > 0 else "LONG UNWINDING"


class Turns:
    """per share: the day's side and the live 3-min kind; a turn when the live kind holds for 3 readings (9 s) against the day's side"""
    def __init__(self, day):
        self.day = day
        b = _load(BASEF) or {}
        self.base = b.get("oi") if b.get("day") == day else {}
        self.streak, self.said, self.list = {}, {}, []

    def save(self):
        try:
            json.dump({"day": self.day, "oi": self.base}, open(BASEF + ".tmp", "w")); os.replace(BASEF + ".tmp", BASEF)
        except Exception:
            pass

    def step(self, t, hm, W, wind):
        """W: the Wind (its history) · wind: W.read(t) -> [new turns]"""
        new, changed = [], False
        for s, d in W.h.items():
            if not d:
                continue
            last = d[-1]
            if last[3] and s not in self.base:
                self.base[s] = last[3]; changed = True
        if changed:
            self.save()
        for s, w in wind.items():
            d = W.h.get(s)
            last = d[-1] if d else None
            doi = ((last[3] / self.base[s] - 1) * 100) if (last and last[3] and self.base.get(s)) else None
            dk = day_kind(last[2] if last else None, doi)
            w["day_kind"], w["day_oi"] = dk, None if doi is None else round(doi, 2)
            lk = w["kind"] if w.get("oi3") is not None and abs(w["oi3"]) >= OI_MIN and abs(w["px3"]) >= 0.4 else None
            prev = self.streak.get(s)
            self.streak[s] = (lk, (prev[1] + 1) if prev and prev[0] == lk else 1)
            if not lk or self.streak[s][1] < STEADY or not dk:
                continue
            ev = None
            if dk in CE_SIDE and lk == "LONG UNWINDING":
                ev = ("CE LEAVING", -1, "⚠ the CE side is leaving - buyers unwinding")
            elif dk in CE_SIDE and lk == "SHORT BUILD-UP":
                ev = ("CE → PE", -1, "🔄 TURNED CE → PE - new sellers coming in")
            elif dk in PE_SIDE and lk == "SHORT COVERING":
                ev = ("PE COVERING", 1, "⚠ the PE side is losing - sellers covering")
            elif dk in PE_SIDE and lk == "LONG BUILD-UP":
                ev = ("PE → CE", 1, "🔄 TURNED PE → CE - new buyers coming in")
            if not ev:
                continue
            k = (s, ev[0])
            if k in self.said and t - self.said[k] < TURN_S:
                continue
            self.said[k] = t
            x = {"t": hm, "ts": int(t), "s": s, "turn": ev[0], "dir": ev[1], "words": ev[2], "day_kind": dk, "day_oi": w["day_oi"], "kind": lk,
                 "px3": w["px3"], "oi3": w["oi3"], "book": w.get("book"), "px": w.get("px"), "chg": w.get("chg")}
            self.list.append(x); new.append(x)
            w["turn"] = ev[0]; w["turn_t"] = hm
        self.list = [x for x in self.list if t - x["ts"] < 3 * 3600][-60:]
        for x in self.list:                                            # keep the last turn on the share's live line
            if x["s"] in wind and "turn" not in wind[x["s"]]:
                wind[x["s"]]["turn"], wind[x["s"]]["turn_t"] = x["turn"], x["t"]
        return new


def turn_text(x, w=None):
    up = x["dir"] > 0
    was = (x["day_kind"] or "").lower()
    b = x.get("book")
    book = (" · buyers %.1fx sellers waiting" % b if b >= 1 else " · sellers %.1fx buyers waiting" % (1 / b)) if b else ""
    full = x["turn"] in ("CE → PE", "PE → CE")
    return "\n".join([
        "🔄 TURN %s %s · %s · %s" % ("▲" if up else "▼", x["s"], x["turn"], x["t"]),
        "the day so far: %s%s · now: %s - price %+.1f%% in 3 min, futures OI %+.1f%%%s" % (was, (" (futures OI %+.1f%% today)" % x["day_oi"]) if x.get("day_oi") is not None else "",
                                                                                   x["kind"].lower(), x["px3"], x["oi3"], book),
        ("for you: %s holders - protect it now (exit / tighten the stop) · the %s side now has the money - a trade only when GIR confirms" % ("PE" if up else "CE", "CE" if up else "PE")) if full else
        ("for you: %s holders - watch it closely; if it turns fully GIR says 🔄 TURNED" % ("PE" if up else "CE"))] +
        (check_text(w, "THE NEW SIDE - THE 3 (%s)" % ("CE" if up else "PE")) if w and w.get("dir") == x["dir"] else []))


def turns_db(xs, day):
    try:
        c = db()
        c.execute("create table if not exists wind_turns(day text, t text, sym text, turn text, side text, day_kind text, kind text, px real, px3 real, oi3 real)")
        c.executemany("insert into wind_turns values (?,?,?,?,?,?,?,?,?,?)", [(day, x["t"], x["s"], x["turn"], "CE" if x["dir"] > 0 else "PE", x["day_kind"], x["kind"], x["px"], x["px3"], x["oi3"]) for x in xs])
        c.commit(); c.close()
    except Exception:
        pass


# ---------------- patch 277: 🌪 BIG MOVERS - their own Telegram channel "GIR Bigmovers" (Rama, 14 Nov) ----------------
BIG_PX, BIG_S = 0.8, 1800
ENVF = "/home/globalbot/.env"
_ENV = {"t": 0.0, "e": {}}


def env():
    """GIR's .env, read (never copied) once a minute - a channel set up later is picked up without a restart"""
    if time.time() - _ENV["t"] > 60:
        e = {}
        try:
            import re as _re
            for ln in open(ENVF):
                m = _re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", ln)
                if m:
                    e[m.group(1)] = m.group(2).strip("'\"")
        except Exception:
            pass
        _ENV.update({"t": time.time(), "e": e})
    return _ENV["e"]


def big_movers(t, wind, said):
    """the early, fast movers: 0.8%+ in 3 min with NEW futures money its way and 3 of 4 wind - once a share-side in 30 min"""
    out = []
    for s, w in wind.items():
        if w["score"] >= 3 and abs(w["px3"]) >= BIG_PX and w["kind"] in ("LONG BUILD-UP", "SHORT BUILD-UP"):
            k = (s, w["dir"])
            if k not in said or t - said[k] >= BIG_S:
                said[k] = t
                out.append((s, w))
    return out


# ---------------- patch 280: THE CHECKLIST on every message (Rama, 14 Nov: "in order for the shares to move all should move together - tell me what
# all 3 are, and when you give the alarm and message you should mention that also") ----------------
# THE 3 THAT MUST MOVE TOGETHER: the price (0.6%+ in 3 min) · the futures money (NEW money its way: long / short build-up) · its sector (half of
# its peers or more the same way). THE HELPERS: the order book (buyers / sellers waiting 1.5x) · the option writers (CE vs PE OI near the
# price) · the whole market (55%+ of the F&O shares moving the same way in 3 min).
def checklist(w):
    """-> (must_ok, must_of, help_ok, help_of, line_must, line_help)"""
    up = w["dir"] > 0
    M, Hh = [], []
    px = abs(w.get("px3") or 0) >= 0.6
    M.append((px, "price %+.1f%% in 3 min" % (w.get("px3") or 0)))
    k = w.get("kind")
    if k in ("LONG BUILD-UP", "SHORT BUILD-UP"):
        M.append((True, "futures money: %s (OI %+.1f%%)" % ("new buyers" if up else "new sellers", w.get("oi3") or 0)))
    elif k in ("SHORT COVERING", "LONG UNWINDING"):
        M.append((None, "futures: %s (OI %+.1f%%) - no new money" % ("sellers running" if up else "buyers leaving", w.get("oi3") or 0)))
    else:
        M.append((False, "futures money: not moving"))
    if w.get("sec_n"):
        n_ = w["sec_up"] if up else w["sec_dn"]
        M.append((n_ * 2 >= w["sec_n"], "sector %d of %d %s" % (n_, w["sec_n"], "up" if up else "down")))
    else:
        M.append((None, "sector: no peers to compare"))
    b = w.get("book")
    if b:
        ok = b >= BOOK_X if up else b <= 1 / BOOK_X
        Hh.append((ok, ("buyers %.1fx sellers waiting" % b) if b >= 1 else ("sellers %.1fx buyers waiting" % (1 / b))))
    else:
        Hh.append((None, "order book: not known"))
    if w.get("ce3") is not None:
        a = w.get("opt")
        Hh.append((a, "writers: %s (CE OI %+.1f%% · PE OI %+.1f%%)" % ({True: "back it", False: "against it", None: "no side"}[a], w["ce3"], w["pe3"])))
    else:
        Hh.append((None, "writers: not known yet"))
    if w.get("mk_n"):
        mu, md, mn = w["mk_up"], w["mk_dn"], w["mk_n"]
        same, other = (mu, md) if up else (md, mu)
        Hh.append((True if same >= 0.55 * mn else False if other >= 0.55 * mn else None, "market: %d of %d shares %s" % (same, mn, "rising" if up else "falling")))
    ic = lambda v: "✅" if v is True else "❌" if v is False else "⚪"
    mo, ho = sum(1 for v, _ in M if v is True), sum(1 for v, _ in Hh if v is True)
    return (mo, len(M), ho, len(Hh), " · ".join("%s %s" % (ic(v), t) for v, t in M), " · ".join("%s %s" % (ic(v), t) for v, t in Hh))


def check_text(w, head="THE 3 THAT MUST MOVE TOGETHER"):
    if not w:
        return []
    mo, mn, ho, hn, lm, lh = checklist(w)
    return ["%s (%d of %d): %s" % (head, mo, mn, lm), "HELPERS (%d of %d): %s" % (ho, hn, lh)]


def big_text(s, w, hm, card=None):
    """patch 280: the head, THE CHECKLIST (the 3 that must move together + the helpers), the 🎫 card, the plan"""
    up = w["dir"] > 0
    stop = w["px"] / (1 + w["px3"] / 100)
    L = ["🌪 BIG MOVER %s %s · %s · ₹%s (%+.1f%% today)" % ("▲" if up else "▼", s, hm, "{:,.2f}".format(w["px"]), w.get("chg") or 0)]
    L += check_text(w)
    L += list(card or [])
    L.append("%s side · early card: HALF your usual size until the scorecard proves it · stop: the share back %s ₹%s · GIR follows it here: 🎯 BOOK HALF · 🚪 EXIT" % (
        "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(stop)))
    return "\n".join(L)


def _log(text):
    try:
        import opencall
        opencall.log_alert(text)
    except Exception:
        pass


def send_big(text, log=True):
    """straight to GIR Bigmovers (TG_CHAT_BIGMOVERS), with sound - and onto GIR's page; False when the channel is not set up yet"""
    e = env()
    chat, tok = e.get("TG_CHAT_BIGMOVERS"), e.get("TELEGRAM_TOKEN") or e.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_TOKEN")
    if not (chat and tok):
        if log:
            _log(text)
        return False
    _log(text)
    try:
        import requests
        a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
        d = {"chat_id": a, "text": text[:4000], "disable_web_page_preview": "true"}
        if b and b.isdigit():
            d["message_thread_id"] = b
        return requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=15).ok
    except Exception:
        return False


# ---------------- patch 278: THE OPTION WRITERS EVERY 5 s + THE CARD FOLLOWED TO THE EXIT (Rama, 14 Nov: "when the futures are investing and
# disinvesting the shares are definitely going up and down - GIR should find it in time and alert me, then we invest, make money and exit") ----------------
# The engine already writes every pinned strike (the 11 nearest the price, CE and PE, all 218 shares) to pins_live.json every 5 s (patch 79) -
# only the desk read it. Now the wind reads it too: CE OI vs PE OI near the price in the last 3 min (who is writing), and every 🌪 card is
# followed: 🎯 BOOK HALF at 1x the risk (stop to the buy price), 🎯 TARGET 2 at 2x, 🚪 EXIT when the futures money leaves (3 readings in a row),
# the stop, or 15:10. Every card and its result go to tomorrow.db wind_cards; the strikes once a minute to data/chainlive.db (10 days).
PINF = os.path.join(BASE, "pins_live.json")
NEAR, OPT_GAP, OPT_MIN_OI = 3, 2.0, 1000
HISTF = os.path.join(BASE, "data", "chainlive.db")
HALF_X, T2_X, MIN_R, EXIT_HM = 1.0, 2.0, 0.004, "15:10"


class Opts:
    """the pinned strikes, every 5 s: per share the nearest expiry's strikes around the price"""
    def __init__(self):
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=KEEP // 5 + 5))
        self.now, self.spot, self.last = {}, {}, None

    def feed(self, P, t):
        if not P or not P.get("t") or P["t"] == self.last or t - float(P["t"]) > 40:
            return False
        self.last = P["t"]
        self.spot = P.get("spot") or {}
        for s, rows in (P.get("rows") or {}).items():
            rows = [r for r in (rows or []) if isinstance(r, (list, tuple)) and len(r) >= 5]
            if not rows:
                continue
            ex = min(r[0] for r in rows)
            self.h[s].append((t, {(float(r[1]), r[2]): float(r[3] or 0) for r in rows if r[0] == ex}))
            self.now[s] = {(r[0], float(r[1]), r[2]): float(r[4] or 0) for r in rows}
        return True

    def read(self, s, t, spot=None):
        """-> {ce3, pe3} the % change of CE OI and PE OI on the strikes nearest the price, over the last 3 min (same strikes both ends)"""
        d = self.h.get(s)
        if not d or len(d) < 2 or t - d[0][0] < LOOK * 0.8:
            return None
        old = next((r for r in d if r[0] >= t - LOOK), d[0])[1]
        new = d[-1][1]
        spot = spot or self.spot.get(s)
        ks = sorted({k for k, _ in new})
        if not ks:
            return None
        if spot:
            ks = sorted(ks, key=lambda k: abs(k - spot))[:2 * NEAR]
        out = {}
        for side in ("CE", "PE"):
            keys = [(k, side) for k in ks if (k, side) in new and (k, side) in old]
            a, b = sum(old[x] for x in keys), sum(new[x] for x in keys)
            if a < OPT_MIN_OI:
                return None
            out[side.lower() + "3"] = round((b / a - 1) * 100, 2)
        return out

    def prem(self, s, exp, k, side):
        return (self.now.get(s) or {}).get((exp, float(k), side))


def opt_agree(d, ce3, pe3):
    """the writers: a rise is backed when PE OI grows faster than CE OI (put writers add / call writers cover); a fall the other way.
    True = they back the move · False = they are against it · None = no clear side"""
    if ce3 is None or pe3 is None:
        return None
    g = (pe3 - ce3) if d > 0 else (ce3 - pe3)
    return True if g >= OPT_GAP else False if g <= -OPT_GAP else None


def opt_words(w):
    up = w["dir"] > 0
    a = w.get("opt")
    tail = {True: "put writers back the rise" if up else "call writers back the fall", False: "the writers are against it - careful",
            None: "the writers have no clear side"}[a]
    return "options CE OI %+.1f%% · PE OI %+.1f%% in 3 min (%s)" % (w["ce3"], w["pe3"], tail)


def opt_into(wind, O, t):
    for s, w in wind.items():
        o = O.read(s, t, w.get("px"))
        if o:
            w["ce3"], w["pe3"] = o["ce3"], o["pe3"]
            w["opt"] = opt_agree(w["dir"], o["ce3"], o["pe3"])


def card_lines(s, side, ustop, now):
    """the 🎫 TRADE CARD (movecard.py - Zerodha's quote, 3 s at most) -> (lines, (exp, strike, premium) or None)"""
    try:
        import movecard
        L = movecard.trade_card(s, side, ustop, now)
    except Exception as ex:
        return ["🎫 TRADE CARD: not available right now (%s) - take the strike nearest the price" % str(ex)[:60]], None
    import re as _re
    m = _re.search(r"BUY \S+ ([\d.]+) (CE|PE) · expiry (\d\d \w{3})", L[0] if L else "")
    p = _re.search(r"premium ₹([\d,]+\.?\d*)", L[1] if len(L) > 1 else "")
    pick = None
    if m and p:
        try:
            ex = dt.datetime.strptime("%s %d" % (m.group(3), now.year), "%d %b %Y").date()
            if ex < now.date():
                ex = ex.replace(year=now.year + 1)
            pick = (str(ex), float(m.group(1)), float(p.group(1).replace(",", "")))
        except Exception:
            pick = None
    return L, pick


class Book:
    """the 🌪 cards GIR gave today, followed every 3 s until the exit"""
    def __init__(self, day):
        self.day, self.open, self.done = day, {}, []

    def add(self, s, w, t, hm):
        d, e = w["dir"], w["px"]
        stop = e / (1 + w["px3"] / 100)
        r = max(abs(e - stop), e * MIN_R)
        stop = e - d * r
        p = {"s": s, "dir": d, "t": hm, "ts": t, "entry": e, "stop0": stop, "stop": stop, "r": r, "half": False, "t2": False, "bad": 0, "pick": None}
        self.open[(s, d)] = p
        return p

    def step(self, t, hm, W, wind, O=None):
        """-> [(kind, card, px, words)]  kind: HALF · T2 · EXIT"""
        out = []
        for k, p in list(self.open.items()):
            s, d = k
            dq = W.h.get(s)
            if not dq or dq[-1][0] <= p["ts"]:
                continue
            px = dq[-1][1]
            mv = (px - p["entry"]) * d
            w = wind.get(s)
            ev = None
            if (px - p["stop"]) * d <= 0:
                ev = "the stop: the share is back %s ₹%s%s" % ("under" if d > 0 else "over", "{:,.2f}".format(p["stop"]),
                                                             " (your buy price - the rest goes out at no loss)" if p["half"] else " - the move failed")
            else:
                against = ("LONG UNWINDING", "SHORT BUILD-UP") if d > 0 else ("SHORT COVERING", "LONG BUILD-UP")
                if w and w.get("oi3") is not None and abs(w["oi3"]) >= OI_MIN and w["kind"] in against:
                    p["bad"] += 1
                else:
                    p["bad"] = 0
                if p["bad"] >= STEADY:
                    ev = "the futures money is leaving: %s (OI %+.1f%%, price %+.1f%% in 3 min)" % (
                        {"LONG UNWINDING": "buyers unwinding", "SHORT BUILD-UP": "new sellers coming in", "SHORT COVERING": "sellers covering",
                         "LONG BUILD-UP": "new buyers coming in"}[w["kind"]], w["oi3"], w["px3"])
                elif hm >= EXIT_HM:
                    ev = "%s - an early card is not held overnight: close it before 15:20" % EXIT_HM
            if ev:
                del self.open[k]
                r_ = (mv + (p["half_px"] - p["entry"]) * d) / 2 if p.get("half_px") is not None else mv      # patch 280: half booked at target 1 counts
                p.update({"exit_t": hm, "exit_px": px, "why": ev, "res": round(r_ / p["entry"] * 100, 2)})
                self.done.append(p)
                out.append(("EXIT", p, px, ev))
                continue
            if not p["half"] and mv >= HALF_X * p["r"]:
                p["half"], p["stop"], p["half_px"] = True, p["entry"], px
                out.append(("HALF", p, px, "target 1 reached (+1x the risk)"))
            elif p["half"] and not p["t2"] and mv >= T2_X * p["r"]:
                p["t2"], p["stop"] = True, p["entry"] + d * p["r"]
                out.append(("T2", p, px, "target 2 reached (+2x the risk)"))
        return out

    def status(self):
        st = {}
        for p in self.done:
            st[(p["s"], p["dir"], p["t"])] = ("exit %+.1f%%" % p["res"], 1 if p["res"] > 0 else -1 if p["res"] < 0 else 0)
        for p in self.open.values():
            st[(p["s"], p["dir"], p["t"])] = ("target 2 · open" if p["t2"] else "½ booked · open" if p["half"] else "open", 1 if p["half"] else 0)
        return st


def follow_text(kind, p, px, words, O=None, w=None):
    up = p["dir"] > 0
    side = "CE" if up else "PE"
    head = {"EXIT": "🚪 EXIT", "HALF": "🎯 BOOK HALF", "T2": "🎯 TARGET 2"}[kind]
    mv = (px / p["entry"] - 1) * 100
    L = ["%s %s %s %s · %s" % (head, "▲" if up else "▼", p["s"], side, dt.datetime.now(IST).strftime("%H:%M:%S")),
         words,
         "from the %s 🌪 card: share ₹%s → ₹%s (%+.1f%%)" % (p["t"][:5], "{:,.2f}".format(p["entry"]), "{:,.2f}".format(px), mv)]
    pk = p.get("pick")
    if pk and O is not None:
        now_ = O.prem(p["s"], pk[0], pk[1], side)
        if now_:
            L[-1] += " · %s %s premium ₹%.2f (card ₹%.2f: %+.0f%%)" % ("{:g}".format(pk[1]), side, now_, pk[2], (now_ / pk[2] - 1) * 100)
    L.append({"EXIT": "sell the rest now" if p.get("half") else "sell it all now",
              "HALF": "sell half now · move the stop to your buy price (share ₹%s)" % "{:,.2f}".format(p["entry"]),
              "T2": "sell most of the rest · keep the last part with the stop at ₹%s" % "{:,.2f}".format(p["stop"])}[kind])
    if w:
        L += check_text(w, "NOW (%s)" % ("▲" if w["dir"] > 0 else "▼"))
    return "\n".join(L)


def cards_db(p, day):
    try:
        c = db()
        c.execute("create table if not exists wind_cards(day text, t text, sym text, side text, entry real, stop real, half int, exit_t text, exit_px real, why text, res real)")
        c.execute("insert into wind_cards values (?,?,?,?,?,?,?,?,?,?,?)", (day, p["t"], p["s"], "CE" if p["dir"] > 0 else "PE", p["entry"], p["stop0"], int(p["half"]),
                                                                           p.get("exit_t"), p.get("exit_px"), (p.get("why") or "")[:120], p.get("res")))
        c.commit(); c.close()
    except Exception:
        pass


def hist_save(O, t, day, hm):
    """once a minute: the strikes nearest the price (nearest expiry) -> data/chainlive.db, so a replay sees minutes, not 40-min gaps"""
    try:
        c = sqlite3.connect(HISTF, timeout=5)
        c.execute("create table if not exists pins(d text, t text, sym text, strike real, kind text, oi real)")
        c.execute("create index if not exists pins_ds on pins(d, sym)")
        rows = []
        for s, dq in O.h.items():
            if not dq:
                continue
            m = dq[-1][1]
            sp = O.spot.get(s)
            ks = sorted({k for k, _ in m}, key=lambda k: abs(k - sp) if sp else 0)[:2 * NEAR]
            rows += [(day, hm, s, k, kd, m[(k, kd)]) for k in ks for kd in ("CE", "PE") if (k, kd) in m]
        c.executemany("insert into pins values (?,?,?,?,?,?)", rows)
        if hm == "09:16":
            c.execute("delete from pins where d < date(?, '-10 days')", (day,))
        c.commit(); c.close()
        return len(rows)
    except Exception:
        return 0


def db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists wind_calls(day text, t text, sym text, side text, kind text, px real, px3 real, oi3 real, book real, sec text, score int)")
    return c


BIG_DAY_MAX = 30


def live_all(W, TU):
    """every share with futures data -> [price % today, futures OI % since the day's first reading (= yesterday's close OI), fresh ₹ cr]"""
    out = {}
    for s, d in W.h.items():
        if not d:
            continue
        last = d[-1]
        b = TU.base.get(s)
        if last[3] and b:
            out[s] = [None if last[2] is None else round(float(last[2]), 2), round((last[3] / b - 1) * 100, 2), round((last[3] - b) * last[1] / 1e7, 1)]
    return out


def _bg(fn, *a):
    """send without holding the 3-s loop (Zerodha's quote for the card takes up to 3 s, Telegram up to 15 s)"""
    import threading
    threading.Thread(target=fn, args=a, daemon=True).start()


def _send_card(s_, w_, hm_, p_, now_):
    side = "CE" if w_["dir"] > 0 else "PE"
    L, pick = card_lines(s_, side, p_["stop0"], now_)
    p_["pick"] = pick
    send_big(big_text(s_, w_, hm_, L))


def run():
    W = Wind()
    TU = Turns(str(dt.datetime.now(IST).date()))
    O, BK = Opts(), Book(str(dt.datetime.now(IST).date()))        # patch 278
    last_q, last_min = 0.0, None
    sent = {"day": None, "n": 0, "big": 0}
    bsaid, BL = {}, []
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            if W.h:
                W, O = Wind(), Opts()
            if TU.day != str(now.date()):
                TU = Turns(str(now.date()))
            if BK.day != str(now.date()):
                BK = Book(str(now.date()))
            time.sleep(20); continue
        try:
            Q = _load(os.path.join(BASE, "quotes_live.json")) or {}
            F = _load(os.path.join(BASE, "data", "fut_live.json")) or {}
            t = time.time()
            day, hms = str(now.date()), now.strftime("%H:%M:%S")
            if sent["day"] != day:
                sent.update({"day": day, "n": 0, "big": 0})
            O.feed(_load(PINF), t)                                          # patch 278: the strikes, 5 s old
            if hm != last_min and O.h:
                last_min = hm
                hist_save(O, t, day, hm)
            if Q.get("t") and Q["t"] != last_q and t - Q["t"] < 30:
                last_q = Q["t"]
                W.feed(t, Q.get("q"), F.get("f") if F.get("t") and t - F["t"] < 30 else {})
                cur = W.read(t)
                opt_into(cur, O, t)
                for w_ in cur.values():                                           # patch 280: the checklist count for the page
                    c_ = checklist(w_); w_["chk"] = [c_[0], c_[1], c_[2], c_[3]]
                NT = TU.step(t, hms, W, cur)          # patch 276: the turns
                p = os.path.join(BASE, "data", "wind.json")
                for kind, cp, px, words in BK.step(t, hm, W, cur, O):     # patch 278: the cards followed
                    _bg(send_big, follow_text(kind, cp, px, words, O, cur.get(cp["s"])))
                    if kind == "EXIT":
                        cards_db(cp, day)
                BG = big_movers(t, cur, bsaid)                                   # patch 277: 🌪 BIG MOVERS
                for s_, w_ in BG:
                    x = {"t": hms, "ts": int(t), "s": s_, "dir": w_["dir"], "px3": w_["px3"], "oi3": w_["oi3"], "score": w_["score"], "opt": w_.get("opt")}
                    BL.append(x)
                    if w_.get("opt") is False:
                        x["st"], x["won"] = "held · writers against", 0                 # shown, not sent: the option writers fight it
                        continue
                    if (s_, w_["dir"]) in BK.open:
                        x["st"], x["won"] = "card already open", 0
                        continue
                    if sent["big"] >= BIG_DAY_MAX:
                        x["st"], x["won"] = "page only (30 a day)", 0
                        continue
                    sent["big"] += 1
                    other = BK.open.pop((s_, -w_["dir"]), None)
                    if other:                                                        # the other side's card on the same share: out
                        other.update({"exit_t": hm, "exit_px": w_["px"], "why": "a big mover the other way", "res": round((w_["px"] - other["entry"]) * other["dir"] / other["entry"] * 100, 2)})
                        BK.done.append(other); cards_db(other, day)
                        _bg(send_big, follow_text("EXIT", other, w_["px"], "a 🌪 big mover the OTHER way on the same share", O))
                    cp = BK.add(s_, w_, t, hms)
                    _bg(_send_card, s_, w_, hms, cp, now)
                st = BK.status()
                for x in BL:
                    if (x["s"], x["dir"], x["t"]) in st:
                        x["st"], x["won"] = st[(x["s"], x["dir"], x["t"])]
                BL[:] = [x for x in BL if t - x["ts"] < 3 * 3600][-40:]
                ALL = live_all(W, TU)                                                # patch 278: every share's day, live (the BIG MONEY table)
                cards = [{k: c.get(k) for k in ("s", "dir", "t", "entry", "stop", "half", "t2", "exit_t", "exit_px", "why", "res")} for c in list(BK.open.values()) + BK.done[-30:]]
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "opt": bool(O.h), "s": cur, "turns": TU.list[-40:], "big": BL[-40:], "cards": cards, "all": ALL, "oi_every": W.oi_every(), "mk": list(W.br)},
                          open(p + ".tmp", "w"), separators=(",", ":")); os.replace(p + ".tmp", p)
                C = W.calls(t, cur)
                if C:
                    c = db()
                    c.executemany("insert into wind_calls values (?,?,?,?,?,?,?,?,?,?,?)", [(day, hms, s, "CE" if w["dir"] > 0 else "PE",
                                  w["kind"], w["px"], w["px3"], w["oi3"], w["book"], w["sec"], w["score"]) for s, w in C])
                    c.commit(); c.close()
                if NT:
                    turns_db(NT, day)
                    for x in NT:                                              # a FULL turn: to GIR Bigmovers (patch 277), else quietly to the usual channel
                        if x["turn"] in ("CE → PE", "PE → CE") and sent["n"] < 40:
                            sent["n"] += 1
                            _bg(_send_turn, turn_text(x, cur.get(x["s"])))
        except Exception as ex:
            print("%s %s" % (hm, str(ex)[:120]), flush=True); time.sleep(5)
        time.sleep(EVERY)


def _send_turn(text):
    if not send_big(text, log=False):
        try:
            import opencall
            opencall.send_tg(text)
        except Exception as ex:
            print("send: %s" % str(ex)[:80], flush=True)


def cards_show(day=None):
    """python3 windwatch.py cards [DAY] - every 🌪 card and how it ended"""
    day = day or str(dt.datetime.now(IST).date())
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True)
        R = c.execute("select t, sym, side, entry, half, exit_t, exit_px, why, res from wind_cards where day=? order by t", (day,)).fetchall()
    except Exception:
        R = []
    print("=== 🌪 CARDS %s: %d" % (day, len(R)))
    for r in R:
        print("  %s %-11s %s ₹%-9s %s → %s %-7s %s" % (r[0][:5], r[1], r[2], "{:,.2f}".format(r[3]), "½" if r[4] else " ", r[5] or "-", ("%+.2f%%" % r[8]) if r[8] is not None else "", (r[7] or "")[:60]))
    if R:
        w = [r[8] for r in R if r[8] is not None]
        print("  won %d · lost %d · booked half first %d · average %+.2f%% on the share" % (sum(1 for x in w if x > 0), sum(1 for x in w if x < 0), sum(1 for r in R if r[4]), sum(w) / max(1, len(w))))


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"]:
        run()
    elif sys.argv[1:2] == ["cards"]:
        cards_show(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        j = _load(os.path.join(BASE, "data", "wind.json")) or {}
        age = time.time() - (j.get("t") or 0)
        print("wind.json: %s · futures data %s · futures OI changes every %s · option strikes %s" % (("%.0f s old" % age) if j else "not written yet (from 09:15 on a trading day)",
              "in" if j.get("fut") else "not in yet", ("~%s s (median, all shares)" % j["oi_every"]) if j.get("oi_every") else "-", "in" if j.get("opt") else "not in yet"))
        for s, w in sorted((j.get("s") or {}).items(), key=lambda x: -x[1]["score"])[:15]:
            print("  %-11s %s" % (s, line(w)))
PY_WW
cat > $W/p280_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p280_patch.py - patch 280: the checklist on BIG MONEY's LIVE column + the futures OI freshness.  python3 p280_patch.py DIR JSFILE"""
import os, sys
D, JS = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 280" in s:
    print("  home.html: patch 280 - already in"); sys.exit(0)
A = '''setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big"&&!document.hidden) pullWind(); },3000);'''
if s.count(A) != 1 or "patch 278" not in s:
    print("❌ home.html: anchor found %d times (or patch 278 missing)" % s.count(A)); sys.exit(1)
s = s.replace(A, A + "\n" + JS.strip())
open(p, "w", encoding="utf-8").write(s)
print("  home.html: the checklist (3 that must move together + helpers) on the LIVE column · futures OI freshness · the market now")
print("patch 280 in")
PY_PATCH
cat > $W/page280.js <<'JS_280'
/* patch 280: THE CHECKLIST on the LIVE column (the 3 that must move together · the helpers) and how fresh the futures OI really is */
{ const wc0_=windCell; windCell=function(w){ let h=wc0_(w); if(w&&w.chk){ const m=w.chk[0], mn=w.chk[1], hh=w.chk[2], hn=w.chk[3]; h=`<b class="${m>=mn?"pu":m>=2?"am":"dim"}" title="the 3 that must move together: price · futures money · sector">${m===mn?"✔":"·"} ${m}/${mn}</b> <span class="dim" title="helpers: order book · option writers · the whole market">+${hh}/${hn}</span> `+h; } return h; }; }
{ const wp0_=windPaint; windPaint=function(){ wp0_(); try{ const bar=$("mk-lnk")&&$("mk-lnk").querySelector(".wbar"); if(bar&&WIND&&!bar.querySelector(".oie")){ const sp=document.createElement("span"); sp.className="oie dim";
  sp.textContent=` · futures OI ${WIND.oi_every?"changes every ~"+WIND.oi_every+" s":"freshness: from 09:15"}${WIND.mk&&WIND.mk[2]?` · market now: ${WIND.mk[0]} up / ${WIND.mk[1]} down of ${WIND.mk[2]}`:""}`; bar.insertBefore(sp,bar.querySelector("div")); } }catch(e){} }; }
JS_280
cat > $W/p280test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p280test.py - THE CHECKLIST on every message · the result counts the half booked · how fresh the futures OI is (made-up readings, nothing sent)"""
import os, sys, shutil, tempfile
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
WW.ENVF = os.path.join(T, "no.env")
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:600]))
w = {"dir": 1, "kind": "LONG BUILD-UP", "px3": 1.1, "oi3": 1.6, "book": 2.3, "score": 4, "px": 1049.0, "chg": 3.2, "sec_up": 3, "sec_dn": 0, "sec_n": 4,
     "ce3": -3.6, "pe3": 5.4, "opt": True, "mk_up": 140, "mk_dn": 50, "mk_n": 218}
c = WW.checklist(w)
chk("all agree: the 3 that must move together 3 of 3 (price · new futures money · sector) + helpers 3 of 3 (book · writers · market)", c[:4] == (3, 3, 3, 3), c)
weak = dict(w, kind="SHORT COVERING", oi3=-1.2, sec_up=1, book=None, ce3=None, pe3=None, opt=None, mk_up=60, mk_dn=130)
c2 = WW.checklist(weak)
chk("forced-out money is not new money (⚪) · sector 1 of 4 ❌ · book / writers not known ⚪ · the market falling ❌", c2[:4] == (1, 3, 0, 3) and "⚪ futures: sellers running" in c2[4]
    and "❌ sector 1 of 4 up" in c2[4] and "❌ market: 60 of 218 shares rising" in c2[5], c2)
tx = WW.big_text("POLICYBZR", w, "09:19:42", ["🎫 TRADE CARD · BUY POLICYBZR 1060 CE · expiry 23 Nov (9 days)"])
print("\n" + tx + "\n")
L = tx.split("\n")
chk("🌪 BIG MOVER: the head, then THE 3 THAT MUST MOVE TOGETHER, then THE HELPERS, then the card and the plan", L[0] == "🌪 BIG MOVER ▲ POLICYBZR · 09:19:42 · ₹1,049.00 (+3.2% today)"
    and L[1].startswith("THE 3 THAT MUST MOVE TOGETHER (3 of 3): ✅ price +1.1% in 3 min · ✅ futures money: new buyers (OI +1.6%) · ✅ sector 3 of 4 up")
    and L[2].startswith("HELPERS (3 of 3): ✅ buyers 2.3x sellers waiting · ✅ writers: back it") and "✅ market: 140 of 218 shares rising" in L[2]
    and L[3].startswith("🎫 TRADE CARD") and "HALF your usual size" in L[4], L)
x = {"t": "10:42:07", "ts": 0, "s": "HINDALCO", "turn": "CE → PE", "dir": -1, "words": "", "day_kind": "LONG BUILD-UP", "day_oi": 3.1, "kind": "SHORT BUILD-UP",
     "px3": -0.8, "oi3": 1.2, "book": 0.4, "px": 700.0, "chg": -0.5}
wt = dict(w, dir=-1, kind="SHORT BUILD-UP", px3=-0.8, oi3=1.2, book=0.4, sec_dn=2, ce3=2.0, pe3=-1.0, opt=True)
tt = WW.turn_text(x, wt)
print(tt + "\n")
chk("🔄 TURN carries the checklist of the NEW side", "THE NEW SIDE - THE 3 (PE) (3 of 3)" in tt and "✅ futures money: new sellers" in tt, tt)
class FW: pass
F = FW(); F.h = {"AAA": [(0, 100.0)]}
BK = WW.Book("d"); p = BK.add("AAA", dict(w, px=100.0, px3=1.0), 0, "10:00:00")
F.h["AAA"].append((60, 101.05)); BK.step(60, "10:01", F, {})
F.h["AAA"].append((120, 100.0)); E = BK.step(120, "10:02", F, {})
chk("the result counts the half booked at target 1: half +1.05%, the rest out at the buy price = +0.53% (not 0)", E and E[0][0] == "EXIT" and abs(p["res"] - 0.53) < 0.02, (E, p.get("res")))
ft = WW.follow_text("EXIT", p, 100.0, E[0][3], None, dict(w, dir=-1, kind="LONG UNWINDING", px3=-0.9, oi3=-0.8, sec_dn=3))
chk("🎯 / 🚪 carry the checklist NOW", "NOW (▼)" in ft and "sell the rest now" in ft, ft)
W = WW.Wind(secmap={})
for i in range(30):
    W.feed(1000 + i, {"AAA": [100 + i * 0.01, 0.1], "BBB": [50, -0.2]}, {"AAA": [100, 1000 + (i // 2), 1, 1], "BBB": [50, 500 + (i // 3), 1, 1]})
chk("how fresh the futures OI is: the median seconds between two changes (AAA every 2 s, BBB every 3 s)", W.oi_every() in (2, 3), W.oi_every())
print("THE CHECKLIST TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p280_patch.py $D $W/page280.js || back
cd $D && python3 -m py_compile windwatch.py || back
echo "=== test"
python3 $W/p280test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-windwatch gir-dash; sleep 5
echo "  gir-windwatch: $(systemctl is-active gir-windwatch) · gir-dash: $(systemctl is-active gir-dash)"
echo "✅ patch 280 done - every 🌪 / 🔄 / 🎯 / 🚪 says which of THE 3 (price · futures money · sector) and the helpers agree; BIG MONEY shows ✔ 3/3 (Ctrl + Shift + R)"
echo "   live check any time:  python3 $D/windwatch.py      (how fresh the futures OI is, the shares moving now)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-windwatch gir-dash"
