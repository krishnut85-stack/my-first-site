"""Cost-control tests for Swaminatha: order-value floor, dedupe, daily cap."""

import mayura
from sectorbot import config, filings
from sectorbot.filings import Announcement


def _ann(subject, detail=""):
    return Announcement("X", "2026-06-26", subject, detail)


# --- order value extraction ------------------------------------------------
def test_order_value_basic():
    assert filings.order_value_cr("orders worth Rs 459 crore") == 459.0
    assert filings.order_value_cr("Rs. 1,200 cr contract") == 1200.0
    assert filings.order_value_cr("₹50cr deal") == 50.0


def test_order_value_lakh_crore():
    assert filings.order_value_cr("project worth 1.5 lakh crore") == 150000.0


def test_order_value_none_when_absent():
    assert filings.order_value_cr("receives USFDA approval") is None


def test_order_value_picks_largest():
    assert filings.order_value_cr("order of Rs 100 crore and Rs 459 crore") == 459.0


# --- value floor gate ------------------------------------------------------
def test_value_floor_skips_small_order():
    a = _ann("Order Win", "secures orders worth Rs 80 crore")
    assert filings.passes_value_floor(a, 100) is False


def test_value_floor_passes_big_order():
    a = _ann("Order Win", "secures orders worth Rs 459 crore")
    assert filings.passes_value_floor(a, 100) is True


def test_value_floor_passes_non_order_catalyst():
    # approvals / buybacks have no order value -> not gated, go to Gemini
    assert filings.passes_value_floor(_ann("US FDA Approval", "gets FDA nod"), 100)
    assert filings.passes_value_floor(_ann("Buyback", "approves buyback"), 100)


def test_value_floor_passes_order_without_number():
    a = _ann("Order Win", "bags order from NHAI")   # no rupee figure stated
    assert filings.passes_value_floor(a, 100) is True


# --- dedupe + daily cap persistence ---------------------------------------
def test_ann_id_stable_and_unique():
    a = _ann("Order Win", "Rs 459 cr")
    b = _ann("Order Win", "Rs 459 cr")
    c = _ann("Order Win", "Rs 460 cr")
    assert filings.ann_id(a) == filings.ann_id(b)
    assert filings.ann_id(a) != filings.ann_id(c)


def test_seen_news_roundtrip_and_prune(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "swaminatha").mkdir()
    mayura._save_seen_news({"old": "2000-01-01", "new": mayura.date.today().isoformat()})
    loaded = mayura._load_seen_news()
    assert "old" in loaded and "new" in loaded
    pruned = mayura._prune_seen_news(loaded, keep_days=5)
    assert "old" not in pruned and "new" in pruned        # old entry dropped


def test_gemini_daily_count_resets_each_day(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "swaminatha").mkdir()
    mayura._save_gemini_count(12)
    assert mayura._gemini_daily_count() == 12          # same day -> persists
    import json
    mayura._gemini_count_path().write_text(
        json.dumps({"date": "2000-01-01", "count": 99}))
    assert mayura._gemini_daily_count() == 0           # old day -> resets
