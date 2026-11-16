#!/bin/bash
# PATCH 339 - THE LAPTOP HOME SCREEN: NIFTY CHART | SECTORS SIDE BY SIDE (Rama, 16 Nov: "most of the sectors and rotation are not visible -
#   make the chart half, NIFTY chart left, the sectors on its right with scroll up / down and the sort buttons, move ROTATION up" ·
#   "move the OI scenarios below the rotation").
#   Laptop (1280 px and wider): the top row = index cards · NIFTY chart · SECTORS (its own scroll, title and sort buttons on top, same height
#   as the chart) · alerts. Below: ROTATION moves up into the sectors' old place, OI SCENARIOS · NEWS right under it (full width, not a thin
#   strip), TRADE NOW takes the whole right column. Under 1280 px (iPad, phone) nothing changes. Edits home.html only. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 339" $D/home.html; then echo "patch 339 - already in"; exit 0; fi
grep -q "patch 338" $D/home.html || { echo "patch 338 first"; exit 1; }
grep -q 'id="q-don"' $D/home.html && grep -q 'id="idxrow"' $D/home.html || { echo "home.html: the sectors box / top row not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_339'
<style>/* patch 339: laptop (1280 px+) - the NIFTY chart and SECTORS side by side in the top row; ROTATION moves up, OI SCENARIOS · NEWS under it, TRADE NOW the whole right column */
@media(min-width:1280px){
  body.gxsplit #idxrow>#q-nif{flex:1 1 0 !important;min-width:0 !important;width:auto !important;max-width:none !important}
  body.gxsplit #idxrow>#q-don{flex:1 1 0 !important;min-width:0 !important;display:flex !important;flex-direction:column !important;align-self:flex-start;height:var(--gxnifh,310px) !important;max-height:var(--gxnifh,310px) !important;margin:0 !important;overflow:hidden !important;
    background:var(--panel,#0b1017);border:1px solid var(--line,#1c2532);border-radius:6px}
  body.gxsplit #idxrow>#q-don>h3{flex:0 0 auto;position:sticky;top:0;z-index:2;background:var(--panel,#0b1017);font-size:12.5px !important;line-height:1.35 !important;letter-spacing:.06em}
  body.gxsplit #idxrow>#q-don>h3 *{font-size:11px !important}
  html body.topchart.fkin.gxsplit:not(.mk-money):not(.mk-opts):not(.mk-big) #mk{grid-template-areas:"mov fk fk act" "mov ear ear act" "mov dsk dsk act" "mov rot rot act" "mov nws nws act" !important}
  html body.topchart.fkin.gxsplit:not(.mk-money):not(.mk-opts):not(.mk-big) #mk>#q-nws{min-height:0;overflow:auto}
  html body.gxsplit #mk>#q-rot{min-height:0;overflow:hidden}
  body.gxsplit #idxrow>#q-don>.bd{flex:1 1 auto;overflow-y:auto !important;overflow-x:hidden !important;min-height:0;-webkit-overflow-scrolling:touch}
}
</style>
<script>/* patch 339: the laptop's top row = [index cards] [NIFTY chart | SECTORS] [alerts]. SECTORS is moved next to the chart (the same box, its
   own scroll, sort buttons on top); below, ROTATION / F&O DESK move up. Under 1280 px nothing changes. */
(function(){
  const $i=id=>document.getElementById(id), home={p:null,n:null};
  function redraw(){ setTimeout(()=>{ try{ if(typeof IXC!=="undefined"&&IXC){ IXC.key=""; IXC.h=-1; } if(typeof ixDraw==="function") ixDraw(); }catch(e){} },60); }
  function apply(){ try{ const row=$i("idxrow"), don=$i("q-don"), nif=$i("q-nif"); if(!row||!don) return;
      const on=innerWidth>=1280&&document.body.classList.contains("topchart")&&nif&&nif.parentElement===row&&!document.body.classList.contains("gx-max-ix");
      if(on&&nif){ const h=Math.round(nif.getBoundingClientRect().height); if(h>120) document.documentElement.style.setProperty("--gxnifh",h+"px"); }
      if(on&&don.parentElement!==row){ home.p=don.parentElement; home.n=don.nextElementSibling; nif.after(don); document.body.classList.add("gxsplit"); redraw(); }
      else if(!on&&don.parentElement===row){ if(home.p) home.p.insertBefore(don,home.n&&home.n.parentElement===home.p?home.n:null); document.body.classList.remove("gxsplit"); redraw(); }
    }catch(e){} }
  window.addEventListener("resize",()=>setTimeout(apply,80));
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; apply(); },150); }).observe(document.body,{attributes:true,attributeFilter:["class"]}); }catch(e){}
  setInterval(apply,2000); apply(); })();
</script>
ADD_339
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: NIFTY chart | SECTORS side by side (laptop)")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 339 done - on the laptop: refresh GIR HOME - NIFTY chart | SECTORS, ROTATION up, OI SCENARIOS under it."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
