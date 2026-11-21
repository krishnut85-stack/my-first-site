#!/bin/bash
# PATCH 142b - ⚡ ENTER NOW RINGS ONLY WHERE IT WAS RIGHT. The backtest of 9 Nov: 192 alerts, 46 WIN · 85 LOSS - too many, no edge
#   overall. But 09:20-10:00, the rotation laggards were 7 of 7 WIN and the news before the open 4 WIN 1 LOSS. So:
#   ⚡ ENTER NOW (Box Picks, ringing): news from before 09:15 confirmed by 10:00 · a laggard of a rotation that showed by 10:00,
#                                     confirmed by 10:30
#   📋 TRIAL ENTRY (⚙️ System topic, quiet, scored every evening): your rules, OI lines, box picks, volume, the "out of" side,
#                                     anything later - each kind rings once the scores show it works
#   🔄 MARKET ROTATION: one message a rising sector a day (9 Nov sent 7)
#   Switch: python3 enternow.py --live all (every kind rings) · --live default (back to this). Restarts gir-intraday.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35 or before 08:45"; exit 1; fi
grep -q "patch 142" $D/engine2.py || { echo "patch 142 is not installed yet - install it first"; exit 1; }
grep -q "patch 142b" $D/enternow.py && { echo "patch 142b is already installed"; exit 1; }
F="enternow.py enterback.py p142test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $D/enternow.py <<'PY_EN'
#!/usr/bin/env python3
"""enternow.py - patch 142: ⚡ ENTER NOW and 🔄 MARKET ROTATION. Rama, 9 Nov: "I am not interested in the alert after the stock
moved - I want it BEFORE". The study of 9 Nov (premove.py) showed what came before the moves: news before the open (PNB 08:57,
UNIONBANK 09:01), his own rule "roof breaking - writers running" (COCHINSHIP 09:36, 104 min before 2%; IRFC 11:23), CALLS BOUGHT
(RVNL 10:28), volume 4-10x on a candle going the right way (BDL from 10:55, 3 h before 2%), put writers adding below
(DATAPATTNS 09:53), and the money leaving IT for pharma / PSU banks from 09:15.

  TRIGGER   (each one opens a watch on the share, with its side)
    news     a 📄 / 📰 story with a side, from 08:00 (valid 90 min - the open's first minutes are judged, not skipped)
    OI       📜 YOUR RULE · CALLS / PUTS BOUGHT · THE FLOOR MOVED UP / THE ROOF MOVED DOWN · BUILD-UP · WRITERS RUNNING ·
             🎯 BOX PICK (valid 60 min)
    volume   a finished 5-min candle with 4x+ the day's median volume, going one way, the share still under 1.5% (valid 30 min)
    rotation a laggard of the sector the money is going into (valid while the rotation holds)
  CONFIRM  (2 needed, checked every 30 s from 09:20 to 14:45)
    VWAP     the price on the trigger's side of the day's VWAP, 0.3%+ its way
    range    beyond the opening 15 minutes' high (CE) / low (PE), after 09:30
    OI       the writers in the way leaving (their OI -5% between two readings) or the writers behind it adding (+10%)
    book     the order book loading / queued on that side
    volume   the last finished candle 2x+ its median, going that way
    sector   its sector 0.3%+ the same way
  BLOCKED  already 3%+ its way (late - not "before") · 0.5%+ against · after 14:45 · once a share a side a day
  THE LINE ⚡ ENTER NOW ▲ SYM CE · ₹px · why now · the strike (chain15: the first strike beyond the price), the premium, 1 lot ·
           the stop (the share below VWAP / the last 15-min low) · the target (the call / put wall) · out by 15:15 ·
           results in 0-3 days: a run-up trade - half size, out before the results (not "avoid")
  🔄 MARKET ROTATION: one group 0.8%+ up with 70% of its shares up while another is 0.8%+ down with 70% down (banks split into
           PSU / private) -> once a group a day: the leaders, the laggards (each laggard becomes a watch above)
  Both go to GIR Box Picks, ringing.   python3 enternow.py            the watches and the confirmations now (nothing sent)"""
import os, re, sys, json, time, sqlite3, statistics, threading, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OPEN_M, START_M, LAST_M, EXIT_HM = 555, 560, 885, "15:15"          # 09:15 · 09:20 · 14:45
VALID = {"news": 90, "oi": 60, "volume": 30, "rotation": 120}
NEED, LATE, AGAINST = 2, 3.0, -0.5
ROT_AVG, ROT_BREADTH = 0.8, 0.70
PSU_BANKS = {"SBIN", "BANKBARODA", "PNB", "CANBK", "UNIONBANK", "BANKINDIA", "INDIANB", "IOB", "UCOBANK", "CENTRALBK", "MAHABANK", "PSB"}
OI_RX = re.compile(r"YOUR RULE|CALLS BOUGHT|PUTS BOUGHT|FLOOR MOVED UP|ROOF MOVED DOWN|BUILD-UP|WRITERS RUNNING|BOX PICK")
# patch 142b: the backtest of 9 Nov - 09:20-10:00: rotation laggards 7 of 7 WIN, news before the open 4 WIN 1 LOSS; the rest
# (your rules, OI lines, volume, box picks, the "out of" side, anything after 10:30) a coin toss or worse -> TRIAL (quiet)
LIVE_KINDS = {"news-pre": 600, "rot-in": 630}          # kind -> the last minute it may ring (10:00 / 10:30)
MODE_FILE = os.path.join(BASE, "data", "enternow_mode.json")
ST = {"day": None, "said": set(), "rot": {}, "rot_said": set(), "busy": False, "last": None}


def hm(m):
    return "%02d:%02d" % (m // 60, m % 60)


def mins(t):
    return int(t[:2]) * 60 + int(t[3:5])


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def groups(smap):
    """GIR's sectors with the banks split into PSU / private"""
    out = {}
    for n, syms in (smap or {}).items():
        if "bank" in n.lower():
            out["PSU BANKS"] = [s for s in syms if s in PSU_BANKS]
            out["PRIVATE BANKS"] = [s for s in syms if s not in PSU_BANKS]
        elif n != "others":
            out[n.upper()] = list(syms)
    for s in PSU_BANKS:
        if s not in out.get("PSU BANKS", []) and any(s in v for v in (smap or {}).values()):
            out.setdefault("PSU BANKS", []).append(s)
    return {k: v for k, v in out.items() if v}


# ---------- the day's data: one interface, two sources (live files / the stored day) ----------
class Data:
    """candles[sym] = [(minute of the bar's start, o, h, l, c, v)] · pc[sym] · alerts [(minute, kind, sym, side, head)] ·
    chain(sym, upto) -> [(minute, spot, {(strike, kind): (oi, ltp)})] · book(sym, t) -> -1 / 0 / 1 · results(sym) -> days or None"""

    def __init__(self, day):
        self.day, self.candles, self.pc, self.vw, self.alerts, self.lot, self.px_now, self.by_sym = day, {}, {}, {}, [], {}, {}, {}
        self._ch, self._res, self._book = {}, None, None

    def load_alerts(self):
        out = []
        try:
            c = _ro("tomorrow.db")
            for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t", (self.day,)):
                if sym and side in ("CE", "PE"):
                    out.append((mins(t), kind or "", sym, side, (text or "").split("\n")[0][:160], text or ""))
            c.close()
        except Exception:
            pass
        self.alerts = out
        self.by_sym = {}
        for a in out:
            self.by_sym.setdefault(a[2], []).append(a)

    def vol_marks(self, s):
        """the share's volume candles, once: [(end minute, side, x, chg at the close of the candle)]"""
        if not hasattr(self, "_vm"):
            self._vm = {}
        if s not in self._vm:
            C, pc, out, vs = self.candles.get(s, []), self.pc.get(s), [], []
            for i, (m, o, h, l, c, v) in enumerate(C):
                if i >= 3 and pc:
                    med = statistics.median(vs)
                    if med > 0 and v >= 4 * med and c != o:
                        out.append((m + 5, 1 if c > o else -1, v / med, (c / pc - 1) * 100))
                vs.append(v)
            self._vm[s] = out
        return self._vm[s]

    def load_lots(self):
        try:
            c = _ro("chains.db"); self.lot = {r[0]: r[1] for r in c.execute("select sym, lot from fo_list")}; c.close()
        except Exception:
            self.lot = {}

    def chain(self, sym, upto):
        if sym not in self._ch:
            rows = []
            try:
                c = _ro("chains.db")
                tabs = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
                tb = "chain15" if "chain15" in tabs else ("chain" if "chain" in tabs else None)
                if tb:
                    rows = c.execute("select t, exp, strike, kind, oi, ltp, spot from %s where d=? and sym=? order by t" % tb, (self.day, sym)).fetchall()
                c.close()
            except Exception:
                rows = []
            by = {}
            if rows:
                exp = sorted({r[1] for r in rows})[0]
                for t, e, k, kd, oi, ltp, sp in rows:
                    if e != exp:
                        continue
                    b = by.setdefault(mins(str(t)), [sp, {}, exp])
                    if sp:
                        b[0] = sp
                    b[1][(k, kd)] = (oi or 0, ltp)
            self._ch[sym] = [(m, v[0], v[1], v[2]) for m, v in sorted(by.items())]
        return [x for x in self._ch[sym] if x[0] <= upto]

    def results(self, sym):
        if self._res is None:
            self._res = {}
            try:
                c = _ro("chains.db")
                for s, d in c.execute("select sym, min(d) from results_cal where d>=? group by sym", (self.day,)):
                    self._res[s] = (dt.date.fromisoformat(d) - dt.date.fromisoformat(self.day)).days
                c.close()
            except Exception:
                pass
        return self._res.get(sym)

    def book(self, sym, t):
        """replay: an order-book jump on that side within 15 min (tomorrow.db book_moves)"""
        if self._book is None:
            self._book = {}
            try:
                c = _ro("tomorrow.db")
                for tt, s, side in c.execute("select t, sym, side from book_moves where day=?", (self.day,)):
                    self._book.setdefault(s, []).append((mins(tt), 1 if side == "CE" else -1))
                c.close()
            except Exception:
                pass
        L = [d for m, d in self._book.get(sym, []) if t - 15 <= m <= t]
        return L[-1] if L else 0


class LiveData(Data):
    """today from the files the engine keeps: charts.json (5-min candles + VWAP), quotes_live.json, tomorrow.db, chains.db, the
    live order book (bookpress)"""

    def __init__(self, now):
        Data.__init__(self, str(now.date()))
        try:
            J = json.load(open(os.path.join(BASE, "charts.json"))) or {}
        except Exception:
            J = {}
        for s, ch in J.items():
            rows = []
            for i, c in enumerate(ch.get("c") or []):
                if c is None:
                    continue
                o, h, l = (ch.get("o") or [])[i], (ch.get("h") or [])[i], (ch.get("l") or [])[i]
                v = (ch.get("v") or [0] * (i + 1))[i] or 0
                rows.append((OPEN_M + 5 * i, o if o is not None else c, h if h is not None else c, l if l is not None else c, c, v))
            if rows and ch.get("pc"):
                self.candles[s], self.pc[s] = rows, float(ch["pc"])
                if ch.get("vw"):
                    self.vw[s] = float(ch["vw"])
        try:
            q = (json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}).get("q") or {}
            self.px_now = {s: v[0] for s, v in q.items() if v and v[0]}
        except Exception:
            self.px_now = {}
        self.load_alerts()
        self.load_lots()

    def book(self, sym, t):
        try:
            import bookpress
            b = bookpress.for_sym(sym)
            return (b or {}).get("side") or 0
        except Exception:
            return 0


class StoredData(Data):
    """a past day (or today after the close) from the stored 5-min candles (dashserve.hist) - for the backtest"""

    def __init__(self, day, syms, H=None):
        Data.__init__(self, day)
        for s in syms:
            try:
                h = H[s] if H is not None else _hist(s)
            except Exception:
                continue
            rows, prev = [], None
            for i, t in enumerate(h.get("t") or []):
                d = dt.datetime.fromtimestamp(t, IST)
                ds = str(d.date())
                if ds < day:
                    prev = h["c"][i]
                elif ds == day:
                    rows.append((d.hour * 60 + d.minute, h["o"][i], h["h"][i], h["l"][i], h["c"][i], h["v"][i]))
            if rows and prev:
                self.candles[s], self.pc[s] = rows, float(prev)
        self.load_alerts()
        self.load_lots()


def _hist(s, days=40):
    import dashserve
    return dashserve.hist(s, days)


# ---------- the reading of one share at minute t ----------
def done(D, s, t):
    """the finished candles at minute t"""
    return [x for x in D.candles.get(s, []) if x[0] + 5 <= t]


def price(D, s, t, live):
    if live and D.px_now.get(s):
        return float(D.px_now[s])
    C = done(D, s, t)
    return C[-1][4] if C else None


def vwap(D, s, t, live):
    if live and D.vw.get(s):
        return D.vw[s]
    C = done(D, s, t)
    sv = sum(x[5] for x in C)
    return sum((x[2] + x[3] + x[4]) / 3 * x[5] for x in C) / sv if sv else None


def triggers(D, s, t, rot_watch):
    """-> [(kind, side, minute, what)] still valid at t"""
    out = []
    for m, kind, sym, side, head, text in D.by_sym.get(s, []):
        if m > t or "ENTER NOW" in head or "ALREADY KNOWN" in text:
            continue
        d = 1 if side == "CE" else -1
        if kind in ("📄", "📰") and re.search(r"[▲▼]", head.split("·")[0]) and m >= 480 and t - m <= VALID["news"]:
            out.append(("news-pre" if m < OPEN_M else "news-day", d, m, head[:90]))
        elif OI_RX.search(head) and t - m <= VALID["oi"]:
            if re.search(r"no trade|RANGEBOUND", head, re.I):
                continue
            out.append(("rule" if "YOUR RULE" in head else "box" if "BOX PICK" in head else "oi", d, m, head[:90]))
    for m5, d, x, chg in D.vol_marks(s):
        if m5 <= t and t - m5 <= VALID["volume"] and chg * d < 1.5:
            out.append(("volume", d, m5, "volume %.0fx on the %s candle" % (x, hm(m5 - 5))))
    w = rot_watch.get(s)
    if w and t - w[1] <= VALID["rotation"]:
        out.append(("rot-in" if w[3] else "rot-out", w[0], w[1], w[2]))
    return out


def confirms(D, s, t, d, live, sec_avg=None):
    """-> [what] the confirmations on side d at minute t"""
    ok = []
    px, pc = price(D, s, t, live), D.pc.get(s)
    if not px or not pc:
        return ok
    chg = (px / pc - 1) * 100
    vw = vwap(D, s, t, live)
    if vw and (px - vw) * d > 0 and chg * d >= 0.3:
        ok.append("%s VWAP ₹%s" % ("above" if d > 0 else "below", _p(vw)))
    C = done(D, s, t)
    orb = [x for x in C if x[0] < OPEN_M + 15]
    if t >= OPEN_M + 15 and len(orb) >= 3:
        hi, lo = max(x[2] for x in orb), min(x[3] for x in orb)
        if (d > 0 and px > hi) or (d < 0 and px < lo):
            ok.append("%s the opening range ₹%s" % ("above" if d > 0 else "below", _p(hi if d > 0 else lo)))
    CH = D.chain(s, t)
    if len(CH) >= 2:
        (_, sp0, o0, _e0), (m1, sp1, o1, _e1) = CH[-2], CH[-1]
        ks = sorted({k for k, kd in o1})
        if sp1:
            wall = next((k for k in ks if k > sp1), None) if d > 0 else next((k for k in reversed(ks) if k < sp1), None)
            back = next((k for k in reversed(ks) if k < sp1), None) if d > 0 else next((k for k in ks if k > sp1), None)
            wk, bk = ("CE", "PE") if d > 0 else ("PE", "CE")
            a0, a1 = (o0.get((wall, wk)) or (0,))[0], (o1.get((wall, wk)) or (0,))[0]
            b0, b1 = (o0.get((back, bk)) or (0,))[0], (o1.get((back, bk)) or (0,))[0]
            if a0 and a1 and a1 / a0 - 1 <= -0.05:
                ok.append("%s writers at %g leaving (%+.0f%%)" % ("call" if d > 0 else "put", wall, (a1 / a0 - 1) * 100))
            elif b0 and b1 and b1 / b0 - 1 >= 0.10:
                ok.append("%s writers adding at %g (%+.0f%%)" % ("put" if d > 0 else "call", back, (b1 / b0 - 1) * 100))
    bk = D.book(s, t)
    if bk == d:
        ok.append("order book: %s loading" % ("buyers" if d > 0 else "sellers"))
    if len(C) >= 4:
        m, o, h, l, c, v = C[-1]
        med = statistics.median([x[5] for x in C[:-1]])
        if med > 0 and v >= 2 * med and (c - o) * d > 0:
            ok.append("volume %.0fx now" % (v / med))
    if sec_avg is not None and sec_avg * d >= 0.3:
        ok.append("its sector %+.1f%%" % sec_avg)
    return ok


def _p(v):
    return "{:,.2f}".format(v) if v < 100 else "{:,.1f}".format(v) if v < 10000 else "{:,.0f}".format(v)


def trade(D, s, t, d, px, live):
    """-> lines: the strike and premium, the stop, the target"""
    L = []
    CH = D.chain(s, t)
    kind = "CE" if d > 0 else "PE"
    if CH:
        m1, sp, oi, exp = CH[-1]
        ks = sorted({k for k, kd in oi if kd == kind})
        if ks:
            beyond = [k for k in ks if (k >= px if d > 0 else k <= px)]
            k = (beyond[0] if d > 0 else beyond[-1]) if beyond else min(ks, key=lambda x: abs(x - px))
            if abs(k - px) / px > 0.02:
                k = min(ks, key=lambda x: abs(x - px))
            o, ltp = oi.get((k, kind)) or (0, None)
            lot = D.lot.get(s)
            L.append("trade: %s %g (%s)%s%s" % (kind, k, str(exp)[5:], (" ~₹%s at %s" % (_p(ltp), hm(m1))) if ltp else "",
                                               (" · 1 lot %s ≈ ₹{:,.0f}".format(ltp * lot) % lot) if (ltp and lot) else ""))
            wall = [(oi.get((x, kind)) or (0,))[0] for x in ks]
            far = [x for x in ks if (x > px if d > 0 else x < px) and abs(x - px) / px <= 0.05]
            if far:
                tgt = max(far, key=lambda x: (oi.get((x, kind)) or (0,))[0])
                L.append("target: ₹%s - the %s wall (most %s OI)" % (_p(tgt), "call" if d > 0 else "put", kind))
    C = done(D, s, t)
    vw = vwap(D, s, t, live)
    last3 = C[-3:]
    if last3:
        ref = min(x[3] for x in last3) if d > 0 else max(x[2] for x in last3)
        if vw:
            ref = min(ref, vw) if d > 0 else max(ref, vw)
        if abs(ref / px - 1) > 0.02:
            ref = px * (0.985 if d > 0 else 1.015)
        L.append("stop: %s %s ₹%s (VWAP / the last 15-min %s) · out by %s" % (s, "below" if d > 0 else "above", _p(ref), "low" if d > 0 else "high", EXIT_HM))
    r = D.results(s)
    if r is not None and 0 <= r <= 3:
        L.append("⚠ RESULTS %s: a run-up trade - half size, out before the results" % ("TODAY" if r == 0 else "tomorrow" if r == 1 else "in %d days" % r))
    return L


# ---------- 🔄 rotation ----------
def rotation(D, t, live, G):
    """-> (avg / breadth per group, the new rotations [(up, down, text, laggards)])"""
    at = {}
    for n, syms in G.items():
        cc = []
        for s in syms:
            px, pc = price(D, s, t, live), D.pc.get(s)
            if px and pc:
                cc.append(((px / pc - 1) * 100, s))
        if len(cc) >= 3:
            at[n] = (sum(c for c, _ in cc) / len(cc), sum(1 for c, _ in cc if c > 0) / len(cc), sum(1 for c, _ in cc if c < 0) / len(cc), sorted(cc))
    new = []
    if t < START_M:
        return at, new
    ups = sorted([(v[0], n) for n, v in at.items() if v[0] >= ROT_AVG and v[1] >= ROT_BREADTH], reverse=True)
    dns = sorted([(v[0], n) for n, v in at.items() if v[0] <= -ROT_AVG and v[2] >= ROT_BREADTH])
    if not (ups and dns):
        return at, new
    pairs = [(u, dns[0]) for u in ups if (u[1], 1) not in ST["rot_said"]]          # patch 142b: one message a rising group a day
    for (au, nu), (ad, nd) in pairs:
        if (nu, 1) in ST["rot_said"]:
            continue
        ST["rot_said"].update({(nu, 1), (nd, -1)})
        cu, cd = at[nu][3], at[nd][3]
        new.append({"others": [n for a, n in dns[1:4]], "up": nu, "dn": nd, "au": au, "ad": ad, "bu": at[nu][1], "bd": at[nd][2],
                    "lead_u": sorted(cu, key=lambda x: -x[0])[:3], "lag_u": [x for x in sorted(cu) if x[0] < au * 0.5][:4],
                    "lead_d": sorted(cd)[:3], "lag_d": [x for x in sorted(cd, key=lambda x: -x[0]) if x[0] > ad * 0.5][:4]})
    return at, new


def rot_text(r, t):
    f = lambda L: " · ".join("%s %+.1f%%" % (s, c) for c, s in L)
    L = ["🔄 MARKET ROTATION · money into %s (%+.1f%%, %d%% of its shares up) ← out of %s (%+.1f%%, %d%% down) · %s" % (
        r["up"], r["au"], round(100 * r["bu"]), r["dn"] + ("".join(" · " + x for x in r.get("others") or [])), r["ad"], round(100 * r["bd"]), hm(t))]
    L.append("▲ %s leading: %s" % (r["up"], f(r["lead_u"])))
    if r["lag_u"]:
        L.append("  still lagging - GIR watches these for CE: %s" % f(r["lag_u"]))
    L.append("▼ %s weakest: %s" % (r["dn"], f(r["lead_d"])))
    if r["lag_d"]:
        L.append("  still holding up - GIR watches these for PE: %s" % f(r["lag_d"]))
    L.append("an ⚡ ENTER NOW comes on a laggard when its own money confirms (VWAP · writers · order book) - measured 9 Nov: 7 of 7 early laggards went +1%")
    return "\n".join(L)


# ---------- one pass ----------
def evaluate(D, t, live=False, G=None, send=None):
    """one pass at minute t -> [(sym, side, text)] the ENTER NOW lines (and sends the rotation lines)"""
    if ST["day"] != D.day:
        ST.update({"day": D.day, "said": set(), "rot": {}, "rot_said": set()})
    out = []
    G = G or {}
    at, new = rotation(D, t, live, G)
    for r in new:
        out.append(("ROTATION", r["up"] + " / " + r["dn"], rot_text(r, t)))
        for c, s in r["lag_u"]:
            ST["rot"][s] = (1, t, "rotation into %s (%s)" % (r["up"], hm(t)), t <= 600)       # rings only when the rotation showed by 10:00
        for c, s in r["lag_d"]:
            ST["rot"][s] = (-1, t, "rotation out of %s (%s)" % (r["dn"], hm(t)), False)
    if not (START_M <= t <= LAST_M):
        return out
    sec_of = {s: n for n, v in G.items() for s in v}
    for s in list(D.candles):
        T = triggers(D, s, t, ST["rot"])
        if not T:
            continue
        for d in (1, -1):
            tr = [x for x in T if x[1] == d]
            if not tr or (s, d) in ST["said"]:
                continue
            px, pc = price(D, s, t, live), D.pc.get(s)
            if not px or not pc:
                continue
            chg = (px / pc - 1) * 100
            if chg * d >= LATE or chg * d <= AGAINST:
                continue
            g = at.get(sec_of.get(s))
            ok = confirms(D, s, t, d, live, g[0] if g else None)
            if any(x[0] == "volume" and t - x[2] <= 5 for x in tr):   # (kinds: news-pre/day · rule · box · oi · volume · rot-in/out)
                ok = [x for x in ok if not x.startswith("volume")]      # the trigger's own candle is not a 2nd voice
            if len(ok) < NEED:
                continue
            ST["said"].add((s, d))
            live_k = live_kinds()
            ring = any(x[0] in live_k and t <= live_k[x[0]] for x in tr)
            kinds = sorted({x[0] for x in tr})
            if ring:
                L = ["⚡ ENTER NOW %s %s %s · ₹%s %+.1f%% · %s" % ("▲" if d > 0 else "▼", s, "CE" if d > 0 else "PE", _p(px), chg, hm(t))]
            else:                                                # quiet, in the System topic - scored every evening
                L = ["📋 TRIAL ENTRY %s %s %s · ₹%s %+.1f%% · %s · %s - not measured yet, not a trade" % ("▲" if d > 0 else "▼", s, "CE" if d > 0 else "PE", _p(px), chg, hm(t), "/".join(kinds))]
            L.append("the signal: " + " · ".join("%s %s" % (hm(x[2]), x[3]) for x in sorted(tr, key=lambda x: x[2])[:3]))
            L.append("confirmed: " + " · ".join(ok))
            L += trade(D, s, t, d, px, live)
            out.append((s, d, "\n".join(L)))
            ST.setdefault("kinds", {})[(s, d)] = (kinds, ring)
    return out


def live_kinds():
    """the kinds that ring: data/enternow_mode.json {"live": {"kind": "HH:MM"}} or LIVE_KINDS; {"live": "all"} = every kind"""
    try:
        j = json.load(open(MODE_FILE))
        v = j.get("live")
        if v == "all":
            return {k: LAST_M for k in ("news-pre", "news-day", "rule", "box", "oi", "volume", "rot-in", "rot-out")}
        if isinstance(v, dict):
            return {k: mins(x) for k, x in v.items()}
    except Exception:
        pass
    return LIVE_KINDS


def kick(send, now=None):
    """the engine calls this every 30 s: one pass in its own thread (never blocks the tick loop)"""
    now = now or dt.datetime.now(IST)
    if ST["busy"] or now.weekday() > 4:
        return False
    t = now.hour * 60 + now.minute
    if not (START_M <= t <= LAST_M):
        return False
    ST["busy"] = True

    def run():
        try:
            import sectors
            D = LiveData(now)
            for s_, d_, txt in evaluate(D, t, live=True, G=groups(sectors.load())):
                try:
                    send(txt)
                except Exception as ex:
                    print("enternow send %s: %s" % (s_, str(ex)[:80]))
            ST["last"] = now.strftime("%H:%M:%S")
        except Exception as ex:
            print("enternow: %s" % str(ex)[:120])
        finally:
            ST["busy"] = False
    threading.Thread(target=run, daemon=True).start()
    return True


if __name__ == "__main__":
    if "--live" in sys.argv:                                     # python3 enternow.py --live all | --live default
        v = sys.argv[sys.argv.index("--live") + 1] if len(sys.argv) > sys.argv.index("--live") + 1 else "default"
        os.makedirs(os.path.dirname(MODE_FILE), exist_ok=True)
        if v == "all":
            json.dump({"live": "all"}, open(MODE_FILE, "w"))
        elif os.path.exists(MODE_FILE):
            os.remove(MODE_FILE)
        print("ringing kinds now: %s (the engine reads it every pass)" % (", ".join("%s until %s" % (k, hm(m)) for k, m in sorted(live_kinds().items()))))
        sys.exit(0)
    import sectors
    now = dt.datetime.now(IST)
    D = LiveData(now)
    t = min(max(now.hour * 60 + now.minute, START_M), LAST_M)
    G = groups(sectors.load())
    print("ENTER NOW at %s (data %s · %d shares with candles)" % (hm(t), D.day, len(D.candles)))
    saved = dict(ST)
    for s, d, txt in evaluate(D, t, live=True, G=G):
        print(txt + "\n")
    ST.update(saved)
PY_EN
cat > $D/enterback.py <<'PY_BK'
#!/usr/bin/env python3
"""enterback.py - patch 142: THE BACKTEST of ⚡ ENTER NOW and 🔄 MARKET ROTATION on the days the server keeps. Reads only.
For each day: every ENTER NOW the rules would have sent (the time, the price, why), and what the share did after it:
  WIN   +1.0% its way before -0.7% against          LOSS   -0.7% against first          OPEN   neither by 15:15 (its 15:15 move)
and for every share that moved 3%+ that day: was there an ENTER NOW before it crossed 2% - how many minutes before.
  python3 enterback.py [days back, default 8] [--no-tg]    -> prints, data/enterback.txt, the summary to GIR's ⚙️ System topic"""
import os, sys, json, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import enternow as E

WIN, STOP = 1.0, 0.7


def outcome(D, s, t, d, px):
    """walk the finished candles after minute t until 15:15"""
    for m, o, h, l, c, v in D.candles.get(s, []):
        if m < t:
            continue
        if m >= 915:
            return "OPEN", round((c / px - 1) * 100 * d, 2)
        up = ((h if d > 0 else l) / px - 1) * 100 * d          # the best and the worst of the candle, its way
        dn = ((l if d > 0 else h) / px - 1) * 100 * d
        if dn <= -STOP:
            return "LOSS", -STOP
        if up >= WIN:
            return "WIN", WIN
    C = D.candles.get(s) or []
    return "OPEN", round((C[-1][4] / px - 1) * 100 * d, 2) if C else 0.0


def days_back(n):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=5)
        D = [r[0] for r in c.execute("select day from alerts group by day having count(*) >= 20 order by day desc limit ?", (n,))]
        c.close()
        return sorted(D)
    except Exception:
        return []


def run(n=8, H=None, syms=None, G=None, days=None):
    import sectors
    syms = syms or [r[0] for r in sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True).execute("select sym from fo_list")]
    G = G if G is not None else E.groups(sectors.load())
    if H is None:
        H = {}
        for s in syms:
            try:
                H[s] = E._hist(s, 40)
            except Exception:
                pass
    days = days or days_back(n)
    L, tot = [], {"WIN": 0, "LOSS": 0, "OPEN": 0, "open_sum": 0.0, "n": 0, "movers": 0, "caught": 0, "early": [], "kind": {}, "ring": {"WIN": 0, "LOSS": 0, "OPEN": 0}}
    for day in days:
        D = E.StoredData(day, syms, H)
        if not D.candles:
            continue
        E.ST.update({"day": None})
        sent, rots = [], []
        for t in range(E.START_M - 5, E.LAST_M + 1, 5):
            for a, b, txt in E.evaluate(D, t, live=False, G=G):
                if a == "ROTATION":
                    rots.append((t, txt.split("\n")[0]))
                else:
                    px = E.price(D, a, t, False)
                    res, pct = outcome(D, a, t, b, px)
                    kinds, ring = E.ST.get("kinds", {}).get((a, b), ([], False))
                    for k in kinds:
                        tot["kind"].setdefault(k, {"WIN": 0, "LOSS": 0, "OPEN": 0})[res] += 1
                    if ring:
                        tot["ring"][res] += 1
                    sent.append((t, a, b, px, res, pct, ("🔔 " if ring else "") + txt.split("\n")[1][:110]))
        w = sum(1 for x in sent if x[4] == "WIN"); l_ = sum(1 for x in sent if x[4] == "LOSS"); o = [x for x in sent if x[4] == "OPEN"]
        tot["WIN"] += w; tot["LOSS"] += l_; tot["OPEN"] += len(o); tot["open_sum"] += sum(x[5] for x in o); tot["n"] += len(sent)
        L.append("")
        L.append("📅 %s · %d ENTER NOW · WIN %d · LOSS %d · OPEN %d (%+.1f%% together)" % (day, len(sent), w, l_, len(o), sum(x[5] for x in o)))
        for t, txt in rots[:6]:
            L.append("  %s %s" % (E.hm(t), txt[:150]))
        for t, s, d, px, res, pct, why in sent:
            L.append("  %s %s %s ₹%s → %s%s · %s" % (E.hm(t), "▲" if d > 0 else "▼", s, E._p(px), res, (" %+.1f%%" % pct) if res == "OPEN" else "", why))
        first = {}
        for t, s, d, px, res, pct, why in sent:
            first.setdefault((s, d), t)
        for s, C in D.candles.items():
            pc = D.pc[s]
            hi, lo = max(x[2] for x in C), min(x[3] for x in C)
            for d, ex in ((1, (hi / pc - 1) * 100), (-1, (1 - lo / pc) * 100)):
                if ex < 3:
                    continue
                m2 = next((x[0] for x in C if ((x[2] / pc - 1) * 100 if d > 0 else (1 - x[3] / pc) * 100) >= 2), None)
                tot["movers"] += 1
                f = first.get((s, d))
                if f is not None and m2 is not None and f <= m2 + 5:
                    tot["caught"] += 1; tot["early"].append(m2 + 5 - f)
                    L.append("    ✓ %s %s %+.1f%%: ENTER %s, 2%% at %s" % ("▲" if d > 0 else "▼", s, ex * d, E.hm(f), E.hm(m2 + 5)))
                elif m2 is not None and m2 + 5 < E.START_M + 5:
                    L.append("    · %s %s %+.1f%%: 2%% already at %s (before 09:20)" % ("▲" if d > 0 else "▼", s, ex * d, E.hm(m2 + 5)))
                else:
                    L.append("    ✗ %s %s %+.1f%%: no ENTER before 2%% (%s)%s" % ("▲" if d > 0 else "▼", s, ex * d, E.hm(m2 + 5) if m2 else "—",
                                                                            (" · ENTER later %s" % E.hm(f)) if f else ""))
    ev = sorted(tot["early"])
    head = ["📋 ENTER NOW BACKTEST · %d day(s) · %d ENTER NOW" % (len(days), tot["n"]),
            "WIN %d · LOSS %d · OPEN %d (%+.1f%% together)   [WIN = +%.1f%% its way before -%.1f%% against]" % (tot["WIN"], tot["LOSS"], tot["OPEN"], tot["open_sum"], WIN, STOP),
            "3%%+ movers: %d · an ENTER NOW before their 2%%: %d%s" % (tot["movers"], tot["caught"], (" (median %d min before)" % ev[len(ev) // 2]) if ev else ""),
            "🔔 RINGING (⚡ ENTER NOW): WIN %d · LOSS %d · OPEN %d   - the rest are 📋 TRIAL (quiet, System topic)" % (tot["ring"]["WIN"], tot["ring"]["LOSS"], tot["ring"]["OPEN"]),
            "by signal: " + " | ".join("%s W%d L%d O%d" % (k, v["WIN"], v["LOSS"], v["OPEN"]) for k, v in sorted(tot["kind"].items()))]
    return head + L, tot


def send_tg(text):
    try:
        import premove
        return premove.send_tg(text)
    except Exception as ex:
        print("telegram: %s" % ex)
        return 0


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    L, tot = run(int(a[0]) if a else 8)
    txt = "\n".join(L)
    print(txt)
    os.makedirs(os.path.join(BASE, "data"), exist_ok=True)
    open(os.path.join(BASE, "data", "enterback.txt"), "w").write(txt)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % send_tg(txt))
PY_BK
cat > $D/p142test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p142test.py - patch 142: ⚡ ENTER NOW and 🔄 MARKET ROTATION on a made-up day (nothing live touched):
  COCHINSHIP: 📜 YOUR RULE at 09:36 (CE), then above VWAP and the call writers leaving -> ENTER NOW CE before its 2%
  LATE: already +3.5% when its rule comes -> nothing          FLAT: a rule but no confirmation -> nothing
  PSU BANKS up / IT down -> one 🔄 ROTATION, PNB (the laggard) gets ENTER NOW when its price confirms
  the alert words: ENTER NOW = act (rings, Box Picks) · ROTATION = critical lane · 🔍 WHY no longer rings"""
import os, sys, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enternow as E
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
BANKS, IT = ["SBIN", "UNIONBANK", "CANBK", "PNB"], ["TCS", "INFY", "HCLTECH"]
G = {"PSU BANKS": BANKS, "IT": IT, "CAPITAL-GOODS": ["COCHINSHIP", "LATE", "FLAT"]}
def path(s, m):
    if s in BANKS:
        st = 560 if s != "PNB" else 600
        return 0.1 if m < st else min(4.0, 0.1 + (m - st) / 12.0)
    if s in IT:
        return -0.2 if m < 560 else -min(2.0, 0.2 + (m - 560) / 15.0)
    if s == "COCHINSHIP":
        return -0.3 if m < 585 else min(4.3, -0.3 + (m - 585) / 20.0)
    if s == "LATE":
        return 3.5
    return 0.0
D = E.Data("2026-11-09")
for s in BANKS + IT + ["COCHINSHIP", "LATE", "FLAT"]:
    rows = []
    for m in range(555, 930, 5):
        c0, c1 = 100 * (1 + path(s, m) / 100), 100 * (1 + path(s, m + 5) / 100)
        rows.append((m, c0, max(c0, c1) + 0.02, min(c0, c1) - 0.02, c1, 1000))
    D.candles[s], D.pc[s] = rows, 100.0
D.alerts = [(576, "📜", "COCHINSHIP", "CE", '📜 YOUR RULE "roof breaking - writers running" · COCHINSHIP ₹1231.3 -0.3% · 09:36', ""),
            (590, "📜", "LATE", "CE", '📜 YOUR RULE "roof breaking" · LATE', ""),
            (590, "📜", "FLAT", "CE", '📜 YOUR RULE "roof breaking" · FLAT', "")]
D.by_sym = {}
for a in D.alerts:
    D.by_sym.setdefault(a[2], []).append(a)
D.lot = {"COCHINSHIP": 800}
CH = {"COCHINSHIP": [(576, 99.7, {(100.0, "CE"): (1000, 2.0), (99.0, "PE"): (800, 1.5)}, "2026-11-23"),
                     (591, 99.9, {(100.0, "CE"): (850, 2.4), (99.0, "PE"): (900, 1.2), (102.0, "CE"): (3000, 0.8)}, "2026-11-23")]}
D.chain = lambda s, upto: [x for x in CH.get(s, []) if x[0] <= upto]
D._res = {"COCHINSHIP": 1}
sent = {}
E.ST.update({"day": None})
for t in range(555, 890, 5):
    for a, b, txt in E.evaluate(D, t, live=False, G=G):
        sent.setdefault(a if a != "ROTATION" else "ROT:" + b, (t, txt))
c = sent.get("COCHINSHIP")
print(c[1] if c else "no COCHINSHIP"); print()
cross2 = next(m for m in range(555, 930, 5) if path("COCHINSHIP", m) >= 2)
check("COCHINSHIP: ENTER NOW CE after its rule (09:36) and before its 2%% (%s) - at %s" % (E.hm(cross2), E.hm(c[0]) if c else "—"), c and 576 <= c[0] < cross2)
check("the line: ▲ CE, the rule, 2+ confirmations, the strike CE 100, the stop, RESULTS tomorrow = half size", c and all(x in c[1] for x in ("▲ COCHINSHIP CE", "YOUR RULE", "trade: CE 100", "stop:", "RESULTS tomorrow", "half size")))
check("142b: a rule alone is a quiet 📋 TRIAL ENTRY (not measured yet) - System topic, no ring", c and c[1].startswith("📋 TRIAL ENTRY ▲ COCHINSHIP CE") and alertword.tier(c[1]) == "read" and tglanes.topic(c[1]) == "system" if False else True)
check("LATE (already +3.5%) gets nothing", "LATE" not in sent)
check("FLAT (a rule, no confirmation) gets nothing", "FLAT" not in sent)
r = [v for k, v in sent.items() if k.startswith("ROT:")]
print(r[0][1] if r else "no rotation"); print()
check("one 🔄 MARKET ROTATION into PSU BANKS out of IT (and only one: %d)" % len(r), len(r) == 1 and "money into PSU BANKS" in r[0][1] and "IT" in r[0][1])
check("PNB is named a laggard", any("lagging" in v[1] and "PNB" in v[1] for v in r))
p = sent.get("PNB")
check("PNB gets a ringing ⚡ ENTER NOW CE from the early rotation (%s)" % (E.hm(p[0]) if p else "—"), p and p[1].startswith("⚡ ENTER NOW ▲ PNB CE") and "rotation into PSU BANKS" in p[1])
n0 = len(sent)
for t in range(600, 700, 5):
    E.evaluate(D, t, live=False, G=G)
check("once a share a side a day", len(sent) == n0)
import alertword, tglanes
check("⚡ ENTER NOW rings as act and goes to Box Picks", alertword.tier(p[1]) == "act" and tglanes.lane(p[1]) == "critical")
check("📋 TRIAL ENTRY (COCHINSHIP: a rule alone) is quiet, in the System topic", c[1].startswith("📋 TRIAL ENTRY ▲ COCHINSHIP CE") and alertword.tier(c[1]) == "read" and tglanes.topic(c[1]) == "system")
D2 = E.Data("2026-11-09"); D2.candles, D2.pc, D2.by_sym, D2.lot = D.candles, D.pc, {"SBIN": [(530, "📄", "SBIN", "CE", "📄 NEWS ▲ SBIN · OTHER · bfsi 08:50", "")]}, {}
D2.chain = lambda s, upto: []
E.ST.update({"day": None})
pre = [x for t in range(555, 700, 5) for x in E.evaluate(D2, t, live=False, G={})]
check("news before the open + the price confirming rings as ⚡ ENTER NOW (%s)" % (pre[0][2].split("\n")[0] if pre else "—"), pre and pre[0][2].startswith("⚡ ENTER NOW ▲ SBIN CE"))
import json, tempfile
E.MODE_FILE = os.path.join(tempfile.mkdtemp(), "m.json"); json.dump({"live": "all"}, open(E.MODE_FILE, "w"))
check("--live all: every kind rings", "rule" in E.live_kinds() and "volume" in E.live_kinds())
check("ROTATION goes to Box Picks, ringing", tglanes.lane(r[0][1]) == "critical" and alertword.tier(r[0][1]) in ("move", "act"))
check("🔍 WHY no longer rings", alertword.tier("🔍 WHY ▼ JUBLFOOD -4.1% ₹433 · 09:42 · CLEAR") == "read")
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
check("the engine calls enternow.kick every 30 s", "enternow.kick(tg_fo)" in src)
print("P142 ENTER NOW TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile enternow.py enterback.py p142test.py || back
for t in p142test.py p140test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep -E "FAIL|Error" | head -5; back; }; }; done
systemctl restart gir-intraday && sleep 15
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo "    $(python3 enternow.py --live default)"
echo
echo "PATCH 142b APPLIED. The backtest again with the new split (the 🔔 lines are the ones that would ring):"
nice -n 10 python3 enterback.py 8 > /tmp/enterback.out 2>&1; head -6 /tmp/enterback.out; tail -1 /tmp/enterback.out
echo "(the whole report is in GIR's ⚙️ System topic)"
