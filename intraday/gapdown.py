#!/usr/bin/env python3
"""gapdown.py - one setup, tested properly: BUY a liquid share that gaps DOWN sharply, sell by 15:15.

Entry variants (all realistic, no buying at the exact open):
  A  09:20 close (end of the first 5-min candle)
  B  09:20 close, only if the first 5-min candle is green
  C  09:30 close, only if price is above the 09:15-09:30 low by 0.3%+ (selling has paused)
Exit variants:
  hold   no stop, sell 15:15
  stop   stop 0.5% below the low of the morning so far (max 4% risk), else 15:15
  fill   as 'stop', but also sell at yesterday's close if reached (gap filled)
Costs 0.20% round trip. Liquidity: 20-day median daily turnover >= Rs 2 crore.
Also: a simple daily portfolio - each day buy the (up to) 3 deepest qualifying gaps, equal size.
Read-only.  python3 gapdown.py
"""
import os, sys, time, datetime as dt
import numpy as np
import core, getdata

COST = 0.20
EXIT = 71
MIN_TURN = 2e7


def series(sym):
    a = core.load_npz(sym)
    if a is None:
        return None
    m = core.to_matrix(a)
    if m is None or len(m["days"]) < 30:
        return None
    return m


def run_trade(h, l, c, j, entry, stop, target):
    for b in range(j + 1, EXIT + 1):
        if not np.isfinite(l[b]):
            continue
        if stop is not None and l[b] <= stop:
            return (stop / entry - 1) * 100 - COST
        if target is not None and h[b] >= target:
            return (target / entry - 1) * 100 - COST
    ex = c[EXIT]
    if not np.isfinite(ex):
        return None
    return (ex / entry - 1) * 100 - COST


def main():
    t0 = time.time()
    uni = getdata.load_universe() or []
    nif = series("NIFTY50")
    nday = {int(d): i for i, d in enumerate(nif["days"])}
    nprev = np.r_[np.nan, nif["C"][:-1, -1]]
    ngap = (nif["O"][:, 0] / nprev - 1) * 100
    days_all = [int(d) for d in nif["days"]]
    last20 = set(days_all[-20:])
    rows = []   # (day, sym, gap, variant, exit, ret, nifty_gap, prior5, rvol5)
    used = 0
    for e in uni:
        s = e["sym"]
        m = series(s)
        if m is None:
            continue
        O, H, L, C, V = m["O"], m["H"], m["L"], m["C"], m["V"]
        days = [int(d) for d in m["days"]]
        turn = np.nansum(np.nan_to_num(V) * np.nan_to_num(C), 1)
        prev = np.r_[np.nan, C[:-1, -1]]
        gap = (O[:, 0] / prev - 1) * 100
        v0 = np.nan_to_num(V[:, 0])
        for d in range(21, len(days)):
            g = gap[d]
            if not (np.isfinite(g) and g <= -3.0):
                continue
            if np.median(turn[d - 20:d]) < MIN_TURN:
                continue
            ni = nday.get(days[d])
            if ni is None:
                continue
            h, l, c = H[d], L[d], C[d]
            prior5 = (prev[d] / C[d - 5, -1] - 1) * 100 if np.isfinite(C[d - 5, -1]) else np.nan
            med = np.median(v0[d - 20:d])
            rvol5 = v0[d] / med if med > 0 else np.nan
            ctx = (ngap[ni], prior5, rvol5)
            # A: 09:20 close
            entries = [("A 09:20 close", 0, c[0])]
            if c[0] > O[d, 0]:
                entries.append(("B 09:20 close, green 1st candle", 0, c[0]))
            lo3 = np.nanmin(l[:3])
            if np.isfinite(c[2]) and c[2] >= lo3 * 1.003:
                entries.append(("C 09:30 close, selling paused", 2, c[2]))
            for name, j, px in entries:
                if not (np.isfinite(px) and px > 0):
                    continue
                mlow = np.nanmin(l[:j + 1])
                stop = max(mlow * 0.995, px * 0.96)
                for ex_name, st, tg in (("hold", None, None), ("stop", stop, None), ("fill", stop, prev[d])):
                    r = run_trade(h, l, c, j, px, st, tg if (tg is not None and tg > px) else None)
                    if r is not None:
                        rows.append((days[d], s, g, name, ex_name, r) + ctx)
        used += 1
        if used % 300 == 0:
            print("  %d shares · %.0f s" % (used, time.time() - t0))
    if not rows:
        print("no qualifying gap-downs")
        return
    import collections
    day_ = np.array([r[0] for r in rows]); gap_ = np.array([r[2] for r in rows])
    var_ = np.array([r[3] for r in rows]); ex_ = np.array([r[4] for r in rows]); ret = np.array([r[5] for r in rows])
    ng_ = np.array([r[6] for r in rows]); p5_ = np.array([r[7] for r in rows]); rv_ = np.array([r[8] for r in rows])
    sym_ = np.array([r[1] for r in rows])
    d0, d1 = dt.date.fromordinal(days_all[0] + 719163), dt.date.fromordinal(days_all[-1] + 719163)
    out = ["GAP-DOWN BUY TEST — %d shares · %s to %s · liquid (≥₹2 cr/day) · costs %.2f%% · entry 09:20/09:30, exit 15:15" % (used, d0, d1, COST), ""]

    def line(name, k):
        r = ret[k]
        if len(r) < 10:
            return "   %-46s %5d trades (too few)" % (name, len(r))
        return "   %-46s %5d  win %3.0f%%  avg %+.2f%%  median %+.2f%%  worst 5%% %+.1f%%" % (
            name, len(r), 100 * (r > 0).mean(), r.mean(), np.median(r), np.percentile(r, 5))

    base_v, base_x = "A 09:20 close", "stop"
    out.append("1) ENTRY × EXIT (gap ≤ −4%)")
    for v in ("A 09:20 close", "B 09:20 close, green 1st candle", "C 09:30 close, selling paused"):
        for x in ("hold", "stop", "fill"):
            out.append(line("%s · %s" % (v, x), (var_ == v) & (ex_ == x) & (gap_ <= -4)))
    out.append("")
    out.append("2) GAP SIZE (entry A, exit stop)")
    for lo, hi, nm in ((-4, -3, "−3 to −4%"), (-6, -4, "−4 to −6%"), (-10, -6, "−6 to −10%"), (-99, -10, "≤ −10%")):
        out.append(line(nm, (var_ == base_v) & (ex_ == base_x) & (gap_ <= hi) & (gap_ > lo)))
    out.append("")
    k4 = (var_ == base_v) & (ex_ == base_x) & (gap_ <= -4)
    out.append("3) CONTEXT (gap ≤ −4%, entry A, exit stop)")
    out.append(line("Nifty also gapped down ≤ −0.7% (market-wide)", k4 & (ng_ <= -0.7)))
    out.append(line("Nifty did NOT gap down (share-specific)", k4 & (ng_ > -0.7)))
    out.append(line("share already fell ≥5% in the 5 days before", k4 & (p5_ <= -5)))
    out.append(line("share was flat/up in the 5 days before", k4 & (p5_ > -5)))
    out.append(line("first 5-min volume ≥ 5x normal (heavy news-type selling)", k4 & (rv_ >= 5)))
    out.append(line("first 5-min volume < 5x normal", k4 & (rv_ < 5)))
    out.append("")
    out.append("4) STABILITY BY HALF-YEAR (gap ≤ −4%, entry A, exit stop)")
    for y in range(d0.year, d1.year + 1):
        for hlf, (m0, m1) in ((1, (1, 6)), (2, (7, 12))):
            a = dt.date(y, m0, 1).toordinal() - 719163
            b = dt.date(y, m1, 28).toordinal() - 719163 + 3
            k = k4 & (day_ >= a) & (day_ <= b)
            if k.sum():
                out.append(line("%d H%d" % (y, hlf), k))
    out.append(line("last 20 sessions", k4 & np.isin(day_, list(last20))))
    out.append("")
    # daily portfolio: up to 3 deepest gaps per day, entry A, exit stop, equal weight
    out.append("5) DAILY DESK (each day: up to 3 deepest qualifying gaps ≤ −4%, entry A, exit stop, equal size)")
    byday = collections.defaultdict(list)
    for i in np.nonzero(k4 & (ng_ > -0.7) & (rv_ < 5))[0]:
        byday[int(day_[i])].append((gap_[i], ret[i]))
    dr = []
    for dd in sorted(byday):
        picks = sorted(byday[dd])[:3]
        dr.append(np.mean([p[1] for p in picks]))
    if dr:
        dr = np.array(dr)
        eq = np.cumsum(dr)
        dd_ = (eq - np.maximum.accumulate(eq)).min()
        out.append("   filters: share-specific gap (Nifty not gapping down), first-5-min volume < 5x")
        out.append("   %d trading days with a trade (of %d) · green days %.0f%% · avg day %+.2f%% · sum %+.1f%% · worst day %+.1f%% · deepest drawdown %+.1f%%" % (
            len(dr), len(days_all), 100 * (dr > 0).mean(), dr.mean(), dr.sum(), dr.min(), dd_))
        out.append("   per ₹1 lakh per trade: avg day ₹%+.0f, total ₹%+.0f" % (dr.mean() * 1000, dr.sum() * 1000))
    out.append("")
    out.append("Note: only shares in today's universe are tested (survivorship bias flatters gap-down buying a little).")
    txt = "\n".join(out)
    print("\n" + txt)
    open(os.path.join(core.BASE, "gapdown.txt"), "w").write(txt + "\n")
    print("\nsaved gapdown.txt · %.0f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
