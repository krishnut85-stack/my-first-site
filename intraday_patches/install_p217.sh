#!/bin/bash
# PATCH 217 - two fixes:
#   1 an OI scenario (🧩, e.g. CALL WRITERS RUNNING) with a BUY line was 🔴 P1 ACT NOW (~30 a day, loud, sticky on the page). Patch 191's rule:
#     P1 only for a MEASURED BUY (55%+ right on 50+ past cases) - the code never checked it. Now measured -> 🔴 P1 · not measured -> 🟠 P2
#     (still rings) · no BUY -> 🟡 P3. Every other alert keeps its level (the test compares this server's file before and after).
#   2 the 14:00 study's NIFTY rows were 0 (no "NIFTY 50" 5-min file): it now finds NIFTY's file by its other names, or uses the F&O median.
#   Restarts the senders (seconds) - run it before 09:00 or after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
mkdir -p $W/old; cp $D/alertword.py $W/old/
for f in alertword.py home.html afternoon.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in alertword.py home.html afternoon.py; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p217_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p217_patch.py - PATCH 217: two fixes.
  1 an OI scenario (🧩, e.g. CALL WRITERS RUNNING) with a BUY line was 🔴 P1 ACT NOW (~30 a day, loud, sticky on the page) - patch 191's rule
    says P1 only for a MEASURED BUY (55%+ right on 50+ past cases), the code never checked "measured". Now: measured BUY -> 🔴 P1 ·
    a BUY not measured -> 🟠 P2 (still rings, not ACT NOW) · the rest -> 🟡 P3 (alertword.py and the page's mirror)
  2 the 14:00 study (afternoon.py): its NIFTY rows were all 0 - NIFTY's 5-min file was not found under "NIFTY 50". Now it tries "NIFTY 50",
    "NIFTY", "NIFTY50"; with none, the market's way at 14:00 = the median 14:00 move of the F&O shares (said in the report)
Usage: python3 p217_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        print("  %s: not on this server - skipped" % f); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("alertword.py", '''    if k == "🧩":                                                # patch 191: an OI reading rings only as a measured BUY
        return "act" if (clean_buy and buy_line) else "read"''', '''    if k == "🧩":                                                # patch 191: an OI reading rings only as a measured BUY
        if clean_buy and buy_line:
            return "act" if meas else "move"                    # patch 217: P1 only when measured (55%+ of 50+) - else P2, it still rings
        return "read"''', "🧩 P1 only for a measured BUY")
rep("home.html", '''  if(k==="🧩") return (cleanBuy&&buyLine)?"act":"watch";''', '''  if(k==="🧩") return (cleanBuy&&buyLine)?(meas?"act":"move"):"watch";   /* patch 217: P1 only for a measured BUY */''', "the page's mirror")
rep("afternoon.py", '''    NI = {}
    try:
        nd, nm = S.daily("NIFTY 50"), S.intraday("NIFTY 50")
        ks = sorted(nd)
        for j in range(1, len(ks)):
            x = nm.get(ks[j])
            if x is not None and x[5][I14]:
                NI[ks[j]] = (float(x[3][I14]) / nd[ks[j - 1]][3] - 1) * 100
    except Exception as ex:
        print("NIFTY: %s" % ex)
    R, base = run(syms, lambda s: (S.daily(s), S.intraday(s)), NI)''', '''    NI, src = nifty_at_14(S, syms)                              # patch 217: the NIFTY rows were 0 (no "NIFTY 50" 5-min file)
    print("NIFTY at 14:00: %s (%d days)" % (src, len(NI)))
    R, base = run(syms, lambda s: (S.daily(s), S.intraday(s)), NI)''', "afternoon: NIFTY found, or the F&O median")
rep("afternoon.py", '''def report(R, base):''', '''def nifty_at_14(S, syms):
    """patch 217: {day: NIFTY % at 14:00} and where it came from - NIFTY's own 5-min file (by any of its names), else the median 14:00 move
    of the F&O shares (the market's way that day)"""
    for nm in ("NIFTY 50", "NIFTY", "NIFTY50", "NIFTY_50"):
        try:
            nd, n5 = S.daily(nm), S.intraday(nm)
        except Exception:
            continue
        ks = sorted(nd or {})
        NI = {}
        for j in range(1, len(ks)):
            x = (n5 or {}).get(ks[j])
            if x is not None and x[5][I14] and nd[ks[j - 1]][3]:
                NI[ks[j]] = (float(x[3][I14]) / nd[ks[j - 1]][3] - 1) * 100
        if len(NI) >= 50:
            return NI, "NIFTY's own 5-min file (%s)" % nm
    per = {}
    for s in syms:
        try:
            Dd, M = S.daily(s), S.intraday(s)
        except Exception:
            continue
        ks = sorted(Dd or {})
        for j in range(1, len(ks)):
            x = (M or {}).get(ks[j])
            pc = Dd[ks[j - 1]][3]
            if x is not None and x[5][I14] and pc:
                per.setdefault(ks[j], []).append((float(x[3][I14]) / pc - 1) * 100)
    NI = {k: sorted(v)[len(v) // 2] for k, v in per.items() if len(v) >= 20}
    return NI, "no NIFTY 5-min file - the median 14:00 move of the F&O shares that day"


def report(R, base):''', "afternoon: the NIFTY finder")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 217 in")
PY_PATCH
cat > $D/p217test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p217test.py - patch 217's own test: the 🧩 levels and the 14:00 study's NIFTY (made-up data, nothing sent). python3 p217test.py DIR [OLD_DIR]"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "."))
import alertword as A, afternoon as F
OK = []
def chk(n, c, g=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(g)[:300]))
print("1 · the 🧩 OI scenario levels")
cw = "🧩 CALL WRITERS RUNNING ▲ SBIN ₹1,004 +1.8% · 11:20\ncall writers at 1000 buying back, premium up\n▶ BUY CE 1000 · ₹18 · stop 990"
chk("CALL WRITERS RUNNING with a BUY line, not measured: 🟠 P2 (rings, not ACT NOW)", A.tier(cw) == "move", A.tier(cw))
chk("… measured 61% right of 120: 🔴 P1 ACT NOW", A.tier(cw + "\nmeasured: 61% right of 120") == "act", A.tier(cw + "\nmeasured: 61% right of 120"))
chk("… measured but only 48% right: 🟠 P2", A.tier(cw + "\nmeasured: 48% right of 120") == "move")
chk("… measured 70% but only on 20 cases: 🟠 P2", A.tier(cw + "\nmeasured: 70% right of 20") == "move")
chk("… a WATCH, not a BUY: 🟡 P3", A.tier(cw.replace("▶ BUY CE", "▶ WATCH CE")) == "read")
chk("… no BUY line: 🟡 P3", A.tier("🧩 CALL WRITERS RUNNING ▲ SBIN ₹1,004 +1.8%\ncall writers at 1000 buying back") == "read")
print("2 · nothing else changed: every other alert keeps its level (the file before this patch vs after)")
OLD = sys.argv[2] if len(sys.argv) > 2 else None
if OLD:
    import importlib.util
    sp = importlib.util.spec_from_file_location("alertword_old", os.path.join(OLD, "alertword.py")); AO = importlib.util.module_from_spec(sp); sp.loader.exec_module(AO)
    others = ["🟢 GO · SWIGGY ▲ CE · 09:16\ngap +1.7%", "⚡ ENTER NOW ▲ GAIL · CE\n▶ BUY CE 200", "🟠 OI ▲ JIOFIN · CE · ₹331 +2.1% · 14:05",
              "🚨 CRITICAL · SECTOR JUMP ▲ FERTILISER · 12:17", "📰 NEWS ▲ AXISBANK · REG · ET 10:02\nRBI nod", "🚀 RUNNING ▲ RVNL ₹412 +2.4%",
              "📄 FILING ▲ IDEA · board meeting", "🚨 PULL STARTED ▼ PNB · 11:07", "🌐 FOREIGN · ABB · x 22:40", "🟡 DIGEST · 09:15–09:30 · 12 quiet",
              "⚠️ SHOCK WATCH ▼ AUROPHARMA · USFDA", "🚨 SUDDEN UPL ₹558 +3.0%", "🌅 PRE-OPEN 09:08 · 5 gaps", "💼 YOUR TRADE COROMANDEL CE"]
    diff = [(x.split("\n")[0], AO.tier(x), A.tier(x)) for x in others if AO.tier(x) != A.tier(x)]
    chk("%d other kinds of alert: the same level as before" % len(others), not diff, diff)
else:
    chk("🟢 GO: still 🔴 P1", A.tier("🟢 GO · SWIGGY ▲ CE · 09:16\ngap +1.7%") == "act")
    chk("⚡ ENTER NOW: still 🔴 P1", A.tier("⚡ ENTER NOW ▲ GAIL · CE\n▶ BUY CE 200") == "act")
print("3 · the 14:00 study: NIFTY at 14:00")
def bars(c14):
    x = np.zeros((6, 75), dtype=np.float32); x[3, :] = c14; x[5, :] = 1; return x
days = ["2026-01-%02d" % d for d in range(1, 32)] + ["2026-02-%02d" % d for d in range(1, 29)] + ["2026-03-%02d" % d for d in range(1, 31)]
class S1:      # NIFTY 50 there
    @staticmethod
    def daily(s): return {d: (0, 0, 0, 100.0, 0) for d in days} if s in ("NIFTY 50", "A", "B") else {}
    @staticmethod
    def intraday(s): return {d: bars(101.0) for d in days} if s == "NIFTY 50" else {}
NI, src = F.nifty_at_14(S1, [])
chk("NIFTY's own file there: used, +1.0% at 14:00", "NIFTY's own" in src and abs(list(NI.values())[0] - 1.0) < 1e-6, (src, list(NI.values())[:1]))
class S2:      # no NIFTY file: 25 shares, 15 up 0.5%, 10 down 0.5%
    @staticmethod
    def daily(s): return {d: (0, 0, 0, 100.0, 0) for d in days} if s.startswith("S") else {}
    @staticmethod
    def intraday(s): return {d: bars(100.5 if int(s[1:]) < 15 else 99.5) for d in days} if s.startswith("S") else {}
NI, src = F.nifty_at_14(S2, ["S%d" % i for i in range(25)])
chk("no NIFTY file: the F&O median, said so (+0.5% - most shares up)", "median" in src and len(NI) > 50 and abs(list(NI.values())[0] - 0.5) < 1e-4, (src, len(NI), list(NI.values())[:1]))
print("CHANGE 217 test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p217_patch.py $D || back
cd $D && python3 -m py_compile alertword.py afternoon.py || back
timeout 60 python3 p217test.py $D $W/old > /tmp/p217test.out 2>&1; R=$?; cat /tmp/p217test.out; [ $R = 0 ] || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 217 done - Ctrl + Shift + R on GIR. 🧩 BUYs are P1 only when measured; the 14:00 study reads NIFTY again"
echo "   (re-run the study after 15:35:  cd $D && nohup python3 afternoon.py > /tmp/afternoon.out 2>&1 &   then: head -40 /tmp/afternoon.out)"
echo "   undo: for f in alertword.py home.html afternoon.py; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
