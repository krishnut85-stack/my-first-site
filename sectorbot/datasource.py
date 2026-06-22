"""Pluggable price feed.

PaperDataSource  -> synthetic prices, works offline with zero keys.
KiteDataSource   -> live LTP via Kite Connect (only used if you enable it).

The bot only ever talks to this interface, so switching from simulation to a
real feed later is a one-line change and does not touch the trading logic.
"""

import hashlib
from typing import Protocol

from . import config


class DataSource(Protocol):
    def last_price(self, symbol: str) -> float: ...


class PaperDataSource:
    """Deterministic synthetic prices so simulations are repeatable offline.

    Each symbol gets a stable pseudo-random base price plus a small drift driven
    by a 'momentum' hint (so higher-ranked industries trend up in the sim). This
    is purely illustrative -- it is NOT real market data.
    """

    def __init__(self) -> None:
        self._base: dict[str, float] = {}
        self._momentum: dict[str, float] = {}
        self._step: dict[str, int] = {}

    def _seed(self, symbol: str) -> float:
        h = int(hashlib.sha256(symbol.encode()).hexdigest(), 16)
        return 100.0 + (h % 4000) / 10.0  # base price between 100 and 500

    def set_momentum(self, symbol: str, momentum_pct: float) -> None:
        """Give a symbol a per-step upward/downward drift (in %)."""
        self._momentum[symbol] = momentum_pct

    def last_price(self, symbol: str) -> float:
        if symbol not in self._base:
            self._base[symbol] = self._seed(symbol)
            self._step[symbol] = 0
        step = self._step[symbol]
        drift = self._momentum.get(symbol, 0.0) / 100.0
        # gentle deterministic wobble so stop-loss / take-profit can trigger
        wobble = ((hash((symbol, step)) % 200) - 100) / 100.0 * 0.01
        price = self._base[symbol] * (1 + drift * step + wobble)
        return round(max(price, 1.0), 2)

    def advance(self, symbol: str) -> None:
        self._step[symbol] = self._step.get(symbol, 0) + 1


class KiteDataSource:
    """Live prices via Kite Connect. Requires pykiteconnect + valid keys.

    Only instantiated when config.LIVE_TRADING is on and keys are present.
    """

    def __init__(self) -> None:
        try:
            from kiteconnect import KiteConnect  # type: ignore
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError(
                "pykiteconnect not installed. Run: pip install kiteconnect"
            ) from exc
        if not (config.KITE_API_KEY and config.KITE_ACCESS_TOKEN):
            raise RuntimeError("KITE_API_KEY / KITE_ACCESS_TOKEN not configured.")
        self.kite = KiteConnect(api_key=config.KITE_API_KEY)
        self.kite.set_access_token(config.KITE_ACCESS_TOKEN)

    def last_price(self, symbol: str) -> float:  # pragma: no cover
        quote = self.kite.ltp([f"NSE:{symbol}"])
        return float(quote[f"NSE:{symbol}"]["last_price"])


def get_datasource() -> DataSource:
    """Return the right data source for the current config."""
    if config.LIVE_TRADING and config.KITE_API_KEY:
        return KiteDataSource()
    return PaperDataSource()
