#!/bin/bash
# PATCH 146d - OI SCENARIOS · NEWS GETS ROOM, THE ORDER BOOK LEAVES THE MARKET PAGE. A laptop: the bottom row is 🔄 ROTATION and
#   OI SCENARIOS · NEWS side by side, both full height; F&O DESK runs down two rows; the order book stays only on each share's
#   trading screen. home.html only (needs 145c). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g146d; mkdir -p $W
grep -q "patch 146d" $D/home.html && { echo "patch 146d is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p146d_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p146d_patch.py - PATCH 146d: OI SCENARIOS · NEWS GETS ROOM, THE ORDER BOOK LEAVES THE MARKET PAGE (Rama, 9 Nov 20:35: "what is the
use of the order book section? and the OI scenarios updating live is a very small window"). A laptop: F&O DESK runs down two rows,
the bottom row is 🔄 ROTATION (3 parts) and OI SCENARIOS · NEWS (2 parts, as tall as the others). The order book's totals include
orders far from the price and were never measured as a signal - it stays only on each share's trading screen.
Usage: python3 p146d_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''  #mk{grid-template-rows:auto 56vh 56vh auto !important;grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus idx nws" "rot rot rot rot rot" !important}   /* patch 145c */''',
     '''  #mk{grid-template-rows:auto 56vh 56vh 62vh !important;grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus idx dsk" "rot rot rot nws nws" !important}   /* patch 145c · 146d: NEWS wide, DESK tall */'''),
    ('''      <div><em>ORDER BOOK</em>${(()=>{''', '''      <div style="display:none"><em>ORDER BOOK</em>${(()=>{   /* patch 146d: off the market page - each share's screen keeps it */'''),
]
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 146d" in s:
    print("patch 146d is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:90])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
python3 $W/p146d_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 146d APPLIED. Reload the GIR page (Ctrl+F5) and scroll down: OI SCENARIOS · NEWS beside ROTATION, full height."
