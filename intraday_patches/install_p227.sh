#!/bin/bash
# PATCH 227 - PROFIT BOOKING / SHORT COVERING only on a REAL TURN, every share (Rama, 12 Nov: "yes, make profit booking wait for a real turn" -
#   POLICYBZR rang PROFIT BOOKING at 10:26, 11:07, 14:19 and closed +7.6%).
#   1 no new high (low) for 5 min first · 2 heavy volume counts as the proof only on a candle going against the move (14:19: 12.7x on a flat
#   candle at the top = buying). The cost: a true booking now rings a few minutes after the top (COROMANDEL 11 Nov: at +7.9%, not +8.2%).
#   Tested: POLICYBZR old rule vs new (5 cases) + the simulated day. Restarts the news hunt - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/pbook.py ] || { echo "patch 213 first"; exit 1; }
if grep -q "patch 227" $D/pbook.py; then
  echo "  patch 227 is already in - restarting the news hunt only"; systemctl restart gir-newshunt; sleep 6; echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"; exit 0
fi
cp $D/pbook.py $D/pbook.py.bak$TS; mkdir -p $W/old && cp $D/pbook.py $W/old/pbook.py
back(){ cp $D/pbook.py.bak$TS $D/pbook.py; systemctl restart gir-newshunt 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p227_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p227_patch.py - PATCH 227: PROFIT BOOKING / SHORT COVERING only on a REAL TURN, every share (Rama, 12 Nov: "yes, make profit booking wait for a
real turn" - POLICYBZR rang PROFIT BOOKING at 10:26, 11:07 and 14:19 and closed +7.6%).
  1 the extreme must be 5 min old (no new high / low for 5 min) - a pause or a tick bounce is not a turn (patch 223 did it for results shares)
  2 heavy volume counts as the selling (buying) proof only on a 5-min candle going AGAINST the move - heavy volume on a flat / green candle
    at the high is buying (POLICYBZR 14:15: 12.7x on a flat candle, then +5% at 14:20)
  the other proofs stay: futures OI falling since the extreme, writers building a roof, 20%+ of the move given back
Usage: python3 p227_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "pbook.py"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag, alt=None):
    global s
    if new in s:
        print("  pbook.py: %s - already in" % tag); return
    for o, n in ((old, new),) + ((alt,) if alt else ()):
        if s.count(o) == 1:
            s = s.replace(o, n); print("  pbook.py: %s" % tag); return
    ERR.append("anchor '%s' not found once" % tag)


T5 = '''            if t - st[tk] < 300:
                continue                                           # patch 227: a real turn - no new extreme for 5 min (every share)'''
rep('''            if t - st[tk] < 300 and results_recent(s, t):
                continue                                           # patch 223: results - a bounce right after a new extreme is not a turn (PAGEIND 14:33)''',
    T5, "the extreme 5 min old (every share)",
    alt=('''                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)''',
         '''                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)
''' + T5))
rep('''            if vx and vx >= 1.5:''', '''            if vx and vx >= 1.5 and candle_against(s, side):       # patch 227: heavy volume on a candle going against the move - not buying at the top''',
    "volume proof only on a candle against the move")
rep('''def tick(now, ltp, chg, fo=None, act=None):''', '''def candle_against(sym, side):
    """patch 227: the last 5-min candle closed against the move (red after a rise, green after a fall)"""
    c = (_json("charts.json", 20) or {}).get(sym) or {}
    O, C = [x for x in (c.get("o") or []) if x], [x for x in (c.get("c") or []) if x]
    if not O or not C:
        return False
    return (C[-1] - O[-1]) * side < 0


def tick(now, ltp, chg, fo=None, act=None):''', "candle_against()")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("patch 227 in")
PY_PATCH
cat > $W/p227test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p227test.py - PROFIT BOOKING on a real turn: POLICYBZR 12 Nov (closed +7.6%), old rule vs new (made-up files, nothing sent).
python3 p227test.py NEWDIR OLDDIR   (pbook.py in each)"""
import os, sys, json, shutil, tempfile, importlib.util, datetime as dt
NEW, OLD = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(NEW, "pbook.py"), os.path.join(T, "pbook_new.py")); shutil.copy(os.path.join(OLD, "pbook.py"), os.path.join(T, "pbook_old.py"))
for f in ("resultreact.py",):
    if os.path.exists(os.path.join(NEW, f)):
        shutil.copy(os.path.join(NEW, f), T)
sys.path.insert(0, T); os.chdir(T)
def load(n):
    sp = importlib.util.spec_from_file_location(n, os.path.join(T, n + ".py")); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m); return m
PN, PO = load("pbook_new"), load("pbook_old")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); DAY = dt.datetime(2026, 11, 12, tzinfo=IST)
PC = 976.0
json.dump({"fo_paths": [{"s": "POLICYBZR", "oi": 6.1}]}, open("dash_state.json", "w"))
def setc(o, c, vx):                                                   # the day so far: 40 quiet candles, then the last one (o -> c, vx x volume)
    json.dump({"POLICYBZR": {"o": [990.0] * 40 + [o], "h": [991.0] * 40 + [max(o, c)], "l": [989.0] * 40 + [min(o, c)], "c": [990.0] * 40 + [c],
                             "v": [1000] * 40 + [int(1000 * vx)], "pc": PC}}, open("charts.json", "w"))
def run(M, seq):
    M.ST.update({"day": None, "s": {}}); M._F.clear(); out = []
    for (h, m, s), px in seq:
        out += M.tick(DAY.replace(hour=h, minute=m, second=s), {"POLICYBZR": px}, {"POLICYBZR": (px / PC - 1) * 100}, fo={"POLICYBZR"}, act=set())
    return [x.split("\n")[0] for x in out]
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))
# 14:13 a new high +4.0%, 14:19 a dip on 12.7x volume - but the candle is FLAT / GREEN (buying at the top); then +5% at 14:20
setc(1012.0, 1013.0, 12.7)
seq = [((14, 5, 0), 1000.0), ((14, 10, 0), 1010.0), ((14, 13, 38), 1015.1), ((14, 15, 0), 1013.0), ((14, 19, 33), 1010.0)]
o, n = run(PO, seq), run(PN, seq)
chk("14:19 (wrong: +5% at 14:20) - the old rule rang PROFIT BOOKING", any("PROFIT BOOKING" in x for x in o), o)
chk("14:19 - the new rule: silent (the heavy volume was on a flat / green candle = buying)", not any("PROFIT BOOKING" in x for x in n), n)
# 11:02 a high +3.0%, 11:07 down on a RED candle with 2.2x volume - the share gave back to +0.8% by 13:15 (a right call)
setc(1004.0, 1000.0, 2.2)
seq = [((10, 55, 0), 1000.0), ((11, 2, 5), 1005.6), ((11, 4, 0), 1003.0), ((11, 7, 16), 1000.0)]
n = run(PN, seq)
chk("11:07 (right: it fell to +0.8%) - the new rule still rings PROFIT BOOKING (5 min after the high, a red candle on 2.2x)", any("PROFIT BOOKING" in x for x in n), n)
# a tick dip 40 s after a new high, red candle, big volume: too soon - not a turn
setc(1004.0, 1000.0, 3.0)
seq = [((11, 55, 0), 1000.0), ((12, 0, 0), 1005.6), ((12, 0, 40), 999.0)]
o, n = run(PO, seq), run(PN, seq)
chk("a dip 40 s after a new high: the old rule rang at once - the new waits (no new high for 5 min first)", any("PROFIT BOOKING" in x for x in o) and not n, (o, n))
seq2 = seq + [((12, 5, 10), 999.5)]
n = run(PN, seq2)
chk("... still down 5 min later, on a red heavy candle: now it rings (a real turn)", any("PROFIT BOOKING" in x for x in n), n)
print("REAL TURN test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p227_patch.py $D || back
cd $D && python3 -m py_compile pbook.py || back
echo "=== test: POLICYBZR 12 Nov, the old rule vs the new"
python3 $W/p227test.py $D $W/old || back
systemctl restart gir-newshunt; sleep 6; echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
[ "$(systemctl is-active gir-newshunt)" = "active" ] || back
echo "✅ patch 227 done - PROFIT BOOKING / SHORT COVERING ring only on a real turn (5 min with no new extreme, selling volume on a falling candle)."
echo "   undo: cp $D/pbook.py.bak$TS $D/pbook.py; systemctl restart gir-newshunt"
