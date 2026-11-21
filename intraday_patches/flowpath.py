#!/usr/bin/env python3
"""flowpath.py - READ ONLY. WHEN DOES THE MONEY SHOW IN THE PRICE? (Rama, 17 Nov: "where is the net flow, how is the sector behaving during the
market, and how long does it take to take effect?"). fpisec.py showed that in the SAME fortnight the sectors foreign funds bought most beat the
ones they sold most 42 times of 48. This looks inside that:
  1) THE PATH        the 5 most bought and the 5 most sold sectors of each fortnight - the sector against the market in each stretch: 20-11 and
                     10-1 days BEFORE the fortnight, its first half, its second half, and 1-5 / 6-10 / 11-20 / 21-40 days AFTER it ends.
                     Does the price go first and the money follow, do they move together, or does the price keep going afterwards?
  1b) THE CLUE       half-way through a fortnight, before any report: do the sectors leading / lagging in its first half turn out to be the
                     ones the foreign funds were buying / selling - and do they go on in the second half and the 10 days after?
  2) IN THE DAY      on the days of such a fortnight: is the bought sector's gain made OVERNIGHT (yesterday's close -> the open) or in the
                     DAYTIME (open -> close)? And from Kite's 5-minute prices (the days sectorstudy.py keeps): the first hour (to 10:15),
                     the middle (10:15-14:15), the last 75 minutes (14:15-15:30) - when in the session do institutions' sectors gain?
  3) HOW LONG THEY KEEP GOING   once they buy (or sell) a sector in a fortnight, how often the next fortnight is the same way, and how long the
                     runs last
Prices: every NSE share of the sector, size-weighted, against the whole market. Needs data/fpisec.json (run fpisec.py once). Orders nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 flowpath.py   -> prints, saves data/flowpath.txt"""
import os, re, sys, json, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)
bp = lambda v: " n/a" if v is None or v != v else "%+.1f" % (10000 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def five_min(syms):
    """the newest 5-minute file sectorstudy.py kept for each share -> {sym: {day ordinal: (open, at 10:15, at 14:15, close)}}"""
    C = os.path.join(D, "data", "secstudy"); best = {}; out = {}
    if not os.path.isdir(C):
        return out
    for f in os.listdir(C):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    for s in syms:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b:
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 6 or not len(A):
            continue
        d = {}
        for part in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            mn = part[:, 1]; a1 = part[mn <= 55]; a2 = part[mn <= 295]
            if len(part) >= 40 and len(a1) and len(a2):
                d[int(part[0, 0])] = (float(part[0, 2]), float(a1[-1, 5]), float(a2[-1, 5]), float(part[-1, 5]))
        if d:
            out[s] = d
    return out


def main():
    import seclive as SL, flowtest, fpisec
    say("📊 WHEN DOES THE MONEY SHOW IN THE PRICE? · foreign funds' fortnightly buying by sector (NSDL) against Kite's prices")
    S = fpisec.load(); F = sorted(k for k, v in S["net"].items() if len(v) >= 12)
    if len(F) < 10:
        say("  ❌ only %d fortnights in data/fpisec.json - run `python3 fpisec.py` first" % len(F)); return
    SEC, _ = SL.universe(); W, wsrc = SL.nse_weights()
    try:
        RAW = flowtest.daily(SL.get_kite, list(SEC), 500)
    except Exception as ex:
        say("  ❌ prices: %s" % ex); return
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W)); sj = {s: j for j, s in enumerate(syms)}
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]}); di = {d: i for i, d in enumerate(days)}; n, m = len(days), len(syms)
    O = np.full((n, m), np.nan); Cl = O.copy()
    for j, s in enumerate(syms):
        for r in RAW[s]:
            i = di[int(r[0])]; O[i, j], Cl[i, j] = r[1], r[4]
    pcl = np.vstack([np.full((1, m), np.nan), Cl[:-1]])
    cc = Cl / pcl - 1; ov = O / pcl - 1; intr = Cl / O - 1
    bad = np.isnan(cc) | (np.abs(cc) > 0.25) | (np.abs(ov) > 0.25); cc[bad] = np.nan; ov[bad] = np.nan; intr[bad] = np.nan
    Wv = np.array([W.get(s) or 1.0 for s in syms])

    def wm(X, idx):
        x = X[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x); sm = w.sum(1); sm[sm == 0] = np.nan
        return np.nan_to_num(np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / sm)
    allj = np.arange(m); secs = [s for s in S["net"][F[-1]] if fpisec.gir_groups(s)]; IDX = {}
    for s in secs:
        g = fpisec.gir_groups(s); idx = np.array([j for j, y in enumerate(syms) if SEC[y] in g])
        if len(idx) >= 4:
            IDX[s] = idx
    REL = {s: wm(cc, IDX[s]) - wm(cc, allj) for s in IDX}; ROV = {s: wm(ov, IDX[s]) - wm(ov, allj) for s in IDX}; RIN = {s: wm(intr, IDX[s]) - wm(intr, allj) for s in IDX}
    held = lambda s, k: next((S["auc"][a].get(s) for a in sorted(S["auc"], reverse=True) if a <= k and S["auc"][a].get(s)), None)
    pos = lambda d: max((i for i, x in enumerate(days) if x <= d.toordinal()), default=None)
    FN = []                                                   # per fortnight: (key, a, b, the 5 most bought, the 5 most sold)
    for k in F:
        e = dt.date.fromisoformat(k); st = (e.replace(day=1) if e.day == 15 else e.replace(day=16)) - dt.timedelta(days=1)
        a, b = pos(st), pos(e)
        if a is None or b is None or b - a < 5:
            continue
        R = sorted(((S["net"][k][s] / held(s, k), s) for s in IDX if S["net"][k].get(s) is not None and held(s, k)), reverse=True)
        if len(R) >= 8:
            q = 5 if len(R) >= 14 else 3
            FN.append((k, a, b, [s for _, s in R[:q]], [s for _, s in R[-q:]]))
    if len(FN) < 8:
        say("  ❌ only %d fortnights have both the report and prices - too few" % len(FN)); return
    av5 = lambda X, i, grp: sum(X[s][i] for s in grp) / len(grp)
    say("  %d fortnights (%s to %s) with prices · %d sectors · %d shares · sizes: %s" % (len(FN), FN[0][0], FN[-1][0], len(IDX), m, wsrc))
    say("")
    say("1) THE PATH - the sector against the market, the most bought sectors minus the most sold, stretch by stretch")
    say("    %-34s %9s %9s %11s   %s" % ("stretch", "bought", "sold", "difference", "bought ahead in"))
    seg = (("20 to 11 trading days BEFORE", lambda a, b: (a - 20, a - 10)), ("the 10 days BEFORE", lambda a, b: (a - 10, a)), ("the fortnight - first half", lambda a, b: (a, (a + b) // 2)),
           ("the fortnight - second half", lambda a, b: ((a + b) // 2, b)), ("days 1-5 AFTER it ends", lambda a, b: (b, b + 5)), ("days 6-10 after", lambda a, b: (b + 5, b + 10)),
           ("days 11-20 after", lambda a, b: (b + 10, b + 20)), ("days 21-40 after", lambda a, b: (b + 20, b + 40)))
    for name, fn in seg:
        T, B = [], []
        for k, a, b, top, bot in FN:
            x, y = fn(a, b)
            if x < 0 or y >= n or y <= x:
                continue
            T.append(sum(float(REL[s][x + 1:y + 1].sum()) for s in top) / len(top)); B.append(sum(float(REL[s][x + 1:y + 1].sum()) for s in bot) / len(bot))
        if len(T) < 8:
            say("    %-34s too few fortnights (%d)" % (name, len(T))); continue
        d_ = [t - b for t, b in zip(T, B)]; h = len(d_) // 2; av = lambda v: sum(v) / len(v)
        say("    %-34s %9s %9s %11s   %2d of %2d (%2d%%) · halves %s / %s" % (name, pc(av(T)), pc(av(B)), pc(av(d_)), sum(1 for v in d_ if v > 0), len(d_), 100 * sum(1 for v in d_ if v > 0) / len(d_), pc(av(d_[:h])), pc(av(d_[h:]))))
    say("    read it like this: a big difference BEFORE = the price moved first and the money followed · during = together · AFTER = still tradable")

    say("")
    say("1b) THE CLUE - half-way through a fortnight, BEFORE any report: take the sectors that did best / worst against the market in its FIRST half")
    hit, sec2, nxt = [], [], []
    for k, a, b, top, bot in FN:
        mid = (a + b) // 2; q = len(top)
        R1 = sorted(IDX, key=lambda s: -float(REL[s][a + 1:mid + 1].sum())); t1, b1 = R1[:q], R1[-q:]
        hit.append((len(set(t1) & set(top)) + len(set(b1) & set(bot))) / (2.0 * q))
        sec2.append(sum(float(REL[s][mid + 1:b + 1].sum()) for s in t1) / q - sum(float(REL[s][mid + 1:b + 1].sum()) for s in b1) / q)
        if b + 10 < n:
            nxt.append(sum(float(REL[s][b + 1:b + 11].sum()) for s in t1) / q - sum(float(REL[s][b + 1:b + 11].sum()) for s in b1) / q)
    av = lambda v: sum(v) / len(v) if v else float("nan"); h = len(sec2) // 2; q0 = len(FN[0][3])
    say("    does it name what they are buying? of the first-half leaders and laggards, %d%% turn out to be among the fortnight's most bought / most sold (by chance: %d%%)" % (
        round(100 * av(hit)), round(100.0 * q0 / len(IDX))))
    say("    do they go on? first-half leaders minus laggards: in the SECOND half %s (ahead in %d of %d, halves %s / %s) · in the 10 days after the fortnight %s (ahead in %d of %d)" % (
        pc(av(sec2)), sum(1 for v in sec2 if v > 0), len(sec2), pc(av(sec2[:h])), pc(av(sec2[h:])), pc(av(nxt)), sum(1 for v in nxt if v > 0), len(nxt)))
    say("    read it: a high first line = the price tells you early where the money is going · a plus on the second line = there is still something left to trade")
    say("")
    say("2) IN THE DAY - on the days of the fortnight, the bought sectors minus the sold ones, per day (in hundredths of a percent)")
    To, Ti = [], []
    for k, a, b, top, bot in FN:
        for i in range(a + 1, b + 1):
            To.append(av5(ROV, i, top) - av5(ROV, i, bot)); Ti.append(av5(RIN, i, top) - av5(RIN, i, bot))
    so, si = float(np.mean(To)), float(np.mean(Ti))
    say("    2 years of daily prices (%d days): OVERNIGHT (close → next open) %s · DAYTIME (open → close) %s%s" % (
        len(To), bp(so), bp(si), (" → %d%% of the bought sectors' lead is made in the daytime" % round(100 * si / (so + si))) if so > 0 and si > 0 else " → the two parts pull in different directions - no clean split"))
    FM = five_min(syms)
    if len(FM) < min(200, m // 2):
        say("    the 5-minute files (data/secstudy) are not there for enough shares (%d) - run sectorstudy.py once for the time-of-day split" % len(FM))
    else:
        d5 = sorted({d for v in FM.values() for d in v}); i5 = {d: i for i, d in enumerate(d5)}; n5 = len(d5)
        P = [np.full((n5, m), np.nan) for _ in range(4)]
        for s, v in FM.items():
            j = sj.get(s)
            if j is None:
                continue
            for d, t4 in v.items():
                for q in range(4):
                    P[q][i5[d], j] = t4[q]
        parts = {"the first hour (09:15-10:15)": P[1] / P[0] - 1, "the middle (10:15-14:15)": P[2] / P[1] - 1, "the last 75 minutes (14:15-15:30)": P[3] / P[2] - 1}
        acc = {k_: [] for k_ in parts}
        RP = {}
        for name, X in parts.items():
            X[np.abs(X) > 0.2] = np.nan
            mk_ = wm(X, allj); RP[name] = {s: wm(X, IDX[s]) - mk_ for s in IDX}
        for k, a, b, top, bot in FN:
            for i in range(a + 1, b + 1):
                x = i5.get(days[i])
                if x is None:
                    continue
                for name in parts:
                    acc[name].append(av5(RP[name], x, top) - av5(RP[name], x, bot))
        nd = len(next(iter(acc.values())))
        if nd < 30:
            say("    5-minute prices cover only %d days of these fortnights - too few for the time-of-day split" % nd)
        else:
            tot = sum(float(np.mean(v)) for v in acc.values())
            say("    Kite 5-minute prices (%d days, %s to %s):" % (nd, dt.date.fromordinal(d5[0]), dt.date.fromordinal(d5[-1])))
            for name, v in acc.items():
                mu = float(np.mean(v)); h = len(v) // 2
                say("      %-34s %s a day · bought ahead on %d%% of days · halves %s / %s%s" % (name, bp(mu), 100 * sum(1 for x in v if x > 0) / len(v), bp(float(np.mean(v[:h]))), bp(float(np.mean(v[h:]))),
                    (" · %d%% of the session's lead" % round(100 * mu / tot)) if tot > 0 and mu > 0 else ""))
    say("    (the newest fortnight's report comes late - on its days nobody yet knew which sectors were being bought: this shows WHEN it happens, not a signal)")

    say("")
    say("3) HOW LONG THEY KEEP GOING - a sector bought (or sold) for at least 0.1% of what they hold in a fortnight")
    sg = {}
    for k in F:
        for s in IDX:
            v, h = S["net"][k].get(s), held(s, k)
            sg[(k, s)] = 0 if v is None or not h or abs(v / h) < 0.001 else (1 if v > 0 else -1)
    for d_, name in ((1, "BOUGHT"), (-1, "SOLD")):
        nxt = [sg[(F[i + 1], s)] for i in range(len(F) - 1) for s in IDX if sg[(F[i], s)] == d_]
        runs = []
        for s in IDX:
            r = 0
            for k in F:
                if sg[(k, s)] == d_:
                    r += 1
                else:
                    if r:
                        runs.append(r)
                    r = 0
            if r:
                runs.append(r)
        if len(nxt) < 30:
            say("    %s: too few cases" % name); continue
        runs.sort()
        say("    %-6s %4d sector-fortnights · the next fortnight the same way %d%%, the other way %d%% · runs: half last %d fortnight(s) or less, %d%% reach 3, %d%% reach 6, the longest %d" % (
            name, len(nxt), 100 * sum(1 for x in nxt if x == d_) / len(nxt), 100 * sum(1 for x in nxt if x == -d_) / len(nxt), runs[len(runs) // 2], 100 * sum(1 for r in runs if r >= 3) / len(runs),
            100 * sum(1 for r in runs if r >= 6) / len(runs), runs[-1]))
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "flowpath.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/flowpath.txt")


if __name__ == "__main__":
    main()
