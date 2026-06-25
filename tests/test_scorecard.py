"""Tests for the honest scorecard + verdict logic."""

from sectorbot import config
from sectorbot.portfolio import Portfolio
from sectorbot.scorecard import compute_scorecard


def _pf_with(history, trades=None):
    return Portfolio(1_000_000, 50_000, history=history, trades=trades or [])


def _ramp(days, strat_pct, index_pct):
    return [
        {"date": f"d{i}",
         "equity": 1_000_000 * (1 + strat_pct / 100 * i / days),
         "index": 20_000 * (1 + index_pct / 100 * i / days)}
        for i in range(days + 1)
    ]


def test_too_early_below_min_track_days():
    sc = compute_scorecard(_pf_with(_ramp(5, 3, 1)))
    assert sc["verdict"] == "TOO EARLY"
    assert sc["ready_to_judge"] is False


def test_promising_when_beating_index():
    sc = compute_scorecard(_pf_with(_ramp(config.MIN_TRACK_DAYS + 2, 6, 4)))
    assert sc["verdict"] == "PROMISING"
    assert sc["edge_vs_index_pct"] > 0


def test_lagging_when_below_index():
    sc = compute_scorecard(_pf_with(_ramp(config.MIN_TRACK_DAYS + 2, 2, 5)))
    assert sc["verdict"] == "LAGGING THE INDEX"
    assert sc["edge_vs_index_pct"] < 0


def test_losing_when_negative():
    sc = compute_scorecard(_pf_with(_ramp(config.MIN_TRACK_DAYS + 2, -3, 4)))
    assert sc["verdict"] == "LOSING"


def test_no_index_history_is_handled():
    hist = [{"date": f"d{i}", "equity": 1_000_000 * (1 + 0.05 * i / 31)}
            for i in range(config.MIN_TRACK_DAYS + 2)]
    sc = compute_scorecard(_pf_with(hist))
    assert sc["index_return_pct"] is None
    assert "no index" in sc["verdict"].lower()


def test_profit_factor_and_win_rate():
    hist = _ramp(config.MIN_TRACK_DAYS + 2, 5, 3)
    trades = [
        {"side": "SELL", "symbol": "A", "pnl": 3000},
        {"side": "SELL", "symbol": "B", "pnl": 1000},
        {"side": "SELL", "symbol": "C", "pnl": -2000},
    ]
    sc = compute_scorecard(_pf_with(hist, trades))
    assert sc["closed_trades"] == 3
    assert round(sc["win_rate_pct"]) == 67
    assert round(sc["profit_factor"], 1) == 2.0  # 4000 won / 2000 lost
