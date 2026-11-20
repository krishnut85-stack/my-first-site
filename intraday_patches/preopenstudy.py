#!/usr/bin/env python3
"""preopenstudy.py - READ ONLY (changes nothing in GIR, sends nothing, fetches nothing, orders nothing). THE PICK STUDY: WHICH SHARE, WHICH
SIDE, HOW EARLY - over every day in the store that histstore.py made.

WHY (the trader, 20 Nov): "People are making money in option contracts. You have to find the RIGHT MOVE. Based on the sector, based on the
market day, whether it is PE or CE. Don't only check +2%, also check the minus - the shares going down. Everything has to be done."
The move study (onsetstudy.py, movestudy_report.txt) showed: about 34 CE and 37 PE 2%+ moves a day, two thirds of them start AT 09:15 and
90% by 09:45, half of a move is done ~20 min after it starts, and no intraday signal warns before the move. So the warning has to be a LIST
named the evening before (19:45) or at 09:08, or in the first 5 / 15 / 30 minutes - and the intraday trigger is only the ENTRY on that list.
This study measures how well such a list can be named, CE (the share going UP) and PE (the share going DOWN) always side by side:

  1 THE DAYS          what kind of day it was (TREND-UP / TREND-DOWN / REVERSAL / RANGE, and up / down / mixed by NIFTY's close) and how
                      many CE and PE moves of 1.5 / 2 / 3% each kind gave (from the open and from yesterday's close)
  2 THE MARKET READ   a fixed rule, read at 19:45, 09:08, 09:20, 09:30 and 09:45 from data up to that minute only: does the day lean UP,
                      DOWN or NEUTRAL - how often right, how often the WRONG SIDE, and how many CE / PE moves follow each read
  3 THE SECTOR READ   the top 3 sectors for CE and for PE at each level against the day's true top 3 - and how many of the day's moves
                      come from the named sectors
  4 THE SHARE PICK    10 fixed scores (no fitted weights) x 4 gates, 5 / 10 / 15 names per side, picked on the tuning days only and shown
                      UNCHANGED on the held-out last 6 months; every list set against RANDOM shares, RANDOM shares from the same sectors,
                      the VOLATILE shares and the plain TOP-MOVERS list. Measured: how many of the day's real up AND down moves the list
                      catches, how many picks went the WRONG SIDE (a CE pick that fell 2%, a PE pick that rose 2%), the move still left
                      when named, and the minutes before the move is half done
  5 FEATURES          what each evening / open / first-minutes number says about tomorrow's CE and PE moves (descriptive only)
  6 THE ENTRY         six entry triggers on each pick (now, the 5-min range, yesterday's high / low, VWAP + momentum, open-hold,
                      pullback break): the earliest one that does not pick the wrong side more often
  7 ROLE IN SECTOR    LEADER / FOLLOWER / LAGGARD / AGAINST its sector / ALONE - which become the big moves
  8 RINGS             how often the phone would ring for the recommended plan
  0 THE ANSWER        at the top, in plain words, per level and per side, for up / down / mixed days, tuning | held-out
"After option costs" is NEVER the verdict: the option proxy is one secondary line.

  python3 preopenstudy.py check                       what is in the store (as onsetstudy.py check) plus how many valid sectors a day
  python3 preopenstudy.py run                         the whole study, every share, every day in the store
  python3 preopenstudy.py run --years 3               only the last 3 years
  python3 preopenstudy.py run --shares SBIN,TITAN     only these shares and the members of their sectors
  (add --workers n to set the processes; add --force to run during market hours - by default it refuses 09:00-15:35 on a weekday)

It reads only the store, exactly as onsetstudy.py does (it imports it): STORE/min/SYM.npz (minute candles), NIFTY.npz, BANKNIFTY.npz,
fo_daily.json (NSE's daily futures OI) and sectors.json. STORE is /root/hist, or the folder in the GIR_HIST environment variable.
It writes ONLY STORE/preopen_report.txt and STORE/preopen.json. numpy only, runs at nice 10. A few minutes on ~220 shares x 3 years.
Run it after 15:35:   cd /home/globalbot/intraday && python3 preopenstudy.py run --years 3"""
import os, sys, json, time, math, warnings, datetime as dt
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as swv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import onsetstudy as O                                     # the same loading, grid(), F&O filter, ALIAS, split skip, labels, outcomes, boot

T, END, NM = O.T, O.END, O.NM
TT = np.arange(T)
TGT1, TGT2, STOP = O.TGT1, O.TGT2, O.STOP
PREM, DELTA, COSTS = O.PREM, O.DELTA, O.COSTS
TS = (5, 15, 30)                     # the intraday snapshots: candles 0..t-1, read at minute t (09:20 / 09:30 / 09:45)
TLAST = 315                          # a trigger may fire up to 14:30
NPT = (None, 5, 15, 30)              # the naming points: the open (19:45 and 09:08 lists), 09:20, 09:30, 09:45
NPS = (0, 4, 14, 29)                 # the first candle a trigger may fire on, per naming point
REFN = ("o0 (the 09:15 open)", "C[0] (09:16)", "C[4] (09:20)", "C[14] (09:30)", "C[29] (09:45)")
TRN = ("E0 NOW", "E1 ORB5", "E2 PDHL", "E3 VWAP+MOM", "E4 OPEN-HOLD", "E5 PULLBACK")
TRD = ("enter at the naming price", "first close beyond the 09:15-09:19 high (CE) / low (PE), from 09:20",
       "first close beyond yesterday's high (CE) / low (PE)", "above (CE) / below (PE) VWAP and 0.2%+ its way in 3 min",
       "0.3%+ its way from the open, the 09:15 candle's other extreme unbroken, from 09:20",
       "a new day extreme its way after 3+ quiet minutes, 0.3%+ from the open, from 09:20")
TIERS = (1.5, 2.0, 3.0)
NLIST = (5, 10, 15)
MINSEC = 4                           # a sector-day is valid with 4+ listed members
THIN = 20                            # a held-out cell with fewer days is printed "(thin)"
SIDES = ((0, 1, "CE"), (1, -1, "PE"))
LEV = ({"key": "19:45", "name": "19:45 the evening before", "npi": 0, "ref": 0, "nm": 0, "t": None, "sl": 0},
       {"key": "09:08", "name": "09:08 the pre-open (the 09:15 open stands in)", "npi": 0, "ref": 0, "nm": 0, "t": None, "sl": 1},
       {"key": "09:20", "name": "09:20 (first 5 minutes)", "npi": 1, "ref": 2, "nm": 5, "t": 5, "sl": 2},
       {"key": "09:30", "name": "09:30 (first 15 minutes)", "npi": 2, "ref": 3, "nm": 15, "t": 15, "sl": 3},
       {"key": "09:45", "name": "09:45 (first 30 minutes)", "npi": 3, "ref": 4, "nm": 30, "t": 30, "sl": 4})
SDESC = {"S1": "CLOSE-STRENGTH (D-1): close in its range, last hour, last-hour volume, vs sector, sector",
         "S2": "FUTURES BUILD (D-1): build-up, OI change, volume, return",
         "S3": "COIL AT THE EDGE (D-1): NR7 / inside day, ATR contraction, near the 20-day edge, streak, sector",
         "S4": "GAP WITH SECTOR (09:08+): gap / ATR, sector gap, open beyond yesterday's range, build-up",
         "S5": "OWN GAP (09:08+): gap vs sector, gap / ATR, volume",
         "S6": "PREPARED + OPEN AGREES (09:08+): S1, S2 and the gap its way",
         "S7": "SECTOR LEADER (intraday): move, RVOL, vs VWAP, beyond yesterday's range - leaders of a named sector",
         "S8": "LAGGARD CATCH-UP (intraday): RVOL, 5-min momentum, near the edge, build-up - followers / laggards above VWAP",
         "S9": "AGAINST / ALONE (intraday): vs sector, RVOL, vs NIFTY, own gap - moving against or without its sector",
         "S10": "SHARE-ONLY BLEND (intraday): vs NIFTY, RVOL, VWAP, beyond, gap, build-up - no sector gate"}
GDESC = {"G0": "no gate", "G1": "sector in the named top 3", "G2": "market lean sets the list size", "G3": "G1 + G2"}
ROLEN = ("NONE", "LEADER", "FOLLOWER", "LAGGARD", "AGAINST", "ALONE")
TYPEN = ("TREND-UP", "TREND-DOWN", "REVERSAL-UP", "REVERSAL-DOWN", "RANGE")
KINDN = ("up", "down", "mixed")
SIDEDN = ("CE-day", "PE-day", "BOTH")
L2N = ("MIXED", "TREND-UP", "TREND-DOWN", "FADE-UP", "FADE-DOWN")
LEANN = {1: "UP", -1: "DOWN", 0: "NEUTRAL"}
EODK = ("ret1", "cpos1", "lhr1", "lhv1", "rvol1", "nr7", "inside1", "coil", "atrc", "dh5", "dh20", "dh60", "dl5", "dl20", "dl60",
        "oichg1", "r5", "streak", "atr20p", "atr20abs")
LABK = ("ampo", "amppc", "onset", "p25", "p50", "tp", "tb", "bp")
REFK = ("R2", "W2", "WA", "FAV", "ADV")
TRGK = ("em", "R2", "W2", "ml", "h1", "mfe", "r60", "ch")
BSC = {0: {1: 2, 3: 1, 0: 0, 4: -1, 2: -2}, 1: {2: 2, 4: 1, 0: 0, 3: -1, 1: -2}}   # build-up class -> score, CE / PE


def set_store(path):
    """point this study (and onsetstudy) at another store (the tests use it)"""
    O.STORE = path
    O.MIN_DIR = os.path.join(path, "min")


def first_true(M):
    return np.where(M.any(1), M.argmax(1), 999)


def roll(x, k, fn):
    """fn over rows i-k+1 .. i (NaN without k rows)"""
    pad = np.r_[np.full(k - 1, np.nan), np.asarray(x, np.float64)]
    with np.errstate(all="ignore"):
        return fn(swv(pad, k), axis=1)


# ------------------------------------------------------------------ PASS A: one share, every valid share-day ------------------------------------------------------------------
def eod(R, s):
    """features of each row's OWN day, from that day and the days before only (the 19:45 numbers). Shifted by one market day they are
    day D's evening-before features (C1)."""
    day = R["day"]; C, H, L, V = R["C"], R["H"], R["L"], R["V"]
    n = len(day)
    g = np.array([O.GIDX.get(int(x), -1) for x in day], np.int64)
    p1 = np.r_[False, (g[1:] == g[:-1] + 1) & (g[:-1] >= 0)]
    c = C[:, -1]; hi = H.max(1); lo = L.min(1); vol = V.sum(1)
    E = {"g": g}
    with np.errstate(all="ignore"):
        prevc = np.where(p1, np.r_[np.nan, c[:-1]], np.nan)
        E["ret1"] = (c / prevc - 1) * 100
        rg = hi - lo
        E["cpos1"] = np.where(rg > 0, (c - lo) / np.where(rg > 0, rg, 1), 0.5)
        E["lhr1"] = (C[:, 374] / C[:, 314] - 1) * 100
        lhvol = V[:, 315:375].sum(1)
        m_ = O.prior_median(lhvol[:, None])[:, 0].astype(np.float64)
        E["lhv1"] = np.where(m_ > 0, lhvol / m_, np.nan)
        m_ = O.prior_median(vol[:, None])[:, 0].astype(np.float64)
        E["rvol1"] = np.where(m_ > 0, vol / m_, np.nan)
        tr = np.where(np.isfinite(prevc), np.maximum(hi, prevc) - np.minimum(lo, prevc), rg)
        a5 = roll(tr, 5, np.mean); a20 = roll(tr, 20, np.mean)
        E["atrc"] = np.where(a20 > 0, a5 / a20, np.nan)
        E["atr20abs"] = a20
        E["atr20p"] = a20 / c * 100
        mn7 = roll(rg, 7, np.min)
        E["nr7"] = np.where(np.isfinite(mn7), (rg <= mn7 + 1e-12).astype(float), np.nan)
        ph = np.r_[np.nan, hi[:-1]]; pl = np.r_[np.nan, lo[:-1]]
        E["inside1"] = np.where(p1, ((hi <= ph) & (lo >= pl)).astype(float), np.nan)
        E["coil"] = E["nr7"] + np.nan_to_num(E["inside1"])
        for k in (5, 20, 60):
            E["dh%d" % k] = np.where(a20 > 0, (c - roll(hi, k, np.max)) / a20, np.nan)
            E["dl%d" % k] = np.where(a20 > 0, (c - roll(lo, k, np.min)) / a20, np.nan)
        c5 = np.r_[np.full(5, np.nan), c[:-5]] if n > 5 else np.full(n, np.nan)
        E["r5"] = (c / c5 - 1) * 100
    st = np.zeros(n); sg = np.sign(np.nan_to_num(E["ret1"]))
    for i in range(n):
        if sg[i] == 0:
            st[i] = 0
        elif i > 0 and np.sign(st[i - 1]) == sg[i]:
            st[i] = st[i - 1] + sg[i]
        else:
            st[i] = sg[i]
    E["streak"] = st
    fo = O.FOD.get(s) or {}
    oc = np.full(n, np.nan)
    for i, x in enumerate(day):
        ds = str(O.dday(x))
        if ds not in O.FODAYS:
            continue
        r = fo.get(ds)
        if not r:
            continue
        base = float(r[0]) - float(r[1])
        if base > 0:
            oc[i] = float(r[1]) / base * 100
    E["oichg1"] = oc
    return E


def fwd(C, H, L, ref, start, d):
    """an entry at price `ref` (per row) whose first look is minute `start` (per row), side d -> to 15:10:
    R2 = +2% its way before -1% against · W2 = -2% against before +1% its way (THE WRONG SIDE) · WA = -2% against at any time ·
    FAV / ADV = the best / worst excursion (%) · and onsetstudy's 60-min outcomes: h1 (+1% before -0.6%), mfe (best in 60 min), r60.
    A minute that touches both levels counts adverse first."""
    C = C[:, :T]; H = H[:, :T]; L = L[:, :T]; n = C.shape[0]
    ref = np.asarray(ref, np.float64); start = np.asarray(start, np.int64)
    fav, adv = (H, L) if d > 0 else (L, H)
    with np.errstate(all="ignore"):
        fx = (fav / ref[:, None] - 1) * 100 * d
        ax = (adv / ref[:, None] - 1) * 100 * d
    w = TT[None, :] >= start[:, None]
    FAV = np.where(w, fx, -np.inf).max(1); ADV = np.where(w, ax, np.inf).min(1)
    tF2 = first_true(w & (fx >= TGT2)); tF1 = first_true(w & (fx >= TGT1))
    tA1 = first_true(w & (ax <= -1.0)); tA2 = first_true(w & (ax <= -2.0)); tS = first_true(w & (ax <= -STOP))
    R2 = (tF2 < 999) & (tF2 < tA1)
    W2 = (tA2 < 999) & (tA2 <= tF1)
    WA = tA2 < 999
    e60 = start + 59
    mfe = np.where(w & (TT[None, :] <= e60[:, None]), fx, -np.inf).max(1)
    h1 = (tF1 <= e60) & (tF1 < tS)
    s60 = (tS <= e60) & (tS <= tF1)
    with np.errstate(all="ignore"):
        c60 = (C[np.arange(n), np.minimum(e60, END)] / ref - 1) * 100 * d
    r60 = np.where(h1, TGT1, np.where(s60, -STOP, c60))
    bad = ~np.isfinite(ref) | (start > END)
    out = {"R2": R2.astype(float), "W2": W2.astype(float), "WA": WA.astype(float), "FAV": FAV, "ADV": ADV, "h1": h1.astype(float),
           "mfe": mfe, "r60": r60}
    for k in out:
        out[k] = np.where(bad, np.nan, out[k])
    return out


def trig_conds(P, d):
    """E1..E5 as a state per candle close (candle m, data 0..m only), side d; only on tradable candles, up to 14:30"""
    C = P["C"][:, :T]; H = P["H"][:, :T]; L = P["L"][:, :T]; VW = P["VW"][:, :T]; o0 = P["o0"]; nv = C.shape[0]
    tr = (TT[None, :] >= P["first"].astype(np.int64)[:, None]) & (TT <= TLAST)[None, :]
    E = H if d > 0 else L
    with np.errstate(all="ignore"):
        b5 = H[:, :5].max(1) if d > 0 else L[:, :5].min(1)
        c1 = (TT >= 5)[None, :] & ((C - b5[:, None]) * d > 0)
        lvl = P["pdh"] if d > 0 else P["pdl"]
        c2 = (C - lvl[:, None]) * d > 0
        m3 = np.zeros_like(C); m3[:, 3:] = (C[:, 3:] / C[:, :-3] - 1) * 100 * d
        c3 = (TT >= 3)[None, :] & ((C - VW) * d > 0) & (m3 >= 0.2)
        mo = (C / o0[:, None] - 1) * 100 * d
        if d > 0:
            nb = np.minimum.accumulate(L[:, 1:], 1) >= L[:, [0]]
        else:
            nb = np.maximum.accumulate(H[:, 1:], 1) <= H[:, [0]]
        nb = np.c_[np.ones(nv, bool), nb]
        c4 = (TT >= 5)[None, :] & (mo >= 0.3) & nb
        RB = (np.maximum.accumulate if d > 0 else np.minimum.accumulate)(E, axis=1)
        prev = O.sh(RB, 1, np.nan)
        newb = ((E - prev) * d > 0) | (TT == 0)[None, :]
        lastnew = np.maximum.accumulate(np.where(newb, TT, 0), 1)
        age = TT - O.sh(lastnew, 1, 0)
        c5 = (TT >= 5)[None, :] & newb & (age >= 4) & (mo >= 0.3)
    return [x & tr for x in (c1, c2, c3, c4, c5)]


def share_rec(s):
    """pass A for one share -> one record per valid share-day (the days O.prep keeps), keyed by the day index g"""
    R = O.load_rows(s)
    if R is None:
        return {"s": s, "n": 0, "meta": (s, 0, 0.0, [0] * len(O.HNAME), 0, 0, [], 0)}
    P = O.prep(s, R, full=True)
    nv = len(P["g"])
    meta = (s, nv, float(np.median(P["real"])) if nv else 0.0, np.bincount(O.HALF[P["g"]], minlength=len(O.HNAME)).tolist() if nv else
            [0] * len(O.HNAME), P.get("unlisted", 0), P.get("base_n", nv), P.get("splits", []), P.get("split_drop", 0))
    if nv == 0:
        return {"s": s, "n": 0, "meta": meta}
    E = eod(R, s)
    idx = np.searchsorted(E["g"], P["g"]); prv = idx - 1          # every valid day has its previous market day as the row before
    rec = {"s": s, "n": nv, "meta": meta, "g": P["g"].astype(np.int64)}
    for k in EODK:
        rec[k] = E[k][prv].astype(np.float32)
    rec["oi"] = P["oi"].astype(np.float32)                         # D-1's build-up, exactly O.prep's (1 LB 2 SB 3 SC 4 LU 0 none)
    C, H, L, VW, o0, pc = P["C"], P["H"], P["L"], P["VW"], P["o0"], P["pc"]
    for k, v in (("o0", o0), ("pc", pc), ("pdh", P["pdh"]), ("pdl", P["pdl"]), ("c0", C[:, 0]), ("c355", C[:, END])):
        rec[k] = np.asarray(v, np.float32)
    for t in TS:
        rec["C%d" % t] = C[:, t - 1].astype(np.float32); rec["VW%d" % t] = VW[:, t - 1].astype(np.float32)
        rec["RV%d" % t] = P["rc"][:, t - 1].astype(np.float32); rec["C6_%d" % t] = C[:, t - 6].astype(np.float32)
        rec["HM%d" % t] = H[:, :t].max(1).astype(np.float32); rec["LM%d" % t] = L[:, :t].min(1).astype(np.float32)
    lab = np.zeros((2, len(LABK), nv), np.float32)
    ref = np.zeros((2, len(REFK), 5, nv), np.float32)
    trg = np.full((2, 4, 6, len(TRGK), nv), np.nan, np.float32)
    r_ = np.arange(nv)
    refs = [(o0, np.zeros(nv, np.int64)), (C[:, 0], np.ones(nv, np.int64))] + [(C[:, t - 1], np.full(nv, t, np.int64)) for t in TS]
    for si, d in ((0, 1), (1, -1)):
        LB = O.labels(C, H, L, o0, pc, d)
        for j, k in enumerate(LABK):
            lab[si, j] = LB[k]
        RO = []
        for ri, (rp, st) in enumerate(refs):
            o = fwd(C, H, L, rp, st, d); RO.append(o)
            for j, k in enumerate(REFK):
                ref[si, j, ri] = o[k]
        Oc = O.outcomes(C, H, L, d)
        conds = trig_conds(P, d)
        for pi, t in enumerate(NPT):
            ri = 0 if t is None else 2 + TS.index(t)
            o = RO[ri]; refp = refs[ri][0]
            x = trg[si, pi, 0]
            x[0] = 0 if t is None else t
            x[1] = o["R2"]; x[2] = o["W2"]; x[3] = o["FAV"]
            if t is None:                                           # the open itself: onsetstudy's outcomes start at a close
                x[4] = o["h1"]; x[5] = o["mfe"]; x[6] = o["r60"]
            else:
                x[4] = Oc["h1"][:, t - 1]; x[5] = Oc["mfe"][:, t - 1]; x[6] = Oc["r60"][:, t - 1]; x[3] = Oc["ml"][:, t - 1]
            x[7] = 0
            for e in range(1, 6):
                ff = first_true(conds[e - 1] & (TT >= NPS[pi])[None, :])
                has = ff < 999; f = np.minimum(ff, TLAST)
                pf = C[r_, f]
                o2 = fwd(C, H, L, pf, f + 1, d)
                x = trg[si, pi, e]
                x[0] = np.where(has, f + 1, -1)
                x[1] = np.where(has, o2["R2"], 0); x[2] = np.where(has, o2["W2"], 0)
                x[3] = np.where(has, Oc["ml"][r_, f], np.nan); x[4] = np.where(has, Oc["h1"][r_, f], np.nan)
                x[5] = np.where(has, Oc["mfe"][r_, f], np.nan); x[6] = np.where(has, Oc["r60"][r_, f], np.nan)
                with np.errstate(all="ignore"):
                    x[7] = np.where(has, ((pf / refp - 1) * 100 * d >= 1.0).astype(float), np.nan)
    rec["lab"] = lab; rec["ref"] = ref; rec["trg"] = trg
    return rec


# ------------------------------------------------------------------ PASS B: day x share matrices ------------------------------------------------------------------
def prank(X, E):
    """per-day percentile rank in [0, 1] over the eligible cells E; ties get the average rank; an eligible NaN gets 0.5"""
    X = np.asarray(X, np.float64)
    fin = E & np.isfinite(X)
    Y = np.where(fin, X, np.inf)
    n_, m_ = Y.shape
    o = np.argsort(Y, 1, kind="stable")
    Sv = np.take_along_axis(Y, o, 1)
    j = np.broadcast_to(np.arange(m_), (n_, m_))
    new = np.ones((n_, m_), bool); new[:, 1:] = Sv[:, 1:] != Sv[:, :-1]
    st = np.maximum.accumulate(np.where(new, j, 0), 1)
    newr = np.ones((n_, m_), bool); newr[:, :-1] = Sv[:, :-1] != Sv[:, 1:]
    en = np.minimum.accumulate(np.where(newr, j, m_)[:, ::-1], 1)[:, ::-1]
    cnt = fin.sum(1)[:, None]
    r = np.where(cnt > 1, (st + en) / 2.0 / np.maximum(cnt - 1, 1), 0.5)
    out = np.empty((n_, m_)); np.put_along_axis(out, o, r, 1)
    return np.where(fin, out, np.where(E, 0.5, np.nan))


def pick_pair(sc, el, nv, by="score"):
    """top nv[side][day] per side and day; an item in both lists stays on the side with the higher score (by="score") or the better
    rank (by="pos") and the next one fills the other list. -> picks (2, G, X) bool, rank positions (2, G, X)"""
    el = el.copy(); G_, X_ = sc.shape[1:]
    ar = np.broadcast_to(np.arange(X_), (G_, X_))
    P = np.zeros(sc.shape, bool); pos = np.zeros(sc.shape, np.int64)
    for _ in range(X_ + 2):
        P = np.zeros(sc.shape, bool)
        for i in (0, 1):
            Y = np.where(el[i], sc[i], -np.inf)
            o = np.argsort(-Y, 1, kind="stable")
            ps = np.empty((G_, X_), np.int64); np.put_along_axis(ps, o, ar, 1)
            pos[i] = ps; P[i] = el[i] & (ps < nv[i][:, None])
        both = P[0] & P[1]
        if not both.any():
            break
        cw = (np.nan_to_num(sc[0], nan=-9) >= np.nan_to_num(sc[1], nan=-9)) if by == "score" else (pos[0] <= pos[1])
        el[1] &= ~(both & cw); el[0] &= ~(both & ~cw)
    return P, pos


class Ctx:
    pass


def assemble(recs):
    """the day x share matrices (NaN = not a valid share-day)"""
    B = Ctx()
    rr = [r for r in recs if r and r["n"]]
    B.shares = [r["s"] for r in rr]; S = len(rr); G = O.G
    B.S, B.G = S, G
    B.meta = [r["meta"] for r in recs if r and "meta" in r]

    def mat(key, pre=()):
        X = np.full(pre + (G, S), np.nan, np.float32)
        for j, r in enumerate(rr):
            X[..., r["g"], j] = r[key]
        return X
    B.X = {}
    for k in EODK + ("oi", "o0", "pc", "pdh", "pdl", "c0", "c355"):
        B.X[k] = mat(k)
    for t in TS:
        for k in ("C%d", "VW%d", "RV%d", "C6_%d", "HM%d", "LM%d"):
            B.X[k % t] = mat(k % t)
    B.lab = mat("lab", (2, len(LABK)))
    B.ref = mat("ref", (2, len(REFK), 5))
    B.trg = mat("trg", (2, 4, 6, len(TRGK)))
    B.V = np.isfinite(B.X["o0"])
    days = np.zeros(G, bool); days[O.GLO:] = True
    B.days = days & B.V.any(1)
    B.tr = B.days & O.TRAIN; B.te = B.days & ~O.TRAIN
    B.W = np.random.default_rng(7).poisson(1.0, (300, G)).astype(np.float64)
    B.R2 = B.ref[:, 0] == 1; B.W2 = B.ref[:, 1] == 1; B.WA = B.ref[:, 2] == 1     # (2, 5, G, S)
    B.FAV = B.ref[:, 3]; B.ADV = B.ref[:, 4]
    B.A = B.lab[:, 0]; B.APC = B.lab[:, 1]                                          # move from the open / from yesterday's close, its way
    B.univ = B.V.sum(1).astype(np.float64)
    return B


def index_days(B):
    """NIFTY and BANKNIFTY by day (open, closes, high, low) on onsetstudy's calendar"""
    G = O.G

    def load(sym):
        o = np.full(G, np.nan); C = np.full((G, NM), np.nan); h = np.full(G, np.nan); l = np.full(G, np.nan)
        fn = os.path.join(O.MIN_DIR, sym + ".npz")
        if not os.path.exists(fn):
            return None
        for day, o0, Cx, Hx, Lx, Vx, real, first in O.grid(np.load(fn)):
            gi = O.GIDX.get(int(day))
            if gi is None or real < 300:
                continue
            o[gi] = o0; C[gi] = Cx; h[gi] = Hx.max(); l[gi] = Lx.min()
        return {"o": o, "C": C, "h": h, "l": l}
    N = load("NIFTY"); BN = load("BANKNIFTY")
    B.has_bnf = BN is not None
    if BN is None:
        BN = {"o": np.full(G, np.nan), "C": np.full((G, NM), np.nan), "h": np.full(G, np.nan), "l": np.full(G, np.nan)}
    B.N, B.BN = N, BN
    with np.errstate(all="ignore"):
        for D, p in ((N, "n"), (BN, "b")):
            cl = D["C"][:, -1]
            pc = np.r_[np.nan, cl[:-1]]
            D["pc"] = pc; D["cl"] = cl
            D["gap"] = (D["o"] / pc - 1) * 100
            for t in TS:
                D["mpc%d" % t] = (D["C"][:, t - 1] / pc - 1) * 100
                D["mo%d" % t] = (D["C"][:, t - 1] / D["o"] - 1) * 100
        N["ret"] = (N["cl"] / N["pc"] - 1) * 100
        N["cpos"] = np.where(N["h"] > N["l"], (N["cl"] - N["l"]) / (N["h"] - N["l"]), 0.5)
        N["nif1"] = np.r_[np.nan, N["ret"][:-1]]
        N["nifcpos1"] = np.r_[np.nan, N["cpos"][:-1]]
        c5 = np.r_[np.full(6, np.nan), N["cl"][:-6]] if G > 6 else np.full(G, np.nan)
        N["nif5"] = (np.r_[np.nan, N["cl"][:-1]] / c5 - 1) * 100
    # expiry
    ex = np.nonzero(O.EXP)[0]
    dte = np.full(G, np.nan)
    for gi in range(G):
        k = np.searchsorted(ex, gi)
        if k < len(ex):
            dte[gi] = ex[k] - gi
    B.dte = dte; B.expw = (dte <= 4) & (dte >= 0); B.post = np.r_[False, O.EXP[:-1]]


def sectors(B):
    """valid sector-days (4+ listed members), the share -> sector index, the helpers for sector medians / leave-one-out medians"""
    col = {s: j for j, s in enumerate(B.shares)}
    B.secn = sorted(k for k in O.SEC if not k.startswith("_"))
    B.secid = np.full(B.S, -1, np.int64)
    for ki, k in enumerate(B.secn):
        for s in O.SEC[k]:
            if s in col:
                B.secid[col[s]] = ki
    B.K = len(B.secn)
    B.mem = [np.nonzero(B.secid == k)[0] for k in range(B.K)]
    B.cnt = np.stack([B.V[:, m].sum(1) for m in B.mem], 1) if B.K else np.zeros((B.G, 0), int)
    B.VS = B.cnt >= MINSEC
    B.SV = B.V & (B.secid >= 0)[None, :] & (B.VS[:, np.clip(B.secid, 0, None)] if B.K else False)
    B.nvs = B.VS.sum(1)


def sec_med(B, X):
    out = np.full((B.G, B.K), np.nan)
    for k, m in enumerate(B.mem):
        if len(m):
            sub = np.where(B.V[:, m], X[:, m], np.nan)
            with np.errstate(all="ignore"), warnings.catch_warnings():
                warnings.simplefilter("ignore")
                out[:, k] = np.nanmedian(sub, 1)
    return np.where(B.VS, out, np.nan)


def sec_mean(B, X):
    out = np.full((B.G, B.K), np.nan)
    for k, m in enumerate(B.mem):
        if len(m):
            sub = np.where(B.V[:, m] & np.isfinite(X[:, m]), X[:, m], 0.0)
            n = (B.V[:, m] & np.isfinite(X[:, m])).sum(1)
            with np.errstate(all="ignore"):
                out[:, k] = np.where(n > 0, sub.sum(1) / np.maximum(n, 1), np.nan)
    return np.where(B.VS, out, np.nan)


def sec_frac(B, Bo):
    out = np.full((B.G, B.K), np.nan)
    for k, m in enumerate(B.mem):
        if len(m):
            with np.errstate(all="ignore"):
                out[:, k] = (Bo[:, m] & B.V[:, m]).sum(1) / np.maximum(B.cnt[:, k], 1)
    return np.where(B.VS, out, np.nan)


def sec_loo(B, X):
    """for every share in a valid sector: the median of the OTHER members' values (onsetstudy's leave-one-out median)"""
    out = np.full((B.G, B.S), np.nan)
    for k, m in enumerate(B.mem):
        if len(m) < 2:
            continue
        sub = np.where(B.V[:, m], X[:, m], np.nan).T[:, :, None].astype(np.float64)
        kk = np.isfinite(sub[:, :, 0]).sum(0)
        med = O.loo_median(sub, kk)[:, :, 0].T
        ok = B.SV[:, m] & np.isfinite(X[:, m]) & (kk >= 2)[:, None]
        out[:, m] = np.where(ok, med, np.nan)
    return out


def sec_loo_frac(B, Bo):
    out = np.full((B.G, B.S), np.nan)
    for k, m in enumerate(B.mem):
        if len(m) < 2:
            continue
        b = (Bo[:, m] & B.V[:, m]).astype(float)
        tot = b.sum(1, keepdims=True); c = B.cnt[:, [k]]
        with np.errstate(all="ignore"):
            out[:, m] = np.where(B.SV[:, m], (tot - b) / np.maximum(c - 1, 1), np.nan)
    return out


def share_of(B, SK):
    """(G, K) per-sector values -> (G, S) for each share in a valid sector (NaN otherwise)"""
    if B.K == 0:
        return np.full((B.G, B.S), np.nan)
    return np.where(B.SV, SK[:, np.clip(B.secid, 0, None)], np.nan)


def features(B):
    """C1 / C2 / C3 matrices (no look-ahead: C1 from D-1, C2 from the 09:15 open, C3 from candles 0..t-1)"""
    X = B.X; V = B.V
    with np.errstate(all="ignore"):
        okc = np.isfinite(X["oi"]); oii = np.clip(np.where(okc, X["oi"], 0), 0, 4).astype(np.int64)
        X["bscore"] = np.stack([np.where(okc, np.array([BSC[si][k] for k in range(5)], float)[oii], np.nan) for si in (0, 1)])
        X["sec1"] = sec_loo(B, X["ret1"]); X["sbr1"] = sec_loo_frac(B, X["ret1"] > 0)
        X["rs1"] = X["ret1"] - X["sec1"]
        X["rs5"] = X["r5"] - sec_loo(B, X["r5"])
        X["prox20"] = np.stack([X["dh20"], -X["dl20"]])
        X["gap"] = (X["o0"] / X["pc"] - 1) * 100
        X["gapA"] = X["gap"] / X["atr20p"]
        X["secgap"] = sec_loo(B, X["gap"]); X["gaprs"] = X["gap"] - X["secgap"]
        X["gapx"] = np.stack([(X["o0"] > X["pdh"]).astype(float), (X["o0"] < X["pdl"]).astype(float)])
        X["gapx"] = np.where(V[None], X["gapx"], np.nan)
        X["nif1"] = np.broadcast_to(B.N["nif1"][:, None], (B.G, B.S)); X["nifcpos1"] = np.broadcast_to(B.N["nifcpos1"][:, None], (B.G, B.S))
        X["nifgap"] = np.broadcast_to(B.N["gap"][:, None], (B.G, B.S)); X["bnfgap"] = np.broadcast_to(B.BN["gap"][:, None], (B.G, B.S))
        X["dte"] = np.broadcast_to(B.dte[:, None], (B.G, B.S))
        for t in TS:
            C = X["C%d" % t]
            X["mo%d" % t] = (C / X["o0"] - 1) * 100
            X["mpc%d" % t] = (C / X["pc"] - 1) * 100
            X["rv%d" % t] = X["RV%d" % t]
            X["vws%d" % t] = (C - X["VW%d" % t]) / X["atr20abs"]
            X["beyond%d" % t] = np.where(V[None], np.stack([(C > X["pdh"]).astype(float), (C < X["pdl"]).astype(float)]), np.nan)
            X["c5_%d" % t] = (C / X["C6_%d" % t] - 1) * 100
            X["rs_sec%d" % t] = X["mpc%d" % t] - sec_loo(B, X["mpc%d" % t])
            X["rs_nif%d" % t] = X["mpc%d" % t] - B.N["mpc%d" % t][:, None]
    B.roles = {t: roles(B, t) for t in TS}


def roles(B, t):
    """the share's ROLE in its sector at t, per side (0 NONE, 1 LEADER, 2 FOLLOWER, 3 LAGGARD, 4 AGAINST, 5 ALONE). The sector's side is
    the sign of ALL members' median move from yesterday's close if it is 0.3%+, else flat; a share without a valid sector is 'flat'."""
    mpc = B.X["mpc%d" % t]
    med = sec_med(B, mpc)
    ss = np.where(np.abs(med) >= 0.3, np.sign(med), 0.0)
    ssh = np.where(B.SV, ss[:, np.clip(B.secid, 0, None)] if B.K else 0, 0.0)
    mm = share_of(B, med)
    out = np.zeros((2, B.G, B.S), np.int8)
    for si, d in ((0, 1), (1, -1)):
        rk = np.full((B.G, B.S), np.nan)
        for k, m in enumerate(B.mem):
            if len(m):
                rk[:, m] = prank(d * mpc[:, m], B.V[:, m])
        x = d * mpc; md = d * mm
        with np.errstate(all="ignore"):
            lead = (ssh == d) & (rk >= 2.0 / 3 - 1e-9) & (x >= md + 0.3)
            fol = (ssh == d) & ~lead & (x > 0) & (x >= md - 0.3)
            lag = (ssh == d) & (x < md - 0.3) & (x > -0.5)
            aga = (ssh == -d) & (x >= 0.5)
            alo = (ssh == 0) & (x >= 1.0)
        r = np.zeros((B.G, B.S), np.int8)
        r[alo] = 5; r[aga] = 4; r[lag] = 3; r[fol] = 2; r[lead] = 1
        out[si] = np.where(B.V, r, 0)
    return out


# ------------------------------------------------------------------ the market-day read ------------------------------------------------------------------
def market(B):
    """TRUTH (hindsight, to grade only) and the fixed-rule PREDICTION at 19:45 / 09:08 / 09:20 / 09:30 / 09:45"""
    N, BN, G = B.N, B.BN, B.G
    with np.errstate(all="ignore"):
        cc = (N["cl"] / N["pc"] - 1) * 100
        pos = np.where(N["h"] > N["l"], (N["cl"] - N["l"]) / (N["h"] - N["l"]), 0.5)
        e = N["C"][:, 29]
        rup = ((e / N["o"] - 1) * 100 <= -0.3) & ((N["cl"] / e - 1) * 100 >= 0.6)
        rdn = ((e / N["o"] - 1) * 100 >= 0.3) & ((N["cl"] / e - 1) * 100 <= -0.6)
    typ = np.full(G, 4, np.int8)
    for gi in range(G):                                            # assigned in the declared order
        if cc[gi] >= 0.6 and pos[gi] >= 0.7:
            typ[gi] = 0
        elif cc[gi] <= -0.6 and pos[gi] <= 0.3:
            typ[gi] = 1
        elif rup[gi]:
            typ[gi] = 2
        elif rdn[gi]:
            typ[gi] = 3
        else:
            typ[gi] = 4
    B.TYPE = typ; B.KIND = O.NKIND.astype(np.int8); B.ncc = cc
    mv = [((B.A[si] >= 2.0) & B.V).sum(1) for si in (0, 1)]
    B.nmov = {(si, X, f): (((B.A if f == 0 else B.APC)[si] >= X) & B.V).sum(1) for si in (0, 1) for X in TIERS for f in (0, 1)}
    sd = np.full(G, 2, np.int8)
    sd[(mv[0] >= 1.5 * mv[1]) & (mv[0] > 0)] = 0; sd[(mv[1] >= 1.5 * mv[0]) & (mv[1] > 0)] = 1
    B.SIDED = sd
    # L0 at 19:45 (D-1 data only)
    X, V = B.X, B.V
    with np.errstate(all="ignore"):
        nfin = (V & np.isfinite(X["ret1"])).sum(1)
        br1 = ((X["ret1"] > 0) & V).sum(1) / np.maximum(nfin, 1)
        lbsc = (V & np.isin(X["oi"], (1, 3))).sum(1); sblu = (V & np.isin(X["oi"], (2, 4))).sum(1)
        bu = np.where(sblu > 0, lbsc / np.maximum(sblu, 1), np.where(lbsc > 0, np.inf, np.nan))
        n1, ncp, n5 = N["nif1"], N["nifcpos1"], N["nif5"]
        up = (n1 >= 0.5).astype(int) + (ncp >= 0.75) + (br1 >= 0.65) + (bu >= 1.5) + (n5 >= 1.0)
        dn = (n1 <= -0.5).astype(int) + (ncp <= 0.25) + (br1 <= 0.35) + (bu <= 1 / 1.5) + (n5 <= -1.0)
    l0 = np.where(up - dn >= 2, 1, np.where(dn - up >= 2, -1, 0)).astype(np.int8)
    # L1 at 09:08
    with np.errstate(all="ignore"):
        gp = X["gap"]
        gb = (((gp >= 0.3) & V).sum(1) - ((gp <= -0.3) & V).sum(1)) / np.maximum(V.sum(1), 1)
        ng = N["gap"]
    l1 = np.where((ng >= 0.25) & (gb >= 0.3), 1, np.where((ng <= -0.25) & (gb <= -0.3), -1, l0)).astype(np.int8)
    B.lean = [l0, l1]; B.mcls = [l0.copy(), l1.copy()]
    B.mdat = {"br1": br1, "bu": bu, "gb": gb, "up_votes": up, "down_votes": dn}
    for t in TS:
        with np.errstate(all="ignore"):
            brvw = ((X["C%d" % t] > X["VW%d" % t]) & V).sum(1) / np.maximum(V.sum(1), 1)
            nm, no, bm = N["mpc%d" % t], N["mo%d" % t], BN["mpc%d" % t]
            c = np.zeros(G, np.int8)
            tu = (nm >= 0.3) & (no >= 0) & (brvw >= 0.60)
            td = (nm <= -0.3) & (no <= 0) & (brvw <= 0.40)
            fu = (ng <= -0.25) & (no >= 0.25) & (brvw >= 0.55)
            fd = (ng >= 0.25) & (no <= -0.25) & (brvw <= 0.45)
        c[fd] = 4; c[fu] = 3; c[td] = 2; c[tu] = 1
        c[(c == 1) & (bm <= -0.3)] = 0; c[(c == 2) & (bm >= 0.3)] = 0      # BANKNIFTY against NIFTY's trend: MIXED
        B.mcls.append(c)
        B.lean.append(np.select([np.isin(c, (1, 3)), np.isin(c, (2, 4))], [1, -1], 0).astype(np.int8))
        B.mdat["brvw%d" % t] = brvw


def market_measures(B, li, dm):
    """one level's market read on the days dm"""
    sl = LEV[li]["sl"]; ln = B.lean[sl]; cl = B.mcls[sl]
    n = int(dm.sum())
    out = {"days": n}
    if not n:
        return out
    names = L2N if sl >= 2 else ("NEUTRAL", "UP", "DOWN")
    codes = (0, 1, 2, 3, 4) if sl >= 2 else (0, 1, -1)
    conf_t = {}; conf_k = {}
    for nm_, c in zip(names, codes):
        mk = dm & (cl == c)
        conf_t[nm_] = [int((mk & (B.TYPE == k)).sum()) for k in range(5)]
        conf_k[nm_] = [int((mk & (B.KIND == k)).sum()) for k in range(3)]
    out["confusion_type"] = conf_t; out["confusion_kind"] = conf_k
    pu = dm & (ln == 1); pd = dm & (ln == -1); nn = dm & (ln == 0)
    ok = int((pu & (B.SIDED == 0)).sum() + (pd & (B.SIDED == 1)).sum())
    wr = int((pu & (B.SIDED == 1)).sum() + (pd & (B.SIDED == 0)).sum())
    out.update({"pred_up": int(pu.sum()), "pred_down": int(pd.sum()), "neutral": int(nn.sum()), "neutral_pct": nn.sum() / n,
                "side_acc": O.rt(ok, pu.sum() + pd.sum()), "wrong_side_days": wr, "wrong_side_pct_called": O.rt(wr, pu.sum() + pd.sum()),
                "wrong_side_pct_all": wr / n, "up_acc": O.rt((pu & (B.SIDED == 0)).sum(), pu.sum()), "down_acc": O.rt((pd & (B.SIDED == 1)).sum(), pd.sum())})
    mv = {}
    for lab_, mk in (("UP", pu), ("DOWN", pd), ("NEUTRAL", nn)):
        k = int(mk.sum())
        mv[lab_] = {"days": k}
        for X in TIERS:
            mv[lab_]["%s" % X] = (float(B.nmov[(0, X, 0)][mk].mean()) if k else float("nan"), float(B.nmov[(1, X, 0)][mk].mean()) if k else float("nan"))
    out["movers_by_lean"] = mv
    t = LEV[li]["t"]
    with np.errstate(all="ignore"):
        refp = B.N["o"] if t is None else B.N["C"][:, t - 1]
        after = (B.N["C"][:, END] / refp - 1) * 100
    called = dm & (ln != 0)
    out["nifty_after"] = float(np.nanmean((after * ln)[called])) if called.any() else float("nan")
    return out


# ------------------------------------------------------------------ the sector read ------------------------------------------------------------------
def sector_reads(B):
    """the sector score per side at each of the 5 levels (rank-averages over the valid sectors), the named top 3 per side, and the truth"""
    X, V = B.X, B.V
    G, K = B.G, B.K
    B.secsc = []; B.named = []; B.npos = []
    for sl in range(5):
        sc = np.full((2, G, K), np.nan)
        for si, d in ((0, 1), (1, -1)):
            if sl == 0:
                parts = [d * sec_med(B, X["ret1"]), sec_frac(B, d * X["ret1"] > 0), sec_mean(B, X["bscore"][si])]
            elif sl == 1:
                parts = [d * sec_med(B, X["gap"]), sec_frac(B, d * X["gap"] >= 0.3)]
            else:
                t = TS[sl - 2]
                parts = [d * sec_med(B, X["mpc%d" % t]), sec_frac(B, d * (X["C%d" % t] - X["VW%d" % t]) > 0), d * sec_med(B, X["mo%d" % t])]
            if K:
                sc[si] = np.where(B.VS, np.mean([prank(p, B.VS) for p in parts], 0), np.nan)
        if K:
            P, pos = pick_pair(sc, np.stack([B.VS, B.VS]), np.full((2, G), 3), by="pos")
        else:
            P, pos = np.zeros((2, G, 0), bool), np.zeros((2, G, 0), np.int64)
        B.secsc.append(sc); B.named.append(P); B.npos.append(pos)
    B.shnamed = [np.stack([B.SV & (B.named[sl][si][:, np.clip(B.secid, 0, None)] if K else False) for si in (0, 1)]) for sl in range(5)]
    with np.errstate(all="ignore"):
        B.sret = sec_med(B, (X["c355"] / X["o0"] - 1) * 100)
        B.sret_pc = sec_med(B, (X["c355"] / X["pc"] - 1) * 100)
    if K:
        # the truth lists: the 3 best and the 3 worst valid sectors by the median member move from the open
        B.true3 = np.stack([top_k(B.sret, B.VS, 3), top_k(-B.sret, B.VS, 3)])
    else:
        B.true3 = np.zeros((2, G, 0), bool)
    B.secmov = np.stack([np.stack([((B.A[si] >= 2.0) & B.V)[:, m].sum(1) for m in B.mem], 1) if K else np.zeros((G, 0))
                         for si in (0, 1)])


def top_k(sc, el, k):
    Y = np.where(el & np.isfinite(sc), sc, -np.inf)
    o = np.argsort(-Y, 1, kind="stable")
    ps = np.empty(Y.shape, np.int64); np.put_along_axis(ps, o, np.broadcast_to(np.arange(Y.shape[1]), Y.shape), 1)
    return el & np.isfinite(sc) & (ps < k)


def sector_measures(B, sl, si, dm):
    d = 1 if si == 0 else -1
    nm = B.named[sl][si]; pos = B.npos[sl][si]; tr3 = B.true3[si]; opp3 = B.true3[1 - si]
    out = {"days": int(dm.sum())}
    has = dm & (nm.sum(1) > 0)
    if not has.any():
        return out
    n1 = nm & (pos == 0)
    out["hit1"] = float(((n1 & tr3).sum(1) > 0)[has].mean())
    out["overlap"] = float((nm & tr3).sum(1)[has].mean())
    out["random_overlap"] = float((9.0 / np.maximum(B.nvs, 1))[has].mean())
    with np.errstate(all="ignore"):
        wrong = nm & ((opp3 & ~tr3) | (d * B.sret <= -1.0))          # the true bottom 3 without the top 3 (they overlap when K < 6)
    out["wrong_side"] = O.rt(wrong[has].sum(), nm[has].sum())
    mv = (B.A[si] >= 2.0) & B.V
    tot = mv.sum(1).astype(float)
    in_named = (mv & B.shnamed[sl][si]).sum(1)
    in_true = (mv & B.SV & (tr3[:, np.clip(B.secid, 0, None)] if B.K else False)).sum(1)
    in_valid = (mv & B.SV).sum(1)
    nosec = (mv & ~B.SV).sum(1)
    den = tot[has].sum()
    out.update({"moves": int(den), "named_share": O.rt(in_named[has].sum(), den), "true_share": O.rt(in_true[has].sum(), den),
                "random_share": O.rt((3.0 / np.maximum(B.nvs, 1) * in_valid)[has].sum(), den), "nosector_share": O.rt(nosec[has].sum(), den),
                "K_median": float(np.median(B.nvs[has]))})
    return out


# ------------------------------------------------------------------ the scores and the lists ------------------------------------------------------------------
def score(B, name, si, t=None, sl=None):
    """one fixed score for one side -> (score (G, S), eligible (G, S)); cached"""
    key = (name, si, t, sl if name in ("S7", "S8") else None)
    if key in B.sc_cache:
        return B.sc_cache[key]
    X, V = B.X, B.V
    d = 1 if si == 0 else -1
    E = V.copy()
    with np.errstate(all="ignore"):
        if name == "S1":
            parts = [d * (X["cpos1"] - 0.5), d * X["lhr1"], X["lhv1"], d * X["rs1"], d * X["sec1"]]
        elif name == "S2":
            bs = X["bscore"][si]
            parts = [bs, np.where(bs > 0, np.abs(X["oichg1"]), np.where(np.isfinite(bs), 0.0, np.nan)), X["rvol1"], d * X["ret1"]]
        elif name == "S3":
            parts = [X["coil"], -X["atrc"], X["prox20"][si], d * X["streak"], d * X["sec1"]]
        elif name == "S4":
            parts = [d * X["gapA"], d * X["secgap"], X["gapx"][si], X["bscore"][si]]
        elif name == "S5":
            parts = [d * X["gaprs"], d * X["gapA"], X["rvol1"]]; E = V & (d * X["gap"] > 0)
        elif name == "S6":
            s1, e1 = score(B, "S1", si); s2, e2 = score(B, "S2", si)
            E = V & (d * X["gap"] >= 0)
            p3 = prank(d * X["gapA"], E)
            nan = np.isnan(s1).astype(int) + np.isnan(s2) + ~np.isfinite(X["gapA"])
            el = E & (2 * nan <= 3)
            sc = np.where(el, (np.nan_to_num(s1, nan=0.5) + np.nan_to_num(s2, nan=0.5) + p3) / 3.0, np.nan)
            B.sc_cache[key] = (sc, el)
            return sc, el
        elif name == "S7":
            parts = [d * X["mpc%d" % t], X["rv%d" % t], d * X["vws%d" % t], X["beyond%d" % t][si]]
            E = V & B.shnamed[sl][si] & (B.roles[t][si] == 1)
        elif name == "S8":
            parts = [X["rv%d" % t], d * X["c5_%d" % t], X["prox20"][si], X["bscore"][si]]
            E = V & B.shnamed[sl][si] & np.isin(B.roles[t][si], (2, 3)) & (d * X["vws%d" % t] > 0)
        elif name == "S9":
            parts = [d * X["rs_sec%d" % t], X["rv%d" % t], d * X["rs_nif%d" % t], d * X["gaprs"]]
            E = V & np.isin(B.roles[t][si], (4, 5))
        elif name == "S10":
            parts = [d * X["rs_nif%d" % t], X["rv%d" % t], d * X["vws%d" % t], X["beyond%d" % t][si], d * X["gapA"], X["bscore"][si]]
        else:
            raise ValueError(name)
        R = [prank(p, E) for p in parts]
        nan = sum((~np.isfinite(p)).astype(int) for p in parts)
        el = E & (2 * nan <= len(parts))
        sc = np.where(el, np.mean(R, 0), np.nan)
    B.sc_cache[key] = (sc, el)
    return sc, el


def grid_configs():
    out = []
    for li in range(5):
        if li == 0:
            for s in ("S1", "S2", "S3"):
                for g in ("G0", "G1", "G2", "G3"):
                    out.append((li, s, g))
        elif li == 1:
            for s in ("S1", "S2", "S3", "S4", "S5", "S6"):
                for g in ("G0", "G1", "G2", "G3"):
                    out.append((li, s, g))
        else:
            for s in ("S4", "S6", "S10"):
                for g in ("G0", "G1", "G2", "G3"):
                    out.append((li, s, g))
            for s in ("S7", "S8", "S9"):
                for g in ("G0", "G2"):
                    out.append((li, s, g))
    return out


def sizes(B, N, lean):
    """G2: the lean side gets N, the other ceil(N/3); NEUTRAL gives N and N"""
    small = int(math.ceil(N / 3.0))
    return np.stack([np.where(lean == -1, small, N), np.where(lean == 1, small, N)])


def make_list(B, cfg, N):
    """-> picks (2, G, S), the score (2, G, S), the rank positions"""
    key = (cfg, N)
    if key in B.list_cache:
        return B.list_cache[key]
    li, name, gate = cfg
    L = LEV[li]; t = L["t"]; sl = L["sl"]
    tt = t if name in ("S7", "S8", "S9", "S10") else None
    sc = np.stack([score(B, name, si, tt, sl)[0] for si in (0, 1)])
    el = np.stack([score(B, name, si, tt, sl)[1] for si in (0, 1)])
    if gate in ("G1", "G3"):
        el = el & B.shnamed[sl]
    nv = sizes(B, N, B.lean[sl]) if gate in ("G2", "G3") else np.full((2, B.G), N)
    P, pos = pick_pair(sc, el, nv, by="score")
    B.list_cache[key] = (P, sc, pos)
    return P, sc, pos


def bench_list(B, kind, li, N):
    key = (kind, li, N)
    if key in B.list_cache:
        return B.list_cache[key][0]
    X, V = B.X, B.V
    t = LEV[li]["t"]
    f = X["ret1"] if li == 0 else X["gap"] if li == 1 else X["mpc%d" % t]
    nv = np.full((2, B.G), N)
    with np.errstate(all="ignore"):
        if kind == "VOLATILE":
            a = np.nan_to_num(X["atr20p"], nan=-1.0)
            P, _ = pick_pair(np.stack([a, a]), np.stack([V & (f > 0), V & (f < 0)]), nv, by="score")
        else:
            P, _ = pick_pair(np.stack([f, -f]), np.stack([V & np.isfinite(f)] * 2), nv, by="score")
    B.list_cache[key] = (P, None, None)
    return P


# ------------------------------------------------------------------ measures ------------------------------------------------------------------
def day_rate(B, M):
    """per day: the share of the day's universe with M"""
    return (M & B.V).sum(1) / np.maximum(B.univ, 1)


def rates(B):
    """the RANDOM baselines per side, REF and day; the RANDOM-FROM-THE-PICKED-SECTORS rate per share-day"""
    B.rate = {}; B.srate = {}
    for si in (0, 1):
        for r in range(5):
            for k, M in (("R2", B.R2[si, r]), ("W2", B.W2[si, r]), ("WA", B.WA[si, r])):
                B.rate[(k, si, r)] = day_rate(B, M)
            sr = np.full((B.G, B.S), np.nan)
            for k, m in enumerate(B.mem):
                if len(m):
                    rk = (B.R2[si, r][:, m] & B.V[:, m]).sum(1) / np.maximum(B.cnt[:, k], 1)
                    sr[:, m] = rk[:, None]
            B.srate[(si, r)] = np.where(B.SV, sr, B.rate[("R2", si, r)][:, None])
        for X in TIERS:
            for f in (0, 1):
                B.rate[("mv", si, X, f)] = day_rate(B, (B.A if f == 0 else B.APC)[si] >= X)


def quick(B, P1, si, li, dm, r=None):
    """the selection numbers of one list (one side) on the days dm (r = another naming price: the robustness line)"""
    r = LEV[li]["ref"] if r is None else r
    m = P1 & dm[:, None]
    n_d = m.sum(1).astype(float); r2 = (m & B.R2[si, r]).sum(1).astype(float); w2 = (m & B.W2[si, r]).sum(1).astype(float)
    er2 = n_d * B.rate[("R2", si, r)]; ew2 = n_d * B.rate[("W2", si, r)]
    nd = max(int(dm.sum()), 1); n = n_d.sum()
    ci = O.boot(r2 * dm, er2 * dm, B.W)
    return {"days": int(dm.sum()), "picks": int(n), "net2": float((r2 - w2).sum() / nd), "r2": int(r2.sum()), "w2": int(w2.sum()),
            "r2rate": O.rt(r2.sum(), n), "w2rate": O.rt(w2.sum(), n), "w2rand": O.rt(ew2.sum(), n), "lift": O.rt(r2.sum(), er2.sum()),
            "lift_ci": ci, "len": float(n_d[dm].mean()) if dm.any() else 0.0}


def boot2(a, b, c, d, W):
    """95% interval of (sum a / sum b) / (sum c / sum d), resampling whole days"""
    A, Bb, C, D = W @ a, W @ b, W @ c, W @ d
    ok = (Bb > 0) & (C > 0) & (D > 0)
    r = (A[ok] / Bb[ok]) / (C[ok] / D[ok])
    return (float(np.percentile(r, 2.5)), float(np.percentile(r, 97.5))) if len(r) else (float("nan"), float("nan"))


def measure(B, P1, si, li, dm, bench=None):
    """every measure of one list (one side, one level) on the days dm"""
    L = LEV[li]; r = L["ref"]; nm = L["nm"]
    m = P1 & dm[:, None]
    q = quick(B, P1, si, li, dm)
    n = q["picks"]
    out = dict(q)
    if not n:
        return out
    fav = B.FAV[si, r]; adv = B.ADV[si, r]; A = B.A[si]
    rec = {}
    for X in TIERS:
        for f, lab_ in ((0, "open"), (1, "close")):
            mv = ((B.A if f == 0 else B.APC)[si] >= X) & B.V & dm[:, None]
            den = int(mv.sum())
            rec["%s %s" % (X, lab_)] = {"moves": den, "caught": O.rt((mv & m).sum(), den), "live": O.rt((mv & m & (fav >= 1.0)).sum(), den),
                                        "random": O.rt((B.rate[("mv", si, X, f)] * m.sum(1)).sum(), (mv.sum(1)).sum())}
    out["recall"] = rec
    out["prec_label"] = O.rt((m & (A >= 2.0)).sum(), n)
    out["prec_label_random"] = O.rt((B.rate[("mv", si, 2.0, 0)] * m.sum(1)).sum(), n)
    out["prec_live"] = q["r2rate"]
    out["wa_rate"] = O.rt((m & B.WA[si, r]).sum(), n)
    out["wa_rand"] = O.rt((B.rate[("WA", si, r)] * m.sum(1)).sum(), n)
    c = m & (A >= 2.0)
    bp = B.lab[si, 7]
    with np.errstate(all="ignore"):
        frac = fav / bp
    out.update({"left_med": O.q(fav[c], 50), "left_p25": O.q(fav[c], 25), "left_frac_med": O.q(frac[c], 50), "left_frac_p25": O.q(frac[c], 25),
                "fav_mean": float(np.nanmean(fav[m])), "adv_mean": float(np.nanmean(adv[m]))})
    p50 = B.lab[si, 4]; p25 = B.lab[si, 3]
    out["to_p50_med"] = O.q((p50 - nm)[c], 50)
    out["before_p50"] = O.rt((c & (p50 >= nm)).sum(), c.sum()); out["before_p25"] = O.rt((c & (p25 >= nm)).sum(), c.sum())
    n_d = m.sum(1).astype(float); r2 = (m & B.R2[si, r]).sum(1).astype(float)
    er2 = n_d * B.rate[("R2", si, r)]
    es = np.where(m, B.srate[(si, r)], 0.0).sum(1)
    out["lift_sec"] = O.rt(r2.sum(), es.sum()); out["lift_sec_ci"] = O.boot(r2 * dm, es * dm, B.W)
    out["univ_pct"] = float((n_d / np.maximum(B.univ, 1))[dm].mean()) if dm.any() else float("nan")
    if bench:
        for k, PB in bench.items():
            mb = PB & dm[:, None]
            nb = mb.sum(1).astype(float); rb = (mb & B.R2[si, r]).sum(1).astype(float)
            wb = (mb & B.W2[si, r]).sum(1).astype(float)
            out["lift_" + k] = O.rt(r2.sum() / max(n_d.sum(), 1), rb.sum() / max(nb.sum(), 1)) if rb.sum() else float("nan")
            out["lift_%s_ci" % k] = boot2(r2 * dm, n_d * dm, rb * dm, nb * dm, B.W)
            out["net2_" + k] = float((rb - wb).sum() / max(int(dm.sum()), 1))
    return out


def trig_table(B, P1, si, li, dm):
    """the six entry triggers on a list's picks; a pick that never fires is no trade (not caught, never wrong)"""
    L = LEV[li]; pi = L["npi"]; r = L["ref"]
    m = P1 & dm[:, None]; n = int(m.sum())
    rows = []
    for e in range(6):
        Tg = B.trg[si, pi, e]
        em = Tg[0]; fired = m & (em >= 0)
        nf = int(fired.sum())
        rows.append({"trigger": TRN[e], "picks": n, "fired": O.rt(nf, n), "em_med": O.q(em[fired], 50),
                     "r2": O.rt((fired & (Tg[1] == 1)).sum(), n), "w2": O.rt((fired & (Tg[2] == 1)).sum(), n),
                     "ml_med": O.q(Tg[3][fired], 50), "ml_p25": O.q(Tg[3][fired], 25), "hit60": O.rt((fired & (Tg[4] == 1)).sum(), nf),
                     "mfe60": O.q(Tg[5][fired], 50), "chase": O.rt((fired & (Tg[7] == 1)).sum(), nf),
                     "opt15": float(np.nanmean(DELTA * Tg[6][fired] / PREM * 100) - COSTS[0]) if nf else float("nan"),
                     "opt3": float(np.nanmean(DELTA * Tg[6][fired] / PREM * 100) - COSTS[1]) if nf else float("nan")})
    w2rand = O.rt((B.rate[("W2", si, r)] * m.sum(1)).sum(), n)
    return rows, safe_trigger(rows, w2rand), w2rand


def rare_note(rows, safe):
    """the agreed rule counts a pick that never fires as never wrong, so a trigger that seldom fires can pass it: say so"""
    if safe is None or safe == 0 or not np.isfinite(rows[safe]["fired"]) or rows[safe]["fired"] >= 0.5:
        return ""
    return (" - NOTE: it fires on only %s of the picks and keeps RIGHT %s against E0's %s: it is 'safe' mostly because it seldom trades"
            % (pc(rows[safe]["fired"]), pc(rows[safe]["r2"]), pc(rows[0]["r2"])))


def safe_trigger(rows, w2rand):
    """the pre-declared rule: among triggers with WRONG2 <= 0.75 x E0's and a median move left >= 70% of E0's, the earliest median entry;
    else E0 if its WRONG2 <= RANDOM's; else none"""
    e0 = rows[0]
    if not e0["picks"]:
        return None
    ok = [i for i, x in enumerate(rows[1:], 1) if x["fired"] and np.isfinite(x["w2"]) and np.isfinite(x["ml_med"]) and np.isfinite(e0["ml_med"])
          and x["w2"] <= 0.75 * e0["w2"] and x["ml_med"] >= 0.7 * e0["ml_med"]]
    if ok:
        return min(ok, key=lambda i: (rows[i]["em_med"], rows[i]["w2"]))
    if np.isfinite(e0["w2"]) and np.isfinite(w2rand) and e0["w2"] <= w2rand:
        return 0
    return None


def leak_test(B, P1, si, li, dm):
    """the configuration re-run with the day labels shuffled across days within each share (seed 11). The baseline is each picked share's
    own rate over all its days (a shuffle within the share keeps every share's base rate, so a lift here can only come from the code
    reading the labels or a misaligned join - never from which shares the score likes)."""
    r = LEV[li]["ref"]
    key = (si, r)
    if key not in B.shuf:
        rng = np.random.default_rng(11)
        R = B.R2[si, r]; out = np.zeros_like(R)
        own = np.full(B.S, np.nan)
        for j in range(B.S):
            idx = np.nonzero(B.V[:, j])[0]
            if len(idx):
                out[idx, j] = R[rng.permutation(idx), j]
                own[j] = R[idx, j].mean()
        B.shuf[key] = (out, own)
    Rs, own = B.shuf[key]
    m = P1 & dm[:, None]
    num = (m & Rs).sum(1).astype(float); den = np.where(m, own[None, :], 0.0).sum(1)
    return {"lift": O.rt(num.sum(), den.sum()), "ci": O.boot(num * dm, den * dm, B.W)}


# ------------------------------------------------------------------ the whole study ------------------------------------------------------------------
def prepare(args):
    """setup + pass A (fork pool) + pass B -> the context with every matrix, score cache and read"""
    names = O.setup(args.get("years"), args.get("shares"))
    todo = names
    if O.ONLY:
        mates = set(O.ONLY)
        for k, mem in O.SEC.items():
            if set(mem) & O.ONLY and not k.startswith("_"):
                mates |= set(mem)
        todo = [s for s in names if s in mates]
    nw = args.get("workers") or max(1, (os.cpu_count() or 2) - 1)
    t0 = time.time()
    recs = []
    if nw == 1:
        for s in todo:
            recs.append(share_rec(s))
    else:
        import multiprocessing as mp
        with mp.get_context("fork").Pool(nw) as pool:
            for i, r in enumerate(pool.imap_unordered(share_rec, todo, chunksize=2)):
                recs.append(r)
                if args.get("verbose", True) and (i + 1) % 20 == 0:
                    print("  pass A: %d of %d shares · %.0f s" % (i + 1, len(todo), time.time() - t0), flush=True)
    recs.sort(key=lambda r: r["s"])
    B = assemble(recs)
    B.names = names; B.args = args; B.t0 = t0
    index_days(B); sectors(B); features(B); market(B); sector_reads(B); rates(B)
    B.sc_cache = {}; B.list_cache = {}; B.shuf = {}
    return B


def select(B):
    """every configuration on the tuning days; the winner per (level, side, N); held-out unchanged; selection luck; the leak test"""
    tr, te = B.tr, B.te
    B.grid = {}; B.win = {}
    cfgs = grid_configs()
    for N in NLIST:
        for cfg in cfgs:
            P, _, _ = make_list(B, cfg, N)
            for si, d, sd in SIDES:
                B.grid[(cfg, N, si)] = {"tr": quick(B, P[si], si, cfg[0], tr), "te": quick(B, P[si], si, cfg[0], te) if te.any() else None}
    for li in range(5):
        for N in NLIST:
            for si, d, sd in SIDES:
                cs = [c for c in cfgs if c[0] == li]
                rows = [(c, B.grid[(c, N, si)]["tr"]) for c in cs]
                okf = lambda x: (np.isfinite(x["w2rate"]) and np.isfinite(x["w2rand"]) and x["w2rate"] <= x["w2rand"] + 1e-12
                                 and np.isfinite(x["lift_ci"][0]) and x["lift_ci"][0] > 1.0)
                qual = [x for x in rows if okf(x[1])]
                rk = sorted(qual or rows, key=lambda x: (-x[1]["net2"], -x[1]["r2"]))
                best = rk[0][0] if rk else None
                top5 = [c for c, _ in rk[:5]]
                te_net = [B.grid[(c, N, si)]["te"]["net2"] for c in top5 if B.grid[(c, N, si)]["te"]]
                w = {"cfg": best, "qualified": bool(qual), "n_qualified": len(qual), "top5": top5,
                     "luck": {"heldout_no1": B.grid[(best, N, si)]["te"]["net2"] if best and B.grid[(best, N, si)]["te"] else float("nan"),
                              "heldout_top5_median": float(np.median(te_net)) if te_net else float("nan")}}
                if best is not None:
                    P = make_list(B, best, N)[0][si]
                    w["leak"] = leak_test(B, P, si, li, tr)
                    w["leak_bad"] = bool(qual) and not (np.isfinite(w["leak"]["ci"][0]) and w["leak"]["ci"][0] <= 1.0 <= w["leak"]["ci"][1])
                B.win[(li, si, N)] = w


def verdict(B, li, si, N=10):
    w = B.win[(li, si, N)]
    if not w["cfg"]:
        return "NO BETTER THAN RANDOM", {}
    P = make_list(B, w["cfg"], N)[0][si]
    a = B.grid[(w["cfg"], N, si)]["tr"]; b = B.grid[(w["cfg"], N, si)]["te"]
    vol = quick(B, bench_list(B, "VOLATILE", li, N)[si], si, li, B.tr)
    top = quick(B, bench_list(B, "TOP-MOVERS", li, N)[si], si, li, B.tr)
    beats = (w["qualified"] and np.isfinite(a["lift_ci"][0]) and a["lift_ci"][0] > 1.1 and b is not None and np.isfinite(b["lift"])
             and b["lift"] >= 1.1)
    info = {"tr": a, "te": b, "vol_net2": vol["net2"], "top_net2": top["net2"]}
    if not beats:
        return "NO BETTER THAN RANDOM", info
    if a["net2"] <= top["net2"]:
        return "PICKS, BUT NO BETTER THAN THE PLAIN MOVERS LIST", info
    if a["net2"] <= vol["net2"]:
        return "PICKS, BUT NO BETTER THAN THE VOLATILE LIST", info
    return "PICKS", info


# ------------------------------------------------------------------ the report ------------------------------------------------------------------
def pc(x, f="%.0f%%"):
    return "-" if x is None or not np.isfinite(x) else f % (x * 100)


def f1(x, f="%.1f"):
    return "-" if x is None or (isinstance(x, float) and not np.isfinite(x)) else f % x


def cfgname(c):
    return "-" if not c else "%s %s %s" % (LEV[c[0]]["key"], c[1], c[2])


def splits(B):
    """the day splits: KIND, TYPE, and (per level) the predicted lean"""
    out = [("all", np.ones(B.G, bool))]
    out += [("%s days" % KINDN[k], B.KIND == k) for k in range(3)]
    out += [(TYPEN[k], B.TYPE == k) for k in range(5)]
    return out


def thin_cell(B, dm, fn, fmt):
    """tuning | held-out for a day split, held-out printed (thin) under 20 days"""
    a = fn(B.tr & dm); b = fn(B.te & dm) if (B.te & dm).sum() >= THIN else None
    return "%s | %s" % (fmt(a), "(thin)" if b is None else fmt(b))


def mover_ref():
    fn = os.path.join(O.STORE, "movestudy.json")
    if not os.path.exists(fn):
        return None
    try:
        J = json.load(open(fn))
        nd = float(J["meta"]["days"])
        ref = {}
        for X in TIERS:
            for sd in ("CE", "PE"):
                ref[(X, sd, 0)] = J["moves"]["open"]["%s %s all" % (X, sd)]["per_day"]
                ref[(X, sd, 1)] = J["moves"]["pc"]["%s %s" % (X, sd)] / nd
        return ref, J["meta"]["from"], J["meta"]["to"], nd
    except Exception:
        return None


def report(B):
    out = []
    P = lambda *a: out.append(" ".join(str(x) for x in a))
    J = {"meta": {}, "sanity": {}, "answer": {}, "days": {}, "market": {}, "sector": {}, "picks": {}, "grid": {}, "features": {},
         "triggers": {}, "roles": {}, "rings": {}}
    days, tr, te = B.days, B.tr, B.te
    nd = int(days.sum())
    gd = np.nonzero(days)[0]
    d0, d1 = O.dday(O.CAL[gd[0]]), O.dday(O.CAL[gd[-1]])
    nsd = int((B.V & days[:, None]).sum())
    P("=== THE PICK STUDY (preopenstudy.py) · %s -> %s · %d market days (%.1f years) · %d shares · %d valid share-days" % (
        d0, d1, nd, nd / 248.0, B.S, nsd))
    P("    tuning %s -> %s (%d days) · HELD OUT (never used to pick, shown unchanged) %s -> %s (%d days)" % (
        O.dday(O.CAL[tr][0]) if tr.any() else "-", O.dday(O.CAL[tr][-1]) if tr.any() else "-", int(tr.sum()),
        O.dday(O.CAL[te][0]) if te.any() else "-", O.dday(O.CAL[te][-1]) if te.any() else "-", int(te.sum())))
    if B.args.get("shares"):
        P("    ONLY these shares and the members of their sectors: %s" % ", ".join(sorted(B.args["shares"])))
    # sanity: movers per day vs movestudy
    mr = mover_ref()
    cells = []; mism = []
    same = bool(mr) and (str(O.dday(O.CAL[O.GLO])), str(O.dday(O.CAL[-1]))) == (mr[1], mr[2])
    for X in TIERS:
        for f, fl in ((0, "open"), (1, "close")):
            for si, d, sd in SIDES:
                tot = float(B.nmov[(si, X, f)][days].sum())
                v = tot / (mr[3] if same else max(nd, 1))         # movestudy divides by every day from its first one: so does the check
                J["sanity"]["%s %s %s" % (X, sd, fl)] = v
                if mr:
                    ref = mr[0][(X, sd, f)]
                    bad = ref > 0 and abs(v / ref - 1) > 0.03
                    if bad:
                        mism.append("%s%% %s from the %s %.1f vs %.1f" % (X, sd, fl, v, ref))
                    cells.append("%s %s%%/%s %.1f (%.1f)" % (sd, X, fl[0], v, ref))
                else:
                    cells.append("%s %s%%/%s %.1f" % (sd, X, fl[0], v))
    if mr:
        P("    movers a day (this run, movestudy %s -> %s in brackets): %s" % (mr[1], mr[2], " · ".join(cells)))
        if mism:
            P("    !! MISMATCH with movestudy section 1 (over 3%%): %s%s" % ("; ".join(mism), "" if same else
                                                                     " - NOTE: the two runs cover different dates"))
    else:
        P("    movers a day: %s (no movestudy.json in the store to check against)" % " · ".join(cells))
    J["sanity"]["mismatch"] = mism
    vsd = B.nvs[days]
    P("    valid share-days %d (the 3-year server store: ~127k) · valid sectors a day (4+ listed members): median %s, min %s, of %d" % (
        nsd, f1(float(np.median(vsd)) if len(vsd) else float("nan"), "%.0f"), f1(float(vsd.min()) if len(vsd) else float("nan"), "%.0f"), B.K))
    hs = [h for h in range(len(O.HNAME)) if (days & (O.HALF == h)).any()]
    uni = {O.HNAME[h]: float(np.median(B.univ[days & (O.HALF == h)])) for h in hs}
    cov = {O.HNAME[h]: int(sum(1 for m in B.meta if m[3][h] >= 20)) for h in hs}
    P("    the universe (median valid shares a day) per half-year: %s" % " · ".join("%s %.0f" % kv for kv in uni.items()))
    full = list(cov.values())
    mixed = bool(full) and min(full[:-1] or full) < 0.85 * float(np.median(full))
    if mixed:
        P("    !! MIXED STORE: the early half-years have far fewer shares (onsetstudy's warning). Recall at a fixed N is easier on thin days;")
        P("    !! lift against same-day random is not biased by it. Better: run with --years 3 once histstore.py has finished.")
    if not B.has_bnf:
        P("    BANKNIFTY.npz is missing: the market read's BANKNIFTY downgrade never applies")
    spl = [(m[0], m[6]) for m in B.meta if len(m) > 7 and m[6]]
    if spl:
        P("    split / bonus-like jumps left out (that day + 20): %s" % ", ".join("%s %s" % (a, "/".join(b[:2])) for a, b in spl[:12]))
    if O.ALIAS_USED:
        P("    renamed shares read with their old NSE symbol too: %s" % ", ".join(O.ALIAS_USED))
    if O.LOOSE_SEC:
        P("    sectors.json buckets treated as no sector: %s" % ", ".join(O.LOOSE_SEC))
    leak = [(k, w) for k, w in B.win.items() if w.get("leak_bad")]
    nl = sum(1 for w in B.win.values() if w.get("qualified"))
    P("    LEAK TEST (every winning list re-run with the day labels shuffled within each share, seed 11; its lift must hold 1.0): %d winners"
      " tested, %d fail%s" % (nl, len(leak), "" if not leak else " - %s" % ", ".join("%s %s N=%d" % (LEV[k[0]]["key"], SIDES[k[1]][2], k[2])
                                                                                  for k, w in leak[:8])))
    J["meta"] = {"from": str(d0), "to": str(d1), "days": nd, "shares": B.S, "share_days": nsd, "train_days": int(tr.sum()),
                 "heldout_days": int(te.sum()), "valid_sectors_median": float(np.median(vsd)) if len(vsd) else None, "sectors": B.secn,
                 "universe_by_half": uni, "coverage": cov, "mixed_store": mixed, "leak_fail": [list(map(str, k)) for k, _ in leak],
                 "scores": SDESC, "gates": GDESC, "triggers": dict(zip(TRN, TRD))}
    P("READ: CE = the share going UP, PE = the share going DOWN - always side by side, equal weight. RIGHT = +2% its way before -1% against;")
    P("WRONG SIDE = -2% against before +1% its way (a CE pick that fell 2%, a PE pick that rose 2%). Both read from the naming price to 15:10.")
    P("NET2 = (RIGHT - WRONG) a day in the list. LIFT = RIGHT against random shares of the same day and side (95% interval, by day).")
    TOP = len(out)
    SPL = splits(B)

    # ---- 1 THE DAYS
    P("\n=== 1. THE DAYS - what kind of day, and the CE / PE moves it gave (a day on average)")
    J["days"] = {}
    for lab_, mk in [("all", days)] + [(x, days & y) for x, y in SPL[1:]] + [(SIDEDN[k], days & (B.SIDED == k)) for k in range(3)]:
        n = int(mk.sum())
        if not n:
            continue
        cells = []
        row = {"days": n}
        for f, fl in ((0, "from the open"), (1, "from yday close")):
            cc = []
            for X in TIERS:
                ce = float(B.nmov[(0, X, f)][mk].mean()); pe = float(B.nmov[(1, X, f)][mk].mean())
                cc.append("%s%% CE %.1f PE %.1f" % (X, ce, pe)); row["%s %s" % (X, fl)] = (ce, pe)
            cells.append("%s: %s" % (fl, " · ".join(cc)))
        J["days"][lab_] = row
        P("  %-14s %4d days (tuning %d, held out %d) · %s" % (lab_, n, int((mk & tr).sum()), int((mk & te).sum()), " | ".join(cells)))
    P("  (KIND: NIFTY's close vs yesterday +-0.6% · TYPE: TREND = close +-0.6% in the top / bottom 30% of the range; REVERSAL = 0.3% the")
    P("  other way by 09:45 then 0.6% back by the close; RANGE = the rest · CE-day / PE-day = 1.5x more 2% movers on that side)")

    # ---- 2 MARKET READ
    P("\n=== 2. THE MARKET-DAY READ - fixed rules, nothing tuned, data up to the naming minute only · tuning | held-out")
    P("    19:45: five votes (NIFTY D-1 return, close in range, F&O breadth, build-up ratio, NIFTY 5-day); 09:08: NIFTY gap + gap breadth,")
    P("    else the 19:45 lean; 09:20 / 09:30 / 09:45: TREND / FADE / MIXED from NIFTY vs yesterday and the open, breadth above VWAP, BANKNIFTY")
    J["market"] = {}
    for li in range(5):
        a = market_measures(B, li, tr); b = market_measures(B, li, te)
        J["market"][LEV[li]["key"]] = {"tuning": a, "heldout": b}
        if not a.get("days"):
            continue
        P("  %s: side accuracy %s | %s (UP right %s, DOWN right %s) · WRONG-SIDE days %s | %s of the called days · NEUTRAL %s | %s · NIFTY after"
          " the read, its way %s%% | %s%% · always-%s baseline %s" % (
              LEV[li]["name"], pc(a["side_acc"]), pc(b.get("side_acc")) if b.get("days", 0) >= THIN else "(thin)", pc(a["up_acc"]), pc(a["down_acc"]),
              pc(a["wrong_side_pct_called"]), pc(b.get("wrong_side_pct_called")) if b.get("days", 0) >= THIN else "(thin)", pc(a["neutral_pct"]),
              pc(b.get("neutral_pct")) if b.get("days", 0) >= THIN else "(thin)", f1(a["nifty_after"], "%+.2f"), f1(b.get("nifty_after", float("nan")), "%+.2f"),
              *baseline(B)))
        cls_names = list(a["confusion_type"].keys())
        P("      predicted vs TYPE (tuning days)     %s" % " · ".join("%s: %s" % (c, "/".join(str(x) for x in a["confusion_type"][c])) for c in cls_names)
          + "   (TREND-UP/TREND-DOWN/REV-UP/REV-DOWN/RANGE)")
        P("      predicted vs KIND (tuning days)     %s" % " · ".join("%s: %s" % (c, "/".join(str(x) for x in a["confusion_kind"][c])) for c in cls_names)
          + "   (up/down/mixed)")
        P("      THE TRADER'S TABLE - the read says ... expect a day (tuning | held-out): " + " · ".join(
            "%s (%d|%d days) CE %s / PE %s at 2%%, CE %s / PE %s at 3%%" % (
                lab_, a["movers_by_lean"][lab_]["days"], b.get("movers_by_lean", {}).get(lab_, {}).get("days", 0),
                f1(a["movers_by_lean"][lab_]["2.0"][0], "%.0f"), f1(a["movers_by_lean"][lab_]["2.0"][1], "%.0f"),
                f1(a["movers_by_lean"][lab_]["3.0"][0], "%.0f"), f1(a["movers_by_lean"][lab_]["3.0"][1], "%.0f")) for lab_ in ("UP", "DOWN", "NEUTRAL")))

    # ---- 3 SECTOR READ
    P("\n=== 3. THE SECTOR READ - the named top 3 per side vs the day's true top 3 (median member move from the open to 15:10) · tuning | held-out")
    J["sector"] = {}
    for li in range(5):
        sl = LEV[li]["sl"]
        for si, d, sd in SIDES:
            a = sector_measures(B, sl, si, tr); b = sector_measures(B, sl, si, te)
            J["sector"]["%s %s" % (LEV[li]["key"], sd)] = {"tuning": a, "heldout": b,
                                                          "split": {lab_: sector_measures(B, sl, si, tr & mk) for lab_, mk in SPL[1:]}}
            if "hit1" not in a:
                continue
            P("  %-5s %s: No.1 in the true top 3 %s | %s · overlap %s | %s of 3 (random %s) · WRONG-SIDE sectors %s | %s · the day's 2%% %s moves"
              " from the named 3 %s | %s, the true 3 %s, a random 3 %s, no-sector shares %s · K median %s" % (
                  LEV[li]["key"], sd, pc(a["hit1"]), pc(b.get("hit1")), f1(a["overlap"], "%.2f"), f1(b.get("overlap", float("nan")), "%.2f"),
                  f1(a["random_overlap"], "%.2f"), pc(a["wrong_side"]), pc(b.get("wrong_side")), sd, pc(a["named_share"]), pc(b.get("named_share")),
                  pc(a["true_share"]), pc(a["random_share"]), pc(a["nosector_share"]), f1(a["K_median"], "%.0f")))
        sp = J["sector"]["%s CE" % LEV[li]["key"]]["split"]; sq = J["sector"]["%s PE" % LEV[li]["key"]]["split"]
        P("        by day (tuning, named-3 share of moves CE / PE): " + " · ".join(
            "%s %s/%s" % (lab_, pc(sp[lab_].get("named_share")), pc(sq[lab_].get("named_share"))) for lab_, _ in SPL[1:]))

    # ---- 4 SHARE PICK
    P("\n=== 4. THE SHARE PICK - the winner per level x side x N (picked on the tuning days by NET2, WRONG <= random, lift 95% low > 1.0),")
    P("    shown UNCHANGED on the held-out days. Recall = the share of the day's real moves the list caught (live = with 1%+ still left from")
    P("    the naming price). From-close moves at 19:45 / 09:08 include the gap, which the trader cannot buy before 09:15.")
    J["picks"] = {}
    for li in range(5):
        L = LEV[li]
        P("\n  --- %s · naming price %s" % (L["name"], REFN[L["ref"]]))
        for N in NLIST:
            for si, d, sd in SIDES:
                w = B.win[(li, si, N)]
                c = w["cfg"]
                if c is None:
                    continue
                Pk = make_list(B, c, N)[0][si]
                bench = {"VOLATILE": bench_list(B, "VOLATILE", li, N)[si], "TOP-MOVERS": bench_list(B, "TOP-MOVERS", li, N)[si]}
                a = measure(B, Pk, si, li, tr, bench); b = measure(B, Pk, si, li, te, bench) if te.any() else {}
                spl = {lab_: measure(B, Pk, si, li, tr & mk) for lab_, mk in SPL[1:]}
                splh = {lab_: measure(B, Pk, si, li, te & mk) for lab_, mk in SPL[1:]}
                lean = B.lean[L["sl"]]
                spl.update({"lean " + LEANN[v]: measure(B, Pk, si, li, tr & (lean == v)) for v in (1, -1, 0)})
                splh.update({"lean " + LEANN[v]: measure(B, Pk, si, li, te & (lean == v)) for v in (1, -1, 0)})
                vt = {k: measure(B, P_, si, li, tr) for k, P_ in bench.items()}
                J["picks"]["%s %s N=%d" % (L["key"], sd, N)] = {"cfg": cfgname(c), "qualified": w["qualified"], "tuning": a, "heldout": b,
                                                              "split_tuning": spl, "split_heldout": splh, "luck": w["luck"],
                                                              "leak": w.get("leak"), "bench_tuning": vt}
                if N != 10 and not B.args.get("full_report"):
                    P("    %s N=%-2d %-16s%s · recall 2%% %s | %s (live %s) · WRONG %s | %s · NET2 %s | %s a day · lift %s | %s" % (
                        sd, N, "%s %s" % (c[1], c[2]), "" if w["qualified"] else " (no config qualified - best NET2 shown)",
                        pc(a["recall"]["2.0 open"]["caught"]), pc(b.get("recall", {}).get("2.0 open", {}).get("caught")),
                        pc(a["recall"]["2.0 open"]["live"]), pc(a["w2rate"]), pc(b.get("w2rate")), f1(a["net2"], "%+.2f"), f1(b.get("net2", float("nan")), "%+.2f"),
                        f1(a["lift"], "%.2f"), f1(b.get("lift", float("nan")), "%.2f")))
                    continue
                P("    %s N=%d  %s %s (%s; %s)%s · %d configs qualified" % (sd, N, c[1], c[2], SDESC[c[1]].split(":")[0], GDESC[c[2]],
                                                                         "" if w["qualified"] else " - NO configuration qualified, the best NET2 is shown",
                                                                         w["n_qualified"]))
                P("      mean list %s names (%s of the universe) · NET2 %s | %s a day · RIGHT %s | %s · WRONG SIDE %s | %s (random %s) · -2%% any time %s (random %s)" % (
                    f1(a["len"], "%.1f"), pc(a.get("univ_pct"), "%.1f%%"), f1(a["net2"], "%+.2f"), f1(b.get("net2", float("nan")), "%+.2f"),
                    pc(a["r2rate"]), pc(b.get("r2rate")), pc(a["w2rate"]), pc(b.get("w2rate")), pc(a["w2rand"]), pc(a.get("wa_rate")), pc(a.get("wa_rand"))))
                if "recall" in a:
                    P("      recall from the open  " + " · ".join("%s%% %s (live %s, random %s) | %s" % (
                        X, pc(a["recall"]["%s open" % X]["caught"]), pc(a["recall"]["%s open" % X]["live"]), pc(a["recall"]["%s open" % X]["random"]),
                        pc(b.get("recall", {}).get("%s open" % X, {}).get("caught"))) for X in TIERS))
                    P("      recall from yday close" + " · ".join(" %s%% %s | %s" % (
                        X, pc(a["recall"]["%s close" % X]["caught"]), pc(b.get("recall", {}).get("%s close" % X, {}).get("caught"))) for X in TIERS)
                      + ("   (includes the gap)" if li < 2 else ""))
                    P("      precision: a 2%% mover %s (random %s) · RIGHT %s · move left on caught movers median %s%% (p25 %s%%) = %s of base->peak (p25 %s)"
                      " · mean best %s%% / worst %s%% over all picks" % (
                          pc(a["prec_label"]), pc(a["prec_label_random"]), pc(a["prec_live"]), f1(a["left_med"], "%.2f"), f1(a["left_p25"], "%.2f"),
                          pc(a["left_frac_med"]), pc(a["left_frac_p25"]), f1(a["fav_mean"], "%.2f"), f1(a["adv_mean"], "%.2f")))
                    P("      named %s min before the move is half done (median)%s · named before half-way %s, before a quarter %s" % (
                        f1(a["to_p50_med"], "%.0f"), " + the night / 7 min" if li < 2 else "", pc(a["before_p50"]), pc(a["before_p25"])))
                    P("      LIFT vs random %s (95%% %s-%s) | %s · vs random from the picked sectors %s (%s-%s) · vs VOLATILE %s (%s-%s) · vs TOP-MOVERS %s (%s-%s)" % (
                        f1(a["lift"], "%.2f"), f1(a["lift_ci"][0], "%.2f"), f1(a["lift_ci"][1], "%.2f"), f1(b.get("lift", float("nan")), "%.2f"),
                        f1(a["lift_sec"], "%.2f"), f1(a["lift_sec_ci"][0], "%.2f"), f1(a["lift_sec_ci"][1], "%.2f"),
                        f1(a.get("lift_VOLATILE", float("nan")), "%.2f"), f1(a["lift_VOLATILE_ci"][0], "%.2f"), f1(a["lift_VOLATILE_ci"][1], "%.2f"),
                        f1(a.get("lift_TOP-MOVERS", float("nan")), "%.2f"), f1(a["lift_TOP-MOVERS_ci"][0], "%.2f"), f1(a["lift_TOP-MOVERS_ci"][1], "%.2f")))
                    P("      benchmarks (tuning) NET2: VOLATILE %s · TOP-MOVERS %s · recall 2%%: VOLATILE %s · TOP-MOVERS %s · WRONG: VOLATILE %s · TOP-MOVERS %s" % (
                        f1(vt["VOLATILE"]["net2"], "%+.2f"), f1(vt["TOP-MOVERS"]["net2"], "%+.2f"),
                        pc(vt["VOLATILE"].get("recall", {}).get("2.0 open", {}).get("caught")), pc(vt["TOP-MOVERS"].get("recall", {}).get("2.0 open", {}).get("caught")),
                        pc(vt["VOLATILE"]["w2rate"]), pc(vt["TOP-MOVERS"]["w2rate"])))
                    if li < 2:
                        ra = quick(B, Pk, si, li, tr, r=1); rb = quick(B, Pk, si, li, te, r=1) if te.any() else {}
                        J["picks"]["%s %s N=%d" % (L["key"], sd, N)]["robust_c0"] = {"tuning": ra, "heldout": rb}
                        P("      ROBUSTNESS from the 09:16 price C[0] (the 09:15 print is hard to get): NET2 %s | %s · RIGHT %s · WRONG %s (random %s) · lift %s (95%% %s-%s) | %s" % (
                            f1(ra["net2"], "%+.2f"), f1(rb.get("net2", float("nan")), "%+.2f"), pc(ra["r2rate"]), pc(ra["w2rate"]), pc(ra["w2rand"]),
                            f1(ra["lift"], "%.2f"), f1(ra["lift_ci"][0], "%.2f"), f1(ra["lift_ci"][1], "%.2f"), f1(rb.get("lift", float("nan")), "%.2f")))
                    P("      SELECTION LUCK: held-out NET2 of the tuning No.1 %s vs the median of the tuning top 5 %s · leak test lift %s (95%% %s-%s)" % (
                        f1(w["luck"]["heldout_no1"], "%+.2f"), f1(w["luck"]["heldout_top5_median"], "%+.2f"), f1(w["leak"]["lift"], "%.2f"),
                        f1(w["leak"]["ci"][0], "%.2f"), f1(w["leak"]["ci"][1], "%.2f")))
                    P("      by day, recall 2% / WRONG / NET2 (tuning | held-out): " + " · ".join(
                        "%s %s/%s/%s | %s" % (lab_, pc(spl[lab_].get("recall", {}).get("2.0 open", {}).get("caught")), pc(spl[lab_].get("w2rate")),
                                              f1(spl[lab_].get("net2", float("nan")), "%+.1f"),
                                              "(thin)" if splh[lab_].get("days", 0) < THIN else pc(splh[lab_].get("recall", {}).get("2.0 open", {}).get("caught")))
                        for lab_ in list(spl.keys())))
    # the full grid in the json
    for (cfg, N, si), v in B.grid.items():
        J["grid"]["%s %s N=%d" % (cfgname(cfg), SIDES[si][2], N)] = v

    # ---- 5 FEATURES
    P("\n=== 5. FEATURE TABLE (tuning days, descriptive only - never used to pick): by quintile, P(2% CE move) / P(2% PE move) from the open,")
    P("    median best move CE / PE from the naming price, WRONG-SIDE rate CE / PE")
    J["features"] = feature_tables(B, P)

    # ---- 6 TRIGGERS
    P("\n=== 6. THE ENTRY TRIGGER on each winning list's picks (N=10; tuning days) - a pick that never fires is no trade: not caught, never wrong")
    P("    EARLIEST SAFE = among triggers with WRONG <= 0.75 x E0's and a median move left >= 70% of E0's, the earliest median entry;")
    P("    else E0 if its WRONG <= random; else no safe trigger. " + " · ".join("%s = %s" % (a, b) for a, b in zip(TRN, TRD)))
    B.safe = {}
    for li in range(5):
        for si, d, sd in SIDES:
            w = B.win[(li, si, 10)]
            if not w["cfg"]:
                continue
            Pk = make_list(B, w["cfg"], 10)[0][si]
            rows, safe, w2r = trig_table(B, Pk, si, li, tr)
            rh, sh_, _ = trig_table(B, Pk, si, li, te) if te.any() else (None, None, None)
            B.safe[(li, si)] = safe
            J["triggers"]["%s %s" % (LEV[li]["key"], sd)] = {"tuning": rows, "heldout": rh, "safe": TRN[safe] if safe is not None else None,
                                                            "random_w2": w2r}
            P("  %s %s (%s): EARLIEST SAFE %s%s" % (LEV[li]["key"], sd, cfgname(w["cfg"]), "%s, median entry %s" % (
                TRN[safe], O.hm(rows[safe]["em_med"]) if np.isfinite(rows[safe]["em_med"]) else "-") if safe is not None else "NO SAFE TRIGGER",
                rare_note(rows, safe)))
            for x in rows:
                P("      %-14s fired %4s · entry %s · RIGHT %4s · WRONG %4s · left median %s%% (p25 %s%%) · HIT60 %4s · MFE60 %s%% · CHASE %4s" % (
                    x["trigger"], pc(x["fired"]), O.hm(x["em_med"]) if np.isfinite(x["em_med"]) else "  -  ", pc(x["r2"]), pc(x["w2"]),
                    f1(x["ml_med"], "%.2f"), f1(x["ml_p25"], "%.2f"), pc(x["hit60"]), f1(x["mfe60"], "%.2f"), pc(x["chase"])))

    # ---- 7 ROLES
    P("\n=== 7. ROLE IN THE SECTOR at 09:20 / 09:30 / 09:45 (tuning days): share-days, become a 2% mover its way, RIGHT, WRONG, move left")
    J["roles"] = {}
    for t, ri in zip(TS, (2, 3, 4)):
        for si, d, sd in SIDES:
            cells = []
            for rc_, rn in enumerate(ROLEN):
                mk = (B.roles[t][si] == rc_) & B.V & tr[:, None]
                n = int(mk.sum())
                row = {"n": n, "mover2": O.rt((mk & (B.A[si] >= 2)).sum(), n), "right": O.rt((mk & B.R2[si, ri]).sum(), n),
                       "wrong": O.rt((mk & B.W2[si, ri]).sum(), n), "left_med": O.q(B.FAV[si, ri][mk], 50)}
                J["roles"]["%d %s %s" % (t, sd, rn)] = row
                cells.append("%s %d: %s / %s / %s / %s%%" % (rn, n, pc(row["mover2"]), pc(row["right"]), pc(row["wrong"]), f1(row["left_med"], "%.2f")))
            P("  %s %s  %s" % (O.hm(t), sd, " · ".join(cells)))

    # ---- 8 RINGS
    P("\n=== 8. RINGS for the recommended plan (the best pre-open list + the best 09:30 list + the safe trigger, both sides, N=10)")
    P("    the evening card is reported, outside the day count · the 09:08 card 1 ring · the 09:30 card 1 ring when it adds a name · each pick's")
    P("    safe-trigger first fire 1 ring (E0 = enter on the card: no extra ring) · limits: 50 a day, 6 in any 15 minutes")
    J["rings"] = rings(B, P)

    # ---- 9 BIASES
    P("\n=== 9. WHAT THIS CAN AND CANNOT SAY")
    for x in BIASES:
        P("  " + x)

    # ---- 0 THE ANSWER
    top = answer(B, J)
    out[TOP:TOP] = top
    P("\n(%.1f min)" % ((time.time() - B.t0) / 60))
    return "\n".join(out), J


def baseline(B):
    """always predict the tuning days' majority side-day"""
    tr = B.tr
    ce = int((tr & (B.SIDED == 0)).sum()); pe = int((tr & (B.SIDED == 1)).sum())
    k = 0 if ce >= pe else 1
    a = O.rt((tr & (B.SIDED == k)).sum(), tr.sum()); b = O.rt((B.te & (B.SIDED == k)).sum(), B.te.sum())
    return ("UP" if k == 0 else "DOWN", "%s | %s of days" % (pc(a), pc(b)))


def feature_tables(B, P):
    X, V, tr = B.X, B.V, B.tr
    J = {}
    feats = [(k, X[k], 0) for k in ("cpos1", "lhr1", "lhv1", "rvol1", "atrc", "dh5", "dh20", "dh60", "dl5", "dl20", "dl60", "oichg1", "ret1",
                                    "sec1", "sbr1", "rs1", "r5", "rs5", "nif1", "nifcpos1", "dte", "atr20p", "gap", "gapA", "secgap", "gaprs",
                                    "nifgap", "bnfgap")]
    feats += [("gapx up", X["gapx"][0], 0), ("gapx down", X["gapx"][1], 0)]
    for t, ri in zip(TS, (2, 3, 4)):
        feats += [("%s@%d" % (k, t), X["%s%d" % (k, t)], ri) for k in ("mo", "mpc", "rv", "vws", "rs_sec", "rs_nif")]
        feats += [("c5@%d" % t, X["c5_%d" % t], ri), ("beyond up@%d" % t, X["beyond%d" % t][0], ri), ("beyond down@%d" % t, X["beyond%d" % t][1], ri)]
    base = V & tr[:, None]

    def row(mk, ri):
        n = int(mk.sum())
        return {"n": n, "p_ce": O.rt((mk & (B.A[0] >= 2)).sum(), n), "p_pe": O.rt((mk & (B.A[1] >= 2)).sum(), n),
                "fav_ce": O.q(B.FAV[0, ri][mk], 50), "fav_pe": O.q(B.FAV[1, ri][mk], 50),
                "w2_ce": O.rt((mk & B.W2[0, ri]).sum(), n), "w2_pe": O.rt((mk & B.W2[1, ri]).sum(), n)}

    def line(lab_, rows):
        P("  %-15s " % lab_ + " · ".join("%s %s/%s %s/%s %s/%s" % (k, pc(r["p_ce"]), pc(r["p_pe"]), f1(r["fav_ce"], "%.1f"), f1(r["fav_pe"], "%.1f"),
                                                                    pc(r["w2_ce"]), pc(r["w2_pe"])) for k, r in rows))
    tot = row(base, 0)
    P("  ALL share-days  P(2%% CE) %s · P(2%% PE) %s · median best CE %s%% / PE %s%% · WRONG CE %s / PE %s" % (
        pc(tot["p_ce"]), pc(tot["p_pe"]), f1(tot["fav_ce"], "%.2f"), f1(tot["fav_pe"], "%.2f"), pc(tot["w2_ce"]), pc(tot["w2_pe"])))
    for name, M, ri in feats:
        mk0 = base & np.isfinite(M)
        vals = M[mk0]
        if len(vals) < 50:
            continue
        u = np.unique(vals)
        rows = []
        if len(u) <= 6:
            for v in u:
                rows.append(("=%g" % v, row(mk0 & (M == v), ri)))
        else:
            e = np.percentile(vals, (20, 40, 60, 80))
            b = np.searchsorted(e, M, "right")
            for k in range(5):
                rows.append(("Q%d" % (k + 1), row(mk0 & (b == k), ri)))
        J[name] = rows
        line(name, rows)
    for lab_, M, codes in (("build-up D-1", X["oi"], ((0, "none"), (1, "LB"), (2, "SB"), (3, "SC"), (4, "LU"))),
                           ("coil", X["coil"], ((0, "0"), (1, "1"), (2, "2")))):
        rows = [(nm, row(base & (M == c), 0)) for c, nm in codes]
        J[lab_] = rows; line(lab_, rows)
    ew = np.broadcast_to(B.expw[:, None], V.shape); po = np.broadcast_to(B.post[:, None], V.shape)
    rows = [("expiry week", row(base & ew, 0)), ("other", row(base & ~ew, 0)), ("day after expiry", row(base & po, 0))]
    J["expiry"] = rows; line("expiry", rows)
    s = X["streak"]
    rows = [(nm, row(base & mk, 0)) for nm, mk in (("<=-3", s <= -3), ("-2", s == -2), ("-1", s == -1), ("0", s == 0), ("+1", s == 1), ("+2", s == 2),
                                                   (">=+3", s >= 3))]
    J["streak"] = rows; line("streak", rows)
    return J


def plan_lists(B):
    """the recommended plan per side: the better pre-open list (19:45 or 09:08, N=10, by tuning NET2) and the 09:30 list"""
    out = {}
    for si, d, sd in SIDES:
        c = [(li, B.win[(li, si, 10)]) for li in (0, 1) if B.win[(li, si, 10)]["cfg"]]
        c.sort(key=lambda x: (not x[1]["qualified"], -B.grid[(x[1]["cfg"], 10, si)]["tr"]["net2"]))
        pre = c[0] if c else None
        mid = B.win[(3, si, 10)] if B.win[(3, si, 10)]["cfg"] else None
        out[si] = (pre, mid)
    return out


def rings(B, P):
    plan = plan_lists(B)
    G = B.G
    Jr = {}
    for variant in ("all", "top5"):
        X = np.zeros((G, 400))
        any_pre = np.zeros(G, bool); adds = np.zeros(G, bool)
        for si, d, sd in SIDES:
            pre, mid = plan[si]
            Ppre = np.zeros((G, B.S), bool); Pmid = np.zeros((G, B.S), bool)
            if pre:
                li, w = pre
                Ppre, sc, pos = make_list(B, w["cfg"], 10)
                Ppre = Ppre[si]; ppos = pos[si]
                any_pre |= Ppre.any(1)
                e = B.safe.get((li, si))
                if e is not None and e > 0:
                    em = B.trg[si, LEV[li]["npi"], e, 0]
                    fire = Ppre & (em >= 0) & ((ppos < 5) if variant == "top5" else True)
                    gi, sj = np.nonzero(fire)
                    np.add.at(X, (gi, em[gi, sj].astype(int)), 1)
            if mid:
                Pm, sc, pos = make_list(B, mid["cfg"], 10)
                Pmid = Pm[si] & ~Ppre; mpos = pos[si]
                adds |= Pmid.any(1)
                e = B.safe.get((3, si))
                if e is not None and e > 0:
                    em = B.trg[si, LEV[3]["npi"], e, 0]
                    fire = Pmid & (em >= 0) & ((mpos < 5) if variant == "top5" else True)
                    gi, sj = np.nonzero(fire)
                    np.add.at(X, (gi, em[gi, sj].astype(int)), 1)
        X[any_pre, 0] += 1
        X[adds, 15] += 1
        r = O.ring_stats(X, B.days)
        Jr[variant] = r
        if variant == "top5" and Jr["all"]["r15_p90"] <= 6:
            break
        P("  %s: a day median %s, p90 %s · the day's busiest 15 min median %s, p90 %s%s" % (
            "the plan" if variant == "all" else "the plan, the trigger ringing only for the top 5 per side", f1(r["p50"], "%.0f"), f1(r["p90"], "%.0f"),
            f1(r["r15_p50"], "%.0f"), f1(r["r15_p90"], "%.0f"), "" if (r["p90"] <= 50 and r["r15_p90"] <= 6) else "   (over the limit)"))
    for si, d, sd in SIDES:
        pre, mid = plan[si]
        P("    %s: pre-open list %s (trigger %s) · 09:30 list %s (trigger %s)" % (
            sd, cfgname(pre[1]["cfg"]) if pre else "none", TRN[B.safe[(pre[0], si)]] if pre and B.safe.get((pre[0], si)) is not None else "none",
            cfgname(mid["cfg"]) if mid else "none", TRN[B.safe[(3, si)]] if mid and B.safe.get((3, si)) is not None else "none"))
        Jr[sd] = {"pre": cfgname(pre[1]["cfg"]) if pre else None, "mid": cfgname(mid["cfg"]) if mid else None}
    return Jr


def answer(B, J):
    top = []
    A = lambda *a: top.append(" ".join(str(x) for x in a))
    A("\n=== 0. THE ANSWER IN PLAIN WORDS - CE and PE apart, for up / down / mixed days, tuning | held-out (picked on the tuning days only)")
    leak = [k for k, w in B.win.items() if w.get("leak_bad")]
    if leak:
        A("  !! LOOK-AHEAD SUSPECTED: %d winning list(s) still beat their own shares' base rate with the labels shuffled - do not trust the" % len(leak))
        A("  !! picks below until this is found (header, leak test)")
    if J["sanity"].get("mismatch"):
        A("  !! the mover counts do not match movestudy (header) - read with care")
    A("  READ: a VERDICT per level and side. PICKS = beats random shares (95% low > 1.1 on tuning, >= 1.1 held out) AND more RIGHT-minus-WRONG")
    A("  than both the VOLATILE list and the plain TOP-MOVERS list. 'caught' = the share of the day's real 2% moves (from the open) on the list.")
    A("  The intraday trigger is only the ENTRY on a named share; 'earliest safe trigger' = section 6's pre-declared rule.")
    kinds = [("up", B.KIND == 0), ("down", B.KIND == 1), ("mixed", B.KIND == 2)]
    for li in range(5):
        L = LEV[li]
        A("  %s" % L["name"].upper())
        Ja = J["answer"][L["key"]] = {}
        opt = []
        for si, d, sd in SIDES:
            v, info = verdict(B, li, si, 10)
            w = B.win[(li, si, 10)]
            Ja[sd] = {"verdict": v}
            if not w["cfg"]:
                A("    %s: %s (no list)" % (sd, v)); continue
            Pk = make_list(B, w["cfg"], 10)[0][si]
            a = measure(B, Pk, si, li, B.tr); b = measure(B, Pk, si, li, B.te) if B.te.any() else {}
            alt = {}
            for N in (5, 15):
                c = B.win[(li, si, N)]["cfg"]
                if c:
                    m_ = measure(B, make_list(B, c, N)[0][si], si, li, B.tr)
                    alt[N] = m_.get("recall", {}).get("2.0 open", {}).get("caught")
            safe = B.safe.get((li, si))
            rows = J["triggers"].get("%s %s" % (L["key"], sd), {}).get("tuning")
            st = ("%s, median entry %s" % (TRN[safe], O.hm(rows[safe]["em_med"]) if rows and np.isfinite(rows[safe]["em_med"]) else "-")
                  if safe is not None else "NO SAFE TRIGGER")
            if rows and safe:
                st += " (fires on %s of the picks, RIGHT %s vs %s entering at once)" % (pc(rows[safe]["fired"]), pc(rows[safe]["r2"]), pc(rows[0]["r2"]))
            rc = lambda m_: m_.get("recall", {}).get("2.0 open", {})
            A("    %s (the share going %s): %s" % (sd, "UP" if d > 0 else "DOWN", v))
            A("      best N=10 list %s %s%s: catches %s | %s of the day's 2%% %s moves (live %s | %s) [N=5 %s · N=15 %s] · WRONG SIDE %s | %s (random %s)" % (
                w["cfg"][1], w["cfg"][2], "" if w["qualified"] else " (nothing qualified - best NET2)", pc(rc(a).get("caught")), pc(rc(b).get("caught")), sd,
                pc(rc(a).get("live")), pc(rc(b).get("live")), pc(alt.get(5)), pc(alt.get(15)), pc(a.get("w2rate")), pc(b.get("w2rate")), pc(a.get("w2rand"))))
            A("      lift vs random %s (95%% %s-%s) | %s · move left median %s%% (p25 %s%%) · named %s min before half-way%s · earliest safe trigger: %s" % (
                f1(a.get("lift", float("nan")), "%.2f"), f1(a.get("lift_ci", (np.nan,))[0], "%.2f"), f1(a.get("lift_ci", (np.nan, np.nan))[1], "%.2f"),
                f1(b.get("lift", float("nan")), "%.2f"), f1(a.get("left_med", float("nan")), "%.2f"), f1(a.get("left_p25", float("nan")), "%.2f"),
                f1(a.get("to_p50_med", float("nan")), "%.0f"), " (+ the night / 7 min)" if li < 2 else "", st))
            cells = []
            for kn, km in kinds:
                ma = measure(B, Pk, si, li, B.tr & km)
                mb = measure(B, Pk, si, li, B.te & km) if (B.te & km).sum() >= THIN else None
                cells.append("%s days %s%s | %s" % (kn, pc(rc(ma).get("caught")), " (wrong %s)" % pc(ma.get("w2rate")),
                                                   "(thin)" if mb is None else pc(rc(mb).get("caught"))))
                Ja[sd][kn] = {"tuning": rc(ma).get("caught"), "heldout": rc(mb).get("caught") if mb else None, "wrong_tuning": ma.get("w2rate")}
            A("      caught by NIFTY day: " + " · ".join(cells))
            Ja[sd].update({"cfg": cfgname(w["cfg"]), "qualified": w["qualified"], "caught": rc(a).get("caught"), "caught_heldout": rc(b).get("caught"),
                           "live": rc(a).get("live"), "wrong": a.get("w2rate"), "wrong_heldout": b.get("w2rate"), "lift": a.get("lift"),
                           "lift_ci": a.get("lift_ci"), "lift_heldout": b.get("lift"), "left_med": a.get("left_med"), "left_p25": a.get("left_p25"),
                           "to_p50": a.get("to_p50_med"), "safe_trigger": TRN[safe] if safe is not None else None, "n5": alt.get(5), "n15": alt.get(15),
                           "vol_net2": info.get("vol_net2"), "top_net2": info.get("top_net2"), "net2": a.get("net2")})
            if rows:
                e0 = rows[0]
                opt.append("%s %s / %s" % (sd, f1(e0["opt15"], "%+.1f%%"), f1(e0["opt3"], "%+.1f%%")))
        mm = J["market"][L["key"]]
        a, b = mm["tuning"], mm["heldout"]
        if a.get("days"):
            A("    market read: side accuracy %s | %s · wrong-side days %s | %s of the days it called · NEUTRAL %s of days" % (
                pc(a["side_acc"]), pc(b.get("side_acc")) if b.get("days", 0) >= THIN else "(thin)", pc(a["wrong_side_pct_called"]),
                pc(b.get("wrong_side_pct_called")) if b.get("days", 0) >= THIN else "(thin)", pc(a["neutral_pct"])))
        sc = [J["sector"].get("%s %s" % (L["key"], sd), {}).get("tuning", {}) for _, _, sd in SIDES]
        if sc[0].get("named_share") is not None:
            A("    sector read: the named top 3 hold %s (CE) / %s (PE) of the day's 2%% moves; the true top 3 hold %s / %s; a random 3 %s / %s" % (
                pc(sc[0].get("named_share")), pc(sc[1].get("named_share")), pc(sc[0].get("true_share")), pc(sc[1].get("true_share")),
                pc(sc[0].get("random_share")), pc(sc[1].get("random_share"))))
        if opt:
            A("    option proxy (secondary, 60-min, 0.5 delta / 2.5%% premium): %s of the premium after 1.5%% / 3%% costs." % " · ".join(opt))
    return top


BIASES = (
    "SURVIVORSHIP: today's F&O list and today's sectors.json. Shares that left F&O are missing; a share that changed sector is in today's.",
    "MIXED STORE / GROWING UNIVERSE: early half-years have fewer shares (the header shows the universe per half-year). Recall at a fixed N is",
    "  easier on thin days, so N as a % of the universe is shown; lift against same-day random shares is not biased by it.",
    "MULTIPLE TESTING: 90 configurations x 5 levels x 2 sides x 3 N. Limited by the fixed formulas (no fitted weights), selection on the",
    "  tuning days only, the unchanged held-out view, the selection-luck line and the leak test. Some optimism remains in every winner.",
    "THE LEAK TEST shuffles the labels across days within each share and compares the winner with its own shares' base rate: it catches code",
    "  that reads the outcome or joins it to the wrong day. The real look-ahead guard is the test that scrambles day D's minutes and checks",
    "  that D's 19:45 features and scores do not move (preopen_test).",
    "REGIME: about 3 years is mostly one regime. The held-out half-year gives wide intervals; its up / down day splits are thin.",
    "NO NEWS, NO GLOBAL CUES, NO ORDER BOOK: the 19:45 level cannot see overnight news, so it is expected to be weak. 09:08 is the first level",
    "  that sees news, and only through the gap.",
    "THE OPEN AS A FILL: the 09:15 candle's open stands in for the 09:08 pre-open price and is an optimistic fill; section 4 shows the",
    "  19:45 / 09:08 winners again from the 09:16 price (C[0]) as the robustness line.",
    "MINUTE CANDLES hide moves inside a minute. A minute that touches both levels counts as the adverse one first.",
    "MOVE LEFT and the best move run to the day's best price until 15:10. Nobody sells the top: read them as room, not profit.",
    "WHIPSAW share-days count as real moves on both sides (a share that ran 2% up and 2% down is a CE and a PE move).",
    "LABELS, KIND and TYPE are hindsight and are never inputs. The market and sector reads use data up to the naming minute only.",
    "The 19:45 level assumes NSE's day-D-1 futures file is out by 19:45 (S1 and S3 do not need it). The split rule misses splits under 20%.",
    "  grid() smooths illiquid shares. Circuit days are included.",
    "The OPTION PROXY ignores IV, skew, gap-day premiums and liquidity - that is why it is one secondary line and never the verdict.",
    "SECTOR BREADTH in small sectors (4-6 members) moves in big steps; a sector-day needs 4+ listed members to be valid.",
    "E0 rings are the card itself (no extra ring); a pick that never fires its trigger counts as not caught, never as wrong.")


# ------------------------------------------------------------------ commands ------------------------------------------------------------------
def check():
    O.check()
    try:
        sec = json.load(open(os.path.join(O.STORE, "sectors.json")))
    except Exception:
        print("sectors.json: none - no valid sectors"); return
    loose = {k for k in sec if any(w in k.lower() for w in O.LOOSE)}
    days = {}
    for k, mem in sec.items():
        if k in loose:
            continue
        for s in mem:
            fn = os.path.join(O.MIN_DIR, s + ".npz")
            if not os.path.exists(fn):
                continue
            try:
                ts = np.load(fn)["ts"]
            except Exception:
                continue
            u, c = np.unique((np.asarray(ts, np.int64) + 19800) // 86400, return_counts=True)
            for x in u[c >= 300].tolist():
                days.setdefault(x, {}).setdefault(k, 0)
                days[x][k] += 1
    nv = [sum(1 for v in d.values() if v >= MINSEC) for d in days.values()]
    if nv:
        print("valid sectors a day (4+ members with a full day; the run also needs F&O-listed and the previous day): median %.0f, min %d, max %d"
              % (np.median(nv), min(nv), max(nv)))


def run(args):
    t0 = time.time()
    if not os.path.exists(os.path.join(O.MIN_DIR, "NIFTY.npz")):
        print("no store yet - run histstore.py get first"); return None, None
    try:
        os.nice(10)
    except Exception:
        pass
    B = prepare(args)
    print("  pass A + B done · %d shares · %d valid share-days · %.0f s · now the lists" % (B.S, int(B.V.sum()), time.time() - t0), flush=True)
    select(B)
    rep, J = report(B)
    if args.get("verbose", True):
        print(rep)
    open(os.path.join(O.STORE, "preopen_report.txt"), "w").write(rep + "\n")
    json.dump(J, open(os.path.join(O.STORE, "preopen.json"), "w"),
              default=lambda o: o.tolist() if hasattr(o, "tolist") else (None if o is None else str(o)), indent=1)
    print("saved: %s (+ preopen.json) · %.1f min" % (os.path.join(O.STORE, "preopen_report.txt"), (time.time() - t0) / 60))
    return B, J


if __name__ == "__main__":
    a = sys.argv[1:] or ["check"]
    if a[0] == "check":
        check()
    elif a[0] == "run":
        args = O.parse(a[1:])
        if O.market_hours() and not args.get("force"):
            print("it is market hours (09:00-15:35 on a weekday) - GIR needs the CPUs. Run it after 15:35, or add --force."); sys.exit(1)
        run(args)
    else:
        print(__doc__)
