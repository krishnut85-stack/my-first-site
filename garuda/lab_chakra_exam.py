"""LAB CHAKRA EXAM — how hard can the wheel honestly be pushed?

CHAKRA (monthly top-20 six-month-momentum rotation) is the fleet's highest
validated CAGR. Two dials could push it harder, both with a known price:

    CONCENTRATION  top-5 / top-10 / top-15 / top-20 — fewer names means more
                   of the winners' fire, and more of any single blow-up.
    LOOKBACK       63 / 126 / 189 bars (~3 / 6 / 9 months of momentum).

A 4 x 3 grid, fixed A PRIORI (monthly cadence and the 200-DMA filter are kept
frozen — they're validated). To stay honest under selection pressure:

    * every variant is simulated over the FULL history;
    * the "pick" is made from the TRAIN period only (everything before the
      TEST window);
    * the untouched TEST window (newest 30%) judges that pick — and the full
      TEST surface is printed so one lucky cell can't hide among dead ones.

    python3 -m garuda.lab_chakra_exam --csv strength_history.csv

PAPER / research only. Concentration raises drawdowns as surely as returns —
read the DD column with the same eyes as the CAGR column.
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_portfolio import metrics
from .lab_tournament import (book_chakra, judge_window_start, prepare,
                             window_metrics)

TOPS = (5, 10, 15, 20)
LOOKS = (63, 126, 189)


def train_metrics(curve, start, capital):
    seg = [(d, v) for d, v in curve if d < start]
    if len(seg) < 40:
        return None
    return metrics(seg, capital)


def run_exam(prep, start, capital, cost, log=print):
    grid = {}
    for top in TOPS:
        for look in LOOKS:
            log(f"[chakra-exam] top-{top} x {look}d lookback ...")
            sim = book_chakra(prep, capital, cost, top=top, mom=look)
            grid[(top, look)] = {
                "train": train_metrics(sim["curve"], start, capital),
                "test": window_metrics(sim["curve"], start),
                "full": metrics(sim["curve"], capital),
            }
    pick = max(grid, key=lambda k: (grid[k]["train"] or {}).get("cagr_pct", -999))
    return grid, pick


def format_exam(grid, pick, start, capital):
    w = 100
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · CHAKRA EXAM   (concentration x lookback — TRAIN "
             "chooses, untouched TEST judges)",
             f"  Grid: top {'/'.join(map(str, TOPS))} names x "
             f"{'/'.join(map(str, LOOKS))}-bar momentum · monthly cadence and "
             f"200-DMA filter frozen · TEST from {start}",
             "=" * w,
             "  TEST-window CAGR (the unseen surface) · drawdown in brackets:"]
    corner = "top\\look"
    lines.append("  " + f"{corner:>10}" + "".join(f"{lk:>22}d" for lk in LOOKS))
    for top in TOPS:
        row = f"  {top:>9}  "
        for lk in LOOKS:
            st = grid[(top, lk)]["test"]
            mark = "*" if (top, lk) == pick else " "
            cell = (f"{st['cagr_pct']:+.1f}% ({st['max_dd_pct']:.0f}%){mark}"
                    if st else "—")
            row += f"{cell:>23}"
        lines.append(row)
    lines += ["-" * w, "  FULL-PERIOD final rupees / CAGR:"]
    for top in TOPS:
        row = f"  top-{top:<6}"
        for lk in LOOKS:
            fm = grid[(top, lk)]["full"]
            row += f"{money(fm['final'])} {fm['cagr_pct']:+.1f}%".rjust(23)
        lines.append(row)
    p = grid[pick]
    tr, te = p["train"], p["test"]
    holds = (te and tr and te["cagr_pct"] > 0)
    base = grid[(20, 126)]
    lines += ["-" * w,
              f"  TRAIN's pick (*): top-{pick[0]} x {pick[1]}d -> TRAIN "
              f"{tr['cagr_pct']:+.1f}% · TEST {te['cagr_pct']:+.1f}% "
              f"(DD {te['max_dd_pct']:.1f}%)" if tr and te else "  pick unmeasurable",
              f"  Current book (top-20 x 126d)  -> TEST "
              f"{base['test']['cagr_pct']:+.1f}% (DD {base['test']['max_dd_pct']:.1f}%) · "
              f"full {base['full']['cagr_pct']:+.1f}%",
              f"  VERDICT: {'TRAIN pick HOLDS on unseen data' if holds else 'TRAIN pick FAILS unseen data'}",
              "  Read the SURFACE: smooth neighbourhoods are robust; one lucky "
              "cell among dead ones is noise.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda CHAKRA EXAM")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    print(f"[chakra-exam] {len(dated)} symbols · preparing ...")
    prep = prepare(dated)
    start = judge_window_start(dated)
    grid, pick = run_exam(prep, start, a.capital, a.cost)
    print(format_exam(grid, pick, start, a.capital))


if __name__ == "__main__":
    main()
