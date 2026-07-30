"""LAB DIP EXAM — put the SMALL/MICRO CAP dip books' settings on trial.

The dip books (RSI-2 < 10 in an uptrend · exit RSI-2 > 85 / 30d / 20% stop)
were validated with the OLD full-sample backtest, before the three-window
gauntlet existed. Meanwhile every honest study since has whispered the same
thing: quick-exit mean reversion decayed in the recent regime; patient exits
survived. This exam settles it.

Grid, fixed a priori (2 entries x 4 exits = 8 cells):

    ENTRY   RSI-2 < 5   ·   RSI-2 < 10          (both above the 200-DMA)
    EXITS   rsi85_30d_stop20   the CURRENT book setting
            rsi65_30d_stop20   faster relief-taking
            rsi50_60d_stop25   the scale-in book's calmer exit
            trail25_180d       the patient exit that won everywhere else

Every cell is measured per-trade on TRAIN / SELECT / untouched TEST (the
newest 30%), after costs both sides. TRAIN chooses its favourite; TEST judges
it; the current setting is printed alongside for the verdict.

    python3 -m garuda.lab_dip_exam --csv strength_history.csv
    python3 -m garuda.lab_dip_exam --csv strength_history.csv --list smallcap_list.csv

--list restricts the universe to the actual book's constituent file (e.g. the
Nifty Smallcap 250), so the exam judges the same waters the book fishes in.

PAPER / research only.
"""

import argparse
import csv as _csv
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE, _bucket_stats
from .lab_discover import three_way_split
from .setups import rsi, sma

ENTRIES = (5.0, 10.0)
EXITS = [
    # (key, exit_rsi, max_hold, hard_stop, trail)
    ("rsi85_30d_stop20", 85.0, 30, 0.20, 0.0),     # the CURRENT dip-book exit
    ("rsi65_30d_stop20", 65.0, 30, 0.20, 0.0),
    ("rsi50_60d_stop25", 50.0, 60, 0.25, 0.0),
    ("trail25_180d", None, 180, 0.0, 0.25),
]
CURRENT = (10.0, "rsi85_30d_stop20")


def _exit_index(closes, r2, i, exit_rsi, max_hold, hard_stop, trail):
    n = len(closes)
    entry = closes[i]
    peak = entry
    for j in range(i + 1, n):
        px = closes[j]
        if px <= 0:
            return j
        peak = max(peak, px)
        if hard_stop and px <= entry * (1 - hard_stop):
            return j
        if trail and px <= peak * (1 - trail):
            return j
        if exit_rsi is not None and r2[j] is not None and r2[j] > exit_rsi:
            return j
        if (j - i) >= max_hold:
            return j
    return n - 1


def run_exam(dated_series, cost=LAB_COST_PER_SIDE, log=print):
    s1, s2 = three_way_split(dated_series)
    log(f"[dip-exam] windows: TRAIN < {s1} <= SELECT < {s2} <= TEST")
    prep = []
    for _sym, dv in dated_series.items():
        if len(dv) < 260:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        prep.append((dates, closes, rsi(closes, 2), sma(closes, 200)))
    log(f"[dip-exam] {len(prep)} symbols with enough history")
    grid = {}
    for thr in ENTRIES:
        # entry days per symbol for this threshold (uptrend-filtered)
        entries_by_sym = []
        for dates, closes, r2, s200 in prep:
            idxs = [i for i in range(200, len(closes) - 1)
                    if r2[i] is not None and r2[i] < thr
                    and s200[i] is not None and closes[i] > s200[i]]
            entries_by_sym.append((dates, closes, r2, idxs))
        for key, exit_rsi, hold, stop, trail in EXITS:
            buckets = {"train": [], "select": [], "test": []}
            for dates, closes, r2, idxs in entries_by_sym:
                pos = 0
                for i in idxs:
                    if i < pos or closes[i] <= 0:
                        continue
                    j = _exit_index(closes, r2, i, exit_rsi, hold, stop, trail)
                    if j <= i or closes[j] <= 0:
                        continue
                    ret = (closes[j] / closes[i] - 1.0) - 2.0 * cost
                    w = ("train" if dates[i] < s1
                         else "select" if dates[i] < s2 else "test")
                    buckets[w].append(ret)
                    pos = j
            grid[(thr, key)] = {w: _bucket_stats(r) for w, r in buckets.items()}
            log(f"[dip-exam] RSI<{thr:.0f} x {key} done")
    pick = max(grid, key=lambda k: (grid[k]["train"]["avg"]
                                    if grid[k]["train"]["avg"] is not None else -999))
    return grid, pick, (s1, s2)


def format_exam(grid, pick, splits):
    w = 104
    lines = ["=" * w,
             "  Garuda · DIP EXAM   (the small/micro-cap books' settings on "
             "trial — TRAIN chooses, TEST judges)",
             f"  Entry RSI-2 < 5 / < 10 above the 200-DMA · four exits · "
             f"TEST from {splits[1]}",
             "=" * w,
             f"  {'cell':<28}{'TRAIN n':>8}{'avg':>8}{'PF':>6}"
             f"{'SELECT avg':>12}{'TEST n':>8}{'win':>6}{'avg':>8}{'PF':>6}"]
    lines.append("-" * w)
    fm = lambda v, s: "—" if v is None else (s % v)  # noqa: E731
    for (thr, key), st in sorted(grid.items()):
        a, b, c = st["train"], st["select"], st["test"]
        tag = " <= CURRENT BOOK" if (thr, key) == CURRENT else \
              ("  * TRAIN pick" if (thr, key) == pick else "")
        lines.append(
            f"  RSI<{thr:<4.0f}{key:<20}{a['trades']:>8}{fm(a['avg'], '%+.2f'):>8}"
            f"{fm(a['pf'], '%.2f'):>6}{fm(b['avg'], '%+.2f'):>12}"
            f"{c['trades']:>8}{fm(c['win'], '%.0f%%'):>6}{fm(c['avg'], '%+.2f'):>8}"
            f"{fm(c['pf'], '%.2f'):>6}{tag}")
    cur, pk = grid[CURRENT], grid[pick]
    lines += ["-" * w,
              f"  CURRENT book on TEST: {fm(cur['test']['avg'], '%+.2f')}%/t "
              f"(PF {fm(cur['test']['pf'], '%.2f')}) · TRAIN pick on TEST: "
              f"{fm(pk['test']['avg'], '%+.2f')}%/t (PF {fm(pk['test']['pf'], '%.2f')})",
              "  Tuning is justified ONLY if the TRAIN pick beats the current "
              "cell on TEST with a coherent",
              "  neighbourhood — one shiny cell is noise. avg = %/trade after "
              "costs both sides.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda DIP EXAM")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--list", default="",
                    help="optional constituent CSV (Symbol column) to restrict "
                         "the universe, e.g. smallcap_list.csv")
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
        print(f"[dip-exam] universe restricted to {len(dated)} names from {a.list}")
    grid, pick, splits = run_exam(dated, cost=a.cost)
    print(format_exam(grid, pick, splits))


if __name__ == "__main__":
    main()
