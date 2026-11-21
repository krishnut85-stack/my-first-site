#!/bin/bash
# PATCH 318 - THE OPTION CHAIN PANEL REDESIGNED (Rama, 15 Nov: "still the same, no changes and not professional").
#   A trader's layout, laptop and phone: a header (NIFTY | BANKNIFTY switch, spot, expiry, days to expiry, lot, live / last session) · a
#   SIGNAL card (the WAIT / BUY CE / BUY PE badge, the checks as a scorecard, the trade with SL and target) · 6 figure tiles (PCR, MAX PAIN,
#   SUPPORT, RESISTANCE, ATM IV, EXP. MOVE) · FRESH WRITING (PE vs CE bar) · FUTURES ORDER BOOK (LTP, basis, bid share bar, best bid / ask,
#   large orders and cancelled orders as tags) · the chain as CALLS | STRIKE | PUTS with OI bars, ATM highlighted, in-the-money shaded,
#   R / S marked. The data and the signal unchanged (idxdesk.py untouched). Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 318: the option chain panel redesigned" $D/home.html; then echo "patch 318 - already in"; exit 0; fi
grep -q "function idxDeskHTML(J)" $D/home.html || { echo "home.html: the index options panel (patch 134) not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_318'
<style>/* patch 318: the option chain panel redesigned - a trader's layout (laptop and phone); the data and the signal unchanged */
.oc{--ocb:#0b1017;--ocl:#1c2532;--ocd:#8592a3;--ocm:#5d6878;--ocu:#26c281;--ocn:#f0544f;--oca:#f5a623;font:13px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3}
.oc .nm{font-family:ui-monospace,"SF Mono",Menlo,Consolas,monospace;font-variant-numeric:tabular-nums}
.oc .up{color:var(--ocu)}.oc .dn{color:var(--ocn)}.oc .am{color:var(--oca)}.oc .dm{color:var(--ocd)}.oc .mu{color:var(--ocm)}
.oc-h{display:flex;flex-wrap:wrap;align-items:center;gap:8px 16px;padding:4px 0 10px}
.oc-seg{display:inline-flex;border:1px solid var(--ocl);border-radius:6px;overflow:hidden}
.oc-seg a{padding:6px 12px;font:700 11.5px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:var(--ocd);cursor:pointer}.oc-seg a.on{background:var(--oca);color:#1a1205}
.oc-px{font:700 20px ui-monospace,Menlo,monospace}.oc-meta{display:flex;gap:6px;flex-wrap:wrap}
.oc-tag{font:600 11px ui-monospace,Menlo,monospace;padding:3px 8px;border:1px solid var(--ocl);border-radius:4px;color:var(--ocd);white-space:nowrap}
.oc-tag.live{color:var(--ocu);border-color:#1d5c42}
.oc-card{background:var(--ocb);border:1px solid var(--ocl);border-radius:8px;padding:12px;margin-bottom:10px}
.oc-ct{font:700 10.5px ui-monospace,Menlo,monospace;letter-spacing:.12em;color:var(--ocm);margin-bottom:8px}
.oc-sig{display:grid;grid-template-columns:auto 1fr;gap:12px;align-items:start}
.oc-badge{font:800 15px ui-monospace,Menlo,monospace;letter-spacing:.06em;padding:10px 14px;border-radius:6px;text-align:center;min-width:104px;background:#1b222d;color:var(--ocd)}
.oc-badge.CE{background:#0d3324;color:var(--ocu)}.oc-badge.PE{background:#3a1416;color:var(--ocn)}.oc-badge small{display:block;font:600 10.5px ui-monospace,Menlo,monospace;margin-top:4px;opacity:.85}
.oc-chk{display:grid;grid-template-columns:18px minmax(96px,auto) 1fr;gap:4px 8px;align-items:baseline;font-size:12.5px}
.oc-chk i{font-style:normal;text-align:center}.oc-chk .k{color:var(--ocd);font-size:11.5px;text-transform:uppercase;letter-spacing:.04em}
.oc-trade{margin-top:10px;padding:8px 10px;border-radius:6px;background:#0d1f17;border:1px solid #1d5c42;font:600 12.5px ui-monospace,Menlo,monospace}
.oc-note{margin-top:8px;color:var(--oca);font-size:12px}
.oc-kpi{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:8px;margin-bottom:10px}
.oc-k{background:var(--ocb);border:1px solid var(--ocl);border-radius:8px;padding:9px 10px}.oc-k .l{font:600 10px ui-monospace,Menlo,monospace;letter-spacing:.1em;color:var(--ocm)}
.oc-k .v{font:700 16px ui-monospace,Menlo,monospace;margin-top:3px}.oc-k .s{font-size:11px;color:var(--ocd);margin-top:1px}
.oc-split{display:flex;height:8px;border-radius:4px;overflow:hidden;background:#1b222d;margin:6px 0 4px}.oc-split b{display:block}
.oc-row2{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:10px}
.oc-bk{display:grid;grid-template-columns:1fr 1fr;gap:6px 14px;font-size:12.5px}.oc-bk .l{color:var(--ocd);font-size:11px;text-transform:uppercase;letter-spacing:.04em}
.oc-chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px}.oc-chip{font:600 11px ui-monospace,Menlo,monospace;padding:3px 7px;border-radius:4px;background:#121923;border:1px solid var(--ocl)}
.oc-chip.b{color:var(--ocu);border-color:#1d5c42}.oc-chip.s{color:var(--ocn);border-color:#5c1d1f}.oc-chip.x{color:var(--oca);border-color:#5c4410;text-decoration:line-through}
.oc-tb{width:100%;border-collapse:collapse;font:12.5px ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums}
.oc-tb th{font:600 10px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:var(--ocm);padding:6px;border-bottom:1px solid var(--ocl);text-align:right}
.oc-tb th.c{text-align:center}.oc-tb th.l{text-align:left}.oc-tb td{padding:5px 6px;border-bottom:1px solid #141b25;text-align:right;position:relative;white-space:nowrap}
.oc-tb td.k{text-align:center;font-weight:700;background:#0e141d}.oc-tb td.pl{text-align:left}
.oc-tb tr.itmc td.ce,.oc-tb tr.itmp td.pe{background:rgba(245,166,35,.05)}
.oc-tb tr.atm td{border-top:1px solid var(--oca);border-bottom:1px solid var(--oca)}.oc-tb tr.atm td.k{background:var(--oca);color:#1a1205}
.oc-tb .bar{position:absolute;top:4px;bottom:4px;opacity:.18;border-radius:2px}.oc-tb td.ce .bar{right:0;background:var(--ocn)}.oc-tb td.pe .bar{left:0;background:var(--ocu)}
.oc-tb td span{position:relative}.oc-tb .ch{font-size:11px;margin-left:4px}.oc-tb u{text-decoration:none;font:700 9px ui-monospace,Menlo,monospace;padding:1px 4px;border-radius:3px;margin-left:4px;vertical-align:1px}
.oc-tb u.r{background:#3a1416;color:var(--ocn)}.oc-tb u.s{background:#0d3324;color:var(--ocu)}
.oc-cap{display:flex;justify-content:space-between;font:600 10.5px ui-monospace,Menlo,monospace;letter-spacing:.1em;margin-bottom:6px}
@media(max-width:899px){
  .oc-kpi{grid-template-columns:repeat(3,minmax(0,1fr));gap:6px}.oc-k{padding:8px}.oc-k .v{font-size:14px}
  .oc-row2{grid-template-columns:1fr}.oc-sig{grid-template-columns:1fr}.oc-badge{min-width:0}
  .oc-chk{grid-template-columns:18px minmax(84px,auto) 1fr;font-size:12px}
  .oc-tb{font-size:11.5px}.oc-tb td,.oc-tb th{padding:5px 3px}.oc-tb .ch{display:block;margin-left:0;font-size:10px}.oc-tb td.cp,.oc-tb th.cp{display:none}
  .oc-px{font-size:18px}
}
</style>
<script>/* patch 318: the option chain panel redesigned - header, signal scorecard, figure tiles, futures order book, a CALLS | STRIKE | PUTS chain
   with OI bars, the ATM row and in-the-money strikes marked. Same data, same signal (idxdesk.py unchanged). */
(function(){ if(typeof idxDeskHTML!=="function") return;
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const N=(v,d)=>v==null||v===""||isNaN(v)?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:d||0,maximumFractionDigits:d==null?2:d});
  const L=v=>v==null?"—":Math.abs(v)>=1e7?(v/1e7).toFixed(2)+" Cr":Math.abs(v)>=1e5?(v/1e5).toFixed(1)+" L":N(v,0);
  const P=v=>v==null?"":`<span class="ch ${v>0?"up":v<0?"dn":"mu"}">${v>0?"+":""}${Math.abs(v)>=100?Math.round(v):v}%</span>`;
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const dm=s=>{ const m=String(s||"").match(/(\d{4})-(\d{2})-(\d{2})/); return m?(+m[3])+" "+MON[+m[2]-1]:E(s); };
  function check(t){ t=String(t||"");
    let m=t.match(/^writers: puts (.+?) · calls (.+?) since (.+)$/); if(m) return ["OI writing",`PE <b class="up">${E(m[1])}</b> · CE <b class="dn">${E(m[2])}</b> <span class="mu">vs ${E(m[3].replace("the last close","prev close"))}</span>`];
    m=t.match(/^PCR (.+?) → (.+?) since (.+)$/); if(m) return ["PCR trend",`${E(m[1])} → <b>${E(m[2])}</b> <span class="mu">since ${E(m[3])}</span>`];
    if(/^PCR /.test(t)) return ["PCR trend",E(t.replace(/^PCR /,"").replace("(its trend after 30 min)","· trend after 30 min"))];
    m=t.match(/^walls: (.+)$/); if(m) return ["OI levels",E(m[1]).replace(/\bfloor\b/g,"Support").replace(/\bceiling\b/g,"Resistance")];
    m=t.match(/^price (above|below) the last close \(([^)]+)\) and (above|below) its day average \(([^)]+)\)$/); if(m) return ["Spot",`${m[1]} prev close <b>${N(+m[2])}</b> · ${m[3]} day avg <b>${N(+m[4])}</b>`];
    if(/^price: /.test(t)) return ["Spot","vs day avg after the first readings"];
    m=t.match(/^futures book: buyers (.+?)% of the orders waiting(.*)$/); if(m) return ["Futures book",`bid share <b>${E(m[1])}%</b>${m[2]?` <span class="mu">${E(m[2].replace(" · big: "," · large: "))}</span>`:""}`];
    if(/^before 09:30/.test(t)) return ["Time","before 09:30 - opening volatility, no signal"];
    return ["Check",E(t)]; }
  idxDeskHTML=function(J){ const T=(typeof IDXT!=="undefined"&&IDXT)||"NIFTY";
    const seg=`<span class="oc-seg">${["NIFTY","BANKNIFTY"].map(n=>`<a class="${T===n?"on":""}" onclick="idxSet('${n}')">${n}</a>`).join("")}</span>`;
    const d=J&&J[T]; if(!d) return `<div class="oc"><div class="oc-h">${seg}<span class="dm">Option chain updates every minute from 09:15</span></div></div>`;
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10), live=d.day===today;
    const X=d.dec||{}, tr=X.trade, side=X.side==="CE"?"CE":X.side==="PE"?"PE":"";
    const head=`<div class="oc-h">${seg}<span class="oc-px nm">${N(d.spot)}</span><span class="nm ${d.chg>0?"up":d.chg<0?"dn":"dm"}">${d.chg>0?"+":""}${N(d.chg,2)}%</span>
      <span class="oc-meta"><span class="oc-tag">EXP ${dm(d.exp)} · ${d.dte??"—"} DTE</span><span class="oc-tag">LOT ${d.lot||"—"}</span><span class="oc-tag ${live?"live":""}">${live?"● LIVE "+E(d.t):"LAST SESSION · "+dm(d.day)+" "+E(d.t)}</span></span></div>`;
    const chk=(X.why||[]).map(w=>{ const c=check(w[1]); return `<i class="${w[0]>0?"up":w[0]<0?"dn":"mu"}">${w[0]>0?"▲":w[0]<0?"▼":"•"}</i><span class="k">${c[0]}</span><span>${c[1]}</span>`; }).join("");
    const n=(X.why||[]).length;
    const sig=`<div class="oc-card"><div class="oc-ct">SIGNAL</div><div class="oc-sig"><div class="oc-badge ${side}">${E(X.word||"—")}<small>▲ ${X.bull||0} · ▼ ${X.bear||0} of ${n||4}</small></div>
      <div><div class="oc-chk">${chk||'<span></span><span class="mu">no checks yet</span><span></span>'}</div>
      ${tr?`<div class="oc-trade">${E(tr.strike)} ${E(tr.kind)} @ ₹${N(tr.prem)} · SL ₹${N(tr.stop)} · target ${E(T)} ${N(tr.target_spot)}${tr.lot_cost?` · 1 lot ₹${N(tr.lot_cost,0)}`:""}</div>`
          :`<div class="oc-note mu">Entry needs 3 checks aligned and none opposed.</div>`}
      ${X.note?`<div class="oc-note">⚠ ${E(X.note)}</div>`:""}</div></div></div>`;
    const pa=Math.abs(d.pe_add||0), ca=Math.abs(d.ce_add||0), tot=pa+ca||1;
    const k=(l,v,s,c)=>`<div class="oc-k"><div class="l">${l}</div><div class="v nm ${c||""}">${v}</div>${s?`<div class="s">${s}</div>`:""}</div>`;
    const kpi=`<div class="oc-kpi">${k("PCR",d.pcr??"—",d.pcr==null?"":d.pcr>=1.2?"put heavy":d.pcr<=0.8?"call heavy":"balanced")}${k("MAX PAIN",N(d.pain),d.pain&&d.spot?((d.pain-d.spot)/d.spot*100).toFixed(1)+"% from spot":"")}
      ${k("SUPPORT",N(d.floor),"highest put OI","up")}${k("RESISTANCE",N(d.ceil),"highest call OI","dn")}${k("ATM IV",d.iv!=null?d.iv+"%":"—","")}${k("EXP. MOVE","±"+N(d.straddle),"ATM straddle")}</div>`;
    const wr=`<div class="oc-card"><div class="oc-ct">FRESH WRITING · ${E(String(d.ref||"prev close").replace("the last close","vs prev close"))}</div>
      <div class="oc-cap"><span class="up">PE ${L(d.pe_add)}</span><span class="dn">CE ${L(d.ce_add)}</span></div>
      <div class="oc-split"><b style="width:${(pa/tot*100).toFixed(1)}%;background:var(--ocu)"></b><b style="width:${(ca/tot*100).toFixed(1)}%;background:var(--ocn)"></b></div>
      <div class="mu" style="font-size:11.5px">${pa>ca?"Put writers more active - supportive":ca>pa?"Call writers more active - capping":"Balanced writing"}</div></div>`;
    const b=d.book;
    const bk=b?`<div class="oc-card"><div class="oc-ct">FUTURES ORDER BOOK · ${E(b.fut||"")}</div><div class="oc-bk">
        <div><div class="l">LTP</div><b class="nm">₹${N(b.px)}</b>${b.basis!=null?` <span class="mu nm">basis ${b.basis>0?"+":""}${b.basis}</span>`:""}</div>
        <div><div class="l">Bid share</div><b class="nm ${b.buy>=60?"up":b.buy!=null&&b.buy<=40?"dn":""}">${b.buy??"—"}%</b></div>
        <div><div class="l">Best bid</div><span class="nm up">${b.bids&&b.bids[0]?N(b.bids[0][0])+" × "+b.bids[0][1]:"—"}</span></div>
        <div><div class="l">Best ask</div><span class="nm dn">${b.asks&&b.asks[0]?N(b.asks[0][0])+" × "+b.asks[0][1]:"—"}</span></div></div>
        ${b.buy!=null?`<div class="oc-split"><b style="width:${b.buy}%;background:var(--ocu)"></b><b style="width:${100-b.buy}%;background:var(--ocn)"></b></div>`:""}
        ${(b.big||[]).length?`<div class="l mu" style="font-size:11px;margin-top:8px">LARGE ORDERS (≥2× avg ${E(b.usual)} lots)</div><div class="oc-chips">${b.big.map(x=>`<span class="oc-chip ${x.side==="BUY"?"b":"s"}">${x.side} ${x.lots} @ ${N(x.price)} · ${x.x}×</span>`).join("")}</div>`:""}
        ${(b.pulled||[]).length?`<div class="l mu" style="font-size:11px;margin-top:8px">CANCELLED BEFORE FILL</div><div class="oc-chips">${b.pulled.map(x=>`<span class="oc-chip x">${x.side} ${x.lots} @ ${N(x.price)}</span>`).join("")}</div>`:""}
      </div>`:"";
    const R=(d.rows||[]).slice().sort((a,c)=>a.k-c.k), mx=Math.max(1,...R.map(r=>Math.max(r.ce||0,r.pe||0)));
    const rows=R.map(r=>{ const itmc=d.spot!=null&&r.k<d.spot, itmp=d.spot!=null&&r.k>d.spot;
      return `<tr class="${r.k===d.atm?"atm ":""}${itmc?"itmc ":""}${itmp?"itmp":""}">
        <td class="ce cp"><span class="dm">${r.ce_p!=null?N(r.ce_p):"—"}</span></td>
        <td class="ce"><i class="bar" style="width:${((r.ce||0)/mx*100).toFixed(0)}%"></i><span>${L(r.ce)}</span>${P(r.ce_pc)}</td>
        <td class="k">${N(r.k,0)}${r.k===d.ceil?'<u class="r">R</u>':""}${r.k===d.floor?'<u class="s">S</u>':""}</td>
        <td class="pe pl"><i class="bar" style="width:${((r.pe||0)/mx*100).toFixed(0)}%"></i><span>${L(r.pe)}</span>${P(r.pe_pc)}</td>
        <td class="pe cp pl"><span class="dm">${r.pe_p!=null?N(r.pe_p):"—"}</span></td></tr>`; }).join("");
    const chain=`<div class="oc-card" style="padding:10px 8px"><div class="oc-cap" style="padding:0 6px"><span class="dn">CALLS</span><span class="mu">OPTION CHAIN · OI · Δ% vs prev close</span><span class="up">PUTS</span></div>
      <table class="oc-tb"><thead><tr><th class="cp">LTP</th><th>OI</th><th class="c">STRIKE</th><th class="l">OI</th><th class="cp l">LTP</th></tr></thead><tbody>${rows}</tbody></table>
      <div class="mu" style="font-size:11px;padding:6px 6px 0">ATM highlighted · shaded = in the money · R = resistance (highest call OI) · S = support (highest put OI)</div></div>`;
    return `<div class="oc">${head}${sig}${kpi}<div class="oc-row2">${wr}${bk}</div>${chain}</div>`; };
  try{ if(typeof drawMarket==="function"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } }catch(e){}
})();
</script>
ADD_318
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 318")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  for f in home.html; do
    python3 - $D/$f $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
    node --check $W/page.js 2>$W/js.err || { echo "❌ $f:"; head -5 $W/js.err; back; }
  done
  echo "  the page code checked ✓"
fi
echo "✅ patch 318 done - NIFTY / BANKNIFTY OPTION CHAIN in a trader's layout (laptop and phone). Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
