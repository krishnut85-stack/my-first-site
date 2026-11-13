#!/bin/bash
# PATCH 244 - WHO IS PUSHING: earlier evidence against today's price is not a push (Rama, 13 Nov 10:00: PETRONET -2.5% said "▲ pushing up: DII ·
#   ▼ pulling down: none"; AMBER +5.1% said "▼ pulling down: COMPANY"). Evidence from before today's session (named FII / DII deals of 5 days and
#   yesterday's delivery, promoter filings, index news, company news, broker notes) stays on the line, but when today's price has gone 0.7%+ the
#   other way it is not counted: "but today the price is -2.5% the other way - not counted as a push today". Live evidence (futures, writers,
#   the tide, the ban) unchanged. Tested: 6 cases (the old code fails the PETRONET and AMBER ones) + GIR's push/pull test.
#   Restarts the page server and the news hunt (push/pull alerts) - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 234" $D/pushwho.py || { echo "patch 234 first"; exit 1; }
cp $D/pushwho.py $D/pushwho.py.bak$TS
SV="gir-dash gir-newshunt"
back(){ cp $D/pushwho.py.bak$TS $D/pushwho.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p244_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p244_patch.py - PATCH 244: WHO IS PUSHING - earlier evidence against today's price is not a push (Rama, 13 Nov 10:00: PETRONET -2.5% said
"▲ pushing up: DII · ▼ pulling down: none"; AMBER +5.1% said "▼ pulling down: COMPANY").
Evidence from before today's session - named FII / DII deals (5 days) and yesterday's delivery, promoter filings, index news, the company's news,
broker notes - stays on the line, but when today's price has gone 0.7%+ the OTHER way it no longer counts as pushing: the line says "but today the
price is -2.5% the other way - not counted as a push today". Live evidence (futures money, option writers, the tide, the ban) is unchanged.
Usage: python3 p244_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "pushwho.py"); s = open(p, encoding="utf-8").read()
old = '''    # the kind of push
'''
new = '''    for n_ in (1, 2, 5, 6, 7, 10):                               # patch 244: earlier evidence against today's price is not a push today
        r_ = R[n_]
        if r_["side"] and d and r_["side"] != d and chg is not None and abs(chg) >= 0.7:
            r_["t"] += " · but today the price is %+.1f%% the other way - not counted as a push today" % chg
            r_["side"] = 0
    # the kind of push
'''
if new in s:
    print("  pushwho.py: earlier evidence against today's price - already in")
elif s.count(old) != 1:
    print("❌ pushwho.py: anchor found %d times" % s.count(old)); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  pushwho.py: earlier evidence against today's price is not a push")
print("patch 244 in")
PY_PATCH
cat > $W/p244test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p244test.py - WHO IS PUSHING: earlier evidence against today's price (PETRONET / AMBER, 13 Nov; made-up files, nothing sent). python3 p244test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(D, "pushwho.py"), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 13, 10, 0, tzinfo=IST)
R = {"AMBER": [{"k": "results", "t": "results 11-12 18:40: Amber Enterprises Q2 profit falls 12%", "side": -1}],
     "TATA1": [{"k": "results", "t": "results 11-13 09:40: Tata One Q2 profit up 30%", "side": 1}],
     "PETRONET": [], "SMALL": []}
CHG = {"AMBER": 5.14, "PETRONET": -2.49, "TATA1": 3.0, "SMALL": -0.4}
open(os.path.join(T, "whymove.py"), "w").write("R = %r\nC = %r\ndef explain(sym, now=None):\n    return {'s': sym, 'chg': C.get(sym), 'reasons': R.get(sym, [])}\n" % (R, CHG))
open(os.path.join(T, "newsalert.py"), "w").write("def about_it(sym, h, src='', name=''):\n    return True\n")
json.dump({"fo_paths": [{"s": "AMBER", "chg": 5.14, "bu": "SHORT COVERING", "cr": 22, "oi": -3.1}, {"s": "PETRONET", "chg": -2.49}, {"s": "TATA1", "chg": 3.0}, {"s": "SMALL", "chg": -0.4}]},
          open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"shares": {}}, open(os.path.join(T, "data", "desk.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import pushwho as W
W._F["_inst"] = (9e18, {"w": {"5": {"dii_all": {"PETRONET": {"cr": 85.0, "who": "an Indian fund"}, "SMALL": {"cr": 20.0}}, "fii_all": {}}, "30": {}}})
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
rows = lambda s: {x["k"]: x for x in W.read(s, now=NOW)["rows"]}
r = rows("PETRONET")
chk("PETRONET -2.5%: DII's 5-day buying shown, but NOT counted as pushing up", r["DII"]["on"] and r["DII"]["side"] == 0 and "not counted as a push today" in r["DII"]["t"] and "-2.5%" in r["DII"]["t"], r["DII"])
chk("... nothing left pushing up", not any(x["side"] > 0 for x in r.values()), [(k, x["side"]) for k, x in r.items() if x["side"]])
r = rows("AMBER")
chk("AMBER +5.1%: last evening's weak results shown, NOT counted as pulling down", r["COMPANY"]["on"] and r["COMPANY"]["side"] == 0 and "+5.1% the other way" in r["COMPANY"]["t"], r["COMPANY"])
chk("... the live futures short covering still pushes up", r["FUTURES"]["side"] == 1, r["FUTURES"])
r = rows("TATA1")
chk("TATA1 +3%: good results the same way - still pushing up", r["COMPANY"]["side"] == 1 and "not counted" not in r["COMPANY"]["t"], r["COMPANY"])
r = rows("SMALL")
chk("SMALL -0.4% (under 0.7%): DII buying still counts (too small a move to call it against)", r["DII"]["side"] == 1, r["DII"])
print("PUSH vs TODAY'S PRICE test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p244_patch.py $D || back
cd $D && python3 -m py_compile pushwho.py || back
echo "=== test: earlier evidence against today's price"
python3 $W/p244test.py $D || back
if [ -f $D/p215test.py ]; then cd $D && python3 p215test.py $D 2>&1 | grep -E "❌|passed"; python3 p215test.py $D >/dev/null 2>&1 || back; fi
echo "=== this server, now (PETRONET · AMBER):"
cd $D && timeout 120 python3 -c "
import sys; sys.path.insert(0, '$D')
import pushwho
for s in ('PETRONET', 'AMBER'):
    try:
        p = pushwho.read(s); rs = p['rows']
        print('   %s %s%% · ▲ pushing up: %s · ▼ pulling down: %s' % (s, p.get('chg'), ', '.join(r['k'] for r in rs if r['side'] > 0) or 'none', ', '.join(r['k'] for r in rs if r['side'] < 0) or 'none'))
        for r in rs:
            if 'not counted as a push today' in (r.get('t') or ''):
                print('      %s: %s' % (r['k'], r['t'][-140:]))
    except Exception as ex:
        print('   %s: %s' % (s, ex))
" 2>&1 | tail -8
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 6; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 244 done - a push counts only when today's price does not go the other way."
echo "   undo: cp $D/pushwho.py.bak$TS $D/pushwho.py; systemctl restart $SV"
