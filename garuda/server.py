"""Garuda live dashboard server — stdlib only (no pip needed on the droplet).

Serves the professional dashboard + a token-protected /data JSON endpoint that
prices the paper portfolios at live Kite LTP. A background thread refreshes
prices and the chart candles on a timer.

    # one-time daily scan (updates the paper portfolios from today's signals):
    python3 -m garuda.server --token YOURSECRET --scan --serve
    # or just serve (prices/charts refresh live):
    python3 -m garuda.server --token YOURSECRET

Open on your phone/computer:  http://64.227.155.177:8501/?token=YOURSECRET
PAPER ONLY — never places a real order.
"""

import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

from .live import GarudaLive

_HTML = (Path(__file__).parent / "dashboard_live.html").read_text(encoding="utf-8")
_STATE = {"json": b'{"profiles":[]}'}
_TOKEN = {"value": ""}
_LIVE = {"obj": None}      # the GarudaLive instance (for on-demand chart requests)


def _refresh_loop(live: GarudaLive, every: float = 3.0):
    chart_tick = 0
    while True:
        try:
            live.refresh_prices(full=(chart_tick % 2 == 0))  # whole universe every ~6s
            live.maybe_scan()                  # auto-book the day's trades once, live
            if chart_tick % 20 == 0:           # refresh chart candles ~once a minute
                for p in live.portfolios.values():
                    if p.holdings:
                        top = max(p.holdings.items(),
                                  key=lambda kv: kv[1]["qty"] * kv[1]["entry_price"])[0]
                        live.refresh_chart(top)
            chart_tick += 1
            _STATE["json"] = json.dumps(live.build_state()).encode()
        except Exception as exc:  # noqa: BLE001 — never let the loop die
            print(f"[refresh] {exc}", flush=True)
        time.sleep(every)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass  # quiet

    def _tok_ok(self):
        q = parse_qs(urlparse(self.path).query)
        return _TOKEN["value"] and q.get("token", [""])[0] == _TOKEN["value"]

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/health":
            return self._send(200, b"ok", "text/plain")
        if not self._tok_ok():
            return self._send(403, b"denied", "text/plain")
        if path == "/data":
            return self._send(200, _STATE["json"], "application/json")
        if path == "/chart":
            sym = parse_qs(urlparse(self.path).query).get("sym", [""])[0].upper()
            ch = _LIVE["obj"].chart_for(sym) if (_LIVE["obj"] and sym) else None
            return self._send(200, json.dumps(ch or {}).encode(), "application/json")
        return self._send(200, _HTML.encode(), "text/html")

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    args = sys.argv[1:]

    def opt(f, cast, d):
        return cast(args[args.index(f) + 1]) if f in args else d

    token = opt("--token", str, "")
    if not token:
        raise SystemExit("--token YOURSECRET is required (protects the dashboard)")
    _TOKEN["value"] = token
    port = opt("--port", int, 8501)
    live = GarudaLive(csv_dir=opt("--csv-dir", str, "."))
    _LIVE["obj"] = live

    if "--scan" in args:
        for k, r in live.scan().items():
            print(f"[scan] {k}: {r}", flush=True)

    live.refresh_prices()
    _STATE["json"] = json.dumps(live.build_state()).encode()
    threading.Thread(target=_refresh_loop, args=(live,), daemon=True).start()

    print(f"Garuda dashboard: http://0.0.0.0:{port}/?token={token}", flush=True)
    print(f"  (Kite feed: {'LIVE' if live.feed.live else 'offline — pricing at last close'})",
          flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
