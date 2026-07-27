"""Tests for the Market Weather oracle (sectorbot/weather.py)."""

import json
from datetime import date, datetime, timedelta

from sectorbot import config, weather
from sectorbot.indicators import Bar


class _DS:
    def __init__(self, vix=15.0, closes=None):
        self._vix = vix
        self._closes = closes or [100.0] * 10

    def last_price(self, symbol):
        assert symbol == "INDIA VIX"
        return self._vix

    def history(self, symbol, bars):
        return [Bar(c + 1, c - 1, c) for c in self._closes]


# --- combine --------------------------------------------------------------
def test_combine_neutral_when_everything_quiet():
    w = weather.combine({"direction": 0, "gift_nifty_pct": 0.1, "reason": "flat"},
                        {"vix": 14.0, "nifty_chg1_pct": 0.1, "nifty_chg5_pct": 0.5})
    assert w["score"] == 0 and w["label"] == "NEUTRAL"
    assert w["size_factor"] == 1.0 and w["allow_new"]


def test_combine_down_day_halves_size():
    w = weather.combine({"direction": -1, "gift_nifty_pct": -0.6,
                         "reason": "GIFT Nifty down"}, {"vix": 16.0})
    assert w["score"] == -1 and w["size_factor"] == 0.5 and w["allow_new"]


def test_combine_strong_down_blocks_new_buys():
    w = weather.combine({"direction": -2, "reason": "global selloff"},
                        {"vix": 18.0})
    assert w["score"] == -2 and w["size_factor"] == 0.0 and not w["allow_new"]


def test_high_vix_drags_score_down():
    w = weather.combine({"direction": 0, "reason": "quiet"}, {"vix": 27.0})
    assert w["score"] == -1
    assert any("high fear" in r for r in w["reasons"])


def test_falling_week_drags_score_down():
    w = weather.combine({"direction": -1, "reason": "soft"},
                        {"vix": 15.0, "nifty_chg5_pct": -4.0})
    assert w["score"] == -2 and not w["allow_new"]


def test_rising_week_lifts_score_but_caps_at_2():
    w = weather.combine({"direction": 2, "reason": "rally"},
                        {"vix": 12.0, "nifty_chg5_pct": 4.0})
    assert w["score"] == 2 and w["size_factor"] == 1.0


def test_combine_without_gemini_uses_hard_data_only():
    w = weather.combine(None, {"vix": 26.0})
    assert w["score"] == -1
    assert any("unavailable" in r for r in w["reasons"])


# --- the dial (what the engine reads) --------------------------------------
def test_dial_neutral_when_no_weather():
    d = weather.dial(None)
    assert d["size"] == 1.0 and not d["block_new"] and d["info"] == ""


def test_dial_reads_fresh_verdict():
    w = weather.combine({"direction": -1, "reason": "soft open"}, {"vix": 15.0})
    d = weather.dial(w)
    assert d["size"] == 0.5 and not d["block_new"] and "DOWN" in d["info"]


def test_dial_ignores_stale_verdict():
    w = weather.combine({"direction": -2, "reason": "old news"}, {})
    w["ts"] = (datetime.now() - timedelta(hours=30)).isoformat(timespec="seconds")
    d = weather.dial(w)
    assert d["size"] == 1.0 and not d["block_new"]


def test_dial_ignores_yesterdays_verdict():
    w = weather.combine({"direction": -2, "reason": "yesterday"}, {})
    w["date"] = (date.today() - timedelta(days=1)).isoformat()
    assert weather.dial(w)["size"] == 1.0


# --- persistence ------------------------------------------------------------
def test_save_load_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setenv("MARKET_WEATHER_FILE", str(tmp_path / "w.json"))
    w = weather.combine({"direction": 1, "reason": "green"}, {"vix": 13.0})
    weather.save_weather(w)
    loaded = weather.load_weather()
    assert loaded["score"] == 1 and loaded["label"] == "UP"


def test_fetch_and_save_with_injected_gemini(tmp_path, monkeypatch):
    monkeypatch.setenv("MARKET_WEATHER_FILE", str(tmp_path / "w.json"))
    monkeypatch.setattr(config, "GEMINI_API_KEY", "test-key")
    fake = {"candidates": [{"content": {"parts": [{"text": json.dumps(
        {"direction": -1, "gift_nifty_pct": -0.8,
         "reason": "GIFT Nifty -0.8%, US closed red"})}]}}]}
    w = weather.fetch_and_save(_DS(vix=21.0), _post=lambda payload: fake)
    assert w["score"] == -1 and w["size_factor"] == 0.5
    assert json.loads((tmp_path / "w.json").read_text())["label"] == "DOWN"


# --- defensive mode (tightened trailing stops on hostile mornings) ----------
def test_combine_sets_trail_factor_by_score():
    up = weather.combine({"direction": 1, "reason": "green"}, {})
    down = weather.combine({"direction": -1, "reason": "soft"}, {})
    strong = weather.combine({"direction": -2, "reason": "selloff"}, {})
    assert up["trail_factor"] == 1.0
    assert down["trail_factor"] == 0.75
    assert strong["trail_factor"] == 0.5


def test_dial_passes_trail_factor_and_clamps():
    w = weather.combine({"direction": -2, "reason": "selloff"}, {})
    assert weather.dial(w)["trail"] == 0.5
    w["trail_factor"] = 0.01                      # corrupt file can't zero the trail
    assert weather.dial(w)["trail"] == 0.25
    assert weather.dial(None)["trail"] == 1.0     # fail-open


def test_defensive_trail_fires_earlier(monkeypatch):
    from sectorbot.risk import PositionState, decide_exit
    monkeypatch.setattr(config, "USE_TRAILING_STOP", True)
    monkeypatch.setattr(config, "TRAILING_ACTIVATE_PCT", 0.10)
    monkeypatch.setattr(config, "TRAILING_SL_PCT", 0.10)
    monkeypatch.setattr(config, "STOP_LOSS_PCT", 0.50)     # keep other rules quiet
    monkeypatch.setattr(config, "USE_ATR_STOP", False)

    def state():
        return PositionState("X", entry_price=100.0, qty=1, peak_price=120.0)

    # peak 120, price 113: a 5.8% dip off the peak — inside a normal 10% give
    monkeypatch.setattr(config, "WEATHER_TRAIL_FACTOR", 1.0)
    assert decide_exit(state(), 113.0)[0] is False
    # STRONG DOWN morning: give tightens to 5% → the same dip books the winner
    monkeypatch.setattr(config, "WEATHER_TRAIL_FACTOR", 0.5)
    fired, reason = decide_exit(state(), 113.0)
    assert fired and "defensive" in reason


# --- engine gating ----------------------------------------------------------
def test_engine_respects_weather_block(tmp_path, monkeypatch):
    from sectorbot.engine import run_paper_session
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "PAPER_CAPITAL", 1_000_000.0)
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "WEATHER_BLOCK_NEW", True)
    monkeypatch.setattr(config, "WEATHER_INFO", "STRONG DOWN (-2) — test")
    result = run_paper_session(verbose=False)
    assert result["entries"] == []                 # no new buys on a -2 morning
    assert result["weather_blocked"] is True
    assert "STRONG DOWN" in result["weather_info"]


def test_engine_halves_budget_on_down_day(tmp_path, monkeypatch):
    from sectorbot.engine import run_paper_session
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "PAPER_CAPITAL", 1_000_000.0)
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "WEATHER_SIZE_FACTOR", 0.5)
    half = run_paper_session(verbose=False)
    assert half["entries"], "still buys, just smaller"
    # each entry's cost must fit the HALVED per-name budget
    cap = (min(config.PAPER_CAPITAL * config.MAX_ALLOCATION_PER_NAME,
               config.PAPER_CAPITAL / max(config.MAX_POSITIONS, 1)) * 0.5)
    for _sym, price, qty in half["entries"]:
        assert qty * price <= cap + 1
