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


def test_handles_zero_price_rows_without_crashing():
    # some illiquid microcaps carry 0.0 closes — must not ZeroDivision
    closes = _uptrend_with_dips()
    closes[300] = 0.0
    closes[301] = 0.0
    trades = oversold_bounce_trades(closes, cost_per_side=0.0)  # no exception
    assert all(isinstance(x, float) for x in trades)


def test_downtrend_triggers_nothing():
    # strictly declining -> never above SMA-200 -> the trend filter blocks entry
    down = [1000.0 * (0.999 ** i) for i in range(400)]
    assert oversold_bounce_trades(down) == []


def test_stop_loss_caps_worst_trade():
    closes = _uptrend_with_dips()
    no_stop = oversold_bounce_trades(closes, cost_per_side=0.0)
    with_stop = oversold_bounce_trades(closes, cost_per_side=0.0, stop_loss=0.03)
    # a 3% stop means no realised trade should be far below -3% (minus a little slip)
    assert min(with_stop) >= min(no_stop) - 1e-9
    assert min(with_stop) > -0.10           # worst loss is contained


def test_oos_window_counts_fewer_trades():
    closes = _uptrend_with_dips()
    full = oversold_bounce_trades(closes, cost_per_side=0.0)
    recent = oversold_bounce_trades(closes, cost_per_side=0.0, oos=0.3)  # last 30%
    assert 0 < len(recent) < len(full)     # only trades entering in the window count


def test_no_trend_filter_allows_more_trades():
    closes = _uptrend_with_dips()
    strict = oversold_bounce_trades(closes, cost_per_side=0.0, use_trend=True)
    loose = oversold_bounce_trades(closes, cost_per_side=0.0, use_trend=False)
    assert len(loose) >= len(strict)         # dropping the filter = more entries


def test_backtest_aggregates_and_flags_costs():
    panel = {"A": _uptrend_with_dips(seed=1), "B": _uptrend_with_dips(seed=2)}
    free = backtest(panel, cost_per_side=0.0)
    dear = backtest(panel, cost_per_side=0.05)     # absurd costs
    assert free["trades"] > 0
    assert dear["avg_return_pct"] < free["avg_return_pct"]
    assert "win_rate_pct" in free
