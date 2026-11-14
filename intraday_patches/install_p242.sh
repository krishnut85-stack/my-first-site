#!/bin/bash
# PATCH 242 - ☀️ MORNING BRIEF · 📅 THE WEEK at 08:30 (Rama, 13 Nov: "why don't we have a recap daily at 08:30 - what to expect today, based on
#   the previous week, today and next week, all inclusive in GIR"). Right after the morning brief (same 08:30 job, same Box Picks channel),
#   and under the brief on the page (TOMORROW tab). From GIR's own files, read-only:
#   ◀ LAST 5 SESSIONS  F&O shares up / down · strongest and weakest with the fresh-money kind · sectors (their F&O shares' average) ·
#                      last week's results and the price since
#   ● TODAY            results due · the F&O ban and shares near it · the expiry and days left
#   ▶ NEXT 7 DAYS      results day by day · NSE holidays · the expiry
#   💡 WHAT IT MEANS   plain reminders from those facts - not trade calls
#   Tested on a made-up week (13 checks). On this server it prints the real one (nothing sent). First message: the next trading day, 08:30.
#   Restarts only the page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/morningbrief.py ] || { echo "the morning brief (patch 169) is not on this server"; exit 1; }
F="morningbrief.py dashserve.py"; [ -f $D/weekview.py ] && F="$F weekview.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; [ -f $D/weekview.py.bak$TS ] || rm -f $D/weekview.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/weekview.py <<'PY_WEEK'
#!/usr/bin/env python3
"""weekview.py - patch 242: ☀️ MORNING BRIEF · 📅 THE WEEK - at 08:30, right after the brief, to GIR Box Picks (Rama, 13 Nov: "why don't we have
a recap daily at 08:30 - what to expect today, based on the previous week, today and next week, all inclusive in GIR").
Read-only, from GIR's own files:
  LAST 5 SESSIONS  F&O shares up / down, the strongest and weakest (with the fresh-money kind: long build-up ...), sectors (the average of their
                   F&O shares, as SECTORS / ROTATION), last week's results and the price since          (data/oistudy.db · chains.db results_cal)
  TODAY            results due · the F&O ban (no new positions) and shares near it (80%+ of the limit) · the expiry and days left
  NEXT 7 DAYS      results day by day · NSE holidays · the expiry
  WHAT IT MEANS    plain reminders for those facts - not trade calls
  python3 weekview.py            print it (nothing sent)"""
import os, sys, json, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
LIMIT = 3900


def _ro(path):
    return sqlite3.connect("file:%s?mode=ro" % path, uri=True, timeout=5)


def _hol(d):
    try:
        import holidays
        return holidays.holiday(d)
    except Exception:
        return "weekend" if d.weekday() >= 5 else None


def fo_set():
    try:
        c = _ro(os.path.join(BASE, "chains.db")); v = {r[0] for r in c.execute("select sym from fo_list")}; c.close(); return v
    except Exception:
        return set()


def week_moves(fo):
    """the last 6 sessions in oistudy.db -> per share: price % and OI % over 5 sessions, the kind of money"""
    try:
        c = _ro(os.path.join(BASE, "data", "oistudy.db"))
        ds = [r[0] for r in c.execute("select distinct d from day order by d desc limit 6")]
        if len(ds) < 2:
            c.close(); return None
        a, b = ds[-1], ds[0]
        A = {r[0]: r[1:] for r in c.execute("select sym, spot, foi, exp from day where d=?", (a,))}
        B = {r[0]: r[1:] for r in c.execute("select sym, spot, foi, exp from day where d=?", (b,))}
        c.close()
    except Exception:
        return None
    rows = []
    for s, (p1, oi1, e1) in B.items():
        if s not in A or (fo and s not in fo and s not in ("NIFTY", "BANKNIFTY")):
            continue
        p0, oi0, e0 = A[s]
        if not p0 or not p1:
            continue
        pc = (p1 / p0 - 1) * 100
        oc = ((oi1 / oi0 - 1) * 100) if (oi0 and oi1 and e0 == e1) else None     # a contract roll in between: OI not compared
        kind = None
        if oc is not None and abs(pc) >= 0.5 and abs(oc) >= 3:
            kind = ("LONG BUILD-UP" if oc > 0 else "SHORT COVERING") if pc > 0 else ("SHORT BUILD-UP" if oc > 0 else "LONG UNWINDING")
        rows.append({"s": s, "pc": pc, "oc": oc, "kind": kind})
    return {"from": a, "to": b, "n": len(ds) - 1, "rows": rows}


def sector_moves(rows):
    try:
        import sectors
        m = sectors.load()
    except Exception:
        return []
    by = {r["s"]: r["pc"] for r in rows}
    out = []
    for sec, syms in m.items():
        v = [by[s] for s in syms if s in by]
        if len(v) >= 3:
            out.append((sec, sum(v) / len(v), len(v)))
    return sorted(out, key=lambda x: -x[1])


def calendar(today, fo, back=7, ahead=7):
    """results_cal rows from `back` days before to `ahead` days after; the nearest expiry"""
    res, exp = [], None
    try:
        c = _ro(os.path.join(BASE, "chains.db"))
        res = [(d, s) for d, s in c.execute("select d, sym from results_cal where d>=? and d<=? order by d, sym",
                                           (str(today - dt.timedelta(days=back)), str(today + dt.timedelta(days=ahead)))) if not fo or s in fo]
        tabs = {r[0] for r in c.execute("select name from sqlite_master where type='table'")}
        tb = "chain15" if "chain15" in tabs else ("chain" if "chain" in tabs else None)
        if tb:
            d = c.execute("select max(d) from %s" % tb).fetchone()[0]
            e = d and c.execute("select min(exp) from %s where d=? and exp>=?" % tb, (d, str(today))).fetchone()[0]
            if e:
                exp = dt.date.fromisoformat(str(e)[:10])
        c.close()
    except Exception:
        pass
    return res, exp


def since_results(res, today):
    """last week's results -> the price from the close before the results day to the last close (oistudy.db)"""
    out = []
    try:
        c = _ro(os.path.join(BASE, "data", "oistudy.db"))
        for d, s in res:
            if d >= str(today):
                continue
            p0 = c.execute("select spot from day where sym=? and d<? order by d desc limit 1", (s, d)).fetchone()
            p1 = c.execute("select spot, d from day where sym=? order by d desc limit 1", (s,)).fetchone()
            if p0 and p1 and p0[0] and p1[0] and p1[1] >= d:
                out.append((s, d, (p1[0] / p0[0] - 1) * 100))
        c.close()
    except Exception:
        pass
    return sorted(out, key=lambda x: -abs(x[2]))


def bans():
    ban, near = set(), []
    try:
        import desk
        ban = set(desk.ban_list() or [])
    except Exception:
        pass
    try:
        c = _ro(os.path.join(BASE, "data", "extra.db"))
        d = c.execute("select max(d) from mwpl").fetchone()[0]
        if d:
            near = [(s, p) for s, p in c.execute("select sym, pct from mwpl where d=? and pct>=80 order by pct desc", (d,)) if s not in ban]
        c.close()
    except Exception:
        pass
    return sorted(ban), near


def pc(v):
    return ("+" if v > 0 else "") + "%.1f%%" % v


def build(now=None):
    now = now or dt.datetime.now(IST)
    today = now.date()
    fo = fo_set()
    day = lambda d: d.strftime("%a %d %b")
    L = ["☀️ MORNING BRIEF · 📅 THE WEEK · %s · F&O shares" % day(today)]
    W = week_moves(fo)
    if W and W["rows"]:
        R = [r for r in W["rows"] if r["s"] not in ("NIFTY", "BANKNIFTY")]
        up, dn = sum(r["pc"] > 0 for r in R), sum(r["pc"] < 0 for r in R)
        f0, f1 = dt.date.fromisoformat(W["from"]), dt.date.fromisoformat(W["to"])
        L += ["", "◀ LAST %d SESSIONS (%s close → %s close)" % (W["n"], f0.strftime("%a %d"), f1.strftime("%a %d %b"))]
        ix = " · ".join("%s %s" % (r["s"], pc(r["pc"])) for r in W["rows"] if r["s"] in ("NIFTY", "BANKNIFTY"))
        L.append("  %s%d F&O shares up · %d down" % ((ix + " · ") if ix else "", up, dn))
        srt = sorted(R, key=lambda r: -r["pc"])
        tag = lambda r: " (%s)" % r["kind"].lower() if r["kind"] else ""
        L.append("  ▲ strongest: " + " · ".join("%s %s%s" % (r["s"], pc(r["pc"]), tag(r)) for r in srt[:5]))
        L.append("  ▼ weakest: " + " · ".join("%s %s%s" % (r["s"], pc(r["pc"]), tag(r)) for r in srt[::-1][:5]))
        S = sector_moves(R)
        su, sd = [x for x in S if x[1] > 0][:3], [x for x in S[::-1] if x[1] < 0][:3]
        if su or sd:
            L.append("  sectors ▲ %s · ▼ %s" % (" · ".join("%s %s" % (n.upper(), pc(v)) for n, v, k in su) or "none up",
                                               " · ".join("%s %s" % (n.upper(), pc(v)) for n, v, k in sd) or "none down"))
        K = {}
        for r in R:
            if r["kind"]:
                K[r["kind"]] = K.get(r["kind"], 0) + 1
        if K:
            L.append("  fresh money: " + " · ".join("%s %d" % (k.lower(), K.get(k, 0)) for k in ("LONG BUILD-UP", "SHORT BUILD-UP", "SHORT COVERING", "LONG UNWINDING")))
        elif R:
            L.append("  fresh money: not compared - the futures rolled to the next month in between")
    else:
        S = []
        L += ["", "◀ LAST WEEK: GIR's daily F&O file (oistudy) has no sessions yet"]
    res, exp = calendar(today, fo)
    past = since_results(res, today)
    if past:
        L.append("  results last week → price since: " + " · ".join("%s %s" % (s, pc(v)) for s, d, v in past[:8]))
    ban, near = bans()
    t_res = [s for d, s in res if d == str(today)]
    L += ["", "● TODAY · %s" % day(today)]
    L.append("  results today: " + (" · ".join(t_res[:15]) + (" +%d more" % (len(t_res) - 15) if len(t_res) > 15 else "") if t_res else "none"))
    if ban:
        L.append("  F&O ban (no new positions): " + " · ".join(ban))
    if near:
        L.append("  near the ban (80%+ of the limit): " + " · ".join("%s %d%%" % (s, round(p)) for s, p in near[:8]))
    days = (exp - today).days if exp else None
    if exp:
        L.append("  expiry %s · %d days left%s" % (day(exp), days, " - EXPIRY WEEK" if days <= 5 else ""))
    L += ["", "▶ NEXT 7 DAYS"]
    nxt = {}
    for d, s in res:
        if d > str(today):
            nxt.setdefault(d, []).append(s)
    hol = []
    for i in range(1, 8):
        d = today + dt.timedelta(days=i)
        h = _hol(d)
        if h and h != "weekend":
            hol.append((d, h))
    keys = sorted(set(nxt) | {str(d) for d, h in hol} | ({str(exp)} if exp and exp > today and (exp - today).days <= 7 else set()))
    for k in keys:
        d = dt.date.fromisoformat(k); bits = []
        h = dict((str(x), y) for x, y in hol).get(k)
        if h:
            bits.append("🚫 NSE HOLIDAY - %s" % h)
        if exp and k == str(exp):
            bits.append("📆 EXPIRY")
        if nxt.get(k):
            ss = nxt[k]
            bits.append("results: " + " · ".join(ss[:12]) + (" +%d more" % (len(ss) - 12) if len(ss) > 12 else ""))
        L.append("  %s: %s" % (d.strftime("%a %d"), " · ".join(bits)))
    if len(keys) == 0:
        L.append("  no results, holiday or expiry in the next 7 days")
    M = []                                                          # plain reminders - from the facts above, not calls
    if t_res or nxt:
        M.append("results shares: the price follows the number against expectations - GIR rings 🚨 RESULTS REACTION about a minute after the "
                 "filing; act on that, not before. Option premiums are high before results and drop after - buying options just before costs more.")
    if days is not None and days <= 5:
        M.append("expiry week: option premiums lose value fast every day - smaller size, and GIR's time exit is 15:05.")
    elif days is not None and days <= 10:
        M.append("expiry %s: from next week option premiums melt faster - prefer next month's contract for anything you hold over a few days." % exp.strftime("%d %b"))
    if ban:
        M.append("in the ban: no new F&O positions in those shares - only closing.")
    if near:
        M.append("near the ban limit: they can enter the ban any day - then you can only close or reduce, not add or roll over; think before a fresh position.")
    if hol:
        M.append("market shut on %s: options lose the days of the break - avoid buying short-dated options just before it." % " · ".join(d.strftime("%a %d %b") for d, h in hol))
    if S and S[0][1] > 0 and S[-1][1] < 0:
        M.append("last week money went into %s and out of %s - watch ROTATION after 09:20 to see whether it carries on today." % (S[0][0].upper(), S[-1][0].upper()))
    if M:
        L += ["", "💡 WHAT IT MEANS (reminders, not calls)"] + ["  • " + m for m in M]
    txt = "\n".join(L)
    return txt[:LIMIT], {"res_today": len(t_res), "res_next": sum(len(v) for v in nxt.values()), "ban": len(ban), "near": len(near), "exp": str(exp) if exp else None}


_C = {"t": 0.0, "v": ""}


def cached(ttl=300):
    """the page's copy - built at most every 5 minutes (the ban list may wait on NSE)"""
    import time
    if not _C["v"] or time.time() - _C["t"] > ttl:
        _C.update({"v": build()[0], "t": time.time()})
    return _C["v"]


if __name__ == "__main__":
    print(build()[0])
PY_WEEK
cat > $W/p242test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p242test.py - 📅 THE WEEK over a made-up week (Mon 16 Nov 2026; nothing sent).  python3 p242test.py DIR (weekview.py in DIR)"""
import os, sys, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "weekview.py"), T)
open(os.path.join(T, "holidays.py"), "w").write('''import datetime as dt
H = {"2026-11-10": "Diwali Balipratipada", "2026-11-20": "Test Holiday"}
def holiday(d):
    d = dt.date.fromisoformat(str(d)) if not isinstance(d, dt.date) else d
    return "weekend" if d.weekday() >= 5 else H.get(str(d))
''')
open(os.path.join(T, "sectors.py"), "w").write('''def load():
    return {"Realty": ["DLF", "LODHA", "GODREJPROP"], "Textiles": ["PAGEIND"], "Insurance": ["HDFCLIFE", "SBILIFE", "POLICYBZR"], "Auto": ["MARUTI", "TVSMOTOR", "EICHERMOT"]}
''')
open(os.path.join(T, "desk.py"), "w").write("def ban_list():\n    return {'KAYNES'}\n")
SY = {"DLF": (700, 5), "LODHA": (1200, 6), "GODREJPROP": (2000, 4), "PAGEIND": (36000, -13), "HDFCLIFE": (700, 4), "SBILIFE": (1800, 3),
      "POLICYBZR": (1700, 9), "MARUTI": (12000, -2), "TVSMOTOR": (2500, -3), "EICHERMOT": (6000, -1), "KAYNES": (5000, -6), "ROLLED": (100, 2), "NIFTY": (25000, 1.2)}
c = sqlite3.connect(os.path.join(T, "data", "oistudy.db"))
c.execute("create table day(d text, sym text, spot real, foi real, exp text, primary key(d, sym))")
days = ["2026-11-05", "2026-11-06", "2026-11-09", "2026-11-11", "2026-11-12", "2026-11-13"]
for i, d in enumerate(days):
    for s, (p, ch) in SY.items():
        oi = 1e6 * (1 + (0.10 if ch > 0 and s != "POLICYBZR" else 0.08 if s == "PAGEIND" else -0.05) * i / 5)
        c.execute("insert into day values(?,?,?,?,?)", (d, s, p * (1 + ch / 100 * i / 5), oi, "2026-12" if (s == "ROLLED" and i == 5) else "2026-11"))
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "chains.db"))
c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,1)", [(s,) for s in SY if s != "NIFTY"])
c.execute("create table results_cal(d text, sym text, purpose text)")
c.executemany("insert into results_cal values(?,?,'')", [("2026-11-12", "PAGEIND"), ("2026-11-11", "POLICYBZR"), ("2026-11-16", "EICHERMOT"),
               ("2026-11-17", "MARUTI"), ("2026-11-17", "TVSMOTOR"), ("2026-11-19", "SBILIFE"), ("2026-11-17", "NOTFO")])
c.execute("create table chain15(d text, t text, sym text, exp text, kind text, oi real)")
c.execute("insert into chain15 values('2026-11-13','15:29','DLF','2026-11-23','CE',1)"); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "data", "extra.db")); c.execute("create table mwpl(d text, sym text, mwpl real, oi real, pct real)")
c.executemany("insert into mwpl values('2026-11-13',?,1,1,?)", [("KAYNES", 97), ("RBLBANK", 88), ("IEX", 81), ("DLF", 40)]); c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)
import weekview as W
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
txt, n = W.build(dt.datetime(2026, 11, 16, 8, 30, tzinfo=IST))
print(txt); print("-" * 60)
OK = []
def chk(name, c):
    OK.append(bool(c)); print("  %s %s" % ("✅" if c else "❌", name))
chk("last 5 sessions: Thu 05 → Fri 13 (the Diwali holiday skipped)", "LAST 5 SESSIONS (Thu 05 close → Fri 13 Nov close)" in txt)
chk("NIFTY shown with the week's %", "NIFTY +1.2%" in txt)
chk("strongest POLICYBZR +9.0% first; PAGEIND weakest -13.0% with short build-up", "strongest: POLICYBZR +9.0%" in txt and "weakest: PAGEIND -13.0% (short build-up)" in txt)
RR = {r["s"]: r for r in W.week_moves(W.fo_set())["rows"]}
chk("a rolled contract: no OI compared, no kind", RR["ROLLED"]["oc"] is None and RR["ROLLED"]["kind"] is None and RR["DLF"]["kind"] == "LONG BUILD-UP")
chk("sectors (3+ shares) from the F&O shares' average: ▲ INSURANCE, REALTY · ▼ AUTO only (no overlap)", "sectors ▲ INSURANCE +5.3% · REALTY +5.0% · ▼ AUTO -2.0%\n" in txt)
chk("results last week → price since: PAGEIND, POLICYBZR", "results last week → price since: PAGEIND" in txt and "POLICYBZR" in txt.split("price since:")[1].split("\n")[0])
chk("today: EICHERMOT results; ban KAYNES; near the ban RBLBANK 88% IEX 81% (KAYNES not repeated)", "results today: EICHERMOT" in txt and "F&O ban (no new positions): KAYNES" in txt and "near the ban (80%+ of the limit): RBLBANK 88% · IEX 81%" in txt)
chk("expiry Mon 23 Nov · 7 days left", "expiry Mon 23 Nov · 7 days left" in txt)
chk("next 7 days: Tue 17 MARUTI TVSMOTOR (NOTFO not F&O - out), Thu 19 SBILIFE, Fri 20 holiday, Mon 23 expiry",
    "Tue 17: results: MARUTI · TVSMOTOR" in txt and "NOTFO" not in txt and "Thu 19: results: SBILIFE" in txt and "Fri 20: 🚫 NSE HOLIDAY - Test Holiday" in txt and "Mon 23: 📆 EXPIRY" in txt)
chk("what it means: results, expiry, ban, near-ban, holiday, rotation reminders", all(k in txt for k in ("RESULTS REACTION", "expiry 23 Nov", "only closing", "near the ban limit", "market shut on Fri 20 Nov", "watch ROTATION")))
chk("fits one Telegram message (%d characters)" % len(txt), len(txt) <= 3900)
txt2, n2 = W.build(dt.datetime(2026, 11, 20, 8, 30, tzinfo=IST))
chk("expiry week (Fri 20 Nov: 3 days left) says EXPIRY WEEK", "3 days left - EXPIRY WEEK" in txt2 and "expiry week: option premiums" in txt2)
for f in ("chains.db", "data/oistudy.db", "data/extra.db"):
    os.remove(os.path.join(T, f))
txt3, n3 = W.build(dt.datetime(2026, 11, 16, 8, 30, tzinfo=IST))
chk("no data files: still a message, no crash", txt3.startswith("☀️ MORNING BRIEF · 📅 THE WEEK") and "no sessions yet" in txt3)
print("THE WEEK test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p242_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p242_patch.py - PATCH 242: 📅 THE WEEK goes out right after the ☀️ MORNING BRIEF at 08:30 (same job, same channel) and shows under the brief
on the page (TOMORROW tab). Usage: python3 p242_patch.py DIR"""
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


rep("morningbrief.py", '''    print(txt)
    if "--send" in sys.argv:
        import opencall
        opencall.send_tg(txt)''', '''    print(txt)
    if "--send" in sys.argv:
        import opencall
        opencall.send_tg(txt)
    try:                                                        # patch 242: 📅 THE WEEK - last 5 sessions, today, the next 7 days
        import time, weekview
        wk = weekview.build(now)[0]
        print("\\n" + wk)
        if "--send" in sys.argv:
            time.sleep(3)
            opencall.send_tg(wk)
    except Exception as ex:
        print("weekview: %s" % ex)''', "08:30: THE WEEK right after the brief")
rep("dashserve.py", '''                    return self.send(200, morningbrief.build()[0], "text/plain; charset=utf-8")''',
    '''                    tx_ = morningbrief.build()[0]
                    try:                                    # patch 242: 📅 THE WEEK under the brief
                        import weekview
                        tx_ += "\\n\\n" + weekview.cached()
                    except Exception:
                        pass
                    return self.send(200, tx_, "text/plain; charset=utf-8")''', "the page: THE WEEK under the brief")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 242 in")
PY_PATCH
cd $D && python3 -m py_compile weekview.py || back
echo "=== test: a made-up week"
python3 $W/p242test.py $D | sed -n '/^---/,$p'; python3 $W/p242test.py $D >/dev/null 2>&1 || back
python3 $W/p242_patch.py $D || back
cd $D && python3 -m py_compile morningbrief.py dashserve.py weekview.py || back
echo "=== THE WEEK from this server's own data (nothing sent):"
cd $D && timeout 120 python3 weekview.py || back
systemctl restart gir-dash 2>/dev/null; sleep 4; echo "  gir-dash: $(systemctl is-active gir-dash)"
echo "✅ patch 242 done - 📅 THE WEEK goes out at 08:30 on the next trading day, right after the morning brief; on the page under the brief (TOMORROW)."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
