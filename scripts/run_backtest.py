#!/usr/bin/env python3
"""Backtest the EMA crossover strategy on futures bars.

Usage:
    python scripts/run_backtest.py data/nifty_fut_5min.csv
    python scripts/run_backtest.py --demo          # synthetic data smoke test

CSV format: datetime,open,high,low,close[,volume] (5-minute bars work well).
Historical NIFTY futures data can be exported from Kite (historical API),
or any vendor; this repo ships no market data.
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np
import pandas as pd

from algotrade.backtest import Backtester, load_bars_csv
from algotrade.instruments import LOT_SIZES
from algotrade.risk import RiskLimits, RiskManager
from algotrade.strategies import EmaCrossover

SYMBOL = "NIFTYFUT"


def synthetic_bars(days: int = 60, seed: int = 7) -> pd.DataFrame:
    """Random-walk 5-min bars for pipeline smoke tests (not for evaluating edge)."""
    rng = np.random.default_rng(seed)
    sessions = pd.bdate_range("2026-01-05", periods=days)
    frames = []
    price = 24_000.0
    for day in sessions:
        idx = pd.date_range(day + pd.Timedelta(hours=9, minutes=15),
                            day + pd.Timedelta(hours=15, minutes=25), freq="5min")
        rets = rng.normal(0, 0.0008, len(idx))
        closes = price * np.exp(np.cumsum(rets))
        price = closes[-1]
        high = closes * (1 + np.abs(rng.normal(0, 0.0004, len(idx))))
        low = closes * (1 - np.abs(rng.normal(0, 0.0004, len(idx))))
        opens = np.concatenate([[closes[0]], closes[:-1]])
        frames.append(pd.DataFrame(
            {"open": opens, "high": high, "low": low, "close": closes}, index=idx))
    return pd.concat(frames)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", nargs="?", help="path to OHLCV csv")
    parser.add_argument("--demo", action="store_true", help="use synthetic data")
    # NIFTY lot 75 with a ~40-pt ATR stop risks ~3,000 rupees per lot, so 1%
    # risk-per-trade needs >=3L capital to size even one lot.
    parser.add_argument("--capital", type=float, default=500_000)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    if args.demo:
        bars = synthetic_bars()
        print("WARNING: synthetic random-walk data — results say nothing about edge")
    elif args.csv:
        bars = load_bars_csv(args.csv)
    else:
        parser.error("provide a csv path or --demo")

    lot = LOT_SIZES["NIFTY"]
    limits = RiskLimits(capital=args.capital, max_daily_loss=args.capital * 0.02)
    risk = RiskManager(limits, lot_size=lot)
    strategy = EmaCrossover(symbol=SYMBOL, lot_size=lot)
    result = Backtester(strategy, risk, SYMBOL, bars).run()

    print("\n=== Backtest result ===")
    print(result.summary())
    out = Path("data/equity_curve.csv")
    out.parent.mkdir(exist_ok=True)
    result.equity_curve.to_csv(out, header=["pnl"])
    print(f"equity curve written to {out}")


if __name__ == "__main__":
    main()
