#!/usr/bin/env python3
"""seriesstudy.py - READ ONLY (changes nothing in GIR, sends nothing, fetches nothing, orders nothing). THE MONTHLY SERIES STUDY - the proof the
desk asked for before the MONTHLY F&O PLAN (design_v3/MONTHLY_PLAN.md, section A) may be used. Section B of that file is this script's design.

The trader, 20 Nov: "For the F&O shares, how about a longer holding - targeting the monthly expiry?" ONE trader buys NSE stock options, CE when
he expects a rise and PE when he expects a fall, equal money per trade. The question measured here: does a position OPENED IN THE FIRST 1-3
DAYS OF A MONTHLY SERIES and CLOSED AT EXPIRY-WEEK MONDAY work better than random picks - as a naked option and as a debit spread?

  1 THE CALENDAR  every monthly series in the store from onsetstudy.expiry_flags (last Thursday to Aug 2025, last Tuesday from Sep 2025, a
                  holiday moves it to the market day before), each expiry checked against the NEXT day's drop in the summed futures OI
                  (fo_daily.json); mismatches are printed. Day 1 = the first market day after the previous expiry. Entry at the close of day
                  1, 2 or 3. Exit at the close of expiry-week Monday (the market day before if Monday is a holiday, and never the expiry day
                  itself: when a holiday moves the expiry to Monday, the exit is the Friday before). Nothing is held into expiry week.
  2 THE SIGNALS   read at the close of the entry day from that day and earlier days only, CE and PE exact mirrors (prices on a log scale,
                  so a fall is the mirror of a rise): build-up (price x OI since the expiry close), rollover proxy terciles, the sector's
                  previous-series rank and breadth, the RSI regime (EXTREME / normal / oversold), distance from the 20 / 50-day averages,
                  NIFTY against its 50-day average - each alone, and a short PRE-DECLARED list of pairs and triples (the count of sets
                  tried is reported)
  3 THE OUTCOMES  the share's move to the exit (its way: up for CE, down for PE), the worst move against the position on the way (daily
                  highs / lows), a naked-option proxy (0.5 x the move minus the sqrt(t) decay of an at-the-money premium priced from the
                  share's 20-day realised volatility) and a debit-spread proxy (capped at +80%, floored at -100% of the debit)
  4 BASELINES     all shares the same side and day; the top (bottom) sector only; random matched picks (for every trade a random share of
                  the same series, entry day and side - 10,000 draws); tuning months against the held-out last 6 months; 95% intervals by
                  resampling whole months (series)
  5 THE VERDICT   PASS = the hit-rate lift over random has its 95% interval above 1.0 on the tuning months, the lift stays above 1.0 on the
                  held-out months and in 5 of 6 half-years, and the set gives 2+ trades a month - CE and PE judged separately
  0 THE ANSWER    in plain words at the top: the first-days set that beats random for CE and for PE (or "none does"), trades a month, hit
                  rate (spread proxy > 0), median move, median spread result, worst trade and worst month - tuning and held-out side by
                  side - and the honest caveats

  python3 seriesstudy.py check                  what is in the store: shares, days, the series calendar and its OI check - does no study
  python3 seriesstudy.py run                    the whole study, every share, every series in the store
  python3 seriesstudy.py run --years 3          only the series that start in the last 3 years
  (add --force to run during market hours - by default it refuses between 09:00 and 15:35 on a weekday, so GIR keeps the CPUs)

It reads only the store: STORE/min/SYM.npz (minute candles ts,o,h,l,c,v - turned into daily bars), STORE/min/NIFTY.npz, STORE/fo_daily.json
(NSE's daily futures OI, summed over expiries) and STORE/sectors.json ({sector: [shares]}). STORE is /root/hist, or the folder in the GIR_HIST
environment variable. It writes ONLY:
  STORE/seriesstudy_report.txt     the report in plain words
  STORE/seriesstudy.json           every number in the report
  STORE/seriesstudy_trades.npz     every candidate trade (share x series x entry day) with its signals and outcomes, for later study
About 1-3 minutes on ~220 shares x 3 years (the minute files are the slow part). numpy only. Run it after 15:35:
  cd /home/globalbot/intraday && python3 seriesstudy.py run"""
import os, sys, json, time, math, datetime as dt
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import onsetstudy as O                                       # the store, the loaders, prep, the calendar, ALIAS, LOOSE, boot, market hours
from onsetstudy import STORE, MIN_DIR, ALIAS, LOOSE, NOT_SHARES, dday, boot, market_hours, f1   # noqa: F401  (ALIAS / LOOSE act in O.setup)

KS = (1, 2, 3)                   # entry at the close of day 1 / 2 / 3 of the series
SIDES = ("CE", "PE")
NDRAW = 10000                    # random matched picks
NBOOT = 2000                     # bootstrap resamples (by month = series)
PM_T = 0.005                     # build-up: the price at least 0.5% its way since the expiry close (log scale)
OI_T = 0.02                      # ... and the OI at least 2% above (below) the market's median OI change since the expiry close
X10 = math.log(1.10)             # EXTREME: 10%+ above the 20-day average (rallyscan.py's rule), on a log scale so PE is the exact mirror
PREM_K = 0.4                     # an at-the-money premium ~ 0.4 x sigma x sqrt(years left) of the share price
DELTA = 0.5                      # the naked option proxy's delta
SPREAD_D = 0.55                  # the debit spread costs ~55% of the ATM premium (the plan's M&M example: 65 / 120)
SPREAD_CAP = 0.80                # its maximum profit is +80% of the debit (the width is 1.8 x the debit)
RV_FLOOR = 0.10                  # a 20-day realised volatility under 10% a year is read as 10% (no near-free premiums)
MIN_TPM = 2.0                    # PASS needs 2+ trades a month
HALF_NEED, HALF_OF = 5, 6        # PASS needs the lift above 1.0 in 5 of 6 half-years (generalised: ceil(5/6 x the half-years counted))
HALF_MIN_SERIES = 3              # a half-year counts only with 3+ series in it (the store's first / last stubs do not)
HALF_MIN_TRADES = 3              # ... and a set with fewer than 3 trades in a counted half-year does not hold there
HELD_MIN_TRADES = 6              # "holds in held-out" needs 6+ held-out trades and a lift above 1.0 there
FAMILY_ALPHA = 0.05              # THE MULTIPLE-TESTING GUARD (added to section B's rule, declared before any real run): with ~93 tries a
                                 # side, a plain 95% interval lets pure noise through (on the synthetic noise stores 4 of 6 seeds "passed").
                                 # So the lift's lower bound must ALSO stay above 1.0 when the interval is widened for the number of tries
                                 # on that side (Bonferroni: z = the 1 - 0.025 / tries quantile, ~3.3 for 93 tries, on the log lift with the
                                 # month-bootstrap's standard error). The plain 95% interval is still shown and still required.
OI_DROP = -0.02                  # the calendar check: the summed OI must fall 2%+ the day after an expiry ...
OI_LEAD = 0.01                   # ... and no other day of that month may show a drop more than 1 point bigger
SPLIT_LOOK = 60                  # rows after an unadjusted split / bonus whose 20 / 50-day averages would mix units: no signals there
ROLL_PREV, ROLL_MIN = 6, 2       # the rollover is compared with the share's own last 6 series (at least 2)
BRD_T = 0.70                     # breadth: 70%+ of the sector's shares rose (fell) over the previous series

# ------------------------------------------------------------------ the signals (CE wording; PE is the exact mirror) ------------------------------------------------------------------
SINGLES = ("BU_LB", "BU_SC", "ROLL_HI", "ROLL_LO", "SEC_TOP", "BREADTH", "RSI_N", "RSI_X", "REV_OS", "REV_X", "TREND", "PULL", "MKT")
DESC = {"BU_LB": "long build-up since the expiry close (CE: price up 0.5%+ and OI 2%+ above the market's; PE: short build-up - price down, OI up)",
        "BU_SC": "short covering (CE: price up 0.5%+, OI 2%+ below the market's; PE: long unwinding - price down, OI down)",
        "ROLL_HI": "rollover proxy in the top third of the series (OI day 1 / OI the day before expiry, against the share's own last 6 series) - same for CE and PE",
        "ROLL_LO": "rollover proxy in the bottom third - same for CE and PE",
        "SEC_TOP": "its sector was in the top 3 of the previous series (PE: the bottom 3) - median move of the sector's shares, expiry to expiry",
        "BREADTH": "70%+ of its sector's shares rose over the previous series (PE: 70%+ fell)",
        "RSI_N": "RSI regime normal: daily RSI(14) between 30 and 70 and within 10% of the 20-day average - same for CE and PE",
        "RSI_X": "RSI regime EXTREME its way (CE: RSI >= 80 or 10%+ above the 20-day average; PE: RSI <= 20 or 10%+ below) - the plan's 'never'",
        "REV_OS": "against the stretch (CE on an oversold share, RSI <= 30; PE on an overbought share, RSI >= 70) - the plan's 'do not, until measured'",
        "REV_X": "against an EXTREME (CE on RSI <= 20 or 10%+ below the 20-day average; PE on EXTREME overbought) - the plan's 'do not'",
        "TREND": "above both its 20- and 50-day averages (PE: below both)",
        "PULL": "a pullback to the 20-day average (within 2% of it) while above the 50-day average (PE: below it) - the plan's entry zone",
        "MKT": "NIFTY above its 50-day average (PE: below)"}
PAIRS = (("P01", ("BU_LB", "ROLL_HI")), ("P02", ("BU_LB", "SEC_TOP")), ("P03", ("BU_LB", "TREND")), ("P04", ("BU_LB", "PULL")),
         ("P05", ("BU_LB", "MKT")), ("P06", ("BU_LB", "RSI_N")), ("P07", ("SEC_TOP", "TREND")), ("P08", ("SEC_TOP", "PULL")),
         ("P09", ("SEC_TOP", "BREADTH")), ("P10", ("ROLL_HI", "SEC_TOP")), ("P11", ("TREND", "MKT")), ("P12", ("BU_SC", "SEC_TOP")))
TRIPLES = (("T01", ("BU_LB", "ROLL_HI", "SEC_TOP")), ("T02", ("BU_LB", "SEC_TOP", "PULL")), ("T03", ("BU_LB", "SEC_TOP", "RSI_N")),
           ("T04", ("SEC_TOP", "TREND", "MKT")), ("T05", ("BU_LB", "ROLL_HI", "TREND")), ("T06", ("BU_LB", "SEC_TOP", "MKT")))
SETS = tuple((s, (s,)) for s in SINGLES) + PAIRS + TRIPLES
SETNAME = [n for n, _ in SETS]
SETPARTS = dict(SETS)
for _n, _p in PAIRS + TRIPLES:
    DESC[_n] = " + ".join(_p)
PLAN_SET = "T01"                 # the plan's own CE rule (A3): long build-up + rollover above its average + a leading sector (PE: short
                                 # build-up + rollover + a lagging sector) - always shown in section 0, pass or not
BIT = {s: 1 << i for i, s in enumerate(SINGLES)}
SMASK = np.array([sum(BIT[p] for p in parts) for _, parts in SETS], np.int64)

RDT = np.dtype([("i", "i2"), ("j", "i2"), ("k", "i1"), ("d", "i4"), ("x", "i4"), ("e", "i4"), ("sec", "i2"),
                ("pm", "f4"), ("oirel", "f4"), ("rollq", "f4"), ("rkt", "i2"), ("rkb", "i2"), ("ntop", "i2"), ("bup", "f4"), ("bdn", "f4"),
                ("rsi", "f4"), ("d20", "f4"), ("d50", "f4"), ("nif", "f4"), ("rv", "f4"), ("p0", "f4"), ("p1", "f4"), ("ok", "?"),
                ("bits", "i8", (2,)), ("move", "f4", (2,)), ("mae", "f4", (2,)), ("naked", "f4", (2,)), ("spread", "f4", (2,))])
# one row per share x series x entry day where the share has a valid entry-day bar; ok = it also has an exit bar (a trade). bits / move /
# mae / naked / spread are per side: [0] CE, [1] PE. rkt / rkb = its sector's previous-series rank from the top / bottom (-1 = none)


# ------------------------------------------------------------------ daily bars from the minute store ------------------------------------------------------------------
def load_share(s):
    """one share -> its daily bars on NIFTY's calendar (close = the day's last minute, high / low over the day), the days onsetstudy.prep
    lets into a study (full session, previous day present, no split jump, listed in F&O that day, inside --years) and its split days"""
    R = O.load_rows(s)
    if R is None:
        return None
    P = O.prep(s, R, full=False)
    g = np.array([O.GIDX[int(x)] for x in R["day"]], np.int64)
    sp = [O.GIDX.get((dt.date.fromisoformat(x) - dt.date(1970, 1, 1)).days, -1) for x in P["splits"]]
    return {"s": s, "g": g, "c": R["C"][:, -1].astype(np.float64), "h": R["H"].max(1).astype(np.float64),
            "l": R["L"].min(1).astype(np.float64), "vg": np.asarray(P["g"], np.int64), "splits": [x for x in sp if x >= 0],
            "unlisted": P["unlisted"]}


def rsi_series(lc, n=14):
    """Wilder's RSI(14) on log closes (so a mirror-image share gets exactly 100 - RSI); row r uses rows <= r only"""
    out = np.full(len(lc), np.nan)
    d = np.diff(lc)
    if len(d) < n:
        return out
    up = np.maximum(d, 0.0); dn = np.maximum(-d, 0.0)
    au, ad = up[:n].mean(), dn[:n].mean()

    def val(a, b):
        return 50.0 if a == 0 and b == 0 else 100.0 if b == 0 else 100.0 - 100.0 / (1.0 + a / b)
    out[n] = val(au, ad)
    for i in range(n, len(d)):
        au = (au * (n - 1) + up[i]) / n; ad = (ad * (n - 1) + dn[i]) / n
        out[i + 1] = val(au, ad)
    return out


def trail_mean(x, k):
    """mean of rows r-k+1 .. r (NaN with fewer than k rows)"""
    out = np.full(len(x), np.nan)
    if len(x) >= k:
        cs = np.cumsum(np.r_[0.0, x])
        out[k - 1:] = (cs[k:] - cs[:-k]) / k
    return out


def indicators(D):
    """per share, on its own rows (causal): RSI(14), log distance from the 20 / 50-day (geometric) averages, 20-day realised volatility"""
    lc = np.log(D["c"]); n = len(lc)
    rsi = rsi_series(lc)
    d20 = lc - trail_mean(lc, 20); d50 = lc - trail_mean(lc, 50)
    r = np.r_[np.nan, np.diff(lc)]
    m1 = trail_mean(np.nan_to_num(r), 20); m2 = trail_mean(np.nan_to_num(r) ** 2, 20)
    rv = np.sqrt(np.maximum(m2 - m1 * m1, 0) * 20 / 19) * math.sqrt(252)
    rv[:21] = np.nan
    bad = np.zeros(n, bool)
    pos = {int(g): p for p, g in enumerate(D["g"])}
    for sg in D["splits"]:
        p = pos.get(int(sg))
        if p is not None:
            bad[p:p + SPLIT_LOOK + 1] = True
    for a in (rsi, d20, d50, rv):
        a[bad] = np.nan
    return rsi, d20, d50, rv


# ------------------------------------------------------------------ the series calendar and its OI check ------------------------------------------------------------------
def series_calendar():
    """-> the series with a known start and end: e0 = the previous expiry (day 0), e1 = this expiry, days 1-3, x = the exit (close of
    expiry-week Monday, the market day before if Monday is a holiday, never the expiry day itself), and the open series (no expiry yet)"""
    E = np.nonzero(O.EXP)[0]
    out = []
    for j in range(1, len(E)):
        e0, e1 = int(E[j - 1]), int(E[j])
        ed = dday(O.CAL[e1])
        mon = ed - dt.timedelta(days=ed.weekday())
        x = int(np.searchsorted(O.CAL, (mon - dt.date(1970, 1, 1)).days, "right")) - 1
        x = min(x, e1 - 1)
        out.append({"j": len(out), "e0": e0, "e1": e1, "x": x, "em1": e0 - 1 if e0 >= 1 else -1,
                    "days": [e0 + k if e0 + k < x else -1 for k in KS], "label": ed.strftime("%b %Y")})
    open_ = None
    if len(E) and E[-1] + 1 < O.G:
        open_ = {"day1": str(dday(O.CAL[E[-1] + 1])), "after": str(dday(O.CAL[E[-1]]))}
    return out, E, open_


def oi_matrix(syms):
    """summed futures OI per symbol and market day (NaN = not in NSE's file that day)"""
    M = np.full((len(syms), O.G), np.nan)
    ds = [str(dday(x)) for x in O.CAL]
    have = [d in O.FODAYS for d in ds] if O.FODAYS else [True] * O.G
    for a, s in enumerate(syms):
        f = O.FOD.get(s) or {}
        for g, d in enumerate(ds):
            if have[g]:
                r = f.get(d)
                if r and r[0] and float(r[0]) > 0:
                    M[a, g] = float(r[0])
    return M


def oi_check(E):
    """every flagged expiry against the next market day's drop in the summed OI (over the symbols present both days)"""
    syms = sorted(O.FOD)
    if not syms:
        return [], "no NSE daily futures file - the calendar could not be checked against OI"
    M = oi_matrix(syms)
    both = np.isfinite(M[:, :-1]) & np.isfinite(M[:, 1:])
    a = np.where(both, M[:, :-1], 0).sum(0); b = np.where(both, M[:, 1:], 0).sum(0)
    with np.errstate(all="ignore"):
        r = np.where(a > 0, b / a - 1, np.nan)                 # r[g] = the change from day g to day g+1
    r = np.r_[r, np.nan]
    mon = np.array([dday(x).year * 12 + dday(x).month for x in O.CAL])
    rows = []
    for e in E:
        e = int(e); dr = r[e]
        inm = np.nonzero((mon == mon[e]) & np.isfinite(r))[0]
        big = int(inm[np.argmin(r[inm])]) if len(inm) else -1
        if not np.isfinite(dr):
            st = "no OI data for the day after"
        elif dr > OI_DROP:
            st = "MISMATCH: the summed OI did not fall the next day"
        elif big >= 0 and big != e and r[big] < dr - OI_LEAD:
            st = "MISMATCH: a bigger drop after %s" % dday(O.CAL[big]).strftime("%a %d %b")
        else:
            st = "ok"
        rows.append({"expiry": str(dday(O.CAL[e])), "wd": dday(O.CAL[e]).strftime("%a"), "drop": float(dr) * 100 if np.isfinite(dr) else None,
                     "status": st, "biggest": str(dday(O.CAL[big])) if big >= 0 else None})
    return rows, None


# ------------------------------------------------------------------ the study rows: signals and outcomes ------------------------------------------------------------------
def build(names, D):
    """-> RDT rows for every share x series x entry day, with the series list and the per-share sector ids"""
    NSH = len(names); G = O.G
    C = np.full((NSH, G), np.nan); H = np.full((NSH, G), np.nan); L = np.full((NSH, G), np.nan); V = np.zeros((NSH, G), bool)
    RS = np.full((NSH, G), np.nan); D20 = np.full((NSH, G), np.nan); D50 = np.full((NSH, G), np.nan); RV = np.full((NSH, G), np.nan)
    SPL = np.zeros((NSH, G), bool)
    for i, s in enumerate(names):
        d = D.get(s)
        if not d:
            continue
        C[i, d["g"]] = d["c"]; H[i, d["g"]] = d["h"]; L[i, d["g"]] = d["l"]; V[i, d["vg"]] = True
        rs, a20, a50, rv = indicators(d)
        RS[i, d["g"]] = rs; D20[i, d["g"]] = a20; D50[i, d["g"]] = a50; RV[i, d["g"]] = rv
        SPL[i, [x for x in d["splits"]]] = True
    OI = oi_matrix(names)
    nl = np.log(O.NIFC[:, -1]) if O.G else np.zeros(0)
    NIF = nl - trail_mean(nl, 50)
    # sectors: real ones only (O.SEC already moved LOOSE buckets and unsectored shares to "_SYM" singletons)
    secs = sorted(k for k in O.SEC if not k.startswith("_"))
    sid = np.full(NSH, -1, np.int16)
    for a, k in enumerate(secs):
        for s in O.SEC[k]:
            if s in O.SHIDX:
                sid[names.index(s)] = a
    SER, E, open_ = series_calendar()
    J = len(SER)
    # the rollover proxy per share and series: log(OI day 1 / OI the day before the previous expiry)
    ROLL = np.full((NSH, J), np.nan)
    for sr in SER:
        if sr["em1"] >= 0:
            with np.errstate(all="ignore"):
                ROLL[:, sr["j"]] = np.log(OI[:, sr["e0"] + 1] / OI[:, sr["em1"]])
    rows = []
    with np.errstate(all="ignore"):
        for sr in SER:
            j, e0, e1, x = sr["j"], sr["e0"], sr["e1"], sr["x"]
            if e0 + 1 < O.GLO:
                continue
            # the sector's previous series (expiry to expiry), known on day 1
            rkt = np.full(NSH, -1, np.int16); rkb = np.full(NSH, -1, np.int16); bup = np.full(NSH, np.nan); bdn = np.full(NSH, np.nan)
            ntop = 0
            if j >= 1:
                p0, p1 = SER[j - 1]["e0"], SER[j - 1]["e1"]
                pr = np.log(C[:, p1] / C[:, p0])
                med, fu, fd, ks = [], [], [], []
                for a in range(len(secs)):
                    v = pr[(sid == a) & np.isfinite(pr)]
                    if len(v) >= 3:
                        ks.append(a); med.append(np.median(v)); fu.append((v > 0).mean()); fd.append((v < 0).mean())
                if ks:
                    med = np.array(med); nsec = len(ks)
                    ntop = 3 if nsec >= 9 else max(1, nsec // 3)
                    ot = np.argsort(-med, kind="stable"); ob = np.argsort(med, kind="stable")
                    rt_ = np.empty(nsec, int); rt_[ot] = np.arange(nsec); rb_ = np.empty(nsec, int); rb_[ob] = np.arange(nsec)
                    for q_, a in enumerate(ks):
                        m_ = sid == a
                        rkt[m_] = rt_[q_]; rkb[m_] = rb_[q_]; bup[m_] = fu[q_]; bdn[m_] = fd[q_]
            # rollover terciles of the series (against the share's own last 6 series), known at the close of day 1
            rq = np.full(NSH, np.nan)
            rel = np.full(NSH, np.nan)
            for i in range(NSH):
                h_ = ROLL[i, max(0, j - ROLL_PREV):j]; h_ = h_[np.isfinite(h_)]
                if len(h_) >= ROLL_MIN and np.isfinite(ROLL[i, j]) and V[i, e0 + 1]:
                    rel[i] = ROLL[i, j] - np.median(h_)
            fin = np.nonzero(np.isfinite(rel))[0]
            if len(fin) >= 3:
                o_ = np.argsort(rel[fin], kind="stable"); rr = np.empty(len(fin)); rr[o_] = np.arange(len(fin)) / (len(fin) - 1)
                rq[fin] = rr
            for k, d in zip(KS, sr["days"]):
                if d < 0 or d < O.GLO:
                    continue
                # build-up: the price since the expiry close, the OI since the expiry close against the market's median OI change that day
                pm = np.log(C[:, d] / C[:, e0])
                lo = np.log(OI[:, d] / OI[:, e0])
                pool = V[:, d] & np.isfinite(lo)
                oirel = lo - (np.median(lo[pool]) if pool.sum() >= 3 else np.nan)
                T0 = e1 - d; T1 = e1 - x
                for i in np.nonzero(V[:, d] & np.isfinite(C[:, e0]) & np.isfinite(RV[:, d]))[0]:
                    r = np.zeros((), RDT)
                    r["i"], r["j"], r["k"], r["d"], r["x"], r["e"], r["sec"] = i, j, k, d, x, e1, sid[i]
                    r["pm"], r["oirel"], r["rollq"] = pm[i], oirel[i], rq[i]
                    r["rkt"], r["rkb"], r["ntop"], r["bup"], r["bdn"] = rkt[i], rkb[i], ntop, bup[i], bdn[i]
                    r["rsi"], r["d20"], r["d50"], r["nif"] = RS[i, d], D20[i, d], D50[i, d], NIF[d]
                    rv = max(float(RV[i, d]), RV_FLOOR); r["rv"] = rv
                    p0_ = PREM_K * rv * math.sqrt(T0 / 252.0) * 100; p1_ = PREM_K * rv * math.sqrt(max(T1, 0) / 252.0) * 100
                    r["p0"], r["p1"] = p0_, p1_
                    en, ex = C[i, d], C[i, x]
                    ok = bool(np.isfinite(ex) and not SPL[i, d + 1:x + 1].any())
                    r["ok"] = ok
                    if ok:
                        lw = np.nanmin(L[i, d + 1:x + 1]); hg = np.nanmax(H[i, d + 1:x + 1])
                        mv = np.array([(ex / en - 1) * 100, (1 - ex / en) * 100])
                        r["move"] = mv
                        r["mae"] = [min(0.0, (lw / en - 1) * 100), min(0.0, (1 - hg / en) * 100)]
                        r["naked"] = np.maximum(-100.0, (DELTA * mv - (p0_ - p1_)) / p0_ * 100)
                        dbt = SPREAD_D * p0_; w = (1 + SPREAD_CAP) * dbt
                        r["spread"] = np.clip((np.clip(mv, 0, w) - dbt) / dbt * 100, -100, SPREAD_CAP * 100)
                    else:
                        r["move"] = r["mae"] = r["naked"] = r["spread"] = np.nan
                    rows.append(r)
    R = np.array(rows, RDT) if rows else np.zeros(0, RDT)
    for sd in (0, 1):
        R["bits"][:, sd] = signal_bits(R, sd)
    return R, SER, E, open_, secs, sid


def zq(p):
    """the standard normal quantile (bisection on erfc - numpy only, no scipy)"""
    lo, hi = -10.0, 10.0
    for _ in range(80):
        m = (lo + hi) / 2
        if 0.5 * math.erfc(-m / math.sqrt(2)) < p:
            lo = m
        else:
            hi = m
    return (lo + hi) / 2


def side_vars(R, sd):
    """the CE view (sd 0) or its mirror, the PE view (sd 1): every directional number flips sign, RSI becomes 100 - RSI, the sector's rank
    is counted from the bottom and the breadth counts the fallers"""
    sg = 1.0 if sd == 0 else -1.0
    return {"pm": sg * R["pm"], "oi": R["oirel"], "rq": R["rollq"], "rk": R["rkt"] if sd == 0 else R["rkb"], "ntop": R["ntop"],
            "brd": R["bup"] if sd == 0 else R["bdn"], "rsi": R["rsi"] if sd == 0 else 100.0 - R["rsi"], "d20": sg * R["d20"],
            "d50": sg * R["d50"], "nif": sg * R["nif"]}


def signal_bits(R, sd):
    v = side_vars(R, sd)
    with np.errstate(invalid="ignore"):
        on = {"BU_LB": (v["pm"] >= PM_T) & (v["oi"] >= OI_T),
              "BU_SC": (v["pm"] >= PM_T) & (v["oi"] <= -OI_T),
              "ROLL_HI": v["rq"] >= 2.0 / 3.0,
              "ROLL_LO": v["rq"] <= 1.0 / 3.0,
              "SEC_TOP": (v["rk"] >= 0) & (v["rk"] < v["ntop"]),
              "BREADTH": v["brd"] >= BRD_T,
              "RSI_N": (v["rsi"] > 30) & (v["rsi"] < 70) & (np.abs(v["d20"]) < X10),
              "RSI_X": (v["rsi"] >= 80) | (v["d20"] >= X10),
              "REV_OS": v["rsi"] <= 30,
              "REV_X": (v["rsi"] <= 20) | (v["d20"] <= -X10),
              "TREND": (v["d20"] > 0) & (v["d50"] > 0),
              "PULL": (np.abs(v["d20"]) <= 0.02) & (v["d50"] > 0),
              "MKT": v["nif"] > 0}
    b = np.zeros(len(R), np.int64)
    for s in SINGLES:
        b |= np.where(on[s], BIT[s], 0)
    return b


# ------------------------------------------------------------------ the tables ------------------------------------------------------------------
class Study:
    def __init__(self, R, SER, names):
        self.R = R; self.SER = SER; self.names = names
        self.T = R[R["ok"]]                                   # the trades (an exit bar exists)
        J = len(SER); self.J = J
        cut = O.TRAIN
        self.tune = np.array([bool(cut[s["x"]]) for s in SER], bool)                     # the whole series ends inside the tuning days
        self.held = np.array([not bool(cut[s["e0"] + 1]) for s in SER], bool)           # the whole series starts after the cut
        used = np.zeros(J, bool); used[np.unique(self.T["j"])] = True
        self.used = used
        self.tune &= used; self.held &= used
        self.half = np.array([int(O.HALF[s["e0"] + 1]) for s in SER], int)
        hc = np.bincount(self.half[used], minlength=len(O.HNAME))
        self.halves = [h for h in range(len(O.HNAME)) if hc[h] >= HALF_MIN_SERIES]
        self.Wt = np.random.default_rng(7).poisson(1.0, (NBOOT, int(self.tune.sum()))).astype(np.float64)
        self.rng = np.random.default_rng(11)
        self.ntry = len(SETS) * len(KS)
        self.zfam = zq(1 - FAMILY_ALPHA / 2 / self.ntry)
        self.hit = (self.T["spread"] > 0)
        # the pool's hit rate per side, entry day and series (what a random matched pick hits)
        self.P = {}
        for sd in (0, 1):
            for k in KS:
                m = self.T["k"] == k
                n = np.bincount(self.T["j"][m], minlength=J).astype(float)
                h = np.bincount(self.T["j"][m], weights=self.hit[m, sd].astype(float), minlength=J)
                with np.errstate(all="ignore"):
                    self.P[sd, k] = (np.where(n > 0, h / n, np.nan), n)

    def members(self, sd, k, si):
        mk = SMASK[si]
        return (self.T["k"] == k) & ((self.T["bits"][:, sd] & mk) == mk)

    def summary(self, sd, m, jm):
        """plain numbers over trades m restricted to series mask jm"""
        T = self.T
        mm = m & jm[T["j"]]
        n = int(mm.sum()); ns = int(jm.sum())
        out = {"trades": n, "series": ns, "tpm": n / ns if ns else float("nan")}
        if not n:
            return out
        sp = T["spread"][mm, sd]; mv = T["move"][mm, sd]
        out.update({"hit": float((sp > 0).mean()), "move_med": float(np.median(mv)), "move_mean": float(mv.mean()),
                    "spread_med": float(np.median(sp)), "spread_mean": float(sp.mean()), "naked_med": float(np.median(T["naked"][mm, sd])),
                    "naked_mean": float(T["naked"][mm, sd].mean()), "mae_med": float(np.median(T["mae"][mm, sd])),
                    "naked_hit": float((T["naked"][mm, sd] > 0).mean())})
        w = np.nonzero(mm)[0][int(np.argmin(mv))]
        out["worst"] = {"share": self.names[T["i"][w]], "entry": str(dday(O.CAL[T["d"][w]])), "exit": str(dday(O.CAL[T["x"][w]])),
                        "move": float(T["move"][w, sd]), "mae": float(T["mae"][w, sd]), "spread": float(T["spread"][w, sd]),
                        "naked": float(T["naked"][w, sd])}
        js = T["j"][mm]
        cnt = np.bincount(js, minlength=self.J); tot = np.bincount(js, weights=sp, minlength=self.J)
        ok = np.nonzero(cnt > 0)[0]
        wj = ok[np.argmin(tot[ok] / cnt[ok])]
        out["worst_month"] = {"series": self.SER[wj]["label"], "trades": int(cnt[wj]), "spread_avg": float(tot[wj] / cnt[wj]),
                              "move_avg": float(np.bincount(js, weights=mv, minlength=self.J)[wj] / cnt[wj])}
        return out

    def lift_parts(self, sd, k, m):
        p, _ = self.P[sd, k]
        js = self.T["j"][m]
        n = np.bincount(js, minlength=self.J).astype(float)
        h = np.bincount(js, weights=self.hit[m, sd].astype(float), minlength=self.J)
        e = n * np.nan_to_num(p)
        return n, h, e

    def judge(self, sd, k, si):
        m = self.members(sd, k, si)
        n, h, e = self.lift_parts(sd, k, m)
        tu, he = self.tune, self.held
        st = {"set": SETNAME[si], "side": SIDES[sd], "k": k, "parts": list(SETS[si][1])}
        st["tune"] = self.summary(sd, m, tu); st["held"] = self.summary(sd, m, he)
        lt = h[tu].sum() / e[tu].sum() if e[tu].sum() > 0 else float("nan")
        lh = h[he].sum() / e[he].sum() if e[he].sum() > 0 else float("nan")
        ci = boot(h[tu], e[tu], self.Wt) if tu.sum() else (float("nan"), float("nan"))
        st["lift"], st["lift_ci"], st["lift_held"] = lt, ci, lh
        adj = float("nan")                                     # the multiple-testing guard: the log lift's bootstrap SE x z(tries)
        if tu.sum() and np.isfinite(lt) and lt > 0:
            a_ = self.Wt @ h[tu]; b_ = self.Wt @ e[tu]
            ok_ = (a_ > 0) & (b_ > 0)
            if ok_.sum() >= NBOOT // 2:
                adj = float(math.exp(math.log(lt) - self.zfam * np.std(np.log(a_[ok_] / b_[ok_]))))
            else:
                adj = 0.0
        st["lift_adj"] = adj
        st["rand_hit"] = float(e[tu].sum() / n[tu].sum()) if n[tu].sum() else float("nan")
        st["rand_hit_held"] = float(e[he].sum() / n[he].sum()) if n[he].sum() else float("nan")
        # 10,000 random matched picks on the tuning months: every trade replaced by a random share of the same series, entry day and side.
        # For the hit count that is exactly a binomial draw per series (n trades, the pool's hit rate)
        p, _ = self.P[sd, k]
        jt = np.nonzero(tu & (n > 0))[0]
        if len(jt):
            dr = self.rng.binomial(n[jt].astype(np.int64)[None, :], np.nan_to_num(p[jt])[None, :], size=(NDRAW, len(jt))).sum(1)
            st["rand_p"] = float((dr >= h[jt].sum()).mean())
            st["rand_band"] = (float(np.percentile(dr, 2.5) / n[jt].sum()), float(np.percentile(dr, 97.5) / n[jt].sum()))
        else:
            st["rand_p"], st["rand_band"] = float("nan"), (float("nan"), float("nan"))
        hv = []
        for hh in self.halves:
            jm = self.used & (self.half == hh)
            nh = n[jm].sum(); eh = e[jm].sum()
            lv = h[jm].sum() / eh if eh > 0 else float("nan")
            hv.append({"half": O.HNAME[hh], "trades": int(nh), "lift": lv, "holds": bool(nh >= HALF_MIN_TRADES and np.isfinite(lv) and lv > 1.0)})
        st["halves"] = hv
        nh_need = int(math.ceil(HALF_NEED / HALF_OF * len(self.halves))) if self.halves else 1
        st["halves_need"] = nh_need
        st["halves_ok"] = sum(x["holds"] for x in hv)
        why = []
        if not (st["tune"]["tpm"] >= MIN_TPM):
            why.append("%.1f trades a month (< %g)" % (st["tune"]["tpm"] if np.isfinite(st["tune"]["tpm"]) else 0, MIN_TPM))
        if not (np.isfinite(ci[0]) and ci[0] > 1.0):
            why.append("lift interval %s-%s not above 1.0" % (f1(ci[0], "%.2f"), f1(ci[1], "%.2f")))
        elif not (np.isfinite(adj) and adj > 1.0):
            why.append("lift bound %s after the %d-tries guard not above 1.0" % (f1(adj, "%.2f"), self.ntry))
        if not (st["held"]["trades"] >= HELD_MIN_TRADES and np.isfinite(lh) and lh > 1.0):
            why.append("held-out lift %s on %d trades" % (f1(lh, "%.2f"), st["held"]["trades"]))
        if st["halves_ok"] < nh_need:
            why.append("lift above 1.0 in %d of %d half-years (needs %d)" % (st["halves_ok"], len(self.halves), nh_need))
        st["pass"] = not why
        st["why"] = why
        return st

    def baseline(self, sd, k, jm, top=False):
        T = self.T
        m = T["k"] == k
        if top:
            rk = T["rkt"] if sd == 0 else T["rkb"]
            m &= rk == 0
        return self.summary(sd, m, jm)


def pct(x, f="%.0f%%", mul=100):
    return f1(x * mul if x is not None and np.isfinite(x) else float("nan"), f)


def sgn(x, f="%+.1f%%"):
    return f1(x, f)


def setlabel(st):
    return "%s at the close of day %d" % (st["set"] if st["set"] in SINGLES else "%s (%s)" % (st["set"], " + ".join(st["parts"])), st["k"])


# ------------------------------------------------------------------ the report ------------------------------------------------------------------
def report(S, SER, E, open_, chk, chk_note, secs, names, nsh_data, t0, args):
    out = []; P = out.append
    J = {"meta": {}, "calendar": [], "oi_check": chk, "baselines": {}, "tries": [], "answer": {}}
    T = S.T
    tu, he = S.tune, S.held
    used_ser = [s for s in SER if S.used[s["j"]]]
    ntry = len(SETS) * len(KS)
    first = dday(O.CAL[used_ser[0]["e0"] + 1]) if used_ser else None
    last = dday(O.CAL[used_ser[-1]["x"]]) if used_ser else None
    P("=== THE MONTHLY SERIES STUDY (seriesstudy.py) · %s -> %s · %d series used (%d tuning, %d held-out, %d dropped at the cut) · %d shares with "
      "data · %d candidate trades" % (first, last, len(used_ser), int(tu.sum()), int(he.sum()), int(S.used.sum() - tu.sum() - he.sum()), nsh_data, len(T)))
    P("Entry at the close of day 1 / 2 / 3 of a monthly series, exit at the close of expiry-week Monday. CE and PE judged separately. "
      "%d signal sets x %d entry days = %d tries per side (%d in all)." % (len(SETS), len(KS), ntry, 2 * ntry))
    P("")
    TOP = len(out)
    # ---------------- 1 the calendar
    P("1 THE CALENDAR - every monthly series (day 0 = the previous expiry; days 1-3 = the entry days; exit = the close of expiry-week Monday)")
    P("  %-9s %-15s %-15s %-15s %-15s %-15s %8s  %s" % ("series", "day 0 (expiry)", "day 1", "day 2", "day 3", "exit", "OI drop", "check"))
    chkd = {c["expiry"]: c for c in chk}
    for s in SER:
        c = chkd.get(str(dday(O.CAL[s["e1"]])), {})
        dl = [dday(O.CAL[d]).strftime("%a %d %b %y") if d >= 0 else "-" for d in s["days"]]
        tag = "" if S.used[s["j"]] else "  (not used: outside --years or no trades)"
        side = " tuning" if tu[s["j"]] else " HELD-OUT" if he[s["j"]] else (" (cut)" if S.used[s["j"]] else "")
        P("  %-9s %-15s %-15s %-15s %-15s %-15s %8s  %s%s%s" % (s["label"], dday(O.CAL[s["e0"]]).strftime("%a %d %b %y"), dl[0], dl[1], dl[2],
                                                           dday(O.CAL[s["x"]]).strftime("%a %d %b %y"),
                                                           f1(c.get("drop"), "%+.1f%%") if c else "-", c.get("status", "-"), side, tag))
        J["calendar"].append({"series": s["label"], "day0": str(dday(O.CAL[s["e0"]])), "expiry": str(dday(O.CAL[s["e1"]])),
                              "days": [str(dday(O.CAL[d])) if d >= 0 else None for d in s["days"]], "exit": str(dday(O.CAL[s["x"]])),
                              "tuning": bool(tu[s["j"]]), "heldout": bool(he[s["j"]]), "used": bool(S.used[s["j"]])})
    if E is not None and len(E):
        c0 = chkd.get(str(dday(O.CAL[E[0]])), {})
        P("  (the first expiry in the store, %s, only opens the first series; its OI check: %s)" % (dday(O.CAL[E[0]]), c0.get("status", "-")))
    if open_:
        P("  the open series (day 1 = %s, after the %s expiry) has no exit in the store yet - not studied" % (open_["day1"], open_["after"]))
    mis = [c for c in chk if c["status"] != "ok"]
    if chk_note:
        P("  OI CHECK: " + chk_note)
    else:
        P("  OI CHECK: %d of %d expiries agree with the next day's drop in the summed futures OI; %d mismatch%s%s" % (
            len(chk) - len(mis), len(chk), len(mis), "" if len(mis) == 1 else "es", ":" if mis else ""))
        for c in mis:
            P("    !! %s (%s): %s (drop %s)" % (c["expiry"], c["wd"], c["status"], f1(c["drop"], "%+.1f%%")))
    P("")
    # ---------------- 2 baselines
    P("2 BASELINES - every share the same side and day (ALL), the top sector of the previous series only (TOP; PE: the bottom sector)")
    P("  hit = the debit-spread proxy ended above 0 · move = the share's move its way to the exit · spread / naked = the proxies' results (% of the premium paid)")
    P("  %-4s %-3s %-5s | %-44s | %-44s" % ("side", "day", "base", "tuning: trades/mo  hit  move  spread  naked  MAE", "held-out: trades/mo  hit  move  spread  naked  MAE"))
    for sd in (0, 1):
        for k in KS:
            for nm, top in (("ALL", False), ("TOP", True)):
                a = S.baseline(sd, k, tu, top); b = S.baseline(sd, k, he, top)
                J["baselines"]["%s_d%d_%s" % (SIDES[sd], k, nm)] = {"tune": a, "held": b}
                P("  %-4s %-3d %-5s | %s | %s" % (SIDES[sd], k, nm, brow(a), brow(b)))
    P("")
    # ---------------- 3 / 4 every try
    tries = []
    for sd in (0, 1):
        for si in range(len(SETS)):
            for k in KS:
                tries.append(S.judge(sd, k, si))
    J["tries"] = tries
    for title, keep in (("3 SINGLE SIGNALS", lambda n: n in SINGLES), ("4 PRE-DECLARED PAIRS AND TRIPLES", lambda n: n not in SINGLES)):
        P("%s - lift = hit rate / random matched picks' hit rate (tuning, 95%% interval by month) · held = the same on the held-out months · "
          "guard = the lift's lower bound widened for the %d tries a side · half = half-years with lift > 1 / counted" % (title, ntry))
        for sd in (0, 1):
            P("  %s %s" % (SIDES[sd], "(buy calls on expected rises)" if sd == 0 else "(buy puts on expected falls - every signal mirrored)"))
            P("    %-8s %-3s %6s %5s %5s %-16s %5s %6s %6s %7s %7s %6s %5s  %s" % ("set", "day", "tr/mo", "hit", "rand", "lift [95%]", "guard", "p",
                                                                          "held", "move", "spread", "naked", "half", "verdict"))
            for st in tries:
                if st["side"] != SIDES[sd] or not keep(st["set"]):
                    continue
                a = st["tune"]
                P("    %-8s %-3d %6s %5s %5s %-16s %5s %6s %6s %7s %7s %6s %5s  %s" % (
                    st["set"], st["k"], f1(a["tpm"]), pct(a.get("hit")), pct(st["rand_hit"]),
                    "%s [%s-%s]" % (f1(st["lift"], "%.2f"), f1(st["lift_ci"][0], "%.2f"), f1(st["lift_ci"][1], "%.2f")),
                    f1(st["lift_adj"], "%.2f"), f1(st["rand_p"], "%.3f"), f1(st["lift_held"], "%.2f"), sgn(a.get("move_med")), sgn(a.get("spread_med"), "%+.0f%%"),
                    sgn(a.get("naked_med"), "%+.0f%%"), "%d/%d" % (st["halves_ok"], len(S.halves)), "PASS" if st["pass"] else "-"))
        P("")
    P("  the signals (CE wording; PE = the mirror):")
    for s in SINGLES:
        P("    %-8s %s" % (s, DESC[s]))
    P("    pairs / triples (declared before the run, never added after): " + " · ".join("%s = %s" % (n, DESC[n]) for n, _ in PAIRS + TRIPLES))
    P("")
    # ---------------- 5 the verdict
    P("5 THE VERDICT - PASS = lift 95%% interval above 1.0 (tuning) and still above 1.0 after the %d-tries guard + lift > 1.0 held-out (%d+ trades) "
      "+ lift > 1.0 in %d of %d half-years (%s) + %g+ trades a month · %d tries per side" % (ntry, HELD_MIN_TRADES, tries[0]["halves_need"] if tries else 0, len(S.halves),
                                                       ", ".join(O.HNAME[h] for h in S.halves), MIN_TPM, ntry))
    best = {}
    for sd in (0, 1):
        ps = [st for st in tries if st["side"] == SIDES[sd] and st["pass"]]
        ps.sort(key=lambda st: (-st["lift_ci"][0], -st["tune"]["trades"]))
        best[sd] = ps[0] if ps else None
        P("  %s: %d of %d tries pass%s" % (SIDES[sd], len(ps), ntry, ": " + ", ".join("%s day %d (lift %.2f [%.2f-%.2f], held %.2f)" % (
            st["set"], st["k"], st["lift"], st["lift_ci"][0], st["lift_ci"][1], st["lift_held"]) for st in ps) if ps else ""))
        if not ps:
            cand = [st for st in tries if st["side"] == SIDES[sd] and st["tune"]["trades"] > 0 and np.isfinite(st["lift_ci"][0])]
            if cand:
                c = max(cand, key=lambda st: st["lift_ci"][0])
                P("     closest: %s day %d - lift %.2f [%.2f-%.2f]; failed: %s" % (c["set"], c["k"], c["lift"], c["lift_ci"][0], c["lift_ci"][1],
                                                                             "; ".join(c["why"])))
    P("  (with %d tries a side, about 1 in 40 sets of pure noise clears a plain 95%% interval - hence the guard: the bound widened to z = %.2f)" % (
        ntry, S.zfam))
    P("")
    # ---------------- 6 method
    P("6 HOW IT WAS MEASURED")
    for ln in METHOD:
        P("  " + ln)
    # ---------------- 0 the answer (at the top)
    top = []; Q = top.append
    Q("0 THE ANSWER - in plain words. Does a monthly CE / PE opened in the first 1-3 days of a series and closed at expiry-week Monday beat")
    Q("  random picks? Picked on the tuning months only (%s), then shown UNCHANGED on the held-out last 6 months; CE and PE judged separately." % (
        "%d series" % int(tu.sum())))
    for sd in (0, 1):
        st = best[sd]
        Q("")
        Q("  %s - %s:" % (SIDES[sd], "buy calls on shares expected to rise" if sd == 0 else "buy puts on shares expected to fall"))
        if st is None:
            Q("    THE FIRST-DAYS SET THAT BEATS RANDOM: none does. None of the %d %s tries passed every rule - do not trade the monthly %s idea" % (
                ntry, SIDES[sd], SIDES[sd]))
            Q("    on these signals. For scale, every share the %s way at the close of day 3:" % SIDES[sd])
            a = S.baseline(sd, 3, tu); b = S.baseline(sd, 3, he)
            J["answer"][SIDES[sd]] = {"set": None, "verdict": "none does", "all_d3": {"tune": a, "held": b}}
            Q("      %-30s %-34s %-34s" % ("", "tuning", "held-out (last 6 months)"))
            ans_rows(Q, a, b, None)
        else:
            Q("    THE FIRST-DAYS SET THAT BEATS RANDOM: %s" % setlabel(st))
            for p_ in st["parts"]:
                Q("      %s = %s" % (p_, DESC[p_]))
            Q("      %-30s %-34s %-34s" % ("", "tuning", "held-out (last 6 months)"))
            ans_rows(Q, st["tune"], st["held"], st)
            J["answer"][SIDES[sd]] = {"set": st["set"], "parts": st["parts"], "k": st["k"], "verdict": "PASS", "stats": st}
    Q("")
    for sd in (0, 1):
        si = SETNAME.index(PLAN_SET)
        pl = [st for st in tries if st["side"] == SIDES[sd] and st["set"] == PLAN_SET and st["k"] == 3][0]
        Q("  THE PLAN'S OWN %s RULE (A3: %s, day 3): %d trades (%.1f a month), hit %s against random %s, lift %s [%s-%s], held-out lift %s - %s" % (
            SIDES[sd], "long build-up + rollover above its average + a top sector" if sd == 0 else "short build-up + rollover + a bottom sector",
            pl["tune"]["trades"], pl["tune"]["tpm"] if np.isfinite(pl["tune"]["tpm"]) else 0, pct(pl["tune"].get("hit")), pct(pl["rand_hit"]),
            f1(pl["lift"], "%.2f"), f1(pl["lift_ci"][0], "%.2f"), f1(pl["lift_ci"][1], "%.2f"), f1(pl["lift_held"], "%.2f"),
            "PASS" if pl["pass"] else "FAIL (" + "; ".join(pl["why"]) + ")"))
        J["answer"]["plan_" + SIDES[sd]] = pl
        del si
    Q("")
    Q("  HONEST CAVEATS - read before using any of this:")
    Q("  - NO OPTION HISTORY: the store has no option prices. The naked option and the debit spread are PROXIES priced from the share's own")
    Q("    20-day realised volatility (premium ~ 0.4 x vol x sqrt(time left)); real premiums, bid-ask (4 legs for a spread) and lot sizes differ.")
    Q("  - IV CHANGES ARE NOT SEEN: the proxy holds volatility fixed. IV falling after results / events, or rising in a sell-off, changes real")
    Q("    option prices in ways this study cannot measure - even a PASS is optimistic.")
    Q("  - SURVIVORSHIP: only today's %d F&O shares are in the store. Shares that left F&O, merged or collapsed in these years are missing," % nsh_data)
    Q("    so every number here (baselines included) looks better than a trader would have got.")
    Q("  - The day-k OI is NSE's end-of-day number (summed over expiries); at 15:20 Kite's live OI is close but not the same. Rollover and")
    Q("    build-up are proxies from summed OI. Results / ex-dates are not filtered (no event calendar in the store). No costs or slippage.")
    Q("  - %d tries per side: a pass also needs the lift bound widened for that many tries (the guard), the held-out months and the half-years -" % ntry)
    Q("    a set that fails any of them is treated as luck.")
    Q("")
    out[TOP:TOP] = top
    P("\n(%.1f min · every candidate trade is kept in %s/seriesstudy_trades.npz)" % ((time.time() - t0) / 60, STORE))
    J["meta"] = {"store": STORE, "first": str(first), "last": str(last), "series_used": len(used_ser), "tuning_series": int(tu.sum()),
                 "heldout_series": int(he.sum()), "shares": nsh_data, "trades": int(len(T)), "tries_per_side": ntry,
                 "tries_total": 2 * ntry, "sets": SETNAME, "singles": list(SINGLES), "desc": DESC, "halves": [O.HNAME[h] for h in S.halves],
                 "years": args.get("years"), "sectors": secs, "open_series": open_}
    return "\n".join(out), J


def brow(a):
    if not a.get("trades"):
        return "%-44s" % "no trades"
    return "%5.1f %5s %6s %6s %6s %6s" % (a["tpm"], pct(a["hit"]), sgn(a["move_med"]), sgn(a["spread_med"], "%+.0f%%"),
                                          sgn(a["naked_med"], "%+.0f%%"), sgn(a["mae_med"]))


def ans_rows(Q, a, b, st):
    def cell(x, key):
        if not x.get("trades"):
            return "no trades"
        if key == "tpm":
            return "%.1f (%d trades in %d months)" % (x["tpm"], x["trades"], x["series"])
        if key == "hit":
            return pct(x["hit"])
        if key == "move":
            return "%s (mean %s)" % (sgn(x["move_med"]), sgn(x["move_mean"]))
        if key == "spread":
            return "%s (mean %s)" % (sgn(x["spread_med"], "%+.0f%%"), sgn(x["spread_mean"], "%+.0f%%"))
        if key == "naked":
            return "%s (hit %s)" % (sgn(x["naked_med"], "%+.0f%%"), pct(x["naked_hit"]))
        if key == "worst":
            w = x["worst"]
            return "%s %s %s (spread %s)" % (w["share"], dday((dt.date.fromisoformat(w["entry"]) - dt.date(1970, 1, 1)).days).strftime("%d %b %y"),
                                             sgn(w["move"]), sgn(w["spread"], "%+.0f%%"))
        if key == "wm":
            w = x["worst_month"]
            return "%s series: %d trades, avg %s" % (w["series"], w["trades"], sgn(w["spread_avg"], "%+.0f%%"))
    Q("      %-30s %-34s %-34s" % ("trades a month", cell(a, "tpm"), cell(b, "tpm")))
    if st:
        Q("      %-30s %-34s %-34s" % ("hit rate (spread proxy > 0)", "%s vs random %s" % (cell(a, "hit"), pct(st["rand_hit"])),
                                       "%s vs random %s" % (cell(b, "hit"), pct(st["rand_hit_held"]))))
        Q("      %-30s %-34s %-34s" % ("lift over random", "%.2f [95%%: %.2f-%.2f, guard %.2f]" % (st["lift"], st["lift_ci"][0], st["lift_ci"][1],
                                                                                        st["lift_adj"]), f1(st["lift_held"], "%.2f")))
    else:
        Q("      %-30s %-34s %-34s" % ("hit rate (spread proxy > 0)", cell(a, "hit"), cell(b, "hit")))
    Q("      %-30s %-34s %-34s" % ("median share move its way", cell(a, "move"), cell(b, "move")))
    Q("      %-30s %-34s %-34s" % ("median debit spread result", cell(a, "spread"), cell(b, "spread")))
    Q("      %-30s %-34s %-34s" % ("median naked option result", cell(a, "naked"), cell(b, "naked")))
    Q("      %-30s %-34s %-34s" % ("worst trade (share move)", cell(a, "worst"), cell(b, "worst")))
    Q("      %-30s %-34s %-34s" % ("worst month (avg spread)", cell(a, "wm"), cell(b, "wm")))


METHOD = (
    "THE SERIES: onsetstudy.expiry_flags on NIFTY's market days (last Thursday of the month to Aug 2025, last Tuesday from Sep 2025, a holiday",
    "  moves the expiry to the market day before). A series runs from the day after one expiry (day 1) to the next expiry. Only series with",
    "  both expiries in the store are studied. The check compares each expiry with the next day's change in the summed futures OI of every",
    "  symbol present on both days: expiring contracts vanish, so the summed OI should drop then more than on any other day of the month.",
    "ENTRY / EXIT: the close of day 1, 2 or 3 (a share needs a full session that day - onsetstudy.prep's rules: previous day present, no",
    "  split jump, listed in F&O). Exit at the close of the Monday of the expiry week (the market day before if that Monday is a holiday;",
    "  never the expiry day itself). A trade with an unadjusted split / bonus between entry and exit is dropped.",
    "SIGNALS at the close of the entry day, from that day and earlier only. Prices on a log scale so the PE mirror is exact. Build-up: the",
    "  price since the expiry close (day 0) and the share's OI since day 0 against the median OI change of all F&O shares that day (the",
    "  expiry drop hits everyone; a share keeping more OI than the market is building). Rollover proxy: OI on day 1 / OI the day before the",
    "  expiry, against the share's own last 6 series, split into thirds across the shares of that series. Sector: median move of its shares",
    "  over the previous series (expiry to expiry), ranked; top 3 of 9+ sectors (top third when fewer); breadth = share of members up.",
    "  LOOSE sectors.json buckets ('other', 'misc', ...) get no sector signals. RSI(14) Wilder on daily closes; 20 / 50-day averages",
    "  (geometric); NIFTY against its 50-day average. No signals within %d rows after a split jump (the averages would mix units)." % SPLIT_LOOK,
    "OUTCOMES: move = (exit / entry - 1) for CE, (1 - exit / entry) for PE. MAE = the worst daily low (CE) / high (PE) after entry up to the",
    "  exit, against the entry. Naked option = (0.5 x move - (P0 - P1)) / P0, floored at -100%%: P0 = 0.4 x vol x sqrt(days to expiry / 252)",
    "  at entry, P1 the same at the exit, vol = 20-day realised volatility (at least %d%% a year). Debit spread = a debit of 0.55 x P0 and a" % int(RV_FLOOR * 100),
    "  width of 1.8 x the debit, valued at its intrinsic value at the exit: result between -100%% and +%d%% of the debit (the time value" % int(SPREAD_CAP * 100),
    "  left 1-3 days before expiry is ignored - slightly harsh on losers). HIT = the spread result above 0. Equal money per trade.",
    "BASELINES: ALL = every share the same side and day; TOP = the shares of the previous series' top sector (PE: bottom). RANDOM = for every",
    "  trade a random share of the same series, entry day and side; its hit count over 10,000 draws is drawn as the exactly equivalent",
    "  binomial count per series. LIFT = the set's hits / the random picks' expected hits; its 95% interval resamples whole months (series)",
    "  2,000 times (onsetstudy.boot). p = the share of the 10,000 random draws that hit as often as the set.",
    "THE GUARD (added to the design's PASS rule): the lift's lower bound with the interval widened for the number of tries on that side",
    "  (Bonferroni on the log lift, the month-bootstrap's standard error): with ~93 tries a plain 95% interval lets pure noise pass.",
    "TUNING / HELD-OUT: held-out = series starting in the last 6 months of the store (onsetstudy's cut); tuning = series that end before",
    "  it; a series spanning the cut is used in neither. Half-years count only with 3+ series; a set needs 3+ trades in one to hold there.",
)


# ------------------------------------------------------------------ commands ------------------------------------------------------------------
def check():
    print("store: %s" % STORE)
    if not os.path.isdir(MIN_DIR) or not os.path.exists(os.path.join(MIN_DIR, "NIFTY.npz")):
        print("no minute store / NIFTY.npz yet (%s) - run histstore.py get first" % MIN_DIR); return
    names = O.setup()
    print("minute files: %d shares · NIFTY %d market days · %s -> %s (%.1f years)" % (len(names), O.G, dday(O.CAL[0]), dday(O.CAL[-1]), O.G / 248.0))
    SER, E, open_ = series_calendar()
    print("monthly expiries in the store: %d · complete series: %d%s" % (len(E), len(SER),
                                                                      " · open series from %s (no exit yet)" % open_["day1"] if open_ else ""))
    chk, note = oi_check(E)
    if note:
        print("OI check: " + note)
    for c in chk:
        print("  expiry %s %s · next-day summed OI %s · %s" % (c["wd"], c["expiry"], f1(c["drop"], "%+.1f%%"), c["status"]))
    for s in SER:
        print("  series %-8s day 1 %s · day 3 %s · exit %s (expiry %s)" % (s["label"], dday(O.CAL[s["e0"] + 1]),
                                                                       dday(O.CAL[s["days"][2]]) if s["days"][2] >= 0 else "-",
                                                                       dday(O.CAL[s["x"]]), dday(O.CAL[s["e1"]])))
    print("NSE daily futures file: %d days · %d symbols%s" % (len(O.FODAYS), len(O.FOD), (" · renamed: " + ", ".join(O.ALIAS_USED)) if O.ALIAS_USED else ""))
    secs = [k for k in O.SEC if not k.startswith("_")]
    print("sectors: %d usable (%s)%s" % (len(secs), ", ".join("%s %d" % (k, len(O.SEC[k])) for k in sorted(secs)),
                                         (" · loose buckets ignored: " + ", ".join(O.LOOSE_SEC)) if O.LOOSE_SEC else ""))
    print("nothing was run (python3 seriesstudy.py run)")


def run(args):
    t0 = time.time()
    if not os.path.exists(os.path.join(MIN_DIR, "NIFTY.npz")):
        print("no store yet - run histstore.py get first"); return
    try:
        os.nice(10)
    except Exception:
        pass
    names = O.setup(args.get("years"))
    nw = args.get("workers") or max(1, min(4, (os.cpu_count() or 2) - 1))
    print("=== the monthly series study · %d shares · %d market days (%s -> %s) · %d workers · NSE file %d days" % (
        len(names), O.G, dday(O.CAL[0]), dday(O.CAL[-1]), nw, len(O.FODAYS)), flush=True)
    D = {}
    if nw == 1:
        for s in names:
            D[s] = load_share(s)
    else:
        import multiprocessing as mp
        with mp.get_context("fork").Pool(nw) as pool:
            for s, d in zip(names, pool.imap(load_share, names, chunksize=4)):
                D[s] = d
    nsh = sum(1 for v in D.values() if v)
    print("  daily bars from the minute files · %d shares · %.0f s" % (nsh, time.time() - t0), flush=True)
    R, SER, E, open_, secs, sid = build(names, D)
    chk, note = oi_check(E)
    print("  %d series · %d candidate rows · %d trades · %.0f s" % (len(SER), len(R), int(R["ok"].sum()), time.time() - t0), flush=True)
    if not int(R["ok"].sum()):
        print("no trades - the store is too short for a monthly study (it needs 3+ complete series and 50 days of history)"); return
    S = Study(R, SER, names)
    rep, J = report(S, SER, E, open_, chk, note, secs, names, nsh, t0, args)
    print(rep)
    fn = os.path.join(STORE, "seriesstudy_report.txt")
    open(fn, "w").write(rep + "\n")
    json.dump(J, open(os.path.join(STORE, "seriesstudy.json"), "w"), default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o), indent=1)
    np.savez_compressed(os.path.join(STORE, "seriesstudy_trades.npz"), rows=R, names=np.array(names), singles=np.array(SINGLES),
                        sets=np.array(SETNAME), set_masks=SMASK, days=O.CAL, sectors=np.array(secs if secs else [""]), share_sector=sid,
                        series=np.array([[s["e0"], s["e1"], s["x"]] + s["days"] for s in SER], np.int64).reshape(-1, 6),
                        tuning=S.tune, heldout=S.held)
    print("saved: %s (+ seriesstudy.json, seriesstudy_trades.npz)" % fn)
    return S, J


def parse(a):
    args = {}
    i = 0
    while i < len(a):
        if a[i] == "--years":
            args["years"] = float(a[i + 1]); i += 2
        elif a[i] == "--workers":
            args["workers"] = int(a[i + 1]); i += 2
        elif a[i] == "--force":
            args["force"] = True; i += 1
        else:
            i += 1
    return args


if __name__ == "__main__":
    a = sys.argv[1:] or ["check"]
    if a[0] == "check":
        check()
    elif a[0] == "run":
        args = parse(a[1:])
        if market_hours() and not args.get("force"):
            print("it is market hours (09:00-15:35 on a weekday) - GIR needs the CPUs. Run it after 15:35, or add --force."); sys.exit(1)
        run(args)
    else:
        print(__doc__)
