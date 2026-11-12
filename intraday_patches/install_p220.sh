#!/bin/bash
# PATCH 220 - the chart's ACT mark in its side's colour (Rama, 12 Nov: "so here the ACT is red colour" - PAYTM's P1 call was an UP arrow,
#   a CE, drawn RED; red meant "urgent" but reads as "down"). Now: ACT ▲ CE green · ACT ▼ PE red · no side: amber. Page only - no restart,
#   safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p220_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p220_patch.py - PATCH 220: the chart's ACT mark in the colour of its side (Rama, 12 Nov: "so here the ACT is red colour" - PAYTM's P1 call
was an UP arrow, a CE, drawn RED: red meant "urgent", it read as "down"). Now: ACT ▲ CE green · ACT ▼ PE red · no side: amber. Page only.
Usage: python3 p220_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
A = [('''color:tr==="act"?dn:tr==="move"?"#ffb000":"#7d8b9c",shape:upS?"arrowUp":"arrowDown",text:tr==="act"?"ACT":""}); });''',
      '''color:tr==="act"?(r.side==="CE"?up:r.side==="PE"?dn:"#ffb000"):tr==="move"?"#ffb000":"#7d8b9c",shape:upS?"arrowUp":"arrowDown",text:tr==="act"?(r.side==="CE"?"ACT ▲ CE":r.side==="PE"?"ACT ▼ PE":"ACT"):""}); });   /* patch 220: ACT in its side's colour */'''),
     ('''if(m.text==="ACT"){ o.text="ACT"; o.color=m.color; }''', '''if(/^ACT/.test(m.text)){ o.text=m.text; o.color=m.color; }''')]
for old, new in A:
    if new in s:
        print("  already in"); continue
    if s.count(old) != 1:
        print("❌ anchor found %d times: %s" % (s.count(old), old[:60])); sys.exit(1)
    s = s.replace(old, new); print("  home.html: %s" % new[:50])
open(p, "w", encoding="utf-8").write(s)
print("patch 220 in")
PY_PATCH
python3 $W/p220_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 220 done - reload GIR. A CE call shows a green ACT ▲ CE, a PE call a red ACT ▼ PE."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
