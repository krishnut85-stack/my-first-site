"""Tests for LAB LARGECAP — relative momentum inside the giants."""

import random
from datetime import date, timedelta

from garuda.lab_chakra_exam import LOOKS, TOPS
from garuda.lab_largecap import restrict_to_top
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


def test_restrict_to_top_keeps_biggest_with_history():
    dated = {f"S{i}": _dated(_series(seed=i)) for i in range(10)}
    mcap = {f"S{i}": 1000.0 - i for i in range(10)}   # S0 biggest
    mcap["GHOST"] = 99999.0                            # huge but no prices
    kept = restrict_to_top(dated, mcap, 3)
    assert set(kept) == {"S0", "S1", "S2"}             # ghost can't sneak in
    # symbols without a market cap are excluded even with history
    assert "S9" in restrict_to_top(dated, mcap, 10)
    del mcap["S9"]
    assert "S9" not in restrict_to_top(dated, mcap, 10)


def test_largecap_exam_runs_on_restricted_universe():
    from garuda.lab_chakra_exam import run_exam
    dated = {f"S{i}": _dated(_series(seed=i)) for i in range(40)}
    mcap = {f"S{i}": 5000.0 - i for i in range(40)}
    small = restrict_to_top(dated, mcap, 25)
    prep = prepare(small)
    start = judge_window_start(small)
    grid, pick = run_exam(prep, start, 500000.0, 0.001, log=lambda *a: None)
    assert len(grid) == len(TOPS) * len(LOOKS)
    assert pick in grid
