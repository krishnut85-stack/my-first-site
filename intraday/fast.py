#!/usr/bin/env python3
"""fast.py - GIR INTRADAY v3 additions (all buy-side, paper only).

  Morning   sectors (NSE index lists), yesterday's bulk/block deals, F&O ban list, today's board meetings
  Sector    live sector strength ranking from our own share prices
  Fast      every few seconds from live ticks: day-high break, pre-breakout, breaking news
  Extras    order-book pressure (total buy vs sell quantity), sector points, deal points, bull-trap check
"""
import os, io, re, csv, json, time, collections, datetime as dt
import numpy as np
import core
from engine import log, rs

SECTOR_FILE = os.path.join(core.BASE, "sectors.json")
SECTOR_URLS = [
    "https://nsearchives.nseindia.com/content/indices/ind_niftytotalmarket_list.csv",
    "https://archives.nseindia.com/content/indices/ind_niftytotalmarket_list.csv",
    "https://www.niftyindices.com/IndexConstituent/ind_niftytotalmarket_list.csv",
    "https://nsearchives.nseindia.com/content/indices/ind_nifty500list.csv",
    "https://archives.nseindia.com/content/indices/ind_nifty500list.csv",
    "https://www.niftyindices.com/IndexConstituent/ind_nifty500list.csv",
    "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv",
    "https://www.niftyindices.com/IndexConstituent/ind_niftymicrocap250_list.csv",
]
DEAL_URLS = ["https://nsearchives.nseindia.com/content/equities/bulk.csv",
             "https://nsearchives.nseindia.com/content/equities/block.csv"]
BAN_URL = "https://nsearchives.nseindia.com/content/fo/fo_secban.csv"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Accept": "*/*", "Accept-Language": "en-US,en;q=0.9"}


def _get(url, session=None, timeout=20):
    import requests
    s = session or requests.Session()
    r = s.get(url, headers=UA, timeout=timeout)
    r.raise_for_status()
    return r.text


# ---------------------------------------------------------------- MORNING DATA
def parse_sector_csv(text):
    out = {}
    rd = csv.DictReader(io.StringIO(text))
    cols = {(k or "").strip().lower(): k for k in (rd.fieldnames or [])}
    ks, ki = cols.get("symbol"), cols.get("industry")
    if not ks or not ki:
        return out
    for row in rd:
        sym, ind = (row.get(ks) or "").strip().upper(), (row.get(ki) or "").strip()
        if sym and ind:
            out[sym] = ind
    return out


def load_sectors(max_age_days=7):
    """sym -> industry. Cached in sectors.json, refreshed weekly. Never raises."""
    cached = {}
    if os.path.exists(SECTOR_FILE):
        try:
            d = json.load(open(SECTOR_FILE))
            cached = d.get("map", {})
            if time.time() - d.get("ts", 0) < max_age_days * 86400 and len(cached) > 300:
                return cached, "cached (%d shares)" % len(cached)
        except Exception:
            pass
    got, ok = {}, 0
    for u in SECTOR_URLS:
        try:
            m = parse_sector_csv(_get(u))
            if m:
                ok += 1
                for k, v in m.items():
                    got.setdefault(k, v)
        except Exception as ex:
            log("sector list failed:", u.split("/")[-1], str(ex)[:80])
    if len(got) > 300:
        try:
            json.dump({"ts": time.time(), "map": got}, open(SECTOR_FILE, "w"))
        except Exception:
            pass
        return got, "downloaded (%d shares from %d lists)" % (len(got), ok)
    if cached:
        return cached, "old cache (%d shares) - download failed" % len(cached)
    return {}, "unavailable - download failed"


def parse_deals(text, kind):
    """-> {sym: [net_qty, [(client, side, qty, price)]]}"""
    out = {}
    rd = csv.DictReader(io.StringIO(text))
    cols = {re.sub(r"[^a-z]", "", (k or "").lower()): k for k in (rd.fieldnames or [])}
    k_sym = cols.get("symbol")
    k_cli = next((cols[c] for c in cols if c.startswith("client")), None)
    k_bs = next((cols[c] for c in cols if c.startswith("buysell")), None)
    k_q = next((cols[c] for c in cols if c.startswith("quantity")), None)
    k_p = next((cols[c] for c in cols if c.startswith("tradeprice") or c.startswith("price")), None)
    if not (k_sym and k_bs and k_q):
        return out
    for row in rd:
        sym = (row.get(k_sym) or "").strip().upper()
        bs = (row.get(k_bs) or "").strip().upper()
        try:
            q = float(str(row.get(k_q) or "0").replace(",", ""))
            p = float(str(row.get(k_p) or "0").replace(",", "")) if k_p else 0.0
        except ValueError:
            continue
        if not sym or bs not in ("BUY", "SELL"):
            continue
        e = out.setdefault(sym, [0.0, []])
        e[0] += q if bs == "BUY" else -q
        e[1].append(((row.get(k_cli) or "?").strip()[:40] if k_cli else "?", bs, q, p, kind))
    return out


def load_deals():
    deals, status = {}, []
    for u in DEAL_URLS:
        kind = "block" if "block" in u else "bulk"
        try:
            d = parse_deals(_get(u), kind)
            status.append("%s %d" % (kind, len(d)))
            for sym, (net, lst) in d.items():
                e = deals.setdefault(sym, [0.0, []])
                e[0] += net
                e[1].extend(lst)
        except Exception as ex:
            status.append("%s failed" % kind)
            log("deals failed:", kind, str(ex)[:80])
    return deals, ", ".join(status)


def parse_ban(text):
    ban = set()
    for line in text.splitlines():
        parts = [x.strip() for x in line.split(",")]
        if len(parts) >= 2 and parts[0].isdigit() and parts[1]:
            ban.add(parts[1].upper())
    return ban


def load_ban():
    try:
        b = parse_ban(_get(BAN_URL))
        return b, "%d shares" % len(b)
    except Exception as ex:
        log("ban list failed:", str(ex)[:80])
        return set(), "unavailable"


def load_board(day):
    """Today's board meetings from NSE's event calendar. NSE often blocks servers; then empty."""
    try:
        import requests
        s = requests.Session()
        s.get("https://www.nseindia.com/", headers=UA, timeout=15)
        r = s.get("https://www.nseindia.com/api/event-calendar", headers=dict(UA, Referer="https://www.nseindia.com/"),
                  timeout=15)
        r.raise_for_status()
        out = {}
        want = dt.datetime.strptime(day, "%Y-%m-%d").strftime("%d-%b-%Y").lower()
        for e in r.json():
            if str(e.get("date", "")).lower() == want and e.get("symbol"):
                out[e["symbol"].upper()] = (e.get("purpose") or e.get("bm_desc") or "board meeting")[:80]
        return out, "%d today" % len(out)
    except Exception as ex:
        log("board meetings failed:", str(ex)[:80])
        return {}, "unavailable (NSE blocks servers)"


def load_fiidii():
    """Previous session's FII and DII net cash-market activity (₹ cr) from NSE. Returns ({'fii':x,'dii':y,'date':d}, status)."""
    try:
        import requests
        s = requests.Session()
        s.get("https://www.nseindia.com/", headers=UA, timeout=15)
        r = s.get("https://www.nseindia.com/api/fiidiiTradeReact", headers=dict(UA, Referer="https://www.nseindia.com/"), timeout=15)
        r.raise_for_status()
        out = {}
        for e in r.json():
            cat = str(e.get("category", "")).upper()
            net = float(str(e.get("netValue", "0")).replace(",", ""))
            if cat.startswith("FII") or cat.startswith("FPI"):
                out["fii"] = round(net)
            elif cat.startswith("DII"):
                out["dii"] = round(net)
            out["date"] = e.get("date", "")
        return out, ("ok" if "fii" in out else "empty")
    except Exception as ex:
        return {}, "failed: %s" % str(ex)[:60]


class Morning(object):
    def __init__(self, day):
        self.sectors, self.s_status = load_sectors()
        self.deals, self.d_status = load_deals()
        self.ban, self.b_status = load_ban()
        self.board, self.m_status = load_board(day)
        self.fiidii, self.f_status = load_fiidii()
        log("morning data: sectors %s · deals %s · ban %s · board %s · FII/DII %s" % (
            self.s_status, self.d_status, self.b_status, self.m_status, self.f_status))

    def status(self):
        return "Sectors: %s · Bulk/block deals: %s · F&O ban: %s · Board meetings: %s" % (
            self.s_status, self.d_status, self.b_status, self.m_status)

    def brief(self, universe):
        L = []
        buys = sorted(((v[0], s, v[1]) for s, v in self.deals.items() if s in universe and v[0] > 0), reverse=True)[:8]
        sells = sorted(((v[0], s, v[1]) for s, v in self.deals.items() if s in universe and v[0] < 0))[:5]
        if buys:
            L.append("Big buyers yesterday (bulk/block deals):")
            for q, s, lst in buys:
                who = ", ".join(sorted(set(x[0] for x in lst if x[1] == "BUY")))[:70]
                L.append("  %s +%s shares — %s" % (s, "{:,.0f}".format(q), who))
        if sells:
            L.append("Big sellers yesterday (avoid):")
            for q, s, lst in sells:
                who = ", ".join(sorted(set(x[0] for x in lst if x[1] == "SELL")))[:70]
                L.append("  %s %s shares — %s" % (s, "{:,.0f}".format(q), who))
        bm = [(s, p) for s, p in self.board.items() if s in universe]
        if bm:
            L.append("Board meetings today (result/news filing likely during market hours):")
            for s, p in bm[:15]:
                L.append("  %s — %s" % (s, p))
        if self.ban:
            L.append("F&O ban today: " + ", ".join(sorted(self.ban))[:300])
        return L


# ---------------------------------------------------------------- SECTOR STRENGTH
def sector_table(F, smap, min_members=3):
    """{industry: (avg day change %, members, rank 1=strongest)} from our own live prices."""
    acc = collections.defaultdict(list)
    for s, f in F.items():
        ind = smap.get(s)
        if ind:
            acc[ind].append(f["day_chg"])
    tab = {k: float(np.mean(v)) for k, v in acc.items() if len(v) >= min_members}
    order = sorted(tab, key=lambda k: -tab[k])
    return {k: (tab[k], len(acc[k]), i + 1) for i, k in enumerate(order)}


def extras(sym, f, news_backed, ctx):
    """Extra points on top of score(): sector, order book, deals, board meeting, bull-trap. Buy side only."""
    pts, why = 0, []
    ind = ctx["smap"].get(sym)
    sec = ctx["sec"].get(ind) if ind else None
    if sec:
        avg, n, rank = sec
        if rank <= 2 and avg > 0.3:
            pts += 10; why.append("sector %s leading (#%d, %+.1f%%)" % (ind, rank, avg))
        elif avg < -0.5:
            pts -= 10; why.append("sector %s falling (%+.1f%%)" % (ind, avg))
    obi = ctx["obi"](sym)
    if obi is not None:
        if obi >= 0.3:
            pts += 8; why.append("buyers outweigh sellers %.0f%%/%.0f%%" % (50 + obi * 50, 50 - obi * 50))
        elif obi <= -0.3:
            pts -= 8; why.append("sellers outweigh buyers")
    d = ctx["deals"].get(sym)
    if d:
        if d[0] > 0:
            pts += 8; why.append("bulk/block BUY yesterday")
        elif d[0] < 0:
            pts -= 8; why.append("bulk/block SELL yesterday")
    if sym in ctx["board"]:
        why.append("board meeting today")
    nc = ctx["nifty_chg"]()
    if news_backed and nc is not None and nc <= -0.8:
        pts -= 15; why.append("bull-trap risk: Nifty %+.1f%% today" % nc)
    if sym in ctx["ban"]:
        why.append("in F&O ban")
    flw = ctx.get("flow")
    if flw is not None and flw.m:
        i = flw.feed.pos.get(sym)
        if i is not None:
            bu = int(flw.m["bu"][i])
            if bu == 1:
                pts += 10; why.append("futures LONG BUILD-UP (OI %+.1f%%)" % flw.m["oi_chg"][i])
            elif bu == 2:
                pts += 5; why.append("futures short covering")
            elif bu == -1:
                pts -= 40; why.append("futures SHORT BUILD-UP - no buy")
            elif bu == -2:
                pts -= 10; why.append("futures long unwinding")
            bf = flw.m["bull_frac"]
            if bf < 0.35:
                pts -= 10; why.append("weak market breadth")
            elif bf > 0.6:
                pts += 5; why.append("strong market breadth")
    return pts, why


# ---------------------------------------------------------------- FAST CHECKS FROM TICKS
class Fast(object):
    """Keeps ~90 s of tick snapshots for 1-minute volume and the 1-minute low."""

    def __init__(self, feed, hist, v):
        self.feed, self.v = feed, v
        self.snaps = collections.deque()
        n = len(feed.syms)
        self.norm1 = np.full(n, np.nan)               # normal 1-minute volume per share
        for i, s in enumerate(feed.syms):
            a = hist.get(s)
            if a is not None and len(a["v"]) >= 75 * 3:
                vv = a["v"][-75 * 10:]
                self.norm1[i] = float(np.mean(vv)) / 5.0
        self.last_t = 0.0

    def sample(self):
        now = time.time()
        if now - self.last_t < 1.0:
            return
        self.last_t = now
        with self.feed.lock:
            self.snaps.append((now, self.feed.last_cum.copy(), self.feed.ltp.copy()))
        while self.snaps and now - self.snaps[0][0] > 95:
            self.snaps.popleft()

    def minute(self):
        """(1-min volume array, 1-min low array) or (None, None) before 60 s of data."""
        if len(self.snaps) < 3:
            return None, None
        now, cum, _ = self.snaps[-1]
        old = next((s for s in self.snaps if now - s[0] <= 65), None)
        if old is None or now - old[0] < 50:
            return None, None
        with np.errstate(invalid="ignore"):
            vol = np.where((cum >= 0) & (old[1] >= 0), cum - old[1], np.nan)
            lows = np.nanmin(np.vstack([s[2] for s in self.snaps if now - s[0] <= 65]), axis=0)
        return vol, lows

    def surge(self):
        """Volume in the last ~20 s as a multiple of a normal 20 s (None before 20 s of data)."""
        if len(self.snaps) < 3:
            return None
        now, cum, _ = self.snaps[-1]
        old = next((s for s in self.snaps if now - s[0] <= 25), None)
        if old is None or now - old[0] < 15:
            return None
        span = now - old[0]
        with np.errstate(invalid="ignore", divide="ignore"):
            vol = np.where((cum >= 0) & (old[1] >= 0), cum - old[1], np.nan)
            return vol / (self.norm1 * span / 60.0)

    def check(self, F, news, ctx, at, score_fn):
        """Return buy candidates that need action now: (score, sym, why, f_live, head, age, kind, stop_px)."""
        v = self.v
        self.sample()
        if not F:
            return []
        now_ist = core.ist_now()
        if now_ist < at(v["trade_from"] // 100, v["trade_from"] % 100) or \
                now_ist > at(v["trade_to"] // 100, v["trade_to"] % 100):
            return []
        vol1, low1 = self.minute()
        r20 = self.surge()
        pre_ok = now_ist >= at(9, 45) and vol1 is not None
        with self.feed.lock:
            ltp = self.feed.ltp.copy()
        out, nowt = [], time.time()
        for s, f in F.items():
            i = self.feed.pos.get(s)
            if i is None or not np.isfinite(ltp[i]):
                continue
            p = float(ltp[i])
            hi = f.get("dayhi")
            if not hi:
                continue
            npts, nside, head, age = news.for_share(s, nowt)
            breaking = bool(npts and nside == 1 and age is not None and age <= 20)
            brk = p > hi * 1.0005
            r1, val1 = 0.0, 0.0
            if vol1 is not None and np.isfinite(vol1[i]) and np.isfinite(self.norm1[i]) and self.norm1[i] > 0:
                r1, val1 = float(vol1[i] / self.norm1[i]), float(vol1[i] * p)
            obi = ctx["obi"](s)
            s20 = float(r20[i]) if (r20 is not None and np.isfinite(r20[i])) else 0.0
            surge = s20 >= v.get("surge_x", 4.0) and r1 >= 1.5          # sudden 20-second burst, already above normal on the minute
            pre = (pre_ok and hi * (1 - v.get("pre_band_pct", 0.3) / 100.0) <= p <= hi and (r1 >= v.get("pre_vol_x", 2.5) or surge)
                   and val1 >= v.get("pre_min_value_lakh", 10) * 1e5 and obi is not None and obi >= 0.2)
            if not (brk or pre or breaking):
                continue
            fl = dict(f)
            fl["px"] = p
            fl["day_chg"] = (p / f["open"] - 1) * 100 if f.get("open") else f["day_chg"]
            fl["above_vwap"], fl["below_vwap"] = p > f["vwap"], p < f["vwap"]
            fl["dayhi_brk"] = brk
            fl["new_hi"] = brk
            fl["brk_up"] = False
            fl["vol"] = max(f["vol"], r1)
            sc, why = score_fn(fl, npts, nside, 1, age)
            if not sc and why and ("too late" in why[0] or "other way" in why[0]):
                continue
            kind = "FAST"
            if pre and not brk:
                sec = ctx["sec"].get(ctx["smap"].get(s))
                if sec and sec[0] < 0:
                    continue                                   # pre-breakout needs the sector rising
                sc += 20
                why.insert(0, "PRE-BREAKOUT: %.2f%% below day high, last minute %.1fx normal volume (%s)%s" % (
                    (hi - p) / hi * 100, r1, ("₹%.1f cr" % (val1 / 1e7)) if val1 >= 1e7 else ("₹%.0f lakh" % (val1 / 1e5)),
                    (", last 20 s %.0fx" % s20) if surge else ""))
                kind = "PRE"
            ep, ew = extras(s, fl, bool(npts and nside == 1), ctx)
            sc = max(0, min(100, sc + ep))
            why += ew
            if sc < v["min_score"]:
                continue
            stop_px = float(low1[i]) if (low1 is not None and np.isfinite(low1[i])) else None
            out.append((sc, s, why, fl, head, age, kind, stop_px))
        out.sort(key=lambda x: -x[0])
        return out
