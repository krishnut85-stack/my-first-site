#!/bin/bash
# PATCH 346 - THE ALERT LOCK FIXED + CONFIRMATION IN 60 SECONDS (Rama, 16 Nov: "the alerts keep stopping" · "I get the alerts after the move - the
#   candle wait is killing me" - chose 60 seconds).
#   1) engine2.py fm_db() (first moves, surges, book moves - many writes a minute) opens tomorrow.db in AUTO-COMMIT: an error between a write and its
#      commit() left the write open and the database LOCKED (the engine held it: "alert log: database is locked", 0 alerts). Now no write stays open.
#   2) desk.py: a call is confirmed 60 SECONDS after it is first seen (was 300 = 5 min - "awaiting the 5-min confirmation").
#   Exact edits (each must match once, else nothing is written) · tests first · after the close only (it restarts the engine and the desk).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - it restarts the engine: run after 15:35"; exit 1; fi
if grep -q "patch 346" $D/engine2.py && grep -q "patch 346" $D/desk.py; then echo "patch 346 - already in"; exit 0; fi
F="engine2.py desk.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-intraday gir-desk 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/edit346.py <<'PY_E'
#!/usr/bin/env python3
"""edit346.py - patch 346: (1) engine2.fm_db() opens tomorrow.db in AUTO-COMMIT mode - a write can never be left open (the alert lock of 16 Nov);
(2) desk.py confirms a call 60 seconds after it is first seen (was 300 = 5 min). Every change must match exactly once, else nothing is written.
python3 edit346.py DIR [--dry]"""
import os, re, sys
D = sys.argv[1]; DRY = "--dry" in sys.argv
out, bad = {}, []
# ---- engine2.py: fm_db auto-commit
p = os.path.join(D, "engine2.py"); s = open(p, encoding="utf-8").read()
if "patch 346" not in s:
    rx = re.compile(r'(def fm_db\(\):\n(?:[^\n]*\n){0,3}?[^\n]*sqlite3\.connect\(os\.path\.join\(core\.BASE, "tomorrow\.db"\), timeout=10)\)')
    m = rx.findall(s)
    if len(m) != 1:
        bad.append("engine2.py: fm_db's connect line found %d times" % len(m))
    else:
        s = rx.sub(lambda mm: mm.group(1) + ", isolation_level=None)   # patch 346: auto-commit - no write is ever left open (the alert lock)", s, count=1)
        out[p] = s
# ---- desk.py: 300 s -> 60 s
p = os.path.join(D, "desk.py"); s = open(p, encoding="utf-8").read()
if "patch 346" not in s:
    E = [("conf = rd.t - self.first_seen[key] >= 300", "conf = rd.t - self.first_seen[key] >= 60   # patch 346: 60 s, was 300 (5 min)"),
         ("self.first_seen[key] + 300 + core.IST", "self.first_seen[key] + 60 + core.IST")]
    for a, b in E:
        n = s.count(a)
        if n != 1:
            bad.append("desk.py: %r found %d times" % (a[:50], n))
        else:
            s = s.replace(a, b, 1)
    for a, b in (("confirmed over 5 min", "confirmed over 60 s"), ("✓ = confirmed 5 min", "✓ = confirmed 60 s"), ("the 5-min confirmation", "the 60-second confirmation")):
        if 1 <= s.count(a) <= 3:
            s = s.replace(a, b)
    out[p] = s
if bad:
    print("❌ " + " · ".join(bad) + " - nothing written"); sys.exit(1)
for p, s in out.items():
    if not DRY:
        open(p, "w", encoding="utf-8").write(s)
    print("  %s: %s" % (os.path.basename(p), "fm_db auto-commit" if p.endswith("engine2.py") else "confirmation 60 s (was 5 min)"))
print("  (dry run - nothing written)" if DRY else "  written")
PY_E
cat > $W/p346test.py <<'PY_T'
#!/usr/bin/env python3
"""p346test.py - why the lock happened and that auto-commit cures it (temp databases), and the edit on made-up copies of the two files"""
import os, sys, sqlite3, tempfile, shutil, subprocess
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
def locked(p):
    try:
        c = sqlite3.connect(p, timeout=0.5); c.execute("BEGIN IMMEDIATE"); c.rollback(); c.close(); return False
    except sqlite3.OperationalError:
        return True
p = os.path.join(T, "tomorrow.db"); sqlite3.connect(p).execute("create table surges(a)").connection.commit()
keep = sqlite3.connect(p, timeout=10)                                     # the old way: a write, then an error before commit()
try:
    keep.execute("insert into surges values(1)"); raise ValueError("a bad value between the write and the commit")
except ValueError:
    pass
chk("the OLD way: an error between the write and commit() leaves tomorrow.db LOCKED (what happened today)", locked(p))
keep.rollback(); keep.close()
fix = sqlite3.connect(p, timeout=10, isolation_level=None)               # the new way
try:
    fix.execute("insert into surges values(2)"); raise ValueError("the same error")
except ValueError:
    pass
chk("the NEW way (auto-commit): the same error leaves it FREE", not locked(p))
chk("…and the row is saved", sqlite3.connect(p).execute("select count(*) from surges where a=2").fetchone()[0] == 1)
fix.commit(); fix.close()
chk("commit() on an auto-commit connection is harmless", True)
os.makedirs(os.path.join(T, "srv"))
open(os.path.join(T, "srv", "engine2.py"), "w").write('import os, sqlite3\nimport core\n\n\ndef fm_db():\n    c = sqlite3.connect(os.path.join(core.BASE, "tomorrow.db"), timeout=10)\n    c.execute("create table if not exists surges(a)")\n    return c\n')
open(os.path.join(T, "srv", "desk.py"), "w").write('import core\nclass X:\n    def f(self, rd, key, notes, dt):\n        conf = rd.t - self.first_seen[key] >= 300\n        if not conf:\n            notes.append("confirmation reading due %s" % (dt.datetime(1970, 1, 1) + dt.timedelta(seconds=self.first_seen[key] + 300 + core.IST)))\n        return "awaiting the 5-min confirmation"\n')
r = subprocess.run([sys.executable, os.path.join(WK, "edit346.py"), os.path.join(T, "srv")], capture_output=True, text=True)
e = open(os.path.join(T, "srv", "engine2.py")).read(); d = open(os.path.join(T, "srv", "desk.py")).read()
chk("engine2.py: fm_db opens with isolation_level=None", 'timeout=10, isolation_level=None)' in e and r.returncode == 0, r.stdout + r.stderr)
chk("desk.py: confirmation at 60 s (both places), the wording '60-second'", ">= 60 " in d and "+ 60 + core.IST" in d and ">= 300" not in d and "+ 300 +" not in d and "60-second confirmation" in d, d)
for f in ("engine2.py", "desk.py"):
    chk("%s still compiles" % f, subprocess.run([sys.executable, "-m", "py_compile", os.path.join(T, "srv", f)]).returncode == 0)
r2 = subprocess.run([sys.executable, os.path.join(WK, "edit346.py"), os.path.join(T, "srv")], capture_output=True, text=True)
chk("run twice: nothing changes the second time", "written" in r2.stdout and open(os.path.join(T, "srv", "desk.py")).read() == d)
open(os.path.join(T, "srv", "desk.py"), "w").write("x = 1\n"); open(os.path.join(T, "srv", "engine2.py"), "w").write(e.replace("patch 346", "p"))
r3 = subprocess.run([sys.executable, os.path.join(WK, "edit346.py"), os.path.join(T, "srv")], capture_output=True, text=True)
chk("a file that does not match -> refused, nothing written", r3.returncode == 1 and "nothing written" in r3.stdout, r3.stdout)
print("THE PATCH 346 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
echo "=== test (temp databases + made-up copies; nothing real touched)"
python3 $W/p346test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
echo "=== a dry run on the real files"
python3 $W/edit346.py $D --dry || { echo "❌ the real files do not match - nothing changed, send this to Claude"; exit 1; }
python3 $W/edit346.py $D || back
cd $D && python3 -m py_compile engine2.py desk.py || back
grep -n "isolation_level=None" engine2.py | head -2; grep -n ">= 60   # patch 346" desk.py | head -2
systemctl restart gir-intraday gir-desk; sleep 20
echo "  gir-intraday: $(systemctl is-active gir-intraday) · gir-desk: $(systemctl is-active gir-desk)"
[ "$(systemctl is-active gir-intraday)" = "active" ] && [ "$(systemctl is-active gir-desk)" = "active" ] || back
echo "  engine log, the last lines:"; journalctl -u gir-intraday --since "1 min ago" --no-pager -o cat | tail -4 | cut -c1-140
echo "✅ patch 346 done - tomorrow: no alert lock, the desk confirms in 60 s. Check any time: python3 $D/lockguard.py check"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-intraday gir-desk"
