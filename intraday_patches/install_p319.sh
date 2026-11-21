#!/bin/bash
# PATCH 319 - MORE -> 6 NEWS AND 7 PICKS HIDDEN (Rama, 15 Nov: "news everywhere · if TODAY is on top, why do we need them in MORE").
#   News lives in two places only: the NEWS tab (every headline) and ◉ TODAY (news for your checklist shares). PICKS came from the older
#   rules and contradicted the checklist / cockpit - hidden. The keys 6 / 7 and a saved NEWS / PICKS page open MARKET instead. Laptop and
#   phone. Edits home.html only (nothing deleted - undo brings them back). No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 319: MORE" $D/home.html; then echo "patch 319 - already in"; exit 0; fi
grep -q "data-v=\"picks\"" $D/home.html || { echo "home.html: the PICKS key not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_319'
<style>/* patch 319: MORE -> 6 NEWS and 7 PICKS hidden (laptop and phone) - news lives in the NEWS tab (all headlines) and ◉ TODAY (your shares);
   PICKS came from the older rules and contradicted the checklist / cockpit */
#fkeys a[data-v="news"],#fkeys a[data-v="picks"]{display:none !important}
</style>
<script>/* patch 319: the keys 6 / 7 and a saved NEWS / PICKS page open MARKET instead */
(function(){ try{ if(typeof setView==="function"){ const O=setView; setView=function(v){ if(v==="news"||v==="picks") v="market"; return O.apply(this,[v].concat([].slice.call(arguments,1))); }; }
  setTimeout(()=>{ try{ if(typeof VIEW!=="undefined"&&(VIEW==="news"||VIEW==="picks")) setView("market"); }catch(e){} },300); }catch(e){} })();
</script>
ADD_319
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 319")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  for f in home.html; do
    python3 - $D/$f $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
    node --check $W/page.js 2>$W/js.err || { echo "❌ $f:"; head -5 $W/js.err; back; }
  done
  echo "  the page code checked ✓"
fi
echo "✅ patch 319 done - NEWS and PICKS gone from MORE (laptop and phone). Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
