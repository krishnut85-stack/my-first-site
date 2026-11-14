#!/bin/bash
# PATCH 278 - 🎫 THE CARD ON EVERY BIG MOVER, FOLLOWED TO THE EXIT · THE OPTION WRITERS EVERY 5 s · THE BIG MONEY TABLE LIVE (Rama, 14 Nov: "when the
#   futures are investing and disinvesting the shares are definitely going up and down - GIR should find it in time and alert me, then we invest,
#   make money and exit" · "even these pages should update in seconds"). No new socket, no new Kite app: the engine already writes every pinned
#   strike (11 nearest the price, CE + PE, all 218 shares) to pins_live.json every 5 s (patch 79) - only the desk read it.
#   · windwatch.py: reads the strikes every 5 s -> CE OI vs PE OI near the price in 3 min (who is writing) on every live line and card;
#     🌪 BIG MOVER carries the 🎫 TRADE CARD (strike, premium, lots for your risk) - not sent when the writers fight it (shown on the page);
#     each card is followed every 3 s: 🎯 BOOK HALF at 1x the risk (stop to the buy price) · 🎯 TARGET 2 at 2x · 🚪 EXIT when the futures money
#     leaves (3 readings in a row), at the stop, at 15:10 - all to GIR Bigmovers with sound; 30 cards a day at most; every card + result ->
#     tomorrow.db wind_cards (python3 windwatch.py cards); the strikes once a minute -> data/chainlive.db (10 days)
#   · home.html: BIG MONEY's table - price, futures build-up, fresh ₹, futures OI and the score - live every 3 s (● live); the writers on the
#     LIVE column; each 🌪 card's state on the strip (open · ½ booked · exit +x%)
#   Tested: 18 cases + the old 7 (turns) + 8 (wind). Restarts the wind watcher and the page server - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 277" $D/home.html && grep -q "def big_movers" $D/windwatch.py || { echo "patch 277 first"; exit 1; }
if grep -q "patch 278" $D/home.html && grep -q "class Opts" $D/windwatch.py; then echo "patch 278 - already in"; exit 0; fi
[ -f $D/pins_live.json ] || echo "  note: pins_live.json not there yet - the engine writes it from 09:16 (patch 79); the writers show from then"
F="windwatch.py home.html"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-windwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel · 278: the option writers every 5 s, the 🎫 card on every big mover, then 🎯 BOOK HALF / 🚪 EXIT): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
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

    def feed(self, t, q, f):
        """q: {sym: [px, chg%]} (quotes_live) · f: {sym: [fut px, fut OI, buy qty, sell qty]} (fut_live)"""
        for s, v in (q or {}).items():
            if not isinstance(v, (list, tuple)) or not v or not v[0]:
                continue
            x = (f or {}).get(s) or [None, None, 0, 0]
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
                      "sec": sec, "sec_up": up, "sec_dn": dn, "sec_n": len(peers), "score": int(score), "px": new[1], "chg": new[2]}
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


def turn_text(x):
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
        ("for you: %s holders - watch it closely; if it turns fully GIR says 🔄 TURNED" % ("PE" if up else "CE"))])


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


def big_text(s, w, hm, card=None):
    """patch 278: the move, the new money, the writers, the book, the sector - then the 🎫 card and the plan (GIR follows it to the exit)"""
    up = w["dir"] > 0
    b = w.get("book")
    book = (" · buyers %.1fx sellers waiting" % b if b >= 1 else " · sellers %.1fx buyers waiting" % (1 / b)) if b else ""
    sec = (" · its sector %d of %d %s" % (w["sec_up"] if up else w["sec_dn"], w["sec_n"], "up" if up else "down")) if w.get("sec_n") else ""
    stop = w["px"] / (1 + w["px3"] / 100)
    L = ["🌪 BIG MOVER %s %s · %s" % ("▲" if up else "▼", s, hm),
         "price %+.1f%% in 3 min (₹%s · %+.1f%% today) · futures OI %+.1f%% (%s)%s%s · wind %d/4" % (
             w["px3"], "{:,.2f}".format(w["px"]), w.get("chg") or 0, w.get("oi3") or 0, "new buyers" if up else "new sellers", book, sec, w["score"])]
    if w.get("ce3") is not None:
        L.append(opt_words(w))
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
                p.update({"exit_t": hm, "exit_px": px, "why": ev, "res": round(mv / p["entry"] * 100, 2)})
                self.done.append(p)
                out.append(("EXIT", p, px, ev))
                continue
            if not p["half"] and mv >= HALF_X * p["r"]:
                p["half"], p["stop"] = True, p["entry"]
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


def follow_text(kind, p, px, words, O=None):
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
                NT = TU.step(t, hms, W, cur)          # patch 276: the turns
                p = os.path.join(BASE, "data", "wind.json")
                for kind, cp, px, words in BK.step(t, hm, W, cur, O):     # patch 278: the cards followed
                    _bg(send_big, follow_text(kind, cp, px, words, O))
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
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "opt": bool(O.h), "s": cur, "turns": TU.list[-40:], "big": BL[-40:], "cards": cards, "all": ALL},
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
                            _bg(_send_turn, turn_text(x))
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
        print("wind.json: %s · futures data %s" % (("%.0f s old" % age) if j else "not written yet (from 09:15 on a trading day)", "in" if j.get("fut") else "not in yet"))
        for s, w in sorted((j.get("s") or {}).items(), key=lambda x: -x[1]["score"])[:15]:
            print("  %-11s %s" % (s, line(w)))
PY_WW
cat > $W/p278_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p278_patch.py - patch 278: the BIG MONEY table live every 3 s + the writers + each 🌪 card's state on the strip.  python3 p278_patch.py DIR JSFILE"""
import os, sys
D, JS = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 278" in s:
    print("  home.html: patch 278 - already in"); sys.exit(0)
A1 = '''<span class="dim">${esc(x.t.slice(0,5))}</span></span>`).join(" · "):'<span class="dim">none yet</span>'} · <b>🔄 TURNS</b>'''
N1 = '''<span class="dim">${esc(x.t.slice(0,5))}</span>${x.st?` <i class="${x.won>0?"pu":x.won<0?"pd":"dim"}">${esc(x.st)}</i>`:""}</span>`).join(" · "):'<span class="dim">none yet</span>'} · <b>🔄 TURNS</b>'''
A2 = '''setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big"&&!document.hidden) pullWind(); },3000);'''
for a, tag in ((A1, "each 🌪 card's state (open · ½ booked · exit +x%)"), (A2, "the table live every 3 s")):
    if s.count(a) != 1:
        print("❌ home.html: anchor for '%s' found %d times" % (tag, s.count(a))); sys.exit(1)
s = s.replace(A1, N1)
s = s.replace(A2, A2 + "\n" + JS.strip())
open(p, "w", encoding="utf-8").write(s)
print("  home.html: each 🌪 card's state on the strip")
print("  home.html: BIG MONEY table - price, build-up, fresh ₹, futures OI, score live every 3 s · the option writers on the LIVE column")
print("patch 278 in")
PY_PATCH
cat > $W/page278.js <<'JS_278'
/* patch 278: the BIG MONEY table itself LIVE every 3 s - price, futures build-up, fresh ₹ and futures OI from the engine's own ticks (OI vs today's
   first reading = yesterday's close OI), the score's futures part with them; the option writers on the LIVE column; each 🌪 card's state */
const BUC={"long build-up":2,"short covering":1,"short build-up":-2,"long unwinding":-1};
(function(){ const st=document.createElement("style"); st.textContent=".lv{color:#3ddc84;font-size:9px;vertical-align:middle}"; document.head.appendChild(st); })();
function liveRows(){ const el=$("mk-lnk"); if(!el||!WIND||!WIND.all||!LNK) return; if(Date.now()/1000-(WIND.t||0)>60) return;
  const A=WIND.all, R={}; (LNK.rows||[]).forEach(x=>{ R[x.s]=x; });
  const c=v=>v>0?"pu":v<0?"pd":"dim", rs=v=>`${v>0?"+":"−"}₹${Math.abs(Math.round(v)).toLocaleString("en-IN")} cr`;
  el.querySelectorAll("table tr.k").forEach(tr=>{ const m=/mkOpen\('([^']+)'\)/.exec(tr.getAttribute("onclick")||""); if(!m) return;
    const a=A[m[1]], x=R[m[1]]; if(!a||!x) return; const td=tr.children; if(td.length<9) return;
    const chg=a[0], doi=a[1], cr=a[2];
    const bu=(chg==null||Math.abs(doi)<0.05)?null:(chg>=0?(doi>0?"long build-up":"short covering"):(doi>0?"short build-up":"long unwinding"));
    const set=(i,h,cl)=>{ if(td[i]._h!==h){ td[i]._h=h; td[i].innerHTML=h; } td[i].className=cl; };
    if(chg!=null) set(1,(chg>0?"+":"")+chg.toFixed(2)+"%",c(chg));
    if(bu){ set(2,bu+' <span class="lv">●</span>',c(BUC[bu])); set(3,rs(cr),c(cr)); set(4,(doi>0?"+":"")+doi.toFixed(1)+"%",c(doi));
      const o=BUC[(x.bu||"").toLowerCase()]||0, n=BUC[bu], sc=(x.sc||0)-o+n; set(7,`<b>${sc>0?"+":""}${sc}</b>`,c(sc));
      if(o&&Math.sign(o)!==Math.sign(n)) set(8,`<b>FUTURES ${n>0?"▲":"▼"} · live</b>`,n>0?"pu":"pd"); } });
  const hr=el.querySelector("table tr"); if(hr&&!hr.querySelector(".lv")&&hr.children[2]) hr.children[2].innerHTML+=' <span class="lv">● live 3 s</span>'; }
{ const wp8_=windPaint; windPaint=function(){ wp8_(); try{ liveRows(); }catch(e){} }; }
{ const wc8_=windCell; windCell=function(w){ let h=wc8_(w); if(w&&w.ce3!=null) h+=` <span class="${w.opt===true?"pu":w.opt===false?"pd":"dim"}">· writers ${w.opt===true?"✓":w.opt===false?"✗":"~"} CE ${w.ce3>0?"+":""}${w.ce3}% PE ${w.pe3>0?"+":""}${w.pe3}%</span>`; return h; }; }
JS_278
cat > $W/p278test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p278test.py - the option writers every 5 s · the 🎫 card on every 🌪 · 🎯 BOOK HALF / 🚪 EXIT · the live table (made-up readings, temp folder, nothing sent)"""
import os, sys, json, shutil, tempfile, sqlite3, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
open(os.path.join(T, "movecard.py"), "w").write('''def trade_card(sym, side, ustop, now, k=None, M=None, q_live=None):
    return ["🎫 TRADE CARD · BUY %s 1060 %s · expiry 23 Nov (9 days)" % (sym, side), "premium ₹31.00 (the ask · spread 1.2%) · lot 350 · 1 lot ₹10,850",
            "your risk ₹10,000 → 2 lots = 700 qty · cost ₹21,700"]
''')
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
WW.ENVF = os.path.join(T, "no.env")
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:500]))
t0 = 1_800_000_000.0
def pins(t, ce, pe, spot=1050.0, prem=31.0):
    rows = []
    for k in (1020, 1040, 1060, 1080, 1100):
        rows += [["2026-11-23", float(k), "CE", ce, prem if k == 1060 else 5.0, int(t)], ["2026-11-23", float(k), "PE", pe, 4.0, int(t)]]
    rows.append(["2026-12-29", 1060.0, "CE", 999999, 60.0, int(t)])
    return {"t": t, "spot": {"POLICYBZR": spot}, "rows": {"POLICYBZR": rows}}
O = WW.Opts()
for i in range(0, 200, 5):
    O.feed(pins(t0 + i, 100000 - i * 20, 100000 + i * 30), t0 + i)
o = O.read("POLICYBZR", t0 + 195, 1050.0)
chk("the writers from the 5-s strikes: CE OI falling, PE OI rising on the 6 strikes nearest the price (nearest expiry only)", o and o["ce3"] < -2 and o["pe3"] > 3, o)
chk("a rise backed by the writers (put writers add, call writers cover) · a fall the same picture = against · close = no side",
    WW.opt_agree(1, o["ce3"], o["pe3"]) is True and WW.opt_agree(-1, o["ce3"], o["pe3"]) is False and WW.opt_agree(1, 1.0, 1.5) is None)
chk("the same 5-s reading twice is read once; an old file (40 s+) is not read", O.feed(pins(t0 + 195, 1, 1), t0 + 195) is False and O.feed(pins(t0 + 100, 1, 1), t0 + 300) is False)
chk("the card's premium from the 5-s strikes (that expiry, that strike)", O.prem("POLICYBZR", "2026-11-23", 1060, "CE") == 31.0)
w = {"dir": 1, "kind": "LONG BUILD-UP", "px3": 1.1, "oi3": 1.6, "book": 2.3, "score": 4, "px": 1049.0, "chg": 3.2, "sec_up": 3, "sec_dn": 0, "sec_n": 4}
WW.opt_into({"POLICYBZR": w}, O, t0 + 195)
chk("the writers go onto the share's live line (and so onto the MOVE CARD's who-line)", w.get("opt") is True and "put writers back the rise" in WW.line(w), WW.line(w))
L, pick = WW.card_lines("POLICYBZR", "CE", 1037.6, dt.datetime(2026, 11, 16, 9, 19, tzinfo=WW.IST))
chk("the 🎫 card is read back: expiry, strike, premium (to follow its premium to the exit)", pick == ("2026-11-23", 1060.0, 31.0), pick)
tx = WW.big_text("POLICYBZR", w, "09:19:42", L)
print("\n" + tx + "\n")
chk("🌪 BIG MOVER now carries the writers, the 🎫 card and the plan (half size · the stop · GIR follows it to the exit)",
    tx.startswith("🌪 BIG MOVER ▲ POLICYBZR · 09:19:42") and "options CE OI" in tx and "🎫 TRADE CARD · BUY POLICYBZR 1060 CE" in tx and "HALF your usual size" in tx
    and "back under ₹1,037.59" in tx and "🎯 BOOK HALF · 🚪 EXIT" in tx, tx)
# the card followed
class FakeW: pass
FW = FakeW(); FW.h = {"POLICYBZR": [(t0, 1049.0)]}
BK = WW.Book("2026-11-16")
p = BK.add("POLICYBZR", w, t0, "09:19:42"); p["pick"] = pick
r = p["r"]
FW.h["POLICYBZR"].append((t0 + 60, 1049.0 + r * 0.5))
chk("half way to target 1: nothing said", BK.step(t0 + 60, "09:20", FW, {}) == [])
FW.h["POLICYBZR"].append((t0 + 120, 1049.0 + r * 1.05))
E = BK.step(t0 + 120, "09:21", FW, {})
chk("🎯 BOOK HALF at 1x the risk · the stop moves to the buy price", [e[0] for e in E] == ["HALF"] and p["stop"] == p["entry"], E)
O.feed(pins(t0 + 200, 90000, 120000, prem=40.3), t0 + 200)
ht = WW.follow_text("HALF", p, 1049.0 + r * 1.05, E[0][3], O)
print("\n" + ht + "\n")
chk("its words: the share since the card, the option's premium now vs the card's, what to do", "from the 09:19 🌪 card: share ₹1,049.00" in ht and "1060 CE premium ₹40.30 (card ₹31.00: +30%)" in ht and "sell half now" in ht, ht)
leave = {"POLICYBZR": {"dir": -1, "kind": "LONG UNWINDING", "px3": -0.6, "oi3": -0.9, "score": 2}}
FW.h["POLICYBZR"].append((t0 + 123, 1049.0 + r * 1.0))
a = BK.step(t0 + 123, "09:21", FW, leave); FW.h["POLICYBZR"].append((t0 + 126, 1049.0 + r * 0.9)); b = BK.step(t0 + 126, "09:21", FW, leave)
FW.h["POLICYBZR"].append((t0 + 129, 1049.0 + r * 0.8)); c = BK.step(t0 + 129, "09:21", FW, leave)
chk("🚪 EXIT when the futures money leaves (buyers unwinding 3 readings in a row = 9 s) - not on the first reading", a == [] and b == [] and [e[0] for e in c] == ["EXIT"] and "buyers unwinding" in c[0][3], (a, b, c))
xt = WW.follow_text("EXIT", c[0][1], c[0][2], c[0][3], O)
print("\n" + xt + "\n")
chk("the exit says why and 'sell it all now'; the card is closed with its result", xt.startswith("🚪 EXIT ▲ POLICYBZR CE") and "sell the rest now" in xt and not BK.open and BK.done[0]["res"] > 0, xt)
BK2 = WW.Book("d"); p2 = BK2.add("AAA", dict(w, px=100.0, px3=1.0), t0, "10:00:00"); FW.h["AAA"] = [(t0, 100.0), (t0 + 3, 98.9)]
s2 = BK2.step(t0 + 3, "10:00", FW, {})
chk("🚪 EXIT at the stop: the share back under where the move began", [e[0] for e in s2] == ["EXIT"] and "the move failed" in s2[0][3], s2)
BK3 = WW.Book("d"); BK3.add("BBB", dict(w, px=100.0, px3=1.0), t0, "14:00:00"); FW.h["BBB"] = [(t0, 100.0), (t0 + 3, 100.2)]
s3 = BK3.step(t0 + 3, "15:10", FW, {})
chk("🚪 EXIT at 15:10: an early card is not held overnight", [e[0] for e in s3] == ["EXIT"] and "15:10" in s3[0][3], s3)
st = BK.status(); st.update(BK3.status())
chk("each card's state for the page (exit +x% · open · ½ booked)", st[("POLICYBZR", 1, "09:19:42")][0].startswith("exit +") and st[("BBB", 1, "14:00:00")][0].startswith("exit "), st)
WW.cards_db(BK.done[0], "2026-11-16")
n = sqlite3.connect("tomorrow.db").execute("select count(*), max(half) from wind_cards").fetchone()
chk("every card and how it ended -> tomorrow.db wind_cards (python3 windwatch.py cards)", n == (1, 1), n)
k = WW.hist_save(O, t0, "2026-11-16", "09:20")
chk("the strikes once a minute -> data/chainlive.db (6 nearest the price, CE + PE)", k == 10 and sqlite3.connect(WW.HISTF).execute("select count(*) from pins").fetchone()[0] == 10, k)
class FW2: pass
W2 = FW2(); W2.h = {"POLICYBZR": [(t0, 1049.0, 3.2, 1_100_000, 0, 0)], "X": [(t0, 10.0, None, None, 0, 0)]}
class TU2: base = {"POLICYBZR": 1_000_000}
A = WW.live_all(W2, TU2)
chk("the live table: price % today · futures OI % since the day's first reading · fresh ₹ cr", A == {"POLICYBZR": [3.2, 10.0, 10.5]}, A)
print("THE CARD TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p278_patch.py $D $W/page278.js || back
cd $D && python3 -m py_compile windwatch.py || back
echo "=== test"
python3 $W/p278test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
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
echo "✅ patch 278 done - from Monday 09:15: 🌪 BIG MOVER with its 🎫 card, then 🎯 BOOK HALF / 🚪 EXIT in GIR Bigmovers; BIG MONEY's table live every 3 s (Ctrl + Shift + R)"
echo "   after 15:35:  python3 $D/windwatch.py cards     (every card and how it ended)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-windwatch gir-dash"
