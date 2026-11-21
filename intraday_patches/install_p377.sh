#!/bin/bash
# PATCH 377 - ONE SECTOR MAP, AND THE MOVERS LIST'S OI FROM ALL MONTHS (the cross-check, 17 Nov 14:40, on the live server: 25 F&O shares in one
#   sector in the SECTORS box and another in the movers filter - pharma / hospitals against "healthcare", electronics against consumer durables /
#   capital goods, telecom services against "telecom"; and BLUESTARCO, IDEA, JUBLFOOD, MAZDOCK "LONG UNWINDING" in the movers list against
#   "SHORT BUILD-UP" over all months).
#   · nsesec.page_map() - the page's sector list, the movers filter and everything built on them - now gives each share the SAME sector as the
#     SECTORS box (seclive.refine: hospitals & diagnostics / pharma, electronics & hardware, telecom services / equipment)
#   · the movers list: the OI % and the LB / SB / SC / LU word come from FUTURES BY MONTH (all months together, a mismatched near month left out)
#     when it is live - in the week before expiry the near month alone falls as positions roll to December and was read as "long unwinding".
#     The near-month figure stays in the tooltip.
#   Edits nsesec.py and home.html. Restarts the dashboard and the heads-up (they read the sector list). After 15:35.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 377" $D/nsesec.py && grep -q "patch 377" $D/home.html; then echo "patch 377 - already in"; exit 0; fi
grep -q "def page_map" $D/nsesec.py && grep -q "def refine" $D/seclive.py && grep -q "function overlayQ" $D/home.html || { echo "nsesec.page_map / seclive.refine / the movers list not found - nothing done"; exit 1; }
cp $D/nsesec.py $D/nsesec.py.bak$TS; cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/nsesec.py.bak$TS $D/nsesec.py; cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; systemctl is-active --quiet gir-headsup && systemctl restart gir-headsup; echo "❌ old files back - nothing changed"; exit 1; }
python3 - $D/nsesec.py <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
a = "        m.setdefault(sector_of(s, nse, hand, names), []).append(s)\n"
b = ("        sec_ = sector_of(s, nse, hand, names)\n"
     "        try:                                                    # patch 377: the same sector as the SECTORS box (seclive.refine)\n"
     "            import seclive as _sl\n"
     "            sec_ = _sl.refine(s, sec_, (names or {}).get(s, \"\"))\n"
     "        except Exception:\n"
     "            pass\n"
     "        m.setdefault(sec_, []).append(s)\n")
if t.count(a) != 1:
    print("❌ nsesec.py: page_map's line found %d times - nothing changed" % t.count(a)); sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(a, b)); print("  nsesec.py: page_map gives the SECTORS box's sector")
PY_EDIT
cd $D && python3 -m py_compile nsesec.py || back
timeout 90 python3 - <<'PY_CHECK' || back
import sys, os
sys.path.insert(0, os.getcwd())
import nsesec, seclive
SEC, _ = seclive.universe(); FO = seclive.fo_set()
pm = nsesec.page_map(sorted(FO)); PS = {s: k for k, v in pm.items() for s in v}
bad = [(s, SEC.get(s), PS.get(s)) for s in FO if SEC.get(s) and PS.get(s) and SEC[s] != PS[s]]
print("  the F&O shares: %d · the same sector in both places: %d · different: %d" % (len(FO), len(FO) - len(bad), len(bad)))
for b in bad[:8]:
    print("   still different: %s %s / %s" % b)
sys.exit(1 if len(bad) > 3 else 0)
PY_CHECK
cat > $W/oi.html <<'OI'
<script>/* patch 377: the movers list's OI % and build-up word from FUTURES BY MONTH (all months; a mismatched near month left out) when it is live */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let FX=null;
  async function pull(){ if(document.hidden) return; try{ const r=await fetch("futx?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ const v=await r.json(); if(v&&v.rows&&v.src==="live") FX=v; } }catch(e){} }
  function apply(){ if(!FX||!FX.rows||typeof TAPE==="undefined") return; for(const r of (TAPE||[])){ const f=FX.rows[r.s]; if(!f||!f.total||f.total.pc==null) continue;
      if(r.foi_near===undefined) r.foi_near=r.foi; if(r.bu_near===undefined) r.bu_near=r.bu;
      r.foi=f.total.pc; if(f.bu) r.bu=f.bu; r.oi_src="all months"+(f.odd?" (near month left out - data mismatch)":"")+(f.rollover?" · rollover":""); } }
  if(typeof overlayQ==="function"){ const O=overlayQ; overlayQ=function(){ const x=O.apply(this,arguments); try{ apply(); }catch(e){} return x; }; }
  setTimeout(pull,2500); setInterval(pull,30000);
})();
</script>
OI
python3 - $D/home.html $W/oi.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); i = t.rfind("</body>")
if i < 0:
    print("❌ home.html: </body> not found"); sys.exit(1)
open(p, "w", encoding="utf-8").write(t[:i] + open(sys.argv[2], encoding="utf-8").read() + t[i:]); print("  home.html: the movers list's OI from all months")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; systemctl is-active --quiet gir-headsup && systemctl restart gir-headsup; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-headsup: $(systemctl is-active gir-headsup)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
[ -f $D/crosscheck.py ] && (cd $D && timeout 200 nice -n 15 python3 crosscheck.py | grep -E "C2|C3" | head -8 | sed 's/^/   /')
echo "✅ patch 377 done - refresh GIR (Ctrl+Shift+R). The movers filter uses the SECTORS box's sectors; its OI % and LB / SB words are all months."
echo "   undo: cp $D/nsesec.py.bak$TS $D/nsesec.py; cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash gir-headsup"
