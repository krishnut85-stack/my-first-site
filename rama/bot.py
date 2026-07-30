"""Rama orchestrator.

Pipeline:
  1. Screen + rank industries from the (daily) CSV          (screener.py)
  2. Map top industries to representative NSE symbols        (instruments.py)
  3. Size positions (fixed or unlimited capital)            (config.py)
  4. Compute ATR at entry, then run forward steps applying
     hard SL / take-profit / trailing stop / ATR stop       (risk.py)
  5. Report results + generate an HTML dashboard            (report.py)

Everything is PAPER TRADING. Nothing here places a real order.
"""

from dataclasses import dataclass

from . import config
from .datasource import PaperDataSource, get_datasource
from .indicators import atr
from .instruments import symbols_for
from .paper_broker import PaperBroker
from .risk import PositionState, decide_exit
from .screener import Industry, top_industries


@dataclass
class Pick:
    industry: Industry
    symbols: list[str]


def build_watchlist(csv_path=None) -> list[Pick]:
    """Top-ranked industries that we actually have tradeable symbols for."""
    picks = []
    for ind in top_industries(csv_path=csv_path):
        syms = symbols_for(ind.name)[: config.MAX_NAMES_PER_INDUSTRY]
        if syms:
            picks.append(Pick(industry=ind, symbols=syms))
    return picks


def _position_size(ds, symbol: str, price: float) -> int:
    if config.CAPITAL_MODE == "unlimited":
        budget = config.NOTIONAL_PER_NAME
    else:
        budget = min(
            config.PAPER_CAPITAL / max(config.TOP_N_INDUSTRIES, 1),
            config.PAPER_CAPITAL * config.MAX_ALLOCATION_PER_NAME,
        )
    return int(budget // price)


def run_simulation(steps: int = 12, verbose: bool = True, csv_path=None) -> dict:
    ds = get_datasource()
    unlimited = config.CAPITAL_MODE == "unlimited"
    broker = PaperBroker(config.PAPER_CAPITAL, unlimited=unlimited)
    picks = build_watchlist(csv_path)

    # Flatten to a target symbol list and seed synthetic momentum (paper only).
    targets: list[str] = []
    for pick in picks:
        for sym in pick.symbols:
            targets.append(sym)
            if isinstance(ds, PaperDataSource):
                ds.set_momentum(sym, pick.industry.qtr_change / 100.0)
    targets = list(dict.fromkeys(targets))  # de-dupe, keep order

    # --- open positions + record per-position risk state ------------------
    states: dict[str, PositionState] = {}
    for sym in targets:
        price = ds.last_price(sym)
        qty = _position_size(ds, sym, price)
        if qty <= 0 or not broker.buy(sym, qty, price, reason="initial allocation"):
            continue
        bars = ds.history(sym, config.ATR_HISTORY_BARS)
        a = atr(bars, config.ATR_PERIOD)
        states[sym] = PositionState(symbol=sym, entry_price=price, qty=qty, atr=a)

    # --- run forward steps with all exit rules ----------------------------
    for _ in range(steps):
        for sym in list(broker.positions.keys()):
            if isinstance(ds, PaperDataSource):
                ds.advance(sym)
            ltp = ds.last_price(sym)
            should_exit, reason = decide_exit(states[sym], ltp)
            if should_exit:
                broker.sell(sym, broker.positions[sym].qty, ltp, reason=reason)

    price_of = ds.last_price
    result = {
        "picks": picks,
        "broker": broker,
        "datasource": ds,
        "states": states,
        "equity": broker.equity(price_of),
        "pnl": broker.total_pnl(price_of),
        "pnl_pct": broker.total_pnl_pct(price_of),
        "invested": broker.invested,
        "price_of": price_of,
    }
    if verbose:
        _print_summary(result)
    return result


def _print_summary(result: dict) -> None:
    b = result["broker"]
    print("\n" + "=" * 66)
    print("  Rama  ·  PAPER TRADING SIMULATION  ·  no real money")
    print("=" * 66)
    print(f"  Mode            : {'LIVE' if config.LIVE_TRADING else 'PAPER (simulation)'}")
    print(f"  Capital mode    : {config.CAPITAL_MODE.upper()}", end="")
    if config.CAPITAL_MODE == "unlimited":
        print(f"  (Rs {config.NOTIONAL_PER_NAME:,.0f}/name)")
    else:
        print(f"  (Rs {config.PAPER_CAPITAL:,.0f} total)")
    print(f"  Gross deployed  : Rs {result['invested']:,.0f}")
    print(f"  Simulated P&L   : Rs {result['pnl']:,.0f} ({result['pnl_pct']:+.2f}%)")
    print(f"  Exit rules      : SL {config.STOP_LOSS_PCT:.0%} | TP {config.TAKE_PROFIT_PCT:.0%}"
          f" | trail {config.TRAILING_SL_PCT:.0%}@{config.TRAILING_ACTIVATE_PCT:.0%}"
          f" | ATR {config.ATR_MULT}x")
    print("-" * 66)
    print("  Top industries selected from your data:")
    for p in result["picks"]:
        i = p.industry
        print(f"   • {i.name:30} score {i.score:5.1f}  PE {i.pe}  -> {', '.join(p.symbols)}")
    print("-" * 66)
    exits = [t for t in b.trades if t.side == "SELL"]
    print(f"  Trades: {len(b.trades)} total · {len(exits)} exits")
    for t in exits[:12]:
        print(f"     SELL {t.symbol:12} @ {t.price:8.2f}  [{t.reason}]")
    print("=" * 66)
    print("  Reminder: synthetic prices. NOT a prediction. NOT advice.\n")


if __name__ == "__main__":
    run_simulation()
