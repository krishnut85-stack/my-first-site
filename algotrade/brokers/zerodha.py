"""Zerodha Kite Connect adapter for live NSE F&O trading.

Requires a Kite Connect app (https://developers.kite.trade) and the
`kiteconnect` package. Credentials come from the environment via
kite_auth.auto_login() (TOTP auto-login with daily token cache), or pass a
ready KiteConnect instance.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

import pandas as pd

from ..timeutils import IST
from .base import Broker, Order, OrderStatus, Position, Side
from .kite_auth import auto_login

log = logging.getLogger(__name__)


class ZerodhaBroker(Broker):
    EXCHANGE = "NFO"

    def __init__(self, kite=None):
        self.kite = kite if kite is not None else auto_login()
        self._token_cache: dict[str, int] = {}

    def ltp(self, symbol: str) -> float:
        key = f"{self.EXCHANGE}:{symbol}"
        data = self.kite.ltp([key])
        return float(data[key]["last_price"])

    def spot_ltp(self, index_symbol: str) -> float:
        """LTP for an index spot, e.g. 'NIFTY 50' -> NSE:NIFTY 50."""
        key = f"NSE:{index_symbol}"
        return float(self.kite.ltp([key])[key]["last_price"])

    def place_order(self, order: Order) -> Order:
        order.placed_at = datetime.now()
        try:
            order_id = self.kite.place_order(
                variety=self.kite.VARIETY_REGULAR,
                exchange=self.EXCHANGE,
                tradingsymbol=order.symbol,
                transaction_type=order.side.value,
                quantity=order.quantity,
                product=self.kite.PRODUCT_NRML,
                order_type=(
                    self.kite.ORDER_TYPE_MARKET
                    if order.limit_price is None
                    else self.kite.ORDER_TYPE_LIMIT
                ),
                price=order.limit_price,
                tag=order.tag[:20] or None,
            )
            order.order_id = str(order_id)
            # Fill confirmation should be reconciled via order history / postback;
            # we optimistically mark filled and let positions() be authoritative.
            order.status = OrderStatus.FILLED
            log.info("kite order placed %s %s x%d id=%s",
                     order.side.value, order.symbol, order.quantity, order_id)
        except Exception as exc:
            order.status = OrderStatus.REJECTED
            order.reason = str(exc)
            log.error("kite order rejected %s: %s", order.symbol, exc)
        return order

    def positions(self) -> dict[str, Position]:
        result: dict[str, Position] = {}
        for p in self.kite.positions()["net"]:
            if p["exchange"] != self.EXCHANGE:
                continue
            result[p["tradingsymbol"]] = Position(
                symbol=p["tradingsymbol"],
                quantity=p["quantity"],
                avg_price=p["average_price"],
                realized_pnl=p["realised"],
            )
        return result

    def margins_available(self) -> float:
        return float(self.kite.margins()["equity"]["available"]["live_balance"])

    def _instrument_token(self, symbol: str) -> int:
        if not self._token_cache:
            for inst in self.kite.instruments(self.EXCHANGE):
                self._token_cache[inst["tradingsymbol"]] = inst["instrument_token"]
        try:
            return self._token_cache[symbol]
        except KeyError:
            raise KeyError(f"{symbol} not found in NFO instruments") from None

    def history(self, symbol: str, lookback_bars: int,
                interval: str = "5minute") -> pd.DataFrame:
        """Recent OHLC bars for an NFO symbol (powers indicator strategies live).

        Fetches a generous calendar window so weekends/holidays don't starve
        the lookback, then trims to the requested number of bars.
        """
        minutes = {"minute": 1, "3minute": 3, "5minute": 5,
                   "10minute": 10, "15minute": 15, "60minute": 60}[interval]
        sessions_needed = (lookback_bars * minutes) / 375 + 1  # 375 trading min/day
        days = int(sessions_needed * 2.5) + 3  # cover weekends/holidays
        to_dt = datetime.now(IST)
        candles = self.kite.historical_data(
            self._instrument_token(symbol),
            from_date=to_dt - timedelta(days=days),
            to_date=to_dt,
            interval=interval,
        )
        df = pd.DataFrame(candles)
        if df.empty:
            return df
        df = df.set_index("date")[["open", "high", "low", "close", "volume"]]
        return df.tail(lookback_bars)
