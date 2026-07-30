"""Walk-forward backtest over your daily CSV snapshots.

Workflow: keep each day's CSV in data/snapshots/ (e.g. 2026-06-20.csv,
2026-06-21.csv, ...). Upload today's file via Termius and copy it into
snapshots/ to grow the history.

Method (honest and simple):
  • On day T, rank industries and pick the top-N (after the PE filter).
  • The realized next-day return of each pick is taken from day T+1's
    "Day Change %" column in the snapshot for that industry.
  • The strategy's daily return = average of the picks' next-day moves,
    MINUS trading costs on whatever it had to buy/sell that day.
  • Compound across all snapshot pairs and compare to a buy-everything
    benchmark (average day-change of all industries), which only pays a cost
    to buy in once and then holds.

Trading costs (config.INCLUDE_TRADING_COSTS) make this realistic: each rebalance
charges config.BACKTEST_COST_PER_SIDE_PCT on the fraction of the book sold and
the fraction bought, so a high-churn strategy is correctly penalised. The result
reports BOTH gross (before costs) and net (after costs) so you can see the drag.

This uses REAL reported industry day-moves, so it is a genuine (if coarse)
test of whether the ranking adds value. It still ignores intraday stops and is
not a guarantee of future results.
"""

from statistics import mean

from . import config
from .data_loader import list_snapshots
from .screener import load_industries, score_industries, top_industries


def _day_change_map(csv_path) -> dict[str, float]:
    return {i.name: i.day_change for i in load_industries(csv_path)}


def run_backtest(verbose: bool = True) -> dict:
    snaps = list_snapshots()
    if len(snaps) < 2:
        msg = (
            f"Need at least 2 daily snapshots in {config.SNAPSHOTS_DIR} to backtest.\n"
            f"Found {len(snaps)}. Drop your daily CSVs there (e.g. 2026-06-22.csv)\n"
            "and re-run. Tip: copy each day's upload into snapshots/ to build history."
        )
        if verbose:
            print(msg)
        return {"ok": False, "message": msg, "days": len(snaps)}

    per_side = config.BACKTEST_COST_PER_SIDE_PCT if config.INCLUDE_TRADING_COSTS else 0.0

    strat_equity = 1.0          # net of costs
    strat_gross_equity = 1.0    # before costs (to show the drag)
    bench_equity = 1.0          # net of its one-time entry cost
    rows = []
    wins = 0
    total_cost_frac = 0.0       # summed daily cost fractions (rough total drag)

    prev_picks: set[str] = set()
    prev_n = 0
    first = True

    for today, nextday in zip(snaps[:-1], snaps[1:]):
        picks = top_industries(csv_path=today)
        realized = _day_change_map(nextday)

        held = [p.name for p in picks if p.name in realized]
        pick_rets = [realized[name] / 100.0 for name in held]
        all_rets = [v / 100.0 for v in realized.values()]
        if not pick_rets:
            continue

        cur = set(held)
        n = len(held)

        # Turnover cost: on the first day we buy the whole book; afterwards we
        # only pay to sell what dropped out and buy what came in.
        if first:
            buy_frac, sell_frac = 1.0, 0.0
        else:
            buy_frac = len(cur - prev_picks) / n if n else 0.0
            sell_frac = len(prev_picks - cur) / prev_n if prev_n else 0.0
        strat_cost = (buy_frac + sell_frac) * per_side
        total_cost_frac += strat_cost

        # Benchmark holds everything: it only pays to buy in on day one.
        bench_cost = per_side if first else 0.0

        strat_r = mean(pick_rets)
        bench_r = mean(all_rets) if all_rets else 0.0
        net_strat_r = strat_r - strat_cost
        net_bench_r = bench_r - bench_cost

        strat_gross_equity *= (1 + strat_r)
        strat_equity *= (1 + net_strat_r)
        bench_equity *= (1 + net_bench_r)
        if net_strat_r > net_bench_r:
            wins += 1
        rows.append((nextday.stem, net_strat_r * 100, net_bench_r * 100))

        prev_picks, prev_n, first = cur, n, False

    strat_net = (strat_equity - 1) * 100
    strat_gross = (strat_gross_equity - 1) * 100
    result = {
        "ok": True,
        "days": len(rows),
        "strategy_return_pct": strat_net,            # net of costs (headline)
        "strategy_gross_pct": strat_gross,           # before costs
        "cost_drag_pct": strat_gross - strat_net,    # how much costs ate
        "benchmark_return_pct": (bench_equity - 1) * 100,
        "win_rate_pct": (wins / len(rows) * 100) if rows else 0.0,
        "costs_included": config.INCLUDE_TRADING_COSTS,
        "cost_per_side_pct": per_side * 100,
        "rows": rows,
    }
    if verbose:
        _print(result)
    return result


def _print(r: dict) -> None:
    print("\n" + "=" * 60)
    print("  Rama · WALK-FORWARD BACKTEST (industry day-moves)")
    print("=" * 60)
    print(f"  Days tested        : {r['days']}")
    if r.get("costs_included"):
        print(f"  Strategy (gross)   : {r['strategy_gross_pct']:+.2f}%")
        print(f"  Cost drag          : -{r['cost_drag_pct']:.2f}%  "
              f"({r['cost_per_side_pct']:.2f}% per side)")
        print(f"  Strategy (NET)     : {r['strategy_return_pct']:+.2f}%  <- after costs")
    else:
        print(f"  Strategy return    : {r['strategy_return_pct']:+.2f}%  (costs OFF)")
    print(f"  Benchmark (all)    : {r['benchmark_return_pct']:+.2f}%")
    print(f"  Days beating bench : {r['win_rate_pct']:.0f}%")
    print("-" * 60)
    for day, s, b in r["rows"][-10:]:
        flag = "✓" if s > b else " "
        print(f"   {day:14} strat {s:+6.2f}%  bench {b:+6.2f}%  {flag}")
    print("=" * 60)
    note = ("Net of trading costs/slippage" if r.get("costs_included")
            else "Costs OFF")
    print(f"  Coarse test on reported day-moves. {note}. Not advice.\n")


if __name__ == "__main__":
    run_backtest()
