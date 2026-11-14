#!/bin/bash
# PATCH 198 - 🧭 TODAY'S PATTERN: what NIFTY did on days like today in GIR's 3 years (Rama, 11 Nov: "after Diwali, before 11:00 we
#   should exit - that is what I expect BEFORE investing in the morning"). The kind of day (after a holiday / Monday / any) and the
#   opening gap -> how often the high came before 11:00 and the gap faded, with what to do. 08:30: in the MORNING BRIEF (each gap) ·
#   09:17: the one line for today's real gap, ringing GIR Box Picks. Shows the 3-year table now. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
FILES="morningbrief.py alertword.py tglanes.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/daypattern.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/daypattern.py <<'PY_DP'
#!/usr/bin/env python3
"""daypattern.py - patch 198: 🧭 TODAY'S PATTERN - what NIFTY did on days like today, in GIR's 3 years (Rama, 11 Nov: the first session
after Diwali opened +1.3%, faded to +0.4% by 14:00 - "after Diwali, before 11:00 we should exit - that is what I expect BEFORE
investing in the morning").
  the kind of day   the first session after a holiday (a weekday with no trading before it) · a Monday · any day
  the opening gap   NIFTY's open against yesterday's close: 0.8%+ up · 0.3-0.8% up · flat · 0.3-0.8% down · 0.8%+ down
  what happened     how often the day's HIGH came before 11:00 · how often it CLOSED BELOW ITS OPEN (the gap faded) ·
                    the average move open -> 11:00 and open -> close
  08:30  the MORNING BRIEF carries it for today's kind of day, for each gap (the gap is not known yet)
  09:17  python3 daypattern.py --send   the gap is known (NSE): the one line that fits, with what to do - it rings
  python3 daypattern.py --study         the full tables and every after-holiday day of the 3 years (nothing sent)"""
import os, sys, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
I11 = 21                                            # the 5-min bar that starts 11:00 (bar 0 = 09:15)
GAPS = [(0.8, 99, "opens +0.8% or more"), (0.3, 0.8, "opens +0.3 to +0.8%"), (-0.3, 0.3, "opens flat (within 0.3%)"),
        (-0.8, -0.3, "opens -0.3 to -0.8%"), (-99, -0.8, "opens -0.8% or more")]


def bar_time(i):
    m = 555 + 5 * int(i)
    return "%02d:%02d" % (m // 60, m % 60)


def rows_of(D, M):
    """every normal session (a full day of 5-min bars) -> dict"""
    ks = sorted(D)
    out = []
    for j in range(1, len(ks)):
        k, kp = ks[j], ks[j - 1]
        x = M.get(k)
        if x is None or x[5].sum() < 70:
            continue                                        # a special / short session (Muhurat) - not a normal day
        pc = D[kp][3]
        o, c = float(x[0][0]), float(x[3][-1])
        if not pc or not o:
            continue
        d0, d1 = dt.date.fromisoformat(kp), dt.date.fromisoformat(k)
        between = [d0 + dt.timedelta(days=i) for i in range(1, (d1 - d0).days)]
        hi = x[1]; lo = x[2]
        out.append({"d": k, "gap": (o / pc - 1) * 100, "o": o, "c": c, "to11": (float(x[3][I11]) / o - 1) * 100, "oc": (c / o - 1) * 100,
                    "hi_i": int(hi.argmax()), "lo_i": int(lo.argmin()), "up": (float(hi.max()) / o - 1) * 100,
                    "after_hol": any(b.weekday() < 5 for b in between), "monday": d1.weekday() == 0})
    return out


def stats(R):
    n = len(R)
    if not n:
        return None
    return {"n": n, "hi11": sum(1 for r in R if r["hi_i"] <= I11), "lo11": sum(1 for r in R if r["lo_i"] <= I11),
            "below": sum(1 for r in R if r["c"] < r["o"]), "to11": statistics.mean(r["to11"] for r in R),
            "oc": statistics.mean(r["oc"] for r in R), "hi_t": bar_time(statistics.median(r["hi_i"] for r in R))}


def advice(st, gap_up):
    if not st or st["n"] < 4:
        return "too few such days to say - trade only what confirms"
    below, above = st["below"] / st["n"], 1 - st["below"] / st["n"]
    if gap_up and below >= 0.55 and st["hi11"] / st["n"] >= 0.55:
        return "the gap usually FADES - book CE profits before 11:00, do not chase the open, fresh CE only after a dip holds"
    if not gap_up and above >= 0.55 and st["lo11"] / st["n"] >= 0.55:
        return "the fall usually RECOVERS - book PE profits before 11:00, do not chase the open"
    if gap_up and above >= 0.6:
        return "the gap usually HOLDS and extends - CE on a dip that holds"
    if not gap_up and below >= 0.6:
        return "the fall usually EXTENDS - PE on a bounce that fails"
    return "no clear pattern - trade only what confirms"


def line(st, label, gap_up):
    if not st:
        return "  %s: no such day in 3 years" % label
    return "  %s (%d days): high before 11:00 on %d · closed below its open on %d · open→11:00 %+.2f%% · open→close %+.2f%% → %s" % (
        label, st["n"], st["hi11"], st["below"], st["to11"], st["oc"], advice(st, gap_up))


def kind_today(today=None):
    """'after a holiday' / 'Monday' / '' for today's session"""
    today = today or dt.datetime.now(IST).date()
    try:
        import holidays
        hol = lambda d: bool(holidays.holiday(d)) and d.weekday() < 5
    except Exception:
        hol = lambda d: False
    d = today - dt.timedelta(days=1)
    skipped = False
    while d.weekday() >= 5 or hol(d):
        if d.weekday() < 5:
            skipped = True
        d -= dt.timedelta(days=1)
    return "after a holiday" if skipped else ("Monday" if today.weekday() == 0 else "")


def pick(R, kind):
    if kind == "after a holiday":
        return [r for r in R if r["after_hol"]]
    if kind == "Monday":
        return [r for r in R if r["monday"] and not r["after_hol"]]
    return R


def load():
    import study3y as S
    return rows_of(S.daily("NIFTY 50"), S.intraday("NIFTY 50"))


def brief_lines(now=None, R=None):
    """the MORNING BRIEF's part (08:30): today's kind of day, each gap"""
    now = now or dt.datetime.now(IST)
    R = R if R is not None else load()
    if not R:
        return []
    kind = kind_today(now.date())
    X = pick(R, kind)
    L = ["🧭 TODAY'S PATTERN · NIFTY on %s in GIR's 3 years (%d days) - the 09:17 line says which one today is:" % (("days " + kind) if kind else "any day", len(X))]
    for lo, hi, lab in GAPS:
        if lab.startswith("opens flat"):
            continue
        L.append(line(stats([r for r in X if lo <= r["gap"] < hi]), "if it " + lab, lo >= 0))
    return L


def today_line(gap, now=None, R=None):
    now = now or dt.datetime.now(IST)
    R = R if R is not None else load()
    kind = kind_today(now.date())
    X = pick(R, kind)
    lo, hi, lab = next(g for g in GAPS if g[0] <= gap < g[1])
    st = stats([r for r in X if lo <= r["gap"] < hi])
    head = "🧭 TODAY'S PATTERN · NIFTY opened %+.2f%%%s · %s" % (gap, (" · the first session " + kind) if kind == "after a holiday" else (" · " + kind if kind else ""), now.strftime("%H:%M"))
    if not st:
        return head + "\nno such day in GIR's 3 years - trade only what confirms"
    return "\n".join([head, "in 3 years, %d days like this (%s%s):" % (st["n"], ("after a holiday, " if kind == "after a holiday" else ""), lab),
                      "  the day's high came before 11:00 on %d of %d · it closed below its open on %d · open→11:00 %+.2f%% · open→close %+.2f%% · the high, typically, %s" % (
                          st["hi11"], st["n"], st["below"], st["to11"], st["oc"], st["hi_t"]),
                      "→ " + advice(st, gap >= 0)])


def nse_open():
    import exchange
    j = exchange.nse_json("/api/allIndices") or {}
    for x in j.get("data") or []:
        if str(x.get("index") or x.get("indexSymbol") or "").upper() == "NIFTY 50":
            o, pc = float(x.get("open") or 0), float(x.get("previousClose") or 0)
            if o and pc:
                return (o / pc - 1) * 100
    return None


def study(R):
    L = ["NIFTY - what the day did, by the kind of day and the opening gap (GIR's 3 years, %d normal sessions)" % len(R)]
    for kind in ("", "after a holiday", "Monday"):
        X = pick(R, kind)
        L.append("")
        L.append("%s (%d days)" % (("DAYS " + kind.upper()) if kind else "ANY DAY", len(X)))
        for lo, hi, lab in GAPS:
            L.append(line(stats([r for r in X if lo <= r["gap"] < hi]), lab, lo >= 0))
    L.append("")
    L.append("every session after a holiday:")
    for r in pick(R, "after a holiday"):
        L.append("  %s gap %+.2f%% · open→11:00 %+.2f%% · high at %s · open→close %+.2f%%%s" % (r["d"], r["gap"], r["to11"], bar_time(r["hi_i"]), r["oc"], " · FADED" if r["gap"] > 0.3 and r["c"] < r["o"] else ""))
    return L


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--send"]:
        now = dt.datetime.now(IST)
        try:
            import holidays
            if holidays.holiday(now.date()) and "--force" not in a:
                print("NSE holiday / weekend - nothing"); sys.exit(0)
        except Exception:
            pass
        g = None
        try:
            g = nse_open()
        except Exception as ex:
            print("NSE allIndices: %s" % ex)
        if g is None:
            print("NIFTY's open not read - nothing sent"); sys.exit(0)
        txt = today_line(g, now)
        print(txt)
        import opencall
        opencall.send_tg(txt)
    elif a[:1] == ["--brief"]:
        print("\n".join(brief_lines()))
    else:
        print("\n".join(study(load())))
PY_DP
cat > $W/p198_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p198_patch.py - PATCH 198: 🧭 TODAY'S PATTERN in the 08:30 MORNING BRIEF, its 09:17 line rings (Box Picks). Usage: python3 p198_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("morningbrief.py", '''    L += ["", "the side is the news only - trade it only if the price confirms after 09:15 · opening call 09:12 · TV WATCH from 09:00"]''',
    '''    try:                                                        # patch 198: what NIFTY did on days like today (3 years)
        import daypattern
        P_ = daypattern.brief_lines(now)
        if P_:
            L += [""] + P_
    except Exception as ex:
        print("daypattern: %s" % ex)
    L += ["", "the side is the news only - trade it only if the price confirms after 09:15 · opening call 09:12 · TV WATCH from 09:00"]''', "the brief carries TODAY'S PATTERN")
rep("alertword.py", '''    if "MORNING BRIEF" in H2:                                  # patch 169: the 08:30 brief rings
        return "move"''', '''    if "MORNING BRIEF" in H2 or "TODAY'S PATTERN" in H2:      # patch 169: the 08:30 brief rings · patch 198: the 09:17 pattern too
        return "move"''', "TODAY'S PATTERN rings")
rep("tglanes.py", '''CRIT_RE = re.compile(r"MORNING BRIEF|''', '''CRIT_RE = re.compile(r"TODAY'S PATTERN|MORNING BRIEF|''', "TODAY'S PATTERN -> Box Picks")
rep("home.html", '''  if(/MORNING BRIEF/.test(H)) return "move";''', '''  if(/MORNING BRIEF|TODAY'S PATTERN/.test(H)) return "move";   /* patch 198 */''', "the page: TODAY'S PATTERN")
if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 198 written")
PY_PATCH
cat > $D/p198test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p198test.py - PATCH 198: TODAY'S PATTERN on a made-up NIFTY (no server data)"""
import os, sys, types, datetime as dt
import numpy as np
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
HOL = {"2026-10-20", "2026-11-10", "2026-09-15", "2026-08-25", "2026-07-14"}
fake = types.ModuleType("holidays"); fake.holiday = lambda d: ("x" if (str(d) in HOL or d.weekday() >= 5) else None); sys.modules["holidays"] = fake
import daypattern as P
D, M = {}, {}
d, px = dt.date(2026, 6, 1), 25000.0
while d <= dt.date(2026, 11, 13):
    if d.weekday() < 5 and str(d) not in HOL:
        k = str(d)
        prev = d - dt.timedelta(days=1)
        while prev.weekday() >= 5:
            prev -= dt.timedelta(days=1)
        after = str(prev) in HOL or (prev - dt.timedelta(days=0)).weekday() < 5 and str(prev) in HOL
        ah = any(str(prev - dt.timedelta(days=i)) in HOL for i in range(0, 4)) and str(prev) in HOL
        if ah:                                              # after a holiday: gap +1.2%, high at 10:00, fade, close below the open
            o = px * 1.012; path = [o * (1 + 0.0004 * i) for i in range(10)] + [o * 1.004 - o * 0.0002 * i for i in range(65)]
        else:                                               # a normal day: flat open, a slow rise, close above the open
            o = px * 1.0005; path = [o * (1 + 0.00005 * i) for i in range(75)]
        x = np.zeros((6, 75), dtype=np.float32); p0 = o
        for i, c in enumerate(path):
            x[:, i] = (p0, max(p0, c) * 1.0001, min(p0, c) * 0.9999, c, 1, 1); p0 = c
        M[k] = x; D[k] = (o, max(path), min(path), path[-1], 1); px = path[-1]
    d += dt.timedelta(days=1)
R = P.rows_of(D, M)
ah = [r for r in R if r["after_hol"]]
check("the sessions after a holiday are found (%d)" % len(ah), len(ah) == 5)
st = P.stats([r for r in ah if r["gap"] >= 0.8])
check("after a holiday, gap +0.8%%+: high before 11:00 %d of %d, closed below the open %d" % (st["hi11"], st["n"], st["below"]), st["n"] == 5 and st["hi11"] == 5 and st["below"] == 5)
t = P.today_line(1.25, now=dt.datetime(2026, 11, 11, 9, 17, tzinfo=P.IST), R=R)
print(t)
check("09:17 on 11 Nov (after Diwali), NIFTY +1.25%: 'the first session after a holiday' + 'FADES - book CE profits before 11:00'", "the first session after a holiday" in t and "FADES" in t and "before 11:00" in t)
b = P.brief_lines(now=dt.datetime(2026, 11, 11, 8, 30, tzinfo=P.IST), R=R)
print("\n".join(b))
check("08:30 brief: today's kind of day (after a holiday) with each gap", b and "days after a holiday" in b[0] and any("opens +0.8% or more (5 days)" in x for x in b))
check("a normal Thursday: the brief uses any day", "any day" in P.brief_lines(now=dt.datetime(2026, 11, 12, 8, 30, tzinfo=P.IST), R=R)[0])
check("a Muhurat-like short session is not a normal day", P.rows_of({"2026-11-07": (1, 1, 1, 1, 1), "2026-11-08": (1, 1, 1, 1, 1)}, {"2026-11-08": np.zeros((6, 75), dtype=np.float32)}) == [])
s = P.study(R)
check("--study lists every after-holiday session, the fades marked", sum(1 for x in s if "FADED" in x) == 5)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 198"
python3 $W/p198_patch.py $D || back
cd $D && python3 -m py_compile daypattern.py morningbrief.py alertword.py tglanes.py || back
echo "=== the test (a made-up NIFTY)"
timeout 60 python3 $D/p198test.py > /tmp/p198test.out 2>&1; R=$?
grep -E "  ok|FAIL|PASSED" /tmp/p198test.out; [ $R = 0 ] || back
cat > $U/gir-daypattern.service <<'UNIT'
[Unit]
Description=GIR TODAY'S PATTERN 09:17 (what NIFTY did on days like today, 3 years)
[Service]
Type=oneshot
TimeoutStartSec=120
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 daypattern.py --send >> data/daypattern.log 2>&1'
UNIT
cat > $U/gir-daypattern.timer <<'UNIT'
[Unit]
Description=GIR TODAY'S PATTERN 09:17 IST, Monday-Friday (it skips NSE holidays itself)
[Timer]
OnCalendar=Mon..Fri *-*-* 09:17:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-daypattern.timer >/dev/null 2>&1
echo "  09:17 line: next $(TZ=Asia/Kolkata date -d "$(systemctl show gir-daypattern.timer -p NextElapseUSecRealtime --value)" '+%a %d %b %H:%M IST' 2>/dev/null)"
echo
echo "=== THE 3-YEAR TABLE (NIFTY)"
cd $D && nice -n 10 timeout 600 python3 daypattern.py --study > $D/data/daypattern_study.txt 2>&1
cat $D/data/daypattern_study.txt
echo
echo "✅ patch 198 done. From tomorrow: the 08:30 brief has 🧭 TODAY'S PATTERN, and at 09:17 the line for today's real gap rings."
