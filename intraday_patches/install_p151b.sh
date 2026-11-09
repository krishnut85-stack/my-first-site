#!/bin/bash
# PATCH 151b - GOVT WATCH READS RBI (its feed answered but the reader refused stray characters) and the probe shows where PIB redirects.
#   govwatch.py replaced. No restart - safe any time.
D=/home/globalbot/intraday
grep -q "151b" $D/govwatch.py 2>/dev/null && { echo "patch 151b is already installed"; exit 1; }
cp $D/govwatch.py $D/govwatch.py.bak$(date +%m%d%H%M)
cat > $D/govwatch.py <<'PY_GW'
#!/usr/bin/env python3
"""govwatch.py - patch 151 (151b: a tolerant reader, the probe shows redirects): 🏛 GOVT WATCH (Rama, 9 Nov: "PSU banks ran - maybe the FM announced something; someone should watch and tell
me at once"). Every 2 minutes it reads the official sources directly - before TV and the news sites carry them:
  PIB    the government's press releases (Finance, Commerce, Petroleum, Power, Steel, Defence, Railways ... every ministry)
  RBI    press releases and notifications          SEBI   press releases
A release that names something the F&O market trades on (rates, duties, taxes, PSU banks, disinvestment, oil prices, steel, power,
defence orders, pharma, telecom, PLI ...) becomes one line: what was said, which sectors it touches, the F&O shares to watch.
  🚨 CRITICAL GOVT  - a rate / duty / tax / ban / disinvestment / merger decision -> GIR Box Picks, ringing
  🏛 GOVT WATCH     - the rest that touches a sector -> the 📰 News topic
The first run only remembers what is there (no flood); after that each new release is said once.
  python3 govwatch.py probe        what each source answers now (nothing sent)
  python3 govwatch.py --send       one pass (the timer runs this every 2 minutes)"""
import os, re, sys, json, time, html, datetime as dt
import xml.etree.ElementTree as ET

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SEEN = os.path.join(BASE, "data", "govwatch.json")
SOURCES = [
    ("PIB", "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"),
    ("PIB", "https://www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"),
    ("RBI", "https://www.rbi.org.in/pressreleases_rss.xml"),
    ("RBI", "https://www.rbi.org.in/notifications_rss.xml"),
    ("SEBI", "https://www.sebi.gov.in/sebirss.xml"),
]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*"}
# keyword -> GIR sector names (sectors.load) it touches
TOPICS = [
    (r"repo rate|reverse repo|\bcrr\b|\bslr\b|monetary policy|policy rate|liquidity|bank(s|ing)? (credit|deposit)|public sector bank|\bpsbs?\b|recapitali", ["banks", "nbfc"]),
    (r"nbfc|housing finance|microfinance|gold loan", ["nbfc"]),
    (r"insurance|irdai", ["insurance"]),
    (r"crude|petrol|diesel|\blpg\b|natural gas|oil market|windfall|refin|ongc|\bcng\b", ["oil-gas"]),
    (r"steel|iron ore|alumin|copper|zinc|coal|mining|mineral", ["metals"]),
    (r"power|electricity|renewable|solar|wind energy|transmission|discom", ["power"]),
    (r"pharma|drug|medicine|usfda|healthcare|hospital|ayushman", ["pharma", "healthcare"]),
    (r"telecom|spectrum|5g|\btrai\b|broadband", ["telecom-media"]),
    (r"automobile|\bauto\b|electric vehicle|\bev\b|two-wheeler|vehicle", ["auto", "auto-anc"]),
    (r"defen[cs]e|military|armed forces|\bdrdo\b|aircraft|warship|missile", ["capital-goods"]),
    (r"railway|rail|road|highway|infrastructure|cement|housing|smart cit|metro", ["cement-infra", "capital-goods"]),
    (r"fmcg|sugar|edible oil|wheat|rice|food|fertili[sz]er|agricultur", ["fmcg", "chemicals"]),
    (r"semiconductor|electronics|it services|software|digital", ["it", "capital-goods"]),
    (r"capital market|stock exchange|mutual fund|\bsebi\b|ipo|demat|broker|f&o|derivative", ["capital-mkts"]),
]
CRIT = re.compile(r"repo rate|\bcrr\b|rate cut|rate hike|customs duty|excise duty|export duty|import duty|windfall|\bgst council\b|\bban(s|ned)?\b|"
                  r"disinvest|stake sale|offer for sale|\bofs\b|merger|amalgamat|recapitali|budget|\bpli\b|fdi (limit|cap)|surcharge|cess", re.I)


def fo_map():
    try:
        import sectors, sqlite3
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        fo = {r[0] for r in c.execute("select sym from fo_list")}
        c.close()
        return {k: [s for s in v if not fo or s in fo] for k, v in sectors.load().items()}
    except Exception:
        return {}


LAST = {}


def fetch(url, get=None):
    if get is not None:
        return get(url)
    import requests
    r = requests.get(url, headers=UA, timeout=15, allow_redirects=True)
    LAST[url] = "HTTP %s · %s · %d bytes · %s" % (r.status_code, r.url if r.url != url else "same address", len(r.content), re.sub(r"\s+", " ", r.text[:90]))
    if r.status_code != 200:
        return None
    r.encoding = r.encoding or "utf-8"
    return r.text


def _rx_items(txt):
    """patch 151b: a feed the XML reader refuses (stray characters in a release) - read it item by item"""
    out = []
    for blk in re.findall(r"<(?:item|entry)\b.*?</(?:item|entry)>", txt, re.S | re.I):
        f = lambda n: (re.search(r"<%s[^>]*>(.*?)</%s>" % (n, n), blk, re.S | re.I) or [None, ""])[1]
        t = html.unescape(re.sub(r"<!\[CDATA\[|\]\]>|<[^>]+>", "", f("title"))).strip()
        l = re.sub(r"<!\[CDATA\[|\]\]>", "", f("link")).strip() or (re.search(r'<link[^>]*href="([^"]+)"', blk) or [None, ""])[1]
        if t:
            out.append((t, l, f("pubDate").strip()))
    return out


def items(xml_text):
    """an RSS / Atom text -> [(title, link, published text)]"""
    out = []
    try:
        root = ET.fromstring(xml_text.strip().encode("utf-8"))
    except Exception:
        return _rx_items(xml_text or "")
    for it in root.iter():
        tag = it.tag.split("}")[-1]
        if tag not in ("item", "entry"):
            continue
        g = lambda n: next((c for c in it if c.tag.split("}")[-1] == n), None)
        t, l = g("title"), g("link")
        d = next((x for x in (g("pubDate"), g("updated"), g("published")) if x is not None), None)
        title = html.unescape(re.sub(r"<[^>]+>", "", (t.text or "") if t is not None else "")).strip()
        link = ((l.text or l.get("href") or "") if l is not None else "").strip()
        if title:
            out.append((title, link, (d.text or "").strip() if d is not None else ""))
    return out


def judge(title, M):
    """-> None or (critical?, [sectors], [shares])"""
    t = title.lower()
    secs = []
    for rx, ss in TOPICS:
        if re.search(rx, t):
            secs += [s for s in ss if s not in secs]
    if not secs:
        return None
    shares = []
    for s in secs:
        shares += [x for x in (M.get(s) or [])[:5] if x not in shares]
    return bool(CRIT.search(title)), secs, shares[:8]


def line(src, title, link, crit, secs, shares, now):
    head = ("🚨 CRITICAL GOVT · %s · %s" if crit else "🏛 GOVT WATCH · %s · %s") % (src, now.strftime("%H:%M"))
    return "\n".join([head, title[:300], "touches: %s" % " · ".join(s.upper() for s in secs),
                      "F&O shares to watch: %s" % (" · ".join(shares) or "-"), link])


def run(send=None, get=None, now=None, probe=False):
    now = now or dt.datetime.now(IST)
    try:
        S = json.load(open(SEEN))
    except Exception:
        S = {"seen": [], "first": True}
    seen = set(S.get("seen") or [])
    M = fo_map()
    out, report = [], []
    for src, url in SOURCES:
        try:
            txt = fetch(url, get)
        except Exception as ex:
            report.append("%-5s %s: %s" % (src, url, str(ex)[:60])); continue
        its = items(txt) if txt else []
        report.append("%-5s %s: %d items%s" % (src, url, len(its), (" · latest: " + its[0][0][:70]) if its else (" · " + LAST.get(url, "no answer"))))
        for title, link, d in its[:40]:
            key = (src + ":" + (link or title))[:300]
            if key in seen:
                continue
            seen.add(key)
            j = judge(title, M)
            if j and not S.get("first"):
                out.append(line(src, title, link, *j, now))
    if probe:
        return report
    S["first"] = False
    S["seen"] = list(seen)[-3000:]
    os.makedirs(os.path.dirname(SEEN), exist_ok=True)
    json.dump(S, open(SEEN, "w"))
    if send:
        for x in out[:8]:
            send(x)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "probe":
        print("\n".join(run(probe=True)))
        sys.exit(0)
    snd = None
    if "--send" in sys.argv:
        import opencall
        snd = opencall.send_tg
    for x in run(snd):
        print(x + "\n")
PY_GW
cat > $D/p151test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p151test.py - patch 151: GOVT WATCH on made-up RSS (no network): the first run is silent, then each new release once, critical apart"""
import os, sys, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import govwatch as G
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); G.SEEN = os.path.join(T, "s.json")
G.fo_map = lambda: {"banks": ["SBIN", "PNB", "CANBK", "UNIONBANK", "BANKBARODA", "HDFCBANK"], "nbfc": ["BAJFINANCE"], "oil-gas": ["ONGC", "OIL", "BPCL"], "metals": ["TATASTEEL", "HINDALCO"]}
RSS = lambda its: '<?xml version="1.0"?><rss><channel>' + "".join("<item><title>%s</title><link>https://x/%d</link><pubDate>Mon</pubDate></item>" % (t, abs(hash(t))) for t in its) + "</channel></rss>"
feed = {"pib": ["Cabinet approves new metro line"], "rbi": ["RBI releases weekly statistical supplement"]}
get = lambda u: RSS(feed["pib"]) if "pib" in u else RSS(feed["rbi"]) if "rbi" in u else None
SENT = []
G.run(SENT.append, get, dt.datetime(2026, 11, 9, 22, 0, tzinfo=G.IST))
check("the first run only remembers (nothing sent)", SENT == [])
feed["pib"] = ["Government announces recapitalisation of public sector banks with Rs 20,000 crore", "Cabinet approves new metro line", "Ministry of Steel holds review meeting on iron ore supply"]
feed["rbi"] = ["RBI cuts repo rate by 25 basis points", "RBI releases weekly statistical supplement"]
out = G.run(SENT.append, get, dt.datetime(2026, 11, 10, 10, 5, tzinfo=G.IST))
for x in out: print(x, "\n")
check("3 new releases said (bank recap, steel, repo); the old and the dull ones not", len(out) == 3)
check("bank recapitalisation -> 🚨 CRITICAL GOVT, BANKS, SBIN · PNB ...", any(x.startswith("🚨 CRITICAL GOVT · PIB") and "BANKS" in x and "PNB" in x for x in out))
check("repo rate cut -> 🚨 CRITICAL GOVT · RBI", any(x.startswith("🚨 CRITICAL GOVT · RBI") and "repo" in x for x in out))
check("steel review -> 🏛 GOVT WATCH (not critical), METALS", any(x.startswith("🏛 GOVT WATCH") and "METALS" in x and "TATASTEEL" in x for x in out))
check("a second pass: nothing again", G.run(None, get) == [])
import alertword, tglanes
c = [x for x in out if x.startswith("🚨")][0]; w = [x for x in out if x.startswith("🏛")][0]
check("CRITICAL rings in Box Picks; GOVT WATCH goes to the News topic", tglanes.lane(c) == "critical" and alertword.tier(c) != "read" and tglanes.topic(w) == "news")
bad = '<?xml version="1.0"?><rss><channel><item><title>RBI cuts repo rate &amp; CRR</title><link>https://r/1</link><description>a &nbsp; stray</description></item></channel></rss>'
check("151b: a feed the XML reader refuses (&nbsp;) is still read", G.items(bad) and G.items(bad)[0][0] == "RBI cuts repo rate & CRR")
shutil.rmtree(T)
print("P151 GOVT WATCH TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile govwatch.py && timeout 60 python3 p151test.py > /dev/null 2>&1 && echo "    p151test.py passed" || { cp $(ls -t $D/govwatch.py.bak* | head -1) $D/govwatch.py; echo "test failed - old file back"; exit 1; }
echo "    each source now:"
timeout 120 python3 govwatch.py probe | sed 's/^/      /'
echo "PATCH 151b APPLIED."
