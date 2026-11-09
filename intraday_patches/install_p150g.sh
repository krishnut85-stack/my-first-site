#!/bin/bash
# PATCH 150g - SECTORS: every sector (compact rows), a visible scroll bar on every panel, SORT % HIGH→LOW / LOW→HIGH (tap again) · A-Z.
#   home.html only (needs 150f). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150g; mkdir -p $W
grep -q "patch 150g" $D/home.html && { echo "patch 150g is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
cat > $W/p150g_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150g_patch.py - PATCH 150g (Rama, 9 Nov 21:59): SECTORS shows every sector (compact rows), a visible scroll bar on every panel, and a
sort: % HIGH→LOW / LOW→HIGH (tap again) · A-Z.   Usage: python3 p150g_patch.py /home/globalbot/intraday  (needs 150f)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('.sort((a,b)=>((b.n>=3)-(a.n>=3))||(b.v-a.v));',
     '.sort((a,b)=>SSORT==="az"?a.name.localeCompare(b.name):((b.n>=3)-(a.n>=3))||(SSORT==="up"?a.v-b.v:b.v-a.v));   /* patch 150g */'),
    ('MKH("mk-don").innerHTML=R.length?R.map(',
     'MKH("mk-don").innerHTML=(R.length?`<div class="ssb">SORT <a class="${SSORT!=="az"?"on":""}" onclick="ssSet(SSORT===\'dn\'?\'up\':\'dn\')">% ${SSORT==="up"?"▲ LOW→HIGH":"▼ HIGH→LOW"}</a><a class="${SSORT==="az"?"on":""}" onclick="ssSet(\'az\')">A–Z</a><span class="dim">${R.length} sectors</span></div>`:"")+(R.length?R.map('),
    ('}).join(""):\'<div class="empty">no sectors yet</div>\'; }', '}).join(""):\'<div class="empty">no sectors yet</div>\'); }'),
    ('function MKH(id){', '''/* patch 150g: the SECTORS sort */
let SSORT="dn"; try{ SSORT=localStorage.getItem("gir_ssort")||"dn"; }catch(e){}
function ssSet(v){ SSORT=v; try{ localStorage.setItem("gir_ssort",v); }catch(e){} drawMarket.force=true; drawMarket(); drawMarket.force=false; }
function MKH(id){'''),
    ("#mk-don .sb{display:grid;grid-template-columns:minmax(0,128px) 1fr 60px;gap:8px;align-items:center;font-size:12.5px;padding:2.5px 2px;",
     """#mk-don .ssb{display:flex;gap:4px;align-items:center;font-size:10px;color:var(--dim);padding:0 2px 5px;position:sticky;top:0;background:var(--panel);z-index:2}
#mk-don .ssb a{padding:2px 7px;border:1px solid var(--line2);border-radius:4px;cursor:pointer;color:var(--txt);background:var(--panel2);font:600 10.5px var(--ui);letter-spacing:.05em}#mk-don .ssb a.on{background:var(--amber);color:#1a1205;border-color:var(--amber)}#mk-don .ssb .dim{margin-left:auto}
#mk .q .bd{scrollbar-width:thin;scrollbar-color:var(--line2) transparent}#mk .q .bd::-webkit-scrollbar{width:8px;height:8px}#mk .q .bd::-webkit-scrollbar-thumb{background:var(--line2);border-radius:4px}#mk .q .bd::-webkit-scrollbar-thumb:hover{background:var(--dim)}
#mk-don .sb{display:grid;grid-template-columns:minmax(0,128px) 1fr 60px;gap:8px;align-items:center;font-size:12px;padding:1px 2px;"""),
]
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 150g" in s:
    print("patch 150g is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:70])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s); print("patched: home.html")
PY_PATCH
python3 $W/p150g_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back"; exit 1; }
echo "PATCH 150g APPLIED. Reload the GIR page with Ctrl+F5."
