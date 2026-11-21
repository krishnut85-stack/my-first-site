#!/bin/bash
# PATCH 178 - laptop MARKET: TRADE NOW is a tall column on the right, from the tab row down beside EARLY / the desk / SECTORS; the tab
#   buttons a little smaller so they fit one row beside a tall F&O MOVERS. + the instant results line names the share first
#   ("🚨 RESULTS · KALYANKJIL · just filed") - the page filed it under "FILED". The exchange reader restarts (seconds).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS; cp $D/exchange.py $D/exchange.py.bak$TS
cat > $W/p178_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p178_patch.py - PATCH 178: (1) laptop MARKET: TRADE NOW is a tall column on the right from the tab row down (beside the tabs, EARLY,
the desk and SECTORS); (2) the instant results line names the share first, so the page files it under the share (it showed "FILED").
Usage: python3 p178_patch.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 178: TRADE NOW tall on the right (laptop, MARKET) */
@media(min-width:1100px){
  body.topchart.fkin #mk{grid-template-rows:auto auto auto minmax(0,1.3fr) minmax(0,1fr) minmax(0,1fr) !important;
    grid-template-areas:"mov fk fk act" "mov ear ear act" "mov dsk dsk act" "mov don don act" "mov mon mon nws" "ins idx rot nws" !important}
  body.topchart.fkin #q-act{min-height:300px}
  body.topchart.fkin #mk #fkeys{gap:3px}body.topchart.fkin #mk #fkeys a{padding:4px 7px;font-size:10.5px;letter-spacing:.04em}
}
</style>"""
out = []
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 178" not in t:
    if "patch 177" not in t:
        print("patch 177 is not in home.html - install it first"); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</style>", CSS, 1)); out.append("home.html: TRADE NOW tall on the right")
x = os.path.join(D, "exchange.py"); s = open(x, encoding="utf-8").read()
a = '"🚨 RESULTS FILED · %s · NSE %s (seen in %ds)'
if a in s:
    open(x, "w", encoding="utf-8").write(s.replace(a, '"🚨 RESULTS · %s · just filed on NSE %s (seen in %ds)   ', 1).replace('"🚨 RESULTS · %s · just filed on NSE %s (seen in %ds)   \\n', '"🚨 RESULTS · %s · just filed on NSE %s (seen in %ds)\\n'))
    out.append("exchange.py: the results line names the share first")
p = os.path.join(D, "p176test.py")
if os.path.exists(p):
    q = open(p, encoding="utf-8").read().replace('sent[0].startswith("🚨 RESULTS FILED · COCHINSHIP")', 'sent[0].startswith("🚨 RESULTS · COCHINSHIP · just filed")')
    open(p, "w", encoding="utf-8").write(q)
print(" · ".join(out) or "patch 178 is already in")
PY_PATCH
back() { cp $D/home.html.bak$TS $D/home.html; cp $D/exchange.py.bak$TS $D/exchange.py; }
R=$(python3 $W/p178_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile exchange.py || { back; echo "does not compile - old files back"; exit 1; }
[ -f p176test.py ] && { timeout 120 python3 p176test.py > /tmp/p176test.log 2>&1 && echo "p176test.py passed" || { echo "test FAILED - old files back"; grep FAIL /tmp/p176test.log | head -3; back; exit 1; }; }
systemctl restart gir-exchange && sleep 4 && [ "$(systemctl is-active gir-exchange)" = "active" ] && echo "exchange reader restarted" || { back; systemctl restart gir-exchange; echo "exchange reader did not come back - old files back"; exit 1; }
rm -rf $W
echo "PATCH 178 APPLIED - on the laptop press Ctrl + Shift + R on girtrader.com."
