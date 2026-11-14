#!/bin/bash
# PATCH 154 - THE PHONE: F&O MOVERS before TRADE NOW, F&O MONEY boxes one under the other (every name shows), SECTORS' bars in true colour
#   (the page tells the phone browser it is dark already - no recolouring), panels sized for a phone. Laptop unchanged.
#   home.html only. Restarts gir-dash only - safe any time, also in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g154; mkdir -p $W
grep -q "patch 154" $D/home.html && { echo "patch 154 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
cat > $W/p154_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p154_patch.py - PATCH 154: THE PHONE (Rama, 10 Nov 06:41): F&O MOVERS before TRADE NOW, the F&O MONEY boxes one under the other so every
share's name shows, SECTORS' bars in true colour (the phone browser's own dark mode recoloured the page - the page now says it is dark
already), the panels sized for a phone. Laptop untouched.   Usage: python3 p154_patch.py /home/globalbot/intraday  (needs 152)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = '''@media(max-width:1099px){#mk #q-act,#mk #q-ins,#mk #q-rot,#mk #q-dsk{grid-area:auto !important}'''
CSS2 = '''/* patch 154: the phone */
:root{color-scheme:dark}
@media(max-width:1099px){
  #mk #q-ear{order:1}#mk #q-mov{order:2;height:470px !important}#mk #q-act{order:3;height:auto !important;max-height:440px}#mk #q-mon{order:4;height:auto !important}
  #mk #q-don{order:5;height:auto !important;max-height:520px}#mk #q-nif{order:6;height:380px !important}#mk #q-nws{order:7;height:440px !important}#mk #q-rot{order:8;height:auto !important;max-height:480px}
  #mk #q-ins{order:9;height:auto !important;max-height:480px}#mk #q-idx{order:10;height:auto !important;max-height:520px}#mk #q-dsk{order:11;height:auto !important}
  #mk #q-hea,#mk #q-bus{display:none !important}
  #mk-mon .qd{grid-template-columns:minmax(0,1fr) !important}
  #mk-mon .qr{grid-template-columns:minmax(96px,1fr) auto auto auto !important;font-size:13px}#mk-mon .qr .cr{min-width:64px}
  #q-mon .bd,#q-don .bd{overflow:visible}
  #mk-don .sb{grid-template-columns:minmax(0,150px) 1fr 62px;padding:3px 2px}
  #mk-don .fl.u{background:#2FD07F !important;filter:none}#mk-don .fl.d{background:#FF5C61 !important}
}
'''
META = '<link rel="preconnect" href="https://fonts.googleapis.com">'
META2 = '<meta name="color-scheme" content="dark only"><meta name="darkreader-lock">' + META
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 154" in s:
    print("patch 154 is already in home.html"); sys.exit(1)
for a, b in ((CSS, CSS2 + CSS), (META, META2)):
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:70])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s); print("patched: home.html")
PY_PATCH
python3 $W/p154_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back"; exit 1; }
echo "PATCH 154 APPLIED. On the phone: close the GIR tab and open it again (or pull down to refresh)."
