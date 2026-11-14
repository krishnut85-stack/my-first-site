#!/usr/bin/env python3
"""stratpool.py - READ ONLY. Adds up every day's fastreplay.py output in a folder into ONE report per strategy (weighted by the number of trades).
python3 stratpool.py /root/strat"""
import re, sys, glob
D = sys.argv[1] if len(sys.argv) > 1 else "/root/strat"
FILES = sorted(glob.glob(D + "/2026-*.txt"))
PAT = {
 "3e": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · TURNED BACK\s+(\d+)% · held to 15:20: average ([+-][\d.]+)%", ("KEPT GOING", "TURNED BACK", "held to 15:20")),
 "3l": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · TURNED BACK\s+(\d+)% · held to 15:20: average ([+-][\d.]+)%", ("KEPT GOING", "TURNED BACK", "held to 15:20")),
 "3k": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · TURNED BACK\s+(\d+)% · held to 15:20: average ([+-][\d.]+)%", ("KEPT GOING", "TURNED BACK", "held to 15:20")),
 "3f": (r"\s+(.+?)\s+(\d+) · KEPT GOING\s+(\d+)% · BACK INSIDE\s+(\d+)% · held to 15:20 ([+-][\d.]+)%", ("KEPT GOING", "BACK INSIDE", "held to 15:20")),
 "3g": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · 2R reached\s+(\d+)% · average ([+-][\d.]+)R", ("WON", "2R reached", "average R")),
 "3h": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · avg ([+-][\d.]+)% on the share$", ("WON", None, "avg % on the share")),
 "3i": (r"\s+(.+?)\s+(\d+) · WON\s+(\d+)% · avg ([+-][\d.]+)% on the share \(stop 2 / target 2\) · held to 15:20 ([+-][\d.]+)% · book half \+ trail ([+-][\d.]+)%", ("WON", None, "avg %")),
}
TITLE = {"3e": "🚀 MOMENTUM - a share already 3% / 5% / 8% on the day (Rama's way)", "3f": "THE INITIAL BALANCE - the break of the first 15 / 30 / 60 min",
         "3g": "STOCKS IN PLAY - the 5-minute opening range breakout (1R = your risk)", "3h": "THE EXIT TEST - the same +3% entries, every exit rule",
         "3i": "RESULTS DAY 2 - yesterday's 5%+ movers, entered at 09:20",
         "3l": "THE SECOND RUN + THE 5-POINT CHECK (long build-up · VWAP · second run · news · option writers)",
         "3k": "ALL AGREE, THE OPTION WRITERS TOO - the +3% entries with the writers and the room to the wall"}
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
        if sec in ("3e", "3f", "3g", "3k", "3l"):
            a[1] += n * int(g[2]) / 100; a[2] += n * int(g[3]) / 100; a[3] += n * float(g[4])
        elif sec == "3h":
            a[1] += n * int(g[2]) / 100; a[3] += n * float(g[3])
        else:
            a[1] += n * int(g[2]) / 100; a[3] += n * float(g[3]); a[4] += n * float(g[4]); a[5] += n * float(g[5])
print("%d days: %s ... %s" % (len(FILES), FILES[0][-14:-4] if FILES else "-", FILES[-1][-14:-4] if FILES else "-"))
for sec in ("3l", "3e", "3k", "3f", "3g", "3h", "3i"):
    if sec not in A:
        continue
    print("\n=== " + TITLE[sec])
    rows = ORD[sec]
    if sec == "3h":
        rows = sorted(rows, key=lambda k: (k[1][:12], -A[sec][k][3] / max(1, A[sec][k][0])))
    for k in rows:
        n, x, y, z, u, v, days = A[sec][k]
        ind = "   " if k[1].startswith("...") else ""
        if sec in ("3e", "3f", "3k", "3l"):
            print("%s%-50s %5d · %s %3.0f%% · %s %3.0f%% · %s %+.2f%%" % (ind, k[1], n, PAT[sec][1][0], 100 * x / n, PAT[sec][1][1], 100 * y / n, PAT[sec][1][2], z / n))
        elif sec == "3g":
            print("%s%-50s %5d · WON %3.0f%% · 2R %3.0f%% · average %+.2fR · total %+.0fR" % (ind, k[1], n, 100 * x / n, 100 * y / n, z / n, z))
        elif sec == "3h":
            print("  %-58s %5d · WON %3.0f%% · avg %+.2f%% on the share" % (k[1], n, 100 * x / n, z / n))
        else:
            print("%s%-50s %5d · WON %3.0f%% · stop 2/target 2 %+.2f%% · held %+.2f%% · half+trail %+.2f%%" % (ind, k[1], n, 100 * x / n, z / n, u / n, v / n))


# ---------------- THE SHARE PROFILE: which share, which setup, which market ----------------
P = []
for f in FILES:
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("PROFILE|"):
            x = ln.rstrip("\n").split("|")
            if len(x) >= 8:
                P.append({"day": x[1], "reg": x[2], "s": x[3], "sec": x[4], "set": x[5], "side": x[6], "r": float(x[7]), "f": x[8] if len(x) > 8 else ""})
if P:
    def agg(L):
        return len(L), 100 * sum(1 for e in L if e["r"] > 0) / len(L), sum(e["r"] for e in L) / len(L)
    print("\n=== EVERY SETUP x THE MARKET KIND (%d trades, %d days) - avg %% on the share a trade (stop 2%% / target 2%%)" % (len(P), len({e['day'] for e in P})))
    sets = sorted({e["set"] for e in P})
    regs = ["rising", "falling", "choppy", "flat"]
    print("  %-34s %s" % ("setup", "".join("%-22s" % r for r in ["ALL DAYS"] + regs)))
    for st in sets:
        for side in ("CE", "PE"):
            cells = []
            for r in [None] + regs:
                L = [e for e in P if e["set"] == st and e["side"] == side and (r is None or e["reg"] == r)]
                cells.append(("%3d · %+.2f%% · W%2.0f%%" % (len(L), agg(L)[2], agg(L)[1])) if len(L) >= 5 else "-")
            print("  %-34s %s" % (st + " " + side, "".join("%-22s" % c for c in cells)))
    print("\n=== EACH SHARE'S OWN BEST SETUP (3+ trades of that setup, the average above 0.3%) - the link: which share, which setup")
    best = []
    for sym in sorted({e["s"] for e in P}):
        rows = []
        for st in sets:
            for side in ("CE", "PE"):
                L = [e for e in P if e["s"] == sym and e["set"] == st and e["side"] == side]
                if len(L) >= 3:
                    n, w, a = agg(L); rows.append((a, n, w, st + " " + side))
        if rows:
            rows.sort(reverse=True)
            if rows[0][0] >= 0.3:
                best.append((rows[0], rows[-1], sym, P[[e["s"] for e in P].index(sym)]["sec"]))
    for (a, n, w, nm), worst, sym, sec in sorted(best, key=lambda x: -x[0][0])[:60]:
        print("  %-11s %-16s BEST: %-40s %2d trades · avg %+.2f%% · won %3.0f%%   avoid: %s (%+.2f%%)" % (sym, sec[:16], nm, n, a, w, worst[3], worst[0]))
    print("\n=== EACH SECTOR'S BEST SETUP (10+ trades)")
    for sec in sorted({e["sec"] for e in P}):
        rows = []
        for st in sets:
            for side in ("CE", "PE"):
                L = [e for e in P if e["sec"] == sec and e["set"] == st and e["side"] == side]
                if len(L) >= 10:
                    n, w, a = agg(L); rows.append((a, n, w, st + " " + side))
        if rows:
            rows.sort(reverse=True)
            print("  %-22s best: %-40s %3d · %+.2f%% · won %3.0f%%   worst: %s %+.2f%%" % (sec[:22], rows[0][3], rows[0][1], rows[0][0], rows[0][2], rows[-1][3], rows[-1][0]))
    print("\nREAD: a share's 'best' needs to hold on NEW days before trusting it - 30 days give each share only a few trades. Sector rows are steadier.")

# ---------------- WINNERS vs LOSERS (Rama, 14 Nov: "in every test some went up and some went down - check those shares, why, on what basis") ----------------
FN = {"R": "results today / last evening", "S": "its sector with it today", "N": "NIFTY with it today", "V": "volume 2x its normal so far",
      "M": "new futures money (long / short build-up)", "C": "money LEAVING (short covering / long unwinding)",
      "H": "news or a filing in the 2 hours before", "O": "the option writers back it", "W": "on its side of VWAP", "G": "gapped its way 1%+", "E": "before 10:00",
      "X": "THE 3 TOGETHER (sector + money + volume)"}
if P and any(e["f"] for e in P):
    print("\n=== WINNERS vs LOSERS - for each setup, what was there when it WON vs when it LOST (how often, and how much more often)")
    for st in sets:
        for side in ("CE", "PE"):
            L = [e for e in P if e["set"] == st and e["side"] == side and e["f"]]
            Wn = [e for e in L if e["r"] > 0.3]; Ls = [e for e in L if e["r"] < -0.3]
            if len(Wn) < 5 or len(Ls) < 5:
                continue
            rows = []
            for k, nm in FN.items():
                a = sum(1 for e in Wn if k in e["f"]) / len(Wn); b = sum(1 for e in Ls if k in e["f"]) / len(Ls)
                rows.append(((a + 0.02) / (b + 0.02), a, b, nm))
            rows.sort(reverse=True)
            print("  %s %s - %d won · %d lost:" % (st, side, len(Wn), len(Ls)))
            for lift, a, b, nm in rows:
                tag = "  ◀ helps" if lift >= 1.5 and a >= 0.15 else ("  ◀ hurts" if lift <= 0.67 and b >= 0.15 else "")
                print("     %-46s won %3.0f%% · lost %3.0f%% · %.1fx%s" % (nm, 100 * a, 100 * b, lift, tag))
    print("\n=== THE SHARES THAT WON MOST and LOST MOST (every setup) - day · market · what was there")
    srt = sorted([e for e in P if e["f"]], key=lambda e: -e["r"])
    lab = lambda e: " ".join(FN[k].split(" (")[0].split(" today")[0] for k in e["f"] if k in FN and k != "X") or "nothing"
    for e in srt[:15]:
        print("  WON  %+5.1f%%  %s %-11s %-32s %s · %s" % (e["r"], e["day"][5:], e["s"], e["set"] + " " + e["side"], e["reg"], lab(e)))
    for e in srt[-15:]:
        print("  LOST %+5.1f%%  %s %-11s %-32s %s · %s" % (e["r"], e["day"][5:], e["s"], e["set"] + " " + e["side"], e["reg"], lab(e)))
    print("READ: '◀ helps' = seen far more when it won - the rule to add · '◀ hurts' = seen more when it lost - the rule to avoid.")

# ---------------- CHECKS 4 / 5 / 6 (Rama, 14 Nov: "yes add checks 4, 5 and 6") ----------------
# 4 COSTS: brokerage, STT, exchange fees, GST, stamp + the bid-ask spread + an hour of time decay ≈ 2% of the premium a round trip. An at / 1-in-the-money
#   option with 11+ days moves about 10x the share in %, so 2% of the premium ≈ 0.20% on the share. Estimates - real premiums are saved from Monday.
# 5 OLD vs NEW: the first half of the days finds the rules, the second half checks them (a rule that only works where it was found is luck)
# 6 LOSING STREAKS: the longest run of losses in a row, the worst day, the deepest fall from a high - what your size must survive
COST, LEV = 0.20, 10.0
if P:
    days = sorted({e["day"] for e in P})
    half = days[len(days) // 2] if days else ""
    def st_(L):
        n = len(L); net = [e["r"] - COST for e in L]
        return n, (100 * sum(1 for x in net if x > 0) / n) if n else 0, (sum(net) / n) if n else 0
    print("\n=== CHECK 4 · AFTER COSTS (≈ %.2f%% on the share a trade = ~2%% of the premium) · CHECK 5 · OLD %s..%s vs NEW %s..%s" % (
        COST, days[0][5:] if days else "-", (days[len(days) // 2 - 1][5:] if len(days) > 1 else "-"), half[5:], days[-1][5:] if days else "-"))
    print("  %-38s %-36s %-36s %-36s" % ("setup", "ALL: trades · won · avg after costs", "OLD days", "NEW days"))
    ranked = []
    for st in sets:
        for side in ("CE", "PE"):
            L = [e for e in P if e["set"] == st and e["side"] == side]
            if len(L) < 15:
                continue
            o = [e for e in L if e["day"] < half]; nw = [e for e in L if e["day"] >= half]
            a, b, c = st_(L), st_(o), st_(nw)
            ranked.append((c[2] if c[0] >= 8 else -9, st + " " + side))
            f = lambda x: ("%4d · W%3.0f%% · %+.2f%% (%+.0f%% prem)" % (x[0], x[1], x[2], x[2] * LEV)) if x[0] else "-"
            hold = "  ✅ holds on new days" if (b[0] >= 8 and c[0] >= 8 and b[2] > 0 and c[2] > 0) else ("  ❌ only old days" if (b[2] > 0 and c[0] >= 8 and c[2] <= 0) else "")
            print("  %-38s %-36s %-36s %-36s%s" % (st + " " + side, f(a), f(b), f(c), hold))
    # the filters found on the OLD days, checked on the NEW days
    if any(e["f"] for e in P):
        print("\n=== CHECK 5b · THE FILTERS ('◀ helps' found on the OLD days) - do they still help on the NEW days?")
        for st in sets:
            for side in ("CE", "PE"):
                L = [e for e in P if e["set"] == st and e["side"] == side and e["f"]]
                o = [e for e in L if e["day"] < half]; nw = [e for e in L if e["day"] >= half]
                ow = [e for e in o if e["r"] > 0.3]; ol = [e for e in o if e["r"] < -0.3]
                if len(ow) < 5 or len(ol) < 5 or len(nw) < 10:
                    continue
                helps = [k for k in FN if k != "X" and (sum(1 for e in ow if k in e["f"]) / len(ow) + 0.02) / (sum(1 for e in ol if k in e["f"]) / len(ol) + 0.02) >= 1.5
                         and sum(1 for e in ow if k in e["f"]) / len(ow) >= 0.15]
                if not helps:
                    continue
                w_ = [e for e in nw if any(k in e["f"] for k in helps)]; wo = [e for e in nw if not any(k in e["f"] for k in helps)]
                if len(w_) >= 5 and len(wo) >= 5:
                    a, b = st_(w_), st_(wo)
                    print("  %-36s filters: %-40s NEW days WITH them %3d · %+.2f%% · W%2.0f%%  |  WITHOUT %3d · %+.2f%%%s" % (
                        st + " " + side, ", ".join(FN[k].split(" (")[0].split(" today")[0] for k in helps)[:40], a[0], a[2], a[1], b[0], b[2],
                        "  ✅ the filter works" if a[2] > b[2] and a[2] > 0 else "  ❌ not on new days"))
    # 6 losing streaks
    print("\n=== CHECK 6 · LOSING STREAKS (after costs) - the longest run of losses, the worst day, the deepest fall from a high, in % on the share")
    for _, nm in sorted(ranked, reverse=True)[:10]:
        st, side = nm.rsplit(" ", 1)
        L = [e for e in P if e["set"] == st and e["side"] == side]
        run = mx = 0; cum = peak = dd = 0.0; byday = {}
        for e in L:
            x = e["r"] - COST
            run = run + 1 if x < 0 else 0; mx = max(mx, run)
            cum += x; peak = max(peak, cum); dd = min(dd, cum - peak)
            byday[e["day"]] = byday.get(e["day"], 0.0) + x
        lose_days = sum(1 for v in byday.values() if v < 0)
        print("  %-38s %4d trades · total %+.1f%% · longest losing run %2d · worst day %+.1f%% · deepest fall %+.1f%% · losing days %d of %d" % (
            nm, len(L), cum, mx, min(byday.values()), dd, lose_days, len(byday)))
    print("READ: trade a setup only if it is ✅ on the NEW days after costs, and size it so its deepest fall and longest losing run would not hurt you.")

# ---------------- 🧲 STEADY MOVE, every exit, all days (fastreplay 3n) ----------------
SA, SO = {}, []
for f in FILES:
    sec_, par = False, ""
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("=== 3n"):
            sec_ = True; continue
        if sec_ and ln.startswith("=== "):
            sec_ = False
        if not sec_:
            continue
        m = re.match(r"\s+(.+?)\s+(\d+) · exits after costs: (.+?) · best:", ln)
        if not m:
            continue
        nm = m.group(1).strip(); n = int(m.group(2))
        if not nm.startswith("..."):
            par = nm
        k = (par, nm) if nm.startswith("...") else ("", nm)
        ex = {int(a): float(b) for a, b in re.findall(r"(\d) ([+-][\d.]+)%", m.group(3))}
        a = SA.setdefault(k, [0, {}])
        if k not in SO:
            SO.append(k)
        a[0] += n
        for e_, v in ex.items():
            a[1][e_] = a[1].get(e_, 0.0) + n * v
if SA:
    print("\n=== 🧲 STEADY MOVE - all days, avg % on the share a trade AFTER costs, by exit (1 stop1/trail0.75 · 2 stop1.5/trail1 · 3 stop1/trail1.5 · 4 stop1/hold 15:20 · 5 VWAP cross · 6 half+1%, trail0.75)")
    for k in SO:
        n, ex = SA[k]
        best = max(ex, key=lambda e_: ex[e_]) if ex else None
        print("%s%-48s %5d · %s · best exit %s %+.2f%% (≈%+.0f%% on the premium)" % ("   " if k[1].startswith("...") else "  ", k[1][:48], n,
              " · ".join("%d %+.2f%%" % (e_, ex[e_] / n) for e_ in sorted(ex)), best, ex[best] / n if best else 0, 10 * ex[best] / n if best else 0))


# ---------------- THE SETTINGS GRID, all days (fastreplay 3o): every steady / burst setting, both ways, ranked ----------------
GA = {}
for f in FILES:
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("GRID|"):
            x = ln.rstrip("\n").split("|")
            if len(x) != 9:
                continue
            k = (x[2], x[3], x[4], x[5]); n = int(x[6]); su = [float(v) for v in x[7].split(",")]; wi = [int(v) for v in x[8].split(",")]
            a = GA.setdefault(k, [0, [0.0] * len(su), [0] * len(wi)])
            a[0] += n
            for j in range(len(su)):
                a[1][j] += su[j]; a[2][j] += wi[j]
if GA:
    EXL = ["t stop2/target2", "a stop1/trail0.75", "b stop1.5/trail1", "h half+1%/trail0.75"]
    print("\n=== THE SETTINGS GRID - all days, after costs (avg % on the share a trade · won) - the best exit for each setting; ≈10x on an at-the-money premium")
    for kind in ("STEADY", "BURST"):
        for side in ("CE", "PE"):
            for tag in ("all", "early"):
                rows = []
                for (k_, s_, nm, t_), (n, su, wi) in GA.items():
                    if k_ == kind and s_ == side and t_ == tag and n >= 20:
                        j = max(range(len(su)), key=lambda q: su[q])
                        rows.append((su[j] / n, n, 100 * wi[j] / n, nm, EXL[j]))
                if not rows:
                    continue
                rows.sort(reverse=True)
                print("  %s %s%s - best 6 settings of %d (and the worst):" % (kind, side, " · entered before 11:00" if tag == "early" else "", len(rows)))
                for avg, n, w, nm, ex in rows[:6] + rows[-1:]:
                    print("     %-56s %5d trades · %+.2f%% (≈%+.0f%% premium) · won %3.0f%% · exit %s" % (nm, n, avg, 10 * avg, w, ex))
