#!/usr/bin/env python3
"""sectoropt.py - READ ONLY. THE SECTOR PICKS IN THE REAL OPTION (Rama, 16 Nov: "we have to find a real edge"). The two studies joined:
sectorstudy.py found three kinds of pick with a lean on the SHARE (59 days); the option replay found how to HOLD (do not book early, out after
about 2 hours if it is not working). Here those picks are traded in the real at-the-money option with Kite's minute prices, on every day whose
own monthly contract Kite still has:
  A  PE on the 3 DRIVERS of the WEAKEST sector, at 10:30 / 11:00 / 12:00
  B  CE / PE on an F&O share of the 1st-3rd best / worst sector that is PAST ITS 20-DAY HIGH / LOW, with 70%+ of the sector that way and on the
     right side of VWAP, at 10:00 / 10:30
  C  the DRIVER of a "ONE SHARE'S STORY" sector (one F&O share = 40%+ of the no.1 best / worst sector's move), at 09:45 / 10:00 / 10:30
  D  CE on a share that fell 2%+ yesterday WITH its theme (the theme -1%+), at 09:45 / 10:00 while the theme has NOT turned up yet   (themestudy.py)
  E  the same share at 09:45 whatever its theme is doing
A share is taken once a day per kind (its first signal). Three ways of holding, side by side:
  CARD   stop 2.5% on the share · half out at +1.5% · the rest at 15:10            (the BUY card's rule today)
  2-HOUR stop 2.5% · half out at +3.5% · out after 120 minutes if the half-out is not reached · the rest at 15:10   (the option replay's best)
  2H FLAT stop 2.5% · simply out after 120 minutes
₹ = the option's own premium x the lot, 1 lot, before charges. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 sectoropt.py   -> prints, saves data/sectoropt.txt"""
import os, sys, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import seclive as SL
import sectorstudy as SS
import optreal as OR
L = []
f0 = lambda x: "{:,.0f}".format(x)
RULES = (("CARD", 0.025, 0.015, None), ("2-HOUR", 0.025, 0.035, 120), ("2H FLAT", 0.025, 9.0, 120))


def say(s=""):
    L.append(s); print(s, flush=True)


def picks_of_day(P, SEC, W, FO, days, di):
    """the day's picks: [(kind, minute, sym, dir, note)] - the same definitions as sectorstudy.py"""
    d, dp = days[di], days[di - 1]; out = []; seen = set()
    S = {}
    for s, sec in SEC.items():
        b, bp = P.get(s, {}).get(d), P.get(s, {}).get(dp)
        if b is None or bp is None or len(b) < 30 or not W.get(s):
            continue
        S[s] = (sec, float(bp[-1, 4]), b)
    px = lambda b, T: (float(b[b[:, 0] <= T - 5][-1, 4]) if (b[:, 0] <= T - 5).any() else None)

    def level20(s):
        w = []
        for x in days[max(0, di - 20):di]:
            bb = P.get(s, {}).get(x)
            if bb is not None:
                w.append((float(bb[:, 2].max()), float(bb[:, 3].min())))
        return (max(a for a, _ in w), min(b_ for _, b_ in w)) if len(w) >= 10 else None

    for T in (30, 45, 75, 105, 165):
        G = {}
        for s, (sec, pc, b) in S.items():
            p = px(b, T)
            if p:
                G.setdefault(sec, []).append((s, p / pc - 1, W[s], p, b))
        sc = {}
        for sec, R in G.items():
            if len(R) >= 5:
                w = sum(r[2] for r in R)
                sc[sec] = (sum(r[1] * r[2] for r in R) / w, sum(1 for r in R if r[1] > 0) / len(R), sum(1 for r in R if r[1] < 0) / len(R), w)
        if len(sc) < 8:
            continue
        at = sorted(sc, key=lambda k: -sc[k][0])

        def add(kind, s, dr, note):
            if (kind, s) not in seen:
                seen.add((kind, s)); out.append((kind, T, s, dr, note))

        if T in (75, 105, 165):                                               # A
            sec = at[-1]; mv = sc[sec][0]
            if mv < 0:
                for r in sorted([r for r in G[sec] if r[0] in FO and r[1] < 0], key=lambda r: r[1] * r[2])[:3]:
                    add("A", r[0], -1, "%s %+.1f%%" % (sec, mv * 100))
        if T in (45, 75):                                                     # B
            for rk in (1, 2, 3):
                for sec, dr in ((at[rk - 1], 1), (at[-rk], -1)):
                    mv = sc[sec][0]; br = sc[sec][1] if dr > 0 else sc[sec][2]
                    if mv * dr <= 0 or br < 0.7:
                        continue
                    for s, c, wt, p, b in G[sec]:
                        if s not in FO:
                            continue
                        pre = b[b[:, 0] <= T - 5]; vw = float((pre[:, 4] * pre[:, 5]).sum() / max(pre[:, 5].sum(), 1.0)); lv = level20(s)
                        if lv and ((p > lv[0]) if dr > 0 else (p < lv[1])) and (p - vw) * dr > 0:
                            add("B", s, dr, "%s %+.1f%% · past its 20-day level" % (sec, mv * 100))
        if T in (30, 45, 75):                                                 # C
            for sec, dr in ((at[0], 1), (at[-1], -1)):
                mv = sc[sec][0]
                if mv * dr <= 0:
                    continue
                r = max(G[sec], key=lambda r: r[1] * r[2] * dr); part = r[1] * r[2] / sc[sec][3] / mv
                if part >= 0.4 and r[0] in FO:
                    add("C", r[0], dr, "%s %+.1f%% · %d%% of its move" % (sec, mv * 100, round(part * 100)))
    return out


def picks_bounce(P, FO, days, di):
    """D: a share that fell 2%+ yesterday WITH its theme (the theme -1%+, the share not far worse) - CE this morning at 09:45 / 10:00 while the theme
    has NOT turned up yet (themestudy.py: 63% up 2 hours later, +0.36%). D2: the same share whatever the theme does. [(kind, minute, sym, +1, note)]"""
    import themestudy as TH
    if di < 2:
        return []
    d, dp, dpp = days[di], days[di - 1], days[di - 2]; out = []; seen = set()
    px = lambda b, T: (float(b[b[:, 0] <= T - 5][-1, 4]) if (b[:, 0] <= T - 5).any() else None)
    for t, (fo, also, why) in TH.THEMES.items():
        R = {}
        for s in (fo + " " + also).split():
            b, bp, b2 = P.get(s, {}).get(d), P.get(s, {}).get(dp), P.get(s, {}).get(dpp)
            if b is not None and bp is not None and b2 is not None and len(b) >= 30:
                R[s] = (float(bp[-1, 4]), b, float(bp[-1, 4]) / float(b2[-1, 4]) - 1)
        if len(R) < 2:
            continue
        yth = sum(v[2] for v in R.values()) / len(R)
        if yth > -0.01:
            continue
        for T in (30, 45):
            c = {s: (px(b, T) / pc - 1) for s, (pc, b, y) in R.items() if px(b, T)}
            if len(c) < 2:
                continue
            turned = sum(c.values()) / len(c) >= 0.003 and sum(1 for v in c.values() if v > 0) / len(c) >= 0.6
            for s in fo.split():
                if s in c and s in FO and R[s][2] <= -0.02 and R[s][2] >= 2.0 * yth - 0.01:
                    note = "%s fell %.1f%% yesterday, the share %.1f%%" % (t, yth * 100, R[s][2] * 100)
                    if ("E", s) not in seen and T == 30:
                        seen.add(("E", s)); out.append(("E", T, s, 1, note))
                    if not turned and ("D", s) not in seen:
                        seen.add(("D", s)); out.append(("D", T, s, 1, note + " · the theme not turned yet"))
    return out


def main():
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    kite = SL.get_kite()
    say("📊 THE SECTOR PICKS IN THE REAL OPTION (Kite minute prices)")
    import themestudy as TH
    RAW = SS.fetch_all(kite, list(set(SEC) | {s for fo, also, _ in TH.THEMES.values() for s in (fo + " " + also).split()}), 60)
    P = {s: SS.by_day(a) for s, a in RAW.items()}
    days = sorted(P.get("NIFTY50", {}))
    if not W:
        for s in SEC:
            v = [float((b[:, 4] * b[:, 5]).sum()) for b in P.get(s, {}).values()]
            if v:
                W[s] = sum(v) / len(v)
        wsrc = "each share's average traded value"
    K = OR.Kite(str(dt.date.fromordinal(days[0])))
    exps = {r[0] for R_ in K.opt.values() for r in R_}
    T = {k: [] for k in "ABCDE"}; used = []
    for di in range(21, len(days)):
        day = dt.date.fromordinal(days[di]); K.day = day
        if not any(abs((e - OR.near_expiry(day)).days) <= 4 and e >= day for e in exps):
            continue                                                         # that day's own month contract has expired - Kite has none
        used.append(str(day)); n0 = sum(len(v) for v in T.values())
        for kind, Tm, s, dr, note in picks_of_day(P, SEC, W, FO, days, di) + picks_bounce(P, FO, days, di):
            if s not in K.eq:
                continue
            Sm = K.candles(K.eq[s]); m0 = next((m for m in sorted(Sm) if m >= Tm), None)
            if m0 is None or m0 > Tm + 5:
                continue
            P0 = Sm[m0][3]; c = K.contract(s, dr, P0)
            if not c:
                continue
            O = K.candles(c[1]); p0 = OR.at(O, m0)
            if not p0:
                continue
            x = {"S": sorted((k,) + v for k, v in Sm.items()), "O": OR.ff(O), "m0": m0, "P0": P0, "dir": dr, "lot": c[2], "p0": p0,
                 "s": s, "day": str(day), "t": SS.hm(Tm), "ts": c[0], "note": note, "r": {}}
            for nm, st, hf, tm in RULES:
                r = OR.money(x, st, hf, tm)
                if r:
                    x["r"][nm] = r
            if len(x["r"]) == len(RULES):
                T[kind].append(x)
        say("  %s · %d picks" % (day, sum(len(v) for v in T.values()) - n0))
    say("")
    say("  %d days with Kite option prices: %s … %s · weights: %s" % (len(used), used[0] if used else "-", used[-1] if used else "-", wsrc))
    say("  1 lot each, before charges · CARD = stop 2.5%, half +1.5%, rest 15:10 · 2-HOUR = half +3.5%, out after 120 min if not reached · 2H FLAT = out after 120 min")
    say("")
    NAME = {"A": "A · PE on the weakest sector's drivers (10:30-12:00)", "B": "B · past the 20-day level + 70% of the sector + VWAP (10:00-10:30)", "C": "C · the driver of a one-share sector (09:45-10:30)",
            "D": "D · CE on a share dragged down 2%+ with its theme yesterday, the theme NOT turned yet (09:45-10:00)", "E": "E · the same share at 09:45, whatever its theme is doing"}
    for kind in "ABCDE":
        X = T[kind]
        say("  %s · %d trades" % (NAME[kind], len(X)))
        for nm, *_ in RULES:
            if not X:
                continue
            v = [x["r"][nm][0] for x in X]; gd = {}
            for x in X:
                gd[x["day"]] = gd.get(x["day"], 0) + x["r"][nm][0]
            say("      %s %-8s %3d won of %3d (%2.0f%%) · ₹%10s · ₹%s a trade · %d of %d days green" % ("✅" if sum(v) > 0 else "❌", nm, sum(1 for a in v if a > 0), len(v),
                100 * sum(1 for a in v if a > 0) / len(v), f0(sum(v)), f0(sum(v) / len(v)), sum(1 for a in gd.values() if a > 0), len(gd)))
        for side, lab in ((1, "CE"), (-1, "PE")):
            Y = [x for x in X if x["dir"] == side]
            if Y and kind in "BC":
                v = [x["r"]["2-HOUR"][0] for x in Y]
                say("        of them %s: %3d trades · %2.0f%% won · ₹%s with the 2-HOUR rule" % (lab, len(Y), 100 * sum(1 for a in v if a > 0) / len(v), f0(sum(v))))
        say("")
    say("  every trade (the 2-HOUR rule), biggest ₹ first:")
    allx = sorted([(k, x) for k in "ABCDE" for x in T[k]], key=lambda kx: -kx[1]["r"]["2-HOUR"][0])
    for k, x in allx[:25] + ([("…", None)] if len(allx) > 45 else []) + allx[25:][-20:]:
        if x is None:
            say("      …"); continue
        r = x["r"]["2-HOUR"]
        say("    %s %s %s %-11s %-22s ₹%-8s → ₹%-8s (%+4.0f%%) · %-12s %s · ₹%s · %s" % (k, x["day"][5:], x["t"], x["s"], x["ts"], "{:,.2f}".format(x["p0"]), "{:,.2f}".format(r[3]),
            (r[3] / x["p0"] - 1) * 100, r[1], OR.C.hm(r[2]), f0(r[0]), x["note"]))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "sectoropt.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/sectoropt.txt")


if __name__ == "__main__":
    main()
