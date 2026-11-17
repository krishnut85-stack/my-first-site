#!/bin/bash
# PATCH 358 - 🌙 THE OVERNIGHT NEWS: CAUGHT BEFORE THE OPEN, THEN OBSERVED (Rama, 17 Nov, on "EU targets Indian steel with 9.5% duty": "these
#   are macro news. You need to catch these news and observe."). GIR's desks already collect such lines through the night; nothing turned them
#   into a list for the open, and nothing recorded what the shares then did.
#   · overnight.py  make (08:35): the lines GIR collected since the last close (the market-wide desk + the company news GIR sent) read once by
#                   Claude Haiku 5.5 (the key in the server's .env) -> each story: time, the F&O shares it touches, up / down / unclear, strong /
#                   moderate / weak, why. It may use only those lines and only GIR's F&O shares.
#                   score (15:50): each listed share's opening gap, open -> 10:00 and open -> 15:10 in the listed direction -> the record.
#   · gir-overnight.timer  Monday-Friday 08:35 and 15:50 IST · dashserve /overnight
#   · the page: a 🌙 OVERNIGHT · FOR THE OPEN box in TRADE NOW under the 🧪 box - the list, and under it the record by strength
#   A paper record: no sound, no Telegram, no order. The engine, the desk and the alerts are not touched. Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 358" $D/home.html && grep -q "patch 358" $D/dashserve.py && [ -f $U/gir-overnight.timer ]; then echo "patch 358 - already in"; exit 0; fi
grep -q 'id="q-act"' $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && [ -f $D/seclive.py ] && [ -f $D/macro.py ] || { echo "the TRADE NOW box / dashserve's route / seclive.py / macro.py not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/overnight.py > $W/overnight.py 2>/dev/null && [ -s $W/overnight.py ] || { echo "❌ overnight.py not in $B - run the git fetch line first; nothing done"; exit 1; }
python3 -m py_compile $W/overnight.py || { echo "❌ did not compile - nothing changed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/overnight.py; systemctl disable --now gir-overnight.timer >/dev/null 2>&1; rm -f $U/gir-overnight.service $U/gir-overnight.timer; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_358'
<style>/* patch 358: 🌙 the overnight news for the open, and what the shares then did - a paper record, in TRADE NOW under the 🧪 box */
#gxon{margin:0 0 10px;border:1px solid #4a3f6b;border-radius:8px;background:#100f1f;font:12.5px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3}
#gxon .h{padding:7px 10px;border-bottom:1px solid #2a2547;font:800 12px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#c3b3ff}
#gxon .h small{display:block;font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf;margin-top:2px}
#gxon .r{padding:6px 10px;border-bottom:1px solid #1d1a35}#gxon .r:last-of-type{border-bottom:0}
#gxon .a{display:flex;flex-wrap:wrap;gap:5px;align-items:center;font:700 12.5px ui-monospace,Menlo,monospace}
#gxon .t{font-weight:500;color:#a3aebf}#gxon .s{cursor:pointer;padding:0 3px;border-radius:3px}#gxon .s:hover{background:#221f3d}
#gxon .k{font:700 10px ui-monospace,Menlo,monospace;padding:1px 5px;border-radius:3px;background:#221f3d;color:#c3b3ff}#gxon .k.strong{background:#3a2a12;color:#f0b429}
#gxon .r,#gxon .hl,#gxon .res{text-align:left}#gxon .hl{color:#c9d4e3;font:12px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;margin-top:2px;white-space:normal}#gxon .res{font:600 11px ui-monospace,Menlo,monospace;color:#a3aebf;margin-top:2px}
#gxon .up{color:#26c281}#gxon .dn{color:#f0544f}#gxon .dim{color:#a3aebf}
#gxon .none,#gxon .rec{padding:7px 10px;color:#a3aebf;font-size:11.5px}#gxon .rec{border-top:1px solid #1d1a35}#gxon .rec b{color:#e6edf3}
</style>
<script>/* patch 358 (Rama, 17 Nov: "these are macro news. You need to catch these news and observe."): the news GIR collected after yesterday's
   close, read once before the open - the F&O shares each story touches and which way - and, after 15:50, what those shares did: the opening gap
   and the move after the open. A paper record: no sound. data/overnight.json through dashserve /overnight, read every 2 minutes. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const pc=v=>(v>=0?"+":"")+(+v).toFixed(1)+"%", cl=v=>v>=0?"up":"dn";
  let V=null;
  function draw(){ const host=document.getElementById("q-act"); if(!host||!V) return; let el=document.getElementById("gxon");
    if(!el){ el=document.createElement("div"); el.id="gxon"; const a=document.getElementById("gxcd")||document.getElementById("gxhu"), h3=host.querySelector("h3"); if(a) a.after(el); else if(h3) h3.after(el); else host.prepend(el); }
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10), mine=V.day===today, I=mine?(V.items||[]):[];
    const row=it=>{ const dr=it.dir==="up"?1:it.dir==="down"?-1:0, res=it.res||{};
      const sh=it.shares.map(s=>`<span class="s" onclick="try{mkOpen('${E(s).replace(/'/g,"")}')}catch(e){}">${E(s)}</span>`).join(" ");
      const rr=Object.keys(res).length?`<div class="res">${it.shares.filter(s=>res[s]).map(s=>`${E(s)}: gap <span class="${cl(res[s].gap*(dr||1))}">${pc(res[s].gap)}</span> · then to 15:10 <span class="${cl(res[s].oc*(dr||1))}">${pc(res[s].oc)}</span>`).join(" &nbsp; ")}</div>`:"";
      return `<div class="r" title="${E(it.why)}"><div class="a"><span class="t">${E(it.time)}</span><span class="${dr>0?"up":dr<0?"dn":"dim"}">${dr>0?"▲ UP":dr<0?"▼ DOWN":"? unclear"}</span><span class="k ${E(it.strength)}">${E(it.strength)}</span>${sh}</div><div class="hl">${E(it.headline)}${it.why?` <span class="dim">— ${E(it.why)}</span>`:""}</div>${rr}</div>`; };
    const R=V.record||{}, rec=k=>R[k]?`${R[k][0]} cases · gap <b>${pc(R[k][1])}</b> · open→10:00 <b class="${cl(R[k][2])}">${pc(R[k][2])}</b> · open→15:10 <b class="${cl(R[k][3])}">${pc(R[k][3])}</b> · paid ${R[k][4]}%`:"none yet";
    el.innerHTML=`<div class="h">🌙 OVERNIGHT · FOR THE OPEN<small>news after yesterday's close and the F&O shares it touches · a paper record - no sound · read at 08:35${mine&&V.at?" (today "+E(V.at)+", "+E(V.n_lines)+" lines since "+E(V.since)+")":""}</small></div>`+
      (I.length?I.map(row).join(""):`<div class="none">${mine?(V.note?E(V.note):"nothing after the close that touches an F&O share"):"today's list is made at 08:35"}</div>`)+
      `<div class="rec">the record (${E(V.days||0)} days), the listed direction · strong: ${rec("strong")}<br>moderate: ${rec("moderate")} · weak: ${rec("weak")}<br><span class="dim">the gap is over before anyone can trade it - open→10:00 and open→15:10 are what a trade from the open would get</span></div>`; }
  async function pull(){ try{ const r=await fetch("overnight?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} draw(); }
  setInterval(()=>{ if(!document.hidden) pull(); },120000); setTimeout(pull,2000); })();
</script>
ADD_358
cp $W/overnight.py $D/overnight.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 358" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/overnight":                # patch 358: the overnight news for the open and its record (a paper record, read only)
                try:
                    import overnight
                    v_ = overnight.view()
                except Exception:
                    v_ = {"day": None, "items": [], "record": {}}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /overnight")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 358" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the 🌙 OVERNIGHT box in TRADE NOW")
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
cd $D && python3 -c "
import overnight, datetime as dt
s, L = overnight.lines(dt.datetime.now(overnight.IST)); v = overnight.view()
print('  overnight: %d news lines in GIR since %s · the record: %d days' % (len(L), s.strftime('%d %b %H:%M'), v['days']))" || back
cat > $U/gir-overnight.service <<'UNIT'
[Unit]
Description=GIR overnight news - the list before the open (08:35) and its score (15:50), overnight.py, patch 358
[Service]
Type=oneshot
TimeoutStartSec=900
Nice=10
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 overnight.py auto >> data/overnight_run.txt 2>&1'
UNIT
cat > $U/gir-overnight.timer <<'UNIT'
[Unit]
Description=GIR overnight news, 08:35 and 15:50 IST Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 08:35:00 Asia/Kolkata
OnCalendar=Mon..Fri *-*-* 15:50:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-overnight.timer >/dev/null 2>&1 && systemctl start gir-overnight.timer || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · the timer: $(systemctl is-active gir-overnight.timer)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-overnight.timer)" = "active" ] || back
echo "✅ patch 358 done - refresh GIR (Ctrl+Shift+R): the 🌙 OVERNIGHT box is in TRADE NOW under the 🧪 box. It reads at 08:35 and scores at 15:50 on market days."
echo "   today's list now (before 09:15 only, under ₹1): systemctl start gir-overnight.service   ·   its log: tail -5 $D/data/overnight_run.txt"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/overnight.py; systemctl disable --now gir-overnight.timer; rm -f $U/gir-overnight.*; systemctl daemon-reload; systemctl restart gir-dash"
