"""Tests for Garuda — the fast Markov next-move model. All offline/synthetic."""

from garuda import data
from garuda.markov import MarkovPredictor
from garuda.backtest import run


# --- Markov predictor learns transition frequencies ------------------------

def test_predictor_learns_direction():
    p = MarkovPredictor(order=3)
    for _ in range(20):
        p.update([1, 1, 1], up=True)     # after (1,1,1), it kept going up
    assert p.prob_up([1, 1, 1]) > 0.9
    assert p.prob_up([0, 0, 0]) == 0.5   # unseen -> neutral


def test_predictor_neutral_when_state_too_short():
    p = MarkovPredictor(order=3)
    assert p.prob_up([1, 1]) == 0.5


# --- backtest plumbing ------------------------------------------------------

def test_backtest_runs_on_synthetic():
    prices = data.synthetic_series(n=1000, seed=3)
    r = run(prices, warmup=100)
    assert r["bars"] == 1000
    assert r["trades"] >= 0
    assert "total_return_pct" in r and "buyhold_return_pct" in r
    assert "verdict" in r


def test_backtest_finds_edge_on_a_predictable_series():
    # A strictly alternating up/down series is perfectly Markov-predictable, and
    # the moves (±~1%) are far bigger than costs — so after warmup the model
    # should short before the down bar / go long before the up bar and net > 0.
    prices = [100.0]
    for i in range(600):
        prices.append(round(prices[-1] * (1.01 if i % 2 == 0 else 1 / 1.01), 4))
    r = run(prices, order=3, warmup=30, cost=0.0003, min_edge=0.05)
    assert r["trades"] > 0
    assert r["total_return_pct"] > 0          # a real edge clears the costs
    assert r["win_rate_pct"] and r["win_rate_pct"] > 80


def test_costs_make_a_difference():
    prices = data.synthetic_series(n=800, seed=11)
    cheap = run(prices, warmup=100, cost=0.0)
    dear = run(prices, warmup=100, cost=0.002)
    # higher costs can never improve the net return
    assert dear["total_return_pct"] <= cheap["total_return_pct"] + 1e-9


# --- CSV loader -------------------------------------------------------------

def test_csv_loader(tmp_path):
    p = tmp_path / "bars.csv"
    p.write_text("Date,Close\n2026-07-01,100.5\n2026-07-01,101.0\nbad,notnum\n")
    series = data.load_csv_series(p)
    assert series == [100.5, 101.0]
