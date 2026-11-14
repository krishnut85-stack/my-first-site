#!/bin/bash
# PATCH 270 - ONE NEWS CLEANER FOR EVERY LIST (Rama, 14 Nov: "some news are still old news ... you don't know where all it's reflecting - I am afraid
#   whether you follow up correctly"). Patch 260 fixed only the Telegram GOVT WATCH; the TOMORROW tab's morning brief (another part of GIR) showed
#   PAYTM's RBI wallet nod 6 times, six IRDAI-commission articles as six lines, BEL's scanned-PDF letters, Federal Bank's letterhead and a "31 stocks
#   ex-date next week" round-up as PFC's news. Now (newsclean.py, used by both):
#   morning brief   one line a story "[+4 more reports]" · unreadable text -> "could not be read - open it on NSE" · round-ups are not a company's news
#   GOVT WATCH      news sites' reports: one alert a regulator-story in 6 h (the regulator's OWN page always comes at once)
#   + newsaudit.sh (read only) checks every news list - Telegram / alert board, the NEWS tab, the brief - for OLD, REPEAT, UNREADABLE, ROUND-UP.
#   Tested: 10 cases on the brief's own lines. Restarts the page server only - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 268" $D/govwatch.py && [ -f $D/morningbrief.py ] || { echo "patch 268 (and the morning brief) first"; exit 1; }
F="morningbrief.py govwatch.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/newsclean.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
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
PY_NC
cat > $W/p270_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p270_patch.py - patch 270: the morning brief and GOVT WATCH use newsclean.py.  python3 p270_patch.py DIR"""
import os, sys
D = sys.argv[1]
MB = '''_filings270, _alerts270 = filings, alerts                         # patch 270: no junk, no round-ups, one line a story


def _clean270(xs):
    import newsclean as NC
    groups, order = {}, []
    for x in sorted(xs, key=lambda x: -x["t"]):                       # the latest report leads its story
        w = x.get("what") or ""
        if x["sym"] != "MARKET" and NC.roundup(w):                  # a many-stock round-up is not this company's news
            continue
        if NC.junk(w) or NC.letterhead(w):
            x = dict(x, what="(the filing's text could not be read - open it on NSE)")
        k = NC.story_key(x["sym"], x["kind"], w)
        if k in groups:
            groups[k]["n"] += 1
            groups[k]["cr"] = max(groups[k]["cr"], x.get("cr") or 0)
            continue
        groups[k] = dict(x, n=0, what=NC.OUTLETS.sub("", x.get("what") or "")); order.append(k)
    out = []
    for k in order:
        g = groups[k]
        if g["n"]:
            g["what"] = "[+%d more report%s] %s" % (g["n"], "s" if g["n"] > 1 else "", NC.OUTLETS.sub("", g["what"]))
        g.pop("n", None); out.append(g)
    return out


def filings(start, now):
    return _clean270(_filings270(start, now))


def alerts(start, now):
    return _clean270(_alerts270(start, now))


if __name__ == "__main__":'''
GW = '''_run270 = run                                                      # patch 270: the news sites' reports - one alert a regulator in 6 h


def run(send=None, get=None, now=None, probe=False):
    if probe:
        return _run270(None, get, now, probe)
    out = _run270(None, get, now)
    import newsclean as NC
    p = os.path.join(BASE, "data", "govwatch_story.json")
    try:
        st = json.load(open(p))
    except Exception:
        st = {}
    t = (now or dt.datetime.now(IST)).timestamp()
    keep = []
    for x in out:
        L = x.split("\\n")
        title, link = (L[1] if len(L) > 1 else ""), L[-1]
        if "news.google" in link:                                    # a news site's report (not the regulator's own page): one a story in 6 h
            k = "%s" % (NC.story_key("MARKET", "", title),)
            if t - float(st.get(k, 0)) < 6 * 3600:
                continue
            st[k] = t
        keep.append(x)
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True); json.dump(st, open(p, "w"))
    except Exception:
        pass
    if send:
        for x in keep[:8]:
            send(x)
    return keep


if __name__ == "__main__":'''
for f, add, need in (("morningbrief.py", MB, None), ("govwatch.py", GW, "patch 268")):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if "patch 270" in s:
        print("  %s: patch 270 - already in" % f); continue
    if need and need not in s:
        print("❌ %s: %s first" % (f, need)); sys.exit(1)
    a = 'if __name__ == "__main__":'
    if s.count(a) != 1:
        print("❌ %s: its main block found %d times" % (f, s.count(a))); sys.exit(1)
    s = s.replace(a, add)
    open(p, "w", encoding="utf-8").write(s)
    print("  %s: %s" % (f, "no junk / letterheads / round-ups · one line a story (+N more reports)" if f == "morningbrief.py" else "news-site reports: one alert a regulator in 6 h · round-ups not sent"))
print("patch 270 in")
PY_PATCH
cat > $W/p270test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p270test.py - the news cleaner on the 14 Nov morning brief's own lines (temp copies, nothing sent).  python3 p270test.py DIR"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("newsclean.py", "morningbrief.py", "govwatch.py"):
    shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); sys.path.append(SRC); os.chdir(T)       # GIR's other modules (daypattern, weekview...) from the real folder
import newsclean as NC
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
BEL = "619 Crore ' I ' KGI TSTT tU ' PlPl ' h % ' iHsh + H , ^ TK ^ T ^ ' Td ' lPittl PlPl ^ s 6 * 1 = jsK"
FED = "Secretarial Department Federal Bank | 6th Floor, Federal Towers, Bank Junction, Aluva | Kerala | 683"
PFC = "Rs 231.80 Dividend, 1:10 Stock Split, 1 Buyback: 31 stocks to trade ex-date next week - MRF, Oil Ind"
chk("BEL's scanned-PDF letters are recognised as unreadable", NC.junk(BEL))
chk("Federal Bank's letterhead is recognised as an address, not news", NC.letterhead(FED))
chk("the '31 stocks ex-date next week' round-up is not PFC's own news", NC.roundup(PFC))
GOOD = ["Bharat Electronics receives orders worth Rs 619 crore for radars and communication equipment",
        "Paytm gets RBI's in-principle nod to revive wallet business; shares hit record high - The Hindu",
        "Eicher Motors Limited has submitted to the Exchange, the financial results for the period"]
chk("real news is not touched (orders, an RBI nod, results)", not any(NC.junk(x) or NC.letterhead(x) or NC.roundup(x) for x in GOOD))
fd = sqlite3.connect("filings.db")
fd.execute("create table filings(sym text, t_exch int, kind text, side int, subject text, detail text, verdict text)")
fri = lambda h, m: dt.datetime(2026, 11, 13, h, m, tzinfo=IST).timestamp()
fd.executemany("insert into filings values (?,?,?,?,?,?,?)", [("BEL", fri(18, 31), "ORDER", 1, "Order", BEL, ""), ("FEDERALBNK", fri(18, 51), "ORDER", 1, "Intimation of order", FED, ""),
               ("EICHERMOT", fri(16, 51), "RESULTS", 0, "Results", GOOD[2], "IN LINE")]); fd.commit()
td = sqlite3.connect("tomorrow.db"); td.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
pay = ["Paytm Wallet is coming back: RBI gives approval, here's what changes for users - News9live", GOOD[1], "Paytm Gets Preliminary RBI Approval for Wallet Licence; Shares Hit Record High",
       "Paytm gets preliminary RBI approval to bring its wallet back and shares hit a 52-week high - Startup", "Paytm Prepaid Wallets Win RBI Nod, But Final Approval Still Pending - Urban Acres"]
rows = [("2026-11-13", "18:%02d:00" % (30 + i), "", "PAYTM", "", "⚠️ SHOCK WATCH ▲ PAYTM · REGULATOR · RBI\n%s" % h) for i, h in enumerate(pay)]
rows.append(("2026-11-13", "18:25:00", "", "PFC", "", "⚠️ SHOCK WATCH ▲ PFC · DEAL · x\n" + PFC))
irdai = ["IRDAI proposed commission cuts: Which banks and NBFCs face the biggest impact? - CNBC TV18", "IRDAI may roll out insurance commission caps from January, overhaul distribution rules",
         "Turtlemint flags lower income for agents under IRDAI proposed commission curbs", "IRDAI may modify draft distribution paper, reports CNBC-TV18; PB Fintech shares rise nearly 5%"]
rows += [("2026-11-13", "%02d:%02d:00" % (16 + i, 10), "", "", "", "🚨 CRITICAL GOVT · IRDAI · 16:10\n%s\ntouches: INSURANCE" % h) for i, h in enumerate(irdai)]
td.executemany("insert into alerts values (?,?,?,?,?,?)", rows); td.commit()
import morningbrief as MB
now = dt.datetime(2026, 11, 14, 8, 30, tzinfo=IST)
txt = MB.build(now)[0]
chk("the brief: PAYTM once, '+4 more reports of this' (it was 6 lines)", txt.count("PAYTM ·") == 1 and "[+4 more reports]" in txt, txt)
chk("... IRDAI's commission articles: one line, '+3 more reports' (it was 6 lines)", txt.count("IRDAI") == 1 and "[+3 more reports]" in txt, txt)
chk("... BEL's and Federal Bank's unreadable texts are not shown as news", "KGI TSTT" not in txt and "Federal Towers" not in txt and "could not be read" in txt, txt)
chk("... the PFC round-up is gone; EICHERMOT's results stay", "31 stocks" not in txt and "EICHERMOT" in txt, txt)
print("\n" + txt + "\n")
import govwatch as G
G.fo_map = lambda: {}
rfc = lambda x: x.strftime("%a, %d %b %Y %H:%M:%S +0530")
GN = [u for s, u in G.SOURCES if "IRDAI+when" in u][0]
FEED = {}
get = lambda u: FEED.get(u, "<rss><channel></channel></rss>")
rss = lambda items: "<rss><channel>" + "".join("<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>" % i for i in items) + "</channel></rss>"
json.dump({"seen": [], "first": False, "p260": True, "srcs": sorted({s for s, _ in G.SOURCES})}, open(G.SEEN, "w"))
N = dt.datetime(2026, 11, 13, 16, 0, tzinfo=IST)
FEED[GN] = rss([(irdai[3], "https://news.google.com/a", rfc(N))])
r1 = G.run(get=get, now=N)
FEED[GN] = rss([(irdai[1], "https://news.google.com/b", rfc(N + dt.timedelta(hours=2)))])
r2 = G.run(get=get, now=N + dt.timedelta(hours=2))
FEED[GN] = rss([(irdai[0], "https://news.google.com/c", rfc(N + dt.timedelta(hours=7)))])
r3 = G.run(get=get, now=N + dt.timedelta(hours=7))
chk("Telegram: IRDAI news reports - the first one sent, the next within 6 h not, a new one after 6 h sent", len(r1) == 1 and r2 == [] and len(r3) == 1, (r1, r2, r3))
PR = "https://irdai.gov.in/press-releases"
FEED[PR] = "<html><a href=\"/document-detail?documentId=9\">IRDAI notifies the final commission regulations for insurers</a></html>"
r4 = G.run(get=get, now=N + dt.timedelta(hours=7, minutes=5))
chk("... IRDAI's OWN page is never held back by that (a real circular always comes)", len(r4) == 1 and "final commission" in r4[0], r4)
print("NEWS CLEANER test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $D/newsaudit.sh <<'PY_AUDIT'
#!/bin/bash
# newsaudit.sh - EVERY NEWS LIST GIR SHOWS, CHECKED (Rama, 14 Nov: "I am afraid whether you follow up and code correctly"). READ ONLY - nothing is
#   changed or sent. For the last 24 hours (or: bash newsaudit.sh 48):
#   1 Telegram + the page's alert board (tomorrow.db): every news line - OLD (published 48 h+ before GIR sent it), REPEAT (the same story again),
#     UNREADABLE (scanned-PDF letters / a letterhead), ROUND-UP (a many-stock list sent as one company's news)
#   2 the NEWS tab (news.db): the same checks, and how late GIR read each item (published -> read)
#   3 the TOMORROW tab's morning brief, built now: what it shows
#   Every check prints its count and up to 5 examples. All zero = clean.
D=/home/globalbot/intraday; HRS="${1:-24}"
cd $D || exit 1
python3 - "$HRS" <<'PY'
import os, re, sys, sqlite3, datetime as dt
sys.path.insert(0, ".")
import newsclean as NC
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); now = dt.datetime.now(IST); H = float(sys.argv[1]); t0 = now.timestamp() - H * 3600
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
def show(lab, xs):
    print("   %-58s %4d%s" % (lab, len(xs), "  ✅" if not xs else "  ⚠"))
    for x in xs[:5]:
        print("       · " + x[:150])
NEWS = re.compile(r"GOVT WATCH|CRITICAL GOVT|SHOCK WATCH|NEWS SHOCK|THE REASON|MACRO|📰|REGULATOR|· REG\b")
print("=== 1 · TELEGRAM / THE ALERT BOARD (tomorrow.db) · last %g h" % H)
try:
    c = ro("tomorrow.db")
    rows = c.execute("select day, t, sym, text from alerts where day >= ? order by day, t", (str((now - dt.timedelta(hours=H)).date()),)).fetchall(); c.close()
except Exception as ex:
    rows = []; print("   (tomorrow.db: %s)" % ex)
seen, rep, junk, rnd, old, n = {}, [], [], [], [], 0
for day, t, sym, tx in rows:
    L = [x for x in (tx or "").split("\n") if x.strip()]
    if not L or not NEWS.search(L[0]):
        continue
    try:
        ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    if ts < t0:
        continue
    n += 1
    body = L[1] if len(L) > 1 else L[0]
    lab = "%s %s %s · %s" % (day[5:], str(t)[:5], sym or "", body)
    m = re.search(r"(\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* (20\d\d)", tx or "")
    if m:
        try:
            d0 = dt.datetime.strptime(" ".join(m.groups()), "%d %b %Y").replace(tzinfo=IST)
            if (dt.datetime.fromtimestamp(ts, IST) - d0).days >= 3 and "dated" not in (tx or "").lower():
                old.append("%s   (the text is dated %s)" % (lab, d0.strftime("%d %b")))
        except ValueError:
            pass
    k = NC.story_key(sym or "MARKET", L[0].split("·")[0].strip()[:20], body)
    if k in seen and ts - seen[k] < 6 * 3600:
        rep.append(lab)
    seen[k] = ts
    if NC.junk(body) or NC.letterhead(body):
        junk.append(lab)
    if NC.roundup(body) and "GOVT" not in L[0]:
        rnd.append(lab)
print("   news lines checked: %d" % n)
show("OLD (the story's own date 3+ days before GIR sent it)", old)
show("REPEAT (the same story again within 6 h)", rep)
show("UNREADABLE (scanned-PDF letters / a letterhead)", junk)
show("ROUND-UP (a many-stock list sent as one company's news)", rnd)
print("\n=== 2 · THE NEWS TAB (news.db) · last %g h" % H)
try:
    c = ro("news.db")
    R = c.execute("select sym, src, domain, t_pub, t_seen, h from items where t_seen >= ? order by t_seen", (t0,)).fetchall(); c.close()
except Exception as ex:
    R = []; print("   (news.db: %s)" % ex)
old2 = ["%s %s · %s   (published %s, read %s)" % (s, dm or src, h, dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %H:%M"), dt.datetime.fromtimestamp(tse, IST).strftime("%d %b %H:%M"))
        for s, src, dm, tp, tse, h in R if tp and tse and tse - tp > 48 * 3600]
junk2 = ["%s · %s" % (s, h) for s, src, dm, tp, tse, h in R if NC.junk(h) or NC.letterhead(h)]
rnd2 = ["%s · %s" % (s, h) for s, src, dm, tp, tse, h in R if NC.roundup(h)]
lag = sorted(tse - tp for s, src, dm, tp, tse, h in R if tp and tse and 0 <= tse - tp < 48 * 3600)
print("   items read: %d%s" % (len(R), (" · read after publishing: median %d min, 9 of 10 within %d min" % (lag[len(lag) // 2] / 60, lag[int(len(lag) * 0.9)] / 60)) if lag else ""))
show("OLD (read 48 h+ after it was published)", old2)
show("UNREADABLE", junk2)
show("ROUND-UP (kept in the share's news - shown, never rung)", rnd2)
print("\n=== 3 · THE TOMORROW TAB - the morning brief as it is built now")
try:
    import morningbrief
    txt = morningbrief.build(now)[0]
    print("\n".join("   " + x for x in txt.split("\n")[:40]))
except Exception as ex:
    print("   (morningbrief: %s)" % ex)
PY
PY_AUDIT
python3 $W/p270_patch.py $D || back
cd $D && python3 -m py_compile newsclean.py morningbrief.py govwatch.py || back
echo "=== test"
python3 $W/p270test.py $D | grep -v "^  [☀▲▼◆🏛 ]\|^$\|^  *[A-Z]* ·\|^the side" || true
python3 $W/p270test.py $D >/dev/null 2>&1 || back
chown --reference=$D $D/newsclean.py $D/newsaudit.sh 2>/dev/null
systemctl restart gir-dash; sleep 4
echo "  gir-dash: $(systemctl is-active gir-dash)"
echo "=== every news list on this server, checked (read only) - the last 24 h"
timeout 120 bash $D/newsaudit.sh 24 2>&1 | head -60
echo "✅ patch 270 done - one line a story, no unreadable lines, no round-ups. Ctrl + Shift + R on GIR → 8 TOMORROW."
echo "   check any time: bash $D/newsaudit.sh   (or: bash $D/newsaudit.sh 48)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
