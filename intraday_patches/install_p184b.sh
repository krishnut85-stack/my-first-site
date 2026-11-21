#!/bin/bash
# PATCH 184b - MARKET's layout fix: the new BIG MONEY · LINKED panel was laid out on MARKET too (outside the grid - the browser added
#   columns and squeezed everything). Now it lives only on the B BIG MONEY tab; the 13 tabs are compact. Page file only - no restart.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $F $F.bak$TS
cat > $W/p184b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p184b_patch.py - PATCH 184b: the MARKET page's grid broke - the new BIG MONEY · LINKED panel was laid out on MARKET too (outside the
grid, so the browser added columns and squeezed everything). It now exists only on the BIG MONEY tab. + the 13 tabs all visible.
Usage: python3 p184b_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 184b: BIG MONEY · LINKED only on its tab; the tab row compact */
#mk #q-lnk{display:none !important;grid-area:auto}
body.topchart.mk-big #mk>#q-lnk{display:flex !important;grid-area:lnk}
@media(min-width:1100px){body.topchart.fkin #mk #fkeys{flex-wrap:wrap;overflow:visible;gap:3px;padding:4px}
  body.topchart.fkin #mk #fkeys a{padding:3px 5px;font-size:10px;letter-spacing:.02em}body.topchart.fkin #mk #fkeys a b{margin-right:2px}}
</style>"""
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 184b" in s:
    print("patch 184b is already in home.html"); sys.exit(0)
if "patch 184" not in s:
    print("patch 184 is not in home.html"); sys.exit(1)
s = s.replace("</style>", CSS, 1)
s = s.replace('"B","🏦 BIG MONEY"', '"B","BIG MONEY"').replace('"G","📘 GUIDE"', '"G","GUIDE"')
open(p, "w", encoding="utf-8").write(s)
print("home.html: MARKET's grid fixed, the tab row in one line")
PY_PATCH
R=$(python3 $W/p184b_patch.py $D) || { echo "$R - nothing changed"; cp $F.bak$TS $F; exit 1; }; echo "$R"; rm -rf $W
echo "PATCH 184b APPLIED - Ctrl + Shift + R on girtrader.com."
