"""Tests for LAB EXITS — the honest exit-parameter sweep."""

import random
from datetime import date, timedelta

from garuda.lab_exits import ENTRIES, HOLDS, TRAILS, _entry_indices, format_sweep, sweep
from garuda.lab_portfolio import signals_hi52


def _dated(closes, start=date(2019, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _series(days=1300, seed=9):
    rng = random.Random(seed)
    p, prev = 100.0, 0.0
    cl = [p]
    for _ in range(days):
        n = -0.5 * prev + rng.gauss(0.0, 0.018)
        p = max(1.0, p * (1 + 0.0006 + n))
        cl.append(round(p, 3))
        prev = n
    return cl


def test_entry_indices_map_back_to_bars():
    closes = [100.0] * 253 + [90.0] * 60 + [99.0, 99.5, 100.5]
    dv = _dated(closes)
    dates = [d for d, _ in dv]
    idx = _entry_indices(dates, closes, signals_hi52)
    assert idx == [closes.index(99.0)]


def test_sweep_full_grid_and_honest_pick():
    series = {f"S{i}": _dated(_series(seed=i)) for i in range(8)}
    res = sweep(series, log=lambda *a: None)
    assert len(res["results"]) == len(ENTRIES)
    for r in res["results"]:
        assert len(r["grid"]) == len(TRAILS) * len(HOLDS)      # every cell measured
        assert r["pick"] in r["grid"]
        # the pick must be TRAIN-optimal — never chosen by peeking at TEST
        best_train = max(r["grid"].values(),
                         key=lambda s: s["train"]["avg"] if s["train"]["avg"] is not None else -999)
        assert r["grid"][r["pick"]]["train"]["avg"] == best_train["train"]["avg"]
        assert r["verdict"] in ("HOLDS on unseen data", "TRAIN pick FAILS unseen data")
        for st in r["grid"].values():
            assert set(st) == {"train", "select", "test"}
    txt = format_sweep(res)
    assert "TRAIN's pick" in txt and "VERDICT" in txt
