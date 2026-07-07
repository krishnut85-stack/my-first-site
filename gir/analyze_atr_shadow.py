#!/usr/bin/env python3
"""Analyze V107 ATR shadow log. Usage: python3 analyze_atr_shadow.py [--days N] [--symbol SYM]"""
import json, sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timedelta

LOG = Path("/home/globalbot/atr_shadow_log.jsonl")


def load_records(days=None, symbol_filter=None):
    if not LOG.exists():
        print(f"❌ No shadow log at {LOG}"); sys.exit(1)
    cutoff = datetime.now() - timedelta(days=days) if days else None
    records = []
    with open(LOG) as f:
        for line in f:
            try:
                r = json.loads(line)
                if symbol_filter and r["sym"] != symbol_filter:
                    continue
                if cutoff and datetime.fromisoformat(r["ts"]) < cutoff:
                    continue
                records.append(r)
            except Exception:
                continue
    return records


def analyze(records):
    if not records:
        print("No records to analyze"); return
    by_sym = defaultdict(list)
    for r in records:
        by_sym[r["sym"]].append(r)
    print("=" * 78)
    print(f"ATR SHADOW ANALYSIS — {len(records)} obs, {len(by_sym)} symbols")
    print(f"Period: {records[0]['ts']} -> {records[-1]['ts']}")
    print("=" * 78)
    tot_af = tot_atrf = tot_saves = tot_false = 0
    tot_delta_rs = 0.0
    print(f"\n{'Symbol':<14} {'Obs':>5} {'ActFire':>8} {'ATRFire':>8} "
          f"{'Saves':>6} {'FalseCmf':>9} {'AvgD%':>7} {'TotalDRs':>10}")
    print("-" * 78)
    for sym, recs in sorted(by_sym.items()):
        n = len(recs)
        af = sum(1 for r in recs if r["active_would_fire"])
        atf = sum(1 for r in recs if r["atr_would_fire"])
        saves = sum(1 for r in recs if r["active_would_fire"] and not r["atr_would_fire"])
        false_cmf = sum(1 for r in recs if r["atr_would_fire"] and not r["active_would_fire"])
        avg_delta = sum(r["atr_pct"] - r["active_pct"] for r in recs) / n
        td = sum(r["delta_total"] for r in recs)
        tot_af += af; tot_atrf += atf; tot_saves += saves
        tot_false += false_cmf; tot_delta_rs += td
        print(f"{sym:<14} {n:>5} {af:>8} {atf:>8} {saves:>6} {false_cmf:>9} "
              f"{avg_delta:>+6.2f}% {td:>+10.2f}")
    print("-" * 78)
    print(f"{'TOTAL':<14} {len(records):>5} {tot_af:>8} {tot_atrf:>8} "
          f"{tot_saves:>6} {tot_false:>9}")
    print()
    print("=" * 78)
    print("VERDICT")
    print("=" * 78)
    if tot_af > 0:
        sr = tot_saves / tot_af * 100
        print(f"  Whipsaw save rate:   {sr:.1f}%  "
              f"(ATR would prevent {tot_saves}/{tot_af} active SL hits)")
    if tot_atrf > 0:
        fr = tot_false / tot_atrf * 100
        print(f"  False comfort rate:  {fr:.1f}%  "
              f"(ATR fires in {tot_false}/{tot_atrf} cases active held)")
    avg_all = sum(r['atr_pct'] - r['active_pct'] for r in records) / len(records)
    print(f"  Avg SL distance D:   {avg_all:+.2f}% (positive = ATR wider)")
    print()
    print("INTERPRETATION:")
    if tot_saves > tot_false * 2:
        print("  + ATR strongly reduces whipsaw. STRONG case to deploy ATR live.")
    elif tot_saves > tot_false:
        print("  ~ ATR moderately better. Consider deploying with conservative multiplier.")
    else:
        print("  - ATR no clear edge this period. Keep current OR try different multiplier.")


if __name__ == "__main__":
    days = None; symbol = None
    args = sys.argv[1:]
    while args:
        if args[0] == "--days" and len(args) > 1:
            days = int(args[1]); args = args[2:]
        elif args[0] == "--symbol" and len(args) > 1:
            symbol = args[1]; args = args[2:]
        else:
            args = args[1:]
    analyze(load_records(days=days, symbol_filter=symbol))
