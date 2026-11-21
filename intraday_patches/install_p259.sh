#!/bin/bash
# PATCH 259 - THE RINGS FOLLOW THE MEASUREMENT (callstudy 7-13 Nov, 3,637 alerts scored on the shares' own 5-min candles; Rama, 14 Nov: "you decide").
#   silent (shown on the page, not rung): 🌅 OPENING CALL · 🟢 GO · ⚡ ENTER NOW - wrong more often than right (8% / 0% / 20% right, 41% / 30% / 30% wrong)
#   rings: ⚡ SPEED with a side (55% right, 6% wrong) · ✅ CONFIRMED MOVE (new, callfail.py every minute 09:20-11:00: a morning call
#   0.8% against within 30 min - the other side was right 13 of 15 times, avg +1.5%; POLICYBZR 13 Nov). The old OPENING CALL FAILED still rings.
#   Tested: 14 cases. Restarts the senders - after 15:35 on a trading day (or add: now); on a weekend any time.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "_tier249" $D/alertword.py || { echo "patch 249 first"; exit 1; }
F="alertword.py ringgov.py tglanes.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/callfail.py $U/gir-callfail.service $U/gir-callfail.timer; systemctl daemon-reload; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/callfail.py <<'PY_CF'
#!/usr/bin/env python3
"""callfail.py - patch 259: ✅ CONFIRMED MOVE - the morning side gave up, the other side confirmed (callstudy, 7-13 Nov: when a morning call - 🌅 OPENING CALL / 🟢 GO / ⚡ ENTER NOW before
09:45 - went 0.8% against within 30 min, the OTHER side was right 13 of 15 times, avg +1.5% in an hour; POLICYBZR 13 Nov: PE at 09:20, then +5%).
Every minute 09:20-11:00: each of today's morning calls, its price (the ₹ in the call), the live price; 0.8% against within 30 min ->
one ringing line to GIR Box Picks, once a share a day.   python3 callfail.py [--send]"""
import os, re, sys, json, time, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "data", "callfail.json")
AGAINST, WINDOW = 0.8, 1800
CALL = re.compile(r"^(?:🔔 OPENING · )?(?:🌅 OPENING CALL(?!.*FAILED)|🟢 GO\b|⚡ ENTER NOW)")
SYMRX = re.compile(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b")


def calls(day):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=5)
        rows = c.execute("select t, text from alerts where day=? and t>='09:00' and t<'09:45' order by t", (day,)).fetchall()
        c.close()
    except Exception:
        return []
    out, seen = [], set()
    for t, tx in rows:
        h = (tx or "").split("\n")[0]
        if not CALL.search(h):
            continue
        m = SYMRX.search(h)
        p = re.search(r"₹\s?([\d,]+(?:\.\d+)?)", h)
        if not m or not p or m.group(2) in seen:
            continue
        seen.add(m.group(2))
        side = 1 if m.group(1) == "▲" else -1
        if re.search(r"\bPE\b", h):
            side = -1
        elif re.search(r"\bCE\b", h):
            side = 1
        out.append({"t": str(t)[:5], "sym": m.group(2), "side": side, "px": float(p.group(1).replace(",", "")), "kind": h.split(" · ")[0][:24]})
    return out


def quotes():
    try:
        j = json.load(open(os.path.join(BASE, "quotes_live.json")))
        return j.get("q") or {} if time.time() - float(j.get("t") or 0) < 120 else {}
    except Exception:
        return {}


def check(now=None, send=None, q=None):
    now = now or dt.datetime.now(IST)
    if now.weekday() > 4 or not (dt.time(9, 20) <= now.time() <= dt.time(11, 0)):
        return []
    day = str(now.date())
    try:
        st = json.load(open(STATE))
    except Exception:
        st = {}
    if st.get("day") != day:
        st = {"day": day, "sent": []}
    q = quotes() if q is None else q
    out = []
    for c in calls(day):
        if c["sym"] in st["sent"]:
            continue
        t0 = dt.datetime.fromisoformat("%s %s:00" % (day, c["t"])).replace(tzinfo=IST)
        if (now - t0).total_seconds() > WINDOW:
            continue
        v = q.get(c["sym"])
        if not v or not v[0]:
            continue
        px = float(v[0]); mv = (px / c["px"] - 1) * 100 * c["side"]
        if mv > -AGAINST:
            continue
        new = -c["side"]; ar = "▲" if new > 0 else "▼"; side_w = "CE" if new > 0 else "PE"
        mins = int((now - t0).total_seconds() // 60)
        txt = ("✅ CONFIRMED MOVE %s %s · %s · %s\n"
               "the morning %s gave up: ₹%s → ₹%s in %d min (%.1f%% the other way)\n"
               "measured: after this, the share kept going %s 13 of 15 times (avg +1.5%% in an hour · 7-13 Nov, still a small count)\n"
               "for you: %s, the strike nearest ₹%s · stay while the share holds %s ₹%s · out if it goes back %s ₹%s") % (
            ar, c["sym"], side_w, now.strftime("%H:%M"),
            "sellers" if c["side"] < 0 else "buyers", "{:,.2f}".format(c["px"]), "{:,.2f}".format(px), mins, -mv,
            "up" if new > 0 else "down",
            side_w, "{:,.0f}".format(px), "above" if new > 0 else "below", "{:,.2f}".format(px), "under" if new > 0 else "over", "{:,.2f}".format(c["px"]))
        st["sent"].append(c["sym"]); out.append(txt)
        (send or (lambda x: __import__("opencall").send_tg(x)))(txt)
    try:
        json.dump(st, open(STATE + ".tmp", "w")); os.replace(STATE + ".tmp", STATE)
    except Exception:
        pass
    return out


if __name__ == "__main__":
    r = check() if "--send" in sys.argv else check(send=lambda x: None)
    print("\n\n".join(r) if r else "no morning call has failed")
PY_CF
cat > $W/p259_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p259_patch.py - PATCH 259: the rings follow the measurement (callstudy 7-13 Nov, 3,637 alerts; Rama, 14 Nov: "you decide").
  silent (shown, not rung)  🌅 OPENING CALL · 🟢 GO · ⚡ ENTER NOW - right 8% / 0% / 20%, wrong 41% / 30% / 30% after 60 min
  rings                     ⚡ SPEED with a side - right 55%, wrong 6% (one ring a share / 15 min, as every alert)
                            ✅ CONFIRMED MOVE (callfail.py) - the morning side gave up, the other side right 13 of 15 - never held back
  OPENING CALL FAILED (the old check) still rings. Usage: python3 p259_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []
MAIN = 'if __name__ == "__main__":'


def edit(f, fn, mark, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if mark in s:
        print("  %s: %s - already in" % (f, tag)); return
    s2 = fn(s)
    if s2 is None:
        ERR.append("%s: anchor for '%s' not found" % (f, tag)); return
    open(p, "w", encoding="utf-8").write(s2); print("  %s: %s" % (f, tag))


AW = '''_tier259 = tier                                                    # patch 259: the rings follow the measurement (callstudy 7-13 Nov)


def tier(text):
    t_ = _tier259(text)
    try:
        L = [x for x in (text or "").split("\\n") if x.strip()]
        if not L:
            return t_
        op, H2, body = _head(L)
        if H2.startswith("✅ CONFIRMED MOVE"):
            return "move"
        if "FAILED" not in H2 and (H2.startswith("🌅 OPENING CALL") or H2.startswith("⚡ ENTER NOW") or re.match(r"🟢 GO\\b", H2)):
            return "read"                                       # right 8% / 20% / 0%, wrong 41% / 30% / 30% - shown, not rung
        if re.search(r"\\bSPEED\\b", H2.split("·")[0]) and re.search(r"[▲▼]", H2):
            return "move"                                       # right 55%, wrong 6%
    except Exception:
        pass
    return t_
'''
edit("alertword.py", lambda s: s.replace(MAIN, AW + "\n\n" + MAIN) if s.count(MAIN) == 1 else s.rstrip() + "\n\n\n" + AW, "_tier259", "opening call / GO / ENTER NOW silent · SPEED and CONFIRMED MOVE ring")
edit("ringgov.py", lambda s: s.replace('PROTECT = re.compile(r"', 'PROTECT = re.compile(r"CONFIRMED MOVE|', 1) if s.count('PROTECT = re.compile(r"') == 1 else None,
     'PROTECT = re.compile(r"CONFIRMED MOVE|', "CONFIRMED MOVE is never held back")
edit("tglanes.py", lambda s: s.replace('CRIT_RE = re.compile(r"', 'CRIT_RE = re.compile(r"CONFIRMED MOVE|', 1) if s.count('CRIT_RE = re.compile(r"') == 1 else None,
     'CRIT_RE = re.compile(r"CONFIRMED MOVE|', "CONFIRMED MOVE -> GIR Box Picks")
HJ = '''{ const at259_=alertTier; alertTier=function(r){ const H=r.head||"";   /* patch 259: the rings follow the measurement */
  if(/^✅ CONFIRMED MOVE/.test(H)) return "move";
  if(!/FAILED/.test(H)&&(/^🌅 OPENING CALL/.test(H)||/^⚡ ENTER NOW/.test(H)||/^🟢 GO\\b/.test(H))) return "watch";
  if(/\\bSPEED\\b/.test(H.split("·")[0])&&/[▲▼]/.test(H)) return "move";
  return at259_(r); }; }
'''
edit("home.html", lambda s: s.replace("function amountCr(s){", HJ + "function amountCr(s){", 1) if s.count("function amountCr(s){") == 1 else None,
     "patch 259: the rings follow the measurement", "the page: the same rings")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 259 in")
PY_PATCH
cat > $W/p259test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p259test.py - the rings follow the measurement + CONFIRMED MOVE on POLICYBZR 13 Nov (temp copies, nothing sent). python3 p259test.py DIR"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "tglanes.py", "ringgov.py", "callfail.py"):
    shutil.copy(os.path.join(SRC, f), T)
open(os.path.join(T, "eventwatch.py"), "w").write("def watch_list(now=None):\n    return {}\n")
json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import alertword as A, tglanes as L, ringgov as G, callfail as C
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); at = lambda h, m: dt.datetime(2026, 11, 16, h, m, tzinfo=IST)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:240]))
OC = "🌅 OPENING CALL ▼ POLICYBZR PE · GO · CONFIRMED 09:20 · pre-open -0.9% (₹1,040.4) · sellers 2.3x buyers"
chk("OPENING CALL: silent now", A.tier(OC) == "read", A.tier(OC))
chk("ENTER NOW: silent now", A.tier("⚡ ENTER NOW ▼ POLICYBZR PE · ₹1,030.8 -1.8% · 09:21\n▶ BUY 1020 PE") == "read")
chk("GO: silent now", A.tier("🟢 GO · MOTILALOFS ▼ PE · 09:16\n▶ BUY 900 PE") == "read")
chk("the old OPENING CALL FAILED still rings", A.tier("❌ OPENING CALL FAILED ▼ ABC PE · out") != "read" or A.tier("🌅 OPENING CALL FAILED ▼ ABC") != "read")
SP = "⚡ SPEED ▲ POLICYBZR ₹1058.9 +1.3% in 5 min · day +0.8% · 09:42:53"
chk("SPEED with a side: rings (was only on a 2%+ day)", A.tier(SP) == "move", A.tier(SP))
o, s = G.gate(SP, "move", now=at(9, 43), px=1058.9, candles={})
chk("... once a share in 15 min (the ring rules)", s is False and G.gate(SP.replace("09:42:53", "09:50"), "move", now=at(9, 50), px=1060.0, candles={})[1] is True)
CF = "✅ CONFIRMED MOVE ▲ POLICYBZR · CE · 09:34"
chk("CONFIRMED MOVE rings, goes to GIR Box Picks", A.tier(CF) == "move" and L.lane(CF) == "critical", (A.tier(CF), L.lane(CF)))
o, s = G.gate(CF, "move", now=at(9, 34), px=1040.0, candles={})
chk("CONFIRMED MOVE is never held - even in 09:15-09:30 or right after another ring", s is False, o)
P1 = "🧩 LONG BUILD-UP ▲ NAVINFLUOR · 13:36\n▶ BUY 10200 CE\n⚖ VOTE 5/6 ✓ P1"
chk("P1 trade calls unchanged (still act)", A.tier(P1) == "act" or A._tier259(P1) == A.tier(P1), A.tier(P1))
# CONFIRMED MOVE on 13 Nov's POLICYBZR, replayed as Monday
c = sqlite3.connect("tomorrow.db"); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
for t, x in (("09:20:04", OC), ("09:21:56", "⚡ ENTER NOW ▼ POLICYBZR PE · ₹1,030.8 -1.8% · 09:21"), ("09:22:00", "🟢 GO · AMBER ▲ CE · ₹6,400 · 09:22")):
    c.execute("insert into alerts values('2026-11-16',?,'','','',?)", (t, x))
c.commit(); c.close()
S = []
r = C.check(at(9, 25), S.append, q={"POLICYBZR": [1038.0, 0.0], "AMBER": [6420.0, 1.0]})
chk("09:25 POLICYBZR ₹1,038 (0.2% against the ₹1,040.4 call): nothing yet", not r)
r = C.check(at(9, 34), S.append, q={"POLICYBZR": [1049.0, 0.0], "AMBER": [6380.0, 1.0]})
chk("09:34 POLICYBZR ₹1,049: ✅ CONFIRMED MOVE ▲ CE - no word of the silent PE call", len(r) == 1 and r[0].startswith("✅ CONFIRMED MOVE ▲ POLICYBZR · CE") and "sellers gave up" in r[0] and "PE" not in r[0], r)
chk("... AMBER ₹6,380 (0.3% against its CE): nothing", not any("AMBER" in x for x in r))
r = C.check(at(9, 40), S.append, q={"POLICYBZR": [1060.0, 0.0], "AMBER": [6400.0, 1.0]})
chk("09:40: POLICYBZR not said again (once a share a day)", not r, r)
r = C.check(at(10, 0), S.append, q={"POLICYBZR": [1060.0, 0.0], "AMBER": [6330.0, 1.0]})
chk("10:00 AMBER 1.1% against - but 38 min after its call: too late, nothing", not r, r)
print("RINGS + CONFIRMED MOVE test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p259_patch.py $D || back
cd $D && python3 -m py_compile alertword.py ringgov.py tglanes.py callfail.py || back
echo "=== test"
python3 $W/p259test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
cat > $U/gir-callfail.service <<'UNIT'
[Unit]
Description=GIR CONFIRMED MOVE - a morning call 0.8% against within 30 min -> the other side confirmed
[Service]
Type=oneshot
TimeoutStartSec=50
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 callfail.py --send >> data/callfail.log 2>&1'
UNIT
cat > $U/gir-callfail.timer <<'UNIT'
[Unit]
Description=GIR CONFIRMED MOVE check, every minute 09:20-11:00 trading days
[Timer]
OnCalendar=Mon..Fri *-*-* 09..10:*:15 Asia/Kolkata
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-callfail.timer >/dev/null 2>&1 || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "  confirmed-move check: $(systemctl is-enabled gir-callfail.timer)"
echo "✅ patch 259 done - opening call / GO / ENTER NOW shown, not rung; SPEED and CONFIRMED MOVE ring. Ctrl + Shift + R on GIR."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-callfail.timer; systemctl restart $SV"
