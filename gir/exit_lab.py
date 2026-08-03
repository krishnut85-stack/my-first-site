#!/usr/bin/env python3
"""Exit engineering on V2 signals: replay daily paths through SL x exit-style grid."""
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
paths = []   # (sym, entry_px, highs[40], lows[40], closes[40])
for k in range(25, 206, 5):
    sub = {s: {q: a[: len(a) - k] for q, a in hist[s].items()} for s in syms}
    nc = nifty["c"][: len(nifty["c"]) - k]
    sub["__NIFTY__"] = {"c": nc}
    if (nc[-1] / nc[-21] - 1) * 100 <= -3.0: continue
    mkt = panel.market_context(sub, {})
    for s in syms:
        c, h, l = hist[s]["c"], hist[s]["h"], hist[s]["l"]
        i = len(c) - k - 1
        if i + 20 >= len(c) or c[i] <= 0: continue
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
            end = min(i + 41, len(c))
            paths.append((s, c[i], h[i+1:end], l[i+1:end], c[i+1:end]))
print(f"{len(paths)} signal paths captured\n")

def simulate(entry, hi, lo, cl, sl_pct, style):
    sl = entry * (1 + sl_pct / 100) if sl_pct else 0.0
    peak = entry
    for d in range(len(cl)):
        if sl and lo[d] <= sl:                       # stop hit intraday
            return (sl / entry - 1) * 100, d + 1, "SL"
        peak = max(peak, hi[d])
        if style == "trail7":
            sl = max(sl, peak * 0.93)
        if style == "fixed20" and d + 1 >= 20:
            return (cl[d] / entry - 1) * 100, d + 1, "T20"
        if style == "trail7" and d + 1 >= 40:
            return (cl[d] / entry - 1) * 100, d + 1, "T40"
    return (cl[-1] / entry - 1) * 100, len(cl), "END"

print(f"{'SL%':>5} {'STYLE':<9}{'BLEND%':>8}{'WIN%':>6}{'W_AVG':>7}{'L_AVG':>7}{'DAYS':>6}")
for sl_pct in (0, -4, -5, -6, -8):
    for style in ("fixed20", "trail7"):
        res = [simulate(e, h, l, c, sl_pct, style) for _, e, h, l, c in paths]
        rets = [r for r, _, _ in res]
        W = [r for r in rets if r > 0]; L = [r for r in rets if r <= 0]
        print(f"{sl_pct:>5} {style:<9}{np.mean(rets):>8.2f}{np.mean([r>0 for r in rets])*100:>6.0f}"
              f"{(np.mean(W) if W else 0):>7.1f}{(np.mean(L) if L else 0):>7.1f}"
              f"{np.mean([d for _, d, _ in res]):>6.1f}")
print("\nbaseline reference: no-SL fixed20 = the +7.28% V2 result")
