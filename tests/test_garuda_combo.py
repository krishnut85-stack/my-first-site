"""Tests for LAB COMBO — the blend racer."""

from garuda.lab_combo import rebalanced, static_split


def _curve(vals, start_month=1):
    # one point per "day", two days per month for month-turn testing
    out, m, d = [], start_month, 1
    for v in vals:
        out.append((f"2025-{m:02d}-{d:02d}", float(v)))
        d += 1
        if d > 2:
            d, m = 1, m + 1
    return out


def test_static_split_is_weighted_growth():
    a = _curve([100, 100, 200, 200])          # doubles
    b = _curve([100, 100, 100, 100])          # flat
    c = static_split([a, b], [.5, .5], 1000.0)
    assert c[-1][1] == 1500.0                 # 500 doubled + 500 flat


def test_rebalanced_buys_the_laggard():
    # A doubles in month 1 then halves; B flat. Static ends at 1000 (A round
    # trip). Rebalanced sells half of A's gain at the month turn -> ends higher.
    a = _curve([100, 200, 200, 100])
    b = _curve([100, 100, 100, 100])
    st = static_split([a, b], [.5, .5], 1000.0)
    rb = rebalanced([a, b], [.5, .5], 1000.0)
    assert st[-1][1] == 1000.0
    assert rb[-1][1] > st[-1][1]              # the rebalancing bonus
    # curves align date-for-date
    assert [d for d, _ in rb] == [d for d, _ in a]


def test_rebalanced_three_way_shape():
    a = _curve([100, 110, 120, 130])
    b = _curve([100, 105, 110, 115])
    c = _curve([100, 95, 100, 105])
    rb = rebalanced([a, b, c], [1/3, 1/3, 1/3], 900.0)
    assert len(rb) == 4 and rb[0][1] == 900.0
    assert rb[-1][1] > 900.0
