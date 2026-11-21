#!/bin/bash
# PATCH 340 - THE EARLY LIST SCROLLS (Rama, 16 Nov: "as the messages increase it keeps pushing down the panels below - we need a scroll").
#   Laptop / iPad Pro (1100 px and wider): the open EARLY list stays about 3 rows tall with its own scroll ("↓ scroll for N more" beside its
#   title); F&O DESK, SECTORS, ROTATION and OI SCENARIOS stay where they are however many shares come in (ROTATION 668 px instead of 842).
#   Phone unchanged. Edits home.html only. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 340" $D/home.html; then echo "patch 340 - already in"; exit 0; fi
grep -q "patch 339" $D/home.html || { echo "patch 339 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_340'
<style>/* patch 340: laptop - the EARLY list scrolls inside its own box (about 3 rows) instead of pushing the market panels down */
@media(min-width:1100px){
  html body.earopen #q-ear .bd,html body #q-ear .bd{max-height:min(200px,26vh) !important;overflow-y:auto !important;-webkit-overflow-scrolling:touch}
  #q-ear h3 .gxe-more{margin-left:10px;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;color:#f5a623;white-space:nowrap}
}
</style>
<script>/* patch 340: "↓ scroll for N more" beside the EARLY title when its list is longer than its box (laptop) */
(function(){
  function tick(){ try{ const q=document.getElementById("q-ear"), bd=q&&q.querySelector(".bd"), h=q&&q.querySelector("h3"); if(!h) return;
      let m=h.querySelector(".gxe-more");
      const rows=bd?[...bd.querySelectorAll("tr")].filter(r=>r.offsetParent):[], seen=bd?rows.filter(r=>r.offsetTop+r.offsetHeight<=bd.scrollTop+bd.clientHeight+2).length:0, more=rows.length-seen;
      const want=innerWidth>=1100&&bd&&getComputedStyle(bd).display!=="none"&&more>0?`↓ scroll for ${more} more`:"";
      if(!want){ if(m) m.remove(); return; }
      if(!m){ m=document.createElement("span"); m.className="gxe-more"; h.appendChild(m); }
      if(m.textContent!==want) m.textContent=want; }catch(e){} }
  document.addEventListener("scroll",e=>{ if(e.target&&e.target.id==="mk-ear") tick(); },true);
  setInterval(tick,1500); tick(); })();
</script>
ADD_340
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: the EARLY list scrolls (laptop)")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 340 done - refresh GIR HOME: EARLY scrolls inside its box, the panels below stay put."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
