"""Tests for the MINERVINI EXAM — trend template + breakout vs plain breakout."""

import random
from datetime import date, timedelta

from garuda.lab_minervini import (ENTRIES, EXITS, _entries, _exit_index,
                                  run_exam, trend_template_days)


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _steady_up(days=400, daily=0.004):
    return [round(100 * (1 + daily) ** i, 3) for i in range(days)]


def _downtrend(days=400):
    return [round(400 * (1 - 0.002) ** i, 3) for i in range(days)]


def test_trend_template_gate():
    up = _steady_up()
    days = trend_template_days(up)
    assert days and days[0] >= 220                 # needs full MA warmup
    assert trend_template_days(_downtrend()) == [] # bear stage never qualifies


def test_entries_cross_only_and_gated():
    # uptrend -> 15-bar pullback ledge 2% BELOW the peak -> breakout above it
    base = _steady_up(300)
    peak = base[-1]
    series = base + [round(peak * 0.98, 3)] * 15 + \
        [round(peak * 1.02, 3)] * 4
    t = _entries(series, template=True)
    p = _entries(series, template=False)
    assert 315 in p                                # the breakout bar
    assert 315 in t                                # template held (MAs rising)
    assert set(t) <= set(p)                        # template is a subset gate
    # a monotonic series has no CROSS (yesterday was already at a 20d high)
    assert _entries(_steady_up(), template=False) == []
    assert _entries(_downtrend(), template=True) == []


def test_exit_rules():
    closes = [100, 93, 91.9, 120]
    assert _exit_index(closes, 0, 0.08, 0.15, 0.0, 120) == 2   # 8% stop at 91.9
    run = [100, 110, 121, 100]
    assert _exit_index(run, 0, 0.0, 0.15, 0.0, 120) == 3       # 15% trail off 121
    tgt = [100, 111, 121, 130]
    assert _exit_index(tgt, 0, 0.08, 0.0, 0.20, 60) == 2       # +20% target


def test_run_exam_grid():
    rng = random.Random(1)

    def noisy_up(seed):
        r = random.Random(seed)
        p, cl = 100.0, [100.0]
        for _ in range(900):
            p = max(1.0, p * (1 + 0.0008 + r.gauss(0, 0.015)))
            cl.append(round(p, 3))
        return cl

    uni = {f"S{i}": _dated(noisy_up(i)) for i in range(12)}
    grid, pick, splits = run_exam(uni, log=lambda *a: None)
    assert len(grid) == len(ENTRIES) * len(EXITS)
    assert pick in grid and splits[0] < splits[1]
    best = max((g["train"]["avg"] if g["train"]["avg"] is not None else -999)
               for g in grid.values())
    assert (grid[pick]["train"]["avg"] or -999) == best
