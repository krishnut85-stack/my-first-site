#!/usr/bin/env python3
"""PATCH_V101 v2 - Price-Confirmed Entry + Momentum Floor Relaxation."""
import ast, shutil, sys
from datetime import datetime
from pathlib import Path

GIR = Path("/home/globalbot/gir.py")
TS = datetime.now().strftime("%Y%m%d_%H%M%S")
BACKUP = Path(f"/home/globalbot/gir.py.bak_v101_{TS}")

src = GIR.read_text()
orig_len = len(src)
print(f"[1/8] Read gir.py: {orig_len} chars, {src.count(chr(10))} lines")

shutil.copy2(GIR, BACKUP)
print(f"[2/8] Backup: {BACKUP}")

# CHANGE 1: Relax Trendlyne floor in ALL 3 scanners (52w-low, breakout, intraday-momentum)
OLD1 = '_min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35'
NEW1 = '_min_score = 30 if _mcap > 20000 else (32 if _mcap > 5000 else 35)  # V101: relaxed 35/40/45 -> 30/32/35 to catch TEJASNET/CARTRADE class movers'
c1 = src.count(OLD1)
if c1 != 3:
    print(f"FATAL: CHANGE 1 anchor matched {c1} times (expected 3)")
    sys.exit(2)
src = src.replace(OLD1, NEW1)
print(f"[3/8] CHANGE 1 applied to all 3 scanners (52w-low, breakout, momentum)")

# CHANGE 2: Insert PATCH_V101_PRICE_CONFIRMED block BEFORE V83 guards header
ANCHOR2 = '        # \u2550\u2550\u2550 V83 ENTRY GUARDS (executed in order; first failure returns False) \u2550\u2550\u2550'
if src.count(ANCHOR2) != 1:
    print(f"FATAL: CHANGE 2 anchor matched {src.count(ANCHOR2)} times (expected 1)")
    shutil.copy2(BACKUP, GIR); sys.exit(3)

V101_BLOCK = '''        # PATCH_V101_PRICE_CONFIRMED: if PRICE + VOLUME confirm, news-quality is moot.
        # Bypasses V83_KILL_MACRO_EQ + V83_HOURLY when ALL hold:
        #   intraday move +3% to +12%, vol_ratio>=2x, turnover>=Rs2Cr, score>=60
        # Catches GODREJIND/TEJASNET/CARTRADE class movers; price filter blocks news-only bleed.
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

''' + ANCHOR2

src = src.replace(ANCHOR2, V101_BLOCK, 1)
print(f"[4/8] CHANGE 2 applied (V101 price-confirmed block inserted)")

# CHANGE 3: V83_KILL_MACRO_EQ now respects _v101_bypass
OLD3 = '''        if (source or "").upper() == "V68_MACRO":
            log.info(f"[V83_KILL_MACRO_EQ] BLOCKED {symbol}: V68_MACRO not allowed for equity (use VALIDATED_FILING/BROKERAGE/NEWS)")
            return False'''
NEW3 = '''        if (source or "").upper() == "V68_MACRO" and not _v101_bypass:
            log.info(f"[V83_KILL_MACRO_EQ] BLOCKED {symbol}: V68_MACRO not allowed for equity (use VALIDATED_FILING/BROKERAGE/NEWS or V101 price-confirmed)")
            return False'''
c3 = src.count(OLD3)
if c3 != 1:
    print(f"FATAL: CHANGE 3 anchor matched {c3} times (expected 1)")
    shutil.copy2(BACKUP, GIR); sys.exit(4)
src = src.replace(OLD3, NEW3)
print(f"[5/8] CHANGE 3 applied (V83_KILL_MACRO_EQ respects V101 bypass)")

# CHANGE 4: V83_HOURLY first if-branch becomes elif under _v101_bypass short-circuit
OLD4 = '            # 9:15->555, 10:30->630, 12:30->750, 14:30->870, 15:15->915\n            if 555 <= _hm < 630:'
NEW4 = '            # 9:15->555, 10:30->630, 12:30->750, 14:30->870, 15:15->915\n            # V101: short-circuit V83_HOURLY when price-confirmed bypass active\n            if _v101_bypass:\n                log.info(f"[V83_HOURLY] {symbol}: SKIPPED (V101 price-confirmed bypass)")\n            elif 555 <= _hm < 630:'
c4 = src.count(OLD4)
if c4 != 1:
    print(f"FATAL: CHANGE 4 anchor matched {c4} times (expected 1)")
    shutil.copy2(BACKUP, GIR); sys.exit(5)
src = src.replace(OLD4, NEW4)
print(f"[6/8] CHANGE 4 applied (V83_HOURLY short-circuits on V101 bypass)")

# AST validation
try:
    ast.parse(src)
    print(f"[7/8] AST validation PASSED")
except SyntaxError as e:
    print(f"FATAL: AST FAILED at line {e.lineno}: {e.text}")
    print(f"      Original file untouched (backup intact at {BACKUP})")
    sys.exit(6)

GIR.write_text(src)
new_len = len(src)
print(f"[8/8] Written. {orig_len} -> {new_len} (+{new_len - orig_len})")
print(f"")
print(f"=== PATCH_V101 DEPLOYED ===")
print(f"Backup:   {BACKUP}")
print(f"Rollback: cp {BACKUP} {GIR} && systemctl restart globaleye")
print(f"Activate: systemctl restart globaleye")
print(f"Watch:    journalctl -u globaleye -f | grep -iE 'V101|V83_'")
