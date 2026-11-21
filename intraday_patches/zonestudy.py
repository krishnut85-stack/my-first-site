#!/usr/bin/env python3
"""zonestudy.py - READ ONLY. THE ZONES AND THE SUDDEN BREAK (Rama, 17 Nov: "some stocks must be in the oversold zone and some in the overbought
zone - LICHSGFIN was extremely overbought ... Premier Energies was hovering around -4% till the afternoon, then within a second it fell to -8%.
If I had known it would fall I could have bought and made money").
  A) OVERBOUGHT / OVERSOLD   every F&O share, 2 years of Kite's daily prices. The zone = RSI(14) on the day's close (above 70 overbought, above
             80 extreme; under 30 oversold, under 20 extreme) and how far the price is from its 20-day average. Then from the NEXT morning's
             open: the share over 1 / 3 / 5 days. Does an overbought share come back, or keep going? Also: with delivery well above its normal
             (investors taking it home - real buying), and when its whole sector is in the same zone.
  B) THE SUDDEN BREAK   Kite 5-minute prices, every day kept. A share already down 2%+ (or up 2%+) that has been HOVERING - a range under 1.2%
             for 90 minutes - and then, after 12:00, closes a 5-minute bar beyond that range in the direction of its day. From that bar's close:
             the next 15 / 30 / 60 minutes and to 15:10. Against: every share down (up) 2%+ at 13:00, held to 15:10.
             The break is seen one bar late (a 5-minute close) - what is left AFTER it is what a trader can get.
"its way" = PE for a fall, CE for a rise: a plus is money for the trade. ✔ = the edge over the yardstick has the same sign in both halves of
the days and is at least 0.15%. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 zonestudy.py   -> prints, saves data/zonestudy.txt"""
import os, re, sys, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def rsi(c, n=14):
    """Wilder's RSI on closes -> an array (nan for the first n days)"""
    d = np.diff(c); out = np.full(len(c), np.nan)
    if len(d) < n + 1:
        return out
    up, dn = np.where(d > 0, d, 0.0), np.where(d < 0, -d, 0.0)
    au, ad = up[:n].mean(), dn[:n].mean()
    for i in range(n, len(d)):
        au = (au * (n - 1) + up[i]) / n; ad = (ad * (n - 1) + dn[i]) / n
        out[i + 1] = 100.0 if ad == 0 else 100 - 100 / (1 + au / ad)
    return out


def table(title, X, base, mid, keys, names, thr=0.0015, sign=1):
    """rows of events against the yardstick `base`: X = [(day, {key: value})]"""
    av = lambda v: sum(v) / len(v) if v else float("nan")
    if len(X) < 40:
        say("    %-46s %5d cases - too few" % (title, len(X))); return
    cells = " │ ".join("%s %s up %2d%%" % (nm, pc(av([r[k] for _, r in X if r[k] == r[k]])), 100 * av([1.0 if r[k] > 0 else 0.0 for _, r in X if r[k] == r[k]])) for k, nm in zip(keys, names))
    if X is base:
        say("    %-46s %5d cases │ %s │ (the yardstick)" % (title, len(X), cells)); return
    k = keys[-1]; e = lambda Y, Bs: av([r[k] for _, r in Y if r[k] == r[k]]) - av([r[k] for _, r in Bs if r[k] == r[k]])
    e0, e1, e2 = e(X, base), e([x for x in X if x[0] < mid], [x for x in base if x[0] < mid]), e([x for x in X if x[0] >= mid], [x for x in base if x[0] >= mid])
    ok = len(X) >= 100 and e1 * e2 > 0 and abs(e0) >= thr and min(abs(e1), abs(e2)) >= thr / 2
    say("    %-46s %5d cases │ %s │ edge %s (halves %s / %s) %s" % (title, len(X), cells, pc(e0), pc(e1), pc(e2), ("✔" if e0 * sign > 0 else "✔ the other way") if ok else "✘"))


def main():
    import seclive as SL, flowtest
    say("📊 THE ZONES AND THE SUDDEN BREAK · overbought / oversold on 2 years of daily prices · a hovering share that breaks, on 5-minute prices")
    SEC, _ = SL.universe(); FO = SL.fo_set()
    fo = sorted(s for s in FO if s in SEC)
    try:
        RAW = flowtest.daily(SL.get_kite, list(SEC), 500)
    except Exception as ex:
        say("  ❌ daily prices: %s" % ex); return
    DP = {}
    try:
        c_ = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=20)
        for d_, s, p_ in c_.execute("select d, sym, dp from deliv"):
            if s in FO and p_ is not None:
                DP.setdefault(s, {})[dt.date.fromisoformat(d_).toordinal()] = p_
        c_.close()
    except Exception:
        pass
    # the sector's own zone: the average RSI of its shares that day
    R = {}; SR = {}
    for s, a in RAW.items():
        if s in SEC and len(a) >= 60:
            r = rsi(a[:, 4]); R[s] = r
            for i in range(len(a)):
                if r[i] == r[i]:
                    SR.setdefault((SEC[s], int(a[i, 0])), []).append(r[i])
    SR = {k: sum(v) / len(v) for k, v in SR.items() if len(v) >= 4}
    ALL = []; EV = []
    for s in fo:
        a = RAW.get(s)
        if a is None or s not in R:
            continue
        o, c, r = a[:, 1], a[:, 4], R[s]; dd = a[:, 0].astype(int)
        for i in range(25, len(a) - 6):
            if r[i] != r[i] or not o[i + 1]:
                continue
            f = {"d1": c[i + 1] / o[i + 1] - 1, "d3": c[i + 3] / o[i + 1] - 1, "d5": c[i + 5] / o[i + 1] - 1}
            if max(abs(v) for v in f.values()) > 0.4:
                continue
            m20 = c[i - 19:i + 1].mean(); dps = [DP.get(s, {}).get(int(dd[j])) for j in range(i - 10, i + 1)]; dn = [x for x in dps[:-1] if x is not None]
            ALL.append((int(dd[i]), f))
            EV.append((int(dd[i]), f, r[i], c[i] / m20 - 1, (dps[-1] - sum(dn) / len(dn)) if dps[-1] is not None and len(dn) >= 5 else None, SR.get((SEC[s], int(dd[i]))), s))
    if len(ALL) < 5000:
        say("  ❌ too little daily data (%d share-days)" % len(ALL)); return
    days = sorted({d for d, _ in ALL}); mid = days[len(days) // 2]
    say("  A: %d F&O shares · %d days (%s to %s) · %d share-days" % (len(fo), len(days), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), len(ALL)))
    say("")
    say("A) OVERBOUGHT / OVERSOLD - the share from the NEXT morning's open (its own move, + = it went up)")
    K, N = ("d1", "d3", "d5"), ("1 day", "3 days", "5 days")
    table("every F&O share, every day (the yardstick)", ALL, ALL, mid, K, N)
    sel = lambda f: [(d, x) for d, x, r, dv, dl, sr, s in EV if f(r, dv, dl, sr)]
    say("  overbought - does it come back (a minus = PE pays) or keep going?")
    table("RSI above 70", sel(lambda r, dv, dl, sr: r >= 70), ALL, mid, K, N)
    table("RSI above 80 (extreme)", sel(lambda r, dv, dl, sr: r >= 80), ALL, mid, K, N)
    table("RSI above 75 and 8%+ over its 20-day average", sel(lambda r, dv, dl, sr: r >= 75 and dv >= 0.08), ALL, mid, K, N)
    table("RSI above 75, delivery 10 pts over its normal", sel(lambda r, dv, dl, sr: r >= 75 and dl is not None and dl >= 10), ALL, mid, K, N)
    table("RSI above 75, delivery under its normal", sel(lambda r, dv, dl, sr: r >= 75 and dl is not None and dl <= -5), ALL, mid, K, N)
    table("RSI above 75, its sector also above 65", sel(lambda r, dv, dl, sr: r >= 75 and sr is not None and sr >= 65), ALL, mid, K, N)
    table("RSI above 75, its sector NOT (under 55)", sel(lambda r, dv, dl, sr: r >= 75 and sr is not None and sr < 55), ALL, mid, K, N)
    say("  oversold - does it bounce (a plus = CE pays) or keep falling?")
    table("RSI under 30", sel(lambda r, dv, dl, sr: r <= 30), ALL, mid, K, N)
    table("RSI under 20 (extreme)", sel(lambda r, dv, dl, sr: r <= 20), ALL, mid, K, N)
    table("RSI under 25 and 8%+ under its 20-day average", sel(lambda r, dv, dl, sr: r <= 25 and dv <= -0.08), ALL, mid, K, N)
    table("RSI under 25, delivery 10 pts over its normal", sel(lambda r, dv, dl, sr: r <= 25 and dl is not None and dl >= 10), ALL, mid, K, N)
    table("RSI under 25, its sector also under 35", sel(lambda r, dv, dl, sr: r <= 25 and sr is not None and sr <= 35), ALL, mid, K, N)
    table("RSI under 25, its sector NOT (above 45)", sel(lambda r, dv, dl, sr: r <= 25 and sr is not None and sr > 45), ALL, mid, K, N)
    last = days[-1]; now_ = sorted(((r, s) for d, x, r, dv, dl, sr, s in EV if d == last), reverse=True)
    lastall = sorted(((R[s][-1], s) for s in fo if s in R and R[s][-1] == R[s][-1]), reverse=True)
    say("  in the zones on the last day of prices (%s): most overbought %s" % (dt.date.fromordinal(int(max(RAW[fo[0]][:, 0]))) if fo and fo[0] in RAW else "?", " · ".join("%s %.0f" % (s, r) for r, s in lastall[:10] if r >= 70) or "none above 70"))
    say("      most oversold %s" % (" · ".join("%s %.0f" % (s, r) for r, s in lastall[::-1][:10] if r <= 30) or "none under 30"))

    # B) the sudden break
    say("")
    say("B) THE SUDDEN BREAK - a share 2%+ its way on the day, hovering in a range under 1.2% for 90 minutes, then a 5-minute close beyond the range (after 12:00)")
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    BR = {1: [], -1: []}; YD = {1: [], -1: []}; nsh = 0
    for s in fo:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b:
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 7 or not len(A):
            continue
        nsh += 1; prev = None
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            mn, hi, lo, cl = p[:, 1], p[:, 3], p[:, 4], p[:, 5]; d = int(p[0, 0])
            if prev and len(p) >= 60:
                e = np.flatnonzero(mn <= 350); end = cl[e[-1]]
                y = np.flatnonzero(mn <= 220)                                  # 13:00 - the yardstick: every share 2%+ its way, held to 15:10
                if len(y):
                    mv = cl[y[-1]] / prev - 1
                    for dr in (1, -1):
                        if mv * dr >= 0.02:
                            YD[dr].append((d, {"m15": float("nan"), "m30": float("nan"), "m60": float("nan"), "eod": (end / cl[y[-1]] - 1) * dr}))
                done = set()
                for i in range(18, len(p)):
                    if mn[i] < 165 or mn[i] > 330:
                        continue
                    w_hi, w_lo = hi[i - 18:i].max(), lo[i - 18:i].min(); mv = cl[i - 1] / prev - 1
                    if (w_hi - w_lo) / cl[i - 1] > 0.012:
                        continue
                    for dr in (1, -1):
                        if dr in done or mv * dr < 0.02 or not ((cl[i] > w_hi) if dr > 0 else (cl[i] < w_lo)):
                            continue
                        done.add(dr); at = lambda k: (cl[min(i + k, e[-1])] / cl[i] - 1) * dr
                        BR[dr].append((d, {"m15": at(3), "m30": at(6), "m60": at(12), "eod": (end / cl[i] - 1) * dr, "bar": (cl[i] / cl[i - 1] - 1) * dr}))
            prev = float(p[-1, 5])
    if nsh < 50:
        say("    5-minute files for only %d F&O shares in data/secstudy - run sectorstudy.py once" % nsh)
    else:
        d5 = sorted({d for dr in (1, -1) for d, _ in YD[dr]}); mid5 = d5[len(d5) // 2] if d5 else 0
        say("    %d F&O shares · %d days of 5-minute prices (%s to %s)" % (nsh, len(d5), dt.date.fromordinal(d5[0]) if d5 else "?", dt.date.fromordinal(d5[-1]) if d5 else "?"))
        K2, N2 = ("m15", "m30", "m60", "eod"), ("15 min", "30 min", "60 min", "to 15:10")
        for dr, nm in ((-1, "DOWN 2%+ and breaks its range DOWN (PE)"), (1, "UP 2%+ and breaks its range UP (CE)")):
            av = lambda v: sum(v) / len(v) if v else float("nan")
            say("    yardstick: every share %s 2%%+ at 13:00, held to 15:10: %d cases · %s its way · up %d%%" % ("down" if dr < 0 else "up", len(YD[dr]), pc(av([r["eod"] for _, r in YD[dr]])), 100 * av([1.0 if r["eod"] > 0 else 0.0 for _, r in YD[dr]])))
            table(nm, BR[dr], YD[dr], mid5, K2, N2, sign=1)
            if BR[dr]:
                say("      the break bar itself moved %s on average - that part is gone before anyone can act; the columns above are what is left" % pc(av([r["bar"] for _, r in BR[dr]])))
                big = [x for x in BR[dr] if x[1]["bar"] >= 0.01]
                table("  the same, when the break bar is 1%+ (a jolt)", big, YD[dr], mid5, K2, N2, sign=1)
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "zonestudy.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/zonestudy.txt")


if __name__ == "__main__":
    main()
