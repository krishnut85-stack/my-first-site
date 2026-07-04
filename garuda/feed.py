"""Kite live feed for Garuda — live LTP + daily OHLC, with safe fallbacks.

Reads KITE_API_KEY + token from the environment at runtime (never committed).
Every method degrades gracefully: with no keys / no network it returns empty, so
the dashboard still runs (pricing holdings at their last close) instead of
crashing. That lets you SEE the display before the live plumbing is perfect.
"""

import json
import os
from pathlib import Path


def _resolve_token() -> str:
    tok = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    if tok:
        return tok
    tf = os.environ.get("KITE_TOKEN_FILE", "")
    if tf and Path(tf).exists():
        raw = Path(tf).read_text().strip()
        try:
            d = json.loads(raw)
            if isinstance(d, dict):
                for k in ("access_token", "accessToken", "token"):
                    if d.get(k):
                        return str(d[k]).strip()
        except Exception:  # noqa: BLE001
            pass
        if raw and "\n" not in raw:
            return raw
    return ""


class KiteFeed:
    def __init__(self):
        self.kite = None
        self._tokens = None
        try:
            from kiteconnect import KiteConnect  # type: ignore
            key = os.environ.get("KITE_API_KEY", "")
            tok = _resolve_token()
            if key and tok:
                self.kite = KiteConnect(api_key=key)
                self.kite.set_access_token(tok)
        except Exception:  # noqa: BLE001 — no keys / not installed -> fallback mode
            self.kite = None

    @property
    def live(self) -> bool:
        return self.kite is not None

    def ltp(self, symbols) -> dict:
        """{symbol: last_price} for a list of NSE symbols (empty if unavailable)."""
        if not self.kite or not symbols:
            return {}
        out = {}
        syms = list(symbols)
        for i in range(0, len(syms), 200):
            chunk = syms[i:i + 200]
            try:
                q = self.kite.ltp([f"NSE:{s}" for s in chunk])
            except Exception:  # noqa: BLE001
                q = {}
            for s in chunk:
                d = q.get(f"NSE:{s}")
                if d and d.get("last_price"):
                    out[s] = float(d["last_price"])
        return out

    def _token(self, symbol):
        if self._tokens is None and self.kite:
            try:
                self._tokens = {i["tradingsymbol"]: i["instrument_token"]
                                for i in self.kite.instruments("NSE")}
            except Exception:  # noqa: BLE001
                self._tokens = {}
        return (self._tokens or {}).get(symbol)

    def ohlc_daily(self, symbol, days=70) -> list:
        """Recent daily candles [{o,h,l,c}] for one symbol ([] if unavailable)."""
        if not self.kite:
            return []
        tok = self._token(symbol)
        if not tok:
            return []
        from datetime import date, timedelta
        try:
            data = self.kite.historical_data(
                tok, date.today() - timedelta(days=days * 2), date.today(), "day")
        except Exception:  # noqa: BLE001
            return []
        return [{"o": d["open"], "h": d["high"], "l": d["low"], "c": d["close"]}
                for d in data][-days:]
