#!/bin/bash
# PATCH 332 - ⚡ F&O: THE CHART SET FOR F&O TRADING IN ONE TAP (Rama, 15 Nov: "what is the correct chart settings for F&O trading - make the F&O button").
#   First in a share's chart toolbar (phone, iPad, laptop): 5m candles · VWAP · EMA 9 · EMA 21 · volume · levels (the chain's walls + yesterday's
#   high / low / close) · GIR's marks · RSI below; SMA 50, Bollinger, Heikin-Ashi, MACD off. It turns green (✓ F&O) when the chart is set so,
#   and is remembered. A note says: check 15m for the trend, enter on 5m, no entry before 9:30 or after 2:30.
#   Edits home.html only. Tested at 4 sizes. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 332" $D/home.html; then echo "patch 332 - already in"; exit 0; fi
grep -q "patch 331" $D/home.html || { echo "patch 331 first"; exit 1; }
grep -q "function proToolbar()" $D/home.html || { echo "home.html: the chart toolbar not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/add.html <<'ADD_332'
<style>/* patch 332: ⚡ F&O - one tap sets the chart for F&O trading */
.ptb a.gxfo{font-weight:800 !important;letter-spacing:.04em;background:#3a2c10 !important;color:#ffc35c !important;border-color:#8a6418 !important;display:inline-flex !important}
.ptb a.gxfo.on{background:#0d3324 !important;color:#4fd69c !important;border-color:#1d5c42 !important}
#gxfotip{position:fixed;left:50%;transform:translateX(-50%);bottom:max(70px,calc(env(safe-area-inset-bottom,0px) + 70px));z-index:9996;max-width:min(92vw,560px);padding:10px 14px;border-radius:8px;background:#0d3324;border:1px solid #1d5c42;color:#e6edf3;font:600 12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.5);display:none;text-align:center}
#gxfotip b{color:#4fd69c}
</style>
<script>/* patch 332: ⚡ F&O - the chart set for F&O trading in one tap: 5m candles · VWAP · EMA 9 · EMA 21 · volume · levels (the chain's walls +
   yesterday's high / low / close) · GIR's marks · RSI below; SMA 50, Bollinger, Heikin-Ashi, MACD off. Green ✓ F&O when the chart is set so. */
(function(){
  const WANT={tf:"5",type:"candle",study:"rsi",ind:{vwap:1,ema9:1,ema21:1,sma50:0,bb:0,vol:1,lv:1,mk:1}};
  function isSet(){ try{ if(PRO.tf!==WANT.tf||PRO.type!==WANT.type||PRO.study!==WANT.study) return false; for(const k in WANT.ind) if(!!PRO.ind[k]!==!!WANT.ind[k]) return false; return true; }catch(e){ return false; } }
  let tipT=0;
  function tip(){ let t=document.getElementById("gxfotip"); if(!t){ t=document.createElement("div"); t.id="gxfotip"; document.body.appendChild(t); }
    t.innerHTML="<b>⚡ F&amp;O chart set:</b> 5m candles · VWAP · EMA 9 / 21 · VOL · LEVELS · RSI<br>check 15m for the trend, enter on 5m · no entry before 9:30 or after 2:30";
    t.style.display="block"; clearTimeout(tipT); tipT=setTimeout(()=>{ t.style.display="none"; },4500); }
  window.gxFo=function(){ try{ PRO.tf=WANT.tf; PRO.type=WANT.type; PRO.study=WANT.study; PRO.ind=Object.assign({},PRO.ind,WANT.ind); PRO.tool="";
      proSave(); if(typeof PC!=="undefined"&&PC) PC.key=""; paint(); tip(); }catch(e){} };
  if(typeof proToolbar==="function"){ const O=proToolbar; proToolbar=function(){ let h=O.apply(this,arguments);
      const on=isSet(), btn=`<a class="gxfo ${on?"on":""}" onclick="gxFo()" title="the chart for F&amp;O: 5m candles, VWAP, EMA 9/21, volume, levels, RSI">${on?"✓ F&amp;O":"⚡ F&amp;O"}</a>`;
      return h.replace('<div class="ptb"><span>','<div class="ptb"><span>'+btn); };
    try{ if(typeof PC!=="undefined"&&PC) PC.key=""; paint(); }catch(e){} }
})();
</script>
ADD_332
python3 - $D/home.html $W/add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: the ⚡ F&O button")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "✅ patch 332 done - open a share, tap ⚡ F&O (first button on the chart). Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
