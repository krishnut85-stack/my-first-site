#!/bin/bash
# PATCH 126c - THE BROKERS' NUMBERS: PROVEN, AND ONLY BEFORE THE RESULTS (on top of patch 126b).
#   126b's real run: "Divi's Q2: Net Profit Jumps 64%" (written AFTER the 11:56 filing, same day) came in, and the reader
#   gave "Motilal Oswal / Prabhudas Lilladher revenue ₹3,000 cr" - the same round number twice, not in any article.
#   Now: articles only up to the filing time (coming results: up to noon of the results day), and every number must
#   come with the article's own words that carry it - GIR checks the words are in the article; no proof, no number.
#   The numbers read so far are deleted and read again.
#   expect.py (replaced) · data/expect.db (the 7 share-quarters read so far, cleared). Restarts gir-exchange.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g126c; mkdir -p $W
grep -q "patch 126b" $D/expect.py 2>/dev/null || { echo "patch 126b is not installed yet - paste patch 126b first"; exit 1; }
grep -q "patch 126c" $D/expect.py && { echo "patch 126c is already installed"; exit 1; }
cp $D/expect.py $D/expect.py.bak$TS; cp $D/p126test.py $D/p126test.py.bak$TS
[ -f $D/data/expect.db ] && cp $D/data/expect.db $D/data/expect.db.bak$TS
back() { cp $D/expect.py.bak$TS $D/expect.py; cp $D/p126test.py.bak$TS $D/p126test.py; [ -f $D/data/expect.db.bak$TS ] && cp $D/data/expect.db.bak$TS $D/data/expect.db; systemctl restart gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/expect.py <<'PY_EXPECT'
#!/usr/bin/env python3
"""expect.py - patch 126 (+126b the right year, +126c proof and the filing time): WHAT THE BROKERS EXPECTED. The market moves on results against the brokers' numbers, not
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


def previews(name, sym, q, before=None, days=21, until=None):
    """Google News: the preview / poll / estimate stories for this company and quarter -> [(t_pub, title, link)]"""
    from urllib.parse import quote
    words = '(preview OR estimate OR estimates OR expected OR expects OR poll OR "seen at" OR "likely to" OR brokerage)'
    end = before or dt.datetime.now(IST).date()
    lo_t = dt.datetime.combine(end - dt.timedelta(days=days), dt.time(0, 0), IST).timestamp()
    hi_t = until or dt.datetime.combine(end, dt.time(23, 59), IST).timestamp()   # patch 126c: until = the filing time (not the day's end)
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
        if not tp or tp < lo_t or tp > hi_t:
            continue                                          # patch 126b: outside the weeks before the results (last year's Q2 preview, the result itself)
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
Use ONLY items dated {lo} to {hi}; anything about another year's quarter is not wanted.
Find the brokerages' / analysts' ESTIMATES for {name}'s {q} numbers. Ignore actual reported numbers, other companies,
other quarters, and the company's own guidance.

{items}

Answer with JSON only: a list, one entry per broker and metric:
[{{"broker": "Motilal Oswal", "metric": "pat", "value_cr": 753.7, "yoy_pct": 17.5, "quote": "PAT is seen rising 17.5% to Rs 753.7 crore"}}]
metric: "pat" (net profit), "rev" (revenue / net sales / NII for banks), "ebitda" (EBITDA / operating profit / PPOP).
value_cr in ₹ crore (convert from lakh / million / billion), null if only a growth % is given; yoy_pct null if not given.
broker: the brokerage name, or "poll" for a poll / consensus of several analysts. [] if none of the items has an estimate.
quote: the exact words from the item that carry this number (copied, not rewritten). No quote = do not list it; never guess a number."""


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
        blocks.append("- [%s] %s%s" % (dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %Y") if tp else "?", title, ("\n  " + body[:2500]) if body else ""))
    _N["asked"] += 1
    ts_ = [x[0] for x in items if x[0]]
    txt = _ask(PROMPT.format(name=name, sym=sym, q=q, qend=qend.strftime("%d %b %Y") if qend else "?", items="\n".join(blocks),
                             lo=dt.datetime.fromtimestamp(min(ts_), IST).strftime("%d %b %Y") if ts_ else "?", hi=dt.datetime.fromtimestamp(max(ts_), IST).strftime("%d %b %Y") if ts_ else "?"))
    if not txt:
        return []
    m = re.search(r"\[.*\]", txt, re.S)
    try:
        got = json.loads(m.group(0)) if m else []
    except Exception:
        got = []
    out = []
    norm = lambda x: re.sub(r"[^a-z0-9.%]+", " ", (x or "").lower().replace(",", "")).strip()
    text_ = norm("\n".join(blocks))
    for e in got if isinstance(got, list) else []:
        if not isinstance(e, dict) or e.get("metric") not in ("pat", "rev", "ebitda"):
            continue
        pv, py_ = proven(e, text_, norm)                       # patch 126c: a number is kept only when the article's own words carry it
        if not pv and not py_:
            _N["rejected"] = _N.get("rejected", 0) + 1
            print("  %-11s %s not used (no proof in the article): %s %s %s" % (sym, q, e.get("broker"), e.get("metric"), e.get("value_cr") or e.get("yoy_pct")))
            continue
        e = dict(e, value_cr=e.get("value_cr") if pv else None, yoy_pct=e.get("yoy_pct") if py_ else None)
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


def proven(e, text_, norm):
    """the reader's quote is in the article, and the number is in the quote (₹ crore, or lakh / million / billion / lakh crore)"""
    qt = norm(e.get("quote") or "")
    if len(qt) < 12 or qt[:60] not in text_:
        return False, False
    nums = [float(x) for x in re.findall(r"\d+(?:\.\d+)?", qt)]
    v, y = e.get("value_cr"), e.get("yoy_pct")
    ok_v = v is not None and any(abs(n * k - float(v)) <= max(0.6, 0.02 * abs(float(v))) for n in nums for k in (1, 0.01, 0.1, 100, 100000))
    ok_y = y is not None and any(abs(n - abs(float(y))) <= 0.11 for n in nums)
    return ok_v, ok_y


def collect(sym, name, q, qend, before=None, days=21, force=False, until=None):
    """find + read the brokers' numbers for one share-quarter once (resumable). -> estimates found"""
    c = db()
    seen = c.execute("select n from done where sym=? and q=? and kind='est'", (sym, q)).fetchone()
    c.close()
    if seen and not force:
        return None
    try:
        items = previews(name, sym, q, before, days, until)
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
        return {s: re.sub(r"\b([A-Za-z]{2,}) S\b", r"\1's", n) for s, n, _l in newsroom.fo_names()}
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
        c_ = db()
        last = c_.execute("select t from done where sym=? and q=? and kind='est'", (sym, q)).fetchone()
        c_.close()
        got = collect(sym, names.get(sym, sym), q, qe, d_, 28, force=bool(last and time.time() - last[0] > 20 * 3600),
                      until=dt.datetime.combine(d_, dt.time(12, 0), IST).timestamp())     # results usually come after noon
        if got is not None:
            n += 1
            print("  %-11s %s results %s · %s" % (sym, q, d, expected_line(sym, d_) or "no broker number found"))
            time.sleep(2)
    return n


def nse_history(sym, quarters):
    """NSE's list of the share's quarterly results -> [(t_filed, entry)] newest first, `quarters` of them"""
    import exchange
    rows, keys = [], set()
    now = dt.datetime.now(IST)
    paths = []
    for k in range(quarters // 4 + 1):                           # patch 126b: one year per request (NSE answers a long range with nothing)
        to = now - dt.timedelta(days=365 * k)
        paths.append("/api/corporates-financial-results?index=equities&period=Quarterly&symbol=%s&from_date=%s&to_date=%s" % (
            sym, (to - dt.timedelta(days=364)).strftime("%d-%m-%Y"), to.strftime("%d-%m-%Y")))
    paths.append("/api/corporates-financial-results?index=equities&period=Quarterly&symbol=%s" % sym)
    for path in paths:
        try:
            data = exchange.nse_json(path)
        except Exception as ex:
            _N["nse_err"] = str(ex)[:100]; continue
        for e in (data if isinstance(data, list) else data.get("data", [])):
            if (e.get("symbol") or "").upper() != sym:
                continue
            k_ = (e.get("exchdisstime") or e.get("broadCastDate") or e.get("filingDate"), e.get("xbrl"))
            if k_ not in keys:
                keys.add(k_); rows.append(e)
        time.sleep(0.5)
    try:                                                         # the results the exchange reader saw itself (filings.db)
        fc = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "filings.db"), uri=True, timeout=5)
        for t_, link_ in fc.execute("select t_exch, link from filings where sym=? and kind='RESULTS' order by t_exch desc", (sym,)):
            rows.append({"symbol": sym, "exchdisstime": dt.datetime.fromtimestamp(t_, IST).strftime("%d-%b-%Y %H:%M:%S"), "xbrl": "", "_t": t_, "_pdf": link_})
        fc.close()
    except Exception:
        pass
    _N["nse_rows"] = len(rows)
    out, seen = [], set()
    tt = lambda e: e.get("_t") or exchange.parse_t(e.get("exchdisstime") or e.get("broadCastDate") or e.get("filingDate")) or 0
    byq = {}                                                      # one row per quarter: the first filing time, the entry that has the XBRL
    for e in rows:
        t = tt(e)
        if not t:
            continue
        q, _qe = quarter_for_filing(dt.datetime.fromtimestamp(t, IST).date())
        t0, e0 = byq.get(q, (t, e))
        byq[q] = (min(t, t0), e if (e.get("xbrl") and not e0.get("xbrl")) else e0)
    out = sorted(byq.values(), key=lambda x: -x[0])
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
            got = collect(sym, names.get(sym, sym), q, qe, before=d, days=21, until=t)
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
        print("NSE / the reader's filings: %s rows%s" % (_N.get("nse_rows"), (" · NSE error: " + _N["nse_err"]) if _N.get("nse_err") else ""))
        d = dt.datetime.fromtimestamp(hist[0][0], IST).date() if hist else today
        q, qe = quarter_for_filing(d)
        print("%s (%s) · %s · results %s" % (sym, names.get(sym, sym), q, d))
        try:
            items = previews(names.get(sym, sym), sym, q, d, 28, hist[0][0] if hist else None)
        except Exception as ex:
            items = []; print("  the news search failed: %s" % str(ex)[:120])
        for tp, t, l in items:
            print("  news %s  %s" % (dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %Y") if tp else "?", t[:110]))
        got = read_estimates(sym, names.get(sym, sym), q, qe, items)
        for e in got:
            print("  READ %-28s %-6s ₹%s cr  %s" % (e["broker"], e["metric"], e["value_cr"], ("%+.1f%% YoY" % e["yoy_pct"]) if e["yoy_pct"] is not None else ""))
        print("  " + (expected_line(sym, d) or "no broker number found"))
        x_ = next((e for t_, e in hist if e.get("xbrl")), None)
        if hist and not x_:
            try:
                import exchange
                r_ = exchange.latest_results(sym, hist[0][0])
                x_ = {"xbrl": r_.get("xbrl")} if r_ and r_.get("xbrl") else None
            except Exception:
                x_ = None
        if hist and x_:
            import exchange
            res = exchange.parse_xbrl(x_["xbrl"]); exchange.judge(res)
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
           "<link>https://x.com/c</link><pubDate>Sun, 08 Nov 2026 04:00:00 GMT</pubDate></item>"
           "<item><title>Divis Laboratories Q2 results: Profit jumps 45% beating Street estimates of Rs 609 crore - CNBC TV18</title>"
           "<link>https://x.com/d</link><pubDate>Sun, 09 Nov 2025 04:00:00 GMT</pubDate></item></rss>")
    URLS = []
    expect._GET = lambda u: (URLS.append(u), R(RSS) if "news.google.com/rss/search" in u else R("<p>the brokerage expects profit of Rs 754 crore</p>"))[-1]
    ASKED = []

    def ask(p):
        ASKED.append(p)
        if "Divi" in p:
            return ('[{"broker": "Motilal Oswal", "metric": "pat", "value_cr": 753.7, "yoy_pct": 17.5, "quote": "PAT seen up 17.5% at Rs 754 crore"},'
                    ' {"broker": "Prabhudas Lilladher", "metric": "pat", "value_cr": 727.2, "yoy_pct": 5.5, "quote": "Prabhudas Lilladher expects profit of Rs 727 crore"},'
                    ' {"broker": "Motilal Oswal", "metric": "rev", "value_cr": 3000, "yoy_pct": null, "quote": "revenue of about Rs 3,000 crore expected"},'
                    ' {"broker": "Prabhudas Lilladher", "metric": "rev", "value_cr": 3000, "yoy_pct": null}]')
        if "Kotak" in p:
            return '[{"broker": "Kotak", "metric": "pat", "value_cr": 1500, "yoy_pct": null}, {"broker": "poll", "metric": "pat", "value_cr": 1480, "yoy_pct": null}]'
        return '[{"broker": "Nuvama", "metric": "pat", "value_cr": null, "yoy_pct": 30}]'
    expect._ASK = ask
    print("2. the brokers' numbers (future)")
    check("the company as the news names it: %s" % expect.who("Divi's Laboratories Limited", "DIVISLAB"), expect.who("Divi's Laboratories Limited", "DIVISLAB") == '("Divi\'s Laboratories" OR "Divi\'s" OR DIVISLAB)'
          and expect.who("Tata Steel Limited", "TATASTEEL") == '("Tata Steel" OR TATASTEEL)')
    items = expect.previews("Divi's Laboratories", "DIVISLAB", "Q2FY27", D("2026-11-07"))
    check("the previews of the 3 weeks before are found; the result itself and LAST YEAR's Q2 story (Nov 2025, the ₹609 cr poll) left out: %d" % len(items),
          len(items) == 2 and "1,127" not in str(items) and "609" not in str(items))
    check("the search asks for the quarter, the preview words and the 3 weeks before: %s" % URLS[0][40:200],
          "Q2FY27" in URLS[0].replace("%22", "") and "after%3A2026-10-17" in URLS[0] and "before%3A2026-11-08" in URLS[0])
    t_div0 = dt.datetime(2026, 11, 7, 11, 56, tzinfo=IST).timestamp()
    got = expect.collect("DIVISLAB", "Divi's Laboratories", "Q2FY27", D("2026-09-30"), before=D("2026-11-07"), until=t_div0)
    con = expect.consensus("DIVISLAB", "Q2FY27")
    check("the made-up revenue numbers (₹3,000 cr: one quote not in any article, one with no quote) are NOT kept: %s" % [(g_["broker"], g_["metric"]) for g_ in got],
          expect.consensus("DIVISLAB", "Q2FY27", "rev") is None and len(got) == 2)
    RSS_DAY = ("<rss><item><title>Divi's Labs Q2 preview: Nuvama sees profit at Rs 760 crore</title><link>https://x.com/e</link><pubDate>Sat, 07 Nov 2026 03:00:00 GMT</pubDate></item>"
               "<item><title>Divi's Laboratories Q2 Results: Net Profit Jumps 64% To Rs 1,127 Crore</title><link>https://x.com/f</link><pubDate>Sat, 07 Nov 2026 07:30:00 GMT</pubDate></item></rss>")
    g0 = expect._GET
    expect._GET = lambda u: R(RSS_DAY) if "news.google.com/rss/search" in u else R("")
    it_day = expect.previews("Divi's Laboratories", "DIVISLAB", "Q2FY27", D("2026-11-07"), 21, until=t_div0)
    expect._GET = g0
    check("the results day: the 08:30 preview kept, the 13:00 'Net Profit Jumps 64%%' (after the 11:56 filing) left out: %s" % [x[1][:40] for x in it_day],
          len(it_day) == 1 and "Nuvama" in it_day[0][1])
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
    expect_nse_history = expect.nse_history
    expect.nse_history = lambda sym, q: HIST.get(sym, [])
    real_px = exchange.parse_xbrl
    exchange.parse_xbrl = lambda u: {"unit": "crore", "rev": {"cur": 1000, "yoy": 900, "qoq": 950}, "pat": {"cur": 150 if "aaa" in u else 75, "yoy": 120, "qoq": 130}}
    real_fo_names = expect.fo_names
    expect.fo_names = lambda: {"AAA": "Aaa Industries", "BBB": "Bbb Kotak Motors"}
    RSS2 = ("<rss><item><title>%s Q2 preview: Kotak sees profit at Rs %s crore</title><link>https://x.com/h</link>"
            "<pubDate>Mon, 27 Oct 2025 04:00:00 GMT</pubDate></item></rss>")
    expect._GET = lambda u: R(RSS2 % ("Aaa", 120) if "Aaa" in u else RSS2 % ("Bbb", 100) if "Bbb" in u else "<rss></rss>")
    expect._ASK = lambda p: ('[{"broker": "Kotak", "metric": "pat", "value_cr": 120, "yoy_pct": null, "quote": "Kotak sees profit at Rs 120 crore"}]' if "Aaa" in p
                             else '[{"broker": "Kotak", "metric": "pat", "value_cr": 100, "yoy_pct": null, "quote": "Kotak sees profit at Rs 100 crore"}]')
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
    print("4b. NSE's results list")
    fc = sqlite3.connect(os.path.join(tmp, "filings.db")); fc.execute("create table filings(sym text, kind text, t_exch real, link text)")
    fc.execute("insert into filings values('DIVISLAB','RESULTS',?,'https://nse/d.pdf')", (t_div,)); fc.commit(); fc.close()
    CALLS = []

    def nj(path):
        CALLS.append(path)
        if "from_date" in path and path.endswith("2026"):
            return [{"symbol": "DIVISLAB", "exchdisstime": "07-Nov-2026 11:58:06", "xbrl": "https://nse/q2fy27.xml"},
                    {"symbol": "DIVISLAB", "exchdisstime": "09-Aug-2026 13:00:00", "xbrl": "https://nse/q1fy27.xml"}]
        if "from_date" in path and path.endswith("2025"):
            return {"data": [{"symbol": "DIVISLAB", "exchdisstime": "08-Nov-2025 12:00:00", "xbrl": "https://nse/q2fy26.xml"}]}
        return []
    real_nj = exchange.nse_json
    exchange.nse_json = nj
    hist = expect_nse_history("DIVISLAB", 8)
    exchange.nse_json = real_nj
    check("one-year requests (%d), one row per quarter, the reader's own 11:56:36 time with NSE's XBRL: %s" % (sum(1 for c_ in CALLS if "from_date" in c_),
          [(dt.datetime.fromtimestamp(t, IST).strftime("%d %b %Y %H:%M:%S"), e.get("xbrl")) for t, e in hist]),
          sum(1 for c_ in CALLS if "from_date" in c_) == 3 and len(hist) == 3 and hist[0][0] == t_div and hist[0][1]["xbrl"] == "https://nse/q2fy27.xml")
    expect.fo_names = real_fo_names
    import newsroom
    real_nf = newsroom.fo_names
    newsroom.fo_names = lambda: [("DIVISLAB", "Divi S Laboratories", 100), ("DRREDDY", "Dr. Reddy S Laboratories", 125), ("TATASTEEL", "Tata Steel", 5500)]
    nm = expect.fo_names()
    newsroom.fo_names = real_nf
    check("the names as the news writes them: %s" % nm, nm["DIVISLAB"] == "Divi's Laboratories" and nm["DRREDDY"] == "Dr. Reddy's Laboratories" and nm["TATASTEEL"] == "Tata Steel")
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
cp $W/expect.py $D/expect.py
cd $D && python3 -m py_compile expect.py p126test.py || back
timeout 120 python3 p126test.py 2>&1 | grep "OK  \|FAIL\|NUMBERS TEST"
timeout 120 python3 p126test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p125btest.py p125ctest.py p124test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
python3 -c "
import sqlite3; c = sqlite3.connect('$D/data/expect.db')
for t in ('est', 'done', 'cmp'):
    c.execute('delete from %s' % t)
c.commit(); print('the numbers read so far deleted (they are read again now)')"
systemctl restart gir-exchange && sleep 8
[ "$(systemctl is-active gir-exchange)" = "active" ] || { echo "gir-exchange did not come back"; back; }
echo
echo "PATCH 126c APPLIED. Divi's again (articles up to the 11:56 filing, numbers with proof only):"
cd /home/globalbot && set -a && source .env && set +a && cd $D
timeout 300 python3 expect.py --probe DIVISLAB 2>&1 | grep -v "^20[0-9][0-9]-"
echo
echo "The results due in the next 7 days:"
timeout 1500 python3 expect.py --upcoming 2>&1 | grep -v "^20[0-9][0-9]-" | tail -30
