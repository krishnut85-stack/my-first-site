"""Tests for LAB SARATHI — the breadth regime gate."""

import random
from datetime import date, timedelta

from garuda.lab_sarathi import (breadth_series, regime_of, simulate_sarathi)


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _trending(days=700, seed=1, drift=0.001):
    rng = random.Random(seed)
    p, cl = 100.0, [100.0]
    for _ in range(days):
        p = max(1.0, p * (1 + drift + rng.gauss(0, 0.012)))
        cl.append(round(p, 3))
    return cl


def test_breadth_extremes_and_warmup():
    # 120 rising stocks -> breadth 100 once the 200-DMA exists; warmup -> None
    up = {f"U{i}": _dated([100 + j * 0.5 for j in range(300)]) for i in range(120)}
    b = breadth_series(up)
    dates = sorted(b)
    assert b[dates[-1]] == 100.0
    down = {f"D{i}": _dated([400 - j for j in range(300)]) for i in range(120)}
    bd = breadth_series(down)
    assert bd[sorted(bd)[-1]] == 0.0
    # fewer than MIN_MEASURED stocks -> None (unmeasurable, treated as GREEN)
    few = breadth_series({"A": _dated([100 + j for j in range(300)])})
    assert all(v is None for v in few.values())


def test_regime_thresholds():
    assert regime_of(None) == "G"          # warmup: no gate
    assert regime_of(60.0) == "G"
    assert regime_of(50.0) == "Y"          # boundary belongs to YELLOW
    assert regime_of(35.0) == "Y"
    assert regime_of(34.9) == "R"


def test_gate_blocks_entries_in_red():
    # bear universe: crashes below the 50-DMA + breadth 0 -> RED days dominate,
    # and the gated portfolio must place no trades on measurable RED days
    bear = {f"B{i}": _dated([600 - j for j in range(400)]) for i in range(120)}
    gated = simulate_sarathi(bear, gate=True)
    assert gated["regime_days"]["R"] > 0
    ungated = simulate_sarathi(bear, gate=False)
    assert ungated["regime_days"]["R"] == 0      # gate off -> every day GREEN
    assert gated["trades"] <= ungated["trades"]


def test_gated_and_ungated_agree_in_green():
    # healthy uptrending universe: breadth ~100 -> gate never binds, so both
    # runs make identical trades and identical final equity
    uni = {f"S{i}": _dated(_trending(seed=i)) for i in range(120)}
    g = simulate_sarathi(uni, gate=True)
    u = simulate_sarathi(uni, gate=False)
    assert g["regime_days"]["R"] == 0
    assert g["final"] == u["final"]
    assert g["trades"] == u["trades"]
    # equity curve exists for every trading day
    assert len(g["curve"]) > 600 and all(v > 0 for _, v in g["curve"])
