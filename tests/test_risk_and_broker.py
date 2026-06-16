from datetime import time

from algotrade.brokers.base import Order, OrderStatus, Position, Side
from algotrade.brokers.paper import PaperBroker
from algotrade.risk import RiskLimits, RiskManager, TrailingStop


def make_broker(price=100.0):
    return PaperBroker(quote_fn=lambda s: price, slippage_bps=0, cost_per_order=0)


def test_position_open_add_reduce_flip():
    pos = Position(symbol="X")
    pos.apply_fill(Side.BUY, 75, 100.0)
    pos.apply_fill(Side.BUY, 75, 110.0)
    assert pos.quantity == 150
    assert pos.avg_price == 105.0
    pos.apply_fill(Side.SELL, 75, 120.0)
    assert pos.realized_pnl == 75 * 15.0
    pos.apply_fill(Side.SELL, 150, 100.0)  # close 75, flip short 75
    assert pos.quantity == -75
    assert pos.avg_price == 100.0


def test_paper_broker_fill_and_pnl():
    broker = make_broker(100.0)
    order = broker.place_order(Order(symbol="X", side=Side.BUY, quantity=75))
    assert order.status is OrderStatus.FILLED
    assert broker.total_pnl() == 0.0


def test_risk_rejects_non_lot_quantity():
    risk = RiskManager(RiskLimits(), lot_size=75)
    broker = make_broker()
    assert not risk.approve(Order(symbol="X", side=Side.BUY, quantity=70), broker)
    assert risk.approve(Order(symbol="X", side=Side.BUY, quantity=75), broker)


def test_risk_kill_switch_latches():
    risk = RiskManager(RiskLimits(max_daily_loss=1_000), lot_size=75)
    broker = make_broker(100.0)
    broker.place_order(Order(symbol="X", side=Side.BUY, quantity=75))
    broker._quote_fn = lambda s: 80.0  # -1500 unrealized
    assert risk.check_daily_loss(broker)
    assert risk.kill_switch
    # New entries blocked, exits allowed.
    assert not risk.approve(Order(symbol="X", side=Side.BUY, quantity=75), broker)
    assert risk.approve(
        Order(symbol="X", side=Side.SELL, quantity=75), broker, is_exit=True
    )


def test_position_sizing():
    risk = RiskManager(
        RiskLimits(capital=200_000, risk_per_trade_pct=1.0, max_open_lots=5),
        lot_size=75,
    )
    # 2000 rupees risk / (100 pts * 75) -> 0 lots; 20 pts -> 1 lot
    assert risk.position_size_lots(100.0) == 0
    assert risk.position_size_lots(20.0) == 1
    assert risk.position_size_lots(0.5) == 5  # capped at max_open_lots


def test_trading_windows():
    risk = RiskManager(RiskLimits(), lot_size=75)
    assert not risk.in_entry_window(time(9, 16))
    assert risk.in_entry_window(time(10, 0))
    assert not risk.in_entry_window(time(15, 5))
    assert risk.should_square_off(time(15, 13))


def test_trailing_stop_long():
    ts = TrailingStop(entry_price=100, is_long=True, initial_stop=95, trail_pct=0.02)
    assert not ts.update(104)          # ratchets stop to ~101.92
    assert ts.stop > 95
    assert not ts.update(103)
    assert ts.update(101.5)            # below trailed stop -> hit


def test_trailing_stop_short():
    ts = TrailingStop(entry_price=100, is_long=False, initial_stop=105, trail_pct=0.02)
    assert not ts.update(96)
    assert ts.stop < 105
    assert ts.update(98.5)
