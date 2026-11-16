#!/bin/bash
# PATCH 343 - MY F&O (TAB 9) STOPS SHAKING (Rama, 16 Nov: "my F&O tab is shaking the whole screen"). On a laptop with real scrollbars the MY F&O
#   page was a few px wider than the window, so a scrollbar came and went; the P&L chart resized to every new width, which moved the page again
#   - a loop (a test with the width flipping: 20 chart resizes in 3 s before, 0 after). Now: no sideways overflow on that view, the chart box
#   has a fixed height, and the chart resizes only on a real width change (8 px+), at most twice a second. Edits home.html only. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 343" $D/home.html; then echo "patch 343 - already in"; exit 0; fi
grep -q "patch 342" $D/home.html || { echo "patch 342 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_343'
<style>/* patch 343: MY F&O (tab 9) stops shaking - no sideways overflow, the P&L chart box holds its size */
body.vmyfo{overflow-x:hidden !important}
#mfpnl{max-width:100%;overflow:hidden;box-sizing:border-box}
#mfpnl #pnc{overflow:hidden;contain:size layout;height:var(--gxpnch,320px)}
#mfpnl #pnc>div{max-width:100%}
</style>
<script>/* patch 343: MY F&O shook on a laptop with real scrollbars: the page was a few px wider than the window, a scrollbar came and went, the P&L chart
   resized to every new width, which moved the page again - a loop. Now: no sideways overflow on that view, the chart box has a fixed height,
   and the chart is resized only when its box width really changes (more than 8 px), at most twice a second. */
(function(){
  function patchRO(){ try{ if(typeof PNL==="undefined"||!PNL.ro||PNL.ro.__gx) return; const box=PNL.box; if(!box) return;
      PNL.ro.disconnect(); let lastW=box.clientWidth, tm=0;
      const ro=new ResizeObserver(()=>{ clearTimeout(tm); tm=setTimeout(()=>{ try{ const w=box.clientWidth; if(PNL.ch&&w&&Math.abs(w-lastW)>8){ lastW=w; PNL.ch.applyOptions({width:w-2}); } }catch(e){} },500); });
      ro.__gx=true; ro.observe(box); PNL.ro=ro;
      try{ if(PNL.ch) PNL.ch.applyOptions({width:Math.max(200,box.clientWidth-2)}); }catch(e){} }catch(e){} }
  function vflag(){ try{ document.body.classList.toggle("vmyfo",typeof VIEW!=="undefined"&&VIEW==="myfo"); const c=document.getElementById("pnc"); if(c){ const h=(typeof PNL!=="undefined"&&PNL.tab==="days")?(PNL.dmode==="bars"?280:320):260; document.documentElement.style.setProperty("--gxpnch",h+"px"); } }catch(e){} }
  setInterval(()=>{ vflag(); patchRO(); },700); })();
</script>
ADD_343
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: MY F&O no longer shakes")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 343 done - refresh GIR and open 9 MY F&O: it stays still."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
