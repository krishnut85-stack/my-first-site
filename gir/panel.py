#!/usr/bin/env python3
"""
PANEL v1.0 — 112-judge interview panel for NSE equities (top 2000 by turnover).
Standalone module. Never imports gir.py. Zero LLM. Pure math.

16 families x 7 judges = 112 judges.
- Families 1-9, 11-16 vote 1..10 (judge error/insufficient data -> neutral 5).
- Family 10 (Risk-Veto) is a GATE: excluded from the mean; any veto -> stock
  disqualified outright (score forced to 0, no averaging past a veto).
Signal = mean >= 7.0 AND agreement >= 70% (share of voting judges scoring >= 6).

Usage (on droplet, after: cd /home/globalbot && set -a && source .env && set +a):
  python3 panel.py warmup      # fetch universe + 400d candles + FII/DII + delivery + bulk deals (run pre-market, ~12-15 min)
  python3 panel.py scan        # score all cached stocks, log votes to SQLite, print top 25
  python3 panel.py votes RELIANCE   # show all 112 votes for one stock from last run
  python3 panel.py test        # offline self-test on synthetic data (no network)

Data stores:
  /home/globalbot/panel_cache/hist.pkl        candles cache
  /home/globalbot/panel_cache/fii_dii.json    rolling FII/DII daily store (warms up over days)
  /home/globalbot/panel_cache/deliv_*.csv     delivery bhavcopy cache
  /home/globalbot/panel_cache/bulk.json       bulk deals (last 10 days)
  /home/globalbot/panel.db                    runs / results / per-judge votes
"""

import os, sys, json, time, math, pickle, sqlite3, datetime as dt
import numpy as np

BASE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(BASE, "panel_cache")
DB_PATH = os.path.join(BASE, "panel.db")
os.makedirs(CACHE, exist_ok=True)

UNIVERSE_SIZE = 2000
HIST_DAYS = 1000
MIN_BARS = 120            # veto: insufficient history
MIN_AVG_TURNOVER = 1e7    # veto: < 1 crore avg daily turnover
MIN_PRICE = 20.0          # veto: penny zone
SIGNAL_MEAN = 7.0
SIGNAL_AGREE = 0.70
NIFTY_TOKEN = 256265      # NIFTY 50 index instrument token on Kite
import re as _re
ETF_PAT = _re.compile(r"BEES$|ETF|^SETF|^HDFCGOLD|^HDFCSILVER|^AXISGOLD|^AXISILVER|"
                      r"^SILVERAG|^GOLDCASE|^SILVERCASE|IETF$|^LIQUID|^GILT|ADD$|^MON100|^MAFANG")
REGIME_MIN_NIFTY20 = -3.0

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
def now_ist():
    return dt.datetime.now(IST)

# ---------------------------------------------------------------- Kite login
def kite_login():
    """Standalone TOTP login. Tries common env var names from .env."""
    from kiteconnect import KiteConnect
    import pyotp, requests as rq

    def env(*names):
        for n in names:
            v = os.environ.get(n)
            if v:
                return v
        return None

    api_key = env("KITE_API_KEY", "API_KEY", "ZERODHA_API_KEY")
    api_secret = env("KITE_API_SECRET", "API_SECRET", "ZERODHA_API_SECRET")
    user_id = env("KITE_USER_ID", "ZERODHA_USER_ID", "USER_ID", "ZERODHA_ID")
    password = env("KITE_PASSWORD", "ZERODHA_PASSWORD", "PASSWORD")
    totp_key = env("KITE_TOTP_SECRET", "TOTP_SECRET", "ZERODHA_TOTP", "TOTP_KEY")
    missing = [k for k, v in [("api_key", api_key), ("api_secret", api_secret),
                              ("user_id", user_id), ("password", password),
                              ("totp", totp_key)] if not v]
    if missing:
        raise SystemExit(f"[PANEL] Missing env credentials: {missing}. "
                         f"Edit env() fallback names at top of kite_login() to match .env keys.")

    kite = KiteConnect(api_key=api_key)
    s = rq.Session()
    s.headers.update({"User-Agent": "Mozilla/5.0"})
    r = s.post("https://kite.zerodha.com/api/login",
               data={"user_id": user_id, "password": password}, timeout=20).json()
    if r.get("status") != "success":
        raise SystemExit(f"[PANEL] Kite login step1 failed: {r}")
    rid = r["data"]["request_id"]
    r2 = s.post("https://kite.zerodha.com/api/twofa",
                data={"user_id": user_id, "request_id": rid,
                      "twofa_value": pyotp.TOTP(totp_key).now(),
                      "twofa_type": "totp"}, timeout=20)
    if r2.json().get("status") != "success":
        raise SystemExit(f"[PANEL] Kite TOTP failed: {r2.text[:200]}")
    # hit connect login to get request_token via redirect
    r3 = s.get(f"https://kite.zerodha.com/connect/login?v=3&api_key={api_key}",
               allow_redirects=True, timeout=20)
    req_token = None
    for resp in list(r3.history) + [r3]:
        u = resp.url
        if "request_token=" in u:
            req_token = u.split("request_token=")[1].split("&")[0]
    if not req_token:
        raise SystemExit("[PANEL] Could not extract request_token from redirect.")
    sess = kite.generate_session(req_token, api_secret=api_secret)
    kite.set_access_token(sess["access_token"])
    print("[PANEL] Kite session OK.")
    return kite

# ---------------------------------------------------------------- NSE fetch
def nse_session():
    import requests as rq
    s = rq.Session()
    s.headers.update({
        "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                       "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"),
        "Accept": "*/*", "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.nseindia.com/"})
    try:
        s.get("https://www.nseindia.com", timeout=15)
    except Exception as e:
        print(f"[PANEL] NSE warmup failed (non-fatal): {e}")
    return s

def fetch_fii_dii():
    """Append today's FII/DII cash numbers to rolling store. Graceful on failure."""
    path = os.path.join(CACHE, "fii_dii.json")
    store = {}
    if os.path.exists(path):
        try:
            store = json.load(open(path))
        except Exception:
            store = {}
    try:
        s = nse_session()
        data = s.get("https://www.nseindia.com/api/fiidiiTradeReact", timeout=20).json()
        for row in data:
            cat = (row.get("category") or "").upper()
            d = row.get("date") or now_ist().strftime("%d-%b-%Y")
            net = float(str(row.get("netValue", "0")).replace(",", ""))
            store.setdefault(d, {})
            if "FII" in cat or "FPI" in cat:
                store[d]["fii"] = net
            elif "DII" in cat:
                store[d]["dii"] = net
        json.dump(store, open(path, "w"))
        print(f"[PANEL] FII/DII store: {len(store)} day(s).")
    except Exception as e:
        print(f"[PANEL] FII/DII fetch failed (judges will vote neutral): {e}")
    return store

def fetch_bulk_deals():
    """Bulk deals for last 10 days -> {symbol: net_buy_qty}. Graceful on failure."""
    path = os.path.join(CACHE, "bulk.json")
    try:
        s = nse_session()
        to_d = now_ist().date()
        fr_d = to_d - dt.timedelta(days=14)
        url = ("https://www.nseindia.com/api/historical/bulk-deals?from="
               f"{fr_d.strftime('%d-%m-%Y')}&to={to_d.strftime('%d-%m-%Y')}")
        data = s.get(url, timeout=25).json().get("data", [])
        net = {}
        for row in data:
            sym = row.get("BD_SYMBOL") or row.get("symbol")
            qty = float(str(row.get("BD_QTY_TRD", row.get("qty", 0))).replace(",", "") or 0)
            side = (row.get("BD_BUY_SELL") or row.get("buySell") or "").upper()
            if not sym:
                continue
            net[sym] = net.get(sym, 0.0) + (qty if side.startswith("B") else -qty)
        json.dump(net, open(path, "w"))
        print(f"[PANEL] Bulk deals: {len(net)} symbols in last 10 sessions.")
        return net
    except Exception as e:
        print(f"[PANEL] Bulk deals fetch failed (judges neutral): {e}")
        if os.path.exists(path):
            try:
                return json.load(open(path))
            except Exception:
                pass
        return {}

def fetch_delivery(days=25):
    """Fetch sec_bhavdata_full CSVs for last `days` weekdays -> {sym: [deliv_pct...]} oldest->newest."""
    import requests as rq
    out = {}
    d = now_ist().date()
    got = 0
    tried = 0
    hdr = {"User-Agent": "Mozilla/5.0"}
    while got < days and tried < days * 2 + 10:
        tried += 1
        d -= dt.timedelta(days=1)
        if d.weekday() >= 5:
            continue
        tag = d.strftime("%d%m%Y")
        fp = os.path.join(CACHE, f"deliv_{tag}.csv")
        if not os.path.exists(fp):
            url = f"https://archives.nseindia.com/products/content/sec_bhavdata_full_{tag}.csv"
            try:
                r = rq.get(url, headers=hdr, timeout=20)
                if r.status_code != 200 or len(r.text) < 1000:
                    continue
                open(fp, "w").write(r.text)
            except Exception:
                continue
        try:
            for line in open(fp).read().splitlines()[1:]:
                c = [x.strip() for x in line.split(",")]
                if len(c) < 15 or c[1] != "EQ":
                    continue
                sym = c[0]
                try:
                    dp = float(c[14])
                except Exception:
                    continue
                out.setdefault(sym, []).append((d.toordinal(), dp))
            got += 1
        except Exception:
            continue
    final = {}
    for sym, rows in out.items():
        rows.sort()
        final[sym] = [p for _, p in rows]
    print(f"[PANEL] Delivery data: {got} day(s), {len(final)} symbols.")
    return final

# ---------------------------------------------------------------- warmup
def warmup():
    kite = kite_login()
    instruments = kite.instruments("NSE")
    eq = [i for i in instruments
          if i.get("instrument_type") == "EQ" and i.get("segment") == "NSE"
          and "-" not in i["tradingsymbol"]]
    print(f"[PANEL] NSE EQ instruments: {len(eq)}")
    to_d = now_ist().date()
    fr_d = to_d - dt.timedelta(days=HIST_DAYS)
    hist = {}
    fails = 0
    t0 = time.time()
    for n, ins in enumerate(eq, 1):
        tok, sym = ins["instrument_token"], ins["tradingsymbol"]
        ok = False
        for attempt in range(3):
            try:
                bars = kite.historical_data(tok, fr_d, to_d, "day")
                if bars and len(bars) >= 30:
                    hist[sym] = {
                        "o": np.array([b["open"] for b in bars], dtype=np.float64),
                        "h": np.array([b["high"] for b in bars], dtype=np.float64),
                        "l": np.array([b["low"] for b in bars], dtype=np.float64),
                        "c": np.array([b["close"] for b in bars], dtype=np.float64),
                        "v": np.array([b["volume"] for b in bars], dtype=np.float64),
                    }
                ok = True
                break
            except Exception:
                time.sleep(1.0 + attempt)
        if not ok:
            fails += 1
        time.sleep(0.34)  # ~3 req/s historical limit
        if n % 200 == 0:
            print(f"[PANEL] candles {n}/{len(eq)} ({time.time()-t0:.0f}s, fails={fails})")
    # NIFTY index
    try:
        bars = kite.historical_data(NIFTY_TOKEN, fr_d, to_d, "day")
        hist["__NIFTY__"] = {"c": np.array([b["close"] for b in bars], dtype=np.float64)}
    except Exception as e:
        print(f"[PANEL] NIFTY fetch failed (breadth family partial): {e}")
    # rank by avg turnover, keep top UNIVERSE_SIZE
    ranks = []
    for sym, d in hist.items():
        if sym == "__NIFTY__":
            continue
        if ETF_PAT.search(sym):
            continue
        c, v = d["c"], d["v"]
        if len(c) < 25:
            continue
        ranks.append((float(np.mean(c[-20:] * v[-20:])), sym))
    ranks.sort(reverse=True)
    keep = {sym for _, sym in ranks[:UNIVERSE_SIZE]}
    keep.add("__NIFTY__")
    hist = {s: d for s, d in hist.items() if s in keep}
    pickle.dump(hist, open(os.path.join(CACHE, "hist.pkl"), "wb"))
    print(f"[PANEL] Cached {len(hist)-1} stocks + NIFTY in {time.time()-t0:.0f}s (fails={fails}).")
    fetch_fii_dii()
    fetch_bulk_deals()
    fetch_delivery()
    print("[PANEL] Warmup complete.")

# ---------------------------------------------------------------- indicators
def ema(x, n):
    if len(x) < n:
        return None
    a = 2.0 / (n + 1)
    out = np.empty_like(x)
    out[0] = x[0]
    for i in range(1, len(x)):
        out[i] = a * x[i] + (1 - a) * out[i - 1]
    return out

def rsi(c, n=14):
    if len(c) < n + 2:
        return None
    d = np.diff(c)
    up = np.where(d > 0, d, 0.0)
    dn = np.where(d < 0, -d, 0.0)
    ru = ema(up, n)
    rd = ema(dn, n)
    rs = ru / np.where(rd == 0, 1e-9, rd)
    return 100 - 100 / (1 + rs)

def atr(h, l, c, n=14):
    if len(c) < n + 2:
        return None
    pc = np.roll(c, 1); pc[0] = c[0]
    tr = np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))
    return ema(tr, n)

def roc(c, n):
    if len(c) < n + 1:
        return None
    return (c[n:] / c[:-n] - 1) * 100

def weekly(c):
    n = (len(c) // 5) * 5
    if n < 10:
        return None
    return c[len(c) - n:].reshape(-1, 5)[:, -1]

def lin(v, lo, hi, slo=1.0, shi=10.0):
    """Map v in [lo,hi] linearly to [slo,shi], clipped. Always >= 1."""
    if hi == lo:
        return 5.0
    s = slo + (shi - slo) * (v - lo) / (hi - lo)
    return float(min(10.0, max(1.0, s)))

# ---------------------------------------------------------------- features
def features(sym, d, mkt):
    """Precompute everything judges need for one stock. Any failure -> partial dict."""
    f = {"sym": sym}
    o, h, l, c, v = d["o"], d["h"], d["l"], d["c"], d["v"]
    f.update(o=o, h=h, l=l, c=c, v=v, n=len(c))
    for p in (2, 7, 9, 14, 21):
        r = rsi(c, p)
        f[f"rsi{p}"] = r
    for p in (5, 9, 12, 20, 21, 26, 50, 200):
        f[f"ema{p}"] = ema(c, p)
    f["atr14"] = atr(h, l, c, 14)
    f["atr50"] = atr(h, l, c, 50)
    for p in (5, 10, 20, 60, 120):
        f[f"roc{p}"] = roc(c, p)
    f["wk"] = weekly(c)
    f["turn20"] = float(np.mean(c[-20:] * v[-20:])) if len(c) >= 20 else 0.0
    f["mkt"] = mkt
    return f

def market_context(hist, fii_store, today_key_fmt="%d-%b-%Y"):
    """Market-wide context shared by all stocks: NIFTY trend, breadth, FII/DII."""
    mkt = {}
    nif = hist.get("__NIFTY__", {}).get("c")
    mkt["nifty"] = nif
    if nif is not None and len(nif) >= 60:
        mkt["nifty_e20"] = ema(nif, 20)
        mkt["nifty_e50"] = ema(nif, 50)
    adv = dec = ab20 = ab50 = nh = nl = tot = 0
    for s, d in hist.items():
        if s == "__NIFTY__":
            continue
        c = d["c"]
        if len(c) < 55:
            continue
        tot += 1
        if c[-1] > c[-2]:
            adv += 1
        else:
            dec += 1
        e20 = np.mean(c[-20:]); e50 = np.mean(c[-50:])
        ab20 += int(c[-1] > e20)
        ab50 += int(c[-1] > e50)
        look = c[-55:]
        if c[-1] >= look.max():
            nh += 1
        if c[-1] <= look.min():
            nl += 1
    mkt.update(adv=adv, dec=dec, ab20=ab20, ab50=ab50, nh=nh, nl=nl, tot=max(tot, 1))
    # FII/DII rolling series oldest->newest
    days = sorted(fii_store.keys(),
                  key=lambda k: dt.datetime.strptime(k, today_key_fmt)
                  if _dateparse_ok(k, today_key_fmt) else dt.datetime.min)
    fii = [fii_store[k].get("fii") for k in days if fii_store[k].get("fii") is not None]
    dii = [fii_store[k].get("dii") for k in days if fii_store[k].get("dii") is not None]
    mkt["fii"] = fii
    mkt["dii"] = dii
    return mkt

def _dateparse_ok(k, fmt):
    try:
        dt.datetime.strptime(k, fmt)
        return True
    except Exception:
        return False

# ---------------------------------------------------------------- judges
# Each judge: (family, name, fn(f) -> float 1..10 or None for neutral 5)
JUDGES = []
def J(family, name):
    def deco(fn):
        JUDGES.append((family, name, fn))
        return fn
    return deco

# --- F1 Momentum (RSI zones favor strong-but-not-blown momentum; ROC strength)
def _rsi_zone(val):
    if val is None or math.isnan(val):
        return None
    if val >= 85: return 4.0
    if val >= 75: return 6.5
    if val >= 60: return 9.0
    if val >= 50: return 7.0
    if val >= 40: return 4.5
    return 2.0
for _p in (7, 9, 14, 21):
    def _mk(p=_p):
        @J("momentum", f"rsi{p}_zone")
        def _(f):
            r = f.get(f"rsi{p}")
            return None if r is None else _rsi_zone(float(r[-1]))
    _mk()
for _p in (5, 10, 20):
    def _mk(p=_p):
        @J("momentum", f"roc{p}")
        def _(f):
            r = f.get(f"roc{p}")
            if r is None: return None
            return lin(float(r[-1]), -3.0, 8.0)
    _mk()

# --- F2 Trend (EMA crosses + price location)
for _a, _b in ((5, 20), (9, 21), (20, 50), (50, 200)):
    def _mk(a=_a, b=_b):
        @J("trend", f"ema{a}x{b}")
        def _(f):
            ea, eb = f.get(f"ema{a}"), f.get(f"ema{b}")
            if ea is None or eb is None: return None
            gap = (ea[-1] - eb[-1]) / eb[-1] * 100
            return lin(gap, -2.0, 4.0)
    _mk()
for _p in (20, 50, 200):
    def _mk(p=_p):
        @J("trend", f"px_above_ema{p}")
        def _(f):
            e = f.get(f"ema{p}")
            if e is None: return None
            gap = (f["c"][-1] - e[-1]) / e[-1] * 100
            return lin(gap, -3.0, 6.0)
    _mk()

# --- F3 Volume
for _p in (10, 20, 50):
    def _mk(p=_p):
        @J("volume", f"surge_vs_{p}d")
        def _(f):
            v = f["v"]
            if len(v) < p + 1: return None
            base = np.mean(v[-p-1:-1])
            if base <= 0: return None
            return lin(v[-1] / base, 0.5, 3.0)
    _mk()
for _p in (10, 20):
    def _mk(p=_p):
        @J("volume", f"obv_slope_{p}")
        def _(f):
            c, v = f["c"], f["v"]
            if len(c) < p + 2: return None
            sign = np.sign(np.diff(c[-(p+1):]))
            obv = np.cumsum(sign * v[-p:])
            return 8.0 if obv[-1] > 0 and obv[-1] >= obv.max() * 0.95 else (6.5 if obv[-1] > 0 else 3.0)
    _mk()
for _p in (10, 20):
    def _mk(p=_p):
        @J("volume", f"updayvol_{p}")
        def _(f):
            c, v = f["c"], f["v"]
            if len(c) < p + 1: return None
            d = np.diff(c[-(p+1):]); vv = v[-p:]
            up = vv[d > 0].sum(); dn = vv[d < 0].sum()
            if up + dn <= 0: return None
            return lin(up / (up + dn), 0.3, 0.75)
    _mk()

# --- F4 Volatility
@J("volatility", "atr_expansion")
def _(f):
    a14, a50 = f.get("atr14"), f.get("atr50")
    if a14 is None or a50 is None or a50[-1] <= 0: return None
    return lin(a14[-1] / a50[-1], 0.7, 1.6)
@J("volatility", "atr_pct_sweet")
def _(f):
    a = f.get("atr14")
    if a is None: return None
    ap = a[-1] / f["c"][-1] * 100
    if 1.5 <= ap <= 4.0: return 8.5
    if 1.0 <= ap < 1.5 or 4.0 < ap <= 5.5: return 6.0
    return 3.0
@J("volatility", "bb_squeeze20")
def _(f):
    c = f["c"]
    if len(c) < 120: return None
    w = []
    for i in range(100):
        seg = c[-(20 + i):len(c) - i] if i else c[-20:]
        w.append(np.std(seg) / max(np.mean(seg), 1e-9))
    cur = w[0]
    rank = sum(1 for x in w if x < cur) / len(w)
    return lin(1 - rank, 0.0, 1.0)  # tighter than history = higher
@J("volatility", "bb_breakout20")
def _(f):
    c = f["c"]
    if len(c) < 21: return None
    m = np.mean(c[-21:-1]); sd = np.std(c[-21:-1])
    if sd <= 0: return None
    z = (c[-1] - m) / sd
    return lin(z, -1.0, 2.5)
@J("volatility", "nr7")
def _(f):
    h, l = f["h"], f["l"]
    if len(h) < 8: return None
    rng = h[-7:] - l[-7:]
    return 8.0 if rng[-1] == rng.min() else 5.0
@J("volatility", "range_expansion")
def _(f):
    h, l = f["h"], f["l"]
    if len(h) < 11: return None
    base = np.mean((h - l)[-11:-1])
    if base <= 0: return None
    return lin((h[-1] - l[-1]) / base, 0.5, 2.5)
@J("volatility", "close_location")
def _(f):
    h, l, c = f["h"][-1], f["l"][-1], f["c"][-1]
    if h <= l: return None
    return lin((c - l) / (h - l), 0.0, 1.0)

# --- F5 Structure
@J("structure", "hh_hl_20")
def _(f):
    h, l = f["h"], f["l"]
    if len(h) < 21: return None
    hh = sum(1 for i in range(-10, 0) if h[i] > h[i - 5])
    hl = sum(1 for i in range(-10, 0) if l[i] > l[i - 5])
    return lin(hh + hl, 4, 18)
@J("structure", "dist_52w_high")
def _(f):
    c = f["c"]
    if len(c) < 200: return None
    pk = c[-250:].max() if len(c) >= 250 else c.max()
    gap = (pk - c[-1]) / pk * 100
    if gap <= 3: return 9.0
    if gap <= 8: return 7.5
    if gap <= 15: return 5.5
    if gap <= 30: return 3.5
    return 2.0
@J("structure", "dist_52w_low")
def _(f):
    c = f["c"]
    if len(c) < 200: return None
    lo = c[-250:].min() if len(c) >= 250 else c.min()
    return lin((c[-1] - lo) / lo * 100, 0, 80)
@J("structure", "closes_above_prior_high")
def _(f):
    c, h = f["c"], f["h"]
    if len(c) < 6: return None
    k = sum(1 for i in range(-5, 0) if c[i] > h[i - 1])
    return lin(k, 0, 5)
@J("structure", "base_tightness20")
def _(f):
    c = f["c"]
    if len(c) < 20: return None
    rng = (c[-20:].max() - c[-20:].min()) / max(c[-20:].mean(), 1e-9) * 100
    if rng <= 8: return 8.5
    if rng <= 15: return 6.5
    if rng <= 25: return 4.5
    return 2.5
@J("structure", "above_20d_pivot")
def _(f):
    c = f["c"]
    if len(c) < 21: return None
    piv = (max(f["h"][-21:-1]) + min(f["l"][-21:-1]) + c[-2]) / 3
    return 8.0 if c[-1] > piv else 3.0
@J("structure", "support_hold_50d")
def _(f):
    c, l = f["c"], f["l"]
    if len(c) < 50: return None
    sup = l[-50:].min()
    return lin((c[-1] - sup) / sup * 100, 0, 25)

# --- F6 Mean reversion (these intentionally disagree with momentum)
@J("meanrev", "rsi2_bounce")
def _(f):
    r = f.get("rsi2")
    if r is None: return None
    val = float(r[-1])
    if val < 10: return 9.0
    if val < 25: return 7.0
    if val > 90: return 2.0
    return 5.0
@J("meanrev", "stretch_below_e20")
def _(f):
    e = f.get("ema20")
    if e is None: return None
    gap = (f["c"][-1] - e[-1]) / e[-1] * 100
    return lin(-gap, -2.0, 8.0)
@J("meanrev", "bb_lower_touch")
def _(f):
    c = f["c"]
    if len(c) < 21: return None
    m = np.mean(c[-21:-1]); sd = np.std(c[-21:-1])
    if sd <= 0: return None
    z = (c[-1] - m) / sd
    return lin(-z, -1.0, 2.5)
@J("meanrev", "down3_volume")
def _(f):
    c, v = f["c"], f["v"]
    if len(c) < 25: return None
    drop3 = (c[-1] / c[-4] - 1) * 100
    volr = v[-1] / max(np.mean(v[-21:-1]), 1e-9)
    return 8.0 if drop3 < -5 and volr > 1.5 else (6.0 if drop3 < -3 else 4.0)
@J("meanrev", "gap_down_recovery")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 2: return None
    gap = (o[-1] / c[-2] - 1) * 100
    if gap < -1.5 and c[-1] > o[-1]: return 8.5
    if gap < -1.5: return 4.0
    return 5.0
@J("meanrev", "atr_stretch")
def _(f):
    a, e = f.get("atr14"), f.get("ema20")
    if a is None or e is None or a[-1] <= 0: return None
    z = (e[-1] - f["c"][-1]) / a[-1]
    return lin(z, -1.0, 3.0)
@J("meanrev", "down_streak")
def _(f):
    c = f["c"]
    if len(c) < 8: return None
    k = 0
    for i in range(-1, -8, -1):
        if c[i] < c[i - 1]:
            k += 1
        else:
            break
    return lin(k, 0, 5)

# --- F7 Relative strength vs NIFTY
def _rel(f, p):
    nif = f["mkt"].get("nifty")
    c = f["c"]
    if nif is None or len(c) < p + 1 or len(nif) < p + 1: return None
    return (c[-1] / c[-p-1] - 1) - (nif[-1] / nif[-p-1] - 1)
for _p in (5, 20, 60, 120):
    def _mk(p=_p):
        @J("relstr", f"vs_nifty_{p}")
        def _(f):
            r = _rel(f, p)
            return None if r is None else lin(r * 100, -5.0, 10.0)
    _mk()
@J("relstr", "rs_line_high20")
def _(f):
    nif = f["mkt"].get("nifty"); c = f["c"]
    if nif is None or len(c) < 25 or len(nif) < 25: return None
    m = min(len(c), len(nif))
    rsline = c[-m:][-25:] / nif[-m:][-25:]
    return 9.0 if rsline[-1] >= rsline.max() * 0.999 else (6.0 if rsline[-1] > np.median(rsline) else 3.0)
@J("relstr", "outperf_streak")
def _(f):
    nif = f["mkt"].get("nifty"); c = f["c"]
    if nif is None or len(c) < 12 or len(nif) < 12: return None
    m = min(len(c), len(nif))
    sc = np.diff(c[-m:][-11:]) / c[-m:][-11:-1]
    sn = np.diff(nif[-m:][-11:]) / nif[-m:][-11:-1]
    return lin(int(np.sum(sc > sn)), 2, 9)
@J("relstr", "ratio_trend")
def _(f):
    nif = f["mkt"].get("nifty"); c = f["c"]
    if nif is None or len(c) < 60 or len(nif) < 60: return None
    m = min(len(c), len(nif))
    ratio = c[-m:][-60:] / nif[-m:][-60:]
    e = ema(ratio, 20)
    return 8.0 if e is not None and ratio[-1] > e[-1] else 3.5

# --- F8 Delivery / quality (delivery store injected into f["deliv"])
@J("quality", "deliv_level")
def _(f):
    d = f.get("deliv")
    if not d: return None
    return lin(d[-1], 20, 75)
@J("quality", "deliv_surge")
def _(f):
    d = f.get("deliv")
    if not d or len(d) < 6: return None
    base = np.mean(d[:-1])
    if base <= 0: return None
    return lin(d[-1] / base, 0.6, 2.0)
@J("quality", "deliv_trend")
def _(f):
    d = f.get("deliv")
    if not d or len(d) < 10: return None
    return 7.5 if np.mean(d[-5:]) > np.mean(d[-10:-5]) else 4.0
@J("quality", "vwap_position")
def _(f):
    h, l, c = f["h"][-1], f["l"][-1], f["c"][-1]
    tp = (h + l + c) / 3
    return lin((c - tp) / max(tp, 1e-9) * 100, -1.0, 1.0)
@J("quality", "turnover_class")
def _(f):
    t = f.get("turn20", 0)
    if t >= 50e7: return 8.5
    if t >= 10e7: return 7.0
    if t >= 3e7: return 5.5
    return 3.5
@J("quality", "price_class")
def _(f):
    px = f["c"][-1]
    if px >= 500: return 7.5
    if px >= 100: return 6.5
    if px >= 50: return 5.0
    return 3.5
@J("quality", "stability")
def _(f):
    c = f["c"]
    if len(c) < 60: return None
    rets = np.diff(c[-60:]) / c[-60:-1]
    worst = rets.min() * 100
    return lin(worst, -12.0, -1.0)

# --- F9 Candle patterns
@J("candle", "bull_engulf")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 2: return None
    return 8.5 if (c[-2] < o[-2] and c[-1] > o[-1] and c[-1] > o[-2] and o[-1] < c[-2]) else 5.0
@J("candle", "close_strength")
def _(f):
    h, l, c = f["h"][-1], f["l"][-1], f["c"][-1]
    if h <= l: return None
    return lin((c - l) / (h - l), 0.0, 1.0)
@J("candle", "close_strength_3d")
def _(f):
    h, l, c = f["h"], f["l"], f["c"]
    if len(c) < 3: return None
    vals = [(c[i] - l[i]) / (h[i] - l[i]) for i in range(-3, 0) if h[i] > l[i]]
    if not vals: return None
    return lin(float(np.mean(vals)), 0.0, 1.0)
@J("candle", "gap_up_hold")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 2: return None
    gap = (o[-1] / c[-2] - 1) * 100
    if gap > 0.8 and c[-1] >= o[-1]: return 9.0
    if gap > 0.8: return 3.0
    return 5.0
@J("candle", "inside_break")
def _(f):
    h, l, c = f["h"], f["l"], f["c"]
    if len(c) < 3: return None
    inside = h[-2] <= h[-3] and l[-2] >= l[-3]
    return 8.0 if inside and c[-1] > h[-2] else 5.0
@J("candle", "body_ratio")
def _(f):
    o, h, l, c = f["o"][-1], f["h"][-1], f["l"][-1], f["c"][-1]
    if h <= l: return None
    body = (c - o) / (h - l)
    return lin(body, -0.5, 0.9)
@J("candle", "hammer_at_low")
def _(f):
    o, h, l, c = f["o"], f["h"], f["l"], f["c"]
    if len(c) < 25: return None
    rng = h[-1] - l[-1]
    if rng <= 0: return None
    lower = min(o[-1], c[-1]) - l[-1]
    near_low = c[-1] <= np.min(c[-20:]) * 1.05
    return 8.0 if lower / rng > 0.6 and near_low else 5.0

# --- F10 RISK-VETO (gate only; True = veto)
VETOES = []
def V(name):
    def deco(fn):
        VETOES.append((name, fn))
        return fn
    return deco
@V("insufficient_history")
def _(f): return f["n"] < MIN_BARS
@V("illiquid_turnover")
def _(f): return f.get("turn20", 0) < MIN_AVG_TURNOVER
@V("penny_price")
def _(f): return f["c"][-1] < MIN_PRICE
@V("circuit_lock")
def _(f):
    h, l, c = f["h"][-1], f["l"][-1], f["c"][-1]
    if len(f["c"]) < 2: return False
    ret = (c / f["c"][-2] - 1) * 100
    return (h == l) or (ret > 9.5 and c >= h * 0.999)
@V("extreme_atr")
def _(f):
    a = f.get("atr14")
    return a is not None and (a[-1] / f["c"][-1] * 100) > 8.0
@V("dead_volume_days")
def _(f):
    v = f["v"]
    return len(v) >= 20 and int(np.sum(v[-20:] <= 0)) > 2
@V("crash_in_progress")
def _(f):
    c = f["c"]
    return len(c) >= 6 and (c[-1] / c[-6] - 1) < -0.18

# --- F11 Multi-timeframe alignment
@J("multitf", "weekly_trend")
def _(f):
    w = f.get("wk")
    if w is None or len(w) < 12: return None
    e = ema(w, 8)
    return 8.5 if w[-1] > e[-1] else 3.0
@J("multitf", "weekly_rsi")
def _(f):
    w = f.get("wk")
    if w is None or len(w) < 18: return None
    r = rsi(w, 14)
    return None if r is None else _rsi_zone(float(r[-1]))
@J("multitf", "monthly_trend")
def _(f):
    c = f["c"]
    if len(c) < 80: return None
    return 8.0 if c[-1] > np.mean(c[-60:]) else 3.0
@J("multitf", "daily_weekly_align")
def _(f):
    e20, w = f.get("ema20"), f.get("wk")
    if e20 is None or w is None or len(w) < 12: return None
    dly = f["c"][-1] > e20[-1]
    wke = ema(w, 8)
    wky = w[-1] > wke[-1]
    return 9.0 if dly and wky else (5.5 if dly or wky else 2.0)
@J("multitf", "triple_align")
def _(f):
    c = f["c"]
    e20, e50, e200 = f.get("ema20"), f.get("ema50"), f.get("ema200")
    if e20 is None or e50 is None or e200 is None: return None
    k = int(c[-1] > e20[-1]) + int(e20[-1] > e50[-1]) + int(e50[-1] > e200[-1])
    return lin(k, 0, 3)
@J("multitf", "weekly_higher_lows")
def _(f):
    w = f.get("wk")
    if w is None or len(w) < 8: return None
    k = sum(1 for i in range(-4, 0) if w[i] > w[i - 2])
    return lin(k, 0, 4)
@J("multitf", "fresh_weekly_high")
def _(f):
    w = f.get("wk")
    if w is None or len(w) < 12: return None
    return 8.5 if w[-1] >= w[-12:].max() * 0.999 else 4.5

# --- F12 Gap behavior
@J("gaps", "today_gap")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 2: return None
    return lin((o[-1] / c[-2] - 1) * 100, -1.5, 2.5)
@J("gaps", "gap_hold_rate60")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 61: return None
    holds = tries = 0
    for i in range(-60, 0):
        g = (o[i] / c[i - 1] - 1) * 100
        if g > 0.8:
            tries += 1
            holds += int(c[i] >= o[i])
    if tries < 3: return None
    return lin(holds / tries, 0.2, 0.8)
@J("gaps", "open_drive")
def _(f):
    o, l, c = f["o"][-1], f["l"][-1], f["c"][-1]
    return 8.0 if c > o and (o - l) / max(o, 1e-9) < 0.004 else 5.0
@J("gaps", "no_gap_fill")
def _(f):
    o, l, c = f["o"], f["l"], f["c"]
    if len(c) < 2: return None
    g = (o[-1] / c[-2] - 1) * 100
    if g <= 0.5: return 5.0
    return 8.5 if l[-1] > c[-2] else 3.5
@J("gaps", "gap_freq20")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 21: return None
    k = sum(1 for i in range(-20, 0) if abs(o[i] / c[i - 1] - 1) * 100 > 1.0)
    return lin(k, 0, 8)
@J("gaps", "runaway_gap")
def _(f):
    o, c = f["o"], f["c"]
    e20 = f.get("ema20")
    if len(c) < 2 or e20 is None: return None
    g = (o[-1] / c[-2] - 1) * 100
    return 8.5 if g > 1.0 and c[-1] > e20[-1] else 5.0
@J("gaps", "avg_gap_followthru")
def _(f):
    o, c = f["o"], f["c"]
    if len(c) < 41: return None
    fts = [ (c[i] / o[i] - 1) * 100 for i in range(-40, 0) if (o[i] / c[i - 1] - 1) * 100 > 0.8 ]
    if len(fts) < 3: return None
    return lin(float(np.mean(fts)), -1.0, 1.5)

# --- F13 Pivot / level
@J("pivots", "above_classic_pivot")
def _(f):
    h, l, c = f["h"], f["l"], f["c"]
    if len(c) < 2: return None
    piv = (h[-2] + l[-2] + c[-2]) / 3
    return 8.0 if c[-1] > piv else 3.5
@J("pivots", "above_pdh")
def _(f):
    h, c = f["h"], f["c"]
    if len(c) < 2: return None
    return 8.5 if c[-1] > h[-2] else 4.0
@J("pivots", "cpr_width")
def _(f):
    h, l, c = f["h"], f["l"], f["c"]
    if len(c) < 2: return None
    piv = (h[-2] + l[-2] + c[-2]) / 3
    bc = (h[-2] + l[-2]) / 2
    width = abs(piv - bc) / max(c[-2], 1e-9) * 100
    return 8.0 if width < 0.25 else (6.0 if width < 0.6 else 4.0)
@J("pivots", "room_to_r1")
def _(f):
    h, l, c = f["h"], f["l"], f["c"]
    if len(c) < 2: return None
    piv = (h[-2] + l[-2] + c[-2]) / 3
    r1 = 2 * piv - l[-2]
    return lin((r1 - c[-1]) / max(c[-1], 1e-9) * 100, -0.5, 2.0)
@J("pivots", "break_20d_high")
def _(f):
    h, c = f["h"], f["c"]
    if len(c) < 21: return None
    return 9.0 if c[-1] > h[-21:-1].max() else 4.5
@J("pivots", "break_50d_high")
def _(f):
    h, c = f["h"], f["c"]
    if len(c) < 51: return None
    return 9.0 if c[-1] > h[-51:-1].max() else 4.5
@J("pivots", "round_number")
def _(f):
    px = f["c"][-1]
    if px <= 0: return None
    near = min(px % 50, 50 - px % 50) / px * 100 if px >= 100 else min(px % 10, 10 - px % 10) / px * 100
    return 4.0 if near < 0.3 else 6.0  # mild penalty when pinned at round number

# --- F14 Momentum acceleration (ROC of ROC, RSI slope, MACD hist)
for _p in (5, 10, 20):
    def _mk(p=_p):
        @J("accel", f"roc_of_roc{p}")
        def _(f):
            r = f.get(f"roc{p}")
            if r is None or len(r) < 6: return None
            return lin(float(r[-1] - np.mean(r[-6:-1])), -2.0, 3.0)
    _mk()
for _p in (5, 10):
    def _mk(p=_p):
        @J("accel", f"rsi14_slope{p}")
        def _(f):
            r = f.get("rsi14")
            if r is None or len(r) < p + 1: return None
            return lin(float(r[-1] - r[-1 - p]), -8.0, 12.0)
    _mk()
@J("accel", "macd_hist_rising")
def _(f):
    e12, e26 = f.get("ema12"), f.get("ema26")
    if e12 is None or e26 is None: return None
    macd = e12 - e26
    sig = ema(macd, 9)
    hist = macd - sig
    if len(hist) < 3: return None
    return 8.5 if hist[-1] > hist[-2] > hist[-3] and hist[-1] > 0 else (6.0 if hist[-1] > hist[-2] else 3.5)
@J("accel", "vol_momentum_combo")
def _(f):
    r = f.get("roc10"); v = f["v"]
    if r is None or len(v) < 21: return None
    volr = v[-1] / max(np.mean(v[-21:-1]), 1e-9)
    return 9.0 if r[-1] > 3 and volr > 1.5 else (6.0 if r[-1] > 0 else 3.5)

# --- F15 Breadth / market context (same score for all stocks; regime tilt)
@J("breadth", "nifty_above_e20")
def _(f):
    m = f["mkt"]
    nif, e = m.get("nifty"), m.get("nifty_e20")
    if nif is None or e is None: return None
    return 8.0 if nif[-1] > e[-1] else 3.0
@J("breadth", "nifty_above_e50")
def _(f):
    m = f["mkt"]
    nif, e = m.get("nifty"), m.get("nifty_e50")
    if nif is None or e is None: return None
    return 7.5 if nif[-1] > e[-1] else 3.5
@J("breadth", "advance_decline")
def _(f):
    m = f["mkt"]
    return lin(m["adv"] / max(m["adv"] + m["dec"], 1), 0.3, 0.7)
@J("breadth", "pct_above_20")
def _(f):
    m = f["mkt"]
    return lin(m["ab20"] / m["tot"], 0.25, 0.75)
@J("breadth", "pct_above_50")
def _(f):
    m = f["mkt"]
    return lin(m["ab50"] / m["tot"], 0.25, 0.75)
@J("breadth", "highs_minus_lows")
def _(f):
    m = f["mkt"]
    return lin((m["nh"] - m["nl"]) / m["tot"], -0.05, 0.08)
@J("breadth", "nifty_5d")
def _(f):
    nif = f["mkt"].get("nifty")
    if nif is None or len(nif) < 6: return None
    return lin((nif[-1] / nif[-6] - 1) * 100, -2.5, 2.5)

# --- F16 Institutional flow (FII/DII + bulk deals + delivery-flow proxy)
@J("insti", "fii_today")
def _(f):
    fii = f["mkt"].get("fii") or []
    if not fii: return None
    return lin(fii[-1], -3000, 4000)
@J("insti", "fii_5d")
def _(f):
    fii = f["mkt"].get("fii") or []
    if len(fii) < 5: return None
    return lin(sum(fii[-5:]), -10000, 12000)
@J("insti", "dii_5d")
def _(f):
    dii = f["mkt"].get("dii") or []
    if len(dii) < 5: return None
    return lin(sum(dii[-5:]), -8000, 12000)
@J("insti", "combined_10d")
def _(f):
    fii = f["mkt"].get("fii") or []; dii = f["mkt"].get("dii") or []
    n = min(len(fii), len(dii))
    if n < 10: return None
    return lin(sum(fii[-10:]) + sum(dii[-10:]), -15000, 20000)
@J("insti", "fii_streak")
def _(f):
    fii = f["mkt"].get("fii") or []
    if len(fii) < 3: return None
    k = 0
    for x in reversed(fii):
        if x > 0: k += 1
        else: break
    return lin(k, 0, 5)
@J("insti", "bulk_deal_hit")
def _(f):
    bulk = f.get("bulk")
    if bulk is None: return None
    net = bulk.get(f["sym"])
    if net is None: return 5.0
    return 8.5 if net > 0 else 3.0
@J("insti", "deliv_flow_proxy")
def _(f):
    d = f.get("deliv")
    r = f.get("roc5")
    if not d or len(d) < 5 or r is None: return None
    return 8.5 if d[-1] > np.mean(d) and r[-1] > 0 else (3.5 if d[-1] < np.mean(d) and r[-1] < 0 else 5.5)

# ---------------------------------------------------------------- scoring
import json as _json
try:
    WEIGHTS = _json.load(open(os.path.join(BASE, "judge_weights.json")))
    print(f"[PANEL] judge weights loaded: {len(WEIGHTS)} (fired: {sum(1 for v in WEIGHTS.values() if v==0)})")
except Exception:
    WEIGHTS = {}

def score_stock(f):
    """Returns (vetoed:list, mean, agreement, votes:{judge:(family,score)})."""
    vetoed = []
    for name, fn in VETOES:
        try:
            if fn(f):
                vetoed.append(name)
        except Exception:
            pass  # veto crash must never false-disqualify
    votes = {}
    scores = []
    for family, name, fn in JUDGES:
        try:
            s = fn(f)
        except Exception:
            s = None
        s = 5.0 if s is None else float(min(10.0, max(1.0, s)))
        votes[name] = (family, s)
        scores.append(s)
    if WEIGHTS:
        ws = [(WEIGHTS.get(n, 1.0), sc) for n, (fam, sc) in votes.items()]
        tw = sum(w for w, _ in ws)
        mean = float(sum(w * sc for w, sc in ws) / tw) if tw > 0 else 0.0
        agree = float(sum(w for w, sc in ws if sc >= 6.0) / tw) if tw > 0 else 0.0
    else:
        mean = float(np.mean(scores)) if scores else 0.0
        agree = float(np.mean([1.0 if s >= 6.0 else 0.0 for s in scores])) if scores else 0.0
    if vetoed:
        mean = 0.0  # security escorts the candidate out
    return vetoed, mean, agree, votes

def composite_signal(votes, vetoed, regime_ok):
    """Two-pattern brain. A: dip-in-uptrend (27 sigs, +7.28%, win 70%).
    B: breakout-from-strength (22 sigs, +8.78%, win 64%, 0% overlap). 2026-06-11."""
    if vetoed or not regime_ok:
        return 0
    v = lambda n: votes.get(n, (None, 5.0))[1]
    trend = v("ema50x200") >= 8 and v("px_above_ema200") >= 8
    demand = v("close_strength_3d") >= 7
    if not (trend and demand):
        return 0
    if v("stretch_below_e20") >= 7 or v("gap_down_recovery") >= 8 or v("down3_volume") >= 7:
        return 1
    if (v("inside_break") >= 8 or v("gap_up_hold") >= 9) and v("dist_52w_low") >= 8:
        return 2
    return 0

# ---------------------------------------------------------------- DB
def db_init():
    con = sqlite3.connect(DB_PATH)
    con.executescript("""
    CREATE TABLE IF NOT EXISTS runs(run_id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts TEXT, n_stocks INTEGER, n_signals INTEGER);
    CREATE TABLE IF NOT EXISTS results(run_id INTEGER, symbol TEXT, mean REAL,
        agreement REAL, vetoed TEXT, signal INTEGER);
    CREATE TABLE IF NOT EXISTS votes(run_id INTEGER, symbol TEXT, family TEXT,
        judge TEXT, score REAL);
    CREATE INDEX IF NOT EXISTS ix_votes ON votes(run_id, symbol);
    CREATE INDEX IF NOT EXISTS ix_results ON results(run_id, mean);
    """)
    return con

# ---------------------------------------------------------------- scan
def scan():
    hp = os.path.join(CACHE, "hist.pkl")
    if not os.path.exists(hp):
        raise SystemExit("[PANEL] No candle cache. Run: python3 panel.py warmup")
    hist = pickle.load(open(hp, "rb"))
    fii_store = {}
    fp = os.path.join(CACHE, "fii_dii.json")
    if os.path.exists(fp):
        try: fii_store = json.load(open(fp))
        except Exception: pass
    bulk = {}
    bp = os.path.join(CACHE, "bulk.json")
    if os.path.exists(bp):
        try: bulk = json.load(open(bp))
        except Exception: pass
    deliv = fetch_delivery_cache_only()
    mkt = market_context(hist, fii_store)
    nif = hist.get("__NIFTY__", {}).get("c")
    nifty20 = (nif[-1] / nif[-21] - 1) * 100 if nif is not None and len(nif) >= 21 else 0.0
    regime_ok = nifty20 > REGIME_MIN_NIFTY20
    print(f"[PANEL] NIFTY 20d {nifty20:+.2f}% -> regime {'OK' if regime_ok else 'BLOCKED'}")
    t0 = time.time()
    rows = []
    con = db_init()
    cur = con.cursor()
    cur.execute("INSERT INTO runs(ts,n_stocks,n_signals) VALUES(?,?,?)",
                (now_ist().isoformat(), len(hist) - 1, 0))
    run_id = cur.lastrowid
    vote_rows = []
    for sym, d in hist.items():
        if sym == "__NIFTY__":
            continue
        if ETF_PAT.search(sym):
            continue
        try:
            f = features(sym, d, mkt)
            f["deliv"] = deliv.get(sym)
            f["bulk"] = bulk
            vetoed, mean, agree, votes = score_stock(f)
        except Exception as e:
            continue
        sig = composite_signal(votes, vetoed, regime_ok)
        rows.append((sym, mean, agree, vetoed, sig))
        cur.execute("INSERT INTO results VALUES(?,?,?,?,?,?)",
                    (run_id, sym, mean, agree, ",".join(vetoed), sig))
        for jname, (fam, s) in votes.items():
            vote_rows.append((run_id, sym, fam, jname, s))
    cur.executemany("INSERT INTO votes VALUES(?,?,?,?,?)", vote_rows)
    nsig = sum(r[4] for r in rows)
    cur.execute("UPDATE runs SET n_signals=? WHERE run_id=?", (nsig, run_id))
    con.commit(); con.close()
    rows.sort(key=lambda r: (-(r[4] > 0), -r[1]))
    print(f"\n[PANEL] Run #{run_id}: {len(rows)} stocks scored in {time.time()-t0:.1f}s "
          f"| judges={len(JUDGES)} vetoes={len(VETOES)} | SIGNALS: {nsig}\n")
    print(f"{'SYMBOL':<14}{'MEAN':>6}{'AGREE':>8}  {'STATUS'}")
    for sym, mean, agree, vetoed, sig in rows[:25]:
        st = {1: "SIGNAL-A DIP", 2: "SIGNAL-B BRKOUT"}.get(sig) or ("VETO:" + ",".join(vetoed) if vetoed else "-")
        print(f"{sym:<14}{mean:>6.2f}{agree*100:>7.0f}%  {st}")
    return run_id

def fetch_delivery_cache_only():
    out = {}
    files = sorted(f for f in os.listdir(CACHE) if f.startswith("deliv_"))
    for fn in files:
        tag = fn[6:14]
        try:
            day = dt.datetime.strptime(tag, "%d%m%Y").toordinal()
        except Exception:
            continue
        try:
            for line in open(os.path.join(CACHE, fn)).read().splitlines()[1:]:
                c = [x.strip() for x in line.split(",")]
                if len(c) < 15 or c[1] != "EQ":
                    continue
                try:
                    out.setdefault(c[0], []).append((day, float(c[14])))
                except Exception:
                    continue
        except Exception:
            continue
    return {s: [p for _, p in sorted(rows)] for s, rows in out.items()}

def show_votes(symbol):
    con = db_init()
    row = con.execute("SELECT MAX(run_id) FROM runs").fetchone()
    if not row or not row[0]:
        raise SystemExit("[PANEL] No runs yet.")
    rid = row[0]
    res = con.execute("SELECT mean,agreement,vetoed,signal FROM results "
                      "WHERE run_id=? AND symbol=?", (rid, symbol)).fetchone()
    if not res:
        raise SystemExit(f"[PANEL] {symbol} not in run #{rid}.")
    print(f"\n{symbol} — run #{rid} | mean={res[0]:.2f} agree={res[1]*100:.0f}% "
          f"veto={res[2] or '-'} signal={'YES' if res[3] else 'no'}\n")
    fam_scores = {}
    for fam, judge, score in con.execute(
            "SELECT family,judge,score FROM votes WHERE run_id=? AND symbol=? "
            "ORDER BY family,judge", (rid, symbol)):
        fam_scores.setdefault(fam, []).append((judge, score))
    for fam, js in fam_scores.items():
        avg = np.mean([s for _, s in js])
        print(f"  [{fam:<10}] avg {avg:4.1f} | " +
              " ".join(f"{j}={s:.0f}" for j, s in js))
    con.close()

# ---------------------------------------------------------------- self-test
def self_test():
    print(f"[TEST] judges={len(JUDGES)} (expect 105 scoring) vetoes={len(VETOES)} (expect 7)")
    fams = {}
    for fam, name, _ in JUDGES:
        fams[fam] = fams.get(fam, 0) + 1
    for fam, k in sorted(fams.items()):
        print(f"  {fam:<10} {k} judges")
    rng = np.random.default_rng(7)
    hist = {}
    n_days = 300
    for i in range(50):
        drift = rng.normal(0.0008, 0.0015)
        rets = rng.normal(drift, 0.02, n_days)
        c = 100 * np.cumprod(1 + rets)
        h = c * (1 + np.abs(rng.normal(0, 0.008, n_days)))
        l = c * (1 - np.abs(rng.normal(0, 0.008, n_days)))
        o = l + (h - l) * rng.random(n_days)
        v = np.abs(rng.normal(5e5, 2e5, n_days)) + 1e4
        hist[f"FAKE{i:03d}"] = {"o": o, "h": h, "l": l, "c": c, "v": v}
    # one designed winner: uptrend, volume surge, near highs
    c = 100 * np.cumprod(1 + np.abs(np.random.default_rng(1).normal(0.004, 0.004, n_days)))
    hist["WINNER"] = {"o": c * 0.995, "h": c * 1.01, "l": c * 0.99, "c": c,
                      "v": np.linspace(5e5, 2e6, n_days)}
    # one veto case: penny + illiquid
    hist["PENNY"] = {"o": np.full(n_days, 5.0), "h": np.full(n_days, 5.2),
                     "l": np.full(n_days, 4.9), "c": np.full(n_days, 5.0),
                     "v": np.full(n_days, 100.0)}
    hist["__NIFTY__"] = {"c": 20000 * np.cumprod(1 + rng.normal(0.0005, 0.008, n_days))}
    fii_store = {f"{d:02d}-Jun-2026": {"fii": float(rng.normal(500, 2000)),
                                       "dii": float(rng.normal(800, 1500))}
                 for d in range(1, 11)}
    mkt = market_context(hist, fii_store)
    nif = hist.get("__NIFTY__", {}).get("c")
    nifty20 = (nif[-1] / nif[-21] - 1) * 100 if nif is not None and len(nif) >= 21 else 0.0
    regime_ok = nifty20 > REGIME_MIN_NIFTY20
    print(f"[PANEL] NIFTY 20d {nifty20:+.2f}% -> regime {'OK' if regime_ok else 'BLOCKED'}")
    bad = 0
    for sym, d in hist.items():
        if sym == "__NIFTY__":
            continue
        if ETF_PAT.search(sym):
            continue
        f = features(sym, d, mkt)
        f["deliv"] = [45 + float(rng.normal(0, 8)) for _ in range(12)]
        f["bulk"] = {"WINNER": 50000.0}
        vetoed, mean, agree, votes = score_stock(f)
        for jn, (fam, s) in votes.items():
            if not (1.0 <= s <= 10.0):
                print(f"  [FAIL] {sym} judge {jn} out of range: {s}")
                bad += 1
        if sym == "PENNY" and not vetoed:
            print("  [FAIL] PENNY not vetoed"); bad += 1
        if sym == "PENNY" and mean != 0.0:
            print("  [FAIL] veto did not zero the mean"); bad += 1
        if sym == "WINNER":
            print(f"  WINNER  -> mean={mean:.2f} agree={agree*100:.0f}% veto={vetoed}")
        if sym == "PENNY":
            print(f"  PENNY   -> mean={mean:.2f} veto={vetoed}")
    # neutral-5 on garbage data
    f = features("TINY", {"o": np.ones(10), "h": np.ones(10) * 1.01,
                          "l": np.ones(10) * 0.99, "c": np.ones(10),
                          "v": np.ones(10)}, mkt)
    vetoed, mean, agree, votes = score_stock(f)
    neutral = sum(1 for _, (fam, s) in votes.items() if s == 5.0)
    print(f"  TINY(10 bars) -> vetoed={vetoed} neutral_votes={neutral}/{len(votes)}")
    if "insufficient_history" not in vetoed:
        print("  [FAIL] insufficient_history veto missed"); bad += 1
    print(f"[TEST] {'PASS — all judges in range, vetoes firing' if bad == 0 else f'{bad} FAILURES'}")
    return bad

# ---------------------------------------------------------------- main
if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "scan"
    if cmd == "warmup":
        warmup()
    elif cmd == "scan":
        scan()
    elif cmd == "votes":
        if len(sys.argv) < 3:
            raise SystemExit("usage: panel.py votes SYMBOL")
    elif cmd == "test":
        sys.exit(1 if self_test() else 0)
    else:
        raise SystemExit(f"unknown command: {cmd}")
