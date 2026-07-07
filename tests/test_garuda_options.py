"""Tests for the Iron Condor options-income backtest."""

import random

from garuda.options import backtest_condor, compare_condor, _condor_stats


def _index_path(days=800, weekly_vol=0.02, seed=1):
    rng = random.Random(seed)
    dvol = weekly_vol / (5 ** 0.5)          # daily vol from weekly
    px, c = 20000.0, [20000.0]
    for _ in range(days):
        px = px * (1 + rng.gauss(0.0003, dvol))
        c.append(round(px, 2))
    return c


def test_wider_strikes_raise_win_rate():
    c = _index_path()
    narrow = _condor_stats(backtest_condor(c, 0.010, 0.01, 0.30))
    wide = _condor_stats(backtest_condor(c, 0.030, 0.01, 0.30))
    # selling further out-of-the-money = the index breaches less often
    assert wide["win"] > narrow["win"]
    assert wide["win"] >= 80          # ~1.5-sigma weekly strikes -> high win rate


def test_condor_payoff_is_bounded():
    c = _index_path(seed=7)
    trades = backtest_condor(c, 0.015, 0.01, 0.30)
    # every week's loss is capped by the wing (defined risk) — never a blow-up
    assert trades and min(trades) >= -0.01           # worst week <= the 1% wing
    assert max(trades) <= 0.30 * 0.01 + 1e-9         # best week = the credit


def test_compare_condor_sweeps_distances():
    res = compare_condor(_index_path())
    assert len(res) == 5
    assert all(s and s["weeks"] > 0 for s in res.values())
