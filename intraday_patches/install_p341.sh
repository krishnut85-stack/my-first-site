#!/bin/bash
# PATCH 341 - HOTFIX: THE LAPTOP SHARE CHART STOPS JUMPING (Rama, 16 Nov 08:00: "something happened with the share chart page - it keeps jumping").
#   Patch 334 (made for the iPad) also resized the laptop's share chart to "fill its box"; with the FUTURES BY MONTH line and a tall "who is
#   pulling" box the chart could never fit, so it kept re-measuring and redrawing. Now: that resizing runs on the iPad only (900-1279 px), the
#   laptop draws its share chart as before 334, and even on the iPad it corrects at most 4 times (never a loop). Edits home.html only. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 341" $D/home.html; then echo "patch 341 - already in"; exit 0; fi
grep -q "patch 334" $D/home.html || { echo "patch 334 is not in this page - nothing to fix"; exit 0; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/edits.json <<'EDITS_341'
[
[
"const mid=()=>innerWidth>=900&&innerWidth<1280, wide=()=>innerWidth>=900;",
"const mid=()=>innerWidth>=900&&innerWidth<1280, wide=()=>innerWidth>=900&&innerWidth<1280;   /* patch 341: iPad only - on the laptop it made the chart jump */"
],
[
"@media(min-width:1280px){ html body #focus .ws{height:var(--gxwsh,calc(100vh - 260px)) !important} }",
"/* patch 341: the laptop keeps its own share-page height */"
],
[
"if(Math.abs(gap)>4){",
"if(Math.abs(gap)>4&&(window.GX334N=(window.GX334N||0)+1)<=4){"
],
[
"window.addEventListener(\"resize\",()=>{ last=\"\"; setTimeout(fit,60); });",
"window.addEventListener(\"resize\",()=>{ last=\"\"; window.GX334N=0; setTimeout(fit,60); });"
]
]
EDITS_341
python3 - $D/home.html $W/edits.json <<'PY_EDIT' || back
import sys, json
h, R = sys.argv[1], json.load(open(sys.argv[2], encoding="utf-8"))
t = open(h, encoding="utf-8").read()
for a, b in R:
    if t.count(a) != 1:
        print("❌ home.html: a patch 334 line found %d times - nothing changed, send this to Claude" % t.count(a)); sys.exit(1)
    t = t.replace(a, b, 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: the laptop share chart no longer resizes itself (iPad keeps its fit)")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 341 done - on the laptop: close the share tab, open the share again - the chart stays still."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
