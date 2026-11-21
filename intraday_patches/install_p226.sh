#!/bin/bash
# PATCH 226 - IRDAI in the GOVT WATCH (Rama, 12 Nov: "yes add IRDAI") + the EXIT WATCH's default stop.
#   govwatch: IRDAI's own pages (press releases, circulars, notifications) every 2 minutes + a news search on "IRDAI". Each item touches
#     INSURANCE (POLICYBZR · LICI · SBILIFE · HDFCLIFE · ICICIPRULI · ICICIGI). 🚨 CRITICAL for commission / expenses of management / surrender /
#     bancassurance / composite licence / Bima Sugam / solvency / FDI / new regulations, or one naming a listed insurer; the rest a quiet line.
#     Its first read only remembers what is there (no flood of old circulars). Then this script asks IRDAI live and shows what it answers.
#   exitwatch: a P1 call with no stop (the opening calls) gets a stop 1% against it (TATAPOWER / COCHINSHIP 12 Nov: no exit until 15:05).
#   Tested: 10 cases. Restarts the news hunt only (the exit watch) - after 15:35 (or add: now). The govt watch is a 2-minute timer (no restart).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="govwatch.py"; [ -f $D/exitwatch.py ] && F="$F exitwatch.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-newshunt 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p226_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p226_patch.py - PATCH 226: IRDAI in the GOVT WATCH (Rama, 12 Nov: "yes add IRDAI" - the insurance regulator moves POLICYBZR, LICI, SBILIFE,
HDFCLIFE, ICICIPRULI, ICICIGI ...) + the EXIT WATCH's default stop.
  govwatch   IRDAI's own pages (press releases, circulars, notifications - read as a list of documents, no feed needed) + a news search on
             "IRDAI" as the second source. Every IRDAI item touches INSURANCE (+ POLICYBZR). 🚨 CRITICAL when it changes the business
             (commission, expenses of management, surrender value, bancassurance, composite licence, Bima Sugam, solvency, FDI, new
             regulations / master circulars / exposure drafts) or names a listed F&O insurer. A new source's first read only remembers.
  exitwatch  a P1 call without a stop (the opening calls) gets a stop 1% against it (12 Nov: TATAPOWER -1.8%, COCHINSHIP -1.4% - no exit
             until 15:05)
Usage: python3 p226_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, need=True):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        (ERR.append("%s missing" % f) if need else print("  %s: not here - skipped" % f)); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("govwatch.py", '''    ("SEBI", "https://www.sebi.gov.in/sebirss.xml"),
]''', '''    ("SEBI", "https://www.sebi.gov.in/sebirss.xml"),
    ("IRDAI", "https://irdai.gov.in/press-releases"),            # patch 226: the insurance regulator - its own pages
    ("IRDAI", "https://irdai.gov.in/circulars"),
    ("IRDAI", "https://irdai.gov.in/notifications"),
    ("IRDAI", "https://news.google.com/rss/search?q=IRDAI&hl=en-IN&gl=IN&ceid=IN:en"),
]
IRDAI_CRIT = re.compile(r"commission|expenses? of management|\\beom\\b|surrender|bancassurance|composite licen|bima sugam|solvency|\\bfdi\\b|"
                        r"master circular|exposure draft|regulations,? 20\\d\\d|\\bamend|life insurance corporation|\\blic\\b|sbi life|hdfc life|"
                        r"icici prudential|icici lombard|pb fintech|policybazaar|star health|new india assurance|general insurance corporation", re.I)
INS_SH = ["POLICYBZR", "LICI", "SBILIFE", "HDFCLIFE", "ICICIPRULI", "ICICIGI"]''', "IRDAI sources")
rep("govwatch.py", '''def items(xml_text):''', '''def html_items(txt, url):
    """patch 226: a regulator's page with no feed (IRDAI) -> its documents: [(title, link, "")] - the links to documents / PDFs"""
    out, seen = [], set()
    base = re.match(r"https?://[^/]+", url).group(0)
    for href, inner in re.findall(r'<a\\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>', txt or "", re.S | re.I):
        if not re.search(r"document-detail|documentId=|\\.pdf\\b|/documents?/", href, re.I):
            continue
        t = html.unescape(re.sub(r"<[^>]+>", " ", inner))
        t = re.sub(r"\\s+", " ", t).strip()
        if len(t) < 15 or re.match(r"(?i)(download|view|read more|click here|pdf)\\b", t):
            continue
        link = href if href.startswith("http") else base + ("" if href.startswith("/") else "/") + href
        if link in seen:
            continue
        seen.add(link)
        out.append((t, link, ""))
    return out


def items(xml_text):''', "html_items(): a page with no feed")
rep("govwatch.py", '''        its = items(txt) if txt else []''', '''        its = items(txt) if txt else []
        if not its and txt and re.search(r"<html|<a\\b", txt[:5000], re.I):  # patch 226: a page, not a feed
            its = html_items(txt, url)
        first_src = src not in (S.get("srcs") or ["PIB", "RBI", "SEBI"])   # patch 226: a new source's first read only remembers (no flood)''', "read pages too · a new source starts quiet")
rep("govwatch.py", '''            j = judge(read, M)''', '''            if src == "IRDAI":                                  # patch 226: everything IRDAI says touches insurance
                read = "irdai insurance " + read
            j = judge(read, M)
            if j and src == "IRDAI":
                j = (bool(j[0]) or bool(IRDAI_CRIT.search(title)), j[1], (INS_SH + [x for x in j[2] if x not in INS_SH])[:8])''', "IRDAI: insurance shares, its own critical words")
rep("govwatch.py", '''            if j and not S.get("first"):''', '''            if j and not S.get("first") and not first_src:''', "no flood from a new source")
rep("govwatch.py", '''    S["first"] = False''', '''    S["first"] = False
    S["srcs"] = sorted(set((S.get("srcs") or []) + [s_ for s_, _u in SOURCES]))''', "remember the sources read")
rep("exitwatch.py", '''        if stop and (stop - entry) * d >= 0:
            stop = None                                         # a stop on the wrong side of the price is not a stop''', '''        if stop and (stop - entry) * d >= 0:
            stop = None                                         # a stop on the wrong side of the price is not a stop
        if not stop:
            stop = round(entry * (1 - 0.01 * d), 2)             # patch 226: no stop given (the opening calls) - 1% against it''', "a default stop: 1% against", need=False)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 226 in")
PY_PATCH
cat > $W/p226test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p226test.py - IRDAI in the GOVT WATCH + the exit watch's default stop (made-up pages, temp folder, nothing sent).  python3 p226test.py DIR"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("govwatch.py", "exitwatch.py", "alertword.py"):
    if os.path.exists(os.path.join(D, f)):
        shutil.copy(os.path.join(D, f), T)
open(os.path.join(T, "sectors.py"), "w").write("def load():\n    return {'insurance': ['LICI', 'SBILIFE', 'HDFCLIFE', 'ICICIPRULI', 'ICICIGI'], 'banks': ['SBIN']}\n")
sys.path.insert(0, T); os.chdir(T)
import govwatch as G
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 13, 11, 0, tzinfo=IST)
rss = lambda items: "<rss><channel>" + "".join("<item><title>%s</title><link>%s</link></item>" % (t, l) for t, l in items) + "</channel></rss>"
page = lambda docs: "<html><body>" + "".join('<a href="/document-detail?documentId=%d">%s</a> <a href="/x.pdf">Download</a>' % (i, t) for i, t in docs) + "</body></html>"
PAGES = {"pib": rss([("Cabinet approves Rs 37,000 crore nutrient based subsidy", "p1")]), "irdai_pr": page([(1, "IRDAI releases Annual Report 2025-26 of the Authority")]),
         "irdai_c": page([(2, "Guidelines on Product Filing for health insurance products")]), "gnews": rss([("IRDAI chairman speaks at insurance summit", "g1")])}
def get(u):
    if "pib.gov" in u: return PAGES["pib"]
    if "press-releases" in u: return PAGES["irdai_pr"]
    if "circulars" in u: return PAGES["irdai_c"]
    if "news.google" in u: return PAGES["gnews"]
    return rss([])
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:500]))
json.dump({"seen": [], "first": False}, open(G.SEEN, "w"))          # the watch has run before (PIB / RBI / SEBI known), IRDAI is new
out = G.run(get=get, now=NOW)
chk("the first pass after the patch: IRDAI only remembers (no flood of old circulars)", not any("IRDAI" in x for x in out), [x.split("\n")[0] for x in out])
chk("... and PIB / RBI / SEBI are NOT silenced by the new source (the Cabinet subsidy still said)", any("PIB" in x and "subsidy" in x for x in out), [x.split("\n")[0] for x in out])
chk("IRDAI's pages were read as lists of documents (no feed)", len(G.html_items(PAGES["irdai_pr"], "https://irdai.gov.in/press-releases")) == 1 and
    G.html_items(PAGES["irdai_pr"], "https://irdai.gov.in/press-releases")[0][1] == "https://irdai.gov.in/document-detail?documentId=1")
PAGES["irdai_pr"] = page([(3, "Exposure Draft - IRDAI (Expenses of Management, including Commission, of Insurers) Regulations, 2026"),
                          (4, "Order in the matter of M/s XYZ Insurance Brokers Pvt Ltd"), (1, "IRDAI releases Annual Report 2025-26 of the Authority")])
PAGES["gnews"] = rss([("IRDAI's insurance overhaul pushes PB Fintech to non-insurance services - MediaNama", "g2"), ("IRDAI chairman speaks at insurance summit", "g1")])
out = G.run(get=get, now=NOW)
h = {x.split("\n")[1][:40]: x for x in out}
ex = next((x for x in out if "Expenses of Management" in x), "")
chk("an exposure draft on commission / expenses: 🚨 CRITICAL GOVT · IRDAI, touches INSURANCE", ex.startswith("🚨 CRITICAL GOVT · IRDAI") and "INSURANCE" in ex, ex)
chk("... the F&O shares to watch start with POLICYBZR · LICI · SBILIFE · HDFCLIFE", "F&O shares to watch: POLICYBZR · LICI · SBILIFE · HDFCLIFE" in ex, ex)
br = next((x for x in out if "XYZ Insurance Brokers" in x), "")
chk("an order on a small broker: a quiet 🏛 GOVT WATCH line, not critical", br.startswith("🏛 GOVT WATCH · IRDAI"), br)
pb = next((x for x in out if "PB Fintech" in x), "")
chk("the news: 'IRDAI ... pushes PB Fintech ...' -> 🚨 CRITICAL (it names a listed F&O insurer)", pb.startswith("🚨 CRITICAL GOVT · IRDAI"), pb)
chk("nothing said twice (the annual report, the summit)", not any("Annual Report" in x or "summit" in x for x in out), [x.split("\n")[1][:50] for x in out])
if os.path.exists("exitwatch.py"):
    import exitwatch as X
    N = 75; c = [1212.0] * N
    for j in range(2, N): c[j] = round(1212.0 - (j - 1) * 2.0, 2)            # COCHINSHIP after a 09:20 CE call: down ~0.17% a candle
    json.dump({"COCHINSHIP": {"c": c, "h": c, "l": c, "v": [1000] * N}}, open("charts.json", "w"))
    db = sqlite3.connect("tomorrow.db"); db.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    db.execute("insert into alerts values ('2026-11-12', '09:20', '', 'COCHINSHIP', 'CE', '⚡ ENTER NOW ▲ COCHINSHIP CE · ₹1,212 · 09:20\n▶ BUY 1220 CE ~₹31 · stop: half the premium')"); db.commit(); db.close()
    R = X.replay("2026-11-12", is_p1=lambda t: "BUY" in t)
    c0, ev, _ = R[0]
    chk("exit watch: an opening call with no stop gets one 1% against (₹1,200)", abs(c0["stop"] - 1199.88) < 0.01, c0["stop"])
    chk("... and COCHINSHIP falling gets 🛑 EXIT - STOP, not silence until 15:05", ev and "EXIT - STOP" in ev[0][1] and ev[0][0] <= "10:00", ev)
print("IRDAI + DEFAULT STOP test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p226_patch.py $D || back
cd $D && python3 -m py_compile govwatch.py || back
[ -f exitwatch.py ] && { python3 -m py_compile exitwatch.py || back; }
echo "=== test: IRDAI pages + the default stop (made-up pages)"
python3 $W/p226test.py $D || back
echo "=== IRDAI live, from this server (what each source answers now - nothing sent)"
cd $D && timeout 90 python3 govwatch.py probe 2>&1 | grep -E "IRDAI" | cut -c1-200 | sed 's/^/   /'
echo "   (a page with 0 items: IRDAI changed its page - send me this and I adjust it; the news search still covers IRDAI)"
systemctl restart gir-newshunt 2>/dev/null; sleep 6; echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
[ "$(systemctl is-active gir-newshunt)" = "active" ] || back
echo "✅ patch 226 done - IRDAI is read every 2 minutes (🚨 CRITICAL GOVT · IRDAI / 🏛 GOVT WATCH · IRDAI); opening calls get a 1% stop."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-newshunt"
