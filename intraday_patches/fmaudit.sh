#!/bin/bash
# fmaudit.sh - READ ONLY. Are the ⚡ FIRST MOVE alerts right? (patch 249 made FIRST MOVE with volume 5x+ ring). For every FIRST MOVE of the day:
#   did the share keep going its way 15 / 60 min later (5-min candles; "right" = 0.3%+ its way)? Split by the volume (5-8x · 8-12x · 12x+) and by
#   how far the share had already moved that day - to choose the threshold that rings only the good ones. Changes nothing.   bash fmaudit.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$DAY" <<'PY'
import sys, re, json, sqlite3, collections
day = sys.argv[1]
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, text from alerts where day=? and text like '⚡ FIRST MOVE%' order by t", (day,)).fetchall(); c.close()
try:
    ch = json.load(open("charts.json"))
except Exception:
    ch = {}
mins = lambda t: int(t[:2]) * 60 + int(t[3:5])
G = collections.defaultdict(lambda: [0, 0, 0, 0])            # group -> [n, right15, right60, scored]
seen, L = set(), []
for t, tx in rows:
    h = (tx or "").split("\n")[0]
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]+)", h)
    v = re.search(r"volume\s*(\d+(?:\.\d+)?)\s*x", tx or "")
    dd = re.search(r"day\s*([+-]?\d+(?:\.\d+)?)%", tx or "")
    if not m or not v:
        continue
    sym, d, vol = m.group(2), (1 if m.group(1) == "▲" else -1), float(v.group(1))
    if (sym, str(t)[:4]) in seen:
        continue
    seen.add((sym, str(t)[:4]))
    C = (ch.get(sym) or {}).get("c") or []
    i = (mins(str(t)) - 555) // 5
    if not (0 <= i < len(C)) or not C[i]:
        continue
    at = lambda j: C[min(len(C) - 1, j)] or None
    r15 = ((at(i + 3) / C[i] - 1) * 100 * d) if at(i + 3) else None
    r60 = ((at(i + 12) / C[i] - 1) * 100 * d) if at(i + 12) else None
    vb = "5-8x" if vol < 8 else "8-12x" if vol < 12 else "12x+"
    day_ = abs(float(dd.group(1))) if dd else None
    db = "day <1%" if day_ is not None and day_ < 1 else "day 1-2%" if day_ is not None and day_ < 2 else "day 2%+" if day_ is not None else "day ?"
    ring = vol >= 5
    for g in (("ALL (would ring)" if ring else "under 5x (quiet)"), "vol " + vb if ring else None, db if ring else None, ("opening 09:15-09:30" if str(t)[:5] < "09:30" else None)):
        if not g:
            continue
        x = G[g]; x[0] += 1
        if r15 is not None:
            x[1] += r15 > 0.3
        if r60 is not None:
            x[2] += r60 > 0.3; x[3] += 1
    if ring:
        L.append((str(t)[:8], sym, "▲" if d > 0 else "▼", vol, dd.group(1) if dd else "?", r15, r60))
print("=== %s · ⚡ FIRST MOVE: right = the share went 0.3%%+ its way (PUSH / PULL STARTED was 7 of 27 = 26%% after 60 min)" % day)
for g in ("ALL (would ring)", "vol 5-8x", "vol 8-12x", "vol 12x+", "day <1%", "day 1-2%", "day 2%+", "opening 09:15-09:30", "under 5x (quiet)"):
    n, a15, a60, s60 = G.get(g, [0, 0, 0, 0])
    if n:
        print("   %-22s %3d alerts · right after 15 min %3d%% · after 60 min %3d%%" % (g, n, 100 * a15 // n, (100 * a60 // s60) if s60 else 0))
print("=== the ringing ones (volume 5x+)")
for t, s, a, vol, dy, r15, r60 in L[:70]:
    f = lambda x: "  -  " if x is None else "%+5.1f%%" % x
    print("   %s %-11s %s vol %4.0fx day %5s%%  15m %s  60m %s  %s" % (t, s, a, vol, dy, f(r15), f(r60), "✅" if (r60 or 0) > 0.3 else "❌"))
print("=== done - nothing was changed")
PY
