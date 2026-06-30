#!/usr/bin/env python3
"""Autopsy of dip-in-uptrend signals: what separates winners from losers?
Re-runs the replay, captures entry context per signal, segments win rate."""
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
sigs = []
t0 = time.time()
for k in range(25, 206, 5):
    sub = {s: {key: a[: len(a) - k] for key, a in hist[s].items()} for s in syms}
    nclose = None
    if nifty is not None:
        nc = nifty["c"][: len(nifty["c"]) - k]
        sub["__NIFTY__"] = {"c": nc}
        nclose = nc
    mkt = panel.market_context(sub, {})
    for s in syms:
        c = hist[s]["c"]; i = len(c) - k - 1
        if i + 20 >= len(c) or c[i] <= 0:
            continue
        f = panel.features(s, sub[s], mkt); f["deliv"] = None; f["bulk"] = {}
        vet = False
        for n, fn in panel.VETOES:
            try:
                if fn(f): vet = True; break
            except Exception: pass
        if vet: continue
        if not (sc("ema50x200", f) >= 8 and sc("px_above_ema200", f) >= 8 and
                (sc("stretch_below_e20", f) >= 7 or sc("gap_down_recovery", f) >= 8
                 or sc("down3_volume", f) >= 7) and sc("close_strength_3d", f) >= 7):
            continue
        cc = sub[s]["c"]; hh = sub[s]["h"]; ll = sub[s]["l"]
        e20 = panel.ema(cc, 20); e200 = panel.ema(cc, 200)
        a14 = panel.atr(hh, ll, cc, 14)
        fwd = c[i:i + 21]
        mae = (fwd.min() / c[i] - 1) * 100          # max adverse excursion
        mfe = (fwd.max() / c[i] - 1) * 100          # max favorable excursion
        nif_reg = 0
        if nclose is not None and len(nclose) >= 21:
            nif_reg = (nclose[-1] / nclose[-21] - 1) * 100   # NIFTY 20d trend at entry
        sigs.append(dict(
            sym=s, f20=(c[i + 20] / c[i] - 1) * 100, mae=mae, mfe=mfe,
            depth=(cc[-1] / e20[-1] - 1) * 100,                   # % vs EMA20 (dip depth)
            ext200=(cc[-1] / e200[-1] - 1) * 100,                 # extension above 200EMA
            atrpct=a14[-1] / cc[-1] * 100 if a14 is not None else 0,
            nifty20=nif_reg,
            drop5=(cc[-1] / cc[-6] - 1) * 100,                    # 5d momentum into entry
            turn=f.get("turn20", 0) / 1e7,                        # turnover in crores
        ))
print(f"{len(sigs)} signals captured | {time.time()-t0:.0f}s")
W = [x for x in sigs if x["f20"] > 0]; L = [x for x in sigs if x["f20"] <= 0]
print(f"winners {len(W)} avg {np.mean([x['f20'] for x in W]):+.1f}% | "
      f"losers {len(L)} avg {np.mean([x['f20'] for x in L]):+.1f}%")
print(f"\n{'ATTRIBUTE':<10}{'WIN_AVG':>9}{'LOSE_AVG':>9}   (gap = the tell)")
for a in ("depth", "ext200", "atrpct", "nifty20", "drop5", "turn", "mae", "mfe"):
    print(f"{a:<10}{np.mean([x[a] for x in W]):>9.2f}{np.mean([x[a] for x in L]):>9.2f}")
print("\nWIN RATE BY BUCKET (n) — look for the killing zone:")
def bucket(attr, edges):
    print(f"  {attr}:")
    for lo, hi in zip(edges[:-1], edges[1:]):
        grp = [x for x in sigs if lo <= x[attr] < hi]
        if grp:
            wr = np.mean([x["f20"] > 0 for x in grp]) * 100
            f20 = np.mean([x["f20"] for x in grp])
            print(f"    [{lo:>6} to {hi:>6}): n={len(grp):<3} win {wr:>3.0f}%  f20 {f20:+.1f}%")
bucket("nifty20", [-99, -3, 0, 3, 99])
bucket("ext200", [-99, 5, 15, 30, 999])
bucket("depth", [-99, -6, -3, 0, 99])
bucket("atrpct", [0, 2, 3, 4, 99])
bucket("drop5", [-99, -7, -4, -1, 99])
print("\nALL LOSERS (the accused):")
for x in sorted(L, key=lambda z: z["f20"]):
    print(f"  {x['sym']:<14} f20 {x['f20']:+5.1f}% | nifty20 {x['nifty20']:+4.1f} "
          f"ext200 {x['ext200']:+5.1f} depth {x['depth']:+4.1f} atr {x['atrpct']:.1f} mae {x['mae']:+5.1f}")
