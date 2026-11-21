#!/bin/bash
# PATCH 350 - "TOO LATE" OFF IN THE ENGINE, BOTH SIDES (Rama, 16 Nov: "already 6 percent on EITHER side - not only one side").
#   engine2.py scoring: "moved 9%+ today -> score 0, too late" and "6%+ -> late entry penalty" (up for CE, down for PE) - both OFF;
#   the opening-breakout "skip if already 1% above the trigger" - now 5%. (patch 349 took the judge's 6% rule off.)
#   Exact edits, tested on a copy of YOUR engine2.py first. Restarts the engine - after the close only.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - it restarts the engine: run after 15:35"; exit 1; fi
if grep -q "patch 350" $D/engine2.py; then echo "patch 350 - already in"; exit 0; fi
cp $D/engine2.py $D/engine2.py.bak$TS
back(){ cp $D/engine2.py.bak$TS $D/engine2.py; systemctl restart gir-intraday 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/edit350.py <<'PY_E'
#!/usr/bin/env python3
"""edit350.py - patch 350 on engine2.py (Rama, 16 Nov: "already 6 percent on EITHER side - not only one side"):
  the scoring rule "moved 9%+ today (up for CE, down for PE) -> score 0, too late" - OFF
  the "6%+ -> late entry penalty -15" - OFF
  the opening-breakout "skip if already 1% above the trigger" (sip_chase_pct) - 1% -> 5%
Each must match exactly once, else nothing is written.   python3 edit350.py DIR [--dry]"""
import os, re, sys
D = sys.argv[1]; DRY = "--dry" in sys.argv
p = os.path.join(D, "engine2.py"); s = open(p, encoding="utf-8").read()
if "patch 350" in s:
    print("  engine2.py: patch 350 already in"); sys.exit(0)
E = [(r"(\n[ \t]+)if moved > 9\.0:(\n[ \t]+return 0, \[\"already moved %\.1f%% today - too late\")", r"\1if moved > 999.0:   # patch 350: was 9.0 - a big mover is a trade, both sides\2"),
     (r"(\n[ \t]+)if moved > 6\.0:(\n[ \t]+pts -= 15; why\.append\(\"already up)", r"\1if moved > 999.0:   # patch 350: was 6.0 - no late-entry penalty\2"),
     (r"\"sip_chase_pct\":[ \t]*1\.0,", r'"sip_chase_pct": 5.0,   # patch 350: was 1.0')]
bad = ["%s x%d" % (rx[:40], len(re.findall(rx, s))) for rx, _ in E if len(re.findall(rx, s)) != 1]
if bad:
    print("❌ engine2.py: %s - nothing written" % " | ".join(bad)); sys.exit(1)
for rx, rp in E:
    s = re.sub(rx, rp, s, count=1)
if not DRY:
    open(p, "w", encoding="utf-8").write(s)
print("  engine2.py: 'too late' and the late penalty off (both sides) · breakout chase 1%% -> 5%%%s" % (" (dry run - nothing written)" if DRY else ""))
PY_E
cat > $W/p350test.py <<'PY_T'
#!/usr/bin/env python3
"""p350test.py - the edit on a copy of engine2.py; the scoring exercised for a +11% CE and a -11% PE"""
import os, sys, shutil, tempfile, subprocess, re
WK = os.path.abspath(sys.argv[1]); SRC = sys.argv[2]; T = tempfile.mkdtemp(); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
shutil.copy(SRC, os.path.join(T, "engine2.py"))
r = subprocess.run([sys.executable, os.path.join(WK, "edit350.py"), T, "--dry"], capture_output=True, text=True)
chk("dry run: all 3 found, nothing written", r.returncode == 0 and "patch 350" not in open(os.path.join(T, "engine2.py")).read(), r.stdout + r.stderr)
r = subprocess.run([sys.executable, os.path.join(WK, "edit350.py"), T], capture_output=True, text=True)
s = open(os.path.join(T, "engine2.py")).read()
chk("written (3 changes)", r.returncode == 0 and s.count("patch 350") == 3, r.stdout + r.stderr)
chk("engine2.py still compiles", subprocess.run([sys.executable, "-m", "py_compile", os.path.join(T, "engine2.py")]).returncode == 0)
if "--live" in sys.argv:
    ns = {}; exec(s[s.index("def score("):s.index("# end score")], ns)
    for up, dc in ((True, 11.0), (False, -11.0), (True, 7.0)):
        sc, why = ns["score"]({"day_chg": dc}, up)
        chk("%s %+.0f%% today: scored %d, no 'too late' / 'late entry'" % ("CE" if up else "PE", dc, sc), sc > 0 and not any("late" in w for w in why), (sc, why))
r2 = subprocess.run([sys.executable, os.path.join(WK, "edit350.py"), T], capture_output=True, text=True)
chk("run twice: already in", "already in" in r2.stdout)
print("THE PATCH 350 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
echo "=== test (on a copy of YOUR engine2.py)"
python3 $W/p350test.py $W $D/engine2.py > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed, send this to Claude"; exit 1; }
python3 $W/edit350.py $D || back
cd $D && python3 -m py_compile engine2.py || back
grep -n "patch 350" engine2.py | cut -c1-120
systemctl restart gir-intraday; sleep 15
echo "  gir-intraday: $(systemctl is-active gir-intraday)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "✅ patch 350 done - from tomorrow a share already up OR down big is scored like any other, never 'too late'."
echo "   undo: cp $D/engine2.py.bak$TS $D/engine2.py; systemctl restart gir-intraday"
