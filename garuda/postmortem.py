"""Garuda post-mortem — the moment a trade closes at a loss, ask WHY.

Every losing exit (and every winner that gave back a big peak) gets an
immediate diagnosis from the stock's actual daily closes over the holding
window:

  · gap shock      — a single-day collapse no daily stop can prevent
  · knife          — the dip kept falling; it never traded above entry
  · gave back      — it WAS well up, then surrendered the gain before the exit
  · chased high    — entry was already far above the 200-day average
  · dead money     — a time/hold exit that went nowhere for weeks
  · by design      — rotation/rebalance books selling red is the wheel turning,
                     not a mistake; still logged so the cost is visible

Each lesson is appended to data/garuda_<book>_lessons.jsonl — a permanent
record of the fleet's mistakes — and the latest ones surface on the dashboard
card of the book that made them.

View from a shell:   python3 -m garuda.postmortem [book]

Garuda's exit-parameter tuning already lives in the LAB (lab_exits: TRAIN
chooses, untouched TEST judges) — this module is the per-trade "why", not
another tuner. PAPER ONLY.
"""

import json
from datetime import date, datetime
from pathlib import Path

from . import config

GIVEBACK_PTS = 10.0     # a winner that peaked this many %-points above its
                        # exit is worth a lesson too (the cost of a wide trail)


def lessons_path(key, data_dir=None) -> Path:
    return Path(data_dir or config.DATA_DIR) / f"garuda_{key}_lessons.jsonl"


# --------------------------------------------------------------------------
# Trade pairing — works for single-entry AND scale-in (multi-BUY) books
# --------------------------------------------------------------------------
def closed_trades(trades) -> list:
    """[{symbol, qty, entry_date, entry_price, exit_date, exit_price, reason,
    pnl, pnl_pct, days_held}] oldest-close first.

    entry_price is derived from the SELL itself (price - pnl/qty), so it is
    the true blended average even for scale-in positions with several BUYs;
    entry_date is the FIRST buy of that position group."""
    first_buy: dict = {}
    out = []
    for t in trades or []:
        sym = t.get("symbol")
        if t.get("side") == "BUY":
            first_buy.setdefault(sym, t.get("date", ""))
        elif t.get("side") == "SELL" and sym in first_buy:
            qty = t.get("qty") or 0
            px = t.get("price") or 0.0
            pnl = t.get("pnl") or 0.0
            entry = (px - pnl / qty) if qty else 0.0
            entry_date = first_buy.pop(sym)
            exit_date = t.get("date", "")
            out.append({
                "symbol": sym, "qty": qty,
                "entry_date": entry_date, "entry_price": round(entry, 2),
                "exit_date": exit_date, "exit_price": px,
                "reason": t.get("reason", ""), "pnl": pnl,
                "pnl_pct": round((px / entry - 1) * 100, 2) if entry else 0.0,
                "days_held": _days(entry_date, exit_date),
            })
    return out


def _days(d1, d2) -> int:
    try:
        return (date.fromisoformat(str(d2)) - date.fromisoformat(str(d1))).days
    except (TypeError, ValueError):
        return 0


# --------------------------------------------------------------------------
# The diagnosis — "why did this trade fail?"
# --------------------------------------------------------------------------
def analyze_trade(trade: dict, dated: list) -> dict:
    """Diagnose one closed trade. `dated` is the symbol's [(date, close)]
    history (the same per-symbol series the dashboard charts from)."""
    lesson = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        **{k: trade[k] for k in ("symbol", "entry_date", "entry_price",
                                 "exit_date", "exit_price", "reason",
                                 "pnl", "pnl_pct", "days_held")},
        "causes": [], "diagnosis": "",
    }
    entry = trade["entry_price"] or 0.0
    window = [c for d, c in dated or []
              if trade["entry_date"] <= d <= trade["exit_date"]]
    prior = [c for d, c in dated or [] if d <= trade["entry_date"]]

    mfe = mae = worst_day = None
    if window and entry:
        mfe = round((max(window) / entry - 1) * 100, 1)
        mae = round((min(window) / entry - 1) * 100, 1)
        seq = ([prior[-2]] if len(prior) >= 2 else []) + window
        drops = [(seq[i] / seq[i - 1] - 1) * 100
                 for i in range(1, len(seq)) if seq[i - 1]]
        worst_day = round(min(drops), 1) if drops else None
    ext = None
    if len(prior) >= 200 and entry:
        sma200 = sum(prior[-200:]) / 200
        if sma200 > 0:
            ext = round((entry / sma200 - 1) * 100, 1)
    lesson.update({"mfe_pct": mfe, "mae_pct": mae,
                   "worst_day_pct": worst_day, "entry_ext_pct": ext})

    reason = (trade["reason"] or "").lower()
    pnl_pct = trade["pnl_pct"]
    causes, notes = [], []
    by_design = any(w in reason for w in ("rotation", "rebalance"))
    if by_design:
        causes.append("by_design")
        notes.append(f"the wheel turned while it was {pnl_pct:+.1f}% — a "
                     "rotation exit, not a stop; the cost of the system")
    if worst_day is not None and worst_day <= -6.0:
        causes.append("gap_shock")
        notes.append(f"single-day drop of {worst_day:.1f}% — a news/gap shock "
                     "no daily stop can prevent (only sizing protects here)")
    if mfe is not None and pnl_pct < 0 and mfe >= 8.0:
        causes.append("gave_back")
        notes.append(f"was up {mfe:.1f}% but closed red — the gain was "
                     "surrendered before the exit fired")
    elif mfe is not None and mfe <= 2.0 and pnl_pct < 0 and not by_design:
        causes.append("knife")
        notes.append(f"never worked (best point {mfe:+.1f}%) — the dip kept "
                     "falling / the breakout had no follow-through")
    if pnl_pct > 0 and mfe is not None and mfe - pnl_pct >= GIVEBACK_PTS:
        causes.append("gave_back")
        notes.append(f"banked {pnl_pct:+.1f}% but peaked {mfe:+.1f}% — gave "
                     f"back {mfe - pnl_pct:.1f} pts from the top; the known "
                     "price of a wide patient trail")
    if ext is not None and ext > 25.0 and not by_design:
        causes.append("chased_high")
        notes.append(f"entry was {ext:.0f}% above the 200-day average — an "
                     "extended, chased entry")
    if ("hold" in reason and not by_design and pnl_pct < 2.0
            and "gave_back" not in causes):
        causes.append("dead_money")
        notes.append(f"time exit at {pnl_pct:+.1f}% after "
                     f"{trade['days_held']}d — capital parked in a stock "
                     "going nowhere")
    if not notes:
        notes.append(f"exit [{trade['reason']}] at {pnl_pct:+.1f}% after "
                     f"{trade['days_held']}d; no single dominant cause")
    lesson["causes"] = causes
    lesson["diagnosis"] = "; ".join(notes)
    return lesson


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------
def log_lesson(key: str, lesson: dict, data_dir=None) -> None:
    try:
        p = lessons_path(key, data_dir)
        p.parent.mkdir(parents=True, exist_ok=True)
        with p.open("a", encoding="utf-8") as f:
            f.write(json.dumps(lesson) + "\n")
    except OSError:
        pass


def read_lessons(key: str, last: int = 20, data_dir=None) -> list:
    try:
        lines = lessons_path(key, data_dir).read_text(
            encoding="utf-8").splitlines()
        return [json.loads(l) for l in lines[-last:] if l.strip()]
    except (OSError, ValueError):
        return []


# --------------------------------------------------------------------------
# Entry point — called by GarudaLive.scan() right after the day's exits
# --------------------------------------------------------------------------
def post_mortem(key: str, sells: list, trades: list, dated_by_sym: dict,
                data_dir=None) -> list:
    """Diagnose THIS scan's exits the moment they happen. `sells` is run_scan's
    list ({symbol, price, pnl, reason}); `trades` the portfolio trade log;
    `dated_by_sym` {symbol: [(date, close)]}. Losers always get a lesson;
    winners only when they gave back GIVEBACK_PTS+ from their peak."""
    if not sells:
        return []
    closed = {}
    for t in closed_trades(trades):
        closed[t["symbol"]] = t          # last close per symbol = this scan's
    lessons = []
    for s in sells:
        trade = closed.get(s.get("symbol"))
        if not trade:
            continue
        lesson = analyze_trade(trade, dated_by_sym.get(s["symbol"]) or [])
        keep = (trade["pnl"] or 0) <= 0 or (
            lesson.get("mfe_pct") is not None
            and lesson["mfe_pct"] - trade["pnl_pct"] >= GIVEBACK_PTS)
        if keep:
            log_lesson(key, lesson, data_dir)
            lessons.append(lesson)
            print(f"[postmortem] {key} {lesson['symbol']} "
                  f"{lesson['pnl_pct']:+.1f}%: {lesson['diagnosis']}",
                  flush=True)
    return lessons


# --------------------------------------------------------------------------
# Shell viewer:  python3 -m garuda.postmortem [book]
# --------------------------------------------------------------------------
def main() -> None:
    import sys
    from .strategy import PROFILES
    keys = [a for a in sys.argv[1:] if a in PROFILES] or list(PROFILES)
    any_found = False
    for k in keys:
        lessons = read_lessons(k, last=15)
        if not lessons:
            continue
        any_found = True
        print(f"\n🦅 {PROFILES[k].name} — last {len(lessons)} lesson(s):")
        for les in lessons:
            print(f"  {les.get('exit_date','?')}  {les.get('symbol','?'):12}"
                  f"{les.get('pnl_pct', 0):+7.1f}%  [{les.get('reason','')}]")
            print(f"      why: {les.get('diagnosis','')}")
    if not any_found:
        print("No lessons logged yet — one is written the moment a trade "
              "closes at a loss (or gives back a big peak).")
    print()


if __name__ == "__main__":
    main()
