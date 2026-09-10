"""Catch the industry that has bottomed AND started to turn — tested.

The rotation study asked one question two ways: ride the leader (momentum) or
buy the faller (contrarian). Momentum won and contrarian lost badly. But
"buy the faller" is not the same idea as "buy the one that has bottomed out and
is starting to move", and conflating them buried the second inside the first.

A pure contrarian screen cannot tell a falling knife from a base that is
breaking upward — both are simply "down a lot". This asks for BOTH conditions:

  * BEATEN DOWN — the industry is at least `min_dd` below its own peak of the
    last `peak_win` months. Its own peak, not the market's: an industry that
    merely lagged a roaring market has not bottomed out.
  * TURNING — of those, hold the ones with the strongest return over the last
    `thrust_win` months. Something has to have started, or it is a knife.

That second condition is the whole difference, and it is why this can win
where contrarian lost even though both buy things that have fallen.

Sitting out is modelled honestly: in a month when nothing is beaten down
enough to qualify, the book earns zero rather than the month being dropped
from the record. Skipping those months would quietly measure the rule only
on the months it liked, and every rule looks good that way.

    python3 -m garuda.turn_study --universe /path/to/universe
"""

import statistics

from .rotation_study import (COST_BPS, IMPLAUSIBLE_CAGR, _load_industry_series,
                             all_months, backtest, equal_weight_all,
                             monthly_returns_by_industry, split_months, stats,
                             trailing)

#: How far below its own recent peak counts as "beaten down".
MIN_DDS = (10.0, 20.0, 30.0)

#: The window the peak is measured over.
PEAK_WIN = 12

#: How long a turn has to have been running to count as started.
THRUSTS = (1, 3, 6)

HOLDS = (3, 6)
KS = (3, 5)


def drawdown_from_peak(rets, ind, upto_idx, months, window=PEAK_WIN):
    """How far below its highest point of the last `window` months, in percent.

    Compounded from monthly returns, so the "peak" is the peak of this
    industry's own equity curve — the thing an investor in it would have felt.
    Returns 0.0 at a new high, negative below one, None without enough history.
    """
    lo = upto_idx - window + 1
    if lo < 0:
        return None
    lvl, peak = 100.0, 100.0
    for i in range(lo, upto_idx + 1):
        r = rets.get(ind, {}).get(months[i])
        if r is None:
            return None
        lvl *= (1 + r / 100.0)
        peak = max(peak, lvl)
    return (lvl / peak - 1) * 100.0


def turn_ranked(rets, months, i, thrust_win, min_dd, peak_win=PEAK_WIN):
    """Beaten-down industries that have started to move, best thrust first.

    Empty when nothing qualifies — which is a real answer, not a failure. In a
    market where nothing has fallen, this rule has nothing to buy.
    """
    out = []
    for ind in rets:
        dd = drawdown_from_peak(rets, ind, i, months, peak_win)
        if dd is None or dd > -min_dd:
            continue
        t = trailing(rets, ind, i, months, thrust_win)
        if t is None or t <= 0:
            continue          # down a lot but still falling — a knife
        out.append((ind, t))
    out.sort(key=lambda x: -x[1])
    return [a for a, _ in out]


def backtest_turn(rets, months, thrust_win, min_dd, hold, k,
                  cost_bps=COST_BPS, peak_win=PEAK_WIN, diag=None):
    """Monthly returns of the turn rule. Cash in months with nothing to buy."""
    out, held, since, idle = [], [], 0, 0
    lookback = max(thrust_win, peak_win)
    for i in range(len(months) - 1):
        if i < lookback:
            continue
        cost = 0.0
        if not held or since >= hold:
            order = turn_ranked(rets, months, i, thrust_win, min_dd, peak_win)
            picks = order[:k]
            prev = list(held)
            if picks != prev:
                changed = len(set(picks) ^ set(prev))
                cost = min(1.0, changed / float(k)) * cost_bps / 100.0
            held, since = picks, 0
        since += 1
        nxt = months[i + 1]
        got = [rets[p][nxt] for p in held if nxt in rets.get(p, {})]
        if not held:
            idle += 1
            out.append((nxt, -cost))          # in cash, and it counts
            continue
        if not got:
            continue
        out.append((nxt, statistics.fmean(got) - cost))
    if diag is not None and out:
        diag["idle_pct"] = round(idle / len(out) * 100, 1)
    return out


def run_grid(rets, months, cost_bps=COST_BPS):
    """Every turn rule, scored on PAST and again on the UNSEEN years."""
    past, unseen = split_months(months)
    bench_past = stats(equal_weight_all(rets, past))
    bench_unseen = stats(equal_weight_all(rets, unseen))
    rows = []
    for thrust in THRUSTS:
        for min_dd in MIN_DDS:
            for hold in HOLDS:
                for k in KS:
                    dp, du = {}, {}
                    a = stats(backtest_turn(rets, past, thrust, min_dd, hold,
                                            k, cost_bps, diag=dp))
                    b = stats(backtest_turn(rets, unseen, thrust, min_dd, hold,
                                            k, cost_bps, diag=du))
                    rows.append({
                        "thrust": thrust, "min_dd": min_dd, "hold": hold,
                        "k": k, "past": a, "unseen": b,
                        "idle_past": dp.get("idle_pct"),
                        "idle_unseen": du.get("idle_pct"),
                        "excess_past": (a["cagr"] or 0) - (bench_past["cagr"] or 0),
                        "excess_unseen": (b["cagr"] or 0) - (bench_unseen["cagr"] or 0),
                    })
    rows.sort(key=lambda r: -(r["excess_unseen"]))
    return rows, past, unseen, bench_past, bench_unseen


def verdict(row):
    if row["excess_past"] > 0 and row["excess_unseen"] > 0:
        return "BEATS"
    if row["excess_past"] > 0:
        return "OVERFIT"
    if row["excess_unseen"] > 0:
        return "LUCKY?"
    return "LAGS"


def _pc(v):
    return "—" if v is None else f"{v:+.2f}%"


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    cost = opt("--cost-bps", int, COST_BPS)
    data, _members = _load_industry_series(opt("--csv-dir"), opt("--universe"))
    if not data:
        return 1
    rets = monthly_returns_by_industry(data)
    months = all_months(rets)
    if len(months) < 60:
        print(f"only {len(months)} months of history — not enough to judge")
        return 1

    rows, past, unseen, bp, bu = run_grid(rets, months, cost)
    print(f"\n{len(rets)} industries · {len(months)} months "
          f"({months[0]} to {months[-1]})")
    print(f"PAST {past[0]}..{past[-1]}   UNSEEN {unseen[0]}..{unseen[-1]}")
    print(f"\nBENCHMARK — hold every industry, always:")
    print(f"  past {_pc(bp['cagr'])}/yr    unseen {_pc(bu['cagr'])}/yr")
    if (bu["cagr"] or 0) > IMPLAUSIBLE_CAGR:
        print("\nSTOP — the benchmark is implausible; the price data is wrong.")
        return 1

    # The rule momentum found, for contrast. Same data, same split, same costs.
    mom_unseen = stats(backtest(rets, unseen, 6, 6, 5, "momentum", cost))
    mom_past = stats(backtest(rets, past, 6, 6, 5, "momentum", cost))
    print(f"\nRIDE THE LEADER (momentum look 6m hold 6m top5), for contrast:")
    print(f"  past {_pc(mom_past['cagr'])}/yr "
          f"({_pc((mom_past['cagr'] or 0) - (bp['cagr'] or 0))} vs bm)    "
          f"unseen {_pc(mom_unseen['cagr'])}/yr "
          f"({_pc((mom_unseen['cagr'] or 0) - (bu['cagr'] or 0))} vs bm)")

    print(f"\nCATCH THE TURN — beaten down past its own peak, and moving again")
    print(f"  {'thrust':<8}{'below pk':<10}{'hold':<6}{'top':<5}"
          f"{'UNSEEN':>10}{'vs bm':>9}{'PAST':>10}{'vs bm':>9}"
          f"{'idle':>7}  verdict")
    for r in rows:
        print(f"  {str(r['thrust']) + 'm':<8}{'-' + str(int(r['min_dd'])) + '%':<10}"
              f"{str(r['hold']) + 'm':<6}{r['k']:<5}"
              f"{_pc(r['unseen']['cagr']):>10}{_pc(r['excess_unseen']):>9}"
              f"{_pc(r['past']['cagr']):>10}{_pc(r['excess_past']):>9}"
              f"{(str(r['idle_unseen']) + '%') if r['idle_unseen'] is not None else '—':>7}"
              f"  {verdict(r)}")

    beats = [r for r in rows if verdict(r) == "BEATS"]
    print(f"\n{len(beats)} of {len(rows)} turn rules beat the benchmark in "
          f"BOTH halves.")
    if beats:
        b = beats[0]
        print(f"Best: thrust {b['thrust']}m, at least {int(b['min_dd'])}% below "
              f"its own {PEAK_WIN}-month peak, hold {b['hold']}m, top{b['k']}")
        print(f"  unseen {_pc(b['unseen']['cagr'])}/yr "
              f"({_pc(b['excess_unseen'])} vs benchmark), "
              f"past {_pc(b['past']['cagr'])}/yr ({_pc(b['excess_past'])})")
        print(f"  in cash {b['idle_unseen']}% of unseen months "
              f"— nothing qualified")
        if (b["excess_unseen"] or 0) > ((mom_unseen["cagr"] or 0)
                                        - (bu["cagr"] or 0)):
            print("  -> and it beats riding the leader on the unseen years.")
        else:
            print("  -> but riding the leader still earned more on unseen "
                  "years.")
    else:
        print("On this data, waiting for the turn did not pay after costs.")
    print("\n'idle' is the share of months the rule held nothing because no")
    print("industry was both beaten down and moving. Those months earn zero")
    print("and are counted — a rule that only trades when it likes the setup")
    print("must be charged for the time it sits out.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
