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


def sim(seq, P0, dr):
    """the share's % result: stop 2.5%; at +1.5% half booked and the stop to the entry; the rest out at 15:10"""
    half = None; stop = -STOP; x = 0.0
    for m, px in seq:
        x = (px / P0 - 1) * dr
        if x <= stop:
            return (stop if half is None else (half + stop) / 2), m, ("STOP" if half is None else "HALF+ENTRY")
        if half is None and x >= HALF:
            half, stop = HALF, 0.0
        if m >= CLOSE_M:
            return (x if half is None else (half + x) / 2), m, ("15:10" if half is None else "HALF+15:10")
    return (x if half is None else (half + x) / 2), (seq[-1][0] if seq else 0), "LAST"


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
        out.append({"m": m, "t": t[:8], "s": str(s).upper(), "dir": dr, "lab": label(k, tx), "call": not NOTCALL.search(str(tx or "").split("\n")[0] + " " + str(tx or "")[:200]),
                    "first": str(tx or "").split("\n")[0][:70]})
    return out


def trade(a, S, LOT):
    seq = S.get(a["s"])
    if not seq:
        return None
    i = next((j for j, (m, _) in enumerate(seq) if m >= a["m"]), None)
    if i is None:
        return None
    m0, P0 = seq[i]
    r, mx, how = sim(seq[i + 1:], P0, a["dir"])
    lot = LOT.get(a["s"]) or 0
    return dict(a, px=P0, r=r, out=hm(mx), how=how, lot=lot, rs=r * P0 * lot * 0.5)


def book(name, T):
    n = len(T); won = sum(1 for x in T if x["r"] > 0); tot = sum(x["rs"] for x in T)
    say("  %-46s %4d trades · %4d won · %4d lost · ₹%s" % (name, n, won, n - won, f0(tot)))
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
        say(""); say("📒 %s · GIR'S OWN ALERTS, TRADED · %d alert lines with CE/PE on %d F&O shares" % (day, len(A), len({a["s"] for a in A})))
        say("  rule: entry at the alert minute · stop 2.5% · half out +1.5% (stop to entry) · rest out 15:10 · 1 lot, ATM option ~ half the rupee move, before charges")
        say("")
        seen = set(); TA = []
        for a in A:
            if a["s"] not in seen:
                seen.add(a["s"]); x = trade(a, S, LOT)
                if x:
                    TA.append(x)
        seen = set(); TB = []
        for a in A:
            if a["call"] and a["s"] not in seen:
                seen.add(a["s"]); x = trade(a, S, LOT)
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
                    seen.add(a["s"]); x = trade(a, S, LOT)
                    if x:
                        T.append(x)
            if T:
                rows.append((sum(x["rs"] for x in T), lab, T))
        for tot, lab, T in sorted(rows, key=lambda r: -r[0]):
            won = sum(1 for x in T if x["r"] > 0)
            say("    %s %-22s %4d trades · %3d won (%2d%%) · ₹%10s · e.g. \"%s\"" % ("✅" if tot > 0 else "❌", lab[:22], len(T), won, round(100 * won / len(T)), f0(tot), T[0]["first"][:60]))
        say(""); say("  A) trade by trade (the first alert on each share), biggest ₹ first:")
        for x in sorted(TA, key=lambda x: -x["rs"]):
            say("    %s %-11s %s at ₹%-9s · %-14s → %+5.1f%% · %-10s at %s · lot %-6s · ₹%s" % (x["t"][:5], x["s"], "CE" if x["dir"] > 0 else "PE",
                "{:,.2f}".format(x["px"]), x["lab"][:14], x["r"] * 100, x["how"], x["out"], x["lot"] or "?", f0(x["rs"])))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "callreplay.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/callreplay.txt")


if __name__ == "__main__":
    main()
