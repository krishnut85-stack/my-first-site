#!/bin/bash
# PATCH 150b - F&O MOVERS SHOWS ITS LIST. The sector buttons become one drop-down (a chosen sector = an amber chip with ✕), the sort
#   and the filters share a row - the shares show at once. home.html only (needs 150). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150b; mkdir -p $W
grep -q "patch 150b" $D/home.html && { echo "patch 150b is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p150b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150b_patch.py - PATCH 150b: F&O MOVERS SHOWS ITS LIST (Rama, 9 Nov 21:38: "F&O movers is not showing the shares list"). The 20 sector
buttons + the sort row + the filter row filled the panel in the one-screen layout; the list was below. Now: the sectors are one
drop-down, the sort and the filters share one row, and a chosen sector shows as an amber chip with ✕ beside the list's count.
Usage: python3 p150b_patch.py /home/globalbot/intraday  (needs 150)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''    const tabs=`<div class="mvt"><div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${(SECS||[]).map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>''',
     '''    const tabs=`<div class="mvt"><div class="wst wsel"><select onchange="wsSec(this.value)" title="a sector = its shares only"><option value="">ALL SECTORS</option>${(SECS||[]).map(x=>`<option value="${esc(x.name)}"${WS.sec===x.name?" selected":""}>${esc(x.name.toUpperCase())}</option>`).join("")}</select>${WS.sec?`<a class="on" onclick="wsSec('')" title="back to all sectors">${esc(WS.sec.toUpperCase())} ✕</a>`:""}</div>'''),
    ('''${btn("v","DESK")}</div>\n    <div class="wss">''', '''${btn("v","DESK")}<span class="sep"></span>'''),
    ('''#mk #nifTf{display:none !important}''', '''#mk #nifTf{display:none !important}
#q-mov .wsel{display:flex;gap:6px;align-items:center;flex-wrap:nowrap}#q-mov .wsel select{flex:1;min-width:0;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);border-radius:4px;padding:3px 6px;font:600 11px var(--ui);letter-spacing:.06em}
#q-mov .wss .sep{width:1px;height:16px;background:var(--line2);margin:0 3px}   /* patch 150b */'''),
]
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 150b" in s:
    print("patch 150b is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:80])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
python3 $W/p150b_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && for t in p140etest.py p140ftest.py p129test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo
echo "PATCH 150b APPLIED. Reload the GIR page with Ctrl+F5."
