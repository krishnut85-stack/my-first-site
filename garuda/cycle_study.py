"""What each INDUSTRY has actually done, month by month, over real history.

The CYCLE tab's phase map is *theory* — the textbook link between rates and
sectors. This module is the opposite: it measures. It pulls daily history for
every NSE sector index and answers, with numbers and sample counts:

    in month M, how has industry I behaved, and how often?

Industries, not the sixteen broad sector indices. "Cement", "Auto Ancillaries",
"Sugar", "Hotels" are industries; NIFTY AUTO is an index covering many of them
at once. The taxonomy comes from your own Trendlyne universe export (NSE Code
-> Industry), and each industry's series is built equal-weight from its
constituent stocks — so an industry with one huge company and nine small ones
is not simply that company.

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

    python3 -m garuda.cycle_study                  # every industry
    python3 -m garuda.cycle_study --universe FILE  # a specific export
    python3 -m garuda.cycle_study --limit 200      # a quick first pass
    python3 -m garuda.cycle_study --offline        # recompute from the cache
    python3 -m garuda.cycle_study --indices        # the 16 broad indices instead
    python3 -m garuda.cycle_study --scan           # what universe files exist?
                                                   #   (offline, no Kite, instant)

The first full run fetches daily history for every stock in the universe and
is slow — Kite rate-limits historical calls, so budget roughly a second per
three stocks. Everything is cached per stock, so a re-run costs nothing and
you can stop and resume it.

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


# ------------------------------------------------- industries, not indices ----
#
# The taxonomy comes from a Trendlyne universe export — the same file Mayura
# eats — which carries "NSE Code" and "Industry" per stock. An industry series
# is built EQUAL-WEIGHT from its constituents' daily returns, so a 40-stock
# industry is not just its largest company.

UNIVERSE_COLUMNS = ("NSE Code", "NSE code", "nse_code", "Symbol", "SYMBOL")
INDUSTRY_COLUMNS = ("Industry", "INDUSTRY", "industry")
SECTOR_COLUMNS = ("Sector", "SECTOR", "sector")

STOCK_DIR = config.DATA_DIR / "stock_history"

#: An industry day needs at least this many constituents to count. Below it the
#: "industry" is one or two companies and the average means little.
MIN_MEMBERS = 3


def _pick(row, names):
    for n in names:
        if row.get(n):
            return str(row[n]).strip()
    return ""


def load_universe(paths):
    """{symbol: (industry, sector)} merged from one or more universe CSVs."""
    out = {}
    for path in paths:
        p = Path(path)
        if not p.exists():
            continue
        try:
            with p.open(encoding="utf-8-sig") as f:
                for row in csv.DictReader(f):
                    sym = _pick(row, UNIVERSE_COLUMNS).upper()
                    ind = _pick(row, INDUSTRY_COLUMNS)
                    sec = _pick(row, SECTOR_COLUMNS)
                    if sym and ind:
                        out[sym] = (ind, sec)
        except Exception:  # noqa: BLE001
            continue
    return out


def find_universe_files(extra=None, csv_dir=None):
    """Every CSV that might carry a symbol->industry mapping.

    Casts wide on purpose: the NSE constituent lists Garuda already uses
    (Symbol + Industry) live wherever the dashboard's --csv-dir points, the
    Trendlyne exports live under mayura_data/, and neither is committed. Files
    that turn out to carry no industry column are simply ignored.
    """
    base = config.BASE_DIR.parent
    roots = []
    if extra:
        roots.append(Path(extra))
    if csv_dir:
        roots.append(Path(csv_dir))
    roots += [base / "mayura_data", base, config.DATA_DIR, Path.cwd()]
    # The per-stock and per-index price caches are CSVs sitting under DATA_DIR.
    # They carry no industry column, so they are only ever opened and discarded
    # — but there are hundreds of them and they multiply on every run, which is
    # why the candidate count climbs each time. Skip them by directory.
    skip = {STOCK_DIR.resolve(), HISTORY_DIR.resolve()}
    found, seen = [], set()
    for r in roots:
        if r.is_file():
            cand = [r]
        elif r.is_dir():
            cand = sorted(r.glob("*.csv")) + sorted(r.glob("*/*.csv"))
        else:
            continue
        for f in cand:
            rp = f.resolve()
            if rp.parent in skip or rp in seen:
                continue
            seen.add(rp)
            found.append(f)
    return found


def scan_universe(files):
    """[(file, symbols, industries)] — what each candidate actually yields.

    Offline and instant: answers "will this find my stocks?" without a single
    Kite call, which is the question worth settling before a long fetch.
    """
    out = []
    for f in files:
        u = load_universe([f])
        if u:
            out.append((f, len(u), len({i for i, _ in u.values()})))
    out.sort(key=lambda r: r[1], reverse=True)
    return out


def by_industry(universe):
    """{industry: {"sector": s, "members": [symbols]}}"""
    out = {}
    for sym, (ind, sec) in universe.items():
        d = out.setdefault(ind, {"sector": sec, "members": []})
        d["members"].append(sym)
        if sec and not d["sector"]:
            d["sector"] = sec
    for d in out.values():
        d["members"].sort()
    return out


def _stock_cache(symbol):
    safe = "".join(c for c in symbol if c.isalnum() or c in "-_&")
    return STOCK_DIR / f"{safe}.csv"


def load_stock(symbol):
    p = _stock_cache(symbol)
    if not p.exists():
        return []
    try:
        with p.open() as f:
            return [{"t": r["t"], "c": float(r["c"])}
                    for r in csv.DictReader(f) if r.get("c")]
    except Exception:  # noqa: BLE001
        return []


def save_stock(symbol, candles):
    STOCK_DIR.mkdir(parents=True, exist_ok=True)
    with _stock_cache(symbol).open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["t", "c"])
        w.writeheader()
        for row in candles:
            w.writerow({"t": row["t"], "c": row["c"]})


def industry_series(members, stocks):
    """One equal-weight index series [{t, c}] for a set of constituents.

    Each day is the MEAN of its members' daily percentage moves, compounded
    into a series starting at 100. Averaging returns rather than prices means a
    2,000-rupee stock does not outvote a 20-rupee one, and a member that only
    lists halfway through history simply joins the average from then on.
    """
    per_day = {}
    for sym in members:
        rows = stocks.get(sym) or []
        prev = None
        for row in rows:
            c = row["c"]
            if prev and prev > 0:
                per_day.setdefault(row["t"], []).append((c - prev) / prev)
            prev = c
    out, level = [], 100.0
    for t in sorted(per_day):
        moves = per_day[t]
        if len(moves) < MIN_MEMBERS:
            continue
        level *= (1 + sum(moves) / len(moves))
        out.append({"t": t, "c": round(level, 4)})
    return out


def gather_industries(kite, universe, years=20, offline=False, log=print,
                      pause=0.35, limit=None):
    """Fetch what each industry's constituents did, and fold them into series."""
    import time
    groups = by_industry(universe)
    symbols = sorted({s for g in groups.values() for s in g["members"]})
    if limit:
        symbols = symbols[:limit]
    log(f"  {len(groups)} industries · {len(symbols)} stocks")

    tokens = {}
    if kite and not offline:
        try:
            tokens = {i["tradingsymbol"]: i["instrument_token"]
                      for i in kite.instruments("NSE")}
        except Exception as e:  # noqa: BLE001
            log(f"  instrument dump failed ({e}) — cache only")

    stocks, fetched, cached, missing = {}, 0, 0, 0
    for i, sym in enumerate(symbols, 1):
        rows = load_stock(sym)
        if rows:
            cached += 1
        elif kite and tokens.get(sym) and not offline:
            rows = fetch_index(kite, tokens[sym], years=years)
            if rows:
                save_stock(sym, rows)
                fetched += 1
            time.sleep(pause)          # Kite historical is rate-limited
        if rows:
            stocks[sym] = rows
        else:
            missing += 1
        if i % 100 == 0:
            log(f"    {i}/{len(symbols)} · {fetched} fetched, {cached} cached, "
                f"{missing} missing")
    log(f"  stocks: {fetched} fetched, {cached} from cache, {missing} missing")

    data, meta = {}, {}
    for ind, g in sorted(groups.items()):
        series = industry_series(g["members"], stocks)
        if series:
            data[ind] = series
            have = sum(1 for s in g["members"] if s in stocks)
            meta[ind] = {"sector": g["sector"], "members": len(g["members"]),
                         "with_data": have}
    log(f"  built {len(data)} industry series")
    return data, meta


def build(data, meta=None):
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
        "meta": meta or {},
        "sectors": sorted(tables),
        "table": {s: {str(m): t[m] for m in range(1, 13)}
                  for s, t in tables.items()},
        "ranked": {str(m): v for m, v in rank_by_month(tables).items()},
    }


def why_no_kite():
    """Name the missing piece, rather than shrugging "no live Kite session".

    Three things have to line up, and the failure looks identical from the
    outside whichever one is absent — which is how a run ends up reporting "no
    data" for every symbol and telling you nothing about why.
    """
    import os
    problems = []
    try:
        import kiteconnect  # noqa: F401
    except Exception:  # noqa: BLE001
        problems.append("the kiteconnect package is not importable "
                        "(pip install kiteconnect)")
    if not os.environ.get("KITE_API_KEY", "").strip():
        problems.append("KITE_API_KEY is not set in the environment")
    tok_env = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    tok_file = os.environ.get("KITE_TOKEN_FILE", "").strip()
    if not tok_env:
        if not tok_file:
            problems.append("neither KITE_ACCESS_TOKEN nor KITE_TOKEN_FILE is set")
        elif not Path(tok_file).exists():
            problems.append(f"KITE_TOKEN_FILE points at {tok_file}, "
                            "which does not exist")
        else:
            try:
                d = json.loads(Path(tok_file).read_text())
                if not (isinstance(d, dict) and d.get("access_token")):
                    problems.append(f"{tok_file} has no access_token in it")
            except Exception:  # noqa: BLE001
                problems.append(f"{tok_file} is unreadable")
    if not problems:
        return ["the token is present but Kite rejected it — it may have "
                "expired (they die ~07:00 IST)"]
    return problems


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    years = opt("--years", int, 20)
    offline = "--offline" in argv
    from_csv = opt("--from-csv")
    universe_arg = opt("--universe")
    csv_dir = opt("--csv-dir")
    scan_only = "--scan" in argv
    limit = opt("--limit", int)
    indices_mode = "--indices" in argv      # the old 16-index study, if wanted

    if scan_only:
        files = find_universe_files(universe_arg, csv_dir)
        rows = scan_universe(files)
        print(f"looked at {len(files)} CSVs; {len(rows)} carry a "
              f"symbol+industry mapping\n")
        for f, n, ni in rows[:25]:
            print(f"  {n:>5} stocks  {ni:>4} industries   {f}")
        u = load_universe([f for f, _n, _i in rows])
        g = by_industry(u)
        big = sorted(g.items(), key=lambda kv: -len(kv[1]["members"]))[:10]
        print(f"\nmerged: {len(u)} stocks across {len(g)} industries")
        if big:
            print("largest industries:")
            for name, d in big:
                print(f"  {len(d['members']):>4}  {name}")
        if not u:
            print("\nNothing found. Point at the file yourself:\n"
                  "  python3 -m garuda.cycle_study --scan --universe /path/to.csv\n"
                  "It needs a column named Symbol or NSE Code, and one named "
                  "Industry.")
        return 0 if u else 1

    kite = None
    if not offline and not from_csv:
        try:
            from .feed import KiteFeed
            feed = KiteFeed()
            if feed.live:          # a property, not a method
                # Read-only: this study must never be able to place an order.
                try:
                    sys.path.insert(0, "/home/globalbot")
                    import kite_session
                    kite = kite_session.ReadOnlyKite(feed.kite)
                except Exception:  # noqa: BLE001
                    kite = feed.kite
            else:
                print("no live Kite session:", flush=True)
                for p in why_no_kite():
                    print(f"  - {p}", flush=True)
                print("\nMost likely you have not loaded the environment. Run:\n"
                      "  set -a && source /home/globalbot/.env && set +a\n"
                      "then try again. Falling back to the cache for now.",
                      flush=True)
                offline = True
        except Exception as e:  # noqa: BLE001
            print(f"Kite unavailable ({e}) — using the cache", flush=True)
            offline = True

    meta = {}
    if indices_mode:
        print("gathering sector-INDEX history", flush=True)
        data = gather(kite, years=years, offline=offline, from_csv=from_csv)
    else:
        files = find_universe_files(universe_arg, csv_dir)
        universe = load_universe(files)
        if not universe:
            print("no universe CSV with 'NSE Code' + 'Industry' columns found.\n"
                  "Point at one:  --universe /path/to/export.csv\n"
                  "(a Trendlyne stock export — the same kind Mayura eats)",
                  flush=True)
            return 1
        print(f"universe: {len(universe)} stocks from "
              f"{len([f for f in files if f.exists()])} file(s)", flush=True)
        print("gathering INDUSTRY history", flush=True)
        data, meta = gather_industries(kite, universe, years=years,
                                       offline=offline, limit=limit)
        # the benchmark is still the index — an industry is judged against the market
        bench = []
        if kite and not offline:
            try:
                toks = {i["tradingsymbol"]: i["instrument_token"]
                        for i in kite.instruments("NSE")}
                if toks.get(BENCHMARK):
                    bench = fetch_index(kite, toks[BENCHMARK], years=years)
                    if bench:
                        save_cached(BENCHMARK, bench)
            except Exception:  # noqa: BLE001
                pass
        data["_BENCH"] = bench or load_cached(BENCHMARK)
        if not data.get("_BENCH"):
            print(f"  WARNING: no {BENCHMARK} history — excess cannot be "
                  f"computed, only raw returns", flush=True)

    if not data or set(data) <= {"_BENCH"}:
        print("no history at all — nothing to study", flush=True)
        return 1

    study = build(data, meta)
    cov = study["coverage"]
    STUDY_FILE.parent.mkdir(parents=True, exist_ok=True)
    STUDY_FILE.write_text(json.dumps(study, indent=1))
    print(f"\nwrote {STUDY_FILE}")
    label = "sector indices" if indices_mode else "industries"
    unit = "sector-months" if indices_mode else "industry-months"
    print(f"  {len(study['sectors'])} {label} · {cov['years']} calendar years "
          f"({cov['first_year']}-{cov['last_year']}) · "
          f"{cov['observations']} {unit}")
    if cov["years"] and cov["years"] < 10:
        print("  NOTE: that is the history Kite served, not the history asked "
              "for. Monthly cells will be thin.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
