"""Tests for the CAGR EXAM — which horizon of past growth predicts future."""

import random
from datetime import date, timedelta

import pytest

from garuda.lab_cagr_exam import BASELINE, LOOKS, format_exam, run_exam
from garuda.lab_tournament import prepare


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
    looks = (60, 120)                       # short horizons for a short fixture
    grid, pick, splits = run_exam(prep, 500000.0, 0.001, looks=looks,
                                  log=lambda *a: None)
    assert set(grid) == set(looks)
    assert pick in grid
    # the pick is TRAIN-optimal, never chosen from TEST
    best_train = max((g["train"] or {}).get("cagr_pct", -999)
                     for g in grid.values())
    assert (grid[pick]["train"] or {}).get("cagr_pct") == best_train
    fair_start, test_start = splits
    assert fair_start < test_start
    txt = format_exam(grid, pick, splits)
    assert "VERDICT" in txt and "CAGR EXAM" in txt


def test_fair_start_is_longest_horizon_warmup():
    uni = {f"S{i}": _dated(_series(seed=i)) for i in range(12)}
    prep = prepare(uni)
    calendar = sorted({d for p in prep.values() for d in p["px"]})
    _grid, _pick, (fair_start, _ts) = run_exam(prep, 500000.0, 0.001,
                                               looks=(60, 120),
                                               log=lambda *a: None)
    assert fair_start == calendar[120]


def test_too_long_horizon_is_skipped():
    uni = {f"S{i}": _dated(_series(days=500, seed=i)) for i in range(12)}
    prep = prepare(uni)
    # test index ~ 0.7*500 = 350; 300-bar horizon leaves 50 TRAIN bars < 250
    grid, _pick, _splits = run_exam(prep, 500000.0, 0.001, looks=(60, 300),
                                    log=lambda *a: None)
    assert set(grid) == {60}


def test_all_horizons_too_long_raises():
    uni = {f"S{i}": _dated(_series(days=400, seed=i)) for i in range(12)}
    prep = prepare(uni)
    with pytest.raises(SystemExit):
        run_exam(prep, 500000.0, 0.001, looks=(300,), log=lambda *a: None)


def test_default_looks_cover_reversal_horizons():
    # the exam's whole point: 1y / 2y / 3y CAGR ranking vs the CHAKRA 189d
    assert BASELINE in LOOKS
    assert {252, 504, 756} <= set(LOOKS)
