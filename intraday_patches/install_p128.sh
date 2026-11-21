#!/bin/bash
# PATCH 128 - THE SHARE CARD READS RIGHT (on top of patch 127).
#   - INDUSTRY: NSE puts Data Patterns, HAL, BEL under "Capital Goods" together with pipes (Astral) and ACs (Voltas). The card
#     now shows the share's own industry (defence, pipes, cables, electricals, railways, pharma, PSU / private banks ...)
#     and its peers from it; NSE's sector stays below
#   - news under a share: "inflation data" no longer counts as Data Patterns news - a one-word name only as a Name, and
#     common English first words (data, page, solar, persistent, prestige ...) need the full company name
#   - the checklist: ONE line on top - DECISION: BUY CE / BUY PE / WATCH / NO TRADE, and why
#   home.html, dashserve.py (exact anchors). Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g128; mkdir -p $W
grep -q "def topic" $D/tglanes.py 2>/dev/null || { echo "patch 127 is not installed yet - paste patch 127 first"; exit 1; }
grep -q "function ckDecision" $D/home.html && { echo "patch 128 is already installed"; exit 1; }
F="home.html dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p128test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p128_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p128_patch.py - PATCH 128: the share card reads right.
  1 INDUSTRY peers: NSE puts Data Patterns, HAL and BEL under "Capital Goods" with pipes (Astral) and ACs (Voltas). The card now
    shows the share's own industry (defence, pipes, cables, electricals, railways, ...) and its peers; NSE's sector stays below it
  2 news under a share: a one-word company name is matched only as a Name ("Data" no longer matches "inflation data"), and
    common English first words (data, page, solar, persistent, prestige ...) need the full name
  3 the checklist gets ONE line on top: BUY CE / BUY PE / WATCH / NO TRADE - with why (futures, both sides, an old reading)
Usage: python3 p128_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
INDG = '''/* patch 128: INDUSTRY - finer than NSE's sector (NSE puts defence, pipes and ACs all under "Capital Goods") */
const INDG={"defence":"HAL BEL BDL MAZDOCK COCHINSHIP DATAPATTNS SOLARINDS BEML","pipes & plastics":"ASTRAL SUPREMEIND FINPIPE",
  "cables & wires":"POLYCAB KEI HFCL","electrical equipment":"SIEMENS ABB CGPOWER BHEL POWERINDIA GVT&D THERMAX SUZLON INOXWIND PREMIERENE",
  "electronics makers":"KAYNES DIXON PGEL AMBER SYRMA","railways":"RVNL IRCON TITAGARH IRFC RAILTEL CONCOR","construction":"LT NCC KEC IRB NBCC",
  "psu banks":"SBIN BANKBARODA PNB CANBK UNIONBANK BANKINDIA INDIANB","private banks":"HDFCBANK ICICIBANK AXISBANK KOTAKBANK INDUSINDBK FEDERALBNK IDFCFIRSTB AUBANK BANDHANBNK RBLBANK YESBANK",
  "cement":"ULTRACEMCO AMBUJACEM SHREECEM DALBHARAT ACC JKCEMENT RAMCOCEM","realty":"DLF LODHA GODREJPROP OBEROIRLTY PRESTIGE PHOENIXLTD BRIGADE",
  "jewellery":"TITAN KALYANKJIL","gold loans":"MUTHOOTFIN MANAPPURAM","oil marketing":"BPCL HINDPETRO IOC","city gas":"IGL MGL ATGL GAIL",
  "tyres":"MRF APOLLOTYRE BALKRISIND CEATLTD","two-wheelers":"HEROMOTOCO BAJAJ-AUTO TVSMOTOR EICHERMOT","paints":"ASIANPAINT BERGEPAINT INDIGOPNTS",
  "pharma":"SUNPHARMA DRREDDY CIPLA DIVISLAB LUPIN AUROPHARMA TORNTPHARM ZYDUSLIFE ALKEM GLENMARK BIOCON LAURUSLABS GRANULES IPCALAB ABBOTINDIA MANKIND PPLPHARMA NATCOPHARM AJANTPHARM SYNGENE",
  "cars & trucks":"MARUTI TATAMOTORS TMPV M&M ASHOKLEY","hospitals":"APOLLOHOSP MAXHEALTH FORTIS","diagnostics":"LALPATHLAB METROPOLIS","telecom":"BHARTIARTL IDEA INDUSTOWER",
  "power utilities":"NTPC POWERGRID NHPC SJVN TATAPOWER JSWENERGY ADANIPOWER TORNTPOWER CESC ADANIGREEN ADANIENSOL",
  "it services":"TCS INFY WIPRO HCLTECH TECHM LTIM MPHASIS COFORGE PERSISTENT","er&d / it mid":"LTTS KPITTECH TATAELXSI CYIENT TATATECH BSOFT OFSS",
  "steel":"TATASTEEL JSWSTEEL JINDALSTEL SAIL JSL","non-ferrous":"HINDALCO VEDL NATIONALUM HINDCOPPER HINDZINC",
  "brokers & exchanges":"BSE MCX CDSL ANGELONE CAMS KFINTECH NUVAMA 360ONE MOTILALOFS IEX","amcs & insurers":"HDFCAMC SBILIFE HDFCLIFE ICICIPRULI ICICIGI LICI"};
const INDOF={}; Object.entries(INDG).forEach(([n,v])=>v.split(" ").forEach(s=>{ INDOF[s]=n; }));
function indGroup(s){ const n=INDOF[s]; if(!n) return null; const syms=INDG[n].split(" "); const rows=(TAPE||[]).filter(x=>syms.includes(x.s)&&x.chg!=null);
  return {name:n,syms,chg:rows.length?rows.reduce((a,x)=>a+x.chg,0)/rows.length:null,n:rows.length}; }
/* patch 128: ONE decision on top of the checklist (the two sides alone left the reader to decide) */
function ckDecision(c){ if(!c||!c.CE||!c.PE) return ""; const ist=new Date(Date.now()+330*60000), today=ist.toISOString().slice(0,10), hm=ist.toISOString().slice(11,16);
  const live=c.d===today&&ist.getUTCDay()>0&&ist.getUTCDay()<6&&hm>="09:20"&&hm<="15:30";
  const fut=x=>((x.items||[]).find(t=>t[0]==="FUTURES")||[0,0])[1], opt=x=>((x.items||[]).find(t=>t[0]==="OPTIONS")||["","",""])[2]||"";
  const pc=c.CE.verdict==="PASS", pp=c.PE.verdict==="PASS"; let side=null, cls="no", word, why;
  if(pc&&!pp) side="CE"; else if(pp&&!pc) side="PE";
  if(!side){ word="NO TRADE"; why=pc&&pp?"both sides pass - the chain does not agree":"neither side passes ("+c.CE.score+"/7 CE · "+c.PE.score+"/7 PE)"; }
  else { const x=c[side], f=fut(x), both=/calls bought/.test(opt(x))&&/puts bought/.test(opt(x));
    if(f<0){ word="NO TRADE"; why=`${side} passes ${x.score}/7 but the futures go the other way`; }
    else if(f>0&&!both){ word="BUY "+side; cls=side==="CE"?"up":"dn"; why=`${x.score}/7 and the futures agree${c[side==="CE"?"PE":"CE"].verdict==="FAIL"?" · the other side fails":""}`; }
    else { word="WATCH "+side; cls="am"; why=`${x.score}/7, but ${f===0?"the futures do not confirm yet (no money behind it)":""}${f===0&&both?" and ":""}${both?"calls AND puts are both being bought (no clear side in the options)":""} - wait for the futures / OI to agree`; } }
  const old=!live?`<br><span class="dim">this is the reading of ${esc(c.d||"?")} ${esc((c.t||"").slice(0,5))} - decide on the live reading after 09:20${hm<"09:30"&&c.d===today?" (the first 15 minutes are noisy)":""}</span>`:"";
  return `<div class="dec ${cls}"><b>DECISION: ${word}</b> <span>${esc(why)}</span>${old}</div>`; }
'''
EDITS = {
    "home.html": [
        ('''function shareInfo(){ if(!FOC) return ""; const r=(TAPE||[]).find(x=>x.s===FOC)||{}; const sec=(SECS||[]).find(x=>(x.syms||[]).includes(FOC)); const c=FCK&&FCK.s===FOC?FCK:null;
  const peers=sec?(TAPE||[]).filter(x=>sec.syms.includes(x.s)&&x.s!==FOC&&x.chg!=null).sort((a,b)=>Math.abs(b.chg)-Math.abs(a.chg)).slice(0,6):[];''',
         INDG + '''function shareInfo(){ if(!FOC) return ""; const r=(TAPE||[]).find(x=>x.s===FOC)||{}; const sec=(SECS||[]).find(x=>(x.syms||[]).includes(FOC)); const c=FCK&&FCK.s===FOC?FCK:null;
  const ind=indGroup(FOC), grp=ind?ind.syms:(sec?sec.syms:[]);
  const peers=(TAPE||[]).filter(x=>grp.includes(x.s)&&x.s!==FOC&&x.chg!=null).sort((a,b)=>Math.abs(b.chg)-Math.abs(a.chg)).slice(0,6);'''),
        ('''    <div><small>SECTOR</small>${sec?`<b>${esc(sec.name.toUpperCase())}</b> <span class="${cls(sec.chg)}">${pc(sec.chg)}</span> · ${(sec.syms||[]).length} F&amp;O shares`:"—"}</div>
    <div><small>PEERS (biggest moves)</small>''',
         '''    ${ind?`<div><small>INDUSTRY</small><b>${esc(ind.name.toUpperCase())}</b> <span class="${cls(ind.chg)}">${pc(ind.chg)}</span> · ${ind.n} F&amp;O shares</div>`:""}
    <div><small>${ind?"NSE SECTOR":"SECTOR"}</small>${sec?`<b>${esc(sec.name.toUpperCase())}</b> <span class="${cls(sec.chg)}">${pc(sec.chg)}</span> · ${(sec.syms||[]).length} F&amp;O shares`:"—"}</div>
    <div><small>PEERS${ind?" in "+esc(ind.name):""} (biggest moves)</small>'''),
        ('''    <div class="sd">${side("CE")}${side("PE")}</div>''', '''    ${ckDecision(c)}<div class="sd">${side("CE")}${side("PE")}</div>'''),
        ('''#focus .ck .wn{''', '''#focus .ck .dec{padding:6px 8px;border:1px solid var(--line2);border-left:4px solid var(--dim);background:#06080b;font-size:11.5px;line-height:1.45}   /* patch 128 */
#focus .ck .dec b{letter-spacing:.04em;margin-right:6px}#focus .ck .dec.up{border-left-color:var(--up)}#focus .ck .dec.up b{color:var(--up)}
#focus .ck .dec.dn{border-left-color:var(--dn)}#focus .ck .dec.dn b{color:var(--dn)}#focus .ck .dec.am{border-left-color:var(--amber)}#focus .ck .dec.am b{color:var(--amber)}#focus .ck .dec.no b{color:var(--hi)}
#focus .ck .wn{'''),
    ],
    "dashserve.py": [
        ('''def news_keys():
''', '''NM_COMMON |= {"data", "info", "page", "tube", "solar", "blue", "supreme", "persistent", "granules", "mankind", "phoenix", "prestige", "brigade",
              "hero", "whirlpool", "escorts", "metropolis", "torrent", "federal", "container", "indus", "amber", "apollo", "eternal", "jubilant",
              "shriram", "premier", "inox", "piramal", "gmr", "sona", "delta", "titan", "trent", "vodafone", "info-edge"}   # patch 128: common English first words


def news_keys():
'''),
        ('''            out[sym] = (re.compile(r"(?<![A-Za-z])%s(?![A-Za-z])" % r"(?:\\s*&\\s*|\\s+and\\s+|\\s+)".join(re.escape(x) for x in kw), re.I), sym)''',
         '''            if len(kw) == 1 and len(w) > 1:                       # patch 128: one word = only as a Name ("Data" yes, "inflation data" no)
                x0 = kw[0]
                out[sym] = (re.compile(r"(?<![A-Za-z])(?:%s|%s)(?![A-Za-z])" % (re.escape(x0[:1].upper() + x0[1:]), re.escape(x0.upper()))), sym)
                continue
            out[sym] = (re.compile(r"(?<![A-Za-z])%s(?![A-Za-z])" % r"(?:\\s*&\\s*|\\s+and\\s+|\\s+)".join(re.escape(x) for x in kw), re.I), sym)'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("home.html: INDUSTRY peers + the DECISION line · dashserve.py: company news matched by the name")
PY_PATCH
cat > $D/p128test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p128test.py - the share card reads right: DATAPATTNS's industry is DEFENCE (peers HAL, BEL ...), the gold article's
"inflation data" is not Data Patterns news, and the checklist says ONE decision (ADANIENSOL: CE 6/7, futures flat -> WATCH CE)."""
import os, sys, json, shutil, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import dashserve, newsroom
real = newsroom.fo_names
newsroom.fo_names = lambda: [("DATAPATTNS", "Data Patterns (India) Limited", 125), ("PERSISTENT", "Persistent Systems Limited", 100), ("GLENMARK", "Glenmark Pharmaceuticals Limited", 375),
                             ("TITAN", "Titan Company Limited", 175), ("POLYCAB", "Polycab India Limited", 25)]
dashserve._NMK.update({"t": 0.0, "v": {}})
dashserve.news_keys()                                    # built now, from the five names above (kept an hour)
R = dashserve.news_relevant
newsroom.fo_names = real
check("'Gold, silver price outlook: US-Iran tensions, inflation data to set the tone' is NOT Data Patterns news",
      not R("DATAPATTNS", "Gold, silver price outlook: US-Iran tensions, inflation data to set the tone next week"))
check("'Data Patterns Q2 profit falls 56%' and 'DATAPATTNS shares slide' ARE", R("DATAPATTNS", "Data Patterns Q2 profit falls 56%") and R("DATAPATTNS", "DATAPATTNS shares slide 5%"))
check("'persistent selling hits IT stocks' is not Persistent Systems; 'Persistent Systems bags deal' is",
      not R("PERSISTENT", "persistent selling hits IT stocks") and R("PERSISTENT", "Persistent Systems bags $200 mn deal"))
check("'Glenmark gets USFDA nod' still matches by the one name; 'glenmark' in lower case does not",
      R("GLENMARK", "Glenmark gets USFDA nod for generic") and not R("GLENMARK", "the glenmark of the season"))
pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page: INDUSTRY peers on the card and ONE decision on the checklist", "function indGroup(s)" in pg and "function ckDecision(c)" in pg and "${ckDecision(c)}" in pg and '"defence":"HAL BEL BDL MAZDOCK COCHINSHIP DATAPATTNS' in pg)
node = shutil.which("node")
if node:
    a = pg.index("/* patch 128: INDUSTRY"); b = pg.index("function shareInfo(){")
    js = "const esc=s=>String(s);let TAPE=[{s:'HAL',chg:-1.2},{s:'BEL',chg:-0.8},{s:'DATAPATTNS',chg:-4.85},{s:'ASTRAL',chg:-9.68},{s:'BDL',chg:0.4}];\n" + pg[a:b] + r"""
const g=indGroup('DATAPATTNS'); console.log(JSON.stringify({name:g.name,n:g.n}));
const it=(f,o)=>[["TREND",1,"x"],["FUTURES",f,"x"],["OPTIONS",1,o],["ROOM",1,""],["IV",1,""],["BREAKEVEN",1,""],["LIQUIDITY",1,""]];
const C=(cv,cs,pv,ps,f,o,d)=>({d:d,t:"15:25:00",CE:{verdict:cv,score:cs,items:it(f,o)},PE:{verdict:pv,score:ps,items:it(f,o)}});
console.log(ckDecision(C("PASS",6,"MIXED",4,0,"calls bought · puts bought","2026-11-06")));
console.log(ckDecision(C("PASS",7,"FAIL",2,1,"calls bought","2099-01-01")));
console.log(ckDecision(C("MIXED",4,"MIXED",4,0,"","2026-11-06")));
console.log(ckDecision(C("PASS",6,"MIXED",4,-1,"calls bought","2026-11-06")));"""
    r = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    out = r.stdout.strip().split("\n")
    check("DATAPATTNS -> INDUSTRY defence (4 F&O shares on the tape with it): %s" % (out[0] if out else r.stderr[:200]), out and json.loads(out[0]) == {"name": "defence", "n": 4})
    check("ADANIENSOL (CE PASS 6/7, PE MIXED, futures flat, calls AND puts bought, Friday's reading) -> WATCH CE: %s" % (out[1][:160] if len(out) > 1 else ""),
          len(out) > 1 and "DECISION: WATCH CE" in out[1] and "futures do not confirm" in out[1] and "both being bought" in out[1] and "reading of 2026-11-06" in out[1])
    check("CE PASS + futures agree + PE fails -> BUY CE", len(out) > 2 and "DECISION: BUY CE" in out[2])
    check("neither side passes -> NO TRADE", len(out) > 3 and "DECISION: NO TRADE" in out[3] and "neither side passes" in out[3])
    check("CE passes but the futures go the other way -> NO TRADE", len(out) > 4 and "DECISION: NO TRADE" in out[4] and "other way" in out[4])
else:
    print("  (node not on this machine - the page logic was checked when the patch was built)")
print("\nP128 SHARE CARD TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p128_patch.py $D || { rm -f $D/p128test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p128test.py || back
timeout 120 python3 p128test.py 2>&1 | grep "OK  \|FAIL\|CARD TEST\|node"
timeout 120 python3 p128test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p120test.py p123test.py p118test.py p114test.py p127test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function ckDecision" || { echo "the new page is not being served"; back; }
echo
echo "PATCH 128 APPLIED. Reload the GIR page: DATAPATTNS -> INDUSTRY DEFENCE (HAL, BEL, BDL ...); CHECKLIST -> one DECISION line."
