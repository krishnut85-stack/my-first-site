#!/bin/bash
# PATCH 207 - SHOWING THE ALERTS WISELY on the GIR page (Rama, 11 Nov: "how to display the alerts wisely - the SECTORS tab is too big,
#   the green colour is too long"). The page only: nothing removed, Telegram unchanged, no restart - safe any time.
#   SECTORS    short bars in 3 columns (1 on a phone) - all sectors at once, no scrolling · ▲ up / ▼ down counted
#   IMPORTANT  (TRADE NOW) one row a share: latest alert · ×n today · the room ✅⚠️❌ · ⇄ BOTH SIDES (CE and PE within 30 min = no call)
#              · LATE (already moved 3%+) · filters ALL / 🚨 CRITICAL / 🟠 OI / 📰 NEWS
#   ALERTS box (laptop) the buttons in one short row · under them 🔴 P1 · 🟠 P2 · 🟡 P3 counts and the quiet P3 alerts grouped a share
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p207_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p207_patch.py - PATCH 207: SHOWING THE ALERTS WISELY on the GIR page (Rama, 11 Nov: "how to display the alerts wisely in the GIR page -
the SECTORS tab is too big, the green colour is too long"). The page only - nothing is removed, nothing changes in Telegram.
  SECTORS     short bars in columns (3 across on a laptop, 1 on a phone) - every sector at once, no scrolling, ▲ up / ▼ down counted
  IMPORTANT   (TRADE NOW, P2) ONE row a share: its latest alert, ×n how many today, since when · the room ✅ / ⚠️ / ❌ when the alert
              gave it · ⇄ BOTH SIDES when the same share said CE and PE within 30 min (a coin toss - no call) · LATE when it had
              already moved 3%+ · filters ALL / 🚨 CRITICAL / 🟠 OI / 📰 NEWS
  ALERTS box  (laptop, MARKET) the controls in one short row · under them the 🟡 INFO list - the quiet P3 alerts grouped a share,
              the same as the Telegram digest - with the count of P1 / P2 / P3 on top
Usage: python3 p207_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
P = os.path.join(D, "home.html")
s = open(P, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  home.html: %s" % tag)


# 1 · SECTORS: short bars in columns
rep('''<span class="dim">${R.length} sectors</span></div>`:"")+(R.length?R.map(x=>{ const w=Math.min(50,Math.abs(x.v)/mx*50); return `<div class="sb${x.n<3?" few":""}" onclick="mkSec('${esc(x.name)}')" title="${esc(x.name)} · ${x.n} F&amp;O shares · ${x.f?"no NSE index - its F&amp;O shares' average":"NSE's index"}"><span>${esc(x.name.toUpperCase())} <small>${x.n}</small>${x.f?"<i>F&amp;O</i>":""}</span><span class="tr"><span class="fl ${x.v>=0?"u":"d"}" style="${x.v>=0?"left":"right"}:50%;width:${w.toFixed(1)}%"></span></span><b class="${x.v>=0?"pu":"pd"}">${x.v>0?"+":""}${x.v.toFixed(2)}%</b></div>`; }).join(""):'<div class="empty">no sectors yet</div>'); }''',
    '''<span class="dim"><b class="pu">▲ ${R.filter(x=>x.v>0).length}</b> · <b class="pd">▼ ${R.filter(x=>x.v<0).length}</b> · ${R.length} sectors</span></div>`:"")+(R.length?'<div class="sbc">'+R.map(x=>{ const w=Math.max(3,Math.abs(x.v)/mx*100); return `<div class="sb${x.n<3?" few":""}" onclick="mkSec('${esc(x.name)}')" title="${esc(x.name)} · ${x.n} F&amp;O shares · ${x.f?"no NSE index - its F&amp;O shares' average":"NSE's index"}"><span>${esc(x.name.toUpperCase())} <small>${x.n}</small>${x.f?"<i>F&amp;O</i>":""}</span><span class="tr"><span class="fl ${x.v>=0?"u":"d"}" style="width:${w.toFixed(1)}%"></span></span><b class="${x.v>=0?"pu":"pd"}">${x.v>0?"+":""}${x.v.toFixed(2)}%</b></div>`; }).join("")+'</div>':'<div class="empty">no sectors yet</div>'); }   /* patch 207: short bars in columns */''',
    "SECTORS: short bars in columns")

# 2 · IMPORTANT: one row a share
rep('''    <h4>IMPORTANT <small>${mv.length} · newest first · tap = its screen</small></h4>${mv.length?mv.slice(0,40).map(imp).join(""):'<div class="dim" style="padding:4px 2px">nothing moving yet</div>'}`; }''',
    '''    ${impGroups(mv)}`; }
/* patch 207: IMPORTANT - one row a share (latest · ×n · since) · room ✅⚠️❌ · ⇄ both sides · late · filters */
let IMPF="all"; try{ IMPF=localStorage.getItem("gir_impf")||"all"; }catch(e){}
function impSet(v){ IMPF=v; try{ localStorage.setItem("gir_impf",v); }catch(e){} drawAct(); }
function impKind(r){ const H=String(r.head||""); return alertLane(r)==="critical"?"crit":/^🟠 OI|^🔭|^🧩/.test(H)?"oi":/📰|📄|RESULTS|NEWS|FILING/.test(H)?"news":"other"; }
function roomOf(r){ const T=[r.head||""].concat(r.lines||[]).join("\\n"); let m=T.match(/room:?\\s*(?:next [^=\\n]*=\\s*)?(\\d+(?:\\.\\d+)?)%/i);
  if(m){ const a=+m[1]; return {a,c:a>=3?"ok":a>=1.5?"mid":"no",t:(a>=3?"✅":a>=1.5?"⚠️":"❌")+" room "+a.toFixed(1)+"%"}; }
  if(/room:?\\s*no (holding|big)|no big (call|put) wall/i.test(T)) return {a:99,c:"ok",t:"✅ open room"};
  if(/no room/i.test(T)) return {a:0,c:"no",t:"❌ no room"}; return null; }
function hm2m(t){ const m=String(t||"").match(/(\\d\\d):(\\d\\d)/); return m?+m[1]*60+ +m[2]:0; }
function impWhat(r){ const h_=String(r.head||""), k_=r.s?h_.indexOf(r.s):-1; if(k_<0) return h_.trim(); const a=h_.slice(0,k_).replace(/[\\s▲▼·:\\-–]+$/,"").trim(), b=h_.slice(k_+r.s.length).replace(/^[\\s▲▼·:\\-–]+/,"").trim(); return [a,b].filter(Boolean).join(" · ").replace(/\\s*·\\s*·\\s*/g," · "); }
function impGroups(mv){ const G={}, order=[];
  mv.slice().sort((a,b)=>hm2m(b.t)-hm2m(a.t)).forEach(r=>{ const k=r.s; if(!G[k]){ G[k]={s:k,r,rows:[],side:{},crit:false,kinds:new Set()}; order.push(k); } const g=G[k];
    g.rows.push(r); if(r.side==="CE"||r.side==="PE") g.side[r.side]=Math.max(g.side[r.side]||0,hm2m(r.t)); if(alertLane(r)==="critical") g.crit=true; g.kinds.add(impKind(r)); });
  const gs=order.map(k=>G[k]); const cnt={all:gs.length,crit:gs.filter(g=>g.crit).length,oi:gs.filter(g=>g.kinds.has("oi")).length,news:gs.filter(g=>g.kinds.has("news")).length};
  const F=IMPF in cnt?IMPF:"all"; const show=gs.filter(g=>F==="all"||(F==="crit"?g.crit:g.kinds.has(F)));
  const tabs=[["all","ALL"],["crit","🚨 CRITICAL"],["oi","🟠 OI"],["news","📰 NEWS"]].map(([k,n])=>`<a class="${F===k?"on":""}" onclick="event.stopPropagation();impSet('${k}')">${n} <b>${cnt[k]}</b></a>`).join("");
  const row=g=>{ const r=g.r, up=r.side==="CE", dn=r.side==="PE", n=g.rows.length;
    const rm=g.rows.filter(x=>x.side===r.side).map(roomOf).find(Boolean);   /* the room of its own side only */ const flip=g.side.CE&&g.side.PE&&Math.abs(g.side.CE-g.side.PE)<=30;
    const pm=String(r.head||"").match(/([+-]\\d+(?:\\.\\d+)?)%/); const late=(up||dn)&&pm&&Math.abs(+pm[1])>=3&&(+pm[1]>0)===up&&!/^🟢|^🌅|^⚠️/.test(r.head||"");
    const older=g.rows.slice(1,4).map(x=>`${esc(x.t)} ${esc(impWhat(x).split("·")[0].trim().slice(0,30))}`).join(" · ")+(n>4?` · +${n-4} more`:"");
    return `<div class="im${g.crit?" cr":""}" onclick="focusOn('${esc(r.s)}')" title="${esc(g.rows.map(x=>x.t+"  "+x.head).join("\\n"))}"><i class="${g.crit?"c":""}"></i><span class="t">${esc(r.t)}</span><div><div class="ih"><b>${esc(r.s)}</b> <span class="${up?"pu":dn?"pd":"dim"}">${up?"▲ CE":dn?"▼ PE":""}</span>${n>1?`<em class="nx" title="${n} alerts today on ${esc(r.s)}">×${n}</em>`:""}${rm?`<em class="rm ${rm.c}">${rm.t}</em>`:""}${flip?'<em class="fx" title="CE and PE within 30 minutes - a coin toss, not a call">⇄ BOTH SIDES</em>':""}${late?'<em class="lt" title="it had already moved 3%+ its way">LATE</em>':""}</div><p>${esc(impWhat(r).slice(0,110))}</p>${n>1?`<p class="ol">also ${older}</p>`:""}</div></div>`; };
  return `<h4>IMPORTANT <small>${gs.length} share${gs.length===1?"":"s"} · ${mv.length} alert${mv.length===1?"":"s"} · newest first · tap = its screen</small></h4><div class="imf">${tabs}</div>${show.length?show.slice(0,30).map(row).join(""):'<div class="dim" style="padding:4px 2px">'+(mv.length?"none in this filter":"nothing moving yet")+'</div>'}`; }''',
    "IMPORTANT: one row a share, room, both sides, filters")

# 3 · ALERTS box: short controls (laptop) + the 🟡 INFO list
rep('''  const LT={all:"ALL",critical:"🚨 CRITICAL",oi:"🔭 OI",moves:"📈 MOVES & NEWS"};''',
    '''  const TC=document.body.classList.contains("topchart");   /* patch 207: beside the chart - short labels, the 🟡 INFO list */
  const LT=TC?{all:"ALL",critical:"🚨 CRITICAL",oi:"🔭 OI",moves:"📈 MOVES"}:{all:"ALL",critical:"🚨 CRITICAL",oi:"🔭 OI",moves:"📈 MOVES & NEWS"};
  const dgH=(()=>{ if(!TC) return ""; const W={}, wo=[]; let nP1=0,nP2=0,nP3=0;
    rows.forEach(r=>{ const tr=alertTier(r); if(aNight()&&!ALLDAY&&!r.prev&&r.t>="09:15"&&r.t<"15:30") return; if(tr==="act"){ nP1++; return; } if(tr==="move"){ nP2++; return; } nP3++; if(/NOT SENT/.test(r.head||"")) return;
      const id=r.s||"·"; if(!W[id]){ W[id]={s:r.s,r,n:0}; wo.push(id); } const w=W[id]; w.n++; if(hm2m(r.t)>hm2m(w.r.t)) w.r=r; });
    const gl=wo.map(k=>W[k]).sort((a,b)=>hm2m(b.r.t)-hm2m(a.r.t)||b.n-a.n);
    return `<div class="dg"><div class="dgh"><span class="p1">🔴 P1 ${nP1}</span><span class="p2">🟠 P2 ${nP2}</span><span class="p3">🟡 P3 ${nP3}</span><span class="dim">P1 · P2 in TRADE NOW ↓</span></div>`+
      (gl.length?gl.slice(0,40).map(w=>{ const r=w.r, up=r.side==="CE", dn=r.side==="PE"; return `<div class="dgr" onclick="focusOn('${esc(r.s||"MARKET")}')" title="${esc(r.head||"")}"><span class="t">${esc(r.t)}</span><b>${esc(r.s||"MARKET")}</b>${w.n>1?`<em>×${w.n}</em>`:""}<span class="${up?"pu":dn?"pd":"dim"}">${up?"▲":dn?"▼":""}</span><span class="w">${esc(impWhat(r).slice(0,70))}</span></div>`; }).join(""):'<div class="dim" style="padding:4px 6px">🟡 no quiet alerts '+(aNight()&&!ALLDAY?"since the close":"yet")+'</div>')+`</div>`; })();''',
    "ALERTS box: short labels + the 🟡 INFO list")
rep('''<div class="ar">${aNight()?`<a class="${ALLDAY?"on":""}" onclick="aDay()" title="after the close: the whole day's alerts / only what came after the close">${ALLDAY?"🌙 ONLY NEW":"DAY'S ALERTS"}</a>`:""}<a onclick="selfCheck()" title="clicks through every key, panel and tab on this server's data and lists what works">✓ SELF-CHECK</a><a class="${ASND?"on":""}" onclick="sndToggle()" title="${ASND&&!sndArmed()?"the browser lets a page ring only after one tap or key on it - tap anywhere once":"sound on / off"}">${ASND?(sndArmed()?"🔔 SOUND ON":"🔔 SOUND ON · tap page once"):"🔕 SOUND OFF"}</a><a onclick="setView('now')">WATCH ${nW} →</a></div>`;''',
    '''${dgH}<div class="ar">${aNight()?`<a class="${ALLDAY?"on":""}" onclick="aDay()" title="after the close: the whole day's alerts / only what came after the close">${TC?(ALLDAY?"🌙 NEW ONLY":"🌙 WHOLE DAY"):(ALLDAY?"🌙 ONLY NEW":"DAY'S ALERTS")}</a>`:""}<a onclick="selfCheck()" title="clicks through every key, panel and tab on this server's data and lists what works">${TC?"✓ CHECK":"✓ SELF-CHECK"}</a><a class="${ASND?"on":""}" onclick="sndToggle()" title="${ASND&&!sndArmed()?"the browser lets a page ring only after one tap or key on it - tap anywhere once":"sound on / off"}">${TC?(ASND?(sndArmed()?"🔔 ON":"🔔 tap once"):"🔕 OFF"):(ASND?(sndArmed()?"🔔 SOUND ON":"🔔 SOUND ON · tap page once"):"🔕 SOUND OFF")}</a><a onclick="setView('now')">WATCH ${nW} →</a></div>`;''',
    "ALERTS box: short controls")
rep('''nW,ASND,FOC,ALANE,LC,ALLDAY,aNight()]); if(!force&&ck===drawAlerts.ck) return;''',
    '''nW,ASND,FOC,ALANE,LC,ALLDAY,aNight(),document.body.classList.contains("topchart"),rows.length]); if(!force&&ck===drawAlerts.ck) return;''',
    "ALERTS box: redrawn when a quiet alert comes")

# 4 · the look
CSS = '''
/* patch 207: SECTORS short bars in columns · IMPORTANT one row a share · the ALERTS box tidy */
#mk-don .sbc{columns:240px auto;column-gap:22px;padding:0 2px}
#mk-don .sbc .sb{break-inside:avoid;grid-template-columns:minmax(0,1fr) 46px 52px;gap:6px;padding:2px 2px;font-size:11.5px}
#mk-don .sbc .tr{height:7px;background:var(--panel2);border-radius:2px;overflow:hidden}#mk-don .sbc .tr::before{display:none}
#mk-don .sbc .fl{top:0;left:0;height:7px;opacity:.8}
#mk-don .sbc .sb b{font-size:11.5px}
#mk-act .imf{display:flex;gap:3px;flex-wrap:wrap;margin:4px 0 2px}
#mk-act .imf a{cursor:pointer;padding:2px 7px;border:1px solid var(--line2);border-radius:4px;font:600 10.5px var(--ui);color:var(--txt);background:var(--panel2)}
#mk-act .imf a b{color:var(--dim);font-weight:500}#mk-act .imf a.on{background:var(--amber);border-color:var(--amber);color:#1a1205}#mk-act .imf a.on b{color:#1a1205}
#mk-act .im .ih{display:flex;flex-wrap:wrap;gap:3px 6px;align-items:baseline}
#mk-act .im em{font:600 10px/1.5 var(--ui);font-style:normal;padding:0 5px;border-radius:3px;background:var(--panel2);color:var(--txt)}
#mk-act .im em.nx{color:var(--amber)}#mk-act .im em.rm.ok{color:var(--up)}#mk-act .im em.rm.mid{color:var(--amber)}#mk-act .im em.rm.no{color:var(--dn)}
#mk-act .im em.fx{color:#fff;background:#5a3b00}#mk-act .im em.lt{color:var(--dim)}
#mk-act .im p.ol{font-size:10.5px;opacity:.75;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#mk-act .im.cr{background:linear-gradient(90deg,rgba(255,80,80,.07),transparent 60%)}
#abar .dg{display:none}
body.topchart #idxside #abar .alt{flex-wrap:nowrap;overflow:hidden}body.topchart #idxside #abar .alt a{padding:2px 5px}
body.topchart #idxside #abar .ar{order:2;flex-wrap:nowrap;overflow:hidden;padding:0 4px 4px}body.topchart #idxside #abar .ar a{padding:2px 6px;font-size:9.5px}
body.topchart #idxside #abar .ac{order:4}
body.vmk.topchart #idxside #abar:not(.lane) .dg{display:block;order:4;flex:1 1 100%;min-height:0;border-top:1px solid var(--line)}
#abar .dgh{display:flex;gap:8px;align-items:center;padding:4px 6px;font:600 10px var(--ui);position:sticky;top:0;background:#0b0d11}
#abar .dgh .p1{color:var(--dn)}#abar .dgh .p2{color:var(--amber)}#abar .dgh .p3{color:#e6c34a}#abar .dgh .dim{margin-left:auto;font-weight:400}
#abar .dgr{display:grid;grid-template-columns:36px auto auto 12px minmax(0,1fr);gap:0 5px;align-items:baseline;padding:2px 6px;cursor:pointer;font-size:10.5px;border-bottom:1px solid var(--line)}
#abar .dgr:hover{background:#14202e}#abar .dgr .t{color:var(--dim);font-family:var(--mono)}#abar .dgr b{color:var(--hi)}#abar .dgr em{font-style:normal;color:var(--amber);font-size:9.5px}
#abar .dgr .w{color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#abar .dgr:not(:has(em)){grid-template-columns:36px auto 12px minmax(0,1fr)}
</style><link rel="preconnect"'''
rep('''</style><link rel="preconnect"''', CSS, "the look")

if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(P, "w", encoding="utf-8").write(s)
print("home.html: patch 207 in")
PY_PATCH
python3 $W/p207_patch.py $D || back
grep -q "patch 207" $D/home.html || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
js = [m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)]
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(js))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 207 done - press Ctrl + Shift + R on GIR."
echo "   SECTORS: short bars in columns · IMPORTANT: one row a share with ×n, room, ⇄ BOTH SIDES · ALERTS box: P1/P2/P3 counts + the quiet alerts grouped"
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
