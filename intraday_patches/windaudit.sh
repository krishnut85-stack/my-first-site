#!/bin/bash
# windaudit.sh - READ ONLY. HOW EARLY DOES GIR CATCH THE WIND? (Rama, 14 Nov: "replay yesterday - where do we take more time, how fast can we be").
#   For every real move of the day (an F&O share 1%+ in 15 min that kept going 1.5%+ the next hour) it measures, from the minute the move started:
#   when each kind of GIR alert came (SPEED, FIRST MOVE, the futures money / OI build-up, P1, CONFIRMED MOVE, the first that RANG), how much of the
#   hour's move was ALREADY GONE when the phone rang, how far behind the option-chain readings were, and how long Telegram took.
#   Changes nothing, sends nothing.   bash windaudit.sh [YYYY-MM-DD]   (default: the last trading day)
D=/home/globalbot/intraday
cd $D || exit 1
python3 - "${1:-}" <<'PY'
import os, re, sys, json, sqlite3, statistics, datetime as dt
import numpy as np
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
day = sys.argv[1] or ""
if not day:
    d = now.date() - dt.timedelta(days=1 if now.strftime("%H:%M") < "15:35" else 0)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    day = str(d)
d0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST).timestamp()
hm = lambda ts: dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M:%S")
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
fo = set()
try:
    c = ro("chains.db"); fo = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
except Exception:
    pass
# ---- the day's 5-min candles: charts.json (the last session) or the share's history file
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def bars(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s, "data/h3/5min/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float)
            idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                prev = np.nonzero(ts < ts[idx[0]])[0]
                pc = float(z["c"][prev[-1]]) if len(prev) else None
                return ts[idx], np.asarray(z["c"], float)[idx], np.asarray(z["h"], float)[idx], np.asarray(z["l"], float)[idx], pc
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c") and len(x["c"]) >= 20:
        n = len(x["c"]); C = np.array([v if v is not None else np.nan for v in x["c"]], float)
        Hh = np.array([v if v is not None else np.nan for v in (x.get("h") or x["c"])], float); L = np.array([v if v is not None else np.nan for v in (x.get("l") or x["c"])], float)
        return np.array([d0 + 300 * i for i in range(n)], float), C, Hh, L, x.get("pc")
    return None
# ---- the alerts of the day
try:
    c = ro("tomorrow.db"); A = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception as ex:
    A = []; print("(tomorrow.db: %s)" % ex)
FAM = [("SPEED", r"\bSPEED\b"), ("FIRST MOVE", r"FIRST MOVE"), ("MONEY / OI", r"🧩|BUILD-UP|SHORT COVERING|LONG UNWINDING|F&O MONEY|🔎"),
       ("P1 / TRADE", r"🔴 TRADE ALERT|✓ P1|ENTER NOW|🟢 GO"), ("CONFIRMED", r"CONFIRMED MOVE|RESULTS REACTION"), ("RUNNING / SUDDEN", r"RUNNING|SUDDEN")]
AL = {}
for t, s, tx in A:
    L = (tx or "").split("\n"); h = L[0]
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
    if not m:
        continue
    sym, sd = m.group(2), (1 if m.group(1) == "▲" else -1)
    try:
        ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    sg = re.search(r"(?<![\d:])([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?![\d:])", h)
    sig = dt.datetime.fromisoformat("%s %s:%s:%s" % (day, sg.group(1), sg.group(2), sg.group(3) or "00")).replace(tzinfo=IST).timestamp() if sg else ts
    rang = "🔕" not in (tx or "") and bool(re.search(r"🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|CRITICAL|CONFIRMED MOVE", tx or ""))
    fam = next((f for f, rx in FAM if re.search(rx, tx or "")), "other")
    AL.setdefault(sym, []).append({"t": ts, "sig": min(sig, ts) if abs(ts - sig) < 3600 else ts, "sd": sd, "fam": fam, "rang": rang, "h": h[:70]})
# ---- the option-chain readings
SW = {}
try:
    c = ro("chains.db")
    for s, t in c.execute("select sym, t from chain where d=? group by sym, t", (day,)):
        try:
            SW.setdefault(s, []).append(dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8] if len(str(t)) >= 8 else str(t)[:5] + ":00")).replace(tzinfo=IST).timestamp())
        except Exception:
            pass
    c.close()
except Exception as ex:
    print("(chains.db: %s)" % ex)
# ---- the moves
M = []
for s in sorted(fo or (set(CJ) - {"NIFTY 50", "NIFTY BANK"})):
    b = bars(s)
    if not b:
        continue
    ts, C, Hh, L, pc = b
    seen = set()
    for i in range(3, len(C) - 2):
        if np.isnan(C[i]) or np.isnan(C[i - 3]) or not C[i - 3]:
            continue
        r15 = (C[i] / C[i - 3] - 1) * 100
        if abs(r15) < 1.0:
            continue
        sd = 1 if r15 > 0 else -1
        if sd in seen:
            continue
        st = i - 3
        while st < i and not np.isnan(C[st + 1]) and (C[st + 1] - C[st]) * sd <= 0:
            st += 1                                                   # skip the flat bars: the last close before the first step its way
        while st > 0 and not np.isnan(C[st - 1]) and (C[st] - C[st - 1]) * sd > 0:
            st -= 1                                                   # back to where it really began
        p0 = C[st]
        fut = C[i:min(len(C), i + 13)]
        best = (np.nanmax(fut) if sd > 0 else np.nanmin(fut))
        hour = (best / p0 - 1) * 100 * sd
        if hour < 1.5:
            continue
        seen.add(sd)
        M.append({"s": s, "sd": sd, "t0": ts[st] + 300, "p0": p0, "hour": hour, "C": C, "ts": ts, "st": st, "best": best})
print("=== %s · real moves (1%%+ in 15 min, then 1.5%%+ within the hour): %d on %d shares" % (day, len(M), len({m["s"] for m in M})))
def at_price(m, t):
    k = int((t - m["ts"][0]) // 300)
    k = max(0, min(len(m["C"]) - 1, k))
    v = m["C"][k]
    return None if np.isnan(v) else v
R = {f: [] for f, _ in FAM}; R["FIRST RING"] = []; R["ANY ALERT"] = []
gone, tg, swl, rows = [], [], [], []
for m in M:
    xs = [a for a in AL.get(m["s"], []) if a["sd"] == m["sd"] and m["t0"] - 600 <= a["t"] <= m["t0"] + 3600]
    def first(f=None, rang=False):
        z = [a for a in xs if (f is None or a["fam"] == f) and (not rang or a["rang"])]
        return min(z, key=lambda a: a["t"]) if z else None
    line = {"s": m["s"], "sd": m["sd"], "t0": m["t0"], "hour": m["hour"]}
    for f, _ in FAM:
        a = first(f); R[f].append((a["sig"] - m["t0"]) / 60 if a else None)
    a = first(); R["ANY ALERT"].append((a["sig"] - m["t0"]) / 60 if a else None)
    r = first(rang=True); R["FIRST RING"].append((r["t"] - m["t0"]) / 60 if r else None)
    if r:
        tg.append(r["t"] - r["sig"])
        p = at_price(m, r["t"])
        if p:
            gone.append(max(0.0, min(150.0, (p / m["p0"] - 1) * 100 * m["sd"] / m["hour"] * 100)))
    sw = [t for t in SW.get(m["s"], []) if t >= m["t0"]]
    if sw:
        swl.append((min(sw) - m["t0"]) / 60)
    line.update({"first": a, "ring": r})
    rows.append(line)
def band(xs):
    n = len(xs); got = [x for x in xs if x is not None]
    if not n:
        return "-"
    b = [sum(1 for x in got if x <= 1), sum(1 for x in got if 1 < x <= 3), sum(1 for x in got if 3 < x <= 5), sum(1 for x in got if 5 < x <= 10), sum(1 for x in got if x > 10)]
    med = statistics.median(got) if got else None
    return "%3d of %3d  · median %5s min · ≤1 %3d · 1-3 %3d · 3-5 %3d · 5-10 %3d · 10+ %3d · never %3d" % (len(got), n, ("%.1f" % med) if med is not None else "-", *b, n - len(got))
print("\n=== 1 · FROM THE MOVE'S START TO GIR'S ALERT (the time GIR saw it) - per kind")
for f in ["ANY ALERT"] + [f for f, _ in FAM] + ["FIRST RING"]:
    print("   %-17s %s" % (f, band(R[f])))
print("\n=== 2 · HOW MUCH OF THE HOUR'S MOVE WAS ALREADY GONE WHEN THE PHONE FIRST RANG")
if gone:
    g = sorted(gone)
    print("   median %.0f%% gone · in time (under 25%% gone) %d of %d · late (25-50%%) %d · very late (50%%+) %d" % (
        statistics.median(g), sum(1 for x in g if x < 25), len(g), sum(1 for x in g if 25 <= x < 50), sum(1 for x in g if x >= 50)))
else:
    print("   no move rang")
print("\n=== 3 · WHERE THE MINUTES GO")
if tg:
    print("   GIR saw it -> Telegram accepted it: median %.0f s · worst %.0f s" % (statistics.median(tg), max(tg)))
if swl:
    print("   the move's start -> the next option-chain reading: median %.1f min · worst %.1f min" % (statistics.median(swl), max(swl)))
cad = []
for s, v in SW.items():
    v = sorted(set(v))
    cad += [(b - a) / 60 for a, b in zip(v, v[1:]) if b - a < 3600]
if cad:
    print("   the option chain is read every: median %.1f min (%d readings of %d shares)" % (statistics.median(cad), len(cad), len(SW)))
print("\n=== 4 · EVERY MOVE (start · the hour's move · the first alert · the first ring)")
for x in sorted(rows, key=lambda x: x["t0"]):
    a, r = x["first"], x["ring"]
    print("   %s %-11s %s %+5.1f%%  first: %-26s ring: %s" % (hm(x["t0"])[:5], x["s"], "▲" if x["sd"] > 0 else "▼", x["hour"] * x["sd"],
          ("%s +%.0f min %s" % (hm(a["sig"])[:5], (a["sig"] - x["t0"]) / 60, a["fam"])) if a else "-", ("%s +%.0f min %s" % (hm(r["t"])[:5], (r["t"] - x["t0"]) / 60, r["fam"])) if r else "never rang"))
PY
