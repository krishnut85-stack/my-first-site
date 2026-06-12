"""Zerodha Kite Connect adapter for live NSE F&O trading.

Requires a Kite Connect app (https://developers.kite.trade) and the
`kiteconnect` package. Credentials are read from the environment so they are
never committed:

    KITE_API_KEY      - app api_key
    KITE_ACCESS_TOKEN - daily access token (generate each morning via login flow)

Kite access tokens expire daily; run scripts/kite_login.py to mint one.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime

from .base import Broker, Order, OrderStatus, Position, Side

log = logging.getLogger(__name__)


class ZerodhaBroker(Broker):
    EXCHANGE = "NFO"

    def __init__(self, api_key: str | None = None, access_token: str | None = None):
        try:
            from kiteconnect import KiteConnect
        except ImportError as exc:
            raise RuntimeError(
                "kiteconnect not installed; run `pip install kiteconnect`"
            ) from exc

        api_key = api_key or os.environ.get("KITE_API_KEY")
        access_token = access_token or os.environ.get("KITE_ACCESS_TOKEN")
        if not api_key or not access_token:
            raise RuntimeError(
                "Set KITE_API_KEY and KITE_ACCESS_TOKEN environment variables"
            )
        self.kite = KiteConnect(api_key=api_key)
        self.kite.set_access_token(access_token)

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
