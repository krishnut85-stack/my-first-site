#!/bin/bash
set -e
cd /home/globalbot
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v60p2_${STAMP}"
echo "=== Backup ==="
cp gir.py "$BACKUP"
wc -l "$BACKUP"

python3 << 'PYEOF'
import re, sys
PATH = "gir.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

def may_replace(old, new, tag):
    global src
    n = src.count(old)
    src = src.replace(old, new)
    print(f"  [{tag}] replaced {n}")

# P6: guard wrappers
guard_fn = '''
# FIX_V60P2_TICK_GUARD: blocks tick-non-compliant GTT API calls
def _safe_place_gtt(kite, **kwargs):
    try:
        tsym = kwargs.get("tradingsymbol")
        exch = kwargs.get("exchange")
        trigs = kwargs.get("trigger_values") or []
        orders = kwargs.get("orders") or []
        for tv in trigs:
            for o in orders:
                if not _validate_gtt_tick(tsym, exch, tv, o.get("price", 0)):
                    log.error(f"[V60P2_GUARD] place_gtt BLOCKED {exch}:{tsym} trig={tv} price={o.get('price')}")
                    return None
        return kite.place_gtt(**kwargs)
    except Exception as e:
        log.error(f"[V60P2_GUARD] place_gtt raised: {e}")
        raise

def _safe_modify_gtt(kite, **kwargs):
    try:
        tsym = kwargs.get("tradingsymbol")
        exch = kwargs.get("exchange")
        trigs = kwargs.get("trigger_values") or []
        orders = kwargs.get("orders") or []
        for tv in trigs:
            for o in orders:
                if not _validate_gtt_tick(tsym, exch, tv, o.get("price", 0)):
                    log.error(f"[V60P2_GUARD] modify_gtt BLOCKED {exch}:{tsym} trig={tv} price={o.get('price')}")
                    return None
        return kite.modify_gtt(**kwargs)
    except Exception as e:
        log.error(f"[V60P2_GUARD] modify_gtt raised: {e}")
        raise
'''

anchor = '    return t_ok and p_ok\n'
idx = src.find("def _validate_gtt_tick")
if idx < 0:
    print("  [P6] FAIL: _validate_gtt_tick not found"); sys.exit(1)
end_idx = src.find(anchor, idx)
if end_idx < 0:
    print("  [P6] FAIL: anchor not found"); sys.exit(1)
insert_at = end_idx + len(anchor)
if "_safe_place_gtt" not in src:
    src = src[:insert_at] + guard_fn + src[insert_at:]
    print("  [P6] OK guard wrappers inserted")
else:
    print("  [P6] already present")

# P7: equity fixes
may_replace('_live_sl = _snap_tick(info["avg"] * (1 - EQ_INITIAL_SL_PCT))',
    '_live_sl = _snap_sl_tick_up(info["avg"] * (1 - EQ_INITIAL_SL_PCT), symbol=sym, exchange="NSE")', "P7a")
may_replace('sl_price = _snap_tick(fill_avg * (1 - EQ_INITIAL_SL_PCT))',
    'sl_price = _snap_sl_tick_up(fill_avg * (1 - EQ_INITIAL_SL_PCT), symbol=sym, exchange="NSE")', "P7b")
may_replace('sl_price = _snap_tick(max(sl_price, fill_avg - 1.5 * _atr))',
    'sl_price = _snap_sl_tick_up(max(sl_price, fill_avg - 1.5 * _atr), symbol=sym, exchange="NSE")', "P7c")
may_replace('formula_sl = _snap_tick(ltp * (1 - EQ_TRAIL_SL_PCT))',
    'formula_sl = _snap_sl_tick_up(ltp * (1 - EQ_TRAIL_SL_PCT), symbol=sym, exchange="NSE")', "P7d")
may_replace('new_sl = _snap_tick(ltp * (1 - EQ_TRAIL_SL_PCT))',
    'new_sl = _snap_sl_tick_up(ltp * (1 - EQ_TRAIL_SL_PCT), symbol=sym, exchange="NSE")', "P7e")
may_replace('sl = max(formula_sl, _snap_tick(_pos_sl) if _pos_sl > 0 else 0.0, existing_trigger)',
    'sl = max(formula_sl, _snap_sl_tick_up(_pos_sl, symbol=sym, exchange="NSE") if _pos_sl > 0 else 0.0, existing_trigger)', "P7f")
may_replace('sl_price = min(sl_price, _snap_tick(price * (1 - EQ_INITIAL_SL_PCT)))',
    'sl_price = min(sl_price, _snap_sl_tick_up(price * (1 - EQ_INITIAL_SL_PCT), symbol=sym, exchange="NSE"))', "P7g")
may_replace('sl_price = _snap_tick(price * (1 - EQ_INITIAL_SL_PCT))',
    'sl_price = _snap_sl_tick_up(price * (1 - EQ_INITIAL_SL_PCT), symbol=sym, exchange="NSE")', "P7h")

with open(PATH, "w") as f:
    f.write(src)
print(f"\nWrote gir.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Compile ==="
python3 -c "import ast; ast.parse(open('gir.py').read()); print('syntax OK')"

echo ""
echo "=== Markers ==="
echo "FIX_V60 total: $(grep -c 'FIX_V60' gir.py)"
echo "_snap_sl_tick_up: $(grep -c '_snap_sl_tick_up' gir.py)"
echo "_safe_place_gtt: $(grep -c 'def _safe_place_gtt' gir.py)"
echo "_safe_modify_gtt: $(grep -c 'def _safe_modify_gtt' gir.py)"
echo "V60P2_GUARD: $(grep -c 'V60P2_GUARD' gir.py)"

echo ""
wc -l gir.py "$BACKUP"
echo ""
echo "=== DONE PART 2 ==="
echo "Rollback: cp $BACKUP gir.py && sudo systemctl restart globaleye"
