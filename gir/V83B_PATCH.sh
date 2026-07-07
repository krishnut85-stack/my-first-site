#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# V83B_NIFTY_SPOT_KEY — fixes index spot lookup in FnoModule.enter()
#
# Bug:    Lines 8884 + 8891 in gir.py use f"NSE:{symbol}" for index symbols.
#         For NIFTY symbol, this becomes "NSE:NIFTY" which Kite returns 0 for
#         (correct key is "NSE:NIFTY 50"). spot=0 triggers `if spot <= 0: return False`
#         and the index trade dies silently — has been blocking ALL index trades
#         despite F&O Brain emitting NIFTY BULLISH score=80 candidates correctly.
#
# Fix:    Use existing _index_spot_key() helper (already defined at line 170 and
#         already used correctly in the AMO path at line 8116).
#
# Risk:   Zero. _index_spot_key("RELIANCE") returns "NSE:RELIANCE" (unchanged
#         behavior for stocks). Only changes lookup for NIFTY/BANKNIFTY/FINNIFTY.
# ═══════════════════════════════════════════════════════════════════════════════
set -e
cd /home/globalbot

TS=$(date +%Y%m%d_%H%M%S)
cp gir.py "gir.py.bak.V83B_${TS}"
echo "Backup: gir.py.bak.V83B_${TS}"

# Idempotency
if grep -q "V83B_NIFTY_SPOT_KEY" gir.py; then
    echo "ABORT: V83B already applied"
    exit 1
fi

python3 << 'PYPATCH'
import ast, sys
from pathlib import Path

GIR = Path("/home/globalbot/gir.py")
g = GIR.read_text()

# Two replacements — both inside FnoModule.enter() spot-lookup block
OLD_BLOCK = '''        try:
            # Get spot price
            ltp_data = kite.ltp([f"NSE:{symbol}"])
            spot = ltp_data.get(f"NSE:{symbol}", {}).get("last_price", 0)
            if spot <= 0:
                return False

            # V28 C3: Freak spot protection — reject if spot >20% off prev close
            try:
                _q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
                _prev = _q.get("ohlc", {}).get("close", 0)'''

NEW_BLOCK = '''        try:
            # Get spot price
            # V83B_NIFTY_SPOT_KEY: use _index_spot_key() helper so NIFTY/BANKNIFTY/
            # FINNIFTY map to "NSE:NIFTY 50"/"NSE:NIFTY BANK"/"NSE:NIFTY FIN SERVICE".
            # Bug: f"NSE:{symbol}" was returning {} for indices, spot=0, silent return False.
            # Stocks are unaffected — _index_spot_key("RELIANCE") = "NSE:RELIANCE".
            _v83b_spot_key = _index_spot_key(symbol)
            ltp_data = kite.ltp([_v83b_spot_key])
            spot = ltp_data.get(_v83b_spot_key, {}).get("last_price", 0)
            if spot <= 0:
                log.info(f"[V83B_NIFTY_SPOT_KEY] {symbol}: no spot from key={_v83b_spot_key}, return False")
                return False

            # V28 C3: Freak spot protection — reject if spot >20% off prev close
            try:
                _q = kite.quote([_v83b_spot_key]).get(_v83b_spot_key, {})
                _prev = _q.get("ohlc", {}).get("close", 0)'''

assert OLD_BLOCK in g, "FAIL: anchor not found"
assert g.count(OLD_BLOCK) == 1, f"FAIL: anchor count={g.count(OLD_BLOCK)}"
g_new = g.replace(OLD_BLOCK, NEW_BLOCK, 1)

# Verify _index_spot_key is in scope (defined at module level around line 170)
if "def _index_spot_key" not in g_new:
    print("FAIL: _index_spot_key helper missing — cannot apply V83B")
    sys.exit(1)

# AST check
try:
    ast.parse(g_new)
    print("ast.parse: OK")
except SyntaxError as e:
    print(f"FAIL syntax: {e}")
    sys.exit(1)

GIR.write_text(g_new)
print(f"V83B markers in gir.py: {g_new.count('V83B_NIFTY_SPOT_KEY')}")
print("V83B PATCH APPLIED")
PYPATCH

rm -rf /home/globalbot/__pycache__
echo ""
echo "=== Restarting globaleye ==="
systemctl restart globaleye
sleep 4
journalctl -u globaleye -n 15 --no-pager
echo ""
echo "=== Status ==="
systemctl is-active globaleye
echo ""
echo "✓ V83B deployed. Backup: gir.py.bak.V83B_${TS}"
echo ""
echo "Tomorrow watch for: 'V83B_NIFTY_SPOT_KEY' lines or actual NIFTY/BANKNIFTY orders"
echo "Rollback: cp gir.py.bak.V83B_${TS} gir.py && rm -rf __pycache__ && systemctl restart globaleye"
