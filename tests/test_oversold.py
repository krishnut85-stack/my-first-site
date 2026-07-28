"""Tests for the RSI indicator and the F&O oversold screener (offline)."""

from sectorbot.indicators import rsi
from sectorbot.oversold import (fo_underlyings_fallback, fo_underlyings_from_kite,
                                format_screen, run_screen)


def test_rsi_needs_enough_history():
    assert rsi([100.0] * 10, period=14) is None


def test_rsi_all_gains_is_100():
    closes = [100.0 + i for i in range(30)]
    assert rsi(closes) == 100.0


def test_rsi_all_losses_is_low():
    closes = [200.0 - i for i in range(30)]
    assert rsi(closes) < 5


def test_rsi_flat_then_selloff_is_oversold():
    closes = [100.0] * 20 + [98, 95, 92, 90, 88, 85, 83, 80]
    value = rsi(closes)
    assert value is not None and value < 30


def test_fallback_universe_loads_and_looks_sane():
    symbols = fo_underlyings_fallback()
    assert len(symbols) > 150
    assert "RELIANCE" in symbols and "SBIN" in symbols
    assert symbols == sorted(symbols)


def test_fo_underlyings_from_kite_skips_indices():
    class FakeKite:
        def instruments(self, exchange):
            assert exchange == "NFO"
            return [
                {"name": "NIFTY", "segment": "NFO-FUT"},
                {"name": "BANKNIFTY", "segment": "NFO-FUT"},
                {"name": "RELIANCE", "segment": "NFO-FUT"},
                {"name": "RELIANCE", "segment": "NFO-OPT"},
                {"name": "TCS", "segment": "NFO-FUT"},
            ]

    assert fo_underlyings_from_kite(FakeKite()) == ["RELIANCE", "TCS"]


def test_run_screen_classifies_and_sorts(monkeypatch):
    from sectorbot import oversold as mod

    series = {
        "DEEPRED": [200.0 - 3 * i for i in range(30)],   # heavy selloff -> oversold
        "MILDRED": [100.0] * 40 + [99.2, 98.5, 98.0, 97.2, 96.8, 96.0],
        "GREEN": [100.0 + i for i in range(30)],          # uptrend -> high RSI
        "DEAD": [],                                        # no data -> failed
    }
    monkeypatch.setattr(mod, "fo_underlyings_fallback",
                        lambda: sorted(series))
    monkeypatch.setattr(mod, "closes_from_yahoo", lambda s: series[s])

    result = run_screen(source="yahoo", verbose=False)
    assert result["source"] == "yahoo"
    assert result["failed"] == ["DEAD"]
    assert result["checked"] == 3
    oversold_syms = [r["symbol"] for r in result["oversold"]]
    assert "DEEPRED" in oversold_syms
    assert "GREEN" not in oversold_syms
    # sorted most-oversold first
    rsis = [r["rsi"] for r in result["oversold"]]
    assert rsis == sorted(rsis)
    # the report renders without blowing up and names the oversold stock
    text = format_screen(result)
    assert "DEEPRED" in text and "OVERSOLD" in text
