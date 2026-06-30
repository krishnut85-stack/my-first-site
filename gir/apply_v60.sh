#!/bin/bash
set -e
cd /home/globalbot
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v60_${STAMP}"
echo "=== Backup ==="
cp gir.py "$BACKUP"
wc -l "$BACKUP"

python3 << 'PYEOF'
import re, sys
PATH = "gir.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

def must_replace(old, new, tag):
    global src
    n = src.count(old)
    if n == 0:
        print(f"  [{tag}] FAIL: pattern not found"); sys.exit(1)
    src = src.replace(old, new)
    print(f"  [{tag}] OK replaced {n}")

def may_replace(old, new, tag):
    global src
    n = src.count(old)
    src = src.replace(old, new)
    print(f"  [{tag}] replaced {n}")

# P1: option-aware fallback
old_fb = '''def _fallback_tick_by_price(price):
    # FIX_V56_TICK_SIZE: derive tick from NSE price bucket when Kite cache unavailable
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
    return 5.00'''
new_fb = '''def _fallback_tick_by_price(price, is_option=False):
    # FIX_V60_TICK_SL_UP: option-aware. NFO options ALWAYS 0.05.
    if is_option:
        return 0.05
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
    return 5.00'''
must_replace(old_fb, new_fb, "P1")

# P2: insert helpers after _snap_tick_up
anchor = '    return round(_math_zr.ceil(float(price) / tick) * tick, decimals if decimals > 0 else 2)\n'
if src.count(anchor) < 1:
    print("  [P2] FAIL: anchor not found"); sys.exit(1)
helpers = anchor + '''
# FIX_V60_TICK_SL_UP
def _snap_sl_tick_up(price, symbol, exchange):
    if not symbol or not exchange:
        raise ValueError(f"[V60] _snap_sl_tick_up needs symbol+exchange")
    return _snap_tick_up(price, symbol=symbol, exchange=exchange)

def _validate_gtt_tick(symbol, exchange, trigger, limit_price):
    try:
        tick = TickSizeCache.get(symbol, exchange=exchange, price=trigger)
    except Exception:
        tick = None
    if not tick or tick <= 0:
        is_opt = (exchange == "NFO") and (symbol.endswith("CE") or symbol.endswith("PE"))
        tick = _fallback_tick_by_price(trigger, is_option=is_opt)
    try:
        t_ok = abs(round(float(trigger)/tick)*tick - float(trigger)) < 0.001
        p_ok = abs(round(float(limit_price)/tick)*tick - float(limit_price)) < 0.001
    except Exception:
        return False
    if not t_ok:
        log.error(f"[V60_TICK_GUARD] BLOCK {exchange}:{symbol} trig={trigger} tick={tick}")
    if not p_ok:
        log.error(f"[V60_TICK_GUARD] BLOCK {exchange}:{symbol} price={limit_price} tick={tick}")
    return t_ok and p_ok
'''
idx = src.find(anchor)
src = src[:idx] + helpers + src[idx+len(anchor):]
print("  [P2] OK helpers inserted")

# P3: offset constants
m = re.search(r'(FNO_SL_PCT\s*=\s*[0-9.]+[^\n]*\n)', src)
if m and "FNO_GTT_LIMIT_OFFSET" not in src:
    ins = m.group(1) + 'FNO_GTT_LIMIT_OFFSET = 0.005  # FIX_V60: was 5%\n' + 'EQ_GTT_LIMIT_OFFSET = 0.05  # FIX_V60\n'
    src = src.replace(m.group(1), ins, 1)
    print("  [P3] OK constants added")
else:
    print("  [P3] skipped")

# P4: F&O limit price
may_replace(
    '_snap_tick(final_sl * 0.95)',
    '_snap_tick(final_sl * (1 - FNO_GTT_LIMIT_OFFSET), symbol=tsym, exchange="NFO")',
    "P4 F&O limit"
)

# P5: F&O SL call sites
may_replace(
    "formula_sl = _snap_tick(ltp * (1 - stage_pct))",
    'formula_sl = _snap_sl_tick_up(ltp * (1 - stage_pct), symbol=tsym, exchange="NFO")',
    "P5a"
)
may_replace(
    "formula_sl = _snap_tick(max(raw_sl, breakeven_sl))",
    'formula_sl = _snap_sl_tick_up(max(raw_sl, breakeven_sl), symbol=tsym, exchange="NFO")',
    "P5b"
)
may_replace(
    "_snap_tick(pos_sl) if pos_sl > 0 else 0.0",
    '_snap_sl_tick_up(pos_sl, symbol=tsym, exchange="NFO") if pos_sl > 0 else 0.0',
    "P5c"
)
may_replace(
    "capped = _snap_tick(ltp * 0.85)",
    'capped = _snap_sl_tick_up(ltp * 0.85, symbol=tsym, exchange="NFO")',
    "P5d"
)
may_replace(
    '_safe_sl = _gtt_safe_trigger(final_sl, ltp, side="SELL")',
    '_safe_sl = _gtt_safe_trigger(final_sl, ltp, side="SELL", symbol=tsym, exchange="NFO")',
    "P5e"
)

with open(PATH, "w") as f:
    f.write(src)
print(f"\nWrote gir.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Compile check ==="
python3 -c "import ast; ast.parse(open('gir.py').read()); print('syntax OK')"
echo ""
echo "=== Markers ==="
echo "FIX_V60: $(grep -c FIX_V60 gir.py)"
echo "_snap_sl_tick_up: $(grep -c _snap_sl_tick_up gir.py)"
echo "FNO_GTT_LIMIT_OFFSET: $(grep -c FNO_GTT_LIMIT_OFFSET gir.py)"
echo ""
grep -n "FIX_V60" gir.py | head -8
echo ""
wc -l gir.py "$BACKUP"
echo ""
echo "=== DONE. Review output above. If clean, restart: ==="
echo "  sudo systemctl restart globaleye"
echo "  sudo journalctl -u globaleye -n 30 --no-pager"
echo "Rollback: cp $BACKUP gir.py && sudo systemctl restart globaleye"
