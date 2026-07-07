"""drop_today() removes a trailing partial bar so morning signals use the last
settled session (yesterday), not today's half-formed candle."""

from sectorbot import technicals as T
from sectorbot.indicators import Bar


def _b(close, d=""):
    return Bar(high=close, low=close, close=close, volume=1.0, date=d)


def test_drops_trailing_today_bar():
    bars = [_b(100, "2026-06-26"), _b(101, "2026-06-29")]
    out = T.drop_today(bars, "2026-06-29")
    assert len(out) == 1 and out[-1].close == 100      # today's bar removed


def test_keeps_when_last_bar_is_not_today():
    bars = [_b(100, "2026-06-25"), _b(101, "2026-06-26")]
    out = T.drop_today(bars, "2026-06-29")
    assert len(out) == 2                                # nothing to drop


def test_no_dates_is_noop():
    bars = [_b(100), _b(101)]                           # synthetic bars, no dates
    assert T.drop_today(bars, "2026-06-29") == bars


def test_empty():
    assert T.drop_today([], "2026-06-29") == []
