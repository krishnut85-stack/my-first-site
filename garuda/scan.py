"""Garuda daily scanner — turns the proven setup into live signals + a portfolio.

Each run, for a profile (smallcap or microcap):
  • SELL any holding whose RSI-2 recovered above exit_rsi, or that has been held
    max_hold bars.
  • BUY the most-oversold fresh names (RSI-2 < entry_rsi), sized at ~alloc_pct of
    capital each, filling the strongest signals first until cash runs out — NO
    position-count cap.
  • Record an equity point.

Prices come from the series passed in (latest close, or a live LTP dict). PAPER
ONLY — it updates the paper portfolio; it never places a real order.
"""

from .portfolio import LivePortfolio, _today
from .setups import rsi, sma


def run_scan(profile, series: dict, portfolio: LivePortfolio, live_prices=None):
    """series: {symbol: [closes]} (latest last). live_prices: optional
    {symbol: ltp} to price against right now instead of the last close."""
    def price_of(sym):
        if live_prices and sym in live_prices and live_prices[sym] > 0:
            return live_prices[sym]
        c = series.get(sym)
        if c:
            return c[-1]
        return portfolio.holdings.get(sym, {}).get("entry_price", 0.0)

    r_cache = {s: rsi(c, 2) for s, c in series.items() if len(c) > 2}

    # --- 1. exits -------------------------------------------------------------
    # Count hold-days from calendar dates, not series length: the daily fetch is
    # a rolling window so len(series) is ~constant day to day. Increment once per
    # new scan-date so restarts don't over-count.
    today = _today()
    sells = []
    for sym, h in list(portfolio.holdings.items()):
        c = series.get(sym)
        if not c:
            continue
        if h.get("last_date") != today:
            h["bars_held"] = h.get("bars_held", 0) + 1
            h["last_date"] = today
        cur = (r_cache.get(sym) or [None])[-1]
        recovered = cur is not None and cur > profile.exit_rsi
        if recovered or h.get("bars_held", 0) >= profile.max_hold:
            reason = "RSI recovered" if recovered else f"{profile.max_hold}-day hold"
            pnl = portfolio.sell(sym, price_of(sym), reason=reason)
            sells.append({"symbol": sym, "price": round(price_of(sym), 2),
                          "pnl": round(pnl, 2), "reason": reason})

    # --- 2. entries: most-oversold first, sized by cash (no count cap) --------
    candidates = []
    for sym, c in series.items():
        if sym in portfolio.holdings or len(c) < profile.max_hold + 5:
            continue
        rr = r_cache.get(sym)
        cur = (rr or [None])[-1]
        if cur is None or cur >= profile.entry_rsi:
            continue
        if profile.use_trend:
            s = sma(c, 200)
            if not (s[-1] is not None and c[-1] > s[-1]):
                continue
        candidates.append((cur, sym, price_of(sym)))
    candidates.sort()   # ascending RSI-2 -> most oversold first

    per_name = profile.capital * profile.alloc_pct
    buys = []
    for cur, sym, price in candidates:
        if price <= 0:
            continue
        budget = min(per_name, portfolio.cash)
        qty = int(budget // price)
        if qty <= 0:
            continue
        if portfolio.buy(sym, qty, price, entry_len=len(series[sym])):
            portfolio.holdings[sym]["rsi2_entry"] = round(cur, 1)
            buys.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                         "rsi2": round(cur, 1)})

    equity = portfolio.equity(price_of)
    portfolio.history.append({"date": _today(), "equity": round(equity, 2)})

    return {
        "profile": profile.name,
        "buys": buys, "sells": sells,
        "positions": len(portfolio.holdings),
        "cash": round(portfolio.cash, 2),
        "equity": round(equity, 2),
        "total_pnl_pct": round((equity / portfolio.starting_capital - 1) * 100, 2),
    }
