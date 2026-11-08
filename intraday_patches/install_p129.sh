#!/bin/bash
# PATCH 129 - TYPE-AHEAD IN THE TICKER BOX (on top of patch 128).
#   Type D -> the shares starting with D; DA -> DABUR, DALBHARAT, DATAPATTNS, then the ones containing DA; DAT -> DATAPATTNS.
#   Each line: the share, price, % today, industry. Tap one (or arrow keys + Enter) to open it; Enter / GO opens the first.
#   home.html (exact anchors). Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g129; mkdir -p $W
grep -q "function ckDecision" $D/home.html 2>/dev/null || { echo "patch 128 is not installed yet - paste patch 128 first"; exit 1; }
grep -q "function sugList" $D/home.html && { echo "patch 129 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; rm -f $D/p129test.py; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p129_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p129_patch.py - PATCH 129: TYPE-AHEAD in the ticker box. D -> the shares starting with D; DA -> DABUR, DALBHARAT, DATAPATTNS ...;
DAT -> DATAPATTNS. Each line: the share, its price and % today, its industry. Tap (or arrow keys + Enter) opens it; Enter with
nothing picked opens the first one. Shares that only CONTAIN the letters come after the ones that start with them.
Usage: python3 p129_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
JS = r'''/* patch 129: type-ahead in the ticker box */
let SUG=[], SUGI=-1;
function sugList(q){ q=(q||"").toUpperCase().replace(/\s+/g,""); if(!q) return []; const all=(TAPE||[]).map(r=>r.s).filter(Boolean);
  const a=all.filter(s=>s.startsWith(q)).sort(), b=all.filter(s=>!s.startsWith(q)&&s.includes(q)).sort(); return a.concat(b).slice(0,10); }
function sugDraw(){ let el=$("sug"); if(!el){ el=document.createElement("div"); el.id="sug"; $("cmd").appendChild(el); }
  if(!SUG.length){ el.hidden=true; el.innerHTML=""; return; }
  const q=($("q").value||"").toUpperCase().replace(/\s+/g,"");
  el.innerHTML=SUG.map((s,i)=>{ const r=(TAPE||[]).find(x=>x.s===s)||{}; const ind=(typeof INDOF!=="undefined"&&INDOF[s])||"";
    const k=s.indexOf(q); const nm=k>=0?esc(s.slice(0,k))+"<u>"+esc(s.slice(k,k+q.length))+"</u>"+esc(s.slice(k+q.length)):esc(s);
    return `<div class="sg${i===SUGI?" on":""}" data-s="${esc(s)}"><b>${nm}</b><span>${r.px!=null?"₹"+inr(r.px):""}</span><span class="${cls(r.chg)}">${r.chg!=null?pc(r.chg):""}</span><span class="dim">${esc(ind)}</span></div>`; }).join("");
  el.hidden=false;
  el.querySelectorAll(".sg").forEach(d=>d.addEventListener("pointerdown",e=>{ e.preventDefault(); const s=d.getAttribute("data-s"); sugHide(); focusOn(s); })); }
function sugHide(){ SUG=[]; SUGI=-1; sugDraw(); }
$("q").addEventListener("input",()=>{ SUG=sugList($("q").value); SUGI=-1; sugDraw(); });
$("q").addEventListener("focus",()=>{ if($("q").value&&!FOC){ SUG=sugList($("q").value); sugDraw(); } });
$("q").addEventListener("blur",()=>setTimeout(sugHide,150));
$("q").addEventListener("keydown",e=>{ if(!SUG.length) return;
  if(e.key==="ArrowDown"||e.key==="ArrowUp"){ e.preventDefault(); SUGI=(SUGI+(e.key==="ArrowDown"?1:-1)+SUG.length)%SUG.length; sugDraw(); return; }
  if(e.key==="Escape"){ sugHide(); return; }
  if(e.key==="Enter"){ const v=($("q").value||"").toUpperCase().trim(); const s=SUGI>=0?SUG[SUGI]:(SUG.includes(v)?v:SUG[0]);
    e.preventDefault(); e.stopImmediatePropagation(); sugHide(); focusOn(s); } });
$("go").addEventListener("click",e=>{ const v=($("q").value||"").toUpperCase().trim(); if(SUG.length&&!SUG.includes(v)){ e.stopImmediatePropagation(); const s=SUG[SUGI>=0?SUGI:0]; sugHide(); focusOn(s); } }, true);
'''
EDITS = {
    "home.html": [
        ('''$("go").onclick=()=>focusOn($("q").value);''', JS + '''$("go").onclick=()=>{ if(SUG.length) return; focusOn($("q").value); };'''),
        ('''#cmd .x{''', '''#cmd{position:relative}   /* patch 129: type-ahead */
#sug{position:absolute;left:22px;right:8px;top:100%;z-index:60;background:#0b0d11;border:1px solid var(--amber);max-height:60vh;overflow-y:auto;box-shadow:0 6px 18px #000a}
#sug .sg{display:grid;grid-template-columns:1fr auto auto minmax(0,110px);gap:10px;align-items:center;padding:8px 10px;border-bottom:1px solid var(--line);cursor:pointer;font:13px var(--mono)}
#sug .sg b{color:var(--hi);letter-spacing:.04em}#sug .sg u{color:var(--amber);text-decoration:none}#sug .sg .dim{font-size:10.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#sug .sg.on,#sug .sg:hover{background:#1d1500}
#cmd .x{'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("home.html: type-ahead in the ticker box")
PY_PATCH
cat > $D/p129test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p129test.py - type-ahead in the ticker box: D / DA / DAT narrow the list, the shares that START with the letters first."""
import os, sys, shutil, subprocess
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page has the type-ahead (list, keys, tap)", "function sugList(q)" in pg and "function sugDraw()" in pg and '$("q").addEventListener("input"' in pg and "#sug .sg" in pg)
node = shutil.which("node")
if node:
    a = pg.index("function sugList(q)"); b = pg.index("function sugDraw()")
    js = ("let TAPE=" + str([{"s": s} for s in "DABUR DALBHARAT DATAPATTNS DEEPAKNTR DIVISLAB ADANIENT ADANIPORTS BANKBARODA HINDALCO TITAN".split()]).replace("'", '"') + ";\n"
          + pg[a:b] + "\nconsole.log([sugList('d'),sugList('DA'),sugList('dat'),sugList(''),sugList('ZZZ')].map(x=>x.join(' ')).join('|'))")
    r = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    o = r.stdout.strip().split("|")
    check("D -> %s" % (o[0] if o else r.stderr[:100]), o and o[0].startswith("DABUR DALBHARAT DATAPATTNS DEEPAKNTR DIVISLAB "))
    check("DA -> the ones starting with DA first, then the ones containing it: %s" % (o[1] if len(o) > 1 else ""), len(o) > 1 and o[1] == "DABUR DALBHARAT DATAPATTNS ADANIENT ADANIPORTS BANKBARODA HINDALCO")
    check("dat (small letters) -> DATAPATTNS; empty -> nothing; ZZZ -> nothing", len(o) > 4 and o[2] == "DATAPATTNS" and o[3] == "" and o[4] == "")
else:
    print("  (node not on this machine - the page logic was checked when the patch was built)")
print("\nP129 TYPE-AHEAD TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p129_patch.py $D || { rm -f $D/p129test.py; echo "the anchors did not match this server's page - nothing was changed"; exit 1; }
cd $D && timeout 60 python3 p129test.py 2>&1 | grep "OK  \|FAIL\|AHEAD TEST\|node"
timeout 60 python3 p129test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p128test.py p120test.py p123test.py p114test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function sugList" || { echo "the new page is not being served"; back; }
echo
echo "PATCH 129 APPLIED. Reload the GIR page and type DA in the ticker box."
