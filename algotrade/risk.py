"""Risk management: order-level checks, daily loss limits, trailing stops.

Every order a strategy emits passes through RiskManager.approve() before it
reaches the broker. Once the daily loss limit trips, the kill switch stays on
for the rest of the session and the engine squares off everything.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import time

from .brokers.base import Broker, Order, Side

log = logging.getLogger(__name__)


@dataclass
class RiskLimits:
    max_daily_loss: float = 5_000.0        # rupees; kill switch threshold
    max_open_lots: int = 2                 # per symbol, in lots
    max_order_quantity: int = 500          # absolute contracts per order
    risk_per_trade_pct: float = 1.0        # % of capital risked per trade
    capital: float = 200_000.0             # account capital for sizing
    trade_start: time = time(9, 20)        # skip the opening volatility
    trade_end: time = time(15, 0)          # no fresh entries after this
    square_off_at: time = time(15, 12)     # flatten before 15:30 close


@dataclass
class TrailingStop:
    """Ratchet stop for a single position. Call update() with each new price."""

    entry_price: float
    is_long: bool
    initial_stop: float
    trail_pct: float  # e.g. 0.30 trails 30% behind the best price seen
    stop: float = field(init=False)
    best: float = field(init=False)

    def __post_init__(self):
        self.stop = self.initial_stop
        self.best = self.entry_price

    def update(self, price: float) -> bool:
        """Returns True when the stop is hit."""
        if self.is_long:
            if price > self.best:
                self.best = price
                self.stop = max(self.stop, price * (1 - self.trail_pct))
            return price <= self.stop
        if price < self.best:
            self.best = price
            self.stop = min(self.stop, price * (1 + self.trail_pct))
        return price >= self.stop


class RiskManager:
    def __init__(self, limits: RiskLimits, lot_size: int):
        self.limits = limits
        self.lot_size = lot_size
        self.kill_switch = False

    def position_size_lots(self, stop_distance_points: float) -> int:
        """Lots such that hitting the stop loses ~risk_per_trade_pct of capital."""
        if stop_distance_points <= 0:
            return 0
        rupee_risk = self.limits.capital * self.limits.risk_per_trade_pct / 100.0
        lots = int(rupee_risk / (stop_distance_points * self.lot_size))
        return max(0, min(lots, self.limits.max_open_lots))

    def check_daily_loss(self, broker: Broker) -> bool:
        """Trips (and latches) the kill switch when the day's loss limit is hit."""
        if self.kill_switch:
            return True
        pnl = broker.total_pnl()
        if pnl <= -self.limits.max_daily_loss:
            self.kill_switch = True
            log.critical("KILL SWITCH: daily pnl %.0f breached limit -%.0f",
                         pnl, self.limits.max_daily_loss)
        return self.kill_switch

    def in_entry_window(self, now: time) -> bool:
        return self.limits.trade_start <= now <= self.limits.trade_end

    def should_square_off(self, now: time) -> bool:
        return now >= self.limits.square_off_at

    def approve(self, order: Order, broker: Broker, *, is_exit: bool = False) -> bool:
        """Gate every order. Exits are always allowed unless quantity is absurd."""
        if order.quantity <= 0 or order.quantity % self.lot_size != 0:
            log.warning("rejected %s: quantity %d not a lot multiple of %d",
                        order.symbol, order.quantity, self.lot_size)
            return False
        if order.quantity > self.limits.max_order_quantity:
            log.warning("rejected %s: quantity %d > max %d",
                        order.symbol, order.quantity, self.limits.max_order_quantity)
            return False
        if is_exit:
            return True
        if self.kill_switch:
            log.warning("rejected %s: kill switch active", order.symbol)
            return False

        pos = broker.positions().get(order.symbol)
        current = pos.quantity if pos else 0
        signed = order.quantity if order.side is Side.BUY else -order.quantity
        if abs(current + signed) > self.limits.max_open_lots * self.lot_size:
            log.warning("rejected %s: would exceed %d open lots",
                        order.symbol, self.limits.max_open_lots)
            return False
        return True
