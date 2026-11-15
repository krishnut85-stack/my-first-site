#!/bin/bash
# PATCH 320 - FIXES FROM THE FULL PAGE CHECK (Rama, 15 Nov: "check each and every page, mobile and laptop"). Every tab and key was opened
#   with GIR's real pages and data (patch 316's file) at phone and laptop sizes; this patch fixes what looked unprofessional:
#   · plain trading wording: no model names ("haiku-5-5"), "🤖 CLAUDE read ..." -> "AI read: ...", "sure 70%" -> "confidence 70%",
#     no "(read in 28152s)", no "tap = its screen" notes, no "python3 windwatch.py ..." command on the cockpit
#   · the phone: NEWS headlines get the full width (the time column took half - patch 312's mistake); the charts show the main buttons
#     in 2 rows, the rest behind ⋯ MORE · the laptop: the search box says "Search share" (it was cut to "TICKER · TY")
#   · ◉ TODAY: only news with a direction in the feed (neutral headlines like exam dates or bank holidays were not about the share)
#   Edits home.html and cockpit.html, replaces today.html (only patch 317's copy). No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 320" $D/home.html && grep -q "patch 320" $D/cockpit.html && grep -q "patch 314 + 317 + 320" $D/today.html; then echo "patch 320 - already in"; exit 0; fi
grep -q "patch 319" $D/home.html || { echo "patch 319 first"; exit 1; }
[ "$(sha256sum $D/today.html | cut -c1-64)" = "de6a336309a5e6fc4a3d6b24ffdfa1eb3ec2c81cb1521c87918d97c611edea2d" ] || { echo "today.html is not patch 317's copy - nothing done, send this to Claude"; exit 1; }
F="home.html cockpit.html today.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/home320.html <<'ADD_H'
<style>/* patch 320: the full page check (every tab, laptop and phone) - fixes */
@media(max-width:899px){
  html body #q-nws .bd table{table-layout:auto !important}
  html body #q-nws .bd td:first-child{width:1% !important;white-space:nowrap !important;padding-right:8px !important;vertical-align:top}
  body:not(.phx-all) .ptb a.phx{display:none !important}
  .ptb a.phmore{font-weight:700 !important;letter-spacing:.1em !important}
}
@media(min-width:900px){ .ptb a.phmore{display:none !important} }
</style>
<script>/* patch 320: plain trading wording instead of internal notes (no model names, no "tap = ..." notes); the phone charts show the main
   buttons, the rest behind ⋯; the search box says "Search share" on the laptop too */
(function(){
  const RULES=[[/🤖 CLAUDE read the full story: /g,"AI read: "],[/🤖 CLAUDE read the headline only \(the page could not be read\): /g,"AI read (headline only): "],
    [/🤖 CLAUDE /g,"AI "],[/\s*·\s*(?:haiku|sonnet|opus|fable)[\w.-]*/gi,""],[/\s*\(read in \d+s\)/g,""],[/ · sure (\d+)%/g," · confidence $1%"],
    [/(?:\s*·\s*|^\s*)tap (?:a share |a label |again |a row |a box )?= ?[^·\n]*/g,""],
    [/the scenario agent reads from 09:20 \(open \+ 5\)/g,"OI scenarios update from 09:20"],[/more on the page \(NEWS\)/g,"more in the NEWS tab"]];
  function clean(root){ try{ if(root.nodeType===3){ fix(root); return; } if(root.nodeType!==1||/^(SCRIPT|STYLE|TEXTAREA|INPUT)$/.test(root.tagName)) return;
      const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT); let n; while((n=w.nextNode())) fix(n); }catch(e){} }
  function fix(n){ const v=n.nodeValue; if(!v||v.length<6) return; let s=v; for(const [a,b] of RULES) s=s.replace(a,b); if(s!==v) n.nodeValue=s; }
  const ADV=new Set(["HEIKIN-ASHI","BARS","SMA 50","BOLL","BB","MARKS","MACD","BREADTH","─ LINE","— LINE","/ TREND","─","—","✕","×","⛶","⤢","TICK","OI"]);
  function tools(){ if(window.innerWidth>=900) return; document.querySelectorAll(".ptb").forEach(tb=>{
      tb.querySelectorAll("a").forEach(a=>{ if(!a.classList.contains("phmore")&&ADV.has(a.textContent.trim())) a.classList.add("phx"); });
      if(tb.querySelector("a.phx")&&!tb.querySelector("a.phmore")){ const m=document.createElement("a"); m.className="phmore"; m.textContent=document.body.classList.contains("phx-all")?"LESS":"⋯ MORE";
        m.onclick=e=>{ e.stopPropagation(); document.body.classList.toggle("phx-all"); document.querySelectorAll(".ptb a.phmore").forEach(x=>x.textContent=document.body.classList.contains("phx-all")?"LESS":"⋯ MORE"); };
        (tb.lastElementChild||tb).appendChild(m); } }); }
  let busy=false;
  try{ new MutationObserver(ms=>{ if(busy) return; busy=true; try{ ms.forEach(m=>{ if(m.type==="characterData") fix(m.target); else m.addedNodes.forEach(clean); }); tools(); }finally{ busy=false; } })
      .observe(document.body,{childList:true,subtree:true,characterData:true}); }catch(e){}
  clean(document.body); tools();
  try{ const q=document.getElementById("q"); if(q) q.placeholder="Search share"; }catch(e){}
})();
</script>
ADD_H
cat > $W/cockpit320.html <<'ADD_C'
<script>/* patch 320: the cockpit in plain wording - no command lines, no internal notes */
(function(){
  const RULES=[[/no shares to watch yet - add yours: python3 windwatch\.py view SYMBOL up\|down · GIR adds its own (.+?) shares as they come/g,"No shares on watch yet - add one with ➕ watch on the CHECKLIST page; GIR adds its own $1 movers as they come"],
    [/(?:\s*·\s*|^\s*)tap (?:a share |a box )?= ?[^·\n]*/g,""],[/\s*·\s*(?:haiku|sonnet|opus|fable)[\w.-]*/gi,""]];
  function fix(n){ const v=n.nodeValue; if(!v||v.length<6) return; let s=v; for(const [a,b] of RULES) s=s.replace(a,b); if(s!==v) n.nodeValue=s; }
  function clean(r){ try{ if(r.nodeType===3) return fix(r); if(r.nodeType!==1) return; const w=document.createTreeWalker(r,NodeFilter.SHOW_TEXT); let n; while((n=w.nextNode())) fix(n); }catch(e){} }
  try{ new MutationObserver(ms=>ms.forEach(m=>{ if(m.type==="characterData") fix(m.target); else m.addedNodes.forEach(clean); })).observe(document.body,{childList:true,subtree:true,characterData:true}); }catch(e){}
  clean(document.body); })();
</script>
ADD_C
cat > $W/today.html <<'HTML_TODAY'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Today</title>
<style>
:root{--bg:#06080c;--panel:#0c1118;--panel2:#111823;--line:#1c2532;--line2:#273244;--text:#e6edf3;--dim:#8592a3;--mut:#5d6878;
  --up:#26c281;--dn:#f0544f;--am:#f5a623;--blue:#4c9aff;--mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;--ui:-apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--text);font:13px/1.4 var(--ui)}
a{color:inherit;text-decoration:none}.num{font-family:var(--mono);font-variant-numeric:tabular-nums}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}.mut{color:var(--mut)}
/* top bar */
#bar{position:sticky;top:0;z-index:10;background:#080b10;border-bottom:1px solid var(--line)}
.r1{display:flex;align-items:center;gap:14px;padding:8px 14px;flex-wrap:wrap}
.brand{font:700 14px/1 var(--mono);letter-spacing:.12em;color:#1a1205;background:var(--am);padding:6px 10px;border-radius:4px}
.ttl{font:600 13px var(--ui);letter-spacing:.14em;color:var(--dim)}
.st{font:600 11px var(--mono);letter-spacing:.08em;padding:3px 8px;border-radius:3px;border:1px solid var(--line2);color:var(--dim)}
.st.live{color:var(--up);border-color:#1d5c42}.st.live::before{content:"● "}
.ix{display:flex;align-items:baseline;gap:6px;padding:0 10px;border-left:1px solid var(--line)}
.ix .n{font:600 11px var(--mono);color:var(--dim);letter-spacing:.06em}.ix .p{font:600 14px var(--mono)}
.chip{font:700 10.5px var(--mono);letter-spacing:.06em;padding:2px 6px;border-radius:3px;white-space:nowrap}
.c-RISING{background:#0d3324;color:var(--up)}.c-FALLING{background:#3a1416;color:var(--dn)}.c-SIDEWAYS{background:#3a2c10;color:var(--am)}
.nav{margin-left:auto;display:flex;gap:6px}.nav a{font:600 11px var(--mono);letter-spacing:.06em;padding:5px 9px;border:1px solid var(--line2);border-radius:4px;color:var(--dim)}
.nav a:hover{color:var(--text);border-color:var(--dim)}
.r2{display:flex;gap:18px;padding:6px 14px;border-top:1px solid var(--line);font:12px var(--mono);color:var(--dim);flex-wrap:wrap}
.r2 b{font-weight:700}.rules{margin-left:auto;color:var(--mut)}
/* layout */
main{display:grid;grid-template-columns:minmax(0,1.7fr) minmax(0,1fr);gap:12px;padding:12px 14px 30px;max-width:1500px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;min-width:0}
.hd{display:flex;align-items:center;gap:10px;padding:9px 12px;border-bottom:1px solid var(--line)}
.hd h2{margin:0;font:700 11.5px var(--mono);letter-spacing:.14em;white-space:nowrap}
#wlb{overflow-x:auto}.hd .sub{color:var(--mut);font-size:11.5px}
.hd .flt{margin-left:auto;display:flex;gap:4px}.flt a{font:600 10.5px var(--mono);letter-spacing:.06em;padding:3px 8px;border-radius:3px;color:var(--dim);cursor:pointer;border:1px solid transparent}
.flt a.on{color:var(--text);border-color:var(--line2);background:var(--panel2)}
/* act-now strip */
#act{grid-column:1/-1}#act .bd{display:flex;gap:8px;padding:10px 12px;overflow-x:auto}
.ac{flex:none;min-width:230px;border:1px solid #1d5c42;background:#0b1a14;border-radius:5px;padding:8px 10px}
.ac.pe{border-color:#5c1d1f;background:#1a0c0d}.ac .s{font:700 14px var(--mono)}.ac .l{font-size:12px;color:var(--dim);margin-top:2px}
.empty{padding:14px 12px;color:var(--mut);font-size:12.5px}
/* watchlist table */
table{width:100%;border-collapse:collapse}th{font:600 10.5px var(--mono);letter-spacing:.08em;color:var(--mut);text-align:left;padding:7px 8px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:middle;white-space:nowrap}tr:hover td{background:#0f1520}
td.r,th.r{text-align:right}td.c-lv,td.c-fu,td.c-en{white-space:normal;min-width:110px}td.c-lv .mut{display:block;font-size:11px}.sym{font:700 13px var(--mono)}.sym a:hover{text-decoration:underline}
.sd{font:700 10.5px var(--mono);padding:2px 6px;border-radius:3px}.sd.CE{background:#0d3324;color:var(--up)}.sd.PE{background:#3a1416;color:var(--dn)}
.sg{font:700 10.5px var(--mono);letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:var(--panel2);color:var(--dim)}
.sg.at{background:#3a2c10;color:var(--am)}.sg.live{background:#0d3324;color:var(--up)}.sg.target{background:#0d3324;color:var(--up)}.sg.out,.sg.broke{background:#3a1416;color:var(--dn)}
.wf{display:flex;gap:6px 14px;flex-wrap:wrap;align-items:center;padding:8px 12px;border-bottom:1px solid var(--line)}
.wf .g{display:flex;gap:3px;align-items:center}.wf .lb{font:600 10px var(--mono);letter-spacing:.08em;color:var(--mut);margin-right:3px}
.wf a{font:600 10.5px var(--mono);letter-spacing:.04em;padding:4px 8px;border-radius:3px;color:var(--dim);cursor:pointer;border:1px solid var(--line2);white-space:nowrap}
.wf a.on{color:#1a1205;background:var(--am);border-color:var(--am)}.wf a.pe.on{background:var(--dn);border-color:var(--dn);color:#fff}.wf a.ce.on{background:var(--up);border-color:var(--up);color:#04140c}
tr.grp td{font:600 10.5px var(--mono);letter-spacing:.1em;color:var(--mut);background:#0a0e14;padding:6px 10px}
/* feed */
.feed{max-height:calc(100vh - 170px);overflow-y:auto}.ev{display:grid;grid-template-columns:44px 22px minmax(0,1fr);gap:8px;padding:8px 12px;border-bottom:1px solid var(--line)}
.ev .t{font:12px var(--mono);color:var(--mut)}.ev .i{text-align:center}.ev .x{min-width:0;overflow-wrap:anywhere}.ev .x b{font-family:var(--mono)}
.ev .m{color:var(--dim);font-size:12px;margin-top:1px}.ev a.h:hover{text-decoration:underline}
.mkt{border-top:1px solid var(--line)}.mkt .hd{border-bottom:0;padding-bottom:4px}
@media(min-width:900px) and (max-width:1279px){main{grid-template-columns:1fr}.feed{max-height:none}}
/* phone */
@media(max-width:899px){
  .r1{gap:6px 8px;padding:7px 10px}.ix{padding:0;border-left:0;width:100%;flex-wrap:nowrap;white-space:nowrap;overflow:hidden}.ix .p{font-size:13px}.ix .mut{font-size:11px;overflow:hidden;text-overflow:ellipsis}
  #act .hd .sub{display:none}.nav{margin-left:0;width:100%}.nav a{flex:1;text-align:center}
  .r2{gap:10px;padding:5px 10px;font-size:11.5px}.rules{margin-left:0;width:100%}
  main{grid-template-columns:1fr;padding:8px 8px 30px;gap:8px}
  .wl table,.wl thead,.wl tbody,.wl tr,.wl td{display:block;width:100%}.wl thead{display:none}
  .wl tr{display:grid;grid-template-columns:auto auto 1fr auto;gap:4px 8px;padding:9px 10px;border-bottom:1px solid var(--line);align-items:center}
  .wl td{padding:0;border:0;white-space:normal}.wl td.c-px{grid-column:4;text-align:right}
  .wl td.c-lv,.wl td.c-vw,.wl td.c-fu,.wl td.c-en{grid-column:1/-1;font-size:12px;color:var(--dim)}
  .wl td[data-k]::before{content:attr(data-k) " ";color:var(--mut);font:600 10px var(--mono);letter-spacing:.06em}
  .wl tr.grp{display:block}.wl td.nil{display:none}
  .wf{padding:8px 10px;gap:6px 10px}.wf a{padding:5px 8px}.feed{max-height:none}
}
</style></head><body>
<div id="bar"><div class="r1"><a class="brand" href="./" id="home">GIR</a><span class="ttl">TODAY</span><span class="st" id="mst">—</span>
  <span class="ix" id="ixn"></span><span class="ix" id="ixb"></span>
  <span class="nav"><a id="lck" href="checklist">CHECKLIST</a><a id="lco" href="cockpit">COCKPIT</a><a id="lho" href="./">GIR</a></span></div>
  <div class="r2" id="cnt"></div></div>
<main>
  <section class="card" id="act"><div class="hd"><h2>ACT NOW</h2><span class="sub">entries live on your checklist - confirm on the cockpit, then trade</span></div><div class="bd" id="actb"></div></section>
  <section class="card wl"><div class="hd"><h2>WATCHLIST</h2><span class="sub" id="wls">tonight's checklist, live every 3 s</span></div><div class="wf" id="wf"></div><div id="wlb"></div></section>
  <section class="card"><div class="hd"><h2>FEED</h2><span class="flt" id="flt"></span></div><div class="feed" id="feed"></div>
    <div class="mkt"><div class="hd"><h2>MARKET HEADLINES</h2><span class="sub">latest 5</span></div><div id="mkt"></div></div></section>
</main>
<script>
/* patch 314 + 317 + 320: ◉ TODAY - one screen for the trading day: the checklist live (patch 303), the cockpit's NIFTY / 👀 / 🧱 (patch 285-299),
   GIR's alerts and news for your checklist shares only, market headlines apart. Reads only - nothing here changes GIR. */
const Q=location.search, K=new URLSearchParams(Q).get("k")||"";
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const f2=v=>v==null||isNaN(v)?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
const pc=v=>v==null||isNaN(v)?"—":(v>0?"+":"")+Number(v).toFixed(2)+"%";
const cl=v=>v>0?"up":v<0?"dn":"dim";
function hmOf(v){ if(v==null||v==="") return ""; if(typeof v==="number"){ const d=new Date((v>2e10?v:v*1000)+19800000); return d.toISOString().slice(11,16); }
  const m=String(v).match(/(\d{1,2}):(\d{2})/); return m?m[1].padStart(2,"0")+":"+m[2]:""; }
function shareURL(s){ const u=new URLSearchParams(Q); u.set("w",s); return "./?"+u.toString(); }
["lck","lco","lho","home"].forEach(id=>{ const a=document.getElementById(id); a.href=a.getAttribute("href")+Q; });
let CL=null, LV=null, CK=null, HM=null, FLT="all", WS={side:"all",stage:"all",sort:"near"};
try{ FLT=localStorage.getItem("gir_today_f")||"all"; WS=Object.assign(WS,JSON.parse(localStorage.getItem("gir_today_w")||"{}")); }catch(e){}
function setW(k,v){ WS[k]=v; try{ localStorage.setItem("gir_today_w",JSON.stringify(WS)); }catch(e){} wl(); }
const STG={wait:"WAITING",at:"AT LEVEL",live:"ENTRY LIVE",target:"TARGET",out:"STOPPED",broke:"INVALID",closed:"CLOSED"};
const DONE=new Set(["target","out","broke","closed"]);
function items(){ const seen=new Set(), A=[]; if(!CL) return A;
  ["pe","ce","retest","breakout","breakdown"].forEach(k=>(CL[k]||[]).forEach(x=>{ const key=x.s+"|"+x.side; if(!seen.has(key)){ seen.add(key); A.push(x); } })); return A; }
function lvOn(){ return !!(LV&&LV.live&&CL&&LV.day>CL.day); }
function L_(x){ return lvOn()?LV.live[x.s+"|"+x.side]||null:null; }
function lvl(x){ const pe=x.side==="PE"; return x.kind==="breakdown"?x.floor:(x.kind==="breakout"||pe)?x.roof:x.floor; }
function mstat(){ const d=new Date(Date.now()+19800000), hm=d.toISOString().slice(11,16), wd=d.getUTCDay();
  const open=wd>0&&wd<6&&hm>="09:15"&&hm<"15:30"; const el=document.getElementById("mst");
  el.textContent=open?"MARKET OPEN "+hm:wd>0&&wd<6&&hm<"09:15"?"PRE-MARKET "+hm:"MARKET CLOSED"; el.className="st"+(open?" live":""); }
function bar(){ mstat();
  const ix=(id,n,x)=>{ const el=document.getElementById(id); if(!x){ el.innerHTML=`<span class="n">${n}</span><span class="mut">from 09:15</span>`; return; }
    el.innerHTML=`<span class="n">${n}</span><span class="p num">${f2(x.px)}</span><span class="chip c-${esc(x.state)}">${x.state==="RISING"?"▲":x.state==="FALLING"?"▼":"↔"} ${esc(x.state)}</span><span class="mut num">${x.since?"since "+esc(String(x.since).slice(0,5)):""}${x.p15!=null?" · 15m "+pc(x.p15):""}</span>`; };
  ix("ixn","NIFTY",CK&&CK.nifty); ix("ixb","BANKNIFTY",CK&&CK.bank);
  const A=items().map(L_).filter(Boolean), n=s=>A.filter(l=>l.state===s).length, dn=A.filter(l=>DONE.has(l.state));
  const res=dn.filter(l=>l.res!=null), w=res.filter(l=>l.res>0).length;
  document.getElementById("cnt").innerHTML=!CL?'<span>checklist not made yet - GIR makes it every market evening at 19:15</span>':
    `<span><b class="up">${n("live")}</b> ENTRY LIVE</span><span><b class="am">${n("at")}</b> AT LEVEL</span><span><b>${lvOn()?n("wait"):items().length}</b> WAITING</span><span><b>${dn.length}</b> DONE${res.length?` · ${w}/${res.length} positive`:""}</span>
     <span class="mut">${lvOn()?"live "+esc(LV.hm||""):"live stages from 09:20"} · list of ${esc(CL.day||"")}</span><span class="rules">after 09:30 · half size · stop after 2 losses · out by 15:15</span>`; }
function act(){ const A=items().filter(x=>{ const l=L_(x); return l&&l.state==="live"; }); const el=document.getElementById("actb");
  el.innerHTML=A.length?A.map(x=>{ const l=L_(x), w=lvl(x), pe=x.side==="PE", tg=l.entry_px*(1+(pe?-0.02:0.02));
    return `<a class="ac ${pe?"pe":""}" href="${shareURL(x.s)}" target="_blank"><div><span class="s">${esc(x.s)}</span> <span class="sd ${x.side}">${pe?"▼ PE":"▲ CE"}</span> <span class="num ${cl(l.move)}">${pc(l.move)}</span></div>
      <div class="l num">in ${esc(l.entry_t)} @ ${f2(l.entry_px)} · LTP ${f2(l.px)}</div><div class="l num">target ${f2(tg)} · stop: close ${pe?"above":"below"} ${w?f2(w.k):"—"}</div></a>`; }).join("")
   :`<div class="empty">${lvOn()?"No live entry right now. The watchlist shows who is at the level.":"Nothing live yet - entries appear here from 09:20 on a market day."}</div>`; }
function wl(){ const el=document.getElementById("wlb"); if(!CL){ el.innerHTML='<div class="empty">The checklist is made every market evening at 19:15.</div>'; return; }
  const pri={live:0,at:1,wait:2}; const ALL=items().map(x=>({x,l:L_(x)}));
  const dist=o=>{ const w=lvl(o.x); return o.l&&w?Math.abs(o.l.px/w.k-1)*100:w?w.dist:99; };
  const st_=o=>o.l?o.l.state:"wait", cnt=f=>ALL.filter(f).length;
  const A=ALL.filter(o=>(WS.side==="all"||o.x.side===WS.side)&&(WS.stage==="all"||st_(o)===WS.stage||(WS.stage==="done"&&DONE.has(st_(o)))));
  const by=WS.sort==="score"?(a,b)=>(b.x.score||0)-(a.x.score||0):WS.sort==="az"?(a,b)=>a.x.s.localeCompare(b.x.s):(a,b)=>dist(a)-dist(b);
  const open=A.filter(o=>!o.l||!DONE.has(o.l.state)).sort(by).sort((a,b)=>(pri[st_(a)]??2)-(pri[st_(b)]??2)), done=A.filter(o=>o.l&&DONE.has(o.l.state));
  const G=(k,L)=>L.map(([v,t,c])=>`<a class="${c||""}${WS[k]===v?" on":""}" onclick="setW('${k}','${v}')">${t}</a>`).join("");
  document.getElementById("wf").innerHTML=`<span class="g"><span class="lb">SIDE</span>${G("side",[["all","ALL "+ALL.length],["PE","▼ PE "+cnt(o=>o.x.side==="PE"),"pe"],["CE","▲ CE "+cnt(o=>o.x.side==="CE"),"ce"]])}</span>`+
    `<span class="g"><span class="lb">STAGE</span>${G("stage",[["all","ALL"],["live","LIVE "+cnt(o=>st_(o)==="live")],["at","AT LEVEL "+cnt(o=>st_(o)==="at")],["wait","WAITING "+cnt(o=>st_(o)==="wait")],["done","DONE "+cnt(o=>DONE.has(st_(o)))]])}</span>`+
    `<span class="g"><span class="lb">SORT</span>${G("sort",[["near","CLOSEST"],["score","SCORE"],["az","A-Z"]])}</span>`;
  const row=({x,l})=>{ const w=lvl(x), pe=x.side==="PE", st=l?l.state:"wait";
    const dist=l&&w?Math.abs(l.px/w.k-1)*100:w?w.dist:null;
    const vw=l&&l.vside!=null?`<span class="${(l.vside>0)===!pe?"up":"dn"}">${l.vside>0?"above":"below"} ${f2(l.vwap)}</span>`:'<span class="mut">—</span>';
    const fu=l&&l.kind_now?`<span class="${(l.kind_now==="SHORT BUILD-UP"||l.kind_now==="LONG UNWINDING")===pe?"up":"dn"}">${esc(l.kind_now.toLowerCase())}</span> <span class="mut num">${pc(l.doi)}</span>`:'<span class="mut">—</span>';
    const en=l&&l.entry_t?`<span class="num">${esc(l.entry_t)} @ ${f2(l.entry_px)}</span>${l.res!=null?` → <b class="num ${cl(l.res)}">${pc(l.res)}</b>`:l.move!=null?` · <span class="num ${cl(l.move)}">${pc(l.move)}</span>`:""}`:l&&l.note&&DONE.has(st)?`<span class="mut">${esc(l.note)}</span>`:'<span class="mut">—</span>';
    return `<tr><td class="sym"><a href="${shareURL(x.s)}" target="_blank">${esc(x.s)}</a></td><td><span class="sd ${x.side}">${x.side}</span></td><td><span class="sg ${st}">${STG[st]||esc(st)}</span></td>
      <td class="r num c-px">${l?f2(l.px):f2(x.px)} <span class="${cl(l?l.chg:x.chg)}">${pc(l?l.chg:x.chg)}</span></td>
      <td class="num c-lv" data-k="LEVEL">${w?`${x.kind==="breakout"||(!x.kind&&pe)?"R":"S"} ${f2(w.k)} <span class="mut">${dist!=null?dist.toFixed(2)+"% away":""}</span>`:'<span class="mut">no wall within 15%</span>'}</td>
      <td class="num c-vw${l&&l.vside!=null?"":" nil"}" data-k="VWAP">${vw}</td><td class="c-fu${l&&l.kind_now?"":" nil"}" data-k="FUT">${fu}</td><td class="c-en${en.includes("—")&&!(l&&(l.entry_t||l.note))?" nil":""}" data-k="ENTRY">${en}</td></tr>`; };
  el.innerHTML=`<table><thead><tr><th>SYMBOL</th><th>SIDE</th><th>STAGE</th><th class="r">LTP</th><th>LEVEL</th><th>VWAP</th><th>FUTURES</th><th>ENTRY / RESULT</th></tr></thead><tbody>
    ${open.length||done.length?"":`<tr><td colspan="8" class="empty">nothing with these filters</td></tr>`}${open.map(row).join("")}${done.length?`<tr class="grp"><td colspan="8">CLOSED TODAY · ${done.length}</td></tr>`+done.map(row).join(""):""}</tbody></table>`;
  document.getElementById("wls").textContent=`${A.length} of ${ALL.length} shares · live every 3 s`; }
function events(){ const set=new Set(items().map(x=>x.s)), E=[];
  if(lvOn()) items().forEach(x=>{ const k=x.s+"|"+x.side, l=LV.live[k], st=(LV.st||{})[k]||{}; if(!l) return; const pe=x.side==="PE", w=lvl(x);
    if(st.near_t) E.push({t:hmOf(st.near_t),i:"👀",k:"sig",s:x.s,c:"am",h:`at ${pe?"resistance":"support"} ${w?f2(w.k):""}`,m:`${x.side} setup - watch for the turn ${pe?"below":"above"} VWAP`});
    if(l.entry_t) E.push({t:l.entry_t,i:"✅",k:"sig",s:x.s,c:"up",h:`${x.side} entry live @ ${f2(l.entry_px)}`,m:l.note||""});
    if(l.done_t) E.push({t:l.done_t,i:l.state==="target"?"✔":l.state==="closed"?"⏹":"✖",k:"sig",s:x.s,c:l.state==="target"?"up":l.state==="closed"?"dim":"dn",h:`${STG[l.state]||l.state}${l.res!=null?" "+pc(l.res):""}`,m:l.note||""}); });
  ((CK&&CK.wm)||[]).forEach(x=>{ if(!x||!x.s) return; const watch=/watch/i.test(x.note||""); E.push({t:hmOf(x.t),i:watch?"👀":"🧱",k:"sig",s:x.s,c:x.dir>0?"up":"dn",
    h:`${x.dir>0?"CE":"PE"} · ${watch?"at the wall":"futures + wall"}${set.has(x.s)?"":" · not on your checklist"}`,m:[x.px!=null?"₹"+f2(x.px):"",x.doi!=null?"fut OI "+pc(x.doi):"",x.note&&!watch?x.note:""].filter(Boolean).join(" · ")}); });
  ((HM&&HM.now)||[]).forEach(r=>{ if(!r||!set.has(r.s)) return; E.push({t:hmOf(r.t),i:"🔔",k:"sig",s:r.s,c:r.side==="CE"?"up":r.side==="PE"?"dn":"dim",h:String(r.head||"").slice(0,140),m:""}); });
  ((HM&&HM.news)||[]).forEach(x=>{ if(!x||!set.has(x.s)||!x.side) return;   /* patch 320: only news with a direction (a neutral headline is usually not about the share) */ E.push({t:hmOf(x.hm||x.t),i:"📰",k:"news",s:x.s,c:x.side>0?"up":x.side<0?"dn":"dim",h:x.h||"",u:x.u||x.url||"",m:x.why||""}); });
  const seen=new Set(); return E.filter(e=>{ const k=e.t+e.s+e.h; if(seen.has(k)) return false; seen.add(k); return true; }).sort((a,b)=>String(b.t).localeCompare(String(a.t))); }
function feed(){ const E=events(), F=[["all","ALL"],["sig","SIGNALS"],["news","NEWS"]];
  document.getElementById("flt").innerHTML=F.map(f=>`<a class="${FLT===f[0]?"on":""}" onclick="setF('${f[0]}')">${f[1]} ${f[0]==="all"?E.length:E.filter(e=>e.k===f[0]).length}</a>`).join("");
  const L=E.filter(e=>FLT==="all"||e.k===FLT).slice(0,80);
  document.getElementById("feed").innerHTML=L.length?L.map(e=>`<div class="ev"><span class="t">${esc(e.t||"")}</span><span class="i">${e.i}</span><div class="x"><a href="${shareURL(e.s)}" target="_blank"><b class="${e.c}">${esc(e.s)}</b></a> ${e.u?`<a class="h" href="${esc(e.u)}" target="_blank" rel="noopener noreferrer">${esc(e.h)} ↗</a>`:esc(e.h)}${e.m?`<div class="m">${esc(e.m)}</div>`:""}</div></div>`).join("")
    :'<div class="empty">Nothing yet. Signals and news for your checklist shares appear here, newest first.</div>';
  const M=((HM&&HM.news)||[]).filter(x=>x&&(x.s==="MARKET"||!x.s)).slice(0,5);
  document.getElementById("mkt").innerHTML=M.length?M.map(x=>`<div class="ev"><span class="t">${esc(hmOf(x.hm||x.t))}</span><span class="i">🏛</span><div class="x">${x.u?`<a class="h" href="${esc(x.u)}" target="_blank" rel="noopener noreferrer">${esc(x.h)} ↗</a>`:esc(x.h||"")}${x.why?`<div class="m">${esc(x.why)}</div>`:""}</div></div>`).join(""):'<div class="empty">No market headlines yet.</div>'; }
function setF(f){ FLT=f; try{ localStorage.setItem("gir_today_f",f); }catch(e){} feed(); }
function paint(){ try{ bar(); act(); wl(); feed(); }catch(e){ console.error(e); } }
async function get(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pLive(){ const j=await get("checklistlive"+Q); if(j) LV=j; paint(); }
async function pList(){ const j=await get("checklistdata"+Q); if(j&&j.day) CL=j; paint(); }
async function pCk(){ const j=await get("cockpitdata"+Q); if(j) CK=j; }
async function pHome(){ const j=await get("home"+(K?"?k="+encodeURIComponent(K):"")); if(j) HM=j; }
pList(); pCk(); pHome().then(paint); pLive();
setInterval(()=>{ if(!document.hidden) pLive(); },3000); setInterval(()=>{ if(!document.hidden) pCk(); },5000);
setInterval(()=>{ if(!document.hidden) pHome(); },10000); setInterval(()=>{ if(!document.hidden) pList(); },300000); setInterval(mstat,30000);
</script></body></html>
HTML_TODAY
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
for f, a in (("home.html", "home320.html"), ("cockpit.html", "cockpit320.html")):
    p = os.path.join(D, f); t = open(p, encoding="utf-8").read()
    if "patch 320" in t:
        continue
    if t.count("</body>") != 1:
        print("❌ %s: </body> x%d - send this to Claude" % (f, t.count("</body>"))); sys.exit(1)
    open(p, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, a), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  %s: patch 320" % f)
PY_EDIT
cp $W/today.html $D/today.html || back
if command -v node >/dev/null 2>&1; then
  for f in home.html cockpit.html today.html; do
    python3 - $D/$f $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
    node --check $W/page.js 2>$W/js.err || { echo "❌ $f:"; head -5 $W/js.err; back; }
  done
  echo "  the page code checked ✓"
fi
echo "✅ patch 320 done - plain wording everywhere, phone NEWS full width, phone charts in 2 rows (⋯ MORE), laptop search fits, TODAY feed cleaner. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done"
