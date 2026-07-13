"""LAB MINERVINI — the champion smallcap playbook, put through OUR gauntlet.

Mark Minervini (two-time US Investing Championship winner, +255% and +334%
audited years) trades small/mid caps with the SEPA method. Its price-only core
is testable on our data TODAY:

  TREND TEMPLATE (the gate — only "stage 2" uptrends may be bought):
    close > 50-DMA  ·  50-DMA > 150-DMA > 200-DMA  ·  all three RISING
    close >= 1.3x its 52-week low  ·  close within 25% of its 52-week high
  ENTRY: a fresh 20-day-high breakout while the template holds
  RISK : his signature tight 8% maximum stop, pre-written before entry

The exam races the templated entry against a PLAIN 20-day breakout (control —
isolating what the template itself is worth) across four exit styles:

    stop8_trail15_120   8% stop + 15% trail / 120d   (Minervini-style risk)
    stop8_trail25_180   8% stop + the patient trail
    stop8_target20_60   8% stop, +20% target, 60d
    trail15_120         no hard stop (the fleet's usual) — control

2 entries x 4 exits = 8 cells, fixed a priori. Per-trade stats on TRAIN /
SELECT / untouched TEST. TRAIN chooses, TEST judges. Use --list to run on the
actual smallcap-250 constituents.

    python3 -m garuda.lab_minervini --csv strength_history.csv
    python3 -m garuda.lab_minervini --csv strength_history.csv --list smallcap_list.csv

What is NOT testable yet (and matters to Minervini): volume confirmation and
earnings acceleration. Volume collection starts with the next daily fetch;
fundamentals need a data feed. PAPER / research only.
"""

import argparse
import csv as _csv
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE, _bucket_stats
from .lab_discover import three_way_split
from .setups import sma

ENTRIES = ("template_brk20", "plain_brk20")
EXITS = [
    # (key, hard_stop, trail, target, max_hold)
    ("stop8_trail15_120", 0.08, 0.15, 0.0, 120),
    ("stop8_trail25_180", 0.08, 0.25, 0.0, 180),
    ("stop8_target20_60", 0.08, 0.0, 0.20, 60),
    ("trail15_120", 0.0, 0.15, 0.0, 120),
]


def trend_template_days(closes):
    """Bar indices where Minervini's price-only Trend Template holds."""
    n = len(closes)
    s50, s150, s200 = sma(closes, 50), sma(closes, 150), sma(closes, 200)
    out = []
    for i in range(220, n):
        c = closes[i]
        if c <= 0 or s50[i] is None or s150[i] is None or s200[i] is None:
            continue
        if not (c > s50[i] > s150[i] > s200[i]):
            continue
        if not (s50[i] > s50[i - 20] and s150[i] > s150[i - 20]
                and s200[i] > s200[i - 20]):                  # all rising
            continue
        win = closes[i - 251:i + 1] if i >= 251 else closes[:i + 1]
        lo, hi = min(win), max(win)
        if lo <= 0 or c < 1.30 * lo or c < 0.75 * hi:
            continue
        out.append(i)
    return out


def _entries(closes, template=True):
    """Fresh 20-day-high breakouts, optionally gated by the Trend Template."""
    n = len(closes)
    tmpl = set(trend_template_days(closes)) if template else None
    out = []
    for i in range(220, n - 1):
        if closes[i] <= 0:
            continue
        if closes[i] < max(closes[i - 19:i + 1]):             # not a fresh 20d high
            continue
        if closes[i - 1] >= max(closes[i - 20:i]):            # not a fresh CROSS
            continue
        if tmpl is not None and i not in tmpl:
            continue
        out.append(i)
    return out


def _exit_index(closes, i, stop, trail, target, hold):
    n = len(closes)
    entry = closes[i]
    peak = entry
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
        if (j - i) >= hold:
            return j
    return n - 1


def run_exam(dated_series, cost=LAB_COST_PER_SIDE, log=print):
    s1, s2 = three_way_split(dated_series)
    log(f"[minervini] windows: TRAIN < {s1} <= SELECT < {s2} <= TEST")
    prep = []
    for _sym, dv in dated_series.items():
        if len(dv) < 280:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        prep.append((dates, closes,
                     _entries(closes, template=True),
                     _entries(closes, template=False)))
    log(f"[minervini] {len(prep)} symbols with enough history")
    grid = {}
    for ek, use_template in (("template_brk20", True), ("plain_brk20", False)):
        for xk, stop, trail, target, hold in EXITS:
            buckets = {"train": [], "select": [], "test": []}
            for dates, closes, t_idx, p_idx in prep:
                pos = 0
                for i in (t_idx if use_template else p_idx):
                    if i < pos or closes[i] <= 0:
                        continue
                    j = _exit_index(closes, i, stop, trail, target, hold)
                    if j <= i or closes[j] <= 0:
                        continue
                    ret = (closes[j] / closes[i] - 1.0) - 2.0 * cost
                    w = ("train" if dates[i] < s1
                         else "select" if dates[i] < s2 else "test")
                    buckets[w].append(ret)
                    pos = j
            grid[(ek, xk)] = {w: _bucket_stats(r) for w, r in buckets.items()}
            log(f"[minervini] {ek} x {xk} done")
    pick = max(grid, key=lambda k: (grid[k]["train"]["avg"]
                                    if grid[k]["train"]["avg"] is not None else -999))
    return grid, pick, (s1, s2)


def format_exam(grid, pick, splits):
    w = 106
    lines = ["=" * w,
             "  Garuda · MINERVINI EXAM   (the champion's price-only core vs a "
             "plain breakout — TRAIN chooses, TEST judges)",
             f"  Trend Template gate + 20d-high breakout · four exits · TEST "
             f"from {splits[1]}",
             "=" * w,
             f"  {'cell':<36}{'TRAIN n':>8}{'avg':>8}{'PF':>6}"
             f"{'SELECT avg':>12}{'TEST n':>8}{'win':>6}{'avg':>8}{'PF':>6}",
             "-" * w]
    fm = lambda v, s: "—" if v is None else (s % v)  # noqa: E731
    for (ek, xk), st in sorted(grid.items()):
        a, b, c = st["train"], st["select"], st["test"]
        tag = "  * TRAIN pick" if (ek, xk) == pick else ""
        lines.append(
            f"  {ek:<16}{xk:<20}{a['trades']:>8}{fm(a['avg'], '%+.2f'):>8}"
            f"{fm(a['pf'], '%.2f'):>6}{fm(b['avg'], '%+.2f'):>12}"
            f"{c['trades']:>8}{fm(c['win'], '%.0f%%'):>6}{fm(c['avg'], '%+.2f'):>8}"
            f"{fm(c['pf'], '%.2f'):>6}{tag}")
    pk = grid[pick]
    lines += ["-" * w,
              f"  TRAIN pick on TEST: {fm(pk['test']['avg'], '%+.2f')}%/t "
              f"(PF {fm(pk['test']['pf'], '%.2f')}, {pk['test']['trades']}t)",
              "  The template earns its keep ONLY if template rows beat plain "
              "rows on TEST at the same exits.",
              "  Volume confirmation (the other half of the playbook) becomes "
              "testable once volume history accrues.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda MINERVINI EXAM")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--list", default="",
                    help="optional constituent CSV (Symbol column), e.g. "
                         "smallcap_list.csv")
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
        print(f"[minervini] universe restricted to {len(dated)} names from {a.list}")
    grid, pick, splits = run_exam(dated, cost=a.cost)
    print(format_exam(grid, pick, splits))


if __name__ == "__main__":
    main()
