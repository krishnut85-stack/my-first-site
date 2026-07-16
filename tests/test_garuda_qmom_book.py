"""Tests for QMOM — the SCREEN LAB winner, live as an annual rotation book."""

from datetime import date

from garuda.portfolio import LivePortfolio
from garuda.scan import _qmom_window, _run_qmom, run_scan
from garuda.strategy import PROFILES


def _runner(mult, days=260):
    """A stock that multiplied `mult`x over the period (steady daily growth)."""
    g = mult ** (1.0 / days)
    return [round(100.0 * g ** i, 3) for i in range(days + 1)]


def _fund(good=True):
    """Quality-screen fundamentals: NP +50% / Rev +20% when good."""
    if good:
        return {("np", 0): 150.0, ("np", 1): 100.0,
                ("rev", 0): 1200.0, ("rev", 1): 1000.0}
    return {("np", 0): 105.0, ("np", 1): 100.0,          # +5% — fails the bar
            ("rev", 0): 1050.0, ("rev", 1): 1000.0}


def test_qmom_profile():
    p = PROFILES["qmom"]
    assert p.strategy == "qmom"
    assert p.daily_csv == "strength_daily.csv"           # shared universe
    assert p.capital == 1_000_000
    assert p.mom_days == 189
    assert "quality" in p.rules.lower() and "July" in p.rules
    assert len(PROFILES) == 10                           # the 11th seat is taken


def test_qmom_window_first_three_july_trading_days():
    assert _qmom_window(date(2026, 7, 1))                # Wed
    assert _qmom_window(date(2026, 7, 3))                # Fri, 3rd trading day
    assert not _qmom_window(date(2026, 7, 6))            # 4th trading day
    assert not _qmom_window(date(2026, 7, 4))            # Saturday
    assert not _qmom_window(date(2026, 6, 1))            # not July
    assert not _qmom_window(date(2026, 10, 1))           # chakra's day, not ours


def test_qmom_bootstrap_buys_quality_and_momentum(monkeypatch):
    """First spin: only quality-passing names in the top-30% momentum get
    bought, equal weight — junk momentum and slow quality both stay out."""
    p = PROFILES["qmom"]
    # 20 stocks with rising momentum; only the strongest are top-30%
    series = {f"S{i:02d}": _runner(1.0 + i * 0.08) for i in range(20)}
    fund = {f"S{i:02d}": _fund(good=(i in (18, 19, 2))) for i in range(20)}
    pf = LivePortfolio(p.capital)

    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2026, 3, 10)                     # mid-March: bootstrap

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    res = _run_qmom(p, series, pf, fundamentals=fund)
    bought = {b["symbol"] for b in res["buys"]}
    assert bought == {"S18", "S19"}       # quality AND top-30% momentum
    # S02 is quality but slow (bottom momentum); S17 is fast but low-quality
    assert "S02" not in bought and "S17" not in bought
    # equal weight: both slices within a share's width of each other
    vals = [h["qty"] * series[s][-1] for s, h in pf.holdings.items()]
    assert abs(vals[0] - vals[1]) < max(series["S18"][-1], series["S19"][-1])
    # idempotent within the same month
    res2 = _run_qmom(p, series, pf, fundamentals=fund)
    assert res2["buys"] == [] and res2["sells"] == []


def test_qmom_july_rotation_sells_dropped_names(monkeypatch):
    p = PROFILES["qmom"]
    series = {f"S{i:02d}": _runner(1.0 + i * 0.08) for i in range(20)}
    fund = {f"S{i:02d}": _fund(good=(i >= 18)) for i in range(20)}
    pf = LivePortfolio(p.capital)
    # held since last July: one name that will fail this year's screen
    pf.buy("S05", 100, 50.0, entry_len=200)
    pf.holdings["S05"]["entry_date"] = "2025-07-01"
    pf.trades.append({"side": "BUY", "symbol": "S05"})   # not a bootstrap book

    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2026, 7, 1)

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    monkeypatch.setattr("garuda.market.HOLIDAYS", set())
    res = _run_qmom(p, series, pf, fundamentals=fund)
    assert any(s["symbol"] == "S05" for s in res["sells"])   # rotated out
    assert {b["symbol"] for b in res["buys"]} == {"S18", "S19"}


def test_qmom_no_fundamentals_holds_quietly(monkeypatch):
    """Missing screen file -> no rotation, no panic sell: hold what we have."""
    p = PROFILES["qmom"]
    series = {"S00": _runner(1.5)}
    pf = LivePortfolio(p.capital)
    pf.buy("S00", 10, 100.0, entry_len=200)

    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2026, 7, 1)

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    monkeypatch.setattr("garuda.market.HOLIDAYS", set())
    res = _run_qmom(p, series, pf, fundamentals={})
    assert res["buys"] == [] and res["sells"] == []
    assert "S00" in pf.holdings


def test_fundamentals_found_from_repo_root(monkeypatch):
    """Regression: BASE_DIR is the garuda/ package, but the screen file lives
    at <repo>/scripts/screen_wide.csv — the loader must find it (this exact
    miss left the live book holding nothing on 2026-07-15)."""
    from garuda.scan import _load_qmom_fundamentals
    monkeypatch.delenv("QMOM_SCREEN", raising=False)
    fund = _load_qmom_fundamentals(cache={})
    assert fund, "scripts/screen_wide.csv not found from the package path"
    assert "RELIANCE" in fund and ("np", 0) in fund["RELIANCE"]


def test_run_scan_dispatches_qmom(monkeypatch):
    p = PROFILES["qmom"]
    monkeypatch.setenv("QMOM_SCREEN", "/nonexistent.csv")

    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2026, 5, 5)

    import datetime as _dt
    monkeypatch.setattr(_dt, "date", FakeDate)
    res = run_scan(p, {"S00": _runner(1.4)}, LivePortfolio(p.capital))
    assert res["profile"] == "Garuda-QM"
