"""Command-line entry point.

  python -m sectorbot rank        # show ranked industries
  python -m sectorbot sim         # run the paper-trading simulation
  python -m sectorbot dashboard   # write dashboard.html
"""

import sys

from . import config
from .bot import run_simulation
from .report import generate
from .screener import score_industries, load_industries


def cmd_rank() -> None:
    ranked = score_industries(load_industries())
    print(f"\n{'#':>3}  {'Industry':34} {'Sector':30} {'Score':>6} {'PE':>7}")
    print("-" * 86)
    for i, ind in enumerate(ranked[:25], 1):
        pe = f"{ind.pe:.1f}" if ind.pe is not None else "-"
        print(f"{i:>3}  {ind.name[:34]:34} {ind.sector[:30]:30} {ind.score:6.1f} {pe:>7}")
    print("\n(Ranking of YOUR data — not a prediction, not advice.)\n")


def cmd_sim() -> None:
    run_simulation()


def cmd_dashboard() -> None:
    out = generate()
    print(f"Dashboard written to: {out}")


def main() -> None:
    cmds = {"rank": cmd_rank, "sim": cmd_sim, "dashboard": cmd_dashboard}
    choice = sys.argv[1] if len(sys.argv) > 1 else "sim"
    if choice not in cmds:
        print(f"Unknown command '{choice}'. Use one of: {', '.join(cmds)}")
        sys.exit(1)
    if config.LIVE_TRADING:
        print("⚠️  LIVE_TRADING is ON — real orders may be placed. Ctrl-C to abort.")
    cmds[choice]()


if __name__ == "__main__":
    main()
