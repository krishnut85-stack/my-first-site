#!/bin/bash
# PATCH 80 - TELEGRAM OFF THE WORKING THREADS (on top of patch 79). One sender queue, tgq.py, for every service:
#   · engine2.tg_fo (Box Picks), desk.tg_box (SUDDEN, YOUR RULE) and core.tg (GIR Intraday) return at once; one thread posts
#     in order, retries once on a hiccup (not on a 4xx), 10 s a try; a line that still fails is written to the home page's
#     NOW list marked NOT SENT. The chain sweep, the desk's 5-s reading and the tick agents never wait for Telegram again.
#   · a command-line run (newsroom.py --send, desk.py --once) still delivers before it quits (the queue drains at exit)
#   · p78test.py (the gate test) learns that sending is queued
#   Edits engine2.py desk.py core.py p78test.py in place (exact anchors); installs tgq.py and p80test.py.
#   Restarts gir-intraday, gir-desk, gir-newsroom, gir-exchange (every service that imports core.tg).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g80; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p80.sh now"; exit 1; fi
grep -q "def pins_loop" $D/engine2.py || { echo "patch 79 is not installed yet - paste patch 79 first"; exit 1; }
grep -q "import tgq" $D/engine2.py && { echo "patch 80 is already installed"; exit 1; }
F="engine2.py desk.py core.py p78test.py"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/tgq.py $D/p80test.py; systemctl restart gir-intraday gir-desk gir-newsroom gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $D/tgq.py <<'PY_TGQ'
#!/usr/bin/env python3
"""tgq.py - the one Telegram sender for every GIR service: a queue and one thread.

send() returns at once, so a slow Telegram never holds the desk, the chain sweep or the tick agents. The thread posts
in order, retries once on a hiccup (not on a 4xx), and calls back: on_ok(text) when the line is on the phone,
on_fail(text, why) when both tries failed - the caller puts it on the page, marked NOT SENT, so nothing is lost in silence.
flush() drains the queue; it is registered at exit so a command-line run (newsroom.py --send, desk.py --once) still
delivers before it quits. status() -> {"pending", "sent", "failed", "last_err"} for the page."""
import threading, queue, time, atexit

TIMEOUT = 10            # seconds per try; two tries at most
_Q = queue.Queue()
_S = {"thr": None, "lock": threading.Lock(), "inflight": 0, "sent": 0, "failed": 0, "last_err": "", "last_ms": 0}


def _post(tok, chat, text, silent):
    import requests
    data = {"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}
    if silent:
        data["disable_notification"] = "true"
    r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=data, timeout=TIMEOUT)
    if r.ok:
        return True, None, True
    return False, "%s %s" % (r.status_code, (r.text or "")[:120]), 400 <= r.status_code < 500


def _run():
    while True:
        tok, chat, text, silent, on_ok, on_fail = _Q.get()
        t0 = time.time()
        try:
            ok, err = False, None
            for try_ in (1, 2):
                try:
                    ok, err, final = _post(tok, chat, text, silent)
                    if ok or final:
                        break
                except Exception as ex:
                    err = str(ex)[:120]
                if try_ == 1:
                    time.sleep(1)
            _S["last_ms"] = int((time.time() - t0) * 1000)
            if ok:
                _S["sent"] += 1
                cb, args = on_ok, (text,)
            else:
                _S["failed"] += 1; _S["last_err"] = err or "?"
                cb, args = on_fail, (text, err or "?")
            if cb:
                try:
                    cb(*args)
                except Exception as ex:
                    print("tgq callback: %s" % str(ex)[:80])
        except Exception as ex:
            print("tgq: %s" % str(ex)[:80])
        finally:
            with _S["lock"]:
                _S["inflight"] -= 1
            _Q.task_done()


def send(tok, chat, text, on_ok=None, on_fail=None, silent=False):
    """queue one message; returns at once (True = queued). The thread starts on first use."""
    with _S["lock"]:
        if _S["thr"] is None or not _S["thr"].is_alive():
            _S["thr"] = threading.Thread(target=_run, daemon=True, name="tgq")
            _S["thr"].start()
        _S["inflight"] += 1
    _Q.put((tok, chat, text, silent, on_ok, on_fail))
    return True


def pending():
    with _S["lock"]:
        return _S["inflight"]


def flush(timeout=20):
    """wait until every queued line has been tried (at most `timeout` s); True when the queue is empty"""
    t0 = time.time()
    while pending() > 0 and time.time() - t0 < timeout:
        time.sleep(0.02)
    return pending() == 0


def status():
    return {"pending": pending(), "sent": _S["sent"], "failed": _S["failed"], "last_err": _S["last_err"], "last_ms": _S["last_ms"]}


atexit.register(flush)
PY_TGQ
cat > $W/p80_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p80_patch.py - PATCH 80: Telegram off the working threads. One sender queue (tgq.py) for engine2.tg_fo (Box Picks),
desk.tg_box (SUDDEN, YOUR RULE) and core.tg (GIR Intraday). send() returns at once; the thread posts in order, retries
once, and a line that still fails lands on the page's NOW list marked NOT SENT. Nothing waits for Telegram any more.
Usage: python3 p80_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new, all_=False):
    EDITS.setdefault(f, []).append((old, new, all_))


# ============================================================ engine2.py  (the block patch 78 installed)
E("engine2.py", '''    err_ = None
    for try_ in (1, 2):                                         # one retry: a Telegram hiccup must not lose the call
        try:
            import requests
            r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                              data={"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}, timeout=15)
            if r.ok:
                alert_log(text)                                 # the home page's NOW list, the same second
                return True
            err_ = "%s %s" % (r.status_code, r.text[:120])
            if 400 <= r.status_code < 500:
                break                                           # a bad request will not get better on a retry
        except Exception as ex:
            err_ = str(ex)[:120]
        if try_ == 1:
            time.sleep(1)
    log("box telegram error: %s" % err_)
    alert_log(text.rstrip() + "\\n⚠ NOT SENT to Telegram (%s) — on the page only" % (err_ or "?")[:80])
    return False''', '''    import tgq                                                  # the sender queue: this thread never waits for Telegram
    tgq.send(tok, chat, text, on_ok=alert_log,                  # on the phone -> the home page's NOW list, the same second
             on_fail=lambda t_, e_: (log("box telegram error: %s" % e_),
                                     alert_log(t_.rstrip() + "\\n⚠ NOT SENT to Telegram (%s) — on the page only" % (e_ or "?")[:80])))
    return True''')

# ============================================================ desk.py
E("desk.py", '''    try:
        import requests
        r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data={"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}, timeout=15)
        if r.ok:
            try:
                first = text.strip().split("\\n")[0]
                m = re.search(r"SUDDEN (\\S+)", first)
                now_ = core.ist_now()
                c = sqlite3.connect(P["tom"], timeout=10)
                c.execute("create table if not exists alerts(day text, t text, kind text, sym text, side text, text text)")
                c.execute("insert into alerts(day,t,kind,sym,side,text) values(?,?,?,?,?,?)", (str(now_.date()), now_.strftime("%H:%M:%S"), "🚨", m.group(1) if m else "", "CE" if "→ CE" in text else "PE" if "→ PE" in text else "", text[:1500]))
                c.commit(); c.close()
            except Exception as ex:
                log("alert log: %s" % str(ex)[:80])
        return r.ok
    except Exception as ex:
        log("box telegram: %s" % str(ex)[:80]); return False''', '''    def _logged(t_, mark=""):
        """the home page's NOW list (tomorrow.db alerts): every line that reached the phone, or failed to, the same second"""
        try:
            first = t_.strip().split("\\n")[0]
            m = re.search(r"SUDDEN (\\S+)|YOUR RULE \\"[^\\"]*\\" · (\\S+)", first)
            sym_ = ((m.group(1) or m.group(2)) if m else "") or ""
            now_ = core.ist_now()
            c = sqlite3.connect(P["tom"], timeout=10)
            c.execute("create table if not exists alerts(day text, t text, kind text, sym text, side text, text text)")
            c.execute("insert into alerts(day,t,kind,sym,side,text) values(?,?,?,?,?,?)", (str(now_.date()), now_.strftime("%H:%M:%S"), first.split()[0] if first else "🚨", sym_,
                                                                                            "CE" if "→ CE" in t_ else "PE" if "→ PE" in t_ else "", (t_.rstrip() + mark)[:1500]))
            c.commit(); c.close()
        except Exception as ex:
            log("alert log: %s" % str(ex)[:80])
    import tgq                                                  # the sender queue: the desk never waits for Telegram
    tgq.send(tok, chat, text, on_ok=_logged,
             on_fail=lambda t_, e_: (log("box telegram: %s" % e_), _logged(t_, "\\n⚠ NOT SENT to Telegram (%s) — on the page only" % (e_ or "?")[:80])))
    return True''')

# ============================================================ core.py  (GIR Intraday, the reading channel)
E("core.py", '''    try:
        import requests
        r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                          data={"chat_id": chat, "text": text[:4000], "disable_notification": "true" if silent else "false",
                                "disable_web_page_preview": "true"}, timeout=15)
        if not r.ok:
            print("telegram error:", r.status_code, r.text[:200])
        return r.ok
    except Exception as ex:
        print("telegram error:", ex)
        return False''', '''    try:
        import tgq                                              # the sender queue (tgq.py): the caller never waits for Telegram
        tgq.send(tok, chat, text, silent=bool(silent), on_fail=lambda t_, e_: print("telegram error:", e_, "|", t_.split("\\n")[0][:80]))
        return True
    except ImportError:
        pass
    try:
        import requests
        r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                          data={"chat_id": chat, "text": text[:4000], "disable_notification": "true" if silent else "false",
                                "disable_web_page_preview": "true"}, timeout=15)
        if not r.ok:
            print("telegram error:", r.status_code, r.text[:200])
        return r.ok
    except Exception as ex:
        print("telegram error:", ex)
        return False''')

# ============================================================ p78test.py  (the gate test learns that sending is queued)
E("p78test.py", "import core, engine2, desk\n", '''import core, engine2, desk, tgq


def _gate(*a, **k):
    r = getattr(engine2, "tg_gate")(*a, **k); tgq.flush(); return r


def _fo(t):
    engine2.tg_fo(t); tgq.flush()
''')
E("p78test.py", "engine2.tg_gate(", "_gate(", all_=True)
E("p78test.py", '''check("one hiccup, then sent: True, two tries, one NOW line", engine2.tg_fo("🎯 BOX PICK retry") is True and len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" not in LOGGED[0])''',
  '''_fo("🎯 BOX PICK retry"); check("one hiccup, then sent: two tries, one NOW line", len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" not in LOGGED[0])''')
E("p78test.py", '''check("two failures: False, and the line is on the page marked NOT SENT", engine2.tg_fo("🎯 BOX PICK lost") is False and len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" in LOGGED[0] and LOGGED[0].startswith("🎯 BOX PICK lost"))''',
  '''_fo("🎯 BOX PICK lost"); check("two failures: the line is on the page marked NOT SENT", len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" in LOGGED[0] and LOGGED[0].startswith("🎯 BOX PICK lost"))''')
E("p78test.py", '''check("a 4xx is not retried", engine2.tg_fo("🎯 BOX PICK bad") is False and len(SENT) == 1 and "NOT SENT" in LOGGED[0])''',
  '''_fo("🎯 BOX PICK bad"); check("a 4xx is not retried", len(SENT) == 1 and "NOT SENT" in LOGGED[0])''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new, all_) in enumerate(edits, 1):
            n = s.count(old)
            if (n != 1 and not all_) or (all_ and n < 1):
                print("ANCHOR %s #%d found %d times (need %s): %r" % (f, i, n, "1+" if all_ else "1", old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p80: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new, all_ in edits:
            s = s.replace(old, new) if all_ else s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p80: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p80test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p80test.py - the sender-queue test (no network, nothing written to the live databases).
  1 tgq: send() returns at once even when Telegram is slow; lines go in order; on_ok / on_fail are called; a 4xx is not retried
  2 engine2.tg_fo queues and the NOW list gets the line when it is on the phone; a failed line is marked NOT SENT
  3 desk.tg_box queues: SUDDEN and YOUR RULE lines land in the alerts table with the share; a failed one marked NOT SENT
  4 core.tg (GIR Intraday) queues, silent prefixes stay silent
"""
import os, sys, time, json, sqlite3, tempfile, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tgq, core, engine2, desk

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


SENT = []


class FakeResp(object):
    def __init__(self, code, text=""):
        self.status_code, self.text, self.ok = code, text, 200 <= code < 300


class FakeRequests(object):
    plan, delay = [], 0.0
    def post(self, url, data=None, timeout=None):
        time.sleep(self.delay)
        SENT.append(dict(data))
        r = self.plan.pop(0) if self.plan else FakeResp(200)
        if isinstance(r, Exception):
            raise r
        return r


fake = FakeRequests()
sys.modules["requests"] = fake
tgq.TIMEOUT = 2

print("1. the queue")
got = []
fake.delay = 0.3
t0 = time.time()
for i in range(3):
    tgq.send("tok", "chat", "line %d" % i, on_ok=lambda t: got.append(("ok", t)), on_fail=lambda t, e: got.append(("fail", t, e)))
dt_ = time.time() - t0
check("three sends with a slow Telegram (0.3 s each) return in %d ms" % int(dt_ * 1000), dt_ < 0.1)
check("pending = 3 right after", tgq.pending() == 3)
check("flush() drains them", tgq.flush(10) and tgq.pending() == 0)
check("in order, all on the phone", [x[1] for x in got] == ["line 0", "line 1", "line 2"] and all(x[0] == "ok" for x in got))
fake.delay = 0.0
SENT[:] = []; got[:] = []
fake.plan = [Exception("read timed out"), FakeResp(200)]
tgq.send("tok", "chat", "retry me", on_ok=lambda t: got.append(("ok", t)), on_fail=lambda t, e: got.append(("fail", t, e))); tgq.flush()
check("a hiccup then OK: two tries, on_ok", len(SENT) == 2 and got == [("ok", "retry me")])
SENT[:] = []; got[:] = []
fake.plan = [Exception("read timed out"), Exception("read timed out")]
tgq.send("tok", "chat", "lost", on_ok=lambda t: got.append(("ok", t)), on_fail=lambda t, e: got.append(("fail", t, e))); tgq.flush()
check("two failures: on_fail with the reason", len(SENT) == 2 and got and got[0][0] == "fail" and "timed out" in got[0][2])
SENT[:] = []; got[:] = []
fake.plan = [FakeResp(400, "Bad Request: chat not found")]
tgq.send("tok", "chat", "bad", on_fail=lambda t, e: got.append(("fail", t, e))); tgq.flush()
check("a 4xx: one try, on_fail", len(SENT) == 1 and got and "400" in got[0][2])
st = tgq.status()
check("status counts: sent %d · failed %d" % (st["sent"], st["failed"]), st["sent"] == 4 and st["failed"] == 2)

print("2. engine2.tg_fo through the queue")
LOGGED = []
engine2.alert_log = lambda t: LOGGED.append(t)
os.environ["TELEGRAM_TOKEN"] = "test-token"
engine2._TGFO.update({"at": time.time() + 3600, "chat": "-100test"})
SENT[:] = []; fake.plan = []
t0 = time.time(); r = engine2.tg_fo("🎯 BOX PICK queued"); dt_ = time.time() - t0
check("tg_fo returns True at once (%d ms)" % int(dt_ * 1000), r is True and dt_ < 0.1)
tgq.flush()
check("on the phone and on the NOW list", len(SENT) == 1 and SENT[0]["text"] == "🎯 BOX PICK queued" and LOGGED == ["🎯 BOX PICK queued"])
SENT[:] = []; LOGGED[:] = []; fake.plan = [Exception("boom"), Exception("boom")]
engine2.tg_fo("🎯 BOX PICK lost"); tgq.flush()
check("a failed line is on the NOW list marked NOT SENT", len(LOGGED) == 1 and LOGGED[0].startswith("🎯 BOX PICK lost") and "NOT SENT" in LOGGED[0])

print("3. desk.tg_box through the queue")
tmp = tempfile.mkdtemp(prefix="p80")
desk.P["tom"] = os.path.join(tmp, "tomorrow.db")
os.environ["TG_CHAT_BOX"] = "-100test"
SENT[:] = []; fake.plan = []
r = desk.tg_box("🚨 SUDDEN GLENMARK ₹2625 · 12:52 · pharma\nEXTREME BULLISH → CE (share price going UP). test"); tgq.flush()
c = sqlite3.connect(desk.P["tom"]); rows = c.execute("select kind, sym, side, text from alerts").fetchall(); c.close()
check("SUDDEN: queued, sent, in the alerts table with the share and side", r is True and len(SENT) == 1 and rows and rows[0][:3] == ("🚨", "GLENMARK", "CE"))
SENT[:] = []
desk.tg_box("📜 YOUR RULE \"puts bought\" · UNOMINDA ₹1101 · 12:52\ndetail\nshare price going DOWN → PE side · desk"); tgq.flush()
c = sqlite3.connect(desk.P["tom"]); rows = c.execute("select kind, sym, side from alerts order by rowid").fetchall(); c.close()
check("YOUR RULE: in the alerts table as 📜 UNOMINDA PE", rows[-1] == ("📜", "UNOMINDA", "PE"))
fake.plan = [Exception("boom"), Exception("boom")]
desk.tg_box("🚨 SUDDEN TATASTEEL ₹150 · 13:00 · metals\n→ CE"); tgq.flush()
c = sqlite3.connect(desk.P["tom"]); rows = c.execute("select sym, text from alerts order by rowid").fetchall(); c.close()
check("a failed SUDDEN is in the table marked NOT SENT", rows[-1][0] == "TATASTEEL" and "NOT SENT" in rows[-1][1])

print("4. core.tg (GIR Intraday) through the queue")
os.environ["TG_CHAT_INTRADAY"] = "-100read"
SENT[:] = []; fake.plan = []
t0 = time.time(); r = core.tg("🧪 a reading line"); dt_ = time.time() - t0; tgq.flush()
check("core.tg returns True at once (%d ms), silent prefix stays silent" % int(dt_ * 1000), r is True and dt_ < 0.1 and len(SENT) == 1 and SENT[0].get("disable_notification") == "true" and SENT[0]["chat_id"] == "-100read")
SENT[:] = []
core.tg("⚡ BREAKING a loud line"); tgq.flush()
check("a loud line has no silent flag", len(SENT) == 1 and "disable_notification" not in SENT[0])

print("\nP80 SENDER TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p80_patch.py $D || { rm -f $D/tgq.py $D/p80test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py desk.py core.py tgq.py p80test.py p78test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the sender test (a fake Telegram, nothing sent, nothing written to the live databases):"
timeout 120 python3 p80test.py 2>&1 | grep "OK  \|FAIL\|SENDER TEST\|Traceback\|Error" | head -30
timeout 120 python3 p80test.py >/dev/null 2>&1 || { echo "the sender test failed"; back; }
echo "--- 3. the gate test and the desk self-test still pass:"
timeout 120 python3 p78test.py 2>&1 | grep "FAIL\|GATE TEST\|Traceback"
timeout 120 python3 p78test.py >/dev/null 2>&1 || { echo "the gate test failed"; back; }
timeout 180 python3 desk.py --test 2>&1 | grep "FAIL\|SELF-TEST" | head -20
timeout 180 python3 desk.py --test >/dev/null 2>&1 || { echo "the desk self-test failed"; back; }
systemctl restart gir-intraday gir-desk gir-newsroom gir-exchange && sleep 8
echo "engine: $(systemctl is-active gir-intraday) · desk: $(systemctl is-active gir-desk) · newsroom: $(systemctl is-active gir-newsroom) · exchange: $(systemctl is-active gir-exchange)"
for u in gir-intraday gir-desk gir-newsroom gir-exchange; do journalctl -u $u --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -2; done
echo "PATCH 80 APPLIED - Telegram is on its own thread; a failed line shows on the home page as NOT SENT."
