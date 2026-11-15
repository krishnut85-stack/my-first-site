#!/bin/bash
# PATCH 308 - THE SIGN OUT BUTTON ON THE PHONE (Rama, 15 Nov: a phone screenshot - the red button sat on top of the NIFTY price). On the phone
#   GIR is a small box with the prices in a row beside it, so there the button is now its own box right after GIR (same height, nothing covered);
#   on the laptop it stays on the right of the GIR bar. Edits home.html only (patch 307's code is swapped). No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 304-308" $D/home.html; then echo "patch 308 - already in"; exit 0; fi
grep -q "patch 304-307" $D/home.html || { echo "patch 307 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/old.js <<'JS_OLD'
<script>/* patch 304-307: SIGN OUT / SIGN IN - its own button right of the orange GIR bar (red = sign out, green = sign in; the sign-in of patch 167) */
(function(){ let ST=null, busy=false, css=false;
  function draw(){ if(busy||!ST||!ST.on) return; const ix=document.getElementById("idx"), br=ix&&ix.querySelector(".brand"); if(!br) return; busy=true;
    try{ if(!css){ const s=document.createElement("style"); s.textContent="#idx{position:relative}#idx .brand{margin-right:124px}"
        +"#sikey{position:absolute;right:0;display:flex;align-items:center;justify-content:center;width:116px;border-radius:6px;font:700 13px/1 var(--ui,system-ui),sans-serif;letter-spacing:.08em;color:#fff;text-decoration:none;cursor:pointer;user-select:none}"
        +"#sikey.out{background:#c62828}#sikey.in{background:#2e7d32}#sikey:hover{filter:brightness(1.15)}"; document.head.appendChild(s); css=true; }
      let a=document.getElementById("sikey");
      if(!a||a.parentNode!==ix){ if(a) a.remove(); a=document.createElement("a"); a.id="sikey"; ix.appendChild(a); }
      const cs=getComputedStyle(ix), top=br.offsetTop, h=br.offsetHeight, rt=parseFloat(cs.paddingRight)||0;
      a.style.top=top+"px"; a.style.height=h+"px"; a.style.right=rt+"px";
      const want=ST.in?"SIGN OUT":"SIGN IN";
      if(a.textContent!==want){ a.textContent=want; a.className=ST.in?"out":"in"; a.href=ST.in?"/logout":"/login";
        a.title=ST.in?"sign out of GIR on this phone / laptop":"sign in with your username and password (stays signed in 90 days)"; }
      a.onclick=e=>{ e.stopPropagation(); if(ST.in&&!confirm("Sign out of GIR on this device?")) e.preventDefault(); };
    } finally { busy=false; } }
  async function ask(){ try{ const r=await fetch("signstate"+location.search,{cache:"no-store"}); if(r.ok){ ST=await r.json(); draw(); } }catch(e){} }
  try{ new MutationObserver(draw).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  window.addEventListener("resize",draw); ask(); setInterval(()=>{ if(!document.hidden) ask(); },60000); setInterval(draw,3000); })();
</script>
JS_OLD
cat > $W/new.js <<'JS_NEW'
<script>/* patch 304-308: SIGN OUT / SIGN IN - its own button next to the GIR bar (laptop: on its right · phone: the box right after GIR); red = sign out, green = sign in */
(function(){ let ST=null, busy=false, css=false;
  function draw(){ if(busy||!ST||!ST.on) return; const ix=document.getElementById("idx"), br=ix&&ix.querySelector(".brand"); if(!br) return; busy=true;
    try{ if(!css){ const s=document.createElement("style"); s.textContent="#idx{position:relative}#idx.skw .brand{margin-right:124px}"
        +"#sikey{display:flex;align-items:center;justify-content:center;border-radius:6px;font:700 13px/1 var(--ui,system-ui),sans-serif;letter-spacing:.08em;color:#fff;text-decoration:none;cursor:pointer;user-select:none;box-sizing:border-box}"
        +"#idx.skw #sikey{position:absolute;width:116px}#idx.skn #sikey{position:static;flex:none;align-self:stretch;width:92px;padding:0 6px;text-align:center;line-height:1.3}"
        +"#sikey.out{background:#c62828}#sikey.in{background:#2e7d32}#sikey:hover{filter:brightness(1.15)}"; document.head.appendChild(s); css=true; }
      let a=document.getElementById("sikey");
      if(!a){ a=document.createElement("a"); a.id="sikey"; }
      const wide=ix.classList.contains("skw")?br.offsetWidth+124>ix.clientWidth*0.6:br.offsetWidth>ix.clientWidth*0.6;   /* laptop: GIR fills the row */
      ix.classList.toggle("skw",wide); ix.classList.toggle("skn",!wide);
      if(wide){ if(a.parentNode!==ix) ix.appendChild(a);
        a.style.top=br.offsetTop+"px"; a.style.height=br.offsetHeight+"px"; a.style.right=(parseFloat(getComputedStyle(ix).paddingRight)||0)+"px"; }
      else { if(a.previousElementSibling!==br) br.after(a); a.style.top=a.style.height=a.style.right=""; }
      const want=ST.in?"SIGN OUT":"SIGN IN";
      if(a.textContent!==want){ a.textContent=want; a.className=ST.in?"out":"in"; a.href=ST.in?"/logout":"/login";
        a.title=ST.in?"sign out of GIR on this phone / laptop":"sign in with your username and password (stays signed in 90 days)"; }
      a.onclick=e=>{ e.stopPropagation(); if(ST.in&&!confirm("Sign out of GIR on this device?")) e.preventDefault(); };
    } finally { busy=false; } }
  async function ask(){ try{ const r=await fetch("signstate"+location.search,{cache:"no-store"}); if(r.ok){ ST=await r.json(); draw(); } }catch(e){} }
  try{ new MutationObserver(draw).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  window.addEventListener("resize",draw); ask(); setInterval(()=>{ if(!document.hidden) ask(); },60000); setInterval(draw,3000); })();
</script>
JS_NEW
python3 - $D/home.html $W/old.js $W/new.js <<'PY_EDIT' || back
import sys
h, o, n = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip(), open(sys.argv[3], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count(o) != 1:
    print("❌ home.html: patch 307's key code found %d times - send this to Claude" % t.count(o)); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace(o, n, 1)); print("  home.html: the phone: SIGN OUT its own box right after GIR")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 308 done - phone: SIGN OUT is its own box right after GIR · laptop: unchanged. Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
