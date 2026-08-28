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
