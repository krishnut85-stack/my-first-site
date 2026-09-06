"""Trendlyne's own industry table — as a coverage map and an independent check.

The file has one row per industry (name, parent sector, company count, and
returns over several windows). It carries no stock symbols, so it cannot build
anything. What it can do is two things nothing else here can:

**Coverage.** It is the authoritative list of what industries exist. Comparing
it against what the study actually measured turns "48 industry series built"
into "48 of 125, covering N of M listed companies" — and names what is missing
rather than leaving the gap invisible.

**A second opinion.** It reports each industry's quarter and half-year change,
computed by someone else from their own data. Our equal-weight series compute
the same thing from Kite prices. If the two broadly agree, the construction is
sound; where they disagree sharply, one of us is wrong and it is worth knowing
which. That is the only outside check this system has.
"""

import csv
from pathlib import Path

#: Their column -> the window we compute. Names as Trendlyne exports them.
WINDOW_COLUMNS = {"Qtr Change %": "3m", "Half Yr Change %": "6m",
                  "1Yr Change %": "12m", "Month Change %": "1m"}


def _num(v):
    """'1,708.14' -> 1708.14; '-' and '' -> None."""
    if v is None:
        return None
    s = str(v).strip().replace(",", "").replace("%", "")
    if not s or s in {"-", "--", "NA"}:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def load_reference(path):
    """{industry: {sector, companies, 1m, 3m, 6m, 12m}} from the export."""
    out = {}
    p = Path(path)
    if not p.exists():
        return out
    with p.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            name = (row.get("Name") or "").strip()
            if not name:
                continue
            rec = {"sector": (row.get("Sector") or "").strip(),
                   "companies": int(_num(row.get("No. of Companies")) or 0)}
            for col, win in WINDOW_COLUMNS.items():
                rec[win] = _num(row.get(col))
            out[name] = rec
    return out


def coverage(reference, measured, meta=None):
    """What the study can see, and what it cannot.

    `measured` is the set of industry names with a series; `meta` carries how
    many of each industry's stocks we actually priced.
    """
    meta = meta or {}
    have, missing = [], []
    for name, ref in sorted(reference.items()):
        if name in measured:
            m = meta.get(name, {})
            have.append({"industry": name, "sector": ref["sector"],
                         "companies": ref["companies"],
                         "priced": m.get("with_data"),
                         "in_universe": m.get("members")})
        else:
            missing.append({"industry": name, "sector": ref["sector"],
                            "companies": ref["companies"]})
    missing.sort(key=lambda r: -r["companies"])
    return {"total": len(reference), "measured": len(have),
            "companies_total": sum(r["companies"] for r in reference.values()),
            "companies_covered": sum(r["companies"] for n, r in reference.items()
                                     if n in measured),
            "have": have, "missing": missing}


def compare(reference, ours, window="6m"):
    """Our computed return vs theirs, per industry. [] where either is absent.

    `ours` is momentum_now()-shaped rows: [{industry, 1m, 3m, 6m, 12m}].
    """
    out = []
    for row in ours:
        name = row.get("industry")
        ref = reference.get(name)
        if not ref:
            continue
        a, b = row.get(window), ref.get(window)
        if a is None or b is None:
            continue
        out.append({"industry": name, "ours": round(a, 2), "theirs": round(b, 2),
                    "gap": round(a - b, 2), "companies": ref["companies"],
                    "sector": ref["sector"]})
    out.sort(key=lambda r: -abs(r["gap"]))
    return out


def agreement(pairs):
    """How well the two agree: correlation, median gap, and the worst offender.

    Correlation is the number that matters. Two series measuring the same thing
    from different data should move together even if their levels differ —
    ours is equal-weight, theirs is likely not.
    """
    if len(pairs) < 3:
        return {"n": len(pairs), "corr": None, "median_gap": None}
    xs = [p["ours"] for p in pairs]
    ys = [p["theirs"] for p in pairs]
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    corr = sxy / (sxx * syy) ** 0.5 if sxx > 0 and syy > 0 else None
    gaps = sorted(abs(p["gap"]) for p in pairs)
    return {"n": n, "corr": round(corr, 3) if corr is not None else None,
            "median_gap": round(gaps[n // 2], 2),
            "worst": pairs[0] if pairs else None}


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    ref_path = opt("--reference") or (argv[0] if argv else None)
    if not ref_path:
        print("usage: python3 -m garuda.industry_ref --reference <trendlyne.csv> "
              "[--window 6m]")
        return 2
    window = opt("--window", str, "6m")
    reference = load_reference(ref_path)
    if not reference:
        print(f"no industries read from {ref_path}")
        return 1
    print(f"reference: {len(reference)} industries, "
          f"{sum(r['companies'] for r in reference.values())} companies")

    from .cycle_study import STUDY_FILE
    import json
    if not STUDY_FILE.exists():
        print("no cycle_study.json yet — run cycle_study first")
        return 1
    study = json.loads(STUDY_FILE.read_text())
    measured = set(study.get("sectors") or [])
    cov = coverage(reference, measured, study.get("meta"))
    pct = cov["companies_covered"] / max(1, cov["companies_total"]) * 100
    print(f"\nCOVERAGE: {cov['measured']} of {cov['total']} industries measured, "
          f"covering {cov['companies_covered']}/{cov['companies_total']} "
          f"companies ({pct:.0f}%)")
    if cov["missing"]:
        print(f"\nBiggest industries NOT measured "
              f"({len(cov['missing'])} missing):")
        for r in cov["missing"][:15]:
            print(f"  {r['companies']:>4} companies  {r['industry']}"
                  f"   [{r['sector']}]")

    pairs = compare(reference, study.get("now") or [], window)
    ag = agreement(pairs)
    print(f"\nSECOND OPINION — our {window} return vs Trendlyne's, "
          f"{ag['n']} industries in common")
    if ag["corr"] is not None:
        print(f"  correlation {ag['corr']:+.3f}   median gap "
              f"{ag['median_gap']}pp")
        if ag["corr"] > 0.8:
            print("  -> they agree. The industry series are measuring the "
                  "same thing.")
        elif ag["corr"] > 0.5:
            print("  -> broadly agree; the gaps below are worth a look.")
        else:
            print("  -> they DISAGREE. Our construction is suspect; do not "
                  "trade the ranking until this is understood.")
        print(f"\n  Biggest disagreements:")
        for p in pairs[:10]:
            print(f"    {p['industry']:<34} ours {p['ours']:>8.1f}%  "
                  f"theirs {p['theirs']:>8.1f}%  gap {p['gap']:>+8.1f}pp")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
