#!/bin/bash
BOT_DIR="/home/globalbot"
SERVICE="globaleye"
echo "=== PROCESS CHECK ==="
ps aux | grep python | grep -v grep | grep -v unattended
echo ""
echo "=== BOT COUNT ==="
BOT_COUNT=$(ps aux | grep "global_eye" | grep python | grep -v grep | wc -l)
echo "Bot processes: $BOT_COUNT"
if [ "$BOT_COUNT" -gt 1 ]; then echo "❌ DUPLICATE BOTS RUNNING!"; elif [ "$BOT_COUNT" -eq 0 ]; then echo "❌ NO BOT RUNNING!"; else echo "✅ Single bot — OK"; fi
echo ""
echo "=== SYSTEMD ==="
systemctl is-active $SERVICE
echo ""
echo "=== BOT FILES ==="
ls -lah $BOT_DIR/global_eye*.py 2>/dev/null
echo ""
echo "=== VERSION ==="
grep -m1 'VERSION' $BOT_DIR/global_eye_v23_pythonanywhere.py | head -1
echo ""
echo "=== EXTRA FILES (should be NONE) ==="
find $BOT_DIR -maxdepth 1 -name "global_eye*.py" ! -name "global_eye_v23_pythonanywhere.py" 2>/dev/null || echo "✅ No extra files"
echo ""
echo "=== MEMORY ==="
free -m | head -2
