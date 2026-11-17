#!/usr/bin/env python3
"""oiflat.py - READ ONLY. FUTURES OI UP, PRICE FLAT - WHAT COMES AFTER? (Rama, 17 Nov 12:15: HEROMOTOCO futures OI +5.8% with the price
-0.16% - "can you test the OI up price flat pattern").
On the 2 years of NSE's daily F&O files already on this server (data/oistudy.db, table day: each F&O share's close and its futures OI),
every share-day is put in one group by its close-to-close change:
  FLAT BUILD     futures OI +4% or more, the price within ±0.5%     (new longs and new shorts in balance - the pattern asked about)
  LONG BUILD-UP  OI +4% or more, the price +1% or more
  SHORT BUILD-UP OI +4% or more, the price -1% or less
  ALL DAYS       every share-day (the yardstick)
Days within 3 trading days of the futures expiry, or where the series changed (rollover), are left out - OI jumps there for other reasons.
For each group, what the share did over the next 1 / 3 / 5 days, each year on its own:
  1 HOW BIG    the average size of the move (up or down) and how often it was 2%+ / 4%+ - does a flat build come before a bigger move?
  2 WHICH WAY  how often it went up - is a flat build a coin toss?
  3 THE CLUE   for flat builds: does the side follow the 5 days before (the trend), the options (more puts or more calls added that day),
               or the size of the build?
✔ = the same lean in both years, 100+ cases, and a difference of 5+ points from all days (or 0.3%+ in the size of the move).
This is the END-OF-DAY version (NSE's day files); GIR's live screen shows the same thing during the day. Orders nothing, sends nothing.
  cd /home/globalbot/intraday && nice -n 15 python3 oiflat.py      -> prints, saves data/oiflat.txt"""
import os, sys, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []


def say(s=""):
    L.append(s); print(s, flush=True)


def db_path():
    try:
        import core
        return os.path.join(core.DATA, "oistudy.db")
    except Exception:
        return os.path.join(D, "data", "oistudy.db")


def main():
    p = db_path()
    if not os.path.exists(p):
        say("❌ no data/oistudy.db on this server"); return
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=30)
    by = {}
    for d, s, spot, foi, exp, ce, pe in c.execute("select d, sym, spot, foi, exp, ce_oi, pe_oi from day order by sym, d"):
        if spot and foi:
            by.setdefault(s, []).append((d, spot, foi, exp or "", ce or 0, pe or 0))
    c.close()
    say("📊 FUTURES OI UP, PRICE FLAT - WHAT COMES AFTER? · NSE's daily F&O files on this server · %d shares" % len(by))
    R = []
    for s, rs in by.items():
        for i in range(6, len(rs) - 5):
            d, px, oi, ex, ce, pe = rs[i]; d1, px1, oi1, ex1, ce1, pe1 = rs[i - 1]
            if ex != ex1 or not ex or oi1 <= 0 or px1 <= 0:
                continue                                                  # the series changed (rollover) - not a build
            try:
                left = sum(1 for k in range(i + 1, len(rs)) if rs[k][0] <= ex)
            except Exception:
                left = 9
            if left <= 3:
                continue                                                  # the last days before expiry
            dp, do = px / px1 - 1, oi / oi1 - 1
            if do >= 0.04 and abs(dp) <= 0.005:
                g = "FLAT"
            elif do >= 0.04 and dp >= 0.01:
                g = "LB"
            elif do >= 0.04 and dp <= -0.01:
                g = "SB"
            else:
                g = "-"
            f = [rs[i + k][1] / px - 1 for k in (1, 3, 5)]
            tr = px / rs[i - 5][1] - 1
            dce, dpe = ce - ce1, pe - pe1
            R.append({"y": d[:4], "g": g, "f": f, "tr": tr, "do": do, "opt": 1 if dpe > dce and dpe > 0 else -1 if dce > dpe and dce > 0 else 0})
    if len(R) < 1000:
        say("  ❌ only %d share-days - too few" % len(R)); return
    Y = sorted({r["y"] for r in R})
    if len(Y) > 2:                                                        # two halves of the record, by year
        mid = Y[len(Y) // 2]; half = lambda r: "A" if r["y"] < mid else "B"
        rng = lambda a, b: a if a == b else "%s-%s" % (a, b)
        hn = (rng(Y[0], str(int(mid) - 1)), rng(mid, Y[-1]))
    else:
        half = lambda r: "A" if r["y"] == Y[0] else "B"; hn = (Y[0], Y[-1])
    av = lambda v: sum(v) / len(v) if v else float("nan")
    say("  %d share-days · the two halves: %s and %s" % (len(R), hn[0], hn[1]))
    G = [("FLAT BUILD (OI +4%+, price ±0.5%)", lambda r: r["g"] == "FLAT"), ("LONG BUILD-UP (OI +4%+, +1%+)", lambda r: r["g"] == "LB"),
         ("SHORT BUILD-UP (OI +4%+, -1%-)", lambda r: r["g"] == "SB"), ("ALL DAYS", lambda r: True)]
    base = {h: [r for r in R if half(r) == h] for h in "AB"}
    say(""); say("1 HOW BIG IS THE NEXT MOVE? (either way) - the average size, and how often 2%+ / 4%+")
    for k, kn in ((0, "next day"), (1, "3 days"), (2, "5 days")):
        say("  %s:" % kn)
        for nm, f in G:
            X = [r for r in R if f(r)]
            if len(X) < 30:
                say("    %-36s %6d cases - too few" % (nm, len(X))); continue
            sz = lambda Z: av([abs(r["f"][k]) for r in Z]); b2 = lambda Z, t: 100 * av([1 if abs(r["f"][k]) >= t else 0 for r in Z])
            hA, hB = [r for r in X if half(r) == "A"], [r for r in X if half(r) == "B"]
            dA, dB = sz(hA) - sz(base["A"]), sz(hB) - sz(base["B"])
            ok = nm != "ALL DAYS" and len(X) >= 100 and dA * dB > 0 and min(abs(dA), abs(dB)) >= 0.003
            say("    %-36s %6d cases │ size %.2f%% (halves %.2f%% / %.2f%%) │ 2%%+ %2.0f%% · 4%%+ %2.0f%% %s" % (
                nm, len(X), 100 * sz(X), 100 * sz(hA), 100 * sz(hB), b2(X, 0.02), b2(X, 0.04), ("✔ bigger" if dA > 0 else "✔ smaller") if ok else ""))
    say(""); say("2 WHICH WAY? - how often the share was higher after (and the average move)")
    for k, kn in ((0, "next day"), (1, "3 days"), (2, "5 days")):
        say("  %s:" % kn)
        bu = {h: 100 * av([1 if r["f"][k] > 0 else 0 for r in base[h]]) for h in "AB"}
        for nm, f in G:
            X = [r for r in R if f(r)]
            if len(X) < 30:
                continue
            up = lambda Z: 100 * av([1 if r["f"][k] > 0 else 0 for r in Z])
            hA, hB = [r for r in X if half(r) == "A"], [r for r in X if half(r) == "B"]
            dA, dB = up(hA) - bu["A"], up(hB) - bu["B"]
            ok = nm != "ALL DAYS" and len(X) >= 100 and dA * dB > 0 and min(abs(dA), abs(dB)) >= 5
            say("    %-36s %6d cases │ up %2.0f%% of the time (halves %2.0f%% / %2.0f%%) │ average %+.2f%% %s" % (
                nm, len(X), up(X), up(hA), up(hB), 100 * av([r["f"][k] for r in X]), ("✔ leans UP" if dA > 0 else "✔ leans DOWN") if ok else ""))
    F = [r for r in R if r["g"] == "FLAT"]
    say(""); say("3 FLAT BUILDS - DOES ANYTHING TELL THE SIDE? (up %% of the time over the next 3 days · all flat builds: %.0f%%)" % (100 * av([1 if r["f"][1] > 0 else 0 for r in F])))
    for nm, f in (("after 5 days UP (2%+)", lambda r: r["tr"] >= 0.02), ("after 5 days DOWN (2%+)", lambda r: r["tr"] <= -0.02), ("after 5 flat days", lambda r: abs(r["tr"]) < 0.02),
                  ("more PUTS added that day", lambda r: r["opt"] > 0), ("more CALLS added that day", lambda r: r["opt"] < 0),
                  ("a big build (OI +8%+)", lambda r: r["do"] >= 0.08), ("a smaller build (OI +4-8%)", lambda r: r["do"] < 0.08)):
        X = [r for r in F if f(r)]
        if len(X) < 30:
            say("    %-30s %5d cases - too few" % (nm, len(X))); continue
        up = lambda Z: 100 * av([1 if r["f"][1] > 0 else 0 for r in Z]) if Z else float("nan")
        hA, hB = [r for r in X if half(r) == "A"], [r for r in X if half(r) == "B"]
        allA, allB = up([r for r in F if half(r) == "A"]), up([r for r in F if half(r) == "B"])
        dA, dB = up(hA) - allA, up(hB) - allB
        ok = len(X) >= 100 and dA * dB > 0 and min(abs(dA), abs(dB)) >= 5
        say("    %-30s %5d cases │ up %2.0f%% over 3 days (halves %2.0f%% / %2.0f%%) · average %+.2f%% %s" % (
            nm, len(X), up(X), up(hA), up(hB), 100 * av([r["f"][1] for r in X]), ("✔ leans UP" if dA > 0 else "✔ leans DOWN") if ok else ""))
    try:
        open(os.path.join(D, "data", "oiflat.txt"), "w").write("\n".join(L) + "\n"); say("  saved: data/oiflat.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
