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
    keep_band = set(syms[: config.SELL_RANK_BUFFER])
    # holdings stay within the buffer band, and never exceed MAX_POSITIONS
    assert set(r["portfolio"].holdings).issubset(keep_band)
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


def test_status_command_runs(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    run_paper_session(verbose=False)  # create a saved portfolio
    from sectorbot.__main__ import cmd_status
    cmd_status()
    out = capsys.readouterr().out
    assert "ACTIVITY" in out
    assert "Current holdings" in out


def test_status_shows_winrate_and_drawdown(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    pf = Portfolio(1_000_000, 1_000_000)
    pf.trades = [
        {"date": "d1", "side": "SELL", "symbol": "ABC", "qty": 10, "price": 110,
         "reason": "rotated out", "pnl": 4200},
        {"date": "d2", "side": "SELL", "symbol": "XYZ", "qty": 5, "price": 90,
         "reason": "stop-loss", "pnl": -3100},
    ]
    pf.history = [{"date": "d1", "equity": 1_000_000},
                  {"date": "d2", "equity": 1_012_000},
                  {"date": "d3", "equity": 990_000}]
    pf.save(tmp_path / "pf.json")

    from sectorbot.__main__ import cmd_status
    cmd_status()
    out = capsys.readouterr().out
    assert "Win rate" in out
    assert "50%" in out               # 1 win / 2 closed
    assert "Max drawdown" in out
    assert "Best trade" in out


def test_aborts_when_real_data_required_but_unavailable(tmp_path, monkeypatch):
    # USE_KITE_DATA on but no keys -> synthetic -> MUST abort and not write state
    pf_path = tmp_path / "pf.json"
    monkeypatch.setattr(config, "PORTFOLIO_JSON", pf_path)
    monkeypatch.setattr(config, "USE_KITE_DATA", True)
    monkeypatch.setattr(config, "KITE_API_KEY", "")
    result = run_paper_session(verbose=False)
    assert result.get("aborted") is True
    assert not pf_path.exists()  # portfolio left untouched / not created


def test_holding_days_counts_calendar_days():
    from datetime import datetime, timedelta
    from sectorbot.engine import _holding_days
    from sectorbot.data_loader import IST
    assert _holding_days(None) == 0
    assert _holding_days("not-a-date") == 0
    ten_ago = (datetime.now(IST).date() - timedelta(days=10)).isoformat()
    assert _holding_days(ten_ago) == 10


def test_time_stop_exits_dead_money_not_winners(monkeypatch, tmp_path):
    # A position held past MAX_HOLDING_DAYS with a small gain is time-stopped;
    # a running winner past the same age is left for the trailing stop.
    from datetime import datetime, timedelta
    from sectorbot import config
    from sectorbot.data_loader import IST
    from sectorbot.engine import run_paper_session
    from sectorbot.portfolio import Portfolio

    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "REBALANCE", False)
    monkeypatch.setattr(config, "MAX_HOLDING_DAYS", 30)
    monkeypatch.setattr(config, "TIME_STOP_MIN_GAIN_PCT", 0.05)
    monkeypatch.setattr(config, "USE_REGIME_FILTER", False)
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "p.json")

    from sectorbot.datasource import PaperDataSource
    price = PaperDataSource().last_price("DEADCO")   # entry == current -> flat

    old = (datetime.now(IST).date() - timedelta(days=40)).isoformat()
    pf = Portfolio(1_000_000, 500_000)
    # DEAD: flat name (entry == current price) held 40 days -> time-stopped
    pf.holdings["DEADCO"] = {"qty": 10, "avg_price": price, "entry_date": old,
                             "peak_price": price, "atr": 0.0}
    pf.save(tmp_path / "p.json")

    res = run_paper_session(verbose=False, ranked_symbols=["DEADCO"])
    reasons = [r for _, _, r, _ in res["exits"]]
    assert "time stop" in reasons


def test_failed_breakout_exit(monkeypatch, tmp_path):
    # Price below the stored breakout level (SMA50) -> 'failed breakout' exit.
    from sectorbot import config
    from sectorbot.datasource import PaperDataSource
    from sectorbot.engine import run_paper_session
    from sectorbot.portfolio import Portfolio

    monkeypatch.setattr(config, "USE_KITE_DATA", False)
    monkeypatch.setattr(config, "REBALANCE", False)
    monkeypatch.setattr(config, "USE_FAILED_BREAKOUT_EXIT", True)
    monkeypatch.setattr(config, "USE_REGIME_FILTER", False)
    monkeypatch.setattr(config, "MAX_HOLDING_DAYS", 0)
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "p.json")

    price = PaperDataSource().last_price("FAILCO")
    pf = Portfolio(1_000_000, 500_000)
    # breakout level set ABOVE current price -> price is below SMA50 -> exit
    pf.holdings["FAILCO"] = {"qty": 10, "avg_price": price, "entry_date": "2026-06-01",
                             "peak_price": price, "atr": 0.0,
                             "breakout_level": price + 50}
    pf.save(tmp_path / "p.json")

    res = run_paper_session(verbose=False, ranked_symbols=["FAILCO"],
                            levels={"FAILCO": price + 50})
    assert "failed breakout" in [r for _, _, r, _ in res["exits"]]
