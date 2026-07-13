"""Garuda configuration (its own — nothing shared with Rama or sectorbot)."""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"          # drop exported 5-min bar CSVs here

BOT_NAME = os.environ.get("GARUDA_NAME", "Garuda")

# --- Model -----------------------------------------------------------------
# Markov order = how many recent bar-directions form the "state" used to predict
# the next bar. Higher order = finer patterns but far more states (needs more
# data before each state is trustworthy).
MARKOV_ORDER = 3
WARMUP_BARS = 100          # learn-only bars before the model starts "trading"
SELF_LEARN = True          # keep updating the transition counts as bars arrive

# Only act when the model is meaningfully off a coin-flip. |p_up - 0.5| must
# exceed this edge, else Garuda stays flat that bar (no trade, no cost).
MIN_EDGE = 0.05

# --- Sizing (fractional Kelly on the model's own edge) ---------------------
KELLY_FRACTION = 0.5       # half-Kelly
MAX_ALLOCATION = 0.25      # never stake more than this fraction on one bar

# --- Honest costs (intraday NSE, round trip on the traded fraction) --------
# Intraday all-in per side ~ brokerage + STT(sell) + exchange + GST + slippage.
# 0.03% per side (~6bps round trip) is a fair, slightly optimistic default for a
# liquid name; raise it toward reality if your cost sheet is higher. WITHOUT
# costs a fast strategy always looks better than it is — so costs are ON.
COST_PER_SIDE = 0.0003

# --- Bars per year (for annualising the Sharpe-like figure) ----------------
# NSE ~ 375 min/session / 5-min bars ≈ 75 bars/day * ~250 days.
BARS_PER_YEAR = 75 * 250

# --- Paper capital (for a rupee view of the equity curve) ------------------
PAPER_CAPITAL = 1_000_000.0

# --- Cross-sectional (rank-all-stocks) backtest ----------------------------
# Daily rebalance on delivery is COSTLY: brokerage + STT + exchange + GST +
# stamp + slippage, both sides. ~0.10% per side (0.20% round trip EVERY day) is
# a fair, slightly optimistic figure for liquid names. This is deliberately
# heavy because daily churn is exactly what quietly bleeds retail accounts.
CROSS_COST_PER_SIDE = 0.0010

# ---------------------------------------------------------------------------
# SWAMINATHA — the news-driven book (Mayura's "Guru" face, ported into Garuda).
# It reads market-wide NSE/BSE corporate announcements, lets Gemini judge whether
# a filing is a genuine MATERIAL bullish catalyst on a financially-sound company,
# safety-gates it, and only then places a (paper) buy. It renders in its own tab.
# ---------------------------------------------------------------------------
# Book economics — its own slice of paper capital + how much to stake per name.
SWAMINATHA_CAPITAL = float(os.environ.get("SWAMINATHA_CAPITAL", "1000000"))
SWAMINATHA_ALLOC_PCT = float(os.environ.get("SWAMINATHA_ALLOC_PCT", "0.10"))  # per name
SWAMINATHA_MAX_POSITIONS = int(os.environ.get("SWAMINATHA_MAX_POSITIONS", "8"))
# Event-driven exits (news can reverse fast, so the stop is tighter than the
# equity books): -8% hard stop, arm a trailing lock after +10% then give 10%
# back from the peak, and time-exit after 15 calendar days.
SWAMINATHA_STOP = float(os.environ.get("SWAMINATHA_STOP", "0.08"))
SWAMINATHA_TRAIL_ARM = float(os.environ.get("SWAMINATHA_TRAIL_ARM", "0.10"))
SWAMINATHA_TRAIL_GIVE = float(os.environ.get("SWAMINATHA_TRAIL_GIVE", "0.10"))
SWAMINATHA_HOLD_DAYS = int(os.environ.get("SWAMINATHA_HOLD_DAYS", "15"))

# --- News fetch (corporate announcements) ----------------------------------
FILINGS_SOURCE = os.environ.get("FILINGS_SOURCE", "nse")  # per-symbol fetch source
FILINGS_DAYS_BACK = int(os.environ.get("FILINGS_DAYS_BACK", "7"))  # per-symbol look-back
FILINGS_REQUEST_TIMEOUT = int(os.environ.get("FILINGS_REQUEST_TIMEOUT", "15"))
NEWS_DAYS_BACK = int(os.environ.get("NEWS_DAYS_BACK", "2"))       # announcement look-back
NEWS_MIN_ORDER_CR = float(os.environ.get("NEWS_MIN_ORDER_CR", "100"))  # skip small orders (no AI)
NEWS_MIN_PRICE = float(os.environ.get("NEWS_MIN_PRICE", "20"))    # no penny stocks
NEWS_SEEN_KEEP_DAYS = int(os.environ.get("NEWS_SEEN_KEEP_DAYS", "5"))

# --- Gemini judge (the LAST, most-filtered step) ---------------------------
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT = int(os.environ.get("GEMINI_TIMEOUT", "30"))
GEMINI_USE_SEARCH = True             # Google Search grounding for materiality context
NEWS_MIN_CONFIDENCE = float(os.environ.get("NEWS_MIN_CONFIDENCE", "0.6"))   # Gemini conviction
NEWS_MAX_GEMINI_CALLS = int(os.environ.get("NEWS_MAX_GEMINI_CALLS", "40"))  # per-poll cap
NEWS_MAX_GEMINI_CALLS_DAILY = int(os.environ.get("NEWS_MAX_GEMINI_CALLS_DAILY", "30"))  # hard daily ceiling
