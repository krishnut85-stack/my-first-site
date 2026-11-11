#!/bin/bash
# PATCH 194 - Claude reads the WHOLE story and says BULLISH or BEARISH (Rama, 11 Nov: "I want the news to be confirmed by Claude
#   whether bullish or bearish" - GIR's reader saw only the headline). The alerts and the page's news line now say:
#   "🤖 CLAUDE read the full story: BULLISH ▲ (CE side)" / "BEARISH ▼ (PE side)" / "NEUTRAL" + why.
#   Reads on Claude Haiku 5.5 ($0.10 / $0.50 a million tokens): full stories cost about $0.25 a day. Needs patch 193.
#   Restarts the engine (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
FILES="llmread.py newsalert.py desk.py"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/newsbody.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/newsbody.py <<'PY_NB'
#!/usr/bin/env python3
"""newsbody.py - patch 194: the WHOLE story behind a headline, for Claude to read before it says BULLISH or BEARISH
(Rama, 11 Nov: "I want the news to be confirmed by Claude whether bullish or bearish" - GIR's reader saw only the headline).
  get(link) -> the article's own words (up to 4,000 characters), '' when the page cannot be read (paywall, blocked, no text).
  A Google News link is first turned into the publisher's own address. Kept 2 days in data/newsbody.db (read once, used by
  every GIR program). Never raises.
  python3 newsbody.py <link>     prints what Claude would read"""
import os, re, html, time, sqlite3

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "data", "newsbody.db")
MAX = 4000
SKIP = re.compile(r"subscribe|sign in|log ?in to|cookie|advertisement|download the app|follow us|all rights reserved|also read|read more:", re.I)


def _db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    c = sqlite3.connect(DB, timeout=3)
    c.execute("create table if not exists b(link text primary key, t real, url text, body text)")
    return c


def extract(page):
    """the article's paragraphs from a page's HTML"""
    t = re.sub(r"(?is)<(script|style|noscript|nav|footer|header|aside|form)[^>]*>.*?</\1>", " ", page or "")
    paras = []
    for p in re.findall(r"(?is)<p[^>]*>(.*?)</p>", t):
        x = html.unescape(re.sub(r"<[^>]+>", " ", p))
        x = re.sub(r"\s+", " ", x).strip()
        if len(x) >= 50 and not SKIP.search(x[:80]):
            paras.append(x)
    body = " ".join(paras)
    if len(body) < 200:                                         # a page without <p> paragraphs: the plain text
        x = html.unescape(re.sub(r"<[^>]+>", " ", t))
        body = re.sub(r"\s+", " ", x).strip()
        body = body if len(body) >= 200 else ""
    return body[:MAX]


def get(link, get_=None, post_=None):
    if not link or not str(link).startswith("http"):
        return ""
    try:
        c = _db()
        r = c.execute("select body from b where link=? and t>?", (link, time.time() - 2 * 86400)).fetchone()
        if r is not None:
            c.close()
            return r[0] or ""
    except Exception:
        c = None
    body, url = "", link
    try:
        import newsfresh
        g, p = get_ or newsfresh._get, post_ or newsfresh._post
        if "news.google.com" in link:
            url = newsfresh.google_real(link, g, p) or ""
        if url.startswith("http"):
            resp = g(url)
            if getattr(resp, "ok", True):
                body = extract(getattr(resp, "text", "") or "")
    except Exception:
        body = ""
    try:
        if c is not None:
            c.execute("insert or replace into b values(?,?,?,?)", (link, time.time(), url, body))
            if int(time.time()) % 40 == 0:
                c.execute("delete from b where t<?", (time.time() - 3 * 86400,))
            c.commit(); c.close()
    except Exception:
        pass
    return body


if __name__ == "__main__":
    import sys
    b = get(sys.argv[1]) if len(sys.argv) > 1 else ""
    print("%d characters\n%s" % (len(b), b[:1500]))
PY_NB
cat > $W/p194_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p194_patch.py - PATCH 194: Claude reads the WHOLE story and says BULLISH or BEARISH (Rama, 11 Nov):
  * newsalert (the alerts) and the desk's news reader (the page) send Claude the article itself (newsbody.py, up to 4,000 characters),
    not only the headline; an NSE filing goes with 2,500 characters of its text (was 600-900)
  * every read item says it plainly: "🤖 CLAUDE read the full story: BULLISH ▲ (CE side)" / "BEARISH ▼ (PE side)" / "NEUTRAL"
    - or "headline only" when the publisher's page could not be read
  * the reading model: Claude Haiku 5.5 first ($0.10 / $0.50 a million tokens - full stories cost about $0.25 a day), then Haiku 4.5;
    Sonnet still only for a results table the small model is not sure of. The desk reads up to 400 items a day (was 150).
Needs patch 193. Usage: python3 p194_patch.py /home/globalbot/intraday"""
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


if "patch 193" not in open(os.path.join(D, "llmread.py"), encoding="utf-8").read():
    print("patch 193 is not in yet - run install_p193.sh first"); sys.exit(1)

# ---- llmread: Haiku 5.5 first (no temperature, no thinking - a short JSON answer), any trouble with it -> the next model
rep("llmread.py", '''        row["usd"] = round(row.get("usd", 0) + (inp * pi + out * po) / 1e6, 4)          # patch 193''',
    '''        row["usd"] = round(row.get("usd", 0) + (inp * pi + out * po) / 1e6, 6)          # patch 193 · 194: 6 places (Haiku 5.5 calls cost $0.0003)''', "the dollars to 6 places")
rep("llmread.py", '''CHEAP = ["claude-haiku-4-5", "claude-haiku-4-5-20251001"]''',
    '''CHEAP = ["claude-haiku-5-5", "claude-haiku-4-5", "claude-haiku-4-5-20251001"]          # patch 194: Haiku 5.5 first''', "Haiku 5.5 first")
rep("llmread.py", '''PRICE = {"haiku": (1.0, 5.0), "sonnet": (3.0, 15.0), "opus": (15.0, 75.0)}       # $ per million tokens in / out''',
    '''PRICE = {"haiku-5": (0.10, 0.50), "haiku": (1.0, 5.0), "sonnet": (3.0, 15.0), "opus": (15.0, 75.0)}       # $ per million tokens in / out''', "Haiku 5.5's price")
rep("llmread.py", '''            kw = dict(model=m, max_tokens=max_tokens, messages=[{"role": "user", "content": prompt}])
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
            return text, m''',
    '''            kw = dict(model=m, max_tokens=max_tokens, messages=[{"role": "user", "content": prompt}])
            if "haiku-5" in m:                                  # patch 194: Haiku 5.5 takes no temperature; no thinking - a short JSON answer
                try:
                    r = client.messages.create(extra_body={"thinking": {"type": "disabled"}, "output_config": {"effort": "low"}}, **kw)
                    text = "".join(getattr(b, "text", "") or "" for b in r.content if getattr(b, "type", "text") == "text")
                    if not text.strip():
                        raise RuntimeError("empty answer")
                except Exception as ex5:
                    last = ex5
                    print("llmread: %s not used (%s) - the next model" % (m, str(ex5)[:100]), flush=True)
                    continue
            else:
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
            return text, m''', "Haiku 5.5: no temperature, no thinking, falls back on any trouble")

# ---- newsalert: the whole story, and the verdict said plainly
rep("newsalert.py", '''        r = model_read(sym, h, src, hm, kind, name) or quick_read(h, kind)''',
    '''        try:                                                    # patch 194: Claude reads the whole story, not only the headline
            import newsbody
            body = newsbody.get(link)
        except Exception:
            body = ""
        r = model_read(sym, (h + "\\n\\nTHE FULL STORY:\\n" + body) if body else h, src, hm, kind, name) or quick_read(h, kind)
        r = dict(r, full=bool(body))''', "the alerts: the whole story")
rep("newsalert.py", '''text=text[:1800]), max_tokens=350)''', '''text=text[:5200]), max_tokens=350)''', "the reader takes up to 5,200 characters")
rep("newsalert.py", '''    r = model_read(f["sym"], "%s — %s" % (f.get("subject") or "", (f.get("detail") or "")[:900]), "NSE filing", "", f.get("kind") or "")''',
    '''    r = model_read(f["sym"], "%s — %s" % (f.get("subject") or "", (f.get("detail") or "")[:2500]), "NSE filing", "", f.get("kind") or "")   # patch 194: 2,500 characters
    if r:
        r = dict(r, full=True)''', "a filing: 2,500 characters of it")
rep("newsalert.py", '''        L.append("the reader (%s): %s · %s%s · sure %.0f%%" % (r.get("model") or "model", r["reason"] or "-", r["level"].upper(), " · ALREADY KNOWN" if r["known"] else "", 100 * r["conf"]))''',
    '''        L.append("🤖 CLAUDE read %s: %s · %s" % ("the full story" if r.get("full") else "the headline only (the page could not be read)",
                                                ("BULLISH ▲ (CE side)" if r["side"] > 0 else "BEARISH ▼ (PE side)" if r["side"] < 0 else "NEUTRAL"), r.get("model") or "model"))   # patch 194
        L.append("why: %s · %s%s · sure %.0f%%" % (r["reason"] or "-", r["level"].upper(), " · ALREADY KNOWN" if r["known"] else "", 100 * r["conf"]))''', "the verdict said plainly")

# ---- desk (the page's news reader): the link -> the whole story; filings 2,500 characters; 400 reads a day
rep("desk.py", '''LLM_DAY_CAP = 150''', '''LLM_DAY_CAP = 400                                              # patch 194: was 150 (Haiku 5.5 - full stories about $0.25 a day)''', "400 reads a day")
rep("desk.py", '''                out.append((key, sym, t_exch, kind, (subject or "") + " — " + (detail or "")[:600], side or 0, "filing"))''',
    '''                out.append((key, sym, t_exch, kind, (subject or "") + " — " + (detail or "")[:2500], side or 0, "filing"))   # patch 194: 2,500 characters''', "the desk: a filing's 2,500 characters")
rep("desk.py", '''            for key, sym, t_pub, kind, h, side, score in c.execute("select key, sym, t_pub, kind, h, side, score from items where t_pub > ? and (score >= 2 or big = 1)", (t0,)):
                out.append((key, sym, t_pub, kind or "NEWS", h or "", side or 0, "headline"))''',
    '''            for key, sym, t_pub, kind, h, side, score, l in c.execute("select key, sym, t_pub, kind, h, side, score, l from items where t_pub > ? and (score >= 2 or big = 1)", (t0,)):
                out.append((key, sym, t_pub, kind or "NEWS", h or "", side or 0, "headline", l or ""))   # patch 194: + the link''', "the desk: the story's link")
rep("desk.py", '''        for key, sym, when, kind, text, side_fb, src in self.items():''',
    '''        for it_ in self.items():
            key, sym, when, kind, text, side_fb, src = it_[:7]
            link_ = it_[7] if len(it_) > 7 else ""''', "the desk: reads the link")
rep("desk.py", '''                        r = self.ask(sym, kind, text); self.calls["n"] += 1''',
    '''                        body_ = ""
                        if link_:                                       # patch 194: the whole story for Claude
                            try:
                                import newsbody
                                body_ = newsbody.get(link_)
                            except Exception:
                                body_ = ""
                        r = self.ask(sym, kind, (text + "\\n\\nTHE FULL STORY:\\n" + body_) if body_ else text); self.calls["n"] += 1
                        r["full"] = bool(body_) or src == "filing"''', "the desk: Claude reads the whole story")
rep("desk.py", '''"\\"known\\": true/false, \\"reason\\": \\"one plain line a trader would say\\"}") % (self.rules_text(), sym, kind, text[:1800])''',
    '''"\\"known\\": true/false, \\"reason\\": \\"one plain line a trader would say\\"}") % (self.rules_text(), sym, kind, text[:5200])''', "the desk reader takes 5,200 characters")

rep("desk.py", '''        return {"v": v, "line": "news %s: %s (%s, sure %.0f%%)" % ("→ UP" if v > 0 else "→ DOWN" if v < 0 else "", r.get("reason") or "", r.get("kind"), r["conf"] * 100), "item": r}''',
    '''        who_ = ("🤖 Claude, full story" if r.get("full") else "🤖 Claude, headline") if str(r.get("model") or "").startswith("claude") else "word rules"   # patch 194
        return {"v": v, "line": "news %s %s: %s (%s, sure %.0f%% · %s)" % ("BULLISH ▲" if v > 0 else "BEARISH ▼" if v < 0 else "", "→ CE" if v > 0 else "→ PE" if v < 0 else "", r.get("reason") or "", r.get("kind"), r["conf"] * 100, who_), "item": r}''', "the page: BULLISH / BEARISH and who read it")

if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 194 written")
PY_PATCH
cat > $D/p194test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p194test.py - PATCH 194: Claude reads the whole story and says BULLISH / BEARISH (a stand-in for Claude and the web - no real call)"""
import os, sys, json, types, shutil, tempfile
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp()
for f in ("llmread.py", "newsalert.py", "newsbody.py", "desk.py"):
    shutil.copy(os.path.join(B, f), W)
os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W); os.environ["ANTHROPIC_API_KEY"] = "test-not-a-key"
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
CALLS, PROMPTS = [], []
FAIL55 = {"on": False}
class _Msgs:
    def create(self, model, max_tokens, messages, temperature=None, extra_body=None):
        CALLS.append((model, temperature, extra_body)); PROMPTS.append(messages[0]["content"])
        if "haiku-5" in model and FAIL55["on"]:
            raise RuntimeError("bad request: something about this model")
        txt = '{"fo_relevant": true, "side": "CE", "level": "important", "known": false, "confidence": 0.8, "reason": "a big order lifts next year sales", "watch": "", "kind": "order", "material": 2}'
        return types.SimpleNamespace(content=[types.SimpleNamespace(type="text", text=txt)], usage=types.SimpleNamespace(input_tokens=2500, output_tokens=120))
fake = types.ModuleType("anthropic"); fake.Anthropic = lambda: types.SimpleNamespace(messages=_Msgs()); sys.modules["anthropic"] = fake
core = types.ModuleType("core"); core.tg = lambda *a, **k: None; sys.modules["core"] = core
nf = types.ModuleType("newsfresh")
PAGE = "<html><nav>menu</nav><p>Subscribe now</p><p>Bharat Electronics said on Tuesday it has won an order worth Rs 2,210 crore from the Ministry of Defence for radar systems.</p><p>The order takes its order book to over Rs 75,000 crore, the company said in an exchange filing. Deliveries begin next year and run over three years, the company added.</p><script>x()</script></html>"
GETS = []
nf._get = lambda u: (GETS.append(u) or types.SimpleNamespace(ok=True, text=PAGE)); nf._post = lambda u, d: None
nf.google_real = lambda link, g, p: "https://publisher.example/bel-order"
nf.check = lambda *a, **k: (True, "")
sys.modules["newsfresh"] = nf
import newsbody, llmread, newsalert
b = newsbody.get("https://news.google.com/rss/articles/ABC")
check("the whole story is read (the paragraphs, no menu / subscribe / script)", "Rs 2,210 crore" in b and "order book" in b and "Subscribe" not in b and "x()" not in b)
newsbody.get("https://news.google.com/rss/articles/ABC")
check("the same story again: from the store, the page is not fetched twice", len(GETS) == 1)
SENT = []
newsalert.SEND = SENT.append
txt = newsalert.story("BEL", "BEL bags Rs 2,210 crore defence order", "https://news.google.com/rss/articles/ABC", "Google News", "ORDER", None, sync=True)
check("Claude got the full story, not only the headline", any("THE FULL STORY" in p and "order book" in p for p in PROMPTS))
check("Haiku 5.5 first, no temperature, no thinking (%s)" % (CALLS[:1],), CALLS and CALLS[0][0] == "claude-haiku-5-5" and CALLS[0][1] is None and CALLS[0][2]["thinking"]["type"] == "disabled")
check("the alert says it plainly: 🤖 CLAUDE read the full story: BULLISH ▲ (CE side)", txt and "🤖 CLAUDE read the full story: BULLISH ▲ (CE side)" in txt and "why: a big order lifts" in txt)
u = list(json.load(open(os.path.join(W, "data", "llm_usage.json"))).values())[0]
check("the cost of a full story on Haiku 5.5: 2,500 in + 120 out = $0.00031 (%s)" % u.get("usd"), abs(u.get("usd", 0) - 0.00031) < 1e-6)
# Haiku 5.5 not available -> Haiku 4.5, nothing lost
FAIL55["on"] = True; CALLS.clear()
t, m = llmread.ask("another question", max_tokens=300)
check("Haiku 5.5 refused -> Haiku 4.5 answers (%s)" % m, m == "claude-haiku-4-5" and CALLS[-1][1] == 0)
# the page could not be read -> the headline, said so
nf._get = lambda u: types.SimpleNamespace(ok=False, text="")
FAIL55["on"] = False
txt = newsalert.story("HAL", "HAL wins Rs 5,000 crore engine contract", "https://news.google.com/rss/articles/XYZ", "Google News", "ORDER", None, sync=True)
check("a page that cannot be read: 'the headline only' is said", txt and "the headline only" in txt)
d = open(os.path.join(W, "desk.py"), encoding="utf-8").read()
check("the page's news line: BULLISH / BEARISH and who read it", "BULLISH ▲" in d and "🤖 Claude, full story" in d and "LLM_DAY_CAP = 400" in d)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 194"
python3 $W/p194_patch.py $D || back
cd $D && python3 -m py_compile llmread.py newsalert.py desk.py newsbody.py || back
echo "=== the test (a copy, a stand-in for Claude and the web - no real call, no cost)"
timeout 90 python3 $D/p194test.py > /tmp/p194test.out 2>&1; R=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p194test.out | head; [ $R = 0 ] || back
echo "=== the live check: the whole story of 5 recent GIR news items (pages only - Claude is not called, no cost)"
cd $D && timeout 120 python3 - <<'PY_LIVE'
import sqlite3, newsbody
try:
    c = sqlite3.connect("file:news.db?mode=ro", uri=True)
    rows = c.execute("select sym, h, l from items where l like 'http%' order by t_pub desc limit 5").fetchall()
except Exception as ex:
    rows = []; print("  news.db not read: %s" % ex)
ok = 0
for sym, h, l in rows:
    b = newsbody.get(l)
    ok += bool(b)
    print("  %-11s %5d characters · %s" % (sym, len(b), (h or "")[:70]))
print("  %d of %d stories read in full (the rest: Claude reads the headline and says so)" % (ok, len(rows)))
PY_LIVE
echo "=== restarting the programs that read the news"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
sleep 20
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
[ $OK = 1 ] || { echo "the page server did not come back - old files back"; back; }
echo
echo "✅ patch 194 done. Every news item: Claude reads the whole story and says BULLISH ▲ / BEARISH ▼ / NEUTRAL + why."
echo "   It reads on Haiku 5.5 (about \$0.25 a day for full stories). Spend:  python3 -c \"import json;d=json.load(open('$D/data/llm_usage.json'));[print(k,v.get('usd'),v['calls'],v['models']) for k,v in sorted(d.items())[-2:]]\""
