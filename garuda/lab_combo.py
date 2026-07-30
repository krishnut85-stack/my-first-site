"""LAB COMBO — can a COMBINATION beat the best single engine's CAGR?

CRASH (buys panic) and CHAKRA (rides leaders) are near-opposites: the
tournament showed CHAKRA making +24.5% through the exact window where CRASH
went flat. When two profitable streams alternate like that, a REBALANCED blend
can out-compound both — each month-start the money is pulled back to target
weights, which mechanically sells the engine that just ran and feeds the one
that lagged (buy-low / sell-high between strategies, on autopilot).

This module races, over the full history AND the untouched TEST window:

    the three engines solo    CRASH · CHAKRA · HI52
    static splits (no rebalancing — what separate books already do)
    monthly-rebalanced blends 50/50 and 60/40 both ways, and equal 3-way

Rebalanced blends are implementable live as a monthly capital transfer between
books, so nothing here is theoretical.

    python3 -m garuda.lab_combo --csv strength_history.csv

PAPER / research only. Survivorship-bias caveat applies to every row equally.
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_portfolio import metrics
from .lab_tournament import (book_chakra, judge_window_start, prepare,
                             run_signal_book, window_metrics)


def _values(curve):
    return [v for _, v in curve]


def static_split(curves, weights, capital):
    """Independent sub-books, one-time split, never rebalanced (= separate
    Garuda books). Combined curve = weighted sum of each stream's growth."""
    dates = [d for d, _ in curves[0]]
    vals = [_values(c) for c in curves]
    out = []
    for t, d in enumerate(dates):
        total = sum(w * capital * (v[t] / v[0]) for w, v in zip(weights, vals))
        out.append((d, round(total, 2)))
    return out


def rebalanced(curves, weights, capital):
    """Monthly-rebalanced blend: at each month's first bar, reset the sleeves
    to target weights; within the month each sleeve follows its own stream."""
    dates = [d for d, _ in curves[0]]
    vals = [_values(c) for c in curves]
    sleeves = [w * capital for w in weights]
    anchor = [v[0] for v in vals]                  # stream value at last rebalance
    out = [(dates[0], round(capital, 2))]
    for t in range(1, len(dates)):
        if dates[t][:7] != dates[t - 1][:7]:       # month turn -> rebalance
            equity = sum(s * vals[k][t - 1] / anchor[k]
                         for k, s in enumerate(sleeves))
            sleeves = [w * equity for w in weights]
            anchor = [v[t - 1] for v in vals]
        equity = sum(s * vals[k][t] / anchor[k] for k, s in enumerate(sleeves))
        out.append((dates[t], round(equity, 2)))
    return out


def format_combo(rows, start):
    w = 100
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · LAB COMBO   (does a rebalanced blend out-compound the "
             "best single engine?)",
             f"  Scored on full history AND the untouched TEST window (from {start})",
             "=" * w,
             f"  {'PORTFOLIO':<30}{'full FINAL':>14}{'full CAGR':>10}"
             f"{'full DD':>9}{'TEST CAGR':>11}{'TEST DD':>9}",
             "-" * w]
    for name, fm, wm in rows:
        lines.append(f"  {name:<30}{money(fm['final']):>14}"
                     f"{fm['cagr_pct']:>+9.1f}%{fm['max_dd_pct']:>8.1f}%"
                     + (f"{wm['cagr_pct']:>+10.1f}%{wm['max_dd_pct']:>8.1f}%"
                        if wm else f"{'—':>11}{'—':>9}"))
    lines += ["-" * w,
              "  'rebal' = monthly capital transfer between the sleeves — "
              "implementable live between books.",
              "  Judge by BOTH columns: full CAGR for compounding power, TEST "
              "for the recent hostile regime.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB COMBO (blend race)")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    print(f"[combo] {len(dated)} symbols · preparing engines ...")
    prep = prepare(dated)
    start = judge_window_start(dated)
    print("[combo] running CRASH / CHAKRA / HI52 ...")
    crash = run_signal_book(prep, ["crash"], a.capital, a.cost)["curve"]
    chakra = book_chakra(prep, a.capital, a.cost)["curve"]
    hi52 = run_signal_book(prep, ["near52"], a.capital, a.cost)["curve"]
    combos = [
        ("CRASH solo", [crash], None),
        ("CHAKRA solo", [chakra], None),
        ("HI52 solo", [hi52], None),
        ("static 50/50 CRASH+CHAKRA", None,
         static_split([crash, chakra], [.5, .5], a.capital)),
        ("rebal 50/50 CRASH+CHAKRA", None,
         rebalanced([crash, chakra], [.5, .5], a.capital)),
        ("rebal 60/40 CRASH-heavy", None,
         rebalanced([crash, chakra], [.6, .4], a.capital)),
        ("rebal 40/60 CHAKRA-heavy", None,
         rebalanced([crash, chakra], [.4, .6], a.capital)),
        ("rebal 1/3 each (3-way)", None,
         rebalanced([crash, chakra, hi52], [1 / 3] * 3, a.capital)),
    ]
    rows = []
    for name, solo, curve in combos:
        cv = solo[0] if solo else curve
        rows.append((name, metrics(cv, a.capital), window_metrics(cv, start)))
    print(format_combo(rows, start))


if __name__ == "__main__":
    main()
