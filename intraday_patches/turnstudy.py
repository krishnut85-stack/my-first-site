#!/usr/bin/env python3
"""turnstudy.py - READ ONLY. A LEADING SECTOR TURNS OVER - IS THE PE WORTH IT? (Rama, 17 Nov 15:00: "capital markets went from high to low today -
ANGELONE fell from +8% to +1%, KFINTECH from +5% to +2% - all made money in PE, we missed that too. A sector going from the best performing to the
worst on a day can make money in PE").
On every day of Kite's 5-minute prices that GIR keeps (data/secstudy), each sector by size (all its NSE shares, like the SECTORS box):
  THE TURN DOWN  the sector was up 1.5%+ at its high of the day and among the 3 strongest then · it has now given back G from that high
                 (G = 0.75% / 1% / 1.5%, each tested) · 70%+ of its shares fell over the last 30 minutes · from 10:30 to 14:30, once a sector a day
  THE TURN UP    the mirror: a sector down 1.5%+ at its low and among the 3 weakest, now G back up, 70%+ of its shares rising -> CE
  THE TRADE      its F&O shares already moving the new way at that moment: their move to 15:10 the new way, how often +1.5% before -1%
                 ("worked"), against ANY F&O share already moving that way at the same 5-minute mark (the yardstick)
✔ = beats the yardstick by 0.10%+ in BOTH halves of the days, with 40+ share cases. Orders nothing, no Kite call.
  cd /home/globalbot/intraday && nice -n 15 python3 turnstudy.py      -> prints, saves data/turnstudy.txt"""
import os, re, sys, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
END = 70                                                     # the 5-minute bar that closes at 15:10


def say(s=""):
    L.append(s); print(s, flush=True)


def load():
    import seclive as SL
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    P = {}
    for s in SEC:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b or (W and not W.get(s)):
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 7 or not len(A):
            continue
        prev = None; d_ = {}
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            day = int(p[0, 0]); cl = np.full(72, np.nan); hi = np.full(72, np.nan); lo = np.full(72, np.nan)
            for row in p:
                k = int(row[1]) // 5
                if 0 <= k < 72:
                    cl[k], hi[k], lo[k] = row[5], row[3], row[4]
            for k in range(1, 72):
                if cl[k] != cl[k]:
                    cl[k], hi[k], lo[k] = cl[k - 1], cl[k - 1], cl[k - 1]
            if prev is not None and day - prev[0] <= 5 and np.isfinite(cl).all():
                d_[day] = (prev[1], cl, hi, lo)
            if np.isfinite(cl).sum() >= 60:
                prev = (day, float(cl[np.isfinite(cl)][-1]))
        if d_:
            P[s] = d_
    return SEC, FO, W, wsrc, P


def worked(hi, lo, b, px, dr):
    fav = (hi[b + 1:END + 1] / px - 1) * dr if dr > 0 else (lo[b + 1:END + 1] / px - 1) * dr
    adv = (lo[b + 1:END + 1] / px - 1) * dr if dr > 0 else (hi[b + 1:END + 1] / px - 1) * dr
    f = np.flatnonzero(fav >= 0.015); s_ = np.flatnonzero(adv <= -0.01)
    return 1 if len(f) and (not len(s_) or f[0] < s_[0]) else 0


def main():
    SEC, FO, W, wsrc, P = load()
    if len(P) < 100:
        say("❌ 5-minute files for only %d shares in data/secstudy - run sectorstudy.py once" % len(P)); return
    days = sorted({d for v in P.values() for d in v}); days = [d for d in days if sum(1 for s in P if d in P[s]) >= 200]
    say("📊 A LEADING SECTOR TURNS OVER - IS THE PE WORTH IT? (and the weakest turning up - the CE) · %d days (%s to %s) · %d shares · sizes: %s" % (
        len(days), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), len(P), wsrc))
    if len(days) < 20:
        say("  ❌ too few days"); return
    mid = days[len(days) // 2]; av = lambda v: sum(v) / len(v) if v else float("nan")
    EV = {g: [] for g in (0.0075, 0.01, 0.015)}; Y = {}
    for d in days:
        G = {}
        for s in P:
            if d in P[s]:
                pc, cl, hi, lo = P[s][d]
                if pc > 0:
                    G.setdefault(SEC[s], []).append((s, pc, cl, hi, lo, W.get(s) or 1.0, s in FO))
        G = {k: v for k, v in G.items() if len(v) >= 5}
        if len(G) < 10:
            continue
        IX = {}
        for k, v in G.items():                                   # the sector's % today at every 5-minute mark, by size
            w = np.array([x[5] for x in v]); cl = np.array([x[2] for x in v]); pc = np.array([x[1] for x in v])
            IX[k] = (w[:, None] * (cl / pc[:, None] - 1)).sum(0) / w.sum()
        for b in range(5, 69, 1):                                # the yardstick: any F&O share already moving 0.5%+ that way at this mark
            for k, v in G.items():
                for s, pc, cl, hi, lo, w, fo in v:
                    if fo:
                        m0 = cl[b] / pc - 1
                        if abs(m0) >= 0.005:
                            dr = 1 if m0 > 0 else -1
                            Y.setdefault((d, b, dr), []).append((cl[END] / cl[b] - 1) * dr)
        for g in EV:
            done = set()
            for b in range(15, 63):                              # 10:30 ... 14:30
                ranks_hi = {}
                for k in IX:
                    for dr in (-1, 1):                           # dr = the NEW way: -1 = turned down (PE), +1 = turned up (CE)
                        if (k, dr) in done:
                            continue
                        path = IX[k][:b + 1]
                        if dr < 0:
                            j = int(np.argmax(path)); ext = path[j]
                            if ext < 0.015 or path[-1] > ext - g:
                                continue
                            rk = sorted(IX, key=lambda q: -IX[q][j]).index(k)
                        else:
                            j = int(np.argmin(path)); ext = path[j]
                            if ext > -0.015 or path[-1] < ext + g:
                                continue
                            rk = sorted(IX, key=lambda q: IX[q][j]).index(k)
                        if rk > 2:
                            continue
                        mv30 = [(x[2][b] / x[2][b - 6] - 1) * dr for x in G[k]]
                        if np.mean([1 if m > 0 else 0 for m in mv30]) < 0.7:
                            continue
                        done.add((k, dr))
                        for s, pc, cl, hi, lo, w, fo in G[k]:
                            if fo and (cl[b] / cl[b - 6] - 1) * dr > 0:
                                yb = Y.get((d, b, dr))
                                EV[g].append({"d": d, "b": b, "dr": dr, "sec": k, "s": s, "mv": (cl[END] / cl[b] - 1) * dr, "w": worked(hi, lo, b, cl[b], dr),
                                              "e": (cl[END] / cl[b] - 1) * dr - (av(yb) if yb else 0.0), "ext": ext, "t": "%02d:%02d" % divmod(555 + 5 * (b + 1), 60)})
    say("  how to read: 'to 15:10' = the share's move the NEW way from the turn · 'worked' = +1.5% the new way before -1% against · 'edge' = against ANY F&O share")
    say("  already moving that way at the same 5-minute mark · ✔ = edge 0.10%+ in both halves of the days, 40+ cases")
    for dr, nm in ((-1, "THE TURN DOWN - a leading sector rolls over -> PE on its falling F&O shares"), (1, "THE TURN UP - the weakest sector turns up -> CE on its rising F&O shares")):
        say(""); say(nm)
        for g in sorted(EV):
            X = [e for e in EV[g] if e["dr"] == dr]
            if len(X) < 10:
                say("    given back %.2f%%: %d cases - too few" % (100 * g, len(X))); continue
            e1, e2 = av([e["e"] for e in X if e["d"] < mid]), av([e["e"] for e in X if e["d"] >= mid])
            ok = len(X) >= 40 and e1 == e1 and e2 == e2 and e1 >= 0.001 and e2 >= 0.001
            say("    given back %.2f%%: %4d share cases on %2d days (%d sector turns) │ to 15:10 %+.2f%% · its way %3.0f%% · worked %3.0f%% │ edge %+.2f%% (halves %+.2f%% / %+.2f%%) %s" % (
                100 * g, len(X), len({e["d"] for e in X}), len({(e["d"], e["sec"]) for e in X}), 100 * av([e["mv"] for e in X]), 100 * av([1 if e["mv"] > 0 else 0 for e in X]),
                100 * av([e["w"] for e in X]), 100 * av([e["e"] for e in X]), 100 * e1, 100 * e2, "✔" if ok else "✘"))
        X = [e for e in EV[0.01] if e["dr"] == dr]
        if X:
            for nm2, f in (("turned before 12:30", lambda e: e["t"] < "12:30"), ("turned 12:30 or later", lambda e: e["t"] >= "12:30"),
                           ("from a big day (2.5%+ at the extreme)", lambda e: abs(e["ext"]) >= 0.025), ("from 1.5-2.5%", lambda e: abs(e["ext"]) < 0.025)):
                Z = [e for e in X if f(e)]
                if len(Z) >= 10:
                    say("      (1%%) %-38s %4d │ to 15:10 %+.2f%% · its way %3.0f%% · worked %3.0f%% │ edge %+.2f%%" % (nm2, len(Z), 100 * av([e["mv"] for e in Z]),
                        100 * av([1 if e["mv"] > 0 else 0 for e in Z]), 100 * av([e["w"] for e in Z]), 100 * av([e["e"] for e in Z])))
            last = sorted({(e["d"], e["sec"], e["t"]) for e in X})[-6:]
            say("      the last turns: " + " · ".join("%s %s %s" % (dt.date.fromordinal(d_).strftime("%d %b"), t_, s_) for d_, s_, t_ in last))
    try:
        open(os.path.join(D, "data", "turnstudy.txt"), "w").write("\n".join(L) + "\n"); say("  saved: data/turnstudy.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
