"""Which stocks inside a winning industry run — the study, not the assumption."""

import pytest

from garuda import stock_pick_study as sp


def _bars(monthly, days=20, start=100.0):
    """Daily bars whose every month compounds to the given percent return."""
    rows, lvl = [], start
    for m, pct in monthly:
        step = (1 + pct / 100.0) ** (1.0 / days)
        for d in range(days):
            lvl *= step
            rows.append({"t": f"{m}-{d + 1:02d}", "c": round(lvl, 4)})
    return rows


@pytest.fixture
def cache(monkeypatch):
    store = {}
    monkeypatch.setattr(sp, "load_stock", lambda s: store.get(s, []))
    return store


def _months(n, y=2010):
    return [f"{y + i // 12:04d}-{i % 12 + 1:02d}" for i in range(n)]


def test_a_month_with_too_few_trading_days_is_not_a_month(cache):
    cache["THIN"] = _bars([(m, 2.0) for m in _months(30)], days=3)
    cache["FULL"] = _bars([(m, 2.0) for m in _months(30)], days=20)
    out = sp.stock_monthly_returns(["THIN", "FULL"])
    assert "THIN" not in out          # 3-day months are all discarded
    assert len(out["FULL"]) == 30


def test_a_split_costs_one_day_not_the_whole_month(cache):
    rows = _bars([(m, 1.0) for m in _months(30)])
    rows[400]["c"] = rows[400]["c"] / 2      # a 1:2 split mid-series
    for r in rows[401:]:
        r["c"] = r["c"] / 2
    cache["SPLIT"] = rows
    out = sp.stock_monthly_returns(["SPLIT"])
    hit = out["SPLIT"][sorted(out["SPLIT"])[20]]
    assert hit > -5.0, hit            # not the -50% a close-to-close read gives


def test_a_stock_with_too_little_history_never_enters_a_basket(cache):
    cache["NEW"] = _bars([(m, 3.0) for m in _months(12)])
    assert "NEW" not in sp.stock_monthly_returns(["NEW"])


def test_leaders_and_laggards_choose_opposite_ends(cache):
    months = _months(40)
    rets = {"RUNNER": {m: 5.0 for m in months},
            "MIDDLE": {m: 1.0 for m in months},
            "SLEEPER": {m: -1.0 for m in months}}
    mem = ["RUNNER", "MIDDLE", "SLEEPER"]
    lead = sp.pick_stocks(rets, mem, 30, months, 6, "leaders", 1)
    lag = sp.pick_stocks(rets, mem, 30, months, 6, "laggards", 1)
    every = sp.pick_stocks(rets, mem, 30, months, 6, "all", 1)
    assert lead == ["RUNNER"] and lag == ["SLEEPER"]
    assert sorted(every) == sorted(mem)


def test_asking_for_more_stocks_than_exist_returns_what_there_is(cache):
    months = _months(40)
    rets = {"A": {m: 2.0 for m in months}, "B": {m: 1.0 for m in months}}
    assert sorted(sp.pick_stocks(rets, ["A", "B"], 30, months, 6,
                                 "leaders", 5)) == ["A", "B"]


def test_the_backtest_holds_the_leaders_when_leaders_keep_leading():
    months = _months(60)
    stock_rets = {"RUN": {m: 4.0 for m in months},
                  "LAG": {m: 0.5 for m in months},
                  "OTH": {m: 0.2 for m in months}}
    ind = {"IND": {m: 1.5 for m in months}, "X": {m: 0.1 for m in months}}
    mem = {"IND": ["RUN", "LAG"], "X": ["OTH"]}
    lead = sp.stats(sp.backtest_stocks(ind, stock_rets, mem, months, 6, 6, 1,
                                       "leaders", 1))
    lag = sp.stats(sp.backtest_stocks(ind, stock_rets, mem, months, 6, 6, 1,
                                      "laggards", 1))
    both = sp.stats(sp.backtest_stocks(ind, stock_rets, mem, months, 6, 6, 1,
                                       "all", 0))
    assert lead["cagr"] > both["cagr"] > lag["cagr"]


def test_compare_scores_every_rule_on_both_halves():
    months = _months(120)
    stock_rets = {s: {m: 1.0 for m in months} for s in ("A", "B", "C", "D")}
    ind = {"I1": {m: 1.0 for m in months}, "I2": {m: 0.5 for m in months}}
    mem = {"I1": ["A", "B"], "I2": ["C", "D"]}
    rows, past, unseen = sp.compare(ind, stock_rets, mem, months, 6, 6, 1)
    assert [(r["mode"], r["n"]) for r in rows] == [
        ("all", 0),
        ("leaders", 2), ("leaders", 3), ("leaders", 0.5), ("leaders", 0.34),
        ("laggards", 2), ("laggards", 3), ("laggards", 0.5),
        ("laggards", 0.34)]
    assert past and unseen and not set(past) & set(unseen)


def test_a_fraction_scales_with_the_industry_but_a_count_does_not(cache):
    """The reason the study reports both. When Iron & Steel goes from 4 members
    to 88, "top 2" becomes a completely different bet; "top half" does not."""
    months = _months(40)
    small = [f"S{i}" for i in range(4)]
    big = [f"B{i}" for i in range(88)]
    rets = {s: {m: float(i) for m in months}
            for i, s in enumerate(small + big)}
    assert len(sp.pick_stocks(rets, small, 30, months, 6, "leaders", 2)) == 2
    assert len(sp.pick_stocks(rets, big, 30, months, 6, "leaders", 2)) == 2
    assert len(sp.pick_stocks(rets, small, 30, months, 6, "leaders", 0.5)) == 2
    assert len(sp.pick_stocks(rets, big, 30, months, 6, "leaders", 0.5)) == 44


def test_a_fraction_never_rounds_an_industry_down_to_nothing(cache):
    months = _months(40)
    rets = {s: {m: 1.0 for m in months} for s in ("A", "B")}
    assert len(sp.pick_stocks(rets, ["A", "B"], 30, months, 6,
                              "leaders", 0.1)) == 1
