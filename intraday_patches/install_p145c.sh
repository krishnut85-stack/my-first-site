#!/bin/bash
# PATCH 145c - 🔄 ROTATION ON THE MARKET PAGE. A full-width panel under the others, live: every sector (banks split PSU / private),
#   its F&O shares' average, how many are up / down, NSE's index; 🔄 ROTATION ON when one group is +0.8% with 70% of its shares up
#   and another -0.8% with 70% down; MONEY IN - the leaders and the laggards (the CE watch); MONEY OUT - the weakest and the ones
#   still holding (the PE watch); today's 🔄 alerts. Tap a share = its trading screen. home.html only (needs patch 145).
#   Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g145c; mkdir -p $W
grep -q "patch 145c" $D/home.html && { echo "patch 145c is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p145c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p145c_patch.py - PATCH 145c: 🔄 ROTATION ON THE MARKET PAGE (Rama, 9 Nov 20:10: "the sector rotation - I see no change on the page").
A full-width panel, live from the second-by-second prices: every sector (banks split PSU / private) with its F&O shares' average,
how many are up, NSE's own index; the rotation rule (one group +0.8% with 70% of its shares up while another is -0.8% with 70%
down = 🔄 ROTATION ON); MONEY IN: the leaders and the laggards (the CE watch - the 9 Nov backtest: early laggards 7 of 7 +1%);
MONEY OUT: the weakest and the ones still holding (the PE watch); today's 🔄 alerts. Tap a share = its trading screen.
Usage: python3 p145c_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
PANEL = '''    <div class="q" id="q-rot"><h3>🔄 ROTATION <span id="mk-roth">where the money is going · live · tap a share = its trading screen</span></h3><div class="bd" id="mk-rot"></div></div>
    <div class="q" id="q-don">'''
CSS = '''  #mk{height:auto;grid-template-rows:auto 56vh 56vh;font-size:12.5px}
  #mk{grid-template-rows:auto 56vh 56vh auto !important;grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus idx nws" "rot rot rot rot rot" !important}   /* patch 145c */
  #q-rot{grid-area:rot}'''
CSS2 = '''#focus table.oi{width:100%;'''
CSS2_NEW = '''/* patch 145c: 🔄 ROTATION */
#mk-rot .rs{padding:6px 10px;border-bottom:1px solid var(--line);font-size:13px}#mk-rot .rs b.on{color:#000;background:var(--amber);padding:1px 8px}
#mk-rot .rc{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:var(--line)}#mk-rot .rc>div{background:var(--panel);padding:4px 8px}
#mk-rot h4{font-size:11px;letter-spacing:.06em;margin:2px 0 4px}#mk-rot .rg{display:grid;grid-template-columns:140px 66px 112px 96px minmax(0,1fr);gap:2px 8px;padding:3px 0;border-bottom:1px solid #10151d;align-items:baseline}
#mk-rot .rg .nm{font-weight:700}#mk-rot .rg small{color:var(--dim)}#mk-rot .rg .sh a{cursor:pointer;margin-right:4px;white-space:nowrap;display:inline-block}#mk-rot .rg .sh a:hover{text-decoration:underline}
#mk-rot .ra{padding:4px 10px;color:var(--dim);font-size:11px;border-top:1px solid var(--line)}#mk-rot .ra b{color:var(--amber)}
@media(max-width:900px){#mk-rot .rc{grid-template-columns:1fr}#mk-rot .rg{grid-template-columns:1fr auto auto;}#mk-rot .rg .ix{display:none}#mk-rot .rg .sh{grid-column:1/-1}#q-rot{height:auto !important;max-height:none}}
#focus table.oi{width:100%;'''
JS = '''/* patch 145c: 🔄 ROTATION - the groups (banks split PSU / private), the rule, money in / money out, today's 🔄 alerts */
const PSUB=new Set(["SBIN","BANKBARODA","PNB","CANBK","UNIONBANK","BANKINDIA","INDIANB","IOB","UCOBANK","CENTRALBK","MAHABANK","PSB"]);
function rotGroups(){ const by={}; (TAPE||[]).forEach(r=>{ if(r.chg!=null) by[r.s]=r; }); const G=[];
  (SECS||[]).forEach(x=>{ const nm=String(x.name||""); const sy=(x.syms||[]).filter(s=>by[s]);
    const parts=/bank/i.test(nm)?[["PSU BANKS",sy.filter(s=>PSUB.has(s)),"NIFTY PSU BANK"],["PRIVATE BANKS",sy.filter(s=>!PSUB.has(s)),"NIFTY PVT BANK"]]:[[nm.toUpperCase(),sy,null]];
    parts.forEach(([n,ss,ix])=>{ if(ss.length<3||/^OTHERS$/i.test(n)) return; const cc=ss.map(s=>[by[s].chg,s]).sort((a,b)=>b[0]-a[0]);
      const avg=cc.reduce((a,c)=>a+c[0],0)/cc.length, up=cc.filter(c=>c[0]>0).length/cc.length, dn=cc.filter(c=>c[0]<0).length/cc.length;
      const si=ix?(((MK&&MK.sidx)||{})[ix]||null):secIdx(x.name); G.push({n,avg,up,dn,cc,ic:si&&si.chg!=null?si.chg:null}); }); });
  return G.sort((a,b)=>b.avg-a.avg); }
function drawRot(){ const el=$("mk-rot"); if(!el) return; const G=rotGroups();
  if(!G.length){ MKH("mk-rot").innerHTML='<div class="empty">the sectors come with the first prices</div>'; return; }
  const ins=G.filter(g=>g.avg>=0.8&&g.up>=0.7), outs=G.filter(g=>g.avg<=-0.8&&g.dn>=0.7).reverse();
  const f=v=>`<span class="${v>0?"pu":v<0?"pd":"dim"}">${v>0?"+":""}${v.toFixed(2)}%</span>`;
  const sh=(L)=>L.map(([c,s])=>`<a onclick="mkOpen('${esc(s)}')">${esc(s)} ${f(c)}</a>`).join(" ");
  const top=G[0], bot=G[G.length-1];
  const st=(ins.length&&outs.length)?`<b class="on">🔄 ROTATION ON</b> money into <b>${ins.map(g=>esc(g.n)).join(" · ")}</b> ← out of <b>${outs.map(g=>esc(g.n)).join(" · ")}</b>`
    :`no rotation by the rule now <small class="dim">(one group +0.8% with 70% of its shares up while another is −0.8% with 70% down)</small> · strongest <b>${esc(top.n)}</b> ${f(top.avg)} ${Math.round(top.up*100)}% up · weakest <b>${esc(bot.n)}</b> ${f(bot.avg)} ${Math.round(bot.dn*100)}% down`;
  const row=(g,side)=>{ const lead=(side>0?g.cc.filter(c=>c[0]>0).slice(0,3):g.cc.filter(c=>c[0]<0).slice(-3).reverse()); const ls=new Set(lead.map(c=>c[1]));
    const lag=Math.abs(g.avg)<0.3?[]:(side>0?g.cc.filter(c=>c[0]<g.avg*0.5&&!ls.has(c[1])).slice(-4).reverse():g.cc.filter(c=>c[0]>g.avg*0.5&&!ls.has(c[1])).slice(0,4));
    return `<div class="rg"><span class="nm">${esc(g.n)}</span>${f(g.avg)}<small>${side>0?Math.round(g.up*100)+"% up":Math.round(g.dn*100)+"% down"} of ${g.cc.length}</small><small class="ix">${g.ic!=null?"index "+(g.ic>0?"+":"")+g.ic.toFixed(2)+"%":""}</small>
      <span class="sh">${lead.length?(side>0?"leading":"weakest")+": "+sh(lead):'<small>none '+(side>0?"up":"down")+"</small>"}${lag.length?`<br><small>${side>0?"still lagging - the CE watch":"still holding up - the PE watch"}:</small> ${sh(lag)}`:""}</span></div>`; };
  const A=((D&&D.now)||[]).filter(r=>/MARKET ROTATION/.test(r.head||""));
  MKH("mk-rot").innerHTML=`<div class="rs">${st}</div><div class="rc"><div><h4 class="pu">MONEY IN</h4>${G.slice(0,5).filter(g=>g.avg>0).map(g=>row(g,1)).join("")||'<div class="dim">no group up</div>'}</div>
    <div><h4 class="pd">MONEY OUT</h4>${G.slice(-5).reverse().filter(g=>g.avg<0).map(g=>row(g,-1)).join("")||'<div class="dim">no group down</div>'}</div></div>
    <div class="ra">${A.length?"today's 🔄 alerts: "+A.map(r=>`<b>${esc(r.t)}</b> ${esc((r.head||"").replace(/^🔄 MARKET ROTATION · /,"").slice(0,120))}`).join(" · "):"today's 🔄 alerts: none yet (they ring in Box Picks from 09:20 - patch 142)"}</div>`; }
'''
EDITS = [
    ('''    <div class="q" id="q-don">''', PANEL),
    ('''  #mk{height:auto;grid-template-rows:auto 56vh 56vh;font-size:12.5px}''', CSS),
    (CSS2, CSS2_NEW),
    ('''  // SECTOR DONUT''', '''  drawRot();   // patch 145c
  // SECTOR DONUT'''),
    ('''function MKH(id){''', JS + '''function MKH(id){'''),
]
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 145c" in s:
    print("patch 145c is already in home.html"); sys.exit(1)
if "patch 145:" not in s:
    print("patch 145 is not installed yet - install it first"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:90].replace("\n", " | "))); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
python3 $W/p145c_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && for t in p145btest.py p143test.py p142test.py p140ftest.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 145c APPLIED. Reload the GIR page (Ctrl+F5) and scroll down on MARKET: the 🔄 ROTATION panel."
