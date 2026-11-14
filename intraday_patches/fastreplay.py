#!/usr/bin/env python3
"""fastreplay.py - READ ONLY. (+ MONEY FIRST: how fast the share follows the futures money · WHAT MAKES A SHARE MOVE: which of the 3 together · BACKWARDS: what was there before the real moves, news + hidden orders · MOMENTUM: Rama's way, after 3/5/8%) FRIDAY AGAIN, WITH PATCHES 275-278 (Rama, 14 Nov: "recheck one more time with the Friday data after updating the code -
how fast are we getting the futures, options and OI data"). Zerodha keeps every F&O contract's MINUTE candles with OPEN INTEREST: this fetches the
day's futures (218 shares) and, for every 🌪 card, the 6 strikes nearest the price (CE + PE), then runs the SAME rules as windwatch.py on them:
the wind (price 3 min · futures OI 3 min · sector), 🌪 BIG MOVER, the writers, and each card to its 🎯 / 🚪. Against the day's 47 real moves and what
GIR really sent that day. The live watcher reads every 3 s; this replay only has minutes - the live one is up to a minute EARLIER than shown here.
The order book is not in Zerodha's history: shown both ways (book counted as no = strict · as yes = loose).
Changes nothing, sends nothing, orders nothing.   python3 fastreplay.py [YYYY-MM-DD]"""
import os, re, sys, json, time, sqlite3, statistics, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__)) if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), "windwatch.py")) else "/home/globalbot/intraday"
sys.path.insert(0, BASE); os.chdir(BASE)
import numpy as np
import windwatch as WW
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
if sys.argv[1:2] == ["days"]:
    # ---- which recent days were which kind of market (NIFTY 50's own daily candles) -> 2 of each kind, ready to replay ----
    import core
    try:
        k = core.get_kite()
        R = k.historical_data(256265, (now - dt.timedelta(days=75)).replace(tzinfo=None), now.replace(tzinfo=None), "day")
    except Exception as ex:
        print("⚠ Zerodha did not answer (%s) - run it with GIR's keys loaded" % str(ex)[:90]); sys.exit(0)
    rows, prev = [], None
    for r in R:
        c = float(r["close"])
        if prev:
            rows.append((r["date"].date(), (c / prev - 1) * 100, (float(r["high"]) - float(r["low"])) / prev * 100, c))
        prev = c
    old = now.date() - dt.timedelta(days=45)                   # older days: the futures contract that is live today was then a far month (thin)
    print("=== THE LAST %d MARKET DAYS - NIFTY 50 (close vs the day before · the day's range)" % len(rows))
    kind = lambda chg, rg: "▼ FALLING" if chg <= -0.6 else "▲ RISING" if chg >= 0.6 else "↕ CHOPPY" if rg >= 1.1 else "→ FLAT"
    for d_, chg, rg, c in rows[-40:]:
        print("  %s %s  %+.2f%%  range %.2f%%  %-10s%s" % (d_, d_.strftime("%a"), chg, rg, kind(chg, rg), "  (thin futures data)" if d_ < old else ""))
    ok = [x for x in rows if x[0] >= old and x[0].weekday() < 5]          # weekdays only - a special session (Muhurat) is not a normal day
    pick = []
    for nm, key, rev in (("▼ FALLING", lambda x: x[1], False), ("▲ RISING", lambda x: x[1], True), ("↕ CHOPPY", lambda x: x[2] - abs(x[1]), True), ("→ FLAT", lambda x: abs(x[1]) + x[2], False)):
        L = sorted([x for x in ok if kind(x[1], x[2]) == nm], key=key, reverse=rev)[:2]
        pick += [(nm, x) for x in L]
    print("\n=== 2 OF EACH KIND (the last 45 days, the futures contract live today):")
    for nm, x in pick:
        print("  %-10s %s  NIFTY %+.2f%% · range %.2f%%" % (nm, x[0], x[1], x[2]))
    ds = " ".join(str(x[0]) for _, x in sorted(pick, key=lambda y: y[1][0]))
    print("\n=== THE COMMAND - replay these %d days (about 5 min each):" % len(pick))
    print('( set -a; . /home/globalbot/.env; set +a; for d in %s; do echo "##### $d"; python3 %s $d | grep -E "^=== 3[bcd]|BEST TOGETHER|OPPOSITE|follow |broke out|moves:|news \\+|%% · "; done )' % (ds, os.path.abspath(__file__)))
    sys.exit(0)
day = sys.argv[1] if len(sys.argv) > 1 else ""
if not day:
    d = now.date() - dt.timedelta(days=1 if now.strftime("%H:%M") < "15:35" else 0)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    day = str(d)
D0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST)
d0 = D0.timestamp()
HM = lambda ts: dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M")
med = lambda L: statistics.median(L) if L else None
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)

# ---------------- 1 · the data pipes, as they are now ----------------
print("=== 1 · HOW FAST THE DATA COMES NOW (patches 275-278)")
def age(p, key="t"):
    try:
        j = json.load(open(p)); t = float(j.get(key) or 0)
        return t
    except Exception:
        return None
live_open = now.weekday() < 5 and "09:15" <= now.strftime("%H:%M") <= "15:30"
for name, p, every in (("prices of every share (quotes_live.json)", "quotes_live.json", "every 1 s"),
                       ("futures price + OI + order book (data/fut_live.json)", "data/fut_live.json", "every 1 s"),
                       ("option strikes, 11 nearest × CE/PE, 218 shares (pins_live.json)", "pins_live.json", "every 5 s"),
                       ("the wind: read + 🌪 / 🔄 / 🎯 / 🚪 decided (data/wind.json)", "data/wind.json", "every 3 s")):
    t = age(p)
    st = ("%.0f s old ✓" % (time.time() - t) if time.time() - t < 30 else "%.0f s old ⚠" % (time.time() - t)) if (t and live_open) else \
         ("last written %s (market closed)" % dt.datetime.fromtimestamp(t, IST).strftime("%a %H:%M:%S") if t else "not written yet")
    print("  %-70s %-10s %s" % (name, every, st))
print("  Telegram: 🌪 / 🎯 / 🚪 / 🔄 go straight to GIR Bigmovers (about 1-2 s) · the old path's median was 28 s")
print("  before (Friday): futures OI reached the alerts on 5-min candles · option OI from the slow chain - %s" % "every ~75 min per share (1,090 readings / 218 shares)")

# ---------------- 2 · the day's real moves (the same rule as windaudit.sh) ----------------
fo = set()
try:
    c = ro("chains.db"); fo = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
except Exception:
    pass
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def bars(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s, "data/h3/5min/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float)
            idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                return ts[idx], np.asarray(z["c"], float)[idx]
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c") and len(x["c"]) >= 20:
        C = np.array([v if v is not None else np.nan for v in x["c"]], float)
        return np.array([d0 + 300 * i for i in range(len(C))], float), C
    return None
M = []
for s in sorted(fo or (set(CJ) - {"NIFTY 50", "NIFTY BANK"})):
    b = bars(s)
    if not b:
        continue
    ts, C = b
    seen = set()
    for i in range(3, len(C) - 2):
        if np.isnan(C[i]) or np.isnan(C[i - 3]) or not C[i - 3]:
            continue
        r15 = (C[i] / C[i - 3] - 1) * 100
        if abs(r15) < 1.0:
            continue
        sd = 1 if r15 > 0 else -1
        if sd in seen:
            continue
        st = i - 3
        while st < i and not np.isnan(C[st + 1]) and (C[st + 1] - C[st]) * sd <= 0:
            st += 1
        while st > 0 and not np.isnan(C[st - 1]) and (C[st] - C[st - 1]) * sd > 0:
            st -= 1
        fut = C[i:min(len(C), i + 13)]
        best = (np.nanmax(fut) if sd > 0 else np.nanmin(fut))
        if (best / C[st] - 1) * 100 * sd < 1.5:
            continue
        seen.add(sd)
        M.append({"s": s, "sd": sd, "t0": ts[st] + 300, "hour": (best / C[st] - 1) * 100 * sd})
# what GIR really sent that day (the first alert / the first ring per move)
try:
    c = ro("tomorrow.db"); A = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception:
    A = []
AL = {}
for t, s, tx in A:
    h = (tx or "").split("\n")[0]
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
    if not m:
        continue
    try:
        ts_ = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    rang = "🔕" not in (tx or "") and bool(re.search(r"🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|CRITICAL|CONFIRMED MOVE", tx or ""))
    AL.setdefault(m.group(2), []).append((ts_, 1 if m.group(1) == "▲" else -1, rang))

# ---------------- 3 · Zerodha's minute candles with OI ----------------
import core
try:
    k = core.get_kite()
    try:
        k.timeout = 10
    except Exception:
        pass
    NFO = k.instruments("NFO")
    k.profile()
except Exception as ex:
    print("\n⚠ Zerodha did not answer (%s)." % str(ex)[:90])
    print("  Zerodha's login ends every morning at 6 AM - GIR logs in again before the market on a trading day.")
    print("  Run this again on Monday after 08:45 (Friday's data is still there):  python3 %s %s" % (os.path.abspath(__file__), day))
    sys.exit(0)
dd = D0.date()
FUT, OPT = {}, {}
for r in NFO:
    ex = r.get("expiry")
    if not ex or ex < dd:
        continue
    nm = r.get("name")
    if r.get("instrument_type") == "FUT":
        if nm not in FUT or ex < FUT[nm][1]:
            FUT[nm] = (r["instrument_token"], ex)
    elif r.get("instrument_type") in ("CE", "PE"):
        OPT.setdefault(nm, []).append((ex, float(r["strike"]), r["instrument_type"], r["instrument_token"]))
syms = sorted(s for s in (fo or FUT) if s in FUT)
print("\n=== 2 · fetching %s's minute candles + OI from Zerodha: %d futures (about %d s) ..." % (day, len(syms), len(syms) * 0.4), flush=True)
def hist(tok, back=0):
    for a in range(3):
        try:
            return k.historical_data(tok, (D0 - dt.timedelta(days=back)).replace(tzinfo=None), D0.replace(hour=15, minute=30, tzinfo=None), "minute", oi=True)
        except Exception as ex:
            if "Too many" in str(ex) or "rate" in str(ex).lower():
                time.sleep(1.5); continue
            return []
    return []
MIN = {}            # sym -> (ts[], close[], oi[])
VOLD = {}           # sym -> (volume[], the normal volume for that minute of the day[], VWAP[])  - the last 8 days give the normal
def split_day(R):
    today = [r for r in R if r["date"].astimezone(IST).date() == dd]
    base = {}
    for r in R:
        dl = r["date"].astimezone(IST)
        if dl.date() < dd:
            base.setdefault(dl.hour * 60 + dl.minute, []).append(float(r.get("volume") or 0))
    prior = [r for r in R if r["date"].astimezone(IST).date() < dd]
    PC_[0] = float(prior[-1]["close"]) if prior else None
    return today, base
PC_ = [None]
PCL = {}            # sym -> the day before's close (the futures)
def vol_info(today, base):
    v = np.array([float(r.get("volume") or 0) for r in today], float)
    nb = np.array([(sorted(base[m])[len(base[m]) // 2] if len(base.get(m) or []) >= 2 else np.nan)
                   for m in ((r["date"].astimezone(IST).hour * 60 + r["date"].astimezone(IST).minute) for r in today)], float)
    tp = np.array([(float(r.get("high") or r["close"]) + float(r.get("low") or r["close"]) + float(r["close"])) / 3 for r in today], float)
    cv = np.cumsum(v); vw = np.where(cv > 0, np.cumsum(tp * v) / np.maximum(cv, 1), tp)
    return v, nb, vw
IDX = {}
MHL = {}            # sym -> (high[], low[]) of each minute (patch 283 study: the initial balance)
for n, s in enumerate(syms + [x for x in ("NIFTY", "BANKNIFTY") if x in FUT and x not in syms]):
    R = hist(FUT[s][0], back=8); time.sleep(0.34)
    R, B = split_day(R)
    if PC_[0]:
        PCL[s] = PC_[0]
    if len(R) >= 30:
        arr = (np.array([r["date"].timestamp() + 60 for r in R], float), np.array([r["close"] for r in R], float), np.array([r.get("oi") or 0 for r in R], float))
        if s in ("NIFTY", "BANKNIFTY"):
            IDX[s] = arr                                                   # the index tide - not a share
        else:
            MIN[s] = arr; VOLD[s] = vol_info(R, B)
            MHL[s] = (np.array([float(r.get("high") or r["close"]) for r in R], float), np.array([float(r.get("low") or r["close"]) for r in R], float))
    if n % 50 == 49:
        print("  %d of %d" % (n + 1, len(syms)), flush=True)
print("  futures with minute data: %d · volume normal from the 8 days before: %d · index: %s" % (len(MIN), sum(1 for v in VOLD.values() if np.isfinite(v[1]).sum() > 100), " ".join(IDX) or "-"))

# ---------------- 3f · THE INITIAL BALANCE (Rama, 14 Nov: "go, start the initial balance test") ----------------
# Auction market theory / TPO: the first 15 / 30 / 60 minutes make the day's opening range (the INITIAL BALANCE). A break out of it is the market
# accepting a new price - the classic momentum entry. For every F&O share, the FIRST minute its close breaks above (below) the range: entry there.
# KEPT GOING = 1% more its way before it closes BACK INSIDE the range · BACK INSIDE = the break failed · and held to 15:20.
def ib_study():
    sec = WW.sectors_of(); of = {}
    for kk, v in sec.items():
        for x in v:
            of.setdefault(x, kk)
    res_set = set()
    try:
        c = ro("chains.db"); p_ = (D0 - dt.timedelta(days=1)).date()
        while p_.weekday() > 4:
            p_ -= dt.timedelta(days=1)
        res_set = {r[0] for r in c.execute("select sym from results_cal where d in (?, ?)", (day, str(p_)))}; c.close()
    except Exception:
        pass
    NI = IDX.get("NIFTY")
    def ib_of(ts, H, L, mins):
        k = np.nonzero(ts <= d0 + 60 * mins + 1)[0]
        return (float(np.max(H[k])), float(np.min(L[k])), int(k[-1])) if len(k) >= max(3, mins // 2) else None
    nib = {m: (ib_of(NI[0], NI[1], NI[1], m) if NI is not None else None) for m in (15, 30, 60)}
    EV = []
    for s, (ts, C, OI) in MIN.items():
        if s not in MHL:
            continue
        H, L = MHL[s]
        vv, nb, vw = VOLD.get(s, (None, None, None))
        pc = PCL.get(s)
        for mins in (15, 30, 60):
            ib = ib_of(ts, H, L, mins)
            if not ib:
                continue
            hi, lo, k0 = ib
            width = (hi / lo - 1) * 100 if lo else None
            for d in (1, -1):
                idx = [i for i in range(k0 + 1, len(C)) if (C[i] > hi if d > 0 else C[i] < lo)]
                if not idx:
                    continue
                i = idx[0]; t = ts[i]
                if HM(t) > "14:30":
                    continue
                edge = hi if d > 0 else lo; p0 = float(C[i]); res = "neither"
                for j in range(i + 1, len(C)):
                    if (float(C[j]) / p0 - 1) * 100 * d >= 1.0:
                        res = "kept going"; break
                    if (C[j] <= edge if d > 0 else C[j] >= edge):
                        res = "back inside"; break
                k_ = int(np.searchsorted(ts, d0 + 6 * 3600 + 5 * 60, side="right") - 1)
                k_ = max(i, min(len(C) - 1, k_))
                hold = (float(C[k_]) / p0 - 1) * 100 * d
                vr = None
                if vv is not None and i >= 2:
                    b_ = nb[i - 2:i + 1]
                    if np.isfinite(b_).all() and b_.sum() > 0:
                        vr = float(vv[i - 2:i + 1].sum() / b_.sum())
                doi = float((OI[i] / OI[0] - 1) * 100) if OI[0] and OI[i] else None
                nwith = False
                if NI is not None and nib.get(mins):
                    jn = int(np.searchsorted(NI[0], t, side="right") - 1)
                    if jn >= 0:
                        nwith = (NI[1][jn] > nib[mins][0]) if d > 0 else (NI[1][jn] < nib[mins][1])
                peers = []
                for x in (sec.get(of.get(s)) or []):
                    if x != s and x in MIN and x in MHL:
                        ibx = ib_of(MIN[x][0], MHL[x][0], MHL[x][1], mins)
                        jx = int(np.searchsorted(MIN[x][0], t, side="right") - 1)
                        if ibx and jx >= 0:
                            peers.append((MIN[x][1][jx] > ibx[0]) if d > 0 else (MIN[x][1][jx] < ibx[1]))
                gap = ((float(C[0]) / pc - 1) * 100 * d) if pc else None
                EV.append({"s": s, "d": d, "m": mins, "t": t, "res": res, "hold": hold, "vol": vr is not None and vr >= 2.0,
                           "money": doi is not None and doi >= 1.0, "nifty": nwith, "sect": bool(peers) and sum(peers) * 2 >= len(peers),
                           "narrow": width is not None and width < 1.0, "wide": width is not None and width >= 2.0, "early": HM(t) < "10:00",
                           "results": s in res_set, "gap": gap is not None and gap >= 1.0, "gapx": gap is not None and gap <= -1.0,
                           "chg": ((p0 / pc - 1) * 100 * d) if pc else None})
    return EV
IBE = ib_study()
print("\n=== 3f · THE INITIAL BALANCE - the first 15 / 30 / 60 min range, then the FIRST break out of it: KEPT GOING 1%% or BACK INSIDE? %s" % day)
def irow(L, name):
    if not L:
        print("  %-48s none" % name); return
    kg = sum(1 for e in L if e["res"] == "kept going"); bi = sum(1 for e in L if e["res"] == "back inside")
    print("  %-48s %4d · KEPT GOING %3d%% · BACK INSIDE %3d%% · held to 15:20 %+.2f%%" % (name, len(L), round(100 * kg / len(L)), round(100 * bi / len(L)),
          sum(e["hold"] for e in L) / len(L)))
for d, lab in ((1, "▲ UP"), (-1, "▼ DOWN")):
    for mins in (15, 30, 60):
        E = [e for e in IBE if e["d"] == d and e["m"] == mins]
        irow(E, "%s break of the first %d min" % (lab, mins))
        if mins in (15, 30) and E:
            for key, nm in (("early", "before 10:00"), ("vol", "VOLUME 2x its normal"), ("money", "NEW futures money (OI +1% since the open)"),
                            ("sect", "its SECTOR broke out too"), ("nifty", "NIFTY broke out too"), ("narrow", "a NARROW range (under 1%)"),
                            ("wide", "a WIDE range (2%+)"), ("results", "RESULTS today / last evening"), ("gap", "gapped its way 1%+"), ("gapx", "gapped the OTHER way 1%+")):
                irow([e for e in E if e[key]], "   ... " + nm)
            irow([e for e in E if e["early"] and e["vol"]], "   ... before 10:00 + VOLUME")
            irow([e for e in E if e["early"] and e["vol"] and (e["sect"] if d > 0 else e["money"])], "   ... before 10:00 + VOLUME + " + ("SECTOR (the CE rule)" if d > 0 else "NEW money (the PE rule)"))
print("  READ: compare with 3e (a share already 3%% up before 10:00: kept going 2%% more 33%%, turned back 11%%). Rows with high KEPT GOING and low BACK INSIDE win.")

# ---------------- 3g · STOCKS IN PLAY - THE 5-MINUTE OPENING RANGE BREAKOUT (Setup A: the research-backed day-trading rule, tested on India) ----------------
# 09:20: rank every F&O share by its first-5-minute volume vs its own normal first 5 minutes (RVOL). The first 5 minutes' direction picks the side
# (up candle -> only CE, down -> only PE). Entry: the first close beyond the 5-minute high (low). Stop: the other side of the 5-minute range = 1R.
# Exit: the stop, or 15:20. Measured in R (risk units) and %: does it pay, and does it pay MORE on the stocks in play (top 20 by RVOL)?
def orb_study():
    EV = []
    for s, (ts, C, OI) in MIN.items():
        if s not in MHL or s not in VOLD:
            continue
        H, L = MHL[s]; vv, nb, vw = VOLD[s]
        k = np.nonzero(ts <= d0 + 300 + 1)[0]
        if len(k) < 4:
            continue
        k5 = int(k[-1]); hi, lo = float(np.max(H[:k5 + 1])), float(np.min(L[:k5 + 1]))
        o_, c5 = float(C[0]), float(C[k5])
        b_ = nb[:k5 + 1]
        rv = float(vv[:k5 + 1].sum() / b_.sum()) if (np.isfinite(b_).all() and b_.sum() > 0) else None
        d = 1 if c5 > o_ * 1.0005 else -1 if c5 < o_ * 0.9995 else 0
        if not d or hi <= lo:
            continue
        edge, stop = (hi, lo) if d > 0 else (lo, hi)
        idx = [i for i in range(k5 + 1, len(C)) if (C[i] > edge if d > 0 else C[i] < edge) and HM(ts[i]) <= "11:00"]
        if not idx:
            EV.append({"s": s, "d": d, "rv": rv, "trade": False}); continue
        i = idx[0]; e = float(C[i]); R_ = abs(e - stop)
        if R_ <= 0 or R_ / e > 0.04:
            continue
        out, two = None, False
        kend = int(np.searchsorted(ts, d0 + 6 * 3600 + 5 * 60, side="right") - 1)
        for j in range(i + 1, max(i + 1, kend + 1)):
            if (L[j] <= stop if d > 0 else H[j] >= stop):
                out = -1.0; break
            if not two and ((H[j] - e) * d >= 2 * R_ if d > 0 else (e - L[j]) >= 2 * R_):
                two = True
        if out is None:
            out = (float(C[max(i, min(len(C) - 1, kend))]) - e) * d / R_
        EV.append({"s": s, "d": d, "rv": rv, "trade": True, "r": out, "pct": out * R_ / e * 100, "two": two, "t": ts[i]})
    return EV
ORBE = orb_study()
print("\n=== 3g · STOCKS IN PLAY - the 5-minute opening range breakout, the first 5 minutes pick the side, stop = the other side (1R), out at 15:20 · %s" % day)
def orow(L, name):
    T_ = [e for e in L if e.get("trade")]
    if not T_:
        print("  %-46s none" % name); return
    w = sum(1 for e in T_ if e["r"] > 0)
    print("  %-46s %4d · WON %3d%% · 2R reached %3d%% · average %+.2fR (%+.2f%% on the share) · total %+.1fR" % (
        name, len(T_), round(100 * w / len(T_)), round(100 * sum(1 for e in T_ if e["two"]) / len(T_)), sum(e["r"] for e in T_) / len(T_),
        sum(e["pct"] for e in T_) / len(T_), sum(e["r"] for e in T_)))
ranked = sorted([e for e in ORBE if e.get("rv")], key=lambda e: -e["rv"])
top = {id(e) for e in ranked[:20] if e["rv"] >= 1.0}
for d, lab in ((0, "every F&O share"), (1, "▲ CE side"), (-1, "▼ PE side")):
    E = [e for e in ORBE if (not d or e["d"] == d)]
    orow(E, lab)
    orow([e for e in E if id(e) in top], "   ... the STOCKS IN PLAY (top 20 by RVOL, 1x+)")
    orow([e for e in E if e.get("rv") and e["rv"] >= 3.0], "   ... RVOL 3x+")
    orow([e for e in E if e.get("rv") is not None and e["rv"] < 1.0], "   ... RVOL under 1x (not in play)")
print("  READ: average R above 0 = it pays. Taking 1R = your risk per trade (e.g. ₹10,000), +0.20R a trade over 20 trades = +4R = ₹40,000.")

if "ib" in sys.argv[2:]:
    sys.exit(0)                                                          # python3 fastreplay.py DAY ib - only the initial balance (fast)

# ---------------- 3b · MONEY FIRST, THEN THE PRICE (Rama, 14 Nov: "when the futures money is betting for a rise or a fall, how fast does the share react") ----------------
def money_first():
    """every time the futures OI jumps 0.5%+ in 3 min while the price has only begun to lean (0.1-0.5%): new money betting on a rise (price
    leaning up = early long build-up) or a fall (leaning down = early short build-up). Then, minute by minute for 30 min: when the price went
    0.5% / 1% further its way, or 0.5% the other way first. Once a share-side in 30 min, not after 15:00."""
    EV = []
    for s, (ts, C, OI) in MIN.items():
        last = {1: -1e9, -1: -1e9}
        n = len(C)
        for i in range(3, n - 1):
            if not OI[i - 3] or not C[i - 3]:
                continue
            oi3 = float((OI[i] / OI[i - 3] - 1) * 100); px3 = float((C[i] / C[i - 3] - 1) * 100)
            if oi3 < 0.5:
                continue
            d = 1 if 0.1 <= px3 < 0.5 else -1 if -0.5 < px3 <= -0.1 else 0
            if not d or ts[i] - last[d] < 1800 or HM(ts[i]) > "15:00":
                continue
            last[d] = ts[i]
            p0 = float(C[i]); t05 = t10 = bad = None; best = 0.0
            for j in range(i + 1, min(n, i + 31)):
                mv = (float(C[j]) / p0 - 1) * 100 * d
                best = max(best, mv)
                if t05 is None and mv >= 0.5:
                    t05 = (ts[j] - ts[i]) / 60
                if t10 is None and mv >= 1.0:
                    t10 = (ts[j] - ts[i]) / 60
                if bad is None and mv <= -0.5:
                    bad = (ts[j] - ts[i]) / 60
            fol = t05 is not None and (bad is None or t05 < bad)
            EV.append({"s": s, "d": d, "t": ts[i], "oi3": oi3, "px3": px3, "t05": t05, "t10": t10, "bad": bad, "fol": fol, "best": best})
    return EV
EV = money_first()
print("\n=== 3 · MONEY FIRST, THEN THE PRICE - when the futures money starts betting, how fast does the share follow? (%s, %d shares)" % (day, len(MIN)))
print("  a 'bet' = futures OI +0.5% or more in 3 min while the price has only begun to lean its way (0.1-0.5%) · then 30 min watched")
def summ(L, name):
    if not L:
        print("  %-44s none" % name); return
    f = [e for e in L if e["fol"]]; b = [e for e in L if e["bad"] is not None and not e["fol"]]
    t5 = [e["t05"] for e in f]; t1 = [e["t10"] for e in L if e["t10"] is not None and e["fol"]]
    print("  %-44s %3d bets · the price FOLLOWED %d (%d%%) · went the OTHER way first %d (%d%%) · nothing much %d" % (
        name, len(L), len(f), round(100 * len(f) / len(L)), len(b), round(100 * len(b) / len(L)), len(L) - len(f) - len(b)))
    if t5:
        print("  %-44s when it followed: +0.5%% more after a median %.0f min (fastest quarter %.0f min) · +1%% after %s min · best in 30 min: median %+.1f%%" % (
            "", med(t5), sorted(t5)[max(0, len(t5) // 4 - 1)], ("%.0f" % med(t1)) if t1 else "-", med([e["best"] for e in f])))
summ([e for e in EV if e["d"] > 0], "▲ betting on a RISE (early long build-up)")
summ([e for e in EV if e["d"] < 0], "▼ betting on a FALL (early short build-up)")
for lo, hi, nm in ((0.5, 1.0, "small money (OI +0.5-1% in 3 min)"), (1.0, 2.0, "big money (OI +1-2%)"), (2.0, 99, "very big money (OI +2%+)")):
    summ([e for e in EV if lo <= e["oi3"] < hi], nm)
for a, b_, nm in (("09:15", "10:00", "at the open (09:15-10:00)"), ("10:00", "13:00", "midday (10:00-13:00)"), ("13:00", "15:01", "afternoon (13:00-15:00)")):
    summ([e for e in EV if a <= HM(e["t"]) < b_], nm)
PS = {}
for e in EV:
    if e["fol"]:
        PS.setdefault(e["s"], []).append(e["t05"])
fast = sorted(((med(v), s, len(v)) for s, v in PS.items()), key=lambda x: x[0])
if fast:
    print("  the shares that react FASTEST (median min to +0.5% after the money): " + " · ".join("%s %.0f" % (s, m) for m, s, n in fast[:10]))
    print("  ... and the SLOWEST: " + " · ".join("%s %.0f" % (s, m) for m, s, n in fast[-8:]))
print("  READ: if the price usually follows in N minutes, GIR's 3-s watch has those N minutes to tell you before the share moves.")

# ---------------- 3c · WHAT MAKES A SHARE MOVE (Rama, 14 Nov: "almost all the shares will have a principle to move up and down - we need to find out") ----------------
def what_moves():
    """every START: an F&O share's price 0.5%+ in 3 min (once a share-side in 30 min, 09:18-15:00). At that minute:
    MONEY  NEW futures money its way (OI +0.5% in 3 min) · FORCED  money only forced out (OI -0.5%: covering / unwinding)
    SECTOR half its peers or more 0.2%+ its way · MARKET 55%+ of all F&O shares its way
    VOLUME the last 3 min traded 2x+ the share's NORMAL for that time of day (the 8 days before) - the big hands
    VWAP   the price on its side of the day's average price (above for a rise, below for a fall) - where institutions buy / sell
    NIFTY  NIFTY futures 0.1%+ its way in the same 3 min - the index tide
    Then 30 min: REAL = 1% further its way before 0.5% back · FAILED = 0.5% back first."""
    sec = WW.sectors_of(); of = {}
    for kk, v in sec.items():
        for x in v:
            of.setdefault(x, kk)
    T_ = sorted({t for v in MIN.values() for t in v[0]})
    NI = IDX.get("NIFTY")
    EV, last = [], {}
    for t in T_:
        hm = HM(t)
        if hm < "09:18" or hm > "15:00":
            continue
        r = {}
        for s, (ts, C, OI) in MIN.items():
            i = np.searchsorted(ts, t, side="right") - 1
            if i >= 3 and ts[i] >= t - 90 and C[i - 3]:
                r[s] = (i, float((C[i] / C[i - 3] - 1) * 100), float((OI[i] / OI[i - 3] - 1) * 100) if OI[i] and OI[i - 3] else None)
        mu = sum(1 for v in r.values() if v[1] > 0.1); md = sum(1 for v in r.values() if v[1] < -0.1); mn = len(r)
        n3 = None
        if NI is not None:
            ni = np.searchsorted(NI[0], t, side="right") - 1
            if ni >= 3 and NI[1][ni - 3]:
                n3 = float((NI[1][ni] / NI[1][ni - 3] - 1) * 100)
        for s, (i, px3, oi3) in r.items():
            d = 1 if px3 >= 0.5 else -1 if px3 <= -0.5 else 0
            if not d or t - last.get((s, d), -1e9) < 1800:
                continue
            last[(s, d)] = t
            ts, C, OI = MIN[s]
            vv, nb, vw = VOLD.get(s, (None, None, None))
            rv = None
            if vv is not None and i >= 2:
                b_ = nb[i - 2:i + 1]
                if np.isfinite(b_).all() and b_.sum() > 0:
                    rv = float(vv[i - 2:i + 1].sum() / b_.sum())
            peers = [r[p][1] for p in (sec.get(of.get(s)) or []) if p != s and p in r]
            p0 = float(C[i]); res, tm = "nothing", None
            for j in range(i + 1, min(len(C), i + 31)):
                mv = (float(C[j]) / p0 - 1) * 100 * d
                if mv >= 1.0:
                    res, tm = "real", (ts[j] - ts[i]) / 60; break
                if mv <= -0.5:
                    res = "failed"; break
            EV.append({"s": s, "d": d, "res": res, "tm": tm, "rv": rv,
                       "money": oi3 is not None and oi3 >= 0.5, "forced": oi3 is not None and oi3 <= -0.5,
                       "sect": bool(peers) and sum(1 for x in peers if x * d > 0.2) * 2 >= len(peers),
                       "mkt": (mu if d > 0 else md) >= 0.55 * mn,
                       "vol": rv is not None and rv >= 2.0,
                       "vwap": vw is not None and (float(C[i]) - float(vw[i])) * d > 0,
                       "nifty": n3 is not None and n3 * d >= 0.1})
    return EV
WM = what_moves()
print("\n=== 3b · WHAT MAKES A SHARE MOVE - every start (price 0.5%%+ in 3 min) on %s: %d · which forces were there, and how often it became a REAL move" % (day, len(WM)))
print("  REAL = 1% further its way within 30 min before 0.5% back · FAILED = 0.5% back first · VOLUME = 2x+ its normal for that minute (8 days before)")
def row(L, name):
    if not L:
        print("  %-52s none" % name); return
    r = [e for e in L if e["res"] == "real"]; f = [e for e in L if e["res"] == "failed"]
    tm = [e["tm"] for e in r]
    def side(d):
        S_ = [e for e in L if e["d"] == d]
        if not S_:
            return "%s -" % ("▲ rise (CE)" if d > 0 else "▼ fall (PE)")
        return "%s %d: REAL %d%% FAILED %d%%" % ("▲ rise (CE)" if d > 0 else "▼ fall (PE)", len(S_), round(100 * sum(1 for e in S_ if e["res"] == "real") / len(S_)),
                                                round(100 * sum(1 for e in S_ if e["res"] == "failed") / len(S_)))
    print("  %-52s %4d starts · REAL %3d%% · FAILED %3d%%%s" % (name, len(L), round(100 * len(r) / len(L)), round(100 * len(f) / len(L)),
          (" · the real ones got +1%% in a median %.0f min" % med(tm)) if tm else ""))
    print("  %-52s %s · %s" % ("", side(1), side(-1)))
F = lambda *ks: [e for e in WM if all(e[k] for k in ks)]
row(WM, "the price alone (every start)")
row([e for e in WM if not e["money"] and not e["forced"]], "price, but the futures money NOT moving")
row([e for e in WM if e["forced"]], "price + money only forced OUT (covering / unwinding)")
row(F("money"), "price + NEW futures money")
row(F("sect"), "price + its SECTOR")
row(F("vol"), "price + VOLUME surge (the big hands)")
row(F("vwap"), "price + on its side of VWAP")
row(F("nifty"), "price + NIFTY with it")
row(F("money", "sect"), "THE 3: price + NEW money + SECTOR")
row(F("money", "sect", "vol"), "THE 3 + VOLUME")
row(F("money", "vol"), "price + NEW money + VOLUME")
row([e for e in WM if e["vol"] and not e["money"]], "price + VOLUME, NO new futures money (cash buying)")
row(F("money", "sect", "vol", "vwap"), "THE 3 + VOLUME + VWAP")
row(F("money", "sect", "vol", "vwap", "nifty"), "ALL: THE 3 + VOLUME + VWAP + NIFTY")
row(F("money", "sect", "mkt"), "THE 3 + the whole MARKET")
# the best combinations, found from the data (each side on its own, 12+ starts)
import itertools
KS = ("money", "sect", "vol", "vwap", "nifty", "mkt")
NM = {"money": "new money", "sect": "sector", "vol": "volume", "vwap": "VWAP", "nifty": "NIFTY", "mkt": "market"}
for d, lab in ((1, "▲ RISE (CE)"), (-1, "▼ FALL (PE)")):
    S_ = [e for e in WM if e["d"] == d]
    base = (sum(1 for e in S_ if e["res"] == "real") / len(S_)) if S_ else 0
    best = []
    for n_ in range(1, 5):
        for combo in itertools.combinations(KS, n_):
            L_ = [e for e in S_ if all(e[k] for k in combo)]
            if len(L_) < 12:
                continue
            re_ = sum(1 for e in L_ if e["res"] == "real") / len(L_); fa = sum(1 for e in L_ if e["res"] == "failed") / len(L_)
            best.append((re_ - fa, re_, fa, len(L_), combo))
    best.sort(key=lambda x: -x[0])
    print("  THE BEST TOGETHER for a %s (price alone: REAL %d%% of %d starts):" % (lab, round(100 * base), len(S_)))
    for sc, re_, fa, n_, combo in best[:6]:
        print("     price + %-40s %4d starts · REAL %3d%% · FAILED %3d%%" % (" + ".join(NM[k] for k in combo), n_, round(100 * re_), round(100 * fa)))
print("  READ: F&O works both ways - the combination with the highest REAL and the lowest FAILED, for the rise (CE) and for the fall (PE), is the principle.")
def edge(L):
    """FOLLOW the start: +1% at REAL, -0.5% at FAILED · the OPPOSITE: +0.5% at FAILED, -1% at REAL (else ~0) -> average per trade, on the share"""
    if not L:
        return "-"
    r = sum(1 for e in L if e["res"] == "real") / len(L); f = sum(1 for e in L if e["res"] == "failed") / len(L)
    return "follow %+.2f%% · opposite %+.2f%% a trade" % (r * 1.0 - f * 0.5, f * 0.5 - r * 1.0)
print("  THE OPPOSITE TRADE (Rama: 'most of the time it turns opposite'): follow = target 1% / stop 0.5% · opposite = target 0.5% / stop 1%")
for nm, L in (("every start", WM), ("▲ every rise start", [e for e in WM if e["d"] > 0]), ("▼ every fall start", [e for e in WM if e["d"] < 0]),
              ("▼ fall start, the market RISING (55%+ up)", [e for e in WM if e["d"] < 0 and not e["mkt"]]), ("▲ rise start + sector + market", [e for e in WM if e["d"] > 0 and e["sect"] and e["mkt"]]),
              ("▼ fall start + NEW money", [e for e in WM if e["d"] < 0 and e["money"]])):
    print("     %-44s %4d · %s" % (nm, len(L), edge(L)))

# ---------------- 3c · HIDDEN ORDERS: heavy volume, price stuck (Rama, 14 Nov: "we have to find a way to find the news and hidden orders") ----------------
def hidden():
    """a big hidden buyer / seller soaks up the other side at one level: the last 3 min traded 3x+ the normal but the price moved under 0.2%.
    Then 30 min: did it break out 1%+ (which way first)? Against the same shares at ANY moment (every 15 min) as the yardstick."""
    H, B = [], []
    for s, (ts, C, OI) in MIN.items():
        vv, nb, vw = VOLD.get(s, (None, None, None))
        if vv is None:
            continue
        last = -1e9
        for i in range(3, len(C) - 1):
            hm = HM(ts[i])
            if hm < "09:20" or hm > "15:00":
                continue
            def out(i0):
                p0 = float(C[i0])
                for j in range(i0 + 1, min(len(C), i0 + 31)):
                    mv = (float(C[j]) / p0 - 1) * 100
                    if abs(mv) >= 1.0:
                        return 1 if mv > 0 else -1
                return 0
            if i % 15 == 0:
                B.append(out(i))
            b_ = nb[i - 2:i + 1]
            if not np.isfinite(b_).all() or b_.sum() <= 0 or ts[i] - last < 1800:
                continue
            rv = float(vv[i - 2:i + 1].sum() / b_.sum()); px3 = float((C[i] / C[i - 3] - 1) * 100)
            if rv >= 3.0 and abs(px3) < 0.2:
                last = ts[i]
                oi3 = float((OI[i] / OI[i - 3] - 1) * 100) if OI[i] and OI[i - 3] else 0.0
                H.append({"s": s, "t": ts[i], "o": out(i), "rv": rv, "oi3": oi3, "side": 1 if float(C[i]) >= float(vw[i]) else -1})
    return H, B
HD, BS = hidden()
print("\n=== 3c · HIDDEN ORDERS? - the last 3 min traded 3x+ the normal, but the price stuck (moved under 0.2%%): %d times on %s" % (len(HD), day))
def brk(L):
    if not L:
        return "none"
    u = sum(1 for x in L if (x["o"] if isinstance(x, dict) else x) > 0); d_ = sum(1 for x in L if (x["o"] if isinstance(x, dict) else x) < 0)
    return "%d · broke out 1%%+ within 30 min: %d%% (up %d · down %d)" % (len(L), round(100 * (u + d_) / len(L)), u, d_)
print("  heavy volume, price stuck          " + brk(HD))
print("  any moment (the yardstick)         " + brk(BS))
print("  ... price ABOVE VWAP when stuck    " + brk([x for x in HD if x["side"] > 0]))
print("  ... price BELOW VWAP when stuck    " + brk([x for x in HD if x["side"] < 0]))
print("  ... futures OI rising (+0.3%+)      " + brk([x for x in HD if x["oi3"] >= 0.3]))
print("  ... futures OI falling (-0.3%)      " + brk([x for x in HD if x["oi3"] <= -0.3]))
if HD:
    print("  where: " + " · ".join("%s %s%s" % (HM(x["t"]), x["s"], {1: "↑", -1: "↓", 0: "·"}[x["o"]]) for x in sorted(HD, key=lambda x: x["t"])[:25]))
print("  READ: if 'heavy volume, price stuck' breaks out far more often than 'any moment', GIR can watch for it live (the engine has the volume every second).")

# ---------------- 3d · BACKWARDS: WHAT WAS THERE BEFORE THE REAL MOVES (Rama, 14 Nov: "work the other way around - when a stock moved up, on what
# conditions, and when it moved down, on what conditions - did you include the news and the hidden buyers") ----------------
def news_times():
    """every share's news (news.db items: t_pub) and exchange filings (filings.db: t_exch, not routine) of the day -> {sym: [epoch]}"""
    out, src = {}, []
    lo, hi = d0 - 3 * 3600, d0 + 7 * 3600
    for dbf, q in (("news.db", "select sym, t_pub from items where t_pub between ? and ?"),
                   ("filings.db", "select sym, t_exch from filings where t_exch between ? and ? and kind not in ('ROUTINE','MEETING','OTHER')")):
        try:
            c = ro(dbf); n_ = 0
            for sym, t in c.execute(q, (lo, hi)):
                if sym and t:
                    out.setdefault(sym, []).append(float(t)); n_ += 1
            c.close(); src.append("%s %d" % (dbf, n_))
        except Exception as ex:
            src.append("%s: %s" % (dbf, str(ex)[:40]))
    return out, " · ".join(src)
NEWS, NSRC = news_times()
def backwards():
    """the REAL moves from Zerodha's minutes: 1.5%+ within 45 min from where it began (once a share-side an hour, 09:15-14:45). For each, what
    was there in the 15 min BEFORE it began and in its first 5 min - against the same shares at ordinary moments (every 15 min)."""
    sec = WW.sectors_of(); of = {}
    for kk, v in sec.items():
        for x in v:
            of.setdefault(x, kk)
    NI = IDX.get("NIFTY")
    def chg(arr, i0, i1):
        ts, C = arr[0], arr[1]
        return float((C[i1] / C[i0] - 1) * 100) if 0 <= i0 < len(C) and 0 <= i1 < len(C) and C[i0] else None
    def at(ts, t):
        return int(np.searchsorted(ts, t, side="right") - 1)
    def facts(s, i, d):
        ts, C, OI = MIN[s]; t = ts[i]
        vv, nb, vw = VOLD.get(s, (None, None, None))
        f = {}
        oib = float((OI[i] / OI[max(0, i - 15)] - 1) * 100) if OI[i] and OI[max(0, i - 15)] else None
        oiw = float((OI[min(len(C) - 1, i + 5)] / OI[i] - 1) * 100) if OI[i] and OI[min(len(C) - 1, i + 5)] else None
        f["money BEFORE the price (OI +0.5% in the 15 min before)"] = oib is not None and oib >= 0.5
        f["NEW money in the first 5 min (OI +0.5%)"] = oiw is not None and oiw >= 0.5
        f["money forced out in the first 5 min (OI -0.5%)"] = oiw is not None and oiw <= -0.5
        p = [chg(MIN[x], at(MIN[x][0], t - 900), at(MIN[x][0], t)) for x in (sec.get(of.get(s)) or []) if x != s and x in MIN]
        p = [x for x in p if x is not None]
        f["its SECTOR already moving its way (15 min before)"] = bool(p) and sum(1 for x in p if x * d > 0.3) * 2 >= len(p)
        pw = [chg(MIN[x], at(MIN[x][0], t), at(MIN[x][0], t + 300)) for x in (sec.get(of.get(s)) or []) if x != s and x in MIN]
        pw = [x for x in pw if x is not None]
        f["its SECTOR moving with it (first 5 min)"] = bool(pw) and sum(1 for x in pw if x * d > 0.2) * 2 >= len(pw)
        if NI is not None:
            nb_ = chg(NI, at(NI[0], t - 900), at(NI[0], t)); nw = chg(NI, at(NI[0], t), at(NI[0], t + 300))
            f["NIFTY already moving its way (15 min before)"] = nb_ is not None and nb_ * d >= 0.15
            f["NIFTY moving with it (first 5 min)"] = nw is not None and nw * d >= 0.1
        if vv is not None:
            hid = False
            for j in range(max(3, i - 20), i + 1):
                b_ = nb[j - 2:j + 1]
                if np.isfinite(b_).all() and b_.sum() > 0 and vv[j - 2:j + 1].sum() / b_.sum() >= 3.0 and abs(float(C[j] / C[j - 3] - 1)) < 0.002:
                    hid = True; break
            f["HIDDEN order before (3x volume, price stuck, 20 min before)"] = hid
            j = min(len(C) - 1, i + 3); b_ = nb[j - 2:j + 1]
            f["VOLUME surge in the first 3 min (2x the normal)"] = bool(np.isfinite(b_).all() and b_.sum() > 0 and vv[j - 2:j + 1].sum() / b_.sum() >= 2.0)
            f["started on the WRONG side of VWAP (a turn back)"] = (float(C[i]) - float(vw[i])) * d < 0
        f["NEWS / a filing in the hour before"] = any(t - 3600 <= x <= t + 120 for x in NEWS.get(s, []))
        f["in the first 15 min of the day"] = HM(t) < "09:31"
        return f
    MV, RD = [], []
    for s, (ts, C, OI) in MIN.items():
        last = {1: -1e9, -1: -1e9}
        n = len(C)
        for i in range(15, n - 1):
            if HM(ts[i]) > "14:45":
                break
            if i % 15 == 0:
                RD.append(facts(s, i, 1 if (i // 15) % 2 else -1) | {"_d": 1 if (i // 15) % 2 else -1})
            w = C[i:min(n, i + 46)]
            for d in (1, -1):
                if ts[i] - last[d] < 3600:
                    continue
                mv = (float(np.max(w)) / float(C[i]) - 1) * 100 if d > 0 else (1 - float(np.min(w)) / float(C[i])) * 100
                if mv < 1.5:
                    continue
                if i >= 1 and ((C[i - 1] < C[i]) if d > 0 else (C[i - 1] > C[i])):
                    continue                                                  # not the low (high) it began from
                if (float(C[min(n - 1, i + 3)]) / float(C[i]) - 1) * 100 * d < 0.2:
                    continue                                                  # it has to begin NOW (within 3 min), not after a long flat stretch
                k_ = int(np.argmax(w) if d > 0 else np.argmin(w))
                if k_ < 3:
                    continue
                last[d] = ts[i]
                MV.append(facts(s, i, d) | {"_d": d, "_s": s, "_t": ts[i], "_mv": mv})
    return MV, RD
MVS, RND = backwards()
print("\n=== 3d · BACKWARDS - every REAL move on %s (1.5%%+ within 45 min): ▲ %d up · ▼ %d down · what was there BEFORE / at the start, vs ordinary moments" % (
    day, sum(1 for m in MVS if m["_d"] > 0), sum(1 for m in MVS if m["_d"] < 0)))
print("  news + filings read: %s" % NSRC)
keys = [k for k in (MVS[0] if MVS else {}) if not k.startswith("_")]
for d, lab in ((1, "▲ UP moves (CE)"), (-1, "▼ DOWN moves (PE)")):
    L = [m for m in MVS if m["_d"] == d]; R_ = [r for r in RND if r["_d"] == d]
    if not L or not R_:
        print("  %s: none" % lab); continue
    print("  %s - %d moves:                                         in the moves · ordinary moments · how much more often" % (lab, len(L)))
    rows = []
    for k_ in keys:
        a = sum(1 for m in L if m.get(k_)) / len(L); b = sum(1 for r in R_ if r.get(k_)) / len(R_)
        rows.append((a / b if b > 0 else (9.9 if a > 0 else 0), a, b, k_))
    for lift, a, b, k_ in sorted(rows, key=lambda x: -x[0]):
        print("     %-62s %4d%% · %4d%% · %s" % (k_, round(100 * a), round(100 * b), ("%.1fx" % lift) if b > 0 else ("new" if a > 0 else "-")))
print("  READ: the lines at the top (seen far more often before real moves than at ordinary moments) are the fingerprint of a real move.")

# ---------------- 3e · MOMENTUM - RAMA'S OWN WAY (14 Nov: "most of the money I made by momentum: the stock goes up 10%, then I invest, make money
# and exit; the same way 20% lower circuit - the only mistake I made is GRASIM") ----------------
def results_days():
    """the shares with results on the day or the evening before (chains.db results_cal) - the quarterly-results momentum"""
    out = set()
    try:
        c = ro("chains.db")
        prev = (D0 - dt.timedelta(days=1)).date()                            # today or the EVENING BEFORE (the last weekday) - not the whole week
        while prev.weekday() > 4:
            prev -= dt.timedelta(days=1)
        for sym, d_ in c.execute("select sym, d from results_cal where d in (?, ?)", (str(prev), day)):
            out.add(sym)
        c.close()
    except Exception:
        pass
    return out
RES = results_days()
def momentum():
    """every share that crossed +3/+5/+8% (or -3/-5/-8%) vs the day before's close: entry at that minute. Then: KEPT GOING = 2% more its way
    before 2% back · TURNED BACK = 2% back first · and held to 15:20. At the crossing: results? · futures OI for the day (new money its way) ·
    volume for the day vs its normal · above / below VWAP · its sector · NIFTY · the time."""
    sec = WW.sectors_of(); of = {}
    for kk, v in sec.items():
        for x in v:
            of.setdefault(x, kk)
    NI = IDX.get("NIFTY")
    EVM = []
    for s, (ts, C, OI) in MIN.items():
        pc = PCL.get(s)
        if not pc:
            continue
        vv, nb, vw = VOLD.get(s, (None, None, None))
        for L in (3.0, 5.0, 8.0):
            for d in (1, -1):
                ch = (C / pc - 1) * 100 * d
                idx = np.nonzero(ch >= L)[0]
                if not len(idx):
                    continue
                i = int(idx[0]); t = ts[i]
                if HM(t) > "15:00":
                    continue
                p0 = float(C[i]); res = "neither"; tmin = None
                for j in range(i + 1, len(C)):
                    mv = (float(C[j]) / p0 - 1) * 100 * d
                    if mv >= 2.0:
                        res, tmin = "kept going", (ts[j] - t) / 60; break
                    if mv <= -2.0:
                        res, tmin = "turned back", (ts[j] - t) / 60; break
                k_ = int(np.searchsorted(ts, ts[0] - 60 + (6 * 3600 + 5 * 60), side="right") - 1)          # ~15:20
                k_ = max(i, min(len(C) - 1, k_))
                hold = (float(C[k_]) / p0 - 1) * 100 * d
                best = (float(np.max(C[i:]) if d > 0 else np.min(C[i:])) / p0 - 1) * 100 * d
                doi = float((OI[i] / OI[0] - 1) * 100) if OI[0] and OI[i] else None
                vr = None
                if vv is not None:
                    b_ = nb[:i + 1]
                    if np.isfinite(b_).sum() > 10 and np.nansum(b_) > 0:
                        vr = float(vv[:i + 1].sum() / np.nansum(b_))
                peers = []
                for x in (sec.get(of.get(s)) or []):
                    if x != s and x in MIN and PCL.get(x):
                        jx = int(np.searchsorted(MIN[x][0], t, side="right") - 1)
                        if jx >= 0:
                            peers.append((float(MIN[x][1][jx]) / PCL[x] - 1) * 100)
                ni = None
                if NI is not None:
                    jn = int(np.searchsorted(NI[0], t, side="right") - 1)
                    if jn >= 0 and NI[1][0]:
                        ni = (float(NI[1][jn]) / float(NI[1][0]) - 1) * 100
                EVM.append({"s": s, "d": d, "L": L, "t": t, "res": res, "tmin": tmin, "hold": hold, "best": best,
                            "results": s in RES, "money": doi is not None and doi >= 3.0, "forced": doi is not None and doi <= -3.0, "doi": doi,
                            "vol": vr is not None and vr >= 2.0, "vr": vr, "vwap": vw is not None and (p0 - float(vw[i])) * d > 0,
                            "sect": bool(peers) and sum(1 for x in peers if x * d > 0.5) * 2 >= len(peers),
                            "nifty": ni is not None and ni * d > 0.2, "early": HM(t) < "10:00"})
    return EVM
MO = momentum()
print("\n=== 3e · MOMENTUM - Rama's own way: a share already UP / DOWN 3%%, 5%%, 8%% on the day - enter there: did it KEEP GOING (2%% more) or TURN BACK (2%%)? %s" % day)
print("  results that day / the evening before: %d shares (%s)" % (len(RES), " ".join(sorted(RES))[:120] or "-"))
def mrow(L, name):
    if not L:
        print("  %-46s none" % name); return
    kg = sum(1 for e in L if e["res"] == "kept going"); tb = sum(1 for e in L if e["res"] == "turned back")
    print("  %-46s %3d · KEPT GOING %3d%% · TURNED BACK %3d%% · held to 15:20: average %+.1f%% · best after entry: median %+.1f%%" % (
        name, len(L), round(100 * kg / len(L)), round(100 * tb / len(L)), sum(e["hold"] for e in L) / len(L), med([e["best"] for e in L])))
for d, lab in ((1, "▲ UP"), (-1, "▼ DOWN")):
    for L in (3.0, 5.0, 8.0):
        E = [e for e in MO if e["d"] == d and e["L"] == L]
        mrow(E, "%s %g%% - every share" % (lab, L))
        if L == 3.0 and E:
            mrow([e for e in E if e["results"]], "   ... with RESULTS")
            mrow([e for e in E if not e["results"]], "   ... no results")
            mrow([e for e in E if e["money"]], "   ... NEW futures money for the day (OI +3%)")
            mrow([e for e in E if e["forced"]], "   ... money forced out (OI -3%)")
            mrow([e for e in E if e["vol"]], "   ... VOLUME 2x its normal so far")
            mrow([e for e in E if e["vwap"]], "   ... on its side of VWAP")
            mrow([e for e in E if not e["vwap"]], "   ... on the WRONG side of VWAP")
            mrow([e for e in E if e["sect"]], "   ... its SECTOR with it")
            mrow([e for e in E if e["nifty"]], "   ... NIFTY with it")
            mrow([e for e in E if e["early"]], "   ... before 10:00")
            mrow([e for e in E if not e["early"]], "   ... after 10:00")
            mrow([e for e in E if e["money"] and e["vwap"]], "   ... NEW money + VWAP")
            mrow([e for e in E if e["results"] and e["money"]], "   ... RESULTS + NEW money")
print("  every share (at the highest level it reached):")
for e in sorted([e for e in MO if e["L"] == max(x["L"] for x in MO if x["s"] == e["s"] and x["d"] == e["d"])], key=lambda x: x["t"])[:40]:
    print("     %s %-11s %s%g%% %s · %-11s held %+.1f%% · OI %s · vol %s · %s VWAP%s%s" % (HM(e["t"]), e["s"], "▲" if e["d"] > 0 else "▼", e["L"], "R" if e["results"] else " ",
          e["res"], e["hold"], ("%+.0f%%" % e["doi"]) if e["doi"] is not None else "-", ("%.1fx" % e["vr"]) if e["vr"] else "-",
          "right side of" if e["vwap"] else "WRONG side of", " · sector ✓" if e["sect"] else "", "   ◀ GRASIM" if e["s"] == "GRASIM" else ""))
G = [e for e in MO if e["s"] == "GRASIM"]
if G:
    print("  GRASIM that day: " + " · ".join("%s %s%g%% %s (held %+.1f%%, OI %s, %s VWAP)" % (HM(e["t"]), "▲" if e["d"] > 0 else "▼", e["L"], e["res"], e["hold"],
          ("%+.0f%%" % e["doi"]) if e["doi"] is not None else "-", "right side of" if e["vwap"] else "wrong side of") for e in G))
print("  READ: the lines with the most KEPT GOING and the fewest TURNED BACK are when Rama's momentum entry works - and what was missing when it did not.")

# ---------------- 4 · the wind, minute by minute, with windwatch's own rules ----------------
SEC = WW.sectors_of(); OF = {}
for kk, v in SEC.items():
    for s in v:
        OF.setdefault(s, kk)
T = sorted({t for v in MIN.values() for t in v[0]})
def read_at(t):
    mv = {}
    for s, (ts, C, OI) in MIN.items():
        i = np.searchsorted(ts, t, side="right") - 1
        if i < 3 or ts[i] < t - 90:
            continue
        px3 = float((C[i] / C[i - 3] - 1) * 100)
        oi3 = float((OI[i] / OI[i - 3] - 1) * 100) if OI[i] and OI[i - 3] else None
        mv[s] = (px3, oi3, float(C[i]))
    out = {}
    for s, (px3, oi3, px) in mv.items():
        d = 1 if px3 >= WW.PX_MIN else -1 if px3 <= -WW.PX_MIN else 0
        if not d:
            continue
        kind = "PRICE ONLY"
        if oi3 is not None and oi3 >= WW.OI_MIN:
            kind = "LONG BUILD-UP" if d > 0 else "SHORT BUILD-UP"
        elif oi3 is not None and oi3 <= -WW.OI_MIN:
            kind = "SHORT COVERING" if d > 0 else "LONG UNWINDING"
        sec = OF.get(s)
        peers = [mv[p][0] for p in (SEC.get(sec) or []) if p != s and p in mv]
        up, dn = sum(1 for x in peers if x > 0.2), sum(1 for x in peers if x < -0.2)
        sec_ok = bool(peers) and (up if d > 0 else dn) * 2 >= len(peers)
        out[s] = {"dir": d, "kind": kind, "px3": round(px3, 2), "oi3": None if oi3 is None else round(oi3, 2), "px": px, "sec_ok": sec_ok,
                  "base": int(abs(px3) >= 0.6) + int(kind in ("LONG BUILD-UP", "SHORT BUILD-UP")) + int(sec_ok)}
    return out
class FW:
    pass
def run(mode, px_min):
    """mode strict: book = no (score = base) · loose: book = yes (score = base + 1) · px_min: the 🌪 rule's move in 3 min"""
    WW.BIG_PX = px_min
    said, cards = {}, []
    BK = WW.Book(day); W = FW(); W.h = {}
    for t in T:
        hm = HM(t)
        if hm < "09:16" or hm > "15:30":
            continue
        cur = read_at(t)
        for s, w in cur.items():
            w["score"] = w["base"] + (1 if mode == "loose" else 0)
        for s, (ts, C, OI) in MIN.items():
            i = np.searchsorted(ts, t, side="right") - 1
            if i >= 0:
                W.h[s] = [(float(ts[i]), float(C[i]))]
        for kind, p, px, words in BK.step(t, hm, W, cur):
            if kind == "EXIT":
                p["exit_ts"] = t
        for s, w in WW.big_movers(t, cur, said):
            if (s, w["dir"]) in BK.open:
                continue
            other = BK.open.pop((s, -w["dir"]), None)
            if other:
                other.update({"exit_t": hm, "exit_px": w["px"], "why": "a big mover the other way", "res": round((w["px"] - other["entry"]) * other["dir"] / other["entry"] * 100, 2)})
                BK.done.append(other)
            p = BK.add(s, w, t, hm); p["w"] = dict(w)
            cards.append(p)
    for p in list(BK.open.values()):
        BK.done.append(p)
    return cards[:200]

# ---------------- 5 · the writers for each card (the 6 strikes nearest the price, CE + PE) ----------------
WR = {}
def writers(s, t, px, d):
    key = (s, int(t // 60))
    if key in WR:
        return WR[key]
    L = OPT.get(s) or []
    if not L:
        WR[key] = None; return None
    ex = min(o[0] for o in L)
    row = sorted({o[1] for o in L if o[0] == ex}, key=lambda kk: abs(kk - px))[:2 * WW.NEAR]
    sums = {"CE": [0.0, 0.0], "PE": [0.0, 0.0]}
    for o in L:
        if o[0] != ex or o[1] not in row:
            continue
        try:
            R = k.historical_data(o[3], dt.datetime.fromtimestamp(t - 600, IST).replace(tzinfo=None), dt.datetime.fromtimestamp(t, IST).replace(tzinfo=None), "minute", oi=True)
        except Exception:
            R = []
        time.sleep(0.34)
        R = [r for r in R if r["date"].timestamp() + 60 <= t + 1]
        if len(R) >= 4:
            sums[o[2]][0] += R[-4].get("oi") or 0; sums[o[2]][1] += R[-1].get("oi") or 0
    if sums["CE"][0] < WW.OPT_MIN_OI or sums["PE"][0] < WW.OPT_MIN_OI:
        WR[key] = None; return None
    ce3 = (sums["CE"][1] / sums["CE"][0] - 1) * 100; pe3 = (sums["PE"][1] / sums["PE"][0] - 1) * 100
    WR[key] = (round(ce3, 1), round(pe3, 1), WW.opt_agree(d, ce3, pe3))
    return WR[key]

OLD = {}
for n_, (mode, pxm) in enumerate((("strict", 0.8), ("loose", 0.8), ("strict", 0.5), ("loose", 0.5))):
    full = n_ == 0
    cards = run(mode, pxm)
    print("\n=== %d · 🌪 %s%% in 3 min · order book counted as %s (%s)%s · %d cards%s" % (4 + n_, pxm, "NO" if mode == "strict" else "YES", "the rule now" if pxm == 0.8 else "an idea - not live",
          "" if mode == "strict" else " - the best case", len(cards), " - checking the writers for each (6 strikes × CE/PE, about %d s) ..." % (len(cards) * 12 * 0.35) if full else ""), flush=True)
    for p in cards:
        p["wr"] = writers(p["s"], p["ts"], p["entry"], p["dir"]) if full else None
    sent = [p for p in cards if not (p.get("wr") and p["wr"][2] is False)]
    held = [p for p in cards if p.get("wr") and p["wr"][2] is False]
    # against the 47 moves
    caught, mins, rows = 0, [], []
    for m in M:
        cs = [p for p in sent if p["s"] == m["s"] and p["dir"] == m["sd"] and m["t0"] - 600 <= p["ts"] <= m["t0"] + 3600]
        old = [a for a in AL.get(m["s"], []) if a[1] == m["sd"] and a[0] >= m["t0"] - 900]
        o1 = min((a[0] for a in old), default=None); r1 = min((a[0] for a in old if a[2]), default=None)
        if cs:
            caught += 1; mins.append((cs[0]["ts"] - m["t0"]) / 60)
        rows.append((m, cs[0] if cs else None, o1, r1))
    o1s = [(o1 - m["t0"]) / 60 for m, p, o1, r1 in rows if o1]; r1s = [(r1 - m["t0"]) / 60 for m, p, o1, r1 in rows if r1]
    print("  the %d real moves: 🌪 caught %d · median %s min from the move's start · within 3 min: %d   (old GIR that day: first alert median %s min · rang %d, median %s min)" % (
        len(M), caught, ("%+.0f" % med(mins)) if mins else "-", sum(1 for x in mins if x <= 3), ("%.0f" % med(o1s)) if o1s else "-", len(r1s), ("%.0f" % med(r1s)) if r1s else "-"))
    if full:
        for m, p, o1, r1 in rows:
            print("    %s %-11s %s %+.1f%%   🌪 %-14s old: alert %-8s ring %s" % (HM(m["t0"]), m["s"], "▲" if m["sd"] > 0 else "▼", m["hour"] * m["sd"],
                  ("%s (%+.0f min)" % (p["t"][:5], (p["ts"] - m["t0"]) / 60)) if p else "-", ("%+.0f min" % ((o1 - m["t0"]) / 60)) if o1 else "-", ("%+.0f min" % ((r1 - m["t0"]) / 60)) if r1 else "never"))
    res = [p["res"] for p in sent if p.get("res") is not None]
    print("  every card that would have gone to GIR Bigmovers: %d (held by the writers: %d) · won %d · lost %d · ½ booked first %d · average %+.2f%% on the share" % (
        len(sent), len(held), sum(1 for x in res if x > 0), sum(1 for x in res if x < 0), sum(1 for p in sent if p.get("half")), (sum(res) / len(res)) if res else 0))
    why = {}
    for p in sent:
        y_ = p.get("why") or ""
        w_ = "closed 15:10" if y_.startswith("15:10") else "the stop" if y_.startswith("the stop") else "money left" if "money is leaving" in y_ else \
             "big mover the other way" if "other way" in y_ else "open"
        why[w_] = why.get(w_, 0) + 1
    print("  how they ended: " + " · ".join("%s %d" % (kk, v) for kk, v in sorted(why.items(), key=lambda x: -x[1])))
    if full:
        print("  the cards:")
        for p in cards[:60]:
            wr = p.get("wr")
            print("    %s %-11s %s ₹%-9s %s%s → %s %s" % (p["t"][:5], p["s"], "CE" if p["dir"] > 0 else "PE", "{:,.2f}".format(p["entry"]),
                  ("writers %s (CE %+.1f%% PE %+.1f%%) " % ({True: "✓", False: "✗ HELD", None: "~"}[wr[2]], wr[0], wr[1])) if wr else "", "½ " if p.get("half") else "",
                  p.get("exit_t") or "close", ("%+.2f%% · %s" % (p["res"], (p.get("why") or "")[:50])) if p.get("res") is not None else ""))
print("\nREAD: minutes, not seconds - the live watcher reads every 3 s, so live it is up to a minute earlier than above. Changes nothing, sends nothing.")
