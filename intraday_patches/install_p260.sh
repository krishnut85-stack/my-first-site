#!/bin/bash
# PATCH 260 - GOVT WATCH NEVER SENDS OLD NEWS (Rama, 14 Nov: "insurance regulatory news released in Sep is coming in now").
#   Three faults in govwatch.py: the IRDAI Google News search had no date limit (Google answers with stories months old) · no story was checked
#   for its age · the "already sent" memory kept 3,000 keys and, when full, threw away RANDOM ones - old stories came back as new.
#   Now: Google asked for 2 days · a dated story older than 48 h is never sent · an undated page item whose title dates it 30+ days back is never
#   sent · the same headline under a new link is not sent twice · the memory keeps the newest 20,000 in order · a page that suddenly lists 5+
#   "new" undated items is remembered, not sent · the first pass after install only remembers.
#   Tested: 14 cases. No restart - govwatch runs on its own 2-minute timer. Safe any time, market hours too.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $D/govwatch.py ] || { echo "govwatch.py missing"; exit 1; }
grep -q "patch 237" $D/govwatch.py || { echo "patch 237 first"; exit 1; }
cp $D/govwatch.py $D/govwatch.py.bak$TS
back(){ cp $D/govwatch.py.bak$TS $D/govwatch.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p260_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p260_patch.py - patch 260: GOVT WATCH sent September's IRDAI news in November (Rama, 14 Nov). Three faults in govwatch.py:
  1 the IRDAI Google News search had no date limit - Google answers with stories months old
  2 no story was checked for its age
  3 the "already sent" memory kept 3,000 keys and, when full, threw away RANDOM ones (a set has no order) - old stories came back as new
Now: Google asked for 2 days only · a dated story older than 48 h is never sent · an undated page item whose own title dates it 30+ days back is
never sent · the same headline under a new link is not sent again · the memory keeps the newest 20,000 in order · a page that suddenly lists
5+ "new" undated items at once (re-listed) is remembered, not sent · the first pass after install only remembers.   python3 p260_patch.py DIR"""
import os, sys
D = sys.argv[1]
p = os.path.join(D, "govwatch.py")
s = open(p, encoding="utf-8").read()
if "patch 260" in s:
    print("  govwatch.py: patch 260 - already in"); sys.exit(0)

HELP = '''class _OSet(dict):                                              # patch 260: the memory keeps its order (the oldest leave first)
    def add(self, k):
        self[k] = None


def _when(d):
    """patch 260: a feed's date text -> epoch seconds, or None"""
    if not d:
        return None
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(d).timestamp()
    except Exception:
        pass
    try:
        x = dt.datetime.fromisoformat(d.strip().replace("Z", "+00:00"))
        return (x if x.tzinfo else x.replace(tzinfo=IST)).timestamp()
    except Exception:
        return None


_MON = {m: i + 1 for i, m in enumerate("jan feb mar apr may jun jul aug sep oct nov dec".split())}


def _title_dates(title):
    """patch 260: the dates written in a title (12.09.2026 / 12-09-2026 / 12 September 2026 / September 12, 2026 / 2026-09-12)"""
    out = []
    for a, b, c in re.findall(r"\\b(\\d{1,2})[./-](\\d{1,2})[./-](20\\d\\d)\\b", title):
        out.append((int(c), int(b), int(a)))
    for a, b, c in re.findall(r"\\b(20\\d\\d)-(\\d{1,2})-(\\d{1,2})\\b", title):
        out.append((int(a), int(b), int(c)))
    for a, b, c in re.findall(r"\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+([A-Za-z]{3})[a-z]*\\.?,?\\s+(20\\d\\d)\\b", title):
        if b.lower() in _MON:
            out.append((int(c), _MON[b.lower()], int(a)))
    for b, a, c in re.findall(r"\\b([A-Za-z]{3})[a-z]*\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(20\\d\\d)\\b", title):
        if b.lower() in _MON:
            out.append((int(c), _MON[b.lower()], int(a)))
    ok = []
    for y, m, d_ in out:
        try:
            ok.append(dt.datetime(y, m, d_, tzinfo=IST))
        except ValueError:
            pass
    return ok


def _is_old(d, title, now):
    """patch 260: True = an old story - remembered, never sent. A dated story: older than 48 h. An undated one: its title's newest date 30+ days back."""
    t = _when(d)
    if t is not None:
        return now.timestamp() - t > 48 * 3600
    ds = _title_dates(title)
    return bool(ds) and (now - max(ds)).days >= 30


def _tkey(src, title):
    """patch 260: the same headline under a new link (Google News changes links) is the same story"""
    t = re.sub(r"\\s+-\\s+[^-]{2,40}$", "", title.lower())
    return (src + ":t:" + re.sub(r"[^a-z0-9]+", " ", t).strip())[:300]


def run('''

EDITS = [
    ('("IRDAI", "https://news.google.com/rss/search?q=IRDAI&hl=en-IN&gl=IN&ceid=IN:en"),',
     '("IRDAI", "https://news.google.com/rss/search?q=IRDAI+when:2d&hl=en-IN&gl=IN&ceid=IN:en"),   # patch 260: 2 days only',
     "the IRDAI Google search asks for 2 days only"),
    ("def run(", HELP, "the age check, the headline key, the ordered memory"),
    ('    seen = set(S.get("seen") or [])', '    seen = _OSet.fromkeys(S.get("seen") or [])', "the memory keeps its order"),
    ("        for title, link, d in its[:40]:", "        n0 = len(out)                                           # patch 260\n        for title, link, d in its[:40]:",
     "count what one page brings"),
    ("            seen.add(key)\n", "            seen.add(key)\n            tk = _tkey(src, title)                              # patch 260: same headline, new link\n"
     "            if tk in seen:\n                continue\n            seen.add(tk)\n            if _is_old(d, title, now):                          # patch 260: an old story - never sent\n"
     "                continue\n", "old stories and repeated headlines are not sent"),
    ("            if j and not S.get(\"first\") and not first_src:", "            if j and not S.get(\"first\") and not first_src and S.get(\"p260\"):",
     "the first pass after install only remembers"),
    ("    if probe:\n        return report", "        if its and not any(x[2] for x in its[:40]) and len(out) - n0 >= 5:   # patch 260: a re-listed page - remember, don't send\n"
     "            report.append(\"      %d 'new' undated items at once - a re-listed page, remembered, not sent\" % (len(out) - n0))\n            del out[n0:]\n"
     "    if probe:\n        return report", "a re-listed page is remembered, not sent"),
    ('    S["first"] = False\n', '    S["first"] = False\n    S["p260"] = True\n', "mark the first pass done"),
    ('    S["seen"] = list(seen)[-3000:]', '    S["seen"] = list(seen)[-20000:]                       # patch 260: the newest 20,000, in order', "keep the newest 20,000"),
]
for old, new, tag in EDITS:
    n = s.count(old)
    if n != 1:
        print("❌ govwatch.py: anchor for '%s' found %d times (needs 1)" % (tag, n)); sys.exit(1)
    s = s.replace(old, new)
    print("  govwatch.py: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("govwatch.py: patch 260 in")
PY_PATCH
cat > $W/p260test.py <<'PY_TEST'
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
PY_TEST
python3 $W/p260_patch.py $D || back
cd $D && python3 -m py_compile govwatch.py || back
echo "=== test"
python3 $W/p260test.py $D || back
echo "=== what the feeds answer now (read only, nothing sent or saved)"
timeout 60 python3 govwatch.py probe 2>&1 | grep -i "irdai\|rbi\|sebi" | cut -c1-150
echo "✅ patch 260 done - old news is never sent again. The next 2-minute pass only remembers; after that only fresh stories."
echo "   undo: cp $D/govwatch.py.bak$TS $D/govwatch.py"
