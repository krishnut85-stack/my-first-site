"""GIR and Garuda must answer the session clock identically.

They deploy to different roots (/home/globalbot flat, vs Garuda's package), so
each carries its own copy of the CAS calendar. This walks every minute of a
trading day — before and after the auction went live — and fails the moment the
two drift apart.
"""

import importlib.util
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from garuda import market as gar

SHARED = ["cas_in_effect", "is_trading_day", "in_cas_window",
          "is_derivatives_open", "is_session_live", "eod_safe",
          "recommended_squareoff", "market_status"]
SYMBOL_AWARE = ["is_market_open", "closing_price_final", "close_min"]


@pytest.fixture(scope="module")
def gir():
    path = Path(__file__).resolve().parent.parent / "gir" / "market_session.py"
    spec = importlib.util.spec_from_file_location("gir_market_session", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_constants_match(gir):
    for name in ("OPEN_MIN", "CLOSE_MIN", "CAS_OPEN_MIN", "CAS_ENTRY_MIN",
                 "CAS_LIMIT_MIN", "CAS_MATCH_MIN", "CAS_CLOSE_MIN",
                 "DERIVATIVES_CLOSE_MIN", "EOD_SAFE_MIN", "CAS_START_DATE"):
        assert getattr(gir, name) == getattr(gar, name), name


@pytest.mark.parametrize("day", [
    datetime(2026, 8, 27),      # Thursday, after CAS
    datetime(2026, 7, 30),      # Thursday, before CAS
    datetime(2026, 8, 29),      # Saturday
])
def test_every_minute_agrees(gir, day, monkeypatch):
    sym = "RELIANCE"
    monkeypatch.setattr(gar, "CAS_STOCKS", {sym})
    monkeypatch.setattr(gir, "CAS_STOCKS", {sym})
    monkeypatch.setattr(gar, "HOLIDAYS", set())
    monkeypatch.setattr(gir, "HOLIDAYS", set())
    for step in range(0, 24 * 60):
        t = day + timedelta(minutes=step)
        for fn in SHARED:
            assert getattr(gir, fn)(t) == getattr(gar, fn)(t), f"{fn} at {t}"
        for fn in SYMBOL_AWARE:
            for s in (None, sym, "SOMESMALLCAP"):
                assert getattr(gir, fn)(t, s) == getattr(gar, fn)(t, s), \
                    f"{fn}({s}) at {t}"


# --- the macro layer: Garuda reads it, GIR owns it ------------------------

MACRO_SHARED = ["vote_repo", "vote_gsec", "vote_credit", "tally",
                "is_stale", "signals_age_days", "sector_tilt", "size_multiplier"]


@pytest.fixture(scope="module")
def gir_macro():
    path = Path(__file__).resolve().parent.parent / "gir" / "macro_cycle.py"
    spec = importlib.util.spec_from_file_location("gir_macro_cycle", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_macro_constants_match(gir_macro):
    from garuda import macro as gar_macro
    for name in ("EASING", "EXPANSION", "SLOWDOWN", "UNKNOWN", "PHASES",
                 "SIGNALS_MAX_AGE_DAYS", "GSEC_FALLING_BPS", "GSEC_RISING_BPS",
                 "AUTO_FESTIVE_MONTHS", "AUTO_FESTIVE_MULT", "MARCH_MULT",
                 "PHASE_SECTORS", "PHASE_AVOID"):
        assert getattr(gir_macro, name) == getattr(gar_macro, name), name


@pytest.mark.parametrize("repo", ["cutting", "holding_after_cuts", "hiking",
                                 "", "nonsense"])
@pytest.mark.parametrize("bps", [-40, -15, -8, 0, 24, 25, 80, None, "x"])
@pytest.mark.parametrize("credit", ["accelerating", "decelerating", "flat", ""])
def test_every_signal_combination_classifies_the_same(gir_macro, repo, bps,
                                                      credit):
    """Two implementations, one answer — for every input the bots can see."""
    from garuda import macro as gar_macro
    from datetime import date as _date
    sig = {"as_of": "2026-09-05", "repo_direction": repo,
           "gsec_10y_slope_3m_bps": bps, "credit_growth_yoy_trend": credit}
    today = _date(2026, 9, 5)
    for fn in MACRO_SHARED:
        if fn in ("sector_tilt", "size_multiplier", "signals_age_days",
                  "is_stale"):
            continue
        assert getattr(gir_macro, fn)(sig) == getattr(gar_macro, fn)(sig), fn
    for held in ("UNKNOWN", "EASING", "EXPANSION", "SLOWDOWN"):
        assert (gir_macro.advance(held, sig, today)
                == gar_macro.advance(held, sig, today)), held


@pytest.mark.parametrize("sector", ["AUTO", "INFRA", "BANKING", "IT", None])
def test_tilt_and_sizing_agree_across_the_year(gir_macro, sector):
    from garuda import macro as gar_macro
    from datetime import date as _date
    for phase in ("EASING", "EXPANSION", "SLOWDOWN", "UNKNOWN"):
        assert (gir_macro.sector_tilt(sector, phase)
                == gar_macro.sector_tilt(sector, phase))
    for month in range(1, 13):
        when = _date(2026, month, 15)
        assert (gir_macro.size_multiplier(sector, when)
                == gar_macro.size_multiplier(sector, when))
