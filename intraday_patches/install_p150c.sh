#!/bin/bash
# PATCH 150c - F&O MONEY SHOWS ₹ CRORE; THE CHART ONE PANEL WIDE. Each share in F&O MONEY: ₹ cr of fresh futures money · OI % · price %;
#   F&O MONEY gets the chart's second column, SECTORS moves up beside the chart. home.html only (needs 150b). Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150c; mkdir -p $W
grep -q "patch 150c" $D/home.html && { echo "patch 150c is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p150c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150c_patch.py - PATCH 150c (Rama, 9 Nov 21:40: "I see only the percentage, not the amount · we don't need this long chart"):
F&O MONEY shows each share's ₹ crore of fresh futures money beside OI % and price %, and gets the chart's second column; the
NIFTY / BANKNIFTY chart is one panel wide, SECTORS beside it.   Usage: python3 p150c_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('<b>${esc(x.s)}${c}</b><span class="m ${(x.oi||0)>0?"pu":"pd"}">',
     '<b>${esc(x.s)}${c}</b><span class="cr">₹${Math.abs(Math.round(x.cr||0)).toLocaleString("en-IN")} cr</span><span class="m ${(x.oi||0)>0?"pu":"pd"}">'),
    ('#mk-mon .qr{display:grid;grid-template-columns:minmax(0,1fr) auto auto;',
     '#mk-mon .qr .cr{font:600 12px var(--mono);color:var(--txt);text-align:right;min-width:72px}   /* patch 150c */\n#mk-mon .qr{display:grid;grid-template-columns:minmax(0,1fr) auto auto auto;'),
    ('"ear ear ear ear" "dsk dsk dsk dsk" "act nif nif mov" "act mon don nws" "ins idx rot nws" !important',
     '"ear ear ear ear" "dsk dsk dsk dsk" "act nif don mov" "act mon mon nws" "ins idx rot nws" !important'),
]
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 150c" in s:
    print("patch 150c is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:80])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
python3 $W/p150c_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 150c APPLIED. Reload the GIR page with Ctrl+F5."
