"""Tests for the OHLC technical engine (sectorbot/technicals.py)."""

from sectorbot import technicals as T
from sectorbot.indicators import Bar


def _bar(close, vol=0.0, hi=None, lo=None):
    return Bar(high=hi if hi is not None else close * 1.01,
               low=lo if lo is not None else close * 0.99,
               close=close, volume=vol)


def _uptrend(n=260, start=100.0, step=0.5):
    return [_bar(start + i * step, vol=1000) for i in range(n)]


def _downtrend(n=260, start=230.0, step=0.5):
    return [_bar(start - i * step, vol=1000) for i in range(n)]


# --- trend template / stage 2 ----------------------------------------------
def test_trend_template_uptrend_high():
    tt = T.trend_template(_uptrend())
    assert tt["score"] >= 85 and tt["met"] >= 6


def test_trend_template_downtrend_low():
    tt = T.trend_template(_downtrend())
    assert tt["score"] <= 30


def test_is_stage2():
    assert T.is_stage2(_uptrend()) is True
    assert T.is_stage2(_downtrend()) is False


# --- VCP -------------------------------------------------------------------
def _seg(lows, vol):
    """15 bars at ~100 high, with the given list of intrabar lows placed early."""
    bars = []
    for i in range(15):
        lo = lows[i] if i < len(lows) else 99.0
        bars.append(_bar(close=99.8, vol=vol, hi=100.0, lo=lo))
    return bars


def test_vcp_detects_contraction():
    # drawdowns 10% -> 6% -> 2.5%, volume drying up, price near pivot.
    bars = (_seg([90.0], 1000) + _seg([94.0], 800)
            + [_bar(close=99.8, vol=500, hi=100.0, lo=97.5) for _ in range(15)])
    out = T.vcp(bars)
    assert out["is_vcp"] is True
    assert out["score"] >= 70
    assert out["vol_dryup"] is True


def test_vcp_rejects_expanding():
    # drawdowns EXPANDING (2.5% -> 6% -> 10%): not a VCP.
    bars = ([_bar(close=99.8, vol=500, hi=100.0, lo=97.5) for _ in range(15)]
            + _seg([94.0], 800) + _seg([90.0], 1000))
    out = T.vcp(bars)
    assert out["is_vcp"] is False


def test_vcp_needs_enough_bars():
    assert T.vcp([_bar(100) for _ in range(10)])["is_vcp"] is False


# --- factors ---------------------------------------------------------------
def test_momentum_positive_in_uptrend():
    assert T.momentum(_uptrend()) > 0


def test_momentum_negative_in_downtrend():
    assert T.momentum(_downtrend()) < 0


def test_relative_strength_outperformer():
    fast = [_bar(100 + i * 1.0) for i in range(150)]
    slow = [_bar(100 + i * 0.2) for i in range(150)]
    assert T.relative_strength(fast, slow) > 0


def test_volatility_lower_for_smooth_series():
    smooth = _uptrend(80)
    jumpy = [_bar(100 + (5 if i % 2 else -5) + i * 0.5) for i in range(80)]
    assert T.volatility_pct(smooth) < T.volatility_pct(jumpy)


# --- composite + levels ----------------------------------------------------
def test_thanikesa_score_uptrend_beats_downtrend():
    idx = _uptrend(260, start=100, step=0.1)
    up = T.thanikesa_score(_uptrend(), idx)
    down = T.thanikesa_score(_downtrend(), idx)
    assert up is not None and down is not None and up > down


def test_thanikesa_score_needs_history():
    assert T.thanikesa_score([_bar(100) for _ in range(10)]) is None


def test_levels_from_bars():
    s50, s200, dist = T.levels(_uptrend())
    assert s50 > s200 > 0          # rising series: 50-DMA above 200-DMA
    assert 0 <= dist < 5           # last bar is at/near the 52-week high


def test_scorer_registry():
    assert T.SCORERS_OHLC["thanikesa"] is T.thanikesa_score
