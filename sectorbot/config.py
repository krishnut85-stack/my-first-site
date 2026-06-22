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
DASHBOARD_HTML = BASE_DIR.parent / "dashboard.html"  # written into my-first-site

# A daily upload can be named anything ending in .csv (e.g. 2026-06-22.csv).
# The bot auto-picks the most recently modified *.csv in DATA_DIR unless you
# pass --csv on the command line or set SECTORBOT_CSV.
CSV_OVERRIDE = os.environ.get("SECTORBOT_CSV", "")

# --- Safety switch ---------------------------------------------------------
# Paper mode = fake money, zero risk. Keep this False unless you fully
# understand the risk, have tested for a long time, and have read the README.
LIVE_TRADING = False

# --- Kite Connect (only needed for live data / live orders) ----------------
KITE_API_KEY = os.environ.get("KITE_API_KEY", "")
KITE_API_SECRET = os.environ.get("KITE_API_SECRET", "")
KITE_ACCESS_TOKEN = os.environ.get("KITE_ACCESS_TOKEN", "")

# --- Capital / position sizing --------------------------------------------
# CAPITAL_MODE:
#   "fixed"     -> spread PAPER_CAPITAL across picks, cash-constrained
#   "unlimited" -> no cash limit; invest NOTIONAL_PER_NAME in every pick
CAPITAL_MODE = "unlimited"
PAPER_CAPITAL = 100_000.0      # used only in "fixed" mode
NOTIONAL_PER_NAME = 50_000.0   # rupees per stock in "unlimited" mode
TOP_N_INDUSTRIES = 8           # how many top-ranked industries to invest in
MAX_NAMES_PER_INDUSTRY = 4     # cap symbols taken from each industry
MAX_ALLOCATION_PER_NAME = 0.15 # (fixed mode only) cap per stock vs capital
MAX_PORTFOLIO_PE = 60          # skip industries trading above this PE (overheated)

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
