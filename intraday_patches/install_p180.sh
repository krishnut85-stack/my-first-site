#!/bin/bash
# PATCH 180 - laptop: the top row on the same columns as the MARKET panels - GIR + NIFTY / SENSEX / BANKNIFTY / VIX as wide as
#   F&O MOVERS; the index chart from the MARKET tab to TRADE NOW; the ticker + alerts as wide as TRADE NOW. Page file only; reload.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $F $F.bak$TS
cat > $W/p180_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p180_patch.py - PATCH 180 (laptop): the top row lines up with the panels under it - GIR + the index boxes as wide as F&O MOVERS,
the index chart from the MARKET tab to TRADE NOW, the ticker + alerts as wide as TRADE NOW. Usage: python3 p180_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 180: the top row on the same columns as the MARKET panels (laptop) */
@media(min-width:1100px){
  body.topchart #idxleft{flex:0 0 330px !important;width:330px}
  body.topchart #idxleft #idx,body.topchart #idx{width:auto !important}
  body.topchart #idx .ix{padding:6px 10px}
  body.topchart #idxside{flex:0 0 300px !important;width:300px}
  body.topchart #idxside #cmd select{max-width:104px;font-size:10px;padding-left:4px;padding-right:2px}body.topchart #idxside #cmd input{font-size:12px}
}
</style>"""
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 180" in s:
    print("patch 180 is already in home.html"); sys.exit(0)
if "patch 179" not in s:
    print("patch 179 is not in home.html - install it first"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace("</style>", CSS, 1))
print("home.html: the top row lines up with the panels")
PY_PATCH
R=$(python3 $W/p180_patch.py $D) || { echo "$R - nothing changed"; cp $F.bak$TS $F; exit 1; }; echo "$R"; rm -rf $W
echo "PATCH 180 APPLIED - on the laptop press Ctrl + Shift + R on girtrader.com."
