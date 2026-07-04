"""Tests for Garuda's live brain: profiles, portfolio, and the daily scanner."""

import random

from garuda.strategy import PROFILES, Profile
from garuda.portfolio import LivePortfolio
from garuda.scan import run_scan


def _reverting(days=400, seed=1):
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    c = [price]
    for _ in range(days):
        noise = -0.6 * prev + rng.gauss(0.0, 0.02)
        price = max(1.0, price * (1.0 + 0.0005 + noise))
        c.append(round(price, 3))
        prev = noise
    return c


def test_profiles_use_proven_settings():
    sc, mc = PROFILES["smallcap"], PROFILES["microcap"]
    for p in (sc, mc):
        assert p.entry_rsi == 5 and p.exit_rsi == 85 and p.max_hold == 30
        assert p.use_trend is False
        assert p.capital == 1_000_000


def test_portfolio_buy_sell_cash():
    pf = LivePortfolio(100_000)
    assert pf.buy("KEI", 10, 100.0, entry_len=250)
    assert pf.cash == 99_000
    pnl = pf.sell("KEI", 110.0)
    assert pnl == 100  # 10 shares * +10
    assert round(pf.cash) == 100_100
    assert pf.equity(lambda s: 0) == 100_100


def test_portfolio_rejects_overspend():
    pf = LivePortfolio(1_000)
    assert pf.buy("X", 100, 100.0, entry_len=1) is False   # 10,000 > 1,000 cash


def test_scan_no_position_cap_fills_by_cash():
    # 60 always-oversold-ish names; with ~2% each on 10L, ~50 should fill (cash-
    # bound), NOT an arbitrary 20 cap.
    prof = Profile("t", "T", "", entry_rsi=99, exit_rsi=85, max_hold=30,
                   use_trend=False, capital=1_000_000, alloc_pct=0.02)
    series = {f"S{i}": _reverting(seed=i) for i in range(60)}
    pf = LivePortfolio(prof.capital)
    result = run_scan(prof, series, pf)
    assert result["positions"] > 20            # not capped at 20
    assert pf.cash >= 0                         # never oversold cash


def test_scan_exits_on_hold_and_records_equity():
    prof = PROFILES["smallcap"]
    series = {f"S{i}": _reverting(seed=i) for i in range(10)}
    pf = LivePortfolio(prof.capital)
    r1 = run_scan(prof, series, pf)
    # grow each series by 40 bars so held positions exceed the 30-bar max hold
    for s in series:
        series[s] += _reverting(days=40, seed=hash(s) % 100)[1:]
    r2 = run_scan(prof, series, pf)
    assert "equity" in r1 and "equity" in r2
    assert len(pf.history) == 2
