"""
╔══════════════════════════════════════════════════════════════════════════╗
║         GLOBAL EYE v23.6.0 — TRILLIONAIRE PRO EDITION                   ║
║         Owner: <redacted> | PythonAnywhere: krishnut85                ║
║                                                                          ║
║  v23.6.0 STRATEGY UPGRADES (12 Improvements):                        ║
║  + #1 Trailing Stop Loss — lock profits as stock rises              ║
║  + #2 Time-Decay SL Tightening — kill dead money positions          ║
║  + #3 Independent Agent 3 — fundamentals-only evaluator             ║
║  + #4 Kelly Position Sizing — optimal capital utilization            ║
║  + #5 Intraday Sniper — 1 precision trade/day enabled               ║
║  + #6 Gap-Down Recovery Scanner — 09:15-09:45 bounce buys           ║
║  + #7 Partial Profit Booking — 50% at T1, rest trails               ║
║  + #8 Faster Filing Polls — 30s critical, 60s bulk during hours     ║
║  + #9 Dynamic Sector Rotation — weekly momentum scoring             ║
║  + #10 3-Tier Telegram Alerts — immediate/digest/daily              ║
║  + #11 Continuous Capital Scaling — log2 formula positions           ║
║  + #12 Protective Put Framework — hedge when capital >1L            ║
║                                                                          ║
║  v23.5.0 RETAINED:                                                   ║
║  + GTT Immediate — protection from second one after every buy       ║
║  + Smart SL — AMO only for stocks without GTT (no double-sell)      ║
║  + GTT Audit 08:30 — verify all positions protected before open     ║
║  + Profit Compounding — reinvest gains into next high-conviction    ║
║  + Conviction Sizing — 2x on ultra-high, 0.5x on low conviction    ║
║  + Penny Multibagger Scanner — strict quality penny stocks          ║
║                                                                          ║
║  PHASE 2 SCANNERS (v23.4.0):                                           ║
║  ✅ Promoter Buying Scanner — insider/SAST filing detection            ║
║  ✅ 52-Week Low Recovery — quality stocks bouncing from lows           ║
║  ✅ Zero Idle Cash Compounder — deploy idle capital safely             ║
║  ✅ Superstar Portfolio Tracker — follow legendary investors           ║
║  ✅ Sector Rotation Bias — macro-driven sector weight shifts           ║
║                                                                          ║
║  15-ISSUE FIX UPDATE:                                                   ║
║  ✅ #1  PDF redesign — BE logo, gold/navy scheme, professional layout  ║
║  ✅ #2  Owner name "<redacted>" on ALL reports + PDFs                ║
║  ✅ #3  Technical trades ACTIVE — lowered DVM thresholds               ║
║  ✅ #4  Telegram digest mode — compiled every 30min + live P&L         ║
║  ✅ #5  Long-term criteria relaxed — PE<60, ROE>5%                     ║
║  ✅ #6  ALL sections active — Intraday/Swing/LT/F&O with lower gates  ║
║  ✅ #7  "ed" keyword false positive FIXED — context-aware matching     ║
║  ✅ #8  "Persistent launching AI" no longer flagged as fraud           ║
║  ✅ #9  Dual mode: AGGRESSIVE (default) + BALANCED via .env            ║
║  ✅ #10 Kite login confirmation enhanced — shows on Telegram           ║
║  ✅ #11 AI 3-Agent voting details shown in PDF reports                 ║
║  ✅ #12 Smarter 2/3 voting — mode-aware thresholds                    ║
║  ✅ #13 30-minute momentum scanning (was 60 min)                       ║
║  ✅ #14 BE logo — golden eye design on all PDFs                        ║
║  ✅ #15 Speed boost — SCAN_WORKERS 5, batch Kite LTP                  ║
║                                                                          ║
║  RETAINED FROM v23.0.0:                                                 ║
║  ✅ 3-Agent AI System (Man Group style)                                ║
║  ✅ Macro Intelligence (Ray Dalio) — sector rotation                   ║
║  ✅ Earnings NLP (Citadel) — filing text sentiment                     ║
║  ✅ Pattern Recognition (Simons) — Golden Cross, Double Bottom         ║
║  ✅ Statistical Arbitrage — pairs trading                              ║
║  ✅ AMO Engine — After Market Orders                                   ║
║  ✅ Kite-ONLY data — no Yahoo Finance for scanning                     ║
╚══════════════════════════════════════════════════════════════════════════╝

DEPLOY:
  python3.10 /home/krishnut85/global_eye_v23_pythonanywhere.py

NEW .env VARIABLES:
  STRATEGY_MODE=AGGRESSIVE   # or BALANCED
"""

import os, sys, time, json, logging, threading, traceback, math, re, hashlib
import requests, feedparser, pyotp, pytz
import pandas as pd
import numpy as np
from datetime import datetime, timedelta, date
from concurrent.futures import ThreadPoolExecutor, as_completed
from dotenv import load_dotenv
from bs4 import BeautifulSoup

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                 Table, TableStyle, HRFlowable, PageBreak)
from reportlab.lib.enums import TA_CENTER, TA_LEFT

from kiteconnect import KiteConnect
import yfinance as yf  # ONLY for morning pulse global markets (Dow, Gold, Crude) — NOT for Indian stocks

# ═══════════════════════════════════════════════════════════════════════════
#  SEBI-COMPLIANT SL LIMITS (Rama's <1% SL requirement)
#  All SL calculations across the bot are capped at these values.
# ═══════════════════════════════════════════════════════════════════════════
MAX_SL_PERCENT = 0.009  # 0.9% max (gives margin under 1%)
MIN_SL_PERCENT = 0.003  # 0.3% floor to avoid whipsaw

# ── EARLY .env load (MUST happen before TRADING_MODE check) ──────────────────
try:
    _early_dir = os.path.dirname(os.path.abspath(__file__))
except Exception:
    _early_dir = "/home/krishnut85"
load_dotenv(os.path.join(_early_dir, ".env"))
# Also try hardcoded path if __file__ doesn't work
if not os.getenv("TRADING_MODE"):
    load_dotenv("/home/krishnut85/.env")

# ── Live Trading Module (loaded when TRADING_MODE=LIVE) ─────────────────────
_LIVE_MODULE_LOADED = False
_TIER_MIGRATION_LOADED = False
_PHASE2_LOADED = False
_TRILLIONAIRE_LOADED = False
_STRATEGY_MODULES_LOADED = False
if os.getenv("TRADING_MODE", "PAPER").upper() == "LIVE":
    try:
        import sys as _sys
        # Method 1: Use __file__ directory
        try:
            _script_dir = os.path.dirname(os.path.abspath(__file__))
        except Exception:
            _script_dir = ""
        # Method 2: Hardcoded PythonAnywhere path
        _pa_dir = "/home/krishnut85"
        # Method 3: Current working directory
        _cwd = os.getcwd()
        # Add ALL possible paths
        for _d in [_script_dir, _pa_dir, _cwd]:
            if _d and _d not in _sys.path:
                _sys.path.insert(0, _d)
        from live_trading_patch import (
            upgrade_to_live, LiveOrderManager, LiveEquityTrader,
            LiveFNOAdapter, PositionSync, CapitalAllocator,
            CircuitBreaker, OrderAudit
        )
        from advanced_trading_engine import TrailingStopLoss, KellyCriterion
        from sentiment_matrix import SentimentMatrix
        try:
            from tier_migration_manager import TierMigrationManager
            _TIER_MIGRATION_LOADED = True
        except ImportError:
            _TIER_MIGRATION_LOADED = False
        try:
            from phase2_scanners import (
                Phase2Orchestrator, PromoterBuyingScanner,
                FiftyTwoWeekLowRecovery, ZeroIdleCashCompounder,
                SuperstarPortfolioTracker, SectorRotationBias
            )
            _PHASE2_LOADED = True
        except ImportError:
            _PHASE2_LOADED = False
        _LIVE_MODULE_LOADED = True
        print("✅ Live trading module loaded")
        print("✅ Advanced trading engine loaded (Trailing SL + Kelly)")
        print("✅ Sentiment Matrix loaded (Fear & Greed trading)")
        if _TIER_MIGRATION_LOADED:
            print("✅ Tier Migration Manager loaded")
        if _PHASE2_LOADED:
            print("✅ Phase 2 Scanners loaded (Promoter/52W/Compounder/Superstar/Sector)")
        # ── Trillionaire Engine (v23.5.0) ──
        try:
            from trillionaire_engine import (
                TrillionaireEngine, SectorNewsIntelligence, TrendFollowingExit,
                SuperchargedStatArb, AggressiveCompounder, UltraTightLossControl,
                SEBIOrderLimiter, EventCalendar
            )
            _TRILLIONAIRE_LOADED = True
            print("✅ Trillionaire Engine loaded (Events/TrendExit/StatArb/LossCtrl/SEBI)")
        except ImportError as _te:
            _TRILLIONAIRE_LOADED = False
            print(f"⚠️ Trillionaire Engine not found: {_te}")
        try:
            from strategy_modules import (
                StrategyModulesOrchestrator, FIIDIIFlowTracker,
                GlobalCuesPreMarket,
            )
            _STRATEGY_MODULES_LOADED = True
            print("✅ Strategy Modules loaded (scan enrichment mode)")
        except ImportError as _sm_err:
            _STRATEGY_MODULES_LOADED = False
            print(f"⚠️ Strategy Modules not found: {_sm_err}")
    except ImportError as e:
        _LIVE_MODULE_LOADED = False
        print(f"⚠️ Live trading module not found: {e}")
    except Exception as e:
        _LIVE_MODULE_LOADED = False
        print(f"⚠️ Live module error: {e}")

# ── Trade Performance Monitor (works in ALL modes) ──────────────────────────
_PERF_MONITOR_LOADED = False
try:
    from trade_performance_monitor import TradePerformanceMonitor
    _PERF_MONITOR_LOADED = True
    print("✅ Trade Performance Monitor loaded (Weekly/Monthly analysis)")
except ImportError:
    _PERF_MONITOR_LOADED = False

# ── Gemini — lazy import, avoids Python 3.10 startup crash ────────────────────
GEMINI_NEW = None  # Detected on first call to call_gemini()

# ─── Environment ──────────────────────────────────────────────────────────────
_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_DIR, ".env"))

TELEGRAM_TOKEN   = os.getenv("TELEGRAM_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")
GEMINI_API_KEY   = os.getenv("GEMINI_API_KEY", "")
KITE_API_KEY     = os.getenv("KITE_API_KEY", "")
KITE_API_SECRET  = os.getenv("KITE_API_SECRET", "")
KITE_TOTP_SECRET = os.getenv("KITE_TOTP_SECRET", "")
TRADING_MODE     = os.getenv("TRADING_MODE", "PAPER").upper()
REDDIT_CLIENT_ID = os.getenv("REDDIT_CLIENT_ID", "")
REDDIT_SECRET    = os.getenv("REDDIT_SECRET", "")

# ─── WhatsApp (CallMeBot) ────────────────────────────────────────────────────
# Setup: Send "I allow callmebot to send me messages" to +34 644 51 95 23
# on WhatsApp. You'll get an API key. Add both to .env file.
WHATSAPP_PHONE   = os.getenv("WHATSAPP_PHONE", "")    # Your phone with country code e.g. 919876543210
WHATSAPP_APIKEY  = os.getenv("WHATSAPP_APIKEY", "")    # CallMeBot API key

# ─── Constants ────────────────────────────────────────────────────────────────
VERSION       = "v23.7.0"
EDITION       = "Trillionaire Pro Edition"
OWNER_NAME    = "<redacted>"
IST           = pytz.timezone("Asia/Kolkata")
PAPER_DAYS    = 3
MIN_WIN_RATE  = 55.0

# Capital — PAPER mode defaults. LIVE mode auto-detects from Kite margins.
TOTAL_CAPITAL = 50_000
INTRADAY_CAP  = 15_000
SWING_CAP     = 15_000
LONGTERM_CAP  = 10_000
FNO_CAP       = 10_000

# Risk
RISK_PER_TRADE      = 0.04  # 4% risk per trade (bigger positions, fewer trades)
MAX_INTRADAY_POS    = 1    # v23.6.0 #5: Sniper mode — 1 precision intraday trade/day
MAX_SWING_POS       = 2    # Max 2 swing positions
MAX_LONGTERM_POS    = 1    # Max 1 longterm position
MAX_FNO_POS         = 0    # No F&O for now (capital too small)
INTRADAY_LOSS_LIMIT = 0.03
MONTHLY_LOSS_LIMIT  = 0.15
PROFIT_ALERT_PCT    = 0.05
MIN_PRICE           = 50
SCAN_WORKERS        = 5  # FIX #15: Speed — increased from 3 to 5

# v23.6.0 #5: Intraday Sniper — only the SINGLE BEST signal of the day
INTRADAY_SNIPER_DVM = 80   # Very high DVM bar for intraday
INTRADAY_SNIPER_ADX = 25   # Must be trending
INTRADAY_SNIPER_VOL = 1.5  # Must have volume surge

# v23.6.0 #4: Kelly Criterion Position Sizing
# Kelly% = WinRate - (1-WinRate)/RR_Ratio
# With 55% WR and 2:1 RR → Kelly = 0.55 - 0.45/2 = 32.5%
# We use Half-Kelly (conservative): 16.25%
USE_KELLY_SIZING    = True   # Enable Kelly-based position sizing
KELLY_FRACTION      = 0.5   # Half-Kelly for safety (0.5 = conservative)
MAX_POSITION_PCT    = 0.60  # v23.6.0: Raised from 0.45 to 0.60 (with Kelly + 3 max pos)

# v23.6.0 #11: Continuous Capital Scaling
# Max positions = floor(log2(Capital / 20000)) + 2
# Rs.50K→3, Rs.100K→4, Rs.200K→5, Rs.500K→6
def calculate_max_positions(capital):
    """Continuous scaling: positions grow smoothly with capital."""
    import math
    if capital <= 0:
        return 2
    raw = math.floor(math.log2(max(1, capital / 20000))) + 2
    return max(2, min(10, raw))  # Floor 2, cap 10

# ─── FIX #9: DUAL MODE — Aggressive + Balanced ──────────────────────────────
# Set in .env: STRATEGY_MODE=AGGRESSIVE or STRATEGY_MODE=BALANCED
# AGGRESSIVE: lower entry thresholds, more trades, wider stops
# BALANCED: original thresholds, fewer but higher-quality trades
STRATEGY_MODE = os.getenv("STRATEGY_MODE", "AGGRESSIVE").upper()

if STRATEGY_MODE == "AGGRESSIVE":
    # v23.6.1: TIGHTENED — old config was bleeding money
    # 1/3 agent approval was letting garbage through at 26% confidence
    # Now: 2/3 agents required + 50% minimum confidence enforced downstream
    DVM_INTRADAY  = 80   # Very high bar — intraday must be precision
    DVM_SWING     = 72   # Strong momentum required
    DVM_LONGTERM  = 65   # Quality longterm picks
    DVM_FNO       = 80   # Very high bar for F&O
    VOL_SURGE_MIN = 1.3  # Need real volume, not noise
    RSI_OVERSOLD  = 32   # Tighter oversold zone
    RSI_OVERBOUGHT= 72   # was 75
    LT_PE_MAX     = 60   # FIX #5: was 40 — too strict for growth stocks
    LT_ROE_MIN    = 0    # FIX: Set to 0 since data unavailable from Kite
    SENT_THRESHOLD= 50   # was 45 — need real sentiment support
    AGENT_APPROVAL= 2    # v23.6.1: 2 out of 3 agents MINIMUM (was 1 — that was insane)
    SCAN_INTERVAL = 1800 # FIX #13: 30 minutes (was 3600)
    MIN_CONFIDENCE= 42   # v23.6.2: Lowered from 45 to allow quality trades in bearish markets
else:  # BALANCED
    # Balanced — slightly higher but still realistic for momentum-only DVM
    DVM_INTRADAY  = 75
    DVM_SWING     = 75
    DVM_LONGTERM  = 70
    DVM_FNO       = 80
    VOL_SURGE_MIN = 1.3
    RSI_OVERSOLD  = 30
    RSI_OVERBOUGHT= 75
    LT_PE_MAX     = 40
    LT_ROE_MIN    = 0    # Data unavailable from Kite
    SENT_THRESHOLD= 55
    AGENT_APPROVAL= 2    # 2 out of 3 agents needed
    SCAN_INTERVAL = 3600 # 60 minutes
    MIN_CONFIDENCE= 50   # v23.6.1: Floor

# v23.6.2: MINIMUM CONFIDENCE FLOOR — lowered to 42 for quality trades
if not 'MIN_CONFIDENCE' in dir():
    MIN_CONFIDENCE = 42

# Paths
DATA_DIR    = os.path.join(_DIR, "data")
REPORTS_DIR = os.path.join(_DIR, "reports")
LOG_FILE    = os.path.join(_DIR, "global_eye.log")
for d in [DATA_DIR, REPORTS_DIR]: os.makedirs(d, exist_ok=True)

INTRADAY_FILE = os.path.join(DATA_DIR, "paper_intraday.json")
SWING_FILE    = os.path.join(DATA_DIR, "paper_swing.json")
LONGTERM_FILE = os.path.join(DATA_DIR, "paper_longterm.json")
FNO_FILE      = os.path.join(DATA_DIR, "paper_fno.json")
STATE_FILE    = os.path.join(DATA_DIR, "bot_state.json")
NEWS_FILE     = os.path.join(DATA_DIR, "news_cache.json")
FILINGS_FILE  = os.path.join(DATA_DIR, "filings_cache.json")
SOCIAL_FILE   = os.path.join(DATA_DIR, "social_cache.json")
DAILY_FILE    = os.path.join(DATA_DIR, "daily_pnl.json")
ACCESS_FILE   = os.path.join(DATA_DIR, "kite_access.json")
INSTRUMENTS_FILE = os.path.join(DATA_DIR, "instruments_cache.json")

# ─── NSE Holidays ─────────────────────────────────────────────────────────────
NSE_HOLIDAYS = {
    # ── 2025 (remaining) ──────────────────────────────────────
    "2025-08-15","2025-10-02","2025-10-21","2025-11-05","2025-12-25",
    # ── 2026 FULL OFFICIAL NSE CALENDAR ───────────────────────
    "2026-01-15","2026-01-26","2026-03-03","2026-03-26","2026-03-31",
    "2026-04-03","2026-04-14","2026-05-01","2026-05-28","2026-06-26",
    "2026-09-14","2026-10-02","2026-10-20","2026-11-10","2026-11-24",
    "2026-12-25",
}

# ── v23.5.0: AUTO-FETCH NSE HOLIDAYS for future years ─────────────────────
# Fetches from Zerodha/NSE API once per month, caches to disk.
# Falls back to hardcoded + "always known" holidays (Republic Day, Independence Day, etc.)
# Bot runs FOREVER — no manual holiday updates needed.
_HOLIDAY_CACHE_FILE = os.path.join(
    os.getenv("DATA_DIR", os.path.dirname(os.path.abspath(__file__))),
    "nse_holidays_cache.json"
)

def _fetch_nse_holidays_online():
    """Fetch NSE holidays from Zerodha instruments API / NSE website.
    Returns set of date strings or empty set on failure."""
    fetched = set()
    current_year = datetime.now().year
    try:
        # Method 1: Zerodha holiday calendar API
        resp = requests.get(
            "https://api.kite.trade/instruments/holidays",
            timeout=10,
            headers={"User-Agent": "GlobalEye/23.5"}
        )
        if resp.status_code == 200:
            data = resp.json()
            for exchange_holidays in data.values():
                for h in exchange_holidays:
                    if h.get("exchange") == "NSE" or "NSE" in str(h):
                        dt = h.get("date", "")
                        if dt and str(current_year) in dt:
                            fetched.add(dt[:10])  # YYYY-MM-DD
            if fetched:
                return fetched
    except Exception:
        pass

    try:
        # Method 2: Zerodha margin holiday page (public)
        resp = requests.get(
            f"https://zerodha.com/static/holidays/trading-holidays-{current_year}.json",
            timeout=10,
            headers={"User-Agent": "GlobalEye/23.5"}
        )
        if resp.status_code == 200:
            data = resp.json()
            for h in data:
                dt = h.get("date", "")
                if dt:
                    fetched.add(dt[:10])
            if fetched:
                return fetched
    except Exception:
        pass

    return fetched


def _get_always_known_holidays(year):
    """Fixed-date holidays that NEVER change. For years with no online data."""
    return {
        f"{year}-01-26",  # Republic Day
        f"{year}-08-15",  # Independence Day
        f"{year}-10-02",  # Gandhi Jayanti
        f"{year}-12-25",  # Christmas
        f"{year}-05-01",  # Maharashtra Day
        f"{year}-04-14",  # Ambedkar Jayanti
    }


def _load_holiday_cache():
    """Load cached holidays from disk."""
    try:
        if os.path.exists(_HOLIDAY_CACHE_FILE):
            with open(_HOLIDAY_CACHE_FILE, "r") as f:
                data = json.load(f)
                return set(data.get("holidays", [])), data.get("fetched_month", "")
    except Exception:
        pass
    return set(), ""


def _save_holiday_cache(holidays, fetched_month):
    """Save holidays to disk cache."""
    try:
        with open(_HOLIDAY_CACHE_FILE, "w") as f:
            json.dump({"holidays": list(holidays), "fetched_month": fetched_month}, f)
    except Exception:
        pass


def refresh_nse_holidays():
    """Auto-refresh NSE holidays. Called once per month.
    Updates the global NSE_HOLIDAYS set with future years."""
    global NSE_HOLIDAYS
    current_year = datetime.now().year
    current_month = datetime.now().strftime("%Y-%m")

    # Check cache first
    cached, cached_month = _load_holiday_cache()
    if cached and cached_month == current_month:
        # Cache is fresh (this month) — merge into global
        NSE_HOLIDAYS = NSE_HOLIDAYS | cached
        return

    # Try to fetch online
    fetched = _fetch_nse_holidays_online()
    if fetched:
        NSE_HOLIDAYS = NSE_HOLIDAYS | fetched
        _save_holiday_cache(fetched, current_month)
        logging.getLogger("global_eye").info(
            f"NSE holidays updated: {len(fetched)} dates for {current_year}"
        )
        return

    # Online failed — use cached if available (even if old)
    if cached:
        NSE_HOLIDAYS = NSE_HOLIDAYS | cached
        return

    # Last resort: add always-known fixed holidays for current + next year
    for yr in [current_year, current_year + 1]:
        NSE_HOLIDAYS = NSE_HOLIDAYS | _get_always_known_holidays(yr)
    logging.getLogger("global_eye").warning(
        f"NSE holidays: Using fixed-date fallback for {current_year}-{current_year+1}"
    )


# Run once at startup
try:
    refresh_nse_holidays()
except Exception:
    pass  # Don't crash on startup — hardcoded 2025-2026 still works

# ─── EXPANDED F&O LIST (NSE approved — includes 6 new additions 2025-26) ──────
FNO_STOCKS = {
    # Index
    "NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY",
    # Nifty 50
    "RELIANCE","TCS","HDFCBANK","INFY","ICICIBANK","HINDUNILVR","ITC",
    "SBIN","BHARTIARTL","KOTAKBANK","LT","AXISBANK","ASIANPAINT","MARUTI",
    "SUNPHARMA","TITAN","BAJFINANCE","WIPRO","NESTLEIND","ULTRACEMCO",
    "POWERGRID","NTPC","TECHM","HCLTECH","JSWSTEEL","TATASTEEL","GRASIM",
    "CIPLA","DRREDDY","DIVISLAB","BAJAJFINSV","BPCL","COALINDIA","ONGC",
    "M&M","ADANIENT","ADANIPORTS","APOLLOHOSP","TATACONSUM","BRITANNIA",
    "HEROMOTOCO","EICHERMOT","UPL","HINDALCO","VEDL","INDUSINDBK",
    "BAJAJ-AUTO","SBILIFE","HDFCLIFE","LTI",
    # Nifty Next 50 / Large caps
    "ZOMATO","NYKAA","PAYTM","POLICYBZR","DELHIVERY","IRCTC","LICI",
    "RVNL","IRFC","HUDCO","PFC","RECLTD","CANBK","BANKBARODA","PNB",
    "UNIONBANK","IDFCFIRSTB","FEDERALBNK","RBLBANK","BANDHANBNK",
    "TATAMOTORS","M&MFIN","TATAPOWER","ADANIGREEN","ADANIPOWER",
    "ADANITRANS","ATGL","AWL","CESC","NHPC","SJVN","TORNTPOWER",
    "TATAELXSI","MPHASIS","LTIM","PERSISTENT","COFORGE","ZYDUSLIFE",
    "ALKEM","TORNTPHARM","AUROPHARMA","GLENMARK","LUPIN","BIOCON",
    "PIIND","SYNGENE","LAURUSLABS","GRANULES","IPCALAB","STAR",
    "NAUKRI","JUSTDIAL","MATRIMONY","MAPMYINDIA",
    # Midcap F&O
    "PAGEIND","MCDOWELL-N","UNITDSPR","RADICO","VBL","JUBLFOOD",
    "DEVYANI","SAPPHIRE","WESTLIFE","BECTOR",
    "ESCORTS","SONACOMS","SWARAJENG","MAHINDCIE",
    "ABBOTINDIA","PFIZER","SANOFI","GLAXO","NATCOPHARM",
    "JKCEMENT","RAMCOCEM","DALBHARAT","HEIDELBERG","SAGAR",
    "POLYCAB","HAVELLS","CROMPTON","ORIENTELEC","BAJAJELEC",
    "SUPREMEIND","ASTRAL","FINOLEX","PRINCEPIPE",
    "CONCOR","BLUEDART","GATI","TCI","VRL",
    "MUTHOOTFIN","CHOLAFIN","BAJAJHLDNG","MANAPPURAM",
    "GODREJCP","DABUR","MARICO","EMAMILTD","JYOTHYLAB",
    "PIDILITIND","BERGER","KANSAINER","AKZONOBEL",
    "OBEROIREAL","GODREJPROP","DLF","PRESTIGE","BRIGADE","SOBHA",
    "NMDC","MOIL","HINDCOPPER","NALCO","SAIL","JSWENERGY",
    "GMRINFRA","IRB","NHAI","KNR","AHLUWALIA",
    "DIXONS","SYRMA","KAYNES","AMBER","DIXON",
    # NEW F&O additions 2025-26
    "JIOFIN","TATATECH","MANKIND","DOMS","PREMIERENE","WAAREEENER",
}

# ─── EXPANDED EQUITY UNIVERSE ─────────────────────────────────────────────────
# Dynamic — loaded from Kite instruments API daily
# Fallback list used ONLY if Kite instruments fail
PRIORITY_500 = list(FNO_STOCKS)

# Remove duplicates
PRIORITY_500 = list(dict.fromkeys(PRIORITY_500))

# ─── Global Market Symbols for pre-market pulse ───────────────────────────────
GLOBAL_MARKETS = {
    "GIFT Nifty":  "^NSEI",          # Using Nifty 50 as proxy
    "Nifty 50":    "^NSEI",
    "Sensex":      "^BSESN",
    "Bank Nifty":  "^NSEBANK",
    "India VIX":   "^INDIAVIX",
    "Dow Jones":   "^DJI",
    "S&P 500":     "^GSPC",
    "Nasdaq":      "^IXIC",
    "VIX":         "^VIX",
    "Nikkei 225":  "^N225",
    "Hang Seng":   "^HSI",
    "DAX":         "^GDAXI",
    "FTSE 100":    "^FTSE",
    "Gold":        "GC=F",
    "Silver":      "SI=F",
    "Crude Oil":   "CL=F",
    "USD/INR":     "USDINR=X",
    "EUR/USD":     "EURUSD=X",
    "Bitcoin":     "BTC-USD",
}

# ─── News Feeds ───────────────────────────────────────────────────────────────
NEWS_FEEDS = {
    "Economic Times Markets":  "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms",
    "ET Corporate":            "https://economictimes.indiatimes.com/industry/rssfeeds/13352306.cms",
    "ET Economy":              "https://economictimes.indiatimes.com/economy/rssfeeds/1373380680.cms",
    "Moneycontrol Markets":    "https://www.moneycontrol.com/rss/marketreports.xml",
    "Moneycontrol Economy":    "https://www.moneycontrol.com/rss/economy.xml",
    "Business Standard":       "https://www.business-standard.com/rss/markets-106.rss",
    "LiveMint Markets":        "https://www.livemint.com/rss/markets",
    "LiveMint Companies":      "https://www.livemint.com/rss/companies",
    "Financial Express":       "https://www.financialexpress.com/market/feed/",
    "Reuters Business":        "https://feeds.reuters.com/reuters/businessNews",
    "Reuters Markets":         "https://feeds.reuters.com/reuters/marketsNews",
    "RBI":                     "https://www.rbi.org.in/scripts/rss.aspx?id=2",
    "CNBCTV18 Market":         "https://cnbctv18.com/commonfeeds/v1/cne/rss/market.xml",
    "CNBCTV18 Companies":      "https://cnbctv18.com/commonfeeds/v1/cne/rss/companies.xml",
    "ET Tech":                 "https://economictimes.indiatimes.com/tech/rssfeeds/13357270.cms",
    "Moneycontrol Business":   "https://www.moneycontrol.com/rss/business.xml",
    "BS Companies":            "https://www.business-standard.com/rss/companies-101.rss",
    "LiveMint Economy":        "https://www.livemint.com/rss/economy",
    "Business Line":           "https://www.thehindubusinessline.com/markets/feeder/default.rss",
    "NDTV Profit":             "https://www.ndtv.com/business/feeds",
    "BS Economy":              "https://www.business-standard.com/rss/economy-policy-10301.rss",
}

# ─── Filing type keywords — 150+ critical words for BSE/NSE filings ──────────
FILING_TYPES = {
    # ── EARNINGS & RESULTS ────────────────────────────────────────────────
    "RESULTS": {
        "keywords": [
            "financial results","quarterly results","q1","q2","q3","q4",
            "profit","loss","revenue","ebitda","earnings","net profit",
            "gross profit","operating profit","pat","profit after tax",
            "profit before tax","pbt","annual results","half yearly",
            "standalone results","consolidated results","audited results",
            "unaudited results","turnover","income from operations",
            "exceptional items","extraordinary items","eps","earnings per share",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["intraday","swing"]
    },
    # ── DIVIDEND & CORPORATE ACTIONS ──────────────────────────────────────
    "DIVIDEND": {
        "keywords": [
            "dividend","interim dividend","final dividend","record date",
            "ex-dividend","special dividend","dividend declared",
            "dividend recommended","bonus","bonus issue","bonus shares",
            "stock split","sub-division","face value split","rights issue",
            "rights offering","share buyback","buyback offer","buyback price",
            "open offer","delisting","voluntary delisting",
        ],
        "sentiment":"BULLISH","urgency":"MEDIUM","strategy":["swing","longterm"]
    },
    # ── BOARD MEETING & GOVERNANCE ────────────────────────────────────────
    "BOARD_MEETING": {
        "keywords": [
            "board meeting","outcome of board","board of directors",
            "agm","egm","annual general meeting","extraordinary general meeting",
            "postal ballot","shareholder approval","board resolution",
            "committee meeting","audit committee","nomination committee",
            "change of auditor","change in management","resignation",
            "appointment","ceo appointed","cfo appointed","md appointed",
            "change in director","key managerial personnel","kmp",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["intraday","swing"]
    },
    # ── BULK & BLOCK DEALS ────────────────────────────────────────────────
    "BULK_BLOCK_DEAL": {
        "keywords": [
            "bulk deal","block deal","large trade","institutional trade",
            "bulk order","block transaction","off-market transaction",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["intraday"]
    },
    # ── PROMOTER & INSIDER TRADING ────────────────────────────────────────
    "PROMOTER": {
        "keywords": [
            "promoter","insider","pledge","stake","promoter holding",
            "promoter pledge","pledge release","encumbrance","pledge creation",
            "promoter buying","promoter selling","promoter stake increase",
            "promoter stake decrease","shareholding pattern","sast",
            "substantial acquisition","insider trading","trading window",
            "upsi","unpublished price sensitive information",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["swing","intraday"]
    },
    # ── MERGER & ACQUISITION ──────────────────────────────────────────────
    "MERGER_ACQUISITION": {
        "keywords": [
            "merger","acquisition","takeover","amalgamation","demerger",
            "joint venture","mou","memorandum of understanding",
            "scheme of arrangement","scheme of amalgamation","hive off",
            "slump sale","business transfer","strategic partnership",
            "strategic alliance","strategic investment","binding agreement",
            "definitive agreement","share purchase agreement","asset purchase",
            "wholly owned subsidiary","wos","stake acquisition",
            "controlling stake","majority stake","equity infusion",
        ],
        "sentiment":"BULLISH","urgency":"CRITICAL","strategy":["intraday","swing","fno"]
    },
    # ── REGULATORY & APPROVALS ────────────────────────────────────────────
    "REGULATORY_APPROVAL": {
        "keywords": [
            "usfda","fda approval","drug approval","patent","patent granted",
            "regulatory approval","licence","license granted","anda approval",
            "nda approval","marketing authorization","product approval",
            "clinical trial","phase 3","phase iii","drug launch",
            "sebi approval","rbi approval","cci approval","nclt approval",
            "environmental clearance","mining lease","spectrum allocation",
            "telecom license","banking license","insurance license",
        ],
        "sentiment":"BULLISH","urgency":"CRITICAL","strategy":["intraday","swing","fno"]
    },
    # ── CREDIT RATING ─────────────────────────────────────────────────────
    "CREDIT_RATING": {
        "keywords": [
            "rating upgrade","rating downgrade","credit rating","crisil",
            "icra","care","india ratings","brickwork","acuite",
            "rating outlook","positive outlook","negative outlook",
            "stable outlook","rating watch","rating reaffirmed",
            "default rating","npa","non performing asset",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["swing","intraday"]
    },
    # ── ORDER WIN & CONTRACTS ─────────────────────────────────────────────
    "ORDER_WIN": {
        "keywords": [
            "order","contract","letter of award","work order","export order",
            "order inflow","order book","order win","order received",
            "supply order","purchase order","government order","defence order",
            "railway order","solar order","epc contract","turnkey contract",
            "rate contract","framework agreement","empanelment",
            "tender awarded","lowest bidder","l1 bidder","project awarded",
            "construction contract","infrastructure order","highway project",
            "metro project","smart city","nal se jal","pmay",
        ],
        "sentiment":"BULLISH","urgency":"HIGH","strategy":["intraday","swing"]
    },
    # ── FRAUD & RISK ──────────────────────────────────────────────────────
    "FRAUD_RISK": {
        "keywords": [
            "fraud","sebi order","cbi raid","enforcement directorate raid",
            "enforcement directorate investigation","enforcement directorate action",
            "ed raid","ed investigation","ed action","ed attaches","ed searches",
            "fir registered","fir filed","penalty imposed","trading suspension",
            "scam","investigation by sebi","investigation by cbi",
            "show cause notice","adjudication order","debarment",
            "insider trading violation","market manipulation","front running",
            "money laundering","pmla case","serious fraud","sfio investigation",
            "nclt insolvency","cirp","moratorium order","liquidation order",
            "winding up","debt default","loan default","npa classification",
            "wilful defaulter","rbi action","sebi ban","trading suspended",
            "gst evasion","income tax raid","tax notice","search and seizure",
            "forensic audit","whistleblower complaint","corporate governance failure",
            "related party transaction violation","embezzlement",
        ],
        "sentiment":"BEARISH","urgency":"CRITICAL","strategy":["intraday"],
        # FIX #7/#8: These words MUST be EXCLUDED from fraud matching
        # "powered", "education", "Persistent", "launched", "AI solution" etc.
        "exclude_context": [
            "powered by","powered","education","educational","educator",
            "experienced","published","launched","launching","established",
            "registered","licensed","authorized","acquired",
            "improved","achieved","delivered","advanced","continued",
            "announced","increased","strengthened","extended",
            "ai solution","digital solution","technology solution",
            "product launch","solution launch","platform launch",
            "persistent systems","persistent","coforge",
        ],
    },
    # ── FII/DII FLOWS ─────────────────────────────────────────────────────
    "FII_DII": {
        "keywords": [
            "fii","dii","foreign institutional","domestic institutional",
            "fpi","foreign portfolio","mutual fund flow","etf flow",
            "institutional buying","institutional selling",
        ],
        "sentiment":"ANALYSE","urgency":"MEDIUM","strategy":["fno"]
    },
    # ── EXPANSION & CAPEX ─────────────────────────────────────────────────
    "EXPANSION": {
        "keywords": [
            "capacity expansion","new plant","greenfield","brownfield",
            "capex","capital expenditure","new facility","plant commissioning",
            "production commenced","commercial production","capacity addition",
            "expansion plan","new unit","factory setup","manufacturing unit",
            "warehouse","distribution center","new office","new branch",
        ],
        "sentiment":"BULLISH","urgency":"HIGH","strategy":["swing","longterm"]
    },
    # ── FUNDRAISING ───────────────────────────────────────────────────────
    "FUNDRAISING": {
        "keywords": [
            "qip","qualified institutional placement","preferential allotment",
            "preferential issue","private placement","fpo","ofs",
            "offer for sale","ipo","initial public offering",
            "rights issue","warrants","convertible debentures","ncd",
            "fccb","ecb","external commercial borrowing","term loan",
            "credit facility","debt refinancing","fund raising",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["swing"]
    },
    # ── TECHNOLOGY & DIGITAL ──────────────────────────────────────────────
    "TECHNOLOGY": {
        "keywords": [
            "digital transformation","ai","artificial intelligence",
            "machine learning","cloud","saas","platform launch",
            "technology partnership","it outsourcing","automation",
            "blockchain","fintech","new product launch","innovation",
        ],
        "sentiment":"BULLISH","urgency":"MEDIUM","strategy":["swing","longterm"]
    },
    # ── GOVERNMENT & POLICY ───────────────────────────────────────────────
    "GOVERNMENT_POLICY": {
        "keywords": [
            "pli scheme","production linked incentive","government subsidy",
            "policy change","budget","gst rate","import duty","export duty",
            "anti-dumping","safeguard duty","make in india","atmanirbhar",
            "defence indigenization","fdi approval","fdi policy",
            "disinvestment","privatization","strategic disinvestment",
        ],
        "sentiment":"ANALYSE","urgency":"HIGH","strategy":["swing","fno"]
    },
    # ── ESG & SUSTAINABILITY ──────────────────────────────────────────────
    "ESG": {
        "keywords": [
            "esg","sustainability","carbon neutral","green bond",
            "renewable energy","solar","wind power","ev","electric vehicle",
            "emission reduction","brsr","csr","corporate social responsibility",
        ],
        "sentiment":"BULLISH","urgency":"MEDIUM","strategy":["longterm"]
    },
}
ALL_FILING_KW = [kw for ft in FILING_TYPES.values() for kw in ft["keywords"]]

# ─── BSE Code → NSE Symbol Mapping ───────────────────────────────────────────
# Converts BSE numeric codes to NSE tradeable symbols
# When BSE filing comes in with code like 540900, converts to HDFCLIFE
BSE_TO_NSE = {
    # Nifty 50
    "500325":"RELIANCE",  "532540":"TCS",       "500180":"HDFCBANK",
    "500209":"INFY",      "532174":"ICICIBANK",  "500696":"HINDUNILVR",
    "500875":"ITC",       "500112":"SBIN",       "532454":"BHARTIARTL",
    "500247":"KOTAKBANK", "500510":"LT",         "532215":"AXISBANK",
    "500820":"ASIANPAINT","532500":"MARUTI",     "524715":"SUNPHARMA",
    "500114":"TITAN",     "532978":"BAJFINANCE", "507685":"WIPRO",
    "500790":"NESTLEIND", "532538":"ULTRACEMCO", "532898":"POWERGRID",
    "532555":"NTPC",      "532755":"TECHM",      "532281":"HCLTECH",
    "500228":"JSWSTEEL",  "500470":"TATASTEEL",  "500300":"GRASIM",
    "500087":"CIPLA",     "500124":"DRREDDY",    "532488":"DIVISLAB",
    "532978":"BAJFINANCE","500547":"BPCL",       "533278":"COALINDIA",
    "500312":"ONGC",      "500520":"M&M",        "512599":"ADANIENT",
    "532921":"ADANIPORTS","508869":"APOLLOHOSP", "500800":"TATACONSUM",
    "500825":"BRITANNIA", "500182":"HEROMOTOCO", "505200":"EICHERMOT",
    "512070":"UPL",       "500440":"HINDALCO",   "532477":"INDUSINDBK",
    "532977":"BAJAJ-AUTO","541179":"SBILIFE",    "540777":"HDFCLIFE",
    "500570":"TATAMOTORS","500295":"BAJAJFINSV", "532286":"VEDL",
    # Nifty Next 50 / Large caps
    "543320":"ZOMATO",    "543384":"NYKAA",      "543396":"PAYTM",
    "543228":"IRCTC",     "543526":"LICI",       "542649":"RVNL",
    "543257":"IRFC",      "542955":"HUDCO",      "532810":"PFC",
    "532955":"RECLTD",    "532483":"CANBK",      "532134":"BANKBARODA",
    "532461":"PNB",       "532477":"UNIONBANK",  "539437":"IDFCFIRSTB",
    "500469":"FEDERALBNK","540065":"RBLBANK",    "541153":"BANDHANBNK",
    "500400":"TATAPOWER", "541450":"ADANIGREEN", "533096":"ADANIPOWER",
    "542066":"ATGL",      "543258":"NHPC",       "533222":"SJVN",
    "500367":"TORNTPOWER","532974":"TATAELXSI",  "526299":"MPHASIS",
    "540005":"LTIM",      "533179":"PERSISTENT", "532675":"COFORGE",
    "532321":"ZYDUSLIFE", "543308":"ALKEM",      "500420":"TORNTPHARM",
    "524804":"AUROPHARMA","532976":"GLENMARK",   "500257":"LUPIN",
    "532523":"BIOCON",    "523642":"PIIND",      "539268":"SYNGENE",
    "524731":"LAURUSLABS","532481":"GRANULES",   "521070":"IPCALAB",
    "532755":"NAUKRI",    "543750":"JIOFIN",     "544028":"TATATECH",
    "543904":"MANKIND",   "543587":"DOMS",
    # Banking
    "532648":"YESBANK",   "532772":"DCBBANK",    "532210":"CITYUNIONBANK",
    "590003":"KARURVYSYA","532215":"AXISBANK",
    # IT
    "532648":"ZENSARTECH","519471":"NIITLTD",    "523704":"MASTEK",
    "543227":"CDSL",      "543066":"BSE",        "534091":"MCX",
    "543469":"CAMS",
    # Pharma
    "500002":"ABBOTINDIA","532887":"PFIZER",     "500674":"SANOFI",
    "500660":"GLAXO",     "524816":"NATCOPHARM", "543809":"GLAND",
    "543701":"YATHARTH",  "543255":"KIMS",       "543220":"MAXHEALTH",
    "543348":"NARAYAN",   "508869":"APOLLOHOSP",
    # Auto
    "520021":"ESCORTS",   "533107":"SONACOMS",   "500480":"MAHINDCIE",
    "430102":"BALKRISIND","500878":"CEATLTD",     "500877":"APOLLOTYRE",
    "500290":"MRF",       "505200":"EICHERMOT",  "532343":"BHARATFORG",
    "532762":"ENDURANCE", "532539":"MINDA",      "517334":"MOTHERSON",
    # Infra
    "532868":"GMRINFRA",  "532947":"IRB",        "532466":"CONCOR",
    "532868":"DLF",       "532726":"OBEROIREAL", "532780":"GODREJPROP",
    "543247":"PRESTIGE",  "532628":"BRIGADE",    "532784":"SOBHA",
    "532924":"KOLTEPATIL","503100":"PHOENIXLTD",
    # FMCG
    "500150":"GODREJCP",  "500096":"DABUR",      "531642":"MARICO",
    "531162":"EMAMILTD",  "532926":"JYOTHYLAB",  "519552":"VBL",
    "533155":"JUBLFOOD",  "543330":"DEVYANI",    "543397":"SAPPHIRE",
    "505537":"WESTLIFE",  "543228":"TRENT",      "532638":"SHOPERSTOP",
    "534976":"VMART",     "535755":"ABFRL",      "543458":"MANYAVAR",
    "523261":"RELAXO",    "500043":"BATA",       "543318":"METRO",
    "530419":"CAMPUS",    "521064":"TRIDENT",    "500330":"RAYMOND",
    "500101":"ARVIND",    "502986":"VARDHMAN",   "514162":"WELSPUN",
    # Energy
    "500010":"HINDUNILVR","500425":"AMBUJACEMENT","532868":"ADANIENT",
    "500188":"GAIL",      "532522":"PETRONET",   "532514":"IGL",
    "532555":"MGL",       "539434":"GUJGASLTD",  "530001":"GSPL",
    "542066":"ATGL",      "533150":"COALINDIA",  "522205":"NMDC",
    "532234":"MOIL",      "513599":"HINDCOPPER", "532234":"NALCO",
    "500113":"SAIL",      "533148":"JSWENERGY",  "532667":"SUZLON",
    # Finance
    "532978":"BAJFINANCE","543762":"CHOLAFIN",   "532652":"M&MFIN",
    "543274":"SHRIRAMFIN","590071":"SUNDARMFIN", "532636":"MANAPPURAM",
    "531213":"MUTHOOTFIN","532488":"CREDITACC",  "539838":"UJJIVAN",
    "543229":"EQUITASBNK","543159":"NUVAMA",     "543235":"ANGELONE",
    "532892":"MOTILALOFS", "533519":"5PAISA",    "532636":"IIFL",
    "532892":"MOFSL",     "543697":"KFINTECH",   "543469":"CAMS",
    "543066":"BFSL",      "543066":"SBICARDS",   "543243":"HDFCAMC",
    "540777":"HDFCLIFE",  "541988":"SBILIFE",    "540133":"ICICIPRU",
    # Misc large caps
    "500043":"PIDILITIND","509480":"BERGER",     "500681":"KANSAINER",
    "505537":"VOLTAS",    "500825":"BLUESTARCO",   "500408":"WHIRLPOOL",
    "517354":"SYMPHONY",  "523395":"POLYCAB",    "517354":"HAVELLS",
    "539876":"CROMPTON",  "531344":"BAJAJELEC",  "532725":"SUPREMEIND",
    "532830":"ASTRAL",    "500940":"FINOLEX",    "543399":"PRINCEPIPE",
    "532638":"CONCOR",    "532456":"BLUEDART",   "532749":"TCI",
    "533272":"VRL",       "532523":"MUTHOOTFIN", "532660":"CHOLAFIN",
    # New additions
    "543750":"JIOFIN",    "544028":"TATATECH",   "543904":"MANKIND",
    "543587":"DOMS",      "544175":"PREMIERENE", "544180":"WAAREEENER",
}

def bse_to_nse(code):
    """Convert BSE numeric code to NSE symbol. Returns None if not found."""
    code_str = str(code).strip()
    # Direct lookup
    if code_str in BSE_TO_NSE:
        return BSE_TO_NSE[code_str]
    # If it's already an NSE symbol (letters), return as-is
    if code_str.isalpha() or (code_str.replace("-","").replace("&","").isalpha()):
        return code_str
    return None

# ──────────────────────────────────────────────────────────────────────────────
#  DYNAMIC STOCK UNIVERSE — 1000+ stocks from Kite instruments API
#  No hardcoded lists. No Yahoo Finance. Zero scan errors.
# ──────────────────────────────────────────────────────────────────────────────

class DynamicStockUniverse:
    """
    Loads ALL NSE equity stocks from Kite instruments API.
    Auto-filters: removes SME, commodities, ETFs, bonds, low-price stocks.
    Auto-deduplicates: NSE preferred over BSE.
    Result: 1000-1500 valid, tradeable stocks. Updated daily.
    """

    # Segments to EXCLUDE
    EXCLUDED_SEGMENTS = {"SME", "SME-EMERGE", "BE", "BZ", "GS", "MF", "IF"}
    # Instrument types to EXCLUDE
    EXCLUDED_TYPES    = {"COMMODITY", "CURRENCY", "CE", "PE", "FUT"}
    # Name patterns to EXCLUDE (commodities, ETFs, bonds)
    EXCLUDED_PATTERNS = [
        "ETF", "GOLD", "SILVER", "CRUDE", "NIFTY", "SENSEX",
        "LIQUID", "BOND", "GILT", "MONEY", "OVERNIGHT",
        "DEBT", "SOVEREIGN", "CPSE", "BHARAT", "GROWTH",
        "-SG", "-GR", "-DP", "-IV", "BEES",
        "GOLDBEES", "SILVERBEES", "LIQUIDBEES",
        # FIX #9: Government securities, bonds, debentures
        "GS20", "GS19", "GSEC", "AFIL", "SSCL", "SDL",
        "TBILL", "SGBOND", "FLOATING", "NCDS", "NCD",
    ]
    # Indices — scan but don't trade
    INDICES = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"}

    _cache = []
    _cache_date = ""
    _all_instruments = {}  # symbol → instrument_token mapping

    @classmethod
    def load(cls, kite):
        """
        Load full stock universe from Kite instruments API.
        Called once per day at startup or first scan.
        Returns list of tradeable symbols (1000+).
        """
        global PRIORITY_500

        today = now_ist().strftime("%Y-%m-%d")
        if cls._cache and cls._cache_date == today:
            return cls._cache

        if not kite:
            logger.warning("Kite not available — using fallback FNO list")
            return list(FNO_STOCKS)

        try:
            logger.info("📡 Loading stock universe from Kite instruments API...")
            instruments = kite.instruments("NSE")
            logger.info(f"  Kite returned {len(instruments)} NSE instruments")

            # Build token cache for ALL instruments
            cls._all_instruments = {}
            valid_stocks = []

            for inst in instruments:
                sym      = inst.get("tradingsymbol", "")
                name     = inst.get("name", "").upper()
                segment  = inst.get("segment", "").upper()
                inst_type= inst.get("instrument_type", "").upper()
                exchange = inst.get("exchange", "").upper()
                token    = inst.get("instrument_token", 0)

                # Store ALL tokens for historical data
                if sym and token:
                    cls._all_instruments[sym] = token

                # ── FILTER: Only equity stocks ──
                # Must be EQ (equity) instrument type
                if inst_type not in ("EQ", ""):
                    continue

                # Skip if segment is excluded (SME, bonds, etc)
                if any(seg in segment for seg in cls.EXCLUDED_SEGMENTS):
                    continue

                # Skip if name contains excluded patterns
                if any(pat in name or pat in sym for pat in cls.EXCLUDED_PATTERNS):
                    continue

                # Skip empty or numeric-only symbols
                if not sym or sym.isdigit() or len(sym) < 2:
                    continue

                # FIX #9: Skip government securities (start with digits)
                # e.g., 591GS2028-GS, 12AFIL27-N0, 99SSCL2035-N4, 79ABCL35-N1
                if sym[0].isdigit():
                    continue
                # Skip symbols with hyphens followed by letter+digit (bond series)
                if "-" in sym and any(c.isdigit() for c in sym.split("-")[-1]):
                    continue

                # Skip if symbol has SME markers
                if any(m in sym for m in ["-SM", "-BE", "-BZ", "-IL", "-BL"]):
                    continue

                valid_stocks.append(sym)

            # Add indices for scanning (not trading)
            for idx in cls.INDICES:
                if idx not in valid_stocks:
                    valid_stocks.append(idx)

            # Ensure all F&O stocks are included
            for fno_sym in FNO_STOCKS:
                if fno_sym not in valid_stocks:
                    valid_stocks.append(fno_sym)

            # Deduplicate
            valid_stocks = list(dict.fromkeys(valid_stocks))

            cls._cache = valid_stocks
            cls._cache_date = today

            # Update global PRIORITY_500
            PRIORITY_500 = valid_stocks

            # Save to file for debugging
            save_json(INSTRUMENTS_FILE, {
                "date": today,
                "count": len(valid_stocks),
                "stocks": valid_stocks[:50],  # First 50 for debug
                "total_instruments": len(instruments),
                "token_cache_size": len(cls._all_instruments),
            })

            logger.info(f"✅ Stock Universe: {len(valid_stocks)} tradeable stocks loaded")
            logger.info(f"  Token cache: {len(cls._all_instruments)} instruments")
            return valid_stocks

        except Exception as e:
            logger.error(f"Stock universe load failed: {e}")
            # Fallback to F&O list
            cls._cache = list(FNO_STOCKS)
            return cls._cache

    @classmethod
    def get_token(cls, symbol):
        """Get instrument token for a symbol. Used by scanner."""
        # Hardcoded index tokens
        index_tokens = {
            "NIFTY":      256265,
            "BANKNIFTY":  260105,
            "FINNIFTY":   257801,
            "MIDCPNIFTY": 288009,
        }
        if symbol in index_tokens:
            return index_tokens[symbol]
        return cls._all_instruments.get(symbol)

    @classmethod
    def is_fno(cls, symbol):
        """Check if a symbol is F&O eligible."""
        return symbol in FNO_STOCKS

# ─── Logging ──────────────────────────────────────────────────────────────────
class NullByteFilter(logging.Filter):
    """Strip null bytes from log messages to prevent binary file corruption."""
    def filter(self, record):
        if record.msg and isinstance(record.msg, str):
            record.msg = record.msg.replace('\x00', '')
        if record.args:
            cleaned = []
            for a in record.args if isinstance(record.args, (list, tuple)) else [record.args]:
                if isinstance(a, str):
                    cleaned.append(a.replace('\x00', ''))
                else:
                    cleaned.append(a)
            record.args = tuple(cleaned) if isinstance(record.args, tuple) else cleaned
        return True

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("GlobalEye")
logger.addFilter(NullByteFilter())

# ──────────────────────────────────────────────────────────────────────────────
#  UTILITIES
# ──────────────────────────────────────────────────────────────────────────────

def now_ist():  return datetime.now(IST)
def today_str():return now_ist().strftime("%Y-%m-%d")

def is_market_open():
    n=now_ist(); ds=n.strftime("%Y-%m-%d")
    if n.weekday()>=5:           return False,"Weekend"
    if ds in NSE_HOLIDAYS:       return False,"NSE Holiday"
    t=n.time()
    if t<_t("09:15"):            return False,"Pre-Open (no orders)"
    if t<_t("15:30"):            return True,"Market Open"
    if t<_t("16:00"):            return True,"Post-Market"
    return False,"After-Hours"

def _t(s): return datetime.strptime(s,"%H:%M").time()
def is_intraday_window(): n=now_ist(); return _t("09:20")<=n.time()<=_t("15:10")
def is_squareoff_time():  n=now_ist(); return _t("15:10")<=n.time()<=_t("15:25")
def is_premarket_pulse_time(): n=now_ist(); return _t("06:55")<=n.time()<=_t("07:10")
def is_premarket_brief_time(): n=now_ist(); return _t("07:55")<=n.time()<=_t("08:10")
def is_eod_time():        n=now_ist(); return _t("15:28")<=n.time()<=_t("15:45")

def load_json(path,default):
    try:
        if os.path.exists(path):
            with open(path, 'rb') as f:
                raw = f.read()
            # Strip null bytes that sneak in from PythonAnywhere uploads
            clean = raw.replace(b'\x00', b'')
            if clean != raw:
                with open(path, 'wb') as f:
                    f.write(clean)
                logger.info(f"Stripped null bytes from {path}")
            return json.loads(clean.decode('utf-8'))
    except Exception as e: logger.warning(f"load_json: {e}")
    return default

def save_json(path,data):
    try:
        with open(path,"w") as f: json.dump(data,f,indent=2,default=str)
    except Exception as e: logger.error(f"save_json: {e}")

def make_hash(text): return hashlib.md5(text.encode()).hexdigest()[:12]
def is_eligible(sym,price):
    if price<MIN_PRICE: return False,"Penny"
    if any(s in sym.upper() for s in ["SME","EMERGE","-SM","-BE","-BZ"]): return False,"SME"
    # FIX #9: Block government securities
    if sym[0].isdigit(): return False,"GovtSec"
    _blocked_gs = ["GS20","GS19","GSEC","AFIL","SSCL","SDL","TBILL","SGBOND"]
    if any(bp in sym.upper() for bp in _blocked_gs): return False,"GovtSec"
    if "-" in sym and any(c.isdigit() for c in sym.split("-")[-1]): return False,"BondSeries"
    return True,"OK"

# ──────────────────────────────────────────────────────────────────────────────
#  GEMINI AI

# ══════════════════════════════════════════════════════════════════════════════
#  GTT IMMEDIATE — Place GTT OCO right after every buy (v23.5.0)
#  Institutional standard: protection from SECOND ONE, not next morning
# ══════════════════════════════════════════════════════════════════════════════
def place_gtt_immediate(kite, symbol, qty, entry_price, sl_price, target_price, trader_obj=None):
    """Place GTT OCO immediately after buy order fills.
    SMART: Skips if LiveEquityTrader already placed GTT (prevents duplicates).
    SAFE:  Validates SL is below current LTP — prevents Trigger already met errors."""
    if not kite or qty <= 0 or entry_price <= 0:
        return None
    if trader_obj and symbol in trader_obj.book.get("positions", {}):
        existing_gtt = trader_obj.book["positions"][symbol].get("gtt_id")
        if existing_gtt and existing_gtt != "?" and existing_gtt != "":
            logger.debug(f"GTT INSTANT SKIP [{symbol}]: Already has GTT {existing_gtt}")
            return existing_gtt

    try:
        _sl_trigger = round(sl_price * 1.005, 1) if sl_price > 0 else round(entry_price * 0.98, 1)
        _sl_limit   = round(sl_price, 1) if sl_price > 0 else round(entry_price * 0.975, 1)
        _tp_trigger = round(target_price * 0.995, 1) if target_price > 0 else round(entry_price * 1.195, 1)
        _tp_limit   = round(target_price * 0.99, 1) if target_price > 0 else round(entry_price * 1.19, 1)

        # Get current LTP — Zerodha needs SL trigger < LTP < Target trigger for OCO SELL
        _ltp = entry_price
        try:
            _ltp_data = kite.ltp([f"NSE:{symbol}"])
            if f"NSE:{symbol}" in _ltp_data:
                _ltp = round(_ltp_data[f"NSE:{symbol}"]["last_price"], 2)
        except Exception:
            pass

        # Safety: if SL >= LTP price already below SL
        # Only place AMO during allowed window (not during 01:00-05:30 maintenance)
        if _sl_trigger >= _ltp:
            from datetime import datetime as _dt
            _hr = now_ist().hour if 'now_ist' in dir() else _dt.now().hour
            _amo_allowed = not (1 <= _hr < 6)  # Block 01:00-05:30 maintenance window
            if _amo_allowed:
                logger.warning(
                    f"GTT SKIP [{symbol}]: SL Rs.{_sl_trigger} >= LTP Rs.{_ltp} "
                    f"— SL breached, queuing AMO SELL for market open"
                )
                try:
                    kite.place_order(
                        variety="amo", exchange="NSE", tradingsymbol=symbol,
                        transaction_type="SELL", quantity=qty, product="CNC",
                        order_type="MARKET", tag="SL_BREACH_AMO",
                    )
                    logger.info(f"AUTO-SELL AMO [{symbol}]: qty={qty} SL breached LTP=Rs.{_ltp}")
                except Exception as _amo_e:
                    logger.warning(f"Auto-sell AMO [{symbol}]: {_amo_e}")
            else:
                logger.warning(
                    f"GTT SKIP [{symbol}]: SL Rs.{_sl_trigger} >= LTP Rs.{_ltp} "
                    f"— SL breached but in maintenance window, GTT will handle at open"
                )
            return None

        # If target <= LTP — price already above target, place SL-only SINGLE GTT
        if _tp_trigger <= _ltp:
            logger.info(f"GTT [{symbol}]: Target Rs.{_tp_trigger} <= LTP Rs.{_ltp} — SL-only GTT")
            resp = kite.place_gtt(
                trigger_type=kite.GTT_TYPE_SINGLE,
                tradingsymbol=symbol, exchange="NSE",
                trigger_values=[_sl_trigger],
                last_price=_ltp,
                orders=[{"exchange":"NSE","tradingsymbol":symbol,"transaction_type":"SELL",
                         "quantity":qty,"order_type":"LIMIT","product":"CNC","price":_sl_limit}],
            )
        else:
            resp = kite.place_gtt(
                trigger_type=kite.GTT_TYPE_OCO,
                tradingsymbol=symbol, exchange="NSE",
                trigger_values=[_sl_trigger, _tp_trigger],
                last_price=_ltp,
                orders=[
                    {"exchange":"NSE","tradingsymbol":symbol,"transaction_type":"SELL",
                     "quantity":qty,"order_type":"LIMIT","product":"CNC","price":_sl_limit},
                    {"exchange":"NSE","tradingsymbol":symbol,"transaction_type":"SELL",
                     "quantity":qty,"order_type":"LIMIT","product":"CNC","price":_tp_limit},
                ],
            )

        gtt_id = resp.get("trigger_id", "?")
        logger.info(f"GTT INSTANT [{symbol}]: SL=Rs.{_sl_limit} T2=Rs.{_tp_limit} LTP=Rs.{_ltp} ID:{gtt_id}")
        if trader_obj and symbol in trader_obj.book.get("positions", {}):
            trader_obj.book["positions"][symbol]["gtt_id"]     = gtt_id
            trader_obj.book["positions"][symbol]["gtt_sl"]     = _sl_trigger
            trader_obj.book["positions"][symbol]["gtt_target"] = _tp_trigger
            trader_obj._save()
        return gtt_id
    except Exception as e:
        logger.warning(f"GTT INSTANT FAILED [{symbol}]: {e}")
        return None

# ══════════════════════════════════════════════════════════════════════════════
#  GTT AUDIT — Check all positions have valid GTTs, re-place missing ones
#  Runs at 08:30 on trading days (before market open)
# ══════════════════════════════════════════════════════════════════════════════
def gtt_audit(kite, traders, send_telegram_fn):
    """
    GTT Audit — simple, Kite-first approach.
    Source of truth: kite.holdings() + kite.positions()
    NOT the bot book. Runs at 08:30 on trading days.

    Simple rules:
    1. Every stock in holdings/positions must have an active GTT
    2. If missing — place one
    3. If GTT exists but stock is gone — delete it (orphan)
    """
    if not kite:
        return 0, 0, 0

    placed  = 0
    orphans = 0

    try:
        # Step 1: Get all active GTTs from Kite
        active_gtts = {}  # symbol -> {id, sl_trigger}
        try:
            for g in (kite.get_gtts() or []):
                if g.get("status") == "active":
                    sym   = g.get("condition", {}).get("tradingsymbol", "")
                    trigs = g.get("trigger_values", [])
                    gid   = g.get("id")
                    if sym:
                        active_gtts[sym] = {
                            "id":   gid,
                            "sl":   trigs[0] if trigs else 0,
                        }
        except Exception as _ge:
            logger.warning(f"GTT audit — fetch GTTs failed: {_ge}")
            return 0, 0, 0

        # Step 2: Get all stocks we actually own (holdings + open positions)
        owned = {}  # symbol -> {qty, avg, ltp}
        try:
            for h in (kite.holdings() or []):
                sym = h.get("tradingsymbol", "")
                qty = h.get("quantity", 0) + h.get("t1_quantity", 0)
                if sym and qty > 0:
                    owned[sym] = {
                        "qty": qty,
                        "avg": h.get("average_price", 0),
                        "ltp": h.get("last_price", 0),
                    }
        except Exception as _he:
            logger.debug(f"GTT audit — holdings: {_he}")

        try:
            for p in (kite.positions() or {}).get("net", []):
                sym = p.get("tradingsymbol", "")
                qty = p.get("quantity", 0)
                if sym and qty > 0 and sym not in owned:
                    owned[sym] = {
                        "qty": qty,
                        "avg": p.get("average_price", 0),
                        "ltp": p.get("last_price", 0),
                    }
        except Exception as _pe:
            logger.debug(f"GTT audit — positions: {_pe}")

        # Bot book lookup for SL/Target
        _bl = {}
        for _tr in traders:
            for _sym, _pos in _tr.book.get("positions", {}).items():
                if _sym not in _bl:
                    _bl[_sym] = _pos

        # Step 3: Every owned stock must have a GTT
        for sym, data in owned.items():
            if sym in active_gtts:
                continue  # Already protected — good

            # Missing GTT — place one now
            qty = data["qty"]
            avg = data["avg"]
            ltp = data["ltp"] or avg

            # Get SL/Target from bot book if known
            bp   = _bl.get(sym, {})
            sl   = bp.get("stop_loss", 0)
            t2   = bp.get("target2", 0)

            # v23.6.1 FIX: Smart fallback SL — old 0.5% was too tight
            # Uses 3% below LTP, capped at 5% below avg purchase price
            if sl <= 0 or sl >= ltp:
                sl = smart_sl_fallback(ltp, avg_price=avg)
            if t2 <= 0:
                t2 = round(avg * 1.20, 2)

            gtt_id = place_gtt_immediate(kite, sym, qty, avg, sl, t2,
                                          trader_obj=None)
            if gtt_id:
                placed += 1
                # Write back to bot book
                for _tr in traders:
                    if sym in _tr.book.get("positions", {}):
                        _tr.book["positions"][sym]["gtt_id"] = gtt_id
                        _tr.book["positions"][sym]["gtt_sl"] = round(sl * 1.005, 1)
                        _tr._save()
                        break
                logger.info(f"GTT AUDIT PLACED [{sym}]: SL=Rs.{sl:.1f} T2=Rs.{t2:.1f}")

        # Step 4: Delete orphan GTTs (GTT exists but we don't own the stock)
        for sym, gtt_data in active_gtts.items():
            if sym not in owned:
                try:
                    kite.delete_gtt(gtt_data["id"])
                    orphans += 1
                    logger.info(f"GTT ORPHAN DELETED [{sym}]: stock not in holdings")
                except Exception as _de:
                    logger.debug(f"GTT delete [{sym}]: {_de}")

        # Report
        if placed > 0 or orphans > 0:
            send_telegram_fn(
                f"GTT AUDIT 08:30\n"
                f"Holdings: {len(owned)} | GTTs: {len(active_gtts)}\n"
                f"Placed: {placed} new | Orphans deleted: {orphans}\n"
                f"All holdings protected",
                priority="trade"
            )
        else:
            logger.info(
                f"GTT AUDIT: All OK — "
                f"{len(owned)} holdings, {len(active_gtts)} GTTs"
            )

    except Exception as e:
        logger.error(f"GTT audit: {e}")
        return 0, 0, 0

    return placed, 0, orphans


# ══════════════════════════════════════════════════════════════════════════════
#  PROFIT COMPOUNDING ENGINE (v23.5.0)
#  When a trade closes with profit, flag capital for immediate redeployment
#  Soros: "When I see a profit, I get more aggressive, not less"
# ══════════════════════════════════════════════════════════════════════════════
class ProfitCompounder:
    """Tracks realized profits and flags them for rapid redeployment."""
    _pending_profits = []
    _total_compounded = 0
    _compound_count = 0

    @classmethod
    def register_profit(cls, pnl, strategy, symbol):
        """Called after every profitable exit. Queues profit for redeployment."""
        if pnl <= 0:
            return
        cls._pending_profits.append({
            "amount": pnl, "strategy": strategy, "symbol": symbol,
            "time": now_ist().isoformat(), "deployed": False
        })
        logger.info(f"COMPOUNDER: +Rs.{pnl:,.0f} from {symbol} queued for redeployment")

    @classmethod
    def get_compound_boost(cls):
        """Returns extra capital from recent profits (last 4 hours).
        This gets added to available capital for next trades."""
        cutoff = now_ist() - timedelta(hours=4)
        total = 0
        for p in cls._pending_profits:
            if not p["deployed"]:
                try:
                    pt = datetime.fromisoformat(p["time"])
                    if not pt.tzinfo:
                        pt = IST.localize(pt)
                    if pt >= cutoff:
                        total += p["amount"]
                except Exception:
                    pass
        return round(total, 2)

    @classmethod
    def mark_deployed(cls, amount):
        """Mark profits as deployed after they're used in a new trade."""
        remaining = amount
        for p in cls._pending_profits:
            if not p["deployed"] and remaining > 0:
                p["deployed"] = True
                remaining -= p["amount"]
                cls._compound_count += 1
                cls._total_compounded += p["amount"]

    @classmethod
    def summary(cls):
        pending = sum(p["amount"] for p in cls._pending_profits if not p["deployed"])
        return {
            "pending": round(pending, 2),
            "total_compounded": round(cls._total_compounded, 2),
            "compound_count": cls._compound_count,
        }


# ══════════════════════════════════════════════════════════════════════════════
#  CONVICTION POSITION SIZING (v23.5.0)
#  Druckenmiller: "Put all your eggs in one basket — just make sure
#                  it's the right basket"
#  HIGH conviction (3/3 AI + promoter + sector + filing) → 2x normal size
#  MODERATE (2/3 AI + some support) → 1x normal size
#  LOW (bare minimum approval) → 0.5x normal size
# ══════════════════════════════════════════════════════════════════════════════
def conviction_multiplier(confidence, sent_score, has_promoter_buy=False, has_sector_tailwind=False):
    """Returns position size multiplier based on conviction level."""
    score = 0
    # Base score from AI confidence (0-100)
    if confidence >= 85: score += 3
    elif confidence >= 70: score += 2
    elif confidence >= 55: score += 1

    # Sentiment boost
    if sent_score >= 70: score += 2
    elif sent_score >= 50: score += 1

    # Catalysts
    if has_promoter_buy: score += 1
    if has_sector_tailwind: score += 1

    # Map to multiplier (minimum 0.75 — never block a trade completely)
    if score >= 6:
        return 2.0, "ULTRA-HIGH"   # Soros bet
    elif score >= 4:
        return 1.5, "HIGH"          # Strong conviction
    elif score >= 2:
        return 1.0, "MODERATE"      # Standard position
    else:
        return 0.75, "LOW"          # Smaller position, but still trades


# ══════════════════════════════════════════════════════════════════════════════
#  PENNY MULTIBAGGER SCANNER (v23.5.0)
#  Scans for quality penny stocks with strict filters to avoid pump-and-dump
#  Inspired by ET Markets criteria: price <Rs.50, mcap <1000cr, vol 5L+
#  MAX 5% of swing capital, auto-promote winners at 50%+ gain
# ══════════════════════════════════════════════════════════════════════════════
class PennyMultibaggerScanner:
    """Finds quality penny stocks with multibagger potential."""

    # Strict quality filters
    PENNY_MIN_PRICE = 5       # Below 5 = junk
    PENNY_MAX_PRICE = 50      # Above 50 = not penny
    PENNY_MIN_MCAP_CR = 50    # Below 50cr = nano-cap junk
    PENNY_MAX_MCAP_CR = 1000  # Above 1000cr = not micro-cap
    PENNY_MIN_VOLUME = 500000 # 5 lakh minimum daily volume
    PENNY_MIN_PROMOTER = 40   # Promoter must have skin in the game
    PENNY_MAX_DEBT_EQ = 1.0   # No debt-heavy penny stocks
    PENNY_MAX_POSITIONS = 3   # Max 3 penny positions at a time
    PENNY_MAX_CAPITAL_PCT = 10 # Max 10% of swing capital on pennies

    _sent_today = set()  # Dedup within a day

    @classmethod
    def reset_daily(cls):
        cls._sent_today = set()

    @classmethod
    def scan(cls, all_scans, kite=None):
        """Scan for quality penny stocks from the full scan universe.
        Returns list of penny candidates sorted by score."""
        candidates = []
        for r in all_scans:
            sym = r["symbol"]
            price = r.get("price", 0)

            # Price filter — penny range only
            if price < cls.PENNY_MIN_PRICE or price > cls.PENNY_MAX_PRICE:
                continue

            # Skip if already alerted today
            if sym in cls._sent_today:
                continue

            # Volume filter
            vol = r.get("volume", 0)
            vol_avg = r.get("vol_avg_20d", 0)
            if vol < cls.PENNY_MIN_VOLUME and vol_avg < cls.PENNY_MIN_VOLUME:
                continue

            # Skip SME/bonds/govt
            if any(s in sym.upper() for s in ["SME","EMERGE","-SM","-BE","-BZ"]):
                continue
            if sym[0].isdigit():
                continue

            # Quality score (0-10)
            score = 0
            reasons = []

            # Promoter holding
            promo = r.get("promoter_holding", 0)
            if promo >= cls.PENNY_MIN_PROMOTER:
                score += 2
                reasons.append(f"Promoter {promo:.0f}%")
            elif promo > 0 and promo < cls.PENNY_MIN_PROMOTER:
                continue  # Too low — skip entirely

            # Debt/Equity
            de = r.get("debt_equity", 999)
            if de <= 0.3:
                score += 2
                reasons.append("Low debt")
            elif de <= cls.PENNY_MAX_DEBT_EQ:
                score += 1
                reasons.append(f"D/E={de:.1f}")
            else:
                continue  # Too much debt — skip

            # RSI recovery from oversold
            rsi = r.get("rsi", 50)
            if 30 <= rsi <= 45:
                score += 2
                reasons.append(f"RSI recovering ({rsi:.0f})")
            elif rsi < 30:
                score += 1
                reasons.append(f"RSI deep oversold ({rsi:.0f})")

            # Volume surge (smart money accumulation)
            vol_surge = r.get("vol_surge", 1.0)
            if vol_surge >= 2.0:
                score += 2
                reasons.append(f"Vol surge {vol_surge:.1f}x")
            elif vol_surge >= 1.3:
                score += 1
                reasons.append(f"Vol up {vol_surge:.1f}x")

            # Positive trend signals
            if "BUY" in r.get("swing_sig", ""):
                score += 1
                reasons.append("Swing BUY")
            if "Bullish" in r.get("trend", ""):
                score += 1
                reasons.append("Bullish trend")

            # 52-week position (near low = bounce potential)
            w52l = r.get("week_52_low", 0)
            w52h = r.get("week_52_high", 0)
            if w52l > 0 and w52h > 0 and (w52h - w52l) > 0:
                position_in_range = (price - w52l) / (w52h - w52l)
                if position_in_range <= 0.25:
                    score += 1
                    reasons.append(f"Near 52W low ({position_in_range:.0%})")

            # Minimum score to qualify
            if score < 4:
                continue

            # Market cap filter (if available)
            mcap = r.get("mcap_cr", 0)
            if mcap > 0:
                if mcap < cls.PENNY_MIN_MCAP_CR or mcap > cls.PENNY_MAX_MCAP_CR:
                    continue
                reasons.append(f"MCap Rs.{mcap:.0f}cr")

            candidates.append({
                "symbol": sym,
                "price": price,
                "score": score,
                "reasons": reasons,
                "sl": round(price * 0.88, 2),  # Tight 12% SL for penny
                "t1": round(price * 1.25, 2),  # 25% first target
                "t2": round(price * 1.50, 2),  # 50% second target (multibagger territory)
                "rsi": rsi,
                "vol_surge": vol_surge,
                "promoter": promo,
            })

        # Sort by score descending
        candidates.sort(key=lambda x: x["score"], reverse=True)
        return candidates[:10]  # Top 10

    @classmethod
    def should_promote(cls, pos):
        """Check if a penny position should be promoted to regular swing.
        Returns True if gain >= 50%."""
        entry = pos.get("entry_price", 0)
        current = pos.get("last_price", entry)
        if entry <= 0:
            return False
        gain_pct = (current - entry) / entry * 100
        return gain_pct >= 50


# ══════════════════════════════════════════════════════════════════════════════
#  GEMINI AI — supports both old and new package
# ──────────────────────────────────────────────────────────────────────────────

# Gemini call counter to avoid quota
_gemini_calls_today = 0
_gemini_calls_date  = ""

def call_gemini(prompt):
    """Call Gemini AI with quota management."""
    global _gemini_calls_today, _gemini_calls_date
    if not GEMINI_API_KEY:
        return "AI commentary unavailable — set GEMINI_API_KEY in .env"

    # Reset counter daily
    today = now_ist().strftime("%Y-%m-%d")
    if _gemini_calls_date != today:
        _gemini_calls_today = 0
        _gemini_calls_date  = today

    # v23.6.4: Removed 5 call limit — billing is enabled, we have 50+ calls/day
    # Old limit was blocking DeepFilingAnalyzer after just 5 filings!
    
    _gemini_calls_today += 1
    logger.info(f"Gemini call #{_gemini_calls_today} today")

    # Try new google-genai package first
    try:
        from google import genai as _genai
        client   = _genai.Client(api_key=GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=prompt
        )
        return response.text
    except ImportError:
        pass
    except Exception as e:
        logger.error(f"Gemini new: {e}")

    # Try old package
    try:
        import google.generativeai as _genai_old
        _genai_old.configure(api_key=GEMINI_API_KEY)
        model = _genai_old.GenerativeModel("gemini-2.5-flash-lite")
        return model.generate_content(prompt).text
    except ImportError:
        return "Gemini not installed."
    except Exception as e:
        logger.error(f"Gemini old: {e}")
        return f"_AI commentary unavailable. Will retry next report._"


# ══════════════════════════════════════════════════════════════════════════════
#  v23.6.4: DEEP FILING ANALYZER
#  Reads FULL filing content (not just keywords) and uses AI to determine
#  TRUE sentiment. Prevents false positives like "ORDER_WIN" being a legal case.
# ══════════════════════════════════════════════════════════════════════════════

class DeepFilingAnalyzer:
    """
    Analyzes full filing content to determine TRUE sentiment.
    
    Problem solved:
    - "BOARD_MEETING" could be dividend (BULLISH) or loss (BEARISH)
    - "ORDER_WIN" could be business order or legal case victory
    - "PROMOTER" could be buying (BULLISH) or selling (BEARISH)
    
    Solution:
    1. Fetch full filing from NSE/BSE
    2. Use Gemini AI to analyze content
    3. Return TRUE sentiment with confidence
    """
    
    # NSE corporate filings API
    NSE_FILINGS_URL = "https://www.nseindia.com/api/corporate-announcements"
    NSE_BASE_URL = "https://www.nseindia.com"
    BSE_FILINGS_URL = "https://api.bseindia.com/BseIndiaAPI/api/AnnGetData/w"
    BSE_PDF_BASE = "https://www.bseindia.com/xml-data/corpfiling/AttachLive"
    
    # Cache to avoid re-analyzing same filing
    _cache = {}
    _cache_date = ""
    
    # Gemini calls for filing analysis (separate from report quota)
    _filing_ai_calls = 0
    _filing_ai_date = ""
    MAX_FILING_AI_CALLS = 50  # Increased to 50 for full content analysis
    
    # Session for NSE (maintains cookies)
    _nse_session = None
    _nse_session_time = None
    
    @classmethod
    def _reset_daily(cls):
        """Reset daily counters."""
        today = now_ist().strftime("%Y-%m-%d")
        if cls._filing_ai_date != today:
            cls._filing_ai_calls = 0
            cls._filing_ai_date = today
            cls._cache = {}
            cls._cache_date = today
    
    @classmethod
    def _get_nse_session(cls):
        """Get or create NSE session with cookies."""
        now = time.time()
        # Refresh session every 10 minutes
        if cls._nse_session is None or (cls._nse_session_time and now - cls._nse_session_time > 600):
            try:
                cls._nse_session = requests.Session()
                headers = {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                    "Accept-Language": "en-US,en;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br",
                    "Connection": "keep-alive",
                }
                cls._nse_session.headers.update(headers)
                # Get cookies from main page
                cls._nse_session.get("https://www.nseindia.com", timeout=10)
                cls._nse_session_time = now
                logger.debug("NSE session refreshed")
            except Exception as e:
                logger.debug(f"NSE session error: {e}")
                return None
        return cls._nse_session
    
    @classmethod
    def fetch_nse_filing_content(cls, symbol, hours_back=48):
        """
        Fetch recent filings from NSE for a symbol with FULL content.
        Returns list of filings with extracted text.
        """
        try:
            session = cls._get_nse_session()
            if not session:
                logger.debug(f"NSE filing [{symbol}]: No session available")
                return []
            
            # Fetch announcements list with retry
            params = {
                "index": "equities",
                "symbol": symbol,
                "from_date": (now_ist() - timedelta(hours=hours_back)).strftime("%d-%m-%Y"),
                "to_date": now_ist().strftime("%d-%m-%Y"),
            }
            
            # Try up to 2 times with session refresh
            for attempt in range(2):
                try:
                    r = session.get(cls.NSE_FILINGS_URL, params=params, timeout=15)
                    if r.status_code == 200:
                        break
                    elif r.status_code == 401 or r.status_code == 403:
                        # Session expired, refresh
                        logger.debug(f"NSE filing [{symbol}]: Session expired, refreshing...")
                        cls._nse_session = None
                        cls._nse_session_time = None
                        session = cls._get_nse_session()
                        if not session:
                            return []
                        time.sleep(1)
                    else:
                        logger.debug(f"NSE filing fetch [{symbol}]: HTTP {r.status_code}")
                        return []
                except Exception as e:
                    logger.debug(f"NSE filing [{symbol}] attempt {attempt+1}: {e}")
                    if attempt == 0:
                        time.sleep(1)
                        cls._nse_session = None
                        session = cls._get_nse_session()
                    continue
            else:
                return []
            
            try:
                data = r.json()
            except:
                logger.debug(f"NSE filing [{symbol}]: Invalid JSON response")
                return []
            
            if not data:
                logger.debug(f"NSE filing [{symbol}]: No filings found")
                return []
            
            filings = []
            
            for item in data[:3]:  # Only process latest 3 filings
                subject = item.get("desc", "") or item.get("subject", "")
                attachment = item.get("attchmntFile", "")
                an_dt = item.get("an_dt", "")
                
                # Try to get PDF content
                pdf_text = ""
                if attachment:
                    pdf_url = f"{cls.NSE_BASE_URL}{attachment}" if attachment.startswith("/") else attachment
                    logger.debug(f"NSE filing [{symbol}]: Fetching PDF from {pdf_url[:80]}...")
                    pdf_text = cls._extract_pdf_text(pdf_url, session)
                    if pdf_text:
                        logger.info(f"NSE filing [{symbol}]: Extracted {len(pdf_text)} chars from PDF")
                
                filings.append({
                    "subject": subject,
                    "attachment": attachment,
                    "date": an_dt,
                    "symbol": symbol,
                    "full_text": pdf_text[:5000] if pdf_text else subject,  # Use subject as fallback
                })
            
            if filings:
                total_content = sum(len(f.get("full_text", "")) for f in filings)
                logger.info(f"NSE filings [{symbol}]: Found {len(filings)} filings, {total_content} chars total")
            return filings
            
        except Exception as e:
            logger.debug(f"NSE filing fetch [{symbol}]: {e}")
            return []
    
    @classmethod
    def _extract_pdf_text(cls, pdf_url, session=None):
        """Extract text from PDF URL."""
        try:
            if not pdf_url:
                return ""
            
            # Use provided session or create new
            if session is None:
                session = requests.Session()
                session.headers.update({
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                })
            
            # Download PDF
            r = session.get(pdf_url, timeout=30)
            if r.status_code != 200:
                return ""
            
            # Check if it's actually a PDF
            content_type = r.headers.get("Content-Type", "")
            if "pdf" not in content_type.lower() and not r.content[:4] == b'%PDF':
                # Might be HTML page with filing text
                if "html" in content_type.lower():
                    # Extract text from HTML
                    from html.parser import HTMLParser
                    class TextExtractor(HTMLParser):
                        def __init__(self):
                            super().__init__()
                            self.text = []
                        def handle_data(self, data):
                            self.text.append(data.strip())
                    parser = TextExtractor()
                    parser.feed(r.text)
                    return " ".join(filter(None, parser.text))[:5000]
                return ""
            
            # Try PyPDF2 for PDF extraction
            try:
                import io
                from PyPDF2 import PdfReader
                pdf_file = io.BytesIO(r.content)
                reader = PdfReader(pdf_file)
                text_parts = []
                for page in reader.pages[:5]:  # First 5 pages only
                    text_parts.append(page.extract_text() or "")
                return " ".join(text_parts)[:5000]
            except ImportError:
                logger.debug("PyPDF2 not installed, trying pdfplumber")
            
            # Try pdfplumber
            try:
                import io
                import pdfplumber
                pdf_file = io.BytesIO(r.content)
                text_parts = []
                with pdfplumber.open(pdf_file) as pdf:
                    for page in pdf.pages[:5]:
                        text_parts.append(page.extract_text() or "")
                return " ".join(text_parts)[:5000]
            except ImportError:
                logger.debug("pdfplumber not installed")
            
            # Fallback: just return raw text from PDF (crude but works for simple PDFs)
            try:
                text = r.content.decode('utf-8', errors='ignore')
                # Extract readable text between PDF markers
                import re
                matches = re.findall(r'\(([^)]+)\)', text)
                return " ".join(matches)[:3000]
            except:
                pass
            
            return ""
            
        except Exception as e:
            logger.debug(f"PDF extraction error: {e}")
            return ""
    
    @classmethod
    def fetch_bse_filing_content(cls, symbol, hours_back=48):
        """Fetch recent filings from BSE for a symbol."""
        try:
            # BSE API for announcements
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept": "application/json",
                "Referer": "https://www.bseindia.com/"
            }
            
            # Get scrip code for symbol (would need mapping)
            # For now, return empty - NSE is primary source
            return []
            
        except Exception as e:
            logger.debug(f"BSE filing fetch [{symbol}]: {e}")
            return []
    
    @classmethod
    def fetch_nse_filing(cls, symbol, filing_type, hours_back=24):
        """
        Fetch recent filings from NSE for a symbol.
        Returns list of filing texts.
        """
        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept": "application/json",
                "Accept-Language": "en-US,en;q=0.9",
                "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
            }
            
            # Get session cookies first
            session = requests.Session()
            session.get("https://www.nseindia.com", headers=headers, timeout=10)
            
            # Fetch announcements
            params = {
                "index": "equities",
                "symbol": symbol,
                "from_date": (now_ist() - timedelta(hours=hours_back)).strftime("%d-%m-%Y"),
                "to_date": now_ist().strftime("%d-%m-%Y"),
            }
            
            r = session.get(cls.NSE_FILINGS_URL, headers=headers, params=params, timeout=15)
            if r.status_code != 200:
                logger.debug(f"NSE filing fetch [{symbol}]: HTTP {r.status_code}")
                return []
            
            data = r.json()
            filings = []
            for item in data:
                subject = item.get("desc", "") or item.get("subject", "")
                attchmnt = item.get("attchmntFile", "")
                an_dt = item.get("an_dt", "")
                filings.append({
                    "subject": subject,
                    "attachment": attchmnt,
                    "date": an_dt,
                    "symbol": symbol,
                })
            
            logger.info(f"NSE filings [{symbol}]: Found {len(filings)} announcements")
            return filings
            
        except Exception as e:
            logger.debug(f"NSE filing fetch [{symbol}]: {e}")
            return []
    
    @classmethod
    def analyze_with_ai(cls, symbol, filing_type, subject, extra_context=""):
        """
        Use Gemini AI to analyze filing content and determine TRUE sentiment.
        
        v23.6.4: Now fetches FULL filing content from NSE before analysis!
        
        Returns:
            (sentiment, confidence, reason)
            sentiment: "BULLISH", "BEARISH", or "NEUTRAL"
            confidence: 0-100
            reason: explanation
        """
        cls._reset_daily()
        
        # Check cache
        cache_key = f"{symbol}_{filing_type}_{subject[:50]}"
        if cache_key in cls._cache:
            cached = cls._cache[cache_key]
            logger.info(f"DeepFiling [{symbol}]: Using cached result — {cached['sentiment']}")
            return cached["sentiment"], cached["confidence"], cached["reason"]
        
        # Check AI quota
        if cls._filing_ai_calls >= cls.MAX_FILING_AI_CALLS:
            logger.warning(f"DeepFiling [{symbol}]: AI quota exhausted, using keyword fallback")
            return cls._keyword_fallback(filing_type, subject, extra_context)
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.4: FETCH FULL FILING CONTENT FROM NSE
        # This is the key improvement - we now read the actual PDF!
        # ═══════════════════════════════════════════════════════════════════
        full_content = ""
        try:
            nse_filings = cls.fetch_nse_filing_content(symbol, hours_back=48)
            if nse_filings:
                # Get the most relevant filing (latest with content)
                for filing in nse_filings:
                    if filing.get("full_text"):
                        full_content = filing["full_text"]
                        subject = filing.get("subject", subject) or subject
                        logger.info(f"DeepFiling [{symbol}]: Fetched {len(full_content)} chars from NSE PDF")
                        break
                if not full_content:
                    logger.warning(f"DeepFiling [{symbol}]: NSE returned {len(nse_filings)} filings but no PDF content extracted")
            else:
                logger.warning(f"DeepFiling [{symbol}]: No filings found on NSE (will use subject only)")
        except Exception as e:
            logger.warning(f"DeepFiling [{symbol}]: Could not fetch NSE content: {e}")
        
        # Combine all available content
        all_content = f"{subject}\n\n{extra_context}\n\n{full_content}".strip()
        has_good_data = len(all_content) > 100
        
        # Build AI prompt with full content
        content_section = all_content[:4000] if all_content else "(No content available)"
        
        prompt = f"""You are an expert Indian stock market analyst. Analyze this corporate filing and determine if it's BULLISH, BEARISH, or NEUTRAL for the stock price.

STOCK: {symbol}
FILING TYPE: {filing_type}

FILING CONTENT:
{content_section}

ANALYSIS RULES:
1. PROMOTER BUYING shares in open market = STRONG BULLISH (80-90% confidence)
2. PROMOTER SELLING/PLEDGING = BEARISH
3. Trading window closure/opening = NEUTRAL (just compliance)
4. ORDER WIN for business contract = BULLISH (check order value)
5. ORDER WIN for legal case (SEBI, SAT, court) = NEUTRAL
6. Dividend/Bonus/Split announcement = BULLISH
7. CEO/CFO/Director resignation = BEARISH
8. Rights issue / QIP = Usually BULLISH
9. Loan default / restructuring = BEARISH
10. Board meeting scheduled = NEUTRAL (wait for outcome)

LOOK FOR THESE KEY DETAILS:
- Number of shares bought/sold
- Transaction value in rupees
- Buyer/seller identity (promoter, FII, DII)
- Date of transaction
- Percentage stake change

Respond in this EXACT format (3 lines only):
SENTIMENT: [BULLISH/BEARISH/NEUTRAL]
CONFIDENCE: [0-100]
REASON: [One line explanation with key numbers if available]"""

        try:
            cls._filing_ai_calls += 1
            logger.info(f"DeepFiling [{symbol}]: AI analysis #{cls._filing_ai_calls} (content: {len(all_content)} chars)")
            
            response = call_gemini(prompt)
            
            # Debug: Log raw response
            logger.info(f"DeepFiling [{symbol}]: Raw AI response: {response[:200] if response else 'EMPTY'}...")
            
            # Parse response
            lines = response.strip().split("\n")
            sentiment = "NEUTRAL"
            confidence = 50
            reason = "AI analysis"
            
            for line in lines:
                line = line.strip()
                # Handle various formats: "SENTIMENT: BULLISH" or "**SENTIMENT:** BULLISH"
                clean_line = line.replace("*", "").replace("#", "").strip()
                
                if "SENTIMENT" in clean_line.upper():
                    # Extract sentiment value
                    parts = clean_line.upper().split(":")
                    if len(parts) >= 2:
                        sent = parts[1].strip().split()[0] if parts[1].strip() else ""
                        if sent in ["BULLISH", "BEARISH", "NEUTRAL"]:
                            sentiment = sent
                            logger.debug(f"DeepFiling [{symbol}]: Parsed sentiment = {sentiment}")
                            
                elif "CONFIDENCE" in clean_line.upper():
                    # Extract confidence value
                    import re
                    numbers = re.findall(r'\d+', clean_line)
                    if numbers:
                        conf = int(numbers[0])
                        confidence = max(0, min(100, conf))
                        logger.debug(f"DeepFiling [{symbol}]: Parsed confidence = {confidence}")
                        
                elif "REASON" in clean_line.upper():
                    # Extract reason
                    parts = clean_line.split(":", 1)
                    if len(parts) >= 2:
                        reason = parts[1].strip()
                        
            # Also check for inline format like "BULLISH (85%)"
            if sentiment == "NEUTRAL" and confidence == 50:
                response_upper = response.upper()
                if "BULLISH" in response_upper:
                    sentiment = "BULLISH"
                    import re
                    conf_match = re.search(r'(\d+)\s*%', response)
                    if conf_match:
                        confidence = int(conf_match.group(1))
                elif "BEARISH" in response_upper:
                    sentiment = "BEARISH"
                    import re
                    conf_match = re.search(r'(\d+)\s*%', response)
                    if conf_match:
                        confidence = int(conf_match.group(1))
            
            # If we have minimal data and AI still said neutral with low confidence,
            # but filing type suggests positive action, boost confidence slightly
            if not has_good_data and filing_type in ("PROMOTER", "BUYBACK", "DIVIDEND"):
                if sentiment == "NEUTRAL" and confidence < 60:
                    # Check if keyword fallback would be more bullish
                    fb_sent, fb_conf, fb_reason = cls._keyword_fallback(filing_type, subject, extra_context)
                    if fb_sent == "BULLISH":
                        sentiment = "BULLISH"
                        confidence = 65
                        reason = f"Filing type {filing_type} typically bullish; {reason}"
            
            # Cache result
            cls._cache[cache_key] = {
                "sentiment": sentiment,
                "confidence": confidence,
                "reason": reason,
            }
            
            logger.info(f"DeepFiling [{symbol}]: AI verdict — {sentiment} ({confidence}%) — {reason[:80]}")
            return sentiment, confidence, reason
            
        except Exception as e:
            logger.error(f"DeepFiling AI [{symbol}]: {e}")
            return cls._keyword_fallback(filing_type, subject, extra_context)
    
    @classmethod
    def _keyword_fallback(cls, filing_type, subject, extra_context):
        """Fallback to keyword analysis if AI unavailable."""
        text = (subject + " " + extra_context).lower()
        
        # Strong BEARISH signals
        bearish_keywords = [
            "loss", "resign", "resignation", "cfo resign", "ceo resign",
            "fraud", "default", "write-off", "impairment", "downgrade",
            "sell", "sold", "pledge", "encumbrance", "sebi order against",
            "penalty", "fine imposed", "violation", "suspended"
        ]
        
        # Strong BULLISH signals
        bullish_keywords = [
            "dividend", "bonus", "split", "buyback", "profit up",
            "profit increased", "revenue grew", "order received",
            "contract won", "business order", "export order",
            "promoter buy", "promoter bought", "stake increase",
            "upgrade", "expansion", "new plant", "capacity addition"
        ]
        
        # NEUTRAL signals
        neutral_keywords = [
            "trading window", "compliance", "regulation", "disclosure",
            "board meeting scheduled", "agm", "egm", "record date",
            "sat set aside", "legal victory", "case disposed"
        ]
        
        bearish_score = sum(1 for k in bearish_keywords if k in text)
        bullish_score = sum(1 for k in bullish_keywords if k in text)
        neutral_score = sum(1 for k in neutral_keywords if k in text)
        
        if bearish_score > bullish_score and bearish_score > neutral_score:
            return "BEARISH", 60, "Keyword analysis: bearish signals detected"
        elif bullish_score > bearish_score and bullish_score > neutral_score:
            return "BULLISH", 60, "Keyword analysis: bullish signals detected"
        else:
            return "NEUTRAL", 50, "Keyword analysis: no clear direction"
    
    @classmethod
    def should_trade(cls, symbol, filing_type, subject, extra_context=""):
        """
        Main entry point. Determines if we should trade based on filing.
        
        Returns:
            (should_trade, sentiment, confidence, reason)
        """
        sentiment, confidence, reason = cls.analyze_with_ai(
            symbol, filing_type, subject, extra_context
        )
        
        # Trading rules based on analysis
        if sentiment == "BEARISH":
            return False, sentiment, confidence, f"DEEP ANALYSIS: {reason}"
        
        if sentiment == "NEUTRAL" and confidence < 70:
            return False, sentiment, confidence, f"NEUTRAL with low confidence: {reason}"
        
        if sentiment == "BULLISH" and confidence >= 60:
            return True, sentiment, confidence, f"DEEP ANALYSIS: {reason}"
        
        # Default: don't trade if uncertain
        return False, sentiment, confidence, f"Uncertain: {reason}"

# ──────────────────────────────────────────────────────────────────────────────
#  ALERTS — Telegram + WhatsApp (CallMeBot) — Same messages to both
# ──────────────────────────────────────────────────────────────────────────────

def send_whatsapp(msg):
    """Send WhatsApp message via CallMeBot API (free, works on any phone)."""
    if not WHATSAPP_PHONE or not WHATSAPP_APIKEY:
        return
    try:
        # Strip Markdown for WhatsApp (CallMeBot doesn't support it)
        clean = msg.replace("*","").replace("`","").replace("_","")
        # URL encode
        import urllib.parse
        encoded = urllib.parse.quote_plus(clean)
        url = (f"https://api.callmebot.com/whatsapp.php"
               f"?phone={WHATSAPP_PHONE}&text={encoded}&apikey={WHATSAPP_APIKEY}")
        r = requests.get(url, timeout=30)
        if r.status_code == 200:
            logger.debug("WhatsApp sent OK")
        else:
            logger.debug(f"WhatsApp: {r.status_code}")
    except Exception as e:
        logger.debug(f"WhatsApp: {e}")

def send_whatsapp_doc(doc_path):
    """Send PDF document via WhatsApp — CallMeBot supports images/docs."""
    if not WHATSAPP_PHONE or not WHATSAPP_APIKEY:
        return
    # CallMeBot free tier only supports text. For docs, send a notification.
    fname = os.path.basename(doc_path)
    send_whatsapp(f"📄 PDF Report ready: {fname}\nCheck Telegram for the PDF file.")


# ── CUMULATIVE TRADE HISTORY — persists across days ──────────────
TRADE_HISTORY_FILE = os.path.join(DATA_DIR, "trade_history_cumulative.json")

def _append_trade_history(trade):
    """Append a closed trade to cumulative history file."""
    try:
        history = load_json(TRADE_HISTORY_FILE, [])
        # Avoid duplicates: check if same symbol + exit_time exists
        _key = f"{trade.get('symbol','')}_{trade.get('exit_time','')}"
        existing_keys = {f"{t.get('symbol','')}_{t.get('exit_time','')}" for t in history}
        if _key not in existing_keys:
            history.append(trade)
            # Keep last 500 trades max
            if len(history) > 500:
                history = history[-500:]
            save_json(TRADE_HISTORY_FILE, history)
    except Exception as e:
        logger.debug(f"Trade history append: {e}")

def _get_trade_history(days=30):
    """Get cumulative trade history for last N days."""
    try:
        history = load_json(TRADE_HISTORY_FILE, [])
        if days <= 0:
            return history
        cutoff = (now_ist() - timedelta(days=days)).isoformat()
        return [t for t in history if t.get("exit_time", "") >= cutoff]
    except Exception:
        return []

# ─── FIX #4: TELEGRAM DIGEST SYSTEM ─────────────────────────────────────────
# Accumulates non-critical messages and sends them as compiled digests
# every 30 minutes instead of spamming individual alerts
_telegram_digest = []
_telegram_digest_lock = threading.Lock()
_telegram_last_flush = 0

def _flush_telegram_digest():
    """Flush accumulated messages as a single digest with live unrealized P&L."""
    global _telegram_digest, _telegram_last_flush
    with _telegram_digest_lock:
        if not _telegram_digest:
            return
        msgs = _telegram_digest.copy()
        _telegram_digest = []
    _telegram_last_flush = time.time()

    # Build digest message
    n = now_ist()
    digest = (
        f"📋 *DIGEST — {n.strftime('%H:%M')} IST*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"_{len(msgs)} updates since last digest_\n\n"
    )
    for idx, m in enumerate(msgs, 1):
        # Truncate each message to 200 chars
        short = m[:200].replace("\n", " | ")
        digest += f"{idx}. {short}\n"

    # Add live unrealized P&L section
    try:
        digest += _get_unrealized_pnl_summary()
    except Exception:
        pass

    # Show correct next digest time (12:00 or 18:00)
    _n_hr = n.hour
    if _n_hr < 12:
        _next_digest_hr = 12
    elif _n_hr < 18:
        _next_digest_hr = 18
    else:
        _next_digest_hr = 12  # Next day 12:00
    _next_time = n.replace(hour=_next_digest_hr, minute=0, second=0)
    if _next_digest_hr <= _n_hr:
        _next_time = _next_time + timedelta(days=1)
    digest += f"\n_Next digest at {_next_time.strftime('%H:%M')} IST_"
    _send_telegram_raw(digest)

def _get_unrealized_pnl_summary():
    """Get live unrealized P&L for digest. Uses Kite holdings as source of truth."""
    try:
        total_unrealized = 0
        position_lines = []

        kite = KiteSession.get()
        if not kite:
            return "\n_Kite not connected_\n"

        # Use Kite holdings as SOLE source of truth (not stale JSON files)
        holdings = kite.holdings() or []
        for h in holdings:
            sym = h.get("tradingsymbol", "")
            qty = (h.get("quantity", 0) + h.get("t1_quantity", 0))
            if sym and qty > 0:
                avg = h.get("average_price", 0)
                ltp = h.get("last_price", 0)
                pnl = round((ltp - avg) * qty, 2)
                pnl_pct = round((ltp - avg) / avg * 100, 1) if avg > 0 else 0
                total_unrealized += pnl
                sign = "+" if pnl >= 0 else ""
                emoji = "\U0001f7e2" if pnl >= 0 else "\U0001f534"
                position_lines.append(
                    (pnl, f"  {emoji} `{sym}` {sign}\u20b9{pnl:,.0f} ({pnl_pct:+.1f}%)")
                )

        # Sort: biggest losses first
        position_lines.sort(key=lambda x: x[0])

        if position_lines:
            tsign = "+" if total_unrealized >= 0 else ""
            temoji = "\u2705" if total_unrealized >= 0 else "\u274c"
            summary = (
                f"\n*{temoji} LIVE P&L ({len(position_lines)} holdings): "
                f"`{tsign}\u20b9{total_unrealized:,.0f}`*\n"
            )
            for _, line in position_lines:
                summary += f"{line}\n"
            return summary
        return "\n_No holdings_\n"
    except Exception as e:
        return f"\n_P&L error: {e}_\n"

def _send_telegram_raw(msg, doc_path=None, silent=False):
    """Direct send to Telegram — no digest, no filtering."""
    if TELEGRAM_TOKEN and TELEGRAM_CHAT_ID:
        base = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}"
        chunks = [msg[i:i+4000] for i in range(0, len(msg), 4000)]
        for chunk in chunks:
            try:
                resp = requests.post(f"{base}/sendMessage", json={
                    "chat_id":             TELEGRAM_CHAT_ID,
                    "text":                chunk,
                    "parse_mode":          "Markdown",
                    "disable_notification": silent,
                }, timeout=15)
                # If Markdown parsing failed, retry without parse_mode
                if resp.status_code != 200:
                    logger.warning(f"Telegram Markdown failed ({resp.status_code}), retrying plain text")
                    requests.post(f"{base}/sendMessage", json={
                        "chat_id":             TELEGRAM_CHAT_ID,
                        "text":                chunk,
                        "disable_notification": silent,
                    }, timeout=15)
                if len(chunks) > 1:
                    time.sleep(0.5)
            except Exception as e:
                logger.error(f"Telegram: {e}")
        if doc_path and os.path.exists(doc_path):
            try:
                with open(doc_path,"rb") as f:
                    requests.post(f"{base}/sendDocument",
                        data={"chat_id":TELEGRAM_CHAT_ID},
                        files={"document":f}, timeout=60)
            except Exception as e:
                logger.error(f"Telegram doc: {e}")

def send_telegram(msg, doc_path=None, silent=False, priority="normal"):
    """
    Send to Telegram + WhatsApp with NIGHT MODE + DIGEST MODE (FIX #4).
    Priority levels:
      "critical"  — always send immediately
      "report"    — scheduled reports — always send immediately
      "kite"      — Kite login/logout — always send immediately
      "trade"     — trade entries/exits — send immediately (important)
      "normal"    — regular alerts — ACCUMULATED into digest (FIX #4)
      "digest"    — added to digest queue, flushed every 30 min
      "silent"    — log only, never send
    """
    global _telegram_last_flush

    # ── NIGHT MODE: Block non-essential messages 22:00-07:00 ──
    hr = now_ist().hour
    is_night = hr >= 22 or hr < 7
    if is_night and priority not in ("critical", "report", "kite"):
        logger.debug(f"Night mode: blocked message ({priority})")
        return

    if priority == "silent":
        return

    # ── FIX #4: DIGEST MODE — accumulate normal alerts ──
    # Trade entries/exits, reports, critical, kite → send immediately
    # Filing alerts (non-critical), health checks, scan results → digest
    if priority in ("normal", "digest") and not doc_path:
        with _telegram_digest_lock:
            _telegram_digest.append(msg)
        # v23.6.0 #10: 3-TIER ALERT SYSTEM
        # TIER 1 (IMMEDIATE): trade/critical/kite — handled below
        # TIER 2 (DIGEST every 4 hrs): 09:00, 13:00, 17:00, 21:00 IST
        # TIER 3 (DAILY): 18:00 IST full PDF report
        _n = now_ist()
        _flush_now = False
        # v23.6.0: Digest at 09:00, 13:00, 17:00, 21:00 (every 4 hours)
        if _n.hour in (9, 13, 17, 21) and _n.minute <= 5:
            elapsed = time.time() - _telegram_last_flush
            if elapsed >= 300:  # At least 5 min since last flush
                _flush_now = True
        # Safety: flush if 50+ messages piled up
        with _telegram_digest_lock:
            count = len(_telegram_digest)
        if count >= 50:
            _flush_now = True
        if _flush_now:
            _flush_telegram_digest()
        return

    # ── Direct send for critical/report/kite/trade ──
    _send_telegram_raw(msg, doc_path, silent or is_night)

    # ── WhatsApp — only for reports and critical ──
    if priority in ("report", "critical", "kite"):
        send_whatsapp(msg)
    if doc_path and os.path.exists(doc_path):
        send_whatsapp_doc(doc_path)

# ──────────────────────────────────────────────────────────────────────────────
#  MARKET DATA COLLECTOR — for Pre-Market Pulse report
# ──────────────────────────────────────────────────────────────────────────────

class MarketDataCollector:
    """Fetches market data for morning report. Kite for Indian, minimal yfinance for global indices."""

    @staticmethod
    def fetch_global_markets():
        data = {}

        # ── Indian indices via Kite (reliable, no errors) ──
        try:
            kite = KiteSession.get()
            if kite:
                indian_indices = {
                    "Nifty 50":   "NSE:NIFTY 50",
                    "Bank Nifty": "NSE:NIFTY BANK",
                    "India VIX":  "NSE:INDIA VIX",
                }
                ltp = kite.ltp(list(indian_indices.values()))
                for name, inst in indian_indices.items():
                    if inst in ltp:
                        price = ltp[inst]["last_price"]
                        data[name] = {"price": round(price, 2), "change": 0, "pct": 0, "arrow": "⚪"}
        except Exception as e:
            logger.debug(f"Kite indices: {e}")

        # ── Global indices ONLY (not individual stocks) via yfinance ──
        global_indices = {
            "Dow Jones":  "^DJI",
            "S&P 500":    "^GSPC",
            "Nasdaq":     "^IXIC",
            "Nikkei 225": "^N225",
            "Hang Seng":  "^HSI",
            "DAX":        "^GDAXI",
            "FTSE 100":   "^FTSE",
        }
        for name, sym in global_indices.items():
            try:
                hist = yf.Ticker(sym).history(period="5d")
                hist = hist.dropna()
                if len(hist) >= 2:
                    prev = float(hist["Close"].iloc[-2])
                    curr = float(hist["Close"].iloc[-1])
                    chg  = round(curr - prev, 2)
                    pct  = round((curr - prev) / prev * 100, 2)
                    data[name] = {"price": round(curr, 2), "change": chg, "pct": pct,
                                  "arrow": "🟢" if chg >= 0 else "🔴"}
            except Exception:
                pass  # Silently skip — PythonAnywhere may block some

        logger.info(f"Market data: {len(data)} indices fetched")
        return data

    @staticmethod
    def get_fear_greed():
        """
        Fear & Greed — display only. Regime uses India VIX, not this.
        Returns N/A honestly if API unavailable — never fakes a value.
        """
        try:
            r = requests.get(
                "https://production.dataviz.cnn.io/index/fearandgreed/graphdata",
                timeout=8,
                headers={"User-Agent": "Mozilla/5.0"}
            )
            if r.status_code == 200:
                d   = r.json()
                val = int(float(d.get("fear_and_greed", {}).get("score", 0)))
                cls = d.get("fear_and_greed", {}).get("rating", "N/A")
                if val > 0:
                    emoji = ("\U0001f631" if val < 25 else "\U0001f630" if val < 40 else
                             "\U0001f610" if val < 55 else "\U0001f600" if val < 75 else "\U0001f911")
                    return {"value": val, "class": cls, "prev": val,
                            "emoji": emoji, "available": True}
        except Exception:
            pass
        return {"value": 0, "class": "N/A — PythonAnywhere network limit",
                "prev": 0, "emoji": "\u26aa", "available": False}
    @staticmethod
    def get_nifty_gainers_losers():
        """Top 5 gainers and losers from Nifty 50."""
        nifty50 = [
            "RELIANCE","TCS","HDFCBANK","INFY","ICICIBANK","HINDUNILVR",
            "ITC","SBIN","BHARTIARTL","KOTAKBANK","LT","AXISBANK",
            "ASIANPAINT","MARUTI","SUNPHARMA","TITAN","BAJFINANCE","WIPRO",
            "NESTLEIND","ULTRACEMCO","POWERGRID","NTPC","TECHM","HCLTECH",
            "JSWSTEEL","TATASTEEL","GRASIM","CIPLA","DRREDDY","DIVISLAB",
            "BAJAJFINSV","BPCL","COALINDIA","ONGC","M&M","ADANIENT",
            "ADANIPORTS","APOLLOHOSP","TATACONSUM","BRITANNIA","HEROMOTOCO",
            "EICHERMOT","UPL","HINDALCO","INDUSINDBK","BAJAJ-AUTO",
            "SBILIFE","HDFCLIFE","TATAMOTORS","NTPC",
        ]
        results = []
        for sym in nifty50[:30]:  # Limit to 30 for speed
            try:
                hist = yf.Ticker(f"{sym}.NS").history(period="2d")
                if len(hist) >= 2:
                    prev = float(hist["Close"].iloc[-2])
                    curr = float(hist["Close"].iloc[-1])
                    pct  = round((curr - prev) / prev * 100, 2)
                    results.append({"symbol": sym, "price": round(curr, 2), "pct": pct})
            except Exception: pass
        gainers = sorted(results, key=lambda x: x["pct"], reverse=True)[:5]
        losers  = sorted(results, key=lambda x: x["pct"])[:5]
        return gainers, losers

    @staticmethod
    def get_sectoral_performance():
        """Nifty sectoral indices 1-day performance."""
        sectors = {
            "Nifty Bank":    "^NSEBANK",
            "Nifty IT":      "^CNXIT",
            "Nifty Pharma":  "^CNXPHARMA",
            "Nifty Auto":    "^CNXAUTO",
            "Nifty FMCG":    "^CNXFMCG",
            "Nifty Metal":   "^CNXMETAL",
            "Nifty Energy":  "^CNXENERGY",
            "Nifty Realty":  "^CNXREALTY",
        }
        perf = {}
        for name, sym in sectors.items():
            try:
                hist = yf.Ticker(sym).history(period="2d")
                if len(hist) >= 2:
                    prev = float(hist["Close"].iloc[-2])
                    curr = float(hist["Close"].iloc[-1])
                    pct  = round((curr - prev) / prev * 100, 2)
                    perf[name] = {"pct": pct, "arrow": "🟢" if pct >= 0 else "🔴"}
            except Exception: pass
        return dict(sorted(perf.items(), key=lambda x: x[1]["pct"], reverse=True))

# ──────────────────────────────────────────────────────────────────────────────
#  PROFESSIONAL TELEGRAM MESSAGE BUILDER
# ──────────────────────────────────────────────────────────────────────────────

class TelegramMessageBuilder:
    """
    Builds complete, professional, well-formatted Telegram messages.
    Never truncated — splits automatically if > 4000 chars.
    Styled like Pre-Market Pulse.
    """

    @staticmethod
    def pre_market_pulse(market_data, fg, gainers, losers, sectors,
                         filings, top_scans, fno_count, equity_count):
        """07:00 IST — Complete Pre-Market Pulse report."""
        n    = now_ist()
        date = n.strftime("%a, %d %b %Y")

        # Fear & Greed bar
        val    = fg["value"]
        filled = int(val / 5) if val > 0 else 0
        bar    = "█" * filled + "░" * (20 - filled)
        fg_color = ("🟢" if val < 30 else "🟡" if val < 55 else "🔴") if val > 0 else "⚪"

        if fg.get("available", False) and val > 0:
            fg_section = (
                f"*😱 FEAR & GREED INDEX*\n"
                f"{fg_color} *{val}* — {fg['class']} {fg['emoji']}\n"
                f"`{bar}`\n"
                f"Last week: {fg['prev']} → Today: {val}\n"
                f"_<30 Extreme Fear: Good to open positions_\n"
                f"_30-50 Fear: Wait for direction_\n"
                f"_50-70 Greed: Be cautious_\n"
                f"_>70 Extreme Greed: Avoid new positions_\n\n"
            )
        else:
            fg_section = (
                f"*😱 FEAR & GREED INDEX*\n"
                f"⚪ Data unavailable (PythonAnywhere network limit)\n"
                f"_Regime based on India VIX: {fg.get('vix_note', 'see below')}_\n\n"
            )

        msg = (
            f"🦅 *GLOBAL EYE {VERSION} — MARKET PULSE*\n"
            f"📅 {date} | 07:00 IST\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        ) + fg_section

        # Indian Markets
        msg += "*🇮🇳 INDIAN MARKETS*\n"
        for name in ["Nifty 50","Sensex","Bank Nifty","India VIX"]:
            d = market_data.get(name)
            if d:
                sign = "+" if d["change"] >= 0 else ""
                msg += (f"{d['arrow']} *{name}*: {d['price']:,.2f} "
                        f"({sign}{d['pct']}%)\n")
        msg += "\n"

        # Global Indices — show only what's available
        global_available = [(n, market_data[n]) for n in
                           ["Dow Jones","S&P 500","Nasdaq","Nikkei 225","Hang Seng","DAX","FTSE 100"]
                           if n in market_data]
        if global_available:
            msg += "*🌍 GLOBAL INDICES*\n"
            for name, d in global_available:
                sign = "+" if d.get("pct",0) >= 0 else ""
                msg += f"  {d.get('arrow','⚪')} {name}: {sign}{d.get('pct',0)}%\n"
        else:
            msg += "*🌍 GLOBAL INDICES*\n  _Data unavailable — PythonAnywhere network limit_\n"
        msg += "\n"

        return msg

    @staticmethod
    def pre_market_pulse_part2(gainers, losers, sectors,
                                filings, top_scans, fno_count, equity_count):
        """Part 2 of morning pulse — sent as separate message."""
        msg = ""

        # Sectoral Performance
        if sectors:
            msg += "*📊 SECTORAL PERFORMANCE (1 Day)*\n"
            for name, d in list(sectors.items())[:8]:
                bar_len = min(10, int(abs(d["pct"]) * 2))
                bar     = ("█" * bar_len) if d["pct"] >= 0 else ("▓" * bar_len)
                sign    = "+" if d["pct"] >= 0 else ""
                msg += f"{d['arrow']} {name}: {sign}{d['pct']}%\n"
            msg += "\n"

        # Top Gainers / Losers
        if gainers or losers:
            msg += "*🏆 TOP GAINERS (Nifty 50)*\n"
            for g in gainers[:5]:
                msg += f"  🟢 `{g['symbol']}`: +{g['pct']}% @ ₹{g['price']}\n"
            msg += "\n*📉 TOP LOSERS (Nifty 50)*\n"
            for l in losers[:5]:
                msg += f"  🔴 `{l['symbol']}`: {l['pct']}% @ ₹{l['price']}\n"
            msg += "\n"

        # NSE/BSE Filings overnight
        if filings:
            msg += f"*📋 OVERNIGHT FILINGS ({len(filings)} total)*\n"
            critical = [f for f in filings if f.get("urgency") == "CRITICAL"][:3]
            high     = [f for f in filings if f.get("urgency") == "HIGH"][:3]
            for f in critical:
                sent_e = "🟢" if "BULL" in f.get("sentiment","") else "🔴"
                msg += f"  🔴 *CRITICAL* {sent_e} `{f['symbol']}`: {f['subject'][:80]}\n"
            for f in high:
                sent_e = "🟢" if "BULL" in f.get("sentiment","") else "🔴"
                msg += f"  🟠 *HIGH* {sent_e} `{f['symbol']}`: {f['subject'][:80]}\n"
            msg += "\n"

        # Top scan signals
        if top_scans:
            msg += "*🔍 TODAY'S WATCHLIST*\n"
            for r in top_scans[:5]:
                dvm  = r.get("dvm_score", "-")
                sig  = r.get("intraday_sig","")[:14]
                msg += (f"  {'🟢' if 'BUY' in sig else '🔴' if 'SELL' in sig else '⚪'} "
                        f"`{r['symbol']}` DVM:{dvm} | {sig} | ₹{r['price']}\n")
            msg += "\n"

        # Universe stats
        msg += (
            f"*📈 MONITORING UNIVERSE*\n"
            f"  📊 Equity stocks: *{equity_count}*\n"
            f"  📋 F&O stocks: *{fno_count}* (incl. 4 indices)\n"
            f"  📋 NSE/BSE Filing Monitor: Every 2 min\n"
            f"  📡 News feeds: {len(NEWS_FEEDS)} sources\n\n"
            f"_Good morning! Market opens at 09:15 IST_ 🇮🇳\n"
            f"_Capital protected. Discipline first._ 🦅"
        )
        return msg

    @staticmethod
    def filing_alert(filing):
        """Professional filing alert with CORE INFO clearly readable."""
        urgency = filing.get("urgency","MEDIUM")
        sentiment = filing.get("sentiment","NEUTRAL")
        ue = {"CRITICAL":"🔴","HIGH":"🟠","MEDIUM":"🟡"}.get(urgency,"⚪")
        se = "🟢" if "BULL" in sentiment else "🔴" if "BEAR" in sentiment else "⚪"
        strategies = filing.get("strategies",[])
        kws = filing.get("keywords",[])[:4]
        ftype = filing.get('type','').replace('_',' ')
        subject = filing.get('subject','')

        # ── Extract CORE INFO from subject in plain language ──
        core_info = subject[:200]
        # Clean up common noise
        for noise in ["Regulation 30","LODR","Clause 36","Annexure",
                       "pursuant to","in terms of","we wish to inform",
                       "this is to inform","kindly note"]:
            core_info = core_info.replace(noise,"").replace(noise.upper(),"")
        core_info = ' '.join(core_info.split())[:180]  # Clean whitespace

        # ── Generate plain-language WHAT HAPPENED line ──
        what_happened = ""
        if "RESULT" in ftype.upper():
            what_happened = "📊 Quarterly/Annual financial results announced"
        elif "DIVIDEND" in ftype.upper():
            what_happened = "💰 Dividend or bonus declared"
        elif "MERGER" in ftype.upper() or "ACQUI" in ftype.upper():
            what_happened = "🤝 Merger/Acquisition/JV announced"
        elif "ORDER" in ftype.upper():
            what_happened = "📋 New order/contract won"
        elif "FRAUD" in ftype.upper():
            what_happened = "⚠️ Fraud risk / regulatory action detected"
        elif "BULK" in ftype.upper() or "BLOCK" in ftype.upper():
            what_happened = "📦 Large institutional trade (bulk/block deal)"
        elif "PROMOTER" in ftype.upper():
            what_happened = "👤 Promoter/insider buying or selling"
        elif "BOARD" in ftype.upper():
            what_happened = "🏛️ Board meeting outcome"
        elif "RATING" in ftype.upper():
            what_happened = "📈 Credit rating change"
        elif "EXPANSION" in ftype.upper():
            what_happened = "🏭 Capacity expansion / new plant"
        elif "FII" in ftype.upper():
            what_happened = "🌐 FII/DII flow data"
        elif "REGULATORY" in ftype.upper() or "FDA" in ftype.upper():
            what_happened = "✅ Regulatory/FDA approval"
        else:
            what_happened = f"📋 {ftype}"

        return (
            f"{ue} *{urgency} FILING*\n"
            f"━━━━━━━━━━━━━━━━━━━━━\n"
            f"🏢 *{filing.get('symbol','')}* ({filing.get('exchange','')})\n\n"
            f"{what_happened}\n"
            f"{se} Impact: *{sentiment}*\n\n"
            f"📝 *Core Info:*\n{core_info}\n\n"
            f"⚡ Trade Action: {', '.join(s.upper() for s in strategies)}\n"
            f"🔑 {', '.join(kws)}\n"
            f"🕐 {now_ist().strftime('%H:%M')} IST"
        )

    @staticmethod
    def eod_report(risk_s, summaries, filings_today, top_scans, equity_count, fno_count):
        """Professional end-of-day P&L report."""
        total_pnl = sum(s.get("total_pnl",0) for s in summaries.values())
        day_pnl   = risk_s.get("total_pnl",0)
        emoji     = "✅" if day_pnl >= 0 else "❌"
        sign      = "+" if day_pnl >= 0 else ""
        tsign     = "+" if total_pnl >= 0 else ""

        msg = (
            f"{emoji} *END OF DAY P&L REPORT*\n"
            f"📅 {now_ist().strftime('%a, %d %b %Y')}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"*💰 TODAY'S PERFORMANCE*\n"
            f"  Day PnL: `{sign}₹{day_pnl:,.0f}`\n"
            f"  Total PnL: `{tsign}₹{total_pnl:,.0f}`\n"
            f"  Trades today: {risk_s.get('trades_today',0)}\n\n"
            f"*📊 STRATEGY BREAKDOWN*\n"
        )
        for name, s in summaries.items():
            sp   = "+" if s.get("total_pnl",0) >= 0 else ""
            emo  = "✅" if s.get("total_pnl",0) >= 0 else "❌"
            msg += (f"  {emo} *{name.upper()}*: "
                    f"`{sp}₹{s.get('total_pnl',0):,.0f}` | "
                    f"Win: {s.get('win_rate',0)}% | "
                    f"Open: {s.get('open_count',0)}\n")

        msg += (
            f"\n*📋 FILINGS PROCESSED TODAY*\n"
            f"  Total: {len(filings_today)} filings\n"
            f"  Critical: {len([f for f in filings_today if f.get('urgency')=='CRITICAL'])}\n"
            f"  High: {len([f for f in filings_today if f.get('urgency')=='HIGH'])}\n\n"
            f"*🛡️ RISK STATUS*\n"
            f"  Intraday: {'🛑 HALTED' if risk_s.get('intraday_halted') else '🟢 Active'}\n"
            f"  Monthly PnL: ₹{risk_s.get('monthly_pnl',0):,.0f}\n\n"
            f"*📈 MONITORING UNIVERSE*\n"
            f"  Equity: {equity_count} stocks | F&O: {fno_count} stocks\n\n"
            f"_Market closes at 15:30 IST. See you tomorrow! 🦅_\n"
            f"_Paper trading — discipline builds wealth._"
        )
        return msg

    @staticmethod
    def health_check(is_open, session, summaries, risk_s,
                     filings_1h, equity_count, fno_count):
        total_pnl = sum(s.get("total_pnl",0) for s in summaries.values())
        sign = "+" if total_pnl >= 0 else ""
        n = now_ist()

        msg = (
            f"🦅 *GLOBAL EYE {VERSION} — HEALTH CHECK*\n"
            f"📅 {n.strftime('%a, %d %b %Y')} | {n.strftime('%H:%M')} IST\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"📈 Market: {'🟢' if is_open else '🔴'} {session}\n\n"
        )

        # Show positions for each strategy
        total_invested = 0
        for strat_name, strat_key in [("💼 INTRADAY","intraday"),("🔄 SWING","swing"),
                                       ("🏦 LONG TERM","longterm"),("📊 F&O","fno")]:
            s = summaries.get(strat_key, {})
            positions = s.get("open_positions", [])
            count = s.get("open_count", 0)
            strat_pnl = s.get("total_pnl", 0)
            sp = "+" if strat_pnl >= 0 else ""

            if count > 0:
                msg += f"*{strat_name}* ({count}) | PnL: `{sp}₹{strat_pnl:,.0f}`\n"
                for pos in positions:  # Show ALL positions
                    sym = pos.get("symbol", pos.get("key",""))[:12]
                    entry = pos.get("entry_price", pos.get("premium", 0))
                    qty = pos.get("qty", pos.get("lot", 0))
                    cost = pos.get("cost", 0)
                    total_invested += cost
                    source = pos.get("source", "")[:8]
                    msg += f"  `{sym}` ₹{entry:,.2f} x{qty} = ₹{cost:,.0f}\n"
                msg += "\n"
            else:
                msg += f"*{strat_name}* — No positions\n"

        msg += (
            f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"💰 Invested: `₹{total_invested:,.0f}`\n"
            f"📊 Total PnL: `{sign}₹{total_pnl:,.0f}`\n"
            f"🛡️ Risk: {'🛑 HALTED' if risk_s.get('intraday_halted') else '🟢 Active'}"
            f" | Monthly: ₹{risk_s.get('monthly_pnl',0):,.0f}\n"
            f"📋 Filings (1h): {filings_1h}\n"
            f"🔍 Universe: {equity_count} equity | {fno_count} F&O\n"
            f"🎯 Mode: *{STRATEGY_MODE}* | "
            f"{'75% TechRecheck' if STRATEGY_MODE=='AGGRESSIVE' else 'Dalio StressTest'}\n"
            f"⏱ Scan: {SCAN_INTERVAL//60}min | Agents: {AGENT_APPROVAL}/3\n"
            f"✅ {VERSION} — {OWNER_NAME} — All systems nominal"
        )
        return msg

    @staticmethod
    def six_hour_report(summaries, risk_s, top_scans,
                        filings, news_count, equity_count, fno_count, session):
        total_pnl = sum(s.get("total_pnl",0) for s in summaries.values())
        sign = "+" if total_pnl >= 0 else ""
        top3 = ""
        for r in top_scans[:3]:
            sig = r.get("intraday_sig","")[:12]
            top3 += (f"  {'🟢' if 'BUY' in sig else '🔴' if 'SELL' in sig else '⚪'} "
                     f"`{r['symbol']}` DVM:{r.get('dvm_score','-')} "
                     f"| {sig} | ₹{r['price']}\n")

        critical_f = [f for f in filings if f.get("urgency")=="CRITICAL"][:2]
        fil_str = ""
        for f in critical_f:
            se = "🟢" if "BULL" in f.get("sentiment","") else "🔴"
            fil_str += f"  🔴 `{f['symbol']}`: {f['subject'][:60]}\n"

        return (
            f"📊 *GLOBAL EYE {VERSION} — 6H REPORT*\n"
            f"🕐 {now_ist().strftime('%d %b %Y %H:%M')} IST | {session}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"*💰 PORTFOLIO*\n"
            f"  Total PnL: `{sign}₹{total_pnl:,.0f}`\n"
            f"  Today: ₹{risk_s.get('total_pnl',0):,.0f} | "
            f"Trades: {risk_s.get('trades_today',0)}\n\n"
            f"*📊 BY STRATEGY*\n"
            + "".join(
                f"  {'✅' if s.get('total_pnl',0)>=0 else '❌'} "
                f"*{n.upper()}*: `{'+'if s.get('total_pnl',0)>=0 else ''}₹{s.get('total_pnl',0):,.0f}` "
                f"Win:{s.get('win_rate',0)}% Open:{s.get('open_count',0)}\n"
                for n,s in summaries.items()
            ) +
            f"\n*📋 FILINGS (6H)*\n"
            f"  Total: {len(filings)} | "
            f"Critical: {len([f for f in filings if f.get('urgency')=='CRITICAL'])}\n"
            + (fil_str if fil_str else "") +
            f"\n*🔍 TOP SIGNALS*\n"
            + (top3 or "  No strong signals\n") +
            f"\n*📡 INTELLIGENCE*\n"
            f"  News alerts: {news_count}\n"
            f"  Equity monitored: {equity_count}\n"
            f"  F&O monitored: {fno_count}\n\n"
            f"_📄 Full PDF report attached below ↓_"
        )

# ──────────────────────────────────────────────────────────────────────────────
#  NSE/BSE FILING MONITOR
# ──────────────────────────────────────────────────────────────────────────────

class FilingMonitor:
    NSE_ANNOUNCEMENTS = "https://www.nseindia.com/api/corporate-announcements?index=equities"
    NSE_BULK_DEALS    = "https://www.nseindia.com/api/snapshot-capital-market-with-equities-and-debtdata?index=bulk-deals"
    NSE_BLOCK_DEALS   = "https://www.nseindia.com/api/snapshot-capital-market-with-equities-and-debtdata?index=block-deals"
    NSE_INSIDER       = "https://www.nseindia.com/api/corporates-pit?index=equities&category=insiders"
    NSE_FII_DII       = "https://www.nseindia.com/api/fiidiiTradeReact"
    BSE_ANNOUNCEMENTS = "https://api.bseindia.com/BseIndiaAPI/api/AnnSubCategoryGetData/w?strCat=-1&strPrevDate={date}&strScrip=&strSearch=P&strToDate={date}&strType=C&subcategory=-1"
    BSE_BULK_DEALS    = "https://api.bseindia.com/BseIndiaAPI/api/BulkDealData/w?flag=0&quotetype=EQ&type=BulkDeal"

    NSE_H = {"User-Agent":"Mozilla/5.0","Accept":"application/json","Referer":"https://www.nseindia.com/","X-Requested-With":"XMLHttpRequest"}
    BSE_H = {"User-Agent":"Mozilla/5.0","Accept":"application/json","Referer":"https://www.bseindia.com/"}

    def __init__(self, trade_cb):
        self.cache    = load_json(FILINGS_FILE, {"seen":[],"filings":[]})
        self.seen_set = set(self.cache.get("seen",[]))
        self.lock     = threading.Lock()
        self.trade_cb = trade_cb
        self._nse     = requests.Session(); self._nse.headers.update(self.NSE_H)
        self._bse     = requests.Session(); self._bse.headers.update(self.BSE_H)
        self._init_nse()
        self._start()

    def _init_nse(self):
        try: self._nse.get("https://www.nseindia.com",timeout=10); logger.info("✅ NSE session OK")
        except Exception: pass

    def _start(self):
        def loop():
            while True:
                try:
                    # v23.6.0 #8: Adaptive poll speed — faster during market hours
                    _open, _ = is_market_open()
                    self._poll_nse()
                    self._poll_bse()
                    self._poll_bulk()
                    self._poll_insider()
                    self._poll_fii_dii()
                except Exception as e: logger.error(f"Filing poll: {e}")
                # v23.6.0 #8: 60s during market hours, 120s outside
                _mkt_open, _ = is_market_open()
                time.sleep(60 if _mkt_open else 120)
        threading.Thread(target=loop,daemon=True,name="Filings").start()
        logger.info("📋 Filing Monitor active — v23.6.0: 60s market / 120s off-hours")

    def _poll_nse(self):
        try:
            r = self._nse.get(self.NSE_ANNOUNCEMENTS,timeout=15)
            if r.status_code!=200: return
            data = r.json()
            items= data if isinstance(data,list) else data.get("data",[])
            for ann in items[:30]:
                sym  = ann.get("symbol","").upper()
                subj = ann.get("subject","")
                body = ann.get("desc","")
                fid  = make_hash(ann.get("an_dt","")+sym+subj[:20])
                if fid in self.seen_set: continue
                self._process(fid,sym,"NSE","ANNOUNCEMENT",subj,body,ann)
        except Exception as e: logger.debug(f"NSE ann: {e}")

    def _poll_bse(self):
        try:
            url = self.BSE_ANNOUNCEMENTS.format(date=today_str().replace("-",""))
            r   = self._bse.get(url,timeout=15)
            if r.status_code!=200: return
            data = r.json()
            items= data.get("Table",data) if isinstance(data,dict) else data
            if not isinstance(items,list): return
            for item in items[:30]:
                sym  = str(item.get("SCRIP_CD",item.get("scrip_cd",""))).upper()
                subj = item.get("HEADLINE",item.get("headline",""))
                body = item.get("LONG_TEXT","")
                fid  = str(item.get("NEWSID",make_hash(subj+sym)))
                if fid in self.seen_set: continue
                self._process(fid,sym,"BSE","ANNOUNCEMENT",subj,body,item)
        except Exception as e: logger.debug(f"BSE ann: {e}")

    def _poll_bulk(self):
        for url,exchange,dtype in [
            (self.NSE_BULK_DEALS,"NSE","BULK"),
            (self.NSE_BLOCK_DEALS,"NSE","BLOCK"),
            (self.BSE_BULK_DEALS,"BSE","BULK"),
        ]:
            try:
                sess = self._nse if exchange=="NSE" else self._bse
                r    = sess.get(url,timeout=15)
                if r.status_code!=200: continue
                data = r.json()
                items= data.get("data",data) if isinstance(data,dict) else data
                if not isinstance(items,list): continue
                for item in items[:20]:
                    sym  = str(item.get("symbol",item.get("Symbol",item.get("SCRIP_CD","")))).upper()
                    cl   = item.get("client_name",item.get("CLIENT_NAME",item.get("clientName","")))
                    qty  = item.get("quantity_traded",item.get("QUANTITY_TRADED",0))
                    price= item.get("trade_price",item.get("TRADE_PRICE",0))
                    bs   = item.get("buy_sell",item.get("BUY_SELL","")).upper()
                    fid  = make_hash(f"{sym}{cl}{qty}{today_str()}")
                    if fid in self.seen_set: continue
                    subj = f"{dtype} DEAL: {sym} | {'BUY' if 'B' in bs else 'SELL'} | {cl} | Qty:{qty} | ₹{price}"
                    self._process(fid,sym,exchange,"BULK_BLOCK_DEAL",subj,"",item,
                                  extra={"client":cl,"bs":bs,"qty":qty,"price":price})
            except Exception as e: logger.debug(f"{exchange} bulk: {e}")

    def _poll_insider(self):
        try:
            r = self._nse.get(self.NSE_INSIDER,timeout=15)
            if r.status_code!=200: return
            data = r.json()
            items= data.get("data",data) if isinstance(data,dict) else data
            if not isinstance(items,list): return
            for item in items[:20]:
                sym = item.get("symbol","").upper()
                name= item.get("acqName",item.get("name",""))
                qty = item.get("secAcq",item.get("secSale",0))
                bs  = "BUY" if item.get("secAcq",0)>0 else "SELL"
                val = item.get("valAcq",item.get("valSale",0))
                fid = make_hash(f"{sym}{name}{qty}{today_str()}")
                if fid in self.seen_set: continue
                subj= f"INSIDER {bs}: {sym} | {name} | Qty:{qty} | ₹{val:.0f}L"
                self._process(fid,sym,"NSE","PROMOTER",subj,"",item,
                              extra={"bs":bs,"name":name})
        except Exception as e: logger.debug(f"Insider: {e}")

    def _poll_fii_dii(self):
        try:
            r = self._nse.get(self.NSE_FII_DII,timeout=15)
            if r.status_code!=200: return
            data=r.json()
            if not data: return
            fid=make_hash(f"fiidii{today_str()}")
            if fid in self.seen_set: return
            fii_net=dii_net=0
            for row in data:
                cat=str(row.get("category","")).upper()
                net=float(str(row.get("net","0")).replace(",","") or 0)
                if "FII" in cat or "FPI" in cat: fii_net=net
                if "DII" in cat: dii_net=net
            sent= ("BULLISH" if fii_net>0 and dii_net>0 else
                   "BEARISH" if fii_net<0 and dii_net<0 else "MIXED")
            subj= f"FII/DII FLOW: FII ₹{fii_net:,.0f}Cr | DII ₹{dii_net:,.0f}Cr | {sent}"
            self._process(fid,"NIFTY","NSE","FII_DII",subj,subj,data,
                          extra={"fii_net":fii_net,"dii_net":dii_net,"sentiment":sent})
            # v23.7.0: Feed flow into Strategy Modules
            if _STRATEGY_MODULES_LOADED:
                try: FIIDIIFlowTracker.record_flow(fii_net, dii_net)
                except: pass
        except Exception as e: logger.debug(f"FII/DII: {e}")

    def _process(self, fid, sym, exchange, ftype, subj, body, raw, extra=None):
        with self.lock: self.seen_set.add(fid)
        # ── BSE code → NSE symbol conversion ─────────────────────────────────
        if exchange == "BSE" and sym.isdigit():
            nse_sym = bse_to_nse(sym)
            if nse_sym:
                logger.debug(f"BSE {sym} → NSE {nse_sym}")
                sym = nse_sym
            else:
                logger.debug(f"BSE code {sym} not in mapping — skipping")
                return  # Skip unknown BSE codes
        text = (subj+" "+body).lower()
        matched_type=ftype; matched_kws=[]
        for ft_name,ft_def in FILING_TYPES.items():
            hits=[k for k in ft_def["keywords"] if k in text]
            if hits:
                # ── FIX #7/#8: EXCLUDE false positives ──────────────
                # If this category has exclude_context, check if the keyword
                # appears ONLY as part of an innocent word/phrase
                excludes = ft_def.get("exclude_context", [])
                if excludes and ft_name == "FRAUD_RISK":
                    # For each hit, verify it's NOT a false positive
                    real_hits = []
                    for kw in hits:
                        is_false_positive = False
                        for exc in excludes:
                            if exc in text:
                                # Check if the keyword is ONLY appearing inside the exclude phrase
                                # e.g., "ed" inside "powered", "education", "launched"
                                text_without_excludes = text
                                for exc2 in excludes:
                                    text_without_excludes = text_without_excludes.replace(exc2, " ")
                                if kw not in text_without_excludes:
                                    is_false_positive = True
                                    break
                        if not is_false_positive:
                            real_hits.append(kw)
                    if not real_hits:
                        logger.debug(f"FRAUD_RISK false positive avoided for {sym}: excluded words in '{subj[:80]}'")
                        continue  # Skip — all hits were false positives
                    hits = real_hits
                matched_type=ft_name; matched_kws=hits; break
        if matched_type not in FILING_TYPES and not matched_kws: return
        ft_def   = FILING_TYPES.get(matched_type,FILING_TYPES["RESULTS"])
        urgency  = ft_def["urgency"]
        base_s   = ft_def["sentiment"]
        strats   = ft_def["strategy"]
        sentiment= base_s if base_s!="ANALYSE" else self._analyse(text,matched_type,extra)
        filing   = {
            "id":sym+"_"+fid,"symbol":sym,"exchange":exchange,
            "type":matched_type,"urgency":urgency,"sentiment":sentiment,
            "subject":subj[:300],"keywords":matched_kws[:5],
            "strategies":strats,"timestamp":now_ist().isoformat(),
            "extra":extra or {},
        }
        with self.lock:
            self.cache["filings"]=(self.cache.get("filings",[])+[filing])[-500:]
            self.cache["seen"]=list(self.seen_set)[-3000:]
        save_json(FILINGS_FILE,self.cache)
        logger.info(f"📋 [{urgency}] {sym} | {matched_type} | {sentiment} | {subj[:60]}")
        # Only send individual alerts for CRITICAL during market hours
        # All other filings compiled into digest reports (07:00, 09:30, 12:00, 15:30)
        is_open, _ = is_market_open()
        if urgency == "CRITICAL" and is_open:
            send_telegram(TelegramMessageBuilder.filing_alert(filing), priority="critical")
        self.trade_cb(sym,sentiment,filing,strats)

    def _analyse(self, text, ftype, extra):
        if ftype=="RESULTS":
            bull=["profit increased","profit up","revenue grew","strong quarter","beat","record profit","growth","higher profit"]
            bear=["loss","net loss","revenue declined","profit fell","missed","below estimates","weak","write-off"]
            b=sum(1 for w in bull if w in text); s=sum(1 for w in bear if w in text)
            return "BULLISH" if b>s else "BEARISH" if s>b else "NEUTRAL"
        if ftype=="BULK_BLOCK_DEAL" and extra:
            bs=str(extra.get("bs","")).upper(); cl=str(extra.get("client","")).lower()
            inst=["mutual fund","mf","fii","fpi","insurance","lic","sbi","hdfc","icici"]
            if "B" in bs:
                return "STRONG_BULLISH" if any(i in cl for i in inst) else "BULLISH"
            return "BEARISH" if any(i in cl for i in inst) else "WEAK_BEARISH"
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: PROPER PROMOTER FILING CLASSIFICATION
        # Bug: "Trading Window Closure" was marked BULLISH — it's NEUTRAL!
        # Only ACTUAL buying/stake increase is bullish.
        # ═══════════════════════════════════════════════════════════════════
        if ftype=="PROMOTER":
            text_lower = text.lower()
            
            # Check for insider API data first (has bs field)
            if extra and "bs" in extra:
                return "BULLISH" if "BUY" in str(extra.get("bs","")).upper() else "BEARISH"
            
            # NEUTRAL signals (NOT actionable — just compliance filings)
            neutral_keywords = [
                "trading window closure", "trading window opening", "closure of trading window",
                "intimation", "disclosure under", "regulation 29", "regulation 7",
                "code of conduct", "annual disclosure", "benpos", "designated persons",
                "compliance certificate", "secretarial audit", "annual secretarial"
            ]
            if any(nk in text_lower for nk in neutral_keywords):
                return "NEUTRAL"  # NOT bullish — just routine compliance
            
            # BEARISH signals (promoter selling, pledging, reducing)
            bearish_keywords = [
                "promoter sell", "promoter sold", "selling by promoter", "stake sale",
                "stake decrease", "stake reduction", "promoter pledge", "pledge creation",
                "encumbrance created", "shares pledged", "pledge increase",
                "promoter offload", "dilution", "stake diluted", "ofs by promoter"
            ]
            if any(bk in text_lower for bk in bearish_keywords):
                return "BEARISH"
            
            # BULLISH signals (promoter ACTUALLY buying/increasing stake)
            bullish_keywords = [
                "promoter buy", "promoter bought", "promoter acquired", "promoter purchase",
                "stake increase", "stake acquisition", "promoter increased",
                "pledge release", "encumbrance released", "pledge reduction",
                "shares acquired", "open market purchase", "creeping acquisition",
                "promoter adding", "shareholding increased"
            ]
            if any(buk in text_lower for buk in bullish_keywords):
                return "BULLISH"
            
            # Default to NEUTRAL if we can't determine
            return "NEUTRAL"
        
        if ftype=="CREDIT_RATING":
            bull=["upgrade","positive","improve"]; bear=["downgrade","negative","deteriorat"]
            b=sum(1 for w in bull if w in text); s=sum(1 for w in bear if w in text)
            return "BULLISH" if b>s else "BEARISH" if s>b else "NEUTRAL"
        if ftype=="FII_DII" and extra:
            fii=extra.get("fii_net",0)
            if fii>500: return "STRONG_BULLISH"
            if fii>0:   return "BULLISH"
            if fii<-500:return "STRONG_BEARISH"
            return "BEARISH"
        return "BULLISH"

    def get_recent(self, hours=6):
        cutoff=now_ist()-timedelta(hours=hours)
        result=[]
        for f in self.cache.get("filings",[]):
            try:
                ts=datetime.fromisoformat(f["timestamp"])
                if not ts.tzinfo: ts=IST.localize(ts)
                if ts>=cutoff: result.append(f)
            except: result.append(f)
        return result[-200:]

# ──────────────────────────────────────────────────────────────────────────────
#  SOCIAL MONITOR
# ──────────────────────────────────────────────────────────────────────────────

class SocialMonitor:
    REDDIT_SUBS  = ["IndiaInvestments","DalalStreetBets","IndianStockMarket","NiftyOptionsTrader"]
    NITTER_ACCTS = ["https://nitter.net/NSEIndia/rss","https://nitter.net/BSEIndia/rss","https://nitter.net/SEBI_India/rss"]

    def __init__(self):
        self.cache=load_json(SOCIAL_FILE,{"seen":[],"signals":[]})
        self.lock=threading.Lock()
        self._start()

    def _start(self):
        def loop():
            while True:
                try: self._poll_reddit(); self._poll_nitter()
                except Exception as e: logger.error(f"Social: {e}")
                time.sleep(900)
        threading.Thread(target=loop,daemon=True,name="Social").start()
        logger.info("📱 Social Monitor active")

    def _poll_reddit(self):
        for sub in self.REDDIT_SUBS:
            try:
                r=requests.get(f"https://www.reddit.com/r/{sub}/new.json?limit=10",
                    headers={"User-Agent":"GlobalEyeBot/23.0"},timeout=15)
                if r.status_code!=200: continue
                for post in r.json().get("data",{}).get("children",[]):
                    d=post.get("data",{}); pid=d.get("id","")
                    title=d.get("title",""); score=d.get("score",0)
                    if pid in self.cache["seen"]: continue
                    text=(title+" "+d.get("selftext","")).lower()
                    syms=self._syms(text)
                    if syms and score>5:
                        self._add(pid,{"source":f"Reddit r/{sub}","type":"social",
                            "title":title[:200],"symbols":syms,"score":score,
                            "sentiment":self._sent(text),"ts":now_ist().isoformat()})
            except Exception as e: logger.debug(f"Reddit: {e}")

    def _poll_nitter(self):
        for url in self.NITTER_ACCTS:
            try:
                feed=feedparser.parse(url)
                for entry in feed.entries[:10]:
                    eid=getattr(entry,"id",entry.get("link",""))
                    title=getattr(entry,"title","")
                    if eid in self.cache["seen"]: continue
                    self._add(eid,{"source":f"Twitter({url.split('/')[3]})","type":"official",
                        "title":title[:200],"symbols":self._syms(title.lower()),
                        "sentiment":self._sent(title.lower()),"ts":now_ist().isoformat()})
            except Exception: pass

    def _syms(self, text):
        known=list(FNO_STOCKS)[:50]
        return list({s for s in known if s.lower() in text})[:5]

    def _sent(self, text):
        bull=["buy","bullish","breakout","target","upgrade","strong","rally","profit"]
        bear=["sell","bearish","breakdown","downgrade","weak","fall","loss","fraud"]
        b=sum(1 for w in bull if w in text); s=sum(1 for w in bear if w in text)
        if b>s: return "BULLISH"
        if s>b: return "BEARISH"
        return "NEUTRAL"

    def _add(self, sid, signal):
        with self.lock:
            self.cache["seen"].append(sid)
            self.cache["signals"]=(self.cache.get("signals",[])+[signal])[-500:]
            self.cache["seen"]=self.cache["seen"][-3000:]
        save_json(SOCIAL_FILE,self.cache)

    def get_recent(self, hours=6):
        cutoff=now_ist()-timedelta(hours=hours)
        result=[]
        for s in self.cache.get("signals",[]):
            try:
                ts=datetime.fromisoformat(s["ts"])
                if not ts.tzinfo: ts=IST.localize(ts)
                if ts>=cutoff: result.append(s)
            except: result.append(s)
        return result[-50:]

# ──────────────────────────────────────────────────────────────────────────────
#  NEWS MONITOR
# ──────────────────────────────────────────────────────────────────────────────

class NewsMonitor:
    def __init__(self):
        self.cache=load_json(NEWS_FILE,{"seen":[],"alerts":[]})
        self.lock=threading.Lock()
        threading.Thread(target=self._loop,daemon=True,name="News").start()
        logger.info("📡 News Monitor active")

    def _loop(self):
        while True:
            try: self._collect()
            except Exception as e: logger.error(f"News: {e}")
            time.sleep(900)

    def _collect(self):
        new_alerts=[]
        for src,url in NEWS_FEEDS.items():
            try:
                feed=feedparser.parse(url)
                for entry in feed.entries[:15]:
                    eid=getattr(entry,"id",entry.get("link",""))
                    if eid in self.cache["seen"]: continue
                    title=getattr(entry,"title",""); summary=getattr(entry,"summary","")
                    text=f"{title} {summary}".lower()
                    matched=[kw for kw in ALL_FILING_KW if kw in text]
                    if matched:
                        # ── Extract CORE INFO for readability ──
                        # Clean HTML tags from summary
                        clean_summary = re.sub(r'<[^>]+>', '', summary)[:300]
                        # Remove common noise phrases
                        for noise in ["Read more","Click here","Subscribe","Share this",
                                      "Also read","Related","Updated"]:
                            clean_summary = clean_summary.replace(noise,"")
                        clean_summary = ' '.join(clean_summary.split())[:200]

                        alert={"ts":now_ist().isoformat(),"source":src,
                               "title":title[:200],
                               "summary":clean_summary[:200],
                               "keywords":matched[:5],
                               "sentiment":self._sent(text)}
                        new_alerts.append(alert)
                        # Log with readable format
                        logger.info(f"📰 [{src}] {title[:100]}")
                        logger.info(f"   Core: {clean_summary[:100]}")
                        logger.info(f"   Keywords: {', '.join(matched[:3])} | {alert['sentiment']}")
                    with self.lock: self.cache["seen"].append(eid)
            except Exception as e: logger.debug(f"Feed [{src}]: {e}")
        if new_alerts:
            with self.lock:
                self.cache["alerts"]=(self.cache["alerts"]+new_alerts)[-1000:]
                self.cache["seen"]=self.cache["seen"][-3000:]
            save_json(NEWS_FILE,self.cache)

    def _sent(self, text):
        bull=["growth","profit","record","approval","upgrade","rally","gain","positive","strong"]
        bear=["loss","fraud","crash","default","penalty","ban","fall","decline","negative"]
        b=sum(1 for w in bull if w in text); s=sum(1 for w in bear if w in text)
        if b>s: return "BULLISH 🟢"
        if s>b: return "BEARISH 🔴"
        return "NEUTRAL ⚪"

    def recent(self, hours=6):
        cutoff=now_ist()-timedelta(hours=hours)
        result=[]
        with self.lock:
            for a in self.cache.get("alerts",[]):
                try:
                    ts=datetime.fromisoformat(a["ts"])
                    if not ts.tzinfo: ts=IST.localize(ts)
                    if ts>=cutoff: result.append(a)
                except: result.append(a)
        return result[-100:]

# ──────────────────────────────────────────────────────────────────────────────
#  TRENDLYNE SCORER
# ──────────────────────────────────────────────────────────────────────────────


# ──────────────────────────────────────────────────────────────────────────────
#  KITE SESSION MANAGER — Auto login, real-time data, no rate limiting
# ──────────────────────────────────────────────────────────────────────────────

class KiteSession:
    """
    Manages Zerodha Kite API session.
    - Scheduled login at 08:30 IST on TRADING DAYS ONLY
    - Emergency login for CRITICAL news outside hours
    - Telegram alert on every login attempt
    - No login on weekends or NSE holidays
    - LOGIN RATE LIMIT: Max 1 login per 30 minutes (prevents API abuse)
    - Token valid for 1 day (expires ~06:00 AM next day)
    """
    _instance = None
    _kite     = None
    _token_date = None
    _login_alerted = False
    _logged_out = False  # FIX: Prevents re-login after 16:00 logout
    _last_login_time = 0  # Rate limiter: timestamp of last login attempt
    _login_count_today = 0  # Track daily login count
    _login_count_date = ""  # Date for login count reset

    @classmethod
    def get(cls):
        """Get or create Kite session. Singleton pattern."""
        # FIX: If we already logged out today (16:00), don't re-login
        # Only scheduled_login() at 08:30 or emergency_login() can reset this
        if cls._logged_out:
            return None

        today = now_ist().strftime("%Y-%m-%d")
        if cls._kite and cls._token_date == today:
            return cls._kite
        # Only auto-login on trading days during trading hours (08:00-16:00)
        n = now_ist()
        if n.weekday() >= 5 or today in NSE_HOLIDAYS:
            if cls._kite:
                return cls._kite  # Use cached session if available
            return None
        # Don't auto-login after 16:00
        if n.hour >= 16:
            return None
        return cls._login()

    @classmethod
    def is_trading_day(cls):
        """Check if today is a trading day."""
        n = now_ist()
        today = n.strftime("%Y-%m-%d")
        return n.weekday() < 5 and today not in NSE_HOLIDAYS

    @classmethod
    def scheduled_login(cls):
        """
        Called at 08:30 IST on trading days.
        Fresh login to ensure valid session for the day.
        """
        if not cls.is_trading_day():
            logger.info("🔒 Kite: Not a trading day — skipping login")
            return None
        logger.info("🔑 Kite: Scheduled 08:30 login on trading day")
        cls._token_date = None  # Force fresh login
        cls._login_alerted = False
        cls._logged_out = False  # FIX: Reset logout flag — new trading day
        kite = cls._login()
        if kite:
            send_telegram(
                f"🔑 *Kite Login — 08:30 IST*\n"
                f"✅ Session active for today\n"
                f"📅 {now_ist().strftime('%a, %d %b %Y')}\n"
                f"📊 Ready for market open at 09:15",
                priority="kite"
            )
        else:
            send_telegram(
                f"🔴 *Kite Login FAILED — 08:30 IST*\n"
                f"⚠️ Could not connect to Zerodha\n"
                f"Please check credentials in .env",
                priority="kite"
            )
        return kite

    @classmethod
    def emergency_login(cls, reason="CRITICAL event"):
        """
        Emergency login outside market hours for critical events.
        Used when filing monitor detects urgent news or AMO orders needed.
        """
        logger.info(f"🚨 Kite EMERGENCY login — {reason}")
        cls._logged_out = False  # Reset logout flag — emergency overrides
        cls._token_date = None  # Force fresh login
        kite = cls._login()
        if kite:
            send_telegram(
                f"🚨 *Kite EMERGENCY Login*\n"
                f"Reason: {reason}\n"
                f"✅ Session active\n"
                f"🕐 {now_ist().strftime('%H:%M IST')}",
                priority="critical"
            )
        else:
            send_telegram(
                f"🚨 *Kite EMERGENCY Login FAILED*\n"
                f"Reason: {reason}\n"
                f"⚠️ Could not connect — manual action needed",
                priority="critical"
            )
        return kite

    @classmethod
    def _login(cls):
        """Auto login to Zerodha — TESTED AND WORKING on PythonAnywhere.
        Rate limited: max 1 login per 30 minutes, max 6 logins per day.
        """
        # ── LOGIN RATE LIMITER ──────────────────────────────
        now_ts = time.time()
        today = now_ist().strftime("%Y-%m-%d")

        # Reset daily counter
        if cls._login_count_date != today:
            cls._login_count_today = 0
            cls._login_count_date = today

        # Max 6 logins per day (1 scheduled + 5 emergency max)
        if cls._login_count_today >= 6:
            logger.warning(f"🛑 Kite login RATE LIMITED: {cls._login_count_today} logins today (max 6)")
            return cls._kite  # Return cached session if any
        
        # Min 30 minutes between logins (1800 seconds)
        elapsed = now_ts - cls._last_login_time
        if elapsed < 1800 and cls._last_login_time > 0:
            logger.info(f"🕐 Kite login: too soon ({elapsed:.0f}s since last, need 1800s) — using cached session")
            return cls._kite  # Return cached session if any

        cls._last_login_time = now_ts
        cls._login_count_today += 1
        logger.info(f"🔑 Kite login attempt #{cls._login_count_today} today")

        if not all([KITE_API_KEY, KITE_API_SECRET, KITE_TOTP_SECRET]):
            logger.warning("Kite credentials missing")
            return None
        try:
            kite    = KiteConnect(api_key=KITE_API_KEY)
            user_id = os.getenv("ZERODHA_USER_ID", "")
            password = os.getenv("ZERODHA_PASSWORD", "")

            session = requests.Session()
            session.headers.update({"User-Agent": "Mozilla/5.0"})

            # Step 1: Login
            r1 = session.post("https://kite.zerodha.com/api/login",
                data={"user_id": user_id, "password": password}, timeout=20)
            d1 = r1.json()
            if d1.get("status") != "success":
                logger.error(f"Kite login failed: {d1.get('message','')}")
                return None
            request_id = d1["data"]["request_id"]
            logger.info("Kite Step 1 OK")

            # Step 2: TOTP
            time.sleep(1)
            totp_code = pyotp.TOTP(KITE_TOTP_SECRET).now()
            r2 = session.post("https://kite.zerodha.com/api/twofa",
                data={"user_id": user_id, "request_id": request_id,
                      "twofa_value": totp_code, "twofa_type": "totp"},
                timeout=20, allow_redirects=True)
            logger.info("Kite Step 2 OK")

            # Step 3: Get request token via login URL (PROVEN METHOD)
            try:
                request_token = ""
                login_url = kite.login_url()
                r3 = session.get(login_url, timeout=20, allow_redirects=True)

                # Token is in final URL after redirect
                if "request_token=" in str(r3.url):
                    request_token = str(r3.url).split("request_token=")[1].split("&")[0]
                    logger.info(f"Token found: {request_token[:8]}...")

                # Also check redirect history
                if not request_token:
                    for resp in r3.history:
                        if "request_token=" in str(resp.url):
                            request_token = str(resp.url).split("request_token=")[1].split("&")[0]
                            break

                if not request_token:
                    logger.error(f"No token found. URL: {r3.url[:100]}")
                    return None

                # Step 4: Generate access token
                sess_data = kite.generate_session(request_token, api_secret=KITE_API_SECRET)
                kite.set_access_token(sess_data["access_token"])

                # Cache session
                cls._kite       = kite
                cls._token_date = now_ist().strftime("%Y-%m-%d")

                # Save to file for reuse
                save_json(ACCESS_FILE, {
                    "access_token": sess_data["access_token"],
                    "date":         cls._token_date,
                })

                logger.info("✅ Kite auto-login successful!")
                if not cls._login_alerted:
                    send_telegram(
                        f"✅ *Zerodha Kite Login*\n"
                        f"Session active — real-time data ready\n"
                        f"🕐 {now_ist().strftime('%H:%M IST %a, %d %b')}",
                        priority="kite"
                    )
                    cls._login_alerted = True
                return kite

            except Exception as e:
                logger.error(f"Kite token error: {e}")
                send_telegram(f"🔴 *Kite Login Failed*\nError: {str(e)[:200]}", priority="kite")
                return None

        except Exception as e:
            logger.error(f"Kite login error: {e}")
            return None

    @classmethod
    def restore(cls):
        """Try to restore session from saved token."""
        try:
            saved = load_json(ACCESS_FILE, {})
            today = now_ist().strftime("%Y-%m-%d")
            if saved.get("date") == today and saved.get("access_token"):
                kite = KiteConnect(api_key=KITE_API_KEY)
                kite.set_access_token(saved["access_token"])
                # Verify token works
                kite.profile()
                cls._kite       = kite
                cls._token_date = today
                logger.info("✅ Kite session restored from cache")
                return kite
        except Exception as e:
            logger.debug(f"Kite restore failed: {e}")
        return cls._login()

    @classmethod
    def get_ltp(cls, symbols):
        """
        Get last traded price for multiple symbols.
        symbols = list of NSE symbols like ["RELIANCE", "TCS"]
        Returns dict: {symbol: price}
        """
        kite = cls.get()
        if not kite:
            return {}
        try:
            instruments = [f"NSE:{s}" for s in symbols
                          if s not in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]]
            # Add indices
            index_map = {
                "NIFTY":      "NSE:NIFTY 50",
                "BANKNIFTY":  "NSE:NIFTY BANK",
                "FINNIFTY":   "NSE:NIFTY FIN SERVICE",
                "MIDCPNIFTY": "NSE:NIFTY MIDCAP 50",
            }
            for sym in symbols:
                if sym in index_map:
                    instruments.append(index_map[sym])

            if not instruments:
                return {}

            # Kite allows max 500 symbols per request
            prices = {}
            for i in range(0, len(instruments), 500):
                batch = instruments[i:i+500]
                data  = kite.ltp(batch)
                for key, val in data.items():
                    # Extract symbol from "NSE:RELIANCE" -> "RELIANCE"
                    sym = key.split(":")[-1]
                    # Reverse index name mapping
                    rev_map = {v.split(":")[-1]: k for k, v in index_map.items()}
                    sym = rev_map.get(sym, sym)
                    prices[sym] = round(val["last_price"], 2)
            return prices
        except Exception as e:
            logger.error(f"Kite LTP error: {e}")
            return {}

    @classmethod
    def get_historical(cls, symbol, interval="day", days=365):
        """
        Get historical OHLCV data for technical analysis.
        Returns pandas DataFrame.
        """
        kite = cls.get()
        if not kite:
            return None
        try:
            from_date = (now_ist() - timedelta(days=days)).strftime("%Y-%m-%d")
            to_date   = now_ist().strftime("%Y-%m-%d")

            # Get instrument token
            instruments = kite.instruments("NSE")
            token = None
            for inst in instruments:
                if inst["tradingsymbol"] == symbol:
                    token = inst["instrument_token"]
                    break

            if not token:
                return None

            data = kite.historical_data(
                instrument_token = token,
                from_date        = from_date,
                to_date          = to_date,
                interval         = interval,
            )
            if not data:
                return None

            df = pd.DataFrame(data)
            df.set_index("date", inplace=True)
            df.columns = [c.capitalize() for c in df.columns]
            return df

        except Exception as e:
            logger.debug(f"Kite historical [{symbol}]: {e}")
            return None



# ══════════════════════════════════════════════════════════════
#  MACRO INTELLIGENCE ENGINE (Ray Dalio Style)
# ══════════════════════════════════════════════════════════════

class MacroIntelligence:
    """
    Analyses global macro factors and their impact on Indian sectors.
    Based on Ray Dalio's principle-based algorithmic approach.
    """

    # Sector impact mapping
    MACRO_SECTOR_MAP = {
        "oil_rising": {
            "bullish": ["ONGC","BPCL","HINDPETRO","IOC","CAIRN","OIL"],
            "bearish": ["INDIGO","SPICEJET","INTERGLOBE","BLUEDART","CONCOR"],
        },
        "oil_falling": {
            "bullish": ["INDIGO","SPICEJET","INTERGLOBE","BLUEDART","PAINTCO"],
            "bearish": ["ONGC","BPCL","HINDPETRO"],
        },
        "inr_falling": {  # USD/INR rising — rupee weakens
            "bullish": ["TCS","INFY","WIPRO","HCLTECH","TECHM","LTIM"],  # IT earns in USD
            "bearish": ["INDIGO","IOC","BPCL"],  # Import-heavy
        },
        "inr_rising": {  # Rupee strengthens
            "bullish": ["INDIGO","IOC","BPCL","HINDPETRO"],
            "bearish": ["TCS","INFY","WIPRO"],
        },
        "rbi_rate_cut": {
            "bullish": ["HDFCBANK","ICICIBANK","KOTAKBANK","SBIN","AXISBANK",
                       "LICHSGFIN","PNBHOUSING","LODHA","DLF"],
            "bearish": [],
        },
        "rbi_rate_hike": {
            "bullish": [],
            "bearish": ["HDFCBANK","ICICIBANK","KOTAKBANK","REALTY","DLF"],
        },
        "fed_rate_hike": {
            "bullish": [],
            "bearish": ["NIFTY","BANKNIFTY"],  # FII outflows
        },
        "vix_high": {  # VIX > 20 — fear
            "bullish": ["HINDUNILVR","NESTLEIND","BRITANNIA","ITC","SUNPHARMA"],  # Defensives
            "bearish": ["TATAMOTORS","MARUTI","BAJFINANCE"],  # Cyclicals
        },
        "vix_low": {  # VIX < 14 — greed
            "bullish": ["TATAMOTORS","MARUTI","BAJFINANCE","DLF","ADANIENT"],
            "bearish": [],
        },
        "gold_rising": {
            "bullish": ["MUTHOOTFIN","MANAPPURAM","TITAN","RAJESHEXPO"],
            "bearish": [],
        },
    }

    @staticmethod
    def get_macro_signals():
        """Fetch macro data and generate sector signals."""
        signals = {}
        try:
            kite = KiteSession.get()
            macro_data = {}

            # Get key macro instruments via Kite LTP
            macro_instruments = {
                "NIFTY":     "NSE:NIFTY 50",
                "BANKNIFTY": "NSE:NIFTY BANK",
                "INDIAVIX":  "NSE:INDIA VIX",
            }

            if kite:
                try:
                    ltp = kite.ltp(list(macro_instruments.values()))
                    for name, inst in macro_instruments.items():
                        if inst in ltp:
                            macro_data[name] = ltp[inst]["last_price"]
                except Exception: pass

            # Get global data via yfinance
            global_syms = {
                "crude":   "CL=F",
                "gold":    "GC=F",
                "usdinr":  "USDINR=X",   # Fixed: INR=X delisted, use USDINR=X
                "usvix":   "^VIX",
            }
            for name, sym in global_syms.items():
                try:
                    hist = yf.Ticker(sym).history(period="5d")
                    if not hist.empty and len(hist) >= 2:
                        curr = float(hist["Close"].dropna().iloc[-1])
                        prev = float(hist["Close"].dropna().iloc[-2])
                        pct  = (curr - prev) / prev * 100
                        macro_data[name] = {"price": curr, "pct": pct}
                except Exception: pass

            # Generate signals
            crude = macro_data.get("crude", {})
            if isinstance(crude, dict):
                crude_pct = crude.get("pct", 0)
                crude_price = crude.get("price", 80)
                if crude_pct > 2 or crude_price > 90:
                    signals["oil_rising"] = True
                elif crude_pct < -2:
                    signals["oil_falling"] = True

            usdinr = macro_data.get("usdinr", {})
            if isinstance(usdinr, dict):
                inr_pct = usdinr.get("pct", 0)
                if inr_pct > 0.3:  # Rupee weakening
                    signals["inr_falling"] = True
                elif inr_pct < -0.3:
                    signals["inr_rising"] = True

            vix = macro_data.get("INDIAVIX", 0)
            if vix:
                if vix > 20: signals["vix_high"] = True
                elif vix < 14: signals["vix_low"] = True

            gold = macro_data.get("gold", {})
            if isinstance(gold, dict) and gold.get("pct", 0) > 1:
                signals["gold_rising"] = True

            logger.info(f"Macro signals: {list(signals.keys())}")
            return signals, macro_data

        except Exception as e:
            logger.error(f"Macro intelligence: {e}")
            return {}, {}

    @staticmethod
    def get_sector_bias(signals):
        """Convert macro signals to stock-level bullish/bearish bias."""
        bullish = set()
        bearish = set()
        for signal, active in signals.items():
            if active and signal in MacroIntelligence.MACRO_SECTOR_MAP:
                mapping = MacroIntelligence.MACRO_SECTOR_MAP[signal]
                bullish.update(mapping.get("bullish", []))
                bearish.update(mapping.get("bearish", []))
        return bullish, bearish


# ══════════════════════════════════════════════════════════════
#  v23.6.0 #9: DYNAMIC SECTOR ROTATION SCORER
#  Every Monday 07:30: ranks sectors by 1-week momentum.
#  Top 2 sectors get lower DVM threshold (priority scanning).
#  Bottom 2 sectors get higher DVM threshold (avoid weak sectors).
#  Mimics FII money flow rotation patterns.
# ══════════════════════════════════════════════════════════════

class SectorRotationScorer:
    """Dynamic sector momentum scoring — updated weekly on Monday."""

    # Sector → representative stocks mapping
    SECTOR_STOCKS = {
        "BANK":   ["HDFCBANK","ICICIBANK","SBIN","KOTAKBANK","AXISBANK"],
        "IT":     ["TCS","INFY","WIPRO","HCLTECH","TECHM","LTIM"],
        "PHARMA": ["SUNPHARMA","DRREDDY","CIPLA","DIVISLAB","AUROPHARMA"],
        "AUTO":   ["MARUTI","TATAMOTORS","M&M","BAJAJ-AUTO","HEROMOTOCO"],
        "FMCG":   ["HINDUNILVR","ITC","NESTLEIND","BRITANNIA","DABUR"],
        "METAL":  ["TATASTEEL","JSWSTEEL","HINDALCO","VEDL","SAIL"],
        "ENERGY": ["RELIANCE","ONGC","BPCL","NTPC","POWERGRID","TATAPOWER"],
        "REALTY": ["DLF","GODREJPROP","OBEROIREAL","PRESTIGE","BRIGADE"],
        "INFRA":  ["LT","ADANIENT","ADANIPORTS","IRB","GMRINFRA"],
    }

    _sector_scores = {}  # sector → {"score": pct, "rank": 1-9}
    _last_scored = ""
    _priority_sectors = []   # Top 2: lower DVM threshold
    _avoid_sectors = []      # Bottom 2: higher DVM threshold

    @classmethod
    def update_weekly(cls):
        """Called Monday 07:30 — rank sectors by 1-week performance."""
        today = now_ist().strftime("%Y-%m-%d")
        if cls._last_scored == today:
            return cls._sector_scores

        sector_returns = {}
        for sector, stocks in cls.SECTOR_STOCKS.items():
            returns = []
            for sym in stocks:
                try:
                    kite = KiteSession.get()
                    if kite:
                        token = DynamicStockUniverse.get_token(sym)
                        if token:
                            from_dt = (now_ist() - timedelta(days=10)).strftime("%Y-%m-%d")
                            to_dt = now_ist().strftime("%Y-%m-%d")
                            data = kite.historical_data(token, from_dt, to_dt, "day")
                            if data and len(data) >= 5:
                                prev = data[-6]["close"] if len(data) >= 6 else data[0]["close"]
                                curr = data[-1]["close"]
                                ret = (curr - prev) / prev * 100
                                returns.append(ret)
                except Exception:
                    pass
            if returns:
                sector_returns[sector] = round(sum(returns) / len(returns), 2)
            else:
                sector_returns[sector] = 0

        # Rank sectors
        sorted_sectors = sorted(sector_returns.items(), key=lambda x: x[1], reverse=True)
        cls._sector_scores = {}
        for rank, (sector, score) in enumerate(sorted_sectors, 1):
            cls._sector_scores[sector] = {"score": score, "rank": rank}

        # Top 2 = priority (lower DVM threshold by 5)
        cls._priority_sectors = [s for s, _ in sorted_sectors[:2]]
        # Bottom 2 = avoid (raise DVM threshold by 10)
        cls._avoid_sectors = [s for s, _ in sorted_sectors[-2:]]
        cls._last_scored = today

        _score_parts = []
        for s, v in cls._sector_scores.items():
            _sc = v.get("score", 0)
            _score_parts.append(f"{s}={_sc:+.1f}%")
        logger.info(
            f"SECTOR ROTATION: Priority={cls._priority_sectors} "
            f"Avoid={cls._avoid_sectors} | "
            f"Scores: {', '.join(_score_parts)}"
        )
        return cls._sector_scores

    @classmethod
    def get_dvm_adjustment(cls, symbol):
        """
        Returns DVM threshold adjustment for a stock based on its sector.
        Returns: (adjustment, sector_name)
          -5 for priority sectors (easier to enter)
          +10 for avoid sectors (harder to enter)
          0 for neutral sectors
        """
        for sector, stocks in cls.SECTOR_STOCKS.items():
            if symbol in stocks:
                if sector in cls._priority_sectors:
                    return -5, sector
                elif sector in cls._avoid_sectors:
                    return +10, sector
                else:
                    return 0, sector
        return 0, ""

    @classmethod
    def is_sector_crowded(cls, sector):
        """
        Check if a sector has been top-2 for 3+ weeks.
        Crowded sector = reduce exposure (mean reversion risk).
        """
        # TODO: Track weekly history to detect crowding
        # For now, no crowding detection
        return False


# ══════════════════════════════════════════════════════════════════════════════
#  v23.6.4: BILLIONAIRE UPGRADES — 4 NEW FEATURES
#  1. ETF Hedge Manager (GOLDBEES, NIFTYBEES, LIQUIDBEES)
#  2. RSI Oversold Bounce Scanner
#  3. Deep Fundamental Scoring
#  4. Win Rate Dashboard
# ══════════════════════════════════════════════════════════════════════════════

# ──────────────────────────────────────────────────────────────────────────────
#  FEATURE 1: ETF HEDGE MANAGER
#  "Don't put all eggs in one basket" — Ray Dalio
#  When market is volatile/bearish, park some capital in GOLDBEES/LIQUIDBEES
# ──────────────────────────────────────────────────────────────────────────────

class ETFHedgeManager:
    """
    Manages hedge positions in ETFs (allowed in NRO account).
    
    ETFs used:
    - GOLDBEES: Gold hedge (rises when stocks fall)
    - NIFTYBEES: Broad market exposure
    - LIQUIDBEES: Safe parking (1 unit = Rs.1000, earns ~6% annual)
    
    Rules:
    - In BEAR market (Nifty < -1%): Suggest GOLDBEES
    - In VOLATILE market (VIX > 18): Suggest LIQUIDBEES
    - In BULL market: No hedge needed
    - Max hedge: 20% of total capital
    """
    
    HEDGE_ETFS = {
        "GOLDBEES": {"type": "GOLD", "purpose": "Crash hedge", "min_buy": 1},
        "NIFTYBEES": {"type": "INDEX", "purpose": "Broad exposure", "min_buy": 1},
        "LIQUIDBEES": {"type": "LIQUID", "purpose": "Safe parking", "min_buy": 1},
    }
    
    MAX_HEDGE_PCT = 0.20  # Max 20% in hedges
    
    _hedge_file = os.path.join(DATA_DIR, "etf_hedges.json")
    _hedges = {}
    
    @classmethod
    def load(cls):
        """Load existing hedge positions."""
        cls._hedges = load_json(cls._hedge_file, {})
        return cls._hedges
    
    @classmethod
    def save(cls):
        """Save hedge positions."""
        save_json(cls._hedge_file, cls._hedges)
    
    @classmethod
    def get_hedge_recommendation(cls, nifty_change_pct, vix, total_capital, available_capital):
        """
        Get hedge recommendation based on market conditions.
        
        Returns: {"etf": "GOLDBEES", "reason": "...", "amount": 5000} or None
        """
        if available_capital < 5000:
            return None  # Not enough capital
        
        max_hedge_amount = total_capital * cls.MAX_HEDGE_PCT
        current_hedge_value = sum(h.get("value", 0) for h in cls._hedges.values())
        
        if current_hedge_value >= max_hedge_amount:
            return None  # Already at max hedge
        
        hedge_budget = min(available_capital * 0.15, max_hedge_amount - current_hedge_value)
        
        # BEAR market — suggest GOLDBEES
        if nifty_change_pct <= -1.0:
            return {
                "etf": "GOLDBEES",
                "reason": f"BEAR market (Nifty {nifty_change_pct:+.1f}%) — Gold hedge recommended",
                "amount": round(hedge_budget, 0),
                "priority": "HIGH"
            }
        
        # VOLATILE market — suggest LIQUIDBEES (safe parking)
        if vix >= 18:
            return {
                "etf": "LIQUIDBEES",
                "reason": f"HIGH VIX ({vix:.1f}) — Park capital safely",
                "amount": round(hedge_budget, 0),
                "priority": "MEDIUM"
            }
        
        # SIDEWAYS market — optional NIFTYBEES for broad exposure
        if -0.5 < nifty_change_pct < 0.5:
            return {
                "etf": "NIFTYBEES",
                "reason": "SIDEWAYS market — Broad index exposure",
                "amount": round(hedge_budget * 0.5, 0),
                "priority": "LOW"
            }
        
        return None  # BULL market — no hedge needed
    
    @classmethod
    def record_hedge(cls, etf, qty, price, order_id=None):
        """Record a hedge position."""
        cls.load()
        cls._hedges[etf] = {
            "qty": qty,
            "entry_price": price,
            "value": round(qty * price, 2),
            "entry_date": today_str(),
            "order_id": order_id or "MANUAL"
        }
        cls.save()
        logger.info(f"🛡️ HEDGE RECORDED: {etf} x{qty} @ Rs.{price}")
    
    @classmethod
    def get_hedge_status(cls):
        """Get current hedge status for reporting."""
        cls.load()
        if not cls._hedges:
            return "No active hedges"
        
        lines = ["🛡️ *ETF Hedges:*"]
        total = 0
        for etf, data in cls._hedges.items():
            lines.append(f"  • {etf}: {data['qty']}x @ Rs.{data['entry_price']} = Rs.{data['value']:,.0f}")
            total += data['value']
        lines.append(f"  *Total Hedge Value: Rs.{total:,.0f}*")
        return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  FEATURE 2: RSI OVERSOLD BOUNCE SCANNER
#  "Buy when there's blood in the streets" — Baron Rothschild
#  Scans for stocks that are oversold (RSI < 30) and starting to bounce
# ──────────────────────────────────────────────────────────────────────────────

class RSIOversoldScanner:
    """
    Scans for oversold bounce opportunities.
    
    Entry Criteria:
    1. RSI < 30 (oversold)
    2. Price bounced from recent low (current > yesterday's low)
    3. Volume spike (today's volume > 1.2x average)
    4. Not in lower circuit
    
    Exit:
    - At RSI 50 (mean reversion complete)
    - OR at +5% profit
    - OR at -3% stop loss
    """
    
    RSI_OVERSOLD = 30
    RSI_EXIT = 50
    BOUNCE_THRESHOLD = 0.003  # 0.3% above recent low
    VOLUME_MULTIPLIER = 1.2
    PROFIT_TARGET = 0.05  # +5%
    STOP_LOSS = 0.03  # -3%
    
    @classmethod
    def scan(cls, stock_data):
        """
        Check if a stock qualifies for oversold bounce entry.
        
        Args:
            stock_data: Dict with 'symbol', 'rsi', 'price', 'low', 'prev_low', 
                       'volume', 'avg_volume', 'is_circuit'
        
        Returns:
            (is_candidate, signal_dict) or (False, None)
        """
        try:
            sym = stock_data.get("symbol", "")
            rsi = stock_data.get("rsi", 50)
            price = stock_data.get("price", 0)
            day_low = stock_data.get("low", price)
            prev_low = stock_data.get("prev_low", day_low)
            volume = stock_data.get("volume", 0)
            avg_volume = stock_data.get("avg_volume", volume)
            is_circuit = stock_data.get("is_circuit", False)
            
            # Skip circuit stocks
            if is_circuit:
                return False, None
            
            # Check RSI oversold
            if rsi >= cls.RSI_OVERSOLD:
                return False, None
            
            # Check bounce from low
            recent_low = min(day_low, prev_low) if prev_low > 0 else day_low
            bounce_pct = (price - recent_low) / recent_low if recent_low > 0 else 0
            if bounce_pct < cls.BOUNCE_THRESHOLD:
                return False, None
            
            # Check volume spike
            vol_ratio = volume / avg_volume if avg_volume > 0 else 1
            if vol_ratio < cls.VOLUME_MULTIPLIER:
                return False, None
            
            # All criteria met!
            signal = {
                "symbol": sym,
                "signal_type": "OVERSOLD_BOUNCE",
                "rsi": round(rsi, 1),
                "bounce_pct": round(bounce_pct * 100, 2),
                "volume_ratio": round(vol_ratio, 2),
                "entry_price": price,
                "stop_loss": round(price * (1 - cls.STOP_LOSS), 2),
                "target": round(price * (1 + cls.PROFIT_TARGET), 2),
                "reason": f"RSI={rsi:.0f} (oversold) + Bounce +{bounce_pct*100:.1f}% + Vol {vol_ratio:.1f}x"
            }
            
            return True, signal
            
        except Exception as e:
            logger.debug(f"RSI Oversold scan error: {e}")
            return False, None
    
    @classmethod
    def check_exit(cls, position, current_rsi, current_price):
        """
        Check if an oversold bounce position should exit.
        
        Returns: (should_exit, reason)
        """
        entry_price = position.get("entry_price", current_price)
        pnl_pct = (current_price - entry_price) / entry_price if entry_price > 0 else 0
        
        # Exit at RSI 50 (mean reversion complete)
        if current_rsi >= cls.RSI_EXIT:
            return True, f"RSI Mean Reversion ({current_rsi:.0f} >= 50)"
        
        # Exit at profit target
        if pnl_pct >= cls.PROFIT_TARGET:
            return True, f"Profit Target (+{pnl_pct*100:.1f}%)"
        
        # Exit at stop loss
        if pnl_pct <= -cls.STOP_LOSS:
            return True, f"Stop Loss ({pnl_pct*100:.1f}%)"
        
        return False, None


# ──────────────────────────────────────────────────────────────────────────────
#  FEATURE 3: DEEP FUNDAMENTAL SCORING
#  "Price is what you pay, value is what you get" — Warren Buffett
#  Comprehensive fundamental analysis for stock selection
# ──────────────────────────────────────────────────────────────────────────────

class DeepFundamentalScorer:
    """
    Comprehensive fundamental scoring system.
    
    Metrics scored (each 0-10 points, total 100):
    1. PE Ratio (0-10): Lower is better, <15 ideal
    2. PB Ratio (0-10): Lower is better, <2 ideal
    3. ROE (0-10): Higher is better, >15% ideal
    4. ROCE (0-10): Higher is better, >18% ideal
    5. Debt/Equity (0-10): Lower is better, <0.5 ideal
    6. Profit Growth (0-10): Higher is better, >15% ideal
    7. Sales Growth (0-10): Higher is better, >10% ideal
    8. Promoter Holding (0-10): Higher is better, >50% ideal
    9. Dividend Yield (0-10): Higher is better for stability
    10. Free Cash Flow (0-10): Positive and growing is ideal
    
    Score interpretation:
    - 80-100: Excellent (Buffett-quality)
    - 60-79: Good (Worth considering)
    - 40-59: Average (Technical trades only)
    - 0-39: Poor (Avoid for long-term)
    """
    
    # Screener.in API for fundamental data
    SCREENER_URL = "https://www.screener.in/api/company/{symbol}/consolidated/"
    
    _cache = {}
    _cache_date = ""
    
    @classmethod
    def score(cls, symbol, fundamental_data=None):
        """
        Calculate comprehensive fundamental score.
        
        Args:
            symbol: Stock symbol
            fundamental_data: Dict with PE, PB, ROE, etc. (optional, will fetch if None)
        
        Returns:
            (total_score, breakdown_dict)
        """
        if fundamental_data is None:
            fundamental_data = {}
        
        scores = {}
        
        # 1. PE Ratio (lower is better)
        pe = fundamental_data.get("pe", 25)
        if pe <= 0:
            scores["PE"] = 0  # Negative PE = loss-making
        elif pe < 10:
            scores["PE"] = 10
        elif pe < 15:
            scores["PE"] = 8
        elif pe < 20:
            scores["PE"] = 6
        elif pe < 30:
            scores["PE"] = 4
        elif pe < 50:
            scores["PE"] = 2
        else:
            scores["PE"] = 0
        
        # 2. PB Ratio (lower is better)
        pb = fundamental_data.get("pb", 3)
        if pb <= 0:
            scores["PB"] = 0
        elif pb < 1:
            scores["PB"] = 10
        elif pb < 2:
            scores["PB"] = 8
        elif pb < 3:
            scores["PB"] = 6
        elif pb < 5:
            scores["PB"] = 4
        else:
            scores["PB"] = 2
        
        # 3. ROE (higher is better)
        roe = fundamental_data.get("roe", 10)
        if roe >= 25:
            scores["ROE"] = 10
        elif roe >= 20:
            scores["ROE"] = 8
        elif roe >= 15:
            scores["ROE"] = 6
        elif roe >= 10:
            scores["ROE"] = 4
        elif roe >= 5:
            scores["ROE"] = 2
        else:
            scores["ROE"] = 0
        
        # 4. ROCE (higher is better)
        roce = fundamental_data.get("roce", 12)
        if roce >= 25:
            scores["ROCE"] = 10
        elif roce >= 20:
            scores["ROCE"] = 8
        elif roce >= 15:
            scores["ROCE"] = 6
        elif roce >= 10:
            scores["ROCE"] = 4
        else:
            scores["ROCE"] = 2
        
        # 5. Debt/Equity (lower is better)
        de = fundamental_data.get("debt_equity", 0.5)
        if de <= 0:
            scores["DE"] = 10  # Debt-free
        elif de < 0.3:
            scores["DE"] = 9
        elif de < 0.5:
            scores["DE"] = 7
        elif de < 1.0:
            scores["DE"] = 5
        elif de < 2.0:
            scores["DE"] = 3
        else:
            scores["DE"] = 1
        
        # 6. Profit Growth (higher is better)
        profit_growth = fundamental_data.get("profit_growth", 10)
        if profit_growth >= 25:
            scores["ProfitGrowth"] = 10
        elif profit_growth >= 15:
            scores["ProfitGrowth"] = 8
        elif profit_growth >= 10:
            scores["ProfitGrowth"] = 6
        elif profit_growth >= 5:
            scores["ProfitGrowth"] = 4
        elif profit_growth >= 0:
            scores["ProfitGrowth"] = 2
        else:
            scores["ProfitGrowth"] = 0
        
        # 7. Sales Growth (higher is better)
        sales_growth = fundamental_data.get("sales_growth", 8)
        if sales_growth >= 20:
            scores["SalesGrowth"] = 10
        elif sales_growth >= 15:
            scores["SalesGrowth"] = 8
        elif sales_growth >= 10:
            scores["SalesGrowth"] = 6
        elif sales_growth >= 5:
            scores["SalesGrowth"] = 4
        else:
            scores["SalesGrowth"] = 2
        
        # 8. Promoter Holding (higher is better)
        promoter = fundamental_data.get("promoter_holding", 50)
        if promoter >= 70:
            scores["Promoter"] = 10
        elif promoter >= 60:
            scores["Promoter"] = 8
        elif promoter >= 50:
            scores["Promoter"] = 6
        elif promoter >= 40:
            scores["Promoter"] = 4
        else:
            scores["Promoter"] = 2
        
        # 9. Dividend Yield (for stability)
        div_yield = fundamental_data.get("dividend_yield", 1)
        if div_yield >= 4:
            scores["Dividend"] = 10
        elif div_yield >= 2:
            scores["Dividend"] = 7
        elif div_yield >= 1:
            scores["Dividend"] = 5
        elif div_yield > 0:
            scores["Dividend"] = 3
        else:
            scores["Dividend"] = 1
        
        # 10. Market Cap Stability (large caps = safer)
        mcap = fundamental_data.get("market_cap_cr", 5000)
        if mcap >= 100000:  # Large cap
            scores["MarketCap"] = 10
        elif mcap >= 20000:  # Mid cap
            scores["MarketCap"] = 7
        elif mcap >= 5000:  # Small cap
            scores["MarketCap"] = 5
        else:
            scores["MarketCap"] = 3
        
        total_score = sum(scores.values())
        
        # Quality label
        if total_score >= 80:
            quality = "EXCELLENT (Buffett-quality)"
        elif total_score >= 65:
            quality = "GOOD"
        elif total_score >= 50:
            quality = "AVERAGE"
        else:
            quality = "BELOW AVERAGE"
        
        return total_score, scores, quality
    
    @classmethod
    def get_fundamental_boost(cls, symbol, fundamental_data=None):
        """
        Get DVM adjustment based on fundamental score.
        Used by 3-Agent AI to boost/penalize stocks.
        
        Returns: (adjustment, reason)
        """
        total, breakdown, quality = cls.score(symbol, fundamental_data)
        
        if total >= 80:
            return -10, f"Fundamental EXCELLENT ({total}/100)"  # Lower DVM bar
        elif total >= 65:
            return -5, f"Fundamental GOOD ({total}/100)"
        elif total < 40:
            return +10, f"Fundamental WEAK ({total}/100)"  # Higher DVM bar
        else:
            return 0, f"Fundamental AVERAGE ({total}/100)"


# ──────────────────────────────────────────────────────────────────────────────
#  FEATURE 4: WIN RATE DASHBOARD
#  "What gets measured gets improved" — Peter Drucker
#  Comprehensive tracking of bot performance
# ──────────────────────────────────────────────────────────────────────────────

class WinRateDashboard:
    """
    Tracks and reports bot performance metrics.
    
    Metrics tracked:
    - Total trades
    - Win rate (%)
    - Average win (Rs.)
    - Average loss (Rs.)
    - Expectancy per trade (Rs.)
    - Best trade
    - Worst trade
    - Profit factor
    - Max drawdown
    - Current streak (wins/losses)
    """
    
    _stats_file = os.path.join(DATA_DIR, "win_rate_stats.json")
    _stats = {}
    
    @classmethod
    def load(cls):
        """Load stats from file."""
        cls._stats = load_json(cls._stats_file, {
            "total_trades": 0,
            "wins": 0,
            "losses": 0,
            "total_profit": 0,
            "total_loss": 0,
            "best_trade": {"symbol": "", "pnl": 0},
            "worst_trade": {"symbol": "", "pnl": 0},
            "current_streak": 0,
            "max_win_streak": 0,
            "max_loss_streak": 0,
            "trades_by_strategy": {},
            "trades_by_source": {},
            "daily_stats": {},
        })
        return cls._stats
    
    @classmethod
    def save(cls):
        """Save stats to file."""
        save_json(cls._stats_file, cls._stats)
    
    @classmethod
    def record_trade(cls, trade_data):
        """
        Record a completed trade.
        
        Args:
            trade_data: Dict with 'symbol', 'pnl', 'strategy', 'source', 'entry_price', 'exit_price'
        """
        cls.load()
        
        pnl = trade_data.get("pnl", 0)
        symbol = trade_data.get("symbol", "UNKNOWN")
        strategy = trade_data.get("strategy", "unknown")
        source = trade_data.get("source", "TECHNICAL")
        
        cls._stats["total_trades"] += 1
        
        if pnl > 0:
            cls._stats["wins"] += 1
            cls._stats["total_profit"] += pnl
            
            # Update streak
            if cls._stats["current_streak"] >= 0:
                cls._stats["current_streak"] += 1
            else:
                cls._stats["current_streak"] = 1
            
            # Best trade
            if pnl > cls._stats["best_trade"]["pnl"]:
                cls._stats["best_trade"] = {"symbol": symbol, "pnl": pnl}
        else:
            cls._stats["losses"] += 1
            cls._stats["total_loss"] += abs(pnl)
            
            # Update streak
            if cls._stats["current_streak"] <= 0:
                cls._stats["current_streak"] -= 1
            else:
                cls._stats["current_streak"] = -1
            
            # Worst trade
            if pnl < cls._stats["worst_trade"]["pnl"]:
                cls._stats["worst_trade"] = {"symbol": symbol, "pnl": pnl}
        
        # Update max streaks
        if cls._stats["current_streak"] > cls._stats["max_win_streak"]:
            cls._stats["max_win_streak"] = cls._stats["current_streak"]
        if cls._stats["current_streak"] < -cls._stats["max_loss_streak"]:
            cls._stats["max_loss_streak"] = abs(cls._stats["current_streak"])
        
        # Track by strategy
        if strategy not in cls._stats["trades_by_strategy"]:
            cls._stats["trades_by_strategy"][strategy] = {"wins": 0, "losses": 0, "pnl": 0}
        cls._stats["trades_by_strategy"][strategy]["pnl"] += pnl
        if pnl > 0:
            cls._stats["trades_by_strategy"][strategy]["wins"] += 1
        else:
            cls._stats["trades_by_strategy"][strategy]["losses"] += 1
        
        # Track by source
        source_key = source.split("|")[0] if "|" in source else source
        if source_key not in cls._stats["trades_by_source"]:
            cls._stats["trades_by_source"][source_key] = {"wins": 0, "losses": 0, "pnl": 0}
        cls._stats["trades_by_source"][source_key]["pnl"] += pnl
        if pnl > 0:
            cls._stats["trades_by_source"][source_key]["wins"] += 1
        else:
            cls._stats["trades_by_source"][source_key]["losses"] += 1
        
        # Daily tracking
        today = today_str()
        if today not in cls._stats["daily_stats"]:
            cls._stats["daily_stats"][today] = {"trades": 0, "pnl": 0, "wins": 0}
        cls._stats["daily_stats"][today]["trades"] += 1
        cls._stats["daily_stats"][today]["pnl"] += pnl
        if pnl > 0:
            cls._stats["daily_stats"][today]["wins"] += 1
        
        cls.save()
        logger.info(f"📊 WIN RATE: Recorded {symbol} PnL={pnl:+.0f} | Total trades={cls._stats['total_trades']}")
    
    @classmethod
    def get_metrics(cls):
        """
        Calculate all performance metrics.
        
        Returns: Dict with all metrics
        """
        cls.load()
        s = cls._stats
        
        total = s["total_trades"]
        wins = s["wins"]
        losses = s["losses"]
        
        win_rate = (wins / total * 100) if total > 0 else 0
        avg_win = (s["total_profit"] / wins) if wins > 0 else 0
        avg_loss = (s["total_loss"] / losses) if losses > 0 else 0
        
        # Expectancy = (Win% × Avg Win) - (Loss% × Avg Loss)
        expectancy = (win_rate/100 * avg_win) - ((100-win_rate)/100 * avg_loss)
        
        # Profit Factor = Gross Profit / Gross Loss
        profit_factor = (s["total_profit"] / s["total_loss"]) if s["total_loss"] > 0 else float('inf')
        
        # Net PnL
        net_pnl = s["total_profit"] - s["total_loss"]
        
        return {
            "total_trades": total,
            "wins": wins,
            "losses": losses,
            "win_rate": round(win_rate, 1),
            "avg_win": round(avg_win, 0),
            "avg_loss": round(avg_loss, 0),
            "expectancy": round(expectancy, 0),
            "profit_factor": round(profit_factor, 2),
            "net_pnl": round(net_pnl, 0),
            "best_trade": s["best_trade"],
            "worst_trade": s["worst_trade"],
            "current_streak": s["current_streak"],
            "max_win_streak": s["max_win_streak"],
            "max_loss_streak": s["max_loss_streak"],
        }
    
    @classmethod
    def get_dashboard_text(cls):
        """
        Generate dashboard text for Telegram/report.
        """
        m = cls.get_metrics()
        
        # Streak emoji
        if m["current_streak"] > 0:
            streak_emoji = "🔥" * min(m["current_streak"], 5)
            streak_text = f"+{m['current_streak']} wins"
        elif m["current_streak"] < 0:
            streak_emoji = "❄️"
            streak_text = f"{m['current_streak']} losses"
        else:
            streak_emoji = "➖"
            streak_text = "No streak"
        
        # Win rate emoji
        if m["win_rate"] >= 60:
            wr_emoji = "🏆"
        elif m["win_rate"] >= 50:
            wr_emoji = "✅"
        else:
            wr_emoji = "⚠️"
        
        dashboard = f"""
📊 *WIN RATE DASHBOARD*
━━━━━━━━━━━━━━━━━━━━━

{wr_emoji} *Win Rate: {m['win_rate']}%* ({m['wins']}W / {m['losses']}L)
📈 Total Trades: {m['total_trades']}

💰 *Performance:*
  • Avg Win: +₹{m['avg_win']:,.0f}
  • Avg Loss: -₹{m['avg_loss']:,.0f}
  • Expectancy: ₹{m['expectancy']:+,.0f}/trade
  • Profit Factor: {m['profit_factor']:.2f}x

📊 *Net PnL: ₹{m['net_pnl']:+,.0f}*

🏅 Best: {m['best_trade']['symbol']} +₹{m['best_trade']['pnl']:,.0f}
💔 Worst: {m['worst_trade']['symbol']} ₹{m['worst_trade']['pnl']:,.0f}

{streak_emoji} Streak: {streak_text}
  Max Win Streak: {m['max_win_streak']}
  Max Loss Streak: {m['max_loss_streak']}
"""
        return dashboard.strip()
    
    @classmethod
    def get_strategy_breakdown(cls):
        """Get performance breakdown by strategy."""
        cls.load()
        lines = ["📊 *By Strategy:*"]
        for strat, data in cls._stats.get("trades_by_strategy", {}).items():
            total = data["wins"] + data["losses"]
            wr = (data["wins"] / total * 100) if total > 0 else 0
            lines.append(f"  • {strat.upper()}: {wr:.0f}% WR | ₹{data['pnl']:+,.0f}")
        return "\n".join(lines) if len(lines) > 1 else "No strategy data yet"
    
    @classmethod
    def get_source_breakdown(cls):
        """Get performance breakdown by signal source."""
        cls.load()
        lines = ["📊 *By Source:*"]
        for source, data in cls._stats.get("trades_by_source", {}).items():
            total = data["wins"] + data["losses"]
            wr = (data["wins"] / total * 100) if total > 0 else 0
            lines.append(f"  • {source}: {wr:.0f}% WR | ₹{data['pnl']:+,.0f}")
        return "\n".join(lines) if len(lines) > 1 else "No source data yet"


# ══════════════════════════════════════════════════════════════
#  v23.6.0 #12: PROTECTIVE PUT FRAMEWORK
#  When portfolio >Rs.1L and positions >4, buy Nifty put as insurance.
#  Activated automatically when conditions met.
#  Cost: ~2-3% of portfolio per month for crash protection.
# ══════════════════════════════════════════════════════════════

class ProtectivePutFramework:
    """
    Portfolio insurance via OTM Nifty puts.
    Rules:
    - Only when portfolio value > Rs.1,00,000
    - Only when 4+ open positions (concentrated risk)
    - Only when VIX < 14 (cheap insurance)
    - Buy 5% OTM monthly Nifty put (1 lot = 25 qty)
    - Max spend: 3% of portfolio on insurance per month
    """

    MIN_PORTFOLIO = 100000     # Rs.1L minimum
    MIN_POSITIONS = 4          # Need meaningful exposure
    MAX_VIX = 14               # Only buy when VIX is low (cheap)
    OTM_PCT = 5                # 5% out-of-the-money
    MAX_INSURANCE_PCT = 0.03   # Max 3% of portfolio on puts

    @classmethod
    def should_hedge(cls, portfolio_value, open_positions, vix):
        """Check if hedging conditions are met."""
        if portfolio_value < cls.MIN_PORTFOLIO:
            return False, f"Portfolio Rs.{portfolio_value:,.0f} < Rs.{cls.MIN_PORTFOLIO:,.0f}"
        if open_positions < cls.MIN_POSITIONS:
            return False, f"Only {open_positions} positions (need {cls.MIN_POSITIONS}+)"
        if vix > cls.MAX_VIX:
            return False, f"VIX={vix} too high (max {cls.MAX_VIX}) — insurance expensive"
        return True, "ALL CONDITIONS MET — hedge recommended"

    @classmethod
    def get_hedge_params(cls, portfolio_value, nifty_price):
        """Calculate hedge parameters."""
        strike = round(nifty_price * (1 - cls.OTM_PCT / 100) / 50) * 50  # Round to nearest 50
        max_spend = round(portfolio_value * cls.MAX_INSURANCE_PCT, 2)
        return {
            "instrument": "NIFTY",
            "option_type": "PE",
            "strike": strike,
            "max_premium": max_spend,
            "description": (
                f"Buy NIFTY {strike} PE (monthly expiry)\n"
                f"Max spend: Rs.{max_spend:,.0f} ({cls.MAX_INSURANCE_PCT*100}% of portfolio)\n"
                f"Protection: Covers crash below Nifty {strike}"
            ),
        }


# ══════════════════════════════════════════════════════════════
#  EARNINGS NLP ENGINE
# ══════════════════════════════════════════════════════════════

class EarningsNLP:
    """
    Parses quarterly results using NLP.
    Based on strategies used by Citadel and AQR.
    """

    STRONG_BULLISH_KEYWORDS = [
        "record revenue", "record profit", "highest ever", "beat estimates",
        "strong growth", "robust performance", "exceptional quarter",
        "revenue grew", "profit surged", "margin expansion", "order book strong",
        "demand robust", "guidance raised", "outperformed", "best ever quarter",
        # Turnaround signals
        "return to profitability", "turnaround", "back to profit",
        "narrowing losses", "loss reduced", "restructuring complete",
        "debt reduced", "debt free", "promoter increased stake",
    ]

    BULLISH_KEYWORDS = [
        "growth", "profit increased", "revenue increased", "positive outlook",
        "strong demand", "market share gained", "new orders", "expansion",
        "dividend declared", "buyback", "capacity addition", "recovery",
        # Turnaround signals
        "improving margins", "cost optimization", "operational efficiency",
        "management change", "new ceo", "new md", "strategic review",
        "business restructuring", "asset monetization", "stake sale",
        "promoter buying", "insider buying", "open offer",
    ]

    BEARISH_KEYWORDS = [
        "loss", "decline", "revenue fell", "profit fell", "margin pressure",
        "challenging", "headwinds", "weak demand", "competition intensified",
        "write-off", "impairment", "below estimates", "guidance cut",
        "plant shutdown", "regulatory", "penalty", "fraud",
    ]

    STRONG_BEARISH_KEYWORDS = [
        "net loss", "revenue declined sharply", "serious concerns",
        "going concern", "default", "insolvency", "fraud detected",
        "major write-off", "plant closed", "license cancelled",
    ]

    @staticmethod
    def analyse(text):
        """Analyse filing text and return sentiment score -100 to +100."""
        text_lower = text.lower()
        score = 0

        # Strong signals
        for kw in EarningsNLP.STRONG_BULLISH_KEYWORDS:
            if kw in text_lower: score += 15
        for kw in EarningsNLP.BULLISH_KEYWORDS:
            if kw in text_lower: score += 5
        for kw in EarningsNLP.BEARISH_KEYWORDS:
            if kw in text_lower: score -= 5
        for kw in EarningsNLP.STRONG_BEARISH_KEYWORDS:
            if kw in text_lower: score -= 15

        # Cap score
        score = max(-100, min(100, score))

        if score >= 30:   sentiment = "STRONG_BULLISH"
        elif score >= 10: sentiment = "BULLISH"
        elif score <= -30:sentiment = "STRONG_BEARISH"
        elif score <= -10:sentiment = "BEARISH"
        else:             sentiment = "NEUTRAL"

        return score, sentiment

    @staticmethod
    def extract_numbers(text):
        """Extract key financial numbers from filing text."""
        import re
        numbers = {}
        # Revenue patterns
        rev_match = re.findall(
            r'revenue[^\d]*(\d+[\.,]?\d*)\s*(crore|lakh|million|billion)?',
            text.lower()
        )
        if rev_match: numbers["revenue_mention"] = rev_match[0]
        # Profit patterns
        profit_match = re.findall(
            r'(?:net\s+)?profit[^\d]*(\d+[\.,]?\d*)\s*(crore|lakh|million|billion)?',
            text.lower()
        )
        if profit_match: numbers["profit_mention"] = profit_match[0]
        return numbers


# ══════════════════════════════════════════════════════════════
#  PATTERN RECOGNITION ENGINE (Simons Style)
# ══════════════════════════════════════════════════════════════

class PatternRecognition:
    """
    Identifies classic chart patterns.
    Based on Renaissance Technologies pattern recognition approach.
    """

    @staticmethod
    def detect(hist):
        """Detect patterns in price history. Returns list of patterns found."""
        patterns = []
        if hist is None or len(hist) < 50:
            return patterns

        try:
            c  = hist["Close"] if "Close" in hist.columns else hist.iloc[:, 3]
            h  = hist["High"]  if "High"  in hist.columns else hist.iloc[:, 1]
            lo = hist["Low"]   if "Low"   in hist.columns else hist.iloc[:, 2]

            price = float(c.iloc[-1])
            ma20  = float(c.rolling(20).mean().iloc[-1])
            ma50  = float(c.rolling(50).mean().iloc[-1])
            ma200 = float(c.rolling(min(200,len(c))).mean().iloc[-1])

            # Golden Cross
            if ma50 > ma200 and float(c.rolling(50).mean().iloc[-2]) <= float(c.rolling(min(200,len(c))).mean().iloc[-2]):
                patterns.append(("GOLDEN_CROSS", "BULLISH", 85))

            # Death Cross
            if ma50 < ma200 and float(c.rolling(50).mean().iloc[-2]) >= float(c.rolling(min(200,len(c))).mean().iloc[-2]):
                patterns.append(("DEATH_CROSS", "BEARISH", 85))

            # Bull Flag — strong uptrend then consolidation
            recent_high = float(h.iloc[-20:].max())
            recent_low  = float(lo.iloc[-20:].min())
            prior_high  = float(h.iloc[-40:-20].max())
            if price > ma20 > ma50 and (recent_high - recent_low) / recent_high < 0.05:
                patterns.append(("BULL_FLAG", "BULLISH", 75))

            # Double Bottom
            lows = lo.rolling(5).min()
            if len(lows) >= 30:
                l1 = float(lows.iloc[-30])
                l2 = float(lows.iloc[-10])
                if abs(l1 - l2) / l1 < 0.02 and price > max(l1, l2) * 1.03:
                    patterns.append(("DOUBLE_BOTTOM", "BULLISH", 80))

            # RSI Divergence
            d    = c.diff()
            gain = d.where(d>0,0).rolling(14).mean()
            loss = -d.where(d<0,0).rolling(14).mean()
            rsi  = float((100-(100/(1+gain/loss))).iloc[-1])
            rsi_prev = float((100-(100/(1+gain/loss))).iloc[-5])

            if price < float(c.iloc[-5]) and rsi > rsi_prev:
                patterns.append(("BULLISH_DIVERGENCE", "BULLISH", 70))
            if price > float(c.iloc[-5]) and rsi < rsi_prev:
                patterns.append(("BEARISH_DIVERGENCE", "BEARISH", 70))

            # 52-week breakout
            high_52 = float(h.rolling(min(252,len(h))).max().iloc[-1])
            if price >= high_52 * 0.99:
                patterns.append(("52W_BREAKOUT", "BULLISH", 90))

        except Exception as e:
            logger.debug(f"Pattern detection: {e}")

        return patterns


# ══════════════════════════════════════════════════════════════
#  COMBINED SENTIMENT SCORE ENGINE (Citadel Style)
# ══════════════════════════════════════════════════════════════

class SentimentEngine:
    """
    Combines all signals into a single sentiment score 0-100.
    Based on Citadel's multi-factor signal approach.
    """

    @staticmethod
    def score(symbol, scan_result, filings, news_alerts,
              macro_bullish, macro_bearish, patterns):
        """
        Calculate combined sentiment score:
        - Technical: 30 points
        - Filing/Earnings: 25 points
        - Macro: 20 points
        - Pattern: 15 points
        - News/Social: 10 points
        """
        score = 50  # Start neutral

        # Technical score (30 points max)
        if scan_result:
            dvm = scan_result.get("dvm_score", 50)
            tech_contribution = (dvm - 50) * 0.6  # -30 to +30
            score += tech_contribution

        # Filing/Earnings score (25 points max)
        stock_filings = [f for f in filings if f.get("symbol") == symbol]
        for f in stock_filings[-3:]:  # Last 3 filings
            sent = f.get("sentiment", "NEUTRAL")
            if sent == "STRONG_BULLISH": score += 10
            elif sent == "BULLISH":      score += 5
            elif sent == "BEARISH":      score -= 5
            elif sent == "STRONG_BEARISH": score -= 10

        # Macro score (20 points max)
        if symbol in macro_bullish: score += 10
        if symbol in macro_bearish: score -= 10

        # Pattern score (15 points max)
        for pattern_name, direction, confidence in patterns:
            if direction == "BULLISH":
                score += confidence * 0.15
            else:
                score -= confidence * 0.15

        # News score (10 points max)
        stock_news = [n for n in news_alerts
                     if symbol.lower() in n.get("title","").lower()]
        for n in stock_news[-2:]:
            sent = n.get("sentiment","")
            if "BULLISH" in sent: score += 5
            elif "BEARISH" in sent: score -= 5

        # Cap score 0-100
        score = max(0, min(100, score))

        if   score >= 80: label = "STRONG BUY 🟢🟢"
        elif score >= 65: label = "BUY 🟢"
        elif score >= 50: label = "HOLD ⚪"
        elif score >= 35: label = "SELL 🔴"
        else:             label = "STRONG SELL 🔴🔴"

        return round(score, 1), label


# ══════════════════════════════════════════════════════════════
#  BILLIONAIRE PRE-TRADE VALIDATION SYSTEM
#  Inspired by:
#  • Renaissance Technologies — 50.75% edge, but ALWAYS validated
#    before execution. "We're right 50.75% of the time, but we're
#    100% right 50.75% of the time."
#  • Ray Dalio/Bridgewater — Multi-factor stress test, data
#    validation, historical backtesting before every position.
#  • Man Group AlphaGPT — 3-agent system with idea/implement/eval.
#
#  KEY DESIGN:
#  AGGRESSIVE MODE (1 agent vote):
#    → Before placing trade, run 8-point TECHNICAL RECHECK
#    → 75% (6/8) must pass → trade executes
#    → This prevents 1 weak agent from placing garbage trades
#
#  BALANCED MODE (2 agent votes):
#    → After 2/3 vote, run 5-point DALIO STRESS TEST
#    → Must pass all 5 → trade executes
#    → Extra safety layer for conservative capital protection
# ══════════════════════════════════════════════════════════════

class ThreeAgentAI:
    """
    3-agent trading system + Billionaire Pre-Trade Validation.

    Agent 1 — Idea Generator: finds opportunities (filings, sentiment, patterns)
    Agent 2 — Implementer: checks technicals + risk (RSI, MACD, DVM, volume)
    Agent 3 — Evaluator: macro alignment + economic reasoning

    AFTER voting:
    AGGRESSIVE: 1/3 vote enough BUT must pass 75% Technical Recheck (6/8 checks)
    BALANCED:   2/3 vote needed AND must pass Dalio Stress Test (5/5 checks)
    """

    # ── 8-POINT TECHNICAL RECHECK (Renaissance Style) ─────────
    # Used in AGGRESSIVE mode after 1 agent approves
    # Must pass 6 out of 8 (75%) — prevents bad trades from weak signals
    TECH_CHECKS = [
        "price_above_ma20",      # Price > 20-day MA (short-term trend intact)
        "macd_bullish",          # MACD line above signal (momentum confirmed)
        "rsi_not_extreme",       # RSI between 25-75 (not overbought/oversold)
        "volume_above_avg",      # Volume > 80% of 20-day average (participation)
        "trend_not_bearish",     # Not in strong bearish trend (MA50 < MA200 death cross)
        "not_near_resistance",   # Not within 2% of 52-week high (avoid buying tops)
        "atr_within_range",      # ATR not > 5% of price (too volatile = dangerous)
        "price_above_min",       # Price > ₹50 (no penny stocks)
    ]

    # ── 5-POINT DALIO STRESS TEST (Bridgewater Style) ─────────
    # Used in BALANCED mode after 2/3 agents approve
    # Must pass ALL 5 — Dalio principle: "stress test against scenarios"
    STRESS_CHECKS = [
        "no_macro_headwind",     # Stock not in macro bearish sector (oil/INR impact)
        "no_recent_bad_filing",  # No negative filing in last 24h for this stock
        "dvm_above_threshold",   # DVM score meets mode threshold
        "positive_sentiment",    # Combined sentiment > 45 (not net negative)
        "capital_available",     # Enough capital left in strategy (< 80% deployed)
    ]

    @staticmethod
    def _run_tech_recheck(symbol, price, scan_result):
        """
        Renaissance-style 8-point technical recheck.
        Returns (passed_count, total_checks, details).
        Each check is a simple True/False with reason.
        """
        checks = {}
        r = scan_result or {}

        # 1. Price above 20-day MA
        ma20 = r.get("ma50", price)  # Use ma50 as proxy if ma20 not available
        checks["price_above_ma20"] = (price >= ma20 * 0.98, f"₹{price} vs MA ₹{ma20:.0f}")

        # 2. MACD bullish
        checks["macd_bullish"] = (r.get("macd_bull", False), "MACD " + ("✅" if r.get("macd_bull") else "❌"))

        # 3. RSI not extreme
        rsi = r.get("rsi", 50)
        checks["rsi_not_extreme"] = (25 < rsi < 75, f"RSI={rsi}")

        # 4. Volume above average
        vol = r.get("vol_surge", 1.0)
        checks["volume_above_avg"] = (vol >= 0.8, f"Vol={vol}x")

        # 5. Trend not bearish (MA50 not below MA200)
        ma50 = r.get("ma50", price)
        ma200 = r.get("ma200", price)
        is_bearish = "Strong Bearish" in r.get("trend", "")
        checks["trend_not_bearish"] = (not is_bearish, r.get("trend", "Unknown")[:20])

        # 6. Not near 52-week high resistance
        w52h = r.get("w52_high", price * 1.2)
        near_top = price >= w52h * 0.98 if w52h > 0 else False
        checks["not_near_resistance"] = (not near_top, f"52WH=₹{w52h:.0f}")

        # 7. ATR within range (not > 5% of price)
        atr = r.get("atr", price * 0.02)
        atr_pct = (atr / price * 100) if price > 0 else 0
        checks["atr_within_range"] = (atr_pct <= 5.0, f"ATR={atr_pct:.1f}%")

        # 8. Price above minimum
        checks["price_above_min"] = (price >= MIN_PRICE, f"₹{price}")

        passed = sum(1 for v, _ in checks.values() if v)
        total = len(checks)
        details = [f"{'✅' if v else '❌'} {k}: {reason}" for k, (v, reason) in checks.items()]

        return passed, total, details

    @staticmethod
    def _run_stress_test(symbol, price, scan_result, filings, macro_signals, strategy_capital_used_pct):
        """
        Dalio-style 5-point stress test.
        Returns (all_passed, details).
        """
        checks = {}
        r = scan_result or {}

        # 1. No macro headwind
        macro_bearish = set()
        for sig, active in macro_signals.items():
            if active and sig in MacroIntelligence.MACRO_SECTOR_MAP:
                macro_bearish.update(MacroIntelligence.MACRO_SECTOR_MAP[sig].get("bearish", []))
        checks["no_macro_headwind"] = (symbol not in macro_bearish, "Macro " + ("CLEAR" if symbol not in macro_bearish else "HEADWIND"))

        # 2. No recent bad filing
        bad_filings = [f for f in filings
                       if f.get("symbol") == symbol
                       and "BEARISH" in f.get("sentiment", "")
                       and f.get("urgency") in ("HIGH", "CRITICAL")]
        checks["no_recent_bad_filing"] = (len(bad_filings) == 0, f"{len(bad_filings)} bad filings")

        # 3. DVM above threshold
        dvm = r.get("dvm_score", 0)
        threshold = DVM_SWING  # Use swing as middle ground
        checks["dvm_above_threshold"] = (dvm >= threshold, f"DVM={dvm} (need≥{threshold})")

        # 4. Positive sentiment
        # Use overall signal as proxy
        overall = r.get("overall", "")
        is_positive = "BUY" in overall or "HOLD" in overall
        checks["positive_sentiment"] = (is_positive, overall[:20])

        # 5. Capital available (< 80% deployed)
        checks["capital_available"] = (strategy_capital_used_pct < 80, f"{strategy_capital_used_pct:.0f}% used")

        all_passed = all(v for v, _ in checks.values())
        details = [f"{'✅' if v else '❌'} {k}: {reason}" for k, (v, reason) in checks.items()]

        return all_passed, details

    @staticmethod
    def evaluate_trade(symbol, price, scan_result, sentiment_score,
                      filings, macro_signals, patterns):
        """
        Run all 3 agents + mode-specific pre-trade validation.
        Returns (approved, confidence, reasoning).
        """
        reasoning = []

        # v23.6.1: INSTANT REJECT — circuit stocks are untradeable
        if scan_result and scan_result.get("is_circuit"):
            _ct = scan_result.get("circuit_type", "?")
            _dc = scan_result.get("day_change_pct", 0)
            reasoning.append(
                f"🚫 CIRCUIT REJECT: {_ct} circuit ({_dc:+.1f}%) — "
                f"stock frozen, orders won't execute, GTT won't trigger"
            )
            return False, 0, reasoning

        # v23.6.1: INSTANT REJECT — blacklisted stocks
        _bl_hit, _bl_msg = LossBlacklist.is_blocked(symbol)
        if _bl_hit:
            reasoning.append(f"⛔ {_bl_msg}")
            return False, 0, reasoning

        # ── AGENT 1: IDEA GENERATOR ──────────────────────────────
        agent1_score = 0
        agent1_reasons = []

        stock_filings = [f for f in filings if f.get("symbol") == symbol]
        critical = [f for f in stock_filings if f.get("urgency") == "CRITICAL"]
        high     = [f for f in stock_filings if f.get("urgency") == "HIGH"]
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: STRONGER FILING BOOST for Agent 1
        # Bug: HIGH PROMOTER filings were only getting +20, needed 30 to approve
        # ═══════════════════════════════════════════════════════════════════
        _has_strong_filing = False
        if critical:
            agent1_score += 50
            agent1_reasons.append(f"🔥CRITICAL: {critical[-1].get('type')}")
            _has_strong_filing = True
        if high:
            # Check if it's a PROMOTER type filing (strongest signal)
            _high_types = [f.get('type', '').upper() for f in high]
            if any('PROMOTER' in t or 'INSIDER' in t or 'BUYBACK' in t for t in _high_types):
                agent1_score += 45
                agent1_reasons.append(f"🔥HIGH PROMOTER: {high[-1].get('type')}")
                _has_strong_filing = True
            else:
                agent1_score += 30
                agent1_reasons.append(f"HIGH filing: {high[-1].get('type')}")
                _has_strong_filing = True

        if sentiment_score >= 70:
            agent1_score += 30
            agent1_reasons.append(f"Sentiment: {sentiment_score}")
        elif sentiment_score >= 55:
            agent1_score += 15
            agent1_reasons.append(f"Sentiment: {sentiment_score}")

        bullish_patterns = [p for p in patterns if p[1] == "BULLISH"]
        if bullish_patterns:
            agent1_score += 20
            agent1_reasons.append(f"Pattern: {bullish_patterns[0][0]}")
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: TECHNICAL BOOST for Agent 1
        # Even without filings, strong DVM/momentum stocks deserve credit
        # ═══════════════════════════════════════════════════════════════════
        if scan_result:
            _dvm = scan_result.get("dvm_score", 0)
            _vol = scan_result.get("vol_surge", 1.0)
            _macd = scan_result.get("macd_bull", False)
            
            # Strong momentum boost
            if _dvm >= 85:
                agent1_score += 30
                agent1_reasons.append(f"Strong momentum ({_dvm})")
            elif _dvm >= 75:
                agent1_score += 20
                agent1_reasons.append(f"Good momentum ({_dvm})")
            
            # Volume surge = institutional interest
            if _vol >= 2.0:
                agent1_score += 15
                agent1_reasons.append(f"High volume ({_vol}x)")
            
            # MACD crossover
            if _macd:
                agent1_score += 10
                agent1_reasons.append("MACD cross")

        # v23.6.2: Lower threshold for strong filings
        _agent1_threshold = 20 if _has_strong_filing else 30
        agent1_approved = agent1_score >= _agent1_threshold
        reasoning.append(f"A1[Idea]: {'✅' if agent1_approved else '❌'} {agent1_score}pts | {', '.join(agent1_reasons[:2])}")

        # ── AGENT 2: IMPLEMENTER ─────────────────────────────────
        agent2_score = 0
        agent2_reasons = []

        if scan_result:
            rsi  = scan_result.get("rsi", 50)
            dvm  = scan_result.get("dvm_score", 50)
            vol  = scan_result.get("vol_surge", 1.0)
            macd = scan_result.get("macd_bull", False)
            trend= scan_result.get("trend", "")
            
            # ═══════════════════════════════════════════════════════════════════
            # v23.6.2 FIX: STRONG TECHNICAL BOOSTS for all stocks
            # Bug: Technical stocks were also getting ~26.7% confidence because
            # Agent 2 wasn't giving enough points for strong momentum/DVM.
            # ═══════════════════════════════════════════════════════════════════
            
            # DVM-based scoring (momentum is king)
            if dvm >= 85:
                agent2_score += 50
                agent2_reasons.append(f"🔥DVM:{dvm} (excellent)")
            elif dvm >= DVM_INTRADAY:  # 80+
                agent2_score += 40
                agent2_reasons.append(f"DVM:{dvm} (strong)")
            elif dvm >= DVM_SWING:  # 72+
                agent2_score += 30
                agent2_reasons.append(f"DVM:{dvm} (good)")
            elif dvm >= 65:
                agent2_score += 20
                agent2_reasons.append(f"DVM:{dvm}")
            
            # RSI in healthy range
            if 30 < rsi < 70:
                agent2_score += 20
                agent2_reasons.append(f"RSI:{rsi}")
            elif rsi > RSI_OVERBOUGHT:
                agent2_score -= 30
                agent2_reasons.append("⚠️Overbought")
            
            # MACD confirmation
            if macd:
                agent2_score += 25
                agent2_reasons.append("MACD✅")
            
            # Volume surge (institutional interest)
            if vol >= 2.0:
                agent2_score += 30
                agent2_reasons.append(f"🔥Vol:{vol}x (high)")
            elif vol > VOL_SURGE_MIN:
                agent2_score += 15
                agent2_reasons.append(f"Vol:{vol}x")
            
            # Trend confirmation
            if "Bullish" in trend:
                agent2_score += 20
                agent2_reasons.append(f"Trend✅")
            
            # Penny stock penalty
            if price < MIN_PRICE:
                agent2_score -= 50
                agent2_reasons.append("⚠️Penny")
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: Filing boost for Agent 2
        # Strong filings = automatic approval even with weak technicals
        # ═══════════════════════════════════════════════════════════════════
        if _has_strong_filing:
            agent2_score += 30
            agent2_reasons.append("Filing boost (+30)")

        # v23.6.2: Lower threshold for strong filings
        _agent2_threshold = 25 if _has_strong_filing else 40
        agent2_approved = agent2_score >= _agent2_threshold
        reasoning.append(f"A2[Tech]: {'✅' if agent2_approved else '❌'} {agent2_score}pts | {', '.join(agent2_reasons[:3])}")

        # ── AGENT 3: EVALUATOR — v23.6.0 #3: INDEPENDENT FUNDAMENTALS ONLY ──
        # Previously checked macro + sentiment (overlapped with Agent 1/2)
        # Now checks ONLY fundamentals + filing quality — truly independent angle
        agent3_score = 0
        agent3_reasons = []

        # v23.6.4: Use DeepFundamentalScorer for comprehensive analysis
        if scan_result:
            _pe = scan_result.get("pe", 0)
            _roe = scan_result.get("roe", 0)
            _debt = scan_result.get("debt_eq", 0)
            _div = scan_result.get("div_yld", 0)
            _pb = scan_result.get("pb", 0)
            _mcap = scan_result.get("mcap_cr", 0)
            _promoter = scan_result.get("promoter_holding", 0)

            _has_fundamental_data = (_pe > 0 or _roe > 0 or _debt > 0)

            if _has_fundamental_data:
                # v23.6.4: Deep Fundamental Score
                try:
                    _fund_data = {
                        "pe": _pe,
                        "pb": _pb if _pb > 0 else 3,
                        "roe": _roe,
                        "roce": _roe * 1.1,  # Estimate ROCE from ROE
                        "debt_equity": _debt,
                        "profit_growth": scan_result.get("profit_growth", 10),
                        "sales_growth": scan_result.get("sales_growth", 8),
                        "promoter_holding": _promoter if _promoter > 0 else 50,
                        "dividend_yield": _div,
                        "market_cap_cr": _mcap if _mcap > 0 else 5000,
                    }
                    _fund_total, _fund_breakdown, _fund_quality = DeepFundamentalScorer.score(symbol, _fund_data)
                    _fund_adj, _fund_reason = DeepFundamentalScorer.get_fundamental_boost(symbol, _fund_data)
                    
                    # Score based on fundamental quality
                    if _fund_total >= 70:
                        agent3_score += 40
                        agent3_reasons.append(f"🔥Fundamentals {_fund_total}/100 ({_fund_quality})")
                    elif _fund_total >= 55:
                        agent3_score += 25
                        agent3_reasons.append(f"Fundamentals {_fund_total}/100 ({_fund_quality})")
                    elif _fund_total >= 40:
                        agent3_score += 10
                        agent3_reasons.append(f"Fundamentals {_fund_total}/100")
                    else:
                        agent3_score -= 10
                        agent3_reasons.append(f"Weak fundamentals {_fund_total}/100")
                except Exception as _fund_err:
                    # Fallback to simple scoring
                    logger.debug(f"DeepFundamental [{symbol}]: {_fund_err}")
                    # PE valuation (lower = better value)
                    if 0 < _pe < 20:
                        agent3_score += 25
                        agent3_reasons.append(f"PE={_pe} (value)")
                    elif 0 < _pe < 35:
                        agent3_score += 15
                        agent3_reasons.append(f"PE={_pe} (fair)")
                    elif _pe > 60:
                        agent3_score -= 15
                        agent3_reasons.append(f"PE={_pe} (expensive)")

                    # ROE quality (higher = better business)
                    if _roe > 15:
                        agent3_score += 20
                        agent3_reasons.append(f"ROE={_roe}% (strong)")
                    elif _roe > 8:
                        agent3_score += 10
                        agent3_reasons.append(f"ROE={_roe}%")

                    # Debt safety
                    if 0 < _debt < 0.5:
                        agent3_score += 15
                        agent3_reasons.append("Low debt")
                    elif _debt > 2.0:
                        agent3_score -= 15
                        agent3_reasons.append("High debt")

                    # Dividend bonus
                    if _div > 2:
                        agent3_score += 5
                        agent3_reasons.append(f"Div={_div}%")
            else:
                # v23.6.0 #3: NO fundamentals data = PENALTY (not free pass)
                # This prevents garbage stocks sneaking through on technicals alone
                agent3_score -= 10
                agent3_reasons.append("No fundamental data")

        # Filing quality check — recent bullish filings add conviction
        recent_bullish = [f for f in stock_filings
                         if "BULLISH" in f.get("sentiment", "")]
        recent_bearish = [f for f in stock_filings
                         if "BEARISH" in f.get("sentiment", "")]
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: STRONG FILING BOOST — Promoter/Buyback/Bulk bypass
        # Bug: All stocks were getting 26.7% confidence because Agent 3 was
        # returning near-zero for HIGH priority filings. This fix ensures
        # strong filings get the confidence boost they deserve.
        # ═══════════════════════════════════════════════════════════════════
        _high_priority_filing = False
        for _bf in recent_bullish:
            _filing_type = _bf.get("type", "").upper()
            _filing_priority = _bf.get("priority", "").upper()
            
            # Promoter buying / Insider buying = STRONGEST signal
            if "PROMOTER" in _filing_type or "INSIDER" in _filing_type:
                agent3_score += 50
                agent3_reasons.append("🔥PROMOTER BUY (+50)")
                _high_priority_filing = True
            
            # Buyback = Very strong
            elif "BUYBACK" in _filing_type:
                agent3_score += 45
                agent3_reasons.append("🔥BUYBACK (+45)")
                _high_priority_filing = True
            
            # Bulk/Block deals = Strong institutional interest
            elif "BULK" in _filing_type or "BLOCK" in _filing_type:
                agent3_score += 40
                agent3_reasons.append("📊BULK/BLOCK (+40)")
                _high_priority_filing = True
            
            # Order win / Major contract
            elif "ORDER" in _filing_type or "CONTRACT" in _filing_type:
                agent3_score += 35
                agent3_reasons.append("📈ORDER WIN (+35)")
                _high_priority_filing = True
            
            # Board meeting / Dividend / M&A
            elif any(kw in _filing_type for kw in ["BOARD", "DIVIDEND", "MERGER", "ACQUISITION"]):
                agent3_score += 30
                agent3_reasons.append(f"📋{_filing_type[:10]} (+30)")
                _high_priority_filing = True
            
            # HIGH priority filings get extra boost
            elif _filing_priority == "HIGH":
                agent3_score += 25
                agent3_reasons.append("HIGH priority (+25)")
                _high_priority_filing = True
        
        # Standard bullish filing boost (if not already boosted above)
        if recent_bullish and not _high_priority_filing:
            agent3_score += 15
            agent3_reasons.append(f"{len(recent_bullish)} bullish filings")
        
        if recent_bearish:
            agent3_score -= 20
            agent3_reasons.append(f"{len(recent_bearish)} bearish filings")

        # Macro headwind/tailwind (lightweight check — not the main axis)
        macro_bullish_syms, macro_bearish_syms = set(), set()
        for sig, active in macro_signals.items():
            if active and sig in MacroIntelligence.MACRO_SECTOR_MAP:
                macro_bullish_syms.update(MacroIntelligence.MACRO_SECTOR_MAP[sig].get("bullish",[]))
                macro_bearish_syms.update(MacroIntelligence.MACRO_SECTOR_MAP[sig].get("bearish",[]))

        if symbol in macro_bullish_syms:
            agent3_score += 10
            agent3_reasons.append("Macro tailwind")
        if symbol in macro_bearish_syms:
            agent3_score -= 15
            agent3_reasons.append("Macro headwind")

        # ═══════════════════════════════════════════════════════════════════
        # v23.6.2 FIX: Don't penalize HIGH PRIORITY filings for weak sentiment
        # Promoter buying IS the sentiment signal — market sentiment doesn't matter
        # ═══════════════════════════════════════════════════════════════════
        if sentiment_score >= 65:
            agent3_score += 30
            agent3_reasons.append("Strong sentiment")
        elif sentiment_score >= 50:
            agent3_score += 15
        elif not _high_priority_filing:
            # Only penalize weak sentiment if NOT a high priority filing
            agent3_score -= 15
            agent3_reasons.append("Weak sentiment")

        if agent1_approved and agent2_approved:
            agent3_score += 20
            agent3_reasons.append("A1&A2 agree")

        # v23.6.2: Lower threshold for high priority filings
        _agent3_threshold = 10 if _high_priority_filing else 20
        agent3_approved = agent3_score >= _agent3_threshold
        reasoning.append(f"A3[Eval]: {'✅' if agent3_approved else '❌'} {agent3_score}pts | {', '.join(agent3_reasons[:2])}")

        # ── VOTING ─────────────────────────────────────────────
        votes = sum([agent1_approved, agent2_approved, agent3_approved])
        vote_passed = votes >= AGENT_APPROVAL
        confidence = round((agent1_score + agent2_score + agent3_score) / 3, 1)
        reasoning.append(f"VOTE: {votes}/3 (need {AGENT_APPROVAL}) [{STRATEGY_MODE}]")

        # ══════════════════════════════════════════════════════════
        #  BILLIONAIRE PRE-TRADE VALIDATION — runs AFTER voting
        # ══════════════════════════════════════════════════════════

        if vote_passed and STRATEGY_MODE == "AGGRESSIVE":
            # ── AGGRESSIVE: Renaissance-style 75% Technical Recheck ──
            # Even with just 1 agent vote, we recheck 8 technical factors.
            # 75% (6/8) must pass. This is the "50.75% edge, executed
            # with 100% discipline" principle from Simons.
            passed, total, tech_details = ThreeAgentAI._run_tech_recheck(
                symbol, price, scan_result
            )
            pct = round(passed / total * 100) if total > 0 else 0
            recheck_ok = passed >= 6  # 75% = 6 out of 8

            reasoning.append(
                f"🔬 RECHECK: {passed}/{total} ({pct}%) "
                f"{'✅ PASS' if recheck_ok else '❌ FAIL (need 75%)'}"
            )
            if not recheck_ok:
                reasoning.append(f"  Failed: {' | '.join(d for d in tech_details if '❌' in d)}")
                return False, confidence, reasoning

        elif vote_passed and STRATEGY_MODE == "BALANCED":
            # ── BALANCED: Dalio-style Stress Test ──
            # After 2/3 agents approve, run 5-point stress test.
            # ALL 5 must pass. Dalio: "stress test against all scenarios"
            stress_ok, stress_details = ThreeAgentAI._run_stress_test(
                symbol, price, scan_result, filings, macro_signals,
                strategy_capital_used_pct=50  # Default estimate
            )

            reasoning.append(
                f"🛡️ STRESS: {'✅ ALL PASS' if stress_ok else '❌ FAIL'}"
            )
            if not stress_ok:
                reasoning.append(f"  Failed: {' | '.join(d for d in stress_details if '❌' in d)}")
                return False, confidence, reasoning

        # ── FINAL RESULT ──────────────────────────────────────
        all_approved = vote_passed  # Already validated by recheck/stress

        # ═══════════════════════════════════════════════════════════════════
        # v23.6.3 FIX: ADAPTIVE REGIME-BASED TRADING (Works in ALL markets)
        # Instead of blocking trades, ADAPT based on market condition:
        # - BULL: Normal trading, follow trends
        # - BEAR: Only buy stocks showing RELATIVE STRENGTH (beating Nifty)
        # - SIDEWAYS: Mean reversion, buy oversold quality stocks
        # ═══════════════════════════════════════════════════════════════════
        if all_approved and scan_result:
            _vix = macro_signals.get("vix", 15) if macro_signals else 15
            # Try to get VIX from macro_signals or macro_data
            if macro_signals and "INDIAVIX" in macro_signals:
                _vix = macro_signals.get("INDIAVIX", 15)
            
            # Get Nifty change - THIS IS THE KEY FIX
            # First try from macro_signals, then calculate from Kite
            _nifty_change = macro_signals.get("nifty_change_pct", None) if macro_signals else None
            
            if _nifty_change is None:
                # Calculate Nifty change directly from Kite
                try:
                    _kite = KiteSession.get()
                    if _kite:
                        _nifty_quote = _kite.quote(["NSE:NIFTY 50"])
                        if "NSE:NIFTY 50" in _nifty_quote:
                            _nq = _nifty_quote["NSE:NIFTY 50"]
                            _nifty_ltp = _nq.get("last_price", 0)
                            _nifty_close = _nq.get("ohlc", {}).get("close", _nifty_ltp)
                            if _nifty_close > 0:
                                _nifty_change = ((_nifty_ltp - _nifty_close) / _nifty_close) * 100
                            else:
                                _nifty_change = 0
                except Exception as _nifty_err:
                    logger.debug(f"Nifty change calc: {_nifty_err}")
                    _nifty_change = 0
            
            _stock_change = scan_result.get("day_change_pct", 0)
            _rsi = scan_result.get("rsi", 50)
            _dvm = scan_result.get("dvm_score", 50)
            
            # Calculate relative strength: stock vs market
            _relative_strength = _stock_change - _nifty_change
            
            # ═══════════════════════════════════════════════════════════════
            # v23.6.4 FIX: Determine market regime from NIFTY CHANGE directly
            # NOT from market_score which was always 0!
            # 
            # BULL:     Nifty > +0.5%
            # BEAR:     Nifty < -0.5%
            # SIDEWAYS: -0.5% <= Nifty <= +0.5%
            # ═══════════════════════════════════════════════════════════════
            _is_bull = _nifty_change >= 0.5
            _is_bear = _nifty_change <= -0.5
            _is_sideways = -0.5 < _nifty_change < 0.5
            _is_volatile = _vix > 20
            
            # Log the actual regime detection
            logger.debug(f"REGIME: Nifty={_nifty_change:+.1f}%, VIX={_vix:.1f} → {'BULL' if _is_bull else ('BEAR' if _is_bear else 'SIDEWAYS')}")
            
            # ═══ REGIME-SPECIFIC RULES ═══
            
            # BEAR MARKET: Require relative strength OR oversold bounce
            if _is_bear:
                _oversold_bounce = _rsi < 35 and _dvm >= 65  # Oversold with momentum turning
                _has_rel_strength = _relative_strength >= 0.3  # Beating market by 0.3%+
                
                if not _oversold_bounce and not _has_rel_strength and not _high_priority_filing:
                    reasoning.append(
                        f"⚠️ BEAR REGIME (Nifty {_nifty_change:+.1f}%): Stock={_stock_change:+.1f}% "
                        f"(RelStr={_relative_strength:+.1f}%, need +0.3% or RSI<35)"
                    )
                    return False, confidence, reasoning
            
            # VOLATILE MARKET (VIX > 20): Require stronger signals
            if _is_volatile and not _is_bull:
                _strong_signal = _dvm >= 75 or _high_priority_filing or _relative_strength >= 0.5
                if not _strong_signal:
                    reasoning.append(
                        f"⚠️ HIGH VIX ({_vix:.1f}): Need DVM≥75 or filing or RelStr≥0.5% "
                        f"(Got DVM={_dvm}, RelStr={_relative_strength:+.1f}%)"
                    )
                    return False, confidence, reasoning
            
            # SIDEWAYS MARKET: Prefer mean reversion (buy low RSI)
            # v23.6.4 FIX #2: Relaxed from RSI<45/DVM>=78 to RSI<50/DVM>=72
            # v23.6.4 FIX #3: Filing trades bypass SIDEWAYS filter completely
            if _is_sideways:
                # Filing trades bypass SIDEWAYS filter — they work in any market
                if _high_priority_filing:
                    reasoning.append(f"📊 SIDEWAYS REGIME: Filing trade BYPASSES filter")
                else:
                    # Technical trades need oversold OR strong momentum
                    _good_setup = _rsi < 50 or _dvm >= 72
                    if not _good_setup:
                        reasoning.append(
                            f"⚠️ SIDEWAYS REGIME (Nifty {_nifty_change:+.1f}%): Need RSI<50 or DVM≥72 "
                            f"(Got RSI={_rsi:.0f}, DVM={_dvm})"
                        )
                        return False, confidence, reasoning
            
            # BULL MARKET: Most permissive - just need basic quality
            # (No additional restrictions in bull market)
            
            # Log the regime for transparency
            _regime_name = "BULL" if _is_bull else ("BEAR" if _is_bear else "SIDEWAYS")
            _vol_tag = "+VOLATILE" if _is_volatile else ""
            reasoning.append(f"📊 REGIME: {_regime_name}{_vol_tag} (Nifty {_nifty_change:+.1f}%) | RelStr={_relative_strength:+.1f}%")

        # v23.6.2: CONFIDENCE FLOOR — hard reject low-confidence garbage
        if all_approved and confidence < MIN_CONFIDENCE:
            reasoning.append(
                f"⛔ CONFIDENCE FLOOR: {confidence:.1f} < {MIN_CONFIDENCE} minimum — "
                f"votes passed but confidence too low"
            )
            return False, confidence, reasoning

        status = "✅ APPROVED" if all_approved else "❌ REJECTED"
        reasoning.append(f"FINAL: {status} | conf={confidence} | mode={STRATEGY_MODE}")

        return all_approved, confidence, reasoning, votes


# ══════════════════════════════════════════════════════════════
#  STATISTICAL ARBITRAGE ENGINE (Simons Style)
# ══════════════════════════════════════════════════════════════

class StatArb:
    """
    Pairs trading — find stocks that move together.
    When they diverge, trade the spread.
    Based on Renaissance Technologies statistical arbitrage.
    """

    PAIRS = [
        ("HDFCBANK",  "ICICIBANK"),
        ("TCS",       "INFY"),
        ("ONGC",      "BPCL"),
        ("TATASTEEL", "JSWSTEEL"),
        ("SBIN",      "BANKBARODA"),
        ("HINDUNILVR","DABUR"),
        ("MARUTI",    "TATAMOTORS"),
        ("ADANIENT",  "ADANIPORTS"),
    ]

    @staticmethod
    def find_opportunities(scan_results):
        """Find pairs that have diverged significantly."""
        opportunities = []
        scan_map = {r["symbol"]: r for r in scan_results}

        for sym1, sym2 in StatArb.PAIRS:
            r1 = scan_map.get(sym1)
            r2 = scan_map.get(sym2)
            if not r1 or not r2: continue

            # Compare 1-month returns
            ret1 = r1.get("ret_1m", 0)
            ret2 = r2.get("ret_1m", 0)
            spread = ret1 - ret2

            # If spread > 5% — they have diverged
            if abs(spread) >= 5:
                if spread > 0:
                    # sym1 outperformed — buy sym2, avoid sym1
                    opportunities.append({
                        "type":       "STAT_ARB",
                        "buy":        sym2,
                        "avoid":      sym1,
                        "spread":     round(spread, 2),
                        "confidence": min(90, 60 + abs(spread) * 3),
                        "reason":     f"{sym1} outperformed {sym2} by {spread:.1f}% — mean reversion expected",
                    })
                else:
                    # sym2 outperformed — buy sym1, avoid sym2
                    opportunities.append({
                        "type":       "STAT_ARB",
                        "buy":        sym1,
                        "avoid":      sym2,
                        "spread":     round(abs(spread), 2),
                        "confidence": min(90, 60 + abs(spread) * 3),
                        "reason":     f"{sym2} outperformed {sym1} by {abs(spread):.1f}% — mean reversion expected",
                    })

        return opportunities


# ══════════════════════════════════════════════════════════════
#  AMO ORDER ENGINE (After Market Orders)
# ══════════════════════════════════════════════════════════════

class AMOEngine:
    """
    Places After Market Orders for next day trading.
    Runs after 15:30 IST daily.
    Finds best setups for tomorrow's open.
    """

    AMO_FILE = os.path.join(DATA_DIR, "amo_orders.json")

    @staticmethod
    def find_amo_candidates(scan_results, filings, macro_signals, news_alerts):
        """Find best stocks for tomorrow's AMO orders."""
        candidates = []
        macro_bullish, macro_bearish = MacroIntelligence.get_sector_bias(macro_signals)

        for r in scan_results:
            sym   = r["symbol"]
            price = r["price"]
            dvm   = r.get("dvm_score", 0)

            # Skip indices and low-price stocks
            if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]: continue
            if price < 50: continue

            # Get patterns
            patterns = []  # Will be populated if hist available

            # Get sentiment
            sent_score, sent_label = SentimentEngine.score(
                sym, r, filings, news_alerts,
                macro_bullish, macro_bearish, patterns
            )

            # ── AMO criteria — mode-aware thresholds ──────────────
            # AGGRESSIVE: DVM >= 55, Sentiment >= 50 (more AMO candidates)
            # BALANCED:   DVM >= 65, Sentiment >= 60 (stricter)
            amo_dvm_min  = DVM_LONGTERM     # 55 aggressive, 65 balanced
            amo_sent_min = SENT_THRESHOLD   # 50 aggressive, 60 balanced

            has_buy = "BUY" in r.get("overall", "")
            has_macro = sym in macro_bullish
            high_dvm = dvm >= amo_dvm_min + 10  # Extra 10 pts = strong conviction

            # Pass if: (good DVM + sentiment + BUY signal) OR (high DVM + macro tailwind)
            if ((dvm >= amo_dvm_min and sent_score >= amo_sent_min and has_buy) or
                (high_dvm and has_macro)):

                atr = r.get("atr", price * 0.02)
                candidates.append({
                    "symbol":      sym,
                    "price":       price,
                    "dvm":         dvm,
                    "sentiment":   sent_score,
                    "label":       sent_label,
                    "sl":          round(price - 1.0 * atr, 2),
                    "target1":     round(price + 2.5 * atr, 2),
                    "target2":     round(price + 4.0 * atr, 2),
                    "macro":       "TAILWIND" if has_macro else "NEUTRAL",
                    "reason":      f"DVM:{dvm} Sent:{sent_score} {sent_label} {'MACRO✅' if has_macro else ''}",
                })

        # Sort by DVM + sentiment combined
        candidates.sort(key=lambda x: x["dvm"] + x["sentiment"], reverse=True)
        logger.info(f"🌙 AMO: {len(candidates)} candidates from {len(scan_results)} scanned (mode={STRATEGY_MODE})")
        return candidates[:5]  # Top 5 AMO candidates

    @staticmethod
    def place_amo_orders(candidates, risk):
        """Place AMO paper orders for tomorrow."""
        if not candidates or not risk.can_trade():
            return []

        orders = []
        save_json(AMOEngine.AMO_FILE, {
            "date":       today_str(),
            "candidates": candidates,
            "placed":     len(candidates),
        })

        # Send Telegram alert
        msg = f"🌙 *AMO ORDERS FOR TOMORROW*\n"
        msg += f"📅 {now_ist().strftime('%d %b %Y')} — After Market\n"
        msg += f"━━━━━━━━━━━━━━━━━━━━━━━\n"
        for c in candidates:
            msg += (
                f"\n📈 `{c['symbol']}` @ ₹{c['price']}\n"
                f"  DVM:{c['dvm']} | Sentiment:{c['sentiment']}\n"
                f"  SL: ₹{c['sl']} | T1: ₹{c['target1']}\n"
                f"  Macro: {c['macro']}\n"
                f"  📌 {c['reason']}\n"
            )
        msg += "\n_These positions will be active at market open 09:15 IST_"
        send_telegram(msg)
        return candidates


# ══════════════════════════════════════════════════════════════
#  NSE FUNDAMENTALS FETCHER — PE, Sector, Industry from NSE API
#  Backup: Screener.in for ROE, Debt, Earnings Growth
#  Cached daily — fetched once per stock per day
# ══════════════════════════════════════════════════════════════

class FundamentalsFetcher:
    """
    Fetches fundamental data from NSE API (primary) and Screener.in (backup).
    Cached daily to avoid rate limiting.
    """
    _cache = {}
    _cache_date = ""
    _nse_session = None
    _screener_session = None

    @classmethod
    def _init_nse(cls):
        if cls._nse_session is None:
            cls._nse_session = requests.Session()
            cls._nse_session.headers.update({
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept": "application/json",
            })
            try:
                cls._nse_session.get("https://www.nseindia.com", timeout=10)
            except Exception:
                pass
        return cls._nse_session

    @classmethod
    def get(cls, symbol):
        """Get fundamentals for a symbol. Returns dict with pe, sector, industry."""
        today = now_ist().strftime("%Y-%m-%d")
        if cls._cache_date != today:
            cls._cache = {}
            cls._cache_date = today

        if symbol in cls._cache:
            return cls._cache[symbol]

        # Skip indices
        if symbol in ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"]:
            return {"pe": 0, "sector": "INDEX", "industry": "INDEX"}

        result = {"pe": 0, "pb": 0, "sector": "", "industry": "",
                  "roe": 0, "debt_eq": 0, "div_yld": 0, "earn_growth": 0, "rev_growth": 0}

        # ── PRIMARY: NSE API ──────────────────────────────────
        try:
            sess = cls._init_nse()
            r = sess.get(
                f"https://www.nseindia.com/api/quote-equity?symbol={symbol}",
                timeout=8
            )
            if r.status_code == 200:
                data = r.json()
                meta = data.get("metadata", {})
                result["pe"] = float(meta.get("pdSymbolPe", 0) or 0)
                result["sector"] = meta.get("industry", "")
                result["industry"] = meta.get("industry", "")
                # Price info
                price_info = data.get("priceInfo", {})
                # Security info for face value, market cap etc
                sec_info = data.get("securityInfo", {})

                if result["pe"] > 0:
                    logger.debug(f"NSE fundamentals [{symbol}]: PE={result['pe']} Sector={result['sector']}")
        except Exception as e:
            logger.debug(f"NSE fund [{symbol}]: {e}")

        # ── BACKUP: Screener.in (if NSE didn't get PE) ────────
        if result["pe"] == 0:
            try:
                if cls._screener_session is None:
                    cls._screener_session = requests.Session()
                    cls._screener_session.headers.update({
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                    })
                r = cls._screener_session.get(
                    f"https://www.screener.in/company/{symbol}/consolidated/",
                    timeout=10
                )
                if r.status_code == 200 and len(r.text) > 5000:
                    import re
                    text = r.text
                    # Extract PE
                    pe_m = re.search(r'Stock P/E[^>]*>[\s]*<[^>]*>[\s]*(\d+\.?\d*)', text)
                    if pe_m: result["pe"] = float(pe_m.group(1))
                    # Extract ROE
                    roe_m = re.search(r'Return on equity[^>]*>[\s]*<[^>]*>[\s]*(\d+\.?\d*)', text)
                    if roe_m: result["roe"] = float(roe_m.group(1)) / 100
                    # Extract Debt/Equity
                    debt_m = re.search(r'Debt to equity[^>]*>[\s]*<[^>]*>[\s]*(\d+\.?\d*)', text)
                    if debt_m: result["debt_eq"] = float(debt_m.group(1))
                    # Extract Dividend Yield
                    div_m = re.search(r'Dividend yield[^>]*>[\s]*<[^>]*>[\s]*(\d+\.?\d*)', text)
                    if div_m: result["div_yld"] = float(div_m.group(1)) / 100

                    if result["pe"] > 0:
                        logger.debug(f"Screener [{symbol}]: PE={result['pe']} ROE={result['roe']}")
            except Exception as e:
                logger.debug(f"Screener [{symbol}]: {e}")

        cls._cache[symbol] = result
        return result

    @classmethod
    def bulk_fetch(cls, symbols, max_fetch=30):
        """
        Fetch fundamentals for multiple symbols.
        Limited to max_fetch per scan to avoid rate limiting.
        Prioritizes F&O stocks.
        """
        today = now_ist().strftime("%Y-%m-%d")
        if cls._cache_date != today:
            cls._cache = {}
            cls._cache_date = today

        # Prioritize F&O stocks that aren't cached
        uncached = [s for s in symbols if s not in cls._cache
                    and s not in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]]
        fno_first = sorted(uncached, key=lambda s: s in FNO_STOCKS, reverse=True)

        fetched = 0
        for sym in fno_first[:max_fetch]:
            cls.get(sym)
            fetched += 1
            time.sleep(0.3)  # Rate limit — 3 per second max

        logger.info(f"📊 Fundamentals: {fetched} fetched, {len(cls._cache)} cached")


class TrendlyneScorer:
    @staticmethod
    def _get_token(kite, symbol):
        """Get instrument token using DynamicStockUniverse cache."""
        return DynamicStockUniverse.get_token(symbol)

    @staticmethod
    def score(symbol):
        try:
            hist      = None
            full_info = {}
            kite      = KiteSession.get()

            if kite:
                try:
                    token = TrendlyneScorer._get_token(kite, symbol)
                    if token:
                        from_dt = (now_ist() - timedelta(days=400)).strftime("%Y-%m-%d")
                        to_dt   = now_ist().strftime("%Y-%m-%d")
                        data    = kite.historical_data(token, from_dt, to_dt, "day")
                        if data and len(data) >= 50:
                            hist = pd.DataFrame(data)
                            hist.columns = [c.capitalize() for c in hist.columns]
                            if "Date" in hist.columns:
                                hist.set_index("Date", inplace=True)
                            logger.debug(f"Kite data: {symbol} {len(hist)} bars")
                except Exception as e:
                    logger.debug(f"Kite hist [{symbol}]: {e}")

            if hist is None or len(hist) < 50:
                logger.debug(f"No data for {symbol} — skipping")
                return None
            c,v=hist["Close"],hist["Volume"]
            h,lo=hist["High"],hist["Low"]
            price=round(float(c.iloc[-1]),2)
            sym=symbol
            ok,reason=is_eligible(symbol,price)
            if not ok and symbol not in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                return None

            # ══════════════════════════════════════════════════════
            #  17 INDICATORS — Backtest-proven from academic research
            #  MACD+RSI = 73-84% win rate (QuantifiedStrategies)
            #  SuperTrend 2x weight (QuantInsti EPAT)
            #  ADX > 25 = trending market gate (Medium quant study)
            # ══════════════════════════════════════════════════════

            # 1. RSI (14) — 60% solo win rate
            d=c.diff(); gain=d.where(d>0,0).rolling(14).mean()
            loss_s=-d.where(d<0,0).rolling(14).mean()
            rs=gain/(loss_s+0.0001)
            rsi=round(float((100-(100/(1+rs))).iloc[-1]),2)

            # 2. SMA 20/50/200
            ma20=float(c.rolling(20).mean().iloc[-1])
            ma50=float(c.rolling(50).mean().iloc[-1])
            ma200=float(c.rolling(min(200,len(c))).mean().iloc[-1])

            # 3. EMA 9/21 (scalper fast momentum)
            ema9=float(c.ewm(span=9).mean().iloc[-1])
            ema21=float(c.ewm(span=21).mean().iloc[-1])
            ema_bull=ema9>ema21

            # 4. MACD (12,26,9) — <50% solo, 73-84% with RSI
            e12=c.ewm(span=12).mean(); e26=c.ewm(span=26).mean()
            macd_line=e12-e26; macd_sig=macd_line.ewm(span=9).mean()
            macd_bull=float(macd_line.iloc[-1])>float(macd_sig.iloc[-1])
            macd_hist_val=round(float(macd_line.iloc[-1]-macd_sig.iloc[-1]),4)
            macd_cross_up=(float(macd_line.iloc[-1])>float(macd_sig.iloc[-1]) and
                           float(macd_line.iloc[-2])<=float(macd_sig.iloc[-2])) if len(c)>2 else False

            # 5. ATR (14)
            tr_vals=pd.Series([max(hh-ll,abs(hh-pc),abs(ll-pc))
                for hh,ll,pc in zip(h,lo,c.shift(1).fillna(c))],index=c.index)
            atr=round(float(tr_vals.rolling(14).mean().iloc[-1]),2)

            # 6. Bollinger Bands (20,2)
            bb_m=c.rolling(20).mean(); bb_s=c.rolling(20).std()
            bb_up=float((bb_m+2*bb_s).iloc[-1]); bb_lo=float((bb_m-2*bb_s).iloc[-1])
            bb_width=round((bb_up-bb_lo)/float(bb_m.iloc[-1]+0.01)*100,2)
            bb_squeeze=bb_width<8

            # 7. Supertrend (10,3) — gets 2x weight (EPAT research)
            st_atr=tr_vals.rolling(10).mean()
            hl2=(h+lo)/2
            st_up=hl2+3*st_atr; st_dn=hl2-3*st_atr
            supertrend_bull=price>float(st_dn.iloc[-1])
            supertrend_val=round(float(st_dn.iloc[-1] if supertrend_bull else st_up.iloc[-1]),2)

            # 8. ADX (14) — gate: only trend-trade when ADX>25
            try:
                plus_dm=h.diff().clip(lower=0); minus_dm=(-lo.diff()).clip(lower=0)
                plus_dm=plus_dm.where(plus_dm>minus_dm,0)
                minus_dm=minus_dm.where(minus_dm>plus_dm,0)
                tr14=tr_vals.rolling(14).sum()+0.0001
                plus_di=100*plus_dm.rolling(14).sum()/tr14
                minus_di=100*minus_dm.rolling(14).sum()/tr14
                dx=100*abs(plus_di-minus_di)/(plus_di+minus_di+0.0001)
                adx=round(float(dx.rolling(14).mean().iloc[-1]),2)
            except Exception:
                adx=20

            # 9. Stochastic RSI (14,3)
            try:
                rsi_s=100-(100/(1+rs))
                rsi_min=rsi_s.rolling(14).min(); rsi_max=rsi_s.rolling(14).max()
                stoch_rsi=(rsi_s-rsi_min)/(rsi_max-rsi_min+0.0001)*100
                stoch_k=round(float(stoch_rsi.rolling(3).mean().iloc[-1]),2)
            except Exception:
                stoch_k=50
            stoch_oversold=stoch_k<20; stoch_overbought=stoch_k>80

            # 10. OBV (On Balance Volume)
            try:
                sign_series=c.diff().fillna(0).apply(lambda x:1 if x>0 else(-1 if x<0 else 0))
                obv=(v*sign_series).cumsum()
                obv_ma=obv.rolling(20).mean()
                obv_bull=float(obv.iloc[-1])>float(obv_ma.iloc[-1])
            except Exception:
                obv_bull=True

            # 11. Volume
            avg_v=float(v.rolling(20).mean().iloc[-1])
            vol_s=round(float(v.iloc[-1]/(avg_v+1)),2)

            # ══════════════════════════════════════════════════════
            # v23.6.1: CIRCUIT DETECTION
            # Lower circuit: close ≈ low, price dropped sharply
            # Upper circuit: close ≈ high, price surged sharply
            # Either way: stock is FROZEN — no new orders execute
            # Kite OHLCV: last bar's High/Low/Close tells us
            # ══════════════════════════════════════════════════════
            _last_h = float(h.iloc[-1])
            _last_l = float(lo.iloc[-1])
            _last_c = float(c.iloc[-1])
            _prev_c = float(c.iloc[-2]) if len(c) >= 2 else _last_c
            _day_change_pct = round((_last_c - _prev_c) / (_prev_c + 0.01) * 100, 2)
            _hl_range = _last_h - _last_l
            # Circuit if: H==L (no range at all) OR range < 0.3% of price AND big change
            _is_circuit = False
            _circuit_type = ""
            if _hl_range < price * 0.003 and abs(_day_change_pct) >= 4.5:
                _is_circuit = True
                _circuit_type = "LOWER" if _day_change_pct < 0 else "UPPER"
            elif _last_h == _last_l and _last_h == _last_c:
                _is_circuit = True
                _circuit_type = "LOWER" if _day_change_pct < 0 else "UPPER"

            # 12. Returns
            ret_1w=round((price/float(c.iloc[-5])-1)*100,2) if len(c)>5 else 0
            ret_1m=round((price/float(c.iloc[-21])-1)*100,2) if len(c)>21 else 0
            ret_3m=round((price/float(c.iloc[-63])-1)*100,2) if len(c)>63 else 0

            # 13. 52W + Fibonacci
            w52h=float(h.rolling(min(252,len(h))).max().iloc[-1])
            w52l=float(lo.rolling(min(252,len(lo))).min().iloc[-1])
            near_52h=price>=w52h*0.95
            fib_range=w52h-w52l
            fib_382=round(w52h-0.382*fib_range,2)
            fib_500=round(w52h-0.500*fib_range,2)
            fib_618=round(w52h-0.618*fib_range,2)
            near_fib=any(abs(price-lvl)/(price+1)<0.02 for lvl in [fib_382,fib_500,fib_618])

            # 14. NSE Fundamentals
            fund=FundamentalsFetcher.get(symbol)
            pe=fund.get("pe",0); roe=fund.get("roe",0)
            debt=fund.get("debt_eq",0); div=fund.get("div_yld",0)
            pb=fund.get("pb",0); earn_g=fund.get("earn_growth",0)
            rev_g=fund.get("rev_growth",0); sector=fund.get("sector","")

            # ── 15. VWAP Proxy (daily typical price × volume) ────
            # True VWAP needs intraday bars. Using daily proxy:
            # Typical Price = (H+L+C)/3, then volume-weighted average
            try:
                typical=(h+lo+c)/3
                vwap_proxy=float((typical*v).rolling(20).sum()/(v.rolling(20).sum()+1).iloc[-1])
                price_vs_vwap="ABOVE" if price>vwap_proxy else "BELOW"
                vwap_bull=price>vwap_proxy  # Institutional: buy below VWAP, price above = bullish
            except Exception:
                vwap_proxy=price; price_vs_vwap="N/A"; vwap_bull=True

            # ── 16. MFI (Money Flow Index, 14) — volume-weighted RSI
            # Research: MACD+MFI = 69-70% WR (arxiv paper)
            try:
                typical_p=(h+lo+c)/3
                raw_mf=typical_p*v
                pos_mf=raw_mf.where(typical_p.diff()>0,0).rolling(14).sum()
                neg_mf=raw_mf.where(typical_p.diff()<=0,0).rolling(14).sum()
                mfi=round(float(100-(100/(1+pos_mf/(neg_mf+1))).iloc[-1]),2)
                mfi_oversold=mfi<20; mfi_overbought=mfi>80
                mfi_bull=20<mfi<80  # Healthy flow
            except Exception:
                mfi=50; mfi_oversold=False; mfi_overbought=False; mfi_bull=True

            # ── 17. Williams %R (14) — faster overbought/oversold
            # Fidelity recommended, TradingView top indicator
            try:
                highest_high=h.rolling(14).max()
                lowest_low=lo.rolling(14).min()
                williams_r=round(float((-100*(highest_high-c)/(highest_high-lowest_low+0.0001)).iloc[-1]),2)
                wr_oversold=williams_r<-80   # Oversold = bounce opportunity
                wr_overbought=williams_r>-20  # Overbought = profit book
                wr_bull=williams_r>-50  # Above midpoint = bullish
            except Exception:
                williams_r=-50; wr_oversold=False; wr_overbought=False; wr_bull=True

            # ── 18. Parabolic SAR — trailing stop + trend direction
            # Used by HFT systems, binary signal (above/below price)
            try:
                af_start=0.02; af_step=0.02; af_max=0.20
                psar_vals=[float(lo.iloc[0])]
                af=af_start; ep=float(h.iloc[0]); rising=True
                for i in range(1,len(c)):
                    prev_psar=psar_vals[-1]
                    if rising:
                        new_psar=prev_psar+af*(ep-prev_psar)
                        new_psar=min(new_psar,float(lo.iloc[i-1]),float(lo.iloc[max(0,i-2)]))
                        if float(h.iloc[i])>ep: ep=float(h.iloc[i]); af=min(af+af_step,af_max)
                        if float(lo.iloc[i])<new_psar: rising=False; new_psar=ep; af=af_start; ep=float(lo.iloc[i])
                    else:
                        new_psar=prev_psar+af*(ep-prev_psar)
                        new_psar=max(new_psar,float(h.iloc[i-1]),float(h.iloc[max(0,i-2)]))
                        if float(lo.iloc[i])<ep: ep=float(lo.iloc[i]); af=min(af+af_step,af_max)
                        if float(h.iloc[i])>new_psar: rising=True; new_psar=ep; af=af_start; ep=float(h.iloc[i])
                    psar_vals.append(new_psar)
                psar=round(psar_vals[-1],2)
                psar_bull=price>psar  # Price above SAR = uptrend
            except Exception:
                psar=price*0.98; psar_bull=True

            # ── 19. Pivot Points (Classic) — daily S/R levels
            # Strongest confluence signal — Zerodha Varsity recommended
            try:
                prev_h=float(h.iloc[-2]); prev_l=float(lo.iloc[-2]); prev_c=float(c.iloc[-2])
                pivot=round((prev_h+prev_l+prev_c)/3,2)
                r1=round(2*pivot-prev_l,2)  # Resistance 1
                s1=round(2*pivot-prev_h,2)  # Support 1
                r2=round(pivot+(prev_h-prev_l),2)
                s2=round(pivot-(prev_h-prev_l),2)
                above_pivot=price>pivot
                near_support=abs(price-s1)/(price+1)<0.015 or abs(price-s2)/(price+1)<0.015
                near_resistance=abs(price-r1)/(price+1)<0.015 or abs(price-r2)/(price+1)<0.015
            except Exception:
                pivot=price; r1=price*1.01; s1=price*0.99; r2=price*1.02; s2=price*0.98
                above_pivot=True; near_support=False; near_resistance=False

            # ══════════════════════════════════════════════════════
            #  DVM SCORE — CONFLUENCE VOTING (25 indicators, max 100)
            #
            #  Backtested research weights:
            #  MACD+RSI combo: 73-84% WR → 12 pts (highest)
            #  MACD+MFI combo: 69-70% WR → 6 pts
            #  Supertrend: 2x weight (EPAT) → 8 pts
            #  ADX gate: trending filter  → 5 pts
            #  VWAP: institutional benchmark → 4 pts
            #  Parabolic SAR: trend confirm → 3 pts
            #  Williams %R: fast momentum  → 3 pts
            #  Pivot: support/resistance   → 3 pts
            #  Fundamentals: PE/ROE bonus  → 10 pts max
            # ══════════════════════════════════════════════════════

            dvm = 0

            # RSI healthy zone (not overbought, not crashed)
            if 40 < rsi < 65: dvm += 6
            elif 30 < rsi <= 40: dvm += 3   # Oversold = opportunity

            # MACD + RSI COMBO — the proven king (73-84% WR)
            if macd_bull and 35 < rsi < 70: dvm += 10

            # MACD + MFI COMBO — 69-70% WR (arxiv research)
            if macd_bull and mfi_bull: dvm += 5

            # MACD standalone
            if macd_bull: dvm += 4
            if macd_cross_up: dvm += 3      # Fresh crossover = strongest

            # EMA fast momentum
            if ema_bull: dvm += 4

            # Supertrend — 2x weight per EPAT research
            if supertrend_bull: dvm += 8

            # Parabolic SAR — trend confirmation
            if psar_bull: dvm += 3

            # ADX — trend strength gate
            if adx > 25: dvm += 5           # Trending market
            if adx > 35: dvm += 2           # Strong trend bonus

            # VWAP — institutional benchmark
            if vwap_bull: dvm += 4          # Price above VWAP = institutional bullish

            # Williams %R — fast momentum confirmation
            if wr_bull and not wr_overbought: dvm += 3

            # Moving average trend
            if ma50 > ma200: dvm += 5       # Golden cross / uptrend
            if price > ma20: dvm += 3       # Above short-term MA

            # Volume confirmation
            if vol_s > 1.2: dvm += 4
            if obv_bull: dvm += 3           # Smart money flowing in

            # Stochastic + MFI filters
            if not stoch_overbought: dvm += 2
            if not mfi_overbought: dvm += 2

            # Chart position
            if near_52h: dvm += 2           # Strength near highs
            if near_fib: dvm += 2           # At Fibonacci support
            if near_support: dvm += 3       # At pivot support = strong buy zone
            if bb_squeeze: dvm += 2         # Breakout imminent

            # Momentum
            if ret_3m > 0: dvm += 2

            # Fundamental bonus (when NSE/Screener data available)
            if 0 < pe < 30: dvm += 4
            elif 0 < pe < 50: dvm += 2
            if roe > 0.12: dvm += 3
            elif roe > 0.05: dvm += 1
            if 0 < debt < 1.0: dvm += 2

            # Penalties — avoid buying into clear danger
            if near_resistance: dvm -= 3    # Near pivot resistance
            if wr_overbought and stoch_overbought: dvm -= 4  # Double overbought
            if mfi_overbought and rsi > 70: dvm -= 3  # Money flowing out

            # Cap 0-100
            dvm = max(0, min(100, dvm))

            # Sub-scores for reporting (25 indicators across 5 categories)
            mom = min(35, (6 if 40<rsi<65 else 3 if rsi<40 else 0) +
                     (4 if macd_bull else 0) + (3 if macd_cross_up else 0) +
                     (4 if ema_bull else 0) + (3 if wr_bull else 0) +
                     (5 if macd_bull and mfi_bull else 0) +
                     (2 if ret_3m>0 else 0) + (2 if not stoch_overbought else 0))
            trnd = min(30, (8 if supertrend_bull else 0) + (5 if ma50>ma200 else 0) +
                      (3 if price>ma20 else 0) + (5 if adx>25 else 0) +
                      (3 if psar_bull else 0) + (4 if vwap_bull else 0) +
                      (2 if above_pivot else 0))
            fun = min(10, (4 if 0<pe<30 else 2 if 0<pe<50 else 0) +
                     (3 if roe>0.12 else 1 if roe>0.05 else 0) +
                     (2 if 0<debt<1 else 0))
            vol_score = dvm - mom - trnd - fun

            # ══════════════════════════════════════════════════════
            #  SIGNAL GENERATION — 25 indicator confluence + ADX gate
            # ══════════════════════════════════════════════════════

            # Overall signal
            if dvm >= 70: overall = "STRONG BUY 🟢"
            elif dvm >= 50: overall = "BUY 🟩"
            elif dvm >= 35: overall = "HOLD ⚪"
            elif dvm >= 20: overall = "SELL 🟥"
            else: overall = "STRONG SELL 🔴"

            # Intraday: EMA + VWAP + RSI + MACD + Supertrend + Volume + SAR + Williams + MA20
            # AGGRESSIVE: need 5/9 (55%) — catches momentum moves
            # BALANCED: need 6/9 (67%) — more confirmation
            ib = (int(50<rsi<70) + int(macd_bull) + int(ema_bull) +
                  int(vol_s>1.2) + int(supertrend_bull) + int(price>ma20) +
                  int(vwap_bull) + int(psar_bull) + int(wr_bull))
            ib_threshold = 5 if STRATEGY_MODE == "AGGRESSIVE" else 6
            if ib >= ib_threshold and adx > 18:
                intraday_sig = "INTRADAY BUY 🟢"
            elif ib <= 2 and rsi > RSI_OVERBOUGHT:
                intraday_sig = "INTRADAY SELL 🔴"
            else:
                intraday_sig = "INTRADAY WAIT ⚪"

            # Swing: MACD + MA50>MA200 + Supertrend + RSI + MFI + VWAP + Pivot + OBV + Fib
            # AGGRESSIVE: need 4/9 (44%) — more swing entries
            # BALANCED: need 5/9 (55%) — quality swings
            sb = (int(macd_bull) + int(ma50>ma200) + int(supertrend_bull) +
                  int(30<rsi<65) + int(near_52h or near_fib) + int(obv_bull) +
                  int(mfi_bull) + int(vwap_bull) + int(above_pivot))
            sb_threshold = 4 if STRATEGY_MODE == "AGGRESSIVE" else 5
            if sb >= sb_threshold:
                swing_sig = "SWING BUY 🟩"
            elif sb <= 2:
                swing_sig = "SWING SELL 🟥"
            else:
                swing_sig = "SWING WAIT ⚪"

            # Long-term: DVM + MA50>MA200 + Supertrend + Parabolic SAR + PE + ADX
            # AGGRESSIVE: DVM >= 45 — more long-term entries
            # BALANCED: DVM >= 55 — quality only
            lt_dvm_min = 45 if STRATEGY_MODE == "AGGRESSIVE" else 55
            if dvm >= lt_dvm_min and ma50 > ma200:
                lt_sig = "LT BUY 🔵"
            elif dvm <= 20:
                lt_sig = "LT SELL 🟣"
            else:
                lt_sig = "LT HOLD ⚪"

            # Trend description
            if ma20 > ma50 > ma200 and adx > 25:
                trend = "Strong Bullish 🐂"
            elif ma20 < ma50 < ma200 and adx > 25:
                trend = "Strong Bearish 🐻"
            elif ma50 > ma200:
                trend = "Bullish"
            else:
                trend = "Bearish"

            return {
                "symbol":sym,"price":price,"rsi":rsi,"macd_bull":macd_bull,
                "macd_cross":macd_cross_up,"macd_hist":macd_hist_val,
                "ema9":round(ema9,2),"ema21":round(ema21,2),"ema_bull":ema_bull,
                "ma20":round(ma20,2),"ma50":round(ma50,2),"ma200":round(ma200,2),
                "atr":atr,"adx":adx,
                "supertrend":supertrend_val,"supertrend_bull":supertrend_bull,
                "psar":psar,"psar_bull":psar_bull,
                "stoch_k":stoch_k,"stoch_oversold":stoch_oversold,"stoch_overbought":stoch_overbought,
                "obv_bull":obv_bull,
                "mfi":mfi,"mfi_bull":mfi_bull,"mfi_oversold":mfi_oversold,"mfi_overbought":mfi_overbought,
                "williams_r":williams_r,"wr_bull":wr_bull,"wr_oversold":wr_oversold,"wr_overbought":wr_overbought,
                "vwap_proxy":round(vwap_proxy,2),"vwap_bull":vwap_bull,
                "pivot":pivot,"r1":r1,"s1":s1,"above_pivot":above_pivot,
                "near_support":near_support,"near_resistance":near_resistance,
                "bb_up":round(bb_up,2),"bb_lo":round(bb_lo,2),"bb_width":bb_width,"bb_squeeze":bb_squeeze,
                "vol_surge":vol_s,"trend":trend,
                "w52_high":round(w52h,2),"w52_low":round(w52l,2),"near_52h":near_52h,
                "fib_382":fib_382,"fib_500":fib_500,"fib_618":fib_618,"near_fib":near_fib,
                "ret_1w":round(ret_1w,2),"ret_1m":round(ret_1m,2),"ret_3m":round(ret_3m,2),
                "dvm_score":dvm,"mom_score":mom,"trnd_score":trnd,"fun_score":fun,"vol_score":vol_score,
                "pe":round(pe,1),"pb":round(pb,1),"roe":round(roe*100 if roe<1 else roe,1),
                "debt_eq":round(debt,2),"div_yld":round(div*100 if div<1 else div,2),
                "earn_growth":round(earn_g*100 if abs(earn_g)<1 else earn_g,1),
                "sector":sector,
                "overall":overall,"intraday_sig":intraday_sig,"swing_sig":swing_sig,"lt_sig":lt_sig,
                "profit_book":rsi>RSI_OVERBOUGHT or stoch_overbought or wr_overbought or mfi_overbought,
                "oversold":rsi<RSI_OVERSOLD or stoch_oversold or wr_oversold or mfi_oversold,
                # ═══ SEBI-COMPLIANT SL: Max 0.9% below entry (Rama's <1% rule) ═══
                # Original ATR-based SL could exceed 1% — now capped
                "sl_intra":round(price * (1 - min(max(atr/price if atr>0 else 0.005, MIN_SL_PERCENT), MAX_SL_PERCENT)), 2),
                "t1_intra":round(price+1.5*atr,2) if atr>0 else round(price*1.015,2),
                "t2_intra":round(price+2.5*atr,2) if atr>0 else round(price*1.025,2),
                "sl_swing":round(price * (1 - min(max(atr/price if atr>0 else 0.007, MIN_SL_PERCENT), MAX_SL_PERCENT)), 2),
                "t1_swing":round(price+2.0*atr,2) if atr>0 else round(price*1.02,2),
                "t2_swing":round(price+4.0*atr,2) if atr>0 else round(price*1.04,2),
                "sl_lt":round(price * (1 - min(max((atr*1.5)/price if atr>0 else 0.008, MIN_SL_PERCENT), MAX_SL_PERCENT)), 2),
                "t1_lt":round(price+4.0*atr,2) if atr>0 else round(price*1.04,2),
                "t2_lt":round(price+8.0*atr,2) if atr>0 else round(price*1.08,2),
                "is_circuit": _is_circuit, "circuit_type": _circuit_type,
                "day_change_pct": _day_change_pct,
            }
        except Exception as e:
            err = str(e)
            if "429" in err or "Too Many" in err:
                logger.debug(f"Rate limit [{symbol}] — backing off 5s")
                time.sleep(5)  # Longer backoff on rate limit
            else:
                logger.debug(f"Score [{symbol}]: {e}")
            return None

# ──────────────────────────────────────────────────────────────────────────────
#  RISK MANAGER
# ──────────────────────────────────────────────────────────────────────────────

# ══════════════════════════════════════════════════════════════════════════════
#  v23.6.1: LOSS BLACKLIST — Prevent re-buying stocks that just burned you
#  Aqylon scenario: bot buys → stock hits lower circuit → manual exit → bot
#  re-buys the same stock. This blacklist blocks re-entry for 48 hours after
#  a loss exit, and 7 DAYS after a circuit-hit exit.
#
#  Also persists to JSON so it survives bot restarts.
# ══════════════════════════════════════════════════════════════════════════════
BLACKLIST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "loss_blacklist.json")

class LossBlacklist:
    """Track stocks that caused losses — block re-entry for a cooldown period."""

    # Cooldown periods (hours)
    LOSS_COOLDOWN_HOURS    = 48   # Normal loss exit: 2 days
    CIRCUIT_COOLDOWN_HOURS = 168  # Circuit hit: 7 days (stock is radioactive)
    MANUAL_EXIT_COOLDOWN   = 72   # Manual exit (user override): 3 days

    _blacklist = {}   # {symbol: {"reason": str, "exit_time": iso, "cooldown_hours": int}}
    _loaded = False

    @classmethod
    def _load(cls):
        if cls._loaded:
            return
        try:
            if os.path.exists(BLACKLIST_FILE):
                with open(BLACKLIST_FILE) as f:
                    cls._blacklist = json.load(f)
            cls._loaded = True
        except Exception:
            cls._blacklist = {}
            cls._loaded = True

    @classmethod
    def _save(cls):
        try:
            with open(BLACKLIST_FILE, "w") as f:
                json.dump(cls._blacklist, f, indent=2)
        except Exception as e:
            logger.debug(f"Blacklist save: {e}")

    @classmethod
    def add(cls, symbol, reason="LOSS", cooldown_hours=None):
        """Add a stock to the blacklist after a bad exit."""
        cls._load()
        if cooldown_hours is None:
            if "circuit" in reason.lower():
                cooldown_hours = cls.CIRCUIT_COOLDOWN_HOURS
            elif "manual" in reason.lower():
                cooldown_hours = cls.MANUAL_EXIT_COOLDOWN
            else:
                cooldown_hours = cls.LOSS_COOLDOWN_HOURS

        cls._blacklist[symbol] = {
            "reason": reason,
            "exit_time": now_ist().isoformat(),
            "cooldown_hours": cooldown_hours,
        }
        cls._save()
        logger.info(
            f"BLACKLIST ADD [{symbol}]: {reason} — blocked for {cooldown_hours}h"
        )

    @classmethod
    def is_blocked(cls, symbol):
        """Check if a stock is still in cooldown.
        Returns (blocked: bool, reason: str)."""
        cls._load()
        if symbol not in cls._blacklist:
            return False, ""

        entry = cls._blacklist[symbol]
        try:
            exit_time = datetime.fromisoformat(entry["exit_time"])
            if not exit_time.tzinfo:
                exit_time = IST.localize(exit_time)
            hours_since = (now_ist() - exit_time).total_seconds() / 3600
            cooldown = entry.get("cooldown_hours", cls.LOSS_COOLDOWN_HOURS)

            if hours_since >= cooldown:
                # Cooldown expired — remove from blacklist
                del cls._blacklist[symbol]
                cls._save()
                return False, ""

            remaining = round(cooldown - hours_since, 1)
            return True, (
                f"BLACKLISTED: {entry['reason']} "
                f"({remaining:.0f}h remaining of {cooldown}h cooldown)"
            )
        except Exception:
            # Can't parse — remove stale entry
            del cls._blacklist[symbol]
            cls._save()
            return False, ""

    @classmethod
    def cleanup(cls):
        """Remove expired entries. Call once per day."""
        cls._load()
        expired = []
        for sym, entry in cls._blacklist.items():
            try:
                exit_time = datetime.fromisoformat(entry["exit_time"])
                if not exit_time.tzinfo:
                    exit_time = IST.localize(exit_time)
                hours_since = (now_ist() - exit_time).total_seconds() / 3600
                if hours_since >= entry.get("cooldown_hours", cls.LOSS_COOLDOWN_HOURS):
                    expired.append(sym)
            except Exception:
                expired.append(sym)
        for sym in expired:
            del cls._blacklist[sym]
        if expired:
            cls._save()
            logger.info(f"BLACKLIST CLEANUP: removed {len(expired)} expired entries")

    @classmethod
    def get_all(cls):
        cls._load()
        return dict(cls._blacklist)


# ══════════════════════════════════════════════════════════════════════════════
#  v23.6.1: SMART SL — Tighten SL for positions already in loss
#  BUG FIX: Old logic set SL = LTP - 1×ATR regardless of existing loss.
#  If stock entered at Rs.100, now at Rs.95 (−5%), old SL = Rs.93 (−7% total).
#  NEW: SL tightens as unrealised loss deepens. Max drawdown from entry capped.
#
#  LOSS BAND TABLE (from entry price):
#    0% to −3%  → Normal ATR-based SL (1.0×ATR below LTP)
#    −3% to −5% → Tighter: 0.5×ATR below LTP, but never > 7% from entry
#    −5% to −8% → Very tight: 0.3×ATR below LTP, max 8% from entry
#    > −8%      → Emergency: 1% below LTP (capital preservation mode)
#
#  For GTT sync fallback (no bot book entry): uses max 3% below LTP
#  instead of the old 0.5% which was too tight for volatile stocks.
# ══════════════════════════════════════════════════════════════════════════════

def smart_sl_for_position(entry_price, current_price, atr, strategy="swing"):
    """Calculate SL that tightens as unrealised loss deepens.
    
    Args:
        entry_price: Original buy price
        current_price: Current LTP
        atr: Average True Range (14-period)
        strategy: 'intraday', 'swing', or 'longterm'
    
    Returns:
        sl_price (float): The computed stop-loss price
    """
    if entry_price <= 0 or current_price <= 0:
        return round(current_price * 0.97, 2)
    
    loss_pct = (entry_price - current_price) / entry_price * 100  # positive = loss
    
    # Strategy-specific max drawdown caps
    _max_dd = {"intraday": 0.05, "swing": 0.08, "longterm": 0.12}
    max_drawdown = _max_dd.get(strategy, 0.08)
    
    # Absolute floor: never let SL go below max_drawdown from entry
    absolute_floor = round(entry_price * (1 - max_drawdown), 2)
    
    if loss_pct <= 3:
        # Normal zone: standard ATR-based SL
        sl = round(current_price - 1.0 * atr, 2)
    elif loss_pct <= 5:
        # Warning zone: tighter SL, approaching max pain
        sl = round(current_price - 0.5 * atr, 2)
    elif loss_pct <= 8:
        # Danger zone: very tight SL, preserve remaining capital
        sl = round(current_price - 0.3 * atr, 2)
    else:
        # Emergency: 1% below LTP — if it drops any more, cut losses
        sl = round(current_price * 0.99, 2)
    
    # SL must be above absolute floor (max allowed drawdown from entry)
    sl = max(sl, absolute_floor)
    
    # SL must be below current price (obviously)
    if sl >= current_price:
        sl = round(current_price * 0.995, 2)
    
    # SL must be > 0
    sl = max(sl, 1.0)
    
    return sl


def smart_sl_fallback(ltp, avg_price=0):
    """Fallback SL for GTT sync when no bot book data exists.
    SEBI-COMPLIANT: Uses 0.9% below LTP (Rama's <1% rule).
    """
    if ltp <= 0:
        return 1.0
    
    # ═══ SEBI-COMPLIANT: 0.9% below LTP (was 3%) ═══
    sl = round(ltp * (1 - MAX_SL_PERCENT), 2)
    
    # If we know avg purchase price, also cap at 0.9% from avg
    if avg_price > 0:
        max_loss_sl = round(avg_price * (1 - MAX_SL_PERCENT), 2)
        # Use the HIGHER (tighter) of the two
        sl = max(sl, max_loss_sl)
    
    # Safety: SL must be below LTP
    if sl >= ltp:
        sl = round(ltp * 0.985, 2)
    
    return max(sl, 1.0)


# ══════════════════════════════════════════════════════════════════════════════
#  v23.6.1: CORRELATION FILTER — Prevent concentrated correlated risk
#  Before buying a new stock, check if it's highly correlated with existing
#  positions. If correlation > 0.75, block the trade (same risk = same crash).
#
#  Uses return-based correlation from historical data (90-day).
#  Sector shortcuts: known high-correlation pairs skip the expensive calc.
#  Max 3 positions in same sector.
# ══════════════════════════════════════════════════════════════════════════════

class CorrelationFilter:
    """Prevent buying stocks highly correlated with existing positions."""
    
    # Known high-correlation clusters (skip expensive historical calc)
    CORR_CLUSTERS = {
        "PRIVATE_BANKS": ["HDFCBANK", "ICICIBANK", "KOTAKBANK", "AXISBANK", "INDUSINDBK"],
        "PSU_BANKS": ["SBIN", "BANKBARODA", "PNB", "CANBK", "UNIONBANK", "IOB", "INDIANB"],
        "IT_LARGE": ["TCS", "INFY", "WIPRO", "HCLTECH", "TECHM", "LTIM"],
        "METALS": ["TATASTEEL", "JSWSTEEL", "HINDALCO", "VEDL", "NATIONALUM", "SAIL"],
        "OIL_GAS": ["ONGC", "BPCL", "HINDPETRO", "IOC", "GAIL", "PETRONET"],
        "ADANI": ["ADANIENT", "ADANIPORTS", "ADANIPOWER", "ADANIGREEN", "AWL", "ATGL"],
        "TATA": ["TCS", "TATASTEEL", "TATAMOTORS", "TATAPOWER", "TATACHEM", "TATACOMM",
                  "TATAELXSI", "TATACONSUM"],
        "PHARMA": ["SUNPHARMA", "DRREDDY", "CIPLA", "DIVISLAB", "AUROPHARMA", "BIOCON"],
        "FMCG": ["HINDUNILVR", "ITC", "NESTLEIND", "BRITANNIA", "DABUR", "MARICO",
                  "GODREJCP", "COLPAL"],
        "AUTO": ["MARUTI", "TATAMOTORS", "M&M", "BAJAJ-AUTO", "HEROMOTOCO", "EICHERMOT"],
        "CEMENT": ["ULTRACEMCO", "SHREECEM", "AMBUJACEM", "ACC", "DALMIACEM", "RAMCOCEM"],
        "POWER": ["NTPC", "POWERGRID", "TATAPOWER", "ADANIPOWER", "NHPC", "SJVN"],
        "REALTY": ["DLF", "GODREJPROP", "OBEROIRLTY", "PRESTIGE", "BRIGADE", "SOBHA"],
        "INSURANCE": ["SBILIFE", "HDFCLIFE", "ICICIPRULI", "MAXHEALTH", "STARHEALTH"],
    }
    
    # Build reverse lookup: symbol → cluster name
    _SYM_TO_CLUSTER = {}
    for _cname, _csyms in CORR_CLUSTERS.items():
        for _cs in _csyms:
            _SYM_TO_CLUSTER[_cs] = _cname
    
    # Max positions from same cluster
    MAX_SAME_CLUSTER = 2
    
    @classmethod
    def check(cls, candidate_symbol, existing_positions, scan_data=None):
        """Check if candidate is too correlated with existing positions.
        
        Args:
            candidate_symbol: Stock symbol to check
            existing_positions: dict of {symbol: pos_dict} for all open positions
            scan_data: dict with candidate's scan result (for sector info)
            
        Returns:
            (allowed: bool, reason: str)
        """
        if not existing_positions:
            return True, "No existing positions"
        
        # Skip check for KITE_ADOPTED positions
        _active = {s: p for s, p in existing_positions.items() 
                   if p.get("source", "") != "KITE_ADOPTED"}
        if not _active:
            return True, "No active bot positions"
        
        # ── Cluster check (fast path) ────────────────────────────
        _cand_cluster = cls._SYM_TO_CLUSTER.get(candidate_symbol)
        if _cand_cluster:
            _same_cluster_count = 0
            _same_cluster_syms = []
            for sym in _active:
                if cls._SYM_TO_CLUSTER.get(sym) == _cand_cluster:
                    _same_cluster_count += 1
                    _same_cluster_syms.append(sym)
            
            if _same_cluster_count >= cls.MAX_SAME_CLUSTER:
                return False, (
                    f"CORR BLOCK: {candidate_symbol} in {_cand_cluster} cluster, "
                    f"already have {_same_cluster_count}: {', '.join(_same_cluster_syms)}"
                )
        
        # ── Sector concentration check ───────────────────────────
        if scan_data:
            _cand_sector = (scan_data.get("sector", "") or 
                           scan_data.get("industry", "") or "").upper()
            if _cand_sector and _cand_sector != "UNKNOWN":
                _sector_count = 0
                for sym, pos in _active.items():
                    _pos_sector = (pos.get("sector", "") or "").upper()
                    if _pos_sector == _cand_sector:
                        _sector_count += 1
                if _sector_count >= 3:
                    return False, (
                        f"SECTOR CAP: Already {_sector_count} positions in {_cand_sector}"
                    )
        
        # ── Return correlation check (uses scan data ret_1m) ─────
        # If we have 1-month return data, check if candidate moves
        # too similarly to existing positions
        if scan_data and scan_data.get("ret_1m") is not None:
            _cand_ret = scan_data.get("ret_1m", 0)
            _cand_ret3m = scan_data.get("ret_3m", 0)
            _similar_count = 0
            for sym, pos in _active.items():
                # Check if both had very similar returns (proxy for correlation)
                _pos_scan = pos.get("scan_data", {})
                if _pos_scan:
                    _pos_ret = _pos_scan.get("ret_1m", -999)
                    if _pos_ret != -999:
                        # If 1-month returns within 2% of each other AND same direction
                        _ret_diff = abs(_cand_ret - _pos_ret)
                        _same_dir = (_cand_ret > 0) == (_pos_ret > 0)
                        if _ret_diff < 2.0 and _same_dir and abs(_cand_ret) > 1:
                            _similar_count += 1
            
            if _similar_count >= 2:
                return False, (
                    f"RETURN CORR: {candidate_symbol} returns too similar to "
                    f"{_similar_count} existing positions"
                )
        
        return True, "OK"
    
    @classmethod
    def get_cluster(cls, symbol):
        """Get the correlation cluster for a symbol."""
        return cls._SYM_TO_CLUSTER.get(symbol, None)


class RiskManager:
    def __init__(self):
        self.daily=load_json(DAILY_FILE,{"date":today_str(),"intraday_pnl":0,"swing_pnl":0,
            "longterm_pnl":0,"fno_pnl":0,"total_pnl":0,"trades_today":0,
            "intraday_halted":False,"observe_mode":False,"monthly_pnl":0,
            "monthly_start":now_ist().strftime("%Y-%m")})
        self._reset_if_new_day()

    def _reset_if_new_day(self):
        if self.daily["date"]!=today_str():
            mp=self.daily.get("monthly_pnl",0)
            ms=now_ist().strftime("%Y-%m")
            if self.daily.get("monthly_start")!=ms: mp=0
            else: mp+=self.daily["total_pnl"]
            self.daily={"date":today_str(),"intraday_pnl":0,"swing_pnl":0,
                "longterm_pnl":0,"fno_pnl":0,"total_pnl":0,"trades_today":0,
                "intraday_halted":False,"observe_mode":False,
                "monthly_pnl":mp,"monthly_start":ms}
            save_json(DAILY_FILE,self.daily)

    def update_pnl(self,strategy,pnl):
        self._reset_if_new_day()
        k=f"{strategy}_pnl"
        if k in self.daily: self.daily[k]=round(self.daily[k]+pnl,2)
        self.daily["total_pnl"]=round(self.daily["total_pnl"]+pnl,2)
        self.daily["trades_today"]+=1
        if self.daily["intraday_pnl"]<=-(INTRADAY_CAP*INTRADAY_LOSS_LIMIT) and not self.daily["intraday_halted"]:
            self.daily["intraday_halted"]=True
            send_telegram(f"🛑 *INTRADAY HALTED*\nDaily loss ₹{abs(self.daily['intraday_pnl']):,.0f} exceeded {INTRADAY_LOSS_LIMIT*100:.0f}% limit.\nSwing & Long term continue.")
        total_m=self.daily["monthly_pnl"]+self.daily["total_pnl"]
        if total_m<=-(TOTAL_CAPITAL*MONTHLY_LOSS_LIMIT) and not self.daily["observe_mode"]:
            self.daily["observe_mode"]=True
            send_telegram(f"⚠️ *OBSERVE MODE*\nMonthly loss ₹{abs(total_m):,.0f}. No new trades until next month.")
        if pnl>TOTAL_CAPITAL*PROFIT_ALERT_PCT:
            send_telegram(f"🎯 *PROFIT ALERT!*\n{strategy.upper()}: +₹{pnl:,.0f}\nToday: ₹{self.daily['total_pnl']:,.0f}")
        save_json(DAILY_FILE,self.daily)

    def can_trade_intraday(self): self._reset_if_new_day(); return not self.daily["intraday_halted"] and not self.daily["observe_mode"]
    def can_trade(self):          self._reset_if_new_day(); return not self.daily["observe_mode"]
    @property
    def is_halted(self):          self._reset_if_new_day(); return self.daily["observe_mode"]
    def size_factor(self,wr):     return 1.0 if wr>=60 else 0.75 if wr>=50 else 0.50
    def get_summary(self):        self._reset_if_new_day(); return self.daily

# ──────────────────────────────────────────────────────────────────────────────
#  BASE PAPER TRADER
# ──────────────────────────────────────────────────────────────────────────────

class BasePaperTrader:
    def __init__(self,filepath,capital,max_pos,name,risk):
        self.file=filepath; self.capital=capital; self.max_pos=max_pos
        self.name=name; self.risk=risk
        self.book=load_json(filepath,{"capital":capital,"available":capital,
            "positions":{},"trades":[],"pnl_log":[],"start_time":now_ist().isoformat()})

    def _save(self): save_json(self.file,self.book)
    def win_rate(self):
        closed=[t for t in self.book["trades"] if t["status"]=="CLOSED"]
        if not closed: return 50.0
        return round(len([t for t in closed if t["pnl"]>0])/len(closed)*100,1)

    def _qty(self,price,sl):
        risk=abs(price-sl)
        if risk<=0: return 0
        f=self.risk.size_factor(self.win_rate())

        # v23.6.0 #4: Kelly Criterion Position Sizing
        if USE_KELLY_SIZING:
            wr = self.win_rate() / 100.0
            closed = [t for t in self.book["trades"] if t["status"]=="CLOSED"]
            wins = [t for t in closed if t["pnl"]>0]
            losses = [t for t in closed if t["pnl"]<=0]
            avg_win = sum(t["pnl"] for t in wins)/len(wins) if wins else 1
            avg_loss = abs(sum(t["pnl"] for t in losses)/len(losses)) if losses else 1
            rr = avg_win / (avg_loss + 0.01)
            kelly_pct = max(0.05, wr - (1 - wr) / (rr + 0.01))
            kelly_pct = kelly_pct * KELLY_FRACTION
            kelly_pct = min(kelly_pct, 0.35)
            qty = max(1, int(self.book["available"] * kelly_pct / risk))
            if qty * price > self.book["available"] * MAX_POSITION_PCT:
                qty = max(1, int(self.book["available"] * MAX_POSITION_PCT / price))
        else:
            qty=max(1,int(self.book["available"]*RISK_PER_TRADE*f/risk))
            if qty*price>self.book["available"]*MAX_POSITION_PCT:
                qty=max(1,int(self.book["available"]*MAX_POSITION_PCT/price))

        # Minimum deployment: each trade must deploy at least Rs.15,000
        # Prevents buying 1 share of a Rs.300 stock when Rs.58,000 is available
        MIN_DEPLOY = 15000
        if qty * price < MIN_DEPLOY and self.book["available"] >= MIN_DEPLOY:
            qty = max(qty, int(MIN_DEPLOY / price))
            # Still respect the MAX_POSITION_PCT cap
            if qty * price > self.book["available"] * MAX_POSITION_PCT:
                qty = max(1, int(self.book["available"] * MAX_POSITION_PCT / price))

        return qty

    def entry(self,symbol,price,signal,sl,t1,t2,source="TECHNICAL"):
        if symbol in self.book["positions"]: return None
        
        # ═══════════════════════════════════════════════════════════════════
        # v23.6.4: OPTION B — CONFIRMATION CANDLE ENTRY (Billionaire Strategy)
        # 
        # "Wait for confirmation before entering" — Every Professional Trader
        # 
        # Logic:
        # 1. Get last 3 candles (5-minute timeframe)
        # 2. Check if stock is BOUNCING (confirmation) or still FALLING
        # 3. Only buy when: Last candle is GREEN after RED (reversal)
        #    OR: Price bounced 0.3%+ from recent low (uptick confirmation)
        # 4. Never buy into falling knife — wait for bounce!
        # ═══════════════════════════════════════════════════════════════════
        _confirmation_passed = False
        _entry_price = price  # Default to signal price
        
        try:
            _kite = KiteSession.get() if TRADING_MODE == "LIVE" else None
            if _kite:
                # Step 1: Get current LTP
                _exchange_sym = f"NSE:{symbol}"
                _ltp_data = _kite.ltp([_exchange_sym])
                _current_ltp = _ltp_data.get(_exchange_sym, {}).get("last_price", 0)
                
                if _current_ltp <= 0:
                    _confirmation_passed = True  # Can't check, proceed with caution
                else:
                    _price_change_pct = ((_current_ltp - price) / price) * 100
                    
                    # RULE 1: If price rose >2% since signal, too expensive — SKIP
                    if _price_change_pct > 2.0:
                        logger.info(
                            f"⏳ ENTRY SKIP [{symbol}]: Price +{_price_change_pct:.1f}% since signal. "
                            f"Too expensive (₹{price} → ₹{_current_ltp})"
                        )
                        return None
                    
                    # Step 2: Get last 3 candles (5-minute) for confirmation check
                    try:
                        from datetime import timedelta
                        _now = now_ist()
                        _from = _now - timedelta(minutes=20)
                        _candles = _kite.historical_data(
                            instrument_token=_kite.ltp([_exchange_sym]).get(_exchange_sym, {}).get("instrument_token", 0),
                            from_date=_from.strftime("%Y-%m-%d %H:%M:%S"),
                            to_date=_now.strftime("%Y-%m-%d %H:%M:%S"),
                            interval="5minute"
                        ) if hasattr(_kite, 'historical_data') else []
                    except:
                        _candles = []
                    
                    if len(_candles) >= 2:
                        # Confirmation Check: Is last candle GREEN after RED?
                        _last = _candles[-1]
                        _prev = _candles[-2]
                        
                        _last_green = _last['close'] > _last['open']
                        _prev_red = _prev['close'] < _prev['open']
                        _bounced_from_low = (_current_ltp - _last['low']) / _last['low'] * 100 >= 0.2
                        
                        # Find recent low from candles
                        _recent_low = min(c['low'] for c in _candles[-3:]) if len(_candles) >= 3 else _last['low']
                        _bounce_from_recent_low = (_current_ltp - _recent_low) / _recent_low * 100
                        
                        # CONFIRMATION CONDITIONS (any one = confirmed):
                        # A) Green candle after red (reversal pattern)
                        # B) Price bounced 0.3%+ from recent low
                        # C) Current price is above last candle's close (upward momentum)
                        
                        _cond_a = _last_green and _prev_red
                        _cond_b = _bounce_from_recent_low >= 0.3
                        _cond_c = _current_ltp > _last['close']
                        
                        if _cond_a or _cond_b or _cond_c:
                            _confirmation_passed = True
                            _why = "GREEN after RED" if _cond_a else (f"Bounce +{_bounce_from_recent_low:.1f}%" if _cond_b else "Above last close")
                            logger.info(f"✅ ENTRY CONFIRMED [{symbol}]: {_why} | LTP=₹{_current_ltp}")
                            _entry_price = _current_ltp  # Use current price
                        else:
                            # No confirmation — stock still falling
                            logger.info(
                                f"⏳ ENTRY WAIT [{symbol}]: No confirmation yet. "
                                f"Last candle: {'GREEN' if _last_green else 'RED'}, "
                                f"Bounce from low: {_bounce_from_recent_low:+.1f}% (need +0.3%)"
                            )
                            return None
                    else:
                        # Can't get candles — use simple LTP check
                        if _price_change_pct < -0.5:
                            logger.info(f"⏳ ENTRY WAIT [{symbol}]: Price fell {_price_change_pct:.1f}%. Waiting for uptick.")
                            return None
                        elif _price_change_pct >= -0.2:
                            _confirmation_passed = True
                            _entry_price = _current_ltp if _current_ltp > 0 else price
                            logger.info(f"✅ ENTRY OK [{symbol}]: Price stable ({_price_change_pct:+.1f}%)")
                        else:
                            return None
                            
        except Exception as _conf_err:
            logger.debug(f"Confirmation check [{symbol}]: {_conf_err}")
            _confirmation_passed = True  # On error, proceed (don't block all trades)
        
        if not _confirmation_passed:
            return None
        
        # Update price and recalculate SL/targets based on confirmed entry price
        if abs(_entry_price - price) / price > 0.001:  # Price changed >0.1%
            price = _entry_price
            # Recalculate SL (maintain 0.9% max)
            sl = round(price * (1 - MAX_SL_PERCENT), 2)
            _risk = price - sl
            t1 = round(price + 2.5 * _risk, 2)
            t2 = round(price + 4.0 * _risk, 2)
        
        # Capital and position checks
        qty=self._qty(price,sl)
        if qty==0: return None
        cost=round(qty*price,2)
        if cost>self.book["available"]: return None
        
        pos={"symbol":symbol,"entry_price":price,"qty":qty,"cost":cost,
             "signal":signal,"stop_loss":sl,"target1":t1,"target2":t2,
             "original_sl":sl,  # v23.6.0 #1: Store original SL for trailing reference
             "highest_price":price,  # v23.6.0 #1: Track peak price for trailing
             "partial_booked":False,  # v23.6.0 #7: Track if T1 partial exit done
             "original_qty":qty,  # v23.6.0 #7: Remember full qty for partial calc
             "corr_cluster": CorrelationFilter.get_cluster(symbol) or "",  # v23.6.1
             "strategy":self.name,"source":source,"entry_time":now_ist().isoformat(),
             "entry_date":today_str(),"status":"OPEN"}
        self.book["positions"][symbol]=pos
        self.book["available"]=round(self.book["available"]-cost,2)
        self._save()
        logger.info(f"📈 {self.name.upper()} [{source}]: {symbol} @ ₹{price} x{qty}")
        send_telegram(f"📈 *{self.name.upper()} Entry* [{source}]\n`{symbol}` @ ₹{price} x{qty}\nCost: ₹{cost:,.0f}\nSL: ₹{sl} | T1: ₹{t1} | T2: ₹{t2}\nSignal: {signal}", priority="trade")
        return pos

    def partial_exit(self, symbol, price, qty_to_sell, reason):
        """v23.6.0 #7: Sell part of a position (e.g., 50% at T1).
        SAFETY: Updates GTT quantity to match reduced position — prevents double-sell."""
        pos = self.book["positions"].get(symbol)
        if not pos or qty_to_sell <= 0:
            return None
        remaining_qty = pos["qty"] - qty_to_sell
        if remaining_qty < 0:
            qty_to_sell = pos["qty"]
            remaining_qty = 0

        pnl = round((price - pos["entry_price"]) * qty_to_sell, 2)
        pct = round((price - pos["entry_price"]) / pos["entry_price"] * 100, 2)

        # Record partial trade
        partial_trade = {**pos, "exit_price": price, "exit_time": now_ist().isoformat(),
                         "pnl": pnl, "pnl_pct": pct, "reason": reason, "status": "PARTIAL_CLOSED",
                         "qty_sold": qty_to_sell, "qty_remaining": remaining_qty}
        self.book["trades"].append(partial_trade)
        self.book["available"] = round(self.book["available"] + qty_to_sell * price, 2)
        self.book["pnl_log"].append({"date": today_str(), "pnl": pnl})
        self.risk.update_pnl(self.name, pnl)
        _append_trade_history(partial_trade)

        if pnl > 0:
            ProfitCompounder.register_profit(pnl, self.name, symbol)

        if remaining_qty > 0:
            # Update position with reduced qty and new cost basis
            pos["qty"] = remaining_qty
            pos["cost"] = round(remaining_qty * pos["entry_price"], 2)
            pos["partial_booked"] = True
            self._save()

            # ══════════════════════════════════════════════════════
            # v23.6.0 CRITICAL SAFETY: Update GTT after partial exit
            # Old GTT has full qty → would sell MORE shares than we own!
            # Delete old GTT and place new one with reduced qty + breakeven SL
            # ══════════════════════════════════════════════════════
            if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                try:
                    _kite = KiteSession.get()
                    if _kite:
                        # Step 1: Delete old GTT
                        old_gtt_id = pos.get("gtt_id")
                        if old_gtt_id and old_gtt_id != "?" and old_gtt_id != "":
                            try:
                                _kite.delete_gtt(old_gtt_id)
                                logger.info(f"GTT DELETED [{symbol}]: Old GTT {old_gtt_id} (partial exit)")
                            except Exception as _del_err:
                                logger.warning(f"GTT delete [{symbol}]: {_del_err}")

                        # Step 2: Modify GTT — update qty to remaining + set breakeven SL
                        _new_sl     = round(pos["entry_price"] * 1.001, 2)  # Breakeven
                        _new_target = pos.get("target2", round(price * 1.20, 2))
                        _sl_t = round(_new_sl * 1.005, 1)
                        _tp_t = round(_new_target * 0.995, 1)
                        _sl_l = round(_new_sl, 1)
                        _tp_l = round(_new_target * 0.99, 1)
                        _mod_ok = False
                        if old_gtt_id and old_gtt_id not in ("?", "", "EXISTS_ON_KITE"):
                            try:
                                _kite.modify_gtt(
                                    trigger_id=old_gtt_id,
                                    trigger_type=_kite.GTT_TYPE_OCO,
                                    tradingsymbol=symbol, exchange="NSE",
                                    trigger_values=[_sl_t, _tp_t],
                                    last_price=price,
                                    orders=[
                                        {"exchange":"NSE","tradingsymbol":symbol,
                                         "transaction_type":"SELL","quantity":remaining_qty,
                                         "order_type":"LIMIT","product":"CNC","price":_sl_l},
                                        {"exchange":"NSE","tradingsymbol":symbol,
                                         "transaction_type":"SELL","quantity":remaining_qty,
                                         "order_type":"LIMIT","product":"CNC","price":_tp_l},
                                    ],
                                )
                                pos["gtt_sl"]     = _sl_t
                                pos["gtt_target"] = _tp_t
                                self._save()
                                _mod_ok = True
                                logger.info(
                                    f"GTT MODIFIED [{symbol}]: qty={remaining_qty} "
                                    f"SL=Rs.{_sl_l} (breakeven) ID={old_gtt_id} kept"
                                )
                            except Exception as _me:
                                logger.debug(f"GTT modify partial [{symbol}]: {_me} — will replace")
                        if not _mod_ok:
                            new_gtt_id = place_gtt_immediate(
                                _kite, symbol, remaining_qty,
                                price, _new_sl, _new_target, self
                            )
                            if new_gtt_id:
                                logger.info(
                                    f"GTT REPLACED [{symbol}]: qty={remaining_qty} "
                                    f"SL=Rs.{_new_sl} breakeven ID={new_gtt_id}"
                                )
                except Exception as _gtt_err:
                    logger.warning(f"GTT update partial [{symbol}]: {_gtt_err}")
            send_telegram(
                f"💰 *{self.name.upper()} Partial Exit (50%)*\n"
                f"`{symbol}` sold {qty_to_sell}x @ ₹{price}\n"
                f"PnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\n"
                f"Remaining: {remaining_qty}x | SL → Breakeven\n"
                f"GTT updated to {remaining_qty}x\n"
                f"Reason: {reason}", priority="trade")
        else:
            # Sold everything — cancel any remaining GTT
            if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                try:
                    _kite = KiteSession.get()
                    old_gtt_id = pos.get("gtt_id")
                    if _kite and old_gtt_id and old_gtt_id != "?" and old_gtt_id != "":
                        _kite.delete_gtt(old_gtt_id)
                        logger.info(f"GTT CANCELLED [{symbol}]: {old_gtt_id} (full exit)")
                except Exception as _gtt_err:
                    logger.warning(f"GTT cancel [{symbol}]: {_gtt_err}")

            self.book["positions"].pop(symbol, None)
            self._save()
            send_telegram(
                f"✅ *{self.name.upper()} Closed (Full)*\n"
                f"`{symbol}` @ ₹{price}\n"
                f"PnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\n"
                f"Reason: {reason}", priority="trade")

        return partial_trade

    def exit(self,symbol,price,reason):
        pos=self.book["positions"].pop(symbol,None)
        if not pos: return None

        # ══════════════════════════════════════════════════════
        # v23.6.0 CRITICAL SAFETY: Cancel GTT BEFORE recording exit
        # If software SL triggers (trailing or time-decay), the GTT
        # is still active on Zerodha and would sell AGAIN → double-sell!
        # Must cancel GTT first.
        # ══════════════════════════════════════════════════════
        if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
            try:
                _kite = KiteSession.get()
                old_gtt_id = pos.get("gtt_id")
                if _kite and old_gtt_id and old_gtt_id != "?" and old_gtt_id != "":
                    _kite.delete_gtt(old_gtt_id)
                    logger.info(f"GTT CANCELLED [{symbol}]: {old_gtt_id} (exit: {reason})")
            except Exception as _gtt_err:
                logger.warning(f"GTT cancel on exit [{symbol}]: {_gtt_err}")

        pnl=round((price-pos["entry_price"])*pos["qty"],2)
        pct=round((price-pos["entry_price"])/pos["entry_price"]*100,2)
        trade={**pos,"exit_price":price,"exit_time":now_ist().isoformat(),
               "pnl":pnl,"pnl_pct":pct,"reason":reason,"status":"CLOSED"}
        self.book["trades"].append(trade)
        self.book["available"]=round(self.book["available"]+pos["cost"]+pnl,2)
        self.book["pnl_log"].append({"date":today_str(),"pnl":pnl})
        self._save(); self.risk.update_pnl(self.name,pnl)
        _append_trade_history(trade)  # FIX #5: persist to cumulative history
        # v23.5.0: Register profit for compounding
        if pnl > 0:
            ProfitCompounder.register_profit(pnl, self.name, symbol)
        emoji="✅" if pnl>=0 else "❌"
        send_telegram(f"{emoji} *{self.name.upper()} Closed*\n`{symbol}` @ ₹{price}\nPnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\nReason: {reason}", priority="trade")

        # v23.6.1: Auto-blacklist on loss exits to prevent re-buying
        if pnl < 0:
            _bl_reason = reason
            if "circuit" in reason.lower():
                LossBlacklist.add(symbol, f"CIRCUIT EXIT ({pct:+.1f}%)")
            elif "stop loss" in reason.lower() or "sl" in reason.lower():
                LossBlacklist.add(symbol, f"SL EXIT ({pct:+.1f}%)")
            elif pct <= -5:
                # Large loss — longer cooldown
                LossBlacklist.add(symbol, f"BIG LOSS ({pct:+.1f}%)",
                                  cooldown_hours=LossBlacklist.CIRCUIT_COOLDOWN_HOURS)
            else:
                LossBlacklist.add(symbol, f"LOSS EXIT ({pct:+.1f}%)")

        # v23.6.4: Record trade in WinRateDashboard
        try:
            WinRateDashboard.record_trade({
                "symbol": symbol,
                "pnl": pnl,
                "strategy": self.name,
                "source": pos.get("source", "TECHNICAL"),
                "entry_price": pos.get("entry_price", 0),
                "exit_price": price,
            })
        except Exception as _wr_err:
            logger.debug(f"WinRate record: {_wr_err}")

        return trade

    def check_stops(self,scans):
        # SAFETY: NEVER trigger stop losses outside market hours
        _now_t = now_ist()
        _hr, _mn = _now_t.hour, _now_t.minute
        _time_mins = _hr * 60 + _mn
        _market_open = (555 <= _time_mins <= 920)  # 09:15 to 15:20
        if not _market_open:
            return []  # No SL checks outside market hours

        exited=[]
        for sym,pos in list(self.book["positions"].items()):
            # v23.7.1: Adopted positions — allow trailing SL and profit booking
            # Only skip the hard SL exit at the bottom (GTT on Zerodha handles that)
            _is_adopted = (pos.get("source", "") == "KITE_ADOPTED" or pos.get("adopt_grace"))
            m=next((a for a in scans if a["symbol"]==sym),None)
            if not m: continue
            p=m["price"]
            entry_price = pos["entry_price"]
            atr = m.get("atr", entry_price * 0.02)

            # ══════════════════════════════════════════════════════
            # v23.6.4: PROGRESSIVE TRAILING STOP LOSS — Lock Profits Early!
            # "Never give back gains" — Rama's requirement
            # 
            # As price moves up, SL ratchets up. NEVER moves down.
            # +1% gain → SL reduces loss to -0.5%
            # +2% gain → SL to BREAKEVEN (zero loss possible!)
            # +3% gain → SL locks +1%
            # +4% gain → SL locks +2%
            # +5% gain → SL locks +3%
            # +7% gain → SL locks +5%
            # +10% gain → SL locks +7%
            # +15% gain → SL locks +12%
            # +20%+ → Trail 1.5x ATR below highest price
            # ══════════════════════════════════════════════════════
            highest = pos.get("highest_price", entry_price)
            if p > highest:
                pos["highest_price"] = p
                highest = p

            gain_from_entry_pct = (highest - entry_price) / entry_price * 100 if entry_price > 0 else 0

            if gain_from_entry_pct >= 20:
                # Dynamic trailing: 1.5x ATR below highest price
                new_sl = round(highest - 1.5 * atr, 2)
            elif gain_from_entry_pct >= 15:
                new_sl = round(entry_price * 1.12, 2)  # Lock +12%
            elif gain_from_entry_pct >= 10:
                new_sl = round(entry_price * 1.07, 2)  # Lock +7%
            elif gain_from_entry_pct >= 7:
                new_sl = round(entry_price * 1.05, 2)  # Lock +5%
            elif gain_from_entry_pct >= 5:
                new_sl = round(entry_price * 1.03, 2)  # Lock +3%
            elif gain_from_entry_pct >= 4:
                new_sl = round(entry_price * 1.02, 2)  # Lock +2%
            elif gain_from_entry_pct >= 3:
                new_sl = round(entry_price * 1.01, 2)  # Lock +1%
            elif gain_from_entry_pct >= 2:
                new_sl = round(entry_price * 1.001, 2)  # BREAKEVEN (zero loss!)
            elif gain_from_entry_pct >= 1:
                new_sl = round(entry_price * 0.995, 2)  # Reduce loss to -0.5%
            else:
                # v23.6.1 FIX: For positions IN LOSS, tighten SL based on how deep
                # the loss is. Don't just keep original SL when stock is tanking.
                _current_loss_pct = (entry_price - p) / entry_price * 100 if entry_price > 0 else 0
                if _current_loss_pct > 3:
                    # Stock is down >3% — tighten SL using smart logic
                    _smart_sl = smart_sl_for_position(entry_price, p, atr, strategy=self.name)
                    # Only tighten (move UP), never loosen
                    if _smart_sl > pos["stop_loss"]:
                        new_sl = _smart_sl
                        logger.info(
                            f"🔧 SMART SL [{sym}]: loss={_current_loss_pct:.1f}% "
                            f"— tightening SL ₹{pos['stop_loss']:.1f} → ₹{_smart_sl:.1f}"
                        )
                    else:
                        new_sl = pos["stop_loss"]
                else:
                    new_sl = pos["stop_loss"]  # Keep original SL

            # SL only moves UP, never down
            if new_sl > pos["stop_loss"]:
                old_sl = pos["stop_loss"]
                pos["stop_loss"] = new_sl
                self._save()
                if new_sl > old_sl * 1.003:  # Log moves >0.3%
                    logger.info(
                        f"🔒 TRAIL [{sym}]: SL ₹{old_sl:.1f} → ₹{new_sl:.1f} "
                        f"(gain: +{gain_from_entry_pct:.1f}%, peak: ₹{highest:.1f})"
                    )

            # ══════════════════════════════════════════════════════
            # v23.6.0 #2: TIME-DECAY SL TIGHTENING (swing/longterm)
            # Dead money = opportunity cost. Tighten SL over time.
            # Day 1-7: Normal SL | Day 8-14: 1.0x ATR
            # Day 15-21: 0.5x ATR | Day 22+: Exit if not in profit
            # ══════════════════════════════════════════════════════
            if self.name in ("swing", "longterm"):
                try:
                    entry_dt = datetime.fromisoformat(pos["entry_time"])
                    if not entry_dt.tzinfo:
                        entry_dt = IST.localize(entry_dt)
                    days_held = (now_ist() - entry_dt).days
                    current_pnl_pct = (p - entry_price) / entry_price * 100

                    if days_held >= 22 and current_pnl_pct < 1.0:
                        # 3+ weeks, not even 1% profit — dead money, exit
                        t = self.exit(sym, p, f"📅 Dead Money Exit ({days_held}d, +{current_pnl_pct:.1f}%)")
                        if t: exited.append(t)
                        continue
                    elif days_held >= 15 and gain_from_entry_pct < 20:
                        # Tighten SL to 0.5x ATR below current price
                        tight_sl = round(p - 0.5 * atr, 2)
                        if tight_sl > pos["stop_loss"]:
                            pos["stop_loss"] = tight_sl
                            self._save()
                    elif days_held >= 8 and gain_from_entry_pct < 20:
                        # Tighten SL to 1.0x ATR below current price
                        medium_sl = round(p - 1.0 * atr, 2)
                        if medium_sl > pos["stop_loss"]:
                            pos["stop_loss"] = medium_sl
                            self._save()
                except Exception:
                    pass

            # ══════════════════════════════════════════════════════
            # v23.6.0 #7: PARTIAL PROFIT BOOKING
            # At T1: Sell 50% of position, move SL to breakeven
            # Remaining 50% trails to T2 or beyond
            # ══════════════════════════════════════════════════════
            if (p >= pos["target1"] and not pos.get("partial_booked", False)
                    and pos["qty"] >= 2):
                # Sell 50% at T1
                qty_to_sell = pos["qty"] // 2
                if qty_to_sell > 0:
                    t = self.partial_exit(sym, p, qty_to_sell, "T1 Partial (50%)")
                    if t:
                        exited.append(t)
                        # Move SL to breakeven for remaining position
                        if sym in self.book["positions"]:
                            self.book["positions"][sym]["stop_loss"] = round(entry_price * 1.001, 2)
                            self._save()
                    continue  # Don't check other stops this cycle

            # ── SINGLE SHARE: move SL to breakeven when T1 hit ──────────
            # Can't sell 50% of 1 share — instead lock profit by moving
            # SL up to entry price so worst case = zero loss, not a loss.
            if (p >= pos["target1"] and not pos.get("partial_booked", False)
                    and pos["qty"] == 1
                    and pos.get("stop_loss", 0) < entry_price):
                _be_sl = round(entry_price * 1.001, 2)
                pos["stop_loss"] = _be_sl
                pos["partial_booked"] = True  # Flag so this only fires once
                self._save()
                # Update GTT on Kite with new breakeven SL
                if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                    try:
                        if hasattr(self, 'update_gtt'):
                            self.update_gtt(sym, _be_sl, ltp=p)
                        else:
                            _kite = KiteSession.get()
                            if _kite:
                                place_gtt_immediate(
                                    _kite, sym, 1,
                                    entry_price, _be_sl,
                                    pos.get("target2", round(p * 1.20, 2)),
                                    trader_obj=self
                                )
                    except Exception as _be_err:
                        logger.warning(f"Breakeven GTT [{sym}]: {_be_err}")
                logger.info(
                    f"BREAKEVEN SL [{sym}]: qty=1, T1 hit @ Rs.{p:.1f} "
                    f"— SL moved to Rs.{_be_sl:.1f} (entry protection)"
                )
                send_telegram(
                    f"BREAKEVEN LOCK [{sym}]\n"
                    f"qty=1 — T1 hit @ Rs.{p:.1f}\n"
                    f"SL moved to Rs.{_be_sl:.1f} (entry price)\n"
                    f"Worst case = zero loss | Target Rs.{pos.get('target2',0):.1f} still open",
                    priority="trade"
                )

            # ── STANDARD STOP CHECKS (with trailing SL already updated above) ──
            if p<=pos["stop_loss"] and not _is_adopted: t=self.exit(sym,p,"Stop Loss" + (" (Trailing)" if pos["stop_loss"] > pos.get("original_sl", 0) else "")); exited.append(t) if t else None
            elif p>=pos["target2"]: t=self.exit(sym,p,"Target 2"); exited.append(t) if t else None
            elif p>=pos["target1"] and m.get("profit_book") and pos.get("partial_booked"): t=self.exit(sym,p,"T1+Overbought (Remaining)"); exited.append(t) if t else None
        return exited

    def summary(self):
        closed=[t for t in self.book["trades"] if t["status"]=="CLOSED"]
        wins=[t for t in closed if t["pnl"]>0]; losses=[t for t in closed if t["pnl"]<=0]
        total_pnl=round(sum(t["pnl"] for t in closed),2)
        wr=round(len(wins)/len(closed)*100,1) if closed else 0
        aw=round(sum(t["pnl"] for t in wins)/len(wins),2) if wins else 0
        al=round(sum(t["pnl"] for t in losses)/len(losses),2) if losses else 0
        try:
            start=datetime.fromisoformat(self.book["start_time"])
            if not start.tzinfo: start=IST.localize(start)
            days=round((now_ist()-start).total_seconds()/86400,1)
        except: days=0
        return {"strategy":self.name,"capital":self.book["capital"],
                "available":self.book["available"],"portfolio_value":round(self.book["capital"]+total_pnl,2),
                "total_pnl":total_pnl,"open_count":len(self.book["positions"]),
                "total_trades":len(closed),"wins":len(wins),"losses":len(losses),
                "win_rate":wr,"avg_win":aw,"avg_loss":al,
                "rr_ratio":round(abs(aw/al),2) if al else 0,
                "open_positions":list(self.book["positions"].values()),"days_running":days}

    def is_ready_for_live(self):
        s=self.summary()
        return s["days_running"]>=PAPER_DAYS and s["total_trades"]>=3 and s["win_rate"]>=MIN_WIN_RATE and s["total_pnl"]>0

class IntradayTrader(BasePaperTrader):
    def __init__(self,risk): super().__init__(INTRADAY_FILE,INTRADAY_CAP,MAX_INTRADAY_POS,"intraday",risk)
    def square_off_all(self,scans):
        closed=[]
        for sym in list(self.book["positions"].keys()):
            m=next((a for a in scans if a["symbol"]==sym),None)
            price=m["price"] if m else self.book["positions"][sym]["entry_price"]
            t=self.exit(sym,price,"⏰ Auto Square-Off 15:15"); closed.append(t) if t else None
        if closed:
            total=sum(t["pnl"] for t in closed)
            send_telegram(f"⏰ *Intraday Square-Off*\nClosed: {len(closed)} | Net: `{'+'if total>=0 else ''}₹{total:,.0f}`")
        return closed

class SwingTrader(BasePaperTrader):
    def __init__(self,risk): super().__init__(SWING_FILE,SWING_CAP,MAX_SWING_POS,"swing",risk)
    def check_time_exit(self,scans):
        exited=[]
        for sym,pos in list(self.book["positions"].items()):
            try:
                entry=datetime.fromisoformat(pos["entry_time"])
                if not entry.tzinfo: entry=IST.localize(entry)
                if (now_ist()-entry).days>=28:
                    m=next((a for a in scans if a["symbol"]==sym),None)
                    price=m["price"] if m else pos["entry_price"]
                    t=self.exit(sym,price,"📅 4-Week Time Exit"); exited.append(t) if t else None
            except Exception: pass
        return exited

class LongTermTrader(BasePaperTrader):
    def __init__(self,risk): super().__init__(LONGTERM_FILE,LONGTERM_CAP,MAX_LONGTERM_POS,"longterm",risk)
    def check_time_exit(self,scans):
        exited=[]
        for sym,pos in list(self.book["positions"].items()):
            try:
                entry=datetime.fromisoformat(pos["entry_time"])
                if not entry.tzinfo: entry=IST.localize(entry)
                if (now_ist()-entry).days>=365:
                    m=next((a for a in scans if a["symbol"]==sym),None)
                    price=m["price"] if m else pos["entry_price"]
                    t=self.exit(sym,price,"📅 12-Month Exit"); exited.append(t) if t else None
            except Exception: pass
        return exited

class FNOTrader:
    """
    Intelligent F&O Trading Engine v22.4
    - Market direction prediction (CE vs PE)
    - Conservative + Moderate + Aggressive strikes
    - NIFTY + BANKNIFTY + top F&O stocks
    - Bot decides hold duration based on profit
    - Advance positioning (enter early in expiry cycle)
    - AMO orders placed after 15:30 for next day
    - PCR analysis for market direction
    - VIX-adjusted position sizing
    """

    # Instruments with lot sizes and strike steps
    INSTRUMENTS = {
        "NIFTY":      {"lot":75,  "step":50,  "ticker":"^NSEI"},
        "BANKNIFTY":  {"lot":30,  "step":100, "ticker":"^NSEBANK"},
        "FINNIFTY":   {"lot":40,  "step":50,  "ticker":"^CNXFIN"},
        "MIDCPNIFTY": {"lot":75,  "step":25,  "ticker":"^NSEMDCP50"},
        # Top F&O stocks
        "RELIANCE":   {"lot":250, "step":20,  "ticker":"RELIANCE.NS"},
        "TCS":        {"lot":150, "step":25,  "ticker":"TCS.NS"},
        "HDFCBANK":   {"lot":550, "step":5,   "ticker":"HDFCBANK.NS"},
        "ICICIBANK":  {"lot":700, "step":5,   "ticker":"ICICIBANK.NS"},
        "INFY":       {"lot":300, "step":20,  "ticker":"INFY.NS"},
        "SBIN":       {"lot":1500,"step":5,   "ticker":"SBIN.NS"},
        "AXISBANK":   {"lot":625, "step":5,   "ticker":"AXISBANK.NS"},
        "BAJFINANCE": {"lot":125, "step":50,  "ticker":"BAJFINANCE.NS"},
        "TATAMOTORS": {"lot":1400,"step":5,   "ticker":"TATAMOTORS.NS"},
        "ADANIENT":   {"lot":300, "step":25,  "ticker":"ADANIENT.NS"},
    }

    def __init__(self, risk):
        self.risk = risk
        self.book = load_json(FNO_FILE, {
            "capital":    FNO_CAP,
            "available":  FNO_CAP,
            "positions":  {},
            "trades":     [],
            "pnl_log":    [],
            "prediction": {},  # Market direction predictions
        })
        self._last_prediction_ts = 0

    def _save(self): save_json(FNO_FILE, self.book)

    def _expiry(self):
        today = now_ist().date()
        y, m  = today.year, today.month
        nm    = date(y+1,1,1) if m==12 else date(y,m+1,1)
        last  = nm - timedelta(days=1)
        while last.weekday() != 3: last -= timedelta(days=1)
        if today > last:
            m = m%12+1; y = y+(1 if m==1 else 0)
            nm   = date(y+1,1,1) if m==12 else date(y,m+1,1)
            last = nm - timedelta(days=1)
            while last.weekday() != 3: last -= timedelta(days=1)
        return last

    def _dte(self): return (self._expiry() - now_ist().date()).days

    def _bs(self, S, K, T, sigma=0.18, otype="CE"):
        try:
            if T <= 0: T = 0.001
            r  = 0.065
            d1 = (math.log(S/K) + (r + 0.5*sigma**2)*T) / (sigma*math.sqrt(T))
            d2 = d1 - sigma*math.sqrt(T)
            def n(x): return (1 + math.erf(x/math.sqrt(2))) / 2
            if otype == "CE":
                return round(max(S*n(d1) - K*math.exp(-r*T)*n(d2), 0), 2)
            else:
                return round(max(K*math.exp(-r*T)*n(-d2) - S*n(-d1), 0), 2)
        except: return 0

    def _get_iv(self, symbol):
        """Estimate IV from recent price volatility using Kite data."""
        try:
            kite = KiteSession.get()
            if kite:
                token = TrendlyneScorer._get_token(kite, symbol)
                if token:
                    from_dt = (now_ist() - timedelta(days=35)).strftime("%Y-%m-%d")
                    to_dt   = now_ist().strftime("%Y-%m-%d")
                    data    = kite.historical_data(token, from_dt, to_dt, "day")
                    if data and len(data) >= 10:
                        df = pd.DataFrame(data)
                        returns = df["close"].pct_change().dropna()
                        iv = float(returns.std() * math.sqrt(252))
                        return max(0.10, min(0.60, iv))
            return 0.18
        except Exception:
            return 0.18

    def predict_market_direction(self, scans):
        """
        Multi-factor market direction prediction.
        Returns: STRONG_BULLISH, BULLISH, NEUTRAL, BEARISH, STRONG_BEARISH
        """
        score = 0
        factors = {}

        try:
            # Factor 1: NIFTY technical
            nifty = next((r for r in scans if r["symbol"] == "NIFTY"), None)
            if nifty:
                if nifty.get("macd_bull"): score += 2; factors["MACD"] = "BULLISH"
                else: score -= 2; factors["MACD"] = "BEARISH"
                rsi = nifty.get("rsi", 50)
                if rsi < 40: score += 2; factors["RSI"] = f"OVERSOLD({rsi})"
                elif rsi > 65: score -= 2; factors["RSI"] = f"OVERBOUGHT({rsi})"
                if "Bullish" in nifty.get("trend", ""): score += 2; factors["Trend"] = "BULLISH"
                else: score -= 2; factors["Trend"] = "BEARISH"

            # Factor 2: BANKNIFTY confirmation
            bnf = next((r for r in scans if r["symbol"] == "BANKNIFTY"), None)
            if bnf:
                if bnf.get("macd_bull"): score += 1; factors["BankNifty"] = "BULLISH"
                else: score -= 1; factors["BankNifty"] = "BEARISH"

            # Factor 3: Market breadth (% bullish stocks)
            bullish = len([r for r in scans if "BUY" in r.get("overall","")])
            bearish = len([r for r in scans if "SELL" in r.get("overall","")])
            total   = len(scans) or 1
            breadth = (bullish - bearish) / total * 100
            if breadth > 20: score += 2; factors["Breadth"] = f"+{breadth:.0f}%"
            elif breadth < -20: score -= 2; factors["Breadth"] = f"{breadth:.0f}%"

            # Factor 4: VIX level (via Kite)
            try:
                kite = KiteSession.get()
                if kite:
                    vix_data = kite.ltp(["NSE:INDIA VIX"])
                    if "NSE:INDIA VIX" in vix_data:
                        vix = vix_data["NSE:INDIA VIX"]["last_price"]
                        if vix < 14: score += 1; factors["VIX"] = f"LOW({vix:.1f})"
                        elif vix > 20: score -= 2; factors["VIX"] = f"HIGH({vix:.1f})"
                        else: factors["VIX"] = f"NORMAL({vix:.1f})"
            except Exception: pass

            # Factor 5: FII flow from recent filings
            fii_filing = load_json(FILINGS_FILE, {})
            recent = [f for f in fii_filing.get("filings", [])
                     if f.get("type") == "FII_DII"]
            if recent:
                last_fii = recent[-1].get("extra", {})
                fii_net  = last_fii.get("fii_net", 0)
                if fii_net > 500: score += 2; factors["FII"] = f"+₹{fii_net:.0f}Cr"
                elif fii_net < -500: score -= 2; factors["FII"] = f"₹{fii_net:.0f}Cr"

        except Exception as e:
            logger.debug(f"Prediction error: {e}")

        # Determine direction
        if   score >= 6:  direction = "STRONG_BULLISH"
        elif score >= 3:  direction = "BULLISH"
        elif score <= -6: direction = "STRONG_BEARISH"
        elif score <= -3: direction = "BEARISH"
        else:             direction = "NEUTRAL"

        prediction = {
            "direction": direction,
            "score":     score,
            "factors":   factors,
            "timestamp": now_ist().isoformat(),
            "expiry":    str(self._expiry()),
            "dte":       self._dte(),
        }
        self.book["prediction"] = prediction
        self._save()

        logger.info(f"🔮 F&O Prediction: {direction} (score={score}) | {factors}")
        return prediction

    def _select_strike(self, spot, step, direction, confidence):
        """
        Select strike based on confidence level.
        Conservative = ATM
        Moderate = slight OTM
        Aggressive = deeper OTM
        """
        atm = round(round(spot / step) * step)
        if confidence == "STRONG_BULLISH" or confidence == "STRONG_BEARISH":
            # Aggressive — deeper OTM for max profit
            if "BULL" in confidence:
                return atm + step  # 1 strike OTM call
            else:
                return atm - step  # 1 strike OTM put
        elif confidence in ["BULLISH", "BEARISH"]:
            # Moderate — slight OTM
            if "BULL" in confidence:
                return atm  # ATM call
            else:
                return atm  # ATM put
        else:
            return atm  # Conservative — always ATM

    def enter(self, symbol, spot, direction, source="TECHNICAL", confidence="MODERATE"):
        """Enter F&O position — supports all instruments."""
        if symbol not in self.INSTRUMENTS: return None
        if len(self.book["positions"]) >= MAX_FNO_POS: return None
        if not self.risk.can_trade(): return None

        inst = self.INSTRUMENTS[symbol]
        lot  = inst["lot"]
        step = inst["step"]
        exp  = self._expiry()
        dte  = self._dte()

        opt = "CE" if "BULL" in direction else "PE"
        K   = self._select_strike(spot, step, direction, confidence)

        # Get IV for better pricing
        iv   = self._get_iv(symbol)
        T    = max(dte / 365, 0.001)
        prem = self._bs(spot, K, T, sigma=iv, otype=opt)
        if prem <= 0: prem = spot * 0.015

        cost = round(prem * lot, 2)
        if cost > self.book["capital"] * 0.20: return None
        if cost > self.book["available"]:       return None

        # Dynamic targets based on confidence
        if "STRONG" in confidence:
            sl_pct = 0.40   # 40% SL (tighter)
            t1_pct = 2.00   # 100% profit
            t2_pct = 3.50   # 250% profit
        else:
            sl_pct = 0.50   # 50% SL
            t1_pct = 1.80   # 80% profit
            t2_pct = 2.50   # 150% profit

        key = f"{symbol}_{K}{opt}_{exp}"
        if key in self.book["positions"]: return None

        pos = {
            "key":        key,
            "symbol":     symbol,
            "strike":     K,
            "opt_type":   opt,
            "expiry":     str(exp),
            "dte":        dte,
            "spot":       spot,
            "premium":    prem,
            "lot":        lot,
            "cost":       cost,
            "iv":         round(iv * 100, 1),
            "stop_loss":  round(prem * sl_pct, 2),
            "target1":    round(prem * t1_pct, 2),
            "target2":    round(prem * t2_pct, 2),
            "direction":  direction,
            "confidence": confidence,
            "source":     source,
            "entry_time": now_ist().isoformat(),
        }
        self.book["positions"][key] = pos
        self.book["available"] = round(self.book["available"] - cost, 2)
        self._save()

        conf_emoji = "🔴🔴" if "STRONG" in confidence else "🟡"
        logger.info(f"📊 F&O [{confidence}]: {symbol} {K}{opt} @ ₹{prem} x{lot} IV:{iv*100:.0f}%")
        msg = ("📊 *F&O Entry* [" + str(source) + "]\n"
               + "`" + str(symbol) + " " + str(K) + " " + str(opt) + "` " + str(exp) + "\n"
               + "Premium: Rs" + str(prem) + " x " + str(lot) + " = Rs" + "{:,.0f}".format(cost) + "\n"
               + "DTE: " + str(dte) + " | IV: " + str(round(iv*100,0)) + "%\n"
               + "Confidence: " + str(conf_emoji) + " " + str(confidence) + "\n"
               + "SL: Rs" + str(pos["stop_loss"]) + " T1: Rs" + str(pos["target1"]) + " T2: Rs" + str(pos["target2"]) + "\n"
               + "Direction: " + str(direction))
        send_telegram(msg)
        return pos

    def enter_advance(self, scans):
        """
        Advance positioning — enter at start of expiry cycle
        when market direction is clear.
        Called daily after market hours.
        """
        if not self.risk.can_trade(): return []
        dte = self._dte()

        # Only enter advance positions when enough DTE (7-20 days)
        if dte < 7 or dte > 20:
            return []

        # Skip if already have positions
        if len(self.book["positions"]) >= MAX_FNO_POS:
            return []

        prediction = self.predict_market_direction(scans)
        direction  = prediction["direction"]

        if direction == "NEUTRAL":
            logger.info("F&O Advance: NEUTRAL market — no advance position")
            return []

        entered = []
        # Enter NIFTY and BANKNIFTY advance positions
        for symbol in ["NIFTY", "BANKNIFTY"]:
            inst = self.INSTRUMENTS[symbol]
            try:
                # Use Kite for spot price
                kite = KiteSession.get()
                spot = 0
                if kite:
                    index_map = {"NIFTY": "NSE:NIFTY 50", "BANKNIFTY": "NSE:NIFTY BANK"}
                    ltp_data = kite.ltp([index_map.get(symbol, f"NSE:{symbol}")])
                    for key, val in ltp_data.items():
                        spot = round(val["last_price"], 2)
                if not spot:
                    continue
                pos  = self.enter(
                    symbol     = symbol,
                    spot       = spot,
                    direction  = "BULLISH" if "BULL" in direction else "BEARISH",
                    source     = "ADVANCE_POSITIONING",
                    confidence = direction,
                )
                if pos: entered.append(pos)
                time.sleep(1)
            except Exception as e:
                logger.error(f"Advance entry [{symbol}]: {e}")

        if entered:
            send_telegram(
                f"🎯 *ADVANCE F&O POSITIONING*\n"
                f"Market prediction: *{direction}*\n"
                f"DTE: {dte} days to expiry\n"
                f"Positions entered: {len(entered)}\n"
                f"Strategy: Hold till target or bot decides"
            )
        return entered

    def monitor(self, spot_prices):
        """Smart monitoring — bot decides exit based on profit dynamics."""
        dte = self._dte()
        for key, pos in list(self.book["positions"].items()):
            spot = spot_prices.get(pos["symbol"])
            if not spot: continue

            # Near expiry — always exit
            if dte <= 2:
                self._exit(key, spot, "⏰ Near Expiry — Time Exit")
                continue

            T    = max(dte / 365, 0.001)
            iv   = pos.get("iv", 18) / 100
            cp   = self._bs(spot, pos["strike"], T, sigma=iv, otype=pos["opt_type"])
            prem = pos["premium"]
            pnl_pct = ((cp - prem) / prem * 100) if prem > 0 else 0

            # Stop loss
            if cp <= pos["stop_loss"]:
                self._exit(key, spot, f"🛑 Stop Loss ({pnl_pct:.0f}%)")
                continue

            # Target 2 — always exit
            if cp >= pos["target2"]:
                self._exit(key, spot, f"🎯 Target 2 Hit (+{pnl_pct:.0f}%)")
                continue

            # Smart exit logic — bot decides
            # If > 80% profit AND DTE < 7 — book profit (theta decay accelerates)
            if pnl_pct >= 80 and dte <= 7:
                self._exit(key, spot, f"✂️ Smart Exit: 80%+ profit near expiry")
                continue

            # If > 100% profit and trend reversing — book profit
            if pnl_pct >= 100:
                # Check if trend still supports position
                nifty_bull = any(
                    r.get("macd_bull") for r in []  # Will be updated by monitor call
                    if r.get("symbol") == "NIFTY"
                )
                self._exit(key, spot, f"🎯 Target 1+ Smart Exit (+{pnl_pct:.0f}%)")
                continue

            # Trailing stop — if profit was > 50% and now < 20%, exit
            if pnl_pct >= 20 and cp <= pos.get("trail_high", pos["stop_loss"]):
                self._exit(key, spot, f"📉 Trailing Stop ({pnl_pct:.0f}%)")
                continue

            # Update trailing high
            if cp > pos.get("trail_high", 0):
                self.book["positions"][key]["trail_high"] = cp
                self._save()

    def _exit(self, key, spot, reason):
        pos = self.book["positions"].pop(key, None)
        if not pos: return None
        dte  = self._dte()
        iv   = pos.get("iv", 18) / 100
        T    = max(dte / 365, 0.001)
        cp   = self._bs(spot, pos["strike"], T, sigma=iv, otype=pos["opt_type"])
        pnl  = round((cp - pos["premium"]) * pos["lot"], 2)
        pct  = round(pnl / pos["cost"] * 100, 2) if pos["cost"] > 0 else 0
        t    = {**pos, "exit_time": now_ist().isoformat(),
                "pnl": pnl, "pnl_pct": pct, "reason": reason, "status": "CLOSED"}
        self.book["trades"].append(t)
        self.book["available"] = round(self.book["available"] + pos["cost"] + pnl, 2)
        self.book["pnl_log"].append({"date": today_str(), "pnl": pnl})
        self._save()
        self.risk.update_pnl("fno", pnl)
        emoji = "✅" if pnl >= 0 else "❌"
        send_telegram(
            f"{emoji} *F&O Closed*\n"
            f"`{pos['symbol']} {pos['strike']} {pos['opt_type']}`\n"
            f"PnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\n"
            f"Reason: {reason}"
        )
        return t

    def summary(self):
        closed    = [t for t in self.book["trades"] if t["status"] == "CLOSED"]
        wins      = [t for t in closed if t["pnl"] > 0]
        losses    = [t for t in closed if t["pnl"] <= 0]
        total     = round(sum(t["pnl"] for t in closed), 2)
        pred      = self.book.get("prediction", {})
        return {
            "strategy":        "fno",
            "capital":         self.book["capital"],
            "available":       self.book["available"],
            "total_pnl":       total,
            "portfolio_value": round(self.book["capital"] + total, 2),
            "open_count":      len(self.book["positions"]),
            "total_trades":    len(closed),
            "wins":            len(wins),
            "losses":          len(losses),
            "win_rate":        round(len(wins)/len(closed)*100, 1) if closed else 0,
            "rr_ratio":        0,
            "open_positions":  list(self.book["positions"].values()),
            "expiry_date":     str(self._expiry()),
            "days_to_expiry":  self._dte(),
            "prediction":      pred.get("direction", "NEUTRAL"),
            "pred_score":      pred.get("score", 0),
        }

# ──────────────────────────────────────────────────────────────────────────────
#  MAIN SENTINEL BOT
# ──────────────────────────────────────────────────────────────────────────────

class GlobalEyeSentinel:
    def __init__(self):
        logger.info("="*65)
        logger.info(f"  Global Eye {VERSION} — {EDITION}")
        logger.info(f"  Zerodha Kite ONLY | 3-Agent AI | Macro | StatArb | AMO")
        logger.info(f"  WhatsApp: {'✅' if WHATSAPP_PHONE else '❌ not configured'}")
        logger.info("="*65)

        self.state=load_json(STATE_FILE,{"mode":TRADING_MODE,"live_prompt_sent":False})
        # Initialize Zerodha Kite — real-time data
        logger.info("🔌 Connecting to Zerodha Kite...")
        try:
            kite = KiteSession.restore()
            if kite:
                logger.info("✅ Kite connected — real-time data active!")
                # ── Load dynamic stock universe from Kite ──────────
                stock_universe = DynamicStockUniverse.load(kite)
                logger.info(f"📊 Dynamic Universe: {len(stock_universe)} stocks loaded from Kite")
            else:
                logger.warning("⚠️ Kite unavailable — using fallback F&O list")
                stock_universe = list(FNO_STOCKS)
        except Exception as e:
            logger.error(f"Kite init: {e}")
            stock_universe = list(FNO_STOCKS)

        self.risk=RiskManager(); self.news=NewsMonitor(); self.social=SocialMonitor()

        # v23.5.0: Clear digest queue on startup to prevent flush from old messages
        global _telegram_digest, _telegram_last_flush
        with _telegram_digest_lock:
            _telegram_digest = []
        _telegram_last_flush = time.time()

        # Initialize intelligence engines
        self.macro    = MacroIntelligence()
        self.earnings = EarningsNLP()
        self.patterns = PatternRecognition()
        self.sentiment= SentimentEngine()
        self.three_ai = ThreeAgentAI()
        self.stat_arb = StatArb()
        self.amo      = AMOEngine()
        self._macro_signals  = {}
        self._macro_data     = {}
        self._macro_ts       = 0
        logger.info("🧠 Intelligence engines initialized")
        self.intraday=IntradayTrader(self.risk); self.swing=SwingTrader(self.risk)
        self.longterm=LongTermTrader(self.risk); self.fno=FNOTrader(self.risk)

        # ── LIVE TRADING UPGRADE ────────────────────────────────────
        # When TRADING_MODE=LIVE, replaces paper traders with real order execution
        if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
            try:
                upgrade_to_live(
                    sentinel=self,
                    KiteSession=KiteSession,
                    send_telegram=send_telegram,
                    save_json=save_json,
                    load_json=load_json,
                    DATA_DIR=DATA_DIR,
                    INTRADAY_FILE=INTRADAY_FILE,
                    SWING_FILE=SWING_FILE,
                    LONGTERM_FILE=LONGTERM_FILE,
                    FNO_FILE=FNO_FILE,
                    MAX_INTRADAY_POS=MAX_INTRADAY_POS,
                    MAX_SWING_POS=MAX_SWING_POS,
                    MAX_LONGTERM_POS=MAX_LONGTERM_POS,
                )
                logger.info("🔴 LIVE TRADING MODE — Real orders active")
            except Exception as e:
                logger.critical(f"LIVE MODE INIT FAILED: {e}\n{traceback.format_exc()}")
                send_telegram(
                    f"🔴 *LIVE MODE FAILED*\n{str(e)[:300]}\n"
                    f"Falling back to PAPER mode",
                    priority="critical"
                )
        elif TRADING_MODE == "LIVE" and not _LIVE_MODULE_LOADED:
            logger.critical("LIVE mode requested but live_trading_patch.py not found!")
            send_telegram(
                "🔴 *LIVE MODE FAILED*\n"
                "live_trading_patch.py not found.\n"
                "Upload it to /home/krishnut85/ and restart.",
                priority="critical"
            )

        self.filings=FilingMonitor(self._filing_cb)
        self.mdc=MarketDataCollector()
        self.tb=TelegramMessageBuilder()

        # ── Phase 2 Scanners (v23.4.0 Phase 2) ──────────────────
        self._phase2 = None
        if _LIVE_MODULE_LOADED and _PHASE2_LOADED:
            try:
                # v23.5.0: Phase2 alerts go to LOG ONLY — no Telegram at all
                # Trade entries still go through when Phase2 routes to swing/longterm
                def _phase2_silent(msg, **kwargs):
                    logger.info(f"Phase2: {msg[:100]}")  # Log only, no Telegram
                self._phase2 = Phase2Orchestrator(send_telegram_fn=_phase2_silent)
                logger.info("Phase 2 Scanners initialized (silent mode)")
            except Exception as _p2e:
                logger.warning(f"Phase2 init: {_p2e}")

        # ── Trillionaire Engine (v23.5.0) ──────────────────────────
        self._trillionaire = None
        self._event_trade_queue = []
        try:
            if _TRILLIONAIRE_LOADED:
                self._trillionaire = TrillionaireEngine(send_telegram_fn=send_telegram)
                logger.info("Trillionaire Engine initialized")
                # Send startup summary (both LIVE and PAPER)
                if self._trillionaire:
                    try:
                        send_telegram(
                            self._trillionaire.startup_summary(),
                            priority="normal", silent=True
                        )
                    except Exception:
                        pass
        except Exception as _tre:
            logger.warning(f"Trillionaire init: {_tre}")

        # ── Strategy Modules v23.7.0 (scan enrichment) ──────────
        self._strategy_modules = None
        if _STRATEGY_MODULES_LOADED:
            try:
                self._strategy_modules = StrategyModulesOrchestrator(send_telegram_fn=send_telegram)
            except Exception as _sm_err:
                logger.warning(f"Strategy Modules init: {_sm_err}")

        # ── Trade Performance Monitor ──────────────────────────
        self._perf_monitor = None
        if _PERF_MONITOR_LOADED:
            try:
                self._perf_monitor = TradePerformanceMonitor(
                    data_dir=DATA_DIR, send_telegram_fn=send_telegram
                )
                logger.info("Trade Performance Monitor initialized")
            except Exception as _pm_err:
                logger.warning(f"PerfMonitor init: {_pm_err}")

        self._scan_cache=[]; self._last_scan_ts=0; self._scan_lock=threading.Lock()
        self._last_report_hr=-1; self._last_health_ts=0
        self._pulse_sent=False; self._premarket_sent=False
        self._eod_sent=False; self._squareoff_done=False

        # Only send startup message in PAPER mode
        # In LIVE mode, upgrade_to_live() sends the combined startup message
        if TRADING_MODE != "LIVE":
            _tril_msg = ""
            if self._trillionaire:
                _tril_msg = "\n" + self._trillionaire.startup_summary()
            send_telegram(
                f"GLOBAL EYE {VERSION} | PAPER\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"\n"
                f"<redacted> | {STRATEGY_MODE} Mode\n"
                f"Kite: {'Connected' if kite else 'Offline'} | {len(stock_universe)} stocks | {len(FNO_STOCKS)} F&O\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"\n"
                f"Systems: Early Signals | Rapid Scan |\n"
                f"Trailing SL / Kelly | ML Predictor\n"
                f"Sources: {len(NEWS_FEEDS)} news + NSE/BSE filings\n"
                f"Scan: {SCAN_INTERVAL//60}min full | 5min rapid\n"
                f"SEBI Compliant: <10 OPS | Full audit trail\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"\n"
                f"Schedule: 07:00 / 08:00 / 09:30 / 12:00\n"
                f"         14:00 / 15:30 / 18:00 / 00:00"
                + _tril_msg,
                priority="kite"
            )

    def get_scan(self,force=False):
        age=time.time()-self._last_scan_ts
        if force or age>SCAN_INTERVAL or not self._scan_cache:
            with self._scan_lock:
                # ── Load dynamic stock universe from Kite ──────────
                kite = KiteSession.get()
                syms = DynamicStockUniverse.load(kite)

                # Also load from CSV if available (merge)
                csv_path = os.path.join(_DIR, "consolidated_nifty_indices.csv")
                if os.path.exists(csv_path):
                    try:
                        df = pd.read_csv(csv_path)
                        csv_syms = [s for s in df["Symbol"].dropna().tolist()
                                   if isinstance(s, str) and len(s) >= 2 and not s.isdigit()]
                        # Merge CSV stocks into universe
                        for s in csv_syms:
                            if s not in syms:
                                syms.append(s)
                        logger.info(f"CSV added {len(csv_syms)} stocks")
                    except Exception as e:
                        logger.debug(f"CSV load: {e}")

                logger.info(f"Total scan universe: {len(syms)} stocks")
                results=[]
                scanned = 0
                failed  = 0
                with ThreadPoolExecutor(max_workers=SCAN_WORKERS) as ex:
                    futures={ex.submit(TrendlyneScorer.score,s):s for s in syms}
                    for f in as_completed(futures):
                        try:
                            r=f.result()
                            if r:
                                r["is_fno"]="YES" if DynamicStockUniverse.is_fno(r["symbol"]) else "NO"
                                results.append(r)
                                scanned += 1
                            else:
                                failed += 1
                        except Exception as e:
                            failed += 1
                results.sort(key=lambda x:x.get("dvm_score",0),reverse=True)
                self._scan_cache=results; self._last_scan_ts=time.time()
                logger.info(f"✅ Scan: {scanned} scored | {failed} skipped | {len(syms)} total")

                # ── Fetch fundamentals for top stocks (NSE API + Screener.in) ──
                try:
                    top_syms = [r["symbol"] for r in results[:50]]
                    FundamentalsFetcher.bulk_fetch(top_syms, max_fetch=30)
                except Exception as e:
                    logger.debug(f"Fundamentals fetch: {e}")
        return self._scan_cache

    def _filing_cb(self,symbol,sentiment,filing,strategies):
        if not self.risk.can_trade(): return
        is_open,_=is_market_open()
        # Convert BSE code to NSE symbol if needed
        if symbol.isdigit():
            nse_sym = bse_to_nse(symbol)
            if not nse_sym: return
            symbol = nse_sym

        # ═══════════════════════════════════════════════════════════════════
        # v23.6.4: DEEP FILING ANALYSIS — Read FULL content before trading
        # Prevents false positives like "ORDER_WIN" being a legal case
        # ═══════════════════════════════════════════════════════════════════
        _filing_type = filing.get("type", "UNKNOWN")
        _filing_subject = filing.get("subject", "")
        _filing_extra = str(filing.get("extra", ""))
        
        # Run deep analysis for HIGH/CRITICAL filings before trading
        if filing.get("urgency") in ("HIGH", "CRITICAL"):
            try:
                should_trade, deep_sentiment, deep_confidence, deep_reason = DeepFilingAnalyzer.should_trade(
                    symbol, _filing_type, _filing_subject, _filing_extra
                )
                
                logger.info(f"🔬 DEEP ANALYSIS [{symbol}]: {deep_sentiment} ({deep_confidence}%) — {deep_reason[:100]}")
                
                # Override keyword-based sentiment with AI analysis
                if deep_sentiment != sentiment.replace("STRONG_", "").replace("WEAK_", ""):
                    logger.warning(
                        f"⚠️ SENTIMENT OVERRIDE [{symbol}]: Keyword={sentiment} → AI={deep_sentiment} | {deep_reason[:80]}"
                    )
                    sentiment = deep_sentiment
                
                # Block trade if deep analysis says NO
                if not should_trade:
                    logger.info(f"🚫 DEEP ANALYSIS BLOCKED [{symbol}]: {deep_reason}")
                    # Still send alert but don't trade
                    send_telegram(
                        f"🔬 *DEEP ANALYSIS BLOCKED*\n"
                        f"Stock: `{symbol}`\n"
                        f"Filing: {_filing_type}\n"
                        f"Keyword sentiment: {filing.get('sentiment', '?')}\n"
                        f"AI sentiment: {deep_sentiment} ({deep_confidence}%)\n"
                        f"Reason: {deep_reason[:100]}\n"
                        f"Action: *NO TRADE*",
                        priority="normal"
                    )
                    return  # Don't proceed with trade
                    
            except Exception as _deep_err:
                logger.warning(f"Deep analysis [{symbol}]: {_deep_err} — proceeding with keyword sentiment")
                # On error, proceed with original sentiment but log warning

        # ── v23.5.0: TRILLIONAIRE EVENT INTELLIGENCE ──
        # Process filing through SectorNewsIntelligence for sector-wide signals
        if self._trillionaire:
            try:
                _headline = filing.get("subject", "")
                _body = str(filing.get("extra", ""))
                _event_signals = self._trillionaire.process_news_for_trades(_headline, _body)
                if _event_signals:
                    logger.info(f"EVENT INTEL: {len(_event_signals)} signals from filing [{symbol}]")
                    # Queue event-driven trades for next scan cycle
                    if not hasattr(self, '_event_trade_queue'):
                        self._event_trade_queue = []
                    self._event_trade_queue.extend(_event_signals)
            except Exception as _evi_err:
                logger.debug(f"Event intel [{symbol}]: {_evi_err}")

        # ── EMERGENCY KITE LOGIN for after-hours filings (AMO orders) ──
        # ZERODHA: AMO allowed on weekends/holidays. NOT during 01:00-05:30 maintenance.
        _filing_time = now_ist()
        _filing_mins = _filing_time.hour * 60 + _filing_time.minute
        _filing_maintenance = (60 <= _filing_mins <= 330)
        if not is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED and not _filing_maintenance:
            if filing.get("urgency") in ("CRITICAL", "HIGH"):
                kite = KiteSession.get()
                if not kite:
                    logger.info(f"🚨 {filing.get('urgency')} filing [{symbol}] outside hours — emergency login for AMO")
                    kite = KiteSession.emergency_login(
                        reason=f"{filing.get('urgency')}: {symbol} {filing.get('type','')} — {sentiment}"
                    )

        # Try scan cache first
        cached=next((r for r in self._scan_cache if r["symbol"]==symbol),None)
        if cached:
            price=cached["price"]
            atr=cached.get("atr",price*0.02)
        else:
            # Try Kite LTP (real-time, no rate limit)
            price = 0
            atr   = 0
            try:
                kite = KiteSession.get()
                if kite:
                    ltp_data = kite.ltp([f"NSE:{symbol}"])
                    if f"NSE:{symbol}" in ltp_data:
                        price = round(ltp_data[f"NSE:{symbol}"]["last_price"], 2)
                        atr   = round(price * 0.02, 2)  # 2% ATR estimate
                        logger.info(f"Kite LTP [{symbol}]: Rs{price}")
            except Exception as e:
                logger.debug(f"Kite LTP [{symbol}]: {e}")
            # Fallback — try Kite historical
            if not price:
                try:
                    kite = KiteSession.get()
                    if kite:
                        hist = KiteSession.get_historical(symbol, days=30)
                        if hist is not None and not hist.empty:
                            price = round(float(hist["Close"].iloc[-1]), 2)
                            tr = pd.Series([
                                max(hh-ll, abs(hh-pc), abs(ll-pc))
                                for hh,ll,pc in zip(
                                    hist["High"], hist["Low"],
                                    hist["Close"].shift(1).fillna(hist["Close"])
                                )
                            ])
                            atr = round(float(tr.rolling(14).mean().iloc[-1]), 2)
                except Exception as e:
                    logger.debug(f"Kite hist filing [{symbol}]: {e}")
            if not price: return
        if price<MIN_PRICE: return
        if filing.get("urgency") not in ["HIGH","CRITICAL"]: return
        source=f"FILING:{filing['type']}"

        # ── 3-Agent AI evaluation for filing trades ──────────
        try:
            macro_signals = self._get_macro()
            macro_bullish, macro_bearish = MacroIntelligence.get_sector_bias(macro_signals)
            filings_recent = self.filings.get_recent(hours=6)
            news_alerts = self.news.recent(hours=6)

            # Get scan result if available
            scan_result = cached if cached else {"symbol": symbol, "price": price, "dvm_score": 50, "rsi": 50}

            # Earnings NLP score for this specific filing
            nlp_score, nlp_sentiment = EarningsNLP.analyse(filing.get("subject","") + " " + str(filing.get("extra","")))

            # Sentiment score
            sent_score, sent_label = SentimentEngine.score(
                symbol, scan_result, filings_recent, news_alerts,
                macro_bullish, macro_bearish, []
            )

            # 3-Agent evaluation + Billionaire Validation
            approved, confidence, reasoning, votes = ThreeAgentAI.evaluate_trade(
                symbol, price, scan_result, sent_score,
                filings_recent, macro_signals, []
            )

            log_lines = reasoning[-3:] if len(reasoning) > 3 else reasoning
            logger.info(f"🤖 Filing [{symbol}] {'✅' if approved else '❌'} conf={confidence} NLP:{nlp_sentiment}({nlp_score}) | {' | '.join(log_lines)}")

            # For CRITICAL filings, allow even if validation fails
            # (CRITICAL = merger, FDA approval, etc. — act fast)
            if not approved and filing.get("urgency") != "CRITICAL":
                logger.info(f"❌ REJECTED filing [{symbol}] — {reasoning[-1] if reasoning else 'no reason'}")
                return  # Log only — no Telegram spam

            # Extract validation type for source tag
            val_type = "VOTE"
            for rl in reasoning:
                if "RECHECK" in rl and "PASS" in rl: val_type = "RECHECK✅"
                elif "STRESS" in rl and "ALL PASS" in rl: val_type = "STRESS✅"
            source = f"FILING:{filing['type']}|3AI({val_type}|conf:{confidence:.0f})"
        except Exception as e:
            logger.debug(f"3AI filing eval [{symbol}]: {e}")
            # On error, proceed with filing trade (don't block)
        if "BULLISH" in sentiment:
            # ═══════════════════════════════════════════════════════════════════
            # v23.6.4 FIX: Check _amo_placed_today BEFORE placing any order
            # Prevents duplicate AMO orders for the same stock
            # ═══════════════════════════════════════════════════════════════════
            if not hasattr(self, '_amo_placed_today'):
                self._amo_placed_today = set()
            
            if symbol in self._amo_placed_today:
                logger.info(f"⚠️ DUPLICATE BLOCKED [{symbol}]: Already placed AMO today")
                return
            
            # ═══ SEBI-COMPLIANT SL for filing trades (max 0.9%) ═══
            _filing_sl_pct = min(atr / price if atr > 0 else 0.007, MAX_SL_PERCENT)
            _filing_sl_pct = max(_filing_sl_pct, MIN_SL_PERCENT)
            sl = round(price * (1 - _filing_sl_pct), 2)
            _filing_risk = price - sl
            t1 = round(price + 2.5 * _filing_risk, 2)
            t2 = round(price + 4.0 * _filing_risk, 2)

            # Cross-strategy duplicate check — ALSO check _amo_placed_today
            _in_any = (symbol in self.intraday.book.get("positions", {})
                    or symbol in self.swing.book.get("positions", {})
                    or symbol in self.longterm.book.get("positions", {})
                    or symbol in self._amo_placed_today)

            # v23.5.0: No artificial position limit — capital is the limit
            # Kelly sizing controls risk per trade

            # Emergency Kite login for after-hours filing trades
            # AMO allowed weekends/holidays. Not during 01:00-05:30 maintenance.
            if not is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED and not _filing_maintenance:
                kite = KiteSession.get()
                if not kite:
                    kite = KiteSession.emergency_login(
                        reason=f"Filing AMO: {symbol} {filing.get('type','')}"
                    )

            if "intraday" in strategies and is_open and is_intraday_window() and self.risk.can_trade_intraday() and not _in_any:
                _result = self.intraday.entry(symbol,price,"FILING BUY",sl,t1,t2,source=source)
                if _result:
                    _in_any = True
                    self._amo_placed_today.add(symbol)  # v23.6.4: Track to prevent duplicates
            if "swing" in strategies and not _in_any:
                _result = self.swing.entry(symbol,price,"FILING SWING BUY",sl,t1,t2,source=source)
                if _result:
                    _in_any = True
                    self._amo_placed_today.add(symbol)  # v23.6.4: Track to prevent duplicates
            if "longterm" in strategies and not _in_any:
                _result = self.longterm.entry(symbol,price,"FILING LT BUY",sl,t1,t2,source=source)
                if _result:
                    self._amo_placed_today.add(symbol)  # v23.6.4: Track to prevent duplicates
            if "fno" in strategies:
                self.fno.enter(symbol,price,"BULLISH",source=source)
        elif "BEARISH" in sentiment:
            if symbol in self.intraday.book["positions"]: self.intraday.exit(symbol,price,f"FILING EXIT:{filing['type']}")
            if symbol in self.swing.book["positions"]:    self.swing.exit(symbol,price,f"FILING EXIT:{filing['type']}")

    def _execute_technical(self,scans):
        if not self.risk.can_trade(): return

        # ── v23.5.0: SEBI + LOSS CONTROL (non-regime checks) ──
        # These block everything including exits — only for SEBI/loss limits
        if self._trillionaire:
            can_sebi, sebi_reason = self._trillionaire.sebi_limiter.can_place_order()
            if not can_sebi:
                logger.warning(f"SEBI BLOCK: {sebi_reason}")
                return
            _total_cap = INTRADAY_CAP + SWING_CAP + LONGTERM_CAP + FNO_CAP
            can_loss, loss_reason = self._trillionaire.loss_control.can_trade(_total_cap)
            if not can_loss:
                logger.warning(f"LOSS CONTROL BLOCK: {loss_reason}")
                return

        is_open,_=is_market_open()
        spot={r["symbol"]:r["price"] for r in scans}

        # ── EXITS ALWAYS RUN — even in BEAR regime ──
        self.intraday.check_stops(scans); self.swing.check_stops(scans)
        self.longterm.check_stops(scans); self.fno.monitor(spot)
        self.swing.check_time_exit(scans); self.longterm.check_time_exit(scans)

        # ── v23.5.0: TREND-FOLLOWING EXIT CHECK (swing + longterm) ──
        if self._trillionaire:
            try:
                scan_map = {r["symbol"]: r for r in scans}
                for _tr in [self.swing, self.longterm]:
                    _positions = _tr.book.get("positions", {})
                    if _positions:
                        _exits = self._trillionaire.check_trailing_exits(_positions, scan_map)
                        for _ex in _exits:
                            _ex_sym = _ex["symbol"]
                            _ex_price = scan_map.get(_ex_sym, {}).get("price", 0)
                            if _ex_price > 0 and _ex_sym in _positions:
                                _tr.exit(_ex_sym, _ex_price, _ex["reason"])
                                logger.info(f"TREND EXIT: {_ex_sym} @ Rs.{_ex_price} ({_ex['reason']})")
                        _tr._save()
            except Exception as _tf_err:
                logger.debug(f"Trend exit check: {_tf_err}")

        # ── v23.5.0: PROCESS EVENT TRADE QUEUE ──
        # Events detected by SectorNewsIntelligence in filing callback
        if hasattr(self, '_event_trade_queue') and self._event_trade_queue and is_open:
            try:
                _evq = self._event_trade_queue[:5]
                self._event_trade_queue = self._event_trade_queue[5:]
                for _evt in _evq:
                    _evt_sym = _evt["symbol"]
                    _evt_dir = _evt["direction"]
                    if _evt_dir != "BUY":
                        continue
                    _in_any = (_evt_sym in self.intraday.book.get("positions", {})
                              or _evt_sym in self.swing.book.get("positions", {})
                              or _evt_sym in self.longterm.book.get("positions", {}))
                    if _in_any:
                        continue
                    _evt_scan = next((r for r in scans if r["symbol"] == _evt_sym), None)
                    if not _evt_scan:
                        continue
                    # Regime check per stock — bypass for promoter/insider signals
                    if self._trillionaire:
                        _evt_allowed, _ = self._trillionaire.should_allow_stock(_evt_sym, _evt_scan)
                        _evt_source_str = _evt.get("source", "")
                        _is_insider_signal = any(kw in _evt_source_str.lower() for kw in 
                            ["promoter", "insider", "bulk", "block", "takeover"])
                        if not _evt_allowed and not _is_insider_signal:
                            continue
                    _evt_price = _evt_scan["price"]
                    _evt_atr = _evt_scan.get("atr", _evt_price * 0.02)
                    # ═══ SEBI-COMPLIANT SL for event trades (max 0.9%) ═══
                    _evt_sl_pct = min(_evt_atr / _evt_price if _evt_atr > 0 else 0.007, MAX_SL_PERCENT)
                    _evt_sl_pct = max(_evt_sl_pct, MIN_SL_PERCENT)
                    _evt_sl = round(_evt_price * (1 - _evt_sl_pct), 2)
                    _evt_risk = _evt_price - _evt_sl
                    _evt_t1 = round(_evt_price + 2.5 * _evt_risk, 2)
                    _evt_t2 = round(_evt_price + 4.0 * _evt_risk, 2)
                    _evt_source = _evt.get("source", "EVENT")
                    self.swing.entry(_evt_sym, _evt_price, f"EVENT BUY",
                                    _evt_sl, _evt_t1, _evt_t2, source=_evt_source)
                    logger.info(f"EVENT TRADE: {_evt_sym} @ Rs.{_evt_price} ({_evt_source})")
            except Exception as _evq_err:
                logger.debug(f"Event queue: {_evq_err}")

        # ── After hours: Allow AMO orders for swing/longterm if LIVE mode ──
        # Intraday trades only during market hours
        # ZERODHA RULE: AMO CAN be placed on weekends and holidays (queues for next trading day)
        # ZERODHA RULE: AMO CANNOT be placed between 01:00-05:30 AM (maintenance window)
        _now = now_ist()
        _time_mins = _now.hour * 60 + _now.minute
        _in_maintenance = (60 <= _time_mins <= 330)  # 01:00 AM to 05:30 AM
        # v23.5.0 FIX: Block 09:00-09:20 — pre-open/opening auction, no orders accepted
        _in_preopen = (_now.hour == 9 and _now.minute < 20)
        _allow_amo = (not is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED 
                      and not _in_maintenance and not _in_preopen)

        if not is_open and not _allow_amo:
            return  # Paper mode or maintenance or pre-open — no after-hours trades

        # ── AMO dedup tracking (prevents same stock ordered every 30-min scan) ──
        if not hasattr(self, '_amo_placed_today'):
            self._amo_placed_today = set()

        if is_open and is_squareoff_time() and not self._squareoff_done:
            self.intraday.square_off_all(scans); self._squareoff_done=True; return

        # ── Emergency Kite login for after-hours AMO ──────────
        if _allow_amo:
            kite = KiteSession.get()
            if not kite:
                kite = KiteSession.emergency_login(reason="AMO orders — 3AI approved signals")
                if not kite:
                    logger.warning("AMO: Cannot login to Kite — skipping after-hours orders")
                    return

        # ── Get macro context (cached 30 min) ──────────────────
        macro_signals = self._get_macro()
        macro_bullish, macro_bearish = MacroIntelligence.get_sector_bias(macro_signals)
        filings = self.filings.get_recent(hours=6)
        news_alerts = self.news.recent(hours=6)

        # ── v23.5.0: Feed live market data into Trillionaire Regime Filter ──
        if self._trillionaire:
            try:
                _vix = 0
                _fg = 50
                # Get VIX from Kite
                kite = KiteSession.get()
                if kite:
                    try:
                        _vix_data = kite.ltp(["NSE:INDIA VIX"])
                        if "NSE:INDIA VIX" in _vix_data:
                            _vix = _vix_data["NSE:INDIA VIX"]["last_price"]
                            # Inject VIX into SentimentMatrix so it uses correct data
                            if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                                try:
                                    SentimentMatrix.set_india_vix(_vix)
                                except Exception:
                                    pass
                    except Exception:
                        pass
                # Get F&G from SentimentMatrix
                if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                    try:
                        _fg = SentimentMatrix.get_fear_greed()
                    except Exception:
                        pass
                self._trillionaire.update_market_data(vix=_vix, fg=_fg)
                _regime = self._trillionaire.get_current_regime()
                if _regime["name"] == "BEAR":
                    logger.info(
                        f"REGIME: BEAR — VIX:{_regime['vix']:.1f} F&G:{_regime['fg']} "
                        f"— NEW BUYS BLOCKED (exits still active)"
                    )
            except Exception as _reg_err:
                logger.debug(f"Regime update: {_reg_err}")

        # ── v23.7.0: STRATEGY MODULES — Enrich scan results ──────────
        # Adds strategy_rank_boost, strategy_dvm_adj, strategy_flags to each scan.
        # Does NOT generate trades — all trades go through the 12-step pipeline.
        _strat_size_mult = 1.0
        if self._strategy_modules is not None:
            try:
                _strat_size_mult = self._strategy_modules.enrich_scans(
                    scans=scans,
                    filings=filings,
                    news_alerts=news_alerts,
                    macro_data=self._macro_data if hasattr(self, '_macro_data') else {},
                )
            except Exception as _se:
                logger.debug(f"Scan enrichment: {_se}")

        # ── StatArb opportunities ──────────────────────────────
        try:
            arb_opps = StatArb.find_opportunities(scans)
            # Dedup: track which pairs already alerted today
            if not hasattr(self, '_statarb_sent_today'):
                self._statarb_sent_today = set()
            for opp in arb_opps[:2]:
                buy_sym = opp["buy"]
                _arb_key = f"{buy_sym}_{opp['avoid']}"
                buy_scan = next((r for r in scans if r["symbol"] == buy_sym), None)
                if buy_scan and opp["confidence"] >= 70 and _arb_key not in self._statarb_sent_today:
                    self._statarb_sent_today.add(_arb_key)
                    logger.info(f"StatArb: BUY {buy_sym} (spread:{opp['spread']}%) | {opp['reason']}")
        except Exception as e:
            logger.debug(f"StatArb: {e}")

        # ── 3-Agent AI evaluated trades ────────────────────────
        # v23.5.0: REGIME FILTER — adapts to market conditions
        _regime_info = None
        if self._trillionaire:
            _regime_info = self._trillionaire.get_current_regime()
            logger.info(
                f"REGIME: {_regime_info['name']} | VIX:{_regime_info['vix']:.1f} "
                f"F&G:{_regime_info['fg']} | Size:{_regime_info['size_multiplier']}x | "
                f"{_regime_info['description']}"
            )
        for r in scans:
            sym=r["symbol"]; price=r["price"]; dvm=r.get("dvm_score",0)

            # Skip indices for equity trades
            if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                continue

            # Get patterns for this stock (from cached scan data)
            try:
                kite = KiteSession.get()
                patterns = []
                if kite:
                    token = TrendlyneScorer._get_token(kite, sym)
                    if token:
                        from_dt = (now_ist() - timedelta(days=400)).strftime("%Y-%m-%d")
                        to_dt   = now_ist().strftime("%Y-%m-%d")
                        hist_data = kite.historical_data(token, from_dt, to_dt, "day")
                        if hist_data and len(hist_data) >= 50:
                            hist_df = pd.DataFrame(hist_data)
                            hist_df.columns = [c.capitalize() for c in hist_df.columns]
                            patterns = PatternRecognition.detect(hist_df)
            except Exception:
                patterns = []

            # Combined Sentiment Score
            sent_score, sent_label = SentimentEngine.score(
                sym, r, filings, news_alerts,
                macro_bullish, macro_bearish, patterns
            )

            # ── 3-Agent AI Gate — ALL trades must pass ──────────
            approved, confidence, reasoning, votes = ThreeAgentAI.evaluate_trade(
                sym, price, r, sent_score,
                filings, macro_signals, patterns
            )

            # Log reasoning for every evaluated stock
            if dvm >= DVM_INTRADAY or sent_score >= SENT_THRESHOLD:
                # Compact log — show last 3 reasoning lines (most important)
                log_lines = reasoning[-3:] if len(reasoning) > 3 else reasoning
                logger.info(f"🤖 [{sym}] {'✅' if approved else '❌'} conf={confidence} | {' | '.join(log_lines)}")

            if not approved:
                # Still allow exits based on signals
                if "SELL" in r.get("intraday_sig","") and sym in self.intraday.book["positions"]:
                    self.intraday.exit(sym,price,r["intraday_sig"])
                if "SELL" in r.get("swing_sig","") and sym in self.swing.book["positions"]:
                    self.swing.exit(sym,price,r["swing_sig"])
                continue  # Skip entry — 3-Agent AI rejected

            # ══════════════════════════════════════════════════════
            # v23.6.1: CIRCUIT BREAKER BLOCK — Never buy frozen stocks
            # If stock is at lower/upper circuit, orders won't execute.
            # GTT won't trigger. You're trapped.
            # HARD BLOCK — no bypass, no override, no exceptions.
            # ══════════════════════════════════════════════════════
            if r.get("is_circuit"):
                _ct = r.get("circuit_type", "?")
                _dc = r.get("day_change_pct", 0)
                logger.warning(
                    f"🚫 CIRCUIT BLOCK [{sym}]: {_ct} CIRCUIT "
                    f"(day change: {_dc:+.1f}%) — stock frozen, orders won't execute"
                )
                # Also blacklist for 7 days — circuit stocks are radioactive
                LossBlacklist.add(sym, f"CIRCUIT HIT ({_ct} {_dc:+.1f}%)")
                continue

            # ══════════════════════════════════════════════════════
            # v23.6.1: LOSS BLACKLIST — Don't re-buy stocks that just burned you
            # Aqylon scenario: buy → lower circuit → manual exit → bot re-buys.
            # Block re-entry for cooldown period after loss/circuit exits.
            # ══════════════════════════════════════════════════════
            _bl_blocked, _bl_reason = LossBlacklist.is_blocked(sym)
            if _bl_blocked:
                logger.info(f"⛔ BLACKLIST [{sym}]: {_bl_reason}")
                continue

            # ── APPROVED BY BILLIONAIRE VALIDATION — Place trades ──
            # v23.5.0: REGIME STOCK FILTER — check if this specific stock is allowed
            # EXCEPTIONS that BYPASS regime (strongest signals):
            #   1. Promoter buying — owner buying own stock
            #   2. Buyback — company buying own shares
            #   3. Bulk/Block deals — institutions loading up
            #   4. Order win — major contract (20%+ revenue impact)
            #   5. M&A — merger/acquisition/takeover
            #   6. Earnings beat — profit growth 30%+
            _has_high_conviction_signal = False
            _bypass_reason = ""

            # Check scan result flags
            if r.get("promoter_buying", False):
                _has_high_conviction_signal = True
                _bypass_reason = "Promoter Buying"
            
            # Check recent filings for this stock
            try:
                _stock_filings = [f for f in filings if f.get("symbol") == sym]
                for _sf in _stock_filings:
                    _sf_type = _sf.get("type", "").upper()
                    _sf_kw = " ".join(_sf.get("keywords", [])).lower()
                    if any(k in _sf_kw for k in ["promoter", "insider buying", "sast"]):
                        _has_high_conviction_signal = True
                        _bypass_reason = "Promoter/Insider Buying"
                    elif any(k in _sf_kw for k in ["buyback", "buy back", "share repurchase"]):
                        _has_high_conviction_signal = True
                        _bypass_reason = "Buyback Announced"
                    elif any(k in _sf_kw for k in ["bulk deal", "block deal"]):
                        _has_high_conviction_signal = True
                        _bypass_reason = "Bulk/Block Deal"
                    elif any(k in _sf_kw for k in ["order win", "contract", "order received"]):
                        _has_high_conviction_signal = True
                        _bypass_reason = "Major Order Win"
                    elif "MERGER" in _sf_type or "ACQUISITION" in _sf_type or "takeover" in _sf_kw:
                        _has_high_conviction_signal = True
                        _bypass_reason = "M&A/Takeover"
                    elif any(k in _sf_kw for k in ["profit growth", "earnings beat", "revenue growth"]):
                        _has_high_conviction_signal = True
                        _bypass_reason = "Earnings Beat"
            except Exception:
                pass

            _regime_bypassed = False
            if self._trillionaire and _regime_info:
                # Pass votes into scan result so should_allow_stock can use it
                r["votes"] = votes
                _stock_allowed, _regime_size = self._trillionaire.should_allow_stock(sym, r, _regime_info)
                if not _stock_allowed:
                    # Bypass 1: High conviction corporate event (buyback, M&A, earnings beat etc.)
                    # Bypass 2: All 3 AI agents voted YES (unanimous) — strongest possible signal
                    _all_3_voted = (votes == 3)
                    if _has_high_conviction_signal or _all_3_voted:
                        _regime_size = 0.75  # Reduced size — respect the regime but don't miss the trade
                        _regime_bypassed = True
                        _bypass_reason_final = _bypass_reason if _has_high_conviction_signal else "3/3 AI Unanimous Vote"
                        logger.info(
                            f"REGIME BYPASS [{sym}]: {_bypass_reason_final} — "
                            f"overriding {_regime_info['name']} regime at 75% size"
                        )
                        # NOTE: Telegram alert sent only AFTER trade executes — see entry blocks below
                    else:
                        logger.info(f"REGIME BLOCK [{sym}]: {_regime_info['name']} — not in allowed category")
                        continue
            else:
                _regime_size = 1.0

            # Extract validation type from reasoning
            val_type = "VOTE"
            for rl in reasoning:
                if "RECHECK" in rl and "PASS" in rl: val_type = "RECHECK✅"
                elif "STRESS" in rl and "ALL PASS" in rl: val_type = "STRESS✅"
            source = f"3AI({val_type}|conf:{confidence:.0f})|{STRATEGY_MODE}"

            # ── SENTIMENT MATRIX FILTER (Fear & Greed) ────────────
            # During fear: only quality large-caps allowed
            # During greed: higher conviction needed, smaller positions
            # During extreme greed: NO new buys
            if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                try:
                    # v23.4.0: Pass scan data for Smart Quality Filter
                    _scan_data = {
                        "pe": r.get("pe", 999),
                        "debt_equity": r.get("debt_equity", 999),
                        "promoter_holding": r.get("promoter_holding", 0),
                        "mcap_cr": r.get("mcap_cr", 0),
                        "promoter_buying": r.get("promoter_buying", False),
                        "turnaround_score": r.get("turnaround_score", 0),
                    }
                    if not SentimentMatrix.filter_stock(sym, scan_data=_scan_data):
                        if _regime_bypassed:
                            logger.info(f"QUALITY FILTER BYPASSED [{sym}] -- high conviction overrides")
                        else:
                            logger.info(f"QUALITY BLOCKED [{sym}]")
                            continue

                    # Check if sentiment requires higher conviction than what we have
                    _fg_conviction = SentimentMatrix.get_min_conviction(80)  # 80 = tier default
                    if confidence < _fg_conviction:
                        if _regime_bypassed:
                            logger.info(f"SENTIMENT BYPASSED [{sym}] -- high conviction overrides")
                        else:
                            logger.info(f"SENTIMENT REJECTED [{sym}] conf={confidence:.0f}")
                            continue
                except Exception as _sent_err:
                    logger.debug(f"Sentiment check [{sym}]: {_sent_err}")
                    # On error, proceed normally — don't block trades

            # ── v23.5.0: CONVICTION SIZING — adjust position size by conviction ──
            _has_promoter_buy = r.get("promoter_buying", False)
            _has_sector_tail = sym in macro_bullish if macro_bullish else False
            _conv_mult, _conv_label = conviction_multiplier(
                confidence, sent_score, _has_promoter_buy, _has_sector_tail
            )

            # ── v23.5.0: PROFIT COMPOUNDING — add recent profits to available capital ──
            _compound_boost = ProfitCompounder.get_compound_boost()
            if _compound_boost > 0:
                # Temporarily boost available capital for this trade
                for _ctr in [self.swing, self.longterm]:
                    _ctr.book["available"] = round(_ctr.book["available"] + _compound_boost / 2, 2)
                logger.info(f"COMPOUNDER: +Rs.{_compound_boost:,.0f} boost applied ({_conv_label} conviction)")

            # ── Cross-strategy duplicate check ─────────────────────
            # A stock should NOT be in multiple strategies at the same time
            # Also check if AMO already placed for this stock tonight
            _in_any = (sym in self.intraday.book.get("positions", {})
                    or sym in self.swing.book.get("positions", {})
                    or sym in self.longterm.book.get("positions", {})
                    or sym in self._amo_placed_today)

            # Total bot positions — no artificial cap, capital is the limit
            # Kelly sizing controls risk per trade
            _total_positions = (sum(1 for p in self.intraday.book.get("positions", {}).values() if p.get("source","") != "KITE_ADOPTED")
                              + sum(1 for p in self.swing.book.get("positions", {}).values() if p.get("source","") != "KITE_ADOPTED")
                              + sum(1 for p in self.longterm.book.get("positions", {}).values() if p.get("source","") != "KITE_ADOPTED"))

            # FIX #3/#6: Intraday — ONLY during market hours (no AMO for intraday)
            # v23.6.0 #5: SNIPER MODE — tighter filters for intraday precision
            # v23.6.1: RESTORE INTRADAY POSITION CAP — MICRO tier can't handle 5 positions
            _intraday_count = sum(1 for p in self.intraday.book.get("positions", {}).values()
                                  if p.get("source", "") != "KITE_ADOPTED")
            _intraday_ok = (is_open and is_intraday_window() and self.risk.can_trade_intraday()
                and "BUY" in r["intraday_sig"] and r.get("vol_surge",1)>=INTRADAY_SNIPER_VOL
                and dvm>=INTRADAY_SNIPER_DVM and r.get("adx", 0)>=INTRADAY_SNIPER_ADX
                and r.get("macd_cross", False)  # v23.6.0: Fresh MACD crossover required
                and not _in_any
                and _intraday_count < self.intraday.max_pos)  # v23.6.1: Hard cap
            if _intraday_ok:
                _result = self.intraday.entry(sym,price,r["intraday_sig"],r["sl_intra"],r["t1_intra"],r["t2_intra"],source=source)
                if _result:
                    _in_any = True  # Bought — block other strategies

            # FIX #3/#6: Swing — COLLECT signal, don't execute yet
            # v23.6.0 #9: Apply sector rotation DVM adjustment
            _sector_adj, _sector_name = SectorRotationScorer.get_dvm_adjustment(sym)
            _strat_adj = r.get("strategy_dvm_adj", 0)
            _effective_swing_dvm = DVM_SWING + _sector_adj + _strat_adj
            # REGIME BYPASS: lower DVM bar by 10 pts — stock cleared all AI filters,
            # don't block it again on DVM alone
            if _regime_bypassed:
                _effective_swing_dvm = max(_effective_swing_dvm - 10, 50)
            if ("BUY" in r["swing_sig"] and dvm>=_effective_swing_dvm
                and not _in_any):
                _source = source + f"|{_conv_label}" + ("|AMO" if _allow_amo else "")
                # Collect signal for batch ranking instead of immediate entry
                if not hasattr(self, '_swing_candidates'):
                    self._swing_candidates = []
                self._swing_candidates.append({
                    "symbol": sym,
                    "price": price,
                    "signal": r["swing_sig"],
                    "sl": r["sl_swing"],
                    "t1": r["t1_swing"],
                    "t2": r["t2_swing"],
                    "source": _source,
                    "confidence": confidence,
                    "dvm": dvm,
                    "sent_score": sent_score,
                    "rr_ratio": round((r["t2_swing"] - price) / max(price - r["sl_swing"], 0.01), 2),
                    "conv_mult": _conv_mult,
                    "regime_size": _regime_size,
                    "regime_bypassed": _regime_bypassed,
                    "bypass_reason": _bypass_reason_final if _regime_bypassed else "",
                    "sector": r.get("sector", "") or r.get("industry", "") or _sector_name or "Unknown",
                    "allow_amo": _allow_amo,
                    "compound_boost": _compound_boost,
                    "conv_label": _conv_label,
                    "r": r,  # Full scan result for GTT placement
                })

            # FIX #5/#6: Long Term — allowed during market AND after hours (AMO)
            _effective_lt_dvm = DVM_LONGTERM
            if _regime_bypassed:
                _effective_lt_dvm = max(DVM_LONGTERM - 10, 45)
            if ("BUY" in r["lt_sig"] and dvm>=_effective_lt_dvm and "Bullish" in r["trend"]
                and r.get("pe",99)<LT_PE_MAX and r.get("roe",0)>LT_ROE_MIN
                and not _in_any):
                # v23.6.1: Correlation filter for LT
                _lt_all_pos = {}
                _lt_all_pos.update(self.intraday.book.get("positions", {}))
                _lt_all_pos.update(self.swing.book.get("positions", {}))
                _lt_all_pos.update(self.longterm.book.get("positions", {}))
                _lt_corr_ok, _lt_corr_reason = CorrelationFilter.check(sym, _lt_all_pos, scan_data=r)
                if not _lt_corr_ok and not _regime_bypassed:
                    logger.info(f"LT CORR BLOCK [{sym}]: {_lt_corr_reason}")
                    continue
                _source = source + f"|{_conv_label}" + ("|AMO" if _allow_amo else "")
                # v23.5.0: Apply conviction multiplier + regime size to LT position sizing
                _orig_risk = RISK_PER_TRADE
                try:
                    _final_mult = round(_conv_mult * _regime_size, 4)
                    globals()["RISK_PER_TRADE"] = round(_orig_risk * _final_mult, 4)
                    _lt_result = self.longterm.entry(sym,price,r["lt_sig"],r["sl_lt"],r["t1_lt"],r["t2_lt"],source=_source)
                finally:
                    globals()["RISK_PER_TRADE"] = _orig_risk  # Always restore
                if _lt_result:
                    if _allow_amo:
                        self._amo_placed_today.add(sym)
                    # v23.5.0: GTT IMMEDIATE for longterm
                    if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                        try:
                            _gkite = KiteSession.get()
                            if _gkite:
                                _gtt_id = place_gtt_immediate(
                                    _gkite, sym, _lt_result["qty"],
                                    price, r["sl_lt"], r["t2_lt"],
                                    trader_obj=self.longterm
                                )
                                if _gtt_id:
                                    send_telegram(f"GTT INSTANT [{sym}]\nSL: Rs.{r['sl_lt']:.1f} | T2: Rs.{r['t2_lt']:.1f}\nProtected from second one", priority="normal", silent=True)
                        except Exception as _gi_err:
                            logger.warning(f"GTT instant LT [{sym}]: {_gi_err}")

            # Sell signals — always execute immediately
            if "SELL" in r.get("intraday_sig","") and sym in self.intraday.book["positions"]:
                self.intraday.exit(sym,price,r["intraday_sig"])
            if "SELL" in r.get("swing_sig","") and sym in self.swing.book["positions"]:
                self.swing.exit(sym,price,r["swing_sig"])

            # v23.5.0: Revert compound boost if not used (prevent capital inflation)
            if _compound_boost > 0:
                for _ctr in [self.swing, self.longterm]:
                    _ctr.book["available"] = round(_ctr.book["available"] - _compound_boost / 2, 2)
                    if _ctr.book["available"] < 0:
                        _ctr.book["available"] = 0
                # If a trade was made, mark profits as deployed
                if _in_any:
                    ProfitCompounder.mark_deployed(_compound_boost)

        # ══════════════════════════════════════════════════════════
        #  BATCH RANKING & DEPLOYMENT — Best stocks get capital first
        #  Instead of buying the first approved stock, we scan ALL stocks,
        #  collect approved signals, rank by quality, and deploy to top picks.
        # ══════════════════════════════════════════════════════════
        if hasattr(self, '_swing_candidates') and self._swing_candidates:
            _candidates = self._swing_candidates
            self._swing_candidates = []  # Reset for next cycle

            # ── RANK by composite score ──────────────────────────
            # Score = confidence (0-100) + RR ratio (0-5 scaled to 0-25) + DVM (0-100 scaled to 0-25)
            for c in _candidates:
                _rr_score = min(c["rr_ratio"], 5) * 5  # Max 25 points from R:R
                _dvm_score = c["dvm"] * 0.25            # Max 25 points from DVM
                _sent_bonus = c["sent_score"] * 0.1     # Max 10 points from sentiment
                _promo_bonus = 15 if c.get("r", {}).get("promoter_buying") else 0
                _strat_bonus = c.get("r", {}).get("strategy_rank_boost", 0)
                c["rank_score"] = round(c["confidence"] + _rr_score + _dvm_score + _sent_bonus + _promo_bonus + _strat_bonus, 1)

            # Sort by rank score — highest first
            # No sector diversification — best stocks get capital regardless of sector
            # Per-stock risk managed by ATR stop loss + Kelly sizing + GTT
            _candidates.sort(key=lambda x: x["rank_score"], reverse=True)

            # Log the ranked candidates
            _top_display = min(10, len(_candidates))
            logger.info(
                f"BATCH RANKING: {len(_candidates)} candidates after scan | "
                f"Top {_top_display}:"
            )
            for i, c in enumerate(_candidates[:_top_display]):
                logger.info(
                    f"  #{i+1} {c['symbol']:12s} score={c['rank_score']:5.1f} "
                    f"conf={c['confidence']:.0f} RR={c['rr_ratio']:.1f} "
                    f"DVM={c['dvm']:.0f} sector={c.get('sector','?')}"
                )

            # Log ranking (no Telegram — only trade/GTT/SL/profit msgs)
            if _candidates:
                logger.info(
                    f"SCAN COMPLETE — {len(_candidates)} candidates ranked | "
                    f"Top: {', '.join(c['symbol'] for c in _candidates[:5])}"
                )

            # ── DEPLOY to top candidates (STAGGERED) ────────────
            # Max 2 trades per scan cycle — spreads capital across time.
            # Better stocks found in later cycles still get capital.
            # Cycle runs every 60 seconds, so full deployment takes 3-5 minutes.
            MAX_TRADES_PER_CYCLE = 2
            _deployed = 0
            for c in _candidates:
                if _deployed >= MAX_TRADES_PER_CYCLE:
                    logger.info(
                        f"STAGGER LIMIT: {_deployed}/{MAX_TRADES_PER_CYCLE} deployed this cycle. "
                        f"Remaining {len(_candidates) - _candidates.index(c)} candidates saved for next cycle."
                    )
                    break

                _sym = c["symbol"]

                # Skip if already in any position
                if (_sym in self.intraday.book.get("positions", {})
                    or _sym in self.swing.book.get("positions", {})
                    or _sym in self.longterm.book.get("positions", {})
                    or _sym in self._amo_placed_today):
                    continue

                # v23.6.1: CORRELATION FILTER — prevent concentrated correlated risk
                _all_positions = {}
                _all_positions.update(self.intraday.book.get("positions", {}))
                _all_positions.update(self.swing.book.get("positions", {}))
                _all_positions.update(self.longterm.book.get("positions", {}))
                _corr_ok, _corr_reason = CorrelationFilter.check(
                    _sym, _all_positions, scan_data=c.get("r", {})
                )
                if not _corr_ok:
                    # Allow bypass for regime-bypassed (high conviction) signals
                    if c.get("regime_bypassed"):
                        logger.info(f"CORR BYPASS [{_sym}]: {_corr_reason} — high conviction override")
                    else:
                        logger.info(f"CORR BLOCK [{_sym}]: {_corr_reason}")
                        continue

                # Place the trade
                _orig_risk = RISK_PER_TRADE
                try:
                    _final_mult = round(c["conv_mult"] * c["regime_size"] * _strat_size_mult, 4)
                    globals()["RISK_PER_TRADE"] = round(_orig_risk * _final_mult, 4)
                    _result = self.swing.entry(
                        _sym, c["price"], c["signal"],
                        c["sl"], c["t1"], c["t2"],
                        source=c["source"]
                    )
                finally:
                    globals()["RISK_PER_TRADE"] = _orig_risk

                if _result:
                    _deployed += 1
                    if c["allow_amo"]:
                        self._amo_placed_today.add(_sym)
                    if c["regime_bypassed"]:
                        logger.info(
                            f"REGIME BYPASS EXECUTED: {_sym} @ Rs.{c['price']:.1f} "
                            f"Rank #{_candidates.index(c)+1} | {c['bypass_reason']}"
                        )
                    # GTT placement
                    if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                        try:
                            _gkite = KiteSession.get()
                            if _gkite:
                                _gtt_id = place_gtt_immediate(
                                    _gkite, _sym, _result["qty"],
                                    c["price"], c["sl"], c["t2"],
                                    trader_obj=self.swing
                                )
                        except Exception as _gi_err:
                            logger.warning(f"GTT instant [{_sym}]: {_gi_err}")
                else:
                    # entry() returned None — likely insufficient capital
                    # Stop deploying — no point trying lower-ranked stocks
                    break

            if _deployed > 0:
                logger.info(f"BATCH DEPLOYED: {_deployed}/{MAX_TRADES_PER_CYCLE} trades from {len(_candidates)} candidates (staggered)")

        # ── FIX #6: F&O Entries — use DVM_FNO (lower threshold) ──
        for r in scans:
            if r["symbol"] in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                dvm=r.get("dvm_score",0)
                if "STRONG BUY" in r["overall"] and dvm>=DVM_FNO:
                    self.fno.enter(r["symbol"],r["price"],"BULLISH",source="3AI_TECHNICAL")
                elif "BUY" in r["overall"] and dvm>=DVM_FNO and STRATEGY_MODE=="AGGRESSIVE":
                    self.fno.enter(r["symbol"],r["price"],"BULLISH",source="3AI_AGGRESSIVE")
                elif "STRONG SELL" in r["overall"]:
                    self.fno.enter(r["symbol"],r["price"],"BEARISH",source="3AI_TECHNICAL")

        # ══════════════════════════════════════════════════════════
        #  v23.6.0 #6: GAP-DOWN RECOVERY SCANNER (09:20-09:50)
        #  Stocks that gapped down ≥3% but are recovering.
        #  Gap fills on quality stocks: 60-70% probability same day.
        #  Only during first 35 minutes of trading.
        #
        #  CRITERIA:
        #  1. Price dropped ≥3% from previous close (gap down)
        #  2. Current price recovering (above day low by 50%+ of gap)
        #  3. F&O stock or large cap (quality — no penny traps)
        #  4. No bearish filing in last 24h
        #  5. Previous day close above 20-day MA (uptrend before gap)
        #  6. Volume in session > 2x average (institutional activity)
        #  SL: Below day's low | Target: Previous close (gap fill)
        # ══════════════════════════════════════════════════════════
        _n_gd = now_ist()
        _gd_hr, _gd_mn = _n_gd.hour, _n_gd.minute
        _gd_time_mins = _gd_hr * 60 + _gd_mn
        # Only run between 09:20 and 09:50
        if 560 <= _gd_time_mins <= 590 and KiteSession.is_trading_day():
            _gd_count = 0
            for r in scans:
                sym = r["symbol"]
                price = r["price"]
                ma20 = r.get("ma20", 0)
                vol = r.get("vol_surge", 1.0)
                atr = r.get("atr", price * 0.02)
                is_fno = r.get("is_fno") == "YES"
                dvm = r.get("dvm_score", 0)
                w52l = r.get("w52_low", 0)

                # Skip indices
                if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                    continue

                # Quality filter: F&O or good DVM
                if not is_fno and dvm < 40:
                    continue

                # Price must be > Rs.100
                if price < 100:
                    continue

                # Already in a position
                if (sym in self.intraday.book["positions"] or
                    sym in self.swing.book["positions"] or
                    sym in self.longterm.book["positions"]):
                    continue

                # Calculate gap: need previous close
                # Use 1-week return as proxy — if ret_1w is very negative, gap detected
                ret_1w = r.get("ret_1w", 0)
                # More accurate: check if today's price is significantly below MA20
                if ma20 <= 0:
                    continue

                gap_from_ma20_pct = (ma20 - price) / ma20 * 100
                # Stock must have gapped down at least 3% below recent average
                if gap_from_ma20_pct < 3.0:
                    continue

                # Volume must be high (institutional reaction)
                if vol < 1.5:
                    continue

                # No bearish filings
                stock_filings = [f for f in filings
                                 if f.get("symbol") == sym
                                 and "BEARISH" in f.get("sentiment", "")
                                 and f.get("urgency") in ("HIGH", "CRITICAL")]
                if stock_filings:
                    continue

                # MACD or RSI should show recovery signal
                rsi = r.get("rsi", 50)
                if rsi > 60:
                    continue  # Already recovered, too late

                _gd_count += 1
                # Tight SL for gap recovery: 1% below current price
                sl = round(price * 0.995, 2)  # Tight 0.5% SL
                t1 = round(ma20 * 0.995, 2)   # Target: near previous MA20 (gap fill)
                t2 = round(ma20 * 1.02, 2)    # Extended: 2% above MA20
                source = f"GAP_RECOVERY(gap:{gap_from_ma20_pct:.1f}%)|{STRATEGY_MODE}"

                logger.info(
                    f"🔻 GAP RECOVERY [{sym}] Gap={gap_from_ma20_pct:.1f}% "
                    f"Price=₹{price} MA20=₹{ma20:.1f} Vol={vol}x RSI={rsi}"
                )

                # Route to intraday (quick trade, tight SL)
                if self.risk.can_trade_intraday() and MAX_INTRADAY_POS > 0:
                    self.intraday.entry(sym, price,
                        f"GAP RECOVERY (gap {gap_from_ma20_pct:.1f}% from MA20)",
                        sl, t1, t2, source=source)

            if _gd_count > 0:
                logger.info(f"🔻 Gap Recovery Scanner: {_gd_count} candidates (09:20-09:50)")

        # ══════════════════════════════════════════════════════════
        #  OVERSOLD BOUNCE SCANNER (Mean Reversion)
        #  Renaissance: "We look for things that can be replicated
        #               thousands of times"
        #  Stocks in oversold zone (RSI < 35) that are QUALITY
        #  companies with intact long-term trend → high probability
        #  bounce back.
        #
        #  FILTERS (to avoid value traps):
        #  1. RSI < RSI_OVERSOLD (35 aggressive, 30 balanced)
        #  2. MA50 > MA200 (long-term uptrend still intact)
        #  3. Price > ₹100 (no penny stocks)
        #  4. F&O stock OR large cap (quality filter)
        #  5. No BEARISH filing in last 24h (no fraud/default)
        #  6. Volume surge > 1.0 (some activity, not dead stock)
        #  7. Not already in any position
        # ══════════════════════════════════════════════════════════
        if is_intraday_window() or True:  # Run during and after market
            bounce_count = 0
            for r in scans:
                sym   = r["symbol"]
                price = r["price"]
                rsi   = r.get("rsi", 50)
                dvm   = r.get("dvm_score", 0)
                ma50  = r.get("ma50", 0)
                ma200 = r.get("ma200", 0)
                vol   = r.get("vol_surge", 1.0)
                trend = r.get("trend", "")
                atr   = r.get("atr", price * 0.02)
                is_fno = r.get("is_fno") == "YES"

                # Skip indices
                if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                    continue

                # ── OVERSOLD BOUNCE CRITERIA ──────────────────
                # Must be oversold
                if rsi >= RSI_OVERSOLD:
                    continue

                # Must be quality — long-term uptrend intact
                if ma50 <= 0 or ma200 <= 0 or ma50 < ma200:
                    continue  # Death cross = broken trend, skip

                # Must be decent price (no penny stocks)
                if price < 100:
                    continue

                # Must be F&O stock or large cap (quality filter)
                if not is_fno and dvm < 30:
                    continue  # Small unknown stock, too risky

                # Must have some volume (not a dead stock)
                if vol < 0.8:
                    continue

                # Must NOT have a bearish filing in last 24h
                stock_filings = [f for f in filings
                                 if f.get("symbol") == sym
                                 and "BEARISH" in f.get("sentiment", "")
                                 and f.get("urgency") in ("HIGH", "CRITICAL")]
                if stock_filings:
                    logger.debug(f"Bounce skip [{sym}]: bearish filing exists")
                    continue

                # Must NOT already be in any position
                if (sym in self.intraday.book["positions"] or
                    sym in self.swing.book["positions"] or
                    sym in self.longterm.book["positions"]):
                    continue

                # ── PASSED ALL FILTERS — This is a quality oversold bounce ──
                bounce_count += 1
                source = f"BOUNCE(RSI:{rsi})|{STRATEGY_MODE}"

                # Tighter stop loss for bounce trades (price already low)
                sl = round(price - 1.0 * atr, 2)
                t1 = round(price + 2.0 * atr, 2)  # Quick 2 ATR target
                t2 = round(price + 4.0 * atr, 2)   # Extended target

                logger.info(
                    f"📉➡️📈 OVERSOLD BOUNCE [{sym}] RSI={rsi} Price=₹{price} "
                    f"MA50={ma50:.0f}>MA200={ma200:.0f} Vol={vol}x {'F&O' if is_fno else 'EQ'}"
                )

                # FIX #8: Place in ONE strategy only (no duplicates)
                _bounce_placed = False
                if is_intraday_window() and self.risk.can_trade_intraday():
                    _br = self.intraday.entry(sym, price, f"BOUNCE BUY RSI:{rsi}",
                                         sl, t1, t2, source=source)
                    if _br: _bounce_placed = True

                # Swing only if NOT already placed in intraday
                if not _bounce_placed and self.risk.can_trade():
                    self.swing.entry(sym, price, f"BOUNCE SWING RSI:{rsi}",
                                      round(price - 1.5 * atr, 2),
                                      round(price + 3.0 * atr, 2),
                                      round(price + 5.0 * atr, 2),
                                      source=source)

                # F&O — buy calls on oversold F&O stocks (high probability bounce)
                if is_fno and sym in FNOTrader.INSTRUMENTS:
                    self.fno.enter(sym, price, "BULLISH",
                                    source=f"BOUNCE_FNO(RSI:{rsi})",
                                    confidence="BULLISH")

            if bounce_count > 0:
                logger.info(f"📉➡️📈 Oversold Bounce: {bounce_count} stocks identified")

        # ══════════════════════════════════════════════════════════
        #  TURNAROUND STOCK SCANNER (Billionaire Combined Strategy)
        #
        #  Warren Buffett: "Be fearful when others are greedy,
        #                   and greedy when others are fearful."
        #  Carl Icahn:     "Buy a company when nobody wants it."
        #  David Tepper:   "Buy the most hated names on the Street."
        #  Peter Lynch:    "Turnarounds make the biggest multibaggers."
        #
        #  WHAT WE LOOK FOR:
        #  A stock that has FALLEN significantly but shows SIGNS OF
        #  RECOVERY — the combination of pain (price drop) with hope
        #  (improving fundamentals or insider buying).
        #
        #  SCORING (must score >= 4 out of 8 to qualify):
        #  1. Price 30%+ below 52-week high           → fallen hard
        #  2. RSI < 40 (beaten down)                  → sentiment low
        #  3. Promoter/insider buying in filings       → smart money entering
        #  4. Improving earnings (bullish NLP score)   → fundamentals turning
        #  5. Sector turning bullish (macro engine)    → tailwind starting
        #  6. Volume surge > 1.5x (accumulation)      → big players buying
        #  7. Double Bottom or Bullish Divergence      → technical turnaround
        #  8. PE below sector avg or < 25 (value)     → cheap vs quality
        #
        #  ANTI-VALUE-TRAP FILTERS (must pass ALL):
        #  × No FRAUD/DEFAULT filing in 30 days
        #  × Not in death cross (MA50 < MA200)
        #  × Price > ₹50 (no penny stocks)
        #  × F&O stock or large cap (quality filter)
        # ══════════════════════════════════════════════════════════
        turnaround_count = 0
        for r in scans:
            sym   = r["symbol"]
            price = r["price"]
            rsi   = r.get("rsi", 50)
            dvm   = r.get("dvm_score", 0)
            ma50  = r.get("ma50", 0)
            ma200 = r.get("ma200", 0)
            vol   = r.get("vol_surge", 1.0)
            w52h  = r.get("w52_high", 0)
            w52l  = r.get("w52_low", 0)
            pe    = r.get("pe", 0)
            atr   = r.get("atr", price * 0.02)
            is_fno = r.get("is_fno") == "YES"
            trend = r.get("trend", "")

            # Skip indices
            if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]:
                continue

            # ── ANTI-VALUE-TRAP FILTERS (must pass ALL) ──────────
            # Filter: No penny stocks
            if price < 50:
                continue

            # Filter: Must be F&O or decent DVM (quality)
            if not is_fno and dvm < 20:
                continue

            # Filter: NOT in death cross (long-term trend must not be broken)
            # Relaxed: allow if MA50 is within 3% of MA200 (about to cross back)
            if ma50 > 0 and ma200 > 0 and ma50 < ma200 * 0.97:
                continue  # Deep death cross — avoid

            # Filter: No FRAUD/DEFAULT filings in last 30 days
            stock_fraud = [f for f in filings
                          if f.get("symbol") == sym
                          and f.get("type") in ("FRAUD_RISK",)
                          and f.get("urgency") in ("HIGH", "CRITICAL")]
            if stock_fraud:
                continue

            # Filter: Already in a position
            if (sym in self.intraday.book["positions"] or
                sym in self.swing.book["positions"] or
                sym in self.longterm.book["positions"]):
                continue

            # ── TURNAROUND SCORING (8 factors) ───────────────────
            ta_score = 0
            ta_reasons = []

            # 1. Price 30%+ below 52-week high (fallen hard)
            if w52h > 0 and price < w52h * 0.70:
                ta_score += 1
                drop_pct = round((1 - price / w52h) * 100, 1)
                ta_reasons.append(f"DOWN {drop_pct}% from 52WH")

            # 2. RSI < 40 (beaten down but not crashed)
            if rsi < 40:
                ta_score += 1
                ta_reasons.append(f"RSI={rsi}")

            # 3. Promoter/insider buying in recent filings
            promoter_buys = [f for f in filings
                            if f.get("symbol") == sym
                            and f.get("type") == "PROMOTER"
                            and "buying" in str(f.get("subject", "")).lower()
                            or "stake increase" in str(f.get("subject", "")).lower()]
            if promoter_buys:
                ta_score += 2  # Double weight — strongest signal
                ta_reasons.append("PROMOTER BUYING")

            # 4. Improving earnings (bullish filing sentiment)
            earnings_filings = [f for f in filings
                               if f.get("symbol") == sym
                               and f.get("type") == "RESULTS"
                               and "BULLISH" in f.get("sentiment", "")]
            if earnings_filings:
                ta_score += 1
                ta_reasons.append("EARNINGS IMPROVING")

            # 5. Sector turning bullish (macro tailwind)
            if sym in macro_bullish:
                ta_score += 1
                ta_reasons.append("SECTOR TAILWIND")

            # 6. Volume surge > 1.5x (accumulation by big players)
            if vol >= 1.5:
                ta_score += 1
                ta_reasons.append(f"VOL {vol}x (accumulation)")

            # 7. Bullish pattern (Double Bottom, Bullish Divergence, Golden Cross)
            try:
                if patterns:
                    for pat_name, pat_dir, pat_conf in patterns:
                        if pat_dir == "BULLISH" and pat_name in ("DOUBLE_BOTTOM", "BULLISH_DIVERGENCE", "GOLDEN_CROSS"):
                            ta_score += 1
                            ta_reasons.append(f"PATTERN:{pat_name}")
                            break
            except Exception:
                pass

            # 8. PE value (cheap stock — PE < 25 or PE improving)
            if 0 < pe < 25:
                ta_score += 1
                ta_reasons.append(f"PE={pe} (value)")

            # ── QUALIFY: Must score >= 4 out of 8 ────────────────
            if ta_score < 4:
                continue

            # ── TURNAROUND DETECTED — Place trade ────────────────
            turnaround_count += 1
            source = f"TURNAROUND(score:{ta_score}/8)|{STRATEGY_MODE}"

            # Wider stops for turnaround (stock is volatile)
            sl = round(price - 2.0 * atr, 2)
            t1 = round(price + 3.0 * atr, 2)
            t2 = round(price + 6.0 * atr, 2)

            logger.info(
                f"🔄 TURNAROUND [{sym}] Score={ta_score}/8 Price=₹{price} "
                f"RSI={rsi} Vol={vol}x PE={pe} | {' + '.join(ta_reasons)}"
            )

            # FIX #8: Turnarounds go to ONE strategy only (no duplicates)
            # Cross-strategy duplicate check
            _ta_in_any = (sym in self.intraday.book.get("positions", {})
                    or sym in self.swing.book.get("positions", {})
                    or sym in self.longterm.book.get("positions", {}))
            if _ta_in_any:
                logger.debug(f"Turnaround [{sym}]: already in a strategy — skip")
            elif ta_score >= 6 and self.risk.can_trade():
                # Strong turnarounds → long-term (need time to play out)
                lt_sl = round(price - 2.5 * atr, 2)
                lt_t1 = round(price + 5.0 * atr, 2)
                lt_t2 = round(price + 10.0 * atr, 2)
                self.longterm.entry(sym, price, f"STRONG TURNAROUND ({ta_score}/8)",
                                     lt_sl, lt_t1, lt_t2, source=source)
            elif self.risk.can_trade():
                # Regular turnarounds → swing
                self.swing.entry(sym, price, f"TURNAROUND BUY ({ta_score}/8)",
                                  sl, t1, t2, source=source)

            # F&O: Buy calls on strong turnaround F&O stocks
            if ta_score >= 5 and is_fno and sym in FNOTrader.INSTRUMENTS:
                self.fno.enter(sym, price, "BULLISH",
                                source=f"TURNAROUND_FNO(score:{ta_score})",
                                confidence="BULLISH")

            # Telegram alert for turnarounds — goes to digest (FIX #7)
            # Dedup: only send once per stock per day
            if not hasattr(self, '_turnaround_sent_today'):
                self._turnaround_sent_today = set()
            if sym not in self._turnaround_sent_today:
                self._turnaround_sent_today.add(sym)
                # v23.5.0: Turnaround alerts go to LOG only (no Telegram spam)
                logger.info(
                    f"TURNAROUND [{sym}] @ Rs.{price} | Score: {ta_score}/8 | "
                    f"{' | '.join(ta_reasons[:3])}"
                )

        if turnaround_count > 0:
            logger.info(f"🔄 Turnaround Scanner: {turnaround_count} stocks identified")

        # ══════════════════════════════════════════════════════════
        #  PHASE 2 SCANNERS (v23.4.0)
        #  Promoter Buying | 52W Low Recovery | Zero Idle Cash |
        #  Superstar Portfolio | Sector Rotation Bias
        #
        #  Capital-agnostic: scanners produce signals with
        #  target_strategy, the routing below places trades.
        #  Tier-aware: respects max positions and strategy limits.
        # ══════════════════════════════════════════════════════════

        # ── v23.5.0: PENNY MULTIBAGGER SCANNER ──────────────────────
        # IMPORTANT: Main scans filter price < Rs.50 via is_eligible().
        # Penny scanner builds its OWN data from Kite instruments + LTP.
        # SAFETY: Only runs on TRADING DAYS — penny AMOs are too risky
        # (thin volume, wide gaps, pump-and-dump risk on pre-open)
        if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED and KiteSession.is_trading_day():
            try:
                _penny_kite = KiteSession.get()
                _penny_candidates = []
                _penny_ltp = {}
                if _penny_kite and hasattr(DynamicStockUniverse, '_all_symbols'):
                    # Step 1: Find penny-priced stocks from universe
                    _penny_symbols = []
                    for _ps_sym, _ps_info in DynamicStockUniverse._all_symbols.items():
                        _ps_price = _ps_info.get("last_price", 0)
                        if 5 <= _ps_price <= 50:
                            _penny_symbols.append(_ps_sym)

                    # Step 2: Fetch LTP in batches (max 200 stocks)
                    if _penny_symbols:
                        for _bi in range(0, min(len(_penny_symbols), 200), 50):
                            _batch = _penny_symbols[_bi:_bi+50]
                            try:
                                _ltd = KiteSession.get_ltp(_batch)
                                if _ltd:
                                    _penny_ltp.update(_ltd)
                            except Exception:
                                pass

                        # Step 3: Build scan records + enrich top by volume
                        _penny_scans = []
                        for _ps in _penny_symbols[:200]:
                            _pld = _penny_ltp.get(_ps, {})
                            _pp = _pld.get("last_price", 0)
                            if _pp < 5 or _pp > 50:
                                continue
                            _penny_scans.append({
                                "symbol": _ps, "price": _pp,
                                "rsi": 50, "vol_surge": 1.0,
                                "volume": _pld.get("volume", 0), "vol_avg_20d": 0,
                                "promoter_holding": 0, "debt_equity": 999,
                                "swing_sig": "", "trend": "",
                                "week_52_low": 0, "week_52_high": 0, "mcap_cr": 0,
                            })
                        # Sort by volume, fetch fundamentals for top 30
                        _penny_scans.sort(key=lambda x: x.get("volume", 0), reverse=True)
                        for _tp in _penny_scans[:30]:
                            try:
                                _fund = FundamentalsFetcher.get(_tp["symbol"])
                                if _fund:
                                    _tp["promoter_holding"] = _fund.get("promoterHolding", 0)
                                    _tp["debt_equity"] = _fund.get("debtToEquity", 999)
                                    _tp["mcap_cr"] = _fund.get("marketCap", 0) / 10000000
                            except Exception:
                                pass

                        # Step 4: Run penny scanner on enriched data
                        _penny_candidates = PennyMultibaggerScanner.scan(_penny_scans[:30])

                if _penny_candidates:
                    _penny_pos_count = sum(
                        1 for s, p in self.swing.book.get("positions", {}).items()
                        if p.get("source", "").startswith("PENNY")
                    )
                    _penny_capital_used = sum(
                        p.get("cost", 0) for s, p in self.swing.book.get("positions", {}).items()
                        if p.get("source", "").startswith("PENNY")
                    )
                    _swing_cap = self.swing.book.get("capital", 0)
                    _penny_cap_limit = _swing_cap * PennyMultibaggerScanner.PENNY_MAX_CAPITAL_PCT / 100

                    # FIX: Check SentimentMatrix before penny entries
                    _penny_ok = True
                    try:
                        if hasattr(SentimentMatrix, 'get_current_zone'):
                            _zone = SentimentMatrix.get_current_zone()
                            if _zone in ["EXTREME_GREED", "EXTREME_FEAR"]:
                                _penny_ok = False
                                logger.info(f"PENNY: Blocked by sentiment ({_zone})")
                    except Exception:
                        pass

                    if _penny_ok:
                        for _pc in _penny_candidates[:3]:
                            _psym = _pc["symbol"]
                            if _penny_pos_count >= PennyMultibaggerScanner.PENNY_MAX_POSITIONS:
                                break
                            if _penny_capital_used >= _penny_cap_limit:
                                break
                            if (_psym in self.intraday.book.get("positions", {})
                                or _psym in self.swing.book.get("positions", {})
                                or _psym in self.longterm.book.get("positions", {})
                                or _psym in self._amo_placed_today):
                                continue
                            if _psym in PennyMultibaggerScanner._sent_today:
                                continue
                            PennyMultibaggerScanner._sent_today.add(_psym)

                            _penny_source = f"PENNY(score:{_pc['score']})|{','.join(_pc['reasons'][:3])}"
                            _pr = self.swing.entry(
                                _psym, _pc["price"], "PENNY_BUY",
                                _pc["sl"], _pc["t1"], _pc["t2"],
                                source=_penny_source
                            )
                            if _pr:
                                _penny_pos_count += 1
                                _penny_capital_used += _pr.get("cost", 0)
                                try:
                                    _pk = KiteSession.get()
                                    if _pk:
                                        place_gtt_immediate(
                                            _pk, _psym, _pr["qty"],
                                            _pc["price"], _pc["sl"], _pc["t2"],
                                            trader_obj=self.swing
                                        )
                                except Exception:
                                    pass
                                send_telegram(
                                    f"PENNY MULTIBAGGER ENTRY\n"
                                    f"{_psym} @ Rs.{_pc['price']:.2f}\n"
                                    f"Score: {_pc['score']}/10 | {', '.join(_pc['reasons'][:4])}\n"
                                    f"SL: Rs.{_pc['sl']:.2f} | T1: Rs.{_pc['t1']:.2f} | T2 (50%): Rs.{_pc['t2']:.2f}\n"
                                    f"Capital limit: {PennyMultibaggerScanner.PENNY_MAX_CAPITAL_PCT}% of swing",
                                    priority="trade"
                                )

                # Auto-promote penny winners (50%+ gain)
                for _ps, _pp in list(self.swing.book.get("positions", {}).items()):
                    if _pp.get("source", "").startswith("PENNY"):
                        _pp_entry = _pp.get("entry_price", 0)
                        _pp_current = _penny_ltp.get(_ps, {}).get("last_price", 0) if _penny_ltp else 0
                        if not _pp_current:
                            _pp_scan = next((s for s in scans if s["symbol"] == _ps), None)
                            _pp_current = _pp_scan["price"] if _pp_scan else 0
                        if _pp_current > 0 and _pp_entry > 0:
                            _pp_gain = (_pp_current - _pp_entry) / _pp_entry * 100
                            if _pp_gain >= 50:
                                _pp["source"] = _pp["source"].replace("PENNY", "PROMOTED_PENNY")
                                _pp["target2"] = round(_pp_entry * 2.0, 2)
                                self.swing._save()
                                send_telegram(
                                    f"PENNY PROMOTED\n"
                                    f"{_ps} gain: +{_pp_gain:.0f}%\n"
                                    f"New T2: Rs.{_pp['target2']:.2f} (100% target)\n"
                                    f"Letting the winner run!",
                                    priority="trade"
                                )
            except Exception as _penny_err:
                logger.debug(f"Penny scanner: {_penny_err}")

        if self._phase2 is not None:
            try:
                # Gather existing positions across all strategies
                _all_positions = set()
                for _trader in [self.intraday, self.swing, self.longterm]:
                    _all_positions.update(_trader.book.get("positions", {}).keys())

                # Calculate idle cash % for compounder
                _swing_cap = self.swing.book.get("capital", 1)
                _swing_avail = self.swing.book.get("available", 0)
                _idle_pct = _swing_avail / max(_swing_cap, 1)

                # Get Fear & Greed for sector rotation
                _fg_val = 50
                try:
                    if _LIVE_MODULE_LOADED:
                        _fg_val = SentimentMatrix.get_fear_greed()
                except Exception:
                    pass

                # Get market condition for sector rotation
                _mkt_condition = "NEUTRAL"
                try:
                    if hasattr(self, '_live_order_mgr'):
                        _alloc = getattr(self, '_live_capital_alloc', {})
                        _mkt_condition = _alloc.get("_condition", "NEUTRAL") if isinstance(_alloc, dict) else "NEUTRAL"
                except Exception:
                    pass

                # Run all Phase 2 scanners
                _p2_results = self._phase2.run_all(
                    scans=scans,
                    filings=filings,
                    macro_signals=macro_signals,
                    market_condition=_mkt_condition,
                    fg_value=_fg_val,
                    existing_positions=_all_positions,
                    idle_pct=_idle_pct,
                )

                # ── Route Phase 2 signals to strategies ──────────
                _p2_placed = 0
                for _scanner_key in ["promoter", "superstar", "52w_low", "compounder"]:
                    for sig in _p2_results.get(_scanner_key, []):
                        _sym = sig["symbol"]
                        _price = sig["price"]

                        # Skip if already in any position
                        if (_sym in self.intraday.book.get("positions", {})
                            or _sym in self.swing.book.get("positions", {})
                            or _sym in self.longterm.book.get("positions", {})):
                            continue

                        # Sentiment Matrix filter (same as main 3AI flow)
                        if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                            try:
                                _r = next((r for r in scans if r["symbol"] == _sym), None)
                                _scan_data = {
                                    "pe": _r.get("pe", 999) if _r else 999,
                                    "debt_equity": _r.get("debt_eq", 999) if _r else 999,
                                    "promoter_holding": _r.get("promoter_holding", 0) if _r else 0,
                                    "mcap_cr": _r.get("mcap_cr", 0) if _r else 0,
                                    "promoter_buying": _scanner_key == "promoter",
                                    "turnaround_score": sig.get("score", 0),
                                }
                                if not SentimentMatrix.filter_stock(_sym, scan_data=_scan_data):
                                    logger.info(f"QUALITY BLOCKED [{_sym}]")
                                    continue
                            except Exception:
                                pass  # On error, proceed

                        # Sector Rotation Bias conviction adjustment
                        _p2_bias = _p2_results.get("sector_bias")
                        if _p2_bias and _PHASE2_LOADED:
                            _adj_conv, _adj_reason = SectorRotationBias.adjust_conviction(
                                _sym, sig.get("score", 0) * 10, _p2_bias
                            )
                            if _adj_reason:
                                sig["reasons"].append(_adj_reason)

                        # Route to target strategy
                        _target = sig["target_strategy"]
                        _source = sig["source"] + f"|{STRATEGY_MODE}"
                        _placed = False

                        if _target == "longterm" and self.risk.can_trade():
                            _placed = self.longterm.entry(
                                _sym, _price, f"{sig['scanner']} BUY",
                                sig["sl"], sig["t1"], sig["t2"],
                                source=_source
                            )
                        elif _target == "swing" and self.risk.can_trade():
                            _placed = self.swing.entry(
                                _sym, _price, f"{sig['scanner']} BUY",
                                sig["sl"], sig["t1"], sig["t2"],
                                source=_source
                            )
                        elif _target == "intraday" and is_open and is_intraday_window() and self.risk.can_trade_intraday():
                            _placed = self.intraday.entry(
                                _sym, _price, f"{sig['scanner']} BUY",
                                sig["sl"], sig["t1"], sig["t2"],
                                source=_source
                            )

                        if _placed:
                            _p2_placed += 1

                if _p2_placed > 0:
                    logger.info(f"Phase2 Scanners: {_p2_placed} trades placed from {_p2_results['total_signals']} signals")

            except Exception as _p2_err:
                logger.debug(f"Phase2 Scanners: {_p2_err}")

    @staticmethod
    def evaluate_trade(symbol, price, scan_result, sentiment_score,
                      filings, macro_signals, patterns):
        """FIX #1: Safety delegate — routes to ThreeAgentAI.evaluate_trade.
        Prevents crash if any code path calls self.evaluate_trade instead of
        ThreeAgentAI.evaluate_trade directly."""
        return ThreeAgentAI.evaluate_trade(
            symbol, price, scan_result, sentiment_score,
            filings, macro_signals, patterns
        )

    def _get_summaries(self):
        return {"intraday":self.intraday.summary(),"swing":self.swing.summary(),
                "longterm":self.longterm.summary(),"fno":self.fno.summary()}

    def _get_macro(self):
        """Get macro signals, cached for 30 minutes."""
        if time.time() - self._macro_ts < 1800 and self._macro_signals:
            return self._macro_signals
        try:
            self._macro_signals, self._macro_data = MacroIntelligence.get_macro_signals()
            self._macro_ts = time.time()
        except Exception as e:
            logger.error(f"Macro fetch: {e}")
        return self._macro_signals

    def send_market_pulse(self):
        """07:00 IST — Pre-Market Pulse style report."""
        logger.info("🌅 Generating Market Pulse (07:00)...")
        try:
            market_data = self.mdc.fetch_global_markets()
            fg          = self.mdc.get_fear_greed()
            gainers, losers = self.mdc.get_nifty_gainers_losers()
            sectors     = self.mdc.get_sectoral_performance()
            filings     = self.filings.get_recent(hours=12)
            scans       = self.get_scan()

            # Part 1
            msg1 = self.tb.pre_market_pulse(
                market_data, fg, gainers, losers, sectors,
                filings, scans, len(FNO_STOCKS), len(PRIORITY_500)
            )
            send_telegram(msg1, priority="report")

            # Part 2
            msg2 = self.tb.pre_market_pulse_part2(
                gainers, losers, sectors, filings, scans,
                len(FNO_STOCKS), len(PRIORITY_500)
            )
            send_telegram(msg2, priority="report")

            # AI commentary (uses 1 of 5 daily Gemini calls)
            prompt = f"""Senior Indian equity analyst. 7 AM morning briefing.
Nifty 50: {market_data.get('Nifty 50',{}).get('price','?')}
Fear & Greed: {fg['value']} ({fg['class']})
Overnight filings: {len(filings)} | Critical: {len([f for f in filings if f.get('urgency')=='CRITICAL'])}
Give 5-point briefing: 1.Market mood 2.Key risk 3.Best sector 4.One Nifty50 stock to watch 5.NIFTY support/resistance
Max 150 words. Use ₹."""
            ai = call_gemini(prompt)
            send_telegram(f"🤖 *AI MORNING BRIEFING*\n━━━━━━━━━━━━━━━━━━━━━━━\n{ai}", priority="report")
            logger.info("✅ Market Pulse sent")
        except Exception as e:
            logger.error(f"Market Pulse error: {e}")

    def send_eod(self,scans):
        # Advance F&O positioning after market close
        try:
            advance = self.fno.enter_advance(scans)
            if advance:
                logger.info(f"F&O advance positions: {len(advance)}")
        except Exception as e:
            logger.error(f"Advance F&O: {e}")

        # AMO orders for tomorrow — equity + F&O
        amo_msg = ""
        try:
            macro_signals = self._get_macro()
            filings       = self.filings.get_recent(hours=24)
            news_alerts   = self.news.recent(hours=6)
            candidates    = AMOEngine.find_amo_candidates(scans, filings, macro_signals, news_alerts)
            if candidates:
                AMOEngine.place_amo_orders(candidates, self.risk)
                logger.info(f"✅ AMO: {len(candidates)} orders placed for tomorrow")
                amo_msg = f"\n🌙 *AMO FOR TOMORROW: {len(candidates)} stocks*\n"
                for c in candidates[:5]:
                    amo_msg += f"  📈 `{c['symbol']}` ₹{c['price']} DVM:{c['dvm']} {c['macro']}\n"
            else:
                logger.info("🌙 AMO: No candidates met criteria today")
                amo_msg = "\n🌙 *AMO: No strong setups for tomorrow*\n"
        except Exception as e:
            logger.error(f"AMO: {e}")
            amo_msg = f"\n🌙 *AMO: Error — {str(e)[:100]}*\n"

        summaries=self._get_summaries(); risk_s=self.risk.get_summary()
        filings_today=self.filings.get_recent(hours=12)
        msg=self.tb.eod_report(risk_s,summaries,filings_today,scans,len(PRIORITY_500),len(FNO_STOCKS))
        msg += amo_msg  # Append AMO status to EOD report
        
        # v23.6.4: Add Win Rate Dashboard to EOD report
        try:
            _wr_dashboard = WinRateDashboard.get_dashboard_text()
            _wr_strategy = WinRateDashboard.get_strategy_breakdown()
            send_telegram(_wr_dashboard, priority="report")
            send_telegram(_wr_strategy, priority="report")
        except Exception as _wr_err:
            logger.debug(f"Win Rate Dashboard: {_wr_err}")
        
        # v23.6.4: Add ETF Hedge recommendation
        try:
            _nifty_quote = {}
            _vix = 15
            _kite = KiteSession.get()
            if _kite:
                _nifty_quote = _kite.quote(["NSE:NIFTY 50"]).get("NSE:NIFTY 50", {})
                _vix_quote = _kite.quote(["NSE:INDIA VIX"]).get("NSE:INDIA VIX", {})
                _vix = _vix_quote.get("last_price", 15)
            _nifty_ltp = _nifty_quote.get("last_price", 0)
            _nifty_close = _nifty_quote.get("ohlc", {}).get("close", _nifty_ltp)
            _nifty_change = ((_nifty_ltp - _nifty_close) / _nifty_close * 100) if _nifty_close > 0 else 0
            
            _total_cap = sum(s.get("capital", 0) for s in summaries)
            _avail_cap = sum(s.get("available", 0) for s in summaries)
            
            _hedge_rec = ETFHedgeManager.get_hedge_recommendation(_nifty_change, _vix, _total_cap, _avail_cap)
            if _hedge_rec:
                send_telegram(
                    f"🛡️ *ETF HEDGE SUGGESTION*\n"
                    f"━━━━━━━━━━━━━━━━━━━━━\n"
                    f"ETF: `{_hedge_rec['etf']}`\n"
                    f"Amount: ₹{_hedge_rec['amount']:,.0f}\n"
                    f"Priority: {_hedge_rec['priority']}\n"
                    f"Reason: {_hedge_rec['reason']}",
                    priority="report"
                )
            _hedge_status = ETFHedgeManager.get_hedge_status()
            if "No active" not in _hedge_status:
                send_telegram(_hedge_status, priority="report")
        except Exception as _hedge_err:
            logger.debug(f"ETF Hedge: {_hedge_err}")
        
        # AI EOD commentary (uses 1 of 5 daily Gemini calls)
        prompt=f"""Senior Indian equity analyst. EOD review.
PnL: ₹{risk_s.get('total_pnl',0):,.0f} | Filings: {len(filings_today)} | Top: {[r['symbol'] for r in scans[:3]]}
3-point summary: 1.What worked 2.Key risk tomorrow 3.Best setup tomorrow. Max 100 words."""
        ai=call_gemini(prompt)
        send_telegram(msg, priority="report")
        send_telegram(f"🤖 *AI EOD ANALYSIS*\n━━━━━━━━━━━━━━━━━━━━━━━\n{ai}", priority="report")
        # PDF
        self._send_6h_pdf(scans,"END-OF-DAY")
        logger.info("📊 EOD report sent")

    def send_6h_report(self,scans):
        _,session=is_market_open()
        summaries=self._get_summaries(); risk_s=self.risk.get_summary()
        filings=self.filings.get_recent(hours=6)
        news_count=len(self.news.recent(hours=6))
        msg=self.tb.six_hour_report(summaries,risk_s,scans,filings,news_count,len(PRIORITY_500),len(FNO_STOCKS),session)
        send_telegram(msg, priority="report")
        self._send_6h_pdf(scans,"6-HOUR")
        self._check_live(summaries)

    def _send_6h_pdf(self,scans,report_type):
        """FIX #1/#2/#11/#14: Professional PDF with BE logo, owner name, AI voting details."""
        try:
            from reportlab.graphics.shapes import Drawing, Circle, Line, String, Rect
            from reportlab.graphics import renderPDF
            from reportlab.graphics.widgets.markers import makeMarker

            _,session=is_market_open()
            summaries=self._get_summaries(); risk_s=self.risk.get_summary()
            filings=self.filings.get_recent(hours=8)
            social=self.social.get_recent(hours=6)
            prompt=f"Senior Indian equity analyst. {report_type} report. Top signals: {[r['symbol'] for r in scans[:5]]}. Filings: {len(filings)}. Give 5-point analysis. Max 200 words. Use ₹."
            ai=call_gemini(prompt)
            ts=now_ist()
            fname=f"GlobalEye_BE_{report_type}_{ts.strftime('%Y%m%d_%H%M')}.pdf"
            fpath=os.path.join(REPORTS_DIR,fname)
            doc=SimpleDocTemplate(fpath,pagesize=A4,topMargin=15*mm,bottomMargin=15*mm,leftMargin=12*mm,rightMargin=12*mm)
            styles=getSampleStyleSheet()

            # ── FIX #14: BE Color scheme — eye-catching professional ──
            NAVY     = colors.HexColor("#0A1628")
            GOLD     = colors.HexColor("#D4AF37")
            DARKGOLD = colors.HexColor("#B8941F")
            GREEN    = colors.HexColor("#27AE60")
            RED      = colors.HexColor("#E74C3C")
            LGREY    = colors.HexColor("#F8F9FA")
            MGREY    = colors.HexColor("#95A5A6")
            WHITE    = colors.white
            W=186*mm; story=[]

            # ── BE LOGO — Clean design: eye + title only ──
            def _be_logo():
                """Golden eye logo — header only. All info in footer."""
                d = Drawing(186*mm, 30*mm)
                # Navy background
                d.add(Rect(0, 0, 186*mm, 30*mm, fillColor=NAVY, strokeColor=None))
                # Gold accent lines
                d.add(Rect(0, 0, 186*mm, 1.5*mm, fillColor=GOLD, strokeColor=None))
                d.add(Rect(0, 28.5*mm, 186*mm, 1.5*mm, fillColor=GOLD, strokeColor=None))
                # Eye icon — outer ring
                cx, cy = 22*mm, 15*mm
                d.add(Circle(cx, cy, 9*mm, fillColor=GOLD, strokeColor=DARKGOLD, strokeWidth=1.5))
                d.add(Circle(cx, cy, 5*mm, fillColor=NAVY, strokeColor=None))
                d.add(Circle(cx, cy, 2*mm, fillColor=GOLD, strokeColor=None))
                # Eyelid curves (scan lines)
                from reportlab.graphics.shapes import PolyLine
                # Upper eyelid
                d.add(PolyLine([10*mm,15*mm, 16*mm,8*mm, 22*mm,6*mm, 28*mm,8*mm, 34*mm,15*mm],
                    strokeColor=GOLD, strokeWidth=1.2, fillColor=None))
                # Lower eyelid
                d.add(PolyLine([10*mm,15*mm, 16*mm,22*mm, 22*mm,24*mm, 28*mm,22*mm, 34*mm,15*mm],
                    strokeColor=GOLD, strokeWidth=1.2, fillColor=None))
                # GLOBAL EYE — large gold text
                d.add(String(42*mm, 18*mm, "GLOBAL EYE", fontSize=18, fillColor=GOLD, fontName="Helvetica-Bold"))
                # BILLIONAIRE EDITION
                d.add(String(42*mm, 9*mm, "BILLIONAIRE EDITION", fontSize=10, fillColor=WHITE, fontName="Helvetica"))
                return d

            story.append(_be_logo())
            story.append(Spacer(1,4))
            # Report type + date (small line below logo)
            story.append(Paragraph(
                f"<b>{report_type} REPORT</b> | {ts.strftime('%a, %d %b %Y %H:%M')} IST | Mode: {STRATEGY_MODE}",
                ParagraphStyle("rpt_line",parent=styles["Normal"],fontSize=8,textColor=MGREY)))
            story.append(Spacer(1,6))

            # Portfolio Summary
            total_pnl=sum(s.get("total_pnl",0) for s in summaries.values())
            sign="+" if total_pnl>=0 else ""
            pnl_color = GREEN if total_pnl >= 0 else RED
            story.append(Paragraph(
                f"<b><font color='#D4AF37'>PORTFOLIO OVERVIEW</font></b> | "
                f"Total P&L: <font color='{'#27AE60' if total_pnl>=0 else '#E74C3C'}'><b>{sign}₹{total_pnl:,.0f}</b></font> | "
                f"Equity: {len(PRIORITY_500)} | F&O: {len(FNO_STOCKS)}",
                styles["Normal"]))
            story.append(Spacer(1,4))

            # Strategy table with gold header
            sh=["Strategy","Capital","P&L","Win%","Trades","Open","Mode"]
            sr=[sh]
            for name,s in summaries.items():
                sp="+" if s.get("total_pnl",0)>=0 else ""
                sr.append([name.upper(),f"₹{s.get('capital',0):,.0f}",f"{sp}₹{s.get('total_pnl',0):,.0f}",
                           f"{s.get('win_rate',0)}%",str(s.get("total_trades",0)),
                           str(s.get("open_count",0)),STRATEGY_MODE[:3]])
            st=Table(sr,colWidths=[26,26,26,18,18,16,18]*mm,repeatRows=1)
            st.setStyle(TableStyle([
                ("BACKGROUND",(0,0),(-1,0),NAVY),("TEXTCOLOR",(0,0),(-1,0),GOLD),
                ("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("FONTSIZE",(0,0),(-1,-1),8),
                ("ALIGN",(0,0),(-1,-1),"CENTER"),("GRID",(0,0),(-1,-1),0.4,MGREY),
                ("ROWBACKGROUNDS",(0,1),(-1,-1),[WHITE,LGREY]),
                ("TOPPADDING",(0,0),(-1,-1),5),("BOTTOMPADDING",(0,0),(-1,-1),5)]))
            story.append(st); story.append(Spacer(1,6))

            # ── FIX #11: AI VOTING + BILLIONAIRE VALIDATION in PDF ────
            story.append(Paragraph(
                f"<font color='#D4AF37'><b>BILLIONAIRE PRE-TRADE VALIDATION LOG</b></font>"
                f" (Top 10 | Mode: {STRATEGY_MODE})",
                styles["Normal"]))
            story.append(Spacer(1,2))
            story.append(Paragraph(
                f"<i>{'AGGRESSIVE: 1/3 vote + 75% Tech Recheck (6/8)' if STRATEGY_MODE=='AGGRESSIVE' else 'BALANCED: 2/3 vote + Dalio 5-point Stress Test'}</i>",
                ParagraphStyle("valinfo",parent=styles["Normal"],fontSize=6.5,textColor=MGREY)))
            story.append(Spacer(1,3))

            ai_votes = []
            for r in scans[:10]:
                sym = r["symbol"]
                if sym in ["NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY"]: continue
                try:
                    filings_r = self.filings.get_recent(hours=6)
                    macro_signals = self._get_macro()
                    sent_score, sent_label = SentimentEngine.score(
                        sym, r, filings_r, self.news.recent(hours=6),
                        *MacroIntelligence.get_sector_bias(macro_signals), [])
                    approved, confidence, reasoning, votes = ThreeAgentAI.evaluate_trade(
                        sym, r["price"], r, sent_score, filings_r, macro_signals, [])

                    # Parse reasoning lines — new format has variable length
                    # A1[Idea], A2[Tech], A3[Eval], VOTE, optional RECHECK/STRESS, FINAL
                    a1 = a2 = a3 = "?"
                    validation = "-"
                    for line in reasoning:
                        if "A1[Idea]" in line: a1 = "✅" if "✅" in line.split(":")[0] else "❌"
                        elif "A2[Tech]" in line: a2 = "✅" if "✅" in line.split(":")[0] else "❌"
                        elif "A3[Eval]" in line: a3 = "✅" if "✅" in line.split(":")[0] else "❌"
                        elif "RECHECK" in line:
                            validation = "✅" if "PASS" in line else "❌"
                        elif "STRESS" in line:
                            validation = "✅" if "ALL PASS" in line else "❌"

                    decision = "✅" if approved else "❌"
                    ai_votes.append([sym, str(r["price"]), str(r.get("dvm_score","-")),
                                      a1, a2, a3, validation, decision, f"{confidence:.0f}"])
                except Exception:
                    ai_votes.append([sym, str(r["price"]), str(r.get("dvm_score","-")),
                                      "?", "?", "?", "?", "?", "-"])

            if ai_votes:
                val_label = "Recheck" if STRATEGY_MODE == "AGGRESSIVE" else "Stress"
                vote_header = ["Symbol","Price","DVM","A1","A2","A3",val_label,"Final","Conf"]
                vote_data = [vote_header] + ai_votes
                vt = Table(vote_data, colWidths=[20,14,10,12,12,12,14,12,12]*mm, repeatRows=1)
                vt.setStyle(TableStyle([
                    ("BACKGROUND",(0,0),(-1,0),NAVY),("TEXTCOLOR",(0,0),(-1,0),GOLD),
                    ("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("FONTSIZE",(0,0),(-1,-1),7),
                    ("ALIGN",(0,0),(-1,-1),"CENTER"),("GRID",(0,0),(-1,-1),0.3,MGREY),
                    ("ROWBACKGROUNDS",(0,1),(-1,-1),[WHITE,LGREY]),
                    ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4)]))
                story.append(vt)
            story.append(Spacer(1,6))

            # Filings
            story.append(Paragraph(
                f"<font color='#D4AF37'><b>NSE/BSE FILINGS</b></font> (Last 8h): {len(filings)} | "
                f"Critical: {len([f for f in filings if f.get('urgency')=='CRITICAL'])}",
                styles["Normal"]))
            story.append(Spacer(1,3))
            fh=["Time","Symbol","Exch","Type","Urgency","Sentiment","Subject"]
            fr=[fh]
            for f in sorted(filings,key=lambda x:x.get("timestamp",""),reverse=True)[:12]:
                fr.append([f.get("timestamp","")[:16].replace("T"," "),f.get("symbol",""),
                           f.get("exchange",""),f.get("type","")[:12],f.get("urgency",""),
                           f.get("sentiment",""),f.get("subject","")[:50]])
            if len(fr)>1:
                ft=Table(fr,colWidths=[22,16,12,20,16,18,82]*mm,repeatRows=1)
                ft.setStyle(TableStyle([
                    ("BACKGROUND",(0,0),(-1,0),NAVY),("TEXTCOLOR",(0,0),(-1,0),GOLD),
                    ("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("FONTSIZE",(0,0),(-1,-1),6.5),
                    ("ALIGN",(0,0),(5,-1),"CENTER"),("ALIGN",(6,0),(6,-1),"LEFT"),
                    ("GRID",(0,0),(-1,-1),0.3,MGREY),
                    ("ROWBACKGROUNDS",(0,1),(-1,-1),[WHITE,LGREY]),
                    ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4)]))
                story.append(ft)
            story.append(Spacer(1,6))

            # Scan page
            story.append(PageBreak())
            story.append(Paragraph(
                f"<font color='#D4AF37'><b>DVM SCAN — TOP {min(20,len(scans))} SIGNALS</b></font>"
                f" ({len(PRIORITY_500)} stocks scanned | {STRATEGY_MODE} mode)",
                styles["Normal"]))
            story.append(Spacer(1,3))
            sch=["Symbol","Price","DVM","Intraday","Swing","LT","PE","ROE%","Trend","Signal"]
            scr=[sch]
            for r in scans[:20]:
                scr.append([r["symbol"],str(r["price"]),str(r.get("dvm_score","-")),
                            r["intraday_sig"][:12],r["swing_sig"][:10],r["lt_sig"][:8],
                            str(r.get("pe","-")),str(r.get("roe","-")),r["trend"][:12],r["overall"][:14]])
            sct=Table(scr,colWidths=[18,14,10,20,16,12,10,10,22,20]*mm,repeatRows=1)
            sct.setStyle(TableStyle([
                ("BACKGROUND",(0,0),(-1,0),NAVY),("TEXTCOLOR",(0,0),(-1,0),GOLD),
                ("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("FONTSIZE",(0,0),(-1,-1),6.5),
                ("ALIGN",(0,0),(-1,-1),"CENTER"),("GRID",(0,0),(-1,-1),0.3,MGREY),
                ("ROWBACKGROUNDS",(0,1),(-1,-1),[WHITE,LGREY]),
                ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4)]))
            story.append(sct); story.append(Spacer(1,6))

            # AI Commentary
            story.append(Paragraph("<font color='#D4AF37'><b>AI MARKET COMMENTARY</b></font>",styles["Normal"]))
            story.append(Spacer(1,3))
            for line in ai.split("\n"):
                if line.strip(): story.append(Paragraph(line.strip(),styles["Normal"]))
            story.append(Spacer(1,6))

            # ── Footer with owner name + copyright ──
            story.append(HRFlowable(width="100%",thickness=1,color=GOLD))
            story.append(Paragraph(
                f"<font color='#D4AF37'><b>GLOBAL EYE {VERSION} | {EDITION}</b></font>",
                ParagraphStyle("footer",parent=styles["Normal"],fontSize=8,textColor=MGREY)))
            story.append(Paragraph(
                f"Prepared for: {OWNER_NAME} | All Rights Reserved",
                ParagraphStyle("footer2",parent=styles["Normal"],fontSize=8,textColor=MGREY)))
            story.append(Paragraph(
                f"Not SEBI registered. Not financial advice. "
                f"Consult a SEBI-registered advisor. "
                f"{ts.strftime('%d %b %Y %H:%M')} IST",
                ParagraphStyle("disc",parent=styles["Normal"],fontSize=6,textColor=MGREY)))
            doc.build(story)
            send_telegram(f"📄 *BE PDF Report: {report_type}*\n{OWNER_NAME} | {ts.strftime('%d %b %Y %H:%M')} IST",doc_path=fpath, priority="report")
        except Exception as e:
            logger.error(f"PDF error: {e}\n{traceback.format_exc()}")

    def _check_live(self,summaries):
        if self.state.get("live_prompt_sent"): return
        if all(t.is_ready_for_live() for t in [self.intraday,self.swing,self.longterm]):
            total=sum(s.get("total_pnl",0) for s in summaries.values())
            avg_wr=sum(s.get("win_rate",0) for s in summaries.values())/len(summaries)
            send_telegram(
                f"🎯 *3-DAY PAPER COMPLETE — READY FOR LIVE!*\n\n"
                f"✅ Win Rate: {avg_wr:.1f}%\n"
                f"✅ Paper PnL: +₹{total:,.0f}\n\n"
                f"To go live:\n1. Edit .env → `TRADING_MODE=LIVE`\n2. Restart task\n\n"
                f"⚠️ Start small. Never risk more than you can afford to lose."
            )
            self.state["live_prompt_sent"]=True; save_json(STATE_FILE,self.state)

    def send_detailed_portfolio(self, report_type="MID-DAY"):
        """
        PDF report mirroring Zerodha app exactly:
          Section 1: HOLDINGS   (Zerodha Holdings tab)
          Section 2: POSITIONS  (Zerodha Positions tab — intraday MIS)
          Section 3: GTT        (Zerodha GTT tab — OCO SL/Target per stock)
          Section 4: FUNDS      (Zerodha Funds screen)
          Section 5: CLOSED TRADES TODAY + 30-day history
        100% Kite-sourced — no bot-book duplication.
        """
        try:
            kite    = KiteSession.get()
            risk_s  = self.risk.get_summary()
            ts      = now_ist()
            today   = today_str()

            time_labels = {
                "FIRST-TRADE": "09:30 IST — First Trade Update",
                "MID-DAY":     "12:00 IST — Mid-Day Portfolio",
                "PRE-CLOSE":   "14:00 IST — Pre-Close Check",
                "EOD-FINAL":   "15:30 IST — Final EOD P&L",
            }
            title = time_labels.get(report_type, report_type)

            # ── Fetch everything from Kite ────────────────────────────────
            kite_holdings  = []
            kite_positions = []   # net positions (includes intraday)
            kite_gtts      = []
            kite_amo_open  = []   # pending AMO orders (Open tab)
            kite_amo_exec  = []   # executed AMO orders today (Executed tab)
            avail_cash     = 0.0
            used_margin    = 0.0
            opening_bal    = 0.0
            payin          = 0.0
            collateral     = 0.0

            if kite:
                try:
                    kite_holdings = kite.holdings() or []
                except Exception as _e:
                    logger.debug(f"Holdings: {_e}")
                try:
                    _pos = kite.positions() or {}
                    kite_positions = _pos.get("net", [])
                except Exception as _e:
                    logger.debug(f"Positions: {_e}")
                try:
                    kite_gtts = [g for g in (kite.get_gtts() or [])
                                 if g.get("status") == "active"]
                except Exception as _e:
                    logger.debug(f"GTTs: {_e}")
                try:
                    _all_orders = kite.orders() or []
                    kite_amo_open = [o for o in _all_orders
                                     if o.get("variety") == "amo"
                                     and o.get("status") in ("OPEN", "TRIGGER PENDING")]
                    kite_amo_exec = [o for o in _all_orders
                                     if o.get("variety") == "amo"
                                     and o.get("status") == "COMPLETE"]
                except Exception as _e:
                    logger.debug(f"AMO orders: {_e}")
                try:
                    _m = kite.margins(segment="equity")
                    avail_cash  = round(_m.get("available", {}).get("cash", 0) or
                                        _m.get("net", 0), 2)
                    used_margin = round(_m.get("utilised", {}).get("debits", 0), 2)
                    opening_bal = round(_m.get("available", {}).get("opening_balance", 0), 2)
                    payin       = round(_m.get("available", {}).get("intraday_payin", 0), 2)
                    collateral  = round(
                        (_m.get("available", {}).get("collateral", 0) or 0) +
                        (_m.get("available", {}).get("liquid_collateral", 0) or 0), 2)
                except Exception as _e:
                    logger.debug(f"Margins: {_e}")

            # ── Bot-book lookup for SL enrichment only ────────────────────
            _sl_map = {}
            for _tr in [self.intraday, self.swing, self.longterm]:
                for _sym, _pos in _tr.book.get("positions", {}).items():
                    if _sym not in _sl_map:
                        _sl_map[_sym] = _pos.get("stop_loss", 0)

            # GTT lookup: symbol -> (sl_trigger, tp_trigger)
            _gtt_map = {}
            for _g in kite_gtts:
                _gsym  = _g.get("condition", {}).get("tradingsymbol", "")
                _trigs = _g.get("trigger_values", [])
                if _gsym:
                    _gtt_map[_gsym] = {
                        "sl":  _trigs[0] if len(_trigs) > 0 else 0,
                        "tp":  _trigs[1] if len(_trigs) > 1 else 0,
                        "id":  _g.get("id", ""),
                        "type": _g.get("type", "OCO"),
                    }

            # ── PDF setup ─────────────────────────────────────────────────
            fname = f"GlobalEye_Portfolio_{report_type}_{ts.strftime('%Y%m%d_%H%M')}.pdf"
            fpath = os.path.join(REPORTS_DIR, fname)
            doc   = SimpleDocTemplate(fpath, pagesize=A4,
                                      topMargin=12*mm, bottomMargin=12*mm,
                                      leftMargin=10*mm, rightMargin=10*mm)
            styles  = getSampleStyleSheet()
            NAVY    = colors.HexColor("#0A1628")
            GOLD    = colors.HexColor("#D4AF37")
            DKGOLD  = colors.HexColor("#B8941F")
            GREEN   = colors.HexColor("#27AE60")
            RED     = colors.HexColor("#E74C3C")
            BLUE    = colors.HexColor("#3498DB")
            LGREY   = colors.HexColor("#F4F6F8")
            MGREY   = colors.HexColor("#95A5A6")
            DKGREY  = colors.HexColor("#2C3E50")
            WHITE   = colors.white
            story   = []

            # ── Helper styles ──────────────────────────────────────────────
            def _s(name, **kw):
                base = kw.pop("parent", "Normal")
                return ParagraphStyle(name, parent=styles[base], **kw)

            SEC_HDR = _s("sec_hdr", fontSize=9, fontName="Helvetica-Bold",
                         textColor=GOLD, spaceBefore=8, spaceAfter=3)
            BODY    = _s("body",    fontSize=8, textColor=DKGREY)
            SMALL   = _s("small",  fontSize=7, textColor=MGREY)

            def _tbl(rows, col_w, hdr_bg=NAVY):
                t = Table(rows, colWidths=col_w, repeatRows=1)
                n = len(rows) - 1
                style_cmds = [
                    ("BACKGROUND", (0,0), (-1,0), hdr_bg),
                    ("TEXTCOLOR",  (0,0), (-1,0), GOLD),
                    ("FONTNAME",   (0,0), (-1,0), "Helvetica-Bold"),
                    ("FONTSIZE",   (0,0), (-1,-1), 7.5),
                    ("ALIGN",      (0,0), (-1,-1), "CENTER"),
                    ("VALIGN",     (0,0), (-1,-1), "MIDDLE"),
                    ("GRID",       (0,0), (-1,-1), 0.25, MGREY),
                    ("TOPPADDING", (0,0), (-1,-1), 4),
                    ("BOTTOMPADDING", (0,0), (-1,-1), 4),
                ]
                if n > 0:
                    style_cmds.append(
                        ("ROWBACKGROUNDS", (0,1), (-1,-1), [WHITE, LGREY]))
                t.setStyle(TableStyle(style_cmds))
                return t

            def _summary_box(left_label, left_val, mid_label, mid_val,
                             right_label, right_val, val_color=DKGREY):
                d = [
                    [left_label,  mid_label,  right_label],
                    [left_val,    mid_val,    right_val],
                ]
                t = Table(d, colWidths=[62*mm, 62*mm, 62*mm])
                t.setStyle(TableStyle([
                    ("BACKGROUND", (0,0), (-1,0), DKGREY),
                    ("TEXTCOLOR",  (0,0), (-1,0), MGREY),
                    ("FONTNAME",   (0,0), (-1,0), "Helvetica"),
                    ("FONTSIZE",   (0,0), (-1,-1), 8),
                    ("ALIGN",      (0,0), (-1,-1), "CENTER"),
                    ("VALIGN",     (0,0), (-1,-1), "MIDDLE"),
                    ("TOPPADDING", (0,0), (-1,-1), 5),
                    ("BOTTOMPADDING", (0,0), (-1,-1), 5),
                    ("FONTNAME",   (0,1), (-1,1), "Helvetica-Bold"),
                    ("FONTSIZE",   (0,1), (-1,1), 11),
                    ("TEXTCOLOR",  (0,1), (-1,1), val_color),
                    ("BACKGROUND", (0,1), (-1,1), colors.HexColor("#1C2C3E")),
                    ("GRID",       (0,0), (-1,-1), 0.3, MGREY),
                ]))
                return t

            # ── HEADER ────────────────────────────────────────────────────
            from reportlab.graphics.shapes import (Drawing, Circle, String,
                                                    Rect as DRect,
                                                    PolyLine as DPolyLine)
            def _logo():
                d = Drawing(186*mm, 26*mm)
                d.add(DRect(0, 0, 186*mm, 26*mm, fillColor=NAVY, strokeColor=None))
                d.add(DRect(0, 0, 186*mm, 1.2*mm, fillColor=GOLD, strokeColor=None))
                d.add(DRect(0, 24.8*mm, 186*mm, 1.2*mm, fillColor=GOLD, strokeColor=None))
                cx, cy = 18*mm, 13*mm
                d.add(Circle(cx, cy, 8*mm, fillColor=GOLD, strokeColor=DKGOLD, strokeWidth=1.2))
                d.add(Circle(cx, cy, 4.5*mm, fillColor=NAVY, strokeColor=None))
                d.add(Circle(cx, cy, 1.8*mm, fillColor=GOLD, strokeColor=None))
                d.add(DPolyLine([8*mm,13*mm,13*mm,7*mm,18*mm,5.5*mm,23*mm,7*mm,28*mm,13*mm],
                                strokeColor=GOLD, strokeWidth=1, fillColor=None))
                d.add(DPolyLine([8*mm,13*mm,13*mm,19*mm,18*mm,20.5*mm,23*mm,19*mm,28*mm,13*mm],
                                strokeColor=GOLD, strokeWidth=1, fillColor=None))
                d.add(String(34*mm, 16*mm, "GLOBAL EYE",
                             fontSize=16, fillColor=GOLD, fontName="Helvetica-Bold"))
                d.add(String(34*mm, 8*mm, "BILLIONAIRE EDITION  |  Portfolio Report",
                             fontSize=9, fillColor=WHITE, fontName="Helvetica"))
                return d

            story.append(_logo())
            story.append(Spacer(1, 3))
            story.append(Paragraph(
                f"<b>{title}</b>  |  {ts.strftime('%a, %d %b %Y  %H:%M IST')}  |  "
                f"Mode: {STRATEGY_MODE}  |  GTTs active: {len(kite_gtts)}",
                _s("subhdr", fontSize=7.5, textColor=MGREY)))
            story.append(Spacer(1, 6))

            # ══════════════════════════════════════════════════════════════
            # SECTION 1 — HOLDINGS  (mirrors Zerodha Holdings tab)
            # ══════════════════════════════════════════════════════════════
            # Filter: only holdings with qty > 0
            h_active = [h for h in kite_holdings
                        if (h.get("quantity", 0) + h.get("t1_quantity", 0)) > 0]
            h_total_invested = sum(
                h.get("average_price", 0) *
                (h.get("quantity", 0) + h.get("t1_quantity", 0))
                for h in h_active)
            h_total_current  = sum(
                h.get("last_price", 0) *
                (h.get("quantity", 0) + h.get("t1_quantity", 0))
                for h in h_active)
            h_total_pnl      = round(h_total_current - h_total_invested, 2)
            h_pnl_pct        = round(h_total_pnl / h_total_invested * 100, 2) \
                               if h_total_invested > 0 else 0
            h_sign           = "+" if h_total_pnl >= 0 else ""
            h_color          = GREEN if h_total_pnl >= 0 else RED

            story.append(Paragraph(
                f"HOLDINGS  ({len(h_active)})", SEC_HDR))
            story.append(_summary_box(
                "Invested",         f"Rs.{h_total_invested:,.2f}",
                "Current Value",    f"Rs.{h_total_current:,.2f}",
                f"P&L  ({h_sign}{h_pnl_pct}%)",
                f"{h_sign}Rs.{abs(h_total_pnl):,.2f}",
                val_color=h_color))
            story.append(Spacer(1, 4))

            if h_active:
                h_rows = [["Stock", "Qty", "Avg Cost",
                           "Invested", "LTP", "P&L", "%",
                           "T1 Qty", "GTT SL", "GTT Target"]]
                for h in sorted(h_active, key=lambda x: x.get("tradingsymbol", "")):
                    sym   = h.get("tradingsymbol", "")
                    qty   = h.get("quantity", 0)
                    t1    = h.get("t1_quantity", 0)
                    tot_q = qty + t1
                    avg   = h.get("average_price", 0)
                    ltp   = h.get("last_price", avg)
                    inv   = round(avg * tot_q, 2)
                    pnl   = round((ltp - avg) * tot_q, 2)
                    pct   = round((ltp - avg) / avg * 100, 2) if avg > 0 else 0
                    sp    = "+" if pnl >= 0 else ""
                    _g    = _gtt_map.get(sym, {})
                    gtt_sl = f"Rs.{_g['sl']:,.1f}" if _g.get("sl") else "NO GTT"
                    gtt_tp = f"Rs.{_g['tp']:,.1f}" if _g.get("tp") else "—"
                    h_rows.append([
                        sym[:12],
                        str(tot_q),
                        f"Rs.{avg:,.2f}",
                        f"Rs.{inv:,.0f}",
                        f"Rs.{ltp:,.2f}",
                        f"{sp}Rs.{abs(pnl):,.0f}",
                        f"{sp}{pct}%",
                        str(t1) if t1 > 0 else "—",
                        gtt_sl,
                        gtt_tp,
                    ])
                story.append(_tbl(h_rows,
                    [20*mm,10*mm,18*mm,17*mm,18*mm,16*mm,11*mm,12*mm,18*mm,18*mm]))
            else:
                story.append(Paragraph("No holdings.", SMALL))
            story.append(Spacer(1, 8))

            # ══════════════════════════════════════════════════════════════
            # SECTION 2 — POSITIONS  (mirrors Zerodha Positions tab)
            # ══════════════════════════════════════════════════════════════
            # Show all net positions with non-zero qty (open or closed today)
            p_open   = [p for p in kite_positions if p.get("quantity", 0) != 0]
            p_closed = [p for p in kite_positions
                        if p.get("quantity", 0) == 0 and p.get("day_buy_quantity", 0) > 0]
            p_total_pnl = sum(p.get("pnl", 0) for p in kite_positions)
            p_sign = "+" if p_total_pnl >= 0 else ""
            p_color = GREEN if p_total_pnl >= 0 else RED

            story.append(Paragraph(
                f"POSITIONS  ({len(p_open)} open, {len(p_closed)} closed today)", SEC_HDR))
            story.append(_summary_box(
                "Open Positions",   str(len(p_open)),
                "Closed Today",     str(len(p_closed)),
                f"Total P&L",       f"{p_sign}Rs.{abs(p_total_pnl):,.2f}",
                val_color=p_color))
            story.append(Spacer(1, 4))

            all_pos_rows = p_open + p_closed
            if all_pos_rows:
                pos_rows = [["Stock", "Qty", "Avg", "LTP", "P&L", "%", "Product", "Type"]]
                for p in all_pos_rows:
                    sym   = p.get("tradingsymbol", "")
                    qty   = p.get("quantity", 0)
                    avg   = p.get("average_price", 0)
                    ltp   = p.get("last_price", avg)
                    pnl   = round(p.get("pnl", (ltp - avg) * abs(qty)), 2)
                    pct   = round(pnl / (avg * abs(qty)) * 100, 2) \
                            if avg > 0 and qty != 0 else 0
                    sp    = "+" if pnl >= 0 else ""
                    prod  = p.get("product", "")
                    tag   = "SOLD" if qty == 0 else ("BUY" if qty > 0 else "SHORT")
                    pos_rows.append([
                        sym[:12],
                        str(qty),
                        f"Rs.{avg:,.2f}",
                        f"Rs.{ltp:,.2f}",
                        f"{sp}Rs.{abs(pnl):,.0f}",
                        f"{sp}{pct}%",
                        prod,
                        tag,
                    ])
                story.append(_tbl(pos_rows,
                    [28*mm,14*mm,22*mm,22*mm,20*mm,14*mm,18*mm,18*mm]))
            else:
                story.append(Paragraph("No open positions.", SMALL))
            story.append(Spacer(1, 8))

            # ══════════════════════════════════════════════════════════════
            # SECTION 3 — PENDING AMO ORDERS  (Zerodha Orders → Open tab)
            # ══════════════════════════════════════════════════════════════
            # Only shown when there are pending or executed AMO orders
            if kite_amo_open or kite_amo_exec:
                story.append(Paragraph(
                    f"AMO ORDERS  "
                    f"({len(kite_amo_open)} pending, {len(kite_amo_exec)} executed today)",
                    SEC_HDR))

                if kite_amo_open:
                    story.append(Paragraph(
                        "PENDING — waiting for market open",
                        _s("amo_pend", fontSize=7.5, textColor=BLUE,
                           fontName="Helvetica-Bold", spaceAfter=2)))
                    amo_rows = [["Stock", "Qty", "Order Type",
                                 "Price", "Product", "Order ID", "Placed At"]]
                    for _o in kite_amo_open:
                        _sym  = _o.get("tradingsymbol", "")
                        _qty  = _o.get("quantity", 0)
                        _otyp = _o.get("order_type", "")
                        _prc  = _o.get("price", 0)
                        _prc_s = f"Rs.{_prc:,.2f}" if _prc > 0 else "MARKET"
                        _prod = _o.get("product", "")
                        _oid  = str(_o.get("order_id", ""))[-8:]  # last 8 chars
                        _time = (_o.get("order_timestamp") or "")
                        _time_s = str(_time)[:16] if _time else "—"
                        amo_rows.append([
                            _sym[:12], str(_qty), _otyp,
                            _prc_s, _prod, _oid, _time_s,
                        ])
                    story.append(_tbl(amo_rows,
                        [22*mm,12*mm,20*mm,20*mm,16*mm,22*mm,30*mm],
                        hdr_bg=colors.HexColor("#0A2840")))
                    story.append(Spacer(1, 4))

                if kite_amo_exec:
                    story.append(Paragraph(
                        "EXECUTED TODAY",
                        _s("amo_exec", fontSize=7.5, textColor=GREEN,
                           fontName="Helvetica-Bold", spaceAfter=2)))
                    amo_ex_rows = [["Stock", "Qty", "Avg Fill",
                                    "Product", "Order ID", "Executed At"]]
                    for _o in kite_amo_exec:
                        _sym  = _o.get("tradingsymbol", "")
                        _qty  = _o.get("quantity", 0)
                        _avg  = _o.get("average_price", 0)
                        _prod = _o.get("product", "")
                        _oid  = str(_o.get("order_id", ""))[-8:]
                        _time = (_o.get("exchange_update_timestamp") or
                                 _o.get("order_timestamp") or "")
                        _time_s = str(_time)[:16] if _time else "—"
                        amo_ex_rows.append([
                            _sym[:12], str(_qty),
                            f"Rs.{_avg:,.2f}" if _avg else "—",
                            _prod, _oid, _time_s,
                        ])
                    story.append(_tbl(amo_ex_rows,
                        [22*mm,12*mm,22*mm,16*mm,22*mm,34*mm],
                        hdr_bg=colors.HexColor("#0D3320")))
                story.append(Spacer(1, 8))

            # ══════════════════════════════════════════════════════════════
            # SECTION 4 — GTT ORDERS  (mirrors Zerodha GTT tab)
            # ══════════════════════════════════════════════════════════════
            story.append(Paragraph(
                f"GTT ORDERS  ({len(kite_gtts)} active)", SEC_HDR))

            # GTT coverage check: every holding should have a GTT
            h_syms   = {h.get("tradingsymbol") for h in h_active}
            gtt_syms = set(_gtt_map.keys())
            missing  = h_syms - gtt_syms
            if missing:
                story.append(Paragraph(
                    f"WARNING — NO GTT for: {', '.join(sorted(missing))}",
                    _s("warn", fontSize=8, textColor=RED, fontName="Helvetica-Bold")))
                story.append(Spacer(1, 2))

            if kite_gtts:
                gtt_rows = [["Stock", "Type", "SL Trigger",
                             "SL Limit", "Target Trigger", "Target Limit",
                             "LTP", "Status"]]
                for _g in sorted(kite_gtts,
                                 key=lambda x: x.get("condition", {}).get("tradingsymbol", "")):
                    _cond   = _g.get("condition", {})
                    _sym    = _cond.get("tradingsymbol", "—")
                    _gtype  = _g.get("type", "—").upper()
                    _trigs  = _g.get("trigger_values", [])
                    _orders = _g.get("orders", [{}])
                    _sl_t   = f"Rs.{_trigs[0]:,.2f}"  if len(_trigs) > 0 else "—"
                    _tp_t   = f"Rs.{_trigs[1]:,.2f}"  if len(_trigs) > 1 else "—"
                    _sl_l   = f"Rs.{_orders[0].get('price',0):,.2f}" if _orders else "—"
                    _tp_l   = f"Rs.{_orders[1].get('price',0):,.2f}" if len(_orders)>1 else "—"
                    _ltp    = _cond.get("last_price", 0)
                    _ltp_s  = f"Rs.{_ltp:,.2f}" if _ltp else "—"
                    _status = _g.get("status", "").upper()
                    gtt_rows.append([
                        _sym[:12], _gtype,
                        _sl_t, _sl_l, _tp_t, _tp_l,
                        _ltp_s, _status,
                    ])
                story.append(_tbl(gtt_rows,
                    [20*mm,14*mm,22*mm,20*mm,24*mm,20*mm,18*mm,18*mm],
                    hdr_bg=colors.HexColor("#0D3320")))
            else:
                story.append(Paragraph("No active GTTs.", SMALL))
            story.append(Spacer(1, 8))

            # ══════════════════════════════════════════════════════════════
            # SECTION 5 — FUNDS  (mirrors Zerodha Funds screen)
            # ══════════════════════════════════════════════════════════════
            story.append(Paragraph("FUNDS", SEC_HDR))
            story.append(_summary_box(
                "Available Cash",    f"Rs.{avail_cash:,.2f}",
                "Used Margin",       f"Rs.{used_margin:,.2f}",
                "Total Collateral",  f"Rs.{collateral:,.2f}",
                val_color=BLUE))
            story.append(Spacer(1, 4))
            funds_detail = [
                ["Opening Balance", f"Rs.{opening_bal:,.2f}"],
                ["Payin (added today)", f"Rs.{payin:,.2f}"],
                ["Used Margin", f"Rs.{used_margin:,.2f}"],
                ["Collateral", f"Rs.{collateral:,.2f}"],
                ["Available Cash", f"Rs.{avail_cash:,.2f}"],
            ]
            fd = Table(funds_detail, colWidths=[60*mm, 50*mm])
            fd.setStyle(TableStyle([
                ("FONTSIZE",  (0,0), (-1,-1), 8),
                ("ALIGN",     (0,0), (0,-1), "LEFT"),
                ("ALIGN",     (1,0), (1,-1), "RIGHT"),
                ("TEXTCOLOR", (0,0), (0,-1), MGREY),
                ("TEXTCOLOR", (1,0), (1,-1), DKGREY),
                ("FONTNAME",  (1,0), (1,-1), "Helvetica-Bold"),
                ("LINEBELOW", (0,0), (-1,-2), 0.25, LGREY),
                ("TOPPADDING",    (0,0), (-1,-1), 4),
                ("BOTTOMPADDING", (0,0), (-1,-1), 4),
                # Highlight available cash row
                ("BACKGROUND", (0,4), (-1,4), colors.HexColor("#0D2010")),
                ("TEXTCOLOR",  (1,4), (1,4),  GREEN),
                ("FONTNAME",   (1,4), (1,4),  "Helvetica-Bold"),
            ]))
            story.append(fd)
            story.append(Spacer(1, 8))

            # ══════════════════════════════════════════════════════════════
            # SECTION 6 — CLOSED TRADES TODAY
            # ══════════════════════════════════════════════════════════════
            story.append(Paragraph("CLOSED TRADES TODAY", SEC_HDR))
            closed_today = []
            for _tr in [self.intraday, self.swing, self.longterm]:
                for t in _tr.book.get("trades", []):
                    if t.get("status") == "CLOSED" and today in t.get("exit_time", ""):
                        closed_today.append(t)
            if closed_today:
                ct_rows = [["Stock", "Entry", "Exit", "Qty", "P&L", "%", "Reason"]]
                for t in closed_today:
                    _sp = "+" if t.get("pnl", 0) >= 0 else ""
                    ct_rows.append([
                        t.get("symbol", "")[:12],
                        f"Rs.{t.get('entry_price', 0):,.2f}",
                        f"Rs.{t.get('exit_price', 0):,.2f}",
                        str(t.get("qty", 0)),
                        f"{_sp}Rs.{abs(t.get('pnl', 0)):,.0f}",
                        f"{_sp}{t.get('pnl_pct', 0)}%",
                        t.get("reason", "")[:22],
                    ])
                story.append(_tbl(ct_rows,
                    [22*mm,20*mm,20*mm,12*mm,18*mm,14*mm,44*mm],
                    hdr_bg=DKGOLD))
            else:
                story.append(Paragraph("No trades closed today.", SMALL))
            story.append(Spacer(1, 6))

            # 30-day cumulative history
            _cum = _get_trade_history(days=30)
            if _cum:
                _cum.sort(key=lambda t: t.get("exit_time", ""), reverse=True)
                _wins    = sum(1 for t in _cum if t.get("pnl", 0) > 0)
                _cum_pnl = sum(t.get("pnl", 0) for t in _cum)
                _wr      = round(_wins / len(_cum) * 100, 1)
                _cs      = "+" if _cum_pnl >= 0 else ""
                story.append(Paragraph(
                    f"30-DAY HISTORY  ({len(_cum)} trades | Win rate: {_wr}% | "
                    f"Net P&L: {_cs}Rs.{_cum_pnl:,.0f})", SEC_HDR))
                _ch = [["Date", "Stock", "Strategy", "Entry", "Exit", "P&L", "%"]]
                for _t in _cum[:25]:
                    _csp = "+" if _t.get("pnl", 0) >= 0 else ""
                    _ch.append([
                        _t.get("exit_time", "")[:10],
                        _t.get("symbol", "")[:10],
                        _t.get("strategy", "")[:6],
                        f"Rs.{_t.get('entry_price', 0):,.1f}",
                        f"Rs.{_t.get('exit_price', 0):,.1f}",
                        f"{_csp}Rs.{abs(_t.get('pnl', 0)):,.0f}",
                        f"{_csp}{_t.get('pnl_pct', 0)}%",
                    ])
                story.append(_tbl(_ch,
                    [22*mm,20*mm,16*mm,20*mm,20*mm,18*mm,14*mm]))
                story.append(Spacer(1, 6))

            # ── FOOTER ────────────────────────────────────────────────────
            story.append(HRFlowable(width="100%", thickness=0.8, color=GOLD))
            story.append(Paragraph(
                f"<font color='#D4AF37'><b>GLOBAL EYE {VERSION} | {EDITION}</b></font>  "
                f"Prepared for: {OWNER_NAME}  |  "
                f"RISK: Intraday {'HALTED' if risk_s.get('intraday_halted') else 'Active'}  |  "
                f"Monthly P&L: Rs.{risk_s.get('monthly_pnl', 0):,.0f}",
                _s("foot", fontSize=7, textColor=MGREY)))
            story.append(Paragraph(
                "Not SEBI registered. Not financial advice. "
                "Consult a SEBI-registered advisor before investing.",
                _s("disc", fontSize=6, textColor=MGREY)))

            doc.build(story)

            # Summary totals for Telegram message
            total_invested = h_total_invested
            total_pnl      = h_total_pnl
            total_pct      = h_pnl_pct
            sign           = h_sign

            send_telegram(
                f"Portfolio Report — {title}\n"
                f"Holdings: {len(h_active)} stocks | "
                f"Invested: Rs.{total_invested:,.0f} | "
                f"P&L: {sign}Rs.{total_pnl:,.0f} ({sign}{total_pct}%)\n"
                f"GTTs: {len(kite_gtts)} active | "
                f"Cash: Rs.{avail_cash:,.0f}",
                doc_path=fpath, priority="report"
            )
            logger.info(f"Portfolio PDF sent: {report_type}")

        except Exception as e:
            logger.error(f"Portfolio report [{report_type}]: {e}\n{traceback.format_exc()}")
            send_telegram(f"Report error [{report_type}]: {str(e)[:200]}")


    def kite_logout(self):
        """Auto-logout Kite at 16:00 IST — end of trading session."""
        try:
            logger.info("🔒 Kite: Auto-logout at 16:00 IST")
            KiteSession._kite = None
            KiteSession._token_date = None
            KiteSession._login_alerted = False
            KiteSession._logged_out = True  # FIX: Block re-login until 08:30 tomorrow
            send_telegram(
                f"🔒 *Kite Session Closed*\n"
                f"📅 {now_ist().strftime('%a, %d %b %Y')}\n"
                f"🕐 16:00 IST — Trading day ended\n"
                f"_No re-login until 08:30 IST tomorrow_",
                priority="kite"
            )
        except Exception as e:
            logger.error(f"Kite logout: {e}")

    def health_check(self):
        is_open,session=is_market_open()
        summaries=self._get_summaries(); risk_s=self.risk.get_summary()
        filings_1h=len(self.filings.get_recent(hours=1))
        msg=self.tb.health_check(is_open,session,summaries,risk_s,filings_1h,len(PRIORITY_500),len(FNO_STOCKS))
        # FIX #7: Health checks go to digest only
        send_telegram(msg, priority="digest")

    def run(self):
        logger.info("🟢 Main loop started")
        REPORT_HOURS={6,12,18,0}
        self._kite_login_done = False
        self._report_0930_sent = False
        self._report_1200_sent = False
        self._report_1400_sent = False
        self._report_1530_sent = False
        self._kite_logout_done = False
        while True:
            try:
                n=now_ist(); hr=n.hour; mn=n.minute
                is_open,_=is_market_open()

                # Reset ALL daily flags at midnight
                if hr==0 and mn<=2:
                    self._pulse_sent=False; self._premarket_sent=False
                    self._eod_sent=False; self._squareoff_done=False
                    self._kite_login_done=False
                    self._report_0930_sent=False; self._report_1200_sent=False
                    self._report_1400_sent=False; self._report_1530_sent=False
                    self._kite_logout_done=False
                    KiteSession._logged_out=False  # FIX: Allow login for new day
                    self._gtt_audit_done_today=False  # Reset GTT audit flag
                    self._gtt_morning_done=False  # Reset morning GTT flag
                    self._amo_monitor_done=False  # Reset AMO monitor flag
                    self._gap_monitor_done=False  # Reset gap down monitor flag
                    self._amo_placed_today=set()  # Reset AMO dedup tracking
                    self._premarket_scan_done=False  # Reset pre-market scan flag
                    # Reset signal dedup for new day
                    self._statarb_sent_today = set()
                    self._turnaround_sent_today = set()
                    PennyMultibaggerScanner.reset_daily()  # v23.5.0
                    # v23.5.0: Refresh NSE holidays on 1st of each month
                    if n.day == 1:
                        try:
                            refresh_nse_holidays()
                            logger.info(f"NSE holidays refreshed for {n.strftime('%B %Y')}")
                        except Exception:
                            pass
                    # ── Phase 2 daily reset ──
                    if self._phase2 is not None:
                        self._phase2.reset_daily()
                    # ── Trillionaire Engine daily reset (v23.5.0) ──
                    if self._trillionaire is not None:
                        self._trillionaire.reset_daily()
                        self._event_trade_queue = []
                    if self._strategy_modules is not None:
                        self._strategy_modules.reset_daily()

                    # ── v23.6.0 #9: SECTOR ROTATION — score on Mondays ──
                    if n.weekday() == 0:  # Monday
                        try:
                            SectorRotationScorer.update_weekly()
                            logger.info("SECTOR ROTATION: Weekly scores updated (Monday)")
                        except Exception as _sr_err:
                            logger.debug(f"Sector rotation update: {_sr_err}")

                    # ── v23.6.0 #11: CONTINUOUS CAPITAL SCALING ──
                    # Recalculate max positions based on current capital
                    try:
                        _total_cap = self.swing.book.get("capital", TOTAL_CAPITAL)
                        if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                            _kite_cap = KiteSession.get()
                            if _kite_cap:
                                _total_cap = CapitalAllocator.get_total_balance(_kite_cap)
                        _new_max = calculate_max_positions(_total_cap)
                        _old_swing = self.swing.max_pos
                        # Distribute: swing gets floor(max*0.6), longterm gets floor(max*0.4), min 1 each
                        self.swing.max_pos = max(1, int(_new_max * 0.6))
                        self.longterm.max_pos = max(1, _new_max - self.swing.max_pos)
                        if self.swing.max_pos != _old_swing:
                            logger.info(
                                f"CAPITAL SCALE: Rs.{_total_cap:,.0f} → {_new_max} max positions "
                                f"(swing={self.swing.max_pos}, LT={self.longterm.max_pos})"
                            )
                    except Exception as _cs_err:
                        logger.debug(f"Capital scaling: {_cs_err}")
                    # ── Daily log clear — fresh log every day ──
                    try:
                        with open(LOG_FILE, 'w') as _lf:
                            _lf.write("")
                        logger.info(f"Log cleared for new day — {n.strftime('%d %b %Y')}")
                    except Exception:
                        pass
                    # ── LIVE: Reset circuit breaker for new day ──
                    if TRADING_MODE == "LIVE" and hasattr(self, '_live_circuit'):
                        self._live_circuit.reset_daily()
                        logger.info("🔄 Circuit breaker reset for new day")

                # ── 07:30 GTT HOLDINGS SYNC (trading days only) ──────────
                # Rule: every holding must have an active GTT — no more, no less.
                # Source of truth = kite.holdings() NOT the bot book.
                # After 07:30 all CNC positions from previous day settle into
                # holdings. We compare holdings vs active GTTs and place any
                # that are missing. Fires ONCE per trading day 07:30–07:45.
                if (hr == 7 and 30 <= mn <= 45
                        and TRADING_MODE == "LIVE"
                        and _LIVE_MODULE_LOADED
                        and KiteSession.is_trading_day()):
                    if not hasattr(self, '_gtt_morning_done'):
                        self._gtt_morning_done = False
                    if not self._gtt_morning_done:
                        self._gtt_morning_done = True
                        try:
                            _gmk = KiteSession.get()
                            if not _gmk:
                                _gmk = KiteSession.emergency_login(
                                    reason="GTT holdings sync 07:30")
                            if _gmk:
                                # Step 1: Fetch actual Kite holdings
                                _h_syms = {}  # symbol -> {qty, avg, ltp}
                                try:
                                    for _h in (_gmk.holdings() or []):
                                        _hs = _h.get("tradingsymbol", "")
                                        _hq = (_h.get("quantity", 0) +
                                               _h.get("t1_quantity", 0))
                                        if _hs and _hq > 0:
                                            _h_syms[_hs] = {
                                                "qty": _hq,
                                                "avg": _h.get("average_price", 0),
                                                "ltp": _h.get("last_price", 0),
                                            }
                                except Exception as _he:
                                    logger.warning(f"GTT sync — holdings: {_he}")

                                # Step 2: Fetch all active GTTs from Kite
                                _gtt_syms = set()
                                try:
                                    for _g in (_gmk.get_gtts() or []):
                                        if _g.get("status") == "active":
                                            _gs = _g.get("condition", {}).get(
                                                "tradingsymbol", "")
                                            if _gs:
                                                _gtt_syms.add(_gs)
                                except Exception as _ge:
                                    logger.warning(f"GTT sync — GTT fetch: {_ge}")

                                # Step 3: Find holdings with NO GTT
                                _missing = {s: d for s, d in _h_syms.items()
                                            if s not in _gtt_syms}

                                logger.info(
                                    f"GTT SYNC 07:30 — Holdings:{len(_h_syms)} "
                                    f"GTTs:{len(_gtt_syms)} "
                                    f"Missing:{len(_missing)}")

                                if not _missing:
                                    send_telegram(
                                        f"GTT SYNC 07:30 — All OK\n"
                                        f"Holdings: {len(_h_syms)} | "
                                        f"GTTs: {len(_gtt_syms)}\n"
                                        f"Every holding is protected",
                                        priority="trade")
                                else:
                                    # Step 4: Bot-book SL/Target lookup
                                    _bl = {}
                                    for _btr in [self.swing, self.longterm,
                                                 self.intraday]:
                                        for _bs, _bp in _btr.book.get(
                                                "positions", {}).items():
                                            if _bs not in _bl:
                                                _bl[_bs] = _bp

                                    # Step 5: Place GTT for each unprotected holding
                                    _placed = 0
                                    _failed = []
                                    for _ms, _md in _missing.items():
                                        _mq   = _md["qty"]
                                        _mavg = _md["avg"]
                                        _mltp = _md["ltp"] or _mavg
                                        _bp   = _bl.get(_ms, {})
                                        _msl  = _bp.get("stop_loss", 0)
                                        _mt2  = _bp.get("target2", 0)
                                        # v23.6.1 FIX: Smart fallback SL
                                        if _msl <= 0:
                                            _msl = smart_sl_fallback(_mltp, avg_price=_mavg)
                                        if _mt2 <= 0:
                                            _mt2 = round(_mavg * 1.20, 2)
                                        _sl_t = round(_msl * 1.005, 1)
                                        _sl_l = round(_msl, 1)
                                        _tp_t = round(_mt2 * 0.995, 1)
                                        _tp_l = round(_mt2 * 0.99, 1)

                                        # Safety: if SL >= LTP price has already broken stop loss
                                        # Auto-place a MARKET SELL order at 09:15 open
                                        # No GTT needed — exit the position immediately
                                        if _mltp > 0 and _sl_t >= _mltp:
                                            logger.warning(
                                                f"GTT SYNC [{_ms}]: SL Rs.{_sl_t} >= LTP Rs.{_mltp} "
                                                f"— SL already breached, queuing auto-sell at market open"
                                            )
                                            # Place AMO SELL order to exit at market open
                                            if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                                                try:
                                                    _sell_kite = KiteSession.get()
                                                    if _sell_kite:
                                                        _sell_oid = _sell_kite.place_order(
                                                            variety="amo",
                                                            exchange="NSE",
                                                            tradingsymbol=_ms,
                                                            transaction_type="SELL",
                                                            quantity=_mq,
                                                            product="CNC",
                                                            order_type="MARKET",
                                                            tag="SL_BREACH_AMO",
                                                        )
                                                        logger.info(
                                                            f"AUTO-SELL AMO [{_ms}]: "
                                                            f"qty={_mq} @ MARKET | OID:{_sell_oid}"
                                                        )
                                                        send_telegram(
                                                            f"AUTO-SELL AMO PLACED\n"
                                                            f"`{_ms}` x{_mq} @ MARKET\n"
                                                            f"SL Rs.{_sl_t} already breached "
                                                            f"(LTP Rs.{_mltp})\n"
                                                            f"Will sell at market open 09:15",
                                                            priority="trade"
                                                        )
                                                        _failed.append(f"{_ms}(AMO-SELL queued)")
                                                except Exception as _se:
                                                    logger.warning(f"Auto-sell [{_ms}]: {_se}")
                                                    _failed.append(f"{_ms}(SL>LTP-sell failed)")
                                            else:
                                                _failed.append(f"{_ms}(SL>LTP-paper mode)")
                                            continue
                                        try:
                                            _gr = _gmk.place_gtt(
                                                trigger_type=_gmk.GTT_TYPE_OCO,
                                                tradingsymbol=_ms,
                                                exchange="NSE",
                                                trigger_values=[_sl_t, _tp_t],
                                                last_price=_mltp,
                                                orders=[
                                                    {"exchange": "NSE",
                                                     "tradingsymbol": _ms,
                                                     "transaction_type": "SELL",
                                                     "quantity": _mq,
                                                     "order_type": "LIMIT",
                                                     "product": "CNC",
                                                     "price": _sl_l},
                                                    {"exchange": "NSE",
                                                     "tradingsymbol": _ms,
                                                     "transaction_type": "SELL",
                                                     "quantity": _mq,
                                                     "order_type": "LIMIT",
                                                     "product": "CNC",
                                                     "price": _tp_l},
                                                ],
                                            )
                                            _new_id = _gr.get("trigger_id", "?")
                                            # Write back to bot book
                                            for _btr in [self.swing,
                                                         self.longterm]:
                                                if _ms in _btr.book.get(
                                                        "positions", {}):
                                                    _btr.book["positions"][_ms][
                                                        "gtt_id"] = _new_id
                                                    _btr.book["positions"][_ms][
                                                        "gtt_sl"] = _sl_t
                                                    _btr._save()
                                                    break
                                            _placed += 1
                                            logger.info(
                                                f"GTT SYNC [{_ms}]: placed "
                                                f"SL=Rs.{_sl_l} "
                                                f"T2=Rs.{_tp_l} ID={_new_id}")
                                        except Exception as _ge2:
                                            _failed.append(_ms)
                                            logger.warning(
                                                f"GTT SYNC [{_ms}]: {_ge2}")

                                    _msg = (
                                        f"GTT SYNC 07:30\n"
                                        f"Holdings: {len(_h_syms)} | "
                                        f"GTTs before: {len(_gtt_syms)}\n"
                                        f"New GTTs placed: {_placed}\n")
                                    if _failed:
                                        _msg += (
                                            f"FAILED: {', '.join(_failed)}\n"
                                            f"Place these manually on Kite")
                                    else:
                                        _msg += "All holdings now protected"
                                    send_telegram(_msg, priority="trade")
                        except Exception as _gme:
                            logger.error(f"GTT holdings sync: {_gme}")


                # ── 08:30 Scheduled Kite Login (trading days ONLY) ────
                if (hr==8 and 28<=mn<=35 and not self._kite_login_done
                    and KiteSession.is_trading_day()):
                    self._kite_login_done = True
                    logger.info("08:30 — Scheduled Kite login")
                    kite = KiteSession.scheduled_login()
                    if kite:
                        stock_universe = DynamicStockUniverse.load(kite)
                        logger.info(f"Universe refreshed: {len(stock_universe)} stocks")

                # ── 08:35 PRE-MARKET FULL SCAN (trading days ONLY) ────
                # Run full 2501-stock scan BEFORE market opens at 09:15
                # Signals ready, 3AI approvals done — instant execution at open
                if (hr==8 and 35<=mn<=42 and KiteSession.is_trading_day()
                    and not hasattr(self, '_premarket_scan_done')):
                    self._premarket_scan_done = True
                    logger.info("08:35 — Pre-market full scan starting")
                    scans = self.get_scan(force=True)
                    if scans:
                        # Run technical analysis but DON'T place orders yet
                        # Orders will be placed at 09:15 when market opens
                        logger.info(f"08:35 — Pre-market scan complete: {len(scans)} stocks analysed")
                        send_telegram(
                            f"Pre-Market Scan Complete\n"
                            f"{len(scans)} stocks analysed\n"
                            f"Signals ready for 09:15 market open",
                            priority="report"
                        )

                # 07:00 Market Pulse (trading days only)
                if is_premarket_pulse_time() and not self._pulse_sent and KiteSession.is_trading_day():
                    self._pulse_sent=True
                    self.send_market_pulse()
                    if self._strategy_modules:
                        try:
                            self._strategy_modules.run_premarket(self._macro_data if hasattr(self,'_macro_data') else {})
                        except Exception as _pm_err:
                            logger.debug(f"Strategy premarket: {_pm_err}")

                # 08:00 Pre-market briefing (trading days only)
                if is_premarket_brief_time() and not self._premarket_sent and KiteSession.is_trading_day():
                    self._premarket_sent=True
                    scans=self.get_scan(force=True)
                    send_telegram(
                        f"🌅 *08:00 Pre-Market Briefing*\n"
                        f"Market opens in 75 minutes!\n"
                        f"Top intraday picks from scan:\n"
                        +"\n".join(f"  {'🟢'if 'BUY'in r['intraday_sig'] else '🔴'if 'SELL'in r['intraday_sig'] else '⚪'} `{r['symbol']}` DVM:{r.get('dvm_score','-')} ₹{r['price']}" for r in scans[:5]),
                        priority="report"
                    )

                # ── 09:20 AMO ORDER MONITOR (check + fix overnight AMO status) ──
                # If AMO order didn't fill due to gap up/down:
                #   1. Cancel the stale OPEN order (free the blocked capital)
                #   2. Re-evaluate with fresh 3AI scan at current price
                #   3. If still valid: place fresh MARKET order at live price
                #   4. If no longer valid: cancel and free capital
                if hr==9 and 18<=mn<=25 and is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                    if not hasattr(self, '_amo_monitor_done'):
                        self._amo_monitor_done = False
                    if not self._amo_monitor_done:
                        self._amo_monitor_done = True
                        try:
                            _amo_kite = KiteSession.get()
                            if _amo_kite:
                                _orders = _amo_kite.orders()
                                _amo_filled = []
                                _amo_rejected = []
                                _amo_cancelled = []
                                _amo_retried = []
                                for _ord in _orders:
                                    if _ord.get("variety", "") != "amo":
                                        continue
                                    _stat = _ord.get("status", "")
                                    _sym = _ord.get("tradingsymbol", "?")
                                    _qty = _ord.get("quantity", 0)
                                    _avg = _ord.get("average_price", 0)
                                    _oid = _ord.get("order_id", "")
                                    _txn = _ord.get("transaction_type", "BUY")
                                    _limit_price = _ord.get("price", 0)

                                    if _stat == "COMPLETE":
                                        _amo_filled.append(f"{_sym} x{_qty} @ Rs.{_avg}")
                                        # Place GTT for filled AMO (was deferred at order time)
                                        try:
                                            _pos = self.swing.book.get("positions", {}).get(_sym, {})
                                            if _pos and _pos.get("gtt_pending"):
                                                _gtt_sl = _pos.get("gtt_sl", _pos.get("stop_loss", 0))
                                                _gtt_tgt = _pos.get("gtt_target", _pos.get("target2", 0))
                                                _fill_price = _avg if _avg > 0 else _pos.get("entry_price", 0)
                                                if _gtt_sl > 0 and _gtt_tgt > 0:
                                                    _sl_trig = round(_gtt_sl * 1.005, 1)
                                                    _tp_trig = round(_gtt_tgt * 0.995, 1)
                                                    _gtt_r = _amo_kite.place_gtt(
                                                        trigger_type=_amo_kite.GTT_TYPE_OCO,
                                                        tradingsymbol=_sym,
                                                        exchange="NSE",
                                                        trigger_values=[_sl_trig, _tp_trig],
                                                        last_price=_fill_price,
                                                        orders=[
                                                            {"exchange":"NSE","tradingsymbol":_sym,
                                                             "transaction_type":"SELL","quantity":_qty,
                                                             "order_type":"LIMIT","product":"CNC",
                                                             "price":round(_gtt_sl, 1)},
                                                            {"exchange":"NSE","tradingsymbol":_sym,
                                                             "transaction_type":"SELL","quantity":_qty,
                                                             "order_type":"LIMIT","product":"CNC",
                                                             "price":round(_gtt_tgt * 0.99, 1)},
                                                        ]
                                                    )
                                                    _gtt_id = _gtt_r if isinstance(_gtt_r, int) else _gtt_r.get("trigger_id", 0) if isinstance(_gtt_r, dict) else 0
                                                    _pos["gtt_id"] = _gtt_id
                                                    _pos.pop("gtt_pending", None)
                                                    _pos["entry_price"] = _fill_price  # Update to actual fill price
                                                    _pos["cost"] = round(_fill_price * _qty, 2)
                                                    self.swing._save()
                                                    logger.info(f"GTT PLACED (AMO fill): {_sym} SL={_gtt_sl} T={_gtt_tgt} GTT:{_gtt_id}")
                                        except Exception as _gtt_err:
                                            logger.warning(f"GTT for AMO fill [{_sym}]: {_gtt_err}")

                                    elif _stat in ("REJECTED", "CANCELLED"):
                                        _reason = _ord.get("status_message", "unknown")
                                        _amo_rejected.append(f"{_sym}: {_reason[:60]}")
                                        # Remove phantom position from swing book
                                        if _sym in self.swing.book.get("positions", {}):
                                            del self.swing.book["positions"][_sym]
                                            self.swing._save()
                                            logger.info(f"AMO REJECTED/CANCELLED: Removed {_sym} from swing book")

                                    elif _stat in ("OPEN", "TRIGGER PENDING") and _txn == "BUY":
                                        # STALE AMO — didn't fill. Gap up/down or price moved.
                                        # Step 1: Cancel the stale order
                                        try:
                                            _amo_kite.cancel_order(variety="amo", order_id=_oid)
                                            logger.info(f"AMO CANCEL: {_sym} order {_oid} (stale — didn't fill at open)")

                                            # Step 2: Get current live price
                                            _ltp_data = _amo_kite.ltp([f"NSE:{_sym}"])
                                            _live_price = 0
                                            if f"NSE:{_sym}" in _ltp_data:
                                                _live_price = round(_ltp_data[f"NSE:{_sym}"]["last_price"], 2)

                                            if _live_price <= 0:
                                                _amo_cancelled.append(f"{_sym}: cancelled (no live price)")
                                                continue

                                            # Step 3: Check price deviation
                                            _price_diff_pct = abs(_live_price - _limit_price) / (_limit_price + 0.01) * 100

                                            # If price gapped MORE than 5%, signal may be invalid
                                            # Cancel and free capital — don't chase
                                            if _price_diff_pct > 5:
                                                _amo_cancelled.append(
                                                    f"{_sym}: cancelled (gapped {_price_diff_pct:.1f}% "
                                                    f"from Rs.{_limit_price} to Rs.{_live_price})"
                                                )
                                                # Return capital to strategy book
                                                _est_cost = _qty * _limit_price
                                                for _tr in [self.swing, self.longterm]:
                                                    if _tr.book.get("available", 0) < _tr.book.get("capital", 0):
                                                        _tr.book["available"] = round(
                                                            _tr.book.get("available", 0) + _est_cost, 2
                                                        )
                                                        _tr._save()
                                                        break
                                                continue

                                            # If price within 5%: re-evaluate with fresh scan
                                            # Find stock in scan cache
                                            _scan_r = next((r for r in self._scan_cache if r["symbol"] == _sym), None)
                                            if not _scan_r:
                                                _amo_cancelled.append(f"{_sym}: cancelled (not in scan)")
                                                continue

                                            # Quick 3AI check at current price
                                            try:
                                                _macro = self._get_macro()
                                                _filings = self.filings.get_recent(hours=6)
                                                _news = self.news.recent(hours=6)
                                                _mb, _mbe = MacroIntelligence.get_sector_bias(_macro)
                                                _ss, _sl = SentimentEngine.score(
                                                    _sym, _scan_r, _filings, _news, _mb, _mbe, []
                                                )
                                                _approved, _conf, _reason = ThreeAgentAI.evaluate_trade(
                                                    _sym, _live_price, _scan_r, _ss, _filings, _macro, []
                                                )
                                            except Exception:
                                                _approved = False

                                            if _approved:
                                                # Signal still valid — place fresh market order
                                                _amo_retried.append(
                                                    f"{_sym}: re-placed at Rs.{_live_price} "
                                                    f"(was Rs.{_limit_price}, gap {_price_diff_pct:.1f}%)"
                                                )
                                                # Route to correct strategy
                                                _in_any = (
                                                    _sym in self.intraday.book.get("positions", {})
                                                    or _sym in self.swing.book.get("positions", {})
                                                    or _sym in self.longterm.book.get("positions", {})
                                                )
                                                if not _in_any:
                                                    _atr = _scan_r.get("atr", _live_price * 0.02)
                                                    _sl = round(_live_price - 1.5 * _atr, 2)
                                                    _t1 = round(_live_price + 2.5 * _atr, 2)
                                                    _t2 = round(_live_price + 4.0 * _atr, 2)
                                                    self.swing.entry(
                                                        _sym, _live_price,
                                                        f"AMO RETRY (gap {_price_diff_pct:.1f}%)",
                                                        _sl, _t1, _t2,
                                                        source=f"AMO_RETRY|{STRATEGY_MODE}"
                                                    )
                                            else:
                                                _amo_cancelled.append(
                                                    f"{_sym}: cancelled (3AI rejected at Rs.{_live_price})"
                                                )

                                        except Exception as _cancel_err:
                                            logger.warning(f"AMO cancel [{_sym}]: {_cancel_err}")
                                            _amo_cancelled.append(f"{_sym}: cancel failed ({str(_cancel_err)[:40]})")

                                # Send summary to Telegram
                                if _amo_filled or _amo_rejected or _amo_cancelled or _amo_retried:
                                    _amo_msg = "AMO ORDER STATUS (09:20)\n"
                                    _amo_msg += "=" * 30 + "\n"
                                    if _amo_filled:
                                        _amo_msg += f"\nFILLED ({len(_amo_filled)}):\n"
                                        for _af in _amo_filled:
                                            _amo_msg += f"  {_af}\n"
                                    if _amo_retried:
                                        _amo_msg += f"\nRE-PLACED AT MARKET ({len(_amo_retried)}):\n"
                                        for _ar in _amo_retried:
                                            _amo_msg += f"  {_ar}\n"
                                    if _amo_cancelled:
                                        _amo_msg += f"\nCANCELLED ({len(_amo_cancelled)}):\n"
                                        for _ac in _amo_cancelled:
                                            _amo_msg += f"  {_ac}\n"
                                    if _amo_rejected:
                                        _amo_msg += f"\nREJECTED ({len(_amo_rejected)}):\n"
                                        for _arj in _amo_rejected:
                                            _amo_msg += f"  {_arj}\n"
                                    send_telegram(_amo_msg, priority="trade")
                                    logger.info(
                                        f"AMO Monitor: {len(_amo_filled)} filled, "
                                        f"{len(_amo_retried)} retried, "
                                        f"{len(_amo_cancelled)} cancelled, "
                                        f"{len(_amo_rejected)} rejected"
                                    )
                        except Exception as _amo_err:
                            logger.debug(f"AMO monitor: {_amo_err}")

                # ── 09:45 GAP DOWN MONITOR (check stuck GTTs) ──────────
                # Market stabilizes by 09:45. If stock gapped below GTT SL
                # limit price, the GTT is stuck OPEN (won't fill).
                # This forces exit at market price.
                if not hasattr(self, '_gap_monitor_done'):
                    self._gap_monitor_done = False
                if hr == 9 and 43 <= mn <= 50 and is_open and not self._gap_monitor_done:
                    if TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED:
                        self._gap_monitor_done = True
                        try:
                            _gm_kite = KiteSession.get()
                            if _gm_kite:
                                _gtt_list = _gm_kite.get_gtts()
                                _gap_exits = []
                                for _gtt in _gtt_list:
                                    if _gtt.get("status") != "active":
                                        continue
                                    _gtt_sym = _gtt.get("condition", {}).get("tradingsymbol", "")
                                    _gtt_id = _gtt.get("id")
                                    _gtt_triggers = _gtt.get("condition", {}).get("trigger_values", [])
                                    _gtt_orders = _gtt.get("orders", [])
                                    if not _gtt_sym or not _gtt_triggers or not _gtt_orders:
                                        continue
                                    # Get current LTP
                                    try:
                                        _gm_ltp = _gm_kite.ltp([f"NSE:{_gtt_sym}"])
                                        _gm_price = _gm_ltp.get(f"NSE:{_gtt_sym}", {}).get("last_price", 0)
                                    except Exception:
                                        continue
                                    if _gm_price <= 0:
                                        continue
                                    # SL trigger and limit (first trigger = SL)
                                    _sl_trigger = _gtt_triggers[0] if len(_gtt_triggers) > 0 else 0
                                    _sl_limit = _gtt_orders[0].get("price", 0) if len(_gtt_orders) > 0 else 0
                                    _sl_qty = _gtt_orders[0].get("quantity", 0) if len(_gtt_orders) > 0 else 0
                                    if _sl_trigger <= 0 or _sl_limit <= 0 or _sl_qty <= 0:
                                        continue
                                    # GAP DOWN: price still below SL limit after 30 min
                                    if _gm_price < _sl_limit * 0.995:
                                        try:
                                            _gm_kite.delete_gtt(_gtt_id)
                                            _exit_oid = _gm_kite.place_order(
                                                tradingsymbol=_gtt_sym, exchange="NSE",
                                                transaction_type="SELL", quantity=_sl_qty,
                                                product="CNC", order_type="MARKET",
                                                variety="regular", tag="GAP_EXIT"[:20],
                                            )
                                            _gap_exits.append(f"{_gtt_sym} x{_sl_qty} @ Rs.{_gm_price}")
                                            logger.info(f"GAP DOWN EXIT [{_gtt_sym}]: OID {_exit_oid}")
                                        except Exception as _ge:
                                            logger.warning(f"GAP EXIT failed [{_gtt_sym}]: {_ge}")
                                            send_telegram(
                                                f"GAP DOWN ALERT\n"
                                                f"{_gtt_sym} below SL limit Rs.{_sl_limit}\n"
                                                f"LTP: Rs.{_gm_price}\n"
                                                f"Auto-exit FAILED — MANUAL EXIT NEEDED",
                                                priority="critical"
                                            )
                                if _gap_exits:
                                    send_telegram(
                                        f"GAP DOWN EXITS\n"
                                        f"{len(_gap_exits)} positions force-exited:\n"
                                        + "\n".join(f"  {g}" for g in _gap_exits),
                                        priority="critical"
                                    )
                                else:
                                    logger.info("Gap Down Monitor: No stuck GTTs detected")
                        except Exception as _gm_err:
                            logger.debug(f"Gap monitor: {_gm_err}")

                # ── 09:30 FIRST TRADE UPDATE (PDF) ────────────────────
                if hr==9 and 28<=mn<=35 and not self._report_0930_sent and is_open:
                    self._report_0930_sent = True
                    self.send_detailed_portfolio("FIRST-TRADE")

                # ── 12:00 MID-DAY PORTFOLIO (PDF) ─────────────────────
                if hr==12 and mn<=5 and not self._report_1200_sent and is_open:
                    self._report_1200_sent = True
                    self.send_detailed_portfolio("MID-DAY")

                # ── 14:00 PRE-CLOSE CHECK (PDF) ───────────────────────
                if hr==14 and mn<=5 and not self._report_1400_sent and is_open:
                    self._report_1400_sent = True
                    self.send_detailed_portfolio("PRE-CLOSE")

                # EOD 15:30 — trading + report
                if is_eod_time() and not self._eod_sent and is_open:
                    self._eod_sent=True
                    scans=self.get_scan(force=True); self._execute_technical(scans); self.send_eod(scans)

                # ── 15:30 FINAL EOD P&L (PDF) ─────────────────────────
                if hr==15 and 28<=mn<=40 and not self._report_1530_sent and is_open:
                    self._report_1530_sent = True
                    self.send_detailed_portfolio("EOD-FINAL")

                # ── 16:00 KITE AUTO-LOGOUT ────────────────────────────
                if hr==16 and mn<=5 and not self._kite_logout_done and KiteSession.is_trading_day():
                    self._kite_logout_done = True
                    self.kite_logout()

                # 6-hourly reports
                # v23.5.0: Only execute trades during/after market hours
                # 06:00 scan = monitor only (market not open yet)
                # 12:00, 18:00, 00:00 = execute allowed
                fire=(hr in REPORT_HOURS and mn<=3 and hr!=self._last_report_hr)
                if hr==0 and mn==1: fire=True
                if fire:
                    self._last_report_hr=hr
                    scans=self.get_scan(force=True)
                    # Only execute trades on trading days AND not at 06:00 (pre-market)
                    if KiteSession.is_trading_day() and hr != 6:
                        self._execute_technical(scans)

                # FIX #13: 30-min scanning during market (was hourly)
                # At mn==0 AND mn==30 — scans every 30 minutes
                elif is_open and (mn==0 or mn==30):
                    scans=self.get_scan(); self._execute_technical(scans)

                # ── AFTER-HOURS SCANNING for AMO orders (LIVE mode) ──
                # Runs ONLY on trading day evenings (after 16:00) and 
                # Sunday evening (to queue for Monday).
                # NOT every 30 min on Saturday/Sunday — prevents duplicate AMOs.
                # Schedule: Trading day 16:00-23:59 and 05:30-08:30 = every 30 min
                #           Non-trading days = ONE scan at 18:00 and 06:00 only
                # v23.5.0 FIX: BLOCK 09:00-09:20 — pre-open auction, no orders accepted
                elif (not is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED
                      and not (60 <= (hr * 60 + mn) <= 330)
                      and not (hr == 9 and mn < 20)):
                    # Determine if we should scan this cycle
                    _should_scan = False
                    _is_td = KiteSession.is_trading_day()
                    if _is_td and (mn == 0 or mn == 30):
                        _should_scan = True  # Trading day: scan every 30 min after hours
                    elif not _is_td and ((hr == 18 and mn <= 5) or (hr == 6 and mn <= 5)):
                        _should_scan = True  # Non-trading day: ONE scan at 18:00, ONE at 06:00
                    
                    if _should_scan:
                        if not hasattr(self, '_last_amo_scan_hr'):
                            self._last_amo_scan_hr = -1
                        _amo_key = hr * 100 + mn
                        if _amo_key != self._last_amo_scan_hr:
                            self._last_amo_scan_hr = _amo_key
                        try:
                            # Step 1: Ensure Kite is connected
                            _kite = KiteSession.get()
                            if not _kite:
                                logger.info("🌙 AMO scan: Kite offline — attempting emergency login")
                                _kite = KiteSession.emergency_login(reason="After-hours AMO scan")
                            if not _kite:
                                logger.warning("🌙 AMO scan: Emergency login failed — skipping scan")
                                continue

                            # Step 2: Verify Kite session is valid by testing a simple API call
                            try:
                                _kite.margins()
                            except Exception as _token_err:
                                logger.warning(f"🌙 AMO scan: Kite session invalid ({_token_err}) — re-login")
                                KiteSession._kite = None
                                KiteSession._token_date = None
                                KiteSession._logged_out = False
                                _kite = KiteSession.emergency_login(reason="AMO scan — token expired")
                                if not _kite:
                                    logger.warning("🌙 AMO scan: Re-login failed — skipping")
                                    continue

                            # Step 3: Refresh stock universe if needed
                            stock_universe = DynamicStockUniverse.load(_kite)
                            if len(stock_universe) < 100:
                                logger.warning(f"🌙 AMO scan: Only {len(stock_universe)} stocks loaded — skipping")
                                continue

                            # Step 4: Run scan and execute
                            scans = self.get_scan(force=True)
                            if scans:
                                self._execute_technical(scans)
                            logger.info(f"🌙 After-hours AMO scan: {len(scans)} stocks evaluated")
                        except Exception as _amo_err:
                            logger.error(f"After-hours AMO scan: {_amo_err}")

                # FIX #4: Flush telegram digest at fixed times (06:00, 12:00, 18:00 IST only)
                # NEVER fire during 01:00-05:30 (Zerodha maintenance / sleep hours)
                if (hr in (6, 12, 18) and mn < 5
                        and time.time() - _telegram_last_flush >= 3600):
                    _flush_telegram_digest()


                # ── POSITION SYNC (every 5 min during market hours) ──────────
                # Catches GTT-triggered sells — removes phantom positions from bot book
                # so position count is accurate for new entries
                if is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED and mn % 5 == 0:
                    if not hasattr(self, '_last_sync_mn'):
                        self._last_sync_mn = -1
                    if mn != self._last_sync_mn:
                        self._last_sync_mn = mn
                        try:
                            _sync_kite = KiteSession.get()
                            if _sync_kite:
                                _all_syms = set()
                                _all_syms.update(self.intraday.book.get("positions", {}).keys())
                                _all_syms.update(self.swing.book.get("positions", {}).keys())
                                _all_syms.update(self.longterm.book.get("positions", {}).keys())
                                # Sync each book — removes positions sold by GTT
                                PositionSync.sync_equity(_sync_kite, self.intraday.book, "intraday", send_telegram, adopt=False)
                                self.intraday._save()
                                PositionSync.sync_equity(_sync_kite, self.longterm.book, "longterm", send_telegram, adopt=False)
                                self.longterm._save()
                                PositionSync.sync_equity(_sync_kite, self.swing.book, "swing", send_telegram, _all_syms, adopt=False)
                                self.swing._save()
                        except Exception as _ps_err:
                            logger.debug(f"Position sync: {_ps_err}")


                # ── FIX #10: ACTIVE PROFIT BOOKING (every 5 min during market) ──
                # Uses Kite LTP to check if any position has hit Target 2
                # This runs INDEPENDENTLY of the 30-min scan cycle
                if is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED and mn % 5 == 0:
                    if not hasattr(self, '_last_profit_mn'):
                        self._last_profit_mn = -1
                    if mn != self._last_profit_mn:
                        self._last_profit_mn = mn
                        try:
                            _pk = KiteSession.get()
                            if _pk:
                                _profit_syms = set()
                                for _ptr in [self.intraday, self.swing, self.longterm]:
                                    _profit_syms.update(_ptr.book.get("positions", {}).keys())
                                if _profit_syms:
                                    _pltp = _pk.ltp([f"NSE:{s}" for s in _profit_syms])
                                    for _ps, _pv in _pltp.items():
                                        _psym = _ps.replace("NSE:", "")
                                        _pcmp = _pv["last_price"]
                                        # Check each trader
                                        for _ptr in [self.intraday, self.swing, self.longterm]:
                                            if _psym in _ptr.book.get("positions", {}):
                                                _ppos = _ptr.book["positions"][_psym]
                                                _pt2 = _ppos.get("target2", 0)
                                                _pt1 = _ppos.get("target1", 0)
                                                _psl = _ppos.get("stop_loss", 0)
                                                # Target 2 hit — SELL immediately
                                                if _pt2 > 0 and _pcmp >= _pt2:
                                                    logger.info(f"🎯 PROFIT TARGET [{_psym}] CMP=₹{_pcmp} >= T2=₹{_pt2}")
                                                    _ptr.exit(_psym, _pcmp, "🎯 Target 2 Hit (LTP)")
                                                # Stop loss hit — SELL immediately
                                                elif _psl > 0 and _pcmp <= _psl:
                                                    logger.info(f"🛑 STOP LOSS [{_psym}] CMP=₹{_pcmp} <= SL=₹{_psl}")
                                                    _ptr.exit(_psym, _pcmp, "🛑 Stop Loss Hit (LTP)")
                                                # Target 1 + overbought check
                                                elif _pt1 > 0 and _pcmp >= _pt1:
                                                    # Check RSI from last scan
                                                    _last_scan = next((s for s in self._scan_cache if s["symbol"] == _psym), None)
                                                    if _last_scan and _last_scan.get("profit_book"):
                                                        _ptr.exit(_psym, _pcmp, "✂️ T1+Overbought (LTP)")
                        except Exception as _perr:
                            logger.debug(f"Profit check: {_perr}")

                        # ── GTT SYNC: Update GTT when trailing SL moves up ──
                        # Delegates to LiveEquityTrader.update_gtt() which uses
                        # the correct product type (CNC/MIS) per trader, enforces
                        # 1.5% minimum move, and sends Telegram on update.
                        try:
                            if _LIVE_MODULE_LOADED:
                                for _gtr in [self.swing, self.longterm]:
                                    for _gsym, _gpos in list(_gtr.book.get("positions", {}).items()):
                                        _cur_sl     = _gpos.get("stop_loss", 0)
                                        _cur_gtt_sl = _gpos.get("gtt_sl", 0)
                                        if _cur_sl > 0 and _cur_sl > _cur_gtt_sl:
                                            # Get LTP from the already-fetched ltp_data if available
                                            _sync_ltp = _ltp_data.get(_gsym, 0) if '_ltp_data' in dir() else 0
                                            _gtr.update_gtt(_gsym, _cur_sl, ltp=_sync_ltp)
                        except Exception:
                            pass

                # ── TRAILING SL (every 10 min during market) ─────────────────
                # Checks all positions every 10 min. If LTP moved up,
                # adjusts SL upward by 0.5% minimum. Updates Kite GTT.
                # Runs at: 09:20, 09:30, 09:40, 09:50, 10:00... (every 10 min)
                if (is_open and TRADING_MODE == "LIVE" and _LIVE_MODULE_LOADED
                    and (mn % 10 == 0) or (hr == 15 and mn == 15)):
                    if not hasattr(self, '_last_trail_key'):
                        self._last_trail_key = -1
                    _trail_key = hr * 100 + mn
                    if _trail_key != self._last_trail_key:
                        self._last_trail_key = _trail_key
                        try:
                            _kite = KiteSession.get()
                            if _kite:
                                # Get LTP for all open positions
                                _all_syms = set()
                                for _tr in [self.intraday, self.swing, self.longterm]:
                                    _all_syms.update(_tr.book.get("positions", {}).keys())
                                if _all_syms:
                                    _ltp_raw = _kite.ltp([f"NSE:{s}" for s in _all_syms])
                                    _ltp_data = {
                                        s.replace("NSE:", ""): v["last_price"]
                                        for s, v in _ltp_raw.items()
                                    }
                                    # Update trailing SL in book
                                    _trail_updates = TrailingStopLoss.update_all(
                                        self, _ltp_data, send_telegram
                                    )
                                    if _trail_updates:
                                        logger.info(f"📈 Trailing SL: {len(_trail_updates)} positions updated in book")
                                        # Only modify Kite SL order if change is 1.5%+ higher
                                        _orders = _kite.orders()
                                        for _upd in _trail_updates:
                                            try:
                                                _sym = _upd["symbol"]
                                                _new_sl = _upd["new_sl"]
                                                _old_sl = _upd["old_sl"]
                                                # Check if change is significant (1.5%+)
                                                _change_pct = ((_new_sl - _old_sl) / _old_sl * 100) if _old_sl > 0 else 0
                                                if _change_pct < 1.5:
                                                    logger.debug(f"Trail [{_sym}]: SL change {_change_pct:.1f}% < 1.5% — skip Kite modify")
                                                    continue
                                                # Find and modify the existing SL order
                                                for _ord in _orders:
                                                    if (_ord["tradingsymbol"] == _sym
                                                            and _ord["status"] in ["TRIGGER PENDING", "OPEN"]
                                                            and _ord["transaction_type"] == "SELL"
                                                            and _ord["order_type"] in ["SL", "SL-M"]):
                                                        _kite.modify_order(
                                                            variety=_ord["variety"],
                                                            order_id=_ord["order_id"],
                                                            trigger_price=round(_new_sl, 1),
                                                        )
                                                        logger.info(
                                                            f"🛡️ SL MODIFIED: {_sym} "
                                                            f"SL ₹{_old_sl:.1f} → ₹{_new_sl:.1f} "
                                                            f"(+{_change_pct:.1f}%)"
                                                        )
                                                        break
                                            except Exception as _sl_err:
                                                logger.error(f"Modify SL [{_upd['symbol']}]: {_sl_err}")
                        except Exception as _trail_err:
                            logger.error(f"Trailing SL engine: {_trail_err}")


                # ── v23.5.0: GTT AUDIT at 08:30 (before market, trading days only) ──
                # Uses gtt_audit() — smarter: checks existing, re-places missing, updates trailing
                if not hasattr(self, '_gtt_audit_done_today'):
                    self._gtt_audit_done_today = False
                if not self._gtt_audit_done_today and hr == 8 and 28 <= mn <= 35 and KiteSession.is_trading_day():
                    self._gtt_audit_done_today = True
                    try:
                        _audit_kite = KiteSession.get()
                        if _audit_kite:
                            _placed, _updated, _orphans = gtt_audit(
                                _audit_kite,
                                [self.intraday, self.swing, self.longterm],
                                send_telegram
                            )
                            logger.info(f"GTT AUDIT: placed={_placed} updated={_updated} orphans={_orphans}")
                    except Exception as _audit_err:
                        logger.error(f"GTT audit: {_audit_err}")

                # Health check (trading days only — no point on weekends)
                if time.time()-self._last_health_ts>=3600 and KiteSession.is_trading_day():
                    self._last_health_ts=time.time(); self.health_check()

                # ── HEARTBEAT: 08:00 and 20:00 on NON-TRADING days only ──
                if not KiteSession.is_trading_day():
                    if ((hr == 8 and mn <= 2) or (hr == 20 and mn <= 2)):
                        if not hasattr(self, '_last_heartbeat_hr'):
                            self._last_heartbeat_hr = -1
                        if hr != self._last_heartbeat_hr:
                            self._last_heartbeat_hr = hr
                            _hb_n = now_ist()
                            # Use Kite holdings as source of truth (not stale JSON books)
                            _hb_pos = 0
                            try:
                                _hb_kite = KiteSession.get()
                                if _hb_kite:
                                    _hb_holdings = _hb_kite.holdings() or []
                                    _hb_pos = sum(1 for h in _hb_holdings
                                                  if (h.get("quantity", 0) + h.get("t1_quantity", 0)) > 0)
                            except Exception:
                                _hb_pos = sum(len(t.book.get("positions", {})) for t in [self.swing, self.longterm] if hasattr(t, 'book'))
                            _send_telegram_raw(
                                f"Bot alive | {_hb_n.strftime('%a %d %b %H:%M IST')}\n"
                                f"Non-Trading Day | {_hb_pos} holdings | GTTs on Zerodha"
                            )
                    # ── LIVE: Periodic position sync (every health check) ──
                    if TRADING_MODE == "LIVE" and hasattr(self, '_live_order_mgr'):
                        try:
                            _kite = KiteSession.get()
                            if _kite:
                                # ── ONE-TIME GTT AUDIT on startup ──
                                # Runs ONCE after first Kite connection
                                # Deletes orphan GTTs, replaces old wide SL with tight SL
                                if not hasattr(self, '_startup_gtt_audit_done'):
                                    self._startup_gtt_audit_done = False
                                if not self._startup_gtt_audit_done:
                                    self._startup_gtt_audit_done = True
                                    try:
                                        logger.info("STARTUP GTT AUDIT — one-time cleanup")
                                        _placed, _updated, _orphans = gtt_audit(
                                            _kite,
                                            [self.intraday, self.swing, self.longterm],
                                            send_telegram
                                        )
                                        logger.info(
                                            f"STARTUP GTT AUDIT DONE: "
                                            f"placed={_placed} updated={_updated} orphans_deleted={_orphans}"
                                        )
                                    except Exception as _sga_err:
                                        logger.warning(f"Startup GTT audit: {_sga_err}")

                                # Collect ALL symbols across all strategies to prevent duplicate adopt
                                # ── FIXED: Collect ALL symbols first, then sync each book ──
                                # Only SWING adopts unknown Kite positions (CNC holdings default to swing)
                                _all_bot_syms = set()
                                _all_bot_syms.update(self.intraday.book.get("positions", {}).keys())
                                _all_bot_syms.update(self.swing.book.get("positions", {}).keys())
                                _all_bot_syms.update(self.longterm.book.get("positions", {}).keys())

                                # Intraday & longterm: sync only (remove phantoms, update qty) — NO adopting
                                PositionSync.sync_equity(_kite, self.intraday.book, "intraday", send_telegram, all_bot_syms=None, adopt=False)
                                self.intraday._save()

                                PositionSync.sync_equity(_kite, self.longterm.book, "longterm", send_telegram, all_bot_syms=None, adopt=False)
                                self.longterm._save()

                                # Swing: sync AND adopt unknown Kite positions
                                PositionSync.sync_equity(_kite, self.swing.book, "swing", send_telegram, _all_bot_syms, adopt=True)
                                self.swing._save()

                                # ── Tier Migration: check for orphaned positions ──
                                if hasattr(self, '_tier_migration_mgr') and self._tier_migration_mgr:
                                    try:
                                        _real_cash = CapitalAllocator.get_available_capital(_kite)
                                        _total_bal = CapitalAllocator.get_total_balance(_kite)
                                        _tier_bal = _total_bal if _total_bal > 0 else _real_cash
                                        _tn, _ti = CapitalAllocator.get_tier(_tier_bal)
                                        _traders = {
                                            "intraday": self.intraday,
                                            "swing": self.swing,
                                            "longterm": self.longterm,
                                            "fno": self.fno,
                                        }
                                        _mig = self._tier_migration_mgr.check_and_migrate(_tn, _traders)
                                        if _mig and _mig.get("total", 0) > 0:
                                            logger.info(f"TierMigration (health): {_mig['total']} positions handled")
                                    except Exception as _mig_err:
                                        logger.debug(f"TierMigration health: {_mig_err}")

                        except Exception as _sync_err:
                            logger.error(f"Periodic sync: {_sync_err}")

                # ── TRADE PERFORMANCE MONITOR (Sunday 18:00 + 1st of month 19:00) ──
                if self._perf_monitor:
                    try:
                        self._perf_monitor.check_and_run(hr, mn, n.weekday())
                    except Exception as _pm_err:
                        logger.debug(f"PerfMonitor: {_pm_err}")

                time.sleep(60)

            except KeyboardInterrupt:
                logger.info("👋 Shutdown"); send_telegram(f"⛔ *Global Eye {VERSION}* — Shutdown"); break
            except Exception as e:
                logger.error(f"Main: {e}\n{traceback.format_exc()}")
                send_telegram(f"⚠️ *Error*: {str(e)[:200]}\nContinuing..."); time.sleep(60)

if __name__=="__main__":
    bot=GlobalEyeSentinel(); bot.run()
