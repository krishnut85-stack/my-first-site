#!/bin/bash
# PATCH 283 - THE STRIKE RAMA'S WAY + POSITION GUARD ON STRIKE / EXPIRY / SIZE / TIME + 👁 YOUR VIEW (Rama, 14 Nov). His rules: at / 1 in the
#   money · 11+ days to expiry · ₹1.5-3 lakh a trade · book in 5-45 min.
#   · movecard.py: the 🎫 card takes 11+ days to expiry and the strike AT the money, then 1 IN the money (no out-of-the-money)
#   · posguard.py: ⚠ CHEAP STRIKE (premium under ₹10) · ⚠ NEAR EXPIRY (10 days or less) · ⚠ SIZE (over ₹3 lakh: python3 posguard.py size AMOUNT) ·
#     ⏱ 45 MIN (still open: book it or the stop to the buy price) - GIR Box Picks, with sound
#   · windwatch.py: 👁 YOUR VIEW - PAYTM ▲ and PATANJALI ▼ set now: ✅ when it moves your way 1% / 2% / 3% today (the checklist + its side's rule),
#     ⚠ when it goes 1% / 2% against you - GIR Bigmovers, with sound. python3 windwatch.py view SYM up|down|off
#   Edits movecard.py posguard.py windwatch.py. Tested: 13 + the old 12 / 12 / 7 / 7. Restarts the services that dress alerts and the wind watcher.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "patch 283" $D/movecard.py && grep -q "patch 283" $D/posguard.py && grep -q "class View" $D/windwatch.py; then echo "patch 283 - already in"; exit 0; fi
grep -q "class Loading" $D/windwatch.py && grep -q "patch 281" $D/posguard.py && grep -q "RISK, MIN_DAYS = 10000.0, 4" $D/movecard.py || { echo "patch 282 (and 281, 271) first"; exit 1; }
F="movecard.py posguard.py windwatch.py"; SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash gir-windwatch"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel · 278: the option writers every 5 s, the 🎫 card on every big mover, then 🎯 BOOK HALF / 🚪 EXIT · 280: THE CHECKLIST on every message, how fresh the futures OI is · 281: 🚀 MOMENTUM - Rama's own way · 282: VOLUME vs its normal, ⏳ MONEY LOADING, each side's own rule · 283: 👁 YOUR VIEW): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
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
            self.h[s].append((t, float(v[0]), v[1] if len(v) > 1 else None, x[1], x[2] or 0, x[3] or 0, (x[4] or 0) if len(x) > 4 else 0))

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
            vr = None                                                       # patch 282: volume in the 3 min vs its normal for those minutes
            if len(new) > 6 and len(old) > 6 and new[6] and old[6] and new[6] > old[6]:
                nm = vol_normal(s, old[0], new[0])
                if nm:
                    vr = (new[6] - old[6]) / nm
            mv[s] = (px3, oi3, book, new, vr)
        self.br = (sum(1 for v in mv.values() if v[0] > 0.1), sum(1 for v in mv.values() if v[0] < -0.1), len(mv))     # patch 280: the whole market
        out = {}
        for s, (px3, oi3, book, new, vr) in mv.items():
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
                      "mk_up": self.br[0], "mk_dn": self.br[1], "mk_n": self.br[2], "vr": None if vr is None else round(vr, 1)}
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
    if w.get("vr") is not None:                                         # patch 282: the volume - in most real moves (2.2x as often as normal)
        Hh.append((True if w["vr"] >= VOL_X else None, "volume %.1fx its normal (3 min)" % w["vr"]))
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
    L.append(side_rule(w))                                                      # patch 282
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
        L_.append(side_rule(dict(w, dir=sd)))                                   # patch 282
    L_ += list(card or [])
    L_.append("%s side · stop: the share back %s ₹%s (2%% back) · 🎯 BOOK HALF at ₹%s (2%% more) · GIR follows it here: 🎯 / 🚪" % (
        "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(px * (1 - MOM_R * sd)), "{:,.2f}".format(px * (1 + MOM_R * sd))))
    return "\n".join(L_)


def _send_mom(s_, sd, L, px, chg, hm_, early, mk, doi, res, cp, now_, w):
    L_, pick = card_lines(s_, "CE" if sd > 0 else "PE", px * (1 - MOM_R * sd), now_)
    if cp is not None:
        cp["pick"] = pick
    send_big(mom_text(s_, sd, L, px, chg, hm_, early, mk, doi, res, L_, w))



# ---------------- patch 282 (Rama, 14 Nov: "build patch 282 now") - what 10 days and 1,043 real moves showed (fastreplay.py 3d):
# UP moves ride the TIDE: its sector moving with it 4.6x as often as normal, new futures money 4.2x, the sector already moving 15 min before 2.5x,
#   NIFTY with it 2.3x, volume 2x its normal 2.2x
# DOWN moves are the share's OWN break: fresh futures sellers 6.6x, its sector with it 4.7x - and the market already falling before was LESS
#   often (0.4-0.6x)
# BOTH: the futures money comes BEFORE the price - OI +0.5% in the 15 min before (2.3x up, 2.8x down) -> ⏳ MONEY LOADING
# Hidden orders and news: no edge (1.1x). ----------------
VOL_X, VOLF = 2.0, os.path.join(BASE, "data", "vol_normal.json")
_VN = {"day": None, "m": {}}


def vol_build(day, syms):
    """the normal volume for each 5-minute slot of the day, per share: the median of the last 8 sessions (data/SYM.npz, 5-min candles) -> per minute"""
    out = {}
    try:
        import numpy as np
    except Exception:
        return out
    for s in syms:
        try:
            z = np.load(os.path.join(BASE, "data", s + ".npz"))
            ts, v = np.asarray(z["ts"], float), np.asarray(z["v"], float)
        except Exception:
            continue
        dd = ((ts + 19800) // 86400).astype(int)
        days = sorted(set(dd.tolist()))
        keep = [d for d in days if str(dt.date(1970, 1, 1) + dt.timedelta(days=d)) < day][-8:]
        if len(keep) < 3:
            continue
        slots = {}
        for t_, v_, d_ in zip(ts, v, dd):
            if d_ in keep and v_ > 0:
                m = int(((t_ + 19800) % 86400) // 60) // 5 * 5
                slots.setdefault(m, []).append(float(v_))
        out[s] = {str(m): round(sorted(L)[len(L) // 2] / 5.0, 1) for m, L in slots.items() if len(L) >= 3}
    return out


def vol_normal(s, t0, t1):
    """the normal volume of share s between t0 and t1 (epoch seconds) - built once a day, kept in data/vol_normal.json"""
    day = str(dt.datetime.fromtimestamp(t1, IST).date())
    if _VN["day"] != day:
        j = _load(VOLF) or {}
        if j.get("day") == day and j.get("m"):
            _VN.update({"day": day, "m": j["m"]})
        else:
            _VN.update({"day": day, "m": {}})
        _VN["tried"] = set()
    m = _VN["m"].get(s)
    if m is None:
        if s in _VN.get("tried", set()):
            return None
        _VN.setdefault("tried", set()).add(s)
        b = vol_build(day, [s])
        if s not in b:
            return None
        _VN["m"][s] = m = b[s]
        try:
            json.dump({"day": day, "m": _VN["m"]}, open(VOLF + ".tmp", "w"), separators=(",", ":")); os.replace(VOLF + ".tmp", VOLF)
        except Exception:
            pass
    tot, t = 0.0, t0
    while t < t1:
        mm = int(((t + 19800) % 86400) // 60)
        tot += m.get(str(mm // 5 * 5), 0.0) * min(60.0, t1 - t) / 60.0
        t += 60.0
    return tot if tot > 0 else None


def side_rule(w):
    """each side's own rule, from the 10 days: CE rides the tide · PE is the share's own break on fresh sellers"""
    up = w["dir"] > 0
    ic = lambda v: "✅" if v else "❌"
    vol = w.get("vr")
    vtx = (" · %s volume %.1fx" % (ic(vol >= VOL_X), vol)) if vol is not None else ""
    if up:
        sec = bool(w.get("sec_n")) and w["sec_up"] * 2 >= w["sec_n"]
        mk = bool(w.get("mk_n")) and w["mk_up"] >= 0.5 * w["mk_n"]
        return "CE RULE - real rises ride the tide: %s its sector with it · %s the market with it%s" % (ic(sec), ic(mk), vtx)
    new = w.get("kind") == "SHORT BUILD-UP"
    return "PE RULE - real falls are the share's own break on fresh sellers: %s new futures sellers (OI %+.1f%%)%s" % (ic(new), w.get("oi3") or 0, vtx)


LOAD_OI, LOAD_PX, LOAD_S, LOAD_BOOK, LOAD_END = 0.5, 0.3, 1800, 1.3, 2700


class Loading:
    """⏳ MONEY LOADING: futures OI +0.5% in 15 min while the price has not moved yet (under 0.3%) - the head start. On the page only, each one
    followed 45 min: did the price go 1% - which way, and was it the side the book / the lean pointed to?"""
    def __init__(self, day):
        self.day, self.said, self.list = day, {}, []

    def step(self, t, hm, W):
        new = []
        for s, d in W.h.items():
            if not d or t - d[0][0] < 0.8 * KEEP:
                continue
            old = next((r for r in d if r[0] >= t - KEEP), d[0]); cur = d[-1]
            if not (old[3] and cur[3] and old[1]):
                continue
            oi15 = (cur[3] / old[3] - 1) * 100; px15 = (cur[1] / old[1] - 1) * 100
            if oi15 < LOAD_OI or abs(px15) >= LOAD_PX or t - self.said.get(s, -1e9) < LOAD_S:
                continue
            self.said[s] = t
            b = (cur[4] / cur[5]) if (cur[4] and cur[5]) else None
            side = 1 if (b and b >= LOAD_BOOK) else -1 if (b and b <= 1 / LOAD_BOOK) else (1 if px15 >= 0.1 else -1 if px15 <= -0.1 else 0)
            x = {"t": hm, "ts": int(t), "s": s, "side": side, "oi15": round(oi15, 2), "px15": round(px15, 2), "book": None if b is None else round(b, 2),
                 "px": cur[1], "up": 0.0, "dn": 0.0, "res": None}
            self.list.append(x); new.append(x)
        done = []
        for x in self.list:                                            # follow each one 45 min
            if x["res"] is not None:
                continue
            d = W.h.get(x["s"])
            if d:
                mv = (d[-1][1] / x["px"] - 1) * 100
                x["up"], x["dn"] = max(x["up"], mv), min(x["dn"], mv)
                if x["up"] >= 1.0 and x["dn"] > -1.0:
                    x["res"] = "▲ +1%"
                elif x["dn"] <= -1.0 and x["up"] < 1.0:
                    x["res"] = "▼ -1%"
            if x["res"] is None and t - x["ts"] >= LOAD_END:
                x["res"] = "nothing (%+.1f%% / %+.1f%%)" % (x["up"], x["dn"])
            if x["res"] is not None:
                done.append(x)
        self.list = [x for x in self.list if t - x["ts"] < 4 * 3600][-80:]
        return new, done


def loading_db(xs, day):
    try:
        c = db()
        c.execute("create table if not exists wind_loading(day text, t text, sym text, side int, oi15 real, px15 real, book real, px real, res text, up real, dn real)")
        c.executemany("insert into wind_loading values (?,?,?,?,?,?,?,?,?,?,?)", [(day, x["t"], x["s"], x["side"], x["oi15"], x["px15"], x["book"], x["px"], x["res"],
                                                                                 round(x["up"], 2), round(x["dn"], 2)) for x in xs])
        c.commit(); c.close()
    except Exception:
        pass


def loading_show(day=None):
    """python3 windwatch.py loading [DAY] - every ⏳ MONEY LOADING and what the price did next"""
    day = day or str(dt.datetime.now(IST).date())
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True)
        R = c.execute("select t, sym, side, oi15, px15, book, res from wind_loading where day=? order by t", (day,)).fetchall()
    except Exception:
        R = []
    print("=== ⏳ MONEY LOADING %s: %d" % (day, len(R)))
    for r in R:
        print("  %s %-11s %s OI %+.1f%% · price %+.2f%% · book %s → %s" % (r[0], r[1], {1: "▲", -1: "▼", 0: "?"}[r[2]], r[3], r[4], ("%.1fx" % r[5]) if r[5] else "-", r[6]))
    if R:
        mv = [r for r in R if r[6] and r[6][0] in "▲▼"]
        right = sum(1 for r in mv if (r[6][0] == "▲" and r[2] > 0) or (r[6][0] == "▼" and r[2] < 0))
        print("  moved 1%% within 45 min: %d of %d (%d%%) · the side it pointed to was right: %d of %d" % (len(mv), len(R), round(100 * len(mv) / len(R)), right,
              sum(1 for r in mv if r[2])))



# ---------------- patch 283: 👁 YOUR VIEW (Rama, 14 Nov: "PAYTM up, PATANJALI down - that is my thinking"): GIR watches the shares you have a
# view on - 👁 ✅ when it moves your way (1% / 2% / 3% today, with the checklist and its side's rule) · 👁 ⚠ when it goes 1% / 2% AGAINST you.
# python3 windwatch.py view SYM up|down|off · view (the list). Kept in data/myview.json until you turn it off.
VIEWF, VIEW_WITH, VIEW_AGAINST = os.path.join(BASE, "data", "myview.json"), (1.0, 2.0, 3.0), (1.0, 2.0)


def views():
    j = _load(VIEWF) or {}
    return {k.upper(): int(v) for k, v in (j.get("v") or {}).items() if v in (1, -1)}


def view_set(sym, how):
    j = _load(VIEWF) or {}
    v = j.get("v") or {}
    if how == "off":
        v.pop(sym.upper(), None)
    else:
        v[sym.upper()] = 1 if how == "up" else -1
    j["v"] = v
    os.makedirs(os.path.dirname(VIEWF), exist_ok=True)
    json.dump(j, open(VIEWF + ".tmp", "w")); os.replace(VIEWF + ".tmp", VIEWF)
    return views()


class View:
    def __init__(self, day):
        self.day, self.said, self.t = day, set(), 0.0
        self.v = views()

    def step(self, t, W, wind):
        """-> [(sym, view, kind 'with'/'against', level, px, chg, w)]"""
        if t - self.t > 60:
            self.t, self.v = t, views()
        out = []
        for s, vd in self.v.items():
            d = W.h.get(s)
            if not d or d[-1][2] is None:
                continue
            px, chg = d[-1][1], float(d[-1][2])
            mv = chg * vd
            for kind, levels in (("with", VIEW_WITH), ("against", VIEW_AGAINST)):
                for L in levels:
                    hit = mv >= L if kind == "with" else mv <= -L
                    if hit and (s, kind, L) not in self.said:
                        self.said.add((s, kind, L))
                        if L == max(x for x in levels if (mv >= x if kind == "with" else mv <= -x)):
                            out.append((s, vd, kind, L, px, chg, wind.get(s)))
        return out


def view_text(s, vd, kind, L, px, chg, hm, w):
    want = "▲ UP (CE)" if vd > 0 else "▼ DOWN (PE)"
    if kind == "with":
        Lx = ["👁 YOUR VIEW ✅ %s %s %+.1f%% today · %s · ₹%s" % ("▲" if vd > 0 else "▼", s, chg, hm, "{:,.2f}".format(px)),
              "moving YOUR way (%s) - %g%% today" % (want, L)]
        if w and w.get("dir") == vd:
            Lx += check_text(w); Lx.append(side_rule(w))
        Lx.append("your rules: at / 1 in the money · 11+ days to expiry · ₹1.5-3 lakh · book in 5-45 min" + (" · after 10:00: half size" if hm >= "10:00" else ""))
    else:
        Lx = ["👁 YOUR VIEW ⚠ %s %s %+.1f%% today · %s · ₹%s" % ("▲" if chg > 0 else "▼", s, chg, hm, "{:,.2f}".format(px)),
              "AGAINST your view (%s) by %g%% - if you hold it, protect it (exit or the stop); the market is saying otherwise" % (want, L)]
        if w and w.get("dir") == -vd:
            Lx += check_text(w, "WHAT IS PUSHING AGAINST YOU")
    return "\n".join(Lx)


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
    LD = Loading(str(dt.datetime.now(IST).date()))                   # patch 282
    VW = View(str(dt.datetime.now(IST).date()))                      # patch 283
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
            if LD.day != str(now.date()):
                LD = Loading(str(now.date()))
            if VW.day != str(now.date()):
                VW = View(str(now.date()))
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
                for s_, vd, kind, L, px, chg, w_ in (VW.step(t, W, cur) if hm >= MOM_FROM else []):     # patch 283: 👁 YOUR VIEW
                    _bg(send_big, view_text(s_, vd, kind, L, px, chg, hms, w_))
                _ln, _ld = LD.step(t, hms, W)                                       # patch 282: ⏳ MONEY LOADING (page only, followed 45 min)
                if _ld:
                    loading_db(_ld, day)
                st = BK.status()
                for x in BL:
                    if (x["s"], x["dir"], x["t"]) in st:
                        x["st"], x["won"] = st[(x["s"], x["dir"], x["t"])]
                BL[:] = [x for x in BL if t - x["ts"] < 3 * 3600][-40:]
                ALL = live_all(W, TU)                                                # patch 278: every share's day, live (the BIG MONEY table)
                cards = [{k: c.get(k) for k in ("s", "dir", "t", "entry", "stop", "half", "t2", "exit_t", "exit_px", "why", "res")} for c in list(BK.open.values()) + BK.done[-30:]]
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "opt": bool(O.h), "s": cur, "turns": TU.list[-40:], "big": BL[-40:], "cards": cards, "all": ALL, "oi_every": W.oi_every(), "mk": list(W.br), "mom": MO.list[-40:], "load": LD.list[-30:]},
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
    elif sys.argv[1:2] == ["view"]:
        if len(sys.argv) >= 4 and sys.argv[3] in ("up", "down", "off"):
            v = view_set(sys.argv[2], sys.argv[3])
        else:
            v = views()
        print("👁 YOUR VIEW: " + (" · ".join("%s %s" % (k, "▲ up" if x > 0 else "▼ down") for k, x in sorted(v.items())) or "none") +
              "   (python3 windwatch.py view SYM up|down|off)")
    elif sys.argv[1:2] == ["loading"]:
        loading_show(sys.argv[2] if len(sys.argv) > 2 else None)
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
cat > $W/p283_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p283_patch.py - patch 283: the trade card picks the strike Rama's way (at / 1 in the money, 11+ days to expiry) + Position Guard: CHEAP STRIKE,
NEAR EXPIRY, SIZE, 45 MIN CHECK.  python3 p283_patch.py DIR"""
import os, sys
D = sys.argv[1]
def edit(f, pairs):
    p = os.path.join(D, f)
    s = open(p, encoding="utf-8").read()
    if "patch 283" in s:
        print("  %s: patch 283 - already in" % f); return
    for o, n, tag in pairs:
        if s.count(o) != 1:
            print("❌ %s: anchor for '%s' found %d times" % (f, tag, s.count(o))); sys.exit(1)
        s = s.replace(o, n); print("  %s: %s" % (f, tag))
    open(p, "w", encoding="utf-8").write(s)
edit("movecard.py", [
    ("RISK, MIN_DAYS = 10000.0, 4", "RISK, MIN_DAYS = 10000.0, 11          # patch 283: 11+ days to expiry (time decay is fastest in the last 10 days)", "11+ days to expiry"),
    ("    cand = [row[j] for j in (i, i - 1 if side == \"CE\" else i + 1, i + 1 if side == \"CE\" else i - 1) if 0 <= j < len(row)]",
     "    cand = [row[j] for j in (i, i - 1 if side == \"CE\" else i + 1) if 0 <= j < len(row)]      # patch 283: at the money, then 1 IN the money - never out",
     "the strike: at the money, then 1 in the money (no out-of-the-money)")])
edit("posguard.py", [
    ("        S = spot.get(u)\n", '''        if new and q > 0:                                                  # patch 283: the strike, the expiry, the size (Rama's record)
            if avg and avg < CHEAP:
                say("cheap:%s" % ts, "⚠ 🛡 POSITION GUARD · CHEAP STRIKE · %s\\n%s bought at %s - a cheap, far strike needs a big move just to break even\\n"
                    "your rule: at the money or 1 in the money" % (hm, ts, _inr(avg)))
            dte = (dt.date.fromisoformat(ex) - now.date()).days if ex else None
            if dte is not None and dte <= NEAR_DTE:
                say("near:%s" % ts, "⚠ 🛡 POSITION GUARD · NEAR EXPIRY · %s\\n%s has %d days left - time decay is fastest in the last 10 days\\n"
                    "your rule: 11+ days to expiry - "
                    "next month's strike costs more but holds its value" % (hm, ts, dte))
            if abs(q) * avg >= C.get("size_max", SIZE_MAX):
                say("size:%s" % ts, "⚠ 🛡 POSITION GUARD · SIZE · %s\\n%s · about %s in one trade - over your %s\\nyour rule: ₹1.5-3 lakh a trade" % (
                    hm, ts, _inr(abs(q) * avg), _inr(C.get("size_max", SIZE_MAX))))
        if q > 0 and st["first"].get(ts) and t - st["first"][ts] >= HOLD_S:
            say("hold:%s" % ts, "⏱ 🛡 POSITION GUARD · 45 MIN · %s\\n%s held %d min · now %s (%+.0f%% on your %s)\\nyour rule: book in 5-45 min - book it now, or move the stop to your buy price" % (
                hm, ts, (t - st["first"][ts]) / 60, _inr(ltp), (ltp / avg - 1) * 100 if avg else 0, _inr(avg)))
        S = spot.get(u)
''', "CHEAP STRIKE (under ₹10) · NEAR EXPIRY (10 days or less) · SIZE (over ₹3 lakh) · 45 MIN CHECK"),
    ('''EARLY_S, PM_HM, PM_X, PM_MIN = 900, "13:00", 1.5, 150000.0''', '''EARLY_S, PM_HM, PM_X, PM_MIN = 900, "13:00", 1.5, 150000.0
CHEAP, NEAR_DTE, SIZE_MAX, HOLD_S = 10.0, 10, 300000.0, 2700          # patch 283 (python3 posguard.py size AMOUNT changes the size limit)''', "the limits"),
    ('''    elif a and a[0] == "limit" and len(a) == 2:''', '''    elif a and a[0] == "size" and len(a) == 2:                            # patch 283
        c = conf(); c["size_max"] = abs(float(a[1])); _save(CONF, c); print("size limit for one trade: ₹{:,.0f}".format(c["size_max"]))
    elif a and a[0] == "limit" and len(a) == 2:''', "python3 posguard.py size AMOUNT")])
print("patch 283 in")
PY_PATCH
cat > $W/p283test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p283test.py - the strike Rama's way, Position Guard's new warnings, 👁 YOUR VIEW (made-up account and prices, temp folder, nothing sent)"""
import os, sys, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("movecard.py", "posguard.py", "windwatch.py"):
    shutil.copy(os.path.join(WK, f), T)
sys.path.insert(0, T); os.chdir(T)
import movecard as MC, posguard as PG, windwatch as WW
WW.ENVF = os.path.join(T, "no.env"); WW.BASE = T; WW.VIEWF = os.path.join(T, "data", "myview.json")
IST = PG.IST
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:600]))
# 1 the trade card: 11+ days, at / 1 in the money
M = {}
for ex in ("2026-11-23", "2026-12-29"):
    for K in range(980, 1121, 20):
        for sd in ("CE", "PE"):
            M["X%s%d%s" % (ex[5:7], K, sd)] = ["AAA", ex, float(K), sd, 350]
class KQ:
    def quote(self, keys):
        out = {"NSE:AAA": {"last_price": 1049.0}}
        for k in keys:
            if k.startswith("NFO:"):
                K = M[k[4:]][2]; out[k] = {"last_price": max(5.0, 1049 - K + 30), "oi": 50000, "depth": {"buy": [{"price": max(5.0, 1049 - K + 29.7)}], "sell": [{"price": max(5.0, 1049 - K + 30)}]}}
        return out
now = dt.datetime(2026, 11, 16, 9, 40, tzinfo=IST)
L = MC.trade_card("AAA", "CE", 1030.0, now, k=KQ(), M=M, q_live={"AAA": [1049.0, 3.0]})
print("\n" + "\n".join(L) + "\n")
chk("the card skips the 23 Nov expiry (7 days) and takes 29 Dec (43 days) - 11+ days", "expiry 29 Dec" in L[0], L[0])
chk("the strike: 1040 CE - at the money (₹1,049), not out of the money", "BUY AAA 1040 CE" in L[0], L[0])
# 2 Position Guard
class K:
    P = []
    def positions(self): return {"net": self.P}
    def ltp(self, keys): return {k: {"last_price": 1049.0} for k in keys}
PM = {"AAA26NOV1100CE": ["AAA", "2026-11-23", 1100.0, "CE", 350], "AAA26DEC1040CE": ["AAA", "2026-12-29", 1040.0, "CE", 350]}
k = K()
def at(h, m): return dt.datetime(2026, 11, 16, h, m, tzinfo=IST)
def pos(ts, q, avg, ltp): return {"exchange": "NFO", "tradingsymbol": ts, "quantity": q, "average_price": avg, "last_price": ltp, "pnl": 0, "m2m": 0}
PG.check(at(9, 30), k, None, PM)
k.P = [pos("AAA26NOV1100CE", 3500, 8.5, 8.6)]
o1 = PG.check(at(9, 31), k, None, PM)
print("\n".join(x.split("\n")[0] for x in o1))
chk("a ₹8.50 premium -> ⚠ CHEAP STRIKE", any("CHEAP STRIKE" in x for x in o1), o1)
chk("7 days to expiry -> ⚠ NEAR EXPIRY", any("NEAR EXPIRY" in x and "7 days left" in x for x in o1), o1)
k.P = [pos("AAA26NOV1100CE", 3500, 8.5, 8.6), pos("AAA26DEC1040CE", 7000, 60.0, 61.0)]
o2 = PG.check(at(9, 33), k, None, PM)
chk("₹4.2 lakh in one trade -> ⚠ SIZE (over ₹3 lakh); the Dec 1040 CE is not cheap / near", any("SIZE" in x and "AAA26DEC1040CE" in x for x in o2)
    and not any(("CHEAP" in x or "NEAR EXPIRY" in x) and "DEC1040" in x for x in o2), o2)
o3 = PG.check(at(10, 19), k, None, PM)
chk("still open 46 min later -> ⏱ 45 MIN: book it or move the stop to the buy price", any("45 MIN" in x and "AAA26DEC1040CE" in x for x in o3), o3)
chk("... once only", not any("45 MIN" in x and "DEC1040" in x for x in PG.check(at(10, 20), k, None, PM)))
# 3 👁 YOUR VIEW
v = WW.view_set("paytm", "up"); v = WW.view_set("PATANJALI", "down")
chk("the views are kept: PAYTM ▲ · PATANJALI ▼", v == {"PAYTM": 1, "PATANJALI": -1}, v)
class FW: pass
W = FW(); W.h = {"PAYTM": [(0, 1300.0, 0.5, None, 0, 0, 0)], "PATANJALI": [(0, 600.0, 0.3, None, 0, 0, 0)]}
VW = WW.View("2026-11-16")
chk("nothing yet at +0.5% / +0.3%", VW.step(1, W, {}) == [])
W.h["PAYTM"] = [(0, 1320.0, 1.4, None, 0, 0, 0)]; W.h["PATANJALI"] = [(0, 607.0, 1.2, None, 0, 0, 0)]
E = VW.step(2, W, {"PAYTM": {"dir": 1, "kind": "LONG BUILD-UP", "px3": 0.8, "oi3": 1.0, "book": 1.8, "score": 4, "sec_up": 2, "sec_dn": 0, "sec_n": 3, "mk_n": 0}})
chk("PAYTM +1.4% -> 👁 ✅ with you · PATANJALI +1.2% -> 👁 ⚠ against your ▼", sorted((e[0], e[2], e[3]) for e in E) == [("PATANJALI", "against", 1.0), ("PAYTM", "with", 1.0)], E)
tx = [WW.view_text(*e[:6], "09:42:00", e[6]) for e in sorted(E)]
print("\n" + "\n\n".join(tx) + "\n")
chk("the words: '👁 YOUR VIEW ✅ ▲ PAYTM' with the checklist and the CE rule · '👁 YOUR VIEW ⚠ ▲ PATANJALI ... AGAINST your view'",
    any(x.startswith("👁 YOUR VIEW ✅ ▲ PAYTM") and "CE RULE" in x and "11+ days to expiry" in x for x in tx) and any(x.startswith("👁 YOUR VIEW ⚠ ▲ PATANJALI") and "AGAINST your view (▼ DOWN (PE))" in x for x in tx), tx)
W.h["PAYTM"] = [(0, 1350.0, 3.6, None, 0, 0, 0)]
E2 = VW.step(3, W, {})
chk("PAYTM jumps to +3.6%: ONE update at 3% (not 2% and 3%)", [(e[0], e[3]) for e in E2] == [("PAYTM", 3.0)], E2)
chk("view off", WW.view_set("PATANJALI", "off") == {"PAYTM": 1})
print("THE PATCH 283 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p283_patch.py $D || back
cd $D && python3 -m py_compile movecard.py posguard.py windwatch.py || back
echo "=== test"
cp $D/movecard.py $D/posguard.py $W/
python3 $W/p283test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
cd $D && python3 windwatch.py view PAYTM up >/dev/null && python3 windwatch.py view PATANJALI down
chown --reference=$D $D/data/myview.json 2>/dev/null
for s in $SV; do systemctl restart $s 2>/dev/null; done; sleep 6
echo "  gir-intraday: $(systemctl is-active gir-intraday) · gir-windwatch: $(systemctl is-active gir-windwatch) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "✅ patch 283 done - the 🎫 card: at / 1 in the money, 11+ days · Position Guard: CHEAP STRIKE / NEAR EXPIRY / SIZE / 45 MIN · 👁 YOUR VIEW PAYTM ▲ PATANJALI ▼"
echo "   your view any time:  python3 $D/windwatch.py view SYM up|down|off      · size limit: python3 $D/posguard.py size 300000"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; for s in $SV; do systemctl restart \$s; done"
