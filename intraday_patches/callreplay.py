#!/usr/bin/env python3
"""callreplay.py - READ ONLY. GIR'S OWN ALERTS, TRADED (Rama, 16 Nov: "why can't you see today's record - when GIR found the alert, and if it was
allowed to trade, how much could be made").
Every F&O share GIR alerted on today with a side (CE / PE), from the alerts table (tomorrow.db) - as if the alert had been a trade:
  ENTRY   the share's price at the MINUTE of the alert (data/oihist/<day>.npz - GIR's own minute history)
  STOP    2.5% against on the share -> out
  HALF    +1.5% -> half booked, the stop moves to the entry
  REST    out at 15:10
  ₹       1 lot, an at-the-money option ~ half the share's rupee move, before charges (the same money rule as every replay)
Three ways of reading the same record:
  A) the FIRST time GIR alerted the share (any line with CE/PE - even "WATCH, not a trade yet")
  B) the first REAL call (not WATCH / IN DOUBT / WHY / news)
  C) every alert type on its own (🚀 RUNNING, 🔔 OPENING, ⚡, 🚨 ...) - which of GIR's alerts make money and which lose
One trade per share per reading per day. Alerts after 15:00 are not traded.
python3 callreplay.py [YYYY-MM-DD ...]   (no day: every day with a minute history)   -> prints, saves data/callreplay.txt"""
import os, re, sys, glob, sqlite3
D = os.path.dirname(os.path.abspath(__file__)); OD = os.path.join(D, "data", "oihist")
L = []
STOP, HALF, CLOSE_M = 0.025, 0.015, 355          # 355 minutes after 09:15 = 15:10
NOTCALL = re.compile(r"not a trade|IN DOUBT|WATCH,|^\W*WHY\b|^🔍|^🔎|^📰|^📄", re.I)
UP = re.compile(r"^(CE|UP|BUY|LONG|BULL|▲)", re.I); DN = re.compile(r"^(PE|DOWN|SELL|SHORT|BEAR|▼)", re.I)
f0 = lambda x: "{:,.0f}".format(x)
IV, RATE = 0.35, 0.065     # v3: the option is priced (Black-Scholes) - an option does not move in a straight line with the share


def say(s=""):
    L.append(s); print(s)


def lots():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        R = dict(c.execute("select sym, lot from fo_list").fetchall()); c.close(); return R
    except Exception:
        return {}


def prices(day):
    """{sym: [(minute, price)]} sorted - GIR's own minute history"""
    import numpy as np
    z = np.load(os.path.join(OD, day + ".npz")); out = {}
    for s in z.files:
        a = z[s]
        seq = sorted((int(r[0]), float(r[1])) for r in a if float(r[1]) > 0)
        if len(seq) >= 30:
            out[s] = seq
    return out


def sim(seq, P0, dr, st=STOP, hf=HALF):
    """the share's % result: stop 2.5%; at +1.5% half booked and the stop to the entry; the rest out at 15:10"""
    half = None; stop = -st; x = 0.0
    for m, px in seq:
        x = (px / P0 - 1) * dr
        if x <= stop:
            return (stop if half is None else (half + stop) / 2), m, ("STOP" if half is None else "HALF+ENTRY")
        if half is None and x >= hf:
            half, stop = hf, 0.0
        if m >= CLOSE_M:
            return (x if half is None else (half + x) / 2), m, ("15:10" if half is None else "HALF+15:10")
    return (x if half is None else (half + x) / 2), (seq[-1][0] if seq else 0), "LAST"


def bs(S, K, T, dr, v=IV, r=RATE):
    """an option's premium: CE (dr > 0) or PE (dr < 0), T in years"""
    from math import log, sqrt, exp, erf
    N = lambda x: 0.5 * (1 + erf(x / sqrt(2)))
    T = max(T, 0.25 / 365)
    d1 = (log(S / K) + (r + v * v / 2) * T) / (v * sqrt(T)); d2 = d1 - v * sqrt(T)
    return S * N(d1) - K * exp(-r * T) * N(d2) if dr > 0 else K * exp(-r * T) * N(-d2) - S * N(-d1)


def expiries(day):
    """{sym: days to its near-month expiry} from NSE's own futures file (data/nsefut_<day>.json: [oi, chg, close, exp])"""
    import json, datetime as dt
    out = {}
    try:
        J = json.load(open(os.path.join(D, "data", "nsefut_%s.json" % day)))
        d0 = dt.date.fromisoformat(day)
        for s, v in J.items():
            try:
                e = str(v[3])[:11]
                for fmt in ("%Y-%m-%d", "%d-%b-%Y", "%d-%m-%Y"):
                    try:
                        out[s] = max((dt.datetime.strptime(e, fmt).date() - d0).days, 0); break
                    except Exception:
                        pass
            except Exception:
                pass
    except Exception:
        pass
    return out


def option_rs(seq, i, P0, dr, lot, dte, st=STOP, hf=HALF):
    """v3: the same trade in the at-the-money option (strike = the entry price): ₹ for 1 lot - half sold at the half-out, the rest at the exit"""
    if not lot:
        return 0.0
    m0 = seq[i][0]; T0 = (dte + 1 - m0 / 375.0) / 365.0                       # expiry day counted to its close
    p0 = bs(P0, P0, T0, dr); half = None; stop = -st; mx, px = m0, P0
    for m, px in seq[i + 1:]:
        x = (px / P0 - 1) * dr; mx = m
        if x <= stop:
            px = P0 * (1 + dr * stop); break
        if half is None and x >= hf:
            half = (m, P0 * (1 + dr * hf)); stop = 0.0
        if m >= CLOSE_M:
            break
    T = lambda m: (dte + 1 - m / 375.0) / 365.0
    end = bs(px, P0, T(mx), dr) - p0
    if half is None:
        return end * lot
    return (0.5 * (bs(half[1], P0, T(half[0]), dr) - p0) + 0.5 * end) * lot


def label(kind, text):
    """the alert's type: its emoji + its first word in capitals (RUNNING, OPENING, WHY ...)"""
    first = str(text or "").split("\n")[0]
    w = re.search(r"\b([A-Z][A-Z\-]{2,})\b", first)
    k = str(kind or "").strip() or first[:1]
    return ("%s %s" % (k, w.group(1) if w else "")).strip()


def side(v):
    v = str(v or "").strip()
    return 1 if UP.match(v) else -1 if DN.match(v) else 0


def hm(m):
    return "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)


def alerts(day):
    c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
    cols = [r[1] for r in c.execute("pragma table_info(alerts)")]
    kc = "kind" if "kind" in cols else "''"; tc = "text" if "text" in cols else "''"
    R = c.execute("select t, %s, sym, side, %s from alerts where day=? order by t" % (kc, tc), (day,)).fetchall(); c.close()
    out = []
    for t, k, s, sd, tx in R:
        t = str(t or "")
        if not re.match(r"\d\d:\d\d", t) or not s:
            continue
        dr = side(sd)
        if not dr:
            continue
        m = int(t[:2]) * 60 + int(t[3:5]) - 555
        if m < 0 or m > 345:                                                   # before 09:15 or after 15:00
            continue
        mv = re.search(r"([+-]\d+(?:\.\d+)?)%", str(tx or "")); vx = re.search(r"volume\s+(\d+(?:\.\d+)?)x", str(tx or ""))
        out.append({"m": m, "t": t[:8], "s": str(s).upper(), "dir": dr, "lab": label(k, tx), "mv": abs(float(mv.group(1))) if mv else None,
                    "vx": float(vx.group(1)) if vx else None, "call": not NOTCALL.search(str(tx or "").split("\n")[0] + " " + str(tx or "")[:200]),
                    "first": str(tx or "").split("\n")[0][:70]})
    return out


def trade(a, S, LOT, DTE=None):
    seq = S.get(a["s"])
    if not seq:
        return None
    i = next((j for j, (m, _) in enumerate(seq) if m >= a["m"]), None)
    if i is None:
        return None
    m0, P0 = seq[i]
    r, mx, how = sim(seq[i + 1:], P0, a["dir"])
    lot = LOT.get(a["s"]) or 0
    dte = (DTE or {}).get(a["s"], 7)
    return dict(a, px=P0, r=r, out=hm(mx), how=how, lot=lot, rs=r * P0 * lot * 0.5, ro=option_rs(seq, i, P0, a["dir"], lot, dte), dte=dte)


def book(name, T):
    n = len(T); won = sum(1 for x in T if x["r"] > 0); tot = sum(x["rs"] for x in T); to = sum(x["ro"] for x in T)
    say("  %-46s %4d trades · %4d won · %4d lost · ₹%s straight-line · ₹%s AS AN OPTION" % (name, n, won, n - won, f0(tot), f0(to)))
    return tot


def main():
    days = sys.argv[1:] or sorted(os.path.basename(f)[:10] for f in glob.glob(os.path.join(OD, "20??-??-??.npz")))
    LOT = lots()
    for day in days:
        try:
            S = prices(day)
        except Exception as ex:
            say("%s: no minute history (%s)" % (day, ex)); continue
        try:
            A = [a for a in alerts(day) if a["s"] in S and (not LOT or a["s"] in LOT)]
        except Exception as ex:
            say("%s: alerts not readable (%s)" % (day, ex)); continue
        DTE = expiries(day)
        say(""); say("📒 %s · GIR'S OWN ALERTS, TRADED · %d alert lines with CE/PE on %d F&O shares" % (day, len(A), len({a["s"] for a in A})))
        say("  ₹ AS AN OPTION: the at-the-money CE / PE priced at entry, half-out and exit (Black-Scholes, IV %d%%, days to expiry from NSE's futures file: %s)" % (
            IV * 100, ("%d days" % sorted(DTE.values())[len(DTE) // 2]) if DTE else "not found - 7 days used"))
        say("  rule: entry at the alert minute · stop 2.5% · half out +1.5% (stop to entry) · rest out 15:10 · 1 lot, ATM option ~ half the rupee move, before charges")
        say("")
        seen = set(); TA = []
        for a in A:
            if a["s"] not in seen:
                seen.add(a["s"]); x = trade(a, S, LOT, DTE)
                if x:
                    TA.append(x)
        seen = set(); TB = []
        for a in A:
            if a["call"] and a["s"] not in seen:
                seen.add(a["s"]); x = trade(a, S, LOT, DTE)
                if x:
                    TB.append(x)
        book("A) the FIRST alert on each share (any line)", TA)
        book("B) the first REAL call (no WATCH / IN DOUBT)", TB)
        say(""); say("  C) each alert type on its own (its first alert per share):")
        labs = {}
        for a in A:
            labs.setdefault(a["lab"], []).append(a)
        rows = []
        for lab, G in labs.items():
            seen = set(); T = []
            for a in G:
                if a["s"] not in seen:
                    seen.add(a["s"]); x = trade(a, S, LOT, DTE)
                    if x:
                        T.append(x)
            if T:
                rows.append((sum(x["rs"] for x in T), lab, T))
        for tot, lab, T in sorted(rows, key=lambda r: -r[0]):
            won = sum(1 for x in T if x["r"] > 0); to = sum(x["ro"] for x in T)
            say("    %s %-22s %4d trades · %3d won (%2d%%) · ₹%10s · as an option ₹%10s · e.g. \"%s\"" % ("✅" if to > 0 else "❌", lab[:22], len(T), won, round(100 * won / len(T)), f0(tot), f0(to), T[0]["first"][:50]))
        say(""); say("  D) WHICH early alerts to take - only what GIR knew at that minute (A's trades, the first alert on each share; ₹ as an option):")
        def grp(name, key, order):
            G = {}
            for x in TA:
                G.setdefault(key(x), []).append(x)
            say("    by %s:" % name)
            for k in order:
                T = G.get(k) or []
                if T:
                    won = sum(1 for x in T if x["r"] > 0); tot = sum(x["ro"] for x in T)
                    say("      %s %-16s %4d trades · %3d won (%2d%%) · ₹%10s · ₹%s a trade" % ("✅" if tot > 0 else "❌", k, len(T), won, round(100 * won / len(T)), f0(tot), f0(tot / len(T))))
        grp("the time of the alert", lambda x: "09:15-09:20" if x["m"] < 5 else "09:20-09:30" if x["m"] < 15 else "09:30-10:00" if x["m"] < 45 else "10:00-12:00" if x["m"] < 165 else "12:00-15:00",
            ["09:15-09:20", "09:20-09:30", "09:30-10:00", "10:00-12:00", "12:00-15:00"])
        grp("the move when it rang", lambda x: "not in the text" if x["mv"] is None else "under 1%" if x["mv"] < 1 else "1-2%" if x["mv"] < 2 else "2-3%" if x["mv"] < 3 else "3%+",
            ["under 1%", "1-2%", "2-3%", "3%+", "not in the text"])
        grp("the volume when it rang", lambda x: "not in the text" if x["vx"] is None else "under 1x" if x["vx"] < 1 else "1-2x" if x["vx"] < 2 else "2-4x" if x["vx"] < 4 else "4x+",
            ["under 1x", "1-2x", "2-4x", "4x+", "not in the text"])
        grp("the side", lambda x: "CE" if x["dir"] > 0 else "PE", ["CE", "PE"])
        say("    the first N alerts of the day (in time order - what you could really take):")
        TS = sorted(TA, key=lambda x: x["t"])
        for N in (5, 10, 15, 20, 30):
            T = TS[:N]
            if T:
                won = sum(1 for x in T if x["r"] > 0); tot = sum(x["ro"] for x in T)
                say("      %s first %-3d %4d won (%2d%%) · ₹%10s · alert no. %d rang at %s" % ("✅" if tot > 0 else "❌", N, won, round(100 * won / len(T)), f0(tot), len(T), T[-1]["t"][:5]))
        say(""); say("  E) the EXIT settings - the same entries (A, and the OPENING alerts only), other stops and half-outs (₹ as an option):")
        def exits(name, T):
            say("    %s (%d trades):" % (name, len(T)))
            res = []
            for st in (0.01, 0.015, 0.025, 0.035):
                for hf in (0.015, 0.025, 0.035):
                    tot = won = 0
                    for x in T:
                        seq = S[x["s"]]; i = next(j for j, (m, _) in enumerate(seq) if m >= x["m"])
                        r = sim(seq[i + 1:], x["px"], x["dir"], st, hf)[0]; tot += option_rs(seq, i, x["px"], x["dir"], x["lot"], x["dte"], st, hf); won += r > 0
                    res.append((tot, st, hf, won))
            for tot, st, hf, won in sorted(res, reverse=True)[:5]:
                say("      stop %.1f%% · half out +%.1f%% → %3d won · ₹%s%s" % (st * 100, hf * 100, won, f0(tot), "   ← today's card rule" if (st, hf) == (STOP, HALF) else ""))
            now = next(r for r in res if (r[1], r[2]) == (STOP, HALF))
            if now not in sorted(res, reverse=True)[:5]:
                say("      (today's card rule, stop 2.5%% · half +1.5%%: ₹%s)" % f0(now[0]))
        exits("A) the first alert on each share", TA)
        OP = [x for x in TA if "OPENING" in x["lab"]]
        if OP:
            exits("only the OPENING alerts", OP)
        say(""); say("  A) trade by trade (the first alert on each share), biggest ₹ first:")
        for x in sorted(TA, key=lambda x: -x["ro"]):
            say("    %s %-11s %s at ₹%-9s · %-14s → %+5.1f%% · %-10s at %s · lot %-6s · ₹%s · option ₹%s" % (x["t"][:5], x["s"], "CE" if x["dir"] > 0 else "PE",
                "{:,.2f}".format(x["px"]), x["lab"][:14], x["r"] * 100, x["how"], x["out"], x["lot"] or "?", f0(x["rs"]), f0(x["ro"])))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "callreplay.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/callreplay.txt")


if __name__ == "__main__":
    main()
