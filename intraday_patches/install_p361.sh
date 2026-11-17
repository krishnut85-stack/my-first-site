#!/bin/bash
# PATCH 361 - 🧪 STRONG3: THE MARK THAT PASSED THE 10:00 STUDY GOES INTO THE PAPER TEST (Rama, 17 Nov: "around 09:45 to 10:00 we know which sector
#   settled. From there we need the list of shares which can outperform"). pickstudy.py, 58 days of 5-minute prices, the F&O shares of the 3
#   strongest sectors that are up: the pool as a whole LOSES a little to 15:10 (-0.08%, 42% up). What separated the ones that went on:
#     above VWAP + past yesterday's high + volume 1.5x its normal   to 15:10 +0.31%, 58% up, +0.39% over the pool (+0.28% at 09:45), both halves
#     past its 20-day high (+0.34%) = the BREAK candidate already running · volume 2x (+0.25%)
#   and what to AVOID: a move that was only the opening gap (-0.23%), the market going against (-0.29%), a sector foreign funds were buying in
#   the last report (-0.18%). No PE mark passed.
#   And gapstudy.py (2 years): news is in the opening price - trading its direction from the open has no edge. One exception: on a day the WHOLE
#   MARKET opens 0.7%+ down, the shares that opened 3%+ down rose 2.69% from the open, 87% of 568 cases, on 24 days. A share gapping down alone
#   did not bounce. So:
#   · seccand.py: G = GAPDAY at 09:20, only when NIFTY opened 0.7%+ down - CE on the F&O shares that opened 3%+ down, scored to 15:10.
#   · seccand.py: a new candidate T = STRONG3 at 09:45 and 10:00 (CE only), scored each evening in the real option with the 2-hour rule.
#     Each morning it also reads yesterday's high and the share's normal volume by 09:45 / 10:00 (about a minute more at 09:18).
#   · the page: STRONG3 rows and its own record line in the 🧪 CANDIDATES box; the note on a share names it too
#   A paper test: no sound, no BUY card. Replaces seccand.py, edits the 355 block in home.html. Restarts the sector reader and the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "find_gapday" $D/seccand.py && grep -q 'G:"GAPDAY"' $D/home.html; then echo "patch 361 - already in"; exit 0; fi
grep -q "355b" $D/seccand.py && grep -q 'E:"BOUNCE"})' $D/home.html && systemctl is-active --quiet gir-seclive || { echo "patch 355b / the CANDIDATES box / gir-seclive not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/seccand.py > $W/seccand.py 2>/dev/null && grep -q "find_gapday" $W/seccand.py && python3 -m py_compile $W/seccand.py || { echo "❌ seccand.py (patch 361) not in $B - run the git fetch line first; nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/seccand.py $D/seccand.py.bak361
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak361 $D/seccand.py; systemctl restart gir-seclive gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/seccand.py $D/seccand.py || back
python3 - $D/home.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
E = (('({A:"WEAK",B:"BREAK",E:"BOUNCE"})', '({A:"WEAK",B:"BREAK",E:"BOUNCE",T:"STRONG3",G:"GAPDAY"})', (1, 2)),
     ('const R=Object.assign({A:[0,0,0,0,0],B:[0,0,0,0,0],E:[0,0,0,0,0]},(V&&V.record)||{});', 'const R=Object.assign({A:[0,0,0,0,0],B:[0,0,0,0,0],E:[0,0,0,0,0],T:[0,0,0,0,0],G:[0,0,0,0,0]},(V&&V.record)||{});', (1,)),
     ('BREAK (past its 20-day level with its sector, 2-hour rule): ${rec("B")}', 'STRONG3 (above VWAP + past yesterday\'s high + volume 1.5x, in a top-3 sector - CE at 09:45 / 10:00, 2-hour rule): ${rec("T")}<br>GAPDAY (only when NIFTY opens 0.7%+ down: CE at 09:20 on shares that opened 3%+ down, to 15:10): ${rec("G")}<br>BREAK (past its 20-day level with its sector, 2-hour rule): ${rec("B")}', (1,)))
for a, b, n in E:
    if t.count(a) not in n:
        print("❌ home.html: %r found %d times" % (a[:50], t.count(a))); sys.exit(1)
    t = t.replace(a, b)
open(p, "w", encoding="utf-8").write(t); print("  home.html: STRONG3 in the 🧪 CANDIDATES box and in the note")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && python3 -c "import seccand; print('  seccand: checks', ', '.join(t + ' ' + k for t, k in seccand.TRIG), '· record', seccand.view()['record'])" || back
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-seclive: $(systemctl is-active gir-seclive)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-seclive)" = "active" ] || back
echo "✅ patch 361 done - refresh GIR (Ctrl+Shift+R). From tomorrow: STRONG3 at 09:45 and 10:00, GAPDAY at 09:20 on market gap-down days, next to BOUNCE, BREAK and WEAK - a paper test, no sound."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak361 $D/seccand.py; systemctl restart gir-seclive gir-dash"
