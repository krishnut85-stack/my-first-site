"""Garuda CLI.

  python -m garuda backtest                 # synthetic random-walk (offline demo)
  python -m garuda backtest --csv bars.csv  # your exported 5-min NSE bars
  python -m garuda backtest --order 4       # change the Markov order

Backtest FIRST. Only if a real-data run shows a genuine edge after costs is it
worth building live execution around this model.
"""

import sys

from . import config, data
from .backtest import run, format_report


def _arg(flag, cast=str, default=None):
    if flag in sys.argv:
        i = sys.argv.index(flag)
        if i + 1 < len(sys.argv):
            return cast(sys.argv[i + 1])
    return default


def main() -> None:
    csv = _arg("--csv")
    order = _arg("--order", int, config.MARKOV_ORDER)
    if csv:
        prices = data.load_csv_series(csv)
        source = f"{csv} ({len(prices)} bars)"
    else:
        prices = data.synthetic_series()
        source = f"synthetic random-walk ({len(prices)} bars) — NOT real data"

    if len(prices) < config.WARMUP_BARS + 50:
        print(f"Need at least {config.WARMUP_BARS + 50} bars; got {len(prices)}.")
        sys.exit(1)

    print(format_report(run(prices, order=order), source))
    if not csv:
        print("\n(Synthetic random walk has no real edge by construction — drop "
              "real 5-min NSE bars with --csv to test the model honestly.)")


if __name__ == "__main__":
    main()
