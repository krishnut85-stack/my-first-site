"""Central configuration for SectorBot.

Everything you might want to tweak lives here. Defaults are intentionally
conservative and the bot ALWAYS runs in paper (simulation) mode unless you
explicitly turn LIVE_TRADING on AND supply Kite Connect keys.
"""

import os
from pathlib import Path

# --- Paths -----------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"            # drop your daily CSVs here (via Termius)
DATA_CSV = DATA_DIR / "sectors.csv"     # fallback if no dated file is found
SNAPSHOTS_DIR = DATA_DIR / "snapshots"  # historical daily CSVs for backtesting
PORTFOLIO_JSON = DATA_DIR / "portfolio.json"  # persistent paper portfolio state
# Tradeable universe (industry -> stocks). Priority order:
#   1. data/universe.csv         -> stock-level export you drop in (Symbol,
#      Industry[,Market Cap/Volume]); auto-grouped, sorted by liquidity.
#   2. data/industry_symbols.csv -> the editable default shipped with the bot.
#   3. the in-code fallback map in instruments.py.
UNIVERSE_CSV = DATA_DIR / "universe.csv"
INDUSTRY_SYMBOLS_CSV = DATA_DIR / "industry_symbols.csv"
PORTFOLIO_REPORT_TXT = BASE_DIR.parent / "portfolio_report.txt"   # latest run, plain
PORTFOLIO_REPORT_HTML = BASE_DIR.parent / "portfolio_report.html"  # latest run, html
DASHBOARD_HTML = BASE_DIR.parent / "dashboard.html"  # written into my-first-site

# A daily upload can be named anything ending in .csv (e.g. 2026-06-22.csv).
# The bot auto-picks the most recently modified *.csv in DATA_DIR unless you
# pass --csv on the command line or set SECTORBOT_CSV.
CSV_OVERRIDE = os.environ.get("SECTORBOT_CSV", "")

# --- Safety switch ---------------------------------------------------------
# Paper mode = fake money, zero risk. Keep this False unless you fully
# understand the risk, have tested for a long time, and have read the README.
LIVE_TRADING = False

# --- Kite Connect ----------------------------------------------------------
# Needed for REAL market prices (paper trading on live data) and for live
# orders. Set these as environment variables / GitHub secrets.
KITE_API_KEY = os.environ.get("KITE_API_KEY", "")
KITE_API_SECRET = os.environ.get("KITE_API_SECRET", "")
KITE_ACCESS_TOKEN = os.environ.get("KITE_ACCESS_TOKEN", "")
# Path to a file holding the daily access token (e.g. the one your TOTP
# auto-login already writes). Used only if KITE_ACCESS_TOKEN isn't set.
KITE_TOKEN_FILE = os.environ.get("KITE_TOKEN_FILE", "")


def resolve_access_token() -> str:
    """Return the Kite access token from the env var, else from KITE_TOKEN_FILE.

    The token file may be: the raw token on one line; JSON with an
    'access_token'/'token' key; or KEY=VALUE lines. We never log its contents.
    """
    if KITE_ACCESS_TOKEN.strip():
        return KITE_ACCESS_TOKEN.strip()
    if KITE_TOKEN_FILE and Path(KITE_TOKEN_FILE).exists():
        raw = Path(KITE_TOKEN_FILE).read_text().strip()
        try:
            import json
            d = json.loads(raw)
            if isinstance(d, dict):
                for k in ("access_token", "accessToken", "token"):
                    if d.get(k):
                        return str(d[k]).strip()
        except Exception:  # noqa: BLE001
            pass
        for line in raw.splitlines():
            if "access_token" in line.lower() and "=" in line:
                return line.split("=", 1)[1].strip().strip('"\'')
        if raw and "\n" not in raw:
            return raw
    return ""

# Use REAL Kite prices for paper trading when keys are present. This is still
# PAPER (no real orders) -- it just simulates against actual market data so the
# track record is meaningful. Falls back to synthetic prices if Kite is
# unavailable. Set LIVE_TRADING (above) only when you truly want real orders.
USE_KITE_DATA = True

# --- Capital / position sizing --------------------------------------------
# CAPITAL_MODE:
#   "fixed"     -> spread PAPER_CAPITAL across picks, cash-constrained
#   "unlimited" -> no cash limit; invest NOTIONAL_PER_NAME in every pick
CAPITAL_MODE = "fixed"
PAPER_CAPITAL = 1_000_000.0    # Rs 10 lakh paper capital (fixed mode)
NOTIONAL_PER_NAME = 50_000.0   # rupees per stock in "unlimited" mode
TOP_N_INDUSTRIES = 8           # how many top-ranked industries to invest in
MAX_NAMES_PER_INDUSTRY = 4     # cap symbols taken from each industry
MAX_ALLOCATION_PER_NAME = 0.15 # (fixed mode) cap per stock vs capital (1.5L)
MAX_PORTFOLIO_PE = 60          # skip industries trading above this PE (overheated)

# --- Over-extended guard ---------------------------------------------------
# Avoid buying the most PARABOLIC names. Research shows extreme/vertical
# momentum has the steepest reversal ("momentum crash") risk -- this is the
# "am I buying the very top?" protection. Skip an industry whose recent quarter
# run-up exceeds MAX_QTR_RUNUP_PCT. Keeps normal momentum, drops the blow-offs.
AVOID_OVEREXTENDED = True
MAX_QTR_RUNUP_PCT = 60.0       # skip industries up more than this % in a quarter

# --- Rebalance (rotation with BUFFER BANDS) --------------------------------
# REBALANCE=True uses buffer bands to minimise churn & taxes (no fixed calendar):
#   • BUY  to fill up to MAX_POSITIONS from the best-ranked names you don't hold.
#   • SELL a holding ONLY when it drops out of the top SELL_RANK_BUFFER (it is
#     NOT sold just for slipping a place or two). A hard stop-loss is the floor.
# So you trade only when a holding genuinely deteriorates — typically a few
# times a month, not daily. REBALANCE=False = pure exit-rule hold (SL/TP/etc).
REBALANCE = True
MAX_POSITIONS = 8             # target number of holdings (buy the top 8)
SELL_RANK_BUFFER = 15        # keep a holding while it stays in the top 15

# --- Exit rules ------------------------------------------------------------
STOP_LOSS_PCT = 0.10           # hard stop: exit if price falls 10% from entry
TAKE_PROFIT_PCT = 0.25         # hard target: book profit at +25% from entry

# Trailing stop-loss: once activated, exit if price falls TRAILING_SL_PCT from
# its peak. TRAILING_ACTIVATE_PCT is the profit needed before trailing arms
# (this is what "trailing profit" / profit-locking means).
USE_TRAILING_STOP = True
TRAILING_ACTIVATE_PCT = 0.08   # arm trailing once +8% in profit
TRAILING_SL_PCT = 0.05         # then exit on a 5% drop from the peak

# ATR (Average True Range) stop: exit if price falls below
# entry - ATR_MULT * ATR. Adapts the stop to each stock's volatility.
USE_ATR_STOP = True
ATR_PERIOD = 14                # bars used to compute ATR
ATR_MULT = 2.5                 # stop distance in ATR multiples
ATR_HISTORY_BARS = 60          # how much history to pull for the ATR calc

DAILY_LOSS_LIMIT_PCT = 0.05    # stop opening new trades after a 5% drawdown

# --- Trading costs (makes the backtest HONEST) -----------------------------
# Real buys/sells cost money: brokerage + STT + exchange fees + GST + stamp
# duty + SEBI charges, PLUS slippage (you rarely fill at the screen price).
# Without these, a backtest looks better than reality. We subtract an all-in
# cost every time the strategy buys or sells.
#
# BACKTEST_COST_PER_SIDE_PCT is one conservative "per side" number (as a
# fraction). NSE delivery equity is roughly ~0.05% on a buy and ~0.12% on a
# sell (STT is sell-heavy); add slippage and 0.12% per side all-in is a fair,
# slightly conservative default. Lower it if your real cost sheet is cheaper.
INCLUDE_TRADING_COSTS = True
BACKTEST_COST_PER_SIDE_PCT = 0.0012   # 0.12% per buy and per sell, all-in

# --- Market-regime filter (don't fight a falling market) -------------------
# Buying strong stocks while the WHOLE market is in a downtrend is the fastest
# way to lose money in a momentum strategy ("momentum crashes" happen in bear
# markets). When the broad index is below its long moving average, we STOP
# opening new positions and sit in cash until the trend turns back up. Existing
# positions are still managed by the normal exit rules. This "trend overlay" is
# one of the most reliable, well-documented ways to cut the worst drawdowns.
# Fail-open: if the index trend can't be determined (no Kite history, offline),
# trading is allowed as normal so the bot never freezes by accident.
USE_REGIME_FILTER = True
REGIME_INDEX = "NIFTY 50"      # broad-market gauge (NSE index)
REGIME_SMA = 200               # days; index above its 200-day average = uptrend

# --- Honest scorecard / finish line ----------------------------------------
# The whole point of paper trading is to answer ONE question: is this strategy
# genuinely worth it — i.e. does it beat just buying a Nifty index fund, after
# costs? The scorecard tracks that and gives a plain verdict. Below MIN_TRACK_DAYS
# of history it refuses to judge (early results are noise, not signal).
MIN_TRACK_DAYS = 30            # need at least this many runs before any verdict

# --- Email alerts ----------------------------------------------------------
# Daily picks + simulated exits can be emailed to you. Credentials come from
# environment variables so nothing secret is committed. If they're not set,
# the bot prints the email to the console instead of sending (safe dry-run).
#
# Gmail setup: turn on 2-step verification, create an "App password", then:
#   export SMTP_HOST=smtp.gmail.com SMTP_PORT=465
#   export SMTP_USER=krishnut85@gmail.com
#   export SMTP_PASSWORD=your_16_char_app_password
EMAIL_TO = os.environ.get("EMAIL_TO", "krishnut85@gmail.com")
EMAIL_FROM = os.environ.get("EMAIL_FROM", os.environ.get("SMTP_USER", ""))
SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "465"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")

# --- Telegram alerts -------------------------------------------------------
# Push alerts to your phone instantly via a Telegram bot. Unlike SMTP, the Bot
# API is plain HTTPS, so it works on hosts that block outbound mail ports (e.g.
# DigitalOcean blocks 25/465/587 by default). Setup:
#   1. Message @BotFather -> /newbot -> copy the token  -> TELEGRAM_BOT_TOKEN
#   2. Message your new bot once (so it is allowed to reply to you).
#   3. Message @userinfobot to get your numeric id      -> TELEGRAM_CHAT_ID
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")

# --- Scoring weights (transparent momentum + quality blend) ----------------
WEIGHTS = {
    "qtr_change": 0.20,        # Qtr Change %
    "half_change": 0.20,       # Half Yr Change %
    "year_change": 0.15,       # 1Yr Change %
    "industry_score": 0.25,    # provider's Industry Score
    "roe": 0.10,               # Return on Equity Annual
    "rev_growth": 0.05,        # Revenue growth Qtr YoY%
    "breadth": 0.05,           # Advances/Declines ratio
}

# --- SMART DVM score (Mayura's brain — uses MAX Trendlyne columns) ---------
# When True, Mayura ranks industries on a Trendlyne-style DVM score built from
# every useful column in your CSV (ROE/ROA/profit & revenue growth = Durability;
# PEG/PE/PBV/dividend yield = Valuation; week→year change + breadth = Momentum),
# instead of the older momentum-only blend. Set False to revert to the plain
# fundamental+breadth score. See sectorbot/smart.py.
USE_SMART_SCORE = True
# Weights of the three DVM pillars (sum ~1.0). Momentum-led but quality-aware:
# we still chase trend, but Durability stops us buying junk and Valuation stops
# us paying any price. Tune to taste.
SMART_WEIGHTS = {
    "durability": 0.35,
    "valuation": 0.20,
    "momentum": 0.45,
}
# Extra points added to the momentum pillar when ALL timeframes are positive
# (a clean, aligned uptrend). 0 disables the bonus.
SMART_ALIGNMENT_BONUS = 10.0

# --- Breakout watchlist: EARLY-STAGE vs continuation -----------------------
# A breakout watchlist (mayura_data/universe.csv) can be scored two ways:
#   • BREAKOUT_EARLY_STAGE = True  (default) -> favour a FRESH golden cross
#     (SMA50 just above SMA200) and DEMOTE already-extended/parabolic names.
#     This catches stocks "when the green just crosses and is about to go up,"
#     not after they have already run 3-6x.
#   • False -> the older "buy strength near the 52-week high" (continuation)
#     model, which by design buys stocks that are ALREADY running.
BREAKOUT_EARLY_STAGE = True
# A cross is "fresh" while SMA50 is within this % above SMA200. Beyond it the
# trend is treated as increasingly mature/extended and scored lower.
FRESH_CROSS_MAX_PCT = 10.0

# --- Sector-breadth blend --------------------------------------------------
# A separate Trendlyne CSV (sector bullish/bearish breadth) can be blended in.
# Each industry's fundamental score gets a tilt from its SECTOR's breadth score.
# Final score = fundamental * BLEND_FUNDAMENTAL_WEIGHT
#             + sector_breadth (0-100) * BLEND_BREADTH_WEIGHT
USE_BREADTH_BLEND = True
BLEND_FUNDAMENTAL_WEIGHT = 1.0
BLEND_BREADTH_WEIGHT = 0.5

# Breadth columns are the % of a sector's stocks that are bullish on each
# signal (0-100); MOMENTUM SCORE is already 0-100. Weights sum to 1.0 so the
# breadth score is also 0-100. Long-term trend (SMA200, golden cross) weighted
# highest.
BREADTH_WEIGHTS = {
    "momentum_score": 0.25,    # MOMENTUM SCORE
    "rsi50": 0.10,             # % with RSI > 50
    "mfi50": 0.10,             # % with MFI > 50
    "sma20": 0.05,             # % with LTP > SMA20
    "sma50": 0.10,             # % with LTP > SMA50
    "sma200": 0.20,            # % with LTP > SMA200 (long-term trend)
    "golden_cross": 0.15,      # % with SMA50 > SMA200
    "week_gainers": 0.05,      # WEEK GAINERS %
}
