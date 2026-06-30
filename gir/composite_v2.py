#!/usr/bin/env python3
"""Dip-in-uptrend V2: + regime gate (NIFTY 20d > -3%) + ETF exclusion."""
import pickle, time, re, numpy as np, panel
JF = {name: fn for fam, name, fn in panel.JUDGES}
def sc(name, f):
    try:
        s = JF[name](f); return 5.0 if s is None else float(s)
    except Exception: return 5.0
ETF_PAT = re.compile(r"BEES$|ETF|^SETF|^HDFCGOLD|^HDFCSILVER|^AXISGOLD|^AXISILVER|"
                     r"^SILVERAG|^GOLDCASE|^SILVERCASE|IETF$|^LIQUID|^GILT|ADD$|^MON100|^MAFANG")
hist = pickle.load(open(panel.CACHE + "/hist.pkl", "rb"))
nifty = hist.get("__NIFTY__")
syms = [s for s in hist if s != "__NIFTY__" and len(hist[s]["c"]) >= 265]
etfs = sorted(s for s in syms if ETF_PAT.search(s))
print(f"excluding {len(etfs)} ETF-pattern symbols: {', '.join(etfs[:20])}{'...' if len(etfs)>20 else ''}")
syms = [s for s in syms if not ETF_PAT.search(s)]
r20, b20l = [], []
t0 = time.time()
for k in range(25, 206, 5):
    sub = {s: {key: a[: len(a) - k] for key, a in hist[s].items()} for s in syms}
    nc = nifty["c"][: len(nifty["c"]) - k] if nifty is not None else None
    if nc is not None: sub["__NIFTY__"] = {"c": nc}
    regime_ok = nc is not None and len(nc) >= 21 and (nc[-1]/nc[-21]-1)*100 > -3.0
    mkt = panel.market_context(sub, {})
    for s in syms:
        c = hist[s]["c"]; i = len(c) - k - 1
        if i + 20 >= len(c) or c[i] <= 0: continue
        b20l.append(c[i+20]/c[i]-1)
        if not regime_ok: continue
        f = panel.features(s, sub[s], mkt); f["deliv"] = None; f["bulk"] = {}
        vet = False
        for n, fn in panel.VETOES:
            try:
                if fn(f): vet = True; break
            except Exception: pass
        if vet: continue
        if (sc("ema50x200", f) >= 8 and sc("px_above_ema200", f) >= 8 and
            (sc("stretch_below_e20", f) >= 7 or sc("gap_down_recovery", f) >= 8
             or sc("down3_volume", f) >= 7) and sc("close_strength_3d", f) >= 7):
            r20.append(c[i+20]/c[i]-1)
b20 = np.mean(b20l)*100
print(f"\nV2 (regime + no-ETF): {len(r20)} signals")
if r20:
    print(f"fwd20 {np.mean(r20)*100:+.2f}%  win {np.mean([x>0 for x in r20])*100:.0f}%  "
          f"edge {np.mean(r20)*100-b20:+.2f}%  (V1 was: 43 sigs, +3.04%, 53%)")
print(f"baseline {b20:+.2f}% | {time.time()-t0:.0f}s")
