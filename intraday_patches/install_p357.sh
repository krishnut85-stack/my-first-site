#!/bin/bash
# PATCH 357 - THE NOTE ON A SHARE (Rama, 17 Nov: "when I hover over the shares there should be a note pad opening saying why the stock is
#   behaving - or somewhere easy to show the information that is required to know regularly").
#   · sharenote.py + dashserve /note: one short note for a share from what GIR already holds (nothing fetched from outside - it opens at once):
#     WHY (GIR's own reasons: results, filings, checked news, a broker's call, results due - or "no company news found") · SECTOR (its move and
#     rank today, this share's part of it) · LEVELS (its 20-day high / low, yesterday's close) · MONEY as bullet points (foreign funds and
#     mutual funds in its sector, the futures build-up, named big deals, delivery against its normal, FII / DII futures positions) ·
#     MARKET NEWS (the strongest market-wide headlines, positive or negative) · DUE (results date) · TODAY (a 🧪 paper-test candidate?)
#   · the page: the note opens when the mouse rests on ANY share name (movers, rotation, candidates, BUY cards, alerts, sector lists ...);
#     on the iPad and the phone: press and hold a share. A tap / click still opens its trading screen as before.
#   No sound, no alert, nothing is hidden or moved. The engine, the desk and the alerts are not touched. Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 357" $D/home.html && grep -q "patch 357" $D/dashserve.py && [ -f $D/sharenote.py ]; then echo "patch 357 - already in"; exit 0; fi
grep -q "</body>" $D/home.html && grep -q "mkOpen(" $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "parse_qs" $D/dashserve.py && [ -f $D/whymove.py ] && [ -f $D/seclive.py ] || { echo "the page / dashserve's route / whymove.py / seclive.py not found - nothing done"; exit 1; }
for f in sharenote.py fpisec.py mfsec.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
python3 -m py_compile $W/sharenote.py $W/fpisec.py $W/mfsec.py || { echo "❌ did not compile - nothing changed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
[ -f $D/fpisec.py ] && cp $D/fpisec.py $D/fpisec.py.bak357
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/sharenote.py; [ -f $D/fpisec.py.bak357 ] && cp $D/fpisec.py.bak357 $D/fpisec.py; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/home_add.html <<'ADD_357'
<style>/* patch 357: the note on a share - opens when the mouse rests on a share name; press and hold on a touch screen */
#gxnt{position:fixed;z-index:9500;display:none;width:430px;max-width:94vw;padding:0 0 8px;border:1px solid #3b6ea5;border-radius:8px;background:#0c1828;color:#e6edf3;
  box-shadow:0 10px 30px rgba(0,0,0,.6);font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;pointer-events:none}
#gxnt.on{display:block}
#gxnt.sheet{left:0!important;right:0;top:auto!important;bottom:0;width:auto;max-width:none;border-radius:12px 12px 0 0;padding-bottom:16px;pointer-events:auto;max-height:70vh;overflow:auto}
#gxnt .h{padding:8px 11px;border-bottom:1px solid #1b3048;background:#0f2238;border-radius:8px 8px 0 0}
#gxnt .h b{font:800 13.5px ui-monospace,Menlo,monospace;letter-spacing:.04em}#gxnt .h span{font:700 12.5px ui-monospace,Menlo,monospace;margin-left:8px}
#gxnt .h small{display:block;color:#a3aebf;font-size:11px;margin-top:1px}
#gxnt .k{margin:7px 11px 1px;font:800 10.5px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#8fc3ff}
#gxnt .v{margin:0 11px;color:#dbe4ef}#gxnt .v div{margin:1px 0}
#gxnt .up{color:#26c281}#gxnt .dn{color:#f0544f}#gxnt .dim{color:#a3aebf}#gxnt .am{color:#f0b429}
#gxnt .f{margin:8px 11px 0;color:#7f8b9c;font-size:10.5px}
</style>
<script>/* patch 357 (Rama, 17 Nov: "when I hover over the shares there should be a note pad opening saying why the stock is behaving"): one note
   for any share name on the page - GIR's own reasons, its sector today and its part of the sector's move, its 20-day levels, delivery, foreign
   funds in its sector, results due, today's paper test. dashserve /note (local data, no outside call). Mouse: rest on the name. Touch: press
   and hold. A click / tap opens the trading screen as before. No sound. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const RX=/(?:mkOpen|focusOn|openWin)\('([A-Z0-9&\-]{1,20})'\)/, IDX={NIFTY:1,BANKNIFTY:1,SENSEX:1,VIX:1,FINNIFTY:1,MIDCPNIFTY:1};
  const MN=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const dm=d=>{ const m=/^(\d{4})-(\d\d)-(\d\d)/.exec(String(d||"")); return m?(+m[3])+" "+MN[+m[2]-1]:""; };
  const rs=v=>v==null?"—":"₹"+(+v).toLocaleString("en-IN",{maximumFractionDigits:2}), pc=v=>v==null?"":(v>=0?"+":"")+(+v).toFixed(2)+"%", cl=v=>v==null?"dim":v>=0?"up":"dn";
  const C=new Map(); let el=null, cur=null, tm=null, held=false;
  function find(t){ for(let e=t,i=0;e&&e!==document.body&&i<7;e=e.parentElement,i++){ const a=e.getAttribute&&e.getAttribute("onclick"); if(a){ const m=RX.exec(a); if(m&&!IDX[m[1]]) return [m[1],e]; } } return null; }
  async function get(s){ const c=C.get(s); if(c&&Date.now()-c.t<45000) return c.v;
    try{ const r=await fetch("note?sym="+encodeURIComponent(s)+"&k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(!r.ok) return null; const v=await r.json(); C.set(s,{t:Date.now(),v}); if(C.size>300) C.clear(); return v; }catch(e){ return null; } }
  function html(v){ const h=[], sc=v.sector, lv=v.levels, dv=v.deliv, fp=v.fpi;
    h.push(`<div class="h"><b>${E(v.s)}</b>${v.px!=null?`<span>${rs(v.px)}</span>`:""}${v.chg!=null?`<span class="${cl(v.chg)}">${pc(v.chg)}</span>`:""}${v.name?`<small>${E(v.name)}</small>`:""}</div>`);
    h.push(`<div class="k">WHY</div><div class="v">${(v.why||[]).length?v.why.map(x=>"<div>• "+E(x)+"</div>").join(""):'<span class="dim">no company news in GIR - it is moving with its sector, the market or the money</span>'}</div>`);
    if(sc&&sc.name) h.push(`<div class="k">SECTOR</div><div class="v">${E(sc.name)}${sc.chg!=null?` <span class="${cl(sc.chg)}">${pc(sc.chg)}</span> · no.${E(sc.rank)} of ${E(sc.of)} today · ${E(sc.up)} up, ${E(sc.dn)} down`:""}${sc.part!=null?(sc.part>=0?` · this share makes <b>${E(sc.part)}%</b> of the sector's move`:` · <span class="am">going against its sector</span>`):""}</div>`);
    if(lv){ const a=lv.to_h20>0?`<span class="up">PAST its 20-day high ${rs(lv.h20)}</span>`:`20-day high ${rs(lv.h20)} <span class="dim">(${Math.abs(lv.to_h20).toFixed(1)}% above here)</span>`,
        b=lv.to_l20<0?`<span class="dn">BELOW its 20-day low ${rs(lv.l20)}</span>`:`20-day low ${rs(lv.l20)} <span class="dim">(${Math.abs(lv.to_l20).toFixed(1)}% below here)</span>`;
      h.push(`<div class="k">LEVELS</div><div class="v"><div>${a}</div><div>${b}${lv.yc!=null?` · yesterday's close ${rs(lv.yc)}`:""}</div></div>`); }
    { const x=[], f0=n=>(n<0?"−":"+")+Math.abs(Math.round(n)).toLocaleString("en-IN");
      if(fp) x.push(`<div>• <b>foreign funds</b> in ${E(fp.sector)}: ${Math.abs(fp.run)>=2?`<span class="${fp.run>0?"up":"dn"}">${fp.run>0?"BUYING":"SELLING"} ${Math.abs(fp.run)} fortnights in a row</span>`:(fp.last!=null?`<span class="${cl(fp.last)}">${fp.last>=0?"bought":"sold"}</span> last fortnight`:"—")} <span class="dim">(to ${E(dm(fp.to))}${fp.last!=null?", "+(fp.last<0?"−":"+")+"₹"+Math.abs(fp.last).toLocaleString("en-IN")+" cr":""})</span></div>`);
      if(v.mf) x.push(`<div>• <b>mutual funds</b>: ${E(v.mf.sector)} is ${E(v.mf.share)}% of their equity money${v.mf.vs3!=null?` · <span class="${v.mf.vs3>=0.3?"up":v.mf.vs3<=-0.3?"dn":"dim"}">${v.mf.vs3>=0?"+":""}${E(v.mf.vs3)} pt in 3 months${v.mf.vs3>=0.3?" - leaning in":v.mf.vs3<=-0.3?" - leaning out":""}</span>`:""} <span class="dim">(${E(v.mf.month)})</span></div>`);
      (v.fut||[]).forEach(t=>x.push(`<div>• <b>futures</b>: ${E(t)}</div>`));
      (v.deals||[]).forEach(d=>x.push(`<div>• <b>${E(d.kind)} deal</b> ${E(d.date)}: <span class="${/buy/i.test(d.side)?"up":"dn"}">${E(d.side)}</span> ₹${E(d.cr)} cr · ${E(d.client)}</div>`));
      if(dv) x.push(`<div>• <b>delivery</b> ${E(dv.pct)}% on ${E(dm(dv.day))} <span class="dim">(its normal ${E(dv.normal)}%)</span>${dv.pct>=dv.normal+10?' <span class="up">- well above normal</span>':dv.pct<=dv.normal-10?' <span class="dim">- well below normal</span>':""}</div>`);
      (v.who||[]).forEach(p=>{ if(p.idx1!=null||p.stk1!=null) x.push(`<div>• <b>${E(p.who)}</b> futures, whole market (${E(dm(p.day))}): index <span class="${cl(p.idx1)}">${p.idx1!=null?f0(p.idx1):"?"}</span> · stocks <span class="${cl(p.stk1)}">${p.stk1!=null?f0(p.stk1):"?"}</span> <span class="dim">contracts on the day</span></div>`); });
      if(x.length) h.push(`<div class="k">MONEY</div><div class="v">${x.join("")}</div>`); }
    if((v.macro||[]).length) h.push(`<div class="k">MARKET NEWS</div><div class="v">${v.macro.map(m=>`<div>• <span class="${m.side>0?"up":m.side<0?"dn":"dim"}">${m.side>0?"▲ positive":m.side<0?"▼ negative":"•"}</span> <span class="dim">${E(m.hm||"")}</span> ${E(m.h)}</div>`).join("")}</div>`);
    if(v.due) h.push(`<div class="k">DUE</div><div class="v"><span class="am">results ${E(dm(v.due))}</span></div>`);
    if((v.cand||[]).length) h.push(`<div class="k">TODAY</div><div class="v">${v.cand.map(c=>`<div>🧪 ${({A:"WEAK",B:"BREAK",E:"BOUNCE"})[c.kind]||E(c.kind)} candidate at ${E(c.t)} <span class="${c.dir>0?"up":"dn"}">${c.dir>0?"▲ CE":"▼ PE"}</span> from ${rs(c.px)} <span class="dim">(paper test)</span></div>`).join("")}</div>`);
    h.push(`<div class="f">GIR's own data · read ${E(v.at||"")}${el&&el.classList.contains("sheet")?" · tap outside to close":" · click = its trading screen"}</div>`);
    return h.join(""); }
  function box(){ if(!el){ el=document.createElement("div"); el.id="gxnt"; document.body.appendChild(el); } return el; }
  function hide(){ clearTimeout(tm); tm=null; cur=null; if(el) el.classList.remove("on","sheet"); }
  async function show(s,anchor,sheet){ const v=await get(s); if(!v||cur!==s||(v.px==null&&!v.sector&&!(v.why||[]).length)) return;
    const b=box(); b.classList.toggle("sheet",!!sheet); b.innerHTML=html(v); b.classList.add("on");
    if(!sheet){ const r=anchor.getBoundingClientRect(), w=b.offsetWidth, hh=b.offsetHeight; let x=r.right+10, y=r.top-6;
      if(x+w>innerWidth-6) x=r.left-w-10; if(x<6) x=Math.max(6,Math.min(innerWidth-w-6,r.left)), y=r.bottom+8;
      if(y+hh>innerHeight-6) y=Math.max(6,innerHeight-hh-6); b.style.left=x+"px"; b.style.top=Math.max(6,y)+"px"; } }
  document.addEventListener("mouseover",e=>{ if(held) return; const f=find(e.target); if(!f){ if(cur&&!(el&&el.classList.contains("sheet"))) hide(); return; }
    if(cur===f[0]) return; hide(); cur=f[0]; tm=setTimeout(()=>show(f[0],f[1],false),380); },true);
  document.addEventListener("mouseleave",()=>{ if(!(el&&el.classList.contains("sheet"))) hide(); });
  document.addEventListener("scroll",()=>{ if(el&&!el.classList.contains("sheet")) hide(); },true);
  document.addEventListener("keydown",e=>{ if(e.key==="Escape") hide(); });
  /* touch: press and hold = the note as a sheet at the bottom; the tap that follows does not open the trading screen */
  let t0=null;
  document.addEventListener("touchstart",e=>{ if(el&&el.classList.contains("sheet")&&!el.contains(e.target)){ hide(); held=false; }
    const f=find(e.target); if(!f) return; const p=e.touches[0]; t0={x:p.clientX,y:p.clientY};
    clearTimeout(tm); tm=setTimeout(()=>{ held=true; cur=f[0]; show(f[0],f[1],true); },560); },{passive:true,capture:true});
  document.addEventListener("touchmove",e=>{ if(!t0) return; const p=e.touches[0]; if(Math.abs(p.clientX-t0.x)>10||Math.abs(p.clientY-t0.y)>10){ clearTimeout(tm); t0=null; } },{passive:true,capture:true});
  document.addEventListener("touchend",()=>{ if(!held) clearTimeout(tm); t0=null; },{passive:true,capture:true});
  document.addEventListener("click",e=>{ if(held){ held=false; if(!(el&&el.contains(e.target))){ e.stopPropagation(); e.preventDefault(); } } },true);
  document.addEventListener("contextmenu",e=>{ if(held||find(e.target)&&("ontouchstart" in window)) e.preventDefault(); },true);
})();
</script>
ADD_357
cp $W/sharenote.py $D/sharenote.py && cp $W/fpisec.py $D/fpisec.py && cp $W/mfsec.py $D/mfsec.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 357" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/note":                     # patch 357: the note on a share - GIR's own reasons, its sector, levels, delivery, foreign funds, results due (local data, read only)
                try:
                    import sharenote
                    v_ = sharenote.view((parse_qs(u.query).get("sym") or [""])[0])
                except Exception:
                    v_ = {}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /note")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 357" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the note on a share (hover · press and hold)")
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
import sharenote; v = sharenote.view('RELIANCE')
print('  a note (RELIANCE):', 'price', v.get('px'), '· reasons', len(v.get('why') or []), '· sector', (v.get('sector') or {}).get('name'), '· levels', 'yes' if v.get('levels') else 'no', '· delivery', 'yes' if v.get('deliv') else 'no', '· foreign funds', 'yes' if v.get('fpi') else 'no')" || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 357 done - refresh GIR (Ctrl+Shift+R). Rest the mouse on any share name: the note opens. iPad / phone: press and hold the share."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/sharenote.py; systemctl restart gir-dash"
