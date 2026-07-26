"""Tests for the post-mortem + self-healing backtest (sectorbot/postmortem.py)."""

from sectorbot import config, postmortem
from sectorbot.indicators import Bar
from sectorbot.portfolio import Portfolio


def _bar(date, close, prev=None):
    spread = close * 0.01
    return Bar(high=close + spread, low=close - spread, close=close, date=date)


def _pf_with_trades(trades):
    pf = Portfolio(1_000_000.0, 1_000_000.0)
    pf.trades = trades
    return pf


CFG = dict(stop=0.08, trail_arm=0.10, trail_give=0.10, tp=1.00,
           hold_days=10, time_min=0.05)


# --- trade pairing ---------------------------------------------------------
def test_closed_trades_pairs_buy_with_sell():
    pf = _pf_with_trades([
        {"date": "2026-07-01", "side": "BUY", "symbol": "AAA", "qty": 10,
         "price": 100.0, "reason": "entry"},
        {"date": "2026-07-02", "side": "BUY", "symbol": "BBB", "qty": 5,
         "price": 200.0, "reason": "entry"},
        {"date": "2026-07-10", "side": "SELL", "symbol": "AAA", "qty": 10,
         "price": 90.0, "reason": "stop-loss -10.0%", "pnl": -100.0},
    ])
    closed = postmortem.closed_trades(pf)
    assert len(closed) == 1
    t = closed[0]
    assert t["symbol"] == "AAA"
    assert t["entry_price"] == 100.0 and t["exit_price"] == 90.0
    assert t["pnl_pct"] == -10.0
    assert t["days_held"] == 9


def test_closed_trades_ignores_sell_without_buy():
    pf = _pf_with_trades([
        {"date": "2026-07-10", "side": "SELL", "symbol": "GHOST", "qty": 1,
         "price": 50.0, "reason": "stop-loss", "pnl": -5.0},
    ])
    assert postmortem.closed_trades(pf) == []


# --- replay ---------------------------------------------------------------
def test_simulate_exit_stop_loss_fires():
    bars = [_bar("2026-07-02", 98.0), _bar("2026-07-03", 91.0),
            _bar("2026-07-04", 85.0)]
    price, reason, held = postmortem.simulate_exit(100.0, bars, CFG)
    assert reason == "stop-loss" and price == 91.0 and held == 2


def test_simulate_exit_trailing_stop_locks_gain():
    bars = [_bar("2026-07-02", 105.0), _bar("2026-07-03", 115.0),
            _bar("2026-07-04", 103.0)]
    price, reason, _ = postmortem.simulate_exit(100.0, bars, CFG)
    assert reason == "trailing-stop" and price == 103.0


def test_simulate_exit_time_stop_on_dead_money():
    bars = [_bar(f"2026-07-{d:02d}", 101.0) for d in range(1, 13)]
    price, reason, held = postmortem.simulate_exit(100.0, bars, CFG)
    assert reason == "time stop" and held == CFG["hold_days"]


def test_simulate_exit_still_open_when_nothing_fires():
    bars = [_bar("2026-07-02", 104.0), _bar("2026-07-03", 106.0)]
    _, reason, _ = postmortem.simulate_exit(100.0, bars, CFG)
    assert reason == "open"


# --- diagnosis ------------------------------------------------------------
def test_analyze_trade_flags_gap_shock():
    trade = {"symbol": "AAA", "entry_date": "2026-07-01", "entry_price": 100.0,
             "exit_date": "2026-07-03", "exit_price": 88.0, "qty": 10,
             "reason": "stop-loss -12.0%", "pnl": -120.0, "pnl_pct": -12.0,
             "days_held": 2}
    bars = [_bar("2026-06-30", 100.0), _bar("2026-07-01", 100.0),
            _bar("2026-07-02", 99.0), _bar("2026-07-03", 88.0)]
    lesson = postmortem.analyze_trade(trade, bars, CFG)
    assert "gap_shock" in lesson["causes"]
    assert lesson["worst_day_pct"] <= -6.0


def test_analyze_trade_flags_giving_back_gains():
    trade = {"symbol": "AAA", "entry_date": "2026-07-01", "entry_price": 100.0,
             "exit_date": "2026-07-05", "exit_price": 95.0, "qty": 10,
             "reason": "stop-loss -5.0%", "pnl": -50.0, "pnl_pct": -5.0,
             "days_held": 4}
    bars = [_bar("2026-07-01", 100.0), _bar("2026-07-02", 108.0),
            _bar("2026-07-03", 112.0), _bar("2026-07-04", 100.0),
            _bar("2026-07-05", 95.0)]
    lesson = postmortem.analyze_trade(trade, bars, CFG)
    assert "gave_back_gains" in lesson["causes"]
    assert lesson["mfe_pct"] == 12.0


def test_analyze_trade_flags_dead_money():
    trade = {"symbol": "AAA", "entry_date": "2026-07-01", "entry_price": 100.0,
             "exit_date": "2026-07-11", "exit_price": 100.5, "qty": 10,
             "reason": "time stop (10d, +0.5%)", "pnl": 5.0, "pnl_pct": 0.5,
             "days_held": 10}
    bars = [_bar(f"2026-07-{d:02d}", 100.5) for d in range(1, 12)]
    lesson = postmortem.analyze_trade(trade, bars, CFG)
    assert "dead_money" in lesson["causes"]


def test_analyze_trade_survives_undated_bars():
    trade = {"symbol": "AAA", "entry_date": "2026-07-01", "entry_price": 100.0,
             "exit_date": "2026-07-03", "exit_price": 90.0, "qty": 10,
             "reason": "stop-loss", "pnl": -100.0, "pnl_pct": -10.0,
             "days_held": 2}
    bars = [Bar(101, 99, 100)]     # synthetic feed: no dates
    lesson = postmortem.analyze_trade(trade, bars, CFG)
    assert lesson["diagnosis"]     # falls back to reason-only diagnosis


# --- lessons persistence --------------------------------------------------
def test_log_and_read_lessons(tmp_path):
    postmortem.log_lesson({"symbol": "AAA", "diagnosis": "x"}, folder=tmp_path)
    postmortem.log_lesson({"symbol": "BBB", "diagnosis": "y"}, folder=tmp_path)
    lessons = postmortem.read_lessons(folder=tmp_path)
    assert [l["symbol"] for l in lessons] == ["AAA", "BBB"]


# --- tuning bounds --------------------------------------------------------
def test_clamp_tuning_enforces_bounds():
    out = postmortem.clamp_tuning({"stop": 0.50, "trail_arm": 0.01,
                                   "hold_days": 500, "tp": 0.0})
    assert out["stop"] == 0.15          # can't loosen the stop past 15%
    assert out["trail_arm"] == 0.06     # can't arm below 6%
    assert out["hold_days"] == 60       # time stop can't be pushed out forever
    assert "tp" not in out              # non-tunable keys are dropped


def test_candidate_grid_stays_in_bounds():
    base = dict(stop=0.14, trail_arm=0.19, trail_give=0.15, hold_days=55,
                tp=1.0, time_min=0.05)
    for cand in postmortem._candidate_grid(base):
        for k in postmortem.TUNABLE:
            lo, hi = postmortem.BOUNDS[k]
            assert lo <= cand[k] <= hi


# --- the healer's refusals ------------------------------------------------
class _FakeDS:
    """Real-data stand-in: dated bars per symbol."""
    def __init__(self, bars_by_symbol):
        self._bars = bars_by_symbol

    def history(self, symbol, bars):
        return self._bars.get(symbol, [])


def test_heal_refuses_on_too_few_trades():
    pf = _pf_with_trades([
        {"date": "2026-07-01", "side": "BUY", "symbol": "AAA", "qty": 10,
         "price": 100.0},
        {"date": "2026-07-05", "side": "SELL", "symbol": "AAA", "qty": 10,
         "price": 90.0, "reason": "stop-loss", "pnl": -100.0},
    ])
    report = postmortem.heal(_FakeDS({}), pf, CFG, min_trades=8)
    assert not report["ok"]
    assert "8+" in report["message"]


def test_heal_refuses_on_synthetic_data():
    from sectorbot.datasource import PaperDataSource
    pf = _pf_with_trades([])
    report = postmortem.heal(PaperDataSource(), pf, CFG)
    assert not report["ok"] and "Kite" in report["message"]


def test_heal_finds_tighter_stop_when_it_helps():
    # 8 identical losers: entry 100 → 94 (−6%) → 85 (−15%). The 6% stop gets
    # out at 94; the base 8% stop only fires on the next bar at 85.
    trades, bars = [], {}
    for i in range(8):
        sym = f"S{i}"
        trades += [
            {"date": "2026-06-01", "side": "BUY", "symbol": sym, "qty": 10,
             "price": 100.0},
            {"date": "2026-06-10", "side": "SELL", "symbol": sym, "qty": 10,
             "price": 85.0, "reason": "stop-loss", "pnl": -150.0},
        ]
        bars[sym] = [_bar("2026-06-01", 100.0), _bar("2026-06-02", 94.0),
                     _bar("2026-06-03", 85.0), _bar("2026-06-04", 84.0)]
    pf = _pf_with_trades(trades)
    report = postmortem.heal(_FakeDS(bars), pf, CFG, min_trades=8,
                             min_improve=1.0)
    assert report["ok"] and report["improved"]
    assert report["changes"].get("stop") == 0.06
    assert report["best"]["avg"] > report["base"]["avg"]


def test_save_and_load_tuning_roundtrip(tmp_path):
    report = {"n": 10, "base": {"avg": -1.0}, "best": {"avg": 0.5}}
    postmortem.save_tuning({"stop": 0.06, "hold_days": 25}, report,
                           folder=tmp_path)
    loaded = postmortem.load_tuning(folder=tmp_path)
    assert loaded == {"stop": 0.06, "hold_days": 25}
    # a second heal merges on top and history accumulates
    postmortem.save_tuning({"stop": 0.08}, report, folder=tmp_path)
    assert postmortem.load_tuning(folder=tmp_path)["stop"] == 0.08
    import json
    hist = json.loads((tmp_path / "tuning.json").read_text())["history"]
    assert len(hist) == 2
