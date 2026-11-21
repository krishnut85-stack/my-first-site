#!/bin/bash
# PATCH 373 - WHY NOW, ON EVERY BUY CALL (Rama, 17 Nov 12:00: ANGELONE rang BUY CE at 09:20 and went +7.3%, lost among 7 calls in 15 minutes -
#   "why was this not informed to me? All these things - this is what I was expecting when the alarm rings").
#   · callwhy.py (new) + dashserve /callwhy: for a BUY call, from what GIR already holds - last night's 🌙 news naming the share or its
#     sector (FOR / AGAINST the call), its sector now (rank, shares up, 🚀 run, ⚠ one company), its other F&O shares moving the same way, its
#     own news, the futures build-up, its 20-day level, results due, today's 🧪 candidate. A call whose share or sector had strong / moderate
#     news its way is 🗞 NEWS-BACKED. Each call's mark is kept (data/callwhy/<day>.json) so it can be scored against what the call did.
#   · the page: when a BUY card comes, a 🔔 WHY NOW banner at the top with those lines (✕ closes it; tap = the share); while open it keeps
#     itself up to date - the price and the move since the call every 10 s, WATCH / HALF OUT / STOPPED, the why (today's news too) every 30 s · on the BOARD, each
#     BUY card gets its why-line and the 🗞 NEWS-BACKED mark. The engine and its ringing are not touched.
#   Needs patches 357 (the share note) and 364 (the BOARD). Adds callwhy.py, edits dashserve.py and home.html. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 373" $D/home.html && grep -q "patch 373" $D/dashserve.py && [ -f $D/callwhy.py ]; then echo "patch 373 - already in"; exit 0; fi
grep -q "patch 357" $D/home.html && grep -q "patch 364" $D/home.html && [ -f $D/sharenote.py ] && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "patches 357 / 364 or dashserve's route not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/callwhy.py > $W/callwhy.py 2>/dev/null && [ -s $W/callwhy.py ] && python3 -m py_compile $W/callwhy.py || { echo "❌ callwhy.py not in $B - run the git fetch line first; nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/callwhy.py; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/callwhy.py $D/callwhy.py || back
cat > $W/why.html <<'WHY'
<style>/* patch 373: WHY NOW on every BUY call */
#gxwn{position:fixed;top:8px;right:10px;z-index:9001;width:min(560px,calc(100vw - 20px));display:flex;flex-direction:column;gap:6px;pointer-events:none}
#gxwn .t{pointer-events:auto;padding:9px 12px;border-radius:9px;background:#13202f;border:2px solid #f0b429;box-shadow:0 8px 30px rgba(0,0,0,.6);color:#e6edf3;font:12.5px/1.5 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;cursor:pointer}
#gxwn .t b.h{font:800 14px ui-monospace,Menlo,monospace}#gxwn .t .up{color:#26c281}#gxwn .t .dn{color:#ff5c5c}
#gxwn .t .x{float:right;padding:0 9px;border:1px solid #2b5a8a;border-radius:6px;background:#0b1522;font:700 12px ui-monospace,Menlo,monospace}
#gxwn .t ul{margin:4px 0 0;padding-left:2px;list-style:none}#gxwn .t li{margin:1px 0}
.gxbk{display:inline-block;padding:0 6px;border-radius:4px;background:#f0b429;color:#111;font:800 11px ui-monospace,Menlo,monospace;margin-left:6px}
.gxbk.ag{background:#7a2a2a;color:#fff}
#gxbd .c .gxwy373{grid-column:1/-1;width:100%;flex-basis:100%;margin-top:4px;font:11.5px/1.45 -apple-system,"Segoe UI",Roboto,sans-serif;color:#c9d4e3}
@media (min-width:1201px){#gxsg{left:10px;transform:none;width:min(600px,45vw)}#gxwn{width:min(560px,45vw)}}   /* the 🚀 banner left, the 🔔 banner right */
@media (max-width:1200px){#gxwn{top:auto;bottom:8px;right:5px}}
</style>
<script>/* patch 373: WHY NOW - a BUY call says why: last night's news for the share or its sector, its sector now, its peers, its own news */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const istNow=()=>{ const n=new Date(Date.now()+19800000); return {d:n.toISOString().slice(0,10),m:n.getUTCHours()*60+n.getUTCMinutes()}; };
  const mins=t=>{ const m=/(\d\d):(\d\d)/.exec(t||""); return m?(+m[1])*60+(+m[2]):-1; };
  const CW={}; let seen={}; try{ seen=JSON.parse(localStorage.getItem("gir_why_seen")||"{}")||{}; }catch(e){}
  async function why(s,dir){ const k=s+"|"+dir, c=CW[k]; if(c&&Date.now()-c.at<60000) return c.v;
    try{ const r=await fetch("callwhy?k="+encodeURIComponent(KEY())+"&sym="+encodeURIComponent(s)+"&dir="+dir,{cache:"no-store"}); if(r.ok){ const v=await r.json(); CW[k]={at:Date.now(),v}; return v; } }catch(e){}
    return c?c.v:null; }
  const badge=v=>v&&v.backed?'<span class="gxbk" title="last night\'s news named this share or its sector, the call\'s way">🗞 NEWS-BACKED</span>':
    (v&&(v.news||[]).some(n=>!n.agree&&(n.dir==="up"||n.dir==="down"))?'<span class="gxbk ag" title="last night\'s news went the other way">🗞 NEWS AGAINST</span>':"");
  function shut(k,el){ seen[k]=1; try{ const d=Object.keys(seen); if(d.length>300) d.slice(0,150).forEach(x=>delete seen[x]); localStorage.setItem("gir_why_seen",JSON.stringify(seen)); }catch(e){} if(el) el.remove(); }
  const OPEN={}, STW={open:"WATCH",half:"HALF OUT ✓ - book half, stop to entry",out:"STOPPED - out",closed:"CLOSED 15:10"};
  function paint(el,m,v){ const p_=(()=>{ try{ const r=(TAPE||[]).find(x=>x.s===m.s); return r&&r.px; }catch(e){ return null; } })()||m.now;
    const mv=p_&&m.px?((p_/m.px-1)*(m.dir>0?1:-1)*100):m.mv, n=new Date(Date.now()+19800000).toISOString().slice(11,19);
    el.innerHTML=`<span class="x" title="close">✕</span><b class="h ${m.dir>0?"up":"dn"}">🔔 ${m.dir>0?"BUY CE":"BUY PE"} ${H(m.s)}</b> <span>${H(m.t)} at ₹${H(m.px)}</span>${badge(v)}`+
      `<div style="font-size:12px;margin-top:2px">now ${p_?"₹"+H((+p_).toFixed(2)):"-"} · <b class="${mv>=0?"up":"dn"}">${mv!=null?(mv>=0?"+":"")+(+mv).toFixed(1)+"% its way":""}</b> · ${H(STW[m.st]||m.st||"")}</div>`+
      `<div style="color:#a3aebf;font-size:11.5px">WHY NOW · updated ${n}</div><ul>${((v&&v.bul)||[]).slice(0,8).map(b=>`<li>${H(b)}</li>`).join("")}</ul>`; }
  async function ring(m,day){ const k=day+"|"+m.s+"|"+m.t; if(seen[k]) return; let box=document.getElementById("gxwn");
    if(box&&box.querySelector(`[data-k="${CSS.escape(k)}"]`)) return; const v=await why(m.s,m.dir>0?1:-1); if(!v) return;
    if(!box){ box=document.createElement("div"); box.id="gxwn"; document.body.appendChild(box); } if(box.querySelector(`[data-k="${CSS.escape(k)}"]`)) return;
    const el=document.createElement("div"); el.className="t"; el.dataset.k=k; paint(el,m,v); OPEN[k]={m,el,v,day};
    el.addEventListener("click",ev=>{ delete OPEN[k]; shut(k,el); if(!ev.target.closest(".x")){ try{ mkOpen(m.s); }catch(_){} } });
    box.prepend(el); while(box.children.length>3){ const z=box.lastChild; delete OPEN[z.dataset.k]; z.remove(); } }
  let tick=0;
  async function refresh(hu){ tick++; for(const [k,o] of Object.entries(OPEN)){ if(!document.body.contains(o.el)){ delete OPEN[k]; continue; }
      const m2=Object.values((hu&&hu.mon)||{}).find(x=>x&&x.s===o.m.s&&x.t===o.m.t); if(m2) o.m=m2;
      if(tick%3===0){ delete CW[o.m.s+"|"+(o.m.dir>0?1:-1)]; const v=await why(o.m.s,o.m.dir>0?1:-1); if(v) o.v=v; }
      paint(o.el,o.m,o.v); } }
  async function pull(){ if(document.hidden) return; try{ const r=await fetch("headsup?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(!r.ok) return; const hu=await r.json(); const n=istNow();
      if(!hu||hu.day!==n.d) return; Object.values(hu.mon||{}).forEach(m=>{ if(m&&m.s&&mins(m.t)>=0&&n.m-mins(m.t)<=20) ring(m,hu.day); }); refresh(hu); }catch(e){} }   /* patch 373: open banners refresh - price every 10 s, the why every 30 s */
  function decorate(){ const bd=document.getElementById("gxbd"); if(!bd||!bd.classList.contains("on")) return;
    bd.querySelectorAll('.c[onclick*="mkOpen("]').forEach(c=>{ if(c.querySelector(".gxwy373")) return; const m=/mkOpen\('([^']+)'\)/.exec(c.getAttribute("onclick")||""); if(!m) return;
      const dir=c.classList.contains("d")?-1:1, v=(CW[m[1]+"|"+dir]||{}).v; if(!v){ why(m[1],dir).then(()=>{ const x=c.querySelector(".gxwy373"); if(!x) decorate(); }); return; }
      const d=document.createElement("div"); d.className="gxwy373"; d.innerHTML=badge(v)+" "+(v.bul||[]).slice(0,3).map(H).join(" · "); c.appendChild(d); }); }
  new MutationObserver(()=>{ try{ decorate(); }catch(e){} }).observe(document.body,{childList:true,subtree:true});
  setTimeout(pull,3500); setInterval(pull,10000);
})();
</script>
WHY
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if s.count(A) != 1:
    print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
s = s.replace(A, """            if u.path == "/callwhy":                  # patch 373: why now, for a BUY call - last night's news for the share or its sector, its sector, peers (local data, read only)
                try:
                    import callwhy
                    q_ = parse_qs(u.query); v_ = callwhy.view((q_.get("sym") or [""])[0], (q_.get("dir") or ["1"])[0])
                except Exception:
                    v_ = {}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /callwhy")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
i = t.rfind("</body>")
if i < 0:
    print("❌ home.html: </body> not found"); sys.exit(1)
open(h, "w", encoding="utf-8").write(t[:i] + open(os.path.join(W, "why.html"), encoding="utf-8").read() + t[i:]); print("  home.html: 🔔 WHY NOW on BUY calls · the BOARD's why-lines")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && timeout 30 python3 callwhy.py ANGELONE 1 2>&1 | head -8 | sed 's/^/   /'
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 373 done - refresh GIR (Ctrl+Shift+R). From tomorrow every BUY call shows 🔔 WHY NOW, and BOARD cards carry their why-line."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/callwhy.py; systemctl restart gir-dash"
