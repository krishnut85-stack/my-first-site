#!/bin/bash
# PATCH 324 - LESS CLUTTER: EXPLANATIONS BEHIND ⓘ, TOMORROW AS CARDS, ONE NEWS PLACE ON THE LAPTOP / iPAD (Rama, 15 Nov: "we still have time -
#   why are you postponing the job"). Tested on GIR's real pages at phone, iPad and laptop sizes (0 text under 11 px, 0 under 4.5:1 contrast):
#   · BIG MONEY: the live lines stay (LIVE, BIG MOVERS, TURNS, MOMENTUM, MONEY LOADING); the long legend and the footnote fold behind
#     "ⓘ HOW TO READ" on the title line · F&O TAPE: the header says "218 shares · desk 15:36" - the legend behind ⓘ
#   · TOMORROW: the morning brief drawn as cards - ▼ TROUBLE · ▲ GOOD NEWS · ◆ RESULTS · 🏛 MARKET · 🧭 TODAY'S PATTERN - each line: the share
#     (tap = its page), the tags as chips (RESULTS / MISS / BEAT / REGULATOR ...), the headline, the time. The same text, nothing dropped.
#   · the laptop / iPad: the scrolling news ticker at the bottom hidden - the full news panel is on the same screen (the phone keeps it)
#   · the alerts panel: ACT / WATCH / INFO on one line, "P1 · P2 in TRADE NOW" -> "ACT · WATCH in TRADE NOW"
#   Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 324" $D/home.html; then echo "patch 324 - already in"; exit 0; fi
grep -q "patch 323" $D/home.html || { echo "patch 323 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/home324.html <<'ADD_H'
<style>/* patch 324: explanations folded behind ⓘ (BIG MONEY, F&O TAPE), TOMORROW as cards, one news place on the laptop / iPad */
body:not(.gx-info) #mk-lnk .wbar>div.dim,body:not(.gx-info) #mk-lnk>.note,body:not(.gx-info) .gx-leg{display:none !important}
.gx-i{display:inline-block;margin-left:8px;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;color:#f5a623 !important;cursor:pointer;border:1px solid #5c4410;border-radius:4px;padding:2px 8px;vertical-align:1px;white-space:nowrap}
.gx-leg{margin:6px 0 10px;padding:9px 11px;border:1px solid #273244;border-radius:6px;background:#0c1118;color:#a3aebf;font:12.5px/1.55 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;white-space:normal}
@media(min-width:900px){ html body #tick{display:none !important} }
#abar .dg span,#abar .dgh span{white-space:nowrap !important}
#tmb.tmx-on{white-space:normal !important;font:13px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
.tmx-h{padding:4px 2px 12px}.tmx-h b{font:700 15px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#e6edf3}.tmx-h div{color:#a3aebf;font-size:12.5px;margin-top:3px}
.tmx-g{display:grid;grid-template-columns:repeat(auto-fill,minmax(520px,1fr));gap:10px}
.tmx-c{background:#0c1118;border:1px solid #1c2532;border-left:3px solid #273244;border-radius:6px;min-width:0}
.tmx-c.dn{border-left-color:#f0544f}.tmx-c.up{border-left-color:#26c281}.tmx-c.am{border-left-color:#f5a623}.tmx-c.bl{border-left-color:#4c9aff}
.tmx-ch{display:flex;align-items:center;gap:8px;padding:9px 12px;border-bottom:1px solid #1c2532;font:700 12px ui-monospace,Menlo,monospace;letter-spacing:.1em;color:#e6edf3}
.tmx-ch .n{margin-left:auto;font:700 11px ui-monospace,Menlo,monospace;padding:2px 8px;border-radius:10px;background:#1b222d;color:#a3aebf}
.tmx-ch small{font:500 11.5px -apple-system,"Segoe UI",Roboto,sans-serif;letter-spacing:0;color:#8b97a9}
.tmx-r{display:grid;grid-template-columns:104px minmax(0,1fr) auto;gap:4px 10px;padding:8px 12px;border-bottom:1px solid #121923;align-items:baseline}.tmx-r:last-child{border-bottom:0}
.tmx-r .s{font:700 12.5px ui-monospace,Menlo,monospace;color:#e6edf3;cursor:pointer;overflow:hidden;text-overflow:ellipsis}.tmx-r .s:hover{text-decoration:underline}
.tmx-r .x{color:#c9d1dc;overflow-wrap:anywhere}.tmx-r .t{font:11.5px ui-monospace,Menlo,monospace;color:#8b97a9;white-space:nowrap}
.tmx-tg{display:inline-block;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:1px 6px;border-radius:3px;background:#1b222d;color:#a3aebf;margin-right:5px}
.tmx-tg.MISS,.tmx-tg.GOVERNANCE{background:#3a1416;color:#f0544f}.tmx-tg.BEAT{background:#0d3324;color:#26c281}.tmx-tg.REGULATOR{background:#3a2c10;color:#f5a623}
.tmx-f{padding:7px 12px;color:#8b97a9;font-size:12px}
.tmx-p{padding:7px 12px;border-bottom:1px solid #121923;color:#c9d1dc;font-size:12.5px}.tmx-p b{color:#e6edf3}
@media(max-width:899px){ .tmx-g{grid-template-columns:1fr}.tmx-r{grid-template-columns:86px minmax(0,1fr)}.tmx-r .t{grid-column:2} }
</style>
<script>/* patch 324: ⓘ how to read (the long legends folded), TOMORROW drawn as cards (the same text, read line by line) */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  function infoBtn(){ const a=document.createElement("a"); a.className="gx-i"; a.textContent=document.body.classList.contains("gx-info")?"ⓘ hide":"ⓘ how to read";
    a.onclick=e=>{ e.stopPropagation(); document.body.classList.toggle("gx-info"); document.querySelectorAll(".gx-i").forEach(x=>x.textContent=document.body.classList.contains("gx-info")?"ⓘ hide":"ⓘ how to read"); }; return a; }
  function bigMoney(){ const h=document.querySelector("#q-lnk > h3"); if(h&&!h.querySelector(".gx-i")) h.appendChild(infoBtn()); }   /* in the fixed title line - the box below redraws every few seconds */
  function tape(){ const t=document.getElementById("tfoot"); if(!t) return; const s=t.textContent, i=s.indexOf(" · PRICE flash"); if(i<0) return;
    const keep=s.slice(0,i).replace(/\s*\(\)/g,""), leg=s.slice(i+3); t.textContent=keep;
    const h=t.closest("h2")||t.parentElement; if(!h.querySelector(":scope>.gx-i")) h.appendChild(infoBtn()); let L=h.nextElementSibling&&h.nextElementSibling.classList.contains("gx-leg")?h.nextElementSibling:null;
    if(!L){ L=document.createElement("div"); L.className="gx-leg"; h.after(L); } L.textContent=leg; }
  const SEC=[["▼","dn"],["▲","up"],["◆","am"],["🏛","bl"],["🧭",""]];
  function tom(){ const el=document.getElementById("tmb"); if(!el||el.querySelector(".tmx-g")) return; const src=el.textContent||""; if(src.length<40) return;
    const intro=[], secs=[]; let cur=null;
    src.split("\n").forEach(raw=>{ const ln=raw.replace(/\s+$/,""); if(!ln.trim()) return;
      if(/^\s{2,}/.test(ln)&&cur){ cur.items.push(ln.trim()); return; }
      const ic=SEC.find(x=>ln.startsWith(x[0]));
      if(ic){ const body=ln.slice(ic[0].length).trim(), m=body.match(/^(.*?)\s*\((\d+)\)\s*:?\s*$/); cur={ic:ic[0],c:ic[1],t:m?m[1]:body.replace(/:\s*$/,""),n:m?m[2]:"",items:[]}; secs.push(cur); return; }
      if(cur) cur.items.push(ln.trim()); else intro.push(ln.trim()); });
    if(!secs.length) return;
    const tagRe=/^[A-Z][A-Z0-9 /&+-]{1,18}$/, timeRe=/^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) \d{1,2}:\d{2}$/;
    const open=s=>`onclick="try{ mkOpen('${E(s).replace(/'/g,"")}') }catch(e){}"`;
    const row=(it,c)=>{ if(/^…/.test(it)) return `<div class="tmx-f">${E(it)}</div>`;
      if(c==="") { const k=it.split(" → "); return `<div class="tmx-p">${E(k[0])}${k[1]?` → <b>${E(k.slice(1).join(" → "))}</b>`:""}</div>`; }
      const P=it.split(" · "); const sym=P.shift(); const time=P.length&&timeRe.test(P[P.length-1])?P.pop():""; const tags=[]; while(P.length>1&&tagRe.test(P[0])) tags.push(P.shift());
      const head=P.join(" · ");
      return `<div class="tmx-r"><span class="s" ${sym&&sym!=="MARKET"?open(sym):""}>${E(sym)}</span><span class="x">${tags.map(t=>`<span class="tmx-tg ${E(t.split(" ")[0])}">${E(t)}</span>`).join("")}${E(head)}</span><span class="t">${E(time)}</span></div>`; };
    const hdr=intro.find(x=>/MORNING BRIEF/.test(x))||intro[0]||"", sub=intro.filter(x=>x!==hdr).join(" ");
    el.classList.add("tmx-on");
    el.innerHTML=`<div class="tmx-h"><b>${E(hdr.replace(/^☀️\s*/,"☀️ "))}</b>${sub?`<div>${E(sub)}</div>`:""}</div><div class="tmx-g">${secs.map(s=>{ const t=s.t.split(" · "); return `<div class="tmx-c ${s.c}"><div class="tmx-ch">${E(s.ic)} ${E(t[0])}${t[1]?` <small>${E(t.slice(1).join(" · "))}</small>`:""}${s.n?`<span class="n">${E(s.n)}</span>`:""}</div>${s.items.map(it=>row(it,s.c)).join("")}</div>`; }).join("")}</div>`; }
  function names(){ document.querySelectorAll("#abar .dg, #abar .dgh").forEach(d=>{ const w=document.createTreeWalker(d,NodeFilter.SHOW_TEXT); let n; while((n=w.nextNode())){ const v=n.nodeValue, x=v.replace(/\bP1 · P2\b/g,"ACT · WATCH"); if(x!==v) n.nodeValue=x; } }); }
  function tick(){ try{ bigMoney(); tape(); tom(); names(); }catch(e){} }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; tick(); },60); }).observe(document.body,{childList:true,subtree:true,characterData:true}); }catch(e){}
  tick(); })();
</script>
ADD_H
python3 - $D/home.html $W/home324.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 324")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 324 done - ⓘ how to read on BIG MONEY / F&O TAPE, TOMORROW as cards, one news place on the laptop / iPad. Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
