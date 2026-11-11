#!/bin/bash
# PATCH 191b - the search box: on a laptop Enter opens the share in its own tab; the main page kept the name in the box and its
#   suggestion stayed over the page (CUB, 11 Nov). Now the box clears and closes. The page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS
cat > $W/p191b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p191b_patch.py - PATCH 191b: the search box (Rama, 11 Nov: "I searched CUB and entered - it opened another page, fine, but the CUB
remained there"). On a laptop Enter opens the share in its own tab and the main page kept 'CUB' in the box - coming back to the tab
showed the suggestion again and it stayed over the page. Now the box is cleared and closed when the share's tab opens.
Usage: python3 p191b_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
old = '''  if(!SOLO&&!focusOn.inner&&wsWide()){ openWin(sym); return; }'''
new = '''  if(!SOLO&&!focusOn.inner&&wsWide()){ $("q").value=""; sugHide(); try{ $("q").blur(); }catch(e){} openWin(sym); return; }   /* patch 191b: the box is cleared when the share's tab opens */'''
old2 = '''$("q").addEventListener("focus",()=>{ if($("q").value&&!FOC){ SUG=sugList($("q").value); sugDraw(); } });'''
new2 = '''$("q").addEventListener("focus",()=>{ if($("q").value&&!FOC&&!wsWide()){ SUG=sugList($("q").value); sugDraw(); } });   /* patch 191b */
document.addEventListener("pointerdown",e=>{ if(SUG.length&&!(e.target.closest&&e.target.closest("#cmd"))) sugHide(); });   /* patch 191b: a click anywhere else closes it */
document.addEventListener("visibilitychange",()=>{ if(!document.hidden&&wsWide()&&SUG.length) sugHide(); });'''
if "patch 191b" in s:
    print("already in"); sys.exit(0)
for o in (old, old2):
    if s.count(o) != 1:
        print("anchor not found: " + o[:60]); sys.exit(1)
s = s.replace(old, new).replace(old2, new2)
open(p, "w", encoding="utf-8").write(s); print("home.html: the search box closes when the share's tab opens")
PY_PATCH
python3 $W/p191b_patch.py $D || { cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back"; exit 1; }
grep -q "patch 191b" $D/home.html && echo "✅ done - press Ctrl + Shift + R on GIR. Type a share + Enter: its tab opens and the box on the main page clears."
