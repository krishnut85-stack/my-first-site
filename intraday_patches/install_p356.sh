#!/bin/bash
# PATCH 356 - 🧭 WHO & WHY ON THE PAGE, EVERY EVENING BY ITSELF (Rama, 17 Nov: "someone is moving the sector ... at least we can see the trend
#   on a daily basis and we can build from there"). Two read-only tools already run by hand:
#     whydesk.py  the day's 5 strongest / weakest sectors: who pushed them, GIR's own reasons, delivery against normal, FII positions, deals -
#                 and one reading of those facts (Claude Haiku 5.5, the key in the server's .env) ending with the news that came AFTER THE CLOSE
#     fpisec.py   NSDL's fortnightly record of foreign funds' buying / selling in each sector (2 years tested: the sectors they bought beat the
#                 ones they sold in the SAME fortnight 42 of 48 times; once the report is public there was no edge)
#   This patch:  · gir-whydesk.timer - Monday-Friday 19:40 and 22:30 IST: fpisec.py update, then whydesk.py (one record a day kept in data/whydesk/)
#                · dashserve /whydesk · a 🧭 WHO & WHY button on the SECTORS box (on the phone: on the box its tab shows) that opens the panel:
#                  AFTER THE CLOSE - FOR TOMORROW · THE DAY · the sectors read · why each moved · FOREIGN FUNDS BY SECTOR · FII / fund positions
#   It explains and records - it is NOT a trade alert: no sound, no Telegram, no order. The engine, the desk and the alerts are not touched.
#   Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 356" $D/home.html && grep -q "patch 356" $D/dashserve.py && [ -f $U/gir-whydesk.timer ]; then echo "patch 356 - already in"; systemctl list-timers gir-whydesk.timer --no-pager 2>/dev/null | head -3; exit 0; fi
grep -q "patch 355" $D/home.html && grep -q 'id="q-don"' $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && [ -f $D/seclive.py ] && [ -f $D/nsextra.py ] || { echo "patch 355 / the SECTORS box / dashserve's route / nsextra.py not found - nothing done"; exit 1; }
for f in whydesk.py fpisec.py flowtest.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
python3 -m py_compile $W/whydesk.py $W/fpisec.py $W/flowtest.py || { echo "❌ did not compile - nothing changed"; exit 1; }
grep -q "^def view" $W/whydesk.py && grep -q '"update"' $W/fpisec.py || { echo "❌ the fetched whydesk.py / fpisec.py are older than this patch - nothing done"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
for f in whydesk.py fpisec.py flowtest.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak356; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for f in whydesk.py fpisec.py flowtest.py; do [ -f $D/$f.bak356 ] && cp $D/$f.bak356 $D/$f; done
  systemctl disable --now gir-whydesk.timer >/dev/null 2>&1; rm -f $U/gir-whydesk.service $U/gir-whydesk.timer; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_356'
<style>/* patch 356: 🧭 WHO & WHY - the evening reading and the foreign funds' sector trend, a panel opened from the SECTORS box */
#gxwyb{margin-left:8px;padding:2px 8px;border:1px solid #2b5a8a;border-radius:10px;background:#0f2238;color:#8fc3ff;font:700 11px ui-monospace,Menlo,monospace;cursor:pointer;vertical-align:middle;white-space:nowrap}
#gxwyb:hover{background:#17324f}
#gxwy{position:fixed;inset:0;z-index:9000;background:rgba(3,8,14,.86);display:none;overflow:auto;-webkit-overflow-scrolling:touch}
#gxwy.on{display:block}
#gxwy .p{max-width:1040px;margin:14px auto;padding:0 0 14px;border:1px solid #24405c;border-radius:10px;background:#0b1522;color:#e6edf3;font:13px/1.5 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxwy .hd{position:sticky;top:0;display:flex;align-items:flex-start;gap:10px;padding:10px 14px;border-bottom:1px solid #1b3048;background:#0d1a2b;border-radius:10px 10px 0 0}
#gxwy .hd b{font:800 13px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#8fc3ff}#gxwy .hd small{display:block;color:#a3aebf;font-size:11.5px;margin-top:2px}
#gxwy .x{margin-left:auto;padding:4px 12px;border:1px solid #2b5a8a;border-radius:6px;background:#0f2238;color:#e6edf3;font:700 13px ui-monospace,Menlo,monospace;cursor:pointer}
#gxwy h4{margin:14px 14px 6px;font:800 11.5px ui-monospace,Menlo,monospace;letter-spacing:.07em;color:#8fc3ff}#gxwy h4 span{font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf;margin-left:6px}
#gxwy .tx{margin:0 14px;padding:10px 12px;border:1px solid #14243a;border-radius:6px;background:#0a1320;white-space:pre-wrap;word-break:break-word;font-size:12.5px}
#gxwy .tx b{color:#fff}#gxwy .tx i{font-style:normal;color:#8fc3ff;font-weight:700}
#gxwy .tx.am{border-color:#6b5a1e;background:#15140a}
#gxwy .sc{margin:0 14px;overflow-x:auto}#gxwy table{border-collapse:collapse;width:100%;font:12px ui-monospace,Menlo,monospace}
#gxwy th,#gxwy td{padding:4px 8px;border-bottom:1px solid #14243a;text-align:right;white-space:nowrap}#gxwy th{color:#a3aebf;font-weight:600}
#gxwy td:first-child,#gxwy th:first-child{text-align:left}#gxwy td.l{text-align:left;white-space:normal;color:#c9d4e3}
#gxwy .up{color:#26c281}#gxwy .dn{color:#f0544f}#gxwy .dim{color:#a3aebf}
#gxwy .nt{margin:6px 14px 0;color:#a3aebf;font-size:11.5px}
@media (max-width:700px){#gxwy .p{margin:0;border-radius:0;border-left:0;border-right:0}#gxwy .hd{border-radius:0}#gxwy h4{margin:12px 10px 5px}#gxwy .tx,#gxwy .sc{margin:0 10px}#gxwy .nt{margin:6px 10px 0}#gxwy td.l{white-space:nowrap}#gxwy th,#gxwy td{padding:4px 7px}}
</style>
<script>/* patch 356 (Rama, 17 Nov: "someone is moving the sector ... at least we can see the trend on a daily basis and build from there"):
   the evening's WHO & WHY - whydesk.py's reading of the day (who pushed each sector, GIR's own reasons, delivery, positions, deals; the news that
   came after the close) and fpisec.py's record of foreign funds' buying / selling by sector (NSDL, every 15 days). It explains and records -
   NOT a trade alert: no sound. dashserve /whydesk, read when the page opens and every 10 minutes. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const MN=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const dm=d=>{ const m=/^(\d{4})-(\d\d)-(\d\d)/.exec(String(d||"")); return m?(+m[3])+" "+MN[+m[2]-1]:"—"; };
  const n0=v=>v==null?"?":(v<0?"−":"+")+Math.abs(Math.round(v)).toLocaleString("en-IN");
  const cl=v=>v==null?"dim":v>=0?"up":"dn", pc=v=>v==null?"—":(v>=0?"+":"")+(+v).toFixed(2)+"%";
  let V=null;
  const txt=t=>E(t).split("\n").map(l=>/^[A-Z][A-Z &amp;,;\-]{2,}\s[+\-−]\d/.test(l)?"<b>"+l+"</b>":l.replace(/^(WHY|KIND|WHO|EXPOSED|WATCH TOMORROW|THE DAY|AFTER THE CLOSE[^:]*):/,"<i>$1:</i>")).join("\n");
  function html(){ const v=V||{}, f=v.fpi, hh=[];
    hh.push(`<div class="hd"><div><b>🧭 WHO &amp; WHY${v.day?" · "+E(dm(v.day))+(v.at?" · read "+E(v.at):""):""}</b><small>the day's reading and the record · no sound · runs by itself at 19:40 and 22:30 on market days</small></div><button class="x" type="button" data-x="1">✕ CLOSE</button></div>`);
    if(!v.day&&!f){ hh.push(`<div class="nt" style="padding:14px 0">no reading yet - the first one runs this evening at 19:40.</div>`); return hh.join(""); }
    if(v.after) hh.push(`<h4>AFTER THE CLOSE · FOR TOMORROW<span>news that came after 15:30 - not yet tested against prices</span></h4><div class="tx am">${txt(v.after.replace(/^AFTER THE CLOSE[^\n]*\n?/,""))}</div>`);
    if(v.theday) hh.push(`<h4>THE DAY</h4><div class="tx">${txt(v.theday.replace(/^THE DAY:\s*/,""))}</div>`);
    if((v.sectors||[]).length) hh.push(`<h4>THE SECTORS READ<span>all NSE shares of the sector, by size · taken home = delivery against its 10-day normal</span></h4><div class="sc"><table><tr><th>sector</th><th>move</th><th>up / down</th><th>taken home</th><th style="text-align:left">pushing it</th></tr>`+
      v.sectors.map(s=>`<tr><td>${E(s.n)}</td><td class="${cl(s.mv)}">${pc(s.mv)}</td><td>${E(s.up)} / ${E(s.dn)}</td><td class="${s.x10==null?"dim":s.x10>=1.3?"up":""}">${s.x10==null?"—":(+s.x10).toFixed(2)+"x"}</td><td class="l">${(s.push||[]).map(p=>E(p[0])+' <span class="'+cl(p[1])+'">'+pc(p[1])+"</span>").join(" · ")}</td></tr>`).join("")+`</table></div>`);
    if(v.sectors_text) hh.push(`<h4>WHY EACH SECTOR MOVED<span>read from GIR's own facts only - "no reason in today's data" is said when there is none</span></h4><div class="tx">${txt(v.sectors_text)}</div>`);
    if(f&&(f.rows||[]).length){ const run=r=>Math.abs(r.run)>=2?`<span class="${r.run>0?"up":"dn"}">${r.run>0?"BUYING":"SELLING"} ${Math.abs(r.run)} in a row</span>`:'<span class="dim">mixed</span>';
      hh.push(`<h4>FOREIGN FUNDS BY SECTOR<span>NSDL, every 15 days · net buying (+) / selling (−) of shares, ₹ crore · fortnight ending</span></h4><div class="sc"><table><tr><th>sector</th>${f.ends.map(e=>"<th>"+E(dm(e))+"</th>").join("")}<th>run</th><th>last 3 months</th></tr>`+
        f.rows.map(r=>`<tr><td>${E(r.s)}</td>${f.ends.map((e,i)=>`<td class="${cl(r.v[i])}">${n0(r.v[i])}</td>`).join("")}<td>${run(r)}</td><td class="${cl(r.tot)}">${n0(r.tot)}${r.held?' <span class="dim">'+pc(100*r.tot/r.held)+"</span>":""}</td></tr>`).join("")+`</table></div>`+
        `<div class="nt">Tested on 2 years: in the SAME fortnight the sectors they bought most beat the ones they sold most 42 times of 48. From 6 trading days after the fortnight, over the next 10 days, the bought sectors beat the sold ones 19 times of 47, and sectors bought 3 fortnights in a row came in 0.56% behind the market. Buying after a fall against buying after a rise: python3 fpisec.py, part 3b.</div>`); }
    if((v.who||[]).length) hh.push(`<h4>POSITIONS<span>NSE's participant file · futures contracts, + net long / − net short · whole market, not one sector</span></h4><div class="sc"><table><tr><th>who</th><th>index futures</th><th>day</th><th>stock futures</th><th>day</th></tr>`+
      v.who.map(p=>`<tr><td>${E(p.who)}</td><td class="${cl(p.index_fut_net)}">${n0(p.index_fut_net)}</td><td class="${cl(p.index_fut_change_1d)}">${n0(p.index_fut_change_1d)}</td><td class="${cl(p.stock_fut_net)}">${n0(p.stock_fut_net)}</td><td class="${cl(p.stock_fut_change_1d)}">${n0(p.stock_fut_change_1d)}</td></tr>`).join("")+`</table></div>`);
    return hh.join(""); }
  function open(){ let el=document.getElementById("gxwy"); if(!el){ el=document.createElement("div"); el.id="gxwy"; el.addEventListener("click",e=>{ if(e.target===el||(e.target.dataset&&e.target.dataset.x)) el.classList.remove("on"); }); document.body.appendChild(el); }
    el.innerHTML=`<div class="p">${html()}</div>`; el.classList.add("on"); el.scrollTop=0; pull(true); }
  function btn(){ /* on the header that is on screen: SECTORS (laptop, iPad) - on the phone whichever of these boxes its tab shows */
    const hs=["#q-don h3","#q-rot h3","#q-mov h3"].map(q=>document.querySelector(q)).filter(Boolean); if(!hs.length) return;
    const h=hs.find(x=>x.getBoundingClientRect().height>0)||hs[0]; let b=document.getElementById("gxwyb");
    if(!b){ b=document.createElement("button"); b.id="gxwyb"; b.type="button"; b.addEventListener("click",e=>{ e.stopPropagation(); e.preventDefault(); open(); }); }
    if(b.parentElement!==h) h.appendChild(b);
    const t="🧭 WHO & WHY"+(V&&V.day?" · "+dm(V.day):""); if(b.textContent!==t) b.textContent=t; }
  async function pull(redraw){ try{ const r=await fetch("whydesk?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ const j=await r.json(), ch=!V||j.saved!==V.saved; V=j;
      const el=document.getElementById("gxwy"); if(redraw&&ch&&el&&el.classList.contains("on")){ const y=el.scrollTop; el.innerHTML=`<div class="p">${html()}</div>`; el.scrollTop=y; } } }catch(e){} btn(); }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"){ const el=document.getElementById("gxwy"); if(el) el.classList.remove("on"); } });
  setInterval(()=>{ if(!document.hidden) pull(true); },600000); setInterval(btn,1500); setTimeout(pull,2500); })();
</script>
ADD_356
cp $W/whydesk.py $D/whydesk.py && cp $W/fpisec.py $D/fpisec.py && cp $W/flowtest.py $D/flowtest.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 356" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/whydesk":                  # patch 356: the evening's WHO & WHY reading + the foreign funds' sector trend (local files, read only)
                try:
                    import whydesk
                    v_ = whydesk.view()
                except Exception:
                    v_ = {"day": None, "fpi": None}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /whydesk")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 356" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the 🧭 WHO & WHY button and panel")
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
import whydesk; v = whydesk.view()
print('  whydesk: the last reading', v.get('day') or 'none yet', '·', len(v.get('sectors') or []), 'sectors · foreign funds:', (str(len(v['fpi']['rows'])) + ' sectors to ' + v['fpi']['ends'][0]) if v.get('fpi') else 'not fetched yet')" || back
cat > $U/gir-whydesk.service <<'UNIT'
[Unit]
Description=GIR who and why - the evening reading (whydesk.py) and NSDL's foreign-fund sector report (fpisec.py), patch 356
[Service]
Type=oneshot
TimeoutStartSec=1200
Nice=10
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && { python3 fpisec.py update > data/fpisec_run.txt 2>&1; python3 whydesk.py > data/whydesk_run.txt 2>&1; }'
UNIT
cat > $U/gir-whydesk.timer <<'UNIT'
[Unit]
Description=GIR who and why, 19:40 and 22:30 IST Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 19:40:00 Asia/Kolkata
OnCalendar=Mon..Fri *-*-* 22:30:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-whydesk.timer >/dev/null 2>&1 && systemctl start gir-whydesk.timer || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · the timer: $(systemctl is-active gir-whydesk.timer)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-whydesk.timer)" = "active" ] || back
echo "✅ patch 356 done - refresh GIR (Ctrl+Shift+R): the 🧭 WHO & WHY button is on the SECTORS box in MARKET. It reads by itself at 19:40 and 22:30 on market days."
echo "   a reading now (optional, under ₹1): systemctl start gir-whydesk.service   ·   its log: tail -5 $D/data/whydesk_run.txt"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-whydesk.timer; rm -f $U/gir-whydesk.*; systemctl daemon-reload; systemctl restart gir-dash"
