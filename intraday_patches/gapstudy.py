#!/usr/bin/env python3
"""gapstudy.py - READ ONLY. AFTER OVERNIGHT NEWS, WHAT IS LEFT AT THE OPEN? (Rama, 17 Nov: "based on the macro news and world-wide news we need
to shoot the gun. What can we expect?"). Overnight news shows first as the OPENING GAP - which nobody can trade. The question for a trade at
09:15 is what the share does AFTER the open. Every F&O share, 2 years of Kite's daily prices (and the 5-minute prices kept, for the timing):
  1) THE GAP BY SIZE   a share opening 1-2% / 2-3% / 3-5% / 5%+ away from yesterday's close, up and down: from the open to the close does it
                 CONTINUE (the news trade pays) or come back? How often is the whole gap filled the same day?
  2) WHOSE NEWS  a 2%+ gap when the share's whole SECTOR gapped the same way (sector news: a duty, a policy, Nasdaq for IT) · when the whole
                 MARKET gapped · when the share gapped ALONE (its own news: results, an order, an approval)
  3) THE SECTOR  a sector opening 0.7%+ away from the market (all its NSE shares, by size): does the sector go on from the open, against the market?
  4) THE CLOCK   the 2%+ gaps on 5-minute prices: open -> 09:45, then 09:45 -> 15:10 - is the move after the open made at once, or later?
"continued" = the move from the open in the gap's direction (a plus pays the news trade: CE after a gap up, PE after a gap down).
✔ = the same sign in both halves of the days and at least 0.15%. Charges are not counted. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 gapstudy.py   -> prints, saves data/gapstudy.txt"""
import os, re, sys, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def row(name, X, mid, extra=""):
    """X = [(day, continued, filled)] -> one line"""
    if len(X) < 40:
        say("    %-46s %5d cases - too few" % (name, len(X))); return
    c = np.array([x[1] for x in X]); a = np.array([x[1] for x in X if x[0] < mid]); b = np.array([x[1] for x in X if x[0] >= mid])
    ok = len(a) >= 15 and len(b) >= 15 and a.mean() * b.mean() > 0 and abs(c.mean()) >= 0.0015 and min(abs(a.mean()), abs(b.mean())) >= 0.0007
    say("    %-46s %5d cases │ from the open %s │ continued %2d%% │ gap filled the same day %2d%% │ halves %s / %s %s%s" % (name, len(X), pc(c.mean()), 100 * (c > 0).mean(),
        100 * np.mean([x[2] for x in X]), pc(a.mean() if len(a) else float("nan")), pc(b.mean() if len(b) else float("nan")), ("✔ CONTINUES" if c.mean() > 0 else "✔ COMES BACK") if ok else "✘ no lean", extra))


def main():
    import seclive as SL, flowtest
    say("📊 AFTER OVERNIGHT NEWS, WHAT IS LEFT AT THE OPEN? · the opening gap of every F&O share on 2 years of daily prices")
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    try:
        RAW = flowtest.daily(SL.get_kite, list(SEC), 500)
    except Exception as ex:
        say("  ❌ daily prices: %s" % ex); return
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W)); sj = {s: j for j, s in enumerate(syms)}
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]}); di = {d: i for i, d in enumerate(days)}; n, m = len(days), len(syms)
    O = np.full((n, m), np.nan); H = O.copy(); Lo = O.copy(); C = O.copy()
    for j, s in enumerate(syms):
        for r in RAW[s]:
            i = di[int(r[0])]; O[i, j], H[i, j], Lo[i, j], C[i, j] = r[1], r[2], r[3], r[4]
    pcl = np.vstack([np.full((1, m), np.nan), C[:-1]])
    gap = O / pcl - 1; intr = C / O - 1; bad = np.isnan(gap) | (np.abs(gap) > 0.2) | np.isnan(intr) | (np.abs(intr) > 0.25); gap[bad] = np.nan; intr[bad] = np.nan
    Wv = np.array([W.get(s) or 1.0 for s in syms])

    def wm(X, idx):
        x = X[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x); sm = w.sum(1); sm[sm == 0] = np.nan
        return np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / sm
    allj = np.arange(m); mg, mi = wm(gap, allj), wm(intr, allj)
    secs = sorted({SEC[s] for s in syms}); sidx = {k: np.array([j for j, s in enumerate(syms) if SEC[s] == k]) for k in secs}
    secs = [k for k in secs if len(sidx[k]) >= 5]; SG = {k: wm(gap, sidx[k]) for k in secs}; SI = {k: wm(intr, sidx[k]) for k in secs}
    fj = [j for j, s in enumerate(syms) if s in FO]; mid = days[n // 2]
    say("  %d F&O shares · %d days (%s to %s) · sizes: %s" % (len(fj), n - 1, dt.date.fromordinal(days[1]), dt.date.fromordinal(days[-1]), wsrc))
    EV = []                                                  # (day, share j, gap, continued, filled, sector gap, market gap)
    for j in fj:
        k = SEC[syms[j]]; sg = SG.get(k)
        for i in range(1, n):
            g = gap[i, j]
            if g != g or abs(g) < 0.01:
                continue
            dr = 1 if g > 0 else -1; filled = (Lo[i, j] <= pcl[i, j]) if dr > 0 else (H[i, j] >= pcl[i, j])
            EV.append((days[i], j, g, intr[i, j] * dr, bool(filled), (sg[i] if sg is not None else np.nan), mg[i]))
    base = [(days[i], intr[i, j], False) for j in fj for i in range(1, n) if gap[i, j] == gap[i, j] and abs(gap[i, j]) < 0.003]
    say("  yardstick - a share that opened flat (under 0.3%%): from the open to the close %s on average, up %d%% of the time (%d cases)" % (pc(np.mean([b[1] for b in base])), 100 * np.mean([b[1] > 0 for b in base]), len(base)))
    say("")
    say("1) THE GAP BY SIZE - from the open to the close, in the gap's direction")
    for dr, nm in ((1, "gap UP"), (-1, "gap DOWN")):
        for lo, hi, lab in ((0.01, 0.02, "1-2%"), (0.02, 0.03, "2-3%"), (0.03, 0.05, "3-5%"), (0.05, 9, "5%+")):
            row("%s %s (%s after it)" % (nm, lab, "CE" if dr > 0 else "PE"), [(e[0], e[3], e[4]) for e in EV if e[2] * dr >= lo and e[2] * dr < hi], mid)
    say("")
    say("2) WHOSE NEWS - the gaps of 2%+")
    big = [e for e in EV if abs(e[2]) >= 0.02]
    for dr, nm in ((1, "UP"), (-1, "DOWN")):
        B = [e for e in big if e[2] * dr > 0]
        row("gap %s with its SECTOR (sector 0.7%%+ same way)" % nm, [(e[0], e[3], e[4]) for e in B if e[5] == e[5] and e[5] * dr >= 0.007 and abs(e[6]) < 0.007], mid)
        row("gap %s with the whole MARKET (0.7%%+)" % nm, [(e[0], e[3], e[4]) for e in B if e[6] * dr >= 0.007], mid)
        row("gap %s ALONE (its sector under 0.3%%)" % nm, [(e[0], e[3], e[4]) for e in B if e[5] == e[5] and abs(e[5]) < 0.003], mid)
    say("")
    say("3) THE SECTOR - a sector opening 0.7%+ away from the market: the sector from the open, AGAINST the market")
    for dr, nm in ((1, "sector gap UP against the market"), (-1, "sector gap DOWN against the market")):
        X = [(days[i], (SI[k][i] - mi[i]) * dr, False) for k in secs for i in range(1, n) if SG[k][i] == SG[k][i] and (SG[k][i] - mg[i]) * dr >= 0.007]
        row(nm, X, mid)
    # 4) the clock, on the 5-minute prices kept
    say("")
    say("4) THE CLOCK - the 2%+ gaps on Kite's 5-minute prices: when is the move after the open made?")
    try:
        import pickstudy
        Cd = os.path.join(D, "data", "secstudy"); best = {}
        for f in (os.listdir(Cd) if os.path.isdir(Cd) else []):
            mm = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
            if mm and (mm.group(1) not in best or mm.group(2) > best[mm.group(1)][0]):
                best[mm.group(1)] = (mm.group(2), f)
        T = {}
        for j in fj:
            b = best.get(re.sub(r"[^A-Z0-9]", "_", syms[j]))
            if b:
                T[j] = pickstudy.scan(os.path.join(Cd, b[1]), 30)                 # (open, price at 09:45, ..., price at 15:10, ...)
        d5 = sorted({d for v in T.values() for d in v}); mid5 = d5[len(d5) // 2] if d5 else 0
        for dr, nm in ((1, "gap UP 2%+"), (-1, "gap DOWN 2%+")):
            A, Bx = [], []
            for e in big:
                t = T.get(e[1], {}).get(e[0])
                if t and e[2] * dr > 0:
                    A.append((e[0], (t[1] / t[0] - 1) * dr, False)); Bx.append((e[0], (t[5] / t[1] - 1) * dr, False))
            if len(A) < 40:
                say("    %s: only %d cases on the %d days of 5-minute prices - too few" % (nm, len(A), len(d5))); continue
            say("    %s (%d cases, %d days):" % (nm, len(A), len(d5)))
            row("  the open → 09:45", A, mid5); row("  09:45 → 15:10", Bx, mid5)
    except Exception as ex:
        say("    (5-minute part not run: %s)" % str(ex)[:90])
    say("")
    say("  read it: ✔ CONTINUES = after that kind of gap the news trade from the open has paid · ✔ COMES BACK = fading it has paid · ✘ = neither - wait for the price")
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "gapstudy.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/gapstudy.txt")


if __name__ == "__main__":
    main()
