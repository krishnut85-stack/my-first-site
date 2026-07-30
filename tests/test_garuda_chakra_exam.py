"""Tests for the CHAKRA EXAM — concentration x lookback, honestly judged."""

import random
from datetime import date, timedelta

from garuda.lab_chakra_exam import LOOKS, TOPS, format_exam, run_exam
from garuda.lab_tournament import judge_window_start, prepare


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _series(days=900, seed=7):
    rng = random.Random(seed)
    p, prev = 100.0, 0.0
    cl = [p]
    for _ in range(days):
        n = -0.5 * prev + rng.gauss(0.0, 0.016)
        p = max(1.0, p * (1 + 0.0007 + n))
        cl.append(round(p, 3))
        prev = n
    return cl


def test_exam_grid_pick_and_report():
    uni = {f"S{i}": _dated(_series(seed=i)) for i in range(30)}
    prep = prepare(uni)
    start = judge_window_start(uni)
    grid, pick = run_exam(prep, start, 500000.0, 0.001, log=lambda *a: None)
    assert len(grid) == len(TOPS) * len(LOOKS)
    assert pick in grid
    # the pick is TRAIN-optimal, never chosen from TEST
    best_train = max((g["train"] or {}).get("cagr_pct", -999)
                     for g in grid.values())
    assert (grid[pick]["train"] or {}).get("cagr_pct") == best_train
    txt = format_exam(grid, pick, start, 500000.0)
    assert "TRAIN's pick" in txt and "VERDICT" in txt
    assert "top-20 x 126d" in txt or "top-20" in txt
