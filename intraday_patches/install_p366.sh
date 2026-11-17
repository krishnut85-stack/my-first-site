#!/bin/bash
# PATCH 366 - F&O MOVERS: A SECTOR'S FLAT SHARES ARE SHOWN TOO (Rama, 17 Nov 09:13: "in SERVICES it shows 5 F&O but see here" - the list had one).
#   The list is two columns, UP | DOWN: a share at exactly 0.00% - before the open every share that has not traded yet - was in neither, so a
#   sector of 5 showed 1. Now, when a sector is chosen, a line under the columns names the ones not shown: "no move yet: ADANIPORTS · CONCOR ..."
#   (tap = its trading screen), and says so when a share of the sector has no live price at all. Nothing else in the list is changed.
#   Adds one small block to home.html. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 366" $D/home.html; then echo "patch 366 - already in"; exit 0; fi
grep -q "</body>" $D/home.html && grep -q 'id="mk-mov"' $D/home.html && grep -q "WS.sec" $D/home.html || { echo "the F&O MOVERS box not found - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_366'
<style>/* patch 366: F&O MOVERS - the chosen sector's shares that are in neither column (flat, or not traded yet) */
#gxflat366{padding:5px 8px;border-top:1px solid #1b3048;font:12px ui-monospace,Menlo,monospace;color:#a3aebf;line-height:1.6}
#gxflat366 b{color:#e6edf3;cursor:pointer;padding:0 3px;border-radius:3px}#gxflat366 b:hover{background:#17324f}
</style>
<script>/* patch 366 (Rama, 17 Nov: SERVICES said "5 F&O" and the list showed 1): the UP | DOWN columns leave out a share at exactly 0.00% - before the
   open, every share that has not traded yet. When a sector is chosen, this names the ones not shown. The list's own code is not touched. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  function line(){ const el=document.getElementById("mk-mov"); if(!el) return; let d=document.getElementById("gxflat366");
    const sec=(typeof WS!=="undefined"&&WS&&WS.sec)||"", sx=sec&&typeof SECS!=="undefined"?(SECS||[]).find(x=>x.name===sec):null;
    if(!sx||!(sx.syms||[]).length){ if(d) d.remove(); return; }
    const T={}; ((typeof TAPE!=="undefined"&&TAPE)||[]).forEach(r=>{ T[r.s]=r; });
    const flat=sx.syms.filter(s=>T[s]&&(T[s].chg==null||T[s].chg===0)), none=sx.syms.filter(s=>!T[s]);
    if(!flat.length&&!none.length){ if(d) d.remove(); return; }
    const sh=s=>`<b onclick="mkOpen('${E(s).replace(/[^A-Z0-9&\-]/g,"")}')">${E(s)}</b>`;
    const h=(flat.length?`no move yet (0.00% or not traded): ${flat.map(sh).join(" · ")}`:"")+(none.length?`${flat.length?"<br>":""}no live price: ${none.map(E).join(" · ")}`:"");
    if(!d){ d=document.createElement("div"); d.id="gxflat366"; }
    if(d.dataset.h!==h){ d.dataset.h=h; d.innerHTML=h; }
    if(d.parentElement!==el||el.lastElementChild!==d) el.appendChild(d); }
  let busy=false; const run=()=>{ if(busy) return; busy=true; try{ line(); }catch(e){} busy=false; };
  function watch(){ const el=document.getElementById("mk-mov"); if(!el) return setTimeout(watch,2000); new MutationObserver(run).observe(el,{childList:true}); run(); }
  setInterval(run,2000); setTimeout(watch,2500); })();
</script>
ADD_366
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace("</body>", open(sys.argv[2], encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the flat shares of a chosen sector are named under F&O MOVERS")
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
echo "✅ patch 366 done - refresh GIR (Ctrl+Shift+R). Tap a sector: any of its shares not in the UP / DOWN columns are named under them."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash"
