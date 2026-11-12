#!/bin/bash
# PATCH 212 - GIR rings when the AI reader is BLOCKED (12 Nov: Anthropic refused every call from 9 Nov - the monthly spend limit was reached -
#   2,216 calls failed and no alarm rang, patch 195 knew only "credit balance too low"). A spend limit, a used-up credit or a refused key now
#   ring 🚨 CRITICAL with Anthropic's own words and where to fix it; "the AI reader is back ✅" when it works. Restarts the readers (seconds).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
cp $D/llmread.py $D/llmread.py.bak$TS
back(){ cp $D/llmread.py.bak$TS $D/llmread.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p212_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p212_patch.py - PATCH 212: GIR rings when the AI reader is BLOCKED for any reason (12 Nov: Anthropic refused every call from 9 Nov -
"You have reached your specified API usage limits" - the monthly spend limit, $20 - 2,216 calls failed and no alarm rang: patch 195's
alarm knew only "credit balance too low"). Now a spend limit, a used-up credit, or a refused key all ring 🚨 CRITICAL with Anthropic's own
words and where to fix it; "the AI reader is back ✅" when it works again. Usage: python3 p212_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "llmread.py"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  llmread.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  llmread.py: %s" % tag)


rep('''CREDIT_RE = re.compile(r"credit balance|insufficient (credit|funds)|purchase credits|plans ?& ?billing|payment required", re.I)''',
    '''CREDIT_RE = re.compile(r"credit balance|insufficient (credit|funds)|purchase credits|plans ?& ?billing|payment required|"
                       r"usage limits?|spend(ing)? limit|reached your specified|api usage|regain access|invalid x-api-key|authentication_error|"
                       r"permission_error|api key .{0,20}(disabled|revoked|invalid)|organization .{0,30}disabled", re.I)   # patch 212: any block''',
    "a spend limit / a refused key counts as a block")
rep('''        _ring("🚨 CRITICAL · GIR AI CREDIT USED UP · %s\\nAnthropic refused Claude's call: the credit balance is used up. The news reader, the results "
              "reader and the morning brief now run on GIR's word rules (less sure).\\nTop up: console.anthropic.com → Billing → Add funds · then tell GIR "
              "the amount:  python3 %s --balance 5" % (dt.datetime.now().strftime("%H:%M"), os.path.join(BASE, "llmread.py")))''',
    '''        m_ = str(ex)
        if re.search(r"usage limits?|spend(ing)? limit|reached your specified|api usage|regain access", m_, re.I):     # patch 212
            what, fix = "SPEND LIMIT REACHED", "the monthly spend limit in your Anthropic account is reached.\\nRaise it: console.anthropic.com → Settings → Limits → Adjust limit"
        elif re.search(r"x-api-key|authentication|permission|disabled|revoked|invalid", m_, re.I) and not re.search(r"credit balance", m_, re.I):
            what, fix = "KEY REFUSED", "the API key in /home/globalbot/.env was refused.\\nCheck it: console.anthropic.com → API keys"
        else:
            what, fix = "CREDIT USED UP", "the credit balance is used up.\\nTop up: console.anthropic.com → Billing → Add funds · then:  python3 %s --balance 5" % os.path.join(BASE, "llmread.py")
        said = re.search(r"'message': '([^']{0,160})", m_)
        _ring("🚨 CRITICAL · GIR AI %s · %s\\nAnthropic refused Claude's call: %s\\nUntil then the news reader, the results reader and the morning brief run on "
              "GIR's word rules (less sure).%s" % (what, dt.datetime.now().strftime("%H:%M"), fix, ("\\nAnthropic said: " + said.group(1)) if said else ""))''',
    "the alarm says what blocked it and where to fix it")
rep('''            core.tg("⚠️ GIR AI · credit is back ✅ - Claude reads the news again (it was off since %s)" % since)''',
    '''            core.tg("⚠️ GIR AI · the AI reader is back ✅ - Claude reads the news again (it was off since %s)" % since)''', "the all-clear")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("llmread.py: patch 212 in")
PY_PATCH
cat > $D/p212test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p212test.py - patch 212's own test: the AI-blocked alarm on made-up Anthropic refusals (nothing sent). python3 p212test.py DIR"""
import os, sys, json, shutil, tempfile
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(SRC, "llmread.py"), T)
sys.path.insert(0, T)
import llmread as L
RANG = []
L._ring = lambda t: RANG.append(t)
L.CREDIT_F = os.path.join(T, "data", "llm_credit.json")
OK = []
def chk(n, c, g=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(g)[:300]))
def fire(msg):
    RANG.clear()
    try: os.remove(L.CREDIT_F)
    except Exception: pass
    L._credit_out(Exception(msg))
    return RANG[0] if RANG else ""
t = fire("Error code: 400 - {'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'You have reached your specified API usage limits. You will regain access on 2026-12-01 at 00:00 UTC.'}}")
chk("the spend limit (12 Nov) rings: SPEND LIMIT REACHED + Settings → Limits", "SPEND LIMIT REACHED" in t and "Settings → Limits" in t and "regain access" in t, t)
t = fire("Error code: 400 - {'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.'}}")
chk("a used-up credit rings: CREDIT USED UP + Billing", "CREDIT USED UP" in t and "Billing" in t, t)
t = fire("Error code: 401 - {'type': 'error', 'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}}")
chk("a refused key rings: KEY REFUSED", "KEY REFUSED" in t, t)
t = fire("Error code: 529 - {'type': 'error', 'error': {'type': 'overloaded_error', 'message': 'Overloaded'}}")
chk("a busy moment (overloaded) does not ring", t == "", t)
RANG.clear(); L._credit_out(Exception("You have reached your specified API usage limits")); L._credit_out(Exception("You have reached your specified API usage limits"))
chk("rings once, not on every failed call (6 h apart)", len(RANG) <= 1, RANG)
shutil.rmtree(T, ignore_errors=True)
print("AI ALARM test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p212_patch.py $D || back
cd $D && python3 -m py_compile llmread.py || back
timeout 60 python3 p212test.py $D > /tmp/p212test.out 2>&1; R=$?
cat /tmp/p212test.out; [ $R = 0 ] || back
for s in gir-newsroom gir-exchange gir-desk; do systemctl restart $s 2>/dev/null; done
sleep 5; for s in gir-newsroom gir-exchange gir-desk; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 212 done. If the AI reader is ever refused again, 🚨 GIR AI SPEND LIMIT / CREDIT / KEY rings in Box Picks within minutes."
echo "   undo: cp $D/llmread.py.bak$TS $D/llmread.py; systemctl restart gir-newsroom gir-exchange gir-desk"
