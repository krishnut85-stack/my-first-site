#!/bin/bash
# PATCH 245 - every big mover shows its push reading (Rama, 13 Nov 10:07: "for GVT&D there is no reason given - at least something is driving it").
#   The server read GVT&D +5.3%, MCX, CUMMINSIND, ANGELONE as 🔵 OWN MOVE (moving on its own - no futures, option or deal money proven), but the
#   page drew the dot only when someone was NAMED pushing or pulling. Now the dot shows whenever there is a reading; the hover says
#   "0 pushing up · 0 pulling down" and the OWN MOVE line. Tested in a browser (old page: nothing; new: 🔵 + the reading).
#   Page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 219" $D/home.html || { echo "patch 219 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p245_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p245_patch.py - PATCH 245: every big mover shows its push reading (Rama, 13 Nov 10:07: "for GVT&D there is no reason given - at least something is
driving it"). The server read GVT&D +5.3%, MCX, CUMMINSIND, ANGELONE as 🔵 OWN MOVE (moving on its own, no futures / option / deal money proven),
but the page drew the dot only when someone was NAMED pushing or pulling. Now the dot shows whenever there is a reading; the hover says
"0 pushing up · 0 pulling down" and the OWN MOVE line. Page only. Usage: python3 p245_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); S = {"s": open(p, encoding="utf-8").read()}
ERR = []


def rep(old, new, tag):
    s = S["s"]
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  home.html: %s" % tag)


rep('''function ppBadge(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length)) return "";''',
    '''function ppBadge(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length||r.kind)) return "";   /* patch 245: OWN MOVE with nobody named still shows */''', "the badge: shown when there is a reading")
rep('''function ppDot(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length)) return "";''',
    '''function ppDot(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length||r.kind)) return "";   /* patch 245 */''', "the dot: shown when there is a reading")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 245 in")
PY_PATCH
python3 $W/p245_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 245 done - reload every GIR tab (Ctrl + Shift + R)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
