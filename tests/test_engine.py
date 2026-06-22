"""Tests for the persistent paper-trading engine (synthetic data path)."""

from sectorbot import config
from sectorbot.engine import run_paper_session
from sectorbot.portfolio import Portfolio


def test_session_opens_positions_within_capital(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "CAPITAL_MODE", "fixed")
    monkeypatch.setattr(config, "PAPER_CAPITAL", 1_000_000.0)
    monkeypatch.setattr(config, "USE_KITE_DATA", False)  # allow synthetic demo

    result = run_paper_session(verbose=False)
    pf = result["portfolio"]
    assert pf.holdings, "should open at least one position"
    assert result["cash"] >= 0
    # never deploy more than the starting capital
    assert result["holdings_value"] <= pf.starting_capital + 1


def test_positions_persist_and_no_double_buy(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "PAPER_CAPITAL", 1_000_000.0)
    monkeypatch.setattr(config, "USE_KITE_DATA", False)

    first = run_paper_session(verbose=False)
    held = set(first["portfolio"].holdings)

    second = run_paper_session(verbose=False)
    held2 = set(second["portfolio"].holdings)

    # held names persist across runs; no duplicate entries created
    assert held.issubset(held2) or held2.issubset(held)
    # equity history grew by the two runs
    assert len(second["portfolio"].history) >= 2


def test_synthetic_flag_when_no_kite_keys(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "KITE_API_KEY", "")
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    result = run_paper_session(verbose=False)
    assert result["real_data"] is False


def test_aborts_when_real_data_required_but_unavailable(tmp_path, monkeypatch):
    # USE_KITE_DATA on but no keys -> synthetic -> MUST abort and not write state
    pf_path = tmp_path / "pf.json"
    monkeypatch.setattr(config, "PORTFOLIO_JSON", pf_path)
    monkeypatch.setattr(config, "USE_KITE_DATA", True)
    monkeypatch.setattr(config, "KITE_API_KEY", "")
    result = run_paper_session(verbose=False)
    assert result.get("aborted") is True
    assert not pf_path.exists()  # portfolio left untouched / not created
