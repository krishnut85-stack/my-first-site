"""Central configuration for SectorBot.

Everything you might want to tweak lives here. Defaults are intentionally
conservative and the bot ALWAYS runs in paper (simulation) mode unless you
explicitly turn LIVE_TRADING on AND supply Kite Connect keys.
"""

from pathlib import Path

# --- Paths -----------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATA_CSV = BASE_DIR / "data" / "sectors.csv"
DASHBOARD_HTML = BASE_DIR.parent / "dashboard.html"  # written into my-first-site

# --- Safety switch ---------------------------------------------------------
# Paper mode = fake money, zero risk. Keep this False unless you fully
# understand the risk, have tested for a long time, and have read the README.
LIVE_TRADING = False

# --- Kite Connect (only needed for live data / live orders) ----------------
# Leave blank for paper mode. Never hard-code real secrets into git; prefer
# environment variables KITE_API_KEY / KITE_API_SECRET / KITE_ACCESS_TOKEN.
KITE_API_KEY = ""
KITE_API_SECRET = ""
KITE_ACCESS_TOKEN = ""

# --- Portfolio / risk controls --------------------------------------------
PAPER_CAPITAL = 100_000.0      # virtual rupees to start the simulation with
TOP_N_INDUSTRIES = 8           # how many top-ranked industries to invest in
MAX_ALLOCATION_PER_NAME = 0.15 # no single stock gets more than 15% of capital
STOP_LOSS_PCT = 0.10           # exit a position if it falls 10% from entry
TAKE_PROFIT_PCT = 0.25         # book profit if a position rises 25%
MAX_PORTFOLIO_PE = 60          # skip industries trading above this PE (overheated)
DAILY_LOSS_LIMIT_PCT = 0.05    # stop trading for the day after a 5% drawdown

# --- Scoring weights (transparent momentum + quality blend) ----------------
# These decide which industries look strongest in the data. Tweak freely.
WEIGHTS = {
    "qtr_change": 0.20,        # Qtr Change %
    "half_change": 0.20,       # Half Yr Change %
    "year_change": 0.15,       # 1Yr Change %
    "industry_score": 0.25,    # provider's Industry Score
    "roe": 0.10,               # Return on Equity Annual
    "rev_growth": 0.05,        # Revenue growth Qtr YoY%
    "breadth": 0.05,           # Advances/Declines ratio
}
