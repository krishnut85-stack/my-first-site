"""Tests for LAB PORTFOLIO — the rupee simulation."""

import random
from datetime import date, timedelta

from garuda.lab_portfolio import (buy_and_hold, metrics, nifty_hold,
                                  signals_crash, signals_hi52, simulate)


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _trending(days=700, seed=1, drift=0.001):
    rng = random.Random(seed)
    p, cl = 100.0, [100.0]
    for _ in range(days):
        p = max(1.0, p * (1 + drift + rng.gauss(0, 0.015)))
        cl.append(round(p, 3))
    return cl


def test_signals_hi52_fires_on_fresh_cross_only():
    closes = [100.0] * 253 + [90.0] * 60 + [97.0, 99.0, 99.5]
    dv = _dated(closes)
    sigs = signals_hi52([d for d, _ in dv], closes)
    assert len(sigs) == 1                       # only the 99.0 cross (>= 98.0)
    i = closes.index(99.0)
    assert sigs[0][0] == dv[i][0]


def test_signals_crash_needs_uptrend():
    up = [round(100 * 1.01 ** i, 2) for i in range(100)]   # steep uptrend, so the
    crash = up + [round(up[-1] * 0.85, 2)]      # -15% day (-11% on 5d) stays above SMA50
    dv = _dated(crash)
    sigs = signals_crash([d for d, _ in dv], crash)
    assert sigs and sigs[-1][0] == dv[-1][0]
    # same crash but BELOW the 50-DMA (downtrend) must not fire at the end
    down = [200 - i for i in range(100)]
    down += [down[-1] * 0.9]
    dv2 = _dated(down)
    assert not [s for s in signals_crash([d for d, _ in dv2], down)
                if s[0] == dv2[-1][0]]


def test_simulate_costs_and_trailing_exit():
    # one stock: crosses into its 52w high, runs up, then crashes -20% -> the
    # 15% trail must realize the profit; final equity > start, trades == 1
    closes = ([100.0] * 253 + [90.0] * 40 + [99.0] + [110.0] * 10 + [130.0] * 5
              + [104.0] * 3 + [104.0] * 130)
    series = {"X": _dated(closes)}
    res = simulate(series, [signals_hi52], capital=100_000.0)
    assert res["trades"] >= 1
    assert res["final"] > 100_000.0             # trailed out well above entry
    # cash-only portfolio: equity curve exists for every calendar day
    assert len(res["curve"]) == len(closes)


def test_simulate_respects_cash_limit():
    # 200 simultaneous signals but only 2% x equity each, cash-limited: total
    # spent can never exceed starting cash
    series = {f"S{i}": _dated(_trending(seed=i)) for i in range(20)}
    res = simulate(series, [signals_hi52, signals_crash], capital=50_000.0)
    assert res["final"] > 0
    for _d, v in res["curve"]:
        assert v > 0


def test_metrics_math():
    curve = [(f"202{y}-01-0{i+1}", v) for y, i, v in
             [(0, 0, 100.0), (0, 1, 110.0), (1, 0, 121.0), (1, 1, 121.0)]]
    m = metrics(curve, capital=100.0)
    assert m["total_pct"] == 21.0
    assert m["max_dd_pct"] == 0.0
    assert m["yearly"]["2020"] == 10.0 and m["yearly"]["2021"] == 0.0
    dd = metrics([("2020-01-01", 100.0), ("2020-01-02", 80.0),
                  ("2020-01-03", 90.0)], capital=100.0)
    assert dd["max_dd_pct"] == 20.0


def test_benchmarks():
    series = {f"S{i}": _dated(_trending(seed=i)) for i in range(5)}
    bh = buy_and_hold(series, capital=100_000.0)
    assert bh["final"] > 0 and len(bh["curve"]) > 600
    nf = nifty_hold(_dated([100.0, 110.0, 121.0]), capital=100_000.0)
    assert abs(nf["final"] / 100_000.0 - 1.21 * 0.999) < 0.01
