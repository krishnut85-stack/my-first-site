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


class _BatchDS:
    """A datasource that answers prices ONLY via a single batched call."""
    def __init__(self, alive):
        self._alive = set(alive)
        self.batch_calls = 0

    def last_prices(self, symbols):
        self.batch_calls += 1
        return {s: (100.0 if s in self._alive else 0.0) for s in symbols}

    def last_price(self, symbol):  # pragma: no cover - must not be used
        raise AssertionError("audit must batch, not call last_price per symbol")


def test_audit_uses_one_batched_call_and_flags_dead():
    instruments.reload_universe()
    # mark every symbol alive except GESHIP
    universe = instruments._universe()
    alive = [s for syms in universe.values() for s in syms if s != "GESHIP"]
    ds = _BatchDS(alive)
    report = instruments.audit_universe(ds=ds)
    assert ds.batch_calls == 1  # exactly one batched fetch, no per-symbol storm
    shipping = next(r for r in report["industries"] if r["industry"] == "Shipping")
    status = {c["symbol"]: c["alive"] for c in shipping["checked"]}
    assert status["GESHIP"] is False and status["SCI"] is True


def test_batch_prices_falls_back_when_no_last_prices():
    class _PerSymbolDS:
        def last_price(self, symbol):
            return 50.0
    out = instruments._batch_prices(_PerSymbolDS(), ["A", "B"])
    assert out == {"A": 50.0, "B": 50.0}
