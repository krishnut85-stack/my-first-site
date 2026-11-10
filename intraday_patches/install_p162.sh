#!/bin/bash
# PATCH 162 - 📺 TV WATCH: GIR listens to CNBC-TV18 live all session (09:00-15:40, NSE trading days), reads the speech every 20 s, and when a
#   company is named with shock-type news (regulator, fraud, boss quits, order, deal, approval, policy) says it at once as ⚠️ SHOCK WATCH
#   (Box Picks, rings) / 📰 SHOCK WATCH (News topic, quiet), with the words heard on air. ~40-70 s from the words on air to Telegram.
#   + SHOCK WATCH's first line now reads "▲ SHARE · REASON" (the page files it under the share, not under "ORDER").
#   + 161c included: shock reasons - market-wide days are MARKET, MGMT only for a boss leaving (the report is made again).
#   Uses the tool folder set up by tvprobe.sh (/home/globalbot/tvenv + cookies). No GIR restart. Safe any time.
set -u
D=/home/globalbot/intraday; V=/home/globalbot/tvenv; U=/etc/systemd/system
[ -x $V/bin/python ] && $V/bin/python -c "import faster_whisper" 2>/dev/null || { echo "the TV tool folder is not ready - run tvprobe.sh first"; exit 1; }
[ -f $D/shockwatch.py ] || { echo "run shocks.sh (patch 161) first"; exit 1; }
[ -f $V/cookies.txt ] || echo "   note: no YouTube cookies in $V/cookies.txt - YouTube may refuse the server"
echo "== 1. the files"
for f in shockwatch.py p161test.py circuits.py; do cp $D/$f $D/$f.bak162 2>/dev/null; done
cat > $D/circuits.py <<'CIRCUITS_PY'
#!/usr/bin/env python3
"""circuits.py - patch 161: THE SHOCK DAYS (Rama, 10 Nov: "check the past 3-4 years when F&O shares hit upper and lower circuit, and the
reason - Policybazaar fell for an IRDAI issue - and alert me when the same kind of thing is brewing").
F&O shares have no fixed circuit: NSE's dynamic price band starts at 10% and is widened when hit. So a SHOCK DAY here is a day the
share closed 8%+ up / down on the previous close, or traded 10%+ away from it (the band's first step) - UP and DOWN, every year from
Nov 2022 (data/h3 holds 3 years; 'extend' adds the year before so 2023 is complete).
  python3 circuits.py extend             the daily candles + NSE futures OI back to 1 Nov 2022 (Kite + NSE files; ~20 min, once)
  python3 circuits.py find               the shock days, year by year, up and down (instant, from the candles)
  python3 circuits.py reasons            each shock's reason: the share's own NSE filings (D-30..D, read with GIR's exchange reader),
                                         its results days, NIFTY that day, Google News headlines of those days. Cached in
                                         data/h3/shock_reasons.json, resumable, the biggest shocks first, pauses in market hours.
  python3 circuits.py report [--no-tg]   the report -> data/h3/circuits.txt, data/h3/circuits.json (the live 🚨 SHOCK WATCH reads it)
  python3 circuits.py all [--no-tg]      reasons, then the report"""
import os, re, sys, json, time, html, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import study3y as S

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
CACHE = os.path.join(S.H3, "shock_reasons.json")
NAMES = os.path.join(BASE, "data", "fo_names.json")
CLOSE_BIG, TOUCH = 8.0, 10.0
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*",
      "Accept-Language": "en-US,en;q=0.9"}

# ---------------------------------------------------------------- the reason words (shared with shockwatch.py)
REASONS = [
    ("REGULATOR", re.compile(r"\brbi\b|reserve bank|\bsebi\b|\birdai\b|insurance regulator|usfda|us fda|\bfda\b|warning letter|import alert|form 483|\b483\b|\boai\b|"
                             r"\bcci\b|competition commission|enforcement directorate|\bed\b (?:raid|search|probe|attach|summon)|income[- ]tax (?:search|raid|survey|notice|demand)|"
                             r"\bi-?t (?:raid|search|survey)|gst (?:notice|demand|evasion)|tax demand|show[- ]cause|penalt\w*|\bfined?\b|\bban(?:s|ned)?\b|\bbarred?\b|bars\b|"
                             r"restrict\w*|licen[cs]e (?:cancel\w*|suspend\w*|revok\w*)|regulator\w*|tribunal|\bnclt\b|\bnclat\b|supreme court|high court|\bcbi\b|\bsfio\b|"
                             r"\btrai\b|\bdgca\b|\bnppa\b|\bdcgi\b|\bcdsco\b|\bmhra\b|\bprobe\b|investigation|raid", re.I)),
    ("GOVERNANCE", re.compile(r"fraud|forensic|auditor\w* (?:resign\w*|quit\w*)|resignation of (?:the )?(?:statutory )?auditor|accounting (?:lapse|issue|discrepanc|irregular)|"
                              r"discrepanc|whistle-?blower|short[- ]seller|hindenburg|indict\w*|brib\w*|\bscam\b|irregularit|misstat\w*|governance|siphon|diversion of funds|"
                              r"derivative (?:portfolio|losses|accounting)|wilful default", re.I)),
    ("RESULTS", re.compile(r"\bq[1-4]\b|\bq[1-4]fy|quarter\w*|\bresults?\b|earnings|net profit|profit (?:falls|rises|jumps|plunges|drops|slumps|surges)|"
                           r"net loss|\bloss\b|revenue|margin\w*|guidance|ebitda|\bpat\b", re.I)),
    ("DEAL", re.compile(r"block deal|bulk deal|stake sale|offer for sale|\bofs\b|promoters? (?:sell|sold|offload|cut|trim|pledge)|pledge\w*|acqui\w*|merger|demerger|"
                        r"takeover|open offer|\bqip\b|buy-?back|delist\w*|\bstake\b|share swap|scheme of arrangement", re.I)),
    ("MGMT", re.compile(r"(?:\bceo\b|managing director|\bmd\b|\bcfo\b|chairman|founder|top boss)[^.|]{0,70}(?:resign\w*|steps? down|quits?\b|exit\w*|sacked|removed|ousted)|"
                        r"(?:resign\w*|steps? down|quits?\b|exit of|sacked|ousted)[^.|]{0,70}(?:\bceo\b|managing director|\bmd\b|\bcfo\b|chairman|founder)", re.I)),   # a boss LEAVING, not an appointment
    ("ORDER", re.compile(r"\border\w*\b|contract|\bwins?\b|\bbags?\b|secures?|letter of (?:award|intent)|\bloa\b|deal worth|\bmou\b", re.I)),
    ("POLICY", re.compile(r"budget|gst council|\bduty\b|tariff|government|govt|\bpolicy\b|\bpli\b|cabinet|ministry|subsidy|windfall|export (?:ban|curb)|\bcess\b|"
                          r"\bpsu\b disinvest|disinvestment|price cap|price control", re.I)),
    ("BROKER", re.compile(r"downgrad\w*|upgrad\w*|target (?:price )?(?:cut|raise|slash)|brokerage|\bmsci\b|\bftse\b|index inclusion|added to (?:nifty|sensex)|"
                          r"\bjefferies\b|\bclsa\b|goldman|morgan stanley|\bnomura\b|\bmacquarie\b|\bciti\b|kotak institutional|\bsell rating|\bbuy rating", re.I)),
    ("BUSINESS", re.compile(r"\bsales\b|volumes?\b|production|business update|launch\w*|\bplant\b|\bfire\b|accident|strike|shutdown|outage|cyber|recall|"
                            r"\bdeal\b|partnership|capex|expansion|approval|clearance", re.I)),
]
NEG = re.compile(r"penalt|fine|\bban|barred|bars\b|restrict|warning|import alert|483|\boai\b|show[- ]cause|notice|demand|probe|raid|search|fraud|forensic|resign|"
                 r"quit|downgrad|cut\b|slash|plunge|crash|tank|slump|sink|fall|fell|drop|tumble|loss|weak|miss|default|suspend|revok|cancel|reject|adverse|"
                 r"short[- ]seller|indict|brib|scam|discrepanc|lapse|investigation|sell[- ]off|lower circuit", re.I)
POS = re.compile(r"approv|clear|\beir\b|\bvai\b|lifted|revoked the ban|relief|win|bag|secure|award|upgrad|beat|surge|jump|soar|rally|zoom|record|upper circuit|"
                 r"buy-?back|bonus|acqui|merger|order|contract|raise|strong|robust|profit rises|in favour", re.I)


def reason_of(text):
    """-> the first reason class whose words are in the text, or None"""
    for k, rx in REASONS:
        if rx.search(text or ""):
            return k
    return None


def side_of(text):
    n, p = len(NEG.findall(text or "")), len(POS.findall(text or ""))
    return -1 if n > p else 1 if p > n else 0


# ---------------------------------------------------------------- company names (for the news search and the live watcher)
ALIASES = {"PBFINTECH": ["Policybazaar", "PB Fintech"], "PAYTM": ["Paytm", "One 97"], "ETERNAL": ["Zomato", "Eternal"], "ZOMATO": ["Zomato"],
           "NYKAA": ["Nykaa"], "DMART": ["DMart", "Avenue Supermarts"], "M&M": ["Mahindra & Mahindra", "M&M"], "SBIN": ["SBI", "State Bank of India"],
           "LT": ["L&T", "Larsen"], "HAL": ["HAL", "Hindustan Aeronautics"], "BEL": ["Bharat Electronics"], "LICI": ["LIC", "Life Insurance Corporation"],
           "INDUSINDBK": ["IndusInd"], "KOTAKBANK": ["Kotak Mahindra Bank", "Kotak Bank"], "BAJFINANCE": ["Bajaj Finance"], "IRCTC": ["IRCTC"],
           "IRFC": ["IRFC"], "RVNL": ["RVNL", "Rail Vikas"], "NHPC": ["NHPC"], "NTPC": ["NTPC"], "ONGC": ["ONGC"], "GAIL": ["GAIL"], "BHEL": ["BHEL"],
           "SAIL": ["SAIL", "Steel Authority"], "IOC": ["Indian Oil", "IOC"], "BPCL": ["BPCL"], "HINDPETRO": ["HPCL", "Hindustan Petroleum"],
           "IDEA": ["Vodafone Idea", "Vi "], "ADANIENT": ["Adani Enterprises"], "ADANIPORTS": ["Adani Ports"], "ADANIGREEN": ["Adani Green"],
           "ADANIENSOL": ["Adani Energy Solutions"], "HDFCBANK": ["HDFC Bank"], "ICICIBANK": ["ICICI Bank"], "AXISBANK": ["Axis Bank"],
           "TCS": ["TCS", "Tata Consultancy"], "INFY": ["Infosys"], "HCLTECH": ["HCLTech", "HCL Tech"], "TECHM": ["Tech Mahindra"],
           "MAZDOCK": ["Mazagon Dock"], "COCHINSHIP": ["Cochin Shipyard"], "DIXON": ["Dixon"], "POLICYBZR": ["Policybazaar"],
           "JIOFIN": ["Jio Financial"], "RELIANCE": ["Reliance Industries", "RIL"], "MCX": ["MCX"], "BSE": ["BSE Ltd", "BSE shares"],
           "CDSL": ["CDSL"], "ANGELONE": ["Angel One"], "IIFL": ["IIFL Finance"], "MANAPPURAM": ["Manappuram"], "MUTHOOTFIN": ["Muthoot"]}
GENERIC = {"life insurance", "indian bank", "general insurance", "new india", "the indian", "power finance", "state bank", "bank of", "union bank"}


def short_name(full):
    w = re.sub(r"\b(?:limited|ltd\.?)\s*$", "", (full or "").strip(), flags=re.I).strip()
    w = re.sub(r"^the\s+", "", w, flags=re.I)
    p = w.split()
    if len(p) > 2:
        w = " ".join(p[:3] if p[1].lower() in ("of", "and", "&") else p[:2])
    return w


def names(syms, get=None):
    """{sym: [names to look for]} from NSE's equity list (cached in data/fo_names.json), with the brand names people use"""
    try:
        full = json.load(open(NAMES))
    except Exception:
        full = {}
    if not full:
        try:
            if get:
                txt = get("https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv")
            else:
                import requests
                txt = requests.get("https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv", headers=UA, timeout=30).text
            for line in (txt or "").splitlines()[1:]:
                c = [x.strip().strip('"') for x in line.split(",")]
                if len(c) > 1 and c[0]:
                    full[c[0]] = c[1]
            if full and not get:
                os.makedirs(os.path.dirname(NAMES), exist_ok=True)
                json.dump(full, open(NAMES, "w"))
        except Exception:
            pass
    out = {}
    for s in syms:
        L = list(ALIASES.get(s, []))
        sn = short_name(full.get(s, ""))
        if sn and sn.lower() not in GENERIC and sn.lower() not in [x.lower() for x in L]:
            L.append(sn)
        out[s] = L or [s]
    return out


# ---------------------------------------------------------------- 1. the shock days
def futmap():
    import sqlite3
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(S.H3, "fut.db"), uri=True)
        F = {(s, d): foi for d, s, foi in c.execute("select d, sym, foi from fut")}
        c.close()
        return F
    except Exception:
        return {}


SIGNS = ["fell 5%+ in the 5 days before", "rose 5%+ in the 5 days before", "moved 3%+ the day before", "volume 2x+ the day before",
         "futures OI +10% in 5 days", "short build-up (OI +10%, price -3%, 5 days)", "long build-up (OI +10%, price +3%, 5 days)",
         "at a 20-day low", "at a 20-day high"]


def signs_at(D, ks, i, s, F):
    """the signs known at the close of day i-1, before day i opens"""
    c = [D[ks[j]][3] for j in range(i - 21, i)]
    v = [D[ks[j]][4] for j in range(i - 21, i)]
    r5 = S.pct(c[-1], c[-6]) or 0
    out = set()
    if r5 <= -5: out.add(SIGNS[0])
    if r5 >= 5: out.add(SIGNS[1])
    if abs(S.pct(c[-1], c[-2]) or 0) >= 3: out.add(SIGNS[2])
    v20 = S.avg(v[:-1])
    if v20 and v[-1] >= 2 * v20: out.add(SIGNS[3])
    o1, o5 = F.get((s, ks[i - 1])), F.get((s, ks[i - 6]))
    if o1 and o5:
        oi5 = S.pct(o1, o5) or 0
        if oi5 >= 10:
            out.add(SIGNS[4])
            if r5 <= -3: out.add(SIGNS[5])
            if r5 >= 3: out.add(SIGNS[6])
    lo20, hi20 = min(D[ks[j]][2] for j in range(i - 21, i)), max(D[ks[j]][1] for j in range(i - 21, i))
    if c[-1] <= lo20 * 1.01: out.add(SIGNS[7])
    if c[-1] >= hi20 * 0.99: out.add(SIGNS[8])
    return out


def find(syms, DAY, F=None):
    """-> (shocks [dict], base {sign: [days, down shocks, up shocks]}, totals [days, down, up])"""
    F = F if F is not None else {}
    N = DAY.get("NIFTY 50") or {}
    npc = S.prev_close_map(N)
    shocks, base, tot = [], {}, [0, 0, 0]
    for s in syms:
        D = DAY.get(s) or {}
        ks = sorted(D)
        for i in range(21, len(ks)):
            k = ks[i]
            o, h, l, c, v = D[k]
            pc = D[ks[i - 1]][3]
            if not pc:
                continue
            mv, hi, lo = S.pct(c, pc), S.pct(h, pc), S.pct(l, pc)
            side = 0
            if mv >= CLOSE_BIG or (hi >= TOUCH and mv > 0):
                side = 1
            elif mv <= -CLOSE_BIG or (lo <= -TOUCH and mv < 0):
                side = -1
            if side < 0 and mv <= -30 and abs(S.pct(o, pc) - mv) < 3:
                side = 0                                       # opened at the new price and stayed: a split / bonus / demerger, not a shock
            sg = signs_at(D, ks, i, s, F)
            tot[0] += 1; tot[1] += side < 0; tot[2] += side > 0
            for x in sg:
                b = base.setdefault(x, [0, 0, 0]); b[0] += 1; b[1] += side < 0; b[2] += side > 0
            if not side:
                continue
            nx = (S.pct(D[ks[i + 1]][3], c) if i + 1 < len(ks) else None)
            n5 = (S.pct(D[ks[i + 5]][3], c) if i + 5 < len(ks) else None)
            nm = S.pct(N[k][3], npc[k]) if k in N and npc.get(k) else None
            shocks.append({"sym": s, "d": k, "side": side, "mv": round(mv, 2), "gap": round(S.pct(o, pc), 2), "hi": round(hi, 2), "lo": round(lo, 2),
                           "nifty": round(nm, 2) if nm is not None else None, "next": round(nx, 2) if nx is not None else None,
                           "n5": round(n5, 2) if n5 is not None else None, "signs": sorted(sg)})
    return shocks, base, tot


# ---------------------------------------------------------------- 2. the reasons
def nse_filings(sym, d, days=30, getj=None):
    """the share's NSE filings from d-days to d: [(epoch, kind, side, subject)] - read with GIR's exchange reader"""
    import exchange
    d0 = dt.date.fromisoformat(d)
    path = "/api/corporate-announcements?index=equities&symbol=%s&from_date=%s&to_date=%s" % (
        sym, (d0 - dt.timedelta(days=days)).strftime("%d-%m-%Y"), (d0 + dt.timedelta(days=1)).strftime("%d-%m-%Y"))
    data = (getj or exchange.nse_json)(path)
    out = []
    for e in (data if isinstance(data, list) else (data or {}).get("data", []) or []):
        if not isinstance(e, dict):
            continue
        te = exchange.parse_t(e.get("sort_date") or e.get("an_dt") or e.get("exchdisstime") or e.get("dt"))
        subj = html.unescape((e.get("desc") or e.get("subject") or "").strip())
        det = html.unescape((e.get("attchmntText") or e.get("sm_desc") or "").strip())
        if not te:
            continue
        try:
            kind, side = exchange.classify(subj, det)
        except Exception:
            kind, side = "OTHER", 0
        if kind in ("ROUTINE",):
            continue
        out.append((te, kind, side, (subj + (" — " + det[:160] if det and det[:40].lower() not in subj.lower() else ""))[:220]))
    return out


def news_of(name, d, get=None):
    """Google News headlines naming the company from d-2 to d+1: [(title, link)]"""
    d0 = dt.date.fromisoformat(d)
    q = '"%s" after:%s before:%s' % (name, d0 - dt.timedelta(days=2), d0 + dt.timedelta(days=2))
    url = "https://news.google.com/rss/search?q=%s&hl=en-IN&gl=IN&ceid=IN:en" % __import__("urllib.parse").parse.quote(q)
    if get:
        txt = get(url)
    else:
        import requests
        r = requests.get(url, headers=UA, timeout=(5, 12))
        txt = r.text if r.status_code == 200 else ""
    out = []
    for m in re.finditer(r"<item>(.*?)</item>", txt or "", re.S):
        t = re.search(r"<title>(.*?)</title>", m.group(1), re.S)
        l = re.search(r"<link>(.*?)</link>", m.group(1), re.S)
        if t:
            out.append((html.unescape(re.sub(r"<!\[CDATA\[|\]\]>", "", t.group(1))).strip()[:200], (l.group(1).strip() if l else "")))
    return out[:12]


def market_day(sh, crowd=0):
    return (sh.get("nifty") is not None and abs(sh["nifty"]) >= 2.5 and sh["nifty"] * sh["side"] > 0) or crowd >= 15


def refine(x, crowd=0):
    """patch 161c: the reason read again with the stricter rules - a market-wide day is MARKET (unless a regulator / governance story),
    MGMT only for a boss leaving (an appointment headline is not why a share fell 8%)"""
    r = x.get("reason")
    if r in ("REGULATOR", "GOVERNANCE", "NOT READ"):
        return r, x.get("line", "")
    if market_day(x, crowd):
        return "MARKET", "NIFTY %+.1f%% that day · %d F&O shares shocked the same way" % (x.get("nifty") or 0, crowd)
    if r == "MGMT" and not REASONS[4][1].search(x.get("line", "")):
        for t in x.get("news") or []:
            k = reason_of(t)
            if k and k != "MGMT" and side_of(t) in (0, x["side"]):
                return k, t
        return "UNKNOWN", ""
    return r, x.get("line", "")


def decide(sh, filings, news, result_day):
    """-> (reason, the line that says it, source) for one shock. The share's own filings first, then a results day, the news, the market."""
    d0 = dt.date.fromisoformat(sh["d"])
    end = dt.datetime.combine(d0, dt.time(15, 30), IST).timestamp()
    start = dt.datetime.combine(d0 - dt.timedelta(days=4), dt.time(15, 30), IST).timestamp()
    near = [f for f in filings if start <= f[0] <= end]
    for f in near:                                             # an official regulator / management / governance filing
        if f[1] in ("REG", "MGMT"):
            return ("REGULATOR" if f[1] == "REG" else "MGMT"), f[3], "NSE filing"
        if reason_of(f[3]) == "GOVERNANCE":
            return "GOVERNANCE", f[3], "NSE filing"
    hits = []
    for t, l in news:
        r = reason_of(t)
        if r:
            sd = side_of(t)
            hits.append((0 if sd == sh["side"] else 1, [k for k, _ in REASONS].index(r), r, t))
    hits.sort()
    strong = [h for h in hits if h[2] in ("REGULATOR", "GOVERNANCE") and h[0] == 0]
    if strong:
        return strong[0][2], strong[0][3], "news"
    if result_day:
        rl = [f[3] for f in near if f[1] == "RESULTS"]
        return "RESULTS", (rl[0] if rl else ([h[3] for h in hits if h[2] == "RESULTS"] or ["results day"])[0]), "results"
    for f in near:
        if f[1] in ("ORDER", "BOARD", "RATING", "SALES", "RESULTS"):
            return {"BOARD": "DEAL", "RATING": "BROKER", "SALES": "BUSINESS"}.get(f[1], f[1]), f[3], "NSE filing"
    if hits:
        return hits[0][2], hits[0][3], "news"
    if sh.get("nifty") is not None and abs(sh["nifty"]) >= 2.5 and sh["nifty"] * sh["side"] > 0:
        return "MARKET", "NIFTY %+.1f%% that day" % sh["nifty"], "market"
    return "UNKNOWN", "", ""


def market_hours():
    n = dt.datetime.now(IST)
    if n.weekday() >= 5 or not (dt.time(9, 0) <= n.time() <= dt.time(15, 35)):
        return False
    try:
        import holidays
        return not holidays.holiday(n.date())                  # an NSE holiday (10 Nov 2026) is not a market day
    except Exception:
        return True


def reasons(shocks, syms, DAY, getj=None, get=None, pause=0.6, log=print, stop=market_hours):
    try:
        C = json.load(open(CACHE))
    except Exception:
        C = {}
    try:
        R = json.load(open(os.path.join(S.H3, "results.json")))
    except Exception:
        R = {}
    try:
        BM = json.load(open(os.path.join(S.H3, "results_bm.json")))
    except Exception:
        BM = {}
    NM = names(syms, get)
    RD = {}
    todo = sorted([x for x in shocks if "%s:%s" % (x["sym"], x["d"]) not in C], key=lambda x: -abs(x["mv"]))
    log("reasons: %d shocks, %d already read, %d to read" % (len(shocks), len(shocks) - len(todo), len(todo)))
    for n, sh in enumerate(todo):
        if stop and stop():
            log("market hours - pausing; run again after 15:35"); break
        s = sh["sym"]
        if s not in RD:
            RD[s] = set(S.result_days(s, R, BM, sorted(DAY.get(s) or {})))
        try:
            fl = nse_filings(s, sh["d"], getj=getj)
        except Exception as ex:
            fl = []; log("  nse %s %s: %s" % (s, sh["d"], str(ex)[:60]))
        nw = []
        for nm in NM.get(s, [s])[:2]:
            try:
                nw += news_of(nm, sh["d"], get)
            except Exception:
                pass
        r, line, src = decide(sh, fl, nw, sh["d"] in RD[s])
        d0 = dt.date.fromisoformat(sh["d"])
        cut = dt.datetime.combine(d0 - dt.timedelta(days=4), dt.time(15, 30), IST).timestamp()
        warn = [(dt.datetime.fromtimestamp(f[0], IST).strftime("%Y-%m-%d"), f[1], f[3][:140]) for f in fl
                if f[0] < cut and (f[1] in ("REG", "MGMT") or reason_of(f[3]) == "GOVERNANCE") and f[2] <= 0]
        lead = [(dt.datetime.fromtimestamp(f[0], IST).strftime("%Y-%m-%d"), f[1], f[3][:140]) for f in fl
                if f[0] < cut and f[1] in ("ORDER", "REG", "BOARD", "RATING", "SALES") and f[2] > 0]
        C["%s:%s" % (s, sh["d"])] = {"reason": r, "line": line[:240], "src": src, "warn": warn[:4], "lead": lead[:4], "news": [t for t, _ in nw[:4]]}
        if n % 20 == 0:
            log("  %d/%d %s %s %+.1f%% -> %s %s" % (n + 1, len(todo), s, sh["d"], sh["mv"], r, line[:70]))
            os.makedirs(S.H3, exist_ok=True)
            json.dump(C, open(CACHE, "w"))
        time.sleep(pause)
    os.makedirs(S.H3, exist_ok=True)
    json.dump(C, open(CACHE, "w"))
    return C


# ---------------------------------------------------------------- 3. the report
def report(shocks, base, tot, C):
    for x in shocks:
        x.update(C.get("%s:%s" % (x["sym"], x["d"])) or {"reason": "NOT READ", "line": "", "src": "", "warn": [], "lead": [], "news": []})
    crowd_n = {}
    for x in shocks:
        crowd_n[(x["d"], x["side"])] = crowd_n.get((x["d"], x["side"]), 0) + 1
    for x in shocks:
        x["reason"], x["line"] = refine(x, crowd_n[(x["d"], x["side"])])
    up = [x for x in shocks if x["side"] > 0]; dn = [x for x in shocks if x["side"] < 0]
    days = sorted({x["d"] for x in shocks})
    L = ["🧱 SHOCK DAYS · F&O shares%s · ▲ up and ▼ down" % ((" · %s to %s" % (days[0], days[-1])) if days else ""),
         "F&O shares have no fixed circuit (NSE's band starts at 10%% and is widened). A shock = closed %.0f%%+ or traded %.0f%%+ from the previous close."
         % (CLOSE_BIG, TOUCH),
         "%d shocks: ▲ %d up · ▼ %d down · %d share-days in all (a shock on %.2f%% of days)" % (len(shocks), len(up), len(dn), tot[0],
                                                                                              100 * len(shocks) / tot[0] if tot[0] else 0)]
    L += ["", "YEAR BY YEAR (▲ up shocks / ▼ down shocks · the year's biggest each way)"]
    for y in sorted({x["d"][:4] for x in shocks}):
        U = [x for x in up if x["d"][:4] == y]; Dn = [x for x in dn if x["d"][:4] == y]
        bu = max(U, key=lambda x: x["mv"]) if U else None; bd = min(Dn, key=lambda x: x["mv"]) if Dn else None
        L.append("  %s  ▲ %4d  ▼ %4d · biggest ▲ %s · biggest ▼ %s%s" % (y, len(U), len(Dn), ("%s %+.0f%% %s" % (bu["sym"], bu["mv"], bu["d"][5:])) if bu else "-",
                 ("%s %+.0f%% %s" % (bd["sym"], bd["mv"], bd["d"][5:])) if bd else "-", "  (from %s)" % min(x["d"] for x in shocks if x["d"][:4] == y) if y == days[0][:4] else ""))
    crowd = {}
    for x in shocks:
        crowd.setdefault((x["d"], x["side"]), []).append(x)
    crowd = sorted(((k, X) for k, X in crowd.items() if len(X) >= 15), key=lambda kv: -len(kv[1]))
    if crowd:
        L += ["", "MARKET-WIDE DAYS (15+ F&O shares shocked together - the market, not the company)"]
        L += ["  %s %s %3d shares · NIFTY %s" % (k[0], "▲" if k[1] > 0 else "▼", len(X), ("%+.1f%%" % X[0]["nifty"]) if X[0]["nifty"] is not None else "-") for k, X in crowd[:8]]
    read = sum(1 for x in shocks if x["reason"] != "NOT READ")
    if read < len(shocks):
        L.append("reasons read so far: %d of %d (the biggest first) - run 'python3 circuits.py reasons' again to finish" % (read, len(shocks)))
    for nm, G in (("▼ DOWN", dn), ("▲ UP", up)):
        if not G:
            continue
        L += ["", "%s SHOCKS - why (count · avg move · the next day · 5 days later · went on the same way next day)" % nm]
        by = {}
        for x in G:
            by.setdefault(x["reason"], []).append(x)
        for r, X in sorted(by.items(), key=lambda kv: -len(kv[1])):
            nx = [x["next"] for x in X if x["next"] is not None]; n5 = [x["n5"] for x in X if x["n5"] is not None]
            same = sum(1 for v in nx if v * X[0]["side"] > 0)
            L.append("  %-11s %4d · %+6.1f%% · next %+5.1f%% · 5d %+5.1f%% · same way %s" % (r, len(X), S.avg([x["mv"] for x in X]), S.avg(nx), S.avg(n5),
                                                                                         S.share(same, len(nx))))
        gap = sum(1 for x in G if abs(x["gap"]) >= 5 and x["gap"] * x["side"] > 0)
        L.append("  opened with a 5%%+ gap (news came overnight): %s · built up during the day: %s" % (S.share(gap, len(G)), S.share(len(G) - gap, len(G))))
    for nm, G in (("▼ THE 15 BIGGEST FALLS", sorted(dn, key=lambda x: x["mv"])[:15]), ("▲ THE 15 BIGGEST RISES", sorted(up, key=lambda x: -x["mv"])[:15])):
        if G:
            L += ["", nm]
            L += ["  %s %-11s %+6.1f%% %-10s %s" % (x["d"], x["sym"], x["mv"], x["reason"], x["line"][:90]) for x in G]
    for side_nm, G in (("▼ SHARES THAT FELL HARD AGAIN AND AGAIN (3+ down shocks)", dn), ("▲ SHARES THAT JUMPED AGAIN AND AGAIN (3+ up shocks)", up)):
      rep = {}
      for x in G:
        rep.setdefault(x["sym"], []).append(x)
      rep = sorted(((s, X) for s, X in rep.items() if len(X) >= 3), key=lambda kv: -len(kv[1]))
      if rep:
        L += ["", side_nm]
        for s, X in rep[:15]:
            rs = {}
            for x in X:
                rs[x["reason"]] = rs.get(x["reason"], 0) + 1
            L.append("  %-11s %d · %s · last %s %+.1f%%" % (s, len(X), " ".join("%s %d" % kv for kv in sorted(rs.items(), key=lambda kv: -kv[1])), X[-1]["d"], X[-1]["mv"]))
    if tot[0]:
        L += ["", "BEFORE THE SHOCK - the signs at the previous close (how much likelier a shock came next day than on an ordinary day)"]
        bd, bu = tot[1] / tot[0], tot[2] / tot[0]
        for x in SIGNS:
            n, d, u = base.get(x, [0, 0, 0])
            if n >= 50:
                L.append("  %-44s %6d days · ▼ next %.2f%% (%.1fx) · ▲ next %.2f%% (%.1fx)" % (x, n, 100 * d / n, (d / n) / bd if bd else 0, 100 * u / n, (u / n) / bu if bu else 0))
        L.append("  an ordinary day: ▼ %.2f%% · ▲ %.2f%%" % (100 * bd, 100 * bu))
    wd = [x for x in dn if x.get("warn")]
    if read:
        L += ["", "▼ A WARNING FILED FIRST (a regulator / management / governance filing 4-30 days before the fall): %d of %d read falls"
              % (len(wd), sum(1 for x in dn if x["reason"] != "NOT READ"))]
        for x in sorted(wd, key=lambda x: x["mv"])[:8]:
            w = x["warn"][0]
            L.append("  %s %s %+.1f%% <- %s %s: %s" % (x["d"], x["sym"], x["mv"], w[0], w[1], w[2][:80]))
    ld = [x for x in up if x.get("lead")]
    if read:
        L += ["", "▲ GOOD NEWS FILED FIRST (an order / approval / board decision 4-30 days before the jump): %d of %d read jumps"
              % (len(ld), sum(1 for x in up if x["reason"] != "NOT READ"))]
        for x in sorted(ld, key=lambda x: -x["mv"])[:8]:
            w = x["lead"][0]
            L.append("  %s %s %+.1f%% <- %s %s: %s" % (x["d"], x["sym"], x["mv"], w[0], w[1], w[2][:80]))
    J = {"built": str(dt.date.today()), "from": days[0] if days else "", "close_big": CLOSE_BIG, "touch": TOUCH, "by_sym": {}, "by_reason": {}}
    for x in shocks:
        J["by_sym"].setdefault(x["sym"], []).append({k: x[k] for k in ("d", "side", "mv", "next", "n5", "reason", "line")})
        b = J["by_reason"].setdefault("%s:%d" % (x["reason"], x["side"]), {"n": 0, "mv": 0.0, "next": []})
        b["n"] += 1; b["mv"] += x["mv"]
        if x["next"] is not None:
            b["next"].append(x["next"])
    for b in J["by_reason"].values():
        b["mv"] = round(b["mv"] / b["n"], 2); b["next"] = round(S.avg(b["next"]), 2)
    return L, J


def extend(syms, since="2022-11-01", log=print):
    """the year before data/h3's 3 years: daily candles from Kite and the NSE futures file, merged in (resumable)"""
    import numpy as np, hist3y as Hh
    s0 = dt.date.fromisoformat(since)
    try:
        k = Hh.kite(); tok = Hh.tokens(k)
    except Exception as ex:
        log("Kite not reachable (%s) - the candles stay at 3 years" % str(ex)[:80]); tok = None
    n_new = 0
    for i, s in enumerate((Hh.INDICES + syms) if tok else []):
        p = os.path.join(S.H3, "day", Hh.fname(s) + ".npz")
        if not os.path.exists(p) or not tok.get(s):
            continue
        a = np.load(p)
        first = dt.datetime.fromtimestamp(float(a["ts"].min()), IST).date()
        if first <= s0 + dt.timedelta(days=10):
            continue
        try:
            rows = Hh.candles(k, tok[s], s0, first - dt.timedelta(days=1), "day", 1900)
        except Exception as ex:
            log("  %s: %s" % (s, str(ex)[:80])); continue
        old = [{"date": dt.datetime.fromtimestamp(float(t), IST), "open": o, "high": h, "low": l, "close": c, "volume": v}
               for t, o, h, l, c, v in zip(a["ts"], a["o"], a["h"], a["l"], a["c"], a["v"])]
        Hh.save_npz(p, rows + old)
        n_new += 1
        if i % 25 == 0:
            log("  candles %d/%d %s: +%d days (from %s)" % (i + 1, len(Hh.INDICES) + len(syms), s, len(rows), since))
    log("candles from Kite: %d shares/indices taken back to %s" % (n_new, since))
    extend_nse(syms, s0, log)
    c = Hh.fo_db()
    done = {r[0] for r in c.execute("select d from done where status in ('ok', 'holiday')")}
    first = c.execute("select min(d) from fut").fetchone()[0] or str(dt.date.today())
    d, n = s0, 0
    while str(d) < first:
        if d.weekday() < 5 and str(d) not in done:
            try:
                v = Hh.fo_one(d)
                if isinstance(v, str):
                    c.execute("insert or replace into done values(?,?)", (str(d), v))
                else:
                    c.executemany("insert or replace into fut values(?,?,?,?,?,?,?,?,?,?,?)", [(str(d), x) + tuple(y) for x, y in v.items()])
                    c.execute("insert or replace into done values(?,?)", (str(d), "ok"))
                c.commit(); n += 1
            except Exception as ex:
                log("  nse fo %s: %s" % (d, str(ex)[:60]))
            time.sleep(0.8)
        d += dt.timedelta(days=1)
    c.close()
    log("NSE futures files: %d more days (back to %s)" % (n, since))
    return 0


NSE_CM = "https://nsearchives.nseindia.com/content/historical/EQUITIES/%d/%s/cm%02d%s%dbhav.csv.zip"
NSE_IDX = "https://nsearchives.nseindia.com/content/indices/ind_close_all_%s.csv"


def extend_nse(syms, s0, log=print, get=None):
    """the shares (and NIFTY 50) Kite did not take back: NSE's own daily files (the equity bhavcopy, the index closes). A later split /
    bonus makes the old prices a different scale - joined by the ratio at the seam."""
    import io, zipfile, numpy as np, hist3y as Hh
    need = {}
    for s in syms + ["NIFTY 50"]:
        p = os.path.join(S.H3, "day", Hh.fname(s) + ".npz")
        if os.path.exists(p):
            first = dt.datetime.fromtimestamp(float(np.load(p)["ts"].min()), IST).date()
            if first > s0 + dt.timedelta(days=10):
                need[s] = first
    if not need:
        return 0
    log("NSE daily files for %d shares/indices Kite did not take back..." % len(need))
    end = max(need.values())
    rows = {s: [] for s in need}
    d = s0
    def fetch(url):
        if get:
            return get(url)
        import requests
        r = requests.get(url, headers=UA, timeout=30)
        return r.content if r.status_code == 200 else None
    while d < end:
        if d.weekday() < 5:
            mon = Hh.MON[d.month - 1]
            try:
                z = fetch(NSE_CM % (d.year, mon, d.day, mon, d.year))
                if z:
                    txt = zipfile.ZipFile(io.BytesIO(z)).read(zipfile.ZipFile(io.BytesIO(z)).namelist()[0]).decode("utf-8", "ignore")
                    hdr = None
                    for line in txt.splitlines():
                        c = [x.strip() for x in line.split(",")]
                        if hdr is None:
                            hdr = {k: j for j, k in enumerate(c)}; continue
                        sy = c[hdr["SYMBOL"]] if "SYMBOL" in hdr else ""
                        if sy in rows and c[hdr.get("SERIES", 1)] == "EQ" and d < need[sy]:
                            rows[sy].append({"date": dt.datetime.combine(d, dt.time(0, 0), IST), "open": float(c[hdr["OPEN"]]), "high": float(c[hdr["HIGH"]]),
                                             "low": float(c[hdr["LOW"]]), "close": float(c[hdr["CLOSE"]]), "volume": float(c[hdr.get("TOTTRDQTY", 8)])})
                if "NIFTY 50" in rows and d < need["NIFTY 50"]:
                    t = fetch(NSE_IDX % d.strftime("%d%m%Y"))
                    for line in (t.decode("utf-8", "ignore") if isinstance(t, bytes) else (t or "")).splitlines():
                        c = [x.strip() for x in line.split(",")]
                        if c and c[0].upper() == "NIFTY 50" and len(c) > 5:
                            rows["NIFTY 50"].append({"date": dt.datetime.combine(d, dt.time(0, 0), IST), "open": float(c[2]), "high": float(c[3]),
                                                     "low": float(c[4]), "close": float(c[5]), "volume": 0})
            except Exception as ex:
                log("  nse day %s: %s" % (d, str(ex)[:60]))
            time.sleep(0.4)
        d += dt.timedelta(days=1)
    n = 0
    for s, R in rows.items():
        if not R:
            continue
        p = os.path.join(S.H3, "day", Hh.fname(s) + ".npz")
        a = np.load(p)
        i0 = int(np.argmin(a["ts"]))
        ratio = float(a["o"][i0]) / R[-1]["close"] if R[-1]["close"] else 1.0
        if abs(ratio - 1) > 0.25:                              # a split / bonus since: put the old prices on today's scale
            for r in R:
                for k in ("open", "high", "low", "close"):
                    r[k] *= ratio
        old = [{"date": dt.datetime.fromtimestamp(float(t), IST), "open": o, "high": h, "low": l, "close": c, "volume": v}
               for t, o, h, l, c, v in zip(a["ts"], a["o"], a["h"], a["l"], a["c"], a["v"])]
        Hh.save_npz(p, R + old); n += 1
    log("NSE daily files: %d shares/indices taken back to %s" % (n, s0))
    return n


def load():
    syms = S.fo_list()
    DAY = {s: S.daily(s) for s in syms + ["NIFTY 50"]}
    return syms, DAY


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "report"
    syms, DAY = load()
    shocks, base, tot = find(syms, DAY, futmap())
    if cmd == "extend":
        return extend(syms)
    if cmd == "find":
        print("%d shocks (▲ %d up · ▼ %d down) in %d share-days, %s to %s" % (len(shocks), sum(1 for x in shocks if x["side"] > 0), sum(1 for x in shocks if x["side"] < 0),
              tot[0], min(x["d"] for x in shocks) if shocks else "-", max(x["d"] for x in shocks) if shocks else "-"))
        for y in sorted({x["d"][:4] for x in shocks}):
            U = [x for x in shocks if x["d"][:4] == y and x["side"] > 0]; Dn = [x for x in shocks if x["d"][:4] == y and x["side"] < 0]
            print("  %s  ▲ %4d up  ▼ %4d down" % (y, len(U), len(Dn)))
        print("the 5 biggest ▲:  " + " · ".join("%s %s %+.0f%%" % (x["d"], x["sym"], x["mv"]) for x in sorted([x for x in shocks if x["side"] > 0], key=lambda x: -x["mv"])[:5]) or "-")
        print("the 5 biggest ▼:  " + " · ".join("%s %s %+.0f%%" % (x["d"], x["sym"], x["mv"]) for x in sorted([x for x in shocks if x["side"] < 0], key=lambda x: x["mv"])[:5]) or "-")
        return 0
    if cmd in ("reasons", "all"):
        reasons(shocks, syms, DAY, log=lambda m: print(dt.datetime.now(IST).strftime("%H:%M:%S"), m, flush=True))
        if cmd == "reasons":
            return 0
    try:
        C = json.load(open(CACHE))
    except Exception:
        C = {}
    L, J = report(shocks, base, tot, C)
    txt = "\n".join(L)
    print(txt)
    os.makedirs(S.H3, exist_ok=True)
    open(os.path.join(S.H3, "circuits.txt"), "w").write(txt)
    json.dump(J, open(os.path.join(S.H3, "circuits.json"), "w"))
    if "--no-tg" not in argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % S.send_tg(txt))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
CIRCUITS_PY
cat > $D/tvstt.py <<'TVSTT_PY'
#!/usr/bin/env python3
"""tvstt.py - patch 162: the speech reader for 📺 TV WATCH. Runs in /home/globalbot/tvenv (faster-whisper). Loads the model ONCE, then
reads one line per recording on stdin ("path<TAB>lang") and writes one JSON line per recording on stdout:
  {"path": ..., "text": ..., "secs": length, "took": seconds, "level": loudness}
  tvstt.py <model> <threads> <prompt file>"""
import sys, json, time, wave
import numpy as np
from faster_whisper import WhisperModel

size, threads = sys.argv[1], int(sys.argv[2])
try:
    prompt = open(sys.argv[3]).read().strip()[:600]
except Exception:
    prompt = ""
m = WhisperModel(size, device="cpu", compute_type="int8", cpu_threads=threads)
print(json.dumps({"ready": size}), flush=True)
for line in sys.stdin:
    try:
        path, lang = line.rstrip("\n").split("\t")
        w = wave.open(path)
        a = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
        lv = float(np.sqrt(np.mean(a ** 2))) if len(a) else 0.0
        t0 = time.time()
        txt = ""
        if lv >= 0.004:
            segs, _ = m.transcribe(a, language=lang, task="translate" if lang == "hi" else "transcribe", vad_filter=True, beam_size=1,
                                   initial_prompt=prompt or None, condition_on_previous_text=False)
            txt = " ".join(s.text.strip() for s in segs)
        print(json.dumps({"path": path, "text": txt, "secs": round(len(a) / 16000.0, 1), "took": round(time.time() - t0, 1), "level": round(lv, 4)}), flush=True)
    except Exception as ex:
        print(json.dumps({"path": line.strip(), "error": str(ex)[:200]}), flush=True)
TVSTT_PY
cat > $D/tvwatch.py <<'TVWATCH_PY'
#!/usr/bin/env python3
"""tvwatch.py - patch 162: 📺 TV WATCH (Rama: "make someone watch the live TV" · "how fast can the bot find these"). Listens to business
TV live on YouTube all session (09:00-15:40 on NSE trading days) and turns the speech into text every 20 seconds:
  CNBC-TV18 (English) by default; CNBC Awaaz / Zee Business (Hindi -> English) / ET Now / Sansad TV can be added in data/tvwatch.json
When the anchors or a reporter name an F&O company together with the kind of news that moved F&O shares 8%+ in the last years
(circuits.py: a regulator acting, governance trouble, a boss quitting, an order / deal / approval, a policy) it says it at once as a
⚠️ SHOCK WATCH (GIR Box Picks, rings) or 📰 SHOCK WATCH (News topic, quiet) - the same rules as the news / filings watcher, with the
words heard on air. Every transcript is kept in data/tv.db (the page can show it). About 40-70 s from the words on air to Telegram.
  python3 tvwatch.py run        the service (gir-tvwatch) - restarts the stream by itself when YouTube drops it
  python3 tvwatch.py once       one 20-second listen of each channel now, printed (nothing sent) - a check
data/tvwatch.json: {"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": false}  ("always": true = listen outside hours)"""
import os, re, sys, json, time, glob, signal, sqlite3, subprocess, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
V = os.environ.get("GIR_TVENV", "/home/globalbot/tvenv")
TMP = "/tmp/tvwatch"
DB = os.path.join(BASE, "data", "tv.db")
CONF = os.path.join(BASE, "data", "tvwatch.json")
STATUS = os.path.join(BASE, "data", "tvwatch_status.json")
LOG = os.path.join(BASE, "data", "tvwatch.log")
SEG = 20
CHANNELS = {"CNBC-TV18": ("https://www.youtube.com/@cnbc-tv18/live", "en"), "CNBC AWAAZ": ("https://www.youtube.com/@CNBCAwaaz/live", "hi"),
            "ZEE BUSINESS": ("https://www.youtube.com/@ZeeBusiness/live", "hi"), "ET NOW": ("https://www.youtube.com/@etnow/live", "en"),
            "SANSAD TV": ("https://www.youtube.com/@SansadTV/live", "hi")}
DEFAULT = {"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": False}
FLASH = re.compile(r"breaking|just in|news flash|newsflash|sources (?:say|said|tell)|according to sources|exclusive|we are just getting|this just in", re.I)
TV_KEEP = ("REGULATOR", "GOVERNANCE", "MGMT", "ORDER", "DEAL", "POLICY")


def log(msg):
    line = "%s %s" % (dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    try:
        open(LOG, "a").write(line + "\n")
    except Exception:
        pass


def conf():
    c = dict(DEFAULT)
    try:
        c.update(json.load(open(CONF)))
    except Exception:
        pass
    c["channels"] = [x for x in c["channels"] if x in CHANNELS] or ["CNBC-TV18"]
    return c


def window(now, c):
    """listen on NSE trading days 08:55-15:40 (or always, when asked)"""
    if c.get("always"):
        return True
    if now.weekday() >= 5 or not (dt.time(8, 55) <= now.time() <= dt.time(15, 40)):
        return False
    try:
        import holidays
        return not holidays.holiday(now.date())
    except Exception:
        return True


# ---------------------------------------------------------------- what was said -> findings
def scan(ch, text, prev, match, now):
    """-> [finding] for one 20-s transcript (with the end of the one before, so a sentence cut in two is still read)"""
    import circuits as C
    whole = ((prev or "")[-240:] + " " + (text or "")).strip()
    out = []
    for s in match(whole):
        pos = []
        for n in (NM.get(s) or [s]):
            fl = 0 if (n.isupper() and len(n) <= 5) else re.I
            pos += [m.start() for m in re.finditer(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(n), whole, fl)]
        i = max(pos) if pos else 0
        win = whole[max(0, i - 220): i + 260]
        r = C.reason_of(win)
        if r not in TV_KEEP:
            continue
        sd = C.side_of(win)
        if sd == 0:
            if r in ("REGULATOR", "GOVERNANCE"):
                sd = -1                                   # a regulator / governance story with no word either way: trouble until it says otherwise
            else:
                continue
        flash = bool(FLASH.search(win))
        out.append({"key": "TV:%s:%s" % (s, r), "sym": s, "reason": r, "side": sd, "head": "on air: “%s”" % re.sub(r"\s+", " ", win).strip()[:300],
                    "src": "TV %s" % ch, "link": "", "circ": flash})
    return out


NM = {}


def fo_names():
    import circuits as C, shockwatch as W
    fo = W.fo_syms()
    NM.clear(); NM.update(C.names(fo))
    return W.matcher(NM)


def prompt_text():
    names = []
    for s, L in sorted(NM.items()):
        if L:
            names.append(L[0])
    return ("Indian stock market news on business TV. Nifty, Sensex, Bank Nifty, F&O, crore, RBI, SEBI, IRDAI, USFDA. Companies: " + ", ".join(names))[:600]


# ---------------------------------------------------------------- the stream -> 20-s recordings
def stream_url(url):
    cmd = [os.path.join(V, "bin", "yt-dlp"), "-q", "--no-warnings", "-f", "bestaudio/best", "-g"]
    if os.path.exists(os.path.join(V, "bin", "deno")):
        cmd += ["--js-runtimes", "deno:" + os.path.join(V, "bin", "deno")]
    if os.path.exists(os.path.join(V, "cookies.txt")):
        cmd += ["--cookies", os.path.join(V, "cookies.txt")]
    env = dict(os.environ, PATH=os.path.join(V, "bin") + ":" + os.environ.get("PATH", ""))
    r = subprocess.run(cmd + [url], capture_output=True, text=True, timeout=90, env=env)
    u = (r.stdout or "").strip().split("\n")[0]
    if not u:
        raise RuntimeError((r.stderr or "no stream")[-160:].replace("\n", " "))
    return u


class Feed:
    def __init__(self, ch):
        self.ch, (self.url, self.lang) = ch, CHANNELS[ch]
        self.tag = re.sub(r"\W+", "", ch).lower()
        self.proc, self.fails, self.next_try = None, 0, 0.0

    def start(self):
        os.makedirs(TMP, exist_ok=True)
        for f in glob.glob(os.path.join(TMP, self.tag + "_*.wav")):
            os.remove(f)
        u = stream_url(self.url)
        self.proc = subprocess.Popen(["nice", "-n", "12", "ffmpeg", "-nostdin", "-loglevel", "error", "-i", u, "-vn", "-ac", "1", "-ar", "16000",
                                      "-c:a", "pcm_s16le", "-f", "segment", "-segment_time", str(SEG), "-reset_timestamps", "1",
                                      os.path.join(TMP, self.tag + "_%06d.wav")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log("%s: listening" % self.ch)

    def alive(self):
        return self.proc is not None and self.proc.poll() is None

    def stop(self):
        if self.alive():
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except Exception:
                self.proc.kill()
        self.proc = None

    def chunks(self):
        """finished recordings, oldest first (the newest is still being written)"""
        fs = sorted(glob.glob(os.path.join(TMP, self.tag + "_*.wav")))
        return fs[:-1] if self.alive() else fs


class Worker:
    """the speech reader in the tool folder's Python, kept running (the model loads once)"""
    def __init__(self, c, cmd=None):
        pf = os.path.join(TMP, "prompt.txt")
        os.makedirs(TMP, exist_ok=True)
        open(pf, "w").write(prompt_text())
        py = os.path.join(V, "bin", "python")
        self.p = subprocess.Popen(cmd or ["nice", "-n", "10", py, os.path.join(BASE, "tvstt.py"), c["model"], str(c["threads"]), pf],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(TMP, "tvstt.err"), "w"), text=True, bufsize=1)
        first = json.loads(self.p.stdout.readline() or "{}")
        if not first.get("ready"):
            try:
                err = open(os.path.join(TMP, "tvstt.err")).read().strip().splitlines()[-1:]
            except Exception:
                err = []
            raise RuntimeError("the speech reader did not start: %s" % (err[0][:200] if err else "no answer"))

    def read(self, path, lang):
        self.p.stdin.write("%s\t%s\n" % (path, lang)); self.p.stdin.flush()
        return json.loads(self.p.stdout.readline() or "{}")

    def stop(self):
        try:
            self.p.terminate()
        except Exception:
            pass


def keep(ch, ts, r):
    try:
        os.makedirs(os.path.dirname(DB), exist_ok=True)
        c = sqlite3.connect(DB, timeout=5)
        c.execute("create table if not exists tv(ts real, ch text, text text, secs real, took real, level real)")
        c.execute("insert into tv values(?,?,?,?,?,?)", (ts, ch, r.get("text") or "", r.get("secs") or 0, r.get("took") or 0, r.get("level") or 0))
        c.execute("delete from tv where ts < ?", (ts - 10 * 86400,))
        c.commit(); c.close()
    except Exception as ex:
        log("tv.db: %s" % ex)


def run(send=None):
    import shockwatch as W
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
    match = fo_names()
    try:
        H = json.load(open(W.HIST))
    except Exception:
        H = {}
    feeds, worker, prev, said = {}, None, {}, {}
    st = {}
    while True:
        c = conf()
        now = dt.datetime.now(IST)
        if not window(now, c):
            if feeds or worker:
                for f in feeds.values():
                    f.stop()
                feeds = {}
                if worker:
                    worker.stop(); worker = None
                log("outside market hours - not listening")
            time.sleep(60)
            continue
        if worker is None:
            worker = Worker(c)
            log("speech reader ready (%s, %d threads)" % (c["model"], c["threads"]))
        for ch in c["channels"]:
            f = feeds.setdefault(ch, Feed(ch))
            if not f.alive() and time.time() >= f.next_try:
                try:
                    f.start(); f.fails = 0
                except Exception as ex:
                    f.fails += 1; f.next_try = time.time() + min(600, 30 * f.fails)
                    log("%s: no stream (%s) - again in %d s" % (ch, str(ex)[:120], min(600, 30 * f.fails)))
                    if f.fails == 5 and send:                # say it once, so a dead TV feed is never silent
                        hint = " - the YouTube sign-in may have expired: export the cookies again" if re.search(r"sign in|bot|cookies", str(ex), re.I) else ""
                        send("📋 TV WATCH: %s - no stream since %s (%s)%s" % (ch, now.strftime("%H:%M"), str(ex)[:120], hint))
        for ch, f in list(feeds.items()):
            if ch not in c["channels"]:
                f.stop(); del feeds[ch]; continue
            fs = f.chunks()
            if len(fs) > 4:                                  # behind: drop the old ones, stay live
                for x in fs[:-2]:
                    os.remove(x)
                log("%s: %d recordings behind - skipped to live" % (ch, len(fs) - 2))
                fs = fs[-2:]
            for path in fs:
                ts = time.time()
                try:
                    r = worker.read(path, f.lang)
                except Exception as ex:
                    log("speech reader: %s - restarting it" % ex); worker.stop(); worker = None; break
                try:
                    os.remove(path)
                except Exception:
                    pass
                txt = (r.get("text") or "").strip()
                keep(ch, ts, r)
                st[ch] = {"t": now.strftime("%H:%M:%S"), "took": r.get("took"), "level": r.get("level"), "said": txt[:160]}
                if txt:
                    log("%s %.0fs read in %.0fs: %s" % (ch, r.get("secs") or 0, r.get("took") or 0, txt[:150]))
                    for x in scan(ch, txt, prev.get(ch), match, now):
                        k = (x["sym"], x["reason"])
                        if time.time() - said.get(k, 0) < 1800:
                            continue
                        said[k] = time.time()
                        msg = W.line(x, H, dt.datetime.now(IST))
                        log("ALERT " + msg.split("\n")[0])
                        if send:
                            send(msg)
                prev[ch] = txt
            if worker is None:
                break
        try:
            json.dump({"at": now.strftime("%H:%M:%S"), "channels": st}, open(STATUS, "w"))
        except Exception:
            pass
        time.sleep(2)


def once():
    """one 20-s listen of each channel now (a check - nothing sent)"""
    c = conf()
    fo_names()
    w = Worker(c)
    print("speech reader ready (%s)" % c["model"])
    os.makedirs(TMP, exist_ok=True)
    for ch in c["channels"]:
        url, lang = CHANNELS[ch]
        try:
            u = stream_url(url)
        except Exception as ex:
            print("%s: no stream - %s" % (ch, str(ex)[:120])); continue
        p = os.path.join(TMP, "once.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", u, "-t", str(SEG), "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", p], timeout=90)
        r = w.read(p, lang)
        print("%s: %.0f s of TV read in %.0f s · loudness %.3f%s" % (ch, r.get("secs") or 0, r.get("took") or 0, r.get("level") or 0, "" if (r.get("level") or 0) >= 0.004 else " (silent)"))
        print("  heard: %s" % ((r.get("text") or "-")[:400]))
    w.stop()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "once"
    if cmd == "once":
        once()
    elif cmd == "run":
        snd = None
        if "--send" in sys.argv:
            import opencall
            snd = opencall.send_tg
        run(snd)
TVWATCH_PY
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
cat > $D/p162test.py <<'P162TEST_PY'
#!/usr/bin/env python3
"""p162test.py - patch 162: 📺 TV WATCH on made-up speech (no stream, no model, nothing sent)"""
import os, sys, json, wave, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import tvwatch as T, shockwatch as W, circuits as C

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  FAIL ") + name)
    ok = ok and bool(cond)

D = tempfile.mkdtemp()
T.TMP = D; T.DB = os.path.join(D, "tv.db")
T.NM.clear(); T.NM.update({"COCHINSHIP": ["Cochin Shipyard"], "MANAPPURAM": ["Manappuram"], "HAL": ["HAL", "Hindustan Aeronautics"], "INFY": ["Infosys"],
                           "SBIN": ["SBI", "State Bank of India"]})
match = W.matcher(T.NM)
now = dt.datetime(2026, 11, 11, 10, 42, tzinfo=T.IST)
f1 = T.scan("CNBC-TV18", "Breaking news coming in. Sources say Cochin Shipyard has bagged an order worth 2,500 crore rupees from the Indian Navy.", "", match, now)
check("on air: Cochin Shipyard bags a 2,500 crore order -> COCHINSHIP ▲ ORDER", len(f1) == 1 and f1[0]["sym"] == "COCHINSHIP" and f1[0]["reason"] == "ORDER" and f1[0]["side"] == 1)
a1 = W.line(f1[0], {}, now)
print(a1, "\n")
check("it rings: ⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER · TV CNBC-TV18, with the words heard", a1.startswith("⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER · TV CNBC-TV18") and "on air:" in a1)
f2 = T.scan("CNBC-TV18", "has imposed restrictions on Manappuram Finance's gold loan business with immediate effect.", "and just in, the Reserve Bank of India", match, now)
check("a sentence cut across two recordings: RBI ... restrictions on Manappuram -> MANAPPURAM ▼ REGULATOR", len(f2) == 1 and f2[0]["sym"] == "MANAPPURAM" and f2[0]["side"] == -1 and f2[0]["reason"] == "REGULATOR")
check("market chatter (Nifty flat, IT mixed, Infosys up half a percent) -> nothing", T.scan("CNBC-TV18", "Nifty is trading flat, IT stocks are mixed, Infosys up half a percent.", "", match, now) == [])
check("'shall' is not HAL; 'SBI' is", T.scan("X", "we shall see a penalty imposed soon", "", match, now) == [] and [x["sym"] for x in T.scan("X", "RBI imposes a penalty on SBI", "", match, now)] == ["SBIN"])
c0 = dict(T.DEFAULT)
check("listens on a trading day 09:30, not at 16:00, not on Saturday", T.window(dt.datetime(2026, 11, 11, 9, 30, tzinfo=T.IST), c0)
      and not T.window(dt.datetime(2026, 11, 11, 16, 0, tzinfo=T.IST), c0) and not T.window(dt.datetime(2026, 11, 14, 10, 0, tzinfo=T.IST), c0))
# recordings: the newest is still being written
f = T.Feed("CNBC-TV18")
for i in range(3):
    open(os.path.join(D, "cnbctv18_%06d.wav" % i), "w").write("x")
class P:
    def poll(self): return None
f.proc = P()
check("the finished recordings, oldest first, not the one being written", [os.path.basename(x) for x in f.chunks()] == ["cnbctv18_000000.wav", "cnbctv18_000001.wav"])
f.proc = None
# the speech reader protocol, with a stand-in reader
fake = os.path.join(D, "fake_stt.py")
open(fake, "w").write('import sys, json\nprint(json.dumps({"ready": "fake"}), flush=True)\nfor l in sys.stdin:\n    p, lang = l.rstrip("\\n").split("\\t")\n    print(json.dumps({"path": p, "text": "heard " + lang, "secs": 20, "took": 1, "level": 0.05}), flush=True)\n')
w = T.Worker(T.DEFAULT, cmd=[sys.executable, fake])
r = w.read("/x.wav", "hi"); w.stop()
check("the speech reader answers one line per recording", r.get("text") == "heard hi" and r.get("secs") == 20)
T.keep("CNBC-TV18", 1.0e9, {"text": "hello", "secs": 20, "took": 3, "level": 0.1})
import sqlite3
check("every transcript is kept in tv.db", sqlite3.connect(T.DB).execute("select count(*) from tv").fetchone()[0] == 1)
try:
    import alertword, tglanes
    check("a TV ⚠️ rings in Box Picks", tglanes.lane(a1) == "critical" and alertword.tier(a1) != "read")
except Exception as ex:
    check("routing (%s)" % ex, False)
shutil.rmtree(D)
print("P162 TV WATCH TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P162TEST_PY
[ -f $D/data/tvwatch.json ] || echo '{"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": false}' > $D/data/tvwatch.json
echo "   tvwatch.py · tvstt.py · shockwatch.py written · channels: $(cat $D/data/tvwatch.json)"
echo "== 2. the tests (made-up speech and news, nothing sent)"
cd $D && python3 -m py_compile tvwatch.py shockwatch.py p161test.py p162test.py && $V/bin/python -m py_compile tvstt.py || { echo "   does not compile"; exit 1; }
if timeout 180 python3 p161test.py > /tmp/p161test.log 2>&1 && timeout 120 python3 p162test.py > /tmp/p162test.log 2>&1; then echo "   p161test.py + p162test.py passed"; else
  echo "   TEST FAILED - undone:"; grep -hE "FAIL|Error" /tmp/p161test.log /tmp/p162test.log | head -6 | sed 's/^/     /'
  for f in shockwatch.py p161test.py circuits.py; do cp $D/$f.bak162 $D/$f 2>/dev/null; done; rm -f $D/tvwatch.py $D/tvstt.py; exit 1; fi
echo "   the shock-day reasons with the 161c rules:"
if systemctl is-active --quiet gir-shocks; then
  systemctl stop gir-shocks; systemctl reset-failed gir-shocks 2>/dev/null
  systemd-run --unit=gir-shocks --nice=10 /bin/bash -c "cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 circuits.py all >> data/h3/shocks.log 2>&1" >/dev/null 2>&1
  echo "   still reading - restarted with the new rules (what is read is kept); the report comes to the ⚙️ System topic when done"
else
  (cd /home/globalbot && set -a && source .env && set +a && cd $D && nohup nice -n 10 python3 circuits.py report >> data/h3/shocks.log 2>&1 &)
  echo "   all read - the report is being made again; it comes to the ⚙️ System topic in a few minutes"
fi
echo "== 3. a live check: 20 s of each channel now, read with the real model (today may be holiday programming)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 300 nice -n 10 python3 tvwatch.py once 2>&1 | sed 's/^/   /'
echo "== 4. the service"
cat > $U/gir-tvwatch.service <<'UNIT'
[Unit]
Description=GIR TV WATCH (live business TV -> text -> SHOCK WATCH)
After=network-online.target
[Service]
Type=simple
Nice=10
CPUQuota=150%
Restart=always
RestartSec=30
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && exec python3 tvwatch.py run --send >> data/tvwatch_service.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-tvwatch >/dev/null 2>&1 && systemctl restart gir-tvwatch && sleep 3 && systemctl is-active --quiet gir-tvwatch \
  && echo "   gir-tvwatch running: listens 09:00-15:40 on trading days (sleeps now - today is a holiday), at most 1.5 CPUs so GIR is never starved" \
  || echo "   gir-tvwatch did not start: journalctl -u gir-tvwatch -n 20"
echo "   what it hears, live: tail -f $D/data/tvwatch.log"
echo "== 5. how late is the news now (GIR's own measure, last 7 days)"
timeout 300 nice -n 10 python3 newslag.py --days=7 2>/dev/null | grep -iE "^[A-C] |median|minutes|before the move|never|lag" | head -16 | sed 's/^/   /' || echo "   (newslag.py not available)"
echo
echo "PATCH 162 APPLIED. Send Claude a screenshot of sections 3 to 5."
