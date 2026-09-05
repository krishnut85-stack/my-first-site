"""Measuring what each sector actually did, month by month.

The point of the study is that it is evidence, so these tests build histories
whose answers are known in advance and check the numbers come back.
"""

import json
from datetime import date

import pytest

from garuda import cycle_study as cs


def series(monthly_pct, start_year=2015, months=120, extra=None):
    """A daily-ish series that moves `monthly_pct` each month.

    `extra` is {month: additional pct} — the planted seasonal effect.
    """
    out, price = [], 100.0
    y, m = start_year, 1
    for _ in range(months):
        bump = monthly_pct + (extra or {}).get(m, 0.0)
        price *= (1 + bump / 100.0)
        # two candles a month: the later one is the month-end close
        out.append({"t": f"{y:04d}-{m:02d}-15", "c": round(price * 0.99, 4)})
        out.append({"t": f"{y:04d}-{m:02d}-28", "c": round(price, 4)})
        m += 1
        if m > 12:
            m, y = 1, y + 1
    return out


def test_month_end_close_is_the_last_close_of_the_month():
    c = [{"t": "2020-01-02", "c": 10}, {"t": "2020-01-31", "c": 12},
         {"t": "2020-01-15", "c": 11}]
    assert cs.month_end_closes(c) == {(2020, 1): 12.0}


def test_returns_are_month_end_to_month_end():
    c = [{"t": "2020-01-31", "c": 100}, {"t": "2020-02-29", "c": 110}]
    assert cs.monthly_returns(c) == [(2020, 2, pytest.approx(10.0))]


def test_a_gap_in_the_data_is_not_a_return():
    """Jan then April is missing data, not a 3-month move booked as one."""
    c = [{"t": "2020-01-31", "c": 100}, {"t": "2020-04-30", "c": 130}]
    assert cs.monthly_returns(c) == []


def test_summarise_reports_hit_rate_and_sample_size():
    s = cs.summarise([2.0, -1.0, 4.0, -3.0])
    assert s["n"] == 4 and s["hit"] == 50
    assert s["mean"] == pytest.approx(0.5)


def test_empty_bucket_says_so_rather_than_guessing():
    assert cs.summarise([]) == {"n": 0, "mean": None, "median": None, "hit": None}


def test_a_planted_september_effect_is_recovered_as_excess():
    """The whole study in one test: sector beats the market only in September."""
    bench = cs.monthly_returns(series(1.0))
    sect = cs.monthly_returns(series(1.0, extra={9: 3.0}))
    t = cs.monthly_table(sect, bench)
    assert t[9]["excess"]["mean"] == pytest.approx(3.0, abs=0.05)
    assert t[9]["excess"]["hit"] == 100
    assert t[4]["excess"]["mean"] == pytest.approx(0.0, abs=0.05)
    # raw return alone would NOT isolate this — it carries the market too
    assert t[9]["raw"]["mean"] > t[9]["excess"]["mean"]


def test_ranking_puts_the_seasonal_winner_first_in_its_month():
    bench = cs.monthly_returns(series(1.0))
    tables = {
        "AUTO": cs.monthly_table(cs.monthly_returns(series(1.0, extra={11: 4.0})), bench),
        "IT": cs.monthly_table(cs.monthly_returns(series(1.0)), bench),
        "FMCG": cs.monthly_table(cs.monthly_returns(series(1.0, extra={11: -2.0})), bench),
    }
    nov = cs.rank_by_month(tables)[11]
    assert nov[0]["sector"] == "AUTO"
    assert nov[-1]["sector"] == "FMCG"          # the month's worst is named too
    assert nov[0]["n"] >= 5


def test_coverage_reports_the_span_actually_obtained():
    rets = {"AUTO": cs.monthly_returns(series(1.0, start_year=2018, months=36))}
    cov = cs.coverage(rets)
    assert cov["first_year"] == 2018 and cov["last_year"] == 2020
    assert cov["years"] == 3
    assert cov["observations"] == 35        # 36 months -> 35 returns


def test_build_produces_the_json_the_dashboard_reads():
    data = {"_BENCH": series(1.0),
            "AUTO": series(1.0, extra={11: 4.0}),
            "IT": series(1.0, extra={7: 2.0})}
    study = cs.build(data)
    assert study["benchmark"] == cs.BENCHMARK
    assert set(study["sectors"]) == {"AUTO", "IT"}
    assert len(study["months"]) == 12
    assert study["ranked"]["11"][0]["sector"] == "AUTO"
    assert study["ranked"]["7"][0]["sector"] == "IT"
    assert study["coverage"]["years"] == 10
    json.dumps(study)          # must be serialisable as-is


def test_no_history_yields_no_false_confidence():
    study = cs.build({"_BENCH": [], "AUTO": []})
    assert study["sectors"] == []
    assert study["coverage"]["years"] == 0


def test_sector_names_match_the_rest_of_the_system():
    from garuda import macro
    known = set(cs.SECTOR_INDICES)
    for phase in macro.PHASES:
        assert macro.PHASE_SECTORS[phase] <= known
        assert macro.PHASE_AVOID[phase] <= known
