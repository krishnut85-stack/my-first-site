#!/bin/bash
# PATCH 293 - BIG MONEY: EVERY F&O SHARE (Rama, 15 Nov: "all the futures are not showing up here - better to have all the details").
#   moneylink.py cut the BIG MONEY table at 120 rows (patch 184); now every F&O share GIR has is in it (about 218). The order stays the same
#   (the strongest score first) and the filters stay (ALL · ▲ AGREE UP · ▼ AGREE DOWN · MIXED · FUTURES ONLY - the ALL button shows them all).
#   The live columns already come for every share (patch 278) - only a longer table, no extra load on GIR. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; F=$D/moneylink.py; TS=$(date +%m%d%H%M%S)
if grep -q "patch 293" $F 2>/dev/null; then echo "patch 293 - already in"; exit 0; fi
[ -f $F ] || { echo "moneylink.py not found - nothing done, send this to Claude"; exit 1; }
cp $F $F.bak$TS
back(){ cp $F.bak$TS $F; systemctl restart gir-dash 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
python3 - $F <<'PY_293' || back
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
A = '"rows": rows[:120],'
if s.count(A) != 1:
    print("❌ moneylink.py: the 120-row cut found %d times" % s.count(A)); sys.exit(1)
s = s.replace(A, '"rows": rows,                                             # patch 293: every F&O share (was the first 120)\n            ')
open(p, "w", encoding="utf-8").write(s)
print("  moneylink.py: the BIG MONEY table has every F&O share now (was 120)")
PY_293
cd $D && python3 -m py_compile moneylink.py || back
python3 - <<'PY_T' || back
import sys; sys.path.insert(0, "/home/globalbot/intraday")
import moneylink as M
fo = [{"s": "S%03d" % i, "chg": (i % 7) - 3, "bu": ("LONG BUILD-UP" if i % 2 else "SHORT BUILD-UP"), "cr": i, "oi": 2.0} for i in range(218)]
r = M.link(fo, ("2026-11-13", {}), {})
ok = len(r["rows"]) == 218 and r["n"] == 218
print("  %s the test: 218 made-up shares in -> %d rows out (was 120)" % ("✅" if ok else "❌", len(r["rows"])))
sys.exit(0 if ok else 1)
PY_T
systemctl restart gir-dash; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 293 done - B BIG MONEY: every F&O share (tap ALL above the table). Reload girtrader.com."
echo "   undo: cp $F.bak$TS $F; systemctl restart gir-dash"
