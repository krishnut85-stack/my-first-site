#!/bin/bash
# PATCH 246 - NO MORE SURPRISE RESTARTS IN MARKET HOURS (Rama, 13 Nov 11:46: "I don't want this to happen again").
#   What happened: Ubuntu's automatic security update (libc6) ran at 06:16 UTC = 11:46 IST and restarted EVERY GIR service; the engine's
#   mid-day catch-up (earlier candles for 1,519 instruments, ~8-9 min) then held back the live prices - the page froze 11:46 -> ~11:55.
#   1 Ubuntu's automatic updates: Saturdays 09:00 IST only (was every day 06:00 UTC + up to 1 h random = 11:30-12:30 IST)
#   2 an update never restarts services by itself (needrestart: list only) - GIR is restarted after the close, by us
#   3 the engine: live prices keep flowing during a mid-day catch-up (a side writer, every second)
#   4 🚨 LIVE FEED DOWN to Box Picks (rings) if live prices stop 90 s+ in market hours; 🔌 SOCKET BACK when they return
#   Tested: 11 cases. Restarts the engine - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
cp $D/engine2.py $D/engine2.py.bak$TS
back(){ cp $D/engine2.py.bak$TS $D/engine2.py; rm -f $U/gir-stalecheck.service $U/gir-stalecheck.timer $U/apt-daily-upgrade.timer.d/gir.conf /etc/needrestart/conf.d/zz-gir.conf
        systemctl daemon-reload; systemctl restart gir-intraday 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p246_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p246_patch.py - PATCH 246 (engine part): live prices keep flowing while a mid-day restart catches up (Rama, 13 Nov 11:46: Ubuntu's automatic
security update restarted every GIR service; the engine's catch-up - today's earlier candles for 1,519 instruments, ~8-9 min at Kite's rate limit -
blocked quotes_live.json, so the page's prices froze from 11:46:34). Now a small side thread writes the live prices every second during the
catch-up (the ticks were arriving all along). Usage: python3 p246_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "engine2.py"); s = open(p, encoding="utf-8").read()
old = '''            if core.ist_now() > at(9, 16):
                feed.backfill(kite, core.ist_now())'''
new = '''            if core.ist_now() > at(9, 16):
                _bf246 = {"on": True}                           # patch 246: live prices to the page while the catch-up loads (~8 min)

                def _q246():
                    while _bf246["on"]:
                        try:
                            quotes_write(feed)
                        except Exception:
                            pass
                        time.sleep(1)
                threading.Thread(target=_q246, daemon=True, name="quotes246").start()
                try:
                    feed.backfill(kite, core.ist_now())
                finally:
                    _bf246["on"] = False'''
if new in s:
    print("  engine2.py: live prices during the catch-up - already in")
elif s.count(old) != 1:
    print("❌ engine2.py: anchor found %d times" % s.count(old)); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  engine2.py: live prices keep flowing during a mid-day catch-up")
print("patch 246 engine part in")
PY_PATCH
cat > $D/girstale.py <<'PY_STALE'
#!/usr/bin/env python3
"""girstale.py - patch 246: 🚨 LIVE FEED DOWN when GIR's live prices stop in market hours (Rama, 13 Nov: "I don't want this to happen again" -
the page's prices froze 11:46-11:55 and nobody was told). Every minute 09:17-15:29 IST on NSE trading days: quotes_live.json (the engine writes it
every second) older than 90 s -> one ringing line to Box Picks, again every 10 min while it lasts; when prices flow again -> 🔌 SOCKET BACK.
Changes nothing in GIR.   python3 girstale.py [--send]"""
import os, sys, json, time, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "data", "stale_state.json")
LIMIT, AGAIN = 90, 600


def holiday(d):
    try:
        import holidays
        return holidays.holiday(d)
    except Exception:
        return "weekend" if d.weekday() >= 5 else None


def age_now(now_ts=None):
    try:
        j = json.load(open(os.path.join(BASE, "quotes_live.json")))
        return (now_ts or time.time()) - float(j.get("t") or 0), float(j.get("t") or 0)
    except Exception:
        return None, None


def check(now=None, send=None):
    """-> the text sent (or None)"""
    now = now or dt.datetime.now(IST)
    if holiday(now.date()) or not (dt.time(9, 17) <= now.time() <= dt.time(15, 29)):
        return None
    send = send or (lambda t: __import__("opencall").send_tg(t))
    try:
        st = json.load(open(STATE))
    except Exception:
        st = {}
    if st.get("d") != str(now.date()):
        st = {"d": str(now.date())}
    age, t = age_now(now.timestamp())
    hm = lambda x: dt.datetime.fromtimestamp(x, IST).strftime("%H:%M:%S")
    txt = None
    if age is None or age > LIMIT:
        if not st.get("down") or now.timestamp() - st.get("sent", 0) >= AGAIN:
            since = ("at %s (%d s ago)" % (hm(t), age)) if t else "(the file cannot be read)"
            txt = ("🚨 LIVE FEED DOWN — GIR's live prices stopped %s · the page's prices are frozen, the second-by-second alerts are off\n"
                   "usually the engine restarting and catching up (up to ~10 min) - do not restart it yourself; check: bash /tmp/livecheck.sh") % since
            st.update({"down": True, "since": st.get("since") or (t or now.timestamp()), "sent": now.timestamp()})
    elif st.get("down") and age < 30:
        mins = max(1, int(round((now.timestamp() - st.get("since", now.timestamp())) / 60.0)))
        txt = "🔌 SOCKET BACK — GIR's live prices are flowing again (%s) after about %d min" % (now.strftime("%H:%M"), mins)
        st = {"d": str(now.date())}
    if txt:
        send(txt)
    try:
        json.dump(st, open(STATE + ".tmp", "w")); os.replace(STATE + ".tmp", STATE)
    except Exception:
        pass
    return txt


if __name__ == "__main__":
    if "--send" in sys.argv:
        print(check() or "ok")
    else:
        a, t = age_now()
        print("quotes_live age: %s" % ("%.0f s" % a if a is not None else "cannot read"))
PY_STALE
cat > $W/p246test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p246test.py - live prices during a mid-day catch-up + the LIVE FEED DOWN alarm (made-up files, nothing sent). python3 p246test.py DIR"""
import os, sys, json, time, shutil, tempfile, textwrap, threading, datetime as dt
D = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:200]))
# 1 the engine part: run the inserted lines with a fake feed whose catch-up takes 3.5 s
src = open(os.path.join(D, "engine2.py"), encoding="utf-8").read()
a = src.index("            if core.ist_now() > at(9, 16):\n                _bf246"); b = src.index('_bf246["on"] = False', a) + len('_bf246["on"] = False')
block = textwrap.dedent(src[a:b])
W = []
class Feed:
    def backfill(self, kite, now):
        time.sleep(3.5)
class Core:
    @staticmethod
    def ist_now():
        return 2
ns = {"core": Core, "at": lambda h, m: 1, "feed": Feed(), "kite": None, "time": time, "threading": threading, "quotes_write": lambda f: W.append(time.time())}
exec("def run():\n" + textwrap.indent(block, "    "), ns)
t0 = time.time(); ns["run"](); n_during = len(W); time.sleep(2.2)
chk("during a 3.5 s catch-up the live prices were written every second (%d times)" % n_during, n_during >= 3)
chk("... and the side writer stops when the catch-up ends (the engine's own loop takes over)", len(W) <= n_during + 1, (n_during, len(W)))
# 2 the alarm
shutil.copy(os.path.join(D, "girstale.py"), T)
open(os.path.join(T, "holidays.py"), "w").write("def holiday(d):\n    return 'weekend' if d.weekday() >= 5 else None\n")
sys.path.insert(0, T); os.chdir(T)
import girstale as G
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); day = dt.datetime(2026, 11, 13, tzinfo=IST)
S = []
def at(h, m, s=0):
    return day.replace(hour=h, minute=m, second=s)
def quotes(t):
    json.dump({"t": t.timestamp(), "q": {"NIFTY50": [25157.05, -0.56]}}, open(os.path.join(T, "quotes_live.json"), "w"))
quotes(at(11, 46, 34))
chk("11:47 (26 s old): quiet", G.check(at(11, 47), S.append) is None and not S)
r = G.check(at(11, 48, 30), S.append)
chk("11:48:30 (116 s old): 🚨 LIVE FEED DOWN rings, says when it stopped", r and r.startswith("🚨 LIVE FEED DOWN") and "11:46:34" in r and len(S) == 1, r)
chk("11:49 / 11:55: not repeated within 10 min", G.check(at(11, 49), S.append) is None and G.check(at(11, 55), S.append) is None and len(S) == 1, S)
r = G.check(at(11, 58, 40), S.append)
chk("11:58:40: still down -> said again (every 10 min)", r and r.startswith("🚨 LIVE FEED DOWN") and len(S) == 2, S)
quotes(at(11, 59, 5))
r = G.check(at(11, 59, 10), S.append)
chk("11:59: prices back -> 🔌 SOCKET BACK after about 13 min", r and r.startswith("🔌 SOCKET BACK") and "13 min" in r, r)
chk("12:00: quiet again", G.check(at(12, 0), S.append) is None and len(S) == 3)
quotes(at(15, 0))
chk("15:31 (after the close, old file): quiet", G.check(at(15, 31), S.append) is None)
chk("09:10 (before the open): quiet", G.check(at(9, 10), S.append) is None)
sat = dt.datetime(2026, 11, 14, 11, 0, tzinfo=IST)
chk("Saturday: quiet", G.check(sat, S.append) is None and len(S) == 3)
print("LIVE PRICES test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p246_patch.py $D || back
cd $D && python3 -m py_compile engine2.py girstale.py || back
echo "=== test: live prices during a catch-up + the LIVE FEED DOWN alarm"
python3 $W/p246test.py $D || back
echo "=== 1 Ubuntu's automatic updates -> Saturdays 09:00 IST"
mkdir -p $U/apt-daily-upgrade.timer.d
printf '[Timer]\nOnCalendar=\nOnCalendar=Sat *-*-* 09:00:00 Asia/Kolkata\nRandomizedDelaySec=0\n' > $U/apt-daily-upgrade.timer.d/gir.conf
echo "=== 2 updates never restart services by themselves"
if [ -d /etc/needrestart ]; then mkdir -p /etc/needrestart/conf.d; printf "# patch 246: list only - GIR is restarted after the close, never by an update\n\$nrconf{restart} = 'l';\n" > /etc/needrestart/conf.d/zz-gir.conf; echo "   needrestart: list only"; else echo "   needrestart not installed - nothing to change"; fi
echo "=== 4 the LIVE FEED DOWN alarm (every minute 09:17-15:29 on trading days)"
cat > $U/gir-stalecheck.service <<'UNIT'
[Unit]
Description=GIR live prices check (LIVE FEED DOWN if they stop 90 s+ in market hours)
[Service]
Type=oneshot
TimeoutStartSec=60
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 girstale.py --send >> data/stalecheck.log 2>&1'
UNIT
cat > $U/gir-stalecheck.timer <<'UNIT'
[Unit]
Description=GIR live prices check, every minute in market hours
[Timer]
OnCalendar=Mon..Fri *-*-* 09..15:*:40 Asia/Kolkata
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-stalecheck.timer >/dev/null 2>&1 || back
echo "   next Ubuntu update: $(systemctl list-timers apt-daily-upgrade.timer --no-pager 2>/dev/null | sed -n 2p | cut -c1-60)"
echo "   live prices check:  $(systemctl is-enabled gir-stalecheck.timer) · $(cd $D && python3 girstale.py)"
echo "=== 3 the engine restarts with the change"
systemctl restart gir-intraday; sleep 20
echo "  gir-intraday: $(systemctl is-active gir-intraday)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "✅ patch 246 done - updates only on Saturday morning, never a restart by an update; prices flow during a catch-up; LIVE FEED DOWN if they stop."
echo "   'System restart required' is still shown - one planned reboot this weekend clears it (Saturday after 09:30, after the update)."
echo "   undo: cp $D/engine2.py.bak$TS $D/engine2.py; rm $U/apt-daily-upgrade.timer.d/gir.conf /etc/needrestart/conf.d/zz-gir.conf; systemctl disable --now gir-stalecheck.timer; systemctl daemon-reload; systemctl restart gir-intraday"
