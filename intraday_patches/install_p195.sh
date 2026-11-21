#!/bin/bash
# PATCH 195 - a Telegram alert when the Claude (Anthropic API) credit runs out or runs low (Rama, 11 Nov):
#   🚨 CRITICAL · GIR AI CREDIT USED UP (rings GIR Box Picks, again every 6 h while it lasts) · ⚠️ credit is back (once) ·
#   🚨 CRITICAL · GIR AI CREDIT LOW when $1 or less is left (once a day) - after each top-up:  python3 llmread.py --balance <amount>
#   Needs patch 193. Restarts the news programs (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
cp $D/llmread.py $D/llmread.py.bak$TS
back(){ cp $D/llmread.py.bak$TS $D/llmread.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p195_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p195_patch.py - PATCH 195: a Telegram alert when the Claude (Anthropic API) credit runs out (Rama, 11 Nov - the balance hit $0
in the afternoon and GIR's news reader went quietly to word rules):
  * Anthropic refuses a call for credit -> "🚨 CRITICAL · GIR AI CREDIT USED UP" rings GIR Box Picks (again every 6 hours while it lasts)
  * the first call that works again -> "⚠️ GIR AI · credit is back" (once)
  * an early warning: after a top-up tell GIR the amount (python3 llmread.py --balance 5) - GIR counts its own spend and rings
    "🚨 CRITICAL · GIR AI CREDIT LOW · about $0.90 left · ~3 days" once a day when $1 or less is left
Needs patch 193. Usage: python3 p195_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []
p = os.path.join(D, "llmread.py")
s = open(p, encoding="utf-8").read()
if "patch 193" not in s:
    print("patch 193 is not in yet"); sys.exit(1)
if "patch 195" in s:
    print("  llmread.py: already in"); sys.exit(0)


def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        ERR.append("llmread.py: anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  llmread.py: %s" % tag)


rep('''def ask(prompt, max_tokens=1500, strong=False, results=False):''', '''# ---- patch 195: the credit watch - a Telegram alert when the Anthropic credit runs out / runs low
CREDIT_RE = re.compile(r"credit balance|insufficient (credit|funds)|purchase credits|plans ?& ?billing|payment required", re.I)
CREDIT_F = os.path.join(BASE, "data", "llm_credit.json")
BAL_F = os.path.join(BASE, "data", "llm_balance.json")
LOW_USD = 1.0


def _cstate(s_=None):
    try:
        if s_ is None:
            return json.load(open(CREDIT_F))
        json.dump(s_, open(CREDIT_F, "w"))
    except Exception:
        return {}


def _ring(text):
    """the credit alert: GIR Box Picks, with sound (falls back to GIR Intraday)"""
    try:
        import opencall
        opencall.send_tg(text); return
    except Exception:
        pass
    try:
        import core
        core.tg(text)
    except Exception:
        pass


def balance_left():
    """$ left by GIR's own count since the last top-up told with --balance; None when not told"""
    try:
        b = json.load(open(BAL_F))
        try:
            d = json.load(open(os.path.join(BASE, "data", "llm_usage.json")))
        except Exception:
            d = {}
        spent = sum(float(v.get("usd") or 0) for k, v in d.items() if k >= b["day"]) - float(b.get("base") or 0)
        return float(b["usd"]) - spent
    except Exception:
        return None


def _rate():
    try:
        d = json.load(open(os.path.join(BASE, "data", "llm_usage.json")))
        xs = [float(v["usd"]) for k, v in sorted(d.items())[-4:-1] if v.get("usd")]
        return max(sum(xs) / len(xs), 0.05) if xs else 0.25
    except Exception:
        return 0.25


def _credit_out(ex):
    if not CREDIT_RE.search(str(ex)):
        return
    import time
    st = _cstate() or {}
    now = time.time()
    if not st.get("out"):
        st["out"] = now
    if now - float(st.get("rang") or 0) > 6 * 3600:
        st["rang"] = now
        _ring("🚨 CRITICAL · GIR AI CREDIT USED UP · %s\\nAnthropic refused Claude's call: the credit balance is used up. The news reader, the results "
              "reader and the morning brief now run on GIR's word rules (less sure).\\nTop up: console.anthropic.com → Billing → Add funds · then tell GIR "
              "the amount:  python3 %s --balance 5" % (dt.datetime.now().strftime("%H:%M"), os.path.join(BASE, "llmread.py")))
    _cstate(st)


def _credit_ok():
    st = _cstate() or {}
    if st.get("out"):
        since = dt.datetime.fromtimestamp(float(st["out"])).strftime("%d %b %H:%M")
        st = {}
        _cstate(st)
        try:
            import core
            core.tg("⚠️ GIR AI · credit is back ✅ - Claude reads the news again (it was off since %s)" % since)
        except Exception:
            pass
    left = balance_left()
    if left is not None and left <= LOW_USD and st.get("low") != str(dt.date.today()):
        st["low"] = str(dt.date.today())
        _cstate(st)
        _ring("🚨 CRITICAL · GIR AI CREDIT LOW · about $%.2f left · ~%.0f day(s) at the recent rate\\nTop up: console.anthropic.com → Billing → Add funds · "
              "then:  python3 %s --balance <the new balance>" % (max(left, 0), max(left, 0) / _rate(), os.path.join(BASE, "llmread.py")))


def ask(prompt, max_tokens=1500, strong=False, results=False):''', "the credit watch")
rep('''            _cache(key, (text, m))
            return text, m
        except Exception as ex:
            last = ex
            if "not_found" in str(ex).lower() or "model" in str(ex).lower() and "not" in str(ex).lower():
                continue
            raise''', '''            _cache(key, (text, m))
            try:
                _credit_ok()                                    # patch 195
            except Exception:
                pass
            return text, m
        except Exception as ex:
            last = ex
            if "not_found" in str(ex).lower() or "model" in str(ex).lower() and "not" in str(ex).lower():
                continue
            try:
                _credit_out(ex)                                 # patch 195: no credit -> the alert
            except Exception:
                pass
            raise''', "the alert when a call is refused for credit")
rep('''if __name__ == "__main__":
    import sys
''', '''if __name__ == "__main__":
    import sys
    if sys.argv[1:2] == ["--balance"]:                         # patch 195: after a top-up - the balance the Console shows
        try:
            json.dump({"usd": float(sys.argv[2]), "day": str(dt.date.today()), "base": spent_today()}, open(BAL_F, "w"))
            st = _cstate() or {}; st.pop("low", None); _cstate(st)
            print("GIR knows: $%.2f of Claude credit from now. It rings when $%.2f is left." % (float(sys.argv[2]), LOW_USD))
        except Exception as ex:
            print("usage: python3 llmread.py --balance 5   (%s)" % ex)
        sys.exit(0)
    if sys.argv[1:2] == ["--credit"]:
        b = balance_left()
        print("spent today $%.4f · left by GIR's count: %s" % (spent_today(), ("$%.2f" % b) if b is not None else "not told - python3 llmread.py --balance <amount>"))
        sys.exit(0)
''', "--balance / --credit")

if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("patch 195 written")
PY_PATCH
cat > $D/p195test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p195test.py - PATCH 195: a Telegram alert when the Claude credit runs out / runs low (a stand-in for Claude - no real call)"""
import os, sys, json, types, shutil, tempfile, subprocess, datetime as dt
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp(); shutil.copy(os.path.join(B, "llmread.py"), W); os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W)
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
RANG, INFO = [], []
MODE = {"broke": True}
class _Msgs:
    def create(self, model, max_tokens, messages, temperature=None, extra_body=None):
        if MODE["broke"]:
            raise RuntimeError("Error code: 400 - {'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.'}}")
        return types.SimpleNamespace(content=[types.SimpleNamespace(type="text", text='{"ok": 1}')], usage=types.SimpleNamespace(input_tokens=1000, output_tokens=100))
fake = types.ModuleType("anthropic"); fake.Anthropic = lambda: types.SimpleNamespace(messages=_Msgs()); sys.modules["anthropic"] = fake
oc = types.ModuleType("opencall"); oc.send_tg = RANG.append; sys.modules["opencall"] = oc
core = types.ModuleType("core"); core.tg = lambda t, silent=None: INFO.append(t); sys.modules["core"] = core
import llmread as L
def call(q):
    try:
        return L.ask(q, max_tokens=100)
    except Exception as ex:
        return None
call("one"); call("two")
check("credit used up -> one 🚨 CRITICAL · GIR AI CREDIT USED UP to Box Picks", len(RANG) == 1 and RANG[0].startswith("🚨 CRITICAL · GIR AI CREDIT USED UP") and "--balance" in RANG[0])
check("... not again within 6 hours", len(RANG) == 1)
MODE["broke"] = False
call("three")
check("the first call that works -> 'credit is back' (once)", len(INFO) == 1 and "credit is back" in INFO[0])
call("four")
check("... only once", len(INFO) == 1)
r = subprocess.run([sys.executable, os.path.join(W, "llmread.py"), "--balance", "5"], capture_output=True, text=True)
check("python3 llmread.py --balance 5 -> GIR knows the balance", "$5.00" in r.stdout)
u = json.load(open(os.path.join(W, "data", "llm_usage.json")))
u[str(dt.date.today())]["usd"] = float(u[str(dt.date.today())]["usd"]) + 4.3          # $4.30 spent since the top-up
json.dump(u, open(os.path.join(W, "data", "llm_usage.json"), "w"))
json.dump({"usd_per_day": 100}, open(os.path.join(W, "data", "llm_budget.json"), "w"))    # the daily limit out of the way for this check
call("five")
check("$1 or less left -> 🚨 CRITICAL · GIR AI CREDIT LOW (left %.2f)" % (L.balance_left() or -1), len(RANG) == 2 and "CREDIT LOW" in RANG[1] and "about $0.70 left" in RANG[1])
call("six")
check("... once a day", len(RANG) == 2)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 195"
python3 $W/p195_patch.py $D || back
cd $D && python3 -m py_compile llmread.py || back
echo "=== the test (a stand-in for Claude and Telegram - no real call, nothing sent)"
timeout 90 python3 $D/p195test.py > /tmp/p195test.out 2>&1; R=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p195test.out | head; [ $R = 0 ] || back
echo "=== restarting the programs that use Claude"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
sleep 15
for s in gir-intraday gir-exchange gir-tvwatch; do echo "  $s: $(systemctl is-active $s)"; done
echo
echo "✅ patch 195 done. If the credit runs out: 🚨 CRITICAL · GIR AI CREDIT USED UP rings GIR Box Picks."
echo "   For the early warning, tell GIR your balance now (the number on console.anthropic.com → Billing), e.g.:"
echo "     python3 $D/llmread.py --balance 4.80"
echo "   Check any time:   python3 $D/llmread.py --credit"
