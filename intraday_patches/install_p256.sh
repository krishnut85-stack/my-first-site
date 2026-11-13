#!/bin/bash
# PATCH 256 - a share's own tab is ONE page (Rama, 13 Nov: "the home page is behind and POLICYBZR on top - two scroll bars; only the GIR button
#   on top, then the share - a separate page"). In a share's tab on the laptop the home page is no longer drawn underneath; the top is one slim
#   line - ⌂ GIR (back to the home tab) - and the share screen is the only thing that scrolls. The home tab is unchanged.
#   Tested in a browser (old: the home page under the share + a 2nd scroll bar; new: one page). Page only - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p256_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p256_patch.py - PATCH 256: a share's own tab is ONE page (Rama, 13 Nov: "the home page is behind and POLICYBZR on top - two scroll bars;
only the GIR button on top, then the share - a separate page"). The share's tab loaded the whole home page under the share screen. Now, in a
share's tab (laptop): the home page is not drawn at all, the top bar is one slim line - ⌂ GIR (back to the home tab) and the share - and the
share screen is the only thing that scrolls. The home tab is unchanged. Page only. Usage: python3 p256_patch.py DIR"""
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


rep('''</style>''', '''/* patch 256: a share's own tab is one page - only the share, one scroll bar, ⌂ GIR on top */
#soloBar{display:none}
@media(min-width:900px){
  body.solo{overflow:hidden}
  body.solo #grid>*:not(#focus),body.solo #idxrow,body.solo #mhome{display:none !important}
  body.solo #top>:not(#soloBar){display:none !important}
  body.solo #top{height:auto !important;min-height:0 !important;display:block !important;padding:0 !important;border-bottom:1px solid var(--line)}
  body.solo #soloBar{display:flex;align-items:center;gap:14px;padding:6px 12px}
  body.solo #soloBar .brand{cursor:pointer;border-radius:6px;font:700 17px/1 var(--ui);letter-spacing:.08em;padding:8px 18px;background:var(--amber);color:#1a1205;user-select:none}
  body.solo #soloBar .brand:hover{filter:brightness(1.1)}
  body.solo #soloBar .t{color:var(--dim);font:500 12px var(--ui)}}
</style>''', "the share's tab: one page, one scroll bar")
rep('''if(SOLO){ document.body.classList.add("solo"); VIEW="all"; document.title=SOLO; }''',
    '''if(SOLO){ document.body.classList.add("solo"); VIEW="all"; document.title=SOLO;
  try{ const sb=document.createElement("div"); sb.id="soloBar"; sb.innerHTML='<div class="brand" onclick="goHome()" title="back to the GIR home tab">⌂ GIR</div><span class="t">'+SOLO+' · its own tab · ⌂ GIR = back to the home tab</span>'; $("top").prepend(sb); }catch(e){} }   /* patch 256 */''',
    "⌂ GIR bar on top of the share's tab")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 256 in")
PY_PATCH
python3 $W/p256_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 256 done - close the share tabs and open a share again from the home tab (Ctrl + Shift + R on the home tab first)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
