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
    assert len(st["profiles"]) == 2
    sc = next(p for p in st["profiles"] if p["key"] == "smallcap")
    assert sc["name"] == "Garuda-SC"
    assert sc["positions"] and sc["positions"][0]["sym"] == "KEI"
    assert sc["positions"][0]["ltp"] == 100.0          # offline -> priced at entry


def test_chart_falls_back_to_local_csv(tmp_path, monkeypatch):
    # No Kite feed -> ohlc_daily returns []; the chart must still draw from the
    # local CSV closes so clicking a share always shows a candle chart.
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    live.series_by_sym["KEI"] = [100.0 + i for i in range(40)]
    ch = live.chart_for("KEI")
    assert ch and ch["candles"] and len(ch["candles"]) == 40
    assert all({"o", "h", "l", "c"} <= set(c) for c in ch["candles"])
    assert live.chart_for("UNKNOWN") is None      # nothing to draw -> None, no crash


def test_live_win_rate_from_open_positions(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    pf = live.portfolios["smallcap"]
    pf.buy("UP", 10, 100.0, entry_len=250)        # will be marked in profit
    pf.buy("DN", 10, 100.0, entry_len=250)        # will be marked at a loss
    live.prices = {"UP": 110.0, "DN": 90.0}
    sc = next(p for p in live.build_state()["profiles"] if p["key"] == "smallcap")
    assert sc["win"] == 50 and sc["win_kind"] == "open"   # 1 of 2 green


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
