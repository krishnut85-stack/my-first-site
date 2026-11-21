#!/bin/bash
# PATCH 145d - THE OVERNIGHT ALERTS ARE NEVER HIDDEN. After 15:30 the alert bar shows what came after the close (results, critical
#   news, filings) with the sound - "DAY'S ALERTS" brings the whole day back. Before 09:15 the list keeps last evening's alerts and
#   the weekend's (they vanished at midnight). dashserve.py · home.html (needs patch 145). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g145d; mkdir -p $W
grep -q "patch 145d" $D/home.html && { echo "patch 145d is already installed"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back() { for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p145dtest.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p145d_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p145d_patch.py - PATCH 145d: THE OVERNIGHT ALERTS ARE NEVER HIDDEN (Rama, 9 Nov 20:20: "the alerts should come to the GIR page,
with some control - else we miss the overnight critical messages"). Patch 145 folded the alert chips after the close; now:
  after 15:30   the chips show what came AFTER the close (results, critical news, the evening's filings) - with the sound, as in
                the day; 'DAY'S ALERTS' brings the whole day back, '🌙 ONLY NEW' returns
  00:00-09:15   the list keeps last evening's alerts (after 15:30) and the weekend's / holiday's - they no longer vanish at midnight
Usage: python3 p145d_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
DASH = [
    ('''def now_rows_(today):
    """NOW: every line that went to Box Picks today, newest first (the same text the phone got)"""
    out = []
    try:
        c = _tom()
        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 60", (today,)):
            lines = [x for x in text.split("\\n") if x.strip()]
            out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})
        c.close()
    except Exception:
        pass
    return out''',
     '''def now_rows_(today, now=None):
    """NOW: every line that went to Box Picks today, newest first (the same text the phone got). patch 145d: before 09:15 also
    the last session's evening (after 15:30) and the days between (a weekend, a holiday) - the overnight alerts stay"""
    out = []
    now = now or dt.datetime.now(IST)
    try:
        c = _tom()
        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 60", (today,)):
            lines = [x for x in text.split("\\n") if x.strip()]
            out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})
        if now.strftime("%H:%M") < "09:15" and len(out) < 60:
            d0 = dt.date.fromisoformat(today) - dt.timedelta(days=1)
            while d0.weekday() > 4:
                d0 -= dt.timedelta(days=1)
            for day, t, kind, sym, side, text in c.execute("select day, t, kind, sym, side, text from alerts where ((day=? and t>='15:30') or (day>? and day<?)) "
                                                           "order by day desc, t desc limit ?", (str(d0), str(d0), today, 60 - len(out))):
                lines = [x for x in text.split("\\n") if x.strip()]
                out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6], "prev": day[5:]})
        c.close()
    except Exception:
        pass
    return out'''),
]
PAGE = [
    ('''body.mclosed #abar:not(.lane) .ac{display:none}''', '''/* patch 145d: after the close the chips show what came after it (never hidden) */'''),
    ('''body.mclosed #abar .al::after{content:" · CLOSED - tap a tab for the day's list";font-weight:400;letter-spacing:0}''',
     '''body.mclosed #abar .al::after{content:" · 🌙 AFTER THE CLOSE";font-weight:400;letter-spacing:0}'''),
    ('''if(ALANE==="all"?(tr==="watch"||!r.s):ln!==ALANE) return;''',
     '''if(ALANE==="all"?(tr==="watch"||!r.s||(aNight()&&!ALLDAY&&!r.prev&&r.t>="09:15"&&r.t<"15:30")):ln!==ALANE) return;   /* patch 145d: after the close - only what came after it */'''),
    ('''<span class="ae">nothing clear-cut yet today — a BUY by the measured rule, your own trade, or a move that is really happening (SUDDEN · SHOCK · RUNNING 3%+) shows here with a sound</span>''',
     '''<span class="ae">${aNight()&&!ALLDAY?"🌙 nothing new since the close — results, critical news and filings that come tonight land here, with a sound · DAY'S ALERTS = the whole day":"nothing clear-cut yet today — a BUY by the measured rule, your own trade, or a move that is really happening (SUDDEN · SHOCK · RUNNING 3%+) shows here with a sound"}</span>'''),
    ('''<div class="ar"><a onclick="selfCheck()"''', '''<div class="ar">${aNight()?`<a class="${ALLDAY?"on":""}" onclick="aDay()" title="after the close: the whole day's alerts / only what came after the close">${ALLDAY?"🌙 ONLY NEW":"DAY'S ALERTS"}</a>`:""}<a onclick="selfCheck()"'''),
    ('''function drawAlerts(force){''', '''/* patch 145d: after the close the ALL tab shows what came after it; DAY'S ALERTS = the whole day */
let ALLDAY=false;
function aNight(){ return typeof mktOpenNow==="function"&&!mktOpenNow(); }
function aDay(){ ALLDAY=!ALLDAY; drawAlerts(true); }
function drawAlerts(force){'''),
    ('''nW,ASND,FOC,ALANE,LC]);''', '''nW,ASND,FOC,ALANE,LC,ALLDAY,aNight()]);'''),
]


def apply(p, eds, tag):
    s = open(p, encoding="utf-8").read()
    if "patch 145d" in s:
        print("patch 145d is already in %s" % os.path.basename(p)); return None
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), os.path.basename(p), a[:90].replace("\n", " | "))); return None
        s = s.replace(a, b)
    return s


def main():
    a = apply(os.path.join(D, "dashserve.py"), DASH, "dash")
    b = apply(os.path.join(D, "home.html"), PAGE, "page")
    if a is None or b is None:
        return 1
    if "patch 145:" not in b:
        print("patch 145 is not installed yet"); return 1
    open(os.path.join(D, "dashserve.py"), "w", encoding="utf-8").write(a)
    open(os.path.join(D, "home.html"), "w", encoding="utf-8").write(b)
    print("patched: dashserve.py, home.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p145dtest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p145dtest.py - patch 145d: before 09:15 the list keeps last evening's (after 15:30) and the weekend's alerts"""
import os, sys, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); p = os.path.join(T, "tom.db")
c = sqlite3.connect(p); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.executemany("insert into alerts values(?,?,?,?,?,?)", [("2026-11-06", "11:00:00", "⚡", "A", "CE", "⚡ ENTER NOW ▲ A CE"), ("2026-11-06", "18:10:00", "🚨", "B", "CE", "🚨 CRITICAL RESULTS ▲ B"),
    ("2026-11-07", "12:00:00", "📄", "C", "PE", "📄 NEWS ▼ C · weekend"), ("2026-11-09", "07:40:00", "📄", "D", "CE", "📄 NEWS ▲ D · morning")])
c.commit(); c.close()
ds._tom = lambda: sqlite3.connect(p)
IST = ds.IST
m = ds.now_rows_("2026-11-09", dt.datetime(2026, 11, 9, 8, 30, tzinfo=IST))
check("Monday 08:30: this morning's + Friday evening's + the weekend's, newest first (%s)" % [(r["t"], r.get("prev")) for r in m], [r["s"] for r in m] == ["D", "C", "B"])
check("Friday 11:00 (the session) is not carried over", all(r["s"] != "A" for r in m))
d = ds.now_rows_("2026-11-09", dt.datetime(2026, 11, 9, 10, 0, tzinfo=IST))
check("after 09:15: only today's", [r["s"] for r in d] == ["D"])
shutil.rmtree(T)
print("P145d TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p145d_patch.py $D || { rm -f $D/p145dtest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p145dtest.py || back
for t in p145dtest.py p145btest.py p143test.py p142test.py p140ftest.py p139test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 145d APPLIED. Reload the GIR page (Ctrl+F5): after the close the alert bar shows what came after it; DAY'S ALERTS = the day."
