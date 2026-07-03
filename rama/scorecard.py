"""Honest scorecard: is the paper strategy actually working?

This turns the equity history + closed trades into the numbers that matter and,
crucially, a plain-English VERDICT measured against the only benchmark that
counts: would you have done better just buying a Nifty index fund?

It refuses to give a verdict before config.MIN_TRACK_DAYS of history, because
a few days of paper results are noise, not signal — and pretending otherwise is
how people fool themselves into risking real money too early.
"""

import statistics

from . import config


def _max_drawdown(equities: list[float]) -> float:
    """Largest peak-to-trough drop on the equity curve, as a negative %."""
    if len(equities) < 2:
        return 0.0
    peak, mdd = equities[0], 0.0
    for e in equities:
        peak = max(peak, e)
        if peak > 0:
            mdd = min(mdd, (e - peak) / peak)
    return mdd * 100


def _index_return_pct(history: list[dict]) -> float | None:
    """Return of the index over the SAME span we have data for (or None).

    Uses the first and last equity points that carry an 'index' level, so the
    comparison is apples-to-apples over the period the bot actually ran.
    """
    first = next((h["index"] for h in history if h.get("index")), None)
    last = next((h["index"] for h in reversed(history) if h.get("index")), None)
    if first and last and first > 0:
        return (last / first - 1) * 100
    return None


def _verdict(days: int, total_ret: float, index_ret: float | None) -> tuple[str, str]:
    """Plain-English status + one-line explanation."""
    if days < config.MIN_TRACK_DAYS:
        return ("TOO EARLY",
                f"Only {days}/{config.MIN_TRACK_DAYS} days of history — this is "
                "noise, not signal. Keep letting it run.")
    if total_ret <= 0:
        return ("LOSING",
                "Net return is negative after costs. Not working yet — do NOT "
                "risk real money.")
    if index_ret is not None and total_ret < index_ret:
        return ("LAGGING THE INDEX",
                f"Up {total_ret:+.1f}%, but a Nifty index fund did {index_ret:+.1f}% "
                "— the lazy option is winning. Not worth real money yet.")
    if index_ret is not None:
        return ("PROMISING",
                f"Up {total_ret:+.1f}% vs the index's {index_ret:+.1f}% — beating "
                "the lazy option after costs. Keep going and re-check.")
    return ("POSITIVE (no index yet)",
            "Net positive, but not enough index data to compare. The verdict "
            "needs a few runs that recorded the Nifty level.")


def compute_scorecard(pf) -> dict:
    """Build the full scorecard dict from a Portfolio's history + trades."""
    history = pf.history
    days = len(history)
    start = pf.starting_capital or 1.0
    latest = history[-1]["equity"] if history else start
    total_ret = (latest / start - 1) * 100

    eqs = [h["equity"] for h in history]
    daily = [eqs[i] / eqs[i - 1] - 1
             for i in range(1, len(eqs)) if eqs[i - 1] > 0]
    sd = statistics.pstdev(daily) if len(daily) > 1 else 0.0
    vol_pct = sd * 100
    # crude annualised risk-adjusted return (Sharpe-like, rf=0). Needs genuine
    # day-to-day variation; a near-flat curve (sd ~ 0) gives a meaningless huge
    # number, so we treat that as "not enough variation" -> 0.
    if len(daily) > 1 and sd > 5e-5:
        sharpe = statistics.mean(daily) / sd * (252 ** 0.5)
    else:
        sharpe = 0.0

    index_ret = _index_return_pct(history)
    edge = (total_ret - index_ret) if index_ret is not None else None

    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    wins = [t for t in closed if t["pnl"] > 0]
    losses = [t for t in closed if t["pnl"] <= 0]
    win_rate = (len(wins) / len(closed) * 100) if closed else None
    gross_win = sum(t["pnl"] for t in wins)
    gross_loss = -sum(t["pnl"] for t in losses)
    profit_factor = (gross_win / gross_loss) if gross_loss > 0 else None

    status, explanation = _verdict(days, total_ret, index_ret)
    return {
        "days": days,
        "min_track_days": config.MIN_TRACK_DAYS,
        "ready_to_judge": days >= config.MIN_TRACK_DAYS,
        "total_return_pct": total_ret,
        "index_return_pct": index_ret,
        "edge_vs_index_pct": edge,
        "max_drawdown_pct": _max_drawdown(eqs),
        "volatility_pct": vol_pct,
        "sharpe": sharpe,
        "closed_trades": len(closed),
        "win_rate_pct": win_rate,
        "profit_factor": profit_factor,
        "verdict": status,
        "explanation": explanation,
    }


def format_scorecard(sc: dict) -> str:
    """Human-readable multi-line scorecard for the console."""
    def pct(v):
        return f"{v:+.2f}%" if isinstance(v, (int, float)) else "n/a"

    idx = pct(sc["index_return_pct"]) if sc["index_return_pct"] is not None else "n/a (need Kite index history)"
    edge = pct(sc["edge_vs_index_pct"]) if sc["edge_vs_index_pct"] is not None else "n/a"
    wr = f"{sc['win_rate_pct']:.0f}%" if sc["win_rate_pct"] is not None else "n/a"
    pf_ = f"{sc['profit_factor']:.2f}" if sc["profit_factor"] is not None else "n/a"
    lines = [
        "=" * 64,
        "  Rama · HONEST SCORECARD  (paper — not advice)",
        "=" * 64,
        f"  Days of history     : {sc['days']}  "
        f"(need {sc['min_track_days']}+ to judge)",
        f"  Strategy return     : {pct(sc['total_return_pct'])}",
        f"  Nifty index return  : {idx}",
        f"  Edge vs index       : {edge}   <- the number that matters",
        f"  Max drawdown        : {sc['max_drawdown_pct']:.2f}%",
        f"  Daily volatility    : {sc['volatility_pct']:.2f}%",
        f"  Sharpe (rough)      : {sc['sharpe']:.2f}",
        f"  Closed trades       : {sc['closed_trades']}  "
        f"(win rate {wr}, profit factor {pf_})",
        "-" * 64,
        f"  VERDICT: {sc['verdict']}",
        f"  {sc['explanation']}",
        "=" * 64,
    ]
    return "\n".join(lines)
