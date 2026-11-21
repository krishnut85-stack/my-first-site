#!/bin/bash
# PATCH 300 - THE OI BATTLE IN 2 LINES (Rama, 15 Nov: "this is what I was telling for the OI battle - too much information, before I read it the
#   reaction will finish"). On a share's page the OI BATTLE box is now:
#     🧱 OI BATTLE · expiry 11-23  BULLISH · roof 32000 (1.1% up) · floor 30000 (5.3% down)
#     ▲ CE if it holds over 32000 → towards the next wall 33000 · ▼ PE if it stalls under 32000 → back towards the floor 30000
#   and everything that was there before is under "why - the details" (tap to open). Page file only (home.html) + the dashboard restarted.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 300" $F; then echo "patch 300 - already in"; exit 0; fi
cp $F $F.bak$TS
back(){ cp $F.bak$TS $F; systemctl restart gir-dash 2>/dev/null; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/old.txt <<'OLD_300'
  const batH=BT?`<div style="grid-column:1/-1"><small>THE OI BATTLE · ${esc(BT.day||"")} · expiry ${esc(String(BT.exp||"").slice(5))} · writers = mostly the big money</small><b class="${BT.verdict==="BULLISH"?"pu":BT.verdict==="BEARISH"?"pd":"am"}">${esc(BT.verdict)}</b> <span class="dim">price ${BT.spot} · ceiling ${BT.ceil} · floor ${BT.floor}</span><br>${(BT.lines||[]).map(x=>"· "+esc(x)).join("<br>")}<br><b class="pu">BREAKOUT</b> ${esc(BT.breakout.confirm)} → ${esc(BT.breakout.then)}<br><b class="pd">REJECTION</b> ${esc(BT.rejection.confirm)} → ${esc(BT.rejection.then)}</div>`:"";
OLD_300
cat > $W/new.txt <<'NEW_300'
  const batH=BT?(()=>{ const sp=+BT.spot, c=+BT.ceil, f=+BT.floor, cu=(c&&sp)?((c/sp-1)*100).toFixed(1):"?", fd=(f&&sp)?((1-f/sp)*100).toFixed(1):"?", cut=t=>String(t||"").replace(/^(CE|PE)\s*-\s*/,"").replace(/\s*\((CE|PE)\)\s*$/,"");   /* patch 300: 2 lines, the details folded */
    return `<div style="grid-column:1/-1"><small>🧱 OI BATTLE · expiry ${esc(String(BT.exp||"").slice(5))}</small> <b class="${BT.verdict==="BULLISH"?"pu":BT.verdict==="BEARISH"?"pd":"am"}">${esc(BT.verdict)}</b> · roof <b>${esc(c)}</b> <span class="dim">(${cu}% up)</span> · floor <b>${esc(f)}</b> <span class="dim">(${fd}% down)</span><br><b class="pu">▲ CE</b> if it holds over ${esc(c)} <span class="dim">→ ${esc(cut(BT.breakout.then))}</span> · <b class="pd">▼ PE</b> if it stalls under ${esc(c)} <span class="dim">→ ${esc(cut(BT.rejection.then))}</span><details style="margin-top:3px"><summary class="dim" style="cursor:pointer">why - the details</summary><span class="dim">${esc(BT.day||"")} · writers = mostly the big money · price ${esc(BT.spot)}</span><br>${(BT.lines||[]).map(x=>"· "+esc(x)).join("<br>")}<br><b class="pu">BREAKOUT</b> ${esc(BT.breakout.confirm)} → ${esc(BT.breakout.then)}<br><b class="pd">REJECTION</b> ${esc(BT.rejection.confirm)} → ${esc(BT.rejection.then)}</details></div>`; })():"";
NEW_300
python3 - $F $W/old.txt $W/new.txt <<'PY_300' || back
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
old = open(sys.argv[2], encoding="utf-8").read().rstrip("\n"); new = open(sys.argv[3], encoding="utf-8").read().rstrip("\n")
if s.count(old) != 1:
    print("❌ home.html: the OI BATTLE box (patch 135) found %d times - nothing changed, send this to Claude" % s.count(old)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("  home.html: the OI BATTLE box in 2 lines, the details folded")
PY_300
if command -v node >/dev/null 2>&1; then
  python3 - $F $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 300 done - the OI BATTLE in 2 lines (roof / floor / CE or PE), the details folded. Laptop: Ctrl + Shift + R."
echo "   undo: cp $F.bak$TS $F; systemctl restart gir-dash"
