#!/bin/bash
# PATCH 195b - today's AI limit and the credit count use only the dollars GIR recorded itself. On 11 Nov the Sonnet calls made
#   before patch 193 ($2.80) were counted against the new $1 limit, so from 19:06 GIR stopped asking Claude, and --balance 4.80
#   showed $7.60. Fixes both, keeps your --balance amount, restarts the news programs (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
cp $D/llmread.py $D/llmread.py.bak$TS
back(){ cp $D/llmread.py.bak$TS $D/llmread.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p195b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p195b_patch.py - PATCH 195b: today's AI limit and the credit count use ONLY the dollars GIR recorded itself (patch 193 on).
On 11 Nov the calls made BEFORE patch 193 (Sonnet, $2.80, no dollars recorded) were estimated and counted against the new $1 limit -
so from 19:06 GIR thought the day's budget was spent and stopped asking Claude; --balance 4.80 then showed $7.60 left.
Usage: python3 p195b_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "llmread.py"); s = open(p, encoding="utf-8").read()
new = '''        return float(row.get("usd") or 0)                     # patch 195b: only the dollars GIR recorded (not an estimate of older calls)'''
old = '''        if "usd" in row:
            return float(row["usd"])
        return (row.get("in", 0) * 3.0 + row.get("out", 0) * 15.0) / 1e6'''
if new in s:
    print("  llmread.py: already in"); sys.exit(0)
if s.count(old) != 1:
    print("NOT DONE: spent_today() not as expected"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  llmread.py: today's spend = the dollars GIR recorded"); print("patch 195b written")
PY_PATCH
cat > $D/p195btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p195btest.py - PATCH 195b: a day with older calls (no dollars recorded) neither blocks the limit nor bends the balance"""
import os, sys, json, shutil, tempfile, subprocess, datetime as dt
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp(); shutil.copy(os.path.join(B, "llmread.py"), W); os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W)
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
today = str(dt.date.today())
json.dump({today: {"calls": 606, "in": 616261, "out": 58728, "models": {"claude-sonnet-4-5": 606}}}, open(os.path.join(W, "data", "llm_usage.json"), "w"))
import llmread as L
check("11 Nov: 606 Sonnet calls before patch 193 -> not counted against today's limit (%.4f)" % L.spent_today(), L.spent_today() == 0)
subprocess.run([sys.executable, os.path.join(W, "llmread.py"), "--balance", "4.80"], capture_output=True, text=True)
check("--balance 4.80 -> $4.80 left (%.2f)" % (L.balance_left() or -1), abs((L.balance_left() or 0) - 4.80) < 1e-9)
u = json.load(open(os.path.join(W, "data", "llm_usage.json"))); u[today]["usd"] = 0.35; json.dump(u, open(os.path.join(W, "data", "llm_usage.json"), "w"))
check("then $0.35 of calls -> $4.45 left (%.2f)" % (L.balance_left() or -1), abs((L.balance_left() or 0) - 4.45) < 1e-9)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 195b"
python3 $W/p195b_patch.py $D || back
cd $D && python3 -m py_compile llmread.py || back
echo "=== the tests (stand-ins - no real call, nothing sent)"
for t in p195btest.py p193test.py p195test.py; do [ -f $D/$t ] || continue; timeout 90 python3 $D/$t > /tmp/$t.out 2>&1 && echo "  $t passed" || { grep FAIL /tmp/$t.out | head -5; back; }; done
echo "=== your --balance amount, counted again from now"
cd $D && python3 - <<'PY_B'
import json, llmread as L
try:
    b = json.load(open(L.BAL_F)); b["base"] = L.spent_today(); json.dump(b, open(L.BAL_F, "w"))
    print("  $%.2f kept" % float(b["usd"]))
except Exception:
    print("  no balance told yet")
PY_B
echo "=== restarting the programs that use Claude"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
sleep 15
for s in gir-intraday gir-exchange gir-tvwatch; do echo "  $s: $(systemctl is-active $s)"; done
echo
python3 $D/llmread.py --credit
echo "✅ patch 195b done - Claude reads the news again tonight."
