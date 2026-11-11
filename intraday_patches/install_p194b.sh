#!/bin/bash
# PATCH 194b - the story reader, stronger (the live check of 194 read 2 of 5 stories in full): the article text news sites keep
#   in the page's data block (articleBody - ET, Moneycontrol, Mint, BS ...), a full browser's request, the page's own summary when
#   nothing else, and WHY a story was not read. Then a live check of 10 recent stories (pages only - no Claude call, no cost).
#   Restarts the news programs (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
[ -f $D/newsbody.py ] || { echo "patch 194 is not in yet - run install_p194.sh first"; exit 1; }
cp $D/newsbody.py $D/newsbody.py.bak$TS; [ -f $D/p194test.py ] && cp $D/p194test.py $D/p194test.py.bak$TS
back(){ cp $D/newsbody.py.bak$TS $D/newsbody.py; [ -f $D/p194test.py.bak$TS ] && cp $D/p194test.py.bak$TS $D/p194test.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $D/newsbody.py <<'PY_NB'
#!/usr/bin/env python3
"""newsbody.py - patch 194 (194b: stronger): the WHOLE story behind a headline, for Claude to read before it says BULLISH or BEARISH
(Rama, 11 Nov: "I want the news to be confirmed by Claude whether bullish or bearish" - GIR's reader saw only the headline).
  get(link) -> the article's own words (up to 4,000 characters), '' when the page cannot be read. Never raises.
  194b - the first live check read 2 of 5 stories. Now, in order:
    1 the article text news sites hide in the page's data block (JSON-LD "articleBody" - Economic Times, Moneycontrol, Mint,
      Business Standard, NDTV Profit ... carry the whole story there)
    2 the page's paragraphs
    3 the page's own summary (og:description) - at least two or three lines more than the headline
  a full browser's request headers (some sites refuse a bare request) · a Google News link is turned into the publisher's address
  LAST["why"] says what happened to the last link: "read (articleBody)" · "Google link not resolved" · "the site refused (403)" ...
  Kept 2 days in data/newsbody.db (an empty result is tried again after 30 minutes).
  python3 newsbody.py <link>     prints what Claude would read and why"""
import os, re, html, json, time, sqlite3

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "data", "newsbody.db")
MAX = 4000
SKIP = re.compile(r"subscribe|sign in|log ?in to|cookie|advertisement|download the app|follow us|all rights reserved|also read|read more:", re.I)
HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
       "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", "Accept-Language": "en-IN,en;q=0.9",
       "Cache-Control": "no-cache"}
LAST = {"why": "", "url": ""}
FETCH = None                                                    # a stand-in for the web (the self-test)


def _db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    c = sqlite3.connect(DB, timeout=3)
    c.execute("create table if not exists b(link text primary key, t real, url text, body text)")
    return c


def _clean(x):
    x = html.unescape(re.sub(r"<[^>]+>", " ", x or ""))
    return re.sub(r"\s+", " ", x).strip()


def article_body(page):
    """the 'articleBody' of the page's JSON-LD block(s), the longest one"""
    best = ""
    for m in re.finditer(r'"articleBody"\s*:\s*"((?:\\.|[^"\\])*)"', page or ""):
        try:
            t = _clean(json.loads('"%s"' % m.group(1)))
        except Exception:
            t = _clean(m.group(1))
        if len(t) > len(best):
            best = t
    return best


def summary(page):
    for pat in (r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']+)', r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:description',
                r'<meta[^>]+name=["\']description["\'][^>]+content=["\']([^"\']+)'):
        m = re.search(pat, page or "", re.I)
        if m and len(_clean(m.group(1))) >= 60:
            return _clean(m.group(1))
    return ""


def extract(page, how=None):
    """the article's words from a page's HTML; how (a list) gets the way it was found"""
    how = how if how is not None else []
    ab = article_body(page)
    if len(ab) >= 200:
        how.append("articleBody"); return ab[:MAX]
    t = re.sub(r"(?is)<(script|style|noscript|nav|footer|header|aside|form)[^>]*>.*?</\1>", " ", page or "")
    paras = []
    for p in re.findall(r"(?is)<p[^>]*>(.*?)</p>", t):
        x = _clean(p)
        if len(x) >= 50 and not SKIP.search(x[:80]):
            paras.append(x)
    body = " ".join(paras)
    if len(body) >= 200:
        how.append("paragraphs"); return body[:MAX]
    sm = summary(page)
    if sm:
        how.append("the page's summary"); return (sm + ((" " + body) if body else ""))[:MAX]
    return ""


def get(link, get_=None, post_=None):
    LAST.update(why="", url="")
    if not link or not str(link).startswith("http"):
        LAST["why"] = "no link"; return ""
    c = None
    try:
        c = _db()
        r = c.execute("select body, t from b where link=? and t>?", (link, time.time() - 2 * 86400)).fetchone()
        if r is not None and (r[0] or time.time() - r[1] < 1800):     # an empty result: tried again after 30 minutes
            LAST["why"] = "from the store"
            c.close()
            return r[0] or ""
    except Exception:
        c = None
    body, url = "", link
    try:
        import newsfresh, requests
        g = get_ or FETCH or (lambda u: requests.get(u, headers=HDR, timeout=(4, 8), allow_redirects=True))
        p = post_ or newsfresh._post
        if "news.google.com" in link:
            url = newsfresh.google_real(link, get_ or FETCH or newsfresh._get, p) or ""
            if not url:
                LAST["why"] = "Google link not resolved"
        if url.startswith("http"):
            LAST["url"] = url
            resp = g(url)
            code = getattr(resp, "status_code", 200)
            if getattr(resp, "ok", True):
                how = []
                body = extract(getattr(resp, "text", "") or "", how)
                LAST["why"] = ("read (%s)" % how[0]) if body else "no text on the page (made by script / paywall)"
            else:
                LAST["why"] = "the site refused (%s)" % code
    except Exception as ex:
        body = ""; LAST["why"] = "error: %s" % str(ex)[:60]
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
    print("%d characters · %s · %s\n%s" % (len(b), LAST["why"], LAST["url"], b[:1500]))
PY_NB
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
newsbody.FETCH = lambda u: nf._get(u)                           # 194b: the web stand-in
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
cat > $D/p194btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p194btest.py - PATCH 194b: the stronger story reader (the page's data block, the summary, why a page was not read) - no web"""
import os, sys, types, shutil, tempfile, time, sqlite3
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp(); shutil.copy(os.path.join(B, "newsbody.py"), W); os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W)
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
nf = types.ModuleType("newsfresh"); nf._get = lambda u: None; nf._post = lambda u, d: None
RES = {"g": "https://economictimes.example/x"}
nf.google_real = lambda link, g, p: RES["g"]
sys.modules["newsfresh"] = nf
import newsbody as N
LD = '<html><script type="application/ld+json">{"@type":"NewsArticle","headline":"x","articleBody":"Oil India said on Tuesday its board approved a Rs 7,000 crore capex plan for the North East. The company expects output to rise 12% by FY28, its chairman told reporters. \\"We are on track\\", he said, adding that new wells come online in the March quarter."}</script><body><div id=app></div></body></html>'
how = []; b = N.extract(LD, how)
check("a page made by script: the story from its data block (articleBody)", "Rs 7,000 crore capex" in b and how == ["articleBody"] and '"We are on track"' in b)
OG = '<html><head><meta property="og:description" content="Bharti Airtel will hold analyst meetings in Mumbai and Singapore on 18-19 November, the company said in a filing on Tuesday."></head><body><p>short</p></body></html>'
how = []; b = N.extract(OG, how)
check("no paragraphs, no data block: the page's own summary", "analyst meetings in Mumbai" in b and how == ["the page's summary"])
PG = {"code": 403, "text": ""}
N.FETCH = lambda u: types.SimpleNamespace(ok=PG["code"] == 200, status_code=PG["code"], text=PG["text"])
b = N.get("https://news.google.com/rss/articles/A1")
check("a site that refuses: said why ('%s')" % N.LAST["why"], b == "" and "refused (403)" in N.LAST["why"])
PG.update(code=200, text=LD)
b = N.get("https://news.google.com/rss/articles/A1")
check("an empty result is not tried again within 30 minutes", b == "" and N.LAST["why"] == "from the store")
c = sqlite3.connect(N.DB); c.execute("update b set t=?", (time.time() - 1900,)); c.commit(); c.close()
b = N.get("https://news.google.com/rss/articles/A1")
check("... after 30 minutes it is tried again and read ('%s')" % N.LAST["why"], "capex" in b and N.LAST["why"] == "read (articleBody)")
RES["g"] = None
b = N.get("https://news.google.com/rss/articles/B2")
check("a Google link that cannot be resolved: said why", b == "" and N.LAST["why"] == "Google link not resolved")
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 194b"
cd $D && python3 -m py_compile newsbody.py || back
echo "=== the tests (stand-ins for Claude and the web - no real call, no cost)"
timeout 90 python3 $D/p194btest.py > /tmp/p194btest.out 2>&1; R1=$?
timeout 90 python3 $D/p194test.py > /tmp/p194test.out 2>&1; R2=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p194btest.out /tmp/p194test.out | sed 's|/tmp/||' | head; [ $R1 = 0 ] && [ $R2 = 0 ] || back
echo "=== the live check: 10 recent GIR stories (pages only - Claude is not called, no cost)"
cd $D && timeout 240 python3 - <<'PY_LIVE'
import sqlite3, re, newsbody
try:
    c = sqlite3.connect(newsbody.DB); c.execute("delete from b where body=''"); c.commit(); c.close()   # the misses of 194: read again
except Exception:
    pass
try:
    c = sqlite3.connect("file:news.db?mode=ro", uri=True)
    rows = c.execute("select sym, h, l from items where l like 'http%' order by t_pub desc limit 10").fetchall()
except Exception as ex:
    rows = []; print("  news.db not read: %s" % ex)
ok = 0
for sym, h, l in rows:
    b = newsbody.get(l)
    ok += bool(b)
    dom = re.sub(r"^https?://(www\.)?", "", newsbody.LAST.get("url") or "").split("/")[0] or "-"
    print("  %-11s %5d ch · %-28s · %-22s · %s" % (sym, len(b), newsbody.LAST["why"][:28], dom[:22], (h or "")[:40]))
print("  %d of %d stories read (the rest: Claude reads the headline and says so)" % (ok, len(rows)))
PY_LIVE
echo "=== restarting the news programs"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
sleep 15
for s in gir-intraday gir-exchange gir-tvwatch; do echo "  $s: $(systemctl is-active $s)"; done
echo
echo "✅ patch 194b done - send Claude a screenshot of the live check above"
