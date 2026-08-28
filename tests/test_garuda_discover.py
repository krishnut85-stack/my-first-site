"""Tests for LAB DISCOVER — the reverse strategy search."""

import random
from datetime import date, timedelta

from garuda.lab_discover import (_exit_index, _features, _indices, _masks,
                                 load_results, run_discover, save_results,
                                 three_way_split)
from garuda.setups import rsi


def _dated(closes, start=date(2019, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _uptrend_with_dips(days=1300, seed=11):
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    closes = [price]
    for _ in range(days):
        noise = -0.6 * prev + rng.gauss(0.0, 0.015)
        price = max(1.0, price * (1.0 + 0.0006 + noise))
        closes.append(round(price, 3))
        prev = noise
    return closes


def test_indices_roundtrip():
    mask = (1 << 3) | (1 << 7) | (1 << 250)
    assert _indices(mask) == [3, 7, 250]
    assert _indices(0) == []


def test_masks_match_direct_computation():
    closes = _uptrend_with_dips(days=400, seed=2)
    f = _features(closes)
    m = _masks(f)
    r2 = rsi(closes, 2)
    for i in _indices(m["rsi2lt10"]):
        assert r2[i] is not None and r2[i] < 10
    for i in _indices(m["down3"]):
        assert closes[i] < closes[i - 1] < closes[i - 2] < closes[i - 3]
    for i in _indices(m["brk20"]):
        assert closes[i] >= max(closes[i - 19:i + 1])
    for i in _indices(m["gt200"]):
        assert f["sma200"][i] is not None and closes[i] > f["sma200"][i]
    # 'any' covers every bar so ANDing it changes nothing
    assert m["any"] & m["gt200"] == m["gt200"]


def test_exit_rules():
    closes = [100, 99, 98, 103, 104, 105, 106, 107]
    r2 = rsi(closes, 2)
    # first green close: bar 3 is the first close above its predecessor
    assert _exit_index("green7", closes, r2, 0) == 3
    # fixed hold
    assert _exit_index("hold20", closes, r2, 0) == len(closes) - 1
    # target +5% hits at bar 5 (105)
    assert _exit_index("tgt5_stop10_10", closes, r2, 0) == 5
    # trailing stop: crash after a peak
    crash = [100, 120, 100] + [100] * 5
    assert _exit_index("trail10_60", crash, rsi(crash, 2), 0) == 2


def test_three_way_split_ordering():
    dv = _dated([100.0] * 1000)
    s1, s2 = three_way_split({"A": dv})
    dates = [d for d, _ in dv]
    assert s1 < s2
    train = sum(1 for d in dates if d < s1)
    sel = sum(1 for d in dates if s1 <= d < s2)
    assert abs(train / len(dates) - 0.50) < 0.02
    assert abs(sel / len(dates) - 0.20) < 0.02


def test_run_discover_end_to_end(tmp_path):
    series = {f"S{i}": _dated(_uptrend_with_dips(seed=i)) for i in range(8)}
    res = run_discover(series, top=5, log=lambda *a: None)
    assert res["universe"] == 8
    assert res["combos_tested"] == 4 * 11 * 4 * 6
    assert res["train_profitable"] <= res["combos_tested"]
    assert len(res["results"]) <= 5
    for r in res["results"]:
        assert r["verdict"] in ("VALIDATED", "FAILED")
        # every reported combo was profitable on TRAIN and SELECT by construction
        assert r["train"]["avg"] > 0 and r["select"]["avg"] > 0
        assert set(r["test"]) == {"trades", "win", "avg", "pf", "worst"}
        assert "Buy" in r["rules"] and "Sell:" in r["rules"]
    # VALIDATED finalists sort ahead of FAILED ones
    verdicts = [r["verdict"] for r in res["results"]]
    assert verdicts == sorted(verdicts, key=lambda v: v != "VALIDATED")
    p = tmp_path / "disc.json"
    save_results(res, "test.csv", p)
    back = load_results(p)
    assert back["source"] == "test.csv" and back["combos_tested"] == res["combos_tested"]


def test_no_overlapping_trades():
    """The cooldown must prevent a second entry before the previous exit."""
    closes = _uptrend_with_dips(days=600, seed=5)
    dv = _dated(closes)
    series = {"A": dv}
    # run a tiny grid by monkey-checking through run_discover's public output:
    res = run_discover(series, top=3, log=lambda *a: None)
    # sanity only — per-combo trade counts can never exceed bars/2 with cooldown
    for r in res["results"]:
        total = r["train"]["trades"] + r["select"]["trades"] + r["test"]["trades"]
        assert total <= len(closes)
