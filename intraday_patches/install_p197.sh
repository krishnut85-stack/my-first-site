#!/bin/bash
# PATCH 197 - THE LINK, a 3-year STUDY (reads only - nothing sent, nothing restarts). Futures money in the evening (a LONG BUILD-UP:
#   price +1%+ and futures OI +5%+ -> CE · a SHORT BUILD-UP -> PE) -> GO next morning when the share confirms (a 5-min close beyond
#   yesterday's high / low, 09:20-10:30, not after a 3%+ gap) -> scored +2% before -1% by 15:15. By OI size, price size, how it
#   closed, the room to the 20-day high / low, and by year - against the same morning rule with no build-up.
set -u
D=/home/globalbot/intraday
cat > $D/buildupstudy.py <<'PY_S'
#!/usr/bin/env python3
"""buildupstudy.py - patch 197: THE LINK - futures money -> the share's way -> the room (Rama, 11 Nov: "there should be some link
between futures investment and the stock going up, and something that clearly tells whether to invest in PE or CE and whether
we have room to play"). COROMANDEL 11 Nov: the evening before, futures OI +13% with the price up (a LONG BUILD-UP); the next day
it held, broke out, ran +6%. GIR's 3 years (data/h3: daily candles, 5-min candles, NSE's daily futures OI) - reads only.

THE EVENING (day 0)   LONG BUILD-UP  -> CE: the price +1%+ and the futures OI +5%+ that day
                      SHORT BUILD-UP -> PE: the price -1%+ and the futures OI +5%+
THE MORNING (day 1)   GO when the share CONFIRMS between 09:20 and 10:30: a 5-min close beyond yesterday's high (CE) / low (PE)
                      - not when it opened 3%+ away already (late)
THE ROOM              to the 20-day high (CE) / low (PE) from the entry: none in the way (a new high / low) · 3%+ · 1.5-3% · under 1.5%
THE SCORE             +2% its way before 1% against, by 15:15 (2 : 1) -> WIN / LOSS / OPEN (the 15:15 move) · per trade = the average
Compared with: the same morning rule on EVERY share-day (no build-up) - so the build-up's own value shows - and by year (it must hold
in each year, not in one lucky stretch).
  python3 buildupstudy.py          -> prints and writes data/h3/buildup_study.txt"""
import os, sys, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
WIN, STOP, LATE_GAP = 2.0, 1.0, 3.0
I920, I1030, I1515 = 1, 15, 72                    # 5-min bar indices: 09:20, 10:30, 15:15 (bar 0 = 09:15)


def oi_pct(f):
    foi, fch = f
    return (fch / (foi - fch) * 100) if (foi and fch is not None and foi - fch > 0) else None


def signals(D, F, s):
    """-> [(day0, side, price %, OI %, close position 0-1)] for one share"""
    out = []
    ks = sorted(D)
    for i in range(1, len(ks)):
        k = ks[i]
        f = F.get((s, k))
        if not f:
            continue
        o, h, l, c, v = D[k]
        pc = D[ks[i - 1]][3]
        if not pc:
            continue
        ch = (c / pc - 1) * 100
        op = oi_pct(f)
        if op is None or op < 5:
            continue
        pos = (c - l) / (h - l) if h > l else 0.5
        if ch >= 1:
            out.append((k, 1, ch, op, pos))
        elif ch <= -1:
            out.append((k, -1, ch, op, 1 - pos))
    return out


def trade(D, M, k0, k1, side, ks=None, idx=None):
    """day 1: GO at the first 5-min close beyond day 0's high / low between 09:20 and 10:30 -> (result, move %, room %, gap %) or None"""
    x = M.get(k1)
    if x is None or not x[5][:I1030 + 1].all() or x[0][0] <= 0:
        return None
    o0, h0, l0, c0, v0 = D[k0]
    hi, lo, cl, op = x[1], x[2], x[3], x[0]
    gap = (op[0] / c0 - 1) * 100 * side
    if gap >= LATE_GAP:
        return ("LATE", 0.0, None, gap)
    lvl = h0 if side > 0 else l0
    ent = None
    for i in range(I920, I1030 + 1):
        if (cl[i] > lvl) if side > 0 else (cl[i] < lvl):
            ent = i; break
    if ent is None:
        return ("NO GO", 0.0, None, gap)
    px = float(cl[ent])
    ks = ks or sorted(D)
    j = idx[k1] if idx else ks.index(k1)
    past = [D[ks[t]] for t in range(max(0, j - 20), j)]
    if side > 0:
        ref = max(p[1] for p in past) if past else None
        room = (ref / px - 1) * 100 if ref and ref > px else None
    else:
        ref = min(p[2] for p in past) if past else None
        room = (1 - ref / px) * 100 if ref and ref < px else None
    for i in range(ent + 1, I1515 + 1):
        fav = (hi[i] / px - 1) * 100 if side > 0 else (1 - lo[i] / px) * 100
        adv = (lo[i] / px - 1) * 100 if side > 0 else (1 - hi[i] / px) * 100
        if adv <= -STOP:
            return ("LOSS", -STOP, room, gap)
        if fav >= WIN:
            return ("WIN", WIN, room, gap)
    return ("OPEN", (float(cl[I1515]) / px - 1) * 100 * side, room, gap)


def tally(L):
    n = len(L)
    if not n:
        return "  0 trades"
    w = sum(1 for r in L if r[0] == "WIN"); l = sum(1 for r in L if r[0] == "LOSS")
    per = sum(r[1] for r in L) / n
    return "%5d trades · WIN %3d%% · LOSS %3d%% · open %3d%% · per trade %+.2f%%" % (n, round(100 * w / n), round(100 * l / n), round(100 * (n - w - l) / n), per)


def room_b(r):
    return "no wall (new high/low)" if r is None else "room 3%+" if r >= 3 else "room 1.5-3%" if r >= 1.5 else "room under 1.5%"


def run(DAY, F, M5, syms, get=None):
    """get(s) -> (daily, 5-min) for one share at a time (the server: one share in memory at a time)"""
    rows, base, late, nogo, recent = [], [], 0, 0, []
    last_month = ""
    for s in syms:
        if get is not None:
            D, M = get(s)
        else:
            D, M = DAY.get(s) or {}, M5.get(s) or {}
        if not D or not M:
            continue
        ks = sorted(D)
        idx = {k: i for i, k in enumerate(ks)}
        last_month = max(last_month, ks[-1][:7])
        nxt = {ks[i]: ks[i + 1] for i in range(len(ks) - 1)}
        for k0, side, ch, op, pos in signals(D, F, s):
            k1 = nxt.get(k0)
            if not k1:
                continue
            r = trade(D, M, k0, k1, side, ks, idx)
            if r is None:
                continue
            if r[0] == "LATE":
                late += 1; continue
            if r[0] == "NO GO":
                nogo += 1; continue
            rows.append((r[0], r[1], r[2], side, ch, op, pos, k1[:4], s, k1))
        for i in range(21, len(ks) - 1, 3):                    # the same morning rule on every 3rd share-day, both sides (the base)
            for side in (1, -1):
                r = trade(D, M, ks[i], ks[i + 1], side, ks, idx)
                if r and r[0] not in ("LATE", "NO GO"):
                    base.append((r[0], r[1]))
    recent = [r for r in rows if r[9][:7] == last_month]
    L = ["THE LINK - futures build-up in the evening -> GO next morning when it confirms (3 years, 5-min candles)",
         "score: +%g%% before -%g%% by 15:15 · GO = a 5-min close beyond yesterday's high / low, 09:20-10:30" % (WIN, STOP), ""]
    L.append("BASE  the same morning rule on any share-day, no build-up:   " + tally(base))
    for side, nm in ((1, "LONG BUILD-UP -> CE"), (-1, "SHORT BUILD-UP -> PE")):
        X = [r for r in rows if r[3] == side]
        L.append("")
        L.append("%-22s all:                    %s" % (nm, tally(X)))
        for lo_, hi_, t in ((5, 10, "futures OI +5-10%"), (10, 20, "futures OI +10-20%"), (20, 1e9, "futures OI +20%+")):
            L.append("   %-36s %s" % (t, tally([r for r in X if lo_ <= r[5] < hi_])))
        for lo_, hi_, t in ((1, 3, "price 1-3% that day"), (3, 6, "price 3-6%"), (6, 99, "price 6%+")):
            L.append("   %-36s %s" % (t, tally([r for r in X if lo_ <= abs(r[4]) < hi_])))
        L.append("   %-36s %s" % ("closed strong (top quarter of the day)", tally([r for r in X if r[6] >= 0.75])))
        L.append("   %-36s %s" % ("closed weak (bottom half)", tally([r for r in X if r[6] < 0.5])))
        for b in ("no wall (new high/low)", "room 3%+", "room 1.5-3%", "room under 1.5%"):
            L.append("   %-36s %s" % (b, tally([r for r in X if room_b(r[2]) == b])))
        for y in sorted({r[7] for r in X}):
            L.append("   year %-31s %s" % (y, tally([r for r in X if r[7] == y])))
    L.append("")
    L.append("no GO by 10:30 (it never confirmed - no trade): %d · opened 3%%+ away already (late - no trade): %d" % (nogo, late))
    if recent:
        L.append("")
        L.append("this month's GO trades:")
        for r in sorted(recent, key=lambda r: r[9])[-15:]:
            L.append("   %s %-11s %s · day 0 price %+.1f%% OI %+.0f%% · %s → %s %+.1f%%" % (r[9], r[8], "▲ CE" if r[3] > 0 else "▼ PE", r[4], r[5], room_b(r[2]), r[0], r[1]))
    return L


def load():
    """-> F (the futures OI of every share-day), syms, get(s) (one share's candles, read when needed)"""
    import study3y as S
    syms = S.fo_list()
    F = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(S.H3, "fut.db"), uri=True)
        for d, s, foi, fch in c.execute("select d, sym, foi, fchg from fut"):
            F[(s, d)] = (foi, fch)
        c.close()
    except Exception as ex:
        print("fut.db: %s" % ex)

    def get(s):
        try:
            return S.daily(s), S.intraday(s)
        except Exception:
            return {}, {}
    return F, syms, get


if __name__ == "__main__":
    F, syms, get = load()
    L = run(None, F, None, syms, get)
    txt = "\n".join(L)
    print(txt)
    try:
        import study3y as S
        open(os.path.join(S.H3, "buildup_study.txt"), "w").write(txt + "\n")
    except Exception:
        pass
PY_S
cat > $D/p197test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p197test.py - PATCH 197: the build-up -> GO study on made-up days (no server data)"""
import os, sys, datetime as dt
import numpy as np
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import buildupstudy as T
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)

def days(n):
    d0, out = dt.date(2026, 9, 1), []
    while len(out) < n:
        if d0.weekday() < 5:
            out.append(str(d0))
        d0 += dt.timedelta(days=1)
    return out

def m5(path):
    """75 closes -> the (6, 75) array (o h l c v filled)"""
    x = np.zeros((6, 75), dtype=np.float32)
    prev = path[0]
    for i, c in enumerate(path):
        x[:, i] = (prev, max(prev, c) * 1.0005, min(prev, c) * 0.9995, c, 1000, 1); prev = c
    return x

K = days(30)
def share(day0_close, day0_hi, day0_lo, day1_path, prev=100.0):
    D, M = {}, {}
    for i, k in enumerate(K[:-2]):
        D[k] = (prev, prev * 1.01, prev * 0.99, prev, 1000)       # flat 20+ days around 100 (20-day high 101)
    D[K[-2]] = (prev, day0_hi, day0_lo, day0_close, 3000)
    p = day1_path
    D[K[-1]] = (p[0], max(p), min(p), p[-1], 3000)
    M[K[-1]] = m5(p)
    return D, M

DAY, M5, F = {}, {}, {}
# 1 COROMANDEL-like: day 0 +2% (101 -> 102), OI +13% -> day 1 opens 102.3, breaks 102.6 at 09:30, runs to 105 -> WIN
DAY["COROM"], M5["COROM"] = share(102.0, 102.5, 100.2, [102.3, 102.4, 102.5, 102.7] + [102.7 + 0.04 * i for i in range(71)])
F[("COROM", K[-2])] = (113.0, 13.0)
# 2 SHORT BUILD-UP that fails: day 0 -2%, OI +8% -> breaks the low, then rallies 1%+ -> LOSS
DAY["FAILPE"], M5["FAILPE"] = share(98.0, 99.8, 97.6, [97.9, 97.7, 97.5] + [97.5 + 0.03 * i for i in range(72)])
F[("FAILPE", K[-2])] = (108.0, 8.0)
# 3 LATE: a long build-up, but it opens +4% -> no trade
DAY["LATEX"], M5["LATEX"] = share(102.0, 102.4, 100.5, [106.1] * 75)
F[("LATEX", K[-2])] = (110.0, 10.0)
# 4 NO GO: a long build-up, it never closes above yesterday's high by 10:30
DAY["NOGO"], M5["NOGO"] = share(102.0, 103.0, 100.5, [102.1] * 75)
F[("NOGO", K[-2])] = (110.0, 10.0)
# 5 no build-up (OI +2%): not a signal
DAY["QUIET"], M5["QUIET"] = share(102.0, 102.5, 100.2, [102.3] * 75)
F[("QUIET", K[-2])] = (102.0, 2.0)
L = T.run(DAY, F, M5, list(DAY))
txt = "\n".join(L)
print(txt)
ce = [l for l in L if l.startswith("LONG BUILD-UP")][0]; pe = [l for l in L if l.startswith("SHORT BUILD-UP")][0]
check("COROMANDEL-like: 1 CE trade, a WIN (+2%)", "    1 trades · WIN 100%" in ce)
check("the failing short build-up: 1 PE trade, a LOSS", "    1 trades · WIN   0% · LOSS 100%" in pe)
check("the late gap and the never-confirmed one are counted, not traded", "no GO by 10:30 (it never confirmed - no trade): 1 · opened 3%+ away already (late - no trade): 1" in txt)
check("OI +2% is not a build-up (no extra signal)", ce.count("trades") == 1 and "    1 trades" in ce)
check("the room bucket: no wall above 105 in the last 20 days -> 'no wall (new high/low)'", any("no wall (new high/low)" in l and "    1 trades" in l for l in L))
check("this month's GO list names COROM", any("COROM" in l and "WIN" in l for l in L))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile buildupstudy.py || { echo "❌ does not compile"; exit 1; }
echo "=== the test (made-up days)"
timeout 60 python3 $D/p197test.py | grep -E "  ok|FAIL|PASSED"
echo
echo "=== THE 3-YEAR STUDY (a few minutes)"
nice -n 10 timeout 3600 python3 $D/buildupstudy.py > $D/data/buildup_study.txt 2>&1
cat $D/data/buildup_study.txt
echo
echo "✅ patch 197 study done - nothing was sent or changed."
