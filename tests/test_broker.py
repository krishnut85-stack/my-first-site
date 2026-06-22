"""Tests for the simulated PaperBroker, including unlimited mode."""

from sectorbot.paper_broker import PaperBroker


def test_buy_reduces_cash_and_opens_position():
    b = PaperBroker(10_000)
    assert b.buy("ABC", 10, 100)  # 1000 spent
    assert b.cash == 9_000
    assert b.positions["ABC"].qty == 10
    assert b.invested == 1_000


def test_buy_rejected_when_insufficient_cash_fixed_mode():
    b = PaperBroker(500)
    assert not b.buy("ABC", 10, 100)  # needs 1000, only 500
    assert "ABC" not in b.positions


def test_unlimited_mode_ignores_cash():
    b = PaperBroker(0, unlimited=True)
    assert b.buy("ABC", 100, 500)  # 50,000 with zero starting cash
    assert b.positions["ABC"].qty == 100
    assert b.invested == 50_000


def test_average_price_on_add():
    b = PaperBroker(100_000)
    b.buy("ABC", 10, 100)
    b.buy("ABC", 10, 200)
    assert b.positions["ABC"].avg_price == 150
    assert b.positions["ABC"].qty == 20


def test_sell_closes_position_and_realises_pnl():
    b = PaperBroker(10_000)
    b.buy("ABC", 10, 100)
    assert b.sell("ABC", 10, 130)
    assert "ABC" not in b.positions
    # cash: 10000 - 1000 + 1300 = 10300
    assert b.cash == 10_300


def test_equity_and_pnl():
    b = PaperBroker(10_000)
    b.buy("ABC", 10, 100)
    price_of = lambda s: 120.0
    assert b.equity(price_of) == 9_000 + 10 * 120  # cash + holdings = 10_200
    assert b.total_pnl(price_of) == 200
