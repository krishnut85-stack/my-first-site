#!/usr/bin/env python3
"""PANEL SIGNAL BACKTEST v1.0 — grade the signal you ACTUALLY trade.

panel_backtest.py grades individual judges and the strict mean>=7/agree>=70%
gate -- but panel_executor.py trades composite_signal() (the A/B two-pattern
brain). Those are different rules, so the old backtest never validated what the
bot trades. This does, end to end, with no lookahead, under the CURRENT
judge_weights.json, and with the realism that decides whether a paper edge
survives in real life:

  - entry at NEXT day's OPEN (signal is computed on the close, traded next AM)
  - the executor's guards: skip if the stock gaps > MAX_GAP_STOCK overnight
  - exit at -SL_PCT stop (gap-through filled at the open) or TIME_STOP_DAYS,
    whichever comes first
  - round-trip costs + slippage subtracted (CNC delivery: STT/charges/slippage)
  - results split by PATTERN (A/B), by MARKET REGIME (bull/neutral/bear via
    NIFTY vs 50DMA), and IN-SAMPLE vs OUT-OF-SAMPLE (older half vs recent half)

It deliberately reuses panel.py (features, score_stock, composite_signal) so it
tests the exact code path the executor runs. Read-only; writes a report + a
signal_backtest table, changes no trading behaviour.

Honest limits: close-to-close candles, no intraday path inside a bar beyond
O/H/L/C; the 'insti' family votes neutral (its stores only build forward); the
A/B patterns may have been tuned on this same window, so trust OUT-OF-SAMPLE
and per-regime numbers far more than the headline.

Usage (on droplet, from /home/globalbot):
  python3 panel_signal_backtest.py            # full universe (~5-10 min)
  python3 panel_signal_backtest.py --quick    # 500-stock sample (~2 min)
"""
import os
import sys
import time
import pickle
import sqlite3
import datetime as dt

import numpy as np
import panel  # JUDGES, VETOES, features, score_stock, composite_signal, market_context

CACHE = panel.CACHE
DB_PATH = panel.DB_PATH
REPORT = os.path.join(panel.BASE, "panel_signal_backtest_report.txt")

OFFSETS = list(range(25, 206, 5))     # bars-before-end eval points (k>=25 so fwd window exists)

# --- realism knobs (match panel_executor.py defaults) ---
SL_PCT = 0.04                  # -4% hard stop
TIME_STOP_DAYS = 20            # 20 trading-day time stop
MAX_GAP_STOCK = 0.03           # skip entry if stock gapped > 3% overnight (executor guard)
SLIP = 0.0005                  # 5 bps slippage each side
ROUND_TRIP_COST = 0.0030       # CNC delivery: STT ~0.2% + exch/SEBI/stamp/GST + DP ~0.1%


def truncate(d, k):
    return {key: arr[: len(arr) - k] for key, arr in d.items()}


def regime_label(nif_trunc):
    """Classify the market at an eval point by NIFTY vs its 50DMA (regime_lite thresholds)."""
    if nif_trunc is None or len(nif_trunc) < 50:
        return "UNKNOWN"
    sma50 = float(np.mean(nif_trunc[-50:]))
    if sma50 <= 0:
        return "UNKNOWN"
    dist = (nif_trunc[-1] - sma50) / sma50
    if dist >= 0.02:
        return "BULL"
    if dist <= -0.01:
        return "BEAR"
    return "NEUTRAL"


def simulate(o, h, l, c, entry_idx, sl_pct, max_days):
    """Forward trade from entry_idx (next-open). Returns (net_pct, reason) or None."""
    n = len(c)
    if entry_idx >= n:
        return None
    open_px = o[entry_idx]
    if open_px <= 0:
        return None
    entry = open_px * (1 + SLIP)
    sl = open_px * (1 - sl_pct)
    last = min(entry_idx + max_days - 1, n - 1)
    exit_px, reason = None, None
    for j in range(entry_idx, last + 1):
        if l[j] <= sl:                          # stop touched
            exit_px = o[j] if o[j] < sl else sl  # gap-through fills worse, at the open
            reason = "SL"
            break
    if exit_px is None:
        exit_px = c[last]
        reason = "TIME"
    exit_eff = exit_px * (1 - SLIP)
    net = (exit_eff / entry - 1.0) - ROUND_TRIP_COST
    return net * 100.0, reason


def stats(rets):
    if not rets:
        return (0, 0.0, 0.0, 0.0)
    arr = np.array(rets, dtype=np.float64)
    return (len(arr), float(arr.mean()), float((arr > 0).mean() * 100), float(np.median(arr)))


def run(quick=False):
    hp = os.path.join(CACHE, "hist.pkl")
    if not os.path.exists(hp):
        raise SystemExit("[SBT] No candle cache. Run: python3 panel.py warmup")
    hist = pickle.load(open(hp, "rb"))
    nifty = hist.get("__NIFTY__")
    syms = [s for s in hist if s != "__NIFTY__" and len(hist[s]["c"]) >= max(OFFSETS) + 60]
    if quick:
        rng = np.random.default_rng(42)
        syms = list(rng.choice(syms, size=min(500, len(syms)), replace=False))
    oos_cut = sorted(OFFSETS)[len(OFFSETS) // 2]   # offsets < cut = recent half = OUT-OF-SAMPLE
    print(f"[SBT] {len(syms)} stocks x {len(OFFSETS)} eval points | weights: "
          f"{'ON' if panel.WEIGHTS else 'FLAT'} | OOS = offsets < {oos_cut} (recent half)")

    trades = []   # dict per simulated trade
    base20 = []
    t0 = time.time()
    for ei, k in enumerate(OFFSETS, 1):
        sub = {s: truncate(hist[s], k) for s in syms}
        nif_trunc = nifty["c"][: len(nifty["c"]) - k] if nifty is not None else None
        if nif_trunc is not None:
            sub["__NIFTY__"] = {"c": nif_trunc}
        mkt = panel.market_context(sub, {})
        regime = regime_label(nif_trunc)
        nifty20 = (nif_trunc[-1] / nif_trunc[-21] - 1) * 100 if nif_trunc is not None and len(nif_trunc) >= 21 else 0.0
        regime_ok = nifty20 > panel.REGIME_MIN_NIFTY20
        oos = k < oos_cut
        for s in syms:
            full = hist[s]
            c = full["c"]
            n = len(c)
            i = n - k - 1                       # last known close index
            if i < 1 or i + 2 >= n:
                continue
            base20.append(c[min(i + 20, n - 1)] / c[i] - 1.0)
            f = panel.features(s, sub[s], mkt)
            f["deliv"] = None
            f["bulk"] = {}
            vetoed, mean, agree, votes = panel.score_stock(f)
            sig = panel.composite_signal(votes, vetoed, regime_ok)
            if sig == 0:
                continue
            entry_idx = i + 1                   # trade next morning's open
            if full["o"][entry_idx] / c[i] - 1.0 > MAX_GAP_STOCK:   # executor's gap guard
                continue
            res = simulate(full["o"], full["h"], full["l"], full["c"], entry_idx,
                           SL_PCT, TIME_STOP_DAYS)
            if res is None:
                continue
            net, reason = res
            trades.append({"sym": s, "pattern": "A" if sig == 1 else "B",
                           "regime": regime, "oos": oos, "net": net, "reason": reason})
        print(f"[SBT] eval {ei}/{len(OFFSETS)} ({time.time()-t0:.0f}s, {len(trades)} trades)")

    b20 = float(np.mean(base20)) * 100 if base20 else 0.0
    L = []
    L.append(f"PANEL SIGNAL BACKTEST — {len(syms)} stocks, {len(OFFSETS)} eval points, "
             f"weights {'ON' if panel.WEIGHTS else 'FLAT'}")
    L.append(f"Realism: next-open entry, {MAX_GAP_STOCK*100:.0f}% gap-skip, -{SL_PCT*100:.0f}% SL, "
             f"{TIME_STOP_DAYS}d time-stop, {SLIP*1e4:.0f}bps slip/side, "
             f"{ROUND_TRIP_COST*100:.2f}% round-trip cost")
    L.append(f"Baseline (random 20d hold, gross): {b20:+.2f}%")
    L.append("")
    allnet = [t["net"] for t in trades]
    n, mean, win, med = stats(allnet)
    if not trades:
        L.append("NO SIGNALS FIRED. composite_signal() never triggered in-window. "
                 "Loosen the A/B gates or widen the universe before expecting trades.")
        _write(L, trades)
        return
    sl_share = sum(1 for t in trades if t["reason"] == "SL") / len(trades) * 100
    L.append(f"ALL TRADES (net of costs): {n} | mean {mean:+.2f}% | win {win:.0f}% | "
             f"median {med:+.2f}% | stopped-out {sl_share:.0f}%")
    L.append(f"Edge vs baseline: {mean - b20:+.2f}% per trade")
    L.append("")

    def block(title, key, buckets):
        L.append(f"=== BY {title} ===")
        L.append(f"{'BUCKET':<12}{'N':>6}{'MEAN%':>9}{'WIN%':>7}{'MEDIAN%':>9}")
        for b in buckets:
            rr = [t["net"] for t in trades if t[key] == b]
            nn, mm, ww, md = stats(rr)
            L.append(f"{str(b):<12}{nn:>6}{mm:>9.2f}{ww:>7.0f}{md:>9.2f}")
        L.append("")

    block("PATTERN", "pattern", ["A", "B"])
    block("REGIME", "regime", ["BULL", "NEUTRAL", "BEAR", "UNKNOWN"])
    # in-sample vs out-of-sample
    L.append("=== IN-SAMPLE vs OUT-OF-SAMPLE (the honesty check) ===")
    L.append(f"{'BUCKET':<12}{'N':>6}{'MEAN%':>9}{'WIN%':>7}{'MEDIAN%':>9}")
    for label, flag in (("in-sample", False), ("out-of-sample", True)):
        rr = [t["net"] for t in trades if t["oos"] == flag]
        nn, mm, ww, md = stats(rr)
        L.append(f"{label:<12}{nn:>6}{mm:>9.2f}{ww:>7.0f}{md:>9.2f}")
    L.append("")
    # rough portfolio translation
    oos = [t["net"] for t in trades if t["oos"]]
    _, oos_mean, _, _ = stats(oos)
    L.append("=== ROUGH PORTFOLIO READ (out-of-sample mean, 10 slots x Rs.50k) ===")
    if oos:
        per_trade_rs = 50000 * oos_mean / 100
        L.append(f"  OOS mean {oos_mean:+.2f}%/trade -> ~Rs.{per_trade_rs:+,.0f} per Rs.50k position.")
        L.append(f"  At ~10 positions/cycle that is ~Rs.{per_trade_rs*10:+,.0f} per turnover (~20 trading days),")
        L.append(f"  i.e. ~{oos_mean*10/5:+.1f}% per month on the Rs.5L pool IF this holds. Unproven.")
    else:
        L.append("  no out-of-sample trades to translate.")
    L.append("")
    L.append("READ THIS: trust OUT-OF-SAMPLE and per-REGIME rows over the headline. "
             "A positive in-sample edge that vanishes out-of-sample = overfit, not profit.")

    _write(L, trades)


def _write(lines, trades):
    report = "\n".join(lines)
    open(REPORT, "w").write(report)
    con = sqlite3.connect(DB_PATH)
    con.executescript("""CREATE TABLE IF NOT EXISTS signal_backtest(
        ts TEXT, symbol TEXT, pattern TEXT, regime TEXT, oos INTEGER,
        net REAL, reason TEXT);""")
    ts = dt.datetime.now().isoformat()
    con.executemany("INSERT INTO signal_backtest VALUES(?,?,?,?,?,?,?)",
                    [(ts, t["sym"], t["pattern"], t["regime"], int(t["oos"]),
                      t["net"], t["reason"]) for t in trades])
    con.commit()
    con.close()
    print("\n" + report)
    print(f"\n[SBT] report: {REPORT} | signal_backtest table updated ({len(trades)} trades)")


if __name__ == "__main__":
    run(quick="--quick" in sys.argv)
