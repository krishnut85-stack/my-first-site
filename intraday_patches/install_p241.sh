#!/bin/bash
# PATCH 241 - SECTORS and ROTATION show the same number; ROTATION fits its box (Rama, 13 Nov: "why is the sectors % different from the
#   rotation %? and sector rotation is barely visible").
#   Why: SECTORS showed an NSE index where one was mapped - INSURANCE and NBFC both showed NIFTY FIN SERVICE (mostly HDFC Bank / ICICI Bank)
#   = +1.42%, while the 7 insurance F&O shares averaged +2.63% (ROTATION). Now both show the F&O shares' average; the NSE index appears on
#   hover only where it really is the group (stand-ins removed). ROTATION on the laptop: MONEY IN | MONEY OUT side by side, one line a
#   sector (name · % · how many up · top share; all leaders + laggards on hover); wide screens show all leaders.
#   Tested in a browser at 1920, 1366, 1280, 1150, 1000 and phone width. Page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 240" $D/home.html || { echo "patch 240 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p241_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p241_patch.py - PATCH 241: SECTORS and ROTATION show the same number; ROTATION fits its box (Rama, 13 Nov: "look at the sectors percentage and
the rotation percentage - why is it different; and sector rotation is barely visible").
  why different  SECTORS showed an NSE index where one was mapped - and some were stand-ins, not the group: INSURANCE and NBFC both showed
                 NIFTY FIN SERVICE (mostly HDFC Bank / ICICI Bank) = +1.42%, while the 7 insurance F&O shares averaged +2.63%. ROTATION
                 always used the group's F&O shares. Now both use the F&O shares' average (the shares you can trade); the NSE index is shown on
                 hover only where it really is the group (Bank, IT, Auto, Realty, Metal, FMCG, Pharma, Oil & Gas, Capital Markets ...);
                 the stand-ins (Fin Services for NBFC / Insurance, Energy for Power, Infra for Construction, Commodities for Cement,
                 Consumption, Services, India Manufacturing for Capital Goods) are gone
  visible        on the laptop: MONEY IN and MONEY OUT side by side, one line a sector (name · % · how many up · its top share; all leaders and the laggards on hover), the window
                 buttons on one line; "still lagging" moves to the hover
Page only. Usage: python3 p241_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); S = {"s": open(p, encoding="utf-8").read()}
ERR = []


def rep(old, new, tag):
    s = S["s"]
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  home.html: %s" % tag)


rep('''const SIDX_MAP=[[/CAPITAL M/,"NIFTY CAPITAL MKT"],[/CAPITAL G/,"NIFTY INDIA MFG"],[/^BANK/,"NIFTY BANK"],[/NBFC|FINANC/,"NIFTY FIN SERVICE"],[/INSUR/,"NIFTY FIN SERVICE"],[/^IT\\b|TECHNOLOG/,"NIFTY IT"],
  [/HEALTH|PHARMA/,"NIFTY HEALTHCARE"],[/AUTO/,"NIFTY AUTO"],[/FMCG/,"NIFTY FMCG"],[/METAL|MINING/,"NIFTY METAL"],[/OIL|GAS/,"NIFTY OIL AND GAS"],[/POWER|ENERGY/,"NIFTY ENERGY"],
  [/CEMENT|MATERIAL/,"NIFTY COMMODITIES"],[/CONSTRUCT|INFRA/,"NIFTY INFRA"],[/REALTY/,"NIFTY REALTY"],[/CONSUMER D/,"NIFTY CONSR DURBL"],[/CONSUMER S/,"NIFTY CONSUMPTION"],
  [/CHEMICAL/,"NIFTY CHEMICALS"],[/MEDIA/,"NIFTY MEDIA"],[/SERVICES/,"NIFTY SERV SECTOR"]];''',
    '''const SIDX_MAP=[[/CAPITAL M/,"NIFTY CAPITAL MKT"],[/^BANK/,"NIFTY BANK"],[/^IT\\b|TECHNOLOG/,"NIFTY IT"],   /* patch 241: only indices that ARE the group - no stand-ins */
  [/HEALTH|PHARMA/,"NIFTY HEALTHCARE"],[/AUTO/,"NIFTY AUTO"],[/FMCG/,"NIFTY FMCG"],[/METAL|MINING/,"NIFTY METAL"],[/OIL|GAS/,"NIFTY OIL AND GAS"],
  [/REALTY/,"NIFTY REALTY"],[/CONSUMER D/,"NIFTY CONSR DURBL"],[/CHEMICAL/,"NIFTY CHEMICALS"],[/MEDIA/,"NIFTY MEDIA"]];''', "sector indices: only true matches")
rep('''return {name:x.name,n:x.n,v:ic!=null?ic:x.chg,f:ic==null}; })''',
    '''return {name:x.name,n:x.n,v:x.chg!=null?x.chg:ic,f:x.chg!=null,ic}; })   /* patch 241: the F&O shares' average - the same number as ROTATION */''',
    "SECTORS = the F&O shares' average")
rep('''title="${esc(x.name)} · ${x.n} F&amp;O shares · ${x.f?"no NSE index - its F&amp;O shares' average":"NSE's index"}"''',
    '''title="${esc(x.name)} · the average of its ${x.n} F&amp;O shares${x.ic!=null&&x.f?` · NSE's index ${x.ic>0?"+":""}${x.ic.toFixed(2)}%`:""}${x.f?"":" · NSE's index (no share prices yet)"}"''',
    "SECTORS hover: the index where it is the group")
rep('''    return `<div class="rg"><span class="nm">${esc(g.n)}</span>${f(g.avg)}<small>${side>0?Math.round(g.up*100)+"% up":Math.round(g.dn*100)+"% down"} of ${g.cc.length}</small>''',
    '''    const nu_=Math.round((side>0?g.up:g.dn)*g.cc.length), tt_=`${g.n}: ${nu_} of ${g.cc.length} F&O shares ${side>0?"up":"down"}${lead.length?` · ${side>0?"leading":"weakest"}: ${lead.map(c=>c[1]+" "+(c[0]>0?"+":"")+c[0].toFixed(2)+"%").join(", ")}`:""}${g.ic!=null?` · NSE's index ${g.ic>0?"+":""}${g.ic.toFixed(2)}%`:""}${lag.length?` · ${side>0?"still lagging (the CE watch)":"still holding up (the PE watch)"}: ${lag.map(c=>c[1]+" "+(c[0]>0?"+":"")+c[0].toFixed(2)+"%").join(", ")}`:""}`;   /* patch 241 */
    return `<div class="rg" title="${esc(tt_)}"><span class="nm">${esc(g.n)}</span>${f(g.avg)}<small>${nu_} of ${g.cc.length} ${side>0?"up":"down"}</small>''', "ROTATION row: count + hover detail")
rep('''${lag.length?`<br><small>${side>0?"still lagging - the CE watch":"still holding up - the PE watch"}:</small> ${sh(lag)}`:""}</span></div>`; };''',
    '''${lag.length?`<span class="lg"><br><small>${side>0?"still lagging - the CE watch":"still holding up - the PE watch"}:</small> ${sh(lag)}</span>`:""}</span></div>`; };''', "ROTATION: lagging part marked")
rep('''<small>${x.n}</small>${x.f?"<i>F&amp;O</i>":""}</span>''', '''<small>${x.n}</small>${x.f?"":"<i>INDEX</i>"}</span>''', "SECTORS: no F&O tag on every row (INDEX only when no prices yet)")
rep('''<span>% today · size = F&amp;O shares · tap = its shares</span>''', '''<span>% today = the average of its F&amp;O shares (as ROTATION) · tap = its shares</span>''', "SECTORS header says what the % is")
rep('''</style>''', '''/* patch 241: ROTATION fits its box on the laptop - MONEY IN | MONEY OUT side by side, one line a sector */
@media(min-width:1100px){
  #q-rot .rt{flex-wrap:nowrap;padding:2px 8px}#q-rot .rt a{padding:0 7px;font-size:11px}#q-rot .rt small{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0;flex:1}
  #q-rot .rs{padding:2px 8px;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  #q-rot .rc{grid-template-columns:1fr 1fr !important}#q-rot .rc>div{padding:1px 6px;min-width:0}#q-rot h4{margin:1px 0 1px;font-size:10px}
  #q-rot .rg{grid-template-columns:minmax(0,7.6em) 4.3em 4.6em minmax(0,1fr) !important;gap:0 6px !important;padding:0;white-space:nowrap;line-height:1.4}
  #q-rot .rg .nm{overflow:hidden;text-overflow:ellipsis}#q-rot .rg .ix,#q-rot .rg .lg{display:none !important}
  #q-rot .rg .sh{grid-column:auto !important;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:0}#q-rot .rg .sh a{font-size:11.5px;display:inline !important;margin-right:6px}#q-rot .rg .sh small{font-size:11px}
  #q-rot .ra{padding:2px 8px}
}
@media(min-width:1100px) and (max-width:1599px){#q-rot .rg .sh a~a,#q-rot .rg .sh a span{display:none !important}}   /* laptop: its top share; all on hover */
@media(min-width:1600px){#q-rot .rg{grid-template-columns:minmax(0,11em) 4.3em 4.6em minmax(0,1fr) !important}}
</style>''', "ROTATION laptop layout")
rep('''MKH("mk-rot").innerHTML=`${tb}<div class="rs">${st}</div>''', '''MKH("mk-rot").innerHTML=`${tb}<div class="rs" title="${esc(st.replace(/<[^>]+>/g,""))}">${st}</div>''', "ROTATION status: full text on hover")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 241 in")
PY_PATCH
python3 $W/p241_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 241 done - reload every GIR tab (Ctrl + Shift + R)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
