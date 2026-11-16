#!/bin/bash
# PATCH 345 - 🔒 THE ALERT-LOCK SAFETY NET (16 Nov: the engine left tomorrow.db locked three times in the session - "alert log: database is
#   locked" every few seconds, the alerts stopped saving, GIR showed 0 alerts; restarting the engine cleared it each time).
#   lockguard.py + gir-lockguard.timer: every minute in market hours - 6+ "database is locked" in 2 min AND a test write really fails ->
#   restart gir-intraday (at most once every 15 min), the reason in data/lockguard.log. It never changes the database (the test rolls back).
#   This is a stop-gap until the engine's own fix (it needs the engine's code). Nothing else changes. Restarts the engine NOW only if locked.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d)
if [ -f $D/lockguard.py ] && systemctl is-active --quiet gir-lockguard.timer; then echo "patch 345 - already in"; cd $D && python3 lockguard.py check; tail -3 $D/data/lockguard.log 2>/dev/null; exit 0; fi
cat > $W/lockguard.py <<'PY_LG'
"""lockguard.py - patch 345: the SAFETY NET for the alert database lock (16 Nov: the engine left tomorrow.db locked three times - "alert log:
database is locked" every few seconds, the alerts stopped saving, the page showed 0; a restart of the engine cleared it each time).
Every minute in market hours (09:15-15:30, trading days): if the engine logged "database is locked" 6+ times in the last 2 minutes, AND a test
write to tomorrow.db really fails, it restarts gir-intraday once - at most once every 15 minutes - and writes why to data/lockguard.log.
It never touches the database's contents (the test opens a write and rolls it back). The real fix (the engine closing its writes) follows.
python3 lockguard.py check     what it would do now (nothing is restarted)"""
import os, sys, time, json, sqlite3, subprocess, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "tomorrow.db")
LOG = os.path.join(BASE, "data", "lockguard.log")
ST = os.path.join(BASE, "data", "lockguard.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
MIN_MSGS, GAP = 6, 900


def now():
    return dt.datetime.now(IST)


def market(n):
    if n.weekday() > 4:
        return False
    try:
        sys.path.insert(0, BASE)
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return "09:15" <= n.strftime("%H:%M") <= "15:30"


def locked_msgs(minutes=2, run=None):
    run = run or (lambda c: subprocess.run(c, shell=True, capture_output=True, text=True, timeout=30).stdout)
    out = run("journalctl -u gir-intraday --since '%d min ago' --no-pager -o cat 2>/dev/null" % minutes)
    return sum(1 for l in out.splitlines() if "database is locked" in l)


def db_locked(path=DB):
    try:
        c = sqlite3.connect(path, timeout=3)
        c.execute("BEGIN IMMEDIATE"); c.rollback(); c.close()
        return False
    except sqlite3.OperationalError as ex:
        return "locked" in str(ex)
    except Exception:
        return False


def decide(n, msgs, locked, last):
    if not market(n):
        return "market closed - nothing to do"
    if msgs < MIN_MSGS:
        return "fine - %d lock messages in 2 min" % msgs
    if not locked:
        return "%d lock messages but tomorrow.db is free now - no restart" % msgs
    if time.time() - last < GAP:
        return "LOCKED, but the engine was restarted %d min ago - waiting (at most once every 15 min)" % ((time.time() - last) // 60)
    return "RESTART"


def say(line):
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a") as fh:
        fh.write("%s %s\n" % (now().strftime("%Y-%m-%d %H:%M:%S"), line))


def main():
    n = now()
    try:
        last = float(json.load(open(ST)).get("last", 0))
    except Exception:
        last = 0.0
    msgs = locked_msgs(); locked = db_locked()
    d = decide(n, msgs, locked, last)
    if sys.argv[1:2] == ["check"]:
        print("lockguard %s: %s" % (n.strftime("%H:%M:%S"), d if d != "RESTART" else "would RESTART the engine now (%d lock messages, tomorrow.db locked)" % msgs))
        return
    if d == "RESTART":
        subprocess.run("systemctl restart gir-intraday", shell=True, timeout=60)
        json.dump({"last": time.time()}, open(ST, "w"))
        say("RESTARTED gir-intraday - %d 'database is locked' in 2 min and tomorrow.db locked (alerts were not being saved)" % msgs)
    elif "LOCKED" in d:
        say(d)


if __name__ == "__main__":
    main()
PY_LG
cat > $W/p345test.py <<'PY_T'
#!/usr/bin/env python3
"""p345test.py - the lock safety net: its decisions and a real lock test on a temp database (nothing is restarted)"""
import os, sys, time, sqlite3, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); shutil.copy(os.path.join(WK, "lockguard.py"), T); sys.path.insert(0, T)
import lockguard as G
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % got))
G.market = lambda n: n.weekday() < 5 and "09:15" <= n.strftime("%H:%M") <= "15:30"
MON = dt.datetime(2026, 11, 16, 13, 45, tzinfo=IST)
chk("23 lock messages + the db really locked + no restart for an hour -> RESTART", G.decide(MON, 23, True, time.time() - 3600) == "RESTART")
chk("restarted 5 min ago -> waits (at most once every 15 min)", "waiting" in G.decide(MON, 23, True, time.time() - 300))
chk("lock messages but the db free now -> no restart", "no restart" in G.decide(MON, 23, False, 0))
chk("2 messages -> fine", "fine" in G.decide(MON, 2, True, 0))
chk("after the close (15:45) -> nothing", "closed" in G.decide(MON.replace(hour=15, minute=45), 50, True, 0))
p = os.path.join(T, "t.db"); a = sqlite3.connect(p); a.execute("create table x(a)"); a.commit()
chk("a free database reads as free", G.db_locked(p) is False)
a.execute("insert into x values(1)")                                          # an open write, never committed - like the engine
t0 = time.time(); r = G.db_locked(p)
chk("a database with a write left open reads as LOCKED (in about 3 s)", r is True and time.time() - t0 < 6, r)
a.rollback(); a.close()
chk("the log counter reads journal lines", G.locked_msgs(run=lambda c: "x\nalert log: database is locked\nsurges log: database is locked\nok\n") == 2)
print("THE PATCH 345 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
echo "=== test (decisions + a real lock on a temp database; nothing restarted)"
python3 $W/p345test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/lockguard.py $D/lockguard.py && python3 -m py_compile $D/lockguard.py || { rm -f $D/lockguard.py; echo "❌ nothing changed"; exit 1; }
cat > /etc/systemd/system/gir-lockguard.service <<'UNIT'
[Unit]
Description=GIR alert-lock safety net (patch 345) - restarts the engine if tomorrow.db stays locked
[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /home/globalbot/intraday/lockguard.py
UNIT
cat > /etc/systemd/system/gir-lockguard.timer <<'UNIT'
[Unit]
Description=GIR alert-lock safety net every minute
[Timer]
OnCalendar=*-*-* *:*:30
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-lockguard.timer >/dev/null 2>&1 || { rm -f /etc/systemd/system/gir-lockguard.* $D/lockguard.py; systemctl daemon-reload; echo "❌ nothing changed"; exit 1; }
echo "  gir-lockguard.timer: $(systemctl is-active gir-lockguard.timer)"
echo "=== right now:"
cd $D && python3 lockguard.py check
echo "✅ patch 345 done - if the alerts lock again, the engine is restarted within about 2-3 minutes by itself (see: tail $D/data/lockguard.log)."
echo "   undo: systemctl disable --now gir-lockguard.timer; rm /etc/systemd/system/gir-lockguard.*; systemctl daemon-reload"
