#!/bin/bash
# PATCH 171 - on the laptop the ⚡ EARLY alert board is FOLDED by default (Rama: "it should show when I click - otherwise the other
#   sections shrink"). Its header stays (today · N BUY · N shares); tap the header to open / fold. The browser remembers your choice.
#   The market panels get the room. The phone layout is not changed. The page file only - nothing restarts; reload the page.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S)
[ -f $F ] || { echo "home.html not found"; exit 1; }
cp $F $F.bak$TS
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
if "patch 171" in s:
    print("patch 171 is already in home.html"); sys.exit(0)
E = [
 ('body.mclosed:not(.earopen) #q-ear .bd{display:none}',
  'body.mclosed:not(.earopen) #q-ear .bd{display:none}\n@media(min-width:900px){body:not(.earopen) #q-ear .bd{display:none}   /* patch 171: folded until tapped (laptop) */\n'
  '  body:not(.earopen) #q-ear h3::after{content:"▸ tap to open the alert board";color:var(--am,#f5a524);margin-left:auto;font-weight:600}\n'
  '  body:not(.earopen) #mk #q-ear{height:auto !important;min-height:0}}'),
 ('function earToggle(){ document.body.classList.toggle("earopen"); }',
  'function earToggle(){ const o=document.body.classList.toggle("earopen"); try{ localStorage.setItem("gir_ear",o?"1":"0"); }catch(e){} }   /* patch 171: remembered */\n'
  'try{ if(localStorage.getItem("gir_ear")==="1") document.body.classList.add("earopen"); }catch(e){}'),
]
for a, b in E:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:60])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("the EARLY board folds until tapped")
PY
[ $? = 0 ] && grep -q "patch 171" $F && echo "PATCH 171 APPLIED - reload girtrader.com (Ctrl + Shift + R on the laptop). Tap ⚡ EARLY to open it, tap again to fold." \
  || { cp $F.bak$TS $F; echo "not applied - old page back; send this to Claude"; exit 1; }
