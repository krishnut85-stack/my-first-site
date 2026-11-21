#!/bin/bash
# PATCH 364 - ▣ THE BOARD: ALARM MANAGEMENT AND THE CLEAN PAGE (Rama: "clean up and a professional design ... basically the alarm management" ·
#   17 Nov: "build the alarm management and page clean-up now"). One screen, three parts, from the data GIR already loads - nothing new runs:
#     TRADE BOARD     only what can be acted on now: the BUY cards (entry, where it stands, WATCH / HALF OUT / STOPPED / CLOSED), the 🧪 paper
#                     candidates (GAPDAY, BOUNCE, STRONG3, BREAK, WEAK) and the 🌙 overnight list - with a count of open / half / closed
#     SECTOR DESK     the 3 strongest and the 3 weakest sectors: move, shares up / down, foreign funds, delivery and zone (sector money), and
#                     their F&O shares with today's move, the futures build-up and a mark when a share is a tested candidate
#     NEWS & ALERTS   ONE list, newest first, of everything GIR sent today: the same story from several sources is one line (x3), with filters
#                     ALL · CRITICAL · RESULTS · MARKET · NEWS · FILINGS · TRADE · FOREIGN (stories GIR itself marked as another country's
#                     company sit under FOREIGN, not in ALL; routine "analyst / investor meet" notices are left out) - all still on the MARKET page
#   A ▣ BOARD button (the function-key bar; on the phone on the box header) opens it; ✕ or Esc goes back to the MARKET page, which is NOT
#   changed - no box is removed, no alert is muted, no sound is changed. A tick box in the board lets it open by itself when GIR starts.
#   The note on a share (357) works inside it. Edits home.html only. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 364" $D/home.html; then echo "patch 364 - already in"; exit 0; fi
grep -q "</body>" $D/home.html && grep -q 'id="fkeys"' $D/home.html && grep -q "D.now" $D/home.html && grep -q "mkOpen(" $D/home.html || { echo "the page's alert list / function-key bar not found - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_364'
<style>/* patch 364: ▣ THE BOARD - trade board · sector desk · one news & alerts list. An overlay: the MARKET page under it is not changed. */
#gxbdb{margin-left:8px;padding:2px 8px;border:1px solid #b5892b;border-radius:10px;background:#2a2008;color:#f0b429;font:800 11px ui-monospace,Menlo,monospace;cursor:pointer;vertical-align:middle;white-space:nowrap}
#fkeys a.gxbdk{color:#f0b429;font-weight:800}
#gxbd{position:fixed;inset:0;z-index:8900;background:#070d16;display:none;overflow:auto;-webkit-overflow-scrolling:touch;color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxbd.on{display:block}
#gxbd .top{position:sticky;top:0;z-index:3;display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:8px 14px;background:#0d1a2b;border-bottom:1px solid #1b3048}
#gxbd .top b{font:800 14px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#f0b429}#gxbd .top .live{font:700 11px ui-monospace,Menlo,monospace;color:#26c281}
#gxbd .top label{color:#a3aebf;font-size:11.5px;cursor:pointer}#gxbd .top .x{margin-left:auto;padding:4px 12px;border:1px solid #2b5a8a;border-radius:6px;background:#0f2238;color:#e6edf3;font:700 12.5px ui-monospace,Menlo,monospace;cursor:pointer}
#gxbd .g{display:grid;grid-template-columns:minmax(0,1.75fr) minmax(330px,1fr);gap:12px;padding:12px 14px;align-items:start}
#gxbd .bx{border:1px solid #1e3550;border-radius:10px;background:#0b1522;margin-bottom:12px;overflow:hidden}
#gxbd .bh{padding:8px 12px;border-bottom:1px solid #16293f;font:800 12.5px ui-monospace,Menlo,monospace;letter-spacing:.08em}#gxbd .bh small{font:500 11.5px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf;margin-left:8px}
#gxbd .st{display:grid;grid-template-columns:repeat(4,1fr);border-bottom:1px solid #16293f}#gxbd .st div{padding:7px 12px;border-right:1px solid #16293f}#gxbd .st div:last-child{border-right:0}
#gxbd .st small{display:block;font:600 10.5px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#8fa0b5}#gxbd .st b{font:800 17px ui-monospace,Menlo,monospace}
#gxbd .c{display:grid;grid-template-columns:minmax(0,1.5fr) minmax(0,1fr) minmax(0,1fr) auto;gap:8px;align-items:center;margin:8px 10px;padding:8px 10px;border:1px solid #1b3048;border-left:4px solid #26c281;border-radius:7px;background:#0f1d30;cursor:pointer}
#gxbd .c.d{border-left-color:#f0544f}#gxbd .c b{font:800 13px ui-monospace,Menlo,monospace}#gxbd .c small{display:block;color:#a3aebf;font-size:11px}
#gxbd .ch{font:700 10.5px ui-monospace,Menlo,monospace;padding:2px 7px;border-radius:4px;background:#17324f;color:#8fc3ff;white-space:nowrap}
#gxbd .ch.half{background:#11331f;color:#26c281}#gxbd .ch.out{background:#3a1616;color:#f0544f}#gxbd .ch.closed{background:#222b38;color:#a3aebf}#gxbd .ch.t{background:#2a2008;color:#f0b429}
#gxbd .r{display:flex;flex-wrap:wrap;gap:6px;align-items:center;padding:5px 12px;border-top:1px solid #12223a;font:12px ui-monospace,Menlo,monospace}
#gxbd .r .s,#gxbd .n .s{font-weight:800;cursor:pointer;padding:0 2px;border-radius:3px}#gxbd .r .s:hover,#gxbd .n .s:hover{background:#17324f}
#gxbd .sub{padding:6px 12px 2px;font:700 10.5px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#8fa0b5;border-top:1px solid #16293f}
#gxbd .none{padding:8px 12px;color:#8fa0b5;font-size:11.5px}
#gxbd .sd{display:grid;grid-template-columns:1fr 1fr}#gxbd .sd>div:first-child{border-right:1px solid #16293f}
#gxbd .sh{padding:8px 12px 3px;font:800 12.5px ui-monospace,Menlo,monospace;cursor:pointer}#gxbd .sf{padding:0 12px 5px;color:#a3aebf;font-size:11.5px}
#gxbd .sr{display:grid;grid-template-columns:104px 56px minmax(40px,1fr) auto;gap:6px;align-items:center;padding:3px 12px;border-top:1px solid #12223a;font:12px ui-monospace,Menlo,monospace;cursor:pointer}
#gxbd .sr:hover{background:#0f1d30}#gxbd .bar{height:5px;border-radius:3px;background:#26c281}#gxbd .bar.d{background:#f0544f}
#gxbd .fl{display:flex;flex-wrap:wrap;gap:5px;padding:8px 10px;border-bottom:1px solid #16293f}#gxbd .fl a{font:700 10.5px ui-monospace,Menlo,monospace;padding:3px 8px;border:1px solid #24405c;border-radius:5px;color:#a3aebf;cursor:pointer}
#gxbd .fl a.on{background:#f0b429;border-color:#f0b429;color:#141005}
#gxbd .n{padding:6px 12px;border-top:1px solid #12223a;cursor:pointer}#gxbd .n:hover{background:#0f1d30}#gxbd .n .a{display:flex;flex-wrap:wrap;gap:6px;align-items:center;font:12px ui-monospace,Menlo,monospace}
#gxbd .n .tm{margin-left:auto;color:#8fa0b5}#gxbd .n .tx{color:#c9d4e3;font-size:12px;margin-top:1px}#gxbd .n .sr2{color:#7f8b9c;font-size:10.5px}
#gxbd .k{font:700 10px ui-monospace,Menlo,monospace;padding:1px 5px;border-radius:3px;background:#1b2a3a;color:#8fc3ff}#gxbd .k.crit{background:#3a1616;color:#f0544f}#gxbd .k.res{background:#14304a;color:#8fc3ff}#gxbd .k.mkt{background:#222b38;color:#c9d4e3}#gxbd .k.trd{background:#2a2008;color:#f0b429}
#gxbd .up{color:#26c281}#gxbd .dn{color:#f0544f}#gxbd .dim{color:#8fa0b5}#gxbd .am{color:#f0b429}
@media (max-width:900px){#gxbd .g{grid-template-columns:1fr;padding:8px}#gxbd .sd{grid-template-columns:1fr}#gxbd .sd>div:first-child{border-right:0}#gxbd .c{grid-template-columns:1fr 1fr}#gxbd .st{grid-template-columns:repeat(2,1fr)}}
</style>
<script>/* patch 364 (Rama: "a professional design ... basically the alarm management" · 17 Nov: "build it now"): ▣ THE BOARD - one screen from what
   the page already loads: TRADE BOARD (BUY cards /headsup, 🧪 candidates /seccand, 🌙 overnight /overnight) · SECTOR DESK (/seclive + sector
   money /secmoney + the live tape) · NEWS & ALERTS (D.now: one list, the same story once). An overlay - the MARKET page is untouched. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const rs=v=>v==null?"—":"₹"+(+v).toLocaleString("en-IN",{maximumFractionDigits:2}), pc=(v,d)=>v==null?"—":(v>=0?"+":"")+(+v).toFixed(d==null?2:d)+"%", cl=v=>v==null?"dim":v>=0?"up":"dn";
  const SY=s=>E(String(s).replace(/[^A-Z0-9&\-]/g,"")), sh=s=>`<span class="s" onclick="mkOpen('${SY(s)}')">${E(s)}</span>`;
  const today=()=>new Date(Date.now()+19800000).toISOString().slice(0,10), KN={G:"GAPDAY",E:"BOUNCE",T:"STRONG3",B:"BREAK",A:"WEAK"};
  let X={hu:null,cd:null,on:null,sl:null,sm:null}, F="all"; try{ F=localStorage.getItem("gir_bdf")||"all"; }catch(e){}
  const tape=()=>{ const m={}; ((typeof TAPE!=="undefined"&&TAPE)||[]).forEach(r=>{ m[r.s]=r; }); return m; };
  function tradeBoard(){ const hu=X.hu, T=tape(), M=hu&&hu.day===today()?Object.values(hu.mon||{}).sort((a,b)=>String(b.t).localeCompare(String(a.t))):[];
    const C=X.cd&&X.cd.day===today()?(X.cd.cands||[]).slice().sort((a,b)=>String(b.t).localeCompare(String(a.t))):[], O=X.on&&X.on.day===today()?(X.on.items||[]):[];
    const n=k=>M.filter(m=>k.includes(m.st)).length, S=(X.sl&&X.sl.sectors)||[], ST={open:"WATCH",half:"HALF OUT ✓",out:"STOPPED",closed:"CLOSED 15:10"};
    const card=m=>`<div class="c ${m.dir>0?"":"d"}" onclick="mkOpen('${SY(m.s)}')"><div><b><span class="${m.dir>0?"up":"dn"}">${m.dir>0?"▲ BUY CE":"▼ BUY PE"}</span> ${E(m.s)}</b><small>${E(m.t)} · ${E(m.kind||"")}</small></div><div><small>ENTRY</small>${rs(m.px)}</div><div><small>NOW</small><span class="${cl(m.mv)}">${m.mv!=null?pc(m.mv,1):"—"}</span></div><span class="ch ${E(m.st)}">${ST[m.st]||E(m.st)}</span></div>`;
    const cand=c=>{ const p=T[c.s]&&T[c.s].px, mv=p?(p/c.px-1)*c.dir*100:null, o=c.opt; return `<div class="r"><span class="dim">${E(c.t)}</span><span class="ch t">🧪 ${KN[c.kind]||E(c.kind)}</span>${sh(c.s)}<span class="${c.dir>0?"up":"dn"}">${c.dir>0?"▲ CE":"▼ PE"}</span><span class="dim">from ${rs(c.px)}</span>${o?`<span class="${cl(o.rs)}">option ${o.rs>=0?"+":"−"}₹${Math.abs(Math.round(o.rs)).toLocaleString("en-IN")}</span>`:(mv!=null?`<span class="${cl(mv)}">${pc(mv,1)} its way</span>`:"")}</div>`; };
    const ov=it=>`<div class="r"><span class="dim">${E(it.time)}</span><span class="${it.dir==="up"?"up":it.dir==="down"?"dn":"dim"}">${it.dir==="up"?"▲":it.dir==="down"?"▼":"?"}</span><span class="k">${E(it.strength)}</span>${it.shares.map(sh).join(" ")}<span class="dim" style="font-family:-apple-system,sans-serif">${E(String(it.headline).slice(0,90))}</span></div>`;
    return `<div class="bx"><div class="bh">TRADE BOARD<small>what can be acted on now · BUY cards ring - the 🧪 and 🌙 lines are paper records, no sound</small></div>`+
      `<div class="st"><div><small>OPEN NOW</small><b>${n(["open"])}</b></div><div><small>HALF BOOKED</small><b class="up">${n(["half"])}</b></div><div><small>CLOSED TODAY</small><b>${n(["out","closed"])}</b></div><div><small>SECTORS</small><b><span class="up">▲ ${S.filter(x=>x.chg>0).length}</span> <span class="dn">▼ ${S.filter(x=>x.chg<0).length}</span></b></div></div>`+
      (M.length?M.map(card).join(""):`<div class="none">no BUY card today so far - GIR rings when one comes</div>`)+
      `<div class="sub">🧪 PAPER CANDIDATES · 09:20 GAPDAY · 09:45 BOUNCE, STRONG3 · 10:00 BREAK, STRONG3 · 10:30+ WEAK</div>`+(C.length?C.map(cand).join(""):`<div class="none">none so far today</div>`)+
      `<div class="sub">🌙 OVERNIGHT · news after yesterday's close - the news is in the opening price; no tested edge in trading its direction at the open</div>`+(O.length?O.slice(0,6).map(ov).join(""):`<div class="none">today's list is made at 08:35</div>`)+`</div>`; }
  function sectorDesk(){ const S=((X.sl&&X.sl.sectors)||[]).slice().sort((a,b)=>b.chg-a.chg), T=tape(), SM={}; ((X.sm&&X.sm.rows)||[]).forEach(r=>{ SM[r.name]=r; });
    if(S.length<6) return `<div class="bx"><div class="bh">SECTOR DESK</div><div class="none">the sectors are not read yet</div></div>`;
    const CK={}; (X.cd&&X.cd.day===today()?(X.cd.cands||[]):[]).forEach(c=>{ (CK[c.s]=CK[c.s]||[]).push(KN[c.kind]||c.kind); });
    const BU={"LONG BUILD-UP":"LB","SHORT BUILD-UP":"SB","SHORT COVERING":"SC","LONG UNWINDING":"LU"};
    const one=(x,i,dr)=>{ const m=SM[x.name]||{}, f=m.fpi, d=m.deliv, rows=(x.fos||[]).map(s=>T[s]).filter(r=>r&&r.chg!=null).sort((a,b)=>(b.chg-a.chg)*dr).slice(0,8), mx=Math.max(1,...rows.map(r=>Math.abs(r.chg)));
      const fund=[f?`foreign funds <span class="${f.run>0?"up":"dn"}">${Math.abs(f.run)>=2?(f.run>0?"BUYING ":"SELLING ")+Math.abs(f.run)+" fortnights":(f.v[0]>=0?"bought":"sold")+" last fortnight"}</span>`:"", d?`delivery ${(+d.x10).toFixed(2)}x normal`:"", m.rsi!=null?`zone ${E(m.rsi)}${m.rsi>=70?' <span class="am">overbought</span>':m.rsi<=30?' <span class="am">oversold</span>':""}`:""].filter(Boolean).join(" · ");
      return `<div class="sh" onclick="try{document.getElementById('gxbd').classList.remove('on');mkSec('${E(x.name).replace(/'/g,"")}')}catch(e){}"><span class="${dr>0?"up":"dn"}">${dr>0?"▲":"▼"} ${i+1} · ${E(String(x.name).toUpperCase())} ${pc(x.chg)}</span> <span class="dim" style="font-weight:500">▲${E(x.up)} ▼${E(x.dn)} of ${E(x.n)}</span></div>`+(fund?`<div class="sf">${fund}</div>`:"")+
        (rows.length?rows.map(r=>`<div class="sr" onclick="mkOpen('${SY(r.s)}')"><b>${E(r.s)}</b><span class="${cl(r.chg)}">${pc(r.chg,1)}</span><span><span class="bar ${r.chg<0?"d":""}" style="display:block;width:${Math.max(4,Math.round(100*Math.abs(r.chg)/mx))}%"></span></span><span>${BU[r.bu]?`<span class="k">${BU[r.bu]}</span> `:""}${(CK[r.s]||[]).map(k=>`<span class="ch t">🧪 ${E(k)}</span>`).join(" ")}</span></div>`).join(""):`<div class="none">no F&O share in it</div>`); };
    return `<div class="bx"><div class="bh">SECTOR DESK<small>the 3 strongest and 3 weakest · all NSE shares of the sector, by size · their F&O shares · tap a share = its screen · rest the mouse = its note</small></div>`+
      `<div class="sd"><div>${S.slice(0,3).map((x,i)=>one(x,i,1)).join("")}</div><div>${S.slice(-3).reverse().map((x,i)=>one(x,i,-1)).join("")}</div></div>`+
      `<div class="none" style="border-top:1px solid #16293f">at 09:45-10:00: CE only on a share marked 🧪 STRONG3 or BREAK (above VWAP + past yesterday's high + volume, or past its 20-day high) · skip a move that was only the opening gap · every sector: the 💰 SECTOR MONEY board</div></div>`; }
  function news(){ const rows=((typeof D!=="undefined"&&D&&D.now)||[]), G=[], ix={};
    const cat=r=>{ const h=r.head||""; return /FOREIGN/.test(h)?"oth":(r.kind==="🚨"||/CRITICAL|SHOCK WATCH/.test(h))?"crit":/RESULTS/.test(h)?"res":(/MARKET NEWS|GOVT WATCH/.test(h)||r.s==="MARKET")?"mkt":/FILING/.test(h)?"fil":/NEWS/.test(h)?"news":"trd"; };
    const TAG=/^(🟠|🔴|📌|🔔|⚠ NOT SENT|🕒|🤖|↳|https?:)/;      /* GIR's own tag lines are not the story */
    rows.forEach(r=>{ const l0=((r.lines||[]).find(x=>x&&!TAG.test(String(x).trim()))||r.head||"").replace(/^\u200b/,""); if(/analyst \/ investor meet/i.test(l0+(r.head||""))) return;
      const k=(r.s||"")+"|"+l0.toLowerCase().replace(/[^a-z0-9]/g,"").slice(0,44); if(ix[k]!=null){ G[ix[k]].n++; return; } ix[k]=G.length; G.push({r,n:1,c:cat(r),l0}); });
    const cnt=c=>c==="all"?G.filter(g=>g.c!=="oth").length:G.filter(g=>g.c===c).length, L=[["all","ALL"],["crit","🚨 CRITICAL"],["res","RESULTS"],["mkt","🏛 MARKET"],["news","NEWS"],["fil","FILINGS"],["trd","TRADE"],["oth","FOREIGN"]];
    const KL={crit:["crit","CRITICAL"],res:["res","RESULTS"],mkt:["mkt","MARKET"],fil:["","FILING"],news:["","NEWS"],trd:["trd","TRADE"],oth:["mkt","FOREIGN"]};
    const V_=G.filter(g=>F==="all"?g.c!=="oth":g.c===F).slice(0,60);      /* a story GIR marked FOREIGN (another country's company) is under its own filter, not in ALL */
    const row=g=>{ const r=g.r, src=((r.head||"").split("·").slice(1).join("·")||"").trim(); return `<div class="n"${r.s&&r.s!=="MARKET"?` onclick="mkOpen('${SY(r.s)}')"`:""}><div class="a"><span class="k ${KL[g.c][0]}">${KL[g.c][1]}</span><b>${E(r.s||"")}</b>${r.side?`<span class="${r.side==="CE"?"up":"dn"}">${r.side==="CE"?"▲ CE":"▼ PE"}</span>`:""}${g.n>1?`<span class="am">×${g.n}</span>`:""}${String(r.t)>="15:30"?'<span class="dim">after the close</span>':""}<span class="tm">${E(r.t)}</span></div><div class="tx">${E(String(g.l0).slice(0,170))}</div>${src?`<div class="sr2">${E(src.slice(0,90))}</div>`:""}</div>`; };
    return `<div class="bx"><div class="bh">NEWS &amp; ALERTS<small>one list · newest first · the same story once</small></div><div class="fl">${L.map(([k,t])=>`<a data-f="${k}" class="${F===k?"on":""}">${t} ${cnt(k)}</a>`).join("")}</div>`+
      (V_.length?V_.map(row).join(""):`<div class="none">nothing in this list today</div>`)+`</div>`; }
  function draw(){ const el=document.getElementById("gxbd"); if(!el||!el.classList.contains("on")) return; const y=el.scrollTop; let auto=false; try{ auto=localStorage.getItem("gir_board")==="1"; }catch(e){}
    const n=new Date(Date.now()+19800000);
    el.innerHTML=`<div class="top"><b>▣ GIR BOARD</b><span class="live">● ${String(n.getUTCHours()).padStart(2,"0")}:${String(n.getUTCMinutes()).padStart(2,"0")}:${String(n.getUTCSeconds()).padStart(2,"0")}</span><label><input type="checkbox" data-auto="1"${auto?" checked":""}> open this board when GIR starts</label><button class="x" type="button" data-x="1">✕ BACK TO MARKET</button></div>`+
      `<div class="g"><div>${tradeBoard()}${sectorDesk()}</div><div>${news()}</div></div>`; el.scrollTop=y; }
  async function get(u){ try{ const r=await fetch(u+"?k="+encodeURIComponent(KEY()),{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
  async function pull(slow){ const a=await Promise.all([get("headsup"),get("seccand"),get("seclive"),slow?get("overnight"):null,slow?get("secmoney"):null]);
    if(a[0]) X.hu=a[0]; if(a[1]) X.cd=a[1]; if(a[2]) X.sl=a[2]; if(a[3]) X.on=a[3]; if(a[4]) X.sm=a[4]; draw(); }
  function open(){ let el=document.getElementById("gxbd"); if(!el){ el=document.createElement("div"); el.id="gxbd";
      el.addEventListener("click",e=>{ const t=e.target; if(t.dataset&&t.dataset.x){ el.classList.remove("on"); return; }
        if(t.dataset&&t.dataset.f){ F=t.dataset.f; try{ localStorage.setItem("gir_bdf",F); }catch(e){} draw(); return; }
        if(t.closest&&t.closest('[onclick*="mkOpen("]')) el.classList.remove("on"); });
      el.addEventListener("change",e=>{ if(e.target.dataset&&e.target.dataset.auto){ try{ localStorage.setItem("gir_board",e.target.checked?"1":"0"); }catch(x){} } });
      document.body.appendChild(el); }
    el.classList.add("on"); el.scrollTop=0; draw(); pull(true); }
  function btn(){ const fk=document.getElementById("fkeys"); if(fk&&!fk.querySelector(".gxbdk")){ const a=document.createElement("a"); a.className="gxbdk"; a.title="the BOARD: trade board · sector desk · one news list (key B)"; a.innerHTML="<b>B</b>▣ BOARD"; a.addEventListener("click",open); fk.insertBefore(a,fk.firstChild); }
    const fv=fk&&fk.getBoundingClientRect().height>0; let b=document.getElementById("gxbdb");
    if(!fv){ const hs=["#q-don h3","#q-rot h3","#q-mov h3"].map(q=>document.querySelector(q)).filter(Boolean), h=hs.find(x=>x.getBoundingClientRect().height>0)||hs[0]; if(!h) return;
      if(!b){ b=document.createElement("button"); b.id="gxbdb"; b.type="button"; b.textContent="▣ BOARD"; b.addEventListener("click",e=>{ e.stopPropagation(); e.preventDefault(); open(); }); }
      if(b.parentElement!==h) h.insertBefore(b,h.children[0]||null); } else if(b) b.remove(); }
  document.addEventListener("keydown",e=>{ const el=document.getElementById("gxbd"), tg=(e.target&&e.target.tagName)||"";
    if(e.key==="Escape"&&el) el.classList.remove("on"); else if((e.key==="b"||e.key==="B")&&!e.ctrlKey&&!e.metaKey&&!e.altKey&&!/INPUT|TEXTAREA|SELECT/.test(tg)){ if(el&&el.classList.contains("on")) el.classList.remove("on"); else open(); } });
  setInterval(()=>{ const el=document.getElementById("gxbd"); if(!document.hidden&&el&&el.classList.contains("on")) draw(); },3000);
  setInterval(()=>{ const el=document.getElementById("gxbd"); if(!document.hidden&&el&&el.classList.contains("on")) pull(false); },10000);
  setInterval(()=>{ const el=document.getElementById("gxbd"); if(!document.hidden&&el&&el.classList.contains("on")) pull(true); },120000);
  setInterval(btn,1500); setTimeout(()=>{ btn(); try{ if(localStorage.getItem("gir_board")==="1"&&!(typeof SOLO!=="undefined"&&SOLO)) open(); }catch(e){} },3000); })();
</script>
ADD_364
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace("</body>", open(sys.argv[2], encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: ▣ THE BOARD")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 364 done - refresh GIR (Ctrl+Shift+R): ▣ BOARD is the first key of the bar (or press B). ✕ or Esc = back to MARKET, which is unchanged."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash"
