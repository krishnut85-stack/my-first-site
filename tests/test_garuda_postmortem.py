"""Tests for Garuda's post-mortem: trade pairing, diagnosis, lessons log."""

from garuda import postmortem


def _dated(start_day, closes, month="2026-07"):
    return [(f"{month}-{start_day + i:02d}", c) for i, c in enumerate(closes)]


# --- pairing ---------------------------------------------------------------
def test_closed_trades_pairs_and_derives_entry():
    trades = [
        {"date": "2026-07-01", "side": "BUY", "symbol": "AAA", "qty": 10,
         "price": 100.0},
        {"date": "2026-07-09", "side": "SELL", "symbol": "AAA", "qty": 10,
         "price": 90.0, "reason": "20% stop-loss", "pnl": -100.0},
    ]
    out = postmortem.closed_trades(trades)
    assert len(out) == 1
    t = out[0]
    assert t["entry_price"] == 100.0 and t["pnl_pct"] == -10.0
    assert t["days_held"] == 8


def test_closed_trades_scalein_blended_entry():
    # two BUYs (average-down) then one SELL — entry must be the TRUE blend,
    # derived from the SELL's pnl, and entry_date the FIRST buy.
    trades = [
        {"date": "2026-07-01", "side": "BUY", "symbol": "SCL", "qty": 10,
         "price": 100.0},
        {"date": "2026-07-03", "side": "BUY", "symbol": "SCL", "qty": 10,
         "price": 80.0},
        {"date": "2026-07-08", "side": "SELL", "symbol": "SCL", "qty": 20,
         "price": 95.0, "reason": "RSI recovered", "pnl": 100.0},
    ]
    t = postmortem.closed_trades(trades)[0]
    assert t["entry_price"] == 90.0        # (100*10 + 80*10) / 20
    assert t["entry_date"] == "2026-07-01"
    assert t["qty"] == 20


def test_closed_trades_ignores_sell_without_buy():
    assert postmortem.closed_trades(
        [{"date": "2026-07-01", "side": "SELL", "symbol": "X", "qty": 1,
          "price": 10.0, "pnl": -1.0}]) == []


# --- diagnosis -------------------------------------------------------------
def _trade(**kw):
    base = {"symbol": "AAA", "qty": 10, "entry_date": "2026-07-02",
            "entry_price": 100.0, "exit_date": "2026-07-08",
            "exit_price": 90.0, "reason": "20% stop-loss",
            "pnl": -100.0, "pnl_pct": -10.0, "days_held": 6}
    base.update(kw)
    return base


def test_gap_shock_flagged():
    dated = _dated(1, [100, 100, 99, 98, 97, 96, 88, 88])
    lesson = postmortem.analyze_trade(_trade(), dated)
    assert "gap_shock" in lesson["causes"]
    assert lesson["worst_day_pct"] <= -6.0


def test_knife_flagged_when_it_never_worked():
    dated = _dated(1, [100, 100, 98, 96, 94, 92, 91, 90])
    lesson = postmortem.analyze_trade(_trade(), dated)
    assert "knife" in lesson["causes"]


def test_gave_back_flagged_on_surrendered_gain():
    dated = _dated(1, [100, 100, 108, 112, 105, 98, 92, 90])
    lesson = postmortem.analyze_trade(_trade(), dated)
    assert "gave_back" in lesson["causes"]
    assert lesson["mfe_pct"] == 12.0


def test_winner_giveback_from_wide_trail():
    # exited +5% but peaked +20%: the wide-trail cost is a lesson too
    dated = _dated(1, [100, 100, 110, 120, 115, 108, 106, 105])
    lesson = postmortem.analyze_trade(
        _trade(exit_price=105.0, reason="25% trailing stop",
               pnl=50.0, pnl_pct=5.0), dated)
    assert "gave_back" in lesson["causes"]


def test_dead_money_on_time_exit():
    dated = _dated(1, [100, 100, 101, 100, 101, 100, 101, 101])
    lesson = postmortem.analyze_trade(
        _trade(exit_price=101.0, reason="180-day hold",
               pnl=10.0, pnl_pct=1.0, days_held=180), dated)
    assert "dead_money" in lesson["causes"]


def test_rotation_exit_is_by_design():
    dated = _dated(1, [100, 100, 99, 97, 96, 95, 95, 95])
    lesson = postmortem.analyze_trade(
        _trade(exit_price=95.0, reason="monthly rotation",
               pnl=-50.0, pnl_pct=-5.0), dated)
    assert "by_design" in lesson["causes"]
    assert "knife" not in lesson["causes"]     # rotation red ≠ a failed entry


def test_survives_missing_history():
    lesson = postmortem.analyze_trade(_trade(), [])
    assert lesson["diagnosis"]                 # reason-only fallback, no crash


# --- persistence + entry point --------------------------------------------
def test_post_mortem_logs_losers_only(tmp_path):
    trades = [
        {"date": "2026-07-01", "side": "BUY", "symbol": "LOSS", "qty": 10,
         "price": 100.0},
        {"date": "2026-07-08", "side": "SELL", "symbol": "LOSS", "qty": 10,
         "price": 90.0, "reason": "20% stop-loss", "pnl": -100.0},
        {"date": "2026-07-01", "side": "BUY", "symbol": "WIN", "qty": 10,
         "price": 100.0},
        {"date": "2026-07-08", "side": "SELL", "symbol": "WIN", "qty": 10,
         "price": 108.0, "reason": "RSI recovered", "pnl": 80.0},
    ]
    sells = [{"symbol": "LOSS", "price": 90.0, "pnl": -100.0,
              "reason": "20% stop-loss"},
             {"symbol": "WIN", "price": 108.0, "pnl": 80.0,
              "reason": "RSI recovered"}]
    dated = {"LOSS": _dated(1, [100, 100, 98, 96, 94, 92, 91, 90]),
             "WIN": _dated(1, [100, 100, 103, 105, 106, 107, 108, 108])}
    lessons = postmortem.post_mortem("smallcap", sells, trades, dated,
                                     data_dir=tmp_path)
    assert [l["symbol"] for l in lessons] == ["LOSS"]     # clean winner skipped
    saved = postmortem.read_lessons("smallcap", data_dir=tmp_path)
    assert len(saved) == 1 and saved[0]["symbol"] == "LOSS"
    assert "knife" in saved[0]["causes"]


def test_read_lessons_missing_file_is_empty(tmp_path):
    assert postmortem.read_lessons("nope", data_dir=tmp_path) == []
