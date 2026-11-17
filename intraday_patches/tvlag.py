#!/usr/bin/env python3
"""tvlag.py - READ ONLY. WAS CNBC-TV18 FIRST? (Rama, 17 Nov 18:50, on newslag: "we need to find the news before the market reacts - Google is
of no use. Check when the news was said live on CNBC TV, and when the market reacted"). GIR's TV watcher (patch 162, gir-tvwatch) writes
every 20-second piece of CNBC-TV18's speech to data/tv.db (kept 10 days). This lines up, for the days it holds:
  0 THE WATCHER    how many minutes of speech each day, the first and last time - if it is empty, the watcher was not running
  1 THE BIG MOVES  every F&O share's sharp move in market hours (1.5%+ within 15 minutes, Kite's 5-minute prices in data/secstudy):
                   when the move STARTED, and the first time CNBC-TV18 said the company's name in the 60 minutes before the start or
                   the 15 after - TV FIRST (before the move), TV WITH IT (within 15 min after), or NOT ON TV
  2 THE STORIES    the important stories (news.db, score 60+, a direction, market hours): CNBC's first mention of the company in the
                   3 hours before publishing, against the price's reaction, the publishing time and when GIR saw it
  3 THE CASES      the moves where TV was ahead, with the words heard, so the reading can be checked by eye
Orders nothing, sends nothing, no Kite call.   cd /home/globalbot/intraday && nice -n 15 python3 tvlag.py"""
import os, re, sys, json, time, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
L = []
COMMON = {"the", "ltd", "limited", "of", "and", "co", "company", "industries", "corporation", "india", "indian", "bank", "national", "power",
          "oil", "gas", "steel", "state", "general", "life", "new", "first", "global", "united", "city", "home", "one", "data", "info", "max",
          "bharat", "hindustan", "small", "great", "central", "union", "insurance", "finance", "financial", "services", "technologies", "tech",
          "motors", "energy", "infra", "enterprises", "holdings", "international", "labs", "laboratories", "pharma", "pharmaceuticals"}


def say(s=""):
    L.append(s); print(s, flush=True)


def ist(ts):
    return dt.datetime.fromtimestamp(ts, IST)


def mkt(ts):
    t = ist(ts)
    return t.weekday() < 5 and "09:15" <= t.strftime("%H:%M") <= "15:30"


def name_rx(sym, name):
    """how a company is SAID on air: its distinctive name word(s), or the symbol said as a word"""
    w = [x for x in re.findall(r"[A-Za-z][A-Za-z&'\-]+", name or "")]
    key = [x for x in w if x.lower() not in COMMON]
    alts = []
    if w and key:
        alts.append(r"\s+".join(re.escape(x) for x in w[:2]) if w[0].lower() in COMMON else re.escape(key[0]))
    if len(sym) >= 4 and sym.isalpha():
        alts.append(re.escape(sym))
    alts = [a for a in alts if len(a.replace("\\", "")) >= 4]
    return re.compile(r"(?<![A-Za-z])(?:%s)(?![A-Za-z])" % "|".join(alts), re.I) if alts else None


def prices():
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
            cl = np.full(75, np.nan)
            for row in p:
                b = int(row[1]) // 5
                if 0 <= b < 75:
                    cl[b] = row[5]
            for b in range(1, 75):
                if cl[b] != cl[b]:
                    cl[b] = cl[b - 1]
            d_[int(p[0, 0])] = cl
        out[k] = d_
    return out


def bar_ts(day_ord, b):
    """the time the 5-minute bar b CLOSES"""
    return dt.datetime.combine(dt.date.fromordinal(day_ord), dt.time(9, 15), IST).timestamp() + 300 * (b + 1)


def main():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "tv.db"), uri=True, timeout=10)
        TV = c.execute("select ts, ch, text from tv order by ts").fetchall(); c.close()
    except Exception as ex:
        say("❌ data/tv.db not read (%s) - the TV watcher has not written anything; is gir-tvwatch installed and running?" % ex); return
    say("📺 WAS CNBC-TV18 FIRST? · %d pieces of speech in data/tv.db" % len(TV))
    say(""); say("0 THE WATCHER - speech heard per day (each piece about 20 s)")
    byd = {}
    for ts, ch, tx in TV:
        byd.setdefault(ist(ts).date(), []).append((ts, ch, tx or ""))
    for d_, X in sorted(byd.items()):
        words = sum(len(x[2].split()) for x in X)
        say("  %s %s · %4d pieces (~%3.0f min of speech) · %6d words · %s to %s · %s" % (d_.strftime("%a %d %b"), "" if d_.weekday() < 5 else "(weekend)", len(X),
            len(X) * 20 / 60.0, words, ist(X[0][0]).strftime("%H:%M"), ist(X[-1][0]).strftime("%H:%M"), ", ".join(sorted({x[1] for x in X}))))
    if not TV:
        say("  nothing heard - the TV watcher was not running (or YouTube refused it). Nothing more to measure."); return
    tv_days = {d_.toordinal() for d_ in byd}
    try:
        import seclive as SL
        _, NM = SL.universe(); FO = SL.fo_set()
    except Exception as ex:
        say("❌ the share names (seclive) not read: %s" % ex); return
    RX = {s: name_rx(s, NM.get(s, "")) for s in FO}
    RX = {s: r for s, r in RX.items() if r}

    def first_said(sym, a, b):
        r = RX.get(sym)
        if not r:
            return None, ""
        for ts, ch, tx in TV:
            if ts < a:
                continue
            if ts > b:
                break
            m = r.search(tx or "")
            if m:
                i = m.start()
                return ts, (tx or "")[max(0, i - 80): i + 160].replace("\n", " ")
        return None, ""
    P = prices()
    say(""); say("1 THE BIG MOVES - an F&O share 1.5%+ within 15 minutes (market hours, the days the TV watcher heard)")
    if not P:
        say("  no 5-minute prices in data/secstudy")
    MV = []
    for s in FO:
        for d_, cl in P.get(re.sub(r"[^A-Z0-9]", "_", s), {}).items():
            if d_ not in tv_days:
                continue
            b = 3; last = -99
            while b < 75:
                if cl[b] == cl[b] and cl[b - 3] == cl[b - 3] and cl[b - 3] > 0:
                    m = cl[b] / cl[b - 3] - 1
                    if abs(m) >= 0.015 and b - last > 12:
                        st = b - 3                                   # the move started after this bar closed
                        MV.append((s, d_, bar_ts(d_, st), 100 * m)); last = b; b += 12; continue
                b += 1
    cnt = {"TV FIRST": 0, "TV WITH IT": 0, "NOT ON TV": 0}; ahead = []; CASES = []
    for s, d_, t0, m in MV:
        ts, ctx = first_said(s, t0 - 3600, t0 + 900)
        k = "NOT ON TV" if ts is None else "TV FIRST" if ts < t0 else "TV WITH IT"
        cnt[k] += 1
        if ts is not None and ts < t0:
            ahead.append((t0 - ts) / 60.0); CASES.append((s, d_, t0, m, ts, ctx))
    n = max(1, len(MV))
    say("  %d sharp moves │ TV FIRST (said in the hour before) %d (%.0f%%) · TV WITH IT (within 15 min after) %d (%.0f%%) · NOT ON TV %d (%.0f%%)" % (
        len(MV), cnt["TV FIRST"], 100.0 * cnt["TV FIRST"] / n, cnt["TV WITH IT"], 100.0 * cnt["TV WITH IT"] / n, cnt["NOT ON TV"], 100.0 * cnt["NOT ON TV"] / n))
    if ahead:
        say("  when TV was first, it was ahead by: middle %.0f min · 3 in 4 within %.0f min" % (np.percentile(ahead, 50), np.percentile(ahead, 75)))
    say("  (a name said in the hour before can be an unrelated mention - section 3 shows the words, to check by eye)")
    say(""); say("2 THE STORIES - important stories (news.db: score 60+, a direction, market hours) on the days the TV watcher heard")
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=10)
        R = c.execute("select sym, src, t_pub, t_seen, h, side from items where score>=60 and side<>0 and t_pub>?", (TV[0][0] - 3 * 3600,)).fetchall(); c.close()
    except Exception as ex:
        R = []; say("  news.db not read: %s" % ex)
    rows = []
    for sym, src, tp, tsn, h, side in R:
        if not (tp and tsn and mkt(tp)) or ist(tp).toordinal() not in tv_days:
            continue
        ts, ctx = first_said(sym, tp - 3 * 3600, tsn)
        rows.append((sym, src, tp, tsn, h, ts, ctx))
    if rows:
        said = [r for r in rows if r[5] is not None]
        say("  %d stories · CNBC named the company before GIR saw the story in %d (%.0f%%)" % (len(rows), len(said), 100.0 * len(said) / len(rows)))
        if said:
            say("    TV before publishing: %d · TV ahead of GIR seeing it: middle %.0f min" % (sum(1 for r in said if r[5] < r[2]), np.percentile([(r[3] - r[5]) / 60.0 for r in said], 50)))
        for r in sorted(said, key=lambda r: -(r[3] - r[5]))[:10]:
            say("    %s %-11s TV %s · published %s · GIR saw %s (%s) · %s" % (ist(r[2]).strftime("%d %b"), r[0], ist(r[5]).strftime("%H:%M"), ist(r[2]).strftime("%H:%M"),
                ist(r[3]).strftime("%H:%M"), r[1], (r[4] or "")[:60]))
            say("        heard: \"…%s…\"" % r[6][:200])
    else:
        say("  no important story on the days the TV watcher heard")
    say(""); say("3 THE CASES - sharp moves where CNBC said the name first (the words heard, to check by eye)")
    for s, d_, t0, m, ts, ctx in sorted(CASES, key=lambda x: -abs(x[3]))[:15]:
        say("  %s %-11s move %+.1f%% from %s · TV said it at %s (%.0f min before)" % (dt.date.fromordinal(d_).strftime("%d %b"), s, m, ist(t0).strftime("%H:%M"), ist(ts).strftime("%H:%M"), (t0 - ts) / 60.0))
        say("      \"…%s…\"" % ctx[:220])
    try:
        open(os.path.join(D, "data", "tvlag.txt"), "w").write("\n".join(L) + "\n"); say(""); say("  saved: data/tvlag.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
