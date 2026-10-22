#!/usr/bin/env python3
"""core.py - shared maths for the GIR INTRADAY program.

The Strategy Lab (lab.py) and the live paper engine (engine.py) both import
this file, so a signal in the backtest and a signal in live paper trading are
produced by exactly the same code.

Conventions
  * 5-minute bars, NSE cash session 09:15-15:30 IST -> 75 bars per day.
  * A "day matrix" has shape (days, bars). 15-minute bars are built from 5-minute ones.
  * Short side is handled by mirroring prices (see side_view) so only long logic exists.
"""
import os, json, time, calendar, datetime as dt
import numpy as np
import pandas as pd

BASE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(BASE, "data")
IST_OFF = 19800
NB5 = 75
OPEN_MIN = 555  # 09:15 in minutes

DEFAULT_CFG = {
    "gir_home": "/home/globalbot",
    "position_rs": 100000,      # paper money put into each trade
    "max_open": 5,              # max positions open at once
    "max_trades_day": 6,        # max new trades per day
    "daily_loss_rs": 3000,      # stop new entries after this realised loss in a day
    "universe_size": 1500,      # upper cap on the number of shares
    "min_turnover_cr": 5,       # a share is "liquid" if it traded at least this many Rs crore in the day
    "min_price": 20,
    "use_websocket": True,
    "rest_fallback_size": 120,
    "years": 2,
    "slip_pct": 0.05,           # slippage per side, percent
    "brokerage_flat": 50,       # NRI Non-PIS: Rs 50 or 0.5% per order, whichever is lower
    "brokerage_pct": 0.5,
    "stop_min_pct": 0.3,
    "stop_max_pct": 3.0,
    "gap_pct": 1.0,
    "vol_mult": 1.5,
    "max_strategies": 5,
    "allow_short": True,        # paper-trade short (sell first) setups too
    "paper_unproven": True,     # if nothing is approved, paper trade the best near-misses (labelled)
}

ENTRIES = ["ORB15", "ORB30", "VWAPX", "EMAX", "RSIREV", "HIBRK", "GAPGO", "GAPFADE"]
GAP_ENTRIES = ("GAPGO", "GAPFADE")
FILTERS = ["NONE", "VOL", "TREND", "MKT"]
WINDOWS = {"W1": (930, 1100), "W2": (1100, 1330), "W3": (1330, 1445), "ALL": (930, 1445)}
STOPS = [1.0, 1.5, 2.5]
EXITS = ["TP15", "TP25", "TIME", "TRAIL"]
TFS = [15, 5]

ENTRY_TEXT = {
    "ORB15": "breakout of first 15-min range", "ORB30": "breakout of first 30-min range",
    "VWAPX": "price crossed VWAP", "EMAX": "EMA 9 crossed EMA 21",
    "RSIREV": "RSI reversal from extreme", "HIBRK": "new day high/low close",
    "GAPGO": "gap continued after first 15 min", "GAPFADE": "gap reversed after first 15 min",
}
ENTRY_TEXT_S = {
    "ORB15": "breakdown below first 15-min range", "ORB30": "breakdown below first 30-min range",
    "VWAPX": "price fell below VWAP", "EMAX": "EMA 9 crossed below EMA 21",
    "RSIREV": "RSI turned down from overbought", "HIBRK": "new day low close",
    "GAPGO": "gap-down continued after first 15 min", "GAPFADE": "gap-up reversed after first 15 min",
}
ENTRY_TEXT_L = dict(ENTRY_TEXT, VWAPX="price crossed above VWAP", EMAX="EMA 9 crossed above EMA 21",
                    RSIREV="RSI turned up from oversold", HIBRK="new day high close",
                    GAPGO="gap-up continued after first 15 min", GAPFADE="gap-down reversed after first 15 min")
FILTER_TEXT = {"NONE": "no filter", "VOL": "volume 1.5x normal", "TREND": "with 20-day trend",
               "MKT": "with Nifty direction"}


def cfg():
    c = dict(DEFAULT_CFG)
    p = os.path.join(BASE, "config.json")
    if os.path.exists(p):
        try:
            c.update(json.load(open(p)))
        except Exception as ex:
            print("config.json unreadable, using defaults:", ex)
    return c


def ist_now():
    return dt.datetime(1970, 1, 1) + dt.timedelta(seconds=time.time() + IST_OFF)


def ist_epoch(d):
    """naive IST datetime -> unix epoch seconds"""
    return calendar.timegm(d.timetuple()) - IST_OFF


def bar_epoch(d):
    """Kite candle 'date' -> unix epoch seconds (handles tz-aware and naive-IST)."""
    if d.tzinfo is None:
        return calendar.timegm(d.timetuple()) - IST_OFF
    return int(d.timestamp())


def day_ord(d):
    """naive IST datetime/date -> day ordinal used in matrices (days since 1970, IST)."""
    return (calendar.timegm(dt.datetime(d.year, d.month, d.day).timetuple())) // 86400


def ord_date(o):
    return (dt.datetime(1970, 1, 1) + dt.timedelta(days=int(o))).date()


def tg(text):
    """Send a Telegram message. Channel: TG_CHAT_INTRADAY, else TG_CHAT_PREOPEN, else TG_NEWS_CHAT_ID."""
    tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
    chat = (os.environ.get("TG_CHAT_INTRADAY") or os.environ.get("TG_CHAT_PREOPEN")
            or os.environ.get("TG_NEWS_CHAT_ID"))
    if not tok or not chat:
        print("[telegram not configured]\n" + text)
        return False
    try:
        import requests
        r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                          data={"chat_id": chat, "text": text[:4000],
                                "disable_web_page_preview": "true"}, timeout=15)
        if not r.ok:
            print("telegram error:", r.status_code, r.text[:200])
        return r.ok
    except Exception as ex:
        print("telegram error:", ex)
        return False


class Limiter(object):
    """Keeps at least `gap` seconds between calls (Kite historical API allows ~3 per second)."""

    def __init__(self, gap=0.36, sleep=time.sleep):
        self.gap, self.last, self.sleep = gap, 0.0, sleep

    def wait(self):
        d = self.gap - (time.time() - self.last)
        if d > 0:
            self.sleep(d)
        self.last = time.time()


def _find_token(obj):
    if isinstance(obj, dict):
        for k in ("access_token", "accessToken", "token"):
            if isinstance(obj.get(k), str) and len(obj[k]) >= 16:
                return obj[k]
        for v in obj.values():
            t = _find_token(v)
            if t:
                return t
    return None


def get_kite(c=None):
    """Re-use the access token GIR refreshes every morning. Never logs in itself:
    a second login would invalidate the token the other bots are using."""
    from kiteconnect import KiteConnect
    c = c or cfg()
    key = os.environ.get("KITE_API_KEY")
    if not key:
        raise RuntimeError("KITE_API_KEY not in environment - run with .env sourced")
    cands = []
    if os.environ.get("KITE_ACCESS_TOKEN"):
        cands.append(os.environ["KITE_ACCESS_TOKEN"])
    for name in ("kite_token.json", "kite_access.json"):
        p = os.path.join(c["gir_home"], "data", name)
        if os.path.exists(p):
            try:
                raw = open(p).read().strip()
                try:
                    t = _find_token(json.loads(raw))
                except ValueError:
                    t = raw if 16 <= len(raw) <= 80 else None
                if t:
                    cands.append(t)
            except Exception as ex:
                print("cannot read", p, ex)
    err = "no token file found in %s/data" % c["gir_home"]
    for t in cands:
        try:
            k = KiteConnect(api_key=key)
            k.set_access_token(t)
            k.profile()
            return k
        except Exception as ex:
            err = str(ex)
    raise RuntimeError("Kite login token not usable (%s)" % err)


def cost_pct(pos, c):
    """Round-trip cost of one intraday equity trade, in percent of position value."""
    b = min(c["brokerage_flat"], pos * c["brokerage_pct"] / 100.0)
    stt = 0.00025 * pos                 # sell side
    txn = 0.0000297 * pos * 2           # NSE transaction charge, both sides
    sebi = 0.000001 * pos * 2
    stamp = 0.00003 * pos               # buy side
    gst = 0.18 * (2 * b + txn + sebi)
    slip = 2 * pos * c["slip_pct"] / 100.0
    return (2 * b + stt + txn + sebi + stamp + gst + slip) / pos * 100.0


def cost_rs(pos, c):
    return cost_pct(pos, c) * pos / 100.0


def bar_of(hhmm, tf):
    h, m = divmod(hhmm, 100)
    return (h * 60 + m - OPEN_MIN) // tf


# ----------------------------------------------------------------------------
# bars -> day matrices
# ----------------------------------------------------------------------------
def to_matrix(a, today=None, upto=None, min_bars=70):
    """5-minute bars -> dict of (D,75) matrices.

    Missing bars (no trade in those 5 minutes) are filled flat from the previous close.
    Past days need >= min_bars real bars and a real 09:15 bar, else the day is dropped.
    `today` (day ordinal) is kept even when partial; bars after index `upto` are ignored
    (that is how the live engine drops the still-forming candle).
    """
    ts = np.asarray(a["ts"], dtype=np.int64)
    if len(ts) == 0:
        return None
    loc = ts + IST_OFF
    day = loc // 86400
    off = (loc % 86400) // 60 - OPEN_MIN
    idx = off // 5
    c_ = np.asarray(a["c"], dtype=float)
    ok = (off >= 0) & (idx < NB5) & (off % 5 == 0) & (c_ > 0)
    if today is not None and upto is not None:
        ok &= ~((day == today) & (idx > upto))
    if today is not None:
        ok &= day <= today
    if not ok.any():
        return None
    day, idx = day[ok], idx[ok]
    days = np.unique(day)
    row = np.searchsorted(days, day)
    D = len(days)
    out = {}
    for k in ("o", "h", "l", "c"):
        m = np.full((D, NB5), np.nan)
        m[row, idx] = np.asarray(a[k], dtype=float)[ok]
        out[k.upper()] = m
    V = np.zeros((D, NB5))
    V[row, idx] = np.asarray(a["v"], dtype=float)[ok]
    real = np.zeros((D, NB5), bool)
    real[row, idx] = True
    last_real = NB5 - 1 - np.argmax(real[:, ::-1], axis=1)
    is_today = (days == today) if today is not None else np.zeros(D, bool)
    fill_to = np.where(is_today, last_real, NB5 - 1)
    Cf = pd.DataFrame(out["C"]).ffill(axis=1).values
    cols = np.arange(NB5)[None, :]
    fill = (~real) & (cols <= fill_to[:, None]) & ~np.isnan(Cf)
    for k in ("O", "H", "L", "C"):
        out[k][fill] = Cf[fill]
    V[np.isnan(out["C"])] = np.nan
    keep = ((real.sum(axis=1) >= min_bars) & real[:, 0]) | is_today
    fresh = np.ones(D, bool)
    if today is not None and upto is not None:
        fresh = np.where(is_today, real[:, min(upto, NB5 - 1)], True)
    res = {k: out[k][keep] for k in ("O", "H", "L", "C")}
    res["V"] = V[keep]
    res["days"] = days[keep]
    res["fresh"] = fresh[keep]
    return res


def agg(m, k=3):
    """(D,75) 5-minute matrices -> (D,25) 15-minute. A 15-min bar missing any 5-min bar is NaN."""
    D = m["O"].shape[0]
    nb = NB5 // k
    r = lambda x: x.reshape(D, nb, k)
    bad = np.isnan(r(m["C"])).any(axis=2)
    out = dict(m)
    out["O"] = r(m["O"])[:, :, 0].copy()
    out["C"] = r(m["C"])[:, :, -1].copy()
    out["H"] = r(m["H"]).max(axis=2)
    out["L"] = r(m["L"]).min(axis=2)
    out["V"] = r(m["V"]).sum(axis=2)
    for f in ("O", "H", "L", "C", "V"):
        out[f][bad] = np.nan
    return out


def indicators(m):
    """Adds vwap, e9, e21, rsi, atr, vavg (bar level) and gap, trend (day level)."""
    O, H, L, C, V = m["O"], m["H"], m["L"], m["C"], m["V"]
    D, nb = C.shape
    s = pd.Series(C.ravel())
    m["e9"] = s.ewm(span=9, adjust=False).mean().values.reshape(D, nb)
    m["e21"] = s.ewm(span=21, adjust=False).mean().values.reshape(D, nb)
    d = s.diff()
    ru = d.clip(lower=0).ewm(alpha=1 / 14.0, adjust=False).mean()
    rd = (-d).clip(lower=0).ewm(alpha=1 / 14.0, adjust=False).mean()
    with np.errstate(divide="ignore", invalid="ignore"):
        m["rsi"] = (100 - 100 / (1 + ru / rd)).values.reshape(D, nb)
    pc = s.shift(1)
    h, l = pd.Series(H.ravel()), pd.Series(L.ravel())
    tr = pd.concat([h - l, (h - pc).abs(), (l - pc).abs()], axis=1).max(axis=1)
    m["atr"] = tr.ewm(alpha=1 / 14.0, adjust=False).mean().values.reshape(D, nb)
    m["vavg"] = pd.Series(V.ravel()).shift(1).rolling(20, min_periods=10).mean().values.reshape(D, nb)
    tp = (H + L + C) / 3.0
    cv = np.nancumsum(V, axis=1)
    with np.errstate(divide="ignore", invalid="ignore"):
        vw = np.nancumsum(np.where(np.isnan(tp * V), 0, tp * V), axis=1) / cv
    m["vwap"] = np.where(cv > 0, vw, C)
    dc = C[:, -1]
    prev = np.r_[np.nan, dc[:-1]]
    far = np.r_[True, np.diff(m["days"]) > 5]
    prev[far] = np.nan
    m["gap"] = (O[:, 0] / prev - 1) * 100.0
    sma = pd.Series(dc).shift(1).rolling(20, min_periods=15).mean().values
    m["trend"] = prev - sma
    return m


def prep(a, nif, tf, today=None, upto=None):
    """One symbol: bars -> matrices with indicators at timeframe tf. nif = prep_nifty() output."""
    m = to_matrix(a, today, upto)
    if m is None or len(m["days"]) < 2:
        return None
    if tf == 15:
        m = agg(m, 3)
    indicators(m)
    D, nb = m["C"].shape
    mk = np.full((D, nb), np.nan)
    if nif is not None and len(nif["days"]):
        pos = np.searchsorted(nif["days"], m["days"])
        pos_c = np.minimum(pos, len(nif["days"]) - 1)
        hit = nif["days"][pos_c] == m["days"]
        mk[hit] = nif["sign"][pos_c[hit]]
    m["mkt"] = mk
    return m


def prep_nifty(a, tf, today=None, upto=None):
    m = to_matrix(a, today, upto, min_bars=60)
    if m is None:
        return None
    if tf == 15:
        m = agg(m, 3)
    return {"days": m["days"], "sign": m["C"] - m["O"][:, :1], "O": m["O"], "C": m["C"]}


BAR_FIELDS = ["O", "H", "L", "C", "V", "vwap", "e9", "e21", "rsi", "atr", "vavg", "mkt"]
DAY_FIELDS = ["gap", "trend"]


def stack(items):
    """items: iterable of (sym_index, prepped matrix). Returns one stacked dict (float32)."""
    acc = {f: [] for f in BAR_FIELDS + DAY_FIELDS}
    day, sym, fresh = [], [], []
    for si, m in items:
        if m is None:
            continue
        for f in BAR_FIELDS + DAY_FIELDS:
            acc[f].append(m[f].astype(np.float32))
        day.append(m["days"].astype(np.int32))
        sym.append(np.full(len(m["days"]), si, np.int32))
        fresh.append(m["fresh"])
    if not day:
        return None
    M = {}
    for f in BAR_FIELDS + DAY_FIELDS:
        M[f] = np.concatenate(acc[f])
        acc[f] = None
    M["day"] = np.concatenate(day)
    M["sym"] = np.concatenate(sym)
    M["fresh"] = np.concatenate(fresh)
    return M


# ----------------------------------------------------------------------------
# signals
# ----------------------------------------------------------------------------
def side_view(M, side):
    """side=+1 long, -1 short. Short = long logic on mirrored prices."""
    if side == 1:
        return M
    V = dict(M)
    V["O"], V["C"] = -M["O"], -M["C"]
    V["H"], V["L"] = -M["L"], -M["H"]
    V["vwap"], V["e9"], V["e21"] = -M["vwap"], -M["e9"], -M["e21"]
    V["rsi"] = 100 - M["rsi"]
    V["gap"], V["trend"], V["mkt"] = -M["gap"], -M["trend"], -M["mkt"]
    return V


def signal(V, entry, tf, c):
    """Boolean (rows, bars): True where the entry condition completes at that bar's close."""
    O, H, C = V["O"], V["H"], V["C"]
    R, nb = C.shape
    sig = np.zeros((R, nb), bool)
    with np.errstate(invalid="ignore"):
        if entry in ("ORB15", "ORB30"):
            k = (15 if entry == "ORB15" else 30) // tf
            orh = H[:, :k].max(axis=1)[:, None]
            sig[:, 1:] = (C[:, 1:] > orh) & (C[:, :-1] <= orh)
            sig[:, :k] = False
        elif entry == "VWAPX":
            vw = V["vwap"]
            sig[:, 1:] = (C[:, 1:] > vw[:, 1:]) & (C[:, :-1] <= vw[:, :-1])
        elif entry == "EMAX":
            a, b = V["e9"], V["e21"]
            sig[:, 1:] = (a[:, 1:] > b[:, 1:]) & (a[:, :-1] <= b[:, :-1]) & ~np.isnan(C[:, 1:])
        elif entry == "RSIREV":
            r = V["rsi"]
            sig[:, 1:] = (r[:, :-1] < 30) & (r[:, 1:] >= 30) & ~np.isnan(C[:, 1:])
        elif entry == "HIBRK":
            k = 30 // tf
            prior = np.maximum.accumulate(H, axis=1)[:, :-1]
            sig[:, 1:] = C[:, 1:] > prior
            sig[:, :k] = False
        elif entry in GAP_ENTRIES:
            b = 15 // tf - 1
            g = V["gap"]
            if entry == "GAPGO":
                sig[:, b] = (g >= c["gap_pct"]) & (C[:, b] > O[:, 0])
            else:
                sig[:, b] = (g <= -c["gap_pct"]) & (C[:, b] > O[:, 0])
        else:
            raise ValueError("unknown entry " + entry)
    return sig


def filt(V, name, c):
    with np.errstate(invalid="ignore"):
        if name == "NONE":
            return None
        if name == "VOL":
            return V["V"] >= c["vol_mult"] * V["vavg"]
        if name == "TREND":
            return (V["trend"] > 0)[:, None]
        if name == "MKT":
            return V["mkt"] > 0
    raise ValueError("unknown filter " + name)


def first_entry(sig, tf, window):
    """First signal whose entry bar (the bar after the signal bar) lies inside the window.
    Returns entry bar index per row, -1 where there is none."""
    w0, w1 = WINDOWS[window]
    e0, e1 = bar_of(w0, tf), bar_of(w1, tf)
    sub = sig[:, e0 - 1:e1 - 1]
    has = sub.any(axis=1)
    return np.where(has, sub.argmax(axis=1) + e0, -1)


def first_k(day, e, rank, k):
    """Rows of the first k entries of each day (earliest bar first, then most liquid)."""
    idx = np.nonzero(e >= 0)[0]
    if len(idx) == 0:
        return idx
    order = np.lexsort((rank[idx], e[idx], day[idx]))
    s = idx[order]
    d = day[s]
    start = np.r_[True, d[1:] != d[:-1]]
    first = np.maximum.accumulate(np.where(start, np.arange(len(s)), 0))
    return np.sort(s[(np.arange(len(s)) - first) < k])


def stop_dist(atr, price, stopm, c):
    return np.clip(stopm * atr, price * c["stop_min_pct"] / 100.0, price * c["stop_max_pct"] / 100.0)


TP_MULT = {"TP15": 1.5, "TP25": 2.5}


def simulate(V, rows, e, stopm, exit_mode, tf, c):
    """Long-logic trade simulation on a (possibly mirrored) view.
    Entry at the open of bar e. Stop is checked before target inside a bar (pessimistic).
    Everything still open is closed at the 15:15 bar open. Returns (gross % return, ok mask)."""
    sq = bar_of(1515, tf)
    n = len(rows)
    if n == 0:
        return np.zeros(0), np.zeros(0, bool)
    O = V["O"][rows].astype(float)
    H = V["H"][rows].astype(float)
    L = V["L"][rows].astype(float)
    ar = np.arange(n)
    entry = O[ar, e]
    atr = V["atr"][rows, e - 1].astype(float)
    ok = np.isfinite(entry) & np.isfinite(atr) & (atr > 0)
    ref = np.abs(entry)
    dist = stop_dist(atr, ref, stopm, c)
    stop = entry - dist
    mult = TP_MULT.get(exit_mode)
    tgt = entry + mult * dist if mult else np.full(n, np.inf)
    trail = exit_mode == "TRAIL"
    best = entry.copy()
    px = np.full(n, np.nan)
    open_ = ok.copy()
    for j in range(int(e.min()), sq):
        live = open_ & (e <= j)
        if not live.any():
            continue
        o, hi, lo = O[:, j], H[:, j], L[:, j]
        later = e < j
        hs = live & (lo <= stop)
        ps = np.where(later & (o < stop), o, stop)
        ht = live & ~hs & (hi >= tgt)
        pt = np.where(later & (o > tgt), o, tgt)
        px[hs] = ps[hs]
        px[ht] = pt[ht]
        open_ &= ~(hs | ht)
        if trail:
            u = open_ & (e <= j)
            best[u] = np.maximum(best[u], hi[u])
            stop[u] = np.maximum(stop[u], best[u] - dist[u])
    px[open_] = O[open_, sq]
    with np.errstate(invalid="ignore"):
        ret = (px - entry) / ref * 100.0
    ok &= np.isfinite(ret)
    return ret, ok


def strat_id(s):
    return "%s-%s-%dm-%s-%s-x%s-%s" % (s["entry"], "L" if s["side"] == 1 else "S", s["tf"],
                                       s["filt"], s["window"], s["stopm"], s["exit"])


def load_npz(sym):
    p = os.path.join(DATA, sym + ".npz")
    if not os.path.exists(p):
        return None
    z = np.load(p)
    return {k: z[k] for k in ("ts", "o", "h", "l", "c", "v")}


def save_npz(sym, a):
    if not os.path.isdir(DATA):
        os.makedirs(DATA)
    tmp = os.path.join(DATA, sym + ".tmp.npz")
    np.savez_compressed(tmp, **a)
    os.replace(tmp, os.path.join(DATA, sym + ".npz"))


def rows_to_arrays(rows):
    return {
        "ts": np.array([bar_epoch(r["date"]) for r in rows], dtype=np.int64),
        "o": np.array([r["open"] for r in rows], dtype=float),
        "h": np.array([r["high"] for r in rows], dtype=float),
        "l": np.array([r["low"] for r in rows], dtype=float),
        "c": np.array([r["close"] for r in rows], dtype=float),
        "v": np.array([r["volume"] for r in rows], dtype=float),
    }


def merge_arrays(a, b):
    """Concatenate two bar sets; where timestamps repeat, b wins."""
    if a is None or len(a["ts"]) == 0:
        return b
    if b is None or len(b["ts"]) == 0:
        return a
    keep = ~np.isin(a["ts"], b["ts"])
    out = {k: np.concatenate([a[k][keep], b[k]]) for k in ("ts", "o", "h", "l", "c", "v")}
    order = np.argsort(out["ts"], kind="stable")
    return {k: out[k][order] for k in out}
