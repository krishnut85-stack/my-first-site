"""Tests for the RSI-2 oversold-bounce setup (the honest high-win-rate route)."""

import random

from garuda.setups import rsi, sma, oversold_bounce_trades, backtest


def test_rsi_and_sma_basics():
    up = [i for i in range(1, 30)]          # strictly increasing
    r = rsi(up, 2)
    assert r[-1] == 100.0                    # only gains -> RSI 100
    s = sma([1, 2, 3, 4, 5], 3)
    assert s[2] == 2.0 and s[4] == 4.0


def _uptrend_with_dips(days=700, seed=4):
    """Long-term uptrend + strongly mean-reverting short-term noise, so RSI-2
    dips tend to bounce — the exact condition the setup is built for."""
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    closes = [price]
    for _ in range(days):
        noise = -0.6 * prev + rng.gauss(0.0, 0.015)
        r = 0.0005 + noise                   # drift up + reverting shock
        price = max(1.0, price * (1.0 + r))
        closes.append(round(price, 3))
        prev = noise
    return closes


def test_oversold_bounce_has_edge_on_reverting_uptrend():
    closes = _uptrend_with_dips()
    trades = oversold_bounce_trades(closes, cost_per_side=0.0)
    assert len(trades) > 10
    win_rate = sum(1 for x in trades if x > 0) / len(trades) * 100
    avg = sum(trades) / len(trades)
    assert win_rate > 60          # a genuine reversion edge shows a high win rate
    assert avg > 0                # and positive expectancy before costs


def test_downtrend_triggers_nothing():
    # strictly declining -> never above SMA-200 -> the trend filter blocks entry
    down = [1000.0 * (0.999 ** i) for i in range(400)]
    assert oversold_bounce_trades(down) == []


def test_backtest_aggregates_and_flags_costs():
    panel = {"A": _uptrend_with_dips(seed=1), "B": _uptrend_with_dips(seed=2)}
    free = backtest(panel, cost_per_side=0.0)
    dear = backtest(panel, cost_per_side=0.05)     # absurd costs
    assert free["trades"] > 0
    assert dear["avg_return_pct"] < free["avg_return_pct"]
    assert "win_rate_pct" in free
