#!/usr/bin/env python3
"""PATCH_V101 - Price-Confirmed Entry + Momentum Floor Relaxation."""
import ast, shutil, sys
from datetime import datetime
from pathlib import Path

GIR = Path("/home/globalbot/gir.py")
TS = datetime.now().strftime("%Y%m%d_%H%M%S")
BACKUP = Path(f"/home/globalbot/gir.py.bak_v101_{TS}")

src = GIR.read_text()
orig_len = len(src)
print(f"[1/7] Read gir.py: {orig_len} chars, {src.count(chr(10))} lines")

# Backup first
shutil.copy2(GIR, BACKUP)
print(f"[2/7] Backup: {BACKUP}")

# ===== CHANGE 1: momentum scanner Trendlyne floor =====
OLD1 = '_min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35'
NEW1 = '_min_score = 30 if _mcap > 20000 else (32 if _mcap > 5000 else 35)  # V101: relaxed 35/40/45 -> 30/32/35 to catch TEJASNET/CARTRADE mid-caps'
c1 = src.count(OLD1)
if c1 != 1:
    print(f"FATAL: CHANGE 1 anchor matched {c1} times (expected 1)")
    sys.exit(2)
src = src.replace(OLD1, NEW1)
print(f"[3/7] CHANGE 1 applied (momentum floor 35/40/45 -> 30/32/35)")

# ===== CHANGE 2: insert PATCH_V101_PRICE_CONFIRMED bypass before V83_KILL_MACRO_EQ =====
ANCHOR2 = '''        # === V83 ENTRY GUARDS (executed in order; first failure returns False) ===
        # V83_KILL_MACRO_EQ: V68_MACRO is structurally low-quality for equity entries.'''

# Anchor uses the actual unicode boxchars in the source. Detect them.
ANCHOR2_REAL = '''        # \u2550\u2550\u2550 V83 ENTRY GUARDS (executed in order; first failure returns False) \u2550\u2550\u2550
        # V83_KILL_MACRO_EQ: V68_MACRO is structurally low-quality for equity entries.'''

if ANCHOR2_REAL in src:
    anchor = ANCHOR2_REAL
elif ANCHOR2 in src:
    anchor = ANCHOR2
else:
    # Fallback: find by V83_KILL_MACRO_EQ comment alone
    fallback = '        # V83_KILL_MACRO_EQ: V68_MACRO is structurally low-quality for equity entries.'
    if src.count(fallback) != 1:
        print(f"FATAL: CHANGE 2 anchor not found (tried 3 patterns)")
        sys.exit(3)
    anchor = fallback

INSERT_BLOCK = '''        # PATCH_V101_PRICE_CONFIRMED: if PRICE + VOLUME are confirming, the news-quality
        # debate is moot - the market has decided. Follow the tape. Bypasses V83_KILL_MACRO_EQ
        # and V83_HOURLY only when ALL conditions hold:
        #   - intraday move between +3% and +12% (in zone, not chasing top)
        #   - vol_ratio >= 2.0x average (real participation)
        #   - turnover >= Rs 2 Cr (liquidity floor)
        #   - score >= 60 (panel/scout still confirms)
        # Designed to catch GODREJIND/TEJASNET/CARTRADE class movers without re-opening
        # the V68_MACRO same-day SL bleed (which was news-only, no price confirmation).
        _v101_bypass = False
        try:
            if direction == "BULLISH" and score >= 60:
                _v101_kite = KiteSession.kite()
                if _v101_kite:
                    _v101_q = _v101_kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
                    _v101_ltp = _v101_q.get("last_price", 0) or 0
                    _v101_pclose = (_v101_q.get("ohlc", {}) or {}).get("close", 0) or 0
                    if _v101_ltp > 0 and _v101_pclose > 0:
                        _v101_pct = (_v101_ltp - _v101_pclose) / _v101_pclose * 100.0
                        if 3.0 <= _v101_pct <= 12.0:
                            _v101_vr = float((cand or {}).get("vol_ratio", 0) or 0)
                            _v101_to = float((cand or {}).get("turnover", 0) or 0)
                            if _v101_vr >= 2.0 and _v101_to >= 20000000:
                                log.info(f"[PATCH_V101_PRICE_CONFIRMED] {symbol}: BYPASS V83 (pct={_v101_pct:+.2f}% vol_ratio={_v101_vr:.1f}x turnover=Rs.{_v101_to/10000000:.2f}Cr score={score} src={source})")
                                _v101_bypass = True
        except Exception as _v101e:
            log.warning(f"[PATCH_V101_PRICE_CONFIRMED] check failed for {symbol}: {_v101e}, falling through to V83")

''' + anchor

src = src.replace(anchor, INSERT_BLOCK, 1)
print(f"[4/7] CHANGE 2 applied (V101 price-confirmed bypass inserted)")

# ===== CHANGE 3: gate V83_KILL_MACRO_EQ behind _v101_bypass =====
OLD3 = '''        if (source or "").upper() == "V68_MACRO":
            log.info(f"[V83_KILL_MACRO_EQ] BLOCKED {symbol}: V68_MACRO not allowed for equity (use VALIDATED_FILING/BROKERAGE/NEWS)")
            return False'''
NEW3 = '''        if (source or "").upper() == "V68_MACRO" and not _v101_bypass:
            log.info(f"[V83_KILL_MACRO_EQ] BLOCKED {symbol}: V68_MACRO not allowed for equity (use VALIDATED_FILING/BROKERAGE/NEWS or V101 price-confirmed)")
            return False'''
c3 = src.count(OLD3)
if c3 != 1:
    print(f"FATAL: CHANGE 3 anchor matched {c3} times (expected 1)")
    shutil.copy2(BACKUP, GIR)
    sys.exit(4)
src = src.replace(OLD3, NEW3)
print(f"[5/7] CHANGE 3 applied (V83_KILL_MACRO_EQ now respects V101 bypass)")

# ===== CHANGE 4: gate V83_HOURLY behind _v101_bypass =====
OLD4 = '''        # V83_HOURLY: tiered filter by IST entry hour. Morning entries face stricter
        # thresholds — the 13:00 cluster produced the only profitable equity trades.
        try:
            _now = now_ist()'''
NEW4 = '''        # V83_HOURLY: tiered filter by IST entry hour. Morning entries face stricter
        # thresholds — the 13:00 cluster produced the only profitable equity trades.
        # V101: bypass entirely if price-confirmed (already validated by tape).
        if _v101_bypass:
            log.info(f"[V83_HOURLY] {symbol}: SKIPPED (V101 price-confirmed bypass active)")
        try:
            if _v101_bypass:
                raise StopIteration("V101_BYPASS")
            _now = now_ist()'''
c4 = src.count(OLD4)
if c4 != 1:
    print(f"FATAL: CHANGE 4 anchor matched {c4} times (expected 1)")
    shutil.copy2(BACKUP, GIR)
    sys.exit(5)
src = src.replace(OLD4, NEW4)

# Also need to handle the StopIteration cleanly - patch the except clause too
OLD4B = '''        except Exception as _v83he:
            log.warning(f"[V83_HOURLY] check failed for {symbol}: {_v83he}, allowing")
        # === END V83 GUARDS ==='''
OLD4B_REAL = '''        except Exception as _v83he:
            log.warning(f"[V83_HOURLY] check failed for {symbol}: {_v83he}, allowing")
        # \u2550\u2550\u2550 END V83 GUARDS \u2550\u2550\u2550'''
NEW4B = '''        except StopIteration:
            pass  # V101 bypass intentional
        except Exception as _v83he:
            log.warning(f"[V83_HOURLY] check failed for {symbol}: {_v83he}, allowing")'''

if OLD4B_REAL in src:
    src = src.replace(OLD4B_REAL, NEW4B + '\n        # \u2550\u2550\u2550 END V83 GUARDS \u2550\u2550\u2550', 1)
elif OLD4B in src:
    src = src.replace(OLD4B, NEW4B + '\n        # === END V83 GUARDS ===', 1)
else:
    print(f"FATAL: CHANGE 4B anchor not found")
    shutil.copy2(BACKUP, GIR)
    sys.exit(6)
print(f"[6/7] CHANGE 4 applied (V83_HOURLY respects V101 bypass)")

# ===== AST validation in memory =====
try:
    ast.parse(src)
    print(f"[7/7] AST validation PASSED")
except SyntaxError as e:
    print(f"FATAL: AST validation FAILED: {e}")
    print(f"      Line {e.lineno}: {e.text}")
    print(f"      Original file untouched (backup intact)")
    sys.exit(7)

# Write
GIR.write_text(src)
new_len = len(src)
print(f"")
print(f"=== PATCH_V101 DEPLOYED ===")
print(f"  Backup:     {BACKUP}")
print(f"  Old size:   {orig_len} chars")
print(f"  New size:   {new_len} chars (+{new_len - orig_len})")
print(f"")
print(f"Rollback (if needed):")
print(f"  cp {BACKUP} {GIR} && systemctl restart globaleye")
print(f"")
print(f"Activate now:")
print(f"  systemctl restart globaleye")
print(f"  journalctl -u globaleye -f | grep -iE 'V101|V83_'")
