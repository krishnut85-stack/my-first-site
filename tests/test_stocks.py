"""Tests for Mayura's stock-level smart scoring (more Trendlyne data)."""

from sectorbot import config, instruments
from sectorbot.stocks import resolve_columns, score_row


def test_resolve_columns_matches_aliases():
    cols = resolve_columns(["NSE Code", "Industry", "Durability Score",
                            "Valuation", "Momentum Score", "PE TTM",
                            "Delivery Volume %", "RSI"])
    assert cols["durability"] == "Durability Score"
    assert cols["valuation"] == "Valuation"
    assert cols["momentum"] == "Momentum Score"
    assert cols["pe"] == "PE TTM"
    assert cols["delivery"] == "Delivery Volume %"
    assert cols["rsi"] == "RSI"


def test_score_row_uses_dvm():
    cols = resolve_columns(["Durability", "Valuation", "Momentum"])
    strong = score_row({"Durability": "90", "Valuation": "80", "Momentum": "95"}, cols)
    weak = score_row({"Durability": "20", "Valuation": "30", "Momentum": "10"}, cols)
    assert strong is not None and weak is not None
    assert strong > weak
    assert 0 <= weak <= 100 and 0 <= strong <= 100


def test_score_row_none_when_no_signals():
    cols = resolve_columns(["Symbol", "Industry"])  # nothing scoreable
    assert score_row({"Symbol": "X", "Industry": "Y"}, cols) is None


def test_stock_universe_ranks_by_smart_score(tmp_path, monkeypatch):
    # A stock export WITH DVM columns: stocks must rank by smart score, not by
    # file order — the high-DVM name comes first even if listed last.
    csv = tmp_path / "universe.csv"
    csv.write_text(
        "NSE Code,Industry,Durability,Valuation,Momentum\n"
        "WEAKO,Banks,20,25,15\n"
        "MIDO,Banks,55,50,60\n"
        "STRONGO,Banks,95,85,98\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(config, "UNIVERSE_CSV", csv)
    instruments.reload_universe()
    assert instruments.universe_source() == "universe.csv"
    assert instruments.has_stock_signals() is True
    assert instruments.symbols_for("Banks") == ["STRONGO", "MIDO", "WEAKO"]
    assert instruments.stock_score("STRONGO") > instruments.stock_score("WEAKO")
    instruments.reload_universe()  # reset cache for other tests


def test_liquidity_sort_still_works_without_signals(tmp_path, monkeypatch):
    # No DVM/technical columns -> must fall back to liquidity sort (unchanged).
    csv = tmp_path / "universe.csv"
    csv.write_text(
        "Symbol,Industry,Market Cap\n"
        "SMALLB,Banks,100\nBIGBANK,Banks,900\nMIDBANK,Banks,500\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(config, "UNIVERSE_CSV", csv)
    instruments.reload_universe()
    assert instruments.has_stock_signals() is False
    assert instruments.symbols_for("Banks") == ["BIGBANK", "MIDBANK", "SMALLB"]
    instruments.reload_universe()
