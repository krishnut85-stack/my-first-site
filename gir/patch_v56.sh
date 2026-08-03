#!/bin/bash
set -e
GIR="/home/globalbot/gir.py"
BAK="/home/globalbot/gir.py.bak_pre_v56_$(date +%Y%m%d_%H%M%S)"
echo "=== FIX_V56_TICK_SIZE ==="
echo "Backup: $BAK"
cp "$GIR" "$BAK"

python3 <<'PYEOF'
import sys
GIR = "/home/globalbot/gir.py"
with open(GIR, 'r') as f:
    content = f.read()

if "FIX_V56_TICK_SIZE" in content:
    print("ERROR: V56 already applied")
    sys.exit(1)

OLD_ANCHOR = """import math as _math_zr

def _snap_tick(price, tick=0.05):
    \"\"\"Snap price DOWN to nearest valid tick. NSE options tick = 0.05.\"\"\"
    if price is None or price <= 0:
        return price
    return round(_math_zr.floor(float(price) / tick) * tick, 2)

def _snap_tick_up(price, tick=0.05):
    \"\"\"Snap price UP to nearest valid tick (for target/trigger above market).\"\"\"
    if price is None or price <= 0:
        return price
    return round(_math_zr.ceil(float(price) / tick) * tick, 2)"""

NEW_ANCHOR = """import math as _math_zr

# FIX_V56_TICK_SIZE: NSE tick rules Apr 2025
def _fallback_tick_by_price(price):
    try:
        p = float(price or 0)
    except Exception:
        p = 0
    if p <= 0: return 0.05
    if p < 250: return 0.01
    if p < 1000: return 0.05
    if p < 5000: return 0.10
    if p < 10000: return 0.50
    if p < 20000: return 1.00
    return 5.00


class TickSizeCache:
    _cache = {}
    _exch_cache = {}
    _loaded_at = 0.0
    _TTL = 86400

    @classmethod
    def load(cls, kite=None, force=False):
        import time as _t
        now = _t.time()
        if not force and cls._cache and (now - cls._loaded_at) < cls._TTL:
            return len(cls._cache)
        if kite is None:
            try:
                kite = KiteSession.kite()
            except Exception:
                return 0
        if kite is None:
            return 0
        loaded = 0
        for exch in ("NSE", "NFO", "BSE"):
            try:
                instr = kite.instruments(exch) or []
                for i in instr:
                    sym = i.get("tradingsymbol", "")
                    ts = i.get("tick_size", 0) or 0
                    if sym and ts > 0:
                        if sym not in cls._cache:
                            cls._cache[sym] = float(ts)
                        cls._exch_cache[(exch, sym)] = float(ts)
                        loaded += 1
            except Exception as _e:
                try:
                    log.warning(f"[FIX_V56_TICK_SIZE] instruments({exch}) failed: {_e}")
                except Exception:
                    pass
        cls._loaded_at = now
        try:
            log.info(f"[FIX_V56_TICK_SIZE] loaded {loaded} instrument tick sizes (unique: {len(cls._cache)})")
        except Exception:
            pass
        return loaded

    @classmethod
    def get(cls, symbol, exchange=None, price=None):
        if not cls._cache:
            try:
                cls.load()
            except Exception:
                pass
        if exchange:
            ts = cls._exch_cache.get((exchange, symbol))
            if ts and ts > 0:
                return ts
        ts = cls._cache.get(symbol)
        if ts and ts > 0:
            return ts
        return _fallback_tick_by_price(price)


def get_tick(symbol=None, exchange=None, price=None):
    if symbol:
        return TickSizeCache.get(symbol, exchange=exchange, price=price)
    return _fallback_tick_by_price(price)


def _snap_tick(price, tick=None, symbol=None, exchange=None):
    if price is None or price <= 0:
        return price
    if tick is None or tick <= 0:
        if symbol:
            tick = TickSizeCache.get(symbol, exchange=exchange, price=price)
        else:
            tick = _fallback_tick_by_price(price)
    if not tick or tick <= 0:
        tick = 0.05
    decimals = max(0, -int(_math_zr.floor(_math_zr.log10(tick)))) if tick < 1 else 0
    return round(_math_zr.floor(float(price) / tick) * tick, decimals if decimals > 0 else 2)


def _snap_tick_up(price, tick=None, symbol=None, exchange=None):
    if price is None or price <= 0:
        return price
    if tick is None or tick <= 0:
        if symbol:
            tick = TickSizeCache.get(symbol, exchange=exchange, price=price)
        else:
            tick = _fallback_tick_by_price(price)
    if not tick or tick <= 0:
        tick = 0.05
    decimals = max(0, -int(_math_zr.floor(_math_zr.log10(tick)))) if tick < 1 else 0
    return round(_math_zr.ceil(float(price) / tick) * tick, decimals if decimals > 0 else 2)"""

if OLD_ANCHOR not in content:
    print("ERROR: anchor 1 not found")
    sys.exit(1)
content = content.replace(OLD_ANCHOR, NEW_ANCHOR, 1)
print("PATCH 1/3 applied: TickSizeCache + symbol-aware _snap_tick")

OLD_GTT_SAFE = """def _gtt_safe_trigger(trigger, ltp, side=\"SELL\", min_gap_pct=0.0030):
    \"\"\"FIX_V53_GAP: Return a Kite-valid GTT trigger price.

    Kite rejects triggers within 0.25% of LTP. We use 0.30% for safety margin.
    For SELL GTTs (stop-loss on long position), trigger must be BELOW LTP.
    If trigger is too close or above, snap it down to LTP * (1 - min_gap_pct).

    Returns tick-aligned price >= 0.05. Returns 0 if inputs invalid.
    \"\"\"
    if ltp <= 0 or trigger <= 0:
        return 0.0
    if side == \"SELL\":
        max_allowed = ltp * (1 - min_gap_pct)
        if trigger > max_allowed:
            return _snap_tick(max_allowed)
        return _snap_tick(trigger)
    else:  # BUY
        min_allowed = ltp * (1 + min_gap_pct)
        if trigger < min_allowed:
            return _snap_tick_up(min_allowed)
        return _snap_tick(trigger)"""

NEW_GTT_SAFE = """def _gtt_safe_trigger(trigger, ltp, side="SELL", min_gap_pct=0.0030, symbol=None, exchange=None):
    """FIX_V53_GAP + FIX_V56_TICK_SIZE: Return Kite-valid GTT trigger price."""
    if ltp <= 0 or trigger <= 0:
        return 0.0
    if side == "SELL":
        max_allowed = ltp * (1 - min_gap_pct)
        if trigger > max_allowed:
            return _snap_tick(max_allowed, symbol=symbol, exchange=exchange)
        return _snap_tick(trigger, symbol=symbol, exchange=exchange)
    else:
        min_allowed = ltp * (1 + min_gap_pct)
        if trigger < min_allowed:
            return _snap_tick_up(min_allowed, symbol=symbol, exchange=exchange)
        return _snap_tick(trigger, symbol=symbol, exchange=exchange)


def _gtt_safe_limit(trigger, side="SELL", offset_pct=0.005, symbol=None, exchange=None):
    """FIX_V56_TICK_SIZE: compute GTT limit price with correct per-symbol tick."""
    if trigger is None or trigger <= 0:
        return 0.0
    if side == "SELL":
        return _snap_tick(trigger * (1 - offset_pct), symbol=symbol, exchange=exchange)
    else:
        return _snap_tick_up(trigger * (1 + offset_pct), symbol=symbol, exchange=exchange)"""

if OLD_GTT_SAFE not in content:
    print("ERROR: anchor 2 not found")
    sys.exit(1)
content = content.replace(OLD_GTT_SAFE, NEW_GTT_SAFE, 1)
print("PATCH 2/3 applied: _gtt_safe_trigger V56-aware + _gtt_safe_limit")

OLD_INIT_TICK = """        # PATCH_V28_KITE_ONLY_EQUITY: DO NOT load from JSON. Kite is the only source of truth.
        # Same pattern as F&O V28_KITE_ONLY. Eliminates JBCHEPHARM-class phantom positions.
        # _sync_holdings() handles all stages: same-day (positions), T1, T2 (holdings).
        self.positions = {}  # start empty, populate from Kite only

        # FIX_V55_AMO_RECOVERY: track pending AMO BUY orders across restarts
        # Maps order_id -> {symbol, qty, registered_at}
        # Populated from kite.orders() at startup + every tick during open window
        self.pending_amo_fills = {}"""

NEW_INIT_TICK = """        # PATCH_V28_KITE_ONLY_EQUITY: DO NOT load from JSON. Kite is the only source of truth.
        self.positions = {}

        # FIX_V56_TICK_SIZE: load tick-size cache before any GTT calls
        try:
            _loaded = TickSizeCache.load()
            log.info(f"[FIX_V56_TICK_SIZE] tick cache loaded: {_loaded} instrument entries")
        except Exception as _tse:
            log.error(f"[FIX_V56_TICK_SIZE] cache load failed: {_tse} (using fallback buckets)")

        # FIX_V55_AMO_RECOVERY: track pending AMO BUY orders across restarts
        self.pending_amo_fills = {}"""

if OLD_INIT_TICK not in content:
    print("ERROR: anchor 3 not found")
    sys.exit(1)
content = content.replace(OLD_INIT_TICK, NEW_INIT_TICK, 1)
print("PATCH 3/3 applied: TickSizeCache.load() at EquityModule init")

with open(GIR, 'w') as f:
    f.write(content)

import py_compile
try:
    py_compile.compile(GIR, doraise=True)
    print("PYTHON SYNTAX OK")
except py_compile.PyCompileError as e:
    print(f"SYNTAX ERROR: {e}")
    sys.exit(1)

import subprocess
r = subprocess.run(["grep", "-c", "FIX_V56_TICK_SIZE", GIR], capture_output=True, text=True)
print(f"FIX_V56 markers: {r.stdout.strip()}")
r2 = subprocess.run(["wc", "-l", GIR], capture_output=True, text=True)
print(f"Lines: {r2.stdout.strip()}")
print("=== V56 APPLIED ===")
PYEOF

echo "Patch complete"
