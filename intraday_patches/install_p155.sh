#!/bin/bash
# PATCH 155 - THE PHONE AS AN APP. Tabs at the top, one page at a time: ⌂ HOME (the chart + F&O MOVERS) · 🟧 TRADE · ₹ MONEY · ▤ SECTORS ·
#   📰 NEWS · ⚙ OPTIONS · ⋯ MORE. Tap a share = its full screen, ✕ = back. A round ⌂ button on every page and share = HOME.
#   Laptop unchanged. home.html only (needs 154). Restarts gir-dash only - safe any time, also in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g155; mkdir -p $W
grep -q "patch 155" $D/home.html && { echo "patch 155 is already installed"; exit 1; }
grep -q "patch 154" $D/home.html || { echo "patch 154 is not installed yet - install it first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
cat > $W/p155_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p155_patch.py - PATCH 155: THE PHONE AS AN APP (Rama, 10 Nov: "the mobile should be a different display - the market page with F&O movers
and the NIFTY chart; tap a share = its details, close = back; tabs at the top for each page; every page a Home button").
On a phone (under 900 px) the market page becomes tabs, one page at a time:
  ⌂ HOME     the NIFTY / BANKNIFTY chart + F&O MOVERS          🟧 TRADE   TRADE NOW + IMPORTANT, the alert tabs, ⚡ EARLY
  ₹ MONEY    F&O MONEY + big money (delivery)                  ▤ SECTORS  sectors + rotation
  📰 NEWS    OI scenarios · news                               ⚙ OPTIONS  the NIFTY / BANKNIFTY options desk + the F&O desk
  ⋯ MORE     the other pages (RESULTS · NOW · THE THREE · ...)
Tap a share = its full screen (✕ = back where you were). A round ⌂ button at the bottom right of every page and every share = HOME.
The laptop is unchanged.   Usage: python3 p155_patch.py /home/globalbot/intraday  (needs 154)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = r'''/* ============ patch 155: THE PHONE AS AN APP ============ */
#mtab,#mhome{display:none}
@media(max-width:899px){
  #mtab{display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:6px 8px;border-top:1px solid var(--line);background:var(--bg)}#mtab::-webkit-scrollbar{display:none}
  #mtab a{flex:none;padding:8px 13px;border-radius:999px;border:1px solid var(--line2);background:var(--panel);color:var(--txt);font:700 13px/1 var(--ui);letter-spacing:.06em;cursor:pointer;white-space:nowrap}
  #mtab a.on{background:var(--amber);color:#1a1205;border-color:var(--amber)}#mtab a b{font-weight:700;margin-left:4px;color:var(--dn)}#mtab a.on b{color:#1a1205}
  #mhome{display:flex;position:fixed;right:max(14px,env(safe-area-inset-right,0px));bottom:calc(46px + env(safe-area-inset-bottom,0px));z-index:45;width:52px;height:52px;border-radius:50%;
    background:var(--amber);color:#1a1205;align-items:center;justify-content:center;font:700 22px/1 var(--ui);box-shadow:0 4px 16px rgba(0,0,0,.55);cursor:pointer;border:0}
  body.vmk:not(.mt-more) #fkeys{display:none}
  body.vmk:not(.mt-trade) #abar{display:none}
  #idx{gap:6px;padding:6px}#idx .ix{min-width:122px;padding:4px 10px}#idx .ix span{font-size:16px}#idx .ix small{font-size:11px}#idx .brand{font-size:16px;padding:0 10px}
  #mk>.q{display:none !important}
  body.mt-home #mk #q-nif{display:flex !important;order:1 !important;height:320px !important}
  body.mt-home #mk #q-mov{display:flex !important;order:2 !important;height:calc(100vh - 150px) !important;min-height:420px}
  body.mt-trade #mk #q-act{display:flex !important;order:1 !important;height:auto !important;max-height:none !important}
  body.mt-trade #mk #q-ear{display:flex !important;order:2 !important}
  body.mt-money #mk #q-mon{display:flex !important;order:1 !important;height:auto !important}
  body.mt-money #mk #q-ins{display:flex !important;order:2 !important;height:auto !important;max-height:none !important}
  body.mt-sect #mk #q-don{display:flex !important;order:1 !important;height:auto !important;max-height:none !important}
  body.mt-sect #mk #q-rot{display:flex !important;order:2 !important;height:auto !important;max-height:none !important}
  body.mt-news #mk #q-nws{display:flex !important;order:1 !important;height:calc(100vh - 150px) !important;min-height:480px}
  body.mt-opt #mk #q-idx{display:flex !important;order:1 !important;height:auto !important;max-height:none !important}
  body.mt-opt #mk #q-dsk{display:flex !important;order:2 !important;height:auto !important}
  body.mt-trade #mk #q-act .bd,body.mt-money #mk .bd,body.mt-sect #mk .bd,body.mt-opt #mk .bd{overflow:visible}
  body.mt-more #mk::before{content:"the other pages are the buttons above - ⌂ HOME brings you back";display:block;color:var(--dim);padding:14px 6px;font:500 13px var(--ui)}
}
#focus table.oi{width:100%;'''
JS = r'''/* patch 155: the phone as an app - tabs, one page at a time, ⌂ HOME everywhere */
const MTABS=[["home","⌂ HOME"],["trade","🟧 TRADE"],["money","₹ MONEY"],["sect","▤ SECTORS"],["news","📰 NEWS"],["opt","⚙ OPTIONS"],["more","⋯ MORE"]];
let MT="home"; try{ MT=localStorage.getItem("gir_mt")||"home"; }catch(e){}
function mtPhone(){ return window.innerWidth<900; }
function mtApply(){ MTABS.forEach(([k])=>document.body.classList.toggle("mt-"+k,MT===k)); mtDraw(); }
function mtDraw(){ const el=$("mtab"); if(!el) return; let cur=MT; try{ if(VIEW!=="market") cur="more"; }catch(e){}
  const na=(()=>{ try{ return ((D&&D.now)||[]).filter(r=>r.s&&alertTier(r)==="act").length; }catch(e){ return 0; } })();
  const h=MTABS.map(([k,l])=>`<a class="${cur===k?"on":""}" onclick="mtSet('${k}')">${l}${k==="trade"&&na?`<b>${na}</b>`:""}</a>`).join(""); if(el._h!==h){ el._h=h; el.innerHTML=h; } }
function mtSet(t){ MT=t; try{ localStorage.setItem("gir_mt",t); }catch(e){} mtApply();
  try{ if(FOC) unfocus(); }catch(e){} try{ if(VIEW!=="market") setView("market"); }catch(e){} window.scrollTo(0,0);
  setTimeout(()=>{ try{ if(typeof IXC!=="undefined"&&IXC) IXC.key=""; drawMarket.force=true; drawMarket(); drawMarket.force=false; }catch(e){} mtDraw(); },80); }
function mtInit(){ const b=document.createElement("button"); b.id="mhome"; b.title="HOME - the chart and F&O movers"; b.textContent="⌂"; b.onclick=()=>mtSet("home"); document.body.appendChild(b);
  mtApply(); setInterval(mtDraw,1500); }
setTimeout(mtInit,0);
'''
EDITS = [('  <div id="fkeys">', '  <div id="mtab"></div>\n  <div id="fkeys">'), ('#focus table.oi{width:100%;', CSS), ('function MKH(id){', JS + 'function MKH(id){')]
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 155" in s:
    print("patch 155 is already in home.html"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:60])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s); print("patched: home.html")
PY_PATCH
python3 $W/p155_patch.py $D || { echo "nothing was changed"; exit 1; }
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back"; exit 1; }
echo "PATCH 155 APPLIED. On the phone: close the GIR tab and open it again."
