"""Pluggable price feed.

PaperDataSource  -> synthetic prices, works offline with zero keys.
KiteDataSource   -> live LTP via Kite Connect (only used if you enable it).

The bot only ever talks to this interface, so switching from simulation to a
real feed later is a one-line change and does not touch the trading logic.
"""

import hashlib
from typing import Protocol

from . import config
from .indicators import Bar


class DataSource(Protocol):
    def last_price(self, symbol: str) -> float: ...
    def history(self, symbol: str, bars: int) -> list[Bar]: ...


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

    def history(self, symbol: str, bars: int) -> list[Bar]:
        """Deterministic synthetic OHLC history so ATR can be computed offline.

        NOT real market data -- volatility here is fabricated. For real ATR,
        use KiteDataSource.history (Kite historical API).
        """
        base = self._base.get(symbol) or self._seed(symbol)
        out: list[Bar] = []
        for i in range(bars):
            wobble = ((hash((symbol, "hist", i)) % 200) - 100) / 100.0
            close = round(base * (1 + 0.012 * wobble), 2)
            spread = abs(wobble) * 0.01 * base + 0.5
            high = round(close + spread, 2)
            low = round(max(close - spread, 1.0), 2)
            out.append(Bar(high=high, low=low, close=close))
        return out


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
        self._tokens = None  # lazy symbol -> instrument_token cache

    def last_price(self, symbol: str) -> float:  # pragma: no cover
        quote = self.kite.ltp([f"NSE:{symbol}"])
        return float(quote[f"NSE:{symbol}"]["last_price"])

    def _token(self, symbol: str):  # pragma: no cover
        if self._tokens is None:
            self._tokens = {
                i["tradingsymbol"]: i["instrument_token"]
                for i in self.kite.instruments("NSE")
            }
        return self._tokens.get(symbol)

    def history(self, symbol: str, bars: int) -> list[Bar]:  # pragma: no cover
        """Real daily OHLC via Kite historical_data ([] if unavailable)."""
        from datetime import date, timedelta

        token = self._token(symbol)
        if not token:
            return []
        data = self.kite.historical_data(
            token, date.today() - timedelta(days=bars * 2), date.today(), "day"
        )
        return [Bar(d["high"], d["low"], d["close"]) for d in data][-bars:]


def get_datasource() -> DataSource:
    """Return the right price feed.

    Uses real Kite data when USE_KITE_DATA (or LIVE_TRADING) is on AND keys are
    present; otherwise synthetic. Any Kite init failure falls back to synthetic
    so the bot never crashes -- but it prints a clear warning so you know the
    numbers are not real.
    """
    want_kite = (config.USE_KITE_DATA or config.LIVE_TRADING) and config.KITE_API_KEY
    if want_kite:
        try:
            ds = KiteDataSource()
            print("[data] Using REAL Kite market data.")
            return ds
        except Exception as exc:  # noqa: BLE001
            print(f"[data] WARNING: Kite unavailable ({exc}). "
                  "Falling back to SYNTHETIC prices -- numbers are NOT real.")
    return PaperDataSource()
