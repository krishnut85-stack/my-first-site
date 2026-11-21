#!/bin/bash
# PATCH 348 - TRADE CARDS: F&O SHARES ONLY, NONE BEFORE 09:30 (16 Nov evening: cards won 8 · lost 19 · average -0.58%).
#   1) the wind watcher read EVERY share the engine streams (1,528) - cards went to INNOVACAP, JAYKAY, REGAAL, ZETWERK, SYNCOMF, POLYPLEX, TVSSCS,
#      TEMBO, DCAL (not F&O - against Rama's rule). Now only the F&O list (chains.db fo_list) goes in: cards, momentum, your view, the minute history.
#   2) most losing cards opened 09:17 and were stopped out in 1-3 minutes (the opening swings) - no card before 09:30 (shown on the page only).
#   windwatch.py (exact edits, a dry run first). Restarts gir-windwatch only - after the close.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35"; exit 1; fi
if grep -q "patch 348" $D/windwatch.py; then echo "patch 348 - already in"; exit 0; fi
cp $D/windwatch.py $D/windwatch.py.bak$TS
back(){ cp $D/windwatch.py.bak$TS $D/windwatch.py; systemctl restart gir-windwatch 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/edit348.py <<'PY_E'
#!/usr/bin/env python3
"""edit348.py - patch 348 on windwatch.py: (1) F&O shares ONLY - the watcher reads every share the engine streams (1,528 on 16 Nov, so cards went
to INNOVACAP, JAYKAY, REGAAL, ZETWERK...); now only the F&O list (chains.db fo_list) is fed in - cards, momentum, your view, the minute
history; (2) no card before 09:30 - 16 Nov: most cards opened 09:17 and were stopped out in 1-3 minutes (the opening swings); before 09:30
it is shown on the page only. Every anchor must match once, else nothing is written.   python3 edit348.py DIR [--dry]"""
import os, sys
D = sys.argv[1]; DRY = "--dry" in sys.argv
p = os.path.join(D, "windwatch.py"); s = open(p, encoding="utf-8").read()
if "patch 348" in s:
    print("  windwatch.py: patch 348 already in"); sys.exit(0)
E = [
 ('def sectors_of():',
  '''CARD_FROM = "09:30"                                                       # patch 348: no card before 09:30 (the opening swings)
_FO = {"day": None, "set": None}


def _fo_only(q):
    """patch 348: only the F&O shares (chains.db fo_list, read once a day) - Rama's rule: F&O stocks only. Unreadable list -> unchanged."""
    import sqlite3, datetime as _dt
    d = str(_dt.date.today())
    if _FO["day"] != d:
        try:
            c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
            st = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
            _FO.update({"day": d, "set": st if len(st) >= 100 else None})
        except Exception:
            _FO.update({"day": d, "set": None})
    S = _FO["set"]
    if not S or not q:
        return q
    return {k: v for k, v in q.items() if k in S}


def sectors_of():'''),
 ('                W.feed(t, Q.get("q"), F.get("f") if F.get("t") and t - F["t"] < 30 else {})',
  '                W.feed(t, _fo_only(Q.get("q")), F.get("f") if F.get("t") and t - F["t"] < 30 else {})   # patch 348: F&O shares only'),
 ('                    if (s_, w_["dir"]) in BK.open:',
  '''                    if hms[:5] < CARD_FROM:                                       # patch 348: no card before 09:30
                        x["st"], x["won"] = "page only · before 09:30 - the opening swings", 0
                        continue
                    if (s_, w_["dir"]) in BK.open:'''),
 ('                    if not early or against or hm < MOM_FROM or sent.get("mom", 0) >= MOM_DAY_MAX:',
  '                    if not early or against or hm < MOM_FROM or hm < CARD_FROM or sent.get("mom", 0) >= MOM_DAY_MAX:   # patch 348: + before 09:30'),
 ('"the first 2 minutes are noise" if hm < MOM_FROM else "12 cards a day")',
  '"the first 2 minutes are noise" if hm < MOM_FROM else "before 09:30 - the opening swings" if hm < CARD_FROM else "12 cards a day")'),
]
bad = [a[:60] for a, b in E if s.count(a) != 1]
if bad:
    print("❌ windwatch.py: not found exactly once: %s - nothing written" % " | ".join(bad)); sys.exit(1)
for a, b in E:
    s = s.replace(a, b, 1)
if not DRY:
    open(p, "w", encoding="utf-8").write(s)
print("  windwatch.py: F&O shares only · no card before 09:30%s" % (" (dry run - nothing written)" if DRY else ""))
PY_E
cat > $W/p348test.py <<'PY_T'
#!/usr/bin/env python3
"""p348test.py - the edit on a copy of windwatch.py (made-up F&O list); the filter and the 09:30 gate"""
import os, sys, sqlite3, shutil, tempfile, subprocess, importlib
WK = os.path.abspath(sys.argv[1]); SRC = sys.argv[2]; T = tempfile.mkdtemp(); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
shutil.copy(SRC, os.path.join(T, "windwatch.py"))
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym, lot)")
c.executemany("insert into fo_list values(?,?)", [("ZZFO%d" % i, 100) for i in range(150)] + [("TMPV", 1000), ("AMBER", 100)]); c.commit(); c.close()
r = subprocess.run([sys.executable, os.path.join(WK, "edit348.py"), T, "--dry"], capture_output=True, text=True)
chk("dry run: every anchor found, nothing written", r.returncode == 0 and "dry run" in r.stdout and "patch 348" not in open(os.path.join(T, "windwatch.py")).read(), r.stdout + r.stderr)
r = subprocess.run([sys.executable, os.path.join(WK, "edit348.py"), T], capture_output=True, text=True)
s = open(os.path.join(T, "windwatch.py")).read()
chk("written: the filter, the feed line, both card gates", r.returncode == 0 and s.count("patch 348") >= 5, r.stdout + r.stderr)
chk("windwatch.py still compiles", subprocess.run([sys.executable, "-m", "py_compile", os.path.join(T, "windwatch.py")]).returncode == 0)
sys.path.insert(0, T)
src = s[s.index("_FO = {"):s.index("def sectors_of():")]
ns = {"os": os, "BASE": T}; exec(src, ns)
q = {"TMPV": [264.7, -8.5], "AMBER": [6242, -7.8], "INNOVACAP": [1047.2, -2.4], "JAYKAY": [191.8, -2.7], "REGAAL": [101.2, 2.0]}
out = ns["_fo_only"](q)
chk("F&O only: TMPV and AMBER kept · INNOVACAP, JAYKAY, REGAAL dropped", set(out) == {"TMPV", "AMBER"}, out)
os.remove(os.path.join(T, "chains.db")); ns["_FO"].update({"day": None})
chk("no F&O list readable -> nothing dropped (never a blank watcher)", ns["_fo_only"](q) == q)
chk("cards: the 09:30 gate on the big-mover cards and the momentum cards", 'if hms[:5] < CARD_FROM:' in s and "or hm < CARD_FROM or" in s)
r2 = subprocess.run([sys.executable, os.path.join(WK, "edit348.py"), T], capture_output=True, text=True)
chk("run twice: says already in, changes nothing", "already in" in r2.stdout and open(os.path.join(T, "windwatch.py")).read() == s)
print("THE PATCH 348 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
echo "=== test (on a copy of YOUR windwatch.py, a made-up F&O list)"
python3 $W/p348test.py $W $D/windwatch.py > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
python3 $W/edit348.py $D || back
cd $D && python3 -m py_compile windwatch.py || back
systemctl restart gir-windwatch; sleep 5
echo "  gir-windwatch: $(systemctl is-active gir-windwatch)"
[ "$(systemctl is-active gir-windwatch)" = "active" ] || back
echo "  F&O shares in the list: $(python3 -c "import sqlite3;print(sqlite3.connect('file:$D/chains.db?mode=ro',uri=True).execute('select count(*) from fo_list').fetchone()[0])")"
echo "✅ patch 348 done - from tomorrow: cards only on F&O shares, none before 09:30."
echo "   undo: cp $D/windwatch.py.bak$TS $D/windwatch.py; systemctl restart gir-windwatch"
