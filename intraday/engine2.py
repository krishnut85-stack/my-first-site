#!/usr/bin/env python3
"""engine2.py - GIR INTRADAY v2: live news + chart desk for NSE shares (paper only).

Six jobs, one decision, every 5-minute candle from 09:20 to 14:45 IST:
  SCOUT    ranks all liquid shares live (gap, volume, momentum); posts the 09:30 brief
  NEWS     reads every fresh headline (NEWSHAWK ledger: RSS, X, regulators) and maps it to shares;
           market-wide news (tax, SEBI, RBI, FinMin...) is posted at once as ⚡ MARKET NEWS
  CHARTS   VWAP, EMA 9/21, RSI, 30-min breakout, volume surge on live candles
  SCORE    0-100 per share and side; below min_score nothing, half size, full size above full_score
  RISK     stop and target fixed before entry, risk_pct of capital per trade, daily loss cap
  MANAGER  one card per trade, exits, 15:15 summary, Friday scorecard by score band

Reuses the price feed, journal and exit logic of engine.py. Places no orders.
"""
import os, sys, re, json, time, sqlite3, datetime as dt
import numpy as np
import core, getdata, engine, fast, flow, dash, judge
from engine import log, db, once, open_trades, close_trade, check_price, sleep_until, rs

V2 = {
    "capital_rs": 500000,       # paper capital the 1% risk is measured on
    "risk_pct": 1.0,            # loss at the stop, as % of capital, for a FULL position
    "position_cap_rs": 150000,  # never more than this in one share
    "min_score": 70,            # below: no trade
    "full_score": 85,           # at or above: full size, else half
    "max_open": 6,
    "max_trades_day": 6,
    "daily_loss_pct": 3.0,      # stop new entries after this % of capital is lost in a day
    "stop_atr": 1.5,
    "target_x": 2.0,            # used when exit = "TP"
    "exit": "TRAIL",            # "TRAIL": book 1/3 at +1x stop distance, stop to entry, rest trails; "TP": fixed target
    "book_x": 0.0,              # 0 = no partial booking; trail starts once price is +1 stop-distance
    "trail_x": 1.0,             # trailing distance below the high, in stop-distances
    "min_history_days": 3,      # newly listed shares need only this many days of candles
    "sip": True,                # Stocks in Play: rank by first-5-min volume vs own normal, buy the opening-range-high break
    "sip_top": 20,              # how many shares are "in play" each morning
    "sip_min_rvol": 2.0,        # first 5 minutes must trade at least this many times the share's normal first 5 minutes
    "sip_min_value_lakh": 30,   # first 5 minutes must trade at least this many Rs lakh (so a paper fill is realistic)
    "sip_until": 1030,          # opening-range breakouts only until this time
    "sip_chase_pct": 1.0,       # skip if price is already this % above the trigger
    "sip_trail_r": 2.0,         # at +2R stop goes to entry, then trails 2R below the high
    "max_profit_pct": 15.0,     # sell the whole position if it reaches this profit
    "blast": True,              # buy the top BLAST RADAR shares
    "blast_min": 75,            # blast score needed to buy
    "blast_big": 85,            # at or above: bigger position
    "blast_risk_x": 1.5,        # risk multiplier for big blast trades
    "blast_cap_rs": 250000,     # position cap for big blast trades
    "max_before_10": 4,         # new trades allowed before 10:00
    "max_per_15": 3,            # new trades allowed in any 15 minutes
    "radar_every_min": 15,      # BLAST RADAR Telegram post interval
    "dash_port": 8090,
    "fast": True,               # check every few seconds from live ticks (day-high break, pre-breakout, breaking news)
    "pre_band_pct": 0.3,        # pre-breakout: price within this % below the day high
    "pre_vol_x": 2.5,           # pre-breakout: last minute's volume at least this many times normal
    "pre_min_value_lakh": 10,   # pre-breakout: last minute traded at least this many Rs lakh
    "trade_from": 930,          # first entry 09:30
    "trade_to": 1445,           # last entry 14:45
    "news_fresh_min": 120,      # headline younger than this = full news points
    "news_old_min": 1440,       # older than this = no news points
}
MACRO_RX = re.compile(r"\b(ltcg|stcg|capital gains?|securities transaction|stt\b|sitharaman|finance minist|"
                      r"budget|sebi|rbi\b|repo rate|monetary policy|gst council|nifty|sensex|fii|"
                      r"tariff|trump|fed\b|federal reserve|crude|war\b|ceasefire|election)", re.I)
MACRO_SIDE_RX = {
    1: re.compile(r"(cut|relief|exempt|withdraw|rollback|boost|rally|surge|eases?|lower|scrap|rebound|positive|gain)", re.I),
    -1: re.compile(r"(hike|raise|increase|impose|curb|ban|tighten|crash|fall|slump|plunge|negative|loss|war|attack)", re.I),
}
POS_RX = re.compile(r"\b(?:orders?|wins?|bags?|secures?|contracts?|approv\w*|launch\w*|upgrad\w*|buyback|record (?:high|profit|revenue)|"
                    r"profit (?:rises?|jumps?|up|soars?|doubles?|grows?)|beats?|strong|expan\w*|acqui\w*|partnership|clearance|"
                    r"usfda (?:nod|approval|clears)|growth|dividend|bonus|split|gains?|surges?|jumps?|rall(?:y|ies)|soars?|rises?|"
                    r"climbs?|higher|outperform\w*|target raised|raises stake|buys stake|picks up stake|block deal buy|up \d+%|"
                    r"rating upgrade|defies|defied|hits? (?:record|52-week|all-time) high)(?!\w)", re.I)
NEG_RX = re.compile(r"\b(?:penalt\w*|fines?|fined|probe\w*|raids?|fraud\w*|defaults?|downgrad\w*|miss\w*|loss|losses|weak\w*|cuts?|"
                    r"bans?|banned|barred|recalls?|warning letter|resign\w*|quits?|strike|shutdown|plunges?|slumps?|falls?|drops?|"
                    r"tumbles?|slides?|sinks?|slips?|tanks?|crash\w*|lower|debt|cbi raid|ed raid|ed attach\w*|enforcement directorate|down \d+%|"
                    r"sebi order|rating cut|underperform\w*|sell rating|pares?|trims?|sells? stake|offloads?|dumps?|exits? stake|"
                    r"pledg\w*|stake sale|block deal sell|lawsuit|sued|selloff|sell-off|hits? (?:52-week|all-time) low|"
                    r"derivatives exit|f&o exit|exclusion|delist\w*)(?!\w)", re.I)
ROUNDUP_RX = re.compile(r"(ahead of market|things that|stocks to watch|stocks in (news|focus)|top (gainers?|losers?)|"
                        r"market wrap|live updates|live blog|what to expect|opening bell|closing bell|trade setup|"
                        r"buy or sell|stock picks|hot stocks|movers|f&o ban|pre-?market|among \d+|\d+ (stocks|companies|others)|"
                        r"stocks showing|stocks that|trade spotlight|how should you trade|stock radar|chart check|"
                        r"technical (pick|view)|pattern|\brsi\b|macd|moving average|breakout stocks|52-week high stocks|screener|"
                        r"to weigh on|sector(al)? (outlook|view)|brokerage(s)? (view|picks?)|top picks|multibagger|"
                        r"\bsensex\b|\bnifty\b|indian (shares|markets?|stocks)|asian (stocks|markets)|global markets?|wall street|"
                        r"markets? (recover|open|fall|rise|gain|slip|end|close|rebound)|watch out|buzzing|results today|"
                        r"to report (its )?(q\d|earnings|results)|earnings (today|preview|calendar)|smart talk|"
                        r"\bsip\b|mutual fund|portfolio|largecaps?|midcaps?|smallcaps?|ipo (opens|gmp|subscription)|gmp\b)", re.I)
OPINION_RX = re.compile(r"(should you|why is|why the|what'?s (spooking|driving|behind)|can it|will (this|it)|explained|"
                        r"preview|outlook|bullish on|bearish on|sees \d+%|upside|target price|analysts?|brokerages?|"
                        r"jefferies|morgan stanley|motilal|nomura|citi|jp ?morgan|goldman|ubs|macquarie|here'?s w|"
                        r"details inside|decoded|in focus|\?$)", re.I)
FACT_RX = re.compile(r"\b((shares?|stock) (jumps?|surges?|gains?|rises?|soars?|rall(y|ies)|falls?|drops?|slips?|tumbles?|"
                     r"plunges?|slumps?|crash\w*|up|down|tanks?|sinks?)|(up|down) \d|profit (jumps?|rises?|falls?|drops?|up|down|"
                     r"soars?|doubles?)|lawsuit|sued|orders? (worth|from)|bags|wins|acquires?|acquisition|stake in|penalt\w*|"
                     r"fined|banned|contract|launches|approv\w*|usfda|resigns?|block deal|bulk deal|buyback|dividend|bonus|"
                     r"derivatives exit|delist\w*|default\w*|raid\w*|fraud\w*)\b", re.I)
PREVIEW_RX = re.compile(r"\b(preview|may |might |likely|expected|expects?|estimates?|could |to report|eyed|ahead of)\b", re.I)
GENERIC_WORDS = set("""bank india tata adani reliance bajaj aditya birla jindal shriram hdfc icici kotak sbi power steel motors
finance capital industries tech global national indian united bharat hindustan mahindra limited ltd corporation company
international enterprises energy infra infrastructure services solutions systems housing life general insurance financial
holdings group trust state central city new first great oil gas chemicals pharma pharmaceuticals textiles sugar paper
cement realty estates projects engineering electricals electronics digital network networks media heritage prince force
premier century general standard united sun star apex pioneer orient oriental eastern western northern southern golden
royal imperial modern classic supreme paramount universal zenith summit liberty victory phoenix crown diamond silver
gold platinum jewel jewels pearl ruby emerald sapphire crystal mega super ultra prime select quality best good luck
goodluck kings king queen alpha beta gamma delta omega sigma asia euro america pacific atlantic ocean river mountain
valley garden green blue red black white orange sunrise sunset dawn morning evening night day summer winter spring""".split())


def body_text(url, timeout=6):
    """First ~1500 characters of article paragraphs, or '' if the page cannot be read."""
    if not url or not url.startswith("http"):
        return ""
    try:
        import requests
        r = requests.get(url, timeout=timeout, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"})
        if not r.ok:
            return ""
        html = r.text
        paras = re.findall(r"<p[^>]*>(.*?)</p>", html, re.S | re.I)
        txt = " ".join(re.sub(r"<[^>]+>", " ", p) for p in paras)
        txt = re.sub(r"&nbsp;|&amp;|&quot;|&#\d+;|\s+", " ", txt).strip()
        return txt[:1500]
    except Exception:
        return ""


def cfg2():
    c = core.cfg()
    v = dict(V2)
    v.update(c.get("v2", {}))
    c["v2"] = v
    c["stop_min_pct"] = max(c.get("stop_min_pct", 0.3), 0.5)

    return c


# ---------------------------------------------------------------- NEWS
class News(object):
    """Reads NEWSHAWK's live_news table and decides, per share, whether there is real company news.
    A headline counts for a share ONLY if the headline names that company (symbol in capitals,
    company name from Kite, or a curated brand alias). NEWSHAWK's own share tag is not trusted:
    it was seen tagging CDSL on a Philippine story and FEDERALBNK on "The Federal" newspaper."""

    def __init__(self, c, uni):
        self.path = os.path.join(c["gir_home"], "newshawk", "ledger.db")
        self.cols = None
        self.items = []          # (ts, title, link)
        self.titles = set()
        self.last_rowid = 0
        self.seen_macro = []
        self.bodies = {}
        self.cls = {}            # title -> (pts_side, side, is_fact)
        self.by_sym = {}         # sym -> [(ts, title, link)] headlines that NAME that company (<=2 names)
        self.named = {}          # title -> [syms]
        self.fetch_budget = 0
        self.alias = {}          # sym -> set of lowercase name keys (matched with word boundaries)
        self.symword = {}        # sym -> regex matching the symbol in CAPITALS in the original text
        for e in uni:
            sym = e["sym"]
            keys = set()
            nm = (e.get("name") or "").lower()
            nm = re.sub(r"[^a-z0-9& ]", " ", nm)
            words = [w for w in nm.split() if w not in ("limited", "ltd", "the", "of", "and", "&", "co")]
            if words:
                keys.add(" ".join(words))
                if len(words) >= 2 and words[0] not in GENERIC_WORDS:
                    keys.add(" ".join(words[:2]))
                if len(words) == 1 or (len(words[0]) >= 7 and words[0] not in GENERIC_WORDS):
                    keys.add(words[0])
            self.alias[sym] = keys
            if re.match(r"^[A-Z&\-]{3,}$", sym):
                self.symword[sym] = re.compile(r"(?<![A-Za-z])" + re.escape(sym) + r"(?![A-Za-z])")
        brand = os.path.join(c["gir_home"], "newshawk", "brand_aliases.json")
        if os.path.exists(brand):
            try:
                for sym, als in json.load(open(brand)).items():
                    if sym in self.alias:
                        for a in (als if isinstance(als, list) else [als]):
                            a = str(a).lower().strip()
                            if len(a) >= 4 and a not in GENERIC_WORDS:
                                self.alias[sym].add(a)
            except Exception as ex:
                log("brand_aliases unreadable:", ex)
        def rx(k):
            w = k.split()
            if len(w) == 1:
                return re.compile(r"\b" + re.escape(w[0]) + (r"\w*" if len(w[0]) >= 6 else r"\b"))
            body = r"(?:\s+(?:of|the|and|&)\s+|\s+)".join(re.escape(x) for x in w[:-1])
            last = w[-1][:4] if len(w[-1]) >= 6 else w[-1]
            return re.compile(r"\b" + body + r"(?:\s+(?:of|the|and|&)\s+|\s+)" + re.escape(last) + r"\w*")
        self.name_rx = {sym: [rx(k) for k in keys] for sym, keys in self.alias.items()}

    def _detect(self, con):
        cols = [r[1] for r in con.execute("pragma table_info(live_news)")]
        low = [x.lower() for x in cols]
        pick = lambda names: next((cols[i] for i, x in enumerate(low) if x in names), None)
        self.cols = {
            "text": pick(("title", "headline", "text", "news", "summary")),
            "link": pick(("link", "url", "href")),
            "ts": pick(("ts", "time", "published", "pub_ts", "created", "created_at", "dt", "date", "timestamp", "seen", "seen_at")),
        }
        log("live_news columns:", self.cols)

    def refresh(self):
        if not os.path.exists(self.path):
            return []
        try:
            con = sqlite3.connect("file:%s?mode=ro" % self.path, uri=True, timeout=3)
            if self.cols is None:
                self._detect(con)
            t, lk, ts = self.cols["text"], self.cols["link"], self.cols["ts"]
            if not t:
                return []
            rows = con.execute("select rowid, %s, %s, %s from live_news where rowid > ? order by rowid" % (
                t, lk or "''", ts or "0"), (self.last_rowid,)).fetchall()
            con.close()
        except Exception as ex:
            log("news read failed:", ex)
            return []
        now = time.time()
        fresh = []
        for rid, text, link, when in rows:
            self.last_rowid = max(self.last_rowid, rid)
            tsec = self._epoch(when, now)
            if not text or now - tsec > 36 * 3600:
                continue
            text = self.clean(text)
            if text in self.titles:
                continue
            self.titles.add(text)
            it = (tsec, text, str(link or ""))
            self.items.append(it)
            fresh.append(it)
            nm = self.names(text)
            self.named[text] = nm
            if len(nm) <= 2:
                for sym in nm:
                    self.by_sym.setdefault(sym, []).append(it)
        if len(self.items) > 3000:
            self.items = self.items[-3000:]
            self.titles = set(x[1] for x in self.items)
            cut = self.items[0][0]
            self.by_sym = {k: [x for x in v if x[0] >= cut] for k, v in self.by_sym.items()}
        return fresh

    @staticmethod
    def clean(text):
        import html as _h
        t = _h.unescape(str(text))
        t = re.sub(r"https?://\S+", " ", t)
        t = re.sub(r"\s+", " ", t).strip()
        return t

    @staticmethod
    def _epoch(when, now):
        if when is None or when == 0 or when == "":
            return now
        try:
            v = float(when)
            return v / 1000.0 if v > 1e11 else v
        except (TypeError, ValueError):
            pass
        s = str(when)[:19].replace("T", " ")
        for f in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
            try:
                return core.ist_epoch(dt.datetime.strptime(s, f))
            except ValueError:
                continue
        return now

    def names(self, title):
        """Shares named in the title (symbol in capitals or company name)."""
        if title in self.named:
            return self.named[title]
        low = title.lower()
        out = []
        for sym, rxs in self.name_rx.items():
            if any(rx.search(low) for rx in rxs) or (sym in self.symword and self.symword[sym].search(title)):
                out.append(sym)
        return out

    def classify(self, title, link, fetch=True):
        """(points, side, is_fact) for a headline. Uses the article body when it can be read."""
        if title in self.cls:
            return self.cls[title]
        if len(title.split()) < 5 or (ROUNDUP_RX.search(title) and not FACT_RX.search(title)):
            res = (0, 0, False)
        else:
            body = ""
            if fetch and link and link not in self.bodies and self.fetch_budget > 0:
                self.fetch_budget -= 1
                self.bodies[link] = body_text(link)
            body = self.bodies.get(link, "")
            fact = (bool(FACT_RX.search(title)) or bool(FACT_RX.search(body[:600]))) and not PREVIEW_RX.search(title)
            opinion = (bool(OPINION_RX.search(title)) or bool(PREVIEW_RX.search(title))) and not fact
            txt = (title + " ") * 3 + body
            p = sum(1 for _ in POS_RX.finditer(txt))
            n = sum(1 for _ in NEG_RX.finditer(txt))
            side = 1 if p > n else (-1 if n > p else 0)
            if opinion and not fact:
                res = (0, side, False)
            elif side == 0:
                res = (10 if fact else 0, 0, fact)
            else:
                res = (30 if fact else 15, side, fact)
        self.cls[title] = res
        return res

    def for_share(self, sym, now):
        """(points 0-30, side +1/-1/0, headline, age_min) for the freshest real news naming the share."""
        for tsec, title, link in reversed(self.by_sym.get(sym, [])):
            if tsec > now + 60 or now - tsec > V2["news_old_min"] * 60:
                continue
            pts, side, fact = self.classify(title, link)
            if pts == 0:
                continue
            age = max(0.0, (now - tsec) / 60.0)
            if age > V2["news_fresh_min"]:
                pts = min(pts, 15)
            return pts, side, title, age
        return 0, 0, None, None

    def macro(self, fresh):
        """Market-wide stories among the fresh headlines, deduplicated by wording; none that name a share."""
        out = []
        for tsec, text, link in fresh:
            if not MACRO_RX.search(text) or self.names(text):
                continue
            words = set(re.findall(r"[a-z]{4,}", text.lower()))
            if any(len(words & w) >= 0.5 * max(1, min(len(words), len(w))) for w in self.seen_macro):
                continue
            self.seen_macro.append(words)
            side = 1 if MACRO_SIDE_RX[1].search(text) else (-1 if MACRO_SIDE_RX[-1].search(text) else 0)
            out.append((text, side))
        return out


# ---------------------------------------------------------------- SCORE
def features(bars, nifty, today, j, c):
    """Chart features for every share at the close of 5-min bar j. Returns {sym: dict}."""
    syms = sorted(bars)
    nif = core.prep_nifty(nifty, 5, today, j) if nifty is not None else None
    M = core.stack((i, core.prep(bars[s], nif, 5, today, j)) for i, s in enumerate(syms))
    if M is None:
        return {}
    rows = np.nonzero((M["day"] == today) & M["fresh"])[0]
    out = {}
    day_chg_all = []
    with np.errstate(invalid="ignore", divide="ignore"):
        for r in rows:
            C, O, H, L, V = (M[k][r] for k in ("C", "O", "H", "L", "V"))
            px = float(C[j])
            if not np.isfinite(px) or px <= 0:
                continue
            vw, e9, e21 = float(M["vwap"][r, j]), float(M["e9"][r, j]), float(M["e21"][r, j])
            atr, vavg = float(M["atr"][r, j]), float(M["vavg"][r, j])
            k = min(6, j + 1)
            orh, orl = float(np.nanmax(H[:k])), float(np.nanmin(L[:k]))
            vol_ratio = float(V[j] / vavg) if vavg and vavg > 0 else 1.0
            prev_hi = float(np.nanmax(H[:j])) if j > 0 else np.nan
            prev_lo = float(np.nanmin(L[:j])) if j > 0 else np.nan
            v3 = float(np.nansum(V[max(0, j - 2):j + 1]) / (3 * vavg)) if vavg and vavg > 0 and j >= 2 else 0.0
            c3 = (px / float(C[j - 3]) - 1) * 100 if j >= 3 and C[j - 3] > 0 else 0.0
            f = {
                "px": px, "gap": float(M["gap"][r]), "vol3": v3, "chg3": c3, "bar": j, "day_chg": (px / float(O[0]) - 1) * 100 if O[0] > 0 else 0.0,
                "above_vwap": px > vw, "below_vwap": px < vw,
                "ema_up": e9 > e21, "ema_dn": e9 < e21,
                "rsi": float(M["rsi"][r, j]),
                "brk_up": j >= 6 and px > orh and float(C[j - 1]) <= orh,
                "brk_dn": j >= 6 and px < orl and float(C[j - 1]) >= orl,
                "new_hi": j > 0 and px > prev_hi, "new_lo": j > 0 and px < prev_lo,
                "vol": vol_ratio, "mkt": float(M["mkt"][r, j]) if np.isfinite(M["mkt"][r, j]) else 0.0,
                "atr": atr if np.isfinite(atr) and atr > 0 else px * 0.004,
                "trend": float(M["trend"][r]),
            }
            f["dayhi_brk"] = j > 0 and px > prev_hi and float(C[j - 1]) <= prev_hi
            f["dayhi"] = float(np.nanmax(H[:j + 1]))
            f["vwap"] = vw
            f["open"] = float(O[0])
            out[syms[int(M["sym"][r])]] = f
            day_chg_all.append(f["day_chg"])
    if day_chg_all:
        arr = np.sort(np.array(day_chg_all))
        for f in out.values():
            f["rs_pct"] = float(np.searchsorted(arr, f["day_chg"]) / len(arr) * 100)   # 100 = strongest share today
    return out


def score(f, news_pts, news_side, side, news_age=None):
    """0-100 and a plain-words breakdown for one side (+1 long / -1 short)."""
    pts, why = 0, []
    if news_pts and news_side == side:
        pts += news_pts
        if news_age is not None and news_age <= 20:
            pts += 15; why.append("BREAKING %s news %d min ago" % ("positive" if side == 1 else "negative", int(news_age)))
        elif f.get("bar", 99) <= 2 and news_age is not None and news_age <= 18 * 60:
            pts += 12; why.append("overnight %s news, opening holds" % ("positive" if side == 1 else "negative"))
        else:
            why.append("fresh %s news" % ("positive" if side == 1 else "negative"))
    elif news_pts and news_side == -side:
        return 0, ["fresh news points the other way - no trade against it"]
    up = side == 1
    rs = f.get("rs_pct", 50)
    if up and rs >= 98 and f["day_chg"] >= 2.0:
        pts += 25; why.append("market leader: top 2%% of all shares today (%+.1f%%)" % f["day_chg"])
    elif up and rs >= 95 and f["day_chg"] >= 1.5:
        pts += 15; why.append("top 5%% strength today (%+.1f%%)" % f["day_chg"])
    if (f["above_vwap"] if up else f["below_vwap"]):
        pts += 5; why.append("%s VWAP" % ("above" if up else "below"))
    if (f["ema_up"] if up else f["ema_dn"]):
        pts += 5; why.append("EMA 9/21 %s" % ("bullish" if up else "bearish"))
    if up and f.get("dayhi_brk"):
        pts += 20; why.append("breaking the day high")
    elif (f["brk_up"] if up else f["brk_dn"]):
        pts += 15; why.append("30-min %s" % ("breakout" if up else "breakdown"))
    elif (f["new_hi"] if up else f["new_lo"]):
        pts += 8; why.append("new day %s" % ("high" if up else "low"))
    if f["vol"] >= 2.5:
        pts += 15; why.append("volume %.1fx" % f["vol"])
    elif f["vol"] >= 1.5:
        pts += 8; why.append("volume %.1fx" % f["vol"])
    if f.get("vol3", 0) >= 2.0 and abs(f.get("chg3", 0)) < 0.4 and f.get("bar", 0) >= 3:
        pts += 12; why.append("quiet accumulation: volume %.1fx over 15 min, price flat" % f["vol3"])
    g = f["gap"] if np.isfinite(f["gap"]) else 0.0
    if (g >= 1.0 and f["day_chg"] > 0) if up else (g <= -1.0 and f["day_chg"] < 0):
        pts += 7; why.append("gap %+.1f%% holding" % g)
    if (f["mkt"] > 0) if up else (f["mkt"] < 0):
        pts += 5; why.append("Nifty %s" % ("up" if up else "down"))
    if (f["trend"] > 0) if up else (f["trend"] < 0):
        pts += 5; why.append("20-day trend %s" % ("up" if up else "down"))
    r = f["rsi"]
    if np.isfinite(r) and ((r > 78) if up else (r < 22)):
        pts -= 10; why.append("RSI stretched")
    moved = f["day_chg"] if up else -f["day_chg"]
    if moved > 9.0:
        return 0, ["already moved %.1f%% today - too late" % f["day_chg"]]
    if moved > 6.0:
        pts -= 15; why.append("already up %.1f%% - late entry penalty" % f["day_chg"])
    return max(0, min(100, pts)), why


# ---------------------------------------------------------------- RISK + MANAGER
def risk_block(con, day, sym, c):
    v = c["v2"]
    cur = con.execute("select count(*), sum(status='OPEN'), sum(case when status='CLOSED' then net else 0 end),"
                      " sum(sym=?) from trades where day=?", (sym, day)).fetchone()
    n, n_open, realised, same = cur[0] or 0, cur[1] or 0, cur[2] or 0.0, cur[3] or 0
    if same:
        return "already traded today"
    if n >= v["max_trades_day"]:
        return "max trades for the day"
    if n_open >= v["max_open"]:
        return "max open positions"
    if realised <= -v["capital_rs"] * v["daily_loss_pct"] / 100.0:
        return "daily loss limit"
    now = time.time()
    if core.ist_now().hour < 10:
        early = con.execute("select count(*) from trades where day=? and entry_ts<?", (day, now)).fetchone()[0] or 0
        if early >= v.get("max_before_10", 4):
            return "max %d trades before 10:00" % v.get("max_before_10", 4)
    recent = con.execute("select count(distinct sym) from trades where day=? and entry_ts>=?",
                         (day, now - 900)).fetchone()[0] or 0
    if recent >= v.get("max_per_15", 3):
        return "max %d new trades per 15 min" % v.get("max_per_15", 3)
    return None


_said = set()


def risk_note(sym, why):
    k = (sym, why.split(" ")[0])
    if k not in _said:
        _said.add(k)
        dash.event("RISK", "%s skipped: %s" % (sym, why), "warn")


_pending = {}
JUDGE = {"j": None, "tape": "normal", "log": []}


def confirm_ok(sym, px, feed, v, kind):
    """CONFIRM agent: a trigger is acted on only if, `confirm_secs` later, the price still holds it and buyers still lead.
    First call registers the trigger and returns False; later calls return True once the hold is proven."""
    secs = float(v.get("confirm_secs", 25))
    if secs <= 0:
        return True
    now = time.time()
    e = _pending.get(sym)
    if e is None or now - e[0] > 180:
        _pending[sym] = (now, px, kind)
        dash.event("CONFIRM", "%s · %s trigger at %s — holding for %ds before buying" % (sym, kind, rs(px), int(secs)))
        return False
    t0, p0, k0 = e
    if now - t0 < secs:
        return False
    obi = feed.obi(sym) if hasattr(feed, "obi") else None
    if px >= p0 * 0.999 and (obi is None or obi >= 0):
        dash.event("CONFIRM", "✅ %s held %s for %ds · buyers %s" % (
            sym, rs(p0), int(now - t0), ("%.0f%%" % (50 + 50 * obi)) if obi is not None else "n/a"), "buy")
        del _pending[sym]
        j = JUDGE["j"]
        if j is not None and v.get("judge", True):
            try:
                verdict, reason, model_line = j.verdict(sym, px, kind, JUDGE["tape"])
            except Exception as ex:
                log("judge failed:", ex)
                verdict, reason, model_line = "GO", "judge error, letting it through", None
            if verdict == "NO":
                dash.event("JUDGE", "✗ %s — %s%s" % (sym, reason, (" · model: " + model_line) if model_line else ""), "warn")
                log("JUDGE NO", sym, reason)
                j.whips[sym] += 1
                return False
            dash.event("JUDGE", "✓ %s — %s%s" % (sym, reason, (" · model: " + model_line) if model_line else ""), "buy")
        return True
    if now - t0 > secs + 60:
        dash.event("CONFIRM", "✗ %s did not hold %s — no trade" % (sym, rs(p0)), "warn")
        del _pending[sym]
        if JUDGE["j"] is not None:
            JUDGE["j"].note_failed_confirm(sym)
    return False


_tape = {"mode": "normal", "since": 0.0, "cand": "normal"}


def tape_mode(flw, v):
    """RISK agent: in a weak tape (few shares up, Nifty red) raise the bar and halve size. Returns the mode name.
    Hysteresis: weak starts under weak_bull_pct with Nifty red, ends only above weak_bull_pct+6 or Nifty green;
    a change must hold for tape_hold_s (120 s) before it is applied, so the mode does not flap."""
    base_min = v.setdefault("min_score_base", v["min_score"])
    base_blast = v.setdefault("blast_min_base", v["blast_min"])
    cand = _tape["mode"]
    if flw is not None and flw.m:
        m = flw.m
        br = m["breadth"]
        tot = max(br[3], 1)
        bull = br[0] / tot
        nif = float(m["nif"]) if np.isfinite(m["nif"]) else 0.0
        lo = v.get("weak_bull_pct", 30) / 100.0
        if _tape["mode"] == "weak":
            cand = "weak" if (bull < lo + 0.06 and nif < 0.1) else ("strong" if (bull > 0.6 and nif > 0.3) else "normal")
        else:
            cand = "weak" if (bull < lo and nif < 0) else ("strong" if (bull > 0.6 and nif > 0.3) else "normal")
    now = time.time()
    if cand != _tape["cand"]:
        _tape["cand"], _tape["since"] = cand, now
    if cand != _tape["mode"] and now - _tape["since"] >= v.get("tape_hold_s", 120):
        _tape["mode"] = cand
    mode = _tape["mode"]
    if mode == "weak":
        v["min_score"], v["blast_min"], v["size_x"] = base_min + v.get("weak_score_add", 15), base_blast + 10, v.get("weak_size_x", 0.5)
    else:
        v["min_score"], v["blast_min"], v["size_x"] = base_min, base_blast, 1.0
    return mode


def open_card(con, day, sym, side, sc, why, f, ltp, headline, age, c):
    v = c["v2"]
    dist = float(core.stop_dist(f["atr"], ltp, v["stop_atr"], c))
    full = sc >= v["full_score"]
    risk_rs = v["capital_rs"] * v["risk_pct"] / 100.0 * (1.0 if full else 0.5)
    qty = int(min(risk_rs / dist, v["position_cap_rs"] / ltp) * v.get("size_x", 1.0))
    if qty < 1:
        return False
    stop = ltp - side * dist
    trail = v.get("exit", "TRAIL") == "TRAIL"
    book = v.get("book_x", 0) > 0
    target = ltp + side * (v["book_x"] if (trail and book) else v["target_x"]) * dist if (book or not trail) else None
    band = "FULL" if full else "HALF"
    con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                "status,mode) values(?,?,?,?,?,?,?,?,?,?,?,?,?,'OPEN',?)",
                (day, sym, "V2-%s-%d" % ("L" if side == 1 else "S", 10 * (sc // 10)), band, side, qty,
                 int(time.time()), ltp, f["px"], stop, target, dist, ltp, "TRAIL" if trail else "TP"))
    con.commit()
    L = ["%s %s  · score %d/100 · %s size" % ("🟢 PAPER BUY" if side == 1 else "🔴 PAPER SELL (short)", sym, sc, band),
         "%s %s × %d = %s" % ("Buy" if side == 1 else "Sell", rs(ltp), qty, rs(ltp * qty)),
         ("Stop %s (−%.2f%%) · no fixed target: once +%.2f%% the stop trails %.1f%% below the high · risk %s"
          % (rs(stop), dist / ltp * 100, dist / ltp * 100, v["trail_x"] * dist / ltp * 100, rs(dist * qty))) if (trail and not book) else
         ("Stop %s (−%.2f%%) · book 1/3 at %s (+%.2f%%), then stop to entry and trail %.1f%% below the high · risk %s"
          % (rs(stop), dist / ltp * 100, rs(target), v["book_x"] * dist / ltp * 100, v["trail_x"] * dist / ltp * 100,
             rs(dist * qty))) if trail else
         ("Stop %s (−%.2f%%) · Target %s (+%.2f%%) · risk %s" % (rs(stop), dist / ltp * 100, rs(target),
                                                               v["target_x"] * dist / ltp * 100, rs(dist * qty))),
         "Exits: stop · trailing stop · +15% target · 15:15 IST",
         "Why: " + ", ".join(why)]
    if headline:
        L.append("News (%s ago): %s" % ("%dm" % age if age < 120 else "%.0fh" % (age / 60), headline[:160]))
    else:
        L.append("News: none in last 24 h (chart-only setup)")
    L.append("Paper trade")
    core.tg("\n".join(L))
    dash.event("MANAGER", L[0].replace("PAPER ", "") + " · " + L[1], "buy")
    return True


def preopen_watch(kite, news, hist, c, morning=None):
    """09:09 IST: shares with overnight company news and their pre-open price vs yesterday's close."""
    extra = morning.brief(set(hist)) if morning else []
    msg = _preopen_news(kite, news, hist, c)
    if extra:
        msg += "\n\n" + "\n".join(extra)
    if morning:
        msg += "\n\n" + morning.status()
    return msg


def _preopen_news(kite, news, hist, c):
    news.refresh()
    now = time.time()
    picks = []
    for sym in hist:
        pts, side, head, age = news.for_share(sym, now)
        if pts and side and age is not None and age <= 18 * 60:
            picks.append((sym, side, head, age))
    if not picks:
        return "📋 PRE-OPEN WATCH 09:09 — no share-specific overnight news found"
    px = {}
    syms = [p[0] for p in picks][:300]
    for i in range(0, len(syms), 150):
        getdata._quote.wait()
        try:
            q = getdata.call(kite.quote, [getdata.key(s) for s in syms[i:i + 150]])
        except Exception as ex:
            log("pre-open quote failed:", ex)
            continue
        for k, v_ in q.items():
            lp = v_.get("last_price") or 0
            pc = (v_.get("ohlc") or {}).get("close") or 0
            if lp and pc:
                px[getdata.unkey(k)] = (lp / pc - 1) * 100
    rows = []
    for sym, side, head, age in picks:
        g = px.get(sym)
        rows.append((side, g if g is not None else 0.0, sym, head, age))
    up = sorted([r for r in rows if r[0] == 1], key=lambda r: -r[1])[:8]
    dn = sorted([r for r in rows if r[0] == -1], key=lambda r: r[1])[:8]
    L = ["📋 PRE-OPEN WATCH 09:09 — overnight company news + pre-open price (information; buys need the open to hold)"]
    if up:
        L.append("Positive news:")
        for s_, g, sym, head, age in up:
            L.append("  %s %s — %s" % (sym, ("pre-open %+.1f%%" % g) if sym in px else "no pre-open price", head[:90]))
    if dn:
        L.append("Negative news (no shorts; avoid buying):")
        for s_, g, sym, head, age in dn:
            L.append("  %s %s — %s" % (sym, ("pre-open %+.1f%%" % g) if sym in px else "no pre-open price", head[:90]))
    return "\n".join(L)


def sip_base(hist):
    """Per share: average first-5-minute volume over the last 14 sessions and average daily range %."""
    base = {}
    for sym, a in hist.items():
        ts = a["ts"]
        if len(ts) < 75 * 3:
            continue
        loc = ts + core.IST_OFF
        first = (loc % 86400) == core.OPEN_MIN * 60
        if first.sum() < 3:
            continue
        v0 = a["v"][first][-14:]
        day = loc // 86400
        starts = np.r_[0, np.nonzero(np.diff(day))[0] + 1]
        hi = np.maximum.reduceat(a["h"], starts)[-14:]
        lo = np.minimum.reduceat(a["l"], starts)[-14:]
        cl = a["c"][np.r_[starts[1:] - 1, len(ts) - 1]][-14:]
        with np.errstate(invalid="ignore", divide="ignore"):
            rng = float(np.nanmean((hi - lo) / cl * 100))
        avg = float(np.mean(v0))
        if avg > 0 and np.isfinite(rng):
            base[sym] = (avg, rng)
    return base


def stocks_in_play(bars, base, t915, news, v):
    """Rank today's first 5-minute candle by relative volume. Returns (ranked list, total scanned)."""
    rows, scanned = [], 0
    now = time.time()
    for sym, (a, _) in bars.items():
        b = base.get(sym)
        k = a["ts"] == t915
        if b is None or not k.any():
            continue
        scanned += 1
        o, h, l, cl, vol = (float(a[x][k][0]) for x in ("o", "h", "l", "c", "v"))
        if cl < 20 or vol <= 0 or b[1] < 1.2:
            continue
        rvol = vol / b[0]
        if rvol < v["sip_min_rvol"] or vol * cl < v["sip_min_value_lakh"] * 1e5:
            continue
        head = news.for_share(sym, now)[2]
        rows.append({"sym": sym, "rvol": rvol, "o": o, "orh": h, "orl": l, "c": cl, "chg": (cl / o - 1) * 100,
                     "value": vol * cl, "range": b[1], "news": head})
    rows.sort(key=lambda r: -r["rvol"])
    return rows[:v["sip_top"]], scanned


def sip_brief(rows, scanned, v):
    L = ["🎯 STOCKS IN PLAY 09:20 — %d shares with the most unusual opening volume (of %d scanned)" % (len(rows), scanned),
         "Buy trigger = break of the first-5-min high, until %02d:%02d. Red first candle = watch only." % divmod(v["sip_until"], 100)]
    for i, r in enumerate(rows, 1):
        L.append("%2d. %s  vol %.1fx normal (₹%.1f cr) · first 5 min %+.1f%% · trigger %s%s%s" % (
            i, r["sym"], r["rvol"], r["value"] / 1e7, r["chg"], rs(r["orh"]), "" if r["chg"] > 0 else " (red - no buy)",
            ("\n     📰 " + r["news"][:90]) if r["news"] else ""))
    return "\n".join(L)


def open_sip(con, day, r, ltp, rank, n, c):
    v = c["v2"]
    dist = ltp - r["orl"]
    dist = min(max(dist, ltp * 0.006), ltp * 0.03)
    qty = int(min(v["capital_rs"] * v["risk_pct"] / 100.0 / dist, v["position_cap_rs"] / ltp) * v.get("size_x", 1.0))
    if qty < 1:
        return False
    stop = ltp - dist
    con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                "status,mode) values(?,?,?,?,1,?,?,?,?,?,NULL,?,?,'OPEN','SIP')",
                (day, r["sym"], "SIP-%.0fx" % min(r["rvol"], 99), "SIP", qty, int(time.time()), ltp, r["o"], stop, dist, ltp))
    con.commit()
    R = v["sip_trail_r"]
    L = ["🎯 PAPER BUY %s · STOCK IN PLAY #%d of %d" % (r["sym"], rank, n),
         "Buy %s × %d = %s" % (rs(ltp), qty, rs(ltp * qty)),
         "Stop %s (−%.2f%%) below the opening range · risk %s" % (rs(stop), dist / ltp * 100, rs(dist * qty)),
         "No fixed target: at +%.1f%% stop moves to entry, then trails %.1f%% below the high · +15%% target · exit 15:15" % (
             R * dist / ltp * 100, R * dist / ltp * 100),
         "Why: first 5 minutes traded %.1fx its normal volume (%s), first candle %+.1f%%, broke the opening high %s" % (
             r["rvol"], ("₹%.1f crore" % (r["value"] / 1e7)) if r["value"] >= 1e7 else ("₹%.0f lakh" % (r["value"] / 1e5)),
             r["chg"], rs(r["orh"]))]
    L.append("News: " + (r["news"][:160] if r["news"] else "none yet — volume came first"))
    L.append("Paper trade")
    core.tg("\n".join(L))
    dash.event("MANAGER", L[0].replace("PAPER ", "") + " · " + L[1], "buy")
    return True


def open_pre(con, day, sym, sc, why, ltp, stop_px, head, age, c):
    """Pre-breakout buy: stop at the low of the trigger minute (0.6%-3% away), SIP-style trailing exit."""
    v = c["v2"]
    dist = ltp - stop_px * 0.999 if stop_px else ltp * 0.01
    dist = min(max(dist, ltp * 0.01), ltp * 0.03)          # at least 1% room, at most 3%
    full = sc >= v["full_score"]
    qty = int(min(v["capital_rs"] * v["risk_pct"] / 100.0 * (1.0 if full else 0.5) / dist, v["position_cap_rs"] / ltp) * v.get("size_x", 1.0))
    if qty < 1:
        return False
    stop = ltp - dist
    con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                "status,mode) values(?,?,?,?,1,?,?,?,?,?,NULL,?,?,'OPEN','SIP')",
                (day, sym, "PRE-%d" % (10 * (sc // 10)), "PRE", qty, int(time.time()), ltp, ltp, stop, dist, ltp))
    con.commit()
    R = v["sip_trail_r"]
    L = ["⚡ PAPER BUY %s · PRE-BREAKOUT · score %d/100 · %s size" % (sym, sc, "FULL" if full else "HALF"),
         "Buy %s × %d = %s" % (rs(ltp), qty, rs(ltp * qty)),
         "Stop %s (−%.2f%%) under the trigger minute's low · risk %s" % (rs(stop), dist / ltp * 100, rs(dist * qty)),
         "No fixed target: at +%.1f%% stop moves to entry, then trails %.1f%% below the high · +15%% target · exit 15:15" % (
             R * dist / ltp * 100, R * dist / ltp * 100),
         "Why: " + ", ".join(why)]
    if head:
        L.append("News (%s ago): %s" % ("%dm" % age if age < 120 else "%.0fh" % (age / 60), head[:160]))
    L.append("Paper trade")
    core.tg("\n".join(L))
    dash.event("MANAGER", L[0].replace("PAPER ", "") + " · " + L[1], "buy")
    return True


def fast_entries(con, kite, feed, day, c, fst, F, news, ctx, at):
    """Every few seconds: act on day-high breaks, pre-breakouts and breaking news without waiting for the candle."""
    if fst is None or not F:
        return
    try:
        cands = fst.check(F, news, ctx, at, score)
    except Exception as ex:
        log("fast check failed:", ex)
        return
    for sc, s, why, fl, head, age, kind, stop_px in cands[:8]:
        why_not = risk_block(con, day, s, c)
        if why_not == "already traded today":
            continue
        if why_not:
            if (s, why_not.split(" ")[0]) not in _said:
                log("fast skip", s, why_not)
            risk_note(s, why_not)
            return
        p = fl["px"]
        if not confirm_ok(s, p, feed, c["v2"], kind):
            continue
        try:
            con.execute("insert into fired values(?,?,?)", (day, "V2", s))
            con.commit()
        except sqlite3.IntegrityError:
            continue
        ok = (open_pre(con, day, s, sc, why, p, stop_px, head, age, c) if kind == "PRE"
              else open_card(con, day, s, 1, sc, ["LIVE " + why[0]] + why[1:], fl, p, head, age, c))
        if ok:
            log("FAST PAPER", kind, s, sc, p)


def blast_entries(con, feed, day, c, flw, at):
    """Buy the top BLAST RADAR shares when they sit at or break the day high."""
    v = c["v2"]
    if flw is None or not flw.m or not v.get("blast", True):
        return
    now = core.ist_now()
    if now < at(9, 30) or now > at(v["trade_to"] // 100, v["trade_to"] % 100):
        return
    m = flw.m
    for i in flw.top(1, 6, v["blast_min"] - 1):
        s = flw.syms[i]
        p, chg, dh = float(m["ltp"][i]), float(m["chg"][i]), float(m["dist_hi"][i])
        if not (0.5 <= chg <= 8.0) or dh > 0.3:
            continue
        pdh = flw.pdh[i]
        if np.isfinite(pdh) and 0 < (pdh - p) / p * 100 < 0.5:
            continue                                   # right under yesterday's high: wait for the break
        why_not = risk_block(con, day, s, c)
        if why_not == "already traded today":
            continue
        if why_not:
            risk_note(s, why_not)
            return
        if not confirm_ok(s, p, feed, v, "BLAST"):
            continue
        try:
            con.execute("insert into fired values(?,?,?)", (day, "BLAST", s))
            con.commit()
        except sqlite3.IntegrityError:
            continue
        sc = int(m["up"][i])
        big = sc >= v["blast_big"]
        l15 = float(m["l15"][i]) if np.isfinite(m["l15"][i]) else p * 0.99
        dist = min(max(p - l15 * 0.999, p * 0.01), p * 0.03)
        risk = v["capital_rs"] * v["risk_pct"] / 100.0 * (v["blast_risk_x"] if big else 1.0)
        cap = v["blast_cap_rs"] if big else v["position_cap_rs"]
        qty = int(min(risk / dist, cap / p) * v.get("size_x", 1.0))
        if qty < 1:
            continue
        stop = p - dist
        con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                    "status,mode) values(?,?,?,?,1,?,?,?,?,?,NULL,?,?,'OPEN','SIP')",
                    (day, s, "BLAST-%d" % (10 * (sc // 10)), "BLAST", qty, int(time.time()), p, p, stop, dist, p))
        con.commit()
        R = v["sip_trail_r"]
        why = flw.reasons(i, 1)
        L = ["🚀 PAPER BUY %s · BLAST %d/100 · %s size" % (s, sc, "BIG" if big else "NORMAL"),
             "Buy %s × %d = %s" % (rs(p), qty, rs(p * qty)),
             "Stop %s (−%.2f%%) under the last 15-min low · risk %s" % (rs(stop), dist / p * 100, rs(dist * qty)),
             "No fixed target: at +%.1f%% stop moves to entry, then trails %.1f%% below the high · +15%% target · exit 15:15" % (
                 R * dist / p * 100, R * dist / p * 100),
             "Why: day %+.1f%%, at the day high, %s" % (chg, ", ".join(why))]
        L.append("Paper trade")
        core.tg("\n".join(L))
        dash.event("MANAGER", "🚀 BLAST BUY %s %d/100 · %s × %d" % (s, sc, rs(p), qty), "buy")
        log("BLAST PAPER", s, sc, p)


def runner_entries(con, feed, day, c, flw, at):
    """RUNNER: a share already up strongly on heavy volume, holding VWAP, that breaks its day high again after a pause.
    Smaller size, tighter stop, trailing exit. Max `runner_max_day` a day."""
    v = c["v2"]
    if flw is None or not flw.m or not v.get("runner", True):
        return
    now = core.ist_now()
    if now < at(9, 45) or now > at(14, 30):
        return
    m = flw.m
    n_today = con.execute("select count(*) from trades where day=? and strat='RUNNER'", (day,)).fetchone()[0]
    if n_today >= v.get("runner_max_day", 3):
        return
    b = m["b"]
    chg, ltp, hi, rvol, vw, ob = m["chg"], m["ltp"], m["hi"], m["rvol"], m["vw"], m["obi"]
    H = m["H"]
    if b < 3:
        return
    with np.errstate(invalid="ignore"):
        prev_hi = np.nanmax(np.where(np.isnan(H[:, :b]), -np.inf, H[:, :b]), axis=1)   # day high BEFORE the current 5-min bar
    cand = np.nonzero(m["valid"] & (np.nan_to_num(chg) >= v.get("runner_min_chg", 5.0)) & (np.nan_to_num(chg) <= v.get("runner_max_chg", 12.0))
                      & (np.nan_to_num(rvol) >= v.get("runner_min_rvol", 5.0)) & np.isfinite(prev_hi) & (prev_hi > 0)
                      & (np.nan_to_num(ltp) > prev_hi * 1.0005))[0]
    for i in cand[:10]:
        s = flw.syms[i]
        p = float(ltp[i])
        if np.isfinite(vw[i]) and p < vw[i]:
            continue
        if np.isfinite(ob[i]) and ob[i] < 0.1:
            continue
        # that earlier high must be at least 10 minutes old (a pause, then a fresh break)
        row = H[i, :b]
        last_hi_bar = int(np.nanargmax(np.where(np.isnan(row), -np.inf, row)))
        if b - last_hi_bar < 2:
            continue
        why_not = risk_block(con, day, s, c)
        if why_not == "already traded today":
            continue
        if why_not:
            risk_note(s, why_not)
            return
        if not confirm_ok(s, p, feed, v, "RUNNER"):
            continue
        try:
            con.execute("insert into fired values(?,?,?)", (day, "RUNNER", s))
            con.commit()
        except sqlite3.IntegrityError:
            continue
        l15 = float(m["l15"][i]) if np.isfinite(m["l15"][i]) else p * 0.985
        dist = min(max(p - l15 * 0.999, p * 0.008), p * v.get("runner_stop_pct", 1.5) / 100.0)
        risk = v["capital_rs"] * v["risk_pct"] / 100.0 * v.get("runner_risk_x", 0.5)
        qty = int(min(risk / dist, v["position_cap_rs"] / p) * v.get("size_x", 1.0))
        if qty < 1:
            continue
        stop = p - dist
        con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                    "status,mode) values(?,?,?,?,1,?,?,?,?,?,NULL,?,?,'OPEN','SIP')",
                    (day, s, "RUNNER", "RUNNER", qty, int(time.time()), p, p, stop, dist, p))
        con.commit()
        why = flw.reasons(i, 1)
        L = ["🏃 PAPER BUY %s · RUNNER · day %+.1f%% on %.0fx volume" % (s, chg[i], rvol[i]),
             "Buy %s × %d = %s (half risk)" % (rs(p), qty, rs(p * qty)),
             "Stop %s (−%.2f%%) · trails %.1f%% below the high after +1R · +15%% target · exit 15:15" % (
                 rs(stop), dist / p * 100, v["sip_trail_r"] * dist / p * 100),
             "Why: new day high after a %d-min pause, above VWAP, %s" % (5 * (b - last_hi_bar), ", ".join(why[:3])), "Paper trade"]
        core.tg("\n".join(L))
        dash.event("MANAGER", "🏃 RUNNER BUY %s %+.1f%% · %s × %d" % (s, chg[i], rs(p), qty), "buy")
        log("RUNNER PAPER", s, p, "chg %.1f rvol %.1f" % (chg[i], rvol[i]))


def sip_check(con, kite, feed, day, c, sip, at):
    """Between candles: buy any in-play share whose price has just crossed its opening-range high."""
    v = c["v2"]
    if not sip or core.ist_now() > at(v["sip_until"] // 100, v["sip_until"] % 100):
        return
    todo = [r for r in sip["rows"] if r["chg"] > 0 and r["sym"] not in sip["done"]]
    if not todo:
        return
    try:
        px = feed.prices(kite, [r["sym"] for r in todo])
    except Exception as ex:
        log("sip price failed:", ex)
        return
    for r in todo:
        p = px.get(r["sym"])
        if not p or p < r["orh"]:
            continue
        if not confirm_ok(r["sym"], p, feed, v, "STOCK IN PLAY"):
            continue
        sip["done"].add(r["sym"])
        if p > r["orh"] * (1 + v["sip_chase_pct"] / 100.0):
            log("SIP skip", r["sym"], "already %.1f%% above trigger" % ((p / r["orh"] - 1) * 100))
            continue
        why = risk_block(con, day, r["sym"], c)
        if why:
            log("SIP skip", r["sym"], why)
            continue
        try:
            con.execute("insert into fired values(?,?,?)", (day, "SIP", r["sym"]))
            con.commit()
        except sqlite3.IntegrityError:
            continue
        if open_sip(con, day, r, p, sip["rows"].index(r) + 1, len(sip["rows"]), c):
            log("SIP PAPER", r["sym"], p, "rvol %.1f" % r["rvol"])


def scout_brief(F):
    rows = sorted(((f["gap"], f["day_chg"], f["vol"], s) for s, f in F.items() if np.isfinite(f["gap"])))
    L = ["🔭 SCOUT 09:30 — %d liquid shares scanned (information only)" % len(F), "Gap up:"]
    for g, d, v, s in reversed(rows[-6:]):
        L.append("  %s gap %+.1f%% → now %+.1f%%, vol %.1fx" % (s, g, d, v))
    L.append("Gap down:")
    for g, d, v, s in rows[:6]:
        L.append("  %s gap %+.1f%% → now %+.1f%%, vol %.1fx" % (s, g, d, v))
    hot = sorted(F.items(), key=lambda kv: -kv[1]["vol"])[:5]
    L.append("Volume surge:")
    for s, f in hot:
        L.append("  %s %.1fx, %+.1f%% today" % (s, f["vol"], f["day_chg"]))
    return "\n".join(L)


def sector_lines(sec):
    if not sec:
        return ""
    order = sorted(sec.items(), key=lambda kv: kv[1][2])
    L = ["", "Sectors now (avg of our shares):"]
    for k, (avg, n, r) in order[:3]:
        L.append("  ▲ %s %+.1f%% (%d shares)" % (k, avg, n))
    for k, (avg, n, r) in order[3:][-3:]:
        L.append("  ▼ %s %+.1f%% (%d shares)" % (k, avg, n))
    return "\n".join(L)


def summary2(con, day):
    base = engine.summary(con, day, None)
    rows = con.execute("select label, count(*), sum(net>0), sum(net) from trades where status='CLOSED' group by label").fetchall()
    if rows:
        base += "\nBy size band (all days): " + " · ".join(
            "%s %d trades %.0f%% wins %s%s" % (r[0], r[1], 100.0 * r[2] / r[1], "+" if r[3] >= 0 else "−", rs(abs(r[3]))) for r in rows)
    return base


# ---------------------------------------------------------------- day loop
def run_day(c):
    v = c["v2"]
    now = core.ist_now()
    day = str(now.date())
    today = core.day_ord(now)
    con = db()
    at = lambda h, m, s=0: now.replace(hour=h, minute=m, second=s, microsecond=0)
    kite = None
    while core.ist_now() < at(15, 0):
        try:
            kite = core.get_kite(c)
            break
        except Exception as ex:
            log("kite not ready:", ex)
            if core.ist_now() > at(9, 20) and once(con, day, "notoken"):
                core.tg("⚠️ INTRADAY: Kite token not usable (%s). Retrying every minute." % str(ex)[:120])
            time.sleep(60)
    if kite is None:
        return
    uni = getdata.load_universe()
    if once(con, day, "topup"):
        log("topping up history for %d shares" % len(uni))
        try:
            getdata.update_all(kite, c, uni, quiet=True)
        except Exception as ex:
            log("history top-up failed:", ex)
    cut = core.ist_epoch(at(0, 0)) - engine.HIST_DAYS * 86400
    midnight = core.ist_epoch(at(0, 0))

    def tail(sym):
        a = core.load_npz(sym)
        if a is None:
            return None
        k = (a["ts"] >= cut) & (a["ts"] < midnight)
        return {x: val[k] for x, val in a.items()}
    hist = {e["sym"]: tail(e["sym"]) for e in uni}
    hist = {k: x for k, x in hist.items() if x is not None and len(x["ts"]) >= 75 * v.get("min_history_days", 3)}
    nif_hist = tail("NIFTY50")
    tok = {e["sym"]: e["token"] for e in uni}
    order_syms = [e["sym"] for e in uni if e["sym"] in hist]
    news = News(c, uni)
    news.refresh()      # prime: everything already in the table counts as known
    try:
        morning = fast.Morning(day)
    except Exception as ex:
        log("morning data failed:", ex)
        morning = None

    futs = {}
    if c.get("use_websocket", True) and v.get("futures", True):
        try:
            futs = flow.find_futures(kite, order_syms, now.date())
            log("futures found for %d shares" % len(futs))
        except Exception as ex:
            log("futures lookup failed:", ex)
            futs = {}
    feed = None
    if c.get("use_websocket", True):
        try:
            feed = engine.WsFeed(order_syms, tok, core.ist_epoch(at(9, 15)), {k: x[0] for k, x in futs.items()})
            feed.start(kite)
            for _ in range(30):
                if feed.connected:
                    break
                time.sleep(1)
            if not feed.connected:
                raise RuntimeError(feed.err or "could not connect in 30 s")
            if core.ist_now() > at(9, 16):
                feed.backfill(kite, core.ist_now())
        except Exception as ex:
            log("websocket feed failed:", ex)
            if feed is not None:
                feed.stop()
            feed = None
            if once(con, day, "nows"):
                core.tg("⚠️ INTRADAY: live tick feed not available (%s). Slow mode on the top %d shares today."
                        % (str(ex)[:120], c.get("rest_fallback_size", 120)))

    def slow_feed():
        top = order_syms[:c.get("rest_fallback_size", 120)]
        return engine.RestFeed(top, tok), {s: hist[s] for s in top}
    if feed is None:
        feed, hist = slow_feed()
    log("ready: %d shares, feed: %s" % (len(hist), feed.name))
    if core.ist_now() < at(9, 9, 30):
        sleep_until(at(9, 9, 30))
    if core.ist_now() < at(9, 15) and once(con, day, "preopen"):
        try:
            msg = preopen_watch(kite, news, hist, c, morning)
            if msg:
                core.tg(msg)
                dash.event("SCOUT", "pre-open watch posted: overnight news, deals, board meetings, ban list")
        except Exception as ex:
            log("pre-open watch failed:", ex)
    if once(con, day, "hello"):
        core.tg("🌅 INTRADAY v4.1 ready — %d liquid shares, %s\nLive every 3 s: money flow, futures OI, blast radar, day-high break, pre-breakout, breaking news\nScore ≥%d half size, ≥%d full · risk %.1f%% of %s per trade · "
                "max %d open · entries %02d:%02d–%02d:%02d · exit 15:15\nPaper only." % (
                    len(hist), feed.name, v["min_score"], v["full_score"], v["risk_pct"], rs(v["capital_rs"]),
                    v["max_open"], v["trade_from"] // 100, v["trade_from"] % 100, v["trade_to"] // 100, v["trade_to"] % 100) +
                ("\n🖥 Live terminal: %s" % dash_link(v) if dash_link(v) else ""))
    try:
        res = trade_loop(c, con, kite, feed, hist, nif_hist, news, day, today, at, morning, futs)
    finally:
        feed.stop()
    if res == "DEAD_FEED":
        core.tg("⚠️ INTRADAY: the live tick feed is silent while the market is open. Switching to slow mode.")
        feed, hist = slow_feed()
        try:
            res = trade_loop(c, con, kite, feed, hist, nif_hist, news, day, today, at, morning)
        finally:
            feed.stop()
    if res and once(con, day, "summary"):
        core.tg(summary2(con, day))
        try:
            rv = judge.review(con, day, JUDGE["log"])
            if rv:
                core.tg(rv)
                dash.event("REVIEW", rv.split("\n")[0], "info")
        except Exception as ex:
            log("review failed:", ex)
        if now.weekday() == 4:
            w = engine.weekly(con)
            if w:
                core.tg(w)


def dash_link(v):
    p = os.path.join(core.BASE, "dash_token.txt")
    if not os.path.exists(p):
        return ""
    hp = os.path.join(core.BASE, "dash_host.txt")
    ip = os.environ.get("DASH_HOST") or (open(hp).read().strip() if os.path.exists(hp) else "") or "64.227.155.177"
    return "http://%s:%s/?k=%s" % (ip, v.get("dash_port", 8090), open(p).read().strip())


def position_charts(con, day, feed, prices, c):
    """One live chart per trade today: 1-min candles, entry, stop (trailing), best price, P&L. Open ones first."""
    out = []
    rows = con.execute("select sym,label,qty,entry_ts,entry,stop,best,exit_ts,exit,reason,net,status,mode,dist from trades "
                       "where day=? order by status desc, id", (day,)).fetchall()
    syms_open = [r[0] for r in rows if r[11] == "OPEN"]
    try:
        feed.set_tape(syms_open)
    except Exception:
        pass
    for sym, label, qty, ets, entry, stop, best, xts, ex, reason, net, status, mode, dist in rows:
        ch = feed.chart1(sym) if status == "OPEN" or (xts and time.time() - xts < 6 * 3600) else None
        p = prices.get(sym)
        d = {"s": sym, "k": label, "q": qty, "e": round(entry, 2), "st": round(stop, 2), "best": round(best or entry, 2),
             "t": time.strftime("%H:%M", time.gmtime(ets + core.IST_OFF)), "open": status == "OPEN", "mode": mode,
             "e_min": int(max(0, (ets - feed.t0) // 60)) if hasattr(feed, "t0") else None}
        if status == "OPEN":
            d["px"] = round(p, 2) if p else None
            d["pl"] = round((p - entry) * qty - core.cost_rs(entry * qty, core.cfg())) if p else None
            d["pl_pct"] = round((p / entry - 1) * 100, 2) if p else None
        else:
            d.update({"x": round(ex, 2) if ex else None, "xt": time.strftime("%H:%M", time.gmtime(xts + core.IST_OFF)) if xts else None,
                      "x_min": int(max(0, (xts - feed.t0) // 60)) if (xts and hasattr(feed, "t0")) else None,
                      "r": reason, "pl": round(net or 0)})
        if ch:
            d.update(ch)
        out.append(d)
    return out


def trade_loop(c, con, kite, feed, hist, nif_hist, news, day, today, at, morning=None, futs=None):
    v = c["v2"]
    live = hasattr(feed, "obi")
    state = {"nif": None}

    def nifty_chg():
        if live:
            return feed.nifty_chg()
        a = state["nif"]
        if a is None or not len(a["ts"]):
            return None
        return float((a["c"][-1] / a["o"][0] - 1) * 100)
    ctx = {"smap": morning.sectors if morning else {}, "deals": morning.deals if morning else {},
           "ban": morning.ban if morning else set(), "board": morning.board if morning else {},
           "sec": {}, "obi": (feed.obi if live else (lambda s: None)), "nifty_chg": nifty_chg}
    fst = fast.Fast(feed, hist, v) if (live and v.get("fast", True)) else None
    F_cache = {}
    flw = None
    if live:
        try:
            flw = flow.Flow(feed, hist, morning, news, v, fst)
            flw.held_fn = lambda s_: risk_block(con, day, s_, c)
            JUDGE["j"] = judge.Judge(feed, flw, news, fst)
            flw.fiidii = getattr(morning, "fiidii", None) if morning is not None else None
            ctx["flow"] = flw
            if futs:
                import threading

                def _base():
                    try:
                        b = flow.oi_baseline(kite, futs, feed, day)
                        flw.set_oi_base(b)
                        log("OI baseline for %d futures" % len(b))
                        dash.event("FLOW", "futures OI baseline loaded for %d F&O shares" % len(b))
                    except Exception as ex:
                        log("OI baseline failed:", ex)
                threading.Thread(target=_base, daemon=True).start()
        except Exception as ex:
            import traceback
            traceback.print_exc()
            log("flow engine failed:", ex)
            flw = None
    tick = {"dash": 0.0, "radar": 0.0, "flow": 0.0, "hot": 0.0, "vix": 0.0}
    sipref = {"sip": None}

    def hot_list():
        """Shares worth watching tick-by-tick, with the price that should wake the desk at once."""
        trig = {}
        try:
            if flw is not None and flw.m:
                m = flw.m
                for i in flw.top(1, 25, 40):
                    hi = float(m["hi"][i]) if np.isfinite(m["hi"][i]) else None
                    if hi:
                        trig[flw.syms[i]] = hi * 0.997          # blast watch: within 0.3% of the day high
            for s_, f in (F_cache or {}).items():
                hi = f.get("dayhi")
                if hi:
                    t_ = hi * (1 - v.get("pre_band_pct", 0.3) / 100.0)
                    trig[s_] = min(trig.get(s_, np.inf), t_)    # pre-breakout band / day-high break
            sp = sipref["sip"]
            if sp:
                for r in sp["rows"]:
                    if r["sym"] not in sp["done"]:
                        trig[r["sym"]] = min(trig.get(r["sym"], np.inf), r["orh"])   # opening-range high
            for (s_,) in con.execute("select sym from trades where day=?", (day,)):
                trig.pop(s_, None)                              # already traded today: never again today
        except Exception as ex:
            log("hot list failed:", ex)
        feed.set_hot(trig)
        return len(trig)

    def heartbeat():
        """Every pass (~3 s): money flow, blast entries, radar post, dashboard state."""
        nowt = time.time()
        if flw is not None:
            try:
                if nowt - tick["flow"] >= 2 or woke["s"]:
                    tick["flow"] = nowt
                    flw.update()
                    flw.note_changes()
                    mode = tape_mode(flw, v)
                    JUDGE["tape"] = mode
                    flw.tape = mode
                    if mode != state.get("tape"):
                        state["tape"] = mode
                        msg = {"weak": "⚠️ weak tape: under %d%% of shares up and Nifty red → min score %d, blast %d, half size" % (
                                   v.get("weak_bull_pct", 30), v["min_score"], v["blast_min"]),
                               "strong": "strong tape: normal rules", "normal": "normal tape: min score %d, full size" % v["min_score"]}[mode]
                        dash.event("RISK", msg, "warn" if mode == "weak" else "info")
                        log("tape mode:", mode)
                blast_entries(con, feed, day, c, flw, at)
                runner_entries(con, feed, day, c, flw, at)
                ist = core.ist_now()
                if (at(9, 30) <= ist <= at(14, 50) and nowt - tick["radar"] >= v["radar_every_min"] * 60
                        and ist.minute % v["radar_every_min"] == 0):
                    tick["radar"] = nowt
                    core.tg(flw.radar_text())
                    dash.event("FLOW", "🚀 blast radar posted to Telegram")
            except Exception as ex:
                log("flow update failed:", ex)
        if nowt - tick["hot"] >= 5:
            tick["hot"] = nowt
            hot_list()
        if nowt - tick.get("tlog", 0.0) >= 60:
            tick["tlog"] = nowt
            JUDGE["log"].append(JUDGE["tape"])
        if flw is not None and nowt - tick["vix"] >= 60:
            tick["vix"] = nowt
            try:
                q = kite.quote(["NSE:INDIA VIX"])
                flw.vix = round(float(list(q.values())[0]["last_price"]), 2)
            except Exception as ex:
                if ("VIX", "fail") not in _said:
                    _said.add(("VIX", "fail"))
                    log("VIX quote failed:", ex)
        if nowt - tick["dash"] >= 1:
            tick["dash"] = nowt
            try:
                syms = [r[0] for r in con.execute("select sym from trades where day=? and status='OPEN'", (day,))]
                prices = feed.prices(kite, syms) if (syms and live) else {}
                st = (flw.state(con, day, feed.name, prices) if (flw is not None and flw.m)
                      else flow.base_state(con, day, feed.name, prices, None))
                st["pos"] = position_charts(con, day, feed, prices, c)
                dash.write(st)
            except Exception as ex:
                log("dashboard state failed:", ex)
    woke = {"s": None}
    lag = dt.timedelta(seconds=2 if feed.poll < 30 else 5)
    t = core.ist_now()
    j0 = int((t - at(9, 20)).total_seconds() // 300) + 1 if t > at(9, 20) else 0
    t_from = at(v["trade_from"] // 100, v["trade_from"] % 100)
    t_to = at(v["trade_to"] // 100, v["trade_to"] % 100)
    base = sip_base(hist) if v.get("sip") else {}
    sip = None
    log("stocks-in-play baseline for %d shares" % len(base))
    for j in range(max(j0, 0), core.NB5):
        close_t = at(9, 20) + dt.timedelta(minutes=5 * j)
        if close_t > at(15, 15):
            break
        while core.ist_now() < close_t + lag:
            engine.watch(con, kite, feed, day, c)
            sip_check(con, kite, feed, day, c, sip, at)
            fast_entries(con, kite, feed, day, c, fst, F_cache, news, ctx, at)
            sipref["sip"] = sip
            heartbeat()
            woke["s"] = None
            fresh = news.refresh()
            for ts_, title, link_ in fresh:
                nm = news.names(title)
                if 0 < len(nm) <= 2:
                    dash.event("NEWS", "%s · %s" % (", ".join(nm), title[:150]), "news")
            for text, side in news.macro(fresh):          # ⚡ market news between candles too
                core.tg("⚡ MARKET NEWS%s\n%s" % ({1: " · bullish read", -1: " · bearish read"}.get(side, ""), text[:300]))
                dash.event("NEWS", "⚡ " + text[:180], "warn")
            left = (close_t + lag - core.ist_now()).total_seconds()
            if left > 0:
                w = feed.wait(min(feed.poll, left))
                if w:
                    woke["s"] = w
                    if (w, "wake") not in _said:
                        _said.add((w, "wake"))
                        dash.event("CHARTS", "⚡ %s ticked through its trigger — checking now" % w)
        bar_start = core.ist_epoch(close_t) - 300
        nif_today, raw = None, {}
        for _ in range(4):
            nif_today, raw = feed.bars(j, kite, core.ist_now())
            if len(nif_today["ts"]) and (nif_today["ts"] == bar_start).any():
                break
            time.sleep(3)
        else:
            if j >= 2 and len(nif_today["ts"]) == 0:
                if feed.poll < 30:
                    try:
                        probe = engine.today_bars(kite, getdata.NIFTY["token"], core.ist_now())
                    except Exception as ex:
                        log("holiday probe failed:", ex)
                        continue
                    if len(probe["ts"]):
                        return "DEAD_FEED"
                log("no Nifty candles today - market holiday, stopping for the day")
                return False
            log("bar %d: Nifty candle missing, skipping this bar" % j)
            continue
        bars = {s: (a, core.merge_arrays(hist[s], a)) for s, a in raw.items() if s in hist and len(a["ts"])}
        if base and sip is None and close_t <= at(v["sip_until"] // 100, v["sip_until"] % 100):
            try:
                rows, scanned = stocks_in_play(bars, base, core.ist_epoch(at(9, 15)), news, v)
                sip = {"rows": rows, "done": set(x[0] for x in con.execute(
                    "select sym from trades where day=?", (day,)).fetchall())}
                log("stocks in play: %d of %d scanned" % (len(rows), scanned))
                if rows and once(con, day, "sip"):
                    core.tg(sip_brief(rows, scanned, v))
                    dash.event("SCOUT", "🎯 stocks in play: " + ", ".join("%s %.1fx" % (r["sym"], r["rvol"]) for r in rows[:8]))
                sip_check(con, kite, feed, day, c, sip, at)
            except Exception as ex:
                log("stocks in play failed:", ex)
                sip = {"rows": [], "done": set()}
        for tr in open_trades(con, day):
            a = bars.get(tr["sym"], (None,))[0]
            if a is None or tr["entry_ts"] > bar_start:
                continue
            k = a["ts"] == bar_start
            if k.any():
                check_price(con, tr, float(a["h"][k][0]), float(a["l"][k][0]), float(a["c"][k][0]), c,
                            gap_open=float(a["o"][k][0]))
        t0 = time.time()
        news.fetch_budget = 12                          # at most 12 article bodies fetched per candle
        try:
            F = features({s: b[1] for s, b in bars.items()}, core.merge_arrays(nif_hist, nif_today), today, j, c)
        except Exception as ex:
            log("features failed:", ex)
            F = {}
        state["nif"] = nif_today
        F_cache = F
        ctx["sec"] = fast.sector_table(F, ctx["smap"]) if ctx["smap"] else {}
        if j >= 2 and F and once(con, day, "scout"):
            core.tg(scout_brief(F) + sector_lines(ctx["sec"]))
        nowt = time.time()
        cands = []
        for s, f in F.items():
            npts, nside, head, age = news.for_share(s, nowt)
            for side in (1, -1):
                if side == -1 and not c.get("allow_short", True):
                    continue
                sc, why = score(f, npts, nside, side, age)
                if side == 1 and (sc or not why or ("too late" not in why[0] and "other way" not in why[0])):
                    ep, ew = fast.extras(s, f, bool(npts and nside == side), ctx)
                    sc, why = max(0, min(100, sc + ep)), why + ew
                if sc >= v["min_score"]:
                    cands.append((sc, s, side, why, f, head, age, bool(npts and nside == side)))
        cands.sort(key=lambda x: -x[0])
        took = time.time() - t0
        log("bar %d: %d shares, %d candidates ≥%d, %.1f s" % (j, len(F), len(cands), v["min_score"], took))
        dash.event("CHARTS", "%s candle: %d shares scanned, %d setups ≥%d%s" % (
            close_t.strftime("%H:%M"), len(F), len(cands), v["min_score"],
            (" · best " + ", ".join("%s %d" % (x[1], x[0]) for x in cands[:3])) if cands else ""))
        if took > 120 and once(con, day, "slow"):
            core.tg("⚠️ INTRADAY: one scan took %.0f s - too slow, tell Claude" % took)
        if close_t > t_to or not cands:
            continue
        if close_t < t_from:                            # before 09:30 only news-backed setups may enter
            cands = [x for x in cands if x[7]]
            if not cands:
                continue
        px = {}
        try:
            px = feed.prices(kite, sorted(set(x[1] for x in cands[:12])))
        except Exception as ex:
            log("entry price failed:", ex)
        for sc, s, side, why, f, head, age, _nb in cands[:12]:
            why_not = risk_block(con, day, s, c)
            if why_not == "already traded today":
                continue
            if why_not:
                log("skip", s, why_not)
                risk_note(s, why_not)
                break
            if s not in px:
                continue
            try:
                con.execute("insert into fired values(?,?,?)", (day, "V2", s))
                con.commit()
            except sqlite3.IntegrityError:
                continue
            if open_card(con, day, s, side, sc, why, f, px[s], head, age, c):
                log("PAPER", s, side, sc, px[s])
    sleep_until(at(15, 15, 5))
    ot = open_trades(con, day)
    if ot:
        px = {}
        for _ in range(3):
            try:
                px = feed.prices(kite, [tr["sym"] for tr in ot])
                break
            except Exception as ex:
                log("square-off price failed:", ex)
                time.sleep(5)
        for tr in ot:
            close_trade(con, tr, px.get(tr["sym"], tr["entry"]), "15:15 square-off" if tr["sym"] in px
                        else "15:15 square-off (NO PRICE - booked flat, check)", c)
    try:  # final dashboard picture of the day (kept on screen until the next session)
        dash.event("MANAGER", "day closed — all positions squared off at 15:15")
        st = (flw.state(con, day, "closed", {}) if (flw is not None and flw.m) else flow.base_state(con, day, "closed", {}, None))
        st["pos"] = position_charts(con, day, feed, {}, c)
        dash.write(st)
    except Exception as ex:
        log("final dashboard state failed:", ex)
    return True


def main():
    log("GIR INTRADAY v2 started (paper only)")
    now = core.ist_now()
    day = str(now.date())
    start = now.replace(hour=9, minute=2, second=0, microsecond=0)
    con = db()
    done = con.execute("select 1 from notes where day=? and key='done'", (day,)).fetchone()
    try:
        import holidays
        hol = holidays.holiday(now.date())
    except Exception as ex:
        log("holiday check failed:", ex)
        hol = None
    if hol and hol != "weekend" and not done:
        nxt = holidays.next_trading_day(now.date())
        log("NSE holiday today (%s) - desk sleeping until %s" % (hol, nxt))
        if once(con, day, "holiday"):
            core.tg("📅 NSE holiday today (%s). Desk is sleeping; next session %s 09:15." % (hol, nxt.strftime("%a %d %b")))
        once(con, day, "done")
        done = True
    if now.weekday() < 5 and not done and start <= now < now.replace(hour=15, minute=40):
        try:
            run_day(cfg2())
        except Exception as ex:
            import traceback
            traceback.print_exc()
            if any(once(con, day, "err%d" % i) for i in range(3)):
                core.tg("⚠️ INTRADAY v2 error: %s — restarting in 30 s" % str(ex)[:200])
            sys.exit(1)
        once(con, day, "done")
        sys.exit(0)
    nxt = start if now < start else start + dt.timedelta(days=1)
    while nxt.weekday() >= 5:
        nxt += dt.timedelta(days=1)
    log("sleeping until", nxt)
    sleep_until(nxt)
    sys.exit(0)


if __name__ == "__main__":
    main()
