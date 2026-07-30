"""Tests for Garuda's Market Weather reader + the scan entry dial."""

import json
from datetime import date, datetime, timedelta

import pytest

from garuda import scan as scan_mod
from garuda import weather
from garuda.portfolio import LivePortfolio
from garuda.strategy import PROFILES


def _verdict(score, size, allow_new=True, when=None, day=None):
    return {"date": day or date.today().isoformat(),
            "ts": (when or datetime.now()).isoformat(timespec="seconds"),
            "score": score, "label": weather.dial(None)["label"] if False else
            {2: "STRONG UP", 1: "UP", 0: "NEUTRAL",
             -1: "DOWN", -2: "STRONG DOWN"}[score],
            "size_factor": size, "allow_new": allow_new,
            "reasons": ["test reason"]}


@pytest.fixture(autouse=True)
def _reset_dial():
    yield
    scan_mod.WEATHER["size"] = 1.0
    scan_mod.WEATHER["trail"] = 1.0


# --- the dial --------------------------------------------------------------
def test_dial_neutral_when_file_missing(tmp_path, monkeypatch):
    monkeypatch.setenv("MARKET_WEATHER_FILE", str(tmp_path / "none.json"))
    d = weather.dial(weather.load_weather())
    assert d["size"] == 1.0 and not d["block_new"] and d["info"] == ""


def test_dial_reads_todays_verdict(tmp_path, monkeypatch):
    monkeypatch.setenv("MARKET_WEATHER_FILE", str(tmp_path / "w.json"))
    (tmp_path / "w.json").write_text(json.dumps(_verdict(-1, 0.5)))
    d = weather.dial(weather.load_weather())
    assert d["size"] == 0.5 and d["label"] == "DOWN" and "test reason" in d["info"]


def test_dial_strong_down_reads_as_zero_size():
    d = weather.dial(_verdict(-2, 0.0, allow_new=False))
    assert d["size"] == 0.0 and d["block_new"]


def test_dial_ignores_stale_and_other_day_verdicts():
    old = weather.dial(_verdict(-2, 0.0, when=datetime.now() - timedelta(hours=30)))
    assert old["size"] == 1.0
    ydy = weather.dial(_verdict(-2, 0.0,
                                day=(date.today() - timedelta(days=1)).isoformat()))
    assert ydy["size"] == 1.0


def test_dial_never_returns_negative_size():
    assert weather.dial(_verdict(-1, -3.0))["size"] == 0.0


# --- the scan gate ---------------------------------------------------------
def _dip_series():
    """A stock in an uptrend that just dipped hard → a fresh RSI-2 buy."""
    c = [100.0 + i * 0.2 for i in range(240)]      # steady uptrend (> 200-SMA)
    c += [c[-1] * 0.97, c[-1] * 0.94]              # two sharp down days
    return {"DIPSTK": c}


def test_scan_buys_normally_at_full_size():
    pf = LivePortfolio(1_000_000.0)
    res = scan_mod.run_scan(PROFILES["smallcap"], _dip_series(), pf)
    assert res["buys"], "the dip should be bought on a neutral day"


def test_scan_blocks_all_buys_at_zero_size():
    scan_mod.WEATHER["size"] = 0.0                 # STRONG DOWN morning
    pf = LivePortfolio(1_000_000.0)
    res = scan_mod.run_scan(PROFILES["smallcap"], _dip_series(), pf)
    assert res["buys"] == [] and pf.holdings == {}


def test_scan_halves_position_size_on_down_day():
    pf_full = LivePortfolio(1_000_000.0)
    scan_mod.run_scan(PROFILES["smallcap"], _dip_series(), pf_full)
    scan_mod.WEATHER["size"] = 0.5                 # DOWN morning
    pf_half = LivePortfolio(1_000_000.0)
    scan_mod.run_scan(PROFILES["smallcap"], _dip_series(), pf_half)
    q_full = pf_full.holdings["DIPSTK"]["qty"]
    q_half = pf_half.holdings["DIPSTK"]["qty"]
    assert 0 < q_half <= q_full * 0.5 + 1


def test_dial_trail_factor_from_file_and_derived():
    w = _verdict(-2, 0.0, allow_new=False)
    w["trail_factor"] = 0.5
    assert weather.dial(w)["trail"] == 0.5
    del w["trail_factor"]                     # older oracle file: derive by score
    assert weather.dial(w)["trail"] == 0.5
    assert weather.dial(_verdict(0, 1.0))["trail"] == 1.0
    assert weather.dial(None)["trail"] == 1.0


def _held_winner_series():
    """A held stock well above entry, peaked, now dipping ~8% off the peak —
    inside a normal 15% trail, outside a defensive 7.5% one."""
    c = [100.0 + i * 0.2 for i in range(240)]
    c += [c[-1] * 1.10, c[-1] * 1.01]         # peak, then a ~8.2% pullback
    return {"WINNER": c}


def test_defensive_trail_books_winner_earlier():
    from garuda.strategy import Profile
    prof = Profile("t", "T", "", "x_daily.csv", strategy="momentum",
                   breakout=20, trail=0.15, max_hold=120)
    series = _held_winner_series()

    def fresh_pf():
        pf = LivePortfolio(1_000_000.0)
        pf.holdings["WINNER"] = {"qty": 10, "entry_price": 100.0,
                                 "entry_date": "2026-07-01", "entry_len": 200,
                                 "bars_held": 5, "last_date": "2026-07-20",
                                 "peak": series["WINNER"][-2]}
        return pf

    # normal day: a ~7% dip is inside the 15% trail — still held
    pf = fresh_pf()
    scan_mod.run_scan(prof, series, pf)
    assert "WINNER" in pf.holdings
    # STRONG DOWN morning: give tightens to 7.5% — the winner is booked
    scan_mod.WEATHER["trail"] = 0.5
    pf = fresh_pf()
    res = scan_mod.run_scan(prof, series, pf)
    assert "WINNER" not in pf.holdings
    assert any(s["symbol"] == "WINNER" and s["pnl"] > 0 for s in res["sells"])


def test_rotation_books_ignore_the_dial():
    """Chakra sizes from book equity, not alloc_pct — the daily dial must not
    starve a monthly rotation."""
    import inspect
    src = inspect.getsource(scan_mod._run_chakra)
    assert "_weather_size" not in src
    src = inspect.getsource(scan_mod._run_qmom)
    assert "_weather_size" not in src
    src = inspect.getsource(scan_mod._run_captain)
    assert "_weather_size" not in src
