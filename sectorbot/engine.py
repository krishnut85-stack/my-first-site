"""Daily paper-trading session against (real, when configured) Kite prices.

Each run:
  1. Load the persistent portfolio.
  2. Price every holding; apply exit rules (SL / TP / trailing / ATR) and book
     realised P&L on exits.
  3. Rank industries from the CSV, then buy new top picks with available cash
     (respecting the per-name allocation cap).
  4. Record an equity point, save the portfolio.

PAPER ONLY -- no real orders. With Kite keys set it simulates against actual
market prices so the track record is meaningful; otherwise it uses synthetic
prices (clearly flagged) and the numbers are not real.
"""

from . import config
from .bot import build_watchlist
from .datasource import PaperDataSource, get_datasource
from .portfolio import Portfolio
from .risk import PositionState, decide_exit


def _safe_price(ds, symbol):
    try:
        p = ds.last_price(symbol)
        return float(p) if p and p > 0 else None
    except Exception:  # noqa: BLE001
        return None


def _safe_atr(ds, symbol):
    """ATR from history, or 0.0 if history is unavailable (e.g. no Kite
    historical-data subscription). The ATR stop is simply skipped then; the
    other exit rules still apply."""
    try:
        from .indicators import atr as _atr
        return _atr(ds.history(symbol, config.ATR_HISTORY_BARS), config.ATR_PERIOD)
    except Exception:  # noqa: BLE001
        return 0.0


def run_paper_session(verbose: bool = True, csv_path=None) -> dict:
    ds = get_datasource()
    real_data = not isinstance(ds, PaperDataSource)
    pf = Portfolio.load()

    # --- 1. manage existing positions (exits) -----------------------------
    exits = []
    for sym in list(pf.holdings.keys()):
        ltp = _safe_price(ds, sym)
        if ltp is None:
            continue
        h = pf.holdings[sym]
        state = PositionState(sym, h["avg_price"], h["qty"],
                              atr=h.get("atr", 0.0),
                              peak_price=h.get("peak_price", h["avg_price"]))
        should_exit, reason = decide_exit(state, ltp)
        h["peak_price"] = state.peak_price  # persist updated high-water mark
        if should_exit:
            pnl = pf.sell(sym, ltp, reason=reason)
            exits.append((sym, ltp, reason, pnl))

    # --- 2. open new top picks with spare cash ----------------------------
    per_name_budget = config.PAPER_CAPITAL * config.MAX_ALLOCATION_PER_NAME
    entries = []
    for pick in build_watchlist(csv_path):
        for sym in pick.symbols:
            if sym in pf.holdings:
                continue
            ltp = _safe_price(ds, sym)
            if ltp is None:
                continue
            budget = min(per_name_budget, pf.cash)
            qty = int(budget // ltp)
            if qty <= 0:
                continue
            a = _safe_atr(ds, sym)
            if pf.buy(sym, qty, ltp, atr=a, reason="entry"):
                entries.append((sym, ltp, qty))

    # --- 3. record + save -------------------------------------------------
    price_of = lambda s: (_safe_price(ds, s) or pf.holdings.get(s, {}).get("avg_price", 0.0))
    equity = pf.equity(price_of)
    unreal = pf.unrealized_pnl(price_of)
    from .portfolio import _today
    pf.history.append({"date": _today(), "equity": round(equity, 2)})
    pf.save()

    result = {
        "portfolio": pf, "datasource": ds, "real_data": real_data,
        "equity": equity, "cash": pf.cash, "holdings_value": pf.holdings_value(price_of),
        "unrealized": unreal, "realized": pf.realized_pnl,
        "total_pnl": equity - pf.starting_capital,
        "total_pnl_pct": (equity - pf.starting_capital) / pf.starting_capital * 100,
        "exits": exits, "entries": entries, "price_of": price_of,
    }
    if verbose:
        _print(result)
    return result


def _print(r: dict) -> None:
    pf = r["portfolio"]
    print("\n" + "=" * 66)
    print("  SectorBot · PAPER PORTFOLIO" + ("  (REAL Kite prices)" if r["real_data"]
          else "  (SYNTHETIC prices — NOT real)"))
    print("=" * 66)
    print(f"  Starting capital : Rs {pf.starting_capital:,.0f}")
    print(f"  Equity (now)     : Rs {r['equity']:,.0f}  "
          f"({r['total_pnl_pct']:+.2f}%)")
    print(f"  Cash             : Rs {r['cash']:,.0f}")
    print(f"  Holdings value   : Rs {r['holdings_value']:,.0f}")
    print(f"  Unrealised P&L   : Rs {r['unrealized']:,.0f}")
    print(f"  Realised P&L     : Rs {r['realized']:,.0f}")
    print("-" * 66)
    print(f"  Holdings ({len(pf.holdings)}):")
    for s, h in pf.holdings.items():
        print(f"    {s:12} qty {h['qty']:>5}  entry {h['avg_price']:>9.2f}  since {h['entry_date']}")
    if r["exits"]:
        print("  Exits this run:")
        for s, ltp, reason, pnl in r["exits"]:
            print(f"    SELL {s:12} @ {ltp:>9.2f}  [{reason}]  P&L {pnl:+,.0f}")
    print("=" * 66)
    if not r["real_data"]:
        print("  Set Kite keys to trade on real prices. Not advice.\n")


if __name__ == "__main__":
    run_paper_session()
