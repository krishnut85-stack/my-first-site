#!/bin/bash
# PATCH 305 - THE 🔓 SIGN OUT / 🔑 SIGN IN KEY - ITS OWN BUTTON RIGHT NEXT TO GIR AT THE TOP (Rama, 15 Nov: "move it to the top bar next to GIR").
#   Patch 304 put it at the end of the key row, where it wrapped onto a second line. Now it is its own button right beside the word GIR (top left) on the
#   laptop and the phone; tapping it does not open GIR home. Edits home.html only (the 304 key's code is swapped). No restart - Ctrl + Shift + R.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 304 + 305" $D/home.html; then echo "patch 305 - already in"; exit 0; fi
grep -q "patch 304" $D/home.html || { echo "patch 304 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/old.js <<'JS_OLD'
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
JS_OLD
cat > $W/new.js <<'JS_NEW'
<script>/* patch 304 + 305: 🔑 SIGN IN / 🔓 SIGN OUT - its own button right next to GIR at the top (the website sign-in of patch 167: /login · /logout) */
(function(){ let ST=null, busy=false;
  function host(){ const L=document.querySelectorAll(".brand"); for(const b of L){ if(b.offsetParent!==null) return b; } return L[0]||null; }
  function draw(){ if(busy||!ST||!ST.on) return; const br=host(); if(!br) return; busy=true;
    try{ let a=document.getElementById("sikey");
      if(!a||a.parentNode!==br){ if(a) a.remove(); a=document.createElement("a"); a.id="sikey";
        a.style.cssText="display:inline-block;vertical-align:middle;margin-left:12px;font:700 11px/1.2 system-ui,sans-serif;padding:3px 8px;border-radius:4px;background:#111;color:#ffb347;border:1px solid #111;text-decoration:none;cursor:pointer;white-space:nowrap;letter-spacing:0;z-index:3";
        br.appendChild(a); }
      const want=ST.in?"🔓 SIGN OUT":"🔑 SIGN IN";
      if(a.textContent!==want){ a.textContent=want; a.href=ST.in?"/logout":"/login";
        a.title=ST.in?"sign out of GIR on this phone / laptop":"sign in with your username and password (stays signed in 90 days)"; }
      a.onclick=e=>{ e.stopPropagation(); if(ST.in&&!confirm("Sign out of GIR on this device?")) e.preventDefault(); };
    } finally { busy=false; } }
  async function ask(){ try{ const r=await fetch("signstate"+location.search,{cache:"no-store"}); if(r.ok){ ST=await r.json(); draw(); } }catch(e){} }
  try{ new MutationObserver(draw).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  ask(); setInterval(()=>{ if(!document.hidden) ask(); },60000); setInterval(draw,3000); })();
</script>
JS_NEW
python3 - $D/home.html $W/old.js $W/new.js <<'PY_EDIT' || back
import sys
h, o, n = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip(), open(sys.argv[3], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count(o) != 1:
    print("❌ home.html: patch 304's key code found %d times - send this to Claude" % t.count(o)); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace(o, n, 1)); print("  home.html: the key now in the GIR bar")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 305 done - 🔓 SIGN OUT is now its own button right next to GIR (top left) (laptop and phone). Ctrl + Shift + R."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
