"""Broker abstraction shared by the paper broker, live adapters, and backtester."""

from __future__ import annotations

import itertools
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class Side(str, Enum):
    BUY = "BUY"
    SELL = "SELL"


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    FILLED = "FILLED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


_order_ids = itertools.count(1)


@dataclass
class Order:
    symbol: str
    side: Side
    quantity: int
    limit_price: float | None = None  # None => market order
    tag: str = ""
    order_id: str = field(default_factory=lambda: f"ORD{next(_order_ids):06d}")
    status: OrderStatus = OrderStatus.PENDING
    fill_price: float = 0.0
    placed_at: datetime | None = None
    reason: str = ""


@dataclass
class Position:
    symbol: str
    quantity: int = 0  # signed: +long, -short
    avg_price: float = 0.0
    realized_pnl: float = 0.0

    def unrealized_pnl(self, ltp: float) -> float:
        return (ltp - self.avg_price) * self.quantity

    def apply_fill(self, side: Side, quantity: int, price: float) -> None:
        signed = quantity if side is Side.BUY else -quantity
        if self.quantity * signed >= 0:  # opening or adding
            total = abs(self.quantity) + quantity
            self.avg_price = (
                abs(self.quantity) * self.avg_price + quantity * price
            ) / total
            self.quantity += signed
            return
        # Reducing / flipping: realize pnl on the closed portion.
        closed = min(abs(self.quantity), quantity)
        direction = 1 if self.quantity > 0 else -1
        self.realized_pnl += (price - self.avg_price) * closed * direction
        self.quantity += signed
        if self.quantity == 0:
            self.avg_price = 0.0
        elif self.quantity * direction < 0:  # flipped through zero
            self.avg_price = price


class Broker(ABC):
    """Minimal order/position/quote interface every adapter must implement."""

    @abstractmethod
    def place_order(self, order: Order) -> Order: ...

    @abstractmethod
    def positions(self) -> dict[str, Position]: ...

    @abstractmethod
    def ltp(self, symbol: str) -> float: ...

    def total_pnl(self) -> float:
        total = 0.0
        for pos in self.positions().values():
            total += pos.realized_pnl
            if pos.quantity != 0:
                total += pos.unrealized_pnl(self.ltp(pos.symbol))
        return total

    def square_off_all(self, tag: str = "square-off") -> list[Order]:
        """Close every open position at market. Used by risk kill-switch/EOD."""
        orders = []
        for pos in self.positions().values():
            if pos.quantity == 0:
                continue
            side = Side.SELL if pos.quantity > 0 else Side.BUY
            orders.append(
                self.place_order(
                    Order(symbol=pos.symbol, side=side, quantity=abs(pos.quantity), tag=tag)
                )
            )
        return orders
