#!/bin/bash
# PATCH 372 - 🚀 A SECTOR IS RUNNING (Rama, 17 Nov 11:10: "I did not get any alert for the sector that was running fast up" - capital
#   markets ran on the capital-gains tax news and GIR said nothing).
#   · secsurge.py (new), called by seclive.py on every sector reading: a sector RUNS when in 30 minutes it moved 0.60%+ (all its NSE shares,
#     by size), 0.40%+ more than the middle sector, with 70%+ of its shares that way (or 0.40% / 0.30% in 15 minutes - a burst). Again for
#     the same sector only after 45 minutes and 0.50% more. 09:30-15:00. Each alert is scored at 15:10 (data/secsurge/<day>.json).
#   · the page: a banner at the top - "🚀 CAPITAL MARKETS RUNNING UP · +0.9% in 30 min ... · F&O: ANGELONE +3.0% ..." - tap = the sector
#     card (patch 369); ✕ closes it. Above the SECTORS list: "RUNS TODAY" with every run of the day. Nothing rings (patch 191's rule).
#   · python3 secsurge.py backtest - the same rule replayed on the kept 5-minute days: what the sector and its F&O shares did after each alert.
#   Needs patch 369. Replaces seclive.py, adds secsurge.py, edits home.html. Restarts the sector reader and the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 372" $D/home.html && grep -q "patch 372" $D/seclive.py && [ -f $D/secsurge.py ]; then echo "patch 372 - already in"; exit 0; fi
grep -q "patch 369" $D/home.html || { echo "patch 369 is not in yet - run install_p369.sh first; nothing done"; exit 1; }
for f in seclive.py secsurge.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "patch 372" $W/seclive.py && python3 -m py_compile $W/seclive.py $W/secsurge.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/seclive.py $D/seclive.py.bak372
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/seclive.py.bak372 $D/seclive.py; rm -f $D/secsurge.py; systemctl restart gir-seclive gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/seclive.py $D/seclive.py && cp $W/secsurge.py $D/secsurge.py || back
cat > $W/surge.html <<'SURGE'
<style>/* patch 372: 🚀 A SECTOR IS RUNNING */
#gxsg{position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:9000;width:min(760px,calc(100vw - 20px));display:flex;flex-direction:column;gap:6px;pointer-events:none}
#gxsg .t{pointer-events:auto;display:flex;gap:10px;align-items:flex-start;padding:9px 12px;border-radius:9px;background:#0f2238;border:2px solid #26c281;box-shadow:0 8px 30px rgba(0,0,0,.6);color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;cursor:pointer}
#gxsg .t.dn{border-color:#ff5c5c}
#gxsg .t b.h{font:800 14px ui-monospace,Menlo,monospace;letter-spacing:.04em}
#gxsg .t .u{color:#26c281}#gxsg .t .d{color:#ff5c5c}#gxsg .t .w{color:#f0b429}#gxsg .t .m{color:#a3aebf}
#gxsg .t .x{margin-left:auto;flex:none;padding:1px 9px;border:1px solid #2b5a8a;border-radius:6px;background:#0b1522;color:#e6edf3;font:700 12px ui-monospace,Menlo,monospace}
#gxrt{margin:2px 0 4px;font:11.5px ui-monospace,Menlo,monospace;color:#a3aebf;display:flex;flex-wrap:wrap;gap:4px 8px;align-items:center}
#gxrt a{cursor:pointer;padding:1px 6px;border-radius:5px;border:1px solid #1b3048;color:#e6edf3}#gxrt a.u{border-color:#1f6e4c}#gxrt a.d{border-color:#7a2a2a}
</style>
<script>/* patch 372: 🚀 A SECTOR IS RUNNING - the banner and RUNS TODAY (from seclive's "surge"); nothing rings */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const P=v=>(v>0?"+":"")+Number(v).toFixed(2)+"%";
  let seen={}; try{ seen=JSON.parse(localStorage.getItem("gir_surge_seen")||"{}")||{}; }catch(e){}
  const k=(V,e)=>(V.day||"")+"|"+e.sec+"|"+e.dir+"|"+e.t;
  const mins=t=>{ const m=/^(\d\d):(\d\d)/.exec(t||""); return m?(+m[1])*60+(+m[2]):0; };
  function shut(key,el){ seen[key]=1; try{ const d=Object.keys(seen); if(d.length>200) d.slice(0,100).forEach(x=>delete seen[x]); localStorage.setItem("gir_surge_seen",JSON.stringify(seen)); }catch(e){} if(el) el.remove(); }
  function open(sec){ try{ mkSec(sec); }catch(e){ try{ if(window.gxSecCard) window.gxSecCard(sec); }catch(_){} } }
  function txt(e){ const up=e.dir>0;
    return `<span><b class="h ${up?"u":"d"}">${up?"🚀":"🔻"} ${H(e.sec.toUpperCase())} ${up?"RUNNING UP":"FALLING FAST"}</b> <span class="m">${H(e.t)}</span><br>`+
      `${P(e.r)} in ${e.win} min (middle sector ${P(e.mid)}) · ${P(e.day)} today, no.${e.rank} of ${e.of} · ${e.br}% of its ${e.nn} shares ${up?"up":"down"}`+
      (e.one?` · <span class="w">⚠ mostly ${H(e.one[0])}</span>`:"")+
      ((e.fo||[]).length?`<br>F&amp;O: ${(e.fo||[]).map(f=>`<b>${H(f[0])}</b> <span class="${f[1]>=0?"u":"d"}">${P(f[1])}</span>`).join(" · ")}`:`<br><span class="m">no F&amp;O share moving that way</span>`)+
      ` <span class="m">· ▸ open its sector card</span></span>`; }
  function draw(V){ const E=(V&&V.surge)||[]; if(!E.length) return;
    let box=document.getElementById("gxsg"); if(!box){ box=document.createElement("div"); box.id="gxsg"; document.body.appendChild(box); }
    const now=mins(V.at);
    E.forEach(e=>{ const key=k(V,e); if(seen[key]||now-mins(e.t)>30||box.querySelector(`[data-k="${CSS.escape(key)}"]`)) return;
      const el=document.createElement("div"); el.className="t"+(e.dir>0?"":" dn"); el.dataset.k=key; el.innerHTML=txt(e)+'<span class="x" title="close">✕</span>';
      el.addEventListener("click",ev=>{ if(ev.target.closest(".x")){ shut(key,el); return; } shut(key,el); open(e.sec); });
      box.prepend(el); while(box.children.length>3) box.lastChild.remove(); });
    const q=document.getElementById("mk-don"); if(q&&q.parentNode){ let r=document.getElementById("gxrt"); if(!r){ r=document.createElement("div"); r.id="gxrt"; q.parentNode.insertBefore(r,q); }
      r.innerHTML=`<span>RUNS TODAY</span>`+E.slice().reverse().map(e=>`<a class="${e.dir>0?"u":"d"}" data-s="${H(e.sec)}" title="${H(e.sec)}: ${P(e.r)} in ${e.win} min at ${H(e.t)} · tap = the sector card">${H(e.t)} ${e.dir>0?"🚀":"🔻"} ${H(e.sec.toUpperCase())}</a>`).join("");
      r.onclick=ev=>{ const a=ev.target.closest("a[data-s]"); if(a) open(a.dataset.s); }; } }
  async function pull(){ if(document.hidden) return; try{ const r=await fetch("seclive?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ const v=await r.json(); if(v&&v.sectors) draw(v); } }catch(e){} }
  setTimeout(pull,3000); setInterval(pull,20000);
})();
</script>
SURGE
python3 - $D/home.html $W/surge.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
i = t.rfind("</body>")
if i < 0:
    print("❌ home.html: </body> not found"); sys.exit(1)
t = t[:i] + open(sys.argv[2], encoding="utf-8").read() + t[i:]
open(p, "w", encoding="utf-8").write(t); print("  home.html: 🚀 the sector-run banner · RUNS TODAY")
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
echo "✅ patch 372 done - from tomorrow 09:30 a running sector shows a 🚀 banner on GIR and in RUNS TODAY above the SECTORS list."
echo "   the rule on the past days:  cd $D && nice -n 15 python3 secsurge.py backtest"
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/seclive.py.bak372 $D/seclive.py; rm -f $D/secsurge.py; systemctl restart gir-seclive gir-dash"
