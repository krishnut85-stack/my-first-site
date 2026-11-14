#!/bin/bash
# PATCH 207b - the alert counts and the quiet list on the PHONE (Rama: "is this update for the mobile also - the alerts").
#   Under the phone's alert strip: 🔴 P1 · 🟠 P2 · 🟡 P3 - tap it and the quiet (P3) alerts open, one row a share (the same list as the
#   laptop's ALERTS box and the Telegram digest); tap again to fold. The page only - no restart, safe any time. Needs patch 207.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 207: short bars" $D/home.html || { echo "patch 207 is not in - run install_p207.sh first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p207b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p207b_patch.py - PATCH 207b: the alert counts and the quiet list on the PHONE (Rama, 11 Nov: "is this update for the mobile also -
the alerts"). Under the phone's alert strip one line: 🔴 P1 · 🟠 P2 · 🟡 P3 - tap it: the quiet (P3) alerts, one row a share, the same
list as the laptop's ALERTS box and the Telegram digest; tap again to fold it. Remembered on the phone. Usage: python3 p207b_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  home.html: %s" % tag)


rep('''  const dgH=(()=>{ if(!TC) return ""; const W={}, wo=[];''', '''  const dgH=(()=>{ const W={}, wo=[];   /* patch 207b: the phone too */''', "the counts on every screen")
rep('''    return `<div class="dg"><div class="dgh"><span class="p1">🔴 P1 ${nP1}</span><span class="p2">🟠 P2 ${nP2}</span><span class="p3">🟡 P3 ${nP3}</span><span class="dim">P1 · P2 in TRADE NOW ↓</span></div>`+''',
    '''    return `<div class="dg${TC||DGO?" open":""}"><div class="dgh"${TC?"":` onclick="dgTog()"`}><span class="p1">🔴 P1 <b>${nP1}</b></span><span class="p2">🟠 P2 <b>${nP2}</b></span><span class="p3">🟡 P3 <b>${nP3}</b></span><span class="dim">${TC?"P1 · P2 in TRADE NOW ↓":DGO?"fold ▴":"the quiet ones ▾"}</span></div><div class="dgl">`+''',
    "the phone: a line that opens the list")
rep('''(aNight()&&!ALLDAY?"since the close":"yet")+'</div>')+`</div>`; })();''', '''(aNight()&&!ALLDAY?"since the close":"yet")+'</div>')+`</div></div>`; })();''', "the list in its fold")
rep('''function aDay(){''', '''let DGO=false; try{ DGO=localStorage.getItem("gir_dgo")==="1"; }catch(e){}   /* patch 207b */
function dgTog(){ DGO=!DGO; try{ localStorage.setItem("gir_dgo",DGO?"1":"0"); }catch(e){} drawAlerts(true); }
function aDay(){''', "the fold remembered")
rep('''/* patch 208: WHO IS PUSHING */''', '''/* patch 207b: the phone - the counts line under the alert strip, the quiet list folds open */
@media(max-width:1099px){body:not(.topchart) #abar{flex-wrap:wrap}
  body:not(.topchart) #abar .dg{display:block;order:5;flex:1 1 100%;border-top:1px solid var(--line)}
  body:not(.topchart) #abar .dg:not(.open) .dgl{display:none}
  body:not(.topchart) #abar .dg .dgl{max-height:45vh;overflow-y:auto}
  body:not(.topchart) #abar .dgh{cursor:pointer;position:static;padding:6px 8px;font-size:11px}
  body:not(.topchart) #abar .dgh .dim{margin-left:auto;color:var(--amber)}
  body:not(.topchart) #abar .dgr{font-size:11.5px;padding:4px 8px}}
#abar .dgh b{margin-left:4px;color:inherit}
/* patch 208: WHO IS PUSHING */''', "the look on the phone")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: patch 207b in")
PY_PATCH
python3 $W/p207b_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 207b done - on the phone, reload GIR (pull down, or close the tab and open it again)."
echo "   under the alert strip: 🔴 P1 · 🟠 P2 · 🟡 P3 - tap it for the quiet alerts, tap again to fold"
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
