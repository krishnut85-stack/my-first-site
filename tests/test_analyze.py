"""The Mayura self-review (`analyze`): per-face closed-trade stats, exit-reason
buckets, an honest verdict, and the pause mechanics (auto-pause only with
MAYURA_AUTO_PAUSE=1; a paused face runs exits but opens no new buys)."""

import json

import mayura
from sectorbot.portfolio import Portfolio


def _face_dir(tmp_path, monkeypatch, key="dandapani"):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path / "mayura_data")
    monkeypatch.setattr(mayura, "REPO_ROOT", tmp_path)
    folder = tmp_path / "mayura_data" / key
    folder.mkdir(parents=True)
    return folder


def _sell(sym, pnl, reason, day="2026-08-01"):
    return {"date": day, "side": "SELL", "symbol": sym, "qty": 1,
            "price": 100.0, "reason": reason, "pnl": pnl}


def test_analyze_metrics_and_buckets(tmp_path, monkeypatch):
    folder = _face_dir(tmp_path, monkeypatch)
    trades = ([_sell("W", +1000, "trailing-stop (locked +9.8%)")] * 3
              + [_sell("L", -500, "stop-loss -8.0%")] * 6
              + [_sell("T", -100, "time stop (10d, +1.2%)")])
    Portfolio(1_000_000, 1_000_000, trades=trades,
              history=[{"date": "2026-08-01", "equity": 1_000_000},
                       {"date": "2026-08-02", "equity": 940_000}]
              ).save(folder / "portfolio.json")
    mayura._use_strategy("dandapani")
    a = mayura._analyze_face(days=90)
    assert a["sells"] == 10 and a["wins"] == 3 and a["losses"] == 7
    assert a["reasons"]["trailing stop"]["n"] == 3
    assert a["reasons"]["hard stop"]["n"] == 6
    assert a["reasons"]["time stop"]["n"] == 1
    assert a["net"] == 3 * 1000 - 6 * 500 - 100
    assert round(a["profit_factor"], 3) == round(3000 / 3100, 3)
    assert a["drawdown"] == (1_000_000 - 940_000) / 1_000_000


def test_verdict_sick_and_healthy():
    sick = {"days": 90, "sells": 12, "wins": 3, "losses": 9, "win_rate": 0.25,
            "avg_win": 300.0, "avg_loss": 400.0, "profit_factor": 0.6,
            "expectancy": -150.0, "net": -1800.0, "drawdown": 0.02,
            "reasons": {"hard stop": {"n": 8, "pnl": -3200.0}},
            "best": None, "worst": None}
    verdict, tips = mayura._face_verdict(sick)
    assert verdict == "SICK"
    assert any("LOSING" in t for t in tips)
    healthy = {**sick, "win_rate": 0.6, "profit_factor": 1.8, "net": 4000.0,
               "avg_win": 800.0, "avg_loss": 400.0, "drawdown": 0.03,
               "reasons": {"trailing stop": {"n": 8, "pnl": 4000.0}}}
    assert mayura._face_verdict(healthy)[0] == "HEALTHY"
    early = {**sick, "sells": 3}
    assert mayura._face_verdict(early)[0] == "TOO EARLY"


def test_auto_pause_only_when_opted_in(tmp_path, monkeypatch):
    folder = _face_dir(tmp_path, monkeypatch)
    Portfolio(1_000_000, 1_000_000,
              trades=[_sell("L", -500, "stop-loss -8.0%")] * 12
              ).save(folder / "portfolio.json")
    sent = []
    monkeypatch.setattr("sectorbot.telegram.send_telegram",
                        lambda text, **kw: sent.append(text) or True)
    mayura._use_strategy("dandapani")

    monkeypatch.delenv("MAYURA_AUTO_PAUSE", raising=False)
    mayura.cmd_analyze()
    assert not mayura._pause_file().exists()      # opt-in only — no file

    monkeypatch.setenv("MAYURA_AUTO_PAUSE", "1")
    mayura.cmd_analyze()
    assert mayura._pause_file().exists()          # SICK + opted in → paused
    assert json.loads(mayura._pause_file().read_text())["by"] == "self-review"
    assert any("AUTO-PAUSED" in m for m in sent)

    mayura.cmd_unpause()
    assert not mayura._pause_file().exists()


def test_pause_and_unpause_commands(tmp_path, monkeypatch):
    _face_dir(tmp_path, monkeypatch, key="senthil")
    mayura._use_strategy("senthil")
    mayura.cmd_pause()
    assert mayura._pause_file().exists()
    assert json.loads(mayura._pause_file().read_text())["by"] == "manual"
    mayura.cmd_unpause()
    assert not mayura._pause_file().exists()
