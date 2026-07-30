"""Tests for the Strategy LAB — walk-forward edge discovery."""

import random
from datetime import date, timedelta

from garuda.lab import (CANDIDATES, _bucket_stats, _trade, _trail_exit, _verdict,
                        cand_three_down, cand_turn_of_month, load_results,
                        run_lab, save_results, split_date_of)


def _dated(closes, start=date(2020, 1, 1)):
    """Attach weekday dates to a close series (long-CSV shape: [(date, close)])."""
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _uptrend_with_dips(days=900, seed=7):
    """Drift up + strongly mean-reverting shocks — dips that tend to bounce."""
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    closes = [price]
    for _ in range(days):
        noise = -0.6 * prev + rng.gauss(0.0, 0.015)
        r = 0.0006 + noise
        price = max(1.0, price * (1.0 + r))
        closes.append(round(price, 3))
        prev = noise
    return closes


def test_trail_exit_stops_and_time():
    closes = [100, 101, 102, 80, 79, 78]
    # 10% hard stop triggers on the crash bar
    assert _trail_exit(closes, 0, stop=0.10, max_hold=50) == 3
    # profit target triggers on the first bar at/above +1%
    assert _trail_exit(closes, 0, target=0.01, max_hold=50) == 1
    # pure time stop
    assert _trail_exit([100] * 20, 0, max_hold=5) == 5


def test_trade_charges_costs_both_sides():
    t = _trade(["d0", "d1"], [100.0, 110.0], 0, 1, cost=0.001)
    assert abs(t["ret"] - (0.10 - 0.002)) < 1e-9
    assert t["entry_date"] == "d0"
    assert _trade(["d0", "d1"], [100.0, 110.0], 1, 1, cost=0.001) is None


def test_turn_of_month_picks_month_boundary():
    dv = _dated([100.0] * 260)                     # a year of flat weekdays
    dates = [d for d, _ in dv]
    closes = [c for _, c in dv]
    trades = cand_turn_of_month(dates, closes, cost=0.0)
    assert len(trades) >= 8                        # ~one per month turn
    # every entry sits within the last 3 trading days of its month
    for t in trades:
        i = dates.index(t["entry_date"])
        month = dates[i][:7]
        rest = [d for d in dates[i + 1:] if d[:7] == month]
        assert len(rest) <= 2


def test_three_down_needs_uptrend_and_streak():
    closes = _uptrend_with_dips()
    dv = _dated(closes)
    trades = cand_three_down([d for d, _ in dv], closes, cost=0.001)
    assert trades, "mean-reverting uptrend must produce 3-red-close entries"
    # on this bounce-heavy series the setup should win more often than it loses
    wins = sum(1 for t in trades if t["ret"] > 0)
    assert wins / len(trades) > 0.5


def test_split_buckets_by_entry_date():
    dv = _dated([100.0] * 500)
    split = split_date_of({"A": dv}, oos_frac=0.30)
    dates = [d for d, _ in dv]
    assert split in dates
    before = sum(1 for d in dates if d < split)
    assert abs(before / len(dates) - 0.70) < 0.02


def test_verdict_logic():
    ok = {"trades": 100, "win": 60.0, "avg": 0.5, "pf": 1.5, "worst": -5.0}
    bad = {"trades": 100, "win": 40.0, "avg": -0.2, "pf": 0.8, "worst": -9.0}
    weak = {"trades": 100, "win": 51.0, "avg": 0.05, "pf": 1.02, "worst": -6.0}
    thin = {"trades": 3, "win": 100.0, "avg": 2.0, "pf": None, "worst": 1.0}
    assert _verdict(ok, ok) == "PROMOTED"
    assert _verdict(ok, bad) == "OVERFIT"          # the trap the LAB exists for
    assert _verdict(bad, ok) == "REJECTED"
    assert _verdict(ok, weak) == "WEAK"
    assert _verdict(ok, thin) == "THIN"
    assert _verdict(thin, ok) == "THIN"


def test_bucket_stats_math():
    st = _bucket_stats([0.10, -0.05, 0.02])
    assert st["trades"] == 3
    assert abs(st["win"] - 66.7) < 0.1
    assert st["pf"] == 2.4                          # 0.12 gross win / 0.05 gross loss
    assert st["worst"] == -5.0
    empty = _bucket_stats([])
    assert empty["trades"] == 0 and empty["avg"] is None


def test_run_lab_end_to_end_and_persistence(tmp_path):
    series = {f"S{i}": _dated(_uptrend_with_dips(seed=i)) for i in range(6)}
    res = run_lab(series, oos_frac=0.30)
    assert res["universe"] == 6 and res["split_date"]
    assert len(res["results"]) == len(CANDIDATES)
    for r in res["results"]:
        assert r["verdict"] in ("PROMOTED", "WEAK", "OVERFIT", "THIN", "REJECTED")
        assert set(r["is"]) == {"trades", "win", "avg", "pf", "worst"}
    # verdict ordering: PROMOTED rows (if any) come first
    order = [r["verdict"] for r in res["results"]]
    rank = {"PROMOTED": 0, "WEAK": 1, "OVERFIT": 2, "THIN": 3, "REJECTED": 4}
    assert order == sorted(order, key=lambda v: rank[v])
    # round-trip through the JSON the dashboard reads
    p = tmp_path / "lab.json"
    save_results(res, "test.csv", p)
    back = load_results(p)
    assert back["source"] == "test.csv" and back["generated"]
    assert back["results"][0]["name"] == res["results"][0]["name"]


def test_no_lookahead_signals_only_use_past():
    """Truncating the future must not change trades that closed before the cut:
    if signals peeked ahead, removing future bars would alter earlier trades."""
    closes = _uptrend_with_dips(days=800, seed=3)
    dv = _dated(closes)
    dates = [d for d, _ in dv]
    cut = 600
    for cand in CANDIDATES:
        full = cand["fn"](dates, closes, 0.001)
        part = cand["fn"](dates[:cut], closes[:cut], 0.001)
        full_early = [t for t in full if dates.index(t["entry_date"]) < cut - 130]
        for a, b in zip(full_early, part):
            assert a["entry_date"] == b["entry_date"]
            assert abs(a["ret"] - b["ret"]) < 1e-12
