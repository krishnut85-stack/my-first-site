#!/bin/bash
# PATCH 369 - SECTORS: ⚠ ONE SHARE + THE SECTOR CARD (Rama, 17 Nov: "the sector ranking is one of the main criteria for the share selection ...
#   work out and confirm the believable sector ranking" · "I want the sector performance for all, and in that sector how our F&O shares
#   performed - when I click the particular sector").
#   rankstudy.py on 66 real days (10 Aug - 16 Nov) ranked the sectors six ways at 09:45 and 10:00: NO way of ranking - by size, size capped,
#   plain average, middle share, up minus down, F&O only - made the shares of the top / bottom sectors steadily better than any F&O share
#   already moving that way. The one steady difference it found: when ONE share makes half or more of a top sector's by-size move, the
#   sector's OTHER F&O shares went on -0.29% to 15:10 from 10:00 (38% its way), against -0.06% (44%) in a sector moved by many shares -
#   worse in both halves of the days.
#   · seclive.py: each sector row gets "one": [share, its % of the sector's move, F&O?] when one share is 50%+ of it (sector moved 0.10%+),
#     and "fol": every F&O share of the sector [share, % today, its size in the sector %, its part of the sector's move %]
#   · the SECTORS box: a small ⚠ tag on that row - "⚠ BHARTIARTL 77%" - and the tooltip says what it means
#   · a click on a sector (SECTORS, ROTATION, the BOARD, ...) still lists its shares in F&O MOVERS and now also opens THE SECTOR CARD: the
#     sector on ALL its NSE shares (by size, plain average, rank, up / down), then each of its F&O shares - % today, against the sector, its
#     size in the sector, its part of the move, the futures build-up, today's 🧪 candidate - and the best / worst of its other shares.
#     ✕ or Esc closes it; it refreshes every 20 seconds while open.
#   Needs patches 367 and 368. Replaces seclive.py, edits home.html. Restarts the sector reader and the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 369" $D/home.html && grep -q "patch 369" $D/seclive.py; then echo "patch 369 - already in"; exit 0; fi
grep -q "patch 368" $D/home.html || { echo "patch 368 is not in yet - run install_p368.sh first; nothing done"; exit 1; }
grep -q "def prefetch" $D/seccand.py || { echo "patch 367 is not in yet - run install_p367.sh first; nothing done"; exit 1; }
git -C $R show $B:intraday_patches/seclive.py > $W/seclive.py 2>/dev/null && grep -q "patch 369" $W/seclive.py && python3 -m py_compile $W/seclive.py || { echo "❌ seclive.py with patch 369 not in $B - run the git fetch line first; nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/seclive.py $D/seclive.py.bak369
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/seclive.py.bak369 $D/seclive.py; systemctl restart gir-seclive gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/seclive.py $D/seclive.py || back
cat > $W/card.html <<'CARD'
<style>/* patch 369: THE SECTOR CARD */
#gxsc{position:fixed;left:14px;top:70px;width:min(620px,calc(100vw - 28px));max-height:calc(100vh - 90px);overflow:auto;z-index:8800;display:none;background:#0b1522;border:1px solid #2b5a8a;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.6);color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;-webkit-overflow-scrolling:touch}
#gxsc.on{display:block}
#gxsc .hd{position:sticky;top:0;background:#0f2238;padding:9px 12px;border-bottom:1px solid #1b3048;display:flex;flex-wrap:wrap;gap:4px 10px;align-items:baseline}
#gxsc .hd b{font:800 14px ui-monospace,Menlo,monospace;letter-spacing:.05em;color:#f0b429}
#gxsc .hd .big{font:800 15px ui-monospace,Menlo,monospace}
#gxsc .hd .x{margin-left:auto;padding:2px 10px;border:1px solid #2b5a8a;border-radius:6px;background:#0b1522;color:#e6edf3;font:700 12px ui-monospace,Menlo,monospace;cursor:pointer}
#gxsc .sub{color:#a3aebf;font-size:11.5px;width:100%}
#gxsc .one{margin:8px 12px 0;padding:6px 9px;border-left:3px solid #f0b429;background:#1d1a0e;color:#f3d98b;font-size:12px}
#gxsc .sum{margin:8px 12px;font-weight:600}
#gxsc table{width:calc(100% - 16px);margin:0 8px;border-collapse:collapse;font:12px ui-monospace,Menlo,monospace}
#gxsc th{color:#8b97a9;font-weight:600;text-align:right;padding:4px 5px;border-bottom:1px solid #1b3048;white-space:nowrap}
#gxsc th:first-child,#gxsc td:first-child{text-align:left}
#gxsc td{text-align:right;padding:5px 5px;border-bottom:1px solid #12233a;white-space:nowrap}
#gxsc tr.r{cursor:pointer}#gxsc tr.r:hover{background:#13263d}
#gxsc .u{color:#26c281}#gxsc .d{color:#ff5c5c}#gxsc .m{color:#8b97a9}#gxsc .c{color:#f0b429}
#gxsc .rest,#gxsc .ft{margin:8px 12px;color:#a3aebf;font-size:11.5px}
#gxsc .ft a{color:#58a6ff;cursor:pointer;text-decoration:underline}
@media (max-width:700px){#gxsc{left:0;right:0;top:auto;bottom:0;width:100%;max-height:78vh;border-radius:12px 12px 0 0}#gxsc table{font-size:11px}#gxsc th,#gxsc td{padding:4px 3px}#gxsc .hide-s{display:none}}
</style>
<script>/* patch 369: THE SECTOR CARD - a click on a sector opens it: the sector on ALL its NSE shares, then how each of its F&O shares did */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const P=v=>v==null||isNaN(v)?"–":(v>0?"+":"")+Number(v).toFixed(2)+"%";
  const C=v=>v==null||isNaN(v)||Math.abs(v)<0.005?"m":v>0?"u":"d";
  const KIND={A:"WEAK",B:"BREAK",E:"BOUNCE",T:"STRONG3",G:"GAPDAY"};
  let name="", SLV=null, CAND=null, tmr=null, at=0;
  function box(){ let el=document.getElementById("gxsc"); if(!el){ el=document.createElement("div"); el.id="gxsc"; document.body.appendChild(el);
      el.addEventListener("click",e=>{ const t=e.target; if(t.closest(".x")){ hide(); return; } if(t.closest(".mv")){ hide(); return; }
        const r=t.closest("tr.r"); if(r&&r.dataset.s){ const s=r.dataset.s; hide(); try{ mkOpen(s); }catch(_){ } } }); }
    return el; }
  function hide(){ const el=document.getElementById("gxsc"); if(el) el.classList.remove("on"); name=""; if(tmr){ clearInterval(tmr); tmr=null; } }
  async function pull(){ try{ const r=await fetch("seclive?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ const v=await r.json(); if(v&&v.sectors) SLV=v; } }catch(e){}
    if(Date.now()-at>60000){ at=Date.now(); try{ const r=await fetch("seccand?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) CAND=await r.json(); }catch(e){} } }
  function draw(){ const el=box(); if(!name||!SLV) return false;
    const L=SLV.sectors.slice().sort((a,b)=>b.chg-a.chg), i=L.findIndex(x=>x.name.toLowerCase()===name.toLowerCase()); if(i<0) return false;
    const x=L[i], dn=x.chg<0, tape={}; try{ (TAPE||[]).forEach(r=>{ tape[r.s]=r; }); }catch(e){}
    const cand={}; try{ ((CAND&&CAND.cands)||[]).forEach(c=>{ (cand[c.s]=cand[c.s]||[]).push((KIND[c.kind]||c.kind)+" "+(c.dir>0?"CE":"PE")+" "+c.t); }); }catch(e){}
    const F=(x.fol||[]).slice().sort((a,b)=>dn?a[1]-b[1]:b[1]-a[1]);
    const up=F.filter(r=>r[1]>0).length, dw=F.filter(r=>r[1]<0).length, avg=F.length?F.reduce((s,r)=>s+r[1],0)/F.length:null;
    const ahead=F.filter(r=>dn?r[1]<x.chg:r[1]>x.chg).length;
    const rows=F.map(r=>{ const t=tape[r[0]]||{}, vs=r[1]-x.chg;
      return `<tr class="r" data-s="${H(r[0])}" title="${H(r[0])}: tap = its trading screen"><td><b>${H(r[0])}</b></td><td class="${C(r[1])}">${P(r[1])}</td><td class="${C(vs)}">${P(vs)}</td>`+
        `<td class="hide-s">${r[2]==null?"–":r[2]+"%"}</td><td>${r[3]==null?"–":r[3]+"%"}</td><td class="hide-s m">${H(t.bu||"–")}</td><td class="c">${H((cand[r[0]]||[]).join(" · "))}</td></tr>`; }).join("");
    const other=(L_,w)=>L_.filter(t=>!t[2]).map(t=>`${H(t[0])} <span class="${C(t[1])}">${P(t[1])}</span>`).join(", ")||"–";
    el.innerHTML=`<div class="hd"><b>${H(x.name.toUpperCase())}</b><span class="big ${C(x.chg)}">${P(x.chg)}</span><span>by size · ${P(x.eqw)} plain average</span><span>rank ${i+1} of ${L.length}</span><a class="x" title="close (Esc)">✕</a>`+
      `<span class="sub">measured on ALL its ${x.n} NSE shares · <span class="u">▲${x.up}</span> <span class="d">▼${x.dn}</span> · ${H(SLV.at||"")}</span></div>`+
      (x.one?`<div class="one">⚠ ONE SHARE: by size, <b>${H(x.one[0])}</b> alone is ${x.one[1]>=100?"more than all":x.one[1]+"%"} of this sector's move - the sector figure is mostly that company. On 66 days the other F&O shares of such a top sector did worse (−0.29% against −0.06% from 10:00 to 15:10).</div>`:"")+
      (F.length?`<div class="sum">ITS ${F.length} F&amp;O SHARES: <span class="u">${up} up</span> · <span class="d">${dw} down</span> · average <span class="${C(avg)}">${P(avg)}</span> · ${ahead} of ${F.length} ${dn?"weaker":"stronger"} than the sector (${P(x.chg)})</div>`+
        `<table><tr><th>F&amp;O share</th><th title="its move today">today</th><th title="its move less the sector's by-size move">vs sector</th><th class="hide-s" title="its company's size as a share of the whole sector">size</th><th title="how much of the sector's by-size % this one share made">part of move</th><th class="hide-s" title="today's futures build-up">futures</th><th title="today's 🧪 candidate on this share">🧪</th></tr>${rows}</table>`
        :`<div class="sum m">no F&amp;O shares in this sector - nothing to trade here, information only</div>`)+
      `<div class="rest">its other shares (not F&amp;O) · best: ${other(x.top||[])} · worst: ${other(x.bot||[])}</div>`+
      `<div class="ft">tap a share = its trading screen · "its part of the move" = how much of the sector's by-size % that one share made · <a class="mv">close - see them in F&amp;O MOVERS</a></div>`;
    el.classList.add("on"); return true; }
  async function open(n){ name=n; if(!draw()){ await pull(); if(name!==n) return; if(!draw()){ name=""; return; } }
    if(tmr) clearInterval(tmr); tmr=setInterval(async()=>{ if(!name){ clearInterval(tmr); tmr=null; return; } await pull(); draw(); },20000); }
  window.gxSecCard=open;
  if(typeof mkSec==="function"){ const O=mkSec; mkSec=function(n){ const r=O.apply(this,arguments); try{ open(String(n||"")); }catch(e){} return r; }; }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape") hide(); });
  document.addEventListener("pointerdown",e=>{ const el=document.getElementById("gxsc"); if(!el||!el.classList.contains("on")) return; const t=e.target;
    if(el.contains(t)||(t.closest&&t.closest('[onclick*="mkSec"]'))) return; hide(); },true);
  setTimeout(pull,2500);
})();
</script>
CARD
python3 - $D/home.html $W/card.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
E = (
 ('`<span>${E(x.name.toUpperCase())} <span class="gxn">',
  '`<span>${x.one?`<span class="gxone">⚠ ${E(x.one[0])} ${x.one[1]>=100?"ALL":x.one[1]+"%"}</span>`:""}${E(x.name.toUpperCase())} <span class="gxn">'),
 ('${pc(x.wchg!=null?x.wchg:x.chg)} by size · ${pc(x.eqw)} as a plain average - all its ${x.n} NSE shares',
  '${pc(x.wchg!=null?x.wchg:x.chg)} by size · ${pc(x.eqw)} as a plain average - all its ${x.n} NSE shares'
  '${x.one?` · ⚠ ONE SHARE: by size, ${E(x.one[0])} alone is ${x.one[1]>=100?"more than all":x.one[1]+"%"} of this move - the figure is mostly that company. On 66 days the other F&O shares of such a top sector did worse than those of a sector moved by many shares`:""}'))
for a, b in E:
    if t.count(a) != 1:
        print("❌ home.html: %r found %d times" % (a[:60], t.count(a))); sys.exit(1)
    t = t.replace(a, b)
css = '<style>/* patch 369: ⚠ ONE SHARE on a SECTORS row */\n#mk-don .sb .gxone{font-size:10px;color:#f0b429;margin-right:6px;font-weight:600;white-space:nowrap}\n</style>\n' + open(sys.argv[2], encoding="utf-8").read()
i = t.rfind("</body>")
if i < 0:
    print("❌ home.html: </body> not found"); sys.exit(1)
t = t[:i] + css + t[i:]
open(p, "w", encoding="utf-8").write(t); print("  home.html: SECTORS - ⚠ ONE SHARE · THE SECTOR CARD")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 8
echo "  gir-seclive: $(systemctl is-active gir-seclive) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-seclive)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 369 done - refresh GIR (Ctrl+Shift+R). Click any sector: THE SECTOR CARD opens - the sector on all its NSE shares, then each of its F&O shares."
echo "   A SECTORS row moved mostly by one company shows ⚠ and its name, e.g. ⚠ BHARTIARTL 77%."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/seclive.py.bak369 $D/seclive.py; systemctl restart gir-seclive gir-dash"
