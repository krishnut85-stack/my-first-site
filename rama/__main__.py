"""Command-line entry point.

  python -m rama rank [--csv FILE]      # show ranked industries
  python -m rama sim  [--csv FILE]      # run the paper-trading simulation
  python -m rama dashboard [--csv FILE] # write dashboard.html
  python -m rama backtest               # replay data/snapshots/*.csv
  python -m rama email [--csv FILE]      # email daily picks/exits
  python -m rama trade [--csv FILE]      # run persistent paper portfolio + email
  python -m rama snapshot                # save today's CSV to snapshots/
  python -m rama status                  # show saved activity (no live data)
  python -m rama scorecard               # honest verdict: working? beating index?
  python -m rama universe-check          # audit stock coverage + live tickers
  python -m rama token-check             # verify Kite token + real data (safe)

Daily workflow: upload today's CSV into rama/data/ via Termius (any name
ending in .csv). The bot auto-uses the newest file -- no flags needed.
"""

import sys

from . import config
from .backtest import run_backtest
from .bot import run_simulation
from .data_loader import resolve_csv, save_snapshot
from .engine import run_paper_session
from .notify import send_daily, send_portfolio, write_portfolio_report
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
    # run the persistent paper session once, print it, write a report file, and
    # email it only if SMTP is configured (email failures never crash the run).
    result = run_paper_session(verbose=True, csv_path=_csv_arg())
    if result.get("aborted"):
        return  # portfolio left untouched; nothing to report
    txt, html = write_portfolio_report(result)
    print(f"Report written: {txt}")
    if config.SMTP_HOST and config.SMTP_USER and config.SMTP_PASSWORD:
        send_portfolio(result=result)


def cmd_status() -> None:
    """Show the saved bot activity (no live data needed): equity history,
    recent trades, and current holdings from portfolio.json."""
    from .portfolio import Portfolio
    pf = Portfolio.load()
    start = pf.starting_capital
    latest = pf.history[-1]["equity"] if pf.history else start
    ret = (latest - start) / start * 100 if start else 0.0

    print("\n" + "=" * 60)
    print("  Rama · ACTIVITY")
    print("=" * 60)
    print(f"  Starting capital : Rs {start:,.0f}")
    print(f"  Latest equity    : Rs {latest:,.0f}  ({ret:+.2f}%)")
    print(f"  Realised P&L     : Rs {pf.realized_pnl:,.0f}")
    print(f"  Holdings: {len(pf.holdings)}   ·   Trades logged: {len(pf.trades)}")

    # --- performance metrics (from closed trades + equity history) --------
    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    wins = [t for t in closed if t["pnl"] > 0]
    losses = [t for t in closed if t["pnl"] <= 0]
    print("\n  Performance:")
    if not closed:
        print("    (no closed trades yet — metrics appear after the first sell)")
    else:
        win_rate = len(wins) / len(closed) * 100
        avg_win = sum(t["pnl"] for t in wins) / len(wins) if wins else 0.0
        avg_loss = sum(t["pnl"] for t in losses) / len(losses) if losses else 0.0
        best = max(closed, key=lambda t: t["pnl"])
        worst = min(closed, key=lambda t: t["pnl"])
        print(f"    Closed trades : {len(closed)}  ({len(wins)} wins / {len(losses)} losses)")
        print(f"    Win rate      : {win_rate:.0f}%")
        print(f"    Avg win/loss  : +{avg_win:,.0f} / {avg_loss:,.0f}")
        print(f"    Best trade    : {best['symbol']} {best['pnl']:+,.0f}")
        print(f"    Worst trade   : {worst['symbol']} {worst['pnl']:+,.0f}")

    # max drawdown from the equity curve (largest peak-to-trough drop)
    eqs = [h["equity"] for h in pf.history]
    if len(eqs) >= 2:
        peak = eqs[0]
        mdd = 0.0
        for e in eqs:
            peak = max(peak, e)
            mdd = min(mdd, (e - peak) / peak)
        print(f"    Max drawdown  : {mdd * 100:.2f}%  (worst peak-to-dip on the equity curve)")

    print("\n  Equity history (last 12 runs):")
    for h in pf.history[-12:]:
        print(f"    {h['date']}    Rs {h['equity']:,.0f}")

    print("\n  Recent trades (last 12):")
    if not pf.trades:
        print("    (none yet)")
    for t in pf.trades[-12:]:
        pnl = t.get("pnl")
        pnl_s = f"   P&L {pnl:+,.0f}" if pnl is not None else ""
        print(f"    {t['date']}  {t['side']:4} {t['symbol']:12} x{t['qty']:<5} "
              f"@ {t['price']:>9.2f}  [{t.get('reason','')}]{pnl_s}")

    print("\n  Current holdings:")
    if not pf.holdings:
        print("    (none)")
    for s, h in pf.holdings.items():
        print(f"    {s:12} x{h['qty']:<5} @ {h['avg_price']:>9.2f}  since {h['entry_date']}")
    print("=" * 60 + "\n")


def cmd_scorecard() -> None:
    """Honest verdict: is the paper strategy working, and is it beating a simple
    Nifty index fund after costs? Reads the saved portfolio (no live data)."""
    from .portfolio import Portfolio
    from .scorecard import compute_scorecard, format_scorecard
    print("\n" + format_scorecard(compute_scorecard(Portfolio.load())) + "\n")


def cmd_universe_check() -> None:
    """Audit the tradeable universe: how many stocks map to each top industry,
    which are live on Kite, and which top industries have NO stocks (blind
    spots). Uses real Kite prices when keys are set, else just shows coverage."""
    from .datasource import PaperDataSource, get_datasource
    from .instruments import audit_universe

    ds = get_datasource()
    real = not isinstance(ds, PaperDataSource)
    report = audit_universe(ds=ds if real else None)

    print("\n" + "=" * 64)
    print(f"  Rama · UNIVERSE CHECK   (source: {report['source']})")
    print("=" * 64)
    for row in report["industries"]:
        if real and row["checked"]:
            alive = sum(1 for c in row["checked"] if c["alive"])
            dead = [c["symbol"] for c in row["checked"] if not c["alive"]]
            tag = f"{alive}/{row['mapped']} live"
            if dead:
                tag += f"  ✗ dead: {', '.join(dead)}"
        else:
            tag = f"{row['mapped']} mapped"
        flag = "  ⚠️ NO STOCKS" if row["mapped"] == 0 else ""
        print(f"  {row['industry'][:38]:38} {tag}{flag}")
    if report["coverage_holes"]:
        print("-" * 64)
        print(f"  Blind spots (top industries with no stocks): "
              f"{len(report['coverage_holes'])}")
        for h in report["coverage_holes"]:
            print(f"    • {h}")
        print("  → add rows for these to rama/data/industry_symbols.csv")
    if not real:
        print("-" * 64)
        print("  (No Kite keys — coverage only. Set keys to check live prices.)")
    print("=" * 64 + "\n")


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
        "status": cmd_status,
        "scorecard": cmd_scorecard,
        "universe-check": cmd_universe_check,
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
