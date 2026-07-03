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
