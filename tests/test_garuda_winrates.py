"""WIN-RATE AUDIT — every win% and profit% on the dashboard, locked by test.

Per-book: win% = wins/closed SELLs (>=5 closed, else backtest fallback),
PF = gross wins / gross losses, pnl% = (equity/capital - 1).
Total: wins/closed across ALL books + settled option weeks — weighted by real
sample sizes, never by open positions, never mixing backtest into 'live'.
"""

from garuda.live import GarudaLive, _live_stats, _wins_closed
from garuda.portfolio import LivePortfolio


def _sells(*pnls):
    return [{"side": "SELL", "symbol": f"T{i}", "qty": 1, "price": 100.0,
             "pnl": p} for i, p in enumerate(pnls)]


def test_live_stats_math_and_threshold():
    pf = LivePortfolio(100000.0)
    pf.trades = _sells(10, 20, -5, -5)              # only 4 closed -> too thin
    win, pfac, n = _live_stats(pf)
    assert (win, pfac, n) == (None, None, 4)
    pf.trades = _sells(10, 20, 30, -20, -10, 6)     # 6 closed: 4W/2L
    win, pfac, n = _live_stats(pf)
    assert win == 67 and n == 6
    assert pfac == round(66 / 30, 2)                # gross 66 win / 30 loss
    pf.trades = _sells(5, 5, 5, 5, 5)               # zero losses -> PF undefined
    assert _live_stats(pf) == (100, None, 5)


def test_wins_closed_ignores_buys_and_unpriced():
    trades = _sells(10, -5) + [{"side": "BUY", "symbol": "X", "qty": 1,
                                "price": 9.0},
                               {"side": "SELL", "symbol": "Y"}]   # no pnl
    assert _wins_closed(trades) == (1, 2)
    settles = [{"side": "SETTLE", "pnl": 500.0}, {"side": "SETTLE", "pnl": -100.0}]
    assert _wins_closed(settles, sides=("SETTLE",)) == (1, 2)


def test_total_win_rate_weighted_by_sample_size():
    g = GarudaLive(csv_dir="/nonexistent")
    # book A: 10 closed, 80% win · book B: 90 closed, 40% win
    g.portfolios["smallcap"].trades = _sells(*([10] * 8 + [-10] * 2))
    g.portfolios["crash"].trades = _sells(*([10] * 36 + [-10] * 54))
    # + 3 settled option weeks, 2 wins
    g.options.trades = [{"side": "SETTLE", "pnl": 900.0},
                        {"side": "SETTLE", "pnl": 800.0},
                        {"side": "SETTLE", "pnl": -1500.0},
                        {"side": "OPEN", "spot": 24000.0}]        # OPEN ignored
    st = g.build_state()
    t = st["totals"]
    # (8 + 36 + 2) wins / (10 + 90 + 3) closed = 46/103 = 44.66 -> 45
    assert t["win_n"] == 103
    assert t["win"] == 45
    # a naive positions-weighted or simple average would say ~60 — locked out
    sc = next(p for p in st["profiles"] if p["key"] == "smallcap")
    assert sc["win"] == 80 and sc["win_kind"] == "live" and sc["win_n"] == 10
    cr = next(p for p in st["profiles"] if p["key"] == "crash")
    assert cr["win"] == 40 and cr["win_kind"] == "live"


def test_total_win_needs_five_closed():
    g = GarudaLive(csv_dir="/nonexistent")
    g.portfolios["smallcap"].trades = _sells(10, -5, 8)           # only 3 closed
    t = g.build_state()["totals"]
    assert t["win"] is None and t["win_n"] == 3


def test_book_profit_percent_and_win_open():
    g = GarudaLive(csv_dir="/nonexistent")
    pf = g.portfolios["leaders"]
    pf.buy("AAA", 100, 500.0, entry_len=300)        # cost 50,000
    pf.buy("BBB", 100, 300.0, entry_len=300)        # cost 30,000
    g.prices = {"AAA": 550.0, "BBB": 290.0}         # +5,000 / -1,000
    st = g.build_state()
    ld = next(p for p in st["profiles"] if p["key"] == "leaders")
    # equity = 920,000 cash + 55,000 + 29,000 = 1,004,000 -> +0.40%
    assert ld["equity"] == 1_004_000
    assert abs(ld["pnl_pct"] - 0.40) < 1e-9
    assert ld["win_open"] == 50                     # 1 of 2 open positions green
    # totals profit % consistent with summed equities over summed capitals
    t = st["totals"]
    assert abs(t["pnl_pct"] - (t["equity"] / t["capital"] - 1) * 100) < 0.01


def test_size_categories():
    """LARGE top-100, MID to 250, SMALL to 500, MICRO beyond — the buckets the
    dashboard uses to answer 'how many large caps does this book hold?'."""
    from garuda.live import _size_cat
    assert _size_cat(1) == "L" and _size_cat(100) == "L"
    assert _size_cat(101) == "M" and _size_cat(250) == "M"
    assert _size_cat(251) == "S" and _size_cat(500) == "S"
    assert _size_cat(501) == "µ" and _size_cat(1500) == "µ"
    assert _size_cat(None) is None
