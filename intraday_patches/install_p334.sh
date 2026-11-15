#!/bin/bash
# PATCH 334 - THE SHARE PAGE FITS THE SCREEN (Rama, 15 Nov, iPad: "it's not fit to page - half of the RSI is hidden").
#   The share page's boxes were sized from 100vh - on an iPad Safari counts its own bars in that, so the bottom of the chart box (the RSI) sat
#   under the screen's edge and could not be scrolled to. Now the boxes end exactly at the bottom of what the screen really shows (measured on
#   the device, re-measured on turning it), the chart fills its box (the RSI with its time line in full), and the page scrolls if ever needed.
#   iPad: the chart buttons in 2 rows (CANDLES / LINE under ⋯ MORE - ⚡ F&O sets candles). The laptop fitted the same way (it ran 6 px under
#   the news ticker). Phone unchanged. Edits home.html only. Tested at 9 sizes. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 334" $D/home.html; then echo "patch 334 - already in"; exit 0; fi
grep -q "patch 333" $D/home.html || { echo "patch 333 first"; exit 1; }
grep -q "function proEnsure(boxId,h)" $D/home.html || { echo "home.html: the chart code not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_334'
<style>/* patch 334: the iPad share page fits the screen - sized from the real visible height (Safari's bars counted), the chart buttons in 2 rows */
@media(min-width:900px) and (max-width:1279px){
  html body #focus.ws-on{overflow-y:auto !important;-webkit-overflow-scrolling:touch}
  html body #focus .ws{height:var(--gxwsh,calc(100vh - 260px)) !important;min-height:0 !important}
  html body #focus .ptb>span{order:3}
  html body #focus .ptb>span:first-child{order:1}
  html body #focus .ptb>span:last-child{order:2}
}
@media(min-width:1280px){ html body #focus .ws{height:var(--gxwsh,calc(100vh - 260px)) !important} }
</style>
<script>/* patch 334: the share page's boxes (iPad and laptop) end at the bottom of what the iPad really shows (window height, not Safari's 100vh) */
(function(){
  const mid=()=>innerWidth>=900&&innerWidth<1280, wide=()=>innerWidth>=900;
  let last="", EX=0;                                  /* EX = px added to the chart so it fills its box exactly */
  if(typeof proEnsure==="function"){ const PE=proEnsure; proEnsure=function(id,h){ if(id==="tvbox"&&wide()&&!document.body.classList.contains("gx-max-pro")) h=Math.max(260,h+EX); return PE(id,h); }; }
  function fill(){ try{ if(!wide()||document.body.classList.contains("gx-max-pro")) return; const px=document.getElementById("wsPx"); if(!px) return;
      const cv=[...px.querySelectorAll("#tvbox canvas")].map(c=>c.getBoundingClientRect()).filter(r=>r.height>5); if(!cv.length) return;
      const gap=Math.floor(px.getBoundingClientRect().bottom-Math.max(...cv.map(r=>r.bottom))-6);
      if(Math.abs(gap)>4){ EX=Math.max(-300,Math.min(400,EX+gap)); if(typeof PC!=="undefined"&&PC) PC.key=""; setTimeout(()=>{ try{ paint(); }catch(e){} },30); } }catch(e){} }
  function fit(){ try{ if(!wide()) return; const f=document.querySelector("#focus.ws-on"), ws=f&&f.querySelector(".ws"); if(!f||!ws) return;
      const top=ws.getBoundingClientRect().top-f.getBoundingClientRect().top+f.scrollTop;
      const h=Math.max(380,Math.floor(f.clientHeight-top-10)), v=h+"px";
      if(v!==last){ last=v; document.documentElement.style.setProperty("--gxwsh",v); if(typeof PC!=="undefined"&&PC) PC.key=""; setTimeout(()=>{ try{ paint(); }catch(e){} },30); }
      if(mid()) f.querySelectorAll(".ptb a").forEach(a=>{ const t=a.textContent.trim(); if((t==="CANDLES"||t==="LINE")&&!a.classList.contains("phx2")) a.classList.add("phx2"); });
      fill();
    }catch(e){} }
  window.addEventListener("resize",()=>{ last=""; setTimeout(fit,60); });
  window.addEventListener("orientationchange",()=>{ last=""; setTimeout(fit,300); });
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; fit(); },120); }).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  setInterval(fit,1500); fit(); })();
</script>
ADD_334
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: the share page fits the screen")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 334 done - on the iPad: close the share tab, refresh GIR HOME, open the share again - the whole chart and RSI fit."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
