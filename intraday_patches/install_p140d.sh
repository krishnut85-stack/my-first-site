#!/bin/bash
# PATCH 140d - F&O MOVERS GETS ITS FILTERS, AND A PANEL'S TABS SHOW ON A PHONE.
#   F&O MOVERS: ALL · ▲ UP · ▼ DOWN (UP / DOWN = one long list); the ALL SECTORS box filters it too (its name shown, ✕ clears).
#   On a phone a MARKET panel's title wraps, so its tabs (F&O MOVERS, NIFTY 1m / 5m / 1D / 2D / AUTO ...) are always on screen.
#   home.html only (exact anchors). Restarts gir-dash only - safe in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140d; mkdir -p $W
grep -q "patch 140d" $D/home.html && { echo "patch 140d is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p140d_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140d_patch.py - PATCH 140d: F&O MOVERS GETS ITS FILTERS. Rama: "the tabs to select the sectors and the up / down tabs above F&O
MOVERS are not visible" - the MARKET screen's movers never had them (the ALL SECTORS box filtered only keys 4 / 5). Now:
ALL · ▲ UP · ▼ DOWN on F&O MOVERS (UP / DOWN = one long list), and the ALL SECTORS box filters it too (its name shown, ✕ clears).
Usage: python3 p140d_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "home.html": [
        ('''<div class="q" id="q-mov"><h3>F&amp;O MOVERS<span id="lvq"></span> <span id="mk-movh">% today · tap = its trading screen</span></h3>''',
         '''<div class="q" id="q-mov"><h3>F&amp;O MOVERS<span id="lvq"></span> <span id="mk-movh">% today · tap = its trading screen</span><span class="ntf" id="movTf"></span></h3>'''),
        ('''  { const el=$("mk-mov"); const T=(TAPE||[]).filter(r=>r.chg!=null).slice().sort((a,b)=>b.chg-a.chg); const n=Math.max(12,Math.floor((el.clientHeight||300)/15)-1);''',
         '''  { const el=$("mk-mov"); const set_=sectorSyms(); const T=(TAPE||[]).filter(r=>r.chg!=null&&(!set_||set_.has(r.s))).slice().sort((a,b)=>b.chg-a.chg); const n=Math.max(12,Math.floor((el.clientHeight||300)/15)-1);   /* patch 140d: the sector box filters it */
    MKH("movTf").innerHTML=`<a class="${MVF==="all"?"on":""}" onclick="movF('all')">ALL</a><a class="${MVF==="up"?"on":""}" onclick="movF('up')">▲ UP</a><a class="${MVF==="down"?"on":""}" onclick="movF('down')">▼ DOWN</a>${SEL?` <a class="on" onclick="pickSector('${esc(SEL)}');movF(MVF)" title="all sectors again">${esc(SEL.toUpperCase().slice(0,14))} ✕</a>`:""}`;'''),
        ('''    MKH(el.id).innerHTML=`<table>${Array.from({length:N},(_,i)=>`<tr>${cell(up[i])}<td style="border-left:1px solid var(--line);padding:0"></td>${cell(dn[i])}</tr>`).join("")}</table>`; }''',
         '''    const one=MVF==="up"?T.filter(r=>r.chg>0):MVF==="down"?T.filter(r=>r.chg<0).reverse():null;      /* patch 140d: UP / DOWN = one long list */
    MKH(el.id).innerHTML=one?(one.length?`<table>${one.map(r=>`<tr>${cell(r)}</tr>`).join("")}</table>`:'<div class="empty">none</div>'):`<table>${Array.from({length:N},(_,i)=>`<tr>${cell(up[i])}<td style="border-left:1px solid var(--line);padding:0"></td>${cell(dn[i])}</tr>`).join("")}</table>`; }'''),
        ('''$("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };''',
         '''$("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); if(VIEW==="market") movF(MVF); };'''),
        ('''#mk .q h3 span{color:var(--dim);letter-spacing:0;font-weight:400}''',
         '''#mk .q h3 span{color:var(--dim);letter-spacing:0;font-weight:400}
@media(max-width:700px){#mk .q h3{flex-wrap:wrap;white-space:normal;row-gap:3px}#mk .q h3 .ntf{float:none;order:9;flex-basis:100%;display:flex;gap:4px;flex-wrap:wrap}#mk .q h3 .ntf a{padding:2px 9px}}   /* patch 140d: a phone - a panel's tabs on their own line, always seen */'''),
        ('''function pickSector(n){''', '''let MVF="all";                                   /* patch 140d: F&O MOVERS - ALL / UP / DOWN */
function movF(f){ MVF=f; if(VIEW==="market"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } }
function pickSector(n){'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
python3 $W/p140d_patch.py $D || { echo "the anchors did not match this server's page - nothing was changed"; exit 1; }
cd $D && for t in p136test.py p129test.py p128test.py p120test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 140d APPLIED. Reload the GIR page: F&O MOVERS - ALL / UP / DOWN, the ALL SECTORS box filters it."
