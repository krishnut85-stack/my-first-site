#!/usr/bin/env python3
"""
GIR v26.0 — Autonomous NSE Trader
Owner: <redacted> | Kite: <redacted> | Server: <server-ip> (BLR1)

Architecture:
  EquityModule — CNC delivery, news-driven, RSI+Volume+ATR confirmation
  FnoModule    — NFO NRML, news-driven CE/PE, 218 F&O stocks, DTE cascade

Rules:
  - ZERO paper trading. Every order is real Kite or nothing.
  - Equity and F&O are completely independent. No shared candidates/filters.
  - Only shared: Kite access token + Telegram bot token.
  - GTT: ALWAYS check get_gtts() before placing. Modify if exists.
  - SL only moves UP, never down. Must be BELOW current LTP always.
  - F&O has NO equity-style regime filter.

Deploy:
  scp gir.py root@<server-ip>:/home/globalbot/gir.py
  systemctl restart globaleye
"""

VERSION = "GIR v28.0"

# ═══════════════════════════════════════════════════════════════════════════════
#  V28 CHANGES (Apr 18, 2026) — applied after comprehensive senior review
# ═══════════════════════════════════════════════════════════════════════════════
#  A1  Equity _can_enter checks Kite holdings (not stale local JSON)
#  A2  AMO scan runs ONCE per evening (20:00 IST) + checks Kite holdings
#  A4  KITE_API_KEY fallback removed (must come from .env)
#  A5  GTT modify failure returns None (not fake success gtt_id)
#  A7  Duplicate order check uses exact match (not .startswith)
#  A8  Bare except: replaced with except Exception: (4 locations)
#  A10 EQUITY REGIME FILTER: block bullish buys when market is falling AND stock
#      not outperforming, block chasing when stock already ran >3% today
#  C3  Freak trade protection (reject LTP >20% from prev close)
#  C10 Edge-weighted position sizing (score/60 multiplier, cap 3% risk)
#  D1  EQ_MAX_POS 10 -> 5 (concentrate into quality positions)
#  D3  Catalyst-based dead money exit (BUYBACK=60d, ORDER_WIN=30d, etc.)
#  D4  Smart FNO_CAP sizing: respect lot-cost constraint (was fixed 0.95)
#  D5  Two-stage F&O trail: 10-25% profit = 30% trail, 25%+ = 20% trail
#  D7  Capital utilization via pressing winners (add to existing winners if idle > 15%)
#
#  NOT applied (require backtest validation first):
#  A9  Kelly fraction (kept at 0.80 pending backtest)
#  D2  ATR-based trail (kept at fixed 2.5% pending backtest)
# ═══════════════════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════════════════
#  IMPORTS
# ═══════════════════════════════════════════════════════════════════════════════

import os
import sys
import json
import time
import math
import hashlib
import logging
import threading
import traceback
from datetime import datetime, timedelta, date, timezone
from collections import defaultdict
from pathlib import Path

import requests
import pyotp

try:
    from kiteconnect import KiteConnect
except ImportError:
    print("FATAL: pip install kiteconnect")
    sys.exit(1)

# V27 Stage 2: import NewsBrain (LLM news analyzer)
try:
    from news_brain import NewsBrain
    _NEWS_BRAIN_AVAILABLE = True
except ImportError as _nbe:
    NewsBrain = None
    _NEWS_BRAIN_AVAILABLE = False
    print(f"WARNING: news_brain.py not importable: {_nbe} - LLM mode disabled")

try:
    import feedparser
except ImportError:
    print("FATAL: pip install feedparser")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("GIR")

# ═══════════════════════════════════════════════════════════════════════════════
#  CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

DATA_DIR = Path("/home/globalbot/data")
DATA_DIR.mkdir(parents=True, exist_ok=True)

# ── Kite credentials ──
# V28 A4: KITE_API_KEY must come from .env (no hardcoded fallback)
KITE_API_KEY = os.getenv("KITE_API_KEY", "")
KITE_API_SECRET = os.getenv("KITE_API_SECRET", "")
KITE_TOTP_SECRET = os.getenv("KITE_TOTP_SECRET", "")
ZERODHA_USER_ID = os.getenv("ZERODHA_USER_ID", "")
ZERODHA_PASSWORD = os.getenv("ZERODHA_PASSWORD", "")
KITE_TOKEN_FILE = DATA_DIR / "kite_token.json"

# ── Telegram ──
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

# ── Capital wall ──
EQUITY_PCT = 0.75
FNO_PCT = 0.25

# ── Equity config ──
EQ_MAX_POS = 5                  # V28 D1: concentrate capital (was 10)
EQ_MAX_PER_SECTOR = 2
EQ_RISK_PER_TRADE = 0.02
EQ_INITIAL_SL_PCT = 0.025       # 2.5% initial SL
EQ_TRAIL_SL_PCT = 0.025         # 2.5% trailing (avoids whipsaw on gap days)
EQ_DEAD_MONEY_DAYS = 15
EQ_KELLY_FRACTION = 0.80
EQ_MIN_CONFIDENCE = 42
EQ_T2_ATR_MULT = 14             # Target 2 = 14 x ATR (from v9.1 backtest)
EQ_PROFIT_LOCK_MIN = 15         # Minutes after entry before profit lock
EQ_SCAN_INTERVAL_MIN = 30       # Scan every 30 minutes

# ── F&O config ──
FNO_MAX_POS = 5
FNO_MAX_PER_STOCK = 1
FNO_MAX_PER_SECTOR = 2          # PATCH_V3_SECTOR_CAP: max 2 F&O positions per sector
FNO_VIX_MAX = 22.0              # PATCH_V4_VIX_FILTER: block F&O entries when India VIX > 22

# ── OI tracking (PATCH_V5_OI_LOGGER) ──
OI_SNAPSHOT_INTERVAL_MIN = 60   # Snapshot every 60 minutes during market hours
OI_RETENTION_DAYS = 14          # Keep 14 days of snapshots, auto-delete older
OI_STRIKES_RANGE = 5            # ATM +/- 5 strikes per option type
OI_BUILDUP_MIN_PCT = 15.0       # Minimum % OI change to trigger buildup signal
OI_SIGNAL_MIN_SCORE = 65        # Minimum score for OI signal to enter pipeline
OI_INDICES = ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"]

# ── Gap detection (PATCH_V6_GAP) ──
GAP_INDEX_THRESHOLD = 0.5       # Index gap threshold: 0.5%
GAP_STOCK_THRESHOLD = 1.0       # Stock gap threshold: 1.0%
GAP_SCORE_BOOST = 10            # Score boost for aligned signals

# ── Sectoral rotation (PATCH_V8_SECTOR_ROTATION) ──
SECTOR_ROTATION_REFRESH_MIN = 15    # Refresh sector ranking every 15 minutes
SECTOR_ROTATION_TOP_BOOST = 10      # Score boost for stocks in top-3 sectors
SECTOR_ROTATION_BOTTOM_BLOCK = True # Block entries for stocks in bottom-2 sectors
SECTOR_INDICES_MAP = {
    "BANKING": "NSE:NIFTY BANK",
    "IT": "NSE:NIFTY IT",
    "PHARMA": "NSE:NIFTY PHARMA",
    "FMCG": "NSE:NIFTY FMCG",
    "AUTO": "NSE:NIFTY AUTO",
    "METALS": "NSE:NIFTY METAL",
    "ENERGY": "NSE:NIFTY ENERGY",
    "REALTY": "NSE:NIFTY REALTY",
    "SERVICES": "NSE:NIFTY FIN SERVICE",
}
FNO_CAP_PER_TRADE = 0.95        # 30% of F&O capital per trade
FNO_SL_PCT = 0.30               # 30% SL on premium
FNO_TRAIL_ACTIVATE = 0.10     # V27 PATCH (Bug #10): trail only after 10% profit captured
FNO_TRAIL_PCT = 0.20          # 20% below LTP
FNO_TRAIL_DRY_RUN = False

# V27 Stage 2: LLM news brain integration (dry-run = log only, no trades)
USE_LLM_NEWS = True
LLM_DRY_RUN = True  # True = LLM logs decisions only (no trades). False = LLM candidates added to live trade list
FNO_MIN_DTE = 10  # PATCH_V28_OPTION_PICKER: was 15. Opens April expiry (DTE~12) but keeps 10-day floor to protect exit liquidity (bid-ask widens <DTE 7)
FNO_MAX_DTE = 45  # PATCH_V28_OPTION_PICKER: was 28. Opens May expiry (DTE~40) for longer-hold catalyst plays
FNO_EMERGENCY_DTE = 12          # Emergency exit
FNO_DTE_CUT_LOSERS = 15         # Cut losers at DTE <= 15
FNO_DTE_WARN = 20               # Warning at DTE <= 20
FNO_MIN_OI = 50000
FNO_MAX_SPREAD = 0.05           # 5% max bid-ask spread
FNO_MIN_CATALYST = 60           # PATCH_V28_SECTOR_LOG: sector over-cap logs demoted to DEBUG           # Minimum catalyst score
FNO_SCAN_INTERVAL_MIN = 15      # Scan every 15 minutes

# ── Risk ──
CRASH_NIFTY_DROP = 0.05         # Block if Nifty drops > 5% intraday
MONTHLY_LOSS_LIMIT = 0.09       # 9% monthly
DAILY_LOSS_AVG_LIMIT = 0.05     # 5% average loss (not cumulative)

# ── Blacklist ──
BLACKLIST = {"AQYLON"}
BLOCKED_PREFIXES = ["GS20", "GS19", "GSEC", "AFIL", "SSCL", "SDL", "TBILL", "SGBOND"]
BLOCKED_SUFFIXES = ["-SM", "-ST", "-BE", "-BZ", "-IL", "-BL"]

# ── NSE holidays 2026 ──
NSE_HOLIDAYS = {
    date(2026, 1, 26), date(2026, 3, 10), date(2026, 3, 30), date(2026, 3, 31),
    date(2026, 4, 14), date(2026, 5, 1), date(2026, 7, 17), date(2026, 8, 15),
    date(2026, 8, 17), date(2026, 10, 2), date(2026, 10, 20), date(2026, 10, 21),
    date(2026, 11, 5), date(2026, 11, 18), date(2026, 12, 25),
}

# ── RSS feeds (Indian financial news only, no Yahoo US garbage) ──
NEWS_FEEDS = {
    "ET Markets": "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms",
    "ET Corporate": "https://economictimes.indiatimes.com/industry/rssfeeds/13352306.cms",
    "MC Markets": "https://www.moneycontrol.com/rss/marketreports.xml",
    "MC Business": "https://www.moneycontrol.com/rss/business.xml",
    "BS Markets": "https://www.business-standard.com/rss/markets-106.rss",
    "Mint Markets": "https://www.livemint.com/rss/markets",
    "Mint Companies": "https://www.livemint.com/rss/companies",
    "FE Market": "https://www.financialexpress.com/market/feed/",
    "NDTV Profit": "https://www.ndtv.com/business/feeds",
    "CNBC TV18 Market": "https://www.cnbctv18.com/rss/market.xml",
    "CNBC TV18 Companies": "https://www.cnbctv18.com/rss/companies.xml",
    "ZeeBiz Markets": "https://www.zeebiz.com/rss/markets.xml",
    "ZeeBiz Stocks": "https://www.zeebiz.com/rss/stocks.xml",
    "BT Markets": "https://www.businesstoday.in/rss/markets",
    "RBI": "https://www.rbi.org.in/scripts/rss.aspx?id=2",
}

# ── News keywords for direction detection ──
BULLISH_KEYWORDS = [
    "buy rating", "upgrade", "outperform", "overweight", "top pick",
    "accumulate", "raises target", "target raised", "order win", "wins order",
    "record profit", "beats estimate", "above estimate", "strong results",
    "revenue growth", "profit growth", "expansion", "new plant", "capex",
    "buyback", "bonus issue", "stock split", "promoter buying", "promoter buy",
    "insider buying", "bulk deal buy", "block deal buy", "dividend declared",
    "fdi inflow", "rate cut", "rbi cut", "stimulus", "reform", "fii buying",
    "dii buying", "contract win", "deal win", "partnership", "collaboration",
    "acquisition", "merger positive", "stake increase", "credit upgrade",
    "new order", "capacity expansion", "margin improvement", "debt reduction",
    "breakthrough", "patent", "approval received", "clearance",
]

BEARISH_KEYWORDS = [
    "sell rating", "downgrade", "underperform", "underweight", "reduce",
    "cuts target", "target cut", "fraud", "scam", "penalty", "fine imposed",
    "loss widens", "misses estimate", "below estimate", "weak results",
    "revenue decline", "profit decline", "shutdown", "closure", "layoff",
    "promoter selling", "promoter sell", "insider selling", "bulk deal sell",
    "fii selling", "dii selling", "credit downgrade", "rating downgrade",
    "debt default", "npa", "bad loan", "sebi action", "ban", "suspension",
    "recall", "investigation", "raid", "probe", "stake decrease",
    "margin pressure", "cost overrun", "delay", "cancellation",
    "downgrade outlook", "negative outlook", "ofs", "qip dilution",
]

# ── Filing types and their signals ──
FILING_SIGNALS = {
    "BUYBACK":          {"direction": "BULLISH",  "score": 95},
    "PROMOTER_BUY":     {"direction": "BULLISH",  "score": 90},
    "ORDER_WIN":        {"direction": "BULLISH",  "score": 80},
    "DIVIDEND":         {"direction": "BULLISH",  "score": 70},
    "BONUS":            {"direction": "BULLISH",  "score": 75},
    "STOCK_SPLIT":      {"direction": "BULLISH",  "score": 70},
    "ACQUISITION":      {"direction": "BULLISH",  "score": 75},
    "EXPANSION":        {"direction": "BULLISH",  "score": 70},
    "RESULTS_BEAT":     {"direction": "BULLISH",  "score": 80},
    "PROMOTER_SELL":    {"direction": "BEARISH",  "score": 75},
    "QIP":              {"direction": "BEARISH",  "score": 60},
    "OFS":              {"direction": "BEARISH",  "score": 70},
    "CREDIT_DOWNGRADE": {"direction": "BEARISH",  "score": 85},
    "FRAUD":            {"direction": "BEARISH",  "score": 95},
    "RESULTS_MISS":     {"direction": "BEARISH",  "score": 80},
    "PENALTY":          {"direction": "BEARISH",  "score": 70},
}

# ── Sector pod config (for equity sector limits) ──
SECTOR_MAP = {
    "HDFCBANK": "BANKING", "ICICIBANK": "BANKING", "SBIN": "BANKING",
    "KOTAKBANK": "BANKING", "AXISBANK": "BANKING", "INDUSINDBK": "BANKING",
    "BANDHANBNK": "BANKING", "FEDERALBNK": "BANKING", "IDFCFIRSTB": "BANKING",
    "PNB": "BANKING", "BANKBARODA": "BANKING", "CANBK": "BANKING",
    "TCS": "IT", "INFY": "IT", "WIPRO": "IT", "HCLTECH": "IT",
    "TECHM": "IT", "LTIM": "IT", "MPHASIS": "IT", "COFORGE": "IT",
    "SUNPHARMA": "PHARMA", "DRREDDY": "PHARMA", "CIPLA": "PHARMA",
    "DIVISLAB": "PHARMA", "BIOCON": "PHARMA", "AUROPHARMA": "PHARMA",
    "HINDUNILVR": "FMCG", "ITC": "FMCG", "NESTLEIND": "FMCG",
    "BRITANNIA": "FMCG", "DABUR": "FMCG", "MARICO": "FMCG",
    "MARUTI": "AUTO", "TATAMOTORS": "AUTO", "M&M": "AUTO",
    "BAJAJ-AUTO": "AUTO", "HEROMOTOCO": "AUTO", "ASHOKLEY": "AUTO",
    "RELIANCE": "ENERGY", "ONGC": "ENERGY", "BPCL": "ENERGY",
    "IOC": "ENERGY", "GAIL": "ENERGY", "NTPC": "ENERGY",
    "TATASTEEL": "METALS", "JSWSTEEL": "METALS", "HINDALCO": "METALS",
    "COALINDIA": "METALS", "VEDL": "METALS", "NMDC": "METALS",
    "PIDILITIND": "CHEMICALS", "UPL": "CHEMICALS", "SRF": "CHEMICALS",
    "LT": "INFRA", "ADANIENT": "INFRA", "ADANIPORTS": "INFRA",
    "BHARTIARTL": "SERVICES", "BAJFINANCE": "SERVICES", "BAJAJFINSV": "SERVICES",
}


# ═══════════════════════════════════════════════════════════════════════════════
#  UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def now_ist():
    """Current time in IST."""
    return datetime.now(timezone(timedelta(hours=5, minutes=30)))


def today_ist():
    """Current date in IST."""
    return now_ist().date()


def is_trading_day(d=None):
    """Check if given date is an NSE trading day."""
    d = d or today_ist()
    if d.weekday() >= 5:  # Saturday/Sunday
        return False
    if d in NSE_HOLIDAYS:
        return False
    return True


def is_market_hours():
    """Check if NSE market is currently open (9:15 to 15:30 IST)."""
    if not is_trading_day():
        return False
    n = now_ist()
    market_open = n.replace(hour=9, minute=15, second=0, microsecond=0)
    market_close = n.replace(hour=15, minute=30, second=0, microsecond=0)
    return market_open <= n <= market_close


def is_amo_window():
    """Check if AMO orders can be placed (15:45-01:00 or 05:30-09:15)."""
    n = now_ist()
    h, m = n.hour, n.minute
    t = h * 60 + m
    # 15:45 to 23:59
    if t >= 945:
        return True
    # 00:00 to 01:00
    if t <= 60:
        return True
    # 05:30 to 09:14
    if 330 <= t <= 554:
        return True
    return False


def load_json(path, default=None):
    """Load JSON file, return default if missing/corrupt."""
    try:
        with open(path, "r") as f:
            return json.load(f)
    except Exception:
        return default if default is not None else {}


def save_json(path, data):
    """Save data to JSON file atomically."""
    tmp = str(path) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, default=str)
    os.replace(tmp, str(path))


def is_valid_symbol(sym):
    """Check if symbol is a valid equity stock (not bond, ETF, SME, etc)."""
    if not sym or not isinstance(sym, str):
        return False
    sym_upper = sym.upper()
    if sym_upper in BLACKLIST:
        return False
    # Numeric prefix = government security
    if sym_upper[0].isdigit():
        return False
    # Blocked prefixes
    for bp in BLOCKED_PREFIXES:
        if bp in sym_upper:
            return False
    # Blocked suffixes
    for bs in BLOCKED_SUFFIXES:
        if sym_upper.endswith(bs):
            return False
    # Special characters (bonds, series)
    if "%" in sym_upper:
        return False
    return True


def get_sector(symbol):
    """Get sector for a symbol, default SERVICES."""
    return SECTOR_MAP.get(symbol, "SERVICES")


# ═══════════════════════════════════════════════════════════════════════════════
#  KITE SESSION — One login, both modules use the token independently
# ═══════════════════════════════════════════════════════════════════════════════

class KiteSession:
    """
    Manages Kite login and access token.
    Both EquityModule and FnoModule call kite() to get a KiteConnect instance.
    They share the access token but make independent API calls.
    """

    _kite = None
    _lock = threading.Lock()
    _last_login = None

    @classmethod
    def login(cls):
        """Full TOTP auto-login to Kite."""
        with cls._lock:
            try:
                kite = KiteConnect(api_key=KITE_API_KEY)

                # Step 1: Try saved token first
                token_data = load_json(KITE_TOKEN_FILE, {})
                saved_date = token_data.get("date", "")
                saved_token = token_data.get("access_token", "")

                if saved_date == str(today_ist()) and saved_token:
                    kite.set_access_token(saved_token)
                    try:
                        profile = kite.profile()
                        log.info(f"Kite: reused token for {profile.get('user_name', ZERODHA_USER_ID)}")
                        cls._kite = kite
                        cls._last_login = now_ist()
                        return True
                    except Exception:
                        log.info("Kite: saved token expired, doing fresh login")

                # Step 2: Fresh TOTP login
                if not ZERODHA_PASSWORD or not KITE_TOTP_SECRET:
                    log.error("Kite: missing password or TOTP secret in env")
                    return False

                session = requests.Session()
                session.headers.update({"User-Agent": "Mozilla/5.0"})

                # Login step 1
                r1 = session.post(
                    "https://kite.zerodha.com/api/login",
                    data={"user_id": ZERODHA_USER_ID, "password": ZERODHA_PASSWORD},
                    timeout=30,
                )
                if r1.status_code != 200:
                    log.error(f"Kite login step 1 failed: {r1.status_code}")
                    return False

                request_id = r1.json().get("data", {}).get("request_id", "")
                if not request_id:
                    log.error("Kite login: no request_id")
                    return False

                # Login step 2: TOTP
                time.sleep(1)
                totp = pyotp.TOTP(KITE_TOTP_SECRET).now()
                r2 = session.post(
                    "https://kite.zerodha.com/api/twofa",
                    data={
                        "user_id": ZERODHA_USER_ID,
                        "request_id": request_id,
                        "twofa_value": totp,
                        "twofa_type": "totp",
                    },
                    timeout=30,
                    allow_redirects=True,
                )

                # Extract request_token from redirect URL
                final_url = r2.url
                if "request_token=" not in final_url:
                    # Check response for token
                    if r2.status_code == 200 and "status" in r2.text:
                        # Try the session approach
                        login_url = kite.login_url()
                        r3 = session.get(login_url, allow_redirects=True, timeout=30)
                        final_url = r3.url

                if "request_token=" not in final_url:
                    log.error(f"Kite TOTP: no request_token in {final_url[:100]}")
                    return False

                request_token = final_url.split("request_token=")[1].split("&")[0]

                # Generate session
                data = kite.generate_session(request_token, api_secret=KITE_API_SECRET)
                access_token = data.get("access_token", "")
                if not access_token:
                    log.error("Kite: no access_token from generate_session")
                    return False

                kite.set_access_token(access_token)
                profile = kite.profile()
                log.info(f"Kite: logged in as {profile.get('user_name', ZERODHA_USER_ID)}")

                # Save token
                save_json(KITE_TOKEN_FILE, {
                    "access_token": access_token,
                    "date": str(today_ist()),
                })

                cls._kite = kite
                cls._last_login = now_ist()
                return True

            except Exception as e:
                log.error(f"Kite login failed: {e}")
                cls._kite = None
                return False

    @classmethod
    def kite(cls):
        """Get KiteConnect instance. Returns None if not logged in."""
        if cls._kite is None:
            cls.login()
        return cls._kite

    @classmethod
    def ensure_connected(cls):
        """Make sure we have a valid Kite connection."""
        k = cls.kite()
        if k is None:
            return False
        try:
            k.profile()
            return True
        except Exception:
            log.info("Kite: token expired, re-logging in")
            cls._kite = None
            return cls.login()


# ═══════════════════════════════════════════════════════════════════════════════
#  TELEGRAM — Simple, direct. No shared gatekeeper.
# ═══════════════════════════════════════════════════════════════════════════════

def send_telegram(msg, silent=False):
    """Send a Telegram message. Returns True on success."""
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        return False
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        resp = requests.post(url, json={
            "chat_id": TELEGRAM_CHAT_ID,
            "text": msg[:4000],
            "parse_mode": "Markdown",
            "disable_notification": silent,
        }, timeout=15)
        return resp.status_code == 200
    except Exception:
        return False


class TelegramThrottle:
    """
    Per-module message throttle. Prevents spam.
    Each module (equity/fno) has its own instance.
    """

    def __init__(self, name, max_per_hour=10):
        self.name = name
        self.max_per_hour = max_per_hour
        self._sent = []

    def can_send(self):
        now = time.time()
        self._sent = [t for t in self._sent if now - t < 3600]
        return len(self._sent) < self.max_per_hour

    def send(self, msg, force=False, silent=False):
        if not force and not self.can_send():
            return False
        prefix = f"*[{self.name}]*\n"
        result = send_telegram(prefix + msg, silent=silent)
        if result:
            self._sent.append(time.time())
        return result


# ═══════════════════════════════════════════════════════════════════════════════
#  GTT MANAGER — The bulletproof version. ALWAYS checks before placing.
# ═══════════════════════════════════════════════════════════════════════════════

class GTTManager:
    """
    Manages GTT orders on Kite. NEVER places blind GTTs.

    Every operation:
      1. Calls kite.get_gtts() to get ALL active GTTs
      2. Builds symbol → gtt_id map
      3. If symbol has GTT → modify (not create new)
      4. If symbol has no GTT → place new
      5. Cleans orphan GTTs (stock sold but GTT still active)
      6. Removes duplicate GTTs (keeps newest, deletes older)

    Equity and F&O each have their own GTTManager instance.
    They independently call Kite API — no shared state.
    """

    def __init__(self, name):
        self.name = name  # "EQUITY" or "FNO"

    def _get_active_gtts(self):
        """Fetch all active GTTs from Kite, grouped by symbol."""
        kite = KiteSession.kite()
        if not kite:
            return {}
        try:
            all_gtts = kite.get_gtts() or []
            by_symbol = defaultdict(list)
            for g in all_gtts:
                if g.get("status") == "active":
                    sym = g.get("condition", {}).get("tradingsymbol", "")
                    if sym:
                        by_symbol[sym].append(g)
            return dict(by_symbol)
        except Exception as e:
            log.error(f"GTT {self.name}: fetch failed: {e}")
            return {}

    def ensure_gtt(self, symbol, exchange, qty, sl_price, target_price=0):
        """
        Ensure exactly ONE GTT exists for this symbol.
        If GTT exists → modify SL/target (only if SL moved UP).
        If no GTT → place new.
        If duplicates → delete extras.

        Returns gtt_id or None.
        """
        kite = KiteSession.kite()
        if not kite or qty <= 0 or sl_price <= 0:
            return None

        # PATCH_V1_INLOSS_FLOOR: prevent placing SL above LTP (broken stop)
        try:
            _ltp_data = kite.ltp([f"{exchange}:{symbol}"])
            _ltp = _ltp_data.get(f"{exchange}:{symbol}", {}).get("last_price", 0)
            if _ltp > 0 and sl_price >= _ltp:
                _new_sl = round(_ltp * 0.85, 1)
                log.warning(f"[PATCH_V1_INLOSS] {self.name} {symbol}: requested SL={sl_price} >= LTP={_ltp}, overriding to {_new_sl}")
                sl_price = _new_sl
        except Exception as _e:
            log.error(f"[PATCH_V1_INLOSS] {self.name} {symbol}: LTP check failed: {_e}")
        # END_PATCH_V1_INLOSS_FLOOR

        active = self._get_active_gtts()
        existing = active.get(symbol, [])

        # ── Delete duplicates (keep newest) ──
        if len(existing) > 1:
            existing.sort(key=lambda g: g.get("id", 0), reverse=True)
            for dup in existing[1:]:
                try:
                    kite.delete_gtt(dup["id"])
                    log.info(f"GTT {self.name}: deleted duplicate {dup['id']} for {symbol}")
                except Exception:
                    pass
            existing = [existing[0]]

        # ── Modify existing GTT ──
        if existing:
            gtt = existing[0]
            gtt_id = gtt["id"]
            old_triggers = gtt.get("trigger_values", [])
            old_sl = old_triggers[0] if old_triggers else 0

            # Only modify if new SL is HIGHER than old SL (SL only moves UP)
            if sl_price > old_sl:
                try:
                    triggers = [sl_price]
                    orders = [
                        {
                            "transaction_type": "SELL",
                            "quantity": qty,
                            "price": round(sl_price * 0.98, 1),  # 2% buffer for fill
                            "order_type": "LIMIT",
                            "product": "CNC" if exchange == "NSE" else "NRML",
                        }
                    ]
                    # FIX_V29_SINGLE_ONLY: always SINGLE, no OCO. Software handles target exit.
                    gtt_type = kite.GTT_TYPE_SINGLE
                    kite.modify_gtt(
                        trigger_id=gtt_id,
                        trigger_type=gtt_type,
                        tradingsymbol=symbol,
                        exchange=exchange,
                        trigger_values=triggers,
                        last_price=sl_price * 1.05,  # Approximate LTP
                        orders=orders,
                    )
                    log.info(f"GTT {self.name}: modified {symbol} SL {old_sl}→{sl_price}")
                    return gtt_id
                except Exception as e:
                    # V27 PATCH (Bug #3): NEVER delete-and-replace with looser SL on modify failure.
                    # If modify fails (rate limit, concurrent edit, network), leave existing GTT
                    # intact and retry on next tick. One stale tick beats losing protection.
                    if "trigger type" in str(e).lower():
                        try:
                            kite.delete_gtt(gtt_id)
                            log.info(f"GTT {self.name}: deleted old GTT {gtt_id} for {symbol} (trigger type change)")
                            return self.ensure_gtt(symbol, exchange, qty, sl_price, target_price)
                        except Exception as e2:
                            log.error(f"GTT {self.name}: delete+recreate failed for {symbol} ({e2}) - NO GTT PROTECTION")
                            return None  # V28 A5: signal failure, caller must retry
                    else:
                        # V28 A5: return None instead of fake-success gtt_id
                        # Caller's trailing SL logic will retry on next tick.
                        log.error(f"GTT {self.name}: modify {symbol} failed ({e}) - leaving existing GTT intact (will retry next tick)")
                        return None
                log.debug(f"GTT {self.name}: {symbol} SL {sl_price} <= existing {old_sl}, no change")
            return gtt_id

        # ── Place new GTT ──
        try:
            triggers = [sl_price]
            orders = [
                {
                    "transaction_type": "SELL",
                    "quantity": qty,
                    "price": round(sl_price * 0.98, 1),
                    "order_type": "LIMIT",
                    "product": "CNC" if exchange == "NSE" else "NRML",
                }
            ]
            # FIX_V29_SINGLE_ONLY: always SINGLE, no OCO. Software handles target exit.
            gtt_type = kite.GTT_TYPE_SINGLE
            ltp_data = kite.ltp([f"{exchange}:{symbol}"])
            last_price = ltp_data.get(f"{exchange}:{symbol}", {}).get("last_price", sl_price * 1.05)

            gtt_id = kite.place_gtt(
                trigger_type=gtt_type,
                tradingsymbol=symbol,
                exchange=exchange,
                trigger_values=triggers,
                last_price=last_price,
                orders=orders,
            )
            log.info(f"GTT {self.name}: placed {symbol} SL={sl_price} Target={target_price} ID={gtt_id}")
            return gtt_id
        except Exception as e:
            log.error(f"GTT {self.name}: place {symbol} failed: {e}")
            return None

    def cleanup_orphans(self, valid_symbols):
        """Delete GTTs for stocks no longer held."""
        active = self._get_active_gtts()
        kite = KiteSession.kite()
        if not kite:
            return 0

        cleaned = 0
        for sym, gtts in active.items():
            if sym not in valid_symbols:
                for g in gtts:
                    try:
                        kite.delete_gtt(g["id"])
                        log.info(f"GTT {self.name}: orphan deleted {sym} ID={g['id']}")
                        cleaned += 1
                    except Exception:
                        pass
        return cleaned

    def audit(self, holdings_map):
        """
        Full GTT audit. Run at 08:00.
        - Every holding must have exactly 1 GTT
        - Delete duplicates
        - Delete orphans
        - Place missing GTTs
        Returns (placed, modified, deleted) counts.
        """
        placed, modified, deleted = 0, 0, 0
        active = self._get_active_gtts()

        # Delete orphans
        for sym in list(active.keys()):
            if sym not in holdings_map:
                for g in active[sym]:
                    kite = KiteSession.kite()
                    if kite:
                        try:
                            kite.delete_gtt(g["id"])
                            deleted += 1
                        except Exception:
                            pass

        # Ensure every holding has GTT
        for sym, info in holdings_map.items():
            qty = info.get("qty", 0)
            sl = info.get("sl", 0)
            target = info.get("target", 0)
            exchange = info.get("exchange", "NSE")
            if qty > 0 and sl > 0:
                result = self.ensure_gtt(sym, exchange, qty, sl, target)
                if result:
                    if sym in active:
                        modified += 1
                    else:
                        placed += 1

        log.info(f"GTT {self.name} AUDIT: placed={placed} modified={modified} deleted={deleted}")
        return placed, modified, deleted


# ═══════════════════════════════════════════════════════════════════════════════
#  TECHNICAL INDICATORS — Just 3. Each does ONE job.
# ═══════════════════════════════════════════════════════════════════════════════

def calc_rsi(closes, period=14):
    """
    Calculate RSI from a list of closing prices.
    Returns RSI value (0-100) or 50 if insufficient data.
    """
    if len(closes) < period + 1:
        return 50.0

    gains = []
    losses = []
    for i in range(1, len(closes)):
        delta = closes[i] - closes[i - 1]
        if delta > 0:
            gains.append(delta)
            losses.append(0)
        else:
            gains.append(0)
            losses.append(abs(delta))

    if len(gains) < period:
        return 50.0

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period

    for i in range(period, len(gains)):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period

    if avg_loss == 0:
        return 100.0

    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))


def calc_volume_ratio(volumes, period=20):
    """
    Calculate today's volume vs 20-day average.
    Returns ratio (1.0 = average, 2.0 = double average).
    """
    if len(volumes) < period + 1:
        return 1.0
    avg_vol = sum(volumes[-period - 1:-1]) / period
    if avg_vol <= 0:
        return 1.0
    return volumes[-1] / avg_vol


def calc_atr(highs, lows, closes, period=14):
    """
    Calculate Average True Range.
    Returns ATR value (in price units).
    """
    if len(closes) < period + 1:
        return closes[-1] * 0.02 if closes else 0  # Default 2% of price

    true_ranges = []
    for i in range(1, len(closes)):
        tr = max(
            highs[i] - lows[i],
            abs(highs[i] - closes[i - 1]),
            abs(lows[i] - closes[i - 1]),
        )
        true_ranges.append(tr)

    if len(true_ranges) < period:
        return sum(true_ranges) / len(true_ranges) if true_ranges else 0

    atr = sum(true_ranges[:period]) / period
    for i in range(period, len(true_ranges)):
        atr = (atr * (period - 1) + true_ranges[i]) / period

    return atr


# ═══════════════════════════════════════════════════════════════════════════════
#  NEWS SCANNER — Each module has its own instance, own interpretation
# ═══════════════════════════════════════════════════════════════════════════════

class NewsScanner:
    """
    Scans RSS feeds for stock-moving news.
    Returns candidates with symbol, direction, score, catalyst text.

    Each module (equity/fno) creates its own NewsScanner.
    Same feeds, but each module filters and interprets independently.
    """

    def __init__(self, name, valid_symbols=None, name_map=None):
        self.name = name
        self.valid_symbols = valid_symbols or set()
        self.name_map = name_map or {}  # PATCH_V28_SYMBOL_REGEX: company name → symbol
        self._seen = set()  # Dedup hashes
        self._seen_file = DATA_DIR / f"news_seen_{name.lower()}.json"
        self._load_seen()

    def _load_seen(self):
        data = load_json(self._seen_file, {"hashes": []})
        self._seen = set(data.get("hashes", [])[-5000:])  # Keep last 5000

    def _save_seen(self):
        save_json(self._seen_file, {"hashes": list(self._seen)[-5000:]})

    def _hash(self, title, link):
        raw = f"{title.strip().lower()}|{link.strip()}"
        return hashlib.md5(raw.encode()).hexdigest()[:16]

    def _extract_symbols(self, text):
        """Try to find NSE symbols mentioned in text.
        PATCH_V28_SYMBOL_REGEX: word-boundary matching to prevent
        'BEL' matching 'BELOW', 'HAL' matching 'SHALL', etc.
        Also maps common company names to NSE symbols.
        """
        import re as _re
        found = []
        text_upper = text.upper()
        for sym in self.valid_symbols:
            if len(sym) < 2:
                continue
            # Word-boundary match: sym must be a standalone word
            if _re.search(r'\b' + _re.escape(sym) + r'\b', text_upper):
                found.append(sym)
        # Company name -> symbol from Kite instruments (all 3000+ stocks)
            _NAME_MAP = self.name_map if self.name_map else {
            "TATA CONSULTANCY": "TCS", "HDFC BANK": "HDFCBANK",
            "INFOSYS": "INFY", "RELIANCE INDUSTRIES": "RELIANCE",
            "STATE BANK": "SBIN", "ICICI BANK": "ICICIBANK",
            "AXIS BANK": "AXISBANK", "KOTAK MAHINDRA": "KOTAKBANK",
            "LARSEN": "LT", "BAJAJ FINANCE": "BAJFINANCE",
            "HINDUSTAN UNILEVER": "HINDUNILVR", "TITAN COMPANY": "TITAN",
            "POWER FINANCE": "PFC", "BHARTI AIRTEL": "BHARTIARTL",
            "TATA MOTORS": "TATAMOTORS", "TATA STEEL": "TATASTEEL",
            "MARUTI SUZUKI": "MARUTI", "SUN PHARMA": "SUNPHARMA",
            "WIPRO": "WIPRO", "TECH MAHINDRA": "TECHM",
            "JSW STEEL": "JSWSTEEL", "ADANI PORTS": "ADANIPORTS",
            "ULTRA TECH": "ULTRACEMCO", "POWER GRID": "POWERGRID",
            "COAL INDIA": "COALINDIA", "INDIAN OIL": "IOC",
            "SHRIRAM FINANCE": "SHRIRAMFIN", "CROMPTON GREAVES": "CROMPTON",
        }
        for name, sym in _NAME_MAP.items():
            if name in text_upper and sym not in found and sym in self.valid_symbols:
                found.append(sym)
        return found

    def _detect_direction(self, text):
        """
        PATCH_V7_SIGNAL_QUALITY
        Detect BULLISH/BEARISH from full text (title + summary).
        Requires minimum 2 keyword matches OR clear margin (diff >= 2).
        Weak single-keyword matches return NEUTRAL to avoid false signals.
        """
        text_lower = (text or "").lower()
        bull_score = sum(1 for kw in BULLISH_KEYWORDS if kw in text_lower)
        bear_score = sum(1 for kw in BEARISH_KEYWORDS if kw in text_lower)

        # Require conviction: either 2+ matches on winning side, or clear margin
        if bull_score >= 2 and bull_score > bear_score:
            return "BULLISH", min(55 + bull_score * 10, 95)
        elif bear_score >= 2 and bear_score > bull_score:
            return "BEARISH", min(55 + bear_score * 10, 95)
        elif bull_score - bear_score >= 2:
            return "BULLISH", min(55 + bull_score * 10, 95)
        elif bear_score - bull_score >= 2:
            return "BEARISH", min(55 + bear_score * 10, 95)
        return "NEUTRAL", 30

    def scan(self):
        """
        Scan all RSS feeds. Return list of candidates:
        [{"symbol": "ONGC", "direction": "BULLISH", "score": 80, "catalyst": "..."}]
        """
        candidates = []
        total_checked = 0

        for feed_name, feed_url in NEWS_FEEDS.items():
            try:
                parsed = feedparser.parse(feed_url)
                for entry in parsed.entries[:20]:
                    total_checked += 1
                    title = entry.get("title", "")
                    link = entry.get("link", "")

                    h = self._hash(title, link)
                    if h in self._seen:
                        continue
                    self._seen.add(h)

                    # PATCH_V7_SIGNAL_QUALITY: read full article text, not just title
                    summary = entry.get("summary", "") or entry.get("description", "") or ""
                    # Strip HTML tags crudely
                    import re as _re
                    summary_clean = _re.sub(r"<[^>]+>", " ", summary)
                    full_text = f"{title} {summary_clean}"

                    # Find symbols (check both title and summary)
                    symbols = self._extract_symbols(full_text)
                    if not symbols:
                        continue

                    # Detect direction from full text
                    direction, score = self._detect_direction(full_text)
                    if direction == "NEUTRAL":
                        continue

                    _now_iso = now_ist().isoformat()
                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"{feed_name}: {title[:80]}",
                            "source": "NEWS",
                            "timestamp": _now_iso,
                        })

            except Exception as e:
                log.debug(f"News {self.name}: {feed_name} error: {e}")

        self._save_seen()
        if candidates:
            log.info(f"News {self.name}: {len(candidates)} candidates from {total_checked} headlines")
        return candidates


# ═══════════════════════════════════════════════════════════════════════════════
#  FILING MONITOR — Scrapes NSE corporate filings for catalysts
# ═══════════════════════════════════════════════════════════════════════════════

class FilingMonitor:
    """
    Monitors NSE corporate filings for trading catalysts.
    Catches promoter buying, buybacks, order wins, earnings BEFORE news RSS.
    Each module has its own instance — interprets filings independently.
    """

    NSE_FILING_URL = "https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={from_date}&to_date={to_date}"

    # Filing keywords mapped to signal type
    FILING_KW_MAP = {
        # BULLISH signals
        "buyback": "BUYBACK", "buy back": "BUYBACK", "buy-back": "BUYBACK",
        "promoter buy": "PROMOTER_BUY", "promoter acqui": "PROMOTER_BUY",
        "increase in shareholding": "PROMOTER_BUY", "acquired shares": "PROMOTER_BUY",
        "order win": "ORDER_WIN", "order received": "ORDER_WIN", "bagged order": "ORDER_WIN",
        "wins order": "ORDER_WIN", "contract awarded": "ORDER_WIN", "new order": "ORDER_WIN",
        "dividend": "DIVIDEND", "interim dividend": "DIVIDEND", "final dividend": "DIVIDEND",
        "bonus": "BONUS", "bonus issue": "BONUS",
        "stock split": "STOCK_SPLIT", "sub-division": "STOCK_SPLIT",
        "acquisition": "ACQUISITION", "acquired": "ACQUISITION",
        "expansion": "EXPANSION", "new plant": "EXPANSION", "capacity addition": "EXPANSION",
        "revenue growth": "RESULTS_BEAT", "profit growth": "RESULTS_BEAT",
        "beats estimate": "RESULTS_BEAT", "above estimate": "RESULTS_BEAT",
        # BEARISH signals
        "promoter sell": "PROMOTER_SELL", "promoter disp": "PROMOTER_SELL",
        "decrease in shareholding": "PROMOTER_SELL", "sold shares": "PROMOTER_SELL",
        "qip": "QIP", "qualified institution": "QIP",
        "ofs": "OFS", "offer for sale": "OFS",
        "downgrade": "CREDIT_DOWNGRADE", "rating downgrade": "CREDIT_DOWNGRADE",
        "fraud": "FRAUD", "scam": "FRAUD", "penalty": "PENALTY", "fine imposed": "PENALTY",
        "loss widen": "RESULTS_MISS", "below estimate": "RESULTS_MISS",
        "misses estimate": "RESULTS_MISS", "revenue decline": "RESULTS_MISS",
    }

    def __init__(self, name, valid_symbols=None):
        self.name = name
        self.valid_symbols = valid_symbols or set()
        self._seen = set()
        self._seen_file = DATA_DIR / f"filing_seen_{name.lower()}.json"
        self._load_seen()
        self._session = requests.Session()
        self._session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/json",
            "Accept-Language": "en-US,en;q=0.9",
        })

    def _load_seen(self):
        data = load_json(self._seen_file, {"seen": []})
        self._seen = set(data.get("seen", [])[-3000:])

    def _save_seen(self):
        save_json(self._seen_file, {"seen": list(self._seen)[-3000:]})

    def scan(self):
        """
        Fetch recent NSE filings and extract trading signals.
        Returns list of candidates with symbol, direction, score, catalyst.
        """
        candidates = []
        today = today_ist()
        from_date = (today - timedelta(days=1)).strftime("%d-%m-%Y")
        to_date = today.strftime("%d-%m-%Y")

        try:
            # First get NSE cookies
            self._session.get("https://www.nseindia.com", timeout=10)
            time.sleep(0.5)

            url = self.NSE_FILING_URL.format(from_date=from_date, to_date=to_date)
            resp = self._session.get(url, timeout=15)

            if resp.status_code != 200:
                log.debug(f"Filing {self.name}: NSE returned {resp.status_code}")
                return candidates

            filings = resp.json()
            if not isinstance(filings, list):
                return candidates

            for filing in filings[:100]:  # Process latest 100
                symbol = filing.get("symbol", "")
                # PATCH_V11_FILING_TEXT: read attchmntText (real content) in addition to desc (category label)
                # NSE puts the real filing summary in attchmntText; desc is just a category like "General Updates"
                _desc = filing.get("desc", "") or ""
                _body = filing.get("attchmntText", "") or ""
                subject = (_desc + " " + _body).lower()
                filing_id = filing.get("an_dt", "") + symbol

                if not symbol or not subject:
                    continue

                # Dedup
                h = hashlib.md5(filing_id.encode()).hexdigest()[:12]
                if h in self._seen:
                    continue
                self._seen.add(h)

                # Skip if not in our valid symbols
                if self.valid_symbols and symbol not in self.valid_symbols:
                    continue

                # Match filing keywords
                matched_type = None
                for keyword, filing_type in self.FILING_KW_MAP.items():
                    if keyword in subject:
                        matched_type = filing_type
                        break

                if not matched_type:
                    continue

                signal = FILING_SIGNALS.get(matched_type, {})
                direction = signal.get("direction", "NEUTRAL")
                score = signal.get("score", 50)

                if direction == "NEUTRAL":
                    continue

                candidates.append({
                    "symbol": symbol,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"FILING {matched_type}: {subject[:80]}",
                    "source": "FILING",
                    "filing_type": matched_type,
                })

        except Exception as e:
            log.debug(f"Filing {self.name}: scan error: {e}")

        self._save_seen()
        if candidates:
            log.info(f"Filing {self.name}: {len(candidates)} signals from NSE filings")
        return candidates


# ═══════════════════════════════════════════════════════════════════════════════
#  BROKERAGE MONITOR — Catches analyst upgrades/downgrades from RSS
# ═══════════════════════════════════════════════════════════════════════════════

class BrokerageMonitor:
    """
    Scans RSS feeds specifically for brokerage calls.
    "HDFC Securities upgrades TCS to BUY with target Rs.4500"
    Each module has its own instance.
    """

    BROKERAGE_KEYWORDS = [
        "buy rating", "sell rating", "target price", "price target",
        "upgrade", "downgrade", "outperform", "underperform",
        "top pick", "accumulate", "overweight", "underweight",
        "raises target", "cuts target", "initiates coverage",
        "maintains buy", "reiterates buy", "conviction buy",
        "stocks to buy", "brokerage picks", "analyst pick",
    ]

    TIER1_BROKERAGES = [
        "hdfc securities", "motilal oswal", "clsa", "jm financial",
        "nuvama", "icici direct", "kotak securities", "jefferies",
        "goldman sachs", "morgan stanley", "nomura", "macquarie",
        "ubs", "bernstein", "citi", "bofa", "jp morgan",
    ]

    def __init__(self, name, valid_symbols=None):
        self.name = name
        self.valid_symbols = valid_symbols or set()
        self._seen = set()

    def scan(self, news_candidates=None):
        """
        Filter news candidates for brokerage-specific calls.
        Returns enhanced candidates with brokerage tier info.
        Also does independent RSS scan for brokerage keywords.
        """
        candidates = []

        # Scan RSS feeds for brokerage-specific headlines
        for feed_name, feed_url in NEWS_FEEDS.items():
            try:
                parsed = feedparser.parse(feed_url)
                for entry in parsed.entries[:15]:
                    title = entry.get("title", "")
                    title_lower = title.lower()

                    # Must contain brokerage keyword
                    if not any(kw in title_lower for kw in self.BROKERAGE_KEYWORDS):
                        continue

                    link = entry.get("link", "")
                    h = hashlib.md5(f"{title}{link}".encode()).hexdigest()[:12]
                    if h in self._seen:
                        continue
                    self._seen.add(h)

                    # Extract symbols
                    text_upper = title.upper()
                    symbols = [s for s in self.valid_symbols if len(s) >= 2 and __import__("re").search(r"\b" + __import__("re").escape(s) + r"\b", text_upper)]  # PATCH_V28_SYMBOL_REGEX
                    if not symbols:
                        continue

                    # Detect direction
                    is_upgrade = any(kw in title_lower for kw in
                                     ["buy", "upgrade", "outperform", "overweight",
                                      "raises target", "top pick", "accumulate"])
                    is_downgrade = any(kw in title_lower for kw in
                                       ["sell", "downgrade", "underperform", "underweight",
                                        "cuts target", "reduce"])

                    if not is_upgrade and not is_downgrade:
                        continue

                    # Tier-1 brokerage bonus
                    is_tier1 = any(b in title_lower for b in self.TIER1_BROKERAGES)
                    score = 80 if is_tier1 else 65

                    direction = "BULLISH" if is_upgrade else "BEARISH"

                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"BROKERAGE {'T1 ' if is_tier1 else ''}{title[:80]}",
                            "source": "BROKERAGE",
                        })

            except Exception:
                pass

        if candidates:
            log.info(f"Brokerage {self.name}: {len(candidates)} analyst calls detected")
        return candidates


# ═══════════════════════════════════════════════════════════════════════════════
#  MACRO EVENT DETECTOR — RBI, war, oil, geopolitical events
# ═══════════════════════════════════════════════════════════════════════════════

class MacroDetector:
    """
    Detects macro events from news and maps them to sector/stock plays.
    "RBI rate cut" → BULLISH BANKING → CE on SBIN/HDFCBANK
    "Iran tensions" → BULLISH ENERGY → CE on ONGC/BPCL
    "IT spending cut" → BEARISH IT → PE on TCS/INFY

    Each module has its own instance.
    """

    # Macro theme → affected stocks and direction
    MACRO_MAP = {
        "rbi rate cut": {"direction": "BULLISH", "score": 85, "stocks": ["SBIN", "HDFCBANK", "ICICIBANK", "KOTAKBANK", "AXISBANK"]},
        "rbi cut": {"direction": "BULLISH", "score": 85, "stocks": ["SBIN", "HDFCBANK", "ICICIBANK", "KOTAKBANK", "AXISBANK"]},
        "rate cut": {"direction": "BULLISH", "score": 75, "stocks": ["SBIN", "HDFCBANK", "ICICIBANK", "BAJFINANCE"]},
        "rbi rate hike": {"direction": "BEARISH", "score": 80, "stocks": ["SBIN", "HDFCBANK", "ICICIBANK", "BAJFINANCE"]},
        "rbi hike": {"direction": "BEARISH", "score": 80, "stocks": ["SBIN", "HDFCBANK", "ICICIBANK"]},
        "iran": {"direction": "BULLISH", "score": 50, "stocks": ["ONGC", "BPCL", "IOC", "GAIL", "RELIANCE"]},
        "oil price": {"direction": "BULLISH", "score": 50, "stocks": ["ONGC", "BPCL", "IOC", "RELIANCE"]},
        "crude oil": {"direction": "BULLISH", "score": 50, "stocks": ["ONGC", "BPCL", "IOC", "RELIANCE"]},
        "opec cut": {"direction": "BULLISH", "score": 55, "stocks": ["ONGC", "BPCL", "RELIANCE"]},
        "defence order": {"direction": "BULLISH", "score": 85, "stocks": ["HAL", "BEL", "BHARATFORGE"]},
        "defence deal": {"direction": "BULLISH", "score": 85, "stocks": ["HAL", "BEL", "BHARATFORGE"]},
        "war": {"direction": "BULLISH", "score": 75, "stocks": ["HAL", "BEL", "BHARATFORGE"]},
        "military": {"direction": "BULLISH", "score": 70, "stocks": ["HAL", "BEL"]},
        "infrastructure spend": {"direction": "BULLISH", "score": 75, "stocks": ["LT", "ADANIENT", "ADANIPORTS"]},
        "highway": {"direction": "BULLISH", "score": 70, "stocks": ["LT", "ADANIENT"]},
        "railway": {"direction": "BULLISH", "score": 70, "stocks": ["IRCTC", "LT"]},
        "it layoff": {"direction": "BEARISH", "score": 75, "stocks": ["TCS", "INFY", "WIPRO", "HCLTECH", "TECHM"]},
        "it spending cut": {"direction": "BEARISH", "score": 70, "stocks": ["TCS", "INFY", "WIPRO"]},
        "us recession": {"direction": "BEARISH", "score": 80, "stocks": ["TCS", "INFY", "WIPRO", "HCLTECH"]},
        "stimulus": {"direction": "BULLISH", "score": 80, "stocks": ["SBIN", "LT", "RELIANCE", "TATASTEEL"]},
        "monsoon good": {"direction": "BULLISH", "score": 65, "stocks": ["HINDUNILVR", "ITC", "DABUR", "MARICO"]},
        "monsoon bad": {"direction": "BEARISH", "score": 65, "stocks": ["HINDUNILVR", "ITC", "DABUR"]},
        "fii buying": {"direction": "BULLISH", "score": 70, "stocks": ["HDFCBANK", "RELIANCE", "INFY", "TCS"]},
        "fii selling": {"direction": "BEARISH", "score": 70, "stocks": ["HDFCBANK", "RELIANCE", "INFY", "TCS"]},
        "rupee weak": {"direction": "BULLISH", "score": 65, "stocks": ["TCS", "INFY", "WIPRO", "HCLTECH"]},
        "rupee strong": {"direction": "BEARISH", "score": 60, "stocks": ["TCS", "INFY", "WIPRO"]},
        "gold price": {"direction": "BULLISH", "score": 60, "stocks": ["TITAN"]},
        "pharma export": {"direction": "BULLISH", "score": 70, "stocks": ["SUNPHARMA", "DRREDDY", "CIPLA", "AUROPHARMA"]},
        "fda approval": {"direction": "BULLISH", "score": 85, "stocks": ["SUNPHARMA", "DRREDDY", "CIPLA", "BIOCON"]},
        "fda warning": {"direction": "BEARISH", "score": 85, "stocks": ["SUNPHARMA", "DRREDDY", "CIPLA", "BIOCON"]},
        "auto sales": {"direction": "BULLISH", "score": 70, "stocks": ["MARUTI", "TATAMOTORS", "M&M", "BAJAJ-AUTO"]},
        "ev push": {"direction": "BULLISH", "score": 75, "stocks": ["TATAMOTORS", "M&M"]},
        "steel price": {"direction": "BULLISH", "score": 65, "stocks": ["TATASTEEL", "JSWSTEEL", "HINDALCO"]},
        "china dump": {"direction": "BEARISH", "score": 70, "stocks": ["TATASTEEL", "JSWSTEEL"]},
    }

    def __init__(self, name, valid_symbols=None):
        self.name = name
        self.valid_symbols = valid_symbols or set()
        self._seen = set()

    def scan(self):
        """Scan RSS feeds for macro themes, return candidates."""
        candidates = []

        for feed_name, feed_url in NEWS_FEEDS.items():
            try:
                parsed = feedparser.parse(feed_url)
                for entry in parsed.entries[:15]:
                    title = entry.get("title", "")
                    title_lower = title.lower()
                    link = entry.get("link", "")

                    h = hashlib.md5(f"macro_{title}".encode()).hexdigest()[:12]
                    if h in self._seen:
                        continue

                    for theme, config in self.MACRO_MAP.items():
                        if theme in title_lower:
                            self._seen.add(h)
                            for stock in config["stocks"]:
                                if not self.valid_symbols or stock in self.valid_symbols:
                                    candidates.append({
                                        "symbol": stock,
                                        "direction": config["direction"],
                                        "score": config["score"],
                                        "catalyst": f"MACRO {theme.upper()}: {title[:60]}",
                                        "source": "MACRO",
                                    })
                            break  # One theme per headline

            except Exception:
                pass

        if candidates:
            log.info(f"Macro {self.name}: {len(candidates)} macro-driven candidates")
        return candidates


# ═══════════════════════════════════════════════════════════════════════════════
#  EARNINGS CALENDAR — Tracks upcoming quarterly results for F&O timing
# ═══════════════════════════════════════════════════════════════════════════════

class EarningsCalendar:
    """
    Tracks upcoming quarterly results dates.
    F&O module uses this to position BEFORE earnings (buy options 2-4 weeks ahead).
    Sources: NSE board meeting filings (purpose: quarterly results).
    """

    def __init__(self):
        self._calendar = {}  # symbol -> {"date": date_str, "quarter": "Q4"}
        self._cal_file = DATA_DIR / "earnings_calendar.json"
        self._load()

    def _load(self):
        self._calendar = load_json(self._cal_file, {})

    def _save(self):
        save_json(self._cal_file, self._calendar)

    def update_from_filings(self, filings_data=None):
        """
        Update earnings calendar from NSE board meeting filings.
        Board meetings with purpose "quarterly results" = earnings date.
        """
        try:
            session = requests.Session()
            session.headers.update({
                "User-Agent": "Mozilla/5.0",
                "Accept": "application/json",
            })
            session.get("https://www.nseindia.com", timeout=10)
            time.sleep(0.5)

            today = today_ist()
            from_date = today.strftime("%d-%m-%Y")
            to_date = (today + timedelta(days=30)).strftime("%d-%m-%Y")

            url = f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={from_date}&to_date={to_date}"
            resp = session.get(url, timeout=15)

            if resp.status_code != 200:
                return

            filings = resp.json()
            if not isinstance(filings, list):
                return

            for f in filings:
                subject = f.get("desc", "").lower()
                symbol = f.get("symbol", "")
                bm_date = f.get("bm_date", "")

                if not symbol or not bm_date:
                    continue

                if any(kw in subject for kw in ["quarterly results", "financial results", "q1", "q2", "q3", "q4"]):
                    self._calendar[symbol] = {
                        "date": bm_date,
                        "subject": subject[:100],
                    }

            self._save()
            log.info(f"Earnings: {len(self._calendar)} upcoming results tracked")

        except Exception as e:
            log.debug(f"Earnings calendar update error: {e}")

    def get_upcoming(self, days_ahead=14):
        """Get stocks with earnings in next N days."""
        upcoming = []
        today = today_ist()

        for sym, info in self._calendar.items():
            try:
                date_str = info.get("date", "")
                for fmt in ("%d-%b-%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y"):
                    try:
                        earn_date = datetime.strptime(date_str, fmt).date()
                        break
                    except ValueError:
                        continue
                else:
                    continue

                days_to = (earn_date - today).days
                if 0 <= days_to <= days_ahead:
                    upcoming.append({
                        "symbol": sym,
                        "date": str(earn_date),
                        "days_to": days_to,
                    })
            except Exception:
                pass

        return sorted(upcoming, key=lambda x: x["days_to"])

    def get_earnings_plays(self, fno_stocks):
        """
        Find the BEST earnings plays — stocks where we should BUY options NOW
        to profit from IV expansion before results.
        
        Sweet spot: 14-21 days before results (IV is still low, enough time)
        Danger zone: 0-3 days before results (IV already peaked, IV crush risk)
        
        Returns list of play candidates with timing info.
        """
        plays = []
        today = today_ist()

        for sym, info in self._calendar.items():
            if sym not in fno_stocks:
                continue
            
            try:
                date_str = info.get("date", "")
                for fmt in ("%d-%b-%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y"):
                    try:
                        earn_date = datetime.strptime(date_str, fmt).date()
                        break
                    except ValueError:
                        continue
                else:
                    continue

                days_to = (earn_date - today).days

                # ── ENTRY ZONE: 14-21 days before results ──
                # IV is low, options are cheap, buy now
                if 14 <= days_to <= 21:
                    plays.append({
                        "symbol": sym,
                        "date": str(earn_date),
                        "days_to": days_to,
                        "action": "BUY_IV_PLAY",
                        "score": 85,  # High score — best timing
                        "direction": "BULLISH",  # Default, can be overridden by news
                        "catalyst": f"EARNINGS PLAY: {sym} results in {days_to}d ({earn_date}). IV expansion expected.",
                        "reason": "Buy options now while IV is low. Sell before results for IV profit.",
                    })

                # ── MODERATE ZONE: 7-13 days before ──
                # IV starting to rise, still OK to enter with strong catalyst
                elif 7 <= days_to <= 13:
                    plays.append({
                        "symbol": sym,
                        "date": str(earn_date),
                        "days_to": days_to,
                        "action": "BUY_IF_STRONG",
                        "score": 70,  # Moderate — IV already rising
                        "direction": "BULLISH",
                        "catalyst": f"EARNINGS MODERATE: {sym} results in {days_to}d. IV rising — need strong catalyst.",
                        "reason": "IV rising. Only enter with score 75+.",
                    })

                # ── DANGER ZONE: 0-3 days before ──
                # IV at peak. DON'T enter new positions. EXIT existing.
                elif 0 <= days_to <= 3:
                    plays.append({
                        "symbol": sym,
                        "date": str(earn_date),
                        "days_to": days_to,
                        "action": "EXIT_IV_CRUSH",
                        "score": 0,  # Don't buy
                        "direction": "NEUTRAL",
                        "catalyst": f"IV CRUSH WARNING: {sym} results in {days_to}d. EXIT options now.",
                        "reason": "IV will crush after results. Sell before.",
                    })

            except Exception:
                pass

        return plays


# ═══════════════════════════════════════════════════════════════════════════════
#  TRENDLYNE SCORER — Fundamental quality filter
# ═══════════════════════════════════════════════════════════════════════════════

class TrendlyneScorer:
    """
    Uses Trendlyne StratQ CSV data for fundamental quality scoring.
    Filters: PE, ROE, promoter holding, debt ratios.
    Prevents buying garbage stocks with good news.

    Each module has its own instance.
    """

    def __init__(self):
        self._data = {}  # symbol -> {pe, roe, promoter_pct, debt_equity}
        self._csv_file = DATA_DIR / "trendlyne_stratq.csv"
        self._load()

    def _load(self):
        """Load Trendlyne CSV if available."""
        try:
            # Try xlsx first, then csv
            xlsx_file = DATA_DIR / "trendlyne_data.xlsx"
            csv_file = self._csv_file
            
            if xlsx_file.exists():
                try:
                    import openpyxl
                    wb = openpyxl.load_workbook(xlsx_file, read_only=True)
                    ws = wb.active
                    rows = list(ws.iter_rows(values_only=True))
                    if not rows:
                        log.info("Trendlyne: xlsx empty")
                        return
                    headers = [str(h).strip() if h else "" for h in rows[0]]
                    for row in rows[1:]:
                        row_dict = {headers[i]: row[i] for i in range(min(len(headers), len(row)))}
                        sym = str(row_dict.get("NSE Code", row_dict.get("Symbol", row_dict.get("Stock Name", "")))).strip()
                        if not sym:
                            continue
                        def safe_float(val):
                            try: return float(val) if val else 0
                            except Exception: return 0  # V28 A8
                        self._data[sym] = {
                            "durability": safe_float(row_dict.get("Trendlyne Durability Score", 0)),
                            "valuation": safe_float(row_dict.get("Trendlyne Valuation Score", 0)),
                            "momentum": safe_float(row_dict.get("Trendlyne Momentum Score", 0)),
                            "promoter_pct": safe_float(row_dict.get("Promoter holding pledge percentage % Qtr", 0)),
                            "market_cap": safe_float(row_dict.get("Market Capitalization", 0)),
                        }
                    wb.close()
                    log.info(f"Trendlyne: {len(self._data)} stocks loaded from xlsx")
                    return
                except ImportError:
                    log.info("Trendlyne: openpyxl not installed, trying csv")
                except Exception as xe:
                    log.warning(f"Trendlyne: xlsx read error: {xe}")
            
            if not csv_file.exists():
                log.info("Trendlyne: no data file found, skipping fundamental filter")
                return

            import csv
            with open(csv_file, "r") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    sym = row.get("Symbol", row.get("symbol", "")).strip()
                    if not sym:
                        continue
                    self._data[sym] = {
                        "pe": float(row.get("PE", row.get("pe", 0)) or 0),
                        "roe": float(row.get("ROE", row.get("roe", 0)) or 0),
                        "promoter_pct": float(row.get("Promoter%", row.get("promoter_pct", 0)) or 0),
                        "debt_equity": float(row.get("Debt/Equity", row.get("debt_equity", 0)) or 0),
                    }
            log.info(f"Trendlyne: {len(self._data)} stocks loaded from csv")
        except Exception as e:
            log.debug(f"Trendlyne load error: {e}")

    def score(self, symbol):
        """
        Return fundamental quality score (0-100) for a symbol.
        100 = excellent fundamentals, 0 = unknown/poor.
        Returns 50 if no data (neutral — don't block, don't boost).
        """
        info = self._data.get(symbol)
        if not info:
            return 50  # No data = neutral

        # Use Trendlyne DVM scores directly (0-100 each)
        d = info.get("durability", 0)
        v = info.get("valuation", 0)
        m = info.get("momentum", 0)
        
        # If DVM scores available, use weighted average
        if d > 0 or v > 0 or m > 0:
            # Durability 40% + Valuation 30% + Momentum 30%
            score = d * 0.4 + v * 0.3 + m * 0.3
            return max(0, min(100, score))
        
        # Fallback: no DVM data
        return 50

    def is_quality(self, symbol, min_score=40):
        """Quick check: is this stock above minimum quality threshold?"""
        return self.score(symbol) >= min_score


# ═══════════════════════════════════════════════════════════════════════════════
#  AMO ENGINE — Places after-market orders for next day
# ═══════════════════════════════════════════════════════════════════════════════

class AMOEngine:
    """
    Places After Market Orders (AMO) for next day execution.
    Runs after 15:45 when evening scan finds strong catalysts.
    AMO orders are LIMIT orders at previous close ± buffer.

    Rules:
    - Total AMO cost must NOT exceed available capital
    - Cancel unfilled AMOs at 09:20 next morning
    - GTT only placed AFTER AMO fills (not before)
    """

    def __init__(self, name):
        self.name = name
        self._amo_file = DATA_DIR / f"amo_{name.lower()}.json"
        self._placed = []  # Track placed AMOs for morning cleanup

    def place_amo(self, symbol, price, qty, exchange="NSE", product="CNC"):
        """Place an AMO LIMIT order."""
        if not is_amo_window():
            return None

        kite = KiteSession.kite()
        if not kite:
            # Try emergency login for after-hours
            if not KiteSession.login():
                return None
            kite = KiteSession.kite()
            if not kite:
                return None

        try:
            limit_price = round(price * 1.01, 1)  # 1% above last close

            order_id = kite.place_order(
                variety="amo",
                exchange=exchange,
                tradingsymbol=symbol,
                transaction_type="BUY",
                quantity=qty,
                order_type="LIMIT",
                price=limit_price,
                product=product,
                validity="DAY",
                market_protection=5,  # SEBI mandatory
            )
            log.info(f"AMO {self.name}: placed {symbol} x{qty} @ {limit_price} id={order_id}")

            self._placed.append({
                "symbol": symbol,
                "qty": qty,
                "price": limit_price,
                "order_id": str(order_id),
                "time": now_ist().isoformat(),
            })
            self._save()
            return order_id

        except Exception as e:
            log.error(f"AMO {self.name}: place {symbol} failed: {e}")
            return None

    def cancel_stale(self):
        """Cancel unfilled AMOs at 09:20. Free up capital."""
        kite = KiteSession.kite()
        if not kite:
            return 0

        cancelled = 0
        try:
            orders = kite.orders()
            for o in orders:
                if (o.get("variety") == "amo" and
                    o.get("status") in ("OPEN", "TRIGGER PENDING") and
                    o.get("transaction_type") == "BUY"):
                    try:
                        kite.cancel_order(variety="amo", order_id=o["order_id"])
                        cancelled += 1
                        log.info(f"AMO {self.name}: cancelled stale {o.get('tradingsymbol')} id={o['order_id']}")
                    except Exception:
                        pass
        except Exception as e:
            log.error(f"AMO {self.name}: cancel stale failed: {e}")

        if cancelled:
            log.info(f"AMO {self.name}: cancelled {cancelled} stale orders")
        self._placed = []
        self._save()
        return cancelled

    def get_total_pending_cost(self):
        """Total cost of pending AMOs — used to prevent over-ordering."""
        return sum(p.get("price", 0) * p.get("qty", 0) for p in self._placed)

    def _save(self):
        save_json(self._amo_file, {
            "placed": self._placed,
            "date": str(today_ist()),
        })

    def _load(self):
        data = load_json(self._amo_file, {})
        if data.get("date") == str(today_ist()):
            self._placed = data.get("placed", [])
        else:
            self._placed = []


# ═══════════════════════════════════════════════════════════════════════════════
#  EOD REPORTER — End of day summary to Telegram
# ═══════════════════════════════════════════════════════════════════════════════

class EODReporter:
    """
    Generates end-of-day summary for Telegram.
    Runs at 15:35 on trading days.
    """

    @staticmethod
    def generate_equity_report(equity_module):
        """Generate equity EOD summary."""
        positions = equity_module.positions
        if not positions:
            return "Equity: No open positions"

        kite = KiteSession.kite()
        if not kite:
            return "Equity: Kite not connected for EOD"

        try:
            sym_list = [f"NSE:{s}" for s in positions]
            ltp_data = kite.ltp(sym_list)

            lines = [f"*EQUITY EOD — {len(positions)} positions*\n"]
            total_pnl = 0

            for sym, pos in sorted(positions.items()):
                ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                entry = pos.get("entry_price", 0)
                qty = pos.get("qty", 0)
                pnl = (ltp - entry) * qty if ltp > 0 and entry > 0 else 0
                pnl_pct = ((ltp - entry) / entry * 100) if entry > 0 and ltp > 0 else 0
                total_pnl += pnl

                emoji = "+" if pnl >= 0 else ""
                lines.append(f"`{sym:12s}` {emoji}Rs.{pnl:,.0f} ({emoji}{pnl_pct:.1f}%)")

            lines.append(f"\n*Total P&L: Rs.{total_pnl:,.0f}*")
            lines.append(f"Capital: Rs.{equity_module.capital:,.0f}")
            return "\n".join(lines)

        except Exception as e:
            return f"Equity EOD error: {e}"

    @staticmethod
    def generate_weekly_attribution(equity_module, fno_module):
        """
        PATCH_V2_WEEKLY_ATTRIBUTION
        Generate a weekly P&L attribution report grouped by source.
        Reads trade history files (read-only), no orders placed.
        Runs every Sunday at 09:00 IST from main loop.
        """
        try:
            from datetime import datetime, timedelta
            cutoff = now_ist() - timedelta(days=7)

            def _parse_time(t):
                try:
                    return datetime.fromisoformat(t.replace("Z", ""))
                except Exception:
                    return None

            def _load_trades(module):
                try:
                    data = load_json(module._trades_file, {"trades": []})
                    return data.get("trades", [])
                except Exception:
                    return []

            def _filter_week(trades):
                out = []
                for t in trades:
                    et = _parse_time(t.get("exit_time", ""))
                    if et and et.replace(tzinfo=None) >= cutoff.replace(tzinfo=None):
                        out.append(t)
                return out

            eq_trades = _filter_week(_load_trades(equity_module))
            fno_trades = _filter_week(_load_trades(fno_module))

            def _attribute(trades):
                by_source = {}
                for t in trades:
                    src = t.get("source", "UNKNOWN")
                    pnl = t.get("pnl", 0)
                    if src not in by_source:
                        by_source[src] = {"count": 0, "wins": 0, "losses": 0, "pnl": 0.0, "win_pnl": 0.0, "loss_pnl": 0.0}
                    by_source[src]["count"] += 1
                    by_source[src]["pnl"] += pnl
                    if pnl > 0:
                        by_source[src]["wins"] += 1
                        by_source[src]["win_pnl"] += pnl
                    elif pnl < 0:
                        by_source[src]["losses"] += 1
                        by_source[src]["loss_pnl"] += pnl
                return by_source

            eq_attr = _attribute(eq_trades)
            fno_attr = _attribute(fno_trades)

            def _format_section(name, attr, trades):
                if not trades:
                    return f"*{name}*: No trades this week\n"
                total_pnl = sum(t.get("pnl", 0) for t in trades)
                total_count = len(trades)
                wins = sum(1 for t in trades if t.get("pnl", 0) > 0)
                wr = (wins / total_count * 100) if total_count else 0
                lines = [f"*{name}* — {total_count} trades | WR {wr:.0f}% | P&L Rs.{total_pnl:,.0f}"]
                for src in sorted(attr.keys(), key=lambda s: -attr[s]["pnl"]):
                    s = attr[src]
                    src_wr = (s["wins"] / s["count"] * 100) if s["count"] else 0
                    avg_win = (s["win_pnl"] / s["wins"]) if s["wins"] else 0
                    avg_loss = (s["loss_pnl"] / s["losses"]) if s["losses"] else 0
                    pf = (s["win_pnl"] / abs(s["loss_pnl"])) if s["loss_pnl"] != 0 else 0
                    lines.append(
                        f"`{src:12s}` n={s['count']} WR={src_wr:.0f}% PnL=Rs.{s['pnl']:,.0f} PF={pf:.1f}"
                    )
                return "\n".join(lines) + "\n"

            best_eq = max(eq_trades, key=lambda t: t.get("pnl", 0)) if eq_trades else None
            worst_eq = min(eq_trades, key=lambda t: t.get("pnl", 0)) if eq_trades else None
            best_fno = max(fno_trades, key=lambda t: t.get("pnl", 0)) if fno_trades else None
            worst_fno = min(fno_trades, key=lambda t: t.get("pnl", 0)) if fno_trades else None

            msg_lines = [f"*WEEKLY ATTRIBUTION REPORT*"]
            msg_lines.append(f"Period: last 7 days ending {now_ist().strftime('%Y-%m-%d')}")
            msg_lines.append("")
            msg_lines.append(_format_section("EQUITY", eq_attr, eq_trades))
            msg_lines.append(_format_section("F&O", fno_attr, fno_trades))

            if best_eq:
                msg_lines.append(f"Best EQ: {best_eq.get('symbol','?')} Rs.{best_eq.get('pnl',0):,.0f} ({best_eq.get('source','?')})")
            if worst_eq:
                msg_lines.append(f"Worst EQ: {worst_eq.get('symbol','?')} Rs.{worst_eq.get('pnl',0):,.0f} ({worst_eq.get('source','?')})")
            if best_fno:
                msg_lines.append(f"Best FNO: {best_fno.get('tradingsymbol','?')} Rs.{best_fno.get('pnl',0):,.0f} ({best_fno.get('source','?')})")
            if worst_fno:
                msg_lines.append(f"Worst FNO: {worst_fno.get('tradingsymbol','?')} Rs.{worst_fno.get('pnl',0):,.0f} ({worst_fno.get('source','?')})")

            return "\n".join(msg_lines)
        except Exception as e:
            return f"Weekly attribution error: {e}"

    @staticmethod
    def generate_fno_report(fno_module):
        """Generate F&O EOD summary.

        V27 Stage 2 PATCH (Bug #6 follow-up): Filter out phantom positions.
        Only include positions with non-zero qty in Kite. For positions that
        closed today, fetch real exit price from tradebook.
        """
        positions = fno_module.positions
        if not positions:
            return "F&O: No open positions"

        kite = KiteSession.kite()
        if not kite:
            return "F&O: Kite not connected for EOD"

        try:
            # Build Kite truth: which positions have qty != 0
            _kite_qtys = {}
            try:
                for _kp in kite.positions().get("net", []):
                    if _kp.get("exchange") == "NFO":
                        _kite_qtys[_kp.get("tradingsymbol", "")] = _kp.get("quantity", 0)
            except Exception as _ke:
                return f"F&O EOD: Kite positions fetch failed: {_ke}"

            # Build today's tradebook for realized exits
            _tradebook = {}
            try:
                for _t in (kite.trades() or []):
                    if _t.get("exchange") != "NFO":
                        continue
                    _tsym = _t.get("tradingsymbol", "")
                    _ttype = _t.get("transaction_type", "")
                    _qty = _t.get("quantity", 0)
                    _avg = _t.get("average_price", 0)
                    if _tsym not in _tradebook:
                        _tradebook[_tsym] = {"sell_qty": 0, "sell_value": 0}
                    if _ttype == "SELL":
                        _tradebook[_tsym]["sell_qty"] += _qty
                        _tradebook[_tsym]["sell_value"] += _qty * _avg
            except Exception as _te:
                log.warning(f"F&O EOD: tradebook fetch failed: {_te}")

            _open_syms = [t for t, q in _kite_qtys.items() if q != 0]
            _ltp_data = {}
            if _open_syms:
                try:
                    _ltp_data = kite.ltp([f"NFO:{s}" for s in _open_syms])
                except Exception as _le:
                    log.warning(f"F&O EOD: LTP fetch failed: {_le}")

            open_lines, closed_lines = [], []
            total_open_pnl = 0
            total_closed_pnl = 0
            open_count = 0
            closed_count = 0

            for key, pos in positions.items():
                tsym = pos.get("tradingsymbol", "")
                if not tsym:
                    continue
                entry = pos.get("entry_price", 0)
                direction = pos.get("direction", "")
                _kqty = _kite_qtys.get(tsym, 0)

                if _kqty != 0:
                    ltp = _ltp_data.get(f"NFO:{tsym}", {}).get("last_price", 0)
                    pnl = (ltp - entry) * abs(_kqty) if ltp > 0 and entry > 0 else 0
                    total_open_pnl += pnl
                    emoji = "+" if pnl >= 0 else ""
                    open_lines.append(f"`{tsym[:20]:20s}`  {emoji}Rs.{pnl:,.0f} | OPEN | {direction}")
                    open_count += 1
                else:
                    _tb = _tradebook.get(tsym)
                    if _tb and _tb["sell_qty"] > 0:
                        _avg_sell = _tb["sell_value"] / _tb["sell_qty"]
                        _real_pnl = (_avg_sell - entry) * _tb["sell_qty"]
                        total_closed_pnl += _real_pnl
                        emoji = "+" if _real_pnl >= 0 else ""
                        closed_lines.append(f"`{tsym[:20]:20s}`  {emoji}Rs.{_real_pnl:,.0f} | CLOSED at {_avg_sell:,.1f} | {direction}")
                        closed_count += 1
                    else:
                        closed_lines.append(f"`{tsym[:20]:20s}`  CLOSED (no tradebook entry) | {direction}")
                        closed_count += 1

            lines = [f"*F&O EOD: {open_count} open, {closed_count} closed today*\n"]
            if open_lines:
                lines.append("*OPEN POSITIONS:*")
                lines.extend(open_lines)
                lines.append(f"\n*Open Unrealized P&L: Rs.{total_open_pnl:,.0f}*")
            if closed_lines:
                lines.append("\n*CLOSED TODAY:*")
                lines.extend(closed_lines)
                lines.append(f"*Closed Realized P&L: Rs.{total_closed_pnl:,.0f}*")
            lines.append(f"\n*Day Total: Rs.{(total_open_pnl + total_closed_pnl):,.0f}*")
            lines.append(f"F&O Capital: Rs.{fno_module.capital:,.0f}")
            return "\n".join(lines)

        except Exception as e:
            return f"F&O EOD error: {e}"


# ═══════════════════════════════════════════════════════════════════════════════
#  RISK MANAGER — Each module has its own instance
# ═══════════════════════════════════════════════════════════════════════════════

class RiskManager:
    """
    Tracks daily/monthly P&L and enforces risk limits.
    Each module has its own RiskManager — independent tracking.

    Circuit breaker: based on AVERAGE loss per trade (not cumulative).
    """

    def __init__(self, name, capital):
        self.name = name
        self.capital = capital
        # V27 PATCH (Bug #9): Persist breaker state across restarts
        self._state_file = f"/home/globalbot/risk_{name.lower()}.json"
        self._trades_today = []
        self._monthly_pnl = 0.0
        self._halted = False
        self._date = today_ist()
        self._month = today_ist().month
        self._load_state()

    def _load_state(self):
        """V27 PATCH (Bug #9): Reload breaker state on init."""
        try:
            data = load_json(self._state_file, {})
            if not isinstance(data, dict):
                return
            _saved_date = data.get("date", "")
            _saved_month = data.get("month", 0)
            _today = today_ist()
            if _saved_date == _today.isoformat():
                self._trades_today = data.get("trades_today", [])
                self._halted = data.get("halted", False)
                if self._halted:
                    log.warning(f"Risk {self.name}: RESTORED HALT STATE from disk (day={_saved_date})")
            if _saved_month == _today.month:
                self._monthly_pnl = data.get("monthly_pnl", 0.0)
        except Exception as e:
            log.error(f"Risk {self.name}: load state failed: {e}")

    def _save_state(self):
        """V27 PATCH (Bug #9): Persist breaker state."""
        try:
            save_json(self._state_file, {
                "date": self._date.isoformat(),
                "month": self._month,
                "trades_today": self._trades_today,
                "monthly_pnl": self._monthly_pnl,
                "halted": self._halted,
            })
        except Exception as e:
            log.error(f"Risk {self.name}: save state failed: {e}")

    def _check_new_day(self):
        d = today_ist()
        if d != self._date:
            self._trades_today = []
            self._halted = False
            self._date = d
        if d.month != self._month:
            self._monthly_pnl = 0.0
            self._month = d.month

    def record_trade(self, pnl):
        """Record a closed trade's P&L."""
        self._check_new_day()
        self._trades_today.append(pnl)
        self._monthly_pnl += pnl
        self._check_limits()
        self._save_state()  # V27 PATCH (Bug #9): persist after every trade

    def _check_limits(self):
        """Check if we should halt trading."""
        if not self._trades_today:
            return

        # Average loss check (not cumulative)
        avg_pnl = sum(self._trades_today) / len(self._trades_today)
        avg_pct = avg_pnl / self.capital if self.capital > 0 else 0

        if avg_pct < -DAILY_LOSS_AVG_LIMIT:
            self._halted = True
            log.warning(f"Risk {self.name}: HALTED — avg loss {avg_pct:.1%} exceeds {DAILY_LOSS_AVG_LIMIT:.0%}")

        # Monthly loss check
        monthly_pct = self._monthly_pnl / self.capital if self.capital > 0 else 0
        if monthly_pct < -MONTHLY_LOSS_LIMIT:
            self._halted = True
            log.warning(f"Risk {self.name}: HALTED — monthly loss {monthly_pct:.1%} exceeds {MONTHLY_LOSS_LIMIT:.0%}")

    def can_trade(self):
        """Can this module place new trades?"""
        self._check_new_day()
        return not self._halted

    def update_capital(self, new_capital):
        self.capital = new_capital



# ═══════════════════════════════════════════════════════════════════════════════
#  SAFETY FILTERS — Circuit limit, Nifty crash, correlation, bad stock
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
#  EQUITY SMART SCANNERS — Proactive stock discovery
# ═══════════════════════════════════════════════════════════════════════════════

class EquitySmartScanner:
    """
    Proactive equity scanners that find opportunities WITHOUT waiting for news.
    Each scanner runs independently during market hours.
    """

    @staticmethod
    def scan_52week_low_recovery(kite, valid_symbols, trendlyne):
        """
        Find stocks near 52-week low with strong fundamentals.
        These are beaten-down quality stocks — buy when everyone is scared.
        Vijay Kedia style: buy what others think is worthless.
        """
        candidates = []
        try:
            # Get Nifty 500 or scan all symbols in batches
            batch_size = 50
            sym_list = list(valid_symbols)[:500]  # Top 500 by market cap

            for i in range(0, len(sym_list), batch_size):
                batch = sym_list[i:i+batch_size]
                try:
                    quotes = kite.quote([f"NSE:{s}" for s in batch])
                    for sym in batch:
                        q = quotes.get(f"NSE:{sym}", {})
                        ltp = q.get("last_price", 0)
                        ohlc = q.get("ohlc", {})
                        low_52 = ohlc.get("low", 0)  # 52-week low
                        high_52 = ohlc.get("high", 0)  # 52-week high

                        if ltp <= 0 or low_52 <= 0 or high_52 <= 0:
                            continue

                        # Stock within 15% of 52-week low
                        pct_from_low = (ltp - low_52) / low_52 if low_52 > 0 else 999
                        if pct_from_low > 0.15:
                            continue  # Not near 52-week low

                        # Must have good fundamentals (Trendlyne score >= 50)
                        if trendlyne and trendlyne.score(sym) < 50:
                            continue

                        # Must have fallen at least 30% from high (genuine beaten down)
                        pct_from_high = (high_52 - ltp) / high_52 if high_52 > 0 else 0
                        if pct_from_high < 0.30:
                            continue

                        score = 70 + int(pct_from_high * 30)  # Higher score for more beaten down
                        candidates.append({
                            "symbol": sym,
                            "direction": "BULLISH",
                            "score": min(score, 90),
                            "catalyst": f"52WK LOW RECOVERY: {sym} at {pct_from_low:.0%} from low, down {pct_from_high:.0%} from high",
                            "source": "52WK_LOW",
                        })
                except Exception:
                    pass
                time.sleep(0.5)  # Rate limit

        except Exception as e:
            log.debug(f"52wk scanner error: {e}")

        if candidates:
            log.info(f"52wk low scanner: {len(candidates)} recovery candidates")
        return candidates[:10]  # Top 10

    @staticmethod
    def scan_promoter_increase(kite, valid_symbols):
        """
        Find stocks where promoter holding has increased.
        Promoter buying = ultimate insider confidence signal.
        Scan NSE SAST filings for shareholding changes.
        """
        candidates = []
        try:
            session = requests.Session()
            session.headers.update({
                "User-Agent": "Mozilla/5.0",
                "Accept": "application/json",
            })
            session.get("https://www.nseindia.com", timeout=10)
            time.sleep(0.5)

            today = today_ist()
            from_date = (today - timedelta(days=7)).strftime("%d-%m-%Y")
            to_date = today.strftime("%d-%m-%Y")

            url = f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={from_date}&to_date={to_date}"
            resp = session.get(url, timeout=15)

            if resp.status_code == 200:
                filings = resp.json()
                if isinstance(filings, list):
                    for f in filings[:200]:
                        subject = f.get("desc", "").lower()
                        symbol = f.get("symbol", "")
                        if not symbol or symbol not in valid_symbols:
                            continue

                        # Look for promoter increase signals
                        if any(kw in subject for kw in [
                            "increase in shareholding", "acquired shares",
                            "promoter buy", "promoter acqui", "sast",
                            "increase in stake", "open market purchase"
                        ]):
                            candidates.append({
                                "symbol": symbol,
                                "direction": "BULLISH",
                                "score": 85,  # High score — promoter buying is strongest signal
                                "catalyst": f"PROMOTER INCREASE: {subject[:80]}",
                                "source": "PROMOTER_BUY",
                            })

        except Exception as e:
            log.debug(f"Promoter scanner error: {e}")

        if candidates:
            log.info(f"Promoter scanner: {len(candidates)} insider buying signals")
        return candidates

    @staticmethod
    def scan_sector_rotation(kite):
        """
        Detect which sectors money is flowing INTO and OUT OF.
        Buy stocks in strengthening sectors, avoid weakening sectors.
        Recovery cycle: Banks → Infra → Auto → Consumer → IT
        """
        candidates = []
        SECTOR_INDICES = {
            "BANKING": "NSE:NIFTY BANK",
            "IT": "NSE:NIFTY IT",
            "PHARMA": "NSE:NIFTY PHARMA",
            "FMCG": "NSE:NIFTY FMCG CONSUMPTION",
            "AUTO": "NSE:NIFTY AUTO",
            "METALS": "NSE:NIFTY METAL",
            "ENERGY": "NSE:NIFTY ENERGY",
            "INFRA": "NSE:NIFTY INFRA",
        }

        SECTOR_STOCKS = {
            "BANKING": ["HDFCBANK", "ICICIBANK", "SBIN", "KOTAKBANK", "AXISBANK"],
            "IT": ["TCS", "INFY", "WIPRO", "HCLTECH", "TECHM"],
            "PHARMA": ["SUNPHARMA", "DRREDDY", "CIPLA", "DIVISLAB"],
            "FMCG": ["HINDUNILVR", "ITC", "NESTLEIND", "BRITANNIA"],
            "AUTO": ["MARUTI", "TATAMOTORS", "M&M", "BAJAJ-AUTO"],
            "METALS": ["TATASTEEL", "JSWSTEEL", "HINDALCO", "VEDL"],
            "ENERGY": ["RELIANCE", "ONGC", "BPCL", "NTPC"],
            "INFRA": ["LT", "ADANIENT", "ADANIPORTS"],
        }

        try:
            # Get sector index performance
            idx_list = list(SECTOR_INDICES.values())
            idx_list.append("NSE:NIFTY 50")  # Benchmark
            quotes = kite.quote(idx_list)

            nifty_q = quotes.get("NSE:NIFTY 50", {})
            nifty_change = 0
            nifty_prev = nifty_q.get("ohlc", {}).get("close", 0)
            nifty_ltp = nifty_q.get("last_price", 0)
            if nifty_prev > 0 and nifty_ltp > 0:
                nifty_change = (nifty_ltp - nifty_prev) / nifty_prev

            strong_sectors = []
            weak_sectors = []

            for sector, idx_sym in SECTOR_INDICES.items():
                q = quotes.get(idx_sym, {})
                prev = q.get("ohlc", {}).get("close", 0)
                ltp = q.get("last_price", 0)
                if prev <= 0 or ltp <= 0:
                    continue

                change = (ltp - prev) / prev
                relative = change - nifty_change  # Performance vs Nifty

                if relative > 0.005:  # Outperforming Nifty by 0.5%+
                    strong_sectors.append((sector, relative))
                elif relative < -0.005:  # Underperforming by 0.5%+
                    weak_sectors.append((sector, relative))

            # Buy stocks in strong sectors
            for sector, rel_perf in sorted(strong_sectors, key=lambda x: x[1], reverse=True)[:3]:
                stocks = SECTOR_STOCKS.get(sector, [])
                for sym in stocks[:2]:  # Top 2 per sector
                    candidates.append({
                        "symbol": sym,
                        "direction": "BULLISH",
                        "score": 65 + int(rel_perf * 1000),  # Higher score for stronger rotation
                        "catalyst": f"SECTOR ROTATION: {sector} outperforming Nifty by {rel_perf:.1%}",
                        "source": "SECTOR_ROTATION",
                    })

        except Exception as e:
            log.debug(f"Sector rotation error: {e}")

        if candidates:
            log.info(f"Sector rotation: {len(candidates)} rotation candidates from {len(strong_sectors)} strong sectors")
        return candidates

    @staticmethod
    def scan_breakout(kite, valid_symbols):
        """
        Find stocks breaking 52-week high on above-average volume.
        Breakout + volume = institutional participation = strong trend start.
        """
        candidates = []
        try:
            sym_list = list(valid_symbols)[:500]
            batch_size = 50

            for i in range(0, len(sym_list), batch_size):
                batch = sym_list[i:i+batch_size]
                try:
                    quotes = kite.quote([f"NSE:{s}" for s in batch])
                    for sym in batch:
                        q = quotes.get(f"NSE:{sym}", {})
                        ltp = q.get("last_price", 0)
                        ohlc = q.get("ohlc", {})
                        high_52 = ohlc.get("high", 0)
                        volume = q.get("volume", 0)
                        avg_volume = q.get("average_volume", 0)

                        if ltp <= 0 or high_52 <= 0:
                            continue

                        # Stock at or above 52-week high
                        pct_from_high = (ltp - high_52) / high_52 if high_52 > 0 else -1
                        if pct_from_high < -0.02:  # Must be within 2% of 52-week high
                            continue

                        # Volume must be above average
                        if avg_volume > 0 and volume > 0:
                            vol_ratio = volume / avg_volume
                            if vol_ratio < 1.5:  # Need 1.5x average volume
                                continue
                        else:
                            continue

                        score = 75 + int(min(vol_ratio, 5) * 3)
                        candidates.append({
                            "symbol": sym,
                            "direction": "BULLISH",
                            "score": min(score, 90),
                            "catalyst": f"BREAKOUT: {sym} at 52wk high, volume {vol_ratio:.1f}x average",
                            "source": "BREAKOUT",
                        })
                except Exception:
                    pass
                time.sleep(0.5)

        except Exception as e:
            log.debug(f"Breakout scanner error: {e}")

        if candidates:
            log.info(f"Breakout scanner: {len(candidates)} breakout candidates")
        return candidates[:10]


class SafetyFilters:
    _circuit_stocks = set()

    @classmethod
    def check_circuit(cls, kite, symbol):
        try:
            q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
            ltp = q.get("last_price", 0)
            lower = q.get("lower_circuit_limit", 0)
            upper = q.get("upper_circuit_limit", 0)
            if ltp <= 0: return True
            if upper > 0 and ltp >= upper * 0.995:
                log.warning(f"Safety: {symbol} at UPPER circuit")
                return False
            if lower > 0 and ltp <= lower * 1.005:
                log.warning(f"Safety: {symbol} at LOWER circuit")
                cls._circuit_stocks.add(symbol)
                return False
            cls._circuit_stocks.discard(symbol)
            return True
        except Exception: return True  # V28 A8

    @classmethod
    def check_nifty_crash(cls, kite):
        try:
            q = kite.quote(["NSE:NIFTY 50"]).get("NSE:NIFTY 50", {})
            ltp = q.get("last_price", 0)
            prev = q.get("ohlc", {}).get("close", 0)
            if ltp <= 0 or prev <= 0: return True
            if (ltp - prev) / prev < -CRASH_NIFTY_DROP:
                log.warning(f"Safety: NIFTY CRASH! Blocking ALL entries")
                return False
            return True
        except Exception: return True  # V28 A8

    CORRELATED = {
        "PVT_BANK": {"HDFCBANK","ICICIBANK","KOTAKBANK","AXISBANK","INDUSINDBK","FEDERALBNK","BANDHANBNK"},
        "PSU_BANK": {"SBIN","PNB","BANKBARODA","CANBK","UNIONBANK","IOB"},
        "IT": {"TCS","INFY","WIPRO","HCLTECH","TECHM","LTIM"},
        "PHARMA": {"SUNPHARMA","DRREDDY","CIPLA","DIVISLAB","BIOCON","AUROPHARMA","LUPIN"},
        "OIL": {"RELIANCE","ONGC","BPCL","IOC","GAIL","HINDPETRO"},
        "METALS": {"TATASTEEL","JSWSTEEL","HINDALCO","VEDL","NMDC","COALINDIA"},
        "ADANI": {"ADANIENT","ADANIPORTS","ADANIGREEN","ADANIPOWER","ATGL"},
        "TATA": {"TCS","TATAMOTORS","TATASTEEL","TATAPOWER","TATACONSUM","TITAN"},
        "AUTO": {"MARUTI","TATAMOTORS","M&M","BAJAJ-AUTO","HEROMOTOCO","ASHOKLEY"},
        "FMCG": {"HINDUNILVR","ITC","NESTLEIND","BRITANNIA","DABUR","MARICO"},
        "INFRA": {"LT","ADANIENT","ADANIPORTS","NCC","NBCC"},
        "INSURANCE": {"HDFCLIFE","SBILIFE","ICICIPRULI","MAXHEALTH","STARHEALTH"},
    }

    @classmethod
    def check_correlation(cls, symbol, positions):
        existing = set(positions.keys()) if isinstance(positions, dict) else set()
        for grp, stocks in cls.CORRELATED.items():
            if symbol in stocks:
                overlap = existing & stocks
                if len(overlap) >= 2:
                    log.info(f"Safety: {symbol} blocked — {len(overlap)} in {grp}")
                    return False
        return True

    @classmethod
    def is_bad_stock(cls, kite, symbol):
        if symbol in cls._circuit_stocks or symbol in BLACKLIST:
            return True
        try:
            q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
            if 0 < q.get("last_price", 0) < 10: return True
            if q.get("volume", 0) == 0: return True
            return False
        except Exception: return False  # V28 A8


class OrderGuard:
    """
    Prevents duplicate orders and enforces SEBI compliance.
    - No duplicate BUY for same symbol within 30 minutes
    - No duplicate F&O contract (same tradingsymbol)
    - SEBI rate limit: max 10 orders/second, max 200 orders/day
    - Market hours enforcement
    """
    _recent_orders = {}  # symbol -> timestamp of last order
    _daily_count = 0
    _daily_date = None
    _second_count = 0
    _second_ts = 0

    @classmethod
    def _reset_daily(cls):
        today = today_ist()
        if cls._daily_date != today:
            cls._daily_count = 0
            cls._daily_date = today

    @classmethod
    def can_place_order(cls, symbol, is_fno=False):
        """
        Check all order guards before placing.
        Returns (True, "OK") or (False, "reason").
        """
        cls._reset_daily()
        now = time.time()

        # SEBI: max 200 orders/day
        if cls._daily_count >= 200:
            return False, "SEBI_DAILY_LIMIT_200"

        # SEBI: max 10 orders/second
        if now - cls._second_ts < 1:
            cls._second_count += 1
            if cls._second_count >= 10:
                return False, "SEBI_RATE_LIMIT_10/sec"
        else:
            cls._second_ts = now
            cls._second_count = 0

        # Market hours check (skip for AMO)
        if not is_market_hours() and not is_amo_window():
            return False, "MARKET_CLOSED"

        # Duplicate check: same symbol within 30 minutes
        last_time = cls._recent_orders.get(symbol, 0)
        if now - last_time < 1800:  # 30 minutes
            mins_ago = int((now - last_time) / 60)
            return False, f"DUPLICATE_ORDER_{mins_ago}min_ago"

        return True, "OK"

    @classmethod
    def record_order(cls, symbol):
        """Record that an order was placed for this symbol."""
        cls._recent_orders[symbol] = time.time()
        cls._daily_count += 1
        # Clean old entries (older than 2 hours)
        now = time.time()
        cls._recent_orders = {s: t for s, t in cls._recent_orders.items() if now - t < 7200}

    @classmethod
    def check_pending_orders(cls, kite, symbol, is_fno=False):
        """
        Check if there's already a pending BUY order for this symbol on Kite.
        V28 A7: Exact match for equity; F&O matches contracts starting with underlying.
        Equity path no longer false-blocks when an F&O contract of same underlying is pending.
        """
        try:
            orders = kite.orders()
            for o in orders:
                ts = o.get("tradingsymbol", "")
                exch = o.get("exchange", "")
                if o.get("transaction_type") != "BUY":
                    continue
                if o.get("status") not in ("OPEN", "TRIGGER PENDING", "AMO REQ RECEIVED"):
                    continue
                # V28 A7: correct matching per exchange
                if is_fno:
                    # F&O contracts live on NFO and are like SBIN26APR820CE
                    if exch == "NFO" and ts.startswith(symbol):
                        log.info(f"OrderGuard: {symbol} already has pending F&O BUY {o.get('order_id')} ({ts})")
                        return True
                else:
                    # Equity: exact match on NSE only
                    if exch == "NSE" and ts == symbol:
                        log.info(f"OrderGuard: {symbol} already has pending equity BUY {o.get('order_id')}")
                        return True
            return False
        except Exception:
            return False


# ═══════════════════════════════════════════════════════════════════════════════
#  EQUITY MODULE — Completely independent. No F&O awareness.
# ═══════════════════════════════════════════════════════════════════════════════

class EquityModule:
    """
    CNC delivery equity trading.

    Entry: News/filing catalyst + RSI not overbought + Volume above avg
    Exit:  Trailing SL (2.5% below LTP, only moves UP) + Dead money (15 days)
    Protection: GTT on every position, checked/modified every 5 min

    Own news scanner, own GTT manager, own risk manager, own capital.
    Zero awareness of F&O module.
    """

    def __init__(self):
        self.positions = {}     # symbol -> position dict
        self.gtt = GTTManager("EQUITY")
        self.risk = None        # Initialized after capital is known
        self.telegram = TelegramThrottle("EQUITY", max_per_hour=15)
        self.news = None        # Initialized after symbols are loaded
        self.filings = None     # FilingMonitor
        self.brokerage = None   # BrokerageMonitor
        self.macro = None       # MacroDetector
        self.trendlyne = TrendlyneScorer()
        self.amo = AMOEngine("EQUITY")
        self.capital = 0
        self.available = 0
        self.all_symbols = set()
        self.fno_stocks = set()  # Loaded from Kite
        self._pos_file = DATA_DIR / "equity_positions.json"
        self._trades_file = DATA_DIR / "equity_trades.json"
        self._last_scan = None
        self._last_trail_check = None

    def init(self):
        """Initialize after Kite login."""
        kite = KiteSession.kite()
        if not kite:
            log.error("Equity: cannot init without Kite")
            return False

        # Load all NSE symbols
        try:
            instruments = kite.instruments("NSE")
            self.all_symbols = set()
            for inst in instruments:
                sym = inst.get("tradingsymbol", "")
                if is_valid_symbol(sym) and inst.get("instrument_type") == "EQ":
                    price = inst.get("last_price", 0)
                    # Skip penny stocks (< Rs.5)
                    if price and price < 5:
                        continue
                    self.all_symbols.add(sym)
            log.info(f"Equity: {len(self.all_symbols)} valid stocks loaded")
        except Exception as e:
            log.error(f"Equity: instrument load failed: {e}")
            return False

        # Get capital
        self._refresh_capital()

        # Init risk manager
        self.risk = RiskManager("EQUITY", self.capital)

        # PATCH_V28_SYMBOL_REGEX: build company name -> symbol map from instruments
        self._name_map = {}
        try:
            for inst in instruments:
                _n = inst.get("name", "").upper().strip()
                _s = inst.get("tradingsymbol", "")
                if _n and _s and inst.get("instrument_type") == "EQ":
                    self._name_map[_n] = _s
                    # Also add first 2 words as key (e.g. "TATA CONSULTANCY" -> TCS)
                    _words = _n.split()
                    if len(_words) >= 2:
                        self._name_map[" ".join(_words[:2])] = _s
            log.info(f"[PATCH_V28_SYMBOL_REGEX] built name_map with {len(self._name_map)} entries")
        except Exception as _nme:
            log.warning(f"[PATCH_V28_SYMBOL_REGEX] name_map build failed: {_nme}")

        # Init news scanner with equity symbols + name mapping
        self.news = NewsScanner("EQUITY", self.all_symbols, name_map=self._name_map)

        # Init filing monitor
        self.filings = FilingMonitor("EQUITY", self.all_symbols)

        # Init brokerage monitor
        self.brokerage = BrokerageMonitor("EQUITY", self.all_symbols)

        # Init macro detector
        self.macro = MacroDetector("EQUITY", self.all_symbols)

        # PATCH_V28_KITE_ONLY_EQUITY: DO NOT load from JSON. Kite is the only source of truth.
        # Same pattern as F&O V28_KITE_ONLY. Eliminates JBCHEPHARM-class phantom positions.
        # _sync_holdings() handles all stages: same-day (positions), T1, T2 (holdings).
        self.positions = {}  # start empty, populate from Kite only

        # Sync with Kite holdings — this is now the ONLY source of positions
        self._sync_holdings()

        # Run GTT audit
        self._gtt_audit()

        log.info(f"Equity: init complete. Capital=Rs.{self.capital:,.0f} Positions={len(self.positions)}")
        self.telegram.send(
            f"Equity Module started\n"
            f"Capital: Rs.{self.capital:,.0f}\n"
            f"Positions: {len(self.positions)}\n"
            f"Stocks scanned: {len(self.all_symbols)}",
            force=True,
        )
        return True

    def _refresh_capital(self):
        """Get real capital from Kite.
        PATCH_V10_CAPITAL_RETRY: retry up to 3 times with 1s delay if Kite returns 0.
        """
        kite = KiteSession.kite()
        if not kite:
            return
        import time as _t
        total = 0
        for _attempt in range(1, 4):
            try:
                margins = kite.margins("equity")
                _t1 = margins.get("net", 0) or margins.get("available", {}).get("live_balance", 0)
                if not _t1:
                    _t1 = margins.get("available", {}).get("cash", 0)
                if _t1 and _t1 > 0:
                    total = _t1
                    break
                log.warning(f"[PATCH_V10_CAPITAL_RETRY] Equity attempt {_attempt}/3: Kite returned 0, retrying")
            except Exception as _e:
                log.warning(f"[PATCH_V10_CAPITAL_RETRY] Equity attempt {_attempt}/3: {type(_e).__name__}: {_e}")
            if _attempt < 3:
                _t.sleep(1)
        if total > 0:
            self.capital = round(total * EQUITY_PCT, 2)
            invested = sum(
                p.get("qty", 0) * p.get("entry_price", 0)
                for p in self.positions.values()
            )
            self.available = max(0, self.capital - invested)
            log.info(f"[PATCH_V10_CAPITAL_RETRY] Equity refreshed: total={total} capital={self.capital} available={self.available}")
        else:
            log.warning(f"[PATCH_V10_CAPITAL_RETRY] Equity: all 3 attempts returned 0, preserving previous capital={self.capital}")

    def _load_positions(self):
        """Load positions from file."""
        data = load_json(self._pos_file, {"positions": {}})
        self.positions = data.get("positions", {})
        # Remove blacklisted
        for sym in list(self.positions.keys()):
            if sym in BLACKLIST:
                del self.positions[sym]

    def _save_positions(self):
        """Save positions to file."""
        save_json(self._pos_file, {"positions": self.positions})

    def _sync_holdings(self):
        """
        Sync with Kite holdings. Every stock in Kite = bot owned.
        No adoption concept — just sync.
        """
        kite = KiteSession.kite()
        if not kite:
            return

        try:
            holdings = kite.holdings()
            kite_syms = {}
            for h in holdings:
                sym = h.get("tradingsymbol", "")
                qty = h.get("quantity", 0) + h.get("t1_quantity", 0)
                avg = h.get("average_price", 0)
                if qty > 0 and sym and sym not in BLACKLIST:
                    kite_syms[sym] = {"qty": qty, "avg": avg}
            
            # Also check positions (day trades not yet settled)
            positions = kite.positions().get("net", [])
            for p in positions:
                sym = p.get("tradingsymbol", "")
                qty = p.get("quantity", 0)
                avg = p.get("average_price", 0)
                exch = p.get("exchange", "")
                if qty > 0 and sym and sym not in BLACKLIST and exch == "NSE":
                    if sym not in kite_syms:
                        kite_syms[sym] = {"qty": qty, "avg": avg}

            # Add Kite holdings not in our positions
            for sym, info in kite_syms.items():
                if sym not in self.positions:
                    # PATCH_V1_RESTART_PEAK
                    _live_sl = round(info["avg"] * (1 - EQ_INITIAL_SL_PCT), 2)
                    _live_peak = info["avg"]
                    try:
                        _existing_gtts = kite.get_gtts() or []
                        for _g in _existing_gtts:
                            if _g.get("status") != "active":
                                continue
                            _cond = _g.get("condition", {})
                            if _cond.get("tradingsymbol") == sym and _cond.get("exchange") == "NSE":
                                _triggers = _cond.get("trigger_values", [])
                                if _triggers and _triggers[0] > 0:
                                    _live_sl = max(_live_sl, float(_triggers[0]))
                                    log.info(f"Equity sync: {sym} using live GTT SL={_live_sl}")
                                    break
                    except Exception as _e:
                        log.warning(f"Equity sync: GTT lookup failed for {sym}: {_e}")
                    try:
                        _ltp_data = kite.ltp([f"NSE:{sym}"])
                        _cur_ltp = _ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                        if _cur_ltp > 0:
                            _live_peak = max(_live_peak, _cur_ltp)
                    except Exception as _e:
                        log.warning(f"Equity sync: LTP lookup failed for {sym}: {_e}")
                    # END_PATCH_V1_RESTART_PEAK
                    self.positions[sym] = {
                        "symbol": sym,
                        "qty": info["qty"],
                        "entry_price": info["avg"],
                        "entry_time": now_ist().isoformat(),
                        "sl": _live_sl,
                        "target": 0,
                        "peak_price": _live_peak,
                        "source": "KITE_SYNC",
                    }
                    log.info(f"Equity: synced {sym} qty={info['qty']} avg={info['avg']} sl={_live_sl} peak={_live_peak}")

            # V27 PATCH (Bug #6): Remove positions not in Kite, fetch REAL exit price
            # from tradebook (was recording 0, polluting all P&L reports).
            for sym in list(self.positions.keys()):
                if sym not in kite_syms:
                    pos = self.positions[sym]
                    _exit_price = 0
                    _reason = "SOLD_EXTERNAL"
                    try:
                        _trades = kite.trades() or []
                        _sym_sells = []
                        for _t in _trades:
                            if (_t.get("tradingsymbol") == sym
                                and _t.get("exchange") == "NSE"
                                and _t.get("transaction_type") == "SELL"):
                                _sym_sells.append(_t)
                        if _sym_sells:
                            _total_qty = sum(_t.get("quantity", 0) for _t in _sym_sells)
                            _total_val = sum(_t.get("quantity", 0) * _t.get("average_price", 0) for _t in _sym_sells)
                            if _total_qty > 0:
                                _exit_price = round(_total_val / _total_qty, 2)
                                _reason = "MANUAL_SELL"
                                log.info(f"Equity: {sym} external sell detected - exit_price={_exit_price} from tradebook")
                    except Exception as _te:
                        log.warning(f"Equity: tradebook lookup for {sym} failed: {_te}, recording exit=0")
                    self._record_trade(sym, pos, _exit_price, _reason)
                    del self.positions[sym]
                    log.info(f"Equity: removed {sym} (exit_price={_exit_price} reason={_reason})")

            self._save_positions()

        except Exception as e:
            log.error(f"Equity: sync holdings failed: {e}")

    def _gtt_audit(self):
        """
        Ensure every holding has exactly 1 GTT.
        Source of truth: Kite holdings (NOT JSON file).
        """
        kite = KiteSession.kite()
        if not kite:
            return
        
        try:
            # Step 1: What do I ACTUALLY own? (Kite = truth)
            # Check BOTH holdings AND positions — covers T1, T2, and day positions
            kite_holdings = {}
            
            # Holdings (settled + T1)
            holdings = kite.holdings()
            for h in holdings:
                sym = h.get("tradingsymbol", "")
                qty = h.get("quantity", 0) + h.get("t1_quantity", 0)
                avg = h.get("average_price", 0)
                if qty > 0 and sym and sym not in BLACKLIST:
                    kite_holdings[sym] = {"qty": qty, "avg": avg}
            
            # Positions (day positions, not yet in holdings)
            positions = kite.positions().get("net", [])
            for p in positions:
                sym = p.get("tradingsymbol", "")
                qty = p.get("quantity", 0)
                avg = p.get("average_price", 0)
                exch = p.get("exchange", "")
                if qty > 0 and sym and sym not in BLACKLIST and exch == "NSE":
                    if sym not in kite_holdings:
                        kite_holdings[sym] = {"qty": qty, "avg": avg}
                    else:
                        kite_holdings[sym]["qty"] += qty
            
            # Step 2: What GTTs exist? (Kite = truth)
            all_gtts = kite.get_gtts() or []
            gtt_by_sym = defaultdict(list)
            for g in all_gtts:
                if g.get("status") == "active":
                    sym = g.get("condition", {}).get("tradingsymbol", "")
                    exch = g.get("condition", {}).get("exchange", "")
                    if sym and exch == "NSE":
                        gtt_by_sym[sym].append(g)
            
            placed, modified, deleted = 0, 0, 0
            
            # Step 3: Delete duplicates (keep newest per symbol)
            for sym, gtts in gtt_by_sym.items():
                if len(gtts) > 1:
                    gtts.sort(key=lambda g: g.get("id", 0), reverse=True)
                    for dup in gtts[1:]:
                        try:
                            kite.delete_gtt(dup["id"])
                            deleted += 1
                            log.info(f"GTT EQUITY: deleted duplicate {sym} id={dup['id']}")
                        except Exception:
                            pass
            
            # Step 4: Delete orphans (GTT exists but stock not in holdings)
            for sym in list(gtt_by_sym.keys()):
                if sym not in kite_holdings:
                    for g in gtt_by_sym[sym]:
                        try:
                            kite.delete_gtt(g["id"])
                            deleted += 1
                            log.info(f"GTT EQUITY: deleted orphan {sym} id={g['id']}")
                        except Exception:
                            pass
            
            # Step 5: Ensure every holding has GTT with valid triggers
            ltp_data = kite.ltp([f"NSE:{s}" for s in kite_holdings]) if kite_holdings else {}
            
            for sym, info in kite_holdings.items():
                qty = info["qty"]
                ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                if ltp <= 0:
                    ltp = info["avg"]
                
                # FIX_V29_SINGLE_ONLY: all GTTs are SINGLE (SL-only). Software handles target exit.
                # FIX_V29_SL_PROTECT: use max(fresh_sl, position_sl) to never lower SL on new placement.
                sl = round(ltp * (1 - EQ_TRAIL_SL_PCT), 1)
                _pos_sl = self.positions.get(sym, {}).get("sl", 0)
                if _pos_sl > 0:
                    sl = max(sl, round(_pos_sl, 1))
                
                existing_gtts = gtt_by_sym.get(sym, [])
                
                if not existing_gtts:
                    # No GTT — place new SINGLE SL-only
                    try:
                        gtt_id = kite.place_gtt(
                            trigger_type=kite.GTT_TYPE_SINGLE,
                            tradingsymbol=sym, exchange="NSE",
                            trigger_values=[sl], last_price=ltp,
                            orders=[
                                {"transaction_type": "SELL", "quantity": qty, "price": round(sl * 0.98, 1), "order_type": "LIMIT", "product": "CNC"},
                            ],
                        )
                        placed += 1
                        log.info(f"GTT EQUITY: placed {sym} SL={sl} (SINGLE) id={gtt_id}")
                    except Exception as e:
                        log.error(f"GTT EQUITY: place {sym} failed: {e}")
                else:
                    # GTT exists — check if triggers are valid
                    gtt = existing_gtts[0]
                    triggers = gtt.get("trigger_values", [])
                    if not triggers or len(triggers) == 0:
                        # Empty triggers — delete and re-place as SINGLE
                        try:
                            kite.delete_gtt(gtt["id"])
                            gtt_id = kite.place_gtt(
                                trigger_type=kite.GTT_TYPE_SINGLE,
                                tradingsymbol=sym, exchange="NSE",
                                trigger_values=[sl], last_price=ltp,
                                orders=[
                                    {"transaction_type": "SELL", "quantity": qty, "price": round(sl * 0.98, 1), "order_type": "LIMIT", "product": "CNC"},
                                ],
                            )
                            placed += 1
                            log.info(f"GTT EQUITY: re-placed {sym} (empty triggers) SL={sl} (SINGLE)")
                        except Exception as e:
                            log.error(f"GTT EQUITY: re-place {sym} failed: {e}")
                    else:
                        # Valid triggers — check if SL should be trailed up
                        old_sl = triggers[0] if triggers else 0
                        if sl > old_sl:
                            # FIX_V29_SINGLE_ONLY: always modify as SINGLE
                            try:
                                kite.modify_gtt(
                                    trigger_id=gtt["id"], trigger_type=kite.GTT_TYPE_SINGLE,
                                    tradingsymbol=sym, exchange="NSE",
                                    trigger_values=[sl], last_price=ltp,
                                    orders=[
                                        {"transaction_type": "SELL", "quantity": qty, "price": round(sl * 0.98, 1), "order_type": "LIMIT", "product": "CNC"},
                                    ],
                                )
                                modified += 1
                                log.info(f"GTT EQUITY: modified {sym} SL {old_sl}->{sl}")
                            except Exception:
                                # Modify failed (type mismatch etc) — delete and re-place as SINGLE
                                try:
                                    kite.delete_gtt(gtt["id"])
                                    kite.place_gtt(
                                        trigger_type=kite.GTT_TYPE_SINGLE,
                                        tradingsymbol=sym, exchange="NSE",
                                        trigger_values=[sl], last_price=ltp,
                                        orders=[
                                            {"transaction_type": "SELL", "quantity": qty, "price": round(sl * 0.98, 1), "order_type": "LIMIT", "product": "CNC"},
                                        ],
                                    )
                                    placed += 1
                                    log.info(f"GTT EQUITY: re-placed {sym} (modify failed) SL={sl} (SINGLE)")
                                except Exception as e2:
                                    log.error(f"GTT EQUITY: re-place {sym} failed: {e2}")
                        else:
                            modified += 1
            
            log.info(f"GTT EQUITY AUDIT: placed={placed} modified={modified} deleted={deleted}")
        
        except Exception as e:
            log.error(f"GTT EQUITY audit error: {e}")

    def _record_trade(self, symbol, pos, exit_price, reason):
        """Record a completed trade."""
        entry = pos.get("entry_price", 0)
        qty = pos.get("qty", 0)
        pnl = (exit_price - entry) * qty if exit_price > 0 else 0
        trade = {
            "symbol": symbol,
            "entry_price": entry,
            "exit_price": exit_price,
            "qty": qty,
            "pnl": round(pnl, 2),
            "reason": reason,
            "entry_time": pos.get("entry_time", ""),
            "exit_time": now_ist().isoformat(),
            "source": pos.get("source", "UNKNOWN"),
        }
        # Append to trades file
        trades = load_json(self._trades_file, {"trades": []})
        trades["trades"].append(trade)
        save_json(self._trades_file, trades)

        if self.risk and pnl != 0:
            self.risk.record_trade(pnl)

    # ── ENTRY LOGIC ──

    # V28 A1: Kite-holdings cache (30s) to avoid hammering API
    _kite_holdings_cache = {"ts": 0, "syms": set()}

    @classmethod
    def _kite_held_symbols(cls):
        """Get currently held equity symbols from Kite (cached 30s).
        Returns None if Kite unreachable so caller can fall back to local JSON.
        """
        import time as _t
        now = _t.time()
        if now - cls._kite_holdings_cache["ts"] < 30:
            return cls._kite_holdings_cache["syms"]
        kite = KiteSession.kite()
        if not kite:
            return None
        try:
            held = set()
            for h in (kite.holdings() or []):
                sym = h.get("tradingsymbol", "")
                qty = h.get("quantity", 0) + h.get("t1_quantity", 0)
                if sym and qty > 0:
                    held.add(sym)
            # Also include same-day positions on NSE (not yet holdings)
            for p in (kite.positions().get("net", []) or []):
                if p.get("exchange") == "NSE" and p.get("quantity", 0) > 0:
                    ts = p.get("tradingsymbol", "")
                    if ts:
                        held.add(ts)
            cls._kite_holdings_cache = {"ts": now, "syms": held}
            return held
        except Exception as e:
            log.warning(f"_kite_held_symbols: kite.holdings() failed: {e}")
            return None

    def _can_enter(self, symbol):
        """Pre-entry checks.
        V28 A1: Authoritative position count comes from Kite, not stale local JSON.
        """
        if symbol in BLACKLIST:
            return False, "BLACKLISTED"
        if symbol in self.positions:
            return False, "ALREADY_HELD"

        # V28 A1: check Kite live
        held = EquityModule._kite_held_symbols()
        if held is not None:
            if symbol in held:
                return False, "ALREADY_HELD_ON_KITE"
            if len(held) >= EQ_MAX_POS:
                return False, f"KITE_MAX_POSITIONS_{len(held)}"
            # Sector limit based on LIVE Kite holdings
            sector = get_sector(symbol)
            sector_count = sum(1 for s in held if get_sector(s) == sector)
            if sector_count >= EQ_MAX_PER_SECTOR:
                return False, f"SECTOR_LIMIT_KITE_{sector}"
        else:
            # Fallback to local JSON if Kite unreachable (safer to under-trade)
            if len(self.positions) >= EQ_MAX_POS:
                return False, "MAX_POSITIONS"
            sector = get_sector(symbol)
            sector_count = sum(1 for s in self.positions if get_sector(s) == sector)
            if sector_count >= EQ_MAX_PER_SECTOR:
                return False, "SECTOR_LIMIT"

        if not self.risk or not self.risk.can_trade():
            return False, "RISK_HALTED"
        return True, "OK"

    def _calc_qty(self, price, sl_price, score=60):
        """Calculate quantity using risk-per-trade rule.
        V28 C10: Edge-weighted — higher score = bigger bet.
                 multiplier = score / 60  (score 60 = 1x baseline)
                 Capped at 3% risk (1.5x of 2% baseline).
        V28 D1:  With EQ_MAX_POS=5, allow up to 25% per position (was 15% for 10-pos).
        """
        if price <= 0 or sl_price <= 0 or sl_price >= price:
            return 0
        risk_per_share = price - sl_price
        if risk_per_share <= 0:
            return 0

        # V28 C10: edge-weighted risk. Baseline 2%, max 3%, min 1%
        try:
            sc = float(score) if score else 60.0
        except Exception:
            sc = 60.0
        score_mult = max(0.5, min(1.5, sc / 60.0))   # 0.5x..1.5x
        effective_risk_pct = EQ_RISK_PER_TRADE * score_mult
        effective_risk_pct = min(effective_risk_pct, 0.03)  # hard cap 3%

        risk_amount = self.available * effective_risk_pct
        qty = int(risk_amount / risk_per_share)

        # V28 D1: concentration cap raised from 15% to 25% (matches 5-position max)
        max_cost = self.available * 0.25
        if qty * price > max_cost:
            qty = int(max_cost / price)
        return max(0, qty)

    def enter(self, symbol, catalyst, direction, score, source="UNKNOWN"):
        """
        Place a real BUY order for equity.
        Returns True on success.
        """
        can, reason = self._can_enter(symbol)
        if not can:
            log.debug(f"Equity entry blocked {symbol}: {reason}")
            return False

        kite = KiteSession.kite()
        if not kite:
            return False

        # Safety: crash, circuit, correlation, bad stock
        if not SafetyFilters.check_nifty_crash(kite): return False
        if not SafetyFilters.check_circuit(kite, symbol): return False
        if not SafetyFilters.check_correlation(symbol, self.positions): return False
        if SafetyFilters.is_bad_stock(kite, symbol): return False

        # V28 A10: EQUITY REGIME FILTER
        # Prevents two failure modes that have historically cost us money:
        #   (a) Buying on bullish news when the MARKET is falling — you catch the tide
        #   (b) Chasing a stock that has already jumped >3% since the signal fired
        # Exception: very high-conviction catalysts (score >= 85, e.g. BUYBACK) allowed
        #            with a looser relative-strength threshold.
        try:
            _nifty_q = kite.quote(["NSE:NIFTY 50"]).get("NSE:NIFTY 50", {})
            _n_ltp = _nifty_q.get("last_price", 0)
            _n_prev = _nifty_q.get("ohlc", {}).get("close", 0)
            _stock_q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
            _s_ltp = _stock_q.get("last_price", 0)
            _s_prev = _stock_q.get("ohlc", {}).get("close", 0)

            if _n_ltp > 0 and _n_prev > 0 and _s_ltp > 0 and _s_prev > 0:
                _nifty_pct = (_n_ltp - _n_prev) / _n_prev * 100
                _stock_pct = (_s_ltp - _s_prev) / _s_prev * 100
                _rel_strength = _stock_pct - _nifty_pct

                # Threshold varies by catalyst conviction
                _high_conv = (score or 0) >= 85
                _rel_threshold = 0.2 if _high_conv else 0.5

                # Rule 1: falling market + stock not outperforming → BLOCK
                if _nifty_pct <= -1.0 and _rel_strength < _rel_threshold:
                    log.info(
                        f"[V28 A10] {symbol} BLOCKED: NIFTY {_nifty_pct:+.2f}%, "
                        f"stock {_stock_pct:+.2f}%, rel_strength {_rel_strength:+.2f}% "
                        f"< {_rel_threshold:+.1f}% threshold (conv={'HIGH' if _high_conv else 'NORMAL'})"
                    )
                    return False

                # Rule 2: chasing — stock already ran >3% today → BLOCK
                # (This is the v24.1.3 chase protection we used to have.)
                # High-conviction catalysts get 5% tolerance.
                _chase_limit = 5.0 if _high_conv else 3.0
                if _stock_pct > _chase_limit:
                    log.info(
                        f"[V28 A10] {symbol} BLOCKED: already +{_stock_pct:.2f}% today "
                        f"> chase_limit {_chase_limit}% (signal arrived late)"
                    )
                    return False

                log.debug(
                    f"[V28 A10] {symbol} regime OK: NIFTY {_nifty_pct:+.2f}%, "
                    f"stock {_stock_pct:+.2f}%, rel {_rel_strength:+.2f}%"
                )
        except Exception as _ae:
            # If regime check fails for any reason (no market data, API error),
            # allow entry rather than block — other safety filters still apply.
            log.warning(f"[V28 A10] regime check failed for {symbol}: {_ae}, allowing entry")

        # Order guard: duplicate check + SEBI compliance
        can_order, guard_reason = OrderGuard.can_place_order(symbol)
        if not can_order:
            log.info(f"Equity: {symbol} blocked by OrderGuard: {guard_reason}")
            return False
        if OrderGuard.check_pending_orders(kite, symbol):
            return False

        try:
            # Get live price
            ltp_data = kite.ltp([f"NSE:{symbol}"])
            price = ltp_data.get(f"NSE:{symbol}", {}).get("last_price", 0)
            if price <= 0:
                return False

            # V28 C3: Freak trade protection — reject LTP more than 20% off prev close
            try:
                q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
                prev_close = q.get("ohlc", {}).get("close", 0)
                if prev_close > 0 and abs(price - prev_close) / prev_close > 0.20:
                    log.warning(f"Equity: {symbol} FREAK PRICE — LTP={price}, prev_close={prev_close}, diff={(price-prev_close)/prev_close*100:.1f}%, REJECTING")
                    return False
            except Exception as _fe:
                log.debug(f"Equity: {symbol} freak-check failed: {_fe}")

            # Get historical data for ATR
            today = today_ist()
            hist = kite.historical_data(
                instrument_token=self._get_instrument_token(kite, symbol),
                from_date=(today - timedelta(days=30)).isoformat(),
                to_date=today.isoformat(),
                interval="day",
            )
            if not hist or len(hist) < 5:
                atr = price * 0.02  # Default 2%
                rsi = 50
                vol_ratio = 1.0
            else:
                closes = [c["close"] for c in hist]
                highs = [c["high"] for c in hist]
                lows = [c["low"] for c in hist]
                volumes = [c["volume"] for c in hist]
                atr = calc_atr(highs, lows, closes)
                rsi = calc_rsi(closes)
                vol_ratio = calc_volume_ratio(volumes)

            # ── Technical confirmation ──
            # RSI: don't buy overbought
            if rsi > 75:
                log.info(f"Equity: {symbol} RSI={rsi:.0f} too high, skipping")
                return False

            # Volume: need above average for conviction
            if vol_ratio < 0.8:
                log.info(f"Equity: {symbol} volume ratio={vol_ratio:.1f} too low, skipping")
                return False

            # ── Calculate SL and target ──
            sl_price = round(price - max(1.5 * atr, price * EQ_INITIAL_SL_PCT), 2)
            # SL must be below current price
            sl_price = min(sl_price, round(price * (1 - EQ_INITIAL_SL_PCT), 2))
            target = round(price + EQ_T2_ATR_MULT * atr, 2)

            # ── Position sizing ──
            qty = self._calc_qty(price, sl_price, score=score)  # V28 C10: edge-weighted
            if qty <= 0:
                log.info(f"Equity: {symbol} qty=0, insufficient capital")
                return False

            cost = qty * price
            if cost > self.available:
                log.info(f"Equity: {symbol} cost={cost:.0f} > available={self.available:.0f}")
                return False

            # ── Place order ──
            order_id = kite.place_order(
                variety=kite.VARIETY_REGULAR,
                exchange="NSE",
                tradingsymbol=symbol,
                transaction_type="BUY",
                quantity=qty,
                order_type="LIMIT",
                price=round(price * 1.005, 1),  # 0.5% buffer above LTP
                product="CNC",
                validity="DAY",
                market_protection=5,  # SEBI mandatory — 5% market protection
            )
            log.info(f"Equity: ORDER PLACED {symbol} qty={qty} price={price} order_id={order_id}")
            OrderGuard.record_order(symbol)

            # Wait for fill
            time.sleep(2)
            order_status = None
            try:
                orders = kite.orders()
                for o in orders:
                    if str(o.get("order_id")) == str(order_id):
                        order_status = o.get("status")
                        if o.get("average_price", 0) > 0:
                            price = o["average_price"]
                            sl_price = round(price - max(1.5 * atr, price * EQ_INITIAL_SL_PCT), 2)
                            sl_price = min(sl_price, round(price * (1 - EQ_INITIAL_SL_PCT), 2))
                            target = round(price + EQ_T2_ATR_MULT * atr, 2)
                        break
            except Exception:
                pass

            if order_status == "REJECTED":
                log.error(f"Equity: {symbol} order REJECTED")
                return False

            # ── Save position ──
            self.positions[symbol] = {
                "symbol": symbol,
                "qty": qty,
                "entry_price": price,
                "entry_time": now_ist().isoformat(),
                "sl": sl_price,
                "target": target,
                "peak_price": price,
                "atr": atr,
                "catalyst": catalyst,
                "order_id": str(order_id),
                "source": source,
            }
            self.available -= cost
            self._save_positions()

            # ── Place GTT only if order is COMPLETE ──
            if order_status == "COMPLETE":
                gtt_id = self.gtt.ensure_gtt(symbol, "NSE", qty, sl_price, target)
                if gtt_id:
                    self.positions[symbol]["gtt_id"] = gtt_id
                    self._save_positions()

            self.telegram.send(
                f"BUY {symbol} x{qty} @ Rs.{price:,.1f}\n"
                f"SL: Rs.{sl_price:,.1f} | Target: Rs.{target:,.1f}\n"
                f"Cost: Rs.{cost:,.0f} | RSI: {rsi:.0f} | Vol: {vol_ratio:.1f}x\n"
                f"Catalyst: {catalyst[:60]}",
                force=True,
            )
            return True

        except Exception as e:
            log.error(f"Equity: entry {symbol} failed: {e}")
            return False

    def _get_instrument_token(self, kite, symbol):
        """Get instrument token for historical data."""
        try:
            instruments = kite.instruments("NSE")
            for inst in instruments:
                if inst.get("tradingsymbol") == symbol and inst.get("instrument_type") == "EQ":
                    return inst["instrument_token"]
        except Exception:
            pass
        return None

    # ── TRAILING SL ──

    def check_trailing_sl(self):
        """
        Check all positions. If price went up, move SL up.
        SL = 2.5% below current LTP.
        SL ONLY moves UP, NEVER down.
        SL must ALWAYS be BELOW current LTP.

        Runs every 5 minutes during market hours.
        """
        if not self.positions:
            return

        kite = KiteSession.kite()
        if not kite:
            return

        try:
            # Batch LTP fetch
            sym_list = [f"NSE:{s}" for s in self.positions]
            ltp_data = kite.ltp(sym_list)

            for sym, pos in list(self.positions.items()):
                ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                if ltp <= 0:
                    continue

                old_sl = pos.get("sl", 0)
                peak = pos.get("peak_price", pos.get("entry_price", 0))

                # Update peak
                if ltp > peak:
                    pos["peak_price"] = ltp

                # Calculate new trailing SL: 2.5% below current LTP
                new_sl = round(ltp * (1 - EQ_TRAIL_SL_PCT), 2)

                # CRITICAL SAFETY CHECKS:
                # 1. New SL must be HIGHER than old SL (only moves UP)
                # 2. New SL must be BELOW current LTP (never above)
                if new_sl > old_sl and new_sl < ltp:
                    pos["sl"] = new_sl
                    self._save_positions()

                    # Update GTT
                    self.gtt.ensure_gtt(sym, "NSE", pos.get("qty", 0), new_sl, pos.get("target", 0))
                    log.info(f"Equity trail: {sym} SL {old_sl}→{new_sl} (LTP={ltp})")

                # FIX_V29_SINGLE_ONLY: software target exit (replaces OCO target trigger)
                _target = pos.get("target", 0)
                if _target > 0 and ltp >= _target:
                    log.info(f"Equity: {sym} TARGET HIT LTP={ltp} >= target={_target}")
                    self._exit_position(sym, "TARGET_HIT")
                    continue

                # Check if SL breached
                if ltp <= old_sl and old_sl > 0:
                    log.info(f"Equity: {sym} SL breached LTP={ltp} <= SL={old_sl}")
                    self._exit_position(sym, "SL_BREACHED")

        except Exception as e:
            log.error(f"Equity trailing SL error: {e}")

    def _exit_position(self, symbol, reason):
        """Exit a position by placing a sell order."""
        pos = self.positions.get(symbol)
        if not pos:
            return

        kite = KiteSession.kite()
        if not kite:
            return

        # Don't sell at lower circuit — will be rejected
        if not SafetyFilters.check_circuit(kite, symbol):
            log.warning(f"Equity: {symbol} at circuit, cannot exit. Retry next cycle.")
            return

        try:
            qty = pos.get("qty", 0)
            if qty <= 0:
                return

            order_id = kite.place_order(
                variety=kite.VARIETY_REGULAR,
                exchange="NSE",
                tradingsymbol=symbol,
                transaction_type="SELL",
                quantity=qty,
                order_type="MARKET",
                product="CNC",
                validity="DAY",
                market_protection=5,  # SEBI mandatory
            )
            log.info(f"Equity: SELL {symbol} x{qty} reason={reason} order_id={order_id}")

            # Get fill price
            time.sleep(2)
            exit_price = 0
            try:
                orders = kite.orders()
                for o in orders:
                    if str(o.get("order_id")) == str(order_id):
                        exit_price = o.get("average_price", 0)
                        break
            except Exception:
                pass

            self._record_trade(symbol, pos, exit_price, reason)
            del self.positions[symbol]
            self._save_positions()

            pnl = (exit_price - pos.get("entry_price", 0)) * qty if exit_price > 0 else 0
            self.telegram.send(
                f"SELL {symbol} x{qty} @ Rs.{exit_price:,.1f}\n"
                f"P&L: Rs.{pnl:,.0f} | Reason: {reason}",
                force=True,
            )

        except Exception as e:
            log.error(f"Equity: exit {symbol} failed: {e}")

    # ── DEAD MONEY CHECK ──

    # V28 D3: Catalyst-specific dead-money windows. Slow catalysts (buyback, promoter buy)
    # need weeks-to-months to play out. Fast catalysts (results beat, momentum) should
    # move quickly or not at all. Single 15d rule was cutting winners on slow catalysts.
    _DEAD_MONEY_BY_CATALYST = {
        "BUYBACK":       60,   # buybacks run weeks-months
        "PROMOTER_BUY":  45,   # insider conviction signals
        "BONUS":         45,
        "STOCK_SPLIT":   30,
        "ACQUISITION":   45,
        "EXPANSION":     30,
        "ORDER_WIN":     30,
        "DIVIDEND":      25,
        "RESULTS_BEAT":  15,   # fast move expected
        "BREAKOUT":      10,
        "MOMENTUM":      10,
    }

    @classmethod
    def _dead_money_days_for(cls, catalyst_text, default=15):
        """Pick a dead-money window based on catalyst type keywords."""
        if not catalyst_text:
            return default
        up = str(catalyst_text).upper()
        # Check FILING_SIGNALS keys first (explicit)
        for key, days in cls._DEAD_MONEY_BY_CATALYST.items():
            if key in up:
                return days
        # Heuristic fallbacks
        if "BUYBACK" in up:    return 60
        if "ORDER" in up:      return 30
        if "BONUS" in up:      return 45
        if "DIVIDEND" in up:   return 25
        if "RESULT" in up or "EARNINGS" in up: return 15
        return default

    # V28 D7: Press winners — when capital sits idle, add to strongest existing winner
    # Rule: if idle capital > 15% of equity capital AND a position is up > 10%,
    #       top up that winner with up to 50% of its current position value.
    # Only runs once per trading day (tracked via self._last_press_day).
    # Respects all safety guards (circuit, crash, correlation, OrderGuard).
    def press_winners(self):
        try:
            if not is_market_hours():
                return
            today = today_ist()
            if getattr(self, "_last_press_day", None) == today:
                return
            if self.capital <= 0:
                return
            idle_pct = self.available / self.capital if self.capital > 0 else 0
            if idle_pct < 0.15:
                return
            if not self.positions:
                return
            kite = KiteSession.kite()
            if not kite:
                return
            # Find best winner (highest unrealized % gain)
            best_sym = None
            best_gain = 0
            best_ltp = 0
            sym_list = [f"NSE:{s}" for s in self.positions]
            try:
                ltp_data = kite.ltp(sym_list)
            except Exception:
                return
            for sym, pos in self.positions.items():
                entry = pos.get("entry_price", 0)
                ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                if entry <= 0 or ltp <= 0:
                    continue
                gain = (ltp - entry) / entry
                if gain > best_gain:
                    best_gain = gain
                    best_sym = sym
                    best_ltp = ltp
            if not best_sym or best_gain < 0.10:
                log.debug(f"Equity press: idle={idle_pct*100:.0f}% but no winner >10%")
                self._last_press_day = today
                return
            # Safety guards
            if not SafetyFilters.check_nifty_crash(kite): return
            if not SafetyFilters.check_circuit(kite, best_sym): return
            pos = self.positions[best_sym]
            current_value = pos.get("qty", 0) * best_ltp
            add_budget = min(self.available * 0.5, current_value * 0.5)
            if add_budget < best_ltp:
                return
            add_qty = int(add_budget / best_ltp)
            if add_qty <= 0:
                return
            # OrderGuard: skip if duplicate/pending
            can_order, reason = OrderGuard.can_place_order(best_sym)
            if not can_order:
                log.info(f"Equity press: {best_sym} guard blocked: {reason}")
                return
            if OrderGuard.check_pending_orders(kite, best_sym):
                return
            try:
                order_id = kite.place_order(
                    variety=kite.VARIETY_REGULAR,
                    exchange="NSE",
                    tradingsymbol=best_sym,
                    transaction_type="BUY",
                    quantity=add_qty,
                    order_type="LIMIT",
                    price=round(best_ltp * 1.005, 1),
                    product="CNC",
                    validity="DAY",
                    market_protection=5,
                )
                log.info(f"Equity PRESS WINNER: {best_sym} +{add_qty} @ {best_ltp} (was up {best_gain*100:.1f}%, idle {idle_pct*100:.0f}%) order={order_id}")
                OrderGuard.record_order(best_sym)

                # V28 D7: Poll for fill before touching local state to avoid drift
                # if order doesn't fill. Don't leak state to self.positions until COMPLETE.
                fill_price = 0.0
                order_status = None
                _elapsed = 0.0
                while _elapsed < 15:
                    time.sleep(1.5)
                    _elapsed += 1.5
                    try:
                        for o in (kite.orders() or []):
                            if str(o.get("order_id")) == str(order_id):
                                order_status = o.get("status")
                                if o.get("average_price", 0) > 0:
                                    fill_price = o["average_price"]
                                break
                    except Exception:
                        continue
                    if order_status in ("COMPLETE", "REJECTED", "CANCELLED"):
                        break

                if order_status != "COMPLETE" or fill_price <= 0:
                    log.warning(f"Equity press: {best_sym} not filled (status={order_status}), cancelling and skipping state update")
                    try:
                        kite.cancel_order(variety=kite.VARIETY_REGULAR, order_id=order_id)
                    except Exception:
                        pass
                    self._last_press_day = today
                    return

                self.telegram.send(
                    f"PRESS WINNER {best_sym} +{add_qty} @ Rs.{fill_price:,.1f}\n"
                    f"Already up {best_gain*100:.1f}% | Idle was {idle_pct*100:.0f}%",
                    silent=True,
                )
                # Update position with ACTUAL fill price (blended average)
                pos["qty"] = pos.get("qty", 0) + add_qty
                pos["entry_price"] = round(
                    (pos.get("entry_price", fill_price) * (pos["qty"] - add_qty) + fill_price * add_qty) / pos["qty"], 2
                )
                self.available -= add_qty * fill_price
                self._save_positions()
            except Exception as pe:
                log.error(f"Equity press: order failed for {best_sym}: {pe}")
            self._last_press_day = today
        except Exception as e:
            log.error(f"press_winners error: {e}")

    def check_dead_money(self):
        """Exit positions with no meaningful profit after catalyst-specific window.
        V28 D3: Window is catalyst-aware (was a single 15-day rule).
        """
        for sym in list(self.positions.keys()):
            pos = self.positions[sym]
            entry_time = pos.get("entry_time", "")
            if not entry_time:
                continue
            try:
                entry_dt = datetime.fromisoformat(entry_time.replace("Z", "+00:00"))
                days_held = (now_ist() - entry_dt).days
                # V28 D3: catalyst-aware window
                _cat = pos.get("catalyst", "") or ""
                window = EquityModule._dead_money_days_for(_cat, default=EQ_DEAD_MONEY_DAYS)
                if days_held >= window:
                    entry_price = pos.get("entry_price", 0)
                    kite = KiteSession.kite()
                    if kite:
                        ltp_data = kite.ltp([f"NSE:{sym}"])
                        ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                        if ltp > 0 and ltp <= entry_price * 1.015:  # Less than 1.5% profit
                            log.info(f"Equity: {sym} dead money {days_held}d >= window {window}d (catalyst='{_cat[:40]}'), exiting")
                            self._exit_position(sym, f"DEAD_MONEY_{days_held}d_w{window}")
            except Exception:
                pass

    # ── SCAN & TRADE ──

    def scan_and_trade(self):
        """
        Main equity scan loop.
        1. Scan ALL sources: news, filings, brokerage, macro
        2. Filter by Trendlyne fundamentals
        3. Confirm with technicals (RSI, Volume)
        4. Enter best candidates
        """
        if not self.risk or not self.risk.can_trade():
            return

        # Gather candidates from ALL sources
        candidates = []

        # Source 1: News RSS
        if self.news:
            candidates.extend(self.news.scan())

        # Source 2: NSE Filings (promoter buying, buybacks, order wins)
        if self.filings:
            candidates.extend(self.filings.scan())

        # Source 3: Brokerage calls (analyst upgrades/downgrades)
        if self.brokerage:
            candidates.extend(self.brokerage.scan())

        # Source 4: Macro events (RBI, war, oil)
        if self.macro:
            candidates.extend(self.macro.scan())

        if not candidates:
            return

        # Source 5: 52-week low recovery (Kedia/Damani style)
        if is_market_hours():
            kite = KiteSession.kite()
            if kite:
                try:
                    candidates.extend(EquitySmartScanner.scan_52week_low_recovery(kite, self.all_symbols, self.trendlyne))
                except Exception as e:
                    log.debug(f"52wk scanner error: {e}")

                # Source 6: Promoter buying (strongest insider signal)
                try:
                    candidates.extend(EquitySmartScanner.scan_promoter_increase(kite, self.all_symbols))
                except Exception as e:
                    log.debug(f"Promoter scanner error: {e}")

                # Source 7: Sector rotation (follow the money)
                try:
                    candidates.extend(EquitySmartScanner.scan_sector_rotation(kite))
                except Exception as e:
                    log.debug(f"Sector rotation error: {e}")

                # Source 8: Breakout (52-week high on volume)
                try:
                    candidates.extend(EquitySmartScanner.scan_breakout(kite, self.all_symbols))
                except Exception as e:
                    log.debug(f"Breakout scanner error: {e}")

        # PATCH_V28_SOURCE_WEIGHT: boost scores based on source reliability
        # Filing/Brokerage = highest conviction, News/Momentum = lowest
        _SOURCE_WEIGHTS = {
            "FILING": 1.15,        # NSE filings — hard data, highest conviction
            "BROKERAGE": 1.12,     # Analyst upgrades/downgrades — professional research
            "PROMOTER_BUY": 1.10,  # Insider buying — strong signal
            "MACRO": 1.05,         # RBI/Fed/GDP — affects entire market
            "52WK_LOW": 1.0,       # Technical — no boost
            "BREAKOUT": 1.0,       # Technical — no boost
            "SECTOR_ROTATION": 1.0,# Sector play — no boost
            "NEWS": 0.95,          # RSS headlines — noisy, slight penalty
            "MOMENTUM": 0.90,      # Price momentum — weakest conviction
        }
        for c in candidates:
            _src = c.get("source", "")
            _w = _SOURCE_WEIGHTS.get(_src, 1.0)
            if _w != 1.0:
                _old_score = c.get("score", 0)
                c["score"] = min(95, int(_old_score * _w))
                if c["score"] != _old_score:
                    log.debug(f"[PATCH_V28_SOURCE_WEIGHT] {c.get('symbol')} {_src}: {_old_score} -> {c['score']} (x{_w})")

        # Deduplicate by symbol (keep highest score)
        best_by_sym = {}
        for c in candidates:
            sym = c["symbol"]
            if sym not in best_by_sym or c.get("score", 0) > best_by_sym[sym].get("score", 0):
                best_by_sym[sym] = c
        candidates = list(best_by_sym.values())

        # Trendlyne quality filter — reject poor fundamentals
        qualified = []
        for c in candidates:
            sym = c["symbol"]
            if not self.trendlyne.is_quality(sym, min_score=40):
                log.debug(f"Equity: {sym} failed Trendlyne quality check")
                continue
            qualified.append(c)

        # Sort by score (highest first)
        qualified.sort(key=lambda c: c.get("score", 0), reverse=True)

        # Only take BULLISH for equity (we buy stocks, not short)
        bullish = [c for c in qualified if c.get("direction") == "BULLISH"]

        entered = 0
        for cand in bullish[:5]:  # Try top 5 candidates
            sym = cand["symbol"]
            if sym not in self.all_symbols:
                continue
            if not is_valid_symbol(sym):
                continue

            success = self.enter(sym, cand.get("catalyst", ""), "BULLISH", cand.get("score", 0), cand.get("source", "UNKNOWN"))
            if success:
                entered += 1
                if entered >= 3:  # Max 3 entries per scan cycle
                    break

        if entered > 0:
            log.info(f"Equity: entered {entered} positions this cycle")

    # ── MAIN TICK ──

    def tick(self):
        """Called every minute from main loop."""
        n = now_ist()

        # Morning sync at 08:00
        if n.hour == 8 and n.minute == 0:
            self._refresh_capital()
            self._sync_holdings()
            self._gtt_audit()

        # SL re-place at 09:16 (SL orders expire daily)
        if n.hour == 9 and n.minute == 16:
            self._gtt_audit()

        # Scan every 30 minutes during market hours
        if is_market_hours() and n.minute % EQ_SCAN_INTERVAL_MIN == 0:
            if self._last_scan != n.hour * 60 + n.minute:
                self._last_scan = n.hour * 60 + n.minute
                self.scan_and_trade()

        # Trailing SL check every 5 minutes during market hours
        if is_market_hours() and n.minute % 5 == 0:
            if self._last_trail_check != n.hour * 60 + n.minute:
                self._last_trail_check = n.hour * 60 + n.minute
                self.check_trailing_sl()

        # FIX_V29_MIDDAY_AUDIT: midday GTT safety check at 12:30
        if n.hour == 12 and n.minute == 30:
            self._gtt_audit()

        # Dead money check at 15:00
        if n.hour == 15 and n.minute == 0:
            self.check_dead_money()

        # V28 D7: Press winners at 14:00 IST if capital idle
        if n.hour == 14 and n.minute == 0 and is_trading_day():
            try:
                self.press_winners()
            except Exception as _pe:
                log.error(f"press_winners tick error: {_pe}")

        # Cancel unfilled AMOs — PATCH_V28_STALE_WINDOW: 09:20-09:30 window, once per day
        # Previously: fired only at 09:20:00 exactly. If main loop was busy that minute,
        # the cancel was skipped entirely until next day (SURAJEST-class miss).
        # Now: tries every minute in the window until successful, then flags done for the day.
        if n.hour == 9 and 20 <= n.minute <= 30:
            try:
                _stale_marker = DATA_DIR / "equity_stale_cancel_today.json"
                _stale_existing = load_json(_stale_marker, {})
                if _stale_existing.get("date") != str(today_ist()):
                    log.info(f"[PATCH_V28_STALE_WINDOW] running equity stale-cancel at {n.hour:02d}:{n.minute:02d} IST")
                    # FIX_V29_DEDUP_AMO: removed duplicate _cancel_stale_amos(), amo.cancel_stale() does same + clears internal list
                    self.amo.cancel_stale()
                    save_json(_stale_marker, {"date": str(today_ist()), "ran_at": f"{n.hour:02d}:{n.minute:02d}"})
            except Exception as _stale_err:
                log.error(f"[PATCH_V28_STALE_WINDOW] failed: {_stale_err}")

        # EOD report at 15:35
        if n.hour == 15 and n.minute == 35 and is_trading_day():
            report = EODReporter.generate_equity_report(self)
            self.telegram.send(report, force=True)

        # V28 A2: Evening AMO scan runs ONCE per evening (20:00 IST), not twice.
        # Previously ran at 16:00 AND 20:00 causing multiple AMO batches per night.
        # 20:00 gives full evening window for news/filings to surface.
        if n.hour == 20 and n.minute == 0 and is_trading_day():
            self._evening_amo_scan()

    def _cancel_stale_amos(self):
        """Cancel any unfilled AMO orders from previous night."""
        kite = KiteSession.kite()
        if not kite:
            return
        try:
            orders = kite.orders()
            for o in orders:
                if o.get("variety") == "amo" and o.get("status") in ("OPEN", "TRIGGER PENDING"):
                    if o.get("transaction_type") == "BUY":
                        kite.cancel_order(variety="amo", order_id=o["order_id"])
                        log.info(f"Equity: cancelled stale AMO {o.get('tradingsymbol')} id={o['order_id']}")
        except Exception as e:
            log.error(f"Equity: cancel AMOs failed: {e}")

    def _evening_amo_scan(self):
        """
        Evening scan for next-day AMO orders — runs ONCE at 20:00 IST (V28 A2).
        Checks LIVE Kite holdings before sizing slots (not stale local JSON).
        Counts pending AMOs against the slot budget.
        Total AMO cost must NOT exceed available capital.
        """
        if not is_amo_window():
            return

        # V28 A2: Pull LIVE Kite holdings. If Kite unreachable, abort rather than guess.
        kite = KiteSession.kite()
        if not kite:
            log.error("Equity AMO: no Kite session, aborting scan")
            return

        try:
            held_syms = set()
            for h in (kite.holdings() or []):
                if h.get("tradingsymbol") and (h.get("quantity", 0) + h.get("t1_quantity", 0)) > 0:
                    held_syms.add(h["tradingsymbol"])
            for p in (kite.positions().get("net", []) or []):
                if p.get("exchange") == "NSE" and p.get("quantity", 0) > 0 and p.get("tradingsymbol"):
                    held_syms.add(p["tradingsymbol"])
        except Exception as e:
            log.error(f"Equity AMO: kite.holdings() failed — aborting scan to avoid over-buying: {e}")
            return

        current_count = len(held_syms)
        log.info(f"Equity AMO: kite shows {current_count} live holdings before AMO scan")

        if current_count >= EQ_MAX_POS:
            log.info(f"Equity AMO: kite has {current_count} >= MAX {EQ_MAX_POS}, skipping AMO scan entirely")
            return

        free_slots = EQ_MAX_POS - current_count

        # Also subtract pending AMO BUY orders on Kite (already queued for tomorrow)
        pending_amo_syms = set()
        try:
            for o in (kite.orders() or []):
                if (o.get("variety") == "amo"
                    and o.get("transaction_type") == "BUY"
                    and o.get("status") in ("OPEN", "TRIGGER PENDING", "AMO REQ RECEIVED")
                    and o.get("exchange") == "NSE"):
                    ts = o.get("tradingsymbol")
                    if ts:
                        pending_amo_syms.add(ts)
        except Exception as pe:
            log.warning(f"Equity AMO: pending-order check failed: {pe}")

        free_slots = max(0, free_slots - len(pending_amo_syms))
        log.info(f"Equity AMO: {free_slots} free slots ({current_count}/{EQ_MAX_POS} used + {len(pending_amo_syms)} pending)")

        if free_slots <= 0:
            return

        candidates = []
        if self.filings:
            candidates.extend(self.filings.scan())
        if self.news:
            candidates.extend(self.news.scan())

        # Only strong catalysts for AMO (score >= 75)
        # V28 A2: exclude symbols held on Kite AND pending AMOs (not just local positions)
        strong = [c for c in candidates
                  if c.get("direction") == "BULLISH"
                  and c.get("score", 0) >= 75
                  and c.get("symbol") in self.all_symbols
                  and is_valid_symbol(c.get("symbol", ""))
                  and c.get("symbol") not in self.positions
                  and c.get("symbol") not in held_syms
                  and c.get("symbol") not in pending_amo_syms]

        if not strong:
            log.info("Equity AMO: no new strong candidates after holdings/pending filter")
            return

        strong.sort(key=lambda c: c.get("score", 0), reverse=True)
        # V28 A2: cap by actual free_slots (dynamic), and never more than 3 per evening
        strong = strong[: min(free_slots, 3)]

        # Check available capital (minus pending AMO cost)
        pending_cost = self.amo.get_total_pending_cost()
        amo_available = self.available - pending_cost

        for cand in strong:  # V28 A2: strong already capped by free_slots
            sym = cand["symbol"]
            try:
                ltp_data = kite.ltp([f"NSE:{sym}"])
                price = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                if price <= 0:
                    continue

                # V28 C3: freak-trade protection — reject LTP >20% off prev close
                try:
                    q = kite.quote([f"NSE:{sym}"]).get(f"NSE:{sym}", {})
                    prev_close = q.get("ohlc", {}).get("close", 0)
                    if prev_close > 0 and abs(price - prev_close) / prev_close > 0.20:
                        log.warning(f"Equity AMO: {sym} FREAK LTP={price} vs prev_close={prev_close}, skipping")
                        continue
                except Exception:
                    pass

                # Simple qty: 2% risk, edge-weighted (V28 C10)
                sl_price = round(price * (1 - EQ_INITIAL_SL_PCT), 2)
                qty = self._calc_qty(price, sl_price, score=cand.get("score", 60))
                if qty <= 0:
                    continue

                cost = qty * price * 1.01  # Include 1% buffer
                if cost > amo_available:
                    log.info(f"Equity AMO: {sym} cost={cost:.0f} exceeds available={amo_available:.0f}")
                    continue

                order_id = self.amo.place_amo(sym, price, qty)
                if order_id:
                    amo_available -= cost
                    self.telegram.send(
                        f"AMO PLACED {sym} x{qty} @ ~Rs.{price:,.1f}\n"
                        f"Catalyst: {cand.get('catalyst', '')[:60]}",
                        silent=True,
                    )
            except Exception as e:
                log.error(f"Equity AMO: {sym} failed: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
#  F&O MODULE — Completely independent. No equity awareness.
# ═══════════════════════════════════════════════════════════════════════════════

class SectorRotation:
    """
    PATCH_V8_SECTOR_ROTATION
    Tracks sectoral indices and ranks them by today's intraday % move.
    Refreshes every 15 minutes during market hours.
    Top-3 sectors get score boost, bottom-2 sectors block new entries.
    """

    def __init__(self, fno_module):
        self.fno = fno_module
        self.ranking_file = DATA_DIR / "sector_ranking.json"
        self._last_refresh_minute = -1
        self._ranking = {}  # sector_name -> {"pct": X, "rank": N}

    def refresh(self):
        """Fetch all sectoral indices, compute today's % move, rank them."""
        kite = KiteSession.kite()
        if not kite:
            return {}
        try:
            keys = list(SECTOR_INDICES_MAP.values())
            ohlc_data = kite.ohlc(keys)
            sector_moves = []
            for sector, key in SECTOR_INDICES_MAP.items():
                d = ohlc_data.get(key, {})
                ltp = d.get("last_price", 0)
                ohlc = d.get("ohlc", {})
                prev_close = ohlc.get("close", 0)
                if ltp > 0 and prev_close > 0:
                    pct = ((ltp - prev_close) / prev_close) * 100
                    sector_moves.append((sector, pct))
            # Sort descending by % move
            sector_moves.sort(key=lambda x: x[1], reverse=True)
            ranking = {}
            for rank, (sector, pct) in enumerate(sector_moves, start=1):
                ranking[sector] = {"pct": round(pct, 2), "rank": rank}
            self._ranking = ranking
            try:
                save_json(self.ranking_file, {
                    "timestamp": now_ist().isoformat(),
                    "ranking": ranking,
                })
            except Exception:
                pass
            top3 = [s for s, d in ranking.items() if d["rank"] <= 3]
            bot2 = [s for s, d in ranking.items() if d["rank"] >= len(ranking) - 1]
            log.info(f"[PATCH_V8_SECTOR] ranking refreshed: TOP3={top3} BOTTOM2={bot2}")
            return ranking
        except Exception as _e:
            log.error(f"[PATCH_V8_SECTOR] refresh failed: {_e}")
            return {}

    def get_sector_bias(self, symbol):
        """
        Returns ("TOP"|"MIDDLE"|"BOTTOM", sector_name, pct).
        TOP    = sector ranked 1-3 (strong, boost score)
        MIDDLE = sector ranked 4-7 (neutral)
        BOTTOM = sector ranked 8-9 (weak, block entries)
        Returns (None, None, 0) if sector unknown or ranking not yet loaded.
        """
        sector = get_sector(symbol)
        if not sector or sector not in self._ranking:
            return (None, None, 0)
        rank = self._ranking[sector]["rank"]
        pct = self._ranking[sector]["pct"]
        total = len(self._ranking)
        if rank <= 3:
            return ("TOP", sector, pct)
        if rank >= total - 1:
            return ("BOTTOM", sector, pct)
        return ("MIDDLE", sector, pct)


class GapDetector:
    """
    PATCH_V6_GAP
    Detects pre-market gaps for all F&O stocks + indices at 08:50 IST.
    Tags each symbol as GAP_UP / GAP_DOWN / FLAT.
    Reviews pending AMOs and cancels any that contradict gap direction.
    """

    INDEX_SPOT_KEYS = {
        "NIFTY": "NSE:NIFTY 50",
        "BANKNIFTY": "NSE:NIFTY BANK",
        "FINNIFTY": "NSE:NIFTY FIN SERVICE",
        "MIDCPNIFTY": "NSE:NIFTY MID SELECT",
    }

    def __init__(self, fno_module):
        self.fno = fno_module
        self.gap_file = DATA_DIR / "gap_status.json"

    def detect_gaps(self):
        """Read previous close vs current LTP for all symbols. Save gap_status.json."""
        kite = KiteSession.kite()
        if not kite:
            log.warning("[PATCH_V6_GAP] no Kite session, skip")
            return {}
        gap_status = {"timestamp": now_ist().isoformat(), "stocks": {}, "indices": {}}
        # Build the full instrument list to query
        index_keys = list(self.INDEX_SPOT_KEYS.values())
        stock_keys = [f"NSE:{s}" for s in self.fno.fno_stocks]
        all_keys = index_keys + stock_keys
        # Batch ohlc calls
        ohlc_data = {}
        try:
            for i in range(0, len(all_keys), 250):
                batch = all_keys[i:i+250]
                resp = kite.ohlc(batch)
                ohlc_data.update(resp)
        except Exception as _e:
            log.error(f"[PATCH_V6_GAP] ohlc batch failed: {_e}")
            return {}
        # Process indices
        gap_up_idx = []
        gap_down_idx = []
        for idx_name, key in self.INDEX_SPOT_KEYS.items():
            try:
                d = ohlc_data.get(key, {})
                ltp = d.get("last_price", 0)
                ohlc = d.get("ohlc", {})
                prev_close = ohlc.get("close", 0)
                if ltp <= 0 or prev_close <= 0:
                    continue
                gap_pct = ((ltp - prev_close) / prev_close) * 100
                tag = "FLAT"
                if gap_pct >= GAP_INDEX_THRESHOLD:
                    tag = "GAP_UP"
                    gap_up_idx.append(f"{idx_name} {gap_pct:+.2f}%")
                elif gap_pct <= -GAP_INDEX_THRESHOLD:
                    tag = "GAP_DOWN"
                    gap_down_idx.append(f"{idx_name} {gap_pct:+.2f}%")
                gap_status["indices"][idx_name] = {"pct": round(gap_pct, 2), "tag": tag, "ltp": ltp, "prev_close": prev_close}
            except Exception:
                continue
        # Process stocks
        gap_up_stocks = []
        gap_down_stocks = []
        flat_count = 0
        for sym in self.fno.fno_stocks:
            try:
                key = f"NSE:{sym}"
                d = ohlc_data.get(key, {})
                ltp = d.get("last_price", 0)
                ohlc = d.get("ohlc", {})
                prev_close = ohlc.get("close", 0)
                if ltp <= 0 or prev_close <= 0:
                    continue
                gap_pct = ((ltp - prev_close) / prev_close) * 100
                tag = "FLAT"
                if gap_pct >= GAP_STOCK_THRESHOLD:
                    tag = "GAP_UP"
                    gap_up_stocks.append(f"{sym} {gap_pct:+.1f}%")
                elif gap_pct <= -GAP_STOCK_THRESHOLD:
                    tag = "GAP_DOWN"
                    gap_down_stocks.append(f"{sym} {gap_pct:+.1f}%")
                else:
                    flat_count += 1
                gap_status["stocks"][sym] = {"pct": round(gap_pct, 2), "tag": tag, "ltp": ltp, "prev_close": prev_close}
            except Exception:
                continue
        try:
            save_json(self.gap_file, gap_status)
        except Exception as _e:
            log.error(f"[PATCH_V6_GAP] save failed: {_e}")
        log.info(f"[PATCH_V6_GAP] gap detection complete: {len(gap_up_stocks)} GAP_UP, {len(gap_down_stocks)} GAP_DOWN, {flat_count} FLAT")
        if gap_up_idx:
            log.info(f"[PATCH_V6_GAP] indices GAP_UP: {', '.join(gap_up_idx)}")
        if gap_down_idx:
            log.info(f"[PATCH_V6_GAP] indices GAP_DOWN: {', '.join(gap_down_idx)}")
        if gap_up_stocks:
            log.info(f"[PATCH_V6_GAP] stocks GAP_UP ({len(gap_up_stocks)}): {', '.join(gap_up_stocks[:10])}{' ...' if len(gap_up_stocks)>10 else ''}")
        if gap_down_stocks:
            log.info(f"[PATCH_V6_GAP] stocks GAP_DOWN ({len(gap_down_stocks)}): {', '.join(gap_down_stocks[:10])}{' ...' if len(gap_down_stocks)>10 else ''}")
        return gap_status

    def review_pending_amos(self, gap_status):
        """
        Review all pending AMOs (BUY orders, equity + F&O).
        Cancel any that contradict gap direction.
        For equity: check stock gap.
        For F&O: extract underlying from tradingsymbol, check stock gap.
        """
        kite = KiteSession.kite()
        if not kite:
            return
        cancelled = []
        try:
            orders = kite.orders()
        except Exception as _e:
            log.error(f"[PATCH_V6_GAP] orders fetch failed: {_e}")
            return
        for o in orders:
            try:
                if o.get("variety") != "amo":
                    continue
                if o.get("status") not in ("OPEN", "TRIGGER PENDING", "AMO REQ RECEIVED"):
                    continue
                if o.get("transaction_type") != "BUY":
                    continue
                tsym = o.get("tradingsymbol", "")
                exch = o.get("exchange", "")
                order_id = o.get("order_id", "")
                # Determine underlying symbol
                if exch == "NSE":
                    underlying = tsym
                    is_call = True  # equity is always bullish
                elif exch == "NFO":
                    # Extract underlying from F&O tradingsymbol like NIFTY26APR25150CE
                    is_call = tsym.endswith("CE")
                    is_put = tsym.endswith("PE")
                    if not (is_call or is_put):
                        continue
                    # Strip CE/PE and try to match underlying from fno_stocks
                    stripped = tsym[:-2]
                    underlying = None
                    for s in sorted(self.fno.fno_stocks, key=len, reverse=True):
                        if stripped.startswith(s):
                            underlying = s
                            break
                    if not underlying:
                        # Index check
                        for idx in OI_INDICES:
                            if stripped.startswith(idx):
                                underlying = idx
                                break
                    if not underlying:
                        continue
                else:
                    continue
                # Look up gap status
                gap_info = None
                if underlying in gap_status.get("stocks", {}):
                    gap_info = gap_status["stocks"][underlying]
                elif underlying in gap_status.get("indices", {}):
                    gap_info = gap_status["indices"][underlying]
                if not gap_info:
                    continue
                tag = gap_info.get("tag", "FLAT")
                pct = gap_info.get("pct", 0)
                # Determine if AMO contradicts gap
                should_cancel = False
                reason = ""
                if exch == "NSE":
                    # Equity BUY contradicts only if GAP_DOWN
                    if tag == "GAP_DOWN":
                        should_cancel = True
                        reason = f"equity BUY but {underlying} GAP_DOWN {pct:+.2f}%"
                    # PATCH_V28_STRANDED_GAPUP: cancel equity BUY AMO when stock gapped UP
                    # above limit price by more than 2% (SURAJEST-class stranding)
                    elif tag == "GAP_UP":
                        try:
                            _limit_price = float(o.get("price", 0))
                            _ltp = float(gap_info.get("open", 0))
                            if _limit_price > 0 and _ltp > 0:
                                _stranded_pct = ((_ltp - _limit_price) / _limit_price) * 100
                                if _stranded_pct >= 2.0:
                                    should_cancel = True
                                    reason = f"equity BUY stranded: limit Rs.{_limit_price:.2f} vs open Rs.{_ltp:.2f} ({_stranded_pct:+.2f}%)"
                        except Exception as _stranded_err:
                            log.debug(f"[PATCH_V28_STRANDED] check failed for {underlying}: {_stranded_err}")
                    # END_PATCH_V28_STRANDED_GAPUP
                else:
                    # F&O: CE BUY contradicts GAP_DOWN, PE BUY contradicts GAP_UP
                    if is_call and tag == "GAP_DOWN":
                        should_cancel = True
                        reason = f"CE BUY but {underlying} GAP_DOWN {pct:+.2f}%"
                    elif is_put and tag == "GAP_UP":
                        should_cancel = True
                        reason = f"PE BUY but {underlying} GAP_UP {pct:+.2f}%"
                if should_cancel:
                    try:
                        kite.cancel_order(variety="amo", order_id=order_id)
                        log.warning(f"[PATCH_V6_GAP] CANCELLED AMO {tsym} id={order_id}: {reason}")
                        cancelled.append({"tsym": tsym, "reason": reason})
                    except Exception as _ce:
                        log.error(f"[PATCH_V6_GAP] cancel failed {tsym}: {_ce}")
            except Exception as _e:
                log.debug(f"[PATCH_V6_GAP] AMO review per-order error: {_e}")
                continue
        if cancelled:
            try:
                msg_lines = [f"*GAP REVIEW: {len(cancelled)} AMOs CANCELLED*"]
                for c in cancelled[:10]:
                    msg_lines.append(f"`{c['tsym']}` — {c['reason']}")
                send_telegram("\n".join(msg_lines), silent=False)
            except Exception:
                pass
        else:
            log.info("[PATCH_V6_GAP] AMO review: no contradictions found")


class OISnapshotEngine:
    """
    PATCH_V5_OI_LOGGER
    Captures option chain Open Interest snapshots for all F&O stocks + indices.
    Stores one JSON file per day, auto-deletes files older than OI_RETENTION_DAYS.
    Provides signal detection: long buildup, short buildup, unwinding.
    """

    def __init__(self, fno_module):
        self.fno = fno_module
        self.snapshot_dir = DATA_DIR / "oi_snapshots"
        self.snapshot_dir.mkdir(parents=True, exist_ok=True)
        self._last_snapshot_minute = -1

    def _get_snapshot_file(self, d=None):
        d = d or today_ist()
        return self.snapshot_dir / f"oi_{d.isoformat()}.json"

    def _cleanup_old_snapshots(self):
        """Delete snapshot files older than OI_RETENTION_DAYS."""
        try:
            cutoff = today_ist() - timedelta(days=OI_RETENTION_DAYS)
            for f in self.snapshot_dir.glob("oi_*.json"):
                try:
                    fname = f.stem.replace("oi_", "")
                    fdate = datetime.strptime(fname, "%Y-%m-%d").date()
                    if fdate < cutoff:
                        f.unlink()
                        log.info(f"[PATCH_V5_OI] deleted old snapshot {f.name}")
                except Exception:
                    pass
        except Exception as _e:
            log.warning(f"[PATCH_V5_OI] cleanup failed: {_e}")

    def _round_to_strike(self, price, symbol):
        """Round spot price to the nearest valid strike for this symbol."""
        if symbol == "NIFTY" or symbol == "FINNIFTY":
            return round(price / 50) * 50
        if symbol == "BANKNIFTY":
            return round(price / 100) * 100
        if symbol == "MIDCPNIFTY":
            return round(price / 25) * 25
        if price < 100:
            return round(price / 2.5) * 2.5
        if price < 500:
            return round(price / 5) * 5
        if price < 1000:
            return round(price / 10) * 10
        if price < 2500:
            return round(price / 20) * 20
        return round(price / 50) * 50

    def _get_atm_strikes(self, symbol, spot):
        """Return list of ATM +/- OI_STRIKES_RANGE strikes that exist in NFO instruments."""
        atm = self._round_to_strike(spot, symbol)
        all_strikes = sorted({
            inst.get("strike", 0)
            for inst in self.fno._nfo_instruments
            if inst.get("name") == symbol and inst.get("instrument_type") in ("CE", "PE")
            and inst.get("strike", 0) > 0
        })
        if not all_strikes:
            return []
        try:
            atm_idx = min(range(len(all_strikes)), key=lambda i: abs(all_strikes[i] - atm))
        except Exception:
            return []
        lo = max(0, atm_idx - OI_STRIKES_RANGE)
        hi = min(len(all_strikes), atm_idx + OI_STRIKES_RANGE + 1)
        return all_strikes[lo:hi]

    def _get_current_expiry_instruments(self, symbol, strikes):
        """Get nearest-expiry CE+PE tradingsymbols for given strikes."""
        today = today_ist()
        candidates = []
        for inst in self.fno._nfo_instruments:
            if inst.get("name") != symbol:
                continue
            if inst.get("instrument_type") not in ("CE", "PE"):
                continue
            if inst.get("strike", 0) not in strikes:
                continue
            expiry = inst.get("expiry")
            if isinstance(expiry, str):
                try:
                    expiry = datetime.strptime(expiry, "%Y-%m-%d").date()
                except Exception:
                    continue
            elif hasattr(expiry, "date"):
                expiry = expiry.date()
            dte = (expiry - today).days
            if dte < 0 or dte > 60:
                continue
            candidates.append({
                "tradingsymbol": inst["tradingsymbol"],
                "strike": inst["strike"],
                "type": inst["instrument_type"],
                "expiry": expiry.isoformat(),
                "dte": dte,
            })
        if not candidates:
            return []
        nearest_expiry = min(c["expiry"] for c in candidates)
        return [c for c in candidates if c["expiry"] == nearest_expiry]

    def take_snapshot(self, is_eod=False):
        """Hourly snapshot of OI for all symbols. Returns count of instruments captured.

        PATCH_V9_AMO_ARCH: is_eod=True flags the snapshot as end-of-day for
        day-over-day comparison in detect_buildup_signals(mode="daily").
        """
        kite = KiteSession.kite()
        if not kite:
            return 0
        all_symbols = list(OI_INDICES) + list(self.fno.fno_stocks)
        all_instruments = []
        symbol_meta = {}
        for sym in all_symbols:
            try:
                if sym in OI_INDICES:
                    spot_key = f"NSE:{sym} 50" if sym == "NIFTY" else f"NSE:NIFTY {sym.replace('NIFTY','').strip() or 'BANK'}"
                    if sym == "NIFTY":
                        spot_key = "NSE:NIFTY 50"
                    elif sym == "BANKNIFTY":
                        spot_key = "NSE:NIFTY BANK"
                    elif sym == "FINNIFTY":
                        spot_key = "NSE:NIFTY FIN SERVICE"
                    elif sym == "MIDCPNIFTY":
                        spot_key = "NSE:NIFTY MID SELECT"
                else:
                    spot_key = f"NSE:{sym}"
                spot_data = kite.ltp([spot_key])
                spot = spot_data.get(spot_key, {}).get("last_price", 0)
                if spot <= 0:
                    continue
                strikes = self._get_atm_strikes(sym, spot)
                if not strikes:
                    continue
                instruments = self._get_current_expiry_instruments(sym, strikes)
                if not instruments:
                    continue
                symbol_meta[sym] = {"spot": spot, "atm": self._round_to_strike(spot, sym), "instruments": instruments}
                all_instruments.extend(f"NFO:{i['tradingsymbol']}" for i in instruments)
            except Exception as _e:
                log.debug(f"[PATCH_V5_OI] {sym} prep failed: {_e}")
                continue
        if not all_instruments:
            log.warning("[PATCH_V5_OI] no instruments to snapshot")
            return 0
        # Batch quote calls (Kite limit: 250 per call)
        oi_data = {}
        try:
            for i in range(0, len(all_instruments), 250):
                batch = all_instruments[i:i+250]
                quotes = kite.quote(batch)
                for k, v in quotes.items():
                    oi_data[k] = {
                        "ltp": v.get("last_price", 0),
                        "oi": v.get("oi", 0),
                        "volume": v.get("volume", 0),
                    }
        except Exception as _e:
            log.error(f"[PATCH_V5_OI] batch quote failed: {_e}")
            return 0
        # Build snapshot
        snapshot = {
            "timestamp": now_ist().isoformat(),
            "symbols": {},
        }
        # PATCH_V9_AMO_ARCH: mark EOD snapshots for day-over-day comparison
        if is_eod:
            snapshot["eod"] = True
        for sym, meta in symbol_meta.items():
            sym_entry = {"spot": meta["spot"], "atm": meta["atm"], "strikes": []}
            for inst in meta["instruments"]:
                key = f"NFO:{inst['tradingsymbol']}"
                q = oi_data.get(key, {})
                sym_entry["strikes"].append({
                    "strike": inst["strike"],
                    "type": inst["type"],
                    "ltp": q.get("ltp", 0),
                    "oi": q.get("oi", 0),
                    "volume": q.get("volume", 0),
                    "dte": inst["dte"],
                })
            snapshot["symbols"][sym] = sym_entry
        # Append to today's file
        snapshot_file = self._get_snapshot_file()
        try:
            existing = load_json(snapshot_file, {"date": str(today_ist()), "snapshots": []})
            existing["snapshots"].append(snapshot)
            save_json(snapshot_file, existing)
        except Exception as _e:
            log.error(f"[PATCH_V5_OI] save failed: {_e}")
            return 0
        # Periodic cleanup
        if now_ist().hour == 16:
            self._cleanup_old_snapshots()
        _eod_tag = " [EOD]" if is_eod else ""
        log.info(f"[PATCH_V5_OI] snapshot saved{_eod_tag}: {len(symbol_meta)} symbols, {len(all_instruments)} instruments, file={snapshot_file.name}")
        return len(all_instruments)

    def _find_recent_eod_snapshots(self, need=2):
        """
        PATCH_V9_AMO_ARCH: walk snapshot_dir, find the most recent `need` snapshots
        marked eod=True. Returns list ordered newest-first. May return empty list.
        """
        results = []
        try:
            files = sorted(self.snapshot_dir.glob("oi_*.json"), reverse=True)
            for f in files:
                try:
                    data = load_json(f, {"snapshots": []})
                    for snap in reversed(data.get("snapshots", [])):
                        if snap.get("eod") is True:
                            results.append(snap)
                            if len(results) >= need:
                                return results
                except Exception as _e:
                    log.debug(f"[PATCH_V9_AMO_ARCH] eod scan skipped {f.name}: {_e}")
                    continue
        except Exception as _e:
            log.warning(f"[PATCH_V9_AMO_ARCH] _find_recent_eod_snapshots failed: {_e}")
        return results

    def detect_buildup_signals(self, mode="intraday"):
        """
        Detect OI buildup signals.

        mode="intraday" (default, unchanged behavior):
          Compare latest 2 snapshots in today's file (~1h apart).
        mode="daily" (PATCH_V9_AMO_ARCH):
          Compare two most recent EOD snapshots across date files.
          Useful in overnight AMO scan window when intraday deltas are stale.

        Patterns detected in both modes:
          - LONG BUILDUP: spot up + total CE OI up significantly  -> BULLISH
          - SHORT BUILDUP: spot down + total PE OI up significantly -> BEARISH
          - LONG UNWINDING: spot down + total CE OI down -> BEARISH (weaker)
          - SHORT COVERING: spot up + total PE OI down -> BULLISH (weaker)

        Returns list of candidates compatible with F&O scanner format.
        """
        candidates = []
        try:
            if mode == "daily":
                # PATCH_V9_AMO_ARCH: day-over-day using EOD snapshots
                eod_snaps = self._find_recent_eod_snapshots(need=2)
                if len(eod_snaps) < 2:
                    log.debug(f"[PATCH_V9_AMO_ARCH] daily mode: only {len(eod_snaps)} EOD snapshots available, need 2")
                    return candidates
                latest = eod_snaps[0]
                prev = eod_snaps[1]
            else:
                snapshot_file = self._get_snapshot_file()
                data = load_json(snapshot_file, {"snapshots": []})
                snaps = data.get("snapshots", [])
                if len(snaps) < 2:
                    log.debug("[PATCH_V5_OI] not enough snapshots for buildup detection")
                    return candidates
                latest = snaps[-1]
                prev = snaps[-2]
            for sym, latest_data in latest.get("symbols", {}).items():
                prev_data = prev.get("symbols", {}).get(sym)
                if not prev_data:
                    continue
                spot_now = latest_data.get("spot", 0)
                spot_prev = prev_data.get("spot", 0)
                if spot_now <= 0 or spot_prev <= 0:
                    continue
                spot_change_pct = ((spot_now - spot_prev) / spot_prev) * 100
                ce_oi_now = sum(s["oi"] for s in latest_data.get("strikes", []) if s["type"] == "CE")
                pe_oi_now = sum(s["oi"] for s in latest_data.get("strikes", []) if s["type"] == "PE")
                ce_oi_prev = sum(s["oi"] for s in prev_data.get("strikes", []) if s["type"] == "CE")
                pe_oi_prev = sum(s["oi"] for s in prev_data.get("strikes", []) if s["type"] == "PE")
                if ce_oi_prev <= 0 or pe_oi_prev <= 0:
                    continue
                ce_oi_change_pct = ((ce_oi_now - ce_oi_prev) / ce_oi_prev) * 100
                pe_oi_change_pct = ((pe_oi_now - pe_oi_prev) / pe_oi_prev) * 100
                pattern = None
                direction = None
                score = 0
                if spot_change_pct > 0.3 and pe_oi_change_pct > OI_BUILDUP_MIN_PCT:
                    pattern = "PUT_WRITING"
                    direction = "BULLISH"
                    score = min(95, 60 + int(pe_oi_change_pct / 2) + int(spot_change_pct * 5))
                elif spot_change_pct < -0.3 and ce_oi_change_pct > OI_BUILDUP_MIN_PCT:
                    pattern = "CALL_WRITING"
                    direction = "BEARISH"
                    score = min(95, 60 + int(ce_oi_change_pct / 2) + int(abs(spot_change_pct) * 5))
                elif spot_change_pct > 0.3 and ce_oi_change_pct < -OI_BUILDUP_MIN_PCT:
                    pattern = "SHORT_COVERING"
                    direction = "BULLISH"
                    score = min(85, 55 + int(abs(ce_oi_change_pct) / 2))
                elif spot_change_pct < -0.3 and pe_oi_change_pct < -OI_BUILDUP_MIN_PCT:
                    pattern = "LONG_UNWINDING"
                    direction = "BEARISH"
                    score = min(85, 55 + int(abs(pe_oi_change_pct) / 2))
                if pattern and direction and score >= OI_SIGNAL_MIN_SCORE:
                    _src = "OI_BUILDUP_DAILY" if mode == "daily" else "OI_BUILDUP"
                    _tag = "DAILY" if mode == "daily" else ""
                    candidates.append({
                        "symbol": sym,
                        "direction": direction,
                        "score": score,
                        "catalyst": f"OI {_tag} {pattern}: spot {spot_change_pct:+.2f}% CE_OI {ce_oi_change_pct:+.0f}% PE_OI {pe_oi_change_pct:+.0f}%".strip(),
                        "source": _src,
                    })
                    log.info(f"[PATCH_V5_OI] signal ({mode}): {sym} {direction} {pattern} score={score}")
        except Exception as _e:
            log.error(f"[PATCH_V5_OI] detect_buildup failed: {_e}")
        return candidates


class FnoModule:
    """
    NFO NRML options trading.

    Entry: News catalyst → determine CE/PE → check F&O eligibility → smart strike
    Exit:  Trailing SL (activate +20%, trail 15%) + DTE cascade + GTT SL at -30%
    Protection: SL orders re-placed every morning at 9:16

    NO equity-style regime filter. Catalyst strength is the only entry gate.
    Own news scanner, own GTT manager, own risk manager, own capital.
    Zero awareness of equity module.
    """

    def __init__(self):
        self.positions = {}     # key -> position dict
        self.gtt = GTTManager("FNO")
        self.risk = None
        self.telegram = TelegramThrottle("FNO", max_per_hour=15)
        self.news = None
        self.filings = None     # FilingMonitor (interprets for F&O direction)
        self.brokerage = None   # BrokerageMonitor
        self.macro = None       # MacroDetector (RBI, war, oil → CE/PE)
        self.earnings = EarningsCalendar()
        self.capital = 0
        self.available = 0
        self.fno_stocks = set()
        self._nfo_instruments = []
        self._pos_file = DATA_DIR / "fno_positions.json"
        self._trades_file = DATA_DIR / "fno_trades.json"
        self._last_scan = None
        self._last_trail_check = None
        self._oi_engine = None  # PATCH_V5_OI_LOGGER: initialized in init()
        self._last_oi_snapshot_hour = -1
        self._gap_detector = None  # PATCH_V6_GAP: initialized in init()
        self._last_gap_check_day = None
        self._sector_rotation = None  # PATCH_V8_SECTOR_ROTATION: initialized in init()

    # ============================================================
    # PATCH_V1_FNO_AMO: Continuous overnight scanner + morning placer
    # Scans 16:01 -> 08:45 IST hourly, places AMO at 08:45
    # ============================================================
    def _fno_amo_candidates_file(self):
        return DATA_DIR / "fno_amo_candidates.json"

    def _fno_amo_load_candidates(self):
        try:
            data = load_json(self._fno_amo_candidates_file(), {})
            if data.get("date") == str(today_ist()):
                return data.get("candidates", [])
        except Exception:
            pass
        return []

    def _fno_amo_save_candidates(self, candidates):
        try:
            save_json(self._fno_amo_candidates_file(), {
                "date": str(today_ist()),
                "candidates": candidates,
                "updated": str(now_ist()) if "now_ist" in globals() else "",
            })
        except Exception as _e:
            log.error(f"[PATCH_V1_FNO_AMO] save candidates failed: {_e}")

    def _fno_amo_in_scan_window(self):
        """True between 16:01 and 08:45 IST (next day)."""
        try:
            from datetime import datetime
            try:
                from zoneinfo import ZoneInfo
                now = datetime.now(ZoneInfo("Asia/Kolkata"))
            except Exception:
                now = datetime.now()
            hm = now.hour * 60 + now.minute
            # 16:01 = 961, 08:45 = 525, 24:00 = 1440
            return hm >= 961 or hm <= 525
        except Exception:
            return False

    def _fno_amo_is_premarket_place_time(self):
        """True only between 08:45 and 08:55 IST."""
        try:
            from datetime import datetime
            try:
                from zoneinfo import ZoneInfo
                now = datetime.now(ZoneInfo("Asia/Kolkata"))
            except Exception:
                now = datetime.now()
            hm = now.hour * 60 + now.minute
            return 525 <= hm <= 535
        except Exception:
            return False

    def _fno_amo_continuous_scan(self, threshold=65):
        """Hourly scan during 16:01-08:45 window. Accumulates catalysts.

        PATCH_V9_AMO_ARCH:
          - threshold param (default 65, was hardcoded 75) matches OI_SIGNAL_MIN_SCORE
          - adds daily-mode OI detection alongside intraday
        """
        if not self._fno_amo_in_scan_window():
            return
        try:
            existing = self._fno_amo_load_candidates()
            existing_keys = {(c.get("symbol"), c.get("direction")) for c in existing}

            fresh = []
            if getattr(self, "filings", None):
                try: fresh.extend(self.filings.scan() or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] filings: {_e}")
            if getattr(self, "news", None):
                try: fresh.extend(self.news.scan() or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] news: {_e}")
            if getattr(self, "brokerage", None):
                try: fresh.extend(self.brokerage.scan(news_candidates=fresh) or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] brokerage: {_e}")
                try:
                    if self._oi_engine:
                        fresh.extend(self._oi_engine.detect_buildup_signals() or [])
                        try:
                            fresh.extend(self._oi_engine.detect_buildup_signals(mode="daily") or [])
                        except Exception as _e2:
                            log.warning(f"[PATCH_V9_AMO_ARCH] daily OI detect: {_e2}")
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] brokerage: {_e}")

            added = 0
            for c in fresh:
                sym = c.get("symbol")
                direction = c.get("direction")
                score = c.get("score", 0)
                if not sym or direction not in ("BULLISH", "BEARISH"):
                    continue
                if sym not in self.fno_stocks:
                    continue
                if score < threshold:
                    continue
                key = (sym, direction)
                if key in existing_keys:
                    # Update score if higher
                    for e in existing:
                        if e.get("symbol") == sym and e.get("direction") == direction:
                            if score > e.get("score", 0):
                                e["score"] = score
                                e["catalyst"] = c.get("catalyst", "")[:120]
                                e["updated"] = str(now_ist()) if "now_ist" in globals() else ""
                            break
                else:
                    existing.append({
                        "symbol": sym,
                        "direction": direction,
                        "score": score,
                        "catalyst": c.get("catalyst", "")[:120],
                        "added": str(now_ist()) if "now_ist" in globals() else "",
                    })
                    existing_keys.add(key)
                    added += 1

            self._fno_amo_save_candidates(existing)
            log.info(f"[PATCH_V1_FNO_AMO] scan complete: {added} new, {len(existing)} total in pool (threshold={threshold})")
        except Exception as _e:
            log.error(f"[PATCH_V1_FNO_AMO] continuous scan failed: {_e}")

    def _fno_amo_premarket_place(self):
        """At 08:45 IST: read pool, apply GIFT Nifty filter, place top 3 AMOs.

        PATCH_V9_AMO_ARCH: if pool is empty, run one final aggressive scan at
        threshold 60 before giving up.
        PATCH_V28_FALLBACK_ONCE: fallback scan must fire only ONCE per day, not every minute.
        """
        try:
            if self._fno_amo_is_premarket_place_time():
                # PATCH_V28_FALLBACK_ONCE: idempotency marker for fallback scan
                _fb_marker = DATA_DIR / "fno_amo_fallback_today.json"
                _fb_existing = load_json(_fb_marker, {})
                if _fb_existing.get("date") != str(today_ist()):
                    _pool_check = self._fno_amo_load_candidates()
                    if not _pool_check:
                        log.info("[PATCH_V9_AMO_ARCH] pool empty at 08:45, running fallback scan at threshold=60 (ONCE)")
                        self._fno_amo_continuous_scan(threshold=60)
                    save_json(_fb_marker, {"date": str(today_ist()), "ran": True})
        except Exception as _e:
            log.error(f"[PATCH_V9_AMO_ARCH] fallback scan failed: {_e}")

        if not self._fno_amo_is_premarket_place_time():
            return
        kite = KiteSession.kite()
        if not kite:
            return
        try:
            # Idempotency: only run once per day
            marker_file = DATA_DIR / "fno_amo_placed_today.json"
            existing_marker = load_json(marker_file, {})
            if existing_marker.get("date") == str(today_ist()):
                return

            candidates = self._fno_amo_load_candidates()
            if not candidates:
                log.info("[PATCH_V1_FNO_AMO] no candidates to place")
                save_json(marker_file, {"date": str(today_ist()), "placed": []})
                return

            # GIFT Nifty direction filter
            gift_pct = 0.0
            try:
                gift_data = kite.ltp(["NSEIX:GIFT NIFTY"])
                gift_ltp = gift_data.get("NSEIX:GIFT NIFTY", {}).get("last_price", 0)
                nifty_ohlc = kite.ohlc(["NSE:NIFTY 50"]).get("NSE:NIFTY 50", {}).get("ohlc", {})
                yest_close = nifty_ohlc.get("close", 0)
                if gift_ltp > 0 and yest_close > 0:
                    gift_pct = ((gift_ltp - yest_close) / yest_close) * 100
                    log.info(f"[PATCH_V1_FNO_AMO] GIFT Nifty implied gap: {gift_pct:+.2f}%")
            except Exception as _e:
                log.warning(f"[PATCH_V1_FNO_AMO] GIFT Nifty fetch failed: {_e}, no direction filter")

            # Filter by GIFT direction
            filtered = []
            for c in candidates:
                d = c.get("direction")
                if gift_pct <= -0.5 and d == "BULLISH":
                    log.info(f"[PATCH_V1_FNO_AMO] SKIP {c.get('symbol')} bullish (GIFT {gift_pct:+.2f}%)")
                    continue
                if gift_pct >= 0.5 and d == "BEARISH":
                    log.info(f"[PATCH_V1_FNO_AMO] SKIP {c.get('symbol')} bearish (GIFT {gift_pct:+.2f}%)")
                    continue
                filtered.append(c)

            filtered.sort(key=lambda c: c.get("score", 0), reverse=True)
            top = filtered[:3]
            log.info(f"[PATCH_V1_FNO_AMO] {len(top)} candidates selected for AMO from pool of {len(candidates)}")

            placed_list = []
            for cand in top:
                sym = cand["symbol"]
                direction = cand["direction"]
                score = cand.get("score", 0)
                catalyst = cand.get("catalyst", "")[:60]
                try:
                    spot_data = kite.ltp([f"NSE:{sym}"])
                    spot = spot_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                    if spot <= 0:
                        log.warning(f"[PATCH_V1_FNO_AMO] {sym}: no spot price, skip")
                        continue
                    option = self._find_best_option(kite, sym, direction, spot, catalyst_score=score)
                    if not option:
                        log.info(f"[PATCH_V1_FNO_AMO] {sym}: no suitable option for {direction}")
                        continue
                    tsym = option["tradingsymbol"]
                    lot = option["lot_size"]
                    premium = option["premium"]
                    # 50% sizing for safety
                    qty = lot
                    cost = qty * premium * 1.01
                    if cost > self.available * 0.5:
                        log.info(f"[PATCH_V1_FNO_AMO] {sym}: cost {cost:.0f} > 50% of available {self.available:.0f}, skip")
                        continue
                    limit_price = round(premium * 1.02, 1)
                    order_id = kite.place_order(
                        variety="amo",
                        exchange="NFO",
                        tradingsymbol=tsym,
                        transaction_type="BUY",
                        quantity=qty,
                        order_type="LIMIT",
                        price=limit_price,
                        product="NRML",
                        validity="DAY",
                    )
                    log.info(f"[PATCH_V1_FNO_AMO] PLACED {tsym} x{qty} @ {limit_price} id={order_id} score={score}")
                    placed_list.append({"tsym": tsym, "qty": qty, "price": limit_price, "score": score, "catalyst": catalyst})
                    try:
                        self.telegram.send(
                            f"*FNO AMO PLACED*\n"
                            f"{tsym} x{qty} @ Rs.{limit_price}\n"
                            f"Direction: {direction} | Score: {score}\n"
                            f"Catalyst: {catalyst}\n"
                            f"GIFT Nifty: {gift_pct:+.2f}%",
                            silent=False,
                        )
                    except Exception:
                        pass
                except Exception as _e:
                    log.error(f"[PATCH_V1_FNO_AMO] place failed {sym}: {_e}")

            save_json(marker_file, {"date": str(today_ist()), "placed": placed_list})
            # Clear candidate pool for next night
            try:
                save_json(self._fno_amo_candidates_file(), {"date": str(today_ist()), "candidates": []})
            except Exception:
                pass
        except Exception as _e:
            log.error(f"[PATCH_V1_FNO_AMO] premarket place failed: {_e}")

    def init(self):
        """Initialize after Kite login."""
        kite = KiteSession.kite()
        if not kite:
            log.error("FNO: cannot init without Kite")
            return False

        # Load F&O eligible stocks
        try:
            self._nfo_instruments = kite.instruments("NFO")
            self.fno_stocks = set()
            for inst in self._nfo_instruments:
                name = inst.get("name", "")
                if name and inst.get("instrument_type") in ("CE", "PE"):
                    self.fno_stocks.add(name)
            log.info(f"FNO: {len(self.fno_stocks)} F&O eligible stocks loaded")

            # V27 Stage 2: initialize LLM news brain
            self.news_brain = None
            if USE_LLM_NEWS and _NEWS_BRAIN_AVAILABLE and NewsBrain:
                try:
                    self.news_brain = NewsBrain(fno_stocks=self.fno_stocks)
                    log.info(f"FNO: NewsBrain initialized (DRY_RUN={LLM_DRY_RUN})")
                except Exception as _nbe2:
                    log.error(f"FNO: NewsBrain init failed: {_nbe2}")
            else:
                log.info(f"FNO: NewsBrain disabled (USE_LLM_NEWS={USE_LLM_NEWS} available={_NEWS_BRAIN_AVAILABLE})")
        except Exception as e:
            log.error(f"FNO: instrument load failed: {e}")
            return False

        # Get capital
        self._refresh_capital()

        # Init risk manager
        self.risk = RiskManager("FNO", self.capital)

        # PATCH_V28_SYMBOL_REGEX: build name_map for F&O stocks from NFO instruments
        self._name_map = {}
        try:
            kite_inst = KiteSession.kite()
            if kite_inst:
                _nse_insts = kite_inst.instruments("NSE")
                for inst in _nse_insts:
                    _n = inst.get("name", "").upper().strip()
                    _s = inst.get("tradingsymbol", "")
                    if _n and _s and _s in self.fno_stocks:
                        self._name_map[_n] = _s
                        _words = _n.split()
                        if len(_words) >= 2:
                            self._name_map[" ".join(_words[:2])] = _s
                log.info(f"[PATCH_V28_SYMBOL_REGEX] FNO name_map with {len(self._name_map)} entries")
        except Exception as _nme:
            log.warning(f"[PATCH_V28_SYMBOL_REGEX] FNO name_map failed: {_nme}")

        # Init news scanner with F&O stocks + name mapping
        self.news = NewsScanner("FNO", self.fno_stocks, name_map=self._name_map)

        # Init filing monitor (for F&O-eligible stocks only)
        self.filings = FilingMonitor("FNO", self.fno_stocks)

        # Init brokerage monitor
        self.brokerage = BrokerageMonitor("FNO", self.fno_stocks)

        # Init macro detector (RBI, war, oil → specific stocks)
        self.macro = MacroDetector("FNO", self.fno_stocks)

        # Update earnings calendar
        try:
            self.earnings.update_from_filings()
        except Exception:
            pass

        # PATCH_V5_OI_LOGGER: initialize OI snapshot engine
        try:
            self._oi_engine = OISnapshotEngine(self)
            log.info("[PATCH_V5_OI] OISnapshotEngine initialized")
        except Exception as _e:
            log.error(f"[PATCH_V5_OI] init failed: {_e}")
            self._oi_engine = None

        # PATCH_V6_GAP: initialize gap detector
        try:
            self._gap_detector = GapDetector(self)
            log.info("[PATCH_V6_GAP] GapDetector initialized")
        except Exception as _e:
            log.error(f"[PATCH_V6_GAP] init failed: {_e}")
            self._gap_detector = None

        # PATCH_V8_SECTOR_ROTATION: initialize sector rotation tracker
        try:
            self._sector_rotation = SectorRotation(self)
            log.info("[PATCH_V8_SECTOR] SectorRotation initialized")
        except Exception as _e:
            log.error(f"[PATCH_V8_SECTOR] init failed: {_e}")
            self._sector_rotation = None

        # PATCH_V28_KITE_ONLY: DO NOT load from JSON. Kite is the only source of truth.
        # Previous behavior loaded phantom positions from live_fno.json that persisted
        # after manual Kite sells (Apr 16 2026 SURAJEST/BANKNIFTY phantom incident).
        self.positions = {}  # start empty, populate from Kite only
        self._sync_positions()

        # Run F&O GTT audit on startup
        self._fno_gtt_audit()
        
        log.info(f"FNO: init complete. Capital=Rs.{self.capital:,.0f} Positions={len(self.positions)}")
        self.telegram.send(
            f"F&O Module started\n"
            f"Capital: Rs.{self.capital:,.0f}\n"
            f"Positions: {len(self.positions)}\n"
            f"F&O stocks: {len(self.fno_stocks)}",
            force=True,
        )
        return True

    def _refresh_capital(self):
        """PATCH_V10_CAPITAL_RETRY: retry up to 3 times with 1s delay if Kite returns 0."""
        kite = KiteSession.kite()
        if not kite:
            return
        import time as _t
        total = 0
        for _attempt in range(1, 4):
            try:
                margins = kite.margins("equity")
                _t1 = margins.get("net", 0) or margins.get("available", {}).get("live_balance", 0)
                if not _t1:
                    _t1 = margins.get("available", {}).get("cash", 0)
                if _t1 and _t1 > 0:
                    total = _t1
                    break
                log.warning(f"[PATCH_V10_CAPITAL_RETRY] FNO attempt {_attempt}/3: Kite returned 0, retrying")
            except Exception as _e:
                log.warning(f"[PATCH_V10_CAPITAL_RETRY] FNO attempt {_attempt}/3: {type(_e).__name__}: {_e}")
            if _attempt < 3:
                _t.sleep(1)
        if total > 0:
            self.capital = round(total * FNO_PCT, 2)
            invested = sum(
                p.get("cost", 0) for p in self.positions.values()
            )
            self.available = max(0, self.capital - invested)
            log.info(f"[PATCH_V10_CAPITAL_RETRY] FNO refreshed: total={total} capital={self.capital} available={self.available}")
        else:
            log.warning(f"[PATCH_V10_CAPITAL_RETRY] FNO: all 3 attempts returned 0, preserving previous capital={self.capital}")

    def _load_positions(self):
        data = load_json(self._pos_file, {"positions": {}})
        self.positions = data.get("positions", {})

    def _save_positions(self):
        save_json(self._pos_file, {"positions": self.positions})

    def _sync_positions(self):
        """Sync with Kite F&O positions.

        PATCH_V28_KITE_ONLY: Now also PURGES phantom positions — any entry in
        self.positions that is NOT in Kite's NFO net book gets removed.
        This makes Kite the authoritative source.
        """
        kite = KiteSession.kite()
        if not kite:
            return
        try:
            kite_positions = kite.positions().get("net", [])

            # PATCH_V28_KITE_ONLY: build set of live NFO symbols from Kite
            _kite_nfo_syms = set()
            for _p in kite_positions:
                if _p.get("exchange") == "NFO" and _p.get("quantity", 0) > 0:
                    _kite_nfo_syms.add(_p.get("tradingsymbol", ""))

            # PATCH_V28_KITE_ONLY: purge any self.positions entries not in Kite
            _phantom_keys = [k for k in list(self.positions.keys()) if k not in _kite_nfo_syms]
            for _phantom in _phantom_keys:
                log.warning(f"[PATCH_V28_KITE_ONLY] FNO purge phantom: {_phantom} not in Kite NFO book")
                del self.positions[_phantom]
            if _phantom_keys:
                log.info(f"[PATCH_V28_KITE_ONLY] FNO purged {len(_phantom_keys)} phantom positions")

            for p in kite_positions:
                if p.get("exchange") == "NFO" and p.get("quantity", 0) > 0:
                    sym = p.get("tradingsymbol", "")
                    key = sym
                    if key not in self.positions:
                        # v26.3: Preserve existing trailed GTT SL instead of resetting to 30% default
                        _live_sl = round(p.get("average_price", 0) * (1 - FNO_SL_PCT), 2)
                        try:
                            _existing_gtts = kite.get_gtts() or []
                            for _g in _existing_gtts:
                                if _g.get("status") != "active":
                                    continue
                                _cond = _g.get("condition", {})
                                if _cond.get("tradingsymbol") == sym and _cond.get("exchange") == "NFO":
                                    _triggers = _cond.get("trigger_values", [])
                                    if _triggers and _triggers[0] > 0:
                                        _live_sl = float(_triggers[0])
                                        log.info(f"FNO sync: {sym} using live GTT SL={_live_sl} (not default)")
                                        break
                        except Exception as _e:
                            log.warning(f"FNO sync: GTT lookup failed for {sym}: {_e}")
                        # V27 PATCH (Bug #5): Enrich with expiry/strike from instrument master
                        # so DTE protection works for synced positions.
                        _expiry_str = ""
                        _strike = 0
                        _option_type = ""
                        try:
                            _instruments = kite.instruments("NFO")
                            for _inst in _instruments:
                                if _inst.get("tradingsymbol") == sym:
                                    _exp = _inst.get("expiry")
                                    if _exp:
                                        _expiry_str = _exp.strftime("%Y-%m-%d") if hasattr(_exp, "strftime") else str(_exp)
                                    _strike = _inst.get("strike", 0)
                                    _option_type = _inst.get("instrument_type", "")
                                    break
                            if not _expiry_str:
                                log.warning(f"FNO sync: {sym} expiry not found in instrument master - DTE protection DISABLED for this position")
                        except Exception as _ie:
                            log.error(f"FNO sync: instrument lookup for {sym} failed: {_ie}")

                        _dte_at_sync = 0
                        if _expiry_str:
                            try:
                                _exp_d = datetime.strptime(_expiry_str, "%Y-%m-%d").date()
                                _dte_at_sync = (_exp_d - today_ist()).days
                            except Exception:
                                pass

                        self.positions[key] = {
                            "tradingsymbol": sym,
                            "qty": p["quantity"],
                            "entry_price": p.get("average_price", 0),
                            "entry_time": now_ist().isoformat(),
                            "cost": p.get("quantity", 0) * p.get("average_price", 0),
                            "peak_premium": p.get("average_price", 0),
                            "sl_price": _live_sl,
                            "expiry": _expiry_str,
                            "dte_at_entry": _dte_at_sync,
                            "strike": _strike,
                            "option_type": _option_type,
                            "source": "KITE_SYNC",
                        }
                        log.info(f"FNO sync: {sym} expiry={_expiry_str} strike={_strike} dte={_dte_at_sync}")
            self._save_positions()
        except Exception as e:
            log.error(f"FNO: sync positions failed: {e}")

    def _find_best_option(self, kite, symbol, direction, spot_price, catalyst_score=60):
        """
        SMART F&O option selection using professional options analysis:
        1. IV Percentile — are options cheap or expensive?
        2. OI Analysis — where is smart money?
        3. Delta — probability of profit
        4. Theta — time decay vs expected move
        5. PCR — market direction confirmation
        6. Physical delivery check — exit stock options 2 days before expiry
        
        Returns dict with option details or None.
        """
        opt_type = "CE" if "BULL" in direction else "PE"
        today = today_ist()
        is_index = symbol in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY")

        # ── Step 0: Gather all valid option contracts ──
        candidates = []
        for inst in self._nfo_instruments:
            if inst.get("name") != symbol or inst.get("instrument_type") != opt_type:
                continue

            expiry = inst.get("expiry")
            if not expiry:
                continue
            if isinstance(expiry, str):
                try:
                    expiry = datetime.strptime(expiry, "%Y-%m-%d").date()
                except Exception:
                    continue
            elif hasattr(expiry, "date"):
                expiry = expiry.date()

            dte = (expiry - today).days

            # PATCH_V28_DTE_PREFER_FAR_MONTH: smart DTE selection
            # Stock options: if near-month DTE < EMERGENCY_DTE + 3 (=15), skip it.
            # Prevents buy-then-emergency-exit-same-day (killed HAL +27% on Apr 17).
            # Index options (cash-settled, liquid): can still use near-month.
            if is_index:
                min_dte = max(5, FNO_MIN_DTE - 5)
            else:
                # For stocks: never enter if DTE would trigger emergency exit soon
                _safe_min = FNO_EMERGENCY_DTE + 3  # 12 + 3 = 15 days minimum for stocks
                min_dte = max(FNO_MIN_DTE, _safe_min)
            if not (min_dte <= dte <= FNO_MAX_DTE):
                continue

            strike = inst.get("strike", 0)
            if strike <= 0:
                continue

            # Calculate OTM percentage
            if opt_type == "CE":
                otm_pct = (strike - spot_price) / spot_price if spot_price > 0 else 0
            else:
                otm_pct = (spot_price - strike) / spot_price if spot_price > 0 else 0

            # Wide range: 1-20% OTM
            if 0.01 <= otm_pct <= 0.20:
                candidates.append({
                    "tradingsymbol": inst["tradingsymbol"],
                    "strike": strike,
                    "expiry": expiry,
                    "dte": dte,
                    "lot_size": inst.get("lot_size", 1),
                    "otm_pct": otm_pct,
                    "instrument_token": inst.get("instrument_token"),
                    "is_index": is_index,
                })

        if not candidates:
            log.debug(f"FNO smart: {symbol} {opt_type} — no candidates in DTE/OTM range")
            return None

        # ── Step 1: Get live quotes for all candidates (batch) ──
        # Process in batches of 20 (Kite API limit)
        scored_candidates = []
        for i in range(0, min(len(candidates), 40), 20):
            batch = candidates[i:i+20]
            sym_list = [f"NFO:{c['tradingsymbol']}" for c in batch]
            try:
                quotes = kite.quote(sym_list)
            except Exception:
                continue

            for cand in batch:
                tsym = cand["tradingsymbol"]
                q = quotes.get(f"NFO:{tsym}", {})
                if not q:
                    continue

                ltp = q.get("last_price", 0)
                oi = q.get("oi", 0)
                oi_change = q.get("oi_day_change", 0)  # Today's OI change
                volume = q.get("volume", 0)
                depth = q.get("depth", {})
                ohlc = q.get("ohlc", {})
                prev_close = ohlc.get("close", 0)

                # Best bid/ask from market depth
                bids = depth.get("buy", [])
                asks = depth.get("sell", [])
                best_bid = bids[0].get("price", 0) if bids else 0
                best_ask = asks[0].get("price", 0) if asks else 0

                # ── Filter: minimum OI ──
                if oi < FNO_MIN_OI:
                    continue

                # ── Filter: bid-ask spread ──
                if best_bid > 0 and best_ask > 0:
                    spread = (best_ask - best_bid) / best_ask
                    if spread > FNO_MAX_SPREAD:
                        continue
                elif ltp <= 0:
                    continue

                premium = best_ask if best_ask > 0 else ltp
                if premium <= 0:
                    continue

                # ── Filter: cost check ──
                cost = premium * cand["lot_size"]
                max_cost = self.available * FNO_CAP_PER_TRADE
                if cost > max_cost or cost > self.available:
                    continue

                # ── Score: IV analysis ──
                # Approximate IV percentile from price movement
                # If premium is low relative to spot and DTE, IV is low (cheap)
                iv_score = 0
                time_value_ratio = premium / (spot_price * 0.01) if spot_price > 0 else 0
                dte_factor = cand["dte"] / 30  # Normalize to 1 month
                
                if time_value_ratio < 1.5 * dte_factor:
                    iv_score = 30  # Options are CHEAP — good
                elif time_value_ratio < 3.0 * dte_factor:
                    iv_score = 15  # Normal pricing
                else:
                    iv_score = -10  # EXPENSIVE — avoid unless strong catalyst
                    if catalyst_score < 80:
                        continue  # Skip expensive options for weak catalysts

                # ── Score: OI analysis (follow smart money) ──
                oi_score = 0
                if oi_change > 0:
                    # OI increasing = new positions being built
                    oi_ratio = oi_change / oi if oi > 0 else 0
                    if oi_ratio > 0.10:
                        oi_score = 25  # >10% OI increase today — strong institutional activity
                    elif oi_ratio > 0.05:
                        oi_score = 15  # 5-10% increase — moderate
                    else:
                        oi_score = 5   # Some activity
                elif oi_change < 0:
                    oi_score = -5  # OI decreasing = unwinding positions

                # ── Score: Delta approximation ──
                # Rough delta from OTM percentage (Black-Scholes approximation)
                delta_score = 0
                otm = cand["otm_pct"]
                if otm <= 0.03:
                    approx_delta = 0.60  # Near ATM
                elif otm <= 0.05:
                    approx_delta = 0.45
                elif otm <= 0.08:
                    approx_delta = 0.30
                elif otm <= 0.12:
                    approx_delta = 0.20
                else:
                    approx_delta = 0.10  # Deep OTM

                # Strong catalyst → prefer higher delta (more probability)
                # Weak catalyst → prefer lower delta (cheaper, less risk)
                if catalyst_score >= 80:
                    # High conviction — want Delta 0.30-0.60
                    if 0.30 <= approx_delta <= 0.60:
                        delta_score = 25
                    elif 0.20 <= approx_delta < 0.30:
                        delta_score = 15
                    else:
                        delta_score = 5
                else:
                    # Lower conviction — want Delta 0.15-0.35 (cheaper)
                    if 0.15 <= approx_delta <= 0.35:
                        delta_score = 25
                    elif 0.10 <= approx_delta < 0.15:
                        delta_score = 15
                    else:
                        delta_score = 5

                # ── Score: Theta check ──
                # Approximate theta: premium / DTE
                theta_score = 0
                daily_decay = premium / cand["dte"] if cand["dte"] > 0 else premium
                # Expected move from catalyst (rough: score/100 * 3% of spot)
                expected_move_pct = (catalyst_score / 100) * 0.03
                expected_premium_gain = expected_move_pct * spot_price * approx_delta
                
                # Is expected gain > 3 days of theta decay?
                if expected_premium_gain > daily_decay * 3:
                    theta_score = 20  # Good — move should overcome decay
                elif expected_premium_gain > daily_decay * 1.5:
                    theta_score = 10  # Marginal
                else:
                    theta_score = -15  # Bad — theta will eat your profit
                    if catalyst_score < 75:
                        continue  # Skip if weak catalyst + bad theta

                # ── Score: Volume confirmation ──
                vol_score = 0
                if volume > 10000:
                    vol_score = 10
                elif volume > 1000:
                    vol_score = 5

                # ── Total score ──
                total_score = iv_score + oi_score + delta_score + theta_score + vol_score

                scored_candidates.append({
                    "tradingsymbol": tsym,
                    "lot_size": cand["lot_size"],
                    "premium": premium,
                    "expiry": cand["expiry"],
                    "dte": cand["dte"],
                    "strike": cand["strike"],
                    "oi": oi,
                    "oi_change": oi_change,
                    "spread": spread if best_bid > 0 and best_ask > 0 else 0,
                    "cost": cost,
                    "approx_delta": approx_delta,
                    "daily_theta": round(daily_decay, 2),
                    "smart_score": total_score,
                    "is_index": cand["is_index"],
                    "iv_score": iv_score,
                    "oi_score": oi_score,
                    "delta_score": delta_score,
                    "theta_score": theta_score,
                })

        if not scored_candidates:
            if candidates:
                log.info(f"FNO smart: {symbol} {opt_type} — {len(candidates)} in DTE/OTM range but ALL rejected by OI/spread/cost/IV/theta")
            else:
                log.info(f"FNO smart: {symbol} {opt_type} — 0 candidates in DTE range ({FNO_MIN_DTE}-{FNO_MAX_DTE}d) or OTM range — check expiry calendar")
            return None

        # ── Pick the BEST option (highest smart_score) ──
        scored_candidates.sort(key=lambda c: c["smart_score"], reverse=True)
        best = scored_candidates[0]

        log.info(
            f"FNO smart: {symbol} {opt_type} SELECTED {best['tradingsymbol']} "
            f"strike={best['strike']} premium={best['premium']} DTE={best['dte']} "
            f"delta~{best['approx_delta']:.2f} OI_chg={best['oi_change']} "
            f"score={best['smart_score']} (IV={best['iv_score']} OI={best['oi_score']} "
            f"D={best['delta_score']} T={best['theta_score']})"
        )

        return best

    def enter(self, symbol, catalyst, direction, score):
        """Place a real F&O BUY order."""
        if len(self.positions) >= FNO_MAX_POS:
            return False
        # Check per-stock limit
        stock_count = sum(1 for p in self.positions.values()
                          if p.get("tradingsymbol", "").startswith(symbol))
        if stock_count >= FNO_MAX_PER_STOCK:
            return False
        # PATCH_V3_SECTOR_CAP: enforce max positions per sector
        try:
            _new_sector = get_sector(symbol)
            _sector_count = sum(1 for p in self.positions.values()
                                if get_sector(p.get("symbol", "")) == _new_sector)
            if _sector_count >= FNO_MAX_PER_SECTOR:
                log.info(f"[PATCH_V3_SECTOR_CAP] FNO blocked {symbol}: sector {_new_sector} already has {_sector_count} positions")
                return False
        except Exception as _e:
            log.warning(f"[PATCH_V3_SECTOR_CAP] sector check failed for {symbol}: {_e}, allowing entry")
        # END_PATCH_V3_SECTOR_CAP

        # PATCH_V4_VIX_FILTER v3: VIX is informational only, never blocks F&O
        # Brain decides CE/PE from news/OI/technicals. VIX is logged for attribution.
        # Cached 60s to avoid hammering kite.ltp().
        try:
            import time as _t
            _now = _t.time()
            _cache = getattr(self, "_vix_cache", None)
            if _cache and (_now - _cache[1]) < 60:
                _vix = _cache[0]
            else:
                _vix_data = kite.ltp(["NSE:INDIA VIX"])
                _vix = _vix_data.get("NSE:INDIA VIX", {}).get("last_price", 0)
                self._vix_cache = (_vix, _now)
            if _vix > 0:
                _regime = "HIGH" if _vix > 22 else ("LOW" if _vix < 12 else "NORMAL")
                log.info(f"[PATCH_V4_VIX_v3] {symbol} {direction} entering at VIX={_vix:.2f} ({_regime})")
        except Exception as _e:
            log.debug(f"[PATCH_V4_VIX_v3] VIX log failed for {symbol}: {_e}")
        # END_PATCH_V4_VIX_FILTER

        # PATCH_V6_GAP: block contradictory entries based on per-stock gap status
        try:
            _gap_file = DATA_DIR / "gap_status.json"
            _gap_status = load_json(_gap_file, {})
            _gap_info = None
            if symbol in _gap_status.get("stocks", {}):
                _gap_info = _gap_status["stocks"][symbol]
            elif symbol in _gap_status.get("indices", {}):
                _gap_info = _gap_status["indices"][symbol]
            if _gap_info:
                _tag = _gap_info.get("tag", "FLAT")
                _pct = _gap_info.get("pct", 0)
                if direction == "BULLISH" and _tag == "GAP_DOWN":
                    log.info(f"[PATCH_V6_GAP] FNO blocked {symbol} BULLISH: stock GAP_DOWN {_pct:+.2f}%")
                    return False
                if direction == "BEARISH" and _tag == "GAP_UP":
                    log.info(f"[PATCH_V6_GAP] FNO blocked {symbol} BEARISH: stock GAP_UP {_pct:+.2f}%")
                    return False
                if (direction == "BULLISH" and _tag == "GAP_UP") or (direction == "BEARISH" and _tag == "GAP_DOWN"):
                    log.info(f"[PATCH_V6_GAP] OK {symbol} {direction}: aligned with {_tag} {_pct:+.2f}%")
        except Exception as _e:
            log.warning(f"[PATCH_V6_GAP] gap check failed for {symbol}: {_e}, allowing entry")
        # END_PATCH_V6_GAP

        # PATCH_V8_SECTOR_ROTATION: only trade stocks in strong sectors
        try:
            if self._sector_rotation and self._sector_rotation._ranking:
                _bias, _sec_name, _sec_pct = self._sector_rotation.get_sector_bias(symbol)
                if _bias == "BOTTOM" and SECTOR_ROTATION_BOTTOM_BLOCK:
                    log.info(f"[PATCH_V8_SECTOR] FNO blocked {symbol}: sector {_sec_name} in bottom-2 ({_sec_pct:+.2f}%)")
                    return False
                elif _bias == "TOP":
                    log.info(f"[PATCH_V8_SECTOR] OK {symbol}: sector {_sec_name} in top-3 ({_sec_pct:+.2f}%) — boosted")
        except Exception as _e:
            log.warning(f"[PATCH_V8_SECTOR] sector check failed for {symbol}: {_e}, allowing entry")
        # END_PATCH_V8_SECTOR_ROTATION
        if not self.risk or not self.risk.can_trade():
            return False

        kite = KiteSession.kite()
        if not kite:
            return False

        # Safety: crash protection only (no regime filter for F&O)
        if not SafetyFilters.check_nifty_crash(kite): return False

        # PATCH_V1_REGIME_GATE: refuse direction-contradicting entries during gap days
        try:
            _nifty_data = kite.ltp(["NSE:NIFTY 50"])
            _nifty_ltp = _nifty_data.get("NSE:NIFTY 50", {}).get("last_price", 0)
            _nifty_ohlc = kite.ohlc(["NSE:NIFTY 50"]).get("NSE:NIFTY 50", {}).get("ohlc", {})
            _yest_close = _nifty_ohlc.get("close", 0)
            if _nifty_ltp > 0 and _yest_close > 0:
                _intraday_pct = ((_nifty_ltp - _yest_close) / _yest_close) * 100
                if direction == "BULLISH" and _intraday_pct <= -0.5:
                    log.info(f"[PATCH_V1_REGIME] BLOCKED bullish {symbol}: NIFTY {_intraday_pct:.2f}% (gap down)")
                    return False
                if direction == "BEARISH" and _intraday_pct >= 0.5:
                    log.info(f"[PATCH_V1_REGIME] BLOCKED bearish {symbol}: NIFTY {_intraday_pct:.2f}% (gap up)")
                    return False
                log.debug(f"[PATCH_V1_REGIME] OK {symbol} {direction}: NIFTY {_intraday_pct:.2f}%")
        except Exception as _e:
            log.warning(f"[PATCH_V1_REGIME] check failed for {symbol}: {_e}, allowing entry")
        # END_PATCH_V1_REGIME_GATE

        # PATCH_V1_CONVICTION_LOCK: no contradictory CE+PE on same underlying+expiry
        try:
            import re as _re
            _new_dir_is_call = (direction == "BULLISH")
            for _key, _pos in self.positions.items():
                _ptsym = _pos.get("tradingsymbol", "")
                if not _ptsym.startswith(symbol):
                    continue
                _m = _re.match(rf"^{_re.escape(symbol)}(\d{{2}}[A-Z]{{3}})", _ptsym)
                if not _m:
                    continue
                _existing_expiry = _m.group(1)
                _existing_is_call = _ptsym.endswith("CE")
                _existing_is_put = _ptsym.endswith("PE")
                if _new_dir_is_call and _existing_is_put:
                    log.info(f"[PATCH_V1_CONVICTION] BLOCKED bullish {symbol}: already hold PE {_ptsym}")
                    return False
                if (not _new_dir_is_call) and _existing_is_call:
                    log.info(f"[PATCH_V1_CONVICTION] BLOCKED bearish {symbol}: already hold CE {_ptsym}")
                    return False
        except Exception as _e:
            log.warning(f"[PATCH_V1_CONVICTION] check failed for {symbol}: {_e}, allowing entry")
        # END_PATCH_V1_CONVICTION_LOCK

        # Order guard: duplicate + SEBI + pending check
        can_order, guard_reason = OrderGuard.can_place_order(symbol, is_fno=True)
        if not can_order:
            log.info(f"FNO: {symbol} blocked by OrderGuard: {guard_reason}")
            return False
        if OrderGuard.check_pending_orders(kite, symbol, is_fno=True):  # V28 A7
            return False

        try:
            # Get spot price
            ltp_data = kite.ltp([f"NSE:{symbol}"])
            spot = ltp_data.get(f"NSE:{symbol}", {}).get("last_price", 0)
            if spot <= 0:
                return False

            # V28 C3: Freak spot protection — reject if spot >20% off prev close
            try:
                _q = kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
                _prev = _q.get("ohlc", {}).get("close", 0)
                if _prev > 0 and abs(spot - _prev) / _prev > 0.20:
                    log.warning(f"FNO: {symbol} FREAK SPOT — spot={spot}, prev={_prev}, diff={(spot-_prev)/_prev*100:.1f}%, REJECTING")
                    return False
            except Exception:
                pass

            # Find best option
            option = self._find_best_option(kite, symbol, direction, spot, catalyst_score=score)
            if not option:
                log.info(f"FNO: no suitable option for {symbol} {direction}")
                return False

            tsym = option["tradingsymbol"]
            lot = option["lot_size"]
            premium = option["premium"]
            cost = lot * premium

            # V28 D4: Smart F&O sizing (respects your constraint that small F&O capital
            # can't always fit 30% — without allowing 95% catastrophic single-trade risk).
            # Rules:
            #   cost_pct = cost / available
            #   <= 0.30          -> OK (safe)
            #   0.30 < x <= 0.60 -> OK (allowed, but logged — lot-cost forces this)
            #   > 0.60           -> BLOCK (position too concentrated)
            # Keeps the original FNO_CAP_PER_TRADE as absolute ceiling too.
            if self.available <= 0:
                log.info(f"FNO: {tsym} no available capital")
                return False
            cost_pct = cost / self.available if self.available > 0 else 1.0
            if cost_pct > 0.60:
                log.info(f"FNO: {tsym} cost={cost:.0f} = {cost_pct*100:.0f}% of available Rs.{self.available:.0f} — BLOCKED (>60%)")
                return False
            if cost_pct > 0.30:
                log.info(f"FNO: {tsym} cost={cost:.0f} = {cost_pct*100:.0f}% of available (30-60% zone, allowed due to lot-cost)")
            # Absolute ceiling (legacy FNO_CAP_PER_TRADE)
            if cost > self.available * FNO_CAP_PER_TRADE or cost > self.available:
                log.info(f"FNO: {tsym} cost={cost:.0f} exceeds legacy ceiling")
                return False

            # Smart order pricing using market depth (v26.2: hardened against zero/stale quotes)
            def _tick_round(p):
                return round(round(p / 0.05) * 0.05, 2)
            
            smart_price = 0.0
            try:
                depth_data = kite.quote([f"NFO:{tsym}"])
                q = depth_data.get(f"NFO:{tsym}", {})
                ltp = q.get("last_price", 0) or 0
                depth = q.get("depth", {})
                asks = depth.get("sell", [])
                ask1_price = asks[0].get("price", 0) if asks else 0
                ask1_qty = asks[0].get("quantity", 0) if asks else 0
                ask2_price = asks[1].get("price", 0) if len(asks) > 1 else 0
                ask2_qty = asks[1].get("quantity", 0) if len(asks) > 1 else 0
                if ask1_price > 0:
                    if ask2_qty > ask1_qty * 5 and ask2_price > 0:
                        smart_price = (ask1_price + ask2_price) / 2
                        log.info(f"FNO: smart pricing {tsym} L1={ask1_price}x{ask1_qty} L2={ask2_price}x{ask2_qty}")
                    else:
                        smart_price = ask1_price * 1.005
                elif ltp > 0:
                    smart_price = ltp * 1.02
                    log.info(f"FNO: {tsym} no ask quote, using LTP={ltp} + 2%")
                elif premium > 0:
                    smart_price = premium * 1.02
                    log.info(f"FNO: {tsym} no market data, using theoretical premium={premium} + 2%")
            except Exception as _e:
                log.warning(f"FNO: quote fetch failed for {tsym}: {_e}")
                smart_price = premium * 1.02 if premium > 0 else 0.0
            
            smart_price = _tick_round(smart_price)
            if smart_price <= 0:
                log.warning(f"FNO: {tsym} smart_price zero after all fallbacks, ABORTING (premium was {premium})")
                return False
            
            # Place order with smart price
            order_id = kite.place_order(
                variety=kite.VARIETY_REGULAR,
                exchange="NFO",
                tradingsymbol=tsym,
                transaction_type="BUY",
                quantity=lot,
                order_type="LIMIT",
                price=smart_price,
                product="NRML",
                validity="DAY",
                market_protection=5,  # SEBI mandatory
            )
            log.info(f"FNO: ORDER PLACED {tsym} lot={lot} premium={premium} order_id={order_id}")
            OrderGuard.record_order(tsym)
            OrderGuard.record_order(symbol)  # Block both tradingsymbol and underlying

            # V27 PATCH (Bug #8): Poll for actual fill (not 3-sec assumption).
            # Saves position only on COMPLETE. Cancels and aborts on timeout.
            fill_price = 0.0
            order_status = None
            _poll_max_sec = 15
            _poll_interval = 1.5
            _elapsed = 0.0
            while _elapsed < _poll_max_sec:
                time.sleep(_poll_interval)
                _elapsed += _poll_interval
                try:
                    orders = kite.orders()
                    for o in orders:
                        if str(o.get("order_id")) == str(order_id):
                            order_status = o.get("status")
                            if o.get("average_price", 0) > 0:
                                fill_price = o["average_price"]
                            break
                except Exception as _oe:
                    log.warning(f"FNO: {tsym} order poll error: {_oe}")
                    continue

                if order_status == "COMPLETE":
                    log.info(f"FNO: {tsym} FILLED at {fill_price} after {_elapsed:.1f}s")
                    break
                if order_status == "REJECTED":
                    log.error(f"FNO: {tsym} order REJECTED")
                    return False
                if order_status == "CANCELLED":
                    log.warning(f"FNO: {tsym} order CANCELLED externally")
                    return False

            if order_status != "COMPLETE":
                log.warning(f"FNO: {tsym} order status={order_status} after {_poll_max_sec}s, CANCELLING to avoid phantom position")
                try:
                    kite.cancel_order(variety=kite.VARIETY_REGULAR, order_id=order_id)
                except Exception as _ce:
                    log.error(f"FNO: {tsym} cancel failed: {_ce}")
                return False

            if fill_price <= 0:
                log.error(f"FNO: {tsym} COMPLETE but fill_price=0, ABORTING (will not save phantom position)")
                return False

            # Save position
            key = tsym
            self.positions[key] = {
                "tradingsymbol": tsym,
                "symbol": symbol,
                "qty": lot,
                "entry_price": fill_price,
                "entry_time": now_ist().isoformat(),
                "cost": lot * fill_price,
                "peak_premium": fill_price,
                "sl_price": round(fill_price * (1 - FNO_SL_PCT), 2),
                "expiry": str(option["expiry"]),
                "dte_at_entry": option["dte"],
                "strike": option["strike"],
                "direction": direction,
                "catalyst": catalyst,
                "order_id": str(order_id),
                "source": getattr(self, "_pending_source", "UNKNOWN"),
            }
            self.available -= cost
            self._save_positions()

            # GTT SL (SL-only, no target cap - let winners run)
            # V27 PATCH (Bug #8b): order_status guaranteed COMPLETE here by poll above
            sl = round(fill_price * (1 - FNO_SL_PCT), 2)
            self.gtt.ensure_gtt(tsym, "NFO", lot, sl)

            self.telegram.send(
                f"F&O BUY {tsym}\n"
                f"Lot: {lot} | Premium: Rs.{fill_price:,.1f}\n"
                f"Cost: Rs.{lot * fill_price:,.0f}\n"
                f"SL: Rs.{round(fill_price * 0.7, 1)} | DTE: {option['dte']}\n"
                f"Direction: {direction}\n"
                f"Catalyst: {catalyst[:60]}",
                force=True,
            )
            return True

        except Exception as e:
            log.error(f"FNO: entry {symbol} failed: {e}")
            return False

    def _old_check_trailing_sl_fno(self):
        """
        F&O trailing SL:
        - Activate at +20% profit
        - Trail 15% from peak premium
        - SL only moves UP
        """
        if not self.positions:
            return

        kite = KiteSession.kite()
        if not kite:
            return

        try:
            sym_list = [f"NFO:{p['tradingsymbol']}" for p in self.positions.values()
                        if p.get("tradingsymbol")]
            if not sym_list:
                return
            ltp_data = kite.ltp(sym_list)

            for key, pos in list(self.positions.items()):
                tsym = pos.get("tradingsymbol", "")
                full_quote = ltp_data.get(f"NFO:{tsym}", {})
                ltp = full_quote.get("last_price", 0)
                if ltp <= 0:
                    continue
                
                prev_close_prem = full_quote.get("ohlc", {}).get("close", 0)

                entry = pos.get("entry_price", 0)
                peak = pos.get("peak_premium", entry)
                old_sl = pos.get("sl_price", 0)

                # Update peak
                if ltp > peak:
                    pos["peak_premium"] = ltp

                # Check if trail should activate
                pnl_pct = (ltp - entry) / entry if entry > 0 else 0

                if pnl_pct >= FNO_TRAIL_ACTIVATE:
                    # Trail 15% from peak
                    new_sl = round(pos["peak_premium"] * (1 - FNO_TRAIL_PCT), 2)
                    if new_sl > old_sl and new_sl < ltp:
                        pos["sl_price"] = new_sl
                        self._save_positions()
                        log.info(f"FNO trail: {tsym} SL {old_sl}→{new_sl} (LTP={ltp}, peak={pos['peak_premium']})")

                # ── Greek monitoring ──
                pnl_pct = (ltp - entry) / entry if entry > 0 else 0
                
                # 1. Premium collapse — Delta near zero, option is worthless
                if entry > 0 and ltp < entry * 0.20 and ltp > 0:
                    log.info(f"FNO: {tsym} premium collapsed to {ltp} (entry={entry}) — Delta near 0")
                    self._exit_position(key, "DELTA_NEAR_ZERO")
                    continue
                
                # 2. Theta burn check — if holding > 5 days and losing, theta is killing it
                entry_time = pos.get("entry_time", "")
                days_held = 0
                if entry_time:
                    try:
                        entry_dt = datetime.fromisoformat(entry_time.replace("Z", "+00:00"))
                        days_held = (now_ist() - entry_dt).days
                    except Exception:
                        pass
                
                if days_held >= 5 and pnl_pct < -0.10:
                    # Held 5+ days and losing 10%+ — theta is eating premium
                    log.info(f"FNO: {tsym} held {days_held}d, P&L {pnl_pct:.0%} — theta burn, consider exit")
                    if days_held >= 8 and pnl_pct < -0.20:
                        # 8+ days and -20% — definitely exit
                        log.info(f"FNO: {tsym} held {days_held}d, P&L {pnl_pct:.0%} — theta exit")
                        self._exit_position(key, f"THETA_BURN_{days_held}d")
                        continue
                
                # 3. IV crush detection — if premium drops 30%+ in one day, IV crushed
                if prev_close_prem > 0:
                    daily_change = (ltp - prev_close_prem) / prev_close_prem
                    if daily_change < -0.30:
                        log.warning(f"FNO: {tsym} IV CRUSH detected — premium dropped {daily_change:.0%} in 1 day")
                        self._exit_position(key, "IV_CRUSH_DETECTED")
                        continue

                # Check SL breach
                if ltp <= old_sl and old_sl > 0:
                    log.info(f"FNO: {tsym} SL breached LTP={ltp} <= SL={old_sl}")
                    self._exit_position(key, "SL_BREACHED")

        except Exception as e:
            log.error(f"FNO trailing SL error: {e}")


    def check_trailing_sl(self):
        """V27 PATCH (Bugs #1, #2, #7): Peak-anchored monotonic F&O trail.

        Fixes:
          - Bug #1: SL anchored to PEAK premium, not live LTP
          - Bug #2: Local monotonic guard (defense-in-depth with ensure_gtt)
          - Bug #7: Skip when off peak by trail%, not just when below avg

        Peaks persisted in /home/globalbot/fno_peaks.json — survives restarts.
        """
        try:
            kite = KiteSession.kite()
            if not kite:
                log.warning("FNO trail: no Kite session")
                return

            positions = kite.positions().get("net", [])
            fno_positions = [p for p in positions
                             if p.get("exchange") == "NFO" and p.get("quantity", 0) != 0]

            if not fno_positions:
                log.debug("FNO trail: no open positions")
                return

            peaks_file = Path("/home/globalbot/fno_peaks.json")
            try:
                peaks = load_json(str(peaks_file), {})
                if not isinstance(peaks, dict):
                    peaks = {}
            except Exception:
                peaks = {}

            log.info(f"FNO trail V27: checking {len(fno_positions)} positions (DRY_RUN={FNO_TRAIL_DRY_RUN})")

            live_symbols = set()
            for p in fno_positions:
                try:
                    tsym = p.get("tradingsymbol")
                    qty = p.get("quantity", 0)
                    avg = p.get("average_price", 0)
                    live_symbols.add(tsym)

                    ltp_data = kite.ltp([f"NFO:{tsym}"])
                    ltp = ltp_data.get(f"NFO:{tsym}", {}).get("last_price", 0)

                    if ltp <= 0:
                        log.warning(f"FNO trail: {tsym} no LTP, skipping")
                        continue

                    prev_peak = peaks.get(tsym, {}).get("peak", avg if avg > 0 else ltp)
                    if qty > 0:
                        peak = max(prev_peak, ltp)
                    else:
                        peak = min(prev_peak, ltp) if prev_peak > 0 else ltp

                    peaks[tsym] = {"peak": peak, "avg": avg, "last_update": now_ist().isoformat()}

                    pnl_pct = ((ltp - avg) / avg * 100) if avg > 0 else 0
                    direction = "LONG" if qty > 0 else "SHORT"

                    if qty > 0:
                        peak_gain = ((peak - avg) / avg) if avg > 0 else 0
                    else:
                        peak_gain = ((avg - peak) / avg) if avg > 0 else 0

                    if peak_gain < FNO_TRAIL_ACTIVATE:
                        log.info(f"FNO trail: {tsym} {direction} peak_gain={peak_gain*100:.1f}% < activate={FNO_TRAIL_ACTIVATE*100:.1f}%, NOT TRAILING")
                        continue

                    # V28 D5: Two-stage trail
                    # Stage 1 (peak_gain 10%..25%): wide trail 30% to let premium breathe
                    # Stage 2 (peak_gain >= 25%):    tighten to 20% to lock gains
                    if peak_gain < 0.25:
                        _trail_pct = 0.30
                        _stage = "STAGE1_WIDE"
                    else:
                        _trail_pct = FNO_TRAIL_PCT  # 0.20
                        _stage = "STAGE2_TIGHT"

                    if qty > 0:
                        off_peak_pct = ((peak - ltp) / peak) if peak > 0 else 0
                        if off_peak_pct >= _trail_pct:
                            log.info(f"FNO trail: {tsym} LONG off-peak {off_peak_pct*100:.1f}% >= trail {_trail_pct*100:.0f}% [{_stage}], SKIP")
                            continue
                    else:
                        off_peak_pct = ((ltp - peak) / peak) if peak > 0 else 0
                        if off_peak_pct >= _trail_pct:
                            log.info(f"FNO trail: {tsym} SHORT off-peak {off_peak_pct*100:.1f}% [{_stage}], SKIP")
                            continue

                    if qty > 0:
                        new_sl = round(peak * (1 - _trail_pct), 2)
                    else:
                        new_sl = round(peak * (1 + _trail_pct), 2)

                    log.info(f"FNO trail: {tsym} {direction} qty={qty} avg={avg} ltp={ltp} peak={peak} pnl={pnl_pct:.1f}% peak_gain={peak_gain*100:.1f}% [{_stage} {_trail_pct*100:.0f}%] -> proposed_sl={new_sl}")

                    if FNO_TRAIL_DRY_RUN:
                        log.info(f"FNO trail: [DRY_RUN] would ensure_gtt({tsym}, NFO, {abs(qty)}, {new_sl})")
                        continue

                    existing_sl = 0
                    try:
                        all_gtts = kite.get_gtts() or []
                        for g in all_gtts:
                            if g.get("status") != "active":
                                continue
                            cond = g.get("condition", {})
                            if cond.get("tradingsymbol") == tsym and cond.get("exchange") == "NFO":
                                triggers = cond.get("trigger_values", [])
                                if triggers:
                                    existing_sl = float(triggers[0])
                                    break
                    except Exception as _e:
                        log.warning(f"FNO trail: {tsym} GTT lookup for guard failed: {_e}")

                    if qty > 0 and existing_sl > 0 and new_sl <= existing_sl:
                        log.info(f"FNO trail: {tsym} new_sl={new_sl} <= existing={existing_sl}, NO CHANGE (monotonic guard)")
                        continue
                    if qty < 0 and existing_sl > 0 and new_sl >= existing_sl:
                        log.info(f"FNO trail: {tsym} SHORT new_sl={new_sl} >= existing={existing_sl}, NO CHANGE")
                        continue

                    gtt_id = self.gtt.ensure_gtt(tsym, "NFO", abs(qty), new_sl)
                    if gtt_id:
                        log.info(f"FNO trail: {tsym} GTT ensured id={gtt_id} sl={new_sl} (was {existing_sl})")
                    else:
                        log.warning(f"FNO trail: {tsym} ensure_gtt returned None")

                except Exception as e:
                    log.error(f"FNO trail per-position error {p.get('tradingsymbol')}: {e}")

            stale = [k for k in list(peaks.keys()) if k not in live_symbols]
            for k in stale:
                del peaks[k]
                log.info(f"FNO trail: pruned peak for closed position {k}")

            try:
                save_json(str(peaks_file), peaks)
            except Exception as _e:
                log.error(f"FNO trail: failed to save peaks: {_e}")

        except Exception as e:
            log.error(f"FNO trailing SL (Kite-only) error: {e}")

    def _try_roll_position(self, key, pos, kite):
        """
        Roll a profitable position to next month expiry.
        Sell current month, buy next month at same/similar strike.
        Only rolls if position is profitable (don't roll losers).
        Returns True if rolled, False if not.
        """
        tsym = pos.get("tradingsymbol", "")
        entry = pos.get("entry_price", 0)
        symbol = pos.get("symbol", "")
        direction = pos.get("direction", "BULLISH")
        
        if not tsym or not symbol or not kite:
            return False
        
        try:
            # Check if profitable
            ltp_data = kite.ltp([f"NFO:{tsym}"])
            ltp = ltp_data.get(f"NFO:{tsym}", {}).get("last_price", 0)
            if ltp <= 0 or ltp <= entry:
                return False  # Not profitable — don't roll, just exit
            
            profit_pct = (ltp - entry) / entry
            if profit_pct < 0.10:
                return False  # Less than 10% profit — not worth rolling
            
            # Find next month option at similar strike
            spot_data = kite.ltp([f"NSE:{symbol}"])
            spot = spot_data.get(f"NSE:{symbol}", {}).get("last_price", 0)
            if spot <= 0:
                return False
            
            next_option = self._find_best_option(kite, symbol, direction, spot)
            if not next_option:
                return False
            
            # Check cost fits capital
            roll_cost = next_option["premium"] * next_option["lot_size"]
            if roll_cost > self.available + (ltp * pos.get("qty", 0)):
                return False
            
            # Step 1: Sell current position
            qty = pos.get("qty", 0)
            sell_id = kite.place_order(
                variety=kite.VARIETY_REGULAR, exchange="NFO",
                tradingsymbol=tsym, transaction_type="SELL",
                quantity=qty, order_type="MARKET", product="NRML",
                validity="DAY", market_protection=5,
            )
            log.info(f"FNO ROLL: sold {tsym} x{qty} for roll")
            OrderGuard.record_order(tsym)
            
            time.sleep(3)
            
            # Step 2: Buy next month
            new_tsym = next_option["tradingsymbol"]
            new_lot = next_option["lot_size"]
            new_premium = next_option["premium"]
            
            buy_id = kite.place_order(
                variety=kite.VARIETY_REGULAR, exchange="NFO",
                tradingsymbol=new_tsym, transaction_type="BUY",
                quantity=new_lot, order_type="LIMIT",
                price=round(new_premium * 1.005, 1),
                product="NRML", validity="DAY", market_protection=5,
            )
            log.info(f"FNO ROLL: bought {new_tsym} x{new_lot} @ {new_premium}")
            OrderGuard.record_order(new_tsym)
            OrderGuard.record_order(symbol)
            
            # Update position
            del self.positions[key]
            self.positions[new_tsym] = {
                "tradingsymbol": new_tsym,
                "symbol": symbol,
                "qty": new_lot,
                "entry_price": new_premium,
                "entry_time": now_ist().isoformat(),
                "cost": new_lot * new_premium,
                "peak_premium": new_premium,
                "sl_price": round(new_premium * (1 - FNO_SL_PCT), 2),
                "expiry": str(next_option["expiry"]),
                "direction": direction,
                "catalyst": f"ROLLED from {tsym}",
            }
            self._save_positions()
            
            self.telegram.send(
                f"F&O ROLLED\n"
                f"Sold: {tsym} (profit {profit_pct:.0%})\n"
                f"Bought: {new_tsym} DTE={next_option['dte']}\n"
                f"Reason: DTE low, position profitable — rolled to next month",
                force=True,
            )
            return True
            
        except Exception as e:
            log.error(f"FNO roll {tsym} failed: {e}")
            return False

    def check_dte_exits(self):
        """DTE cascade — exit or roll before expiry kills premium."""
        today = today_ist()
        kite = KiteSession.kite()
        
        for key in list(self.positions.keys()):
            pos = self.positions[key]
            expiry_str = pos.get("expiry", "")
            try:
                expiry = datetime.strptime(expiry_str, "%Y-%m-%d").date()
            except Exception:
                continue

            dte = (expiry - today).days

            # Physical delivery risk — stock options must exit 2 days before expiry
            is_stock_option = not any(idx in pos.get("tradingsymbol", "") for idx in ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"])
            if is_stock_option and dte <= 2:
                log.info(f"FNO: {pos['tradingsymbol']} DTE={dte} PHYSICAL DELIVERY RISK — exit now")
                self._exit_position(key, f"PHYSICAL_DELIVERY_DTE_{dte}")
                continue

            if dte <= FNO_EMERGENCY_DTE:
                # Try to roll if profitable, otherwise exit
                if kite and self._try_roll_position(key, pos, kite):
                    log.info(f"FNO: {pos.get('tradingsymbol','')} DTE={dte} — ROLLED to next month")
                    continue
                log.info(f"FNO: {pos['tradingsymbol']} DTE={dte} EMERGENCY EXIT (roll failed)")
                self._exit_position(key, f"DTE_EMERGENCY_{dte}")
            elif dte <= FNO_DTE_CUT_LOSERS:
                # Cut if losing
                entry = pos.get("entry_price", 0)
                if kite:
                    ltp_data = kite.ltp([f"NFO:{pos['tradingsymbol']}"])
                    ltp = ltp_data.get(f"NFO:{pos['tradingsymbol']}", {}).get("last_price", 0)
                    if ltp > 0 and ltp < entry:
                        log.info(f"FNO: {pos['tradingsymbol']} DTE={dte} losing, cutting")
                        self._exit_position(key, f"DTE_CUT_LOSER_{dte}")

    def _exit_position(self, key, reason):
        """Exit an F&O position."""
        pos = self.positions.get(key)
        if not pos:
            return

        kite = KiteSession.kite()
        if not kite:
            return

        try:
            tsym = pos.get("tradingsymbol", "")
            qty = pos.get("qty", 0)
            if qty <= 0 or not tsym:
                return

            order_id = kite.place_order(
                variety=kite.VARIETY_REGULAR,
                exchange="NFO",
                tradingsymbol=tsym,
                transaction_type="SELL",
                quantity=qty,
                order_type="MARKET",
                product="NRML",
                validity="DAY",
                market_protection=5,  # SEBI mandatory
            )
            log.info(f"FNO: SELL {tsym} x{qty} reason={reason}")

            time.sleep(2)
            exit_price = 0
            try:
                orders = kite.orders()
                for o in orders:
                    if str(o.get("order_id")) == str(order_id):
                        exit_price = o.get("average_price", 0)
                        break
            except Exception:
                pass

            entry = pos.get("entry_price", 0)
            pnl = (exit_price - entry) * qty if exit_price > 0 else 0

            # Record trade
            trade = {
                "tradingsymbol": tsym,
                "entry_price": entry,
                "exit_price": exit_price,
                "qty": qty,
                "pnl": round(pnl, 2),
                "reason": reason,
                "entry_time": pos.get("entry_time", ""),
                "exit_time": now_ist().isoformat(),
                "source": pos.get("source", "UNKNOWN"),
                "symbol": pos.get("symbol", ""),
                "direction": pos.get("direction", ""),
            }
            trades = load_json(self._trades_file, {"trades": []})
            trades["trades"].append(trade)
            save_json(self._trades_file, trades)

            if self.risk:
                self.risk.record_trade(pnl)

            del self.positions[key]
            self._save_positions()

            self.telegram.send(
                f"F&O SELL {tsym}\n"
                f"P&L: Rs.{pnl:,.0f} | Reason: {reason}",
                force=True,
            )

        except Exception as e:
            log.error(f"FNO: exit {key} failed: {e}")

    def scan_and_trade(self):
        """
        Main F&O scan.
        ALL sources: news, filings, brokerage, macro, earnings calendar.
        Direction: BULLISH → CE, BEARISH → PE.
        NO regime filter. Catalyst score is the only gate.
        """
        if not self.risk or not self.risk.can_trade():
            return

        # Gather candidates from ALL sources
        candidates = []

        # Source 1: News RSS
        if self.news:
            candidates.extend(self.news.scan())

        # Source 2: NSE Filings
        if self.filings:
            candidates.extend(self.filings.scan())

        # Source 3: Brokerage calls
        if self.brokerage:
            candidates.extend(self.brokerage.scan())

        # Source 4: Macro events (most important for F&O)
        if self.macro:
            candidates.extend(self.macro.scan())

        # ── V27 Stage 2: LLM news brain (dry-run by default) ──
        # Runs alongside keyword path. In dry-run, only logs decisions.
        # In live mode (LLM_DRY_RUN=False), candidates are added to the trade list.
        if getattr(self, "news_brain", None):
            try:
                # Re-scan news as raw items so NewsBrain can analyze full text
                _llm_news_items = []
                if self.news:
                    # Use existing scanner output — already deduplicated & filtered
                    _llm_news_items = self.news.scan() or []
                _llm_cands = self.news_brain.analyze_news_batch(_llm_news_items) if _llm_news_items else []
                if _llm_cands:
                    log.info(f"[LLM] NewsBrain returned {len(_llm_cands)} candidates (DRY_RUN={LLM_DRY_RUN})")
                    for _lc in _llm_cands[:5]:  # top 5 only to avoid spam
                        log.info(f"[LLM] {_lc['symbol']} {_lc['direction']} score={_lc['score']} reasoning={_lc.get('reasoning','')[:120]}")
                    # Telegram notify on every LLM decision in dry-run
                    if LLM_DRY_RUN:
                        try:
                            _msg = "[LLM DRY-RUN] NewsBrain candidates:\n"
                            for _lc in _llm_cands[:5]:
                                _msg += f"- {_lc['symbol']} {_lc['direction']} ({_lc['score']}): {_lc.get('reasoning','')[:80]}\n"
                            self.telegram.send(_msg, force=True)
                        except Exception as _te:
                            log.warning(f"[LLM] telegram notify failed: {_te}")
                    else:
                        # LIVE mode: merge into candidates list
                        candidates.extend(_llm_cands)
                        log.info(f"[LLM] LIVE mode: {len(_llm_cands)} candidates added to trade list")
                else:
                    log.debug("[LLM] NewsBrain returned 0 candidates this scan")
            except Exception as _le:
                log.error(f"[LLM] NewsBrain scan failed: {_le}")

        # PATCH_V5_OI_LOGGER: Source 6 — OI buildup signals
        if self._oi_engine:
            try:
                oi_candidates = self._oi_engine.detect_buildup_signals()
                if oi_candidates:
                    candidates.extend(oi_candidates)
                    log.info(f"[PATCH_V5_OI] {len(oi_candidates)} OI buildup candidates added to F&O scan")
            except Exception as _e:
                log.error(f"[PATCH_V5_OI] signal injection failed: {_e}")

        # PATCH_V28_MOMENTUM_SCANNER: Source 7 — Price momentum signals
        # Scans all 218 F&O stocks for intraday moves >= 3% with volume >= 2x average.
        # Score 58 (below catalyst 70+) so momentum plays only enter when gates are clear.
        # Catches Trent-type non-news moves that keyword scanner misses.
        try:
            kite = KiteSession.kite()
            if kite and is_market_hours():
                _mom_candidates = []
                _fno_list = list(self.fno_stocks)
                _mom_checked = 0
                for _bi in range(0, min(len(_fno_list), 220), 20):
                    _batch = _fno_list[_bi:_bi+20]
                    _sym_keys = [f"NSE:{s}" for s in _batch]
                    try:
                        _quotes = kite.quote(_sym_keys)
                    except Exception:
                        continue
                    for _sym in _batch:
                        _q = _quotes.get(f"NSE:{_sym}", {})
                        if not _q:
                            continue
                        _mom_checked += 1
                        _ltp = _q.get("last_price", 0)
                        _ohlc = _q.get("ohlc", {})
                        _prev_close = _ohlc.get("close", 0)
                        _volume = _q.get("volume", 0)
                        _avg_volume = _q.get("average_volume", 0)
                        if _ltp <= 0 or _prev_close <= 0:
                            continue
                        _change_pct = ((_ltp - _prev_close) / _prev_close) * 100
                        _vol_ratio = (_volume / _avg_volume) if _avg_volume > 0 else 0
                        # Momentum threshold: >= 3% move with >= 2x volume
                        if abs(_change_pct) >= 3.0 and _vol_ratio >= 2.0:
                            _direction = "BULLISH" if _change_pct > 0 else "BEARISH"
                            _score = min(58 + int(abs(_change_pct)), 68)  # 58-68 range
                            _mom_candidates.append({
                                "symbol": _sym,
                                "direction": _direction,
                                "score": _score,
                                "catalyst": f"MOMENTUM: {_change_pct:+.1f}% vol={_vol_ratio:.1f}x",
                                "source": "MOMENTUM",
                                "timestamp": now_ist().isoformat(),
                            })
                if _mom_candidates:
                    candidates.extend(_mom_candidates)
                    _mom_syms = ", ".join(c["symbol"] for c in _mom_candidates[:5])
                    log.info(f"[PATCH_V28_MOMENTUM] {len(_mom_candidates)} momentum signals from {_mom_checked} stocks: {_mom_syms}")
                else:
                    log.debug(f"[PATCH_V28_MOMENTUM] 0 momentum signals from {_mom_checked} stocks")
        except Exception as _me:
            log.error(f"[PATCH_V28_MOMENTUM] scanner failed: {_me}")

        # Source 5: Earnings plays — pre-earnings IV expansion strategy
        # PATCH_V7_SIGNAL_QUALITY: inherit direction from other signals on same stock, skip if none
        if self.earnings:
            plays = self.earnings.get_earnings_plays(self.fno_stocks)
            # Build direction map from current candidates (news/macro/filing/brokerage already scanned)
            _existing_dirs = {}
            for _c in candidates:
                _sym = _c.get("symbol")
                _d = _c.get("direction")
                if _sym and _d in ("BULLISH", "BEARISH"):
                    if _sym not in _existing_dirs:
                        _existing_dirs[_sym] = []
                    _existing_dirs[_sym].append(_d)
            for play in plays:
                sym = play["symbol"]
                if play["action"] == "BUY_IV_PLAY":
                    # Look up real direction from other signals
                    real_dirs = _existing_dirs.get(sym, [])
                    if not real_dirs:
                        log.info(f"[PATCH_V7_SQ] earnings {sym} skipped: no directional signal found")
                        continue
                    # If conflicting, skip (contradiction check handles it anyway)
                    if "BULLISH" in real_dirs and "BEARISH" in real_dirs:
                        log.info(f"[PATCH_V7_SQ] earnings {sym} skipped: conflicting signals")
                        continue
                    real_direction = real_dirs[0]
                    candidates.append({
                        "symbol": sym,
                        "direction": real_direction,
                        "score": play["score"],
                        "catalyst": f"EARNINGS+{real_direction}: {play['catalyst']}",
                        "source": "EARNINGS_PLAY",
                        "timestamp": now_ist().isoformat(),
                    })
                    log.info(f"[PATCH_V7_SQ] FNO earnings play: {sym} in {play['days_to']}d direction={real_direction} (inherited)")
                elif play["action"] == "BUY_IF_STRONG":
                    real_dirs = _existing_dirs.get(sym, [])
                    if not real_dirs or ("BULLISH" in real_dirs and "BEARISH" in real_dirs):
                        continue
                    candidates.append({
                        "symbol": sym,
                        "direction": real_dirs[0],
                        "score": play["score"],
                        "catalyst": f"EARNINGS+{real_dirs[0]}: {play['catalyst']}",
                        "source": "EARNINGS_MODERATE",
                        "timestamp": now_ist().isoformat(),
                    })
                elif play["action"] == "EXIT_IV_CRUSH":
                    # Danger zone — exit existing positions for this stock
                    for key, pos in list(self.positions.items()):
                        if play["symbol"] in pos.get("tradingsymbol", ""):
                            log.warning(f"FNO IV CRUSH: {pos['tradingsymbol']} — {play['symbol']} results in {play['days_to']}d, EXITING")
                            self._exit_position(key, f"IV_CRUSH_{play['days_to']}d_before_results")

        # Source 6: Index options — NIFTY/BANKNIFTY always scanned
        for idx in ["NIFTY", "BANKNIFTY"]:
            if idx in self.fno_stocks:
                candidates.append({
                    "symbol": idx,
                    "direction": "BULLISH",
                    "score": 60,
                    "catalyst": "INDEX: permanent scan for cheap options",
                    "source": "INDEX",
                })
                candidates.append({
                    "symbol": idx,
                    "direction": "BEARISH",
                    "score": 60,
                    "catalyst": "INDEX: permanent scan for cheap options",
                    "source": "INDEX",
                })

        # Source 6: Earnings calendar — boost stocks with upcoming results
        if self.earnings:
            upcoming = self.earnings.get_upcoming(days_ahead=14)
            for earn in upcoming:
                sym = earn["symbol"]
                if sym in self.fno_stocks:
                    candidates.append({
                        "symbol": sym,
                        "direction": "BULLISH",  # Default bullish for earnings play
                        "score": 65 + max(0, 14 - earn["days_to"]) * 2,  # Higher score closer to date
                        "catalyst": f"EARNINGS in {earn['days_to']}d ({earn['date']})",
                        "source": "EARNINGS",
                    })

        if not candidates:
            return

        # PATCH_V7_SIGNAL_QUALITY: filter stale candidates (older than 4 hours)
        try:
            _cutoff = now_ist() - timedelta(hours=4)
            _fresh_candidates = []
            for c in candidates:
                ts = c.get("timestamp")
                if not ts:
                    _fresh_candidates.append(c)  # No timestamp = assume fresh (macro/filings)
                    continue
                try:
                    c_ts = datetime.fromisoformat(ts)
                    if c_ts.replace(tzinfo=None) >= _cutoff.replace(tzinfo=None):
                        _fresh_candidates.append(c)
                    else:
                        log.debug(f"[PATCH_V7_SQ] stale candidate skipped: {c.get('symbol')} ts={ts}")
                except Exception:
                    _fresh_candidates.append(c)
            candidates = _fresh_candidates
        except Exception as _e:
            log.warning(f"[PATCH_V7_SQ] time decay filter failed: {_e}")

        # PATCH_V28_CONTRADICTION_TIEBREAK: if same symbol has both bull and bear,
        # keep the stronger signal if score gap >= 10pts, veto both only if close.
        _scores_by_sym = {}
        for c in candidates:
            sym = c.get("symbol")
            d = c.get("direction")
            s = c.get("score", 0)
            if sym and d in ("BULLISH", "BEARISH"):
                if sym not in _scores_by_sym:
                    _scores_by_sym[sym] = {}
                if d not in _scores_by_sym[sym] or s > _scores_by_sym[sym][d]:
                    _scores_by_sym[sym][d] = s
        _conflicting = set()
        _tiebreak_winners = {}
        for sym, dir_scores in _scores_by_sym.items():
            if len(dir_scores) >= 2:
                bull_s = dir_scores.get("BULLISH", 0)
                bear_s = dir_scores.get("BEARISH", 0)
                gap = abs(bull_s - bear_s)
                if gap >= 10:
                    winner = "BULLISH" if bull_s > bear_s else "BEARISH"
                    _tiebreak_winners[sym] = winner
                    log.info(f"[PATCH_V28_TIEBREAK] {sym} contradiction resolved: {winner} wins (B={bull_s} vs R={bear_s}, gap={gap})")
                else:
                    _conflicting.add(sym)
                    log.info(f"[PATCH_V28_TIEBREAK] {sym} contradiction too close, vetoing both (B={bull_s} vs R={bear_s}, gap={gap})")
        # Remove vetoed symbols entirely, keep only winning direction for tiebreak symbols
        _filtered = []
        for c in candidates:
            sym = c.get("symbol")
            if sym in _conflicting:
                continue  # vetoed
            if sym in _tiebreak_winners:
                if c.get("direction") == _tiebreak_winners[sym]:
                    _filtered.append(c)
                # else: losing direction dropped
            else:
                _filtered.append(c)
        candidates = _filtered

        # PATCH_V28_SOURCE_WEIGHT: boost scores based on source reliability
        # Filing/Brokerage = highest conviction, News/Momentum = lowest
        _SOURCE_WEIGHTS = {
            "FILING": 1.15,        # NSE filings — hard data, highest conviction
            "BROKERAGE": 1.12,     # Analyst upgrades/downgrades — professional research
            "PROMOTER_BUY": 1.10,  # Insider buying — strong signal
            "MACRO": 1.05,         # RBI/Fed/GDP — affects entire market
            "52WK_LOW": 1.0,       # Technical — no boost
            "BREAKOUT": 1.0,       # Technical — no boost
            "SECTOR_ROTATION": 1.0,# Sector play — no boost
            "NEWS": 0.95,          # RSS headlines — noisy, slight penalty
            "MOMENTUM": 0.90,      # Price momentum — weakest conviction
        }
        for c in candidates:
            _src = c.get("source", "")
            _w = _SOURCE_WEIGHTS.get(_src, 1.0)
            if _w != 1.0:
                _old_score = c.get("score", 0)
                c["score"] = min(95, int(_old_score * _w))
                if c["score"] != _old_score:
                    log.debug(f"[PATCH_V28_SOURCE_WEIGHT] {c.get('symbol')} {_src}: {_old_score} -> {c['score']} (x{_w})")

        # Deduplicate by symbol (keep highest score)
        best_by_sym = {}
        for c in candidates:
            sym = c["symbol"]
            if sym not in best_by_sym or c.get("score", 0) > best_by_sym[sym].get("score", 0):
                best_by_sym[sym] = c
        candidates = list(best_by_sym.values())

        # Filter: score >= minimum catalyst score
        qualified = [c for c in candidates
                     if c.get("score", 0) >= FNO_MIN_CATALYST
                     and c.get("symbol") in self.fno_stocks
                     and c.get("direction") in ("BULLISH", "BEARISH")]

        qualified.sort(key=lambda c: c.get("score", 0), reverse=True)

        entered = 0
        for cand in qualified[:5]:
            self._pending_source = cand.get("source", "UNKNOWN")
            success = self.enter(
                cand["symbol"],
                cand.get("catalyst", ""),
                cand["direction"],
                cand.get("score", 0),
            )
            if success:
                entered += 1
                if entered >= 2:  # Max 2 F&O entries per scan
                    break

    def tick(self):
        """Called every minute from main loop."""
        n = now_ist()

        # Morning sync at 08:01 (v26.4: skip audit to preserve trailed SLs)
        if n.hour == 8 and n.minute == 1:
            self._refresh_capital()
            self._sync_positions()
            # self._fno_gtt_audit()  # DISABLED — was wiping trailed SLs daily

        # PATCH_V6_GAP: gap detection + AMO review at 08:50 IST
        if n.hour == 8 and n.minute == 50 and is_trading_day():
            if self._gap_detector and self._last_gap_check_day != today_ist():
                self._last_gap_check_day = today_ist()
                try:
                    gap_status = self._gap_detector.detect_gaps()
                    if gap_status:
                        self._gap_detector.review_pending_amos(gap_status)
                except Exception as _e:
                    log.error(f"[PATCH_V6_GAP] morning routine failed: {_e}")

        # PATCH_V28_GTT_AT_FILL: sync + GTT audit at 09:17 to catch AMO fills
        # AMOs fill at 09:15 market open. By 09:17, orders are COMPLETE on Kite.
        # This syncs the new positions into the bot and places GTTs immediately.
        # Prevents CROMPTON-class unprotected positions (Apr 17 incident).
        if n.hour == 9 and n.minute == 17:
            if not getattr(self, "_v28_amo_fill_synced_today", False):
                self._v28_amo_fill_synced_today = True
                try:
                    _before = len(self.positions)
                    self._sync_positions()
                    _after = len(self.positions)
                    if _after > _before:
                        log.info(f"[PATCH_V28_GTT_AT_FILL] synced {_after - _before} new positions from AMO fills")
                    self._fno_gtt_audit()
                    log.info(f"[PATCH_V28_GTT_AT_FILL] GTT audit complete after AMO fill sync")
                except Exception as _e:
                    log.error(f"[PATCH_V28_GTT_AT_FILL] failed: {_e}")

        # SL re-place at 09:16 (v26.4: skip audit to preserve trailed SLs)
        if n.hour == 9 and n.minute == 16:
            self._replace_sl_orders()
            # self._fno_gtt_audit()  # DISABLED — was wiping trailed SLs daily

        # Scan every 15 minutes during market hours
        if is_market_hours() and n.minute % FNO_SCAN_INTERVAL_MIN == 0:
            if self._last_scan != n.hour * 60 + n.minute:
                self._last_scan = n.hour * 60 + n.minute
                self.scan_and_trade()

        # Trailing SL every 5 minutes
        if is_market_hours() and n.minute % 5 == 0:
            if self._last_trail_check != n.hour * 60 + n.minute:
                self._last_trail_check = n.hour * 60 + n.minute
                self.check_trailing_sl()

        # PATCH_V5_OI_LOGGER: hourly OI snapshot during market hours
        if is_market_hours() and self._oi_engine and n.minute < 5:
            if self._last_oi_snapshot_hour != n.hour:
                self._last_oi_snapshot_hour = n.hour
                try:
                    self._oi_engine.take_snapshot()
                except Exception as _e:
                    log.error(f"[PATCH_V5_OI] hourly snapshot failed: {_e}")

        # PATCH_V9_AMO_ARCH: EOD OI snapshot at 15:25 IST (once per trading day)
        if self._oi_engine and n.hour == 15 and n.minute == 25 and is_trading_day():
            if getattr(self, "_last_eod_snapshot_day", None) != today_ist():
                self._last_eod_snapshot_day = today_ist()
                try:
                    self._oi_engine.take_snapshot(is_eod=True)
                except Exception as _e:
                    log.error(f"[PATCH_V9_AMO_ARCH] EOD snapshot failed: {_e}")

        # PATCH_V8_SECTOR_ROTATION: refresh sector ranking every 15 minutes
        if is_market_hours() and self._sector_rotation and n.minute % SECTOR_ROTATION_REFRESH_MIN == 0:
            _sr_key = n.hour * 60 + n.minute
            if self._sector_rotation._last_refresh_minute != _sr_key:
                self._sector_rotation._last_refresh_minute = _sr_key
                try:
                    self._sector_rotation.refresh()
                except Exception as _e:
                    log.error(f"[PATCH_V8_SECTOR] refresh failed: {_e}")

        # DTE check at 09:30 and 14:00
        if n.hour in (9, 14) and n.minute == 30:
            self.check_dte_exits()

        # FIX_V29_MIDDAY_AUDIT: midday GTT safety check at 12:30
        if n.hour == 12 and n.minute == 30:
            self._fno_gtt_audit()

        # EOD report at 15:36
        if n.hour == 15 and n.minute == 36 and is_trading_day():
            report = EODReporter.generate_fno_report(self)
            self.telegram.send(report, force=True)

        # Update earnings calendar at 07:00 and 16:00
        if n.hour in (7, 16) and n.minute == 0:
            try:
                self.earnings.update_from_filings()
                plays = self.earnings.get_earnings_plays(self.fno_stocks)
                if plays:
                    buy_plays = [p for p in plays if p["action"] == "BUY_IV_PLAY"]
                    exit_plays = [p for p in plays if p["action"] == "EXIT_IV_CRUSH"]
                    if buy_plays or exit_plays:
                        msg = "EARNINGS CALENDAR UPDATE\n"
                        for p in buy_plays[:5]:
                            msg += f"BUY: {p['symbol']} results in {p['days_to']}d\n"
                        for p in exit_plays[:5]:
                            msg += f"EXIT: {p['symbol']} results in {p['days_to']}d (IV crush)\n"
                        self.telegram.send(msg, force=True)
            except Exception:
                pass

    def _fno_gtt_audit(self):
        """
        F&O GTT audit. Source of truth: Kite positions (NOT JSON).
        Every F&O position with qty > 0 must have a GTT SL.
        """
        kite = KiteSession.kite()
        if not kite:
            return
        try:
            # Step 1: What F&O positions do I own?
            fno_positions = {}
            positions = kite.positions().get("net", [])
            for p in positions:
                if p.get("exchange") == "NFO" and p.get("quantity", 0) > 0:
                    tsym = p["tradingsymbol"]
                    fno_positions[tsym] = {
                        "qty": p["quantity"],
                        "avg": p.get("average_price", 0),
                    }
            
            if not fno_positions:
                return
            
            # Step 2: What GTTs exist for NFO?
            all_gtts = kite.get_gtts() or []
            fno_gtts = defaultdict(list)
            for g in all_gtts:
                if g.get("status") == "active":
                    sym = g.get("condition", {}).get("tradingsymbol", "")
                    exch = g.get("condition", {}).get("exchange", "")
                    if exch == "NFO" and sym:
                        fno_gtts[sym].append(g)
            
            placed, deleted = 0, 0
            
            # Step 3: Delete duplicates
            for sym, gtts in fno_gtts.items():
                if len(gtts) > 1:
                    gtts.sort(key=lambda g: g.get("id", 0), reverse=True)
                    for dup in gtts[1:]:
                        try:
                            kite.delete_gtt(dup["id"])
                            deleted += 1
                        except Exception:
                            pass
            
            # Step 4: Delete orphans (GTT for position we don't hold)
            for sym in list(fno_gtts.keys()):
                if sym not in fno_positions:
                    for g in fno_gtts[sym]:
                        try:
                            kite.delete_gtt(g["id"])
                            deleted += 1
                            log.info(f"GTT FNO: deleted orphan {sym}")
                        except Exception:
                            pass
            
            # Step 5: Place missing GTTs (SL-only, no target)
            for tsym, info in fno_positions.items():
                qty = info["qty"]
                avg = info["avg"]
                if avg <= 0:
                    continue
                
                existing = fno_gtts.get(tsym, [])
                if existing:
                    # Check triggers are valid
                    triggers = existing[0].get("trigger_values", [])
                    if triggers and len(triggers) > 0:
                        continue  # GTT exists with valid triggers
                    else:
                        # Empty triggers — delete and re-place
                        try:
                            kite.delete_gtt(existing[0]["id"])
                        except Exception:
                            pass
                
                # v26.3: Preserve existing GTT trigger if available (honor trailed SL)
                default_sl = round(avg * (1 - FNO_SL_PCT), 1)
                sl = default_sl
                if existing:
                    _existing_triggers = existing[0].get("trigger_values", [])
                    if _existing_triggers and _existing_triggers[0] > 0:
                        sl = max(sl, float(_existing_triggers[0]))
                        if sl != default_sl:
                            log.info(f"GTT FNO: {tsym} preserving trailed SL={sl} (default would be {default_sl})")
                try:
                    ltp_data = kite.ltp([f"NFO:{tsym}"])
                    last = ltp_data.get(f"NFO:{tsym}", {}).get("last_price", avg)

                    # PATCH_V1_INLOSS_AUDIT: override broken SL before direct place_gtt
                    if last and last > 0 and sl >= last:
                        _new_sl = round(last * 0.85, 1)
                        log.warning(f"[PATCH_V1_INLOSS_AUDIT] {tsym}: SL={sl} >= LTP={last}, overriding to {_new_sl}")
                        sl = _new_sl
                    gtt_id = kite.place_gtt(
                        trigger_type=kite.GTT_TYPE_SINGLE,
                        tradingsymbol=tsym, exchange="NFO",
                        trigger_values=[sl], last_price=last,
                        orders=[{"transaction_type": "SELL", "quantity": qty, "price": round(sl * 0.85, 1), "order_type": "LIMIT", "product": "NRML"}],
                    )
                    placed += 1
                    log.info(f"GTT FNO: placed {tsym} SL={sl} qty={qty} id={gtt_id}")
                except Exception as e:
                    log.error(f"GTT FNO: place {tsym} failed: {e}")
            
            if placed or deleted:
                log.info(f"GTT FNO AUDIT: placed={placed} deleted={deleted}")
        
        except Exception as e:
            log.error(f"GTT FNO audit error: {e}")

    def _replace_sl_orders(self):
        """PATCH_V12_SL_DEDUP: DISABLED. GTTManager (check_trailing_sl every 5 min) handles all SL.

        The legacy _replace_sl_orders ran daily at 09:16 IST and placed regular SL orders
        on top of existing GTTs without cancelling stale ones, causing duplicate stop-losses
        on the same position (e.g., BPCL had SL at 1.20 from old run AND GTT at 5.12 from
        trailing). GTTManager.ensure_gtt() already handles dedup, in-loss floor, and
        upward-only trailing. Running both systems in parallel created the duplicate-SL bug.

        Trusting GTT-only matches the standing rule: GTT is the most critical safety feature.
        """
        log.info("[PATCH_V12_SL_DEDUP] FNO _replace_sl_orders skipped — GTTManager handles SL via check_trailing_sl every 5 min")
        return


# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    log.info(f"{'='*60}")
    log.info(f"  {VERSION} — Starting")
    log.info(f"  Server: <server-ip> | Kite: {ZERODHA_USER_ID}")
    log.info(f"  ZERO paper trading | Real orders only")
    log.info(f"{'='*60}")

    # Load env
    env_path = Path("/home/globalbot/.env")
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())
        # Reload constants from env
        globals().update({
            "KITE_API_KEY": os.getenv("KITE_API_KEY", ""),   # V28 A4: reload from env
            "KITE_API_SECRET": os.getenv("KITE_API_SECRET", ""),
            "KITE_TOTP_SECRET": os.getenv("KITE_TOTP_SECRET", ""),
            "ZERODHA_PASSWORD": os.getenv("ZERODHA_PASSWORD", ""),
            "TELEGRAM_TOKEN": os.getenv("TELEGRAM_TOKEN", ""),
            "TELEGRAM_CHAT_ID": os.getenv("TELEGRAM_CHAT_ID", ""),
        })

    # V28 A4: validate KITE_API_KEY is present after env load
    if not globals().get("KITE_API_KEY"):
        log.error("FATAL: KITE_API_KEY missing from /home/globalbot/.env — add it before restart")
        sys.exit(1)

    # Login to Kite
    if not KiteSession.login():
        log.error("FATAL: Kite login failed. Retrying in 60s...")
        time.sleep(60)
        if not KiteSession.login():
            log.error("FATAL: Kite login failed twice. Exiting.")
            sys.exit(1)

    # Initialize modules — completely independent
    equity = EquityModule()
    fno = FnoModule()

    eq_ok = equity.init()
    fno_ok = fno.init()

    if not eq_ok and not fno_ok:
        log.error("FATAL: both modules failed to init")
        sys.exit(1)

    send_telegram(
        f"*{VERSION} STARTED*\n"
        f"Equity: {'OK' if eq_ok else 'FAILED'} | Rs.{equity.capital:,.0f}\n"
        f"F&O: {'OK' if fno_ok else 'FAILED'} | Rs.{fno.capital:,.0f}\n"
        f"Stocks: {len(equity.all_symbols)} | F&O: {len(fno.fno_stocks)}\n"
        f"Positions: EQ={len(equity.positions)} FNO={len(fno.positions)}\n"
        f"Mode: LIVE — real orders only",
    )

    # Main loop — runs every 60 seconds
    log.info("Main loop started")
    last_minute = -1
    reconnect_count = 0

    while True:
        try:
            n = now_ist()
            current_minute = n.hour * 60 + n.minute

            # Only process once per minute
            if current_minute == last_minute:
                time.sleep(5)
                continue
            last_minute = current_minute

            # Ensure Kite connected
            if not KiteSession.ensure_connected():
                reconnect_count += 1
                if reconnect_count > 5:
                    log.error("Kite: too many reconnect failures, sleeping 5 min")
                    time.sleep(300)
                    reconnect_count = 0
                continue
            reconnect_count = 0

            # Tick both modules independently
            if eq_ok:
                try:
                    equity.tick()
                except Exception as e:
                    log.error(f"Equity tick error: {e}\n{traceback.format_exc()}")

            if fno_ok:
                try:
                    fno.tick()

                    # PATCH_V1_FNO_AMO_HOOK

                    try: fno._fno_amo_continuous_scan()

                    except Exception as _e: log.error(f'[PATCH_V1_FNO_AMO] scan hook: {_e}')

                    try: fno._fno_amo_premarket_place()

                    except Exception as _e: log.error(f'[PATCH_V1_FNO_AMO] place hook: {_e}')
                except Exception as e:
                    log.error(f"FNO tick error: {e}\n{traceback.format_exc()}")

            # Daily log rotation at midnight
            if n.hour == 0 and n.minute == 0:
                log.info("Midnight: daily reset")

            # Kite re-login at 08:00 on trading days
            if n.hour == 8 and n.minute == 0 and is_trading_day():
                KiteSession.login()

            # PATCH_V2_WEEKLY_ATTRIBUTION: Sunday 09:00 IST report
            if n.weekday() == 6 and n.hour == 9 and n.minute == 0:
                try:
                    _wk_report = EODReporter.generate_weekly_attribution(equity, fno)
                    send_telegram(_wk_report, silent=False)
                    log.info("Weekly attribution report sent")
                except Exception as _e:
                    log.error(f"Weekly attribution failed: {_e}")
            # END_PATCH_V2_WEEKLY_ATTRIBUTION

            time.sleep(10)

        except KeyboardInterrupt:
            log.info("Shutdown requested")
            send_telegram(f"*{VERSION} STOPPED* — manual shutdown")
            break
        except Exception as e:
            log.error(f"Main loop error: {e}\n{traceback.format_exc()}")
            time.sleep(30)


if __name__ == "__main__":
    main()
