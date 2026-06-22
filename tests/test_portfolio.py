"""Tests for the persistent paper Portfolio."""

from sectorbot import config
from sectorbot.portfolio import Portfolio


def test_buy_sell_and_cash():
    pf = Portfolio(starting_capital=100_000, cash=100_000)
    assert pf.buy("ABC", 10, 100, atr=2.0)
    assert pf.cash == 99_000
    assert pf.holdings["ABC"]["qty"] == 10
    pnl = pf.sell("ABC", 130)
    assert pnl == 300
    assert "ABC" not in pf.holdings
    assert pf.realized_pnl == 300


def test_buy_rejected_without_cash():
    pf = Portfolio(starting_capital=500, cash=500)
    assert not pf.buy("ABC", 10, 100)  # needs 1000
    assert pf.holdings == {}


def test_equity_and_unrealized():
    pf = Portfolio(starting_capital=100_000, cash=100_000)
    pf.buy("ABC", 10, 100)
    price_of = lambda s: 120.0
    assert pf.equity(price_of) == 99_000 + 10 * 120
    assert pf.unrealized_pnl(price_of) == 200


def test_save_and_load_roundtrip(tmp_path):
    path = tmp_path / "portfolio.json"
    pf = Portfolio(starting_capital=1_000_000, cash=1_000_000)
    pf.buy("XYZ", 5, 200, atr=3.0)
    pf.save(path)

    loaded = Portfolio.load(path)
    assert loaded.starting_capital == 1_000_000
    assert loaded.holdings["XYZ"]["qty"] == 5
    assert loaded.holdings["XYZ"]["atr"] == 3.0


def test_load_missing_file_uses_paper_capital(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PAPER_CAPITAL", 1_000_000.0)
    pf = Portfolio.load(tmp_path / "nope.json")
    assert pf.cash == 1_000_000.0
    assert pf.holdings == {}
