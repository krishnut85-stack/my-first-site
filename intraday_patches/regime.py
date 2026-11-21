#!/usr/bin/env python3
"""regime.py - READ ONLY. CAN THE MORNING TELL THE DAY? (Rama, 14 Nov: "based on the market condition we have to find the shares").
fastreplay.py showed: rising days -> the CE breakouts win, falling / choppy days -> the PE breakdowns win, flat days -> nothing. But a day's kind is
known only at its close. This takes NIFTY 50 at 09:30 and 09:45 (vs the day before's close and vs its 09:15 open) and the 5 days before, sorts
every trade of the finished run by what the MORNING said, and shows each setup's result after costs.   python3 regime.py /root/strat2"""
import os, sys, glob, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
D = sys.argv[1] if len(sys.argv) > 1 else "/root/strat2"
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
COST = 0.20
P = []
for f in sorted(glob.glob(D + "/2026-*.txt")):
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("PROFILE|"):
            x = ln.rstrip("\n").split("|")
            if len(x) >= 8:
                P.append({"day": x[1], "reg": x[2], "set": x[5], "side": x[6], "r": float(x[7])})
days = sorted({e["day"] for e in P})
if not days:
    print("no PROFILE lines in %s" % D); sys.exit(0)
import core, time
k = core.get_kite()
def hd(*a):
    """Zerodha allows ~3 data requests a second: wait and retry on 'Too many requests' (another download may be running)"""
    for n in range(8):
        try:
            r = k.historical_data(*a); time.sleep(0.4); return r
        except Exception as ex:
            if "too many" in str(ex).lower() or "rate" in str(ex).lower():
                time.sleep(2 + n); continue
            raise
    return []
d0 = dt.date.fromisoformat(days[0]) - dt.timedelta(days=12)
dc = {r["date"].date(): float(r["close"]) for r in hd(256265, d0, dt.date.fromisoformat(days[-1]), "day")}
dl = sorted(dc)
M = {}
for d in days:
    dd = dt.date.fromisoformat(d)
    R = [r for r in hd(256265, dt.datetime(dd.year, dd.month, dd.day, 9, 15), dt.datetime(dd.year, dd.month, dd.day, 10, 0), "minute")
         if r["date"].astimezone(IST).date() == dd]
    prev = [x for x in dl if x < dd]
    if not R or not prev:
        continue
    pc = dc[prev[-1]]; o = float(R[0]["open"])
    def at(hm):
        L = [r for r in R if r["date"].astimezone(IST).strftime("%H:%M") <= hm]
        return float(L[-1]["close"]) if L else None
    c930, c945 = at("09:29"), at("09:44")
    p5 = dc[prev[-5]] if len(prev) >= 5 else None
    def kind(c):
        if c is None:
            return "?"
        ch = (c / pc - 1) * 100
        return "UP" if (ch >= 0.25 and c > o) else "DOWN" if (ch <= -0.25 and c < o) else "MIXED"
    M[d] = {"930": kind(c930), "945": kind(c945), "gap": (o / pc - 1) * 100, "5d": None if not p5 else ("UP" if (pc / p5 - 1) * 100 >= 1 else "DOWN" if (pc / p5 - 1) * 100 <= -1 else "SIDEWAYS"),
            "ch930": (c930 / pc - 1) * 100 if c930 else None}
print("=== WHAT THE MORNING SAID, day by day (NIFTY at 09:30 vs the day before's close and its open) · and how the day ended")
for d in days:
    m = M.get(d)
    if m:
        reg = next((e["reg"] for e in P if e["day"] == d), "?")
        print("  %s  09:30 %-5s (%+.2f%%) · 09:45 %-5s · gap %+.2f%% · last 5 days %-8s · the day ended: %s" % (d, m["930"], m["ch930"] or 0, m["945"], m["gap"], m["5d"] or "-", reg))
right = sum(1 for d in days if d in M and ((M[d]["930"] == "UP" and next(e["reg"] for e in P if e["day"] == d) == "rising") or
                                           (M[d]["930"] == "DOWN" and next(e["reg"] for e in P if e["day"] == d) in ("falling", "choppy"))))
called = sum(1 for d in days if d in M and M[d]["930"] in ("UP", "DOWN"))
print("  09:30 called a side on %d of %d days · it matched how the day ended on %d of those" % (called, len(M), right))
def tab(key, kinds, title):
    print("\n=== EVERY SETUP by %s - avg %% on the share a trade AFTER costs (%.2f%%) · trades · won" % (title, COST))
    print("  %-34s %s" % ("setup", "".join("%-24s" % x for x in kinds)))
    for st in sorted({e["set"] for e in P}):
        for side in ("CE", "PE"):
            cells = []
            for kd in kinds:
                L = [e for e in P if e["set"] == st and e["side"] == side and M.get(e["day"], {}).get(key) == kd]
                cells.append(("%+.2f%% · %d · W%.0f%%" % (sum(e["r"] - COST for e in L) / len(L), len(L), 100 * sum(1 for e in L if e["r"] - COST > 0) / len(L))) if len(L) >= 10 else "-")
            print("  %-34s %s" % ((st + " " + side)[:34], "".join("%-24s" % c for c in cells)))
tab("930", ["UP", "DOWN", "MIXED"], "NIFTY AT 09:30")
tab("945", ["UP", "DOWN", "MIXED"], "NIFTY AT 09:45")
tab("5d", ["UP", "DOWN", "SIDEWAYS"], "NIFTY'S LAST 5 DAYS")
print("\nREAD: if CE setups are + in the UP column and PE setups + in the DOWN column, the rule works live: look at NIFTY at 09:30, trade only that side.")
