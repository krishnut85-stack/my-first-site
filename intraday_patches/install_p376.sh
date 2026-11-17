#!/bin/bash
# PATCH 376 - GIR CHECKS ITS OWN NUMBERS (Rama, 17 Nov: "all these values decide the trade - check every value on every page, each point and
#   decimal; you come back in seconds saying OK and I find the mistake"). crosscheck.py compares the SAME value wherever GIR keeps it:
#     C1 day change (live feed · movers · sectors) · C2 futures OI and build-up word (movers against FUTURES BY MONTH, the mismatched near month)
#     C3 the sector of each F&O share (SECTORS box against the movers filter) · C4 a feed not refreshed · C5 CE and PE on one share within 30 min
#     C6 a headline's word-reading direction against the AI's full-story reading · after the close C7 NSE's own end-of-day file (the base of every
#     "% today" and the last price)
#   · the gir-crosscheck timer: every 5 minutes 09:20-15:35 on market days, and at 18:45 and 20:15 against NSE's file
#   · the page: a ⚠ CHECK button (with the count) beside 🔊 SOUNDS - the list, both values side by side · dashserve /crosscheck
#   READ ONLY - it changes no number and no alert; nothing rings. Adds crosscheck.py, edits dashserve.py and home.html. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 376" $D/home.html && grep -q "patch 376" $D/dashserve.py && [ -f $D/crosscheck.py ]; then echo "patch 376 - already in"; exit 0; fi
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "</body>" $D/home.html || { echo "dashserve's route / the page not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/crosscheck.py > $W/crosscheck.py 2>/dev/null && [ -s $W/crosscheck.py ] && python3 -m py_compile $W/crosscheck.py || { echo "❌ crosscheck.py not in $B - run the git fetch line first; nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/crosscheck.py; systemctl disable --now gir-crosscheck.timer 2>/dev/null; rm -f $U/gir-crosscheck.service $U/gir-crosscheck.timer; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/crosscheck.py $D/crosscheck.py || back
cat > $W/cc.html <<'CC'
<style>/* patch 376: ⚠ CHECK - GIR checks its own numbers */
.gxcck{cursor:pointer;font-weight:700}.gxcck.bad{color:#f0b429}
#gxcc{position:fixed;top:56px;left:50%;transform:translateX(-50%);z-index:9150;display:none;width:min(980px,calc(100vw - 20px));max-height:calc(100vh - 80px);overflow:auto;background:#0b1522;border:2px solid #f0b429;border-radius:10px;box-shadow:0 12px 44px rgba(0,0,0,.7);color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxcc.on{display:block}#gxcc .hd{position:sticky;top:0;display:flex;gap:10px;align-items:baseline;padding:9px 12px;background:#0f2238;border-bottom:1px solid #1b3048}
#gxcc .hd b{font:800 14px ui-monospace,Menlo,monospace;color:#f0b429}#gxcc .hd a{margin-left:auto;cursor:pointer;padding:0 9px;border:1px solid #2b5a8a;border-radius:6px}
#gxcc table{width:100%;border-collapse:collapse;font:12px ui-monospace,Menlo,monospace}#gxcc td{padding:5px 8px;border-bottom:1px solid #12233a;vertical-align:top}
#gxcc td.w{color:#f0b429}#gxcc td.m{color:#8b97a9}#gxcc .inf{padding:8px 12px;color:#a3aebf;font-size:11.5px}
</style>
<script>/* patch 376: ⚠ CHECK - the same value compared wherever GIR keeps it (crosscheck.py, every 5 minutes; NSE's file in the evening) */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  let V=null;
  async function pull(){ try{ const r=await fetch("crosscheck?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} link(); const el=document.getElementById("gxcc"); if(el&&el.classList.contains("on")) draw(); }
  function link(){ let a=document.querySelector(".gxcck"); if(!a){ const host=document.querySelector(".gxsndk")||[...document.querySelectorAll('a[onclick="alarm(\'crit\')"]')][0]||document.getElementById("fkeys"); if(!host) return;
      a=document.createElement("a"); a.className="gxcck"; a.addEventListener("click",e=>{ e.preventDefault(); open(); }); if(host.id==="fkeys") host.appendChild(a); else host.after(a); }
    const n=V&&V.n||0, t=n?`⚠ CHECK ${n}`:"✓ CHECK"; if(a.textContent!==t){ a.textContent=t; a.classList.toggle("bad",n>0); a.title=n?`${n} values disagree between two places on GIR - press to see both`:"GIR's numbers agree where they are compared"; } }
  function draw(){ const el=document.getElementById("gxcc"); if(!el) return; const I=(V&&V.items)||[];
    el.innerHTML=`<div class="hd"><b>⚠ GIR CHECKS ITS OWN NUMBERS</b><span>${V?H(V.day+" "+V.at+" · "+(V.mode==="eod"?"against NSE's file":"live, every 5 min")):"not run yet"}</span><a data-x="1">✕</a></div>`+
      `<div class="inf">${V&&V.info?Object.entries(V.info).map(([k,v])=>`${H(k)}: ${H(v)}`).join(" · "):""}</div>`+
      (I.length?`<table>${I.map(x=>`<tr><td class="${x.lvl==="⚠"?"w":"m"}">${H(x.lvl)} ${H(x.chk)}</td><td><b>${H(x.s)}</b></td><td>${H(x.a)}</td><td>≠</td><td>${H(x.b)}</td><td class="m">${H(x.note)}</td></tr>`).join("")}</table>`
        :`<div class="inf">✓ nothing disagrees in this check</div>`); }
  function open(){ let el=document.getElementById("gxcc"); if(!el){ el=document.createElement("div"); el.id="gxcc"; el.addEventListener("click",e=>{ if(e.target.dataset.x) el.classList.remove("on"); }); document.body.appendChild(el); }
    el.classList.toggle("on"); if(el.classList.contains("on")){ draw(); pull(); } }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"){ const el=document.getElementById("gxcc"); if(el) el.classList.remove("on"); } });
  new MutationObserver(()=>{ try{ link(); }catch(e){} }).observe(document.body,{childList:true,subtree:true});
  setTimeout(pull,3000); setInterval(()=>{ if(!document.hidden) pull(); },60000);
})();
</script>
CC
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if s.count(A) != 1:
    print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
s = s.replace(A, """            if u.path == "/crosscheck":               # patch 376: GIR checks its own numbers (crosscheck.py writes it; read only)
                try:
                    v_ = json.load(open(os.path.join(BASE, "data", "crosscheck.json")))
                except Exception:
                    v_ = {}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /crosscheck")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read(); i = t.rfind("</body>")
open(h, "w", encoding="utf-8").write(t[:i] + open(os.path.join(W, "cc.html"), encoding="utf-8").read() + t[i:]); print("  home.html: ⚠ CHECK")
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
cat > $U/gir-crosscheck.service <<SVC
[Unit]
Description=GIR cross-check - the same value compared wherever GIR keeps it (patch 376, read only)
[Service]
Type=oneshot
WorkingDirectory=$D
ExecStart=/bin/bash -c 'H=\$(TZ=Asia/Kolkata date +%%H%%M); if [ "\$H" -ge 1800 ]; then nice -n 15 /usr/bin/python3 $D/crosscheck.py --eod; else nice -n 15 /usr/bin/python3 $D/crosscheck.py; fi'
TimeoutStartSec=240
SVC
cat > $U/gir-crosscheck.timer <<TMR
[Unit]
Description=GIR cross-check: every 5 minutes 09:20-15:35 on market days, and 18:45 / 20:15 against NSE's file
[Timer]
OnCalendar=Mon..Fri *-*-* 03:50..59/5:00 UTC
OnCalendar=Mon..Fri *-*-* 04..09:00/5:00 UTC
OnCalendar=Mon..Fri *-*-* 10:00..05/5:00 UTC
OnCalendar=Mon..Fri *-*-* 13:15:00 UTC
OnCalendar=Mon..Fri *-*-* 14:45:00 UTC
Persistent=false
[Install]
WantedBy=timers.target
TMR
systemctl daemon-reload && systemctl enable --now gir-crosscheck.timer >/dev/null 2>&1 || back
cd $D && timeout 200 nice -n 15 python3 crosscheck.py | head -20 | sed 's/^/   /'
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-crosscheck.timer: $(systemctl is-active gir-crosscheck.timer)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 376 done - refresh GIR (Ctrl+Shift+R): ⚠ CHECK beside 🔊 SOUNDS lists every value that disagrees between two places."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl disable --now gir-crosscheck.timer; systemctl restart gir-dash"
