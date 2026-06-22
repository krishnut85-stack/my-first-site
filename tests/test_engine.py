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
    # report figures must reconcile: equity == cash + holdings value
    assert abs(result["equity"] - (result["cash"] + result["holdings_value"])) < 0.01
    # unrealized must equal equity change from a single price snapshot
    assert abs(result["unrealized"] - result["total_pnl"]) < 0.01


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


def test_write_portfolio_report_creates_files(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "PORTFOLIO_REPORT_TXT", tmp_path / "r.txt")
    monkeypatch.setattr(config, "PORTFOLIO_REPORT_HTML", tmp_path / "r.html")
    from sectorbot.notify import write_portfolio_report

    result = run_paper_session(verbose=False)
    txt, html = write_portfolio_report(result)
    assert (tmp_path / "r.txt").exists()
    assert (tmp_path / "r.html").exists()
    assert "paper portfolio" in (tmp_path / "r.txt").read_text().lower()


def test_rebalance_holds_only_top_picks(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "REBALANCE", True)
    from sectorbot.bot import build_watchlist

    r = run_paper_session(verbose=False)
    syms = []
    for p in build_watchlist():
        for s in p.symbols:
            if s not in syms:
                syms.append(s)
    target = set(syms[: config.MAX_POSITIONS])
    assert set(r["portfolio"].holdings).issubset(target)
    assert len(r["portfolio"].holdings) <= config.MAX_POSITIONS


def test_rebalance_rotates_out_stale_holding(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "REBALANCE", True)
    from sectorbot.portfolio import Portfolio

    pf = Portfolio(config.PAPER_CAPITAL, config.PAPER_CAPITAL)
    pf.buy("ZZZJUNK", 1, 100.0)  # not in any top pick
    pf.save(tmp_path / "pf.json")

    r = run_paper_session(verbose=False)
    assert "ZZZJUNK" not in r["portfolio"].holdings  # rotated out


def test_aborts_when_real_data_required_but_unavailable(tmp_path, monkeypatch):
    # USE_KITE_DATA on but no keys -> synthetic -> MUST abort and not write state
    pf_path = tmp_path / "pf.json"
    monkeypatch.setattr(config, "PORTFOLIO_JSON", pf_path)
    monkeypatch.setattr(config, "USE_KITE_DATA", True)
    monkeypatch.setattr(config, "KITE_API_KEY", "")
    result = run_paper_session(verbose=False)
    assert result.get("aborted") is True
    assert not pf_path.exists()  # portfolio left untouched / not created
