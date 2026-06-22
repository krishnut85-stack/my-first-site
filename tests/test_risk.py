"""Tests for the exit rules in risk.py."""

from sectorbot import config
from sectorbot.risk import PositionState, decide_exit


def test_hard_stop_loss():
    s = PositionState("X", entry_price=100, qty=10)
    exit_, reason = decide_exit(s, 89)  # -11% < -10%
    assert exit_ and "stop-loss" in reason


def test_take_profit():
    s = PositionState("Y", entry_price=100, qty=10)
    exit_, reason = decide_exit(s, 126)  # +26% > +25%
    assert exit_ and "take-profit" in reason


def test_no_exit_in_normal_range():
    s = PositionState("Z", entry_price=100, qty=10)
    exit_, _ = decide_exit(s, 103)  # small gain, nothing triggers
    assert not exit_


def test_trailing_stop_locks_profit():
    s = PositionState("T", entry_price=100, qty=10)
    decide_exit(s, 115)              # peak rises, arms trailing (+15% > 8%)
    exit_, reason = decide_exit(s, 109)  # 5.2% off the 115 peak
    assert exit_ and "trailing" in reason


def test_trailing_not_armed_below_threshold():
    s = PositionState("U", entry_price=100, qty=10)
    decide_exit(s, 105)              # only +5%, trailing not armed (needs 8%)
    exit_, _ = decide_exit(s, 101)   # would be a drop from peak but not armed
    assert not exit_


def test_atr_stop_when_tightest():
    # atr=2, mult 2.5 -> stop at 95 (-5%), tighter than the 10% hard SL
    s = PositionState("V", entry_price=100, qty=10, atr=2)
    exit_, reason = decide_exit(s, 94)
    assert exit_ and "ATR" in reason


def test_peak_tracks_high_water_mark():
    s = PositionState("W", entry_price=100, qty=10)
    decide_exit(s, 120)
    decide_exit(s, 110)
    assert s.peak_price == 120
