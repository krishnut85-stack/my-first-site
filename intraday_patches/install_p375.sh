#!/bin/bash
# PATCH 375 - "DRIVING IT" SAYS ONLY TODAY'S NEWS, WITH ITS TIME (Rama, 17 Nov 13:36, LAURUSLABS: from 09:19 to 12:06 every 🚀 RUNNING / ⚡ SPEED
#   line said "driving it: news: Laurus Labs shares fall 3.5% as promoters sell shares worth Rs 500 crore" - YESTERDAY's headline, the other
#   way - while the share rose on the promoter ruling out more sales; GIR's reader had that at 12:26 and the line never showed it).
#   engine2.drivers() took the newest headline of the last 24 hours, whatever its day. Now:
#     · only news seen AFTER THE LAST CLOSE (15:30 of the last weekday) counts, the newest first, with its time:
#         "driving it: news 12:26: Laurus Labs shares rise 3.5% as promoter says no further plans for stake sale"
#     · none since the close -> "no fresh news since the last close (older: 16 Nov 15:01 Laurus Labs shares fall ...)"
#   Edits engine2.py (one block, backed up; tested on its own before the engine restarts). Restarts gir-intraday - after 15:35.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 375" $D/engine2.py; then echo "patch 375 - already in"; exit 0; fi
cp $D/engine2.py $D/engine2.py.bak$TS
back(){ cp $D/engine2.py.bak$TS $D/engine2.py; systemctl restart gir-intraday; echo "❌ old engine2.py back - nothing changed"; exit 1; }
python3 - $D/engine2.py <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
a = '''        it = next(iter(newsroom.items_for(sym, 24, 0)), None)
        if it:
            news = "news: %s" % (it.get("h") or "")[:120]
'''
b = '''        import datetime as _dt                                  # patch 375: only news seen after the last close counts, with its time
        _n = _dt.datetime.now(_dt.timezone(_dt.timedelta(hours=5, minutes=30))); _c = _n.replace(hour=15, minute=30, second=0, microsecond=0)
        if _n < _c:
            _c -= _dt.timedelta(days=1)
        while _c.weekday() > 4:
            _c -= _dt.timedelta(days=1)
        _its = list(newsroom.items_for(sym, 24, 0) or [])
        _fr = sorted([x for x in _its if float(x.get("ts") or 0) >= _c.timestamp()], key=lambda x: -float(x.get("ts") or 0))
        if _fr:
            it = _fr[0]
            news = "news %s: %s" % (_dt.datetime.fromtimestamp(float(it.get("ts") or 0), _n.tzinfo).strftime("%H:%M"), (it.get("h") or "")[:120])
        elif _its:
            it = _its[0]
            news = "no fresh news since the last close (older: %s %s)" % (str(it.get("t") or "")[:12], (it.get("h") or "")[:70])
'''
if t.count(a) != 1:
    print("❌ engine2.py: the news block found %d times (expected 1) - nothing changed" % t.count(a)); sys.exit(1)
t = t.replace(a, b)
a2 = '"no news found — this is money"'
if t.count(a2) == 1:
    t = t.replace(a2, '"no news since the last close — this is money"')
open(p, "w", encoding="utf-8").write(t); print("  engine2.py: drivers() - today's news only, with its time")
PY_EDIT
cd $D && python3 -m py_compile engine2.py || back
timeout 60 python3 - $D/engine2.py <<'PY_TEST' || back
import sys, ast, time, types
src = open(sys.argv[1], encoding="utf-8").read(); tree = ast.parse(src)
fn = next((n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "drivers"), None)
if fn is None:
    print("  ❌ drivers() not found in engine2.py"); sys.exit(1)
now = time.time(); fake = types.ModuleType("newsroom")
fake.items_for = lambda s, h, x=0: [{"ts": now - 26 * 3600, "t": "16 Nov 15:01", "h": "Laurus Labs shares fall 3.5% as promoters sell"}] if s == "OLD" else \
    [{"ts": now - 600, "t": "17 Nov 12:26", "h": "Laurus Labs shares rise 3.5% as promoter says no further stake sale"}, {"ts": now - 26 * 3600, "t": "16 Nov", "h": "old"}] if s == "NEW" else []
sys.modules["newsroom"] = fake
g = {"__name__": "t375", "json": __import__("json"), "os": __import__("os")}
class _C: BASE = "/nonexistent"
sys.modules.setdefault("core", types.ModuleType("core")); sys.modules["core"].BASE = "/nonexistent"; g["core"] = sys.modules["core"]
exec(compile(ast.Module(body=[fn], type_ignores=[]), "drivers", "exec"), g)
f = g["drivers"]
for s_ in ("OLD", "NEW", "NONE"):
    print("   %-5s -> %s" % (s_, f(s_)[1]))
assert "no fresh news" in f("OLD")[1] and "rise 3.5%" in f("NEW")[1] and not f("NONE")[1]
print("  the three cases checked ✓")
PY_TEST
systemctl restart gir-intraday; sleep 10
echo "  gir-intraday: $(systemctl is-active gir-intraday)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "✅ patch 375 done - from tomorrow 🚀 RUNNING / ⚡ SPEED say only today's news, with its time."
echo "   undo: cp $D/engine2.py.bak$TS $D/engine2.py; systemctl restart gir-intraday"
