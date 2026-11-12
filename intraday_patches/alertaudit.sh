#!/bin/bash
# alertaudit.sh - READ ONLY. One day's alerts, measured: how many, which rang, the repeats, the contradictions, the busiest shares, and
# whether each 🔴 P1 call was right 15 / 60 min later (5-min candles). Changes nothing, sends nothing.   bash alertaudit.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$DAY" <<'PY'
import sys, json, sqlite3, collections
sys.path.insert(0, "/home/globalbot/intraday")
import alertword
try:
    import tglanes
except Exception:
    tglanes = None
day = sys.argv[1]
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = [(str(t)[:8], s or "", (sd or "").upper(), tx or "") for t, s, sd, tx in c.execute("select t, sym, side, text from alerts where day=? order by t", (day,))]
c.close()
mins = lambda t: int(t[:2]) * 60 + int(t[3:5])
head = lambda tx: tx.split("\n")[0]
kind = lambda tx: (head(tx).split() or ["?"])[0]
A = []
for t, s, sd, tx in rows:
    tr = alertword.tier(tx)
    A.append({"t": t, "s": s, "sd": sd, "tx": tx, "tr": tr, "ring": tr != "read", "k": kind(tx),
              "tn": bool(tglanes and tglanes.trade_now(tx)), "crit": "CRITICAL" in head(tx)})
R = [a for a in A if a["ring"]]
print("=== %s · %d alerts · %d RANG your phone · %d quiet (page + digest)" % (day, len(A), len(R), len(A) - len(R)))
print("   by level: P1 act %d · P2 move %d · know %d · quiet %d" % tuple(sum(1 for a in A if a["tr"] == x) for x in ("act", "move", "know", "read")))
mk = [a for a in R if "09:15" <= a["t"] < "15:30"]
print("   rang in market hours: %d = one every %.1f min" % (len(mk), 375 / max(1, len(mk))))
print("=== rings by hour")
H = collections.Counter(a["t"][:2] for a in R)
print("   " + " · ".join("%s:00 %d" % (h, H[h]) for h in sorted(H)))
print("=== the kinds (count / rang)")
K = collections.Counter(a["k"] for a in A); KR = collections.Counter(a["k"] for a in R)
for k, n in K.most_common(18):
    ex = next(head(a["tx"])[:70] for a in A if a["k"] == k)
    print("   %-3s %4d / %-4d e.g. %s" % (k, n, KR[k], ex))
print("=== the busiest shares (count / rang)")
S = collections.Counter(a["s"] for a in A if a["s"]); SR = collections.Counter(a["s"] for a in R if a["s"])
print("   " + " · ".join("%s %d/%d" % (s, n, SR[s]) for s, n in S.most_common(15)))
print("=== repeats: the same share + kind again within 15 min (rang)")
last, rep = {}, []
for a in R:
    k = (a["s"], a["k"])
    if a["s"] and k in last and mins(a["t"]) - mins(last[k]) <= 15:
        rep.append(a)
    last[k] = a["t"]
print("   %d of the %d rings were repeats" % (len(rep), len(R)))
for a in rep[:8]:
    print("   %s %s" % (a["t"][:5], head(a["tx"])[:90]))
print("=== contradictions: the same share rang UP and DOWN within 30 min")
cx, seen = [], {}
for a in R:
    if not a["s"] or a["sd"] not in ("CE", "PE"):
        continue
    p = seen.get(a["s"])
    if p and p["sd"] != a["sd"] and mins(a["t"]) - mins(p["t"]) <= 30:
        cx.append((p, a))
    seen[a["s"]] = a
print("   %d" % len(cx))
for p, a in cx[:10]:
    print("   %s %-11s %s %-40s -> %s %s %s" % (p["t"][:5], a["s"], p["sd"], head(p["tx"])[:40], a["t"][:5], a["sd"], head(a["tx"])[:50]))
print("=== every 🔴 P1 call: right or wrong (the share's move its way, 5-min candles)")
try:
    ch = json.load(open("charts.json"))
except Exception:
    ch = {}
ok = n = 0
for a in A:
    if a["tr"] != "act" or a["sd"] not in ("CE", "PE") or not a["s"]:
        continue
    C = (ch.get(a["s"]) or {}).get("c") or []
    i = (mins(a["t"]) - 555) // 5
    if not (0 <= i < len(C)) or not C[i]:
        continue
    d = 1 if a["sd"] == "CE" else -1
    at = lambda j: C[min(len(C) - 1, j)] if C[min(len(C) - 1, j)] else None
    m15, m60 = [((at(i + k) / C[i] - 1) * 100 * d) if at(i + k) else None for k in (3, 12)]
    best = max(((x / C[i] - 1) * 100 * d) for x in C[i:i + 13] if x)
    worst = min(((x / C[i] - 1) * 100 * d) for x in C[i:i + 13] if x)
    n += 1; right = m60 is not None and m60 > 0.3; ok += right
    print("   %s %-11s %s %+5.1f%% in 15m · %+5.1f%% in 60m · best %+4.1f%% worst %+4.1f%% %s  %s" % (a["t"][:5], a["s"], a["sd"], m15 or 0, m60 or 0, best, worst,
                                                                                 "✅" if right else "❌", head(a["tx"])[:50]))
print("   P1 right after 60 min: %d of %d" % (ok, n))
PY
echo "=== done - nothing was changed"
