
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RAVEN  —  News-Catalyst Latency Engine  (GIR lane #6)
=====================================================
Purpose : Catch exchange-filing catalysts (order wins, promoter raises, QIP,
          USFDA approvals, M&A) in the FIRST SECONDS after they hit the NSE
          feed — before the stock locks upper circuit. This is the SPEED lane.

What makes it different from gir_eq / F&O / Hunter / Phoenix:
  * gir_eq READS news and sends it to Gemini for JUDGEMENT  -> smart, slow, costs API money.
  * RAVEN  READS the same feed but DECIDES with hardcoded RULES -> literal, instant, ZERO Gemini.
  It only fires on filings whose meaning is unambiguous from a KEYWORD + a NUMBER.
  Fuzzy/ambiguous commentary is deliberately ignored (that is gir_eq's job).

DATA SOURCES (none of them is Gemini / any LLM):
  1. NSE corporate-announcements API  -> plain HTTPS GET (free; same endpoint gir_eq uses)
  2. Kite quote API                   -> LTP, upper/lower circuit limits, volume (your Kite plan)
  3. Liquid universe file             -> reuse Hunter's universe (operator-trap filter)

COMPLIANCE (inherited from gir.py house rules):
  * NRO account -> CNC delivery ONLY. MIS is blocked. No F&O / commodity / currency.
  * Catalyst "scalp" = enter on filing, hold 1-3 days delivery, exit. NOT intraday MIS.
  * SEBI retail-algo framework: above broker order-rate thresholds a live algo must be
    registered/approved by the broker. IRRELEVANT in PAPER mode. VERIFY against Zerodha's
    algo policy BEFORE flipping PAPER_MODE = False. (Do not silently go live.)

SAFETY:
  * PAPER_MODE = True by default. The broker wrapper RAISES on any real order call.
  * Own ₹5,00,000 book, own ledger / positions / seen files. Never touches other lanes' pool.

MODES:
  python3 raven.py --probe       # dump raw NSE feed + parsed fields (validate before trading)
  python3 raven.py --intraday    # main scan loop (default)
  python3 raven.py --preopen     # 08:45 sweep of overnight filings -> gap watchlist
  python3 raven.py --eod         # 15:35 sweep
  python3 raven.py --manage      # exit manager (run on a fast timer)
  python3 raven.py --status      # print ledger + open positions

Author: built for Rama's GIR ecosystem. Logs to journald (journalctl -u raven).
"""

# __GIR_TG_TOPIC_ROUTING__ (auto top-inject, lazy env)
try:
 import os as _o, requests as _r
 _b=_r.sessions.Session.request
 def _f(self,*a,**k):
  try:
   u=k.get('url') or (a[1] if len(a)>1 else '')
   if 'sendMessage' in str(u):
    _t=_o.environ.get('TG_THREAD_RAVEN','').strip()
    d=k.get('data')
    if _t and isinstance(d,dict) and 'message_thread_id' not in d:
     d=dict(d); d['message_thread_id']=int(_t); k['data']=d
  except Exception: pass
  return _b(self,*a,**k)
 _r.sessions.Session.request=_f
except Exception: pass
# __GIR_TG_TOPIC_ROUTING_END__
import os
import re
import json
import time
import argparse
import datetime as dt
from pathlib import Path

# ----------------------------------------------------------------------------- #
#  CONFIG  — every threshold lives here. Tune, don't hunt through the code.      #
# ----------------------------------------------------------------------------- #
class CFG:
    # --- identity / safety ---
    LANE_NAME          = "RAVEN"
    PAPER_MODE         = True            # HARD BLOCK. Real orders raise while True.

    # --- capital / sizing ---
    BOOK               = 500_000.0       # ₹5L separate book
    POSITION_PCT       = 0.13            # ~13% per trade -> ~7-8 concurrent max
    MAX_CONCURRENT     = 8
    MAX_ENTRIES_PER_DAY= 6
    MAX_DAILY_LOSS_PCT = 0.05            # stand down for the day if book down 5%

    # --- catalyst scoring / gates ---
    MIN_SCORE          = 70
    # --- Stage 2 (Gemini judgement on survivors) ---
    LLM_ENABLED        = True
    LLM_MODEL          = "gemini-2.5-flash"
    GEMINI_API_KEY_ENV = "GEMINI_API_KEY"
    LLM_MIN_CONF       = 0.65            # enter only if Gemini confidence >= this
    LLM_MAX_RETRIES    = 2              # 0-100; below this, do not enter
    VALUE_MCAP_MIN     = 0.03            # order value / mcap >= 3% (magnitude law)
    PROMOTER_MCAP_MAX  = 1000_00_00_000  # promoter raise fires on mcap < ₹1000cr regardless of value
    FRESHNESS_SEC      = 180             # intraday: filing age must be < 3 min
    MIN_MARKET_CAP     = 100_00_00_000   # ₹100cr floor (kills micro/operator traps)
    MIN_AVG_VOLUME     = 100_000         # shares/day floor (liquidity)
    MIN_CIRCUIT_BAND   = 0.10            # require >=10% band; skips 2% and 5% bands
    ENTRY_HEADROOM     = 0.97            # enter only if LTP <= 97% of upper circuit

    # --- exits ---
    STOP_PCT           = 0.06            # hard stop 6% below entry (was 4%: too tight, noise stop-outs)
    TARGET_PCT         = 0.06            # first target +6% -> book partial, stop to breakeven
    PARTIAL_FRACTION   = 0.5             # sell half at target
    TRAIL_PCT          = 0.04            # after partial, trail 4% off the peak
    MAX_HOLD_DAYS      = 3               # time-stop (catalyst pops fade)

    # --- market kill switch ---
    CRASH_NIFTY_DROP   = 0.03            # if Nifty50 down >3% intraday, stand down

    # --- cadence (PAPER values; THROTTLE for live to respect NSE + broker limits) ---
    SCAN_INTERVAL_SEC  = 5

    # --- paths (VERIFY universe path against your droplet) ---
    BASE_DIR           = Path("/home/globalbot/raven")
    UNIVERSE_FILE      = Path("/home/globalbot/eq_floor/universe.csv")  # Hunter's liquid universe (CSV)
    POSITIONS_FILE     = BASE_DIR / "raven_positions.json"
    LEDGER_FILE        = BASE_DIR / "raven_ledger.json"
    SEEN_FILE          = BASE_DIR / "raven_seen.json"
    SIGNAL_INBOX       = BASE_DIR / "raven_signals.json"   # optional: decision_brain can read this
    TRENDLYNE_CSV      = Path("/home/globalbot/trendlyne_data/trendlyne_all_stocks.csv")  # mcap source (₹cr)

    # --- NSE feed ---
    NSE_HOME           = "https://www.nseindia.com"
    NSE_ANN_URL        = "https://www.nseindia.com/api/corporate-announcements?index=equities"
    HTTP_TIMEOUT       = 10


# ----------------------------------------------------------------------------- #
#  LOGGING  — to stdout so journald captures it (journalctl -u raven)            #
# ----------------------------------------------------------------------------- #
def log(level, msg):
    ts = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{ts} [{CFG.LANE_NAME}] {level}: {msg}", flush=True)

def info(m):  log("INFO", m)
def warn(m):  log("WARN", m)
def err(m):   log("ERROR", m)
def crit(m):  log("CRIT", m)


# ----------------------------------------------------------------------------- #
#  TELEGRAM  — alerts on entry / exit / daily summary / errors                   #
#  Reads TG_BOT_TOKEN + TG_CHAT_ID from .env. Silent no-op if not configured.    #
# ----------------------------------------------------------------------------- #
class Telegram:
    def __init__(self):
        self.token = (os.environ.get("TELEGRAM_TOKEN")
                      or os.environ.get("TELEGRAM_BOT_TOKEN")
                      or os.environ.get("TG_BOT_TOKEN", "")).strip()
        self.chat  = (os.environ.get("TELEGRAM_CHAT_ID")
                      or os.environ.get("TG_CHAT_ID", "")).strip()
        self.on    = bool(self.token and self.chat)
        if not self.on:
            warn("Telegram not configured (TG_BOT_TOKEN / TG_CHAT_ID missing) — alerts disabled")

    def send(self, text):
        if not self.on:
            return
        try:
            import requests
            url = f"https://api.telegram.org/bot{self.token}/sendMessage"
            requests.post(url, data={"chat_id": self.chat,
                                     "text": f"🦅 RAVEN\n{text}",
                                     "parse_mode": "HTML"},
                          timeout=CFG.HTTP_TIMEOUT)
        except Exception as e:
            warn(f"Telegram send failed: {e}")


# ----------------------------------------------------------------------------- #
#  KITE ADAPTER  — login, quotes, circuit limits, paper order routing           #
#  Credentials come from .env. Wire get_kite() to your existing TOTP helper.     #
# ----------------------------------------------------------------------------- #
class PaperOrderBlock(Exception):
    """Raised if a real broker order is attempted while PAPER_MODE is True."""

class KiteAdapter:
    def __init__(self):
        self.kite = self._login()

    def _login(self):
        # Preferred: reuse the project's existing login helper if present.
        try:
            from kite_login import get_kite          # <-- your existing helper, if any
            k = get_kite()
            info("Kite session via project kite_login helper")
            return k
        except Exception:
            pass
        # Fallback: build from .env (api_key + a pre-generated access_token).
        try:
            from kiteconnect import KiteConnect
            api_key = os.environ.get("KITE_API_KEY", "").strip()
            # TOKENFIX 2026-06-11: read the daily-refreshed token file the main bot writes,
            # falling back to .env only if the file is missing. Fixes RAVEN reading a stale .env token.
            token = ""
            try:
                import json as _json
                _td = _json.load(open("/home/globalbot/data/kite_token.json"))
                token = (_td.get("access_token") or "").strip()
            except Exception:
                pass
            if not token:
                token = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
            if not (api_key and token):
                warn("KITE_API_KEY / KITE_ACCESS_TOKEN missing — quote calls will fail")
                return None
            k = KiteConnect(api_key=api_key)
            k.set_access_token(token)
            info("Kite session via .env access token")
            return k
        except Exception as e:
            err(f"Kite login failed: {e}")
            return None

    def quote(self, symbols):
        """symbols: list like ['NSE:RELIANCE']. Returns kite quote dict or {}."""
        if not self.kite:
            return {}
        try:
            return self.kite.quote(symbols)
        except Exception as e:
            warn(f"quote failed for {symbols}: {e}")
            return {}

    def snapshot(self, symbol):
        """Return (ltp, upper_circuit, lower_circuit, volume, prev_close) for NSE:<symbol>."""
        key = f"NSE:{symbol}"
        q = self.quote([key]).get(key, {})
        if not q:
            return None
        ltp   = q.get("last_price")
        upper = q.get("upper_circuit_limit") or q.get("ohlc", {}).get("upper_circuit")
        lower = q.get("lower_circuit_limit") or q.get("ohlc", {}).get("lower_circuit")
        vol   = q.get("volume") or q.get("volume_traded")
        prevc = q.get("ohlc", {}).get("close")
        if ltp is None or not upper:
            return None
        return {"ltp": float(ltp), "upper": float(upper),
                "lower": float(lower or 0), "volume": int(vol or 0),
                "prev_close": float(prevc or 0)}

    def nifty_intraday_change(self):
        """Fraction change of Nifty50 today (for kill switch). None if unavailable."""
        key = "NSE:NIFTY 50"
        q = self.quote([key]).get(key, {})
        ohlc = q.get("ohlc", {})
        ltp, close = q.get("last_price"), ohlc.get("close")
        if not (ltp and close):
            return None
        return (ltp - close) / close

    def place_paper_or_block(self, symbol, qty, price, side):
        """In PAPER mode this NEVER hits the broker. Returns a synthetic fill."""
        if CFG.PAPER_MODE:
            return {"status": "PAPER_FILL", "symbol": symbol, "qty": qty,
                    "price": price, "side": side, "ts": dt.datetime.now().isoformat()}
        # ---- LIVE PATH (disabled by default) ----
        raise PaperOrderBlock(
            "PAPER_MODE is True — real order blocked. Set PAPER_MODE=False AND verify "
            "SEBI/Zerodha algo registration before enabling the live path below.")
        # When you DO go live, implement here with product=CNC (NRO rule), e.g.:
        # return self.kite.place_order(variety=..., exchange="NSE", tradingsymbol=symbol,
        #     transaction_type=side, quantity=qty, product="CNC", order_type="LIMIT", price=price)


# ----------------------------------------------------------------------------- #
#  LEDGER / PAPER BROKER  — own ₹5L book, positions, persistence                 #
# ----------------------------------------------------------------------------- #
class Ledger:
    def __init__(self):
        CFG.BASE_DIR.mkdir(parents=True, exist_ok=True)
        self.state = self._load_ledger()
        self.positions = self._load_json(CFG.POSITIONS_FILE, default={})

    def _load_json(self, path, default):
        try:
            return json.loads(Path(path).read_text())
        except Exception:
            return default

    def _load_ledger(self):
        d = self._load_json(CFG.LEDGER_FILE, default=None)
        if d:
            return d
        return {"cash": CFG.BOOK, "realized_pnl": 0.0,
                "entries_today": 0, "day": str(dt.date.today()),
                "day_start_equity": CFG.BOOK}

    def save(self):
        Path(CFG.LEDGER_FILE).write_text(json.dumps(self.state, indent=2))
        Path(CFG.POSITIONS_FILE).write_text(json.dumps(self.positions, indent=2))

    def roll_day(self):
        today = str(dt.date.today())
        if self.state.get("day") != today:
            self.state["day"] = today
            self.state["entries_today"] = 0
            self.state["day_start_equity"] = self.state["cash"]  # positions valued at manage time
            self.save()

    def can_enter(self, cost):
        if len(self.positions) >= CFG.MAX_CONCURRENT:
            return False, "max concurrent positions"
        if self.state["entries_today"] >= CFG.MAX_ENTRIES_PER_DAY:
            return False, "daily entry cap"
        if cost > self.state["cash"]:
            return False, "insufficient cash"
        # daily loss circuit breaker
        dd = (self.state["day_start_equity"] - self.state["cash"]) / CFG.BOOK
        if dd >= CFG.MAX_DAILY_LOSS_PCT:
            return False, "daily loss limit hit — standing down"
        return True, "ok"

    def open_position(self, symbol, qty, price, meta):
        cost = qty * price
        self.state["cash"] -= cost
        self.state["entries_today"] += 1
        self.positions[symbol] = {
            "symbol": symbol, "qty": qty, "entry_price": price,
            "entry_time": dt.datetime.now().isoformat(),
            "stop_price": round(price * (1 - CFG.STOP_PCT), 2),
            "target_price": round(price * (1 + CFG.TARGET_PCT), 2),
            "peak_price": price, "partial_done": False,
            "category": meta.get("category"), "value_cr": meta.get("value_cr"),
            "score": meta.get("score"), "ann_id": meta.get("ann_id"),
        }
        self.save()

    def reduce_position(self, symbol, qty, price):
        p = self.positions.get(symbol)
        if not p:
            return 0.0
        qty = min(qty, p["qty"])
        proceeds = qty * price
        pnl = (price - p["entry_price"]) * qty
        self.state["cash"] += proceeds
        self.state["realized_pnl"] += pnl
        p["qty"] -= qty
        if p["qty"] <= 0:
            self.positions.pop(symbol, None)
        else:
            p["partial_done"] = True
            p["stop_price"] = round(p["entry_price"], 2)  # move stop to breakeven
        self.save()
        return pnl


# ----------------------------------------------------------------------------- #
#  NSE FEED  — bootstrap a browser-style session, poll announcements             #
# ----------------------------------------------------------------------------- #
class NSEFeed:
    HEADERS = {
        "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                       "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"),
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.nseindia.com/",
    }

    def __init__(self):
        import requests
        self.requests = requests
        self.session = None
        self._bootstrap()

    def _bootstrap(self):
        try:
            s = self.requests.Session()
            s.headers.update(self.HEADERS)
            s.get(CFG.NSE_HOME, timeout=CFG.HTTP_TIMEOUT)  # sets cookies
            self.session = s
        except Exception as e:
            err(f"NSE bootstrap failed: {e}")
            self.session = None

    def fetch(self):
        """Return a list of raw announcement dicts (defensive on schema)."""
        if not self.session:
            self._bootstrap()
        if not self.session:
            return []
        try:
            r = self.session.get(CFG.NSE_ANN_URL, timeout=CFG.HTTP_TIMEOUT)
            if r.status_code in (401, 403):           # cookies stale -> rebootstrap once
                self._bootstrap()
                r = self.session.get(CFG.NSE_ANN_URL, timeout=CFG.HTTP_TIMEOUT)
            data = r.json()
            return data if isinstance(data, list) else data.get("data", [])
        except Exception as e:
            warn(f"NSE fetch failed: {e}")
            return []

    @staticmethod
    def parse(raw):
        """Pull (symbol, text, ann_id, age_sec) from a raw item — schema varies, so be defensive."""
        symbol = raw.get("symbol") or raw.get("Symbol") or raw.get("sm_symbol")
        text   = " ".join(str(raw.get(k, "")) for k in
                          ("attchmntText", "sm_name", "desc", "headline", "smIndustry", "subject")
                          if raw.get(k))
        ann_dt = (raw.get("an_dt") or raw.get("sort_date") or raw.get("dt")
                  or raw.get("exchdisstime") or "")
        ann_id = raw.get("seq_id") or raw.get("attchmntFile") or f"{symbol}|{ann_dt}|{hash(text) & 0xffffff}"
        age = 999999
        IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
        now_ist = dt.datetime.now(dt.timezone.utc).astimezone(IST).replace(tzinfo=None)
        for fmt in ("%d-%b-%Y %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%d-%m-%Y %H:%M:%S", "%d-%b-%Y %H:%M"):
            try:
                t = dt.datetime.strptime(ann_dt.strip(), fmt)
                age = (now_ist - t).total_seconds()
                if -120 <= age < 0:   # tiny clock skew -> treat as just-now
                    age = 0
                break
            except Exception:
                continue
        attach = raw.get("attchmntFile") or ""
        return {"symbol": symbol, "text": text or "", "ann_id": str(ann_id),
                "age_sec": age, "attach": attach}


# ----------------------------------------------------------------------------- #
#  CLASSIFIER  — RULES ONLY. No Gemini, no LLM, no network. Microseconds, ₹0.    #
# ----------------------------------------------------------------------------- #
class Classifier:
    CATS = {
        # specific / pharma catalysts checked FIRST so they win over generic ORDER_WIN
        "USFDA":          ["usfda", "us fda", "u.s. fda", "establishment inspection",
                           "anda approval", "anda for", "abbreviated new drug",
                           "fda approval", "fda clearance", "zero observation",
                           "clears usfda", "drug approval", "tentative approval",
                           "510(k)", "received approval from fda"],
        "MnA":            ["acquire", "acquisition", "controlling stake", "open offer",
                           "stake purchase", "merger", "amalgamation", "to buy stake"],
        "PROMOTER_RAISE": ["convertible warrant", "warrants to promoter",
                           "promoter infusion", "preferential allotment to promoter"],
        "QIP_RAISE":      ["qip", "qualified institutional placement", "fund rais",
                           "fundrais", "raise up to", "preferential issue",
                           "preferential allotment"],
        # ORDER_WIN LAST + tightened: needs order/contract NEXT TO an action word,
        # so boilerplate like "in order to ensure" no longer false-matches.
        "ORDER_WIN":      ["bags order", "bagged order", "bagging", "receives order",
                           "receiving of order", "receipt of order", "secures order",
                           "wins order", "won order", "new order", "export order",
                           "supply order", "work order", "purchase order", "order worth",
                           "order valued", "order from", "order book", "letter of award",
                           "letter of intent", "awarded contract", "wins contract",
                           "secures contract", "bags contract", "received order"],
        "BUYBACK":       ["buy back", "buyback", "buy-back", "buyback of equity",
                         "approved buy back", "approves buyback", "repurchase of shares",
                         "buy-back of equity shares", "buyback of shares"],
        "BONUS":         ["bonus issue", "bonus share", "issue of bonus", "bonus shares in the ratio"],
        "SPLIT":         ["stock split", "sub-division of shares", "subdivision of shares",
                          "split of equity shares", "face value split"],
    }
    # category base weight (0-1)
    WEIGHT = {"USFDA": 1.0, "ORDER_WIN": 0.9, "MnA": 0.95, "BUYBACK": 0.92, "BONUS": 0.85, "SPLIT": 0.78,
              "PROMOTER_RAISE": 0.85, "QIP_RAISE": 0.7}

    # negation / disqualifiers — block bullish read, may trigger EXIT of held name
    NEGATION = ["cancel", "cancelled", "terminat", "withdraw", "withdrawn",
                "order dispute", "rejected by", "lapsed", "scrapped", "called off",
                "fails to receive", "loses order", "downgrade"]

    VALUE_RE = re.compile(
        r"(?:₹|rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)\s*(crores?|cr\b|billion|bn|lakhs?)", re.I)

    @classmethod
    def has_negation(cls, text):
        t = text.lower()
        for n in cls.NEGATION:
            idx = t.find(n)
            if idx == -1:
                continue
            pre = t[max(0, idx - 8):idx].strip()
            if pre.endswith(("not", "no", "n't", "without", "denies")):
                continue   # double-negative e.g. "not cancelled" -> ignore
            return True
        return False

    SURVEILLANCE = ["significant increase in volume", "in order to ensure that",
                    "graded surveillance", "asm framework", "gsm stage",
                    "price band", "surveillance measure", "circuit filter revision"]


    _GENAI_CLIENT = None
    @classmethod
    def _gemini_verdict(cls, symbol, headline, body):
        """Stage 2: one Gemini call on a pre-gated survivor. Fail-safe: returns
        (False, 0.0, '') on ANY error so a broken call can never cause a trade."""
        if not CFG.LLM_ENABLED:
            return True, 1.0, "llm-disabled-passthrough"
        try:
            import os, json
            from google import genai
            from google.genai import types as genai_types
            if cls._GENAI_CLIENT is None:
                key = os.environ.get(CFG.GEMINI_API_KEY_ENV, "")
                if not key:
                    return False, 0.0, "no-api-key"
                cls._GENAI_CLIENT = genai.Client(api_key=key)
            prompt = (
                "You are an Indian equity catalyst analyst. Read this NSE filing and judge "
                "if it is an UNAMBIGUOUSLY BULLISH, price-moving catalyst for the company's stock "
                "TODAY. A shareholding/takeover DISCLOSURE, an investor-meet notice, a routine "
                "credit-rating reaffirmation, or a promoter/PE SELLING stake is NOT bullish. "
                "A genuine new order win, USFDA approval, rating UPGRADE, or fund RAISE that "
                "the company RECEIVES is bullish. Respond ONLY as JSON:\n"
                '{"bullish":bool,"direction":"positive|negative|neutral",'
                '"catalyst_type":str,"confidence":float_0_to_1,"reason":str}\n\n'
                f"SYMBOL: {symbol}\nHEADLINE: {headline}\nBODY: {body[:6000]}"
            )
            text = ""
            for attempt in range(CFG.LLM_MAX_RETRIES + 1):
                try:
                    resp = cls._GENAI_CLIENT.models.generate_content(
                        model=CFG.LLM_MODEL,
                        contents=prompt,
                        config=genai_types.GenerateContentConfig(
                            temperature=0.2,
                            max_output_tokens=600,
                            response_mime_type="application/json",
                            thinking_config=genai_types.ThinkingConfig(thinking_budget=0),
                        ),
                    )
                    text = (resp.text or "").strip()
                    if text:
                        break
                except Exception:
                    continue
            if not text:
                return False, 0.0, "empty-response"
            # strip fences if any
            for p in ("```json", "```JSON", "```"):
                if text.startswith(p):
                    text = text[len(p):].lstrip("\n").lstrip()
            if text.endswith("```"):
                text = text[:-3].rstrip()
            d = json.loads(text)
            bullish = bool(d.get("bullish")) and d.get("direction") == "positive"
            conf = float(d.get("confidence") or 0.0)
            return bullish, conf, str(d.get("reason", ""))[:160]
        except Exception as e:
            cls._write_err(f"_gemini_verdict {symbol}: {e}") if hasattr(cls, "_write_err") else None
            return False, 0.0, f"error:{type(e).__name__}"

    @classmethod
    def classify(cls, text):
        """Return (category|None, value_cr|None). Bullish, unambiguous only."""
        t = text.lower()
        # STAGE 1 SAST FILTER: takeover-disclosure filings are NOT bullish catalysts
        _SAST_SKIP = ("takeover regulation", "sebi (sast)", "regulation 29",
                      "regulation 31", "disclosure under sebi (substantial")
        if any(s in t for s in _SAST_SKIP):
            return None, None
        if cls.has_negation(t):
            return None, None
        if any(sv in t for sv in cls.SURVEILLANCE):   # exchange boilerplate, not a catalyst
            return None, None
        for cat, kws in cls.CATS.items():
            if any(kw in t for kw in kws):
                return cat, cls.extract_value_cr(text)
        return None, None

    _PDF_CACHE = {}   # ann_id -> value_cr (None if no value found); avoids re-fetch

    @classmethod
    def value_from_attachment(cls, url, ann_id):
        """Download the filing PDF (once) and pull a value. Fail-safe: returns None on any error."""
        if not url:
            return None
        if ann_id in cls._PDF_CACHE:
            return cls._PDF_CACHE[ann_id]
        val = None
        try:
            import requests, io, PyPDF2
            hdrs = {"User-Agent": "Mozilla/5.0", "Referer": "https://www.nseindia.com/"}
            resp = requests.get(url, headers=hdrs, timeout=6)   # hard timeout
            if resp.status_code == 200 and resp.content[:4] == b"%PDF":
                reader = PyPDF2.PdfReader(io.BytesIO(resp.content))
                pages = reader.pages[:5]   # first 5 pages is plenty for a filing
                full = " ".join((pg.extract_text() or "") for pg in pages)
                val = cls.extract_value_cr(full)
        except Exception:
            val = None   # never hang or crash the loop on a bad PDF
        cls._PDF_CACHE[ann_id] = val
        return val


    _PDF_TEXT_CACHE = {}
    _BOILERPLATE = ("disclosure under sebi takeover", "investor meet", "con. call",
                    "general update", "trading window", "newspaper", "duplicate share")
    @classmethod
    def text_from_attachment(cls, url, key):
        """Fetch filing PDF once, return first-5-page text. Fail-safe: '' on any error."""
        if not url:
            return ""
        if key in cls._PDF_TEXT_CACHE:
            return cls._PDF_TEXT_CACHE[key]
        txt = ""
        try:
            import requests, io, PyPDF2
            hdrs = {"User-Agent": "Mozilla/5.0", "Referer": "https://www.nseindia.com/"}
            resp = requests.get(url, headers=hdrs, timeout=6)
            if resp.status_code == 200 and resp.content[:4] == b"%PDF":
                reader = PyPDF2.PdfReader(io.BytesIO(resp.content))
                txt = " ".join((pg.extract_text() or "") for pg in reader.pages[:5])
        except Exception:
            txt = ""
        cls._PDF_TEXT_CACHE[key] = txt
        return txt

    @classmethod
    def extract_value_cr(cls, text):
        m = cls.VALUE_RE.search(text)
        if not m:
            return None
        num = float(m.group(1).replace(",", ""))
        unit = m.group(2).lower()
        if unit.startswith("b") or unit == "bn":
            return num * 100.0          # 1 billion = 100 crore
        if unit.startswith("lakh"):
            return num / 100.0          # 1 lakh = 0.01 crore
        return num                      # crore

    @classmethod
    def score(cls, category, value_cr, market_cap, age_sec, is_promoter):
        """0-100. Magnitude law: value/mcap. Promoter infusion gets a floor."""
        base = cls.WEIGHT.get(category, 0.5) * 60.0          # up to 60 from category
        mag = 0.0
        if value_cr and market_cap:
            ratio = (value_cr * 1e7) / market_cap            # crore -> rupees
            mag = min(ratio / CFG.VALUE_MCAP_MIN, 3.0) * 12.0  # up to ~36
        elif category in ("BUYBACK","BONUS","SPLIT","USFDA"):
            mag = 20.0   # strong catalysts that carry no rupee value in the headline
        elif is_promoter:
            mag = 25.0                                       # promoter raise w/o clean value
        fresh = 4.0 if age_sec <= CFG.FRESHNESS_SEC else 0.0
        return round(min(base + mag + fresh, 100.0), 1)


# ----------------------------------------------------------------------------- #
#  UNIVERSE  — reuse Hunter's liquid list; gate on mcap + volume                 #
# ----------------------------------------------------------------------------- #
class Universe:
    def __init__(self):
        self.names = set()
        try:
            import csv as _csv
            with open(CFG.UNIVERSE_FILE) as _f:
                rows = list(_csv.reader(_f))
            # take the first column of each row; skip a header if present
            self.names = {r[0].strip().upper() for r in rows if r and r[0].strip()}
            self.names.discard("SYMBOL"); self.names.discard("TRADINGSYMBOL")
            info(f"Universe loaded: {len(self.names)} names from CSV")
        except Exception as e:
            warn(f"Universe file not found ({e}) — falling back to mcap/volume gate only")

    def allowed(self, symbol):
        return (not self.names) or (symbol in self.names)


# ----------------------------------------------------------------------------- #
#  RAVEN  — orchestrator: scan -> classify -> gate -> enter ; and manage exits   #
# ----------------------------------------------------------------------------- #
class Raven:
    def __init__(self):
        self.tg     = Telegram()
        self.kite   = KiteAdapter()
        self.led    = Ledger()
        self.uni    = Universe()
        self.feed   = None  # lazy (probe/scan only)
        self.seen   = set(self._load_seen())

    def _load_seen(self):
        try:
            return json.loads(CFG.SEEN_FILE.read_text())
        except Exception:
            return []

    def _save_seen(self):
        # keep last 5000 ids to bound the file
        ids = list(self.seen)[-5000:]
        Path(CFG.SEEN_FILE).write_text(json.dumps(ids))

    def _market_ok(self):
        chg = self.kite.nifty_intraday_change()
        if chg is not None and chg <= -CFG.CRASH_NIFTY_DROP:
            warn(f"KILL SWITCH: Nifty {chg*100:.1f}% — standing down")
            return False
        return True

    def _emit_signal(self, sig):
        """Optional bridge: append scored signal for decision_brain/JR to consume."""
        try:
            existing = []
            if CFG.SIGNAL_INBOX.exists():
                existing = json.loads(CFG.SIGNAL_INBOX.read_text())
            existing.append(sig)
            CFG.SIGNAL_INBOX.write_text(json.dumps(existing[-500:], indent=2))
        except Exception as e:
            warn(f"signal inbox write failed: {e}")

    # ---------- ENTRY PIPELINE ----------
    def scan_once(self):
        if self.feed is None:
            self.feed = NSEFeed()
        # --- one-shot test inject: drop raven/inject.json to feed the live loop a single filing ---
        try:
            import os, json as _json
            _ij = os.path.join(os.path.dirname(__file__), 'inject.json')
            if os.path.exists(_ij):
                _a = _json.loads(open(_ij).read()); os.remove(_ij)
                info(f"INJECT: processing test filing {_a.get('symbol')}")
                _cat,_val = Classifier.classify(_a.get('text',''))
                info(f"INJECT: classified cat={_cat}")
                if _cat: self._evaluate(_a, _cat, _val)
        except Exception as _e:
            warn(f"INJECT failed: {_e}")
        self.led.roll_day()
        if not self._market_ok():
            return
        for raw in self.feed.fetch():
            a = NSEFeed.parse(raw)
            if not a["symbol"] or a["ann_id"] in self.seen:
                continue
            self.seen.add(a["ann_id"])

            # thesis-invalidation: denial on a name we HOLD -> force exit
            if a["symbol"] in self.led.positions and Classifier.has_negation(a["text"]):
                warn(f"{a['symbol']}: negative filing on held position -> exiting")
                self._exit(a["symbol"], reason="thesis_invalidation")
                continue

            head = a.get("text") or a.get("attchmntText") or a.get("desc") or ""
            cat, val = Classifier.classify(head)
            if not cat:
                # headline missed -> read PDF body once (skip pure boilerplate to spare NSE)
                hl = head.lower()
                if not any(b in hl for b in Classifier._BOILERPLATE):
                    body = Classifier.text_from_attachment(a.get("attchmntFile", ""),
                                                           a.get("seq_id") or a.get("ann_id"))
                    if body:
                        cat, val = Classifier.classify(head + " " + body)
            if not cat:
                continue
            self._evaluate(a, cat, val)
        self._save_seen()

    def _evaluate(self, a, cat, val):
        sym = a["symbol"]
        if not self.uni.allowed(sym):
            return
        if sym in self.led.positions:
            return  # one position per symbol
        if a["age_sec"] > CFG.FRESHNESS_SEC:
            return  # stale (intraday); pre-open/eod sweeps use their own path

        snap = self.kite.snapshot(sym)
        if not snap:
            return
        ltp, upper, vol, prevc = snap["ltp"], snap["upper"], snap["volume"], snap["prev_close"]

        # liquidity + circuit-band gates
        if vol < CFG.MIN_AVG_VOLUME:
            return
        band = (upper - prevc) / prevc if prevc else 0
        if band < CFG.MIN_CIRCUIT_BAND - 0.005:   # tolerance: exact 10% bands compute to 0.09998 via float; don't reject them
            return  # 2-5% band: no room, locks instantly
        if ltp > upper * CFG.ENTRY_HEADROOM:
            return  # already kissing the lock -> can't get a fill

        market_cap = self._market_cap(sym, ltp)
        if market_cap and market_cap < CFG.MIN_MARKET_CAP:
            return

        is_promoter = cat == "PROMOTER_RAISE" or "promoter" in a["text"].lower()
        # PDF value-recovery: catalyst classified but snippet had no value -> read the attachment.
        # Runs only here, after liquidity/band/headroom gates already passed = few PDFs/day.
        if val is None and cat in ("ORDER_WIN", "MnA", "QIP_RAISE", "PROMOTER_RAISE"):
            val = Classifier.value_from_attachment(a.get("attchmntFile", ""), a["ann_id"])
            if val:
                info(f"{sym}: value recovered from PDF -> Rs.{val}cr")
        if cat == "ORDER_WIN":
            if not (market_cap and val):
                return
            if (val * 1e7) / market_cap < CFG.VALUE_MCAP_MIN:
                return
        if cat == "PROMOTER_RAISE" and market_cap and market_cap > CFG.PROMOTER_MCAP_MAX:
            return

        score = Classifier.score(cat, val, market_cap, a["age_sec"], is_promoter)
        if score < CFG.MIN_SCORE:
            return
        # STAGE 2: Gemini reads the survivor and gives the final bullish/bearish verdict.
        body = a.get("_pdf_text") or a.get("text") or a.get("attchmntText") or ""
        bullish, conf, reason = Classifier._gemini_verdict(sym, a.get("text",""), body)
        info(f"{sym}: gemini bullish={bullish} conf={conf:.2f} :: {reason}")
        if not (bullish and conf >= CFG.LLM_MIN_CONF):
            return  # Gemini says not an unambiguous bullish catalyst -> skip

        self._enter(sym, ltp, {"category": cat, "value_cr": val,
                               "score": score, "ann_id": a["ann_id"]})

    _MCAP_CACHE = None  # class-level: {SYMBOL: market_cap_in_rupees}

    @classmethod
    def _load_mcap(cls):
        if cls._MCAP_CACHE is not None:
            return cls._MCAP_CACHE
        cls._MCAP_CACHE = {}
        try:
            import csv as _csv
            with open(CFG.TRENDLYNE_CSV, encoding="utf-8", errors="ignore") as _f:
                rdr = _csv.DictReader(_f)
                for row in rdr:
                    sym = (row.get("Symbol") or "").strip().upper()
                    raw = (row.get("MarketCap") or "").replace(",", "").strip()
                    if sym and raw:
                        try:
                            cls._MCAP_CACHE[sym] = float(raw) * 1e7  # ₹cr -> rupees
                        except ValueError:
                            pass
            info(f"Trendlyne mcap loaded: {len(cls._MCAP_CACHE)} symbols")
        except Exception as e:
            warn(f"Trendlyne mcap load failed: {e}")
        return cls._MCAP_CACHE

    def _market_cap(self, symbol, ltp):
        return self._load_mcap().get(symbol.strip().upper())

    def _enter(self, symbol, price, meta):
        cost_per = CFG.BOOK * CFG.POSITION_PCT
        qty = int(cost_per / price)
        if qty <= 0:
            return
        ok, why = self.led.can_enter(qty * price)
        if not ok:
            warn(f"{symbol}: entry rejected — {why}")
            return
        fill = self.kite.place_paper_or_block(symbol, qty, price, "BUY")
        self.led.open_position(symbol, qty, price, meta)
        msg = (f"ENTRY  {symbol}  x{qty} @ ₹{price:.2f}\n"
               f"why: {meta['category']} "
               f"{('₹'+str(meta['value_cr'])+'cr ') if meta.get('value_cr') else ''}"
               f"score {meta['score']}\n"
               f"stop ₹{price*(1-CFG.STOP_PCT):.2f}  target ₹{price*(1+CFG.TARGET_PCT):.2f}  [PAPER]")
        info(msg.replace("\n", " | "))
        self.tg.send(msg)
        self._emit_signal({"lane": "RAVEN", "symbol": symbol, "action": "BUY",
                           "score": meta["score"], "category": meta["category"],
                           "ts": fill["ts"]})

    # ---------- EXIT PIPELINE ----------
    def manage(self):
        self.led.roll_day()
        for symbol in list(self.led.positions.keys()):
            p = self.led.positions[symbol]
            snap = self.kite.snapshot(symbol)
            if not snap:
                continue
            ltp = snap["ltp"]
            p["peak_price"] = max(p.get("peak_price", ltp), ltp)

            # 1) hard stop / breakeven stop
            if ltp <= p["stop_price"]:
                self._exit(symbol, reason="stop_hit", price=ltp)
                continue
            # 2) first target -> book partial, move stop to breakeven
            if (not p["partial_done"]) and ltp >= p["target_price"]:
                qty = max(1, int(p["qty"] * CFG.PARTIAL_FRACTION))
                pnl = self.led.reduce_position(symbol, qty, ltp)
                m = f"PARTIAL {symbol} x{qty} @ ₹{ltp:.2f}  pnl ₹{pnl:.0f}  (stop->breakeven) [PAPER]"
                info(m); self.tg.send(m)
                continue
            # 3) trail the runner after partial
            if p["partial_done"] and ltp <= p["peak_price"] * (1 - CFG.TRAIL_PCT):
                self._exit(symbol, reason="trail", price=ltp)
                continue
            # 4) time-stop
            _IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
            _now_ist = dt.datetime.now(_IST).replace(tzinfo=None)
            held = (_now_ist - dt.datetime.fromisoformat(p["entry_time"])).days
            if held >= CFG.MAX_HOLD_DAYS:
                self._exit(symbol, reason="time_stop", price=ltp)
                continue
        self.led.save()

    def _exit(self, symbol, reason, price=None):
        p = self.led.positions.get(symbol)
        if not p:
            return
        if price is None:
            snap = self.kite.snapshot(symbol)
            price = snap["ltp"] if snap else p["entry_price"]
        qty = p["qty"]
        self.kite.place_paper_or_block(symbol, qty, price, "SELL")
        pnl = self.led.reduce_position(symbol, qty, price)
        m = f"EXIT   {symbol} x{qty} @ ₹{price:.2f}  pnl ₹{pnl:.0f}  ({reason}) [PAPER]"
        info(m); self.tg.send(m)
        self._emit_signal({"lane": "RAVEN", "symbol": symbol, "action": "SELL",
                           "reason": reason, "ts": dt.datetime.now().isoformat()})

    # ---------- REPORTING ----------
    def status(self):
        s = self.led.state
        eq_note = f"cash ₹{s['cash']:.0f}  realized ₹{s['realized_pnl']:.0f}  open {len(self.led.positions)}"
        info(f"LEDGER: {eq_note}  entries_today {s['entries_today']}")
        for sym, p in self.led.positions.items():
            info(f"  {sym}: x{p['qty']} @ ₹{p['entry_price']:.2f}  {p['category']} score {p['score']}")
        return eq_note


# ----------------------------------------------------------------------------- #
#  PROBE MODE  — validate the live NSE schema BEFORE trusting the parser         #
# ----------------------------------------------------------------------------- #
def probe():
    info("PROBE: fetching raw NSE announcements (validate field names below)")
    feed = NSEFeed()
    raw = feed.fetch()
    info(f"PROBE: {len(raw)} items returned")
    for r in raw[:5]:
        info(f"RAW KEYS: {list(r.keys())}")
        parsed = NSEFeed.parse(r)
        cat, val = Classifier.classify(parsed["text"])
        info(f"PARSED: sym={parsed['symbol']} age={parsed['age_sec']:.0f}s "
             f"cat={cat} val_cr={val} text={parsed['text'][:120]!r}")


# ----------------------------------------------------------------------------- #
#  MAIN                                                                          #
# ----------------------------------------------------------------------------- #

def _market_is_open():
    """NSE cash session gate (Mon-Fri 09:15-15:30 IST). Pauses the intraday loop
    off-hours so RAVEN stops polling Kite overnight (the 'quote failed' spam +
    watchdog false alarms)."""
    _IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
    _n = dt.datetime.now(_IST)
    if _n.weekday() >= 5:
        return False
    return dt.time(9, 15) <= _n.time() <= dt.time(15, 30)


def main():
    ap = argparse.ArgumentParser(description="RAVEN news-catalyst engine (paper)")
    ap.add_argument("--probe",    action="store_true", help="dump raw NSE feed + parse")
    ap.add_argument("--intraday", action="store_true", help="main scan loop (default)")
    ap.add_argument("--preopen",  action="store_true", help="08:45 overnight-filing sweep")
    ap.add_argument("--eod",      action="store_true", help="15:35 sweep")
    ap.add_argument("--manage",   action="store_true", help="exit manager (run on timer)")
    ap.add_argument("--status",   action="store_true", help="print ledger + positions")
    args = ap.parse_args()

    # load .env if python-dotenv is available (never hardcode secrets)
    try:
        from dotenv import load_dotenv
        load_dotenv("/home/globalbot/.env")
    except Exception:
        pass

    if args.probe:
        probe(); return

    r = Raven()
    if args.status:
        r.status(); return
    if args.manage:
        r.manage(); return
    if args.preopen or args.eod:
        # sweep: same pipeline but freshness window relaxed for overnight filings
        old = CFG.FRESHNESS_SEC
        CFG.FRESHNESS_SEC = 18 * 3600   # accept filings up to ~18h old for the gap watchlist
        r.scan_once()
        CFG.FRESHNESS_SEC = old
        r.status()
        return

    # default: intraday scan loop
    info(f"RAVEN intraday loop start  (PAPER_MODE={CFG.PAPER_MODE}, book ₹{CFG.BOOK:.0f})")
    r.tg.send(f"RAVEN online — intraday scan every {CFG.SCAN_INTERVAL_SEC}s  [PAPER ₹{CFG.BOOK:.0f}]")
    _hb = {"cycles": 0, "last": time.time()}
    while True:
        try:
            if not _market_is_open():
                time.sleep(300)   # NSE closed: skip polling Kite
                continue
            r.scan_once()
            r.manage()
            _hb["cycles"] += 1
            if time.time() - _hb["last"] >= 300:   # heartbeat every 5 min
                info(f"heartbeat: {_hb['cycles']} scan cycles, "
                     f"{len(r.led.positions)} open, cash Rs.{r.led.state['cash']:.0f}")
                _hb["cycles"] = 0; _hb["last"] = time.time()
        except Exception as e:
            err(f"loop error: {e}")
        time.sleep(CFG.SCAN_INTERVAL_SEC)


if __name__ == "__main__":
    main()


