#!/bin/bash
# circuitcheck.sh - READ ONLY. Did GIR's 🧱 CIRCUIT agent (patch 114) see today's big F&O moves (results day)?
# Shows: the agent's start, its 🧱 alerts today, and every F&O share that moved 7%+ at some point today (from the 5-min candles),
# how far, at what time, and whether a 🧱 alert went out for it. Changes nothing. Usage: bash circuitcheck.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
echo "=== the circuit agent today"
journalctl -u gir-intraday --since "$DAY" --no-pager 2>/dev/null | grep -E "GAP \+ CIRCUIT agent|gap quote failed|CIRCUIT [A-Z]" | tail -15 | cut -c1-160
cd $D && python3 - "$DAY" <<'PY'
import sys, json, sqlite3
day = sys.argv[1]
al = {}
try:
    c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
    for t, s, tx in c.execute("select t, sym, text from alerts where day=? and text like '%🧱 CIRCUIT%' order by t", (day,)):
        al.setdefault(s, []).append((t, tx.split("\n")[0][:110]))
    c.close()
except Exception as ex:
    print("   alerts not read:", ex)
print("=== 🧱 CIRCUIT alerts today: %d" % sum(len(v) for v in al.values()))
for s, v in al.items():
    for t, h in v:
        print("   %s  %s" % (t, h))
ch = json.load(open("charts.json"))
rows = []
for s, v in ch.items():
    pc, H, L, C = v.get("pc"), v.get("h") or [], v.get("l") or [], v.get("c") or []
    if not pc or not H:
        continue
    hs = [(x, i) for i, x in enumerate(H) if x]; ls = [(x, i) for i, x in enumerate(L) if x]
    if not hs or not ls:
        continue
    hi, ih = max(hs); lo, il = min(ls)
    up, dn = (hi / pc - 1) * 100, (lo / pc - 1) * 100
    last = next((x for x in reversed(C) if x), None)
    tm = lambda i: "%02d:%02d" % divmod(9 * 60 + 15 + 5 * i, 60)
    if up >= 7:
        rows.append((up, s, "▲ high %+.1f%% at %s" % (up, tm(ih)), last, pc))
    if dn <= -7:
        rows.append((-dn, s, "▼ low %+.1f%% at %s" % (dn, tm(il)), last, pc))
print("=== F&O shares that moved 7%%+ today (5-min candles): %d" % len(rows))
for _, s, what, last, pc in sorted(rows, reverse=True):
    print("   %-11s %-24s close %+.1f%%   🧱 alert: %s" % (s, what, (last / pc - 1) * 100 if last else 0, (al.get(s) or [("none", "")])[0][0]))
PY
echo "=== done - nothing was changed"
