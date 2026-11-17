#!/usr/bin/env python3
"""pickstudy.py - READ ONLY. AT 10:00 THE SECTORS HAVE SETTLED - WHICH OF THEIR SHARES GO ON? (Rama, 17 Nov: "all I am trying is to get the sector
correct, and from that sector which share has the potential to go up. When we say they invested in IT, definitely they prefer some shares. Around
09:45 to 10:00 we know which sector settled. From there we need the list of shares which can outperform, and from the last sector the shares
which can lose - based on the market condition.")
Every day of Kite's 5-minute prices that sectorstudy.py keeps (data/secstudy), with the 2 years of daily prices, NSE's delivery file and NSDL's
foreign-fund record:
  THE POOL   at the check time the sectors are ranked (all NSE shares, by size). CE pool = the F&O shares of the 3 strongest sectors that are up
             on the day · PE pool = the F&O shares of the 3 weakest that are down. What the pool does to 12:00 and to 15:10 is the yardstick.
  WHICH SHARE   inside the pool, each mark is tested on its own - does a share WITH the mark do better than the pool?
             leading its sector · not moved yet · volume 2x its normal by then · on the right side of VWAP · past yesterday's high / low ·
             past its 20-day high / low · strong (or weak) against its sector for 20 days - the shares funds have been preferring ·
             delivery building (taken home 5 days against 20) · one of the 3 biggest of its sector · its move was the opening gap or made after
             the open · VWAP + yesterday's level + volume together
  WHICH SECTOR  the same pool by: the sector's rank (1st / 2nd / 3rd) · 70%+ of its shares the same way · foreign funds buying or selling that
             sector in the last published fortnight
  THE MARKET    the same pool when the whole market is up / flat / down at the check time
"move" = the share's own move in the trade's direction (PE: a fall counts as plus). "worked" = +1.5% its way before -1% against (on the share).
A mark is ✔ only if its edge over the pool is there in BOTH halves of the days. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 pickstudy.py [0945|1000|1030]   -> prints, saves data/pickstudy.txt"""
import os, re, sys, json, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def scan(path, T):
    """one share's 5-minute file -> {day: (open, price at T, VWAP to T, volume to T, price at 12:00, price at 15:10, worked up, worked down)}"""
    try:
        A = np.load(path)
    except Exception:
        return {}
    if A.ndim != 2 or A.shape[1] < 7 or not len(A):
        return {}
    out = {}
    for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
        mn = p[:, 1]; a = p[mn <= T - 5]; b = p[(mn > T - 5) & (mn <= 350)]
        if len(a) < 3 or len(b) < 30:
            continue
        v = a[:, 6]; vs = float(v.sum()); pT = float(a[-1, 5])
        vw = float((((a[:, 3] + a[:, 4] + a[:, 5]) / 3) * v).sum() / vs) if vs > 0 else pT
        m12 = b[b[:, 1] <= 160]; p12 = float(m12[-1, 5]) if len(m12) else float("nan")
        hi, lo = b[:, 3] / pT - 1, b[:, 4] / pT - 1

        def worked(fav, adv):                                      # +1.5% the trade's way before -1% against (the stop wins a bar that has both)
            f = np.flatnonzero(fav >= 0.015); s = np.flatnonzero(adv <= -0.01)
            return 1.0 if len(f) and (not len(s) or f[0] < s[0]) else 0.0
        out[int(p[0, 0])] = (float(p[0, 2]), pT, vw, vs, p12, float(b[-1, 5]), worked(hi, lo), worked(-lo, -hi))
    return out


def main():
    import seclive as SL, flowtest, fpisec
    arg = next((a for a in sys.argv[1:] if a.isdigit()), "1000"); T = int(arg[:2]) * 60 + int(arg[2:]) - 555
    hm = "%s:%s" % (arg[:2], arg[2:])
    say("📊 AT %s THE SECTORS HAVE SETTLED - WHICH OF THEIR SHARES GO ON? · Kite 5-minute prices, every day kept · the trade from %s to 12:00 and to 15:10" % (hm, hm))
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    I = {}
    for s in SEC:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if b and (W.get(s) or not W):
            d = scan(os.path.join(C, b[1]), T)
            if d:
                I[s] = d
    if len(I) < 100:
        say("  ❌ 5-minute files for only %d shares in data/secstudy - run sectorstudy.py once (it fetches and keeps them)" % len(I)); return
    try:
        RAW = flowtest.daily(SL.get_kite, list(I), 500)
    except Exception as ex:
        say("  ❌ daily prices: %s" % ex); return
    # daily marks per share: {day: (prev close, yesterday's high, low, 20-day high, low, 20-day return)}
    DY = {}; DV = {}
    for s, a in RAW.items():
        if s not in I or len(a) < 30:
            continue
        o = a[:, 0].astype(int); h, l, c, v = a[:, 2], a[:, 3], a[:, 4], a[:, 5]; d = {}
        for i in range(21, len(a)):
            d[int(o[i])] = (c[i - 1], h[i - 1], l[i - 1], h[i - 20:i].max(), l[i - 20:i].min(), c[i - 1] / c[i - 21] - 1)
        DY[s] = d; DV[s] = (o, v)
    # delivery building as of the evening before: taken home (volume x delivery %) 5 days against the 20 before
    BLD = {}
    try:
        c_ = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=20); dp = {}
        first = str(dt.date.fromordinal(min(min(v) for v in I.values()) - 50))
        for d_, s, p_ in c_.execute("select d, sym, dp from deliv where d>=?", (first,)):
            if s in DV and p_ is not None:
                dp.setdefault(s, {})[dt.date.fromisoformat(d_).toordinal()] = p_
        c_.close()
        for s, m_ in dp.items():
            o, v = DV[s]; q = np.array([v[i] * m_.get(int(o[i]), np.nan) / 100 for i in range(len(o))]); d = {}
            for i in range(26, len(o)):
                a5, a20 = q[i - 5:i], q[i - 25:i - 5]
                if np.isnan(a5).sum() <= 1 and np.isnan(a20).sum() <= 6 and np.nanmean(a20) > 0:
                    d[int(o[i])] = float(np.nanmean(a5) / np.nanmean(a20))
            BLD[s] = d
    except Exception as ex:
        say("  (delivery not read: %s)" % str(ex)[:70])
    # foreign funds: for a day, the sign of the sector's last PUBLISHED fortnight (out about 6 trading days after it ends -> 10 calendar days here)
    FP = []
    try:
        S = fpisec.load(); held = lambda s, k: next((S["auc"][a].get(s) for a in sorted(S["auc"], reverse=True) if a <= k and S["auc"][a].get(s)), None)
        for k in sorted(S["net"]):
            g = {}
            for ns, v in S["net"][k].items():
                h = held(ns, k)
                for gs in (fpisec.gir_groups(ns) or ()):
                    if h and v is not None:
                        g[gs] = 1 if v / h >= 0.001 else -1 if v / h <= -0.001 else 0
            FP.append((dt.date.fromisoformat(k).toordinal() + 10, g))
    except Exception:
        pass
    fpi = lambda day, sec: next((g.get(sec, 0) for d_, g in reversed(FP) if d_ <= day), 0)
    days = sorted({d for v in I.values() for d in v}); big = {}
    for sec in set(SEC.values()):
        big[sec] = set(sorted((s for s in I if SEC[s] == sec), key=lambda s: -(W.get(s) or 0))[:3])
    R = {1: [], -1: []}; nd = 0
    for d in days:
        mv = {s: I[s][d][1] / DY[s][d][0] - 1 for s in I if d in I[s] and s in DY and d in DY[s]}
        mv = {s: x for s, x in mv.items() if abs(x) < 0.2}
        if len(mv) < 200:
            continue
        G = {}
        for s, x in mv.items():
            G.setdefault(SEC[s], []).append((s, x, W.get(s) or 1.0))
        sc = {k: (sum(x * w for _, x, w in v) / sum(w for _, _, w in v), sum(1 for _, x, _ in v if x > 0) / len(v)) for k, v in G.items() if len(v) >= 5}
        if len(sc) < 10:
            continue
        nd += 1
        mk = sum(x * (W.get(s) or 1.0) for s, x in mv.items()) / sum(W.get(s) or 1.0 for s in mv)
        s20 = {k: float(np.mean([DY[s][d][5] for s, _, _ in G[k]])) for k in sc}
        order = sorted(sc, key=lambda k: -sc[k][0])
        for dr, pick in ((1, order[:3]), (-1, order[::-1][:3])):
            for rk, sec in enumerate(pick, 1):
                smv, br = sc[sec][0] * dr, (sc[sec][1] if dr > 0 else 1 - sc[sec][1])
                if smv <= 0:
                    continue
                for s, x, w in G[sec]:
                    if s not in FO or x * dr <= 0:
                        continue
                    o, pT, vw, vs, p12, pE, wu, wd = I[s][d]; pc_, yh, yl, h20, l20, r20 = DY[s][d]
                    prev = [I[s][q][3] for q in days[max(0, days.index(d) - 10):days.index(d)] if q in I[s]]
                    vr = vs / (sum(prev) / len(prev)) if len(prev) >= 5 and sum(prev) > 0 else None
                    gap = (o / pc_ - 1) / x if x else 0
                    R[dr].append({"d": d, "r12": (p12 / pT - 1) * dr, "re": (pE / pT - 1) * dr, "w": wu if dr > 0 else wd, "rk": rk, "br": br, "mk": mk * dr, "fpi": fpi(d, sec) * dr,
                                  "lead": x * dr >= smv + 0.005, "lag": x * dr <= 0.5 * smv, "vol2": vr is not None and vr >= 2, "vol_lo": vr is not None and vr < 1,
                                  "vwap": (pT - vw) * dr > 0, "yday": pT > yh if dr > 0 else pT < yl, "d20": pT > h20 if dr > 0 else pT < l20,
                                  "strong": (r20 - s20[sec]) * dr >= 0.03, "weak": (r20 - s20[sec]) * dr <= -0.03, "deliv": BLD.get(s, {}).get(d, 0) >= 1.3,
                                  "big": s in big[sec], "gap": gap >= 0.7, "made": gap <= 0.3, "three": (pT - vw) * dr > 0 and (pT > yh if dr > 0 else pT < yl) and vr is not None and vr >= 1.5})
    say("  %d days (%s to %s) · %d shares with 5-minute prices · %d CE cases, %d PE cases · sizes: %s" % (nd, dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), len(I), len(R[1]), len(R[-1]), wsrc))
    if nd < 30:
        say("  ❌ too few days to say anything"); return
    say("  how to read: 'to 12:00' and 'to 15:10' = the average move the trade's way from %s · 'worked' = +1.5%% before -1%% · 'edge' = to 15:10, against the pool" % hm)
    say("  ✔ = the edge is at least 0.10%, the same sign in both halves of the days, and there are 150+ cases · ✘ = not steady - do not lean on it")
    PASS = {1: [], -1: []}
    for dr, title in ((1, "CE - the F&O shares of the 3 STRONGEST sectors at %s that are up on the day" % hm), (-1, "PE - the F&O shares of the 3 WEAKEST sectors at %s that are down on the day" % hm)):
        X = R[dr]; mid = days[len(days) // 2]; av = lambda v: sum(v) / len(v) if v else float("nan")
        base = av([r["re"] for r in X]); b1, b2 = av([r["re"] for r in X if r["d"] < mid]), av([r["re"] for r in X if r["d"] >= mid])

        def line(name, f, key=None):
            Y = [r for r in X if f(r)]
            if len(Y) < 40:
                say("    %-44s %5d cases - too few" % (name, len(Y))); return
            e = av([r["re"] for r in Y]) - base; e1 = av([r["re"] for r in Y if r["d"] < mid]) - b1; e2 = av([r["re"] for r in Y if r["d"] >= mid]) - b2
            ok = len(Y) >= 150 and e1 * e2 > 0 and abs(e) >= 0.001 and min(abs(e1), abs(e2)) >= 0.0005
            say("    %-44s %5d cases │ to 12:00 %s │ to 15:10 %s up %2d%% │ worked %2d%% │ edge %s (halves %s / %s) %s" % (name, len(Y), pc(av([r["r12"] for r in Y if r["r12"] == r["r12"]])), pc(av([r["re"] for r in Y])),
                100 * sum(1 for r in Y if r["re"] > 0) / len(Y), 100 * av([r["w"] for r in Y]), pc(e), pc(e1), pc(e2), ("✔" if e > 0 else "✔ WORSE - avoid") if ok else "✘"))
            if ok and key:
                PASS[dr].append((e, name.strip()))
        say(""); say(title)
        say("    %-44s %5d cases │ to 12:00 %s │ to 15:10 %s up %2d%% │ worked %2d%% │ (the pool - the yardstick)" % ("every share of the pool", len(X), pc(av([r["r12"] for r in X if r["r12"] == r["r12"]])), pc(base),
            100 * sum(1 for r in X if r["re"] > 0) / max(1, len(X)), 100 * av([r["w"] for r in X])))
        say("  WHICH SHARE")
        for name, k in (("leading its sector (0.5%+ ahead of it)", "lead"), ("not moved yet (under half the sector's move)", "lag"), ("volume 2x its normal by %s" % hm, "vol2"), ("volume under its normal", "vol_lo"),
                        ("on the right side of VWAP", "vwap"), ("past yesterday's %s" % ("high" if dr > 0 else "low"), "yday"), ("past its 20-day %s" % ("high" if dr > 0 else "low"), "d20"),
                        ("%s against its sector for 20 days (3%%+)" % ("STRONG" if dr > 0 else "WEAK"), "strong"), ("%s against its sector for 20 days" % ("weak" if dr > 0 else "strong"), "weak"),
                        ("delivery building (1.3x) to yesterday", "deliv"), ("one of the 3 biggest of its sector", "big"), ("its move was the opening gap (70%+)", "gap"),
                        ("its move was made after the open", "made"), ("VWAP + yesterday's level + volume 1.5x", "three")):
            line(name, lambda r, k=k: r[k], k)
        say("  WHICH SECTOR")
        for rk in (1, 2, 3):
            line("the %s sector" % (("strongest", "2nd strongest", "3rd strongest") if dr > 0 else ("weakest", "2nd weakest", "3rd weakest"))[rk - 1], lambda r, rk=rk: r["rk"] == rk, "rk")
        line("70%+ of the sector's shares that way", lambda r: r["br"] >= 0.7, "br")
        line("under 70% of its shares that way", lambda r: r["br"] < 0.7)
        line("foreign funds %s that sector (last report)" % ("BUYING" if dr > 0 else "SELLING"), lambda r: r["fpi"] > 0, "fpi")
        line("foreign funds %s that sector (last report)" % ("selling" if dr > 0 else "buying"), lambda r: r["fpi"] < 0, "fpi-")
        say("  THE MARKET at %s (all NSE shares, by size)" % hm)
        line("the market going the trade's way (0.3%+)", lambda r: r["mk"] >= 0.003, "mk")
        line("the market flat", lambda r: abs(r["mk"]) < 0.003)
        line("the market going AGAINST the trade (0.3%+)", lambda r: r["mk"] <= -0.003, "mk-")
    say("")
    say("WHAT PASSED (✔ in both halves) - the only marks worth putting on a %s list:" % hm)
    for dr, nm in ((1, "CE"), (-1, "PE")):
        say("  %s: %s" % (nm, " · ".join("%s (%s)" % (n_, pc(e)) for e, n_ in sorted(PASS[dr], reverse=True)) or "nothing passed"))
    say("  (charges and the option's own cost are not in these numbers: an edge under about 0.3% on the share is too thin to trade by itself)")
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "pickstudy.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/pickstudy.txt")


if __name__ == "__main__":
    main()
