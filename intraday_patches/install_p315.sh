#!/bin/bash
# PATCH 315 - THE PHONE: A SHARE'S PAGE SHOWS ITS CHART (Rama, 15 Nov: "for the mobile I can't even see the chart for MANAPPURAM · whenever you
#   change the layout it should be compatible with the mobile and the laptop"). Phone only - the laptop unchanged:
#   · the IN SIMPLE WORDS box: 3 lines, tap it for the rest · 🎯 COCKPIT: a small button next to ✕ CLOSE (it floated over the chart buttons)
#   · the chart buttons smaller -> the chart starts ~170 px higher, on the first screen. Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 315" $D/home.html; then echo "patch 315 - already in"; exit 0; fi
grep -q "patch 299" $D/home.html && grep -q "ppStrip" $D/home.html || { echo "home.html: the share page parts (patch 214 / 299) not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/css.html <<'CSS_315'
<style>/* patch 315: the phone - a share's page shows its chart on the first screen (the laptop unchanged) */
@media(max-width:899px){
  html body #ppStrip .ppp:not(.open){max-height:66px !important;overflow:hidden !important;position:relative;cursor:pointer}
  html body #ppStrip .ppp:not(.open)::after{content:"tap for more ▾";position:absolute;right:0;bottom:0;padding:2px 8px;background:#0e131b;color:#ffb347;font:600 11px system-ui,sans-serif;border-radius:6px 0 0 0}
  html body #ckshare{display:none !important}
  #ckshare2{font:700 11px/1 system-ui,sans-serif;padding:5px 8px;border-radius:5px;background:#ffb347;color:#1a1205 !important;text-decoration:none;margin-left:auto;margin-right:8px;white-space:nowrap}
  #ckshare2+a[onclick="unfocus()"]{margin-left:0 !important}
  html body #focus .ptb{gap:3px 4px !important;padding:3px 4px !important}
  html body #focus .ptb span{gap:2px !important}
  html body #focus .ptb a{padding:3px 5px !important;font-size:10px !important;letter-spacing:0 !important}
}
</style>
CSS_315
cat > $W/js.html <<'JS_315'
<script>/* patch 315: the phone - the IN SIMPLE WORDS box opens on a tap; 🎯 COCKPIT sits next to ✕ CLOSE (not over the chart buttons) */
(function(){ let OPEN=false;
  document.addEventListener("click",e=>{ const p=e.target&&e.target.closest&&e.target.closest("#ppStrip .ppp"); if(p&&window.innerWidth<900&&!e.target.closest("a")){ OPEN=!OPEN; tick(); } });
  function tick(){ try{ if(window.innerWidth>=900) return;
      document.querySelectorAll("#ppStrip .ppp").forEach(p=>p.classList.toggle("open",OPEN));
      const sym=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase(), x=document.querySelector('#focus a[onclick="unfocus()"]'); let a=document.getElementById("ckshare2");
      if(!sym||!x){ if(a) a.remove(); return; }
      if(!a||a.nextElementSibling!==x){ if(a) a.remove(); a=document.createElement("a"); a.id="ckshare2"; a.target="_blank"; x.parentNode.insertBefore(a,x); }
      const u=new URLSearchParams(location.search); u.set("w",sym); const h="cockpit?"+u.toString(); if(a.getAttribute("href")!==h){ a.href=h; a.textContent="🎯 COCKPIT"; }
    }catch(e){} }
  try{ new MutationObserver(tick).observe(document.body,{childList:true,subtree:true}); }catch(e){} setInterval(tick,1000); })();
</script>
JS_315
python3 - $D/home.html $W/css.html $W/js.html <<'PY_EDIT' || back
import sys
h, c, j = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip(), open(sys.argv[3], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</head>") != 1 or t.count("</body>") != 1:
    print("❌ home.html: </head> x%d, </body> x%d - send this to Claude" % (t.count("</head>"), t.count("</body>"))); sys.exit(1)
t = t.replace("</head>", c + "\n</head>", 1).replace("</body>", j + "\n</body>", 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: the phone - a share's chart on the first screen")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 315 done - the phone: a share's chart on the first screen, 🎯 COCKPIT next to ✕ CLOSE. Close the GIR tab and open it again."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
