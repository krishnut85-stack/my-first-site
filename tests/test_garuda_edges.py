"""Tests for LAB EDGES — low-volatility anomaly + industry lead-lag."""

import random
from datetime import date, timedelta

from garuda.lab_discover import three_way_split
from garuda.lab_edges import (_stats, _vol, book_rotate, format_edges,
                              leadlag_trades, load_industries, prep_prices,
                              run_lowvol, score_lowvol)


def _dated(closes, start=date(2021, 1, 1)):
    out, d = [], start
    for c in closes:
        while d.weekday() >= 5:
            d += timedelta(days=1)
        out.append((d.isoformat(), c))
        d += timedelta(days=1)
    return out


def _noisy(days, drift, sigma, seed):
    rng = random.Random(seed)
    p, cl = 100.0, []
    for _ in range(days):
        p = max(1.0, p * (1 + drift + rng.gauss(0, sigma)))
        cl.append(round(p, 4))
    return cl


def test_vol_measures_noise():
    calm = _noisy(300, 0.0005, 0.002, 1)
    wild = _noisy(300, 0.0005, 0.030, 2)
    assert _vol(wild, 299) > _vol(calm, 299) * 3
    assert _vol(calm, 30) is None                      # not enough bars


def test_lowvol_rotation_prefers_calm_names():
    # calm names drift up; wild names drift down — LOWVOL must beat HIGHVOL
    uni = {}
    for i in range(24):
        calm = i < 12
        uni[f"S{i:02d}"] = _dated(_noisy(700, 0.0008 if calm else -0.0004,
                                         0.004 if calm else 0.03, i))
    prep = prep_prices(uni)
    rot, start = run_lowvol(prep, 500000.0, 0.001, log=lambda *a: None)
    assert rot["LOWVOL"]["full"]["final"] > rot["HIGHVOL"]["full"]["final"]
    txt = format_edges(rot, start, {w: {"sig": [], "base": []}
                                    for w in ("train", "select", "test")})
    assert "LOWVOL" in txt and "LEADLAG" in txt


def test_book_rotate_holds_top_by_score():
    uni = {f"S{i}": _dated([100.0 + i] * 400) for i in range(5)}
    prep = prep_prices(uni)
    curve = book_rotate(prep, 100000.0, 0.0,
                        lambda c, i: c[i], top=2)       # score = price level
    assert len(curve) == 400
    assert curve[-1][1] > 0


def test_leadlag_finds_spillover():
    # leader ignites at bar 300; siblings rally AFTER it; unrelated flat
    days = 700
    leader = [100.0] * 300 + [100.0 * (1.02 ** i) for i in range(days - 300)]
    sib = ([100.0] * 310                                # lags the leader ~10 bars
           + [100.0 * (1.015 ** i) for i in range(days - 310)])
    flatline = [100.0] * days
    uni = {"BIG": _dated(leader), "SIB1": _dated(sib), "SIB2": _dated(sib),
           "SIB3": _dated(sib), "OTHER": _dated(flatline)}
    prep = prep_prices(uni)
    industries = {"Widgets": ["BIG", "SIB1", "SIB2", "SIB3"],
                  "Elsewhere": ["OTHER"]}
    mcap = {"BIG": 1000.0, "SIB1": 10.0, "SIB2": 10.0, "SIB3": 10.0,
            "OTHER": 50.0}
    splits = three_way_split(uni)
    ll = leadlag_trades(prep, industries, mcap, splits, cost=0.001)
    sig = [r for w in ll.values() for r in w["sig"]]
    assert sig, "leader ignition should trigger sibling trades"
    assert sum(sig) / len(sig) > 0                      # siblings drifted up


def test_leadlag_verdict_needs_most_windows():
    # positive spread in TEST alone must print the regime-hint wording,
    # never the validated-edge wording (the 2026-07-15 droplet run's case)
    from garuda.lab_edges import format_edges as fe
    rot = {n: {"test": None, "full": None}
           for n in ("LOWVOL", "HIGHVOL", "MOMENTUM")}
    ll = {"train": {"sig": [-0.01] * 40, "base": [0.01] * 40},
          "select": {"sig": [-0.01] * 40, "base": [0.01] * 40},
          "test": {"sig": [0.02] * 40, "base": [0.001] * 40}}
    txt = fe(rot, "2024-01-01", ll)
    assert "regime hint" in txt and "build nothing" in txt
    ll2 = {w: {"sig": [0.02] * 40, "base": [0.001] * 40}
           for w in ("train", "select", "test")}
    assert "consistent across windows" in fe(rot, "2024-01-01", ll2)


def test_load_industries_and_stats(tmp_path):
    p = tmp_path / "list.csv"
    p.write_text('"Company Name","Industry","Symbol","Series","ISIN Code"\n'
                 '"A Ltd","Widgets","AAA","EQ","X1"\n'
                 '"B Ltd","Widgets","BBB","EQ","X2"\n'
                 '"C Ltd","Gadgets","CCC","EQ","X3"\n')
    ind = load_industries([p])
    assert ind == {"Widgets": ["AAA", "BBB"], "Gadgets": ["CCC"]}
    st = _stats([0.10, -0.05, 0.02])
    assert st["n"] == 3 and st["win"] > 60
    assert _stats([]) is None
