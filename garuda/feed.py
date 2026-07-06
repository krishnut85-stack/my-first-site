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
        self.kws = None            # KiteTicker (websocket) once streaming
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

    @property
    def streaming(self) -> bool:
        return self.kws is not None

    def start_stream(self, symbols, on_update) -> bool:
        """Open a KiteTicker websocket and push real-time ticks to on_update(sym,
        ltp, ohlc). Returns True if the stream started. Auto-reconnects."""
        if not self.kite or not symbols:
            return False
        try:
            from kiteconnect import KiteTicker  # type: ignore
        except Exception:  # noqa: BLE001
            return False
        tokens, tok2sym = [], {}
        for s in symbols:
            tk = self._token(s)
            if tk:
                tokens.append(tk)
                tok2sym[tk] = s
        if not tokens:
            return False
        key = os.environ.get("KITE_API_KEY", "")
        kws = KiteTicker(key, _resolve_token())

        def on_ticks(ws, ticks):
            for t in ticks:
                s = tok2sym.get(t.get("instrument_token"))
                if s:
                    on_update(s, t.get("last_price"), t.get("ohlc") or {})

        def on_connect(ws, response):
            for i in range(0, len(tokens), 3000):
                chunk = tokens[i:i + 3000]
                ws.subscribe(chunk)
                ws.set_mode(ws.MODE_QUOTE, chunk)   # ltp + ohlc + volume
            print(f"[ticker] connected, streaming {len(tokens)} symbols", flush=True)

        kws.on_ticks = on_ticks
        kws.on_connect = on_connect
        kws.on_error = lambda ws, code, reason: print(f"[ticker] error {code}: {reason}", flush=True)
        try:
            kws.connect(threaded=True)
        except Exception as exc:  # noqa: BLE001
            print(f"[ticker] connect failed: {exc}", flush=True)
            return False
        self.kws = kws
        return True

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

    def ohlc_quote(self, symbols) -> dict:
        """{sym: {o,h,l,pc,ltp}} — today's open/high/low, previous close and the
        last price, via kite.ohlc(). Lets the dashboard form today's candle live
        like a real broker chart. Empty if unavailable."""
        if not self.kite or not symbols:
            return {}
        out = {}
        syms = list(symbols)
        for i in range(0, len(syms), 200):
            chunk = syms[i:i + 200]
            try:
                q = self.kite.ohlc([f"NSE:{s}" for s in chunk])
            except Exception:  # noqa: BLE001
                q = {}
            for s in chunk:
                d = q.get(f"NSE:{s}")
                if d and d.get("last_price"):
                    o = d.get("ohlc") or {}
                    out[s] = {"o": o.get("open"), "h": o.get("high"),
                              "l": o.get("low"), "pc": o.get("close"),
                              "ltp": float(d["last_price"])}
        return out

    def index_quote(self, names=("NIFTY 50", "NIFTY BANK")) -> dict:
        """{name: {ltp, pc, chg}} for NSE indices (Nifty 50, Bank Nifty). Uses
        kite.ohlc('NSE:NIFTY 50'); pc is the previous close, chg the day %.
        Empty if unavailable — the header just hides the reading then."""
        if not self.kite or not names:
            return {}
        try:
            q = self.kite.ohlc([f"NSE:{n}" for n in names])
        except Exception:  # noqa: BLE001
            return {}
        out = {}
        for n in names:
            d = q.get(f"NSE:{n}")
            if d and d.get("last_price"):
                pc = (d.get("ohlc") or {}).get("close")
                ltp = float(d["last_price"])
                out[n] = {"ltp": round(ltp, 2), "pc": pc,
                          "chg": round((ltp - pc) / pc * 100, 2) if pc else 0.0}
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
        """Recent daily candles [{t,o,h,l,c}] for one symbol ([] if unavailable)."""
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
        out = []
        for d in data:
            dt = d.get("date")
            t = dt.strftime("%Y-%m-%d") if hasattr(dt, "strftime") else str(dt)[:10]
            out.append({"t": t, "o": d["open"], "h": d["high"],
                        "l": d["low"], "c": d["close"], "v": d.get("volume", 0)})
        return out[-days:]
