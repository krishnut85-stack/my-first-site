"""Pluggable price feed.

PaperDataSource  -> synthetic prices, works offline with zero keys.
KiteDataSource   -> live LTP via Kite Connect (only used if you enable it).

The bot only ever talks to this interface, so switching from simulation to a
real feed later is a one-line change and does not touch the trading logic.
"""

import hashlib
import time
from typing import Protocol

from . import config
from .indicators import Bar


def _retry_kite(call, attempts: int = 4, base_delay: float = 1.0, sleep=time.sleep):
    """Call a Kite API function, retrying with exponential backoff on transient
    failures (rate-limit / network / busy). This is how Mayura COEXISTS with
    other bots that share the same Kite token — if it gets throttled it simply
    waits (1s, 2s, 4s…) and tries again, instead of fighting or failing. Auth
    errors (bad/expired token, permissions) are NOT retried — they won't fix
    themselves. `call` is a zero-arg callable; `sleep` is injectable for tests."""
    last = None
    for i in range(attempts):
        try:
            return call()
        except Exception as exc:  # noqa: BLE001
            msg = str(exc).lower()
            if any(w in msg for w in ("token", "api_key", "api key", "permission",
                                      "forbidden", "unauthor", "invalid")):
                raise   # auth/permission — retrying is pointless
            last = exc
            if i < attempts - 1:
                sleep(base_delay * (2 ** i))
    raise last


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

    def last_prices(self, symbols: list[str]) -> dict[str, float]:
        return {s: self.last_price(s) for s in symbols}

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
        if not config.KITE_API_KEY:
            raise RuntimeError("KITE_API_KEY not configured.")
        access_token = config.resolve_access_token()
        if not access_token:
            raise RuntimeError(
                "No Kite access token. Set KITE_ACCESS_TOKEN or KITE_TOKEN_FILE "
                "(e.g. the kite_token.json your main bot refreshes daily)."
            )
        self.kite = KiteConnect(api_key=config.KITE_API_KEY)
        self.kite.set_access_token(access_token)
        self._tokens = None  # lazy symbol -> instrument_token cache

    def last_price(self, symbol: str) -> float:  # pragma: no cover
        quote = _retry_kite(lambda: self.kite.ltp([f"NSE:{symbol}"]))
        return float(quote[f"NSE:{symbol}"]["last_price"])

    def last_prices(self, symbols: list[str]) -> dict[str, float]:  # pragma: no cover
        """Fetch many LTPs in ONE call (Kite allows up to ~500), chunked to be
        safe. Avoids the per-symbol rate-limiting that makes a sequential audit
        report live tickers as 'dead'. Missing/invalid symbols map to 0.0."""
        out: dict[str, float] = {}
        for i in range(0, len(symbols), 200):
            chunk = symbols[i:i + 200]
            try:
                quote = _retry_kite(lambda: self.kite.ltp([f"NSE:{s}" for s in chunk]))
            except Exception:  # noqa: BLE001
                quote = {}
            for s in chunk:
                d = quote.get(f"NSE:{s}")
                out[s] = float(d["last_price"]) if d and d.get("last_price") else 0.0
        return out

    def market_traded_today(self) -> bool:  # pragma: no cover
        """True if the NSE actually traded today (not a holiday/weekend). Checks a
        liquid stock's last trade time vs today's IST date. Fail-OPEN (returns
        True) if it can't tell, so the bot never freezes by mistake."""
        from datetime import datetime
        from .data_loader import IST
        try:
            q = _retry_kite(lambda: self.kite.quote(["NSE:RELIANCE"]))
            d = q.get("NSE:RELIANCE", {})
            ltt = d.get("last_trade_time") or d.get("timestamp")
            if ltt is None:
                return True
            if isinstance(ltt, str):
                try:
                    ltt = datetime.fromisoformat(ltt)
                except ValueError:
                    return True
            return ltt.date() == datetime.now(IST).date()
        except Exception:  # noqa: BLE001
            return True

    # Index instrument tokens aren't always in the equity dump; hard-map the
    # common ones so the regime filter can pull index history reliably.
    _INDEX_TOKENS = {"NIFTY 50": 256265, "NIFTY BANK": 260105,
                     "NIFTY 500": 268041}

    def _token(self, symbol: str):  # pragma: no cover
        if symbol in self._INDEX_TOKENS:
            return self._INDEX_TOKENS[symbol]
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
        data = _retry_kite(lambda: self.kite.historical_data(
            token, date.today() - timedelta(days=bars * 2), date.today(), "day"
        ))
        return [Bar(d["high"], d["low"], d["close"], d.get("volume", 0))
                for d in data][-bars:]


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
