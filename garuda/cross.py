"""Cross-sectional daily backtest — 'rank all the stocks, pick some, hold'.

This is the honest version of "100 shares go up every day, catch them". Every
day it ranks the whole liquid universe by yesterday's move and picks K names,
then measures their ACTUAL next-day return minus costs. It tests both forks:

  • momentum  — buy the top gainers   (chase what's going up)
  • reversion — buy the worst laggards (bet the beaten-down ones bounce)

No lookahead: the signal on day t uses prices up to day t; the return is day
t -> t+1. Costs are charged every rebalance. Win rate is REPORTED but is not the
target — net return after costs, and beating an equal-weight buy & hold of the
same universe, is what counts. A high win rate that still loses money is a trap,
so this makes the net number impossible to hide.
"""

import csv
import statistics
from pathlib import Path

from . import config


def _load_long(path) -> dict:
    """Read a long CSV (symbol,date,close) into {symbol: {date: close}}. This
    scales to the whole 2000-5000 stock universe — no wide-row alignment needed."""
    data: dict = {}
    with open(path, newline="", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            s = row.get("symbol") or row.get("Symbol")
            d = row.get("date") or row.get("Date")
            c = row.get("close") or row.get("Close")
            if not s or c in (None, ""):
                continue
            try:
                data.setdefault(s, {})[d] = float(str(c).replace(",", ""))
            except ValueError:
                continue
    return data


def load_series(path) -> dict:
    """{symbol: [closes sorted by date]} — each stock independent (for setups)."""
    return {s: [v for _, v in sorted(dv.items())] for s, dv in _load_long(path).items()}


def load_panel(path) -> dict:
    """{symbol: [closes]} aligned to the dates ALL stocks share (for the
    cross-sectional backtest, which must compare stocks on the same days)."""
    data = _load_long(path)
    if not data:
        return {}
    common = sorted(set.intersection(*[set(dv) for dv in data.values()]))
    return {s: [data[s][d] for d in common] for s in data if len(data[s]) >= len(common)}


def run_cross(panel: dict, mode: str = "reversion", pick: int = 10,
              cost_per_side: float | None = None, lookback: int = 1) -> dict:
    cost = config.CROSS_COST_PER_SIDE if cost_per_side is None else cost_per_side
    syms = [s for s, v in panel.items() if len(v) > lookback + 1]
    if len(syms) < pick + 1:
        return {"error": f"need > {pick} aligned symbols, got {len(syms)}"}
    n = min(len(panel[s]) for s in syms)

    equity = 1.0
    curve = [1.0]
    day_rets = []
    wins = days = 0

    for t in range(lookback, n - 1):
        sig = {}
        for s in syms:
            base = panel[s][t - lookback]
            if base > 0:
                sig[s] = panel[s][t] / base - 1.0        # signal known at day t
        if len(sig) < pick:
            continue
        ranked = sorted(sig, key=sig.get)                # worst -> best
        picks = ranked[:pick] if mode == "reversion" else ranked[-pick:]
        fwd = [panel[s][t + 1] / panel[s][t] - 1.0        # realised next-day move
               for s in picks if panel[s][t] > 0]
        if not fwd:
            continue
        net = sum(fwd) / len(fwd) - 2 * cost              # equal weight, entry+exit cost
        equity *= (1.0 + net)
        curve.append(equity)
        day_rets.append(net)
        wins += 1 if net > 0 else 0
        days += 1

    # benchmark: equal-weight buy & hold of the same universe over the window
    bh = statistics.mean(panel[s][n - 1] / panel[s][lookback] - 1.0
                         for s in syms if panel[s][lookback] > 0) * 100

    total = (equity - 1.0) * 100
    sd = statistics.pstdev(day_rets) if len(day_rets) > 1 else 0.0
    sharpe = (statistics.mean(day_rets) / sd * (250 ** 0.5)) if sd > 1e-12 else 0.0
    peak, mdd = 1.0, 0.0
    for e in curve:
        peak = max(peak, e)
        mdd = min(mdd, (e - peak) / peak)

    if days == 0:
        verdict = "NO TRADES"
    elif total <= 0:
        verdict = "LOSING after costs — no edge"
    elif total < bh:
        verdict = f"WEAK — {total:+.1f}% but buy & hold did {bh:+.1f}%"
    else:
        verdict = f"EDGE — {total:+.1f}% vs buy & hold {bh:+.1f}%"

    return {
        "mode": mode, "pick": pick, "symbols": len(syms), "rebalances": days,
        "win_rate_pct": (wins / days * 100) if days else None,
        "total_return_pct": total, "buyhold_return_pct": bh,
        "edge_vs_buyhold_pct": total - bh, "max_drawdown_pct": mdd * 100,
        "sharpe": sharpe, "verdict": verdict,
    }


def format_report(r: dict, source: str) -> str:
    if r.get("error"):
        return f"cross backtest error: {r['error']}"
    wr = f"{r['win_rate_pct']:.0f}%" if r["win_rate_pct"] is not None else "—"
    return "\n".join([
        "=" * 64,
        f"  {config.BOT_NAME} · CROSS-SECTIONAL BACKTEST  ({r['mode'].upper()})",
        "=" * 64,
        f"  Data           : {source}",
        f"  Universe/picks : {r['symbols']} stocks, top {r['pick']} each day",
        f"  Rebalances     : {r['rebalances']}   (win rate {wr})",
        f"  Net return     : {r['total_return_pct']:+.2f}%   (AFTER costs)",
        f"  Buy & hold all : {r['buyhold_return_pct']:+.2f}%",
        f"  Edge vs hold   : {r['edge_vs_buyhold_pct']:+.2f}%",
        f"  Max drawdown   : {r['max_drawdown_pct']:.2f}%",
        f"  Sharpe (daily) : {r['sharpe']:.2f}",
        "-" * 64,
        f"  VERDICT: {r['verdict']}",
        "=" * 64,
    ])


def main() -> None:
    import sys
    args = sys.argv[1:]

    def _opt(flag, cast, default):
        return cast(args[args.index(flag) + 1]) if flag in args else default

    path = _opt("--csv", str, None)
    if not path or not Path(path).exists():
        raise SystemExit("usage: python3 -m garuda.cross --csv daily.csv "
                         "[--mode reversion|momentum] [--pick 10]")
    panel = load_panel(path)
    mode = _opt("--mode", str, "reversion")
    pick = _opt("--pick", int, 10)
    r = run_cross(panel, mode=mode, pick=pick)
    print(format_report(r, f"{path} ({len(panel)} symbols)"))


if __name__ == "__main__":
    main()
