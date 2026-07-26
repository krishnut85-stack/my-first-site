"""Post-mortem + self-healing backtest.

The moment a trade closes at a loss, Mayura asks "WHY did this trade fail?"
— not with vibes, but with the actual price bars over the holding period:

  · Did the stock gap down on news (a shock no stop-loss can prevent)?
  · Was it in profit and gave it all back (trailing stop armed too late)?
  · Did it never move at all (weak entry — momentum already gone)?
  · Was the entry chased too far above the 200-DMA?

Each answer is logged as a LESSON (mayura_data/<face>/lessons.jsonl) so the
record of mistakes survives across runs and can be reviewed any time with
`python mayura.py lessons <face>`.

Then the SELF-HEALING step: recent closed trades are replayed against nearby
exit-rule settings (stop %, trailing arm/give, holding days). If a candidate
beats the current rules by a clear margin — across ALL recent trades, not just
the losers, so it can't overfit to one bad day — it is saved to tuning.json
and applied on the next run, clamped inside hard safety bounds so the healer
can never turn the risk rules off.

Honest limits, stated up front:
  · The replay is CLOSE-based (one decision per daily bar), mirroring how the
    engine itself checks once per day — but intraday wiggles are invisible.
  · The ATR stop is not replayed (entry-day ATR isn't in the trade log); all
    candidates are compared on the same rules, so the comparison stays fair.
  · Few trades = weak evidence. Below MIN_TRADES the healer refuses to tune.
PAPER ONLY — this tunes a paper strategy, it is not investment advice.
"""

import json
from datetime import date, datetime
from pathlib import Path

from . import config

# Exit-rule keys the healer may tune, and the hard bounds it can never leave.
# Everything else (take-profit, ATR, failed-breakout, extension guard) stays
# exactly as written in mayura.py.
TUNABLE = ("stop", "trail_arm", "trail_give", "hold_days")
BOUNDS = {
    "stop":       (0.05, 0.15),   # a stop-loss must always exist: 5–15%
    "trail_arm":  (0.06, 0.20),
    "trail_give": (0.06, 0.16),
    "hold_days":  (5, 60),        # the time stop can never be disabled
}


# --------------------------------------------------------------------------
# Trade pairing
# --------------------------------------------------------------------------
def closed_trades(pf) -> list:
    """Pair each SELL in the portfolio's trade log with its BUY.

    Returns [{symbol, qty, entry_date, entry_price, exit_date, exit_price,
    reason, pnl, pnl_pct, days_held}] in close order (oldest first)."""
    open_buys: dict = {}
    out = []
    for t in getattr(pf, "trades", []):
        sym = t.get("symbol")
        if t.get("side") == "BUY":
            open_buys[sym] = t
        elif t.get("side") == "SELL" and sym in open_buys:
            b = open_buys.pop(sym)
            entry, exitp = b.get("price") or 0.0, t.get("price") or 0.0
            pnl_pct = (exitp / entry - 1) * 100 if entry else 0.0
            out.append({
                "symbol": sym, "qty": t.get("qty") or b.get("qty") or 0,
                "entry_date": b.get("date", ""), "entry_price": entry,
                "exit_date": t.get("date", ""), "exit_price": exitp,
                "reason": t.get("reason", ""), "pnl": t.get("pnl", 0.0),
                "pnl_pct": round(pnl_pct, 2),
                "days_held": _days_between(b.get("date"), t.get("date")),
            })
    return out


def _days_between(d1, d2) -> int:
    try:
        return (date.fromisoformat(str(d2)) - date.fromisoformat(str(d1))).days
    except (TypeError, ValueError):
        return 0


# --------------------------------------------------------------------------
# Immediate post-mortem — "why did we lose?"
# --------------------------------------------------------------------------
def analyze_trade(trade: dict, bars: list, exits_cfg: dict) -> dict:
    """Diagnose one closed trade from its actual price path.

    `bars` is the symbol's daily history (must include the holding window);
    bars without dates (synthetic feed) yield a reason-only diagnosis."""
    lesson = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        **{k: trade[k] for k in ("symbol", "entry_date", "entry_price",
                                 "exit_date", "exit_price", "reason",
                                 "pnl", "pnl_pct", "days_held")},
        "causes": [], "diagnosis": "", "suggestion": "",
    }
    entry = trade["entry_price"] or 0.0
    dated = [b for b in bars if b.date]
    window = [b for b in dated
              if trade["entry_date"] <= b.date <= trade["exit_date"]]
    prior = [b for b in dated if b.date <= trade["entry_date"]]

    mfe = mae = worst_day = None
    if window and entry:
        closes = [b.close for b in window]
        mfe = round((max(closes) / entry - 1) * 100, 1)   # best point reached
        mae = round((min(closes) / entry - 1) * 100, 1)   # worst point reached
        prevs = ([prior[-2].close] if len(prior) >= 2 else []) + closes
        drops = [(prevs[i] / prevs[i - 1] - 1) * 100
                 for i in range(1, len(prevs)) if prevs[i - 1]]
        worst_day = round(min(drops), 1) if drops else None
    ext = None
    if len(prior) >= 200 and entry:
        sma200 = sum(b.close for b in prior[-200:]) / 200
        if sma200 > 0:
            ext = round((entry / sma200 - 1) * 100, 1)
    lesson.update({"mfe_pct": mfe, "mae_pct": mae,
                   "worst_day_pct": worst_day, "entry_ext_pct": ext})

    reason = (trade["reason"] or "").lower()
    causes, notes, suggest = [], [], []
    if worst_day is not None and worst_day <= -6.0:
        causes.append("gap_shock")
        notes.append(f"single-day drop of {worst_day:.1f}% — a news/gap shock "
                     "no daily stop can prevent")
        suggest.append("size, not stops, is the defence against gaps")
    if mfe is not None and mfe >= exits_cfg.get("trail_arm", 0.10) * 100 \
            and trade["pnl_pct"] < 0:
        causes.append("gave_back_gains")
        notes.append(f"was up {mfe:.1f}% but still closed red — profit was "
                     "given back before the trailing stop armed/fired")
        suggest.append("earlier trail_arm / tighter trail_give")
    elif mfe is not None and mfe <= 2.0:
        causes.append("weak_entry")
        notes.append(f"never worked (best point {mfe:+.1f}%) — momentum was "
                     "already spent at entry")
        suggest.append("tighter stop cuts these losers sooner")
    if ext is not None and ext > 25.0:
        causes.append("chased_extended")
        notes.append(f"entry was {ext:.0f}% above the 200-DMA — a chased, "
                     "extended entry")
        suggest.append("a lower max_ext guard would have skipped it")
    if "time stop" in reason:
        causes.append("dead_money")
        notes.append(f"dead money — drifted {trade['pnl_pct']:+.1f}% in "
                     f"{trade['days_held']}d without progress")
        suggest.append("shorter hold_days frees the capital sooner")
    if "failed breakout" in reason:
        causes.append("failed_breakout")
        notes.append("the breakout failed — price fell back below the level "
                     "it broke out from")
    if not notes:
        notes.append(f"exit [{trade['reason']}] after {trade['days_held']}d; "
                     "no single dominant cause found")
    lesson["causes"] = causes
    lesson["diagnosis"] = "; ".join(notes)
    lesson["suggestion"] = "; ".join(dict.fromkeys(suggest))
    return lesson


def log_lesson(lesson: dict, folder=None) -> None:
    """Append one lesson to <face folder>/lessons.jsonl (never raises)."""
    try:
        path = Path(folder or config.DATA_DIR) / "lessons.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(lesson) + "\n")
    except OSError:
        pass


def read_lessons(folder=None, last: int = 20) -> list:
    try:
        path = Path(folder or config.DATA_DIR) / "lessons.jsonl"
        lines = path.read_text(encoding="utf-8").splitlines()
        return [json.loads(l) for l in lines[-last:] if l.strip()]
    except (OSError, ValueError):
        return []


def post_mortem(ds, pf, run_exits: list, exits_cfg: dict) -> list:
    """Analyze THIS run's exits immediately after they happen.

    Losing exits always get a lesson; winners are analyzed too when they left
    a lot on the table (peaked far above where they closed). Lessons are
    appended to lessons.jsonl and returned for display."""
    closed = {t["symbol"]: t for t in closed_trades(pf)}
    lessons = []
    for sym, ltp, reason, pnl in run_exits:
        trade = closed.get(sym)
        if not trade:
            continue
        try:
            bars = ds.history(sym, config.OHLC_HISTORY_BARS)
        except Exception:  # noqa: BLE001
            bars = []
        lesson = analyze_trade(trade, bars, exits_cfg)
        keep = pnl <= 0 or (
            lesson.get("mfe_pct") is not None
            and lesson["mfe_pct"] - trade["pnl_pct"] >= 10.0)
        if keep:
            log_lesson(lesson)
            lessons.append(lesson)
    return lessons


# --------------------------------------------------------------------------
# Replay one trade under a candidate rule set
# --------------------------------------------------------------------------
def simulate_exit(entry_price: float, bars_after: list, cfg: dict):
    """Walk the daily closes after entry applying stop / take-profit /
    trailing / time rules (same order of protection as the live engine).
    Returns (exit_price, reason, bars_held); 'open' if nothing fired."""
    peak = entry_price
    for i, b in enumerate(bars_after, start=1):
        ltp = b.close
        if not ltp or not entry_price:
            continue
        peak = max(peak, ltp)
        change = (ltp - entry_price) / entry_price
        if change <= -cfg["stop"]:
            return ltp, "stop-loss", i
        if change >= cfg.get("tp", 1.0):
            return ltp, "take-profit", i
        peak_gain = (peak - entry_price) / entry_price
        if peak_gain >= cfg["trail_arm"] \
                and (peak - ltp) / peak >= cfg["trail_give"]:
            return ltp, "trailing-stop", i
        if cfg.get("hold_days") and i >= cfg["hold_days"] \
                and change < cfg.get("time_min", 0.05):
            return ltp, "time stop", i
    last = bars_after[-1].close if bars_after else entry_price
    return last, "open", len(bars_after)


def _evaluate(trades: list, bars_by_symbol: dict, cfg: dict) -> dict:
    """Replay every trade under `cfg`; equal-weight average P&L % per trade."""
    pnls = []
    for t in trades:
        bars = [b for b in bars_by_symbol.get(t["symbol"], [])
                if b.date and b.date > t["entry_date"]]
        if not bars or not t["entry_price"]:
            continue
        exitp, _reason, _held = simulate_exit(t["entry_price"], bars, cfg)
        pnls.append((exitp / t["entry_price"] - 1) * 100)
    if not pnls:
        return {"avg": 0.0, "win_rate": 0.0, "n": 0}
    return {"avg": round(sum(pnls) / len(pnls), 2),
            "win_rate": round(100 * sum(1 for p in pnls if p > 0) / len(pnls), 0),
            "n": len(pnls)}


def clamp_tuning(exits: dict) -> dict:
    """Keep only tunable keys, clamped inside the hard safety bounds."""
    out = {}
    for k in TUNABLE:
        if k not in exits:
            continue
        lo, hi = BOUNDS[k]
        v = exits[k]
        out[k] = int(min(max(v, lo), hi)) if k == "hold_days" \
            else round(min(max(float(v), lo), hi), 3)
    return out


def _candidate_grid(base: dict) -> list:
    """Small grid of rule sets NEAR the current ones (bounded, deduped).
    Nearby-only on purpose: the healer nudges, it never reinvents."""
    def around(cur, deltas, key):
        lo, hi = BOUNDS[key]
        vals = sorted({round(min(max(cur + d, lo), hi), 3) for d in deltas})
        return vals
    stops = around(base["stop"], (-0.02, 0.0, 0.02, 0.04), "stop")
    arms = around(base["trail_arm"], (-0.04, 0.0, 0.05), "trail_arm")
    gives = around(base["trail_give"], (-0.04, 0.0, 0.03), "trail_give")
    holds = sorted({int(min(max(base["hold_days"] + d, BOUNDS["hold_days"][0]),
                            BOUNDS["hold_days"][1])) for d in (0, 15)})
    grid = []
    for s in stops:
        for a in arms:
            for g in gives:
                for h in holds:
                    cand = dict(base)
                    cand.update(stop=s, trail_arm=a, trail_give=g, hold_days=h)
                    grid.append(cand)
    return grid


# --------------------------------------------------------------------------
# The self-healing backtest
# --------------------------------------------------------------------------
def heal(ds, pf, exits_cfg: dict, min_trades: int = 8, lookback: int = 30,
         min_improve: float = 1.0, fetch_delay: float = 0.0) -> dict:
    """Backtest the current exit rules vs nearby candidates over the last
    `lookback` closed trades. Returns a report dict:

      {ok, n, base: {avg, win_rate}, best: {avg, win_rate}, changes: {...},
       improved: bool, message}

    `changes` is non-empty only when a candidate beat the current rules by at
    least `min_improve` percentage points of average P&L per trade."""
    from .datasource import PaperDataSource
    if isinstance(ds, PaperDataSource):
        return {"ok": False, "message": "needs REAL Kite data — synthetic "
                "prices can't judge real trades"}
    trades = closed_trades(pf)[-lookback:]
    if len(trades) < min_trades:
        return {"ok": False,
                "message": f"only {len(trades)} closed trade(s) — the healer "
                           f"needs {min_trades}+ before it will tune anything "
                           "(too few trades = overfitting, not learning)"}
    import time
    bars_by_symbol = {}
    for sym in dict.fromkeys(t["symbol"] for t in trades):
        try:
            bars_by_symbol[sym] = ds.history(sym, config.OHLC_HISTORY_BARS)
        except Exception:  # noqa: BLE001
            bars_by_symbol[sym] = []
        if fetch_delay:
            time.sleep(fetch_delay)

    base_cfg = dict(exits_cfg)
    base = _evaluate(trades, bars_by_symbol, base_cfg)
    if not base["n"]:
        return {"ok": False, "message": "no trade could be replayed (history "
                "didn't cover the holding windows)"}
    best_cfg, best = base_cfg, base
    for cand in _candidate_grid(base_cfg):
        r = _evaluate(trades, bars_by_symbol, cand)
        if r["n"] == base["n"] and r["avg"] > best["avg"]:
            best_cfg, best = cand, r
    improved = best["avg"] - base["avg"] >= min_improve
    changes = {k: best_cfg[k] for k in TUNABLE
               if best_cfg.get(k) != base_cfg.get(k)} if improved else {}
    msg = (f"replayed {base['n']} trades: current rules avg "
           f"{base['avg']:+.2f}%/trade (win {base['win_rate']:.0f}%)")
    if changes:
        msg += (f" → best nearby avg {best['avg']:+.2f}%/trade "
                f"(win {best['win_rate']:.0f}%)")
    else:
        msg += " — no nearby rule set was clearly better; keeping current rules"
    return {"ok": True, "n": base["n"], "base": base, "best": best,
            "changes": changes, "improved": improved, "message": msg}


# --------------------------------------------------------------------------
# Tuning persistence (what the healer learned, applied on the next run)
# --------------------------------------------------------------------------
def tuning_path(folder=None) -> Path:
    return Path(folder or config.DATA_DIR) / "tuning.json"


def load_tuning(folder=None) -> dict:
    """The tuned exit overrides for this face ({} if never tuned)."""
    try:
        d = json.loads(tuning_path(folder).read_text(encoding="utf-8"))
        return clamp_tuning(d.get("exits", {}))
    except (OSError, ValueError):
        return {}


def save_tuning(changes: dict, report: dict, folder=None) -> None:
    """Persist the healer's verdict; keeps a history of every adjustment."""
    path = tuning_path(folder)
    try:
        old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    except (OSError, ValueError):
        old = {}
    exits = {**old.get("exits", {}), **clamp_tuning(changes)}
    hist = old.get("history", [])[-19:]
    hist.append({"date": date.today().isoformat(), "changes": changes,
                 "trades": report.get("n"),
                 "avg_before": report.get("base", {}).get("avg"),
                 "avg_after": report.get("best", {}).get("avg")})
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(
            {"exits": exits, "updated": date.today().isoformat(),
             "history": hist}, indent=2), encoding="utf-8")
    except OSError:
        pass
