#!/bin/bash
# PATCH 312 - THE PHONE: THE SEARCH BOX AND THE NEWS FIT THE SCREEN (Rama, 15 Nov: "ticker and type a share is not fitting inside properly" ·
#   "news should be fitting in one page"). On the phone: the search hint is "Search share" (the long "TICKER · type a share, Enter = FOCUS" was
#   cut off); every news headline wraps onto the next line instead of running off the right edge. The laptop unchanged. Edits home.html. Refresh.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 312" $D/home.html; then echo "patch 312 - already in"; exit 0; fi
grep -q 'id="q"' $D/home.html || { echo "home.html: the search box not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/css.html <<'CSS_312'
<style>/* patch 312: the phone - every news headline fits the screen (wraps onto the next line instead of running off the right edge) */
@media(max-width:899px){
  html body #q-nws,html body #q-nws .bd{overflow-x:hidden !important;max-width:100% !important}
  html body #q-nws .bd *{white-space:normal !important;text-overflow:clip !important;overflow-wrap:anywhere !important;max-width:100% !important}
  html body #q-nws .bd table{table-layout:fixed !important;width:100% !important}
}
</style>
CSS_312
cat > $W/js.html <<'JS_312'
<script>/* patch 312: the phone - the search box hint short enough to fit ("Search share"); the laptop keeps the long one */
(function(){ const q=document.getElementById("q"); if(!q) return; const LONG=q.placeholder;
  function fit(){ q.placeholder=window.innerWidth<900?"Search share":LONG; } fit(); window.addEventListener("resize",fit); })();
</script>
JS_312
python3 - $D/home.html $W/css.html $W/js.html <<'PY_EDIT' || back
import sys
h, c, j = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip(), open(sys.argv[3], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</head>") != 1 or t.count("</body>") != 1:
    print("❌ home.html: </head> x%d, </body> x%d - send this to Claude" % (t.count("</head>"), t.count("</body>"))); sys.exit(1)
t = t.replace("</head>", c + "\n</head>", 1).replace("</body>", j + "\n</body>", 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: the phone - 'Search share', the news headlines wrap to fit")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 312 done - the phone: the search box says 'Search share', the news fits the screen. Close the GIR tab and open it again."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
