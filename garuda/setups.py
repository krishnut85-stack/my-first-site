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
    out = [None] * len(closes)
    for i in range(period - 1, len(closes)):
        out[i] = sum(closes[i - period + 1:i + 1]) / period
    return out


def oversold_bounce_trades(closes, entry_rsi=10.0, exit_rsi=65.0,
                           trend_sma=200, max_hold=10, cost_per_side=None,
                           stop_loss=0.0, profit_target=0.0, use_trend=True):
    """Return a list of per-trade net returns for one stock's daily closes.

    stop_loss / profit_target (fractions, 0 = off) cut losers / lock winners at
    the close that breaches them — the principled fix for a high win rate that
    still loses (it caps the rare falling-knife trades that eat the small wins).
    Checked at the daily close, so there is no intraday lookahead."""
    cost = config.CROSS_COST_PER_SIDE if cost_per_side is None else cost_per_side
    if len(closes) < trend_sma + 5:
        return []
    r = rsi(closes, 2)
    s = sma(closes, trend_sma)
    trades = []
    i = trend_sma
    while i < len(closes) - 1:
        in_uptrend = (not use_trend) or (s[i] is not None and closes[i] > s[i])
        oversold = r[i] is not None and r[i] < entry_rsi
        if in_uptrend and oversold:
            entry = closes[i]
            j = i + 1
            while j < len(closes) - 1:
                px = closes[j]
                if stop_loss and px <= entry * (1 - stop_loss):
                    break                              # stop-loss hit
                if profit_target and px >= entry * (1 + profit_target):
                    break                              # profit target hit
                if (r[j] is not None and r[j] > exit_rsi) or (j - i) >= max_hold:
                    break
                j += 1
            ret = (closes[j] - entry) / entry - 2 * cost   # entry + exit cost
            trades.append(ret)
            i = j + 1
        else:
            i += 1
    return trades


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
    g = grids or {
        "entry": [5, 10, 15, 20, 25, 30],
        "exit": [65, 75, 85],
        "hold": [10, 15, 20, 30],
        "trend": [True, False],
    }
    out = []
    for e, x, h, t in itertools.product(g["entry"], g["exit"], g["hold"], g["trend"]):
        r = backtest(panel, entry_rsi=e, exit_rsi=x, max_hold=h, use_trend=t)
        if r.get("trades"):
            out.append({"avg": r["avg_return_pct"], "pf": r["profit_factor"] or 0.0,
                        "win": r["win_rate_pct"], "trades": r["trades"],
                        "entry": e, "exit": x, "hold": h, "trend": t})
    out.sort(key=lambda d: d["avg"], reverse=True)
    return out


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
    if "--sweep" in args:
        print(format_sweep(sweep(panel)))
        return
    r = backtest(panel,
                 entry_rsi=_opt("--entry", float, 10.0),
                 exit_rsi=_opt("--exit", float, 65.0),
                 max_hold=_opt("--hold", int, 10),
                 stop_loss=_opt("--stop", float, 0.0),        # e.g. 0.05 = cut at -5%
                 profit_target=_opt("--target", float, 0.0),  # e.g. 0.06 = take +6%
                 use_trend=("--no-trend" not in args))         # drop the uptrend filter
    print(format_report(r, f"{path} ({len(panel)} symbols)"))


if __name__ == "__main__":
    main()
