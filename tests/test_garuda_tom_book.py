"""Tests for SANKRANTI — the turn-of-month book (10th book)."""

from datetime import date

from garuda.portfolio import LivePortfolio
from garuda.scan import _run_tom, _tom_phase
from garuda.strategy import PROFILES


def test_tom_profile_uses_validated_settings():
    p = PROFILES["tom"]
    assert p.strategy == "tom"
    assert p.daily_csv == "strength_daily.csv"
    assert p.capital == 1_000_000 and p.alloc_pct == 0.02
    assert p.max_hold == 8                       # safety net only
    assert "Sankranti" in p.label and "month" in p.rules


def test_tom_phase_calendar():
    # September 2025: weekdays only, no holidays passed.
    # Last trading day = Tue 30th; 3rd-to-last = Fri 26th.
    assert _tom_phase(date(2025, 9, 26)) == "BUY"
    assert _tom_phase(date(2025, 9, 29)) is None       # 2nd-to-last: no action
    assert _tom_phase(date(2025, 9, 30)) is None       # last day: no action
    # New month: trading days 1(Mon Sep 1)... for October: Wed 1, Thu 2, Fri 3
    assert _tom_phase(date(2025, 10, 1)) is None       # 1st trading day
    assert _tom_phase(date(2025, 10, 2)) is None       # 2nd
    assert _tom_phase(date(2025, 10, 3)) == "SELL"     # 3rd -> exit day
    assert _tom_phase(date(2025, 10, 6)) == "SELL"     # still sell window
    assert _tom_phase(date(2025, 10, 4)) is None       # Saturday
    # a holiday shifts the count: make Oct 2 a holiday -> 3rd TD becomes Oct 6
    hol = {"2025-10-02"}
    assert _tom_phase(date(2025, 10, 3), hol) is None
    assert _tom_phase(date(2025, 10, 6), hol) == "SELL"
    # mid-month and late-month days are quiet — the sell window is bounded, so
    # positions bought 3 days BEFORE month-end are never dumped early
    assert _tom_phase(date(2025, 10, 15)) is None
    assert _tom_phase(date(2025, 10, 28)) is None      # buy day is 10-29


def test_tom_buys_on_buy_day_and_exits_on_sell_day(monkeypatch):
    p = PROFILES["tom"]
    series = {f"S{i}": [100.0] * 80 for i in range(60)}
    pf = LivePortfolio(p.capital)

    class FakeDate(date):
        _today = date(2025, 9, 26)                     # the BUY day

        @classmethod
        def today(cls):
            return cls._today

    monkeypatch.setattr("garuda.scan.date", FakeDate, raising=False)
    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    monkeypatch.setattr("garuda.market.HOLIDAYS", set())
    res = _run_tom(p, series, pf)
    assert len(res["buys"]) >= 45                      # ~50 names, cash-limited
    assert pf.cash < p.capital * 0.05
    # sell day: everything exits together
    FakeDate._today = date(2025, 10, 3)
    for h in pf.holdings.values():                     # not entered today
        h["entry_date"] = "2025-09-26"
    res2 = _run_tom(p, series, pf, live_prices={s: 102.0 for s in series})
    assert not pf.holdings
    assert all(s["reason"] == "month-turn exit" for s in res2["sells"])
    assert all(s["pnl"] > 0 for s in res2["sells"])    # sold at 102 vs 100 entry


def test_tom_quiet_midmonth(monkeypatch):
    p = PROFILES["tom"]
    pf = LivePortfolio(p.capital)

    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2025, 10, 15)                  # mid-month, no holdings

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    res = _run_tom(p, {f"S{i}": [100.0] * 80 for i in range(10)}, pf)
    assert res["buys"] == [] and res["sells"] == []
    assert pf.cash == p.capital
