#!/bin/bash
# PATCH 379 - WHO & WHY IS TODAY'S SOON AFTER THE CLOSE, AND SAYS WHEN IT IS NOT (Rama, 17 Nov 13:12 and 16:35: "in the mobile app WHO & WHY is
#   still yesterday's" - it was read only at 19:40 and 22:30, so all day it showed the day before, with nothing saying so).
#   · gir-whydesk.timer: a FIRST reading at 15:50 on market days (today's moves, news, futures money; NSE's delivery file comes about 18:30 -
#     the reading already says "NSE's file of <day>, today's is not out yet"), then 19:40 and 22:30 as before
#   · the page: the panel's header says plainly when the reading is not today's ("⚠ this is 16 Nov's reading - today's first one at 15:50"),
#     and the button shows the reading's day when it is not today ("🧭 WHY · 16 Nov")
#   · run once now (after the close), so today's reading is there tonight
#   Edits the timer and home.html. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); U=/etc/systemd/system
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 379" $D/home.html && grep -q "15:50" $U/gir-whydesk.timer 2>/dev/null; then echo "patch 379 - already in"; exit 0; fi
[ -f $U/gir-whydesk.timer ] && grep -q "patch 356" $D/home.html || { echo "patch 356 (WHO & WHY) not found - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $U/gir-whydesk.timer $D/gir-whydesk.timer.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/gir-whydesk.timer.bak$TS $U/gir-whydesk.timer; systemctl daemon-reload; systemctl restart gir-whydesk.timer gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
grep -q "15:50" $U/gir-whydesk.timer || sed -i 's|^OnCalendar=Mon..Fri \*-\*-\* 19:40:00 Asia/Kolkata|OnCalendar=Mon..Fri *-*-* 15:50:00 Asia/Kolkata\n&|' $U/gir-whydesk.timer
grep -q "15:50" $U/gir-whydesk.timer || back
systemctl daemon-reload && systemctl restart gir-whydesk.timer || back
echo "  gir-whydesk.timer: $(grep -c OnCalendar $U/gir-whydesk.timer) runs a day ($(grep -o '[0-9][0-9]:[0-9][0-9]:00' $U/gir-whydesk.timer | cut -c1-5 | paste -sd' '))"
python3 - $D/home.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
E = (
 ('<small>the day\'s reading and the record · no sound · runs by itself at 19:40 and 22:30 on market days</small>',
  '<small>the day\'s reading and the record · no sound · runs by itself at 15:50 (first read, after the close), 19:40 and 22:30 on market days${v.day&&v.day!==new Date(Date.now()+19800000).toISOString().slice(0,10)?`<br><b style="color:#f0b429">⚠ this is ${E(dm(v.day))}\'s reading - today\'s first one comes at 15:50, after the close</b>`:""}</small>'),)
for a, b in E:
    if t.count(a) != 1:
        print("❌ home.html: the WHO & WHY header found %d times - nothing changed" % t.count(a)); sys.exit(1)
    t = t.replace(a, b)
a2 = 'const t="🧭 WHY"; if(b.textContent!==t) b.textContent=t;'
if t.count(a2) == 1:
    t = t.replace(a2, 'const t="🧭 WHY"+(V&&V.day&&V.day!==new Date(Date.now()+19800000).toISOString().slice(0,10)?" · "+dm(V.day):""); if(b.textContent!==t) b.textContent=t;   /* patch 379: an old reading shows its day */')
    print("  home.html: the WHY button shows an old reading's day")
t = t.replace("</body>", "<!-- patch 379 -->\n</body>", 1) if "<!-- patch 379 -->" not in t else t
open(p, "w", encoding="utf-8").write(t); print("  home.html: WHO & WHY says when it is not today's")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  W=$(mktemp -d); python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
if [ "$H" -ge 1540 ] || [ "$DW" -gt 5 ]; then systemctl start --no-block gir-whydesk.service && echo "  today's reading started now - it takes a few minutes (data/whydesk_run.txt)"; fi
echo "✅ patch 379 done - refresh GIR (Ctrl+Shift+R): WHO & WHY is read at 15:50, 19:40 and 22:30, and says when it is an old day's."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/gir-whydesk.timer.bak$TS $U/gir-whydesk.timer; systemctl daemon-reload; systemctl restart gir-whydesk.timer gir-dash"
