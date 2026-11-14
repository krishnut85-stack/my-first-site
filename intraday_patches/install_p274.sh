#!/bin/bash
# PATCH 274 - A SHARE'S OWN TAB IN ONE VIEW (Rama, 14 Nov: "a lot of space next to the GIR icon - the share's name, price and sector go next to GIR; who is
#   pulling and why it is moving short and sweet, side by side on top of the charts; everything fits on the page, no scrolling").
#   top bar: ⌂ GIR · the share · ₹ price · % · the last reading · its sector · "▾ details" (why it moves · the OI battle · the desk's lines - a panel
#   that opens over the page, ✕ closes it) · under it: WHO IS PUSHING / PULLING (left) and IN SIMPLE WORDS - why (right) · the four panels fill the
#   rest of the screen (each scrolls inside itself). "no desk reading yet" is not shown. Laptop / desktop only - the phone is unchanged.
#   Tested in a browser at 1536 x 864: no page scroll. home.html only - restarts the page server; after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 257" $D/home.html || { echo "patch 257 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p274_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p274_patch.py - patch 274: a share's own tab in one view (home.html only).  python3 p274_patch.py DIR CSS JS"""
import os, sys
D = sys.argv[1]; CSS = open(sys.argv[2], encoding="utf-8").read(); JS = open(sys.argv[3], encoding="utf-8").read()
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 274" in s:
    print("  home.html: patch 274 - already in"); sys.exit(0)
A = "/* patch 221: WHO IS PUSHING / PULLING - IN SIMPLE WORDS */"
for o, n, tag in (("</style>", CSS + "</style>", "the one-view look"), (A, JS + A, "the head next to ⌂ GIR · details behind one button · the panels fill the screen")):
    if s.count(o) != 1:
        print("❌ home.html: anchor for '%s' found %d times" % (tag, s.count(o))); sys.exit(1)
    s = s.replace(o, n); print("  home.html: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("patch 274 in")
PY_PATCH
cat > $W/p274.css <<'PY_CSS'
/* patch 274: a share's own tab in ONE view - name / price / sector next to ⌂ GIR · WHO and WHY side by side, short · the panels fill the rest, no page scroll */
@media(min-width:900px){
  body.solo #soloBar{gap:12px;padding:4px 10px;min-height:46px;box-sizing:border-box}
  body.solo #soloBar .t{display:none}
  body.solo #soloHd{display:flex;align-items:center;gap:12px;flex:1 1 auto;min-width:0;overflow:hidden;white-space:nowrap}
  body.solo #soloHd .hm,body.solo #soloHd .am{display:none}
  body.solo #soloHd>b{font:700 22px/1 var(--ui);letter-spacing:.02em;color:#F2F5F9}
  body.solo #soloHd .px{font:600 20px/1 var(--mono)}
  body.solo #soloHd .dim{font-size:11px;overflow:hidden;text-overflow:ellipsis}
  body.solo #soloHd .sct{font-size:12px;padding:4px 10px;border:1px solid #1C2433;border-radius:999px;background:#121826;overflow:hidden;text-overflow:ellipsis;margin-left:0}
  body.solo #soloMore{margin-left:auto;cursor:pointer;white-space:nowrap;font:600 12px var(--ui);color:var(--amber);border:1px solid #3A2D12;border-radius:6px;padding:6px 10px;user-select:none}
  body.solo #soloMore:hover{background:#17130A}
  body.solo #focus{padding-bottom:0 !important;overflow:hidden !important}
  body.solo #focus>.hd{display:none !important}
  body.solo #focus>.m.soloNo{display:none !important}
  body.solo #focus>.m{padding:6px 12px !important;font-size:13px !important;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  body.solo #focus>#ppStrip{margin:8px 16px 0 !important}
  body.solo #focus .pps{display:grid !important;grid-template-columns:minmax(0,1fr) minmax(0,1.15fr);column-gap:18px;row-gap:3px;align-items:start;padding:8px 12px !important;font-size:12.5px !important}
  body.solo #focus .pps>*{grid-column:1}
  body.solo #focus .pps>.ppp{grid-column:2;grid-row:1/span 9;margin:0;padding:6px 10px !important;font-size:12.5px !important;line-height:1.35}
  body.solo #focus .pps .k{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
  body.solo #focus .ppp ul{margin:2px 0 2px 16px;padding:0}
  body.solo #focus .ppp .pv,body.solo #focus .ppp .py{margin-top:2px}
  body.solo #focus .ws{padding:8px 16px 0 !important}
  body.solo:not(.soloMore) #wsDesk{display:none !important}
  body.solo.soloMore #wsDesk{display:block !important;position:fixed;right:12px;top:52px;bottom:40px;width:min(800px,58vw);overflow:auto;z-index:40;background:#0D121B;border:1px solid var(--amber);border-radius:10px;padding:8px 12px !important;box-shadow:0 10px 40px rgba(0,0,0,.65)}
}
PY_CSS
cat > $W/p274.js <<'PY_JS274'
/* patch 274: a share's own tab in ONE view - the head next to ⌂ GIR, the details (why it moves · the OI battle) behind one button, the panels fill the screen */
function soloFit(){ if(!SOLO||!document.body.classList.contains("solo")||window.innerWidth<900) return false;
  const F=$("focus"), sb=$("soloBar"); if(!F||!sb) return false;
  let sh=$("soloHd"); if(!sh){ sh=document.createElement("div"); sh.id="soloHd"; sb.appendChild(sh); }
  let mb=$("soloMore"); if(!mb){ mb=document.createElement("a"); mb.id="soloMore"; mb.title="why it is moving · the OI battle · the desk's lines"; mb.onclick=()=>{ document.body.classList.toggle("soloMore"); soloFit(); }; sb.appendChild(mb); }
  const hd=F.querySelector(".hd"); if(hd){ const h=hd.innerHTML; if(sh._h!==h){ sh._h=h; sh.innerHTML=h; } }
  mb.textContent=document.body.classList.contains("soloMore")?"✕ close the details":"▾ details: why it moves · OI battle";
  const m=F.querySelector(":scope>.m"); if(m) m.classList.toggle("soloNo",/^no desk reading yet/.test((m.textContent||"").trim()));
  const ws=F.querySelector(".ws"); if(!ws) return false;
  const tick=($("tick")&&$("tick").offsetHeight)||30, top=ws.getBoundingClientRect().top;
  const h=Math.max(360,Math.floor(window.innerHeight-top-tick-6)), old=parseInt(ws.style.height||"0",10);
  if(Math.abs(h-old)>12){ ws.style.height=h+"px"; return true; }
  return false; }
(function(){ const _paint=paint; let busy=false;
  paint=function(){ const r=_paint.apply(this,arguments); if(!busy){ try{ busy=true; if(soloFit()) _paint.apply(this,arguments); }catch(e){} finally{ busy=false; } } return r; };
  window.addEventListener("resize",()=>{ try{ if(soloFit()) paint(); }catch(e){} }); })();
PY_JS274
python3 $W/p274_patch.py $D $W/p274.css $W/p274.js || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash; sleep 4
echo "  gir-dash: $(systemctl is-active gir-dash)"
echo "✅ patch 274 done - open any share's tab and press Ctrl + Shift + R: name / price / sector next to ⌂ GIR, WHO and WHY side by side, no scrolling; ▾ details for the rest."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash"
