"""Tests for the ATR indicator."""

from sectorbot.indicators import Bar, atr, true_range


def test_true_range_uses_widest_span():
    bar = Bar(high=110, low=100, close=105)
    # prev_close far below low -> gap dominates
    assert true_range(bar, prev_close=90) == 20  # 110 - 90


def test_atr_zero_without_enough_history():
    bars = [Bar(10, 9, 9.5) for _ in range(5)]
    assert atr(bars, period=14) == 0.0


def test_atr_constant_range_series():
    # every bar spans exactly 2.0 and closes flat -> ATR converges to ~2.0
    bars = [Bar(high=102, low=100, close=101) for _ in range(40)]
    result = atr(bars, period=14)
    assert 1.5 <= result <= 2.5


def test_atr_positive_on_real_history():
    from sectorbot.datasource import PaperDataSource

    ds = PaperDataSource()
    bars = ds.history("HINDALCO", 60)
    assert atr(bars, 14) > 0
