"""Garuda backtester — the honest heart of the fast model.

Walks a price series bar by bar. At each bar it forms the Markov state from the
last few bar-directions, asks the predictor P(next bar up), and — only if the
edge clears MIN_EDGE — takes a Kelly-sized long or short for the NEXT bar. It
then books the result MINUS round-trip costs and lets the model self-learn from
what actually happened. No lookahead: the outcome of a bar is never in the
counts when that bar is predicted.

The output is a plain, honest scorecard: net return AFTER costs, win rate, max
drawdown, a rough annualised Sharpe, and — the number that matters — whether it
beat simply buying and holding the same series. A fast strategy that can't clear
its own costs is worthless, and this makes that impossible to hide.
"""

import statistics

from . import config
from .markov import MarkovPredictor


def run(prices, order=None, warmup=None, cost=None, kelly_fraction=None,
        min_edge=None, max_alloc=None, self_learn=None) -> dict:
    order = config.MARKOV_ORDER if order is None else order
    warmup = config.WARMUP_BARS if warmup is None else warmup
    cost = config.COST_PER_SIDE if cost is None else cost
    kf = config.KELLY_FRACTION if kelly_fraction is None else kelly_fraction
    min_edge = config.MIN_EDGE if min_edge is None else min_edge
    max_alloc = config.MAX_ALLOCATION if max_alloc is None else max_alloc
    self_learn = config.SELF_LEARN if self_learn is None else self_learn

    pred = MarkovPredictor(order=order)
    equity = 1.0
    eq_curve = [1.0]
    trades = wins = 0
    signs: list[int] = []

    for i in range(len(prices) - 1):
        if i >= 1:
            signs.append(1 if prices[i] >= prices[i - 1] else 0)
        state = signs[-order:] if len(signs) >= order else None
        nr = (prices[i + 1] - prices[i]) / prices[i] if prices[i] else 0.0
        outcome_up = prices[i + 1] >= prices[i]

        bar_ret = 0.0
        if state is not None and i >= warmup:
            p_up = pred.prob_up(state)
            edge = p_up - 0.5
            if abs(edge) >= min_edge:
                direction = 1 if edge > 0 else -1        # long or short next bar
                frac = min(kf * abs(2 * p_up - 1), max_alloc)
                bar_ret = direction * nr * frac - 2 * cost * frac  # entry+exit cost
                equity *= (1.0 + bar_ret)
                trades += 1
                wins += 1 if bar_ret > 0 else 0

        # self-learn: update AFTER predicting/trading, so no lookahead. Always
        # learn during warmup; after warmup, only if self_learn is on.
        if state is not None and (self_learn or i < warmup):
            pred.update(state, outcome_up)
        eq_curve.append(equity)

    return _metrics(prices, eq_curve, trades, wins, pred)


def _max_drawdown(curve) -> float:
    peak, mdd = curve[0], 0.0
    for e in curve:
        peak = max(peak, e)
        if peak > 0:
            mdd = min(mdd, (e - peak) / peak)
    return mdd * 100


def _metrics(prices, eq_curve, trades, wins, pred) -> dict:
    total_ret = (eq_curve[-1] - 1.0) * 100
    buyhold = ((prices[-1] / prices[0] - 1.0) * 100) if prices and prices[0] else 0.0
    rets = [eq_curve[i] / eq_curve[i - 1] - 1.0
            for i in range(1, len(eq_curve)) if eq_curve[i - 1] > 0]
    sd = statistics.pstdev(rets) if len(rets) > 1 else 0.0
    sharpe = (statistics.mean(rets) / sd * (config.BARS_PER_YEAR ** 0.5)
              if sd > 1e-12 else 0.0)
    win_rate = (wins / trades * 100) if trades else None

    if trades == 0:
        verdict = "NO TRADES — the edge never cleared MIN_EDGE"
    elif total_ret <= 0:
        verdict = "LOSING after costs — no usable edge on this data"
    elif total_ret < buyhold:
        verdict = f"WEAK — up {total_ret:+.1f}% but buy & hold did {buyhold:+.1f}%"
    else:
        verdict = f"EDGE (on this data) — {total_ret:+.1f}% vs buy & hold {buyhold:+.1f}%"

    return {
        "bars": len(prices), "trades": trades, "win_rate_pct": win_rate,
        "total_return_pct": total_ret, "buyhold_return_pct": buyhold,
        "edge_vs_buyhold_pct": total_ret - buyhold,
        "max_drawdown_pct": _max_drawdown(eq_curve),
        "sharpe": sharpe, "states_learned": pred.states_seen(),
        "equity_curve": eq_curve, "verdict": verdict,
    }


def format_report(r: dict, source: str) -> str:
    wr = f"{r['win_rate_pct']:.0f}%" if r["win_rate_pct"] is not None else "—"
    return "\n".join([
        "=" * 64,
        f"  {config.BOT_NAME} · FAST-MODEL BACKTEST  (paper — not advice)",
        "=" * 64,
        f"  Data           : {source}",
        f"  Bars / trades  : {r['bars']} / {r['trades']}   (win rate {wr})",
        f"  Net return     : {r['total_return_pct']:+.2f}%   (AFTER costs)",
        f"  Buy & hold     : {r['buyhold_return_pct']:+.2f}%",
        f"  Edge vs hold   : {r['edge_vs_buyhold_pct']:+.2f}%   <- the number that matters",
        f"  Max drawdown   : {r['max_drawdown_pct']:.2f}%",
        f"  Sharpe (rough) : {r['sharpe']:.2f}",
        f"  States learned : {r['states_learned']}",
        "-" * 64,
        f"  VERDICT: {r['verdict']}",
        "=" * 64,
    ])
