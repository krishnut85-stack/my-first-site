"""Tests for the market-regime filter (trend overlay)."""

from sectorbot import config
from sectorbot.datasource import PaperDataSource
from sectorbot.indicators import Bar
from sectorbot.regime import market_in_uptrend


class _FakeDS:
    """A non-synthetic datasource that returns a fixed close series."""
    def __init__(self, closes):
        self._closes = closes

    def last_price(self, symbol):  # pragma: no cover - unused here
        return self._closes[-1]

    def history(self, symbol, bars):
        return [Bar(high=c, low=c, close=c) for c in self._closes[-bars:]]


def _series(n, last):
    """n-1 closes at 100, final close = `last` (so SMA ~= 100)."""
    return [100.0] * (n - 1) + [last]


def test_uptrend_when_index_above_its_average():
    closes = _series(config.REGIME_SMA + 5, last=120.0)
    assert market_in_uptrend(_FakeDS(closes)) is True


def test_downtrend_when_index_below_its_average():
    closes = _series(config.REGIME_SMA + 5, last=80.0)
    assert market_in_uptrend(_FakeDS(closes)) is False


def test_fail_open_on_insufficient_history():
    # fewer than REGIME_SMA bars -> cannot judge -> allow trading (default True)
    assert market_in_uptrend(_FakeDS([100.0, 101.0, 99.0])) is True


def test_fail_open_with_default_false():
    assert market_in_uptrend(_FakeDS([100.0]), default=False) is False


def test_synthetic_datasource_is_fail_open():
    # synthetic prices have no real index -> never gate on a fabricated trend
    assert market_in_uptrend(PaperDataSource()) is True
