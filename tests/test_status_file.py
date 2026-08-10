"""cmd_statusfile writes mayura_status.json with per-face P&L and, for every
holding, the trailing-stop state (peak, armed?, exact exit price) — the file a
remote session reads to check performance without SSH."""

import json

import mayura
from sectorbot.portfolio import Portfolio


class _FakeDS:
    """Deterministic prices; not a PaperDataSource so real_kite_data=True."""

    def last_prices(self, symbols):
        return {"WINNER": 110.0, "LOSER": 190.0}


def test_statusfile_writes_pnl_and_trail_state(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path / "mayura_data")
    monkeypatch.setattr(mayura, "REPO_ROOT", tmp_path)
    monkeypatch.setattr("sectorbot.datasource.get_datasource", lambda: _FakeDS())

    # Dandapani (stop 8%, trail arms +10%, gives back 10%) holds two stocks:
    # WINNER peaked +22% (trail armed), LOSER never rose (trail not armed).
    folder = tmp_path / "mayura_data" / "dandapani"
    folder.mkdir(parents=True)
    pf = Portfolio(1_000_000, 1_000_000 - 10 * 100 - 5 * 200, holdings={
        "WINNER": {"qty": 10, "avg_price": 100.0, "entry_date": "2026-08-01",
                   "peak_price": 122.0, "atr": 0.0},
        "LOSER": {"qty": 5, "avg_price": 200.0, "entry_date": "2026-08-01",
                  "peak_price": 200.0, "atr": 0.0},
    })
    pf.save(folder / "portfolio.json")

    mayura.cmd_statusfile()

    out = json.loads((tmp_path / "mayura_status.json").read_text())
    assert out["paper_only"] is True
    assert out["real_kite_data"] is True
    assert set(out["faces"]) == set(mayura.STRATEGY_ORDER)

    face = out["faces"]["dandapani"]
    assert face["open_positions"] == 2
    # equity = cash + 10×110 + 5×190
    assert face["equity"] == pf.cash + 10 * 110 + 5 * 190
    # unrealised: WINNER +100, LOSER −50
    assert face["unrealized"] == 100 - 50

    by_sym = {h["symbol"]: h for h in face["holdings"]}
    w, l = by_sym["WINNER"], by_sym["LOSER"]
    # WINNER: peak +22% ≥ +10% arm → trail live, exits 10% below the 122 peak.
    assert w["trail_armed"] is True
    assert w["trail_exit"] == round(122.0 * 0.90, 2)
    assert w["locked_pct"] == round((122.0 * 0.90 - 100) / 100 * 100, 2)
    assert w["hard_stop"] == round(100 * 0.92, 2)
    # LOSER: never reached the arm threshold → only the hard stop protects it.
    assert l["trail_armed"] is False
    assert l["trail_exit"] is None and l["locked_pct"] is None
    # holdings sorted best-first
    assert face["holdings"][0]["symbol"] == "WINNER"

    # Faces with no portfolio.json fall back to an untouched ₹10L book.
    assert out["faces"]["senthil"]["equity"] == 1_000_000
    assert out["faces"]["senthil"]["open_positions"] == 0
