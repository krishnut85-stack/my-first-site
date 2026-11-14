#!/bin/bash
# windscore.sh - READ ONLY. THE WIND'S SCORECARD (patch 275): every early wind signal of the day (tomorrow.db wind_calls) - was it right
#   (0.5%+ its way 30 / 60 min later) or wrong (0.5%+ against), and how many MINUTES EARLIER than GIR's first alert on that share and side.
#   Decides whether the wind may ring (it needs SPEED's level: right 55%, wrong under 10%).   bash windscore.sh [YYYY-MM-DD]
D=/home/globalbot/intraday
cd $D || exit 1
python3 - "${1:-$(TZ=Asia/Kolkata date +%F)}" <<'PY'
import re, sys, json, sqlite3, statistics, datetime as dt
import numpy as np
day = sys.argv[1]; IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
d0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST).timestamp()
ro = lambda db: sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
try:
    c = ro("tomorrow.db"); W = c.execute("select t, sym, side, kind, px, px3, oi3, book, sec, score from wind_calls where day=? order by t", (day,)).fetchall()
    A = c.execute("select t, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception as ex:
    print("no wind signals yet (%s) - they start on the first trading day after patch 275" % str(ex)[:60]); sys.exit(0)
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def closes(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float); idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                return ts[idx], np.asarray(z["c"], float)[idx]
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c"):
        return np.array([d0 + 300 * i for i in range(len(x["c"]))], float), np.array([v if v is not None else np.nan for v in x["c"]], float)
    return None
first = {}
for t, tx in A:
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", (tx or "").split("\n")[0])
    if m:
        k = (m.group(2), "CE" if m.group(1) == "▲" else "PE")
        first.setdefault(k, []).append(dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp())
R = []
for t, s, side, kind, px, px3, oi3, book, sec, score in W:
    ts_ = dt.datetime.fromisoformat("%s %s" % (day, t)).replace(tzinfo=IST).timestamp(); sd = 1 if side == "CE" else -1
    b = closes(s); r30 = r60 = None
    if b:
        T_, C = b
        def at(x):
            k = int((x - T_[0]) // 300)
            return C[k] if 0 <= k < len(C) and not np.isnan(C[k]) else None
        p0 = px or at(ts_)
        for mins in (30, 60):
            p = at(ts_ + mins * 60)
            if p and p0:
                v = (p / p0 - 1) * 100 * sd
                if mins == 30: r30 = v
                else: r60 = v
    g = [x for x in first.get((s, side), []) if x >= ts_ - 600]
    lead = (min(g) - ts_) / 60 if g else None
    R.append((t, s, side, kind, score, r30, r60, lead, px3, oi3, book))
print("=== %s · wind signals: %d" % (day, len(R)))
sc = [x for x in R if x[6] is not None]
if sc:
    r = [x[6] for x in sc]
    print("   after 60 min: right (0.5%%+ its way) %d of %d (%d%%) · wrong (0.5%%+ against) %d (%d%%) · avg %+.2f%%   [SPEED: right 55%%, wrong 6%%]" % (
        sum(1 for v in r if v >= 0.5), len(r), 100 * sum(1 for v in r if v >= 0.5) // len(r), sum(1 for v in r if v <= -0.5), 100 * sum(1 for v in r if v <= -0.5) // len(r), sum(r) / len(r)))
    for k in ("LONG BUILD-UP", "SHORT BUILD-UP", "SHORT COVERING", "LONG UNWINDING", "PRICE ONLY"):
        z = [x[6] for x in sc if x[3] == k]
        if z:
            print("     %-15s %3d · right %d · wrong %d · avg %+.2f%%" % (k, len(z), sum(1 for v in z if v >= 0.5), sum(1 for v in z if v <= -0.5), sum(z) / len(z)))
L = [x[7] for x in R if x[7] is not None]
if L:
    print("   GIR's own first alert on that share and side came: median %+.1f min after the wind (positive = the wind was earlier) · the wind earlier in %d of %d" % (
        statistics.median(L), sum(1 for v in L if v > 0), len(L)))
print("   (time · share · side · kind · wind · 30 min · 60 min · GIR's first alert vs the wind)")
for t, s, side, kind, score, r30, r60, lead, px3, oi3, book in R[:60]:
    f = lambda v: "%+.1f%%" % v if v is not None else "  -  "
    print("   %s %-11s %s %-15s %d/4  %6s %6s  %s" % (t[:5], s, side, kind, score, f(r30), f(r60), ("GIR %+.0f min" % lead) if lead is not None else "GIR: no alert"))
PY
