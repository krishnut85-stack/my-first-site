#!/usr/bin/env python3
"""LIVE trading — real orders, real money. Read this before running.

Prerequisites:
  1. Backtest the strategy on real historical data (scripts/run_backtest.py).
  2. Paper trade during market hours for at least 2-4 weeks (scripts/run_paper.py).
  3. Understand that F&O losses can exceed your invested capital, and that
     ~90% of retail F&O traders lose money (SEBI study, 2024).

Requires KITE_API_KEY and KITE_ACCESS_TOKEN. The --i-understand-the-risks
flag is mandatory by design.

Usage:
    python scripts/run_live.py --lots 1 --max-daily-loss 5000 --i-understand-the-risks
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from algotrade.brokers.zerodha import ZerodhaBroker
from algotrade.engine import TradingEngine
from algotrade.instruments import LOT_SIZES
from algotrade.risk import RiskLimits, RiskManager
from algotrade.strategies import ShortStraddle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lots", type=int, default=1)
    parser.add_argument("--max-daily-loss", type=float, default=5_000)
    parser.add_argument("--i-understand-the-risks", action="store_true")
    args = parser.parse_args()

    if not args.i_understand_the_risks:
        sys.exit("Refusing to trade live without --i-understand-the-risks. "
                 "Use scripts/run_paper.py first.")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.StreamHandler(), logging.FileHandler("live_trading.log")],
    )

    broker = ZerodhaBroker()
    margin = broker.margins_available()
    logging.info("available margin: %.0f", margin)

    risk = RiskManager(
        RiskLimits(max_daily_loss=args.max_daily_loss, max_open_lots=args.lots,
                   capital=margin),
        lot_size=LOT_SIZES["NIFTY"],
    )
    strategy = ShortStraddle(lots=args.lots, spot_ltp_fn=broker.spot_ltp)
    TradingEngine(strategy, broker, risk, poll_seconds=15).run()


if __name__ == "__main__":
    main()
