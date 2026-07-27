"""Central configuration for SectorBot.

Everything you might want to tweak lives here. Defaults are intentionally
conservative and the bot ALWAYS runs in paper (simulation) mode unless you
explicitly turn LIVE_TRADING on AND supply Kite Connect keys.
"""

import os
from pathlib import Path


def _load_env_file(path: "Path") -> None:
    """Load KEY=VALUE lines from one .env into os.environ. Existing env vars
    always win (we never overwrite). Tiny parser: '#' comments, optional quotes,
    optional leading 'export '."""
    try:
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if line.startswith("export "):
                line = line[len("export "):]
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = val
    except OSError:
        pass


def _autoload_dotenv() -> None:
    """Auto-load env files so you never paste/copy keys or use nano. Order (first
    wins, never overwritten):
      1. Mayura's OWN .env   (repo root)  -> Telegram token + per-topic ids
      2. the SHARED bot .env (/home/globalbot/.env, override via MAYURA_SHARED_ENV)
         -> the API keys your main bot already holds: KITE_API_KEY/SECRET,
            GEMINI_API_KEY, etc. Loaded at runtime; nothing secret is copied here."""
    here = Path(__file__).resolve().parent
    candidates = [here.parent / ".env", here / ".env",
                  Path(os.environ.get("MAYURA_SHARED_ENV", "/home/globalbot/.env"))]
    seen = set()
    for p in candidates:
        rp = str(p)
        if rp in seen:
            continue
        seen.add(rp)
        if p.exists():
            _load_env_file(p)


_autoload_dotenv()

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

# Time stop ("how many days do we hold?"): in exit-rule mode (REBALANCE=False),
# exit a position after MAX_HOLDING_DAYS calendar days, but ONLY if it is "dead
# money" — gain still below TIME_STOP_MIN_GAIN_PCT. A stock that is genuinely
# running stays in (the trailing stop manages it); this just frees capital from
# names that went sideways. 0 = disabled (default; the equity bot is unaffected).
MAX_HOLDING_DAYS = 0
TIME_STOP_MIN_GAIN_PCT = 0.05

# Failed-breakout exit (exit-rule mode): sell as soon as price falls back BELOW
# the breakout level (the SMA50 captured at entry) — the cleanest "this breakout
# has failed" signal, usually faster than the time stop. Needs a breakout_level
# stored on the holding (Mayura's watchlist mode supplies it). Default off so the
# equity bot is unaffected.
USE_FAILED_BREAKOUT_EXIT = False
# Grace period: don't fire the failed-breakout exit within this many days of
# entry — give a fresh breakout time to develop (and avoid same-day whipsaws).
BREAKOUT_GRACE_DAYS = 0

# Skip the whole session if the market did NOT trade today (holiday/weekend):
# prices are stale, so running exits would be bogus. Default off (equity bot
# unchanged); Mayura turns it on.
SKIP_MARKET_HOLIDAYS = False

# Extension guard ("never chase a stock that already ran up"): refuse to BUY any
# stock whose LIVE price is more than this fraction above its 200-day average —
# i.e. already parabolic/extended (what we must NOT chase). Uses the live Kite
# price vs the SMA200 supplied from your screen. 0 = disabled (equity bot
# unaffected). Mayura sets a per-strategy value.
MAX_EXTENSION_ABOVE_SMA200 = 0.0

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

# What to do in a DOWNTREND (index below its 200-DMA):
#   "block"   -> open NO new positions, sit in cash (default; safest).
#   "reduced" -> SMART MIDDLE: still buy, but only the strongest few leaders and
#                at a smaller size — because relative-strength leaders can keep
#                running even while the index falls.
REGIME_DOWNTREND_MODE = "block"
REGIME_DOWNTREND_MAX_POSITIONS = 3    # in reduced mode, hold at most this many
REGIME_DOWNTREND_SIZE_FACTOR = 0.5    # …each at this fraction of normal size

# --- Market Weather 👁 (pre-open risk dial; sectorbot/weather.py) ------------
# Set per run by the launcher (Mayura) from the day's saved weather verdict.
# Defaults are NEUTRAL so plain sectorbot (and any run without a fresh verdict)
# behaves exactly as before. Scales/blocks NEW ENTRIES ONLY — exits always run.
WEATHER_SIZE_FACTOR = 1.0     # multiply each new position's budget (0.5 on a DOWN day)
WEATHER_BLOCK_NEW = False     # True on a STRONG DOWN morning: no new buys today
WEATHER_TRAIL_FACTOR = 1.0    # DEFENSIVE MODE: tighten the trailing stop's give
                              # on hostile mornings (0.75 DOWN / 0.5 STRONG DOWN)
WEATHER_INFO = ""             # human line for reports/Telegram ("" = no verdict)

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
#
# MAYURA ISOLATION: Mayura is its OWN bot in its OWN group, and must NEVER share
# a token/chat with the main equity bot (an env load-order slip once sent Mayura
# alerts into the wrong group). So Mayura's OWN vars — MAYURA_BOT_TOKEN /
# MAYURA_CHAT_ID — ALWAYS WIN when present. The generic TELEGRAM_* vars are only
# the fallback (what the main bot uses), so the two can never collide again.
TELEGRAM_BOT_TOKEN = (os.environ.get("MAYURA_BOT_TOKEN")
                      or os.environ.get("TELEGRAM_BOT_TOKEN", ""))
TELEGRAM_CHAT_ID = (os.environ.get("MAYURA_CHAT_ID")
                    or os.environ.get("TELEGRAM_CHAT_ID", ""))

# --- Swaminatha: NSE/BSE filings gate --------------------------------------
# The Swaminatha face (Mayura's "Guru") reads recent corporate filings and only
# (paper-)buys a stock when the filing is BULLISH. A clear red-flag filing
# (SEBI action, default, auditor resignation, pledge, etc.) blocks the buy.
# These settings are read by sectorbot/filings.py and mayura.py.
FILINGS_SOURCE = os.environ.get("FILINGS_SOURCE", "nse")  # "nse" (symbol-based)
FILINGS_DAYS_BACK = int(os.environ.get("FILINGS_DAYS_BACK", "7"))  # look-back window
FILINGS_SCAN_TOP = int(os.environ.get("FILINGS_SCAN_TOP", "25"))   # cap fetches/day
FILINGS_REQUEST_TIMEOUT = int(os.environ.get("FILINGS_REQUEST_TIMEOUT", "15"))
# If filings can't be fetched (e.g. NSE blocks the server), be SAFE: no clear
# bullish news = no buy. True keeps Swaminatha from buying blind on fetch errors.
FILINGS_REQUIRE_BULLISH = True

# --- Swaminatha: Gemini news-reading face ----------------------------------
# Reads today's NSE/BSE announcements market-wide, lets Gemini read the FULL
# news and judge whether it's a genuine, MATERIAL bullish catalyst, runs basic
# safety checks, then paper-buys. Needs a (paid) Gemini API key on the droplet.
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT = int(os.environ.get("GEMINI_TIMEOUT", "30"))
GEMINI_USE_SEARCH = True          # Google Search grounding for materiality context
NEWS_DAYS_BACK = int(os.environ.get("NEWS_DAYS_BACK", "2"))      # announcement look-back
NEWS_MAX_GEMINI_CALLS = int(os.environ.get("NEWS_MAX_GEMINI_CALLS", "40"))  # per-POLL safety cap
NEWS_MAX_GEMINI_CALLS_DAILY = int(os.environ.get("NEWS_MAX_GEMINI_CALLS_DAILY", "30"))  # HARD daily ceiling
NEWS_MIN_CONFIDENCE = float(os.environ.get("NEWS_MIN_CONFIDENCE", "0.6"))   # Gemini conviction
# Cheap pre-Gemini gate: for ORDER/CONTRACT news with a stated value, require it
# be at least this many ₹ crore (small orders are skipped WITHOUT a Gemini call).
# Approvals/buybacks/mergers (no order value) bypass this and go to Gemini.
NEWS_MIN_ORDER_CR = float(os.environ.get("NEWS_MIN_ORDER_CR", "100"))
# Basic safety checks before ANY news-driven buy (market-wide can surface junk):
NEWS_MIN_PRICE = float(os.environ.get("NEWS_MIN_PRICE", "20"))             # no penny stocks
NEWS_MIN_TURNOVER_CR = float(os.environ.get("NEWS_MIN_TURNOVER_CR", "1.0"))  # avg daily ₹cr (liquidity)

# --- OHLC technical engine (Thanikesa VCP / Stage-2; Solaimalai) -----------
# These strategies COMPUTE their edge from live Kite OHLC bars instead of
# screening Trendlyne columns. The universe CSV is just a stable candidate pool
# (e.g. Nifty Smallcap 250) uploaded once — not a daily screen.
OHLC_HISTORY_BARS = int(os.environ.get("OHLC_HISTORY_BARS", "260"))  # ~1yr of days
OHLC_MAX_SYMBOLS = int(os.environ.get("OHLC_MAX_SYMBOLS", "520"))    # cap fetches (covers Nifty 500)
OHLC_FETCH_DELAY = float(os.environ.get("OHLC_FETCH_DELAY", "0.35")) # secs/req (~<3/s, Kite historical limit)

# --- Thanikesa: lenient valuation guard ("a little freedom") ---------------
# Thanikesa is a momentum face, so it WILL favour leaders near their highs. To
# avoid blindly buying "Getting Expensive" names (like RR Kabel: PE 57, P/B 11,
# Trendlyne Valuation 33.8), it reads the Trendlyne Valuation Score (0..100,
# HIGHER = cheaper) from the pool CSV — IF that column is present. Only active
# when the pool carries valuation data; a bare NSE-symbol list disables it.
#   • Below FLOOR  -> SKIP (too expensive, no freedom).
#   • FLOOR..FULL  -> kept but DEMOTED (the "little freedom" zone).
#   • >= FULL      -> no penalty (cheap enough).
# Raise the FLOOR (e.g. 35) to be stricter; lower it (e.g. 0) to disable.
THANIKESA_VALUATION_FLOOR = float(os.environ.get("THANIKESA_VALUATION_FLOOR", "20"))
THANIKESA_VALUATION_FULL = float(os.environ.get("THANIKESA_VALUATION_FULL", "55"))
THANIKESA_VALUATION_MIN_FACTOR = 0.65   # most an expensive name is demoted

# --- Solaimalai: large/mid-cap VALUE + QUALITY quant + special situations ---
# Re-tuned (was momentum-heavy, which overlapped Thanikesa). Now value- and
# quality-led from Trendlyne fundamentals, cross-sectionally z-scored, with the
# Greenblatt special-situations overlay. Run on a LARGE/MID-cap pool so it never
# overlaps small-cap Thanikesa. Factors (higher = better) from the CSV.
SOLAIMALAI_FUND_WEIGHTS = {"value": 0.45, "quality": 0.40, "trend": 0.15}
# (legacy OHLC weights kept for reference / fallback if ever switched back)
SOLAIMALAI_FACTOR_WEIGHTS = {
    "momentum": 0.30, "vcp": 0.20, "trend": 0.20, "lowvol": 0.15, "rs": 0.15,
}
# A bullish "special situation" (buyback / demerger / spin-off / promoter buying)
# in recent filings BOOSTS the composite by this many points (capped at 100). A
# red-flag filing zeroes the score (blocked). Filings are a conviction overlay
# here, not a hard gate (fail-open: no filings = pure quant score stands).
SOLAIMALAI_SPECIAL_BOOST = float(os.environ.get("SOLAIMALAI_SPECIAL_BOOST", "12"))

# How many days before a pool/screen file is flagged "stale" in the alert, so you
# know when to re-upload a fresh Trendlyne export. Index pools rarely change, but
# Trendlyne valuation/DVM scores drift over weeks.
POOL_STALE_DAYS = int(os.environ.get("POOL_STALE_DAYS", "45"))

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
