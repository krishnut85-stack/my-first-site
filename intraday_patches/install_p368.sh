#!/bin/bash
# PATCH 368 - SECTORS: BY SIZE or PLAIN AVERAGE (Rama, 17 Nov, GIR against Trendlyne at 09:52: REALTY +2.00% here, +0.53% there - "it has to
#   show the real picture ... the sector ranking is one of the main criteria for the share selection").
#   GIR's sector % is BY SIZE: every share of NSE's list weighted by the company's market value - what the money in the sector's big companies
#   (every F&O share is one) is doing. A site that averages all companies equally shows what the TYPICAL company is doing. Both are real; when
#   they disagree, the big names and the rest of the sector are going different ways - and that is worth seeing.
#   · the SECTORS box gets a switch: BY SIZE · PLAIN AVERAGE. PLAIN AVERAGE ranks the sectors by the simple average of their shares (the figure
#     seclive already computes and the tooltip already showed). The choice is remembered. The tooltip always shows both figures.
#   · the label at the right says which view is on. ROTATION, the candidates and the BOARD's sector desk stay BY SIZE (the tested rules used it).
#   Edits the patch-354 block in home.html (3 small places) and adds one small block. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 368" $D/home.html; then echo "patch 368 - already in"; exit 0; fi
grep -q "patch 354 + 354e" $D/home.html && grep -q "a plain average would say" $D/home.html || { echo "the patch-354 SECTORS block not found - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "❌ old page back - nothing changed"; exit 1; }
python3 - $D/home.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
E = (
 # the figures as they arrive: keep the by-size figure, show the plain average when that view is on
 ('if(v&&v.sectors) SL=v;',
  'if(v&&v.sectors){ SL=v; gxView(); }   /* patch 368 */'),
 ('let SL=null, busy=false;',
  'let SL=null, busy=false;\n  /* patch 368: BY SIZE or PLAIN AVERAGE - wchg keeps the size-weighted figure, chg is the one shown and ranked */\n'
  '  function gxView(){ try{ const avg=window.GXSECAVG; (SL&&SL.sectors||[]).forEach(x=>{ if(x.wchg==null) x.wchg=x.chg; x.chg=(avg&&x.eqw!=null)?x.eqw:x.wchg; }); }catch(e){} }\n'
  '  window.gxSecMode=m=>{ window.GXSECAVG=!!m; try{ localStorage.setItem("gir_secavg",m?"1":"0"); }catch(e){} gxView(); try{ paint(); }catch(e){} };'),
 # the switch in the SORT bar
 ('''<a class="${so==="az"?"on":""}" onclick="ssSet('az')">A–Z</a>`+''',
  '''<a class="${so==="az"?"on":""}" onclick="ssSet('az')">A–Z</a><a class="${window.GXSECAVG?"":"on"}" onclick="gxSecMode(0)" title="each share counts by its company's market value - what the money in the big companies is doing (the F&O shares are among them)">BY SIZE</a><a class="${window.GXSECAVG?"on":""}" onclick="gxSecMode(1)" title="every share counts the same - what the typical company of the sector is doing">PLAIN AVERAGE</a>`+'''),
 ('ALL ${SL.shares} · WEIGHTED · ${E(SL.at)}</span></div>`+',
  'ALL ${SL.shares} · ${window.GXSECAVG?"PLAIN AVERAGE":"WEIGHTED"} · ${E(SL.at)}</span></div>`+'),
 # the tooltip: both figures, whichever view is on
 ('${pc(x.chg)} - all its ${x.n} NSE shares, size-weighted (a plain average would say ${pc(x.eqw)})',
  '${pc(x.wchg!=null?x.wchg:x.chg)} by size · ${pc(x.eqw)} as a plain average - all its ${x.n} NSE shares'))
for a, b in E:
    if t.count(a) != 1:
        print("❌ home.html: %r found %d times" % (a[:60], t.count(a))); sys.exit(1)
    t = t.replace(a, b)
add = '<script>/* patch 368: the SECTORS view chosen last time (BY SIZE unless PLAIN AVERAGE was picked) */\ntry{ window.GXSECAVG=localStorage.getItem("gir_secavg")==="1"; }catch(e){ window.GXSECAVG=false; }\n</script>'
i = t.find("patch 354 + 354e"); j = t.rfind("<script>", 0, i)
if i < 0 or j < 0:
    print("❌ home.html: the patch-354 script not found"); sys.exit(1)
t = t[:j] + add + "\n" + t[j:]
open(p, "w", encoding="utf-8").write(t); print("  home.html: SECTORS - BY SIZE · PLAIN AVERAGE")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 368 done - refresh GIR (Ctrl+Shift+R): the SECTORS box has BY SIZE · PLAIN AVERAGE next to the sort buttons."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash"
