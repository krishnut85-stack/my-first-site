"""Tests for the DIP RACE — portfolio-level quick vs patient exits."""

import random
from datetime import date, timedelta

from garuda.lab_dip_race import CONFIGS, race


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _bouncy(days=700, seed=2):
    rng = random.Random(seed)
    p, prev = 100.0, 0.0
    cl = [p]
    for _ in range(days):
        n = -0.6 * prev + rng.gauss(0.0, 0.015)
        p = max(1.0, p * (1 + 0.0006 + n))
        cl.append(round(p, 3))
        prev = n
    return cl


def test_race_both_configs():
    uni = {f"S{i}": _dated(_bouncy(seed=i)) for i in range(15)}
    for name, cfg in CONFIGS.items():
        r = race(uni, cfg, capital=200000.0)
        assert r["trades"] > 0 and r["curve"]
        assert all(v > 0 for _, v in r["curve"])
        assert r["avg_slots"] >= 0 and r["skipped"] >= 0
    quick = race(uni, CONFIGS["QUICK (current book)"], capital=200000.0)
    patient = race(uni, CONFIGS["PATIENT (exam winner)"], capital=200000.0)
    # patient holds longer and recycles capital more slowly, by construction
    assert patient["avg_hold"] > quick["avg_hold"]
    assert patient["trades"] < quick["trades"]
