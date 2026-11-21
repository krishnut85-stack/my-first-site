#!/bin/bash
# PATCH 86 - THE OI BUILD-UP STUDY, LAST YEAR AND THIS YEAR (works with any patch level; touches no running service).
#   oistudy.py downloads NSE's daily F&O file for every trading day from 1 Jan 2025 to yesterday (the same UDiFF bhavcopy
#   the server already reads; ~470 files, about 1 s each, resumes if stopped), boils each day down to one row per share
#   (futures price + OI over every month, volume, basis; the near-expiry option chain's walls, PCR, max pain, ATM premiums
#   and the four boxes on each side), then measures 49 daily OI build-up scenarios on the NEXT day's close, 2025 vs 2026,
#   each against that year's base rate - streaks, squeezes after shorts, breakouts with fresh OI, OI at a 20-day peak,
#   volume + OI surges, the futures premium, gaps held, roofs / floors broken at the close, PCR extremes, and the rest.
#   It runs in the background (nice) and writes data/oistudy.txt (the table) and data/oistudy.json when it is done.
D=/home/globalbot/intraday; W=/tmp/g86; mkdir -p $W
[ -f $D/oistudy.py ] && grep -q "THE OI BUILD-UP STUDY" $D/oistudy.py && echo "    oistudy.py is already there - replacing it with this version"
cat > $D/oistudy.py <<'PY_STUDY'
#!/usr/bin/env python3
"""oistudy.py - THE OI BUILD-UP STUDY: how open interest built up on every NSE stock F&O share, last year and this year,
and what the share did the next day. From NSE's own daily F&O files (the UDiFF bhavcopy the server already reads).

  python3 oistudy.py --fetch [FROM] [TO]   download + boil down every trading day (default 2025-01-01 .. yesterday); resumes
  python3 oistudy.py --study               every daily scenario, 2025 vs 2026: cases, right %, the base rate, the edge
  python3 oistudy.py --today               the shares where a scenario that HOLDS in both years fired on the latest day
  python3 oistudy.py --status              how many days are in
  python3 oistudy.py --test                the self-test (synthetic files, no network)

Each share-day is boiled down to one row (data/oistudy.db): the futures (price, OI and its change summed over every expiry,
volume, basis, days to expiry) and the near-expiry option chain within 10% of the price (calls and puts OI, the roof, the
floor, PCR, max pain, the at-the-money premiums, and the biggest strike in each of the four boxes on each side).
A scenario is measured on the NEXT trading day's close (and 3 days on): right % against the base rate of the same claim
on every share-day of that year. The edge = right % minus the base rate. A scenario HOLDS when it has 50+ cases, 55%+ right
and an edge of +3 points or more in BOTH years. A negative edge means the other side worked - it is shown, not hidden.
Daily scenarios are the day-scale version of the live agent's (scenarios.py); the day after an expiry is skipped for the
futures OI change (the expired month falls out of the total)."""
import os, io, re, sys, csv, json, time, zipfile, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core

BASE, DATA = core.BASE, core.DATA
DB = os.path.join(DATA, "oistudy.db")
OUT = os.path.join(DATA, "oistudy.json")
URL = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Referer": "https://www.nseindia.com/", "Accept": "*/*"}
BAND, WALL = 0.08, 0.10


def db(path=None):
    c = sqlite3.connect(path or DB, timeout=30)
    c.execute("create table if not exists fetched(d text primary key, status text, n int)")
    c.execute("create table if not exists day(d text, sym text, spot real, fc real, fo real, fh real, fl real, foi real, fdoi real, fvol real, basis real, "
              "dte int, exp text, oexp text, ce_oi real, pe_oi real, ce_doi real, pe_doi real, roof_k real, roof_oi real, floor_k real, floor_oi real, mp real, "
              "atm_k real, atm_ce real, atm_ce0 real, atm_pe real, atm_pe0 real, boxes text, strikes text, primary key(d, sym))")
    return c


def fnum(e, *names):
    for n in names:
        v = e.get(n)
        if v not in (None, "", "-"):
            try:
                return float(v)
            except ValueError:
                pass
    return None


def fdate(s):
    s = (s or "").strip()
    for f in ("%Y-%m-%d", "%d-%b-%Y", "%d-%m-%Y", "%d%b%Y", "%Y%m%d"):
        try:
            return dt.datetime.strptime(s, f).date()
        except ValueError:
            continue
    return None


def max_pain(ch):
    ks = sorted(ch)
    if len(ks) < 5:
        return None
    best = None
    for K in ks:
        pain = sum(max(0, K - k) * (ch[k][0] or 0) + max(0, k - K) * (ch[k][2] or 0) for k in ks)
        if best is None or pain < best[0]:
            best = (pain, K)
    return best[1]


def boil(txt, d, prev=None):
    """one NSE F&O day file -> {sym: row}. prev = {sym: yesterday's row} (only used if the file has no OI change / previous close)"""
    rd = csv.DictReader(io.StringIO(txt))
    cols = set(rd.fieldnames or [])
    need = {"FinInstrmTp", "TckrSymb", "XpryDt", "StrkPric", "OptnTp", "ClsPric", "UndrlygPric", "OpnIntrst"}
    if not need <= cols:
        raise ValueError("the NSE file has new columns - missing %s" % ", ".join(sorted(need - cols)))
    fut, opt = {}, {}
    for e in rd:
        tp = e.get("FinInstrmTp")
        if tp not in ("STF", "STO"):
            continue
        s = (e.get("TckrSymb") or "").strip()
        x = fdate(e.get("XpryDt"))
        if not s or not x or x < d:
            continue
        if tp == "STF":
            fut.setdefault(s, []).append((x, fnum(e, "ClsPric", "LastPric"), fnum(e, "OpnPric"), fnum(e, "HghPric"), fnum(e, "LwPric"), fnum(e, "OpnIntrst") or 0,
                                         fnum(e, "ChngInOpnIntrst"), fnum(e, "TtlTradgVol") or 0, fnum(e, "UndrlygPric")))
        else:
            k = fnum(e, "StrkPric"); kd = (e.get("OptnTp") or "").strip().upper()
            if k is None or kd not in ("CE", "PE"):
                continue
            opt.setdefault(s, []).append((x, k, kd, fnum(e, "OpnIntrst") or 0, fnum(e, "ChngInOpnIntrst"), fnum(e, "ClsPric", "LastPric") or 0, fnum(e, "PrvsClsgPric"), fnum(e, "UndrlygPric")))
    out = {}
    for s, fl in fut.items():
        fl.sort(key=lambda r: r[0])
        near = fl[0]
        spot = near[8] or (opt.get(s) and next((o[7] for o in opt[s] if o[7]), None)) or near[1]
        if not spot or not near[1]:
            continue
        p = (prev or {}).get(s) or {}
        foi = sum(r[5] for r in fl)
        fdoi = sum(r[6] for r in fl) if all(r[6] is not None for r in fl) else ((foi - p["foi"]) if p.get("foi") else None)
        row = {"d": str(d), "sym": s, "spot": spot, "fc": near[1], "fo": near[2], "fh": near[3], "fl": near[4], "foi": foi, "fdoi": fdoi,
               "fvol": sum(r[7] for r in fl), "basis": (near[1] / spot - 1) * 100, "dte": (near[0] - d).days, "exp": str(near[0])}
        ol = opt.get(s) or []
        if ol:
            oexp = min(o[0] for o in ol)
            ch = {}
            pst = json.loads(p["strikes"]) if p.get("strikes") and p.get("oexp") == str(oexp) else {}
            for x, k, kd, oi, doi, cl, pcl, u in ol:
                if x != oexp or abs(k / spot - 1) > WALL:
                    continue
                r = ch.setdefault(k, [0, None, 0, None, 0, None, 0, None])        # ce_oi, ce_doi, pe_oi, pe_doi, ce_cl, ce_pcl, pe_cl, pe_pcl
                j = 0 if kd == "CE" else 2
                if doi is None:
                    q = pst.get("%g" % k)
                    doi = (oi - q[j]) if q else None
                r[j], r[j + 1] = oi, doi
                r[4 + (0 if kd == "CE" else 2)], r[5 + (0 if kd == "CE" else 2)] = cl, pcl
            if ch:
                band = {k: v for k, v in ch.items() if abs(k / spot - 1) <= BAND}
                row.update({"oexp": str(oexp), "ce_oi": sum(v[0] for v in band.values()), "pe_oi": sum(v[2] for v in band.values()),
                            "ce_doi": sum((v[1] or 0) for v in band.values()), "pe_doi": sum((v[3] or 0) for v in band.values())})
                rf = max(((v[0], k) for k, v in ch.items() if k >= spot and v[0]), default=None)
                fl_ = max(((v[2], k) for k, v in ch.items() if k <= spot and v[2]), default=None)
                row.update({"roof_k": rf[1] if rf else None, "roof_oi": rf[0] if rf else None, "floor_k": fl_[1] if fl_ else None, "floor_oi": fl_[0] if fl_ else None,
                            "mp": max_pain(ch)})
                both = [k for k, v in ch.items() if v[4] and v[6]]
                if both:
                    ka = min(both, key=lambda k: abs(k - spot)); v = ch[ka]
                    row.update({"atm_k": ka, "atm_ce": v[4], "atm_ce0": v[5], "atm_pe": v[6], "atm_pe0": v[7]})
                maxwall = max([max(v[0], v[2]) for v in ch.values()] or [0])
                bx = {}
                for k, v in band.items():
                    for kd, (oi, doi, cl, pcl) in (("CE", (v[0], v[1], v[4], v[5])), ("PE", (v[2], v[3], v[6], v[7]))):
                        if doi is None or not pcl or pcl < 1 or not maxwall:
                            continue
                        oi0 = oi - doi
                        if abs(doi) < max(0.15 * max(oi, oi0), 0.10 * maxwall) or abs(cl - pcl) < 0.05 * pcl:
                            continue
                        box = ("bought" if cl > pcl else "written") if doi > 0 else ("running" if cl > pcl else "leaving")
                        ok = {("CE", "bought"): k >= spot * 0.97, ("CE", "written"): spot * 0.995 <= k <= spot * 1.03, ("CE", "running"): k >= spot * 0.98,
                              ("PE", "bought"): k <= spot * 1.03, ("PE", "written"): spot * 0.97 <= k <= spot * 1.005, ("PE", "running"): k <= spot * 1.02}.get((kd, box), True)
                        key = "%s_%s" % (kd, box)
                        if ok and (key not in bx or abs(doi) > abs(bx[key][1])):
                            bx[key] = [k, doi, oi0]
                row["boxes"] = json.dumps(bx, separators=(",", ":"))
                row["strikes"] = json.dumps({"%g" % k: [v[0], v[1], v[2], v[3]] for k, v in ch.items()}, separators=(",", ":"))
        out[s] = row
    return out


COLS = ["d", "sym", "spot", "fc", "fo", "fh", "fl", "foi", "fdoi", "fvol", "basis", "dte", "exp", "oexp", "ce_oi", "pe_oi", "ce_doi", "pe_doi", "roof_k", "roof_oi",
        "floor_k", "floor_oi", "mp", "atm_k", "atm_ce", "atm_ce0", "atm_pe", "atm_pe0", "boxes", "strikes"]


def store(c, rows):
    c.executemany("insert or replace into day(%s) values(%s)" % (",".join(COLS), ",".join("?" * len(COLS))), [tuple(r.get(k) for k in COLS) for r in rows.values()])


def prev_rows(c, d):
    p = c.execute("select max(d) from day where d < ?", (str(d),)).fetchone()[0]
    if not p:
        return {}
    cur = c.execute("select %s from day where d=?" % ",".join(COLS), (p,))
    return {r[1]: dict(zip(COLS, r)) for r in cur}


def fetch(d0, d1, getter=None, quiet=False):
    """download and boil down every weekday from d0 to d1 (resumes: a day already in is skipped)"""
    import requests
    s = requests.Session()
    get = getter or (lambda url: s.get(url, headers=UA, timeout=40))
    c = db()
    done = {r[0] for r in c.execute("select d from fetched where status in ('ok', 'none')")}
    d, fails, n_ok, t0 = d0, 0, 0, time.time()
    while d <= d1:
        if d.weekday() < 5 and str(d) not in done:
            try:
                r = get(URL % d.strftime("%Y%m%d"))
                if r.status_code == 404:
                    c.execute("insert or replace into fetched values(?,?,?)", (str(d), "none", 0)); c.commit()
                elif r.status_code != 200:
                    raise IOError("NSE answered %s" % r.status_code)
                else:
                    z = zipfile.ZipFile(io.BytesIO(r.content))
                    txt = z.read(z.namelist()[0]).decode("utf-8", "ignore")
                    rows = boil(txt, d, prev_rows(c, d))
                    store(c, rows)
                    c.execute("insert or replace into fetched values(?,?,?)", (str(d), "ok", len(rows))); c.commit()
                    n_ok += 1; fails = 0
                    if not quiet and n_ok % 10 == 0:
                        print("  %s: %d shares · %d days in this run · %.0f s" % (d, len(rows), n_ok, time.time() - t0), flush=True)
                time.sleep(0.4)
            except zipfile.BadZipFile:
                c.execute("insert or replace into fetched values(?,?,?)", (str(d), "none", 0)); c.commit()
            except ValueError as ex:
                print("STOP: %s (%s) - send me this line" % (ex, d)); break
            except Exception as ex:
                fails += 1
                print("  %s: %s" % (d, str(ex)[:80]), flush=True)
                if fails >= 6:
                    print("STOP: NSE is not answering (6 in a row) - run --fetch again later, it resumes"); break
                time.sleep(3 * fails)
                continue
        d += dt.timedelta(days=1)
    c.close()
    return n_ok


# ---------------------------------------------------------------- the daily scenarios
UP, DOWN, NOTUP, NOTDOWN, SMALL, BIG = "up", "down", "notup", "notdown", "small", "big"
SCN = [
    ("d_long_buildup", "LONG BUILD-UP", "CE", UP, "price up 0.5%+ and futures OI up 2%+"),
    ("d_short_buildup", "SHORT BUILD-UP", "PE", DOWN, "price down 0.5%+ and futures OI up 2%+"),
    ("d_short_covering", "SHORT COVERING", "CE", UP, "price up 0.5%+ and futures OI down 2%+"),
    ("d_long_unwinding", "LONG UNWINDING", "PE", DOWN, "price down 0.5%+ and futures OI down 2%+"),
    ("d_lb_streak3", "LONG BUILD-UP 3 DAYS RUNNING", "CE", UP, "long build-up today and the 2 days before"),
    ("d_sb_streak3", "SHORT BUILD-UP 3 DAYS RUNNING", "PE", DOWN, "short build-up today and the 2 days before"),
    ("d_squeeze", "SQUEEZE AFTER SHORTS", "CE", UP, "short covering today after 2 days of short build-up"),
    ("d_exhaustion", "LONGS GIVING UP", "PE", DOWN, "long unwinding today after 2 days of long build-up"),
    ("d_breakout_oi", "20-DAY HIGH WITH FRESH LONGS", "CE", UP, "close at a 20-day high and futures OI up 3%+"),
    ("d_breakdown_oi", "20-DAY LOW WITH FRESH SHORTS", "PE", DOWN, "close at a 20-day low and futures OI up 3%+"),
    ("d_breakout_cover", "20-DAY HIGH ON COVERING", "CE", UP, "close at a 20-day high and futures OI down 2%+"),
    ("d_breakdown_unwind", "20-DAY LOW ON UNWINDING", "PE", DOWN, "close at a 20-day low and futures OI down 2%+"),
    ("d_oi_peak_up", "OI AT A 20-DAY PEAK, PRICE UP", "CE", UP, "futures OI the highest in 20 days and price up 1%+"),
    ("d_oi_peak_down", "OI AT A 20-DAY PEAK, PRICE DOWN", "PE", DOWN, "futures OI the highest in 20 days and price down 1%+"),
    ("d_vol_up", "VOLUME + OI SURGE UP", "CE", UP, "futures volume 2x its 20-day average, OI up 3%+, price up 1%+"),
    ("d_vol_down", "VOLUME + OI SURGE DOWN", "PE", DOWN, "futures volume 2x its 20-day average, OI up 3%+, price down 1%+"),
    ("d_basis_long", "LONGS PAYING UP", "CE", UP, "long build-up and the futures premium widened 0.15 pt+"),
    ("d_discount_short", "SHORTS AT A DISCOUNT", "PE", DOWN, "short build-up with the futures under the share price"),
    ("d_gap_up_held", "GAP UP HELD WITH LONGS", "CE", UP, "futures opened 1%+ up and closed as a long build-up"),
    ("d_gap_down_held", "GAP DOWN HELD WITH SHORTS", "PE", DOWN, "futures opened 1%+ down and closed as a short build-up"),
    ("d_calls_bought", "CALLS BOUGHT", "CE", UP, "a big call strike: OI up, premium up"),
    ("d_call_writing", "SELLERS BUILDING A ROOF", None, NOTUP, "a big call strike just above: OI up, premium down"),
    ("d_call_short_covering", "CALL WRITERS RUNNING", "CE", UP, "a big call strike: OI down, premium up"),
    ("d_call_unwinding", "CALL BUYERS LEAVING", "PE", DOWN, "a big call strike: OI down, premium down"),
    ("d_puts_bought", "PUTS BOUGHT", "PE", DOWN, "a big put strike: OI up, premium up"),
    ("d_put_writing", "SELLERS BUILDING A FLOOR", None, NOTDOWN, "a big put strike just below: OI up, premium down"),
    ("d_put_short_covering", "PUT WRITERS RUNNING", "PE", DOWN, "a big put strike: OI down, premium up"),
    ("d_put_unwinding", "PUT BUYERS LEAVING", "CE", UP, "a big put strike: OI down, premium down"),
    ("d_bull_shift", "FLOOR BUILDING, ROOF LEAVING", "CE", UP, "puts written below and call writers running above"),
    ("d_bear_shift", "ROOF BUILDING, FLOOR LEAVING", "PE", DOWN, "calls written above and put writers running below"),
    ("d_range_writing", "SELLERS BOX IT IN", None, SMALL, "calls written above and puts written below, price flat"),
    ("d_rise_not_trusted", "THE RISE IS NOT TRUSTED", "PE", DOWN, "price up 1%+ but calls written above and no put writing"),
    ("d_fall_not_trusted", "THE FALL IS NOT TRUSTED", "CE", UP, "price down 1%+ but puts written below and no call writing"),
    ("d_floor_up", "THE FLOOR MOVED UP", "CE", UP, "the biggest put strike moved to a higher strike"),
    ("d_floor_down", "THE FLOOR MOVED DOWN", "PE", DOWN, "the biggest put strike moved to a lower strike"),
    ("d_roof_up", "THE ROOF MOVED UP", "CE", UP, "the biggest call strike moved to a higher strike"),
    ("d_roof_down", "THE ROOF MOVED DOWN", "PE", DOWN, "the biggest call strike moved to a lower strike"),
    ("d_roof_broken", "CLOSED ABOVE YESTERDAY'S ROOF", "CE", UP, "closed above yesterday's roof and the calls there fell"),
    ("d_floor_broken", "CLOSED BELOW YESTERDAY'S FLOOR", "PE", DOWN, "closed below yesterday's floor and the puts there fell"),
    ("d_roof_rising_near", "A ROOF RISING RIGHT ABOVE", None, NOTUP, "within 1% under the roof and its calls up 10%+"),
    ("d_floor_rising_near", "A FLOOR RISING RIGHT BELOW", None, NOTDOWN, "within 1% over the floor and its puts up 10%+"),
    ("d_pcr_up", "PCR UP SHARPLY", "CE", UP, "the put-call ratio near the price up 0.2+ on the day"),
    ("d_pcr_down", "PCR DOWN SHARPLY", "PE", DOWN, "the put-call ratio near the price down 0.2+ on the day"),
    ("d_pcr_high", "PCR VERY HIGH (1.5+)", "CE", UP, "far more puts than calls near the price"),
    ("d_pcr_low", "PCR VERY LOW (0.5-)", "PE", DOWN, "far more calls than puts near the price"),
    ("d_maxpain_up", "MAX PAIN MOVED UP", "CE", UP, "the sellers' comfort strike moved up"),
    ("d_maxpain_down", "MAX PAIN MOVED DOWN", "PE", DOWN, "the sellers' comfort strike moved down"),
    ("d_iv_pump", "BOTH SIDES PUMPED", None, BIG, "ATM call and put both up 15%+ with the price flat"),
    ("d_iv_crush", "BOTH SIDES CRUSHED", None, SMALL, "ATM call and put both down 15%+ with the price flat"),
]
SC = {s[0]: {"id": s[0], "name": s[1], "side": s[2], "claim": s[3], "what": s[4]} for s in SCN}


def claim_ok(claim, mv):
    if claim == UP:
        return mv > 0, mv
    if claim == DOWN:
        return mv < 0, -mv
    if claim == NOTUP:
        return mv <= 0.2, -mv
    if claim == NOTDOWN:
        return mv >= -0.2, mv
    if claim == SMALL:
        return abs(mv) < 1.0, -abs(mv)
    if claim == BIG:
        return abs(mv) >= 1.5, abs(mv)
    return None, None


def fires(rs, i):
    """the daily scenarios on share-day i of one share's rows (oldest first) -> [ids]"""
    r, p = rs[i], rs[i - 1]
    out = []
    if not r["spot"] or not p["spot"]:
        return out
    chg = (r["spot"] / p["spot"] - 1) * 100
    roll = r.get("exp") != p.get("exp")                  # the day after an expiry: the old month fell out of the total OI
    foi = None
    if not roll and r.get("foi") and r.get("fdoi") is not None and r["foi"] - r["fdoi"] > 0:
        foi = r["fdoi"] / (r["foi"] - r["fdoi"]) * 100

    def q(row, prow):
        if not row["spot"] or not prow["spot"] or row.get("exp") != prow.get("exp") or row.get("foi") is None or row.get("fdoi") is None or row["foi"] - row["fdoi"] <= 0:
            return None
        c_, f_ = (row["spot"] / prow["spot"] - 1) * 100, row["fdoi"] / (row["foi"] - row["fdoi"]) * 100
        return "LB" if c_ >= 0.5 and f_ >= 2 else "SB" if c_ <= -0.5 and f_ >= 2 else "SC" if c_ >= 0.5 and f_ <= -2 else "LU" if c_ <= -0.5 and f_ <= -2 else None
    qt = q(r, p)
    q1 = q(p, rs[i - 2]) if i >= 2 else None
    q2 = q(rs[i - 2], rs[i - 3]) if i >= 3 else None
    for k_, v_ in (("LB", "d_long_buildup"), ("SB", "d_short_buildup"), ("SC", "d_short_covering"), ("LU", "d_long_unwinding")):
        if qt == k_:
            out.append(v_)
    if qt == "LB" and q1 == "LB" and q2 == "LB":
        out.append("d_lb_streak3")
    if qt == "SB" and q1 == "SB" and q2 == "SB":
        out.append("d_sb_streak3")
    if qt == "SC" and q1 == "SB" and q2 == "SB":
        out.append("d_squeeze")
    if qt == "LU" and q1 == "LB" and q2 == "LB":
        out.append("d_exhaustion")
    h = rs[max(0, i - 20):i]
    if len(h) >= 15 and foi is not None:
        hi, lo = max(x["spot"] for x in h if x["spot"]), min(x["spot"] for x in h if x["spot"])
        if r["spot"] > hi and foi >= 3:
            out.append("d_breakout_oi")
        if r["spot"] < lo and foi >= 3:
            out.append("d_breakdown_oi")
        if r["spot"] > hi and foi <= -2:
            out.append("d_breakout_cover")
        if r["spot"] < lo and foi <= -2:
            out.append("d_breakdown_unwind")
        same = [x for x in h if x.get("exp") == r.get("exp") and x.get("foi")]
        if len(same) >= 5 and r["foi"] >= max(x["foi"] for x in same):
            if chg >= 1:
                out.append("d_oi_peak_up")
            if chg <= -1:
                out.append("d_oi_peak_down")
        av = sum(x["fvol"] or 0 for x in h) / len(h)
        if av and (r["fvol"] or 0) >= 2 * av and foi >= 3:
            if chg >= 1:
                out.append("d_vol_up")
            if chg <= -1:
                out.append("d_vol_down")
    if qt == "LB" and r.get("basis") is not None and p.get("basis") is not None and r["basis"] - p["basis"] >= 0.15:
        out.append("d_basis_long")
    if qt == "SB" and r.get("basis") is not None and r["basis"] < 0:
        out.append("d_discount_short")
    if r.get("fo") and p.get("fc"):
        gap = (r["fo"] / p["fc"] - 1) * 100
        if gap >= 1 and qt == "LB":
            out.append("d_gap_up_held")
        if gap <= -1 and qt == "SB":
            out.append("d_gap_down_held")
    bx = json.loads(r["boxes"]) if r.get("boxes") else {}
    for key, id_ in (("CE_bought", "d_calls_bought"), ("CE_written", "d_call_writing"), ("CE_running", "d_call_short_covering"), ("CE_leaving", "d_call_unwinding"),
                     ("PE_bought", "d_puts_bought"), ("PE_written", "d_put_writing"), ("PE_running", "d_put_short_covering"), ("PE_leaving", "d_put_unwinding")):
        if key in bx:
            out.append(id_)
    if "PE_written" in bx and "CE_running" in bx:
        out.append("d_bull_shift")
    if "CE_written" in bx and "PE_running" in bx:
        out.append("d_bear_shift")
    if "CE_written" in bx and "PE_written" in bx and abs(chg) <= 0.5:
        out.append("d_range_writing")
    if chg >= 1 and "CE_written" in bx and "PE_written" not in bx:
        out.append("d_rise_not_trusted")
    if chg <= -1 and "PE_written" in bx and "CE_written" not in bx:
        out.append("d_fall_not_trusted")
    if r.get("oexp") and r.get("oexp") == p.get("oexp"):
        st = json.loads(r["strikes"]) if r.get("strikes") else {}
        if r.get("floor_k") and p.get("floor_k") and r["floor_k"] != p["floor_k"]:
            old = (st.get("%g" % p["floor_k"]) or [0, 0, 0])[2] or 0
            if (r["floor_oi"] or 0) >= 0.8 * max(old, 1):
                out.append("d_floor_up" if r["floor_k"] > p["floor_k"] else "d_floor_down")
        if r.get("roof_k") and p.get("roof_k") and r["roof_k"] != p["roof_k"]:
            old = (st.get("%g" % p["roof_k"]) or [0])[0] or 0
            if (r["roof_oi"] or 0) >= 0.8 * max(old, 1):
                out.append("d_roof_up" if r["roof_k"] > p["roof_k"] else "d_roof_down")
        if p.get("roof_k") and r["spot"] > p["roof_k"]:
            v = st.get("%g" % p["roof_k"])
            if v and v[1] is not None and v[1] < 0:
                out.append("d_roof_broken")
        if p.get("floor_k") and r["spot"] < p["floor_k"]:
            v = st.get("%g" % p["floor_k"])
            if v and v[3] is not None and v[3] < 0:
                out.append("d_floor_broken")
        if r.get("roof_k") and r["spot"] < r["roof_k"] <= r["spot"] * 1.01:
            v = st.get("%g" % r["roof_k"])
            if v and v[1] and v[0] - v[1] > 0 and v[1] / (v[0] - v[1]) >= 0.10:
                out.append("d_roof_rising_near")
        if r.get("floor_k") and r["spot"] * 0.99 <= r["floor_k"] < r["spot"]:
            v = st.get("%g" % r["floor_k"])
            if v and v[3] and v[2] - v[3] > 0 and v[3] / (v[2] - v[3]) >= 0.10:
                out.append("d_floor_rising_near")
        if r.get("ce_oi") and p.get("ce_oi") and r.get("pe_oi") is not None and p.get("pe_oi") is not None and r["ce_oi"] + r["pe_oi"] > 0:
            pc1, pc0 = r["pe_oi"] / r["ce_oi"], p["pe_oi"] / p["ce_oi"]
            if pc1 - pc0 >= 0.2:
                out.append("d_pcr_up")
            elif pc0 - pc1 >= 0.2:
                out.append("d_pcr_down")
        if r.get("mp") and p.get("mp") and r["mp"] != p["mp"] and abs(r["mp"] / p["mp"] - 1) >= 0.005:
            out.append("d_maxpain_up" if r["mp"] > p["mp"] else "d_maxpain_down")
    if r.get("ce_oi") and r.get("pe_oi") is not None:
        pc = r["pe_oi"] / r["ce_oi"]
        if pc >= 1.5:
            out.append("d_pcr_high")
        elif pc <= 0.5:
            out.append("d_pcr_low")
    if r.get("atm_ce0") and r.get("atm_pe0") and r["atm_ce0"] >= 2 and r["atm_pe0"] >= 2 and abs(chg) <= 0.5:
        rc, rp = r["atm_ce"] / r["atm_ce0"] - 1, r["atm_pe"] / r["atm_pe0"] - 1
        if rc >= 0.15 and rp >= 0.15:
            out.append("d_iv_pump")
        elif rc <= -0.15 and rp <= -0.15:
            out.append("d_iv_crush")
    return out


def load(path=None):
    c = db(path)
    by = {}
    for r in c.execute("select %s from day order by sym, d" % ",".join(COLS)):
        x = dict(zip(COLS, r))
        by.setdefault(x["sym"], []).append(x)
    c.close()
    return by


def study(by=None, path=None, quiet=False):
    by = by if by is not None else load(path)
    res, base = {}, {}
    for sym, rs in by.items():
        for i in range(3, len(rs) - 1):
            r, n1 = rs[i], rs[i + 1]
            if not r["spot"] or not n1["spot"]:
                continue
            yr = r["d"][:4]
            mv = (n1["spot"] / r["spot"] - 1) * 100
            mv3 = (rs[i + 3]["spot"] / r["spot"] - 1) * 100 if i + 3 < len(rs) and rs[i + 3]["spot"] else None
            for cl in (UP, DOWN, NOTUP, NOTDOWN, SMALL, BIG):
                b = base.setdefault((yr, cl), [0, 0]); b[0] += 1; b[1] += int(claim_ok(cl, mv)[0])
            for id_ in fires(rs, i):
                s = SC[id_]
                ok, way = claim_ok(s["claim"], mv)
                e = res.setdefault((id_, yr), {"n": 0, "right": 0, "way": 0.0, "n3": 0, "right3": 0, "last": []})
                e["n"] += 1; e["right"] += int(ok); e["way"] += way
                if mv3 is not None and s["claim"] in (UP, DOWN):
                    e["n3"] += 1; e["right3"] += int(claim_ok(s["claim"], mv3)[0])
                e["last"] = (e["last"] + ["%s %s %+.1f%%" % (r["d"], sym, mv)])[-5:]
    years = sorted({y for (_, y) in res} | {y for (y, _) in base})
    rows = []
    for s in SCN:
        id_ = s[0]
        row = {"id": id_, "name": s[1], "side": s[2], "claim": s[3], "what": s[4], "years": {}}
        for y in years:
            e = res.get((id_, y))
            b = base.get((y, s[3]))
            if not e or not b:
                continue
            pct = 100.0 * e["right"] / e["n"]
            bp = 100.0 * b[1] / b[0]
            row["years"][y] = {"n": e["n"], "pct": round(pct, 1), "base": round(bp, 1), "edge": round(pct - bp, 1), "avg": round(e["way"] / e["n"], 2),
                               "pct3": round(100.0 * e["right3"] / e["n3"], 1) if e["n3"] else None, "last": e["last"]}
        ys = [row["years"].get(y) for y in years[-2:]] if len(years) >= 2 else [row["years"].get(y) for y in years]
        holds = [v and v["n"] >= 50 and v["pct"] >= 55 and v["edge"] >= 3 for v in ys]
        against = [v and v["n"] >= 50 and v["edge"] <= -3 for v in ys]
        row["verdict"] = ("HOLDS BOTH YEARS" if ys and all(holds) else "ONE YEAR ONLY" if any(holds) else "THE OTHER SIDE WORKS" if ys and all(against)
                          else "FEW CASES" if not ys or any((not v) or v["n"] < 50 for v in ys) else "NO EDGE")
        rows.append(row)
    order = {"HOLDS BOTH YEARS": 0, "THE OTHER SIDE WORKS": 1, "ONE YEAR ONLY": 2, "NO EDGE": 3, "FEW CASES": 4}
    rows.sort(key=lambda r: (order[r["verdict"]], -max([v["edge"] for v in r["years"].values()] or [0])))
    out = {"at": core.ist_now().strftime("%Y-%m-%d %H:%M"), "years": years, "shares": len(by), "days": len({r["d"] for rs in by.values() for r in rs}),
           "base": {"%s %s" % k: round(100.0 * v[1] / v[0], 1) for k, v in base.items()}, "rows": rows}
    return out


def table(out):
    ys = out["years"][-2:]
    L = ["OI BUILD-UP STUDY · %d shares · %d trading days · NSE F&O daily files · measured on the next day's close" % (out["shares"], out["days"]),
         "base rate (any share-day): " + " · ".join("%s up %s%% / down %s%%" % (y, out["base"].get("%s up" % y), out["base"].get("%s down" % y)) for y in ys),
         "", "%-32s %-4s " % ("SCENARIO", "SIDE") + " ".join("%-27s" % ("%s: cases right base edge" % y) for y in ys) + " VERDICT"]
    for r in out["rows"]:
        cells = []
        for y in ys:
            v = r["years"].get(y)
            cells.append("%-27s" % (("%5d %5.1f%% %4.0f%% %+5.1f" % (v["n"], v["pct"], v["base"], v["edge"])) if v else "      —"))
        L.append("%-32s %-4s %s %s" % (r["name"][:32], r["side"] or "—", " ".join(cells), r["verdict"]))
    L.append("")
    L.append("HOLDS = 50+ cases, 55%+ right and +3 points over the base rate in BOTH years · THE OTHER SIDE WORKS = it lost by 3+ points both years")
    return "\n".join(L)


def today(out, path=None):
    by = load(path)
    holds = {r["id"] for r in out["rows"] if r["verdict"] in ("HOLDS BOTH YEARS", "THE OTHER SIDE WORKS")}
    last = max((rs[-1]["d"] for rs in by.values() if rs), default=None)
    L = ["the latest day in: %s · scenarios that hold (or flip) in both years:" % last]
    for sym, rs in sorted(by.items()):
        if len(rs) < 4 or rs[-1]["d"] != last:
            continue
        for id_ in fires(rs, len(rs) - 1):
            if id_ in holds:
                r = next(x for x in out["rows"] if x["id"] == id_)
                L.append("  %-12s %-32s %s %s" % (sym, r["name"], r["side"] or "—", r["verdict"]))
    return "\n".join(L)


# ---------------------------------------------------------------- the self-test
def selftest():
    import tempfile, random
    ok = True

    def check(name, good):
        nonlocal ok
        print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)
    hdr = "TradDt,BizDt,Sgmt,Src,FinInstrmTp,FinInstrmId,ISIN,TckrSymb,SctySrs,XpryDt,FininstrmActlXpryDt,StrkPric,OptnTp,FinInstrmNm,OpnPric,HghPric,LwPric,ClsPric,LastPric,PrvsClsgPric,UndrlygPric,SttlmPric,OpnIntrst,ChngInOpnIntrst,TtlTradgVol,TtlTrfVal,TtlNbOfTxsExctd,SsnId,NewBrdLotQty,Rmks,Rsvd1,Rsvd2,Rsvd3,Rsvd4"

    def line(tp, sym, exp, k, kd, o, cl, pcl, u, oi, doi, vol):
        return ",".join(str(x) for x in ["2025-03-03", "2025-03-03", "FO", "NSE", tp, 1, "", sym, "", exp, exp, k, kd, "", o, cl, cl, cl, cl, pcl, u, cl, oi, doi, vol, 0, 0, "F1", 500, "", "", "", "", ""])
    print("1. one NSE day file boiled down")
    rows = [hdr, line("STF", "ABC", "2025-03-27", "", "", 1000, 1012, 1000, 1010, 600000, 30000, 90000), line("STF", "ABC", "2025-04-24", "", "", 1003, 1015, 1003, 1010, 100000, 5000, 9000),
            line("IDF", "NIFTY", "2025-03-27", "", "", 1, 1, 1, 1, 1, 1, 1)]
    for k, ce, pe, cdo, pdo, cp, cp0, pp, pp0 in [(960, 30000, 120000, 0, 0, 52, 50, 3, 3.2), (980, 60000, 330000, 0, 180000, 34, 33, 6, 9), (1000, 180000, 200000, 0, 0, 20, 19, 15, 15.5),
                                                  (1020, 420000, 60000, 200000, 0, 9, 12, 30, 29), (1040, 260000, 40000, 0, 0, 5, 5, 45, 44)]:
        rows.append(line("STO", "ABC", "2025-03-27", k, "CE", cp, cp, cp0, 1010, ce, cdo, 1000)); rows.append(line("STO", "ABC", "2025-03-27", k, "PE", pp, pp, pp0, 1010, pe, pdo, 1000))
    r = boil("\n".join(rows), dt.date(2025, 3, 3))["ABC"]
    check("futures: spot 1010, OI summed over both months 700,000, change +35,000", r["spot"] == 1010 and r["foi"] == 700000 and r["fdoi"] == 35000)
    check("the roof 1020 (4.2 L calls) and the floor 980 (3.3 L puts)", r["roof_k"] == 1020 and r["floor_k"] == 980)
    bx = json.loads(r["boxes"])
    check("calls WRITTEN at 1020 and puts WRITTEN at 980 found", "CE_written" in bx and bx["CE_written"][0] == 1020 and "PE_written" in bx and bx["PE_written"][0] == 980)
    check("an index future is left out", "NIFTY" not in boil("\n".join(rows), dt.date(2025, 3, 3)))
    bad = False
    try:
        boil("a,b,c\n1,2,3", dt.date(2025, 3, 3))
    except ValueError:
        bad = True
    check("a file with new columns stops the fetch with a clear line", bad)
    print("2. the study on two synthetic years")
    random.seed(4)
    by = {}
    for s in range(40):
        rs, sp, foi = [], 1000.0, 1e6
        d = dt.date(2025, 1, 1)
        lb_next = False
        while d <= dt.date(2026, 10, 30):
            if d.weekday() < 5:
                mv = random.gauss(0, 1.0)
                if lb_next:
                    mv = abs(mv) + 0.3                            # planted: after a long build-up, the next day tends up
                sp *= 1 + mv / 100
                lb = random.random() < 0.12
                chg_fo = (random.uniform(0.03, 0.06) if lb else random.uniform(-0.01, 0.01))
                if lb:
                    sp *= 1.008
                doi = foi * chg_fo; foi += doi
                rs.append({"d": str(d), "sym": "S%d" % s, "spot": sp, "fc": sp * 1.002, "fo": sp, "fh": sp, "fl": sp, "foi": foi, "fdoi": doi, "fvol": 1e5, "basis": 0.2,
                           "dte": 10, "exp": d.strftime("%Y-%m"), "oexp": None, "ce_oi": None, "pe_oi": None, "ce_doi": None, "pe_doi": None, "roof_k": None, "roof_oi": None,
                           "floor_k": None, "floor_oi": None, "mp": None, "atm_k": None, "atm_ce": None, "atm_ce0": None, "atm_pe": None, "atm_pe0": None, "boxes": None, "strikes": None})
                lb_next = lb
            d += dt.timedelta(days=1)
        by["S%d" % s] = rs
    out = study(by)
    lbr = next(r for r in out["rows"] if r["id"] == "d_long_buildup")
    print("    long build-up: %s" % " · ".join("%s %d cases %.0f%% (base %.0f%%)" % (y, v["n"], v["pct"], v["base"]) for y, v in lbr["years"].items()))
    check("the planted long build-up edge is found in both years: %s" % lbr["verdict"], lbr["verdict"] == "HOLDS BOTH YEARS")
    cbr = next(r for r in out["rows"] if r["id"] == "d_calls_bought")
    check("a scenario with no cases says so, it is not dropped (%s)" % cbr["verdict"], cbr["verdict"] == "FEW CASES")
    sbr = next(r for r in out["rows"] if r["id"] == "d_short_buildup")
    check("short build-up days that were planted rises show up as THE OTHER SIDE WORKS (%s) - a loss is shown, not hidden" % sbr["verdict"], sbr["verdict"] == "THE OTHER SIDE WORKS")
    check("every scenario is in the table (%d)" % len(out["rows"]), len(out["rows"]) == len(SCN))
    print(table(out).splitlines()[0])
    print("3. the store and the resume")
    tmp = tempfile.mkdtemp(prefix="oistudy")
    p = os.path.join(tmp, "o.db")
    c = db(p); store(c, {"ABC": r}); c.commit()
    n = c.execute("select count(*) from day").fetchone()[0]; c.close()
    check("a boiled day is stored (%d row)" % n, n == 1)
    print("\nOI STUDY SELF-TEST %s" % ("PASSED" if ok else "FAILED"))
    return ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--test"]:
        sys.exit(0 if selftest() else 1)
    if a[:1] == ["--fetch"]:
        d0 = fdate(a[1]) if len(a) > 1 else dt.date(2025, 1, 1)
        d1 = fdate(a[2]) if len(a) > 2 else core.ist_now().date() - dt.timedelta(days=1)
        print("fetching %s .. %s (resumes; about 1 s a day)" % (d0, d1), flush=True)
        n = fetch(d0, d1)
        print("fetched %d new days" % n); sys.exit(0)
    if a[:1] == ["--status"]:
        c = db()
        r = c.execute("select count(*), min(d), max(d) from fetched where status='ok'").fetchone()
        print("days in: %d (%s .. %s) · share-days: %d" % (r[0], r[1], r[2], c.execute("select count(*) from day").fetchone()[0])); sys.exit(0)
    if a[:1] == ["--study"]:
        out = study()
        json.dump(out, open(OUT + ".tmp", "w"), default=str); os.replace(OUT + ".tmp", OUT)
        print(table(out)); print("\nsaved: %s" % OUT); sys.exit(0)
    if a[:1] == ["--today"]:
        out = json.load(open(OUT)) if os.path.exists(OUT) else study()
        print(today(out)); sys.exit(0)
    print(__doc__)
PY_STUDY
cd $D && python3 -m py_compile oistudy.py || { echo "ERROR - oistudy.py does not compile"; rm -f $D/oistudy.py; exit 1; }
echo "--- 1. the self-test (synthetic NSE files and two synthetic years, no network):"
timeout 300 python3 oistudy.py --test 2>&1 | grep "OK  \|FAIL\|SELF-TEST" | head -14
timeout 300 python3 oistudy.py --test >/dev/null 2>&1 || { echo "ERROR - the study's self-test failed"; exit 1; }
echo "--- 2. one real day from NSE (the reach check):"
timeout 120 python3 -c "
import oistudy, datetime as dt, requests, io, zipfile
d = dt.date.today() - dt.timedelta(days=1)
while d.weekday() >= 5: d -= dt.timedelta(days=1)
for _ in range(6):
    r = requests.get(oistudy.URL % d.strftime('%Y%m%d'), headers=oistudy.UA, timeout=40)
    if r.status_code == 200: break
    d -= dt.timedelta(days=1)
    while d.weekday() >= 5: d -= dt.timedelta(days=1)
z = zipfile.ZipFile(io.BytesIO(r.content)); rows = oistudy.boil(z.read(z.namelist()[0]).decode('utf-8', 'ignore'), d)
x = rows.get('RELIANCE') or next(iter(rows.values()))
print('    %s: %d F&O shares read · %s spot %s · futures OI %s · roof %s floor %s · boxes %s' % (d, len(rows), x['sym'], x['spot'], int(x['foi'] or 0), x.get('roof_k'), x.get('floor_k'), x.get('boxes')))
" || { echo "ERROR - NSE's file could not be read here - send me the lines above"; exit 1; }
echo "--- 3. the two years, in the background (nice): progress in data/oistudy.log, the table in data/oistudy.txt when done"
mkdir -p $D/data
cd $D && nohup nice -n 15 sh -c "python3 -u oistudy.py --fetch && python3 -u oistudy.py --study > data/oistudy.txt 2>&1 && python3 -u oistudy.py --today >> data/oistudy.txt 2>&1" > data/oistudy.log 2>&1 &
sleep 15; tail -3 $D/data/oistudy.log
echo "PATCH 86 STARTED - the download takes about 10-20 minutes. Then:"
echo "    cat /home/globalbot/intraday/data/oistudy.txt          the table: every scenario, 2025 vs 2026"
echo "    tail -3 /home/globalbot/intraday/data/oistudy.log      progress while it runs (run this file again to resume if it stops)"
