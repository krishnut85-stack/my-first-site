#!/bin/bash
# PATCH 234 - COMPANY in WHO IS PUSHING: only news really about the share, and recent (Rama, 12 Nov: "fix the company news matching now"; the
#   audit: COMPANY on 135 of 218 shares - DATAPATTNS got "India bonds to stay hemmed in by oil" as its company news, and a 10 Nov broker note
#   counted as a push on 12 Nov). A news line counts only when the headline names the company (GIR's name matcher, patch 211) - any other
#   headline shows as "market / other news, not about X itself" (no side); news older than 18 h is context (no side).
#   Tested: 6 cases + the push tests 30 + FII/DII 7 + the simulated day 16; then the server's real name matcher and its 218 shares.
#   Restarts the senders + page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="pushwho.py"; [ -f $D/p215test.py ] && F="$F p215test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p234_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p234_patch.py - PATCH 234: COMPANY in WHO IS PUSHING - only news that is really about the share, and recent (Rama, 12 Nov: "fix the company
news matching now"; the audit: COMPANY lit up on 135 of 218 shares - DATAPATTNS got "India bonds to stay hemmed in by oil" as its company news,
and a broker note from 10 Nov as a push on 12 Nov).
  about it  a news line counts as COMPANY only when the headline names the company (symbol, name, short names - newsalert.about_it, patch 211);
            any other headline the hunt found is shown as "market / other news, not about X itself" - no side
  recent    news older than 18 hours (last evening's news still counts for the morning) is shown as context - no side
Usage: python3 p234_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "pushwho.py"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  pushwho.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  pushwho.py: %s" % tag)


rep('''        if k in ("results", "news", "event"):
            on(7, t[:120], sd)''', '''        if k in ("results", "news", "event"):
            if k == "news":                                     # patch 234: only news about the share, and recent
                hl_ = re.sub(r"^news \\(found by the hunt, [^)]*\\):\\s*|^news [\\d-]+ [\\d:]+:\\s*", "", t)
                if not _about(sym, hl_):
                    on(9, "market / other news, not about %s itself: %s" % (sym, hl_[:100]))
                    continue
                if _old_news(t, now):
                    on(7, t[:120] + " (older than 18 h - context)")
                    continue
            on(7, t[:120], sd)''', "COMPANY: about the share + recent")
rep('''def _filings(sym, hours, routine_only=True):''', '''def _about(sym, h):
    """patch 234: the headline names this share (newsalert.about_it: symbol / name / short names); unknown -> True (as before)"""
    try:
        import newsalert
        return newsalert.about_it(sym, h) is True
    except Exception:
        return True


def _old_news(t, now):
    """patch 234: a 'news MM-DD HH:MM:' line older than 18 hours"""
    m = re.match(r"news (\\d\\d)-(\\d\\d) (\\d\\d):(\\d\\d)", t or "")
    if not m:
        return False
    try:
        ts = now.replace(month=int(m.group(1)), day=int(m.group(2)), hour=int(m.group(3)), minute=int(m.group(4)), second=0, microsecond=0)
        if ts > now + dt.timedelta(days=1):                     # December news read in January
            ts = ts.replace(year=ts.year - 1)
        return (now - ts).total_seconds() > 18 * 3600
    except Exception:
        return False


def _filings(sym, hours, routine_only=True):''', "_about() · _old_news()")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
tp = os.path.join(D, "p215test.py")                                  # GIR's own test (run by the evening audit): its news line had a fixed date
if os.path.exists(tp):
    ts = open(tp, encoding="utf-8").read()
    t2 = ts.replace('"news 11-12 07:05: LIC makes the cut', '"news (found by the hunt, 07:05): LIC makes the cut')
    if "newsalert.py" not in t2:                                     # the test's made-up news must not meet the server's real name matcher
        t2 = t2.replace('open(os.path.join(T, "newsroom.py"), "w")',
                        'open(os.path.join(T, "newsalert.py"), "w").write("def about_it(sym, h, src=\\"\\", name=\\"\\"):\\n    return True\\n")   # patch 234: a stand-in\nopen(os.path.join(T, "newsroom.py"), "w")', 1)
    if t2 != ts:
        open(tp, "w", encoding="utf-8").write(t2); print("  p215test.py: no fixed news date · its own stand-in name matcher (patch 234)")

print("patch 234 in")
PY_PATCH
cat > $W/p234test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p234test.py - COMPANY news in WHO IS PUSHING: about the share + recent (DATAPATTNS 12 Nov; made-up files, nothing sent).
python3 p234test.py DIR   (pushwho.py [, newsalert.py for a live check of the real name matcher])"""
import os, sys, json, shutil, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(D, "pushwho.py"), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 12, 9, 41, tzinfo=IST)
BOND = "news (found by the hunt, 08:18): India bonds to stay hemmed in by oil, Treasury moves ahead of inflation data"
OLD = "news 11-10 15:24: Neutral Data Patterns (India) Ltd For Target Rs.4,040 by Motilal Oswal"
FRESH = "news 11-12 08:40: Data Patterns bags Rs 120 crore defence order"
EVE = "news 11-11 19:30: Data Patterns Q2 profit jumps 40%"
R = {"DATAPATTNS": [{"k": "news", "t": BOND, "side": 1}, {"k": "news", "t": OLD, "side": 1}, {"k": "news", "t": FRESH, "side": 1}],
     "ONLYBOND": [{"k": "news", "t": BOND.replace("found by the hunt", "found by the hunt"), "side": 1}],
     "ONLYOLD": [{"k": "news", "t": OLD.replace("Data Patterns", "Onlyold Corp"), "side": 1}],
     "EVENING": [{"k": "news", "t": EVE.replace("Data Patterns", "Evening Ltd"), "side": 1}]}
open(os.path.join(T, "whymove.py"), "w").write("R = %r\ndef explain(sym, now=None):\n    return {'s': sym, 'chg': 4.0, 'reasons': R.get(sym, [])}\n" % R)
open(os.path.join(T, "newsalert.py"), "w").write('''
N = {"DATAPATTNS": "Data Patterns", "ONLYBOND": "Onlybond Systems", "ONLYOLD": "Onlyold Corp", "EVENING": "Evening Ltd"}
def about_it(sym, h, src="", name=""):
    return N.get(sym, "~") in (h or "")
''')
json.dump({"fo_paths": [{"s": s, "chg": 4.0} for s in R]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"shares": {}}, open(os.path.join(T, "data", "desk.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import pushwho as W
W._F["_inst"] = (9e18, {})
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:300]))
def rows(sym):
    return {x["k"]: x for x in W.read(sym, now=NOW)["rows"]}
r = rows("DATAPATTNS")
chk("DATAPATTNS: COMPANY ▲ from its own fresh news (the ₹120 cr order)", r["COMPANY"]["on"] and r["COMPANY"]["side"] == 1 and "defence order" in r["COMPANY"]["t"], r["COMPANY"])
chk("... the bond-market headline is NOT company news: shown under TIDE as 'not about DATAPATTNS itself', no side", "India bonds" not in r["COMPANY"]["t"] and "not about DATAPATTNS itself" in r["TIDE"]["t"] and r["TIDE"]["side"] == 0, (r["COMPANY"]["t"], r["TIDE"]))
chk("... the 10 Nov broker note is context ('older than 18 h'), not a push", "older than 18 h - context" in r["COMPANY"]["t"], r["COMPANY"]["t"])
r = rows("ONLYBOND")
chk("a share with only an unrelated headline: COMPANY off (was ▲ before)", not r["COMPANY"]["on"], r["COMPANY"])
r = rows("ONLYOLD")
chk("a share with only 2-day-old news: COMPANY shown, no side (not pushing)", r["COMPANY"]["on"] and r["COMPANY"]["side"] == 0, r["COMPANY"])
r = rows("EVENING")
chk("last evening's news (19:30, 14 h before 09:41) still counts for the morning: COMPANY ▲", r["COMPANY"]["on"] and r["COMPANY"]["side"] == 1, r["COMPANY"])
print("COMPANY NEWS test: %d of %d passed" % (sum(OK), len(OK)))
if os.path.exists(os.path.join(D, "newsalert.py")) and os.path.exists(os.path.join(D, "newsroom.py")):   # on the server: the real name matcher
    sys.path.insert(0, D)
    for m in [x for x in list(sys.modules) if x in ("newsalert",)]:
        del sys.modules[m]
    os.chdir(D)
    import importlib, newsalert as NA
    a = NA.about_it("DATAPATTNS", "India bonds to stay hemmed in by oil, Treasury moves ahead of inflation data")
    b = NA.about_it("DATAPATTNS", "Neutral Data Patterns (India) Ltd For Target Rs.4,040 by Motilal Oswal")
    print("  the server's real matcher: bond headline about DATAPATTNS? %s · 'Neutral Data Patterns ...'? %s" % (a, b))
    OK.append(a is not True and b is True)
    print("  %s the real matcher agrees" % ("✅" if (a is not True and b is True) else "❌"))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p234_patch.py $D || back
cd $D && python3 -m py_compile pushwho.py || back
echo "=== test: COMPANY news (DATAPATTNS 12 Nov) + the server's real name matcher"
python3 $W/p234test.py $D || back
if [ -f $D/p215test.py ]; then python3 $D/p215test.py $D 2>&1 | grep -E "❌|passed"; python3 $D/p215test.py $D >/dev/null 2>&1 || back; fi
echo "=== for information: how the real name matcher reads an index-inclusion headline"
cd $D && python3 -c "
import sys; sys.path.insert(0, '/home/globalbot/intraday')
import newsalert as N
for s, h in (('LICI', 'LIC makes the cut in the MSCI Global Standard Index'), ('POLICYBZR', 'IRDAI insurance overhaul pushes PB Fintech to non-insurance services')):
    print('   %-10s %-70s -> %s' % (s, h[:70], N.about_it(s, h)))
" 2>&1 | head -4
echo "=== this server's 218 shares: COMPANY now (before: shown on 135)"
cd $D && timeout 300 python3 - <<'PY'
import sys, json, collections
sys.path.insert(0, "/home/globalbot/intraday")
import pushwho
st = json.load(open("dash_state.json"))
fps = [f["s"] for f in st.get("fo_paths") or [] if f.get("s")]
c = collections.Counter(); ex = collections.defaultdict(list)
for s in fps:
    try:
        r = {x["k"]: x for x in pushwho.read(s)["rows"]}
    except Exception:
        continue
    co, ti = r["COMPANY"], r["TIDE"]
    k = "COMPANY pushing" if co["on"] and co["side"] else "COMPANY context only" if co["on"] else "no COMPANY news"
    c[k] += 1; ex[k].append(s)
    if "not about" in (ti.get("t") or ""):
        c["other news moved to TIDE"] += 1; ex["other news moved to TIDE"].append(s)
for k, n in c.most_common():
    print("   %-26s %3d · e.g. %s" % (k, n, " ".join(ex[k][:8])))
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 234 done - COMPANY means news about that company, from the last 18 hours."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
