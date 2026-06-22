"""Command-line entry point.

  python -m sectorbot rank [--csv FILE]      # show ranked industries
  python -m sectorbot sim  [--csv FILE]      # run the paper-trading simulation
  python -m sectorbot dashboard [--csv FILE] # write dashboard.html
  python -m sectorbot backtest               # replay data/snapshots/*.csv

Daily workflow: upload today's CSV into sectorbot/data/ via Termius (any name
ending in .csv). The bot auto-uses the newest file -- no flags needed.
"""

import sys

from . import config
from .backtest import run_backtest
from .bot import run_simulation
from .data_loader import resolve_csv
from .report import generate
from .screener import score_industries, load_industries


def _csv_arg() -> str | None:
    if "--csv" in sys.argv:
        i = sys.argv.index("--csv")
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


def cmd_rank() -> None:
    csv = _csv_arg()
    print(f"\nUsing data file: {resolve_csv(csv)}")
    ranked = score_industries(load_industries(csv))
    print(f"\n{'#':>3}  {'Industry':34} {'Sector':30} {'Score':>6} {'PE':>7}")
    print("-" * 86)
    for i, ind in enumerate(ranked[:25], 1):
        pe = f"{ind.pe:.1f}" if ind.pe is not None else "-"
        print(f"{i:>3}  {ind.name[:34]:34} {ind.sector[:30]:30} {ind.score:6.1f} {pe:>7}")
    print("\n(Ranking of YOUR data — not a prediction, not advice.)\n")


def cmd_sim() -> None:
    run_simulation(csv_path=_csv_arg())


def cmd_dashboard() -> None:
    out = generate(csv_path=_csv_arg())
    print(f"Dashboard written to: {out}")


def cmd_backtest() -> None:
    run_backtest()


def main() -> None:
    cmds = {
        "rank": cmd_rank,
        "sim": cmd_sim,
        "dashboard": cmd_dashboard,
        "backtest": cmd_backtest,
    }
    choice = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "sim"
    if choice not in cmds:
        print(f"Unknown command '{choice}'. Use one of: {', '.join(cmds)}")
        sys.exit(1)
    if config.LIVE_TRADING:
        print("⚠️  LIVE_TRADING is ON — real orders may be placed. Ctrl-C to abort.")
    cmds[choice]()


if __name__ == "__main__":
    main()
