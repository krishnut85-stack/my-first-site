#!/bin/bash
# PATCH 150d - F&O MOVERS LEFT, TRADE NOW RIGHT; THE ALERT TABS WORK AGAIN. CRITICAL / OI / MOVES & NEWS open their full list (150 hid it);
#   tap the same tab again = folded. home.html only (needs 150c). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150d; mkdir -p $W
grep -q "patch 150d" $D/home.html && { echo "patch 150d is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p150d_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150d_patch.py - PATCH 150d (Rama, 9 Nov 21:46): F&O MOVERS on the left (two rows tall), TRADE NOW on the right; the alert tabs
(ALL · CRITICAL · OI · MOVES & NEWS) open their list again - 150 hid the strip that holds it. The ALL tab's chip row stays folded on a
laptop (TRADE NOW shows it); a lane tab opens its full list; tap the same lane again = folded.
Usage: python3 p150d_patch.py /home/globalbot/intraday  (needs 150c)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('  body.vmk #abar .ac{display:none}', '  body.vmk #abar:not(.lane) .ac{display:none}   /* patch 150d: a lane tab shows its list */'),
    ('"act nif don mov" "act mon mon nws" "ins idx rot nws" !important', '"mov nif don act" "mov mon mon nws" "ins idx rot nws" !important'),
    ('grid-template-columns:280px minmax(0,1fr) minmax(0,1fr) 330px !important', 'grid-template-columns:330px minmax(0,1fr) minmax(0,1fr) 300px !important'),
    ('function aLane(k){ ALANE=k;', 'function aLane(k){ if(ALANE===k&&k!=="all"&&document.body.classList.contains("vmk")) k="all";   /* patch 150d: tap again = fold */\n  ALANE=k;'),
]
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 150d" in s:
    print("patch 150d is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:80])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
python3 $W/p150d_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 150d APPLIED. Reload the GIR page with Ctrl+F5."
