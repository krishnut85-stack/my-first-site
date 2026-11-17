#!/bin/bash
# PATCH 367 - THREE FIXES FROM THE 17 NOV SESSION
#   1) A CLICK THAT IS NOT LOST (Rama, 09:31: "the cursor sensitivity is very low - if I click TEXTILES it is going to REALTY"). The live lists are
#      redrawn several times a second; when a redraw falls between pressing and releasing the mouse button the browser drops the click, or the
#      row under the pointer has changed. Now the row pressed is remembered: if its click did not arrive - or arrived on another row - the action
#      of the row that was PRESSED is done (a sector's shares · a share's trading screen). Mouse only; touch taps are unchanged.
#   2) THE SECTORS HEADER BACK TO ONE LINE: the two buttons are now short - 🧭 WHY and 💰 MONEY (their full names show on hover) - so the list
#      gets its rows back.
#   3) THE MORNING LEVELS BEFORE THE OPEN, AND GENTLER (17 Nov 09:18-09:21: Kite refused "Too many requests" for ETERNAL and MPHASIS - patch 361
#      had doubled that fetch): seccand.py now fetches between 08:45 and 09:13 (only if that did not happen: after 09:22), at half the speed,
#      waits out a refusal and asks again, and logs how many shares it could not read. seclive.py calls it while the market is closed.
#   Replaces seccand.py and seclive.py, edits home.html. Restarts the sector reader and the dashboard.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 367" $D/home.html && grep -q "def prefetch" $D/seccand.py && grep -q "seccand.prefetch" $D/seclive.py; then echo "patch 367 - already in"; exit 0; fi
grep -q "find_gapday" $D/seccand.py && grep -q "</body>" $D/home.html && systemctl is-active --quiet gir-seclive || { echo "patch 361 / the page / gir-seclive not found - nothing done"; exit 1; }
for f in seccand.py seclive.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "def prefetch" $W/seccand.py && grep -q "seccand.prefetch" $W/seclive.py && python3 -m py_compile $W/seccand.py $W/seclive.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/seccand.py $D/seccand.py.bak367; cp $D/seclive.py $D/seclive.py.bak367
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak367 $D/seccand.py; cp $D/seclive.py.bak367 $D/seclive.py; systemctl restart gir-seclive gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cp $W/seccand.py $D/seccand.py && cp $W/seclive.py $D/seclive.py || back
cat > $W/home_add.html <<'ADD_367'
<style>/* patch 367: the SECTORS header on ONE line again - its note is cut with … to make room for the two short buttons (laptop / iPad; the phone keeps its wrap) */
@media (min-width:701px){#q-don h3{display:flex;align-items:center;gap:6px;white-space:nowrap;overflow:hidden}#q-don h3>span{flex:1 1 auto;min-width:0;overflow:hidden;text-overflow:ellipsis}#q-don h3>button{flex:none;margin-left:0}}
</style>
<script>/* patch 367 (Rama, 17 Nov 09:31: "if I click TEXTILES it is going to REALTY"): the live lists are redrawn several times a second - a redraw
   between pressing and releasing the mouse button drops the click, or puts another row under the pointer. The row PRESSED is remembered; if its
   own click did not arrive, its action is done: a sector's shares (mkSec) · a share's trading screen (mkOpen / focusOn). Mouse only. */
(function(){
  const RX=/(mkSec|mkOpen|focusOn)\('([^']{1,40})'\)/; let dn=null;
  const act=t=>{ for(let e=t,i=0;e&&e.getAttribute&&i<7;e=e.parentElement,i++){ const a=e.getAttribute("onclick"), m=a&&RX.exec(a); if(m) return m[1]+"|"+m[2]; } return ""; };
  document.addEventListener("pointerdown",e=>{ dn=null; if(e.pointerType!=="mouse"||e.button!==0) return; const k=act(e.target); if(k) dn={k,t:Date.now(),x:e.clientX,y:e.clientY,done:false}; },true);
  document.addEventListener("click",e=>{ const d=dn; if(!d||Date.now()-d.t>1500) return; const k=act(e.target);
    if(k===d.k) d.done=true;                                                   /* the click reached the row that was pressed */
    else if(k&&k.split("|")[0]===d.k.split("|")[0]){ e.stopPropagation(); e.preventDefault(); } },true);   /* it reached ANOTHER row of the same list: not that one */
  document.addEventListener("pointerup",e=>{ const d=dn; if(!d||e.pointerType!=="mouse") return;
    if(Date.now()-d.t>1200||Math.abs(e.clientX-d.x)>8||Math.abs(e.clientY-d.y)>8){ dn=null; return; }       /* a drag or a long hold is not a click */
    setTimeout(()=>{ if(!d.done){ const p=d.k.split("|"); try{ if(typeof window[p[0]]==="function") window[p[0]](p[1]); }catch(x){} } if(dn===d) dn=null; },70); },true);
})();
</script>
ADD_367
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
if "patch 367" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    t = t.replace("</body>", open(sys.argv[2], encoding="utf-8").read().strip() + "\n</body>", 1); print("  home.html: a pressed row's click is not lost")
E = (('const t="🧭 WHO & WHY"+(V&&V.day?" · "+dm(V.day):""); if(b.textContent!==t) b.textContent=t; }',
      'const t="🧭 WHY"; if(b.textContent!==t) b.textContent=t; b.title="WHO & WHY"+(V&&V.day?" · the reading of "+dm(V.day):"")+" - who pushed each sector, the news after the close, foreign funds by sector"; }'),
     ('b.textContent="💰 SECTOR MONEY";', 'b.textContent="💰 MONEY"; b.title="SECTOR MONEY - investment and disinvestment, every sector on one board";'))
n = 0
for a, b in E:
    if t.count(a) == 1:
        t = t.replace(a, b); n += 1
print("  home.html: the SECTORS header buttons made short (%d of 2%s)" % (n, "" if n == 2 else " - a button of patch 356 / 360 is not on this page"))
open(p, "w", encoding="utf-8").write(t)
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && python3 -c "import seccand; print('  seccand: the morning levels 08:45-09:13, pause %.2fs a call · checks' % seccand.GAP_S, ', '.join(t for t, k in seccand.TRIG))" || back
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-seclive: $(systemctl is-active gir-seclive)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-seclive)" = "active" ] || back
echo "✅ patch 367 done - refresh GIR (Ctrl+Shift+R). Tomorrow's log line to look for (data/seclive.log, about 08:50): 'seccand levels: N shares read ... Kite refusals waited out: 0'"
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak367 $D/seccand.py; cp $D/seclive.py.bak367 $D/seclive.py; systemctl restart gir-seclive gir-dash"
