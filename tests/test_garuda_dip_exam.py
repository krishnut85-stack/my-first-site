"""Tests for the DIP EXAM — small/micro-cap settings on trial."""

import random
from datetime import date, timedelta

from garuda.lab_dip_exam import CURRENT, ENTRIES, EXITS, _exit_index, run_exam
from garuda.setups import rsi


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _bouncy(days=900, seed=3):
    rng = random.Random(seed)
    p, prev = 100.0, 0.0
    cl = [p]
    for _ in range(days):
        n = -0.6 * prev + rng.gauss(0.0, 0.015)
        p = max(1.0, p * (1 + 0.0006 + n))
        cl.append(round(p, 3))
        prev = n
    return cl


def test_exit_index_rules():
    closes = [100, 90, 80, 120, 121, 122, 123]
    r2 = rsi(closes, 2)
    # hard stop 20% fires at bar 2 (80 <= 100*0.8)
    assert _exit_index(closes, r2, 0, 85.0, 30, 0.20, 0.0) == 2
    # rsi exit: after the strong bounce RSI-2 goes >85 (first up bars)
    j = _exit_index(closes, r2, 2, 85.0, 30, 0.0, 0.0)
    assert closes[j] > closes[2]
    # trail exit
    crash = [100, 130, 90, 90, 90]
    assert _exit_index(crash, rsi(crash, 2), 0, None, 180, 0.0, 0.25) == 2
    # time stop: a slow bleed (RSI-2 pinned low, stop never reached) times out
    bleed = [round(100 * (1 - 0.001) ** i, 3) for i in range(40)]
    assert _exit_index(bleed, rsi(bleed, 2), 0, 85.0, 30, 0.20, 0.0) == 30


def test_run_exam_grid_and_current_cell():
    uni = {f"S{i}": _dated(_bouncy(seed=i)) for i in range(10)}
    grid, pick, splits = run_exam(uni, log=lambda *a: None)
    assert len(grid) == len(ENTRIES) * len(EXITS)
    assert CURRENT in grid and pick in grid
    for st in grid.values():
        assert set(st) == {"train", "select", "test"}
    # the pick is TRAIN-optimal, never chosen from TEST
    best = max((g["train"]["avg"] if g["train"]["avg"] is not None else -999)
               for g in grid.values())
    assert (grid[pick]["train"]["avg"] or -999) == best
    assert splits[0] < splits[1]
