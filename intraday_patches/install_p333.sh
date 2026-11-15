#!/bin/bash
# PATCH 333 - THE iPAD SHARE PAGE FIXED (Rama, 15 Nov: "no price on top, no share list - many are missing on the iPad").
#   Patch 327 laid a share's page over the whole iPad screen (900-1279 px): a share opened in its own tab lost its top bar (⌂ GIR · the name,
#   price and change · COCKPIT), and the share list was hidden. Now: the top bar stays on top, the SHARE LIST is back on the left, the chart in
#   the middle, the option chain and the checklist on the right. Phone and laptop unchanged.
#   Edits home.html only. Tested at 900 / 1024 / 1080 / 1194 / 1279 / 1440 px. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 333" $D/home.html; then echo "patch 333 - already in"; exit 0; fi
grep -q "patch 332" $D/home.html || { echo "patch 332 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_333'
<style>/* patch 333: the iPad share page (900-1279 px) - the price header back on top (a share in its own tab: the top bar) and the SHARE LIST back */
@media(min-width:900px) and (max-width:1279px){
  html body.solo #focus.ws-on{top:var(--gxsolo,59px) !important;z-index:25 !important}
  html body #focus .ws{grid-template-columns:minmax(168px,188px) minmax(0,1.55fr) minmax(0,1fr) !important;height:calc(100vh - var(--gxsolo,0px) - 190px) !important}
  html body #focus .ws>#wsList{display:block !important;grid-column:1 !important;grid-row:1 / span 2 !important;overflow:auto !important;min-width:0}
  html body #focus .ws>#wsPx{grid-column:2 !important;grid-row:1 / span 2 !important}
  html body #focus .ws>#wsOi{grid-column:3 !important;grid-row:1 !important}
  html body #focus .ws>#wsOc{grid-column:3 !important;grid-row:2 !important}
}
</style>
<script>/* patch 333: the top bar's real height (it can wrap to 2 lines on an iPad) */
(function(){ function fit(){ try{ const b=document.getElementById("soloBar"); const h=b&&document.body.classList.contains("solo")&&getComputedStyle(b).display!=="none"?Math.ceil(b.getBoundingClientRect().bottom):0;
    document.documentElement.style.setProperty("--gxsolo",(h||0)+"px"); }catch(e){} }
  window.addEventListener("resize",fit); setInterval(fit,2000); fit(); })();
</script>
ADD_333
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: the iPad share page")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 333 done - on the iPad: refresh, open a share - the price on top, the share list on the left."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
