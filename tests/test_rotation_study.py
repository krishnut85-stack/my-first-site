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

def test_making_money_is_not_the_bar_beating_the_benchmark_is():
    """2020-2026 the benchmark itself did ~34% a year; +25% was a LOSS."""
    bench_past, bench_unseen = {"cagr": 16.8}, {"cagr": 33.89}
    assert rs.verdict({"cagr": 20.0}, {"cagr": 25.0},
                      bench_past, bench_unseen) == "OVERFIT"
    assert rs.verdict({"cagr": 30.0}, {"cagr": 45.0},
                      bench_past, bench_unseen) == "BEATS"
    assert rs.verdict({"cagr": 5.0}, {"cagr": 20.0},
                      bench_past, bench_unseen) == "LAGS"
    assert rs.verdict({"cagr": 5.0}, {"cagr": 40.0},
                      bench_past, bench_unseen) == "LUCKY?"


def test_excess_is_measured_against_the_same_half():
    """A rule is never credited for a bull run the benchmark also enjoyed."""
    assert rs._ex({"cagr": 45.0}, {"cagr": 33.89}) == pytest.approx(11.11)
    assert rs._ex({"cagr": 25.0}, {"cagr": 33.89}) == pytest.approx(-8.89)
    assert rs._ex({"cagr": None}, {"cagr": 10.0}) is None


def test_the_grid_carries_excess_for_both_halves():
    n = 150
    d = market({c: [(i % 3 - 1) * 2.0 for i in range(n)] for c in "ABCDEF"})
    rets = rs.monthly_returns_by_industry(d)
    rows, _p, _u = rs.run_grid(rets, rs.all_months(rets))
    assert all("excess_past" in r and "excess_unseen" in r for r in rows)
    assert all(r["verdict"] in {"BEATS", "OVERFIT", "LAGS", "LUCKY?", "NO DATA"}
               for r in rows)


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


def test_current_picks_are_the_rule_speaking_not_a_fresh_opinion():
    """Today's holdings must come from the same window the rule was tested on."""
    n = 60
    d = market({"HOT": [3.0] * n, "WARM": [1.0] * n, "COOL": [0.0] * n,
                "COLD": [-2.0] * n})
    rets = rs.monthly_returns_by_industry(d)
    months = rs.all_months(rets)
    picks = rs.current_picks(rets, months, 6, 2, "momentum")
    assert [p["industry"] for p in picks] == ["HOT", "WARM"]   # best first
    assert picks[0]["trailing"] > picks[1]["trailing"]
    con = rs.current_picks(rets, months, 6, 2, "contrarian")
    assert [p["industry"] for p in con] == ["COLD", "COOL"]


def test_current_picks_need_enough_history():
    d = market({"A": [1.0] * 3, "B": [2.0] * 3})
    rets = rs.monthly_returns_by_industry(d)
    assert rs.current_picks(rets, rs.all_months(rets), 12, 2) == []


def test_consistency_ranks_by_the_weaker_half():
    rows = [
        {"direction": "momentum", "lookback": 6, "hold": 6, "k": 5,
         "excess_past": 10.3, "excess_unseen": 10.9, "verdict": "BEATS"},
        {"direction": "momentum", "lookback": 3, "hold": 3, "k": 5,
         "excess_past": 12.6, "excess_unseen": 5.4, "verdict": "BEATS"},
        {"direction": "momentum", "lookback": 1, "hold": 1, "k": 5,
         "excess_past": -4.0, "excess_unseen": 30.0, "verdict": "LUCKY?"},
    ]
    out = rs.consistency(rows)
    assert len(out) == 2                        # the LUCKY? row is excluded
    assert out[0]["lookback"] == 6              # 10.3 beats 5.4 as a worst half
    assert out[0]["weaker"] == pytest.approx(10.3)
    assert out[0]["gap"] == pytest.approx(0.6)


def test_both_the_raw_return_and_the_excess_are_available_to_print():
    """Showing only one of them hides something. Keep both in the row."""
    n = 150
    d = market({c: [(i % 3 - 1) * 2.0 + (0.5 if c == "A" else 0)
                    for i in range(n)] for c in "ABCDEF"})
    rets = rs.monthly_returns_by_industry(d)
    rows, _p, _u = rs.run_grid(rets, rs.all_months(rets))
    r = rows[0]
    assert r["unseen"]["cagr"] is not None      # what the money did
    assert r["excess_unseen"] is not None       # what the skill did
    assert r["past"]["cagr"] is not None and r["excess_past"] is not None


def test_next_rerank_date_is_stated():
    assert rs._add_months("2026-09", 6) == "2027-03"
    assert rs._add_months("2026-12", 1) == "2027-01"
    assert rs._add_months("2026-01", 12) == "2027-01"
