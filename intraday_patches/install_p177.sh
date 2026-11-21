#!/bin/bash
# PATCH 177 - laptop, MARKET page: F&O MOVERS is a tall column on the left; the tab buttons (MARKET · RESULTS · NOW ...) start beside it,
#   above EARLY / the desk / SECTORS. On the other pages the tabs stay on top. The page file only - nothing restarts; reload the page.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $F ] || { echo "home.html not found"; exit 1; }
cp $F $F.bak$TS
cat > $W/p177_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p177_patch.py - PATCH 177 (laptop, MARKET page): F&O MOVERS is a tall column on the left from the top of the page down; the tab
buttons (MARKET · RESULTS · NOW ...) start beside it, above EARLY / the desk / SECTORS. On every other page the tabs stay on top.
Usage: python3 p177_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 177: F&O MOVERS tall on the left, the tabs beside it (laptop, MARKET) */
@media(min-width:1100px){
  body.topchart #mk #fkeys{grid-area:fk;border:1px solid var(--line);border-radius:7px;background:var(--panel);padding:5px 6px;flex-wrap:wrap;overflow:visible}
  body.topchart.fkin #mk{grid-template-rows:auto auto auto minmax(0,1.1fr) minmax(0,1fr) minmax(0,1fr) !important;
    grid-template-areas:"mov fk fk fk" "mov ear ear ear" "mov dsk dsk dsk" "mov don don act" "mov mon mon nws" "ins idx rot nws" !important}
}
</style>"""
JS = """
/* patch 177: on MARKET (laptop) the tabs sit beside a tall F&O MOVERS; elsewhere they stay on top */
function fkPlace(){ const fk=$("fkeys"), mk=$("mk"), top=$("top"); if(!fk||!mk||!top) return;
  const inside=document.body.classList.contains("topchart")&&typeof VIEW!=="undefined"&&VIEW==="market";
  if(inside&&fk.parentNode!==mk){ mk.insertBefore(fk,mk.firstChild); document.body.classList.add("fkin"); }
  else if(!inside&&fk.parentNode===mk){ top.appendChild(fk); document.body.classList.remove("fkin"); } }
{ const tc3_=topChart; topChart=function(){ tc3_(); fkPlace(); }; const sv3_=setView; setView=function(v){ sv3_(v); fkPlace(); }; }
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 177" in s:
    print("patch 177 is already in home.html"); sys.exit(0)
if "patch 172" not in s or s.count(A_JS) != 1:
    print("patch 172 is not in home.html - install it first"); sys.exit(1)
s = s.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: F&O MOVERS tall on the left, the tabs beside it")
PY_PATCH
R=$(python3 $W/p177_patch.py $D) || { echo "$R - nothing changed"; cp $F.bak$TS $F; exit 1; }
echo "$R"; rm -rf $W
echo "PATCH 177 APPLIED - on the laptop press Ctrl + Shift + R on girtrader.com."
