#!/bin/bash
# PATCH 251 - the phone: the round ⌂ button at the bottom right is gone (Rama, 13 Nov: "two home buttons, one hides the share percentage").
#   HOME stays: ⌂ GIR top left, the ⌂ HOME tab, ⌂ HOME on every share screen. Tested on a phone-size browser. Page only - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p251_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p251_patch.py - PATCH 251: the phone - the round ⌂ button at the bottom right is gone (Rama, 13 Nov: "two home buttons, one hides the share
percentage" - it covered the right column of F&O MOVERS). HOME stays: ⌂ GIR top left, the ⌂ HOME tab, ⌂ HOME on every share screen.
Page only. Usage: python3 p251_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
NEW = '''#mhome{display:none !important}   /* patch 251: the round ⌂ hid the % column - HOME is top left, in the tabs and on every share */
</style>'''
if "patch 251" in s:
    print("  home.html: the round ⌂ button removed - already in")
elif s.count("</style>") != 1:
    print("❌ home.html: </style> found %d times" % s.count("</style>")); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace("</style>", NEW)); print("  home.html: the round ⌂ button removed")
print("patch 251 in")
PY_PATCH
python3 $W/p251_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 251 done - reload GIR on the phone (pull down to refresh, or close and reopen the tab)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
