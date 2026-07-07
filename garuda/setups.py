"""Named, specific SETUPS — the honest route to a high win rate.

High win rates don't come from "catch any winning stock". They come from a
narrow, well-defined setup with a real statistical tendency behind it. This
module implements the canonical one — the **RSI-2 oversold bounce** (Larry
Connors) — a mean-reversion setup famous for high backtested win rates and, not
coincidentally, the same family as your Phoenix edge:

  ENTRY : stock in a long-term UPTREND (close > SMA-200) AND a sharp short-term
          drop (RSI-2 below ENTRY_RSI, e.g. < 10). Buy the fear.
  EXIT  : RSI-2 recovers above EXIT_RSI (e.g. > 65), or after MAX_HOLD days.
          Sell the relief.

It reports win rate — but ALSO average return per trade after costs, profit
factor and expectancy, because a high win rate that doesn't clear costs is a
trap. No lookahead: every signal on day i uses only closes up to day i.

This is a REAL technique with a genuine edge historically — but backtest edges
can shrink forward and mean-reversion carries 'catch a falling knife' tail risk.
Measured, not promised.
"""

import csv
import statistics

from . import config


def rsi(closes, period: int = 2):
    """Wilder-style RSI over `period` (simple-average variant, fine for RSI-2).
    Returns a list aligned to closes (None during warmup)."""
    out = [None] * len(closes)
    for i in range(period, len(closes)):
        ag = al = 0.0
        for j in range(i - period + 1, i + 1):
            ch = closes[j] - closes[j - 1]
            if ch >= 0:
                ag += ch
            else:
                al -= ch
        ag /= period
        al /= period
        out[i] = 100.0 if al == 0 else 100.0 - 100.0 / (1.0 + ag / al)
    return out


def sma(closes, period: int):
    """Simple moving average, O(n) via a rolling sum (was O(n*period))."""
    out = [None] * len(closes)
    if period <= 0 or len(closes) < period:
        return out
    run = sum(closes[:period])
    out[period - 1] = run / period
    for i in range(period, len(closes)):
        run += closes[i] - closes[i - period]
        out[i] = run / period
    return out


def _simulate(closes, r, s, entry_rsi, exit_rsi, trend_sma, max_hold, cost,
              stop_loss, profit_target, use_trend, start_i=0):
    """The trade loop given PRE-COMPUTED rsi (r) and sma (s). Split out so the
    sweep computes the indicators once per stock, not once per parameter combo."""
    trades = []
    i = trend_sma if use_trend else 2   # no trend filter -> no SMA warmup needed
    n = len(closes)
    while i < n - 1:
        in_uptrend = (not use_trend) or (s[i] is not None and closes[i] > s[i])
        if in_uptrend and (r[i] is not None and r[i] < entry_rsi) and closes[i] > 0:
            entry = closes[i]
            j = i + 1
            while j < n - 1:
                px = closes[j]
                if px <= 0:
                    break
                if stop_loss and px <= entry * (1 - stop_loss):
                    break
                if profit_target and px >= entry * (1 + profit_target):
                    break
                if (r[j] is not None and r[j] > exit_rsi) or (j - i) >= max_hold:
                    break
                j += 1
            if closes[j] > 0 and i >= start_i:   # start_i>0 -> out-of-sample window
                trades.append((closes[j] - entry) / entry - 2 * cost)
            i = j + 1
        else:
            i += 1
    return trades


def oversold_bounce_trades(closes, entry_rsi=10.0, exit_rsi=65.0,
                           trend_sma=200, max_hold=10, cost_per_side=None,
                           stop_loss=0.0, profit_target=0.0, use_trend=True, oos=0.0):
    """Return a list of per-trade net returns for one stock's daily closes.

    stop_loss / profit_target (fractions, 0 = off) cut losers / lock winners at
    the close that breaches them — the principled fix for a high win rate that
    still loses (it caps the rare falling-knife trades that eat the small wins).
    Checked at the daily close, so there is no intraday lookahead."""
    cost = config.CROSS_COST_PER_SIDE if cost_per_side is None else cost_per_side
    need = (trend_sma + 5) if use_trend else (max_hold + 5)
    if len(closes) < need:
        return []
    r = rsi(closes, 2)
    s = sma(closes, trend_sma) if use_trend else [None] * len(closes)
    start_i = int(len(closes) * (1 - oos)) if 0 < oos < 1 else 0
    return _simulate(closes, r, s, entry_rsi, exit_rsi, trend_sma, max_hold,
                     cost, stop_loss, profit_target, use_trend, start_i)


def backtest_costs(panel: dict, cost_levels, entry_rsi=5.0, exit_rsi=85.0, max_hold=30):
    """RSI-2 edge at rising cost/side levels — the honest liquidity/penny test:
    an edge that only survives at 0.1% costs is untradeable in illiquid names."""
    prepared = [(c, rsi(c, 2)) for c in panel.values() if len(c) >= max_hold + 5]
    out = []
    for cost in cost_levels:
        rets = []
        for closes, r in prepared:
            rets.extend(_simulate(closes, r, [None] * len(closes), entry_rsi, exit_rsi,
                                  2, max_hold, cost, 0.0, 0.0, False))
        out.append((cost, _stats(rets)))
    return out


def format_costs(rows, source: str) -> str:
    lines = ["=" * 74,
             f"  {config.BOT_NAME} · EDGE vs SLIPPAGE   (RSI-2, entry<5 exit>85 30d)",
             f"  Data: {source}", "=" * 74,
             f"  {'cost/side':>9}{'round-trip':>12}{'win%':>7}{'avg%/trade':>12}{'PF':>7}  verdict",
             "-" * 74]
    for cost, s in rows:
        if not s:
            continue
        v = ("dead" if s["avg"] <= 0 else "thin" if (s["pf"] or 0) < 1.2 else "edge")
        lines.append(f"  {cost * 100:>8.2f}%{cost * 200:>11.2f}%{s['win']:>6.0f}%"
                     f"{s['avg']:>+11.2f}%{(s['pf'] or 0):>7.2f}  {v}")
    lines += ["-" * 74,
              "  Illiquid/penny names really cost 1-5% a side to get in and out.",
              "  Read where 'avg%/trade' turns negative — beyond that, the edge is fiction.",
              "=" * 74]
    return "\n".join(lines)


def _dated_trades(closes, r, entry_rsi, exit_rsi, max_hold, cost):
    """[(entry_index, exit_index, net_return)] for one stock (time-ordered)."""
    trades, i, n = [], 2, len(closes)
    while i < n - 1:
        if r[i] is not None and r[i] < entry_rsi and closes[i] > 0:
            entry, j = closes[i], i + 1
            while j < n - 1 and not ((r[j] is not None and r[j] > exit_rsi) or (j - i) >= max_hold):
                j += 1
            if closes[j] > 0:
                trades.append((i, j, (closes[j] - entry) / entry - 2 * cost))
            i = j + 1
        else:
            i += 1
    return trades


def backtest_sizing(panel: dict, entry_rsi=5.0, exit_rsi=85.0, max_hold=30,
                    base=0.02, cap=0.9):
    """Portfolio equity sim comparing position-sizing DISCIPLINE. Same trades,
    different sizing -> shows the effect on max drawdown and final return.
    (Edge per trade is identical; discipline shapes RISK, which is the point.)"""
    cost = config.CROSS_COST_PER_SIDE
    trades = []
    for closes in panel.values():
        if len(closes) >= max_hold + 5:
            r = rsi(closes, 2)
            trades += _dated_trades(closes, r, entry_rsi, exit_rsi, max_hold, cost)
    trades.sort(key=lambda t: t[0])              # by entry day (approx real order)

    def run(sizer):
        eq, peak, mdd, mult, prev = 1.0, 1.0, 0.0, 1.0, None
        for _, _, ret in trades:
            mult = sizer(prev, mult)
            eq *= 1.0 + min(base * mult, cap) * ret
            peak = max(peak, eq)
            mdd = min(mdd, eq / peak - 1.0)
            prev = ret
        return {"ret": (eq - 1) * 100, "mdd": mdd * 100}

    rules = {
        "Flat 2%/trade (current Garuda)": lambda p, m: 1.0,
        "Dux: halve size after a loss": lambda p, m: 1.0 if p is None or p > 0 else 0.5,
        "Dux: cut hard after a loss (x0.33)": lambda p, m: 1.0 if p is None or p > 0
        else max(0.33, m * 0.33),
        "Anti (double up after a loss)": lambda p, m: 1.0 if p is None or p > 0
        else min(4.0, m * 2.0),
    }
    return {name: run(fn) for name, fn in rules.items()}, len(trades)


def format_sizing(res, ntr, source: str) -> str:
    rows, _ = res if isinstance(res, tuple) else (res, 0)
    lines = ["=" * 76,
             f"  {config.BOT_NAME} · SIZING DISCIPLINE   ({ntr} trades, {source})",
             "  Same trades & edge — only the position sizing differs (Dux's rules).",
             "=" * 76,
             f"  {'sizing rule':<40}{'total return%':>15}{'max drawdown%':>16}",
             "-" * 76]
    for name, s in rows.items():
        lines.append(f"  {name:<40}{s['ret']:>+14.1f}%{s['mdd']:>+15.1f}%")
    lines += ["-" * 76,
              "  Discipline doesn't add return — it cuts DRAWDOWN (smaller worst-case loss).",
              "  'Anti' (adding after losses) is the gambler's trap: watch its drawdown blow out.",
              "=" * 76]
    return "\n".join(lines)


def _rolling_std(closes, period):
    out = [None] * len(closes)
    for i in range(period - 1, len(closes)):
        w = closes[i - period + 1:i + 1]
        out[i] = statistics.pstdev(w)
    return out


def _run_strategy(closes, entry_ok, exit_ok, max_hold, cost, start=2,
                  stop=0.0, target=0.0, trail=0.0):
    """Generic long-only trade loop. entry_ok(i)->bool, exit_ok(j,i)->bool, plus
    optional profit-locking: stop-loss, profit target, and trailing stop (all
    fractions, 0=off), checked at the daily close (no intraday lookahead)."""
    trades, i, n = [], max(start, 2), len(closes)
    while i < n - 1:
        if closes[i] > 0 and entry_ok(i):
            entry, j, peak = closes[i], i + 1, closes[i]
            while j < n - 1:
                px = closes[j]
                peak = max(peak, px)
                if ((stop and px <= entry * (1 - stop)) or
                        (target and px >= entry * (1 + target)) or
                        (trail and px <= peak * (1 - trail)) or
                        exit_ok(j, i) or (j - i) >= max_hold):
                    break
                j += 1
            if closes[j] > 0:
                trades.append((closes[j] - entry) / entry - 2 * cost)
            i = j + 1
        else:
            i += 1
    return trades


def compare_strategies(panel: dict, cost=None) -> dict:
    """Run 7 genuinely DIFFERENT long-only strategies on the same data so we can
    see whether anything beats RSI-2 mean-reversion (not just tune it)."""
    cost = config.CROSS_COST_PER_SIDE if cost is None else cost
    res = {}

    def add(name, rets):
        res.setdefault(name, []).extend(rets)

    for closes in panel.values():
        n = len(closes)
        if n < 60:
            continue
        r2 = rsi(closes, 2)
        r14 = rsi(closes, 14)
        s10, s20, s50 = sma(closes, 10), sma(closes, 20), sma(closes, 50)
        s200 = sma(closes, 200)
        sd20 = _rolling_std(closes, 20)
        hi20 = [max(closes[max(0, i - 19):i + 1]) for i in range(n)]
        lo10 = [min(closes[max(0, i - 9):i + 1]) for i in range(n)]

        def up(i):    # consecutive
            return closes[i] > closes[i - 1]

        # 1. RSI-2 reversion (the current live strategy)
        add("RSI-2 reversion (LIVE)", _run_strategy(closes,
            lambda i: r2[i] is not None and r2[i] < 5,
            lambda j, i: r2[j] is not None and r2[j] > 85, 30, cost))
        # 2. RSI-2 only in an uptrend (close > 200-SMA)
        add("RSI-2 + uptrend (>200SMA)", _run_strategy(closes,
            lambda i: r2[i] is not None and r2[i] < 5 and s200[i] is not None and closes[i] > s200[i],
            lambda j, i: r2[j] is not None and r2[j] > 85, 30, cost, start=200))
        # 3. Bollinger reversion (buy lower band, exit middle)
        add("Bollinger reversion (20,2)", _run_strategy(closes,
            lambda i: sd20[i] is not None and closes[i] < s20[i] - 2 * sd20[i],
            lambda j, i: s20[j] is not None and closes[j] > s20[j], 20, cost, start=20))
        # 4. 3 down days -> bounce (simple reversion)
        add("3 down-days dip buy", _run_strategy(closes,
            lambda i: i > 3 and closes[i] < closes[i - 1] < closes[i - 2] < closes[i - 3],
            lambda j, i: j >= i + 2 and closes[j] > closes[j - 1] > closes[j - 2], 10, cost, start=4))
        # 5. 20-day breakout, exit on 10-day low (Donchian momentum)
        add("20d breakout (momentum)", _run_strategy(closes,
            lambda i: closes[i] >= hi20[i] and closes[i] > 0,
            lambda j, i: closes[j] <= lo10[j], 60, cost, start=20))
        # 6. MOMENTUM + PROFIT LOCK: breakout, take +12% or a 10% trailing stop
        add("Momentum + profit lock (12%/trail10%)", _run_strategy(closes,
            lambda i: closes[i] >= hi20[i] and closes[i] > 0,
            lambda j, i: False, 90, cost, start=20, target=0.12, trail=0.10))
        # 7. MOMENTUM + trailing stop only (let winners run, lock the giveback)
        add("Momentum + trailing stop 15%", _run_strategy(closes,
            lambda i: closes[i] >= hi20[i] and closes[i] > 0,
            lambda j, i: False, 120, cost, start=20, trail=0.15))
        # 8. 10/50 SMA golden cross (trend-following)
        add("10/50 SMA cross (trend)", _run_strategy(closes,
            lambda i: s10[i] is not None and s50[i] is not None and s10[i] > s50[i]
            and s10[i - 1] <= s50[i - 1],
            lambda j, i: s10[j] is not None and s50[j] is not None and s10[j] < s50[j], 90, cost, start=51))
        # 9. RSI-14 reversion (the "normal" RSI everyone uses)
        add("RSI-14 reversion (30/70)", _run_strategy(closes,
            lambda i: r14[i] is not None and r14[i] < 30,
            lambda j, i: r14[j] is not None and r14[j] > 70, 20, cost, start=14))
        # 10. STRENGTH swing (the Indian positional-swing filter): buy strong-but-
        #     not-overbought stocks in an uptrend (close>200SMA, RSI-14 55-70) and
        #     let them run with a 12% trailing stop. Buys STRENGTH, not dips — the
        #     kind of setup that can catch momentum runners RSI-2 never touches.
        #     (ADX>25 + volume are further filters; added once OHLCV data is on.)
        add("Strength swing RSI-14 55-70 (>200SMA)", _run_strategy(closes,
            lambda i: (s200[i] is not None and closes[i] > s200[i]
                       and r14[i] is not None and 55 <= r14[i] <= 70),
            lambda j, i: False, 90, cost, start=200, trail=0.12))

    return {name: _stats(rets) for name, rets in res.items()}


def compare_momentum(panel: dict, cost=None) -> dict:
    """'Catch the stocks going UP' — momentum variants that buy active strength /
    new highs and exit ONLY on a trailing stop (let winners run). Different from
    the STRENGTH book (which buys the RSI-55-70 pullback) — these chase breakouts
    and new highs. Which flavor actually pays after costs on this universe?"""
    cost = config.CROSS_COST_PER_SIDE if cost is None else cost
    res = {}

    def add(name, rets):
        res.setdefault(name, []).extend(rets)

    for closes in panel.values():
        n = len(closes)
        if n < 260:
            continue
        s20, s50, s200 = sma(closes, 20), sma(closes, 50), sma(closes, 200)
        hi20 = [max(closes[max(0, i - 19):i + 1]) for i in range(n)]
        hi55 = [max(closes[max(0, i - 54):i + 1]) for i in range(n)]
        hi252 = [max(closes[max(0, i - 251):i + 1]) for i in range(n)]

        # 1. NEW 52-WEEK HIGH breakout — the strongest "going up" signal — trail 20%
        add("52-week-high breakout · trail 20%", _run_strategy(closes,
            lambda i, _c=closes, _h=hi252: _c[i] >= _h[i] and _c[i] > 0,
            lambda j, i: False, 250, cost, start=252, trail=0.20))
        # 2. 55-day Donchian breakout (Turtle-style) — trail 15%
        add("55-day-high breakout · trail 15%", _run_strategy(closes,
            lambda i, _c=closes, _h=hi55: _c[i] >= _h[i] and _c[i] > 0,
            lambda j, i: False, 180, cost, start=55, trail=0.15))
        # 3. STACKED MAs (close>20>50>200, all aligned up) — a clean uptrend — trail 15%
        add("Stacked MAs close>20>50>200 · trail 15%", _run_strategy(closes,
            lambda i, _c=closes, _a=s20, _b=s50, _d=s200:
            (_a[i] is not None and _b[i] is not None and _d[i] is not None
             and _c[i] > _a[i] > _b[i] > _d[i]),
            lambda j, i: False, 180, cost, start=200, trail=0.15))
        # 4. STRONG 3-month mover (>25% in 63d) still in an uptrend — trail 20%
        add("3-mo momentum >25% (>200SMA) · trail 20%", _run_strategy(closes,
            lambda i, _c=closes, _d=s200:
            (i >= 63 and _d[i] is not None and _c[i] > _d[i]
             and _c[i - 63] > 0 and _c[i] / _c[i - 63] - 1 > 0.25),
            lambda j, i: False, 180, cost, start=200, trail=0.20))
        # 5. 20-day breakout with a TIGHT 10% trail (faster momentum, quicker cut)
        add("20-day-high breakout · trail 10%", _run_strategy(closes,
            lambda i, _c=closes, _h=hi20: _c[i] >= _h[i] and _c[i] > 0,
            lambda j, i: False, 120, cost, start=20, trail=0.10))
    return {name: _stats(rets) for name, rets in res.items()}


def format_momentum(res: dict, source: str) -> str:
    ranked = sorted(res.items(),
                    key=lambda kv: (kv[1]["avg"] if kv[1] else -9), reverse=True)
    lines = ["=" * 80,
             f"  {config.BOT_NAME} · MOMENTUM CATCHER   (buy what's going up · trail out · let it run)",
             f"  Data: {source}   ·   costs both sides   ·   ranked by avg%/trade",
             "=" * 80,
             f"  {'#':>2} {'strategy':<38}{'win%':>6}{'avg%/trade':>11}{'PF':>6}{'trades':>8}",
             "-" * 80]
    for k, (name, s) in enumerate(ranked, 1):
        if not s:
            lines.append(f"  {k:>2} {name:<38}{'— no trades —':>31}")
            continue
        lines.append(f"  {k:>2} {name:<38}{s['win']:>5.0f}%{s['avg']:>+10.2f}%"
                     f"{(s['pf'] or 0):>6.2f}{s['trades']:>8}")
    lines += ["-" * 80,
              "  Momentum WINS LESS OFTEN but WINS BIG — judge by avg%/trade & PF>1.2, not win%.",
              "  Compare the winner to the STRENGTH book (+5.94%, PF 2.95): only add a 5th tab if it clears that bar.",
              "=" * 80]
    return "\n".join(lines)


def format_strategies(res: dict, source: str) -> str:
    ranked = sorted(res.items(),
                    key=lambda kv: (kv[1]["avg"] if kv[1] else -9), reverse=True)
    lines = ["=" * 80,
             f"  {config.BOT_NAME} · STRATEGY SHOWDOWN   ({len(res)} strategies, same data)",
             f"  Data: {source}   ·   costs both sides   ·   ranked by avg%/trade",
             "=" * 80,
             f"  {'#':>2} {'strategy':<32}{'win%':>6}{'avg%/trade':>12}{'PF':>7}{'trades':>8}",
             "-" * 80]
    for k, (name, s) in enumerate(ranked, 1):
        if not s:
            lines.append(f"  {k:>2} {name:<32}{'— no trades —':>33}")
            continue
        lines.append(f"  {k:>2} {name:<32}{s['win']:>5.0f}%{s['avg']:>+11.2f}%"
                     f"{(s['pf'] or 0):>7.2f}{s['trades']:>8}")
    lines += ["-" * 80,
              "  Positive avg%/trade AND PF>1.2 = a real edge on this data. Most will be thin/negative.",
              "  This is the honest test: does ANY strategy beat RSI-2 here, or is the whole space thin?",
              "=" * 80]
    return "\n".join(lines)


def compare_trend_ma(panel: dict, cost=None, mas=(0, 20, 50, 100, 150, 200)) -> dict:
    """RSI-2 dip-buy (entry RSI<5, exit RSI>85 or 30-day hold — EXACTLY the live
    rules) with DIFFERENT trend-filter lengths. 0 = no filter (plain RSI-2); each
    other value only buys when close > that SMA. Only the trend gate changes, so
    this isolates precisely what the filter length is worth — is 200 too strict?"""
    cost = config.CROSS_COST_PER_SIDE if cost is None else cost
    res = {}

    def add(name, rets):
        res.setdefault(name, []).extend(rets)

    for closes in panel.values():
        if len(closes) < 60:
            continue
        r2 = rsi(closes, 2)
        for m in mas:
            if m == 0:
                name = "no filter (plain RSI-2)"
                entry = lambda i, _r=r2: _r[i] is not None and _r[i] < 5
                start = 2
            else:
                s = sma(closes, m)
                name = f"{m}-day SMA filter"
                entry = (lambda i, _r=r2, _s=s, _c=closes:
                         _r[i] is not None and _r[i] < 5
                         and _s[i] is not None and _c[i] > _s[i])
                start = m
            add(name, _run_strategy(closes, entry,
                lambda j, i, _r=r2: _r[j] is not None and _r[j] > 85,
                30, cost, start=start))
    return {name: _stats(rets) for name, rets in res.items()}


def format_trend_ma(res: dict, source: str) -> str:
    best = max((kv for kv in res.items() if kv[1]),
               key=lambda kv: kv[1]["avg"], default=(None, None))[0]

    def malen(name):
        return 0 if name.startswith("no filter") else int(name.split("-")[0])
    rows = sorted(res.items(), key=lambda kv: malen(kv[0]))   # strictness gradient
    lines = ["=" * 80,
             f"  {config.BOT_NAME} · TREND-FILTER LENGTH TEST   (RSI-2 dip, same entry/exit)",
             f"  Data: {source}   ·   costs both sides   ·   only the SMA length changes",
             "=" * 80,
             f"  {'trend filter':<30}{'win%':>6}{'avg%/trade':>12}{'PF':>7}{'trades':>8}",
             "-" * 80]
    for name, s in rows:
        star = "  <- best" if name == best else ""
        if not s:
            lines.append(f"  {name:<30}{'— no trades —':>33}")
            continue
        lines.append(f"  {name:<30}{s['win']:>5.0f}%{s['avg']:>+11.2f}%"
                     f"{(s['pf'] or 0):>7.2f}{s['trades']:>8}{star}")
    lines += ["-" * 80,
              "  Shorter SMA = looser filter = more trades, but more falling knives get in.",
              "  Pick the length with the best avg%/trade AND PF>1.2 AND enough trades to trust.",
              "=" * 80]
    return "\n".join(lines)


def compare_dip_depth(panel: dict, cost=None, thresholds=(5, 10, 15, 20, 25, 30),
                      ma=200) -> dict:
    """RSI-2 dip-buy WITH the uptrend filter (close > `ma`-SMA), sweeping the
    ENTRY threshold. Deep (RSI<5) = only violent dips — misses momentum runners
    like AEGISLOG that never fall that far. Shallow (RSI<30) = also buys mild
    pullbacks in strong uptrends, so it CAN ride those runners. Same exit (RSI>85
    or 30-day hold). Question: does buying shallower dips-in-uptrends pay, or does
    it just let weaker setups in?"""
    cost = config.CROSS_COST_PER_SIDE if cost is None else cost
    res = {}

    def add(name, rets):
        res.setdefault(name, []).extend(rets)

    for closes in panel.values():
        if len(closes) < ma + 10:
            continue
        r2 = rsi(closes, 2)
        s = sma(closes, ma)
        for t in thresholds:
            entry = (lambda i, _t=t, _r=r2, _s=s, _c=closes:
                     _r[i] is not None and _r[i] < _t
                     and _s[i] is not None and _c[i] > _s[i])
            add(f"RSI-2 < {t}  (uptrend)", _run_strategy(closes, entry,
                lambda j, i, _r=r2: _r[j] is not None and _r[j] > 85,
                30, cost, start=ma))
    return {name: _stats(rets) for name, rets in res.items()}


def format_dip_depth(res: dict, source: str) -> str:
    best = max((kv for kv in res.items() if kv[1]),
               key=lambda kv: kv[1]["avg"], default=(None, None))[0]

    def thr(name):
        return int(name.split("<")[1].split("(")[0].strip())
    rows = sorted(res.items(), key=lambda kv: thr(kv[0]))
    lines = ["=" * 80,
             f"  {config.BOT_NAME} · DIP-DEPTH TEST   (RSI-2 + 200-SMA uptrend, exit RSI>85/30d)",
             f"  Data: {source}   ·   costs both sides   ·   only the entry threshold changes",
             "=" * 80,
             f"  {'entry (buy the dip)':<26}{'win%':>6}{'avg%/trade':>12}{'PF':>7}{'trades':>8}",
             "-" * 80]
    for name, s in rows:
        star = "  <- best" if name == best else ""
        if not s:
            lines.append(f"  {name:<26}{'— no trades —':>33}")
            continue
        lines.append(f"  {name:<26}{s['win']:>5.0f}%{s['avg']:>+11.2f}%"
                     f"{(s['pf'] or 0):>7.2f}{s['trades']:>8}{star}")
    lines += ["-" * 80,
              "  Shallower (RSI<30) catches momentum names that never dip hard — but also weaker setups.",
              "  Best avg%/trade AND PF>1.2 AND enough trades wins. Deep (<5) is the current live setting.",
              "=" * 80]
    return "\n".join(lines)


def backtest(panel: dict, **kw) -> dict:
    """Run the setup across every stock in the panel and aggregate honestly."""
    all_rets = []
    for closes in panel.values():
        all_rets.extend(oversold_bounce_trades(closes, **kw))

    n = len(all_rets)
    if n == 0:
        return {"trades": 0, "verdict": "NO SETUPS TRIGGERED (need ~1yr+ of daily data)"}

    wins = [x for x in all_rets if x > 0]
    losses = [x for x in all_rets if x <= 0]
    win_rate = len(wins) / n * 100
    avg = statistics.mean(all_rets) * 100
    gross_win = sum(wins)
    gross_loss = -sum(losses)
    profit_factor = (gross_win / gross_loss) if gross_loss > 0 else None
    expectancy = statistics.mean(all_rets) * 100          # avg % per trade

    if avg <= 0:
        verdict = f"LOSING — {win_rate:.0f}% win rate but avg trade {avg:+.2f}% after costs"
    elif profit_factor and profit_factor < 1.2:
        verdict = f"THIN — profitable but fragile (profit factor {profit_factor:.2f})"
    else:
        verdict = f"REAL EDGE (on this data) — {win_rate:.0f}% win, +{avg:.2f}%/trade"

    return {
        "trades": n, "win_rate_pct": win_rate, "avg_return_pct": avg,
        "profit_factor": profit_factor, "expectancy_pct": expectancy,
        "avg_win_pct": (statistics.mean(wins) * 100) if wins else 0.0,
        "avg_loss_pct": (statistics.mean(losses) * 100) if losses else 0.0,
        "verdict": verdict,
    }


def sweep(panel: dict, grids: dict | None = None) -> list:
    """Grid-search entry/exit/hold/trend and return configs ranked by avg-return
    per trade after costs (best first). No stop-loss in the grid — it hurt."""
    import itertools
    import statistics
    g = grids or {
        "entry": [5, 10, 15, 20, 25, 30],
        "exit": [65, 75, 85],
        "hold": [10, 15, 20, 30],
        "trend": [True, False],
    }
    trend_sma = 200
    cost = config.CROSS_COST_PER_SIDE
    # Compute rsi + sma ONCE per stock (the expensive part), reuse for every combo.
    prepared = []
    for closes in panel.values():
        if len(closes) >= trend_sma + 5:
            prepared.append((closes, rsi(closes, 2), sma(closes, trend_sma)))
    print(f"  prepared {len(prepared)} stocks with enough history", flush=True)

    combos = list(itertools.product(g["entry"], g["exit"], g["hold"], g["trend"]))
    out = []
    for ci, (e, x, h, t) in enumerate(combos, 1):
        rets = []
        for closes, r, s in prepared:
            rets.extend(_simulate(closes, r, s, e, x, trend_sma, h, cost, 0.0, 0.0, t))
        if rets:
            wins = [a for a in rets if a > 0]
            gl = -sum(a for a in rets if a <= 0)
            out.append({"avg": statistics.mean(rets) * 100,
                        "pf": (sum(wins) / gl) if gl > 0 else 0.0,
                        "win": len(wins) / len(rets) * 100, "trades": len(rets),
                        "entry": e, "exit": x, "hold": h, "trend": t})
        if ci % 12 == 0 or ci == len(combos):
            print(f"  swept {ci}/{len(combos)} combos...", flush=True)
    out.sort(key=lambda d: d["avg"], reverse=True)
    return out


def _rsi2_at(prev2, prev1, cur):
    """2-period RSI using `cur` as the latest price (matches rsi(...,2))."""
    c1, c2 = prev1 - prev2, cur - prev1
    ag = (max(c1, 0.0) + max(c2, 0.0)) / 2.0
    al = (max(-c1, 0.0) + max(-c2, 0.0)) / 2.0
    return 100.0 if al == 0 else 100.0 - 100.0 / (1.0 + ag / al)


def _rsi2_threshold(prev2, prev1, target):
    """The price at which 2-period RSI (given the two prior closes) first reaches
    `target` on the way up — i.e. where a limit sell would actually fill."""
    rs = 100.0 / (100.0 - target) - 1.0 if target < 100 else 1e9
    c1 = prev1 - prev2
    if c1 >= 0:
        return prev1 - c1 / rs if rs > 0 else prev1
    return prev1 + rs * (-c1)


def _simulate_intraday(closes, highs, r, entry_rsi, exit_rsi, max_hold, cost, realistic=False):
    """Same entries as baseline, but exit INTRADAY the first day RSI-2 (using
    that day's high) crosses exit_rsi. realistic=False sells at the day's HIGH
    (optimistic ceiling); realistic=True sells at the RSI-2=exit_rsi threshold
    price (what a limit order would actually get)."""
    trades = []
    i, n = 2, len(closes)
    while i < n - 1:
        if r[i] is not None and r[i] < entry_rsi and closes[i] > 0:
            entry, j, exit_px = closes[i], i + 1, None
            while j < n - 1:
                if highs[j] > 0 and _rsi2_at(closes[j - 2], closes[j - 1], highs[j]) > exit_rsi:
                    if realistic:
                        thr = _rsi2_threshold(closes[j - 2], closes[j - 1], exit_rsi)
                        exit_px = min(highs[j], max(thr, 0.01))   # limit fill, capped by the high
                    else:
                        exit_px = highs[j]                        # sold at the peak
                    break
                if (r[j] is not None and r[j] > exit_rsi) or (j - i) >= max_hold:
                    exit_px = closes[j]
                    break
                j += 1
            if exit_px is None:
                exit_px = closes[j]
            if exit_px > 0:
                trades.append((exit_px - entry) / entry - 2 * cost)
            i = j + 1
        else:
            i += 1
    return trades


def _stats(rets):
    if not rets:
        return None
    wins = [x for x in rets if x > 0]
    gl = -sum(x for x in rets if x <= 0)
    return {"trades": len(rets), "win": len(wins) / len(rets) * 100,
            "avg": statistics.mean(rets) * 100,
            "pf": (sum(wins) / gl) if gl > 0 else None,
            "avg_win": (statistics.mean(wins) * 100) if wins else 0.0,
            "avg_loss": (statistics.mean([x for x in rets if x <= 0]) * 100)
                        if len(wins) < len(rets) else 0.0}


def compare_intraday(ohlc_panel: dict, entry_rsi=5.0, exit_rsi=85.0, max_hold=30):
    """Baseline daily-close exit vs the REALISTIC intraday exit (limit at the
    RSI-2=exit price) vs the OPTIMISTIC ceiling (sell at the high)."""
    cost = config.CROSS_COST_PER_SIDE
    base, real, opt = [], [], []
    for closes, highs in ohlc_panel.values():
        if len(closes) < max_hold + 5:
            continue
        r = rsi(closes, 2)
        base.extend(_simulate(closes, r, [None] * len(closes), entry_rsi, exit_rsi,
                              2, max_hold, cost, 0.0, 0.0, False))
        real.extend(_simulate_intraday(closes, highs, r, entry_rsi, exit_rsi, max_hold, cost, True))
        opt.extend(_simulate_intraday(closes, highs, r, entry_rsi, exit_rsi, max_hold, cost, False))
    return {"Baseline (daily-close exit, LIVE)": _stats(base),
            "Intraday REALISTIC (limit at RSI-2=85 price)": _stats(real),
            "Intraday CEILING (sell at the high)": _stats(opt)}


def load_ohlc(path) -> dict:
    """Read symbol,date,open,high,low,close -> {symbol: ([closes], [highs])}."""
    rows_by = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            s = row.get("symbol") or row.get("Symbol")
            try:
                d = row["date"]
                c = float(row["close"])
                h = float(row["high"])
            except (KeyError, ValueError, TypeError):
                continue
            if s:
                rows_by.setdefault(s, []).append((d, h, c))
    out = {}
    for s, rows in rows_by.items():
        rows.sort()
        out[s] = ([c for _, _, c in rows], [h for _, h, _ in rows])
    return out


def format_intraday(res: dict, source: str) -> str:
    lines = ["=" * 82,
             f"  {config.BOT_NAME} · INTRADAY vs DAILY-CLOSE EXIT   (entry<5, exit>85, 30d hold)",
             f"  Data: {source}   ·   costs both sides",
             "=" * 82,
             f"  {'variant':<46}{'win%':>6}{'avg%/trade':>12}{'PF':>7}{'trades':>7}",
             "-" * 82]
    for name, s in res.items():
        if not s:
            lines.append(f"  {name:<46}{'— no trades —':>32}")
            continue
        lines.append(f"  {name:<46}{s['win']:>5.0f}%{s['avg']:>+11.2f}%"
                     f"{(s['pf'] or 0):>7.2f}{s['trades']:>7}")
    lines += ["-" * 82,
              "  The REALISTIC row is what you'd actually get (limit sell at the RSI-2=85 price).",
              "  The CEILING (sell at the exact high) is impossible — it's only an upper bound.",
              "  Build intraday exits ONLY if REALISTIC clearly beats baseline on avg%/trade AND PF.",
              "=" * 82]
    return "\n".join(lines)


def compare_exits(panel: dict, entry_rsi=5.0, exit_rsi=85.0, max_hold=30,
                  use_trend=False) -> list:
    """Run the LIVE settings (baseline) against stop-loss / profit-target
    variants, side by side, so you can SEE whether stops help or hurt."""
    base = dict(entry_rsi=entry_rsi, exit_rsi=exit_rsi, max_hold=max_hold,
                use_trend=use_trend)
    variants = [
        ("Baseline (live: no stop/target)", 0.0, 0.0),
        ("+ Stop-loss -5%", 0.05, 0.0),
        ("+ Stop-loss -8%", 0.08, 0.0),
        ("+ Stop-loss -12%", 0.12, 0.0),
        ("+ Profit target +5%", 0.0, 0.05),
        ("+ Profit target +10%", 0.0, 0.10),
        ("+ Profit target +15%", 0.0, 0.15),
        ("+ Stop -8% & Target +10%", 0.08, 0.10),
        ("+ Stop -12% & Target +8%", 0.12, 0.08),
    ]
    rows = []
    for name, sl, pt in variants:
        r = backtest(panel, stop_loss=sl, profit_target=pt, **base)
        rows.append((name, r))
    return rows


def format_compare(rows: list, source: str, settings: str) -> str:
    lines = ["=" * 84,
             f"  {config.BOT_NAME} · RSI-2 EXIT COMPARISON   ({settings})",
             f"  Data: {source}   ·   costs charged both sides",
             "=" * 84,
             f"  {'variant':<32}{'win%':>6}{'avg%/trade':>12}{'PF':>7}"
             f"{'avgWin%':>9}{'avgLoss%':>9}{'trades':>8}",
             "-" * 84]
    base_avg = base_pf = None
    for name, r in rows:
        if r.get("trades", 0) == 0:
            lines.append(f"  {name:<32}{'— no trades —':>42}")
            continue
        pf = r["profit_factor"]
        if base_avg is None:
            base_avg, base_pf = r["avg_return_pct"], (pf or 0)
        flag = ""
        if name.startswith("+"):
            better = r["avg_return_pct"] >= base_avg and (pf or 0) >= base_pf
            flag = "  << beats baseline" if better else ""
        lines.append(
            f"  {name:<32}{r['win_rate_pct']:>5.0f}%{r['avg_return_pct']:>+11.2f}%"
            f"{(pf if pf else 0):>7.2f}{r['avg_win_pct']:>+9.1f}{r['avg_loss_pct']:>9.1f}"
            f"{r['trades']:>8}{flag}")
    lines += ["-" * 84,
              "  Read: a variant only truly helps if BOTH avg%/trade AND PF beat the baseline.",
              "  RSI-2 mean-reversion usually LOSES edge with tight stops (they exit before the bounce).",
              "=" * 84]
    return "\n".join(lines)


def format_sweep(rows: list, top: int = 15) -> str:
    lines = ["=" * 72,
             f"  {config.BOT_NAME} · RSI-2 SWEEP  (ranked by avg-return/trade after costs)",
             "=" * 72,
             f"  {'#':>2} {'avg%':>6} {'PF':>5} {'win%':>5} {'trades':>7}  "
             f"{'entry':>5} {'exit':>4} {'hold':>4} {'trend':>5}",
             "-" * 72]
    for i, d in enumerate(rows[:top], 1):
        lines.append(f"  {i:>2} {d['avg']:>6.2f} {d['pf']:>5.2f} {d['win']:>5.1f} "
                     f"{d['trades']:>7}  {d['entry']:>5} {d['exit']:>4} {d['hold']:>4} "
                     f"{'no' if not d['trend'] else 'yes':>5}")
    lines += ["-" * 72,
              "  Reproduce the best row:  --entry E --exit X --hold H [--no-trend]",
              "=" * 72]
    return "\n".join(lines)


def format_report(r: dict, source: str) -> str:
    if r["trades"] == 0:
        return f"RSI-2 oversold bounce · {source}\n  {r['verdict']}"
    pf = f"{r['profit_factor']:.2f}" if r["profit_factor"] else "—"
    return "\n".join([
        "=" * 64,
        f"  {config.BOT_NAME} · RSI-2 OVERSOLD BOUNCE  (mean-reversion setup)",
        "=" * 64,
        f"  Data          : {source}",
        f"  Trades        : {r['trades']}",
        f"  Win rate      : {r['win_rate_pct']:.1f}%",
        f"  Avg / trade   : {r['avg_return_pct']:+.2f}%   (AFTER costs)  <- must be > 0",
        f"  Avg win / loss: +{r['avg_win_pct']:.2f}% / {r['avg_loss_pct']:.2f}%",
        f"  Profit factor : {pf}",
        "-" * 64,
        f"  VERDICT: {r['verdict']}",
        "=" * 64,
    ])


def main() -> None:
    import sys
    from .cross import load_series
    from pathlib import Path
    args = sys.argv[1:]

    def _opt(flag, cast, default):
        return cast(args[args.index(flag) + 1]) if flag in args else default

    path = _opt("--csv", str, None)
    if not path or not Path(path).exists():
        raise SystemExit("usage: python3 -m garuda.setups --csv daily.csv "
                         "[--entry 10] [--exit 65] [--hold 10]")
    panel = load_series(path)   # per-stock; scales to the whole universe
    # --exclude a,b : drop symbols listed in these files (e.g. isolate microcaps
    # by running allstocks.csv and excluding the Nifty 500 = everything smaller).
    excl_arg = _opt("--exclude", str, "")
    if excl_arg:
        from .fetch_daily import _read_symbols_file
        excl = set()
        for ef in excl_arg.split(","):
            ef = ef.strip()
            if ef and Path(ef).exists():
                excl.update(_read_symbols_file(ef))
        if excl:
            panel = {s: v for s, v in panel.items() if s not in excl}
            print(f"  excluded {len(excl)} symbols; {len(panel)} remain")
    # price filter: isolate penny stocks (--maxprice 50) or exclude them (--minprice)
    maxp = _opt("--maxprice", float, 0.0)
    minp = _opt("--minprice", float, 0.0)
    if maxp or minp:
        panel = {s: v for s, v in panel.items() if v and
                 (not maxp or v[-1] <= maxp) and (not minp or v[-1] >= minp)}
        print(f"  price filter (<= {maxp or '∞'}, >= {minp or 0}): {len(panel)} stocks")
    if "--intraday" in args:
        ohlc = load_ohlc(path)
        if not ohlc or all(len(h) == 0 for _, h in ohlc.values()):
            raise SystemExit("This CSV has no 'high' column. Re-fetch with --ohlc:\n"
                             "  python3 -m garuda.fetch_daily --symbols-file <list> "
                             "--out <name>_ohlc.csv --ohlc --fresh")
        res = compare_intraday(ohlc, entry_rsi=_opt("--entry", float, 5.0),
                               exit_rsi=_opt("--exit", float, 85.0),
                               max_hold=_opt("--hold", int, 30))
        print(format_intraday(res, f"{path} ({len(ohlc)} symbols)"))
        return
    if "--strategies" in args:
        print(format_strategies(compare_strategies(panel), f"{path} ({len(panel)} symbols)"))
        return
    if "--trendma" in args:
        print(format_trend_ma(compare_trend_ma(panel), f"{path} ({len(panel)} symbols)"))
        return
    if "--momentum" in args:
        print(format_momentum(compare_momentum(panel), f"{path} ({len(panel)} symbols)"))
        return
    if "--dipdepth" in args:
        print(format_dip_depth(compare_dip_depth(panel), f"{path} ({len(panel)} symbols)"))
        return
    if "--costs" in args:
        levels = [0.0010, 0.0030, 0.0050, 0.0100, 0.0300, 0.0500]
        rows = backtest_costs(panel, levels, entry_rsi=_opt("--entry", float, 5.0),
                              exit_rsi=_opt("--exit", float, 85.0),
                              max_hold=_opt("--hold", int, 30))
        print(format_costs(rows, f"{path} ({len(panel)} symbols)"))
        return
    if "--discipline" in args:
        res, ntr = backtest_sizing(panel, entry_rsi=_opt("--entry", float, 5.0),
                                   exit_rsi=_opt("--exit", float, 85.0),
                                   max_hold=_opt("--hold", int, 30))
        print(format_sizing(res, ntr, f"{path} ({len(panel)} symbols)"))
        return
    if "--sweep" in args:
        print(format_sweep(sweep(panel)))
        return
    if "--compare" in args:
        e = _opt("--entry", float, 5.0)
        x = _opt("--exit", float, 85.0)
        h = _opt("--hold", int, 30)
        ut = ("--trend" in args)          # default OFF to match the live strategy
        rows = compare_exits(panel, entry_rsi=e, exit_rsi=x, max_hold=h, use_trend=ut)
        settings = f"entry<{e:g}, exit>{x:g}, {h}-day hold, trend={'on' if ut else 'off'}"
        print(format_compare(rows, f"{path} ({len(panel)} symbols)", settings))
        return
    r = backtest(panel,
                 entry_rsi=_opt("--entry", float, 10.0),
                 exit_rsi=_opt("--exit", float, 65.0),
                 max_hold=_opt("--hold", int, 10),
                 stop_loss=_opt("--stop", float, 0.0),        # e.g. 0.05 = cut at -5%
                 profit_target=_opt("--target", float, 0.0),  # e.g. 0.06 = take +6%
                 use_trend=("--no-trend" not in args),         # drop the uptrend filter
                 oos=_opt("--oos", float, 0.0))                # e.g. 0.3 = only last 30%
    oos = _opt("--oos", float, 0.0)
    label = f"{path} ({len(panel)} symbols)"
    if 0 < oos < 1:
        label += f"  [OUT-OF-SAMPLE: last {oos:.0%} only]"
    print(format_report(r, label))


if __name__ == "__main__":
    main()
