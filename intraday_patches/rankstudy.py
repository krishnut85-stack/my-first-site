#!/usr/bin/env python3
"""rankstudy.py - READ ONLY. WHICH SECTOR RANKING IS THE BELIEVABLE ONE? (Rama, 17 Nov: "it has to show the real picture - to know which sector is
moving ... the sector ranking is one of the main criteria for the share selection ... work out and confirm the believable sector ranking")
GIR ranks a sector by all its NSE shares weighted by SIZE; other sites use a PLAIN AVERAGE - and the two lists can look very different (one giant
share can carry a sector by size; a crowd of small shares can carry it on a plain average). This does not argue - it tests, on every day of Kite's
5-minute prices that GIR keeps (data/secstudy), with the sectors ranked at 09:45 and at 10:00 in SIX ways:
  BY SIZE          every share weighted by its market value (GIR's page today)
  SIZE, CAPPED     the same, but no one share may count for more than 20% of its sector
  PLAIN AVERAGE    every share counts the same
  MIDDLE SHARE     the middle one of the sector's shares (the median) - a few wild shares cannot move it
  UP MINUS DOWN    how many of its shares are up, less how many are down
  F&O SHARES ONLY  the plain average of only its F&O shares (sectors with 3 or more)
and asks of each:
  1 HOW FAR APART   sector by sector: how much of it is one share, how far the by-size figure sits from the plain average, how often they point
                    opposite ways
  2 DOES IT HOLD    is the rank at that time still the rank at 15:10 (the same way of ranking)?
  3 THE SECTOR      do the 3 strongest keep rising against the market for the rest of the day, the 3 weakest keep falling?
  4 THE SHARES      what you trade: the F&O shares (already moving that way) of the 3 strongest / 3 weakest sectors that have F&O shares -
                    their move from then to 15:10, against ANY F&O share already moving that way. The edge is what the ranking added.
  5 HEAD TO HEAD    on the days BY SIZE and PLAIN AVERAGE name different sectors: whose shares did better?
  6 ONE BIG SHARE   when one share makes half or more of a by-size sector's move: do its OTHER F&O shares follow?
✔ = the edge is at least 0.10%, the same sign in both halves of the days, 150+ cases. Yesterday's close is the last 5-minute price of the day
before in the same file, so nothing is fetched - no Kite call, safe to run at any hour. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && nice -n 15 python3 rankstudy.py   -> prints, saves data/rankstudy.txt"""
import os, re, sys, json, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)
av = lambda v: sum(v) / len(v) if v else float("nan")
TS = (("09:45", 30), ("10:00", 45))                                  # minutes after 09:15
WAYS = ("BY SIZE", "SIZE, CAPPED", "PLAIN AVERAGE", "MIDDLE SHARE", "UP MINUS DOWN", "F&O SHARES ONLY")


def say(s=""):
    L.append(s); print(s, flush=True)


def scan(path):
    """one share's 5-minute file -> {day: (yesterday's last price, price at 09:45, at 10:00, at 15:10)}"""
    try:
        A = np.load(path)
    except Exception:
        return {}
    if A.ndim != 2 or A.shape[1] < 7 or not len(A):
        return {}
    out = {}; prev = None
    for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
        mn = p[:, 1]; day = int(p[0, 0]); late = p[mn <= 350]
        if prev and len(p) >= 60 and len(late) >= 40 and mn[0] <= 10 and day - prev[0] <= 5:
            px = []
            for _, T in TS:
                a = p[mn <= T - 5]; px.append(float(a[-1, 5]) if len(a) >= 3 else float("nan"))
            out[day] = (prev[1], px[0], px[1], float(late[-1, 5]))
        prev = (day, float(p[-1, 5])) if len(p) >= 60 else None
    return out


def score(v, way):
    """v: the sector's shares [(sym, move, size, is F&O)] -> its figure that way (None = cannot be ranked that way)"""
    x = np.array([r[1] for r in v]); w = np.array([r[2] for r in v])
    if way == "BY SIZE":
        return float((x * w).sum() / w.sum())
    if way == "SIZE, CAPPED":
        c = np.minimum(w, 0.20 * w.sum()); return float((x * c).sum() / c.sum())
    if way == "PLAIN AVERAGE":
        return float(x.mean())
    if way == "MIDDLE SHARE":
        return float(np.median(x))
    if way == "UP MINUS DOWN":
        return float(((x > 0).sum() - (x < 0).sum()) / len(x)) + float(x.mean()) * 1e-3     # the plain average only breaks a tie
    f = np.array([r[1] for r in v if r[3]])
    return float(f.mean()) if len(f) >= 3 else None


def spearman(a, b):
    ra, rb = np.argsort(np.argsort(a)), np.argsort(np.argsort(b))
    return float(np.corrcoef(ra, rb)[0, 1]) if len(a) >= 5 else float("nan")


def main():
    import seclive as SL
    say("📊 WHICH SECTOR RANKING IS THE BELIEVABLE ONE? · Kite 5-minute prices, every day kept · six ways of ranking, tested at 09:45 and 10:00 against what happened to 15:10")
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    I = {}
    for s in SEC:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if b and (W.get(s) or not W):
            d = scan(os.path.join(C, b[1]))
            if d:
                I[s] = d
    if len(I) < 100:
        say("  ❌ 5-minute files for only %d shares in data/secstudy - run sectorstudy.py once (it fetches and keeps them)" % len(I)); return
    days = sorted({d for v in I.values() for d in v})
    days = [d for d in days if sum(1 for s in I if d in I[s]) >= 200]
    if len(days) < 30:
        say("  ❌ only %d days with 200+ shares - too few to say anything" % len(days)); return
    mid = days[len(days) // 2]
    say("  %d days (%s to %s) · %d shares with 5-minute prices, %d of them F&O · sizes: %s" % (len(days), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), len(I), sum(1 for s in I if s in FO), wsrc))
    # ---------------------------------------------------------------- 1 HOW FAR APART (at 10:00)
    members = {}
    for s in I:
        members.setdefault(SEC[s], []).append(s)
    gap = {}
    for d in days:
        G = {}
        for s in I:
            r = I[s].get(d)
            if r and r[2] == r[2] and abs(r[2] / r[0] - 1) < 0.2:
                G.setdefault(SEC[s], []).append((s, r[2] / r[0] - 1, W.get(s) or 1.0, s in FO))
        for k, v in G.items():
            if len(v) >= 5:
                a, b = score(v, "BY SIZE"), score(v, "PLAIN AVERAGE")
                gap.setdefault(k, []).append((abs(a - b), 1 if a * b < 0 and min(abs(a), abs(b)) >= 0.001 else 0))
    say(""); say("1 HOW FAR APART ARE 'BY SIZE' AND 'PLAIN AVERAGE'? (at 10:00, every day) - the sectors where one share is most of the size come first")
    say("    %-26s %4s %4s │ %-13s %5s │ %6s │ %9s │ %s" % ("sector", "all", "F&O", "biggest share", "of it", "top 3", "apart", "opposite ways"))
    rows = []
    for k, m in members.items():
        if k not in gap:
            continue
        m = sorted(m, key=lambda s: -(W.get(s) or 1.0)); tot = sum(W.get(s) or 1.0 for s in m); g = gap[k]
        rows.append((k, len(m), sum(1 for s in m if s in FO), m[0], (W.get(m[0]) or 1.0) / tot, sum(W.get(s) or 1.0 for s in m[:3]) / tot, av([x[0] for x in g]), av([x[1] for x in g])))
    for r in sorted(rows, key=lambda r: -r[4]):
        say("    %-26s %4d %4d │ %-13s %4.0f%% │ %5.0f%% │ %8.2f%% │ %3.0f%% of days %s" % (r[0][:26], r[1], r[2], r[3][:13], 100 * r[4], 100 * r[5], 100 * r[6], 100 * r[7], "◀ one share is half the sector" if r[4] >= 0.5 else ""))
    say("    'apart' = the usual distance between the two figures at 10:00 · 'opposite ways' = one says up and the other says down (each by 0.10%+)")
    VERD = {}
    for hm, ti in (("09:45", 1), ("10:00", 2)):
        say(""); say("═" * 150); say("RANKED AT %s" % hm)
        hold = {w: [] for w in WAYS}; goes = {w: [] for w in WAYS}; pool = {w: {1: [], -1: []} for w in WAYS}; base = {1: [], -1: []}
        h2h = {"size": {1: [], -1: []}, "plain": {1: [], -1: []}}; same3 = []; one = {"one": {1: [], -1: []}, "broad": {1: [], -1: []}, "lead": {1: [], -1: []}}
        for d in days:
            G = {}; mvall = []; restall = []
            for s in I:
                r = I[s].get(d)
                if not r or r[ti] != r[ti] or abs(r[ti] / r[0] - 1) >= 0.2:
                    continue
                x, rest = r[ti] / r[0] - 1, r[3] / r[ti] - 1
                G.setdefault(SEC[s], []).append((s, x, W.get(s) or 1.0, s in FO, rest, r[3] / r[0] - 1)); restall.append(rest)
                if s in FO:
                    for dr in (1, -1):
                        if x * dr > 0:
                            base[dr].append((d, rest * dr))
            G = {k: v for k, v in G.items() if len(v) >= 5}
            if len(G) < 10:
                continue
            mrest = av(restall); picks = {}
            for way in WAYS:
                sc = {k: score(v, way) for k, v in G.items()}; sc = {k: x for k, x in sc.items() if x is not None}
                if len(sc) < 6:
                    continue
                order = sorted(sc, key=lambda k: -sc[k]); ks = list(sc)
                end = {k: score([(r[0], r[5], r[2], r[3]) for r in G[k]], way) for k in ks}
                oe = sorted(ks, key=lambda k: -end[k])
                hold[way].append((d, spearman([sc[k] for k in ks], [end[k] for k in ks]), len(set(order[:3]) & set(oe[:3])), len(set(order[-3:]) & set(oe[-3:])), 1 if order[0] in oe[:3] else 0))
                srest = lambda k: av([r[4] for r in G[k]]) - mrest                    # the sector's rest of the day against the market - every share counts the same
                goes[way].append((d, av([srest(k) for k in order[:3]]), av([srest(k) for k in order[-3:]])))
                picks[way] = {}
                for dr, od in ((1, order), (-1, order[::-1])):
                    pk = [k for k in od if sc[k] * dr > 0 and any(r[3] and r[1] * dr > 0 for r in G[k])][:3]; picks[way][dr] = pk
                    for k in pk:
                        for r in G[k]:
                            if r[3] and r[1] * dr > 0:
                                pool[way][dr].append((d, r[4] * dr))
            if "BY SIZE" in picks and "PLAIN AVERAGE" in picks:
                for dr in (1, -1):
                    a, b = picks["BY SIZE"][dr], picks["PLAIN AVERAGE"][dr]
                    if dr > 0:
                        same3.append(len(set(a) & set(b)) / 3.0 if len(a) == 3 and len(b) == 3 else float("nan"))
                    for nm, only in (("size", [k for k in a if k not in b]), ("plain", [k for k in b if k not in a])):
                        for k in only:
                            for r in G[k]:
                                if r[3] and r[1] * dr > 0:
                                    h2h[nm][dr].append((d, r[4] * dr))
                    for k in a:                                                        # 6: is this by-size sector one big share?
                        v = G[k]; tot = sum(r[1] * r[2] for r in v); lead = max(v, key=lambda r: r[1] * r[2] * dr)
                        part = lead[1] * lead[2] / tot if tot else 0
                        for r in v:
                            if r[3] and r[1] * dr > 0:
                                if part >= 0.5 and r[0] == lead[0]:
                                    one["lead"][dr].append((d, r[4] * dr))
                                else:
                                    one["one" if part >= 0.5 else "broad"][dr].append((d, r[4] * dr))
        # ------------------------------------------------------------ 2 DOES IT HOLD
        say(""); say("2 DOES THE RANK AT %s HOLD TO 15:10? (each way against itself · 1.00 = the same order, 0 = no link)" % hm)
        say("    %-16s │ %-14s │ %-24s │ %-24s │ %s" % ("way of ranking", "order kept", "top 3 still top 3", "bottom 3 still bottom 3", "the No.1 ends in the top 3"))
        for way in WAYS:
            h = hold[way]
            if h:
                say("    %-16s │ %5.2f          │ %4.1f of 3                │ %4.1f of 3                │ %3.0f%% of days" % (way, av([x[1] for x in h if x[1] == x[1]]), av([x[2] for x in h]), av([x[3] for x in h]), 100 * av([x[4] for x in h])))
        # ------------------------------------------------------------ 3 THE SECTOR GOES ON?
        say(""); say("3 AFTER %s - DO THE 3 STRONGEST SECTORS KEEP GAINING ON THE MARKET, THE 3 WEAKEST KEEP LOSING? (to 15:10, all the sector's shares, each counted the same)" % hm)
        say("    %-16s │ %-10s │ %-10s │ %-28s │ %s" % ("way of ranking", "strongest 3", "weakest 3", "strongest less weakest", "days it was the right way"))
        for way in WAYS:
            g = goes[way]
            if g:
                sp = [x[1] - x[2] for x in g]; s1, s2 = av([x[1] - x[2] for x in g if x[0] < mid]), av([x[1] - x[2] for x in g if x[0] >= mid])
                say("    %-16s │ %s     │ %s    │ %s (halves %s / %s) │ %3.0f%% %s" % (way, pc(av([x[1] for x in g])), pc(av([x[2] for x in g])), pc(av(sp)), pc(s1), pc(s2), 100 * av([1 if x > 0 else 0 for x in sp]),
                                                                              "✔" if s1 * s2 > 0 and av(sp) >= 0.001 else "✘ went the other way" if av(sp) <= -0.001 and s1 * s2 > 0 else "✘"))
        # ------------------------------------------------------------ 4 THE SHARES
        res = {}
        for dr, title in ((1, "CE - the F&O shares, already up, of the 3 STRONGEST sectors that have F&O shares"), (-1, "PE - the F&O shares, already down, of the 3 WEAKEST sectors that have F&O shares")):
            B = base[dr]; b0, b1, b2 = av([x[1] for x in B]), av([x[1] for x in B if x[0] < mid]), av([x[1] for x in B if x[0] >= mid])
            say(""); say("4 THE SHARES · %s · ranked at %s, held to 15:10" % (title, hm))
            say("    %-16s %6s cases │ to 15:10 %s  %s its way │ %s" % ("ANY F&O share", len(B), pc(b0), "%2.0f%%" % (100 * av([1 if x[1] > 0 else 0 for x in B])), "the yardstick - no sector chosen at all"))
            for way in WAYS:
                X = pool[way][dr]
                if len(X) < 40:
                    say("    %-16s %6d cases - too few" % (way, len(X))); continue
                e, e1, e2 = av([x[1] for x in X]) - b0, av([x[1] for x in X if x[0] < mid]) - b1, av([x[1] for x in X if x[0] >= mid]) - b2
                ok = len(X) >= 150 and e1 * e2 > 0 and abs(e) >= 0.001 and min(abs(e1), abs(e2)) >= 0.0005
                res[(way, dr)] = (e, e1, e2, ok, len(X))
                say("    %-16s %6d cases │ to 15:10 %s  %2.0f%% its way │ edge %s (halves %s / %s) %s" % (way, len(X), pc(av([x[1] for x in X])), 100 * av([1 if x[1] > 0 else 0 for x in X]), pc(e), pc(e1), pc(e2),
                                                                                                    ("✔" if e > 0 else "✘ steadily WORSE than no sector") if ok else "✘ steady but under 0.10%" if e1 * e2 > 0 and len(X) >= 150 else "✘ not steady"))
        VERD[hm] = res
        # ------------------------------------------------------------ 5 HEAD TO HEAD
        s3 = [x for x in same3 if x == x]
        say(""); say("5 HEAD TO HEAD at %s · BY SIZE and PLAIN AVERAGE name the same 3 strongest on %.0f%% of days · on average %.1f of the 3 are the same" % (hm, 100 * av([1 if x > 0.99 else 0 for x in s3]), 3 * av(s3)))
        for dr, nm in ((1, "CE"), (-1, "PE")):
            a, b = h2h["size"][dr], h2h["plain"][dr]
            if len(a) < 40 or len(b) < 40:
                say("    %s: too few cases where they differ (%d / %d)" % (nm, len(a), len(b))); continue
            f = lambda X: (av([x[1] for x in X]), av([x[1] for x in X if x[0] < mid]), av([x[1] for x in X if x[0] >= mid]))
            A, B = f(a), f(b); dfr = (A[0] - B[0], A[1] - B[1], A[2] - B[2])
            say("    %s · sectors ONLY BY SIZE picked:        %5d cases │ to 15:10 %s (halves %s / %s)" % (nm, len(a), pc(A[0]), pc(A[1]), pc(A[2])))
            say("    %s · sectors ONLY PLAIN AVERAGE picked:  %5d cases │ to 15:10 %s (halves %s / %s)" % (nm, len(b), pc(B[0]), pc(B[1]), pc(B[2])))
            few = min(len(a), len(b)) < 150; mark = "but only %d cases - a lean, not a proof" % min(len(a), len(b)) if few else "✔"
            say("    %s · → %s" % (nm, ("BY SIZE's own picks did better by %s - in both halves %s" % (pc(dfr[0]), mark)) if dfr[1] > 0 and dfr[2] > 0 and dfr[0] >= 0.001 else
                                  ("PLAIN AVERAGE's own picks did better by %s - in both halves %s" % (pc(-dfr[0]), mark)) if dfr[1] < 0 and dfr[2] < 0 and dfr[0] <= -0.001 else "no steady difference between the two (%s, halves %s / %s) ✘" % (pc(dfr[0]), pc(dfr[1]), pc(dfr[2]))))
        # ------------------------------------------------------------ 6 ONE BIG SHARE
        say(""); say("6 ONE BIG SHARE at %s · a by-size top / bottom sector where ONE share makes half or more of the sector's move" % hm)
        for dr, nm in ((1, "CE"), (-1, "PE")):
            for key, txt in (("lead", "that big share itself"), ("one", "the OTHER F&O shares of that sector"), ("broad", "F&O shares of sectors moved by many shares")):
                X = one[key][dr]
                if len(X) < 30:
                    say("    %s · %-44s %5d cases - too few" % (nm, txt, len(X))); continue
                say("    %s · %-44s %5d cases │ to 15:10 %s  %2.0f%% its way (halves %s / %s)" % (nm, txt, len(X), pc(av([x[1] for x in X])), 100 * av([1 if x[1] > 0 else 0 for x in X]), pc(av([x[1] for x in X if x[0] < mid])), pc(av([x[1] for x in X if x[0] >= mid]))))
    # ---------------------------------------------------------------- THE VERDICT
    say(""); say("═" * 150); say("THE VERDICT - what ranking the sectors added to the share selection (part 4), each way, both times")
    say("    %-16s │ %-31s │ %-31s │ %s" % ("way of ranking", "CE  09:45 · 10:00", "PE  09:45 · 10:00", "steady ✔ out of 4"))
    tot = {}
    for way in WAYS:
        c = []; n = 0; sm = 0.0
        for dr in (1, -1):
            for hm in ("09:45", "10:00"):
                r = VERD.get(hm, {}).get((way, dr))
                c.append("%s%s" % (pc(r[0]), "✔" if r[3] and r[0] > 0 else "✘") if r else "  n/a  "); n += 1 if r and r[3] and r[0] > 0 else 0; sm += r[0] if r else 0
        tot[way] = (n, sm)
        say("    %-16s │ %-15s %-15s │ %-15s %-15s │ %d" % (way, c[0], c[1], c[2], c[3], n))
    bestw = max(tot, key=lambda w: tot[w]); n, sm = tot[bestw]
    if n == 0:
        say("  → NO way of ranking the sectors gave the share selection a steady edge on these days. The sector rank is then a picture of the day, not a signal - the tested marks on the share itself carry the edge.")
    else:
        say("  → the most believable for picking shares on these days: %s (steady in %d of the 4 tests)%s" % (bestw, n, "" if bestw == "BY SIZE" else " · GIR's page ranks BY SIZE today"))
    try:
        open(os.path.join(D, "data", "rankstudy.txt"), "w").write("\n".join(L) + "\n")
        json.dump({"at": str(dt.datetime.now())[:16], "days": len(days), "best": bestw if n else None, "ways": {w: {"steady": tot[w][0]} for w in WAYS},
                   "edge": {hm: {"%s|%s" % (w, "CE" if dr > 0 else "PE"): [round(100 * r[0], 3), bool(r[3])] for (w, dr), r in VERD[hm].items()} for hm in VERD}}, open(os.path.join(D, "data", "rankstudy.json"), "w"))
        say("  saved: data/rankstudy.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
