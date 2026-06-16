"""Strategy interface and the context object strategies trade through."""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime

import pandas as pd

from ..brokers.base import Broker, Order, OrderStatus, Position, Side
from ..risk import RiskManager

log = logging.getLogger(__name__)


@dataclass
class Bar:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: int = 0


class Context:
    """What a strategy sees: quotes, history, positions, and risk-gated orders."""

    def __init__(self, broker: Broker, risk: RiskManager, history_fn=None,
                 notify_orders: bool = False):
        self.broker = broker
        self.risk = risk
        self._history_fn = history_fn
        self._notify_orders = notify_orders  # engine sets True; backtests stay quiet
        self.now: datetime = datetime.now()

    def ltp(self, symbol: str) -> float:
        return self.broker.ltp(symbol)

    def history(self, symbol: str, lookback_bars: int) -> pd.DataFrame:
        """OHLC history ending at `now`. Backtester serves this from its data."""
        if self._history_fn is None:
            raise RuntimeError("no history source configured")
        return self._history_fn(symbol, lookback_bars)

    def position(self, symbol: str) -> Position | None:
        return self.broker.positions().get(symbol)

    def order(
        self,
        symbol: str,
        side: Side,
        quantity: int,
        limit_price: float | None = None,
        tag: str = "",
        is_exit: bool = False,
    ) -> Order | None:
        order = Order(symbol=symbol, side=side, quantity=quantity,
                      limit_price=limit_price, tag=tag)
        if not self.risk.approve(order, self.broker, is_exit=is_exit):
            order.status = OrderStatus.REJECTED
            order.reason = "risk check failed"
            return None
        placed = self.broker.place_order(order)
        if self._notify_orders and placed.status is OrderStatus.FILLED:
            from ..notify import notify

            notify(f"{placed.side.value} {placed.symbol} x{placed.quantity} "
                   f"@ ₹{placed.fill_price:.2f} [{placed.tag}]")
        return placed

    def buy(self, symbol: str, quantity: int, **kw) -> Order | None:
        return self.order(symbol, Side.BUY, quantity, **kw)

    def sell(self, symbol: str, quantity: int, **kw) -> Order | None:
        return self.order(symbol, Side.SELL, quantity, **kw)


class Strategy(ABC):
    """Implement on_bar (called once per bar/poll). Keep strategies stateless
    where possible; persistent state lives on self."""

    name = "strategy"

    def on_start(self, ctx: Context) -> None:  # noqa: B027
        pass

    @abstractmethod
    def on_bar(self, ctx: Context) -> None: ...

    def on_square_off(self, ctx: Context) -> None:  # noqa: B027
        """Called once when the engine flattens at end of day."""
        pass
