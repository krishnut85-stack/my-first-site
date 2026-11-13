#!/bin/bash
# missedmove.sh - READ ONLY. DID GIR MISS A MOVE? (Rama, 13 Nov: "I don't want to miss any critical act for PE or CE").
#   Every F&O share that moved 2%+ from yesterday's close during the session (5-min candles): when it crossed 2%, how far it went, where it closed -
#   and whether GIR RANG a call its way (as it was sent that day - its ring tag, not today's rules) (CE side up / PE side down) from 30 min before to 15 min after the cross:
#     ✅ rang in time (by the cross + 5 min) · 🕒 rang late (5-15 min after) · 🔕 only silent alerts · ❌ nothing at all
#   The last trading session only (the engine's charts.json). Changes nothing, sends nothing.   bash missedmove.sh [MIN%]   (default 2)
D=/home/globalbot/intraday; MIN=${1:-2}
cd $D || exit 1
python3 - "$MIN" <<'PY'
import sys, re, json, sqlite3, collections
sys.path.insert(0, "/home/globalbot/intraday")
MIN = float(sys.argv[1])
try:
    import alertword
    tier = alertword.tier
except Exception:
    tier = lambda t: "move"
ch = json.load(open("charts.json"))
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
day = c.execute("select max(day) from alerts where t between '09:15' and '15:30'").fetchone()[0]
rows = c.execute("select t, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
hm = lambda m: "%02d:%02d" % (m // 60, m % 60)
mins = lambda t: int(t[:2]) * 60 + int(t[3:5])
def side(tx):
    h = (tx or "").split("\n")[0]
    up = "▲" in h or bool(re.search(r"\bCE\b", h)); dn = "▼" in h or bool(re.search(r"\bPE\b", h))
    return 1 if up and not dn else -1 if dn and not up else 0
def rang_then(tx):
    """did it RING that day? GIR keeps every alert as it was sent: a ringing one carries its tag, a held one "🔕 no ring" (not today's rules)"""
    tx = tx or ""
    if "🔕 no ring" in tx:
        return False
    return any(k in tx for k in ("🔴 TRADE ALERT", "🟠 SOMETHING IS HAPPENING", "📌 F&O"))
A = collections.defaultdict(list)
for t, tx in rows:
    h = (tx or "").split("\n")[0]
    for m in re.finditer(r"\b([A-Z][A-Z0-9&\-]{1,19})\b", h):
        A[m.group(1)].append((mins(str(t)), str(t)[:5], tx))
R, cnt = [], collections.Counter()
for sym, cc in ch.items():
    if sym in ("NIFTY50", "NIFTY", "BANKNIFTY"):
        continue
    pc, H, L, C = cc.get("pc"), cc.get("h") or [], cc.get("l") or [], cc.get("c") or []
    if not pc or not C:
        continue
    for d in (1, -1):
        X = [((x / pc - 1) * 100 * d) if x else None for x in (H if d > 0 else L)]
        i = next((k for k, x in enumerate(X) if x is not None and x >= MIN), None)
        if i is None:
            continue
        T = 555 + 5 * i
        far = max(x for x in X if x is not None)
        last = next((x for x in reversed(C) if x), None)
        close = (last / pc - 1) * 100 if last else 0
        rang = [(m, t_, tx) for m, t_, tx in A.get(sym, []) if T - 30 <= m <= T + 15 and side(tx) == d and rang_then(tx)]
        quiet = [(m, t_, tx) for m, t_, tx in A.get(sym, []) if T - 30 <= m <= T + 15 and side(tx) == d]
        if rang and min(m for m, _, _ in rang) <= T + 5:
            k = "✅ rang in time"
        elif rang:
            k = "🕒 rang late"
        elif quiet:
            k = "🔕 only silent"
        else:
            k = "❌ nothing"
        cnt[k] += 1
        later = [(m, t_, tx) for m, t_, tx in A.get(sym, []) if m > T + 15 and side(tx) == d]
        first = (rang or quiet or [(0, "", "")])[0]
        if not rang and not quiet and later:
            first = (later[0][0], "%s (%d min after the cross)" % (later[0][1], later[0][0] - T), later[0][2])
        R.append((k, sym, "▲" if d > 0 else "▼", hm(T), far, close * d, first[1], (first[2] or "").split("\n")[0][:60]))
print("=== %s · F&O shares that moved %.0f%%+ from yesterday's close: %d moves" % (day, MIN, len(R)))
print("   " + " · ".join("%s %d" % (k, cnt[k]) for k in ("✅ rang in time", "🕒 rang late", "🔕 only silent", "❌ nothing")))
order = {"❌ nothing": 0, "🔕 only silent": 1, "🕒 rang late": 2, "✅ rang in time": 3}
for k, s, a, t, far, cl, ft, fh in sorted(R, key=lambda r: (order[r[0]], -r[4])):
    print("   %-16s %-11s %s crossed %s%.0f%% at %s · went %+.1f%% · closed %+.1f%% its way%s" % (k, s, a, "+" if a == "▲" else "-", MIN, t, far * (1 if a == "▲" else -1),
          cl, ("  · first: %s %s" % (ft, fh)) if ft else ""))
print("=== done - nothing was changed")
PY
