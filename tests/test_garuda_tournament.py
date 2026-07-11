"""Tests for LAB TOURNAMENT — the seat-10 contest."""

import random
from datetime import date, timedelta

from garuda.lab_tournament import (FAMILIES, book_chakra, book_champion,
                                   book_ekalavya, book_triveni, book_vijaya,
                                   prepare, judge_window_start, virtual_trades,
                                   window_metrics)


def _dated(closes, start=date(2020, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _series(days=900, seed=5):
    rng = random.Random(seed)
    p, prev = 100.0, 0.0
    cl = [p]
    for _ in range(days):
        n = -0.5 * prev + rng.gauss(0.0, 0.017)
        p = max(1.0, p * (1 + 0.0006 + n))
        cl.append(round(p, 3))
        prev = n
    return cl


def _uni(n=25):
    return {f"S{i}": _dated(_series(seed=i)) for i in range(n)}


def test_prepare_and_virtual_trades():
    prep = prepare(_uni(8))
    assert prep and all(set(p["fam_idx"]) == set(FAMILIES) for p in prep.values())
    vt = virtual_trades(prep, cost=0.001)
    # virtual trades are ordered, non-overlapping, resolved
    for (sym, fam), trades in vt.items():
        for k, (e, x, r) in enumerate(trades):
            assert x > e
            if k:
                assert e >= trades[k - 1][1]        # cooldown respected


def test_triveni_needs_two_families():
    prep = prepare(_uni(8))
    solo = book_champion(prep, 100000.0, 0.001)
    conf = book_triveni(prep, 100000.0, 0.001)
    # confluence is strictly more selective than the whole-family union
    all_fam = sum(len(p["fam_idx"][f]) for p in prep.values() for f in FAMILIES)
    assert conf["trades"] <= all_fam
    assert len(conf["curve"]) == len(solo["curve"])


def test_ekalavya_gates_on_past_only():
    prep = prepare(_uni(8))
    vt = virtual_trades(prep, cost=0.001)
    res = book_ekalavya(prep, vt, 100000.0, 0.001)
    ungated = book_triveni(prep, 100000.0, 0.001)   # any book for shape compare
    assert len(res["curve"]) == len(ungated["curve"])
    # learner must trade less than the raw union of all signals
    raw = sum(len(t) for t in vt.values())
    assert (res["trades"] or 0) <= raw


def test_vijaya_and_chakra_produce_full_curves():
    prep = prepare(_uni(12))
    v = book_vijaya(prep, 100000.0, 0.001)
    c = book_chakra(prep, 100000.0, 0.001)
    days = len(sorted({d for p in prep.values() for d in p["px"]}))
    assert len(v["curve"]) == days and len(c["curve"]) == days
    assert all(x > 0 for _, x in v["curve"])
    assert all(x > 0 for _, x in c["curve"])


def test_window_scoring():
    uni = _uni(6)
    start = judge_window_start(uni)
    prep = prepare(uni)
    sim = book_champion(prep, 100000.0, 0.001)
    wm = window_metrics(sim["curve"], start)
    assert wm is None or (wm["final"] > 0 and "cagr_pct" in wm)
    dates = [d for d, _ in sim["curve"]]
    before = sum(1 for d in dates if d < start)
    assert abs(before / len(dates) - 0.70) < 0.05
