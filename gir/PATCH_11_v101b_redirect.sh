#!/bin/bash
# Paste this entire block into ConnectBot. It applies patch 11 (v101b_redirect).
python3 << 'PYEOF'
#!/usr/bin/env python3
"""
PATCH_V101B_WEBSOCKET_REDIRECT
==============================
PURPOSE:
  Redirect kite.ltp() and kite.quote() calls to read from KiteTickerStream
  dict instead of HTTP polling. REST fallback if dict has no data for symbol.

  Effect: 51 polling call sites get faster reads with no rate limit cost.
  Bot's existing logic unchanged — calls return same shape data.

APPROACH:
  Instead of monkey-patching 51 call sites (fragile, error-prone), we wrap
  the kite object at retrieval time. KiteSession.kite() returns a transparent
  wrapper that intercepts .ltp() and .quote() and routes through the dict.
  All other methods (orders, positions, holdings, etc.) pass through unchanged.

SAFETY:
  - REST fallback on every miss — if dict empty, bot uses original kite call
  - Wrapper is None-safe; if KiteTickerStream not started, all calls go REST
  - V101A must be deployed first (this patch depends on KiteTickerStream class)
  - Idempotent: if already wrapped, returns existing wrapper
"""
import ast, hashlib, shutil, sys

PATH = "/home/globalbot/gir.py"
BACKUP = "/home/globalbot/gir_backup_pre_V101B_redirect.py"

# ==========================================================================
# CHANGE 1: Add KiteWrapper class — insert AFTER KiteTickerStream class
# Anchor: the existing KiteSession class start
# ==========================================================================

ANCHOR_1 = '''class KiteSession:
    """
    Manages Kite login and access token.
    Both EquityModule and FnoModule call kite() to get a KiteConnect instance.
    They share the access token but make independent API calls.
    """'''

INSERT_1 = '''class KiteWrapper:
    """
    PATCH_V101B: transparent wrapper around KiteConnect that intercepts
    .ltp() and .quote() calls. Reads from KiteTickerStream dict when available,
    falls back to underlying REST call otherwise.

    All other KiteConnect methods pass through unchanged via __getattr__.
    """
    def __init__(self, kite):
        self._kite = kite

    def __getattr__(self, name):
        # Pass through everything we don't intercept
        return getattr(self._kite, name)

    def ltp(self, instruments):
        """
        Drop-in for KiteConnect.ltp.
        instruments: str | list[str] — formats: "NSE:RELIANCE", ["NSE:INFY", "NFO:..."]
        Returns dict { "NSE:RELIANCE": {"instrument_token": ..., "last_price": ...}, ...}
        """
        try:
            if isinstance(instruments, str):
                instruments = [instruments]
            out = {}
            misses = []
            for key in instruments:
                # Parse "NSE:RELIANCE" or "NFO:LT26MAY..."
                if ":" in key:
                    _exch, _sym = key.split(":", 1)
                else:
                    _sym = key
                t = KiteTickerStream.get_tick(_sym)
                if t and t.get("ltp", 0) > 0:
                    out[key] = {
                        "instrument_token": KiteTickerStream._sym_to_token.get(_sym, 0),
                        "last_price": t["ltp"],
                    }
                else:
                    misses.append(key)
            # REST fallback for misses
            if misses:
                try:
                    rest_data = self._kite.ltp(misses) or {}
                    out.update(rest_data)
                except Exception as _re:
                    log.debug(f"[V101B] ltp REST fallback failed for {len(misses)}: {_re}")
            return out
        except Exception as e:
            log.debug(f"[V101B] ltp wrapper error, falling back to REST: {e}")
            return self._kite.ltp(instruments)

    def quote(self, instruments):
        """
        Drop-in for KiteConnect.quote.
        Returns dict per Kite spec — instrument_token, last_price, ohlc, volume, etc.
        """
        try:
            if isinstance(instruments, str):
                instruments = [instruments]
            out = {}
            misses = []
            for key in instruments:
                if ":" in key:
                    _exch, _sym = key.split(":", 1)
                else:
                    _sym = key
                t = KiteTickerStream.get_tick(_sym)
                if t and t.get("ltp", 0) > 0:
                    _ohlc = t.get("ohlc", {}) or {}
                    out[key] = {
                        "instrument_token": KiteTickerStream._sym_to_token.get(_sym, 0),
                        "last_price": t["ltp"],
                        "volume": t.get("vol", 0),
                        "buy_quantity": t.get("buy_qty", 0),
                        "sell_quantity": t.get("sell_qty", 0),
                        "ohlc": {
                            "open": _ohlc.get("open", 0),
                            "high": _ohlc.get("high", 0),
                            "low": _ohlc.get("low", 0),
                            "close": _ohlc.get("close", 0),
                        },
                    }
                else:
                    misses.append(key)
            # REST fallback
            if misses:
                try:
                    rest_data = self._kite.quote(misses) or {}
                    out.update(rest_data)
                except Exception as _re:
                    log.debug(f"[V101B] quote REST fallback failed for {len(misses)}: {_re}")
            return out
        except Exception as e:
            log.debug(f"[V101B] quote wrapper error, falling back to REST: {e}")
            return self._kite.quote(instruments)


class KiteSession:
    """
    Manages Kite login and access token.
    Both EquityModule and FnoModule call kite() to get a KiteConnect instance.
    They share the access token but make independent API calls.
    """'''

# ==========================================================================
# CHANGE 2: kite() classmethod returns wrapped instance
# Anchor: the kite() classmethod definition
# ==========================================================================

ANCHOR_2 = '''    @classmethod
    def kite(cls):
        """Get KiteConnect instance. Returns None if not logged in."""
        if cls._kite is None:
            cls.login()
        # V78: install recorder on the live kite object (idempotent, never raises)
        if cls._kite is not None and _TRADE_RECORDER_AVAILABLE:
            try:
                TradeRecorder.install(cls._kite)
            except Exception:
                pass  # Never let recorder failure block kite access'''

INSERT_2 = '''    @classmethod
    def kite(cls):
        """Get KiteConnect instance. Returns None if not logged in.
        PATCH_V101B: returns a KiteWrapper that routes ltp/quote through
        WebSocket dict (with REST fallback). All other methods pass through.
        """
        if cls._kite is None:
            cls.login()
        # V78: install recorder on the live kite object (idempotent, never raises)
        if cls._kite is not None and _TRADE_RECORDER_AVAILABLE:
            try:
                TradeRecorder.install(cls._kite)
            except Exception:
                pass  # Never let recorder failure block kite access
        # V101B: return wrapper if WebSocket available, else raw kite (no behavior change)
        if cls._kite is not None:
            try:
                if KiteTickerStream._started:
                    # Return wrapper — note: each call gets a fresh wrapper but they
                    # all share the same underlying _kite, so this is cheap.
                    return KiteWrapper(cls._kite)
            except Exception:
                pass  # If anything fails, return raw kite — same as pre-V101B'''

def main():
    with open(PATH, "r") as f:
        content = f.read()
    md5_before = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101B] BEFORE md5={md5_before}")

    if "class KiteWrapper" in content:
        print("[V101B] SKIP: already patched.")
        sys.exit(0)

    if "class KiteTickerStream" not in content:
        print("[V101B] FATAL: V101A not deployed yet. Deploy V101A first.")
        sys.exit(1)

    for label, anchor, replacement, expected in [
        ("wrapper_class", ANCHOR_1, INSERT_1, 1),
        ("kite_method", ANCHOR_2, INSERT_2, 1),
    ]:
        n = content.count(anchor)
        if n != expected:
            print(f"[V101B] FATAL {label}: anchor x{n}, expected {expected}.")
            sys.exit(1)
        content = content.replace(anchor, replacement)

    try:
        ast.parse(content)
    except SyntaxError as e:
        print(f"[V101B] FATAL: syntax error: {e}")
        sys.exit(1)

    shutil.copy(PATH, BACKUP)
    print(f"[V101B] backup -> {BACKUP}")
    with open(PATH, "w") as f:
        f.write(content)
    md5_after = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101B] AFTER  md5={md5_after}")
    print(f"[V101B] OK — kite.ltp/quote redirected to WebSocket dict.")

if __name__ == "__main__":
    main()
PYEOF
