#!/usr/bin/env python3
"""obscan.py - READ ONLY. The trader, 20 Nov: "Show me one F&O share that was EXTREMELY overbought, kept going up from there, and prove
there was no correction." Over every day in the minute store (/root/hist or GIR_HIST), daily closes:

  EVENT      the first day a share's daily RSI(14) closes >= 80 (EXTREME; a new event only after RSI has been below 70 again)
  AFTER IT   the next 20 trading days: the move to day 20, the highest close, and the WORST PULLBACK = the largest fall from any
             high close to a later close in those 20 days (close to close, %), and whether it ever closed below its 20-day average
  CONTINUED  up at day 20 AND worst pullback under 5% AND never closed below the 20-day average  = "kept going, no correction"
  CORRECTED  worst pullback 5% or more, or it closed below the 20-day average
Prints how often each happened (the honest base rate), the 15 best "kept going" cases with their numbers (the proof the trader asked
for - he can check each on a chart), and the 15 sharpest corrections.
  python3 obscan.py [--rsi 80] [--days 20] [--pull 5] [--force]
Writes only STORE/obscan_report.txt. numpy only."""
import os, sys, datetime as dt
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sectorlag import daily, fmtd, STORE, IST, NOT_SHARES


def arg(n, d):
    return type(d)(sys.argv[sys.argv.index(n) + 1]) if n in sys.argv else d


def rsi_series(c, n=14):
    out = np.full(len(c), np.nan)
    d = np.diff(c)
    if len(d) < n + 1:
        return out
    up = np.where(d > 0, d, 0.0); dn = np.where(d < 0, -d, 0.0)
    au, ad = up[:n].mean(), dn[:n].mean()
    out[n] = 100.0 if ad == 0 else 100 - 100 / (1 + au / ad)
    for i in range(n, len(d)):
        au = (au * (n - 1) + up[i]) / n; ad = (ad * (n - 1) + dn[i]) / n
        out[i + 1] = 100.0 if ad == 0 else 100 - 100 / (1 + au / ad)
    return out


def main():
    now = dt.datetime.now(IST)
    if now.weekday() < 5 and (9, 0) <= (now.hour, now.minute) <= (15, 35) and "--force" not in sys.argv:
        print("market hours: add --force (it is light)"); return
    try:
        os.nice(19)
    except Exception:
        pass
    RSI, N, PULL = arg("--rsi", 80.0), arg("--days", 20), arg("--pull", 5.0)
    mdir = os.path.join(STORE, "min")
    names = sorted(f[:-4] for f in os.listdir(mdir) if f.endswith(".npz") and f[:-4] not in NOT_SHARES)
    ev = []
    for s in names:
        try:
            D = daily(os.path.join(mdir, s + ".npz"))
        except Exception:
            continue
        ds = sorted(D); c = np.array([D[d][1] for d in ds])
        if len(c) < 60:
            continue
        jump = np.abs(np.diff(c) / c[:-1]) > 0.2                     # split / bonus: skip windows that contain one
        r = rsi_series(c)
        armed = True
        for i in range(20, len(c) - N):
            if not np.isfinite(r[i]):
                continue
            if r[i] < 70:
                armed = True
            if armed and r[i] >= RSI:
                armed = False
                if jump[max(0, i - 20):i + N].any():
                    continue
                w = c[i:i + N + 1]
                peak = np.maximum.accumulate(w)
                worst = float(((w / peak - 1) * 100).min())
                sma = np.array([c[k - 19:k + 1].mean() for k in range(i, i + N + 1)])
                below = bool((w < sma).any())
                ret = (w[-1] / w[0] - 1) * 100
                hi = (w.max() / w[0] - 1) * 100
                cont = ret > 0 and worst > -PULL and not below
                ev.append(dict(s=s, d=ds[i], rsi=r[i], ret=ret, hi=hi, worst=worst, below=below, cont=cont, p0=w[0], p1=w[-1]))
    L = []
    P = L.append
    n = len(ev)
    P("=== EXTREME OVERBOUGHT - WHAT HAPPENED NEXT (obscan.py) · daily RSI(14) >= %.0f · next %d trading days · correction = a %.0f%%+"
      " pullback or a close below the 20-day average" % (RSI, N, PULL))
    if not n:
        P("no events"); print("\n".join(L)); return
    k = sum(e["cont"] for e in ev); up = sum(e["ret"] > 0 for e in ev)
    P("events: %d (F&O shares in the store, each counted once until RSI falls back under 70)" % n)
    P("  KEPT GOING, NO CORRECTION: %d (%.0f%%)   |   up after %d days at all: %d (%.0f%%)   |   CORRECTED: %d (%.0f%%)" % (
        k, k / n * 100, N, up, up / n * 100, n - k, (n - k) / n * 100))
    P("  median move to day %d: %+.1f%% · median worst pullback: %.1f%% · closed below the 20-day average at some point: %.0f%%" % (
        N, np.median([e["ret"] for e in ev]), np.median([e["worst"] for e in ev]), np.mean([e["below"] for e in ev]) * 100))
    P("")
    P("THE PROOF - the 15 strongest 'kept going, no correction' cases (check each on a daily chart):")
    for e in sorted([e for e in ev if e["cont"]], key=lambda e: -e["ret"])[:15]:
        P("  %-12s %s  RSI %.0f  close %.2f -> %.2f after %d days = %+.1f%%  (best %+.1f%%)  worst pullback %.1f%%  never below the 20-day avg"
          % (e["s"], fmtd(e["d"]), e["rsi"], e["p0"], e["p1"], N, e["ret"], e["hi"], e["worst"]))
    P("")
    P("THE OTHER SIDE - the 15 sharpest corrections after an EXTREME reading:")
    for e in sorted(ev, key=lambda e: e["worst"])[:15]:
        P("  %-12s %s  RSI %.0f  worst pullback %.1f%%  move to day %d %+.1f%%%s" % (
            e["s"], fmtd(e["d"]), e["rsi"], e["worst"], N, e["ret"], "  (closed below the 20-day avg)" if e["below"] else ""))
    P("")
    P("READ: both happen. The base rate above says how often an EXTREME share kept running without a real pullback - that is the")
    P("honest answer to 'does overbought mean it must fall'. Closes only; intraday dips inside a day are not counted.")
    txt = "\n".join(L)
    print(txt)
    try:
        open(os.path.join(STORE, "obscan_report.txt"), "w").write(txt + "\n")
    except Exception as e:
        print("could not write:", e)


if __name__ == "__main__":
    main()
