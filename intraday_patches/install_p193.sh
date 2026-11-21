#!/bin/bash
# PATCH 193 - GIR's AI reading at about a quarter of the cost (Rama, 11 Nov: $19 in 6 days - 600-900 calls a day, all on Sonnet 4.5):
#   Haiku 4.5 first (a third of the price) · Sonnet only for a results table Haiku is not sure of · the same question within 2 days is
#   not paid twice · a limit of $1.00 a day (results may use 1.5x), then GIR's own reader + one "⚠️ GIR AI budget" line.
#   Restarts the engine (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
cp $D/llmread.py $D/llmread.py.bak$TS
back(){ cp $D/llmread.py.bak$TS $D/llmread.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p193_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p193_patch.py - PATCH 193: GIR's AI reading costs about a quarter (Rama, 11 Nov: $19 in 6 days - 600-900 calls a day, all on
Claude Sonnet 4.5, about $3.50-4.50 a day):
  * every reading goes to Claude Haiku 4.5 first ($1 / $5 a million tokens, a third of Sonnet's $3 / $15)
  * a results table goes to Sonnet only when Haiku finds no table or is under 75% sure
  * the same question within 2 days is answered from GIR's own store (data/llm_cache.db) - no new call
  * a daily limit: $1.00 a day (data/llm_budget.json {"usd_per_day": 1.0}); results may use up to 1.5x it. Past it, GIR's own
    reader carries on and ONE "⚠️ GIR AI budget" line goes to Telegram
  * data/llm_usage.json keeps the dollars of each day (usd)
Usage: python3 p193_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []
p = os.path.join(D, "llmread.py")
s = open(p, encoding="utf-8").read()
if "patch 193" in s:
    print("  llmread.py: already in"); sys.exit(0)


def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        ERR.append("llmread.py: anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  llmread.py: %s" % tag)


rep('''MODELS = [m for m in [os.environ.get("GIR_LLM_MODEL", "")] if m] + ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001"]''',
    '''MODELS = [m for m in [os.environ.get("GIR_LLM_MODEL", "")] if m] + ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001"]
# patch 193: Haiku first (a third of the price), Sonnet only for a results table Haiku is not sure of; a daily $ limit; a 2-day store
CHEAP = ["claude-haiku-4-5", "claude-haiku-4-5-20251001"]
STRONG = ["claude-sonnet-4-5", "claude-sonnet-4-5-20250929"]
PRICE = {"haiku": (1.0, 5.0), "sonnet": (3.0, 15.0), "opus": (15.0, 75.0)}       # $ per million tokens in / out
BUDGET_DEFAULT = 1.0''', "Haiku first, Sonnet for unsure results")

rep('''        row = d.setdefault(k, {"calls": 0, "in": 0, "out": 0, "models": {}})
        row["calls"] += 1; row["in"] += inp; row["out"] += out''',
    '''        row = d.setdefault(k, {"calls": 0, "in": 0, "out": 0, "models": {}})
        row["calls"] += 1; row["in"] += inp; row["out"] += out
        pi, po = next((v for n, v in PRICE.items() if n in model), PRICE["sonnet"])
        row["usd"] = round(row.get("usd", 0) + (inp * pi + out * po) / 1e6, 4)          # patch 193''', "the dollars of each day")

a = s.find("def ask(prompt, max_tokens=1500):")
b = s.find("\ndef _json(text):")
if a < 0 or b < 0:
    ERR.append("llmread.py: ask() not found")
else:
    s = s[:a] + '''def spent_today():
    """$ spent on the AI today (data/llm_usage.json; days before patch 193 counted at Sonnet's price)"""
    try:
        d = json.load(open(os.path.join(BASE, "data", "llm_usage.json")))
        row = d.get(str(dt.date.today())) or {}
        if "usd" in row:
            return float(row["usd"])
        return (row.get("in", 0) * 3.0 + row.get("out", 0) * 15.0) / 1e6
    except Exception:
        return 0.0


def budget():
    try:
        return float((json.load(open(os.path.join(BASE, "data", "llm_budget.json"))) or {}).get("usd_per_day", BUDGET_DEFAULT))
    except Exception:
        return BUDGET_DEFAULT


def _warn_once(spent, cap):
    """one ⚠️ line a day when the limit is reached"""
    try:
        f = os.path.join(BASE, "data", "llm_budget_warned.txt")
        today = str(dt.date.today())
        if os.path.exists(f) and open(f).read().strip() == today:
            return
        open(f, "w").write(today)
        import core
        core.tg("⚠️ GIR AI budget reached · $%.2f of $%.2f today · results and news are read by GIR's own reader until midnight\\n"
                "more: echo '{\\"usd_per_day\\": 2}' > %s" % (spent, cap, os.path.join(BASE, "data", "llm_budget.json")))
    except Exception:
        pass


def _cache(key, val=None):
    """the 2-day store: the same question is not paid for twice (several GIR programs share it - sqlite)"""
    import sqlite3, time
    try:
        c = sqlite3.connect(os.path.join(BASE, "data", "llm_cache.db"), timeout=3)
        c.execute("create table if not exists q(k text primary key, t real, text text, model text)")
        if val is None:
            r = c.execute("select text, model from q where k=? and t>?", (key, time.time() - 2 * 86400)).fetchone()
            c.close()
            return r
        c.execute("insert or replace into q values(?,?,?,?)", (key, time.time(), val[0], val[1]))
        if int(time.time()) % 50 == 0:
            c.execute("delete from q where t<?", (time.time() - 3 * 86400,))
        c.commit(); c.close()
    except Exception:
        return None


def ask(prompt, max_tokens=1500, strong=False, results=False):
    """-> (text, model). patch 193: Haiku first (strong=True: Sonnet first); the 2-day store; the daily $ limit (results get 1.5x).
    Raises when nothing answered - every caller already falls back to GIR's own reader then."""
    import hashlib
    key = hashlib.sha1(("%s|%d|%s" % ("S" if strong else "H", max_tokens, prompt)).encode("utf-8", "ignore")).hexdigest()
    hit = _cache(key)
    if hit:
        return hit[0], hit[1]
    cap, spent = budget(), spent_today()
    if spent >= cap * (1.5 if results else 1.0):
        _warn_once(spent, cap)
        raise RuntimeError("daily AI budget spent ($%.2f of $%.2f)" % (spent, cap))
    import anthropic
    client = anthropic.Anthropic()
    env = [m for m in [os.environ.get("GIR_LLM_MODEL", "")] if m]
    order = (env + STRONG + CHEAP) if strong else (CHEAP + env + STRONG)
    last = None
    for m in order:
        try:
            kw = dict(model=m, max_tokens=max_tokens, messages=[{"role": "user", "content": prompt}])
            try:
                r = client.messages.create(temperature=0, **kw)
            except TypeError:                                   # an SDK that does not take temperature here
                r = client.messages.create(**kw)
            text = "".join(getattr(b, "text", "") for b in r.content)
            try:
                _usage(m, r.usage.input_tokens, r.usage.output_tokens)
            except Exception:
                pass
            _cache(key, (text, m))
            return text, m
        except Exception as ex:
            last = ex
            if "not_found" in str(ex).lower() or "model" in str(ex).lower() and "not" in str(ex).lower():
                continue
            raise
    raise RuntimeError("no model answered: %s" % str(last)[:120])

''' + s[b + 1:]
    print("  llmread.py: the store, the daily limit, Haiku first")

rep('''        text, model = ask(PROMPT.format(name=name or sym or "the company", pages=body))
        j = _json(text)
        rows = j.get("rows") or {}
        if any(isinstance(rows.get(k), (list, tuple)) and rows[k] and rows[k][0] is not None for k in ("revenue", "pat", "pbt")):
            break''',
    '''        text, model = ask(PROMPT.format(name=name or sym or "the company", pages=body), results=True)
        j = _json(text)
        rows = j.get("rows") or {}
        found = any(isinstance(rows.get(k), (list, tuple)) and rows[k] and rows[k][0] is not None for k in ("revenue", "pat", "pbt"))
        if skip == 0 and "haiku" in model and (not found or float(j.get("confidence") or 0) < 0.75):   # patch 193: Haiku unsure -> Sonnet once
            try:
                t2, m2 = ask(PROMPT.format(name=name or sym or "the company", pages=body), strong=True, results=True)
                j2 = _json(t2); r2 = j2.get("rows") or {}
                if any(isinstance(r2.get(k), (list, tuple)) and r2[k] and r2[k][0] is not None for k in ("revenue", "pat", "pbt")):
                    j, rows, model, found = j2, r2, m2, True
            except Exception:
                pass
        if found:
            break''', "results: Sonnet only when Haiku is unsure")

if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
bp = os.path.join(D, "data", "llm_budget.json")
if not os.path.exists(bp):
    os.makedirs(os.path.dirname(bp), exist_ok=True)
    open(bp, "w").write('{"usd_per_day": 1.0}\n'); print("  data/llm_budget.json: $1.00 a day")
print("patch 193 written")
PY_PATCH
cat > $D/p193test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p193test.py - PATCH 193: Haiku first, Sonnet only for an unsure results table, the 2-day store, the daily $ limit (no real call)"""
import os, sys, json, types, shutil, tempfile
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp(); shutil.copy(os.path.join(B, "llmread.py"), W); os.makedirs(os.path.join(W, "data"))
sys.path.insert(0, W)
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
CALLS, SENT = [], []
REPLY = {"haiku": '{"rows": {"revenue": [100, 90, 80], "pat": [10, 9, 8]}, "confidence": 0.9, "unit": "crore"}',
         "sonnet": '{"rows": {"revenue": [101, 91, 81], "pat": [11, 9, 8]}, "confidence": 0.95, "unit": "crore"}'}
class _Msgs:
    def create(self, model, max_tokens, messages, temperature=0):
        CALLS.append(model)
        k = "haiku" if "haiku" in model else "sonnet"
        return types.SimpleNamespace(content=[types.SimpleNamespace(text=REPLY[k])], usage=types.SimpleNamespace(input_tokens=1000000, output_tokens=100000))
fake = types.ModuleType("anthropic"); fake.Anthropic = lambda: types.SimpleNamespace(messages=_Msgs()); sys.modules["anthropic"] = fake
core = types.ModuleType("core"); core.tg = lambda t, silent=None: SENT.append(t); sys.modules["core"] = core
import llmread as L
json.dump({"usd_per_day": 100}, open(os.path.join(W, "data", "llm_budget.json"), "w"))
t, m = L.ask("headline one", max_tokens=300)
check("news: Haiku first (%s)" % m, "haiku" in m and CALLS == [m])
t2, m2 = L.ask("headline one", max_tokens=300)
check("the same question again: from the store, no new call", len(CALLS) == 1 and t2 == t)
u = json.load(open(os.path.join(W, "data", "llm_usage.json")))
row = list(u.values())[0]
check("usage keeps the dollars: 1M in + 0.1M out on Haiku = $1.50 (%s)" % row.get("usd"), abs(row.get("usd", 0) - 1.5) < 1e-6)
CALLS.clear()
r = L.read_results(["Statement of unaudited financial results for the quarter ended 30 Sep 2026 revenue from operations net profit quarter ended"], "X", "X")
check("results, Haiku sure (0.9): no Sonnet call", CALLS and all("haiku" in c for c in CALLS) and r and r["model"].startswith("claude-haiku"))
REPLY["haiku"] = REPLY["haiku"].replace('"confidence": 0.9', '"confidence": 0.5'); CALLS.clear()
r = L.read_results(["Statement of unaudited financial results for the quarter ended 30 Sep 2026 revenue from operations net profit quarter ended (b)"], "X", "X")
check("results, Haiku unsure (0.5): Sonnet reads it once (%s)" % CALLS, any("sonnet" in c for c in CALLS) and r and "sonnet" in r["model"] and r["rev"]["cur"] == 101)
# the daily limit
json.dump({"usd_per_day": 1.0}, open(os.path.join(W, "data", "llm_budget.json"), "w")); CALLS.clear()
try:
    L.ask("headline two", max_tokens=300); ok = False
except RuntimeError as ex:
    ok = "budget" in str(ex)
check("over $1.00 today: no call, an error the callers already handle", ok and not CALLS)
check("one ⚠️ GIR AI budget line to Telegram", len(SENT) == 1 and SENT[0].startswith("⚠️ GIR AI budget"))
try:
    L.ask("headline three", max_tokens=300)
except RuntimeError:
    pass
check("... only once a day", len(SENT) == 1)
json.dump({"usd_per_day": 50}, open(os.path.join(W, "data", "llm_budget.json"), "w"))
t, m = L.ask("headline four", max_tokens=300)
check("the limit raised -> it reads again", "haiku" in m)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 193"
python3 $W/p193_patch.py $D || back
cd $D && python3 -m py_compile llmread.py || back
echo "=== the test (a copy, a stand-in for Claude - no real call, no cost)"
timeout 60 python3 $D/p193test.py > /tmp/p193test.out 2>&1; R=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p193test.out | head; [ $R = 0 ] || back
echo "=== restarting the programs that read with the AI"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
sleep 20
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
[ $OK = 1 ] || { echo "the page server did not come back - old file back"; back; }
echo
echo "✅ patch 193 done. The AI now reads on Haiku first, at most \$1.00 a day (about \$0.60-1.20 in results season, was \$3.50-4.50)."
echo "   today's spend:   python3 -c \"import json;d=json.load(open('$D/data/llm_usage.json'));[print(k,v.get('usd'),v['calls'],v['models']) for k,v in sorted(d.items())[-3:]]\""
echo "   a different limit (e.g. \$2):   echo '{\"usd_per_day\": 2}' > $D/data/llm_budget.json"
