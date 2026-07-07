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
    strat = getattr(profile, "strategy", "rsi2")
    if strat == "momentum":
        return _run_momentum(profile, series, portfolio, live_prices)
    if strat == "strength":
        return _run_strength(profile, series, portfolio, live_prices)
    if strat == "leaders":
        return _run_leaders(profile, series, portfolio, live_prices)
    if strat == "scalein":
        return _run_scalein(profile, series, portfolio, live_prices)
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


def _hard_stopped(profile, h, px):
    """True if a hard stop-loss (fraction below ENTRY) is hit. Cuts a loser fast,
    before the peak-based trailing stop can trigger. 0 = off."""
    hs = getattr(profile, "hard_stop", 0.0)
    return bool(hs and h.get("entry_price") and px <= h["entry_price"] * (1 - hs))


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
        px = price_of(sym)
        recovered = cur is not None and cur > profile.exit_rsi
        stopped = _hard_stopped(profile, h, px)
        if stopped or recovered or h.get("bars_held", 0) >= profile.max_hold:
            reason = (f"{profile.hard_stop:.0%} stop-loss" if stopped
                      else "RSI recovered" if recovered else f"{profile.max_hold}-day hold")
            pnl = portfolio.sell(sym, px, reason=reason)
            sells.append({"symbol": sym, "price": round(px, 2),
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
        hstop = _hard_stopped(profile, h, px)
        stopped = hstop or (profile.trail and px <= peak * (1 - profile.trail))
        if stopped or h.get("bars_held", 0) >= profile.max_hold:
            reason = (f"{profile.hard_stop:.0%} stop-loss" if hstop
                      else f"{profile.trail:.0%} trailing stop" if stopped
                      else f"{profile.max_hold}-day hold")
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


def _run_strength(profile, series, portfolio, live_prices=None):
    """The whole-NSE STRENGTH swing (showdown winner: +5.94%/trade, PF 2.95).
    Buy strong-but-not-overbought names in an uptrend — RSI-14 inside [rsi_lo,
    rsi_hi] AND close > trend_ma-SMA — strongest first, and let them run on a
    trailing stop (peak-tracked, checked daily like the backtest)."""
    price_of = _price_of(series, portfolio, live_prices)
    today = _today()
    ma = max(2, profile.trend_ma)
    r_cache = {s: rsi(c, 14) for s, c in series.items() if len(c) > 14}
    s_cache = {s: sma(c, ma) for s, c in series.items() if len(c) >= ma}

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
        hstop = _hard_stopped(profile, h, px)
        stopped = hstop or (profile.trail and px <= peak * (1 - profile.trail))
        if stopped or h.get("bars_held", 0) >= profile.max_hold:
            reason = (f"{profile.hard_stop:.0%} stop-loss" if hstop
                      else f"{profile.trail:.0%} trailing stop" if stopped
                      else f"{profile.max_hold}-day hold")
            pnl = portfolio.sell(sym, px, reason=reason)
            sold_today.add(sym)
            sells.append({"symbol": sym, "price": round(px, 2),
                          "pnl": round(pnl, 2), "reason": reason})

    # --- 2. entries: RSI-14 in [lo,hi] AND above the trend SMA, strongest first
    candidates = []
    for sym, c in series.items():
        if sym in portfolio.holdings or sym in sold_today or len(c) < ma + 5:
            continue
        rr, ss = r_cache.get(sym), s_cache.get(sym)
        cur = (rr or [None])[-1]
        s200 = (ss or [None])[-1]
        price = price_of(sym)
        if cur is None or s200 is None or price <= 0:
            continue
        if not (profile.rsi_lo <= cur <= profile.rsi_hi and price > s200):
            continue
        candidates.append((cur, sym, price, c))
    candidates.sort(reverse=True)                # strongest RSI (within band) first

    per_name = profile.capital * profile.alloc_pct
    buys = []
    for cur, sym, price, c in candidates:
        budget = min(per_name, portfolio.cash)
        qty = int(budget // price)
        if qty <= 0:
            continue
        if portfolio.buy(sym, qty, price, entry_len=len(c)):
            portfolio.holdings[sym]["peak"] = price
            portfolio.holdings[sym]["rsi14"] = round(cur, 1)
            buys.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                         "rsi14": round(cur, 1)})

    return _result(profile, portfolio, buys, sells, price_of)


def _run_scalein(profile, series, portfolio, live_prices=None):
    """SCALE-IN (Connors-TPS): buy the RSI-2 dip in an uptrend and AVERAGE DOWN up
    to max_units as it keeps falling, so a small bounce exits most trades green.
    Exit the whole averaged position on RSI-2 recovery, a max-hold, or a
    catastrophe stop. High win rate (~73%), capped tail."""
    price_of = _price_of(series, portfolio, live_prices)
    r_cache = {s: rsi(c, 2) for s, c in series.items() if len(c) > 2}
    today = _today()
    ma = max(2, profile.trend_ma)
    max_units = max(1, getattr(profile, "max_units", 1))

    # --- 1. exits: RSI recovered, max hold, or catastrophe stop --------------
    sells, sold_today = [], set()
    for sym, h in list(portfolio.holdings.items()):
        c = series.get(sym)
        if not c:
            continue
        _tick_hold(h, today)
        cur = (r_cache.get(sym) or [None])[-1]
        px = price_of(sym)
        recovered = cur is not None and cur > profile.exit_rsi
        stopped = profile.stop and h["entry_price"] and px <= h["entry_price"] * (1 - profile.stop)
        if recovered or stopped or h.get("bars_held", 0) >= profile.max_hold:
            reason = ("RSI recovered" if recovered
                      else f"{profile.stop:.0%} stop" if stopped
                      else f"{profile.max_hold}-day hold")
            pnl = portfolio.sell(sym, px, reason=reason)
            sold_today.add(sym)
            sells.append({"symbol": sym, "price": round(px, 2),
                          "pnl": round(pnl, 2), "reason": reason})

    per_unit = profile.capital * profile.alloc_pct

    # --- 2. scale-in adds: still oversold, lower than the last add, room left --
    adds = []
    for sym, h in list(portfolio.holdings.items()):
        if sym in sold_today:
            continue
        c = series.get(sym)
        if not c:
            continue
        cur = (r_cache.get(sym) or [None])[-1]
        price = price_of(sym)
        if (cur is not None and cur < profile.entry_rsi and price > 0
                and h.get("units", 1) < max_units
                and price < h.get("last_add", h["entry_price"])):
            qty = int(min(per_unit, portfolio.cash) // price)
            if qty > 0 and portfolio.scale_in(sym, qty, price, entry_len=len(c)):
                adds.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                             "unit": h.get("units")})

    # --- 3. new entries: most-oversold uptrend dips first --------------------
    candidates = []
    for sym, c in series.items():
        if sym in portfolio.holdings or sym in sold_today or len(c) < ma + 5:
            continue
        cur = (r_cache.get(sym) or [None])[-1]
        if cur is None or cur >= profile.entry_rsi:
            continue
        s = sma(c, ma)
        if not (s[-1] is not None and c[-1] > s[-1]):
            continue
        candidates.append((cur, sym, price_of(sym), c))
    candidates.sort()

    buys = []
    for cur, sym, price, c in candidates:
        if price <= 0:
            continue
        qty = int(min(per_unit, portfolio.cash) // price)
        if qty <= 0:
            continue
        if portfolio.scale_in(sym, qty, price, entry_len=len(c)):
            portfolio.holdings[sym]["rsi2_entry"] = round(cur, 1)
            buys.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                         "rsi2": round(cur, 1)})

    return _result(profile, portfolio, buys + adds, sells, price_of)


def _run_leaders(profile, series, portfolio, live_prices=None):
    """MOMENTUM LEADERS (catcher winner: +7.80%/trade, PF 3.37). Buy the stocks
    that are actually GOING UP — up > mom_min over mom_days AND above the trend
    SMA — strongest momentum first, and let them run on a wide trailing stop."""
    price_of = _price_of(series, portfolio, live_prices)
    today = _today()
    ma = max(2, profile.trend_ma)
    look = max(2, profile.mom_days)
    s_cache = {s: sma(c, ma) for s, c in series.items() if len(c) >= ma}

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
        hstop = _hard_stopped(profile, h, px)
        stopped = hstop or (profile.trail and px <= peak * (1 - profile.trail))
        if stopped or h.get("bars_held", 0) >= profile.max_hold:
            reason = (f"{profile.hard_stop:.0%} stop-loss" if hstop
                      else f"{profile.trail:.0%} trailing stop" if stopped
                      else f"{profile.max_hold}-day hold")
            pnl = portfolio.sell(sym, px, reason=reason)
            sold_today.add(sym)
            sells.append({"symbol": sym, "price": round(px, 2),
                          "pnl": round(pnl, 2), "reason": reason})

    # --- 2. entries: strong momentum in an uptrend, strongest first -----------
    candidates = []
    for sym, c in series.items():
        if sym in portfolio.holdings or sym in sold_today or len(c) < max(ma, look) + 1:
            continue
        s200 = (s_cache.get(sym) or [None])[-1]
        price = price_of(sym)
        if s200 is None or price <= 0 or c[-look] <= 0:
            continue
        mom = price / c[-look] - 1.0                  # return over the momentum window
        if not (price > s200 and mom > profile.mom_min):
            continue
        candidates.append((mom, sym, price, c))
    candidates.sort(reverse=True)                     # strongest momentum gets cash first

    per_name = profile.capital * profile.alloc_pct
    buys = []
    for mom, sym, price, c in candidates:
        budget = min(per_name, portfolio.cash)
        qty = int(budget // price)
        if qty <= 0:
            continue
        if portfolio.buy(sym, qty, price, entry_len=len(c)):
            portfolio.holdings[sym]["peak"] = price
            portfolio.holdings[sym]["mom"] = round(mom * 100, 1)
            buys.append({"symbol": sym, "price": round(price, 2), "qty": qty,
                         "mom": round(mom * 100, 1)})

    return _result(profile, portfolio, buys, sells, price_of)
