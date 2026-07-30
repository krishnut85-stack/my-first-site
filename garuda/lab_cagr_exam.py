"""LAB CAGR EXAM — does picking the HIGHEST past-CAGR names beat momentum?

The screener instinct: "select the small caps whose CAGR is highest." Ranking
stocks by their return over a fixed horizon IS ranking them by CAGR over that
horizon (same order, different units) — so the question is really: WHICH
horizon of past growth predicts future growth?

The literature says medium horizons (6-12 months) persist and long horizons
(3-5 years) REVERSE. This exam tests that on our own waters. The validated
CHAKRA machinery is kept frozen (monthly cadence, top-20, 200-DMA filter);
only the ranking horizon is swept, fixed a priori:

    126 bars (~6m) · 189 (~9m, the CHAKRA book) · 252 (~1y) · 504 (~2y)
    · 756 (~3y)

Honesty rules, same as every exam:
  * every horizon is simulated over the full history;
  * curves are compared from a common FAIR START (after the longest horizon's
    warmup) so short horizons don't win by simply trading earlier;
  * TRAIN (before the newest 30%) chooses its favourite; the untouched TEST
    window judges it; the CHAKRA baseline is printed alongside.

    python3 -m garuda.lab_cagr_exam --csv strength_history.csv --list smallcap_list.csv

PAPER / research only. Universe is today's constituents: survivorship-biased,
an upper bound — and it flatters LONG horizons most (a stock with a great
3-year CAGR that then died is exactly what this data cannot show).
"""

import argparse
import csv as _csv
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_portfolio import metrics
from .lab_tournament import book_chakra, prepare, window_metrics

LOOKS = (126, 189, 252, 504, 756)
BASELINE = 189                     # the validated CHAKRA lookback
LABELS = {126: "6 months", 189: "9m CHAKRA", 252: "1 year",
          504: "2 years", 756: "3 years"}
MIN_TRAIN_BARS = 250               # a horizon must leave >= ~1y of TRAIN


def run_exam(prep, capital, cost, looks=LOOKS, log=print):
    calendar = sorted({d for p in prep.values() for d in p["px"]})
    test_i = int(len(calendar) * 0.70)
    test_start = calendar[test_i]
    usable = [lk for lk in looks if test_i - lk >= MIN_TRAIN_BARS]
    for lk in looks:
        if lk not in usable:
            log(f"[cagr-exam] {lk}-bar horizon SKIPPED — leaves "
                f"{max(0, test_i - lk)} TRAIN bars (< {MIN_TRAIN_BARS})")
    if not usable:
        raise SystemExit("history too short for every horizon — need a "
                         "deeper strength_history.csv")
    fair_start = calendar[max(usable)]
    grid = {}
    for lk in usable:
        log(f"[cagr-exam] ranking by {lk}-bar CAGR ({LABELS.get(lk, lk)}) ...")
        sim = book_chakra(prep, capital, cost, top=20, mom=lk)
        fair = [(d, v) for d, v in sim["curve"] if d >= fair_start]
        # rebase every curve to the same rupees at the fair start, so a short
        # horizon gets no credit for trading during the long horizons' warmup
        base = fair[0][1] if fair else capital
        fair = [(d, v / base * capital) for d, v in fair]
        train = [(d, v) for d, v in fair if d < test_start]
        grid[lk] = {
            "train": metrics(train, capital) if len(train) >= 40 else None,
            "test": window_metrics(sim["curve"], test_start),
            "full": metrics(fair, capital) if len(fair) >= 40 else None,
        }
    pick = max(grid, key=lambda k: (grid[k]["train"] or {}).get("cagr_pct", -999))
    return grid, pick, (fair_start, test_start)


def format_exam(grid, pick, splits):
    w = 100
    fair_start, test_start = splits
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · CAGR EXAM   (which horizon of past growth predicts "
             "future growth?)",
             "  CHAKRA machinery frozen (monthly · top-20 · 200-DMA); only "
             "the ranking horizon moves.",
             f"  Fair start {fair_start} (common warmup) · TEST from "
             f"{test_start} · survivorship-biased: UPPER BOUND",
             "=" * w,
             f"  {'horizon':<14}{'bars':>6}{'TRAIN CAGR':>12}{'DD':>8}"
             f"{'TEST CAGR':>12}{'DD':>8}{'full FINAL':>16}{'CAGR':>9}"]
    lines.append("-" * w)
    fm = lambda st, k: f"{st[k]:+.1f}%" if st else "—"  # noqa: E731
    dd = lambda st: f"{st['max_dd_pct']:.0f}%" if st else "—"  # noqa: E731
    for lk in sorted(grid):
        st = grid[lk]
        tag = ("  <= CHAKRA book" if lk == BASELINE else "") + \
              ("  * TRAIN pick" if lk == pick else "")
        fin = money(st["full"]["final"]) if st["full"] else "—"
        lines.append(
            f"  {LABELS.get(lk, str(lk)):<14}{lk:>6}"
            f"{fm(st['train'], 'cagr_pct'):>12}{dd(st['train']):>8}"
            f"{fm(st['test'], 'cagr_pct'):>12}{dd(st['test']):>8}"
            f"{fin:>16}{fm(st['full'], 'cagr_pct'):>9}{tag}")
    base = grid.get(BASELINE)
    pk = grid[pick]
    longs = [lk for lk in grid if lk >= 252 and grid[lk]["test"]]
    best_long = max(longs, key=lambda k: grid[k]["test"]["cagr_pct"]) if longs else None
    lines.append("-" * w)
    if base and base["test"] and pk["test"]:
        lines.append(f"  TRAIN's pick (*): {LABELS.get(pick, pick)} -> TEST "
                     f"{pk['test']['cagr_pct']:+.1f}% (DD "
                     f"{pk['test']['max_dd_pct']:.1f}%) · CHAKRA baseline TEST "
                     f"{base['test']['cagr_pct']:+.1f}% (DD "
                     f"{base['test']['max_dd_pct']:.1f}%)")
        if best_long is not None and (grid[best_long]["test"]["cagr_pct"]
                                      > base["test"]["cagr_pct"]):
            lines.append(f"  VERDICT: long-horizon CAGR ranking "
                         f"({LABELS[best_long]}) BEATS the 9-month book on "
                         "unseen data — a real find, retest before believing.")
        else:
            lines.append("  VERDICT: the 6-12 month horizon stays king — "
                         "buying multi-year CAGR leaders is buying AFTER the "
                         "move (matches the reversal literature).")
    else:
        lines.append("  VERDICT: unmeasurable — not enough history in a window.")
    lines += ["  Remember: this universe only contains survivors, and long "
              "horizons enjoy that flattery the most.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda CAGR EXAM")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--list", default="",
                    help="optional constituent CSV (Symbol column) to restrict "
                         "the universe, e.g. smallcap_list.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    if a.list:
        lp = Path(a.list)
        if not lp.exists():
            sys.exit(f"{a.list} not found")
        with open(lp, newline="", encoding="utf-8") as f:
            keep = {(r.get("Symbol") or r.get("symbol") or "").strip()
                    for r in _csv.DictReader(f)}
        dated = {s: dv for s, dv in dated.items() if s in keep}
        print(f"[cagr-exam] universe restricted to {len(dated)} names from {a.list}")
    print(f"[cagr-exam] {len(dated)} symbols · preparing ...")
    prep = prepare(dated)
    grid, pick, splits = run_exam(prep, a.capital, a.cost)
    print(format_exam(grid, pick, splits))


if __name__ == "__main__":
    main()
