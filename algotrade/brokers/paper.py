"""Paper-trading broker: simulates fills against a quote source.

Use this for dry runs before going live. Quotes can come from a live feed
(e.g. the Zerodha adapter's ltp) or from the backtester, so the same strategy
code runs unchanged in all three modes.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Callable

from .base import Broker, Order, OrderStatus, Position

log = logging.getLogger(__name__)


class PaperBroker(Broker):
    def __init__(
        self,
        quote_fn: Callable[[str], float],
        slippage_bps: float = 5.0,
        cost_per_order: float = 25.0,
    ):
        """quote_fn returns the current price for a symbol.

        slippage_bps models market-impact on market orders; cost_per_order
        approximates brokerage + STT + exchange charges per leg.
        """
        self._quote_fn = quote_fn
        self._slippage = slippage_bps / 10_000.0
        self._cost_per_order = cost_per_order
        self._positions: dict[str, Position] = {}
        self.order_log: list[Order] = []
        self.costs_paid = 0.0

    def ltp(self, symbol: str) -> float:
        return self._quote_fn(symbol)

    def positions(self) -> dict[str, Position]:
        return self._positions

    def place_order(self, order: Order) -> Order:
        order.placed_at = datetime.now()
        try:
            market = self.ltp(order.symbol)
        except Exception as exc:
            order.status = OrderStatus.REJECTED
            order.reason = f"no quote: {exc}"
            self.order_log.append(order)
            log.warning("paper order rejected %s: %s", order.symbol, order.reason)
            return order

        if order.limit_price is not None:
            # Fill limit orders only if immediately marketable.
            marketable = (
                market <= order.limit_price
                if order.side.value == "BUY"
                else market >= order.limit_price
            )
            if not marketable:
                order.status = OrderStatus.CANCELLED
                order.reason = "limit not marketable (paper broker has no order book)"
                self.order_log.append(order)
                return order
            fill = order.limit_price
        else:
            sign = 1 if order.side.value == "BUY" else -1
            fill = market * (1 + sign * self._slippage)

        order.fill_price = round(fill, 2)
        order.status = OrderStatus.FILLED
        self.costs_paid += self._cost_per_order

        pos = self._positions.setdefault(order.symbol, Position(symbol=order.symbol))
        pos.apply_fill(order.side, order.quantity, order.fill_price)
        self.order_log.append(order)
        log.info(
            "paper fill %s %s x%d @ %.2f [%s]",
            order.side.value, order.symbol, order.quantity, order.fill_price, order.tag,
        )
        return order

    def total_pnl(self) -> float:
        return super().total_pnl() - self.costs_paid
