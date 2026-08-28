"""Tests for the Iron Condor options-income backtest."""

import random
from datetime import date, timedelta

from garuda.options import (backtest_condor, compare_condor, _condor_stats,
                            _next_thursday, OptionsBook)


def _index_path(days=800, weekly_vol=0.02, seed=1):
    rng = random.Random(seed)
    dvol = weekly_vol / (5 ** 0.5)          # daily vol from weekly
    px, c = 20000.0, [20000.0]
    for _ in range(days):
        px = px * (1 + rng.gauss(0.0003, dvol))
        c.append(round(px, 2))
    return c


def test_wider_strikes_raise_win_rate():
    c = _index_path()
    narrow = _condor_stats(backtest_condor(c, 0.010, 0.01, 0.30))
    wide = _condor_stats(backtest_condor(c, 0.030, 0.01, 0.30))
    # selling further out-of-the-money = the index breaches less often
    assert wide["win"] > narrow["win"]
    assert wide["win"] >= 80          # ~1.5-sigma weekly strikes -> high win rate


def test_condor_payoff_is_bounded():
    c = _index_path(seed=7)
    trades = backtest_condor(c, 0.015, 0.01, 0.30)
    # every week's loss is capped by the wing (defined risk) — never a blow-up
    assert trades and min(trades) >= -0.01           # worst week <= the 1% wing
    assert max(trades) <= 0.30 * 0.01 + 1e-9         # best week = the credit


def test_compare_condor_sweeps_distances():
    res = compare_condor(_index_path())
    assert len(res) == 5
    assert all(s and s["weeks"] > 0 for s in res.values())


def test_next_thursday_is_strictly_after():
    thu = date(2026, 1, 8)                       # a Thursday
    assert thu.weekday() == 3
    assert _next_thursday(thu) == date(2026, 1, 15)     # rolls to NEXT Thursday, not same day
    wed = date(2026, 1, 7)
    assert _next_thursday(wed) == date(2026, 1, 8)      # nearest upcoming Thursday


def test_options_book_flat_market_collects_credit():
    b = OptionsBook(capital=1_000_000.0, dist=0.025, wing=0.01, credit_frac=0.30,
                    alloc_pct=0.02)
    d, spot = date(2026, 1, 1), 20000.0
    for i in range(40):                          # ~8 weekly cycles, index barely moves
        b.step(spot, d, market_open=True)
        d += timedelta(days=1)
        spot *= 1.0 + 0.001 * ((i % 3) - 1)      # tiny chop, stays inside +/-2.5%
    st = b.state(spot)
    assert st["realized"] > 0                     # index stayed in range -> net credit
    assert st["equity"] > b.starting_capital
    assert st["strikes"]["sp"] < st["spot"] < st["strikes"]["sc"]   # currently in range


def test_options_book_loss_is_capped_at_week_risk():
    b = OptionsBook(capital=1_000_000.0, dist=0.025, wing=0.01, credit_frac=0.30,
                    alloc_pct=0.02)
    b.step(20000.0, date(2026, 1, 1), market_open=True)      # open a condor
    risk = 1_000_000.0 * 0.02
    # index rockets 50% -> both spreads fully breached, but the wing caps the loss
    blowup = b._pnl_rupees(b._net_frac(30000.0))
    assert abs(blowup + risk) < 1.0               # loss == the defined week risk, no blow-up
    win = b._pnl_rupees(b._net_frac(20000.0))     # settles in range -> full credit
    assert 0 < win < risk


def test_options_book_market_closed_is_a_noop():
    b = OptionsBook()
    b.step(20000.0, date(2026, 1, 1), market_open=False)
    assert b.condor is None and not b.trades      # nothing opens while the market is shut


def test_options_book_save_load_roundtrip(tmp_path):
    b = OptionsBook(capital=500_000.0, dist=0.03)
    b.step(18000.0, date(2026, 1, 1), market_open=True)
    b.realized = 1234.0
    p = tmp_path / "options.json"
    b.save(str(p))
    b2 = OptionsBook.load(str(p))
    assert b2.starting_capital == 500_000.0 and b2.dist == 0.03
    assert b2.realized == 1234.0 and b2.condor == b.condor
