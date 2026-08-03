#!/usr/bin/env python3
"""Lever 1+2 exam: Pattern B (breakout) discovery + conviction tiering on V2."""
import pickle, re, numpy as np, panel
JF = {n: fn for f_, n, fn in panel.JUDGES}
def sc(n, f):
    try:
        s = JF[n](f); return 5.0 if s is None else float(s)
    except Exception: return 5.0
ETF = re.compile(r"BEES$|ETF|^SETF|^HDFCGOLD|^HDFCSILVER|^AXISGOLD|^AXISILVER|^SILVERAG|^GOLDCASE|^SILVERCASE|IETF$|^LIQUID|^GILT|ADD$|^MON100|^MAFANG")
hist = pickle.load(open(panel.CACHE + "/hist.pkl", "rb"))
nifty = hist.get("__NIFTY__")
syms = [s for s in hist if s != "__NIFTY__" and len(hist[s]["c"]) >= 265 and not ETF.search(s)]
A, B, OV = [], [], 0      # V2 dip signals, Pattern B signals, overlap count
tiers = {1: [], 2: [], 3: []}
dem_hi, dem_lo = [], []
for k in range(25, 206, 5):
    sub = {s: {q: a[: len(a) - k] for q, a in hist[s].items()} for s in syms}
    nc = nifty["c"][: len(nifty["c"]) - k]
    sub["__NIFTY__"] = {"c": nc}
    if (nc[-1] / nc[-21] - 1) * 100 <= -3.0: continue
    mkt = panel.market_context(sub, {})
    for s in syms:
        c = hist[s]["c"]; i = len(c) - k - 1
        if i + 20 >= len(c) or c[i] <= 0: continue
        f = panel.features(s, sub[s], mkt); f["deliv"] = None; f["bulk"] = {}
        vet = False
        for n, fn in panel.VETOES:
            try:
                if fn(f): vet = True; break
            except Exception: pass
        if vet: continue
        trend = sc("ema50x200", f) >= 8 and sc("px_above_ema200", f) >= 8
        if not trend: continue
        f20 = (c[i + 20] / c[i] - 1) * 100
        demand = sc("close_strength_3d", f)
        # V2 dip pattern + conviction data
        p = [sc("stretch_below_e20", f) >= 7, sc("gap_down_recovery", f) >= 8,
             sc("down3_volume", f) >= 7]
        isA = any(p) and demand >= 7
        if isA:
            A.append(f20)
            tiers[min(3, sum(p))].append(f20)
            (dem_hi if demand >= 8.5 else dem_lo).append(f20)
        # Pattern B breakout
        isB = ((sc("inside_break", f) >= 8 or sc("gap_up_hold", f) >= 9)
               and sc("dist_52w_low", f) >= 8 and demand >= 7)
        if isB:
            B.append(f20)
            if isA: OV += 1
def rep(name, r):
    if not r: print(f"{name}: 0 signals"); return
    print(f"{name}: n={len(r)}  fwd20 {np.mean(r):+.2f}%  win {np.mean([x>0 for x in r])*100:.0f}%")
print("=== LEVER 1: Pattern B (breakout) vs V2 ===")
rep("V2 dip   ", A)
rep("PatternB ", B)
print(f"overlap: {OV} signals in both ({OV/max(len(B),1)*100:.0f}% of B)")
print("\n=== LEVER 2: conviction tiers within V2 ===")
for t in (1, 2, 3):
    rep(f"pull_judges={t}", tiers[t])
rep("demand>=8.5", dem_hi)
rep("demand 7-8.5", dem_lo)
