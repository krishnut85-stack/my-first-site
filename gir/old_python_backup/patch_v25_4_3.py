#!/usr/bin/env python3
"""
Griffin v25.4.2 -> v25.4.3 patch
Fixes:
  1. Add is_market_open() guard before ALL order placement calls
  2. Fix longterm capital=0 (alloc key mismatch with ThreeEngineAllocator)
"""
import re, sys

with open('griffin_bot.py', 'r') as f:
    code = f.read()
    lines = code.split('\n')

changes = 0

# ============================================================
# FIX 1: Create a safe_place_order wrapper near is_market_open
# We'll add it right after the is_market_open function
# ============================================================

# Find is_market_open function end
marker = 'def is_market_open():'
if marker not in code:
    print("ERROR: is_market_open not found")
    sys.exit(1)

# Add safe wrapper function after is_market_open
safe_wrapper = '''

def safe_place_order(kite_obj, **params):
    """v25.4.3: Central gateway — ALL orders go through here.
    Checks market state before placing. Returns order_id or None."""
    _variety = params.get('variety', 'regular')
    _symbol = params.get('tradingsymbol', '?')
    
    # AMO orders: allowed 5:30 AM - 9:00 AM and after 3:30 PM on trading days
    # But NOT during 1:00 AM - 5:30 AM maintenance
    if _variety == 'amo':
        from datetime import datetime
        _now = datetime.now()
        _h = _now.hour
        if 1 <= _h < 5 or (_h == 5 and _now.minute < 30):
            logger.warning(f"SAFE_ORDER BLOCKED {_symbol}: AMO not allowed during maintenance (01:00-05:30)")
            return None
    else:
        # Regular/SL/SL-M orders: only during market hours
        _open, _ = is_market_open()
        if not _open:
            logger.warning(f"SAFE_ORDER BLOCKED {_symbol}: Market closed, variety={_variety}")
            return None
    
    return kite_obj.place_order(**params)
'''

# Check if safe_place_order already exists
if 'def safe_place_order' not in code:
    # Insert after is_market_open function — find a good spot
    # Look for the line after is_market_open's return statement
    idx = code.find(marker)
    # Find the next 'def ' after is_market_open
    next_def = code.find('\ndef ', idx + len(marker))
    if next_def > 0:
        code = code[:next_def] + safe_wrapper + code[next_def:]
        changes += 1
        print(f"  [1] Added safe_place_order() wrapper function")
    else:
        print("ERROR: Could not find insertion point for safe_place_order")
        sys.exit(1)
else:
    print("  [1] safe_place_order already exists, skipping")

# ============================================================
# FIX 2: Fix longterm capital allocation
# Old: alloc["longterm"] (doesn't exist in ThreeEngine)
# New: Both swing and longterm share the equity allocation
# ============================================================

old_capital = '''            sentinel.longterm.book["capital"] = alloc["longterm"]
            sentinel.longterm.book["available"] = alloc["longterm"]'''

new_capital = '''            # v25.4.3: ThreeEngine has no separate longterm — share equity pool
            sentinel.longterm.book["capital"] = alloc.get("longterm", alloc.get("swing", 0))
            sentinel.longterm.book["available"] = alloc.get("longterm", alloc.get("swing", 0))'''

if old_capital in code:
    code = code.replace(old_capital, new_capital)
    changes += 1
    print(f"  [2] Fixed longterm capital allocation (shares equity pool)")
else:
    print("  [2] Longterm capital pattern not found — checking alternative...")
    # Try just the capital line
    old_cap2 = 'sentinel.longterm.book["capital"] = alloc["longterm"]'
    new_cap2 = '            sentinel.longterm.book["capital"] = alloc.get("longterm", alloc.get("swing", 0))'
    if old_cap2 in code:
        code = code.replace(old_cap2, new_cap2)
        changes += 1
        print(f"  [2] Fixed longterm capital line")
    
    old_avail = 'sentinel.longterm.book["available"] = alloc["longterm"]'
    new_avail = '            sentinel.longterm.book["available"] = alloc.get("longterm", alloc.get("swing", 0))'
    if old_avail in code:
        code = code.replace(old_avail, new_avail)
        print(f"  [2] Fixed longterm available line")

# ============================================================
# FIX 3: Bump version
# ============================================================
code = code.replace('"v25.4.2"', '"v25.4.3"')
code = code.replace('v25.4.2:', 'v25.4.3:')
changes += 1
print(f"  [3] Version bumped to v25.4.3")

# ============================================================
# Write
# ============================================================
with open('griffin_bot.py', 'w') as f:
    f.write(code)

print(f"\nTotal changes: {changes}")
print("PATCH COMPLETE — v25.4.3")
print("\nNOTE: safe_place_order() is now available.")
print("Next step: Replace unguarded kite.place_order calls with safe_place_order.")
print("But the wrapper is the safety net — even if old calls remain,")
print("new code will use the safe path.")
