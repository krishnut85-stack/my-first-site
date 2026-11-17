#!/bin/bash
# PATCH 360 - 💰 SECTOR MONEY: INVESTMENT AND DISINVESTMENT, EVERY SECTOR ON ONE BOARD (Rama, 17 Nov: "let's not drift away from finding the
#   sector investment and disinvestment ... we want to complete also about the sectors").
#   · secmoney.py + dashserve /secmoney: one row a sector from what GIR holds - TODAY (move, rank, up / down, who pushes it) · FOREIGN FUNDS
#     (NSDL: the last 4 fortnights, the run, 3 months as a % of holding) · MUTUAL FUNDS (SEBI: the sector's share of their money, its change in
#     3 months) · DELIVERY (the last file against the 10-day normal, 5 days against 20) · PRICE (against the market over 5 and 60 days, the
#     average RSI of its shares - overbought / oversold) · WHO (both buying / both selling / one buys what the other sells)
#   · the page: a 💰 SECTOR MONEY button on the SECTORS box opens the board; tap a column to sort by it; tap a sector = its F&O shares
#   Facts only - no alert, no sound. The engine, the desk and the alerts are not touched. Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 360" $D/home.html && grep -q "patch 360" $D/dashserve.py && [ -f $D/secmoney.py ]; then echo "patch 360 - already in"; exit 0; fi
grep -q 'id="q-don"' $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && [ -f $D/seclive.py ] || { echo "the SECTORS box / dashserve's route / seclive.py not found - nothing done"; exit 1; }
for f in secmoney.py fpisec.py mfsec.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
python3 -m py_compile $W/secmoney.py $W/fpisec.py $W/mfsec.py || { echo "❌ did not compile - nothing changed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
for f in fpisec.py mfsec.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak360; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/secmoney.py; for f in fpisec.py mfsec.py; do [ -f $D/$f.bak360 ] && cp $D/$f.bak360 $D/$f; done; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_360'
<style>/* patch 360: 💰 SECTOR MONEY - investment and disinvestment, every sector on one board, opened from the SECTORS box */
#gxsmb{margin-left:8px;padding:2px 8px;border:1px solid #2f7a55;border-radius:10px;background:#0e2a1e;color:#7be0a8;font:700 11px ui-monospace,Menlo,monospace;cursor:pointer;vertical-align:middle;white-space:nowrap}
#gxsmb:hover{background:#143a29}
#gxsm{position:fixed;inset:0;z-index:9000;background:rgba(3,8,14,.88);display:none;overflow:auto;-webkit-overflow-scrolling:touch}#gxsm.on{display:block}
#gxsm .p{max-width:1500px;margin:12px auto;border:1px solid #24405c;border-radius:10px;background:#0b1522;color:#e6edf3;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxsm .hd{position:sticky;top:0;z-index:2;display:flex;align-items:flex-start;gap:10px;padding:10px 14px;border-bottom:1px solid #1b3048;background:#0d1a2b;border-radius:10px 10px 0 0}
#gxsm .hd b{font:800 13px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#7be0a8}#gxsm .hd small{display:block;color:#a3aebf;font-size:11.5px;margin-top:2px}
#gxsm .x{margin-left:auto;padding:4px 12px;border:1px solid #2b5a8a;border-radius:6px;background:#0f2238;color:#e6edf3;font:700 13px ui-monospace,Menlo,monospace;cursor:pointer;white-space:nowrap}
#gxsm .sc{overflow-x:auto;padding:0 6px 8px}#gxsm table{border-collapse:collapse;width:100%;font:12px ui-monospace,Menlo,monospace}
#gxsm th,#gxsm td{padding:5px 8px;border-bottom:1px solid #14243a;text-align:right;white-space:nowrap}
#gxsm th{color:#a3aebf;font-weight:600;cursor:pointer;user-select:none;position:sticky;top:0;background:#0b1522}#gxsm th.g{color:#8fc3ff;text-align:center;cursor:default;border-bottom:0;padding-bottom:0}
#gxsm th.on{color:#fff}#gxsm td:first-child,#gxsm th:first-child{text-align:left}
#gxsm td.l{text-align:left;color:#c9d4e3}#gxsm tr.r{cursor:pointer}#gxsm tr.r:hover td{background:#0f1d30}
#gxsm .up{color:#26c281}#gxsm .dn{color:#f0544f}#gxsm .dim{color:#7f8b9c}#gxsm .am{color:#f0b429}
#gxsm .w{font:700 10.5px ui-monospace,Menlo,monospace;padding:1px 6px;border-radius:3px}#gxsm .w.bb{background:#11331f;color:#26c281}#gxsm .w.ss{background:#3a1616;color:#f0544f}#gxsm .w.mx{background:#2f2a12;color:#f0b429}
#gxsm .nt{margin:2px 14px 12px;color:#a3aebf;font-size:11.5px}
@media (max-width:700px){#gxsm .p{margin:0;border-radius:0;border-left:0;border-right:0}#gxsm .hd{border-radius:0}}
</style>
<script>/* patch 360 (Rama, 17 Nov: "let's not drift away from finding the sector investment and disinvestment"): every sector on one board -
   today's move, the foreign funds' fortnights (NSDL), the mutual funds' share (SEBI), delivery against normal, the price against the market
   and the zone. dashserve /secmoney (local data). Tap a column = sort · tap a sector = its F&O shares. Facts, not alerts. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const MN=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const dm=d=>{ const m=/^(\d{4})-(\d\d)(?:-(\d\d))?/.exec(String(d||"")); return m?(m[3]?(+m[3])+" ":"")+MN[+m[2]-1]:"—"; };
  const n0=v=>v==null?"—":(v<0?"−":"+")+Math.abs(Math.round(v)).toLocaleString("en-IN"), pc=(v,d)=>v==null?"—":(v>=0?"+":"")+(+v).toFixed(d==null?2:d)+"%", cl=v=>v==null?"dim":v>=0?"up":"dn";
  let V=null, SK="chg", SD=-1;
  const val={name:r=>r.name, chg:r=>r.chg, fpi:r=>r.fpi?r.fpi.v[0]:null, run:r=>r.fpi?r.fpi.run:null, f3:r=>r.fpi?r.fpi.pct:null, mf:r=>r.mf?r.mf.share:null, mf3:r=>r.mf?r.mf.vs3:null,
    dx:r=>r.deliv?r.deliv.x10:null, db:r=>r.deliv?r.deliv.build:null, r5:r=>r.r5, r60:r=>r.r60, rsi:r=>r.rsi};
  function html(){ const v=V||{}, R=(v.rows||[]).slice(), fe=v.fpi_ends||[];
    R.sort((a,b)=>{ const x=val[SK](a), y=val[SK](b); if(x==null&&y==null) return 0; if(x==null) return 1; if(y==null) return -1; return SK==="name"?SD*String(x).localeCompare(String(y)):SD*(x-y); });
    const th=(k,t,tt)=>`<th data-k="${k}" class="${SK===k?"on":""}" title="${E(tt||"")}">${t}${SK===k?(SD<0?" ▼":" ▲"):""}</th>`;
    const run=f=>!f?'<span class="dim">—</span>':Math.abs(f.run)>=2?`<span class="${f.run>0?"up":"dn"}">${f.run>0?"BUYING":"SELLING"} ${Math.abs(f.run)}</span>`:'<span class="dim">mixed</span>';
    const who=w=>!w?"":`<span class="w ${w==="BOTH BUYING"?"bb":w==="BOTH SELLING"?"ss":"mx"}">${E(w)}</span>`;
    const zone=r=>r.rsi==null?"—":`<span class="${r.rsi>=70?"am":r.rsi<=30?"am":""}">${E(r.rsi)}${r.rsi>=70?" overbought":r.rsi<=30?" oversold":""}</span>`;
    const row=r=>{ const f=r.fpi, m=r.mf, d=r.deliv; return `<tr class="r" data-s="${E(r.name)}" title="${E(r.fund_sector?"fund sector: "+r.fund_sector:"")}"><td>${E(r.name)}</td>`+
      `<td class="${cl(r.chg)}">${pc(r.chg)}</td><td class="dim">${r.up!=null?E(r.up)+"/"+E(r.dn):"—"}</td><td class="l">${(r.push||[]).slice(0,2).map(p=>E(p[0])+' <span class="'+cl(p[1])+'">'+pc(p[1],1)+"</span>").join(" · ")}</td>`+
      `<td class="${f?cl(f.v[0]):"dim"}">${f?n0(f.v[0]):"—"}</td><td>${run(f)}</td><td class="${f?cl(f.pct):"dim"}">${f?pc(f.pct):"—"}</td>`+
      `<td>${m?E(m.share)+"%":"—"}</td><td class="${m&&m.vs3!=null?(m.vs3>=0.2?"up":m.vs3<=-0.2?"dn":"dim"):"dim"}">${m&&m.vs3!=null?(m.vs3>=0?"+":"")+E(m.vs3)+" pt":"—"}</td>`+
      `<td class="${d?(d.x10>=1.3?"up":d.x10<=0.7?"dim":""):"dim"}">${d?(+d.x10).toFixed(2)+"x":"—"}</td><td class="${d&&d.build!=null?(d.build>=1.3?"up":d.build<=0.75?"dn":""):"dim"}">${d&&d.build!=null?(+d.build).toFixed(2)+"x":"—"}</td>`+
      `<td class="${cl(r.r5)}">${pc(r.r5,1)}</td><td class="${cl(r.r60)}">${pc(r.r60,1)}</td><td>${zone(r)}</td><td class="l">${who(r.who)}</td></tr>`; };
    return `<div class="hd"><div><b>💰 SECTOR MONEY</b><small>investment and disinvestment, every sector · today ${E(v.at||"—")} · foreign funds to ${E(dm(fe[0]))} (NSDL, fortnightly) · mutual funds ${E(dm(v.mf_month))} (SEBI, monthly) · daily prices to ${E(dm(v.prices_to))} · tap a column = sort · tap a sector = its F&O shares</small></div><button class="x" type="button" data-x="1">✕ CLOSE</button></div>`+
      `<div class="sc"><table><tr><th class="g"></th><th class="g" colspan="3">TODAY</th><th class="g" colspan="3">FOREIGN FUNDS</th><th class="g" colspan="2">MUTUAL FUNDS</th><th class="g" colspan="2">DELIVERY</th><th class="g" colspan="3">PRICE</th><th class="g">WHO</th></tr>`+
      `<tr>${th("name","sector")}${th("chg","move","all NSE shares of the sector, by size")}<th>up/dn</th><th style="text-align:left">pushing it</th>${th("fpi","last ₹cr","net buying (+) / selling (−) in the fortnight to "+dm(fe[0]))}${th("run","run","fortnights in a row the same way")}${th("f3","3 months","the last 6 fortnights as a % of what they hold")}`+
      `${th("mf","share","the sector's share of all mutual funds' equity money")}${th("mf3","3 months","the change in that share in 3 months - up = leaning in")}${th("dx","last day","the value taken home on NSE's last file against the sector's 10-day normal")}${th("db","5d / 20d","the last 5 days against the 20 before - above 1 = building")}`+
      `${th("r5","5 days","against the whole market")}${th("r60","60 days","against the whole market")}${th("rsi","zone","the average RSI(14) of its shares: above 70 overbought, under 30 oversold")}<th style="text-align:left"></th></tr>`+
      (R.length?R.map(row).join(""):`<tr><td colspan="15" class="dim">no data yet</td></tr>`)+`</table></div>`+
      `<div class="nt">Facts from GIR's own files. Banks, NBFC, insurance and capital markets share one fund sector (Financial Services); pharma and hospitals share Healthcare - the fund columns then repeat. A dash = that source has not been read on this server yet (python3 fpisec.py · python3 mfsec.py).</div>`; }
  function draw(){ const el=document.getElementById("gxsm"); if(el&&el.classList.contains("on")){ const y=el.scrollTop; el.innerHTML=`<div class="p">${html()}</div>`; el.scrollTop=y; } }
  function open(){ let el=document.getElementById("gxsm"); if(!el){ el=document.createElement("div"); el.id="gxsm";
      el.addEventListener("click",e=>{ const t=e.target; if(t===el||(t.dataset&&t.dataset.x)){ el.classList.remove("on"); return; }
        const h=t.closest&&t.closest("th[data-k]"); if(h){ const k=h.dataset.k; if(SK===k) SD=-SD; else { SK=k; SD=k==="name"?1:-1; } draw(); return; }
        const r=t.closest&&t.closest("tr.r"); if(r){ el.classList.remove("on"); try{ mkSec(r.dataset.s); }catch(e){} } });
      document.body.appendChild(el); }
    el.classList.add("on"); el.scrollTop=0; draw(); pull(); }
  function btn(){ const hs=["#q-don h3","#q-rot h3","#q-mov h3"].map(q=>document.querySelector(q)).filter(Boolean); if(!hs.length) return;
    const h=hs.find(x=>x.getBoundingClientRect().height>0)||hs[0]; let b=document.getElementById("gxsmb");
    if(!b){ b=document.createElement("button"); b.id="gxsmb"; b.type="button"; b.textContent="💰 SECTOR MONEY"; b.addEventListener("click",e=>{ e.stopPropagation(); e.preventDefault(); open(); }); }
    if(b.parentElement!==h) h.appendChild(b);
    if(innerWidth<=700&&!h.dataset.gxw){ h.dataset.gxw="1"; h.style.flexWrap="wrap"; h.style.whiteSpace="normal"; h.style.height="auto"; h.style.overflow="visible"; h.style.rowGap="4px"; } }
  async function pull(){ try{ const r=await fetch("secmoney?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ V=await r.json(); draw(); } }catch(e){} }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"){ const el=document.getElementById("gxsm"); if(el) el.classList.remove("on"); } });
  setInterval(()=>{ const el=document.getElementById("gxsm"); if(!document.hidden&&el&&el.classList.contains("on")) pull(); },120000); setInterval(btn,1500); })();
</script>
ADD_360
cp $W/secmoney.py $D/secmoney.py && cp $W/fpisec.py $D/fpisec.py && cp $W/mfsec.py $D/mfsec.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 360" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/secmoney":                 # patch 360: sector money - today, foreign funds, mutual funds, delivery, price and zone, one row a sector (local data, read only)
                try:
                    import secmoney
                    v_ = secmoney.view()
                except Exception:
                    v_ = {"rows": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /secmoney")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 360" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the 💰 SECTOR MONEY button and board")
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
import secmoney; v = secmoney.view(); R = v['rows']
print('  sector money: %d sectors · today %s · foreign funds %s (%d sectors) · mutual funds %s (%d) · delivery %d · daily prices to %s' % (len(R), v.get('at'), (v.get('fpi_ends') or ['not read yet'])[0], sum(1 for r in R if r.get('fpi')), v.get('mf_month') or 'not read yet', sum(1 for r in R if r.get('mf')), sum(1 for r in R if r.get('deliv')), v.get('prices_to')))" || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 360 done - refresh GIR (Ctrl+Shift+R): the 💰 SECTOR MONEY button is on the SECTORS box in MARKET."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/secmoney.py; systemctl restart gir-dash"
