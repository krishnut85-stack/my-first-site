#!/bin/bash
# PATCH 310 - THE PHONE: THE TOP SMALLER (Rama, 15 Nov: "also small: the tabs, sign out, NIFTY and SENSEX, ticker, go, all sectors").
#   Phone only - the laptop is unchanged: GIR + SIGN OUT narrower, the NIFTY / SENSEX / BANKNIFTY / VIX boxes smaller (price 15 px),
#   the TICKER · GO · ALL SECTORS row thinner -> the chart and F&O MOVERS move up. Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 310" $D/home.html; then echo "patch 310 - already in"; exit 0; fi
grep -q "patch 309" $D/home.html || { echo "patch 309 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/css.html <<'CSS_310'
<style>/* patch 310: the phone - the top smaller: GIR + SIGN OUT, the NIFTY / SENSEX / BANKNIFTY / VIX boxes, the TICKER · GO · ALL SECTORS row */
@media(max-width:899px){
  html body #idx{gap:4px !important;padding:4px 6px !important}
  html body #idx .brand{font-size:12px !important;padding:0 8px !important}
  html body #idx .ix{min-width:96px !important;padding:2px 8px !important}
  html body #idx .ix span{font-size:15px !important;line-height:1.15 !important}
  html body #idx .ix small,html body #idx .ix b,html body #idx .ix em{font-size:10px !important;line-height:1.2 !important}
  html body #idx.skn #sikey{width:62px !important;font-size:10px !important;letter-spacing:.04em !important;padding:0 4px !important}
  html body #cmd{padding:3px 6px !important;gap:4px !important}
  html body #cmd input,html body #cmd button,html body #cmd select{height:28px !important;min-height:0 !important;font-size:11px !important;padding-top:0 !important;padding-bottom:0 !important}
  html body #cmd .pr{font-size:12px !important}
}
</style>
CSS_310
python3 - $D/home.html $W/css.html <<'PY_EDIT' || back
import sys
h, c = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</head>") != 1:
    print("❌ home.html: </head> x%d - send this to Claude" % t.count("</head>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</head>", c + "\n</head>", 1)); print("  home.html: the phone - the top smaller")
PY_EDIT
echo "✅ patch 310 done - the phone: GIR, SIGN OUT, the NIFTY / SENSEX boxes and the TICKER row smaller. Close the GIR tab and open it again."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
