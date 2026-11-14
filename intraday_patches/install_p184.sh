#!/bin/bash
# PATCH 184 - the laptop's tabs, as Rama asked (10 Nov):
#   MARKET = F&O MOVERS · SECTORS · ROTATION · TRADE NOW · OI SCENARIOS (+ EARLY, the desk strip)
#   2 F&O MONEY (full screen, 25 a block) · B 🏦 BIG MONEY (new: futures build-up + big-hands delivery + FII/DII deals LINKED per share,
#   + the BIG MONEY panel) · 4 OPTIONS (NIFTY · BANKNIFTY options, full screen) · G 📘 GUIDE · THE THREE and SECTORS gone from the row
#   One build-up rule for every panel: OI 1%+ and price 0.25%+, else no label. TOMORROW shows everything filed since the close.
#   DESK P&L labelled (GIR's practice trades). gir-dash restarts (502 for 1-3 minutes) - outside market hours.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35"; exit 1; fi
[ -f $D/morningbrief.py ] || echo "note: the morning brief (install_p169.sh) is not installed - run it too, for 08:30 tomorrow"
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $D/moneylink.py <<'MONEYLINK_PY'
#!/usr/bin/env python3
"""moneylink.py - patch 184: ONE LINE PER F&O SHARE linking the three money readings (Rama: "link the F&O OI build-up and the big money
- it gives a fair idea which share will go up or down"):
  1. FUTURES   the build-up (long / short build-up, short covering, long unwinding) and ₹ crore of fresh futures money
  2. DELIVERY  shares actually taken home (NSE's delivery file) against the share's own 20-day normal - price up + 1.5x = big hands
               buying, price down + 1.5x = big hands selling
  3. NAMED     FII / DII bulk & block deals on the last day
  score: long build-up +2 · short covering +1 · short build-up -2 · long unwinding -1 · delivery buying +1 / selling -1 · named FII/DII
  buy +1 / sell -1  ->  ALL AGREE ▲ / ▼ when futures and delivery point the same way, MIXED when they disagree.
A reading of the last session, not a trade by itself: the 09:20 opening call and the live price decide."""
import os, sys, json

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
BU = {"LONG BUILD-UP": 2, "SHORT COVERING": 1, "SHORT BUILD-UP": -2, "LONG UNWINDING": -1}


def deliv_all(min_hist=5):
    """{sym: {"chg", "x", "dp", "avg_dp", "extra"}} the last delivery day, every F&O share, vs its own 20-day normal"""
    import instflow as I
    files = sorted(f for f in (os.listdir(I.DIR) if os.path.isdir(I.DIR) else []) if f.startswith("deliv_"))[-21:]
    D = []
    for f in files:
        try:
            D.append(json.load(open(os.path.join(I.DIR, f))))
        except Exception:
            pass
    if not D:
        return None, {}
    last, hist = D[-1], D[:-1]
    out = {}
    for s, (q, dq, dp, cl, pc) in (last.get("s") or {}).items():
        H = [x["s"][s] for x in hist if s in (x.get("s") or {})]
        if len(H) < min_hist or not (cl and pc and dq):
            continue
        a = sum(h[1] for h in H) / len(H)
        if a <= 0:
            continue
        out[s] = {"chg": round((cl / pc - 1) * 100, 2), "x": round(dq / a, 1), "dp": round(dp, 1), "avg_dp": round(sum(h[2] for h in H) / len(H), 1),
                  "extra": round((dq - a) * cl / 1e7, 1)}
    return last.get("day"), out


def link(fo_paths, deliv=None, named_w=None):
    day, DL = deliv if deliv is not None else deliv_all()
    W = named_w or {}
    named = {}
    for k in ("fii_buy", "fii_sell", "dii_buy", "dii_sell"):
        for x in W.get(k) or []:
            named.setdefault(x.get("s"), []).append({"k": k, "cr": x.get("cr"), "who": x.get("who")})
    rows = []
    for f in fo_paths or []:
        s = f.get("s")
        if not s:
            continue
        bu = f.get("bu") or ""
        fs = BU.get(bu, 0)
        d = DL.get(s) or {}
        ds = (1 if d.get("chg", 0) > 0 else -1) if d and d.get("x", 0) >= 1.5 and abs(d.get("chg", 0)) >= 0.3 else 0
        ns = sum(1 if "buy" in n["k"] else -1 for n in named.get(s, []))
        ns = max(-1, min(1, ns))
        sc = fs + ds + ns
        if fs and ds:
            word = ("ALL AGREE ▲" if fs > 0 else "ALL AGREE ▼") if (fs > 0) == (ds > 0) else "MIXED"
        elif fs:
            word = "FUTURES ▲" if fs > 0 else "FUTURES ▼"
        elif ds:
            word = "DELIVERY ▲" if ds > 0 else "DELIVERY ▼"
        else:
            word = "—"
        rows.append({"s": s, "chg": f.get("chg"), "bu": bu, "cr": f.get("cr"), "oi": f.get("oi"), "fs": fs,
                     "dx": d.get("x"), "dext": d.get("extra"), "dp": d.get("dp"), "ds": ds, "named": named.get(s, []), "ns": ns, "sc": sc, "word": word})
    rows.sort(key=lambda r: (-abs(r["sc"]), -abs(r.get("cr") or 0)))
    return {"deliv_day": day, "n": len(rows), "rows": rows[:120],
            "up": [r for r in rows if r["word"] == "ALL AGREE ▲"][:15], "dn": [r for r in rows if r["word"] == "ALL AGREE ▼"][:15]}
MONEYLINK_PY
cat > $D/p184test.py <<'P184TEST_PY'
#!/usr/bin/env python3
"""p184test.py - the money link: futures build-up + delivery + named FII/DII on one line per share"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import moneylink as M
fo = [{"s": "GLENMARK", "chg": 2.94, "bu": "LONG BUILD-UP", "cr": 164, "oi": 6.1}, {"s": "HDFCBANK", "chg": 1.79, "bu": "SHORT COVERING", "cr": -847, "oi": -3.6},
      {"s": "TATASTEEL", "chg": -2.81, "bu": "SHORT BUILD-UP", "cr": 120, "oi": 4.0}, {"s": "INFY", "chg": -1.5, "bu": "SHORT BUILD-UP", "cr": 90, "oi": 2.0}]
DL = ("2026-11-09", {"GLENMARK": {"chg": 2.94, "x": 2.4, "extra": 69.2, "dp": 53.3}, "TATASTEEL": {"chg": -2.81, "x": 1.8, "extra": 40.0, "dp": 50},
                    "INFY": {"chg": -1.5, "x": 1.9, "extra": 30.0, "dp": 60}, "HDFCBANK": {"chg": 1.79, "x": 1.0, "extra": 0, "dp": 40}})
W = {"fii_buy": [{"s": "GLENMARK", "cr": 210, "who": "a foreign fund"}], "dii_buy": [{"s": "INFY", "cr": 300, "who": "a mutual fund"}]}
r = M.link(fo, DL, W); R = {x["s"]: x for x in r["rows"]}
ok = True
def check(n, g):
    global ok
    print(("  ok   " if g else "  FAIL ") + n); ok = ok and bool(g)
check("GLENMARK: long build-up + big-hands delivery + FII buy -> ALL AGREE ▲, score 4, first", R["GLENMARK"]["word"] == "ALL AGREE ▲" and R["GLENMARK"]["sc"] == 4 and r["rows"][0]["s"] == "GLENMARK")
check("TATASTEEL: short build-up + delivery selling -> ALL AGREE ▼", R["TATASTEEL"]["word"] == "ALL AGREE ▼" and R["TATASTEEL"]["sc"] == -3)
check("INFY: futures ▼ but a DII buy -> score -2 (the named buy softens it)", R["INFY"]["sc"] == -2)
check("HDFCBANK: short covering, normal delivery -> FUTURES ▲ (weak)", R["HDFCBANK"]["word"] == "FUTURES ▲" and R["HDFCBANK"]["sc"] == 1)
check("the ▲ / ▼ lists", [x["s"] for x in r["up"]] == ["GLENMARK"] and [x["s"] for x in r["dn"]] == ["TATASTEEL", "INFY"])
print("P184 TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
P184TEST_PY
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
  body.topchart.fkin:not(.mk-money):not(.mk-opts):not(.mk-big) #mk #q-mon,body.topchart.fkin:not(.mk-money):not(.mk-opts):not(.mk-big) #mk #q-ins,body.topchart.fkin:not(.mk-money):not(.mk-opts):not(.mk-big) #mk #q-idx{display:none !important}
  body.topchart.fkin:not(.mk-money):not(.mk-opts):not(.mk-big) #mk{grid-template-rows:auto auto auto minmax(0,1.25fr) minmax(0,1fr) !important;
    grid-template-areas:"mov fk fk act" "mov ear ear act" "mov dsk dsk act" "mov don don act" "mov rot rot nws" !important}
  body.topchart.mk-money #mk>.q,body.topchart.mk-opts #mk>.q,body.topchart.mk-big #mk>.q{display:none !important}
  body.topchart.mk-money #mk>#q-mon,body.topchart.mk-big #mk>#q-lnk,body.topchart.mk-big #mk>#q-ins,body.topchart.mk-opts #mk>#q-idx{display:flex !important;flex-direction:column}
  body.topchart.mk-money #mk,body.topchart.mk-opts #mk,body.topchart.mk-big #mk{height:auto !important;grid-template-columns:minmax(0,1fr) !important;grid-template-rows:auto auto auto !important}
  body.topchart.mk-money #mk{grid-template-areas:"fk" "mon" !important}body.topchart.mk-opts #mk{grid-template-areas:"fk" "idx" !important}
  body.topchart.mk-big #mk{grid-template-areas:"fk" "lnk" "ins" !important}#q-lnk{grid-area:lnk}
  body.topchart.mk-money #q-mon{min-height:72vh}body.topchart.mk-big #q-lnk{min-height:55vh}body.topchart.mk-big #q-ins{min-height:40vh}body.topchart.mk-opts #q-idx{min-height:72vh}
  body.topchart.mk-money #mk .q>.bd,body.topchart.mk-opts #mk .q>.bd,body.topchart.mk-big #mk .q>.bd{max-height:none;flex:1}
}
#fkeys a[data-v="three"],#fkeys a[data-v="secs"]{display:none !important}
#learn .gd{padding:10px 16px 30px;max-width:1100px;font:14px/1.6 var(--ui,system-ui);color:var(--txt)}
#learn .gd h3{color:var(--amber);font:700 15px/1.3 var(--ui,system-ui);letter-spacing:.06em;margin:22px 0 6px;text-transform:uppercase}
#learn .gd table{border-collapse:collapse;margin:6px 0 10px;width:100%;max-width:900px}#learn .gd td,#learn .gd th{border:1px solid var(--line);padding:6px 9px;text-align:left;vertical-align:top}
#learn .gd th{color:var(--dim);font-weight:600}#learn .gd .u{color:var(--up)}#learn .gd .d{color:var(--dn)}#learn .gd b{color:var(--hi)}
#learn .gd .bx{border:1px solid var(--line);border-radius:7px;padding:8px 12px;background:var(--panel);margin:8px 0}
#q-lnk{display:none}#mk-lnk table{width:100%;border-collapse:collapse;font-size:12.5px}#mk-lnk td,#mk-lnk th{padding:4px 8px;border-bottom:1px solid var(--line);text-align:left;white-space:nowrap}
#mk-lnk th{color:var(--dim);font-weight:600;position:sticky;top:0;background:var(--panel)}#mk-lnk tr.k{cursor:pointer}#mk-lnk tr.k:hover{background:var(--panel2)}
#mk-lnk .lg{display:flex;gap:16px;padding:6px 8px;flex-wrap:wrap}#mk-lnk .lg div{flex:1;min-width:280px}#mk-lnk .note{color:var(--dim);font-size:11.5px;padding:2px 8px 6px}
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
let MKSUB=""; let SUBGO=false; let LNK=null, LNKT=0;
async function pullLink(){ if(Date.now()-LNKT<60000&&LNK) return drawLink(); LNKT=Date.now(); try{ const r=await fetch("flow?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ LNK=await r.json(); drawLink(); } }catch(e){} }
function drawLink(){ const el=$("mk-lnk"); if(!el||!LNK) return; const c=v=>v>0?"pu":v<0?"pd":"dim"; const rs=v=>v==null?"—":`${v>0?"+":"−"}₹${Math.abs(Math.round(v)).toLocaleString("en-IN")} cr`;
  const nm=x=>(x.named||[]).map(n=>`<b class="${/buy/.test(n.k)?"pu":"pd"}">${n.k.slice(0,3).toUpperCase()} ${/buy/.test(n.k)?"BUY":"SELL"}</b> ₹${Math.round(n.cr||0)} cr`).join(" · ")||'<span class="dim">—</span>';
  const one=x=>`<tr class="k" onclick="mkOpen('${esc(x.s)}')"><td><b>${esc(x.s)}</b></td><td class="${c(x.chg)}">${x.chg!=null?(x.chg>0?"+":"")+x.chg.toFixed(2)+"%":"—"}</td><td class="${c(x.fs)}">${esc((x.bu||"—").toLowerCase())}</td><td class="${c(x.cr)}">${rs(x.cr)}</td><td class="${c(x.oi)}">${x.oi!=null?(x.oi>0?"+":"")+x.oi+"%":"—"}</td><td class="${c(x.ds)}">${x.dx!=null?x.dx+"× normal"+(x.ds?(x.ds>0?" · buying":" · selling"):""):"—"}</td><td>${nm(x)}</td><td class="${c(x.sc)}"><b>${x.sc>0?"+":""}${x.sc}</b></td><td class="${/▲/.test(x.word)?"pu":/▼/.test(x.word)?"pd":"dim"}"><b>${esc(x.word)}</b></td></tr>`;
  const mini=(L,cl)=>(L||[]).length?(L||[]).map(x=>`<span class="k" onclick="mkOpen('${esc(x.s)}')"><b class="${cl}">${esc(x.s)}</b> <span class="dim">${esc((x.bu||"").toLowerCase())} · ${x.dx}×</span></span>`).join(" · "):'<span class="dim">none</span>';
  el.innerHTML=`<div class="lg"><div><b class="pu">▲ ALL AGREE UP</b> <span class="dim">futures build-up + big-hands delivery both up</span><br>${mini(LNK.up,"pu")}</div><div><b class="pd">▼ ALL AGREE DOWN</b> <span class="dim">futures + delivery both down</span><br>${mini(LNK.dn,"pd")}</div></div>
    <div class="note">futures: GIR live / NSE's file after 18:40 · delivery: NSE's file ${esc(LNK.deliv_day||"(comes ~18:00)")} vs each share's own 20-day normal · named = FII / DII bulk & block deals · score: long build-up +2 · short covering +1 · short build-up −2 · long unwinding −1 · delivery ±1 · named ±1. A reading of the last session - the 09:20 call and the live price decide.</div>
    <table><tr><th>SHARE</th><th>PRICE</th><th>FUTURES BUILD-UP</th><th>FRESH ₹</th><th>FUT OI</th><th>DELIVERY</th><th>FII / DII</th><th>SCORE</th><th>READING</th></tr>${(LNK.rows||[]).map(one).join("")}</table>`; }
function subApply(){ const b=document.body; b.classList.toggle("mk-money",VIEW==="market"&&MKSUB==="money"); b.classList.toggle("mk-opts",VIEW==="market"&&MKSUB==="opts"); b.classList.toggle("mk-big",VIEW==="market"&&MKSUB==="big"); if(VIEW==="market"&&MKSUB==="big") pullLink();
  document.querySelectorAll("#fkeys a").forEach(a=>{ const v=a.dataset.v; a.classList.toggle("on", MKSUB?(v==="mk-"+MKSUB):(v===VIEW)); });
  if(VIEW==="market"){ setTimeout(()=>{ try{ if(typeof mkFit==="function") mkFit(); drawMarket.force=true; drawMarket(); drawMarket.force=false; if(typeof ixDraw==="function") ixDraw(); }catch(e){} },30); } }
function mkSub(s){ SUBGO=true; MKSUB=s; setView("market"); SUBGO=false; subApply(); window.scrollTo(0,0); }
{ const sv5_=setView; setView=function(v){ if(!SUBGO) MKSUB=""; sv5_(v); subApply(); if(v==="tom") tomBrief(); }; }
async function tomBrief(){ try{ const r=await fetch("brief?k="+encodeURIComponent(K),{cache:"no-store"}); if(!r.ok) return; const t=await r.text();
  let el=$("tmb"); if(!el){ el=document.createElement("div"); el.id="tmb"; const tl=$("tml"); if(tl) tl.parentNode.insertBefore(el,tl); }
  el.textContent="AFTER THE LIST WAS MADE - everything filed / said on F&O shares since the last close (the 08:30 brief, live):\n\n"+t; }catch(e){} }
setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="tom") tomBrief(); if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big") pullLink(); },60000);
function tabsFix(){ const fk=$("fkeys"); if(!fk||fk.dataset.p184) return; fk.dataset.p184="1";
  const mk=(v,k,l,f,t)=>{ const a=document.createElement("a"); a.dataset.v=v; a.innerHTML=`<b>${k}</b>${l}`; a.title=t; a.onclick=f; return a; };
  const after=(v,el)=>{ const r=fk.querySelector(`a[data-v="${v}"]`); if(r) r.after(el); else fk.appendChild(el); };
  after("now",mk("mk-money","2","F&amp;O MONEY",()=>mkSub("money"),"fresh futures money + the big hands (key 2)"));
  after("mk-money",mk("mk-big","B","🏦 BIG MONEY",()=>mkSub("big"),"futures build-up + big-hands delivery + FII/DII deals, linked per share (key B)"));
  after("scn",mk("mk-opts","4","OPTIONS",()=>mkSub("opts"),"NIFTY · BANKNIFTY options (key 4)"));
  fk.appendChild(mk("learn","G","📘 GUIDE",()=>setView("learn"),"futures · options · OI · build-up · support / resistance · bullish / bearish (key G)"));
  const dh=document.querySelector("#desk h2 small"); if(dh) dh.textContent="GIR's own PRACTICE trades - automatic, on paper, no real money; nobody types them in. Your own trades: 9 MY F&O"; }
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return;
  const m={"2":()=>mkSub("money"),"4":()=>mkSub("opts"),"b":()=>mkSub("big"),"B":()=>mkSub("big"),"g":()=>setView("learn"),"G":()=>setView("learn")}; if(m[e.key]){ e.stopImmediatePropagation(); e.preventDefault(); m[e.key](); } },true);
tabsFix(); window.addEventListener("load",tabsFix);
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
A_SEC = '  <section class="p pn xp" id="desk">'
A_INS = '    <div class="q" id="q-ins">'
LNK = '    <div class="q" id="q-lnk"><h3>🏦 BIG MONEY · LINKED <span>futures build-up + delivery + FII / DII, one line per F&amp;O share · tap = its screen</span></h3><div class="bd" id="mk-lnk"><div class="empty">loading…</div></div></div>\n'
R_OLD = '            if u.path == "/home":'
R_NEW = ('            if u.path == "/brief":                    # patch 184: the morning brief, live, for the TOMORROW tab\n'
         '                try:\n'
         '                    import morningbrief\n'
         '                    return self.send(200, morningbrief.build()[0], "text/plain; charset=utf-8")\n'
         '                except Exception as ex_:\n'
         '                    return self.send(200, "the morning brief is not installed yet (install_p169.sh)", "text/plain; charset=utf-8")\n'
         '            if u.path == "/flow":                     # patch 184: futures build-up + delivery + FII / DII linked per share\n'
         '                import moneylink, instflow\n'
         '                return self.send(200, json.dumps(moneylink.link(live_obj().get("fo_paths") or [], None, (instflow.summary().get("w") or {}).get("1") or {}), default=str), "application/json; charset=utf-8")\n'
         + R_OLD)
# one rule for every panel: a build-up needs a real move - OI 1%+ and price 0.25%+ (KOTAKBANK -0.21% with OI +0.1% was "SHORT BUILD-UP")
S_OLD = """        _fut_eod(v)                                              # patch 146b: after the close, NSE's official futures OI
    except Exception:
        pass
"""
S_NEW = S_OLD + """    try:                                                         # patch 184: no build-up label on a tiny move (OI under 1%, price under 0.25%)
        for f_ in v.get("fo_paths") or []:
            if f_.get("bu") and (abs(f_.get("oi") or 0) < 1.0 or abs(f_.get("chg") or 0) < 0.25):
                f_["bu"] = ""
    except Exception:
        pass
"""
H_OLD = "const xs=msort(mo[b]||[]).slice(0,6);"
H_NEW = "const xs=msort(mo[b]||[]).slice(0,document.body.classList.contains(\"mk-money\")?25:6);   /* patch 184: the full list on its own tab */"
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
msg = []
if "patch 184" not in t:
    if "patch 179" not in t or t.count(A_JS) != 1 or t.count(A_SEC) != 1:
        print("patches 177-179 are not in home.html - install them first"); sys.exit(1)
    if t.count(A_INS) != 1:
        print("the BIG MONEY panel was not found"); sys.exit(1)
    if t.count(H_OLD) == 1:
        t = t.replace(H_OLD, H_NEW, 1)
    t = t.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1).replace(A_SEC, GUIDE + "\n" + A_SEC, 1).replace(A_INS, LNK + A_INS, 1)
    open(h, "w", encoding="utf-8").write(t); msg.append("home.html: the tabs")
if "patch 184" not in s:
    if s.count(R_OLD) != 1:
        print("ANCHOR x%d in dashserve.py" % s.count(R_OLD)); sys.exit(1)
    s = s.replace(R_OLD, R_NEW, 1)
    if s.count(S_OLD) == 1:
        s = s.replace(S_OLD, S_NEW, 1)
    open(p, "w", encoding="utf-8").write(s); msg.append("dashserve.py: /brief, /flow, one build-up rule")
print(" · ".join(msg) or "patch 184 is already in")
PY_PATCH
back() { cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; }
R=$(python3 $W/p184_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile dashserve.py moneylink.py || { back; echo "does not compile - old files back"; exit 1; }
timeout 60 python3 p184test.py > /tmp/p184test.log 2>&1 && echo "p184test.py passed (the money link)" || { echo "TEST FAILED - old files back"; tail -4 /tmp/p184test.log; back; exit 1; }
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 60 python3 -c "
import json, moneylink
st = json.load(open('dash_state.json'))
r = moneylink.link(st.get('fo_paths') or [])
print('the money link now: %d F&O shares · delivery file %s · ALL AGREE ▲ %s · ▼ %s' % (r['n'], r['deliv_day'], ' '.join(x['s'] for x in r['up'][:6]) or '-', ' '.join(x['s'] for x in r['dn'][:6]) or '-'))
" 2>&1 | tail -1
echo -n "the page server restarting (502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "✅ the page is back" || { echo "❌ the page did not come back - old files back"; back; systemctl restart gir-dash; exit 1; }
rm -rf $W
echo "PATCH 184 APPLIED - Ctrl + Shift + R on girtrader.com. Tabs: MARKET · R · 1 NOW · 2 F&O MONEY · B BIG MONEY · 3 OI SCENARIOS · 4 OPTIONS · 5-0 · G GUIDE"
