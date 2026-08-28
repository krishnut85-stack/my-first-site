"""SCREEN LAB — a panel of analyst screens, each backtested the same honest way.

Trendlyne's catalog exposes fundamentals with 1-5 "Yr Ago" history columns, so
ONE export today carries each stock's five-year statement history. This module
reconstructs what each screen WOULD have selected at every past fiscal
year-end (formation 90 days later, so the annual report was public) and
measures the NEXT 12 months against every stock the screen could have judged
on the same dates. Selection strictly precedes measurement.

The panel (fixed a priori — no peeking, no tuning after results):

    QUALITY40   NP>0 both yrs · NP growth>40% · Rev growth>10%
                (the bar the first history test calibrated)
    ACCEL       profit growth ACCELERATING: this year's growth beats last
                year's, both >20% — O'Neil's 'A' (earnings acceleration)
    QMOM        QUALITY40 and in the top 30% of 189-bar price momentum at
                formation — the literature's quality+momentum marriage
    QROCE15     QUALITY40 + ROCE>15 — the export carries ROCE for one year
                only, so this runs in that cohort alone (for interest)
    TURNAROUND  loss last year, profit this year, revenue growing — the
                classic special situation (low win rate, big winners?)
    STEADY15    NP growth>15% in EACH of the last 3 years — boring
                consistency (fewer names, steadier?)

Current-only fields (D/E, Piotroski, DVM scores, holdings) are deliberately
EXCLUDED from the rules: applying today's value to past years is lookahead.

    python3 -m garuda.lab_screens --wide scripts/screen_wide.csv \
        --csv strength_history.csv
    python3 -m garuda.lab_screens --wide scripts/screen_wide.csv --dump-headers

Survivor universe + restated financials: the SPREAD (screen vs its own
judgeable peers on identical dates) is the honest number, absolute returns
are not. PAPER / research only.
"""

import argparse
import csv as _csv
import re
import sys
from bisect import bisect_left
from datetime import date, timedelta
from pathlib import Path

from .cross import _load_long

MOM_BARS = 189
MOM_TOP_PCT = 70
LAG = "-07-01"                 # formation: July 1 after a March fiscal year-end
HOLD_DAYS = 365
MIN_COHORT = 10
MAX_K = 5                      # Trendlyne history depth: 1..5 Yr Ago


# ------------------------- wide-export parsing -------------------------

def _squish(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def _field_of(header):
    """Map a Trendlyne column header to (field, k) or None. k=0 is the latest
    fiscal year, k=1 is '1Yr Ago', etc. Tolerant to 'Ann'/'Annual' and
    spacing/percent variants."""
    h = _squish(header)
    if any(x in h for x in ("growth", "ttm", "qtr", "avg", "prev")):
        return None
    if "operatingprofitmargin" in h or ("opm" in h and "ann" in h):
        f = "opm"
    elif "netprofit" in h and "ann" in h and "margin" not in h:
        f = "np"
    elif "roce" in h:
        f = "roce"
    elif "rev" in h and "ann" in h and "margin" not in h:
        f = "rev"
    else:
        return None
    m = re.search(r"(\d)yr?ago", h)   # Trendlyne writes both "1Yr Ago" and "1Y Ago"
    return (f, int(m.group(1))) if m else (f, 0)


def _num(v):
    try:
        return float(str(v).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def load_wide(path, dump=False):
    """-> {symbol: {(field, k): value}} plus the header map (for --dump)."""
    out, fmap = {}, {}
    with open(path, newline="", encoding="utf-8-sig") as f:
        rd = _csv.DictReader(f)
        for h in rd.fieldnames or []:
            fk = _field_of(h)
            if fk:
                fmap[h] = fk
        sym_cols = [h for h in (rd.fieldnames or [])
                    if _squish(h) in ("nsecode", "symbol")]
        for r in rd:
            sym = ""
            for c in sym_cols:
                sym = (r.get(c) or "").strip()
                if sym:
                    break
            if not sym or sym.isdigit():
                continue
            vals = {}
            for h, fk in fmap.items():
                v = _num(r.get(h))
                if v is not None:
                    vals[fk] = v
            if vals:
                out[sym] = vals
    if dump:
        print("[screens] matched columns:")
        for h, fk in sorted(fmap.items(), key=lambda x: x[1]):
            print(f"    {fk[0]:>5}[{fk[1]}]  <-  {h}")
    return out, fmap


# ------------------------------ the panel ------------------------------

def _g(new, old):
    if new is None or old is None or old <= 0:
        return None
    return new / old - 1.0


def s_quality40(v):
    # ROCE deliberately absent: the export carries ROCE for one year only, and
    # a rule that silently weakens in the years lacking data is not one rule
    g_np, g_rev = _g(v("np", 0), v("np", 1)), _g(v("rev", 0), v("rev", 1))
    if None in (g_np, g_rev) or v("np", 0) is None:
        return None
    return v("np", 0) > 0 and g_np > 0.40 and g_rev > 0.10


def s_accel(v):
    g0, g1 = _g(v("np", 0), v("np", 1)), _g(v("np", 1), v("np", 2))
    if g0 is None or g1 is None:
        return None
    return g0 > 0.20 and g1 > 0.20 and g0 > g1


def s_qroce(v):
    """QUALITY40 plus ROCE > 15 — runs only in cohorts where the export
    carries ROCE for that year (currently one), printed for interest."""
    base = s_quality40(v)
    roce = v("roce", 0)
    if base is None or roce is None:
        return None
    return base and roce > 15.0


def s_turnaround(v):
    np0, np1 = v("np", 0), v("np", 1)
    g_rev = _g(v("rev", 0), v("rev", 1))
    if None in (np0, np1, g_rev):
        return None
    return np1 < 0 < np0 and g_rev > 0


def s_steady15(v):
    gs = [_g(v("np", j), v("np", j + 1)) for j in range(3)]
    if any(g is None for g in gs):
        return None
    return all(g > 0.15 for g in gs)


SCREENS = [
    ("QUALITY40", s_quality40, False),
    ("ACCEL", s_accel, False),
    ("QMOM", s_quality40, True),          # quality AND momentum gate
    ("QROCE15", s_qroce, False),
    ("TURNAROUND", s_turnaround, False),
    ("STEADY15", s_steady15, False),
]


# --------------------------- price machinery ---------------------------

def _prep_prices(dated):
    return {s: ([d for d, _ in dv], [p for _, p in dv])
            for s, dv in dated.items()}


def next_return(px, formation, hold_days=HOLD_DAYS):
    dates, closes = px
    i = bisect_left(dates, formation)
    if i >= len(dates) or dates[i] > _shift(formation, 30) or closes[i] <= 0:
        return None
    j = bisect_left(dates, _shift(formation, hold_days))
    if j >= len(dates):
        j = len(dates) - 1
        if _days(dates[i], dates[j]) < 200:
            return None
    return closes[j] / closes[i] - 1.0 if closes[j] > 0 else None


def momentum_pct(prices, formation):
    """{symbol: percentile 0-100} of MOM_BARS-bar return as of formation."""
    moms = {}
    for sym, (dates, closes) in prices.items():
        i = bisect_left(dates, formation) - 1
        if i >= MOM_BARS and closes[i - MOM_BARS] > 0 and closes[i] > 0 \
                and _days(dates[i], formation) <= 10:
            moms[sym] = closes[i] / closes[i - MOM_BARS] - 1.0
    if not moms:
        return {}
    ordered = sorted(moms.values())
    n = len(ordered)
    return {s: round(bisect_left(ordered, m) / n * 100) for s, m in moms.items()}


def _shift(iso, days):
    y, m, d = map(int, iso[:10].split("-"))
    return (date(y, m, d) + timedelta(days=days)).isoformat()


def _days(a, b):
    ya, ma, da = map(int, a[:10].split("-"))
    yb, mb, db = map(int, b[:10].split("-"))
    return (date(yb, mb, db) - date(ya, ma, da)).days


# ------------------------------ the exam ------------------------------

def run_exam(wide, prices, latest_fy, log=print):
    """-> {screen: [{year, n_sel, n_uni, sel, uni, spread, sel_win}]}"""
    results = {name: [] for name, _f, _m in SCREENS}
    for k in range(MAX_K):
        fy = latest_fy - k
        formation = f"{fy}{LAG}"
        rets = {s: next_return(px, formation) for s, px in prices.items()}
        rets = {s: r for s, r in rets.items() if r is not None}
        mom = momentum_pct(prices, formation)
        log(f"[screens] FY{fy} · formation {formation} · "
            f"{len(rets)} measurable names")
        for name, fn, needs_mom in SCREENS:
            sel, uni = [], []
            for sym, vals in wide.items():
                if sym not in rets:
                    continue
                v = lambda f, j: vals.get((f, j + k))  # noqa: E731
                verdict = fn(v)
                if verdict is None:
                    continue
                if needs_mom:
                    if sym not in mom:
                        continue
                    verdict = verdict and mom[sym] >= MOM_TOP_PCT
                uni.append(rets[sym])
                if verdict:
                    sel.append(rets[sym])
            if uni:
                avg = lambda xs: sum(xs) / len(xs) if xs else None  # noqa: E731
                results[name].append(
                    {"year": str(fy), "n_sel": len(sel), "n_uni": len(uni),
                     "sel": avg(sel), "uni": avg(uni),
                     "spread": (avg(sel) - avg(uni)) if sel else None,
                     "sel_win": (sum(1 for r in sel if r > 0) / len(sel) * 100)
                     if sel else None})
    return results


def format_exam(results):
    w = 100
    fm = lambda x: "—" if x is None else f"{x * 100:+.1f}%"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · SCREEN LAB   (six analyst screens, one honest "
             "harness — spread vs same-date peers)",
             "  Formation July 1 after each FY · next-12m returns · survivor "
             "universe: SPREADS honest, absolutes not",
             "=" * w]
    summary = []
    for name, fn, _m in SCREENS:
        rows = results.get(name) or []
        lines.append(f"  {name}")
        lines.append(f"    {'FY':<6}{'selected':>9}{'of':>7}{'sel 12m':>10}"
                     f"{'universe':>10}{'spread':>9}{'win%':>7}")
        for r in sorted(rows, key=lambda r: r["year"]):
            thin = r["n_sel"] < MIN_COHORT
            lines.append(
                f"    {r['year']:<6}{r['n_sel']:>9}{r['n_uni']:>7}"
                f"{fm(r['sel']):>10}{fm(r['uni']):>10}{fm(r['spread']):>9}"
                + (f"{r['sel_win']:>6.0f}%" if r["sel_win"] is not None
                   else f"{'—':>7}")
                + ("   TOO THIN — ignored" if thin else ""))
        use = [r for r in rows if r["spread"] is not None
               and r["n_sel"] >= MIN_COHORT]
        if use:
            avg_sp = sum(r["spread"] for r in use) / len(use)
            pos = sum(1 for r in use if r["spread"] > 0)
            wins = [r["sel_win"] for r in use if r["sel_win"] is not None]
            summary.append((name, len(use), pos, avg_sp,
                            sum(wins) / len(wins) if wins else None,
                            sum(r["n_sel"] for r in use) / len(use)))
            lines.append(f"    -> {len(use)} usable yrs · beat universe "
                         f"{pos}/{len(use)} · avg spread {avg_sp * 100:+.1f}%/yr")
        else:
            summary.append((name, 0, 0, None, None, None))
            lines.append("    -> no usable cohorts (all thin) — nothing to "
                         "conclude")
        lines.append("-" * w)
    lines.append("  VERDICT BOARD (usable years only, ranked by avg spread):")
    lines.append(f"    {'screen':<12}{'usable':>7}{'beat':>7}{'avg spread':>12}"
                 f"{'avg win%':>10}{'avg n/yr':>10}")
    ranked = sorted(summary, key=lambda s: -999 if s[3] is None else s[3],
                    reverse=True)
    for name, nuse, pos, sp, win, n in ranked:
        lines.append(
            f"    {name:<12}{nuse:>7}{f'{pos}/{nuse}':>7}"
            + (f"{sp * 100:>+11.1f}%" if sp is not None else f"{'—':>12}")
            + (f"{win:>9.0f}%" if win is not None else f"{'—':>10}")
            + (f"{n:>10.0f}" if n is not None else f"{'—':>10}"))
    lines += ["  A screen earns respect by beating its peers MOST years with "
              "n >= " f"{MIN_COHORT}; one shiny year is luck.",
              "  Next step for any winner: forward paper trial — the only "
              "bias-free test.", "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda SCREEN LAB")
    ap.add_argument("--wide", required=True,
                    help="Trendlyne export with 1-5 'Yr Ago' history columns")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--latest-fy", type=int, default=2026,
                    help="fiscal year of the newest annual columns")
    ap.add_argument("--dump-headers", action="store_true")
    a = ap.parse_args(argv)
    wide, fmap = load_wide(a.wide, dump=a.dump_headers)
    print(f"[screens] {len(wide)} symbols · {len(fmap)} history columns matched")
    if a.dump_headers:
        return
    need = {("np", 0), ("np", 1), ("rev", 0), ("rev", 1)}
    have = set().union(*[set(v) for v in wide.values()]) if wide else set()
    if not need <= have:
        sys.exit("[screens] export is missing Net Profit / Revenue history "
                 "columns — run --dump-headers to see what matched")
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    prices = _prep_prices(dated)
    print(f"[screens] prices for {len(prices)} symbols")
    results = run_exam(wide, prices, a.latest_fy)
    print(format_exam(results))


if __name__ == "__main__":
    main()
