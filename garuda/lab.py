"""Garuda Strategy LAB — the edge-discovery engine (how you actually find a NEW
strategy, instead of hoping one indicator is magic).

THE HONEST TRUTH this module is built on: there is no secret strategy nobody
knows. What separates the few who compound in Indian equity from the crowd is
PROCESS — test many candidate ideas on real data, charge honest costs, and
validate every idea on data it has NEVER seen. Most retail backtests fail that
last step: they tune a rule on the whole history and then are shocked when the
"edge" evaporates live. That is overfitting, and the LAB is built to catch it.

How the LAB works (walk-forward validation):

  1. CANDIDATES — a library of genuinely different strategy hypotheses (calendar
     effects, panic reversals, volatility squeezes, leader pullbacks, 52-week-high
     drift...). Each is a fixed, plain rule — deliberately NOT parameter-swept,
     because sweeping 100 variants and keeping the best is how you manufacture a
     fake edge.
  2. SPLIT — the shared calendar is cut at a date: the older ~70% is IN-SAMPLE
     (IS, "the past the idea gets to see"), the newest ~30% is OUT-OF-SAMPLE
     (OOS, "the unseen future"). Trades are bucketed by their ENTRY date.
  3. VERDICT — an idea is only PROMOTED when it makes money after costs in BOTH
     buckets. Profitable in IS but not OOS -> OVERFIT (the classic trap, and the
     LAB's whole reason to exist). Too few trades -> THIN (no statistical claim
     either way).

Every trade is close-to-close, long-only delivery, no lookahead (day-i signals
use only closes up to day i), and costs are charged both sides at the heavy
delivery rate — the same discipline as the rest of Garuda.

    python3 -m garuda.lab --csv strength_daily.csv     # run on the top-1500 universe
    python3 -m garuda.lab --csv strength_daily.csv --oos 0.30

Results are printed AND written to data/garuda_lab_results.json, which the
dashboard's LAB tab renders. PAPER / research only — a PROMOTED verdict means
"survived honest validation", never "guaranteed money".
"""

import argparse
import json
import sys
from pathlib import Path

from . import config
from .cross import _load_long
from .setups import sma

# Delivery swing costs, both sides (brokerage + STT + exchange + GST + stamp +
# slippage). Same deliberately-heavy figure as the cross-sectional backtest.
LAB_COST_PER_SIDE = config.CROSS_COST_PER_SIDE

# Statistical floor: below this many trades a bucket proves nothing.
MIN_IS_TRADES = 60
MIN_OOS_TRADES = 25


# --------------------------------------------------------------------------
# Candidate building blocks
# --------------------------------------------------------------------------

def _trail_exit(closes, i, trail=0.0, max_hold=60, stop=0.0, target=0.0):
    """Walk forward from entry at closes[i] and return the exit index. Exits on
    a trailing stop off the running peak, a hard stop below entry, a profit
    target, or the time stop — whichever comes first. No lookahead: bar j is
    only compared against information from bars <= j."""
    entry = closes[i]
    peak = entry
    n = len(closes)
    for j in range(i + 1, n):
        px = closes[j]
        if px <= 0:
            return j
        peak = max(peak, px)
        if stop and px <= entry * (1 - stop):
            return j
        if target and px >= entry * (1 + target):
            return j
        if trail and px <= peak * (1 - trail):
            return j
        if (j - i) >= max_hold:
            return j
    return n - 1


def _trade(dates, closes, i, j, cost):
    """One closed round trip: entry close -> exit close, costs both sides."""
    if j <= i or closes[i] <= 0 or closes[j] <= 0:
        return None
    return {"entry_date": dates[i],
            "ret": (closes[j] / closes[i] - 1.0) - 2.0 * cost}


# --------------------------------------------------------------------------
# The candidate library — each takes (dates, closes, cost) for ONE symbol and
# returns its list of closed trades. Rules are fixed on purpose (see docstring).
# --------------------------------------------------------------------------

def cand_turn_of_month(dates, closes, cost):
    """Calendar edge: buy 3 trading days before month-end, sell after the 3rd
    trading day of the new month. Institutional inflows + India's salary-day SIP
    wave cluster around the month turn."""
    trades = []
    n = len(dates)
    i = 0
    while i < n - 6:
        month_now = dates[i][:7]
        # last trading day of this month = last index sharing the month prefix
        j = i
        while j + 1 < n and dates[j + 1][:7] == month_now:
            j += 1
        entry = j - 2                       # 3rd-to-last trading day of the month
        exit_ = j + 3                       # 3rd trading day of the next month
        if entry > i - 1 and exit_ < n:
            t = _trade(dates, closes, entry, exit_, cost)
            if t:
                trades.append(t)
        i = j + 1
    return trades


def cand_panic_drop(dates, closes, cost):
    """Panic reversal: a quality name (above its 200-DMA) knifed >=6% in ONE day.
    Fear overshoots on good names; buy the panic, take a quick +5%, cut at -10%,
    give it 10 days."""
    trades = []
    s = sma(closes, 200)
    i = 200
    n = len(closes)
    while i < n - 1:
        drop = closes[i] / closes[i - 1] - 1.0 if closes[i - 1] > 0 else 0.0
        if drop <= -0.06 and s[i] is not None and closes[i] > s[i]:
            j = _trail_exit(closes, i, max_hold=10, stop=0.10, target=0.05)
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


def cand_three_down(dates, closes, cost):
    """Micro mean reversion without RSI: three or more consecutive red closes
    while still above the 200-DMA. Exit on the first green close (or 7 days) —
    the shortest, simplest dip-buy there is."""
    trades = []
    s = sma(closes, 200)
    i = 200
    n = len(closes)
    while i < n - 1:
        if (closes[i] < closes[i - 1] < closes[i - 2] < closes[i - 3]
                and s[i] is not None and closes[i] > s[i]):
            j = i + 1
            while j < n - 1 and (j - i) < 7 and closes[j] <= closes[j - 1]:
                j += 1
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


def cand_weekly_crash(dates, closes, cost):
    """Bigger fear, longer bounce: down >=10% over a week (5 bars) while above
    the 200-DMA. Hold 10 days with a 15% disaster stop."""
    trades = []
    s = sma(closes, 200)
    i = 200
    n = len(closes)
    while i < n - 1:
        wk = closes[i] / closes[i - 5] - 1.0 if closes[i - 5] > 0 else 0.0
        if wk <= -0.10 and s[i] is not None and closes[i] > s[i]:
            j = _trail_exit(closes, i, max_hold=10, stop=0.15)
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


def cand_vol_squeeze(dates, closes, cost):
    """Volatility-contraction breakout: the last 10 days' close-range squeezed to
    <40% of its 60-day average range AND today prints a fresh 20-day high. Quiet
    coils tend to resolve explosively; ride the release on a 15% trail."""
    trades = []
    n = len(closes)

    def _range(k):                       # close-based 10-day range ending at k
        w = closes[k - 9:k + 1]
        return (max(w) - min(w)) / closes[k] if closes[k] > 0 else 0.0

    i = 80
    while i < n - 1:
        avg_range = sum(_range(k) for k in range(i - 59, i + 1)) / 60.0
        hi20 = max(closes[i - 19:i + 1])
        if (avg_range > 0 and _range(i) < 0.40 * avg_range
                and closes[i] >= hi20 and closes[i] > 0):
            j = _trail_exit(closes, i, trail=0.15, max_hold=60)
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


def cand_leader_pullback(dates, closes, cost):
    """Buy the leader's rest stop: a stock up >25% in ~3 months and above its
    200-DMA that has pulled back BELOW its 20-DMA. The leaders book buys the run;
    this buys the pause. 10% trail, 45-day hold."""
    trades = []
    s200 = sma(closes, 200)
    s20 = sma(closes, 20)
    i = 200
    n = len(closes)
    while i < n - 1:
        mom = closes[i] / closes[i - 63] - 1.0 if closes[i - 63] > 0 else 0.0
        if (mom >= 0.25 and s200[i] is not None and closes[i] > s200[i]
                and s20[i] is not None and closes[i] < s20[i]):
            j = _trail_exit(closes, i, trail=0.10, max_hold=45)
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


def cand_high_52w(dates, closes, cost):
    """The 52-week-high anomaly: buy the day a stock CROSSES into 2% of its
    1-year high (anchoring makes investors under-react near old highs). 15%
    trail, 120-day hold. Entry only on the cross, not every day in the band."""
    trades = []
    n = len(closes)
    i = 252
    while i < n - 1:
        hi = max(closes[i - 251:i + 1])
        near = hi > 0 and closes[i] >= 0.98 * hi
        hi_prev = max(closes[i - 252:i])
        was_near = hi_prev > 0 and closes[i - 1] >= 0.98 * hi_prev
        if near and not was_near:
            j = _trail_exit(closes, i, trail=0.15, max_hold=120)
            t = _trade(dates, closes, i, j, cost)
            if t:
                trades.append(t)
            i = j
        i += 1
    return trades


CANDIDATES = [
    {"key": "turn_of_month", "name": "Turn-of-Month",
     "hypothesis": "Month-end/-start institutional + SIP inflows lift prices",
     "rules": "Buy 3 trading days before month-end · sell after the 3rd trading day "
              "of the new month", "fn": cand_turn_of_month},
    {"key": "panic_drop", "name": "1-Day Panic Reversal",
     "hypothesis": "Fear overshoots on quality names — single-day dumps bounce",
     "rules": "Buy a >=6% one-day drop above the 200-DMA · +5% target, 10% stop, "
              "10-day hold", "fn": cand_panic_drop},
    {"key": "three_down", "name": "3 Red Closes",
     "hypothesis": "Short losing streaks in uptrends mean-revert fast",
     "rules": "Buy 3+ consecutive down closes above the 200-DMA · sell the first "
              "green close or 7 days", "fn": cand_three_down},
    {"key": "weekly_crash", "name": "1-Week Crash Bounce",
     "hypothesis": "A -10% week on an uptrending name overshoots",
     "rules": "Buy a <=-10% 5-day return above the 200-DMA · 10-day hold, 15% stop",
     "fn": cand_weekly_crash},
    {"key": "vol_squeeze", "name": "Volatility Squeeze",
     "hypothesis": "Quiet range contractions resolve into explosive moves",
     "rules": "Buy a 20-day-high breakout out of a 10-day range squeezed <40% of "
              "normal · 15% trail, 60-day hold", "fn": cand_vol_squeeze},
    {"key": "leader_pullback", "name": "Leader Pullback",
     "hypothesis": "Strong 3-month leaders get bought on their first rest",
     "rules": "Buy a stock up >25%/3mo, above the 200-DMA, pulled back under its "
              "20-DMA · 10% trail, 45-day hold", "fn": cand_leader_pullback},
    {"key": "high_52w", "name": "52-Week-High Drift",
     "hypothesis": "Anchoring: investors under-react as old highs are reclaimed",
     "rules": "Buy the cross into 2% of the 52-week high · 15% trail, 120-day hold",
     "fn": cand_high_52w},
]


# --------------------------------------------------------------------------
# Walk-forward harness
# --------------------------------------------------------------------------

def split_date_of(dated_series: dict, oos_frac: float = 0.30) -> str:
    """The calendar date that cuts the shared history: entries strictly BEFORE
    it are in-sample, entries on/after it are out-of-sample."""
    all_dates = sorted({d for dv in dated_series.values() for d, _ in dv})
    if not all_dates:
        return ""
    cut = int(len(all_dates) * (1.0 - oos_frac))
    cut = min(max(cut, 0), len(all_dates) - 1)
    return all_dates[cut]


def _bucket_stats(rets):
    if not rets:
        return {"trades": 0, "win": None, "avg": None, "pf": None, "worst": None}
    wins = [r for r in rets if r > 0]
    gross_loss = -sum(r for r in rets if r <= 0)
    return {
        "trades": len(rets),
        "win": round(len(wins) / len(rets) * 100, 1),
        "avg": round(sum(rets) / len(rets) * 100, 3),          # % per trade
        "pf": round(sum(wins) / gross_loss, 2) if gross_loss > 0 else None,
        "worst": round(min(rets) * 100, 2),
    }


def _verdict(is_st, oos_st):
    """PROMOTED only when the idea makes money after costs in BOTH periods —
    the whole point of the LAB. IS-only profit is the overfitting trap."""
    if is_st["trades"] < MIN_IS_TRADES or oos_st["trades"] < MIN_OOS_TRADES:
        return "THIN"
    if is_st["avg"] is None or is_st["avg"] <= 0:
        return "REJECTED"
    if oos_st["avg"] is None or oos_st["avg"] <= 0:
        return "OVERFIT"
    if oos_st["pf"] is not None and oos_st["pf"] < 1.1:
        return "WEAK"
    return "PROMOTED"


def run_lab(dated_series: dict, candidates=None, oos_frac: float = 0.30,
            cost: float = LAB_COST_PER_SIDE) -> dict:
    """Run every candidate over every symbol, bucket the trades by entry date
    around the walk-forward split, and attach a verdict per candidate.
    dated_series: {symbol: [(date, close), ...] sorted by date}."""
    candidates = candidates if candidates is not None else CANDIDATES
    split = split_date_of(dated_series, oos_frac)
    results = []
    for c in candidates:
        is_rets, oos_rets = [], []
        for _sym, dv in dated_series.items():
            if len(dv) < 80:
                continue
            dates = [d for d, _ in dv]
            closes = [v for _, v in dv]
            for t in c["fn"](dates, closes, cost):
                (is_rets if t["entry_date"] < split else oos_rets).append(t["ret"])
        is_st, oos_st = _bucket_stats(is_rets), _bucket_stats(oos_rets)
        results.append({"key": c["key"], "name": c["name"],
                        "hypothesis": c["hypothesis"], "rules": c["rules"],
                        "is": is_st, "oos": oos_st,
                        "verdict": _verdict(is_st, oos_st)})
    order = {"PROMOTED": 0, "WEAK": 1, "OVERFIT": 2, "THIN": 3, "REJECTED": 4}
    results.sort(key=lambda r: (order[r["verdict"]],
                                -(r["oos"]["avg"] if r["oos"]["avg"] is not None else -999)))
    return {"split_date": split, "oos_frac": oos_frac, "cost_per_side": cost,
            "universe": len(dated_series), "results": results}


# --------------------------------------------------------------------------
# Persistence + report
# --------------------------------------------------------------------------

def results_path() -> Path:
    return config.DATA_DIR / "garuda_lab_results.json"


def save_results(res: dict, source: str, path: Path | None = None) -> Path:
    from datetime import datetime, timezone, timedelta
    p = path or results_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    ist = datetime.now(timezone(timedelta(hours=5, minutes=30)))
    p.write_text(json.dumps({**res, "source": source,
                             "generated": ist.strftime("%Y-%m-%d %H:%M IST")}, indent=2))
    return p


def load_results(path: Path | None = None):
    p = path or results_path()
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except (OSError, ValueError):
        return None


def format_lab(res: dict, source: str) -> str:
    w = 100
    lines = ["=" * w,
             f"  {config.BOT_NAME} · STRATEGY LAB   (walk-forward edge discovery — "
             f"IS learns, OOS judges)",
             f"  Data: {source} · {res['universe']} symbols · split {res['split_date']} "
             f"(last {res['oos_frac']*100:.0f}% unseen) · cost {res['cost_per_side']*100:.2f}%/side",
             "=" * w,
             f"  {'CANDIDATE':<22}{'IS n':>6}{'win':>6}{'avg%':>8}{'PF':>6}"
             f"{'OOS n':>8}{'win':>6}{'avg%':>8}{'PF':>6}{'VERDICT':>12}",
             "-" * w]
    fm = lambda v, s="%s": "—" if v is None else (s % v)  # noqa: E731
    for r in res["results"]:
        a, b = r["is"], r["oos"]
        lines.append(
            f"  {r['name']:<22}{a['trades']:>6}{fm(a['win'], '%.0f%%'):>6}"
            f"{fm(a['avg'], '%+.2f'):>8}{fm(a['pf'], '%.2f'):>6}"
            f"{b['trades']:>8}{fm(b['win'], '%.0f%%'):>6}"
            f"{fm(b['avg'], '%+.2f'):>8}{fm(b['pf'], '%.2f'):>6}{r['verdict']:>12}")
    lines += ["-" * w,
              "  PROMOTED = profitable after costs in BOTH periods -> worth a paper book.",
              "  OVERFIT  = made money on the past, LOST on unseen data — the trap the LAB exists to catch.",
              "  WEAK/THIN = real but marginal / too few trades to claim anything.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda Strategy LAB (walk-forward)")
    ap.add_argument("--csv", default="strength_daily.csv",
                    help="long CSV (symbol,date,close) — default: the top-1500 universe")
    ap.add_argument("--oos", type=float, default=0.30,
                    help="fraction of the calendar reserved as unseen OOS (default 0.30)")
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE,
                    help="per-side cost fraction (default %.4f)" % LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run on the droplet where the daily CSVs live")
    long = _load_long(p)
    dated = {s: sorted(dv.items()) for s, dv in long.items()}
    res = run_lab(dated, oos_frac=a.oos, cost=a.cost)
    print(format_lab(res, p.name))
    out = save_results(res, p.name)
    print(f"\nWrote {out} — the dashboard's LAB tab now shows this run.")


if __name__ == "__main__":
    main()
