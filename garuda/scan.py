"""Garuda daily scanner — turns the proven setups into live signals + a portfolio.

Two engines, dispatched per profile by `profile.strategy`:

  • "rsi2" (Smallcap, Microcap) — mean reversion, uptrend-filtered:
      SELL any holding whose RSI-2 recovered above exit_rsi, or held max_hold bars.
      BUY the most-oversold fresh names (RSI-2 < entry_rsi) that are ALSO above
      their 200-day average (use_trend), sized at ~alloc_pct each, strongest
      signal first, until cash runs out — NO position-count cap.

  • "momentum" (Next 50) — 20-day breakout + trailing stop:
      SELL any holding that gave back `trail` off its peak, or held max_hold bars.
      BUY names making a fresh `breakout`-day high, strongest momentum first.

Prices come from the series passed in (latest close, or a live LTP dict). PAPER
ONLY — it updates the paper portfolio; it never places a real order.
"""

from .portfolio import LivePortfolio, _today
from .setups import rsi, sma


def run_scan(profile, series: dict, portfolio: LivePortfolio, live_prices=None):
    """Dispatch to the profile's engine. series: {symbol: [closes]} (latest last).
    live_prices: optional {symbol: ltp} to price against right now."""
    if getattr(profile, "strategy", "rsi2") == "momentum":
        return _run_momentum(profile, series, portfolio, live_prices)
    return _run_rsi2(profile, series, portfolio, live_prices)


def _price_of(series, portfolio, live_prices):
    def price_of(sym):
        if live_prices and sym in live_prices and live_prices[sym] > 0:
            return live_prices[sym]
        c = series.get(sym)
        if c:
            return c[-1]
        return portfolio.holdings.get(sym, {}).get("entry_price", 0.0)
    return price_of


def _tick_hold(h, today):
    """Advance a holding's bars_held once per new scan-date (restart-safe)."""
    if h.get("last_date") != today:
        h["bars_held"] = h.get("bars_held", 0) + 1
        h["last_date"] = today


def _result(profile, portfolio, buys, sells, price_of):
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


def _run_rsi2(profile, series, portfolio, live_prices=None):
    price_of = _price_of(series, portfolio, live_prices)
    r_cache = {s: rsi(c, 2) for s, c in series.items() if len(c) > 2}
    today = _today()

    # --- 1. exits -------------------------------------------------------------
    sells = []
    for sym, h in list(portfolio.holdings.items()):
        c = series.get(sym)
        if not c:
            continue
        _tick_hold(h, today)
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
        if profile.use_trend:                    # the uptrend filter: only buy dips in uptrends
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

    return _result(profile, portfolio, buys, sells, price_of)


def _run_momentum(profile, series, portfolio, live_prices=None):
    """20-day breakout entry, trailing-stop exit — the Next 50 winner. Peak is
    tracked in the holding and advanced on every scan, so the trailing stop
    checks daily against the running high (matching the daily-bar backtest)."""
    price_of = _price_of(series, portfolio, live_prices)
    look = max(2, profile.breakout)
    today = _today()

    # --- 1. exits: trailing stop off the running peak, or max hold ------------
    sells, sold_today = [], set()
    for sym, h in list(portfolio.holdings.items()):
        c = series.get(sym)
        if not c:
            continue
        _tick_hold(h, today)
        px = price_of(sym)
        peak = max(h.get("peak", h["entry_price"]), px)
        h["peak"] = peak
        stopped = profile.trail and px <= peak * (1 - profile.trail)
        if stopped or h.get("bars_held", 0) >= profile.max_hold:
            reason = f"{profile.trail:.0%} trailing stop" if stopped \
                else f"{profile.max_hold}-day hold"
            pnl = portfolio.sell(sym, px, reason=reason)
            sold_today.add(sym)
            sells.append({"symbol": sym, "price": round(px, 2),
                          "pnl": round(pnl, 2), "reason": reason})

    # --- 2. entries: fresh N-day highs, strongest momentum first --------------
    # skip anything just sold this scan — never exit and re-enter on the same bar
    candidates = []
    for sym, c in series.items():
        if sym in portfolio.holdings or sym in sold_today or len(c) < look + 1:
            continue
        price = price_of(sym)
        if price <= 0:
            continue
        prior_high = max(c[-(look - 1):])        # highest of the previous look-1 closes
        if price < prior_high:                   # not a fresh N-day high
            continue
        strength = price / c[-look] if c[-look] > 0 else 0.0
        candidates.append((strength, sym, price, c))
    candidates.sort(reverse=True)                # strongest breakout gets cash first

    per_name = profile.capital * profile.alloc_pct
    buys = []
    for strength, sym, price, c in candidates:
        budget = min(per_name, portfolio.cash)
        qty = int(budget // price)
        if qty <= 0:
            continue
        if portfolio.buy(sym, qty, price, entry_len=len(c)):
            portfolio.holdings[sym]["peak"] = price
            portfolio.holdings[sym]["mom"] = round((strength - 1) * 100, 1)
            buys.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                         "mom": round((strength - 1) * 100, 1)})

    return _result(profile, portfolio, buys, sells, price_of)
