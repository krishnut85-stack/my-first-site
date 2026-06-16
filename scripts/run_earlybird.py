#!/usr/bin/env python3
"""Early Bird scanner — flags F&O names whose option flow looks pre-explosive.

ALERT-ONLY: it never places an order. It scans option chains for the whole
F&O universe every few minutes, sends Telegram alerts on strong signals
(put/call writing, short covering, unusual volume, IV expansion), logs every
signal, and posts an end-of-day scorecard of how the signals actually did.

Run it alongside the paper trading bot (separate systemd service):
    python3 scripts/run_earlybird.py                 # market-hours loop
    python3 scripts/run_earlybird.py --once          # single scan (testing)
    python3 scripts/run_earlybird.py --interval 300  # scan every 5 min
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from algotrade.brokers.kite_auth import auto_login
from algotrade.earlybird import EarlyBird
from algotrade.earlybird.scanner import run_loop
from algotrade.env import load_dotenv_if_present
from algotrade.timeutils import is_weekday


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--interval", type=int, default=600,
                        help="seconds between chain scans (default 600)")
    parser.add_argument("--once", action="store_true",
                        help="run a single scan cycle and print signals")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s")
    load_dotenv_if_present()

    if not args.once and not is_weekday():
        logging.info("weekend — nothing to do")
        return

    kite = auto_login()
    if args.once:
        signals = EarlyBird(kite).cycle()
        for s in signals:
            print(f"{s['score']:>3}  {s['symbol']:<14} {s['direction']:<8} "
                  f"{s['pattern']:<16} {s['detail']}")
        if not signals:
            print("no signals this cycle")
        return

    run_loop(kite, interval_seconds=args.interval)


if __name__ == "__main__":
    main()
