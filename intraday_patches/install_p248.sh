#!/bin/bash
# PATCH 248 - the share window names its SECTOR and how the whole sector is doing today (Rama, 13 Nov 12:28). On the share's top line:
#   🏷 CONSUMER DURABLES -0.7% · 3 of 10 up · #15 of 21 sectors · CROMPTON weaker than its sector - the same numbers as SECTORS / ROTATION
#   (the average of the sector's F&O shares, live); hover = every share of the sector with its %.
#   Tested in a browser (the tag's % = the SECTORS box's %). Page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 238" $D/home.html || { echo "patch 238 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p248_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p248_patch.py - PATCH 248: the share window names its SECTOR and how the whole sector is doing today (Rama, 13 Nov 12:28: "when I click a share a
separate page opens - that page should show which sector the share belongs to and the overall performance of that sector today").
On the share's top line: 🏷 CONSUMER DURABLES -0.7% · 3 of 10 up · #15 of 21 sectors · CROMPTON weaker than its sector - the same numbers as SECTORS /
ROTATION (the average of the sector's F&O shares, live); hover = every share of the sector with its %. Page only. Usage: python3 p248_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); S = {"s": open(p, encoding="utf-8").read()}
ERR = []


def rep(old, new, tag):
    s = S["s"]
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  home.html: %s" % tag)


rep('''${rsiTag()}${chainTag()}''', '''${rsiTag()}${secTag(f.s)}${chainTag()}''', "the share's top line: its sector")
rep('''function rsiTag(){''', '''/* patch 248: the share's sector and how the whole sector is doing today (the average of its F&O shares - as SECTORS / ROTATION) */
function secStats(){ const by={}; (TAPE||[]).forEach(r=>{ if(r.s&&r.chg!=null) by[r.s]=r.chg; });
  return (SECS||[]).map(x=>{ const v=(x.syms||[]).filter(s=>by[s]!=null).map(s=>[s,by[s]]); const a=v.length?v.reduce((t,c)=>t+c[1],0)/v.length:null;
    return {name:x.name,v,avg:a,up:v.filter(c=>c[1]>0).length,dn:v.filter(c=>c[1]<0).length}; }).filter(x=>x.avg!=null); }
function secTag(sym){ try{ const S=secStats(); const mine=S.filter(x=>x.v.some(c=>c[0]===sym)); if(!mine.length) return "";
    const big=S.filter(x=>x.v.length>=3).sort((a,b)=>b.avg-a.avg); const g=mine.sort((a,b)=>b.v.length-a.v.length)[0];
    const rk=big.findIndex(x=>x.name===g.name), me=(g.v.find(c=>c[0]===sym)||[])[1];
    const rel=me==null?"":Math.abs(me-g.avg)<0.3?"moving with its sector":(me>g.avg?(me>0&&g.avg<0?"UP while its sector falls":"stronger than its sector"):(me<0&&g.avg>0?"DOWN while its sector rises":"weaker than its sector"));
    const tip=`${g.name} today (live, F&O shares):\\n`+g.v.slice().sort((a,b)=>b[1]-a[1]).map(c=>`${c[0]} ${c[1]>0?"+":""}${c[1].toFixed(2)}%`).join("\\n");
    return ` <span class="sct" title="${esc(tip)}">🏷 ${esc(String(g.name).toUpperCase())} <b class="${g.avg>0?"pu":g.avg<0?"pd":"dim"}">${g.avg>0?"+":""}${g.avg.toFixed(2)}%</b> <span class="dim">· ${g.up} of ${g.v.length} up${rk>=0?` · #${rk+1} of ${big.length} sectors`:""}${rel?" · "+esc(sym)+" "+rel:""}</span></span>`;
  }catch(e){ return ""; } }
function rsiTag(){''', "secStats() · secTag()")
rep('''</style>''', '''.hd .sct{margin-left:10px;white-space:nowrap;font-size:12px;cursor:help}   /* patch 248 */
</style>''', "the sector tag's style")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 248 in")
PY_PATCH
python3 $W/p248_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 248 done - reload every GIR tab (Ctrl + Shift + R); open any share - its sector is on the top line."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
