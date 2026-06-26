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


def _holding_days(entry_date) -> int:
    """Calendar days a position has been held, from its entry_date (YYYY-MM-DD)."""
    if not entry_date:
        return 0
    try:
        from datetime import date, datetime
        from .data_loader import IST
        y, m, d = (int(x) for x in str(entry_date).split("-"))
        return (datetime.now(IST).date() - date(y, m, d)).days
    except Exception:  # noqa: BLE001
        return 0


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


def run_paper_session(verbose: bool = True, csv_path=None,
                      ranked_symbols=None, levels=None) -> dict:
    """Run one paper session.

    If `ranked_symbols` is given (best-first), Mayura trades THAT list directly
    (e.g. a Trendlyne breakout watchlist) instead of ranking industries → stocks.
    `levels` is an optional {symbol: breakout_level} map (e.g. entry SMA50) used
    for the failed-breakout exit. All risk rules, the regime filter and sizing
    still apply identically."""
    ds = get_datasource()
    real_data = not isinstance(ds, PaperDataSource)

    # SAFETY: never trade a real portfolio with synthetic prices. If real data
    # is required (USE_KITE_DATA) but unavailable (token expired, missing keys,
    # wrong shell/cron env), refuse and leave the portfolio UNTOUCHED. Mixing
    # real entry prices with synthetic prices would fire bogus stop-losses and
    # destroy the track record.
    if config.USE_KITE_DATA and not real_data:
        msg = ("ABORT: real Kite data required (USE_KITE_DATA=True) but "
               "unavailable — token/keys missing or invalid. Portfolio left "
               "UNCHANGED. Fix the Kite token and re-run. (For a synthetic "
               "demo set USE_KITE_DATA=False.)")
        if verbose:
            print("\n" + "!" * 66 + f"\n  {msg}\n" + "!" * 66 + "\n")
        return {"aborted": True, "message": msg, "real_data": False}

    pf = Portfolio.load()

    # Today's ranked symbols (best first) and the buffer "keep" band.
    if ranked_symbols is None:
        picks = build_watchlist(csv_path)
        ranked_symbols = []
        for pick in picks:
            for sym in pick.symbols:
                if sym not in ranked_symbols:
                    ranked_symbols.append(sym)
    keep_band = set(ranked_symbols[: config.SELL_RANK_BUFFER])  # e.g. top 15

    # --- 1. manage existing positions -------------------------------------
    exits = []
    for sym in list(pf.holdings.keys()):
        ltp = _safe_price(ds, sym)
        if ltp is None:
            continue
        h = pf.holdings[sym]
        if config.REBALANCE:
            # buffer band: sell ONLY when it drops out of the top SELL_RANK_BUFFER
            if sym not in keep_band:
                pnl = pf.sell(sym, ltp,
                              reason=f"rotated out (left top {config.SELL_RANK_BUFFER})")
                exits.append((sym, ltp, "rotated out", pnl))
                continue
            # still within the band: keep, but honor a hard stop-loss as a floor
            change = (ltp - h["avg_price"]) / h["avg_price"]
            if change <= -config.STOP_LOSS_PCT:
                pnl = pf.sell(sym, ltp, reason=f"stop-loss {change:+.1%}")
                exits.append((sym, ltp, "stop-loss", pnl))
        else:
            # low-churn: FAILED-BREAKOUT / TIME STOP / SL / TP / trailing / ATR
            # Failed-breakout exit: price fell back below the breakout level
            # (the SMA50 captured at entry) -> the breakout failed, get out.
            if config.USE_FAILED_BREAKOUT_EXIT:
                lvl = h.get("breakout_level")
                if lvl and ltp < lvl:
                    pnl = pf.sell(sym, ltp, reason=f"failed breakout (<SMA50 {lvl:.0f})")
                    exits.append((sym, ltp, "failed breakout", pnl))
                    continue
            # Time stop ("dead money"): held too long without progress -> exit
            # and free the capital. A running stock (gain above the threshold)
            # is left to the trailing stop, so winners are never time-stopped.
            if config.MAX_HOLDING_DAYS:
                gain = (ltp - h["avg_price"]) / h["avg_price"]
                days = _holding_days(h.get("entry_date"))
                if days >= config.MAX_HOLDING_DAYS and gain < config.TIME_STOP_MIN_GAIN_PCT:
                    pnl = pf.sell(sym, ltp, reason=f"time stop ({days}d, {gain:+.1%})")
                    exits.append((sym, ltp, "time stop", pnl))
                    continue
            state = PositionState(sym, h["avg_price"], h["qty"],
                                  atr=h.get("atr", 0.0),
                                  peak_price=h.get("peak_price", h["avg_price"]))
            should_exit, reason = decide_exit(state, ltp)
            h["peak_price"] = state.peak_price
            if should_exit:
                pnl = pf.sell(sym, ltp, reason=reason)
                exits.append((sym, ltp, reason, pnl))

    # --- 2. fill open slots with the best-ranked names not already held ----
    # REGIME FILTER: only open NEW positions when the broad market is trending
    # up. In a downtrend we hold cash (existing exits above still run). This is
    # the single biggest protection against momentum-crash drawdowns.
    from .regime import market_in_uptrend
    uptrend = market_in_uptrend(ds)
    regime_blocked = config.USE_REGIME_FILTER and not uptrend

    per_name_budget = min(config.PAPER_CAPITAL * config.MAX_ALLOCATION_PER_NAME,
                          config.PAPER_CAPITAL / max(config.MAX_POSITIONS, 1))
    entries = []
    if not regime_blocked:
        for sym in ranked_symbols:
            if config.REBALANCE and len(pf.holdings) >= config.MAX_POSITIONS:
                break  # already hold the target number of names
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
            lvl = (levels or {}).get(sym)
            if pf.buy(sym, qty, ltp, atr=a, reason="entry", breakout_level=lvl):
                entries.append((sym, ltp, qty))

    # --- 3. record + save -------------------------------------------------
    # Snapshot each price ONCE so every figure in the report reconciles
    # (live prices tick between fetches otherwise: equity != cash + holdings).
    price_snapshot = {
        s: (_safe_price(ds, s) or pf.holdings[s]["avg_price"])
        for s in pf.holdings
    }
    price_of = lambda s: price_snapshot.get(s) or pf.holdings.get(s, {}).get("avg_price", 0.0)
    equity = pf.equity(price_of)
    unreal = pf.unrealized_pnl(price_of)
    from .portfolio import _today
    # Record the Nifty level alongside equity (real data only) so the scorecard
    # can compare the strategy to a simple index fund over the same period.
    point = {"date": _today(), "equity": round(equity, 2)}
    if real_data:
        idx_level = _safe_price(ds, config.REGIME_INDEX)
        if idx_level:
            point["index"] = round(idx_level, 2)
    pf.history.append(point)
    pf.save()

    from .data_loader import active_csv_info
    from .scorecard import compute_scorecard
    data_info = active_csv_info(csv_path)

    result = {
        "portfolio": pf, "datasource": ds, "real_data": real_data,
        "equity": equity, "cash": pf.cash, "holdings_value": pf.holdings_value(price_of),
        "unrealized": unreal, "realized": pf.realized_pnl,
        "total_pnl": equity - pf.starting_capital,
        "total_pnl_pct": (equity - pf.starting_capital) / pf.starting_capital * 100,
        "exits": exits, "entries": entries, "price_of": price_of,
        "regime_uptrend": uptrend, "regime_blocked": regime_blocked,
        "data_date": data_info["date"], "data_stale": data_info["stale"],
        "scorecard": compute_scorecard(pf),
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
    if r.get("data_date"):
        warn = "  ⚠️ STALE — upload today's CSV!" if r.get("data_stale") else ""
        print(f"  Data file date   : {r['data_date']}{warn}")
    if r.get("regime_blocked"):
        print(f"  Regime           : DOWNTREND — holding cash, no new buys "
              f"({config.REGIME_INDEX} below {config.REGIME_SMA}-DMA)")
    elif config.USE_REGIME_FILTER and r["real_data"]:
        print(f"  Regime           : uptrend — new buys allowed")
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
