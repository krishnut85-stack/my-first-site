#!/bin/bash
# PATCH 252 - four fixes from 13 Nov: 🏦 MACRO needs real rate words ("RBI ... may ease scrutiny on stakes" was RATE-CUT HOPES) · F&O MONEY leaves
#   out a share whose futures OI moved 40%+ in a day and names it (IDEA LONG UNWINDING ₹5,370 cr, OI -71%) · the daily RSI adds today instead of
#   replacing yesterday, 120 days of history (PHOENIXLTD 74 vs Kite 69.76) · the F&O TAPE says what its colours, blocks and ✓ mean.
#   Tested: 22 headlines + the 13 Nov macro replay; in a browser old vs new. No restart (the macro check runs fresh every 2 min) - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $D/macrowarn.py ] || { echo "patch 247 first"; exit 1; }
F="macrowarn.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p252_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p252_patch.py - PATCH 252: four fixes from 13 Nov.
  macrowarn   🏦 MACRO needs real rate words (repo / interest rate / rate cut / MPC ...), not the bare "RBI" - "RBI plans rules ... may ease
              scrutiny on stakes" was read as RATE-CUT HOPES · "Rate hike in December likely" and "Reserve Bank cuts repo" are now read
  F&O MONEY   a share whose futures OI moved 40%+ in a day is left out of the four boxes and named on one line ("not believable for one day")
              - IDEA showed LONG UNWINDING ₹5,370 cr, OI -71%
  daily RSI   today's price is ADDED as today's close (it replaced yesterday's close when the history ended yesterday) · 120 days of history
              (was 60 - RSI keeps a long memory; PHOENIXLTD showed 74 where Kite showed 69.76) · refreshed every 2 min
  F&O TAPE    one line saying what the colours, the blocks and ✓ mean
Usage: python3 p252_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        ERR.append("%s not found" % f); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("macrowarn.py", '''RB = r"\\b(rbi|reserve bank|repo|mpc|monetary policy|interest rates?|rate hikes?|rate cuts?|policy rates?)\\b"''',
    '''RB = r"\\b(repo|mpc|monetary policy|interest rates?|rate hikes?|rate cuts?|policy rates?|lending rates? cut)\\b"   # patch 252: rate words, not the bare "RBI" ("RBI ... may ease scrutiny on stakes" is not a rate cut)''',
    "MACRO: rate words, not the bare RBI")
rep("macrowarn.py", '''    ("RATE_UP", "RATE-HIKE FEARS", [RB + r".*\\b(hikes?|hiking|raise[sd]?|tighten\\w*|hawkish|higher)\\b|\\b(hikes?|raise[sd]?)\\b.*" + RB,''',
    '''    ("RATE_UP", "RATE-HIKE FEARS", [RB + r".*\\b(hikes?|hiking|raise[sd]?|tighten\\w*|hawkish|higher)\\b|\\b(hikes?|raise[sd]?)\\b.*" + RB + r"|\\brate hikes?\\b",''',
    "MACRO: 'rate hike in December likely'")
rep("macrowarn.py", '''    ("RATE_DOWN", "RATE-CUT HOPES", [RB + r".*\\b(cuts?|cutting|lower\\w*|eas\\w+|dovish|reduce[sd]?)\\b|\\b(rate cuts?)\\b"],''',
    '''    ("RATE_DOWN", "RATE-CUT HOPES", [RB + r".*\\b(cuts?|cutting|lower\\w*|eas\\w+|dovish|reduce[sd]?)\\b|\\b(rate cuts?)\\b|\\b(cuts?|lowers?|slash\\w*|reduces?)\\b.*" + RB],''',
    "MACRO: 'Reserve Bank cuts repo'")
rep("home.html", '''  const v=await getJ("hist?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&days=60"); if(v&&v.s===FOC){ const c=dailyCloses(v); const px=FLV&&FLV.ok&&FLV.px; if(px&&c.length) c[c.length-1]=px; DRSI={sym:FOC,t:Date.now(),v:rsiLast(c),n:c.length}; } }''',
    '''  const v=await getJ("hist?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&days=120"); if(v&&v.s===FOC&&v.t){   /* patch 252: today ADDED (not over yesterday) · 120 days */
    const m=new Map(); for(let i=0;i<v.t.length;i++){ if(v.c[i]==null) continue; m.set(new Date((v.t[i]+19800)*1000).toISOString().slice(0,10),v.c[i]); }
    const ist=new Date(Date.now()+19800000), today=ist.toISOString().slice(0,10), hm=ist.toISOString().slice(11,16), wd=ist.getUTCDay();
    const px=(FLV&&FLV.ok&&FLV.px)||(LQ&&LQ[FOC]&&LQ[FOC][0]);
    if(px&&(m.has(today)||(wd>0&&wd<6&&hm>="09:15"))) m.set(today,px);
    const c=[...m.values()]; DRSI={sym:FOC,t:Date.now()-480000,v:rsiLast(c),n:c.length}; } }''', "daily RSI: today added, 120 days, every 2 min")
rep("home.html", '''  const box=(b,k,bias)=>{ const xs=msort(mo[b]||[]).slice(0,''', '''  const box=(b,k,bias)=>{ const xs=msort((mo[b]||[]).filter(x=>Math.abs(x.oi||0)<40)).slice(0,''', "F&O MONEY: OI 40%+ in a day left out")
rep("home.html", '''  return `${msortBar()}<div class="qd">''', '''  const odd_=Object.values(mo).flat().filter(x=>x&&Math.abs(x.oi||0)>=40);   /* patch 252 */
  return `${msortBar()}${odd_.length?`<div class="dim" style="padding:2px 6px;font-size:11px">left out - futures OI moved 40%+ in one day, not believable as new money (a contract or lot change): ${odd_.map(x=>esc(x.s)+" OI "+(x.oi>0?"+":"")+x.oi+"%").join(" · ")}</div>`:""}<div class="qd">''', "F&O MONEY: the left-out shares named")
rep("home.html", '''shares · ${D&&D.desk_t?`desk ${D.desk_t} (${D.desk_src||""})`:`desk: no reading yet`}`; }''',
    '''shares · ${D&&D.desk_t?`desk ${D.desk_t} (${D.desk_src||""})`:`desk: no reading yet`} · PRICE flash = the last tick (green up, red down - not a signal) · DESK blocks = the desk's call −2…+2 (left red = bearish, right green = bullish) · ✓ = confirmed by the 5-min candle · tap a share = its screen`; }   /* patch 252: the legend */''',
    "F&O TAPE: the legend")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 252 in")
PY_PATCH
cat > $W/p252test.py <<'PY_TEST'
import sys; sys.path.insert(0, sys.argv[1] if len(sys.argv) > 1 else ".")
import macrowarn as M
C=[("RBI May Hike Interest Rates Amid Rising Food Inflation Risks in FY27","RATE-HIKE FEARS",False),("Uneven monsoons, El Nino pose upside risks to inflation","RATE-HIKE FEARS",False),
 ("RBI hikes repo rate by 25 bps to 6.75%","RATE-HIKE FEARS",True),("RBI keeps repo rate unchanged",None,False),("Crude oil prices surge 4% as OPEC+ cuts output","CRUDE OIL RISING",False),
 ("Rupee falls to record low of 88.9 against dollar","RUPEE WEAK",False),("Oil India Q2 profit jumps 53%",None,False),("Fed cuts rates by 25 bps, signals more easing","US FED DOVISH",True),
 ("Trump announces 50% tariffs on Indian goods","US TARIFFS ON INDIA",False),("Nifty ends lower as banks drag",None,False),("RBI governor says rate cut possible in December","RATE-CUT HOPES",False),
 ("India's GDP growth rate higher at 7.8% in Q2",None,False),("HDFC Bank raises lending rates by 10 bps",None,False),("Retail inflation rises to 6.2% in October","RATE-HIKE FEARS",False),
 ("Brent crude falls 3% on demand worries","CRUDE OIL FALLING",False),("Infosys shares rise 2% on deal win",None,False),
 ("RBI Plans New Rules To Restrict Private Equity Control In Multiple NBFCs, May Ease Scrutiny On Stakes Up To",None,False),
 ("RBI raises penalty on three co-operative banks",None,False),("RBI may raise repo rate to 6% by February as inflation breaches upper band","RATE-HIKE FEARS",False),
 ("RBI Rate Hike In December Likely As Inflation Crosses 6%, ICICI Bank Warns Food Prices May Stay Elevated","RATE-HIKE FEARS",False),
 ("MPC cuts repo rate by 25 bps","RATE-CUT HOPES",True),("Reserve Bank cuts repo rate by 50 bps in surprise move","RATE-CUT HOPES",True)]
ok=0
for h,want,dec in C:
    r=M.theme_of(h); got=r[1] if r else None; gd=r[5] if r else False; g=(got==want and gd==dec); ok+=g
    if not g: print("  ❌ %-70s -> %s%s" % (h[:70], got, " DECIDED" if gd else ""))
print("MACRO HEADLINES test: %d of %d passed" % (ok,len(C)))
sys.exit(0 if ok==len(C) else 1)
PY_TEST
python3 $W/p252_patch.py $D || back
cd $D && python3 -m py_compile macrowarn.py || back
echo "=== test: 22 headlines"
python3 $W/p252test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== 🏦 MACRO on this server's news now (nothing sent):"
cd $D && timeout 60 python3 macrowarn.py 2>&1 | head -12
echo "✅ patch 252 done - reload GIR (Ctrl + Shift + R on the laptop, pull down on the phone)."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done"
