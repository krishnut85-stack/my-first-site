#!/bin/bash
# PATCH 291 - THE PHONE: BIG MONEY, F&O MONEY and OPTIONS under ⋯ MORE showed nothing (Rama, 15 Nov: "it's showing in the laptop but not in the
#   mobile - something is wrong"). Since patch 155 the phone shows one page at a time and hides every other panel; the tabs under ⋯ MORE
#   (B BIG MONEY · 2 F&O MONEY · OPTIONS) were never given their panel on the phone, so only "the other pages are the buttons above" showed.
#   Now on the phone: B BIG MONEY -> the BIG MONEY table (+ the big hands below it), the wide table scrolls sideways · 2 F&O MONEY -> its panel
#   · OPTIONS -> its panel. The laptop is not touched. Page file only (home.html) + the dashboard restarted.
#   If the pre-290 page was put back for the test (home.html.p290 is there and has patch 290), the patch-290 page is put back first.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 291" $F; then echo "patch 291 - already in"; exit 0; fi
grep -q "patch 155" $F && grep -q "patch 184b" $F || { echo "home.html: patch 155 / 184b missing - nothing done, send this to Claude"; exit 1; }
if ! grep -q "patch 290" $F && [ -f $D/home.html.p290 ] && grep -q "patch 290" $D/home.html.p290; then
  cp $F $F.pre290test$TS; cp $D/home.html.p290 $F; echo "  the patch-290 page put back (the test copy kept as home.html.pre290test$TS)"
fi
cp $F $F.bak$TS
back(){ cp $F.bak$TS $F; systemctl restart gir-dash 2>/dev/null; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p291.py <<'PY_291'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
CSS = """
/* patch 291: the phone - the pages under ⋯ MORE get their panel (BIG MONEY · F&O MONEY · OPTIONS); before, only the hint showed */
@media(max-width:899px){
  body.mt-more.mk-big #mk #q-lnk{display:flex !important;flex-direction:column;order:1 !important;height:auto !important;max-height:none !important;grid-area:auto}
  body.mt-more.mk-big #mk #q-ins{display:flex !important;flex-direction:column;order:2 !important;height:auto !important;max-height:none !important}
  body.mt-more.mk-money #mk #q-mon{display:flex !important;flex-direction:column;order:1 !important;height:auto !important;max-height:none !important}
  body.mt-more.mk-money #mk #q-ins{display:flex !important;flex-direction:column;order:2 !important;height:auto !important;max-height:none !important}
  body.mt-more.mk-opts #mk #q-idx{display:flex !important;flex-direction:column;order:1 !important;height:auto !important;max-height:none !important}
  body.mt-more.mk-big #mk::before,body.mt-more.mk-money #mk::before,body.mt-more.mk-opts #mk::before{display:none !important}
  body.mt-more.mk-big #mk #q-lnk .bd{overflow-x:auto !important;overflow-y:visible !important;max-height:none !important;-webkit-overflow-scrolling:touch}
  body.mt-more.mk-big #mk-lnk table{font-size:12px}body.mt-more.mk-big #mk-lnk td,body.mt-more.mk-big #mk-lnk th{padding:4px 6px}
  body.mt-more.mk-money #mk .bd,body.mt-more.mk-opts #mk .bd,body.mt-more.mk-big #mk #q-ins .bd{overflow:visible}
}
</style>"""
if s.count("</style>") < 1:
    print("❌ home.html: no </style>"); sys.exit(1)
s = s.replace("</style>", CSS, 1)
open(p, "w", encoding="utf-8").write(s)
print("  home.html: BIG MONEY · F&O MONEY · OPTIONS show on the phone under ⋯ MORE")
PY_291
python3 $W/p291.py $F || back
grep -q "patch 291" $F || back
if command -v node >/dev/null 2>&1; then
  python3 - $F $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 291 done - on the phone: ⋯ MORE -> B BIG MONEY / 2 F&O MONEY / OPTIONS now show their page. Close the GIR tab on the phone and open it again."
echo "   undo: cp $F.bak$TS $F; systemctl restart gir-dash"
