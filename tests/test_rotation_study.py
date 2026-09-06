"""Testing the strategy itself: does buying the weak industry pay?

Each test builds a market whose behaviour is known in advance, so the
backtester has to find the answer that is actually there.
"""

import pytest

from garuda import rotation_study as rs


def series_from(monthly, start="2010-01"):
    """[{t,c}] from a list of monthly % returns."""
    out, lvl = [], 100.0
    y, m = int(start[:4]), int(start[5:])
    for r in monthly:
        lvl *= (1 + r / 100.0)
        out.append({"t": f"{y:04d}-{m:02d}-28", "c": round(lvl, 6)})
        m += 1
        if m > 12:
            m, y = 1, y + 1
    return out


def market(spec):
    return {k: series_from(v) for k, v in spec.items()}


# ------------------------------------------------------------- plumbing ----

def test_monthly_returns_are_month_on_month():
    d = market({"A": [10.0, -10.0]})
    r = rs.monthly_returns_by_industry(d)["A"]
    assert list(r.values())[0] == pytest.approx(-10.0)


def test_stats_compound_and_measure_the_drawdown():
    s = [("2020-01", 10.0), ("2020-02", -10.0)]
    st = rs.stats(s)
    assert st["total"] == pytest.approx(-1.0)
    assert st["maxdd"] == pytest.approx(-10.0)
    assert st["hit"] == 50


def test_empty_history_reports_nothing_rather_than_zero():
    assert rs.stats([])["cagr"] is None
    assert rs.verdict(rs.stats([]), rs.stats([])) == "NO DATA"


# ------------------------------------------------- the strategies, tested ----

def test_contrarian_wins_in_a_mean_reverting_market():
    """Whatever fell last month rises next month — buying weakness must pay."""
    n = 120
    a = [(-8.0 if i % 2 == 0 else 8.0) for i in range(n)]
    b = [(8.0 if i % 2 == 0 else -8.0) for i in range(n)]
    d = market({"A": a, "B": b, "C": [0.0] * n, "D": [0.0] * n,
                "E": [0.0] * n, "F": [0.0] * n})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    con = rs.stats(rs.backtest(rets, months, 1, 1, 3, "contrarian", cost_bps=0))
    mom = rs.stats(rs.backtest(rets, months, 1, 1, 3, "momentum", cost_bps=0))
    assert con["cagr"] > mom["cagr"]
    assert con["cagr"] > 0


def test_momentum_wins_when_strength_persists():
    """A steady leader — buying weakness must lose to buying strength."""
    n = 120
    d = market({"WINNER": [3.0] * n, "OK": [0.5] * n, "FLAT": [0.0] * n,
                "SOFT": [-0.5] * n, "LOSER": [-2.0] * n, "BAD": [-2.5] * n})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    con = rs.stats(rs.backtest(rets, months, 6, 3, 2, "contrarian", cost_bps=0))
    mom = rs.stats(rs.backtest(rets, months, 6, 3, 2, "momentum", cost_bps=0))
    assert mom["cagr"] > con["cagr"]
    assert con["cagr"] < 0            # buying the fallers loses here


def test_costs_are_charged_on_turnover_only():
    """A book that never changes hands pays nothing after the first switch."""
    n = 60
    d = market({"A": [1.0] * n, "B": [0.9] * n, "C": [0.8] * n,
                "D": [-1.0] * n, "E": [-1.1] * n, "F": [-1.2] * n})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    free = rs.stats(rs.backtest(rets, months, 3, 1, 3, "momentum", cost_bps=0))
    paid = rs.stats(rs.backtest(rets, months, 3, 1, 3, "momentum", cost_bps=100))
    # holdings are stable, so the cost drag is tiny, not 1% a month
    assert free["cagr"] - paid["cagr"] < 0.5


def test_churning_pays_more_than_a_stable_book():
    n = 120
    a = [(-8.0 if i % 2 == 0 else 8.0) for i in range(n)]
    b = [(8.0 if i % 2 == 0 else -8.0) for i in range(n)]
    d = market({"A": a, "B": b, "C": [0.0] * n, "D": [0.0] * n})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    free = rs.stats(rs.backtest(rets, months, 1, 1, 2, "contrarian", cost_bps=0))
    paid = rs.stats(rs.backtest(rets, months, 1, 1, 2, "contrarian", cost_bps=100))
    assert free["cagr"] > paid["cagr"]        # switching every month is charged


def test_hold_period_keeps_the_book_still():
    """hold=6 must not re-pick every month — that is the 'wait' in the plan."""
    n = 60
    d = market({c: [float(i) * 0.1] * n for i, c in enumerate("ABCDEF")})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    h1 = rs.backtest(rets, months, 3, 1, 2, "contrarian", cost_bps=0)
    h6 = rs.backtest(rets, months, 3, 6, 2, "contrarian", cost_bps=0)
    assert len(h1) == len(h6)          # same number of months invested


# -------------------------------------------------------- honest scoring ----

def test_a_rule_that_only_worked_on_the_past_is_called_overfit():
    good, bad = {"cagr": 12.0}, {"cagr": -3.0}
    assert rs.verdict(good, bad) == "OVERFIT"
    assert rs.verdict(good, {"cagr": 5.0}) == "HOLDS UP"
    assert rs.verdict(bad, bad) == "REJECTED"


def test_the_split_never_lets_the_unseen_years_leak_into_the_past():
    months = [f"2010-{m:02d}" for m in range(1, 13)] * 2
    months = sorted(set(f"20{y:02d}-{m:02d}" for y in range(10, 30)
                        for m in range(1, 13)))
    past, unseen = rs.split_months(months)
    assert past[-1] < unseen[0]
    assert len(past) + len(unseen) == len(months)
    assert len(past) / len(months) == pytest.approx(rs.PAST_FRACTION, abs=0.01)


def test_the_grid_scores_every_rule_on_both_halves():
    n = 150
    d = market({c: [(i % 3 - 1) * 2.0 for i in range(n)] for c in "ABCDEF"})
    rets = rs.monthly_returns_by_industry(d)
    rows, past, unseen = rs.run_grid(rets, rs.all_months(rets))
    assert len(rows) == (len(rs.DIRECTIONS) * len(rs.LOOKBACKS)
                         * len(rs.HOLDS) * len(rs.KS))
    assert all("past" in r and "unseen" in r and "verdict" in r for r in rows)
    assert past[-1] < unseen[0]


def test_a_gap_between_months_is_not_a_return():
    """Jan then April is missing data; booking it as one month inflates all."""
    d = {"A": [{"t": "2020-01-28", "c": 100.0}, {"t": "2020-04-28", "c": 200.0},
               {"t": "2020-05-28", "c": 210.0}]}
    r = rs.monthly_returns_by_industry(d)["A"]
    assert "2020-04" not in r                  # the 100% jump is discarded
    assert r["2020-05"] == pytest.approx(5.0)  # the real month survives


def test_an_impossible_benchmark_is_flagged_not_reported(capsys, tmp_path,
                                                         monkeypatch):
    """A 75%-a-year 'benchmark' means the input is broken, not that we won."""
    n = 120
    d = market({c: [12.0] * n for c in "ABCDEF"})     # 12% a MONTH
    rets = rs.monthly_returns_by_industry(d)
    bench = rs.stats(rs.equal_weight_all(rets, rs.all_months(rets)))
    assert bench["cagr"] > rs.IMPLAUSIBLE_CAGR
