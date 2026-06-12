"""Intraday short straddle on NIFTY weekly options.

Sells the ATM call and put after the opening range settles, with a per-leg
stop loss (classic 9:20 straddle). Theta decay is the edge; the stop loss
caps the gamma risk on a trending day. Live/paper only — backtesting options
requires historical option chains, which this repo does not bundle.

This is a well-known retail strategy with NEGATIVE skew (many small wins,
occasional large losses). Paper trade it through at least one expiry cycle
and one high-volatility event before considering real capital.
"""

from __future__ import annotations

import logging
from datetime import time

from ..instruments import LOT_SIZES, Option, OptionType, atm_strike, next_weekly_expiry
from .base import Context, Strategy

log = logging.getLogger(__name__)


class ShortStraddle(Strategy):
    name = "short_straddle"

    def __init__(
        self,
        underlying: str = "NIFTY",
        spot_symbol: str = "NIFTY 50",
        entry_time: time = time(9, 20),
        lots: int = 1,
        leg_stop_pct: float = 0.30,   # exit a leg if its premium rises 30%
        combined_target_pct: float = 0.50,  # book if combined premium decays 50%
        spot_ltp_fn=None,             # callable returning index spot; engine wires it
    ):
        self.underlying = underlying
        self.spot_symbol = spot_symbol
        self.entry_time = entry_time
        self.lots = lots
        self.leg_stop_pct = leg_stop_pct
        self.combined_target_pct = combined_target_pct
        self._spot_ltp_fn = spot_ltp_fn
        self._legs: dict[str, float] = {}  # symbol -> entry premium
        self._done_for_day = False

    def _spot(self, ctx: Context) -> float:
        if self._spot_ltp_fn:
            return self._spot_ltp_fn(self.spot_symbol)
        return ctx.ltp(self.spot_symbol)

    def on_bar(self, ctx: Context) -> None:
        now = ctx.now.time()
        if self._legs:
            self._manage_exits(ctx)
            return
        if self._done_for_day or now < self.entry_time:
            return
        if not ctx.risk.in_entry_window(now):
            return
        self._enter(ctx)

    def _enter(self, ctx: Context) -> None:
        spot = self._spot(ctx)
        strike = atm_strike(spot, self.underlying)
        expiry = next_weekly_expiry(ctx.now.date())
        qty = self.lots * LOT_SIZES[self.underlying]

        legs = [
            Option(self.underlying, expiry, strike, OptionType.CALL),
            Option(self.underlying, expiry, strike, OptionType.PUT),
        ]
        placed: dict[str, float] = {}
        for leg in legs:
            order = ctx.sell(leg.tradingsymbol, qty, tag="straddle-entry")
            if order is None:
                # If one leg fails, unwind any leg already sold — never run naked.
                for sym, _ in placed.items():
                    ctx.buy(sym, qty, is_exit=True, tag="straddle-abort")
                log.error("straddle entry aborted at %s", leg.tradingsymbol)
                self._done_for_day = True
                return
            placed[leg.tradingsymbol] = order.fill_price or ctx.ltp(leg.tradingsymbol)

        self._legs = placed
        self._done_for_day = True
        log.info("straddle sold %s strike=%d premiums=%s",
                 expiry, strike, {k: round(v, 2) for k, v in placed.items()})

    def _manage_exits(self, ctx: Context) -> None:
        entry_total = sum(self._legs.values())
        current: dict[str, float] = {}
        for symbol in list(self._legs):
            pos = ctx.position(symbol)
            if pos is None or pos.quantity == 0:
                self._legs.pop(symbol)
                continue
            current[symbol] = ctx.ltp(symbol)
        if not self._legs:
            return

        # Combined profit target: buy back both legs.
        if sum(current.values()) <= entry_total * (1 - self.combined_target_pct) and len(
            self._legs
        ) == 2:
            self._close_all(ctx, tag="straddle-target")
            return

        # Per-leg stop loss.
        for symbol, entry_premium in list(self._legs.items()):
            if current[symbol] >= entry_premium * (1 + self.leg_stop_pct):
                pos = ctx.position(symbol)
                ctx.buy(symbol, abs(pos.quantity), is_exit=True, tag="straddle-sl")
                self._legs.pop(symbol)
                log.info("straddle leg stopped: %s %.2f -> %.2f",
                         symbol, entry_premium, current[symbol])

    def _close_all(self, ctx: Context, tag: str) -> None:
        for symbol in list(self._legs):
            pos = ctx.position(symbol)
            if pos and pos.quantity != 0:
                ctx.buy(symbol, abs(pos.quantity), is_exit=True, tag=tag)
            self._legs.pop(symbol)

    def on_square_off(self, ctx: Context) -> None:
        self._legs.clear()
        self._done_for_day = True
