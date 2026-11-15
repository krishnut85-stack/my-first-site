#!/bin/bash
# PATCH 309 - THE PHONE: SMALL ICON TABS, THE CHART UP, F&O MOVERS IN VIEW (Rama, 15 Nov: "make tab icons for the mobile above the NIFTY chart,
#   keep them small, the chart can be up a bit and the F&O movers clearly visible"). Phone only - the laptop is unchanged:
#   · the tabs (HOME TRADE MONEY SECTORS NEWS OPTIONS MORE): an icon with a short word under it, all 7 across the screen, no scrolling;
#     the open one in amber with a line under it, TRADE's red count as a small bubble
#   · the chart: its title line hidden, the buttons smaller, the box a little shorter (260 px, was 320) -> F&O MOVERS starts higher
#   Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 309" $D/home.html; then echo "patch 309 - already in"; exit 0; fi
grep -q "patch 155" $D/home.html || { echo "home.html: the phone tabs (patch 155) not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/css.html <<'CSS_309'
<style>/* patch 309: the phone - small icon tabs, the chart a little shorter, F&O MOVERS higher up (the laptop unchanged) */
@media(max-width:899px){
  #mtab{gap:0 !important;padding:2px 2px !important;justify-content:space-between}
  #mtab a{position:relative;flex:1 0 auto !important;min-width:48px;display:flex;flex-direction:column;align-items:center;gap:3px;padding:5px 3px 5px !important;border:0 !important;border-radius:6px !important;background:transparent !important;color:var(--dim,#8b98a8) !important;font:700 9px/1 var(--ui,system-ui) !important;letter-spacing:.04em !important}
  #mtab a i{font-style:normal;font-size:17px;line-height:1}
  #mtab a.on{color:var(--amber,#ffb347) !important;box-shadow:inset 0 -2px 0 var(--amber,#ffb347)}
  #mtab a b{position:absolute;top:1px;right:4px;margin:0 !important;font-size:9px;line-height:1;background:var(--dn,#ff5c5c);color:#fff !important;border-radius:8px;padding:2px 4px}
  body.mt-home #mk #q-nif{height:260px !important}
  body.mt-home #mk #q-nif>h3{display:none !important}
  body.mt-home #mk-nif .ixw .ptb{gap:2px 3px !important;padding:2px 3px !important}
  body.mt-home #mk-nif .ixw .ptb a{padding:3px 5px !important;font-size:10px !important}
}
</style>
CSS_309
cat > $W/js.html <<'JS_309'
<script>/* patch 309: the phone tabs as small icons with a short word under each */
(function(){ try{ if(typeof MTABS==="undefined") return;
  const L={home:["⌂","HOME"],trade:["🟧","TRADE"],money:["₹","MONEY"],sect:["▤","SECTORS"],news:["📰","NEWS"],opt:["⚙","OPTIONS"],more:["⋯","MORE"]};
  MTABS.forEach(t=>{ const x=L[t[0]]; if(x) t[1]=`<i>${x[0]}</i>${x[1]}`; }); if(typeof mtDraw==="function") mtDraw(); }catch(e){} })();
</script>
JS_309
python3 - $D/home.html $W/css.html $W/js.html <<'PY_EDIT' || back
import sys
h, c, j = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip(), open(sys.argv[3], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</head>") != 1 or t.count("</body>") != 1:
    print("❌ home.html: </head> x%d, </body> x%d - send this to Claude" % (t.count("</head>"), t.count("</body>"))); sys.exit(1)
t = t.replace("</head>", c + "\n</head>", 1).replace("</body>", j + "\n</body>", 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: the phone - icon tabs, the chart smaller, F&O MOVERS higher")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 309 done - the phone: small icon tabs, the chart a little shorter, F&O MOVERS higher. Refresh the page on the phone."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
