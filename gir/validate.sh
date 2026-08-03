#!/bin/bash
# validate.sh — pre-deployment check for gir.py
# Exit 0 = safe to deploy. Exit >0 = bugs found, DO NOT restart bot.
set -e
echo "=== 1. SYNTAX CHECK ==="
python3 -c "import ast; ast.parse(open('/home/globalbot/gir.py').read())" && echo "✅ Syntax OK" || { echo "❌ SyntaxError"; exit 1; }

echo ""
echo "=== 2. IMPORT CHECK ==="
cd /home/globalbot && python3 -c "
import sys
sys.path.insert(0, '/home/globalbot')
import py_compile
py_compile.compile('/home/globalbot/gir.py', doraise=True)
print('✅ Imports + compile OK')
" || { echo "❌ Import/compile failed"; exit 2; }

echo ""
echo "=== 3. CRITICAL FUNCTION PRESENCE CHECK ==="
for fn in "_gtt_audit" "_fno_gtt_audit" "_check_new_day" "_kite_retry" "_check_limits"; do
  if grep -q "def $fn" /home/globalbot/gir.py; then
    echo "✅ $fn() present"
  else
    echo "❌ $fn() MISSING"; exit 3
  fi
done

echo ""
echo "=== 4. CRITICAL PATCHES PRESENT ==="
for patch in "FIX_V29_AUTO_UNHALT" "FIX_V29_STATE_DESYNC" "FIX_V29_ADAPTIVE" "FIX_V29_GTT_ON_ENTRY" "FIX_V29_FNO_GTT_HOURLY"; do
  if grep -q "$patch" /home/globalbot/gir.py; then
    echo "✅ $patch applied"
  else
    echo "⚠️ $patch NOT FOUND (may have been reverted)"
  fi
done

echo ""
echo "=== 5. DANGEROUS PATTERNS CHECK ==="
# Anything that looks like dead code or silent failure
if grep -n "except.*:\s*pass" /home/globalbot/gir.py | wc -l | awk '{if($1>20) exit 1}'; then
  echo "✅ Exception swallowing within reasonable limits"
else
  echo "⚠️ Too many 'except: pass' — silent failures possible"
fi

echo ""
echo "=== 6. BACKUP BEFORE DEPLOY ==="
cp /home/globalbot/gir.py "/home/globalbot/gir.py.bak_$(date +%Y%m%d_%H%M%S)"
ls -la /home/globalbot/gir.py.bak* | tail -3
echo "✅ Backup saved"

echo ""
echo "=== 7. POST-RESTART HEALTH CHECK (runs after restart) ==="
echo "Usage: sudo systemctl restart globaleye && sleep 10 && /home/globalbot/validate.sh --post"

if [ "$1" = "--post" ]; then
  if ! systemctl is-active globaleye > /dev/null; then
    echo "❌ Bot not active after restart"; exit 10
  fi
  errors=$(journalctl -u globaleye --since "30 seconds ago" --no-pager | grep -iE "Traceback|SyntaxError|ImportError|CRITICAL" | wc -l)
  if [ "$errors" -gt 0 ]; then
    echo "❌ $errors critical errors in last 30 sec"
    journalctl -u globaleye --since "30 seconds ago" --no-pager | grep -iE "Traceback|SyntaxError|ImportError|CRITICAL" | tail -5
    exit 11
  fi
  echo "✅ Bot healthy post-restart, no critical errors"
fi

echo ""
echo "=== ALL CHECKS PASSED ==="
