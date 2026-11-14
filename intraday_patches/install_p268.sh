#!/bin/bash
# PATCH 268 - GOVT WATCH KNOWS MORE OF THE ECONOMY AND DROPS NOTHING BIG (Rama, 14 Nov: "6 PLI-approved textile stocks to watch as India eases incentive
#   rules - are we reading this? the news reader lacks knowledge"). govwatch had no textile topic; a policy headline matching none of its 15 topics
#   was DROPPED; it read the official sites only. Now: 8 more topics with their F&O shares (textiles: GRASIM viscose, SRF technical textiles, PAGEIND,
#   TRENT, ABFRL, RELIANCE polyester · electronics · aviation · real estate · shipping · jewellery / gold duty · hotels · EV) · a big-policy headline
#   (PLI, duty, ban, Cabinet, ₹5,000 cr+) with no known topic is still sent ("sector not known to GIR") · a new source: Google News policy stories
#   (last day; a "stocks to watch" story is not CRITICAL, a Cabinet decision is). Tested: 9 cases + patch 260's 14. No restart (2-minute timer).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 260" $D/govwatch.py || { echo "patch 260 first"; exit 1; }
cp $D/govwatch.py $D/govwatch.py.bak$TS
back(){ cp $D/govwatch.py.bak$TS $D/govwatch.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p268_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p268_patch.py - patch 268: GOVT WATCH knows more of the economy and drops nothing big (Rama, 14 Nov: "6 PLI-approved textile stocks to watch as
India eases incentive rules - are we reading this kind of message? the news reader lacks knowledge"). govwatch.py had no textile topic, and a policy
headline that matched none of its 15 topics was DROPPED; it read the official sites only, not the news sites' policy stories.
  more topics -> their F&O shares: textiles (GRASIM viscose, SRF technical textiles, PAGEIND, TRENT, ABFRL, RELIANCE polyester) · electronics /
  semiconductors (DIXON, KAYNES, AMBER, PGEL) · aviation · real estate · shipping / ports · jewellery / gold duty · hotels / tourism · EV
  a big-policy headline (PLI, duty, ban, Cabinet, ₹5,000 cr+) with no known topic: still sent, "sector not known to GIR" - never dropped
  a new source: Google News policy stories (PLI, Cabinet, duties, ministry schemes) - last day only; a "stocks to watch" story is not CRITICAL
python3 p268_patch.py DIR"""
import os, sys
D = sys.argv[1]
p = os.path.join(D, "govwatch.py"); s = open(p, encoding="utf-8").read()
if "patch 268" in s:
    print("  govwatch.py: patch 268 - already in"); sys.exit(0)
if "patch 260" not in s:
    print("❌ govwatch.py: patch 260 first"); sys.exit(1)
X = 'EXTRA_SH = {"fertiliser": ["COROMANDEL", "CHAMBLFERT", "UPL", "PIIND", "DEEPAKFERT"]}'
X2 = X + '''
EXTRA_SH.update({                                                  # patch 268: the shares of topics GIR's sector map does not have
    "textiles": ["GRASIM", "SRF", "PAGEIND", "TRENT", "ABFRL", "RELIANCE"],
    "electronics": ["DIXON", "KAYNES", "AMBER", "PGEL", "CGPOWER"],
    "aviation": ["INDIGO", "GMRAIRPORT"],
    "real-estate": ["DLF", "LODHA", "GODREJPROP", "OBEROIRLTY", "PRESTIGE", "PHOENIXLTD"],
    "shipping": ["MAZDOCK", "COCHINSHIP", "ADANIPORTS", "CONCOR"],
    "jewellery": ["TITAN", "KALYANKJIL", "MUTHOOTFIN", "MANAPPURAM"],
    "hotels": ["INDHOTEL", "IRCTC"],
    "ev": ["TATAMOTORS", "M&M", "TVSMOTOR", "BAJAJ-AUTO", "EXIDEIND", "SONACOMS"]})
TOPICS += [                                                         # patch 268
    (r"textile|apparel|garment|man-?made fibre|\\bmmf\\b|viscose|polyester|cotton|yarn|handloom|technical textile", ["textiles"]),
    (r"semiconductor|electronics? (?:component|manufactur|scheme|pli)|mobile phone|smartphone|\\besdm\\b|display fab|\\bchips?\\b", ["electronics"]),
    (r"aviation|airline|airport|\\bdgca\\b|\\batf\\b|jet fuel|udan", ["aviation"]),
    (r"real estate|\\brera\\b|affordable housing|stamp duty|home loan", ["real-estate"]),
    (r"shipbuild|shipping|\\bports?\\b|maritime|sagarmala", ["shipping"]),
    (r"jewell?ery|gold import|gold duty|duty on gold|\\bgold\\b.{0,25}\\bduty|hallmark|bullion", ["jewellery"]),
    (r"tourism|hotel|hospitality", ["hotels"]),
    (r"electric vehicle|\\bev\\b policy|\\bfame\\b|pm e-drive|battery storage|\\bacc\\b battery", ["ev"])]'''
Y = '''    ("IRDAI", "https://news.google.com/rss/search?q=IRDAI+when:2d&hl=en-IN&gl=IN&ceid=IN:en"),   # patch 260: 2 days only'''
Y2 = Y + '''
    ("POLICY", "https://news.google.com/rss/search?q=%22PLI%22+OR+%22Cabinet+approves%22+OR+%22customs+duty%22+OR+%22import+duty%22+OR+%22export+duty%22+OR+%22incentive+scheme%22+when:1d&hl=en-IN&gl=IN&ceid=IN:en"),   # patch 268: the news sites' policy stories'''
Z = 'if __name__ == "__main__":'
Z2 = '''_judge268, _line268 = judge, line                                  # patch 268


def _fo268():
    try:
        import sqlite3
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)
        v = {r[0] for r in c.execute("select sym from fo_list")}; c.close(); return v
    except Exception:
        return set()


def judge(title, M):
    """patch 268: a known topic -> its F&O shares only · a big-policy headline with no known topic -> still sent (never dropped)"""
    j = _judge268(title, M)
    if j:
        fo = _fo268()
        return (j[0], j[1], [x for x in j[2] if not fo or x in fo][:8])
    if CRIT.search(title) or CAB.search(title) or amount_cr(title) >= 5000:
        return (False, ["sector not known to GIR - read it"], [])
    return None


def line(src, title, link, crit, secs, shares, now):
    """patch 268: a news site's 'stocks to watch' story is information, not a CRITICAL line (unless a Cabinet decision / ₹5,000 cr+)"""
    if src == "POLICY" and crit and not (CAB.search(title) or amount_cr(title) >= 5000):
        crit = False
    return _line268(src, title, link, crit, secs, shares, now)


''' + Z
for o, n, tag in ((X, X2, "8 more topics: textiles, electronics, aviation, real estate, shipping, jewellery, hotels, EV"),
                  (Y, Y2, "a new source: the news sites' policy stories (last day)"),
                  (Z, Z2, "nothing big dropped · F&O shares only · 'stocks to watch' not critical")):
    if s.count(o) != 1:
        print("❌ govwatch.py: anchor for '%s' found %d times" % (tag, s.count(o))); sys.exit(1)
    s = s.replace(o, n); print("  govwatch.py: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("govwatch.py: patch 268 in")
PY_PATCH
cat > $W/p268test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p268test.py - GOVT WATCH's wider knowledge (made-up feeds on a temp copy, nothing sent).  python3 p268test.py DIR"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = sys.argv[1]; T = tempfile.mkdtemp()
shutil.copy(os.path.join(SRC, "govwatch.py"), T); os.makedirs(os.path.join(T, "data"))
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text)")
c.executemany("insert into fo_list values (?)", [(s,) for s in "GRASIM SRF PAGEIND TRENT ABFRL RELIANCE DIXON KAYNES AMBER INDIGO GMRAIRPORT TITAN KALYANKJIL".split()]); c.commit(); c.close()
sys.path.insert(0, T)
import govwatch as G
G.fo_map = lambda: {}
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 14, 11, 50, tzinfo=IST)
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   -> %s" % (got,)))
j = G.judge("Ministry of Textiles reopens PLI scheme Round 4, lowers turnover requirement for MMF apparel makers", {})
chk("a textile PLI headline: topic textiles -> GRASIM, SRF, PAGEIND, TRENT... (it was dropped before)", j and "textiles" in j[1] and j[2][:2] == ["GRASIM", "SRF"], j)
j = G.judge("Government approves Rs 22,919 crore scheme for electronics component manufacturing", {})
chk("electronics components scheme -> DIXON, KAYNES, AMBER (F&O only - PGEL / CGPOWER are not in this F&O list)", j and "electronics" in j[1] and j[2] == ["DIXON", "KAYNES", "AMBER"], j)
j = G.judge("Customs duty on gold cut to 6% in a surprise move", {})
chk("gold duty -> jewellery: TITAN, KALYANKJIL", j and "jewellery" in j[1] and "TITAN" in j[2], j)
j = G.judge("Government notifies ban on exports of a new item", {})
chk("a big-policy word (ban) with no known topic: still sent - 'sector not known to GIR'", j and j[1] == ["sector not known to GIR - read it"] and j[0] is False, j)
chk("an ordinary headline with no topic and no policy word: nothing", G.judge("Minister inaugurates a museum in Delhi", {}) is None)
POL = [u for s, u in G.SOURCES if s == "POLICY"]
chk("a new source: the news sites' policy stories, last day only", POL and "when:1d" in POL[0], POL)
rfc = lambda x: x.strftime("%a, %d %b %Y %H:%M:%S +0530")
FEED = {}
get = lambda u: FEED.get(u, "<rss><channel></channel></rss>")
rss = lambda items: "<rss><channel>" + "".join("<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>" % i for i in items) + "</channel></rss>"
json.dump({"seen": [], "first": False, "p260": True, "srcs": sorted({s for s, _ in G.SOURCES} - {"POLICY"})}, open(G.SEEN, "w"))
FEED[POL[0]] = rss([("Old story - Moneycontrol", "https://n/0", rfc(NOW))])
chk("the new source's first read only remembers (no flood)", G.run(get=get, now=NOW) == [])
FEED[POL[0]] = rss([("6 PLI-approved textile stocks to watch as India eases incentive rules - Financial Express", "https://n/1", rfc(NOW - dt.timedelta(hours=1)))])
r = G.run(get=get, now=NOW)
chk("the Financial Express story: 🏛 GOVT WATCH · POLICY, touches TEXTILES, shares GRASIM · SRF ... - not CRITICAL (a 'to watch' story)",
    len(r) == 1 and r[0].startswith("🏛 GOVT WATCH · POLICY") and "TEXTILES" in r[0] and "GRASIM" in r[0], r)
print("\n" + (r[0] if r else "") + "\n")
FEED[POL[0]] = rss([("Cabinet approves Rs 12,000 crore PLI for textiles - ET", "https://n/2", rfc(NOW - dt.timedelta(minutes=10)))])
r = G.run(get=get, now=NOW)
chk("a Cabinet decision from a news site stays 🚨 CRITICAL", len(r) == 1 and r[0].startswith("🚨 CRITICAL GOVT · POLICY"), r)
print("GOVT WATCH knowledge test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p260test.py <<'PY_T260'
#!/usr/bin/env python3
"""p260test.py - GOVT WATCH never sends old news (made-up feeds on a temp copy, nothing sent).  python3 p260test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = sys.argv[1]
T = tempfile.mkdtemp()
shutil.copy(os.path.join(SRC, "govwatch.py"), T)
os.makedirs(os.path.join(T, "data"))
sys.path.insert(0, T)
import govwatch as G
G.fo_map = lambda: {}
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime(2026, 11, 14, 10, 0, tzinfo=IST)
rfc = lambda x: x.strftime("%a, %d %b %Y %H:%M:%S +0530")
OK = []
def chk(name, cond, extra=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   -> %s" % (extra,)))

GN = [u for s_, u in G.SOURCES if "news.google" in u][0]
FEED = {}
def rss(items):
    return "<rss><channel>" + "".join("<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>" % i for i in items) + "</channel></rss>"
def page(items):
    return "<html><body>" + "".join('<a href="/document-detail?documentId=%s">%s</a>' % (k, t) for k, t in items) + "</body></html>"
def get(url):
    return FEED.get(url, "<rss><channel></channel></rss>")
def run(now=NOW):
    return G.run(get=get, now=now)

chk("the IRDAI Google search asks for 2 days only", "when:2d" in GN, GN)
# install: an old state (patch 237's memory) - the first pass only remembers
json.dump({"seen": ["IRDAI:x%d" % i for i in range(10)], "first": False, "srcs": sorted({s for s, _ in G.SOURCES})}, open(G.SEEN, "w"))
FEED[GN] = rss([("IRDAI eases commission rules for insurers - ET", "https://news.google.com/a1", rfc(NOW - dt.timedelta(hours=1)))])
r = run()
chk("first pass after install: remembers, sends nothing", r == [], r)
# September's story, comes back in November
FEED[GN] = rss([("IRDAI proposes bancassurance changes - Mint", "https://news.google.com/sep1", rfc(dt.datetime(2026, 9, 18, 11, 0, tzinfo=IST)))])
r = run()
chk("a story from 18 Sep (dated) is NOT sent", r == [], r)
FEED[GN] = rss([("IRDAI surrender value norms tightened - BS", "https://news.google.com/old3", rfc(NOW - dt.timedelta(hours=60)))])
chk("a story 60 h old is NOT sent", run() == [])
FEED[GN] = rss([("IRDAI master circular on expenses of management - ET", "https://news.google.com/new1", rfc(NOW - dt.timedelta(minutes=20)))])
r = run()
chk("a story 20 min old IS sent (CRITICAL, insurance shares)", len(r) == 1 and "CRITICAL GOVT" in r[0] and "POLICYBZR" in r[0], r)
FEED[GN] = rss([("IRDAI master circular on expenses of management - Moneycontrol", "https://news.google.com/new1-other-link", rfc(NOW - dt.timedelta(minutes=18)))])
chk("the same headline under a new link: NOT sent again", run() == [])
FEED[GN] = rss([("IRDAI composite licence draft out", "https://news.google.com/atom1", (NOW - dt.timedelta(days=50)).isoformat())])
chk("an old ISO (Atom) date: NOT sent", run() == [])
FEED[GN] = rss([("IRDAI fdi review meeting", "https://news.google.com/bad", "sometime")])
chk("a date GIR cannot read: still sent (never lose a real one)", len(run()) == 1)
# IRDAI's own pages (no dates)
PR = "https://irdai.gov.in/press-releases"
FEED[PR] = page([("d1", "Corrigendum to the circular on surrender value dated 12.09.2026")])
chk("an undated page item dated 12.09.2026 in its title: NOT sent", run() == [])
FEED[PR] = page([("d2", "IRDAI notifies Insurance (Amendment) Regulations on commission limits")])
r = run()
chk("an undated new page item: sent", len(r) == 1 and "commission" in r[0], r)
FEED[PR] = page([("e%d" % i, "IRDAI notification number %d on solvency margins for insurers" % i) for i in range(7)])
chk("a page that suddenly lists 7 'new' undated items (re-listed): none sent", run() == [])
FEED[PR] = page([("e%d" % i, "IRDAI notification number %d on solvency margins for insurers" % i) for i in range(7)])
chk("... and they stay remembered next pass", run() == [])
# the memory: in order, the newest kept
S = json.load(open(G.SEEN)); S["seen"] = ["OLD:%d" % i for i in range(25000)] + S["seen"]; json.dump(S, open(G.SEEN, "w"))
FEED[GN] = rss([("IRDAI eases commission rules for insurers - ET", "https://news.google.com/a1", rfc(NOW - dt.timedelta(hours=1)))])
run()
S = json.load(open(G.SEEN))
chk("the memory keeps the newest 20,000 in order (the oldest leave first)", len(S["seen"]) == 20000 and "OLD:0" not in S["seen"]
    and "IRDAI:https://news.google.com/new1" in S["seen"] and S["seen"][-1].startswith("IRDAI:"), (len(S["seen"]), S["seen"][-2:]))
FEED[GN] = rss([("IRDAI master circular on expenses of management - ET", "https://news.google.com/new1", rfc(NOW - dt.timedelta(minutes=20)))])
chk("a story sent earlier is still remembered after the trim", run() == [])
print("GOVT WATCH old-news test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_T260
python3 $W/p268_patch.py $D || back
cd $D && python3 -m py_compile govwatch.py || back
echo "=== test"
python3 $W/p268test.py $D || back
python3 $W/p260test.py $D | tail -1 | grep -q "14 of 14" || { echo "  patch 260's old-news test no longer passes"; back; }
echo "  patch 260's old-news test: still 14 of 14 ✓"
echo "=== what the feeds answer now (read only, nothing sent or saved)"
timeout 60 python3 govwatch.py probe 2>&1 | grep -i "policy\|irdai.*google" | cut -c1-160
echo "✅ patch 268 done - GOVT WATCH reads policy for 8 more sectors and the news sites; nothing big dropped. The new source's first pass only remembers."
echo "   undo: cp $D/govwatch.py.bak$TS $D/govwatch.py"
