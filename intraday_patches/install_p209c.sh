#!/bin/bash
# PATCH 209c - the news hunt reads Indian stories only (209b's check found "Nutrien opens $70M fertiliser facility in Western Australia":
#   Google sends the world's news even when asked for India). A story counts when it names one of the moving shares, or it is not about
#   another country (Australia, US, China ... without India / the Centre / ₹ / crore in it); a share-named story is picked first.
#   The check lists the top 5 matches. Replaces newshunt.py, restarts only gir-newshunt - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
[ -f $D/newshunt.py ] || { echo "patch 209 first"; exit 1; }
for f in newshunt.py p209test.py; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in newshunt.py p209test.py; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-newshunt; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/newshunt.py <<'PY_HUNT'
#!/usr/bin/env python3
"""newshunt.py - patch 209: THE NEWS HUNT (Rama, 11 Nov: "the chemical shares were up around 14:13 - you alerted me to act on
COROMANDEL around 14:12, the same time the news was released" - GIR's alert came with the move, but the REASON (the Cabinet's ₹62,370 cr
fertiliser subsidy) reached GIR only at 16:18: the news scout walks 218 shares one by one, ~20 min a round, and nothing searched by topic).
Price is the fastest news - so the move starts the hunt:
  SECTOR JUMP   every 15 s, the live prices: 3+ shares of one group (a sector, a theme, or the fertiliser / sugar / defence-PSU baskets)
                moved 1.5%+ the same way in 15 minutes, beating the market by 1.5%+
                -> 🚨 CRITICAL · SECTOR JUMP ▲ FERTILISER (rings, GIR Box Picks + the page) with the reason when found,
                   else "no news found yet - the reason follows"
  THE HUNT      from that second, every 60 s for 30 min: Google News (the last hour, the group's own words + the movers' names) and
                the business wires GIR reads -> the first fresh headline = 🚨 CRITICAL · THE REASON ▲ FERTILISER (rings)
  BIG MOVERS    an F&O share 2.5%+ in 15 min (or crossing 3% on the day) is hunted the same way; its reason rings when the move is
                3%+ (else a quiet 📰 line); the reason also joins its 🔎 why line (data/newshunt.json, whymove)
  POLICY LANE   every 60 s in market hours (5 min outside): Cabinet / subsidy / duty / PLI / MSP / ban / tariff headlines of the last
                hour -> the groups and F&O shares they touch, with their move now. A Cabinet decision or ₹5,000 cr+ -> 🚨 CRITICAL ·
                POLICY (rings); the rest -> a quiet 📰 GOVT POLICY line
  python3 newshunt.py run           the service (gir-newshunt)
  python3 newshunt.py policy        one policy-lane pass now, printed (nothing sent)
  python3 newshunt.py hunt GROUP [HOURS]   hunt one group's / share's news now (the first story in the last HOURS, 1.5 by default), printed"""
import os, re, sys, json, time, collections, datetime as dt
from urllib.parse import quote

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "data", "newshunt.json")
LOG = os.path.join(BASE, "data", "newshunt.log")
GQ = lambda q: "https://news.google.com/rss/search?q=" + quote(q) + "&hl=en-IN&gl=IN&ceid=IN:en"
WIN, JUMP, REL, MIN_N, ONE, DAY3, HUNT_S, FRESH, MAX_ONE = 900, 1.5, 1.5, 3, 2.5, 3.0, 1800, 5400, 10
EXTRA = {"fertiliser": "COROMANDEL CHAMBLFERT DEEPAKFERT RCF GNFC FACT GSFC PARADEEP NFL MADRASFERT ZUARI",
         "sugar": "BALRAMCHIN EIDPARRY TRIVENI RENUKA BAJAJHIND DALMIASUG DHAMPURSUG",
         "defence-psu": "HAL BEL BDL MAZDOCK COCHINSHIP GRSE BEML MIDHANI",
         "psu-banks": "SBIN PNB BANKBARODA CANBK UNIONBANK INDIANB BANKINDIA MAHABANK IOB UCOBANK CENTRALBK",
         "rail": "IRFC RVNL IRCTC IRCON RAILTEL TITAGARH TEXRAIL JWL RITES",
         "shipping": "SCI GESHIP COCHINSHIP MAZDOCK GRSE",
         "tea-agri": "UPL PIIND RALLIS DHANUKA BAYERCROP SUMICHEM"}
TOPIC = {"fertiliser": r"fertili[sz]er|\burea\b|di-?ammonium|nutrient[- ]based|\bnbs\b|potash|phosphat|subsid\w* .{0,40}(?:p&k|phosph|potash|rabi|kharif)",
         "sugar": r"sugar|ethanol|cane|\bfrp\b", "defence-psu": r"defen[cs]e|\bdac\b|military|missile|warship|\bdrdo\b",
         "defence": r"defen[cs]e|\bdac\b|military|missile|warship|\bdrdo\b", "psu-banks": r"psu bank|public sector bank|recapitali|bank merger|\bpsb",
         "banks": r"\brbi\b|repo|bank", "rail": r"railway|\brail\b|vande bharat|kavach|freight corridor", "shipping": r"shipping|shipbuild|port",
         "metals": r"steel|alumin|copper|zinc|safeguard duty|anti-dumping|iron ore", "china-metals": r"steel|alumin|china|safeguard|anti-dumping",
         "oil-gas": r"crude|petrol|diesel|\blpg\b|natural gas|windfall|\bopec", "crude-freight": r"crude|\bopec|freight|oil price",
         "pharma": r"pharma|drug|usfda|\bfda\b|tariff on (?:drugs|pharma)", "us-pharma": r"pharma|drug|usfda|\bfda\b|tariff",
         "it": r"\bit services|h-?1b|visa|outsourc|tech spending", "us-it": r"h-?1b|visa|outsourc|tariff|tech spending",
         "power": r"power|electricity|renewable|solar|transmission|discom", "ai-power": r"power|data cent|transmission|electricity",
         "telecom-media": r"telecom|spectrum|\btrai\b|tariff hike|\bagr\b", "auto": r"\bauto\b|vehicle|\bev\b|electric vehicle|car sales",
         "auto-anc": r"\bauto\b|vehicle|\bev\b|tyre", "cement-infra": r"cement|infra|highway|construction", "capital-goods": r"capex|order|infra|defen",
         "nbfc": r"nbfc|microfinance|gold loan|housing finance", "insurance": r"insurance|irdai", "capital-mkts": r"sebi|f&o|derivative|demat|mutual fund",
         "fmcg": r"fmcg|gst|rural demand|edible oil", "rural-monsoon": r"monsoon|rural|kharif|rabi|msp|fertili", "consumer": r"consumer|gst|retail",
         "realty": r"real estate|housing|realty|home loan", "chemicals": r"chemical|anti-dumping|fertili|agro", "gold": r"\bgold\b",
         "tea-agri": r"agro|pesticide|crop|kharif|rabi|monsoon", "rate-sensitive": r"\brbi\b|repo|rate cut|rate hike|inflation"}
QWORDS = {"fertiliser": 'fertiliser OR fertilizer OR urea OR "nutrient based subsidy" OR "fertiliser subsidy" OR "P&K subsidy"',
          "sugar": 'sugar OR ethanol OR "cane price"', "defence-psu": 'defence OR DAC OR "defence ministry"', "defence": 'defence OR DAC OR "defence ministry"',
          "psu-banks": '"PSU banks" OR "public sector banks" OR "bank merger"', "rail": 'railway OR "Indian Railways" OR "Vande Bharat"',
          "shipping": 'shipping OR shipbuilding', "metals": 'steel OR "safeguard duty" OR "anti-dumping" OR aluminium OR copper',
          "china-metals": 'steel OR "safeguard duty" OR "anti-dumping"', "oil-gas": 'crude OR "windfall tax" OR petrol OR diesel OR OPEC',
          "crude-freight": 'crude OR OPEC OR "oil prices"', "pharma": 'pharma OR USFDA OR "drug prices"', "us-pharma": 'pharma OR USFDA OR "pharma tariff"',
          "it": '"IT stocks" OR H-1B OR "IT services"', "us-it": '"IT stocks" OR H-1B', "power": '"power stocks" OR electricity OR "power demand"',
          "telecom-media": 'telecom OR spectrum OR TRAI OR "tariff hike"', "auto": '"auto stocks" OR "auto sales" OR EV', "cement-infra": 'cement OR infrastructure',
          "nbfc": 'NBFC OR microfinance OR "gold loan"', "insurance": 'insurance OR IRDAI', "capital-mkts": 'SEBI OR "F&O" OR "capital market stocks"',
          "fmcg": 'FMCG OR GST', "rural-monsoon": 'monsoon OR rural OR MSP OR fertiliser', "realty": '"real estate" OR realty OR housing',
          "chemicals": '"chemical stocks" OR "anti-dumping" OR fertiliser', "gold": 'gold', "tea-agri": 'agrochemical OR pesticide OR kharif OR rabi',
          "rate-sensitive": 'RBI OR "repo rate"', "ai-power": '"data centre" OR transmission OR "power stocks"', "banks": '"bank stocks" OR RBI'}
POLICY_Q = ('("cabinet approves" OR "cabinet clears" OR "cabinet nod" OR "union cabinet" OR "cabinet okays" OR subsidy OR "import duty" OR '
            '"export duty" OR "customs duty" OR "anti-dumping" OR "safeguard duty" OR "PLI scheme" OR MSP OR "export ban" OR "windfall tax" OR '
            '"GST council") when:1h')
INDIA_RX = re.compile(r"\bindia|\bindian\b|\bcentre\b|union cabinet|\bcabinet\b|\bgovt\b|government of india|\bmodi\b|\bsitharaman|\brbi\b|\bsebi\b|"
                      r"\bnse\b|\bbse\b|sensex|nifty|\bdalal|crore|\blakh\b|₹|\brs\.?\s?\d|\brabi\b|\bkharif\b|\bmsp\b|\bdgtr\b|\bpli\b|\bgst\b|"
                      r"maharashtra|gujarat|tamil nadu|karnataka|uttar pradesh|delhi|mumbai|kerala|odisha|rajasthan|punjab|telangana|andhra|bengal|bihar", re.I)
FOREIGN_RX = re.compile(r"australia|malaysia|canada|\bus\b|u\.s\.|america|china|europe|\buk\b|britain|africa|brazil|indonesia|pakistan|bangladesh|"
                        r"sri lanka|nigeria|kenya|philippines|vietnam|russia|ukraine|\$\d|usd|\beur\b", re.I)
CRIT_POLICY = re.compile(r"\bcabinet\b|gst council|export ban|windfall|safeguard duty|anti-dumping", re.I)
_U = {"names": (0.0, {}), "groups": (0.0, {}), "fo": (0.0, set())}


def log(*a):
    line = "%s %s" % (dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"), " ".join(str(x) for x in a))
    print(line, flush=True)
    try:
        open(LOG, "a").write(line + "\n")
    except Exception:
        pass


def groups():
    """{group: [syms]} - GIR's sectors + themes + the extra baskets (a share can sit in several)"""
    t, v = _U["groups"]
    if v and time.time() - t < 3600:
        return v
    g = {}
    try:
        import sectors
        for k, s in (sectors.load() or {}).items():
            g[k] = list(s)
        for k, s in (sectors.themes() or {}).items():
            g[k] = list(s)
    except Exception:
        pass
    for k, s in EXTRA.items():
        g[k] = s.split()
    g = {k: v for k, v in g.items() if k not in ("others", "other", "conglomerate")}
    _U["groups"] = (time.time(), g)
    return g


def names():
    t, v = _U["names"]
    if v and time.time() - t < 3600:
        return v
    try:
        import newsroom
        v = {s: n for s, n, l in newsroom.fo_names()}
    except Exception:
        v = {}
    _U["names"] = (time.time(), v)
    return v


def fo_set():
    t, v = _U["fo"]
    if v and time.time() - t < 3600:
        return v
    v = set(names().keys())
    _U["fo"] = (time.time(), v)
    return v


def amount_cr(s):
    best = 0.0
    for m in re.finditer(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)\s*(lakh crore|lakh cr|crore|cr\b|billion|bn\b)?", s or "", re.I):
        try:
            v = float(m.group(1).replace(",", ""))
        except ValueError:
            continue
        u = (m.group(2) or "").lower()
        cr = v * 1e5 if u.startswith("lakh") else v if u.startswith("cr") else v * 100 if u.startswith(("billion", "bn")) else 0
        best = max(best, cr)
    return best


class Hunter(object):
    def __init__(self, fetch=None, send=None, now_f=None, quotes_f=None, wires=True):
        self.fetch = fetch or self._fetch
        self.send = send or self._send
        self.now_f = now_f or (lambda: dt.datetime.now(IST))
        self.quotes_f = quotes_f or self._quotes
        self.wires = wires
        self.hist = collections.deque()                         # (t, {sym: ltp})
        self.fired = {}                                         # (kind, name, side) -> t
        self.hunts = {}                                         # name -> {...}
        self.seen = set()                                       # headline keys said today
        self.day = None
        self.last_policy = 0.0
        self.wcache = (0.0, [])
        self.day_mv, self.last_h, self.done = {}, None, {}
        self.state = {"reasons": {}, "day": None}

    # -- plumbing
    def _fetch(self, url):
        import requests
        r = requests.get(url, timeout=8, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
                                                  "Accept": "application/rss+xml, application/xml, text/xml, */*"})
        return r.text if r.ok else ""

    def _send(self, text):
        """🚨 rings at once (GIR Box Picks + the page); a quiet 📰 line -> the page + the 15-min 🟡 digest (patch 205)"""
        import opencall
        if text.startswith("🚨"):
            opencall.send_tg(text); return
        opencall.log_alert(text)
        try:
            import digest, tglanes
            box = os.environ.get("TG_CHAT_BOX") or ""
            if not box:
                for line in open("/home/globalbot/.env"):
                    m = re.match(r"\s*(?:export\s+)?TG_CHAT_BOX\s*=\s*(.*?)\s*$", line)
                    if m:
                        box = m.group(1).strip("'\"")
            digest.spool(tglanes.chat_for(text, box), text)
        except Exception as ex:
            log("digest: %s" % str(ex)[:80])

    def _quotes(self):
        try:
            j = json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}
            if time.time() - float(j.get("t") or 0) > 90:
                return {}
            return {s: float(v[0]) for s, v in (j.get("q") or {}).items() if v and v[0]}
        except Exception:
            return {}

    def items(self, url, src):
        """-> [(epoch, title, link, publisher)]"""
        try:
            import macro
            return macro.parse(self.fetch(url) or "", src)
        except Exception:
            return []

    def save(self):
        try:
            os.makedirs(os.path.dirname(STATE), exist_ok=True)
            json.dump(self.state, open(STATE + ".tmp", "w"), ensure_ascii=False); os.replace(STATE + ".tmp", STATE)
        except Exception:
            pass

    # -- the moves
    def moves(self, now_t, q):
        """-> {sym: 15-min move %}, the market's median 15-min move"""
        self.hist.append((now_t, q))
        while self.hist and now_t - self.hist[0][0] > WIN + 60:
            self.hist.popleft()
        old = next((x for t, x in self.hist if now_t - t <= WIN), None)
        if old is None or old is q:
            return {}, 0.0
        mv = {s: (q[s] / old[s] - 1) * 100 for s in q if s in old and old[s]}
        med = sorted(mv.values())[len(mv) // 2] if mv else 0.0
        return mv, med

    def jumps(self, mv, med):
        """-> [(group, side, [(sym, move)])] the groups that jumped together"""
        out = []
        for g, syms in groups().items():
            have = [s for s in syms if s in mv]
            if len(have) < MIN_N:
                continue
            for side in (1, -1):
                hit = sorted([(s, mv[s]) for s in have if mv[s] * side >= JUMP and (mv[s] - med) * side >= REL], key=lambda x: -abs(x[1]))
                if len(hit) >= MIN_N and len(hit) >= 0.4 * len(have):
                    out.append((g, side, hit))
        # one message per basket of shares: a smaller group inside a bigger one with the same movers is said once
        out.sort(key=lambda x: (-len(x[2]), x[0]))
        said, keep = [], []
        for g, side, hit in out:
            k = frozenset(s for s, m in hit)
            if any(k <= o for o in said):
                continue
            said.append(k); keep.append((g, side, hit))
        return keep

    # -- the hunt
    def query_for(self, name, syms, win="1h"):
        nm = names()
        cos = [re.sub(r"\s+(Ltd\.?|Limited)$", "", nm.get(s) or "", flags=re.I) for s in syms[:3]]
        terms = [QWORDS[name]] if name in QWORDS else []
        terms += ['"%s"' % c for c in cos if c and len(c) >= 4]
        return GQ("(" + " OR ".join(terms) + ") when:" + win) if terms else None

    def match(self, name, syms, title):
        nm = names()
        t = title.lower()
        if TOPIC.get(name) and re.search(TOPIC[name], t):
            return True
        for s in syms[:6]:
            w = [x for x in re.findall(r"[A-Za-z][A-Za-z&'\-]+", nm.get(s) or "") if x.lower() not in ("the", "ltd", "limited", "india", "of", "and", "industries", "company")]
            if (w and len(w[0]) >= 4 and re.search(r"\b%s\b" % re.escape(w[0].lower()), t)) or re.search(r"\b%s\b" % re.escape(s.lower()), t):
                return True
        return False

    def look(self, name, syms, since, win="1h"):
        """-> the first matching headline (epoch, title, link, publisher) published after `since`, or None"""
        found = []
        url = self.query_for(name, syms, win)
        if url:
            for it in self.items(url, "Google News"):
                if it[0] and it[0] >= since and self.match(name, syms, it[1]):
                    found.append(it)
        if self.wires and not found:
            for it in self.wire_items():
                if (not it[0] or it[0] >= since) and self.match(name, syms, it[1]):
                    found.append((it[0] or time.time(), it[1], it[2], it[3]))
        found = [x for x in found if self.key(x[1]) not in self.seen]
        found = [(self.india(name, syms, x[1]), x) for x in found]
        found = [(r, x) for r, x in found if r > 0]              # patch 209c: an Indian story only (Google sends the world's too)
        return min(found, key=lambda rx: (-rx[0], rx[1][0]))[1] if found else None

    def india(self, name, syms, title):
        """2 = names one of the shares · 1 = an Indian story (India, the Centre, the Cabinet, ₹ / crore, NSE ...) · 0 = not about India"""
        t = title.lower()
        nm = names()
        for s in syms[:12]:
            w = [x for x in re.findall(r"[A-Za-z][A-Za-z&'\-]+", nm.get(s) or "") if x.lower() not in ("the", "ltd", "limited", "india", "of", "and", "industries", "company")]
            if (w and len(w[0]) >= 4 and re.search(r"\b%s\b" % re.escape(w[0].lower()), t)) or re.search(r"\b%s\b" % re.escape(s.lower()), t):
                return 2
        return 0 if (FOREIGN_RX.search(t) and not INDIA_RX.search(t)) else 1

    def wire_items(self):
        """the business wires GIR reads (macro.FEEDS, not Google), fetched at most once a minute for every hunt together"""
        t, v = self.wcache
        if time.time() - t < 60:
            return v
        v = []
        try:
            import macro
            for src, u, every in macro.FEEDS:
                if not src.startswith("Google"):
                    v += [(a, b, c, d or src) for a, b, c, d in self.items(u, src)]
        except Exception:
            pass
        self.wcache = (time.time(), v)
        return v

    @staticmethod
    def key(h):
        return " ".join(sorted(set(re.findall(r"[a-z0-9]{4,}", (h or "").lower())))[:12])

    def hm(self, t):
        return dt.datetime.fromtimestamp(t, IST).strftime("%H:%M")

    def reason_text(self, hit):
        t, title, link, pub = hit
        return "📰 %s (%s%s)" % (title[:220], (pub + " · ") if pub else "", "published " + self.hm(t) if t else "time unknown")

    def start(self, name, side, syms, now_t, kind, ring):
        if name in self.hunts or (kind == "one" and sum(1 for x in self.hunts.values() if x["kind"] == "one") >= MAX_ONE):
            return None
        h = {"name": name, "side": side, "syms": syms, "t0": now_t, "next": now_t, "kind": kind, "ring": ring,
             "mv0": {s: self.day_mv.get(s) for s in syms if self.day_mv.get(s) is not None}}
        self.hunts[name] = h
        self.last_h = h
        return self.step(h, now_t, first=True)

    def step(self, h, now_t, first=False):
        if now_t < h["next"]:
            return None
        h["next"] = now_t + 60
        hit = self.look(h["name"], h["syms"], now_t - FRESH)
        if hit:
            self.seen.add(self.key(hit[1]))
            self.hunts.pop(h["name"], None)
            self.remember(h, hit)
            self.done[h["name"]] = h
            return hit
        if now_t - h["t0"] > HUNT_S:
            self.hunts.pop(h["name"], None)
            log("hunt %s: nothing found in 30 min" % h["name"])
        return None

    def remember(self, h, hit):
        r = {"h": hit[1][:220], "src": hit[3], "pub": hit[0], "found": time.time(), "side": h["side"], "group": h["name"]}
        for s in h["syms"]:
            self.state["reasons"][s] = r
        self.state["reasons"][h["name"]] = r
        self.save()

    # -- the policy lane
    def policy(self, now_t, q, mv_day):
        out = []
        for it in self.items(GQ(POLICY_Q), "Google News"):
            t, title, link, pub = it
            if not t or now_t - t > 3600:
                continue
            k = self.key(title)
            if k in self.seen:
                continue
            self.seen.add(k)
            tl = title.lower()
            if FOREIGN_RX.search(tl) and not INDIA_RX.search(tl):
                continue                                         # patch 209c: another country's policy
            gs = [g for g, rx in TOPIC.items() if re.search(rx, tl) and g in groups()]
            if not gs:
                continue
            fo = fo_set()
            shares = []
            for g in gs:
                shares += [s for s in groups()[g] if s not in shares and (not fo or s in fo)]
            crit = bool(CRIT_POLICY.search(title)) or amount_cr(title) >= 5000
            moves = " · ".join("%s %+.1f%%" % (s, mv_day[s]) for s in sorted([s for s in shares if s in mv_day], key=lambda s: -abs(mv_day[s]))[:6])
            head = ("🚨 CRITICAL · POLICY · %s" if crit else "📰 GOVT POLICY · %s") % self.hm(now_t)
            out.append("\n".join([head, "📰 %s (%s%s)" % (title[:240], (pub + " · ") if pub else "", "published " + self.hm(t)),
                                  "touches: %s" % " · ".join(g.upper() for g in gs[:4]),
                                  ("F&O shares now: " + moves) if moves else "F&O shares: " + (" · ".join(shares[:8]) or "-")]))
        return out

    # -- one pass
    def tick(self, now=None):
        now = now or self.now_f()
        now_t = now.timestamp()
        if self.day != now.date():
            self.day, self.seen, self.fired, self.hunts = now.date(), set(), {}, {}
            self.state = {"reasons": {}, "day": str(now.date())}
        q = self.quotes_f()
        msgs = []
        hm = now.strftime("%H:%M")
        live = "09:15" <= hm <= "15:35"
        mv, med = self.moves(now_t, q) if (q and live) else ({}, 0.0)
        day_mv = {}
        try:
            j = json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}
            day_mv = {s: v[1] for s, v in (j.get("q") or {}).items() if v and len(v) > 1 and v[1] is not None}
        except Exception:
            pass
        self.day_mv = day_mv
        # 1 sector jumps
        for g, side, hit in self.jumps(mv, med) if mv else []:
            k = ("jump", g, side)
            if now_t - self.fired.get(k, 0) < 3600:
                continue
            self.fired[k] = now_t
            syms = [s for s, m in hit]
            ar = "▲" if side > 0 else "▼"
            fo = fo_set()
            r = self.start(g, side, syms + [s for s in groups().get(g, []) if s not in syms], now_t, "jump", True)
            fom = [s for s in groups().get(g, []) if (not fo or s in fo) and s in mv]          # every F&O share of the group, moved yet or not
            fom.sort(key=lambda s: -mv[s] * side)
            L = ["🚨 CRITICAL · SECTOR JUMP %s %s · %s" % (ar, g.upper(), hm),
                 "in 15 min: " + " · ".join("%s %+.1f%%" % (s, m) for s, m in hit[:7]) + (" (market %+.1f%%)" % med),
                 self.reason_text(r) if r else "📰 no news found yet - GIR is hunting, the reason follows",
                 ("F&O %s %s: " % (ar, "CE" if side > 0 else "PE")) + (" · ".join("%s %+.1f%% (day %+.1f%%)" % (s, mv[s], day_mv.get(s, 0)) for s in fom[:6]) or "none in F&O")]
            msgs.append("\n".join(L))
            log("jump %s %s %s" % (g, ar, ", ".join("%s %+.1f" % x for x in hit)))
        # 2 big movers (F&O)
        fo = fo_set()
        for s, m in mv.items():
            if fo and s not in fo:
                continue
            side = 1 if m > 0 else -1
            big15 = abs(m) >= ONE and abs(m - med) >= ONE
            d3 = abs(day_mv.get(s) or 0) >= DAY3 and (day_mv.get(s) or 0) * side > 0
            if not (big15 or d3):
                continue
            k = ("one", s, side)
            if k in self.fired or any(s in h["syms"] for h in self.hunts.values()):
                continue
            self.fired[k] = now_t
            ring = abs(day_mv.get(s) or m) >= DAY3
            r = self.start(s, side, [s], now_t, "one", ring)
            if r:
                msgs.append(self.reason_msg(s, side, [s], r, ring, day_mv, now_t))
        # 3 the running hunts
        for name, h in list(self.hunts.items()):
            r = self.step(h, now_t)
            if r:
                msgs.append(self.reason_msg(name, h["side"], h["syms"], r, h["ring"], day_mv, now_t))
        # 4 the policy lane
        every = 60 if live else 300
        if now_t - self.last_policy >= every and "07:00" <= hm <= "23:00":
            self.last_policy = now_t
            try:
                msgs += self.policy(now_t, q, day_mv)
            except Exception as ex:
                log("policy: %s" % str(ex)[:80])
        for m in msgs:
            try:
                self.send(m)
            except Exception as ex:
                log("send: %s" % str(ex)[:80])
        return msgs

    def reason_msg(self, name, side, syms, hit, ring, day_mv, now_t):
        ar = "▲" if side > 0 else "▼"
        head = ("🚨 CRITICAL · THE REASON %s %s · %s" if ring else "📰 THE REASON %s %s · %s") % (ar, name.upper(), self.hm(now_t))
        mv = " · ".join("%s %+.1f%%" % (s, day_mv[s]) for s in syms[:6] if s in day_mv)
        lag = (now_t - hit[0]) / 60 if hit[0] else None
        h = self.done.get(name) or {}
        first = ""
        m0 = [v * side for v in (h.get("mv0") or {}).values() if v is not None]
        if h and hit[0] and hit[0] >= h["t0"] - 120 and m0 and max(m0) >= 1.5:
            # patch 209 (Rama: "before the news was officially published someone leaked it - that is why it went to 9% and settled at 5.5%")
            first = ("⚠ THE MONEY CAME FIRST: the shares were already %s%.1f%% (best) before this was published - someone knew. "
                     "News after a run is often sold into by the early money: book part at the spike, trail the stop, do not chase") % ("+" if side > 0 else "-", max(m0))
        return "\n".join(x for x in [head, self.reason_text(hit), ("today: " + mv) if mv else "", first,
                                      "found %s%s" % (self.hm(now_t), (" · %d min after it was published" % lag) if lag is not None and lag >= 0 else "")] if x)


def run():
    h = Hunter()
    log("news hunt: sector jumps every 15 s, the policy lane every 60 s (market hours)")
    while True:
        t0 = time.time()
        try:
            now = dt.datetime.now(IST)
            try:
                import holidays
                off = holidays.holiday(now.date())
            except Exception:
                off = now.weekday() >= 5
            if not off or "07:00" <= now.strftime("%H:%M") <= "23:00":
                h.tick(now)
        except Exception as ex:
            log("tick: %s" % str(ex)[:120])
        time.sleep(max(1.0, 15 - (time.time() - t0)))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "run":
        run()
    elif a and a[0] == "policy":
        h = Hunter(send=lambda m: None)
        h.last_policy = 0
        for m in h.policy(time.time(), {}, {}) or ["(no policy headline in the last hour)"]:
            print(m + "\n")
    elif a and a[0] == "hunt" and len(a) > 1:
        g = a[1]
        syms = groups().get(g) or [g.upper()]
        hrs = float(a[2]) if len(a) > 2 else 1.5
        h = Hunter(send=lambda m: None)
        win = "1h" if hrs <= 1.5 else "1d"
        print("query:", h.query_for(g, syms, win))
        seen = []
        for _ in range(5):
            r = h.look(g, syms, time.time() - hrs * 3600, win)
            if not r:
                break
            seen.append(r); h.seen.add(h.key(r[1]))
        print("\n".join(h.reason_text(r) for r in seen) if seen else "nothing in the last %g hours" % hrs)
    else:
        print(__doc__)
PY_HUNT
cat > $D/p209test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p209test.py - patch 209's own test: THE NEWS HUNT replayed on 11 Nov 14:00-14:30 (made-up prices like the day's, a made-up news feed)
- no network, nothing sent.  python3 p209test.py DIR   (DIR = the folder with newshunt.py and macro.py)"""
import os, sys, json, shutil, tempfile, html, datetime as dt
from email.utils import format_datetime
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp()
os.makedirs(os.path.join(T, "data"))
for f in ("newshunt.py", "macro.py"):
    shutil.copy(os.path.join(SRC, f), T)
open(os.path.join(T, "sectors.py"), "w").write('''
def load():
    return {"chemicals": "PIDILITIND SRF PIIND ATUL DEEPAKNTR AARTIIND NAVINFLUOR TATACHEM UPL COROMANDEL CHAMBLFERT".split(),
            "banks": "HDFCBANK ICICIBANK SBIN AXISBANK KOTAKBANK".split(), "it": "TCS INFY WIPRO HCLTECH TECHM".split()}
def themes():
    return {"rural-monsoon": "M&M HEROMOTOCO DABUR MARICO UPL COROMANDEL CHAMBLFERT ESCORTS".split()}
''')
open(os.path.join(T, "newsroom.py"), "w").write('''
def fo_names():
    return [("COROMANDEL", "Coromandel International Ltd", 1), ("CHAMBLFERT", "Chambal Fertilisers and Chemicals Ltd", 1), ("UPL", "UPL Ltd", 1),
            ("PIIND", "PI Industries Ltd", 1), ("SBIN", "State Bank of India", 1), ("TCS", "Tata Consultancy Services", 1), ("INFY", "Infosys", 1),
            ("HDFCBANK", "HDFC Bank", 1), ("ICICIBANK", "ICICI Bank", 1), ("AXISBANK", "Axis Bank", 1), ("KOTAKBANK", "Kotak Mahindra Bank", 1),
            ("WIPRO", "Wipro", 1), ("HCLTECH", "HCL Technologies", 1), ("TECHM", "Tech Mahindra", 1), ("SRF", "SRF Ltd", 1), ("DIXON", "Dixon Technologies", 1)]
''')
sys.path.insert(0, T)
os.chdir(T)
import newshunt as N
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
D0 = dt.datetime(2026, 11, 11, 14, 0, tzinfo=IST)
BASEPX = {"COROMANDEL": 2300, "CHAMBLFERT": 520, "DEEPAKFERT": 1400, "RCF": 160, "GNFC": 560, "FACT": 900, "UPL": 650, "PIIND": 3600,
          "SBIN": 1000, "HDFCBANK": 1700, "ICICIBANK": 1300, "AXISBANK": 1150, "KOTAKBANK": 2000, "TCS": 3100, "INFY": 1500, "WIPRO": 250,
          "HCLTECH": 1600, "TECHM": 1500, "SRF": 2900, "DIXON": 15000, "PIDILITIND": 3000}
JUMPS = {"COROMANDEL": 3.4, "CHAMBLFERT": 2.6, "DEEPAKFERT": 4.2, "RCF": 4.8, "GNFC": 2.2, "FACT": 5.1}      # the fertiliser shares, 14:08-14:13
NEWS = {"t": None, "items": []}


def quotes_at(t):
    m = (t - D0).total_seconds() / 60
    q = {}
    for s, p in BASEPX.items():
        k = 0.0
        if s in JUMPS:
            k = JUMPS[s] * min(1.0, max(0.0, (m - 8) / 5))       # the jump between 14:08 and 14:13
        if s == "DIXON":
            k = 3.2 * min(1.0, max(0.0, (m - 20) / 4))           # one share alone, 14:20-14:24
        q[s] = p * (1 + k / 100)
    return q


def rss(items):
    x = "".join("<item><title>%s - %s</title><link>http://x/%d</link><pubDate>%s</pubDate></item>" % (html.escape(h), src, i, format_datetime(t)) for i, (t, h, src) in enumerate(items))
    return "<rss><channel>%s</channel></rss>" % x


def fetch(url):
    return rss([x for x in NEWS["items"] if x[0] <= NEWS["now"]]) if "news.google" in url else "<rss><channel></channel></rss>"


OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond))
    print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))


def replay(news, until_min=30):
    NEWS["items"] = news
    sent = []
    clock = {"t": D0}
    h = N.Hunter(fetch=fetch, send=lambda m: sent.append((clock["t"].strftime("%H:%M:%S"), m)), now_f=lambda: clock["t"],
                 quotes_f=lambda: quotes_at(clock["t"]), wires=False)
    json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
    for i in range(0, until_min * 4 + 1):
        clock["t"] = D0 + dt.timedelta(seconds=15 * i)
        NEWS["now"] = clock["t"]
        q = quotes_at(clock["t"])
        json.dump({"t": clock["t"].timestamp(), "q": {s: [p, (p / BASEPX[s] - 1) * 100] for s, p in q.items()}}, open(os.path.join(T, "quotes_live.json"), "w"))
        h.tick(clock["t"])
    return sent, h


CAB = (D0 + dt.timedelta(minutes=11), "Cabinet approves Rs 62,370 crore subsidy on P&K fertilisers for rabi season", "Business Today")
NUT = (D0 - dt.timedelta(minutes=40), "Nutrien opens $70M fertiliser facility in Western Australia", "Australian Manufacturing")
print("1 · the news out at 14:11, the shares jump 14:08-14:13 (a foreign fertiliser story at 13:20 in the feed too)")
sent, h = replay([NUT, CAB])
chk("the foreign story (Nutrien, Australia) is never the reason, nor a policy line", not any("Nutrien" in m for t, m in sent), [m for t, m in sent])
jump = [m for t, m in sent if "SECTOR JUMP" in m]
chk("one 🚨 CRITICAL · SECTOR JUMP ▲ FERTILISER", len(jump) == 1 and "SECTOR JUMP ▲ FERTILISER" in jump[0], [m[:90] for t, m in sent])
t_j = next((t for t, m in sent if "SECTOR JUMP" in m), "")
chk("… by 14:13 (with the move, not 2 hours later)", t_j and t_j <= "14:13:00", t_j)
rea0 = [m for t, m in sent if "THE REASON" in m]
chk("… the reason (the Cabinet's ₹62,370 cr subsidy) in it, or 🚨 THE REASON within a minute", (jump and "Cabinet approves Rs 62,370 crore" in jump[0]) or (rea0 and "Cabinet approves Rs 62,370 crore" in rea0[0] and "Business Today" in rea0[0] and min(t for t, m in sent if "THE REASON" in m) <= "14:12:15"), sent)
chk("… its F&O shares named for CE (COROMANDEL, CHAMBLFERT)", jump and "F&O ▲ CE: " in jump[0] and "COROMANDEL" in jump[0].split("F&O")[1] and "CHAMBLFERT" in jump[0].split("F&O")[1], jump[:1])
chk("… the chemicals / rural baskets (the same movers) are not said again", len([m for t, m in sent if "SECTOR JUMP" in m]) == 1, [m.split("\n")[0] for t, m in sent])
chk("the policy lane does not repeat the same Cabinet headline", sum(1 for t, m in sent if "62,370" in m) == 1, [m.split("\n")[0] for t, m in sent])
chk("DIXON alone +3.2% at 14:24: hunted (no news -> nothing rings)", not any("DIXON" in m for t, m in sent) and ("one", "DIXON", 1) in h.fired, [m.split("\n")[0] for t, m in sent])
chk("the reason is kept for the 🔎 why line (data/newshunt.json)", "COROMANDEL" in json.load(open(os.path.join(T, "data", "newshunt.json")))["reasons"])
print("2 · the shares jump first, the news is found at 14:19")
LATE = (D0 + dt.timedelta(minutes=17), "Fertiliser stocks surge as Union Cabinet clears Rs 62,370 crore NBS subsidy", "Economic Times")
sent, h = replay([LATE])
jump = [(t, m) for t, m in sent if "SECTOR JUMP" in m]
chk("the jump rings at once with 'no news found yet - the reason follows'", jump and "the reason follows" in jump[0][1], jump)
rea = [(t, m) for t, m in sent if "THE REASON" in m and "FERTILISER" in m]
chk("then 🚨 CRITICAL · THE REASON ▲ FERTILISER when the story appears (within a minute)", rea and "CRITICAL · THE REASON ▲ FERTILISER" in rea[0][1] and rea[0][0] <= "14:18:30", rea)
chk("… with the published time and how late it was found", rea and "published 14:17" in rea[0][1] and "found" in rea[0][1], rea)
chk("… said once", len(rea) == 1, rea)
chk("… with ⚠ THE MONEY CAME FIRST (the shares ran before the news was published - book part at the spike)", rea and "THE MONEY CAME FIRST" in rea[0][1] and "book part" in rea[0][1], rea)
print("2b · the news first, the shares after: no 'money came first' warning")
JUMPS.clear(); JUMPS.update({"COROMANDEL": 3.4, "CHAMBLFERT": 2.6, "DEEPAKFERT": 4.2, "RCF": 4.8, "GNFC": 2.2, "FACT": 5.1})
EARLY = (D0 - dt.timedelta(minutes=20), "Govt may hike fertiliser subsidy for rabi, say sources", "Mint")
sent, h = replay([EARLY])
allm = "\n".join(m for t, m in sent)
chk("a story out 20 min BEFORE the jump: the reason comes in the jump itself, no 'money came first'", "SECTOR JUMP" in allm and "hike fertiliser subsidy" in allm and "MONEY CAME FIRST" not in allm, [m for t, m in sent])
print("3 · a market-wide rally is not a sector jump")
JUMPS.clear(); JUMPS.update({s: 2.0 for s in BASEPX})
sent, h = replay([])
chk("every share +2% (the market) -> no SECTOR JUMP", not any("SECTOR JUMP" in m for t, m in sent), [m.split("\n")[0] for t, m in sent])
print("4 · the money words")
chk("₹62,370 crore -> 62,370 cr", N.amount_cr("Rs 62,370 crore subsidy") == 62370)
chk("Rs 1.2 lakh crore -> 120,000 cr", N.amount_cr("Rs 1.2 lakh crore package") == 120000)
shutil.rmtree(T, ignore_errors=True)
print("NEWS HUNT test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cd $D && python3 -m py_compile newshunt.py || back
timeout 120 python3 p209test.py $D > /tmp/p209c.out 2>&1 || { grep -E "❌|passed|Error" /tmp/p209c.out; back; }
grep -E "Nutrien|passed" /tmp/p209c.out
echo "=== the search on this server: the top fertiliser stories of the last 12 hours (Indian only)"
timeout 120 python3 newshunt.py hunt fertiliser 12 2>&1 | grep -v "^query" | cut -c1-200 | sed 's/^/   /'
systemctl restart gir-newshunt && sleep 3 && echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
echo "✅ patch 209c done."
