#!/bin/bash
# PATCH 349 - BIG MOVERS ARE TRADES, NOT "TOO LATE" (Rama, 16 Nov: "the PE and CE are the money-making sections - don't worry about the big moves /
#   circuits"; GIR said "JUDGE NO BELRISE already +11.0% today (limit 6%); already failed a confirm today" and stayed silent on SYRMA, SAIL ...).
#   judge.py: rule 1 "already +X% today (limit 6%)" - OFF · rule 6 "already failed a confirm today" - now a 30-minute pause, not the whole day.
#   The other checks stay (weak tape, thin liquidity, sellers leading, fresh bad news, NIFTY falling hard, far from VWAP - two or more = NO).
#   Exact edits, tested on a copy of YOUR judge.py first. Restarts the engine - after the close only.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - it restarts the engine: run after 15:35"; exit 1; fi
if grep -q "patch 349" $D/judge.py; then echo "patch 349 - already in"; exit 0; fi
cp $D/judge.py $D/judge.py.bak$TS
back(){ cp $D/judge.py.bak$TS $D/judge.py; systemctl restart gir-intraday 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/edit349.py <<'PY_E'
#!/usr/bin/env python3
"""edit349.py - patch 349 on judge.py (Rama, 16 Nov: "the PE and CE are the money-making sections - don't worry about the big moves / circuits"):
  rule 1 "already +X% today (limit 6%)" - OFF: a share already moving big is a trade, not a reason to say NO
  rule 6 "already failed a confirm today" - a 30-minute pause instead of the whole day
Each change must match exactly once (spaces may differ), else nothing is written.   python3 edit349.py DIR [--dry]"""
import os, re, sys
D = sys.argv[1]; DRY = "--dry" in sys.argv
p = os.path.join(D, "judge.py"); s = open(p, encoding="utf-8").read()
if "patch 349" in s:
    print("  judge.py: patch 349 already in"); sys.exit(0)
E = [
 (r"(\n)(class Judge\(object\):)", r"\1BIG_MOVE_OK = True          # patch 349: a share already up / down big is a trade - rule 1 off\nWHIP_PAUSE_S = 1800         # patch 349: a failed confirm pauses the share 30 min, not the whole day\n\n\n\2"),
 (r"(\n([ \t]+))if chg is not None and chg > lim:", r"\1if not BIG_MOVE_OK and chg is not None and chg > lim:   # patch 349"),
 (r"(\n([ \t]+))self\.whips\[sym\] \+= 1", r"\1self.whips[sym] += 1\1self.__dict__.setdefault('whip_t', {})[sym] = time.time()   # patch 349"),
 (r"(\n([ \t]+))if self\.whips\[sym\] >= 1:\n([ \t]+)out\.append\(\"already failed a confirm today\"\)",
  r'\1if time.time() - getattr(self, "whip_t", {}).get(sym, 0) < WHIP_PAUSE_S:   # patch 349: 30 min, not all day\n\3out.append("failed a confirm in the last 30 min")'),
]
bad = []
for rx, rp in E:
    n = len(re.findall(rx, s))
    if n != 1:
        bad.append("%s x%d" % (rx[:50], n))
if "import time" not in s and not re.search(r"^import .*\btime\b", s, re.M):
    bad.append("judge.py does not import time")
if bad:
    print("❌ judge.py: %s - nothing written" % " | ".join(bad)); sys.exit(1)
for rx, rp in E:
    s = re.sub(rx, rp, s, count=1)
if not DRY:
    open(p, "w", encoding="utf-8").write(s)
print("  judge.py: 'already +6%% today' off · a failed confirm pauses 30 min%s" % (" (dry run - nothing written)" if DRY else ""))
PY_E
cat > $W/p349test.py <<'PY_T'
#!/usr/bin/env python3
"""p349test.py - the edit on a copy of judge.py; then the two rules exercised with a stand-in engine"""
import os, sys, shutil, tempfile, subprocess, types, time
WK = os.path.abspath(sys.argv[1]); SRC = sys.argv[2]; T = tempfile.mkdtemp(); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
shutil.copy(SRC, os.path.join(T, "judge.py"))
r = subprocess.run([sys.executable, os.path.join(WK, "edit349.py"), T, "--dry"], capture_output=True, text=True)
chk("dry run: all 4 changes found, nothing written", r.returncode == 0 and "patch 349" not in open(os.path.join(T, "judge.py")).read(), r.stdout + r.stderr)
r = subprocess.run([sys.executable, os.path.join(WK, "edit349.py"), T], capture_output=True, text=True)
s = open(os.path.join(T, "judge.py")).read()
chk("written", r.returncode == 0 and s.count("patch 349") >= 4, r.stdout + r.stderr)
chk("judge.py still compiles", subprocess.run([sys.executable, "-m", "py_compile", os.path.join(T, "judge.py")]).returncode == 0)
r2 = subprocess.run([sys.executable, os.path.join(WK, "edit349.py"), T], capture_output=True, text=True)
chk("run twice: already in, unchanged", "already in" in r2.stdout and open(os.path.join(T, "judge.py")).read() == s)
if "--live" in sys.argv:
    import numpy as np
    for m in ("core", "dash", "llm", "engine"):
        sys.modules.setdefault(m, types.ModuleType(m))
    sys.modules["core"].cfg = lambda: {"v2": {"judge_max_chg": 6.0}}; sys.modules["engine"].log = lambda *a: None; sys.modules["engine"].rs = lambda *a: None
    sys.path.insert(0, T); import judge as J
    flw = types.SimpleNamespace(m={"chg": np.array([11.0]), "vw": np.array([100.0])}, syms=["BIG"])
    feed = types.SimpleNamespace(pos={"BIG": 0}, obi=lambda s: 0.0, nifty_chg=lambda: 0.2)
    j = J.Judge(feed, flw, None, None)
    o1 = j.strikes("BIG", 101.0, "BLAST", "ok")
    chk("a share +11% today: NO 'already +11% today' strike any more", not any("already +" in x for x in o1), o1)
    j.note_failed_confirm("BIG"); o2 = j.strikes("BIG", 101.0, "BLAST", "ok")
    chk("a failed confirm: paused (one strike) right after", any("last 30 min" in x for x in o2), o2)
    j.whip_t["BIG"] = time.time() - 1900; o3 = j.strikes("BIG", 101.0, "BLAST", "ok")
    chk("31 minutes later: free again (it was the whole day before)", not any("failed a confirm" in x for x in o3), o3)
print("THE PATCH 349 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
echo "=== test (on a copy of YOUR judge.py)"
python3 $W/p349test.py $W $D/judge.py > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed, send this to Claude"; exit 1; }
python3 $W/edit349.py $D || back
cd $D && python3 -m py_compile judge.py || back
grep -n "patch 349" judge.py | cut -c1-120
systemctl restart gir-intraday; sleep 15
echo "  gir-intraday: $(systemctl is-active gir-intraday)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "✅ patch 349 done - from tomorrow GIR no longer says NO to a share just because it already moved big."
echo "   undo: cp $D/judge.py.bak$TS $D/judge.py; systemctl restart gir-intraday"
