"""Livermore breakout-leader scorer: trade with the trend, at a pivotal breakout,
near the highs — and stand aside (None) otherwise."""

from sectorbot import technicals as T
from sectorbot.indicators import Bar


def _rising(n=260, start=100.0, step=0.4, vol=1000.0):
    """A clean Stage-2 uptrend making fresh highs into the last bar."""
    return [Bar(high=c + 0.5, low=c - 0.5, close=c, volume=vol)
            for c in (start + i * step for i in range(n))]


def _flat_index(n=260):
    return [Bar(high=100, low=100, close=100, volume=0.0) for _ in range(n)]


def test_scores_breakout_leader_high():
    bars = _rising()
    last = bars[-1]
    bars[-1] = Bar(high=last.high, low=last.low, close=last.close, volume=3000.0)  # volume surge
    s = T.livermore_score(bars, _flat_index())
    assert s is not None and s >= 60        # strong trend + breakout + RS + volume


def test_stands_aside_when_not_trending():
    flat = [Bar(high=100, low=99, close=100, volume=1000.0) for _ in range(260)]
    assert T.livermore_score(flat) is None   # no Stage-2 trend -> no trade


def test_stands_aside_far_from_high():
    base = _rising()[:-20]
    last = base[-1].close
    crash = [Bar(high=c, low=c, close=c, volume=1000.0)
             for c in (last * (1 - 0.02 * (i + 1)) for i in range(20))]
    assert T.livermore_score(base + crash) is None   # broke down -> stand aside


def test_breakout_helper():
    bars = _rising(n=60)
    broke, strength = T._new_high_breakout(bars)
    assert broke and strength > 0            # fresh series makes a new pivot high


def test_registered_in_scorers():
    assert "livermore" in T.SCORERS_OHLC
