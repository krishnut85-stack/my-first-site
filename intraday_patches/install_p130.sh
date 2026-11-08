#!/bin/bash
# PATCH 130 - GIR TRADES EVERY SESSION (on top of patch 127; 128 / 129 not needed first).
#   Sun 8 Nov 2026: the Diwali Muhurat session - only the desk knew it, the ENGINE slept (no live shares, OI, alerts).
#   - sessions.py: one list of sessions for every service: normal Mon-Fri 09:15-15:30, NSE holidays, special sessions
#     (data/sessions.json + built-in) - add one:  python3 sessions.py add 2027-02-06 09:15 15:30 "Budget day"
#   - the engine runs a special session like a normal day inside its window (starts 13 min before the open), sends a
#     Telegram note the day before and at the start, and does not stop on the empty bars before the special open
#   - the safety net: on a day GIR has as closed it looks every 3 minutes whether NIFTY trades anyway - if so, it writes
#     the day as a special session and starts by itself
#   engine2.py, exchange.py, dashserve.py (exact anchors) · sessions.py (new). Restarts gir-intraday, gir-exchange, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g130; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p130.sh now"; exit 1; fi
grep -q "def topic" $D/tglanes.py 2>/dev/null || { echo "patch 127 is not installed yet - paste patch 127 first"; exit 1; }
grep -q "def _special_pre" $D/engine2.py && { echo "patch 130 is already installed"; exit 1; }
F="engine2.py exchange.py dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/sessions.py $D/p130test.py; systemctl restart gir-exchange gir-dash; pgrep -f "engine2.run_day" >/dev/null || systemctl restart gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p130_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p130_patch.py - PATCH 130: GIR TRADES EVERY SESSION. The engine follows sessions.py: special sessions (Muhurat,
Budget-day weekend sessions ...) run like a normal day inside their window; the day before, a Telegram note; on a "closed"
day, a look every 3 minutes whether NIFTY trades anyway (then it starts by itself). exchange.py / dashserve.py say
"market open" in a special session too.
Usage: python3 p130_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''    if hol and hol != "weekend" and not done:
''', '''    try:                                                   # patch 130: the special sessions (Muhurat ...) - sessions.py
        import sessions as _ses
        ses = _ses.session(now.date())
    except Exception as ex:
        log("sessions: %s" % str(ex)[:80]); ses = None
    special = bool(ses and ses.get("special"))
    if hol and hol != "weekend" and not done and not special:
'''),
        ('''    if now.weekday() < 5 and not done and start <= now < now.replace(hour=15, minute=40):
''', '''    if special and not done:                               # patch 130: a special session today - the engine runs its window
        h0, m0 = [int(x) for x in ses["open"].split(":")]
        h1, m1 = [int(x) for x in ses["close"].split(":")]
        s_open = now.replace(hour=h0, minute=m0, second=0, microsecond=0)
        s_close = now.replace(hour=h1, minute=m1, second=0, microsecond=0)
        if s_open - dt.timedelta(minutes=13) <= now < s_close + dt.timedelta(minutes=10):
            if once(con, day, "special_on"):
                core.tg("🪔 SPECIAL SESSION today %s-%s (%s) - GIR's live feed, OI scanning and alerts are ON" % (ses["open"], ses["close"], ses["name"]))
            try:
                run_day(cfg2())
            except Exception as ex:
                import traceback
                traceback.print_exc()
                if any(once(con, day, "err%d" % i) for i in range(3)):
                    core.tg("⚠️ INTRADAY v2 error (special session): %s — restarting in 30 s" % str(ex)[:200])
                sys.exit(1)
            once(con, day, "done")
            sys.exit(0)
    if now.weekday() < 5 and not done and not special and start <= now < now.replace(hour=15, minute=40):
'''),
        ('''    log("sleeping until", nxt)
    sleep_until(nxt)
    sys.exit(0)''', '''    try:                                                   # patch 130: a special session before that -> wake up for it
        import sessions as _ses2
        sp_t, sp_s = _ses2.next_special(dt.datetime(now.year, now.month, now.day, now.hour, now.minute, tzinfo=_ses2.IST))
        if sp_t is not None:
            sp_n = sp_t.replace(tzinfo=None) - dt.timedelta(minutes=13)
            if sp_n < nxt:
                nxt = max(sp_n, now + dt.timedelta(seconds=5))
                if once(con, day, "special_notice_%s" % sp_t.date()):
                    core.tg("🪔 SPECIAL SESSION %s %s-%s (%s) - GIR will run it: live feed, OI scanning, alerts" % (
                        sp_t.strftime("%a %d %b"), sp_s["open"], sp_s["close"], sp_s["name"]))
        if _ses2.session(now.date()) is None and "09:00" <= now.strftime("%H:%M") <= "21:00":
            try:                                           # the safety net: NIFTY trading on a day GIR has as closed
                found = _ses2.detect(core.get_kite(cfg2()), dt.datetime(now.year, now.month, now.day, now.hour, now.minute, now.second, tzinfo=_ses2.IST))
                if found:
                    core.tg("🪔 NIFTY is trading today although GIR had the day as closed - a special session. GIR's live feed is starting now.")
                    log("special session detected - restarting into it")
                    sys.exit(0)
            except SystemExit:
                raise
            except Exception as ex:
                log("special-session check: %s" % str(ex)[:80])
            nxt = min(nxt, now + dt.timedelta(minutes=3))  # a closed day: look again in 3 minutes
    except SystemExit:
        raise
    except Exception as ex:
        log("sessions: %s" % str(ex)[:80])
    log("sleeping until", nxt)
    sleep_until(nxt)
    sys.exit(0)'''),
        ('''            if j >= 2 and len(nif_today["ts"]) == 0:
                if feed.poll < 30:
                    try:
                        probe = engine.today_bars''', '''            if j >= 2 and len(nif_today["ts"]) == 0 and not _special_pre(close_t):   # patch 130: before a special open = empty by design
                if feed.poll < 30:
                    try:
                        probe = engine.today_bars'''),
        ('''
def main():
''', '''
def _special_pre(close_t):
    """patch 130: a bar before a special session's open (or its first 10 minutes) is empty by design - skip it, never stop the day"""
    try:
        import sessions
        s = sessions.session(close_t.date())
        if s and s.get("special"):
            h, m = [int(x) for x in s["open"].split(":")]
            return close_t <= close_t.replace(hour=h, minute=m, second=0, microsecond=0) + dt.timedelta(minutes=10)
    except Exception:
        pass
    return False


def main():
'''),
    ],
    "exchange.py": [
        ('''def is_open(hm):
    try:
        import holidays''', '''def is_open(hm):
    try:                                                     # patch 130: a special session (Muhurat ...) is open too
        import sessions
        s_ = sessions.session(hm.date())
        if s_ and s_.get("special"):
            return s_["open"] <= hm.strftime("%H:%M") <= s_["close"]
    except Exception:
        pass
    try:
        import holidays'''),
    ],
    "dashserve.py": [
        ('''    open_ = "09:15" <= hm <= "15:30" and dt.datetime.now(IST).weekday() < 5
''', '''    try:                                                     # patch 130: the special sessions too
        import sessions as _s130
        _ss = _s130.session(dt.datetime.now(IST).date())
        open_ = bool(_ss) and _ss["open"] <= hm <= _ss["close"]
    except Exception:
        open_ = "09:15" <= hm <= "15:30" and dt.datetime.now(IST).weekday() < 5
'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("engine2.py: the special sessions + the safety net · exchange.py + dashserve.py: open in a special session")
PY_PATCH
cat > $W/sessions.py <<'PY_SESS'
#!/usr/bin/env python3
"""sessions.py - patch 130: WHEN THE MARKET TRADES - one answer for every GIR service (the engine slept through the
Diwali Muhurat session of Sun 8 Nov 2026 because only the desk knew about it).

  normal    Mon-Fri 09:15-15:30, except NSE holidays
  special   data/sessions.json {"2026-11-08": ["14:20", "15:30", "Diwali Muhurat"]} (+ the built-in list below) - Muhurat,
            a Budget-day weekend session, NSE's special live sessions; the engine starts 13 minutes before the open
  detected  the safety net: on a day GIR thinks is closed, NIFTY trading (its last trade minutes old, the price moving) ->
            the day is written as "special session (detected)" and the engine starts at once

  python3 sessions.py                                      the next sessions
  python3 sessions.py add 2027-02-01 09:15 15:30 "Budget day"
  python3 sessions.py remove 2027-02-01"""
import os, sys, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "sessions.json")
PROBE = os.path.join(BASE, "data", "session_probe.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
BUILTIN = {"2026-11-08": ["14:20", "15:30", "Diwali Muhurat"]}
NORMAL = {"open": "09:15", "close": "15:30", "name": "normal", "special": False}


def _list():
    sp = dict(BUILTIN)
    try:
        sp.update(json.load(open(FILE)) or {})
    except Exception:
        pass
    return sp


def _holiday(d):
    try:
        import holidays
        return holidays.holiday(d)
    except Exception:
        return "weekend" if d.weekday() >= 5 else None


def session(day=None):
    """{"open", "close", "name", "special"} for the day, or None (closed)"""
    d = day or dt.datetime.now(IST).date()
    if isinstance(d, str):
        d = dt.date.fromisoformat(d)
    sp = _list().get(str(d))
    if sp:
        return {"open": sp[0], "close": sp[1], "name": sp[2] if len(sp) > 2 else "special session", "special": True}
    if d.weekday() >= 5 or _holiday(d):
        return None
    return dict(NORMAL)


def at(d, hm):
    h, m = [int(x) for x in hm.split(":")]
    return dt.datetime(d.year, d.month, d.day, h, m, tzinfo=IST)


def next_special(now=None, days=14):
    """(start datetime, session) of the next special session from now (one still open today counts), or (None, None)"""
    now = now or dt.datetime.now(IST)
    for i in range(days + 1):
        d = now.date() + dt.timedelta(days=i)
        s = session(d)
        if s and s["special"] and at(d, s["close"]) > now:
            return at(d, s["open"]), s
    return None, None


def save(day, open_, close, name):
    try:
        sp = json.load(open(FILE)) or {}
    except Exception:
        sp = {}
    sp[str(day)] = [open_, close, name]
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    json.dump(sp, open(FILE + ".tmp", "w"), indent=1)
    os.replace(FILE + ".tmp", FILE)


def remove(day):
    try:
        sp = json.load(open(FILE)) or {}
    except Exception:
        sp = {}
    sp.pop(str(day), None)
    json.dump(sp, open(FILE, "w"), indent=1)


def detect(kite, now=None):
    """the safety net, on a day GIR thinks is closed: NIFTY's last trade is today and minutes old, and the price moved
    since the last look -> the day is a special session (saved) -> the session, else None"""
    now = now or dt.datetime.now(IST)
    if session(now.date()) is not None or not ("09:00" <= now.strftime("%H:%M") <= "21:00"):
        return None
    q = (kite.quote(["NSE:NIFTY 50"]) or {}).get("NSE:NIFTY 50") or {}
    ts = q.get("timestamp") or q.get("last_trade_time")
    px = q.get("last_price")
    if isinstance(ts, str):
        try:
            ts = dt.datetime.fromisoformat(ts)
        except Exception:
            ts = None
    if ts is None or px is None:
        return None
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=IST)
    try:
        last = json.load(open(PROBE))
    except Exception:
        last = {}
    json.dump({"t": time.time(), "day": str(now.date()), "px": px}, open(PROBE, "w"))
    fresh = ts.astimezone(IST).date() == now.date() and (now - ts.astimezone(IST)).total_seconds() < 300
    moved = last.get("day") == str(now.date()) and last.get("px") is not None and abs(float(last["px"]) - float(px)) > 0.01
    if not (fresh and moved):
        return None
    op = (now - dt.timedelta(minutes=10)).strftime("%H:%M")
    cl = "15:30" if now.strftime("%H:%M") < "14:15" else (now + dt.timedelta(minutes=75)).strftime("%H:%M")
    save(now.date(), op, cl, "special session (detected)")
    return session(now.date())


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["add"] and len(a) >= 4:
        dt.date.fromisoformat(a[1]); at(dt.date.today(), a[2]); at(dt.date.today(), a[3])
        save(a[1], a[2], a[3], " ".join(a[4:]) or "special session")
        print("saved: %s %s-%s %s - every GIR service follows it (the engine starts 13 minutes before)" % (a[1], a[2], a[3], " ".join(a[4:])))
    elif a[:1] == ["remove"] and len(a) >= 2:
        remove(a[1]); print("removed %s" % a[1])
    else:
        now = dt.datetime.now(IST)
        print("special sessions on the list:")
        for d, v in sorted(_list().items()):
            print("  %s %s  %s-%s  %s%s" % (d, dt.date.fromisoformat(d).strftime("%a"), v[0], v[1], v[2] if len(v) > 2 else "", "   (past)" if d < str(now.date()) else ""))
        print("today: %s" % (session(now.date()) or "closed"))
PY_SESS
cat > $D/p130test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p130test.py - GIR TRADES EVERY SESSION: Sun 8 Nov 2026 (Diwali Muhurat 14:20-15:30) the engine runs; the evening before
it says so on Telegram and wakes for it; an unknown session (NIFTY trading on a 'closed' Sunday) is found and run; a normal
Monday is unchanged. A fake clock, a fake Kite, a fake Telegram - nothing real is touched."""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import holidays
holidays.holiday = lambda d=None: ("weekend" if (d if not isinstance(d, str) else dt.date.fromisoformat(d)).weekday() >= 5 else None)
import sessions, core, engine, engine2, exchange
IST = sessions.IST
tmp = tempfile.mkdtemp(prefix="p130")
try:
    sessions.FILE = os.path.join(tmp, "sessions.json"); sessions.PROBE = os.path.join(tmp, "probe.json")
    D = dt.date
    print("1. the sessions")
    check("Mon 9 Nov 2026: normal 09:15-15:30 · Sat 7 Nov: closed · Sun 8 Nov: Diwali Muhurat 14:20-15:30",
          sessions.session(D(2026, 11, 9))["name"] == "normal" and sessions.session(D(2026, 11, 7)) is None and sessions.session(D(2026, 11, 8))["name"] == "Diwali Muhurat")
    sessions.save("2027-02-06", "09:15", "15:30", "Budget day")
    check("added by hand: Sat 6 Feb 2027 Budget day", sessions.session(D(2027, 2, 6))["special"] is True)
    t, s = sessions.next_special(dt.datetime(2026, 11, 7, 20, 0, tzinfo=IST))
    check("the next special session from Sat 7 Nov 20:00: %s %s" % (t, s and s["name"]), t == dt.datetime(2026, 11, 8, 14, 20, tzinfo=IST) and s["name"] == "Diwali Muhurat")
    sessions.remove("2027-02-06")
    check("removed again", sessions.session(D(2027, 2, 6)) is None)

    print("2. the engine")
    engine.DB = os.path.join(tmp, "trades.db")
    TG, RUN, SLEEP = [], [], []
    core.tg = lambda t, silent=None: TG.append(t) or True
    engine2.run_day = lambda c: RUN.append(core.ist_now()) or True
    engine2.cfg2 = lambda: {}
    engine2.sleep_until = lambda t: SLEEP.append(t)

    class Kite(object):
        def __init__(self, ts, px):
            self.ts, self.px = ts, px

        def quote(self, keys):
            return {"NSE:NIFTY 50": {"timestamp": self.ts, "last_price": self.px}}
    KITE = {"k": None}

    def get_kite(c=None):
        if KITE["k"] is None:
            raise RuntimeError("no token today")
        return KITE["k"]
    core.get_kite = get_kite

    def run_main(when):
        core.ist_now = lambda: when
        try:
            engine2.main()
        except SystemExit as e:
            return e.code
        return None
    TG[:] = []; RUN[:] = []; SLEEP[:] = []
    run_main(dt.datetime(2026, 11, 7, 20, 0))
    check("Sat 7 Nov 20:00: a Telegram note for tomorrow's session: %s" % (TG[:1],), any("SPECIAL SESSION Sun 08 Nov 14:20-15:30 (Diwali Muhurat)" in x for x in TG) and not RUN)
    check("... and it does not sleep till Monday (it looks again in 3 min on a closed day): %s" % SLEEP, SLEEP and SLEEP[-1] == dt.datetime(2026, 11, 7, 20, 3))
    TG[:] = []; SLEEP[:] = []
    run_main(dt.datetime(2026, 11, 8, 11, 0))
    check("Sun 8 Nov 11:00: sleeps until 14:07 (13 min before the 14:20 open): %s" % SLEEP, SLEEP and SLEEP[-1] == dt.datetime(2026, 11, 8, 14, 7) and not RUN)
    code = run_main(dt.datetime(2026, 11, 8, 14, 8))
    check("Sun 8 Nov 14:08: the live day runs, Telegram says so: %s" % (TG[-1:] if TG else None), RUN and code == 0 and any("SPECIAL SESSION today 14:20-15:30" in x for x in TG))
    RUN[:] = []; SLEEP[:] = []
    run_main(dt.datetime(2026, 11, 8, 16, 0))
    check("16:00 the same day: done, not run again", not RUN)
    print("3. the safety net (a session nobody put on the list)")
    TG[:] = []; RUN[:] = []; SLEEP[:] = []
    KITE["k"] = Kite(dt.datetime(2026, 11, 15, 10, 59, 30), 25100.0)
    code = run_main(dt.datetime(2026, 11, 15, 11, 0))
    check("Sun 15 Nov 11:00, first look: NIFTY's last trade is fresh but there is nothing to compare yet - no start", code == 0 and not RUN and sessions.session(D(2026, 11, 15)) is None)
    KITE["k"] = Kite(dt.datetime(2026, 11, 15, 11, 2, 50), 25112.5)
    code = run_main(dt.datetime(2026, 11, 15, 11, 3))
    ses = sessions.session(D(2026, 11, 15))
    check("3 min later the price moved: written as a special session, Telegram says so: %s" % (ses,), ses and ses["special"] and "detected" in ses["name"] and any("NIFTY is trading today" in x for x in TG))
    code = run_main(dt.datetime(2026, 11, 15, 11, 3, 30))
    check("the restart runs the live day", RUN)
    KITE["k"] = Kite(dt.datetime(2026, 11, 13, 15, 29, 59), 25000.0)
    RUN[:] = []; TG[:] = []
    run_main(dt.datetime(2026, 11, 21, 11, 0)); run_main(dt.datetime(2026, 11, 21, 11, 3))
    check("an ordinary Saturday (NIFTY's last trade is Friday's): nothing starts", not RUN and sessions.session(D(2026, 11, 21)) is None)
    print("4. a normal Monday and the bars")
    RUN[:] = []
    run_main(dt.datetime(2026, 11, 9, 9, 5))
    check("Mon 9 Nov 09:05: the normal day runs as before", RUN and RUN[0] == dt.datetime(2026, 11, 9, 9, 5))
    check("the bar before the 14:20 special open is skipped, not 'market holiday, stop'; a normal day's empty bar still stops",
          engine2._special_pre(dt.datetime(2026, 11, 8, 14, 15)) and engine2._special_pre(dt.datetime(2026, 11, 8, 14, 30)) and not engine2._special_pre(dt.datetime(2026, 11, 8, 14, 40))
          and not engine2._special_pre(dt.datetime(2026, 11, 9, 9, 30)))
    check("the filings reader: 'market OPEN' in the Muhurat session, closed after it",
          exchange.is_open(dt.datetime(2026, 11, 8, 14, 30)) and not exchange.is_open(dt.datetime(2026, 11, 8, 16, 0)) and exchange.is_open(dt.datetime(2026, 11, 9, 10, 0)))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP130 EVERY SESSION TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p130_patch.py $D || { rm -f $D/p130test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/sessions.py $D/
cd $D && python3 -m py_compile engine2.py exchange.py dashserve.py sessions.py p130test.py || back
timeout 120 python3 p130test.py 2>&1 | grep "OK  \|FAIL\|SESSION TEST"
timeout 120 python3 p130test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p88test.py p114test.py p116test.py p119test.py p120test.py p124test.py p125btest.py p118test.py p123test.py p80test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-exchange gir-dash && sleep 8
for u in gir-exchange gir-dash; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
if pgrep -f "engine2.run_day" >/dev/null; then
  echo "PATCH 130 APPLIED. The engine you started by hand for today's session is still running - it is left alone."
  echo "After today's session (after 15:45) run:   systemctl restart gir-intraday"
else
  systemctl restart gir-intraday && sleep 10
  [ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
  echo "PATCH 130 APPLIED. The engine follows every session now."
fi
python3 $D/sessions.py
