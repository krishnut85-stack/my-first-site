#!/usr/bin/env python3
"""Paper-trade the short straddle with LIVE Zerodha quotes but SIMULATED fills.

This is the recommended mode for validating the system during market hours
before any real order is placed. Requires KITE_API_KEY / KITE_ACCESS_TOKEN
for the quote feed only — no orders reach the exchange.

Usage:
    python scripts/run_paper.py [--lots 1]
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from algotrade.brokers.paper import PaperBroker
from algotrade.brokers.zerodha import ZerodhaBroker
from algotrade.engine import TradingEngine
from algotrade.instruments import LOT_SIZES
from algotrade.risk import RiskLimits, RiskManager
from algotrade.strategies import ShortStraddle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lots", type=int, default=1)
    parser.add_argument("--max-daily-loss", type=float, default=5_000)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    quotes = ZerodhaBroker()  # used only as a quote source here
    broker = PaperBroker(quote_fn=quotes.ltp)
    risk = RiskManager(
        RiskLimits(max_daily_loss=args.max_daily_loss, max_open_lots=args.lots),
        lot_size=LOT_SIZES["NIFTY"],
    )
    strategy = ShortStraddle(lots=args.lots, spot_ltp_fn=quotes.spot_ltp)
    TradingEngine(strategy, broker, risk, poll_seconds=20).run()


if __name__ == "__main__":
    main()
