#!/usr/bin/env python3
"""longtest.py - READ ONLY (changes nothing, sends nothing, fetches nothing). THE 3-YEAR BACKTEST from the store histstore.py made
(Rama, 15 Nov: "why can't we test all we did for at least 2 years - find a way to do it faster" · "ok then make 3 years of test").

Every study we ran on 30 days, now over every day in the store (3 years), all from the disk, every CPU at once - minutes, not days:
  ORB    the opening 5-min break (09:20-10:00)            IB15   the break of the first 15 min (09:30-11:00)
  MOM3   already +3% / -3% on the day (Rama's momentum)   FADE3  betting that 3% move turns back
  RUN2   the second run (1.5% push, 0.5% back holding VWAP, a new high / low)
  STEADY a steady move: 0.75 / 1 / 1.5% from the open, past yesterday's close, its side of VWAP 15 min (the price; see FUTURES below)
  BURST  1% in 3 min                                       DAY2   yesterday's 5% movers, entered 09:20 the same way (and FADE2 the other)
  PUSHD  THE PUSH FOR ITS SIZE, day by day (patch 290): yesterday's new futures money (NSE) as ₹ crore · OI % · x a normal day's trading
Each trade: entry at the signal minute's close, every exit (stop 2/target 2 · stop 1/trail 0.75 · stop 1.5/trail 1 · half at +1, trail 0.75 ·
no stop out 1% / 0.75% / 0.5% off the best · hold), out by 15:15, after 0.20% costs. Split by NIFTY at 09:30, NIFTY / the sector with it
at entry, in play, the time, yesterday's futures build-up, and by HALF-YEAR - a setup is only trusted if it made money in (nearly) every half-year.
FUTURES: the futures OI minute by minute is not kept for expired contracts (Zerodha), so for 3 years the futures money is NSE's daily file:
yesterday's build-up (the steady move's "+2% short build-up since the open" itself cannot be tested over 3 years - only on recent weeks).
The shares: today's F&O list (and only the days NSE listed them in F&O, when the NSE file is there).
  python3 longtest.py                 every study, every day in the store  -> the report (also saved in /root/hist/longtest_DATE.txt)
  python3 longtest.py 2025-01-01 2026-06-30   only those dates"""
import os, sys, json, time, datetime as dt
import numpy as np
STORE = os.environ.get("GIR_HIST", "/root/hist")
MIN_DIR = os.path.join(STORE, "min")
COST = 0.20
NM = 375                         # minutes 09:15 .. 15:29
KEND = 359                       # the 15:14 candle closes at 15:15 - out by 15:15
CK = [15, 30, 45, 75, 105, 165, 225]          # 09:30 09:45 10:00 10:30 11:00 12:00 13:00 - the sector's readings
EXN = ["t stop2/target2", "a stop1/trail0.75", "b stop1.5/trail1", "h half+1/trail0.75", "n no stop, out 1% off the best", "x hold to 15:15",
       "p no stop, out 0.5% off the best", "q no stop, out 0.75% off the best"]
STUDY = ["ORB opening 5-min break", "IB15 first-15-min break", "MOM3 already 3% on the day", "FADE3 betting a 3% move turns back", "RUN2 second run",
         "STEADY 0.75% from the open", "STEADY 1% from the open", "STEADY 1.5% from the open", "BURST 1% in 3 min", "DAY2 yesterday's 5% mover, same way",
         "FADE2 yesterday's 5% mover, the other way"]
T_N930U, T_N930D, T_N930M, T_NWITH, T_NAG, T_SWITH, T_SOLO, T_INPLAY, T_YBUILD, T_YKNOWN = 1, 2, 4, 8, 16, 32, 64, 128, 256, 512
FROM = TO = None
NIF, SECT, OF, FOD = {}, {}, {}, {}


def dday(n):
    return dt.date(1970, 1, 1) + dt.timedelta(days=int(n))


def grid(z):
    """minute file -> [(day number, O0, C[375], H[375], L[375], V[375], real minutes)] - gaps filled with the last price"""
    ts = np.asarray(z["ts"], np.int64); loc = ts + 19800
    dn = loc // 86400; m = (loc % 86400) // 60 - 555
    ok = (m >= 0) & (m < NM)
    ts, dn, m = ts[ok], dn[ok], m[ok]
    o, h, l, c, v = (np.asarray(z[k_], np.float64)[ok] for k_ in ("o", "h", "l", "c", "v"))
    out = []
    if not len(dn):
        return out
    cut = np.nonzero(np.diff(dn))[0] + 1
    for a, b in zip(np.r_[0, cut], np.r_[cut, len(dn)]):
        day = int(dn[a])
        if (FROM and dday(day) < FROM) or (TO and dday(day) > TO) or dday(day).weekday() > 4:
            continue
        C = np.full(NM, np.nan); H = np.full(NM, np.nan); L = np.full(NM, np.nan); V = np.zeros(NM)
        mm = m[a:b]
        C[mm] = c[a:b]; H[mm] = h[a:b]; L[mm] = l[a:b]; V[mm] = v[a:b]
        real = int(np.isfinite(C).sum())
        idx = np.where(np.isfinite(C), np.arange(NM), -1)
        np.maximum.accumulate(idx, out=idx)
        first = int(np.argmax(np.isfinite(C)))
        idx[idx < 0] = first
        miss = ~np.isfinite(H)
        C = C[idx]; H[miss] = C[miss]; L[miss] = C[miss]
        out.append((day, float(o[a]), C, H, L, V, real))
    return out


def exits8(H, L, C, i, d):
    """the 8 exits for an entry at C[i] (side d) -> % on the share, before costs (the same rules as fastreplay's play())"""
    p0 = C[i]
    sh = H[i + 1:KEND + 1]; sl = L[i + 1:KEND + 1]; sc = C[i + 1:KEND + 1]
    if d > 0:
        hi = (sh / p0 - 1) * 100; lo = (sl / p0 - 1) * 100
    else:
        hi = (1 - sl / p0) * 100; lo = (1 - sh / p0) * 100
    cl = (sc / p0 - 1) * 100 * d; end = cl[-1]
    bp = np.maximum(np.maximum.accumulate(np.r_[0.0, hi[:-1]]), 0.0)             # the best so far, before this minute

    after1 = np.arange(len(hi)) > 0                                               # the trail moves only after the first minute (as the loop)

    def trail(stop, tr, start):
        st = np.where((bp >= tr) | (start & after1), np.maximum(-stop, bp - tr), -stop)
        k_ = np.nonzero(lo <= st)[0]
        return float(st[k_[0]]) if len(k_) else float(end)
    s2 = np.nonzero(lo <= -2.0)[0]; g2 = np.nonzero(hi >= 2.0)[0]
    if len(s2) and (not len(g2) or s2[0] <= g2[0]):
        r_t = -2.0
    elif len(g2):
        r_t = 2.0
    else:
        r_t = float(end)
    bk = np.nonzero(hi >= 1.0)[0]                                                 # h: half booked at +1, then the stop to 0, trail 0.75
    b0 = bk[0] if len(bk) else len(hi)
    st_h = np.where(bp >= 0.75, np.maximum(-1.0, bp - 0.75), -1.0)
    st_h = np.where(np.arange(len(hi)) > b0, np.maximum(st_h, 0.0), st_h)
    k_ = np.nonzero(lo <= st_h)[0]
    if len(k_):
        r_h = float(st_h[k_[0]]) if k_[0] <= b0 else 0.5 + 0.5 * float(st_h[k_[0]])
    else:
        r_h = (0.5 + 0.5 * float(end)) if b0 < len(hi) else float(end)
    return (r_t, trail(1.0, 0.75, False), trail(1.5, 1.0, False), r_h, trail(99.0, 1.0, True), float(end), trail(99.0, 0.5, True), trail(99.0, 0.75, True))


def first(mask, a, b):
    k_ = np.nonzero(mask[a:b])[0]
    return a + int(k_[0]) if len(k_) else None


def nifty_days():
    z = np.load(os.path.join(MIN_DIR, "NIFTY.npz")); out = {}; pc = None
    for day, o0, C, H, L, V, real in grid(z):
        if real >= 300 and pc:
            c930 = C[14]; ch = (c930 / pc - 1) * 100
            k930 = "UP" if (ch >= 0.25 and c930 > o0) else "DOWN" if (ch <= -0.25 and c930 < o0) else "MIXED"
            dc = (C[-1] / pc - 1) * 100; rg = (H.max() - L.min()) / pc * 100
            out[day] = {"o": o0, "C": C, "k930": k930, "kind": 0 if dc >= 0.6 else 1 if dc <= -0.6 else 2 if rg >= 1.1 else 3}
        if real >= 300:
            pc = C[-1]
    return out


def pass1(s):
    """the share's change on the day at the sector's reading times -> {day: [7]}"""
    try:
        z = np.load(os.path.join(MIN_DIR, s + ".npz"))
    except Exception:
        return s, {}
    out, pc = {}, None
    for day, o0, C, H, L, V, real in grid(z):
        if real >= 200 and pc and abs(o0 / pc - 1) < 0.2:
            out[day] = (C[CK] / pc - 1) * 100
        if real >= 200:
            pc = C[-1]
    return s, out


def pass2(s):
    """every study's trades for one share -> (array of trades, list of PUSHD readings)"""
    try:
        z = np.load(os.path.join(MIN_DIR, s + ".npz"))
    except Exception:
        return s, np.zeros((0, 14), np.float32), []
    T, PD = [], []
    sec = OF.get(s); SD = SECT.get(sec) or {}; fo = FOD.get(s) or {}; fo_days = FOD.get("_days") or set()
    pc = ppc = None; f5h, volh = [], []; pday = None
    for day, o0, C, H, L, V, real in grid(z):
        dstr = str(dday(day)); n = NIF.get(day)
        good = real >= 200 and pc is not None and abs(o0 / pc - 1) < 0.2 and n is not None
        listed = (dstr in fo) if dstr in fo_days else True
        if good and listed:
            tp = (H + L + C) / 3; cv = np.cumsum(V)
            vw = np.where(cv > 0, np.cumsum(tp * V) / np.maximum(cv, 1e-9), tp)
            chg = (C / pc - 1) * 100; mvo = (C / o0 - 1) * 100
            nmv = (n["C"] / n["o"] - 1) * 100
            inplay = len(f5h) >= 3 and V[:5].sum() >= 2 * float(np.median(f5h[-8:]))
            prev = fo.get(pday) if pday else None                                 # NSE's figures for the share's previous market day
            ymv = (pc / ppc - 1) * 100 if ppc else 0.0
            own = (C[CK] / pc - 1) * 100

            def tags(m, d):
                t_ = {"UP": T_N930U, "DOWN": T_N930D}.get(n["k930"], T_N930M)
                t_ |= T_NWITH if nmv[m] * d > 0.05 else T_NAG if nmv[m] * d < -0.05 else 0
                ci = max((k_ for k_ in range(len(CK)) if CK[k_] <= m), default=None)
                if ci is not None and day in SD:
                    up_, dn_, nn = SD[day][ci]
                    up_ -= 1 if own[ci] > 0.3 else 0; dn_ -= 1 if own[ci] < -0.3 else 0; nn -= 1
                    w_, a_ = (up_, dn_) if d > 0 else (dn_, up_)
                    if nn > 0 and w_ * 2 >= nn:
                        t_ |= T_SWITH
                    elif nn > 0 and a_ >= 2 and a_ * 2 >= nn:
                        t_ |= T_SOLO
                if inplay:
                    t_ |= T_INPLAY
                if prev is not None:
                    t_ |= T_YKNOWN
                    if prev[1] > 0 and ymv * d > 0:
                        t_ |= T_YBUILD
                return t_

            def add(code, m, d):
                if m is None or m >= KEND - 1:
                    return
                T.append((code, d, day, m, tags(m, d), n["kind"]) + exits8(H, L, C, m, d))
            for d in (1, -1):
                hi5, lo5 = H[:5].max(), L[:5].min()
                add(0, first((C > hi5) if d > 0 else (C < lo5), 5, 45), d)
                hi15, lo15 = H[:15].max(), L[:15].min()
                add(1, first((C > hi15) if d > 0 else (C < lo15), 15, 105), d)
                mm = first(chg * d >= 3.0, 2, 315)
                add(2, mm, d); add(3, mm, -d)
                above = (C - vw) * d > 0; idx = np.arange(NM)
                run = idx - np.maximum.accumulate(np.where(~above, idx, -1))
                for code, lv in ((5, 0.75), (6, 1.0), (7, 1.5)):
                    add(code, first((mvo * d >= lv) & (chg * d > 0) & (run >= 16), 15, 315), d)
                p3 = np.r_[np.zeros(3), (C[3:] / C[:-3] - 1) * 100 * d]
                last = -99
                for m in np.nonzero(p3[5:315] >= 1.0)[0] + 5:
                    if m - last >= 30:
                        add(8, int(m), d); last = int(m)
                # the second run (fastreplay 3l): 1.5% from the open, back 0.5% staying its side of VWAP, then past the first push
                X = H if d > 0 else L
                mvx = (X / o0 - 1) * 100 * d
                f = first(mvx >= 1.5, 0, 315)
                if f is not None:
                    e = np.maximum.accumulate(np.where(np.arange(NM) >= f, mvx, -1e9))
                    ep = o0 * (1 + e * d / 100)
                    newhi = np.r_[False, e[1:] > e[:-1]]
                    pull = first((~newhi) & ((ep - C) / ep * 100 * d >= 0.5), f + 1, 315)
                    if pull is not None:
                        ext = ep[pull]
                        dead = first((C - vw) * d < 0, pull + 1, 315); hit = first((C - ext) * d > 0, pull + 1, 315)
                        if hit is not None and (dead is None or hit < dead):
                            add(4, hit, d)
                if ppc is not None and 5.0 <= ymv * d <= 20.0:
                    add(9, 5, d); add(10, 5, -d)
            # PUSHD: yesterday's new futures money (NSE) -> today, day level
            if prev is not None and prev[1] > 0 and 0.5 <= abs(ymv) <= 20 and len(volh) >= 10:              # over 20%: a bonus / split, not a move
                avg = float(np.mean(volh[-20:]))
                oi_before = prev[0] - prev[1]
                if avg > 0 and oi_before > 0:
                    d = 1 if ymv > 0 else -1
                    PD.append((day, d, prev[1] / avg, prev[1] / oi_before * 100, prev[1] * pc / 1e7, (C[KEND] / C[5] - 1) * 100 * d, (C[KEND] / pc - 1) * 100 * d))
        if real >= 200:
            ppc, pc = pc, C[-1]; f5h.append(V[:5].sum()); volh.append(V.sum()); pday = dstr
    return s, np.array(T, np.float32).reshape(-1, 14), PD


def half(day):
    d = dday(day)
    return "%d H%d" % (d.year, 1 if d.month <= 6 else 2)


def report(T, PD, days):
    out = []
    P = lambda *a: out.append(" ".join(str(x) for x in a))
    R = T[:, 6:14] - COST
    hv = np.array([half(x) for x in T[:, 2]]) if len(T) else np.array([])
    periods = sorted(set(hv.tolist()))
    P("=== THE %.1f-YEAR BACKTEST · %s -> %s · %d market days · %d trades · after %.2f%% costs · on the share (≈10x on an at-the-money premium)" % (
        len(days) / 248.0, dday(min(days)), dday(max(days)), len(days), len(T), COST))
    P("    half-years: " + " · ".join("%s %d trades" % (p_, int((hv == p_).sum())) for p_ in periods))
    m_ = T[:, 3] if len(T) else np.array([])
    tg = T[:, 4].astype(np.int64) if len(T) else np.array([], np.int64)
    FL = [("all", None), ("NIFTY 09:30 UP", lambda: tg & T_N930U > 0), ("NIFTY 09:30 DOWN", lambda: tg & T_N930D > 0), ("NIFTY 09:30 MIXED", lambda: tg & T_N930M > 0),
          ("NIFTY with it at entry", lambda: tg & T_NWITH > 0), ("NIFTY against it", lambda: tg & T_NAG > 0), ("its sector with it", lambda: tg & T_SWITH > 0),
          ("SOLO (its sector against)", lambda: tg & T_SOLO > 0), ("NIFTY AND its sector with it", lambda: (tg & T_NWITH > 0) & (tg & T_SWITH > 0)),
          ("in play (first 5 min 2x volume)", lambda: tg & T_INPLAY > 0), ("yesterday's futures build-up its way (NSE)", lambda: tg & T_YBUILD > 0),
          ("NIFTY + sector with it + in play", lambda: (tg & T_NWITH > 0) & (tg & T_SWITH > 0) & (tg & T_INPLAY > 0)),
          ("NIFTY + sector with it + yesterday's build-up", lambda: (tg & T_NWITH > 0) & (tg & T_SWITH > 0) & (tg & T_YBUILD > 0)),
          ("entered before 10:00", lambda: m_ < 45), ("entered 10:00-11:00", lambda: (m_ >= 45) & (m_ < 105)), ("entered 11:00-13:00", lambda: (m_ >= 105) & (m_ < 225)),
          ("entered after 13:00", lambda: m_ >= 225), ("(hindsight) a rising day", lambda: T[:, 5] == 0), ("(hindsight) a falling day", lambda: T[:, 5] == 1),
          ("(hindsight) a choppy day", lambda: T[:, 5] == 2)]
    rows, lifts = [], []
    for code, name in enumerate(STUDY):
        for d, side in ((1, "CE"), (-1, "PE")):
            base = (T[:, 0] == code) & (T[:, 1] == d)
            if base.sum() < 30:
                continue
            P("\n=== %s · %s · %d trades" % (name, side, int(base.sum())))
            j0 = None
            for lab, f in FL:
                mk = base & (f() if f else True)
                n = int(mk.sum())
                if n < 30:
                    continue
                av = R[mk].mean(axis=0); j = int(np.argmax(av)); w = 100 * (R[mk][:, j] > 0).mean()
                per = []
                for p_ in periods:
                    q = mk & (hv == p_)
                    per.append((p_, int(q.sum()), float(R[q][:, j].mean()) if q.sum() >= 15 else None))
                pos = sum(1 for _, _, a in per if a is not None and a > 0); cnt = sum(1 for _, _, a in per if a is not None)
                sig = " ".join(("+" if a > 0 else "-") if a is not None else "." for _, _, a in per)
                P("  %-44s %6d · best %+.2f%% (≈%+.0f%% premium) won %3.0f%% · %s · hold %+.2f%% · half-years %s (%d of %d +)" % (
                    lab, n, av[j], 10 * av[j], w, EXN[j].split(" ")[0], av[5], sig, pos, cnt))
                if not lab.startswith("(hindsight)"):
                    rows.append((name, side, lab, n, float(av[j]), w, EXN[j], float(av[5]), pos, cnt))
                if lab == "all":
                    j0, bw, ba = j, w, float(av[j])                                # the plain setup: its best exit, its success %
                elif j0 is not None and not lab.startswith("(hindsight)"):
                    w0 = 100 * (R[mk][:, j0] > 0).mean(); a0 = float(av[j0])       # the same exit, with this filter
                    pp = [float(R[mk & (hv == p_)][:, j0].mean()) for p_ in periods if (mk & (hv == p_)).sum() >= 15]
                    lifts.append((name, side, lab, n, w0, bw, a0, ba, sum(1 for x in pp if x > 0), len(pp), EXN[j0].split(" ")[0]))
    P("\n=== WHAT RAISES THE SUCCESS % - each setup alone vs with one filter (the same exit) · 200+ trades · + in (nearly) every half-year · biggest lift first")
    up = [x for x in lifts if x[3] >= 200 and x[4] - x[5] >= 3 and x[6] > x[7] and x[6] > 0 and x[9] >= 2 and x[8] >= x[9] - (1 if x[9] >= 4 else 0)]
    up.sort(key=lambda x: -(x[4] - x[5]))
    for x in up[:30]:
        P("  %-40s %s + %-44s won %3.0f%% (alone %3.0f%%, %+.0f points) · %+.2f%% a trade (alone %+.2f%%) · %6d trades · exit %s · half-years %d of %d +" % (
            x[0], x[1], x[2], x[4], x[5], x[4] - x[5], x[6], x[7], x[3], x[10], x[8], x[9]))
    if not up:
        P("  no filter lifted a setup's success % steadily")
    P("\n=== THE LONG-TEST PLAYBOOK - made money after costs in (nearly) every half-year · 200+ trades · best first")
    good = [r for r in rows if r[3] >= 200 and r[4] > 0 and r[9] >= 2 and r[8] >= r[9] - (1 if r[9] >= 4 else 0)]
    good.sort(key=lambda r: -r[4])
    for i, r in enumerate(good[:30]):
        P("  #%-2d %-44s %s · %-40s %6d trades · %+.2f%% (≈%+.0f%% premium) won %.0f%% · exit %s · half-years %d of %d +" % (i + 1, r[0], r[1], r[2], r[3], r[4], 10 * r[4], r[5], r[6], r[8], r[9]))
    if not good:
        P("  none passed every half-year")
    P("\n=== THE LOSERS - lost after costs in (nearly) every half-year · 200+ trades · worst first")
    bad = [r for r in rows if r[3] >= 200 and r[4] < 0 and r[9] >= 2 and r[8] <= (1 if r[9] >= 4 else 0)]
    bad.sort(key=lambda r: r[4])
    for r in bad[:20]:
        P("  %-44s %s · %-40s %6d trades · best exit still %+.2f%% · half-years + in %d of %d" % (r[0], r[1], r[2], r[3], r[4], r[8], r[9]))
    if PD:
        A = np.array(PD, np.float64)
        P("\n=== THE PUSH FOR ITS SIZE, day by day (patch 290) · %d share-days with new futures money yesterday (NSE) and the price 0.5%%+ its way" % len(A))
        P("  cut in fifths, smallest -> biggest: today 09:20 -> 15:15 its way (avg %) · and yesterday's close -> today's close its way (gap included)")
        for d, nm in ((1, "▲ yesterday a LONG build-up"), (-1, "▼ yesterday a SHORT build-up")):
            B = A[A[:, 1] == d]
            if len(B) < 100:
                continue
            P("  %s · %d" % (nm, len(B)))
            for k_, lab in ((4, "₹ crore"), (3, "OI %"), (2, "FOR ITS SIZE")):
                S_ = B[np.argsort(B[:, k_])]; nn = len(S_); cells, a1 = [], []
                for q in range(5):
                    part = S_[q * nn // 5:(q + 1) * nn // 5]
                    a1.append(part[:, 5].mean()); cells.append("%+.2f%% / %+.2f%%" % (part[:, 5].mean(), part[:, 6].mean()))
                P("     %-13s %s   biggest - smallest %+.2f%%" % (lab, " | ".join(cells), a1[-1] - a1[0]))
        P("  READ: the way whose 'biggest - smallest' is largest tells the next day best. If FOR ITS SIZE wins here AND on the 30-day minute test, it goes into the rules.")
    P("\nREAD: trust a setup only if it is + in (nearly) every half-year - one good stretch is luck. 'best' picks the best of 8 exits (a little flattering);")
    P("'hold' is the plain hold to 15:15 for comparison. Today's F&O list is used for every day (shares that left F&O are missing).")
    return "\n".join(out)


def main():
    global FROM, TO, NIF, SECT, OF, FOD
    a = sys.argv[1:]
    if len(a) >= 2:
        FROM, TO = dt.date.fromisoformat(a[0]), dt.date.fromisoformat(a[1])
    if not os.path.exists(os.path.join(MIN_DIR, "NIFTY.npz")):
        print("no store yet - run histstore.py get first"); return
    t0 = time.time()
    try:
        os.nice(10)
    except Exception:
        pass
    NIF = nifty_days()
    names = sorted(f[:-4] for f in os.listdir(MIN_DIR) if f.endswith(".npz") and f[:-4] not in ("NIFTY", "BANKNIFTY"))
    sec = {}
    try:
        sec = json.load(open(os.path.join(STORE, "sectors.json")))
    except Exception:
        pass
    OF = {x: k_ for k_, v in sec.items() for x in v}
    try:
        J = json.load(open(os.path.join(STORE, "fo_daily.json")))
        FOD = {s: v for s, v in J.get("d", {}).items()}
        FOD["_days"] = set(J.get("done", []))
    except Exception:
        FOD = {"_days": set()}
    import multiprocessing as mp
    nw = max(1, (os.cpu_count() or 2) - 1)
    print("=== %d shares · %d NIFTY days · %d workers · the NSE daily file: %d days" % (len(names), len(NIF), nw, len(FOD["_days"])), flush=True)
    with mp.get_context("fork").Pool(nw) as pool:
        P1 = dict(pool.map(pass1, names, chunksize=4))
    acc = {}
    for s, D in P1.items():
        g = OF.get(s)
        if not g:
            continue
        for day, v in D.items():
            a_ = acc.setdefault(g, {}).setdefault(day, np.zeros((len(CK), 3)))
            a_[:, 0] += v > 0.3; a_[:, 1] += v < -0.3; a_[:, 2] += 1
    SECT = acc
    print("  the sectors read · %.0f s" % (time.time() - t0), flush=True)
    Ts, PDs = [], []
    with mp.get_context("fork").Pool(nw) as pool:
        for i, (s, T, PD) in enumerate(pool.imap_unordered(pass2, names, chunksize=2)):
            Ts.append(np.c_[T, np.full(len(T), names.index(s), np.float32)]); PDs += [x + (names.index(s),) for x in PD]
            if i % 25 == 24:
                print("  %d of %d shares · %.0f s" % (i + 1, len(names), time.time() - t0), flush=True)
    T = np.concatenate(Ts) if Ts else np.zeros((0, 15), np.float32)            # columns: study, side, day, minute, tags, day kind, 8 exits, the share
    np.savez_compressed(os.path.join(STORE, "longtest_trades.npz"), T=T, PD=np.array(PDs, np.float32).reshape(-1, 8), names=np.array(names), studies=np.array(STUDY),
                        exits=np.array(EXN))
    rep = report(T, PDs, sorted(NIF))
    rep += "\n(%.1f min · the trades are kept in %s/longtest_trades.npz)" % ((time.time() - t0) / 60, STORE)
    print(rep)
    fn = os.path.join(STORE, "longtest_%s.txt" % dt.date.today())
    open(fn, "w").write(rep + "\n")
    print("saved: %s" % fn)


if __name__ == "__main__":
    main()
