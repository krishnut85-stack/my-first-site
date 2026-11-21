#!/bin/bash
# PATCH 126 - RESULTS AGAINST THE BROKERS' NUMBERS (on top of patch 125c). History and future.
#   The market moves on results against what the brokers expected, not against last year (Divi's: +64% YoY, but the
#   news was ~50% ABOVE Motilal Oswal's ₹754 cr). Free source: the brokers' published previews / polls in the news.
#   - FUTURE: every evening and morning, for results due in the next 7 days, the brokers' numbers are found and read
#     (data/expect.db). The results alert then says "52% ABOVE ESTIMATES"; the side follows a 10%+ surprise; 20%+ = 🚨
#   - HISTORY: every night 150 more share-quarters (the last 8 quarters of all F&O shares): the results from NSE, the
#     brokers' previews of the 3 weeks before, the move next day / 3 days later -> the study ("beat by 20%+: up next day
#     in N% of cases") which every alert quotes. About 2 weeks of nights to cover everything.
#   - the 08:30 recap: each result against the brokers + RESULTS DUE with what the brokers expect.
#   expect.py (new) · exchange.py, tglanes.py, home.html (exact anchors) · newsrecap.py (replaced) · gir-expect.timer (new).
#   Restarts gir-exchange, gir-intraday, gir-desk, gir-newsroom, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g126; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p126.sh now"; exit 1; fi
grep -q "patch 125c" $D/exchange.py 2>/dev/null || { echo "patch 125c is not installed yet - paste patch 125c first"; exit 1; }
[ -f $D/expect.py ] && { echo "patch 126 is already installed"; exit 1; }
F="exchange.py tglanes.py home.html newsrecap.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/expect.py $D/p126test.py; systemctl disable --now gir-expect.timer >/dev/null 2>&1; rm -f /etc/systemd/system/gir-expect.timer /etc/systemd/system/gir-expect.service; systemctl daemon-reload
         systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p126_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p126_patch.py - PATCH 126: the results alert against the BROKERS' numbers (expect.py).
  exchange.py: after the results are read, expect.vs_street() adds "vs the brokers: profit ₹1,127 cr against ₹741 cr expected
  → 52% ABOVE"; the side follows the surprise from 10%; 20%+ either way is 🚨 CRITICAL RESULTS; the head says "BEAT YoY · 52% ABOVE ESTIMATES"
  tglanes.py / home.html: a 10%+ surprise against the brokers goes to GIR Box Picks
Usage: python3 p126_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
STREET = '''{i}try:                                                 # patch 126: against the brokers' numbers
{i}    import expect
{i}    st_ = expect.vs_street(f["sym"], res, f["t_exch"])
{i}    if st_:
{i}        {line} += "\\n" + st_["line"]
{i}        f["street"] = st_["word"]
{i}        if st_["side"]:
{i}            f["side"] = st_["side"]
{i}        if st_["big"]:
{i}            f["big"] = True
{i}except Exception as ex:
{i}    log("expect %s: %s" % (f["sym"], str(ex)[:80]))
'''
EDITS = {
    "exchange.py": [
        ('''                    if s2:
                        f["side"] = s2
''', '''                    if s2:
                        f["side"] = s2
''' + STREET.format(i=" " * 20, line="res_line")),
        ('''            box(f, int(now - t_exch), line, market_open)                # patch 117: the numbers to Box Picks
''', STREET.format(i=" " * 12, line="line") + '''            box(f, int(now - t_exch), line, market_open)                # patch 117: the numbers to Box Picks
'''),
        ('''(" · %s%s" % ("BIG " if f.get("big") else "", f["verdict"])) if f.get("verdict") else ""''',
         '''((" · %s YoY · %s" % (f["verdict"], f["street"])) if f.get("street") else (" · %s%s" % ("BIG " if f.get("big") else "", f["verdict"]))) if f.get("verdict") else ""'''),
    ],
    "tglanes.py": [
        ('''        if re.search(r"· RESULTS · (BIG )?(BEAT|MISS)\\b", H2):''',
         '''        if re.search(r"· RESULTS · (BIG )?(BEAT|MISS)\\b", H2) or re.search(r"· RESULTS · .*\\b([1-9]\\d|\\d{3,})% (ABOVE|BELOW) ESTIMATES", H2):   # patch 126'''),
    ],
    "home.html": [
        ('''  if(/· RESULTS · (BIG )?(BEAT|MISS)\\b/.test(H)) return "critical";   /* patch 125b */''',
         '''  if(/· RESULTS · (BIG )?(BEAT|MISS)\\b/.test(H)) return "critical";   /* patch 125b */
  if(/· RESULTS · .*\\b([1-9]\\d|\\d{3,})% (ABOVE|BELOW) ESTIMATES/.test(H)) return "critical";   /* patch 126: a 10%+ surprise against the brokers */'''),
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
print("exchange.py: results against the brokers · tglanes.py + home.html: a 10%+ surprise to Box Picks")
PY_PATCH
cat > $W/expect.py <<'PY_EXPECT'
#!/usr/bin/env python3
"""expect.py - patch 126: WHAT THE BROKERS EXPECTED. The market moves on results against the brokers' numbers, not
against last year (Divi's 7 Nov: profit +64% YoY, but the real news was ~50% ABOVE Motilal Oswal's ₹754 cr).

  FUTURE   every evening (gir-expect.timer) for each F&O share with results in the next 7 days: the brokers' preview
           numbers are found in the news ("Q2 preview: profit seen at ₹754 cr - Motilal Oswal"), read by the AI reader
           and kept (data/expect.db). When the results come, the alert says "52% ABOVE ESTIMATES" and the side follows the
           surprise (beat by 10%+ -> CE, miss by 10%+ -> PE); 20%+ either way is 🚨 CRITICAL RESULTS.
  HISTORY  --history: for every F&O share, the last N quarters - the results from NSE, the brokers' previews from the
           news of the 3 weeks before, and what the share did next day / 3 days later (data/oistudy.db). --study then
           says how shares really reacted to a beat / a miss against the brokers - the alert quotes it.
  FREE SOURCE: published broker previews and polls in the news. Large companies are well covered, small ones less.
           A paid consensus feed can be added later through add_estimate() - nothing else changes.

  python3 expect.py --probe SYM          find and read the brokers' numbers for SYM's latest / next quarter (prints all)
  python3 expect.py --upcoming           the evening job: results due in the next 7 days
  python3 expect.py --history 8          the last 8 quarters of every F&O share (resumes; --max-reads N per run)
  python3 expect.py --study              how shares reacted to beats / misses against the brokers
  python3 expect.py --status
  python3 expect.py --nightly            what gir-expect.timer runs (07:45 the coming results · 22:15 also 150 history reads + the study)"""
import os, re, sys, json, time, html, sqlite3, statistics, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "data", "expect.db")
STUDY = os.path.join(BASE, "data", "expect_study.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
SURPRISE_SIDE, SURPRISE_BIG = 10.0, 20.0          # % against the brokers: a side from 10%, 🚨 CRITICAL from 20%
_GET = None                                        # tests put fakes here
_POST = None
_ASK = None
_N = {"asked": 0}                                  # AI reads made by this run


# ---------------------------------------------------------------- quarters
def qlabel(end):
    """the quarter that ENDED on date `end` -> "Q2FY27" (Indian fiscal year: Apr-Mar)"""
    q = {6: 1, 9: 2, 12: 3, 3: 4}.get(end.month)
    if q is None:
        q = (((end.month - 4) % 12) // 3) + 1
    fy = (end.year + (1 if end.month >= 4 else 0)) % 100
    return "Q%dFY%02d" % (q, fy)


def quarter_for_filing(d):
    """results filed on date d are for the last quarter that ended before it"""
    for back in range(0, 200):
        x = d - dt.timedelta(days=back + 1)
        if (x.month, x.day) in ((3, 31), (6, 30), (9, 30), (12, 31)):
            return qlabel(x), x
    return None, None


def q_words(q):
    """search words for a quarter: Q2FY27 -> ("Q2", "Q2FY27", "September quarter")"""
    n = int(q[1])
    month = {1: "June", 2: "September", 3: "December", 4: "March"}[n]
    return 'Q%d OR "Q%dFY%s" OR "%s quarter"' % (n, n, q[-2:], month)


# ---------------------------------------------------------------- the store
def db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    c = sqlite3.connect(DB, timeout=15)
    c.execute("create table if not exists est(sym text, q text, broker text, metric text, value_cr real, yoy_pct real, t_pub real, link text, src text,"
              " primary key(sym, q, broker, metric))")
    c.execute("create table if not exists done(sym text, q text, kind text, t real, n int, primary key(sym, q, kind))")
    c.execute("create table if not exists act(sym text, q text, t_filed real, pat real, rev real, pat_yoy real, rev_yoy real, verdict text, primary key(sym, q))")
    c.execute("create table if not exists cmp(sym text, q text, t real, surprise real, side int, big int, word text, line text, primary key(sym, q))")
    c.execute("create table if not exists react(sym text, q text, base real, d1 real, d3 real, intraday int, primary key(sym, q))")
    return c


def add_estimate(sym, q, broker, metric, value_cr=None, yoy_pct=None, t_pub=None, link="", src="news"):
    """one broker number (also the door for a paid consensus feed later: src="feed")"""
    c = db()
    c.execute("insert or replace into est values(?,?,?,?,?,?,?,?,?)", (sym, q, (broker or "?")[:60], metric, value_cr, yoy_pct, t_pub or time.time(), (link or "")[:300], src))
    c.commit(); c.close()


def consensus(sym, q, metric="pat"):
    """-> {"value": median ₹ cr or None, "yoy": median % or None, "n": brokers, "brokers": [(name, value, yoy)]} or None"""
    c = db()
    rows = c.execute("select broker, value_cr, yoy_pct from est where sym=? and q=? and metric=?", (sym, q, metric)).fetchall()
    c.close()
    if not rows:
        return None
    vals = [r[1] for r in rows if r[1]]
    if len(vals) >= 3:                                            # drop a number far from the rest (a misread unit, another company)
        m = statistics.median(vals)
        rows = [r for r in rows if not r[1] or 0.4 * m <= r[1] <= 2.5 * m]
        vals = [r[1] for r in rows if r[1]]
    yoys = [r[2] for r in rows if r[2] is not None]
    return {"value": round(statistics.median(vals), 1) if vals else None, "yoy": round(statistics.median(yoys), 1) if yoys else None,
            "n": len(rows), "brokers": [(r[0], r[1], r[2]) for r in rows]}


# ---------------------------------------------------------------- finding the brokers' numbers in the news
def _get(url):
    if _GET:
        return _GET(url)
    import requests
    return requests.get(url, headers=UA, timeout=(5, 10))


def _post(url, data):
    if _POST:
        return _POST(url, data)
    import requests
    return requests.post(url, data=data, headers=dict(UA, **{"Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"}), timeout=(5, 10))


def who(name, sym):
    """how the news names the company: "Divi's Laboratories Limited" -> ("Divi's Laboratories" OR "Divi's" OR DIVISLAB)"""
    short = re.sub(r"(?i)\b(limited|ltd\.?|corporation|corp\.?|company|co\.|\(india\)|india)\b", "", name or "").strip(" .,-")
    short = re.sub(r"\s+", " ", short)
    alts = []
    if short and short.upper() != sym:
        alts.append('"%s"' % short)
        w0 = short.split()[0]
        try:
            from engine2 import GENERIC_WORDS as G
        except Exception:
            G = {"tata", "bank", "india", "bajaj", "adani", "hdfc", "icici", "power", "steel", "state", "national", "indian", "united"}
        if len(short.split()) > 1 and len(w0) >= 4 and re.sub(r"'s$", "", w0.lower()) not in G:
            alts.append('"%s"' % w0)
    alts.append(sym)
    return "(" + " OR ".join(alts) + ")"


def previews(name, sym, q, before=None, days=21):
    """Google News: the preview / poll / estimate stories for this company and quarter -> [(t_pub, title, link)]"""
    from urllib.parse import quote
    words = '(preview OR estimate OR estimates OR expected OR expects OR poll OR "seen at" OR "likely to" OR brokerage)'
    if before:
        a = (before - dt.timedelta(days=days)).strftime("%Y-%m-%d")
        b = (before + dt.timedelta(days=1)).strftime("%Y-%m-%d")
        query = "%s (%s) %s after:%s before:%s" % (who(name, sym), q_words(q), words, a, b)
    else:
        query = "%s (%s) %s when:%dd" % (who(name, sym), q_words(q), words, days)
    r = _get("https://news.google.com/rss/search?q=%s&hl=en-IN&gl=IN&ceid=IN:en" % quote(query))
    if getattr(r, "status_code", 200) != 200:
        raise RuntimeError("Google News answered %s" % getattr(r, "status_code", "?"))   # not marked done: tried again next run
    out = []
    for m in re.finditer(r"<item>(.*?)</item>", getattr(r, "text", "") or "", re.S):
        it = m.group(1)
        t = re.search(r"<title>(.*?)</title>", it, re.S)
        l = re.search(r"<link>(.*?)</link>", it, re.S)
        p = re.search(r"<pubDate>(.*?)</pubDate>", it, re.S)
        if not t:
            continue
        title = html.unescape(re.sub(r"<!\[CDATA\[|\]\]>", "", t.group(1))).strip()
        try:
            tp = dt.datetime.strptime(p.group(1).strip()[:25], "%a, %d %b %Y %H:%M:%S").replace(tzinfo=dt.timezone.utc).timestamp() if p else 0
        except Exception:
            tp = 0
        if before and tp and tp > dt.datetime.combine(before, dt.time(23, 59), IST).timestamp():
            continue                                          # written after the results: not an estimate
        out.append((tp, title[:220], (l.group(1).strip() if l else "")))
    return out[:8]


def article_text(link):
    """the article's words (the Google link resolved to the publisher first); '' when it cannot be read"""
    try:
        url = link
        if "news.google.com" in link:
            import newsfresh
            url = newsfresh.google_real(link, _get, _post) or ""
        if not url.startswith("http"):
            return ""
        r = _get(url)
        t = getattr(r, "text", "") or ""
        t = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", t)
        t = html.unescape(re.sub(r"<[^>]+>", " ", t))
        t = re.sub(r"\s+", " ", t)
        i = max(0, t.lower().find("crore") - 1500)
        return t[i:i + 3500]
    except Exception:
        return ""


PROMPT = """Below are news items written BEFORE {name} ({sym}) announced its {q} results (quarter ended {qend}).
Find the brokerages' / analysts' ESTIMATES for {name}'s {q} numbers. Ignore actual reported numbers, other companies,
other quarters, and the company's own guidance.

{items}

Answer with JSON only: a list, one entry per broker and metric:
[{{"broker": "Motilal Oswal", "metric": "pat", "value_cr": 753.7, "yoy_pct": 17.5}}]
metric: "pat" (net profit), "rev" (revenue / net sales / NII for banks), "ebitda" (EBITDA / operating profit / PPOP).
value_cr in ₹ crore (convert from lakh / million / billion), null if only a growth % is given; yoy_pct null if not given.
broker: the brokerage name, or "poll" for a poll / consensus of several analysts. [] if none of the items has an estimate."""


def _ask(prompt):
    if _ASK:
        return _ASK(prompt)
    import llmread
    if not llmread.available():
        return None
    txt, _m = llmread.ask(prompt, max_tokens=900)
    return txt


def read_estimates(sym, name, q, qend, items, read_pages=True):
    """the AI reader on the preview stories -> [dict] (also stored)"""
    if not items:
        return []
    blocks = []
    for tp, title, link in items[:6]:
        body = article_text(link) if read_pages else ""
        blocks.append("- %s (%s)%s" % (title, dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %Y") if tp else "?", ("\n  " + body[:2500]) if body else ""))
    _N["asked"] += 1
    txt = _ask(PROMPT.format(name=name, sym=sym, q=q, qend=qend.strftime("%d %b %Y") if qend else "?", items="\n".join(blocks)))
    if not txt:
        return []
    m = re.search(r"\[.*\]", txt, re.S)
    try:
        got = json.loads(m.group(0)) if m else []
    except Exception:
        got = []
    out = []
    for e in got if isinstance(got, list) else []:
        if not isinstance(e, dict) or e.get("metric") not in ("pat", "rev", "ebitda"):
            continue
        v, y = e.get("value_cr"), e.get("yoy_pct")
        try:
            v = float(v) if v is not None else None
            y = float(y) if y is not None else None
        except Exception:
            continue
        if v is None and y is None:
            continue
        b = str(e.get("broker") or "?").strip()[:60]
        add_estimate(sym, q, b, e["metric"], v, y, items[0][0] if items else None, items[0][2] if items else "", "news")
        out.append({"broker": b, "metric": e["metric"], "value_cr": v, "yoy_pct": y})
    return out


def collect(sym, name, q, qend, before=None, days=21, force=False):
    """find + read the brokers' numbers for one share-quarter once (resumable). -> estimates found"""
    c = db()
    seen = c.execute("select n from done where sym=? and q=? and kind='est'", (sym, q)).fetchone()
    c.close()
    if seen and not force:
        return None
    try:
        items = previews(name, sym, q, before, days)
    except Exception as ex:
        print("  %-11s %s news: %s" % (sym, q, str(ex)[:60]))
        return None
    got = read_estimates(sym, name, q, qend, items) if items else []
    c = db()
    c.execute("insert or replace into done values(?,?,?,?,?)", (sym, q, "est", time.time(), len(got)))
    c.commit(); c.close()
    return got


# ---------------------------------------------------------------- the results against the brokers
def _cr(v, unit):
    if v is None:
        return None
    return v / 100.0 if unit == "lakh" else v if unit == "crore" else v / 10.0 if unit == "million" else v / 1e7


def _study_line(s):
    try:
        st = json.load(open(STUDY))
    except Exception:
        return ""
    for b in st.get("buckets", []):
        if b["lo"] <= s < b["hi"] and b.get("n", 0) >= 15:
            return " · history: %s - next day %s in %d%% of %d cases (avg %+.1f%%)" % (b["name"], "UP" if b["avg_d1"] >= 0 else "DOWN",
                                                                                   b["up_pct"] if b["avg_d1"] >= 0 else 100 - b["up_pct"], b["n"], b["avg_d1"])
    return ""


def vs_street(sym, res, t_filed):
    """a results reading (exchange.parse_xbrl / parse_results_pdf) against the brokers' numbers ->
    {"surprise", "side", "big", "word", "line"} or None when no broker number is known"""
    d = dt.datetime.fromtimestamp(t_filed, IST).date()
    q, _qe = quarter_for_filing(d)
    if not q:
        return None
    rd = res.get("read") or {}
    unit = rd.get("unit") or res.get("unit") or "?"
    pat = (res.get("pat") or {}).get("cur")
    pat_cr = _cr(pat, unit)
    pat_yoy = (rd.get("pat") or [None, None])[1]
    con = consensus(sym, q, "pat")
    if not con or pat_cr is None:
        return None
    if con["value"]:
        s = (pat_cr / con["value"] - 1) * 100 if con["value"] > 0 else None
        if s is None:
            return None
        names = ", ".join("%s %s" % (b, ("₹{:,.0f}".format(v) if v else "%+.0f%%" % y)) for b, v, y in con["brokers"][:3])
        line = "vs the brokers: profit ₹{:,.0f} cr against ₹{:,.0f} cr expected ({} - {}) → {:.0f}% {}".format(
            pat_cr, con["value"], "%d broker%s" % (con["n"], "s" if con["n"] > 1 else ""), names, abs(s), "ABOVE" if s >= 0 else "BELOW")
    elif con["yoy"] is not None and pat_yoy is not None:
        s = pat_yoy - con["yoy"]                                 # only growth was expected: the gap in growth points
        line = "vs the brokers: profit %+.0f%% YoY against %+.0f%% expected (%d) → %.0f points %s" % (pat_yoy, con["yoy"], con["n"], abs(s), "ABOVE" if s >= 0 else "BELOW")
    else:
        return None
    side = 1 if s >= SURPRISE_SIDE else -1 if s <= -SURPRISE_SIDE else 0
    word = ("%.0f%% ABOVE ESTIMATES" % s) if s >= 5 else ("%.0f%% BELOW ESTIMATES" % -s) if s <= -5 else "IN LINE WITH ESTIMATES"
    out = {"q": q, "surprise": round(s, 1), "side": side, "big": abs(s) >= SURPRISE_BIG, "word": word, "line": line + _study_line(s)}
    try:
        c = db()
        c.execute("insert or replace into cmp values(?,?,?,?,?,?,?,?)", (sym, q, time.time(), out["surprise"], side, int(out["big"]), word, out["line"]))
        c.commit(); c.close()
    except Exception:
        pass
    return out


def last_cmp(sym, since=0):
    """the stored comparison for sym's latest results (for the recap / the page)"""
    try:
        c = db()
        r = c.execute("select q, surprise, side, big, word, line from cmp where sym=? and t>=? order by t desc limit 1", (sym, since)).fetchone()
        c.close()
        return dict(zip(("q", "surprise", "side", "big", "word", "line"), r)) if r else None
    except Exception:
        return None


def expected_line(sym, when=None):
    """for results still to come: 'brokers expect profit ₹1,400 cr (+25% YoY) · 3 brokers' or ''"""
    q, _qe = quarter_for_filing(when or dt.datetime.now(IST).date())
    con = consensus(sym, q, "pat") if q else None
    if not con:
        return ""
    v = ("₹{:,.0f} cr".format(con["value"]) if con["value"] else "")
    y = ("%+.0f%% YoY" % con["yoy"]) if con["yoy"] is not None else ""
    return "brokers expect %s profit %s%s · %d broker%s" % (q, v, (" (%s)" % y) if (v and y) else y, con["n"], "s" if con["n"] > 1 else "")


# ---------------------------------------------------------------- the jobs
def fo_names():
    try:
        import newsroom
        return {s: n for s, n, _l in newsroom.fo_names()}
    except Exception:
        return {}


def upcoming(days=7, now=None):
    """the evening job: every F&O share with results in the next `days` -> its brokers' numbers (once per quarter)"""
    now = now or dt.datetime.now(IST)
    names = fo_names()
    rows = []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        rows = c.execute("select sym, min(d) from results_cal where d>=? and d<=? group by sym", (str(now.date()), str(now.date() + dt.timedelta(days=days)))).fetchall()
        c.close()
    except Exception as ex:
        print("results calendar: %s" % str(ex)[:80])
    n = 0
    for sym, d in rows:
        if names and sym not in names:
            continue
        d_ = dt.datetime.strptime(d, "%Y-%m-%d").date()
        q, qe = quarter_for_filing(d_)
        got = collect(sym, names.get(sym, sym), q, qe, None, 28)
        if got is not None:
            n += 1
            print("  %-11s %s results %s · %s" % (sym, q, d, expected_line(sym, d_) or "no broker number found"))
            time.sleep(2)
    return n


def nse_history(sym, quarters):
    """NSE's list of the share's quarterly results -> [(t_filed, entry)] newest first, `quarters` of them"""
    import exchange
    t0 = dt.datetime.now(IST) - dt.timedelta(days=95 * quarters + 30)
    data = exchange.nse_json("/api/corporates-financial-results?index=equities&period=Quarterly&symbol=%s&from_date=%s&to_date=%s" % (
        sym, t0.strftime("%d-%m-%Y"), dt.datetime.now(IST).strftime("%d-%m-%Y")))
    rows = [e for e in (data if isinstance(data, list) else data.get("data", [])) if (e.get("symbol") or "").upper() == sym]
    out, seen = [], set()
    for e in sorted(rows, key=lambda e: exchange.parse_t(e.get("exchdisstime") or e.get("broadCastDate") or e.get("filingDate")) or 0, reverse=True):
        t = exchange.parse_t(e.get("exchdisstime") or e.get("broadCastDate") or e.get("filingDate"))
        if not t:
            continue
        q, _qe = quarter_for_filing(dt.datetime.fromtimestamp(t, IST).date())
        if q in seen:
            continue
        seen.add(q)
        out.append((t, e))
    return out[:quarters]


def reaction(sym, t_filed, con=None):
    """the share's move after the results (daily closes, data/oistudy.db): (base close, next-day %, 3-day %, filed in market hours?)"""
    own = con is None
    con = con or sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "data", "oistudy.db"), uri=True, timeout=5)
    try:
        rows = con.execute("select d, spot from day where sym=? and spot>0 order by d", (sym,)).fetchall()
    finally:
        if own:
            con.close()
    if not rows:
        return None
    t = dt.datetime.fromtimestamp(t_filed, IST)
    hm = t.strftime("%H:%M")
    d0 = str(t.date())
    after_close = hm >= "15:30"
    before = [r for r in rows if (r[0] <= d0 if after_close else r[0] < d0)]
    later = [r for r in rows if (r[0] > d0 if after_close else r[0] >= d0)]
    if not before or not later:
        return None
    base = before[-1][1]
    d1 = (later[0][1] / base - 1) * 100
    d3 = (later[min(2, len(later) - 1)][1] / base - 1) * 100
    return round(base, 2), round(d1, 2), round(d3, 2), int("09:15" <= hm < "15:30" and t.weekday() < 5)


def history(quarters=8, max_reads=250, only=None):
    """the past: for every F&O share x quarter - NSE's results, the brokers' previews of the 3 weeks before, the reaction"""
    import exchange
    names = fo_names()
    syms = [only] if only else sorted(names)
    reads, c = 0, db()
    for sym in syms:
        if not only and c.execute("select count(*) from done where sym=? and kind='est'", (sym,)).fetchone()[0] >= quarters:
            continue                                          # this share's quarters are all searched
        try:
            hist = nse_history(sym, quarters)
        except Exception as ex:
            print("  %-11s NSE: %s" % (sym, str(ex)[:60])); time.sleep(3); continue
        for t, e in hist:
            d = dt.datetime.fromtimestamp(t, IST).date()
            q, qe = quarter_for_filing(d)
            if not c.execute("select 1 from act where sym=? and q=?", (sym, q)).fetchone() and e.get("xbrl"):
                try:
                    res = exchange.parse_xbrl(e["xbrl"])
                    v, side, line = exchange.judge(res)
                    rd = res.get("read") or {}
                    c.execute("insert or replace into act values(?,?,?,?,?,?,?,?)", (sym, q, t, _cr((res.get("pat") or {}).get("cur"), rd.get("unit") or res.get("unit")),
                                                                                    _cr((res.get("rev") or {}).get("cur"), rd.get("unit") or res.get("unit")),
                                                                                    (rd.get("pat") or [None, None])[1], (rd.get("rev") or [None, None])[1], v))
                    c.commit()
                except Exception as ex:
                    print("  %-11s %s xbrl: %s" % (sym, q, str(ex)[:60]))
            if not c.execute("select 1 from react where sym=? and q=?", (sym, q)).fetchone():
                r = reaction(sym, t)
                if r:
                    c.execute("insert or replace into react values(?,?,?,?,?,?)", (sym, q) + r); c.commit()
            if reads >= max_reads:
                continue
            a0 = _N["asked"]
            got = collect(sym, names.get(sym, sym), q, qe, before=d, days=21)
            if got is not None:
                reads += _N["asked"] - a0
                time.sleep(2)
        print("  %-11s %d quarters · reads so far %d" % (sym, len(hist), reads))
        if reads >= max_reads:
            print("the read limit for this run (%d) is reached - the next run continues where this one stopped" % max_reads)
            break
    c.close()
    return reads


BUCKETS = [("missed by 20%+", -1e9, -20), ("missed by 10-20%", -20, -10), ("missed by 5-10%", -10, -5), ("in line (within 5%)", -5, 5),
           ("beat by 5-10%", 5, 10), ("beat by 10-20%", 10, 20), ("beat by 20%+", 20, 1e9)]


def study():
    """how shares reacted to a beat / a miss against the brokers (and, side by side, against last year)"""
    c = db()
    rows = c.execute("select a.sym, a.q, a.pat, a.pat_yoy, a.verdict, r.d1, r.d3 from act a join react r on a.sym=r.sym and a.q=r.q").fetchall()
    out = {"buckets": [], "yoy": [], "n": 0, "t": time.time()}
    pts = []
    for sym, q, pat, pat_yoy, verdict, d1, d3 in rows:
        con = consensus(sym, q, "pat")
        if not con:
            continue
        if con["value"] and pat:
            s = (pat / con["value"] - 1) * 100
        elif con["yoy"] is not None and pat_yoy is not None:
            s = pat_yoy - con["yoy"]
        else:
            continue
        pts.append((s, d1, d3, verdict))
    c.close()
    out["n"] = len(pts)
    for name, lo, hi in BUCKETS:
        b = [p for p in pts if lo <= p[0] < hi]
        if b:
            out["buckets"].append({"name": name, "lo": lo, "hi": hi, "n": len(b), "up_pct": round(100.0 * sum(1 for p in b if p[1] > 0) / len(b)),
                                   "avg_d1": round(sum(p[1] for p in b) / len(b), 2), "avg_d3": round(sum(p[2] for p in b) / len(b), 2)})
    for v in ("BEAT", "IN LINE", "MISS"):
        b = [p for p in pts if p[3] == v]
        if b:
            out["yoy"].append({"name": "%s vs last year" % v, "n": len(b), "up_pct": round(100.0 * sum(1 for p in b if p[1] > 0) / len(b)),
                               "avg_d1": round(sum(p[1] for p in b) / len(b), 2)})
    os.makedirs(os.path.dirname(STUDY), exist_ok=True)
    json.dump(out, open(STUDY, "w"), indent=1)
    return out


def study_text(st):
    L = ["THE RESULTS AGAINST THE BROKERS - how the share moved the next day (%d results with a broker number)" % st["n"]]
    for b in st["buckets"]:
        L.append("  %-22s %4d cases · up next day %3d%% · avg next day %+.1f%% · 3 days %+.1f%%" % (b["name"], b["n"], b["up_pct"], b["avg_d1"], b["avg_d3"]))
    L.append("  and against LAST YEAR only (what GIR used before):")
    for b in st["yoy"]:
        L.append("  %-22s %4d cases · up next day %3d%% · avg next day %+.1f%%" % (b["name"], b["n"], b["up_pct"], b["avg_d1"]))
    return "\n".join(L)


def status():
    c = db()
    r = c.execute("select (select count(*) from est), (select count(distinct sym||q) from est), (select count(*) from done), (select count(*) from act),"
                  " (select count(*) from react), (select count(*) from cmp)").fetchone()
    c.close()
    return "broker numbers %d (for %d share-quarters) · share-quarters searched %d · results %d · reactions %d · live comparisons %d" % r


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--probe" in a:
        sym = a[a.index("--probe") + 1].upper()
        names = fo_names()
        today = dt.datetime.now(IST).date()
        try:
            hist = nse_history(sym, 1)
        except Exception as ex:
            hist = []; print("NSE: %s" % str(ex)[:80])
        d = dt.datetime.fromtimestamp(hist[0][0], IST).date() if hist else today
        q, qe = quarter_for_filing(d)
        print("%s (%s) · %s · results %s" % (sym, names.get(sym, sym), q, d))
        try:
            items = previews(names.get(sym, sym), sym, q, d if hist else None, 28)
        except Exception as ex:
            items = []; print("  the news search failed: %s" % str(ex)[:120])
        for tp, t, l in items:
            print("  news %s  %s" % (dt.datetime.fromtimestamp(tp, IST).strftime("%d %b") if tp else "?", t[:110]))
        got = read_estimates(sym, names.get(sym, sym), q, qe, items)
        for e in got:
            print("  READ %-28s %-6s ₹%s cr  %s" % (e["broker"], e["metric"], e["value_cr"], ("%+.1f%% YoY" % e["yoy_pct"]) if e["yoy_pct"] is not None else ""))
        print("  " + (expected_line(sym, d) or "no broker number found"))
        if hist and hist[0][1].get("xbrl"):
            import exchange
            res = exchange.parse_xbrl(hist[0][1]["xbrl"]); exchange.judge(res)
            r = vs_street(sym, res, hist[0][0])
            print("  " + (r["line"] if r else "no comparison"))
    elif "--nightly" in a:                                     # gir-expect.timer: 07:45 the coming results; 22:15 also the history + the study
        print(dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M"), "results due in the next 7 days - the brokers' numbers:")
        upcoming()
        if dt.datetime.now(IST).hour >= 20:
            history(8, int(os.environ.get("GIR_EXPECT_READS", "150")))
            print(study_text(study()))
        print(status())
    elif "--upcoming" in a:
        print("results due in the next 7 days - the brokers' numbers:")
        upcoming()
        print(status())
    elif "--history" in a:
        i = a.index("--history")
        nq = int(a[i + 1]) if len(a) > i + 1 and a[i + 1].isdigit() else 8
        mr = int(a[a.index("--max-reads") + 1]) if "--max-reads" in a else 250
        history(nq, mr, a[a.index("--only") + 1].upper() if "--only" in a else None)
        print(status())
    elif "--study" in a:
        print(study_text(study()))
    elif "--status" in a:
        print(status())
    else:
        print(__doc__)
PY_EXPECT
cat > $W/newsrecap.py <<'PY_RECAP'
#!/usr/bin/env python3
"""newsrecap.py - patch 125: 🗞 THE MORNING NEWS RECAP - one PDF page to "GIR Moves & News" every day at 08:30 IST.

  THE MORNING READ   three lines from the news reader: what an F&O trader must know before 09:15
  RESULTS            every F&O company's results since the last close, BIG BEAT / BIG MISS first, bullish ▲ or bearish ▼
                     with the numbers behind it (patch 125b) - and against the BROKERS' numbers (patch 126)
  RESULTS DUE        today's and tomorrow's results with what the brokers expect (patch 126)
  OVERNIGHT          every news line GIR sent after the last close (15:30): 🚨 critical first, then company news, filings
  MARKET & GLOBAL    the top market / policy / global headlines of the night
  YESTERDAY'S NEWS → THE CLOSE   the session's news lines and what the share did by the close (✔ the side was right)
Only news GIR already checked and sent (old news is held by newsfresh, never in the recap). The PDF is kept in
data/recap/. gir-recap.timer runs it.
  python3 newsrecap.py --send     build and send now          python3 newsrecap.py --pdf    build only (prints the path)"""
import os, re, sys, json, time, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(BASE, "data", "recap")
FONTS = ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
NEWS_KINDS = ("📰", "🚨", "📄", "🏛", "⚡")
TAGS = ("🔴", "🟠", "📌")


def prev_session(now):
    """the last weekday before today (holidays aside) -> its date"""
    d = now.date() - dt.timedelta(days=1)
    while d.weekday() >= 5:
        d -= dt.timedelta(days=1)
    return d


def _parse(text):
    """an alert's text -> (head, headline, reader's reason, link)"""
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return "", "", "", ""
    head = L[0]
    if head.startswith("🔔 OPENING") and len(L) > 1:
        L = L[1:]; head = L[0]
    body = [x for x in L[1:] if not x.startswith(TAGS)]
    hl = next((x for x in body if not x.startswith(("the reader", "quick read", "share price", "no clear", "http", "also names", "watch:", "NIFTY", "why it matters", "⚠"))), head)
    rs = next((x for x in body if x.startswith("the reader")), "")
    m = re.match(r"the reader \([^)]*\):\s*(.*?)\s*·\s*(CRITICAL|IMPORTANT|MINOR)", rs)
    reason = m.group(1) if m else ""
    link = next((x.strip() for x in body if x.startswith("http")), "")
    return head, hl, reason, link


def _level(kind, head):
    return "critical" if "CRITICAL" in head else "minor" if kind == "📄" else "market" if (kind == "🏛" or " MARKET " in head) else "important"


def _key(sym, h):
    w = re.findall(r"[a-z0-9]+", h.lower())
    return sym + ":" + " ".join(w[:7])


def results_since(hours):
    """{sym: exchange.results_read(...)} - the results GIR read off the exchange in the last `hours`"""
    import exchange
    return exchange.results_map(hours)


def street(sym, since):
    """patch 126: the results against the brokers' numbers (expect.py), or None"""
    try:
        import expect
        return expect.last_cmp(sym, since)
    except Exception:
        return None


def due(now):
    """patch 126: F&O results due today and tomorrow -> [(date, sym, what the brokers expect)]"""
    out = []
    try:
        import expect
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        fo = {r[0] for r in c.execute("select sym from fo_list")}
        d1 = now.date() + dt.timedelta(days=1 if now.weekday() < 4 else 7 - now.weekday())
        for d, sym in c.execute("select d, sym from results_cal where d>=? and d<=? order by d, sym", (str(now.date()), str(d1))):
            if not fo or sym in fo:
                out.append((d, sym, expect.expected_line(sym, dt.datetime.strptime(d, "%Y-%m-%d").date())))
        c.close()
    except Exception as ex:
        print("recap due: %s" % str(ex)[:80])
    return out


def gather(now=None, db=None):
    """-> {"since", "prev", "overnight": [...], "session": [...], "market": [...], "reaction": [...], "held": n}"""
    now = now or dt.datetime.now(IST)
    prev = prev_session(now)
    t_close = dt.datetime.combine(prev, dt.time(15, 30), IST)
    t_open = dt.datetime.combine(prev, dt.time(9, 0), IST)
    out = {"now": now, "prev": prev, "since": t_close, "overnight": [], "session": [], "market": [], "reaction": [], "held": 0, "results": [], "due": due(now)}
    try:                                                         # patch 125b: the results since the last close (not yet traded)
        for sym, r in (results_since(max(1.0, (now - t_close).total_seconds() / 3600.0)) or {}).items():
            if not r or float(r.get("t_exch") or 0) < t_close.timestamp():
                continue
            st_ = street(sym, float(r["t_exch"]) - 3600)
            out["results"].append({"s": sym, "v": r.get("verdict") or "", "side": int((st_ or {}).get("side") or r.get("side") or 0),
                                   "big": bool((r.get("read") or {}).get("big")) or bool((st_ or {}).get("big")), "street": (st_ or {}).get("word") or "",
                                   "line": (r.get("line") or "") + (("\n" + st_["line"]) if st_ else ""), "at": dt.datetime.fromtimestamp(float(r["t_exch"]), IST), "check": bool(r.get("unverified"))})
        out["results"].sort(key=lambda x: (not x["big"], x["side"] == 0, x["v"] in ("NUMBERS NOT READ", "XBRL NOT UP YET"), -x["at"].timestamp()))
    except Exception as ex:
        print("recap results: %s" % str(ex)[:80])
    seen = set()
    try:
        c = sqlite3.connect(db or os.path.join(BASE, "tomorrow.db"), timeout=10)
        rows = c.execute("select day, t, kind, sym, side, text from alerts where day>=? order by day, t", (str(prev),)).fetchall()
        for day, t, kind, sym, side, text in rows:
            if kind not in NEWS_KINDS:
                continue
            head, hl, reason, link = _parse(text)
            if (kind == "🚨" and "CRITICAL" not in head) or (kind == "⚡" and "NEWS SHOCK" not in head) or "NOT SENT" in (text or ""):
                continue
            try:
                at = dt.datetime.strptime(day + " " + t[:8], "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
            except Exception:
                continue
            if at < t_open or at > now:
                continue
            k = _key(sym or "MARKET", hl)
            if k in seen:
                continue
            seen.add(k)
            lv = _level(kind, head)
            it = {"at": at, "s": sym or "MARKET", "side": side or "", "lvl": lv, "h": hl, "why": reason, "link": link}
            if lv == "market":
                out["market"].append(it)
            elif at >= t_close:
                out["overnight"].append(it)
            else:
                out["session"].append(it)
        try:
            for r in c.execute("select t, sym, side, lvl, head, p0, pc, nc from news_react where day=? and p0 is not null and pc is not null", (str(prev),)).fetchall():
                t, sym, side, lvl, head, p0, pc, nc = r
                mc = round((pc / p0 - 1) * 100, 2) if p0 and pc else None
                sg = 1 if side == "CE" else -1 if side == "PE" else 0
                out["reaction"].append({"t": t[:5], "s": sym, "side": side or "", "lvl": lvl, "h": head, "mc": mc,
                                        "right": None if (not sg or mc is None) else (mc * sg >= 0.5)})
        except Exception:
            pass
        c.close()
    except Exception as ex:
        print("recap alerts: %s" % str(ex)[:80])
    try:                                                         # the market headlines GIR kept (scored, trusted) but did not send
        j = json.load(open(os.path.join(BASE, "data", "macro.json")))
        for x in sorted(j.get("items") or [], key=lambda x: -(x.get("score") or 0)):
            at = dt.datetime.fromtimestamp(float(x.get("t") or 0), IST)
            if at < t_close or at > now or (x.get("score") or 0) < 4:
                continue
            k = _key("MARKET", x.get("h") or "")
            if k in seen:
                continue
            seen.add(k)
            out["market"].append({"at": at, "s": "MARKET", "side": "CE" if x.get("side", 0) > 0 else "PE" if x.get("side", 0) < 0 else "", "lvl": "market",
                                  "h": x.get("h") or "", "why": x.get("why") or "", "link": x.get("link") or "", "src": x.get("src") or ""})
    except Exception:
        pass
    try:
        held = json.load(open(os.path.join(BASE, "data", "news_held.json")))
        out["held"] = sum(1 for x in held if x.get("at", "") >= t_close.strftime("%Y-%m-%d %H:%M:%S"))
    except Exception:
        pass
    rank = {"critical": 0, "important": 1, "minor": 2, "market": 3}
    out["overnight"].sort(key=lambda x: (rank.get(x["lvl"], 9), -x["at"].timestamp()))
    out["session"].sort(key=lambda x: (rank.get(x["lvl"], 9), -x["at"].timestamp()))
    out["market"].sort(key=lambda x: -x["at"].timestamp())
    out["reaction"].sort(key=lambda x: -abs(x["mc"] or 0))
    return out


def morning_read(g):
    """three lines from the news reader (the model), or [] when it is not there"""
    try:
        import llmread
        if not llmread.available():
            return []
        items = g["overnight"][:25] + g["market"][:10]
        res_ = "\n".join("- RESULTS %s %s %s: %s" % (x["s"], ("BIG " if x["big"] else "") + x["v"], x.get("street") or "", x["line"][:260].replace("\n", " · ")) for x in g.get("results", [])[:12])
        res_ += "".join("\n- DUE %s %s: %s" % (d, sm, ex or "no broker number") for d, sm, ex in g.get("due", [])[:12])
        if not items and not res_:
            return []
        lines = "\n".join("- %s %s %s: %s" % (x["at"].strftime("%a %H:%M"), x["s"], {"CE": "UP", "PE": "DOWN"}.get(x["side"], ""), x["h"]) for x in items) + ("\n" + res_ if res_ else "")
        p = ("You are the senior news reader on an Indian F&O desk. It is %s, before the 09:15 open. These are the news lines since "
             "yesterday's close:\n%s\n\nWrite exactly 3 short lines (max 22 words each) for a trader: what matters most at the open "
             "today, naming the shares and UP / DOWN. No intro, no bullets symbols, plain text, one item per line.") % (g["now"].strftime("%a %d %b %H:%M"), lines)
        txt, _m = llmread.ask(p, max_tokens=300)
        return [re.sub(r"^[\-\*\d\.\)\s]+", "", x).strip() for x in (txt or "").split("\n") if x.strip()][:3]
    except Exception as ex:
        print("recap morning read: %s" % str(ex)[:80])
        return []


def build_pdf(g, path, read=None, caps=(24, 10, 10, 10), n_res=14, n_due=16):
    """one A4 page; when it does not fit, fewer rows (never a second page). -> (path, rows shown)"""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    F, FB = "Helvetica", "Helvetica-Bold"
    if all(os.path.exists(f) for f in FONTS):
        try:
            pdfmetrics.registerFont(TTFont("GirSans", FONTS[0])); pdfmetrics.registerFont(TTFont("GirSans-B", FONTS[1]))
            pdfmetrics.registerFontFamily("GirSans", normal="GirSans", bold="GirSans-B", italic="GirSans", boldItalic="GirSans-B")
            F, FB = "GirSans", "GirSans-B"
        except Exception:
            pass
    uni = F == "GirSans"
    esc = lambda s: (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") if uni else \
        (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("₹", "Rs ").encode("latin-1", "ignore").decode("latin-1")
    UP, DN, AM, DIM, INK, RED = colors.HexColor("#0a8a3a"), colors.HexColor("#c62828"), colors.HexColor("#b26a00"), colors.HexColor("#6b7280"), colors.HexColor("#111827"), colors.HexColor("#c62828")
    st = lambda size=7.6, bold=False, col=INK, lead=None: ParagraphStyle("x", fontName=FB if bold else F, fontSize=size, leading=lead or size * 1.22, textColor=col)
    arrow = lambda side: ('<font color="#0a8a3a">%s</font>' % ("▲" if uni else "+")) if side == "CE" else ('<font color="#c62828">%s</font>' % ("▼" if uni else "-")) if side == "PE" else ('<font color="#6b7280">·</font>')
    lvl_word = {"critical": '<font color="#c62828"><b>CRITICAL</b></font>', "important": "news", "minor": '<font color="#6b7280">minor</font>', "market": "market"}

    def news_table(rows, show_day):
        data = []
        for x in rows:
            when = x["at"].strftime("%a %H:%M" if show_day else "%H:%M")
            why = (" — " + esc(x["why"][:110])) if x.get("why") else ""
            data.append([Paragraph(when, st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow(x["side"])), st(7.6)),
                         Paragraph(lvl_word.get(x["lvl"], ""), st(6.8)), Paragraph(esc(x["h"][:170]) + '<font color="#6b7280">%s</font>' % why, st(7.4))])
        t = Table(data, colWidths=[46, 76, 50, 359])
        t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                               ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
        return t

    def section(title, sub):
        return Paragraph('<font color="#b26a00"><b>%s</b></font> <font color="#6b7280" size="7">%s</font>' % (esc(title), esc(sub)), st(9.5, lead=13))

    n_on, n_mk, n_rx, n_se = caps
    for _try in range(8):
        story = []
        now = g["now"]
        crit = [x for x in g["overnight"] if x["lvl"] == "critical"]
        hdr = Table([[Paragraph('<font color="#ffb000"><b>GIR</b></font> <font color="#ffffff"><b>MORNING NEWS RECAP</b></font>', st(13, col=colors.white, lead=16)),
                      Paragraph('<font color="#ffffff">%s · %s IST</font><br/><font color="#9ca3af">news since %s close · %d overnight · %d critical · %d old stories held back</font>' % (
                          esc(now.strftime("%a %d %b %Y")), now.strftime("%H:%M"), esc(g["prev"].strftime("%a %d %b")), len(g["overnight"]), len(crit), g["held"]), st(7.6, col=colors.white))]],
                    colWidths=[270, 261])
        hdr.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#0b0d11")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                                 ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6), ("LEFTPADDING", (0, 0), (-1, -1), 8)]))
        story += [hdr, Spacer(1, 5)]
        if read:
            box = Table([[Paragraph("<b>THE MORNING READ</b><br/>" + "<br/>".join("• " + esc(x) for x in read), st(8.2, lead=11))]], colWidths=[531])
            box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#fff7e6")), ("BOX", (0, 0), (-1, -1), 0.6, AM),
                                     ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
            story += [box, Spacer(1, 5)]
        rs = g.get("results", [])[:n_res]                           # patch 125b: RESULTS first - the market has not traded them yet
        if g.get("results"):
            nb = sum(1 for x in g["results"] if x["big"])
            story.append(section("RESULTS · since the %s close" % g["prev"].strftime("%a"), "%d companies%s · not traded yet - the move comes at 09:15" % (
                len(g["results"]), (" · %d BIG" % nb) if nb else "")))
            vcol = lambda x: "#0a8a3a" if x["side"] > 0 else "#c62828" if x["side"] < 0 else "#6b7280"
            data = [[Paragraph(x["at"].strftime("%a %H:%M"), st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow("CE" if x["side"] > 0 else "PE" if x["side"] < 0 else "")), st(7.6)),
                     Paragraph('<font color="%s">%s%s%s</font>' % (vcol(x), "<b>BIG %s</b>" % esc(x["v"]) if x["big"] else esc(x["v"]).replace("NUMBERS NOT READ", "not read"),
                                                                   ("<br/><b>%s</b>" % esc(x["street"].replace(" ESTIMATES", " EST.").replace("IN LINE WITH EST.", "AS EXPECTED"))) if x.get("street") else "",
                                                                   "<br/>(check)" if x["check"] else ""), st(7, lead=8.4)),
                     Paragraph(esc(re.sub(r"\s*\((consolidated|standalone)[^)]*\)", "", x["line"])[:480]).replace("\n", "<br/>"), st(7.2))] for x in rs]
            t = Table(data, colWidths=[46, 76, 50, 359])
            t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                   ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]
                                  + [("BACKGROUND", (0, i), (-1, i), colors.HexColor("#eefaf1" if x["side"] > 0 else "#fdeeee")) for i, x in enumerate(rs) if x["big"]]))
            story += [t, Spacer(1, 5)]
        if g.get("due"):                                           # patch 126: what the brokers expect from today's / tomorrow's results
            story.append(section("RESULTS DUE · what the brokers expect", "%d F&O companies" % len(g["due"])))
            rows_ = [[Paragraph(esc(dt.datetime.strptime(d, "%Y-%m-%d").strftime("%a %d")), st(7, col=DIM)), Paragraph("<b>%s</b>" % esc(sm), st(7.6)),
                      Paragraph(esc(ex) if ex else '<font color="#6b7280">no broker number found yet</font>', st(7.2))] for d, sm, ex in g["due"][:n_due]]
            t2 = Table(rows_, colWidths=[46, 76, 409])
            t2.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                    ("TOPPADDING", (0, 0), (-1, -1), 1.2), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.2), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
            story += [t2, Spacer(1, 5)]
        on = g["overnight"][:n_on]
        story.append(section("OVERNIGHT · after the %s close" % g["prev"].strftime("%a"), "%d lines%s" % (len(g["overnight"]), (" · top %d shown" % len(on)) if len(on) < len(g["overnight"]) else "")))
        story.append(news_table(on, True) if on else Paragraph("no company news after the close", st(7.4, col=DIM)))
        story.append(Spacer(1, 5))
        mk = g["market"][:n_mk]
        story.append(section("MARKET & GLOBAL", "policy · RBI · SEBI · global · crude · rupee"))
        story.append(news_table(mk, True) if mk else Paragraph("no market headline of weight", st(7.4, col=DIM)))
        story.append(Spacer(1, 5))
        rx = g["reaction"][:n_rx]
        rt = [x for x in g["reaction"] if x["right"] is not None]
        story.append(section("YESTERDAY'S NEWS → THE CLOSE", "%s · the reader's side right by the close: %d of %d" % (g["prev"].strftime("%a %d %b"), sum(1 for x in rt if x["right"]), len(rt))))
        if rx:
            data = [[Paragraph(esc(x["t"]), st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow(x["side"])), st(7.6)),
                     Paragraph(esc((x["h"] or "")[:150]), st(7.3)),
                     Paragraph(('<font color="%s"><b>%+.1f%%</b></font>' % ("#0a8a3a" if (x["mc"] or 0) > 0 else "#c62828", x["mc"])) if x["mc"] is not None else "—", st(7.6)),
                     Paragraph("" if x["right"] is None else ('<font color="#0a8a3a">%s</font>' % ("✔" if uni else "right")) if x["right"] else ('<font color="#c62828">%s</font>' % ("✖" if uni else "wrong")), st(7.6))]
                    for x in rx]
            t = Table(data, colWidths=[30, 78, 351, 42, 30])
            t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                   ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
            story.append(t)
        else:
            se = g["session"][:n_se]
            story.append(news_table(se, False) if se else Paragraph("no news lines in the session", st(7.4, col=DIM)))
        story.append(Spacer(1, 6))
        story.append(Paragraph("GIR · only news GIR checked (old stories held back) · ▲ share likely UP → CE · ▼ likely DOWN → PE · news, not a trade by itself"
                               if uni else "GIR - only news GIR checked (old stories held back) - + likely UP (CE) - likely DOWN (PE)", st(6.4, col=DIM)))
        doc = SimpleDocTemplate(path, pagesize=A4, leftMargin=32, rightMargin=32, topMargin=26, bottomMargin=22,
                                title="GIR news recap %s" % now.strftime("%Y-%m-%d"), author="GIR")
        doc.build(story)
        if doc.page <= 1:
            return path, (len(on), len(mk), len(rx))
        n_on, n_mk, n_rx, n_se = max(4, n_on - 2), max(3, n_mk - 2), max(4, n_rx - 2), max(4, n_se - 2)
        n_res = max(6, n_res - 1)
        n_due = max(6, n_due - 2)
    return path, (n_on, n_mk, n_rx)


def caption(g):
    crit = [x for x in g["overnight"] if x["lvl"] == "critical"]
    top = (crit or g["overnight"])[:4]
    s = "🗞 GIR MORNING NEWS RECAP · %s · %d overnight · %d critical" % (g["now"].strftime("%a %d %b %H:%M"), len(g["overnight"]), len(crit))
    big = [x for x in g.get("results", []) if x["big"]]
    if g.get("results"):
        s += " · %d results" % len(g["results"])
    if big:
        s += "\nRESULTS: " + " · ".join("%s %s %s" % (x["s"], "▲" if x["side"] > 0 else "▼", x.get("street") or ("BIG " + x["v"])) for x in big[:5])
    if top:
        s += "\n" + " · ".join("%s %s" % (x["s"], "▲" if x["side"] == "CE" else "▼" if x["side"] == "PE" else "·") for x in top)
    return s


def send_pdf(path, cap, post=None):
    """the PDF as a document to GIR Moves & News (or Box Picks until that channel is set). True when Telegram took it."""
    env = {}
    try:
        for line in open("/home/globalbot/.env"):
            m = re.match(r"\s*(?:export\s+)?([A-Z_]+)\s*=\s*(.*?)\s*$", line)
            if m:
                env[m.group(1)] = m.group(2).strip("'\"")
    except Exception:
        pass
    tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN") or env.get("TELEGRAM_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
    box = os.environ.get("TG_CHAT_BOX") or env.get("TG_CHAT_BOX")
    try:
        import tglanes
        chat = tglanes.chat_for(cap, box)
    except Exception:
        chat = box
    if not tok or not chat:
        print("recap: no Telegram token / channel"); return False
    if post is None:
        import requests
        post = requests.post
    for try_ in range(3):
        try:
            with open(path, "rb") as fh:
                r = post("https://api.telegram.org/bot%s/sendDocument" % tok, data={"chat_id": chat, "caption": cap[:1000]},
                         files={"document": (os.path.basename(path), fh, "application/pdf")}, timeout=60)
            if getattr(r, "ok", False):
                return True
            print("recap telegram: %s %s" % (getattr(r, "status_code", "?"), (getattr(r, "text", "") or "")[:120]))
            if getattr(r, "status_code", 0) == 429:
                time.sleep(10); continue
            return False
        except Exception as ex:
            print("recap telegram: %s" % str(ex)[:100]); time.sleep(3)
    return False


def run(send=True, now=None):
    now = now or dt.datetime.now(IST)
    g = gather(now)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "GIR_news_recap_%s.pdf" % now.strftime("%Y-%m-%d"))
    path, shown = build_pdf(g, path, morning_read(g))
    for f in sorted(os.listdir(OUT))[:-30]:                      # keep a month
        try:
            os.remove(os.path.join(OUT, f))
        except Exception:
            pass
    ok = send_pdf(path, caption(g)) if send else None
    print("recap %s: %d overnight · %d market · %d reactions · shown %s · %s" % (now.strftime("%Y-%m-%d %H:%M"), len(g["overnight"]), len(g["market"]), len(g["reaction"]), shown,
                                                                          "sent" if ok else "NOT sent" if send else path))
    return path, ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--send" in a:
        sys.exit(0 if run(True)[1] else 1)
    elif "--pdf" in a:
        print(run(False)[0])
    else:
        print(__doc__)
PY_RECAP
cat > $D/p126test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p126test.py - RESULTS AGAINST THE BROKERS: the preview numbers found and read (Divi's: Motilal Oswal ₹754 cr,
Prabhudas Lilladher ₹727 cr), the results alert says "52% ABOVE ESTIMATES" and follows the surprise, the history study,
the 08:30 recap. Fake news, fake AI reader, fake NSE - nothing is fetched, nothing is sent."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import expect, exchange, tglanes, alertword, newsrecap
IST = expect.IST
D = lambda s: dt.datetime.strptime(s, "%Y-%m-%d").date()
print("1. quarters")
check("filed 7 Nov 2026 -> Q2FY27 · 20 May 2026 -> Q4FY26 · 10 Aug 2026 -> Q1FY27 · 20 Jan 2027 -> Q3FY27",
      [expect.quarter_for_filing(D(x))[0] for x in ("2026-11-07", "2026-05-20", "2026-08-10", "2027-01-20")] == ["Q2FY27", "Q4FY26", "Q1FY27", "Q3FY27"])
tmp = tempfile.mkdtemp(prefix="p126")
try:
    expect.DB = os.path.join(tmp, "expect.db"); expect.STUDY = os.path.join(tmp, "expect_study.json")

    class R(object):
        def __init__(self, text, code=200):
            self.text, self.status_code = text, code
    RSS = ("<rss><item><title>Divi's Laboratories Q2 FY27 Preview: PAT seen up 17.5% at Rs 754 crore - Motilal Oswal</title><link>https://x.com/a</link>"
           "<pubDate>Mon, 02 Nov 2026 04:00:00 GMT</pubDate></item><item><title>Divi's Labs Q2 earnings: Prabhudas Lilladher expects profit of Rs 727 crore</title>"
           "<link>https://x.com/b</link><pubDate>Wed, 04 Nov 2026 04:00:00 GMT</pubDate></item><item><title>Divi's Lab Q2 result: Net profit rises 64% to Rs 1,127 cr</title>"
           "<link>https://x.com/c</link><pubDate>Sun, 08 Nov 2026 04:00:00 GMT</pubDate></item></rss>")
    URLS = []
    expect._GET = lambda u: (URLS.append(u), R(RSS) if "news.google.com/rss/search" in u else R("<p>the brokerage expects profit of Rs 754 crore</p>"))[-1]
    ASKED = []

    def ask(p):
        ASKED.append(p)
        if "Divi" in p:
            return '[{"broker": "Motilal Oswal", "metric": "pat", "value_cr": 753.7, "yoy_pct": 17.5}, {"broker": "Prabhudas Lilladher", "metric": "pat", "value_cr": 727.2, "yoy_pct": 5.5}]'
        if "Kotak" in p:
            return '[{"broker": "Kotak", "metric": "pat", "value_cr": 1500, "yoy_pct": null}, {"broker": "poll", "metric": "pat", "value_cr": 1480, "yoy_pct": null}]'
        return '[{"broker": "Nuvama", "metric": "pat", "value_cr": null, "yoy_pct": 30}]'
    expect._ASK = ask
    print("2. the brokers' numbers (future)")
    check("the company as the news names it: %s" % expect.who("Divi's Laboratories Limited", "DIVISLAB"), expect.who("Divi's Laboratories Limited", "DIVISLAB") == '("Divi\'s Laboratories" OR "Divi\'s" OR DIVISLAB)'
          and expect.who("Tata Steel Limited", "TATASTEEL") == '("Tata Steel" OR TATASTEEL)')
    items = expect.previews("Divi's Laboratories", "DIVISLAB", "Q2FY27", D("2026-11-07"))
    check("the previews before the results are found, the story written after them left out: %d" % len(items), len(items) == 2 and "1,127" not in str(items))
    check("the search asks for the quarter, the preview words and the 3 weeks before: %s" % URLS[0][40:200],
          "Q2FY27" in URLS[0].replace("%22", "") and "after%3A2026-10-17" in URLS[0] and "before%3A2026-11-08" in URLS[0])
    got = expect.collect("DIVISLAB", "Divi's Laboratories", "Q2FY27", D("2026-09-30"), before=D("2026-11-07"))
    con = expect.consensus("DIVISLAB", "Q2FY27")
    check("read: Motilal Oswal ₹753.7 cr, Prabhudas Lilladher ₹727.2 cr -> consensus ₹%s cr (%d brokers)" % (con["value"], con["n"]), con["value"] == 740.5 and con["n"] == 2)
    check("searched once per quarter (the second call reads nothing)", expect.collect("DIVISLAB", "Divi's", "Q2FY27", None, before=D("2026-11-07")) is None and len(ASKED) == 1)
    print("3. the results against the brokers")
    divi = {"unit": "crore", "rev": {"cur": 3676, "yoy": 2715, "qoq": 3200}, "pat": {"cur": 1127, "yoy": 689, "qoq": 902}, "opp": {"cur": 1662, "yoy": 1035, "qoq": 1300}}
    v, side, line = exchange.judge(divi)
    t_div = dt.datetime(2026, 11, 7, 11, 56, tzinfo=IST).timestamp()
    st = expect.vs_street("DIVISLAB", divi, t_div)
    check("DIVI'S: %s" % st["line"], st["surprise"] == 52.2 and st["side"] == 1 and st["big"] and st["word"] == "52% ABOVE ESTIMATES" and "Motilal Oswal ₹754" in st["line"])
    expect.add_estimate("XCO", "Q2FY27", "Kotak", "pat", 1500.0, None); expect.add_estimate("XCO", "Q2FY27", "poll", "pat", 1480.0, None)
    xco = {"unit": "crore", "rev": {"cur": 9000, "yoy": 8000, "qoq": 8800}, "pat": {"cur": 1200, "yoy": 1000, "qoq": 1100}}
    vx, sx, lx = exchange.judge(xco)
    stx = expect.vs_street("XCO", xco, t_div)
    check("profit +20%% YoY (a BEAT by last year) but 19%% BELOW the brokers -> DOWN: %s %+d -> %s %+d" % (vx, sx, stx["word"], stx["side"]),
          vx == "BEAT" and sx == 1 and stx["side"] == -1 and stx["word"] == "19% BELOW ESTIMATES" and not stx["big"])
    expect.add_estimate("YCO", "Q2FY27", "Nuvama", "pat", None, 30.0)
    yco = {"unit": "crore", "rev": {"cur": 900, "yoy": 800, "qoq": 880}, "pat": {"cur": 112, "yoy": 100, "qoq": 105}}
    exchange.judge(yco)
    sty = expect.vs_street("YCO", yco, t_div)
    check("only growth was expected (+30%%), profit grew +12%%: %s" % sty["line"], sty["side"] == -1 and "18 points BELOW" in sty["line"])
    check("no broker number -> no comparison (the YoY reading stands)", expect.vs_street("ZCO", yco, t_div) is None)
    f = {"exch": "NSE", "sym": "XCO", "t_exch": t_div, "kind": "RESULTS", "side": stx["side"], "verdict": vx, "street": stx["word"], "subject": "Outcome of Board Meeting",
         "detail": "", "link": "", "big": False}
    head = exchange.box_text(f, 120, lx + "\n" + stx["line"], False).split("\n")[0]
    check("the alert: %s" % head, head.startswith("📰 FILING ▼ XCO · RESULTS · BEAT YoY · 19% BELOW ESTIMATES") and tglanes.lane(head) == "critical")
    head2 = exchange.box_text(dict(f, sym="DIVISLAB", side=1, street=st["word"], big=True), 120, "x", False).split("\n")[0]
    check("the big one: %s" % head2, head2.startswith("🚨 CRITICAL RESULTS ▲ DIVISLAB · RESULTS · BEAT YoY · 52% ABOVE ESTIMATES") and tglanes.lane(head2) == "critical" and alertword.tier(head2) == "move")
    print("4. the history")
    os.makedirs(os.path.join(tmp, "data"))
    expect.BASE = tmp
    c = sqlite3.connect(os.path.join(tmp, "data", "oistudy.db"))
    c.execute("create table day(d text, sym text, spot real)")
    day0 = dt.date(2025, 1, 1)
    for i in range(700):
        d_ = day0 + dt.timedelta(days=i)
        if d_.weekday() < 5:
            for s_ in ("AAA", "BBB"):
                c.execute("insert into day values(?,?,?)", (str(d_), s_, 100.0))
    c.execute("update day set spot=106 where sym='AAA' and d='2025-11-05'"); c.execute("update day set spot=108 where sym='AAA' and d>'2025-11-05' and d<='2025-11-07'")
    c.execute("update day set spot=95 where sym='BBB' and d='2025-11-04'")
    c.commit(); c.close()
    r1 = expect.reaction("AAA", dt.datetime(2025, 11, 4, 17, 0, tzinfo=IST).timestamp())
    check("filed after the close on 4 Nov: base = that close, next day +6%%, 3 days +8%%: %s" % (r1,), r1 == (100.0, 6.0, 8.0, 0))
    r2 = expect.reaction("BBB", dt.datetime(2025, 11, 4, 11, 0, tzinfo=IST).timestamp())
    check("filed in market hours: base = the day before, the day itself -5%%, marked in-hours: %s" % (r2,), r2[1] == -5.0 and r2[3] == 1)
    HIST = {"AAA": [(dt.datetime(2025, 11, 4, 17, 0, tzinfo=IST).timestamp(), {"xbrl": "https://nse/aaa.xml"})],
            "BBB": [(dt.datetime(2025, 11, 4, 11, 0, tzinfo=IST).timestamp(), {"xbrl": "https://nse/bbb.xml"})]}
    expect.nse_history = lambda sym, q: HIST.get(sym, [])
    real_px = exchange.parse_xbrl
    exchange.parse_xbrl = lambda u: {"unit": "crore", "rev": {"cur": 1000, "yoy": 900, "qoq": 950}, "pat": {"cur": 150 if "aaa" in u else 75, "yoy": 120, "qoq": 130}}
    expect.fo_names = lambda: {"AAA": "Aaa Industries", "BBB": "Bbb Kotak Motors"}
    RSS2 = ("<rss><item><title>%s Q2 preview: Kotak sees profit at Rs %s crore</title><link>https://x.com/h</link>"
            "<pubDate>Mon, 27 Oct 2025 04:00:00 GMT</pubDate></item></rss>")
    expect._GET = lambda u: R(RSS2 % ("Aaa", 120) if "Aaa" in u else RSS2 % ("Bbb", 100) if "Bbb" in u else "<rss></rss>")
    expect._ASK = lambda p: ('[{"broker": "Kotak", "metric": "pat", "value_cr": 120, "yoy_pct": null}]' if "Aaa" in p else '[{"broker": "Kotak", "metric": "pat", "value_cr": 100, "yoy_pct": null}]')
    n = expect.history(8, 10)
    exchange.parse_xbrl = real_px
    st_ = expect.study()
    bk = {b["name"]: b for b in st_["buckets"]}
    check("history: AAA beat the brokers by 25%% and rose 6%% next day; BBB missed by 20%% and fell 5%%: %s" % {k: (v["n"], v["avg_d1"]) for k, v in bk.items()},
          n == 2 and bk.get("beat by 20%+", {}).get("avg_d1") == 6.0 and bk.get("missed by 20%+", {}).get("avg_d1") == -5.0 and st_["n"] == 2)
    check("a second run does not search again", expect.history(8, 10) == 0)
    json.dump({"buckets": [{"name": "beat by 20%+", "lo": 20, "hi": 1e9, "n": 40, "up_pct": 78, "avg_d1": 4.1, "avg_d3": 5.0}]}, open(expect.STUDY, "w"))
    st2 = expect.vs_street("DIVISLAB", divi, t_div)
    check("the live alert quotes the history: %s" % st2["line"][st2["line"].find("history"):], "history: beat by 20%+ - next day UP in 78% of 40 cases (avg +4.1%)" in st2["line"])
    print("5. the 08:30 recap")
    newsrecap.BASE = tmp
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)"); c.commit(); c.close()
    c = sqlite3.connect(os.path.join(tmp, "chains.db")); c.execute("create table results_cal(d text, sym text, purpose text)"); c.execute("create table fo_list(sym text, lot int)")
    c.executemany("insert into fo_list values(?,?)", [("TITAN", 1), ("XCO", 1), ("DIVISLAB", 1)])
    c.executemany("insert into results_cal values(?,?,?)", [("2026-11-09", "TITAN", "Results"), ("2026-11-10", "XCO", "Results"), ("2026-11-09", "NOTFO", "Results")]); c.commit(); c.close()
    expect.add_estimate("TITAN", "Q2FY27", "Kotak", "pat", 1400.0, 25.0); expect.add_estimate("TITAN", "Q2FY27", "Nuvama", "pat", 1360.0, 22.0)
    now = dt.datetime(2026, 11, 9, 8, 30, tzinfo=IST)
    newsrecap.results_since = lambda hours: {"DIVISLAB": {"verdict": "BEAT", "side": 1, "line": line, "t_exch": t_div, "read": {"big": True}}}
    g = newsrecap.gather(now)
    check("RESULTS DUE: today and tomorrow, F&O only, with the brokers' number: %s" % g["due"],
          [x[1] for x in g["due"]] == ["TITAN", "XCO"] and g["due"][0][2].startswith("brokers expect Q2FY27 profit ₹1,380 cr (+24% YoY) · 2 brokers"))
    r0 = g["results"][0]
    check("the result row carries the brokers: %s" % r0["street"], r0["street"] == "52% ABOVE ESTIMATES" and "vs the brokers" in r0["line"])
    path, shown = newsrecap.build_pdf(g, os.path.join(tmp, "r.pdf"), ["DIVISLAB ▲ 52% above the brokers."])
    check("one page", b"/Count 1" in open(path, "rb").read())
    cap = newsrecap.caption(g)
    check("the caption: %s" % cap.replace("\n", " / "), "DIVISLAB ▲ 52% ABOVE ESTIMATES" in cap)
    if "--keep" in sys.argv:
        shutil.copy(path, os.path.join(B, "p126_sample.pdf"))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
src = open(os.path.join(B, "exchange.py"), encoding="utf-8").read()
check("the exchange reader asks expect.vs_street on the first read and on the follow-up read", src.count("expect.vs_street(") == 2)
print("\nP126 BROKERS' NUMBERS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p126_patch.py $D || { rm -f $D/p126test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/expect.py $W/newsrecap.py $D/
cd $D && python3 -m py_compile expect.py exchange.py tglanes.py newsrecap.py p126test.py || back
timeout 120 python3 p126test.py 2>&1 | grep "OK  \|FAIL\|NUMBERS TEST"
timeout 120 python3 p126test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p125ctest.py p125btest.py p125test.py p124test.py p124ctest.py p118test.py p123test.py p80test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
cat > /etc/systemd/system/gir-expect.service <<'UNIT'
[Unit]
Description=GIR - the brokers' numbers for coming results (07:45, 22:15) + the history study (22:15)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && nice -n 19 python3 expect.py --nightly >> data/expect.log 2>&1'
UNIT
cat > /etc/systemd/system/gir-expect.timer <<'UNIT'
[Unit]
Description=GIR brokers' numbers at 07:45 and 22:15 IST every day
[Timer]
OnCalendar=*-*-* 07:45:00 Asia/Kolkata
OnCalendar=*-*-* 22:15:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-expect.timer >/dev/null 2>&1 || back
systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash && sleep 15
for u in gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo "brokers' numbers timer: $(systemctl is-active gir-expect.timer) · next: $(systemctl list-timers gir-expect.timer --no-pager | sed -n 2p | cut -c1-32)"
echo
echo "PATCH 126 APPLIED. The real check on Divi's (NSE + the news + the AI reader):"
cd /home/globalbot && set -a && source .env && set +a && cd $D
timeout 300 python3 expect.py --probe DIVISLAB 2>&1 | grep -v "^20[0-9][0-9]-"
echo
echo "The brokers' numbers for the results due in the next 7 days:"
timeout 1200 python3 expect.py --upcoming 2>&1 | grep -v "^20[0-9][0-9]-" | tail -40
echo "The history (8 quarters of every F&O share) runs every night at 22:15 - see:  python3 $D/expect.py --status   and   --study"
