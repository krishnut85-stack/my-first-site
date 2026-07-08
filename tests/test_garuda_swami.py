"""Tests for the SWAMINATHA guest tab — read-only mirror of Mayura's news face."""

import json

from garuda.live import GarudaLive


def _write_swami(tmp_path):
    d = {
        "starting_capital": 500000.0,
        "cash": 350000.0,
        "holdings": {
            "TRANSRAIL": {"qty": 100, "avg_price": 500.0,
                          "entry_date": "2026-07-01", "peak_price": 520.0,
                          "atr": 12.0, "breakout_level": None},
        },
        "realized_pnl": 12500.0,
        "history": [{"date": "2026-07-01", "equity": 500000.0}],
        "trades": [
            {"date": "2026-07-01", "side": "BUY", "symbol": "TRANSRAIL",
             "qty": 100, "price": 500.0,
             "reason": "Transrail Lighting secures ~Rs 459 cr MENA order"},
        ],
    }
    p = tmp_path / "mayura_data" / "swaminatha" / "portfolio.json"
    p.parent.mkdir(parents=True)
    p.write_text(json.dumps(d))
    return p


def test_swami_tab_state(tmp_path, monkeypatch):
    p = _write_swami(tmp_path)
    monkeypatch.setenv("SWAMINATHA_PORTFOLIO", str(p))
    g = GarudaLive(csv_dir="/nonexistent")
    g.prices["TRANSRAIL"] = 550.0                     # live LTP via Garuda's feed
    s = g.swaminatha_state()
    assert s["capital"] == 500000 and s["cash"] == 350000
    assert s["realized"] == 12500
    pos = s["positions"][0]
    assert pos["sym"] == "TRANSRAIL" and pos["ltp"] == 550.0
    assert pos["pnl"] == 5000 and pos["chg"] == 10.0  # (550-500)*100
    assert s["equity"] == 350000 + 55000
    assert s["unrealized"] == 5000
    # newest-first trade log carries the actual news headline
    assert "MENA order" in s["trades"][0]["reason"]
    # swaminatha's names join the live-pricing set
    assert "TRANSRAIL" in g.held_symbols()
    # and the guest book rides into the dashboard state
    state = g.build_state()
    assert state["swaminatha"]["positions"][0]["sym"] == "TRANSRAIL"


def test_swami_tab_absent_is_none(monkeypatch, tmp_path):
    monkeypatch.setenv("SWAMINATHA_PORTFOLIO", str(tmp_path / "missing.json"))
    monkeypatch.setattr("garuda.live.Path.cwd", staticmethod(lambda: tmp_path))
    monkeypatch.setattr("garuda.live.Path.home", staticmethod(lambda: tmp_path))
    g = GarudaLive(csv_dir="/nonexistent")
    assert g.swaminatha_state() is None
    assert g.build_state()["swaminatha"] is None
