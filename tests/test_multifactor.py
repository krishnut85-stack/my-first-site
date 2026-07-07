"""Tests for Solaimalai: quant multi-factor compositing + special situations."""

from sectorbot import filings, technicals as T
from sectorbot.filings import Announcement
from sectorbot.indicators import Bar


def _bar(close, vol=1000.0):
    return Bar(high=close * 1.01, low=close * 0.99, close=close, volume=vol)


def _uptrend(n=260, start=100.0, step=0.5):
    return [_bar(start + i * step) for i in range(n)]


# --- raw_factors -----------------------------------------------------------
def test_raw_factors_keys():
    f = T.raw_factors(_uptrend(), _uptrend(260, 100, 0.1))
    assert set(f) == {"momentum", "lowvol", "trend", "vcp", "rs"}
    assert f["momentum"] > 0 and f["trend"] > 0


def test_raw_factors_short_history_none():
    assert T.raw_factors([_bar(100) for _ in range(10)]) is None


# --- composite_zscore ------------------------------------------------------
def test_composite_ranks_best_highest():
    rows = [
        {"symbol": "BEST", "factors": {"momentum": 0.5, "lowvol": -0.1, "trend": 100}},
        {"symbol": "MID", "factors": {"momentum": 0.2, "lowvol": -0.2, "trend": 60}},
        {"symbol": "WORST", "factors": {"momentum": -0.1, "lowvol": -0.5, "trend": 10}},
    ]
    w = {"momentum": 0.4, "lowvol": 0.2, "trend": 0.4}
    scores = T.composite_zscore(rows, w)
    assert scores["BEST"] > scores["MID"] > scores["WORST"]
    assert scores["BEST"] == 100.0          # top percentile


def test_composite_handles_missing_factors():
    rows = [
        {"symbol": "A", "factors": {"momentum": 0.3, "trend": None}},
        {"symbol": "B", "factors": {"momentum": 0.1, "trend": 50}},
    ]
    scores = T.composite_zscore(rows, {"momentum": 0.5, "trend": 0.5})
    assert scores["A"] >= scores["B"]       # A wins on the one factor it has


def test_composite_empty():
    assert T.composite_zscore([], {"momentum": 1.0}) == {}


# --- special situations ----------------------------------------------------
def _ann(subject):
    return Announcement(symbol="X", date="2026-06-26", subject=subject)


def test_special_buyback_and_demerger():
    anns = [_ann("Board approves buyback of equity shares"),
            _ann("Approval of scheme of arrangement (demerger)")]
    tags = filings.special_situations(anns)
    assert "buyback" in tags and "demerger" in tags


def test_special_promoter_buying():
    tags = filings.special_situations([_ann("Increase in promoter shareholding")])
    assert "promoter-buying" in tags


def test_special_none():
    assert filings.special_situations([_ann("Intimation of board meeting")]) == []


def test_assess_includes_special_field():
    out = filings.assess([_ann("Board approves buyback")])
    assert "special" in out and "buyback" in out["special"]


def test_assess_symbol_special_via_fetcher():
    out = filings.assess_symbol(
        "Z", fetcher=lambda s: [_ann("Composite scheme of arrangement / demerger")])
    assert "demerger" in out["special"]
