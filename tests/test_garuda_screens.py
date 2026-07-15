"""Tests for SCREEN LAB — six screens, one harness."""

from datetime import date, timedelta

from garuda.lab_screens import (SCREENS, _field_of, format_exam, load_wide,
                                momentum_pct, next_return, run_exam,
                                s_accel, s_qroce, s_quality40, s_steady15,
                                s_turnaround)


def _v(d):
    return lambda f, j: d.get((f, j))


def test_field_of_header_mapping():
    assert _field_of("Net Profit Annual") == ("np", 0)
    assert _field_of("Net Profit Annual 3Yr Ago") == ("np", 3)
    assert _field_of("Net Profit Ann  1Yr Ago") == ("np", 1)
    assert _field_of("Revenue Annual 2Yr ago") == ("rev", 2)
    assert _field_of("ROCE Annual 1Yr Ago %") == ("roce", 1)
    assert _field_of("Operating Profit Margin Annual 2Yr Ago %") == ("opm", 2)
    assert _field_of("Net Profit Margin Annual") is None        # margin != NP
    assert _field_of("Net Profit Ann  YoY Growth %") is None    # growth
    assert _field_of("Net Profit Qtr 1Yr Ago") is None          # quarterly
    assert _field_of("ROE Annual 5Yr Avg %") is None            # average
    # the real export writes "1Y Ago" (no 'r') and trailing-space headers
    assert _field_of("Net Profit Ann  1Y Ago") == ("np", 1)
    assert _field_of("Rev  Ann  4Y ago") == ("rev", 4)
    assert _field_of("Total Rev  Ann ") == ("rev", 0)
    assert _field_of("Net Profit Ann ") == ("np", 0)
    assert _field_of("ROCE Ann  1Y Ago %") == ("roce", 1)
    assert _field_of("OPM Ann  1Y ago %") == ("opm", 1)


def test_screen_rules():
    q = {("np", 0): 150, ("np", 1): 100, ("rev", 0): 1200, ("rev", 1): 1000}
    assert s_quality40(_v(q)) is True
    assert s_quality40(_v({**q, ("np", 0): 130})) is False      # +30% < 40%
    assert s_quality40(_v({**q, ("rev", 1): None})) is None     # missing data

    assert s_qroce(_v({**q, ("roce", 0): 20.0})) is True
    assert s_qroce(_v({**q, ("roce", 0): 10.0})) is False       # ROCE too low
    assert s_qroce(_v(q)) is None                               # no ROCE data

    a = {("np", 0): 200, ("np", 1): 130, ("np", 2): 100}        # 54% > 30%
    assert s_accel(_v(a)) is True
    assert s_accel(_v({("np", 0): 150, ("np", 1): 130,
                       ("np", 2): 100})) is False               # 15% not >20%

    t = {("np", 0): 50, ("np", 1): -20, ("rev", 0): 1100, ("rev", 1): 1000}
    assert s_turnaround(_v(t)) is True
    assert s_turnaround(_v({**t, ("np", 1): 10})) is False      # no loss before

    s = {("np", 0): 160, ("np", 1): 135, ("np", 2): 116, ("np", 3): 100}
    assert s_steady15(_v(s)) is True
    assert s_steady15(_v({**s, ("np", 2): 130})) is False       # a flat year


def test_load_wide_and_symbols(tmp_path):
    p = tmp_path / "wide.csv"
    p.write_text('"Stock","NSE code","Net Profit Annual",'
                 '"Net Profit Annual 1Yr Ago","Revenue Annual",'
                 '"Revenue Annual 1Yr Ago"\n'
                 '"Good","GOOD","150","100","1200","1000"\n'
                 '"BSEOnly","123456","1","1","1","1"\n')
    wide, fmap = load_wide(p)
    assert set(wide) == {"GOOD"}
    assert wide["GOOD"][("np", 0)] == 150.0
    assert len(fmap) == 4


def _px(start, days, drift, p0=100.0):
    dates, closes, p, d = [], [], p0, start
    for _ in range(days):
        p *= 1 + drift
        dates.append(d.isoformat())
        closes.append(round(p, 4))
        d += timedelta(days=1)
    return dates, closes


def test_momentum_pct_and_next_return():
    prices = {"HOT": _px(date(2024, 1, 1), 900, 0.001),
              "COLD": _px(date(2024, 1, 1), 900, -0.0005)}
    mom = momentum_pct(prices, "2025-07-01")
    assert mom["HOT"] > mom["COLD"]
    r = next_return(prices["HOT"], "2025-07-01")
    assert r is not None and r > 0.3


def test_run_exam_and_verdict_board():
    # GOOD passes QUALITY40 in every year and its price outruns BAD's
    wide = {}
    for i in range(30):
        good = i % 2 == 0
        vals = {}
        for k in range(7):
            base = 100.0 * (1.6 ** -k if good else 1.0)
            vals[("np", k)] = base
            vals[("rev", k)] = base * 10 * (1.2 ** -k if good else 1.0)
            vals[("roce", k)] = 25.0 if good else 10.0
            vals[("opm", k)] = 20.0 - k if good else 10.0
        wide[f"S{i}"] = vals
    prices = {f"S{i}": _px(date(2021, 1, 1), 2000,
                           0.0008 if i % 2 == 0 else -0.0002)
              for i in range(30)}
    results = run_exam(wide, prices, latest_fy=2026, log=lambda *a: None)
    assert set(results) == {n for n, _f, _m in SCREENS}
    q = [r for r in results["QUALITY40"] if r["n_sel"] >= 10]
    assert q, "QUALITY40 should have usable cohorts"
    assert all(r["spread"] > 0 for r in q)
    txt = format_exam(results)
    assert "VERDICT BOARD" in txt and "QUALITY40" in txt and "QMOM" in txt
