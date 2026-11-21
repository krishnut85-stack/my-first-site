#!/bin/bash
# PATCH 325 - ONE RULE EVERYWHERE: A FUTURES OI MOVE OF 40%+ IN ONE DAY IS NOT MONEY (Rama, 15 Nov, the IDEA page: "this page is very important for
#   trading - all the information needs to be updated correctly"). F&O MONEY already left IDEA out (futures OI -71.2% in a day: a contract /
#   lot change - patch 252), but the share page still said "FORCED OUT · long unwinding ₹5,371 cr", "Traders who had bet on a rise are GIVING UP
#   (₹5,371 cr)", the checklist "long unwinding ₹5,367 cr" -> "DECISION: BUY PE 6/7 and the futures agree". Now on the share page, for any share
#   whose futures OI moved 40%+ in a day: the FUTURES check counts 0 ("a contract / lot change, not counted"), the FUTURES pusher is off, no
#   "forced out / new money" claim, the checklist score / verdict / DECISION worked out again without it (IDEA: NO TRADE - 4/7 CE, 5/7 PE).
#   A normal share (TECHM, OI change small) is unchanged. Laptop and phone. Edits home.html only (display - the server unchanged). Refresh.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 325" $D/home.html; then echo "patch 325 - already in"; exit 0; fi
grep -q "function ckDecision(c)" $D/home.html && grep -q "patch 324" $D/home.html || { echo "patch 324 first (or the share checklist not found) - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/home325.html <<'ADD_H'
<script>/* patch 325: ONE RULE EVERYWHERE - a futures OI move of 40%+ in one day is a contract / lot change, not money (F&O MONEY already left
   such a share out - patch 252). The share page now does the same: the FUTURES check counts 0, the FUTURES pusher is off, "forced out / new
   money" is not claimed, and the checklist score, verdict and DECISION are worked out again without it. Display only - the server unchanged. */
(function(){ const LIM=40;
  function foiOf(sym, j){ let v=null;
    try{ const r=((typeof D!=="undefined"&&D&&D.tape)||[]).find(x=>x.s===sym); if(r&&r.foi!=null) v=+r.foi; }catch(e){}
    try{ if(v==null&&j&&j.push&&j.push.rows){ const f=j.push.rows.find(x=>x.k==="FUTURES"); const m=f&&String(f.t||"").match(/futures OI ([+-−]?\d+(?:\.\d+)?)%/); if(m) v=+m[1].replace("−","-"); } }catch(e){}
    try{ if(v==null&&j&&j.push&&/futures OI ([+-−]?\d+(?:\.\d+)?)%/.test(j.push.kline||"")) v=+RegExp.$1.replace("−","-"); }catch(e){}
    return v; }
  const note=v=>`futures OI ${v>0?"+":""}${v}% in one day - a contract / lot change, not counted`;
  function fixSide(x, v){ if(!x||!x.items) return; const it=x.items.find(t=>t[0]==="FUTURES"); if(!it) return; it[1]=0; it[2]=note(v);
    x.score=x.items.filter(t=>t[1]>0).length; x.fails=x.items.filter(t=>t[1]<0).length;
    x.verdict=x.fails>=1?"FAIL":x.score>=6?"PASS":"MIXED"; }
  function fixPush(P, v){ if(!P||!P.rows) return; const f=P.rows.find(x=>x.k==="FUTURES"); if(f){ f.on=false; f.side=0; f.t=""; }
    if(["FORCED OUT","NEW MONEY","BOTH"].includes(P.kind)){ P.kind=""; P.advice=""; } P.kline=note(v); P.new=[]; P.forced=[];
    P.n_on=P.rows.filter(x=>x.on).length; }
  function fixChk(j){ try{ if(!j||!j.s) return j; const v=foiOf(j.s,j); if(v==null||Math.abs(v)<LIM) return j;
      fixSide(j.CE,v); fixSide(j.PE,v); fixPush(j.push,v); j.oi_note=note(v); }catch(e){} return j; }
  function fixPP(j){ try{ (j.rows||[]).forEach(r=>{ const v=foiOf(r.s,null); if(v==null||Math.abs(v)<LIM) return;
      ["up","dn"].forEach(k=>{ if(Array.isArray(r[k])) r[k]=r[k].filter(x=>!/^FUTURES/.test(String(x))); }); if(/forced|new money|unwinding|build-up|covering/i.test(r.kline||"")) r.kline=note(v); if(["FORCED OUT","NEW MONEY","BOTH"].includes(r.kind)) r.kind=""; }); }catch(e){} return j; }
  const F0=window.fetch.bind(window);
  window.fetch=function(u,o){ const url=String(u&&u.url||u||""); const p=F0(u,o);
    const kind=/(^|\/)chk\?/.test(url)?"chk":/(^|\/)pushpull\?/.test(url)?"pp":null; if(!kind) return p;
    return p.then(r=>{ if(!r.ok) return r; return r.clone().json().then(j=>{ const x=kind==="chk"?fixChk(j):fixPP(j);
      return new Response(JSON.stringify(x),{status:r.status,statusText:r.statusText,headers:{"Content-Type":"application/json"}}); }).catch(()=>r); }); };
  /* the reading already on screen (loaded before this rule): correct it once, then repaint */
  setInterval(()=>{ try{ if(typeof FCK!=="undefined"&&FCK&&FCK.s&&!FCK.__g){ FCK.__g=1; const v=foiOf(FCK.s,FCK); if(v!=null&&Math.abs(v)>=LIM){ fixChk(FCK); if(typeof paint==="function") paint(); } } }catch(e){} },500);
})();
</script>
ADD_H
python3 - $D/home.html $W/home325.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 325")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 325 done - a share whose futures OI moved 40%+ in a day: the futures are not counted on its page (IDEA: NO TRADE). Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
