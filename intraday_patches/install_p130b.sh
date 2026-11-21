#!/bin/bash
# PATCH 130b - LIVE IN ~2 MINUTES, NOT 10 (on top of patch 130).
#   The engine topped up the history of all 1,522 shares before going live (8-12 min; on the Muhurat Sunday the page showed
#   Friday until it finished). Now the ~218 F&O shares first (~2 min), then the live loop, and the other shares slowly in
#   the background. A special session starts 40 minutes before its open (was 13).
#   engine2.py (exact anchors). The engine is NOT restarted inside a session - the new code starts with its next run.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g130b; mkdir -p $W
grep -q "def _special_pre" $D/engine2.py 2>/dev/null || { echo "patch 130 is not installed yet - paste patch 130 first"; exit 1; }
grep -q "patch 130b" $D/engine2.py && { echo "patch 130b is already installed"; exit 1; }
cp $D/engine2.py $D/engine2.py.bak$TS; cp $D/p130test.py $D/p130test.py.bak$TS
back() { cp $D/engine2.py.bak$TS $D/engine2.py; cp $D/p130test.py.bak$TS $D/p130test.py; rm -f $D/p130btest.py; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p130b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p130b_patch.py - PATCH 130b: LIVE IN 2 MINUTES, NOT 10. The engine topped up the history of all 1,522 shares before going
live (8-12 min - on the Muhurat Sunday it went in mid-session and the page showed Friday until it finished). Now the ~218
F&O shares first (about 2 min), the live loop starts, and the other shares are topped up slowly in the background.
A special session starts 40 minutes before its open (was 13).
Usage: python3 p130b_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''    if once(con, day, "topup"):
        log("topping up history for %d shares" % len(uni))
        try:
            getdata.update_all(kite, c, uni, quiet=True)
        except Exception as ex:
            log("history top-up failed:", ex)
''', '''    topup_rest = []
    if once(con, day, "topup"):                            # patch 130b: the F&O shares first (~2 min), the rest in the background
        try:
            _c0 = chains.db(); _fo0 = {r[0] for r in _c0.execute("select sym from fo_list")}; _c0.close()
        except Exception:
            _fo0 = set()
        first = [e for e in uni if e["sym"] in _fo0] if _fo0 else uni
        topup_rest = [e for e in uni if e["sym"] not in _fo0] if _fo0 else []
        log("topping up history: %d F&O shares now, %d other shares in the background once live" % (len(first), len(topup_rest)))
        try:
            getdata.update_all(kite, c, first, quiet=True)
        except Exception as ex:
            log("history top-up failed:", ex)
'''),
        ('''    nif_hist = tail("NIFTY50")
''', '''    nif_hist = tail("NIFTY50")
    if topup_rest:                                         # patch 130b: the other shares, slowly, after the start-up has read its history

        def _topup_rest(rest=topup_rest):
            n_ = 0
            for e_ in rest:
                try:
                    getdata.update_symbol(kite, e_, c); n_ += 1
                except Exception:
                    pass
                time.sleep(0.5)                            # slow on purpose: the live loop's own Kite calls come first
            log("background history top-up done: %d of %d other shares" % (n_, len(rest)))
        threading.Thread(target=_topup_rest, daemon=True, name="topup").start()
'''),
        ('''        if s_open - dt.timedelta(minutes=13) <= now < s_close + dt.timedelta(minutes=10):''',
         '''        if s_open - dt.timedelta(minutes=40) <= now < s_close + dt.timedelta(minutes=10):   # patch 130b: 40 min before (was 13)'''),
        ('''            sp_n = sp_t.replace(tzinfo=None) - dt.timedelta(minutes=13)''',
         '''            sp_n = sp_t.replace(tzinfo=None) - dt.timedelta(minutes=40)   # patch 130b: was 13'''),
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
print("engine2.py: the F&O shares' history first, the rest in the background · special sessions 40 min before the open")
PY_PATCH
cat > $D/p130btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p130btest.py - the engine's start: the F&O shares' history is topped up first, the live start follows at once, the other
shares are topped up in the background afterwards. A fake Kite and fake files - nothing real is touched."""
import os, sys, time, sqlite3, tempfile, shutil, threading, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import core, engine, engine2, getdata, chains
tmp = tempfile.mkdtemp(prefix="p130b")
try:
    engine.DB = os.path.join(tmp, "trades.db")
    core.ist_now = lambda: dt.datetime(2026, 11, 9, 9, 3)
    core.get_kite = lambda c=None: object()
    UNI = [{"sym": s, "token": i} for i, s in enumerate("AAA BBB CCC FO1 DDD FO2 EEE FFF FO3 GGG".split())]
    getdata.load_universe = lambda: UNI
    fodb = os.path.join(tmp, "chains.db")
    c_ = sqlite3.connect(fodb); c_.execute("create table fo_list(sym text, lot int)"); c_.executemany("insert into fo_list values(?,1)", [("FO1",), ("FO2",), ("FO3",)]); c_.commit(); c_.close()
    chains.db = lambda: sqlite3.connect(fodb)
    ORDER = []
    getdata.update_all = lambda kite, c, uni, quiet=False: ORDER.append(("first", [e["sym"] for e in uni])) or (len(uni), [])
    BG = []
    getdata.update_symbol = lambda kite, e, c: BG.append(e["sym"]) or 1
    core.load_npz = lambda sym: None

    class Stop(Exception):
        pass

    def news(c, uni):
        ORDER.append(("live start", time.time()))
        raise Stop()
    engine2.News = news
    t0 = time.time()
    try:
        engine2.run_day({"v2": {}})
    except Stop:
        pass
    dt_ = time.time() - t0
    check("the F&O shares are topped up first, alone: %s" % (ORDER[:1],), ORDER and ORDER[0] == ("first", ["FO1", "FO2", "FO3"]))
    check("the live start follows at once (%.1f s), not after the other shares" % dt_, len(ORDER) > 1 and ORDER[1][0] == "live start" and dt_ < 2)
    for th in threading.enumerate():
        if th.name == "topup":
            th.join(timeout=20)
    check("the other 7 shares are topped up in the background afterwards: %s" % BG, BG == ["AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG"])
finally:
    shutil.rmtree(tmp, ignore_errors=True)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
check("a special session starts 40 minutes before its open", src.count("dt.timedelta(minutes=40)") == 2)
print("\nP130B FAST START TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cat > $W/p130test.py <<'PY_TEST130'
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
    check("Sun 8 Nov 11:00: sleeps until 13:40 (40 min before the 14:20 open): %s" % SLEEP, SLEEP and SLEEP[-1] == dt.datetime(2026, 11, 8, 13, 40) and not RUN)
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
PY_TEST130
python3 $W/p130b_patch.py $D || { rm -f $D/p130btest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/p130test.py $D/p130test.py
cd $D && python3 -m py_compile engine2.py p130btest.py p130test.py || back
timeout 120 python3 p130btest.py 2>&1 | grep "OK  \|FAIL\|START TEST"
timeout 120 python3 p130btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p130test.py p88test.py p114test.py p116test.py p119test.py p120test.py p124test.py p125btest.py p80test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo
INSESSION=$(cd $D && python3 -c "
import sessions, datetime as dt
n = dt.datetime.now(sessions.IST); s = sessions.session(n.date())
print(1 if s and sessions.at(n.date(), s['open']) - dt.timedelta(minutes=40) <= n <= sessions.at(n.date(), s['close']) + dt.timedelta(minutes=10) else 0)")
if [ "$INSESSION" = "1" ]; then
  echo "PATCH 130b APPLIED. A session is running - the engine is left alone; the new start-up is used from its next run"
  echo "(after this session it restarts by itself). To use it at once outside market hours:  systemctl restart gir-intraday"
else
  systemctl restart gir-intraday && sleep 10
  [ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
  echo "PATCH 130b APPLIED. The engine restarted with the fast start."
fi
