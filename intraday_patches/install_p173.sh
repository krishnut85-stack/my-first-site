#!/bin/bash
# PATCH 173 - laptop: the TICKER search and the ALERTS strip in a column right of the index chart; the tab buttons stay in their row;
#   every market panel moves up. The phone layout is unchanged. The page file only - nothing restarts; reload the page.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $F ] || { echo "home.html not found"; exit 1; }
cp $F $F.bak$TS
cat > $W/p173_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p173_patch.py - PATCH 173 (laptop): the TICKER search and the ALERTS strip move into a column right of the index chart; the tab
buttons (MARKET · RESULTS · NOW ...) stay in their row; every market panel moves up. Phone unchanged. Usage: python3 p173_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 173: ticker search + alerts beside the index chart (laptop) */
body.topchart #idx{align-content:start}
body.topchart #idxside{flex:0 0 440px;min-width:0;height:310px;display:flex;flex-direction:column;gap:6px}
body.topchart #idxside #cmd{flex:none;display:flex;gap:4px;align-items:center;border:1px solid var(--line);border-radius:7px;background:var(--panel);padding:4px 6px}
body.topchart #idxside #cmd input{flex:1;min-width:0}body.topchart #idxside #cmd select{max-width:130px}
body.topchart #idxside #abar{flex:1;min-height:0;display:flex;flex-wrap:wrap;align-content:flex-start;overflow-y:auto;border:1px solid var(--line);border-radius:7px}
body.topchart #idxside #abar .al{flex:1 1 100%;padding:5px 9px;min-height:24px}
body.topchart #idxside #abar .alt{flex:1 1 100%;border-right:0;flex-wrap:wrap;gap:3px;padding:4px}
body.topchart #idxside #abar .ac{flex:1 1 100%;flex-direction:column;flex-wrap:nowrap;align-items:stretch;overflow-x:hidden;overflow-y:auto;max-height:none}
body.topchart #idxside #abar .ch{max-width:none;flex:0 0 auto}
body.topchart #idxside #abar .ar{flex:1 1 100%;border-left:0;flex-wrap:wrap;gap:3px;padding:4px}
</style>"""
JS = """
/* patch 173: the ticker search and the alerts in a column beside the chart (laptop) */
function sideCol(){ const wide=document.body.classList.contains("topchart"), row=$("idxrow"), cmd=$("cmd"), ab=$("abar"), fk=$("fkeys"), top=$("top"); if(!row||!cmd||!ab||!fk||!top) return;
  let side=$("idxside"); if(!side){ side=document.createElement("div"); side.id="idxside"; }
  if(wide){ if(side.parentNode!==row) row.appendChild(side); if(cmd.parentNode!==side){ side.appendChild(cmd); side.appendChild(ab); } }
  else if(cmd.parentNode===side){ top.insertBefore(cmd,fk); fk.after(ab); side.remove(); } }
{ const tc1_=topChart; topChart=function(){ tc1_(); sideCol(); }; }
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 173" in s:
    print("patch 173 is already in home.html"); sys.exit(0)
if "patch 172" not in s or s.count(A_JS) != 1:
    print("patch 172 is not in home.html - install it first"); sys.exit(1)
s = s.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: the ticker search and the alerts beside the chart")
PY_PATCH
R=$(python3 $W/p173_patch.py $D) || { echo "$R - nothing changed"; cp $F.bak$TS $F; exit 1; }
echo "$R"; rm -rf $W
echo "PATCH 173 APPLIED - on the laptop press Ctrl + Shift + R on girtrader.com."
