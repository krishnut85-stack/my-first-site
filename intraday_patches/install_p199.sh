#!/bin/bash
# PATCH 199 - ROOM TO RUN, a STUDY (nothing sent, nothing restarts): catch the share BEFORE the run, only with 3%+ room to the next
#   HOLDING wall (a shrinking wall is not a wall). GAP + ROOM at 09:20 · SHIFT + ROOM 09:30-13:30 (SBIN: the wall above bought back,
#   puts written at / above the price, the share still under 1.5%). Scored the way an option is traded: +1.5% before -0.8%.
set -u
D=/home/globalbot/intraday
[ -f $D/tradecard.py ] || { echo "patch 196 (tradecard.py) is not in - run install_p196.sh first"; exit 1; }
cat > $D/roomscan.py <<'PY_R'
#!/usr/bin/env python3
"""roomscan.py - patch 199: ROOM TO RUN - catch the share BEFORE the run, only when there is room (Rama, 11 Nov: "I don't want a noisy
alert after the stock has already run and has room for 0.5%" · SBIN: the 1040 / 1050 call walls were bought back (-56% / -67%) and puts
written at 1060-1080 (+341% to +1,252%) - the walls fell, the 1000 CE went 15 -> 60). A STUDY first: nothing is sent.

  GAP + ROOM     09:20: a 0.5-3% opening gap that the first 5 minutes confirm (GIR's 3-year gap study: the confirmed gap paid) and
                 3%+ room to the next HOLDING wall
  SHIFT + ROOM   09:30-13:30: in the last 30 minutes the wall just above (within 3%) lost 8%+ of its calls (bought back) AND puts were
                 written at or above the price-1% more than calls added above (the sellers moved up) - the share still under 1.5% its
                 way on the day (the run not begun) - and 3%+ room to the next HOLDING wall. PE: the mirror.
  HOLDING WALL   a big strike (60%+ of the biggest OI within 8%) whose OI did NOT fall 5%+ in the last 30 minutes - a shrinking
                 wall is not a wall
  NEVER          room under 3% · already 2%+ its way · after 13:30
  SCORE          the way Rama trades an option: +1.5% on the share (an ATM option +50-80%) before -0.8% against, by 15:15 ·
                 and the best move within 2 hours
  python3 roomscan.py --replay [day] · python3 roomscan.py --study 20"""
import os, sys, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import tradecard as T

TGT, STP, ROOM, LATE, BIG = 1.5, 0.8, 3.0, 2.0, 0.6
SHIFT_FALL, SHIFT_LAST, GAP_LO, GAP_HI = 8.0, 810, 0.5, 3.0          # 13:30


def holding_wall(snap, old, px, side):
    """-> (the nearest big wall that is NOT shrinking, its distance %) - (None, None) when none within 8%"""
    if not snap or not px:
        return None, None
    kd = "CE" if side > 0 else "PE"
    xs = [(k, T._num(v[0])) for (k, d), v in snap[2].items() if d == kd and (k > px if side > 0 else k < px) and abs(k / px - 1) * 100 <= T.BAND]
    if not xs:
        return None, None
    mx = max(o for k, o in xs)
    for k, o in sorted([(k, o) for k, o in xs if mx > 0 and o >= BIG * mx], key=lambda x: abs(x[0] - px)):
        o0 = T._num((old[2].get((k, kd)) or (0, 0))[0]) if old else 0
        if o0 and o <= 0.95 * o0:
            continue                                            # shrinking: the writers are leaving - not a wall
        return k, abs(k / px - 1) * 100
    return None, None


def shift(snap, old, px, side):
    """the sellers moved its way in the last 30 min: (yes?, the wall bought back, its OI fall %)"""
    if not snap or not old or not px:
        return False, None, 0.0
    kd, ok = ("CE", "PE") if side > 0 else ("PE", "CE")
    near = [(k, T._num(v[0])) for (k, d), v in snap[2].items() if d == kd and ((px < k <= px * 1.03) if side > 0 else (px * 0.97 <= k < px))]
    best = (None, 0.0)
    for k, o in near:
        o0 = T._num((old[2].get((k, kd)) or (0, 0))[0])
        if o0 > 0 and (1 - o / o0) * 100 > best[1]:
            best = (k, (1 - o / o0) * 100)
    if best[1] < SHIFT_FALL:
        return False, best[0], best[1]
    add_ok = add_kd = 0.0                                       # puts written at / above price-1% vs calls added above (CE)
    for (k, d), v in snap[2].items():
        o0 = T._num((old[2].get((k, d)) or (0, 0))[0]); dd = T._num(v[0]) - o0
        if dd <= 0:
            continue
        if d == ok and ((k >= px * 0.99) if side > 0 else (k <= px * 1.01)):
            add_ok += dd
        elif d == kd and ((k > px) if side > 0 else (k < px)):
            add_kd += dd
    return add_ok > add_kd and add_ok > 0, best[0], best[1]


def score(C, i, px, side):
    stop, tgt = px * (1 - STP / 100 * side), px * (1 + TGT / 100 * side)
    best, end_t = 0.0, C[i][0] + 5 + 120
    res = None
    for m, o, h, l, c, v in C[i + 1:]:
        if m + 5 > T.EXIT_M:
            break
        fav = (h / px - 1) * 100 if side > 0 else (1 - l / px) * 100
        if m + 5 <= end_t:
            best = max(best, fav)
        if res is None:
            if (l <= stop) if side > 0 else (h >= stop):
                res = ("LOSS", -STP)
            elif (h >= tgt) if side > 0 else (l <= tgt):
                res = ("WIN", TGT)
    if res is None:
        last = [x for x in C if x[0] + 5 <= T.EXIT_M]
        res = ("OPEN", ((last[-1][4] / px - 1) * 100 * side) if last else 0.0)
    return res[0], res[1], best


def read(D, s):
    C, pc = D.candles.get(s) or [], D.pc.get(s)
    if len(C) < 4 or not pc:
        return []
    ch = D.chain(s, 24 * 60) or []
    out, done = [], set()
    o0 = C[0][1]
    gap = (o0 / pc - 1) * 100
    # GAP + ROOM at 09:20 (the first 5-min candle closed its way)
    side = 1 if gap > 0 else -1
    if GAP_LO <= abs(gap) <= GAP_HI and (C[0][4] - o0) * side > 0:
        snap = T.snap_at(ch, 565); old = T.snap_at(ch, 565, 30) or snap
        w, dist = holding_wall(snap, old, C[0][4], side)
        if snap and (w is None or dist >= ROOM):
            r = score(C, 0, C[0][4], side)
            out.append({"kind": "GAP", "t": "09:20", "s": s, "side": side, "px": C[0][4], "chg": (C[0][4] / pc - 1) * 100, "wall": w, "dist": dist,
                        "why": "gap %+.1f%% held the first 5 min" % gap, "res": r[0], "mv": r[1], "best": r[2]})
            done.add(side)
        elif not snap:
            out.append({"kind": "GAP?", "s": s, "t": "09:20", "side": side})
    # SHIFT + ROOM, 09:30-13:30
    for i, (m, o, h, l, c, v) in enumerate(C):
        t = m + 5
        if t < 570 or t > SHIFT_LAST:
            continue
        chg = (c / pc - 1) * 100
        for side in (1, -1):
            if side in done or chg * side >= 1.5 or chg * side < 0:
                continue
            snap, old = T.snap_at(ch, t), T.snap_at(ch, t, 30)
            if not snap or not old or snap[0] == old[0]:
                continue
            ok, bk, fall = shift(snap, old, c, side)
            if not ok:
                continue
            w, dist = holding_wall(snap, old, c, side)
            if w is not None and dist < ROOM:
                continue
            r = score(C, i, c, side)
            out.append({"kind": "SHIFT", "t": T.hm(t), "s": s, "side": side, "px": c, "chg": chg, "wall": w, "dist": dist,
                        "why": "the %g %s wall bought back -%.0f%%, puts written at/above the price" % (bk, "CE" if side > 0 else "PE", fall) if side > 0 else
                               "the %g PE floor bought back -%.0f%%, calls written at/below the price" % (bk, fall),
                        "res": r[0], "mv": r[1], "best": r[2]})
            done.add(side)
    return out


def line(x):
    a = "▲ CE" if x["side"] > 0 else "▼ PE"
    room = ("next holding wall %g = %.1f%% room" % (x["wall"], x["dist"])) if x["wall"] else "no holding wall within 8%"
    return "  %-5s %s %-11s %s ₹%s %+.1f%% · %s · %s → %s %+.1f%% (best in 2 h %+.1f%%)" % (
        x["kind"], x["t"], x["s"], a, format(round(x["px"], 2), ","), x["chg"], x["why"], room, x["res"], x["mv"], x["best"])


def tally(X):
    if not X:
        return "none"
    w = sum(1 for x in X if x["res"] == "WIN"); l = sum(1 for x in X if x["res"] == "LOSS")
    return "%d · WIN %d · LOSS %d · open %d · per trade %+.2f%% (share) · best in 2 h avg %+.2f%%" % (
        len(X), w, l, len(X) - w - l, sum(x["mv"] for x in X) / len(X), sum(x["best"] for x in X) / len(X))


def day(d, syms=None):
    import enternow
    syms = syms or T.fo_syms()
    for s_ in syms:
        if s_ not in T._H:
            try:
                T._H[s_] = enternow._hist(s_)
            except Exception:
                T._H[s_] = {}
    D = enternow.StoredData(d, syms, T._H)
    X, first = [], None
    for s in sorted(D.candles):
        try:
            X += read(D, s)
        except Exception as ex:
            print("  %s: %s" % (s, str(ex)[:80]))
        ch = D.chain(s, 24 * 60) or []
        if ch:
            first = min(first or 9999, ch[0][0])
    return X, len(D.candles), first


def main(a):
    if a[:1] == ["--study"]:
        days = T.chain_days(int(a[1]) if len(a) > 1 else 20)
        allx = []
        for d in days:
            X, n, first = day(d)
            G = [x for x in X if x["kind"] in ("GAP", "SHIFT")]
            allx += G
            print("%s · %d shares · the chain from %s · GAP %s · SHIFT %s · gaps with no chain at 09:20: %d" % (
                d, n, T.hm(first) if first else "-", tally([x for x in G if x["kind"] == "GAP"]), tally([x for x in G if x["kind"] == "SHIFT"]),
                sum(1 for x in X if x["kind"] == "GAP?")))
        print("\nTHE %d DAYS" % len(days))
        print("  GAP + ROOM    " + tally([x for x in allx if x["kind"] == "GAP"]))
        print("  SHIFT + ROOM  " + tally([x for x in allx if x["kind"] == "SHIFT"]))
        return
    d = a[1] if len(a) > 1 else (T.chain_days(1) or [str(dt.date.today())])[-1]
    X, n, first = day(d)
    print("ROOM TO RUN · %s · %d shares · the option chain stored from %s · nothing sent\n" % (d, n, T.hm(first) if first else "-"))
    for x in sorted([x for x in X if x["kind"] in ("GAP", "SHIFT")], key=lambda x: x["t"]):
        print(line(x))
    print("\n  GAP + ROOM    " + tally([x for x in X if x["kind"] == "GAP"]))
    print("  SHIFT + ROOM  " + tally([x for x in X if x["kind"] == "SHIFT"]))
    print("  gaps 0.5-3%% the chain could not judge at 09:20 (no reading yet): %d" % sum(1 for x in X if x["kind"] == "GAP?"))


if __name__ == "__main__":
    main(sys.argv[1:] or ["--replay"])
PY_R
cat > $D/p199test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p199test.py - PATCH 199: ROOM TO RUN on made-up days (no server data)"""
import os, sys
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import roomscan as R
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
class FakeD:
    def __init__(self):
        self.candles, self.pc, self._c = {}, {}, {}
    def chain(self, s, upto):
        return [x for x in self._c.get(s, []) if x[0] <= upto]
def bars(path, o0=None):
    out, prev = [], (o0 if o0 is not None else path[0])
    for i, c in enumerate(path):
        out.append((555 + 5 * i, prev, max(prev, c) * 1.0003, min(prev, c) * 0.9997, c, 1000)); prev = c
    return out
D = FakeD()
# 1 SBIN-like: flat ~1042 (+0.3%) till 10:30, the 1050 call wall bought back (-43%) and puts written at 1040-1060 between 10:00 and 10:30,
#   the next big wall 1100 (5.6% away) holding -> SHIFT at 10:30, then it runs to 1062 -> WIN
p = [1041 + 0.1 * (i % 3) for i in range(15)] + [1042 + 0.4 * i for i in range(51)] + [1062] * 9
D.candles["SBINX"] = bars(p); D.pc["SBINX"] = 1039.0
def ch_sb(m, after):
    return (m, 1042.0, {(1050.0, "CE"): (2000000 if after else 3500000, 20), (1060.0, "CE"): (3200000, 12), (1070.0, "CE"): (3000000, 8),
                        (1100.0, "CE"): (7400000, 3), (1040.0, "PE"): (1600000 if after else 1000000, 10), (1060.0, "PE"): (1500000 if after else 300000, 22)}, "x")
D._c["SBINX"] = [ch_sb(m, m >= 630) for m in range(555, 931, 15)]
# 2 the same shift, but a big HOLDING wall 1.2% above (growing) -> no card
D.candles["WALLX"] = bars(p); D.pc["WALLX"] = 1039.0
def ch_w(m, after):
    x = ch_sb(m, after); d = dict(x[2]); d[(1055.0, "CE")] = (9000000 if after else 8500000, 15); return (m, x[1], d, "x")
D._c["WALLX"] = [ch_w(m, m >= 630) for m in range(555, 931, 15)]
# 3 a GAP +1.2% that holds its first 5 min, no big call wall within 8% -> GAP at 09:20, it runs +1.6% -> WIN
p3 = [101.4] + [101.4 + 0.03 * i for i in range(74)]
D.candles["GAPX"] = bars(p3, o0=101.2); D.pc["GAPX"] = 100.0
D._c["GAPX"] = [(m, 101.3, {(110.0, "CE"): (900000, 1), (100.0, "PE"): (800000, 2)}, "x") for m in range(555, 931, 15)]
# 4 LATE: the same shift when the share is already +2.1% -> no card
p4 = [1061 + 0.05 * i for i in range(75)]
D.candles["LATEX"] = bars(p4); D.pc["LATEX"] = 1039.0
D._c["LATEX"] = [ch_sb(m, m >= 630) for m in range(555, 931, 15)]
X = {s: R.read(D, s) for s in D.candles}
sb = [x for x in X["SBINX"] if x["kind"] == "SHIFT"]
check("SBIN-like: SHIFT ▲ CE before the run (%s)" % [(x["t"], round(x["chg"], 2)) for x in sb], len(sb) == 1 and sb[0]["side"] == 1 and sb[0]["chg"] < 1.5)
check("... the shrinking 1050 wall is not counted; the next HOLDING wall 1100 gives the room (%s)" % (sb[0]["wall"] if sb else "-"), sb and sb[0]["wall"] == 1100.0 and sb[0]["dist"] >= 3)
check("... WIN: +1.5%% on the share (%s)" % (sb[0]["res"] if sb else "-"), sb and sb[0]["res"] == "WIN")
check("a big holding wall 1.2% above: no card", not [x for x in X["WALLX"] if x["kind"] == "SHIFT"])
g = [x for x in X["GAPX"] if x["kind"] == "GAP"]
check("GAP +1.2%% held the first 5 min, room: GAP at 09:20 → %s" % (g[0]["res"] if g else "-"), len(g) == 1 and g[0]["res"] == "WIN")
check("already +2.1% on the day: no card (late)", not [x for x in X["LATEX"] if x["kind"] in ("GAP", "SHIFT")])
print("\n".join(R.line(x) for xs in X.values() for x in xs if x["kind"] in ("GAP", "SHIFT")))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile roomscan.py || { echo "❌ does not compile"; exit 1; }
echo "=== the test (made-up days: SBIN-like, a holding wall too close, a gap, a late one)"
timeout 60 python3 $D/p199test.py | grep -E "  ok|FAIL|PASSED"
echo
echo "=== TODAY"
nice -n 10 timeout 900 python3 $D/roomscan.py --replay $(TZ=Asia/Kolkata date +%Y-%m-%d) > $D/data/roomscan_today.txt 2>&1; cat $D/data/roomscan_today.txt
echo
echo "=== THE STORED DAYS"
nice -n 10 timeout 1800 python3 $D/roomscan.py --study 20 > $D/data/roomscan_study.txt 2>&1; cat $D/data/roomscan_study.txt
echo
echo "✅ patch 199 study done - nothing was sent or changed."
