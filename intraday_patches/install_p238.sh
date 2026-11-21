#!/bin/bash
# PATCH 238 - THE SHARE WINDOW, Rama's points of 13 Nov:
#   1/2 the tab says "⌂ GIR HOME" or "ATHERENERG ₹1,923 +2.93%" (every tab said "GIR" - an alert's flash put back the page's first title)
#   3   the RSI pane is no longer pushed out of the box by the toolbar (measured, not assumed) · the header shows "RSI 5m 61 · daily 74 ⚠ overbought"
#   4   the share's name, price and % stay fixed on top when its window scrolls
#   5   hovering a candle with an "OI" mark explains it: "🔴 OI 11:20 · <the reading> - where the option money stood, not a forecast"
#   6   one chain: a 0.3% move or a VWAP cross fetches the checklist, the option chain, the chart and who-is-pushing at once ("🔗 all refreshed")
#   Tested in a browser: 9 cases (the old page reproduces the "GIR" tab). Page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 214" $D/home.html || { echo "patch 214 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p238_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p238_patch.py - PATCH 238: THE SHARE WINDOW, Rama's six points (13 Nov):
  1/2 the browser tab names the page: "⌂ GIR HOME" - or the share with its price "ATHERENERG ₹1,923 +2.9%" (it was "GIR" on every tab: the alert
      flash put back the title the page had when it first loaded)
  3   RSI: the chart's toolbar wraps to 2-3 rows on the laptop and pushed the RSI pane below the box - now its real height is measured.
      The header also shows the DAILY RSI (Kite's chart) next to the 5-min one: "RSI 5m 61 · daily 74 ⚠ overbought"
  4   the share's name, price and % stay fixed at the top of its window when you scroll
  5   the chart's OI marks explain themselves: hover a candle with an "OI" mark -> "🔴 OI 11:20 · <the reading> - where the option money stood at
      that candle, not a forecast"
  6   one chain: when the live price moves 0.3% or crosses VWAP, the checklist, the option chain, the chart and who-is-pushing are fetched at
      once (not each on its own clock) - the header says "🔗 all refreshed HH:MM:SS"; the push strip shows its time
Page only. Usage: python3 p238_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); S = {"s": open(p, encoding="utf-8").read()}
ERR = []


def rep(old, new, tag, marker=None):
    s = S["s"]
    if new in s or (marker and marker in s):
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  home.html: %s" % tag)


# 1/2 the tab's name
rep('''let ATITLE=document.title; function titleFlag(on){ document.title=on?"🔴 ALERT · "+ATITLE:ATITLE; }''',
    '''let ATITLE=document.title; function titleFlag(on){ document.title=on?"🔴 ALERT · "+gTitle():gTitle(); }   /* patch 238: never back to a stale "GIR" */
function gTitle(){ const s=SOLO||""; if(!s) return "⌂ GIR HOME"+(FOC?" · "+FOC:"");
  const t=(TAPE||[]).find(x=>x.s===s)||{}; const px=(FOC===s&&FLV&&FLV.px)?FLV.px:t.px; const pcv=(FOC===s&&((FLV&&FLV.pc)||(FCH&&FCH.pc)))||null;
  const ch=(px&&pcv)?(px/pcv-1)*100:t.chg; return s+(px?" ₹"+inr(px):"")+(ch!=null?" "+pc(ch):""); }
setInterval(()=>{ try{ if(/🔴 ALERT/.test(document.title)) return; const pre=(document.title.match(/^\\(\\d+\\) /)||[""])[0]; const t=pre+gTitle(); if(document.title!==t) document.title=t; }catch(e){} },3000);''',
    "the tab: ⌂ GIR HOME / the share and its price")
# 3 the RSI pane: the toolbar's real height
rep('''PC.tb.innerHTML=proToolbar(); proCharts();''',
    '''PC.tb.innerHTML=proToolbar(); { const tbh=PC.tb.offsetHeight||34; if(tbh>34){ PC.mh=proMainH(H,sh,tbh); el.querySelector(".pmain").style.height=PC.mh+"px"; } } proCharts();   /* patch 238: the RSI pane stays inside the box */''',
    "the RSI pane: the toolbar's real height")
# 3 daily RSI · 6 the chain mark - in the header
rep('''<span class="dim">${esc(age)}</span>''', '''<span class="dim">${esc(age)}</span>${rsiTag()}${chainTag()}''', "the header: RSI 5m · daily · the chain")
# 6 the chain
rep('''if(v&&v.sym===FOC){ FLV=v; tkFeed(v); paint();''', '''if(v&&v.sym===FOC){ FLV=v; tkFeed(v); chainKick(v); paint();''', "the chain: every live price")
# 5 the OI marks remember their reading
rep('''mk.push({time:tm,position:r.side==="PE"?"aboveBar":"belowBar",color:r.side==="CE"?up:r.side==="PE"?dn:"#7d8b9c",shape:"circle",text:"OI"}); });''',
    '''mk.push({time:tm,position:r.side==="PE"?"aboveBar":"belowBar",color:r.side==="CE"?up:r.side==="PE"?dn:"#7d8b9c",shape:"circle",text:"OI"}); (PC.oimk[tm]=PC.oimk[tm]||[]).push(r); });''',
    "the OI marks remember their reading")
rep('''    ((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).forEach(r=>{ const tm=at(r.t); if(tm==null) return; mk.push''',
    '''    PC.oimk={}; ((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).forEach(r=>{ const tm=at(r.t); if(tm==null) return; mk.push''', "the OI marks: a fresh list each drawing")
# 6 the push strip's time
rep('''PP=m; }).catch''', '''PP=m; PPT=j.t||""; }).catch''', "who-is-pushing: its time")
rep('''<b>${P.dir==="DOWN"?"WHO IS PULLING IT DOWN":"WHO IS PUSHING IT UP"}</b>''', '''<b>${P.dir==="DOWN"?"WHO IS PULLING IT DOWN":"WHO IS PUSHING IT UP"}</b>${PPT?` <span class="dim">· ${esc(PPT)}</span>`:""}''', "who-is-pushing (full): its time")
# the helpers
rep('''function proRender(){''', '''/* patch 238: the share window - RSI daily, the OI marks explained, one chain of refreshes */
let PPT="", DRSI={sym:"",t:0,v:null}, CHN={sym:"",px:0,t:0,side:0,at:0,why:""};
function proMainH(H,sh,tbh){ return Math.max(140,H-sh-tbh); }
function rsiLast(a,n=14){ if(!a||a.length<n+1) return null; let g=0,l=0; for(let i=1;i<=n;i++){ const d=a[i]-a[i-1]; g+=Math.max(d,0); l+=Math.max(-d,0); } g/=n; l/=n;
  for(let i=n+1;i<a.length;i++){ const d=a[i]-a[i-1]; g=(g*(n-1)+Math.max(d,0))/n; l=(l*(n-1)+Math.max(-d,0))/n; } return l===0?100:100-100/(1+g/l); }
function dailyCloses(d){ if(!d||!d.t) return []; const m=new Map(); for(let i=0;i<d.t.length;i++){ if(d.c[i]==null) continue; m.set(new Date((d.t[i]+19800)*1000).toISOString().slice(0,10),d.c[i]); } return [...m.values()]; }
async function pullDRSI(){ if(!FOC||(DRSI.sym===FOC&&Date.now()-DRSI.t<600000)) return; DRSI={sym:FOC,t:Date.now(),v:DRSI.sym===FOC?DRSI.v:null};
  const v=await getJ("hist?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&days=60"); if(v&&v.s===FOC){ const c=dailyCloses(v); const px=FLV&&FLV.ok&&FLV.px; if(px&&c.length) c[c.length-1]=px; DRSI={sym:FOC,t:Date.now(),v:rsiLast(c),n:c.length}; } }
function rsiTag(){ if(!FOC) return ""; pullDRSI(); const d=PH.sym===FOC&&PH.d; const r5=d&&d.c?rsiLast(d.c.filter(x=>x!=null)):null; const rd=DRSI.sym===FOC?DRSI.v:null;
  if(r5==null&&rd==null) return ""; const w=x=>x==null?"–":Math.round(x); const z=rd==null?"":rd>=70?' <b class="pd">⚠ overbought</b>':rd<=30?' <b class="pu">⚠ oversold</b>':"";
  return ` <span class="rsit" title="RSI 14 on the 5-minute chart (today's moves) and on the daily chart (the last 14 days - Kite's daily RSI). 70+ = overbought, 30- = oversold">RSI 5m ${w(r5)} · daily ${w(rd)}${z}</span>`; }
function chainTag(){ return CHN.sym===FOC&&CHN.at&&Date.now()-CHN.at<90000?` <span class="dim" title="the price ${esc(CHN.why)} - the checklist, the option chain, the chart and who-is-pushing were all fetched again at once">🔗 all refreshed ${new Date(CHN.at+19800000).toISOString().slice(11,19)}</span>`:""; }
function chainKick(v){ const px=v&&v.px; if(!px||!FOC) return; const vw=FCH&&FCH.vw; const side=vw?Math.sign(px-vw):0; const now=Date.now();
  if(CHN.sym!==FOC){ CHN={sym:FOC,px,t:now,side,at:0,why:""}; return; }
  const moved=Math.abs(px/CHN.px-1)*100>=0.3, crossed=!!(side&&CHN.side&&side!==CHN.side);
  if((moved||crossed)&&now-CHN.t>=5000){ CHN={sym:FOC,px,t:now,side,at:now,why:moved?"moved 0.3%+":"crossed VWAP"}; try{ pullChk(); pullOI(); ppLoad(); pullChart(); }catch(e){} }
  else if(side) CHN.side=side; }
function oiExplain(t){ if(!PC||!PC.B||!PC.B.length||!PC.oimk) return ""; const B=PC.B; let i=B.length-1; if(t!=null){ const k=B.findIndex(b=>T_(b.t)===t); if(k>=0) i=k; }
  const rs=PC.oimk[T_(B[i].t)]; if(!rs||!rs.length) return "";
  return rs.map(r=>`<div class="oix">${r.side==="CE"?"🟢":r.side==="PE"?"🔴":"⚪"} OI ${esc(r.t)} · <b>${esc(r.name)}</b> ${r.side==="CE"?"(UP → CE)":r.side==="PE"?"(DOWN → PE)":""}${r.word?" · "+esc(r.word):""} <span class="dim">- where the option money stood at that candle, not a forecast; if the price breaks through, those writers often have to buy back and the move speeds up</span></div>`).join(""); }
function proRender(){''', "the helpers", marker="/* patch 238: the share window")
# 5 the legend shows the OI reading under the mouse
rep('''  main.subscribeCrosshairMove(p=>proLegend(p&&p.time));''', '''  main.subscribeCrosshairMove(p=>{ proLegend(p&&p.time); try{ const x=oiExplain(p&&p.time); if(x) PC.lg.insertAdjacentHTML("beforeend",x); }catch(e){} });   /* patch 238 */''', "the legend: the OI reading under the mouse")
# 4 the name and the price fixed at the top · the look
rep('''/* patch 211: alert rows that are links look the same */''', '''/* patch 238: the share's name and price stay on top when its window scrolls */
#focus .hd{position:sticky;top:0;z-index:35;background:var(--panel);box-shadow:0 2px 6px #000a}
#focus .hd .rsit{font:600 11px var(--ui);color:var(--txt);white-space:nowrap}
#focus .plg .oix{margin-top:3px;max-width:640px;padding:3px 6px;background:#0b0d11ee;border-left:3px solid var(--amber);font:500 11px/1.4 var(--ui);white-space:normal}
/* patch 211: alert rows that are links look the same */''', "the look", marker="/* patch 238: the share's name and price stay on top")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 238 in")
PY_PATCH
python3 $W/p238_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 238 done - reload every GIR tab (Ctrl + Shift + R; the phone: reload)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
