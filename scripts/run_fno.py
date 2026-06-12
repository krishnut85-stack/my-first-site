#!/usr/bin/env python3
"""F&O bot — the single entry point for paper and live NSE F&O trading.

Strategies:
    straddle  - intraday NIFTY ATM short straddle, per-leg SL (default)
    trend     - EMA crossover on the current-month NIFTY future, ATR stop

Modes:
    paper (default) - LIVE Zerodha quotes, SIMULATED fills. No real orders.
    live            - real orders; additionally requires --i-understand-the-risks

Credentials come from the environment / .env (TOTP auto-login, same variable
names as the previous server setup): KITE_API_KEY, KITE_API_SECRET,
ZERODHA_USER_ID, ZERODHA_PASSWORD, KITE_TOTP_SECRET. Telegram alerts are sent
if TG_BOT_TOKEN/TELEGRAM_CHAT_ID are set.

Examples:
    python3 scripts/run_fno.py                              # paper straddle
    python3 scripts/run_fno.py --strategy trend --lots 1
    python3 scripts/run_fno.py --mode live --lots 1 --max-daily-loss 5000 \
        --i-understand-the-risks
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from algotrade.brokers.paper import PaperBroker
from algotrade.brokers.zerodha import ZerodhaBroker
from algotrade.engine import TradingEngine
from algotrade.instruments import LOT_SIZES, build_future_symbol, next_monthly_expiry
from algotrade.risk import RiskLimits, RiskManager
from algotrade.strategies import EmaCrossover, ShortStraddle
from algotrade.timeutils import now_ist


def load_dotenv_if_present() -> None:
    for path in (Path.home() / ".env", Path(".env")):
        if path.exists():
            import os
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            break


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--strategy", choices=["straddle", "trend"], default="straddle")
    parser.add_argument("--mode", choices=["paper", "live"], default="paper")
    parser.add_argument("--lots", type=int, default=1)
    parser.add_argument("--max-daily-loss", type=float, default=5_000)
    parser.add_argument("--poll-seconds", type=int, default=20)
    parser.add_argument("--i-understand-the-risks", action="store_true")
    args = parser.parse_args()

    if args.mode == "live" and not args.i_understand_the_risks:
        sys.exit(
            "Refusing live mode without --i-understand-the-risks.\n"
            "Run paper mode for at least 2-4 weeks first; F&O losses can be "
            "large and fast (a SEBI study found ~90% of retail F&O traders "
            "lose money)."
        )

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.StreamHandler()],
    )
    load_dotenv_if_present()

    quotes = ZerodhaBroker()  # quote/history source in both modes (auto TOTP login)
    lot = LOT_SIZES["NIFTY"]

    if args.mode == "live":
        broker = quotes
        capital = broker.margins_available()
        logging.info("LIVE mode — available margin ₹%.0f", capital)
    else:
        broker = PaperBroker(quote_fn=quotes.ltp)
        capital = 200_000.0
        logging.info("PAPER mode — simulated fills, live quotes")

    risk = RiskManager(
        RiskLimits(max_daily_loss=args.max_daily_loss, max_open_lots=args.lots,
                   capital=capital),
        lot_size=lot,
    )

    if args.strategy == "trend":
        fut = build_future_symbol("NIFTY", next_monthly_expiry(now_ist().date()))
        strategy = EmaCrossover(symbol=fut, lot_size=lot)
        history_fn = quotes.history
    else:
        strategy = ShortStraddle(lots=args.lots, spot_ltp_fn=quotes.spot_ltp)
        history_fn = None

    TradingEngine(strategy, broker, risk, poll_seconds=args.poll_seconds,
                  history_fn=history_fn, mode=args.mode).run()


if __name__ == "__main__":
    main()
