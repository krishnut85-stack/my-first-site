#!/usr/bin/env python3
"""stratpool.py - READ ONLY. Adds up every day's fastreplay.py output in a folder into ONE report per strategy (weighted by the number of trades).
python3 stratpool.py /root/strat"""
import re, sys, glob
D = sys.argv[1] if len(sys.argv) > 1 else "/root/strat"
FILES = sorted(glob.glob(D + "/2026-*.txt"))
PAT = {
 "3e": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · TURNED BACK\s+(\d+)% · held to 15:20: average ([+-][\d.]+)%", ("KEPT GOING", "TURNED BACK", "held to 15:20")),
 "3f": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · BACK INSIDE\s+(\d+)% · held to 15:20 ([+-][\d.]+)%", ("KEPT GOING", "BACK INSIDE", "held to 15:20")),
 "3g": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · 2R reached\s+(\d+)% · average ([+-][\d.]+)R", ("WON", "2R reached", "average R")),
 "3h": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · avg ([+-][\d.]+)% on the share$", ("WON", None, "avg % on the share")),
 "3i": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · avg ([+-][\d.]+)% on the share \(stop 2 / target 2\) · held to 15:20 ([+-][\d.]+)% · book half \+ trail ([+-][\d.]+)%", ("WON", None, "avg %")),
}
TITLE = {"3e": "🚀 MOMENTUM - a share already 3% / 5% / 8% on the day (Rama's way)", "3f": "THE INITIAL BALANCE - the break of the first 15 / 30 / 60 min",
         "3g": "STOCKS IN PLAY - the 5-minute opening range breakout (1R = your risk)", "3h": "THE EXIT TEST - the same +3% entries, every exit rule",
         "3i": "RESULTS DAY 2 - yesterday's 5%+ movers, entered at 09:20"}
A, ORD = {}, {}
for f in FILES:
    sec, parent = None, ""
    for ln in open(f, encoding="utf-8"):
        m = re.match(r"=== (3[a-z])\b", ln)
        if m:
            sec, parent = m.group(1), ""; continue
        if sec not in PAT:
            continue
        m = re.match(PAT[sec][0], ln.rstrip("\n"))
        if not m:
            continue
        nm = m.group(1).strip(); n = int(m.group(2))
        if not nm.startswith("..."):
            parent = nm
        k = (parent, nm) if nm.startswith("...") else ("", nm)
        a = A.setdefault(sec, {}).setdefault(k, [0, 0.0, 0.0, 0.0, 0.0, 0.0, set()])
        ORD.setdefault(sec, [])
        if k not in ORD[sec]:
            ORD[sec].append(k)
        g = m.groups()
        a[0] += n; a[6].add(f)
        if sec in ("3e", "3f", "3g"):
            a[1] += n * int(g[2]) / 100; a[2] += n * int(g[3]) / 100; a[3] += n * float(g[4])
        elif sec == "3h":
            a[1] += n * int(g[2]) / 100; a[3] += n * float(g[3])
        else:
            a[1] += n * int(g[2]) / 100; a[3] += n * float(g[3]); a[4] += n * float(g[4]); a[5] += n * float(g[5])
print("%d days: %s ... %s" % (len(FILES), FILES[0][-14:-4] if FILES else "-", FILES[-1][-14:-4] if FILES else "-"))
for sec in ("3e", "3f", "3g", "3h", "3i"):
    if sec not in A:
        continue
    print("\n=== " + TITLE[sec])
    rows = ORD[sec]
    if sec == "3h":
        rows = sorted(rows, key=lambda k: (k[1][:12], -A[sec][k][3] / max(1, A[sec][k][0])))
    for k in rows:
        n, x, y, z, u, v, days = A[sec][k]
        ind = "   " if k[1].startswith("...") else ""
        if sec in ("3e", "3f"):
            print("%s%-50s %5d · %s %3.0f%% · %s %3.0f%% · %s %+.2f%%" % (ind, k[1], n, PAT[sec][1][0], 100 * x / n, PAT[sec][1][1], 100 * y / n, PAT[sec][1][2], z / n))
        elif sec == "3g":
            print("%s%-50s %5d · WON %3.0f%% · 2R %3.0f%% · average %+.2fR · total %+.0fR" % (ind, k[1], n, 100 * x / n, 100 * y / n, z / n, z))
        elif sec == "3h":
            print("  %-58s %5d · WON %3.0f%% · avg %+.2f%% on the share" % (k[1], n, 100 * x / n, z / n))
        else:
            print("%s%-50s %5d · WON %3.0f%% · stop 2/target 2 %+.2f%% · held %+.2f%% · half+trail %+.2f%%" % (ind, k[1], n, 100 * x / n, z / n, u / n, v / n))
