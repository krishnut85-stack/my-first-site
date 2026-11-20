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
  python3 obscan.py --oversold [--rsi 30]     the MIRROR: RSI <= 30, "kept falling, no bounce" vs "bounced"; split by the market
                                              (NIFTY above / below its 50-day average that day) - "is oversold useless in a strong market?"
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
    OS = "--oversold" in sys.argv
    RSI, N, PULL = arg("--rsi", 30.0 if OS else 80.0), arg("--days", 20), arg("--pull", 5.0)
    nifD = daily(os.path.join(STORE, "min", "NIFTY.npz")); nds = sorted(nifD); nc = np.array([nifD[d][1] for d in nds])
    nup = {d: (i >= 49 and nc[i] > nc[i - 49:i + 1].mean()) for i, d in enumerate(nds)}
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
            if (r[i] > 30 if OS else r[i] < 70):
                armed = True
            if armed and (r[i] <= RSI if OS else r[i] >= RSI):
                armed = False
                if jump[max(0, i - 20):i + N].any():
                    continue
                w = c[i:i + N + 1]
                sma = np.array([c[k - 19:k + 1].mean() for k in range(i, i + N + 1)])
                ret = (w[-1] / w[0] - 1) * 100
                if OS:                                    # mirror: worst BOUNCE from a low close; "below" = closed ABOVE the 20-day avg
                    trough = np.minimum.accumulate(w)
                    worst = -float(((w / trough - 1) * 100).max())
                    below = bool((w > sma).any())
                    hi = (w.min() / w[0] - 1) * 100
                    cont = ret < 0 and worst > -PULL and not below
                else:
                    peak = np.maximum.accumulate(w)
                    worst = float(((w / peak - 1) * 100).min())
                    below = bool((w < sma).any())
                    hi = (w.max() / w[0] - 1) * 100
                    cont = ret > 0 and worst > -PULL and not below
                ev.append(dict(s=s, d=ds[i], rsi=r[i], ret=ret, hi=hi, worst=worst, below=below, cont=cont, p0=w[0], p1=w[-1], mkt=nup.get(ds[i], False)))
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
    for lab, sub in (("NIFTY ABOVE its 50-day avg (strong market)", [e for e in ev if e["mkt"]]),
                     ("NIFTY BELOW its 50-day avg (weak market)", [e for e in ev if not e["mkt"]])):
        if sub:
            P("  %s: %d events · %s %.0f%% · up after %d days %.0f%% · median move %+.1f%%" % (
                lab, len(sub), "KEPT FALLING, NO BOUNCE" if OS else "KEPT GOING", np.mean([e["cont"] for e in sub]) * 100, N,
                np.mean([e["ret"] > 0 for e in sub]) * 100, np.median([e["ret"] for e in sub])))
    if OS:
        P("  (OVERSOLD MODE: 'worst pullback' = the biggest BOUNCE from a low close shown as a negative; 'KEPT GOING' rows below = kept"
          " FALLING with no 5%+ bounce and never closed above the 20-day avg; 'corrections' below = the sharpest BOUNCES)")
    P("")
    P("THE PROOF - the 15 strongest 'kept going, no correction' cases (check each on a daily chart):")
    for e in sorted([e for e in ev if e["cont"]], key=lambda e: (e["ret"] if OS else -e["ret"]))[:15]:
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
    if OS:
        L[0] = L[0].replace("EXTREME OVERBOUGHT", "OVERSOLD").replace(">=", "<=").replace("a %.0f%%+ pullback or a close below" % PULL,
                                                                                        "a %.0f%%+ bounce or a close above" % PULL)
        for a_, b_ in (("KEPT GOING, NO CORRECTION", "KEPT FALLING, NO BOUNCE"), ("CORRECTED:", "BOUNCED:"),
                       ("until RSI falls back under 70", "until RSI rises back over 30"),
                       ("median worst pullback", "median biggest bounce (shown negative)"),
                       ("closed below the 20-day average at some point", "closed ABOVE the 20-day average at some point"),
                       ("strongest 'kept going, no correction' cases", "strongest 'kept falling, no bounce' cases"),
                       ("15 sharpest corrections", "15 sharpest bounces"), ("worst pullback", "biggest bounce"),
                       ("never below the 20-day avg", "never above the 20-day avg"), ("(best ", "(lowest ")):
            L = [x.replace(a_, b_) for x in L]
    txt = "\n".join(L)
    print(txt)
    try:
        open(os.path.join(STORE, "obscan_oversold_report.txt" if OS else "obscan_report.txt"), "w").write(txt + "\n")
    except Exception as e:
        print("could not write:", e)


if __name__ == "__main__":
    main()
