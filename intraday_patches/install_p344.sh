#!/bin/bash
# PATCH 344 - THE SECTOR RANKING, DONE PROPERLY (Rama, 16 Nov: "our sector ranking is completely wrong - healthcare is no.1 (Trendlyne), the rotation %
#   is wrong - do the maths"). GIR's sector % was the PLAIN average of its F&O shares (LAURUSLABS -7% weighed as much as SUNPHARMA) and HEALTHCARE
#   mixed pharma with hospitals. Now (SECTORS box, the phone's sector grid, ROTATION):
#   · a sector with its own NSE index (BANK, PSU BANK, PVT BANK, IT, PHARMA, AUTO, FMCG, METAL, OIL & GAS, REALTY, CONSUMER DURABLES, CHEMICALS,
#     CAPITAL MARKETS, MEDIA) shows NSE's index % for TODAY - marked NSE
#   · every other sector, and every 15M / 30M / 1H window: the SIZE-WEIGHTED average of its F&O shares (weight = futures open interest in ₹)
#   · HEALTHCARE split into PHARMA and HOSPITALS & DIAGNOSTICS · beside each sector how many of its shares are up (10/26 ▲) · its own top mover
#   Edits home.html only. No restart - refresh the page. Tested at 3 sizes.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 344" $D/home.html; then echo "patch 344 - already in"; exit 0; fi
grep -q "patch 343" $D/home.html && grep -q "function rotGroups()" $D/home.html && grep -q "const SIDX_MAP" $D/home.html || { echo "patch 343 / the sector code not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_344'
<style>/* patch 344: sector ranking by NSE's own indices / size-weighted, PHARMA apart from HOSPITALS, breadth on every sector */
.sb span:has(>.gxbr)>small{display:none}
.sb .gxbr{font:600 11px ui-monospace,Menlo,monospace;color:#a3aebf;margin-left:6px;white-space:nowrap}
.sb .gxsrc{font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;margin-left:5px;padding:0 4px;border-radius:3px;background:#1b2a3a;color:#8fc3ff;vertical-align:1px}
.ssb .gxnote{font-size:11px;color:#8b97a9;margin-left:8px}
</style>
<script>/* patch 344 (Rama, 16 Nov: "our sector ranking is completely wrong - healthcare is no.1, the rotation % is wrong, do the maths"). GIR's sector % was
   the PLAIN average of its F&O shares (LAURUSLABS -7% counted as much as SUNPHARMA) and "healthcare" mixed pharma with hospitals. Now:
   · a sector with its own NSE index (BANK, IT, PHARMA, AUTO, FMCG, METAL, OIL & GAS, REALTY, CONSUMER DURABLES, CHEMICALS, CAPITAL MARKETS, MEDIA)
     shows NSE's index % (the professional, size-weighted number) for TODAY
   · every other sector, and every 15M / 30M / 1H window: the SIZE-WEIGHTED average of its F&O shares (weight = the share's futures open
     interest in ₹, all months - from GIR's live futures reader), never the plain one
   · HEALTHCARE split into PHARMA and HOSPITALS & DIAGNOSTICS · beside each sector: how many of its shares are up (11/16 ▲)
   · ROTATION uses the same numbers. */
(function(){
  const PHARMA=new Set("SUNPHARMA DRREDDY CIPLA DIVISLAB LUPIN AUROPHARMA TORNTPHARM ZYDUSLIFE ALKEM GLENMARK BIOCON LAURUSLABS GRANULES IPCALAB ABBOTINDIA MANKIND PPLPHARMA NATCOPHARM AJANTPHARM SYNGENE GLAND".split(" "));
  const IDX=[[/^banks?$/,"NIFTY BANK"],[/^psu bank/,"NIFTY PSU BANK"],[/^private bank/,"NIFTY PVT BANK"],[/^it$|technolog/,"NIFTY IT"],[/^pharma$/,"NIFTY PHARMA"],[/^auto/,"NIFTY AUTO"],[/^fmcg/,"NIFTY FMCG"],[/metal|mining/,"NIFTY METAL"],
    [/oil|gas/,"NIFTY OIL AND GAS"],[/^realty/,"NIFTY REALTY"],[/consumer d/,"NIFTY CONSR DURBL"],[/chemical/,"NIFTY CHEMICALS"],[/capital m/,"NIFTY CAPITAL MKT"],[/^media/,"NIFTY MEDIA"]];
  const HOSP="hospitals & diagnostics";
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let W={}, WT=0;
  async function weights(){ if(Date.now()-WT<120000) return; WT=Date.now();
    try{ const r=await fetch("futx?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(!r.ok) return; const v=await r.json(); const w={};
      Object.entries(v.rows||{}).forEach(([s,x])=>{ let t=0; (x.months||[]).forEach(m=>{ if(m.oi&&m.px) t+=m.oi*m.px; }); if(t>0) w[s]=t; }); if(Object.keys(w).length>20) W=w; }catch(e){} }
  window.gxSecW=()=>W;
  const idxOf=name=>{ const n=String(name||"").toLowerCase(), m=IDX.find(([re])=>re.test(n)); const S=(typeof MK!=="undefined"&&MK&&MK.sidx)||{}; return m&&S[m[1]]&&S[m[1]].chg!=null?{n:m[1],chg:+S[m[1]].chg}:null; };
  function wavg(pairs){ let a=0,b=0,n=0; pairs.forEach(([c,s])=>{ if(c==null) return; const w=W[s]||0; if(w>0){ a+=c*w; b+=w; } n++; });
    if(b>0) return a/b; if(!n) return null; return pairs.reduce((x,[c])=>x+(c||0),0)/n; }
  function tapeMap(){ const m={}; ((typeof TAPE!=="undefined"&&TAPE)||[]).forEach(r=>{ if(r.chg!=null) m[r.s]=r.chg; }); return m; }
  function split(list){ const out=[]; (list||[]).forEach(x=>{ if(/^health/i.test(String(x.name))&&(x.syms||[]).length){
        const ph=x.syms.filter(s=>PHARMA.has(s)), ho=x.syms.filter(s=>!PHARMA.has(s));
        if(ph.length) out.push(Object.assign({},x,{name:"pharma",syms:ph,n:ph.length}));
        if(ho.length) out.push(Object.assign({},x,{name:HOSP,syms:ho,n:ho.length})); }
      else out.push(x); }); return out; }
  function build(base, symsOf){ const T=tapeMap(); const L=split(base.map(x=>Object.assign({},x,{syms:x.syms||symsOf(x.name)||[]})));
    L.forEach(x=>{ const pairs=(x.syms||[]).filter(s=>T[s]!=null).map(s=>[T[s],s]); const ix=idxOf(x.name), wa=wavg(pairs);
      x.gx_up=pairs.filter(p=>p[0]>0).length; x.gx_n=pairs.length;
      if(pairs.length){ const so=pairs.slice().sort((a,b)=>b[0]-a[0]); x.top={s:so[0][1],chg:so[0][0]}; x.bot={s:so[so.length-1][1],chg:so[so.length-1][0]}; }   /* its own movers (a split group keeps no stray share) */
      if(ix){ x.chg=ix.chg; x.gx_src="NSE"; x.gx_ix=ix.n; } else if(wa!=null){ x.chg=Math.round(wa*100)/100; x.gx_src="WTD"; }
      if(x.n==null) x.n=(x.syms||[]).length; });
    L.__gx=true; return L; }
  let SB=null, MB=null;
  function fixAll(){ try{
      if(typeof SECS!=="undefined"&&Array.isArray(SECS)){ if(!SECS.__gx) SB=SECS; if(SB) SECS=build(SB,()=>null); }
      if(typeof MK!=="undefined"&&MK&&Array.isArray(MK.sectors)){ if(!MK.sectors.__gx) MB=MK.sectors; if(MB){ const sy=n=>{ const s=(SB||[]).find(x=>x.name===n); return s?s.syms:null; }; MK.sectors=build(MB,sy); } }
    }catch(e){} }
  function decorate(){ try{ const box=document.getElementById("mk-don"); if(!box) return; const L=(MK&&MK.sectors)||[];
      box.querySelectorAll(".sb").forEach(el=>{ const m=(el.getAttribute("onclick")||"").match(/mkSec\('(.+)'\)/); if(!m) return; const nm=m[1].replace(/&amp;/g,"&"); const x=L.find(s=>s.name===nm)||(SECS||[]).find(s=>s.name===nm); if(!x) return;
        const sp=el.querySelector("span"); if(sp&&!sp.querySelector(".gxbr")){ const b=document.createElement("span"); b.className="gxbr"; b.textContent=x.gx_n?`${x.gx_up}/${x.gx_n} ▲`:""; sp.appendChild(b);
          if(x.gx_src==="NSE"){ const t=document.createElement("span"); t.className="gxsrc"; t.textContent="NSE"; sp.appendChild(t); } }
        el.title=`${nm}: ${x.gx_src==="NSE"?"NSE's own index "+x.gx_ix+" (size-weighted)":"size-weighted average of its "+(x.gx_n||x.n)+" F&O shares (weight = futures open interest in ₹)"} · ${x.gx_up||0} of ${x.gx_n||0} shares up`; });
      const s=box.querySelector(".ssb"); if(s&&!s.querySelector(".gxnote")){ const n=document.createElement("span"); n.className="gxnote"; n.textContent="NSE = NSE's own sector index · others size-weighted · 11/16 ▲ = shares up"; s.appendChild(n); } }catch(e){} }
  if(typeof drawMarket==="function"){ const O=drawMarket; drawMarket=function(){ fixAll(); const r=O.apply(this,arguments); decorate(); return r; }; Object.keys(O).forEach(k=>{ try{ drawMarket[k]=O[k]; }catch(e){} });
    Object.defineProperty(drawMarket,"force",{get(){ return O.force; },set(v){ O.force=v; }}); }
  if(typeof drawSecs==="function"){ const O=drawSecs; drawSecs=function(){ fixAll(); return O.apply(this,arguments); }; }
  if(typeof rotGroups==="function"){ const O=rotGroups; rotGroups=function(){ fixAll(); const G=O.apply(this,arguments); const B=(typeof rwBase==="function")?rwBase():null;
      (G||[]).forEach(g=>{ const ix=!B?idxOf(g.n):null, wa=wavg(g.cc||[]); if(ix) g.avg=ix.chg; else if(wa!=null) g.avg=wa; });
      return (G||[]).sort((a,b)=>b.avg-a.avg); }; }
  weights(); setInterval(weights,120000);
  setTimeout(()=>{ try{ drawMarket.force=true; drawMarket(); drawMarket.force=false; }catch(e){} },1500); })();
</script>
ADD_344
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: sector ranking by NSE indices / size-weighted, PHARMA and HOSPITALS apart")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 344 done - refresh GIR: SECTORS and ROTATION use NSE's indices (NSE tag) or size-weighted averages, with 10/26 ▲ breadth."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
