#!/usr/bin/env python3
"""gapstats.py - what actually happens intraday, measured on the 5-minute history already on this server.

Answers, for every liquid share-day in the data:
  1. Gaps: how often a gap-up / gap-down fades by 15:15, by gap size.
  2. Opening-range breakout (buy the break of the first 5-min high, stop at its low, exit 15:15):
     win rate and average R - all days, stocks-in-play only, and split by what Nifty is doing.
  3. Same breakout on the first 30-min range (entry from 09:45).
  4. Relative strength on red days: shares up >=1% and above VWAP at 10:00 while Nifty is down - what they do by 15:15.
Prints a table and saves it to gapstats.txt. Read-only: touches nothing the engine uses.

  python3 gapstats.py            all shares in the universe
  python3 gapstats.py --max=300  only the 300 most liquid (faster)
"""
import os, sys, json, time
import numpy as np
import core, getdata

COST_PCT = 0.10          # round-trip charges + slippage, % of price (intraday equity, approximate)


def series(sym):
    a = core.load_npz(sym)
    if a is None:
        return None
    m = core.to_matrix(a)
    if m is None or len(m["days"]) < 30:
        return None
    return m


def vwap_upto(m, j):
    tp = (m["H"][:, :j + 1] + m["L"][:, :j + 1] + m["C"][:, :j + 1]) / 3.0
    v = np.nan_to_num(m["V"][:, :j + 1])
    with np.errstate(invalid="ignore", divide="ignore"):
        return (tp * v).sum(1) / v.sum(1)


def orb(m, rng_bars, first_entry_bar, exit_bar=71, max_risk=3.0, min_risk=0.2):
    """Buy the first break of the high of bars [0, rng_bars); stop = low of that range; exit at exit_bar close.
    Vectorised over days. Returns per-day arrays (R net of costs, % move net); NaN = no trade."""
    H, L, C = m["H"], m["L"], m["C"]
    D = len(H)
    with np.errstate(invalid="ignore"):
        rh = np.nanmax(H[:, :rng_bars], 1)
        rl = np.nanmin(L[:, :rng_bars], 1)
        entry = rh * 1.0005
        risk = (entry - rl) / entry * 100
        valid = np.isfinite(rh) & np.isfinite(rl) & (rh > rl) & (rl > 0) & (risk <= max_risk) & (risk >= min_risk)
        seg_h = H[:, first_entry_bar:exit_bar + 1]
        seg_l = L[:, first_entry_bar:exit_bar + 1]
        brk = np.nan_to_num(seg_h, nan=-np.inf) > entry[:, None]
        trig = brk.any(1) & valid
        j = np.argmax(brk, 1)                                   # first breaking bar (relative)
        cols = np.arange(seg_l.shape[1])[None, :]
        after = cols >= j[:, None]
        hit = (np.nan_to_num(seg_l, nan=np.inf) <= rl[:, None]) & after
        stopped = hit.any(1)
        ex = np.where(stopped, rl, C[:, exit_bar])
        cost = entry * COST_PCT / 100
        ok = trig & np.isfinite(ex)
        R = np.where(ok, (ex - entry - cost) / (entry - rl), np.nan)
        pct = np.where(ok, (ex - entry - cost) / entry * 100, np.nan)
    return R, pct


def summ(R, pct, mask):
    k = mask & np.isfinite(R)
    n = int(k.sum())
    if n == 0:
        return n, None, None, None, None
    r = R[k]
    return n, 100.0 * (r > 0).mean(), float(r.mean()), float(np.nansum(pct[k]) / n), float(np.median(r))


def main():
    mx = None
    for x in sys.argv[1:]:
        if x.startswith("--max="):
            mx = int(x[6:])
    uni = getdata.load_universe() or []
    syms = [e["sym"] for e in uni][:mx] if mx else [e["sym"] for e in uni]
    nif = series("NIFTY50")
    if nif is None:
        print("no NIFTY50 history - run getdata.py first")
        return
    nday = {int(d): i for i, d in enumerate(nif["days"])}
    nO, nC = nif["O"], nif["C"]
    n_prev = np.r_[np.nan, nC[:-1, -1]]
    n_gap = (nO[:, 0] / n_prev - 1) * 100
    n_930 = (nC[:, 2] / nO[:, 0] - 1) * 100            # Nifty at 09:30 vs its own open
    n_1000 = (nC[:, 8] / n_prev - 1) * 100             # Nifty at 10:00 vs previous close
    n_day = (nC[:, 71] / n_prev - 1) * 100

    acc = {k: [] for k in ("gap", "ret_open", "ret_prev", "orb5R", "orb5p", "sip", "orb30R", "orb30p",
                           "ngap", "n930", "rs_ret", "rs_mask", "n1000", "nday", "gapheld")}
    t0 = time.time()
    used = 0
    for s in syms:
        m = series(s)
        if m is None:
            continue
        idx = np.array([nday.get(int(d), -1) for d in m["days"]])
        ok = idx >= 0
        if ok.sum() < 30:
            continue
        m = {k: (v[ok] if hasattr(v, "__len__") and len(v) == len(ok) else v) for k, v in m.items()}
        idx = idx[ok]
        O, H, L, C, V = m["O"], m["H"], m["L"], m["C"], m["V"]
        prev = np.r_[np.nan, C[:-1, -1]]
        gap = (O[:, 0] / prev - 1) * 100
        ret_open = (C[:, 71] / O[:, 0] - 1) * 100
        ret_prev = (C[:, 71] / prev - 1) * 100
        # stocks in play: first-5-min volume vs the median of the previous 20 days' first 5 min
        v0 = np.nan_to_num(V[:, 0])
        med = np.array([np.median(v0[max(0, d - 20):d]) if d >= 5 else np.nan for d in range(len(v0))])
        with np.errstate(invalid="ignore", divide="ignore"):
            rvol5 = v0 / med
        sip = (rvol5 >= 2.0) & (C[:, 0] > O[:, 0])
        R5, p5 = orb(m, 1, 1)
        R30, p30 = orb(m, 6, 6)
        # relative strength at 10:00
        chg10 = (C[:, 8] / prev - 1) * 100
        vw10 = vwap_upto(m, 8)
        rs_mask = (chg10 >= 1.0) & (C[:, 8] > vw10) & (n_1000[idx] <= -0.3)
        rs_ret = (C[:, 71] / C[:, 8] - 1) * 100 - COST_PCT
        gapheld = np.nanmin(L[:, :6], 1) >= prev        # gap-up never filled in the first 30 min
        for k, v in (("gap", gap), ("ret_open", ret_open), ("ret_prev", ret_prev), ("orb5R", R5), ("orb5p", p5),
                     ("sip", sip), ("orb30R", R30), ("orb30p", p30), ("ngap", n_gap[idx]), ("n930", n_930[idx]),
                     ("rs_ret", rs_ret), ("rs_mask", rs_mask), ("n1000", n_1000[idx]), ("nday", n_day[idx]), ("gapheld", gapheld)):
            acc[k].append(v)
        used += 1
        if used % 100 == 0:
            print("  %d shares, %.0f s" % (used, time.time() - t0))
    A = {k: np.concatenate(v) for k, v in acc.items()}
    first = min(int(d) for d in nif["days"])
    last = max(int(d) for d in nif["days"])
    import datetime as dt
    d0, d1 = dt.date.fromordinal(first + 719163), dt.date.fromordinal(last + 719163)
    L = ["GAPSTATS — %d shares, %d share-days, %s to %s (%d Nifty days)" % (used, len(A["gap"]), d0, d1, len(nif["days"])),
         "returns are to 15:15, net of %.2f%% costs where a trade is simulated" % COST_PCT, ""]

    L.append("1) GAPS — does the gap fade?   (fade = 15:15 below the open)")
    L.append("   %-14s %7s %8s %12s %14s" % ("gap", "days", "fade %", "avg open→15:15", "avg vs prev close"))
    for lo, hi, name in ((4, 99, "≥ +4%"), (2, 4, "+2 to +4%"), (1, 2, "+1 to +2%"), (-1, 1, "−1 to +1%"),
                         (-2, -1, "−2 to −1%"), (-4, -2, "−4 to −2%"), (-99, -4, "≤ −4%")):
        k = np.isfinite(A["gap"]) & (A["gap"] >= lo) & (A["gap"] < hi) & np.isfinite(A["ret_open"])
        if k.sum():
            fade = 100.0 * (A["ret_open"][k] < 0).mean() if lo >= 0 else 100.0 * (A["ret_open"][k] > 0).mean()
            L.append("   %-14s %7d %7.0f%% %+11.2f%% %+13.2f%%" % (name, k.sum(), fade, np.nanmean(A["ret_open"][k]), np.nanmean(A["ret_prev"][k])))
    L.append("   (for gap-downs, 'fade' = recovered: 15:15 above the open)")
    k = np.isfinite(A["gap"]) & (A["gap"] >= 2) & np.isfinite(A["ret_open"])
    if k.sum():
        h = k & A["gapheld"]
        L.append("   gap-ups ≥2%% that did NOT fill in the first 30 min: %d days, fade %.0f%%, avg open→15:15 %+.2f%%" % (
            h.sum(), 100.0 * (A["ret_open"][h] < 0).mean() if h.sum() else 0, np.nanmean(A["ret_open"][h]) if h.sum() else 0))
    L.append("")

    def row(name, R, p, mask):
        n, wr, ar, ap, md = summ(R, p, mask)
        if n:
            L.append("   %-44s %6d  win %3.0f%%  avg %+.2fR  (%+.2f%% per trade)" % (name, n, wr, ar, ap))
        else:
            L.append("   %-44s %6d" % (name, 0))

    L.append("2) OPENING 5-MIN BREAKOUT (09:20 entry, stop at 5-min low)")
    allm = np.ones(len(A["gap"]), bool)
    row("all share-days", A["orb5R"], A["orb5p"], allm)
    row("stocks in play only (5-min vol ≥2x, green)", A["orb5R"], A["orb5p"], A["sip"])
    row("  … and Nifty gapped up ≥0.5%", A["orb5R"], A["orb5p"], A["sip"] & (A["ngap"] >= 0.5))
    row("  … Nifty gap-up AND below its open at 09:30", A["orb5R"], A["orb5p"], A["sip"] & (A["ngap"] >= 0.5) & (A["n930"] < 0))
    row("  … Nifty gap-up AND above its open at 09:30", A["orb5R"], A["orb5p"], A["sip"] & (A["ngap"] >= 0.5) & (A["n930"] >= 0))
    row("  … Nifty flat open (−0.3..+0.3%)", A["orb5R"], A["orb5p"], A["sip"] & (np.abs(A["ngap"]) < 0.3))
    row("  … Nifty gapped down ≤−0.5%", A["orb5R"], A["orb5p"], A["sip"] & (A["ngap"] <= -0.5))
    row("  … share itself gapped ≥3%", A["orb5R"], A["orb5p"], A["sip"] & (A["gap"] >= 3))
    row("  … share gap 0..3%", A["orb5R"], A["orb5p"], A["sip"] & (A["gap"] >= 0) & (A["gap"] < 3))
    L.append("")
    L.append("3) 30-MIN RANGE BREAKOUT (entry from 09:45)")
    row("all share-days", A["orb30R"], A["orb30p"], allm)
    row("stocks in play only", A["orb30R"], A["orb30p"], A["sip"])
    row("  … Nifty above its open at 09:30", A["orb30R"], A["orb30p"], A["sip"] & (A["n930"] >= 0))
    row("  … Nifty below its open at 09:30", A["orb30R"], A["orb30p"], A["sip"] & (A["n930"] < 0))
    L.append("")
    L.append("4) RELATIVE STRENGTH ON RED MORNINGS (share ≥+1% & above VWAP at 10:00 while Nifty ≤−0.3%)")
    k = A["rs_mask"] & np.isfinite(A["rs_ret"])
    if k.sum():
        L.append("   %d share-days · up by 15:15 %.0f%% · avg 10:00→15:15 %+.2f%% · median %+.2f%%" % (
            k.sum(), 100.0 * (A["rs_ret"][k] > 0).mean(), np.nanmean(A["rs_ret"][k]), np.nanmedian(A["rs_ret"][k])))
        kk = k & (A["nday"] < -0.5)
        if kk.sum():
            L.append("   … when Nifty kept falling (closed ≤−0.5%%): %d · up %.0f%% · avg %+.2f%%" % (
                kk.sum(), 100.0 * (A["rs_ret"][kk] > 0).mean(), np.nanmean(A["rs_ret"][kk])))
    else:
        L.append("   no such days in the data")
    txt = "\n".join(L)
    print("\n" + txt)
    open(os.path.join(core.BASE, "gapstats.txt"), "w").write(txt + "\n")
    print("\nsaved gapstats.txt · %.0f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
