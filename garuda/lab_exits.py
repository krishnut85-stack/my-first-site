"""LAB EXITS — is 15% trail / 120 days actually the best exit, or just a number?

DISCOVER raced six exit FAMILIES and "15% trail / 120d" won — but it never
fine-swept the numbers. This module does that, without falling into the classic
trap (sweeping the full history and keeping the best = manufacturing overfit):

  GRID    : trailing stops 10/12/15/20/25%  x  time stops 60/90/120/180 days
  ENTRIES : the two validated ones only — the 52-week-high cross (HI52) and the
            -8%-week-above-50-DMA crash bounce (CRASH)
  METHOD  : every combo is measured on TRAIN (oldest 50%), SELECT (middle 20%)
            and untouched TEST (newest 30%), after costs. The sweep "chooses"
            its winner using TRAIN ONLY; TEST then judges that choice. We also
            print the full TEST grid so you can see how FLAT the surface is —
            a flat surface means the exact number barely matters (robust); a
            spiky one means any single "best" cell is probably luck.

    python3 -m garuda.lab_exits --csv strength_history.csv

PAPER / research only.
"""

import argparse
import sys
from pathlib import Path

from . import config
from .cross import _load_long
from .lab import LAB_COST_PER_SIDE, _bucket_stats, _trail_exit
from .lab_discover import three_way_split
from .lab_portfolio import signals_crash, signals_hi52

TRAILS = (0.10, 0.12, 0.15, 0.20, 0.25)
HOLDS = (60, 90, 120, 180)

ENTRIES = [
    ("HI52", "52-week-high cross", signals_hi52),
    ("CRASH", "-8% week above 50-DMA", signals_crash),
]


def _entry_indices(dates, closes, signal_fn):
    """Bar indices of the entry signals (signal fns report dates; map back)."""
    pos = {d: i for i, d in enumerate(dates)}
    return [pos[d] for d, _ in signal_fn(dates, closes)]


def sweep(dated_series, cost=LAB_COST_PER_SIDE, log=print):
    s1, s2 = three_way_split(dated_series)
    log(f"[exits] windows: TRAIN < {s1} <= SELECT < {s2} <= TEST")
    prep = []
    for _sym, dv in dated_series.items():
        if len(dv) < 300:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        prep.append((dates, closes))
    out = []
    for key, label, fn in ENTRIES:
        entries_by_sym = [(dates, closes, _entry_indices(dates, closes, fn))
                          for dates, closes in prep]
        grid = {}
        for trail in TRAILS:
            for hold in HOLDS:
                buckets = {"train": [], "select": [], "test": []}
                for dates, closes, entries in entries_by_sym:
                    n = len(closes)
                    pos = 0
                    for i in entries:
                        if i < pos or i >= n - 1 or closes[i] <= 0:
                            continue
                        j = _trail_exit(closes, i, trail=trail, max_hold=hold)
                        if j <= i or closes[j] <= 0:
                            continue
                        ret = (closes[j] / closes[i] - 1.0) - 2.0 * cost
                        d = dates[i]
                        w = "train" if d < s1 else ("select" if d < s2 else "test")
                        buckets[w].append(ret)
                        pos = j
                grid[(trail, hold)] = {w: _bucket_stats(r)
                                       for w, r in buckets.items()}
        # the honest selection: best by TRAIN avg only
        pick = max(grid, key=lambda k: grid[k]["train"]["avg"] or -999)
        st = grid[pick]
        holds_up = all(st[w]["avg"] is not None and st[w]["avg"] > 0
                       for w in ("select", "test"))
        out.append({"key": key, "label": label, "grid": grid, "pick": pick,
                    "verdict": "HOLDS on unseen data" if holds_up
                               else "TRAIN pick FAILS unseen data"})
        log(f"[exits] {key}: TRAIN picks trail {pick[0]*100:.0f}% / {pick[1]}d")
    return {"split_train_end": s1, "split_select_end": s2,
            "cost_per_side": cost, "results": out}


def format_sweep(res) -> str:
    w = 100
    lines = ["=" * w,
             f"  {config.BOT_NAME} · LAB EXITS   (exit sweep — TRAIN chooses, "
             f"untouched TEST judges)",
             f"  Grid: trails {'/'.join(f'{t*100:.0f}%' for t in TRAILS)} x holds "
             f"{'/'.join(str(h) for h in HOLDS)}d · cost "
             f"{res['cost_per_side']*100:.2f}%/side",
             "=" * w]
    for r in res["results"]:
        g, pick = r["grid"], r["pick"]
        corner = "trail\\hold"
        lines += ["",
                  f"  {r['key']} — {r['label']}",
                  "  TEST avg %/trade (the unseen surface):",
                  "  " + f"{corner:>12}" + "".join(f"{h:>10}d" for h in HOLDS)]
        for t in TRAILS:
            row = f"  {t*100:>10.0f}%  "
            for h in HOLDS:
                st = g[(t, h)]["test"]
                mark = " *" if (t, h) == pick else "  "
                row += f"{(('%+.2f' % st['avg']) if st['avg'] is not None else '—'):>8}{mark}"
            lines.append(row)
        st = g[pick]
        fa = lambda w: ("—" if st[w]["avg"] is None else f"{st[w]['avg']:+.2f}%/t")  # noqa: E731
        lines += [f"  TRAIN's pick: {pick[0]*100:.0f}% trail / {pick[1]}d  (*) -> "
                  f"TRAIN {fa('train')} · SELECT {fa('select')} · TEST {fa('test')} "
                  f"({st['test']['trades']}t)",
                  f"  VERDICT: {r['verdict']}"]
    lines += ["-" * w,
              "  Read the SURFACE, not one cell: if neighbouring cells are all similar,",
              "  the exact numbers barely matter (robust). A single hot cell = luck.",
              "  Picking by TEST directly would be cheating — TRAIN chooses, TEST judges.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB EXITS (exit-parameter sweep)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="deep-history long CSV (symbol,date,close)")
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    res = sweep(dated, cost=a.cost)
    print(format_sweep(res))


if __name__ == "__main__":
    main()
