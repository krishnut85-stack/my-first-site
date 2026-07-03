"""Tests for the cross-sectional 'rank all stocks, pick some' backtest.

We build a synthetic universe with a KNOWN mean-reversion edge (yesterday's
losers bounce). The backtest must then show reversion beating momentum — proving
it measures the fork honestly rather than just printing a pretty number."""

import random

from garuda.cross import run_cross, load_panel


def _mean_reverting_panel(symbols=20, days=1500, seed=5):
    """Each stock has negative return autocorrelation, so a down day tends to be
    followed by an up day — a textbook mean-reversion universe."""
    rng = random.Random(seed)
    panel = {}
    for k in range(symbols):
        prev_r = 0.0
        price = 100.0
        closes = [price]
        for _ in range(days):
            r = -0.5 * prev_r + rng.gauss(0.0, 0.01)   # negative autocorrelation
            price = max(1.0, price * (1.0 + r))
            closes.append(round(price, 3))
            prev_r = r
        panel[f"S{k}"] = closes
    return panel


def test_reversion_beats_momentum_on_reverting_universe():
    panel = _mean_reverting_panel()
    rev = run_cross(panel, mode="reversion", pick=5, cost_per_side=0.0)
    mom = run_cross(panel, mode="momentum", pick=5, cost_per_side=0.0)
    # the constructed edge is reversion, so it must win clearly...
    assert rev["total_return_pct"] > mom["total_return_pct"]
    # ...and be profitable before costs, with an above-coin-flip hit rate
    assert rev["total_return_pct"] > 0
    assert rev["win_rate_pct"] > 50


def test_costs_can_flip_a_thin_edge():
    panel = _mean_reverting_panel()
    free = run_cross(panel, mode="reversion", pick=5, cost_per_side=0.0)
    dear = run_cross(panel, mode="reversion", pick=5, cost_per_side=0.02)
    # heavy costs can only reduce the net return, never improve it
    assert dear["total_return_pct"] < free["total_return_pct"]


def test_reports_win_rate_but_verdict_uses_net():
    panel = _mean_reverting_panel()
    r = run_cross(panel, mode="momentum", pick=5, cost_per_side=0.02)
    assert "win_rate_pct" in r
    # momentum on a reverting universe + heavy costs must lose, whatever the win
    # rate — the verdict is driven by net return, not the vanity metric
    assert r["total_return_pct"] < 0
    assert "LOSING" in r["verdict"] or "WEAK" in r["verdict"]


def test_load_panel(tmp_path):
    p = tmp_path / "daily.csv"
    p.write_text("date,AAA,BBB\n2026-07-01,100,200\n2026-07-02,101,199\n"
                 "2026-07-03,bad,198\n")   # last row dropped (non-numeric)
    panel = load_panel(p)
    assert panel["AAA"] == [100.0, 101.0]
    assert panel["BBB"] == [200.0, 199.0]
