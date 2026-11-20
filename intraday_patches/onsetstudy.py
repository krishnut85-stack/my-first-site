#!/usr/bin/env python3
"""onsetstudy.py - READ ONLY (changes nothing in GIR, sends nothing, fetches nothing, orders nothing). HOW A CE OR PE MOVE STARTS, AND HOW
FAST GIR MUST REACT - over every day in the 3-5 year store that histstore.py made
(Rama, 19 Nov: "check the 5-year data: how the PE or CE moves break, and how fast the AI needs to react to give the early warning, the alarm
and the card"). This is the "movestudy" the expert pool agreed (quant, F&O dealer, sector-first options buyer, HFT trader).

WHY: on 18 Nov 53 F&O shares moved 2%+ and the new engine's cards caught 0 BEFORE the move, 9 late and missed 43 (the old system: 35 before,
18 late, 0 missed). It waited for the sector to be CONFIRMED, and its main trigger was the day-LOW break (1,018 times against 4 for the
day-high break), so it was PE only. This study measures, from the minute candles of every F&O share over the years, CE and PE alike:
  1 THE MOVES     every share-day that ran 1.5 / 2 / 3% from the open (and from yesterday's close), up and down separately: when it really
                  started (the ONSET), how fast it went (minutes to a quarter / half of the move, to +1% / +2%, to the peak), gap days apart
  2 THE SIGNALS   about 35 early-warning signals and fixed combinations (opening-range breaks, day-high / day-low breaks, yesterday's high /
                  low, VWAP reclaim / loss, volume surges, strength against the sector and NIFTY, the sector's breadth FORMING or CONFIRMED,
                  gap-and-hold, yesterday's futures build-up), every one with its CE and PE mirror, each read at a minute's close from
                  that day's minutes up to then only (and earlier days)
  3 THE GRADES    each signal against each move: BEFORE (by the onset + 2 min, before a quarter is done), EARLY (before half is done), LATE,
                  MISSED; how much of the move was still left; +1% before -0.6% within 60 min against random minutes (the lift);
                  false alarms; how many rings a day and in any 15 minutes
  4 REACTION      the same entry 0 / 1 / 2 / 3 / 5 / 10 / 15 / 20 / 30 minutes later: how much is lost a minute, how often it is already a
                  chase, and the LATENCY BUDGET - the longest the data + the AI + the phone may take while the entry still keeps 90% of what an
                  entry at once gets, measured four ways (the move left to 15:10, the best move in 60 min, +1% before -0.6% in 60 min, the
                  60-min option proxy), per side and for the fast moves; a budget that never breaks prints ">= 30 (longest tested)"
  5 THE VERDICT   signal sets that pass every rule (BEFORE+EARLY at least the old system's worst day, rings within 50 a day / 6 in 15 min,
                  CE as good as PE, above random in 5 of 6 half-years) - picked on the tuning days only (all but the last 6 months), then
                  shown UNCHANGED on the last 6 months (held out); 18 Nov and 16 Nov are replayed INSIDE the held-out part only, on the old
                  scorecard's own population (shares whose close moved 2%+ on the previous close), and never decide which set is picked
  0 THE ANSWER    a short summary in plain words at the top, CE and PE separately: how many 2% moves start at 09:15 (open-drive) and how
                  many of those still leave time to warn (a quarter done only at / after 09:30, a late breakout); the EARLY WARNING (BEFORE on
                  the other moves + graded by timing only on the open-drive ones: before P25, by the breakout for non day-high-break sets);
                  THE ALARM / CARD only when a set has an edge on that side (B+E >= 25%, lift > 1.2 with its 95% interval by day above 1.0,
                  100+ fires) - otherwise "no alarm with an edge" and no reaction budget; the reaction budget against random (over every
                  alarm) and on the caught moves; the move left both ON THE MOVES IT CAUGHT and OVER EVERY ALARM; the rings a day and in the
                  busiest 15 min for the early warning, the alarm and both together

  python3 onsetstudy.py check                            what is in the store: shares, days, how many shares cover each half-year, the NSE
                                                         file, sectors - does no work
  python3 onsetstudy.py run                              the whole study, every share, every day in the store
  python3 onsetstudy.py run --years 3                    only the last 3 years
  python3 onsetstudy.py run --shares SBIN,TITAN          only these shares (their sectors are still read in full, for the breadth)
  (add --force to run during market hours - by default it refuses between 09:00 and 15:35 on a weekday, so GIR keeps the CPUs)
WHILE histstore.py IS EXTENDING THE STORE FROM 3 TO 5 YEARS: wait until it has finished (run "check": every half-year should show about the same
number of shares), or run with --years 3. A store where some shares have 5 years and others 3 mixes two universes; the report warns about it.

It reads only the store: STORE/min/SYM.npz (minute candles ts,o,h,l,c,v), STORE/fo_daily.json (NSE's daily futures OI) and
STORE/sectors.json (share -> sector). STORE is /root/hist, or the folder in the GIR_HIST environment variable. It writes only into STORE
(the expert pool called this study "movestudy", so the outputs carry that name; the script keeps its file name onsetstudy.py):
  movestudy_report.txt     the report in plain words (also a dated copy movestudy_DATE.txt)
  movestudy.json           every number in the report
  movestudy_fires.npz      every first fire of every signal (with its outcome) and every move (with its grade per signal), for later study
About 4-6 minutes on ~220 shares x ~1250 days on a 4-CPU box (3 workers; measured on a random-walk store of that size), about 2-3 GB of
memory at the peak. It uses numpy only. Run it after 15:35, like longtest.py:   cd /home/globalbot/intraday && python3 onsetstudy.py run"""
import os, sys, json, time, calendar, datetime as dt
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as swv

STORE = os.environ.get("GIR_HIST", "/root/hist")
MIN_DIR = os.path.join(STORE, "min")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NM = 375                         # minutes 09:15 .. 15:29 in a day's grid
T = 356                          # the minutes the study reads: 0 = 09:15 ... 355 = 15:10 (out by 15:10)
END = 355
TF = 316                         # a signal may fire up to 14:30 (minute 315)
DS = (0, 1, 2, 3, 5, 10, 15, 20, 30)     # the reaction delays tested, in minutes
TM = TF + max(DS)                # outcome tables for minutes 0..345 (a fire at 14:30 entered 30 minutes late)
TIERS = (1.5, 2.0, 3.0)
BEDGE = (0, 30, 105, 225, 316)
BNAME = ("09:15-09:45", "09:45-11:00", "11:00-13:00", "13:00-14:30")
LOOK = 15                        # a fire up to 15 min before a move's base still counts for that move (earlier: it belonged to another swing)
COOL = 30                        # the re-arm version: the same signal, share and side may fire again only 30 min later
WMEM = 10                        # a combination fires when all its parts were on within the last 10 minutes
HOLD = 183                       # the last 6 months are held out
MIN_LAT = 20                     # the reaction-time table needs at least this many caught fires
TGT1, TGT2, STOP, FLAT = 1.0, 2.0, 0.6, 0.5
PREM, DELTA, COSTS = 2.5, 0.5, (1.5, 3.0)       # the option proxy: an at-the-money premium of ~2.5% of the share, delta 0.5
ANCHOR = {"2026-11-18": (35, 53), "2026-11-16": (22, 53)}    # the old system's BEFORE count / the 2%+ movers on those days (run_report.py's
                                 # own definition: close 2%+ on the previous close, gap opens at 09:16 counted BEFORE - NOT the study's BEFORE)
YEARS_MIN = 22.0 / 53.0          # over the years BEFORE+EARLY on 2% moves must be at least the old system's worst day share
BTOL = 1e-3                      # the tolerance on the breadth thresholds (breadth is a share of 4..40 others: steps of 0.025 or more)
FLOOR_BE, FLOOR_N = 0.25, 30     # a set shown as a reference when nothing passes must catch 25%+ (BEFORE+EARLY) and 30+ moves
ALARM_LIFT, ALARM_CI, ALARM_MIN_FIRES = 1.2, 1.2, 100   # section 0 names an ALARM on a side only with B+E >= FLOOR_BE, a lift > 1.2 whose
                                 # 95% interval (bootstrap by day) stays above 1.2 (strict: ~150 set x side tries), and 100+ first fires on that side (tuning days)
SPLIT_JUMP, SPLIT_SKIP = 0.20, 20  # an open 20%+ off the last close looks like a split / bonus: that day and the share's next 20 days are left
                                 # out (the 20-day volume history would mix pre- and post-split volume, the price history pre- and post-split prices)
ALIAS = {"ETERNAL": ("ZOMATO",), "TMPV": ("TATAMOTORS",), "UNITDSPR": ("MCDOWELL-N",), "GMRAIRPORT": ("GMRINFRA",),
         "SAMMAANCAP": ("IBULHSGFIN",), "ADANIENSOL": ("ADANITRANS",), "SHRIRAMFIN": ("SRTRANSFIN",), "LTIM": ("LTI",),
         "ZYDUSLIFE": ("CADILAHC",), "MOTHERSON": ("MOTHERSUMI",), "LTF": ("L&TFH",), "PVRINOX": ("PVR",)}   # renamed F&O shares: NSE's older daily files carry the old symbol
LOOSE = ("other", "misc", "divers", "conglomer")              # sectors.json buckets of unrelated shares: no breadth / RS over them
TT = np.arange(T)
NOT_SHARES = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50", "SENSEX", "BANKEX"}

SINGLES = ("ORB5", "ORB15", "DHB", "PDH", "VWR2", "VWR3", "RVOL", "RVOL5", "RS15", "RS30", "FORM", "CONF", "GAPHOLD")
EVPART = {"ORB5", "ORB15", "DHB", "PDH", "VWR2", "VWR3", "GAPHOLD"}          # in a combination these count by their break, the rest by their state
COMBOS = (("C01", ("ORB15", "RVOL", "RS15", "FORM")), ("C02", ("VWR2", "RS15", "BTURN")), ("C03", ("GAPHOLD", "OIB")),
          ("C04", ("DHB", "RVOL", "FORM")), ("C05", ("ORB5", "RVOL")), ("C06", ("ORB15", "RS15")), ("C07", ("DHB", "RS30")),
          ("C08", ("VWR2", "RVOL")), ("C09", ("RS15", "FORM")), ("C10", ("RS15", "RVOL5")), ("C11", ("PDH", "RVOL")),
          ("C12", ("ORB5", "FORM")), ("C13", ("DHB", "RVOL", "RS15")), ("C14", ("RS30", "FORM")), ("C15", ("ORB15", "OIB")),
          ("C16", ("VWR3", "RS15")), ("C17", ("RVOL5", "FORM")), ("C18", ("GAPHOLD", "RVOL")), ("C19", ("ORB15", "RVOL", "CONF")),
          ("C20", ("DHB", "RS15", "OIB")))
UNIONS = (("U1", ("C01", "C02", "C04", "C09")), ("U2", ("C05", "C06", "C10", "C13")), ("U3", ("RS15", "FORM")),
          ("U4", tuple(c for c, _ in COMBOS)))
SETS = SINGLES + tuple(c for c, _ in COMBOS) + tuple(u for u, _ in UNIONS)
NS = len(SETS)
NSM = 2 * NS                     # every set twice: 0 = the first fire of the day only, 1 = re-arm after 30 min
DESC = {"ORB5": "opening 5-min range break (CE above its high, PE below its low), 09:20-10:00",
        "ORB15": "opening 15-min range break, 09:30-10:45",
        "DHB": "day-high break (CE) / day-low break (PE), the old extreme 15+ min old, from 09:30",
        "PDH": "yesterday's high break (CE) / yesterday's low break (PE)",
        "VWR2": "VWAP reclaim (CE) / loss (PE): 10 of 15 bars on the wrong side, then 2 closes over",
        "VWR3": "VWAP reclaim / loss with 3 closes over",
        "RVOL": "the day's volume so far 2x a normal day's by this minute, on its side of VWAP",
        "RVOL5": "the last 5 minutes' volume 3x normal for this minute, on its side of VWAP",
        "RS15": "15 min: +0.5% better than its sector's median and +0.6% better than NIFTY (PE: worse)",
        "RS30": "30 min: +0.75% better than its sector and +1.0% better than NIFTY (PE: worse)",
        "FORM": "its sector FORMING: share above VWAP rose 0.30 in 15 min, now 0.5-0.8, sector still under +0.75%",
        "CONF": "its sector CONFIRMED: 80%+ above VWAP and the median +0.75% (the new engine's rule)",
        "GAPHOLD": "gap of 1%+ held at 09:30 (beyond the open, never back past half the gap)",
        "BTURN": "breadth turn (share of the sector on its side of VWAP rose 0.30 in 15 min)",
        "OIB": "yesterday's futures build-up its way (LB / SC for CE, SB / LU for PE)"}
for _c, _p in COMBOS:
    DESC[_c] = " + ".join(_p)
for _u, _p in UNIONS:
    DESC[_u] = "any of " + " | ".join(_p)
_CP = dict(COMBOS)
_DHBC = {c for c, p in COMBOS if "DHB" in p}
DHBSETS = {"DHB"} | _DHBC | {u for u, mem in UNIONS if set(mem) & _DHBC}   # sets built on the day-high / low break = the BRK label's own
                                 # shape: never graded against BRK (they would be graded against themselves)
GRN = ("MISSED", "BEFORE", "EARLY", "LATE", "PRIOR")       # PRIOR = rang only for an earlier swing (counts as missed)

FDT = np.dtype([("set", "u1"), ("share", "i2"), ("g", "i2"), ("side", "i1"), ("t", "i2"), ("tag", "u1"), ("oi", "i1"), ("fl", "u1"),
                ("hd", "u2"), ("ch", "u2"), ("mfe", "f2"), ("tt1", "i2"), ("tt2", "i2"), ("ml", "f2", (len(DS),)), ("r0", "f2"), ("r2", "f2"),
                ("mf", "f2", (len(DS),)), ("rd", "f2", (len(DS),)),      # by delay d: the best move in 60 min, the 60-min trade result
                ("bh", "f2"), ("bf", "f2"), ("gr", "i1"), ("lead", "i2"), ("ampo", "f2"), ("bp", "f2")])
MDT = np.dtype([("share", "i2"), ("g", "i2"), ("side", "i1"), ("ampo", "f4"), ("amppc", "f4"), ("gap", "i1"), ("onset", "i2"), ("tb", "i2"),
                ("tp", "i2"), ("p25", "i2"), ("p50", "i2"), ("t1", "i2"), ("t2", "i2"), ("bp", "f4"), ("fast", "i1"), ("brk", "i2"),
                ("cc", "f4")])          # brk = the breakout minute (timing label) · cc = the close (15:29) on yesterday's close, % its way

# run context (set by setup(); the workers inherit it by fork)
CAL = np.zeros(0, np.int64); GIDX = {}; G = 0; GLO = 0; NIFC = None; NKIND = None; EXP = None; HALF = None; HNAME = []; YEAR = None
TRAIN = None; FOD = {}; FODAYS = set(); OF = {}; SEC = {}; ONLY = None; SHIDX = {}; ALIAS_USED = []; LOOSE_SEC = []


def dday(n):
    return dt.date(1970, 1, 1) + dt.timedelta(days=int(n))


def hm(m):
    m = int(m)
    return "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)


def grid(z):
    """minute file -> [(day number, O0, C[375], H[375], L[375], V[375], real minutes, first real minute)] - gaps filled with the last price
    (longtest.py's grid). Minutes BEFORE the day's first real candle hold its OPEN (never a later close: no look-ahead) and are marked not
    tradable by `first` (no signal may fire there). Weekend days are kept: a full Saturday session (the 1 Feb 2025 budget day) passes the
    300-minute rule like any day, short special sessions (Muhurat, DR drills) do not."""
    ts = np.asarray(z["ts"], np.int64); loc = ts + 19800
    dn = loc // 86400; m = (loc % 86400) // 60 - 555
    ok = (m >= 0) & (m < NM)
    dn, m = dn[ok], m[ok]
    o, h, l, c, v = (np.asarray(z[k_], np.float64)[ok] for k_ in ("o", "h", "l", "c", "v"))
    out = []
    if not len(dn):
        return out
    cut = np.nonzero(np.diff(dn))[0] + 1
    for a, b in zip(np.r_[0, cut], np.r_[cut, len(dn)]):
        day = int(dn[a])
        C = np.full(NM, np.nan); H = np.full(NM, np.nan); L = np.full(NM, np.nan); V = np.zeros(NM)
        mm = m[a:b]
        C[mm] = c[a:b]; H[mm] = h[a:b]; L[mm] = l[a:b]; V[mm] = v[a:b]
        real = int(np.isfinite(C).sum())
        first = int(np.argmax(np.isfinite(C)))
        o0 = float(o[a])
        C[:first] = o0; H[:first] = o0; L[:first] = o0
        idx = np.where(np.isfinite(C), np.arange(NM), -1)
        np.maximum.accumulate(idx, out=idx)
        miss = ~np.isfinite(H)
        C = C[idx]; H[miss] = C[miss]; L[miss] = C[miss]
        out.append((day, o0, C, H, L, V, real, first))
    return out


# ------------------------------------------------------------------ the calendar, NIFTY, expiry, half-years ------------------------------------------------------------------
def nifty_days():
    """NIFTY's days (like longtest.py): {day: (open, C[375], kind)} kind 0 up (close +0.6% on yesterday), 1 down, 2 mixed"""
    z = np.load(os.path.join(MIN_DIR, "NIFTY.npz")); out = {}; pc = None
    for day, o0, C, H, L, V, real, first in grid(z):
        if real >= 300 and pc:
            dc = (C[-1] / pc - 1) * 100
            out[day] = (o0, C, 0 if dc >= 0.6 else 1 if dc <= -0.6 else 2)
        if real >= 300:
            pc = C[-1]
    return out


def expiry_flags(days):
    """the monthly stock F&O expiry: the last Thursday of the month until Aug 2025, the last Tuesday from Sep 2025 (NSE's change);
    a holiday moves it to the market day before. A month whose expiry lies after the last day in the store is not flagged (its expiry is
    not in the data yet - walking back from it would wrongly flag the store's last day)."""
    ds = [dday(x) for x in days]; pos = {d: i for i, d in enumerate(ds)}
    f = np.zeros(len(ds), bool)
    if not ds:
        return f
    lastd = max(ds)
    for y, m in sorted({(d.year, d.month) for d in ds}):
        last = dt.date(y, m, calendar.monthrange(y, m)[1])
        wd = 1 if (y, m) >= (2025, 9) else 3
        e = last - dt.timedelta(days=(last.weekday() - wd) % 7)
        if e > lastd:
            continue
        while e not in pos and e.month == m and e.day > 1:
            e -= dt.timedelta(days=1)
        if e in pos:
            f[pos[e]] = True
    return f


def setup(years=None, only=None):
    """the run context: the calendar (NIFTY's days), NIFTY's minutes, the day kinds, expiry, half-years, the train / held-out cut, the NSE file,
    the sectors"""
    global CAL, GIDX, G, GLO, NIFC, NKIND, EXP, HALF, HNAME, YEAR, TRAIN, FOD, FODAYS, OF, SEC, ONLY, SHIDX, ALIAS_USED, LOOSE_SEC
    N = nifty_days()
    CAL = np.array(sorted(N), np.int64); G = len(CAL)
    GIDX = {int(d): i for i, d in enumerate(CAL)}
    NIFC = np.stack([N[d][1] for d in CAL]) if G else np.zeros((0, NM))
    NKIND = np.array([N[d][2] for d in CAL], np.int8)
    EXP = expiry_flags(CAL)
    hl = ["%d H%d" % (dday(d).year, 1 if dday(d).month <= 6 else 2) for d in CAL]
    HNAME = sorted(set(hl)); HALF = np.array([HNAME.index(x) for x in hl], np.int16)
    YEAR = np.array([dday(d).year for d in CAL], np.int16)
    last = dday(CAL[-1]) if G else dt.date.today()
    GLO = 0
    if years:
        lo = last - dt.timedelta(days=int(round(365.25 * float(years))))
        GLO = int(np.searchsorted(CAL, (lo - dt.date(1970, 1, 1)).days))
    cut = (last - dt.timedelta(days=HOLD) - dt.date(1970, 1, 1)).days
    TRAIN = CAL <= cut
    try:
        J = json.load(open(os.path.join(STORE, "fo_daily.json")))
        FOD = J.get("d", {}); FODAYS = set(J.get("done", []))
    except Exception:
        FOD, FODAYS = {}, set()
    ALIAS_USED = []
    for new_, olds in ALIAS.items():                    # a renamed share: its days under the old symbol count as listed (and give the OI)
        if any(o_ in FOD for o_ in olds):
            mg = {}
            for o_ in olds:
                mg.update(FOD.get(o_, {}))
            mg.update(FOD.get(new_, {}))
            FOD[new_] = mg; ALIAS_USED.append("%s (was %s)" % (new_, "/".join(olds)))
    try:
        sec = json.load(open(os.path.join(STORE, "sectors.json")))
    except Exception:
        sec = {}
    OF = {x: k_ for k_, v in sec.items() for x in v}
    names = sorted(f[:-4] for f in os.listdir(MIN_DIR) if f.endswith(".npz") and f[:-4] not in NOT_SHARES)
    SHIDX = {s: i for i, s in enumerate(names)}
    SEC = {}
    LOOSE_SEC = sorted({k_ for k_ in sec if any(w in k_.lower() for w in LOOSE)})
    for s in names:
        k_ = OF.get(s)
        if not k_ or k_ in LOOSE_SEC:
            k_ = "_" + s                                  # no sector, or a bucket of unrelated shares: no breadth / RS for it
        SEC.setdefault(k_, []).append(s)
    ONLY = set(only) if only else None
    return names


# ------------------------------------------------------------------ one share: its days, VWAP, volume history, yesterday's OI ------------------------------------------------------------------
def load_rows(s):
    try:
        z = np.load(os.path.join(MIN_DIR, s + ".npz"))
        rows = [r for r in grid(z) if r[6] >= 200 and int(r[0]) in GIDX]     # market days only (NIFTY's calendar)
    except Exception:
        return None
    if not rows:
        return None
    return {"day": np.array([r[0] for r in rows], np.int64), "o0": np.array([r[1] for r in rows]), "C": np.stack([r[2] for r in rows]),
            "H": np.stack([r[3] for r in rows]), "L": np.stack([r[4] for r in rows]), "V": np.stack([r[5] for r in rows]),
            "real": np.array([r[6] for r in rows]), "first": np.array([r[7] for r in rows], np.int16)}


def prior_median(X, k=20, need=10):
    """row i -> the median of rows i-k .. i-1 (the share's earlier days only), NaN with fewer than `need` earlier days"""
    n = X.shape[0]
    pad = np.vstack([np.full((k, X.shape[1]), np.nan, np.float32), X.astype(np.float32)])
    W = swv(pad, k, axis=0)[:n]
    out = np.full(X.shape, np.nan, np.float32)
    for a in range(0, n, 200):
        out[a:a + 200] = np.median(W[a:a + 200], axis=2)
    for i in range(need, min(k, n)):
        out[i] = np.nanmedian(W[i], axis=1)
    out[:need] = np.nan
    return out


def prep(s, R, full=True):
    """-> the share's study days (real >= 300 minutes, a previous day, |open / yesterday - 1| < 20%, listed in F&O that day if NSE's file has
    the day, inside --years) with everything the signals need from that day and the days before"""
    day = R["day"]; C, H, L, V, o0 = R["C"], R["H"], R["L"], R["V"], R["o0"]
    g = np.array([GIDX.get(int(x), -1) for x in day], np.int64)
    # yesterday = the previous MARKET day (CAL), never just the previous row: if the share has no row for it, the day is skipped
    p1 = np.r_[False, (g[1:] == g[:-1] + 1) & (g[:-1] >= 0)]
    p2 = np.r_[False, p1[:-1]] & p1
    pc = np.where(p1, np.r_[np.nan, C[:-1, -1]], np.nan); ppc = np.where(p2, np.r_[np.nan, pc[:-1]], np.nan)
    pdh = np.where(p1, np.r_[np.nan, H[:-1].max(1)], np.nan); pdl = np.where(p1, np.r_[np.nan, L[:-1].min(1)], np.nan)
    fo = FOD.get(s) or {}
    dstr = [str(dday(x)) for x in day]
    listed = np.array([(x in fo) if x in FODAYS else True for x in dstr], bool)
    # a split / bonus not adjusted in the history: the open is 20%+ off the LAST close the share has (within 5 market days, so a missing
    # yesterday does not hide it). That day and the next SPLIT_SKIP rows are left out: their 20-day volume median (RVOL / RVOL5) and
    # yesterday's high / low would still be in pre-split units. When Kite's history is adjusted no such jump exists and nothing is dropped.
    with np.errstate(all="ignore"):
        lastc = np.r_[np.nan, C[:-1, -1]]
        near = np.r_[False, (g[1:] - g[:-1] <= 5) & (g[1:] > g[:-1]) & (g[:-1] >= 0)]
        jump = near & (np.abs(o0 / lastc - 1) >= SPLIT_JUMP)
    after = np.zeros(len(day), bool)
    for i in np.nonzero(jump)[0]:
        after[i:i + SPLIT_SKIP + 1] = True
    with np.errstate(all="ignore"):
        base_ok = (R["real"] >= 300) & np.isfinite(pc) & (np.abs(o0 / pc - 1) < SPLIT_JUMP) & (g >= GLO) & ~after
        valid = base_ok & listed
    vi = np.nonzero(valid)[0]
    Cv, Hv, Lv, Vv = C[vi], H[vi], L[vi], V[vi]
    tp_ = (Hv + Lv + Cv) / 3; cv = np.cumsum(Vv, 1)
    with np.errstate(all="ignore"):
        VW = np.where(cv > 0, np.cumsum(tp_ * Vv, 1) / np.maximum(cv, 1e-9), tp_)
    P = {"s": s, "g": g[vi], "o0": o0[vi], "pc": pc[vi], "pdh": pdh[vi], "pdl": pdl[vi], "C": Cv, "H": Hv, "L": Lv, "VW": VW,
         "real": R["real"][vi], "first": R["first"][vi], "unlisted": int((base_ok & ~listed).sum()), "base_n": int(base_ok.sum()),
         "splits": [str(dday(day[i])) for i in np.nonzero(jump)[0]], "split_drop": int((after & (g >= GLO)).sum())}
    if not full:
        return P
    cum = np.cumsum(V[:, :T], 1)
    mc = prior_median(cum)
    v5 = np.zeros((len(day), T)); cs = np.cumsum(np.c_[np.zeros(len(day)), V[:, :T]], 1)
    v5[:, 4:] = cs[:, 5:T + 1] - cs[:, 0:T - 4]
    m5 = prior_median(v5)
    with np.errstate(all="ignore"):
        rc = np.where(mc > 0, cum / mc, 0.0); r5 = np.where(m5 > 0, v5 / m5, 0.0)
    rc[~np.isfinite(rc)] = 0; r5[~np.isfinite(r5)] = 0; r5[:, :4] = 0
    P["rc"], P["r5"] = rc[vi], r5[vi]
    oi = np.zeros(len(vi), np.int8); oib = np.zeros(len(vi), np.int8)        # yesterday's (D-1) futures build-up: 1 LB 2 SB 3 SC 4 LU
    for j, i in enumerate(vi):
        if not p2[i] or dstr[i - 1] not in FODAYS:
            continue
        r = fo.get(dstr[i - 1])
        if not r or not np.isfinite(ppc[i]) or ppc[i] <= 0:
            continue
        base = float(r[0]) - float(r[1])
        if base <= 0:
            continue
        op = float(r[1]) / base * 100; pm = (pc[i] / ppc[i] - 1) * 100
        k_ = 1 if (pm >= 1 and op >= 5) else 2 if (pm <= -1 and op >= 5) else 3 if (pm >= 1 and op <= -5) else 4 if (pm <= -1 and op <= -5) else 0
        oi[j] = k_; oib[j] = 1 if k_ in (1, 3) else -1 if k_ in (2, 4) else 0
    P["oi"], P["oib"] = oi, oib
    return P


def stageA(P):
    """pass A: what the share gives its sector, every minute - the move from its open, its 15 / 30-min change, above / below its VWAP"""
    C = P["C"][:, :T]; VW = P["VW"][:, :T]; o0 = P["o0"]
    mvo = (C / o0[:, None] - 1) * 100
    c15 = np.zeros_like(C); c15[:, 15:] = (C[:, 15:] / C[:, :-15] - 1) * 100
    c30 = np.zeros_like(C); c30[:, 30:] = (C[:, 30:] / C[:, :-30] - 1) * 100
    return {"g": P["g"], "mvo": mvo.astype(np.float16), "ch15": c15.astype(np.float16), "ch30": c30.astype(np.float16), "ab": C > VW, "bl": C < VW}


def loo_median(X, k):
    """X (members, days, minutes), a member missing a day = NaN that day. -> for every member the median of the OTHER members (leave-one-out)"""
    n = X.shape[0]
    order = np.argsort(X, axis=0, kind="stable")                   # NaN sorts last
    S = np.take_along_axis(X, order, axis=0)
    rank = np.argsort(order, axis=0, kind="stable")
    m = k - 1
    jlo = np.clip((m - 1) // 2, 0, n - 2); jhi = np.clip(m // 2, 0, n - 2)
    gi = np.arange(X.shape[1])

    def R(j):
        a = S[j, gi]; b = S[j + 1, gi]
        return np.where(j[None, :, None] < rank, a[None], b[None])
    med = 0.5 * (R(jlo) + R(jhi))
    med[:, m < 1, :] = 0
    return med


def sector_loo(A):
    """pass A, the sector part: for every member and minute the other members' median move from the open, median 15 / 30-min change,
    and the share of them above (below) VWAP - each from minute data up to that minute only"""
    ms = list(A); n = len(ms)
    out = {s: {"mm": np.zeros((len(A[s]["g"]), T), np.float16), "m15": np.zeros((len(A[s]["g"]), T), np.float16),
               "m30": np.zeros((len(A[s]["g"]), T), np.float16), "bu": np.zeros((len(A[s]["g"]), T), np.float32),
               "bd": np.zeros((len(A[s]["g"]), T), np.float32), "m": np.zeros(len(A[s]["g"]), np.int16)} for s in ms}
    # the breadth (bu / bd) stays float32: float16(0.8) = 0.7998 would turn "80% of the others" into "not 80%"
    if n < 2:
        return out
    ga = np.concatenate([A[s]["g"] for s in ms])
    if not len(ga):
        return out
    lo, hi = int(ga.min()), int(ga.max()) + 1
    CH = max(8, int(3e6 // (n * T)))
    for a in range(lo, hi, CH):
        b = min(hi, a + CH); cb = b - a
        sl = {}
        ok = np.zeros((n, cb), bool)
        for j, s in enumerate(ms):
            i0, i1 = np.searchsorted(A[s]["g"], [a, b]); sl[s] = (i0, i1, A[s]["g"][i0:i1] - a)
            ok[j, sl[s][2]] = True
        k = ok.sum(0); m = k - 1
        if k.max() < 2:
            continue
        for key, okey in (("mvo", "mm"), ("ch15", "m15"), ("ch30", "m30")):
            X = np.full((n, cb, T), np.nan, np.float32)
            for j, s in enumerate(ms):
                i0, i1, gg = sl[s]; X[j, gg] = A[s][key][i0:i1]
            med = loo_median(X, k)
            for j, s in enumerate(ms):
                i0, i1, gg = sl[s]; out[s][okey][i0:i1] = med[j, gg]
        for key, okey in (("ab", "bu"), ("bl", "bd")):
            X = np.zeros((n, cb, T), np.float32)
            for j, s in enumerate(ms):
                i0, i1, gg = sl[s]; X[j, gg] = A[s][key][i0:i1]
            tot = X.sum(0)
            br = (tot[None] - X) / np.maximum(m, 1)[None, :, None]
            for j, s in enumerate(ms):
                i0, i1, gg = sl[s]; out[s][okey][i0:i1] = br[j, gg]
        for j, s in enumerate(ms):
            i0, i1, gg = sl[s]; out[s]["m"][i0:i1] = m[gg]
    return out


# ------------------------------------------------------------------ pass B: the signals (minute t's close, data 0..t only), CE and PE mirrors ------------------------------------------------------------------
def sh(x, k=1, fill=False):
    """x one minute (k minutes) later: out[:, t] = x[:, t-k]"""
    o = np.empty_like(x); o[:, :k] = fill; o[:, k:] = x[:, :-k]
    return o


def rising(st):
    return st & ~sh(st)


def recent(x, w=WMEM):
    """on at any minute in [t-w, t]"""
    cs = np.cumsum(x, 1, dtype=np.int32); r = cs.copy(); r[:, w + 1:] -= cs[:, :-(w + 1)]
    return r > 0


def sector_inputs(P, LO):
    nv = len(P["g"])
    if LO is None:
        z = np.zeros((nv, T), np.float32)
        return {"mm": z, "m15": z, "m30": z, "bu": z, "bd": z, "m": np.zeros(nv, np.int16)}
    return {k_: (LO[k_].astype(np.float32) if k_ != "m" else LO[k_]) for k_ in ("mm", "m15", "m30", "bu", "bd", "m")}


def signals(P, SI, d):
    """every signal's STATE and EVENT (the minute it switches on) for side d (+1 CE, -1 PE) -> (ST, EV), arrays (days, 356) of bools.
    Minute t uses that day's minutes 0..t, earlier days (volume history, yesterday's high / low / OI) and the sector and NIFTY up to t."""
    C = P["C"][:, :T]; H = P["H"][:, :T]; L = P["L"][:, :T]; VW = P["VW"][:, :T]; o0 = P["o0"]; pc = P["pc"]
    nv = C.shape[0]
    E, O_ = (H, L) if d > 0 else (L, H)                    # the extreme its way, the other one
    best = np.max if d > 0 else np.min; worst = np.min if d > 0 else np.max
    acc = np.maximum.accumulate if d > 0 else np.minimum.accumulate

    def beyond(a, b):
        return (a - b) * d > 0
    ST, EV = {}, {}
    win = lambda a, b: (TT >= a) & (TT <= b)
    with np.errstate(all="ignore"):
        st = beyond(C, best(E[:, :5], 1)[:, None]) & win(5, 45); EV["ORB5"] = rising(st); ST["ORB5"] = st
        st = beyond(C, best(E[:, :15], 1)[:, None]) & win(15, 90); EV["ORB15"] = rising(st); ST["ORB15"] = st
        RB = acc(E, axis=1); prev = sh(RB, 1, np.nan)
        newb = beyond(E, prev) | (TT == 0)[None, :]
        lastnew = np.maximum.accumulate(np.where(newb, TT, 0), 1)
        age = TT - sh(lastnew, 1, 0)
        EV["DHB"] = beyond(C, prev) & (age >= 15) & (TT >= 15); ST["DHB"] = EV["DHB"]
        lvl = P["pdh"] if d > 0 else P["pdl"]
        ab = beyond(C, lvl[:, None]); pre0 = beyond(o0, lvl)
        EV["PDH"] = ab & ~sh(ab, 1, False) & (TT >= 1); EV["PDH"][:, 0] = ab[:, 0] & ~pre0; ST["PDH"] = EV["PDH"]
        up = beyond(C, VW); dn = beyond(VW, C)
        CB = np.c_[np.zeros(nv, np.int32), np.cumsum(dn, 1, dtype=np.int32)]
        c2 = np.zeros((nv, T), np.int32); c2[:, 16:] = CB[:, 15:T - 1] - CB[:, 0:T - 16]
        c3 = np.zeros((nv, T), np.int32); c3[:, 17:] = CB[:, 15:T - 2] - CB[:, 0:T - 17]
        EV["VWR2"] = up & sh(up, 1) & ~sh(up, 2) & (c2 >= 10) & (TT >= 16); ST["VWR2"] = EV["VWR2"]
        EV["VWR3"] = up & sh(up, 1) & sh(up, 2) & ~sh(up, 3) & (c3 >= 10) & (TT >= 17); ST["VWR3"] = EV["VWR3"]
        st = (P["rc"] >= 2) & up; ST["RVOL"] = st; EV["RVOL"] = rising(st)
        st = (P["r5"] >= 3) & up & (TT >= 4); ST["RVOL5"] = st; EV["RVOL5"] = rising(st)
        m4 = (SI["m"] >= 4)[:, None]
        c15 = np.zeros_like(C); c15[:, 15:] = (C[:, 15:] / C[:, :-15] - 1) * 100 * d
        c30 = np.zeros_like(C); c30[:, 30:] = (C[:, 30:] / C[:, :-30] - 1) * 100 * d
        NC = NIFC[P["g"]][:, :T]
        n15 = np.zeros_like(C); n15[:, 15:] = (NC[:, 15:] / NC[:, :-15] - 1) * 100 * d
        n30 = np.zeros_like(C); n30[:, 30:] = (NC[:, 30:] / NC[:, :-30] - 1) * 100 * d
        st = (c15 - SI["m15"] * d >= 0.5) & (c15 - n15 >= 0.6) & m4 & (TT >= 15); ST["RS15"] = st; EV["RS15"] = rising(st)
        st = (c30 - SI["m30"] * d >= 0.75) & (c30 - n30 >= 1.0) & m4 & (TT >= 30); ST["RS30"] = st; EV["RS30"] = rising(st)
        br = SI["bu"] if d > 0 else SI["bd"]; mv = SI["mm"] * d
        turn = (br - sh(br, 15, 0.0) >= 0.30 - BTOL) & m4 & (TT >= 15)
        ST["BTURN"] = turn
        st = turn & (br >= 0.5 - BTOL) & (br <= 0.8 + BTOL) & (mv < 0.75); ST["FORM"] = st; EV["FORM"] = rising(st)
        st = (br >= 0.8 - BTOL) & (mv >= 0.75) & m4; ST["CONF"] = st; EV["CONF"] = rising(st)
        gap = (o0 / pc - 1) * 100 * d
        hold = beyond(worst(O_[:, :15], 1), pc + 0.5 * (o0 - pc))
        gh = (gap >= 1.0) & beyond(C[:, 14], o0) & hold
        EV["GAPHOLD"] = np.zeros((nv, T), bool); EV["GAPHOLD"][:, 14] = gh; ST["GAPHOLD"] = gh[:, None] & win(14, 14 + WMEM)
        ST["OIB"] = np.repeat((P["oib"] == d)[:, None], T, 1)
    trad = TT[None, :] >= P["first"].astype(np.int64)[:, None]     # before the share's first real candle of the day: not tradable
    for k_ in ST:
        ST[k_] = ST[k_] & trad
    for k_ in EV:
        EV[k_] = EV[k_] & trad
    for k_ in SINGLES:
        EV[k_] = EV[k_] & (TT < TF)
    return ST, EV


def build_sets(ST, EV):
    """the 13 single signals, the 20 combinations fixed before the run, the 4 unions -> one event array each (minute <= 14:30)"""
    R = {}
    out = {k_: EV[k_] for k_ in SINGLES}
    for nm, parts in COMBOS:
        st = None
        for p in parts:
            if p not in R:
                R[p] = recent(EV[p] if p in EVPART else ST[p])
            st = R[p] if st is None else (st & R[p])
        out[nm] = rising(st) & (TT < TF)
    for nm, mem in UNIONS:
        u = out[mem[0]].copy()
        for x in mem[1:]:
            u |= out[x]
        out[nm] = u
    return [out[k_] for k_ in SETS]


def fires(ev, mode):
    """mode 0: the first fire of the day; mode 1: re-arm - again only 30 min after the last fire"""
    if mode == 0:
        has = ev.any(1); r = np.nonzero(has)[0]
        return r, ev[r].argmax(1)
    r, t = np.nonzero(ev)
    if not len(r):
        return r, t
    keep = np.zeros(len(r), bool); lr, lt = -1, -9999
    rl, tl = r.tolist(), t.tolist()
    for i in range(len(rl)):
        if rl[i] != lr or tl[i] - lt >= COOL:
            keep[i] = True; lr, lt = rl[i], tl[i]
    return r[keep], t[keep]


# ------------------------------------------------------------------ outcomes for every minute (the hindsight side: labels and results) ------------------------------------------------------------------
def first_off(X, thr, sgn):
    """minutes after t until X reaches thr (sgn +1: X >= thr, -1: X <= thr), looking at t+1 .. 15:10; 999 = never"""
    nv = X.shape[0]
    pad = np.full((nv, T + TM + 1), np.nan); pad[:, :T] = X
    out = np.full((nv, TM), 999, np.int16)
    for a in range(0, nv, 40):
        b = min(nv, a + 40)
        W = swv(pad[a:b], END, axis=1)[:, 1:TM + 1]
        c = (W >= thr[a:b, :, None]) if sgn > 0 else (W <= thr[a:b, :, None])
        f = c.argmax(2)
        has = np.take_along_axis(c, f[:, :, None], 2)[:, :, 0]
        out[a:b] = np.where(has, f + 1, 999)
    return out


def outcomes(C, H, L, d):
    """for an entry at C[t] its way d, for every t in 0..325: +1% / +2% before -0.6% (in 60 min, by 15:10), false alarm, best move in 60 min,
    the move still left to the day's extreme until 15:10, the minutes to +1% / +2%, and the 60-min trade result"""
    C = C[:, :T]; H = H[:, :T]; L = L[:, :T]; nv = C.shape[0]
    c0 = C[:, :TM]
    fav, adv = (H, L) if d > 0 else (L, H)
    with np.errstate(all="ignore"):
        o1 = first_off(fav, c0 * (1 + d * TGT1 / 100), d)
        o2 = first_off(fav, c0 * (1 + d * TGT2 / 100), d)
        oS = first_off(adv, c0 * (1 - d * STOP / 100), -d)
        inf = -np.inf if d > 0 else np.inf
        pad = np.full((nv, T + 61), inf); pad[:, :T] = fav
        W = swv(pad, 60, axis=1)[:, 1:TM + 1]
        ext = W.max(2) if d > 0 else W.min(2)
        mfe = (ext / c0 - 1) * 100 * d
        suf = (np.maximum.accumulate(fav[:, ::-1], 1) if d > 0 else np.minimum.accumulate(fav[:, ::-1], 1))[:, ::-1]
        nxt = np.c_[suf[:, 1:], np.full(nv, inf)]
        ml = (nxt[:, :TM] / c0 - 1) * 100 * d
        i60 = np.minimum(np.arange(TM) + 60, END)
        c60 = (C[:, i60] / c0 - 1) * 100 * d
    h1 = (o1 <= 60) & (o1 < oS); h2 = (o2 <= 60) & (o2 < oS)
    e1 = (o1 < 999) & (o1 < oS); e2 = (o2 < 999) & (o2 < oS)
    s60 = (oS <= 60) & (oS <= o1)
    fa = s60 | (mfe < FLAT)
    r60 = np.where(h1, TGT1, np.where(s60, -STOP, c60))
    ml[~np.isfinite(ml)] = 0
    return {"o1": o1, "o2": o2, "h1": h1, "h2": h2, "e1": e1, "e2": e2, "fa": fa, "mfe": mfe, "ml": ml, "r60": r60, "C": c0}


def labels(C, H, L, o0, pc, d):
    """the day's move its way d (hindsight - a label, never a signal input): the peak tp, the base tb (the other extreme before it, its last
    touch), the ONSET (first close 0.3% beyond the base; 09:15 if the base is the first minute), P25 / P50 (a quarter / half of base -> peak
    done), T1 / T2 (base +1% / +2%), the move from the open and from yesterday's close"""
    C = C[:, :T]; H = H[:, :T]; L = L[:, :T]; nv = C.shape[0]; r = np.arange(nv)
    E, O_ = (H, L) if d > 0 else (L, H)
    tp = np.argmax(E * d, 1); Pk = E[r, tp]
    with np.errstate(all="ignore"):
        ampo = (Pk / o0 - 1) * 100 * d; amppc = (Pk / pc - 1) * 100 * d
    inwin = TT[None, :] <= tp[:, None]
    Om = np.where(inwin, -O_ * d, -np.inf)
    bv = Om.max(1)
    tb = END - np.argmax((Om == bv[:, None])[:, ::-1], 1)
    B = O_[r, tb]
    with np.errstate(all="ignore"):
        bp = (Pk / B - 1) * 100 * d
    w = (TT[None, :] >= tb[:, None]) & inwin

    def first_at(X, lv):
        m_ = w & ((X - lv[:, None]) * d >= 0)
        return np.where(m_.any(1), m_.argmax(1), 999)
    on = first_at(C, B * (1 + 0.003 * d))
    on = np.where(on >= 999, tp, on); on[tb == 0] = 0
    p25 = first_at(E, B + 0.25 * (Pk - B)); p50 = first_at(E, B + 0.5 * (Pk - B))
    t1 = first_at(E, B * (1 + 0.01 * d)); t2 = first_at(E, B * (1 + 0.02 * d))
    # the BREAKOUT minute (a second, timing-only label): the last close beyond the day's high (low) so far, after 15+ min without a new
    # one, between the base and half the move done; none -> the onset. On a range-then-breakout day whose low is at 09:15 the onset is
    # 09:15 but the breakout is when it left the range. (It is the DHB trigger's own shape, so it is never used to GRADE a signal.)
    with np.errstate(all="ignore"):
        RB = (np.maximum.accumulate if d > 0 else np.minimum.accumulate)(E, axis=1); prev = sh(RB, 1, np.nan)
        newb = ((E - prev) * d > 0) | (TT == 0)[None, :]
        lastnew = np.maximum.accumulate(np.where(newb, TT, 0), 1)
        age = TT - sh(lastnew, 1, 0)
        bev = ((C - prev) * d > 0) & (age >= 15) & (TT >= 15)
    wb = bev & (TT[None, :] >= tb[:, None]) & (TT[None, :] <= np.minimum(p50, tp)[:, None])
    brk = np.where(wb.any(1), END - np.argmax(wb[:, ::-1], 1), on)
    brk = np.maximum(brk, on)
    return {"tp": tp, "tb": tb, "onset": on, "p25": p25, "p50": p50, "t1": t1, "t2": t2, "ampo": ampo, "amppc": amppc, "bp": bp, "brk": brk}


def grade(NF, mv, ff):
    """the first fire at or after (base - 15 min) against the move: 1 BEFORE (by onset+2 and before P25), 2 EARLY (before P50), 3 LATE,
    0 MISSED, 4 PRIOR (rang only for an earlier swing)"""
    x = np.maximum(mv["tb"].astype(np.int64) - LOOK, 0)
    rr = mv["row"]
    f = NF[rr, x]; f0 = ff[rr]
    gr = np.where(f >= 999, np.where(f0 < x, 4, 0),
                  np.where((f <= mv["onset"] + 2) & (f < mv["p25"]), 1, np.where(f < mv["p50"], 2, 3)))
    lead = np.where(f >= 999, -999, mv["onset"] - f)
    return gr.astype(np.uint8), lead.astype(np.int16), f


def stageB(s, P, LO, acc):
    """pass B for one share: signals, labels, outcomes, fires, grades -> added to acc"""
    nv = len(P["g"])
    if nv == 0:
        return
    si_ = SHIDX.get(s, -1)
    SI = sector_inputs(P, LO)
    g = P["g"]; hv = HALF[g]; NH = len(HNAME)
    C = P["C"]; H = P["H"]; L = P["L"]
    with np.errstate(all="ignore"):
        gapf = np.abs(P["o0"] / P["pc"] - 1) * 100 >= 1.0
    for sidx, d in enumerate((1, -1)):
        ST, EV = signals(P, SI, d)
        SE = build_sets(ST, EV)
        O = outcomes(C, H, L, d)
        LB = labels(C, H, L, P["o0"], P["pc"], d)
        # the matched baseline: the same outcome from every minute in the same time bucket, same share, side and half-year
        BH = np.zeros((4, NH)); BF = np.zeros((4, NH))
        for b in range(4):
            a_, b_ = BEDGE[b], BEDGE[b + 1]; w_ = b_ - a_
            cnt = np.bincount(hv, minlength=NH) * w_
            for j, key in enumerate(("h1", "h2", "e1", "fa")):
                sm_ = np.bincount(hv, weights=O[key][:, a_:b_].sum(1), minlength=NH)
                acc["BS"][sidx, b, :, j] += sm_
                if key == "h1":
                    BH[b] = np.where(cnt > 0, sm_ / np.maximum(cnt, 1), 0)
                if key == "fa":
                    BF[b] = np.where(cnt > 0, sm_ / np.maximum(cnt, 1), 0)
            acc["BC"][sidx, b] += cnt
        keep = np.nonzero(np.maximum(np.nan_to_num(LB["ampo"]), np.nan_to_num(LB["amppc"])) >= TIERS[0])[0]
        mv = {k_: LB[k_][keep] for k_ in LB}; mv["row"] = keep
        nm = len(keep)
        midx = np.full(nv, -1, np.int64); midx[keep] = np.arange(nm)
        fastm = np.zeros(nv, np.int64); fastm[keep] = (mv["p50"] - mv["onset"]) < 10
        MG = np.zeros((nm, NSM), np.uint8); ML = np.full((nm, NSM), -999, np.int16); M2 = np.full((nm, NSM), np.nan, np.float16)
        csec = ST["CONF"]; fsec = recent(ST["FORM"])
        for k_, ev in enumerate(SE):
            for mode in (0, 1):
                sm = 2 * k_ + mode
                r, t = fires(ev, mode)
                if len(r):
                    acc["RK"].append((((2 * sm + sidx) * G + g[r]) * 400 + t).astype(np.int64))
                    bk = np.searchsorted(BEDGE, t, "right") - 1
                    vals = np.c_[np.ones(len(r)), O["h1"][r, t], O["h2"][r, t], O["e1"][r, t], O["e2"][r, t], O["fa"][r, t],
                                 BH[bk, hv[r]], BF[bk, hv[r]]]
                    for j in range(vals.shape[1]):
                        acc["DA"][sm, sidx, :, j] += np.bincount(g[r], weights=vals[:, j], minlength=G)
                FM = np.zeros((nv, T + 1), bool); FM[r, t] = True
                NF = np.minimum.accumulate(np.where(FM, np.arange(T + 1), 999)[:, ::-1], 1)[:, ::-1]
                if nm:
                    gr, ld, f = grade(NF, mv, NF[:, 0])
                    MG[:, sm] = gr; ML[:, sm] = ld
                    okf = f < 999
                    M2[okf, sm] = O["ml"][mv["row"][okf], np.minimum(f[okf] + 2, TM - 1)]
                if mode == 0 and len(r):
                    F = np.zeros(len(r), FDT)
                    F["set"] = k_; F["share"] = si_; F["g"] = g[r]; F["side"] = d; F["t"] = t
                    sec = np.where(csec[r, t], 2, np.where(fsec[r, t], 1, 0))
                    F["tag"] = bk | (sec << 2) | (gapf[r].astype(np.int64) << 4) | (fastm[r] << 5)
                    F["oi"] = P["oi"][r]
                    F["fl"] = (O["h1"][r, t] * 1) | (O["h2"][r, t] * 2) | (O["e1"][r, t] * 4) | (O["e2"][r, t] * 8) | (O["fa"][r, t] * 16)
                    hd = np.zeros(len(r), np.int64); ch = np.zeros(len(r), np.int64)
                    for j, dd in enumerate(DS):
                        td = t + dd
                        F["ml"][:, j] = O["ml"][r, td]; F["mf"][:, j] = O["mfe"][r, td]; F["rd"][:, j] = O["r60"][r, td]
                        hd |= O["h1"][r, td].astype(np.int64) << j
                        with np.errstate(all="ignore"):
                            ch |= (((O["C"][r, td] / O["C"][r, t] - 1) * 100 * d) >= 0.5).astype(np.int64) << j
                    F["hd"] = hd; F["ch"] = ch
                    F["mfe"] = O["mfe"][r, t]; F["tt1"] = O["o1"][r, t]; F["tt2"] = O["o2"][r, t]
                    F["r0"] = O["r60"][r, t]; F["r2"] = O["r60"][r, t + 2]
                    F["bh"] = BH[bk, hv[r]]; F["bf"] = BF[bk, hv[r]]
                    mi = midx[r]; hasm = mi >= 0
                    F["gr"] = -1; F["lead"] = -999
                    if nm:
                        F["gr"][hasm] = MG[mi[hasm], sm]; F["lead"][hasm] = ML[mi[hasm], sm]
                        F["ampo"][hasm] = mv["ampo"][mi[hasm]]; F["bp"][hasm] = mv["bp"][mi[hasm]]
                    acc["F"].append(F)
        if nm:
            M = np.zeros(nm, MDT)
            M["share"] = si_; M["g"] = g[keep]; M["side"] = d; M["ampo"] = mv["ampo"]; M["amppc"] = mv["amppc"]; M["gap"] = gapf[keep]
            for k_ in ("onset", "tb", "tp", "p25", "p50", "t1", "t2", "bp", "brk"):
                M[k_] = mv[k_]
            with np.errstate(all="ignore"):
                M["cc"] = np.nan_to_num((P["C"][keep, -1] / P["pc"][keep] - 1) * 100 * d)
            M["fast"] = (mv["p50"] - mv["onset"]) < 10
            acc["M"].append(M); acc["MG"].append(MG); acc["ML"].append(ML); acc["M2"].append(M2)
    acc["meta"].append((s, nv, float(np.median(P["real"])) if nv else 0.0, np.bincount(HALF[g], minlength=NH).tolist(), P.get("unlisted", 0),
                        P.get("base_n", nv), P.get("splits", []), P.get("split_drop", 0)))


def new_acc():
    NH = len(HNAME)
    return {"F": [], "M": [], "MG": [], "ML": [], "M2": [], "RK": [], "DA": np.zeros((NSM, 2, G, 8), np.float64),
            "BS": np.zeros((2, 4, NH, 4)), "BC": np.zeros((2, 4, NH)), "meta": []}


def run_group(task):
    """one sector (or one share without a sector): pass A for all its shares, the leave-one-out sector readings, then pass B"""
    sec, members = task
    t0 = time.time()
    A = {}
    for s in members:
        R = load_rows(s)
        if R is None:
            continue
        P = prep(s, R, full=False)
        if len(P["g"]):
            A[s] = stageA(P)
    LO = sector_loo(A) if len(A) >= 2 else {}
    acc = new_acc()
    for s in members:
        if s not in A or (ONLY and s not in ONLY):
            continue
        R = load_rows(s)
        P = prep(s, R, full=True)
        stageB(s, P, LO.get(s), acc)
    out = {"F": np.concatenate(acc["F"]) if acc["F"] else np.zeros(0, FDT), "M": np.concatenate(acc["M"]) if acc["M"] else np.zeros(0, MDT),
           "MG": np.concatenate(acc["MG"]) if acc["MG"] else np.zeros((0, NSM), np.uint8),
           "ML": np.concatenate(acc["ML"]) if acc["ML"] else np.zeros((0, NSM), np.int16),
           "M2": np.concatenate(acc["M2"]) if acc["M2"] else np.zeros((0, NSM), np.float16),
           "DA": acc["DA"].astype(np.float32), "BS": acc["BS"], "BC": acc["BC"], "meta": acc["meta"], "sec": sec, "n": len(A),
           "secn": len(A), "sec_ok": len(A) >= 5, "secs": time.time() - t0}
    K = np.concatenate(acc["RK"]) if acc["RK"] else np.zeros(0, np.int64)
    out["RK"], out["RC"] = np.unique(K, return_counts=True)
    return out


# ------------------------------------------------------------------ pass C: the tables ------------------------------------------------------------------
def q(x, p):
    x = np.asarray(x, np.float64); x = x[np.isfinite(x)]
    return float(np.percentile(x, p)) if len(x) else float("nan")


def rt(a, b):
    return float(a) / float(b) if b else float("nan")


def f1(x, f="%.1f"):
    return "-" if x is None or (isinstance(x, float) and not np.isfinite(x)) else f % x


def boot(num, den, W):
    """95% interval of sum(num)/sum(den), resampling whole DAYS (moves cluster in days) - Poisson bootstrap"""
    if den.sum() <= 0:
        return (float("nan"), float("nan"))
    a = W @ num; b = W @ den
    r = a[b > 0] / b[b > 0]
    return (float(np.percentile(r, 2.5)), float(np.percentile(r, 97.5))) if len(r) else (float("nan"), float("nan"))


class Study:
    def __init__(self, res, names):
        self.names = names
        self.F = np.concatenate([r["F"] for r in res]) if res else np.zeros(0, FDT)
        self.F = self.F[np.argsort(self.F["set"], kind="stable")]
        self.fo = np.searchsorted(self.F["set"], np.arange(NS + 1))
        self.M = np.concatenate([r["M"] for r in res]) if res else np.zeros(0, MDT)
        self.MG = np.concatenate([r["MG"] for r in res]) if res else np.zeros((0, NSM), np.uint8)
        self.ML = np.concatenate([r["ML"] for r in res]) if res else np.zeros((0, NSM), np.int16)
        self.M2 = np.concatenate([r["M2"] for r in res]) if res else np.zeros((0, NSM), np.float16)
        self.DA = np.sum([r["DA"].astype(np.float64) for r in res], axis=0) if res else np.zeros((NSM, 2, G, 8))
        self.BS = np.sum([r["BS"] for r in res], axis=0); self.BC = np.sum([r["BC"] for r in res], axis=0)
        K = np.concatenate([r["RK"] for r in res]) if res else np.zeros(0, np.int64)
        Cn = np.concatenate([r["RC"] for r in res]) if res else np.zeros(0, np.int64)
        o = np.argsort(K, kind="stable"); self.RK = K[o]; self.RC = Cn[o]
        self.meta = [m for r in res for m in r["meta"]]
        self.days = np.zeros(G, bool); self.days[GLO:] = True
        self.W = np.random.default_rng(7).poisson(1.0, (300, G)).astype(np.float64)
        self._ring = {}

    def fset(self, k_):
        return self.F[self.fo[k_]:self.fo[k_ + 1]]

    def rings(self, sm, side=None):
        """per day: how many rings (both sides unless side is +1 CE / -1 PE, every share) and the most in any 15 minutes"""
        key = (sm, side)
        if key in self._ring:
            return self._ring[key]
        X = np.zeros(G * 400)
        for sidx in ((0, 1) if side is None else ((0,) if side > 0 else (1,))):
            lo_ = (2 * sm + sidx) * G * 400
            a, b = np.searchsorted(self.RK, [lo_, lo_ + G * 400])
            X += np.bincount(self.RK[a:b] - lo_, weights=self.RC[a:b], minlength=G * 400)
        X = X.reshape(G, 400)
        day = X.sum(1)
        cs = np.cumsum(X, 1); r15 = cs.copy(); r15[:, 15:] -= cs[:, :-15]
        self._ring[key] = (day, r15.max(1), X)
        return self._ring[key]

    def catch(self, sm, mk):
        c = np.bincount(self.MG[mk, sm], minlength=5)
        n = int(mk.sum())
        return {"n": n, "before": int(c[1]), "early": int(c[2]), "late": int(c[3]), "missed": int(c[0] + c[4]), "prior": int(c[4]),
                "be": rt(c[1] + c[2], n)}

    def hits(self, sm, dmask, side=None):
        D = self.DA[sm] if side is None else self.DA[sm, [0 if side > 0 else 1]]
        x = D[:, dmask].sum(axis=(0, 1))
        return {"n": int(x[0]), "hit1": rt(x[1], x[0]), "hit2": rt(x[2], x[0]), "eod1": rt(x[3], x[0]), "eod2": rt(x[4], x[0]),
                "false": rt(x[5], x[0]), "base": rt(x[6], x[0]), "basef": rt(x[7], x[0]), "lift": rt(x[1], x[6])}

    def stats(self, sm, dmask):
        """everything the verdict needs for one set on a set of days"""
        M = self.M
        dm = dmask[M["g"]]
        t2 = dm & (M["ampo"] >= 2.0)
        ca = self.catch(sm, t2)
        up = t2 & (M["side"] == 1) & (NKIND[M["g"]] == 0); dn = t2 & (M["side"] == -1) & (NKIND[M["g"]] == 1)
        cu, cd = self.catch(sm, up), self.catch(sm, dn)
        day, m15, _ = self.rings(sm)
        dd = dmask & self.days
        rd, r15 = day[dd], m15[dd]
        hce, hpe, hall = self.hits(sm, dmask, 1), self.hits(sm, dmask, -1), self.hits(sm, dmask)
        halves = []
        for h in range(len(HNAME)):
            hm_ = dmask & (HALF == h)
            if not hm_.any():
                continue
            x = self.hits(sm, hm_)
            if x["n"] >= 30:
                halves.append((HNAME[h], x["n"], x["hit1"], x["base"]))
        hok = sum(1 for _, _, a, b in halves if a > b)
        cg = self.MG[t2, sm]; caught = (cg == 1) | (cg == 2)
        ml2 = self.M2[t2, sm][caught].astype(np.float64)
        rings = float(rd.sum())
        s = {"moves2": ca, "ce_upday": cu, "pe_downday": cd, "rings_total": rings, "rings_p50": q(rd, 50), "rings_p90": q(rd, 90),
             "rings_max": float(rd.max()) if len(rd) else 0.0, "r15_p90": q(r15, 90), "r15_max": float(r15.max()) if len(r15) else 0.0,
             "hit": hall, "hit_ce": hce, "hit_pe": hpe, "halves": halves, "halves_ok": hok, "ml2_med": q(ml2, 50),
             "score": rt(ca["before"] + ca["early"], rings) if rings else 0.0}
        g_ = M["g"][t2]
        num = np.bincount(g_, weights=caught.astype(np.float64), minlength=G); den = np.bincount(g_, minlength=G).astype(np.float64)
        s["be_ci"] = boot(num * dmask, den * dmask, self.W)
        D = self.DA[sm].sum(0)
        s["hit_ci"] = boot(D[:, 1] * dmask, D[:, 0] * dmask, self.W)
        return s

    def anchor(self, sm):
        """18 Nov / 16 Nov, a HELD-OUT check only (never used to pick a set). The population is the old scorecard's own: the shares whose
        CLOSE moved 2%+ on yesterday's close, that way (run_report.py). Graded on BEFORE+EARLY, because the old system's 35 / 22 'before'
        is run_report.py's looser definition (gap opens at 09:16 counted BEFORE, LATE against a later-found start), not the study's strict
        BEFORE. The open-drive moves (base = the 09:15 candle) are also shown apart: no intraday signal can ring BEFORE them."""
        out = {}
        for ds, (b, n) in ANCHOR.items():
            dn = (dt.date.fromisoformat(ds) - dt.date(1970, 1, 1)).days
            if dn not in GIDX:
                continue
            gi = GIDX[dn]
            mk = (self.M["g"] == gi) & (self.M["cc"] >= 2.0)
            c = self.catch(sm, mk)
            c["not_open_drive"] = self.catch(sm, mk & (self.M["tb"] > 0))
            c["open_drive"] = int((mk & (self.M["tb"] == 0)).sum())
            day, m15, _ = self.rings(sm)
            c["rings"] = float(day[gi]); c["r15"] = float(m15[gi]); c["need"] = b / float(n); c["old_n"] = n
            c["heldout"] = bool(not TRAIN[gi])
            c["pass"] = c["n"] > 0 and c["be"] >= b / float(n)
            out[ds] = c
        return out

    def side_stats(self, sm, dmask, d):
        """one set, one side: the catch on that side's 2% moves (all, and not open-drive), its lead, its lift, its rings"""
        M = self.M
        mk = dmask[M["g"]] & (M["ampo"] >= 2.0) & (M["side"] == d)
        ca = self.catch(sm, mk); cn = self.catch(sm, mk & (M["tb"] > 0))
        g_ = self.MG[mk, sm]; caught = (g_ == 1) | (g_ == 2)
        lead = q(self.ML[mk, sm][caught], 50)
        mo = mk & (M["tb"] > 0); go = self.MG[mo, sm]
        lead_o = q(self.ML[mo, sm][(go == 1) | (go == 2)], 50)
        h = self.hits(sm, dmask, d)
        day, m15, _ = self.rings(sm, d)
        dd = dmask & self.days
        D = self.DA[sm, 0 if d > 0 else 1]
        lci = boot(D[:, 1] * dmask, D[:, 6] * dmask, self.W)          # the lift's 95% interval: hits / random, resampling whole days
        return {"all": ca, "not_od": cn, "lead_caught": lead, "lead_not_od": lead_o, "lift": h["lift"], "hit1": h["hit1"], "base": h["base"],
                "lift_ci": lci, "n_fires": h["n"], "rings_p50": q(day[dd], 50), "rings_p90": q(day[dd], 90), "od": self.od_timing(sm, mo_od(M, mk))}

    def od_timing(self, sm, mk):
        """the OPEN-DRIVE moves (base = the 09:15 candle) graded by TIMING only - the BEFORE rule can never count a warning there (the onset
        is 09:15 by rule, BEFORE needs a ring by 09:17). The fire is the day's first (the move's base is minute 0): before a quarter of the
        move is done (P25), and by the breakout (BRK + 2 min, before P25) on the moves that break out 15+ min after 09:15. Sets built on the
        day-high / low break (DHBSETS) are the BRK label's own shape and get no BRK grade."""
        M = self.M
        ld = self.ML[mk, sm].astype(np.int64); has = ld != -999; f = np.where(has, -ld, 999)
        p25 = M["p25"][mk].astype(np.int64); brk = M["brk"][mk].astype(np.int64)
        late = p25 >= 15; bl = brk >= 15
        b25 = has & (f < p25); bb = has & (f <= brk + 2) & (f < p25)
        dhb = SETS[sm // 2] in DHBSETS
        return {"n": int(mk.sum()), "p25_late": int(late.sum()), "brk_late": int(bl.sum()), "b25": int(b25.sum()), "b25_late": int((b25 & late).sum()),
                "bbrk": None if dhb else int((bb & bl).sum()), "dhb": dhb}


def mo_od(M, mk):
    return mk & (M["tb"] == 0)


def ring_stats(X, dmask):
    """X (days, 400) rings a minute -> a day median / p90, the day's busiest 15 min median / p90"""
    X = X[dmask]
    if not len(X):
        return {"p50": float("nan"), "p90": float("nan"), "r15_p50": float("nan"), "r15_p90": float("nan")}
    day = X.sum(1); cs = np.cumsum(X, 1); r15 = cs.copy(); r15[:, 15:] -= cs[:, :-15]; m15 = r15.max(1)
    return {"p50": q(day, 50), "p90": q(day, 90), "r15_p50": q(m15, 50), "r15_p90": q(m15, 90)}


def alarm_ok(st):
    """section 0 names a set as THE ALARM on a side only if it has an edge there: B+E >= FLOOR_BE, ALARM_MIN_FIRES+ first fires, a lift
    > ALARM_LIFT whose 95% interval (by day) stays above ALARM_CI"""
    lo = st["lift_ci"][0]
    return bool(np.isfinite(st["all"]["be"]) and st["all"]["be"] >= FLOOR_BE and st["n_fires"] >= ALARM_MIN_FIRES and np.isfinite(st["lift"])
                and st["lift"] > ALARM_LIFT and np.isfinite(lo) and lo > ALARM_CI)


def qualify(s):
    """the four rules - on the tuning days only. (18 / 16 Nov are held-out days: they are reported in section 4 and never decide this.)"""
    a = s["moves2"]["be"] >= YEARS_MIN if np.isfinite(s["moves2"]["be"]) else False
    b = (s["rings_p90"] <= 50) and (s["r15_p90"] <= 6)
    cu, cd = s["ce_upday"]["be"], s["pe_downday"]["be"]
    c = (np.isfinite(cu) and np.isfinite(cd) and cu >= 0.8 * cd and s["hit_ce"]["lift"] > 1.2 and s["hit_pe"]["lift"] > 1.2)
    nh = len(s["halves"])
    d = nh >= 2 and s["halves_ok"] >= 5.0 / 6.0 * nh
    return {"a": bool(a), "b": bool(b), "c": bool(c), "d": bool(d), "all": bool(a and b and c and d)}


def smname(sm):
    return "%s%s" % (SETS[sm // 2], "" if sm % 2 == 0 else " re-arm")


def lat_curve(cf):
    """fires (the caught ones, or every fire of a set) -> by delay d: the move left to 15:10 (median), the best move in 60 min (median), +1% before -0.6% in 60 min (rate),
    the 60-min option proxy after 1.5% costs (mean), already a chase (rate)"""
    rows = []
    for j, dd in enumerate(DS):
        rows.append({"d": dd, "ml": q(cf["ml"][:, j].astype(np.float64), 50), "ml_p25": q(cf["ml"][:, j].astype(np.float64), 25),
                     "mfe": q(cf["mf"][:, j].astype(np.float64), 50), "hit60": float(((cf["hd"].astype(np.int64) >> j) & 1).mean()),
                     "opt": float(np.mean(DELTA * cf["rd"][:, j].astype(np.float64) / PREM * 100) - COSTS[0]),
                     "opt3": float(np.mean(DELTA * cf["rd"][:, j].astype(np.float64) / PREM * 100) - COSTS[1]),
                     "chase": float(((cf["ch"].astype(np.int64) >> j) & 1).mean()),
                     "loss_per_min": (q(cf["ml"][:, 0].astype(np.float64) - cf["ml"][:, j].astype(np.float64), 50) / dd) if dd else 0.0})
    return rows


def budget(rows, key):
    """the largest delay d that still keeps 90% of what an entry at once gets on `key` (every shorter delay too).
    -> (minutes, capped: True when it never broke inside the delays tested, or None when there is no edge to keep at d = 0)"""
    v0 = rows[0][key]
    if not np.isfinite(v0) or v0 <= 0:
        return None, None
    b = 0
    for r in rows:
        if np.isfinite(r[key]) and r[key] >= 0.9 * v0:
            b = r["d"]
        else:
            return b, False
    return b, True


def edge_budget(rows, base):
    """over EVERY fire: the largest delay d whose +1%-before--0.6% rate keeps 90% of its edge OVER RANDOM at d = 0 (hit60 - base, the
    matched random minutes) - the budget compared with random, not with the set's own hindsight-caught fires. (None, None) = no edge."""
    e0 = rows[0]["hit60"] - base
    if not np.isfinite(e0) or e0 <= 0:
        return None, None
    b = 0
    for r in rows:
        if r["hit60"] - base >= 0.9 * e0:
            b = r["d"]
        else:
            return b, False
    return b, True


def every_fire(F):
    """every first fire of a set (one side) -> the curve, the matched random +1%-before--0.6% rate and the edge budget"""
    cur = lat_curve(F); base = float(F["bh"].astype(np.float64).mean())
    return cur, base, edge_budget(cur, base)


def fb(x):
    b, cap = x
    if b is None:
        return "no edge at once"
    return (">= %d (longest tested)" % b) if cap else ("%d min" % b)


def report(S, t0, args):
    out = []
    P = lambda *a: out.append(" ".join(str(x) for x in a))
    J = {"meta": {}, "summary": {}, "moves": {}, "sets": {}, "ranking": [], "latency": {}, "rings": {}, "nov": {}, "heldout": {}, "baseline": {}}
    M = S.M; days = S.days; nd = int(days.sum())
    tr = TRAIN & days; te = (~TRAIN) & days
    d0, d1 = dday(CAL[GLO]), dday(CAL[-1])
    ill = [m[0] for m in S.meta if m[2] < 340]
    P("=== THE MOVE STUDY (onsetstudy.py) · %s -> %s · %d market days (%.1f years) · %d shares · %d share-days" % (
        d0, d1, nd, nd / 248.0, len(S.meta), sum(m[1] for m in S.meta)))
    P("    tuned on %s -> %s (%d days) · HELD OUT (never used to pick, 18 / 16 Nov included): %s -> %s (%d days)" % (
        d0, dday(CAL[tr].max()) if tr.any() else "-", int(tr.sum()), dday(CAL[te].min()) if te.any() else "-", d1, int(te.sum())))
    if args.get("shares"):
        P("    ONLY these shares: %s (rings count only them)" % ", ".join(sorted(args["shares"])))
    P("    illiquid (median real minutes < 340, grid() fills their gaps with the last price - treat with care): %s" % (", ".join(ill[:30]) or "none"))
    # the store's coverage: how many shares have data in each half-year (a store half-way through its 3 -> 5 year extension mixes universes)
    hs = [h for h in range(len(HNAME)) if (days & (HALF == h)).any()]
    cov = {HNAME[h]: int(sum(1 for m in S.meta if m[3][h] >= 20)) for h in hs}
    P("    shares with 20+ study days in each half-year: %s" % " · ".join("%s %d" % (k_, v) for k_, v in cov.items()))
    full = [v for k_, v in cov.items()]
    mixed = bool(full) and min(full[:-1] or full) < 0.85 * float(np.median(full))
    if mixed:
        P("    !! MIXED STORE: the early half-years have far fewer shares than the rest (thinner sectors, another universe). Wait for histstore.py")
        P("    !! to finish the extension, or run with --years 3. The half-year rule (d) and the tuning / held-out comparison are skewed meanwhile.")
    lost = [(m[0], m[4], m[5]) for m in S.meta if m[5] and m[4] >= 0.2 * m[5]]
    if lost:
        P("    left out as 'not in F&O that day' on 20%%+ of their days (a rename missing from ALIAS would look like this): %s" % ", ".join(
            "%s %d/%d" % x for x in lost[:20]))
    spl = [(m[0], m[6], m[7]) for m in S.meta if len(m) > 7 and m[6]]
    nspl = sum(len(x[1]) for x in spl); ndrop = sum(x[2] for x in spl)
    if spl:
        P("    split / bonus-like jumps (an open %.0f%%+ off the last close): %d on %d shares - each day and the share's next %d days left out (%d "
          "share-days), so the 20-day volume history (RVOL / RVOL5) never mixes pre- and post-split units: %s" % (
              SPLIT_JUMP * 100, nspl, len(spl), SPLIT_SKIP, ndrop, ", ".join("%s %s" % (x[0], "/".join(x[1][:3])) for x in spl[:15])))
    else:
        P("    split / bonus-like jumps (an open %.0f%%+ off the last close): none - the minute history looks adjusted for corporate actions" % (
            SPLIT_JUMP * 100))
    if ALIAS_USED:
        P("    renamed shares read with their old NSE symbol too: %s" % ", ".join(ALIAS_USED))
    if LOOSE_SEC:
        P("    sectors.json buckets of unrelated shares, treated as no sector (no breadth / RS): %s" % ", ".join(LOOSE_SEC))
    J["meta"] = {"from": str(d0), "to": str(d1), "days": nd, "shares": len(S.meta), "train_days": int(tr.sum()), "heldout_days": int(te.sum()),
                 "illiquid": ill, "sets": list(SETS), "desc": DESC, "half_years": HNAME, "coverage": cov, "mixed_store": mixed,
                 "unlisted_heavy": lost, "alias": ALIAS_USED, "loose_sectors": LOOSE_SEC,
                 "splits": {x[0]: x[1] for x in spl}, "split_days_dropped": ndrop}
    P("READ: CE = the share going up, PE = the share going down - every number below is shown for both. Minute 0 = 09:15. A move is the")
    P("day's best run from the OPEN (and, second, from yesterday's close); its ONSET is the first close 0.3% off its base (the day's other")
    P("extreme before the peak, its last touch). When the base is the 09:15 candle itself (an OPEN-DRIVE move) the onset is 09:15 by rule.")
    P("BEFORE = a ring by the onset + 2 min and before a quarter of the move is done; EARLY = before half is done; LATE = after; MISSED = none.")
    TOP = len(out)                   # the answer (section 0) is put here once everything is measured

    # 1 ---- THE MOVES
    P("\n=== 1. HOW THE MOVES BREAK - %d share-day moves of 1.5%%+ (from the open) · each side separately · hindsight labels" % int(
        (days[M["g"]] & (M["ampo"] >= 1.5)).sum()))
    P("    READ THE TIMING FROM P25 / P50 / +1%: the ONSET follows the 0.3%-off-the-base rule, so on a range-then-breakout day whose low (high)")
    P("    is at 09:15 it reads 09:15, not the breakout. 'od' = open-drive moves (base = the 09:15 candle); BRK = the breakout minute (the last")
    P("    fresh break of the day's high / low after 15+ quiet minutes, before half is done; the onset when there is none).")
    onb = lambda x: np.bincount(np.searchsorted((0, 30, 105, 225, 356), x, "right") - 1, minlength=4)[:4]
    J["moves"]["open"] = {}
    for X in TIERS:
        for d, side in ((1, "CE"), (-1, "PE")):
            for cls, cm in (("all", None), ("not gap", 0), ("GAP", 1)):
                mk = days[M["g"]] & (M["ampo"] >= X) & (M["side"] == d) & (True if cm is None else (M["gap"] == cm))
                n = int(mk.sum())
                if n < 5:
                    continue
                m_ = M[mk]
                ob = onb(m_["onset"]) / n * 100
                d25 = m_["p25"] - m_["onset"]; d50 = m_["p50"] - m_["onset"]; dpk = m_["tp"] - m_["onset"]
                t1 = (m_["t1"] - m_["onset"])[m_["t1"] < 999]; t2 = (m_["t2"] - m_["onset"])[m_["t2"] < 999]
                fast = float(m_["fast"].mean() * 100)
                od = float((m_["tb"] == 0).mean() * 100)
                b50 = m_["p50"] - m_["brk"]; bl = float(((m_["brk"] - m_["onset"]) >= 15).mean() * 100)
                row = {"n": n, "per_day": n / max(nd, 1), "onset_med": q(m_["onset"], 50), "onset_buckets_pct": ob.tolist(),
                       "to_p25_med": q(d25, 50), "to_p50_med": q(d50, 50), "to_p50_p25": q(d50, 25), "to_p50_p75": q(d50, 75),
                       "to_t1_med": q(t1, 50), "to_t2_med": q(t2, 50), "to_peak_med": q(dpk, 50), "fast_pct": fast, "bp_med": q(m_["bp"], 50),
                       "open_drive_pct": od, "p25_clock_med": q(m_["p25"], 50), "p50_clock_med": q(m_["p50"], 50), "brk_med": q(m_["brk"], 50),
                       "brk_to_p50_med": q(b50, 50), "brk_later_15_pct": bl}
                J["moves"]["open"]["%s %s %s" % (X, side, cls)] = row
                P("  %3.1f%%+ %s %-7s %6d (%.1f a day) · od %2.0f%% · onset median %s (%2.0f%% 09:15-09:45, %2.0f%% -11:00, %2.0f%% -13:00, %2.0f%% later) · "
                  "quarter done at %s, HALF at %s · from the onset: a quarter %s min, HALF %s min (p25-p75 %s-%s), +1%% %s, +2%% %s, peak %s · "
                  "BRK median %s, HALF %s min after it (BRK 15+ min after the onset: %2.0f%%) · fast %2.0f%% · base->peak %s%%" % (
                      X, side, cls, n, n / max(nd, 1), od, hm(row["onset_med"]), ob[0], ob[1], ob[2], ob[3], hm(row["p25_clock_med"]),
                      hm(row["p50_clock_med"]), f1(row["to_p25_med"], "%.0f"), f1(row["to_p50_med"], "%.0f"), f1(row["to_p50_p25"], "%.0f"),
                      f1(row["to_p50_p75"], "%.0f"), f1(row["to_t1_med"], "%.0f"), f1(row["to_t2_med"], "%.0f"), f1(row["to_peak_med"], "%.0f"),
                      hm(row["brk_med"]), f1(row["brk_to_p50_med"], "%.0f"), bl, fast, f1(row["bp_med"], "%.2f")))
    P("  THE BEFORE CEILING (2% moves): the share that is NOT open-drive - the most the BEFORE rule can count (on an open-drive move the onset")
    P("  is 09:15 by rule and BEFORE needs a ring by 09:17, so the rule can never count a warning there). That ceiling is the RULE's: an open-drive")
    P("  move a quarter done only at / after 09:30 still leaves time to warn; section 0 grades those by timing (before P25, by the breakout).")
    J["moves"]["ceiling"] = {}
    for d, side in ((1, "CE"), (-1, "PE")):
        mk = days[M["g"]] & (M["ampo"] >= 2.0) & (M["side"] == d); n = max(int(mk.sum()), 1)
        od = int((mk & (M["tb"] == 0)).sum()); gp = int((mk & (M["gap"] == 1)).sum()); og = int((mk & ((M["tb"] == 0) | (M["gap"] == 1))).sum())
        mo = mk & (M["tb"] == 0)
        odl = int((mo & (M["p25"] >= 15)).sum()); odb = int((mo & (M["brk"] >= 15)).sum())
        J["moves"]["ceiling"][side] = {"n": int(mk.sum()), "open_drive": od, "gap": gp, "open_drive_or_gap": og, "ceiling": 1 - od / n,
                                       "od_p25_after_0930": odl, "od_brk_15plus": odb, "warnable": (n - od + odl) / n}
        P("    %s %6d · open-drive %2.0f%% · gap %2.0f%% · either %2.0f%% · BEFORE ceiling %2.0f%% (the rule's) · of the open-drive moves %2.0f%% are a "
          "quarter done only at / after 09:30 and %2.0f%% break out (BRK) 15+ min after 09:15 - a signal can still warn of those, so the moves a "
          "warning could reach: %2.0f%%" % (side, int(mk.sum()), od / n * 100, gp / n * 100, og / n * 100, (1 - od / n) * 100,
                                            rt(odl, od) * 100 if od else 0, rt(odb, od) * 100 if od else 0, (n - od + odl) / n * 100))
    P("  the second label, from YESTERDAY's close (gap included):")
    J["moves"]["pc"] = {}
    for X in TIERS:
        cells = []
        for d, side in ((1, "CE"), (-1, "PE")):
            mk = days[M["g"]] & (M["amppc"] >= X) & (M["side"] == d)
            cells.append("%s %d (%.1f a day)" % (side, int(mk.sum()), mk.sum() / max(nd, 1)))
            J["moves"]["pc"]["%s %s" % (X, side)] = int(mk.sum())
        P("    %3.1f%%+  %s" % (X, " · ".join(cells)))
    P("  CE and PE by NIFTY's day (2%+ from the open, a day on average):")
    for k_, nmk in ((0, "NIFTY up"), (1, "NIFTY down"), (2, "NIFTY mixed")):
        dk = days & (NKIND == k_); n_ = max(int(dk.sum()), 1)
        ce = int((dk[M["g"]] & (M["ampo"] >= 2) & (M["side"] == 1)).sum()); pe = int((dk[M["g"]] & (M["ampo"] >= 2) & (M["side"] == -1)).sum())
        P("    %-12s %4d days · CE %.1f · PE %.1f a day" % (nmk, int(dk.sum()), ce / n_, pe / n_))
        J["moves"]["nifty_%d" % k_] = {"days": int(dk.sum()), "ce_per_day": ce / n_, "pe_per_day": pe / n_}
    mk2 = days[M["g"]] & (M["ampo"] >= 2.0)
    for d, side in ((1, "CE"), (-1, "PE")):
        mk = mk2 & (M["gap"] == 0) & (M["side"] == d)
        if not mk.any():
            continue
        d50 = (M["p50"] - M["onset"])[mk]; d25 = (M["p25"] - M["onset"])[mk]
        cs = S.catch(2 * SETS.index("CONF"), mk2 & (M["side"] == d))
        oth = [(SETS[k_], S.catch(2 * k_, mk2 & (M["side"] == d))["be"]) for k_ in range(len(SINGLES)) if SETS[k_] != "CONF"]
        oth = [x for x in oth if np.isfinite(x[1])]
        bo = max(oth, key=lambda x: x[1]) if oth else ("-", float("nan"))
        cb = cs["be"]
        if not (np.isfinite(cb) and np.isfinite(bo[1])):
            tail = "CONF's catch cannot be measured on these days."
        elif cb < 0.5 * bo[1]:
            tail = ("waiting for the sector to be CONFIRMED caught %.0f%% early against %.0f%% for %s, so the alarm cannot wait for CONFIRMED."
                    % (cb * 100, bo[1] * 100, bo[0]))
        elif cb < 0.9 * bo[1]:
            tail = "CONFIRMED caught %.0f%% early against %.0f%% for %s - it costs catches, use it to grade, not to gate." % (cb * 100, bo[1] * 100, bo[0])
        else:
            tail = "CONFIRMED caught %.0f%% early, as much as the best other signal (%s %.0f%%) - here waiting for it costs little." % (
                cb * 100, bo[0], bo[1] * 100)
        J["moves"]["one_line_%s" % side] = {"q_med": q(d25, 50), "half_med": q(d50, 50), "half_p25": q(d50, 25), "conf_be": cb, "best_other": bo}
        P("  IN ONE LINE, %s: a 2%% move (no gap) is a quarter done %.0f min and HALF done %.0f min after it starts (a quarter of them in %.0f min or "
          "less); %s" % (side, q(d25, 50), q(d50, 50), q(d50, 25), tail))

    # 2 ---- THE VERDICT
    P("\n=== 2. THE VERDICT - every signal set on the TUNING days, ranked by early catches (BEFORE+EARLY on 2% moves) per ring, then the move left at +2 min")
    P("    rules: (a) BEFORE+EARLY on 2%% moves >= %.0f%% over the tuning days (the old system's worst day, 22 of 53) · (b) p90 rings a day <= 50"
      " and p90 of the day's busiest 15 min <= 6 · (c) CE catch on NIFTY-up days >= 0.8 x PE catch on NIFTY-down days, both sides"
      " +1%%-before--0.6%% lift > 1.2 · (d) above random in >= 5 of 6 half-years. 18 / 16 Nov are held-out days: section 4, never a rule here." % (YEARS_MIN * 100))
    rows = []
    for sm in range(NSM):
        s = S.stats(sm, tr if tr.any() else days); qf = qualify(s)
        rows.append((sm, s, qf))
        J["sets"][smname(sm)] = {"desc": DESC[SETS[sm // 2]], "train": s, "rules": qf}
    rows.sort(key=lambda x: (not x[2]["all"], -x[1]["score"], -(x[1]["ml2_med"] if np.isfinite(x[1]["ml2_med"]) else -9)))
    P("    %-3s %-16s %6s %6s %6s %6s %5s %6s · %6s %5s %5s · %5s %5s %5s · %4s %4s · %-5s %s" % (
        "#", "set", "2%mv", "BEF%", "B+E%", "late%", "miss", "rings", "/day90", "15m90", "B+E/r", "CEup", "PEdn", "lift", "hit1", "base", "ML@2", "rules a b c d"))
    for i, (sm, s, qf) in enumerate(rows):
        c = s["moves2"]
        P("    %-3d %-16s %6d %5.0f%% %5.0f%% %5.0f%% %4.0f%% %6.0f · %6.0f %5.0f %5.2f · %4.0f%% %4.0f%% %4.2f/%4.2f · %3.0f%% %3.0f%% · %5s %s %s %s %s %s" % (
            i + 1, smname(sm), c["n"], rt(c["before"], c["n"]) * 100, c["be"] * 100, rt(c["late"], c["n"]) * 100, rt(c["missed"], c["n"]) * 100,
            s["rings_total"], s["rings_p90"], s["r15_p90"], s["score"], s["ce_upday"]["be"] * 100, s["pe_downday"]["be"] * 100,
            s["hit_ce"]["lift"], s["hit_pe"]["lift"], s["hit"]["hit1"] * 100, s["hit"]["base"] * 100, f1(s["ml2_med"], "%.2f"),
            "PASS" if qf["all"] else "    ", "a" if qf["a"] else "-", "b" if qf["b"] else "-", "c" if qf["c"] else "-", "d" if qf["d"] else "-"))
    J["ranking"] = [{"set": smname(sm), "score": s["score"], "rules": qf} for sm, s, qf in rows]
    win = [x for x in rows if x[2]["all"]][:5]
    frozen = [x[0] for x in win]
    J["reference"] = {}
    if not frozen:
        P("  NO set passed every rule on the tuning days. NOTHING is frozen. For reference only (not winners):")
        floor = [x for x in rows if x[1]["moves2"]["be"] >= FLOOR_BE and (x[1]["moves2"]["before"] + x[1]["moves2"]["early"]) >= FLOOR_N][:5]
        inlim = [x for x in rows if x[2]["b"] and (x[1]["moves2"]["before"] + x[1]["moves2"]["early"]) >= FLOOR_N]
        best_in = max(inlim, key=lambda x: x[1]["moves2"]["be"]) if inlim else None
        rich = [x for x in rows if x[1]["moves2"]["be"] >= YEARS_MIN and (x[1]["moves2"]["before"] + x[1]["moves2"]["early"]) >= FLOOR_N]
        few = min(rich, key=lambda x: x[1]["rings_p50"] if np.isfinite(x[1]["rings_p50"]) else 1e9) if rich else None
        if floor:
            P("    the best by the ranking among sets that catch %.0f%%+ early and %d+ moves: %s" % (FLOOR_BE * 100, FLOOR_N, ", ".join(
                "%s (B+E %.0f%%, missed %.0f%%, rings p90 %.0f)" % (smname(x[0]), x[1]["moves2"]["be"] * 100,
                                                                   rt(x[1]["moves2"]["missed"], x[1]["moves2"]["n"]) * 100, x[1]["rings_p90"]) for x in floor)))
        else:
            P("    no set catches %.0f%%+ of the 2%% moves early with %d+ caught moves" % (FLOOR_BE * 100, FLOOR_N))
        if best_in:
            P("    the best catch within 50 rings a day / 6 in 15 min: %s (B+E %.0f%%, rings p90 %.0f, 15-min p90 %.0f)" % (
                smname(best_in[0]), best_in[1]["moves2"]["be"] * 100, best_in[1]["rings_p90"], best_in[1]["r15_p90"]))
        else:
            P("    no set stays within 50 rings a day / 6 in 15 min and catches %d+ moves early" % FLOOR_N)
        if few:
            P("    the fewest rings at a %.0f%%+ catch (22 of 53): %s (B+E %.0f%%, rings median %.0f, p90 %.0f a day)" % (
                YEARS_MIN * 100, smname(few[0]), few[1]["moves2"]["be"] * 100, few[1]["rings_p50"], few[1]["rings_p90"]))
        else:
            P("    no set reaches a %.0f%% catch on %d+ moves" % (YEARS_MIN * 100, FLOOR_N))
        frozen_ref = list(dict.fromkeys([x[0] for x in floor] + ([best_in[0]] if best_in else []) + ([few[0]] if few else [])))
        J["reference"] = {"floor": [smname(x[0]) for x in floor], "best_in_limits": smname(best_in[0]) if best_in else None,
                          "fewest_rings_at_42pct": smname(few[0]) if few else None}
    else:
        P("  FROZEN WINNERS (picked on the tuning days only): %s" % ", ".join(smname(x) for x in frozen))
        frozen_ref = frozen
    J["frozen"] = [smname(x) for x in frozen]

    # 3 ---- HELD OUT
    P("\n=== 3. TUNING DAYS vs the HELD-OUT last 6 months, the same sets unchanged")
    refs = list(dict.fromkeys(frozen_ref + [2 * SETS.index("CONF"), 2 * SETS.index("DHB"), 2 * SETS.index("U4")]))
    for sm in refs:
        a, b = S.stats(sm, tr), S.stats(sm, te) if te.any() else None
        J["heldout"][smname(sm)] = {"train": a, "heldout": b}
        for lab, s in (("tuning ", a), ("HELD OUT", b)):
            if s is None:
                P("  %-16s %s no held-out days in the store" % (smname(sm), lab)); continue
            c = s["moves2"]
            P("  %-16s %-8s 2%% moves %5d · BEFORE %4.0f%% · B+E %4.0f%% (95%% %s-%s) · missed %3.0f%% · rings p50 %3.0f p90 %3.0f · 15-min p90 %2.0f · "
              "hit +1%% %3.0f%% (95%% %s-%s) vs random %3.0f%% · lift CE %.2f PE %.2f · CE-up %3.0f%% PE-down %3.0f%%" % (
                  smname(sm), lab, c["n"], rt(c["before"], c["n"]) * 100, c["be"] * 100, f1(s["be_ci"][0] * 100, "%.0f"), f1(s["be_ci"][1] * 100, "%.0f"),
                  rt(c["missed"], c["n"]) * 100, s["rings_p50"], s["rings_p90"], s["r15_p90"], s["hit"]["hit1"] * 100, f1(s["hit_ci"][0] * 100, "%.0f"),
                  f1(s["hit_ci"][1] * 100, "%.0f"), s["hit"]["base"] * 100, s["hit_ce"]["lift"], s["hit_pe"]["lift"], s["ce_upday"]["be"] * 100,
                  s["pe_downday"]["be"] * 100))

    # 4 ---- 18 / 16 NOV
    P("\n=== 4. 18 NOV and 16 NOV REPLAYED - a HELD-OUT check, never used to pick. The population is the old scorecard's: the shares whose close")
    P("    moved 2%+ on yesterday's close, that way. The old system's 'before' (35 / 22 of 53) is run_report.py's looser definition (gap opens at")
    P("    09:16 counted BEFORE, LATE against a later-found start), so it is set against the study's BEFORE+EARLY, never its strict BEFORE.")
    for ds, (b, n) in ANCHOR.items():
        dn = (dt.date.fromisoformat(ds) - dt.date(1970, 1, 1)).days
        if dn not in GIDX:
            P("  %s is not in the store - this check waits for the store to reach it" % ds); continue
        gi = GIDX[dn]
        mk = (M["g"] == gi) & (M["cc"] >= 2.0)
        od = int((mk & (M["tb"] == 0)).sum())
        P("  %s%s · %d movers here (old scorecard: %d) · CE %d, PE %d · open-drive %d (BEFORE ceiling %d of %d) · old system 'before' %d of %d "
          "(its own definition) · NIFTY %s" % (ds, "" if not TRAIN[gi] else " (NOTE: inside the tuning days with this store)", int(mk.sum()), n,
                                               int((mk & (M["side"] == 1)).sum()), int((mk & (M["side"] == -1)).sum()), od, int(mk.sum()) - od,
                                               int(mk.sum()), b, n, ("up", "down", "mixed")[int(NKIND[gi])]))
        J["nov"][ds] = {"movers": int(mk.sum()), "old_movers": n, "open_drive": od, "old_before": b}
        for sm in refs:
            an = S.anchor(sm).get(ds)
            c = S.catch(sm, mk); day, m15, _ = S.rings(sm)
            cce = S.catch(sm, mk & (M["side"] == 1)); cpe = S.catch(sm, mk & (M["side"] == -1))
            J["nov"][ds][smname(sm)] = {"all": c, "ce": cce, "pe": cpe, "rings": float(day[gi]), "r15": float(m15[gi]), "anchor": an}
            P("    %-16s BEFORE %3d · EARLY %3d · LATE %3d · MISSED %3d · B+E %3.0f%% (needs %2.0f%%: %s) · not open-drive B+E %s/%d · "
              "(CE %d/%d early, PE %d/%d) · rings %3.0f, busiest 15 min %2.0f" % (
                  smname(sm), c["before"], c["early"], c["late"], c["missed"], c["be"] * 100 if np.isfinite(c["be"]) else 0, b / float(n) * 100,
                  "pass" if an and an["pass"] else "fail", an["not_open_drive"]["before"] + an["not_open_drive"]["early"] if an else 0,
                  an["not_open_drive"]["n"] if an else 0, cce["before"] + cce["early"], cce["n"], cpe["before"] + cpe["early"], cpe["n"], day[gi], m15[gi]))

    # 5 ---- REACTION TIME
    P("\n=== 5. REACTION TIME - the same fire entered d minutes later · first fire of the day · TWO populations, never mix them:")
    P("    ON THE MOVES IT CAUGHT = only the fires hindsight graded BEFORE / EARLY on a 2% move (an upper bound: what is left on a move that")
    P("    really came) · EVERY FIRE = every first fire of that set and side, the population a live ring belongs to (it cannot know the move).")
    P("    The EDGE budget is measured on EVERY FIRE against random minutes: the largest d whose HIT60 keeps 90% of its edge over random.")
    P("    d = 0 is already the minute's close: a 1-minute candle is known only at t+1:00, so d = 0 means the close + the seconds to read it.")
    P("    LEFT = the best price after the entry until 15:10 (an upper bound, a loose bar) · MFE60 = the best move in the 60 min after the entry")
    P("    (what a 60-min option trade feels) · HIT60 = +1% before -0.6% in 60 min · OPT / OPT3 = the 60-min option proxy after 1.5% / 3% costs,")
    P("    % of the premium")
    P("    · CHASE = already 0.5%+ its way since the fire. BUDGET = the largest d that keeps 90% of the d = 0 value (every shorter d too);")
    P("    '>= %d (longest tested)' means it never broke inside the delays tried. Read MFE60 / HIT60 / OPT first: LEFT runs to 15:10." % DS[-1])
    lat_sets = list(dict.fromkeys(refs + [2 * k_ for k_ in range(len(SINGLES))]))
    for sm in lat_sets:
        if sm % 2:
            continue
        F = S.fset(sm // 2)
        F = F[days[F["g"]]]; Fall = F
        cg = (F["gr"] == 1) | (F["gr"] == 2)
        cf = F[cg & (F["ampo"] >= 2.0)]
        if len(cf) < MIN_LAT:
            continue
        fm = ((cf["tag"] >> 5) & 1) == 1                 # the fast moves: half done within 10 minutes of the onset
        groups = [("all", cf), ("CE", cf[cf["side"] == 1]), ("PE", cf[cf["side"] == -1]), ("fast", cf[fm]),
                  ("fast CE", cf[fm & (cf["side"] == 1)]), ("fast PE", cf[fm & (cf["side"] == -1)])]
        Jl = J["latency"][smname(sm)] = {"n": int(len(cf))}
        P("  %-14s %5d caught (CE %d, PE %d, fast %d)" % (smname(sm), len(cf), int((cf["side"] == 1).sum()), int((cf["side"] == -1).sum()), int(fm.sum())))
        for lab, x in groups:
            if len(x) < (MIN_LAT if lab == "all" else 10):
                continue
            cur = lat_curve(x)
            bud = {k_: budget(cur, k_) for k_ in ("ml", "mfe", "hit60", "opt")}
            Jl[lab] = {"n": int(len(x)), "curve": cur, "budget": {k_: {"min": v[0], "capped": v[1]} for k_, v in bud.items()}}
            if lab == "all":
                Jl["budget_min"] = bud["mfe"][0]; Jl["curve"] = cur
            P("    %-8s %5d ON THE MOVES IT CAUGHT · BUDGET: MFE60 %s · HIT60 %s · OPT %s · LEFT %s" % (
                lab, len(x), fb(bud["mfe"]), fb(bud["hit60"]), fb(bud["opt"]), fb(bud["ml"])))
            if lab in ("all", "CE", "PE", "fast"):
                P("             d     " + " ".join("%6d" % r["d"] for r in cur))
                P("             MFE60 " + " ".join("%6s" % f1(r["mfe"], "%.2f") for r in cur) + "   %")
                P("             HIT60 " + " ".join("%5.0f%%" % (r["hit60"] * 100) for r in cur))
                P("             OPT   " + " ".join("%+6.1f" % r["opt"] for r in cur) + "   % of the premium")
                P("             LEFT  " + " ".join("%6s" % f1(r["ml"], "%.2f") for r in cur) + "   %")
                P("             CHASE " + " ".join("%5.0f%%" % (r["chase"] * 100) for r in cur))
            if lab in ("all", "CE", "PE"):
                Fa = Fall if lab == "all" else Fall[Fall["side"] == (1 if lab == "CE" else -1)]
                if len(Fa) >= MIN_LAT:
                    ac, abase, eb = every_fire(Fa)
                    Jl[lab]["every_fire"] = {"n": int(len(Fa)), "curve": ac, "random_hit60": abase, "edge_budget": {"min": eb[0], "capped": eb[1]}}
                    P("    %-8s %5d EVERY FIRE (what a live ring gets) · EDGE BUDGET (HIT60 over random %.0f%%): %s" % (
                        lab, len(Fa), abase * 100, fb(eb) if eb[0] is not None else "no edge over random at once"))
                    P("             MFE60 " + " ".join("%6s" % f1(r["mfe"], "%.2f") for r in ac) + "   %")
                    P("             HIT60 " + " ".join("%5.0f%%" % (r["hit60"] * 100) for r in ac) + "   (random %.0f%%)" % (abase * 100))
                    P("             OPT   " + " ".join("%+6.1f" % r["opt"] for r in ac) + "   % of the premium after 1.5% costs")
                    P("             OPT3  " + " ".join("%+6.1f" % r["opt3"] for r in ac) + "   % after 3% costs")
                    P("             LEFT  " + " ".join("%6s" % f1(r["ml"], "%.2f") for r in ac) + "   %")
    P("  THE BUDGET SPLIT (ASSUMED, not measured here): the data ~5-10 s after the candle closes (Kite's candle is known only at t+1:00), the AI")
    P("  10-60 s (one short call; a second GO NOW check only if it fits), the phone ring 2-10 s. Anything over the budget is paid out of the move.")
    P("  HFT caveat: minute candles hide moves inside the minute, so fast moves look better here than they were.")

    # 6 ---- RINGS
    P("\n=== 6. RINGS - how often the phone would ring, every share, both sides (the limit: 50 a day, 6 in any 15 minutes)")
    J["rings"] = {}
    for sm in range(NSM):
        day, m15, _ = S.rings(sm)
        rd = day[days]; r15 = m15[days]
        dce = S.rings(sm, 1)[0][days]; dpe = S.rings(sm, -1)[0][days]
        J["rings"][smname(sm)] = {"p50": q(rd, 50), "p90": q(rd, 90), "max": float(rd.max()) if len(rd) else 0, "r15_p50": q(r15, 50),
                                  "r15_p90": q(r15, 90), "r15_max": float(r15.max()) if len(r15) else 0, "ce_p50": q(dce, 50), "pe_p50": q(dpe, 50)}
    lines = sorted(J["rings"].items(), key=lambda x: x[1]["p90"])
    for nm_, r in lines:
        P("  %-16s a day: median %4.0f (CE %3.0f, PE %3.0f) · p90 %4.0f · max %4.0f   busiest 15 min: median %3.0f · p90 %3.0f · max %3.0f%s" % (
            nm_, r["p50"], r["ce_p50"], r["pe_p50"], r["p90"], r["max"], r["r15_p50"], r["r15_p90"], r["r15_max"],
            "" if (r["p90"] <= 50 and r["r15_p90"] <= 6) else "   (over the limit)"))

    # 7 ---- PER SIGNAL
    P("\n=== 7. EVERY SIGNAL - first fire of the day · all days · +1% (+2%) its way before -0.6% against within 60 min (EOD = by 15:10) · "
      "FALSE = -0.6% first or < 0.5% in 60 min · RANDOM = the same from every minute of the same time bucket, same share, side and half-year")
    for k_ in range(NS):
        F = S.fset(k_); F = F[days[F["g"]]]
        sm = 2 * k_
        if not len(F):
            P("\n--- %s · %s · no fires" % (SETS[k_], DESC[SETS[k_]])); continue
        P("\n--- %s · %s · %d first fires" % (SETS[k_], DESC[SETS[k_]], len(F)))
        J["sets"][smname(sm)]["detail"] = det = {}
        bk = F["tag"] & 3; sec = (F["tag"] >> 2) & 3; gp = (F["tag"] >> 4) & 1
        nk = NKIND[F["g"]]; ex = EXP[F["g"]]; yr = YEAR[F["g"]]; hv = HALF[F["g"]]
        spl = [("CE", F["side"] == 1), ("PE", F["side"] == -1)]
        spl += [(BNAME[b], bk == b) for b in range(4)]
        spl += [("sector NONE", sec == 0), ("sector FORMING", sec == 1), ("sector CONFIRMED", sec == 2)]
        spl += [("NIFTY up day", nk == 0), ("NIFTY down day", nk == 1), ("NIFTY mixed", nk == 2)]
        spl += [("expiry day", ex), ("not expiry", ~ex), ("GAP day", gp == 1), ("no gap", gp == 0)]
        spl += [("OI yday LB/SC", np.isin(F["oi"], (1, 3))), ("OI yday SB/LU", np.isin(F["oi"], (2, 4)))]
        spl += [(str(y), yr == y) for y in sorted(set(yr.tolist()))]
        spl += [(HNAME[h], hv == h) for h in sorted(set(hv.tolist()))]
        spl += [("tuning days", TRAIN[F["g"]]), ("HELD OUT", ~TRAIN[F["g"]])]
        for lab, mk in [("all", np.ones(len(F), bool))] + spl:
            f = F[mk]; n = len(f)
            if n < 20:
                continue
            h1 = float((f["fl"] & 1).mean()); h2 = float(((f["fl"] >> 1) & 1).mean()); e1 = float(((f["fl"] >> 2) & 1).mean())
            e2 = float(((f["fl"] >> 3) & 1).mean()); fa = float(((f["fl"] >> 4) & 1).mean()); bh = float(f["bh"].astype(np.float64).mean())
            det[lab] = {"n": n, "hit1": h1, "hit2": h2, "eod1": e1, "eod2": e2, "false": fa, "base": bh, "lift": rt(h1, bh)}
            P("    %-18s %7d · hit +1%% %3.0f%% (+2%% %3.0f%%) · EOD %3.0f%% (%3.0f%%) · false %3.0f%% · random %3.0f%% · LIFT %.2f" % (
                lab, n, h1 * 100, h2 * 100, e1 * 100, e2 * 100, fa * 100, bh * 100, rt(h1, bh)))
        if "all" in det:
            ci = boot(np.bincount(F["g"], weights=(F["fl"] & 1).astype(np.float64), minlength=G), np.bincount(F["g"], minlength=G).astype(np.float64), S.W)
            det["all"]["hit1_ci"] = ci
            P("    (hit +1%% 95%% interval by day %s-%s%%)" % (f1(ci[0] * 100, "%.0f"), f1(ci[1] * 100, "%.0f")))
        P("    CATCH (each move, its first fire from 15 min before its base):")
        det["catch"] = {}
        for lab_, key in (("from the open", "ampo"), ("from yday close", "amppc")):
            for X in TIERS:
                for d, side in ((1, "CE"), (-1, "PE")):
                    for cls, cm in (("", None), (" no-gap", 0), (" GAP", 1)):
                        mk = days[M["g"]] & (M[key] >= X) & (M["side"] == d) & (True if cm is None else (M["gap"] == cm))
                        if mk.sum() < 10 or (cls and key == "amppc"):
                            continue
                        c = S.catch(sm, mk); c2 = S.catch(sm + 1, mk)
                        det["catch"]["%s %s %s%s" % (key, X, side, cls)] = {"first": c, "rearm": c2}
                        if cls and X != 2.0:
                            continue
                        P("      %-15s %3.1f%%+ %s%-7s %6d · BEFORE %3.0f%% · EARLY %3.0f%% · LATE %3.0f%% · MISSED %3.0f%% (rang for an earlier swing %2.0f%%) · re-arm B+E %3.0f%%" % (
                            lab_, X, side, cls, c["n"], rt(c["before"], c["n"]) * 100, rt(c["early"], c["n"]) * 100, rt(c["late"], c["n"]) * 100,
                            rt(c["missed"], c["n"]) * 100, rt(c["prior"], c["n"]) * 100, c2["be"] * 100))
        g2 = F[(F["gr"] >= 1) & (F["gr"] <= 3) & (F["ampo"] >= 2.0)]
        cg = g2[(g2["gr"] == 1) | (g2["gr"] == 2)]
        if len(g2) >= 10:
            ml0 = cg["ml"][:, 0].astype(np.float64); frac = ml0 / np.maximum(cg["bp"].astype(np.float64), 1e-6)
            t1 = cg["tt1"][cg["tt1"] < 999]; t2 = cg["tt2"][cg["tt2"] < 999]
            det["lead"] = {"graded_n": int(len(g2)), "lead_med_all": q(g2["lead"], 50), "caught_n": int(len(cg)), "lead_med_caught": q(cg["lead"], 50),
                           "to1_med": q(t1, 50), "to2_med": q(t2, 50), "left_med": q(ml0, 50), "left_p25": q(ml0, 25), "left_frac_med": q(frac, 50),
                           "left_frac_p25": q(frac, 25)}
            P("    LEAD (onset - fire, + = early; the onset is 09:15 on open-drive moves) on 2%% moves: median %s min over %d graded fires, %s min over %d "
              "caught · minutes to +1%% %s, to +2%% %s · MOVE LEFT after a caught fire: median %s%% (p25 %s%%) = %s%% of base->peak (p25 %s%%)" % (
                  f1(det["lead"]["lead_med_all"], "%+.0f"), len(g2), f1(det["lead"]["lead_med_caught"], "%+.0f"), len(cg), f1(det["lead"]["to1_med"], "%.0f"),
                  f1(det["lead"]["to2_med"], "%.0f"), f1(det["lead"]["left_med"], "%.2f"), f1(det["lead"]["left_p25"], "%.2f"),
                  f1(det["lead"]["left_frac_med"] * 100, "%.0f"), f1(det["lead"]["left_frac_p25"] * 100, "%.0f")))
        # the option proxy: the 60-min trade (+1% / -0.6% / the close at 60 min) x 0.5 delta on a ~2.5% premium, less 1.5-3% round trip
        r0 = F["r0"].astype(np.float64); r2 = F["r2"].astype(np.float64)
        op0 = DELTA * r0 / PREM * 100; op2 = DELTA * r2 / PREM * 100
        det["option"] = {"share_r60_mean": float(r0.mean()), "opt_d0_mean_cost15": float(op0.mean() - COSTS[0]), "opt_d0_mean_cost3": float(op0.mean() - COSTS[1]),
                         "opt_d2_mean_cost15": float(op2.mean() - COSTS[0]), "opt_d2_mean_cost3": float(op2.mean() - COSTS[1])}
        P("    OPTION PROXY (60-min trade x 0.5 delta / a 2.5%% premium): entered at once %+.1f%% / %+.1f%% of the premium after 1.5%% / 3%% costs · "
          "entered 2 min late %+.1f%% / %+.1f%%" % (det["option"]["opt_d0_mean_cost15"], det["option"]["opt_d0_mean_cost3"],
                                                     det["option"]["opt_d2_mean_cost15"], det["option"]["opt_d2_mean_cost3"]))

    # 8 ---- BASELINE
    P("\n=== 8. RANDOM MINUTES (the baseline every lift is measured against), all shares, all half-years")
    for sidx, side in ((0, "CE"), (1, "PE")):
        cells = []
        for b in range(4):
            c = S.BC[sidx, b].sum()
            x = S.BS[sidx, b].sum(0)
            cells.append("%s: +1%% %2.0f%% +2%% %2.0f%% false %2.0f%%" % (BNAME[b], rt(x[0], c) * 100, rt(x[1], c) * 100, rt(x[3], c) * 100))
            J["baseline"]["%s %s" % (side, BNAME[b])] = {"hit1": rt(x[0], c), "hit2": rt(x[1], c), "eod1": rt(x[2], c), "false": rt(x[3], c)}
        P("  %s  %s" % (side, " · ".join(cells)))

    # 9 ---- BIASES
    P("\n=== 9. WHAT THIS CAN AND CANNOT SAY")
    for x in ("NO LOOK-AHEAD: every signal at minute t uses that day's minutes 0..t only; the volume history uses only the 20 days before;",
              "  yesterday's futures OI (NSE's day D-1 file) is used on day D, day D's OI never before D+1; the sector and NIFTY only up to t;",
              "  the move labels (onset, breakout, peak, P25 / P50) use hindsight and are never an input (they only grade the fires).",
              "  minutes before a share's first real candle of the day hold its open and no signal fires there (not tradable).",
              "YESTERDAY is the previous market day (NIFTY's calendar): a share with no full row for it is skipped that day (no older close, high,",
              "  low or OI is used in its place).",
              "THE ONSET is 'the first close 0.3% off the base': on an open-drive move it is 09:15 and the LEAD / BEFORE of a signal on it is",
              "  measured from the open, not from the breakout. Read P25 / P50 / +1% as the timing; the breakout minute (BRK) is a second label.",
              "sectors.json is TODAY's sector list - a share that changed sector is in today's. Buckets of unrelated shares (names with 'other',",
              "  'misc', ...) are treated as no sector; a broad real bucket (e.g. 'nbfc & finance') still gives breadth over loosely related shares.",
              "the F&O list is TODAY's - shares that left F&O are missing; days a share was not in F&O are left out when NSE's file has the day.",
              "  RENAMED shares (%s) are read with their old NSE symbol too; a rename not in that list loses its pre-rename" % ", ".join(
                  "%s<-%s" % (k_, "/".join(v)) for k_, v in ALIAS.items()),
              "  days (the header lists any share that lost 20%+ of its days this way).",
              "a weekend FULL session (the 1 Feb 2025 budget day) is a market day like any other; short special sessions are not.",
              "the store's coverage by half-year is in the header: a store half-way through its 3 -> 5 year extension mixes two universes.",
              "grid() fills a missing minute with the last price - illiquid shares look smoother than they traded (listed above).",
              "the 09:15 candle includes the pre-open; circuit days are included.",
              "SPLITS / BONUSES: whether Kite's minute history is adjusted for them was not checked by hand. A day whose open is 20%+ off the",
              "  share's last close is taken as an unadjusted split / bonus: that day AND the share's next 20 days are left out, because RVOL /",
              "  RVOL5 (the 20-day volume median) and yesterday's high / low would still be in pre-split units (the header lists them; none found",
              "  means the history is adjusted). A split under 20% (e.g. some 5:4 bonuses) is not caught: its volume reads ~1.25x for 20 days.",
              "only the %d combinations fixed BEFORE the run were tried (plus 4 unions of them), to limit luck from testing many ideas;" % len(COMBOS),
              "  the winners were picked on the tuning days only and the last 6 months are shown unchanged.",
              "minute candles hide moves inside the minute: a fast move looks better here than it was to trade (the HFT caveat).",
              "MOVE LEFT is to the day's best price after the entry - nobody sells the exact top; read it as the room, not the profit.",
              "the option proxy is the share's move x 0.5 delta on an assumed ~2.5% premium, less 1.5-3% round trip - no option history exists.",
              "the budget split (data / AI / phone seconds) is assumed, not measured; only the minutes come from the data.",
              "NIFTY's day type (up / down / mixed) uses the day's close - a split for reading, never an input.",
              "expiry days: the last Thursday of the month until Aug 2025, the last Tuesday from Sep 2025 (NSE's change), a holiday moves it back;",
              "  a month whose expiry is still ahead of the store's last day is not flagged.",
              "a fire up to 15 min before a move's base counts for it; earlier fires that day count as MISSED ('rang for an earlier swing').",
              "18 / 16 Nov are inside the held-out months; they are reported in section 4 only and never decide which set is picked. Their",
              "  population is the old scorecard's (close 2%+ on yesterday's close); the old 35 / 22 'before' is that scorecard's own definition."):
        P("  " + x)

    # 0 ---- THE ANSWER (put at the top)
    top = []
    A = lambda *a: top.append(" ".join(str(x) for x in a))
    A("\n=== 0. THE ANSWER IN PLAIN WORDS (CE and PE apart · signals picked on the tuning days, numbers over all days unless marked)")
    if mixed:
        A("  !! the store is MIXED (see the header): read this after the extension finishes, or re-run with --years 3")
    base_days = tr if tr.any() else days
    elig = [sm for sm, s, qf in rows if qf["b"]]
    J["summary"] = {}
    ringX = {}
    pc_ = lambda a, b: (a / float(b) * 100) if b else 0.0
    ci_ = lambda c: "%s-%s" % (f1(c[0], "%.2f"), f1(c[1], "%.2f"))
    for d, side in ((1, "CE"), (-1, "PE")):
        Js = J["summary"][side] = {}
        mk = days[M["g"]] & (M["ampo"] >= 2.0) & (M["side"] == d); n = int(mk.sum())
        A("  %s (the share going %s):" % (side, "UP" if d > 0 else "DOWN"))
        if n < 5:
            A("    too few 2%% moves (%d) to say" % n); continue
        m_ = M[mk]
        odm = m_["tb"] == 0
        od = float(odm.mean()); gp = float((m_["gap"] == 1).mean()); og = float((odm | (m_["gap"] == 1)).mean())
        nod = int(odm.sum()); odl = int((odm & (m_["p25"] >= 15)).sum()); odb = int((odm & (m_["brk"] >= 15)).sum())
        reach_all = (n - nod + odl) / n
        Js.update({"moves": n, "per_day": n / max(nd, 1), "open_drive": od, "gap": gp, "open_drive_or_gap": og,
                   "od_p25_after_0930": rt(odl, nod), "od_brk_15plus": rt(odb, nod), "warnable": reach_all,
                   "to_p25": q(m_["p25"] - m_["onset"], 50), "to_p50": q(m_["p50"] - m_["onset"], 50), "brk_to_p50": q(m_["p50"] - m_["brk"], 50)})
        A("    THE MOVES: %.1f 2%%+ moves a day. %.0f%% start AT 09:15 (open-drive) and %.0f%% come with a 1%%+ gap (%.0f%% one or the other)."
          % (n / max(nd, 1), od * 100, gp * 100, og * 100))
        A("      On an open-drive move the onset is 09:15 by rule, so the BEFORE rule (a ring by 09:17) can never count a warning there. But %.0f%%"
          % pc_(odl, nod))
        A("      of them are a quarter done only at / after 09:30 and %.0f%% break out (BRK) 15+ min after 09:15: a signal can still warn of those,"
          % pc_(odb, nod))
        A("      graded by timing in 1. So a warning could reach %.0f%% of the 2%% moves, not only the %.0f%% that are not open-drive. A move is a"
          % (reach_all * 100, (1 - od) * 100))
        A("      quarter done %s min and half done %s min after its onset; half done %s min after its breakout minute."
          % (f1(Js["to_p25"], "%.0f"), f1(Js["to_p50"], "%.0f"), f1(Js["brk_to_p50"], "%.0f")))
        st = {sm: S.side_stats(sm, base_days, d) for sm in elig}
        cand = [sm for sm in elig if st[sm]["all"]["before"] + st[sm]["all"]["early"] >= FLOOR_N]
        if not cand:
            A("    no signal set rings within 50 a day / 6 in 15 min AND catches %d+ of these moves early - nothing to name yet" % FLOOR_N)
            continue
        # 1 THE EARLY WARNING: the most 2% moves warned of in time - BEFORE on the not-open-drive moves, before a quarter is done on the
        # open-drive ones (timing only: the BEFORE rule cannot count those)
        warned = lambda sm: st[sm]["not_od"]["before"] + st[sm]["od"]["b25"]
        ew = max(cand, key=lambda sm: (rt(warned(sm), st[sm]["all"]["n"]), st[sm]["all"]["be"]))
        se = st[ew]; o_ = se["od"]
        reach = se["not_od"]["n"] + o_["p25_late"]                       # the moves a warning could reach (tuning days)
        wr = {sm: rt(st[sm]["not_od"]["before"] + st[sm]["od"]["b25_late"], reach) for sm in cand} if reach else {}
        he = S.side_stats(ew, te, d) if te.any() else None
        bef = rt(se["not_od"]["before"], se["not_od"]["n"]) if se["not_od"]["n"] else 0.0
        if o_["bbrk"] is not None and o_["brk_late"]:
            btx = "by the breakout on %.0f%% of those breaking out 15+ min after 09:15" % pc_(o_["bbrk"], o_["brk_late"])
        elif o_["dhb"]:
            btx = "no BRK grade (a day-high / low break set: the breakout label is its own shape)"
        else:
            btx = "no late breakouts to grade"
        A("    1 EARLY WARNING: %s (%s)" % (smname(ew), DESC[SETS[ew // 2]]))
        A("      BEFORE on %.0f%% of the not-open-drive moves (median lead %s min on their onset, + = before it) · on the open-drive moves, by"
          % (bef * 100, f1(se["lead_not_od"], "%+.0f")))
        A("      timing only: before a quarter is done on %.0f%% (%.0f%% of those a quarter done only at / after 09:30), %s"
          % (pc_(o_["b25"], o_["n"]), pc_(o_["b25_late"], o_["p25_late"]), btx))
        A("      in all it warns of %.0f%% of the 2%% moves in time (%.0f%% of those a warning could reach) · early (B+E) %.0f%% · lift %.2f (95%% %s)"
          " · +1%% before -0.6%% %.0f%% vs %.0f%% at random%s" % (
              rt(warned(ew), se["all"]["n"]) * 100, wr.get(ew, 0.0) * 100, se["all"]["be"] * 100, se["lift"], ci_(se["lift_ci"]), se["hit1"] * 100,
              se["base"] * 100, "" if he is None else "; held out: warns of %.0f%%" % (rt(he["not_od"]["before"] + he["od"]["b25"], he["all"]["n"]) * 100
                                                                                       if he["all"]["n"] else 0)))
        if not (np.isfinite(se["lift_ci"][0]) and se["lift_ci"][0] > ALARM_CI):
            A("      !! its lift is not above random (95%% low %s <= %.1f): it rings in time, but no better than a random minute" % (
                f1(se["lift_ci"][0], "%.2f"), ALARM_CI))
        nd_ = [sm for sm in cand if st[sm]["od"]["bbrk"] is not None and st[sm]["od"]["brk_late"]]
        if nd_:
            bb_ = max(nd_, key=lambda sm: st[sm]["od"]["bbrk"])
            A("      by the BREAKOUT (sets not built on the day-high / low break, so BRK is not graded against itself): best %s on %.0f%% of the"
              " open-drive moves breaking out 15+ min after 09:15 (lift %.2f, 95%% %s)" % (
                  smname(bb_), pc_(st[bb_]["od"]["bbrk"], st[bb_]["od"]["brk_late"]), st[bb_]["lift"], ci_(st[bb_]["lift_ci"])))
            Js["by_breakout_best"] = {"set": smname(bb_), "rate": rt(st[bb_]["od"]["bbrk"], st[bb_]["od"]["brk_late"])}
        wedge = {sm: v for sm, v in wr.items() if np.isfinite(st[sm]["lift_ci"][0]) and st[sm]["lift_ci"][0] > ALARM_CI}
        bw = max(wedge, key=wedge.get) if wedge else None
        ba = max(wr, key=wr.get) if wr else None
        Js["warning_verdict"] = {"reach": reach, "best_with_edge": smname(bw) if bw is not None else None,
                                 "best_with_edge_rate": wedge[bw] if bw is not None else None, "best_any": smname(ba) if ba is not None else None,
                                 "best_any_rate": wr[ba] if ba is not None else None}
        if bw is not None and wedge[bw] >= 0.10:
            A("      an intraday signal CAN warn in time: %s on %.0f%% of the moves a warning could reach, with a lift above random. The pre-open /"
              % (smname(bw), wedge[bw] * 100))
            A("      GET READY card is still the only warning for the open-drive moves a quarter done before 09:30 (%.0f%% of all 2%% moves)."
              % ((nod - odl) / n * 100))
        elif ba is not None and wr[ba] >= 0.10:
            A("      !! signals ring in time on up to %.0f%% of the moves a warning could reach (%s), but none of those beats random (95%% low of the"
              % (wr[ba] * 100, smname(ba)))
            A("      lift <= %.1f): on this data no intraday early warning has an edge - the warning is the pre-open / evening GET READY card." % ALARM_CI)
        else:
            A("      !! even graded by timing on the open-drive moves, no intraday signal warns in time on 10%% of the moves a warning could reach"
              " (best %s %.0f%%):" % (smname(ba) if ba is not None else "-", (wr[ba] if ba is not None else 0) * 100))
            A("      the early warning has to be the pre-open / evening GET READY card with its trigger levels; the intraday signals are the alarm.")
        # 2 THE ALARM / CARD: only a set with an edge on this side
        ok = [sm for sm in cand if alarm_ok(st[sm])]
        fz = [sm for sm in frozen if sm in st and sm in cand and alarm_ok(st[sm])]
        if fz:
            al = fz[0]; why = "the first FROZEN winner, with an edge on this side"
        elif ok:
            al = max(ok, key=lambda sm: st[sm]["all"]["be"])
            why = "the best early catch among the sets with an edge on this side; nothing passed every rule"
        else:
            al = None
        rule = ("B+E >= %.0f%%, a lift over %.1f whose 95%% interval (by day) stays above %.1f, %d+ fires, on the tuning days" % (
            FLOOR_BE * 100, ALARM_LIFT, ALARM_CI, ALARM_MIN_FIRES))
        if al is None:
            nl = max(cand, key=lambda sm: st[sm]["lift_ci"][0] if np.isfinite(st[sm]["lift_ci"][0]) else -9)
            nb = max(cand, key=lambda sm: st[sm]["all"]["be"])
            A("    2 THE ALARM / CARD: NO ALARM WITH AN EDGE ON THIS SIDE (needs %s)." % rule)
            A("      closest by the lift: %s (early %.0f%%, lift %.2f, 95%% %s, %d fires) · the best catch: %s (early %.0f%%, lift %.2f, 95%% %s) - not a card"
              % (smname(nl), st[nl]["all"]["be"] * 100, st[nl]["lift"], ci_(st[nl]["lift_ci"]), st[nl]["n_fires"], smname(nb), st[nb]["all"]["be"] * 100,
                 st[nb]["lift"], ci_(st[nb]["lift_ci"])))
            if np.isfinite(st[nl]["lift_ci"][0]) and st[nl]["lift_ci"][0] > ALARM_CI:
                A("      NOTE: %s DOES beat random (95%% low %.2f > %.1f) but comes LATE (early only %.0f%% < %.0f%%): a late confirmation, not an early alarm."
                  " Whether it still pays after option costs: section 5, OVER EVERY ALARM (move left, option proxy after 1.5%% / 3%%)."
                  % (smname(nl), st[nl]["lift_ci"][0], ALARM_CI, st[nl]["all"]["be"] * 100, FLOOR_BE * 100))
                A("    3 REACTION BUDGET: none given for an early alarm (section 5 has the curves for the late confirmation sets).")
            else:
                A("    3 REACTION BUDGET: none given - with no alarm that beats random there is no edge for speed to keep (section 5 has the curves).")
            A("    4 MOVE LEFT after the alarm: - (no alarm on this side)")
            sa = None
        else:
            sa = st[al]
            ha = S.side_stats(al, te, d) if te.any() else None
            A("    2 THE ALARM / CARD: %s (%s; %s) - early on %.0f%%, missed %.0f%%, +1%% before -0.6%% %.0f%% vs %.0f%% at random (lift %.2f, 95%% %s,"
              " %d fires)%s" % (smname(al), DESC[SETS[al // 2]], why, sa["all"]["be"] * 100, rt(sa["all"]["missed"], sa["all"]["n"]) * 100, sa["hit1"] * 100,
                                sa["base"] * 100, sa["lift"], ci_(sa["lift_ci"]), sa["n_fires"],
                                "" if ha is None else "; held out: early %.0f%%, lift %.2f" % (
                                    ha["all"]["be"] * 100 if np.isfinite(ha["all"]["be"]) else 0, ha["lift"] if np.isfinite(ha["lift"]) else 0)))
            if ha is not None and not (np.isfinite(ha["lift"]) and ha["lift"] > 1.0):
                A("      !! it did NOT hold out: on the held-out months its lift is %s - treat it as unproven" % f1(ha["lift"], "%.2f"))
            F = S.fset(al // 2); F = F[days[F["g"]]]          # the first fire of the day (a re-arm set: its first fire too)
            Fs = F[F["side"] == d]
            cf = Fs[((Fs["gr"] == 1) | (Fs["gr"] == 2)) & (Fs["ampo"] >= 2.0)]
            ac, abase, eb = every_fire(Fs) if len(Fs) else (None, float("nan"), (None, None))
            if len(cf) >= min(10, MIN_LAT) and ac is not None:
                cur = lat_curve(cf); fm = ((cf["tag"] >> 5) & 1) == 1
                bm, bh, bo = budget(cur, "mfe"), budget(cur, "hit60"), budget(cur, "opt")
                fcur = lat_curve(cf[fm]) if fm.sum() >= 10 else None
                A("    3 REACTION BUDGET (data + AI + phone, from the candle's close): over EVERY alarm, its edge over random (+1%% before -0.6%%"
                  " %.0f%% vs %.0f%% at once) keeps 90%% up to %s;" % (ac[0]["hit60"] * 100, abase * 100, fb(eb) if eb[0] is not None else "- (no edge)"))
                A("      ON THE MOVES IT CAUGHT (hindsight, an upper bound): %s by the best move in 60 min, %s by +1%% before -0.6%%, %s by the option"
                  " proxy%s." % (fb(bm), fb(bh), fb(bo), "" if fcur is None else "; on the FAST moves (%d): %s by MFE60" % (int(fm.sum()), fb(budget(fcur, "mfe")))))
                bmin = [x[0] for x in (eb, bm, bh, bo) if x[0] is not None]
                if eb[0] is None or not bmin:
                    fit = "there is no edge at once to keep, so the speed does not decide it"
                elif min(bmin) >= 1:
                    fit = "so one AI call (10-60 s) fits inside the tightest of these (%d min)" % min(bmin)
                else:
                    fit = "even one AI call eats into it: ring on the rule first and let the AI check after"
                A("      Of it, ASSUMED (not measured): data 5-10 s, AI 10-60 s, phone 2-10 s - %s." % fit)
                A("    4 MOVE LEFT after the alarm (median; LEFT = to 15:10, MFE60 = the best move in 60 min; entered at once / two minutes later):")
                A("      ON THE MOVES IT CAUGHT (%d, hindsight): LEFT %s%% / %s%% · MFE60 %s%% / %s%% · +1%% before -0.6%% %.0f%% / %.0f%% · option proxy "
                  "%+.1f%% / %+.1f%% of the premium after 1.5%% costs" % (len(cf), f1(cur[0]["ml"], "%.2f"), f1(cur[2]["ml"], "%.2f"), f1(cur[0]["mfe"], "%.2f"),
                                                                         f1(cur[2]["mfe"], "%.2f"), cur[0]["hit60"] * 100, cur[2]["hit60"] * 100, cur[0]["opt"], cur[2]["opt"]))
                A("      OVER EVERY ALARM (%d, what a live ring gets): LEFT %s%% / %s%% · MFE60 %s%% / %s%% · +1%% before -0.6%% %.0f%% / %.0f%% (random %.0f%%)"
                  " · option proxy %+.1f%% / %+.1f%% after 1.5%% costs, %+.1f%% / %+.1f%% after 3%%" % (
                      len(Fs), f1(ac[0]["ml"], "%.2f"), f1(ac[2]["ml"], "%.2f"), f1(ac[0]["mfe"], "%.2f"), f1(ac[2]["mfe"], "%.2f"), ac[0]["hit60"] * 100,
                      ac[2]["hit60"] * 100, abase * 100, ac[0]["opt"], ac[2]["opt"], ac[0]["opt3"], ac[2]["opt3"]))
                Js["budget"] = {"edge_every_alarm": eb, "caught_mfe": bm, "caught_hit60": bh, "caught_opt": bo,
                                "caught_fast_mfe": budget(fcur, "mfe") if fcur else None}
                Js["left_caught"] = {"n": int(len(cf)), "d0": cur[0]["ml"], "d2": cur[2]["ml"], "mfe_d0": cur[0]["mfe"], "mfe_d2": cur[2]["mfe"],
                                     "hit60_d0": cur[0]["hit60"], "opt_d0": cur[0]["opt"]}
                Js["left_every_alarm"] = {"n": int(len(Fs)), "d0": ac[0]["ml"], "d2": ac[2]["ml"], "mfe_d0": ac[0]["mfe"], "mfe_d2": ac[2]["mfe"],
                                          "hit60_d0": ac[0]["hit60"], "hit60_d2": ac[2]["hit60"], "random_hit60": abase, "opt_d0": ac[0]["opt"],
                                          "opt_d2": ac[2]["opt"], "opt3_d0": ac[0]["opt3"], "opt3_d2": ac[2]["opt3"]}
            else:
                A("    3 / 4 REACTION BUDGET and MOVE LEFT: too few caught %s moves (%d) for the alarm set" % (side, len(cf)))
        # 5 RINGS: the early warning and the alarm are separate rings
        Xe = S.rings(ew, d)[2]; re_ = ring_stats(Xe, days); X = Xe.copy()
        cells = ["early warning %s %s / %s (15 min %s / %s)" % (smname(ew), f1(re_["p50"], "%.0f"), f1(re_["p90"], "%.0f"), f1(re_["r15_p50"], "%.0f"),
                                                                f1(re_["r15_p90"], "%.0f"))]
        if al is not None and al != ew:
            Xa = S.rings(al, d)[2]; ra_ = ring_stats(Xa, days); X = X + Xa
            cells.append("alarm %s %s / %s (15 min %s / %s)" % (smname(al), f1(ra_["p50"], "%.0f"), f1(ra_["p90"], "%.0f"), f1(ra_["r15_p50"], "%.0f"),
                                                               f1(ra_["r15_p90"], "%.0f")))
        elif al is not None:
            cells.append("the alarm is the same set")
        else:
            cells.append("no alarm")
        rt_ = ring_stats(X, days); ringX[side] = X
        A("    5 RINGS on the %s side, a day median / p90 (the day's busiest 15 min median / p90): %s · together %s / %s (15 min %s / %s)" % (
            side, " · ".join(cells), f1(rt_["p50"], "%.0f"), f1(rt_["p90"], "%.0f"), f1(rt_["r15_p50"], "%.0f"), f1(rt_["r15_p90"], "%.0f")))
        Js["rings"] = {"early_warning": re_, "together": rt_}
        cs_ = S.side_stats(2 * SETS.index("CONF"), base_days, d)
        A("    (for comparison, waiting for the sector CONFIRMED: early on %.0f%%, missed %.0f%%)" % (
            cs_["all"]["be"] * 100 if np.isfinite(cs_["all"]["be"]) else 0, rt(cs_["all"]["missed"], cs_["all"]["n"]) * 100 if cs_["all"]["n"] else 0))
        Js.update({"early_warning": smname(ew), "alarm": smname(al) if al is not None else None, "alarm_why": why if al is not None else "no edge",
                   "ew": se, "al": sa})
    if ringX:
        r_ = ring_stats(sum(ringX.values()), days)
        A("  RINGS, BOTH SIDES, every set named above: a day median %s, p90 %s · the day's busiest 15 min median %s, p90 %s (the limits: 50 a day,"
          " 6 in 15 min)" % (f1(r_["p50"], "%.0f"), f1(r_["p90"], "%.0f"), f1(r_["r15_p50"], "%.0f"), f1(r_["r15_p90"], "%.0f")))
        J["summary"]["rings_both"] = r_
    out[TOP:TOP] = top
    P("\n(%.1f min · the fires and the moves are kept in %s/movestudy_fires.npz)" % ((time.time() - t0) / 60, STORE))
    return "\n".join(out), J


# ------------------------------------------------------------------ commands ------------------------------------------------------------------
def market_hours():
    n = dt.datetime.now(IST)
    return n.weekday() < 5 and "09:00" <= n.strftime("%H:%M") < "15:35"


def check():
    print("store: %s" % STORE)
    if not os.path.isdir(MIN_DIR):
        print("no minute files yet (%s) - run histstore.py get first" % MIN_DIR); return
    f = sorted(x[:-4] for x in os.listdir(MIN_DIR) if x.endswith(".npz"))
    sh_ = [x for x in f if x not in NOT_SHARES]
    print("minute files: %d shares + %s" % (len(sh_), ", ".join(x for x in f if x in NOT_SHARES) or "NO index files"))
    if "NIFTY" not in f:
        print("NIFTY.npz is missing - the study needs it"); return
    ts = np.load(os.path.join(MIN_DIR, "NIFTY.npz"))["ts"]
    loc = (np.asarray(ts, np.int64) + 19800) // 86400
    du, dc = np.unique(loc, return_counts=True)
    days = du[dc >= 300]                                  # full sessions (a full Saturday session counts, Muhurat does not)
    print("NIFTY: %d market days · %s -> %s · %.1f years" % (len(days), dday(days[0]), dday(days[-1]), len(days) / 248.0))
    for ds in ANCHOR:
        dn = (dt.date.fromisoformat(ds) - dt.date(1970, 1, 1)).days
        print("  %s in the store: %s" % (ds, "yes" if dn in set(days.tolist()) else "not yet"))
    # how many shares cover each half-year: while histstore.py extends the store from 3 to 5 years the early half-years are thin
    hn = lambda x: "%d H%d" % (dday(x).year, 1 if dday(x).month <= 6 else 2)
    halves = sorted({hn(x) for x in days}); hix = {h: i for i, h in enumerate(halves)}
    dset = set(days.tolist()); cnt = np.zeros(len(halves), int)
    for x in sh_:
        try:
            t_ = np.load(os.path.join(MIN_DIR, x + ".npz"))["ts"]
        except Exception:
            continue
        u, c_ = np.unique((np.asarray(t_, np.int64) + 19800) // 86400, return_counts=True)
        u = [int(a_) for a_, b_ in zip(u, c_) if b_ >= 200 and int(a_) in dset]
        hc = np.bincount([hix[hn(a_)] for a_ in u], minlength=len(halves)) if u else np.zeros(len(halves), int)
        cnt += hc >= 20
    print("shares with 20+ days in each half-year: " + " · ".join("%s %d" % (h, c_) for h, c_ in zip(halves, cnt)))
    if len(cnt) > 1 and cnt[:-1].min() < 0.85 * np.median(cnt):
        print("  !! the early half-years have far fewer shares: the store is still being extended (or some shares are short). Wait for")
        print("  !! histstore.py to finish, or run with --years 3 - a mixed store skews the half-year rule and the tuning / held-out split.")
    try:
        J = json.load(open(os.path.join(STORE, "fo_daily.json")))
        print("NSE daily futures file: %d days · %d shares" % (len(J.get("done", [])), len(J.get("d", {}))))
    except Exception:
        print("NSE daily futures file: none (OI filters will be empty, the F&O-listing check is skipped)")
    try:
        sec = json.load(open(os.path.join(STORE, "sectors.json")))
        inn = {x for v in sec.values() for x in v} & set(sh_)
        big = sum(1 for v in sec.values() if len(set(v) & set(sh_)) >= 5)
        print("sectors: %d · %d of the shares in a sector · %d sectors with 5+ shares (the breadth needs 4 others)" % (len(sec), len(inn), big))
    except Exception:
        print("sectors.json: none (the sector signals will be empty)")
    nw = max(1, (os.cpu_count() or 2) - 1)
    print("about %.0f-%.0f min with %d workers (nothing was run)" % (len(sh_) * len(days) * 0.0035 / nw / 60 * 0.7, len(sh_) * len(days) * 0.0035 / nw / 60 * 1.4, nw))


def run(args):
    t0 = time.time()
    if not os.path.exists(os.path.join(MIN_DIR, "NIFTY.npz")):
        print("no store yet - run histstore.py get first"); return
    try:
        os.nice(10)
    except Exception:
        pass
    names = setup(args.get("years"), args.get("shares"))
    if args.get("shares"):
        miss = [s for s in args["shares"] if s not in SHIDX]
        if miss:
            print("not in the store: %s" % ", ".join(miss))
    tasks = []
    for sec, mem in SEC.items():
        if ONLY and not (set(mem) & ONLY):
            continue
        tasks.append((sec, mem))
    tasks.sort(key=lambda x: -len(x[1]))
    import multiprocessing as mp
    nw = args.get("workers") or max(1, (os.cpu_count() or 2) - 1)
    print("=== the onset study · %d shares in %d sector groups · %d market days (%s -> %s) · %d workers · NSE file %d days" % (
        sum(len(m) for _, m in tasks), len(tasks), G - GLO, dday(CAL[GLO]), dday(CAL[-1]), nw, len(FODAYS)), flush=True)
    res = []
    if nw == 1:
        it = map(run_group, tasks)
        for i, r in enumerate(it):
            res.append(r)
            print("  %d of %d groups · %s (%d shares, %.0f s) · %.0f s" % (i + 1, len(tasks), r["sec"], r["n"], r["secs"], time.time() - t0), flush=True)
    else:
        with mp.get_context("fork").Pool(nw) as pool:
            for i, r in enumerate(pool.imap_unordered(run_group, tasks, chunksize=1)):
                res.append(r)
                print("  %d of %d groups · %s (%d shares, %.0f s) · %.0f s" % (i + 1, len(tasks), r["sec"], r["n"], r["secs"], time.time() - t0), flush=True)
    print("  pass A + B done · %.0f s · %d first fires · %d moves · now the tables" % (time.time() - t0, sum(len(r["F"]) for r in res), sum(len(r["M"]) for r in res)), flush=True)
    S = Study(res, names)
    del res
    rep, J = report(S, t0, args)
    print(rep)
    fn = os.path.join(STORE, "movestudy_report.txt")
    open(fn, "w").write(rep + "\n")
    open(os.path.join(STORE, "movestudy_%s.txt" % dt.date.today()), "w").write(rep + "\n")
    json.dump(J, open(os.path.join(STORE, "movestudy.json"), "w"), default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o), indent=1)
    np.savez_compressed(os.path.join(STORE, "movestudy_fires.npz"), fires=S.F, moves=S.M, grades=S.MG, lead=S.ML, names=np.array(names),
                        sets=np.array(SETS), days=CAL, grade_names=np.array(GRN))
    print("saved: %s (+ movestudy.json, movestudy_fires.npz)" % fn)
    return S, J


def parse(a):
    args = {}
    i = 0
    while i < len(a):
        if a[i] == "--years":
            args["years"] = float(a[i + 1]); i += 2
        elif a[i] == "--shares":
            args["shares"] = [x.strip().upper() for x in a[i + 1].split(",") if x.strip()]; i += 2
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
