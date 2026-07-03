"""Tests for Rama's three added pillars: Kelly sizing, catalyst signal, audit
gate — plus one end-to-end synthetic paper session. Rama is a separate package,
so these never touch sectorbot."""

import pytest

from rama import config
from rama.sizing import kelly_fraction, measure_edge, target_fraction
from rama.audit import audit_candidate
from rama import catalysts
from rama.screener import Industry


# --- Kelly sizing ----------------------------------------------------------

def test_kelly_fraction_basic():
    # f* = W - (1-W)/R = 0.6 - 0.4/2 = 0.4 ; half-Kelly halves it.
    assert kelly_fraction(0.6, 2.0, 1.0) == pytest.approx(0.4)
    assert kelly_fraction(0.6, 2.0, 0.5) == pytest.approx(0.2)


def test_kelly_no_edge_is_zero():
    # A losing edge (W=0.4, R=1) gives a negative f* -> clamped to 0 (don't bet).
    assert kelly_fraction(0.4, 1.0, 1.0) == 0.0
    assert kelly_fraction(0.6, 0.0, 1.0) == 0.0  # R<=0 guard


class _PF:
    def __init__(self, trades):
        self.trades = trades


def test_measure_edge_from_trades():
    trades = [{"side": "SELL", "pnl": 100}, {"side": "SELL", "pnl": 100},
              {"side": "SELL", "pnl": -50}, {"side": "BUY"}]
    w, rr, n = measure_edge(_PF(trades))
    assert n == 3
    assert w == pytest.approx(2 / 3)
    assert rr == pytest.approx(100 / 50)  # avg win / avg loss = 2.0


def test_target_fraction_falls_back_before_min_trades(monkeypatch):
    monkeypatch.setattr(config, "SIZING_MODE", "kelly")
    monkeypatch.setattr(config, "KELLY_MIN_TRADES", 20)
    frac, label = target_fraction(_PF([{"side": "SELL", "pnl": 10}]))
    assert frac == config.MAX_ALLOCATION_PER_NAME
    assert "flat cap" in label


# --- Catalyst signal -------------------------------------------------------

def _write_catalysts(tmp_path, rows):
    p = tmp_path / "catalysts.csv"
    p.write_text("Symbol,Signal,Party,Date\n" + "\n".join(rows) + "\n")
    return p


def test_catalyst_scores_sign(tmp_path, monkeypatch):
    p = _write_catalysts(tmp_path, ["KEI,BUY,Promoter,", "SUZLON,SELL,Promoter,"])
    monkeypatch.setattr(config, "CATALYST_CSV", p)
    catalysts.clear_cache()
    scores = catalysts.load_catalyst_scores()
    assert scores["KEI"] > 0
    assert scores["SUZLON"] < 0


def test_catalyst_tilt_raises_ranking(tmp_path, monkeypatch):
    # KEI/POLYCAB belong to "Wires & Cables" in the fallback universe map.
    p = _write_catalysts(tmp_path, ["KEI,BUY,Promoter,", "POLYCAB,BUY,Promoter,"])
    monkeypatch.setattr(config, "CATALYST_CSV", p)
    monkeypatch.setattr(config, "USE_CATALYST_SIGNAL", True)
    catalysts.clear_cache()
    ind = Industry(name="Wires & Cables", sector="Industrials", day_change=0,
                   industry_score=0, qtr_change=0, half_change=0, year_change=0,
                   roe=0, rev_growth=0, breadth=0, pe=20, score=10.0)
    catalysts.apply_catalyst_tilt([ind])
    assert ind.catalyst_score > 0
    assert ind.score > 10.0  # buys tilted the score up


# --- Audit gate ------------------------------------------------------------

def _industry(score=50.0, pe=20):
    return Industry(name="X", sector="Y", day_change=0, industry_score=0,
                    qtr_change=0, half_change=0, year_change=0, roe=0,
                    rev_growth=0, breadth=0, pe=pe, score=score)


def test_audit_passes_healthy(monkeypatch):
    monkeypatch.setattr(config, "USE_AUDIT_GATE", True)
    res = audit_candidate("KEI", _industry(), ltp=100.0, uptrend=True,
                          catalyst_score=0.3)
    assert res.ok


def test_audit_vetoes_downtrend(monkeypatch):
    monkeypatch.setattr(config, "USE_AUDIT_GATE", True)
    monkeypatch.setattr(config, "AUDIT_REQUIRE_UPTREND", True)
    res = audit_candidate("KEI", _industry(), ltp=100.0, uptrend=False)
    assert not res.ok and "downtrend" in res.reason


def test_audit_vetoes_insider_selling(monkeypatch):
    monkeypatch.setattr(config, "USE_AUDIT_GATE", True)
    monkeypatch.setattr(config, "USE_CATALYST_SIGNAL", True)
    monkeypatch.setattr(config, "AUDIT_MAX_NEGATIVE_CATALYST", -0.5)
    res = audit_candidate("SUZLON", _industry(), ltp=100.0, uptrend=True,
                          catalyst_score=-0.9)
    assert not res.ok and "SELLING" in res.reason


def test_audit_gate_off_always_passes(monkeypatch):
    monkeypatch.setattr(config, "USE_AUDIT_GATE", False)
    res = audit_candidate("ANY", _industry(score=-5), ltp=0.0, uptrend=False)
    assert res.ok


# --- End-to-end synthetic paper session ------------------------------------

def test_paper_session_runs_synthetic(tmp_path, monkeypatch):
    # Force synthetic prices (no Kite) and an isolated portfolio file.
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    from rama.engine import run_paper_session
    result = run_paper_session(verbose=False)
    assert not result.get("aborted")
    assert "sizing_label" in result
    assert "vetoes" in result and "entries" in result
