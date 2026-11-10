#!/bin/bash
# PATCH 179 - laptop MARKET: the MY P&L card off the main screen; F&O MOVERS rises into its place, from just under the index boxes
#   (9 MY F&O still keeps your trades). TRADE NOW scrolls inside its own box - it ran over OI SCENARIOS. The alerts already filed under
#   "FILED" (17:09 KALYANKJIL) are put under their share. The page file only - nothing restarts; reload the page.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $F $F.bak$TS
cat > $W/p179_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p179_patch.py - PATCH 179 (laptop, MARKET): the MY P&L card off the main screen; F&O MOVERS grows up into its place, from just under
the NIFTY / SENSEX / BANKNIFTY / VIX boxes down the page. (9 MY F&O keeps your trades.) Usage: python3 p179_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 179: no P&L card on the main screen; F&O MOVERS up under the index boxes (laptop, MARKET) */
body.topchart #pnlcard{display:none !important}
body.topchart #idxleft{height:auto !important;align-self:flex-start}
body.topchart.fkin #q-mov{position:relative;z-index:3}
body.topchart.fkin #mk{overflow:visible !important}body.topchart.fkin #top{border-bottom:0}   /* F&O MOVERS may rise into the header's empty corner */
body.topchart.fkin #q-act{min-height:0 !important;overflow:hidden !important;display:flex;flex-direction:column}
body.topchart.fkin #q-act>h3{flex:none}
body.topchart.fkin #q-act>.bd{flex:1 1 auto;min-height:0;overflow-y:auto !important;max-height:none}   /* TRADE NOW scrolls inside - never over OI SCENARIOS */
</style>"""
JS = """
/* patch 179: F&O MOVERS starts right under the index boxes */
function movUp(){ const m=$("q-mov"), ix=$("idx"); if(!m||!ix) return; m.style.marginTop="";
  if(!(document.body.classList.contains("topchart")&&document.body.classList.contains("fkin"))) return;
  const gap=m.getBoundingClientRect().top-ix.getBoundingClientRect().bottom-8; if(gap>4) m.style.marginTop=(-gap)+"px"; }
{ const tc4_=topChart; topChart=function(){ tc4_(); setTimeout(movUp,60); }; const sv4_=setView; setView=function(v){ sv4_(v); setTimeout(movUp,60); }; }
window.addEventListener("resize",()=>setTimeout(movUp,320)); setInterval(movUp,5000);
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 179" in s:
    print("patch 179 is already in home.html"); sys.exit(0)
if "patch 177" not in s or s.count(A_JS) != 1:
    print("patch 177 is not in home.html - install it first"); sys.exit(1)
s = s.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: F&O MOVERS up under the index boxes, the P&L card off the main screen")
PY_PATCH
R=$(python3 $W/p179_patch.py $D) || { echo "$R - nothing changed"; cp $F.bak$TS $F; exit 1; }; echo "$R"
python3 - <<'PY'
import sqlite3, re
c = sqlite3.connect("/home/globalbot/intraday/tomorrow.db")
n = 0
for rid, text in c.execute("select rowid, text from alerts where sym='FILED'").fetchall():
    m = re.search(r"RESULTS FILED · ([A-Z0-9&-]+)", text or "")
    if m:
        c.execute("update alerts set sym=? where rowid=?", (m.group(1), rid)); n += 1
c.commit(); print("alerts filed under 'FILED' put under their share: %d" % n)
PY
rm -rf $W
echo "PATCH 179 APPLIED - on the laptop press Ctrl + Shift + R on girtrader.com."
