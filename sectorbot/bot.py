"""SectorBot orchestrator.

Pipeline:
  1. Screen + rank industries from the CSV (screener.py)
  2. Map top industries to representative NSE symbols (instruments.py)
  3. Allocate virtual capital across them, respecting risk limits (config.py)
  4. Simulate buys, then run a few price steps applying stop-loss/take-profit
  5. Report results + generate an HTML dashboard

Everything is PAPER TRADING. Nothing here places a real order.
"""

from dataclasses import dataclass

from . import config
from .datasource import PaperDataSource, get_datasource
from .instruments import symbols_for
from .paper_broker import PaperBroker
from .screener import Industry, top_industries


@dataclass
class Pick:
    industry: Industry
    symbols: list[str]


def build_watchlist() -> list[Pick]:
    """Top-ranked industries that we actually have tradeable symbols for."""
    picks = []
    for ind in top_industries():
        syms = symbols_for(ind.name)
        if syms:
            picks.append(Pick(industry=ind, symbols=syms))
    return picks


def run_simulation(steps: int = 10, verbose: bool = True) -> dict:
    ds = get_datasource()
    broker = PaperBroker(config.PAPER_CAPITAL)
    picks = build_watchlist()

    # Flatten to a target symbol list and seed synthetic momentum (paper only).
    targets: list[str] = []
    for pick in picks:
        for sym in pick.symbols:
            targets.append(sym)
            if isinstance(ds, PaperDataSource):
                # nudge sim drift using the industry's recent quarter momentum
                ds.set_momentum(sym, pick.industry.qtr_change / 100.0)
    targets = list(dict.fromkeys(targets))  # de-dupe, keep order

    # --- allocate capital equally, capped per name ------------------------
    if targets:
        per_name_budget = min(
            config.PAPER_CAPITAL / len(targets),
            config.PAPER_CAPITAL * config.MAX_ALLOCATION_PER_NAME,
        )
        entries: dict[str, float] = {}
        for sym in targets:
            price = ds.last_price(sym)
            qty = int(per_name_budget // price)
            if qty > 0 and broker.buy(sym, qty, price, reason="initial allocation"):
                entries[sym] = price

    # --- run forward steps with stop-loss / take-profit -------------------
    for _ in range(steps):
        for sym in list(broker.positions.keys()):
            if isinstance(ds, PaperDataSource):
                ds.advance(sym)
            ltp = ds.last_price(sym)
            entry = entries.get(sym, ltp)
            change = (ltp - entry) / entry
            pos = broker.positions[sym]
            if change <= -config.STOP_LOSS_PCT:
                broker.sell(sym, pos.qty, ltp, reason=f"stop-loss {change:.1%}")
            elif change >= config.TAKE_PROFIT_PCT:
                broker.sell(sym, pos.qty, ltp, reason=f"take-profit {change:.1%}")

    price_of = ds.last_price
    result = {
        "picks": picks,
        "broker": broker,
        "datasource": ds,
        "equity": broker.equity(price_of),
        "pnl": broker.total_pnl(price_of),
        "pnl_pct": broker.total_pnl_pct(price_of),
        "price_of": price_of,
    }

    if verbose:
        _print_summary(result)
    return result


def _print_summary(result: dict) -> None:
    print("\n" + "=" * 64)
    print("  SectorBot  ·  PAPER TRADING SIMULATION  ·  no real money")
    print("=" * 64)
    print(f"  Mode: {'LIVE' if config.LIVE_TRADING else 'PAPER (simulation)'}")
    print(f"  Starting capital : Rs {result['broker'].starting_capital:,.0f}")
    print(f"  Ending equity    : Rs {result['equity']:,.0f}")
    print(f"  Simulated P&L    : Rs {result['pnl']:,.0f} ({result['pnl_pct']:+.2f}%)")
    print("-" * 64)
    print("  Top industries selected from your data:")
    for p in result["picks"]:
        i = p.industry
        print(f"   • {i.name:32} score {i.score:5.1f}  PE {i.pe}  -> {', '.join(p.symbols[:4])}")
    print("-" * 64)
    print(f"  Trades executed (simulated): {len(result['broker'].trades)}")
    print("=" * 64)
    print("  Reminder: synthetic prices. NOT a prediction. NOT advice.\n")


if __name__ == "__main__":
    run_simulation()
