"""Tests for LAB MOVERS — the big-move precursor hunter."""

import random
from datetime import date, timedelta

from garuda.lab_movers import (PRECURSORS, _event_stats, _window_stats,
                               load_results, run_movers, save_results,
                               scan_today)


def _dated(closes, start=date(2019, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _series(days=900, seed=3):
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    closes = [price]
    for _ in range(days):
        noise = -0.5 * prev + rng.gauss(0.0, 0.02)
        price = max(1.0, price * (1.0 + 0.0005 + noise))
        closes.append(round(price, 3))
        prev = noise
    return closes


def test_event_stats_hit_and_cooldown():
    #                0    1    2      3      4    5    6
    closes = [100, 101, 112, 100, 100, 100, 100]
    dates = [f"d{i}" for i in range(len(closes))]
    out = {"train": [], "select": [], "test": []}
    # split dates chosen so everything lands in train ("d9" > all)
    _event_stats(dates, closes, [0, 1, 2], pop=0.10, horizon=5, cost=0.001,
                 s1="d9", s2="d9x", out=out)
    # entry 0: close 112 at bar 2 = +12% -> hit, exits at bar 2. Cooldown eats
    # entry 1 (i=1 < pos=2). Entry 2: no +10% within horizon -> miss.
    assert len(out["train"]) == 2
    (h1, r1), (h2, r2) = out["train"]
    assert h1 == 1 and r1 > 0.10
    assert h2 == 0 and r2 < 0


def test_window_stats():
    st = _window_stats([(1, 0.12), (0, -0.02)])
    assert st["n"] == 2 and st["hit"] == 50.0 and abs(st["avg"] - 5.0) < 0.01
    assert _window_stats([])["hit"] is None


def test_run_movers_end_to_end(tmp_path):
    series = {f"S{i}": _dated(_series(seed=i)) for i in range(6)}
    res = run_movers(series, pop=0.10, horizon=5, log=lambda *a: None)
    assert res["universe"] == 6
    assert len(res["results"]) == len(PRECURSORS)
    for k in ("train", "select", "test"):
        assert res["baseline"][k]["n"] > 0            # baseline always populates
    for r in res["results"]:
        assert r["verdict"] in ("VALIDATED", "FAILED", "THIN")
        assert set(r["lift"]) == {"train", "select", "test"}
        # a VALIDATED precursor must clear the lift bar in every window
        if r["verdict"] == "VALIDATED":
            assert all(v is not None and v >= 1.25 for v in r["lift"].values())
            assert r["test"]["avg"] > 0
    # VALIDATED first
    vs = [r["verdict"] for r in res["results"]]
    assert vs == sorted(vs, key=lambda v: v != "VALIDATED")
    p = tmp_path / "movers.json"
    save_results(res, "t.csv", p)
    assert load_results(p)["pop"] == 0.10


def test_scan_today_matches_latest_bar():
    # craft a stock whose LAST bar is a fresh 20-day-high breakout with +25% mom
    closes = [100.0] * 300
    for i in range(230, 300):
        closes[i] = 100.0 + (i - 230) * 0.6           # steady runner: +~40% over 70d
    closes[-1] = closes[-2] * 1.03                    # breaks the 20-day high today
    flat = [50.0] * 300                               # a dead stock matches nothing
    validated = [{"key": "brk20_mom", "masks": ["brk20", "mom25"]}]
    today = scan_today({"RUNNER": closes, "DEAD": flat}, validated)
    assert today["brk20_mom"] == ["RUNNER"]
    assert scan_today({"RUNNER": closes}, []) == {}
