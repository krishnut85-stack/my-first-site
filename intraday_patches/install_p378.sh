#!/bin/bash
# PATCH 378 - WHY THEY MOVED, ALL DAY (Rama, 17 Nov 15:04: "do we know why these stocks moved? If we were really proactive we could have got the
#   information and given it to me"). moverswhy.py, every 15 minutes 09:45-15:15 on market days: the 10 biggest F&O gainers and losers (1.5%+),
#   GIR's own facts (callwhy.py: today's news with the AI's reading, its sector and peers, futures, filings, broker calls, results due) + a fresh
#   Google News search for the company since the last close -> one line each by Claude Haiku from those lines only: the reason, its kind, how
#   sure, its source - or plainly "no news found" and whether the sector moved with it. A line is kept 30 min unless the share moved 1% more.
#   · the page: ❓ WHY THEY MOVED in the F&O MOVERS header - the list, gainers then losers · dashserve /moverswhy
#   Needs patch 373 (callwhy.py). The key is the server's .env (never printed). Adds moverswhy.py, a timer; edits dashserve.py and home.html.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 378" $D/home.html && grep -q "patch 378" $D/dashserve.py && [ -f $D/moverswhy.py ]; then echo "patch 378 - already in"; exit 0; fi
[ -f $D/callwhy.py ] && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "</body>" $D/home.html || { echo "patch 373 (callwhy.py) / dashserve's route / the page not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/moverswhy.py > $W/moverswhy.py 2>/dev/null && [ -s $W/moverswhy.py ] && python3 -m py_compile $W/moverswhy.py || { echo "❌ moverswhy.py not in $B - run the git fetch line first; nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/moverswhy.py; systemctl disable --now gir-moverswhy.timer 2>/dev/null; rm -f $U/gir-moverswhy.service $U/gir-moverswhy.timer; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/moverswhy.py $D/moverswhy.py || back
cat > $W/mw.html <<'MW'
<style>/* patch 378: ❓ WHY THEY MOVED */
#gxmwb{margin-left:6px;padding:1px 8px;border:1px solid #2b5a8a;border-radius:6px;background:#0f2238;color:#e6edf3;font:700 11px ui-monospace,Menlo,monospace;cursor:pointer}
#gxmw{position:fixed;top:56px;left:50%;transform:translateX(-50%);z-index:9140;display:none;width:min(920px,calc(100vw - 20px));max-height:calc(100vh - 80px);overflow:auto;background:#0b1522;border:2px solid #58a6ff;border-radius:10px;box-shadow:0 12px 44px rgba(0,0,0,.7);color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxmw.on{display:block}#gxmw .hd{position:sticky;top:0;display:flex;gap:10px;align-items:baseline;padding:9px 12px;background:#0f2238;border-bottom:1px solid #1b3048}
#gxmw .hd b{font:800 14px ui-monospace,Menlo,monospace;color:#58a6ff}#gxmw .hd a{margin-left:auto;cursor:pointer;padding:0 9px;border:1px solid #2b5a8a;border-radius:6px}
#gxmw table{width:100%;border-collapse:collapse}#gxmw td{padding:6px 8px;border-bottom:1px solid #12233a;vertical-align:top}#gxmw td.s{font:700 12.5px ui-monospace,Menlo,monospace;cursor:pointer;white-space:nowrap}
#gxmw .u{color:#26c281}#gxmw .d{color:#ff5c5c}#gxmw .m{color:#8b97a9;font-size:11.5px}#gxmw .k{display:inline-block;padding:0 6px;border-radius:4px;background:#13263d;font:700 10.5px ui-monospace,Menlo,monospace;margin-right:6px}
#gxmw .k.nf{background:#3a2a0e;color:#f0b429}
</style>
<script>/* patch 378: ❓ WHY THEY MOVED - the biggest movers and the reason, every 15 minutes (moverswhy.py) */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  let V=null;
  async function pull(){ try{ const r=await fetch("moverswhy?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} const el=document.getElementById("gxmw"); if(el&&el.classList.contains("on")) draw(); }
  function draw(){ const el=document.getElementById("gxmw"); if(!el) return; const R=(V&&V.rows)||[], today=new Date(Date.now()+19800000).toISOString().slice(0,10);
    const row=r=>`<tr><td class="s ${r.chg>=0?"u":"d"}" data-s="${H(r.s)}">${H(r.s)} ${r.chg>=0?"+":""}${(+r.chg).toFixed(2)}%</td><td><span class="k ${r.sure==="not found"||r.sure==="error"?"nf":""}">${H(r.kind)} · ${H(r.sure)}</span>${H(r.why)}${r.src?` <span class="m">(${H(r.src)})</span>`:""}</td><td class="m">${H(r.t)}</td></tr>`;
    el.innerHTML=`<div class="hd"><b>❓ WHY THEY MOVED</b><span class="m">${V&&V.day===today?"read "+H(V.at)+" · news since "+H(V.since)+" · every 15 min":"not read yet today - from 09:45 every 15 min"}</span><a data-x="1">✕</a></div>`+
      (R.length?`<table>${R.map(row).join("")}</table>`:`<div class="m" style="padding:10px 12px">no F&amp;O share has moved 1.5% yet</div>`)+
      `<div class="m" style="padding:8px 12px">from GIR's own facts and a fresh news search, written by Claude Haiku from those lines only · "not found" = searched, nothing published · tap a share = its trading screen</div>`; }
  function open(){ let el=document.getElementById("gxmw"); if(!el){ el=document.createElement("div"); el.id="gxmw";
      el.addEventListener("click",e=>{ if(e.target.dataset.x){ el.classList.remove("on"); return; } const s=e.target.closest("[data-s]"); if(s){ el.classList.remove("on"); try{ mkOpen(s.dataset.s); }catch(_){} } }); document.body.appendChild(el); }
    el.classList.toggle("on"); if(el.classList.contains("on")){ draw(); pull(); } }
  window.gxWhyMoved=open;
  function btn(){ if(document.getElementById("gxmwb")) return; const h=document.querySelector("#q-mov h3"); if(!h) return;
    const b=document.createElement("button"); b.id="gxmwb"; b.type="button"; b.textContent="❓ WHY THEY MOVED"; b.title="the biggest movers and the reason - every 15 minutes";
    b.addEventListener("click",e=>{ e.stopPropagation(); e.preventDefault(); open(); }); h.appendChild(b); }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"){ const el=document.getElementById("gxmw"); if(el) el.classList.remove("on"); } });
  new MutationObserver(()=>{ try{ btn(); }catch(e){} }).observe(document.body,{childList:true,subtree:true});
  setTimeout(()=>{ btn(); pull(); },2500); setInterval(()=>{ if(!document.hidden) pull(); },120000);
})();
</script>
MW
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if s.count(A) != 1:
    print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
s = s.replace(A, """            if u.path == "/moverswhy":                # patch 378: why the biggest movers moved (moverswhy.py writes it; read only)
                try:
                    v_ = json.load(open(os.path.join(BASE, "data", "moverswhy.json")))
                except Exception:
                    v_ = {}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /moverswhy")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read(); i = t.rfind("</body>")
open(h, "w", encoding="utf-8").write(t[:i] + open(os.path.join(W, "mw.html"), encoding="utf-8").read() + t[i:]); print("  home.html: ❓ WHY THEY MOVED")
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
cat > $U/gir-moverswhy.service <<SVC
[Unit]
Description=GIR why they moved - the biggest F&O movers and the reason (patch 378)
[Service]
Type=oneshot
WorkingDirectory=$D
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && nice -n 10 python3 moverswhy.py > data/moverswhy_run.txt 2>&1'
TimeoutStartSec=300
SVC
cat > $U/gir-moverswhy.timer <<TMR
[Unit]
Description=GIR why they moved: every 15 minutes 09:45-15:15 IST on market days
[Timer]
OnCalendar=Mon..Fri *-*-* 04..09:15/15:00 UTC
Persistent=false
[Install]
WantedBy=timers.target
TMR
systemctl daemon-reload && systemctl enable --now gir-moverswhy.timer >/dev/null 2>&1 || back
cd $D && timeout 60 python3 -c "import moverswhy; print('  movers now: %d' % len(moverswhy.movers()))" 2>&1 | tail -1
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-moverswhy.timer: $(systemctl is-active gir-moverswhy.timer)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 378 done - from tomorrow 09:45, ❓ WHY THEY MOVED in the F&O MOVERS header, every 15 minutes."
echo "   try it now (it reads today's last prices):  cd $D && set -a && . /home/globalbot/.env && set +a && python3 moverswhy.py"
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl disable --now gir-moverswhy.timer; systemctl restart gir-dash"
