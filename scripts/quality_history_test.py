#!/usr/bin/env python3
"""QUALITY HISTORY TEST — did the quality-growth screen work in PREVIOUS years?

The Trendlyne export is a snapshot of today, so it cannot be backtested. But
Yahoo keeps ~4 years of each company's ANNUAL statements, which lets us
reconstruct what a quality-growth screen WOULD have selected at each past
fiscal year-end, then measure the NEXT 12 months — selection strictly before
measurement, no peeking at returns.

Rule tested (the user's screen, minus ROCE which Yahoo can't give cleanly):
    net profit > 0 in both years · profit growth > 20% · revenue growth > 10%
    · debt/equity < 1 when the balance sheet is available.
Formation happens LAG days (default 90) after fiscal year-end, so the annual
report was genuinely public before "buying".

    python3 scripts/quality_history_test.py --universe smallcap_list.csv micro.csv
    python3 scripts/quality_history_test.py --selftest    # machinery only

HONEST LIMITS, read before believing anything:
  * survivor universe (today's constituents) — an UPPER BOUND on both legs;
  * Yahoo shows RESTATED financials, not as-originally-reported — mild bias;
  * ~4 annual periods -> only ~3 formation years. Indicative, NOT gauntlet-grade.
Output: bt_out/report_quality_history.txt. PAPER / research only.
"""

import argparse
import csv
import json
import os
import sys
from datetime import date, timedelta
from pathlib import Path

LAG_DAYS = 90          # fiscal year end -> formation (annual report is public)
HOLD_DAYS = 365        # measure the next 12 months
MIN_NP_GROWTH = 0.20
MIN_REV_GROWTH = 0.10
MAX_DE = 1.0


# ---------------------------- pure logic (tested) ----------------------------

def quality_pass(prev_ni, ni, prev_rev, rev, de,
                 min_np=MIN_NP_GROWTH, min_rev=MIN_REV_GROWTH, max_de=MAX_DE):
    """The screen rule, applied to one company's consecutive annual reports."""
    if not all(isinstance(v, (int, float)) for v in (prev_ni, ni, prev_rev, rev)):
        return False
    if prev_ni <= 0 or ni <= 0 or prev_rev <= 0:
        return False
    if ni / prev_ni - 1.0 < min_np or rev / prev_rev - 1.0 < min_rev:
        return False
    if de is not None and de >= max_de:
        return False
    return True


def next_return(prices, entry_date, hold_days=HOLD_DAYS):
    """prices: sorted [(iso_date, close)]. Entry = first close within 30 days
    on/after entry_date; exit = first close on/after entry+hold (or the last
    close if >= 200 days elapsed). None if unmeasurable."""
    entry = None
    limit = _shift(entry_date, 30)
    target = _shift(entry_date, hold_days)
    for d, px in prices:
        if entry is None:
            if d >= entry_date:
                if d > limit or px <= 0:
                    return None
                entry = (d, px)
            continue
        if d >= target:
            return px / entry[1] - 1.0 if px > 0 else None
    if entry and prices:
        d, px = prices[-1]
        if px > 0 and _days_between(entry[0], d) >= 200:
            return px / entry[1] - 1.0
    return None


def form_cohorts(fundamentals, prices, lag_days=LAG_DAYS, hold_days=HOLD_DAYS,
                 min_np=MIN_NP_GROWTH, min_rev=MIN_REV_GROWTH, max_de=MAX_DE):
    """fundamentals: {sym: [(fy_end_iso, net_income, revenue, de), ...] oldest
    first}. Returns {cohort_year: {"selected": [(sym, ret)],
    "rejected": [(sym, ret)]}} — rejected = reported that year, failed the rule.
    Benchmark = selected + rejected (every reporter, same formation timing)."""
    cohorts = {}
    for sym, years in fundamentals.items():
        px = prices.get(sym)
        if not px:
            continue
        for (d0, ni0, rev0, _de0), (d1, ni1, rev1, de1) in zip(years, years[1:]):
            if not d0 or not d1:
                continue
            formation = _shift(d1, lag_days)
            ret = next_return(px, formation, hold_days)
            if ret is None:
                continue
            ok = quality_pass(ni0, ni1, rev0, rev1, de1,
                              min_np=min_np, min_rev=min_rev, max_de=max_de)
            c = cohorts.setdefault(d1[:4], {"selected": [], "rejected": []})
            c["selected" if ok else "rejected"].append((sym, ret))
    return cohorts


def summarize(cohorts):
    rows = []
    for yr in sorted(cohorts):
        sel = [r for _, r in cohorts[yr]["selected"]]
        rej = [r for _, r in cohorts[yr]["rejected"]]
        uni = sel + rej
        if not uni:
            continue
        avg = lambda xs: sum(xs) / len(xs) if xs else None  # noqa: E731
        rows.append({"year": yr, "n_sel": len(sel), "n_uni": len(uni),
                     "sel": avg(sel), "uni": avg(uni),
                     "spread": (avg(sel) - avg(uni))
                     if sel and uni else None,
                     "sel_win": (sum(1 for r in sel if r > 0) / len(sel) * 100)
                     if sel else None})
    return rows


def format_report(rows):
    w = 96
    lines = ["=" * w,
             "  QUALITY HISTORY TEST — the screen rule applied in PREVIOUS "
             "years, next-12-month returns",
             "  Rule: NP>0 both yrs · NP growth>20% · Rev growth>10% · D/E<1 · "
             "formed 90d after FY end",
             "  *** SURVIVOR UNIVERSE + RESTATED FINANCIALS: UPPER BOUND, "
             "INDICATIVE ONLY ***",
             "=" * w,
             f"  {'FY':<6}{'selected':>9}{'of':>6}{'sel next-12m':>14}"
             f"{'universe':>10}{'spread':>9}{'sel win%':>10}",
             "-" * w]
    fm = lambda v: "—" if v is None else f"{v * 100:+.1f}%"  # noqa: E731
    for r in rows:
        lines.append(f"  {r['year']:<6}{r['n_sel']:>9}{r['n_uni']:>6}"
                     f"{fm(r['sel']):>14}{fm(r['uni']):>10}{fm(r['spread']):>9}"
                     + (f"{r['sel_win']:>9.0f}%" if r['sel_win'] is not None
                        else f"{'—':>10}"))
    spreads = [r["spread"] for r in rows if r["spread"] is not None]
    lines.append("-" * w)
    if spreads:
        pos = sum(1 for s in spreads if s > 0)
        lines.append(f"  Screen beat its own universe in {pos}/{len(spreads)} "
                     f"years · average spread {sum(spreads) / len(spreads) * 100:+.1f}%"
                     " per year")
        lines.append("  A rule that helps must win MOST years with a positive "
                     "average spread — one good year is luck.")
    else:
        lines.append("  Not enough measurable cohorts — nothing to conclude.")
    lines += ["  The spread is quality-vs-peers on identical dates, so "
              "survivorship hits BOTH legs; the spread",
              "  is the honest part, the absolute returns are not.",
              "=" * w]
    return "\n".join(lines)


def _shift(iso, days):
    y, m, d = map(int, iso[:10].split("-"))
    return (date(y, m, d) + timedelta(days=days)).isoformat()


def _days_between(a, b):
    ya, ma, da = map(int, a[:10].split("-"))
    yb, mb, db = map(int, b[:10].split("-"))
    return (date(yb, mb, db) - date(ya, ma, da)).days


# ------------------------- fetch layer (droplet only) -------------------------

def load_universe(paths):
    syms = []
    for p in paths:
        with open(p, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                s = (r.get("Symbol") or r.get("symbol") or "").strip()
                if s and s not in syms:
                    syms.append(s)
    return syms


def fetch_fundamentals(symbols, cache="bt_out/fundamentals_cache.json"):
    import yfinance as yf
    cp = Path(cache)
    if cp.exists():
        print(f"[fund] using cache {cache} (delete it to refetch)")
        return json.loads(cp.read_text())
    out = {}
    for k, sym in enumerate(symbols, 1):
        try:
            t = yf.Ticker(sym + ".NS")
            inc, bal = t.income_stmt, t.balance_sheet
            if inc is None or inc.empty:
                continue
            years = []
            for col in sorted(inc.columns):
                ni = _cell(inc, "Net Income", col)
                rev = _cell(inc, "Total Revenue", col)
                de = None
                if bal is not None and not bal.empty and col in bal.columns:
                    debt = _cell(bal, "Total Debt", col)
                    eq = _cell(bal, "Stockholders Equity", col)
                    if debt is not None and eq and eq > 0:
                        de = debt / eq
                if ni is not None and rev is not None:
                    years.append((str(col)[:10], ni, rev, de))
            if len(years) >= 2:
                out[sym] = years
        except Exception:  # noqa: BLE001 — one dead ticker must not kill the run
            continue
        if k % 25 == 0:
            print(f"[fund] {k}/{len(symbols)} · {len(out)} with >=2 annuals")
    cp.parent.mkdir(exist_ok=True)
    cp.write_text(json.dumps(out))
    return out


def _cell(df, row, col):
    try:
        v = df.at[row, col]
        return None if v != v else float(v)   # NaN check without numpy import
    except (KeyError, TypeError, ValueError):
        return None


def fetch_prices(symbols, start="2019-01-01"):
    import yfinance as yf
    out, chunk = {}, 40
    for i in range(0, len(symbols), chunk):
        batch = [s + ".NS" for s in symbols[i:i + chunk]]
        raw = yf.download(batch, start=start, auto_adjust=True,
                          group_by="ticker", progress=False, threads=True)
        for s in symbols[i:i + chunk]:
            try:
                ser = (raw[s + ".NS"]["Close"] if len(batch) > 1
                       else raw["Close"]).dropna()
            except KeyError:
                continue
            if len(ser) > 250:
                out[s] = [(str(d)[:10], float(v)) for d, v in ser.items()]
        print(f"[px] {min(i + chunk, len(symbols))}/{len(symbols)}")
    return out


# ----------------------------- selftest / main -----------------------------

def selftest():
    """Synthetic: quality names drift up after formation, junk drifts down.
    The machinery must find a positive spread — numbers are meaningless."""
    fundamentals, prices = {}, {}
    for k in range(20):
        good = k % 2 == 0
        fy = [("2022-03-31", 100.0, 1000.0, 0.3),
              ("2023-03-31", (130.0 if good else 90.0),
               (1200.0 if good else 950.0), 0.3)]
        fundamentals[f"S{k}"] = fy
        drift = 0.0008 if good else -0.0004
        px, days = 100.0, []
        d = date(2022, 1, 1)
        for _ in range(900):
            px *= 1 + drift
            days.append((d.isoformat(), round(px, 3)))
            d += timedelta(days=1)
        prices[f"S{k}"] = days
    rows = summarize(form_cohorts(fundamentals, prices))
    print(format_report(rows))
    assert rows and rows[0]["spread"] > 0, "selftest: expected positive spread"
    print("\nSELFTEST OK (synthetic — machinery only)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--universe", nargs="+", default=["smallcap_list.csv"])
    ap.add_argument("--start", default="2019-01-01")
    ap.add_argument("--min-np-growth", type=float, default=MIN_NP_GROWTH)
    ap.add_argument("--min-rev-growth", type=float, default=MIN_REV_GROWTH)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        selftest()
        return
    syms = load_universe(a.universe)
    print(f"Universe: {len(syms)} symbols")
    fund = fetch_fundamentals(syms)
    print(f"Fundamentals: {len(fund)} symbols with >=2 annual reports")
    if len(fund) < 30:
        sys.exit("too few fundamentals — Yahoo coverage is thin here")
    prices = fetch_prices(list(fund), start=a.start)
    print(f"Prices: {len(prices)} symbols")
    rows = summarize(form_cohorts(fund, prices, min_np=a.min_np_growth,
                                  min_rev=a.min_rev_growth))
    txt = format_report(rows)
    os.makedirs("bt_out", exist_ok=True)
    Path("bt_out/report_quality_history.txt").write_text(txt + "\n")
    print(txt)
    print("\nSaved: bt_out/report_quality_history.txt")


if __name__ == "__main__":
    main()
