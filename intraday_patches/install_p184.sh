#!/bin/bash
# PATCH 184 - the laptop's tabs, as Rama asked (10 Nov):
#   MARKET = F&O MOVERS · SECTORS · ROTATION · TRADE NOW · OI SCENARIOS (+ EARLY, the desk strip)
#   2 F&O MONEY (new, full screen, with BIG MONEY) · 4 OPTIONS (new: NIFTY · BANKNIFTY options, full screen) · G 📘 GUIDE (new)
#   THE THREE and SECTORS (old tab 4) gone from the row · TOMORROW shows everything filed since the last close (the brief, live)
#   DESK P&L labelled: GIR's own practice trades, automatic, on paper. gir-dash restarts (502 for 1-3 minutes) - outside market hours.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35"; exit 1; fi
[ -f $D/morningbrief.py ] || { echo "install_p169 first (the brief)"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $W/p184_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p184_patch.py - PATCH 184 (laptop tabs, Rama 10 Nov):
  MARKET keeps F&O MOVERS · SECTORS · ROTATION · TRADE NOW · OI SCENARIOS (+ EARLY, the desk strip)
  F&O MONEY (new tab, key 2): F&O MONEY + BIG MONEY, full screen · OPTIONS (new tab, key 4): NIFTY · BANKNIFTY options, full screen
  📘 GUIDE (new tab, key G): futures, options, OI, build-ups, support / resistance, when a share is bullish / bearish
  THE THREE and SECTORS (tab 4) gone from the tab row · TOMORROW shows what came after the list was made (the morning brief, live)
  DESK P&L says what it is: GIR's own practice trades - automatic, paper, no real money
Usage: python3 p184_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"

CSS = """
/* patch 184: MARKET / F&O MONEY / OPTIONS / GUIDE (laptop) */
@media(min-width:1100px){
  body.topchart.fkin:not(.mk-money):not(.mk-opts) #mk #q-mon,body.topchart.fkin:not(.mk-money):not(.mk-opts) #mk #q-ins,body.topchart.fkin:not(.mk-money):not(.mk-opts) #mk #q-idx{display:none !important}
  body.topchart.fkin:not(.mk-money):not(.mk-opts) #mk{grid-template-rows:auto auto auto minmax(0,1.25fr) minmax(0,1fr) !important;
    grid-template-areas:"mov fk fk act" "mov ear ear act" "mov dsk dsk act" "mov don don act" "mov rot rot nws" !important}
  body.topchart.mk-money #mk>.q,body.topchart.mk-opts #mk>.q{display:none !important}
  body.topchart.mk-money #mk>#q-mon,body.topchart.mk-money #mk>#q-ins,body.topchart.mk-opts #mk>#q-idx{display:flex !important;flex-direction:column}
  body.topchart.mk-money #mk,body.topchart.mk-opts #mk{height:auto !important;grid-template-columns:minmax(0,1fr) !important;grid-template-rows:auto auto auto !important}
  body.topchart.mk-money #mk{grid-template-areas:"fk" "mon" "ins" !important}body.topchart.mk-opts #mk{grid-template-areas:"fk" "idx" !important}
  body.topchart.mk-money #q-mon{min-height:62vh}body.topchart.mk-money #q-ins{min-height:40vh}body.topchart.mk-opts #q-idx{min-height:72vh}
  body.topchart.mk-money #mk .q>.bd,body.topchart.mk-opts #mk .q>.bd{max-height:none;flex:1}
}
#fkeys a[data-v="three"],#fkeys a[data-v="secs"]{display:none !important}
#learn .gd{padding:10px 16px 30px;max-width:1100px;font:14px/1.6 var(--ui,system-ui);color:var(--txt)}
#learn .gd h3{color:var(--amber);font:700 15px/1.3 var(--ui,system-ui);letter-spacing:.06em;margin:22px 0 6px;text-transform:uppercase}
#learn .gd table{border-collapse:collapse;margin:6px 0 10px;width:100%;max-width:900px}#learn .gd td,#learn .gd th{border:1px solid var(--line);padding:6px 9px;text-align:left;vertical-align:top}
#learn .gd th{color:var(--dim);font-weight:600}#learn .gd .u{color:var(--up)}#learn .gd .d{color:var(--dn)}#learn .gd b{color:var(--hi)}
#learn .gd .bx{border:1px solid var(--line);border-radius:7px;padding:8px 12px;background:var(--panel);margin:8px 0}
#tmb{white-space:pre-wrap;font:12.5px/1.5 var(--mono,monospace);border:1px solid var(--line);border-radius:7px;padding:8px 12px;margin:6px 8px 10px;background:var(--panel)}
</style>"""

GUIDE = r"""<section class="p" id="learn"><h2>📘 GUIDE <small>futures · options · OI · build-up · support / resistance · bullish or bearish</small></h2><div class="gd">
<h3>1 · Futures and options - the link</h3>
<p><b>Future</b>: an agreement to buy (or sell) the share at a price on the expiry day. It moves almost rupee for rupee with the share.
<b>Option</b>: the right, not the duty. <b class="u">CE</b> (call) gains when the share goes <b>up</b>; <b class="d">PE</b> (put) gains when it goes <b>down</b>.
Every option has a <b>buyer</b> (pays the premium, risk = the premium) and a <b>writer / seller</b> (collects the premium, big risk if the share moves against him).
Big money mostly <b>writes</b> options - so where it writes tells you where it thinks the share will NOT go.</p>
<h3>2 · Open interest (OI)</h3>
<p>The number of contracts still open. It <b>rises</b> when new positions are opened and <b>falls</b> when old ones are closed. Price shows the direction; OI shows whether <b>new money</b> came in or <b>old money</b> left.</p>
<h3>3 · OI build-up - which way the new money goes (futures)</h3>
<table><tr><th>price</th><th>futures OI</th><th>name</th><th>meaning</th></tr>
<tr><td class="u">▲ up</td><td>▲ up</td><td class="u"><b>LONG BUILD-UP</b></td><td>new buyers - <b class="u">strong bullish</b></td></tr>
<tr><td class="d">▼ down</td><td>▲ up</td><td class="d"><b>SHORT BUILD-UP</b></td><td>new sellers - <b class="d">strong bearish</b></td></tr>
<tr><td class="u">▲ up</td><td>▼ down</td><td><b>SHORT COVERING</b></td><td>old sellers leaving - bullish but weaker (no new buyers)</td></tr>
<tr><td class="d">▼ down</td><td>▼ down</td><td><b>LONG UNWINDING</b></td><td>old buyers leaving - bearish but weaker</td></tr></table>
<p>On GIR: <b>F&amp;O MONEY</b> tab (₹ crore of fresh futures money per share), the F&amp;O MOVERS buttons LB · SB · SC · LU.</p>
<h3>4 · Support and resistance - where the price may stop (option chain)</h3>
<p><b>CEILING (CE)</b> = the strike above the price with the most <b>CE OI</b>: call writers lose above it, so they sell there - a lid.
<b>FLOOR (PE)</b> = the strike below with the most <b>PE OI</b>: put writers defend it - a floor. They are levels, not walls: big money or news breaks them.
<b>PCR</b> (puts ÷ calls OI): above 1 = more put writing = support below (bullish lean); under 0.7 = call writing heavy (bearish lean).
Chart levels (yesterday's high / low, PREV) are a second kind of support / resistance - from price history, not OI.</p>
<h3>5 · Build-up vs support / resistance</h3>
<div class="bx"><b>Support / resistance = WHERE</b> (a price level, from option OI at strikes).<br><b>OI build-up = WHICH WAY</b> (the direction of new money, from futures OI change).</div>
<h3>6 · A share is BULLISH (CE side) when most of these agree</h3>
<table><tr><td class="u">✓</td><td>price above yesterday's close <b>and</b> above VWAP, holding above the first 15-minute high</td></tr>
<tr><td class="u">✓</td><td><b>long build-up</b> (price ▲ + futures OI ▲), ₹ crore of fresh money rising</td></tr>
<tr><td class="u">✓</td><td>at the FLOOR: <b>PE OI rising</b> (put writers defending) · at the CEILING: <b>CE OI falling</b> (call writers running = breakout)</td></tr>
<tr><td class="u">✓</td><td>PCR rising · volume 1.5-2x normal · its sector up · NIFTY not falling</td></tr>
<tr><td class="u">✓</td><td>news: results BEAT, a big order, a regulator approval (ORDER news kept running next day 64% of the time - GIR's 3-year study)</td></tr></table>
<h3>7 · A share is BEARISH (PE side) when most of these agree</h3>
<table><tr><td class="d">✓</td><td>price below yesterday's close <b>and</b> below VWAP, breaking the first 15-minute low</td></tr>
<tr><td class="d">✓</td><td><b>short build-up</b> (price ▼ + futures OI ▲)</td></tr>
<tr><td class="d">✓</td><td>at the CEILING: <b>CE OI rising</b> (call writers adding) · the FLOOR breaks with <b>PE OI falling</b> (put writers running)</td></tr>
<tr><td class="d">✓</td><td>PCR falling under 0.7 · heavy volume · sector down</td></tr>
<tr><td class="d">✓</td><td>news: results MISS, regulator action, fraud / auditor quits, a boss leaving</td></tr></table>
<h3>8 · Traps - what GIR's studies found (3 years)</h3>
<table><tr><td>chart patterns alone (breakouts, VWAP bounce, 52-week high, 17 tested)</td><td>no edge after costs</td></tr>
<tr><td>chasing the first move after a Budget / RBI / GST / bill</td><td>lost -0.25% a trade - the first move often reverses by the close</td></tr>
<tr><td>the day after a results shock</td><td>a coin flip (52%) - trade the opening only if 09:20 confirms</td></tr>
<tr><td>a whole-market crash day</td><td>the shocked shares bounced +3.5% next day, +9.6% in 5 days</td></tr>
<tr><td><b>what works</b>: a gap confirmed by the first 5 minutes</td><td class="u">+0.53% a trade - the 🌅 09:20 OPENING CALL</td></tr>
<tr><td>short covering / long unwinding</td><td>weaker than build-ups - smaller size</td></tr>
<tr><td>expiry week</td><td>premiums melt fast - small size, out by 15:00</td></tr></table>
<h3>9 · Size</h3><p>Risk at most 1-2% of your capital on one trade (₹2.5 lakh → ₹2,500-5,000 loss at your stop → usually 1 lot). Limit orders, not market orders, in stock options.</p>
</div></section>"""

JS = r"""
/* patch 184: the tab row - F&O MONEY and OPTIONS as their own tabs, GUIDE, no THE THREE / SECTORS; TOMORROW shows the brief */
let MKSUB=""; let SUBGO=false;
function subApply(){ const b=document.body; b.classList.toggle("mk-money",VIEW==="market"&&MKSUB==="money"); b.classList.toggle("mk-opts",VIEW==="market"&&MKSUB==="opts");
  document.querySelectorAll("#fkeys a").forEach(a=>{ const v=a.dataset.v; a.classList.toggle("on", MKSUB?(v==="mk-"+MKSUB):(v===VIEW)); });
  if(VIEW==="market"){ setTimeout(()=>{ try{ if(typeof mkFit==="function") mkFit(); drawMarket.force=true; drawMarket(); drawMarket.force=false; if(typeof ixDraw==="function") ixDraw(); }catch(e){} },30); } }
function mkSub(s){ SUBGO=true; MKSUB=s; setView("market"); SUBGO=false; subApply(); window.scrollTo(0,0); }
{ const sv5_=setView; setView=function(v){ if(!SUBGO) MKSUB=""; sv5_(v); subApply(); if(v==="tom") tomBrief(); }; }
async function tomBrief(){ try{ const r=await fetch("brief?k="+encodeURIComponent(K),{cache:"no-store"}); if(!r.ok) return; const t=await r.text();
  let el=$("tmb"); if(!el){ el=document.createElement("div"); el.id="tmb"; const tl=$("tml"); if(tl) tl.parentNode.insertBefore(el,tl); }
  el.textContent="AFTER THE LIST WAS MADE - everything filed / said on F&O shares since the last close (the 08:30 brief, live):\n\n"+t; }catch(e){} }
setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="tom") tomBrief(); },60000);
function tabsFix(){ const fk=$("fkeys"); if(!fk||fk.dataset.p184) return; fk.dataset.p184="1";
  const mk=(v,k,l,f,t)=>{ const a=document.createElement("a"); a.dataset.v=v; a.innerHTML=`<b>${k}</b>${l}`; a.title=t; a.onclick=f; return a; };
  const after=(v,el)=>{ const r=fk.querySelector(`a[data-v="${v}"]`); if(r) r.after(el); else fk.appendChild(el); };
  after("now",mk("mk-money","2","F&amp;O MONEY",()=>mkSub("money"),"fresh futures money + the big hands (key 2)"));
  after("scn",mk("mk-opts","4","OPTIONS",()=>mkSub("opts"),"NIFTY · BANKNIFTY options (key 4)"));
  fk.appendChild(mk("learn","G","📘 GUIDE",()=>setView("learn"),"futures · options · OI · build-up · support / resistance · bullish / bearish (key G)"));
  const dh=document.querySelector("#desk h2 small"); if(dh) dh.textContent="GIR's own PRACTICE trades - automatic, on paper, no real money; nobody types them in. Your own trades: 9 MY F&O"; }
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return;
  const m={"2":()=>mkSub("money"),"4":()=>mkSub("opts"),"g":()=>setView("learn"),"G":()=>setView("learn")}; if(m[e.key]){ e.stopImmediatePropagation(); e.preventDefault(); m[e.key](); } },true);
tabsFix(); window.addEventListener("load",tabsFix);
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
A_SEC = '  <section class="p pn xp" id="desk">'
R_OLD = '            if u.path == "/home":'
R_NEW = ('            if u.path == "/brief":                    # patch 184: the morning brief, live, for the TOMORROW tab\n'
         '                import morningbrief\n'
         '                return self.send(200, morningbrief.build()[0], "text/plain; charset=utf-8")\n' + R_OLD)
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
msg = []
if "patch 184" not in t:
    if "patch 179" not in t or t.count(A_JS) != 1 or t.count(A_SEC) != 1:
        print("patches 177-179 are not in home.html - install them first"); sys.exit(1)
    t = t.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1).replace(A_SEC, GUIDE + "\n" + A_SEC, 1)
    open(h, "w", encoding="utf-8").write(t); msg.append("home.html: the tabs")
if "patch 184" not in s:
    if s.count(R_OLD) != 1:
        print("ANCHOR x%d in dashserve.py" % s.count(R_OLD)); sys.exit(1)
    open(p, "w", encoding="utf-8").write(s.replace(R_OLD, R_NEW, 1)); msg.append("dashserve.py: /brief")
print(" · ".join(msg) or "patch 184 is already in")
PY_PATCH
back() { cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; }
R=$(python3 $W/p184_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile dashserve.py || { back; echo "does not compile - old files back"; exit 1; }
cd /home/globalbot && set -a && source .env; set +a; cd $D
python3 -c "import morningbrief; t,_=morningbrief.build(); print('the brief for TOMORROW reads:', t.split(chr(10))[0])" 2>&1 | tail -1
echo -n "the page server restarting (502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "✅ the page is back" || { echo "❌ the page did not come back - old files back"; back; systemctl restart gir-dash; exit 1; }
rm -rf $W
echo "PATCH 184 APPLIED - Ctrl + Shift + R on girtrader.com. Tabs: MARKET · RESULTS · 1 NOW · 2 F&O MONEY · 3 OI SCENARIOS · 4 OPTIONS · ... · G GUIDE"
