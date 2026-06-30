#!/bin/bash
BOT_DIR="/home/globalbot"
LIVE_FILE="$BOT_DIR/global_eye_v23_pythonanywhere.py"
SERVICE="globaleye"
ENV_FILE="$BOT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
TELEGRAM_TOKEN=$(grep "^TELEGRAM_TOKEN=" "$ENV_FILE" | cut -d= -f2-)
TELEGRAM_CHAT_ID=$(grep "^TELEGRAM_CHAT_ID=" "$ENV_FILE" | cut -d= -f2-)
fi
PASS=0; FAIL=0; WARN=0; REPORT=""
TS=$(date '+%Y-%m-%d %H:%M:%S IST')
ap() { PASS=$((PASS+1)); REPORT="$REPORT\n✅ $1"; echo "✅ $1"; }
af() { FAIL=$((FAIL+1)); REPORT="$REPORT\n❌ $1"; echo "❌ $1"; }
aw() { WARN=$((WARN+1)); REPORT="$REPORT\n⚠️ $1"; echo "⚠️ $1"; }
stg() {
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=$1" -d "parse_mode=Markdown" > /dev/null 2>&1
fi
}
echo ""; echo "══ PRE-MARKET CHECKLIST ══"; echo "$TS"; echo ""
echo "── 1. PROCESSES ──"
BC=$(ps aux|grep "global_eye"|grep python|grep -v grep|wc -l)
SP=$(systemctl show -p MainPID $SERVICE 2>/dev/null|cut -d= -f2)
if [ "$BC" -eq 1 ]; then ap "Single bot process (PID $SP)"
elif [ "$BC" -eq 0 ]; then af "NO bot running!"
else af "DUPLICATE: $BC bots running!"; for p in $(ps aux|grep "global_eye"|grep python|grep -v grep|awk '{print $2}'); do [ "$p" != "$SP" ] && kill $p 2>/dev/null && aw "Killed zombie $p"; done
fi
echo ""
echo "── 2. FILE INTEGRITY ──"
if [ -f "$LIVE_FILE" ]; then
VER=$(grep -m1 'VERSION' "$LIVE_FILE"|grep -oP '"v[^"]+' |head -1)
LN=$(wc -l < "$LIVE_FILE")
ap "Live file: $VER | $LN lines"
else af "Live file MISSING!"; fi
python3 -c "import py_compile; py_compile.compile('$LIVE_FILE', doraise=True)" 2>/dev/null && ap "Syntax OK" || af "SYNTAX ERROR!"
if grep -Pq '\x00' "$LIVE_FILE" 2>/dev/null; then af "Null bytes!"; sed -i 's/\x0//g' "$LIVE_FILE"; aw "Auto-cleaned"; else ap "No null bytes"; fi
EX=$(find $BOT_DIR -maxdepth 1 -name "global_eye*.py" ! -name "global_eye_v23_pythonanywhere.py" 2>/dev/null)
if [ -n "$EX" ]; then aw "Extra bot files found (zombie risk)"; else ap "No extra files"; fi
echo ""
echo "── 3. ENVIRONMENT ──"
[ -f "$ENV_FILE" ] && ap ".env exists" || af ".env MISSING!"
AV=true; for v in KITE_API_KEY KITE_API_SECRET KITE_TOTP_SECRET TELEGRAM_TOKEN TELEGRAM_CHAT_ID GEMINI_API_KEY; do
grep -q "^${v}=" "$ENV_FILE" 2>/dev/null || { af "$v MISSING"; AV=false; }; done
[ "$AV" = true ] && ap "All 6 env vars set"
DP=$(df / |awk 'NR==2{print $5}'|tr -d '%')
[ "$DP" -gt 90 ] && af "Disk ${DP}%!" || ap "Disk ${DP}%"
MP=$(free|awk '/Mem/{printf "%d",$3/$2*100}')
[ "$MP" -gt 90 ] && af "RAM ${MP}%!" || ap "RAM ${MP}%"
echo ""
echo "── 4. SYSTEMD ──"
SS=$(systemctl is-active $SERVICE 2>/dev/null)
if [ "$SS" = "active" ]; then ap "Service active"; else af "Service $SS"; sudo systemctl start $SERVICE 2>/dev/null; sleep 3; NS=$(systemctl is-active $SERVICE); [ "$NS" = "active" ] && aw "Auto-started" || af "Start FAILED!"; fi
echo ""
echo "══════════════════════════════"
if [ "$FAIL" -eq 0 ]; then ST="🟢 GO"; STT="READY FOR MARKET"; else ST="🔴 STOP"; STT="$FAIL ISSUES — FIX NOW"; fi
echo "$ST — $STT"; echo "✅$PASS | ⚠️$WARN | ❌$FAIL"
echo "══════════════════════════════"
FV=$(grep -m1 'VERSION' "$LIVE_FILE" 2>/dev/null|grep -oP '"v[^"]+' |head -1)
FP=$(systemctl show -p MainPID $SERVICE 2>/dev/null|cut -d= -f2)
TM="🔍 *PRE-MARKET CHECKLIST*
━━━━━━━━━━━━━━━━━━━━━━━
$ST *$STT*
✅ $PASS | ⚠️ $WARN | ❌ $FAIL
📋 Bot: $FV | PID: $FP
💾 Disk: ${DP}% | RAM: ${MP}%
🕐 $TS"
stg "$TM"
echo "Telegram sent."
