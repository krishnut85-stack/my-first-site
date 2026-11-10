#!/bin/bash
# PATCH 163 - 🏛 REGULATOR WATCH: every 2 minutes GIR reads the regulators' OWN pages (IRDAI, SEBI, RBI, CCI, USFDA, TRAI, ED) - orders,
#   notices, penalties, approvals - and when one names an F&O company rings at once: ⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · IRDAI site.
#   Rama: "Policybazaar crashed because the insurance regulator issued a notice - not on NSE, or days later". No GIR restart. Safe any time.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system
[ -f $D/circuits.py ] && [ -f $D/govwatch.py ] || { echo "run shocks.sh (161) and install_p151 first"; exit 1; }
echo "== 1. the files"
for f in shockwatch.py p161test.py; do cp $D/$f $D/$f.bak163 2>/dev/null; done
cat > $D/regwatch.py <<'REGWATCH_PY'
#!/usr/bin/env python3
"""regwatch.py - patch 163: 🏛 REGULATOR WATCH (Rama, 10 Nov: "Policybazaar crashed because the insurance regulator issued a notice - you
will not find these on NSE, or only days later"). Every 2 minutes it reads the REGULATORS' OWN pages - orders, notices, penalties,
press releases - and when one names an F&O company it rings at once as ⚠️ SHOCK WATCH (GIR Box Picks), the same rules and history as
the news / filings / TV watchers:
  IRDAI (insurance) · SEBI (markets) · RBI (banks, NBFCs) · CCI (competition) · USFDA (warning letters, pharma) · TRAI (telecom) · ED
Each regulator has several page addresses; the ones that answer from the server are used (probe shows which). The first pass only
remembers what is there (no flood).
  python3 regwatch.py probe     each page: does it answer, how many items, the latest two (nothing sent)
  python3 regwatch.py --send    one pass (the timer runs this every 2 minutes)"""
import os, re, sys, json, time, html, datetime as dt
from urllib.parse import urljoin

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SEEN = os.path.join(BASE, "data", "regwatch.json")
HIST = os.path.join(BASE, "data", "h3", "circuits.json")
# (regulator, page) - several addresses each; a page that does not answer is skipped quietly
SOURCES = [
    ("IRDAI", "https://irdai.gov.in/orders1"), ("IRDAI", "https://irdai.gov.in/orders"), ("IRDAI", "https://irdai.gov.in/press-releases"),
    ("IRDAI", "https://irdai.gov.in/whats-new"), ("IRDAI", "https://irdai.gov.in/"),
    ("SEBI", "https://www.sebi.gov.in/sebirss.xml"),
    ("SEBI", "https://www.sebi.gov.in/sebiweb/home/HomeAction.do?doListing=yes&sid=2&s=0&ssid=9&smid=6"),
    ("RBI", "https://www.rbi.org.in/pressreleases_rss.xml"), ("RBI", "https://www.rbi.org.in/Scripts/BS_PressReleaseDisplay.aspx"),
    ("CCI", "https://www.cci.gov.in/antitrust/orders"), ("CCI", "https://www.cci.gov.in/media-gallery/press-release"),
    ("USFDA", "https://www.fda.gov/about-fda/contact-fda/stay-informed/rss-feeds/warning-letters/rss.xml"),
    ("USFDA", "https://www.fda.gov/about-fda/contact-fda/stay-informed/rss-feeds/press-releases/rss.xml"),
    ("TRAI", "https://www.trai.gov.in/notifications/press-release"),
    ("ED", "https://enforcementdirectorate.gov.in/press-release"),
]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*",
      "Accept-Language": "en-US,en;q=0.9"}
GOOD = re.compile(r"approv\w*|grant\w*|registration (?:granted|certificate)|in-principle|licen[cs]e (?:granted|issued)|close[sd] (?:the )?(?:inspection|matter)|"
                  r"no action|disposed of|withdrawn", re.I)
JUNK = re.compile(r"^(?:home|about us|contact us|sitemap|faq|rti|tenders?|careers?|login|search|screen reader|skip to main|more|read more|view|download|"
                  r"click here|archives?|feedback|help|disclaimer|terms|privacy|hindi|english|a\+|a-|a)$", re.I)
LAST = {}


def fetch(url, get=None):
    if get is not None:
        return get(url)
    import requests
    r = requests.get(url, headers=UA, timeout=10, allow_redirects=True)
    LAST[url] = "HTTP %s · %d bytes" % (r.status_code, len(r.content))
    if r.status_code != 200:
        return None
    return r.content.decode("utf-8", "replace")


def html_items(txt, url):
    """an HTML listing -> [(title, link)]: each table row's text + its first link, and the longer link texts"""
    out, seen = [], set()
    clean = lambda s: re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s or ""))).strip()
    for row in re.findall(r"<tr\b.*?</tr>", txt, re.S | re.I):
        t = clean(row)
        h = re.search(r'href="([^"#][^"]*)"', row, re.I)
        if 25 <= len(t) <= 400 and t not in seen:
            seen.add(t); out.append((t, urljoin(url, html.unescape(h.group(1))) if h else url))
    for h, a in re.findall(r'<a\b[^>]*href="([^"#][^"]*)"[^>]*>(.*?)</a>', txt, re.S | re.I):
        t = clean(a)
        if 25 <= len(t) <= 300 and not JUNK.match(t) and t not in seen and not any(t in x for x in seen):
            seen.add(t); out.append((t, urljoin(url, html.unescape(h))))
    return out


def page_items(txt, url):
    head = (txt or "")[:400].lower()
    if "<rss" in head or "<feed" in head or "<?xml" in head:
        import govwatch
        return [(t, l) for t, l, _ in govwatch.items(txt)]
    return html_items(txt or "", url)


def side_of(title):
    if GOOD.search(title):
        return 1
    import circuits as C
    s = C.side_of(title)
    return s if s else -1                                    # a regulator naming a company: trouble until the words say otherwise


def run(send=None, get=None, now=None, probe=False, fo=None):
    import circuits as C, shockwatch as W
    now = now or dt.datetime.now(IST)
    try:
        S = json.load(open(SEEN))
    except Exception:
        S = {"seen": [], "first": True}
    seen = set(S.get("seen") or [])
    try:
        H = json.load(open(HIST))
    except Exception:
        H = {}
    fo = fo if fo is not None else W.fo_syms()
    match = W.matcher(C.names(fo, get))
    out, report, said = [], [], set()
    for reg, url in SOURCES:
        try:
            txt = fetch(url, get)
        except Exception as ex:
            report.append("%-6s %s: no answer (%s)" % (reg, url, str(ex)[:50])); continue
        its = page_items(txt, url) if txt else []
        report.append("%-6s %s: %s%s" % (reg, url, ("%d items" % len(its)) if txt else LAST.get(url, "no answer"),
                                         ("  · latest: " + " | ".join(t[:70] for t, _ in its[:2])) if its else ""))
        for title, link in its[:60]:
            key = (reg + ":" + (link if link != url else title))[:300]
            if key in seen:
                continue
            seen.add(key)
            if S.get("first") or probe:
                continue
            for s in match(title)[:2]:
                if (s, title[:80]) in said:
                    continue
                said.add((s, title[:80]))
                x = {"sym": s, "reason": "REGULATOR", "side": side_of(title), "head": "%s: %s" % (reg, title[:280]), "src": "%s site" % reg, "link": link}
                out.append(W.line(x, H, now))
    if probe:
        return report
    S["first"] = False
    S["seen"] = list(seen)[-6000:]
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
REGWATCH_PY
cat > $D/p163test.py <<'P163TEST_PY'
#!/usr/bin/env python3
"""p163test.py - patch 163: REGULATOR WATCH on made-up regulator pages (no network, nothing sent)"""
import os, sys, json, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regwatch as R, circuits as C

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  FAIL ") + name)
    ok = ok and bool(cond)

T = tempfile.mkdtemp()
R.SEEN = os.path.join(T, "regwatch.json"); R.HIST = os.path.join(T, "circuits.json"); C.NAMES = os.path.join(T, "fo_names.json")
json.dump({"from": "2022-11-01", "by_sym": {"POLICYBZR": [{"d": "2026-09-24", "side": -1, "mv": -36.0, "reason": "REGULATOR"}]},
           "by_reason": {"REGULATOR:-1": {"n": 40, "mv": -11.2, "next": -1.1}}}, open(R.HIST, "w"))
pages = {"irdai": [], "rbi": [], "fda": []}
def get(url):
    if "EQUITY_L" in url:
        return "SYMBOL,NAME OF COMPANY\nPOLICYBZR,PB Fintech Limited\nMANAPPURAM,Manappuram Finance Limited\nSUNPHARMA,Sun Pharmaceutical Industries Limited\nHDFCBANK,HDFC Bank Limited\n"
    if "irdai.gov.in/orders1" in url:
        rows = "".join('<tr><td>%d</td><td>%s</td><td><a href="/documents/o%d.pdf">Download</a></td></tr>' % (i, t, i) for i, t in enumerate(pages["irdai"]))
        return "<html><body><a href='/'>Home</a><table>%s</table></body></html>" % rows
    if "rbi.org.in/pressreleases_rss" in url:
        return "<rss><channel>%s</channel></rss>" % "".join("<item><title>%s</title><link>https://rbi.org.in/p%d</link></item>" % (t, i) for i, t in enumerate(pages["rbi"]))
    if "warning-letters/rss" in url:
        return "<rss><channel>%s</channel></rss>" % "".join("<item><title>%s</title><link>https://fda.gov/w%d</link></item>" % (t, i) for i, t in enumerate(pages["fda"]))
    return None
fo = ["POLICYBZR", "MANAPPURAM", "SUNPHARMA", "HDFCBANK"]
pages["irdai"] = ["Order in the matter of M/s ABC Insurance Brokers Pvt Ltd"]
pages["rbi"] = ["RBI releases the weekly statistical supplement"]
SENT = []
R.run(SENT.append, get, fo=fo)
check("the first pass only remembers (nothing sent)", SENT == [])
pages["irdai"].append("Show cause notice and order in the matter of M/s Policybazaar Insurance Brokers Private Limited - penalty of Rs 5 crore")
pages["rbi"].append("RBI imposes monetary penalty on Manappuram Finance Limited")
pages["rbi"].append("RBI grants in-principle approval to HDFC Bank for acquisition of stake")
pages["fda"].append("Sun Pharmaceutical Industries Limited - 680000 - 11/09/2026 - Warning Letter")
out = R.run(SENT.append, get, fo=fo, now=dt.datetime(2026, 11, 11, 10, 3, tzinfo=R.IST))
for x in out:
    print(x, "\n")
heads = [x.split("\n")[0] for x in out]
check("IRDAI order on Policybazaar -> ⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · IRDAI site",
      any(h.startswith("⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · IRDAI site") for h in heads))
check("it carries Policybazaar's own -36% day", any("POLICYBZR" in x and "-36%" in x for x in out))
check("RBI penalty on Manappuram -> ▼ MANAPPURAM", any("▼ MANAPPURAM · REGULATOR · RBI site" in h for h in heads))
check("RBI approval to HDFC Bank -> ▲ HDFCBANK", any("▲ HDFCBANK · REGULATOR · RBI site" in h for h in heads))
check("USFDA warning letter to Sun Pharma -> ▼ SUNPHARMA", any("▼ SUNPHARMA · REGULATOR · USFDA site" in h for h in heads))
check("an order on a company not in F&O, the weekly supplement -> nothing", len(out) == 4)
check("a second pass: nothing again", R.run(None, get, fo=fo) == [])
check("an HTML listing: rows with their PDF link, 'Home' / 'Download' left out",
      R.html_items('<a href="/">Home</a><table><tr><td>Order in the matter of XYZ Ltd dated 1 Nov</td><td><a href="/d/1.pdf">Download</a></td></tr></table>', "https://irdai.gov.in/x")
      == [("Order in the matter of XYZ Ltd dated 1 Nov Download", "https://irdai.gov.in/d/1.pdf")])
try:
    import alertword, tglanes
    check("rings in GIR Box Picks", all(tglanes.lane(x) == "critical" and alertword.tier(x) != "read" for x in out))
except Exception as ex:
    check("routing (%s)" % ex, False)
shutil.rmtree(T)
print("P163 REGULATOR WATCH TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P163TEST_PY
cat > $D/shockwatch.py <<'SHOCKWATCH_PY'
#!/usr/bin/env python3
"""shockwatch.py - patch 161: ⚠️ SHOCK WATCH (Rama, 10 Nov: "if the same kind of thing is brewing, alert me and I will keep a watch on
that share"). Every 5 minutes, day and night, it looks for the kinds of news that sent F&O shares 8-20% in a day in the last 3 years
(circuits.py), BOTH WAYS:
  ▼ a regulator acting (RBI / SEBI / IRDAI / USFDA / CCI / ED / tax), a governance problem (fraud, auditor quits, short seller,
    accounting), a top boss leaving, a "lower circuit" story
  ▲ a regulator approval (USFDA approval / clean EIR), an open offer / buyback / stake buy, an order of Rs 1,000 crore+, an "upper circuit" story
  * the share's own NSE filings, already read by GIR's EXCHANGE DIRECT (filings.db) - a REG / MGMT filing against the company
  * Google News: a set of searches for those words in the last hour, kept only when the headline names an F&O company
Each one is said ONCE with that share's own past shocks and what such news did to F&O shares: ⚠️ in GIR Box Picks (rings);
the smaller ▲ ones (an order under Rs 1,000 crore, a deal story) as 📰 in the News topic (quiet).
The first run only remembers what is there (no flood).
  python3 shockwatch.py probe      what it would say now (nothing sent, nothing remembered)
  python3 shockwatch.py --send     one pass (the timer runs this every 5 minutes)"""
import os, re, sys, json, time, html, sqlite3, datetime as dt
from urllib.parse import quote

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import circuits as C

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SEEN = os.path.join(BASE, "data", "shockwatch.json")
HIST = os.path.join(BASE, "data", "h3", "circuits.json")
QUERIES = ["RBI imposes", "RBI bars", "RBI restrictions bank", "SEBI order", "SEBI bans", "SEBI show cause", "IRDAI", "USFDA warning letter",
           "import alert USFDA", "Form 483", "OAI USFDA", "CCI penalty", "ED raid company", "income tax search company", "GST demand notice",
           "auditor resigns", "forensic audit", "short seller report", "fraud shares", "accounting lapses", "CEO resigns shares", "shares crash regulator",
           "lower circuit", "upper circuit", "bags order worth crore", "wins order worth crore", "USFDA approval", "EIR USFDA",
           "open offer shares", "buyback shares", "acquire stake", "shares zoom order"]
KEEP = ("REGULATOR", "GOVERNANCE", "MGMT")
KEEP_UP = ("REGULATOR", "ORDER", "DEAL", "POLICY")
PER_RUN = 8                                   # searches per pass: all of them every 15 minutes (Google is not asked too often)


def fo_syms():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        v = [r[0] for r in c.execute("select sym from fo_list")]
        c.close()
        return v
    except Exception:
        return []


def matcher(NM):
    """-> f(title) -> [syms named in it]"""
    pats = []
    for s, L in NM.items():
        for n in L:
            n = n.strip()
            if len(n) < 3:
                continue
            flags = 0 if (n.isupper() and len(n) <= 5) else re.I        # short tickers (SBI, HAL, LIC) only in capitals
            pats.append((s, re.compile(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(n), flags)))
    def f(t):
        out = []
        for s, rx in pats:
            if s not in out and rx.search(t or ""):
                out.append(s)
        return out
    return f


def gnews(q, get=None):
    url = "https://news.google.com/rss/search?q=%s&hl=en-IN&gl=IN&ceid=IN:en" % quote(q + " when:1h")
    if get:
        txt = get(url)
    else:
        import requests
        r = requests.get(url, headers=C.UA, timeout=(5, 10))
        txt = r.text if r.status_code == 200 else ""
    out = []
    for m in re.finditer(r"<item>(.*?)</item>", txt or "", re.S):
        t = re.search(r"<title>(.*?)</title>", m.group(1), re.S)
        l = re.search(r"<link>(.*?)</link>", m.group(1), re.S)
        if t:
            out.append((html.unescape(re.sub(r"<!\[CDATA\[|\]\]>", "", t.group(1))).strip(), l.group(1).strip() if l else ""))
    return out


def filings_new(since, fo):
    p = os.path.join(BASE, "filings.db")
    if not os.path.exists(p):
        return []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=3)
        rows = c.execute("select key, sym, kind, side, subject, detail, link, t_exch from filings where t_seen > ? and kind in ('REG','MGMT','OTHER','BOARD')",
                         (since,)).fetchall()
        c.close()
    except Exception:
        return []
    out = []
    for key, s, kind, side, subj, det, link, te in rows:
        if s not in fo:
            continue
        txt = "%s %s" % (subj or "", (det or "")[:300])
        r = "REGULATOR" if kind == "REG" else "MGMT" if kind == "MGMT" else ("GOVERNANCE" if C.reason_of(txt) == "GOVERNANCE" else None)
        if not r or (kind in ("REG", "MGMT") and (side or 0) > 0 and r != "REGULATOR"):
            continue
        out.append({"key": "F:" + str(key), "sym": s, "reason": r, "side": side or C.side_of(txt) or -1, "head": (subj or "")[:200],
                    "src": "NSE filing", "link": link or ""})
    return out


def history_lines(H, sym, reason, side):
    L = []
    H = dict(H or {}); H["from"] = (H.get("from") or "")[:4] or "2022"
    mine = (H.get("by_sym") or {}).get(sym) or []
    if mine:
        L.append("%s's own shocks since %s: %d · %s" % (sym, (H.get("from") or "")[:4], len(mine), " · ".join("%s %+.0f%% %s" % (x["d"], x["mv"], x["reason"]) for x in mine[-3:])))
    else:
        L.append("%s: no 8%%+ shock since %s" % (sym, (H.get("from") or "")[:4]))
    b = (H.get("by_reason") or {}).get("%s:%d" % (reason, -1 if side < 0 else 1))
    if b and b.get("n"):
        L.append("%s news behind %d F&O shocks %s since %s · avg %+.1f%% that day, %+.1f%% the next" % (reason, b["n"], "▼" if side < 0 else "▲", (H.get("from") or "")[:4], b["mv"], b["next"]))
    return L


def rings(x):
    """▼ always rings; ▲ rings for an approval, an open offer / buyback, an upper-circuit story, an order of Rs 1,000 crore+"""
    if x["side"] < 0 or x.get("circ") or x["reason"] == "REGULATOR":
        return True
    if x["reason"] == "DEAL" and re.search(r"open offer|buy-?back|acquire|stake", x["head"], re.I):
        return True
    if x["reason"] == "ORDER":
        amt = 0.0
        try:
            import exchange
            amt = exchange.amount_cr(x["head"])
        except Exception:
            pass
        for m in re.finditer(r"([\d,]+(?:\.\d+)?)\s*(?:crore|cr\b)", x["head"], re.I):      # spoken: "2,500 crore rupees"
            try:
                amt = max(amt, float(m.group(1).replace(",", "")))
            except ValueError:
                pass
        return amt >= 1000
    return False


def line(x, H, now):
    arrow = "▼" if x["side"] < 0 else "▲"
    hint = ("bearish news: PE side only if the price confirms (breaks the first 15-min low); no fresh CE" if x["side"] < 0
            else "bullish news: CE side only if the price confirms (holds above the first 15-min high)")
    return "\n".join(["%s SHOCK WATCH · %s %s · %s · %s %s" % ("⚠️" if rings(x) else "📰", arrow, x["sym"], x["reason"], x["src"], now.strftime("%H:%M")), x["head"][:300]]
                     + history_lines(H, x["sym"], x["reason"], x["side"]) + ["watch: " + hint] + ([x["link"]] if x.get("link") else []))


def run(send=None, get=None, now=None, probe=False, fo=None):
    now = now or dt.datetime.now(IST)
    try:
        Sx = json.load(open(SEEN))
    except Exception:
        Sx = {"seen": [], "first": True, "since": time.time() - 3600}
    seen = set(Sx.get("seen") or [])
    try:
        H = json.load(open(HIST))
    except Exception:
        H = {}
    fo = fo if fo is not None else fo_syms()
    NM = C.names(fo, get)
    match = matcher(NM)
    found = filings_new(Sx.get("since") or 0, set(fo))
    qi = int(Sx.get("qi") or 0) % len(QUERIES)
    batch = (QUERIES + QUERIES)[qi:qi + PER_RUN]
    Sx["qi"] = (qi + PER_RUN) % len(QUERIES)
    for q in batch:
        try:
            items = gnews(q, get)
        except Exception:
            continue
        for t, l in items[:15]:
            circ = re.search(r"(upper|lower) circuit", t, re.I)
            r, sd = C.reason_of(t), C.side_of(t)
            if circ:
                sd = -1 if circ.group(1).lower() == "lower" else 1
            if not circ and not ((sd < 0 and r in KEEP) or (sd > 0 and r in KEEP_UP)):
                continue
            for s in match(t)[:2]:
                found.append({"key": "N:%s:%s" % (s, re.sub(r"\W+", "", t.lower())[:80]), "sym": s, "reason": r or "MOVE", "side": sd,
                              "head": t, "src": "news", "link": l, "circ": bool(circ)})
    out, report = [], []
    for x in found:
        k = x["key"]
        report.append("%s %s %s: %s" % (x["sym"], x["reason"], x["src"], x["head"][:90]))
        if k in seen:
            continue
        seen.add(k)
        if not Sx.get("first"):
            out.append(line(x, H, now))
    if probe:
        return report or ["nothing found now (%d F&O names watched, %d searches)" % (len(NM), len(QUERIES))]
    Sx["first"] = False
    Sx["since"] = time.time()
    Sx["seen"] = list(seen)[-4000:]
    os.makedirs(os.path.dirname(SEEN), exist_ok=True)
    json.dump(Sx, open(SEEN, "w"))
    if send:
        for x in out[:6]:
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
SHOCKWATCH_PY
cat > $D/p161test.py <<'P161TEST_PY'
#!/usr/bin/env python3
"""p161test.py - patch 161: the shock-day study and SHOCK WATCH on made-up data (no network, nothing sent, real files untouched)"""
import os, sys, json, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import circuits as C, shockwatch as W

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  FAIL ") + name)
    ok = ok and bool(cond)

T = tempfile.mkdtemp()
C.CACHE = os.path.join(T, "shock_reasons.json"); C.NAMES = os.path.join(T, "fo_names.json")
W.SEEN = os.path.join(T, "shockwatch.json"); W.HIST = os.path.join(T, "circuits.json")
C.S.H3 = T
W.PER_RUN = len(W.QUERIES)

# 60 trading days; PBFINTECH falls 20% on day 40 (an IRDAI penalty filed that morning), TCS rises 9% on day 45 (results), NIFTY flat
d0 = dt.date(2025, 3, 3)
days = []
d = d0
while len(days) < 60:
    if d.weekday() < 5:
        days.append(str(d))
    d += dt.timedelta(days=1)
def series(jumps):
    out, c = {}, 100.0
    for i, k in enumerate(days):
        pc = c
        c = c * (1 + jumps.get(i, 0.0))
        out[k] = (pc, max(pc, c) * 1.002, min(pc, c) * 0.998, c, 1000.0 * (3 if i == 39 else 1))
    return out
DAY = {"PBFINTECH": series({40: -0.20, 36: -0.012, 37: -0.015, 38: -0.01, 39: -0.02}), "TCS": series({45: 0.09}), "INFY": series({}), "NIFTY 50": series({})}
syms = ["PBFINTECH", "TCS", "INFY"]
shocks, base, tot = C.find(syms, DAY, {})
check("find: 2 shocks (PBFINTECH ▼ -20%, TCS ▲ +9%)", sorted((x["sym"], x["side"]) for x in shocks) == [("PBFINTECH", -1), ("TCS", 1)])
pb = [x for x in shocks if x["sym"] == "PBFINTECH"][0]
check("the signs before PBFINTECH's fall: fell 5%+ in 5 days, volume 2x+", "fell 5%+ in the 5 days before" in pb["signs"] and "volume 2x+ the day before" in pb["signs"])
check("the next day / 5 days filled", pb["next"] is not None and pb["n5"] is not None)

D40 = dt.date.fromisoformat(days[40])
def getj(path):
    if "PBFINTECH" in path:
        return [{"symbol": "PBFINTECH", "desc": "Action(s) taken or orders passed", "attchmntText": "IRDAI has imposed a penalty of Rs 5 crore on Policybazaar Insurance Brokers",
                 "an_dt": D40.strftime("%d-%b-%Y") + " 08:10:00"},
                {"symbol": "PBFINTECH", "desc": "Action(s) taken or orders passed", "attchmntText": "IRDAI inspection observations and show cause notice received",
                 "an_dt": (D40 - dt.timedelta(days=20)).strftime("%d-%b-%Y") + " 18:00:00"}]
    if "TCS" in path:
        return [{"symbol": "TCS", "desc": "Bagging/Receiving of orders/contracts", "attchmntText": "TCS has secured an order worth Rs 2,000 crore from a European bank",
                 "an_dt": (dt.date.fromisoformat(days[45]) - dt.timedelta(days=10)).strftime("%d-%b-%Y") + " 17:00:00"}]
    return []
def get(url):
    if "EQUITY_L" in url:
        return "SYMBOL,NAME OF COMPANY\nPBFINTECH,PB Fintech Limited\nTCS,Tata Consultancy Services Limited\nINFY,Infosys Limited\n"
    if "news.google.com" in url and "Tata" in url:
        return "<item><title>TCS Q4 results: net profit jumps 12%, shares surge</title><link>x</link></item>"
    return ""
C.S.result_days = lambda s, R, BM, ds: [days[45]] if s == "TCS" else []
Cx = C.reasons(shocks, syms, DAY, getj=getj, get=get, pause=0, log=lambda m: None, stop=None)
r_pb, r_tcs = Cx["PBFINTECH:" + days[40]], Cx["TCS:" + days[45]]
check("PBFINTECH's fall -> REGULATOR from the NSE filing (IRDAI penalty)", r_pb["reason"] == "REGULATOR" and "IRDAI" in r_pb["line"] and r_pb["src"] == "NSE filing")
check("the IRDAI show-cause notice 20 days before is kept as the warning", len(r_pb["warn"]) == 1 and "show cause" in r_pb["warn"][0][2])
check("TCS's rise -> RESULTS", r_tcs["reason"] == "RESULTS")
check("a second run reads nothing again (cached)", json.dumps(C.reasons(shocks, syms, DAY, getj=lambda p: 1 / 0, get=get, pause=0, log=lambda m: None, stop=None), sort_keys=True) == json.dumps(Cx, sort_keys=True))
L, J = C.report(shocks, base, tot, Cx)
txt = "\n".join(L)
print(txt)
check("report: the falls by reason, the biggest falls, the warning filed first", "REGULATOR" in txt and "THE 15 BIGGEST FALLS" in txt and "A WARNING FILED FIRST" in txt)
check("report: UP as well - the rises by reason, the 15 biggest rises, the order filed 10 days before TCS's jump", "▲ UP SHOCKS" in txt and "THE 15 BIGGEST RISES" in txt
      and "GOOD NEWS FILED FIRST" in txt and "TCS +9.0% <-" in txt)
check("report: year by year, up and down", "YEAR BY YEAR" in txt and "2025  ▲    1  ▼    1" in txt)
check("circuits.json: per share and per reason", J["by_sym"]["PBFINTECH"][0]["reason"] == "REGULATOR" and J["by_reason"]["REGULATOR:-1"]["n"] == 1)
json.dump(J, open(W.HIST, "w"))
check("refine: an election-day fall (NIFTY -5.9%) blamed on a CEO appointment -> MARKET",
      C.refine({"reason": "MGMT", "line": "Asirvad MFI appoints Satish Nair as CEO", "nifty": -5.93, "side": -1, "news": []}, 300)[0] == "MARKET")
check("refine: a CEO appointment on a quiet day is not MGMT; a CEO quitting is", C.refine({"reason": "MGMT", "line": "X appoints new CEO", "nifty": 0.1, "side": -1,
      "news": []}, 1)[0] == "UNKNOWN" and C.refine({"reason": "MGMT", "line": "X CEO resigns with immediate effect", "nifty": 0.1, "side": -1, "news": []}, 1)[0] == "MGMT")
check("refine: a regulator fall stays REGULATOR even on a market day", C.refine({"reason": "REGULATOR", "line": "RBI bars", "nifty": -3, "side": -1}, 40)[0] == "REGULATOR")

# a 1:1 bonus (opens at half the price and stays) is not a crash
DB = {"BONUS": series({30: -0.5}), "NIFTY 50": DAY["NIFTY 50"]}
DB["BONUS"][days[30]] = (DB["BONUS"][days[30]][3],) + DB["BONUS"][days[30]][1:]          # it opened at the new price
check("a bonus / split day (opened -50% and stayed) is not counted as a shock", C.find(["BONUS"], DB, {})[0] == [])

# the year before from NSE's own daily files (Kite not there): TESTSYM's old prices were half (a 1:1 bonus since) -> joined at the seam
import io, zipfile, numpy as np, hist3y as Hh
os.makedirs(os.path.join(T, "day"), exist_ok=True)
t0 = [dt.datetime(2023, 1, 23 + i, tzinfo=C.IST).timestamp() for i in range(5)]
np.savez(os.path.join(T, "day", "TESTSYM.npz"), ts=np.array(t0), o=np.full(5, 200.0), h=np.full(5, 202.0), l=np.full(5, 198.0), c=np.full(5, 200.0), v=np.full(5, 1e5))
np.savez(os.path.join(T, "day", "NIFTY_50.npz"), ts=np.array(t0), o=np.full(5, 18000.0), h=np.full(5, 18100.0), l=np.full(5, 17900.0), c=np.full(5, 18000.0), v=np.zeros(5))
def get3(url):
    if "bhav.csv.zip" in url:
        b = io.BytesIO(); z = zipfile.ZipFile(b, "w")
        z.writestr("x.csv", "SYMBOL,SERIES,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,TOTTRDQTY\nTESTSYM,EQ,100,101,99,100,100,100,50000\nOTHER,EQ,5,5,5,5,5,5,1\n"); z.close()
        return b.getvalue()
    if "ind_close_all" in url:
        return b"Index Name,Index Date,Open Index Value,High Index Value,Low Index Value,Closing Index Value\nNifty 50,x,17900,18050,17850,18000\n"
    return None
C.extend_nse(["TESTSYM"], dt.date(2023, 1, 2), log=lambda m: None, get=get3)
a = np.load(os.path.join(T, "day", "TESTSYM.npz")); nf = np.load(os.path.join(T, "day", "NIFTY_50.npz"))
check("NSE files: TESTSYM taken back to 2 Jan 2023 (15 more days), the old prices put on today's scale (x2)",
      len(a["ts"]) == 20 and abs(float(a["c"][0]) - 200) < 1 and dt.datetime.fromtimestamp(float(a["ts"].min()), C.IST).date() == dt.date(2023, 1, 2))
check("NSE files: NIFTY 50 taken back too", len(nf["ts"]) == 20)

# ---- SHOCK WATCH
feed = {"q": []}
def get2(url):
    if "EQUITY_L" in url:
        return get(url)
    if "news.google.com" in url and "IRDAI" in url:
        return "".join("<item><title>%s</title><link>http://n/%d</link></item>" % (t, i) for i, t in enumerate(feed["q"]))
    return ""
SENT = []
W.run(SENT.append, get2, fo=syms)
check("the first run only remembers (nothing sent)", SENT == [])
feed["q"] = ["IRDAI issues show cause notice to Policybazaar over violations", "IRDAI releases annual report", "Infosys wins large deal in Europe",
             "Cochin Shipyard bags Rs 2,500 crore order from Indian Navy"]
allout = W.run(SENT.append, get2, fo=syms + ["COCHINSHIP"], now=dt.datetime(2026, 11, 11, 10, 5, tzinfo=W.IST))
for x in allout:
    print(x, "\n")
out = [x for x in allout if "PBFINTECH" in x]
up_big = [x for x in allout if "COCHINSHIP" in x]; up_small = [x for x in allout if "INFY" in x]
check("▲ a Rs 2,500 crore order -> ⚠️ SHOCK WATCH COCHINSHIP ▲ ORDER (rings)", len(up_big) == 1 and up_big[0].startswith("⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER"))
check("▲ a deal story with no size -> 📰 SHOCK WATCH INFY (quiet, News topic)", len(up_small) == 1 and up_small[0].startswith("📰 SHOCK WATCH · ▲ INFY ·"))
check("▼ PBFINTECH REGULATOR (the plain IRDAI report is not news)", len(out) == 1 and "▼ PBFINTECH · REGULATOR" in out[0] and len(allout) == 3)
check("it carries PBFINTECH's own past shock and the 3-year REGULATOR record", "own shocks since 2025: 1" in out[0] and "REGULATOR news behind 1 F&O shocks ▼ since 2025" in out[0])
check("a second pass: nothing again", W.run(None, get2, fo=syms + ["COCHINSHIP"]) == [])
m = W.matcher({"SBIN": ["SBI", "State Bank of India"], "HAL": ["HAL"]})
check("names: 'SBI' and 'HAL' only as words in capitals ('Halol', 'hal' are not HAL)", m("RBI fines SBI Rs 2 crore") == ["SBIN"] and m("plant at Halol shut") == [] and m("HAL bags order") == ["HAL"])
try:
    import alertword, tglanes
    check("⚠️ SHOCK WATCH rings in GIR Box Picks (▼ and the big ▲)", all(tglanes.lane(x) == "critical" and alertword.tier(x) != "read" for x in out + up_big))
    check("📰 SHOCK WATCH goes quiet to the News topic", tglanes.topic(up_small[0]) == "news" and alertword.tier(up_small[0]) == "read")
except Exception as ex:
    check("routing check (%s)" % ex, False)
shutil.rmtree(T)
print("P161 SHOCK DAYS TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P161TEST_PY
echo "   regwatch.py · p163test.py written"
echo "== 2. the test (made-up regulator pages, nothing sent)"
cd $D && python3 -m py_compile regwatch.py shockwatch.py p163test.py || { echo "   does not compile"; exit 1; }
if timeout 120 python3 p163test.py > /tmp/p163test.log 2>&1 && timeout 180 python3 p161test.py > /tmp/p161test.log 2>&1; then echo "   p163test.py + p161test.py passed"; else
  echo "   TEST FAILED - undone:"; grep -hE "FAIL|Error" /tmp/p163test.log /tmp/p161test.log | head -6 | sed 's/^/     /'
  for f in shockwatch.py p161test.py; do cp $D/$f.bak163 $D/$f 2>/dev/null; done; rm -f $D/regwatch.py; exit 1; fi
echo "== 3. which regulator pages answer from the server (nothing sent)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 400 python3 regwatch.py probe 2>&1 | sed 's/^/   /'
timeout 400 python3 regwatch.py > /dev/null 2>&1
echo "   (what is on the pages now is remembered - only new orders / notices are said from now on)"
cat > $U/gir-regwatch.service <<'UNIT'
[Unit]
Description=GIR REGULATOR WATCH (IRDAI / SEBI / RBI / CCI / USFDA / TRAI / ED pages)
[Service]
Type=oneshot
TimeoutStartSec=170
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 regwatch.py --send >> data/regwatch.log 2>&1'
UNIT
cat > $U/gir-regwatch.timer <<'UNIT'
[Unit]
Description=GIR REGULATOR WATCH every 2 minutes
[Timer]
OnCalendar=*-*-* *:1/2:20
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-regwatch.timer >/dev/null 2>&1 && echo "== 4. REGULATOR WATCH on: every 2 minutes, day and night -> GIR Box Picks"
echo
echo "PATCH 163 APPLIED. Send Claude a screenshot of section 3 - the pages that show 0 items or no answer get new addresses."
