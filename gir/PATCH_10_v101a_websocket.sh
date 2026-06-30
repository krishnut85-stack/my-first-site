#!/bin/bash
# Paste this entire block into ConnectBot. It applies patch 10 (v101a_websocket).
python3 << 'PYEOF'
#!/usr/bin/env python3
"""
PATCH_V101A_WEBSOCKET_OBSERVABILITY
====================================
PURPOSE:
  Open Kite WebSocket connection, subscribe to all NSE equity + F&O instruments,
  populate thread-safe LatestTicks dict, log tick rate every 60 sec.

  ZERO BEHAVIOR CHANGE. Bot continues using REST polling for everything.
  This patch ONLY observes — it doesn't redirect any existing call.

  V101b (next) will redirect kite.ltp/quote calls to read from this dict.

ARCHITECTURE:
  - New class KiteTickerStream (thread-safe LatestTicks dict)
  - Auto-reconnect on disconnect (Zerodha drops idle conns every few hours)
  - Logs tick rate, tick count, connection state every 60 sec
  - Started in main() AFTER KiteSession.login() succeeds

SAFETY:
  - WebSocket runs in background thread (daemon=True)
  - If WebSocket fails, main loop unaffected — bot keeps polling
  - LatestTicks dict is read-only for now; nothing depends on it
  - Reconnect uses exponential backoff capped at 60s
"""
import ast, hashlib, shutil, sys

PATH = "/home/globalbot/gir.py"
BACKUP = "/home/globalbot/gir_backup_pre_V101A_websocket.py"

# ==========================================================================
# CHANGE 1: Add KiteTickerStream class — insert AFTER KiteSession class
# Anchor: the line right after KiteSession's last method
# We anchor on the next class definition for stability
# ==========================================================================

ANCHOR_1 = '''class KiteSession:'''

# We'll insert the new class BEFORE KiteSession by replacing the anchor
# with the new class + the original anchor

INSERT_1 = '''class KiteTickerStream:
    """
    PATCH_V101A: Kite WebSocket tick stream wrapper.
    Maintains a thread-safe LatestTicks dict keyed by tradingsymbol.
    Observability-only in V101A — nothing reads from this dict yet.

    Usage:
        KiteTickerStream.start(api_key, access_token, symbol_token_map)
        # ... later ...
        tick = KiteTickerStream.get_tick("RELIANCE")  # returns dict or None
    """
    _ticker = None
    _started = False
    _lock = threading.Lock()
    _ticks = {}  # tradingsymbol -> {"ltp": float, "vol": int, "ts": datetime, ...}
    _token_to_sym = {}  # instrument_token -> tradingsymbol
    _sym_to_token = {}  # tradingsymbol -> instrument_token
    _tick_count = 0
    _last_log = None
    _last_connect = None
    _reconnect_count = 0
    _api_key = None
    _access_token = None
    _subscribed_tokens = []

    @classmethod
    def start(cls, api_key, access_token, symbol_token_map):
        """
        Start the WebSocket. symbol_token_map = {tradingsymbol: instrument_token}.
        Returns True on success, False if KiteTicker unavailable or init fails.
        """
        with cls._lock:
            if cls._started:
                log.info("[V101A] WebSocket already started, skipping.")
                return True
            try:
                from kiteconnect import KiteTicker
            except ImportError as _ie:
                log.error(f"[V101A] KiteTicker import failed: {_ie}. WebSocket disabled.")
                return False

            cls._api_key = api_key
            cls._access_token = access_token
            cls._sym_to_token = dict(symbol_token_map)
            cls._token_to_sym = {v: k for k, v in symbol_token_map.items()}
            cls._subscribed_tokens = list(symbol_token_map.values())
            cls._last_log = now_ist()

            try:
                cls._ticker = KiteTicker(api_key, access_token)
                cls._ticker.on_ticks = cls._on_ticks
                cls._ticker.on_connect = cls._on_connect
                cls._ticker.on_close = cls._on_close
                cls._ticker.on_error = cls._on_error
                cls._ticker.on_reconnect = cls._on_reconnect
                cls._ticker.on_noreconnect = cls._on_noreconnect
                cls._ticker.connect(threaded=True, disable_ssl_verification=False)

                # Reporter thread — logs tick rate every 60s
                _t = threading.Thread(target=cls._reporter_loop, name="V101A_TickReporter", daemon=True)
                _t.start()

                cls._started = True
                log.info(f"[V101A] WebSocket started. Subscribed to {len(cls._subscribed_tokens)} instruments.")
                return True
            except Exception as e:
                log.error(f"[V101A] start failed: {e}")
                cls._started = False
                return False

    @classmethod
    def _on_connect(cls, ws, response):
        """Subscribe + set mode QUOTE on connect."""
        try:
            cls._last_connect = now_ist()
            # Subscribe in chunks of 3000 (Kite max per message; we have ~3700 instruments)
            tokens = cls._subscribed_tokens
            CHUNK = 3000
            for i in range(0, len(tokens), CHUNK):
                batch = tokens[i:i+CHUNK]
                ws.subscribe(batch)
                ws.set_mode(ws.MODE_QUOTE, batch)
            log.info(f"[V101A] WebSocket connected. Mode=QUOTE. Tokens={len(tokens)}.")
        except Exception as e:
            log.error(f"[V101A] _on_connect error: {e}")

    @classmethod
    def _on_ticks(cls, ws, ticks):
        """Update LatestTicks dict on every tick batch."""
        try:
            now = now_ist()
            with cls._lock:
                for t in ticks:
                    tok = t.get("instrument_token")
                    sym = cls._token_to_sym.get(tok)
                    if not sym:
                        continue
                    cls._ticks[sym] = {
                        "ltp": float(t.get("last_price", 0) or 0),
                        "vol": int(t.get("volume_traded", 0) or 0),
                        "buy_qty": int(t.get("total_buy_quantity", 0) or 0),
                        "sell_qty": int(t.get("total_sell_quantity", 0) or 0),
                        "ohlc": t.get("ohlc", {}),
                        "ts": now,
                    }
                cls._tick_count += len(ticks)
        except Exception as e:
            log.debug(f"[V101A] _on_ticks error: {e}")

    @classmethod
    def _on_close(cls, ws, code, reason):
        log.warning(f"[V101A] WebSocket closed: code={code} reason={reason}")

    @classmethod
    def _on_error(cls, ws, code, reason):
        log.warning(f"[V101A] WebSocket error: code={code} reason={reason}")

    @classmethod
    def _on_reconnect(cls, ws, attempts_count):
        cls._reconnect_count += 1
        log.info(f"[V101A] WebSocket reconnecting attempt={attempts_count}")

    @classmethod
    def _on_noreconnect(cls, ws):
        log.error(f"[V101A] WebSocket gave up reconnecting after max attempts.")

    @classmethod
    def _reporter_loop(cls):
        """Log tick rate every 60s."""
        while True:
            try:
                time.sleep(60)
                with cls._lock:
                    n_syms = len(cls._ticks)
                    n_ticks = cls._tick_count
                    cls._tick_count = 0  # reset window counter
                    rc = cls._reconnect_count
                log.info(f"[V101A_REPORT] ticks/min={n_ticks} symbols_with_ticks={n_syms} reconnects={rc}")
            except Exception as e:
                log.debug(f"[V101A_REPORT] error: {e}")

    @classmethod
    def get_tick(cls, symbol):
        """Read latest tick for symbol. Returns None if no data."""
        with cls._lock:
            return cls._ticks.get(symbol)

    @classmethod
    def get_ltp(cls, symbol):
        """Convenience accessor — returns float or None."""
        with cls._lock:
            t = cls._ticks.get(symbol)
            return t["ltp"] if t else None

    @classmethod
    def stats(cls):
        """Return dict of current stream stats."""
        with cls._lock:
            return {
                "started": cls._started,
                "symbols_with_ticks": len(cls._ticks),
                "subscribed_tokens": len(cls._subscribed_tokens),
                "reconnect_count": cls._reconnect_count,
                "last_connect": str(cls._last_connect) if cls._last_connect else None,
            }


class KiteSession:'''

# ==========================================================================
# CHANGE 2: Start WebSocket in main() AFTER KiteSession.login() succeeds
# Anchor: right before "# Initialize modules"
# ==========================================================================

ANCHOR_2 = '''    # Initialize modules — completely independent
    equity = EquityModule()
    fno = FnoModule()'''

INSERT_2 = '''    # PATCH_V101A: Start Kite WebSocket tick stream (observability-only).
    # Failure is non-fatal — bot continues with REST polling.
    try:
        _kite_for_ws = KiteSession.kite()
        if _kite_for_ws:
            _v101_token_data = load_json(KITE_TOKEN_FILE, {})
            _v101_at = _v101_token_data.get("access_token", "")
            if _v101_at:
                # Build symbol -> token map for NSE equity + NFO derivatives
                _v101_sym_token = {}
                try:
                    for _exch in ("NSE", "NFO"):
                        try:
                            _v101_instr = _kite_for_ws.instruments(_exch) or []
                            for _i in _v101_instr:
                                _v101_ts = _i.get("tradingsymbol", "")
                                _v101_tok = _i.get("instrument_token", 0)
                                if _v101_ts and _v101_tok:
                                    _v101_sym_token[_v101_ts] = _v101_tok
                        except Exception as _v101ie:
                            log.warning(f"[V101A] instruments({_exch}) failed: {_v101ie}")
                    log.info(f"[V101A] built sym->token map: {len(_v101_sym_token)} instruments")
                    if _v101_sym_token:
                        # Cap at 9000 (3 connections x 3000) — but V101A uses 1 connection.
                        # Limit subscription to 3000 most-relevant: NSE equity first.
                        if len(_v101_sym_token) > 3000:
                            _v101_subset = dict(list(_v101_sym_token.items())[:3000])
                            log.info(f"[V101A] subscribing first 3000 of {len(_v101_sym_token)} (V101 uses 1 conn)")
                        else:
                            _v101_subset = _v101_sym_token
                        KiteTickerStream.start(KITE_API_KEY, _v101_at, _v101_subset)
                except Exception as _v101me:
                    log.warning(f"[V101A] map build failed: {_v101me}")
            else:
                log.warning("[V101A] no access_token available for WebSocket; skipping")
    except Exception as _v101e:
        log.warning(f"[V101A] WebSocket startup error (non-fatal): {_v101e}")

    # Initialize modules — completely independent
    equity = EquityModule()
    fno = FnoModule()'''


def main():
    with open(PATH, "r") as f:
        content = f.read()
    md5_before = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101A] BEFORE md5={md5_before}")

    if "class KiteTickerStream" in content:
        print("[V101A] SKIP: already patched.")
        sys.exit(0)

    for label, anchor, replacement, expected in [
        ("class_insert", ANCHOR_1, INSERT_1, 1),
        ("main_startup", ANCHOR_2, INSERT_2, 1),
    ]:
        n = content.count(anchor)
        if n != expected:
            print(f"[V101A] FATAL {label}: anchor x{n}, expected {expected}.")
            sys.exit(1)
        content = content.replace(anchor, replacement)

    try:
        ast.parse(content)
    except SyntaxError as e:
        print(f"[V101A] FATAL: syntax error: {e}")
        sys.exit(1)

    shutil.copy(PATH, BACKUP)
    print(f"[V101A] backup -> {BACKUP}")
    with open(PATH, "w") as f:
        f.write(content)
    md5_after = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101A] AFTER  md5={md5_after}")
    print(f"[V101A] OK — Kite WebSocket observability deployed.")

if __name__ == "__main__":
    main()
PYEOF
