#!/bin/bash
# PATCH 106 - MARKET NEWS WITHOUT THE NOISE (on top of patch 103). The first read on this server showed lines that must not
#   ring the phone: Brazil's finance minister, one NRI's tax case, an Edelweiss opinion ("India should scrap ..."). Now:
#   · only India's market news counts (India / Nifty / Sensex / SEBI / RBI / FII / STT / LTCG / Govt / Centre ... in the line)
#   · an opinion or an explainer ("should", "urges", "demands", "calls for", "explained") is marked down - page only
#   · only established outlets ring the phone (ET, Moneycontrol, Mint, Business Standard, BusinessLine, Financial Express,
#     Reuters, Bloomberg, CNBC, NDTV, PTI, RBI, SEBI, PIB ...); tax blogs, foreign and niche sites stay on the page
#   macro.py replaced (backed up). Installs p106test.py. Restarts gir-newsroom only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M)
grep -q "def nifty_watch" $D/engine2.py || { echo "patch 103 is not installed yet - paste patch 103 first"; exit 1; }
grep -q "def trusted" $D/macro.py && { echo "patch 106 is already installed"; exit 1; }
cp $D/macro.py $D/macro.py.bak$TS
back() { cp $D/macro.py.bak$TS $D/macro.py; rm -f $D/p106test.py; systemctl restart gir-newsroom; echo "ERROR - old macro.py back, nothing changed"; exit 1; }
cat > $D/macro.py <<'PY_MACRO'
#!/usr/bin/env python3
"""macro.py - MARKET NEWS (patch 103): the news that moves the WHOLE market, not one share - the Finance Minister in
Parliament (LTCG / STT / capital gains / FII tax), RBI (repo, policy), SEBI (F&O rules, FPI), the budget, GST, the US Fed,
tariffs, crude, the rupee, war / ceasefire, and NIFTY / SENSEX swinging. Reads the business wires every minute (Economic
Times, Moneycontrol, Mint, Business Standard, RBI, SEBI; Google News every 2 min), scores each headline, keeps them in
data/macro.json (the page's news panels) and sends the important ones to GIR Box Picks as one ringing line:
    🏛 MARKET NEWS ▲ likely UP · 14:32 · Economic Times
    FM cuts LTCG for FIIs ...                                       (if NIFTY just swung: "WHY NIFTY MOVED")
Runs as a thread inside the newsroom service (gir-newsroom).
  python3 macro.py --once      fetch every source once now, print what each gave and the top headlines (sends nothing)"""
import os, re, sys, json, time, threading, hashlib, datetime as dt
from email.utils import parsedate_to_datetime
from urllib.parse import quote
import xml.etree.ElementTree as ET

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "macro.json")
STATUS = os.path.join(BASE, "data", "macro_status.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
GQ = lambda q: "https://news.google.com/rss/search?q=" + quote(q) + "&hl=en-IN&gl=IN&ceid=IN:en"
FEEDS = [("Economic Times", "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms", 60),
         ("ET Economy", "https://economictimes.indiatimes.com/news/economy/rssfeeds/1373380680.cms", 60),
         ("Moneycontrol", "https://www.moneycontrol.com/rss/latestnews.xml", 60),
         ("Moneycontrol Markets", "https://www.moneycontrol.com/rss/marketreports.xml", 60),
         ("Mint", "https://www.livemint.com/rss/markets", 60),
         ("Mint Economy", "https://www.livemint.com/rss/economy", 60),
         ("Business Standard", "https://www.business-standard.com/rss/markets-106.rss", 60),
         ("RBI", "https://www.rbi.org.in/pressreleases_rss.xml", 120),
         ("SEBI", "https://www.sebi.gov.in/sebirss.xml", 120),
         ("Google News · policy", GQ('(Sitharaman OR "finance minister" OR LTCG OR STT OR "capital gains" OR "securities transaction tax" OR FPI OR "foreign investors") when:1d'), 120),
         ("Google News · RBI SEBI", GQ('(RBI OR SEBI OR "repo rate" OR "F&O" OR derivatives) (policy OR rules OR cut OR hike OR circular) when:1d'), 120),
         ("Google News · markets", GQ('(Nifty OR Sensex) (jumps OR surges OR soars OR crashes OR tanks OR plunges OR recovers OR rebounds OR "turns positive" OR "turns negative") when:1d'), 120),
         ("Google News · global", GQ('(Fed OR "Federal Reserve" OR tariff OR crude OR rupee OR ceasefire OR war) India markets when:1d'), 180)]

# what makes a headline market-moving (weights) - the Parliament / tax / RBI / SEBI words weigh most
TOPIC = [(r"\b(sitharaman|finance minister|finance ministry|fm\b|union budget|budget 20\d\d|parliament|lok sabha|rajya sabha)", 3),
         (r"\b(ltcg|stcg|long[- ]term capital gains?|short[- ]term capital gains?|capital gains tax|stt\b|securities transaction tax|tax on (fii|fpi|foreign))", 4),
         (r"\b(fii|fiis|fpi|fpis|foreign (portfolio )?investors?)\b", 2),
         (r"\b(rbi|reserve bank|repo rate|monetary policy|mpc|crr|rate cut|rate hike)\b", 3),
         (r"\b(sebi)\b", 2), (r"\b(f&o|derivatives?|futures and options|weekly expiry|lot size)\b", 1),
         (r"\b(gst council|gst rate|budget)\b", 2),
         (r"\b(us fed|federal reserve|powell|fomc|us inflation|cpi)\b", 2),
         (r"\b(tariffs?|trade deal|trade war|sanctions?)\b", 2),
         (r"\b(crude|brent|oil prices?)\b", 1), (r"\b(rupee)\b", 1),
         (r"\b(war|attack|missile|strikes? on|ceasefire|terror)\b", 2),
         (r"\b(nifty|sensex|dalal street|indian (stock )?market|markets?)\b", 1),
         (r"\b(jumps?|surges?|soars?|rall(y|ies)|crash(es)?|tanks?|plunges?|tumbles?|recovers?|rebounds?|turns? (positive|negative)|sell-?off|\d{3,4} (pts|points))\b", 2)]
COMBO = [(r"\b(rbi|reserve bank|repo|mpc)\b", r"\b(cut|cuts|hike|hikes|unchanged|holds?|policy|pause)\b", 2),
         (r"\b(sebi)\b", r"\b(f&o|derivatives?|lot size|expiry|margin|fpi|algo|rules?|circular|tighten)", 2),
         (r"\b(fed|federal reserve|fomc|powell)\b", r"\b(cut|cuts|hike|hikes|holds?|pause)\b", 2),
         (r"\b(tax|stt|ltcg|stcg|duty|levy|gst)\b", r"\b(cut|cuts|hike|hikes|raise[sd]?|scrap|exempt|relief|lower|reduce|increase)", 2)]
INDIA = re.compile(r"(f&o|\b(india|indian|indians|sebi|rbi|reserve bank|nifty|sensex|sitharaman|fiis?|fpis?|dalal|rupee|gst|nse|bse|lok sabha|rajya sabha|parliament|modi|centre|union budget|dii|d-street|mumbai|stt|ltcg|stcg|securities transaction tax|govt|finance ministry|cbdt|dpiit)\b)", re.I)
OPINION = re.compile(r"\b(should|urges?|seeks?|demands?|calls? for|wants?|suggests?|hopes?|wishlist|wish list|opinion|view|column|explained|explainer|what is|how to|why you)\b", re.I)
TRUST = ("economic times", "et now", "et markets", "et economy", "moneycontrol", "mint", "livemint", "business standard", "businessline", "hindu businessline",
         "financial express", "reuters", "bloomberg", "cnbc", "ndtv", "business today", "the hindu", "times of india", "indian express", "hindustan times",
         "press information bureau", "pib", "rbi", "sebi", "pti", "press trust", "zee business", "outlook business", "fortune india", "free press journal",
         "deccan herald", "news18", "india today", "the print", "theprint", "firstpost", "moneycontrol markets", "mint economy")
UP = re.compile(r"\b(cut|cuts|slash|scrap|scraps|scrapped|exempt|exemption|relief|eases?|eased|lower(s|ed)?|reduce[sd]?|rollback|withdraw|stimulus|boost|jumps?|surges?|soars?|rall(y|ies)|recovers?|rebounds?|turns? positive|ceasefire|deal|record high|gains?)\b", re.I)
DOWN = re.compile(r"\b(hike|hikes|raise[sd]?|increase[sd]?|impose[sd]?|levy|curb|curbs|ban|tighten|war|attack|missile|crash(es)?|tanks?|plunges?|tumbles?|sell-?off|slumps?|turns? negative|tariffs? (on|against) india|record low|falls?|drops?)\b", re.I)
WHY = [(r"ltcg|capital gains|stt|securities transaction", "a tax on investing gains / trades - FIIs and traders react at once"),
       (r"fii|fpi|foreign (portfolio )?investors?", "the foreign money that drives NIFTY's big moves"),
       (r"repo|rate cut|rate hike|monetary policy|rbi", "interest rates - banks, NBFCs, realty and autos move first"),
       (r"sebi|f&o|derivatives|lot size|expiry", "the F&O rules themselves - volumes and option premiums react"),
       (r"budget|gst", "tax and spending - the sectors named move"),
       (r"fed|federal reserve|powell|fomc", "US rates - FII flows and IT shares react"),
       (r"tariff|trade", "exports - IT, pharma, metals, autos react"),
       (r"crude|brent|oil", "oil - OMCs, paints, aviation, the rupee react"),
       (r"war|attack|missile|ceasefire|terror", "risk on / risk off - the whole market"),
       (r"nifty|sensex", "the index itself is moving - check the open trades")]


def score(h):
    t = h.lower()
    sc = sum(w for p, w in TOPIC if re.search(p, t)) + sum(w for a, b, w in COMBO if re.search(a, t) and re.search(b, t))
    if not INDIA.search(h):                              # patch 106: only India's market news counts (not Brazil's finance minister)
        sc = min(sc, 2)
    if OPINION.search(h):                                # an opinion / an explainer is not a decision
        sc -= 4
    up, dn = len(UP.findall(h)), len(DOWN.findall(h))
    side = 1 if up > dn else -1 if dn > up else 0
    if re.search(r"\b(tax|stt|ltcg|duty|levy)\b", t) and re.search(r"\b(cut|scrap|exempt|relief|lower|reduce|rollback|withdraw)", t):
        side = 1                                         # a tax CUT is good for the market even though "tax" sounds bad
    why = next((w for p, w in WHY if re.search(p, t)), "")
    return sc, side, why


def key(h):
    w = sorted(set(x for x in re.findall(r"[a-z0-9]{4,}", h.lower())))[:10]
    return hashlib.sha1(" ".join(w).encode()).hexdigest()[:12]


def parse(text, src):
    """RSS / Atom -> [(epoch, title, link)] - tolerant of every feed's own shape"""
    out = []
    try:
        root = ET.fromstring(text.encode("utf-8", "ignore") if isinstance(text, str) else text)
    except Exception:
        return out
    for it in list(root.iter("item")) + list(root.iter("{http://www.w3.org/2005/Atom}entry")):
        g = lambda *names: next(((x.text or "").strip() for n in names for x in [it.find(n)] if x is not None and (x.text or "").strip()), "")
        title = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", g("title", "{http://www.w3.org/2005/Atom}title")))
        pub = ""
        if " - " in title and src.startswith("Google"):
            title, pub = title.rsplit(" - ", 1)
        link = g("link")
        if not link:
            le = it.find("{http://www.w3.org/2005/Atom}link")
            link = le.get("href") if le is not None else ""
        ds = g("pubDate", "{http://www.w3.org/2005/Atom}updated", "{http://www.w3.org/2005/Atom}published", "{http://purl.org/dc/elements/1.1/}date")
        t = None
        try:
            t = parsedate_to_datetime(ds).timestamp()
        except Exception:
            try:
                t = dt.datetime.fromisoformat(ds.replace("Z", "+00:00")).timestamp()
            except Exception:
                t = None
        if title:
            out.append((t, title[:200], link[:300], pub[:40]))
    return out


def fetch(url, timeout=8):
    import requests
    r = requests.get(url, timeout=timeout, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
                                                    "Accept": "application/rss+xml, application/xml, text/xml, */*"})
    return r.status_code, r.text if r.ok else ""


def load():
    try:
        return json.load(open(FILE))
    except Exception:
        return {"items": [], "sent": {}, "day": None, "n_sent": 0}


def save(j):
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    json.dump(j, open(FILE + ".tmp", "w"), ensure_ascii=False)
    os.replace(FILE + ".tmp", FILE)


def nifty_now():
    try:
        q = json.load(open(os.path.join(BASE, "quotes_live.json")))
        if time.time() - float(q.get("t") or 0) < 60 and q["q"].get("NIFTY50"):
            return q["q"]["NIFTY50"]
    except Exception:
        pass
    return None


def recent_shock(within=2700):
    try:
        s = json.load(open(os.path.join(BASE, "data", "nifty_shock.json")))
        if time.time() - float(s.get("t") or 0) <= within:
            return s
    except Exception:
        pass
    return None


def trusted(src):
    s_ = (src or "").lower()
    return any(t in s_ for t in TRUST)


def line(it):
    """the Box Picks line for one market headline"""
    sh = recent_shock()
    arrow = "▲ likely UP" if it["side"] > 0 else "▼ likely DOWN" if it["side"] < 0 else "· direction unclear"
    head = "🏛 MARKET NEWS %s · %s · %s" % (arrow, it["hm"], it["src"])
    n = nifty_now()
    L = [head, ("WHY NIFTY MOVED (%s %+.2f%% at %s): " % ("▲" if sh["mv"] > 0 else "▼", sh["mv"], sh["hm"]) if sh else "") + it["h"]]
    if it.get("why"):
        L.append("why it matters: " + it["why"])
    if n:
        L.append("NIFTY now %s (%+.2f%% today)" % ("{:,.2f}".format(n[0]), n[1] or 0))
    return "\n".join(L)


def scan(sources=None, send=True, now=None):
    """one pass over the due sources: new headlines scored, kept, the important ones sent. Returns (new items, sent)"""
    now = now or time.time()
    j = load()
    d_ = dt.datetime.now(IST).strftime("%Y-%m-%d")
    if j.get("day") != d_:
        j.update({"day": d_, "n_sent": 0})
    seen = {x["k"] for x in j["items"]}
    st = {}
    try:
        st = json.load(open(STATUS))
    except Exception:
        pass
    new, sent = [], 0
    for name, url, every in (sources or FEEDS):
        s0 = st.get(name) or {}
        if sources is None and now - float(s0.get("at") or 0) < every:
            continue
        try:
            code, txt = fetch(url)
            rows = parse(txt, name) if txt else []
            st[name] = {"at": now, "code": code, "n": len(rows)}
        except Exception as ex:
            st[name] = {"at": now, "code": str(ex)[:60], "n": 0}; rows = []
        for t, h, link, pub in rows:
            k = key(h)
            if k in seen:
                continue
            sc, side, why = score(h)
            if sc < 3:
                continue
            seen.add(k)
            t = t or now
            it = {"k": k, "t": t, "hm": dt.datetime.fromtimestamp(t, IST).strftime("%H:%M"), "h": h, "src": pub or name.split(" · ")[0], "link": link, "score": sc, "side": side, "why": why}
            j["items"].append(it); new.append(it)
    j["items"] = sorted([x for x in j["items"] if now - x["t"] < 36 * 3600], key=lambda x: -x["t"])[:200]
    if send:
        for it in sorted(new, key=lambda x: -x["score"]):
            if it["score"] >= 5 and trusted(it["src"]) and now - it["t"] < 3 * 3600 and j.get("n_sent", 0) < 12 and it["k"] not in j["sent"]:
                try:
                    import engine2
                    engine2.tg_fo(line(it))
                    j["sent"][it["k"]] = now; j["n_sent"] = j.get("n_sent", 0) + 1; sent += 1
                except Exception as ex:
                    print("macro send: %s" % str(ex)[:80])
        j["sent"] = {k: v for k, v in j["sent"].items() if now - v < 3 * 86400}
    save(j)
    try:
        json.dump(st, open(STATUS + ".tmp", "w")); os.replace(STATUS + ".tmp", STATUS)
    except Exception:
        pass
    return new, sent


def run():
    """the newsroom's market-news thread: every 20 s it reads the sources that are due (each on its own minute)"""
    while True:
        try:
            hm = dt.datetime.now(IST).strftime("%H:%M")
            if "06:30" <= hm <= "23:45":
                scan()
        except Exception as ex:
            print("macro: %s" % str(ex)[:120])
        time.sleep(20)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--once"]:
        new, _ = scan(sources=FEEDS, send=False)
        st = json.load(open(STATUS))
        for name, _u, _e in FEEDS:
            s = st.get(name) or {}
            print("    %-24s %s · %s headlines" % (name, s.get("code"), s.get("n")))
        items = load()["items"]
        print("    %d market headlines kept (36 h) · the top 10 (RING = would ring the phone; page = page only):" % len(items))
        for it in sorted(items, key=lambda x: (-x["score"], -x["t"]))[:10]:
            sc_, _s, _w = score(it["h"])
            print("    %s %s %2d %-4s %s  [%s]" % (it["hm"], "▲" if it["side"] > 0 else "▼" if it["side"] < 0 else "·", sc_, "RING" if (sc_ >= 5 and trusted(it["src"])) else "page", it["h"][:90], it["src"]))
PY_MACRO
cat > $D/p106test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p106test.py - MARKET NEWS without the noise: only India's market news counts; opinions ("should", "urges") do not ring;
only established outlets ring the phone (blogs, foreign and niche sites stay on the page or are dropped)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import macro
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


def d(h, src):
    sc, _s, _w = macro.score(h)
    return "RING" if (sc >= 5 and macro.trusted(src)) else "page" if sc >= 3 else "drop"


T = [("Sitharaman announces LTCG cut for FIIs in Parliament; Sensex jumps 900 points", "Economic Times", "RING"),
     ("Govt hikes STT on futures and options", "Moneycontrol", "RING"),
     ("SEBI tightens F&O rules, raises lot size", "Economic Times", "RING"),
     ("RBI keeps repo rate unchanged, cuts CRR", "Mint", "RING"),
     ("US Fed cuts rates; FPIs return to India", "Reuters", "RING"),
     ("Centre cuts LTCG for foreign investors", "PTI", "RING"),
     ("India should scrap capital gains tax on foreign investors: Edelweiss chief", "Business Standard", "page"),
     ("Edelweiss urges India to scrap foreign capital gains tax to revive markets", "BusinessLine", "page"),
     ("Finance Minister says end of betting will reduce Selective Tax revenue and require budget", "iGaming Brazil", "drop"),
     ("ITAT Grants Relief to NRI Woman in Capital Gains Tax Case", "Taxscan", "drop"),
     ("SEBI Circular on Currency Derivatives: USD 5 Million Exposure Limit Without Underlying", "TaxCorp AI", "page"),
     ("Glenmark shares rise on USFDA nod", "Mint", "drop")]
for h, src, want in T:
    got = d(h, src)
    check("%-4s %s [%s]" % (got, h[:70], src), got == want)
print("\nP106 MARKET NEWS NOISE TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile macro.py p106test.py || back
echo "--- 1. the tests:"
timeout 60 python3 p106test.py 2>&1 | grep "OK  \|FAIL\|NOISE TEST"
timeout 60 python3 p106test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
timeout 300 python3 p103test.py >/dev/null 2>&1 && echo "    p103test.py passed" || { echo "p103test.py failed"; back; }
echo "--- 2. today's market headlines on this server, with the new rule (RING = rings the phone · page = on the page only):"
timeout 150 python3 macro.py --once 2>&1 | tail -11
systemctl restart gir-newsroom && sleep 5
echo "newsroom: $(systemctl is-active gir-newsroom)"
echo "PATCH 106 APPLIED"
