"""Tests for Thanikesa's pure-technical small-cap scorer (technical_score)."""

from sectorbot import config
from sectorbot.stocks import SCORERS, technical_score

CM = {
    "dist52": "dist52", "sma50": "sma50", "sma200": "sma200",
    "rs_qtr": "rs_qtr", "rsi": "rsi", "mfi": "mfi",
    "deliv_month": "dm", "deliv_6m": "d6",
}


def _row(**kw):
    base = {"dist52": "", "sma50": "", "sma200": "", "rs_qtr": "",
            "rsi": "", "mfi": "", "dm": "", "d6": ""}
    base.update({k: str(v) for k, v in kw.items()})
    return base


def test_registered_profile():
    assert SCORERS["technical"] is technical_score


def test_downtrend_is_rejected_low():
    # SMA50 below SMA200 => trend component 0 => weak score.
    down = technical_score(_row(sma50=90, sma200=100, dist52=5, rs_qtr=10, rsi=60), CM)
    up = technical_score(_row(sma50=110, sma200=100, dist52=5, rs_qtr=10, rsi=60), CM)
    assert down is not None and up is not None
    assert up > down


def test_near_high_beats_far_from_high():
    near = technical_score(_row(sma50=110, sma200=100, dist52=3, rs_qtr=10, rsi=60), CM)
    far = technical_score(_row(sma50=110, sma200=100, dist52=60, rs_qtr=10, rsi=60), CM)
    assert near > far


def test_relative_strength_helps():
    strong = technical_score(_row(sma50=110, sma200=100, dist52=10, rs_qtr=40, rsi=60), CM)
    weak = technical_score(_row(sma50=110, sma200=100, dist52=10, rs_qtr=0, rsi=60), CM)
    assert strong > weak


def test_parabolic_is_demoted():
    # Same proximity/RS, but a huge SMA gap (parabolic) should score lower via
    # the extension factor.
    fresh = technical_score(_row(sma50=105, sma200=100, dist52=8, rs_qtr=20, rsi=60), CM)
    parabolic = technical_score(_row(sma50=200, sma200=100, dist52=8, rs_qtr=20, rsi=60), CM)
    assert fresh > parabolic


def test_no_signals_returns_none():
    assert technical_score(_row(), CM) is None


def test_volume_spike_helps():
    spike = technical_score(
        _row(sma50=110, sma200=100, dist52=10, rs_qtr=10, rsi=60, dm=2.0, d6=1.0), CM)
    flat = technical_score(
        _row(sma50=110, sma200=100, dist52=10, rs_qtr=10, rsi=60, dm=1.0, d6=1.0), CM)
    assert spike >= flat
