#!/bin/bash
# PATCH 140e - THE SHARE WINDOW'S TABS ON THE MARKET PAGE, ABOVE F&O MOVERS.
#   The sectors (ALL · BANKS · NBFC & FINANCE · ...), the sort (A-Z · PRICE · CHG % · OI % · DESK) and the filters
#   (▲ UP · ▼ DOWN · LB · SB · SC · LU) - the same settings as the share window. No filter = the two columns as before.
#   home.html only. Restarts gir-dash only - safe in market hours. (Works with or without patch 140d.)
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140e; mkdir -p $W
grep -q "patch 140e" $D/home.html && { echo "patch 140e is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p140e_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140e_patch.py - PATCH 140e: THE SHARE WINDOW'S TABS ON THE MARKET PAGE (Rama, 9 Nov 14:50: "the same tabs I need above F&O MOVERS").
F&O MOVERS now carries the share list's three rows: the sectors (ALL · BANKS · NBFC & FINANCE · ...), the sort (A-Z · PRICE · CHG % ·
OI % · DESK) and the filters (▲ UP · ▼ DOWN · LB · SB · SC · LU), the same settings as the share window. With no filter and the sort on
CHG % it stays the two columns (gainers | losers); any filter or another sort = one list with the price, OI %, the build-up and the desk.
Usage: python3 p140e_patch.py /home/globalbot/intraday  (replaces the F&O MOVERS block between its two comments; aborts if not found once)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
START, END = "  // F&O MOVERS: gainers | losers\n", "  // NIFTY through the day"
BLOCK = r'''  // F&O MOVERS: gainers | losers   (patch 140e: + the share window's tabs - the sectors · the sort · ▲ UP ▼ DOWN LB SB SC LU)
  { const el=$("mk-mov"); const sx=WS.sec?(SECS||[]).find(x=>x.name===WS.sec):null; const set_=sx?new Set(sx.syms||[]):null;
    const T0=(TAPE||[]).filter(r=>r.chg!=null&&(!set_||set_.has(r.s))&&(!WS.bu||(r.bu||"").toUpperCase()===WS.bu));
    const T=T0.slice().sort((a,b)=>b.chg-a.chg); const n=Math.max(12,Math.floor((el.clientHeight||300)/15)-1);
    const up=T.filter(r=>r.chg>0).slice(0,n), dn=T.filter(r=>r.chg<0).reverse().slice(0,n); const N=Math.max(up.length,dn.length);
    const wide=(el.clientWidth||300)>=430; const cell=r=>r?`<td class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b></td>${wide?`<td class="r dim">${r.px!=null?inr(r.px):""}</td>`:""}<td class="r ${cls(r.chg)}${qfl(r.s)}">${mkPc(r.chg)}</td>`:(wide?"<td></td><td></td><td></td>":"<td></td><td></td>");
    $("mk-movh").textContent=`${T.filter(r=>r.chg>0).length} up · ${T.filter(r=>r.chg<0).length} down${WS.sec?" · "+WS.sec.toUpperCase():""} · tap = its trading screen`;
    const L=T0.filter(r=>!WS.pn||(WS.pn==="up"?r.chg>0:r.chg<0));
    const btn=(k,l)=>`<a class="${WS.k===k?"on":""}" onclick="wsSort('${k}')">${l}${WS.k===k?(WS.dir>0?" ▲":" ▼"):""}</a>`;
    const tabs=`<div class="mvt"><div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${(SECS||[]).map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>
      <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("v","DESK")}</div>
      <div class="wss"><a class="${WS.pn==="up"?"on":""}" onclick="wsPn('up')"><span class="${WS.pn==="up"?"":"pu"}">▲ UP</span></a><a class="${WS.pn==="dn"?"on":""}" onclick="wsPn('dn')"><span class="${WS.pn==="dn"?"":"pd"}">▼ DOWN</span></a>${Object.entries(BUS).map(([nm,[sh,c]])=>`<a class="${WS.bu===nm?"on":""}" onclick="wsBu('${nm}')"><span class="${WS.bu===nm?"":c}">${sh}</span></a>`).join("")}${(WS.sec||WS.bu||WS.pn)?`<a onclick="wsClear()">✕ ALL</a>`:""}<span class="dim">${L.length} shares</span></div></div>`;
    let body;
    if(!WS.pn&&!WS.bu&&WS.k==="chg"&&WS.dir<0){ body=`<table>${Array.from({length:N},(_,i)=>`<tr>${cell(up[i])}<td style="border-left:1px solid var(--line);padding:0"></td>${cell(dn[i])}</tr>`).join("")}</table>`; }
    else { const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);
      const R=L.slice().sort((a,b)=>{ const x=val(a), y=val(b); return (x<y?-1:x>y?1:0)*WS.dir; });
      body=R.length?`<div class="mvl">${R.map(r=>{ const bb=BUS[(r.bu||"").toUpperCase()]; return `<div class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b><span class="${cls(r.chg)}${qfl(r.s)}">${mkPc(r.chg)}</span><small>₹${r.px!=null?inr(r.px):"—"}${r.foi!=null?` · OI <span class="${r.foi>0?"pu":r.foi<0?"pd":""}">${r.foi>0?"+":""}${Number(r.foi).toFixed(1)}%</span>`:""}${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")}</div>`:'<div class="empty">no share matches</div>'; }
    MKH(el.id).innerHTML=tabs+body; }
'''
CSS_A = '''#focus .wss .dim{font-size:9px;margin-left:auto}'''
CSS_B = CSS_A + '''
/* patch 140e: the share window's tabs on F&O MOVERS */
#q-mov .mvt{position:sticky;top:0;z-index:2;background:var(--panel)}
#q-mov .wst{display:flex;gap:2px;flex-wrap:wrap;padding:4px;border-bottom:1px solid var(--line)}
#q-mov .wst a,#q-mov .wss a{flex:none;padding:3px 6px;border:1px solid var(--line2);font-size:9px;letter-spacing:.04em;cursor:pointer;white-space:nowrap;color:var(--txt);background:#000}
#q-mov .wst a.on,#q-mov .wss a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#q-mov .wss{display:flex;gap:2px;flex-wrap:wrap;padding:4px;border-bottom:1px solid var(--line);align-items:center}#q-mov .wss .dim{font-size:9px;margin-left:auto}
#q-mov .mvl>div{display:grid;grid-template-columns:1fr auto;padding:3px 6px;border-bottom:1px solid var(--line);cursor:pointer}#q-mov .mvl small{grid-column:1/-1;color:var(--dim);font-size:9.5px}
@media(max-width:700px){#q-mov .wst{flex-wrap:nowrap;overflow-x:auto;scrollbar-width:none}#q-mov .wst::-webkit-scrollbar{display:none}#q-mov.q{height:420px}}'''
REDRAW = 'wsSave(); WSKEY=""; paint(); }'


def main():
    p = os.path.join(D, "home.html")
    s = open(p, encoding="utf-8").read()
    if "patch 140e" in s:
        print("patch 140e is already in the page"); return 1
    a, b = s.find(START), s.find(END)
    if s.count(START) != 1 or s.count(END) != 1 or not (0 < a < b):
        print("ANCHOR: the F&O MOVERS block not found once"); return 1
    s = s[:a] + BLOCK + s[b:]
    if s.count(CSS_A) != 1:
        print("ANCHOR: the share list css not found once"); return 1
    s = s.replace(CSS_A, CSS_B)
    if s.count(REDRAW) != 5:
        print("ANCHOR: the share list's tab functions x%d (5 expected)" % s.count(REDRAW)); return 1
    s = s.replace(REDRAW, 'wsSave(); WSKEY=""; paint(); mkRe(); }')
    s = s.replace("function wsSave(){", '''function mkRe(){ if(typeof VIEW!=="undefined"&&VIEW==="market"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } }   /* patch 140e: a tab on F&O MOVERS redraws it */
function wsSave(){''', 1)
    open(p, "w", encoding="utf-8").write(s)
    print("patched: home.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
python3 $W/p140e_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && for t in p136test.py p129test.py p128test.py p120test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 140e APPLIED. Reload the GIR page: F&O MOVERS has the share window's tabs (sectors · sort · UP / DOWN / LB SB SC LU)."
