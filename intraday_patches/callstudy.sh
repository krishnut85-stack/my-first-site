#!/bin/bash
# callstudy.sh - READ ONLY. WHICH ALERTS ARE WORTH A RING? (Rama, 14 Nov: "I don't want to miss any critical movement - alerts for both PE and CE";
#   POLICYBZR 13 Nov: 50 alerts, the two real CE moments buried). Every past alert GIR kept (tomorrow.db) with a side (▲ / ▼ · CE / PE), scored on
#   the share's own 5-min candles: did it go on 0.5%+ its way 30 and 60 min later? By kind, then by the conditions a clean call would need:
#     time (after 09:45) · VWAP (price on the right side of the day's average) · EXTREME (at a new day high / low) · DAY (the day's move agrees)
#     · CONFLUENCE (2+ different kinds the same way on the share within 15 min) · the opening call failing (0.8% against in 30 min) -> the other side
#   ★ = 30+ cases and right 55%+ after 60 min - the candidates to ring. Changes nothing, sends nothing.   bash callstudy.sh [days back, default 60]
D=/home/globalbot/intraday; DAYS=${1:-60}
cd $D || exit 1
python3 - "$DAYS" <<'PY'
import sys, os, re, sqlite3, collections, datetime as dt
import numpy as np
sys.path.insert(0, "/home/globalbot/intraday")
DAYS = int(sys.argv[1]); IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
WIN, BAR = 0.5, 300
try:
    import core
    DATA = core.DATA
except Exception:
    DATA = "data"
KINDS = [("P1", r"🔴 TRADE ALERT|⚖ VOTE[^\n]*✓ P1"), ("OPENING CALL", r"OPENING CALL"), ("ENTER NOW", r"ENTER NOW"), ("GO", r"^🟢 GO\b"),
         ("BUILD-UP", r"^🧩 (LONG|SHORT) BUILD-UP"), ("OI other", r"^🧩"), ("BREAKING NOW", r"BREAKING NOW"), ("SUDDEN", r"SUDDEN"),
         ("FIRST MOVE", r"FIRST MOVE"), ("RUNNING", r"RUNNING"), ("SPEED", r"SPEED"), ("PUSH/PULL", r"(PUSH|PULL) STARTED"),
         ("TURN (profit booking / short covering)", r"PROFIT BOOKING|SHORT COVERING"), ("PATTERN", r"PATTERN"), ("TRIAL ENTRY", r"TRIAL ENTRY"),
         ("EVENT WATCH", r"EVENT WATCH"), ("NEWS", r"^📰"), ("RESULTS", r"RESULTS"), ("WHY", r"^🔍 WHY")]
SYM = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b|·\s+([A-Z][A-Z0-9&\-]{2,19})\s+[▲▼]")
NOT = {"CE", "PE", "BUY", "SELL", "UP", "DOWN", "OI", "GO", "CRITICAL", "NIFTY", "BANKNIFTY", "SENSEX", "MARKET", "FINNIFTY"}
def kind_of(tx):
    h = tx.split("\n")[0]
    for k, rx in KINDS:
        if re.search(rx, tx if k == "P1" else h):
            return k
    return None
def side_of(h):
    up, dn = "▲" in h or bool(re.search(r"\bCE\b", h)), "▼" in h or bool(re.search(r"\bPE\b", h))
    return 1 if up and not dn else -1 if dn and not up else 0
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
d0 = str(dt.date.today() - dt.timedelta(days=DAYS))
rows = c.execute("select day, t, text from alerts where day>=? and t>='09:15' and t<'15:05' order by day, t", (d0,)).fetchall(); c.close()
A, seen = [], {}
for day, t, tx in rows:
    tx = tx or ""; h = tx.split("\n")[0]
    k = kind_of(tx); s = side_of(h)
    if not k or not s:
        continue
    m = [x for x in (g for mm in SYM.finditer(h) for g in mm.groups()) if x and x not in NOT]
    if not m:
        continue
    sym = m[0]; ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    key = (day, sym, k, s)
    if key in seen and ts - seen[key] < 600:                       # a repeat of the same line within 10 min counts once
        continue
    seen[key] = ts
    A.append({"day": day, "t": str(t)[:5], "ts": ts, "sym": sym, "k": k, "s": s})
H = {}
def bars(sym):
    if sym not in H:
        a = None
        for p in (os.path.join(DATA, sym + ".npz"), os.path.join(DATA, "h3", sym + ".npz"), os.path.join(DATA, "h3", "5min", sym + ".npz")):
            try:
                z = np.load(p); a = {k: np.asarray(z[k], dtype=float) for k in ("ts", "o", "h", "l", "c", "v")}; break
            except Exception:
                continue
        H[sym] = a
    return H[sym]
def score(a):
    B = bars(a["sym"])
    if B is None or not len(B["ts"]):
        return None
    ts = B["ts"]; day0 = (ts + 19800) // 86400; dd = (a["ts"] + 19800) // 86400
    idx = np.nonzero(day0 == dd)[0]
    if len(idx) < 3:
        return None
    i = idx[np.searchsorted(ts[idx], a["ts"] - BAR, side="right") - 1] if ts[idx[0]] <= a["ts"] - BAR else idx[0]
    j = int(np.searchsorted(idx, i))
    C, Hh, L, V = B["c"][idx], B["h"][idx], B["l"][idx], B["v"][idx]
    e = C[j]
    if not e or e != e:
        return None
    s = a["s"]
    f = lambda k: ((C[min(len(C) - 1, j + k)] / e - 1) * 100 * s) if j + k < len(C) else None
    r30, r60 = f(6), f(12)
    if r60 is None:
        return None
    tp = (Hh[:j + 1] + L[:j + 1] + C[:j + 1]) / 3; vv = np.nan_to_num(V[:j + 1])
    vw = float((tp * vv).sum() / vv.sum()) if vv.sum() > 0 else None
    prev = np.nonzero(day0 < dd)[0]
    pc = B["c"][prev[-1]] if len(prev) else None
    hi, lo = np.nanmax(Hh[:j + 1]), np.nanmin(L[:j + 1])
    return {"r30": r30, "r60": r60,
            "late": a["t"] >= "09:45",
            "vwap": (vw is not None and (e - vw) * s > 0),
            "ext": (e >= hi * 0.997) if s > 0 else (e <= lo * 1.003),
            "dayok": (pc is not None and (e / pc - 1) * s > 0),
            "against1": (min(((x / e - 1) * 100 * s) for x in C[j:j + 7] if x) <= -0.8)}
S = []
for a in A:
    r = score(a)
    if r:
        a.update(r); S.append(a)
for a in S:                                                          # confluence: 2+ different kinds the same way within 15 min
    a["conf"] = any(b is not a and b["sym"] == a["sym"] and b["day"] == a["day"] and b["s"] == a["s"] and b["k"] != a["k"] and 0 <= a["ts"] - b["ts"] <= 900 for b in S)
def line(lab, xs):
    n = len(xs)
    if not n:
        return "   %-44s    0" % lab
    w30 = 100 * sum(x["r30"] >= WIN for x in xs if x["r30"] is not None) // max(1, sum(x["r30"] is not None for x in xs))
    w60 = 100 * sum(x["r60"] >= WIN for x in xs) // n
    bad = 100 * sum(x["r60"] <= -WIN for x in xs) // n
    avg = sum(x["r60"] for x in xs) / n
    star = "★" if n >= 30 and w60 >= 55 else " "
    return "%s  %-44s %4d · right 30m %3d%% · 60m %3d%% · wrong 60m %3d%% · avg %+.2f%%" % (star, lab[:44], n, w30, w60, bad, avg)
days = sorted(set(a["day"] for a in S))
print("=== %d alerts with a side, scored on 5-min candles · %d days (%s .. %s) · right = 0.5%%+ its way" % (len(S), len(days), days[0] if days else "-", days[-1] if days else "-"))
print("    (alerts with no candles - a share without history - left out: %d)" % (len(A) - len(S)))
print("=== 1 · BY KIND")
for k, _ in KINDS:
    xs = [a for a in S if a["k"] == k]
    if xs:
        print(line(k, xs))
print("=== 2 · THE CONDITIONS, for the trading kinds (P1 · OPENING CALL · ENTER NOW · GO · BUILD-UP · BREAKING NOW · SUDDEN · FIRST MOVE · RUNNING)")
T = [a for a in S if a["k"] in ("P1", "OPENING CALL", "ENTER NOW", "GO", "BUILD-UP", "BREAKING NOW", "SUDDEN", "FIRST MOVE", "RUNNING")]
print(line("all of them", T))
for lab, fn in (("after 09:45", lambda a: a["late"]), ("price on the right side of VWAP", lambda a: a["vwap"]), ("at a new day high / low", lambda a: a["ext"]),
                ("the day's move agrees", lambda a: a["dayok"]), ("CONFLUENCE: 2+ kinds same way, 15 min", lambda a: a["conf"]),
                ("after 09:45 + VWAP", lambda a: a["late"] and a["vwap"]), ("after 09:45 + VWAP + new extreme", lambda a: a["late"] and a["vwap"] and a["ext"]),
                ("after 09:45 + VWAP + day agrees", lambda a: a["late"] and a["vwap"] and a["dayok"]),
                ("after 09:45 + VWAP + extreme + day", lambda a: a["late"] and a["vwap"] and a["ext"] and a["dayok"]),
                ("after 09:45 + VWAP + confluence", lambda a: a["late"] and a["vwap"] and a["conf"]),
                ("after 09:45 + VWAP + extreme + confluence", lambda a: a["late"] and a["vwap"] and a["ext"] and a["conf"]),
                ("NOT VWAP (against the day's average)", lambda a: not a["vwap"])):
    print(line(lab, [a for a in T if fn(a)]))
print("=== 3 · EACH TRADING KIND with the best combination (after 09:45 + VWAP + new extreme)")
for k in ("P1", "BUILD-UP", "BREAKING NOW", "SUDDEN", "FIRST MOVE", "RUNNING", "ENTER NOW", "GO"):
    xs = [a for a in T if a["k"] == k]
    if xs:
        print(line(k + " · all", xs)); print(line(k + " · 09:45+VWAP+extreme", [a for a in xs if a["late"] and a["vwap"] and a["ext"]]))
print("=== 4 · CE vs PE (trading kinds, after 09:45 + VWAP)")
for s, lab in ((1, "▲ CE side"), (-1, "▼ PE side")):
    print(line(lab, [a for a in T if a["s"] == s and a["late"] and a["vwap"]]))
print("=== 5 · THE OPENING CALL FAILING (0.8% against within 30 min) - would the OTHER side have paid?")
O = [a for a in S if a["k"] in ("OPENING CALL", "GO", "ENTER NOW") and a["t"] < "09:45"]
F = [a for a in O if a["against1"]]
print("   opening calls / GO / ENTER NOW before 09:45: %d · failed (0.8%% against in 30 min): %d" % (len(O), len(F)))
flip = [dict(a, r60=-a["r60"], r30=-a["r30"] if a["r30"] is not None else None) for a in F]
print(line("the other side, from the call's price", flip))
print("=== 6 · POLICYBZR 13 Nov, as scored")
for a in [a for a in S if a["sym"] == "POLICYBZR" and a["day"] == "2026-11-13"][:30]:
    print("   %s %-14s %s  30m %+5.1f%%  60m %+5.1f%%  %s%s%s%s" % (a["t"], a["k"][:14], "▲" if a["s"] > 0 else "▼", a["r30"] or 0, a["r60"],
          "late " if a["late"] else "", "vwap " if a["vwap"] else "", "EXT " if a["ext"] else "", "conf" if a["conf"] else ""))
print("=== done - nothing was changed")
PY
