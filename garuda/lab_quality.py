"""LAB QUALITY — cross-examine a Trendlyne quality-growth screen against Garuda.

The user's screener instinct (high profit CAGR + ROCE + sane balance sheet) is
the quality-momentum overlay the literature endorses. What it CANNOT be is a
backtest: the export is a snapshot of today, so this module makes no return
claims. It answers three honest questions instead:

    1. TRADABLE  — which screen rows can Garuda even trade (real NSE symbol,
       not a BSE-only listing), and which are base-effect mirages (a company
       going from ₹1L profit to ₹50L prints +4,900% growth and means nothing)?
    2. OVERLAP   — how many tradable names are already in the smallcap book's
       universe, and how many does the fleet already hold?
    3. MOMENTUM  — where does each name sit in the 189-bar momentum ranking
       CHAKRA uses? A high-quality name that is ALSO high-momentum is the
       overlay working; quality names with dead momentum are the disagreement
       worth watching.

    python3 -m garuda.lab_quality --screen scripts/quality_screen.csv \
        --csv strength_history.csv --list smallcap_list.csv --data-dir garuda/data

PAPER / research only. No Garuda book reads this module.
"""

import argparse
import csv as _csv
import glob
import json
import sys
from pathlib import Path

from .cross import _load_long

MOM_BARS = 189                   # CHAKRA's validated lookback
BASE_EFFECT_REV3Y = 500.0        # >500% 3y revenue growth = base-effect flag
BASE_EFFECT_NP3Y = 1000.0        # >1000% 3y profit growth = base-effect flag


def _num(v):
    try:
        return float(str(v).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def load_screen(path):
    """Trendlyne export -> [{name, symbol, mcap, roce, rev3y, np3y, ...}].
    symbol is None for rows Garuda cannot trade (blank or Trendlyne's numeric
    internal id, i.e. BSE-only listings)."""
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        for r in _csv.DictReader(f):
            sym = ""
            for k in ("NSE code", "NSE Code", "nse code"):
                sym = (r.get(k) or "").strip()
                if sym:
                    break
            if not sym or sym.isdigit():
                sym = None
            rows.append({
                "name": (r.get("Stock") or "").strip(),
                "symbol": sym,
                "mcap": _num(r.get("Market Cap")),
                "roce": _num(r.get("ROCE Ann  %") or r.get("ROCE Ann %")),
                "rev3y": _num(r.get("Rev  Ann  3Y Growth %")
                              or r.get("Rev Ann 3Y Growth %")),
                "np3y": _num(r.get("Net Profit 3Y Growth %")),
            })
    return rows


def base_effect(row):
    return ((row["rev3y"] is not None and row["rev3y"] > BASE_EFFECT_REV3Y)
            or (row["np3y"] is not None and row["np3y"] > BASE_EFFECT_NP3Y))


def momentum_ranks(dated, universe=None):
    """{symbol: momentum percentile 0-100} over `universe` (default: all)."""
    moms = {}
    for sym, dv in dated.items():
        if universe and sym not in universe:
            continue
        closes = [v for _, v in dv]
        if len(closes) > MOM_BARS and closes[-1 - MOM_BARS] > 0:
            moms[sym] = closes[-1] / closes[-1 - MOM_BARS] - 1.0
    if not moms:
        return {}
    ordered = sorted(moms.values())
    n = len(ordered)

    def pct(m):
        lo = sum(1 for v in ordered if v < m)
        return round(lo / n * 100.0)
    return {s: pct(m) for s, m in moms.items()}


def held_by_books(data_dir):
    """{symbol: [book, ...]} from the live paper portfolios on disk."""
    held = {}
    for p in sorted(glob.glob(str(Path(data_dir) / "garuda_*_portfolio.json"))):
        book = Path(p).stem.replace("garuda_", "").replace("_portfolio", "")
        try:
            for sym in (json.loads(Path(p).read_text()).get("holdings") or {}):
                held.setdefault(sym, []).append(book)
        except (OSError, ValueError):
            continue
    return held


def examine(rows, smallcap=None, ranks=None, held=None):
    out = {"total": len(rows), "clean": [], "flagged": [], "untradable": []}
    for r in rows:
        if r["symbol"] is None:
            out["untradable"].append(r)
            continue
        r = dict(r)
        r["flag"] = base_effect(r)
        r["in250"] = bool(smallcap and r["symbol"] in smallcap)
        r["mom_pct"] = (ranks or {}).get(r["symbol"])
        r["held"] = (held or {}).get(r["symbol"], [])
        (out["flagged"] if r["flag"] else out["clean"]).append(r)
    out["clean"].sort(key=lambda r: -(r["mcap"] or 0))
    return out


def format_report(ex, smallcap=None, ranks=None):
    w = 100
    clean, flagged, untr = ex["clean"], ex["flagged"], ex["untradable"]
    lines = ["=" * w,
             "  Garuda · QUALITY SCREEN vs THE FLEET   (snapshot diagnostic — "
             "NOT a backtest, no return claims)",
             f"  {ex['total']} screen rows -> {len(clean)} clean · "
             f"{len(flagged)} base-effect flagged (rev3y>{BASE_EFFECT_REV3Y:.0f}% "
             f"or np3y>{BASE_EFFECT_NP3Y:.0f}%) · {len(untr)} not NSE-tradable",
             "=" * w]
    if clean:
        lines.append(f"  {'symbol':<14}{'mcap cr':>9}{'ROCE':>7}{'NP 3Y%':>9}"
                     f"{'in 250':>8}{'mom pct':>9}  held by")
        lines.append("-" * w)
        for r in clean:
            mp = f"{r['mom_pct']:>7}%" if r["mom_pct"] is not None else "      —"
            lines.append(
                f"  {r['symbol']:<14}{(r['mcap'] or 0):>9,.0f}"
                f"{(r['roce'] or 0):>7.1f}{(r['np3y'] or 0):>9.0f}"
                f"{'yes' if r['in250'] else '—':>8}{mp:>9}"
                f"  {','.join(r['held']) or '—'}")
    in250 = [r for r in clean if r["in250"]]
    held = [r for r in clean if r["held"]]
    hot = [r for r in clean if (r["mom_pct"] or 0) >= 70]
    lines += ["-" * w,
              f"  OVERLAP: {len(in250)}/{len(clean)} clean names sit in the "
              f"smallcap-250 universe · {len(held)} already held by the fleet",
              f"  MOMENTUM: {len(hot)}/{len(clean)} clean names are in the top "
              f"30% of {MOM_BARS}-bar momentum (CHAKRA's radar)"]
    if flagged:
        lines.append("  FLAGGED (growth % is a base-effect mirage, judge by "
                     "hand): " + ", ".join((r["symbol"] or r["name"])
                                           for r in flagged[:15])
                     + (" ..." if len(flagged) > 15 else ""))
    if untr:
        lines.append("  NOT NSE-TRADABLE (BSE-only / no symbol): "
                     + ", ".join(r["name"] for r in untr[:10])
                     + (" ..." if len(untr) > 10 else ""))
    lines += ["  A quality name that is ALSO high-momentum is the overlay "
              "agreeing with the fleet; quality with",
              "  dead momentum is a watchlist, not a signal. Forward paper "
              "trading is the only honest test here.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda QUALITY screen diagnostic")
    ap.add_argument("--screen", required=True,
                    help="Trendlyne export CSV (quality-growth screen)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="price history for momentum ranks (optional)")
    ap.add_argument("--list", default="",
                    help="smallcap constituent CSV for universe overlap")
    ap.add_argument("--data-dir", default="garuda/data",
                    help="live portfolio dir for held-by overlap")
    a = ap.parse_args(argv)
    rows = load_screen(a.screen)
    smallcap = set()
    if a.list and Path(a.list).exists():
        with open(a.list, newline="", encoding="utf-8") as f:
            smallcap = {(r.get("Symbol") or r.get("symbol") or "").strip()
                        for r in _csv.DictReader(f)}
    ranks = {}
    if Path(a.csv).exists():
        dated = {s: sorted(dv.items()) for s, dv in _load_long(Path(a.csv)).items()}
        screen_syms = {r["symbol"] for r in rows if r["symbol"]}
        universe = (smallcap | screen_syms) if smallcap else None
        ranks = momentum_ranks(dated, universe=universe)
    else:
        print(f"[quality] {a.csv} not found — momentum column will be empty")
    held = held_by_books(a.data_dir) if Path(a.data_dir).exists() else {}
    ex = examine(rows, smallcap=smallcap, ranks=ranks, held=held)
    print(format_report(ex, smallcap, ranks))


if __name__ == "__main__":
    main()
