#!/bin/bash
# PATCH 183 - REGULATOR WATCH reads the RULE CHANGES for a whole sector: IRDAI's paper of 23 Sep 2026 ("Recalibrating the Economics of
#   Insurance Distribution") named no company, so it would not have rung - POLICYBZR fell 36% the next morning. Now a consultation
#   paper / draft / circular / bill that touches a sector rings: ⚠️ SHOCK WATCH · ◆ INSURANCE · RULE CHANGE - touches POLICYBZR · HDFCLIFE ...
#   + the draft / consultation pages of IRDAI, SEBI, RBI, CERC (power exchanges - IEX), PNGRB (city gas), NPPA (drug prices), TRAI,
#   DGCA, and PARLIAMENT's bills (PRS, Lok Sabha, Rajya Sabha). Pages read for the first time only remember (no flood). No restart.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S)
[ -f $D/regwatch.py ] || { echo "install_p163 first"; exit 1; }
cp $D/regwatch.py $D/regwatch.py.bak$TS
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
    # patch 183: draft rules / consultation papers - where a rule change for a whole sector appears first
    ("IRDAI", "https://irdai.gov.in/exposure-drafts"), ("IRDAI", "https://irdai.gov.in/consultation-papers"),
    ("SEBI", "https://www.sebi.gov.in/sebiweb/home/HomeAction.do?doListing=yes&sid=1&ssid=7&smid=0"),
    ("RBI", "https://www.rbi.org.in/Scripts/DraftNotificationsGuildelines.aspx"), ("RBI", "https://www.rbi.org.in/Scripts/NotificationUser.aspx"),
    ("CERC", "https://cercind.gov.in/recent_orders.html"), ("CERC", "https://cercind.gov.in/draft_reg.html"), ("CERC", "https://cercind.gov.in/"),
    ("PNGRB", "https://www.pngrb.gov.in/eng-web/whats-new.html"), ("NPPA", "https://www.nppaindia.nic.in/en/"),
    ("TRAI", "https://www.trai.gov.in/consultation-paper"), ("DGCA", "https://www.dgca.gov.in/digigov-portal/"),
    # Parliament: the bills (introduced / passed) - PRS keeps a clean tracker; Sansad the official lists
    ("PARLIAMENT", "https://prsindia.org/billtrack"), ("PARLIAMENT", "https://sansad.in/ls/legislation/bills"), ("PARLIAMENT", "https://sansad.in/rs/legislation/bills"),
]
# patch 183: a rule change for a WHOLE SECTOR names no company (IRDAI, 23 Sep 2026: "Recalibrating the Economics of Insurance
# Distribution" -> POLICYBZR -36% next morning). (sector, the words, the F&O shares it touches)
RULE = re.compile(r"consultation|exposure draft|\bdraft\b|regulations?,? 20\d\d|amendment|master direction|circular|guidelines|framework|"
                  r"proposes?|proposal|\bbill\b|act,? 20\d\d|notification|order in|recalibrat|review of|cap(s|ping)? on|ceiling", re.I)
SECTORS = [
    ("INSURANCE", r"insuran|insurer|intermediar|bancassurance|\bbima\b|commission|distribution of insurance|motor (third|tp)|health cover",
     "POLICYBZR HDFCLIFE SBILIFE ICICIPRULI LICI ICICIGI STARHEALTH NIACL GICRE MFSL"),
    ("CAPITAL MARKETS", r"derivative|\bf&o\b|futures|options|expir|stock exchange|depositor|mutual fund|stock ?broker|margin|algo|demat|index",
     "BSE MCX CDSL ANGELONE CAMS KFINTECH 360ONE NUVAMA HDFCAMC NAM-INDIA"),
    ("BANKS & NBFC", r"\bbank|nbfc|lend|loan|credit|deposit|provision|expected credit loss|risk weight|liquidity|priority sector|gold loan|microfinance|repo|\bcrr\b|\bslr\b",
     "HDFCBANK ICICIBANK SBIN AXISBANK KOTAKBANK INDUSINDBK BANKBARODA PNB BAJFINANCE CHOLAFIN MUTHOOTFIN MANAPPURAM SHRIRAMFIN"),
    ("POWER", r"market coupling|power exchange|electricity|tariff|transmission|\bists\b|renewable|discom",
     "IEX NTPC POWERGRID TATAPOWER ADANIENSOL ADANIGREEN NHPC JSWENERGY TORNTPOWER"),
    ("TELECOM", r"telecom|spectrum|interconnect|\bagr\b|satellite|broadband|tariff", "BHARTIARTL IDEA INDUSTOWER"),
    ("GAS", r"city gas|\bcgd\b|natural gas|\bapm\b|pipeline tariff|gas transportation", "IGL MGL GUJGASLTD GAIL PETRONET"),
    ("PHARMA", r"ceiling price|price control|\bdpco\b|\bnlem\b|drug price", "SUNPHARMA CIPLA DRREDDY LUPIN ZYDUSLIFE AUROPHARMA ALKEM TORNTPHARM"),
    ("AVIATION", r"airline|flight duty|\bfdtl\b|aviation", "INDIGO"),
    ("GAMING", r"online gaming|real money gam|betting|gambling", "NAZARA DELTACORP"),
]


def sector_hits(reg, title, fo):
    """-> [(sector, [F&O shares])] for a rule change on a whole sector (the title names no company)"""
    if not RULE.search(title):
        return []
    out = []
    for name, rx, syms in SECTORS:
        if re.search(rx, title, re.I):
            sh = [x for x in syms.split() if not fo or x in fo]
            if sh:
                out.append((name, sh))
    return out[:2]


def sector_line(reg, title, link, sec, shares, H, now):
    b = (H.get("by_reason") or {}).get("REGULATOR:-1") or {}
    return "\n".join(["⚠️ SHOCK WATCH · ◆ %s · RULE CHANGE · %s site %s" % (sec, reg, now.strftime("%H:%M")), "%s: %s" % (reg, title[:280]),
                      "touches: %s" % " · ".join(shares[:10]),
                      ("for scale: regulator news was behind %d F&O falls since %s (avg %+.1f%% that day)" % (b["n"], (H.get("from") or "2022")[:4], b["mv"])) if b.get("n") else "",
                      "watch: read it now - a rule change hits the whole sector at the next open; the 🌅 09:08 pre-open shows the gap, the 09:20 call decides",
                      link or ""]).replace("\n\n", "\n")
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
    r = requests.get(url, headers=UA, timeout=6, allow_redirects=True)
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
    known_urls = set(S.get("urls") or [])                       # patch 183: a page read for the first time only remembers (no flood)
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
            if S.get("first") or probe or (known_urls and url not in known_urls) or (not known_urls and S.get("seen") and not S.get("urls_v")):
                continue
            named = match(title)[:2]
            if not named:                                         # patch 183: no company named - a rule change for a whole sector?
                for sec, sh in sector_hits(reg, title, set(fo)):
                    if (sec, title[:80]) in said:
                        continue
                    said.add((sec, title[:80]))
                    out.append(sector_line(reg, title, link, sec, sh, H, now))
            for s in named:
                if (s, title[:80]) in said:
                    continue
                said.add((s, title[:80]))
                x = {"sym": s, "reason": "REGULATOR", "side": side_of(title), "head": "%s: %s" % (reg, title[:280]), "src": "%s site" % reg, "link": link}
                W.mark_known(x)                                   # patch 168: old news never rings
                out.append(W.line(x, H, now))
    if probe:
        return report
    S["first"] = False
    S["urls"] = sorted(set(S.get("urls") or []) | {u for _r, u in SOURCES}); S["urls_v"] = 1
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
cat > $D/p183test.py <<'P183TEST_PY'
#!/usr/bin/env python3
"""p183test.py - patch 183: a rule change for a whole sector (no company named) rings, with the F&O shares it touches"""
import os, sys, json, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regwatch as R, circuits as C, shockwatch as W
ok = True
def check(n, g):
    global ok
    print(("  ok   " if g else "  FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp()
R.SEEN = os.path.join(T, "rw.json"); R.HIST = os.path.join(T, "h.json"); C.NAMES = os.path.join(T, "n.json"); W.BASE = T; W.SAID = os.path.join(T, "s.json")
json.dump({"from": "2022-12-05", "by_reason": {"REGULATOR:-1": {"n": 105, "mv": -10.1, "next": 0.1}}}, open(R.HIST, "w"))
pages = {"irdai": [], "sebi": [], "prs": []}
def get(url):
    if "EQUITY_L" in url:
        return "SYMBOL,NAME OF COMPANY\nPOLICYBZR,PB Fintech Limited\nHDFCLIFE,HDFC Life Insurance Company Limited\nBSE,BSE Limited\nANGELONE,Angel One Limited\n"
    rows = lambda L: "<table>%s</table>" % "".join('<tr><td>%s</td><td><a href="/d/%d.pdf">PDF</a></td></tr>' % (t, i) for i, t in enumerate(L))
    if "irdai.gov.in/press-releases" in url:
        return rows(pages["irdai"])
    if "sebirss.xml" in url:
        return "<rss><channel>%s</channel></rss>" % "".join("<item><title>%s</title><link>https://sebi.gov.in/x%d</link></item>" % (t, i) for i, t in enumerate(pages["sebi"]))
    if "prsindia.org/billtrack" in url:
        return rows(pages["prs"])
    return None
fo = ["POLICYBZR", "HDFCLIFE", "BSE", "ANGELONE"]
R.run(None, get, fo=fo)
pages["irdai"] = ["Consultation Paper on Recalibrating the Economics of Insurance Distribution - comments by 25 October 2026", "IRDAI Annual Report 2025-26 released"]
pages["sebi"] = ["Consultation paper on review of the weekly expiry framework for equity derivatives"]
pages["prs"] = ["The Insurance Laws (Amendment) Bill, 2026 passed by Lok Sabha"]
out = R.run(None, get, fo=fo, now=dt.datetime(2026, 9, 23, 18, 5, tzinfo=R.IST))
for x in out:
    print(x, "\n")
ins = [x for x in out if "◆ INSURANCE" in x and "IRDAI" in x.split("\n")[0]]
check("IRDAI's commission paper (no company named) -> ⚠️ SHOCK WATCH · ◆ INSURANCE · RULE CHANGE, touches POLICYBZR · HDFCLIFE",
      len(ins) == 1 and "touches: POLICYBZR · HDFCLIFE" in ins[0])
check("SEBI's weekly-expiry paper -> ◆ CAPITAL MARKETS: BSE · ANGELONE", any("◆ CAPITAL MARKETS" in x and "BSE · ANGELONE" in x for x in out))
check("a bill passed by Lok Sabha -> ◆ INSURANCE · PARLIAMENT", any("◆ INSURANCE" in x and "PARLIAMENT site" in x for x in out))
check("the annual report: nothing", not any("Annual Report" in x for x in out))
import tglanes, alertword
check("it rings in Box Picks", all(tglanes.lane(x) == "critical" and alertword.tier(x) != "read" for x in out))
check("a second pass: nothing again", R.run(None, get, fo=fo) == [])
shutil.rmtree(T)
print("P183 TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
P183TEST_PY
cd $D && python3 -m py_compile regwatch.py || { cp $D/regwatch.py.bak$TS $D/regwatch.py; echo "does not compile - old file back"; exit 1; }
for t in p183test.py p163test.py; do timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "$t passed" || { echo "$t FAILED - old file back"; grep FAIL /tmp/$t.log | head -3; cp $D/regwatch.py.bak$TS $D/regwatch.py; exit 1; }; done
sed -i 's/^TimeoutStartSec=.*/TimeoutStartSec=400/' $U/gir-regwatch.service 2>/dev/null; systemctl daemon-reload
echo "== which pages answer from the server (nothing sent)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 420 python3 regwatch.py probe 2>&1 | grep -E "IRDAI|SEBI|RBI|CERC|PNGRB|NPPA|TRAI|DGCA|PARLIAMENT" | cut -c1-150 | sed 's/^/   /'
timeout 420 python3 regwatch.py > /dev/null 2>&1
echo "   (what is on the new pages now is remembered - only new papers / bills are said from now on)"
echo
echo "PATCH 183 APPLIED. Send Claude a screenshot of the page list - the ones with 0 items / no answer get new addresses."
