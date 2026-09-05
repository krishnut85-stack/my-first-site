"""What each sector index has actually done, month by month, over real history.

The CYCLE tab's phase map is *theory* — the textbook link between rates and
sectors. This module is the opposite: it measures. It pulls daily history for
every NSE sector index and answers, with numbers and sample counts:

    in month M, how has sector S behaved, and how often?

That is the "which industry rises in which period" question, answered from the
tape rather than from a chart in a book.

Three rules it holds itself to
------------------------------
1. **It reports its own sample size.** Every cell carries ``n`` — how many
   Septembers actually went into that September number. A mean over 9 years is
   labelled 9, not dressed up as a law.
2. **It reports the span it really got**, not the span you asked for. Kite's
   historical API does not reach back 20 years for indices; whatever it
   returns is what gets reported.
3. **Excess over the Nifty, not raw return.** A sector rising 2% in a month the
   whole market rose 3% did not lead — it lagged. Raw monthly returns mostly
   measure the market; the excess is the part that is about the sector.

Running it (on the droplet, where Kite lives)::

    python3 -m garuda.cycle_study                 # fetch + compute
    python3 -m garuda.cycle_study --years 20      # ask for more history
    python3 -m garuda.cycle_study --offline       # recompute from the cache
    python3 -m garuda.cycle_study --from-csv DIR  # no Kite at all

It never places an order: it takes the read-only Kite handle, whose order
methods do not exist. Prices are cached per index under
``garuda/data/sector_history/`` so a re-run costs nothing and the history
survives even if the API stops serving those years.
"""

import csv
import json
import statistics
from datetime import date, datetime, timedelta
from pathlib import Path

from . import config

#: The NSE sector indices, by the tradingsymbol Kite knows them as. Same names
#: GIR's SECTOR_INDICES_MAP uses, so the two systems talk about one vocabulary.
SECTOR_INDICES = {
    "BANKING": "NIFTY BANK",
    "IT": "NIFTY IT",
    "PHARMA": "NIFTY PHARMA",
    "FMCG": "NIFTY FMCG",
    "AUTO": "NIFTY AUTO",
    "METALS": "NIFTY METAL",
    "ENERGY": "NIFTY ENERGY",
    "REALTY": "NIFTY REALTY",
    "SERVICES": "NIFTY FIN SERVICE",
    "HEALTHCARE": "NIFTY HEALTHCARE",
    "CONSUMPTION": "NIFTY CONSUMPTION",
    "PSUBANK": "NIFTY PSU BANK",
    "PVTBANK": "NIFTY PVT BANK",
    "MEDIA": "NIFTY MEDIA",
    "INFRA": "NIFTY INFRA",
    "OILGAS": "NIFTY OIL & GAS",
}

BENCHMARK = "NIFTY 50"

HISTORY_DIR = config.DATA_DIR / "sector_history"
STUDY_FILE = config.DATA_DIR / "cycle_study.json"

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

#: Below this many observations a month/sector cell is shown but marked thin.
MIN_SAMPLE = 5


# ----------------------------------------------------------- pure maths ----
# Kept free of Kite and of the filesystem so it can be tested directly.

def month_end_closes(candles):
    """{(year, month): last close of that month} from [{t, c}, ...]."""
    out = {}
    for row in candles:
        t = str(row.get("t", ""))[:10]
        if len(t) < 7:
            continue
        try:
            y, m = int(t[:4]), int(t[5:7])
            close = float(row["c"])
        except (TypeError, ValueError, KeyError):
            continue
        key = (y, m)
        prev = out.get(key)
        if prev is None or t >= prev[0]:
            out[key] = (t, close)
    return {k: v[1] for k, v in out.items()}


def monthly_returns(candles):
    """[(year, month, pct return)] month-end to month-end, chronological."""
    closes = month_end_closes(candles)
    keys = sorted(closes)
    out = []
    for i in range(1, len(keys)):
        prev_k, k = keys[i - 1], keys[i]
        # only consecutive months — a gap means missing data, not a return
        if (k[0] - prev_k[0]) * 12 + (k[1] - prev_k[1]) != 1:
            continue
        a, b = closes[prev_k], closes[k]
        if a:
            out.append((k[0], k[1], (b - a) / a * 100.0))
    return out


def summarise(values):
    """mean / median / hit-rate / n for one bucket of returns."""
    vals = [v for v in values if v is not None]
    if not vals:
        return {"n": 0, "mean": None, "median": None, "hit": None}
    return {
        "n": len(vals),
        "mean": round(statistics.fmean(vals), 2),
        "median": round(statistics.median(vals), 2),
        "hit": round(sum(1 for v in vals if v > 0) / len(vals) * 100),
    }


def monthly_table(sector_returns, bench_returns):
    """Per-month stats for one sector, in raw and in excess over the benchmark.

    The excess is the honest measure: it strips out the months when everything
    rose together and leaves what the sector did on its own.
    """
    bench = {(y, m): r for y, m, r in bench_returns}
    raw = {m: [] for m in range(1, 13)}
    exc = {m: [] for m in range(1, 13)}
    for y, m, r in sector_returns:
        raw[m].append(r)
        b = bench.get((y, m))
        if b is not None:
            exc[m].append(r - b)
    return {m: {"raw": summarise(raw[m]), "excess": summarise(exc[m])}
            for m in range(1, 13)}


def rank_by_month(tables):
    """{month: [sectors, best excess first]} — the "where, when" answer."""
    out = {}
    for m in range(1, 13):
        scored = [(s, t[m]["excess"]["mean"], t[m]["excess"]["n"])
                  for s, t in tables.items()
                  if t[m]["excess"]["mean"] is not None]
        scored.sort(key=lambda x: x[1], reverse=True)
        out[m] = [{"sector": s, "excess": v, "n": n} for s, v, n in scored]
    return out


def coverage(all_returns):
    """What history we actually ended up with — reported, never assumed."""
    years = sorted({y for rows in all_returns.values() for y, _m, _r in rows})
    months = sum(len(r) for r in all_returns.values())
    return {"first_year": years[0] if years else None,
            "last_year": years[-1] if years else None,
            "years": len(years),
            "observations": months}


# --------------------------------------------------------------- fetch ----

def _cache_path(name):
    return HISTORY_DIR / f"{name.replace(' ', '_').replace('&', 'and')}.csv"


def load_cached(name):
    p = _cache_path(name)
    if not p.exists():
        return []
    try:
        with p.open() as f:
            return [{"t": r["t"], "c": float(r["c"])} for r in csv.DictReader(f)
                    if r.get("c")]
    except Exception:  # noqa: BLE001
        return []


def save_cached(name, candles):
    HISTORY_DIR.mkdir(parents=True, exist_ok=True)
    p = _cache_path(name)
    with p.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["t", "c"])
        w.writeheader()
        for row in candles:
            w.writerow({"t": row["t"], "c": row["c"]})
    return p


def fetch_index(kite, token, years=20, chunk_days=1500):
    """Daily closes as far back as Kite will serve, walking backwards.

    Kite caps a daily-candle request at a few thousand days, so this asks in
    chunks and stops at the first empty one — which is how the real start of
    the series announces itself.
    """
    out, end = [], date.today()
    start_limit = end - timedelta(days=int(years * 365.25))
    while end > start_limit:
        start = max(start_limit, end - timedelta(days=chunk_days))
        try:
            rows = kite.historical_data(token, start, end, "day")
        except Exception:  # noqa: BLE001
            break
        if not rows:
            break
        for d in rows:
            dt = d.get("date")
            t = dt.strftime("%Y-%m-%d") if hasattr(dt, "strftime") else str(dt)[:10]
            out.append({"t": t, "c": float(d["close"])})
        end = start - timedelta(days=1)
    seen, uniq = set(), []
    for row in sorted(out, key=lambda r: r["t"]):
        if row["t"] not in seen:
            seen.add(row["t"])
            uniq.append(row)
    return uniq


def gather(kite=None, years=20, offline=False, from_csv=None, log=print):
    """{sector name: candles} from the cache, a CSV directory, or Kite."""
    names = dict(SECTOR_INDICES)
    names["_BENCH"] = BENCHMARK
    data = {}
    tokens = {}
    if kite and not offline and not from_csv:
        try:
            tokens = {i["tradingsymbol"]: i["instrument_token"]
                      for i in kite.instruments("NSE")}
        except Exception as e:  # noqa: BLE001
            log(f"  instrument dump failed ({e}) — falling back to the cache")
    for key, idx in names.items():
        candles = []
        if from_csv:
            p = Path(from_csv) / f"{idx.replace(' ', '_').replace('&', 'and')}.csv"
            if p.exists():
                with p.open() as f:
                    candles = [{"t": r["t"], "c": float(r["c"])}
                               for r in csv.DictReader(f) if r.get("c")]
        elif offline:
            candles = load_cached(idx)
        else:
            tok = tokens.get(idx)
            if tok and kite:
                candles = fetch_index(kite, tok, years=years)
                if candles:
                    save_cached(idx, candles)
            if not candles:
                candles = load_cached(idx)
        if candles:
            data[key] = candles
            log(f"  {idx:22} {len(candles):>5} days  "
                f"{candles[0]['t']} -> {candles[-1]['t']}")
        else:
            log(f"  {idx:22} no data")
    return data


def build(data):
    """The whole study, as the JSON the dashboard renders."""
    bench = monthly_returns(data.get("_BENCH", []))
    rets = {k: monthly_returns(v) for k, v in data.items() if k != "_BENCH"}
    tables = {k: monthly_table(v, bench) for k, v in rets.items() if v}
    return {
        "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "benchmark": BENCHMARK,
        "coverage": coverage(rets),
        "min_sample": MIN_SAMPLE,
        "months": MONTHS,
        "sectors": sorted(tables),
        "table": {s: {str(m): t[m] for m in range(1, 13)}
                  for s, t in tables.items()},
        "ranked": {str(m): v for m, v in rank_by_month(tables).items()},
    }


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    years = opt("--years", int, 20)
    offline = "--offline" in argv
    from_csv = opt("--from-csv")

    kite = None
    if not offline and not from_csv:
        try:
            from .feed import KiteFeed
            feed = KiteFeed()
            if feed.live():
                # Read-only: this study must never be able to place an order.
                try:
                    sys.path.insert(0, "/home/globalbot")
                    import kite_session
                    kite = kite_session.ReadOnlyKite(feed.kite)
                except Exception:  # noqa: BLE001
                    kite = feed.kite
            else:
                print("no live Kite session — using the cache", flush=True)
                offline = True
        except Exception as e:  # noqa: BLE001
            print(f"Kite unavailable ({e}) — using the cache", flush=True)
            offline = True

    print("gathering sector history", flush=True)
    data = gather(kite, years=years, offline=offline, from_csv=from_csv)
    if not data:
        print("no history at all — nothing to study", flush=True)
        return 1

    study = build(data)
    cov = study["coverage"]
    STUDY_FILE.parent.mkdir(parents=True, exist_ok=True)
    STUDY_FILE.write_text(json.dumps(study, indent=1))
    print(f"\nwrote {STUDY_FILE}")
    print(f"  {len(study['sectors'])} sectors · {cov['years']} calendar years "
          f"({cov['first_year']}-{cov['last_year']}) · "
          f"{cov['observations']} sector-months")
    if cov["years"] and cov["years"] < 10:
        print("  NOTE: that is the history Kite served, not the history asked "
              "for. Monthly cells will be thin.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
