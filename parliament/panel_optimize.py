#!/usr/bin/env python3
"""PANEL OPTIMIZE — turn the backtest's edge measurements into ENFORCED weights.

The gap this closes (audit finding #1):
  panel_backtest.py MEASURES every judge's forward edge and prints a FIRE LIST,
  and panel.py's score_stock() ALREADY applies per-judge weights from
  judge_weights.json -- but nothing ever WROTE that file. So every scan fell
  back to flat 1.0 weights (np.mean), and bb_squeeze20 (edge -2.30%) voted
  exactly as hard as gap_freq20 (edge +2.11%). The fire list was advisory
  wallpaper. This script is the missing wire between measurement and decision.

It reads the most recent judge_stats row per judge (written by
panel_backtest.py) and writes judge_weights.json:

    weight = clip(1 + GAIN * edge, 0, MAX_W)         # edge = % fwd20 vs baseline
    weight = 0  (BENCHED)  if edge <= BENCH_EDGE and n_high >= MIN_SAMPLE

Judges with no graded stat -- too few high votes, or the whole 'insti' family
which is honestly excluded from the backtest -- keep weight 1.0. We never
penalise a judge we could not measure.

Safe by construction: paper-only system, purely additive (panel.py already
reads the file), idempotent. After writing, re-run panel_backtest.py to see the
WEIGHTED panel's signal performance before trusting it.

Usage (on droplet, from /home/globalbot):
  python3 panel_optimize.py          # write judge_weights.json from latest backtest
  python3 panel_optimize.py --dry    # print the table, write nothing
"""
import os
import sys
import json
import sqlite3

import panel  # JUDGES, BASE, DB_PATH

GAIN = 0.40          # weight sensitivity to edge (% fwd20 over baseline)
MAX_W = 2.50         # cap so no single judge can dominate the mean
BENCH_EDGE = -1.00   # at/below this measured edge -> benched (weight 0)
MIN_SAMPLE = 200     # need this many high votes before an edge is trusted enough to bench
OUT = os.path.join(panel.BASE, "judge_weights.json")


def latest_stats(con):
    """Return (ts, {judge: (family, n_high, edge)}) for the newest backtest run."""
    ts = con.execute("SELECT MAX(ts) FROM judge_stats").fetchone()[0]
    if not ts:
        raise SystemExit("[OPT] no judge_stats yet -- run: python3 panel_backtest.py")
    rows = con.execute(
        "SELECT judge, family, n_high, edge FROM judge_stats WHERE ts=?", (ts,)
    ).fetchall()
    return ts, {r[0]: (r[1], r[2], r[3]) for r in rows}


def weight_for(edge, n_high):
    """Map a measured edge -> (weight, reason)."""
    if edge is None:
        return 1.0, "ungraded->neutral"
    if edge <= BENCH_EDGE and (n_high or 0) >= MIN_SAMPLE:
        return 0.0, "BENCHED"
    w = max(0.0, min(MAX_W, 1.0 + GAIN * edge))
    return round(w, 3), "weighted"


def main(dry=False):
    con = sqlite3.connect(panel.DB_PATH)
    ts, stats = latest_stats(con)
    con.close()

    weights = {}
    table = []
    for fam, name, _ in panel.JUDGES:          # all 105 scoring judges (vetoes excluded)
        _, n_high, edge = stats.get(name, (fam, None, None))
        w, why = weight_for(edge, n_high)
        weights[name] = w
        table.append((name, fam, n_high, edge, w, why))

    table.sort(key=lambda r: (r[4], r[3] if r[3] is not None else 99))
    benched = [r for r in table if r[5] == "BENCHED"]
    mean_w = sum(weights.values()) / len(weights)
    print(f"[OPT] from judge_stats @ {ts} | {len(weights)} judges | "
          f"benched {len(benched)} | mean weight {mean_w:.2f}")
    print(f"{'JUDGE':<26}{'FAMILY':<12}{'N_HIGH':>7}{'EDGE':>8}{'WEIGHT':>8}  WHY")
    for name, fam, n_high, edge, w, why in table:
        es = f"{edge:+.2f}" if edge is not None else "--"
        ns = f"{n_high}" if n_high is not None else "--"
        print(f"{name:<26}{fam:<12}{ns:>7}{es:>8}{w:>8.2f}  {why}")

    if dry:
        print("[OPT] --dry: nothing written.")
        return

    json.dump(weights, open(OUT, "w"), indent=2, sort_keys=True)
    print(f"\n[OPT] wrote {OUT}. Next 'panel.py scan' will enforce these weights.\n"
          f"[OPT] VALIDATE before trusting: re-run 'python3 panel_backtest.py' and confirm\n"
          f"      the weighted panel's signal edge improves (or at least does not degrade).")


if __name__ == "__main__":
    main(dry="--dry" in sys.argv or "--dryrun" in sys.argv)
