#!/bin/bash
# PATCH 192 - Telegram carries ONLY what an F&O trader acts on (Rama, 11 Nov: News 161 · Moves 1002 · OI 931 · System 203 unread
#   in one day). SENT: trade calls · 🚨 critical news / results / government · regulator action · a top boss leaving · an order of
#   ₹1,000 cr+ · a results BEAT / MISS · ⚠️ SHOCK WATCH · 08:30 brief · 09:08 pre-open · GIR's health (data check, audits, down).
#   Everything else stays on the GIR page and in data/quiet/<day>.log. Undo: touch /home/globalbot/intraday/data/tg_all.on
#   Needs patch 191. Restarts the engine (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
FILES="tgq.py alertword.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/tgquiet.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/tgquiet.py <<'PY_Q'
#!/usr/bin/env python3
"""tgquiet.py - patch 192: Telegram carries ONLY what an F&O trader acts on (Rama, 11 Nov: GIR Live had News 161 · Moves 1002 ·
OI 931 · System 203 unread in one day - "F&O trader don't need noisy alerts. Need critical news and alerts which are very sure
that we can make profit").
  SENT     trade calls (⚡ ENTER NOW · 🌅 OPENING CALL · a measured BUY · your trade / stop) · 🚨 CRITICAL news / results /
           government · regulator action · a top boss leaving · an order of ₹1,000 cr+ · a results BEAT / MISS · ⚠️ SHOCK WATCH ·
           NIFTY / NEWS SHOCK · 🧱 CIRCUIT · ☀️ 08:30 BRIEF · 🌅 09:08 PRE-OPEN · 🌙 TOMORROW · 📜 YOUR RULE  (alertword.tier)
           + GIR's own health: 📋 DATA CHECK · 📋 NSE AUDIT · 📋 GIR FULL AUDIT · 🚨 SERVICE DOWN · GIR NOT LIVE · ⚠️ engine errors
  NOT SENT everything else (1% runs, speed, OI readings, quiet news, scorecards, digests) - it stays on the GIR page, and every
           line is kept in data/quiet/<day>.log, so nothing is lost
  Undo:    touch data/tg_all.on   -> Telegram gets everything again (rm it to go quiet again). Read once a minute, no restart."""
import os, re, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
ALL_ON = os.path.join(BASE, "data", "tg_all.on")
QDIR = os.path.join(BASE, "data", "quiet")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SYS_RE = re.compile(r"^(📋 (DATA CHECK|NSE AUDIT|GIR FULL AUDIT)|⚠️ (INTRADAY|GIR |CHAIN COVERAGE|\d+ (F&O|paper))|🚨 (SERVICE DOWN|GIR NOT LIVE))"
                    r"|LIVE FEED DOWN|SOCKET (DOWN|BACK)")
_C = {"at": 0.0, "all": False, "n": 0, "pruned": ""}


def all_on():
    if time.time() - _C["at"] > 60:
        _C["at"] = time.time()
        _C["all"] = os.path.exists(ALL_ON)
    return _C["all"]


def allow(text):
    """True = this line goes to Telegram"""
    if all_on():
        return True
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return False
    try:
        import alertword
        _o, H2, _b = alertword._head(L)
        if SYS_RE.search(H2) or SYS_RE.search(L[0]):
            return True
        return alertword.tier(text) != "read"
    except Exception:
        return True                                           # never lose a line because this check broke


def keep(text, chat=""):
    """the line that did not go to Telegram -> data/quiet/<day>.log (14 days kept)"""
    try:
        now = dt.datetime.now(IST)
        os.makedirs(QDIR, exist_ok=True)
        with open(os.path.join(QDIR, "%s.log" % now.date()), "a", encoding="utf-8") as f:
            f.write("%s · %s\n%s\n\n" % (now.strftime("%H:%M:%S"), chat, (text or "").strip()))
        _C["n"] += 1
        if _C["pruned"] != str(now.date()):
            _C["pruned"] = str(now.date())
            for fn in os.listdir(QDIR):
                if fn.endswith(".log") and fn[:10] < str(now.date() - dt.timedelta(days=14)):
                    os.remove(os.path.join(QDIR, fn))
    except Exception:
        pass


if __name__ == "__main__":
    import sys
    s = sys.stdin.read()
    print("SENT" if allow(s) else "page only")
PY_Q
cat > $W/p192_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p192_patch.py - PATCH 192: Telegram carries only what an F&O trader acts on (tgquiet.py decides, in tgq.send - the one sender
every GIR service uses). Everything else stays on the GIR page and in data/quiet/<day>.log. + a results BEAT / MISS rings.
Usage: python3 p192_patch.py /home/globalbot/intraday"""
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


if "patch 191" not in open(os.path.join(D, "alertword.py"), encoding="utf-8").read():
    print("patch 191 is not in yet - run install_p191.sh first (after 15:35), then this one"); sys.exit(1)

rep("tgq.py", '''    """queue one message on its channel's own queue; returns at once (True = queued). The thread starts on first use."""
    with _S["lock"]:''',
    '''    """queue one message on its channel's own queue; returns at once (True = queued). The thread starts on first use."""
    try:                                                        # patch 192: only what an F&O trader acts on goes to Telegram
        import tgquiet
        if not tgquiet.allow(text):
            tgquiet.keep(text, chat)
            _S["quiet"] = _S.get("quiet", 0) + 1
            if on_ok:                                           # the page still gets the line (the NOW list)
                try:
                    on_ok(text)
                except Exception as ex:
                    print("tgq callback: %s" % str(ex)[:80])
            return True
    except Exception as ex:
        print("tgquiet: %s" % str(ex)[:80])
    with _S["lock"]:''', "the one gate before Telegram")

rep("alertword.py", '''        if re.search(r"·\\s*(REG|REGULATOR|MGMT)\\b", H2):
            return "move"''',
    '''        if re.search(r"·\\s*(REG|REGULATOR|MGMT)\\b", H2):
            return "move"
        if re.search(r"·\\s*RESULTS\\s*·.*\\b(BEAT|MISS)\\b", H2):   # patch 192: a results verdict with a side
            return "move"''', "a results BEAT / MISS rings")

rep("home.html", '''if(/·\\s*(REG|REGULATOR|MGMT)\\b/.test(H)) return "move";''',
    '''if(/·\\s*(REG|REGULATOR|MGMT)\\b/.test(H)) return "move"; if(/·\\s*RESULTS\\s*·.*\\b(BEAT|MISS)\\b/.test(H)) return "move";   /* patch 192 */''',
    "the page: a results BEAT / MISS")

if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 192 written")
PY_PATCH
cat > $D/p192test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p192test.py - PATCH 192: Telegram gets only what an F&O trader acts on; the rest stays on the page and in data/quiet/"""
import os, sys, glob, time
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import tgquiet, tgq
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
S, Q = True, False
CASES = [
    ("🚀 RUNNING ▲ YESBANK ₹24.3 +1.2% · 10:05\ncrossed +1%", Q),
    ("🧩 SHORT BUILD-UP ▼ TITAN ₹3500 -1.2% · 10:42\nWATCH — not a trade yet", Q),
    ("🧩 OI SCENARIOS · 10:42 · 12 new (readings, not trades — tap the share on GIR for the numbers)\n▼ TITAN ...", Q),
    ("📰 NEWS ▲ SAIL · ORDER · 10:00\nSAIL bags order of Rs 200 crore", Q),
    ("📋 TRIAL ENTRY · 14:45 · paper", Q),
    ("🗞 GIR ENTRY RECAP · 14:00", Q),
    ("⚡ SPEED ▲ IREDA day +2.2% · 12:43", Q),
    ("📰 FILING · TATAPOWER · RESULTS · NSE 17:20:01 (read in 30s)\nnumbers follow", Q),
    ("📰 FILING ▼ TATAPOWER · RESULTS · MISS · NSE 17:20:01 (read in 30s)\nprofit -12%", S),
    ("🚨 CRITICAL RESULTS ▼ COCHINSHIP · RESULTS · BIG MISS · NSE 16:05", S),
    ("⚡ ENTER NOW ▲ RVNL ₹209 · 09:55\nBUY 210 CE", S),
    ("🌅 OPENING CALL · 09:12\nGO", S),
    ("🚨 CRITICAL GOVT · RBI · 11:02\nrepo cut", S),
    ("⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · Google News 10:12\nIRDAI bars Policybazaar", S),
    ("⚠️ SHOCK WATCH · ▼ PNB · REGULATOR · NSE filing 22:10\nRBI imposes a penalty of Rs 1 lakh", Q),
    ("📋 DATA CHECK · 09:25 · futures OI %: 12 of 12 match", S),
    ("📋 GIR FULL AUDIT · 19:20 IST · the last session 2026-11-11 · 0 problem(s)", S),
    ("🚨 SERVICE DOWN · gir-exchange · inactive", S),
    ("⚠️ INTRADAY v2 error: x — restarting in 30 s", S),
    ("☀️ MORNING BRIEF · Thu 12 Nov", S),
    ("🌅 PRE-OPEN 09:08 · F&O shares opening with a gap", S),
    ("💼 YOUR TRADE · COCHINSHIP 1180 PE", S),
    ("🌅 INTRADAY PAPER ready — watching 40 shares", Q),
    ("📅 NSE holiday today (Diwali). Desk is sleeping", Q),
]
for t, w in CASES:
    check("%-9s %s" % ("SENT" if w else "page only", t.split("\n")[0][:70]), tgquiet.allow(t) == w)
# the gate in tgq.send: a quiet line never reaches Telegram, the page still gets it, the quiet log keeps it
posted, page = [], []
tgq._post = lambda tok, chat, text, silent: (posted.append(text) or (True, None, True, 0))
tgq.send("T", "-100", "🚀 RUNNING ▲ YESBANK ₹24.3 +1.2% · 10:05", on_ok=page.append, silent=True)
tgq.send("T", "-100", "⚡ ENTER NOW ▲ RVNL ₹209 · 09:55\nBUY 210 CE", on_ok=page.append)
tgq.flush(5)
check("quiet line: not posted, on the page", not any("RUNNING" in p for p in posted) and any("RUNNING" in p for p in page))
check("trade call: posted and on the page", any("ENTER NOW" in p for p in posted) and any("ENTER NOW" in p for p in page))
lg = sorted(glob.glob(os.path.join(B, "data", "quiet", "*.log")))
check("quiet line kept in data/quiet/<day>.log", lg and "YESBANK" in open(lg[-1], encoding="utf-8").read())
# the undo switch
open(tgquiet.ALL_ON, "w").close(); tgquiet._C["at"] = 0
check("touch data/tg_all.on -> everything is sent again", tgquiet.allow("🚀 RUNNING ▲ YESBANK ₹24.3 +1.2%"))
os.remove(tgquiet.ALL_ON); tgquiet._C["at"] = 0
check("rm data/tg_all.on -> quiet again", not tgquiet.allow("🚀 RUNNING ▲ YESBANK ₹24.3 +1.2%"))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 192"
python3 $W/p192_patch.py $D || back
cd $D && python3 -m py_compile tgq.py tgquiet.py alertword.py || back
echo "=== the test (a copy of GIR's files - nothing is sent)"
T=$(mktemp -d); cp $D/tgq.py $D/tgquiet.py $D/alertword.py $D/p192test.py $T/ && mkdir -p $T/data
timeout 60 python3 $T/p192test.py > /tmp/p192test.out 2>&1; R=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p192test.out | head -20
[ $R = 0 ] || back
echo "=== restarting the engine, the filings reader, TV WATCH, the page server (the page shows 502 for up to 2 minutes)"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
sleep 20
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
[ $OK = 1 ] || { echo "the page server did not come back - old files back"; back; }
echo
echo "✅ patch 192 done. Telegram now gets only: trade calls · 🚨 critical · regulator news · ⚠️ SHOCK WATCH · results BEAT/MISS ·"
echo "   the 08:30 brief · 09:08 pre-open · GIR's health. Everything else: on the GIR page, and in $D/data/quiet/<day>.log"
echo "   Want everything back on Telegram:  touch $D/data/tg_all.on      (quiet again:  rm $D/data/tg_all.on)"
