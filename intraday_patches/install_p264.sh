#!/bin/bash
# PATCH 264 - THE RESULTS-WEEK SWING ON DAYS 2-7: SHOWN, NOT RUNG (the 40-day replay on this server, 14 Nov: right 8 of 29, wrong 7 of 29,
#   avg +0.11% in an hour, -0.32% to the close - a coin flip). It still reaches Box Picks and the page, silently, marked 📊 RESULTS WEEK.
#   Keeps ringing: the day-1 swing (right 4 of 11, wrong 1) and the open checks (right 7 of 10, wrong 2) · ⚡ SPEED · the EVENT WATCH.
#   Tested: 2 cases. Restarts the senders - after 15:35 on a trading day (or add: now); on a weekend any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 262" $D/resultreact.py || { echo "patch 262 first"; exit 1; }
F="resultreact.py alertword.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p264_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p264_patch.py - patch 264: the results-week SWING on days 2-7 is shown, not rung (Rama's server, 14 Nov, the 40-day replay: day-2-7 swings
right 8 of 29, wrong 7 of 29, avg +0.11% in an hour, -0.32% to the close - a coin flip). Day 1 swings (right 4 of 11, wrong 1) and the open checks
(right 7 of 10, wrong 2) keep ringing. ⚡ SPEED and the EVENT WATCH still ring on results shares.   python3 p264_patch.py DIR"""
import os, sys
D = sys.argv[1]
RR = '''

_swing262 = swing_tick                                             # patch 264: days 2-7 shown, not rung (the 40-day replay: a coin flip)


def swing_tick(now, ltp, chg=None, fo=None):
    out = []
    for x in _swing262(now, ltp, chg, fo):
        m = re.match(r"🚨 CRITICAL · RESULTS REACTION ([▲▼]) (\\S+) · (\\d\\d:\\d\\d) · DAY (\\d+) SWING", x)
        if not m or int(m.group(4)) < 2:
            out.append(x); continue
        L = x.split("\\n")
        out.append("\\n".join(["📊 RESULTS WEEK · DAY %s SWING %s %s · %s · shown, not rung" % (m.group(4), m.group(1), m.group(2), m.group(3)),
                              L[1] if len(L) > 1 else "", L[2] if len(L) > 2 else "",
                              "not a trade call: on days 2-7 these swings were right 8 of 29 and wrong 7 of 29 (5-12 Nov) - a coin flip · "
                              "⚡ SPEED and the 👁 EVENT WATCH still ring on this share"]))
    return out
'''
AW = '''

_tier264 = tier                                                    # patch 264: the results week's day-2-7 swing is information, not a ring


def tier(text):
    if (text or "").lstrip().startswith("📊 RESULTS WEEK"):
        return "read"
    return _tier264(text)
'''
for f, add, need in (("resultreact.py", RR, "patch 262"), ("alertword.py", AW, None)):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if "patch 264" in s:
        print("  %s: patch 264 - already in" % f); continue
    if need and need not in s:
        print("❌ %s: %s first" % (f, need)); sys.exit(1)
    open(p, "w", encoding="utf-8").write(s.rstrip("\n") + "\n" + add)
    print("  %s: %s" % (f, "days 2-7 swings shown, not rung" if f == "resultreact.py" else "📊 RESULTS WEEK = silent"))
print("patch 264 in")
PY_PATCH
cat > $W/p264test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p264test.py - day-2-7 swings shown, not rung (temp copies, nothing sent).  python3 p264test.py DIR"""
import os, sys, json, types, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp()
for f in ("resultreact.py", "alertword.py", "tglanes.py"):
    shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); os.chdir(T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
sys.modules["holidays"] = types.SimpleNamespace(holiday=lambda d: "weekend" if d.weekday() >= 5 else None)
at = lambda y, m, d, h, mi: dt.datetime(y, m, d, h, mi, tzinfo=IST)
c = sqlite3.connect("filings.db"); c.execute("create table filings(sym text, t_exch int, kind text, verdict text)")
for s, t in (("ABC", at(2026, 11, 11, 18, 0)), ("ONE", at(2026, 11, 13, 18, 0))):
    c.execute("insert into filings values (?, ?, 'RESULTS', 'BEAT')", (s, int(t.timestamp())))
c.commit(); c.close()
bar = lambda: {"pc": 100, "o": [101] * 70, "h": [101.3] * 70, "l": [100.7] * 70, "c": [101] * 70, "v": [1000] * 52 + [3200] + [1000] * 17, "vw": [101.0] * 70}
json.dump({"ABC": bar(), "ONE": bar()}, open("charts.json", "w"))
import resultreact as RR, alertword as A
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
r = RR.tick(at(2026, 11, 16, 13, 41), {"ABC": 103.4, "ONE": 103.4}, {}, fo={"ABC", "ONE"})
a = next((x for x in r if "ABC" in x.split("\n")[0]), ""); o = next((x for x in r if "ONE" in x.split("\n")[0]), "")
chk("ABC day 3 swing: 📊 RESULTS WEEK · shown, not rung (silent)", a.startswith("📊 RESULTS WEEK · DAY 3 SWING ▲ ABC") and A.tier(a) == "read" and "BUY" not in a, (a, A.tier(a)))
chk("ONE day 1 swing: still 🚨 RESULTS REACTION, rings (act)", o.startswith("🚨 CRITICAL · RESULTS REACTION ▲ ONE") and "DAY 1 SWING" in o and A.tier(o) == "act", (o, A.tier(o)))
print("\n" + a + "\n")
print("DAY 2-7 SWING test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p264_patch.py $D || back
cd $D && python3 -m py_compile resultreact.py alertword.py || back
echo "=== test"
python3 $W/p264test.py $D || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 264 done - day-2-7 swings shown, not rung. Day-1 swings, the open checks, ⚡ SPEED and the EVENT WATCH still ring."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
