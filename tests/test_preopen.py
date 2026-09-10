"""The pre-open gap scan: what is known before options can be traded."""

from datetime import datetime, timedelta, timezone

import pytest

from garuda import preopen as po

IST = timezone(timedelta(hours=5, minutes=30))


def at(h, m):
    return datetime(2026, 9, 10, h, m, tzinfo=IST)


def test_the_preopen_window_runs_until_continuous_trading_starts():
    assert not po.in_preopen(at(8, 59))
    assert po.in_preopen(at(9, 0))
    assert po.in_preopen(at(9, 8))      # entry closed, auction still matching
    assert po.in_preopen(at(9, 14))
    assert not po.in_preopen(at(9, 15))  # options trade from here


def test_a_gap_down_is_a_puts_morning_and_a_gap_up_a_calls():
    q = {"COFORGE": {"pc": 1900.0, "ltp": 1750.0},
         "INFY": {"pc": 1500.0, "ltp": 1620.0}}
    rows = {r["sym"]: r for r in po.gap_rows(q, 3.0)}
    assert rows["COFORGE"]["side"] == "PE"
    assert rows["COFORGE"]["gap_pct"] == pytest.approx(-7.89, abs=0.01)
    assert rows["INFY"]["side"] == "CE"


def test_the_biggest_mover_is_named_first_whichever_way_it_went():
    q = {"A": {"pc": 100.0, "ltp": 104.0},
         "B": {"pc": 100.0, "ltp": 88.0},
         "C": {"pc": 100.0, "ltp": 106.0}}
    assert [r["sym"] for r in po.gap_rows(q, 3.0)] == ["B", "C", "A"]


def test_a_quiet_name_is_not_reported():
    q = {"FLAT": {"pc": 100.0, "ltp": 101.0}}
    assert po.gap_rows(q, 3.0) == []
    assert len(po.gap_rows(q, 0.0)) == 1        # --all shows it


def test_an_unknown_previous_close_is_skipped_not_shown_as_no_gap():
    """An unknown gap is not a small one."""
    q = {"NOPC": {"pc": None, "ltp": 500.0},
         "NOLTP": {"pc": 500.0, "ltp": None},
         "ZERO": {"pc": 0.0, "ltp": 500.0}}
    assert po.gap_rows(q, 0.0) == []


def test_strike_intervals_widen_with_price():
    assert po.strike_step(80) == 2.5
    assert po.strike_step(300) == 10
    assert po.strike_step(1800) == 50
    assert po.strike_step(9000) == 200


def test_the_ladder_brackets_the_indicated_price():
    ladder = po.strike_ladder(1750.0)
    assert 1750 in ladder
    assert ladder == sorted(ladder) and len(ladder) == 5
    assert min(ladder) < 1750 < max(ladder)


def test_the_ladder_never_offers_a_strike_at_or_below_zero():
    assert all(s > 0 for s in po.strike_ladder(3.0))
    assert po.strike_ladder(0) == [] and po.strike_ladder(None) == []
