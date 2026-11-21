#!/usr/bin/env python3
"""loadtest.py - READ ONLY. "MONEY LOADING BEFORE THE MOVE" - tested on GIR's own minute futures history (Rama, 16 Nov: "the build-up alert comes after
the move - and 10-15 minutes is also too late"). data/oihist/<day>.npz: per share, a row a minute: minute since 09:15, price, futures OI, volume,
buyers waiting, sellers waiting.
  a LOADING signal at minute m, window w (3 / 5 / 10 min): futures OI up k% (0.5 / 1.0 / 1.5) in w minutes while the price moved under 0.3% -
  the side from the order book (buyers 1.3x sellers -> CE, sellers 1.3x buyers -> PE), first signal per share per day, 09:20-14:30
  then: did the price go 1.5%+ that way (before 0.75% against)? the money (1 lot, an at-the-money option ~ half the rupee move, stop 2.5%, half at
  +1.5%, out 15:10)? and for the day's big movers (2.5%+): how many minutes BEFORE their move started did the signal come?
python3 loadtest.py [YYYY-MM-DD ...]   (no day: every day kept)   -> prints, saves data/loadtest.txt"""
import os, sys, glob, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); OD = os.path.join(D, "data", "oihist")
L = []
def say(s=""):
    L.append(s); print(s)
hmf = lambda m: "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)


def lots():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        R = dict(c.execute("select sym, lot from fo_list").fetchall()); c.close(); return R
    except Exception:
        return {}


def load(day):
    import numpy as np
    z = np.load(os.path.join(OD, day + ".npz")); out = {}
    for s in z.files:
        a = z[s]
        if len(a) < 60:
            continue
        out[s] = {int(r[0]): (float(r[1]), float(r[2]), float(r[3]), float(r[4]), float(r[5])) for r in a}
    return out


def sim(seq, P0, dr, st=0.025):
    half = None; stop = -st
    for m, px in seq:
        x = (px / P0 - 1) * dr
        if x <= stop:
            return stop if half is None else (half + stop) / 2
        if half is None and x >= 0.015:
            half, stop = 0.015, 0.0
        if m >= 355:                                                           # 15:10
            return x if half is None else (half + x) / 2
    x = (seq[-1][1] / P0 - 1) * dr if seq else 0.0
    return x if half is None else (half + x) / 2


def signals(S, w, k):
    out = []
    for s, R in S.items():
        ms = sorted(R)
        for m in ms:
            if m < 5 or m > 315 or (m - w) not in R:
                continue
            px, oi, vol, b, sl = R[m]; px0, oi0 = R[m - w][0], R[m - w][1]
            if not oi0 or not px0 or not oi:
                continue
            doi = oi / oi0 - 1; dpx = px / px0 - 1
            if doi < k or abs(dpx) > 0.003:
                continue
            dr = 1 if b >= 1.3 * max(sl, 1) else -1 if sl >= 1.3 * max(b, 1) else 0
            if not dr:
                continue
            out.append({"s": s, "m": m, "dir": dr, "px": px, "doi": doi})
            break
    return out


def movers(S):
    out = {}
    for s, R in S.items():
        ms = sorted(R); o0 = R[ms[0]][0]
        if not o0:
            continue
        up = max(R[m][0] for m in ms) / o0 - 1; dn = 1 - min(R[m][0] for m in ms) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size >= 0.025:
            st = next((m for m in ms if (R[m][0] / o0 - 1) * dr >= 0.005), ms[0])
            out[s] = (dr, size, st)
    return out


def main():
    days = sys.argv[1:] or sorted(os.path.basename(f)[:10] for f in glob.glob(os.path.join(OD, "20??-??-??.npz")))
    LOT = lots()
    say("💰 MONEY LOADING BEFORE THE MOVE - tested on GIR's minute futures history · %d day(s): %s" % (len(days), ", ".join(days)))
    for day in days:
        try:
            S = load(day)
        except Exception as ex:
            say("  %s: not readable (%s)" % (day, ex)); continue
        S = {s: R for s, R in S.items() if not LOT or s in LOT}
        MV = movers(S)
        say(""); say("  %s · %d F&O shares · %d moved 2.5%%+" % (day, len(S), len(MV)))
        for w in (3, 5, 10):
            for k in (0.005, 0.01, 0.015):
                G = signals(S, w, k); tot = 0.0; hit = 0; lead = []
                for g in G:
                    R = S[g["s"]]; seq = [(m, R[m][0]) for m in sorted(R) if m > g["m"]]
                    p = sim(seq, g["px"], g["dir"]); tot += p * g["px"] * (LOT.get(g["s"]) or 0) * 0.5; hit += p > 0
                    mv = MV.get(g["s"])
                    if mv and mv[0] == g["dir"]:
                        lead.append(mv[2] - g["m"])
                before = sum(1 for x in lead if x >= 0)
                say("    %2d min · OI +%.1f%% · price flat → %3d signals · %3d won · ₹%9s · big movers caught: %d (%d BEFORE their move, median %s min)" % (
                    w, k * 100, len(G), hit, "{:,.0f}".format(tot), len(lead), before, sorted(lead)[len(lead) // 2] if lead else "—"))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "loadtest.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/loadtest.txt")


if __name__ == "__main__":
    main()
