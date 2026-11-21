#!/bin/bash
# PATCH 230 - "📜 YOUR RULE" becomes "📜 PATTERN" (Rama, 12 Nov: these are GIR's own option-chain / futures pattern alerts, not rules he set).
#   The wording only - what rings is unchanged. Every reader accepts both names (today's history still says YOUR RULE): the desk, the alert
#   levels, ENTER NOW's OI checks, the ring rules (🔕 "a pattern alert - it rings when a GIR alert on X agrees"), the page, the engine.
#   Tested: 6 cases + the page. Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F=""; for f in desk.py alertword.py enternow.py ringgov.py home.html engine2.py; do [ -f $D/$f ] && { cp $D/$f $D/$f.bak$TS; F="$F $f"; }; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p230_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p230_patch.py - PATCH 230: "📜 YOUR RULE" is renamed "📜 PATTERN" (Rama, 12 Nov: "please don't tell me my own rules - I am not an F&O expert"
- these are GIR's own option-chain / futures pattern alerts, e.g. "roof breaking - writers running"). The alert's body says "pattern:" not
"rule:". Every reader accepts both names (today's history still says YOUR RULE): the desk, the alert levels, ENTER NOW's OI checks, the ring
rules, the page, and the engine's share-name reader (PATTERN is not a share). Usage: python3 p230_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, every=False, need=True):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        (ERR.append("%s missing" % f) if need else print("  %s: not here - skipped" % f)); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    n = s.count(old)
    if n == 0 or (n > 1 and not every):
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, n)); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s%s" % (f, tag, (" (%d places)" % n) if n > 1 else ""))


rep("desk.py", '''txt = "📜 YOUR RULE \\"%s\\" · %s ₹%g%s · %s\\n%s\\nshare price going %s → %s side · %s\\n%s\\nrule: %s · measured: %s" % (''',
    '''txt = "📜 PATTERN \\"%s\\" · %s ₹%g%s · %s\\n%s\\nshare price going %s → %s side · %s\\n%s\\npattern: %s · measured: %s" % (''', "the alert says 📜 PATTERN")
rep("desk.py", '''m = re.search(r"SUDDEN (\\S+)|YOUR RULE \\"[^\\"]*\\" · (\\S+)", first)''',
    '''m = re.search(r"SUDDEN (\\S+)|(?:YOUR RULE|PATTERN) \\"[^\\"]*\\" · (\\S+)", first)''', "the desk reads both names")
rep("alertword.py", "📜 YOUR RULE", "📜 (?:YOUR RULE|PATTERN)", "the levels read both names", every=True)
rep("enternow.py", '''OI_RX = re.compile(r"YOUR RULE|''', '''OI_RX = re.compile(r"YOUR RULE|📜 PATTERN|''', "ENTER NOW's OI checks read both", need=False)
rep("enternow.py", '''"rule" if "YOUR RULE" in head''', '''"rule" if ("YOUR RULE" in head or "📜 PATTERN" in head)''', "ENTER NOW's kind reads both", need=False)
rep("ringgov.py", '''    yr = "YOUR RULE" in h''', '''    yr = "YOUR RULE" in h or "📜 PATTERN" in h                  # patch 230: GIR's pattern alerts (renamed from YOUR RULE)''', "the ring rules read both", need=False)
rep("ringgov.py", '''"your rule - it rings when it agrees with a GIR alert on %s (none the same way in the last 15 min)"''',
    '''"a pattern alert - it rings when a GIR alert on %s agrees (none the same way in the last 15 min)"''', "the 🔕 line says pattern", need=False)
rep("home.html", "📜 YOUR RULE", "📜 (?:YOUR RULE|PATTERN)", "the page reads both names", every=True)
rep("engine2.py", "|RULE|SCORECARD|", "|RULE|PATTERN|SCORECARD|", "PATTERN is not a share name", need=False)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 230 in")
PY_PATCH
cat > $W/p230test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p230test.py - "📜 YOUR RULE" renamed "📜 PATTERN": every reader treats both the same (nothing sent).  python3 p230test.py DIR"""
import os, sys, re, shutil, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "ringgov.py", "desk.py", "enternow.py", "engine2.py"):
    if os.path.exists(os.path.join(D, f)):
        shutil.copy(os.path.join(D, f), T)
sys.path.insert(0, T); os.chdir(T)
import alertword as A
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:300]))
old = '📜 YOUR RULE "roof breaking - writers running" · SBILIFE ₹1805.3 +2.2% · 10:00\nroof at 1800 BREAKING\nshare price going UP → CE side · desk BULLISH +1\nrule: roof breaking · measured: 61% right of 120'
new = old.replace("📜 YOUR RULE", "📜 PATTERN").replace("\nrule:", "\npattern:")
desk = open("desk.py", encoding="utf-8").read()
chk("the desk now writes 📜 PATTERN \"...\" and 'pattern:'", '📜 PATTERN \\"%s\\"' in desk and "\\npattern: %s · measured" in desk)
m = re.search(r"SUDDEN (\S+)|(?:YOUR RULE|PATTERN) \"[^\"]*\" · (\S+)", new.split("\n")[0])
chk("the desk reads the share from a PATTERN head (SBILIFE)", m and m.group(2) == "SBILIFE", m and m.groups())
chk("the alert level is the same for both names (%s)" % A.tier(old), A.tier(old) == A.tier(new) and A.tier(new) != "read", (A.tier(old), A.tier(new)))
if os.path.exists("ringgov.py"):
    import ringgov as G
    IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
    t, s = G.gate(new, A.tier(new), now=dt.datetime(2026, 11, 13, 10, 0, tzinfo=IST), px=1805.3, candles={})
    chk("the ring rules treat a PATTERN like before: no GIR alert on SBILIFE -> silent, '🔕 ... a pattern alert'", s and "a pattern alert - it rings when a GIR alert on SBILIFE agrees" in t, t.split("\n")[-1])
if os.path.exists("enternow.py"):
    en = open("enternow.py", encoding="utf-8").read()
    rx = re.search(r'OI_RX = re.compile\(r"([^"]+)"\)', en)
    chk("ENTER NOW's OI checks still see it", rx and re.search(rx.group(1), new.split("\n")[0]), rx and rx.group(1)[:60])
if os.path.exists("engine2.py"):
    chk("the engine never reads PATTERN as a share name", "|RULE|PATTERN|" in open("engine2.py", encoding="utf-8").read())
print("RENAME test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p230_patch.py $D || back
cd $D && for f in desk.py alertword.py enternow.py ringgov.py engine2.py; do [ -f $f ] && { python3 -m py_compile $f || back; }; done
echo "=== test: both names read the same"
python3 $W/p230test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 230 done - GIR's pattern alerts now say 📜 PATTERN. Ctrl + Shift + R on GIR."
echo "   undo: for f in$F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
