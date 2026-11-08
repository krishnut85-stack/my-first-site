#!/bin/bash
# PATCH 124c - NO OLD NEWS (on top of patch 124b).
#   Rama got "DLF Shares Slump on Fresh CCI Probe" on Sunday 8 Nov 2026 - a story of 7 Dec 2023 (DLF ₹215; today ₹752).
#   Google News re-lists old articles with a new date. Now every news story passes newsfresh.check before the reader:
#     the feed's date (6 h) · the headline's period (Q2 FY24 = past) · a "shares slump / jump" story only while the share
#     is moving that way NOW · Google items: the real article opened and its own published date read (3+ days = held).
#   Held stories are never sent; they are listed by:  python3 /home/globalbot/intraday/newsfresh.py --held
#   newsalert.py, macro.py (exact anchors) · newsfresh.py (new). Restarts gir-newsroom, gir-exchange, gir-desk, gir-intraday.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g124c; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p124c.sh now"; exit 1; fi
grep -q "TG_CHAT_GIROI" $D/tglanes.py 2>/dev/null || { echo "patch 124b is not installed yet - paste patch 124b first"; exit 1; }
grep -q "newsfresh" $D/newsalert.py && { echo "patch 124c is already installed"; exit 1; }
F="newsalert.py macro.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/newsfresh.py $D/p124ctest.py; systemctl restart gir-newsroom gir-exchange gir-desk gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p124c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p124c_patch.py - PATCH 124c: no old news. newsalert.story (every wire / Google / market story) and macro's fallback
sender ask newsfresh.check first: an old story (a re-dated Google item, a past quarter, a 'shares slump' that is not
happening now, an article published days ago) is held, never sent.
Usage: python3 p124c_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "newsalert.py": [
        ('''        if recently_sent(sym, h):
            return None
''', '''        if recently_sent(sym, h):
            return None
        try:                                                    # patch 124c: no old news (DLF's 2023 CCI story, re-dated by Google)
            import newsfresh
            if not newsfresh.check(sym, h, link, t)[0]:
                return None
        except Exception as ex:
            print("newsfresh: %s" % str(ex)[:80])
'''),
    ],
    "macro.py": [
        ('''                    engine2.tg_fo(line(it))
''', '''                    import newsfresh                     # patch 124c: no old news
                    if not newsfresh.check("MARKET", it["h"], it.get("link") or "", it["t"])[0]:
                        j["sent"][it["k"]] = now; continue
                    engine2.tg_fo(line(it))
'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("newsalert.py + macro.py: every story passes newsfresh.check (no old news)")
PY_PATCH
cat > $W/newsfresh.py <<'PY_FRESH'
#!/usr/bin/env python3
"""newsfresh.py - patch 124c: NO OLD NEWS. Rama got "DLF Shares Slump on Fresh CCI Probe" on a Sunday - a story of
7 Dec 2023 (DLF ₹215, today ₹752). Google News re-lists old articles with a NEW date, so the feed's date cannot be
trusted alone. Every news item now passes four checks before the reader sees it (newsalert.story):

  1 the feed's date        older than 6 hours -> held
  2 the headline's period  "Q2 FY24", "FY24" - a quarter / year already past -> held
  3 the price             a "shares slump / jump" headline is only news while the share is moving that way NOW:
                          market closed, or the share flat / the other way (under 0.5%) -> held
                          (the live price alerts - RUNNING, SPEED, CIRCUIT - cover real moves anyway)
  4 the article itself    Google News items (and any without a date): the page is opened and its own published date
                          read (the Google link resolved to the real article first); published 3+ days ago -> held
A held item is never sent; it is written to data/news_held.json (the last 200) with the reason, for checking."""
import os, re, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
HELD = os.path.join(BASE, "data", "news_held.json")
FEED_MAX_S, PAGE_MAX_S, MOVE_MIN = 6 * 3600, 3 * 86400, 0.5
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
DOWN = (r"(slump|slumps|slumped|tank|tanks|tanked|crash|crashes|crashed|plunge|plunges|plunged|fall|falls|fell|falling|drop|drops|dropped|"
                  r"decline|declines|declined|slide|slides|slid|sink|sinks|sank|tumble|tumbles|tumbled|dip|dips|dipped|skid|skids|nosedive|nosedives|"
                  r"turns? weak|trades? lower|in the red|hits? (?:52[- ]week|lower circuit|record) low|down \d+(?:\.\d+)?\s?%)\b")
UP = (r"(jump|jumps|jumped|surge|surges|surged|soar|soars|soared|rally|rallies|rallied|rise|rises|rose|rising|gain|gains|gained|"
                r"climb|climbs|climbed|zoom|zooms|zoomed|spurt|spurts|spurted|skyrocket|skyrockets|trades? higher|in the green|"
                r"hits? (?:52[- ]week|upper circuit|record|all[- ]time) high|up \d+(?:\.\d+)?\s?%)\b")
# the verb must be about the share's price: "DLF shares slump", "stock jumps 5%" - not "shares in focus as profit rises"
_NEAR = r"\b(?:shares?|stocks?|scrip|share price|stock price)\b\W+(?:[\w&.-]+\W+){0,2}?"
DOWN = re.compile(_NEAR + DOWN, re.I)
UP = re.compile(_NEAR + UP, re.I)


def now_fy(now=None):
    """the Indian fiscal year now, two digits (Nov 2026 -> 27)"""
    d = dt.datetime.fromtimestamp(now or time.time(), IST)
    return (d.year + (1 if d.month >= 4 else 0)) % 100, d.month


def old_period(h, now=None):
    """'Q2 FY24' / 'FY24' / 'Q2FY2024' in the headline, already past -> the reason, else None"""
    fy, mon = now_fy(now)
    for m in re.finditer(r"\b(Q[1-4]|H[12])?\s?FY\s?'?(20)?(\d{2})\b", h, re.I):
        y = int(m.group(3))
        if y < fy - 1 or (y == fy - 1 and m.group(1) and mon >= 7):
            return "the headline is about %s - that period is past" % m.group(0).strip()
    return None


def move_said(h):
    """+1 / -1 when the headline is about the share's price moving, else 0"""
    dn, up = bool(DOWN.search(h)), bool(UP.search(h))
    return -1 if dn and not up else 1 if up and not dn else 0


def live_move(sym, max_age=120):
    """(price, % today) from the engine's live quotes, or None when the market is not live"""
    try:
        q = json.load(open(os.path.join(BASE, "quotes_live.json")))
        if time.time() - float(q.get("t") or 0) > max_age:
            return None
        v = (q.get("q") or {}).get("NIFTY50" if sym == "MARKET" else sym)
        return (float(v[0]), float(v[1] or 0)) if v and v[0] else None
    except Exception:
        return None


def _iso(s):
    s = (s or "").strip()
    try:
        d = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
        return (d if d.tzinfo else d.replace(tzinfo=IST)).timestamp()
    except Exception:
        pass
    for f in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%b %d, %Y %H:%M", "%d %b %Y"):
        try:
            d = dt.datetime.strptime(s[:25], f)
            return (d if d.tzinfo else d.replace(tzinfo=IST)).timestamp()
        except Exception:
            continue
    return None


def page_date(html, url=""):
    """the article's own published date (epoch) from its page or its address, else None"""
    pats = (r'"datePublished"\s*:\s*"([^"]+)"', r'property=["\']article:published_time["\']\s+content=["\']([^"\']+)',
            r'content=["\']([^"\']+)["\']\s+property=["\']article:published_time', r'itemprop=["\']datePublished["\']\s+content=["\']([^"\']+)',
            r'name=["\'](?:publish-date|pubdate|publishdate|article\.published|DC\.date\.issued)["\']\s+content=["\']([^"\']+)', r'<time[^>]+datetime=["\']([^"\']+)')
    for p in pats:
        m = re.search(p, html or "", re.I)
        if m:
            t = _iso(m.group(1))
            if t:
                return t
    m = re.search(r"/(20\d\d)[/-](\d{1,2})[/-](\d{1,2})(?:/|-|$)", url or "")
    if m:
        try:
            return dt.datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)), tzinfo=IST).timestamp()
        except Exception:
            pass
    return None


def google_real(link, get, post):
    """a news.google.com article link -> the publisher's own address (Google's own page hands it out), else None"""
    m = re.search(r"news\.google\.com/(?:rss/)?articles/([^?/#]+)", link or "")
    if not m:
        return None
    gid = m.group(1)
    r = get("https://news.google.com/rss/articles/%s" % gid)
    html = getattr(r, "text", "") or ""
    sg = re.search(r'data-n-a-sg="([^"]+)"', html)
    ts = re.search(r'data-n-a-ts="([^"]+)"', html)
    if not sg or not ts:
        return None
    inner = json.dumps(["garturlreq", [["X", "X", ["X", "X"], None, None, 1, 1, "US:en", None, 1, None, None, None, None, None, 0, 1], "X", "X", 1, [1, 1, 1], 1, 1, None, 0, 0, None, 0],
                        gid, int(ts.group(1)), sg.group(1)])
    r2 = post("https://news.google.com/_/DotsSplashUi/data/batchexecute", {"f.req": json.dumps([[["Fbv4je", inner, None, "generic"]]])})
    body = getattr(r2, "text", "") or ""
    try:
        part = json.loads(body.split("\n\n")[1])[:-2]
        return json.loads(part[0][2])[1]
    except Exception:
        m2 = re.search(r'https?://(?!news\.google)[^"\\\s]+', body)
        return m2.group(0) if m2 else None


def _get(url):
    import requests
    return requests.get(url, headers=UA, timeout=(4, 6), allow_redirects=True)


def _post(url, data):
    import requests
    return requests.post(url, data=data, headers=dict(UA, **{"Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"}), timeout=(4, 6))


def article_age(link, now=None, get=None, post=None):
    """(seconds since the article was published, the address read) - None when it cannot be told"""
    now = now or time.time()
    get, post = get or _get, post or _post
    url = link or ""
    try:
        if "news.google.com" in url:
            url = google_real(url, get, post) or ""
        if not url.startswith("http"):
            return None, url
        t = page_date("", url)
        if t is None:
            r = get(url)
            t = page_date((getattr(r, "text", "") or "")[:400000], getattr(r, "url", "") or url)
        return (now - t if t else None), url
    except Exception:
        return None, url


def _held(sym, h, link, why):
    try:
        os.makedirs(os.path.dirname(HELD), exist_ok=True)
        try:
            L = json.load(open(HELD))
        except Exception:
            L = []
        L.insert(0, {"at": dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"), "s": sym, "h": h[:200], "link": (link or "")[:300], "why": why})
        json.dump(L[:200], open(HELD + ".tmp", "w"), ensure_ascii=False)
        os.replace(HELD + ".tmp", HELD)
    except Exception:
        pass


def check(sym, h, link="", t=None, now=None, get=None, post=None, live=None, page=True):
    """-> (send it?, why held). live: (price, % today) or None (market not live); default = the engine's live quotes."""
    now = now or time.time()
    why = None
    if t and now - t > FEED_MAX_S:
        why = "the feed dates it %d h ago" % ((now - t) / 3600)
    why = why or old_period(h, now)
    if not why:
        sd = move_said(h)
        if sd:
            lv = live_move(sym) if live is None else (live or None)
            if not lv:
                why = "a 'shares %s' story while the market is not live - an old or a past session's move" % ("down" if sd < 0 else "up")
            elif lv[1] * sd < MOVE_MIN:
                why = "the headline says %s, %s is %+.1f%% now - an old story" % ("DOWN" if sd < 0 else "UP", sym, lv[1])
    if not why and page and link and ("news.google." in link or not t):     # Google re-dates old articles; the wires' own dates hold
        age, url = article_age(link, now, get, post)
        if age is not None and age > PAGE_MAX_S:
            d = dt.datetime.fromtimestamp(now - age, IST).strftime("%d %b %Y")
            why = "the article itself was published %s (%d days ago)%s" % (d, age / 86400, (" · " + url[:80]) if url and url != link else "")
    if why:
        _held(sym, h, link, why)
        print("news held (%s): %s · %s" % (sym, h[:80], why))
        return False, why
    return True, None


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--held":
        try:
            for x in json.load(open(HELD))[:int(sys.argv[2]) if len(sys.argv) > 2 else 20]:
                print("%s %-10s %s\n      held: %s" % (x["at"], x["s"], x["h"][:100], x["why"]))
        except Exception:
            print("nothing held yet")
    elif len(sys.argv) > 3:
        print(check(sys.argv[1].upper(), sys.argv[2], sys.argv[3]))
    else:
        print("python3 newsfresh.py --held [N]          the last N news items held as old\n"
              "python3 newsfresh.py SYM \"headline\" LINK  check one item now")
PY_FRESH
cat > $D/p124ctest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p124ctest.py - NO OLD NEWS: DLF's 7 Dec 2023 CCI story (re-dated by Google) is held, fresh news still goes.
Fake web pages and fake Telegram only - nothing is fetched or sent."""
import os, sys, json, time, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import newsfresh, newsalert
tmp = tempfile.mkdtemp(prefix="p124c")
try:
    newsfresh.HELD = os.path.join(tmp, "news_held.json")
    now = time.time()
    H = "DLF Shares Slump on Fresh CCI Probe"
    GL = "https://news.google.com/rss/articles/CBMiTESTDLF?oc=5"
    REAL = "https://www.ndtvprofit.com/markets/dlf-shares-slump-on-fresh-cci-probe"

    class R(object):
        def __init__(self, text, url=""):
            self.text, self.url = text, url
    PAGES = {"https://news.google.com/rss/articles/CBMiTESTDLF": R('<c-wiz><div jscontroller="x" data-n-a-sg="SIG123" data-n-a-ts="1730000000"></div></c-wiz>'),
             REAL: R('<script type="application/ld+json">{"@type":"NewsArticle","datePublished":"2023-12-07T22:25:00+05:30"}</script>', REAL),
             "https://www.ndtvprofit.com/markets/dlf-q2-new": R('<meta property="article:published_time" content="%s">' % dt.datetime.fromtimestamp(now - 3600, newsfresh.IST).isoformat())}
    POSTS = []
    get = lambda u: PAGES.get(u, R(""))

    def post(u, data):
        POSTS.append(json.loads(data["f.req"]))
        inner = json.dumps([[None, None, json.dumps(["garturlres", REAL, 1])]] + [None, None])
        return R(')]}\'\n\n' + json.dumps([["wrb.fr", "Fbv4je", json.dumps(["garturlres", REAL, 1]), None, None, None, "generic"], ["di", 10], ["af.httprm", 9, "x", 1]]))
    print("1. the DLF story")
    r = newsfresh.check("DLF", H, GL, now - 600, now, get, post, live=False)
    check("Sunday (market not live), the feed says 10 min old: held - %s" % r[1], r[0] is False)
    r = newsfresh.check("DLF", H, GL, now - 600, now, get, post, live=(752.9, 0.1))
    check("market live, DLF +0.1%%: held - %s" % r[1], r[0] is False and "+0.1%" in r[1])
    r = newsfresh.check("DLF", H, GL, now - 600, now, get, post, live=(735.0, -2.4))
    check("even if DLF were down 2.4%%, the article itself is from 2023 (the Google link resolved): %s" % r[1], r[0] is False and "07 Dec 2023" in r[1] and POSTS and POSTS[-1][0][0][0] == "Fbv4je")
    held = json.load(open(newsfresh.HELD))
    check("every held story is written down with the reason (%d)" % len(held), len(held) == 3 and held[0]["s"] == "DLF")
    print("2. fresh news still goes")
    r = newsfresh.check("DLF", "DLF shares slump 4% as CCI orders probe", "https://www.ndtvprofit.com/markets/dlf-q2-new", None, now, get, post, live=(722.0, -4.1))
    check("a fresh article (published 1 h ago), DLF -4.1%% now: sent (%s)" % (r,), r == (True, None))
    r = newsfresh.check("TITAN", "Titan Q2 FY27 profit up 32%, beats estimates", "https://economictimes.indiatimes.com/x/articleshow/1.cms", now - 300, now, get, post, live=False)
    check("a results story from a wire (its own date, 5 min old), market closed: sent - not a price-move story", r == (True, None))
    r = newsfresh.check("TITAN", "Titan Q2 FY24 profit up 32%", "", now - 300, now, get, post, live=False)
    check("'Q2 FY24' in November 2026: held - %s" % r[1], r[0] is False and "FY24" in r[1])
    r = newsfresh.check("TITAN", "Titan bags order", "", now - 8 * 3600, now, get, post, live=False)
    check("a feed date 8 h old: held", r[0] is False and "8 h" in r[1])
    print("3. through the reader (newsalert.story)")
    SENT = []
    newsalert.SEND = SENT.append
    newsalert.model_read = lambda *a, **k: {"relevant": True, "side": -1, "level": "important", "known": False, "conf": 0.8, "reason": "probe", "watch": "", "model": "test"}
    newsfresh.live_move = lambda sym, max_age=120: None
    newsfresh._get, newsfresh._post = get, post
    newsalert._S["sent"] = []
    a = newsalert.story("DLF", H, GL, "ndtvprofit.com", "REG", now - 600, sync=True)
    b = newsalert.story("TITAN", "Titan Q2 FY27 profit up 32%, beats estimates", "https://economictimes.indiatimes.com/x/articleshow/1.cms", "Economic Times", "RESULTS", now - 300, sync=True)
    check("the old DLF story never reaches Telegram; the fresh Titan one does", a is None and b and len(SENT) == 1 and "TITAN" in SENT[0])
finally:
    shutil.rmtree(tmp, ignore_errors=True)
src = open(os.path.join(B, "newsalert.py"), encoding="utf-8").read() + open(os.path.join(B, "macro.py"), encoding="utf-8").read()
check("newsalert.story and macro's market line both ask newsfresh.check first", src.count("newsfresh.check(") == 2)
print("\nP124C NO OLD NEWS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p124c_patch.py $D || { rm -f $D/p124ctest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/newsfresh.py $D/
cd $D && python3 -m py_compile newsalert.py macro.py newsfresh.py p124ctest.py || back
timeout 120 python3 p124ctest.py 2>&1 | grep "OK  \|FAIL\|NEWS TEST"
timeout 120 python3 p124ctest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p118test.py p119test.py p123test.py p124test.py readertest.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-newsroom gir-exchange gir-desk gir-intraday && sleep 15
for u in gir-newsroom gir-exchange gir-desk gir-intraday; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 124c APPLIED - old news is held, never sent."
echo "The DLF story checked now on this server:"
python3 $D/newsfresh.py DLF "DLF Shares Slump on Fresh CCI Probe" "https://www.ndtvprofit.com/markets/dlf-shares-slump-on-fresh-cci-probe"
echo "See what was held any time:  python3 $D/newsfresh.py --held"
