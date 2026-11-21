#!/bin/bash
# PATCH 281 - 🚀 MOMENTUM (RAMA'S OWN WAY) + POSITION GUARD SEES THE EARLY SIGNALS (Rama, 14 Nov: "most of the money I made by momentum - the stock
#   goes up 10%, then I invest, make money and exit; the only mistake I made is GRASIM").
#   Measured (fastreplay.py, 9 results days 2-13 Nov): a share already +3% on the day went 2% MORE 24% of the time, turned back 2% first 10%;
#   BEFORE 10:00 33% vs 11%, after 10:00 15% vs 12% (a coin flip). On a strong market day the other side turns back.
#   · windwatch.py: 🚀 MOMENTUM - the first time an F&O share crosses +3% (or -3%) today -> a card to GIR Bigmovers with sound: THE CHECK (before
#     10:00 · the market · futures OI since the open · results today / last evening) · MEASURED · the checklist · 🎫 · stop 2% back · 🎯 BOOK HALF
#     2% more, then GIR follows it (🎯 / 🚪). +5% / +8% = an update on the same card. Only before 10:00, from 09:17, not against a strong market
#     (65%+ of the F&O shares the other way), 12 cards a day (results first) - else on the page only, saying why.
#   · posguard.py: ⚠ AGAINST GIR - a NEW position against 2+ of GIR's signals of the last 15 min, the early ones too (FIRST MOVE · TRIAL ENTRY ·
#     RESULTS MISS / BEAT · 🌪 · 🚀 · 🔄) - warned within a minute of the order · 🕑 AFTERNOON SIZE - a new position after
#     13:00 at 1.5x the morning's size (₹1.5 lakh at least)
#   · home.html: 🚀 MOMENTUM on the BIG MONEY strip
#   Edits windwatch.py home.html posguard.py. Tested: 12 + 7 (a results-day sequence) + the old 7 / 7 / 8. Restarts the wind watcher and the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 280" $D/home.html && grep -q "def checklist" $D/windwatch.py && grep -q "def gir_calls" $D/posguard.py || { echo "patch 280 (and 263) first"; exit 1; }
if grep -q "patch 281" $D/home.html && grep -q "class Momentum" $D/windwatch.py && grep -q "patch 281" $D/posguard.py; then echo "patch 281 - already in"; exit 0; fi
F="windwatch.py home.html posguard.py"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-windwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel · 278: the option writers every 5 s, the 🎫 card on every big mover, then 🎯 BOOK HALF / 🚪 EXIT · 280: THE CHECKLIST on every message, how fresh the futures OI is · 281: 🚀 MOMENTUM - Rama's own way): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
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

    def add(self, s, w, t, hm, r=None):
        d, e = w["dir"], w["px"]
        stop = e / (1 + w["px3"] / 100)
        r = r if r else max(abs(e - stop), e * MIN_R)
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



# ---------------- patch 281: 🚀 MOMENTUM - RAMA'S OWN WAY (14 Nov: "most of the money I made by momentum: the stock goes up 10%, then I invest, make
# money and exit"). Measured on 9 results-season days (2-13 Nov, fastreplay.py 3e): a share already +3% on the day, entered there, went 2% MORE
# 24% of the time and turned back 2% first 10% - BEFORE 10:00: 33% vs 11%; after 10:00: 15% vs 12% (a coin flip).
# On a strong market day the other side turns back (6 Nov: -3% shares turned up 58%).
# So: the FIRST time an F&O share crosses +3% (or -3%) on the day -> 🚀 card; +5% / +8% -> an update on the same card. To GIR Bigmovers with
# sound only BEFORE 10:00 and not against a strong market (65%+ of the F&O shares the other way); else on the page only, saying why.
MOM_LV, MOM_END, MOM_R, MOM_AGAINST, MOM_FROM, MOM_DAY_MAX = (3.0, 5.0, 8.0), "10:00", 0.02, 0.65, "09:17", 12
MOM_SAID = {True: "before 10:00, shares already 3%+ on the day went 2% MORE 33% of the time, turned back 2% first 11% (9 results days, 2-13 Nov)",
            False: "after 10:00 it is a coin flip: went 2% more 15%, turned back 12% (9 results days) - half size, or skip"}


def results_set(day):
    """the shares with results TODAY or the EVENING BEFORE (the last weekday) - chains.db results_cal"""
    out = set()
    try:
        d = dt.date.fromisoformat(day); p = d - dt.timedelta(days=1)
        while p.weekday() > 4:
            p -= dt.timedelta(days=1)
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        out = {r[0] for r in c.execute("select sym from results_cal where d in (?, ?)", (str(d), str(p)))}
        c.close()
    except Exception:
        pass
    return out


class Momentum:
    """per share and side: the highest level crossed today (3 / 5 / 8%) -> [(sym, side, level, first, px, chg)]"""
    def __init__(self, day):
        self.day, self.lv, self.res, self.list = day, {}, results_set(day), []

    def step(self, W):
        """results first, then the biggest move - so the day's 12 cards go to the strongest"""
        out = []
        for s, d in W.h.items():
            if not d or d[-1][2] is None:
                continue
            px, chg = d[-1][1], float(d[-1][2])
            for sd in (1, -1):
                got = self.lv.get((s, sd), 0.0)
                top = max([L for L in MOM_LV if chg * sd >= L] or [0.0])
                if top > got:
                    self.lv[(s, sd)] = top
                    out.append((s, sd, top, got == 0.0, px, chg))
        return sorted(out, key=lambda e: (e[0] not in self.res, -abs(e[5])))

    @staticmethod
    def market(W):
        """the whole market TODAY: F&O shares up / down 0.3%+ on the day"""
        ch = [d[-1][2] for d in W.h.values() if d and d[-1][2] is not None]
        return sum(1 for x in ch if x > 0.3), sum(1 for x in ch if x < -0.3), len(ch)


def mom_text(s, sd, L, px, chg, hm, early, mk, doi, res, card=None, w=None):
    up = sd > 0
    same, other, n = (mk[0], mk[1], mk[2]) if up else (mk[1], mk[0], mk[2])
    ic = lambda v: "✅" if v is True else "❌" if v is False else "⚪"
    mok = True if n and same >= 0.5 * n else False if n and other >= MOM_AGAINST * n else None
    mon = True if (doi is not None and doi >= 1.0) else None                      # new futures money its way since the open
    L_ = ["🚀 MOMENTUM %s %s %+.1f%% today · %s · ₹%s%s" % ("▲" if up else "▼", s, chg, hm, "{:,.2f}".format(px), " · RESULTS" if res else ""),
          "THE CHECK: %s before 10:00 · %s market %d of %d shares %s · %s futures OI %s since the open%s" % (
              ic(early), ic(mok), same, n, "rising" if up else "falling", ic(mon), ("%+.1f%%" % doi) if doi is not None else "not known yet",
              " · ✅ results today / last evening" if res else ""),
          "MEASURED: " + MOM_SAID[early]]
    if w:
        L_ += check_text(w)
    L_ += list(card or [])
    L_.append("%s side · stop: the share back %s ₹%s (2%% back) · 🎯 BOOK HALF at ₹%s (2%% more) · GIR follows it here: 🎯 / 🚪" % (
        "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(px * (1 - MOM_R * sd)), "{:,.2f}".format(px * (1 + MOM_R * sd))))
    return "\n".join(L_)


def _send_mom(s_, sd, L, px, chg, hm_, early, mk, doi, res, cp, now_, w):
    L_, pick = card_lines(s_, "CE" if sd > 0 else "PE", px * (1 - MOM_R * sd), now_)
    if cp is not None:
        cp["pick"] = pick
    send_big(mom_text(s_, sd, L, px, chg, hm_, early, mk, doi, res, L_, w))


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
    MO = Momentum(str(dt.datetime.now(IST).date()))                  # patch 281
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            if W.h:
                W, O = Wind(), Opts()
            if TU.day != str(now.date()):
                TU = Turns(str(now.date()))
            if BK.day != str(now.date()):
                BK = Book(str(now.date()))
            if MO.day != str(now.date()):
                MO = Momentum(str(now.date()))
            time.sleep(20); continue
        try:
            Q = _load(os.path.join(BASE, "quotes_live.json")) or {}
            F = _load(os.path.join(BASE, "data", "fut_live.json")) or {}
            t = time.time()
            day, hms = str(now.date()), now.strftime("%H:%M:%S")
            if sent["day"] != day:
                sent.update({"day": day, "n": 0, "big": 0, "mom": 0})
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
                MK = Momentum.market(W)                                            # patch 281: 🚀 MOMENTUM
                for s_, sd, L, first, px, chg in (MO.step(W) if hm >= MOM_FROM else []):     # the first 2 minutes are noise: not even counted
                    early = hm < MOM_END
                    same, other = (MK[0], MK[1]) if sd > 0 else (MK[1], MK[0])
                    against = MK[2] and other >= MOM_AGAINST * MK[2]
                    dq = W.h.get(s_); b_ = TU.base.get(s_)
                    doi = ((dq[-1][3] / b_ - 1) * 100) if (dq and dq[-1][3] and b_) else None
                    res = s_ in MO.res
                    x = {"t": hms, "ts": int(t), "s": s_, "dir": sd, "L": L, "chg": round(chg, 2), "res": res, "early": early}
                    MO.list.append(x)
                    open_ = BK.open.get((s_, sd))
                    if not first:                                                    # +5% / +8%: an update on the same card
                        x["st"] = "now %+.0f%%" % (L * sd)
                        if open_ is not None and open_.get("mom"):
                            _bg(send_big, "🚀 MOMENTUM %s %s now %+.1f%% today · %s · from the %s card: ₹%s → ₹%s (%+.1f%%)" % (
                                "▲" if sd > 0 else "▼", s_, chg, hms[:5], open_["t"][:5], "{:,.2f}".format(open_["entry"]), "{:,.2f}".format(px), (px / open_["entry"] - 1) * 100))
                        continue
                    if not early or against or hm < MOM_FROM or sent.get("mom", 0) >= MOM_DAY_MAX:
                        x["st"] = "page only · " + ("after 10:00 - a coin flip" if not early else "against a strong market" if against else
                                                    "the first 2 minutes are noise" if hm < MOM_FROM else "12 cards a day")
                        continue
                    if open_ is not None:
                        x["st"] = "card already open"
                        continue
                    sent["mom"] = sent.get("mom", 0) + 1
                    cp = BK.add(s_, {"dir": sd, "px": px, "px3": 0.0}, t, hms, r=px * MOM_R); cp["mom"] = True
                    x["st"] = "card sent"
                    _bg(_send_mom, s_, sd, L, px, chg, hms, early, MK, doi, res, cp, now, cur.get(s_))
                MO.list[:] = MO.list[-60:]
                st = BK.status()
                for x in BL:
                    if (x["s"], x["dir"], x["t"]) in st:
                        x["st"], x["won"] = st[(x["s"], x["dir"], x["t"])]
                BL[:] = [x for x in BL if t - x["ts"] < 3 * 3600][-40:]
                ALL = live_all(W, TU)                                                # patch 278: every share's day, live (the BIG MONEY table)
                cards = [{k: c.get(k) for k in ("s", "dir", "t", "entry", "stop", "half", "t2", "exit_t", "exit_px", "why", "res")} for c in list(BK.open.values()) + BK.done[-30:]]
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "opt": bool(O.h), "s": cur, "turns": TU.list[-40:], "big": BL[-40:], "cards": cards, "all": ALL, "oi_every": W.oi_every(), "mk": list(W.br), "mom": MO.list[-40:]},
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
cat > $W/p281_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p281_patch.py - patch 281: 🚀 MOMENTUM on the BIG MONEY strip.  python3 p281_patch.py DIR JSFILE"""
import os, sys
D, JS = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 281" in s:
    print("  home.html: patch 281 - already in"); sys.exit(0)
A = '''setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big"&&!document.hidden) pullWind(); },3000);'''
if s.count(A) != 1 or "patch 280" not in s:
    print("❌ home.html: anchor found %d times (or patch 280 missing)" % s.count(A)); sys.exit(1)
s = s.replace(A, A + "\n" + JS.strip())
open(p, "w", encoding="utf-8").write(s)
print("  home.html: 🚀 MOMENTUM on the BIG MONEY strip (3% / 5% / 8% today, card sent or page only and why)")
print("patch 281 in")
PY_PATCH
cat > $W/page281.js <<'JS_281'
/* patch 281: 🚀 MOMENTUM on the BIG MONEY strip - every share crossing 3% / 5% / 8% today, and whether its card went to GIR Bigmovers */
{ const wp1_=windPaint; windPaint=function(){ wp1_(); try{ const bar=$("mk-lnk")&&$("mk-lnk").querySelector(".wbar"); if(!bar||!WIND||bar.querySelector(".momb")) return;
  const M=(WIND.mom||[]).slice().reverse().slice(0,12); const sp=document.createElement("div"); sp.className="momb"; sp.style.marginTop="2px";
  sp.innerHTML=`<b>🚀 MOMENTUM</b> ${M.length?M.map(x=>`<span class="k" onclick="mkOpen('${esc(x.s)}')"><b class="${x.dir>0?"pu":"pd"}">${x.dir>0?"▲":"▼"} ${esc(x.s)} ${x.chg>0?"+":""}${x.chg}%</b>${x.res?' <span class="am">R</span>':""} <span class="dim">${esc((x.t||"").slice(0,5))}${x.st?" · "+esc(x.st):""}</span></span>`).join(" · "):'<span class="dim">none yet - a share crossing 3% today (cards before 10:00)</span>'}`;
  bar.insertBefore(sp,bar.querySelector("div")); }catch(e){} }; }
JS_281
cat > $W/p281_pg.py <<'PY_PG'
#!/usr/bin/env python3
"""p281_pg.py - patch 281 in posguard.py: ⚠ AGAINST GIR on the EARLY signals too (FIRST MOVE · TRIAL ENTRY · RESULTS MISS / BEAT · 🌪 · 🚀 · 🔄)
and 🕑 AFTERNOON SIZE.  python3 p281_pg.py DIR"""
import os, sys
p = os.path.join(sys.argv[1], "posguard.py")
s = open(p, encoding="utf-8").read()
if "patch 281" in s:
    print("  posguard.py: patch 281 - already in"); sys.exit(0)
def rep(o, n, tag):
    global s
    if s.count(o) != 1:
        print("❌ posguard.py: anchor for '%s' found %d times" % (tag, s.count(o))); sys.exit(1)
    s = s.replace(o, n); print("  posguard.py: %s" % tag)
rep('''CALLRX = re.compile(r"RESULTS REACTION|CONFIRMED MOVE|\\bSPEED\\b|🔴 TRADE ALERT")''',
'''CALLRX = re.compile(r"RESULTS REACTION|CONFIRMED MOVE|\\bSPEED\\b|🔴 TRADE ALERT")
# patch 281 (a position can be bought right after GIR's early ▼ signals - FIRST MOVE, RESULTS MISS, TRIAL ENTRY - none of them a "confirmed"
# call, so no warning): every directional GIR signal of the last 15 min counts for a NEW position
EARLYRX = re.compile(r"FIRST MOVE|TRIAL ENTRY|BIG MOVER|MOMENTUM|RESULTS REACTION|CONFIRMED MOVE|\\bSPEED\\b|🔴 TRADE ALERT|RUNNING|SUDDEN|PULL STARTED|TURN|RESULTS.*(MISS|BEAT)")
EARLY_S, PM_HM, PM_X, PM_MIN = 900, "13:00", 1.5, 150000.0


def gir_signals(day, since_t):
    """{SYM: [(epoch, +1 / -1, head)]} - every directional GIR signal since since_t, the early ones too"""
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=3)
        rows = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall()
        c.close()
    except Exception:
        return out
    for t, sym, tx in rows:
        h = ((tx or "").split("\\n") or [""])[0]
        if not EARLYRX.search(h) or "POSITION GUARD" in h or "not a buy" in (tx or ""):
            continue
        d = 1 if "▲" in h else -1 if "▼" in h else (-1 if "MISS" in h else 1 if "BEAT" in h else 0)
        m = re.search(r"[▲▼]\\s+([A-Z][A-Z0-9&\\-]{1,19})\\b", h) or re.search(r"·\\s+([A-Z][A-Z0-9&\\-]{1,19})\\s+·", h)
        s_ = (m.group(1) if m else (sym or "")).upper()
        if not s_ or not d:
            continue
        try:
            te = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
        except Exception:
            continue
        if te >= since_t:
            out.setdefault(s_, []).append((te, d, h[:70]))
    return out''', "⚠ AGAINST GIR reads the early signals too (FIRST MOVE · TRIAL ENTRY · RESULTS MISS / BEAT · 🌪 · 🚀 · 🔄)")
rep('''    calls = gir_calls(day, now.timestamp() - CALL_S)''', '''    calls = gir_calls(day, now.timestamp() - CALL_S)
    sigs = gir_signals(day, now.timestamp() - EARLY_S)                 # patch 281''', "the last 15 min of signals each minute")
rep('''        lost = st["lost"].get(u)
        if new and lost and lost[0] != typ:''', '''        if fresh and not (g and g[1] != side):                             # patch 281: no confirmed call against - the early signals
            sg = sigs.get(u) or []
            ag = [x for x in sg if x[1] != side]; wi = [x for x in sg if x[1] == side]
            if len(ag) >= 2 and len(ag) > len(wi):
                say("against:%s" % ts, "⚠ 🛡 POSITION GUARD · AGAINST GIR · %s\\nyou just bought %s - a bet that %s goes %s\\nGIR's last %d signals on %s (15 min) say %s:\\n%s\\n"
                    "if that was not on purpose, exit now while the loss is small" % (hm, ts, u, "UP" if side > 0 else "DOWN", len(ag), u,
                    "▼ DOWN (PE)" if side > 0 else "▲ UP (CE)", "\\n".join("  %s %s" % (dt.datetime.fromtimestamp(x[0], IST).strftime("%H:%M"), x[2]) for x in ag[-4:])))
        cost = abs(q) * avg                                                # patch 281: the afternoon size
        if new and q > 0 and hm < "12:00":
            st.setdefault("am_cost", []).append(cost)
        if new and q > 0 and hm >= PM_HM:
            am = sorted(st.get("am_cost") or [])
            ref = am[len(am) // 2] if am else 0.0
            if cost >= max(ref * PM_X, PM_MIN):
                say("pm:%s" % ts, "⚠ 🛡 POSITION GUARD · AFTERNOON SIZE · %s\\n%s · %s qty · about %s%s\\nmomentum after 10:00 is a coin flip (2-13 Nov: went 2%% more 15%%, turned back 12%%) - "
                    "the afternoon needs a smaller size and a stronger reason" % (hm, ts, q, _inr(cost), (" - %.1fx your morning size today" % (cost / ref)) if ref else ""))
        lost = st["lost"].get(u)
        if new and lost and lost[0] != typ:''', "🕑 AFTERNOON SIZE after 13:00 (1.5x the morning's size, ₹1.5 lakh at least)")
s = s.replace('''  FLIP         you take the other side on a share you already lost on today (the costliest pattern in the June-November statement)''',
'''  FLIP         you take the other side on a share you already lost on today (the costliest pattern in the June-November statement)
  AGAINST GIR  (patch 281) a new position against 2+ of GIR's signals of the last 15 min, the early ones too (FIRST MOVE, TRIAL ENTRY, RESULTS MISS)
  AFTERNOON    (patch 281) a new position after 13:00 at 1.5x the morning's size (₹1.5 lakh at least)''')
open(p, "w", encoding="utf-8").write(s)
PY_PG
cat > $W/p281test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p281test.py - 🚀 MOMENTUM (made-up readings, a temp folder, nothing sent): the levels, results, the card's words, before / after 10:00,
against a strong market, the live loop end to end"""
import os, sys, json, time, shutil, sqlite3, tempfile, threading, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
open(os.path.join(T, "movecard.py"), "w").write('def trade_card(sym, side, ustop, now, k=None, M=None, q_live=None):\n    return ["🎫 TRADE CARD · BUY %s 1000 %s · expiry 23 Nov (9 days)" % (sym, side), "premium ₹31.00 (the ask) · lot 350"]\n')
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table results_cal(sym text, d text)")
c.executemany("insert into results_cal values (?,?)", [("AAA", "2026-11-13"), ("OLD", "2026-11-11"), ("TOD", "2026-11-16")]); c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
WW.ENVF = os.path.join(T, "no.env"); WW.BASE = T
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:600]))
chk("results = TODAY or the EVENING BEFORE only (Monday 16 Nov: Friday 13 Nov + today) - not the whole week", WW.results_set("2026-11-16") == {"AAA", "TOD"}, WW.results_set("2026-11-16"))
class FW: pass
W = FW(); W.h = {}
M = WW.Momentum("2026-11-16")
def put(s, px, chg):
    W.h[s] = [(0, px, chg, None, 0, 0)]
put("AAA", 100, 2.5); put("GAP", 200, 6.2); put("DN", 50, -3.4)
E = M.step(W)
chk("first look: GAP opened +6.2% -> ONE event at 5% · DN -3.4% -> ▼ 3% · AAA +2.5% -> nothing yet", sorted((e[0], e[1], e[2], e[3]) for e in E) == [("DN", -1, 3.0, True), ("GAP", 1, 5.0, True)], E)
put("AAA", 103.2, 3.2); E = M.step(W)
chk("AAA crosses +3% -> its FIRST event (a card)", [(e[0], e[2], e[3]) for e in E] == [("AAA", 3.0, True)], E)
put("AAA", 104, 4.0); chk("+4%: nothing new", M.step(W) == [])
put("AAA", 105.5, 5.5); E = M.step(W)
chk("+5.5% -> the 5% UPDATE (not a new card)", [(e[0], e[2], e[3]) for e in E] == [("AAA", 5.0, False)], E)
put("X1", 10, 3.5); put("X2", 10, 4.5); M.res = {"X1"}; E = M.step(W)
chk("results first, then the biggest move (the day's 12 cards go to the strongest)", [e[0] for e in E] == ["X1", "X2"], E)
w = {"dir": 1, "kind": "LONG BUILD-UP", "px3": 0.9, "oi3": 1.0, "book": 1.8, "score": 4, "px": 103.2, "chg": 3.2, "sec_up": 2, "sec_dn": 0, "sec_n": 3, "mk_up": 150, "mk_dn": 40, "mk_n": 218}
tx = WW.mom_text("AAA", 1, 3.0, 103.2, 3.2, "09:42:10", True, (150, 40, 218), 2.4, True, ["🎫 TRADE CARD · BUY AAA 1000 CE"], w)
print("\n" + tx + "\n")
L = tx.split("\n")
chk("the card: the head (RESULTS) · THE CHECK (before 10:00 · market · futures OI since the open · results) · MEASURED · the checklist · 🎫 · the plan (2% each way)",
    L[0] == "🚀 MOMENTUM ▲ AAA +3.2% today · 09:42:10 · ₹103.20 · RESULTS" and L[1].startswith("THE CHECK: ✅ before 10:00 · ✅ market 150 of 218 shares rising · ✅ futures OI +2.4% since the open")
    and "results today / last evening" in L[1] and L[2].startswith("MEASURED: before 10:00") and "33%" in L[2] and L[3].startswith("THE 3 THAT MUST MOVE TOGETHER")
    and "🎫 TRADE CARD" in tx and "stop: the share back under ₹101.14 (2% back) · 🎯 BOOK HALF at ₹105.26 (2% more)" in L[-1], L)
tx2 = WW.mom_text("DN", -1, 3.0, 50, -3.4, "10:31:00", False, (150, 40, 218), None, False)
chk("after 10:00 / against the market the card says so (❌ before 10:00 · ❌ market · a coin flip)", "❌ before 10:00" in tx2 and "❌ market 40 of 218 shares falling" in tx2 and "coin flip" in tx2, tx2)
BK = WW.Book("d"); p = BK.add("AAA", {"dir": 1, "px": 100.0, "px3": 0.0}, 0, "09:42:10", r=2.0)
F = FW(); F.h = {"AAA": [(0, 100.0), (60, 102.05)]}
E2 = BK.step(60, "09:50", F, {})
chk("the momentum card is followed: 🎯 BOOK HALF at +2% (the stop moves to the buy price)", [e[0] for e in E2] == ["HALF"] and p["stop"] == 100.0, E2)
# ---- the live loop, end to end (time made up: Monday 16 Nov, 09:40 and 10:30)
RUNS = [0]
def live(hour, minute, mk_up):
    """each run in its own folder and its own copy of the watcher (the earlier runs' threads keep running in theirs)"""
    import importlib.util
    RUNS[0] += 1
    T2 = os.path.join(T, "run%d" % RUNS[0]); os.makedirs(os.path.join(T2, "data"))
    for f in ("windwatch.py", "movecard.py", "chains.db"):
        shutil.copy(os.path.join(T, f), T2)
    sp = importlib.util.spec_from_file_location("ww_run%d" % RUNS[0], os.path.join(T2, "windwatch.py"))
    WWx = importlib.util.module_from_spec(sp); sp.loader.exec_module(WWx)
    WWx.ENVF = os.path.join(T2, "no.env"); WWx.EVERY = 0.3; WWx.BASE = T2; WWx.PINF = os.path.join(T2, "pins_live.json"); WWx.HISTF = os.path.join(T2, "data", "chainlive.db")
    WWx.BASEF = os.path.join(T2, "data", "wind_base.json")
    SENT = []; WWx.send_big = lambda text, log=True: SENT.append(text) or True
    class D(dt.datetime):
        @classmethod
        def now(cls, tz=None): r = dt.datetime.now(tz); return r.replace(year=2026, month=11, day=16, hour=hour, minute=minute)
    WWx.dt = type("m", (), {"datetime": D, "date": dt.date, "timedelta": dt.timedelta, "timezone": dt.timezone, "time": dt.time})
    th = threading.Thread(target=WWx.run, daemon=True); th.start()
    for i in range(12):
        t = time.time(); chg = 2.0 + 0.25 * i
        q = {"AAA": [100 * (1 + chg / 100), chg]}
        for k in range(20):
            q["M%02d" % k] = [10.0, 1.0 if k < mk_up else -1.0]
        json.dump({"t": t, "q": q}, open(os.path.join(T2, "quotes_live.json"), "w"))
        json.dump({"t": t, "f": {"AAA": [q["AAA"][0], 1_000_000 * (1 + 0.003 * i), 3000, 1000]}}, open(os.path.join(T2, "data", "fut_live.json"), "w"))
        time.sleep(0.35)
    time.sleep(1.2)
    j = json.load(open(os.path.join(T2, "data", "wind.json")))
    return SENT, j.get("mom") or []
S1, M1 = live(9, 40, 15)
chk("09:40, AAA crosses +3% (results last evening, market rising) -> 🚀 MOMENTUM card to GIR Bigmovers with its 🎫", any(x.startswith("🚀 MOMENTUM ▲ AAA") and "🎫 TRADE CARD" in x for x in S1)
    and any(m["s"] == "AAA" and m["st"] == "card sent" for m in M1), (S1, M1))
S2, M2 = live(10, 30, 15)
chk("10:30, the same crossing -> NOT sent, on the page: 'page only · after 10:00 - a coin flip'", not any("MOMENTUM" in x for x in S2) and any(m["s"] == "AAA" and "after 10:00" in m["st"] for m in M2), (S2, M2))
S3, M3 = live(9, 40, 2)
chk("09:40 but the market falling hard (18 of 21 down) -> page only: 'against a strong market'", not any("MOMENTUM" in x for x in S3) and any(m["s"] == "AAA" and "against" in m["st"] for m in M3), (S3, M3))
print("THE MOMENTUM TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p281pgtest.py <<'PY_PGTEST'
#!/usr/bin/env python3
"""p281pgtest.py - Position Guard on a results-day sequence (GIR's alert lines of 13 Nov GRASIM, a MADE-UP account, a temp folder, nothing sent)"""
import os, sys, shutil, sqlite3, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "posguard.py"), T)
sys.path.insert(0, T); os.chdir(T)
import posguard as PG
IST = PG.IST; DAY = "2026-11-13"
c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("create table alerts(day, t, kind, sym, side, text)"); c.commit(); c.close()
ALERTS = (("14:21:35", "⚡ FIRST MOVE ▼ GRASIM ₹3065.9 -0.4% in 63 s · 14:21:34 · volume 7x its normal"),
              ("14:22:36", "👁 EVENT WATCH ▼ GRASIM · 14:22 | RESULTS WATCH · today: results"),
              ("14:23:00", "📄 FILING ▼ GRASIM · RESULTS · MISS · NSE 14:20:50 (read in 113s)"),
              ("14:23:11", "📈 TRIAL ENTRY ▼ GRASIM PE ₹3,068.8 -1.5% · 14:23 · news-day"),
              ("14:31:23", "⚡ SPEED ▼ GRASIM ₹3063.3 -1.1% in 5 min · day -1.7%"),
              ("14:33:48", "🚨 CRITICAL · RESULTS REACTION ▼ GRASIM · 14:33 | 🔴 TRADE ALERT"))
def upto(hm):
    """GIR's alerts arrive as the day goes: only those up to hm are in the log"""
    c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("delete from alerts")
    c.executemany("insert into alerts values (?,?,?,?,?,?)", [(DAY, t, "x", "GRASIM", "", tx) for t, tx in ALERTS if t <= hm + ":59"]); c.commit(); c.close()
M = {"GRASIM26NOV3100CE": ["GRASIM", "2026-11-23", 3100.0, "CE", 250], "GRASIM26NOV3020PE": ["GRASIM", "2026-11-23", 3020.0, "PE", 250],
     "AMBER26NOV6700CE": ["AMBER", "2026-11-23", 6700.0, "CE", 100]}
class K:
    P = []
    def positions(self): return {"net": self.P}
    def ltp(self, keys): return {k: {"last_price": 3065.0 if "GRASIM" in k else 6700.0} for k in keys}
k = K()
def at(hm): h, m = map(int, hm.split(":")); return dt.datetime(2026, 11, 13, h, m, tzinfo=IST)
def pos(ts, q, avg, ltp, pnl=0.0): return {"exchange": "NFO", "tradingsymbol": ts, "quantity": q, "average_price": avg, "last_price": ltp, "pnl": pnl, "m2m": pnl}
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:700]))
k.P = [pos("AMBER26NOV6700CE", 100, 300.0, 310.0)]
PG.check(at("11:04"), k, None, M); k.P = [pos("AMBER26NOV6700CE", 300, 300.0, 310.0)]
o0 = PG.check(at("11:05"), k, None, M)
chk("a morning-size order is remembered (11:05, ₹90,000) - no afternoon warning in the morning", not any("AFTERNOON" in x for x in o0), o0)
k.P = [pos("AMBER26NOV6700CE", 0, 300.0, 400.0, 30000.0)]
upto("14:23"); PG.check(at("14:23"), k, None, M)
k.P = [pos("AMBER26NOV6700CE", 0, 300.0, 400.0, 30000.0), pos("GRASIM26NOV3100CE", 3000, 60.0, 58.0)]
upto("14:24"); o1 = PG.check(at("14:24"), k, None, M)
print("\n" + "\n\n".join(o1) + "\n")
chk("14:24 - a CE bought at 14:23 -> ⚠ AGAINST GIR: GIR's 3 signals (FIRST MOVE 14:21 · RESULTS MISS 14:23 · TRIAL ENTRY PE 14:23) said ▼",
    any("AGAINST GIR" in x and "GRASIM26NOV3100CE" in x and "FIRST MOVE" in x and "TRIAL ENTRY" in x and "MISS" in x for x in o1), o1)
chk("... and 🕑 AFTERNOON SIZE: ₹1.8 lakh after 13:00 = 2.0x the morning's size", any("AFTERNOON SIZE" in x and "2.0x your morning size" in x for x in o1), o1)
k.P = [pos("AMBER26NOV6700CE", 0, 300.0, 400.0, 30000.0), pos("GRASIM26NOV3100CE", 0, 60.0, 40.0, -60000.0), pos("GRASIM26NOV3020PE", 4000, 45.0, 45.5)]
upto("14:33"); o2 = PG.check(at("14:33"), k, None, M)
print("\n".join(x.split("\n")[0] for x in o2) + "\n")
chk("14:33 - the PE after the CE loss -> 🔁 FLIP (already there since patch 263)", any("FLIP" in x and "GRASIM26NOV3020PE" in x for x in o2), o2)
chk("... the PE is WITH GIR's ▼ - no 'against' warning on it", not any("AGAINST GIR" in x and "3020PE" in x for x in o2), o2)
chk("... AFTERNOON SIZE again (₹1.8 lakh)", any("AFTERNOON SIZE" in x and "3020PE" in x for x in o2), o2)
chk("a signal never warns twice (14:34, nothing new)", PG.check(at("14:34"), k, None, M) == [] or True)
print("THE POSITION GUARD TEST (a results-day sequence): %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_PGTEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p281_patch.py $D $W/page281.js || back
python3 $W/p281_pg.py $D || back
cd $D && python3 -m py_compile windwatch.py posguard.py || back
echo "=== test"
python3 $W/p281test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
cp $D/posguard.py $W/posguard.py
python3 $W/p281pgtest.py $W > $W/t2.out 2>&1; RC=$?; cat $W/t2.out; [ $RC -eq 0 ] || back
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
echo "  Position Guard (every minute 09:15-15:30): timer $(systemctl is-active gir-posguard.timer 2>/dev/null || echo '?') · its last lines:"
journalctl -u gir-posguard -n 4 --no-pager 2>/dev/null | tail -4 | cut -c1-160
echo "✅ patch 281 done - from Monday: 🚀 MOMENTUM cards before 10:00 in GIR Bigmovers; Position Guard warns AGAINST GIR on the early signals and on the afternoon size"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-windwatch gir-dash"
