#!/bin/bash
# PATCH 156 - SAMSUNG INTERNET KEEPS GIR'S COLOURS (its own dark mode recoloured the page). home.html only. Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g156; mkdir -p $W
grep -q "patch 156" $D/home.html && { echo "patch 156 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
cat > $W/p156_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p156_patch.py - PATCH 156: SAMSUNG INTERNET KEEPS GIR'S COLOURS. Its own dark mode recoloured the page (the amber GIR box brown, the sector bars
dull); it leaves a page alone only when the page carries its own dark-mode style (prefers-color-scheme: dark) - added, with GIR's colours.
Usage: python3 p156_patch.py /home/globalbot/intraday  (needs 155)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
A = '#focus table.oi{width:100%;'
B = '''/* patch 156: the page's own dark-mode style - Samsung Internet then keeps GIR's colours */
@media (prefers-color-scheme: dark){:root{color-scheme:dark;--bg:#0A0F1A;--panel:#0F1626;--panel2:#141D31;--line:#1F2B44;--line2:#2A3956;--dim:#7D8BA5;--txt:#D9E0EC;--hi:#F4F7FB;
  --amber:#F2A93B;--amber2:#F7C46C;--up:#2FD07F;--dn:#FF5C61;--ce:#2FD07F;--pe:#FF5C61}body{background:#0A0F1A;color:#D9E0EC}}
@media (prefers-color-scheme: light){:root{color-scheme:dark}body{background:#0A0F1A;color:#D9E0EC}}
#focus table.oi{width:100%;'''
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 156" in s:
    print("patch 156 is already in home.html"); sys.exit(1)
if s.count(A) != 1:
    print("ANCHOR"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(A, B)); print("patched: home.html")
PY_PATCH
python3 $W/p156_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back"; exit 1; }
echo "PATCH 156 APPLIED. On the phone: close the GIR tab and open it again."
