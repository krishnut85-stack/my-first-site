"""Walk-forward backtest over your daily CSV snapshots.

Workflow: keep each day's CSV in data/snapshots/ (e.g. 2026-06-20.csv,
2026-06-21.csv, ...). Upload today's file via Termius and copy it into
snapshots/ to grow the history.

Method (honest and simple):
  • On day T, rank industries and pick the top-N (after the PE filter).
  • The realized next-day return of each pick is taken from day T+1's
    "Day Change %" column in the snapshot for that industry.
  • The strategy's daily return = average of the picks' next-day moves.
  • Compound across all snapshot pairs and compare to a buy-everything
    benchmark (average day-change of all industries).

This uses REAL reported industry day-moves, so it is a genuine (if coarse)
test of whether the ranking adds value. It is still not a guarantee of future
results, and it ignores costs, slippage and intraday stops.
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

    strat_equity = 1.0
    bench_equity = 1.0
    rows = []
    wins = 0

    for today, nextday in zip(snaps[:-1], snaps[1:]):
        picks = top_industries(csv_path=today)
        realized = _day_change_map(nextday)

        pick_rets = [realized[p.name] / 100.0 for p in picks if p.name in realized]
        all_rets = [v / 100.0 for v in realized.values()]
        if not pick_rets:
            continue

        strat_r = mean(pick_rets)
        bench_r = mean(all_rets) if all_rets else 0.0
        strat_equity *= (1 + strat_r)
        bench_equity *= (1 + bench_r)
        if strat_r > bench_r:
            wins += 1
        rows.append((nextday.stem, strat_r * 100, bench_r * 100))

    result = {
        "ok": True,
        "days": len(rows),
        "strategy_return_pct": (strat_equity - 1) * 100,
        "benchmark_return_pct": (bench_equity - 1) * 100,
        "win_rate_pct": (wins / len(rows) * 100) if rows else 0.0,
        "rows": rows,
    }
    if verbose:
        _print(result)
    return result


def _print(r: dict) -> None:
    print("\n" + "=" * 60)
    print("  SectorBot · WALK-FORWARD BACKTEST (industry day-moves)")
    print("=" * 60)
    print(f"  Days tested        : {r['days']}")
    print(f"  Strategy return    : {r['strategy_return_pct']:+.2f}%")
    print(f"  Benchmark (all)    : {r['benchmark_return_pct']:+.2f}%")
    print(f"  Days beating bench : {r['win_rate_pct']:.0f}%")
    print("-" * 60)
    for day, s, b in r["rows"][-10:]:
        flag = "✓" if s > b else " "
        print(f"   {day:14} strat {s:+6.2f}%  bench {b:+6.2f}%  {flag}")
    print("=" * 60)
    print("  Coarse test on reported day-moves; ignores costs/slippage. Not advice.\n")


if __name__ == "__main__":
    run_backtest()
