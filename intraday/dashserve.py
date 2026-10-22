#!/usr/bin/env python3
"""dashserve.py - serves the GIR INTRADAY live terminal (read-only, token protected).

  http://<server>:8090/?k=<token>     the terminal page
  /state?k=<token>                    live state written by the engine every ~3 s
  /history?k=<token>                  daily paper P&L since the start
"""
import os, sys, json, hmac, sqlite3, time, datetime as dt
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

BASE = os.path.dirname(os.path.abspath(__file__))
TOKEN = open(os.path.join(BASE, "dash_token.txt")).read().strip()
PAGE = os.path.join(BASE, "terminal.html")
STATE = os.path.join(BASE, "dash_state.json")
DB = os.path.join(BASE, "trades.db")


IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
ROLES = {"SCOUT": "opening volume · gaps · stocks in play", "NEWS": "filings · headlines · market news",
         "CHARTS": "breakouts · pre-breakouts · live checks", "FLOW": "money flow · futures OI · blast radar",
         "RISK": "limits · spacing · daily loss", "MANAGER": "buys · exits · P&L"}


def hm(ts):
    return dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M") if ts else ""


def _is_holiday(d):
    try:
        import holidays
        return bool(holidays.holiday(d))
    except Exception:
        return d.weekday() >= 5


def next_open(now):
    """Next 09:15 IST on a trading day (weekends and NSE holidays skipped)."""
    d = now
    while True:
        o = d.replace(hour=9, minute=15, second=0, microsecond=0)
        if not _is_holiday(d.date()) and o > now:
            return o
        d = (d + dt.timedelta(days=1)).replace(hour=0, minute=0)


def closed_state():
    """What the page shows when the engine is not writing: the last session, replayed from trades.db."""
    now = dt.datetime.now(IST)
    st = {"ts": now.strftime("%Y-%m-%d %H:%M:%S"), "closed": True, "next_open": next_open(now).isoformat(),
          "feed": "market closed", "trades": [], "events": [], "curve": [], "news": [],
          "pnl": {"real": 0, "unreal": 0, "total": 0, "used": 0, "n": 0, "wins": 0, "losses": 0, "open": 0},
          "agents": [{"name": k, "role": v, "t": "", "m": "standing by", "n": 0} for k, v in ROLES.items()]}
    if not os.path.exists(DB):
        return st
    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True, timeout=3)
    try:
        last = con.execute("select max(day) from trades where status='CLOSED'").fetchone()[0]
        if not last:
            return st
        rows = con.execute("select sym,label,qty,entry_ts,entry,exit_ts,exit,reason,net,strat from trades "
                           "where day=? and status='CLOSED' order by id", (last,)).fetchall()
    finally:
        con.close()
    st["day"] = last
    saved = None
    if os.path.exists(STATE):
        try:
            d = json.load(open(STATE))
            if d.get("day") == last and d.get("paths"):
                saved = d
        except Exception:
            saved = None
    real, ev, cum, curve = 0.0, [], 0.0, [["09:15", 0]]
    for sym, label, qty, ets, entry, xts, ex, reason, net, strat in rows:
        net = net or 0.0
        real += net
        st["trades"].append({"s": sym, "k": label, "t": hm(ets), "e": round(entry, 2), "x": round(ex, 2) if ex else None,
                             "pl": round(net), "r": reason, "open": False, "q": qty, "xt": hm(xts) or None})
        ev.append((ets, "BUY %s · %s · %d @ %.2f" % (sym, label, qty, entry), "buy", None))
        if xts:
            ev.append((xts, "EXIT %s — %s · %s₹%s" % (sym, reason, "+" if net > 0 else "−", "{:,}".format(abs(round(net)))),
                       "win" if net > 0 else "loss", net))
    for t, m, k, net in sorted(ev, key=lambda e: e[0]):
        st["events"].append({"t": hm(t), "a": "MANAGER", "m": m, "k": k})
        if net is not None:
            cum += net
            curve.append([hm(t), round(cum)])
    st["events"].append({"t": "15:15", "a": "MANAGER", "m": "session %s closed — all positions squared off" % last, "k": "info"})
    st["curve"] = curve
    if saved:  # the engine's own last picture of that session: flow lines, cards, sectors, minute-by-minute curve
        for k in ("paths", "nifty_path", "bar", "up", "down", "blast", "crash", "sectors", "breadth", "fo_breadth", "nifty", "news", "ctx", "pos", "accum", "bse"):
            if k in saved:
                st[k] = saved[k]
        if len(saved.get("curve") or []) > 3:
            st["curve"] = saved["curve"]
        if saved.get("events"):
            st["events"] = saved["events"]
    st["pnl"] = {"real": round(real), "unreal": 0, "total": round(real), "used": round(sum(r[2] * r[4] for r in rows)),
                 "n": len(rows), "wins": sum(1 for r in rows if (r[8] or 0) > 0), "losses": sum(1 for r in rows if (r[8] or 0) <= 0), "open": 0}
    for a in st["agents"]:
        a["m"] = "standing by · last session %s" % last
    return st


def live_state():
    """The engine's state file if it is today's; otherwise the closed-market view."""
    if os.path.exists(STATE):
        try:
            raw = open(STATE, "rb").read()
            d = json.loads(raw)
            if d.get("day") == dt.datetime.now(IST).strftime("%Y-%m-%d"):
                return raw
        except Exception:
            pass
    return json.dumps(closed_state(), ensure_ascii=False, default=str)


def history():
    if not os.path.exists(DB):
        return []
    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True, timeout=3)
    rows = con.execute("select day, round(sum(net)), count(*), sum(net>0) from trades where status='CLOSED' "
                       "group by day order by day").fetchall()
    con.close()
    out, cum = [], 0
    for d, net, n, w in rows:
        cum += net or 0
        out.append({"d": d, "net": net or 0, "cum": cum, "n": n, "w": w or 0})
    return out


class H(BaseHTTPRequestHandler):
    server_version = "GIR"

    def log_message(self, *a):
        pass

    def send(self, code, body, ctype):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        k = (parse_qs(u.query).get("k") or [""])[0]
        if not hmac.compare_digest(k.encode(), TOKEN.encode()):
            return self.send(403, "forbidden", "text/plain")
        try:
            if u.path == "/":
                return self.send(200, open(PAGE, "rb").read(), "text/html; charset=utf-8")
            if u.path == "/state":
                return self.send(200, live_state(), "application/json; charset=utf-8")
            if u.path == "/history":
                return self.send(200, json.dumps(history()), "application/json")
        except Exception as ex:
            return self.send(500, str(ex), "text/plain")
        return self.send(404, "not found", "text/plain")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
