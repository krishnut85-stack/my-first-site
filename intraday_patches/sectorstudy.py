#!/usr/bin/env python3
"""sectorstudy.py - READ ONLY. WHICH SECTOR, WHICH SHARES ARE MOVING IT, WHY - AND HOW EARLY CAN WE KNOW (Rama, 16 Nov: "every day a different
sector performs - there has to be a reason. Not only the strongest share: find the shares of that sector that have the potential to MOVE the
sector, and the reason. When, after NIFTY opens, can we say which sector is performing and which is bad?").
Kite's own 5-minute prices for every share of NSE's Nifty Total Market (~750), the last 60 trading days, in NSE's own sectors, weighted by NSE's
free-float market cap (the same list and weights as patch 354's seclive.py). For every day and for 09:20 / 09:30 / 09:45 / 10:00 / 10:30:
  1) THE RANKING   the best and the worst sector at that time: still top 3 / bottom 3 at 15:10? did the sector go FURTHER after that time?
  2) THE DRIVERS   a share's push on its sector = its weight x its move. The DRIVERS = the F&O shares with the biggest push in the sector's
                   direction (the shares that are moving the sector). Against: the STRONGEST share (the biggest %), the LAGGARDS (big F&O shares
                   of the sector that have not moved yet) and ALL the sector's F&O shares. From that time to 15:10: went on? +1.5% before -1%?
  3) THE VOTES     on the drivers: news on the share before that time (GIR's own alert list, the evening before included) · a gap the same way ·
                   the right side of VWAP · 70%+ of the sector's shares the same way · NIFTY the same way · the driver is one of the sector's 3
                   biggest companies - which votes raise the win, which do nothing
  4) THE REASON    the last days: the best and the worst sector at 09:45, the shares that moved it (their part of the sector's move), the
                   news GIR had on them, and WHY in plain words
  5) THE KIND OF REASON  one share's story / a few shares / the whole sector · news or none · overnight or built after the open · with the
                   market or on its own · new today, 2nd day or a rebound - which kind of move LASTS to 15:10 and which fades
CE on the best sector's shares, PE on the worst sector's. The moves are the SHARE's (%). Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 sectorstudy.py [days=60]   -> prints, saves data/sectorstudy.txt
The first run fetches ~750 shares from Kite (about 10 minutes) and keeps them in data/secstudy/; a second run is quick."""
import os, re, sys, json, time, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import seclive as SL
CACHE = os.path.join(D, "data", "secstudy")
L = []
TS = (5, 15, 30, 45, 75)                         # minutes after 09:15: 09:20 09:30 09:45 10:00 10:30
END = 355                                        # 15:10
UPT, DNT = 0.015, 0.010                          # "worked" = +1.5% its way before -1.0% against
NEWS = re.compile(r"NEWS|RESULT|ORDER|UPGRAD|DOWNGRAD|TARGET|BLOCK|BULK|📰|📄|🚨", re.I)
hm = lambda m: "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)


def say(s=""):
    L.append(s); print(s, flush=True)


def fetch_all(kite, syms, ndays):
    """{sym: array [day ordinal, minute, o, h, l, c, v]} - Kite 5-minute candles, kept on disk"""
    import getdata
    os.makedirs(CACHE, exist_ok=True)
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    tok["NIFTY50"] = 256265
    today = dt.datetime.now(SL.IST).date(); frm = dt.datetime.combine(today - dt.timedelta(days=int(ndays * 1.6) + 5), dt.time(9, 15)); to = dt.datetime.combine(today, dt.time(15, 30))
    out = {}; got = 0
    for n_, s in enumerate(sorted(set(syms) | {"NIFTY50"})):
        f = os.path.join(CACHE, "%s_%s.npy" % (re.sub(r"[^A-Z0-9]", "_", s), today))
        if os.path.exists(f):
            out[s] = np.load(f); continue
        if s not in tok:
            continue
        try:
            rows = getdata.call(kite.historical_data, tok[s], frm, to, "5minute"); time.sleep(0.36)
        except Exception as ex:
            print("  %s: %s" % (s, str(ex)[:60]), flush=True); continue
        a = np.array([[r["date"].date().toordinal(), r["date"].hour * 60 + r["date"].minute - 555, r["open"], r["high"], r["low"], r["close"], r["volume"]] for r in rows], dtype=np.float64)
        if len(a):
            np.save(f, a); out[s] = a; got += 1
        if got and got % 100 == 0:
            print("  fetched %d ..." % got, flush=True)
    return out


def by_day(A):
    """array -> {day ordinal: bars [minute, o, h, l, c, v]}"""
    out = {}
    if A is None or not len(A):
        return out
    d = A[:, 0]; cut = np.flatnonzero(np.diff(d)) + 1
    for part in np.split(A, cut):
        out[int(part[0, 0])] = part[:, 1:]
    return out


def news_of(day):
    """{sym: [(hh:mm, first line)]} - GIR's own alert list: the news lines of the day up to 10:30 and of the evening before"""
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
        prev = str(dt.date.fromisoformat(day) - dt.timedelta(days=1))
        prev3 = str(dt.date.fromisoformat(day) - dt.timedelta(days=3))
        for d_, t, s, tx in c.execute("select day, t, sym, text from alerts where (day=? and t<='10:30') or (day>=? and day<? and t>='15:30') order by day, t", (day, prev3, day)):
            if s and tx and NEWS.search(str(tx)[:160]):
                out.setdefault(str(s).upper(), []).append((("eve " if d_ != day else "") + str(t)[:5], str(tx).split("\n")[0][:90]))
        c.close()
    except Exception:
        pass
    return out


def has_news(N, s, T):
    lim = hm(T)
    return any(t.startswith("eve") or t <= lim for t, _ in N.get(s, []))


def stat(X):
    """picks -> (n, won %, average % to 15:10, worked %)"""
    if not X:
        return None
    n = len(X); return n, 100.0 * sum(1 for x in X if x["ret"] > 0) / n, 100.0 * sum(x["ret"] for x in X) / n, 100.0 * sum(1 for x in X if x["hit"] > 0) / n


def fmt(name, X):
    s = stat(X)
    if not s:
        return "    %-44s -" % name
    return "    %-44s %5d picks · %3.0f%% went on · average %+.2f%% · %3.0f%% worked (+1.5%% before -1%%)" % (name, s[0], s[1], s[2], s[3])


def main():
    ndays = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 60
    SEC, NAMES = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    kite = SL.get_kite()
    say("📊 SECTOR STUDY · NSE's sectors, all their shares, Kite 5-minute prices · the last %d trading days" % ndays)
    say("  fetching %d shares from Kite (about 10 minutes the first time) ..." % len(SEC))
    RAW = fetch_all(kite, list(SEC), ndays)
    P = {s: by_day(a) for s, a in RAW.items()}
    days = sorted(P.get("NIFTY50", {}))[-(ndays + 1):]
    if len(days) < 5:
        say("  not enough days from Kite (%d)" % len(days)); return
    if not W:                                                                # NSE's sizes not available -> the share's own traded value as its size
        for s in SEC:
            v = [float((b[:, 4] * b[:, 5]).sum()) for b in P.get(s, {}).values()]
            if v:
                W[s] = sum(v) / len(v)
        wsrc = "each share's average traded value (NSE's sizes were not available)"
    say("  %d shares with prices · %d sectors · weights: %s · %d F&O shares" % (len(P) - 1, len(set(SEC.values())), wsrc, len(FO & set(P))))
    px = lambda b, T: (float(b[b[:, 0] <= T - 5][-1, 4]) if (b[:, 0] <= T - 5).any() else None)
    RANK = {T: {"n": 0, "top3": 0, "bot3": 0, "topgo": [], "botgo": [], "rho": []} for T in TS}
    PICK = {T: {k: [] for k in ("CE DRIVER", "CE STRONGEST", "CE LAGGARD", "CE ALL F&O", "PE DRIVER", "PE STRONGEST", "PE LAGGARD", "PE ALL F&O")} for T in TS}
    WHY = []; REAS = []; CLR = {}
    for di in range(1, len(days)):
        d, dp = days[di], days[di - 1]; day = str(dt.date.fromordinal(d)); N = None
        nb = P["NIFTY50"].get(d); nbp = P["NIFTY50"].get(dp)
        if nb is None or nbp is None or len(nb) < 60:
            continue
        S = {}
        for s, sec in SEC.items():
            b, bp = P.get(s, {}).get(d), P.get(s, {}).get(dp)
            if b is None or bp is None or len(b) < 30 or not W.get(s):
                continue
            S[s] = (sec, float(bp[-1, 4]), b)
        pe = {s: px(b, END + 5) for s, (_, _, b) in S.items()}
        SCD = {}
        for T in TS:
            G = {}
            for s, (sec, pc, b) in S.items():
                p = px(b, T)
                if p and pe[s]:
                    G.setdefault(sec, []).append((s, p / pc - 1, pe[s] / pc - 1, W[s], p, b, pc))
            sc = {}
            for sec, R in G.items():
                if len(R) < 5:
                    continue
                w = sum(r[3] for r in R)
                sc[sec] = (sum(r[1] * r[3] for r in R) / w, sum(r[2] * r[3] for r in R) / w, sum(1 for r in R if r[1] > 0) / len(R), sum(1 for r in R if r[1] < 0) / len(R))
            if len(sc) < 8:
                continue
            at = sorted(sc, key=lambda k: -sc[k][0]); cl = sorted(sc, key=lambda k: -sc[k][1]); SCD[T] = sc
            top, bot = at[0], at[-1]; K = RANK[T]; K["n"] += 1
            K["top3"] += top in cl[:3]; K["bot3"] += bot in cl[-3:]
            K["topgo"].append(sc[top][1] - sc[top][0]); K["botgo"].append(sc[bot][0] - sc[bot][1])
            ra = {k: i for i, k in enumerate(at)}; rc = {k: i for i, k in enumerate(cl)}; n_ = len(at)
            K["rho"].append(1 - 6 * sum((ra[k] - rc[k]) ** 2 for k in at) / (n_ * (n_ * n_ - 1)))
            pn = px(nb, T); nif = (pn / float(nbp[-1, 4]) - 1) if pn else 0.0
            for sec, dr, side in ((top, 1, "CE"), (bot, -1, "PE")):
                R = G[sec]; w = sum(r[3] for r in R); mv = sc[sec][0]
                if mv * dr <= 0:
                    continue
                big3 = {r[0] for r in sorted(R, key=lambda r: -r[3])[:3]}
                breadth = sc[sec][2] if dr > 0 else sc[sec][3]

                def pick(r, kind):
                    s, c, _, wt, p, b, pc = r
                    a = b[(b[:, 0] >= T) & (b[:, 0] <= END - 5)]
                    if not len(a):
                        return
                    hit = 0
                    for row in a:
                        lo = ((row[3] if dr > 0 else row[2]) / p - 1) * dr; hi = ((row[2] if dr > 0 else row[3]) / p - 1) * dr
                        if lo <= -DNT:
                            hit = -1; break
                        if hi >= UPT:
                            hit = 1; break
                    pre = b[b[:, 0] <= T - 5]; vw = float((pre[:, 4] * pre[:, 5]).sum() / max(pre[:, 5].sum(), 1.0))
                    nonlocal N
                    if N is None:
                        N = news_of(day)
                    PICK[T][side + " " + kind].append({"s": s, "day": day, "ret": (float(a[-1, 4]) / p - 1) * dr, "hit": hit, "push": c * wt / w / mv if mv else 0, "c": c,
                        "v_news": has_news(N, s, T), "v_gap": (float(b[0, 1]) / pc - 1) * dr >= 0.005, "v_vwap": (p - vw) * dr > 0, "v_breadth": breadth >= 0.7,
                        "v_nifty": nif * dr > 0, "v_big": s in big3, "v_strong": abs(mv) >= 0.01})
                fo = [r for r in R if r[0] in FO]
                drv = sorted([r for r in fo if r[1] * dr > 0], key=lambda r: -r[1] * r[3] * dr)[:3]
                for r in drv:
                    pick(r, "DRIVER")
                st = sorted(fo, key=lambda r: -r[1] * dr)[:1]
                for r in st:
                    pick(r, "STRONGEST")
                for r in sorted([r for r in fo if r[1] * dr < 0.5 * mv * dr], key=lambda r: -r[3])[:3]:
                    pick(r, "LAGGARD")
                for r in fo:
                    pick(r, "ALL F&O")
                if T == 30:
                    if N is None:
                        N = news_of(day)
                    allp = sorted(R, key=lambda r: -r[1] * r[3] * dr)[:4]
                    part1 = (allp[0][1] * allp[0][3] / w / mv) if (allp and mv) else 0
                    early = (SCD.get(5) or {}).get(sec); y = CLR.get(dp)
                    tags = ["ONE SHARE'S STORY" if part1 >= 0.4 else "THE WHOLE SECTOR" if breadth >= 0.7 else "A FEW SHARES",
                            "NEWS ON ITS DRIVERS" if any(has_news(N, r[0], T) for r in allp) else "NO NEWS IN GIR",
                            "OVERNIGHT (already there at 09:20)" if (early and early[0] * dr >= 0.6 * mv * dr) else "BUILT AFTER THE OPEN",
                            "WITH THE MARKET" if nif * dr >= 0.002 else "ON ITS OWN (NIFTY not that way)",
                            "NEW TODAY" if not y else "2nd DAY (the same yesterday)" if sec in (y[0] if dr > 0 else y[1]) else "REBOUND (the opposite yesterday)" if sec in (y[1] if dr > 0 else y[0]) else "NEW TODAY"]
                    REAS.append({"tags": tags, "go": (sc[sec][1] - mv) * dr, "stay": sec in (cl[:3] if dr > 0 else cl[-3:]), "side": side})
                    WHY.append((day, side, sec, mv, breadth, len(R), sc[sec][1], [(r[0], r[1], r[1] * r[3] / w / mv if mv else 0, r[0] in FO, (N.get(r[0]) or [None])[-1]) for r in allp], tags))
            if T == TS[-1]:
                CLR[d] = (cl[:3], cl[-3:])
    say("")
    say("1) THE RANKING - is the best / worst sector at that time still the best / worst at 15:10, and does it go further?")
    for T in TS:
        K = RANK[T]
        if not K["n"]:
            continue
        tg, bg = K["topgo"], K["botgo"]
        say("    %s · %d days · the BEST sector: top 3 at 15:10 on %2.0f%% of days, went further on %2.0f%% (average %+.2f%% more) · the WORST: bottom 3 on %2.0f%%, fell further on %2.0f%% (%+.2f%% more) · the whole ranking kept %.0f%%" % (
            hm(T), K["n"], 100 * K["top3"] / K["n"], 100 * sum(1 for x in tg if x > 0) / len(tg), 100 * sum(tg) / len(tg), 100 * K["bot3"] / K["n"],
            100 * sum(1 for x in bg if x > 0) / len(bg), 100 * sum(bg) / len(bg), 100 * sum(K["rho"]) / len(K["rho"])))
    say("")
    say("2) THE SHARES - from that time to 15:10, on the share (CE = the best sector's F&O shares, PE = the worst sector's):")
    for T in TS:
        say("  %s" % hm(T))
        for k in ("CE DRIVER", "CE STRONGEST", "CE LAGGARD", "CE ALL F&O", "PE DRIVER", "PE STRONGEST", "PE LAGGARD", "PE ALL F&O"):
            lab = {"DRIVER": "the DRIVERS (the 3 with the biggest push)", "STRONGEST": "the STRONGEST share (the biggest %)", "LAGGARD": "the LAGGARDS (big, not moved yet)", "ALL F&O": "ALL the sector's F&O shares"}[k[3:]]
            say(fmt(k[:2] + " · " + lab, PICK[T][k]))
    say("")
    say("3) THE VOTES - on the DRIVERS (CE and PE together): with the vote / without it")
    for T in TS:
        X = PICK[T]["CE DRIVER"] + PICK[T]["PE DRIVER"]
        if not X:
            continue
        say("  %s" % hm(T))
        for v, nm in (("v_news", "news on the share (GIR's list)"), ("v_gap", "gapped 0.5%+ the same way"), ("v_vwap", "the right side of VWAP"), ("v_breadth", "70%+ of the sector the same way"),
                      ("v_nifty", "NIFTY the same way"), ("v_big", "one of the sector's 3 biggest"), ("v_strong", "the sector already 1%+")):
            a, b = stat([x for x in X if x[v]]), stat([x for x in X if not x[v]])
            say("    %-34s WITH: %s   WITHOUT: %s" % (nm, ("%4d picks · %2.0f%% worked · %+.2f%%" % (a[0], a[3], a[2])) if a else "none", ("%4d picks · %2.0f%% worked · %+.2f%%" % (b[0], b[3], b[2])) if b else "none"))
        yes = [x for x in X if sum(1 for v in ("v_gap", "v_vwap", "v_breadth", "v_nifty", "v_big") if x[v]) >= 4]
        say(fmt("4 or 5 of the 5 price votes together", yes))
    say("")
    say("4) THE REASON - the last days at 09:45: the sector, the shares that moved it (their part of the sector's move), GIR's news on them")
    for day, side, sec, mv, br, n, cl, rows, tags in WHY[-12:]:
        say("  %s %s %-22s %+.2f%% at 09:45 (%d%% of its %d shares that way) -> %+.2f%% at 15:10" % (day, "▲ BEST " if side == "CE" else "▼ WORST", sec.upper(), mv * 100, round(br * 100), n, cl * 100))
        say("      why: %s" % " · ".join(tags))
        for s, c, part, fo, nw in rows:
            say("      %-12s %+5.1f%% · %2.0f%% of the sector's move%s%s" % (s, c * 100, part * 100, " · F&O" if fo else " · not F&O", (" · news %s: %s" % nw) if nw else ""))
    say("")
    say("5) THE KIND OF REASON - the best / worst sector at 09:45, by why it moved: does that kind of move LAST to 15:10?")
    for grp in (("ONE SHARE'S STORY", "A FEW SHARES", "THE WHOLE SECTOR"), ("NEWS ON ITS DRIVERS", "NO NEWS IN GIR"), ("OVERNIGHT (already there at 09:20)", "BUILT AFTER THE OPEN"),
                ("WITH THE MARKET", "ON ITS OWN (NIFTY not that way)"), ("NEW TODAY", "2nd DAY (the same yesterday)", "REBOUND (the opposite yesterday)")):
        for g in grp:
            X = [x for x in REAS if g in x["tags"]]
            if X:
                say("    %-36s %4d times · still top 3 / bottom 3 at 15:10: %3.0f%% · went further: %3.0f%% (average %+.2f%% more)" % (
                    g, len(X), 100 * sum(1 for x in X if x["stay"]) / len(X), 100 * sum(1 for x in X if x["go"] > 0) / len(X), 100 * sum(x["go"] for x in X) / len(X)))
        say("")
    both = [x for x in REAS if "THE WHOLE SECTOR" in x["tags"] and "NEWS ON ITS DRIVERS" in x["tags"]]
    if both:
        say("    the whole sector + news on its drivers  %4d times · went further: %3.0f%% (average %+.2f%% more)" % (len(both), 100 * sum(1 for x in both if x["go"] > 0) / len(both), 100 * sum(x["go"] for x in both) / len(both)))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "sectorstudy.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/sectorstudy.txt")


if __name__ == "__main__":
    main()
