#!/bin/bash
# PATCH 204 - THE 14:00 STUDY (reads only, sends nothing): in at 14:00 its way, out 15:25, +1% before -0.5% - by the day's move, near the
#   day's high / low, VWAP, the last hour's volume, NIFTY with it or against, by year - 3 years of 5-min candles, every F&O share.
set -u
D=/home/globalbot/intraday
cat > $D/afternoon.py <<'PY_A'
#!/usr/bin/env python3
"""afternoon.py - patch 204: THE 14:00 STUDY (Rama, 11 Nov: "I have seen many times there are a few stocks worth investing at the start
and just before closing - at 14:00"). GIR's 3 years of 5-min candles, every F&O share, every day - reads only, sends nothing.
  AT 14:00     the share's move on the day, against its VWAP, how close to its day high (low), the volume of the last hour vs the
               morning, and NIFTY's own move
  THE TRADE    in at 14:00 its way, out at 15:25 · scored +1% before -0.5% (an afternoon move; an ATM option +30-40%)
  THE GROUPS   a strong day (1-2% · 2-4% · 4%+) · at / near the day's high (within 0.5%) · above VWAP · the last hour's volume up
               · with NIFTY or against it · by year - against every share-day at 14:00 (the base)
  python3 afternoon.py      -> prints, data/afternoon_study.txt"""
import os, sys
import numpy as np
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
I14, I1525, TGT, STP = 56, 74, 1.0, 0.5                 # bar 56 = 13:55-14:00 (its close = the 14:00 price) · bar 74 = 15:25


def read_day(x, pc):
    """-> dict at 14:00 or None"""
    if x is None or not x[5][:I1525 + 1].all() or not pc:
        return None
    c = x[3]; h = x[1]; l = x[2]; v = x[4]
    px = float(c[I14])
    tp = (h[:I14 + 1] + l[:I14 + 1] + c[:I14 + 1]) / 3
    vs = float(v[:I14 + 1].sum())
    vw = float((tp * v[:I14 + 1]).sum() / vs) if vs else px
    dh, dl = float(h[:I14 + 1].max()), float(l[:I14 + 1].min())
    vm = float(v[:I14 - 11].mean()) if I14 > 12 else 0
    vl = float(v[I14 - 11:I14 + 1].mean())
    return {"px": px, "chg": (px / pc - 1) * 100, "vw": vw, "nh": (1 - px / dh) * 100 if dh else 9, "nl": (px / dl - 1) * 100 if dl else 9,
            "volx": (vl / vm) if vm else 1.0, "x": x}


def score(x, px, side):
    stop, tgt = px * (1 - STP / 100 * side), px * (1 + TGT / 100 * side)
    for i in range(I14 + 1, I1525 + 1):
        if (x[2][i] <= stop) if side > 0 else (x[1][i] >= stop):
            return ("LOSS", -STP)
        if (x[1][i] >= tgt) if side > 0 else (x[2][i] <= tgt):
            return ("WIN", TGT)
    return ("OPEN", (float(x[3][I1525]) / px - 1) * 100 * side)


def tally(L):
    n = len(L)
    if not n:
        return "    0"
    w = sum(1 for r in L if r[0] == "WIN"); l = sum(1 for r in L if r[0] == "LOSS")
    return "%6d · WIN %3d%% · LOSS %3d%% · per trade %+.2f%% · to 15:25 avg %+.2f%%" % (n, round(100 * w / n), round(100 * l / n), sum(r[1] for r in L) / n, sum(r[2] for r in L) / n)


def run(syms, get, nifty=None):
    R, base = [], []
    for s in syms:
        D, M = get(s)
        if not D or not M:
            continue
        ks = sorted(D)
        for j in range(1, len(ks)):
            k = ks[j]
            d = read_day(M.get(k), D[ks[j - 1]][3])
            if not d:
                continue
            nf = (nifty or {}).get(k)
            for side in (1, -1):
                res, mv = score(d["x"], d["px"], side)
                end = (float(d["x"][3][I1525]) / d["px"] - 1) * 100 * side
                if j % 5 == 0:
                    base.append((res, mv, end))
                way = d["chg"] * side
                if way < 1:
                    continue
                R.append({"res": res, "mv": mv, "end": end, "way": way, "vwap": (d["px"] - d["vw"]) * side > 0, "near": (d["nh"] if side > 0 else d["nl"]) <= 0.5,
                          "volup": d["volx"] >= 1.2, "nifty": None if nf is None else nf * side > 0, "y": k[:4], "side": side})
    return R, base


def report(R, base):
    T = lambda X: [(r["res"], r["mv"], r["end"]) for r in X]
    L = ["THE 14:00 STUDY - in at 14:00 its way, out 15:25 · +1% before -0.5% · 3 years of 5-min candles",
         "BASE (every share-day at 14:00, both sides):  " + tally(base), ""]
    for side, nm in ((1, "UP ON THE DAY -> CE"), (-1, "DOWN ON THE DAY -> PE")):
        X = [r for r in R if r["side"] == side]
        L.append(nm)
        L.append("  1%+ its way at 14:00 (all)                  " + tally(T(X)))
        for lo, hi, t in ((1, 2, "1-2%"), (2, 4, "2-4%"), (4, 99, "4%+")):
            L.append("  %-44s %s" % (t + " its way", tally(T([r for r in X if lo <= r["way"] < hi]))))
        L.append("  %-44s %s" % ("at / near its day %s (within 0.5%%)" % ("high" if side > 0 else "low"), tally(T([r for r in X if r["near"]]))))
        L.append("  %-44s %s" % ("NOT near it (pulled back)", tally(T([r for r in X if not r["near"]]))))
        L.append("  %-44s %s" % ("%s VWAP" % ("above" if side > 0 else "below"), tally(T([r for r in X if r["vwap"]]))))
        L.append("  %-44s %s" % ("the last hour's volume 1.2x+ the morning", tally(T([r for r in X if r["volup"]]))))
        L.append("  %-44s %s" % ("NIFTY the same way", tally(T([r for r in X if r["nifty"] is True]))))
        L.append("  %-44s %s" % ("NIFTY the other way", tally(T([r for r in X if r["nifty"] is False]))))
        best = [r for r in X if r["near"] and r["vwap"] and r["volup"] and r["nifty"] is True and r["way"] >= 2]
        L.append("  %-44s %s" % ("ALL: 2%+, near the extreme, VWAP, volume, NIFTY", tally(T(best))))
        for y in sorted({r["y"] for r in best}):
            L.append("     %-41s %s" % ("  the same, " + y, tally(T([r for r in best if r["y"] == y]))))
        L.append("")
    return L


if __name__ == "__main__":
    import study3y as S
    syms = S.fo_list()
    NI = {}
    try:
        nd, nm = S.daily("NIFTY 50"), S.intraday("NIFTY 50")
        ks = sorted(nd)
        for j in range(1, len(ks)):
            x = nm.get(ks[j])
            if x is not None and x[5][I14]:
                NI[ks[j]] = (float(x[3][I14]) / nd[ks[j - 1]][3] - 1) * 100
    except Exception as ex:
        print("NIFTY: %s" % ex)
    R, base = run(syms, lambda s: (S.daily(s), S.intraday(s)), NI)
    txt = "\n".join(report(R, base))
    print(txt)
    open(os.path.join(BASE, "data", "afternoon_study.txt"), "w").write(txt + "\n")
PY_A
cat > $D/p204test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p204test.py - PATCH 204: the 14:00 study on made-up days (no server data)"""
import os, sys, datetime as dt
import numpy as np
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import afternoon as A
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
def day(path, vol):
    x = np.zeros((6, 75), dtype=np.float32); p0 = path[0]
    for i, c in enumerate(path):
        x[:, i] = (p0, max(p0, c) * 1.0001, min(p0, c) * 0.9999, c, vol[i], 1); p0 = c
    return x
# a share up 2.5% at 14:00, at its high, above VWAP, the last hour's volume up, trending into the close -> WIN
up = [100 + 0.045 * i for i in range(57)] + [102.52 + 0.08 * i for i in range(18)]
x1 = day(up, [1000] * 45 + [2000] * 30)
# a share up 1.5% at 14:00 that gives it back after 14:00 -> LOSS
fade = [100 + 0.027 * i for i in range(57)] + [101.5 - 0.06 * i for i in range(18)]
x2 = day(fade, [1000] * 75)
D = {"UPX": {"2026-11-10": (100, 100, 100, 100.0, 1), "2026-11-11": (100, 104, 100, 104, 1)}, "FADEX": {"2026-11-10": (100, 100, 100, 100.0, 1), "2026-11-11": (100, 101.6, 100, 100.5, 1)}}
M = {"UPX": {"2026-11-11": x1}, "FADEX": {"2026-11-11": x2}}
R, base = A.run(["UPX", "FADEX"], lambda s: (D[s], M[s]), {"2026-11-11": 0.6})
u = [r for r in R if r["side"] > 0 and r["way"] >= 2]
check("UP 2.5%% at 14:00, at its high, VWAP, volume, NIFTY up -> WIN (%s)" % [(r["res"], round(r["mv"], 2)) for r in u], len(u) == 1 and u[0]["res"] == "WIN" and u[0]["near"] and u[0]["vwap"] and u[0]["volup"] and u[0]["nifty"])
f = [r for r in R if r["side"] > 0 and 1 <= r["way"] < 2]
check("UP 1.5%% that gives it back -> LOSS (%s)" % [r["res"] for r in f], len(f) == 1 and f[0]["res"] == "LOSS")
L = A.report(R, base)
print("\n".join(L[:14]))
check("the report: the groups and the all-together line", any("ALL: 2%+" in l for l in L) and any("NIFTY the same way" in l for l in L))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile afternoon.py || { echo "❌ does not compile"; exit 1; }
echo "=== the test (made-up days)"
timeout 60 python3 $D/p204test.py | grep -E "  ok|FAIL|PASSED"
echo "=== THE 14:00 STUDY (several minutes)"
nice -n 10 timeout 3600 python3 $D/afternoon.py > /dev/null 2>&1
cat $D/data/afternoon_study.txt
echo
echo "✅ patch 204 study done - nothing was sent or changed."
