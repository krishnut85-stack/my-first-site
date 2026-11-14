#!/bin/bash
# PATCH 258b - the 08:20 RESULTS brief lists only real results FILINGS (Saturday's run listed GRASIM / AMBER / PAGEIND / IDEA as "numbers not read
#   yet" - those were news stories about results). Tested: 9 cases. Prints Monday's brief again (nothing sent). No restart - safe any time.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d)
[ -f $D/resultsday.py ] || { echo "patch 258 first"; exit 1; }
cp $D/resultsday.py $D/resultsday.py.bak258b
back(){ cp $D/resultsday.py.bak258b $D/resultsday.py; echo "❌ old file back"; exit 1; }
cat > $D/resultsday.py <<'PY_RD'
#!/usr/bin/env python3
"""resultsday.py - patch 258: ☀️ MORNING BRIEF · 📑 RESULTS at 08:20 on trading days (Rama, 13 Nov: "for Monday keep the list for me at 08:20 -
what to expect from the quarterly results"). One message to GIR Box Picks, from GIR's own files:
  ◀ FILED SINCE THE LAST CLOSE   every F&O share that filed results after the last session's 15:30 (the weekend too): GIR's verdict, the
                                 numbers, the plain read - these move at 09:15
  ● DUE TODAY                    the results calendar: what the brokers expect (expect.db), how the share moved after its last results
  💡 HOW TO TRADE IT             the reminders that matter on a results morning - not calls
  python3 resultsday.py            print it (nothing sent)        python3 resultsday.py --send     the 08:20 job"""
import os, re, sys, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
VERDICT = re.compile(r"\b(BIG BEAT|BIG MISS|BEAT|MISS|IN LINE|STRONG|STEADY|MIXED|FLAT|WEAK)\b")
LIMIT = 3900


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def holiday(d):
    try:
        import holidays
        return holidays.holiday(d)
    except Exception:
        return "weekend" if d.weekday() >= 5 else None


def last_close(now):
    d = now.date() - dt.timedelta(days=1)
    while holiday(d):
        d -= dt.timedelta(days=1)
    return dt.datetime.combine(d, dt.time(15, 30), IST)


def fo_set():
    try:
        c = _ro("chains.db"); v = {r[0] for r in c.execute("select sym from fo_list")}; c.close(); return v
    except Exception:
        return set()


def filed_since(start, now, fo):
    """{sym: {"t", "head", "nums", "plain"}} - GIR's results lines after start (tomorrow.db alerts), the most complete one per share"""
    out = {}
    try:
        c = _ro("tomorrow.db")
        rows = c.execute("select day, t, text from alerts where day>=? and day<=? order by day, t", (str(start.date()), str(now.date()))).fetchall()
        c.close()
    except Exception:
        return out
    for day, t, tx in rows:
        try:
            ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST)
        except Exception:
            continue
        if ts < start or ts > now:
            continue
        L = [x for x in (tx or "").split("\n") if x.strip()]
        if not L or "RESULTS" not in L[0] or "RESULTS REACTION" in L[0] or "EVENT WATCH" in L[0]:
            continue
        if L[0].startswith("📰") or re.search(r"\bNEWS\b", L[0].split("·")[0]):    # a story about results is not a filing (GRASIM "profit triples")
            continue
        m = re.search(r"([▲▼])?\s*\b([A-Z][A-Z0-9&\-]{1,19})\s+·\s+RESULTS\b", L[0]) or re.search(r"RESULTS\s+[▲▼]?\s*([A-Z][A-Z0-9&\-]{1,19})\b", L[0])
        sym = (m.group(2) if m and m.lastindex == 2 else m.group(1)) if m else None
        if not sym or (fo and sym not in fo):
            continue
        body = " | ".join(L)
        nums = next((x for x in re.split(r"\s*\|\s*", body) if re.search(r"\b(revenue|profit|loss)\b", x, re.I) and "₹" in x), "")
        plain = next((x for x in re.split(r"\s*\|\s*", body) if x.lower().startswith("plain read")), "")
        v = VERDICT.search(L[0])
        rec = {"t": ts, "head": L[0], "verdict": v.group(1) if v else "", "nums": nums, "plain": plain,
               "side": 1 if "▲" in L[0] else -1 if "▼" in L[0] else 0}
        old = out.get(sym)
        score = lambda r: (bool(r["nums"]), bool(r["verdict"]), bool(r["plain"]), r["t"])
        if not old or score(rec) >= score(old):
            out[sym] = rec
    return out


def due_today(now, fo):
    try:
        c = _ro("chains.db")
        rows = [r[0] for r in c.execute("select distinct sym from results_cal where d=? order by sym", (str(now.date()),))]
        c.close()
        return [s for s in rows if not fo or s in fo]
    except Exception:
        return []


def expected(sym, now):
    try:
        import expect
        return expect.expected_line(sym, now.date()) or ""
    except Exception:
        return ""


def past_moves(sym, n=4):
    """how the share moved the next day after its last results (expect.db react) -> 'last 4: +3.1% −2.0% +0.4% −5.2% (avg ±2.7%)'"""
    try:
        c = _ro(os.path.join("data", "expect.db"))
        rows = c.execute("select q, d1 from react where sym=? and d1 is not null", (sym,)).fetchall()
        c.close()
        def qk(q):                                              # "Q1 FY27" -> (27, 1): the newest first
            m = re.search(r"Q(\d)\D*FY\s*(\d+)", q or "")
            return (int(m.group(2)), int(m.group(1))) if m else (0, 0)
        r = [d for q, d in sorted(rows, key=lambda x: qk(x[0]), reverse=True)][:n]
    except Exception:
        return ""
    if not r:
        return ""
    return "after its last %d results the next day: %s (typical move ±%.1f%%)" % (len(r), " ".join("%+.1f%%" % x for x in r), sum(abs(x) for x in r) / len(r))


def short(s, n):
    s = re.sub(r"\s+", " ", s or "").strip()
    return s if len(s) <= n else s[:n - 1] + "…"


def build(now=None):
    now = now or dt.datetime.now(IST)
    fo = fo_set()
    start = last_close(now)
    F = filed_since(start, now, fo)
    T = [s for s in due_today(now, fo) if s not in F]
    L = ["☀️ MORNING BRIEF · 📑 RESULTS · %s · F&O shares" % now.strftime("%a %d %b")]
    if F:
        L += ["", "◀ FILED SINCE %s 15:30 - they move at 09:15 (%d)" % (start.strftime("%a"), len(F))]
        order = sorted(F.items(), key=lambda kv: (0 if kv[1]["verdict"] in ("BIG MISS", "BIG BEAT", "MISS", "WEAK") else 1, kv[1]["t"]))
        for sym, r in order[:14]:
            ar = "▲" if r["side"] > 0 else "▼" if r["side"] < 0 else "·"
            L.append("%s %s · %s · filed %s" % (ar, sym, r["verdict"] or "numbers not read yet", r["t"].strftime("%a %H:%M")))
            if r["nums"]:
                L.append("   " + short(r["nums"], 170))
            if r["plain"]:
                L.append("   " + short(r["plain"], 120))
            pm = past_moves(sym)
            if pm:
                L.append("   " + pm)
        if len(F) > 14:
            L.append("   … %d more on GIR (RESULTS)" % (len(F) - 14))
    else:
        L += ["", "◀ FILED SINCE %s 15:30: none" % start.strftime("%a")]
    L += ["", "● DUE TODAY (%d)" % len(T)]
    if T:
        for sym in T[:14]:
            ex, pm = expected(sym, now), past_moves(sym)
            L.append("  %s%s" % (sym, (" · " + ex) if ex else " · no broker estimate found"))
            if pm:
                L.append("     " + pm)
        if len(T) > 14:
            L.append("  … %d more on GIR (RESULTS)" % (len(T) - 14))
    else:
        L.append("  none on the calendar")
    L += ["", "💡 HOW TO TRADE IT (reminders, not calls)",
          "  • filed overnight: the 09:08 pre-open shows the gap; GIR's 🚨 RESULTS REACTION after 09:15 is the verdict - the price, not the headline",
          "  • a big gap often bounces first: wait for the first 15 min, do not chase the opening candle",
          "  • due today: options are dearest before the number and cheap after it - buy after the number, not before",
          "  • a ▲ verdict with the price falling (or ▼ with it rising) = the market expected more: follow the price"]
    txt = "\n".join(L)
    return txt[:LIMIT], {"filed": len(F), "due": len(T)}


if __name__ == "__main__":
    now = dt.datetime.now(IST)
    if "--send" in sys.argv and holiday(now.date()) and "--force" not in sys.argv:
        print("NSE holiday / weekend - no results brief"); sys.exit(0)
    txt, n = build(now)
    print(txt)
    if "--send" in sys.argv:
        import opencall
        opencall.send_tg(txt)
PY_RD
cat > $W/p258test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p258test.py - the 08:20 results brief on a made-up Monday 16 Nov (Fri 13 + Sat 14 filings; nothing sent). python3 p258test.py DIR"""
import os, sys, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "resultsday.py"), T)
open(os.path.join(T, "holidays.py"), "w").write("import datetime as dt\ndef holiday(d):\n    return 'weekend' if d.weekday() >= 5 else None\n")
open(os.path.join(T, "expect.py"), "w").write("E = {'TVSMOTOR': 'brokers expect Q2 FY27 profit ₹820 cr (+24% YoY) · 4 brokers'}\ndef expected_line(sym, when=None):\n    return E.get(sym, '')\n")
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)")
c.executemany("insert into fo_list values(?,1)", [(s,) for s in ("INOXWIND", "EICHERMOT", "ASHOKLEY", "KAYNES", "TVSMOTOR", "GRASIM")])
c.execute("create table results_cal(d text, sym text, purpose text)")
c.executemany("insert into results_cal values(?,?,'')", [("2026-11-16", "TVSMOTOR"), ("2026-11-16", "KAYNES"), ("2026-11-16", "NOTFO"), ("2026-11-17", "GRASIM")]); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "data", "expect.db")); c.execute("create table react(sym text, q text, base real, d1 real, d3 real, intraday int)")
c.executemany("insert into react values(?,?,0,?,0,0)", [("INOXWIND", "Q1 FY27", -6.2), ("INOXWIND", "Q4 FY26", 4.1), ("TVSMOTOR", "Q1 FY27", 2.3), ("TVSMOTOR", "Q4 FY26", -1.1)]); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
A = [("2026-11-13", "14:20:00", "🚨 CRITICAL RESULTS ▼ GRASIM · RESULTS · MISS · NSE 14:19\nrevenue ₹50,105 cr +26% YoY · profit ₹1,029 cr -35% YoY"),
     ("2026-11-13", "17:54:39", "🚨 RESULTS · INOXWIND · just filed on NSE 17:53:58 (seen in 41s)\nreading the numbers now"),
     ("2026-11-13", "17:56:15", "🚨 CRITICAL RESULTS ▼ INOXWIND · RESULTS · MISS YoY · 70% BELOW ESTIMATES · NSE 17:53:58 (read in 132s)\n🟠 SOMETHING IS HAPPENING\nOutcome of Board Meeting\nrevenue ₹1,354 cr +21% YoY · profit ₹69 cr -43% YoY · +7% QoQ · EBITDA margin 16.9% (-734 bps YoY)\nplain read: WEAK - sales grew 21% but profit fell 43%"),
     ("2026-11-13", "17:52:00", "📰 NEWS ▲ EICHERMOT · RESULTS · BEAT · NSE 17:48\nrevenue ₹7,159 cr +21% YoY · profit ₹1,325 cr +10% YoY\nplain read: STEADY - sales up, margins a little lower"),
     ("2026-11-14", "16:05:00", "🚨 CRITICAL RESULTS ▲ ASHOKLEY · RESULTS · BEAT · NSE 16:04\nrevenue ₹10,900 cr +12% YoY · profit ₹830 cr +18% YoY"),
     ("2026-11-13", "18:12:07", "📰 NEWS ▲ INOXWIND · RESULTS · investywise.com 18:01\nInox Wind reports Q2 FY27 earnings presentation"),
     ("2026-11-13", "13:00:00", "🚨 RESULTS REACTION ▲ ABB · 13:00"),
     ("2026-11-13", "19:23:00", "📰 NEWS · GRASIM · RESULTS · livemint.com 19:20\nGrasim Industries Q2 profit triples: how a ₹3,968 crore dividend cushioned a one-time loss"),
     ("2026-11-13", "18:35:00", "📰 NEWS ▼ AMBER · RESULTS · upstox.com 18:30\nAmber Enterprises shares in focus after Q2")]
for d, t, x in A:
    c.execute("insert into alerts values(?,?,'','','',?)", (d, t, x))
c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)
import resultsday as R
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
txt, n = R.build(dt.datetime(2026, 11, 16, 8, 20, tzinfo=IST))
print(txt); print("-" * 60)
OK = []
def chk(name, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", name, "" if c else "   got: %s" % str(got)[:200]))
chk("filed since Fri 15:30: INOXWIND, EICHERMOT, ASHOKLEY (Saturday too) - not GRASIM (14:20, before the close)", n["filed"] == 3 and "GRASIM ·" not in txt.split("● DUE")[0], n)
chk("INOXWIND: the complete 17:56 line (MISS, numbers, plain read), not the 17:54 'just filed' one", "▼ INOXWIND · MISS" in txt and "profit ₹69 cr -43%" in txt and "plain read: WEAK" in txt, txt)
chk("the misses first: INOXWIND before EICHERMOT", txt.index("INOXWIND ·") < txt.index("EICHERMOT ·"), "")
chk("INOXWIND's past reactions: -6.2% +4.1%", "-6.2% +4.1%" in txt, "")
chk("due today: TVSMOTOR with the brokers' estimate, KAYNES with none; NOTFO left out", "TVSMOTOR · brokers expect Q2 FY27 profit ₹820 cr" in txt and "KAYNES · no broker estimate found" in txt and "NOTFO" not in txt, "")
chk("a RESULTS REACTION or a news story about results is not a filing (ABB, the 18:12 INOXWIND news)", "ABB" not in txt and txt.count("INOXWIND ·") == 1, "")
chk("news stories about results are not filings: no GRASIM 19:23, no AMBER", "GRASIM ·" not in txt.split("● DUE")[0] and "AMBER" not in txt, txt)
chk("fits one Telegram message (%d chars)" % len(txt), len(txt) <= 3900)
txt2, n2 = R.build(dt.datetime(2026, 11, 17, 8, 20, tzinfo=IST))
chk("Tuesday: only what was filed after Monday 15:30 (none here) · GRASIM due", n2["filed"] == 0 and "GRASIM" in txt2, n2)
print("RESULTS BRIEF test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cd $D && python3 -m py_compile resultsday.py || back
python3 $W/p258test.py $D | tail -1; python3 $W/p258test.py $D >/dev/null 2>&1 || back
echo "=== Monday's brief now (nothing sent):"
cd $D && timeout 90 python3 -c "
import sys, datetime as dt; sys.path.insert(0, '$D')
import resultsday as R
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); now = dt.datetime.now(IST)
d = now.date() + dt.timedelta(days=1)
while R.holiday(d): d += dt.timedelta(days=1)
print(R.build(dt.datetime.combine(d, dt.time(8, 20), IST))[0])" || back
echo "✅ patch 258b done"
