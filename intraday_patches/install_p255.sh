#!/bin/bash
# PATCH 255 - sort controls + times (Rama, 13 Nov). BIG MONEY · LINKED: tap a column (PRICE · FRESH ₹ · FUT OI · DELIVERY · SCORE · SHARE) =
#   high -> low, again = low -> high. F&O MONEY: each share shows "since 10:42 · last 13:31" - GIR's first and latest alert of that build-up today.
#   Tested in a browser. Page only - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 252" $D/home.html || { echo "patch 252 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p255_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p255_patch.py - PATCH 255: sort controls + times (Rama, 13 Nov: "for each list we need up and down control to have the highest and lowest value";
"here we need the time in each share - what time this investment or divestment happened").
  BIG MONEY · LINKED   tap a column (PRICE · FRESH ₹ · FUT OI · DELIVERY · SCORE · SHARE) = high -> low, again = low -> high (kept)
  F&O MONEY            each share: "since 10:42 · last 13:31" - GIR's first and latest alert of that build-up on the share today
Page only. Usage: python3 p255_patch.py DIR"""
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


rep('''setTimeout(()=>{ try{ LNKT=0; pullLink(); }catch(e){} },1500);''', '''setTimeout(()=>{ try{ LNKT=0; pullLink(); }catch(e){} },1500);
/* patch 255: BIG MONEY · LINKED - tap a column = high -> low, again = low -> high */
let LNKS={k:"",d:-1}; try{ LNKS=Object.assign(LNKS,JSON.parse(localStorage.getItem("gir_lnks")||"{}")); }catch(e){}
function lnkSort(k){ if(LNKS.k===k) LNKS.d=-LNKS.d; else { LNKS.k=k; LNKS.d=k==="s"?1:-1; } try{ localStorage.setItem("gir_lnks",JSON.stringify(LNKS)); }catch(e){} drawLink(); }
{ const dl1_=drawLink; drawLink=function(){ if(!LNK) return; const keep=LNK.rows;
    const val={s:x=>x.s,chg:x=>x.chg,cr:x=>x.cr,oi:x=>x.oi,dx:x=>x.dx,sc:x=>x.sc}[LNKS.k];
    if(val&&keep) LNK.rows=keep.slice().sort((a,b)=>{ const A=val(a),B=val(b); if(A==null&&B==null) return 0; if(A==null) return 1; if(B==null) return -1; return (A<B?-1:A>B?1:0)*LNKS.d; });
    try{ dl1_(); } finally{ LNK.rows=keep; }
    const keys=["s","chg","","cr","oi","dx","","sc",""];
    document.querySelectorAll("#mk-lnk table tr:first-child th").forEach((h,i)=>{ const k=keys[i]; if(!k) return; h.style.cursor="pointer"; h.title="tap = sort high → low, again = low → high";
      h.onclick=()=>lnkSort(k); if(LNKS.k===k) h.textContent+=LNKS.d<0?" ▼ HIGH→LOW":" ▲ LOW→HIGH"; }); }; }''', "BIG MONEY · LINKED: tap a column to sort")
rep('''function monQuad(M){''', '''function monT(s,b){   /* patch 255: when GIR alerted this build-up on the share today - the first and the latest */
  const L=((D&&D.now)||[]).filter(r=>{ const h=" "+(r.head||"")+" "; return h.includes(b)&&(h.includes(" "+s+" ")||h.includes(" "+s+"·")); }).map(r=>String(r.t||"").slice(0,5)).filter(Boolean).sort();
  return L.length?`<small class="dim" title="GIR's first and latest ${b.toLowerCase()} alert on ${s} today"> since ${L[0]}${L.length>1&&L[L.length-1]!==L[0]?" · last "+L[L.length-1]:""}</small>`:""; }
function monQuad(M){''', "monT(): the times")
rep('''<b>${esc(x.s)}${c}</b><span class="cr">''', '''<b>${esc(x.s)}${c}${monT(x.s,b)}</b><span class="cr">''', "F&O MONEY: the time on each share")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 255 in")
PY_PATCH
python3 $W/p255_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 255 done - reload GIR (Ctrl + Shift + R / pull down on the phone)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
