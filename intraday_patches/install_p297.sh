#!/bin/bash
# PATCH 297 - ⏱ THE TIME IN THE BIG MONEY TABLE (Rama, 15 Nov: "the time is also not mentioned"). Under each share's FUTURES BUILD-UP on
#   B BIG MONEY -> 🏦 THE TABLE: "⏱ short build-up since 11:08 · 1 change, first 09:40" - from the build-up timeline (patch 292, held 3 min).
#   Fills from about 09:18 on a market day. Page file only (home.html) + the dashboard restarted.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 297" $F; then echo "patch 297 - already in"; exit 0; fi
grep -q "patch 292" $F || { echo "patch 292 first"; exit 1; }
cp $F $F.bak$TS
back(){ cp $F.bak$TS $F; systemctl restart gir-dash 2>/dev/null; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/page297.js <<'JS_297'
/* patch 297: ⏱ THE TIME IN THE BIG MONEY TABLE - under each share's futures build-up: since when (the build-up timeline, held 3 min), how many
   changes today and the first one. Rama, 15 Nov: "the time is also not mentioned". */
(function(){ const st=document.createElement("style"); st.textContent=".bsn{font-size:10px;color:#8b98a8;white-space:nowrap}.bsn b{color:#ffb347}"; document.head.appendChild(st); })();
const BSW={"LONG BUILD-UP":"long build-up","SHORT BUILD-UP":"short build-up","SHORT COVERING":"short covering","LONG UNWINDING":"long unwinding"};
function btSince(){ const el=document.getElementById("mk-lnk"); if(!el||typeof WIND==="undefined"||!WIND||!WIND.bt) return;
  el.querySelectorAll("table tr.k").forEach(tr=>{ const m=/mkOpen\('([^']+)'\)/.exec(tr.getAttribute("onclick")||""); if(!m) return;
    const L=WIND.bt[m[1]], td=tr.children; if(td.length<9) return;
    let h='<span class="dim">⏱ no clear build-up yet</span>';
    if(L&&L.length){ const last=L[L.length-1];
      h=`⏱ ${BSW[last[1]]||esc(last[1])} since <b>${esc(last[0])}</b>${L.length>1?` · ${L.length-1} change${L.length>2?"s":""}, first ${esc(L[0][0])}`:""}`; }
    let sp=td[2].querySelector(".bsn"); if(!sp){ sp=document.createElement("div"); sp.className="bsn"; td[2].appendChild(sp); }
    if(sp._h!==h){ sp._h=h; sp.innerHTML=h; } });
  const hr=el.querySelector("table tr"); if(hr&&hr.children[2]&&!hr.children[2].querySelector(".bsn")) hr.children[2].insertAdjacentHTML("beforeend",'<div class="bsn">⏱ since when (held 3 min)</div>'); }
setInterval(()=>{ if(!document.hidden) try{ btSince(); }catch(e){} },1000);
JS_297
python3 - $F $W/page297.js <<'PY_HOME' || back
import sys
p, js = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
s = open(p, encoding="utf-8").read()
A = 'setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big"&&!document.hidden) pullWind(); },3000);'
if s.count(A) != 1:
    print("❌ home.html: anchor found %d times" % s.count(A)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(A, A + "\n" + js.strip()))
print("  home.html: ⏱ since when, under each share's build-up on BIG MONEY")
PY_HOME
if command -v node >/dev/null 2>&1; then
  python3 - $F $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 297 done - B BIG MONEY: ⏱ since when under each build-up (from about 09:18 on a market day). On the laptop: Ctrl + Shift + R."
echo "   undo: cp $F.bak$TS $F; systemctl restart gir-dash"
