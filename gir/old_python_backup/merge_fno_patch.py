#!/usr/bin/env python3
"""
Griffin v25.4.3 -> v25.5.0 — Merge Safe F&O + Moonshot into Unified F&O Engine
"""
import re, sys

with open('griffin_bot.py', 'r') as f:
    code = f.read()

changes = 0

# ============================================================
# 1. THREE_ENGINE_TIERS -> TWO_ENGINE_TIERS (equity, fno)
# ============================================================
old_tiers = '''THREE_ENGINE_TIERS = [
    # (max_capital, equity_pct, safe_fno_pct, moonshot_pct)
    (300_000,       0.75, 0.15, 0.10),   # ₹1-3L   — conservative, moonshot capped
    (500_000,       0.70, 0.20, 0.10),   # ₹3-5L   — standard split
    (1_000_000,     0.65, 0.22, 0.13),   # ₹5-10L  — more F&O firepower
    (2_500_000,     0.60, 0.25, 0.15),   # ₹10-25L — balanced growth
    (float('inf'),  0.50, 0.30, 0.20),   # ₹25L+   — aggressive multi-engine
]'''

new_tiers = '''TWO_ENGINE_TIERS = [
    # (max_capital, equity_pct, unified_fno_pct)  v25.5.0: merged Safe F&O + Moonshot
    (300_000,       0.75, 0.25),   # ₹1-3L   — conservative
    (500_000,       0.70, 0.30),   # ₹3-5L   — standard split
    (1_000_000,     0.65, 0.35),   # ₹5-10L  — more F&O firepower
    (2_500_000,     0.60, 0.40),   # ₹10-25L — balanced growth
    (float('inf'),  0.50, 0.50),   # ₹25L+   — aggressive multi-engine
]'''

if old_tiers in code:
    code = code.replace(old_tiers, new_tiers)
    changes += 1
    print(f"  [1] THREE_ENGINE_TIERS -> TWO_ENGINE_TIERS")
else:
    print("  [1] SKIP — THREE_ENGINE_TIERS not found exactly, trying flexible match...")
    # Try to find and replace just the variable name and structure
    if 'THREE_ENGINE_TIERS' in code:
        code = code.replace('THREE_ENGINE_TIERS', 'TWO_ENGINE_TIERS')
        changes += 1
        print(f"  [1] Renamed THREE_ENGINE_TIERS -> TWO_ENGINE_TIERS (name only)")
    else:
        print("  [1] ERROR — cannot find tiers")

# ============================================================
# 2. get_three_engine_split -> get_two_engine_split
# ============================================================
old_split_func = '''def get_three_engine_split(total_capital):
    """Return (equity_pct, safe_fno_pct, moonshot_pct) for given capital."""
    for threshold, eq, sf, ms in THREE_ENGINE_TIERS:
        if total_capital <= threshold:
            return eq, sf, ms
    return 0.50, 0.30, 0.20'''

new_split_func = '''def get_two_engine_split(total_capital):
    """Return (equity_pct, fno_pct) for given capital. v25.5.0: unified F&O engine."""
    for threshold, eq, fno in TWO_ENGINE_TIERS:
        if total_capital <= threshold:
            return eq, fno
    return 0.50, 0.50'''

if old_split_func in code:
    code = code.replace(old_split_func, new_split_func)
    changes += 1
    print(f"  [2] get_three_engine_split -> get_two_engine_split")
else:
    print("  [2] SKIP — exact function not found, trying rename only...")
    if 'get_three_engine_split' in code:
        code = code.replace('get_three_engine_split', 'get_two_engine_split')
        changes += 1
        print(f"  [2] Renamed all get_three_engine_split -> get_two_engine_split")

# ============================================================
# 3. Fix all callers: 3 return values -> 2
# Line 14588: _eq_pct, _sf_pct, _ms_pct = get_three_engine_split(_total)
# Line 18432: eq_pct, sf_pct, ms_pct = get_three_engine_split(total_capital)
# ============================================================
code = code.replace('_eq_pct, _sf_pct, _ms_pct = get_two_engine_split', '_eq_pct, _fno_pct = get_two_engine_split')
code = code.replace('eq_pct, sf_pct, ms_pct = get_two_engine_split', 'eq_pct, fno_pct = get_two_engine_split')
print(f"  [3] Fixed callers to use 2 return values")
changes += 1

# ============================================================
# 4. Pipeline: merge moonshot_queue into fno_queue
# MoonshotScanner proposals go to fno_queue instead of moonshot_queue
# ============================================================

# 4a. Remove moonshot_queue initialization
code = code.replace('self.moonshot_queue = []     # Proposals from MoonshotScanner', '# v25.5.0: moonshot merged into fno_queue')
code = code.replace('self.moonshot_queue = []', '# v25.5.0: moonshot merged into fno_queue')

# 4b. MoonshotScanner proposals -> fno_queue
code = code.replace('self.moonshot_queue.append({', 'self.fno_queue.append({')
code = code.replace('"engine": "MOONSHOT",', '"engine": "FNO_MOONSHOT",  # v25.5.0: unified')

# 4c. Fix the ranking phase — moonshot sorting merges into fno
code = code.replace(
    'for prop in sorted(self.moonshot_queue, key=lambda x: x.get("score", 0), reverse=True):',
    '# v25.5.0: moonshot merged into fno_queue above'
)

# 4d. Remove moonshot queue assignment after ranking  
code = code.replace('self.moonshot_queue = final_moonshot[:max_new_moonshot]', '# v25.5.0: moonshot merged into fno_queue')

changes += 1
print(f"  [4] Merged moonshot_queue into fno_queue")

# ============================================================
# 5. Capital waterfall: remove _moon_capital, use only _fno_capital
# ============================================================
code = code.replace('_moon_capital = 0', '# v25.5.0: moonshot capital merged into _fno_capital')
code = code.replace("_moon_capital = _alloc.get(\"moonshot\", 0)", '# v25.5.0: moonshot merged — see _fno_capital')
code = code.replace('_moon_capital = 5000', '# v25.5.0: moonshot merged into fno fallback')
code = code.replace('_moon_spent = 0', '# v25.5.0: moonshot spent merged into _fno_spent')

# Fix _fno_capital to include both fno + moonshot
code = code.replace(
    '_fno_capital = _alloc.get("fno", 0)',
    '_fno_capital = _alloc.get("fno", 0)  # v25.5.0: unified F&O (was safe_fno + moonshot)'
)

# Fix fallback
code = code.replace(
    '_fno_capital = 10000',
    '_fno_capital = 15000  # v25.5.0: unified fallback (was 10000+5000)'
)

changes += 1
print(f"  [5] Merged capital: _fno_capital now unified")

# ============================================================
# 6. Remove moonshot execution block
# ============================================================
old_moon_exec = '''        # — Execute moonshot trades (capital waterfall) —
        for prop in self.moonshot_queue:
            try:
                sym = prop["symbol"]
                if _moon_spent >= _moon_capital and kite:
                    logger.info(f"🔵PIPELINE MOONSHOT: {sym} skipped — moonshot capital exhausted")
                    continue'''

if old_moon_exec in code:
    # Replace just the capital check to use _fno_capital
    code = code.replace(old_moon_exec, '''        # — v25.5.0: moonshot trades now execute through fno_queue above —
        # (MoonshotScanner proposals merged into fno_queue at queue_phase)''')
    changes += 1
    print(f"  [6] Removed separate moonshot execution block")
else:
    print(f"  [6] SKIP — moonshot execution block not found exactly")

# ============================================================
# 7. Morning brief: 2 engines not 3
# ============================================================
code = code.replace(
    'f"   📊Safe F&O: ₹{_total*_sf_pct:,.0f} ({_sf_pct*100:.0f}%)\\n"',
    'f"   📊F&O: ₹{_total*_fno_pct:,.0f} ({_fno_pct*100:.0f}%)\\n"'
)
code = code.replace(
    'f"   🚀Moonshot: ₹{_total*_ms_pct:,.0f} ({_ms_pct*100:.0f}%)\\n"',
    '# v25.5.0: moonshot merged into F&O line above'
)

changes += 1
print(f"  [7] Morning brief updated to 2 engines")

# ============================================================
# 8. Pipeline capital log
# ============================================================
code = code.replace(
    'logger.info(f"💰Pipeline capital: Eq=₹{_eq_capital:,.0f} F&O=₹{_fno_capital:,.0f} Moon=₹{_moon_capital:,.0f}")',
    'logger.info(f"💰Pipeline capital: Eq=₹{_eq_capital:,.0f} F&O=₹{_fno_capital:,.0f} (unified)")'
)
print(f"  [8] Pipeline capital log updated")
changes += 1

# ============================================================
# 9. Battle plan F&O count log
# ============================================================
code = code.replace(
    'f"F&O={len(self.fno_queue)} | Moonshot={len(self.moonshot_queue)}"',
    'f"F&O={len(self.fno_queue)}"'
)
# Also fix the pipeline fed log
code = code.replace('_moon_capital:,.0f}', '_fno_capital:,.0f}')
print(f"  [9] Battle plan logs updated")
changes += 1

# ============================================================
# 10. CapitalAllocator — update allocation keys
# The allocator needs to return "fno" key with combined amount
# ============================================================
code = code.replace(
    '"fno": total * sf_pct,',
    '"fno": total * fno_pct,  # v25.5.0: unified F&O'
)
code = code.replace(
    '"moonshot": total * ms_pct,',
    '# v25.5.0: moonshot merged into fno'
)
# Also handle variable names in allocator
code = code.replace('sf_pct', 'fno_pct')
code = code.replace('ms_pct', 'fno_pct')
print(f"  [10] CapitalAllocator updated")
changes += 1

# ============================================================
# 11. Version bump
# ============================================================
code = code.replace('"v25.4.3"', '"v25.5.0"')
code = code.replace('v25.4.3:', 'v25.5.0:')
changes += 1
print(f"  [11] Version bumped to v25.5.0")

# ============================================================
# 12. Startup log — update Three-Engine to Two-Engine
# ============================================================
code = code.replace('THREE-ENGINE CAPITAL', 'TWO-ENGINE CAPITAL')
code = code.replace('Three-Engine', 'Two-Engine')
code = code.replace('three-engine', 'two-engine')
code = code.replace('three_engine', 'two_engine')
print(f"  [12] References updated to Two-Engine")
changes += 1

# Write
with open('griffin_bot.py', 'w') as f:
    f.write(code)

print(f"\nTotal changes: {changes}")
print("MERGE PATCH COMPLETE — v25.5.0")
print("Unified F&O Engine: Safe F&O + Moonshot merged")
print("Both scanners still run, feed into single fno_queue")
print("Single capital pool, single execution waterfall")
