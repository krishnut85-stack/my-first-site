#!/usr/bin/env python3
"""Backtest the DIP-IN-UPTREND composite discovered by judge grading.
Rule: uptrend (ema50x200>=8 AND px_above_ema200>=8) + pullback (stretch_below_e20>=7
OR gap_down_recovery>=8 OR down3_volume>=7) + demand (close_strength_3d>=7), no veto."""
import pickle, time, numpy as np, panel

JF = {name: fn for fam, name, fn in panel.JUDGES}
def sc(name, f):
    try:
        s = JF[name](f)
        return 5.0 if s is None else float(s)
    except Exception:
        return 5.0

hist = pickle.load(open(panel.CACHE + "/hist.pkl", "rb"))
nifty = hist.get("__NIFTY__")
syms = [s for s in hist if s != "__NIFTY__" and len(hist[s]["c"]) >= 265]
res5, res20, base5, base20 = [], [], [], []
t0 = time.time()
for k in range(25, 206, 5):
    sub = {s: {key: a[: len(a) - k] for key, a in hist[s].items()} for s in syms}
    if nifty is not None:
        sub["__NIFTY__"] = {"c": nifty["c"][: len(nifty["c"]) - k]}
    mkt = panel.market_context(sub, {})
    for s in syms:
        c = hist[s]["c"]; i = len(c) - k - 1
        if i + 20 >= len(c) or c[i] <= 0:
            continue
        f5 = c[i + 5] / c[i] - 1; f20 = c[i + 20] / c[i] - 1
        base5.append(f5); base20.append(f20)
        f = panel.features(s, sub[s], mkt); f["deliv"] = None; f["bulk"] = {}
        vet = [n for n, fn in panel.VETOES if (lambda: (lambda r: r)(fn(f)))() ] if False else []
        for n, fn in panel.VETOES:
            try:
                if fn(f): vet.append(n)
            except Exception: pass
        if vet: continue
        trend = sc("ema50x200", f) >= 8 and sc("px_above_ema200", f) >= 8
        pull = sc("stretch_below_e20", f) >= 7 or sc("gap_down_recovery", f) >= 8 or sc("down3_volume", f) >= 7
        demand = sc("close_strength_3d", f) >= 7
        if trend and pull and demand:
            res5.append(f5); res20.append(f20)
b20 = np.mean(base20) * 100
print(f"\nDIP-IN-UPTREND COMPOSITE: {len(res20)} signals over {len(base20)} observations")
if res20:
    print(f"fwd5 {np.mean(res5)*100:+.2f}%  fwd20 {np.mean(res20)*100:+.2f}%  "
          f"win20 {np.mean([x>0 for x in res20])*100:.0f}%  edge vs baseline {np.mean(res20)*100-b20:+.2f}%")
print(f"baseline fwd20 {b20:+.2f}% | {time.time()-t0:.0f}s")
