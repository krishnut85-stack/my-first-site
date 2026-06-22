"""Command-line entry point.

  python -m sectorbot rank [--csv FILE]      # show ranked industries
  python -m sectorbot sim  [--csv FILE]      # run the paper-trading simulation
  python -m sectorbot dashboard [--csv FILE] # write dashboard.html
  python -m sectorbot backtest               # replay data/snapshots/*.csv
  python -m sectorbot email [--csv FILE]      # email daily picks/exits
  python -m sectorbot trade [--csv FILE]      # run persistent paper portfolio + email
  python -m sectorbot snapshot                # save today's CSV to snapshots/
  python -m sectorbot token-check             # verify Kite token + real data (safe)

Daily workflow: upload today's CSV into sectorbot/data/ via Termius (any name
ending in .csv). The bot auto-uses the newest file -- no flags needed.
"""

import sys

from . import config
from .backtest import run_backtest
from .bot import run_simulation
from .data_loader import resolve_csv, save_snapshot
from .engine import run_paper_session
from .notify import send_daily, send_portfolio
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
    print(f"\n{'#':>3}  {'Industry':34} {'Sector':28} {'Score':>6} {'Fund':>6} {'Breadth':>7} {'PE':>7}")
    print("-" * 100)
    for i, ind in enumerate(ranked[:25], 1):
        pe = f"{ind.pe:.1f}" if ind.pe is not None else "-"
        print(f"{i:>3}  {ind.name[:34]:34} {ind.sector[:28]:28} {ind.score:6.1f} "
              f"{ind.fundamental_score:6.1f} {ind.sector_breadth_score:7.1f} {pe:>7}")
    print("\nScore = fundamentals + breadth blend. Not a prediction, not advice.\n")


def cmd_sim() -> None:
    run_simulation(csv_path=_csv_arg())


def cmd_dashboard() -> None:
    out = generate(csv_path=_csv_arg())
    print(f"Dashboard written to: {out}")


def cmd_backtest() -> None:
    run_backtest()


def cmd_email() -> None:
    send_daily(csv_path=_csv_arg())


def cmd_snapshot() -> None:
    dst = save_snapshot(_csv_arg())
    print(f"Snapshot saved: {dst}")


def cmd_trade() -> None:
    # run the persistent paper session once, print it, then email that result
    result = run_paper_session(verbose=True, csv_path=_csv_arg())
    send_portfolio(result=result)


def cmd_token_check() -> None:
    """Confirm a Kite token resolves and real prices work -- without ever
    printing the token itself (only its length + last 4 chars)."""
    tok = config.resolve_access_token()
    if not tok:
        print("No access token resolved.")
        print("Set KITE_ACCESS_TOKEN, or KITE_TOKEN_FILE to your kite_token.json.")
        return
    print(f"Token resolved: length {len(tok)}, ends ...{tok[-4:]}  (value hidden)")
    if not config.KITE_API_KEY:
        print("KITE_API_KEY is not set — cannot test live fetch.")
        return
    try:
        from .datasource import KiteDataSource
        ds = KiteDataSource()
        price = ds.last_price("RELIANCE")
        print(f"✅ Kite live data OK — RELIANCE LTP = {price}")
    except Exception as exc:  # noqa: BLE001
        print(f"❌ Kite check failed: {exc}")


def main() -> None:
    cmds = {
        "rank": cmd_rank,
        "sim": cmd_sim,
        "dashboard": cmd_dashboard,
        "backtest": cmd_backtest,
        "email": cmd_email,
        "trade": cmd_trade,
        "snapshot": cmd_snapshot,
        "token-check": cmd_token_check,
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
