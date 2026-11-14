#!/bin/bash
# PATCH 202 - EVERY OI SITUATION WITH ROOM, a STUDY (reads only, sends nothing): futures build-up, the roof / floor moving (resistance /
#   support shifting), a wall breaking, bull / bear shift, COROMANDEL-like combinations - on NSE's daily F&O file since Jan 2025 (every
#   strike), each with the ROOM to the next HOLDING wall at the close, and the next morning traded the Rama way (+1.5% before -0.8%).
set -u
D=/home/globalbot/intraday
[ -f $D/oistudy.py ] && [ -f $D/data/oistudy.db ] || { echo "GIR's oistudy.db is not on this server - tell Claude"; exit 1; }
cat > $D/oiroom.py <<'PY_O'
#!/usr/bin/env python3
"""oiroom.py - patch 202: EVERY OI SITUATION, WITH ROOM, the way Rama trades (Rama, 11 Nov: "there are a lot of situations in OI - the
futures build-up, the resistance changing: money leaving the first resistance and going to the second, the first support leaving and a
new resistance coming up, like COROMANDEL - these are also important"). A STUDY: reads only, sends nothing.
  the data   GIR's oistudy.db: NSE's daily F&O file since Jan 2025 - every share-day's futures (price, OI and its change) and every
             strike within 10% (call / put OI and their change) - and the 5-min candles of the next day (data/h3)
  the situations at the close (GIR's own detection, oistudy.fires): LONG / SHORT BUILD-UP, SHORT COVERING, LONG UNWINDING, 3-day streaks,
             THE ROOF MOVED UP / DOWN (resistance shifting), THE FLOOR MOVED UP / DOWN (support shifting), CLOSED ABOVE YESTERDAY'S ROOF /
             BELOW ITS FLOOR (a wall broke), FLOOR BUILDING + ROOF LEAVING (bull shift) and the mirror, calls / puts bought, writers running,
             20-day high with fresh longs ... and combinations: COROMANDEL-like = the roof AND the floor moved up with a long build-up
  the room   at that close: the next BIG wall its way (60%+ of the biggest OI within 8%) that is HOLDING (its OI did not fall that day) -
             a wall whose writers ran is no wall
  the trade  the next morning, the Rama way: in at 09:20 when the first 5-min candle went its way (not after a 3%+ gap its way - late),
             +1.5% on the share (an ATM option +50-80%) before -0.8% against, by 15:15
  compared   with the same morning trade on every share-day (no situation) - so each situation's own value shows - and room 3%+ vs not
  python3 oiroom.py      -> prints, data/oiroom_study.txt"""
import os, sys, json, statistics
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
TGT, STP, LATE, ROOM, BIG, BAND = 1.5, 0.8, 3.0, 3.0, 0.6, 8.0


def room_of(r, side):
    """the room % at the close to the next holding wall its way, None = no holding wall within 8% (open room)"""
    try:
        st = json.loads(r.get("strikes") or "{}")
    except Exception:
        return None
    px = r.get("spot")
    if not st or not px:
        return None
    oi_i, d_i = (0, 1) if side > 0 else (2, 3)
    xs = []
    for k, v in st.items():
        k = float(k)
        if (k > px if side > 0 else k < px) and abs(k / px - 1) * 100 <= BAND and v[oi_i]:
            xs.append((k, v[oi_i], v[d_i] or 0))
    if not xs:
        return None
    mx = max(o for k, o, d in xs)
    for k, o, d in sorted([x for x in xs if x[1] >= BIG * mx], key=lambda x: abs(x[0] - px)):
        if d < 0:
            continue                                           # its writers ran today - not a wall
        return abs(k / px - 1) * 100
    return None


def trade(x, pc, side):
    """the next day's 5-min candles x (6, 75) -> (WIN / LOSS / OPEN, move %) or a reason it was no trade"""
    if x is None or not x[5][:2].all():
        return None
    o, c0 = float(x[0][0]), float(x[3][0])
    if not o or not pc:
        return None
    if (o / pc - 1) * 100 * side >= LATE:
        return ("LATE", 0.0)
    if (c0 - o) * side <= 0:
        return ("NO GO", 0.0)
    px = c0
    stop, tgt = px * (1 - STP / 100 * side), px * (1 + TGT / 100 * side)
    for i in range(1, 73):
        h, l = float(x[1][i]), float(x[2][i])
        if (l <= stop) if side > 0 else (h >= stop):
            return ("LOSS", -STP)
        if (h >= tgt) if side > 0 else (l <= tgt):
            return ("WIN", TGT)
    return ("OPEN", (float(x[3][72]) / px - 1) * 100 * side)


def tally(L):
    n = len(L)
    if not n:
        return "    0"
    w = sum(1 for r in L if r[0] == "WIN"); l = sum(1 for r in L if r[0] == "LOSS")
    return "%5d · WIN %3d%% · LOSS %3d%% · per trade %+.2f%%" % (n, round(100 * w / n), round(100 * l / n), sum(r[1] for r in L) / n)


def room_b(rm):
    return "no holding wall" if rm is None else "room 3%+" if rm >= 3 else "room 1.5-3%" if rm >= 1.5 else "room <1.5%"


COMBOS = [("COROMANDEL-like: roof AND floor moved up + long build-up", "CE", ("d_roof_up", "d_floor_up", "d_long_buildup")),
          ("the mirror: roof AND floor moved down + short build-up", "PE", ("d_roof_down", "d_floor_down", "d_short_buildup")),
          ("roof moved up + long build-up", "CE", ("d_roof_up", "d_long_buildup")),
          ("floor moved down + short build-up", "PE", ("d_floor_down", "d_short_buildup")),
          ("bull shift (floor building, roof leaving) + long build-up", "CE", ("d_bull_shift", "d_long_buildup")),
          ("bear shift + short build-up", "PE", ("d_bear_shift", "d_short_buildup")),
          ("closed above yesterday's roof + long build-up", "CE", ("d_roof_broken", "d_long_buildup")),
          ("closed below yesterday's floor + short build-up", "PE", ("d_floor_broken", "d_short_buildup"))]


def run(by, m5_of, SC):
    res, base = {}, []
    for sym, rs in by.items():
        M = m5_of(sym)
        if not M:
            continue
        for i in range(3, len(rs) - 1):
            r, n1 = rs[i], rs[i + 1]
            x = M.get(n1["d"])
            if x is None or not r.get("spot"):
                continue
            ids = set(oistudy_fires(rs, i))
            if i % 4 == 0:                                       # the base: the same morning trade on every 4th share-day, both sides
                for side in (1, -1):
                    t = trade(x, r["spot"], side)
                    if t and t[0] not in ("LATE", "NO GO"):
                        base.append(t)
            tags = [(id_, 1 if SC[id_]["side"] == "CE" else -1) for id_ in ids if SC.get(id_, {}).get("side") in ("CE", "PE")]
            tags += [(nm, 1 if sd == "CE" else -1) for nm, sd, need in COMBOS if all(n in ids for n in need)]
            for name, side in tags:
                t = trade(x, r["spot"], side)
                if not t or t[0] in ("LATE", "NO GO"):
                    continue
                res.setdefault(name, []).append((t[0], t[1], room_of(r, side), r["d"][:4]))
    return res, base


def report(res, base, SC):
    L = ["EVERY OI SITUATION AT THE CLOSE -> the next morning, the Rama way (in 09:20 when the first 5 min go its way; +1.5% before -0.8%)",
         "BASE (no situation, every share-day, both sides): " + tally(base), ""]
    rows = []
    for name, R in res.items():
        if len(R) < 30:
            continue
        good = [r for r in R if r[2] is None or r[2] >= ROOM]
        rows.append((name, R, good))
    rows.sort(key=lambda x: -(sum(r[1] for r in x[2]) / len(x[2]) if x[2] else -9))
    for name, R, good in rows:
        label = SC[name]["name"] + (" ▲ CE" if SC[name]["side"] == "CE" else " ▼ PE") if name in SC else name
        L.append(label)
        L.append("   all:                 " + tally(R))
        for b in ("room 3%+", "no holding wall", "room 1.5-3%", "room <1.5%"):
            L.append("   %-20s " % b + tally([r for r in R if room_b(r[2]) == b]))
        for y in sorted({r[3] for r in good}):
            L.append("   room 3%%+ / none, %s " % y + tally([r for r in good if r[3] == y]))
        L.append("")
    return L


def oistudy_fires(rs, i):
    import oistudy
    return oistudy.fires(rs, i)


if __name__ == "__main__":
    import oistudy, study3y as S
    by = oistudy.load()
    res, base = run(by, lambda s: S.intraday(s), oistudy.SC)
    L = report(res, base, oistudy.SC)
    txt = "\n".join(L)
    print(txt)
    open(os.path.join(BASE, "data", "oiroom_study.txt"), "w").write(txt + "\n")
PY_O
cat > $D/p202test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p202test.py - PATCH 202: every OI situation with room, on a made-up COROMANDEL-like share (no server data)"""
import os, sys, json
import numpy as np
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import oistudy, oiroom as R
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
def row(d, spot, foi, fdoi, roof_k, roof_oi, floor_k, floor_oi, strikes):
    r = {c: None for c in oistudy.COLS}
    r.update({"d": d, "sym": "COROX", "spot": spot, "fc": spot, "fo": spot, "foi": foi, "fdoi": fdoi, "fvol": 1000, "exp": "2026-11-25", "oexp": "2026-11-25",
              "roof_k": roof_k, "roof_oi": roof_oi, "floor_k": floor_k, "floor_oi": floor_oi, "ce_oi": 1e6, "pe_oi": 8e5, "strikes": json.dumps(strikes), "boxes": "{}"})
    return r
S0 = {"95": [1e5, 0, 6e5, 0], "100": [9e5, 0, 2e5, 0], "105": [5e5, 0, 1e5, 0], "110": [4e5, 0, 0, 0]}
rs = [row("2026-11-0%d" % (i + 2), 100.0, 1e6, 0, 100.0, 9e5, 95.0, 6e5, S0) for i in range(4)]
# the signal day: +2%, futures OI +5% (LB), the roof moved 100 -> 105 (its OI 9.5 L >= 0.8 x the old), the floor 95 -> 98,
# 105's writers ran later in the day? no - 105 holds; the next big holding wall 110 (7.8% away); 100's calls fell (below the price now)
S1 = {"95": [1e5, 0, 4e5, -2e5], "98": [5e4, 0, 7e5, 6e5], "100": [6e5, -3e5, 3e5, 1e5], "105": [9.5e5, 4.5e5, 1e5, 0], "110": [1e6, 6e5, 0, 0]}
S1["105"][1] = -5e4                                         # the 105 call writers trimmed: a shrinking wall - not a wall
rs.append(row("2026-11-06", 102.0, 1.05e6, 5e4, 105.0, 9.5e5, 98.0, 7e5, S1))
rs.append(row("2026-11-09", 104.0, 1.05e6, 0, 105.0, 9.5e5, 98.0, 7e5, S1))
ids = oistudy.fires(rs, 4)
check("GIR's own detection fires the roof up, the floor up, the long build-up (%s)" % sorted(ids), {"d_roof_up", "d_floor_up", "d_long_buildup"} <= set(ids))
check("the room: the shrinking 105 wall skipped, the holding 110 wall 7.8%% away (%.1f)" % (R.room_of(rs[4], 1) or -1), abs((R.room_of(rs[4], 1) or 0) - 7.84) < 0.1)
x = np.zeros((6, 75), dtype=np.float32); p0 = 102.2
path = [102.5] + [102.5 + 0.04 * i for i in range(74)]
for i, c in enumerate(path):
    x[:, i] = (p0, max(p0, c) * 1.0002, min(p0, c) * 0.9998, c, 1, 1); p0 = c
res, base = R.run({"COROX": rs}, lambda s: {"2026-11-09": x}, oistudy.SC)
co = res.get(R.COMBOS[0][0]) or []
check("COROMANDEL-like combo: one trade next morning, a WIN, room 3%%+ (%s)" % co, len(co) == 1 and co[0][0] == "WIN" and co[0][2] >= 3)
check("the long build-up alone is counted too", len(res.get("d_long_buildup") or []) == 1)
y = x.copy(); y[0][0] = 105.5                                # a 3.4% gap up: late
res2, _ = R.run({"COROX": rs}, lambda s: {"2026-11-09": y}, oistudy.SC)
check("a 3%+ gap its way: late, no trade", not res2.get(R.COMBOS[0][0]))
L = R.report({k: v * 30 for k, v in res.items()}, base * 30, oistudy.SC)
print("\n".join(L[:8]))
check("the report: each situation, room 3%+ vs not", any("room 3%+" in l for l in L) and any("COROMANDEL-like" in l for l in L))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile oiroom.py || { echo "❌ does not compile"; exit 1; }
echo "=== the test (a made-up COROMANDEL-like share)"
timeout 60 python3 $D/p202test.py | grep -E "  ok|FAIL|PASSED"
echo "=== the data"
cd $D && python3 oistudy.py --status 2>&1 | tail -3
echo "=== THE STUDY (several minutes)"
nice -n 10 timeout 3600 python3 $D/oiroom.py > /dev/null 2>&1
cat $D/data/oiroom_study.txt
echo
echo "✅ patch 202 study done - nothing was sent or changed."
