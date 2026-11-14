#!/bin/bash
# PATCH 240 - SELF-CHECK: "OI BUILD-UP CHART / TABLE: FAIL" was the check, not the OI build-up (Rama's photo, 13 Nov 07:55, PAGEIND).
#   On a window narrower than 900 px (a zoomed-in browser too) the share screen shows one tab at a time; the check read the open tab - the PRO
#   price chart - and called the OI build-up broken. Now it opens the OI BUILD-UP tab first, needs real strikes to pass, says what it measured,
#   and puts your tab and BARS / TABLE / OPTION CHAIN choice back.
#   Tested in a browser: the old page reproduces FAIL / FAIL; the new one passes narrow and wide, and fails on an empty build-up.
#   Page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 238" $D/home.html || { echo "patch 238 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p240_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p240_patch.py - PATCH 240: SELF-CHECK - "OI BUILD-UP CHART / TABLE: FAIL" was the check, not the OI build-up (Rama's photo, 13 Nov 07:55).
On a window narrower than 900 px (a zoomed-in browser too) the share screen shows one tab at a time; the check read the open tab - the PRO price
chart, 37 characters - and called the OI build-up broken. Now it opens the OI BUILD-UP tab first, then puts your tab and BARS / TABLE choice back,
and says what it measured. Page only. Usage: python3 p240_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
old = '''    for(const m of ["chart","table"]){ oiMode(m); await sleep(500); add("SHARE "+sym,"OI BUILD-UP "+m.toUpperCase(),(($("wsOiB")||$("fbody")||{}).innerText||"").length>80?"PASS":"FAIL"); }
    oiMode("chart");'''
new = '''    { const ft_=FTAB, om_=OIMODE;                                  // patch 240: one tab at a time (narrow window) -> open the OI BUILD-UP tab first
      for(const m of ["chart","table"]){ if(!wsWide()) FTAB="oi"; oiMode(m); await sleep(500); const bx_=$("wsOiB")||$("fbody"), n_=((bx_||{}).innerText||"").length;
        add("SHARE "+sym,"OI BUILD-UP "+m.toUpperCase(),n_>80&&oiRows().length?"PASS":"FAIL",`${wsWide()?"wide screen":"one tab at a time"} · ${n_} characters · ${oiRows().length} strikes`); }
      FTAB=ft_; oiMode(om_); }'''
if new in s:
    print("  home.html: self-check opens the OI BUILD-UP tab - already in")
elif s.count(old) != 1:
    print("❌ anchor found %d times" % s.count(old)); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  home.html: self-check opens the OI BUILD-UP tab")
print("patch 240 in")
PY_PATCH
python3 $W/p240_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 240 done - reload every GIR tab (Ctrl + Shift + R), then ✓ SELF-CHECK → run again."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
