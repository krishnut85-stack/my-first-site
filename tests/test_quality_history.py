"""Tests for scripts/quality_history_test.py — the pure decision logic only
(the yfinance fetch layer is droplet-only and imported lazily)."""

import importlib.util
from datetime import date, timedelta
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "quality_history_test",
    Path(__file__).resolve().parent.parent / "scripts" / "quality_history_test.py")
qh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qh)


def _px(start, days, drift, p0=100.0):
    out, p, d = [], p0, start
    for _ in range(days):
        p *= 1 + drift
        out.append((d.isoformat(), round(p, 4)))
        d += timedelta(days=1)
    return out


def test_quality_pass_rule():
    assert qh.quality_pass(100, 130, 1000, 1200, 0.5)          # all good
    assert not qh.quality_pass(100, 115, 1000, 1200, 0.5)      # NP +15% < 20%
    assert not qh.quality_pass(100, 130, 1000, 1050, 0.5)      # rev +5% < 10%
    assert not qh.quality_pass(-10, 130, 1000, 1200, 0.5)      # loss last year
    assert not qh.quality_pass(100, 130, 1000, 1200, 1.5)      # D/E >= 1
    assert qh.quality_pass(100, 130, 1000, 1200, None)         # no balance sheet
    assert not qh.quality_pass(None, 130, 1000, 1200, 0.5)     # missing data


def test_next_return_measures_forward_year():
    prices = _px(date(2023, 1, 1), 500, 0.001)
    r = qh.next_return(prices, "2023-02-01", hold_days=365)
    assert r is not None and 0.35 < r < 0.55                   # ~+44% at 0.1%/d
    # entry more than 30 days after requested date -> unmeasurable
    assert qh.next_return(prices, "2022-01-01") is None
    # too little forward history (< 200 days) -> unmeasurable
    assert qh.next_return(prices, "2024-01-01") is None


def test_form_cohorts_selects_and_benchmarks():
    fund = {
        "GOOD": [("2022-03-31", 100.0, 1000.0, 0.3),
                 ("2023-03-31", 140.0, 1200.0, 0.3)],
        "JUNK": [("2022-03-31", 100.0, 1000.0, 0.3),
                 ("2023-03-31", 90.0, 950.0, 0.3)],
    }
    prices = {"GOOD": _px(date(2022, 1, 1), 900, 0.0006),
              "JUNK": _px(date(2022, 1, 1), 900, -0.0004)}
    cohorts = qh.form_cohorts(fund, prices)
    assert set(cohorts) == {"2023"}
    assert [s for s, _ in cohorts["2023"]["selected"]] == ["GOOD"]
    assert [s for s, _ in cohorts["2023"]["rejected"]] == ["JUNK"]
    rows = qh.summarize(cohorts)
    assert rows[0]["n_sel"] == 1 and rows[0]["n_uni"] == 2
    assert rows[0]["spread"] > 0
    txt = qh.format_report(rows)
    assert "UPPER BOUND" in txt and "spread" in txt
    # a 1-stock cohort must be flagged and excluded from the headline average
    assert "TOO THIN" in txt and "nothing to conclude" in txt


def test_thin_cohorts_never_carry_the_average():
    rows = [{"year": "2023", "n_sel": 1, "n_uni": 9, "sel": 2.688,
             "uni": 0.572, "spread": 2.115, "sel_win": 100.0},
            {"year": "2024", "n_sel": 123, "n_uni": 438, "sel": 0.098,
             "uni": 0.094, "spread": 0.004, "sel_win": 54.0},
            {"year": "2025", "n_sel": 132, "n_uni": 460, "sel": 0.103,
             "uni": 0.066, "spread": 0.036, "sel_win": 48.0}]
    txt = qh.format_report(rows)
    assert "2 usable year(s)" in txt
    assert "+2.0%/yr" in txt            # (0.4 + 3.6) / 2, not the +71.9% mirage
    assert "71.9" not in txt


def test_selftest_runs_clean(capsys):
    qh.selftest()
    assert "SELFTEST OK" in capsys.readouterr().out


def test_norm_thr_accepts_percent_or_fraction():
    assert qh._norm_thr(40) == 0.40
    assert qh._norm_thr(0.40) == 0.40
    assert qh._norm_thr(100) == 1.00


def test_format_sweep_compares_thresholds():
    rows_ok = [{"year": "2024", "n_sel": 120, "n_uni": 400, "sel": 0.10,
                "uni": 0.08, "spread": 0.02, "sel_win": 52.0},
               {"year": "2025", "n_sel": 110, "n_uni": 420, "sel": 0.09,
                "uni": 0.05, "spread": 0.04, "sel_win": 50.0}]
    rows_thin = [{"year": "2024", "n_sel": 3, "n_uni": 400, "sel": 0.50,
                  "uni": 0.08, "spread": 0.42, "sel_win": 67.0}]
    txt = qh.format_sweep([(0.20, rows_ok), (1.00, rows_thin)])
    assert "20%" in txt and "100%" in txt
    assert "+3.0%" in txt                  # (2 + 4) / 2 across usable years
    assert "too thin" in txt               # the 100% bar collapsed to n=3
