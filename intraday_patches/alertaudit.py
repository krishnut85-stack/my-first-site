#!/usr/bin/env python3
"""alertaudit.py - READ ONLY. WHICH OF GIR'S ALERTS ARE WORTH ANYTHING? (Rama, 17 Nov: "a complete overhaul of the alarm management, the sector
calculation, the sector rotation and the stocks" - GIR has 10+ alert makers (EARLY, heads-up, candidates, MOVE CARD, RUNNING, SPEED, FIRST MOVE,
MOVER, SUDDEN, OI scenarios, sector alerts ...) that overlap and disagree; LAURUSLABS got ~25 alerts in 4 hours).
Phase 1 of the overhaul: before anything is cut, every alert GIR logged (tomorrow.db, table alerts) on every day that also has Kite 5-minute
prices on this server (data/secstudy) is scored the same way:
  · its TYPE - from the alert's own words (RUNNING, SPEED, FIRST MOVE, SUDDEN, MOVER, HEADS-UP / BUY CE, PROFIT BOOKING, NEWS ...)
  · its SIDE - CE (up) / PE (down), as the alert said it
  · what the share did from the alert to 15:10, its way: the average move, how often it went its way, and how often it went +1.5% its
    way before -1% against ("worked" - the card rule's half-out and stop on the share)
  · the YARDSTICK: any F&O share already moving that way at the same times of day - an alert type is worth something only if it beats that
  · per share per day: how many alerts one share got (the noise)
✔ = beats the yardstick by 0.10%+ to 15:10 in BOTH halves of the days, with 100+ cases. ✘ = not steady. Nothing is changed, no Kite call.
  cd /home/globalbot/intraday && nice -n 15 python3 alertaudit.py      -> prints, saves data/alertaudit.txt"""
import os, re, sys, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
TYPES = ["HEADS-UP", "BUY CE", "BUY PE", "TRADE ALERT", "ENTER NOW", "OPENING CALL", "MOVE CARD", "TRADE CARD", "NEWS SHOCK", "SECTOR JUMP", "SECTOR",
         "FIRST MOVE", "RUNNING", "SPEED", "MOVER", "SUDDEN", "PROFIT BOOKING", "SHOCK WATCH", "YOUR VIEW", "OPENING", "WHY", "NEWS", "RESULTS",
         "OI", "BREAK", "STRONG3", "BOUNCE", "WEAK", "GAPDAY", "BOOK HALF", "EXIT", "HOLD", "STILL GOING", "CRITICAL"]


def say(s=""):
    L.append(s); print(s, flush=True)


def kind_of(text):
    first = (text or "").split("\n")[0].upper()
    for t in TYPES:
        if re.search(r"(?<![A-Z])%s(?![A-Z])" % re.escape(t), first):
            return t
    m = re.search(r"[A-Z][A-Z &'-]{3,24}", first)
    return (m.group(0).strip() if m else "OTHER")[:24]


def db_path(name):
    for p in (os.path.join(D, name), os.path.join(D, "data", name)):
        if os.path.exists(p):
            return p
    return None


def load_prices(syms):
    """sym -> {day ordinal: (yesterday's close, array of 5-minute rows [minute offset, high, low, close])}"""
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    out = {}
    for s in syms:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b:
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 7 or not len(A):
            continue
        prev = None; d_ = {}
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            day = int(p[0, 0])
            if prev is not None:
                d_[day] = (prev, p[:, [1, 3, 4, 5]])
            prev = float(p[-1, 5])
        out[s] = d_
    return out


def outcome(rows, off, dr):
    """from the 5-minute bar before the alert to 15:10: (move its way, worked +1.5% before -1%, the move its way in the 30 minutes BEFORE)"""
    a = rows[rows[:, 0] <= off - 5]; b = rows[(rows[:, 0] > off - 5) & (rows[:, 0] <= 350)]
    if not len(a) or len(b) < 2:
        return None
    px = float(a[-1, 3])
    if px <= 0:
        return None
    w30 = a[a[:, 0] >= off - 35]                                      # the last 30 minutes before the alert
    pre = ((px / float(w30[:, 2].min()) - 1) if dr > 0 else (1 - px / float(w30[:, 1].max()))) if len(w30) else 0.0
    fav = (b[:, 1] / px - 1) * dr if dr > 0 else (b[:, 2] / px - 1) * dr
    adv = (b[:, 2] / px - 1) * dr if dr > 0 else (b[:, 1] / px - 1) * dr
    f = np.flatnonzero(fav >= 0.015); s_ = np.flatnonzero(adv <= -0.01)
    worked = 1 if len(f) and (not len(s_) or f[0] < s_[0]) else 0
    return (float(b[-1, 3]) / px - 1) * dr, worked, pre


def main():
    p = db_path("tomorrow.db")
    if not p:
        say("❌ tomorrow.db (GIR's alert log) not found"); return
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=30)
    A = [r for r in c.execute("select day, t, kind, sym, side, text from alerts where sym is not null and sym != 'MARKET'")]
    c.close()
    say("📊 WHICH OF GIR'S ALERTS ARE WORTH ANYTHING? · every alert in GIR's log, scored on the 5-minute prices · from the alert to 15:10")
    if not A:
        say("  ❌ the alert log is empty"); return
    try:
        import seclive as SL
        FO = SL.fo_set()
    except Exception:
        FO = set()
    P = load_prices({r[3] for r in A})
    days_log = sorted({r[0] for r in A})
    say("  the alert log: %d alerts on %d days (%s to %s) · 5-minute prices for %d of its shares" % (len(A), len(days_log), days_log[0], days_log[-1], len(P)))
    R = []; per = {}; nos = 0
    for day, t, k, s, side, text in A:
        try:
            dd = dt.date.fromisoformat(day).toordinal(); hh, mm = int(t[:2]), int(t[3:5])
        except Exception:
            continue
        if not ("09:20" <= t[:5] <= "15:00"):
            continue
        per[(day, s)] = per.get((day, s), 0) + 1
        dr = 1 if side == "CE" else -1 if side == "PE" else 0
        if not dr:
            first = (text or "").split("\n")[0]
            dr = 1 if "▲" in first and "▼" not in first else -1 if "▼" in first and "▲" not in first else 0
        if not dr or s not in P or dd not in P[s]:
            nos += 1; continue
        o = outcome(P[s][dd][1], hh * 60 + mm - 555, dr)
        if o:
            R.append({"d": dd, "k": kind_of(text), "t": t[:5], "mv": o[0], "w": o[1], "s": s, "b": (hh * 60 + mm - 555) // 30, "dr": dr, "pre": o[2]})
    if len(R) < 50:
        say("  ❌ only %d alerts could be scored (the rest: no side, or no 5-minute prices for that day) - too few" % len(R)); return
    D_ = sorted({r["d"] for r in R}); mid = D_[len(D_) // 2]
    # the yardstick: any F&O share already moving that way (0.5%+ on the day) at every half hour 09:30-14:30
    Y = []
    for s, dd in P.items():
        if FO and s not in FO:
            continue
        for d, (pc, rows) in dd.items():
            if d not in D_ or pc <= 0:
                continue
            for off in range(15, 346, 5):                         # every 5-minute mark, so each alert meets the yardstick of ITS time of day
                a = rows[rows[:, 0] <= off - 5]
                if not len(a):
                    continue
                mv0 = float(a[-1, 3]) / pc - 1
                if abs(mv0) >= 0.005:
                    o = outcome(rows, off, 1 if mv0 > 0 else -1)
                    if o:
                        Y.append((d, o[0], o[1], off // 30))
    av = lambda v: sum(v) / len(v) if v else float("nan")
    y0, y1, y2 = av([x[1] for x in Y]), av([x[1] for x in Y if x[0] < mid]), av([x[1] for x in Y if x[0] >= mid])
    YB = {}                                                     # the yardstick of the same day and the same half hour
    for d, mv, w, b in Y:
        YB.setdefault((d, b), []).append(mv)
    YB = {k: av(v) for k, v in YB.items() if len(v) >= 5}
    for r in R:
        r["e"] = r["mv"] - YB[(r["d"], r["b"])] if (r["d"], r["b"]) in YB else None
    R = [r for r in R if r["e"] is not None]
    say("  %d alerts scored on %d days (%d skipped: no CE/PE side, or no prices that day) · the halves split at %s" % (len(R), len(D_), nos, dt.date.fromordinal(mid)))
    say("  YARDSTICK - any F&O share already moving 0.5%%+ that way, every 5 minutes: %d cases · to 15:10 %+.2f%% (halves %+.2f%% / %+.2f%%) · worked %.0f%%" % (
        len(Y), 100 * y0, 100 * y1, 100 * y2, 100 * av([x[2] for x in Y])))
    say("")
    say("1 EACH ALERT TYPE - what the share did after it, its way · 'worked' = +1.5% before -1% · edge = against the yardstick OF THE SAME DAY AND HALF HOUR")
    say("  (so an early alert is not credited for firing when every share moves most - it must beat the shares moving at that same time)")
    say("    %-16s %6s %7s │ %-8s %-7s %-7s │ %s" % ("type", "alerts", "a day", "to 15:10", "its way", "worked", "edge (halves)"))
    G = {}
    for r in R:
        G.setdefault(r["k"], []).append(r)
    rows_out = []
    for k, X in G.items():
        if len(X) < 15:
            continue
        e1 = av([r["e"] for r in X if r["d"] < mid]); e2 = av([r["e"] for r in X if r["d"] >= mid]); e = av([r["e"] for r in X])
        ok = len(X) >= 100 and e1 == e1 and e2 == e2 and e1 >= 0.001 and e2 >= 0.001
        bad = len(X) >= 100 and e1 == e1 and e2 == e2 and e1 <= -0.001 and e2 <= -0.001
        rows_out.append((e, "    %-16s %6d %6.1f  │ %+.2f%%  %3.0f%%    %3.0f%%    │ %+.2f%% (%+.2f%% / %+.2f%%) %s" % (
            k[:16], len(X), len(X) / len(D_), 100 * av([r["mv"] for r in X]), 100 * av([1 if r["mv"] > 0 else 0 for r in X]), 100 * av([r["w"] for r in X]),
            100 * e, 100 * e1, 100 * e2, "✔ worth something" if ok else "✘ steadily WORSE than no alert" if bad else "✘ not steady" if len(X) >= 100 else "· too few to judge")))
    for _, ln in sorted(rows_out, key=lambda z: -z[0]):
        say(ln)
    # 1b THE FIRST ALERT of each share, side and day - the one you would act on - and 1c AGREEMENT of two or more ✔ types
    OKT = {k for k in G if any(ln.strip().startswith(k[:16]) and "✔" in ln for _, ln in rows_out)}
    seen = {}; FIRST = []
    for r in sorted(R, key=lambda r: (r["d"], r["t"])):
        if (r["d"], r["s"]) not in seen:
            seen[(r["d"], r["s"])] = r; FIRST.append(r)
    say("")
    say("1b ONLY THE FIRST ALERT of each share each day (the one you would act on) - by type, against the shares moving then")
    G1 = {}
    for r in FIRST:
        G1.setdefault(r["k"], []).append(r)
    for k, X in sorted(G1.items(), key=lambda kv: -av([r["e"] for r in kv[1]])):
        if len(X) < 20:
            continue
        e1, e2 = av([r["e"] for r in X if r["d"] < mid]), av([r["e"] for r in X if r["d"] >= mid])
        ok = len(X) >= 60 and e1 == e1 and e2 == e2 and e1 >= 0.001 and e2 >= 0.001
        say("    %-16s %5d first alerts │ to 15:10 %+.2f%% · its way %3.0f%% · worked %3.0f%% │ edge %+.2f%% (%+.2f%% / %+.2f%%) %s" % (
            k[:16], len(X), 100 * av([r["mv"] for r in X]), 100 * av([1 if r["mv"] > 0 else 0 for r in X]), 100 * av([r["w"] for r in X]),
            100 * av([r["e"] for r in X]), 100 * e1, 100 * e2, "✔" if ok else "✘" if len(X) >= 60 else "·"))
    say("")
    say("1c AGREEMENT - the moment a SECOND different ✔ type flags the same share the same way within 15 minutes (✔ types: %s)" % (", ".join(sorted(OKT)) or "none"))
    AG = []; last = {}
    for r in sorted(R, key=lambda r: (r["d"], r["t"])):
        if r["k"] not in OKT:
            continue
        m_ = int(r["t"][:2]) * 60 + int(r["t"][3:5]); key = (r["d"], r["s"], r["dr"])
        prev = [x for x in last.get(key, []) if m_ - x[0] <= 15 and x[1] != r["k"]]
        if prev and key not in {(a["d"], a["s"], a["dr"]) for a in AG}:
            AG.append(r)
        last.setdefault(key, []).append((m_, r["k"]))
    for nm, f in (("all agreements", lambda r: True), ("before 10:30", lambda r: r["t"] < "10:30"), ("10:30 or later", lambda r: r["t"] >= "10:30")):
        X = [r for r in AG if f(r)]
        if len(X) < 10:
            say("    %-16s %5d - too few" % (nm, len(X))); continue
        e1, e2 = av([r["e"] for r in X if r["d"] < mid]), av([r["e"] for r in X if r["d"] >= mid])
        say("    %-16s %5d (%.1f a day) │ to 15:10 %+.2f%% · its way %3.0f%% · worked %3.0f%% │ edge %+.2f%% (%+.2f%% / %+.2f%%) %s" % (
            nm, len(X), len(X) / len(D_), 100 * av([r["mv"] for r in X]), 100 * av([1 if r["mv"] > 0 else 0 for r in X]), 100 * av([r["w"] for r in X]),
            100 * av([r["e"] for r in X]), 100 * e1, 100 * e2, "✔" if len(X) >= 60 and e1 == e1 and e2 == e2 and e1 >= 0.001 and e2 >= 0.001 else "✘" if len(X) >= 60 else "·"))
    say("")
    say("1d LATENESS - how much of the move had ALREADY happened in the 30 minutes before the alert (from that half hour's low, its way) - and what came after")
    say("    %-26s %6s │ %-9s %-7s %-7s │ %s" % ("", "alerts", "to 15:10", "its way", "worked", "against shares moving then"))
    for nm, f in (("early: under 0.5% done", lambda r: r["pre"] < 0.005), ("0.5% to 1% done", lambda r: 0.005 <= r["pre"] < 0.01),
                  ("late: 1% to 2% done", lambda r: 0.01 <= r["pre"] < 0.02), ("very late: 2%+ done", lambda r: r["pre"] >= 0.02)):
        X = [r for r in R if f(r)]
        if len(X) < 20:
            say("    %-26s %6d - too few" % (nm, len(X))); continue
        e1, e2 = av([r["e"] for r in X if r["d"] < mid]), av([r["e"] for r in X if r["d"] >= mid])
        say("    %-26s %6d │ %+.2f%%    %3.0f%%    %3.0f%%    │ %+.2f%% (halves %+.2f%% / %+.2f%%)" % (nm, len(X), 100 * av([r["mv"] for r in X]),
            100 * av([1 if r["mv"] > 0 else 0 for r in X]), 100 * av([r["w"] for r in X]), 100 * av([r["e"] for r in X]), 100 * e1, 100 * e2))
    say("    by type - the share of its alerts that came LATE (1%+ of the move already done):")
    lt = sorted(((k, len(X), 100 * av([1 if r["pre"] >= 0.01 else 0 for r in X])) for k, X in G.items() if len(X) >= 40), key=lambda z: -z[2])
    say("    " + " · ".join("%s %d%%" % (k, p_) for k, n_, p_ in lt[:14]))
    say("")
    say("2 THE NOISE - how many alerts one share got in one day (09:20-15:00)")
    n = sorted(per.values())
    if n:
        say("    median %d · 90%% of share-days had %d or fewer · the most: %d" % (n[len(n) // 2], n[int(len(n) * 0.9)], n[-1]))
        top = sorted(per.items(), key=lambda kv: -kv[1])[:5]
        say("    the noisiest: " + " · ".join("%s %s %d" % (s, d[5:], v) for (d, s), v in top))
    say("")
    say("3 BY TIME OF DAY - all alerts together")
    for nm, lo, hi in (("09:20-10:00", "09:20", "10:00"), ("10:00-11:30", "10:00", "11:30"), ("11:30-13:30", "11:30", "13:30"), ("13:30-15:00", "13:30", "15:00")):
        X = [r for r in R if lo <= r["t"] < hi]
        if X:
            say("    %-12s %6d alerts │ to 15:10 %+.2f%% · its way %3.0f%% · worked %3.0f%% · against shares moving then %+.2f%%" % (nm, len(X), 100 * av([r["mv"] for r in X]), 100 * av([1 if r["mv"] > 0 else 0 for r in X]), 100 * av([r["w"] for r in X]), 100 * av([r["e"] for r in X])))
    try:
        open(os.path.join(D, "data", "alertaudit.txt"), "w").write("\n".join(L) + "\n"); say("  saved: data/alertaudit.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
