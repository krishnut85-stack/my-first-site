"""Catch the turn: beaten down AND moving again — not just beaten down."""

import pytest

from garuda import turn_study as ts


def _months(n, y=2010):
    return [f"{y + i // 12:04d}-{i % 12 + 1:02d}" for i in range(n)]


def test_drawdown_is_measured_against_the_industrys_own_peak():
    months = _months(24)
    # up 5%/month for a year, then down 10%/month for a year
    rets = {"X": {m: (5.0 if i < 12 else -10.0) for i, m in enumerate(months)}}
    at_high = ts.drawdown_from_peak(rets, "X", 11, months, 12)
    assert at_high == pytest.approx(0.0, abs=1e-9)     # a new high is 0
    later = ts.drawdown_from_peak(rets, "X", 20, months, 12)
    assert later < -30.0


def test_too_little_history_is_none_not_zero():
    months = _months(24)
    rets = {"X": {m: 1.0 for m in months}}
    assert ts.drawdown_from_peak(rets, "X", 3, months, 12) is None


def test_a_falling_knife_is_not_a_turn():
    """Down 40% and still falling must NOT qualify — that is the whole point."""
    months = _months(30)
    rets = {"KNIFE": {m: -5.0 for m in months},
            "BASE": {m: (-8.0 if i < 20 else 4.0) for i, m in enumerate(months)}}
    picked = ts.turn_ranked(rets, months, 25, thrust_win=3, min_dd=20.0)
    assert "KNIFE" not in picked
    assert "BASE" in picked


def test_something_never_beaten_down_is_not_a_turn_however_well_it_runs():
    months = _months(30)
    rets = {"RUNNER": {m: 4.0 for m in months}}
    assert ts.turn_ranked(rets, months, 25, thrust_win=3, min_dd=20.0) == []


def test_nothing_qualifying_means_cash_not_a_skipped_month():
    """A rule that only trades when it likes the setup must be charged for the
    time it sits out; dropping those months measures it only on its good ones."""
    months = _months(40)
    rets = {f"UP{i}": {m: 3.0 for m in months} for i in range(4)}
    diag = {}
    out = ts.backtest_turn(rets, months, 3, 20.0, 6, 3, diag=diag)
    assert out, "the months must still be recorded"
    assert diag["idle_pct"] == 100.0
    assert all(v <= 0 for _m, v in out)        # cash earns nothing


def test_the_grid_scores_every_rule_on_both_halves():
    months = _months(160)
    rets = {}
    for j in range(6):
        rets[f"I{j}"] = {m: (4.0 if (i // 20 + j) % 2 else -4.0)
                         for i, m in enumerate(months)}
    rows, past, unseen, bp, bu = ts.run_grid(rets, months)
    assert len(rows) == len(ts.THRUSTS) * len(ts.MIN_DDS) * len(ts.HOLDS) * len(ts.KS)
    assert all("excess_unseen" in r and "idle_unseen" in r for r in rows)
    assert not set(past) & set(unseen)


def test_the_verdict_needs_both_halves():
    assert ts.verdict({"excess_past": 5, "excess_unseen": 5}) == "BEATS"
    assert ts.verdict({"excess_past": 5, "excess_unseen": -1}) == "OVERFIT"
    assert ts.verdict({"excess_past": -1, "excess_unseen": 5}) == "LUCKY?"
    assert ts.verdict({"excess_past": -1, "excess_unseen": -1}) == "LAGS"
