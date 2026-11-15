#!/bin/bash
# PATCH 304 - 🔑 SIGN IN / 🔓 SIGN OUT ON GIR'S PAGE (Rama, 15 Nov: "can you please make a login and log out button for the GIR page").
#   The website sign-in has been there since patch 167 (girtrader.com/login, the phone / laptop stays signed in 90 days) - now a key for it next
#   to 🎯 COCKPIT / 📋 CHECKLIST: signed in -> 🔓 SIGN OUT (asks first, then back to the sign-in page); opened from the old key link -> 🔑 SIGN IN.
#   dashserve.py: /signstate (signed in or not - never the password or the cookie). Edits dashserve.py and home.html. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "patch 304" $D/dashserve.py && grep -q "patch 304" $D/home.html; then echo "patch 304 - already in"; exit 0; fi
grep -q "patch 167" $D/dashserve.py || { echo "the website sign-in (patch 167) is not in dashserve.py - nothing done, send this to Claude"; exit 1; }
grep -q 'id="fkeys"' $D/home.html || { echo "home.html: the key bar not found - nothing done, send this to Claude"; exit 1; }
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "dashserve.py: the cockpit route (patch 285) not found - nothing done, send this to Claude"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/page304.js <<'JS_304'
<script>/* patch 304: 🔑 SIGN IN / 🔓 SIGN OUT key - the website sign-in of patch 167 (girtrader.com/login · /logout) */
(function(){ let ST=null;
  function draw(){ const fk=document.getElementById("fkeys"); if(!fk||!ST||!ST.on) return; let a=document.getElementById("sikey");
    if(!a){ a=document.createElement("a"); a.id="sikey"; a.style.cssText="font-weight:700;padding:2px 8px;border-radius:4px;margin-left:6px;border:1px solid #ffb347;color:#ffb347;cursor:pointer"; fk.appendChild(a); }
    if(ST.in){ a.textContent="🔓 SIGN OUT"; a.href="/logout"; a.title="sign out of GIR on this phone / laptop";
      a.onclick=e=>{ if(!confirm("Sign out of GIR on this device?")) e.preventDefault(); }; }
    else { a.textContent="🔑 SIGN IN"; a.href="/login"; a.title="sign in with your username and password (stays signed in 90 days)"; a.onclick=null; } }
  async function ask(){ try{ const r=await fetch("signstate"+location.search,{cache:"no-store"}); if(r.ok){ ST=await r.json(); draw(); } }catch(e){} }
  ask(); setInterval(()=>{ if(!document.hidden) ask(); },60000); setInterval(draw,3000); })();
</script>
JS_304
python3 - $D $W/page304.js <<'PY_EDIT' || back
import os, sys
D, js = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 304" not in s:
    if s.count(A) != 1 or "def _site_ok(" not in s or "def _site_on(" not in s:
        print("❌ dashserve.py: the anchor found %d times / the sign-in checks missing" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/signstate":                # patch 304: signed in or not (for the 🔑 / 🔓 key) - nothing secret
                import json as js_
                return self.send(200, js_.dumps({"on": bool(_site_on()), "in": bool(_site_ok(self))}).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /signstate")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 304" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> found %d times" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", js.strip() + "\n</body>", 1)); print("  home.html: the 🔑 SIGN IN / 🔓 SIGN OUT key")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
systemctl restart gir-dash; sleep 4
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 304 done - GIR's page: 🔓 SIGN OUT (or 🔑 SIGN IN) next to 🎯 COCKPIT. Laptop: Ctrl + Shift + R · phone: under ⋯ MORE on the market screen."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
