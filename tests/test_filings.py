"""Tests for the Swaminatha NSE/BSE filings reader (sectorbot/filings.py).

All offline: the classifier and aggregation are pure, and assess_symbol takes an
injectable fetcher so no network is touched.
"""

from sectorbot import filings
from sectorbot.filings import Announcement


def _ann(subject, detail=""):
    return Announcement(symbol="X", date="2026-06-26", subject=subject, detail=detail)


# --- classify --------------------------------------------------------------
def test_classify_bullish_order_win():
    v, bull, bear, _ = filings.classify("Company bags order worth Rs 500 crore")
    assert v == "bullish" and bull >= 2 and bear == 0


def test_classify_bullish_approval():
    v, *_ = filings.classify("Receives USFDA approval for new drug")
    assert v == "bullish"


def test_classify_bearish_sebi():
    v, bull, bear, _ = filings.classify("SEBI show cause notice issued to company")
    assert v == "bearish" and bear >= 3


def test_classify_bearish_auditor_resignation():
    v, _, bear, _ = filings.classify("Intimation regarding resignation of auditor")
    assert v == "bearish" and bear >= 5


def test_classify_red_flag_beats_bullish():
    # Even with a bullish word, a strong red flag must block.
    v, *_ = filings.classify("Bags order but promoter pledged shares; invocation of pledge")
    assert v == "bearish"


def test_classify_neutral_routine():
    v, bull, bear, _ = filings.classify("Intimation of board meeting under regulation 29")
    assert v == "neutral" and bull == 0 and bear == 0


# --- assess (aggregate) ----------------------------------------------------
def test_assess_bearish_wins_over_bullish():
    anns = [_ann("Bags order worth Rs 100 crore"),
            _ann("Auditor resignation intimation")]
    out = filings.assess(anns)
    assert out["verdict"] == "bearish"


def test_assess_bullish_when_only_good_news():
    anns = [_ann("Interim dividend declared"),
            _ann("Bags order worth Rs 100 crore")]
    out = filings.assess(anns)
    assert out["verdict"] == "bullish"
    assert "order" in out["headline"].lower()


def test_assess_empty_is_neutral():
    assert filings.assess([])["verdict"] == "neutral"


def test_assess_pure_noise_is_neutral():
    anns = [_ann("Trading window closure intimation"),
            _ann("Newspaper publication of results")]
    assert filings.assess(anns)["verdict"] == "neutral"


# --- assess_symbol with injected fetcher (no network) ----------------------
def test_assess_symbol_unknown_on_empty_fetch():
    out = filings.assess_symbol("FOO", fetcher=lambda s: [])
    assert out["verdict"] == "unknown" and out["symbol"] == "FOO"


def test_assess_symbol_unknown_on_fetch_error():
    def boom(_):
        raise RuntimeError("blocked")
    out = filings.assess_symbol("BAR", fetcher=boom)
    assert out["verdict"] == "unknown"


def test_assess_symbol_bullish_via_fetcher():
    out = filings.assess_symbol(
        "BAZ", fetcher=lambda s: [_ann("Bags order worth Rs 50 crore")])
    assert out["verdict"] == "bullish" and out["symbol"] == "BAZ"


# --- gate ------------------------------------------------------------------
def test_gate_buckets_and_order():
    verdicts = {
        "A": {"verdict": "bullish"},
        "B": {"verdict": "bearish"},
        "C": {"verdict": "neutral"},
        "D": {"verdict": "unknown"},
        "E": {"verdict": "bullish"},
    }
    g = filings.gate(verdicts)
    assert g["buy"] == ["A", "E"]      # only bullish, order preserved
    assert g["blocked"] == ["B"]
    assert g["neutral"] == ["C"]
    assert g["unknown"] == ["D"]


def test_gate_empty():
    g = filings.gate({})
    assert g == {"buy": [], "blocked": [], "neutral": [], "unknown": []}
