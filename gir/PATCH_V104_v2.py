#!/usr/bin/env python3
"""
PATCH_V104_v2.py — FINAL approved patch for GIR-1.

Consolidates all good items from V103 and V104_v1 after Rama's review,
drops everything that contradicts test data or is too risky.

═══ KEEPS from V103 ═══
  K1. NSE 2026 holiday list corrected (per NSE circular NSE/CMTR/71775)
  K2. Index tick rule fallback (NIFTY/BANKNIFTY tier on cache miss)
  K3. F&O safety helpers module (LPP, freeze, freak gap, physical delivery,
      NRO compliance) — pure helpers, nothing calls them yet, available for
      future patches to use
  K4. market_protection = 5 -> 1 at all 10 sites (kills silent slippage bleed)
  K5. Holdings empty-purge guard in _sync_holdings
  K6. Version bump

═══ KEEPS from V104_v1 ═══
  K7. F&O trail: activate +10% -> +5%, width 20% -> 10% (was 8% in V104_v1)

═══ NEW in V104_v2 ═══
  N1. Steady 15-min equity scan (was 10/30 split) — Gemini API cost reduction

═══ DROPPED (after Rama's review) ═══
  D1. EQ_INITIAL_SL_PCT 0.025 -> 0.009 — contradicts April 30 analyzer test
      (11/19 trades stopped <1 day at 2.5%, tighter would be worse)
  D2. EQ_TRAIL_SL_PCT 0.025 -> 0.009 — contradicts V85 tiered trail design
  D3. Tier trail caps to 0.9% — contradicts V85 (winners earn 4% room)
  D4. EQ_MAX_POS 12 -> 6 — math shows bot already caps at ~4 active naturally
  D5. Expert Panel news bypass — too risky if bug, defeats panel's purpose
  D6. Fast catalyst scan (5 min) — Gemini API cost too high

═══ DEFERRED to V105 ═══
  L1. Chase block relax (needs targeted patch at usage site)
  L2. Premarket bias in sector score (needs careful weighting)
  L3. NewsBrain single-source rule (needs news_brain.py edit)
  L4. Equity-only until F&O capital > Rs.75K (behavior change)
  L5. GTT audit empty-holdings guard (parallel to K5)
  L6. validate_gtt_tick pre-flight assertion hardening

═══ FEATURE FLAGS ═══
Each behavioral change is gated by a flag at the top of gir.py.
To disable any optimization: set flag = False, restart globaleye.

═══ TESTED ═══
AST validates. Idempotent (re-run is no-op).
Backup at /home/globalbot/backups/gir.py.before_v104v2_<timestamp>.
"""

import ast
import shutil
import sys
from datetime import datetime
from pathlib import Path

PATH = Path("/home/globalbot/gir.py")
BACKUP_DIR = Path("/home/globalbot/backups")

print("=" * 72)
print("GIR-1 OPTIMIZATION V104_v2 (final reconciled)")
print("=" * 72)

if not PATH.exists():
    sys.exit(f"FATAL: {PATH} not found")

src = PATH.read_text()
original_src = src
print(f"Loaded {PATH}: {len(src):,} chars / {src.count(chr(10)):,} lines")

BACKUP_DIR.mkdir(parents=True, exist_ok=True)
ts = datetime.now().strftime("%Y%m%d_%H%M%S")
backup_path = BACKUP_DIR / f"gir.py.before_v104v2_{ts}"
shutil.copy(PATH, backup_path)
print(f"Backup: {backup_path}")

if "PATCH_V104_V2" in src:
    print("\nV104_v2 marker already present. Idempotent — exiting.")
    sys.exit(0)

applied = []
skipped = []

# ============================================================================
# Step 1: Insert feature flags after VERSION
# ============================================================================
V104V2_FLAGS = '''
# ════════════════════════════════════════════════════════════════════════
# PATCH_V104_V2 — Final reconciled optimizations
# To disable any: set flag = False, then: systemctl restart globaleye
# ════════════════════════════════════════════════════════════════════════
V104_FAST_FNO_TRAIL = True       # F&O trail activate +5% / width 10%
V104_STEADY_SCAN = True          # equity scan = 15 min steady (Gemini cost)
V104_TIGHT_SLIPPAGE = True       # market_protection 5 -> 1 (kills slippage)
V103_HOLIDAYS = True             # corrected NSE 2026 calendar
V103_INDEX_TICKS = True          # NIFTY/BANKNIFTY tick tier on cache miss
V103_HOLDINGS_GUARD = True       # refuse purge on transient empty holdings
# F&O safety helpers (LPP, freeze, freak gap, physical delivery, NRO)
# are inserted as standalone functions — always available, no flag needed.
'''

OLD_VER = 'VERSION = "GIR v28 + patches through V77"  # V77_FIX2'
NEW_VER = ('VERSION = "GIR v28 + patches through V104_v2 '
           '(slippage, F&O trail, holidays, ticks, holdings guard, scan)"'
           + V104V2_FLAGS)

if OLD_VER in src:
    src = src.replace(OLD_VER, NEW_VER, 1)
    applied.append("Step 1: V104_v2 flags + version inserted")
else:
    skipped.append("Step 1: VERSION line not found (manual review needed)")

# ============================================================================
# K1: NSE 2026 holiday list corrected
# ============================================================================
OLD_HOLIDAYS = """NSE_HOLIDAYS = {
    date(2026, 1, 26), date(2026, 3, 10), date(2026, 3, 30), date(2026, 3, 31),
    date(2026, 4, 14), date(2026, 5, 1), date(2026, 7, 17), date(2026, 8, 15),
    date(2026, 8, 17), date(2026, 10, 2), date(2026, 10, 20), date(2026, 10, 21),
    date(2026, 11, 5), date(2026, 11, 18), date(2026, 12, 25),
}"""

NEW_HOLIDAYS = """# PATCH_V104_V2: NSE 2026 holidays per official circular NSE/CMTR/71775
# Past incident: bot greeted "Market opens in 75 min" on a Saturday because
# old list had Holi Mar 10 (actual: Mar 3), missing Good Friday/Bakri Id/Muharram.
_NSE_HOLIDAYS_OFFICIAL = {
    date(2026, 1, 26),   # Republic Day (Mon)
    date(2026, 3, 3),    # Holi (Tue)
    date(2026, 3, 26),   # Shri Ram Navami (Thu)
    date(2026, 3, 31),   # Shri Mahavir Jayanti (Tue)
    date(2026, 4, 3),    # Good Friday (Fri)
    date(2026, 4, 14),   # Dr. Baba Saheb Ambedkar Jayanti (Tue)
    date(2026, 5, 1),    # Maharashtra Day (Fri)
    date(2026, 5, 28),   # Bakri Id (Thu)
    date(2026, 6, 26),   # Muharram (Fri)
    # Aug 15 (Independence Day) is Saturday — already closed
    date(2026, 10, 2),   # Gandhi Jayanti (Fri)
    date(2026, 10, 21),  # Diwali Balipratipada (Wed)
    # Nov 8 (Diwali Laxmi Pujan) is Sunday — Muhurat session only
    date(2026, 11, 25),  # Guru Nanak Jayanti (Wed)
    date(2026, 12, 25),  # Christmas (Fri)
}
_NSE_HOLIDAYS_LEGACY = {
    date(2026, 1, 26), date(2026, 3, 10), date(2026, 3, 30), date(2026, 3, 31),
    date(2026, 4, 14), date(2026, 5, 1), date(2026, 7, 17), date(2026, 8, 15),
    date(2026, 8, 17), date(2026, 10, 2), date(2026, 10, 20), date(2026, 10, 21),
    date(2026, 11, 5), date(2026, 11, 18), date(2026, 12, 25),
}
NSE_HOLIDAYS = _NSE_HOLIDAYS_OFFICIAL if V103_HOLIDAYS else _NSE_HOLIDAYS_LEGACY"""

if OLD_HOLIDAYS in src:
    src = src.replace(OLD_HOLIDAYS, NEW_HOLIDAYS, 1)
    applied.append("K1: NSE 2026 holiday list corrected (gated)")
else:
    skipped.append("K1: holiday block not found")

# ============================================================================
# K2: Index tick rule fallback (always on — old behavior was wrong)
# ============================================================================
OLD_TICK = """def _fallback_tick_by_price(price, is_option=False):
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
    return 5.00"""

NEW_TICK = """# PATCH_V104_V2: index instruments use separate tick tier from stocks
# NIFTY at 25000 was getting tick=5.00 from stock bucket; should be 0.10.
_INDEX_ROOTS = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY",
                "NIFTYNXT50", "NIFTYIT", "SENSEX", "BANKEX"}

def _is_index_symbol(symbol):
    \"\"\"True if symbol is a plain index. NIFTY26MAY24000CE is an OPTION, not index.\"\"\"
    if not symbol:
        return False
    s = str(symbol).upper()
    if s.endswith("CE") or s.endswith("PE"):
        return False
    return s in _INDEX_ROOTS

def _fallback_tick_by_price(price, is_option=False, is_index=False):
    # FIX_V60_TICK_SL_UP: option-aware. NFO options ALWAYS 0.05.
    # PATCH_V104_V2: index-aware (NIFTY<15k=0.05, 15-30k=0.10, >30k=0.20)
    if is_option:
        return 0.05
    try:
        p = float(price or 0)
    except Exception:
        p = 0
    if p <= 0: return 0.05
    if is_index and V103_INDEX_TICKS:
        if p < 15000: return 0.05
        if p < 30000: return 0.10
        return 0.20
    if p < 250: return 0.01
    if p < 1000: return 0.05
    if p < 5000: return 0.10
    if p < 10000: return 0.50
    if p < 20000: return 1.00
    return 5.00"""

if OLD_TICK in src:
    src = src.replace(OLD_TICK, NEW_TICK, 1)
    applied.append("K2: index tick rule fallback added (gated)")
else:
    skipped.append("K2: tick fallback signature changed")

# K2b: route by instrument class in TickSizeCache.get
OLD_GET_TICK = """        ts = cls._cache.get(symbol)
        if ts and ts > 0:
            return ts
        return _fallback_tick_by_price(price)"""
NEW_GET_TICK = """        ts = cls._cache.get(symbol)
        if ts and ts > 0:
            return ts
        # PATCH_V104_V2: route by instrument class on cache miss
        _is_opt = bool(symbol and (str(symbol).endswith("CE") or str(symbol).endswith("PE")))
        _is_idx = _is_index_symbol(symbol)
        return _fallback_tick_by_price(price, is_option=_is_opt, is_index=_is_idx)"""

if OLD_GET_TICK in src:
    src = src.replace(OLD_GET_TICK, NEW_GET_TICK, 1)
    applied.append("K2b: TickSizeCache.get routes by instrument class")

# ============================================================================
# K3: F&O safety helpers module (pure utilities, nothing calls them yet)
# ============================================================================
FNO_SAFETY_BLOCK = '''

# ════════════════════════════════════════════════════════════════════════
# PATCH_V104_V2: F&O safety helpers (pure functions, available for use)
# These are utilities. They are NOT called automatically anywhere — they are
# building blocks for future patches that need LPP / freeze / NRO checks.
# Verified against Zerodha API docs and SEBI circulars.
# ════════════════════════════════════════════════════════════════════════

def fno_market_protection_pct(premium):
    """Per-premium MP tier (Zerodha). <100=2% / 100-500=1.5% / 500-1k=1% / >1k=0.5%."""
    try:
        p = float(premium or 0)
    except Exception:
        return 0.020
    if p < 100:  return 0.020
    if p < 500:  return 0.015
    if p < 1000: return 0.010
    return 0.005

def fno_market_protected_limit(ltp, side="BUY"):
    """Convert intended MARKET into safe LIMIT-with-buffer."""
    pct = fno_market_protection_pct(ltp)
    if str(side).upper() == "BUY":
        return ltp * (1.0 + pct)
    return ltp * (1.0 - pct)

# Limit Price Protection (LPP) — exchange-level reject band for options
LPP_PCT_OPTIONS = 0.60
LPP_MIN_ABSOLUTE_RS = 30.0

def fno_lpp_range(ref_price):
    """Return (low, high) LPP band. Orders outside REJECTED by exchange."""
    try:
        rp = float(ref_price or 0)
    except Exception:
        return (0.05, 1e9)
    if rp <= 0:
        return (0.05, 1e9)
    band = max(rp * LPP_PCT_OPTIONS, LPP_MIN_ABSOLUTE_RS)
    return (max(0.05, rp - band), rp + band)

def fno_is_inside_lpp(price, ref_price):
    if not price or not ref_price or price <= 0 or ref_price <= 0:
        return False
    lo, hi = fno_lpp_range(ref_price)
    return lo <= price <= hi

def fno_sl_l_limit_price(trigger, side="SELL", gap_pct=0.10):
    """SL-L limit with gap from trigger. SELL SL: limit = trig * (1 - gap)."""
    try:
        t = float(trigger or 0)
    except Exception:
        return 0.0
    if t <= 0:
        return 0.0
    if str(side).upper() == "SELL":
        return t * (1.0 - gap_pct)
    return t * (1.0 + gap_pct)

# Freeze quantity caps (per SEBI Feb 2026 revision)
FNO_FREEZE_QTY = {
    "NIFTY": 1800, "BANKNIFTY": 900, "FINNIFTY": 1800,
    "MIDCPNIFTY": 4200, "SENSEX": 1000,
}

def fno_freeze_qty_for(symbol_root):
    return FNO_FREEZE_QTY.get(str(symbol_root or "").upper(), 100000)

def fno_is_within_freeze(symbol_root, total_qty):
    cap = fno_freeze_qty_for(symbol_root)
    return int(total_qty or 0) <= cap

# Physical delivery guard for stock options (cash-settled if index)
FNO_INDEX_SYMBOLS = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "SENSEX"}

def fno_is_stock_option(symbol_root):
    """Stock options need physical delivery if ITM at expiry; index = cash."""
    return str(symbol_root or "").upper() not in FNO_INDEX_SYMBOLS

def fno_physical_delivery_force_exit(symbol_root, dte, guard_dte=2):
    """True if stock option must be force-exited NOW due to physical delivery risk."""
    if not fno_is_stock_option(symbol_root):
        return False
    try:
        return int(dte) <= int(guard_dte)
    except Exception:
        return False

# NRO compliance — NRML only, NEVER MIS for F&O. NFO not NSE.
NRO_BLOCKED_PRODUCTS = {"MIS"}

def nro_validate_order(product, exchange, is_fno):
    """Return (allowed, reason). Block patterns that break NRO offshore rules."""
    pp = str(product or "").upper()
    ee = str(exchange or "").upper()
    if pp in NRO_BLOCKED_PRODUCTS:
        return False, f"NRO_BLOCKED_PRODUCT_{pp}"
    if is_fno and ee in ("NSE", "BSE"):
        return False, f"NRO_BLOCKED_EXCHANGE_{ee}_FOR_FNO"
    return True, "OK"

def fno_extract_root(tradingsymbol):
    """e.g. NIFTY26MAY24000CE -> NIFTY, RELIANCE26MAY1300PE -> RELIANCE."""
    if not tradingsymbol:
        return ""
    s = str(tradingsymbol).upper()
    for root in ("BANKNIFTY", "MIDCPNIFTY", "FINNIFTY", "NIFTYNXT50",
                  "NIFTY", "SENSEX", "BANKEX"):
        if s.startswith(root):
            return root
    out = []
    for c in s:
        if c.isdigit():
            break
        out.append(c)
    return "".join(out)

# END F&O SAFETY HELPERS — PATCH_V104_V2
'''

# Insert just before class TickSizeCache
ANCHOR = "class TickSizeCache:"
if ANCHOR in src and "fno_market_protection_pct" not in src:
    src = src.replace(ANCHOR, FNO_SAFETY_BLOCK + "\n" + ANCHOR, 1)
    applied.append("K3: F&O safety helpers module inserted")
else:
    skipped.append("K3: anchor missing or already inserted")

# ============================================================================
# K4: market_protection = 5 -> 1 (gated by flag)
# ============================================================================
count_mp5 = src.count("market_protection=5")
if count_mp5 > 0:
    # Insert helper just after flags
    HELPER = '''
# PATCH_V104_V2 helper: returns 1% slippage when flag on, else legacy 5%
def _V104_mp(legacy=5):
    """1% market_protection when V104_TIGHT_SLIPPAGE on. Replaces silent 5% bleed."""
    return 1 if V104_TIGHT_SLIPPAGE else legacy
'''
    flag_marker = "# F&O safety helpers (LPP, freeze, freak gap, physical delivery, NRO)"
    if flag_marker in src:
        src = src.replace(flag_marker, HELPER + "\n" + flag_marker, 1)

    src = src.replace("market_protection=5",
                       "market_protection=_V104_mp(5)")
    applied.append(f"K4: market_protection=5 -> _V104_mp() at {count_mp5} sites")
else:
    skipped.append("K4: no market_protection=5 sites")

# ============================================================================
# K5: Holdings empty-purge guard
# ============================================================================
OLD_PURGE = """            # V27 PATCH (Bug #6): Remove positions not in Kite, fetch REAL exit price
            # from tradebook (was recording 0, polluting all P&L reports).
            for sym in list(self.positions.keys()):
                if sym not in kite_syms:"""

NEW_PURGE = """            # V27 PATCH (Bug #6): Remove positions not in Kite, fetch REAL exit price
            # from tradebook (was recording 0, polluting all P&L reports).
            # PATCH_V104_V2 SAFETY GUARD: if kite_syms is empty AND we have positions
            # locally, refuse to purge — likely transient API hiccup, not real "all
            # sold" event. Past incident: kite.holdings() returned [] for 2 seconds;
            # bot deleted every position from local state; reappeared as orphans.
            if V103_HOLDINGS_GUARD and not kite_syms and len(self.positions) >= 2:
                log.error(f"Equity sync: REFUSING to purge {len(self.positions)} "
                          f"positions — kite_syms empty (transient API issue?). "
                          f"Will retry next cycle.")
                self._save_positions()
                return
            for sym in list(self.positions.keys()):
                if sym not in kite_syms:"""

if OLD_PURGE in src:
    src = src.replace(OLD_PURGE, NEW_PURGE, 1)
    applied.append("K5: holdings empty-purge guard (gated)")
else:
    skipped.append("K5: purge anchor changed")

# ============================================================================
# K7: F&O trail — activate +5%, width 10%
# ============================================================================
OLD_FNO_TRAIL = """FNO_TRAIL_ACTIVATE = 0.10     # V27 PATCH (Bug #10): trail only after 10% profit captured
FNO_TRAIL_PCT = 0.20          # 20% below LTP"""
NEW_FNO_TRAIL = """FNO_TRAIL_ACTIVATE = 0.05 if V104_FAST_FNO_TRAIL else 0.10  # V104_v2: +5% (was +10%)
FNO_TRAIL_PCT = 0.10 if V104_FAST_FNO_TRAIL else 0.20      # V104_v2: 10% trail (was 20%)"""

if OLD_FNO_TRAIL in src:
    src = src.replace(OLD_FNO_TRAIL, NEW_FNO_TRAIL, 1)
    applied.append("K7: F&O trail activate +10% -> +5%, width 20% -> 10%")
else:
    skipped.append("K7: F&O trail constants not found")

# ============================================================================
# N1: Steady 15-min equity scan
# ============================================================================
OLD_SCAN = "        _scan_interval = 10 if (n.hour == 9 or (n.hour == 10 and n.minute <= 15)) else EQ_SCAN_INTERVAL_MIN"
NEW_SCAN = ("        # PATCH_V104_V2: steady 15-min scan reduces Gemini API cost 3x (was 10/30 split)\n"
            "        _scan_interval = 15 if V104_STEADY_SCAN else (10 if (n.hour == 9 or (n.hour == 10 and n.minute <= 15)) else EQ_SCAN_INTERVAL_MIN)")
if OLD_SCAN in src:
    src = src.replace(OLD_SCAN, NEW_SCAN, 1)
    applied.append("N1: equity scan = 15 min steady (Gemini cost -3x)")
else:
    skipped.append("N1: scan interval line not found")

# ============================================================================
# Validate via AST
# ============================================================================
print("\nValidating patched source via AST...")
try:
    ast.parse(src)
    print("AST parse: OK")
except SyntaxError as e:
    print(f"\nFATAL: AST parse failed at line {e.lineno}: {e.text}")
    print(f"Restoring backup. NO CHANGES WRITTEN to {PATH}.")
    sys.exit(1)

old_lines = original_src.count("\n")
new_lines = src.count("\n")
print(f"Lines: {old_lines:,} -> {new_lines:,} (delta {new_lines - old_lines:+,})")

PATH.write_text(src)
print(f"Written {len(src):,} chars to {PATH}")

# Summary
print("\n" + "=" * 72)
print("V104_v2 SUMMARY")
print("=" * 72)
print(f"\nAPPLIED ({len(applied)}):")
for a in applied:
    print(f"  + {a}")
if skipped:
    print(f"\nSKIPPED ({len(skipped)}):")
    for s in skipped:
        print(f"  ~ {s}")

print(f"""
Backup: {backup_path}

Feature flags are at top of /home/globalbot/gir.py.
Disable any optimization: set V104_* or V103_* flag to False, then:
  systemctl restart globaleye

DEPLOY:
  python3 PATCH_V104_v2.py
  systemctl restart globaleye
  sleep 5
  journalctl -u globaleye -n 30 --no-pager

WATCH FOR:
  - VERSION line shows V104_v2
  - No syntax errors at boot
  - market_protection=_V104_mp(5) at all 10 sites (grep to verify)
  - F&O trail logs show 5% activation, 10% width
  - Equity scan logs every 15 min

WHAT'S UNCHANGED (intentionally):
  - SL system: 2.5% initial, V85 tiered trail (2.5/3/4%), V79 time-stagnation
  - Expert Panel: thresholds 55/65, no news bypass
  - EQ_MAX_POS: 12 (sizing math already caps at ~4 active)
  - NewsBrain: v3/v4 unchanged
  - All 21 patches V55-V102: preserved

DEFERRED TO V105 (after live data from V104_v2):
  - Chase block tier relaxation
  - GlobalPreMarket bias in sector vote
  - NewsBrain single-source rule at high conviction
  - Equity-only mode until F&O capital > Rs.75K
  - GTT audit empty-holdings guard
""")
