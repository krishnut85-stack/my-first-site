#!/bin/bash
# PATCH 272 - INDIAN NEWS SITES FIRST (Rama, 14 Nov: "you always look at foreign websites - there are many best Indian news sites; live during trading").
#   GIR already reads Economic Times, Moneycontrol, Mint and Business Standard every minute; the per-share news came through Google, which mixes in
#   LinkedIn posts, blogs and unknown sites ("Urban Acres", "Unique Times Magazine"). Now:
#   + more Indian business sites read every minute - each tried from this server first, only the ones answering with fresh news are added
#     (CNBC-TV18, Financial Express, Hindu BusinessLine, NDTV Profit, Zee Business, Business Today, more Moneycontrol / Mint / BS / ET feeds)
#   + a known Indian news site leads every story; social media and blogs never shown; a story only on an unknown site is marked "(small site - check)"
#   + Telegram policy news from news sites: only from known Indian outlets (the regulators' own pages always)
#   Tested: 8 cases. Restarts the news services and the page server - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 270" $D/govwatch.py && [ -f $D/newsclean.py ] || { echo "patch 270 first"; exit 1; }
F="newsclean.py morningbrief.py govwatch.py newsroom.py macro.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-newsroom gir-newshunt gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/data/feeds_extra.json; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/newsclean.py <<'PY_NC'
#!/usr/bin/env python3
"""newsclean.py - patch 270: ONE news cleaner for every list GIR shows (Rama, 14 Nov: "some news are still old news ... you don't know where all
it's reflecting"). Patch 260 fixed the Telegram GOVT WATCH only; the morning brief (TOMORROW tab, 08:30) showed:
  the same story many times     PAYTM's RBI wallet nod x6 from six websites · six IRDAI-commission articles, all one story
  unreadable text               BEL: "619 Crore ' I ' KGI TSTT tU ' PlPl ..." (a scanned PDF read as letters)
  a letterhead, not news        FEDERALBNK: "Secretarial Department Federal Bank | 6th Floor, Federal Towers ..."
  a round-up as company news    PFC "DEAL": "Rs 231.80 Dividend, 1:10 Split, 1 Buyback: 31 stocks to trade ex-date next week"
junk() · letterhead() · roundup() · story_key() - used by morningbrief.py and govwatch.py."""
import re

SMALL = set("a an the of to in on at by for and or is be as it its we our us from with vs re no not per cr rs ltd inr".split())
OUTLETS = re.compile(r"\s+[-|–]\s+(?:[A-Z][\w.&' ]{1,40}|[a-z0-9.]+\.(?:com|in|net))\s*$")
REGS = ("IRDAI", "SEBI", "RBI", "CCI", "TRAI", "USFDA", "DGCA", "NHAI", "PIB", "CABINET", "MINISTRY")


def junk(s):
    """a scanned PDF read as letters: many 1-2 letter pieces and stray symbols"""
    t = (s or "").split()
    if len(t) < 5:
        return False
    bad = sum(1 for w in t if (len(w) <= 2 and not w.isdigit() and w.lower() not in SMALL and not re.match(r"^[₹&%]$|^\d", w)) or re.search(r"[\^*`~]|'.*'", w))
    return bad / len(t) > 0.3


LETTER = re.compile(r"\b(?:\d+(?:st|nd|rd|th) floor|floor|towers?|bhavan|bhawan|marg|nagar|road|junction|p\.?\s?o\.?\s?box|pin(?:code)?|cin\b|"
                    r"tel(?:ephone)?\b|fax\b|e-?mail|website|www\.|regd\.? office|registered office|corporate office|secretarial department)", re.I)


def letterhead(s):
    """a company's letterhead / address read as the news"""
    s = s or ""
    hits = len(LETTER.findall(s))
    return hits >= 2 or (hits >= 1 and s.count("|") >= 2) or bool(re.search(r"\|\s*[A-Z][a-z]+\s*\|\s*\d{3}", s))


ROUND = re.compile(r"\b\d{1,3}\s+(?:stocks|shares|companies)\b|stocks? to (?:watch|buy|trade|track)|top \d+ |\bex-?date next week|"
                   r"stocks in focus|stocks in news|buzzing stocks|market wrap|\bq\d results (?:today|live)|shares? to watch|key stocks", re.I)


def roundup(s):
    """a many-stock round-up (one company named among many) - not that company's news"""
    return bool(ROUND.search(s or ""))


def words(s):
    s = OUTLETS.sub("", s or "")
    return {w for w in re.findall(r"[a-z][a-z0-9]{3,}", s.lower()) if w not in SMALL}


def story_key(sym, kind, s):
    """one story = the same share + kind; for the market lines the same regulator (IRDAI's six commission articles are one story)"""
    if sym and sym != "MARKET":
        return (sym, kind)
    up = (s or "").upper()
    reg = next((r for r in REGS if re.search(r"\b%s\b" % r, up)), None)
    return ("MARKET", reg) if reg else ("MARKET", tuple(sorted(words(s)))[:6])


# ---------------- patch 272: which sites to believe (Rama, 14 Nov: "you look at foreign websites - there are many best Indian news sites") ----------
TRUST_DOM = ("economictimes.indiatimes.com", "moneycontrol.com", "livemint.com", "business-standard.com", "thehindubusinessline.com", "financialexpress.com",
             "cnbctv18.com", "ndtvprofit.com", "businesstoday.in", "zeebiz.com", "etnownews.com", "reuters.com", "bloomberg.com", "thehindu.com",
             "timesofindia.indiatimes.com", "indianexpress.com", "hindustantimes.com", "news18.com", "indiatoday.in", "theprint.in", "firstpost.com",
             "outlookbusiness.com", "fortuneindia.com", "freepressjournal.in", "ptinews.com", "deccanherald.com", "ndtv.com", "goodreturns.in",
             "newindianexpress.com", "telegraphindia.com", "tribuneindia.com", "dnaindia.com", "pib.gov.in", "rbi.org.in", "sebi.gov.in",
             "nseindia.com", "bseindia.com", "irdai.gov.in", "informistmedia.com", "cogencis.com", "businessworld.in", "inc42.com", "entrackr.com")
TRUST_NAME = ("economic times", "et markets", "et now", "moneycontrol", "mint", "livemint", "business standard", "businessline", "hindu businessline",
              "financial express", "cnbc-tv18", "cnbc tv18", "cnbctv18", "ndtv profit", "ndtv", "business today", "zee business", "reuters", "bloomberg",
              "the hindu", "times of india", "indian express", "hindustan times", "news18", "india today", "theprint", "firstpost", "outlook business",
              "fortune india", "free press journal", "pti", "press trust of india", "deccan herald", "goodreturns", "new indian express", "telegraph india",
              "tribune india", "dna india", "informist", "cogencis", "businessworld", "inc42", "entrackr", "press information bureau", "the economic times",
              "outlook money", "news9live", "news9", "moneylife", "bqprime", "the financial express", "the times of india", "the indian express", "et prime")
BLOCK_NAMES = ("linkedin", "facebook", "twitter", "youtube", "instagram", "medium", "quora", "reddit", "blogspot", "wordpress", "substack", "tumblr",
               "scribd", "slideshare", "telegram", "whatsapp", "sharechat", "pinterest")
BLOCK = re.compile(r"linkedin|facebook|twitter|\bx\.com|youtube|instagram|medium\.com|quora|reddit|blogspot|wordpress|substack|tumblr|scribd|slideshare|"
                   r"telegram|whatsapp|sharechat|pinterest", re.I)
_SUFFIX = re.compile(r"\s+[-|–]\s+([^-|–]{2,60})\s*$")


def outlet(title):
    """the site's name Google puts after the headline ("... - The Hindu") -> 'the hindu', or ''"""
    parts = re.split(r"\s+[-|–]\s+", (title or "").strip())          # only a SPACED dash separates the site ("CNBC-TV18" keeps its own)
    return parts[-1].strip().lower() if len(parts) > 1 and 2 <= len(parts[-1].strip()) <= 60 else ""


def _pre(o, names):
    """o matches a name - also when the page cut it short ("The Economi" = The Economic Times, "LinkedI" = LinkedIn)"""
    return bool(o) and any(o == n or o.startswith(n + " ") or (len(o) >= 5 and n.startswith(o)) for n in names)


def blocked(dom=None, title=None):
    o = outlet(title) if title else ""
    return bool((dom and BLOCK.search(dom)) or (o and (BLOCK.search(o) or _pre(o, BLOCK_NAMES))))


def trusted(dom=None, title=None):
    """True: a known Indian news site / regulator · False: social media / a blog · None: an unknown site"""
    if blocked(dom, title):
        return False
    d = (dom or "").lower()
    d = d[4:] if d.startswith("www.") else d
    if d and any(d == t or d.endswith("." + t) for t in TRUST_DOM):
        return True
    o = outlet(title)
    if o and (_pre(o, TRUST_NAME) or any(n in o for n in TRUST_NAME if len(n) >= 5)):
        return True
    return None
PY_NC
cat > $W/p272_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p272_patch.py - patch 272: Indian news sites first, social media / blogs never (newsclean.trusted).  python3 p272_patch.py DIR"""
import os, sys
D = sys.argv[1]
MAIN = 'if __name__ == "__main__":'
MB = '''def _clean270(xs):                                                  # patch 272: a known Indian news site leads its story; LinkedIn & co never
    import newsclean as NC
    groups, order = {}, []
    for x in xs:
        w = x.get("what") or ""
        if x["sym"] != "MARKET" and NC.roundup(w):
            continue
        if NC.blocked(title=w):
            continue
        if NC.junk(w) or NC.letterhead(w):
            x = dict(x, what="(the filing's text could not be read - open it on NSE)")
        x = dict(x, _tr=1 if (x.get("src") in ("NSE", "BSE") or NC.trusted(title=w)) else 0)
        k = NC.story_key(x["sym"], x["kind"], w)
        g = groups.get(k)
        if g is None:
            groups[k] = dict(x, n=0); order.append(k); continue
        g["n"] += 1
        g["cr"] = max(g["cr"], x.get("cr") or 0)
        if (x["_tr"], x["t"]) > (g["_tr"], g["t"]):                 # the trusted, then the latest report leads
            n_, cr_ = g["n"], g["cr"]
            groups[k] = dict(x, n=n_, cr=cr_)
    out = []
    for k in order:
        g = groups[k]
        w = NC.OUTLETS.sub("", g.get("what") or "") if g["_tr"] else (g.get("what") or "")
        if g["n"]:
            w = "[+%d more report%s] %s" % (g["n"], "s" if g["n"] > 1 else "", w)
        if not g["_tr"] and g["sym"] != "MARKET" or (g["sym"] == "MARKET" and not g["_tr"] and g.get("src") not in ("PIB", "RBI", "SEBI", "IRDAI")):
            w += "  (small site - check)"
        g["what"] = w
        for z in ("n", "_tr"):
            g.pop(z, None)
        out.append(g)
    return sorted(out, key=lambda x: x["t"])


''' + MAIN
GW_OLD = '''        if "news.google" in link:                                    # a news site's report (not the regulator's own page): one a story in 6 h'''
GW_NEW = '''        if "news.google" in link and not NC.trusted(title=title):      # patch 272: from a news site only a known Indian outlet's report
            continue
''' + GW_OLD
NR = '''_gn272 = google_news                                               # patch 272: no social media / blogs; known Indian news sites first


def google_news(name, sym, days=4):
    import newsclean as NC
    rows = [r for r in _gn272(name, sym, days) if not NC.blocked(dom=r[3], title=r[1])]
    return sorted(rows, key=lambda r: 0 if NC.trusted(dom=r[3], title=r[1]) else 1)


''' + MAIN
MC = '''

try:                                                               # patch 272: more Indian business sites, every minute (data/feeds_extra.json, tested at install)
    import json as _j272
    FEEDS += [tuple(x) for x in _j272.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "feeds_extra.json")))
              if tuple(x) not in FEEDS and x[1] not in [f[1] for f in FEEDS]]
except Exception:
    pass
'''
for f, add, mode in (("morningbrief.py", MB, "main"), ("govwatch.py", (GW_OLD, GW_NEW), "swap"), ("newsroom.py", NR, "main"), ("macro.py", MC, "end")):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        print("❌ %s missing" % f); sys.exit(1)
    s = open(p, encoding="utf-8").read()
    if "patch 272" in s:
        print("  %s: patch 272 - already in" % f); continue
    if f == "morningbrief.py" and "patch 270" not in s:
        print("❌ morningbrief.py: patch 270 first"); sys.exit(1)
    if mode == "swap":
        if "patch 270" not in s or s.count(add[0]) != 1:
            print("❌ govwatch.py: patch 270's story filter not found (patch 270 first)"); sys.exit(1)
        s = s.replace(add[0], add[1])
    elif mode == "main":
        if s.count(MAIN) != 1:
            print("❌ %s: its main block found %d times" % (f, s.count(MAIN))); sys.exit(1)
        s = s.replace(MAIN, add)
    else:
        if "\nFEEDS = [" not in s:
            print("❌ macro.py: FEEDS not found"); sys.exit(1)
        s = s.rstrip("\n") + MC
    open(p, "w", encoding="utf-8").write(s)
    print("  %s: %s" % (f, {"morningbrief.py": "a known Indian site leads each story · LinkedIn & co never · unknown sites marked 'small site - check'",
                            "govwatch.py": "news-site policy stories only from known Indian outlets",
                            "newsroom.py": "the share's news: no social media / blogs, known Indian sites first",
                            "macro.py": "more Indian business sites read every minute"}[f]))
print("patch 272 in")
PY_PATCH
cat > $W/feedprobe.py <<'PY_FP'
#!/usr/bin/env python3
"""feedprobe.py - patch 272: which Indian business sites answer from this server (each tried once; the ones with fresh items are kept).
python3 feedprobe.py OUTFILE"""
import re, sys, json, time
from email.utils import parsedate_to_datetime
CAND = [("CNBC-TV18 Market", "https://www.cnbctv18.com/commonfeeds/v1/cne/rss/market.xml"), ("CNBC-TV18 Business", "https://www.cnbctv18.com/commonfeeds/v1/cne/rss/business.xml"),
        ("CNBC-TV18 Latest", "https://www.cnbctv18.com/commonfeeds/v1/cne/rss/latest.xml"), ("Financial Express Market", "https://www.financialexpress.com/market/feed/"),
        ("Financial Express Business", "https://www.financialexpress.com/business/feed/"), ("BusinessLine Markets", "https://www.thehindubusinessline.com/markets/feeder/default.rss"),
        ("BusinessLine Companies", "https://www.thehindubusinessline.com/companies/feeder/default.rss"), ("BusinessLine Economy", "https://www.thehindubusinessline.com/economy/feeder/default.rss"),
        ("NDTV Profit", "https://feeds.feedburner.com/ndtvprofit-latest"), ("NDTV Profit Markets", "https://www.ndtvprofit.com/feeds/markets"),
        ("Zee Business Markets", "https://www.zeebiz.com/markets.xml"), ("Zee Business Latest", "https://www.zeebiz.com/latest.xml"),
        ("Business Today Markets", "https://www.businesstoday.in/rss/markets"), ("Business Today", "https://www.businesstoday.in/rssfeeds/?id=home"),
        ("Moneycontrol Buzzing", "https://www.moneycontrol.com/rss/buzzingstocks.xml"), ("Moneycontrol Economy", "https://www.moneycontrol.com/rss/economy.xml"),
        ("Moneycontrol IPO", "https://www.moneycontrol.com/rss/iponews.xml"), ("Mint Latest", "https://www.livemint.com/rss/news"),
        ("Business Standard Latest", "https://www.business-standard.com/rss/latest.rss"), ("Business Standard Economy", "https://www.business-standard.com/rss/economy-102.rss"),
        ("ET Industry", "https://economictimes.indiatimes.com/industry/rssfeeds/13352306.cms"), ("ET Now", "https://www.etnownews.com/feeds/gns-etn-latest.xml"),
        ("Hindu Business", "https://www.thehindu.com/business/feeder/default.rss"), ("TOI Business", "https://timesofindia.indiatimes.com/rssfeeds/1898055.cms")]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*"}


def fresh_items(txt, now):
    n = 0
    for blk in re.findall(r"<item\b.*?</item>", txt or "", re.S | re.I)[:60]:
        if not re.search(r"<title[^>]*>\s*\S", blk, re.I):
            continue
        p = re.search(r"<pubDate>(.*?)</pubDate>", blk, re.S | re.I)
        try:
            if p and now - parsedate_to_datetime(p.group(1).strip()).timestamp() > 4 * 86400:
                continue
        except Exception:
            pass
        n += 1
    return n


def probe(get=None, now=None):
    now = now or time.time()
    if get is None:
        import requests
        get = lambda u: (lambda r: r.text if r.status_code == 200 else "")(requests.get(u, headers=UA, timeout=12))
    keep, report = [], []
    for name, url in CAND:
        try:
            n = fresh_items(get(url), now)
        except Exception as ex:
            n = -1
        report.append("  %-28s %s" % (name, ("%d fresh items ✓" % n) if n >= 5 else ("no answer" if n < 0 else "%d items - not used" % n)))
        if n >= 5:
            keep.append([name, url, 60])
    return keep, report


if __name__ == "__main__":
    keep, rep = probe()
    print("\n".join(rep))
    json.dump(keep, open(sys.argv[1], "w"))
    print("  -> %d Indian sites added to the every-minute reading" % len(keep))
PY_FP
cat > $W/p272test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p272test.py - Indian news sites first (temp copies, made-up items, nothing sent).  python3 p272test.py DIR WORKDIR"""
import os, sys, json, types, shutil, sqlite3, tempfile, datetime as dt
SRC, WK = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("newsclean.py", "morningbrief.py", "govwatch.py"):
    shutil.copy(os.path.join(SRC, f), T)
shutil.copy(os.path.join(WK, "feedprobe.py"), T)
sys.path.insert(0, T); sys.path.append(SRC); os.chdir(T)
import newsclean as NC
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
chk("known Indian sites are trusted: The Hindu, Moneycontrol, Mint, CNBC-TV18, 'The Economi…' (cut short)",
    all(NC.trusted(title="x - " + o) for o in ("The Hindu", "Moneycontrol", "Mint", "CNBC-TV18", "The Economi")))
chk("social media / blogs never: LinkedIn (also cut short 'LinkedI'), YouTube, Medium", all(NC.blocked(title="x - " + o) for o in ("LinkedIn", "LinkedI", "YouTube", "Medium")))
chk("an unknown site is neither (shown, marked): Urban Acres, Unique Times Magazine", NC.trusted(title="x - Urban Acres") is None and not NC.blocked(title="x - Urban Acres"))
td = sqlite3.connect("tomorrow.db"); td.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
rows = [("2026-11-13", "18:30:00", "", "PAYTM", "", "⚠️ SHOCK WATCH ▲ PAYTM · REGULATOR · RBI\nPaytm gets RBI's in-principle nod to revive wallet business - The Hindu"),
        ("2026-11-13", "18:50:00", "", "PAYTM", "", "⚠️ SHOCK WATCH ▲ PAYTM · REGULATOR · RBI\nPaytm Prepaid Wallets Win RBI Nod, But Final Approval Still Pending - Urban Acres"),
        ("2026-11-13", "19:00:00", "", "LICI", "", "⚠️ SHOCK WATCH ▲ LICI · DEAL · x\nLIC to buy stake in a health insurer - Unique Times Magazine"),
        ("2026-11-13", "19:10:00", "", "", "", "🚨 CRITICAL GOVT · IRDAI · 19:10\nIRDAI proposed commission cuts: Which banks face impact? - CNBC TV18 - LinkedIn")]
td.executemany("insert into alerts values (?,?,?,?,?,?)", rows); td.commit()
fd = sqlite3.connect("filings.db"); fd.execute("create table filings(sym text, t_exch int, kind text, side int, subject text, detail text, verdict text)"); fd.commit()
import morningbrief as MB
txt = MB.build(dt.datetime(2026, 11, 14, 8, 30, tzinfo=IST))[0]
chk("the brief: PAYTM led by The Hindu (trusted), not the later Urban Acres report · '[+1 more report]'", "Paytm gets RBI's in-principle nod" in txt and "[+1 more report]" in txt and "Urban Acres" not in txt, txt)
chk("... LICI from an unknown site only: shown, marked '(small site - check)'", "LIC to buy stake" in txt and "small site - check" in txt, txt)
chk("... the LinkedIn post is not shown", "LinkedIn" not in txt and "commission cuts" not in txt, txt)
print("\n" + txt + "\n")
import govwatch as G
G.fo_map = lambda: {}
G.BASE = T; G.SEEN = os.path.join(T, "data", "govwatch.json")         # only this test's own files
rfc = lambda x: x.strftime("%a, %d %b %Y %H:%M:%S +0530")
POL = [u for s, u in G.SOURCES if s == "POLICY"][0]
FEED = {}
get = lambda u: FEED.get(u, "<rss><channel></channel></rss>")
rss = lambda items: "<rss><channel>" + "".join("<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>" % i for i in items) + "</channel></rss>"
json.dump({"seen": [], "first": False, "p260": True, "srcs": sorted({s for s, _ in G.SOURCES})}, open(G.SEEN, "w"))
N = dt.datetime(2026, 11, 16, 10, 0, tzinfo=IST)
FEED[POL] = rss([("Government cuts customs duty on textile machinery - Urban Acres", "https://news.google.com/u", rfc(N))])
r1 = G.run(get=get, now=N)
FEED[POL] = rss([("Centre slashes import duty on textile machinery to boost MMF exports - The Economic Times", "https://news.google.com/e", rfc(N))])
r2 = G.run(get=get, now=N + dt.timedelta(minutes=2))
chk("Telegram policy news: from an unknown site - not sent; the same from The Economic Times - sent", r1 == [] and len(r2) == 1 and "Economic Times" in r2[0], (r1, r2))
import feedprobe as FP
now = dt.datetime(2026, 11, 16, 10, 0, tzinfo=IST).timestamp()
good = "<rss><channel>" + "".join("<item><title>Story %d</title><pubDate>%s</pubDate></item>" % (i, rfc(N)) for i in range(8)) + "</channel></rss>"
stale = "<rss><channel>" + "".join("<item><title>Old %d</title><pubDate>Mon, 01 Sep 2025 10:00:00 +0530</pubDate></item>" % i for i in range(8)) + "</channel></rss>"
def fget(u):
    if "cnbctv18" in u: return good
    if "financialexpress" in u: return stale
    raise IOError("no answer")
keep, rep = FP.probe(fget, now)
chk("the feed test keeps only sites that answer with fresh news (CNBC-TV18 yes · a stale feed no · no answer no)",
    keep and all("CNBC" in k[0] for k in keep) and any("not used" in r for r in rep) and any("no answer" in r for r in rep), (keep, rep[:4]))
print("INDIAN NEWS FIRST test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p272_patch.py $D || back
cd $D && python3 -m py_compile newsclean.py morningbrief.py govwatch.py newsroom.py macro.py || back
echo "=== test"
python3 $W/p272test.py $D $W > $W/t272.out 2>&1; RC=$?
grep "✅\|❌\|passed\|Error\|error" $W/t272.out
[ $RC -eq 0 ] || { echo "  --- the test's last lines:"; tail -15 $W/t272.out; back; }
echo "=== the Indian business sites, tried from this server now"
mkdir -p $D/data; timeout 200 python3 $W/feedprobe.py $D/data/feeds_extra.json || echo "  (the sites could not be tried now - GIR keeps its 4 sites; run again later)"
chown --reference=$D $D/newsclean.py $D/data/feeds_extra.json 2>/dev/null
cd $D && python3 -c "import macro; print('  every-minute reading now: %d feeds' % len(macro.FEEDS))" 2>/dev/null
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 6; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 272 done - Indian news sites first, social media never, unknown sites marked. Check any time: bash $D/newsaudit.sh"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/data/feeds_extra.json; systemctl restart $SV"
