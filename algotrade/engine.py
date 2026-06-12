"""Live/paper trading loop.

Polls on a fixed interval during market hours, runs the strategy, enforces the
daily loss kill switch, and squares off before the close. Designed to be
restart-safe: positions are always read from the broker, never cached.

All clocks are IST (the server may run UTC — see timeutils).
"""

from __future__ import annotations

import logging
import time as time_mod
from datetime import datetime, time

from .brokers.base import Broker
from .notify import notify
from .risk import RiskManager
from .strategies.base import Context, Strategy
from .timeutils import is_weekday, now_ist

log = logging.getLogger(__name__)

MARKET_OPEN = time(9, 15)
MARKET_CLOSE = time(15, 30)


class TradingEngine:
    def __init__(
        self,
        strategy: Strategy,
        broker: Broker,
        risk: RiskManager,
        poll_seconds: int = 60,
        history_fn=None,
        mode: str = "paper",
    ):
        self.strategy = strategy
        self.broker = broker
        self.risk = risk
        self.poll_seconds = poll_seconds
        self.mode = mode
        self.ctx = Context(broker, risk, history_fn=history_fn, notify_orders=True)
        self._squared_off = False

    def run(self) -> None:
        if not is_weekday():
            log.info("weekend — nothing to do")
            return
        log.info("engine starting: strategy=%s mode=%s poll=%ss",
                 self.strategy.name, self.mode, self.poll_seconds)
        notify(f"{self.strategy.name} online [{self.mode.upper()}] "
               f"max daily loss ₹{self.risk.limits.max_daily_loss:,.0f}")
        self.strategy.on_start(self.ctx)
        try:
            while True:
                now = now_ist()
                self.ctx.now = now
                if now.time() >= MARKET_CLOSE:
                    log.info("market closed; stopping")
                    break
                if now.time() < MARKET_OPEN:
                    time_mod.sleep(30)
                    continue
                self.step(now)
                time_mod.sleep(self.poll_seconds)
        except KeyboardInterrupt:
            log.warning("interrupted by user")
        finally:
            self._square_off("shutdown")
            pnl = self.broker.total_pnl()
            log.info("final pnl: %.2f", pnl)
            notify(f"{self.strategy.name} done [{self.mode.upper()}] "
                   f"day pnl ₹{pnl:,.0f}")

    def step(self, now: datetime) -> None:
        """One poll cycle; exceptions are contained so a bad tick can't kill the day."""
        try:
            if self.risk.check_daily_loss(self.broker):
                if not self._squared_off:
                    notify("KILL SWITCH: daily loss limit hit — squaring off, "
                           "no more entries today")
                self._square_off("kill-switch")
                return
            if self.risk.should_square_off(now.time()):
                self._square_off("eod")
                return
            self.strategy.on_bar(self.ctx)
        except Exception:
            log.exception("error in strategy step; continuing")

    def _square_off(self, reason: str) -> None:
        if self._squared_off:
            return
        open_positions = [p for p in self.broker.positions().values() if p.quantity]
        if open_positions:
            log.warning("squaring off %d positions (%s)", len(open_positions), reason)
            self.broker.square_off_all(tag=reason)
        self.strategy.on_square_off(self.ctx)
        self._squared_off = True
