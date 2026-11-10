#!/bin/bash
# THE SCENARIO LAB (patch 159) - 17 trading scenarios tested on 3 years of 5-minute data for every F&O share; each must make money in BOTH
#   halves of the 3 years to count. Reads only; ~10-20 min (loading the data); the report goes to GIR's ⚙️ System topic.
D=/home/globalbot/intraday
[ -f $D/study3y.py ] || { echo "the 3-year study (study3y.py) is needed first"; exit 1; }
cat > $D/scenlab.py <<'PY_SL'
#!/usr/bin/env python3
"""scenlab.py - patch 159: THE SCENARIO LAB (Rama, 10 Nov: "the sector rotation happened in my eyes and I was not aware - check every such
scenario over 3-4 years; the ones that work must be watched live and alert me: this is happening, go to this stock").
3 years of 5-minute candles, every F&O share, every scenario below, each judged the SAME way:
  the entry   the close of the 5-minute candle where the scenario becomes true
  the result  +1.0% its way before -0.7% against (A) and +1.5% before -1.0% (B), else out at 15:15; minus 0.06% costs
  the proof   ✅ EDGE only if it makes money in BOTH halves of the 3 years (before / after 1 May 2025), 150+ trades - a lucky stretch
              cannot pass; ⚠ = money in one half only; ✗ = no edge
SCENARIOS (long and short, mirrored)
  GAP5        a 0.3-4% gap and the first 5 minutes its way (the rule live since 152 - the yardstick)
  GAPFADE     a 1.5%+ gap and the first 15 minutes AGAINST it - trade the fade
  ORB         the first close beyond the opening 15-minute range before 11:00, on 1.5x volume, NIFTY the same way
  RS_NIFTY    10:00 - the share 1%+ up while NIFTY is down 0.2%+ (strength against the market)
  VWAP_BACK   dipped 0.5% under VWAP in the first hour, back above it 10:00-12:00, up on the day
  HOD_VOL     a new day high after 10:30 on 3x volume, the share up 1-3%
  PDH         crosses yesterday's high in the first 90 minutes without a gap above it
  NR_BREAK    yesterday a narrow day (range < 60% of its 10-day average); today breaks yesterday's high in the first hour
  OI_GAP      yesterday futures OI +5% with the price 1.5%+ the same way (NSE's file), today a gap that way + first 5 minutes its way
  HIGH52      crosses its 52-week high before 11:30
  SECTOR_PB   its sector 1%+ up at 11:00 with 70% of its shares up; the share pulled back to VWAP and closes back above it
  LAGGARD     its sector 0.8%+ up with 70% up by 10:00; the share still under half the sector's move but above VWAP (rotation)
  LEADER      the same rotation; the strongest share of the sector, above VWAP
  NIFTY_TREND NIFTY 0.5%+ by 10:15 and above its VWAP; the share above VWAP at a new day high
  PM_MOMO     14:00 - within 0.2% of its day high, 1.5%+ up
  DROP_BOUNCE 11:00 - down 4%+ while its sector is flat or up (mean reversion)
  RESULT15    a results reaction day; the first 15 minutes' direction
  python3 scenlab.py [--no-tg]        -> data/h3/scenlab.txt / .json and the report to GIR's ⚙️ System topic"""
import os, sys, json, math, statistics, datetime as dt
import numpy as np

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import study3y as S

NB, EXIT_I = S.NB, 72                     # 75 bars 09:15..15:25; out at the close of the 15:15 bar
TARGETS = {"A": (1.0, 0.7), "B": (1.5, 1.0)}
COST = 0.06
SPLIT = "2025-05-01"


def outcome(h, l, c, d, entry, i, tg, st):
    """+tg its way before -st against, from bar i+1 to EXIT_I -> net % (after costs)"""
    if i + 1 > EXIT_I:
        return None
    hh, ll = h[i + 1:EXIT_I + 1], l[i + 1:EXIT_I + 1]
    fav = ((hh / entry - 1) * 100) if d > 0 else ((1 - ll / entry) * 100)
    adv = ((ll / entry - 1) * 100) if d > 0 else ((1 - hh / entry) * 100)
    a = np.argmax(adv <= -st) if (adv <= -st).any() else 10 ** 6
    f = np.argmax(fav >= tg) if (fav >= tg).any() else 10 ** 6
    if a == 10 ** 6 and f == 10 ** 6:
        r = (c[EXIT_I] / entry - 1) * 100 * d
    elif a <= f:                                  # the same candle: count the loss (the cautious side)
        r = -st
    else:
        r = tg
    return float(r) - COST


def ctx_day(x, pc):
    o, h, l, c, v = (x[j].astype(np.float64) for j in range(5))
    tp = (h + l + c) / 3
    cv = np.cumsum(v)
    vw = np.where(cv > 0, np.cumsum(tp * v) / np.where(cv > 0, cv, 1), np.cumsum(tp) / np.arange(1, NB + 1))
    P = (c / pc - 1) * 100
    return o, h, l, c, v, vw, P


def scan(syms, DAY, M5, NIF, G, RD, F):
    """-> {scenario: [(day, sym, d, rA, rB, i)]}"""
    out = {}

    def add(name, k, s, d, i, h, l, c):
        e = c[i]
        if not e:
            return
        rA = outcome(h, l, c, d, e, i, *TARGETS["A"])
        rB = outcome(h, l, c, d, e, i, *TARGETS["B"])
        if rA is not None:
            out.setdefault(name, []).append((k, s, d, rA, rB, i))
    days = sorted({k for s in syms for k in (M5.get(s) or {})})
    pcm = {s: S.prev_close_map(DAY.get(s) or {}) for s in syms}
    dkeys = {s: sorted(DAY.get(s) or {}) for s in syms}
    didx = {s: {k: j for j, k in enumerate(dkeys[s])} for s in syms}
    sec_of = {s: n for n, v in G.items() for s in v}
    for k in days:
        P_all, C = {}, {}
        for s in syms:
            x = (M5.get(s) or {}).get(k)
            pc = pcm[s].get(k)
            if x is None or not pc or not x[5, 0]:
                continue
            C[s] = ctx_day(x, pc)
            P_all[s] = C[s][6]
        if len(C) < 50:
            continue
        sec = {}                                               # sector average path and breadth path
        for n, mem in G.items():
            m = [P_all[s] for s in mem if s in P_all]
            if len(m) >= 3:
                A = np.vstack(m)
                sec[n] = (A.mean(0), (A > 0).mean(0), A)
        nif = NIF.get(k)
        for s, (o, h, l, c, v, vw, P) in C.items():
            pc = pcm[s][k]
            op = o[0]
            gap = (op / pc - 1) * 100
            gd = 1 if gap > 0 else -1
            j = didx[s].get(k)
            Dk = DAY[s]
            prev = [Dk[dkeys[s][q]] for q in range(max(0, (j or 0) - 260), j or 0)] if j else []
            # GAP5
            if 0.3 <= abs(gap) <= 4 and (c[0] - op) * gd > 0:
                add("GAP5", k, s, gd, 0, h, l, c)
            # GAPFADE
            if abs(gap) >= 1.5 and (c[2] - op) * gd < 0:
                add("GAPFADE", k, s, -gd, 2, h, l, c)
            # ORB
            hi3, lo3 = h[:3].max(), l[:3].min()
            avgv = (prev[-1][4] / NB) if prev and prev[-1][4] else v[:3].mean()
            for i in range(3, 21):
                if c[i] > hi3 or c[i] < lo3:
                    d = 1 if c[i] > hi3 else -1
                    if v[i] >= 1.5 * avgv and nif is not None and nif[i] * d > 0:
                        add("ORB", k, s, d, i, h, l, c)
                    break
            # RS_NIFTY at 10:00 (bar 8 close)
            if nif is not None:
                if P[8] >= 1.0 and nif[8] <= -0.2:
                    add("RS_NIFTY", k, s, 1, 8, h, l, c)
                elif P[8] <= -1.0 and nif[8] >= 0.2:
                    add("RS_NIFTY", k, s, -1, 8, h, l, c)
            # VWAP_BACK
            for d in (1, -1):
                dip = ((c[:12] - vw[:12]) / vw[:12] * 100 * d <= -0.5).any()
                if dip:
                    for i in range(9, 33):
                        if (c[i] - vw[i]) * d > 0 and (c[i - 1] - vw[i - 1]) * d <= 0 and P[i] * d > 0:
                            add("VWAP_BACK", k, s, d, i, h, l, c)
                            break
            # HOD_VOL after 10:30 (bar 15+)
            rh, rl = np.maximum.accumulate(h), np.minimum.accumulate(l)
            mv = np.cumsum(v) / np.arange(1, NB + 1)                # the running average volume
            for d in (1, -1):
                for i in range(15, 66):
                    newx = (h[i] > rh[i - 1]) if d > 0 else (l[i] < rl[i - 1])
                    if newx and 1.0 <= P[i] * d <= 3.0 and v[i] >= 3 * mv[i - 1]:
                        add("HOD_VOL", k, s, d, i, h, l, c)
                        break
            if prev:
                pdh, pdl = prev[-1][1], prev[-1][2]
                # PDH / PDL in the first 90 minutes, no gap beyond it
                if op < pdh:
                    i = next((q for q in range(0, 18) if c[q] > pdh), None)
                    if i is not None:
                        add("PDH", k, s, 1, i, h, l, c)
                if op > pdl:
                    i = next((q for q in range(0, 18) if c[q] < pdl), None)
                    if i is not None:
                        add("PDH", k, s, -1, i, h, l, c)
                # NR_BREAK
                if len(prev) >= 11:
                    rng = [(p[1] - p[2]) for p in prev[-11:-1]]
                    if (pdh - pdl) < 0.6 * (sum(rng) / len(rng)):
                        for d, lv in ((1, pdh), (-1, pdl)):
                            i = next((q for q in range(0, 12) if (c[q] - lv) * d > 0), None)
                            if i is not None:
                                add("NR_BREAK", k, s, d, i, h, l, c)
                # HIGH52
                if len(prev) >= 240:
                    hi52 = max(p[1] for p in prev[-250:])
                    if op < hi52:
                        i = next((q for q in range(0, 27) if c[q] > hi52), None)
                        if i is not None:
                            add("HIGH52", k, s, 1, i, h, l, c)
                # OI_GAP
                f = F.get((s, dkeys[s][j - 1])) if j else None
                if f and f[0] and f[1] and f[0] - f[1] > 0 and len(prev) >= 2 and prev[-2][3]:
                    och = f[1] / (f[0] - f[1]) * 100
                    pch = (prev[-1][3] / prev[-2][3] - 1) * 100
                    if och >= 5 and abs(pch) >= 1.5:
                        d = 1 if pch > 0 else -1
                        if 0.3 <= gap * d <= 4 and (c[0] - op) * d > 0:
                            add("OI_GAP", k, s, d, 0, h, l, c)
            n = sec_of.get(s)
            sc = sec.get(n)
            if sc is not None:
                avg, br, A = sc
                # SECTOR_PB at 11:00 (bar 21)
                for d in (1, -1):
                    if avg[21] * d >= 1.0 and (br[21] if d > 0 else 1 - br[21]) >= 0.7:
                        touched = ((l[:22] - vw[:22]) * d <= 0).any() if d > 0 else ((h[:22] - vw[:22]) * d <= 0).any()
                        for i in range(21, 40):
                            if touched and (c[i] - vw[i]) * d > 0 and (c[i - 1] - vw[i - 1]) * d <= 0:
                                add("SECTOR_PB", k, s, d, i, h, l, c)
                                break
                # LAGGARD / LEADER at 10:00 (bar 8)
                for d in (1, -1):
                    if avg[8] * d >= 0.8 and (br[8] if d > 0 else 1 - br[8]) >= 0.7:
                        if P[8] * d < avg[8] * d * 0.5 and (c[8] - vw[8]) * d > 0:
                            add("LAGGARD", k, s, d, 8, h, l, c)
                        col = A[:, 8] * d
                        if P[8] * d >= col.max() - 1e-9 and (c[8] - vw[8]) * d > 0:
                            add("LEADER", k, s, d, 8, h, l, c)
                # DROP_BOUNCE at 11:00
                if P[21] <= -4 and avg[21] >= 0:
                    add("DROP_BOUNCE", k, s, 1, 21, h, l, c)
            # NIFTY_TREND at 10:15 (bar 11)
            if nif is not None:
                for d in (1, -1):
                    if nif[11] * d >= 0.5 and (c[11] - vw[11]) * d > 0 and ((h[11] >= h[:11].max()) if d > 0 else (l[11] <= l[:11].min())):
                        add("NIFTY_TREND", k, s, d, 11, h, l, c)
            # PM_MOMO at 14:00 (bar 57)
            if P[57] >= 1.5 and (h[:58].max() - c[57]) / c[57] * 100 <= 0.2:
                add("PM_MOMO", k, s, 1, 57, h, l, c)
            if P[57] <= -1.5 and (c[57] - l[:58].min()) / c[57] * 100 <= 0.2:
                add("PM_MOMO", k, s, -1, 57, h, l, c)
            # RESULT15
            if k in RD.get(s, set()):
                d = 1 if c[2] > op else -1
                add("RESULT15", k, s, d, 2, h, l, c)
    return out


def judge(rows):
    """-> dict of the numbers, both halves, by year"""
    def st(R, col):
        if not R:
            return {"n": 0, "pt": 0.0, "win": 0.0}
        v = [r[col] for r in R]
        return {"n": len(v), "pt": round(sum(v) / len(v), 3), "win": round(100 * sum(1 for x in v if x > 0) / len(v), 1)}
    a, b = [r for r in rows if r[0] < SPLIT], [r for r in rows if r[0] >= SPLIT]
    years = {}
    for r in rows:
        years.setdefault(r[0][:4], []).append(r)
    out = {"all": {"A": st(rows, 3), "B": st(rows, 4)}, "h1": {"A": st(a, 3), "B": st(a, 4)}, "h2": {"A": st(b, 3), "B": st(b, 4)},
           "years": {y: st(R, 3)["pt"] for y, R in sorted(years.items())}, "per_day": round(len(rows) / max(1, len({r[0] for r in rows})), 2)}
    best = max("AB", key=lambda t: out["all"][t]["pt"])
    ok = lambda t: out["h1"][t]["n"] >= 75 and out["h2"][t]["n"] >= 75 and out["h1"][t]["pt"] >= 0.08 and out["h2"][t]["pt"] >= 0.08
    out["verdict"] = "EDGE" if (ok("A") or ok("B")) and out["all"][best]["n"] >= 150 else \
                     "ONE HALF" if out["all"][best]["pt"] > 0.05 else "NO EDGE"
    out["best"] = best
    return out


def main():
    import sectors, enternow
    syms = S.fo_list()
    G = enternow.groups(sectors.load())
    DAY = {s: S.daily(s) for s in syms + ["NIFTY 50"]}
    M5 = {s: S.intraday(s) for s in syms + ["NIFTY 50"]}
    NIF = {}
    pcn = S.prev_close_map(DAY.get("NIFTY 50") or {})
    for k, x in (M5.get("NIFTY 50") or {}).items():
        if pcn.get(k):
            NIF[k] = (x[3].astype(np.float64) / pcn[k] - 1) * 100
    try:
        R = json.load(open(os.path.join(S.H3, "results.json")))
    except Exception:
        R = {}
    RD = {s: set(S.result_days(s, R, {}, sorted(DAY.get(s) or {}))) for s in syms}
    F = {}
    try:
        import sqlite3
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(S.H3, "fut.db"), uri=True)
        for d, s, foi, fch in c.execute("select d, sym, foi, fchg from fut"):
            F[(s, d)] = (foi, fch)
        c.close()
    except Exception:
        pass
    res = scan(syms, DAY, M5, NIF, G, RD, F)
    J = {n: judge(rows) for n, rows in res.items()}
    order = sorted(J, key=lambda n: ({"EDGE": 0, "ONE HALF": 1, "NO EDGE": 2}[J[n]["verdict"]], -J[n]["all"][J[n]["best"]]["pt"]))
    L = ["📋 SCENARIO LAB · %d F&O shares · %s .. %s · entry = the candle it happens · A: +1%% / -0.7%% · B: +1.5%% / -1%% · out 15:15 · costs 0.06%%" % (
        len(syms), min(NIF) if NIF else "?", max(NIF) if NIF else "?"),
         "✅ EDGE = money in BOTH halves (before / after %s) · per trade = average net %% of the share price" % SPLIT, ""]
    for n in order:
        j = J[n]; b = j["best"]
        mark = {"EDGE": "✅", "ONE HALF": "⚠", "NO EDGE": "✗"}[j["verdict"]]
        L.append("%s %-12s %5d trades (%.1f a day) · best %s: WIN %s%% · per trade %+.2f%% · 1st half %+.2f%% · 2nd half %+.2f%% · years %s" % (
            mark, n, j["all"][b]["n"], j["per_day"], b, j["all"][b]["win"], j["all"][b]["pt"], j["h1"][b]["pt"], j["h2"][b]["pt"],
            " ".join("%s %+.2f" % (y[2:], v) for y, v in j["years"].items())))
    os.makedirs(S.H3, exist_ok=True)
    json.dump({"judge": J, "order": order}, open(os.path.join(S.H3, "scenlab.json"), "w"))
    return L, J


if __name__ == "__main__":
    L, J = main()
    txt = "\n".join(L)
    print(txt)
    open(os.path.join(S.H3, "scenlab.txt"), "w").write(txt)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % S.send_tg(txt))
PY_SL
cat > $D/p159test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p159test.py - patch 159: the scenario lab on made-up days (no files): the outcome rule, a few scenarios found, the verdict"""
import os, sys, datetime as dt
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenlab as L
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
NB = L.NB
c = np.full(NB, 100.0); h = c + 0.05; l = c - 0.05
h2 = h.copy(); h2[10] = 101.2
check("outcome: +1%% reached first -> +0.94 (after costs)", abs(L.outcome(h2, l, c, 1, 100.0, 5, 1.0, 0.7) - 0.94) < 1e-9)
l2 = l.copy(); l2[8] = 99.2
check("outcome: -0.7%% first -> -0.76", abs(L.outcome(h2, l2, c, 1, 100.0, 5, 1.0, 0.7) + 0.76) < 1e-9)
check("outcome: neither -> the 15:15 close", abs(L.outcome(h, l, c, 1, 100.0, 5, 1.0, 0.7) + 0.06) < 1e-9)
days = []
d = dt.date(2025, 1, 1)
while len(days) < 30:
    if d.weekday() < 5: days.append(str(d))
    d += dt.timedelta(days=1)
def bars(path, vol=1000.0, vspike=None):
    x = np.zeros((6, NB), dtype=np.float32)
    for i in range(NB):
        c0, c1 = path(i), path(i + 1)
        x[:, i] = (c0, max(c0, c1) + 0.02, min(c0, c1) - 0.02, c1, vol * (5 if vspike == i else 1), 1)
    return x
syms = ["GAPPY", "FLAT"] + ["F%d" % i for i in range(52)]
DAY = {s: {k: (100.0, 100.5, 99.5, 100.0, 75000) for k in days} for s in syms}
M5 = {s: {} for s in syms}
k = days[20]
M5["GAPPY"][k] = bars(lambda i: 101.0 + 0.04 * i)                      # gaps +1% and climbs
for s in syms[1:]:
    M5[s][k] = bars(lambda i: 100.0)
NIF = {k: np.linspace(0, 0.6, NB)}
res = L.scan(syms, DAY, M5, NIF, {"X": ["F1", "F2", "F3"]}, {}, {})
print({n: len(v) for n, v in res.items()})
g = res.get("GAP5") or []
check("GAP5 found for GAPPY (gap +1%%, first 5 min up) and it wins", any(r[1] == "GAPPY" and r[2] == 1 and r[3] > 0.9 for r in g))
check("FLAT gives no GAP5", all(r[1] != "FLAT" for r in g))
rows = [("2024-06-01", "X", 1, 0.5, 0.6, 1)] * 100 + [("2025-08-01", "X", 1, 0.4, 0.3, 1)] * 100
check("verdict EDGE when both halves make money", L.judge(rows)["verdict"] == "EDGE")
rows2 = [("2024-06-01", "X", 1, 0.5, 0.6, 1)] * 100 + [("2025-08-01", "X", 1, -0.4, -0.5, 1)] * 100
check("verdict not EDGE when one half loses", L.judge(rows2)["verdict"] != "EDGE")
print("P159 SCENARIO LAB TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile scenlab.py && timeout 120 python3 p159test.py > /dev/null 2>&1 && echo "    p159test.py passed" || { echo "the lab's own test failed - nothing run"; exit 1; }
echo "    loading 3 years of candles and testing 17 scenarios (10-20 min)..."
cd /home/globalbot && set -a && source .env && set +a && cd $D && nice -n 10 python3 scenlab.py
