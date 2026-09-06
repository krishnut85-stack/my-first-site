"""Which stocks inside a winning industry actually run — tested, not assumed.

The rotation book buys every universe member of a winning industry, equally
weighted. That is a deliberate choice, not an oversight: it says "I know which
industry is moving, I do not claim to know which of its stocks will move most."

This asks whether that claim is too modest. Inside an industry that has just
risen 50%, do the stocks that led keep leading, or do the laggards catch up?
Both are plausible stories and both have believers. The difference is worth
real money and neither of us can settle it by reasoning.

It is testable with prices alone — no fundamentals, no look-ahead, the same
walk-forward split the industry study uses. The industry choice stays exactly
as the rotation study made it; only the stock selection inside it changes, so
the comparison isolates one decision.

    python3 -m garuda.stock_pick_study --universe /path/to/universe

Reads the same cached daily bars cycle_study builds, so it needs no Kite call.
"""

import statistics

from .cycle_study import (MAX_DAILY_MOVE, by_industry, find_universe_files,
                          load_stock, load_universe)
from .rotation_study import (COST_BPS, PAST_FRACTION, all_months, split_months,
                             stats, trailing)

#: A month needs this many trading days before its return means anything. A
#: stock that listed on the 27th has a 3-day "month", and compounding that
#: into a monthly series makes a listing pop look like a monthly return.
MIN_DAYS_IN_MONTH = 15

#: Stocks with less history than this never enter a basket. Same reasoning as
#: the industry study's thin-history guard, one level down.
MIN_MONTHS = 24

#: How many stocks to take from each industry. A whole number is a fixed
#: count; a fraction below 1 is a share of whatever the industry has.
#:
#: The distinction decides whether a result survives better data. With today's
#: ~5 members per industry, "top 2" means "drop the worst half". When the
#: stock-level export lifts Iron & Steel from 4 members to 88, "top 2" would
#: silently become "hold 2 of 88" — a far more aggressive bet that was never
#: tested. A fraction means the same thing at both universe sizes.
PICKS = (2, 3, 0.5, 0.34)

#: Selection rules tested inside each winning industry.
MODES = ("all", "leaders", "laggards")

#: Never hold fewer than this many names from an industry, however small the
#: fraction works out. Most industries here have 2-5 priced members, so a bare
#: fraction reduces them to a single stock — and a single stock standing in for
#: a fifth of the book is where the extra drawdown in the fraction rows comes
#: from. The floor separates "drop the weak half" from "concentrate".
FLOORS = (1, 3)


def stock_monthly_returns(symbols, max_move=MAX_DAILY_MOVE,
                          min_days=MIN_DAYS_IN_MONTH):
    """{symbol: {'YYYY-MM': pct return}} from the cached daily bars.

    Built by compounding cleaned DAILY moves within each month rather than
    dividing month-end closes, so a split lands as one discarded day instead
    of a -50% month — the same treatment industry_series gives its members.
    """
    out = {}
    for sym in symbols:
        rows = load_stock(sym)
        if not rows:
            continue
        by_month, prev = {}, None
        for row in rows:
            c = row["c"]
            if prev and prev > 0:
                r = (c - prev) / prev
                if abs(r) <= max_move:
                    by_month.setdefault(str(row["t"])[:7], []).append(r)
            prev = c
        rets = {}
        for m, moves in by_month.items():
            if len(moves) < min_days:
                continue
            acc = 1.0
            for r in moves:
                acc *= (1 + r)
            rets[m] = (acc - 1) * 100.0
        if len(rets) >= MIN_MONTHS:
            out[sym] = rets
    return out


def pick_stocks(stock_rets, members, i, months, lookback, mode, n, floor=1):
    """The stocks to hold from one industry this rebalance.

    `all` is what the live book does today. `leaders` backs the names already
    running; `laggards` backs the ones that have not moved yet, on the theory
    that they catch up to their own industry.
    """
    have = []
    for s in members:
        t = trailing(stock_rets, s, i, months, lookback)
        if t is not None:
            have.append((s, t))
    if not have:
        return []
    if mode == "all":
        return [s for s, _ in have]
    want = max(1, round(len(have) * n)) if 0 < n < 1 else int(n)
    want = max(want, min(floor, len(have)))
    if len(have) <= want:
        return [s for s, _ in have]
    have.sort(key=lambda x: x[1])
    return [s for s, _ in (have[:want] if mode == "laggards"
                           else have[-want:])]


def backtest_stocks(ind_rets, stock_rets, members_by_ind, months, lookback,
                    hold, k, mode, n, cost_bps=COST_BPS, floor=1,
                    diag=None):
    """Monthly returns of: top-k industries by momentum, then `mode` inside each.

    Equal weight across every stock held, so an industry that contributes six
    names does carry more weight than one contributing two — which is exactly
    what the live book does, and the thing being measured has to match it.
    """
    out, held, since = [], [], 0
    sizes = []
    for i in range(len(months) - 1):
        if i < lookback:
            continue
        if not held or since >= hold:
            scored = [(ind, trailing(ind_rets, ind, i, months, lookback))
                      for ind in ind_rets]
            scored = [(a, b) for a, b in scored if b is not None]
            if len(scored) < k:
                continue
            scored.sort(key=lambda x: x[1])
            picks = []
            for ind, _ in scored[-k:]:
                picks += pick_stocks(stock_rets, members_by_ind.get(ind, []),
                                     i, months, lookback, mode, n, floor)
            if not picks:
                continue
            turnover = 1.0 if not held else \
                len(set(picks) - set(held)) / float(len(picks))
            cost = turnover * cost_bps / 100.0
            held, since = picks, 0
            sizes.append(len(picks))
        else:
            cost = 0.0
        since += 1
        nxt = months[i + 1]
        got = [stock_rets[s][nxt] for s in held if nxt in stock_rets.get(s, {})]
        if not got:
            continue
        out.append((nxt, statistics.fmean(got) - cost))
    if diag is not None and sizes:
        # How many names the rule actually held, averaged over rebalances.
        # Two rules can print different names and hold the same basket: with
        # ~5 members an industry, "top 3", "top 50% min3" and "top 34% min3"
        # all come out as "hold 3", and nothing but this number says so. It
        # goes in a diag dict, never in the return series — a basket size
        # appended there would be read as a month's return.
        diag["names"] = round(statistics.fmean(sizes), 1)
    return out


def compare(ind_rets, stock_rets, members_by_ind, months, lookback, hold, k,
            cost_bps=COST_BPS, modes=MODES, picks=PICKS, floors=FLOORS):
    """Every within-industry rule, scored on PAST and on the UNSEEN years."""
    past, unseen = split_months(months)
    rows = []
    for mode in modes:
        for n in ([0] if mode == "all" else list(picks)):
            for floor in ([1] if mode == "all" or n >= 1 else list(floors)):
                diag = {}
                a = stats(backtest_stocks(ind_rets, stock_rets, members_by_ind,
                                          past, lookback, hold, k, mode, n,
                                          cost_bps, floor))
                b = stats(backtest_stocks(ind_rets, stock_rets, members_by_ind,
                                          unseen, lookback, hold, k, mode, n,
                                          cost_bps, floor, diag))
                rows.append({"mode": mode, "n": n, "floor": floor,
                             "names": diag.get("names"), "past": a,
                             "unseen": b})
    return rows, past, unseen


def _pc(v):
    return "—" if v is None else f"{v:+.2f}%"


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    lookback = opt("--lookback", int, 6)
    hold = opt("--hold", int, 6)
    k = opt("--top", int, 5)
    cost = opt("--cost-bps", int, COST_BPS)

    files = find_universe_files(opt("--universe"), opt("--csv-dir"))
    universe = load_universe(files)
    if not universe:
        print("no universe found — run cycle_study --scan first")
        return 1
    groups = by_industry(universe)
    print(f"universe: {len(universe)} stocks · {len(groups)} industries")

    stock_rets = stock_monthly_returns(sorted(universe))
    if not stock_rets:
        print("no cached prices — run cycle_study first")
        return 1
    print(f"priced: {len(stock_rets)} stocks with at least "
          f"{MIN_MONTHS} months of history")

    # The industry composite is the mean of its priced members' monthly
    # returns — the same equal-weight construction, one level up, so the
    # industry ranking here matches the one the rotation study makes.
    members_by_ind, ind_rets = {}, {}
    for ind, d in groups.items():
        mem = [s for s in d["members"] if s in stock_rets]
        if len(mem) < 2:
            continue
        members_by_ind[ind] = mem
        per_month = {}
        for s in mem:
            for m, r in stock_rets[s].items():
                per_month.setdefault(m, []).append(r)
        ind_rets[ind] = {m: statistics.fmean(v) for m, v in per_month.items()}
    months = all_months(ind_rets)
    if len(months) < 60:
        print(f"only {len(months)} months — not enough to judge")
        return 1
    print(f"{len(ind_rets)} industries with 2+ priced members · "
          f"{len(months)} months ({months[0]} to {months[-1]})")

    rows, past, unseen = compare(ind_rets, stock_rets, members_by_ind, months,
                                 lookback, hold, k, cost)
    base = next((r for r in rows if r["mode"] == "all"), None)
    print(f"\nWHICH STOCKS INSIDE THE WINNING INDUSTRIES "
          f"(top{k} by {lookback}m, held {hold}m)")
    print(f"PAST {past[0]}..{past[-1]}   UNSEEN {unseen[0]}..{unseen[-1]}")
    print(f"\n  {'rule':<22}{'UNSEEN':>10}{'PAST':>10}{'maxDD':>10}"
          f"{'trough':>9}{'names':>7}")
    for r in rows:
        if r["mode"] == "all":
            name = "all of them"
        elif 0 < r["n"] < 1:
            name = f"top {r['n'] * 100:.0f}% {r['mode']}"
            if r.get("floor", 1) > 1:
                name += f" min{r['floor']}"
        else:
            name = f"top {int(r['n'])} {r['mode']}"
        print(f"  {name:<22}{_pc(r['unseen']['cagr']):>10}"
              f"{_pc(r['past']['cagr']):>10}{_pc(r['unseen']['maxdd']):>10}"
              f"{(r['unseen'].get('maxdd_at') or '—'):>9}"
              f"{(r['names'] if r['names'] is not None else '—'):>7}")
        if base is None or r is base:
            continue
        du = (r["unseen"]["cagr"] or 0) - (base["unseen"]["cagr"] or 0)
        dp = (r["past"]["cagr"] or 0) - (base["past"]["cagr"] or 0)
        if du > 0 and dp > 0:
            print(f"      -> beats holding all of them in BOTH halves "
                  f"({_pc(du)} unseen, {_pc(dp)} past)")
        elif du <= 0 and dp <= 0:
            print(f"      -> worse in both halves.")
        else:
            print(f"      -> helps one half, hurts the other. Noise, not edge.")
    print("\n'all of them' is what the live book does today. A subset only "
          "\nearns its place by beating that on the UNSEEN years too — "
          "\nconcentration into 2-3 names is a real increase in single-stock "
          "\nrisk, so a tie is a loss.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
