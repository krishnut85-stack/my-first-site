"""Tests for the Swaminatha news face: Gemini judge parsing + buy logic +
candidate pre-filter + liquidity gate. All offline (Gemini POST injected)."""

from sectorbot import config, filings, gemini
from sectorbot.filings import Announcement


def _resp(text):
    """Shape a fake Gemini generateContent response carrying `text`."""
    return {"candidates": [{"content": {"parts": [{"text": text}]}}]}


# --- Gemini response parsing ----------------------------------------------
def test_judge_parses_clean_json(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "x")
    post = lambda payload: _resp(
        '{"verdict":"bullish","material":true,"confidence":0.82,"reason":"big order"}')
    v = gemini.judge_news("TRANSRAIL", "Transrail", "459cr order", _post=post)
    assert v["verdict"] == "bullish" and v["material"] is True
    assert v["confidence"] == 0.82 and "order" in v["reason"]


def test_judge_handles_json_wrapped_in_prose(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "x")
    post = lambda payload: _resp(
        'Here is my view:\n```json\n{"verdict":"neutral","material":false,'
        '"confidence":0.3,"reason":"small"}\n```')
    v = gemini.judge_news("X", "X Co", "tiny order", _post=post)
    assert v["verdict"] == "neutral" and v["material"] is False


def test_judge_none_without_key(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "")
    assert gemini.judge_news("X", "X", "news") is None


def test_judge_none_on_post_error(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "x")
    def boom(_):
        raise RuntimeError("503")
    assert gemini.judge_news("X", "X", "news", _post=boom) is None


def test_judge_none_on_garbage(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "x")
    assert gemini.judge_news("X", "X", "news",
                             _post=lambda p: _resp("no json here")) is None


# --- buy decision ----------------------------------------------------------
def test_is_buy_requires_bullish_material_sound_confident(monkeypatch):
    monkeypatch.setattr(config, "NEWS_MIN_CONFIDENCE", 0.6)
    ok = {"verdict": "bullish", "material": True, "financially_sound": True,
          "confidence": 0.7}
    assert gemini.is_buy(ok)
    assert not gemini.is_buy({**ok, "confidence": 0.5})           # low conviction
    assert not gemini.is_buy({**ok, "material": False})           # not material
    assert not gemini.is_buy({**ok, "financially_sound": False})  # weak company -> trap
    assert not gemini.is_buy({**ok, "verdict": "neutral"})        # not bullish
    assert not gemini.is_buy(None)


def test_search_grounding_in_payload(monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "x")
    monkeypatch.setattr(config, "GEMINI_USE_SEARCH", True)
    seen = {}
    def capture(payload):
        seen.update(payload)
        return _resp('{"verdict":"neutral","material":false,"confidence":0.1,"reason":"x"}')
    gemini.judge_news("X", "X", "news", _post=capture)
    assert seen.get("tools") == [{"google_search": {}}]


# --- candidate pre-filter --------------------------------------------------
def test_is_candidate_order_win():
    a = Announcement("TRANSRAIL", "2026-06-26", "Order Win",
                     "secures international T&D orders worth Rs 459 crore")
    assert filings.is_candidate(a) is True


def test_is_candidate_buyback_special():
    a = Announcement("X", "2026-06-26", "Buyback", "Board approves buyback of shares")
    assert filings.is_candidate(a) is True


def test_is_candidate_skips_routine():
    a = Announcement("X", "2026-06-26", "Board Meeting",
                     "Intimation of board meeting under regulation 29")
    assert filings.is_candidate(a) is False
