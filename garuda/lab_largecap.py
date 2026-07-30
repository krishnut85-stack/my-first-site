"""LAB LARGECAP — momentum rotation hunted INSIDE the giants only.

The LEADERS book scans every large cap daily but its absolute gate
(+25% in ~3 months) is a sprint few elephants ever run — the live book
held exactly one top-100 name the day this was written. The honest fix
is not loosening a validated book: it is testing RELATIVE momentum
within the giants — always hold the fastest few of the top-`N` by
market cap, even when their absolute pace is modest.

Machinery: the proven CHAKRA exam (monthly rotation, 200-DMA filter,
concentration x lookback grid, TRAIN chooses / untouched TEST judges),
with the universe restricted to today's top-`N` companies by market cap.

    python3 -m garuda.lab_largecap --csv strength_history.csv \
        --mcap marketcap.csv --top-universe 100

Caveat: today's top-100 includes yesterday's climbers (survivorship
flatters even giants, just less than minnows). PAPER / research only.
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_edges import load_mcap
from .lab_chakra_exam import format_exam, run_exam
from .lab_tournament import judge_window_start, prepare


def restrict_to_top(dated_series, mcap, top_n):
    """Keep only the `top_n` largest symbols (by today's market cap) that
    also have price history."""
    ranked = sorted((s for s in dated_series if mcap.get(s)),
                    key=lambda s: -mcap[s])
    keep = set(ranked[:top_n])
    return {s: dv for s, dv in dated_series.items() if s in keep}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB LARGECAP")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--mcap", default="marketcap.csv")
    ap.add_argument("--top-universe", type=int, default=100,
                    help="how many of the biggest companies form the pond")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    if not Path(a.mcap).exists():
        sys.exit(f"{a.mcap} not found — the giants are ranked by market cap")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    mcap = load_mcap(a.mcap)
    dated = restrict_to_top(dated, mcap, a.top_universe)
    print(f"[largecap] universe: top-{a.top_universe} by mcap -> "
          f"{len(dated)} with price history")
    if len(dated) < 40:
        sys.exit("too few giants with history — check marketcap.csv")
    prep = prepare(dated)
    start = judge_window_start(dated)
    grid, pick = run_exam(prep, start, a.capital, a.cost)
    print(format_exam(grid, pick, start, a.capital))
    print("[largecap] read it like every exam: TRAIN's pick must HOLD on "
          "TEST in a smooth neighbourhood; compare the winner against the "
          "live CHAKRA book before dreaming of a 12th seat.")


if __name__ == "__main__":
    main()
