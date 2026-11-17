#!/usr/bin/env python3
"""newslag.py - READ ONLY. HOW LATE IS GIR'S NEWS, AND WHERE DOES THE TIME GO? (Rama, 17 Nov: "find news faster" - LAURUSLABS: Moneycontrol
12:26, CNBC 12:42, GIR's AI alert 12:47). Before changing the news scouts, measure them. news.db keeps, for every story, when it was
PUBLISHED (t_pub) and when GIR first SAW it (t_seen); tomorrow.db keeps when the alert went out. For the last N days (default 7):
  1 FOUND HOW LATE   published -> seen, by the way GIR found it (WIRE = the business wires' feeds every minute, GOOGLE NEWS = the
                     share-by-share search, EXCHANGE = NSE filings), market hours and outside, middle / 3 in 4 / 9 in 10 of the stories
  2 BY SOURCE        the same by the publisher (Moneycontrol, ET, CNBC-TV18 ...), the 15 that bring the most stories
  3 WHO FINDS FIRST  a story GIR found from two ways: which way saw it first, and by how many minutes
  4 SEEN -> ALERT    seen -> the alert went out (the AI's reading, the checks); and how many important stories got no alert at all
  5 THE PRICE        for stories with a direction in market hours: the share's move in the 30 minutes BEFORE it was published, between
                     publishing and GIR seeing it, and the 30 minutes AFTER GIR saw it (Kite's 5-minute prices kept in data/secstudy) -
                     how much of the move is gone before GIR knows
Orders nothing, sends nothing, no Kite call.   cd /home/globalbot/intraday && nice -n 15 python3 newslag.py [days]"""
import os, re, sys, json, time, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
L = []


def say(s=""):
    L.append(s); print(s, flush=True)


def q(v, p):
    return float(np.percentile(v, p)) if len(v) else float("nan")


def ist(ts):
    return dt.datetime.fromtimestamp(ts, IST)


def mkt(ts):
    t = ist(ts)
    return t.weekday() < 5 and "09:15" <= t.strftime("%H:%M") <= "15:30"


def line(name, v):
    v = [x for x in v if x == x]
    if not v:
        return "%-26s none" % name
    return "%-26s %5d stories │ middle %5.1f min · 3 in 4 within %5.1f · 9 in 10 within %6.1f · over 30 min: %3.0f%%" % (
        name, len(v), q(v, 50), q(v, 75), q(v, 90), 100.0 * sum(1 for x in v if x > 30) / len(v))


def words(h):
    STOP = set("with from that this will after over into than then them they their there here about which while where would could should "
               "shares share stock stocks price prices today news crore rupees worth says said amid against between".split())
    return set(x[:-1] if x.endswith("s") else x for x in re.findall(r"[a-z0-9]+", (h or "").lower()) if len(x) > 3 and x not in STOP)


def prices():
    """{sym: {day ordinal: closes[72]}} from data/secstudy (5-minute bars from 09:15)"""
    C = os.path.join(D, "data", "secstudy"); best = {}; out = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    for k, (_, f) in best.items():
        try:
            A = np.load(os.path.join(C, f))
        except Exception:
            continue
        d_ = {}
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            cl = np.full(76, np.nan)
            for row in p:
                b = int(row[1]) // 5
                if 0 <= b < 76:
                    cl[b] = row[5]
            for b in range(1, 76):
                if cl[b] != cl[b]:
                    cl[b] = cl[b - 1]
            d_[int(p[0, 0])] = cl
        out[k] = d_
    return out


def px_at(P, sym, ts):
    """the share's price at that moment (the last 5-minute close before it), or None"""
    t = ist(ts); d_ = P.get(re.sub(r"[^A-Z0-9]", "_", sym), {}).get(t.toordinal())
    if d_ is None:
        return None
    b = (t.hour * 60 + t.minute - 555) // 5 - 1                  # the bar that has CLOSED by then
    if b < 0:
        return None
    b = min(b, 75)
    v = d_[b]
    return float(v) if v == v else None


def main():
    days = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 7
    since = time.time() - days * 86400
    try:
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=10)
        R = con.execute("select sym, src, domain, t_pub, t_seen, h, side, kind, score from items where t_seen>? order by t_seen", (since,)).fetchall()
        con.close()
    except Exception as ex:
        say("❌ news.db not read: %s" % ex); return
    say("📊 HOW LATE IS GIR'S NEWS? · the last %d days · %d stories in news.db" % (days, len(R)))
    say("  'late' = minutes from the publisher's own time to GIR first seeing it (a publisher's clock a minute off shows as 0)")
    R = [r for r in R if r[3] and r[4] and r[4] - r[3] > -600]
    lag = lambda r: max(0.0, (r[4] - r[3]) / 60.0)
    say(""); say("1 FOUND HOW LATE - by the way GIR found it")
    for src in sorted({r[1] for r in R}, key=lambda s: -sum(1 for r in R if r[1] == s)):
        X = [r for r in R if r[1] == src]
        say("  " + line(src + " · market hours", [lag(r) for r in X if mkt(r[3])]))
        say("  " + line(src + " · outside", [lag(r) for r in X if not mkt(r[3])]))
    imp = [r for r in R if (r[8] or 0) >= 60 and r[6]]
    say("  " + line("IMPORTANT (score 60+, a side)", [lag(r) for r in imp if mkt(r[3])]) + "  ← market hours")
    say(""); say("2 BY PUBLISHER - market hours, the 15 bringing the most stories")
    MH = [r for r in R if mkt(r[3])]
    doms = sorted({r[2] for r in MH}, key=lambda d_: -sum(1 for r in MH if r[2] == d_))[:15]
    for d_ in doms:
        X = [r for r in MH if r[2] == d_]
        by = {}
        for r in X:
            by[r[1]] = by.get(r[1], 0) + 1
        say("  " + line((d_ or "?")[:26], [lag(r) for r in X]) + "  (" + ", ".join("%s %d" % kv for kv in sorted(by.items(), key=lambda kv: -kv[1])) + ")")
    say(""); say("3 WHO FINDS FIRST - the same story reached by two ways (same share, most words in common, within 6 hours)")
    pairs = {}
    by_sym = {}
    for r in R:
        by_sym.setdefault(r[0], []).append(r)
    for sym, X in by_sym.items():                            # each story counted once: its earliest copy from ANOTHER way
        nm = words(sym); W_ = [words(x[5]) - nm for x in X]
        for j in range(len(X)):
            b, wj, first = X[j], W_[j], None
            for i in range(j):
                a, wi = X[i], W_[i]
                if a[1] == b[1] or b[4] - a[4] > 6 * 3600:
                    continue
                both = wi & wj
                if len(both) >= 2 and wi and wj and len(both) / min(len(wi), len(wj)) >= 0.5:
                    first = a; break
            if first is not None:
                pairs.setdefault((first[1], b[1]), []).append((b[4] - first[4]) / 60.0)
    if not pairs:
        say("  no story reached by two ways")
    for (f_, s_), v in sorted(pairs.items(), key=lambda kv: -len(kv[1])):
        say("  %-12s first, %-12s later: %4d stories │ later by: middle %5.1f min · 3 in 4 within %5.1f" % (f_, s_, len(v), q(v, 50), q(v, 75)))
    say(""); say("4 SEEN -> ALERT - the alert's time after GIR saw the story (the share's 📰 / 🚨 / 📄 alert with that headline, within 60 min)")
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
        A = c.execute("select day, t, kind, sym, text from alerts where day>=? and kind in ('📰','🚨','📄')", (str(ist(since).date()),)).fetchall(); c.close()
    except Exception as ex:
        A = []; say("  tomorrow.db not read: %s" % ex)
    AL = {}
    for day, t, kind, sym, text in A:
        try:
            ts = dt.datetime.combine(dt.date.fromisoformat(day), dt.time.fromisoformat(str(t)[:8]), IST).timestamp()
        except Exception:
            continue
        ln = [x for x in str(text or "").split("\n") if x.strip()]
        AL.setdefault(sym, []).append((ts, ln[1] if len(ln) > 1 else "", kind))
    got, miss, dl = 0, 0, []
    for r in imp:
        if not mkt(r[3]):
            continue
        w = words(r[5]) - words(r[0])
        hit = None
        for ts, h, k in AL.get(r[0], []):
            if r[4] - 120 <= ts <= r[4] + 3600:
                wh = words(h) - words(r[0]); both = w & wh
                if h and (h == r[5] or (len(both) >= 2 and w and wh and len(both) / min(len(w), len(wh)) >= 0.5)):
                    hit = ts; break
        if hit:
            got += 1; dl.append(max(0.0, (hit - r[4]) / 60.0))
        else:
            miss += 1
    say("  " + line("seen -> alert", dl))
    say("  important stories in market hours: %d alerted, %d with no alert of that headline (the same story may have gone out from another source)" % (got, miss))
    say(""); say("5 THE PRICE - stories with a side, score 60+, market hours: the share's move the story's way (Kite 5-minute prices)")
    P = prices()
    if not P:
        say("  no 5-minute prices in data/secstudy")
    else:
        rows = []
        for r in imp:
            if not mkt(r[3]) or not mkt(r[4]):
                continue
            a0, a1, a2, a3 = (px_at(P, r[0], x) for x in (r[3] - 1800, r[3], r[4], r[4] + 1800))
            if None in (a0, a1, a2, a3) or not a0:
                continue
            s = 1 if r[6] > 0 else -1
            rows.append((s * 100 * (a1 / a0 - 1), s * 100 * (a2 / a1 - 1), s * 100 * (a3 / a2 - 1), lag(r), r))
        if not rows:
            say("  no story with prices for all four moments")
        else:
            av = lambda i: float(np.mean([x[i] for x in rows]))
            say("  %d stories │ the 30 min BEFORE it was published %+.2f%% · publishing -> GIR saw it %+.2f%% · the 30 min AFTER GIR saw it %+.2f%%" % (
                len(rows), av(0), av(1), av(2)))
            for nm, f in (("found within 5 min", lambda x: x[3] <= 5), ("found 5-20 min late", lambda x: 5 < x[3] <= 20), ("found 20+ min late", lambda x: x[3] > 20)):
                Z = [x for x in rows if f(x)]
                if Z:
                    say("    %-20s %4d │ before %+.2f%% · while GIR had not seen it %+.2f%% · after %+.2f%%" % (
                        nm, len(Z), np.mean([x[0] for x in Z]), np.mean([x[1] for x in Z]), np.mean([x[2] for x in Z])))
            big = sorted(rows, key=lambda x: -x[1])[:8]
            say("  the stories where the most was lost while GIR had not seen them:")
            for x in big:
                r = x[4]
                say("    %s %-11s pub %s seen %s (%s, %.0f min) · moved %+.2f%% before GIR saw it · %s" % (
                    ist(r[3]).strftime("%d %b"), r[0], ist(r[3]).strftime("%H:%M"), ist(r[4]).strftime("%H:%M"), r[1], x[3], x[1], (r[5] or "")[:70]))
    try:
        open(os.path.join(D, "data", "newslag.txt"), "w").write("\n".join(L) + "\n"); say(""); say("  saved: data/newslag.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
