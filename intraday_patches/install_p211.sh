#!/bin/bash
# PATCH 211 - Rama, 12 Nov:
#   1 "when I click AUBANK it takes me to the share page - I want 2 pages: the share page and the related news": an alert with news is now a
#     link - one click opens the share page AND the story in a new tab (ALERTS list, IMPORTANT, the alert chips)
#   2 "OI SCENARIOS links say error 400 bad request": Google's RSS story address is opened as its page address (it forwards to the paper),
#     and every story gets 🔎 - a Google News search for the headline, which always opens
#   3 CAMS "Colorado justices ... parole officer body cams" (coloradopolitics.com) was a P2 alert: the news reader now keeps a story only when
#     it names the company (the symbol in CAPITALS, its name, or its short name L&T / SBI / HUL / Zomato ...) and it is Indian news
#   + why "the human reader was not available" (the AI reader) - printed at the end, read-only
#   The page (no restart) + the news reader (gir-newsroom restarts in seconds) - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $D/newshunt.py ] || { echo "patch 209 first (the news reader uses its India check)"; exit 1; }
for f in home.html newsalert.py; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in home.html newsalert.py; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-newsroom 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p211_patch.py <<'PY_PAGE'
#!/usr/bin/env python3
"""p211_patch.py - PATCH 211: TWO PAGES FROM ONE ALERT · NEWS LINKS THAT OPEN (Rama, 12 Nov: "when I click AUBANK it takes me to the AU share
page - I want 2 pages: the share page and the related news" · "in OI SCENARIOS some links do not open - error 400 bad request").
  - an alert row with news (📰 / 📄 NEWS, FILING, RESULTS, GOVT, POLICY, THE REASON, SHOCK WATCH) is now a link: one click opens the share page
    AND the story in a new tab (a plain link, so the browser does not block it as a pop-up). Rows: the ALERTS list, IMPORTANT, the alert chips.
    The story = the link in the alert; none in it -> a Google News search for its headline
  - Google News links: GIR stored Google's RSS address (news.google.com/rss/articles/...), which a browser answers with 400 - now opened as
    news.google.com/articles/... (Google's page for the story, it forwards to the newspaper); every story also gets 🔎 - a Google News search
    for its headline, which always opens
Usage: python3 p211_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  home.html: %s" % tag)


# the helpers, next to nlink
rep('''function nlink(x,txt){ const t=esc(txt!=null?txt:(x&&x.h)||""); const u=x&&(x.l||x.u)||""; if(!/^https?:\\/\\//i.test(u)) return t;
  return `<a class="nl" href="${esc(u)}" target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()" title="open the full story">${t}<span class="ar_">↗</span></a>`; }''',
    '''/* patch 211: Google's RSS story address answers 400 in a browser - its page address forwards to the newspaper; 🔎 = a search that always opens */
function gnFix(u){ const m=String(u||"").match(/^https?:\\/\\/news\\.google\\.com\\/rss\\/articles\\/([^?#\\s]+)/i); return m?"https://news.google.com/articles/"+m[1]+"?hl=en-IN&gl=IN&ceid=IN%3Aen":u; }
function gnSearch(h){ return "https://news.google.com/search?q="+encodeURIComponent(String(h||"").replace(/[^\\w&%.,'\\- ]+/g," ").replace(/\\s+/g," ").trim().slice(0,140))+"&hl=en-IN&gl=IN&ceid=IN%3Aen"; }
function nlink(x,txt){ const t=esc(txt!=null?txt:(x&&x.h)||""); const u=gnFix(x&&(x.l||x.u)||""); if(!/^https?:\\/\\//i.test(u)) return t;
  return `<a class="nl" href="${esc(u)}" target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()" title="open the full story">${t}<span class="ar_">↗</span></a><a class="nls" href="${esc(gnSearch((x&&x.h)||txt||""))}" target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()" title="the story did not open? search it on Google News">🔎</a>`; }
/* patch 211: an alert with news -> its story (the link in it, else a Google News search for its headline); the row opens the share AND the story */
function aNewsUrl(r){ const H=String(r&&r.head||""); if(!/NEWS|FILING|RESULTS|GOVT|POLICY|THE REASON|SHOCK WATCH|📰|📄/.test(H)) return "";
  const T=[H].concat(r.lines||[]).join("\\n"), m=T.match(/https?:\\/\\/[^\\s<>"']+/); if(m&&!/girtrader/i.test(m[0])) return gnFix(m[0]);
  const L=(r.lines||[]).map(x=>String(x)).filter(x=>x.trim()&&!/^(⚙️|🔎|room:|the reader|also names|⚠|🔴|🟠|📌)/.test(x.trim()));
  return gnSearch((r.s&&r.s!=="MARKET"?r.s+" ":"")+(L[0]||H.replace(/^\\S+\\s*/,"")).slice(0,120)); }
function aTag(r,cls,title){ const u=aNewsUrl(r), s=esc(r.s||"MARKET");
  return u?`<a class="${cls}" href="${esc(u)}" target="_blank" rel="noopener" onclick="focusOn('${s}')" title="${title} · click: the share page + its story">`:`<div class="${cls}" onclick="focusOn('${s}')" title="${title}">`; }
function aEnd(r){ return aNewsUrl(r)?"</a>":"</div>"; }''', "Google News links that open · 🔎 · the alert's story")
# the ALERTS list (laptop box / phone fold)
rep('''return `<div class="dgr" onclick="focusOn('${esc(r.s||"MARKET")}')" title="${esc(r.head||"")}">''',
    '''return `${aTag(r,"dgr",esc(r.head||""))}''', "ALERTS list rows: share + story")
rep('''<span class="w">${esc(impWhat(r).slice(0,70))}</span></div>`''',
    '''<span class="w">${aNewsUrl(r)?"📰 ":""}${esc(impWhat(r).slice(0,70))}</span>${aEnd(r)}`''', "ALERTS list rows: the end")
# IMPORTANT rows
rep('''    return `<div class="im${g.crit?" cr":""}" onclick="focusOn('${esc(r.s)}')" title="${esc(g.rows.map(x=>x.t+"  "+x.head).join("\\n"))}">''',
    '''    return `${aTag(r,"im"+(g.crit?" cr":""),esc(g.rows.map(x=>x.t+"  "+x.head).join("\\n")))}''', "IMPORTANT rows: share + story")
rep('''</div><p>${esc(impWhat(r).slice(0,110))}</p>${n>1?`<p class="ol">also ${older}</p>`:""}</div></div>`; };''',
    '''${aNewsUrl(r)?'<em class="sty">📰 story ↗</em>':""}</div><p>${esc(impWhat(r).slice(0,110))}</p>${n>1?`<p class="ol">also ${older}</p>`:""}</div>${aEnd(r)}`; };''', "IMPORTANT rows: the end")
# the alert chips
rep('''    return `<div class="ch ${x.tier}${fr?" fresh":""}" title="${esc([r.head].concat(r.lines||[]).join("\\n"))}" onclick="focusOn('${esc(r.s||"MARKET")}')">''',
    '''    return `${aTag(r,"ch "+x.tier+(fr?" fresh":""),esc([r.head].concat(r.lines||[]).join("\\n")))}''', "alert chips: share + story")
rep('''${x.n>1?`<span class="dim">×${x.n}</span>`:""}</div>`; };''', '''${x.n>1?`<span class="dim">×${x.n}</span>`:""}${aEnd(r)}`; };''', "alert chips: the end")
rep('''/* patch 207b: the phone - the counts line''', '''/* patch 211: alert rows that are links look the same */
a.dgr,a.im,a.ch{color:inherit;text-decoration:none}a.dgr:hover,a.im:hover{background:#14202e}
#mk-act .im em.sty{color:#4fc3f7;background:transparent;padding:0}
a.nls{margin-left:6px;text-decoration:none;font-size:.9em;opacity:.8}a.nls:hover{opacity:1}
/* patch 207b: the phone - the counts line''', "the look")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: patch 211 in")
PY_PAGE
cat > $W/p211b_patch.py <<'PY_NEWS'
#!/usr/bin/env python3
"""p211b_patch.py - PATCH 211b: the news reader keeps only stories ABOUT the share (Rama, 12 Nov: CAMS - "Colorado justices to weigh insurer
penalties, parole officer body cams" from coloradopolitics.com became a P2 alert). A story reaches the reader / the alerts only when:
  - it names the company: its NSE symbol in CAPITALS (CAMS, not "body cams") or its name's first word (Computer Age ...), and
  - it is Indian: India in its words (India, the Centre, ₹, crore, NSE, SEBI, RBI ...) or an Indian news site - a foreign site with no
    India in it needs the company's name, not just a symbol-like word
Usage: python3 p211b_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "newsalert.py"); s = open(p, encoding="utf-8").read()
old = '''    def job():
        if recently_sent(sym, h):
            return None'''
new = '''    def job():
        if recently_sent(sym, h):
            return None
        if not about_it(sym, h, src, name):                    # patch 211b: "body cams" is not CAMS, a Colorado court is not Indian news
            print("news reader: not about %s - %s (%s)" % (sym, h[:90], src), flush=True)
            return None'''
helper = '''

_NM211 = {"t": 0.0, "v": {}}


def about_it(sym, h, src="", name=""):
    """patch 211b: True when the headline is about this F&O share and is Indian news"""
    if sym in ("MARKET", "NIFTY", "BANKNIFTY", "SENSEX"):
        return True
    import re
    h = h or ""
    try:
        if not name:
            if time.time() - _NM211["t"] > 3600:
                import newsroom
                _NM211["v"] = {s_: n_ for s_, n_, l_ in newsroom.fo_names()}; _NM211["t"] = time.time()
            name = _NM211["v"].get(sym) or ""
    except Exception:
        pass
    w = [x for x in re.findall(r"[A-Za-z][A-Za-z&'\\-]+", name or "") if x.lower() not in ("the", "ltd", "limited", "of", "and", "co", "company", "industries", "corporation")]
    common = ("oil", "power", "bank", "state", "indian", "national", "union", "central", "general", "life", "steel", "gas", "coal", "bharat",
              "hindustan", "small", "punjab", "great", "new", "first", "global", "united", "city", "home", "max", "page", "info", "data", "one")
    kw = w[:1] if (w and len(w[0]) >= 4 and w[0].lower() not in common) else w[:2]   # "Oil India", "AU Small", "Bharat Electronics"
    by_name = bool(kw and re.search(r"(?<![A-Za-z])%s(?![A-Za-z])" % r"(?:\\s+(?:of|and|&)\\s+|\\s*&\\s*|\\s+)".join(re.escape(x) for x in kw), h, re.I))
    by_sym = bool(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(sym), h))          # the symbol in CAPITALS only
    AKA = {"LT": ["L&T"], "M&M": ["M&M"], "SBIN": ["SBI"], "HINDUNILVR": ["HUL"], "BHARTIARTL": ["Airtel"], "COALINDIA": ["CIL"], "LICI": ["LIC"],
           "ETERNAL": ["Zomato", "Eternal"], "PAYTM": ["Paytm"], "NYKAA": ["Nykaa"], "POLICYBZR": ["Policybazaar", "PB Fintech"], "DMART": ["DMart"],
           "INDIGO": ["IndiGo"], "NAUKRI": ["Info Edge", "Naukri"], "ICICIGI": ["ICICI Lombard"], "ICICIPRULI": ["ICICI Prudential"], "HDFCLIFE": ["HDFC Life"],
           "SBILIFE": ["SBI Life"], "BAJAJ-AUTO": ["Bajaj Auto"], "HEROMOTOCO": ["Hero MotoCorp"], "TMPV": ["Tata Motors"], "TATAMOTORS": ["Tata Motors"],
           "KOTAKBANK": ["Kotak"], "INDUSINDBK": ["IndusInd"], "BANKBARODA": ["Bank of Baroda", "BoB"], "PNB": ["Punjab National"], "HAL": ["Hindustan Aeronautics"],
           "BEL": ["BEL"], "BHEL": ["BHEL"], "IRFC": ["IRFC"], "RVNL": ["RVNL", "Rail Vikas"], "MAZDOCK": ["Mazagon"], "M&MFIN": ["M&M Finance"]}
    by_sym = by_sym or any(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(a), h) for a in AKA.get(sym, []))
    if not (by_name or by_sym):
        return name == ""                                       # names not known here: keep, as before
    try:
        import newshunt as NH
        tl = h.lower()
        india = bool(NH.INDIA_RX.search(tl)) or bool(NH.INDIAN_PUB.search(src or ""))
        if NH.FOREIGN_RX.search(tl) and not NH.INDIA_RX.search(tl):
            return False
        if not india and not by_name:
            return False                                        # a foreign site, no India in it, only a symbol-like word: not it
    except Exception:
        pass
    return True
'''
if "def about_it(" in s:
    print("  newsalert.py: the name check - already in"); sys.exit(0)
if s.count(old) != 1:
    print("❌ newsalert.py: anchor found %d times" % s.count(old)); sys.exit(1)
s = s.replace(old, new)
s = s.replace('''\n\ndef story(sym, h, link="", src="", kind="",''', helper + '''\n\ndef story(sym, h, link="", src="", kind="",''', 1)
if "def about_it(" not in s:
    print("❌ newsalert.py: could not place the check"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("  newsalert.py: a story must name the company and be Indian news")
PY_NEWS
cat > $D/p211test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p211test.py - patch 211b's own test: which headlines the news reader keeps for a share (no network, nothing sent). python3 p211test.py DIR"""
import os, sys
sys.path.insert(0, os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "."))
import newsalert as N
CASES = [(0, "CAMS", "Computer Age Management Services Ltd", "Colorado justices to weigh insurer penalties, parole officer body cams", "coloradopolitics.com"),
         (1, "CAMS", "Computer Age Management Services Ltd", "CAMS shares jump 6% after SEBI nod", "Moneycontrol"),
         (0, "IDEA", "Vodafone Idea Ltd", "A great idea for retirement planning", "forbes.com"),
         (1, "IDEA", "Vodafone Idea Ltd", "Vodafone Idea AGR relief: Supreme Court hearing today", "ET"),
         (0, "OIL", "Oil India Ltd", "Oil prices climb as OPEC cuts output", "reuters.com"),
         (1, "OIL", "Oil India Ltd", "OIL India discovers new gas field in Assam", "PTI"),
         (1, "AUBANK", "AU Small Finance Bank", "AU Small Finance Bank gets RBI nod", "money.rediff.com"),
         (0, "BEL", "Bharat Electronics Ltd", "Bharat Forge wins order", "ET"),
         (1, "BEL", "Bharat Electronics Ltd", "Bharat Electronics bags Rs 1,200 crore order", "ET"),
         (0, "COALINDIA", "Coal India Ltd", "Coal prices fall in China", "reuters.com"),
         (1, "BANKINDIA", "Bank of India", "Bank of India cuts MCLR", "ET"),
         (1, "LT", "Larsen & Toubro Ltd", "L&T wins order", "ET"),
         (1, "SBIN", "State Bank of India", "SBI raises Rs 10,000 crore via bonds", "Mint"),
         (1, "ETERNAL", "Eternal Ltd", "Zomato parent Eternal shares fall", "ET")]
ok = 0
for exp, s, nm, h, src in CASES:
    r = N.about_it(s, h, src, nm)
    ok += (r == bool(exp))
    print("  %s %s %-9s %s (%s)" % ("✅" if r == bool(exp) else "❌", "kept   " if r else "dropped", s, h[:60], src))
print("NEWS READER test: %d of %d passed" % (ok, len(CASES)))
sys.exit(0 if ok == len(CASES) else 1)
PY_TEST
echo "=== the page"
python3 $W/p211_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== the news reader"
python3 $W/p211b_patch.py $D || back
cd $D && python3 -m py_compile newsalert.py || back
timeout 60 python3 p211test.py $D > /tmp/p211test.out 2>&1; R=$?
cat /tmp/p211test.out; [ $R = 0 ] || back
systemctl restart gir-newsroom && sleep 5 && echo "  gir-newsroom: $(systemctl is-active gir-newsroom)"
echo "=== why 'the human reader was not available' (read-only)"
python3 - <<'PY_AI'
import json, os
os.chdir("/home/globalbot/intraday")
try:
    d = json.load(open("data/llm_usage.json"))
    for k in sorted(d)[-3:]:
        r = d[k]; print("   %s · %s AI calls · $%.4f spent" % (k, r.get("calls"), float(r.get("usd") or 0)))
except Exception as ex:
    print("   usage file: %s" % ex)
try:
    print("   GIR's own daily AI limit: $%s a day (data/llm_budget.json)" % json.load(open("data/llm_budget.json")).get("usd_per_day"))
except Exception:
    print("   GIR's own daily AI limit: the default ($1 a day)")
for f in ("data/llm_credit.json", "data/llm_balance.json"):
    try:
        print("   %s: %s" % (f, json.dumps(json.load(open(f)))[:200]))
    except Exception:
        pass
PY_AI
journalctl -u gir-newsroom --since "-30 hours" --no-pager 2>/dev/null | grep -iE "news reader|budget|credit|anthropic|overload|429|529|rate" | grep -v "not about" | tail -n 6 | cut -c1-180 | sed 's/^/   log: /'
echo "✅ patch 211 done - Ctrl + Shift + R on GIR (the phone: reload)."
echo "   undo: for f in home.html newsalert.py; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-newsroom"
