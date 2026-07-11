"""Tests for CHAKRA — the tournament-winning monthly rotation book (seat 10)."""

from datetime import date

from garuda.portfolio import LivePortfolio
from garuda.scan import _chakra_window, _run_chakra
from garuda.strategy import PROFILES


def _runner(mult, days=260):
    """A stock that multiplied `mult`x over the period (steady daily growth)."""
    g = mult ** (1.0 / days)
    return [round(100.0 * g ** i, 3) for i in range(days + 1)]


def test_chakra_profile():
    p = PROFILES["chakra"]
    assert p.strategy == "chakra"
    assert p.mom_days == 126 and p.trend_ma == 200 and p.max_units == 20
    assert p.daily_csv == "strength_daily.csv"
    assert p.capital == 1_000_000
    assert "rotate" in p.rules
    assert "tom" not in PROFILES                       # Sankranti retired


def test_chakra_window_first_three_trading_days():
    # October 2025: Wed 1, Thu 2, Fri 3 are the first three trading days
    assert _chakra_window(date(2025, 10, 1))
    assert _chakra_window(date(2025, 10, 3))
    assert not _chakra_window(date(2025, 10, 6))       # 4th trading day
    assert not _chakra_window(date(2025, 10, 4))       # Saturday
    assert not _chakra_window(date(2025, 10, 15))      # mid-month
    # a holiday on Oct 1 shifts the window to 2/3/6
    hol = {"2025-10-01"}
    assert _chakra_window(date(2025, 10, 6), hol)


def test_chakra_rotates_into_top_momentum(monkeypatch):
    p = PROFILES["chakra"]
    # 30 stocks with distinct momentum; the strongest 20 must be bought
    series = {f"S{i:02d}": _runner(1.1 + i * 0.05) for i in range(30)}
    pf = LivePortfolio(p.capital)

    class FakeDate(date):
        _d = date(2025, 10, 1)

        @classmethod
        def today(cls):
            return cls._d

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    monkeypatch.setattr("garuda.market.HOLIDAYS", set())
    res = _run_chakra(p, series, pf)
    assert len(res["buys"]) == 20
    bought = {b["symbol"] for b in res["buys"]}
    assert bought == {f"S{i:02d}" for i in range(10, 30)}   # the 20 strongest
    # re-running inside the window is idempotent (already rotated this month)
    res2 = _run_chakra(p, series, pf)
    assert res2["buys"] == [] and res2["sells"] == []
    # mid-month: nothing happens
    FakeDate._d = date(2025, 10, 15)
    res3 = _run_chakra(p, series, pf)
    assert res3["buys"] == [] and res3["sells"] == []
    # next month: a faded leader rotates out, a new one rotates in
    FakeDate._d = date(2025, 11, 3)                    # Mon = 1st trading day
    for h in pf.holdings.values():
        h["entry_date"] = "2025-10-01"                 # aged into last month
    faded = {s: list(c) for s, c in series.items()}
    faded["S29"] = [100.0] * 261                       # champion goes flat
    res4 = _run_chakra(p, faded, pf)
    assert any(s["symbol"] == "S29" for s in res4["sells"])
    assert any(b["symbol"] == "S09" for b in res4["buys"])  # next-best steps in
