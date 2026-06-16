"""EMA crossover trend strategy for index futures.

Long when fast EMA crosses above slow EMA, short on the reverse cross.
Position size comes from the risk manager (ATR-based stop distance), and a
trailing stop manages the exit. Works in backtest, paper, and live modes.
"""

from __future__ import annotations

import logging

from ..risk import TrailingStop
from .base import Context, Strategy

log = logging.getLogger(__name__)


class EmaCrossover(Strategy):
    name = "ema_crossover"

    def __init__(
        self,
        symbol: str,
        lot_size: int,
        fast: int = 9,
        slow: int = 21,
        atr_period: int = 14,
        atr_stop_mult: float = 2.0,
        trail_pct: float = 0.01,
    ):
        self.symbol = symbol
        self.lot_size = lot_size
        self.fast = fast
        self.slow = slow
        self.atr_period = atr_period
        self.atr_stop_mult = atr_stop_mult
        self.trail_pct = trail_pct
        self._trailing: TrailingStop | None = None

    def on_bar(self, ctx: Context) -> None:
        lookback = max(self.slow, self.atr_period) + 5
        bars = ctx.history(self.symbol, lookback)
        if len(bars) < lookback:
            return

        close = bars["close"]
        fast = close.ewm(span=self.fast, adjust=False).mean()
        slow = close.ewm(span=self.slow, adjust=False).mean()
        crossed_up = fast.iloc[-2] <= slow.iloc[-2] and fast.iloc[-1] > slow.iloc[-1]
        crossed_down = fast.iloc[-2] >= slow.iloc[-2] and fast.iloc[-1] < slow.iloc[-1]

        tr = (bars["high"] - bars["low"]).combine(
            (bars["high"] - close.shift()).abs(), max
        ).combine((bars["low"] - close.shift()).abs(), max)
        atr = tr.rolling(self.atr_period).mean().iloc[-1]
        price = close.iloc[-1]

        pos = ctx.position(self.symbol)
        qty_held = pos.quantity if pos else 0

        # Manage exit first: trailing stop or opposite cross.
        if qty_held != 0:
            stop_hit = self._trailing.update(price) if self._trailing else False
            reverse = crossed_down if qty_held > 0 else crossed_up
            if stop_hit or reverse:
                side_fn = ctx.sell if qty_held > 0 else ctx.buy
                side_fn(self.symbol, abs(qty_held), is_exit=True,
                        tag="trail-stop" if stop_hit else "reverse")
                self._trailing = None
                qty_held = 0
                if stop_hit and not reverse:
                    return  # stopped out; wait for a fresh cross to re-enter

        if qty_held != 0 or not (crossed_up or crossed_down):
            return
        if not ctx.risk.in_entry_window(ctx.now.time()):
            return

        stop_distance = atr * self.atr_stop_mult
        lots = ctx.risk.position_size_lots(stop_distance)
        if lots == 0:
            log.info("%s: signal but position size is 0 (stop %.1f pts too wide)",
                     self.name, stop_distance)
            return
        qty = lots * self.lot_size

        if crossed_up:
            if ctx.buy(self.symbol, qty, tag="ema-long"):
                self._trailing = TrailingStop(
                    entry_price=price, is_long=True,
                    initial_stop=price - stop_distance, trail_pct=self.trail_pct)
        else:
            if ctx.sell(self.symbol, qty, tag="ema-short"):
                self._trailing = TrailingStop(
                    entry_price=price, is_long=False,
                    initial_stop=price + stop_distance, trail_pct=self.trail_pct)

    def on_square_off(self, ctx: Context) -> None:
        self._trailing = None
