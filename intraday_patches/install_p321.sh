#!/bin/bash
# PATCH 321 - THE COCKPIT REDESIGNED + THE TRADE TAB CLEANED UP (Rama, 15 Nov: "go cockpit and trade" · "TODAY in 2 places - HOME first, then
#   TODAY"). Tested on GIR's real pages (patch 316's file) at phone and laptop sizes:
#   · 🎯 COCKPIT: a trader's layout - the top bar (NIFTY / BANKNIFTY rising / falling since when), 3 signal panels (🧱 PRIORITY · 📚 PLAYBOOK
#     · 📏 PUSH FOR SIZE), a card per share with a TRADE / SMALL / SKIP badge, a ✓ ! ✕ scorecard and the plan, the day's activity. Same data.
#   · TRADE: P1 / P2 / P3 -> ACT / WATCH / INFO, no formula in the EARLY header, no "rings loud · overnight kept", SOUND ON without the note;
#     the phone: the scrolling CRITICAL strip hidden (the IMPORTANT list right below has it)
#   · the phone tabs: HOME first, then TODAY; TODAY and ⌂ MARKET no longer repeated in MORE; the MORE note: "Choose a page above"
#   Replaces cockpit.html (only patch 320's copy), edits home.html. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 321" $D/home.html && grep -q "patch 321" $D/cockpit.html; then echo "patch 321 - already in"; exit 0; fi
grep -q "patch 320" $D/home.html || { echo "patch 320 first"; exit 1; }
[ "$(sha256sum $D/cockpit.html | cut -c1-64)" = "0e3cac7dcddf7f4d55b357d9004e5ae69bd00338a477f282ef175dc22b19866a" ] || { echo "cockpit.html is not patch 320's copy - nothing done, send this to Claude"; exit 1; }
F="home.html cockpit.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/cockpit.html <<'HTML_CK'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Cockpit</title>
<style>
:root{--bg:#06080c;--panel:#0c1118;--panel2:#111823;--line:#1c2532;--line2:#273244;--text:#e6edf3;--dim:#8592a3;--mut:#5d6878;
  --up:#26c281;--dn:#f0544f;--am:#f5a623;--mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;--ui:-apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--text);font:13px/1.45 var(--ui)}
a{color:inherit;text-decoration:none}.nm{font-family:var(--mono);font-variant-numeric:tabular-nums}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}.mu{color:var(--mut)}
#bar{position:sticky;top:0;z-index:10;background:#080b10;border-bottom:1px solid var(--line)}
.r1{display:flex;align-items:center;gap:12px;padding:8px 14px;flex-wrap:wrap}
.brand{font:700 14px/1 var(--mono);letter-spacing:.12em;color:#1a1205;background:var(--am);padding:6px 10px;border-radius:4px}
.ttl{font:600 13px var(--ui);letter-spacing:.14em;color:var(--dim)}
.st{font:600 11px var(--mono);letter-spacing:.06em;padding:3px 8px;border-radius:3px;border:1px solid var(--line2);color:var(--dim)}.st.live{color:var(--up);border-color:#1d5c42}.st.old{color:var(--am);border-color:#5c4410}
.ix{display:flex;align-items:baseline;gap:6px;padding:0 10px;border-left:1px solid var(--line);white-space:nowrap}
.ix .n{font:600 11px var(--mono);color:var(--dim);letter-spacing:.06em}.ix .p{font:600 14px var(--mono)}
.chip{font:700 10.5px var(--mono);letter-spacing:.06em;padding:2px 6px;border-radius:3px;white-space:nowrap}
.c-RISING{background:#0d3324;color:var(--up)}.c-FALLING{background:#3a1416;color:var(--dn)}.c-SIDEWAYS{background:#3a2c10;color:var(--am)}
.nav{margin-left:auto;display:flex;gap:6px}.nav a{font:600 11px var(--mono);letter-spacing:.06em;padding:5px 9px;border:1px solid var(--line2);border-radius:4px;color:var(--dim)}
.r2{display:flex;gap:6px 14px;padding:6px 14px;border-top:1px solid var(--line);font:12px var(--mono);color:var(--dim);flex-wrap:wrap;align-items:center}
.secs{display:flex;gap:4px;flex-wrap:wrap}.sc{font:11px var(--mono);padding:2px 6px;border-radius:3px;background:var(--panel2)}
.rules{margin-left:auto;color:var(--mut)}
main{padding:12px 14px 30px;max-width:1600px}
.sig{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-bottom:12px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;min-width:0}
.hd{display:flex;align-items:center;gap:8px;padding:8px 12px;border-bottom:1px solid var(--line)}.hd h2{margin:0;font:700 11px var(--mono);letter-spacing:.12em;white-space:nowrap}.hd .sub{color:var(--mut);font-size:11.5px}
.li{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:8px;padding:6px 12px;border-bottom:1px solid #121923;align-items:baseline}.li:last-child{border-bottom:0}
.li .s{font:700 12.5px var(--mono)}.li .m{color:var(--dim);font-size:12px;overflow-wrap:anywhere}.li .t{font:11.5px var(--mono);color:var(--mut)}
.sd{font:700 10px var(--mono);padding:2px 5px;border-radius:3px}.sd.CE{background:#0d3324;color:var(--up)}.sd.PE{background:#3a1416;color:var(--dn)}
.empty{padding:12px;color:var(--mut);font-size:12.5px}
.boxes{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:10px;margin-bottom:12px}
.bx{display:block;background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:0}.bx:hover{border-color:var(--line2)}
.bx .top{display:flex;align-items:flex-start;gap:10px;padding:10px 12px;border-bottom:1px solid var(--line)}
.bx .nmx{font:700 16px var(--mono)}.bx .px{font:600 13px var(--mono)}.bx .src{font:600 10px var(--mono);letter-spacing:.06em;color:var(--mut);margin-top:3px}
.vd{margin-left:auto;text-align:center;padding:6px 10px;border-radius:5px;font:800 12px var(--mono);letter-spacing:.04em;background:#1b222d;color:var(--dim);white-space:nowrap}
.vd small{display:block;font:600 10px var(--mono);opacity:.85;margin-top:2px}.vd.TRADE{background:#0d3324;color:var(--up)}.vd.SMALL{background:#3a2c10;color:var(--am)}.vd.SKIP{background:#3a1416;color:var(--dn)}
.ck{display:grid;grid-template-columns:16px 82px minmax(0,1fr);gap:4px 8px;padding:8px 12px;font-size:12.5px;align-items:baseline}
.ck i{font-style:normal;text-align:center;font-weight:700}.ck .k{font:600 10px var(--mono);letter-spacing:.08em;color:var(--mut)}
.pbk{margin:0 12px 8px;padding:7px 9px;border-radius:5px;background:#101722;border-left:3px solid var(--line2);font-size:12px}.pbk.hit{border-color:var(--up);background:#0d1f17}.pbk.bad{border-color:var(--dn);background:#1f0f10}
.tst{padding:0 12px 8px;font-size:12px}
.plan{margin:0 12px 12px;padding:8px 10px;border-radius:5px;background:#0d1f17;border:1px solid #1d5c42;font:600 12px var(--mono)}.plan.SMALL{background:#1f1a0d;border-color:#5c4410}
.act{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:12px}
.foot{display:flex;flex-wrap:wrap;gap:8px 18px;padding:10px 12px;font-size:12.5px}
details{padding:8px 12px}summary{cursor:pointer;font:600 11px var(--mono);letter-spacing:.08em;color:var(--dim)}ol{margin:8px 0;padding-left:22px}ol li{margin:4px 0}
@media(max-width:1100px){.sig{grid-template-columns:1fr}.act{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:899px){
  .r1{gap:6px 8px;padding:7px 10px}.ix{padding:0;border-left:0;width:100%;overflow:hidden}.ix .mu{overflow:hidden;text-overflow:ellipsis;min-width:0}.nav{margin-left:0;width:100%}.nav a{flex:1;text-align:center}
  .r2{padding:6px 10px}.rules{margin-left:0;width:100%}main{padding:8px}
  .boxes{grid-template-columns:1fr}.act{grid-template-columns:1fr}.ck{grid-template-columns:16px 70px minmax(0,1fr)}
}
</style></head><body>
<div id="bar"><div class="r1"><a class="brand" id="lb" href="./">GIR</a><span class="ttl">COCKPIT</span><span class="st" id="st">—</span>
  <span class="ix" id="ixn"></span><span class="ix" id="ixb"></span>
  <span class="nav"><a id="l1" href="today">TODAY</a><a id="l2" href="checklist">CHECKLIST</a><a id="l3" href="./">GIR</a></span></div>
  <div class="r2" id="r2"></div></div>
<main>
  <div class="sig">
    <section class="card"><div class="hd"><h2>🧱 PRIORITY</h2><span class="sub">futures + option wall + VWAP agree</span></div><div id="pri"></div></section>
    <section class="card"><div class="hd"><h2>📚 PLAYBOOK</h2><span class="sub">shares in a tested setup now</span></div><div id="pbk"></div></section>
    <section class="card"><div class="hd"><h2>📏 PUSH FOR SIZE</h2><span class="sub">new futures money vs a normal day</span></div><div id="psh"></div></section>
  </div>
  <div class="boxes" id="boxes"></div>
  <div class="act">
    <section class="card"><div class="hd"><h2>🧲 STEADY MOVES</h2></div><div id="a1"></div></section>
    <section class="card"><div class="hd"><h2>🌪 BIG MOVERS</h2></div><div id="a2"></div></section>
    <section class="card"><div class="hd"><h2>🚀 MOMENTUM ±3%</h2></div><div id="a3"></div></section>
    <section class="card"><div class="hd"><h2>⏳ MONEY LOADING</h2><span class="sub">futures in, price flat</span></div><div id="a4"></div></section>
  </div>
  <section class="card" id="ft"></section>
</main>
<script>
/* patch 321: 🎯 THE COCKPIT redesigned - a trader's layout (laptop and phone): the top bar (NIFTY / BANKNIFTY now), 3 signal panels, a card per
   share with a verdict badge and a scorecard, the day's activity. The same data as before (windwatch.py's cockpit.json), nothing dropped. */
const Q=location.search;
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const f2=v=>v==null||isNaN(v)?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
const pc=v=>v==null||isNaN(v)?"":(v>0?"+":"")+Number(v).toFixed(2)+"%";
const cl=v=>v>0?"up":v<0?"dn":"dim";
function shareURL(s){ const u=new URLSearchParams(Q); u.set("w",s); return "./?"+u.toString(); }
const sl=s=>`<a href="${shareURL(s)}" target="_blank">${esc(s)}</a>`;
const side=d=>`<span class="sd ${d>0?"CE":"PE"}">${d>0?"▲ CE":"▼ PE"}</span>`;
[["lb","./"],["l1","today"],["l2","checklist"],["l3","./"]].forEach(([id,h])=>{ const a=document.getElementById(id); a.href=h+Q; });
const WQ=(new URLSearchParams(Q).get("w")||"").toUpperCase();
function askNow(){ if(WQ) fetch("cockpitask"+Q,{cache:"no-store"}).catch(()=>{}); }
function ix(id,n,x){ const el=document.getElementById(id);
  if(!x){ el.innerHTML=`<span class="n">${n}</span><span class="mu">from 09:15</span>`; return; }
  el.innerHTML=`<span class="n">${n}</span><span class="p nm">${f2(x.px)}</span><span class="chip c-${esc(x.state)}">${x.state==="RISING"?"▲":x.state==="FALLING"?"▼":"↔"} ${esc(x.state)}</span>
    <span class="mu nm">since ${esc((x.since||"").slice(0,5))}${x.above_open==null?"":x.above_open?" · above open":" · below open"}${x.p15!=null?" · 15m "+pc(x.p15):""}</span>`; }
function li(d,s,m,t){ return `<div class="li">${d==null?"<span></span>":side(d)}<div><span class="s">${sl(s)}</span> <span class="m">${m||""}</span></div><span class="t">${esc(t||"")}</span></div>`; }
const EMPTY=t=>`<div class="empty">${t}</div>`;
function ckRow(c,k){ if(!c) return ""; const t=c[2]||""; const warn=/SOLO|no help|mixed|no clear|close ⚠/.test(t);
  return `<i class="${c[1]?"up":warn?"am":"dn"}">${c[1]?"✓":warn?"!":"✕"}</i><span class="k">${k}</span><span>${esc(t)}</span>`; }
function walls(w){ if(!w) return '<span class="mu">no option data yet</span>';
  const r=(w.R||[]).slice(0,2).map((x,i)=>`<span class="dn">R${i+1} ${f2(x.k)}</span> <span class="mu">${x.pct}%${x.ch!=null?" · "+(x.ch>0?"+":"")+x.ch+"% today":""}</span>`).join(" · ");
  const s=(w.S||[]).slice(0,2).map((x,i)=>`<span class="up">S${i+1} ${f2(x.k)}</span> <span class="mu">${x.pct}%${x.ch!=null?" · "+(x.ch>0?"+":"")+x.ch+"% today":""}</span>`).join(" · ");
  return (r||'<span class="mu">R —</span>')+"<br>"+(s||'<span class="mu">S —</span>'); }
function pb(p,b){ if(!p) return `<div class="pbk"><span class="mu">Playbook: waiting for prices</span></div>`;
  if(p.bad) return `<div class="pbk bad"><b class="dn">Playbook ✕</b> ${esc(p.bad)}</div>`;
  if(p.rank) return `<div class="pbk hit"><b class="up">Playbook #${p.rank} of 10</b> · ${esc(p.name)}<div class="mu">${esc(p.tested)}${p.hits&&p.hits.length>1?" · also #"+p.hits.slice(1).join(", #"):""}</div></div>`;
  const bs=p.best; return `<div class="pbk"><b>Playbook: no tested setup</b> <span class="mu">for ${esc(b.s)} ${b.side} now</span>${p.near?`<div class="am">${esc(p.near)}</div>`:""}${bs?`<div class="mu">best now: <span class="${bs.dir>0?"up":"dn"}">${esc(bs.s)} ${bs.side} #${bs.rank}</span> ${esc(bs.short)} · since ${esc(bs.since)}</div>`:""}</div>`; }
function box(b){ const C={}; (b.checks||[]).forEach(c=>C[c[0]]=c);
  const src=b.how==="your view"?"👁 YOUR VIEW":b.how==="asked from its page"?"🔎 ASKED FROM ITS PAGE":"GIR SIGNAL (🧱 / 🧲 / 🚀 / 🌪)";
  const vt={TRADE:"TRADE "+b.side,SMALL:"SMALL / WAIT",SKIP:"SKIP"}[b.verdict]||esc(b.verdict||"—");
  const iv=b.iv&&b.iv.word?` · IV ${b.iv.iv}% ${b.iv.word==="EXPENSIVE"?'<span class="am">expensive</span>':esc(b.iv.word.toLowerCase())}`:"";
  const move=b.brk==null?'<span class="mu">5-min range from 09:20</span>':b.brk?`<span class="up">broke 5-min ${b.dir>0?"high "+f2(b.f5[0]):"low "+f2(b.f5[1])}</span>`:`<span class="dn">inside 5-min ${b.dir>0?"high "+f2(b.f5&&b.f5[0]):"low "+f2(b.f5&&b.f5[1])}</span>`;
  const book=b.book==null?'<span class="mu">not known yet</span>':`<span class="${b.book_ok?"up":"dim"}">${b.book>=1?"buyers "+b.book.toFixed(1)+"× sellers":"sellers "+(1/b.book).toFixed(1)+"× buyers"}</span>`;
  return `<a class="bx" href="${shareURL(b.s)}" target="_blank"><div class="top"><div><div><span class="nmx">${esc(b.s)}</span> ${side(b.dir)} <span class="px nm">₹${f2(b.px)}</span> <span class="nm ${cl(b.chg)}">${pc(b.chg)}</span></div>
      <div class="src">${src}${b.index?` · ${esc(b.index)} ${pc(b.index_chg)}`:""}</div></div><div class="vd ${esc(b.verdict||"")}">${vt}<small>score ${b.score??"—"} / 5</small></div></div>
    <div class="ck">${ckRow(C.market,"MARKET")}${ckRow(C.bank,"BANK")}${ckRow(C.sector,"SECTOR")}${ckRow(C.futures,"FUTURES")}${ckRow(C.vwap,"VWAP")}
      <i class="mu">•</i><span class="k">ORDER BOOK</span><span>${book}</span>${ckRow(C.walls,"WALLS")}<i class="mu">•</i><span class="k">LEVELS</span><span class="nm" style="font-size:11.5px">${walls(b.walls)}</span>
      <i class="mu">•</i><span class="k">MOVE</span><span>${move}${b.vr!=null?` · volume ${b.vr}× normal`:""}${iv}</span>
      ${b.steady?`<i class="up">✓</i><span class="k">STEADY</span><span class="up">${b.steady.mv}% from open · OI +${b.steady.doi}% · ${b.dir>0?"above":"below"} VWAP ${b.steady.vmin} min</span>`:""}</div>
    ${pb(b.play,b)}
    ${(b.good&&b.good.length)||(b.warn&&b.warn.length)?`<div class="tst"><span class="mu" style="font:600 10px var(--mono);letter-spacing:.08em">TESTED 30 DAYS</span>${(b.good||[]).map(x=>`<div class="up">${esc(x)}</div>`).join("")}${(b.warn||[]).map(x=>`<div class="${String(x).startsWith("❌")?"dn":"am"}">${esc(x)}</div>`).join("")}</div>`:""}
    ${b.verdict!=="SKIP"?`<div class="plan ${esc(b.verdict||"")}">${b.strike?f2(b.strike)+" "+b.side+" ATM · ":""}SL: share ${b.dir>0?"below":"above"} ₹${f2(b.stop)} · book half ₹${f2(b.half)}${b.target?` · target ${b.dir>0?"R1":"S1"} ${f2(b.target)}`:""} · out by 15:15</div>`:""}
  </a>`; }
function lst(id,L,f,empty){ document.getElementById(id).innerHTML=(L&&L.length)?L.slice().reverse().slice(0,12).map(f).join(""):EMPTY(empty||"none yet"); }
function paint(d){ d=d||{};
  const age=Math.max(0,Math.round(Date.now()/1000-(d.t||0))), st=document.getElementById("st");
  if(!d.t){ st.textContent="NO DATA YET · FROM 09:15"; st.className="st"; } else if(age>60){ st.textContent="UPDATED "+(age<3600?Math.round(age/60)+" MIN":Math.round(age/3600)+" H")+" AGO"; st.className="st old"; } else { st.textContent="● LIVE "+(d.hm||""); st.className="st live"; }
  ix("ixn","NIFTY",d.nifty); ix("ixb","BANKNIFTY",d.bank);
  document.getElementById("r2").innerHTML=`<span>${d.mk?`<b class="nm">${d.mk[0]}</b> of ${d.mk[2]} shares rising`:"breadth from 09:15"}</span><span class="secs">${(d.sectors||[]).slice(0,12).map(x=>`<span class="sc ${cl(x[1])}">${esc(String(x[0]).replace("NIFTY ",""))} ${pc(x[1])}</span>`).join("")}</span><span class="rules">out by 15:15 · stop after 2 losses · trade the side NIFTY is going</span>`;
  document.getElementById("pri").innerHTML=(d.wm||[]).length?(d.wm||[]).slice().reverse().slice(0,8).map(x=>li(x.dir,x.s,`fut OI ${x.doi>0?"+":""}${x.doi}% · ${x.dir>0?"floor":"roof"} ${x.wall?x.wall[0]:"—"}${x.wall?` (${x.wall[3]}% away, +${Math.round(x.wall[2]||0)}% today)`:""}${x.note&&x.note!=="card sent"?" · "+esc(x.note):""}`,x.t)).join(""):EMPTY("None yet today. Rings in GIR Bigmovers when futures, the option wall and VWAP agree (09:30-14:30).");
  document.getElementById("pbk").innerHTML=(d.pb||[]).length?(d.pb||[]).slice(0,8).map(x=>li(x.dir,x.s,`#${x.rank} · ${esc(x.short)}`,x.since)).join(""):EMPTY("No share in a tested setup right now. Steady falls usually come 09:30-11:00, CE setups before 10:00.");
  document.getElementById("psh").innerHTML=(d.push_top||[]).length?(d.push_top||[]).slice(0,8).map(x=>li(x.dir,x.s,`<b class="nm">${Number(x.x).toFixed(Math.abs(x.x)>=0.1?2:3)}×</b> a normal day · ₹${Math.round(x.cr||0).toLocaleString("en-IN")} cr`,"")).join(""):EMPTY("Waiting for the futures money (from 09:15).");
  let BX=(d.boxes||[]).slice(); if(WQ){ const a=(d.ask||{})[WQ]; BX=BX.filter(b=>b.s!==WQ); BX.unshift(a||null); }
  document.getElementById("boxes").innerHTML=BX.length?BX.map(b=>b?box(b):`<div class="bx"><div class="top"><span class="nmx">${esc(WQ)}</span></div><div class="empty">Working out ${esc(WQ)}'s checks - a few seconds on a market day (from 09:15).</div></div>`).join("")
    :`<div class="card">${EMPTY("No shares on watch yet - add one with ➕ watch on the CHECKLIST page; GIR adds its own 🚀 / 🌪 movers as they come.")}</div>`;
  lst("a1",d.steady,x=>li(x.dir,x.s,`${x.mv}% · OI +${x.doi}%${x.note?" · "+esc(x.note):""}`,x.t));
  lst("a2",d.big,x=>li(x.dir,x.s,"",(x.t||"").slice(0,5)));
  lst("a3",d.mom,x=>li(x.dir,x.s,`<span class="nm ${cl(x.chg)}">${pc(x.chg)}</span>`,(x.t||"").slice(0,5)));
  lst("a4",d.load,x=>li(x.side>0?1:x.side<0?-1:null,x.s,x.side?"":'<span class="am">direction not clear</span>',""));
  const PA=d.pb_all||[], AV=d.pb_avoid||[];
  document.getElementById("ft").innerHTML=`<div class="foot"><span>🛡 <b>POSITIONS</b> ${d.pos&&d.pos.open&&d.pos.open.length?esc(d.pos.open.join(", ")):'<span class="mu">none open</span>'}</span><span>today <b class="nm">${d.pos?d.pos.losses:0}</b> losses <span class="mu">(stop after 2)</span></span></div>
    ${PA.length?`<details><summary>📚 THE FULL PLAYBOOK · 10 TESTED SETUPS (30 DAYS, NSE DATA)</summary><ol>${PA.map(x=>`<li><span class="${x[1]==="CE"?"up":"dn"}">${esc(x[2])}</span> <span class="mu">· ${esc(x[3])}</span><br><span class="dim">${esc(x[4]||"")}</span></li>`).join("")}</ol>${AV.length?`<div class="dn">Avoid: ${AV.map(esc).join(" · ")}</div>`:""}</details>`:""}`; }
async function pull(){ try{ const r=await fetch("cockpitdata"+Q,{cache:"no-store"}); if(r.ok) paint(await r.json()); }catch(e){} }
pull(); setInterval(()=>{ if(!document.hidden) pull(); },3000);
askNow(); setInterval(()=>{ if(!document.hidden) askNow(); },30000);
</script></body></html>
HTML_CK
cat > $W/home321.html <<'ADD_H'
<style>/* patch 321: the TRADE tab cleaned up (laptop and phone) */
#q-act>h3>span{display:none}
@media(max-width:899px){
  body.vmk.mt-trade #abar .ac{display:none !important}
  #abar .ar{gap:4px !important;flex-wrap:wrap}#abar .ar a{font-size:11px !important;padding:3px 7px !important}
  #abar .alt a{font-size:11px !important}
  #fkeys #tdkey,#fkeys a[data-v="market"]{display:none !important}
  body.mt-more #mk::before{content:"Choose a page above" !important}
}
</style>
<script>/* patch 321: plain names on the alert panels - P1 / P2 / P3 -> ACT / WATCH / INFO, no formula in the EARLY header, SOUND ON without the note */
(function(){ const NM={P1:"ACT",P2:"WATCH",P3:"INFO"};
  function tick(){ try{
    document.querySelectorAll("#abar .dg .p1, #abar .dg .p2, #abar .dg .p3, .dgh .p1, .dgh .p2, .dgh .p3").forEach(e=>{ const t=e.textContent, n=t.replace(/\bP([123])\b/,(m,d)=>NM["P"+d]); if(n!==t) e.textContent=n; });
    document.querySelectorAll("#abar .tg, .tg").forEach(e=>{ const t=e.textContent, n=t.replace(/^P[123]\s+/,""); if(n!==t) e.textContent=n; });
    const eh=document.getElementById("mk-earh"); if(eh){ const t=eh.textContent, i=t.indexOf(" · BUY = "); if(i>0) eh.textContent=t.slice(0,i); }
    document.querySelectorAll("#abar .ar a").forEach(a=>{ const t=a.textContent; if(/tap page once/.test(t)) a.textContent=t.replace(/\s*·\s*tap page once/,""); });
  }catch(e){} }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; tick(); },50); }).observe(document.body,{childList:true,subtree:true,characterData:true}); }catch(e){}
  tick();
  /* the phone tabs: HOME first, then TODAY (TODAY appears once - not in MORE too) */
  try{ if(typeof MTABS!=="undefined"){ const i=MTABS.findIndex(t=>t[0]==="today"), h=MTABS.findIndex(t=>t[0]==="home");
      if(i>=0&&h>=0&&i<h){ const t=MTABS.splice(i,1)[0]; MTABS.splice(MTABS.findIndex(x=>x[0]==="home")+1,0,t); if(typeof mtDraw==="function") mtDraw(); } } }catch(e){}
  })();
</script>
ADD_H
cp $W/cockpit.html $D/cockpit.html || back
python3 - $D/home.html $W/home321.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 321")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  for f in home.html cockpit.html; do
    python3 - $D/$f $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
    node --check $W/page.js 2>$W/js.err || { echo "❌ $f:"; head -5 $W/js.err; back; }
  done
  echo "  the page code checked ✓"
fi
echo "✅ patch 321 done - the new COCKPIT, the TRADE tab cleaned up, phone tabs HOME then TODAY. Refresh the page (phone: close the tab and open it again)."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done"
