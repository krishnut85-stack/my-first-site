#!/bin/bash
# PATCH 138 - NO RECAPS, NO ROUND-UPS, NO OLD RESULTS, F&O ONLY (on top of patch 137).
#   Monday 9 Nov 07:22-07:58: "Weekly Recap: Q2 profit rises 57.3%" came as news of ONGC, BEL, BAJFINANCE, ADANIENT, WIPRO (and a
#   CRITICAL on SUNPHARMA); Angel One's "Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors" as news of ITC and of Force Motors
#   (not F&O); JIOFIN's results of 16 Oct as news. Four more checks in the one gate every story passes before the reader:
#   a recap / wrap -> held · a round-up / market note under one share's name -> held · results that came out 4+ days ago -> held
#   (a preview is kept) · a share outside F&O -> held. Held items: python3 newsfresh.py --held
#   newsfresh.py (exact anchors), p124ctest.py (its test checks the older gate only). Restarts gir-newsroom and gir-exchange only
#   (the engine is not touched - safe before the open).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g138; mkdir -p $W
[ -f $D/bookpress.py ] || { echo "patch 137 is not installed yet - paste patch 137 first"; exit 1; }
grep -q "patch 138" $D/newsfresh.py && { echo "patch 138 is already installed"; exit 1; }
F="newsfresh.py p124ctest.py p118test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p138test.py; systemctl restart gir-newsroom gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p138_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p138_patch.py - PATCH 138: NO RECAPS, NO ROUND-UPS, NO OLD RESULTS, F&O ONLY - four more checks in the one gate every news story
passes (newsfresh.check, before the reader): Monday 9 Nov 07:22-07:58 Rama got "Weekly Recap: Q2 profit rises 57.3%" (ONGC, BEL,
BAJFINANCE, ADANIENT, WIPRO, a CRITICAL on SUNPHARMA), Angel One's "Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors" as
news of ITC and of Force Motors (not even F&O), and JIOFIN's results of 16 Oct as news.
Usage: python3 p138_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
NEW = r'''

# ---------------------------------------------------------------- patch 138: recaps, round-ups, old results, F&O only
RECAP = re.compile(r"\b(?:weekly|week'?s?|daily|morning|evening|market|news|stock)\s+(?:recap|wrap|round-?up|review)\b|\brecap\b|\bwrap-?up\b|week in review|"
                   r"week ahead|this week in|what (?:moved|happened) (?:the market )?this week|(?:biggest|top) (?:stories|news) (?:of|this) (?:the )?week", re.I)
ROUNDUP = re.compile(r"stocks? to (?:buy|watch|sell|trade|track)|top \d+ (?:stocks|picks|shares)|(?:top|stock|diwali|muhurat|samvat) picks|stocks? in (?:focus|news|the news)|"
                     r"buzzing|trade setup|\bhurdle\b|nifty (?:support|resistance|outlook|prediction|view|today|ahead)|sensex today|market (?:outlook|live|today|ahead)|"
                     r"\blive updates?\b|(?:bullish|bearish|positive|negative|buy|sell) on [A-Z][\w&.'-]+(?: [A-Z][\w&.'-]+)?\s*(?:,|and\b)", re.I)
RESULTS_W = re.compile(r"\bq[1-4]\b|q[1-4]\s?fy|quarter|\bresults?\b|earnings|profit|net income|revenue|ebitda|\bpat\b|margins?", re.I)
PREVIEW = re.compile(r"preview|expect|estimate|likely|to announce|to report|\bdate\b|ahead of|board meeting on|will (?:announce|declare)|scheduled", re.I)
RES_OLD_S = 4 * 86400
_FO = {"t": 0.0, "v": set()}


def _ro(name):
    import sqlite3
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def fo_set():
    if time.time() - _FO["t"] > 600:
        _FO["t"] = time.time()
        try:
            c = _ro("chains.db")
            _FO["v"] = {r[0] for r in c.execute("select sym from fo_list")}
            c.close()
        except Exception:
            pass
    return _FO["v"]


def last_results(sym, now=None):
    """the share's latest results date known to GIR (the exchange filings, the brokers' file, the results calendar) -> epoch or None"""
    now = now or time.time()
    ts = []
    for db, q in (("filings.db", "select max(t_exch) from filings where sym=? and kind='RESULTS'"),
                  (os.path.join("data", "expect.db"), "select max(t_filed) from act where sym=?")):
        try:
            c = _ro(db); v = c.execute(q, (sym,)).fetchone()[0]; c.close()
            if v:
                ts.append(float(v))
        except Exception:
            pass
    try:
        c = _ro("chains.db")
        v = c.execute("select max(d) from results_cal where sym=? and d<=?", (sym, dt.datetime.fromtimestamp(now, IST).strftime("%Y-%m-%d"))).fetchone()[0]
        c.close()
        if v:
            ts.append(dt.datetime.strptime(v + " 15:30", "%Y-%m-%d %H:%M").replace(tzinfo=IST).timestamp())
    except Exception:
        pass
    ts = [t for t in ts if t <= now + 3600]
    return max(ts) if ts else None


def stale_kind(sym, h, now=None):
    """-> why held, or None: a recap, a round-up / market note under one share's name, results that came out days ago, not F&O"""
    now = now or time.time()
    if RECAP.search(h or ""):
        return "a recap / wrap of older news, not news"
    if sym and sym != "MARKET":
        fo = fo_set()
        if fo and sym not in fo:
            return "%s is not an F&O share" % sym
        if ROUNDUP.search(h or ""):
            return "a round-up / market note naming several shares, not %s's own news" % sym
        if RESULTS_W.search(h or "") and not PREVIEW.search(h or ""):
            t = last_results(sym, now)
            if t and now - t > RES_OLD_S:
                return "%s's results came out on %s (%d days ago) - an old story" % (sym, dt.datetime.fromtimestamp(t, IST).strftime("%d %b"), (now - t) / 86400)
    return None
'''
EDITS = {
    "newsfresh.py": [
        ('''def check(sym, h, link="", t=None, now=None, get=None, post=None, live=None, page=True):
    """-> (send it?, why held). live: (price, % today) or None (market not live); default = the engine's live quotes."""
    now = now or time.time()
    why = None''', NEW.lstrip("\n") + '''

def check(sym, h, link="", t=None, now=None, get=None, post=None, live=None, page=True):
    """-> (send it?, why held). live: (price, % today) or None (market not live); default = the engine's live quotes."""
    now = now or time.time()
    why = stale_kind(sym, h, now)                               # patch 138'''),
        ('''    if t and now - t > FEED_MAX_S:
        why = "the feed dates it %d h ago" % ((now - t) / 3600)''', '''    if not why and t and now - t > FEED_MAX_S:
        why = "the feed dates it %d h ago" % ((now - t) / 3600)'''),
    ],
    "p118test.py": [
        ("""import newsalert, alertword, engine2, macro, exchange, newsroom, dashserve, llmread""", """import newsalert, alertword, engine2, macro, exchange, newsroom, dashserve, llmread
import newsfresh; newsfresh.stale_kind = lambda *a, **k: None      # patch 138: its own test checks the recap / round-up / old-results / F&O gate"""),
    ],
    "p124ctest.py": [
        ("""import newsfresh, newsalert""", """import newsfresh, newsalert
newsfresh.stale_kind = lambda *a, **k: None      # patch 138: its own test checks the recap / round-up / old-results / F&O gate"""),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p138test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p138test.py - Rama's Monday 9 Nov morning, item by item: the weekly recaps, Angel One's round-up under ITC / Force Motors,
JIOFIN's results of 16 Oct -> held; real news (Ambuja's capex, Divi's results of 2 days ago, a results preview, "Dixon picks up
a stake") -> passes. Fake files - nothing is fetched or sent."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import newsfresh
IST = newsfresh.IST
tmp = tempfile.mkdtemp(prefix="p138")
try:
    newsfresh.BASE = tmp; newsfresh.HELD = os.path.join(tmp, "data", "news_held.json"); os.makedirs(os.path.join(tmp, "data"))
    newsfresh._FO.update({"t": 0.0, "v": set()})
    now = time.time()
    c = sqlite3.connect(os.path.join(tmp, "chains.db"))
    c.execute("create table fo_list(sym text, lot int)"); c.execute("create table results_cal(d text, sym text, purpose text)")
    c.executemany("insert into fo_list values(?,1)", [(s,) for s in ("ONGC", "BEL", "BAJFINANCE", "ADANIENT", "WIPRO", "SUNPHARMA", "ITC", "JIOFIN", "AMBUJACEM", "DIVISLAB", "TCS", "DIXON")])
    c.execute("insert into results_cal values(?,?,?)", ("2026-10-16", "JIOFIN", "results")); c.commit(); c.close()
    c = sqlite3.connect(os.path.join(tmp, "filings.db"))
    c.execute("create table filings(sym text, kind text, t_exch int)")
    c.execute("insert into filings values('DIVISLAB','RESULTS',?)", (int(now - 2 * 86400),)); c.execute("insert into filings values('ONGC','RESULTS',?)", (int(now - 12 * 86400),))
    c.commit(); c.close()
    C = lambda s, h: newsfresh.check(s, h, "", now - 600, now=now, live=(100.0, 1.0), page=False)
    held = [("ONGC", "Weekly Recap: Q2 profit rises 57.3% and Venezuela rights expected", "recap"),
            ("SUNPHARMA", "Weekly Recap: US FDA observations at Halol plant", "recap"),
            ("BEL", "Weekly Recap: Q2 earnings beat and H1 orders total Rs 75 billion", "recap"),
            ("ITC", "Angel One flags Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors", "round-up"),
            ("FORCEMOT", "Angel One flags Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors", "not an F&O share"),
            ("JIOFIN", "Q2FY27 Quarterly Result Announced for Jio Financial Services Ltd.", "results came out on 16 Oct"),
            ("TCS", "Stocks to buy today: TCS, Infosys and HDFC Bank", "round-up")]
    for s, h, w in held:
        r = C(s, h)
        check("held %-10s %s -> %s" % (s, h[:48], r[1]), r[0] is False and w in (r[1] or ""))
    passed = [("AMBUJACEM", "Ambuja Cements to invest ₹14,500 crore to add 30 MTPA capacity"),
              ("DIVISLAB", "Divi's Q2 profit jumps 64% on strong custom synthesis"),
              ("ONGC", "ONGC Q3 results preview: brokers expect profit to rise 12%"),
              ("DIXON", "Dixon picks up 51% stake in display maker")]
    for s, h in passed:
        r = C(s, h)
        check("passes %-9s %s (%s)" % (s, h[:50], r[1] or "ok"), r[0] is True)
    j = json.load(open(newsfresh.HELD))
    check("held items are written to the held list for checking (%d)" % len(j), len(j) == len(held))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP138 NO RECAPS / ROUND-UPS / OLD RESULTS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p138_patch.py $D || { rm -f $D/p138test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile newsfresh.py p138test.py || back
timeout 120 python3 p138test.py 2>&1 | grep "OK  \|FAIL\|P138"
timeout 120 python3 p138test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p118test.py p124ctest.py p125test.py p126test.py p132test.py p133test.py p123test.py p124test.py p119test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-newsroom gir-exchange && sleep 6
for u in gir-newsroom gir-exchange; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 138 APPLIED (the engine was not touched). This morning's lines, read again on your server's own data:"
cd $D && python3 - <<'PYCHK'
import newsfresh
for s, h in (("ONGC", "Weekly Recap: Q2 profit rises 57.3% and Venezuela rights expected"), ("SUNPHARMA", "Weekly Recap"),
             ("ITC", "Angel One flags Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors"),
             ("FORCEMOT", "Angel One flags Nifty hurdle at 25,150; bullish on ITC, SBI, Force Motors"),
             ("JIOFIN", "Q2FY27 Quarterly Result Announced for Jio Financial Services Ltd.")):
    print("  %-10s %s" % (s, newsfresh.stale_kind(s, h) or "PASSES (no results date known for it)"))
PYCHK
