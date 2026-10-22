#!/usr/bin/env python3
"""flow.py - money-flow engine + BLAST RADAR (paper only, buy side trades).

Every ~3 seconds, for every share on the live feed:
  day change, relative volume vs normal at this time of day, 1-minute volume burst,
  distance to day high, coil (tight range near the high), order-book pressure,
  relative strength vs Nifty, sector flow, fresh news, bulk/block deals,
  and for F&O shares: futures OI change, build-up type, 15-min OI acceleration, futures basis.
These become a 0-100 BLAST score (likely to explode up) and a CRASH score (likely to fall).
"""
import os, json, time, collections, datetime as dt
import numpy as np
import core, getdata, dash
from engine import log, rs

BUILD = {1: "LONG BUILD-UP", 2: "SHORT COVERING", -1: "SHORT BUILD-UP", -2: "LONG UNWINDING", 0: ""}
STAGES = ((85, "ENTRY READY"), (75, "CONFIRMED"), (65, "BUILDING"), (55, "EARLY"), (40, "WATCH"))


def stage_of(score):
    for lo, name in STAGES:
        if score >= lo:
            return name
    return "QUIET"


# ---------------------------------------------------------------- FUTURES
def find_futures(kite, syms, today):
    """underlying -> (token, tradingsymbol, expiry) of the nearest futures contract (rolls over 2 days before expiry)."""
    path = os.path.join(core.BASE, "futmap_%s.json" % today)
    if os.path.exists(path):
        try:
            d = json.load(open(path))
            return {k: tuple(v) for k, v in d.items()}
        except Exception:
            pass
    want, best = set(syms), {}
    for i in getdata.call(kite.instruments, "NFO"):
        if i.get("instrument_type") != "FUT" or i.get("name") not in want:
            continue
        exp = i.get("expiry")
        if isinstance(exp, dt.datetime):
            exp = exp.date()
        if isinstance(exp, str):
            try:
                exp = dt.date.fromisoformat(exp[:10])
            except ValueError:
                continue
        if exp is None or (exp - today).days < 2:
            continue
        cur = best.get(i["name"])
        if cur is None or exp < cur[2]:
            best[i["name"]] = (int(i["instrument_token"]), i["tradingsymbol"], exp)
    try:
        json.dump({k: [v[0], v[1], str(v[2])] for k, v in best.items()}, open(path, "w"))
    except Exception:
        pass
    return best


def oi_baseline(kite, futs, feed, day):
    """Yesterday's closing OI per futures contract. Before 09:15 the live OI *is* yesterday's close;
    after the open we read the previous daily candle (with OI) from Kite. Cached per day."""
    path = os.path.join(core.BASE, "oibase_%s.json" % day)
    if os.path.exists(path):
        try:
            return {k: float(v) for k, v in json.load(open(path)).items()}
        except Exception:
            pass
    base = {}
    now = core.ist_now()
    if now.hour * 100 + now.minute < 915:
        keys = ["NFO:" + v[1] for v in futs.values()]
        rev = {v[1]: k for k, v in futs.items()}
        for i in range(0, len(keys), 150):
            getdata._quote.wait()
            try:
                q = getdata.call(kite.quote, keys[i:i + 150])
            except Exception as ex:
                log("OI baseline quote failed:", ex)
                continue
            for k, v in q.items():
                if v.get("oi"):
                    base[rev[k[4:]]] = float(v["oi"])
    else:
        frm = now - dt.timedelta(days=8)
        for u, (tok, ts, exp) in futs.items():
            getdata._hist.wait()
            try:
                rows = getdata.call(kite.historical_data, tok, frm, now, "day", oi=True)
            except Exception:
                continue
            prev = [r for r in rows if r["date"].date() < now.date() and r.get("oi")]
            if prev:
                base[u] = float(prev[-1]["oi"])
    if base:
        try:
            json.dump(base, open(path, "w"))
        except Exception:
            pass
    return base


# ---------------------------------------------------------------- FLOW
class Flow(object):
    def __init__(self, feed, hist, morning, news, v, fst=None):
        self.feed, self.morning, self.news, self.v, self.fst = feed, morning, news, v, fst
        self.syms = feed.syms
        n = len(self.syms)
        self.prev_close = np.full(n, np.nan)
        self.pdh = np.full(n, np.nan)
        self.exp_cum = np.full((n, core.NB5), np.nan)
        for i, s in enumerate(self.syms):
            a = hist.get(s) if i else None
            if a is None or not len(a["ts"]):
                continue
            m = core.to_matrix(a, min_bars=60)
            if m is None or not len(m["days"]):
                continue
            self.prev_close[i] = m["C"][-1, -1]
            self.pdh[i] = np.nanmax(m["H"][-1])
            V = np.nan_to_num(m["V"][-10:])
            self.exp_cum[i] = np.cumsum(V, axis=1).mean(axis=0)
        smap = morning.sectors if morning else {}
        self.sector = np.array([smap.get(s, "") for s in self.syms], dtype=object)
        self.deal = np.array([np.sign((morning.deals.get(s) or [0])[0]) if morning else 0 for s in self.syms])
        self.is_fo = np.array([bool(feed.fidx_of.get(s) is not None) if hasattr(feed, "fidx_of") else False
                               for s in self.syms])
        self.oi0 = np.full(n, np.nan)
        self.basis0 = np.full(n, np.nan)
        self.oi_snaps = collections.deque()
        self.m = {}
        self.top_prev = []
        self.pnl_curve = []
        self.last_curve_min = None
        log("flow engine: %d shares, %d with futures" % (n - 1, int(self.is_fo.sum())))

    def set_oi_base(self, base):
        for u, oi in base.items():
            i = self.feed.pos.get(u)
            if i is not None and oi > 0:
                self.oi0[i] = oi

    # ------------------------------------------------------------ core numbers
    def update(self):
        f = self.feed
        now = time.time()
        with f.lock:
            ltp, O, H, L, C, V = f.ltp.copy(), f.O.copy(), f.H.copy(), f.L.copy(), f.C.copy(), f.V.copy()
            cum = f.last_cum.copy()
            tbq, tsq = f.tbq.copy(), f.tsq.copy()
            f_ltp = f.f_ltp.copy() if hasattr(f, "f_ltp") else None
            f_oi = f.f_oi.copy() if hasattr(f, "f_oi") else None
        b = int(min(max((now - f.t0) // 300, 0), core.NB5 - 1))
        n = len(ltp)
        with np.errstate(invalid="ignore", divide="ignore"):
            first = np.where(np.isnan(O[:, 0]), np.nan, O[:, 0])
            op = np.where(np.isfinite(first), first, self.prev_close)
            # % vs the previous close, the same basis Kite / TradingView use; the feed's ohlc close is exact,
            # the last 5-min close from history is the fallback, today's open the last resort
            fpc = f.pclose.copy() if hasattr(f, "pclose") else np.full(n, np.nan)
            pc = np.where(np.isfinite(fpc) & (fpc > 0), fpc, self.prev_close)
            pc = np.where(np.isfinite(pc) & (pc > 0), pc, op)
            chg = (ltp / pc - 1) * 100
            chg_o = (ltp / op - 1) * 100
            gap = (op / pc - 1) * 100
            hi = np.fmax(np.nanmax(np.where(np.isnan(H[:, :b + 1]), -np.inf, H[:, :b + 1]), axis=1), ltp)
            lo = np.fmin(np.nanmin(np.where(np.isnan(L[:, :b + 1]), np.inf, L[:, :b + 1]), axis=1), ltp)
            hi[~np.isfinite(hi)] = np.nan
            lo[~np.isfinite(lo)] = np.nan
            dist_hi = (hi - ltp) / ltp * 100
            dist_lo = (ltp - lo) / ltp * 100
            dayrng = (hi - lo) / ltp * 100
            k0 = max(0, b - 2)
            h15 = np.nanmax(np.where(np.isnan(H[:, k0:b + 1]), -np.inf, H[:, k0:b + 1]), axis=1)
            l15 = np.nanmin(np.where(np.isnan(L[:, k0:b + 1]), np.inf, L[:, k0:b + 1]), axis=1)
            h15 = np.fmax(h15, ltp)
            l15 = np.fmin(l15, ltp)
            r15 = (h15 - l15) / ltp * 100
            frac = ((now - f.t0) % 300) / 300.0
            e_prev = self.exp_cum[:, b - 1] if b > 0 else np.zeros(n)
            e_now = e_prev + frac * (self.exp_cum[:, b] - e_prev)
            rvol = np.where((cum > 0) & (e_now > 0), cum / e_now, np.nan)
            vw = np.nansum(np.nan_to_num(C[:, :b + 1]) * np.nan_to_num(V[:, :b + 1]), axis=1) / np.nansum(
                np.nan_to_num(V[:, :b + 1]), axis=1)
            vw = np.where(np.isfinite(vw) & (vw > 0), vw, ltp)
            obi = np.where(tbq + tsq > 0, (tbq - tsq) / (tbq + tsq), np.nan)
            nif = chg[0] if np.isfinite(chg[0]) else 0.0
            rsn = chg - nif
            burst = np.full(n, np.nan)
            if self.fst is not None:
                vol1, _ = self.fst.minute()
                if vol1 is not None:
                    burst = vol1 / self.fst.norm1
            # futures
            oi_chg = np.full(n, np.nan)
            oi15 = np.full(n, np.nan)
            basis = np.full(n, np.nan)
            basis_chg = np.full(n, np.nan)
            oi_add = np.full(n, np.nan)
            if f_oi is not None:
                good = (f_oi > 0) & (self.oi0 > 0)
                oi_chg = np.where(good, (f_oi / self.oi0 - 1) * 100, np.nan)
                oi_add = np.where(good, f_oi - self.oi0, np.nan)
                if not self.oi_snaps or now - self.oi_snaps[-1][0] >= 60:
                    self.oi_snaps.append((now, f_oi.copy()))
                while self.oi_snaps and now - self.oi_snaps[0][0] > 16 * 60:
                    self.oi_snaps.popleft()
                old = self.oi_snaps[0]
                if now - old[0] >= 10 * 60:
                    oi15 = np.where(good & (old[1] > 0), (f_oi - old[1]) / self.oi0 * 100, np.nan)
                basis = np.where((f_ltp > 0) & (ltp > 0), (f_ltp / ltp - 1) * 100, np.nan)
                if now >= f.t0 + 60:
                    setb = np.isnan(self.basis0) & np.isfinite(basis)
                    self.basis0[setb] = basis[setb]
                basis_chg = basis - self.basis0
        bu = np.zeros(n, dtype=int)
        with np.errstate(invalid="ignore"):
            bu[(chg > 0.3) & (oi_chg > 2)] = 1
            bu[(chg > 0.3) & (oi_chg < -2)] = 2
            bu[(chg < -0.3) & (oi_chg > 2)] = -1
            bu[(chg < -0.3) & (oi_chg < -2)] = -2
        valid = np.isfinite(chg)
        valid[0] = False
        # sectors
        sec = {}
        for i in np.nonzero(valid & (self.sector != ""))[0]:
            sec.setdefault(self.sector[i], []).append(i)
        sect = {k: (float(np.nanmean(chg[ix])), len(ix)) for k, ix in sec.items() if len(ix) >= 3}
        order = sorted(sect, key=lambda k: -sect[k][0])
        srank = {k: r + 1 for r, k in enumerate(order)}
        with np.errstate(invalid="ignore"):
            up = int((valid & (chg > 0.25)).sum())
            dn = int((valid & (chg < -0.25)).sum())
        tot = int(valid.sum())
        fl = tot - up - dn
        fo_v = valid & self.is_fo
        with np.errstate(invalid="ignore"):
            fo_up = int((fo_v & (chg > 0.25)).sum())
            fo_dn = int((fo_v & (chg < -0.25)).sum())
        bull_frac = up / float(tot) if tot else 0.5
        self.m = dict(ltp=ltp, chg=chg, gap=gap, hi=hi, lo=lo, dist_hi=dist_hi, dist_lo=dist_lo, dayrng=dayrng,
                      r15=r15, l15=l15, rvol=rvol, burst=burst, vw=vw, obi=obi, rsn=rsn, nif=nif, chg_o=chg_o, pc=pc,
                      oi_chg=oi_chg, oi15=oi15, oi_add=oi_add, basis=basis, basis_chg=basis_chg, bu=bu,
                      valid=valid, sect=sect, srank=srank, nsec=len(order),
                      breadth=(up, dn, fl, tot), fo_breadth=(fo_up, fo_dn, int(fo_v.sum())), bull_frac=bull_frac,
                      C=C, H=H, b=b, op=op, t=now)
        self._score()
        return self.m

    def _score(self):
        m = self.m
        n = len(m["chg"])
        rv, bs, ob, rsn, chg = (np.nan_to_num(m[k], nan=0.0) for k in ("rvol", "burst", "obi", "rsn", "chg"))
        dh, dl = np.nan_to_num(m["dist_hi"], nan=99.0), np.nan_to_num(m["dist_lo"], nan=99.0)
        r15, rng = np.nan_to_num(m["r15"], nan=99.0), np.nan_to_num(m["dayrng"], nan=0.0)
        oi15, bc = np.nan_to_num(m["oi15"], nan=0.0), np.nan_to_num(m["basis_chg"], nan=0.0)
        bu = m["bu"]
        secr = np.array([m["srank"].get(s, 0) for s in self.sector])
        secv = np.array([m["sect"].get(s, (0.0, 0))[0] for s in self.sector])
        nsec = max(m["nsec"], 1)
        coil_up = (dh < 0.7) & (r15 < 0.45 * rng) & (rng > 1.0)
        # accumulation: price going nowhere while volume runs above normal, buyers lead the book, holding VWAP
        vwap_ok = np.isfinite(m["vw"]) & (np.nan_to_num(m["ltp"]) >= np.nan_to_num(m["vw"]) * 0.998)
        rvol = np.nan_to_num(m["rvol"], nan=0.0)
        accum = ((np.abs(np.nan_to_num(m["chg"])) <= 1.5) & (rvol >= 1.5) & (r15 <= 1.2) & (ob >= 0.15) & vwap_ok
                 & ((bu == 1) | ~self.is_fo) & m["valid"])
        m["accum"] = accum
        coil_dn = (dl < 0.7) & (r15 < 0.45 * rng) & (rng > 1.0)
        vol_pts = np.where(rv >= 3, 25, np.where(rv >= 2, 18, np.where(rv >= 1.5, 8, 0)))
        bst_pts = np.where(bs >= 3, 15, np.where(bs >= 2, 8, 0))
        up = vol_pts + bst_pts
        up += np.where(coil_up, 12, 0) + np.where(dh <= 0.3, 8, 0) + np.where(accum, 10, 0)
        up += np.where(ob >= 0.3, 10, np.where(ob <= -0.3, -10, 0))
        up += np.select([bu == 1, bu == 2, bu == -1, bu == -2], [15, 8, -25, -10], 0)
        up += np.where((oi15 >= 3) & (chg > 0), 10, 0) + np.where(bc >= 0.1, 5, 0)
        up += np.where((secr >= 1) & (secr <= 2) & (secv > 0.3), 10, np.where(secv < -0.5, -10, 0))
        up += np.where(rsn >= 1.5, 10, np.where(rsn >= 0.75, 5, 0))
        up += np.where(self.deal > 0, 5, np.where(self.deal < 0, -5, 0))
        bf = m["bull_frac"]
        up += 5 if bf > 0.6 else (-10 if bf < 0.35 else 0)
        up += np.where(chg > 8, -30, np.where(chg > 5, -10, 0)) + np.where(chg < -1, -15, 0)
        # shares without futures can never earn the ~30 OI points: rescale so their ladder reaches 100 too
        up = np.where(self.is_fo, up, up * (100.0 / 70.0))
        dn = vol_pts + bst_pts
        dn += np.where(coil_dn, 12, 0) + np.where(dl <= 0.3, 8, 0)
        dn += np.where(ob <= -0.3, 10, np.where(ob >= 0.3, -10, 0))
        dn += np.select([bu == -1, bu == -2, bu == 1, bu == 2], [15, 8, -25, -10], 0)
        dn += np.where((oi15 >= 3) & (chg < 0), 10, 0) + np.where(bc <= -0.1, 5, 0)
        dn += np.where((secr >= nsec - 1) & (secv < -0.3), 10, np.where(secv > 0.5, -10, 0))
        dn += np.where(rsn <= -1.5, 10, np.where(rsn <= -0.75, 5, 0))
        dn += np.where(self.deal < 0, 5, 0)
        dn += 5 if bf < 0.4 else (-10 if bf > 0.65 else 0)
        dn += np.where(chg < -8, -30, 0) + np.where(chg > 1, -15, 0)
        dn = np.where(self.is_fo, dn, dn * (100.0 / 70.0))
        # news only for shares already scoring
        now = time.time()
        news = np.zeros(n)
        heads = {}
        if self.news is not None:
            for i in np.nonzero(m["valid"] & ((up >= 35) | (dn >= 35)))[0]:
                pts, side, head, age = self.news.for_share(self.syms[i], now)
                if pts and side:
                    news[i] = side * (15 if age is not None and age <= 120 else 8)
                    heads[i] = (side, head, age)
        up = up + np.where(news > 0, news, np.where(news < 0, -30, 0))
        dn = dn + np.where(news < 0, -news, np.where(news > 0, -30, 0))
        valid = m["valid"]
        m["up"] = np.where(valid, np.clip(up, 0, 100), 0).astype(int)
        m["dn"] = np.where(valid, np.clip(dn, 0, 100), 0).astype(int)
        m["coil_up"], m["coil_dn"], m["heads"] = coil_up, coil_dn, heads
        m["secv"], m["secr"] = secv, secr

    def reasons(self, i, side=1):
        m = self.m
        r = []
        rv, bs = m["rvol"][i], m["burst"][i]
        if np.isfinite(rv) and rv >= 1.5:
            r.append("volume %.1fx normal for this time" % rv)
        if np.isfinite(bs) and bs >= 2:
            r.append("last minute %.1fx" % bs)
        b = m["bu"][i]
        if b:
            oc = m["oi_chg"][i]
            r.append("%s (OI %+.1f%%)" % (BUILD[b], oc))
        if np.isfinite(m["oi15"][i]) and abs(m["oi15"][i]) >= 3:
            r.append("OI %+.1f%% in 15 min" % m["oi15"][i])
        if side == 1 and m.get("accum") is not None and m["accum"][i]:
            r.append("accumulating: flat price, volume %.1fx, buyers %.0f%%" % (m["rvol"][i], 50 + 50 * np.nan_to_num(m["obi"][i])))
        if (m["coil_up"][i] if side == 1 else m["coil_dn"][i]):
            r.append("tight range at the day %s" % ("high" if side == 1 else "low"))
        ob = m["obi"][i]
        if np.isfinite(ob) and abs(ob) >= 0.3:
            r.append("%s %.0f%%" % ("buyers" if ob > 0 else "sellers", 50 + abs(ob) * 50))
        if abs(m["rsn"][i]) >= 0.75:
            r.append("%+.1f%% vs Nifty" % m["rsn"][i])
        if self.sector[i] and m["secr"][i] and (m["secr"][i] <= 2 or m["secv"][i] < -0.5):
            r.append("%s %+.1f%%" % (self.sector[i], m["secv"][i]))
        if self.deal[i]:
            r.append("bulk/block %s yesterday" % ("BUY" if self.deal[i] > 0 else "SELL"))
        h = m["heads"].get(i)
        if h:
            r.append("news: " + h[1][:70])
        return r

    def top(self, side=1, k=10, min_score=0):
        m = self.m
        s = m["up"] if side == 1 else m["dn"]
        ix = np.argsort(-s)[:k]
        return [int(i) for i in ix if s[i] > min_score]

    def levels(self, i):
        m = self.m
        p = m["ltp"][i]
        vw, lo, hi, pdh = m["vw"][i], m["lo"][i], m["hi"][i], self.pdh[i]
        s1 = vw if vw < p else lo
        r1 = pdh if (np.isfinite(pdh) and pdh > p * 1.001) else (hi if hi > p * 1.001 else np.nan)
        stop = p * 0.99
        rr = (r1 - p) / (p - stop) if np.isfinite(r1) else np.nan
        return s1, r1, rr

    # ------------------------------------------------------------ radar post
    def radar_text(self):
        m = self.m
        up, dn, fl, tot = m["breadth"]
        L = ["🚀 BLAST RADAR %s — breadth: %d up / %d down / %d flat · Nifty %+.2f%%" % (
            core.ist_now().strftime("%H:%M"), up, dn, fl, m["nif"])]
        L.append("Likely to explode UP:")
        for r, i in enumerate(self.top(1, 8, 39), 1):
            sc = int(m["up"][i])
            h = self.held(i, sc)
            L.append("%d. %s %d/100 %s · %+.1f%% · %s%s" % (r, self.syms[i], sc, stage_of(sc), m["chg"][i],
                                                            ", ".join(self.reasons(i, 1)[:3]),
                                                            (" · held: %s" % h) if h else " · BUY ZONE"))
        L.append("Likely to fall (watch only, no shorts):")
        for r, i in enumerate(self.top(-1, 5, 39), 1):
            L.append("%d. %s %d/100 · %+.1f%% · %s" % (r, self.syms[i], m["dn"][i], m["chg"][i],
                                                       ", ".join(self.reasons(i, -1)[:3])))
        if m["sect"]:
            o = sorted(m["sect"].items(), key=lambda kv: -kv[1][0])
            L.append("Money in: " + ", ".join("%s %+.1f%%" % (k, v[0]) for k, v in o[:3]))
            L.append("Money out: " + ", ".join("%s %+.1f%%" % (k, v[0]) for k, v in o[-3:][::-1]))
        return "\n".join(L)

    def note_changes(self):
        """Tell the FLOW agent feed when the top of the radar changes."""
        top = self.top(1, 3, 59)
        for i in top:
            if i not in self.top_prev:
                dash.event("FLOW", "🚀 %s enters top-3 blast · %d/100 · %s" % (
                    self.syms[i], self.m["up"][i], ", ".join(self.reasons(i, 1)[:2])), "buy")
        self.top_prev = top

    # ------------------------------------------------------------ dashboard state
    def held(self, i, score):
        """Why the desk is not buying this share right now, in one short phrase (None = nothing holds it)."""
        m = self.m
        v = self.v
        if score < v.get("blast_min", 75):
            return "score %d < %d" % (score, v.get("blast_min", 75))
        dh = float(m["dist_hi"][i]) if np.isfinite(m["dist_hi"][i]) else 99.0
        if dh > 0.3:
            return "%.1f%% below the day high" % dh
        chg = float(m["chg"][i]) if np.isfinite(m["chg"][i]) else 0.0
        if chg < 0.5:
            return "day move only %+.1f%%" % chg
        if chg > 8.0:
            return "already +%.1f%% today" % chg
        pdh = self.pdh[i]
        p = float(m["ltp"][i])
        if np.isfinite(pdh) and 0 < (pdh - p) / p * 100 < 0.5:
            return "just under yesterday's high"
        fn = getattr(self, "held_fn", None)
        if fn is not None:
            try:
                r = fn(self.syms[i])
                if r:
                    return r
            except Exception:
                pass
        return None

    def card(self, i, side):
        m = self.m
        s1, r1, rr = self.levels(i)
        fin = lambda x, d=2: (round(float(x), d) if x is not None and np.isfinite(x) else None)
        sc = int(m["up"][i] if side == 1 else m["dn"][i])
        stg = stage_of(sc)
        if side == 1 and m.get("accum") is not None and m["accum"][i] and stg in ("QUIET", "WATCH"):
            stg = "ACCUMULATING"
        c = {"s": self.syms[i], "sec": self.sector[i], "chg": fin(m["chg"][i]), "px": fin(m["ltp"][i]),
             "sc": sc, "bu": BUILD[int(m["bu"][i])], "stage": stg, "bse": getdata.EXCH.get(self.syms[i]) == "BSE",
             "oi": fin(m["oi_chg"][i], 1), "oiadd": fin(m["oi_add"][i], 0), "rv": fin(m["rvol"][i], 1),
             "s1": fin(s1), "r1": fin(r1), "rr": fin(rr, 1), "why": self.reasons(i, side)[:4],
             "fo": bool(self.is_fo[i])}
        if side == 1:
            c["held"] = self.held(i, sc)
        return c

    def sector_buildup(self):
        """Dominant futures build-up per sector, from its F&O members: {sector: (label, n_members_with_futures)}."""
        m = self.m
        out = {}
        bu = m["bu"]
        for sec in set(self.sector):
            if not sec:
                continue
            ix = [i for i, s_ in enumerate(self.sector) if s_ == sec and self.is_fo[i] and bu[i] != 0]
            if not ix:
                continue
            cnt = collections.Counter(int(bu[i]) for i in ix)
            k, n = cnt.most_common(1)[0]
            out[sec] = (BUILD[k], n, len(ix))
        return out

    def state(self, con, day, feed_name, prices):
        m = self.m
        chg = m["chg"]
        valid = m["valid"]
        ix = np.nonzero(valid)[0]
        order = ix[np.argsort(-np.nan_to_num(chg[ix]))]
        pick = list(order[:70]) + list(order[-70:])
        b = m["b"]
        C, op = m["C"], m["op"]
        paths = []
        with np.errstate(invalid="ignore", divide="ignore"):
            for i in pick:
                p = (C[i, :b + 1] / op[i] - 1) * 100
                p = [round(float(x), 2) if np.isfinite(x) else None for x in p] + [round(float(chg[i]), 2)]
                paths.append({"s": self.syms[i], "p": p})
        nifty = [round(float(x), 2) if np.isfinite(x) else None
                 for x in (C[0, :b + 1] / op[0] - 1) * 100] + [round(float(m["nif"]), 2)]
        up_cards = [self.card(int(i), 1) for i in order[:12]]
        dn_cards = [self.card(int(i), -1) for i in order[::-1][:12]]
        blast = [self.card(i, 1) for i in self.top(1, 10, 39)]
        acc_ix = [int(i) for i in np.nonzero(m.get("accum", np.zeros(len(chg), bool)))[0]]
        acc_ix.sort(key=lambda i: -float(np.nan_to_num(m["rvol"][i])))
        accum_cards = [self.card(i, 1) for i in acc_ix[:8]]
        crash = [self.card(i, -1) for i in self.top(-1, 6, 39)]
        sbu = self.sector_buildup()
        sect = sorted(([k, round(v[0], 2), v[1], sbu.get(k, ("", 0, 0))[0]] for k, v in m["sect"].items()), key=lambda x: -x[1])
        # market context: India bias from Nifty + breadth
        br = m["breadth"]
        nif = float(m["nif"]) if np.isfinite(m["nif"]) else 0.0
        tot = max(br[3], 1)
        bias = ("BULLISH" if (nif > 0.3 and br[0] / tot > 0.55) else "BEARISH" if (nif < -0.3 and br[1] / tot > 0.55) else "SIDEWAYS")
        ctxc = {"india": bias, "nifty": round(nif, 2), "bull_pct": round(100.0 * br[0] / tot),
                "vix": getattr(self, "vix", None), "fiidii": getattr(self, "fiidii", None),
                "tape": getattr(self, "tape", "normal"), "min_score": self.v.get("min_score"), "blast_min": self.v.get("blast_min"),
                "size_x": self.v.get("size_x", 1.0)}
        st = base_state(con, day, feed_name, prices, self)
        st.update({"breadth": m["breadth"], "fo_breadth": m["fo_breadth"], "nifty": round(float(m["nif"]), 2),
                   "paths": paths, "nifty_path": nifty, "bar": b, "up": up_cards, "down": dn_cards,
                   "blast": blast, "crash": crash, "sectors": sect, "ctx": ctxc, "accum": accum_cards,
                   "bse": [s_ for s_ in self.syms if getdata.EXCH.get(s_) == "BSE"]})
        return st


def base_state(con, day, feed_name, prices, owner):
    """Trades, P&L, agents, events. Works without the flow engine too (slow mode)."""
    rows = con.execute("select id,sym,label,side,qty,entry_ts,entry,stop,exit,reason,net,status,exit_ts from trades "
                       "where day=? order by id", (day,)).fetchall()
    trades, real, unreal = [], 0.0, 0.0
    for r in rows:
        tid, sym, label, side, qty, ets, entry, stop, ex, reason, net, status, xts = r
        if status == "OPEN":
            p = prices.get(sym)
            u = ((p - entry) * side * qty - core.cost_rs(entry * qty, core.cfg())) if p else None
            unreal += u or 0.0
            trades.append({"s": sym, "k": label, "t": time.strftime("%H:%M", time.gmtime(ets + core.IST_OFF)),
                           "e": round(entry, 2), "st": round(stop, 2), "p": round(p, 2) if p else None,
                           "pl": round(u) if u is not None else None, "open": True, "q": qty})
        else:
            real += net or 0.0
            trades.append({"s": sym, "k": label, "t": time.strftime("%H:%M", time.gmtime(ets + core.IST_OFF)),
                           "e": round(entry, 2), "x": round(ex, 2) if ex else None, "pl": round(net or 0),
                           "r": reason, "open": False, "q": qty,
                           "xt": time.strftime("%H:%M", time.gmtime(xts + core.IST_OFF)) if xts else None})
    total = real + unreal
    hm = core.ist_now().strftime("%H:%M")
    curve = owner.pnl_curve if owner is not None else []
    if owner is not None and owner.last_curve_min != hm:
        owner.last_curve_min = hm
        curve.append([hm, round(total)])
    elif curve:
        curve[-1] = [hm, round(total)]
    used = sum(r[4] * r[6] for r in rows)
    ev, agents = dash.snapshot()
    news = []
    if owner is not None and getattr(owner, "news", None) is not None:
        for ts, title, link in list(owner.news.items)[-25:][::-1]:
            nm = owner.news.named.get(title, [])
            news.append({"t": time.strftime("%H:%M", time.gmtime(ts + core.IST_OFF)), "h": title[:140],
                         "s": nm[:2] if len(nm) <= 2 else []})
    return {"ts": core.ist_now().strftime("%Y-%m-%d %H:%M:%S"), "day": day, "feed": feed_name,
            "pnl": {"real": round(real), "unreal": round(unreal), "total": round(total), "used": round(used),
                    "n": len(rows), "wins": sum(1 for r in rows if r[11] == "CLOSED" and (r[10] or 0) > 0),
                    "losses": sum(1 for r in rows if r[11] == "CLOSED" and (r[10] or 0) <= 0),
                    "open": sum(1 for r in rows if r[11] == "OPEN")},
            "curve": curve[-400:], "trades": trades, "events": ev[-120:], "agents": agents, "news": news}
