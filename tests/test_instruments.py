"""Tests for the data-driven tradeable universe loader."""

from sectorbot import config, instruments


def test_default_universe_loads_from_shipped_csv():
    instruments.reload_universe()
    assert instruments.universe_source() == "industry_symbols.csv"
    assert instruments.symbols_for("Shipping") == ["GESHIP", "SCI", "COCHINSHIP"]


def test_unmapped_industry_returns_empty():
    instruments.reload_universe()
    assert instruments.symbols_for("Totally Made Up Industry") == []


def test_stock_level_universe_csv_groups_and_sorts_by_liquidity(tmp_path, monkeypatch):
    # a stock-level export with a Market Cap column -> grouped by Industry,
    # most-liquid first, and it takes priority over the shipped CSV.
    csv = tmp_path / "universe.csv"
    csv.write_text(
        "Symbol,Industry,Market Cap\n"
        "SMALLB,Banks,100\n"
        "BIGBANK,Banks,900\n"
        "MIDBANK,Banks,500\n"
        "ONLYPHARMA,Pharma,250\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(config, "UNIVERSE_CSV", csv)
    instruments.reload_universe()
    assert instruments.universe_source() == "universe.csv"
    # sorted by market cap descending
    assert instruments.symbols_for("Banks") == ["BIGBANK", "MIDBANK", "SMALLB"]
    assert instruments.symbols_for("Pharma") == ["ONLYPHARMA"]
    instruments.reload_universe()  # reset cache for other tests


def test_audit_reports_coverage_holes(monkeypatch):
    instruments.reload_universe()
    report = instruments.audit_universe(ds=None)
    assert "industries" in report and "coverage_holes" in report
    # every reported industry has a 'mapped' count
    assert all("mapped" in row for row in report["industries"])
