#!/bin/bash
# PATCH 115 - THE EARLY-WARNING STUDY (read-only; nothing in the live system changes, no restart).
#   Your question: which OI footprints come BEFORE the big moves - days ahead - so GIR can warn early?
#   On the 2 years of NSE daily F&O files already on this server (data/oistudy.db), for 13 footprints (futures OI piling
#   up with the price flat, one strike doubling, calls / puts building, PCR, a coil, premiums rising, the roof / floor
#   leaving, quiet volume with OI creeping): how often a 4%+ move followed within 1 / 3 / 5 days vs an ordinary day, and
#   of all the 5%+ days, how many it warned about in the 5 days before. Every result is shown, the failures too.
#   First it brings the daily files up to yesterday. Installs earlystudy.py. Writes data/earlystudy.txt.
D=/home/globalbot/intraday; W=/tmp/g115; mkdir -p $W
[ -f $D/data/oistudy.db ] || { echo "no data/oistudy.db on this server - the daily F&O files were never loaded"; exit 1; }
[ -f $D/earlystudy.py ] && { echo "patch 115 is already installed - to run the study again:  cd $D && python3 earlystudy.py --study --today"; exit 1; }
cat > $W/earlystudy.py <<'PY_STUDY'
#!/usr/bin/env python3
"""earlystudy.py - THE EARLY-WARNING STUDY (patch 115): which OI footprints came BEFORE the big moves, hours to days ahead?
Read-only, on data/oistudy.db (NSE's daily F&O files boiled down per share-day by oistudy.py: futures OI, the option chain).

For every share-day it asks two questions, separately for each year:
  FORWARD  when a footprint shows up after the close, how often does a BIG MOVE (4%+ from that close, any day within the
           next 1 / 3 / 5 trading days) follow - against the same rate on every share-day (the base). lift = hit / base.
  MIRROR   of all the big days (a share closing 5%+ up or down), how many had the footprint in the 5 days before
           (= how often it would have warned you in time).
A footprint is a WARNING when it has 50+ cases and a lift of 1.5x or more in BOTH years. Its direction is usable when the
big moves that followed went its way 60%+ of the time. Everything is shown, the failures too.

  python3 earlystudy.py --study      the table (also saved to data/earlystudy.txt and data/earlystudy.json)
  python3 earlystudy.py --today      the shares showing a WARNING footprint on the latest day in the file
  python3 earlystudy.py --test       the self-test (synthetic data, no network)"""
import os, sys, json, sqlite3, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BIG, BIGDAY, HOR = 4.0, 5.0, (1, 3, 5)
UP, DN, ANY = "UP", "DOWN", "EITHER"


def _db_path():
    try:
        import core
        return os.path.join(core.DATA, "oistudy.db")
    except Exception:
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "oistudy.db")


COLS = ["d", "sym", "spot", "foi", "fvol", "exp", "oexp", "ce_oi", "pe_oi", "roof_k", "floor_k", "atm_k", "atm_ce", "atm_pe", "strikes"]


def load(path=None):
    c = sqlite3.connect("file:%s?mode=ro" % (path or _db_path()), uri=True, timeout=30)
    by = collections.OrderedDict()
    for r in c.execute("select %s from day order by sym, d" % ",".join(COLS)):
        x = dict(zip(COLS, r))
        if x["spot"]:
            by.setdefault(x["sym"], []).append(x)
    c.close()
    return by


def pct(a, b):
    return (a / b - 1) * 100 if a and b else None


def same_series(rs, i, k):
    """no futures expiry inside the window (the expired month drops out of the OI total) and the same option expiry"""
    w = rs[i - k:i + 1]
    return all(x["exp"] == w[0]["exp"] for x in w) and all(x["oexp"] == w[0]["oexp"] for x in w)


def strikes(r):
    if "_k" not in r:
        try:
            r["_k"] = {float(k): v for k, v in json.loads(r["strikes"]).items()} if r.get("strikes") else {}
        except Exception:
            r["_k"] = {}
    return r["_k"]


def spike(rs, i, kind):
    """ONE out-of-the-money strike whose OI at least doubled in 3 days, holds 2x+ its neighbours and 10%+ of its side"""
    a, b = rs[i], rs[i - 3]
    ka, kb, sp = strikes(a), strikes(b), a["spot"]
    if not ka or not kb or a["oexp"] != b["oexp"]:
        return None
    j = 0 if kind == "CE" else 2
    ks = sorted(ka)
    tot = sum(v[j] or 0 for v in ka.values()) or 1
    best = None
    for n, k in enumerate(ks):
        if (kind == "CE" and k < sp * 1.02) or (kind == "PE" and k > sp * 0.98):
            continue
        oi, oi0 = ka[k][j] or 0, (kb.get(k) or [0, 0, 0, 0])[j] or 0
        if oi < 0.10 * tot or oi0 <= 0 or oi < 2 * oi0:
            continue
        nb = [ka[ks[m]][j] or 0 for m in (n - 1, n + 1) if 0 <= m < len(ks)]
        if nb and oi < 2 * (sum(nb) / len(nb)):
            continue
        if not best or oi / oi0 > best[1]:
            best = (k, oi / oi0)
    return best


def flat(rs, i, k, lim=1.5):
    m = pct(rs[i]["spot"], rs[i - k]["spot"])
    return m is not None and abs(m) <= lim


# id, name, claim, what it means
FP = [
    ("fut_accum3", "FUTURES OI +10% IN 3 DAYS, PRICE FLAT", ANY, "money piling into futures while the price sleeps (±1.5%)"),
    ("fut_accum5", "FUTURES OI +15% IN 5 DAYS, PRICE FLAT", ANY, "the same over a week (±2%)"),
    ("ce_spike", "ONE CALL STRIKE DOUBLED IN 3 DAYS", UP, "an out-of-the-money call strike 2x in 3 days, 2x its neighbours"),
    ("pe_spike", "ONE PUT STRIKE DOUBLED IN 3 DAYS", DN, "an out-of-the-money put strike 2x in 3 days, 2x its neighbours"),
    ("ce_build3", "CALLS BUILDING 3 DAYS, PRICE FLAT", ANY, "call OI near the price +25% in 3 days, puts not, price ±1.5%"),
    ("pe_build3", "PUTS BUILDING 3 DAYS, PRICE FLAT", ANY, "put OI near the price +25% in 3 days, calls not, price ±1.5%"),
    ("pcr_rise3", "PCR UP 0.3+ IN 3 DAYS", UP, "puts written faster than calls for 3 days"),
    ("pcr_high", "PCR 1.5 OR MORE", UP, "puts 1.5x the calls near the price"),
    ("coil", "OI AT A 20-DAY HIGH, PRICE IN A 2.5% BOX", ANY, "the most futures OI in 20 days while 5 closes sit inside 2.5%"),
    ("prem_build", "OPTION PREMIUM UP 20% WITH THE PRICE FLAT", ANY, "the at-the-money call + put (as % of the price) up 20% in 3 days, price ±1.5%"),
    ("roof_leaving", "THE ROOF'S CALLS LEAVING", UP, "the biggest call strike above loses 20% of its OI in 2 days, price within 3% under it"),
    ("floor_leaving", "THE FLOOR'S PUTS LEAVING", DN, "the biggest put strike below loses 20% of its OI in 2 days, price within 3% over it"),
    ("quiet_then_oi", "QUIET VOLUME, OI CREEPING UP", ANY, "futures volume 5-day average under 60% of 20-day, OI +5% in 5 days"),
]
FPD = {f[0]: f for f in FP}


def fires(rs, i):
    """the footprints on share-day i (after its close)"""
    out = []
    r = rs[i]
    if i >= 3 and same_series(rs, i, 3):
        o3 = pct(r["foi"], rs[i - 3]["foi"])
        if o3 is not None and o3 >= 10 and flat(rs, i, 3):
            out.append("fut_accum3")
        if spike(rs, i, "CE"):
            out.append("ce_spike")
        if spike(rs, i, "PE"):
            out.append("pe_spike")
        c3, p3 = pct(r["ce_oi"], rs[i - 3]["ce_oi"]), pct(r["pe_oi"], rs[i - 3]["pe_oi"])
        if c3 is not None and p3 is not None and flat(rs, i, 3):
            if c3 >= 25 and p3 <= 5:
                out.append("ce_build3")
            if p3 >= 25 and c3 <= 5:
                out.append("pe_build3")
        if r["ce_oi"] and rs[i - 3]["ce_oi"] and r["pe_oi"] is not None and rs[i - 3]["pe_oi"] is not None:
            if r["pe_oi"] / r["ce_oi"] - rs[i - 3]["pe_oi"] / rs[i - 3]["ce_oi"] >= 0.3:
                out.append("pcr_rise3")
        a0, a1 = rs[i - 3], r
        if a0["atm_ce"] and a0["atm_pe"] and a1["atm_ce"] and a1["atm_pe"] and flat(rs, i, 3):
            s0, s1 = (a0["atm_ce"] + a0["atm_pe"]) / a0["spot"], (a1["atm_ce"] + a1["atm_pe"]) / a1["spot"]
            if s1 >= 1.2 * s0:
                out.append("prem_build")
    if r["ce_oi"] and r["pe_oi"] and r["pe_oi"] / r["ce_oi"] >= 1.5:
        out.append("pcr_high")
    if i >= 5 and same_series(rs, i, 5):
        o5 = pct(r["foi"], rs[i - 5]["foi"])
        if o5 is not None and o5 >= 15 and flat(rs, i, 5, 2.0):
            out.append("fut_accum5")
    if i >= 20:
        w = rs[i - 19:i + 1]
        if all(x["foi"] for x in w) and r["foi"] >= max(x["foi"] for x in w) and same_series(rs, i, 5):
            cl = [x["spot"] for x in rs[i - 4:i + 1]]
            if (max(cl) / min(cl) - 1) * 100 <= 2.5:
                out.append("coil")
        v20 = [x["fvol"] or 0 for x in w]
        v5 = v20[-5:]
        o5 = pct(r["foi"], rs[i - 5]["foi"])
        if sum(v20) > 0 and (sum(v5) / 5) < 0.6 * (sum(v20) / 20) and o5 is not None and o5 >= 5 and same_series(rs, i, 5):
            out.append("quiet_then_oi")
    if i >= 2 and same_series(rs, i, 2):
        for key, kind, j, want in (("roof_k", "CE", 0, "roof_leaving"), ("floor_k", "PE", 2, "floor_leaving")):
            k = r[key]
            if not k:
                continue
            a, b = strikes(r).get(float(k)), strikes(rs[i - 2]).get(float(k))
            if a and b and b[j] and a[j] is not None and a[j] <= 0.8 * b[j]:
                gap = (k / r["spot"] - 1) * 100 if kind == "CE" else (r["spot"] / k - 1) * 100
                if 0 <= gap <= 3:
                    out.append(want)
    return out


def outcome(rs, i, h):
    """-> (max rise %, max fall %) of the closes over the next h trading days, or None near the end of the data"""
    if i + h >= len(rs):
        return None
    p0 = rs[i]["spot"]
    w = [x["spot"] for x in rs[i + 1:i + h + 1] if x["spot"]]
    if not w:
        return None
    return (max(w) / p0 - 1) * 100, (min(w) / p0 - 1) * 100


def hit(claim, o):
    up, dn = o[0] >= BIG, o[1] <= -BIG
    return up if claim == UP else dn if claim == DN else (up or dn)


def study(by=None, path=None):
    by = by if by is not None else load(path)
    F = collections.defaultdict(lambda: {"n": 0, "h": {h: 0 for h in HOR}, "up": 0, "dn": 0, "last": []})
    base = collections.defaultdict(lambda: {"n": 0, UP: 0, DN: 0, ANY: 0})
    mirror = collections.defaultdict(lambda: {"big": 0, "warned": collections.Counter(), "any": 0})
    days = set()
    for sym, rs in by.items():
        fl = [fires(rs, i) for i in range(len(rs))]
        for i, r in enumerate(rs):
            days.add(r["d"])
            yr = r["d"][:4]
            o5 = outcome(rs, i, 5)
            if o5 is not None:
                b = base[yr]; b["n"] += 1
                for cl in (UP, DN, ANY):
                    b[cl] += int(hit(cl, o5))
            for f in fl[i]:
                e = F[(f, yr)]
                oo = {h: outcome(rs, i, h) for h in HOR}
                if oo[5] is None:
                    continue
                e["n"] += 1
                for h in HOR:
                    e["h"][h] += int(oo[h] is not None and hit(FPD[f][2], oo[h]))
                if oo[5][0] >= BIG:
                    e["up"] += 1
                if oo[5][1] <= -BIG:
                    e["dn"] += 1
                if hit(FPD[f][2], oo[5]):
                    e["last"] = (e["last"] + ["%s %s %+.1f%%" % (r["d"], sym, oo[5][0] if oo[5][0] >= -oo[5][1] else oo[5][1])])[-4:]
            if i >= 1 and rs[i - 1]["spot"]:
                mv = pct(r["spot"], rs[i - 1]["spot"])
                if mv is not None and abs(mv) >= BIGDAY:
                    m = mirror[yr]; m["big"] += 1
                    seen = set(f for j in range(max(0, i - 5), i) for f in fl[j])
                    for f in seen:
                        m["warned"][f] += 1
                    m["any"] += int(bool(seen & set(WARN_OK or [x[0] for x in FP])))
    years = sorted({y for (_, y) in F} | set(base))
    rows = []
    for fid, name, claim, what in FP:
        row = {"id": fid, "name": name, "claim": claim, "what": what, "years": {}}
        for y in years:
            e, b = F.get((fid, y)), base.get(y)
            if not e or not e["n"] or not b or not b["n"]:
                continue
            br = 100.0 * b[claim] / b["n"]
            hr = 100.0 * e["h"][5] / e["n"]
            big = e["up"] + e["dn"]
            row["years"][y] = {"n": e["n"], "h1": round(100.0 * e["h"][1] / e["n"], 1), "h3": round(100.0 * e["h"][3] / e["n"], 1), "h5": round(hr, 1),
                               "base": round(br, 1), "lift": round(hr / br, 2) if br else None, "up_share": round(100.0 * e["up"] / big) if big else None,
                               "warned": mirror[y]["warned"].get(fid, 0), "bigdays": mirror[y]["big"], "last": e["last"]}
        ys = [row["years"].get(y) for y in years[-2:]]
        good = [v and v["n"] >= 50 and (v["lift"] or 0) >= 1.5 for v in ys]
        weak = [v and v["n"] >= 50 and (v["lift"] or 0) >= 1.2 for v in ys]
        row["verdict"] = ("WARNING WORKS BOTH YEARS" if ys and all(good) else "ONE YEAR ONLY" if any(good) else "WEAK" if ys and all(weak)
                          else "FEW CASES" if not ys or any((not v) or v["n"] < 50 for v in ys) else "NO EARLY WARNING")
        v = ys[-1] if ys else None
        if claim == ANY and v and v["up_share"] is not None:
            row["direction"] = "mostly UP" if v["up_share"] >= 60 else "mostly DOWN" if v["up_share"] <= 40 else "either way"
        rows.append(row)
    order = {"WARNING WORKS BOTH YEARS": 0, "ONE YEAR ONLY": 1, "WEAK": 2, "NO EARLY WARNING": 3, "FEW CASES": 4}
    rows.sort(key=lambda r: (order[r["verdict"]], -max([(v["lift"] or 0) for v in r["years"].values()] or [0])))
    return {"years": years, "shares": len(by), "days": len(days), "first": min(days) if days else None, "last": max(days) if days else None,
            "base": {y: {k: round(100.0 * b[k] / b["n"], 1) for k in (UP, DN, ANY)} for y, b in base.items() if b["n"]},
            "mirror": {y: {"big": m["big"], "any": m["any"]} for y, m in mirror.items()}, "rows": rows}


WARN_OK = None


def table(out):
    ys = out["years"][-2:]
    L = ["EARLY-WARNING STUDY · %d shares · %d trading days (%s → %s) · NSE F&O daily files" % (out["shares"], out["days"], out["first"], out["last"]),
         "BIG MOVE = the close 4%+ away from the signal day's close on any day within the next 5 trading days",
         "base (any share-day): " + " · ".join("%s up %s%% / down %s%% / either %s%%" % (y, out["base"][y][UP], out["base"][y][DN], out["base"][y][ANY]) for y in ys if y in out["base"]),
         ""]
    for r in out["rows"]:
        L.append("%s · %s · %s%s" % (r["name"], {"UP": "expect UP", "DOWN": "expect DOWN", "EITHER": "a big move either way"}[r["claim"]], r["verdict"],
                                    (" (%s)" % r["direction"]) if r.get("direction") else ""))
        for y in ys:
            v = r["years"].get(y)
            if v:
                L.append("   %s: %d cases · big move within 5 days %.0f%% vs %.0f%% normal = %.1fx (1 day %.0f%%, 3 days %.0f%%) · warned %d of %d big days"
                         % (y, v["n"], v["h5"], v["base"], v["lift"] or 0, v["h1"], v["h3"], v["warned"], v["bigdays"]))
    L += ["", "warned = of the big days that year (a close 5%+ up or down), how many had this footprint in the 5 days before",
          "lift = how many times more often a big move followed than on an ordinary share-day. 1.5x+ in both years = WARNING WORKS"]
    for y in ys:
        m = out["mirror"].get(y)
        if m:
            L.append("%s: %d big days · %d (%d%%) had at least one footprint in the 5 days before" % (y, m["big"], m["any"], round(100.0 * m["any"] / m["big"]) if m["big"] else 0))
    L.append("")
    L.append("EXAMPLES (the latest hits of each footprint that works):")
    for r in out["rows"]:
        if r["verdict"] in ("WARNING WORKS BOTH YEARS", "ONE YEAR ONLY"):
            v = r["years"].get(ys[-1]) or {}
            L.append("  %s: %s" % (r["name"], " · ".join(v.get("last") or [])))
    return "\n".join(L)


def today(out, by=None, path=None):
    by = by if by is not None else load(path)
    ok = {r["id"] for r in out["rows"] if r["verdict"] in ("WARNING WORKS BOTH YEARS", "ONE YEAR ONLY")}
    last = max((rs[-1]["d"] for rs in by.values() if rs), default=None)
    L = ["ON %s (the latest day in the file) - shares showing a footprint that works:" % last]
    n = 0
    for sym, rs in by.items():
        if not rs or rs[-1]["d"] != last:
            continue
        f = [x for x in fires(rs, len(rs) - 1) if x in ok]
        if f:
            n += 1
            L.append("  %-11s %s" % (sym, " · ".join(FPD[x][1] + " (" + FPD[x][2] + ")" for x in f)))
    if not n:
        L.append("  none")
    return "\n".join(L)


def selftest():
    import random
    ok = True

    def check(name, good):
        nonlocal ok
        print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)
    random.seed(7)
    by = {}
    for s in range(60):
        rs, sp, foi, d = [], 1000.0, 1e6, 0
        import datetime as dt
        day = dt.date(2025, 1, 1)
        plant = 0
        while day <= dt.date(2026, 10, 30):
            if day.weekday() < 5:
                mv = random.gauss(0, 1.1)
                if plant == 1:
                    mv = 6.0                                         # planted: after 3 flat days of futures OI piling up, a 6% day
                if plant > 1:
                    mv = random.uniform(-0.3, 0.3); foi *= 1.05      # the planted build: OI +5% a day, the price flat
                plant = plant - 1 if plant else (4 if random.random() < 0.02 else 0)
                sp *= 1 + mv / 100
                foi *= 1 + random.uniform(-0.01, 0.01)
                rs.append({"d": str(day), "sym": "S%d" % s, "spot": sp, "foi": foi, "fvol": 1e5, "exp": day.strftime("%Y-%m"), "oexp": day.strftime("%Y-%m"),
                           "ce_oi": 1e5, "pe_oi": 1e5, "roof_k": None, "floor_k": None, "atm_k": None, "atm_ce": None, "atm_pe": None, "strikes": None})
            day += dt.timedelta(days=1)
        by["S%d" % s] = rs
    out = study(by)
    fa = next(r for r in out["rows"] if r["id"] == "fut_accum3")
    y = fa["years"].get("2025") or {}
    check("the planted footprint (futures OI piling up, price flat -> a 6%% day) is found: lift %sx · %s" % (y.get("lift"), fa["verdict"]),
          fa["verdict"] == "WARNING WORKS BOTH YEARS" and (y.get("lift") or 0) >= 1.5)
    ph = next(r for r in out["rows"] if r["id"] == "pcr_high")
    check("a footprint that never shows up is FEW CASES, not a winner (%s)" % ph["verdict"], ph["verdict"] == "FEW CASES")
    check("the mirror counts the big days and how many were warned (%s)" % out["mirror"].get("2025"),
          out["mirror"].get("2025", {}).get("big", 0) > 0 and out["mirror"]["2025"]["any"] > 0)
    t = table(out)
    check("the table prints", "EARLY-WARNING STUDY" in t and "WARNING WORKS BOTH YEARS" in t)
    print("\nEARLY-WARNING STUDY SELF-TEST %s" % ("PASSED" if ok else "FAILED"))
    return ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--test" in a:
        sys.exit(0 if selftest() else 1)
    out = study()
    if "--study" in a or not a:
        t = table(out)
        print(t)
        try:
            import core
            d = core.DATA
        except Exception:
            d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
        open(os.path.join(d, "earlystudy.txt"), "w").write(t + "\n")
        json.dump(out, open(os.path.join(d, "earlystudy.json"), "w"), default=str)
    if "--today" in a:
        print(today(out))
PY_STUDY
cp $W/earlystudy.py $D/earlystudy.py
cd $D && python3 -m py_compile earlystudy.py || { rm -f $D/earlystudy.py; echo "ERROR - nothing installed"; exit 1; }
timeout 120 python3 earlystudy.py --test 2>&1 | grep "OK  \|FAIL\|SELF-TEST"
timeout 120 python3 earlystudy.py --test >/dev/null 2>&1 || { rm -f $D/earlystudy.py; echo "the self-test failed - nothing installed"; exit 1; }
echo "--- bringing the NSE daily files up to yesterday (a few seconds a day):"
nice -n 19 timeout 900 python3 oistudy.py --fetch 2>&1 | tail -3
python3 oistudy.py --status 2>&1 | tail -1
echo "--- THE STUDY (1-2 minutes):"
nice -n 19 timeout 1200 python3 earlystudy.py --study --today 2>&1
echo
echo "PATCH 115 DONE - the table is saved in $D/data/earlystudy.txt. Send me a photo of it."
