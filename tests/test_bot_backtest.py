"""End-to-end-ish tests for the simulation, backtest and email builder."""

import shutil

from sectorbot import config
from sectorbot.backtest import run_backtest
from sectorbot.bot import run_simulation
from sectorbot.notify import build_email


def test_simulation_runs_and_reports():
    result = run_simulation(steps=5, verbose=False)
    assert result["picks"], "should select at least one industry"
    assert result["invested"] > 0
    assert "pnl" in result and "pnl_pct" in result
    # in unlimited mode every pick gets a notional allocation
    assert len(result["broker"].trades) >= len(result["picks"])


def test_backtest_needs_two_snapshots(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "SNAPSHOTS_DIR", tmp_path)
    out = run_backtest(verbose=False)
    assert out["ok"] is False


def test_backtest_with_two_snapshots(tmp_path, monkeypatch):
    # build two snapshots from the bundled data so the walk-forward has a pair
    snap_dir = tmp_path
    shutil.copy(config.DATA_CSV, snap_dir / "2026-06-20.csv")
    shutil.copy(config.DATA_CSV, snap_dir / "2026-06-21.csv")
    monkeypatch.setattr(config, "SNAPSHOTS_DIR", snap_dir)
    out = run_backtest(verbose=False)
    assert out["ok"] is True
    assert out["days"] == 1
    assert "strategy_return_pct" in out


def test_email_builder_produces_subject_and_bodies():
    result = run_simulation(steps=3, verbose=False)
    subject, plain, html = build_email(result)
    assert "SectorBot" in subject
    assert "PAPER" in plain
    assert "<html" in html
    assert config.EMAIL_TO  # recipient configured
