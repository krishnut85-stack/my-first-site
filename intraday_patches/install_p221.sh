#!/bin/bash
# PATCH 221 - WHO IS PUSHING / PULLING IN SIMPLE WORDS + the share window never says "market closed" in market hours (Rama, 12 Nov).
#   Every push / pull box gets IN SIMPLE WORDS: one plain sentence per force ("Futures traders are making NEW bets that the price will FALL
#   (₹105 cr)"), what kind of move it is, and what it means for you ("this favours a PE ... do not hold it overnight on this alone").
#   A share window that has fallen off live ticks (GIR keeps 4 live) said "market closed · last price 14:02" - now: "⚠ this window is off
#   live ticks since 14:02 · price from the all-shares feed, live", with that live price. Tested on the page: 6 cases. Page only - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 214" $D/home.html || { echo "patch 214 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p221_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p221_patch.py - PATCH 221: WHO IS PUSHING / PULLING - IN SIMPLE WORDS (Rama, 12 Nov: "explain in simple terms the whole 'who is pulling
down' - I don't understand; when I click the notification it goes to the share and says who is pushing and pulling - I need a simple layman
explanation inside the box"). Every push / pull box (the top of each share screen, the share card's board) now has IN SIMPLE WORDS:
one plain sentence per force that is on (e.g. "Futures traders are making NEW bets that the price will FALL (₹105 cr)"), what kind of move it
is ("new sellers AND old buyers giving up - the strongest kind of fall"), and what it means for you ("this favours a PE ... do not hold it
overnight on this alone"). Page only - no restart. Usage: python3 p221_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []
p = os.path.join(D, "home.html"); S = {"s": open(p, encoding="utf-8").read()}


def rep(old, new, tag, marker=None):
    s = S["s"]
    if new in s or (marker and marker in s):
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  home.html: %s" % tag)


rep('''function shareInfo(){''', r'''/* patch 221: WHO IS PUSHING / PULLING - IN SIMPLE WORDS */
const PPW={FII:"Foreign funds",DII:"Indian funds (mutual funds, insurers)",WRITERS:"Big option sellers",FUTURES:"Futures traders",PROMOTER:"The company's owners",
  INDEX:"Index funds",COMPANY:"Company news",REGULATOR:"Government / regulator news",TIDE:"The whole market / its sector",BROKERS:"Broker ratings",
  ALGOS:"Computer trading and stop-losses",MECHANICAL:"Dates that move prices (expiry, dividend)"};
function ppSay(r,up){ const t=r.t||"", k=r.k; let x;
  if(k==="FUTURES"){ x=t.match(/₹([\d,.]+) cr/); const c=x?` (₹${x[1]} cr)`:"";
    if(/short build-up/i.test(t)) return `Futures traders are making NEW bets that the price will FALL${c}.`;
    if(/long unwinding/i.test(t)) return `Traders who had bet on a rise are GIVING UP and selling${c}.`;
    if(/long build-up/i.test(t)) return `Futures traders are making NEW bets that the price will RISE${c}.`;
    if(/short covering/i.test(t)) return `Traders who had bet on a fall are GIVING UP and buying back${c}.`; }
  if(k==="WRITERS"){ const a=[];
    if((x=t.match(/put writers buying back at ([\d.]+)/))) a.push(`The big sellers who promised it stays above ₹${x[1]} are running away - that support is breaking.`);
    if((x=t.match(/call writers buying back at ([\d.]+)/))) a.push(`The big sellers who bet it stays below ₹${x[1]} are running away - that ceiling is breaking.`);
    if((x=t.match(/roof at ([\d.]+) \(a cap/))) a.push(`Big option sellers are betting it will NOT go above ₹${x[1]} (a ceiling).`);
    if((x=t.match(/floor at ([\d.]+) \(support/))) a.push(`Big option sellers are betting it will NOT go below ₹${x[1]} (support).`);
    if((x=t.match(/calls bought at ([\d.]+)/))) a.push(`People are paying for bets that it goes above ₹${x[1]}.`);
    if((x=t.match(/puts bought at ([\d.]+)/))) a.push(`People are paying for bets that it goes below ₹${x[1]}.`);
    if(a.length) return a.join(" ");
    if(/sellers running/.test(t)) return "Option sellers are rushing out - the price can move fast."; }
  if(k==="FII"||k==="DII"){ const who=k==="FII"?"Foreign funds":"Indian funds";
    if((x=t.match(/(bought|sold) ₹([\d,.]+) cr in named deals/))) return `${who} ${x[1]==="bought"?"BOUGHT":"SOLD"} ₹${x[2]} cr of this share in big deals (last 5 days).`;
    if((x=t.match(/big hands (BUYING|SELLING)[^:]*: delivery ([\d.]+)x/))) return x[1]==="BUYING"?`Big investors BOUGHT and kept the shares (${x[2]}x the normal) - real buying.`:`Big investors SOLD more than normal (${x[2]}x) - real selling.`; }
  if(k==="ALGOS"){ x=t.match(/volume ([\d.]+)x/); return `Computer trading and stop-loss orders are speeding it ${up?"UP":"DOWN"}${x?` (trading ${x[1]}x the normal)`:""}.`; }
  if(k==="TIDE"){ if((x=t.match(/sector is ([+-][\d.]+)%/))) return `Its whole sector is ${x[1]}% - it is moving with the crowd.`;
    if(/NIFTY/.test(t)) return "The whole market (NIFTY) is moving the same way.";
    if(/on its own/.test(t)) return "It is moving on its own - its sector is not."; }
  if(k==="INDEX") return `Index funds have to ${up?"buy":"sell"} it (an index change).`;
  if(k==="MECHANICAL"&&/expiry/i.test(t)) return "Expiry week - option sellers try to hold the price at their levels.";
  const h=t.replace(/^[^:]{0,40}:\s*/,"").slice(0,90); return `${PPW[k]||k}${h?": "+h:""}.`; }
function ppPlain(P){ if(!P||!P.rows) return ""; const on=P.rows.filter(x=>x.on&&x.side), dn_=P.dir==="DOWN", w=dn_?"fall":"rise";
  if(!on.length&&!P.kind) return "";
  const mine=on.filter(x=>dn_?x.side<0:x.side>0), them=on.filter(x=>dn_?x.side>0:x.side<0);
  const K={"BOTH":`New ${dn_?"sellers":"buyers"} coming in AND the other side giving up - the strongest kind of ${w}.`,
    "NEW MONEY":`New money is behind it - this kind of ${w} can last.`,
    "FORCED OUT":`Mostly people being forced out (${dn_?"buyers selling":"sellers buying back"}) - fast but short: book profit early, do not enter late.`,
    "TIDE ONLY":"It is only following the market - weak on its own.",
    "OWN MOVE":"It is moving by itself with no proven big money - be careful."}[P.kind]||"No clear push yet - wait.";
  const strong=["BOTH","NEW MONEY","FORCED OUT"].includes(P.kind);
  const you=strong?(dn_?"This favours a PE (a bet on the fall). A CE (a bet on a rise) is against it.":"This favours a CE (a bet on the rise). A PE (a bet on a fall) is against it.")
    :"Not strong enough to trade on this alone.";
  const night=/TURNED BACK/.test(P.kline||"")?" It often turns back the next day - do not carry it.":/coin toss/.test(P.kline||"")?" Do not hold it overnight on this alone (the next day is about 50 / 50).":"";
  const li=(x,c)=>`<li class="${c}">${esc(x.t?ppSay(x,x.side>0):(PPW[x.k]||x.k)+(x.side>0?" are pushing it up.":" are pulling it down."))}</li>`;
  return `<div class="ppp"><b>IN SIMPLE WORDS - why it is ${dn_?"falling":"rising"}</b><ul>${mine.map(x=>li(x,dn_?"pd":"pu")).join("")}${them.map(x=>li(x,"am")).join("")}</ul>`
    +`${them.length?`<div class="am">${them.length} force${them.length>1?"s":""} the other way (orange) - watch ${them.length>1?"them":"it"}.</div>`:""}<div class="pv">${esc(K)}</div><div class="py">For you: ${esc(you+night)}</div></div>`; }
function shareInfo(){''', "ppSay() · ppPlain()", marker="/* patch 221: WHO IS PUSHING / PULLING - IN SIMPLE WORDS */")
rep('''${r.kline?` <span class="k">${esc(r.kline)}</span>`:""}</div>`; }''',
    '''${r.kline?` <span class="k">${esc(r.kline)}</span>`:""}${ppPlain({dir:r.dir,kind:r.kind,kline:r.kline,rows:r.up.map(k=>({k,on:true,side:1,t:""})).concat(r.dn.map(k=>({k,on:true,side:-1,t:""})))})}</div>`; }''',
    "the strip (quick reading): in simple words")
rep('''    ${P.kline?`<span class="k ${kc}">${esc(P.kline)}</span>`:`<span class="k dim">no clear push yet</span>`}
    <a onclick="PPO=!PPO;''', '''    ${P.kline?`<span class="k ${kc}">${esc(P.kline)}</span>`:`<span class="k dim">no clear push yet</span>`}
    ${ppPlain(P)}
    <a onclick="PPO=!PPO;''', "the strip (full reading): in simple words")
rep('''${PW.advice?`<br><span class="dim">${esc(PW.advice)}</span>`:""}''', '''${PW.advice?`<br><span class="dim">${esc(PW.advice)}</span>`:""}${ppPlain(PW)}''', "the share card's board: in simple words")
rep('''/* patch 211: alert rows that are links look the same */''', '''/* patch 221: in simple words */
.ppp{flex:1 1 100%;margin:4px 0 2px;padding:6px 9px;border-left:3px solid var(--amber);background:rgba(255,176,0,.06);border-radius:4px;font:500 13px/1.5 var(--ui)}
.ppp>b{display:block;font:700 10.5px var(--ui);letter-spacing:.08em;color:var(--amber);margin-bottom:2px}.ppp ul{margin:0;padding-left:18px}.ppp li{margin:1px 0}
.ppp li.pd{color:var(--dn)}.ppp li.pu{color:var(--up)}.ppp li.am,.ppp .am{color:var(--amber)}.ppp .pv{margin-top:4px;font-weight:700;color:var(--hi)}.ppp .py{font-weight:600}
/* patch 211: alert rows that are links look the same */''', "the look", marker="/* patch 221: in simple words */")
rep('''function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?(FLV.age_p<=120?`tick ${FLV.age_p}s ago`:`market closed · last price ${new Date(Date.now()-FLV.age_p*1000+19800000).toISOString().replace("T"," ").slice(5,16)}`):"on ticks"):(f.src||"");''',
    '''function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim";
  /* patch 221: in market hours an old tick is "this window is off live ticks", never "market closed" - and the price comes from the all-shares feed */
  const ist_=new Date(Date.now()+19800000), hm_=ist_.toISOString().slice(11,16), mkt_=ist_.getUTCDay()>0&&ist_.getUTCDay()<6&&hm_>="09:15"&&hm_<"15:30";
  const old_=FLV&&FLV.ok&&FLV.age_p!=null&&FLV.age_p>120, lq_=LQ[f.s]&&QT&&Date.now()/1000-QT<20?LQ[f.s]:null;
  const px=(old_&&mkt_&&lq_)?lq_[0]:((FLV&&FLV.px)||f.px); const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(old_&&mkt_&&lq_&&lq_[1]!=null)?lq_[1]:((px&&pcv)?(px/pcv-1)*100:f.chg);
  const at_=FLV&&FLV.age_p!=null?new Date(Date.now()-FLV.age_p*1000+19800000).toISOString().replace("T"," ").slice(5,16):"";
  const age=FLV&&FLV.ok?(FLV.age_p!=null?(FLV.age_p<=120?`tick ${FLV.age_p}s ago`:mkt_?`⚠ this window is off live ticks since ${at_.slice(6)} (GIR keeps 4 share windows live)${lq_?" · price from the all-shares feed, live":""}`:`market closed · last price ${at_}`):"on ticks"):(f.src||"");''', "the share window: off ticks in market hours, not \"market closed\"")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 221 in")
PY_PATCH
python3 $W/p221_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 221 done - reload GIR. Open any share: under WHO IS PUSHING / PULLING there is IN SIMPLE WORDS."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
