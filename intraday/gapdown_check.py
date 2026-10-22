#!/usr/bin/env python3
"""gapdown_check.py - stress-test the one result that looked good in gapdown.txt.

gapdown.txt found: share gaps <= -4% on a day Nifty also gaps <= -0.7%,
buy at the 09:20 close, stop 0.5% under the morning low, sell 15:15
-> 252 trades, 61% win, +1.26% a trade.

Two questions decide whether that is usable:
  1. Is it spread over many days and periods, or mostly one crash?
     Market-wide gap-downs come in clusters, so 252 trades may be only a
     handful of days.
  2. Does it survive an overnight hold? An NRO account cannot buy and sell
     the same share on the same day (no MIS), so a live version must hold
     at least to the next session, paying delivery costs.

Same data, same entry, same stop rule as gapdown.py. Read-only, places no
orders, changes no settings.   python3 gapdown_check.py
Writes gapdown_check.txt next to gapdown.txt.
"""
import os, time, datetime as dt, collections
import numpy as np
import core, getdata
from gapdown import series, run_trade, COST, EXIT, MIN_TURN

COST_DELIV = 0.30   # delivery round trip: STT 0.1% each side + stamp + exchange + GST + DP charge
GAP_MAX = -4.0
NIFTY_GAPS = (-0.7, -1.0, -1.5)


def walk(O, L, C, d, j, entry, stop, days_ahead, cost):
    """Buy at bar j of day d. Check the stop on every later bar, through day
    d+days_ahead. Exit at 15:15 of the last day. Returns % net, or None."""
    for k in range(days_ahead + 1):
        dd = d + k
        start = j + 1 if k == 0 else 0
        last = EXIT if k == days_ahead else core.NB5 - 1
        for b in range(start, last + 1):
            lo = L[dd, b]
            if not np.isfinite(lo) or lo > stop:
                continue
            # opening below the stop on a later day fills at that open, not at the stop
            px = O[dd, b] if (k > 0 and b == 0 and O[dd, b] < stop) else stop
            return (px / entry - 1) * 100 - cost
    ex = C[d + days_ahead, EXIT]
    return (ex / entry - 1) * 100 - cost if np.isfinite(ex) else None


def main():
    t0 = time.time()
    uni = getdata.load_universe() or []
    nif = series("NIFTY50")
    days_all = [int(d) for d in nif["days"]]
    nday = {d: i for i, d in enumerate(days_all)}
    nprev = np.r_[np.nan, nif["C"][:-1, -1]]
    ngap = (nif["O"][:, 0] / nprev - 1) * 100
    last20 = set(days_all[-20:])

    # one row per qualifying trade
    R = collections.defaultdict(list)
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
        for d in range(21, len(days)):
            g = gap[d]
            if not (np.isfinite(g) and g <= GAP_MAX):
                continue
            ni = nday.get(days[d])
            if ni is None or nday.get(days[d - 1]) != ni - 1:
                continue          # previous session missing for this share: gap is not real
            mt = np.median(turn[d - 20:d])
            if mt < MIN_TURN:
                continue
            px = C[d, 0]
            if not (np.isfinite(px) and px > 0):
                continue
            stop = max(L[d, 0] * 0.995, px * 0.96)
            same = run_trade(H[d], L[d], C[d], 0, px, stop, None)

            def ahead(n):
                if d + n >= len(days) or nday.get(days[d + n]) != ni + n:
                    return None   # need n consecutive sessions after the gap day
                return walk(O, L, C, d, 0, px, stop, n, COST_DELIV)

            def next_open():
                if d + 1 >= len(days) or nday.get(days[d + 1]) != ni + 1:
                    return None
                # same-day stop still applies; if not stopped, sell at next open
                for b in range(1, core.NB5):
                    if np.isfinite(L[d, b]) and L[d, b] <= stop:
                        return (stop / px - 1) * 100 - COST_DELIV
                return (O[d + 1, 0] / px - 1) * 100 - COST_DELIV

            R["day"].append(days[d]); R["sym"].append(s); R["gap"].append(g)
            R["ngap"].append(ngap[ni]); R["turn"].append(mt)
            R["green"].append(C[d, 0] > O[d, 0])
            R["same"].append(same)
            R["nopen"].append(next_open())
            R["n1"].append(ahead(1))
            R["n3"].append(ahead(3))
        used += 1
        if used % 300 == 0:
            print("  %d shares · %.0f s" % (used, time.time() - t0))

    if not R["day"]:
        print("no qualifying gap-downs")
        return
    A = {k: np.array(v, dtype=float if k not in ("sym",) else object) for k, v in R.items()
         if k not in ("same", "nopen", "n1", "n3")}
    A["green"] = A["green"].astype(bool)
    for k in ("same", "nopen", "n1", "n3"):
        A[k] = np.array([np.nan if x is None else x for x in R[k]], float)
    day_ = A["day"].astype(int)
    d0, d1 = core.ord_date(days_all[0]), core.ord_date(days_all[-1])

    EXITS = (("same", "sell 15:15 same day (MIS - not allowed on NRO)"),
             ("nopen", "sell next morning at the open (delivery)"),
             ("n1", "sell next day 15:15 (delivery)"),
             ("n3", "sell 3rd day 15:15 (delivery)"))

    def line(name, k, col):
        r = A[col][k]
        r = r[np.isfinite(r)]
        dd = day_[k][np.isfinite(A[col][k])]
        if len(r) < 10:
            return "   %-50s %4d trades on %3d days (too few)" % (name, len(r), len(set(dd)))
        # day-level average: trades on the same day are not independent
        per_day = np.array([r[dd == u].mean() for u in np.unique(dd)])
        t = per_day.mean() / (per_day.std(ddof=1) / np.sqrt(len(per_day))) if len(per_day) > 2 and per_day.std() > 0 else np.nan
        return "   %-50s %4d trades on %3d days  win %3.0f%%  avg %+.2f%%  avg per day %+.2f%%  t %+.1f" % (
            name, len(r), len(per_day), 100 * (r > 0).mean(), r.mean(), per_day.mean(), t)

    out = ["GAP-DOWN CHECK — %d shares · %s to %s · gap ≤ %.0f%% · liquid ≥₹2 cr/day · entry 09:20 close · stop 0.5%% under the 1st candle low" % (
        used, d0, d1, GAP_MAX), "costs: same day %.2f%% · delivery %.2f%%" % (COST, COST_DELIV),
        "t = average day's result divided by its standard error; under 2 means it could easily be luck", ""]

    mw = A["ngap"] <= -0.7
    out.append("1) EXIT TIMING, market-wide gap-downs only (Nifty gap ≤ −0.7%)")
    for col, nm in EXITS:
        out.append(line(nm, mw, col))
    out.append(line("  … same day, green 1st candle only", mw & A["green"], "same"))
    out.append(line("  … next day 15:15, green 1st candle only", mw & A["green"], "n1"))
    out.append("")

    out.append("2) HOW DEEP DOES NIFTY NEED TO GAP? (same day / next day 15:15)")
    for th in NIFTY_GAPS:
        k = A["ngap"] <= th
        nd = len(set(day_[k]))
        out.append("   Nifty gap ≤ %.1f%%: %d Nifty days of %d" % (th, nd, len(days_all)))
        out.append(line("   same day", k, "same"))
        out.append(line("   next day 15:15", k, "n1"))
    out.append(line("share-specific (Nifty gap > −0.7%), same day", ~mw, "same"))
    out.append(line("share-specific (Nifty gap > −0.7%), next day 15:15", ~mw, "n1"))
    out.append("")

    out.append("3) STABILITY BY HALF-YEAR, market-wide only")
    for y in range(d0.year, d1.year + 1):
        for hlf, (m0, m1) in ((1, (1, 6)), (2, (7, 12))):
            a = core.day_ord(dt.date(y, m0, 1))
            b = core.day_ord(dt.date(y, m1, 28)) + 3
            k = mw & (day_ >= a) & (day_ <= b)
            if k.sum():
                out.append(line("%d H%d · same day" % (y, hlf), k, "same"))
                out.append(line("%d H%d · next day 15:15" % (y, hlf), k, "n1"))
    out.append(line("last 20 sessions · same day", mw & np.isin(day_, list(last20)), "same"))
    out.append("")

    out.append("4) WHICH DAYS MADE THE MONEY? market-wide, same day, each day = average of its trades")
    k = mw & np.isfinite(A["same"])
    ud = np.unique(day_[k])
    pdays = sorted(((A["same"][k][day_[k] == u].mean(), int((day_[k] == u).sum()), u) for u in ud), reverse=True)
    for r, n, u in pdays[:8]:
        out.append("   best   %s  Nifty gap %+.1f%%  %3d trades  avg %+.2f%%" % (
            core.ord_date(u), ngap[nday[u]], n, r))
    for r, n, u in pdays[-5:]:
        out.append("   worst  %s  Nifty gap %+.1f%%  %3d trades  avg %+.2f%%" % (
            core.ord_date(u), ngap[nday[u]], n, r))
    tot = sum(r for r, _, _ in pdays)
    top5 = sum(r for r, _, _ in pdays[:5])
    out.append("   %d days in all · sum of day averages %+.1f%% · best 5 days %+.1f%% · all other days %+.1f%%" % (
        len(pdays), tot, top5, tot - top5))
    out.append("")

    out.append("5) DAILY DESK, market-wide only: each such day buy the 3 deepest gaps, equal size")
    for col, nm in EXITS:
        by = collections.defaultdict(list)
        for i in np.nonzero(mw & np.isfinite(A[col]))[0]:
            by[day_[i]].append((A["gap"][i], A[col][i]))
        dr = np.array([np.mean([p[1] for p in sorted(by[u])[:3]]) for u in sorted(by)])
        if len(dr) < 5:
            out.append("   %-50s too few days" % nm)
            continue
        eq = np.cumsum(dr)
        dd_ = (eq - np.maximum.accumulate(eq)).min()
        out.append("   %-50s %3d days · green %3.0f%% · avg day %+.2f%% · sum %+.1f%% · worst day %+.1f%% · drawdown %+.1f%%" % (
            nm, len(dr), 100 * (dr > 0).mean(), dr.mean(), dr.sum(), dr.min(), dd_))
    out.append("")

    out.append("6) BIGGER SHARES ONLY (20-day median turnover ≥ ₹20 cr), market-wide")
    big = mw & (A["turn"] >= 2e8)
    for col, nm in EXITS:
        out.append(line(nm, big, col))
    out.append("")
    out.append("Note: only shares in today's universe are tested (survivorship bias flatters gap-down buying a little).")
    txt = "\n".join(out)
    print("\n" + txt)
    open(os.path.join(core.BASE, "gapdown_check.txt"), "w").write(txt + "\n")
    print("\nsaved gapdown_check.txt · %.0f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
