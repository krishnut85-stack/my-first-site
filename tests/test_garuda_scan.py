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
        assert p.entry_rsi == 10 and p.exit_rsi == 85 and p.max_hold == 30
        assert p.strategy == "rsi2"
        assert p.use_trend is True          # the uptrend filter is now ON (the showdown winner)
        assert p.label and p.capital == 1_000_000
    n50 = PROFILES["next50"]
    assert n50.strategy == "momentum"       # Next 50 runs breakout + trailing stop
    assert n50.breakout == 20 and n50.trail == 0.15 and n50.max_hold == 120
    assert n50.label


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
    prof = Profile("t", "T", "", "", entry_rsi=99, exit_rsi=85, max_hold=30,
                   use_trend=False, capital=1_000_000, alloc_pct=0.02)
    series = {f"S{i}": _reverting(seed=i) for i in range(60)}
    pf = LivePortfolio(prof.capital)
    result = run_scan(prof, series, pf)
    assert result["positions"] > 20            # not capped at 20
    assert pf.cash >= 0                         # never oversold cash


def test_scan_exits_on_max_hold():
    prof = PROFILES["smallcap"]
    series = {f"S{i}": _reverting(seed=i) for i in range(6)}
    pf = LivePortfolio(prof.capital)
    run_scan(prof, series, pf)                      # open some positions
    assert pf.holdings
    # make a holding look long-held (past max_hold), from an old scan date
    for h in pf.holdings.values():
        h["bars_held"] = prof.max_hold
        h["last_date"] = "2000-01-01"
    r = run_scan(prof, series, pf)                  # today's scan bumps it over -> exit
    assert r["sells"], "a maxed-out hold should be sold"


def _rising(days=60, start=100.0, step=1.0):
    return [start + i * step for i in range(days)]


def test_momentum_enters_on_breakout_and_trails_out():
    prof = PROFILES["next50"]                       # the momentum book
    pf = LivePortfolio(prof.capital)
    series = {"AAA": _rising(60)}                    # steady climb, last=159
    # a live price above every prior close = a fresh 20-day high -> breakout entry
    r = run_scan(prof, series, pf, live_prices={"AAA": 200.0})
    assert r["buys"] and "AAA" in pf.holdings
    assert pf.holdings["AAA"]["peak"] == 200.0       # peak seeded at entry
    # price gives back >15% off the 200 peak (160 < 170) -> trailing-stop exit
    r2 = run_scan(prof, series, pf, live_prices={"AAA": 160.0})
    assert r2["sells"] and "trailing stop" in r2["sells"][0]["reason"]
    assert "AAA" not in pf.holdings


def test_momentum_holds_while_above_trailing_stop():
    prof = PROFILES["next50"]
    pf = LivePortfolio(prof.capital)
    series = {"AAA": _rising(60)}
    run_scan(prof, series, pf, live_prices={"AAA": 200.0})
    # a shallow pullback (5% < 15% trail) must NOT stop us out
    r = run_scan(prof, series, pf, live_prices={"AAA": 190.0})
    assert not r["sells"] and "AAA" in pf.holdings
    assert pf.holdings["AAA"]["peak"] == 200.0       # peak unchanged by a dip


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
