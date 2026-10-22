#!/usr/bin/env python3
"""toplist.py - buy the LIVE top-gainers list (as Trendlyne shows it during the day) and see what happens.

Each session: rank every liquid share by % change vs yesterday's close at 09:20, 09:30, 10:00, 11:00.
Buy the top 10 at that candle's close. Exit: stop 2% below entry (or the morning low if closer), trail
(at +4% the stop goes to entry, then trails 3% below the high), else 15:15. Costs 0.20%.
Then: which of those picks kept going (≥+3% more by 15:15) vs faded - and what separated them.
Read-only.  python3 toplist.py
"""
import os, time, datetime as dt, collections
import numpy as np
import core, getdata

COST = 0.20
EXIT = 71
MIN_TURN = 2e7
TOPN = 10
CHECK = {"09:20": 0, "09:30": 2, "10:00": 8, "11:00": 20}


def series(sym):
    a = core.load_npz(sym)
    if a is None:
        return None
    m = core.to_matrix(a)
    if m is None or len(m["days"]) < 30:
        return None
    return m


def trade(h, l, c, j, entry):
    stop = entry * 0.98
    hi = entry
    for b in range(j + 1, EXIT + 1):
        if not np.isfinite(l[b]):
            continue
        if l[b] <= stop:
            return (stop / entry - 1) * 100 - COST, (np.nanmax(h[j + 1:EXIT + 1]) / entry - 1) * 100
        hi = max(hi, h[b])
        if hi >= entry * 1.04:
            stop = max(stop, entry, hi * 0.97)
    ex = c[EXIT]
    if not np.isfinite(ex):
        return None, None
    return (ex / entry - 1) * 100 - COST, (np.nanmax(h[j + 1:EXIT + 1]) / entry - 1) * 100


def main():
    t0 = time.time()
    uni = getdata.load_universe() or []
    fo = set()
    for f in os.listdir(core.BASE):
        if f.startswith("futmap_") and f.endswith(".json"):
            try:
                import json
                fo |= set(json.load(open(os.path.join(core.BASE, f))).keys())
            except Exception:
                pass
    nif = series("NIFTY50")
    days_all = [int(d) for d in nif["days"]]
    nday = {d: i for i, d in enumerate(days_all)}
    nprev = np.r_[np.nan, nif["C"][:-1, -1]]
    # per day, per checkpoint: list of candidates (chg, sym, features...)
    book = collections.defaultdict(list)
    used = 0
    for e in uni:
        s = e["sym"]
        m = series(s)
        if m is None:
            continue
        O, H, L, C, V = m["O"], m["H"], m["L"], m["C"], m["V"]
        days = [int(d) for d in m["days"]]
        prev = np.r_[np.nan, C[:-1, -1]]
        v = np.nan_to_num(V)
        turn = np.nansum(v * np.nan_to_num(C), 1)
        cumv = np.cumsum(v, 1)
        tp = (H + L + C) / 3.0
        with np.errstate(invalid="ignore", divide="ignore"):
            vw = np.cumsum(tp * v, 1) / cumv
        for d in range(21, len(days)):
            if not np.isfinite(prev[d]) or prev[d] <= 0 or np.median(turn[d - 20:d]) < MIN_TURN:
                continue
            ni = nday.get(days[d])
            if ni is None:
                continue
            gap = (O[d, 0] / prev[d] - 1) * 100
            p5 = (prev[d] / C[d - 5, -1] - 1) * 100 if np.isfinite(C[d - 5, -1]) else np.nan
            for tag, j in CHECK.items():
                px = C[d, j]
                if not np.isfinite(px):
                    continue
                chg = (px / prev[d] - 1) * 100
                if chg < 2:
                    continue
                avg_cum = np.median(cumv[d - 20:d, j]) if d >= 20 else np.nan
                rvol = cumv[d, j] / avg_cum if avg_cum and avg_cum > 0 else np.nan
                above_open = px > O[d, 0]
                above_vw = px > vw[d, j]
                nchg = (nif["C"][ni, j] / nprev[ni] - 1) * 100 if np.isfinite(nprev[ni]) else np.nan
                r, mfe = trade(H[d], L[d], C[d], j, px)
                if r is None:
                    continue
                more = (C[d, EXIT] / px - 1) * 100 if np.isfinite(C[d, EXIT]) else np.nan
                book[(days[d], tag)].append(dict(chg=chg, s=s, gap=gap, rvol=rvol, above_open=above_open, above_vw=above_vw,
                                                 p5=p5, price=px, fo=s in fo, nchg=nchg, r=r, mfe=mfe, more=more, day=days[d]))
        used += 1
        if used % 300 == 0:
            print("  %d shares · %.0f s" % (used, time.time() - t0))
    d0, d1 = dt.date.fromordinal(days_all[0] + 719163), dt.date.fromordinal(days_all[-1] + 719163)
    last20 = set(days_all[-20:])
    out = ["TOP-GAINERS LIST TEST — %d liquid shares · %s to %s · buy top %d of the live list, stop 2%%, trail, exit 15:15, costs %.2f%%" % (
        used, d0, d1, TOPN, COST), ""]

    def stat(rows, name):
        if len(rows) < 20:
            return "   %-48s %5d (too few)" % (name, len(rows))
        r = np.array([x["r"] for x in rows])
        mo = np.array([x["more"] for x in rows])
        return "   %-48s %5d  win %3.0f%%  avg %+.2f%%  kept going ≥+3%%: %2.0f%%  faded ≤−2%%: %2.0f%%" % (
            name, len(rows), 100 * (r > 0).mean(), r.mean(), 100 * np.nanmean(mo >= 3), 100 * np.nanmean(mo <= -2))

    picks_by_tag = {}
    out.append("1) BUY THE TOP %d AT EACH TIME" % TOPN)
    for tag in CHECK:
        rows = []
        for (day, t), lst in book.items():
            if t == tag:
                rows += sorted(lst, key=lambda x: -x["chg"])[:TOPN]
        picks_by_tag[tag] = rows
        out.append(stat(rows, "top %d at %s" % (TOPN, tag)))
        out.append(stat([x for x in rows if x["day"] in last20], "   … last 20 sessions"))
    out.append("")
    for tag in ("09:30", "10:00"):
        rows = picks_by_tag[tag]
        out.append("2) WHAT SEPARATES THE ONES THAT KEPT GOING — top %d at %s" % (TOPN, tag))
        out.append(stat([x for x in rows if x["chg"] < 5], "up 2–5% at that time"))
        out.append(stat([x for x in rows if 5 <= x["chg"] < 10], "up 5–10%"))
        out.append(stat([x for x in rows if x["chg"] >= 10], "up ≥10%"))
        out.append(stat([x for x in rows if x["above_open"] and x["above_vw"]], "above its open AND above VWAP"))
        out.append(stat([x for x in rows if not x["above_open"]], "below its open (gap fading)"))
        out.append(stat([x for x in rows if x["gap"] < 1], "did NOT gap up (rose after the open)"))
        out.append(stat([x for x in rows if x["gap"] >= 3], "gapped up ≥3%"))
        out.append(stat([x for x in rows if np.isfinite(x["rvol"]) and x["rvol"] >= 5], "volume so far ≥5x normal"))
        out.append(stat([x for x in rows if np.isfinite(x["rvol"]) and x["rvol"] < 2], "volume so far <2x normal"))
        out.append(stat([x for x in rows if np.isfinite(x["nchg"]) and x["nchg"] > 0.3], "Nifty green (>+0.3%)"))
        out.append(stat([x for x in rows if np.isfinite(x["nchg"]) and x["nchg"] < -0.3], "Nifty red (<−0.3%)"))
        out.append(stat([x for x in rows if np.isfinite(x["p5"]) and x["p5"] >= 10], "already up ≥10% in the 5 days before"))
        out.append(stat([x for x in rows if np.isfinite(x["p5"]) and x["p5"] < 0], "down in the 5 days before"))
        if fo:
            out.append(stat([x for x in rows if x["fo"]], "F&O share"))
            out.append(stat([x for x in rows if not x["fo"]], "non-F&O share"))
        out.append(stat([x for x in rows if x["price"] < 100], "price < ₹100"))
        out.append(stat([x for x in rows if x["price"] >= 500], "price ≥ ₹500"))
        best = [x for x in rows if x["above_open"] and x["above_vw"] and x["gap"] < 1 and np.isfinite(x["rvol"]) and x["rvol"] >= 3]
        out.append(stat(best, "COMBO: rose after open, above VWAP, vol ≥3x"))
        out.append(stat([x for x in best if x["day"] in last20], "   … COMBO last 20 sessions"))
        out.append("")
    txt = "\n".join(out)
    print("\n" + txt)
    open(os.path.join(core.BASE, "toplist.txt"), "w").write(txt + "\n")
    print("saved toplist.txt · %.0f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
