#!/bin/bash
# PATCH 311 - THE PHONE: THE TOP IN 2 SHORT ROWS, NO SIDEWAYS SCROLL (Rama, 15 Nov: "I didn't want scroll sideways on top - make it small and all
#   the details visible; no need for 'CLOSED 42 alerts' on the mobile"). Phone only - the laptop is unchanged:
#     GIR      | NIFTY  | BANKNIFTY
#     SIGN OUT | SENSEX | VIX
#   every price and change on the screen at once; the clock / CLOSED / alerts line hidden on the phone. Edits home.html only. Refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 311" $D/home.html; then echo "patch 311 - already in"; exit 0; fi
grep -q "patch 310" $D/home.html || { echo "patch 310 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/css.html <<'CSS_311'
<style>/* patch 311: the phone - the top in 2 short rows, everything on screen, no sideways scroll: GIR / SIGN OUT · NIFTY / SENSEX · BANKNIFTY / VIX;
   the clock / CLOSED / alerts line hidden on the phone (the laptop unchanged) */
@media(max-width:899px){
  html body #idx{display:grid !important;grid-template-columns:58px minmax(0,1fr) minmax(0,1fr) !important;grid-template-rows:auto auto !important;grid-auto-flow:column !important;
    gap:4px !important;padding:4px 6px !important;width:100% !important;max-width:100vw !important;box-sizing:border-box !important;overflow:visible !important}
  html body #idx>.st{display:none !important}
  html body #idx .brand{grid-column:1 !important;grid-row:1 !important;margin:0 !important;font-size:11px !important;padding:0 4px !important;min-width:0 !important;height:auto !important}
  html body #idx.skn #sikey{grid-column:1 !important;grid-row:2 !important;width:auto !important;min-width:0 !important;font-size:9px !important;letter-spacing:.03em !important;padding:0 2px !important}
  html body #idx .ix{min-width:0 !important;width:auto !important;padding:3px 8px !important;overflow:hidden}
  html body #idx .ix span{font-size:14px !important;line-height:1.15 !important}
  html body #idx .ix small,html body #idx .ix b,html body #idx .ix em{font-size:10px !important;line-height:1.2 !important;white-space:nowrap}
}
</style>
CSS_311
python3 - $D/home.html $W/css.html <<'PY_EDIT' || back
import sys
h, c = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</head>") != 1:
    print("❌ home.html: </head> x%d - send this to Claude" % t.count("</head>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</head>", c + "\n</head>", 1)); print("  home.html: the phone - the top in 2 rows, no sideways scroll")
PY_EDIT
echo "✅ patch 311 done - the phone: the top in 2 rows (GIR / SIGN OUT · NIFTY / SENSEX · BANKNIFTY / VIX), no sideways scroll. Close the GIR tab and open it again."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
