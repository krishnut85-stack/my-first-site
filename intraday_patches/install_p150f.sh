#!/bin/bash
# PATCH 150f - F&O MONEY's columns named: FUT ₹ CR · OI % · PRICE %. home.html only (needs 150c). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150f; mkdir -p $W
grep -q "patch 150f" $D/home.html && { echo "patch 150f is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
cat > $W/p150f_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150f_patch.py - PATCH 150f: F&O MONEY's columns named - FUTURES ₹ CR · OI % (positions vs yesterday) · PRICE % (the share today).
Usage: python3 p150f_patch.py /home/globalbot/intraday  (needs 150c)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
A = '<small>${bias}</small></h5>${xs.length?'
B = '<small>${bias}</small></h5><div class="qr qh" title="FUTURES ₹ CR = new money put into its futures today · OI % = open futures positions vs yesterday · PRICE % = the share price today"><b>SHARE</b><span>FUT ₹ CR</span><span>OI %</span><span>PRICE %</span></div>${xs.length?'
C = '#mk-mon .qr .cr{'
C2 = '#mk-mon .qh{cursor:help;color:var(--dim);font:600 9.5px/1 var(--ui) !important;letter-spacing:.08em;border-bottom:1px solid var(--line);padding-bottom:3px !important;margin-bottom:2px}#mk-mon .qh span{text-align:right}#mk-mon .qh b{font-weight:600}   /* patch 150f */\n#mk-mon .qr .cr{'
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 150f" in s:
    print("patch 150f is already in home.html"); sys.exit(1)
for a, b in ((A, B), (C, C2)):
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:60])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s); print("patched: home.html")
PY_PATCH
python3 $W/p150f_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back"; exit 1; }
echo "PATCH 150f APPLIED. Reload the GIR page with Ctrl+F5."
