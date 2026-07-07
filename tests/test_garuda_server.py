"""Tests for Garuda's live dashboard: state assembly + the token-gated server."""

import json
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from garuda import config
from garuda import server as srv
from garuda.live import GarudaLive


def test_build_state_offline(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))          # no Kite -> offline feed
    live.portfolios["smallcap"].buy("KEI", 10, 100.0, entry_len=250)
    st = live.build_state()
    assert len(st["profiles"]) == 6   # + next50 + strength + leaders + scalein
    sc = next(p for p in st["profiles"] if p["key"] == "smallcap")
    assert sc["name"] == "Garuda-SC"
    assert sc["positions"] and sc["positions"][0]["sym"] == "KEI"
    assert sc["positions"][0]["ltp"] == 100.0          # offline -> priced at entry


def test_chart_falls_back_to_local_csv(tmp_path, monkeypatch):
    # No Kite feed -> ohlc_daily returns []; the chart must still draw from the
    # local CSV closes so clicking a share always shows a candle chart.
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    live.dated_by_sym["KEI"] = [(f"2026-{(i // 28) + 1:02d}-{(i % 28) + 1:02d}", 100.0 + i)
                                for i in range(40)]
    ch = live.chart_for("KEI")
    assert ch and ch["candles"] and len(ch["candles"]) == 40
    assert all({"t", "o", "h", "l", "c"} <= set(c) for c in ch["candles"])
    assert "markers" in ch
    assert live.chart_for("UNKNOWN") is None      # nothing to draw -> None, no crash


def test_win_rate_shows_backtest_until_live_trades(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    pf = live.portfolios["smallcap"]
    pf.buy("UP", 10, 100.0, entry_len=250)        # in profit
    pf.buy("DN", 10, 100.0, entry_len=250)        # at a loss
    live.prices = {"UP": 110.0, "DN": 90.0}
    sc = next(p for p in live.build_state()["profiles"] if p["key"] == "smallcap")
    # no closed trades yet -> headline win rate is the validated backtest figure,
    # with the live "green now" ratio exposed separately.
    assert sc["win"] == 66 and sc["win_kind"] == "backtest"
    assert sc["win_open"] == 50                    # 1 of 2 positions green right now


def test_day_pnl_resets_each_day_via_equity_baseline(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    pf = live.portfolios["smallcap"]
    pf.buy("KEI", 10, 100.0, entry_len=250)
    live.prices["KEI"] = 100.0
    sc1 = next(p for p in live.build_state()["profiles"] if p["key"] == "smallcap")
    assert sc1["day_pnl"] == 0                     # first build of the day -> baseline, 0
    live.prices["KEI"] = 105.0                     # +5 * 10 = +50 during the day
    sc2 = next(p for p in live.build_state()["profiles"] if p["key"] == "smallcap")
    assert sc2["day_pnl"] == 50
    live.day_base_date = "2000-01-01"              # simulate a new trading day
    sc3 = next(p for p in live.build_state()["profiles"] if p["key"] == "smallcap")
    assert sc3["day_pnl"] == 0                     # re-baselined -> resets, even at the same price


def test_state_exposes_index_reading(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    # offline -> no Kite -> empty index, but the key is always present so the
    # header can render a live Nifty reading when the feed is live.
    st = live.build_state()
    assert st["index"] == {}
    live.index = {"NIFTY 50": {"ltp": 24832.30, "pc": 24720.0, "chg": 0.45}}
    assert live.build_state()["index"]["NIFTY 50"]["chg"] == 0.45


def test_market_hours_gate():
    from datetime import datetime
    from garuda.market import is_market_open, is_trading_day, HOLIDAYS
    sat = datetime(2026, 7, 4, 11, 0)          # Saturday, mid-day
    mon_open = datetime(2026, 7, 6, 11, 0)     # Monday, 11:00 IST
    mon_pre = datetime(2026, 7, 6, 8, 50)      # Monday, before 09:15
    mon_post = datetime(2026, 7, 6, 16, 0)     # Monday, after 15:30
    assert not is_market_open(sat) and not is_trading_day(sat)
    assert is_market_open(mon_open)
    assert not is_market_open(mon_pre) and not is_market_open(mon_post)
    HOLIDAYS.add("2026-07-06")
    try:
        assert not is_market_open(mon_open)    # holiday overrides
    finally:
        HOLIDAYS.discard("2026-07-06")
    # a seeded fixed NSE holiday (Republic Day, a weekday) is closed all day
    from garuda.market import market_status
    rep = datetime(2026, 1, 26, 11, 0)
    assert "2026-01-26" in HOLIDAYS
    assert not is_market_open(rep)
    assert market_status(rep) == "CLOSED · NSE HOLIDAY"


def test_scan_books_nothing_when_market_closed(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    monkeypatch.setattr("garuda.live.is_market_open", lambda *a: False)
    live = GarudaLive(csv_dir=str(tmp_path))
    live.series_by_sym["KEI"] = [100.0 - i * 0.5 for i in range(60)]  # oversold-ish
    res = live.scan()                          # market closed -> no trades
    assert all("status" in v for v in res.values())
    assert not any(pf.holdings for pf in live.portfolios.values())
    assert live.build_state()["market_open"] is False


def test_server_token_gate():
    srv._TOKEN["value"] = "secret"
    srv._STATE["json"] = json.dumps({"profiles": []}).encode()
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), srv.Handler)
    port = httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    try:
        base = f"http://127.0.0.1:{port}"
        assert urllib.request.urlopen(base + "/health").read() == b"ok"
        try:
            urllib.request.urlopen(base + "/data")
            assert False, "should have been denied"
        except urllib.error.HTTPError as e:
            assert e.code == 403
        r = urllib.request.urlopen(base + "/data?token=secret")
        assert r.status == 200 and json.loads(r.read()) == {"profiles": []}
        # the dashboard page also requires the token
        r2 = urllib.request.urlopen(base + "/?token=secret")
        assert b"GARUDA" in r2.read()
    finally:
        httpd.shutdown()
