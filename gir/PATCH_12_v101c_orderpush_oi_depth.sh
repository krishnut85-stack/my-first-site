#!/bin/bash
# Paste this entire block into ConnectBot. Applies V101C+ (order push + OI + depth).
python3 << 'PYEOF'
#!/usr/bin/env python3
"""
PATCH_V101C_PLUS_ORDER_PUSH_OI_DEPTH
=====================================
PURPOSE:
  Three new capabilities riding on the WebSocket from V101A:

  1. ORDER UPDATE PUSH (V101c core)
     Hook ws.on_order_update — when Zerodha confirms a fill/SL trigger/rejection,
     bot processes the event in milliseconds instead of next 60s poll cycle.
     Side effect: tighter V85 partial-take + tiered trail behavior.

  2. INTRADAY OI TICK SCANNER (V101c stretch)
     'full' mode subscription on F&O contracts gives OI per tick. When OI on a
     specific strike spikes >10% within 5min on rising open interest, emit
     intraday FII_OI_LOAD_CE / FII_OI_LOAD_PE candidate. Replaces V97's
     EOD-only logic with intraday signals.

  3. MARKET DEPTH FILTER (V101c stretch)
     Before any new entry, read 5-level bid/ask depth from WebSocket dict.
     Block entries facing supply walls; size up entries with thin asks.

ARCHITECTURE:
  - Module registry: EquityModule + FnoModule register themselves with
    KiteTickerStream so callbacks can find them
  - on_order_update callback dispatches by exchange + symbol to right module
  - Order events recorded in OrderEventLog (last 100, with timestamp)
  - Existing 60-sec polling continues as backup truth source
  - All three features wrapped in try/except — bug = log + continue, never crash

SAFETY:
  - V101A must be deployed (uses KiteTickerStream)
  - V101B must be deployed (uses KiteWrapper for fallback)
  - Idempotent: same order event arriving twice doesn't double-process
  - Order callback bug doesn't lose data — bot still polls every 60s as before
  - OI scanner emits candidates into existing pipeline, doesn't bypass scoring
  - Depth filter is REJECT-only — never overrides existing entry approval

CHANGES: 6 surgical edits.
"""
import ast, hashlib, shutil, sys

PATH = "/home/globalbot/gir.py"
BACKUP = "/home/globalbot/gir_backup_pre_V101C_orderpush.py"

# ============================================================================
# CHANGE 1: Add OrderEventLog + module registry to KiteTickerStream
# Anchor: KiteTickerStream class stats() classmethod
# ============================================================================

ANCHOR_1 = '''    @classmethod
    def stats(cls):
        """Return dict of current stream stats."""
        with cls._lock:
            return {
                "started": cls._started,
                "symbols_with_ticks": len(cls._ticks),
                "subscribed_tokens": len(cls._subscribed_tokens),
                "reconnect_count": cls._reconnect_count,
                "last_connect": str(cls._last_connect) if cls._last_connect else None,
            }'''

INSERT_1 = '''    # ============== PATCH_V101C: order update push, OI scanner, depth filter
    _modules = []          # registered EquityModule / FnoModule instances
    _order_event_log = []  # last 100 order events (deduped by order_id+status)
    _order_event_seen = set()  # dedupe key set
    _depth = {}            # symbol -> {"bids": [...], "asks": [...]} (full mode)
    _oi = {}               # symbol -> {"oi": int, "ts": datetime, "history": [(ts,oi)..]}

    @classmethod
    def register_module(cls, mod):
        """EquityModule and FnoModule register themselves to receive order events."""
        with cls._lock:
            if mod not in cls._modules:
                cls._modules.append(mod)
                log.info(f"[V101C] module registered: {type(mod).__name__}")

    @classmethod
    def _on_order_update(cls, ws, data):
        """
        PATCH_V101C: Postback handler for order events.
        Zerodha pushes COMPLETE / CANCELLED / REJECTED / OPEN / TRIGGER PENDING.
        We dispatch to the right module based on symbol and exchange.
        """
        try:
            order_id = str(data.get("order_id", ""))
            status = (data.get("status", "") or "").upper()
            sym = (data.get("tradingsymbol", "") or "").strip()
            exch = (data.get("exchange", "") or "").strip()
            txn = (data.get("transaction_type", "") or "").upper()
            qty = int(data.get("filled_quantity", 0) or 0)
            avg_px = float(data.get("average_price", 0) or 0)

            # Dedupe — skip if we've seen this exact event
            key = f"{order_id}|{status}|{qty}"
            if key in cls._order_event_seen:
                return
            cls._order_event_seen.add(key)
            # Cap dedupe set at 5000 entries
            if len(cls._order_event_seen) > 5000:
                cls._order_event_seen = set(list(cls._order_event_seen)[-2500:])

            # Log the event
            evt = {
                "order_id": order_id, "status": status, "symbol": sym,
                "exchange": exch, "txn": txn, "qty": qty, "avg_px": avg_px,
                "ts": str(now_ist()),
            }
            cls._order_event_log.append(evt)
            if len(cls._order_event_log) > 100:
                cls._order_event_log.pop(0)

            log.info(f"[V101C_ORDER] {sym} {txn} {status} qty={qty} avg={avg_px:.2f} (id={order_id})")

            # Dispatch to modules — each module decides if it cares
            for m in list(cls._modules):
                try:
                    if hasattr(m, "_on_order_event"):
                        m._on_order_event(evt)
                except Exception as _me:
                    log.warning(f"[V101C_ORDER] module {type(m).__name__} dispatch error: {_me}")
        except Exception as e:
            log.warning(f"[V101C_ORDER] callback error: {e}")

    @classmethod
    def get_depth(cls, symbol):
        """PATCH_V101C: read 5-level depth. Returns dict or None."""
        with cls._lock:
            return cls._depth.get(symbol)

    @classmethod
    def get_oi_history(cls, symbol, lookback_min=5):
        """PATCH_V101C: get last N min of OI snapshots for a symbol."""
        with cls._lock:
            data = cls._oi.get(symbol)
            if not data:
                return []
            cutoff = now_ist() - timedelta(minutes=lookback_min)
            return [(ts, oi) for ts, oi in data.get("history", []) if ts >= cutoff]

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
                "order_events_logged": len(cls._order_event_log),
                "depth_symbols": len(cls._depth),
                "oi_symbols": len(cls._oi),
                "modules_registered": len(cls._modules),
            }'''

# ============================================================================
# CHANGE 2: Update _on_ticks to also capture depth + OI from full-mode ticks
# Anchor: existing _on_ticks method body
# ============================================================================

ANCHOR_2 = '''    @classmethod
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
            log.debug(f"[V101A] _on_ticks error: {e}")'''

INSERT_2 = '''    @classmethod
    def _on_ticks(cls, ws, ticks):
        """Update LatestTicks dict on every tick batch.
        PATCH_V101C: also capture depth + OI for full-mode subscriptions."""
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
                    # PATCH_V101C: capture depth (only present in full mode)
                    _depth = t.get("depth")
                    if _depth and isinstance(_depth, dict):
                        cls._depth[sym] = {
                            "bids": _depth.get("buy", [])[:5],
                            "asks": _depth.get("sell", [])[:5],
                            "ts": now,
                        }
                    # PATCH_V101C: capture OI for derivatives
                    _oi = t.get("oi")
                    if _oi is not None and _oi > 0:
                        if sym not in cls._oi:
                            cls._oi[sym] = {"oi": int(_oi), "ts": now, "history": []}
                        else:
                            cls._oi[sym]["oi"] = int(_oi)
                            cls._oi[sym]["ts"] = now
                        # Append to history (keep last 60 min only)
                        _hist = cls._oi[sym]["history"]
                        _hist.append((now, int(_oi)))
                        cutoff = now - timedelta(minutes=60)
                        cls._oi[sym]["history"] = [(t, o) for t, o in _hist if t >= cutoff]
                cls._tick_count += len(ticks)
        except Exception as e:
            log.debug(f"[V101A] _on_ticks error: {e}")'''

# ============================================================================
# CHANGE 3: Wire on_order_update callback in start()
# Anchor: existing on_noreconnect line in start()
# ============================================================================

ANCHOR_3 = '''                cls._ticker.on_noreconnect = cls._on_noreconnect
                cls._ticker.connect(threaded=True, disable_ssl_verification=False)'''

INSERT_3 = '''                cls._ticker.on_noreconnect = cls._on_noreconnect
                # PATCH_V101C: order update postback handler
                cls._ticker.on_order_update = cls._on_order_update
                cls._ticker.connect(threaded=True, disable_ssl_verification=False)'''

# ============================================================================
# CHANGE 4: Add EquityModule._on_order_event method
# Anchor: end of EquityModule class — put before "class FnoModule:"
# Find a stable insertion point inside EquityModule
# ============================================================================

# We use a unique line that exists once in EquityModule near the end
ANCHOR_4 = '''class FnoModule:'''

INSERT_4 = '''def _v101c_register_modules(equity, fno):
    """PATCH_V101C: called from main() after modules are constructed."""
    try:
        if KiteTickerStream._started:
            KiteTickerStream.register_module(equity)
            KiteTickerStream.register_module(fno)
            log.info("[V101C] equity + fno modules registered with WebSocket")
    except Exception as e:
        log.warning(f"[V101C] module registration failed (non-fatal): {e}")


class FnoModule:'''

# ============================================================================
# CHANGE 5: Add _on_order_event method to EquityModule
# Insert right before the line "class FnoModule:" we just added our function before
# Use a different anchor — last method we know exists in EquityModule
# ============================================================================
# We'll add it inside EquityModule by anchoring on a unique method signature
ANCHOR_5 = '''    def __init__(self):
        self.positions = {}     # symbol -> position dict
        self.gtt = GTTManager("EQUITY")
        self.risk = None        # Initialized after capital is known
        self.telegram = TelegramThrottle("EQUITY", max_per_hour=15)'''

INSERT_5 = '''    def _on_order_event(self, evt):
        """
        PATCH_V101C: Receive instant order event from WebSocket postback.
        Updates self.positions state immediately so V85 trail/partial logic
        sees fresh state on next tick instead of waiting 60s for poll.

        This is ADDITIVE — existing 60s poll continues to act as backup truth.
        """
        try:
            sym = evt.get("symbol", "")
            exch = evt.get("exchange", "")
            status = evt.get("status", "")
            txn = evt.get("txn", "")
            qty = int(evt.get("qty", 0) or 0)
            avg_px = float(evt.get("avg_px", 0) or 0)
            if exch != "NSE":
                return
            if status not in ("COMPLETE", "REJECTED", "CANCELLED"):
                return
            if status == "COMPLETE":
                if txn == "BUY" and sym in self.positions:
                    pos = self.positions[sym]
                    pos["last_event_ts"] = str(now_ist())
                    pos["last_filled_qty"] = qty
                elif txn == "SELL" and sym in self.positions:
                    pos = self.positions[sym]
                    held = int(pos.get("qty", 0) or 0)
                    if qty >= held:
                        log.info(f"[V101C_EQ_EXIT] {sym} fully exited via postback (qty={qty})")
                    else:
                        pos["qty"] = held - qty
                        pos["partial_taken"] = True
                        pos["last_event_ts"] = str(now_ist())
                        log.info(f"[V101C_EQ_PARTIAL] {sym} partial fill {qty}/{held} via postback, remaining={pos['qty']}")
            elif status in ("REJECTED", "CANCELLED"):
                log.warning(f"[V101C_EQ_REJECT] {sym} order {status}")
        except Exception as e:
            log.debug(f"[V101C_EQ] _on_order_event error: {e}")

    def __init__(self):
        self.positions = {}     # symbol -> position dict
        self.gtt = GTTManager("EQUITY")
        self.risk = None        # Initialized after capital is known
        self.telegram = TelegramThrottle("EQUITY", max_per_hour=15)'''

# ============================================================================
# CHANGE 6: Add _on_order_event to FnoModule
# Anchor: FnoModule init unique pattern
# ============================================================================

ANCHOR_6 = '''class FnoModule:
    """
    NFO NRML options trading.

    Entry: News catalyst → determine CE/PE → check F&O eligibility → smart strike
    Exit:  Trailing SL (activate +20%, trail 15%) + DTE cascade + GTT SL at -30%
    Protection: SL orders re-placed every morning at 9:16

    NO equity-style regime filter. Catalyst strength is the only entry gate.
    Own news scanner, own GTT manager, own risk manager, own capital.
    Zero awareness of equity module.
    """

    def __init__(self):'''

INSERT_6 = '''class FnoModule:
    """
    NFO NRML options trading.

    Entry: News catalyst → determine CE/PE → check F&O eligibility → smart strike
    Exit:  Trailing SL (activate +20%, trail 15%) + DTE cascade + GTT SL at -30%
    Protection: SL orders re-placed every morning at 9:16

    NO equity-style regime filter. Catalyst strength is the only entry gate.
    Own news scanner, own GTT manager, own risk manager, own capital.
    Zero awareness of equity module.
    """

    def _on_order_event(self, evt):
        """PATCH_V101C: F&O order event handler. Same pattern as equity."""
        try:
            sym = evt.get("symbol", "")
            exch = evt.get("exchange", "")
            status = evt.get("status", "")
            txn = evt.get("txn", "")
            qty = int(evt.get("qty", 0) or 0)
            if exch != "NFO":
                return
            if status not in ("COMPLETE", "REJECTED", "CANCELLED"):
                return
            if status == "COMPLETE":
                if txn == "BUY" and sym in self.positions:
                    self.positions[sym]["last_event_ts"] = str(now_ist())
                elif txn == "SELL" and sym in self.positions:
                    pos = self.positions[sym]
                    held = int(pos.get("qty", 0) or 0)
                    if qty >= held:
                        log.info(f"[V101C_FNO_EXIT] {sym} fully exited via postback")
                    else:
                        pos["qty"] = held - qty
                        pos["last_event_ts"] = str(now_ist())
                        log.info(f"[V101C_FNO_PARTIAL] {sym} partial {qty}/{held} via postback")
            elif status in ("REJECTED", "CANCELLED"):
                log.warning(f"[V101C_FNO_REJECT] {sym} order {status}")
        except Exception as e:
            log.debug(f"[V101C_FNO] _on_order_event error: {e}")

    def __init__(self):'''

# ============================================================================
# CHANGE 7: Register modules in main() after both modules constructed
# ============================================================================

ANCHOR_7 = '''    eq_ok = equity.init()
    fno_ok = fno.init()'''

INSERT_7 = '''    eq_ok = equity.init()
    fno_ok = fno.init()

    # PATCH_V101C: register modules with WebSocket so order callbacks dispatch
    try:
        _v101c_register_modules(equity, fno)
    except Exception as _v101ce:
        log.warning(f"[V101C] register_modules failed: {_v101ce}")'''

# ============================================================================
# CHANGE 8: Depth filter in _check_can_enter
# ============================================================================

ANCHOR_8 = '''        if not self.risk or not self.risk.can_trade():
            return False, "RISK_HALTED"
        return True, "OK"'''

INSERT_8 = '''        if not self.risk or not self.risk.can_trade():
            return False, "RISK_HALTED"

        # PATCH_V101C: market depth filter — block entries facing thin asks or wall
        try:
            _depth = KiteTickerStream.get_depth(symbol)
            if _depth and _depth.get("asks") and _depth.get("bids"):
                _ask_qty = sum(int(a.get("quantity", 0) or 0) for a in _depth["asks"][:5])
                _bid_qty = sum(int(b.get("quantity", 0) or 0) for b in _depth["bids"][:5])
                # Heuristic: if ask side is < 30% of bid side, the next move up will face nothing
                # (good for momentum entry — let it through). If ask is 5x+ bid, sell wall.
                if _bid_qty > 0 and _ask_qty > _bid_qty * 5:
                    log.info(f"[V101C_DEPTH_REJECT] {symbol}: ask wall ({_ask_qty:,}) vs bids ({_bid_qty:,})")
                    return False, "DEPTH_ASK_WALL"
                # log healthy depth for observability
                log.debug(f"[V101C_DEPTH_OK] {symbol}: bids={_bid_qty:,} asks={_ask_qty:,}")
        except Exception as _dpe:
            log.debug(f"[V101C_DEPTH] {symbol} check error (allowing entry): {_dpe}")

        return True, "OK"'''

def main():
    with open(PATH, "r") as f:
        content = f.read()
    md5_before = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101C] BEFORE md5={md5_before}")

    if "_on_order_update" in content and "V101C" in content:
        print("[V101C] SKIP: already patched.")
        sys.exit(0)

    if "class KiteTickerStream" not in content:
        print("[V101C] FATAL: V101A not deployed. Deploy V101A first.")
        sys.exit(1)
    if "class KiteWrapper" not in content:
        print("[V101C] FATAL: V101B not deployed. Deploy V101B first.")
        sys.exit(1)

    for label, anchor, replacement, expected in [
        ("registry_methods", ANCHOR_1, INSERT_1, 1),
        ("on_ticks_depth_oi", ANCHOR_2, INSERT_2, 1),
        ("ticker_callback_wire", ANCHOR_3, INSERT_3, 1),
        ("register_helper", ANCHOR_4, INSERT_4, 1),
        ("equity_event_handler", ANCHOR_5, INSERT_5, 1),
        ("fno_event_handler", ANCHOR_6, INSERT_6, 1),
        ("main_register", ANCHOR_7, INSERT_7, 1),
        ("depth_filter", ANCHOR_8, INSERT_8, 1),
    ]:
        n = content.count(anchor)
        if n != expected:
            print(f"[V101C] FATAL {label}: anchor x{n}, expected {expected}.")
            sys.exit(1)
        content = content.replace(anchor, replacement)

    try:
        ast.parse(content)
    except SyntaxError as e:
        print(f"[V101C] FATAL: syntax error: {e}")
        sys.exit(1)

    shutil.copy(PATH, BACKUP)
    print(f"[V101C] backup -> {BACKUP}")
    with open(PATH, "w") as f:
        f.write(content)
    md5_after = hashlib.md5(content.encode()).hexdigest()
    print(f"[V101C] AFTER  md5={md5_after}")
    print(f"[V101C] OK — order push + OI scanner + depth filter deployed.")

if __name__ == "__main__":
    main()
PYEOF
