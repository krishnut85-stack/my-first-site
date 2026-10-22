#!/usr/bin/env python3
"""engine.py - GIR INTRADAY paper-trading engine (NSE shares, no F&O, no real orders).

Five jobs, one decision (each job has one output; only the Manager combines them):
  SCOUT    ranks the universe after the open (gaps, first-bar volume)
  NEWS     looks up the latest headline for a share (information only)
  CHARTS   runs ONLY the strategies the Lab approved, on finished candles
  RISK     position size, max open trades, max trades per day, daily loss stop
  MANAGER  merges the above into one Telegram card and the paper journal

This program never places an order. It only reads prices.
"""
import os, sys, json, time, sqlite3, threading, collections, datetime as dt
import numpy as np
import core
import getdata

DB = os.path.join(core.BASE, "trades.db")
APPROVED = os.path.join(core.BASE, "approved.json")
HIST_DAYS = 50


def log(*a):
    print(str(core.ist_now())[:19], *a)
    sys.stdout.flush()


def db():
    con = sqlite3.connect(DB, timeout=30)
    con.execute("create table if not exists trades(id integer primary key, day text, sym text, strat text,"
                " label text, side int, qty int, entry_ts int, entry real, ref_open real, stop real,"
                " target real, dist real, best real, exit_ts int, exit real, reason text, gross real,"
                " cost real, net real, status text, mode text, booked real default 0)")
    try:
        con.execute("alter table trades add column booked real default 0")
    except sqlite3.OperationalError:
        pass
    con.execute("create table if not exists fired(day text, strat text, sym text, primary key(day,strat,sym))")
    con.execute("create table if not exists notes(day text, key text, primary key(day,key))")
    con.commit()
    return con


def once(con, day, key):
    """True the first time it is called for (day,key)."""
    try:
        con.execute("insert into notes values(?,?)", (day, key))
        con.commit()
        return True
    except sqlite3.IntegrityError:
        return False


# ---------------------------------------------------------------- CHARTS
def scan(strats, bars, nifty, today, j, c):
    """Pure function. bars: {sym: 5-min arrays incl. history + today}. j = index of the 5-min
    bar that has just closed. Returns signals whose signal bar is exactly bar j."""
    out = []
    for tf in sorted(set(s["tf"] for s in strats)):
        if tf == 15 and j % 3 != 2:
            continue
        jb = j // (tf // 5)
        nif = core.prep_nifty(nifty, tf, today, j) if nifty is not None else None
        syms = sorted(bars)
        M = core.stack((i, core.prep(bars[s], nif, tf, today, j)) for i, s in enumerate(syms))
        if M is None:
            continue
        rows = np.nonzero((M["day"] == today) & M["fresh"])[0]
        if len(rows) == 0:
            continue
        T = {k: (v[rows] if isinstance(v, np.ndarray) else v) for k, v in M.items()}
        views = {1: T, -1: core.side_view(T, -1)}
        for s in strats:
            if s["tf"] != tf:
                continue
            V = views[s["side"]]
            sig = core.signal(V, s["entry"], tf, c)
            f = core.filt(V, s["filt"], c)
            if f is not None:
                sig = sig & f
            e = core.first_entry(sig, tf, s["window"])
            for r in np.nonzero(e == jb + 1)[0]:
                atr = float(T["atr"][r, jb])
                px = float(T["C"][r, jb])
                if not (np.isfinite(atr) and atr > 0 and px > 0):
                    continue
                out.append({"sym": syms[int(T["sym"][r])], "strat": s, "e": int(e[r]), "tf": tf,
                            "close": px, "dist": float(core.stop_dist(atr, px, s["stopm"], c)),
                            "gap": float(T["gap"][r]), "mkt": float(T["mkt"][r, jb])})
    return out


# ---------------------------------------------------------------- NEWS
def news_for(sym, c):
    """Latest headline for the share from NEWSHAWK's ledger, if that database is there."""
    p = os.path.join(c["gir_home"], "newshawk", "ledger.db")
    if not os.path.exists(p):
        return None
    try:
        con = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=3)
        cols = [r[1] for r in con.execute("pragma table_info(live_news)")]
        pick = lambda names: next((x for x in cols if x.lower() in names), None)
        cs = pick(("symbol", "sym", "stock", "symbols", "stocks", "ticker"))
        ch = pick(("headline", "title", "text", "news"))
        ct = pick(("ts", "time", "published", "pub_ts", "created", "created_at", "dt", "date"))
        if not (cs and ch):
            return None
        q = "select %s from live_news where %s like ? order by %s desc limit 1" % (ch, cs, ct or "rowid")
        row = con.execute(q, ("%" + sym + "%",)).fetchone()
        con.close()
        return str(row[0])[:140] if row and row[0] else None
    except Exception:
        return None


# ---------------------------------------------------------------- RISK
def risk_ok(con, day, sym, c):
    cur = con.execute("select count(*), sum(status='OPEN'), sum(case when status='CLOSED' then net else 0 end),"
                      " sum(sym=?) from trades where day=?", (sym, day)).fetchone()
    n, n_open, realised, same = cur[0] or 0, cur[1] or 0, cur[2] or 0.0, cur[3] or 0
    if same:
        return "already traded today"
    if n >= c["max_trades_day"]:
        return "max trades for the day reached"
    if n_open >= c["max_open"]:
        return "max open positions"
    if realised <= -abs(c["daily_loss_rs"]):
        return "daily loss limit hit"
    return None


# ---------------------------------------------------------------- MANAGER
def rs(x):
    return "₹{:,.2f}".format(x)


def open_trade(con, day, g, ltp, ref_open, c, send=True):
    s, side = g["strat"], g["strat"]["side"]
    qty = int(c["position_rs"] // ltp)
    if qty < 1:
        return None
    dist = g["dist"]
    stop = ltp - side * dist
    mult = core.TP_MULT.get(s["exit"])
    target = ltp + side * mult * dist if mult else None
    con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                "status,mode) values(?,?,?,?,?,?,?,?,?,?,?,?,?,'OPEN',?)",
                (day, g["sym"], s["id"], s.get("label", ""), side, qty, int(time.time()), ltp, ref_open, stop,
                 target, dist, ltp, s["exit"]))
    con.commit()
    head = ("🟢 PAPER BUY" if side == 1 else "🔴 PAPER SELL (short)") + "  " + g["sym"]
    L = [head + ("  ⚠️ UNPROVEN strategy" if s.get("label") != "APPROVED" else ""),
         "%s %s × %d = %s" % ("Buy" if side == 1 else "Sell", rs(ltp), qty, rs(ltp * qty)),
         "Stop %s (%.2f%%)%s" % (rs(stop), dist / ltp * 100,
                                 " · Target %s (%.2f%%)" % (rs(target), mult * dist / ltp * 100) if mult else
                                 (" · trailing stop" if s["exit"] == "TRAIL" else " · no target, exit 15:15")),
         "Exit by 15:15 IST",
         "Why: " + s.get("desc", s["id"]),
         "Lab: %s%% wins, %+.2f%%/trade after costs (%s trades)" % (s.get("win", "?"), s.get("exp", 0),
                                                                    s.get("trades", "?")),
         "Gap %+.1f%% · Nifty %s" % (g["gap"] if np.isfinite(g["gap"]) else 0.0,
                                    "up" if g["mkt"] > 0 else "down" if g["mkt"] < 0 else "flat")]
    nw = news_for(g["sym"], c)
    L.append("News: " + (nw or "none found"))
    if send:
        core.tg("\n".join(L))
    return qty


def close_trade(con, t, px, reason, c, send=True):
    gross = (px - t["entry"]) * t["side"] * t["qty"]
    cost = core.cost_rs(t["entry"] * t["qty"], c)
    net = gross - cost
    con.execute("update trades set exit_ts=?, exit=?, reason=?, gross=?, cost=?, net=?, status='CLOSED' where id=?",
                (int(time.time()), px, reason, gross, cost, net, t["id"]))
    con.commit()
    try:
        import dash
        dash.event("MANAGER", "EXIT %s — %s · %s%s (%+.2f%%)" % (t["sym"], reason, "+" if net >= 0 else "−",
                   rs(abs(net)), net / (t["entry"] * t["qty"]) * 100), "win" if net > 0 else "loss")
    except Exception:
        pass
    if send:
        core.tg("%s EXIT %s — %s\n%s → %s × %d\nResult %s after costs (%+.2f%%)" % (
            "✅" if net > 0 else "❌", t["sym"], reason, rs(t["entry"]), rs(px), t["qty"],
            ("+" if net >= 0 else "−") + rs(abs(net)), net / (t["entry"] * t["qty"]) * 100))
    return net


def open_trades(con, day):
    try:
        cur = con.execute("select id,sym,side,qty,entry_ts,entry,stop,target,dist,best,mode,booked from trades"
                          " where day=? and status='OPEN'", (day,))
    except sqlite3.OperationalError:
        cur = con.execute("select id,sym,side,qty,entry_ts,entry,stop,target,dist,best,mode,0 from trades"
                          " where day=? and status='OPEN'", (day,))
    keys = ("id", "sym", "side", "qty", "entry_ts", "entry", "stop", "target", "dist", "best", "mode", "booked")
    return [dict(zip(keys, r)) for r in cur.fetchall()]


def check_price(con, t, hi, lo, last, c, gap_open=None, send=True):
    """Apply one price observation (bar high/low or a single LTP) to an open trade.
    Stop is checked before target. Returns True if the trade was closed."""
    side = t["side"]
    adverse = lo if side == 1 else hi
    favour = hi if side == 1 else lo
    if (adverse - t["stop"]) * side <= 0:
        px = t["stop"]
        if gap_open is not None and (gap_open - t["stop"]) * side < 0:
            px = gap_open
        elif hi == lo:
            px = last  # single LTP seen beyond the stop: fill at that worse price
        close_trade(con, t, px, "stop hit", c, send)
        return True
    cap = (c.get("v2") or {}).get("max_profit_pct", 0)
    if cap and t["mode"] in ("TRAIL", "SIP") and (favour - t["entry"]) * side >= t["entry"] * cap / 100.0:
        close_trade(con, t, t["entry"] * (1 + side * cap / 100.0), "+%g%% profit target hit" % cap, c, send)
        return True
    if t["mode"] in ("TRAIL", "SIP"):
        if t["mode"] == "TRAIL" and t["target"] is not None and not t.get("booked") and (favour - t["target"]) * side >= 0:
            part = max(1, t["qty"] // 3)
            px = t["target"]
            gross = (px - t["entry"]) * side * part
            cost = core.cost_rs(t["entry"] * part, c)
            con.execute("insert into trades(day,sym,strat,label,side,qty,entry_ts,entry,ref_open,stop,target,dist,best,"
                        "exit_ts,exit,reason,gross,cost,net,status,mode,booked) select day,sym,strat,label,side,?,entry_ts,"
                        "entry,ref_open,stop,target,dist,best,?,?,'1/3 booked',?,?,?,'CLOSED',mode,1 from trades where id=?",
                        (part, int(time.time()), px, gross, cost, gross - cost, t["id"]))
            con.execute("update trades set qty=qty-?, booked=1, stop=? where id=?", (part, t["entry"], t["id"]))
            con.commit()
            t["qty"] -= part
            t["stop"] = t["entry"]
            t["booked"] = 1
            if send:
                core.tg("✅ BOOKED 1/3 %s at %s (%+.2f%%), stop moved to entry %s; %d shares still running" % (
                    t["sym"], rs(px), (px - t["entry"]) * side / t["entry"] * 100, rs(t["entry"]), t["qty"]))
            if t["qty"] <= 0:
                con.execute("update trades set status='CLOSED', exit_ts=?, exit=?, reason='target hit', gross=0, cost=0, net=0 where id=?",
                            (int(time.time()), px, t["id"]))
                con.commit()
                return True
        best = max(t["best"], favour) if side == 1 else min(t["best"], favour)
        if t["mode"] == "SIP":
            trail = (c.get("v2") or {}).get("sip_trail_r", 2.0)
            armed = (best - t["entry"]) * side >= t["dist"] * trail
        else:
            trail = c["v2"].get("trail_x", 1.0) if "v2" in c else 1.0
            armed = t.get("booked") or (t["target"] is None and (best - t["entry"]) * side >= t["dist"])
        stop = best - side * t["dist"] * trail if armed else t["stop"]   # trail once the trade is +1 stop-distance
        if (stop - t["stop"]) * side > 0 or best != t["best"]:
            new_stop = max(t["stop"], stop) if side == 1 else min(t["stop"], stop)
            con.execute("update trades set best=?, stop=? where id=?", (best, new_stop, t["id"]))
            con.commit()
        return False
    if t["target"] is not None and (favour - t["target"]) * side >= 0:
        close_trade(con, t, t["target"], "target hit", c, send)
        return True
    return False


def ltps(kite, syms):
    if not syms:
        return {}
    getdata._quote.wait()
    q = getdata.call(kite.ltp, [getdata.key(s) for s in syms])
    return {getdata.unkey(k): v["last_price"] for k, v in q.items() if v.get("last_price")}


def summary(con, day, strats):
    rows = con.execute("select sym, side, net, reason, strat from trades where day=? and status='CLOSED'"
                       " order by id", (day,)).fetchall()
    if not rows:
        return "📒 INTRADAY PAPER — %s\nNo trades today (no approved setup fired)." % day
    tot = sum(r[2] for r in rows)
    wins = sum(1 for r in rows if r[2] > 0)
    L = ["📒 INTRADAY PAPER — %s" % day,
         "%d trades · %d wins · day result %s%s after costs" % (len(rows), wins, "+" if tot >= 0 else "−", rs(abs(tot)))]
    for r in rows:
        L.append("%s %s %s %s%s (%s)" % ("✅" if r[2] > 0 else "❌", "BUY" if r[1] == 1 else "SELL", r[0],
                                         "+" if r[2] >= 0 else "−", rs(abs(r[2])), r[3]))
    a = con.execute("select count(*), sum(net>0), sum(net), count(distinct day) from trades where status='CLOSED'").fetchone()
    L.append("")
    L.append("Since start: %d trades over %d days, %.0f%% wins, total %s%s" % (
        a[0], a[3], 100.0 * (a[1] or 0) / a[0], "+" if a[2] >= 0 else "−", rs(abs(a[2]))))
    if a[0] < 60:
        L.append("(needs ~60+ trades before the result means anything)")
    return "\n".join(L)


def weekly(con):
    rows = con.execute("select strat, label, count(*), sum(net>0), sum(net), avg(net/(entry*qty))*100"
                       " from trades where status='CLOSED' group by strat").fetchall()
    if not rows:
        return None
    L = ["📊 INTRADAY PAPER — scorecard by strategy (all days so far)"]
    for r in rows:
        L.append("%s [%s]\n   %d trades, %.0f%% wins, %+.2f%%/trade, total %s%s" % (
            r[0], r[1] or "?", r[2], 100.0 * r[3] / r[2], r[5], "+" if r[4] >= 0 else "−", rs(abs(r[4]))))
    return "\n".join(L)


# ---------------------------------------------------------------- day loop
def sleep_until(t):
    while True:
        d = (t - core.ist_now()).total_seconds()
        if d <= 0:
            return
        time.sleep(min(d, 30))


def today_bars(kite, token, now):
    start = now.replace(hour=9, minute=15, second=0, microsecond=0)
    getdata._hist.wait()
    return core.rows_to_arrays(getdata.call(kite.historical_data, token, start, now, "5minute"))


# ---------------------------------------------------------------- price feeds
class WsFeed(object):
    """Live candles for the whole universe from ONE Kite WebSocket (up to 3000 shares).
    A candle is updated only when a trade happened (day volume increased), so the candles
    match Kite's own 5-minute candles as closely as ticks allow."""
    name, poll = "live ticks", 1

    def __init__(self, syms, tok, t0, fut=None):
        self.syms = ["NIFTY50"] + list(syms)
        self.tokens = [getdata.NIFTY["token"]] + [tok[s] for s in syms]
        self.idx = {t: i for i, t in enumerate(self.tokens)}
        self.pos = {x: i for i, x in enumerate(self.syms)}
        self.t0 = t0                                   # epoch of 09:15 IST today
        n = len(self.syms)
        self.O, self.H, self.L, self.C, self.V = (np.full((n, core.NB5), np.nan) for _ in range(5))
        self.ltp = np.full(n, np.nan)
        self.pclose = np.full(n, np.nan)               # previous day's close, from the tick's ohlc (what Kite shows % against)
        self.seen = np.zeros(n)
        self.last_cum = np.full(n, -1.0)
        self.base = np.zeros(n)
        self.cur = np.full(n, -1, dtype=int)
        fut = fut or {}
        self.fidx = {int(t): self.pos[s] for s, t in fut.items() if s in self.pos}   # futures token -> share index
        self.fidx_of = {s: int(t) for s, t in fut.items() if s in self.pos}
        self.f_ltp = np.full(n, np.nan)
        self.f_oi = np.full(n, np.nan)
        self.tbq = np.zeros(n)                         # total buy quantity waiting in the order book
        self.tsq = np.zeros(n)                         # total sell quantity waiting in the order book
        self.lock = threading.Lock()
        self.nticks, self.err, self.ws, self.connected = 0, None, None, False
        # hot list: shares the desk is watching for an entry; a tick at/above the trigger wakes the main loop at once
        self.hot_trig = np.full(n, np.inf)
        self.wake = threading.Event()
        self.woke_by = None
        # 1-minute candles (for the position charts) and a tick tape for the shares we hold
        self.NB1 = 375
        self.O1, self.H1, self.L1, self.C1 = (np.full((n, self.NB1), np.nan) for _ in range(4))
        self.tape_idx = set()
        self.tape = {}

    def set_tape(self, syms):
        """Keep the last ticks for these shares (the open positions)."""
        keep = set(self.pos[s] for s in syms if s in self.pos)
        with self.lock:
            self.tape_idx = keep
            for i in list(self.tape):
                if i not in keep:
                    del self.tape[i]

    def chart1(self, sym):
        """1-minute candles so far today for one share: dict of lists (None where no trade), or None."""
        i = self.pos.get(sym)
        if i is None:
            return None
        with self.lock:
            b1 = int(min(max((time.time() - self.t0) // 60, 0), self.NB1 - 1)) + 1
            o, h, l, c = (np.round(a[i, :b1], 2).tolist() for a in (self.O1, self.H1, self.L1, self.C1))
            tp = [[round(t - self.t0), p, q] for t, p, q in self.tape.get(i, ())]
        f = lambda xs: [None if (x != x) else x for x in xs]
        return {"o": f(o), "h": f(h), "l": f(l), "c": f(c), "ticks": tp[-40:]}

    def set_hot(self, trig):
        """trig: {sym: trigger price}. Replaces the hot list."""
        new = np.full(len(self.syms), np.inf)
        for s, p in trig.items():
            i = self.pos.get(s)
            if i is not None and p and np.isfinite(p):
                new[i] = float(p)
        self.hot_trig = new

    def wait(self, secs):
        """Sleep up to `secs`, or until a hot share ticks through its trigger. Returns the share that woke us (or None)."""
        self.wake.wait(timeout=max(0.0, secs))
        self.wake.clear()
        w, self.woke_by = self.woke_by, None
        return w

    def start(self, kite):
        from kiteconnect import KiteTicker
        ws = KiteTicker(kite.api_key, kite.access_token)
        feed = self

        def on_connect(w, resp):
            for i in range(0, len(feed.tokens), 500):
                part = feed.tokens[i:i + 500]
                w.subscribe(part)
                w.set_mode(w.MODE_QUOTE, part)
            ft = list(feed.fidx)
            for i in range(0, len(ft), 500):
                part = ft[i:i + 500]
                w.subscribe(part)
                w.set_mode(w.MODE_FULL, part)
            feed.connected = True
            log("websocket connected, %d instruments + %d futures subscribed" % (len(feed.tokens), len(ft)))

        def on_error(w, code, reason):
            feed.err = "%s %s" % (code, reason)
            log("websocket error:", feed.err)

        def on_close(w, code, reason):
            log("websocket closed:", code, reason)

        ws.on_ticks = lambda w, ticks: feed.on_ticks(ticks)
        ws.on_connect, ws.on_error, ws.on_close = on_connect, on_error, on_close
        ws.connect(threaded=True)
        self.ws = ws

    def stop(self):
        try:
            if self.ws is not None:
                self.ws.close()
        except Exception:
            pass

    def on_ticks(self, ticks):
        now = time.time()
        b = int((now - self.t0) // 300)
        live = 0 <= b < core.NB5 and now >= self.t0
        with self.lock:
            self.nticks += len(ticks)
            for t in ticks:
                tk = t.get("instrument_token")
                i = self.idx.get(tk)
                p = t.get("last_price")
                if i is None:
                    k = self.fidx.get(tk)
                    if k is not None:
                        if p:
                            self.f_ltp[k] = p
                        oi = t.get("oi")
                        if oi:
                            self.f_oi[k] = oi
                    continue
                if not p:
                    continue
                self.seen[i] = now
                if np.isnan(self.pclose[i]):
                    pc_ = (t.get("ohlc") or {}).get("close") or 0
                    if pc_ > 0:
                        self.pclose[i] = pc_
                if p >= self.hot_trig[i]:
                    self.hot_trig[i] = p * 1.001              # next wake from this share only on a further +0.1%
                    if not self.wake.is_set():
                        self.woke_by = self.syms[i]
                        self.wake.set()
                tb, ts_ = t.get("total_buy_quantity"), t.get("total_sell_quantity")
                if tb is not None and ts_ is not None:
                    self.tbq[i], self.tsq[i] = tb, ts_
                cum = t.get("volume_traded", t.get("volume"))
                if i:
                    if cum is None:
                        continue
                    if cum == self.last_cum[i]:
                        continue                      # no new trade since the last tick: ignore it fully
                    self.ltp[i] = p
                    if not live:
                        self.last_cum[i] = cum
                        continue
                else:
                    self.ltp[i] = p
                    if not live:
                        continue
                if b != self.cur[i]:
                    prev = np.nansum(self.V[i, :b]) if b > 0 else 0.0
                    self.base[i] = self.last_cum[i] if (self.cur[i] >= 0 and self.last_cum[i] >= 0) else prev
                    self.cur[i] = b
                if np.isnan(self.O[i, b]):
                    o = p
                    if b == 0:
                        do = (t.get("ohlc") or {}).get("open") or 0
                        if do > 0:
                            o = do
                    self.O[i, b] = o
                    self.H[i, b], self.L[i, b] = max(o, p), min(o, p)
                else:
                    if p > self.H[i, b]:
                        self.H[i, b] = p
                    if p < self.L[i, b]:
                        self.L[i, b] = p
                self.C[i, b] = p
                b1 = int((now - self.t0) // 60)
                if 0 <= b1 < self.NB1:
                    if np.isnan(self.O1[i, b1]):
                        self.O1[i, b1] = self.H1[i, b1] = self.L1[i, b1] = p
                    else:
                        if p > self.H1[i, b1]:
                            self.H1[i, b1] = p
                        if p < self.L1[i, b1]:
                            self.L1[i, b1] = p
                    self.C1[i, b1] = p
                if i in self.tape_idx:
                    q = t.get("last_traded_quantity") or t.get("last_quantity") or 0
                    self.tape.setdefault(i, collections.deque(maxlen=60)).append((now, p, q))
                if i:
                    v = cum - self.base[i]
                    if v < 0:                          # exchange reset the day volume
                        self.base[i], v = 0.0, cum
                    self.V[i, b] = v
                    self.last_cum[i] = cum

    def backfill(self, kite, now):
        """After a mid-day restart: load the candles we missed from Kite (slow, once)."""
        log("mid-day start: loading today's earlier candles for %d instruments" % len(self.tokens))
        for i, tk in enumerate(self.tokens):
            try:
                a = today_bars(kite, tk, now)
            except Exception as ex:
                log(self.syms[i], "backfill failed:", ex)
                continue
            b_now = int((time.time() - self.t0) // 300)
            k = ((a["ts"] - self.t0) // 300).astype(int)
            ok = (k >= 0) & (k < min(b_now, core.NB5))
            with self.lock:
                for f, key in (("O", "o"), ("H", "h"), ("L", "l"), ("C", "c"), ("V", "v")):
                    getattr(self, f)[i, k[ok]] = a[key][ok]
                self.cur[i] = -1

    def bars(self, j, kite=None, now=None):
        with self.lock:
            O, H, L, C, V = (x[:, :j + 1].copy() for x in (self.O, self.H, self.L, self.C, self.V))
        ts = self.t0 + 300 * np.arange(j + 1)
        out = {}
        for i, s in enumerate(self.syms):
            k = ~np.isnan(C[i])
            out[s] = {"ts": ts[k].astype(np.int64), "o": O[i][k], "h": H[i][k], "l": L[i][k], "c": C[i][k],
                      "v": np.nan_to_num(V[i][k])}
        return out.pop("NIFTY50"), out

    def prices(self, kite, syms):
        with self.lock:
            return {s: float(self.ltp[i]) for s in syms for i in [self.pos[s]] if np.isfinite(self.ltp[i])}

    def obi(self, sym):
        """Order-book pressure -1..+1 from total buy vs sell quantity; None if unknown."""
        i = self.pos.get(sym)
        if i is None:
            return None
        b, s = self.tbq[i], self.tsq[i]
        return float((b - s) / (b + s)) if b + s > 0 else None

    def nifty_chg(self):
        """Nifty % vs the previous close (falls back to % vs today's open until the first tick carries ohlc)."""
        o = self.pclose[0] if (np.isfinite(self.pclose[0]) and self.pclose[0] > 0) else self.O[0, 0]
        p = self.ltp[0]
        return float((p / o - 1) * 100) if np.isfinite(o) and np.isfinite(p) and o > 0 else None

    def silent_for(self):
        """Seconds since the last Nifty tick (the index ticks every second while the market is open)."""
        return time.time() - self.seen[0] if self.seen[0] else None


class RestFeed(object):
    """Fallback when the WebSocket is not available: asks Kite for candles after every bar.
    Slower (3 requests a second), so it covers only the most liquid shares."""
    name, poll = "candle requests (slow mode)", 60

    def set_hot(self, trig):
        pass

    def set_tape(self, syms):
        pass

    def chart1(self, sym):
        return None

    def wait(self, secs):
        time.sleep(max(0.0, secs))
        return None

    def __init__(self, syms, tok):
        self.syms, self.tok = list(syms), tok

    def stop(self):
        pass

    def bars(self, j, kite, now):
        try:
            nif = today_bars(kite, getdata.NIFTY["token"], now)
        except Exception as ex:
            log("nifty fetch failed:", ex)
            nif = core.rows_to_arrays([])
        out = {}
        for s in self.syms:
            try:
                out[s] = today_bars(kite, self.tok[s], now)
            except Exception as ex:
                log(s, "fetch failed:", ex)
        return nif, out

    def prices(self, kite, syms):
        return ltps(kite, syms)


def run_day(c):
    now = core.ist_now()
    day = str(now.date())
    today = core.day_ord(now)
    con = db()
    at = lambda h, m, s=0: now.replace(hour=h, minute=m, second=s, microsecond=0)

    strats = []
    if os.path.exists(APPROVED):
        strats = json.load(open(APPROVED)).get("strategies", [])
    if not strats:
        if once(con, day, "nostrat"):
            core.tg("⚠️ INTRADAY: the Lab has no strategies to trade today. Run: python3 lab.py")
        return
    kite = None
    while core.ist_now() < at(15, 0):
        try:
            kite = core.get_kite(c)
            break
        except Exception as ex:
            log("kite not ready:", ex)
            if core.ist_now() > at(9, 20) and once(con, day, "notoken"):
                core.tg("⚠️ INTRADAY: Kite token not usable (%s). Retrying every minute." % str(ex)[:120])
            time.sleep(60)
    if kite is None:
        return
    uni = getdata.load_universe()
    if once(con, day, "topup"):
        log("topping up history for %d shares" % len(uni))
        try:
            getdata.update_all(kite, c, uni, quiet=True)
        except Exception as ex:
            log("history top-up failed:", ex)
    cut = core.ist_epoch(at(0, 0)) - HIST_DAYS * 86400
    midnight = core.ist_epoch(at(0, 0))

    def tail(sym):
        a = core.load_npz(sym)
        if a is None:
            return None
        k = (a["ts"] >= cut) & (a["ts"] < midnight)
        return {x: v[k] for x, v in a.items()}
    hist = {e["sym"]: tail(e["sym"]) for e in uni}
    hist = {k: v for k, v in hist.items() if v is not None and len(v["ts"]) > 75 * 20}
    nif_hist = tail("NIFTY50")
    tok = {e["sym"]: e["token"] for e in uni}
    rank = {e["sym"]: i for i, e in enumerate(uni)}
    order_syms = [e["sym"] for e in uni if e["sym"] in hist]

    # price feed: WebSocket for everything; slow candle requests for the top shares if that fails
    feed = None
    if c.get("use_websocket", True):
        try:
            feed = WsFeed(order_syms, tok, core.ist_epoch(at(9, 15)))
            feed.start(kite)
            for _ in range(30):
                if feed.connected:
                    break
                time.sleep(1)
            if not feed.connected:
                raise RuntimeError(feed.err or "could not connect in 30 s")
            if core.ist_now() > at(9, 16):
                feed.backfill(kite, core.ist_now())
        except Exception as ex:
            log("websocket feed failed:", ex)
            if feed is not None:
                feed.stop()
            feed = None
            if once(con, day, "nows"):
                core.tg("⚠️ INTRADAY: live tick feed not available (%s). Using slow mode on the top %d shares today."
                        % (str(ex)[:120], c.get("rest_fallback_size", 120)))
    def slow_feed():
        top = order_syms[:c.get("rest_fallback_size", 120)]
        return RestFeed(top, tok), {s: hist[s] for s in top}
    if feed is None:
        feed, hist = slow_feed()
    log("ready: %d shares, %d strategies, feed: %s" % (len(hist), len(strats), feed.name))
    if once(con, day, "hello"):
        core.tg("🌅 INTRADAY PAPER ready — watching %d shares (%s), %d strategies:\n%s" % (
            len(hist), feed.name, len(strats),
            "\n".join("S%d [%s] %s" % (i + 1, s.get("label"), s.get("desc")) for i, s in enumerate(strats))))
    try:
        traded = trade_loop(c, con, kite, feed, strats, hist, nif_hist, rank, day, today, at)
    finally:
        feed.stop()
    if traded == "DEAD_FEED":
        core.tg("⚠️ INTRADAY: the live tick feed is connected but silent while the market is open. "
                "Switching to slow mode on the top shares for the rest of today.")
        feed, hist = slow_feed()
        traded = trade_loop(c, con, kite, feed, strats, hist, nif_hist, rank, day, today, at)
    if traded and once(con, day, "summary"):
        core.tg(summary(con, day, strats))
        if now.weekday() == 4:
            w = weekly(con)
            if w:
                core.tg(w)


def watch(con, kite, feed, day, c):
    gap = feed.silent_for() if hasattr(feed, "silent_for") else None
    if gap is not None and gap > 180 and time.time() > feed.t0 + 300 and once(con, day, "silent"):
        core.tg("⚠️ INTRADAY: no price ticks for 3 minutes. Kite's feed is reconnecting; open paper trades "
                "are not being watched until it is back.")
    ot = open_trades(con, day)
    if not ot:
        return
    try:
        px = feed.prices(kite, [t["sym"] for t in ot])
    except Exception as ex:
        log("price poll failed:", ex)
        return
    for t in ot:
        if t["sym"] in px:
            p = px[t["sym"]]
            check_price(con, t, p, p, p, c)


def trade_loop(c, con, kite, feed, strats, hist, nif_hist, rank, day, today, at):
    lag = dt.timedelta(seconds=2 if feed.poll < 30 else 5)
    t = core.ist_now()
    j0 = int((t - at(9, 20)).total_seconds() // 300) + 1 if t > at(9, 20) else 0
    for j in range(max(j0, 0), core.NB5):
        close_t = at(9, 20) + dt.timedelta(minutes=5 * j)
        if close_t > at(15, 15):
            break
        while core.ist_now() < close_t + lag:          # between candles: watch open positions
            watch(con, kite, feed, day, c)
            left = (close_t + lag - core.ist_now()).total_seconds()
            if left > 0:
                time.sleep(min(feed.poll, left))
        bar_start = core.ist_epoch(close_t) - 300
        nif_today, raw = None, {}
        for _ in range(4):
            nif_today, raw = feed.bars(j, kite, core.ist_now())
            if len(nif_today["ts"]) and (nif_today["ts"] == bar_start).any():
                break
            time.sleep(3)
        else:
            if j >= 2 and len(nif_today["ts"]) == 0:
                if feed.poll < 30:                      # tick feed silent: holiday, or is the feed dead?
                    try:
                        probe = today_bars(kite, getdata.NIFTY["token"], core.ist_now())
                    except Exception as ex:
                        log("holiday probe failed:", ex)
                        continue
                    if len(probe["ts"]):
                        log("Kite has Nifty candles but the tick feed has none - feed is dead")
                        return "DEAD_FEED"
                log("no Nifty candles today - market holiday, stopping for the day")
                return False
            log("bar %d: Nifty candle missing, skipping this bar" % j)
            continue
        bars = {s: (a, core.merge_arrays(hist[s], a)) for s, a in raw.items() if s in hist and len(a["ts"])}
        # exits on the finished candle (catches touches the price poll missed)
        for t in open_trades(con, day):
            a = bars.get(t["sym"], (None,))[0]
            if a is None or t["entry_ts"] > bar_start:
                continue
            k = a["ts"] == bar_start
            if k.any():
                check_price(con, t, float(a["h"][k][0]), float(a["l"][k][0]), float(a["c"][k][0]), c,
                            gap_open=float(a["o"][k][0]))
        if j >= 2 and once(con, day, "scout"):          # SCOUT brief once, after the first 15 minutes
            try:
                core.tg(scout(bars, hist))
            except Exception as ex:
                log("scout failed:", ex)
        if close_t >= at(14, 45):                       # CHARTS -> RISK -> MANAGER
            continue
        t_scan = time.time()
        try:
            sigs = scan(strats, {s: b[1] for s, b in bars.items()}, core.merge_arrays(nif_hist, nif_today),
                        today, j, c)
        except Exception as ex:
            log("scan failed:", ex)
            sigs = []
        order = {s["id"]: i for i, s in enumerate(strats)}
        sigs.sort(key=lambda g: (order[g["strat"]["id"]], rank.get(g["sym"], 9999)))
        fresh = []
        for g in sigs:
            try:
                con.execute("insert into fired values(?,?,?)", (day, g["strat"]["id"], g["sym"]))
                con.commit()
                fresh.append(g)
            except sqlite3.IntegrityError:
                pass
        todo = [g for g in fresh if risk_ok(con, day, g["sym"], c) is None
                and (g["strat"]["side"] == 1 or c.get("allow_short", True))]
        if todo:
            try:
                px = feed.prices(kite, sorted(set(g["sym"] for g in todo)))
            except Exception as ex:
                log("entry price failed:", ex)
                px = {}
            for g in todo:
                why = risk_ok(con, day, g["sym"], c)
                if why or g["sym"] not in px:
                    log("skip", g["sym"], why or "no price")
                    continue
                open_trade(con, day, g, px[g["sym"]], g["close"], c)
                log("PAPER", g["strat"]["id"], g["sym"], px[g["sym"]])
        if j % 12 == 0:
            log("bar %d: %d shares scanned in %.1f s, %d signals" % (j, len(bars), time.time() - t_scan, len(sigs)))
    sleep_until(at(15, 15, 5))                          # 15:15 square-off
    ot = open_trades(con, day)
    if ot:
        px = {}
        for _ in range(3):
            try:
                px = feed.prices(kite, [t["sym"] for t in ot])
                break
            except Exception as ex:
                log("square-off price failed:", ex)
                time.sleep(5)
        for t in ot:
            close_trade(con, t, px.get(t["sym"], t["entry"]), "15:15 square-off" if t["sym"] in px
                        else "15:15 square-off (NO PRICE - booked flat, check)", c)
    return True


def scout(bars, hist):
    rowsu = []
    for sym, (a, _) in bars.items():
        h = hist[sym]
        if len(a["ts"]) < 3 or len(h["ts"]) == 0:
            continue
        pc = float(h["c"][-1])
        gap = (float(a["o"][0]) / pc - 1) * 100
        now_ = (float(a["c"][2]) / pc - 1) * 100
        rowsu.append((gap, now_, sym))
    rowsu.sort()
    L = ["🔭 SCOUT 09:30 — biggest gaps in the universe (information only)"]
    L.append("Gap up:")
    for g, n, s in reversed(rowsu[-5:]):
        L.append("  %s gap %+.1f%% → now %+.1f%%" % (s, g, n))
    L.append("Gap down:")
    for g, n, s in rowsu[:5]:
        L.append("  %s gap %+.1f%% → now %+.1f%%" % (s, g, n))
    return "\n".join(L)


def main():
    """One market day per process: systemd restarts the service after each day (and after any
    crash), which gives the WebSocket library a clean start every time."""
    log("GIR INTRADAY engine started (paper only)")
    now = core.ist_now()
    day = str(now.date())
    start = now.replace(hour=9, minute=2, second=0, microsecond=0)
    con = db()
    done = con.execute("select 1 from notes where day=? and key='done'", (day,)).fetchone()
    if now.weekday() < 5 and not done and start <= now < now.replace(hour=15, minute=40):
        try:
            run_day(core.cfg())
        except Exception as ex:
            import traceback
            traceback.print_exc()
            if any(once(con, day, "err%d" % i) for i in range(3)):
                core.tg("⚠️ INTRADAY engine error: %s — restarting in 30 s" % str(ex)[:200])
            sys.exit(1)
        once(con, day, "done")
        log("day finished")
        sys.exit(0)
    nxt = start if now < start else start + dt.timedelta(days=1)
    while nxt.weekday() >= 5:
        nxt += dt.timedelta(days=1)
    log("sleeping until", nxt)
    sleep_until(nxt)
    sys.exit(0)


if __name__ == "__main__":
    main()
