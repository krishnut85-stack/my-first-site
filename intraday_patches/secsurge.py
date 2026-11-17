#!/usr/bin/env python3
"""secsurge.py - patch 372: 🚀 A SECTOR IS RUNNING (Rama, 17 Nov 11:10: "I did not get any alert for the sector that was running fast up" -
capital markets ran from the open on the capital-gains tax news and came no.3 with no word from GIR).
Called by seclive.py on every new sector reading (every few seconds, market hours). A sector RUNS when, over the last 30 minutes:
  · it moved 0.80%+ (all its NSE shares, by size), and 0.50%+ more than the middle sector (so a whole-market jump is not a sector run)
  · 70%+ of its shares moved that way in those 30 minutes (many shares, not one)
  · it has 5+ shares, and no one company is half or more of its move (patch 369 ⚠)
(The first rule - 0.60% / 0.40%, or 0.40% / 0.30% in 15 minutes, any sector - gave 13 alerts a day on the 67 kept days, and what came after
was no better than any F&O share already moving; the 15-minute bursts and the one-company runs were pure noise. "backtest" compares the rules.) The same sector the same way again only after 45 minutes and a
further 0.50% on the day. From 09:30 (30 minutes of record needed) to 15:00. Up = 🚀 RUNNING UP, down = 🔻 FALLING FAST.
Each alert carries: the sector, the move in the window and on the day, its rank now, how many shares are moving, ⚠ when one company is half or
more of it (patch 369), and its F&O shares leading the move.
The test: at 15:10 each alert is scored - did the sector go on its way from the alert to 15:10, against the middle sector? Kept per day in
data/secsurge/<day>.json, so after a few weeks the numbers say whether an alert is worth acting on. Nothing rings (patch 191's rule: only
trade calls, critical and regulator alerts ring); the page shows it. Orders nothing, sends nothing.
  python3 secsurge.py            today's alerts and their scores
  python3 secsurge.py study      every kept day: how the live alerts did
  python3 secsurge.py backtest   the same rule replayed on every day of Kite's 5-minute prices GIR keeps (data/secstudy) - what the sector and
                                 its F&O shares did after each alert, against the middle sector and against any F&O share (no Kite call)"""
import os, sys, json, glob, datetime as dt
D = os.path.dirname(os.path.abspath(__file__))
SD = os.path.join(D, "data", "secsurge")
RULE = {"30": (0.80, 0.50)}         # window -> (its move, more than the middle sector), in % - 17 Nov replay: the 15-minute burst was noise
NO_ONE = True                        # 17 Nov replay: a run carried by one company (patch 369 ⚠) did nothing after (235 alerts, +0.00%)
BREADTH, MIN_N, AGAIN_MIN, AGAIN_MORE = 0.70, 5, 45, 0.50
_S = {"day": None, "ev": [], "end": None}


def _path(day):
    return os.path.join(SD, "%s.json" % day)


def _load(day):
    if _S["day"] != day:
        _S.update({"day": day, "ev": [], "end": None})
        try:
            j = json.load(open(_path(day)))
            _S["ev"], _S["end"] = j.get("ev") or [], j.get("end")
        except Exception:
            pass


def _save():
    try:
        os.makedirs(SD, exist_ok=True); p = _path(_S["day"])
        json.dump({"day": _S["day"], "ev": _S["ev"], "end": _S["end"]}, open(p + ".tmp", "w"), ensure_ascii=False); os.replace(p + ".tmp", p)
    except Exception:
        pass


def _med(v):
    v = sorted(v)
    return v[len(v) // 2] if v else 0.0


def check(V, n):
    """V: seclive's reading (compute()) · n: now (IST). Adds today's alerts to V["surge"]; returns the new ones."""
    day = str(n.date()); _load(day); hm = n.strftime("%H:%M"); new = []
    S = [x for x in (V.get("sectors") or []) if (x.get("n") or 0) >= MIN_N]
    if not S:
        V["surge"] = _S["ev"][-12:]; return new
    rank = {x["name"]: i + 1 for i, x in enumerate(sorted(S, key=lambda x: -x["chg"]))}
    if "09:30" <= hm <= "15:00":
        for w in RULE:
            R = [x for x in S if (x.get("rot") or {}).get(w) is not None and not (NO_ONE and x.get("one"))]
            if len(R) < 8:
                continue
            md = _med([x["rot"][w] for x in R]); mv, rel = RULE[w]
            for x in R:
                r = x["rot"][w]; dr = 1 if r > 0 else -1; d = (x.get("rotx") or {}).get(w) or {}; nn = d.get("n") or 0
                br = ((d.get("up") if dr > 0 else d.get("dn")) or 0) / nn if nn else 0
                if abs(r) < mv or (r - md) * dr < rel or br < BREADTH or nn < MIN_N:
                    continue
                old = [e for e in _S["ev"] if e["sec"] == x["name"] and e["dir"] == dr]
                if old:
                    e0 = old[-1]; h0, m0 = map(int, e0["t"].split(":"))
                    if n.hour * 60 + n.minute - (h0 * 60 + m0) < AGAIN_MIN or (x["chg"] - e0["day"]) * dr < AGAIN_MORE:
                        continue
                fol = [f for f in (x.get("fol") or []) if f[1] * dr > 0]
                fol.sort(key=lambda f: -f[1] * dr)
                lead = [t for t in (d.get("top") if dr > 0 else d.get("bot")) or [] if t[1] * dr > 0]
                e = {"t": hm, "sec": x["name"], "dir": dr, "win": int(w), "r": round(r, 2), "mid": round(md, 2), "day": x["chg"], "mday": round(_med([y["chg"] for y in S]), 2), "rank": rank.get(x["name"]),
                     "of": len(S), "br": round(100 * br), "nn": nn, "one": x.get("one"), "fo": [[f[0], f[1]] for f in fol[:4]], "lead": [[t[0], t[1], t[2]] for t in lead[:3]]}
                _S["ev"].append(e); new.append(e)
    if hm >= "15:10" and _S["ev"] and not _S["end"]:                      # the score: from the alert to 15:10, against the middle sector
        mdd = _med([x["chg"] for x in S]); ch = {x["name"]: x["chg"] for x in S}
        _S["end"] = {"t": hm, "mid": round(mdd, 2), "chg": {k: round(v, 2) for k, v in ch.items()}}
        for e in _S["ev"]:
            if e["sec"] in ch:
                e["went"] = round((ch[e["sec"]] - e["day"]) * e["dir"], 2)
                e["rel"] = round(((ch[e["sec"]] - e["day"]) - (mdd - e.get("mday", mdd))) * e["dir"], 2)   # against the middle sector
        new = new or []
        _save()
    if new:
        _save()
    V["surge"] = _S["ev"][-12:]
    return new


def line(e):
    return "%s %s %s %s%.2f%% in %d min (middle sector %+.2f%%) · %+.2f%% on the day, no.%s of %s · %d%% of %d shares that way%s%s" % (
        e["t"], "🚀" if e["dir"] > 0 else "🔻", e["sec"].upper(), "+" if e["r"] > 0 else "", e["r"], e["win"], e["mid"], e["day"], e["rank"], e["of"], e["br"], e["nn"],
        (" · ⚠ mostly %s" % e["one"][0]) if e.get("one") else "", (" · F&O: " + ", ".join("%s %+.1f%%" % (f[0], f[1]) for f in e["fo"])) if e.get("fo") else "")


def study():
    E = []
    for p in sorted(glob.glob(os.path.join(SD, "*.json"))):
        try:
            j = json.load(open(p))
        except Exception:
            continue
        for e in j.get("ev") or []:
            if "went" in e:
                E.append((j["day"], e))
    print("🚀 SECTOR RUN ALERTS - how they did from the alert to 15:10 (the sector's own move its way, by size) · %d alerts on %d days" % (len(E), len({d for d, _ in E})))
    if not E:
        print("  none scored yet - the first score is at 15:10 on a day with an alert"); return
    for nm, f in (("all", lambda e: True), ("RUNNING UP", lambda e: e["dir"] > 0), ("FALLING FAST", lambda e: e["dir"] < 0), ("30-minute", lambda e: e["win"] == 30),
                  ("15-minute burst", lambda e: e["win"] == 15), ("before 11:00", lambda e: e["t"] < "11:00"), ("11:00 or later", lambda e: e["t"] >= "11:00"),
                  ("many shares (no ⚠)", lambda e: not e.get("one")), ("⚠ one company", lambda e: bool(e.get("one")))):
        X = [e["went"] for _, e in E if f(e)]
        if X:
            print("  %-20s %4d alerts │ went on %+.2f%% on average │ went on its way %3.0f%% of the time" % (nm, len(X), sum(X) / len(X), 100 * sum(1 for x in X if x > 0) / len(X)))
    print("  (a few weeks of alerts are needed before these numbers mean anything)")


def backtest():
    """the rule on every kept day of 5-minute prices: at each 5-minute mark 09:45-15:00 (the 30-minute window needs 09:15-09:45)"""
    import re, numpy as np
    sys.path.insert(0, D); import seclive as SL
    C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    P = {}                                                              # sym -> {day: (yesterday's close, 72 closes at 09:20 ... 15:15)}
    for s in SEC:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b or (W and not W.get(s)):
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 7 or not len(A):
            continue
        prev = None; d_ = {}
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            day = int(p[0, 0]); cl = np.full(72, np.nan)
            for row in p:
                k = int(row[1]) // 5
                if 0 <= k < 72:
                    cl[k] = row[5]
            for k in range(1, 72):                                      # a bar with no trade keeps the last price
                if cl[k] != cl[k]:
                    cl[k] = cl[k - 1]
            if prev is not None and day - prev[0] <= 5 and np.isfinite(cl).sum() >= 60:
                d_[day] = (prev[1], cl)
            if np.isfinite(cl).sum() >= 60:
                prev = (day, float(cl[np.isfinite(cl)][-1]))
        if d_:
            P[s] = d_
    if len(P) < 100:
        print("  ❌ 5-minute files for only %d shares in data/secstudy - run sectorstudy.py once" % len(P)); return
    days = sorted({d for v in P.values() for d in v}); days = [d for d in days if sum(1 for s in P if d in P[s]) >= 200]
    END = 70                                                            # the bar that closes at 15:10
    print("🚀 SECTOR RUN ALERTS - the rule replayed · %d days (%s to %s) · %d shares · sizes: %s" % (len(days), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), len(P), wsrc))
    print("  the live rule: %s, %d%%+ of its shares that way, %d+ shares%s; again after %d min and %.2f%% more" % (
        ", ".join("%s min %.2f%%+ (and %.2f%%+ over the middle sector)" % (w, RULE[w][0], RULE[w][1]) for w in RULE), 100 * BREADTH, MIN_N, ", no ⚠ one company" if NO_ONE else "", AGAIN_MIN, AGAIN_MORE))
    CA = []; base = []
    for d in days:
        G = {}
        for s in P:
            if d in P[s]:
                pc, cl = P[s][d]
                if pc > 0 and np.isfinite(cl).all():
                    G.setdefault(SEC[s], []).append((s, pc, cl, W.get(s) or 1.0, s in FO))
        G = {k: v for k, v in G.items() if len(v) >= MIN_N}
        if len(G) < 10:
            continue
        for b in range(5, 69):                                          # bar 5 closes at 09:45 ... bar 68 at 15:00
            hm = "%02d:%02d" % divmod(9 * 60 + 15 + 5 * (b + 1), 60)
            rows = {}
            for k, v in G.items():
                w = np.array([x[3] for x in v]); cl = np.array([x[2] for x in v]); pc = np.array([x[1] for x in v])
                dayc = float((w * (cl[:, b] / pc - 1)).sum() / w.sum() * 100)
                win = {}
                for wl, nb in (("30", 6), ("15", 3)):
                    if b - nb >= 0:
                        m_ = cl[:, b] / cl[:, b - nb] - 1
                        win[wl] = (float((w * m_).sum() / w.sum() * 100), float((m_ > 0).mean()), float((m_ < 0).mean()))
                ahead = float((w * (cl[:, END] / cl[:, b] - 1)).sum() / w.sum() * 100)
                rows[k] = (dayc, win, ahead)
            mdd = _med([r[0] for r in rows.values()]); mahead = _med([r[2] for r in rows.values()])
            for wl in ("30", "15"):
                R_ = {k: r for k, r in rows.items() if wl in r[1]}
                if len(R_) < 8:
                    continue
                md = _med([r[1][wl][0] for r in R_.values()])
                for k, r in R_.items():
                    x, up, dn = r[1][wl]; dr = 1 if x > 0 else -1; br = up if dr > 0 else dn
                    if abs(x) < 0.40 or (x - md) * dr < 0.30 or br < 0.70:     # looser than every rule tried below
                        continue
                    fo = [(x_[0], (x_[2][END] / x_[2][b] - 1) * dr * 100) for x_ in G[k] if x_[4] and (x_[2][b] / x_[1] - 1) * dr > 0]
                    one = None
                    tot = sum(x_[3] * (x_[2][b] / x_[1] - 1) for x_ in G[k])
                    if tot and abs(r[0]) >= 0.1:
                        lead = max(G[k], key=lambda x_: x_[3] * (x_[2][b] / x_[1] - 1) * dr)
                        one = bool(lead[3] * (lead[2][b] / lead[1] - 1) / tot >= 0.5)
                    CA.append({"d": d, "b": b, "t": hm, "sec": k, "dir": dr, "win": int(wl), "x": abs(x), "ov": (x - md) * dr, "br": br, "went": r[2] * dr,
                               "rel": (r[2] - mahead) * dr, "fo": fo, "one": one, "dayc": r[0] * dr})
        for s in P:                                                     # the yardstick: any F&O share already moving that way at a 5-minute mark
            if s in FO and d in P[s]:
                pc, cl = P[s][d]
                if np.isfinite(cl).all():
                    for b in range(5, 69, 6):
                        m0 = cl[b] / pc - 1
                        if abs(m0) > 0.003:
                            base.append((d, (cl[END] / cl[b] - 1) * (1 if m0 > 0 else -1) * 100))
    mid = days[len(days) // 2]; av = lambda v: sum(v) / len(v) if v else float("nan")
    b0 = av([x[1] for x in base]); b1 = av([x[1] for x in base if x[0] < mid]); b2 = av([x[1] for x in base if x[0] >= mid])

    def run(win, brd, no_one=False, until="15:00", first=False, dr_=0):
        out = []; last = {}
        for e in CA:                                                    # in time order within each day
            if e["t"] > until or (dr_ and e["dir"] != dr_) or str(e["win"]) not in win or (no_one and e["one"]):
                continue
            mv, rel = win[str(e["win"])]
            if e["x"] < mv or e["ov"] < rel or e["br"] < brd:
                continue
            key = (e["d"], e["sec"], e["dir"]); lk = last.get(key)
            if lk and (first or e["b"] - lk[0] < AGAIN_MIN // 5 or e["dayc"] - lk[1] < AGAIN_MORE):
                continue
            last[key] = (e["b"], e["dayc"]); out.append(e)
        return out
    V_ = [("first rule (30 or 15 min)", dict(win={"30": (0.60, 0.40), "15": (0.40, 0.30)}, brd=0.70)),
          ("30 min only", dict(win={"30": (0.60, 0.40)}, brd=0.70)),
          ("30 min, no ⚠ one company", dict(win={"30": (0.60, 0.40)}, brd=0.70, no_one=True)),
          ("30 min 0.8%, no ⚠", dict(win={"30": (0.80, 0.50)}, brd=0.70, no_one=True)),
          ("30 min 1.0% 75%, no ⚠", dict(win={"30": (1.00, 0.60)}, brd=0.75, no_one=True)),
          ("30 min 0.8%, no ⚠, to 12:30", dict(win={"30": (0.80, 0.50)}, brd=0.70, no_one=True, until="12:30")),
          ("30 min, no ⚠, to 10:30", dict(win={"30": (0.60, 0.40)}, brd=0.70, no_one=True, until="10:30")),
          ("30 min 0.8%, no ⚠, once a day", dict(win={"30": (0.80, 0.50)}, brd=0.70, no_one=True, first=True)),
          ("30 min 0.8%, no ⚠ - 🚀 up only", dict(win={"30": (0.80, 0.50)}, brd=0.70, no_one=True, dr_=1)),
          ("30 min 0.8%, no ⚠ - 🔻 down only", dict(win={"30": (0.80, 0.50)}, brd=0.70, no_one=True, dr_=-1))]
    print("  yardstick: ANY F&O share already moving, from a 5-minute mark to 15:10: %+.2f%% (halves %+.2f%% / %+.2f%%)" % (b0, b1, b2))
    print("")
    print("  WHICH RULE? - the same days, each rule · 'F&O edge' = its F&O shares (already moving that way) against the yardstick · ✔ = 0.10%+ in both halves, 100+ cases")
    print("    %-34s %9s │ %-24s │ %s" % ("rule", "a day", "sector went on (its way)", "F&O shares: cases · move · its way · edge (halves)"))
    for nm, kw in V_:
        X = run(**kw)
        if not X:
            print("    %-34s     0" % nm); continue
        F_ = [(e["d"], v) for e in X for _, v in e["fo"]]
        f1, f2 = av([v for d_, v in F_ if d_ < mid]), av([v for d_, v in F_ if d_ >= mid])
        ok = len(F_) >= 100 and f1 - b1 >= 0.1 and f2 - b2 >= 0.1
        print("    %-34s %5.1f/day │ %+.2f%% (%2.0f%%)            │ %5d · %+.2f%% · %2.0f%% · %+.2f%% (%+.2f%% / %+.2f%%) %s" % (
            nm, len(X) / len(days), av([e["went"] for e in X]), 100 * av([1 if e["went"] > 0 else 0 for e in X]), len(F_), av([v for _, v in F_]),
            100 * av([1 if v > 0 else 0 for _, v in F_]), av([v for _, v in F_]) - b0, f1 - b1, f2 - b2, "✔" if ok else "✘"))
    EV = run(win=RULE, brd=BREADTH, no_one=NO_ONE)
    print("")
    print("  THE LIVE RULE IN DETAIL (%s) · %d alerts on %d of %d days (%.1f a day)" % (", ".join("%s min %.2f%%/+%.2f%%" % (w, RULE[w][0], RULE[w][1]) for w in RULE) + (", no ⚠" if NO_ONE else ""),
                                                                                   len(EV), len({e["d"] for e in EV}), len(days), len(EV) / len(days)))
    if not EV:
        return
    print("  how to read: 'sector went on' = the sector's move its way from the alert to 15:10 · 'over middle' = against the middle sector over the same time")
    print("  ✔ = the F&O shares beat the yardstick by 0.10%+ in both halves of the days, with 100+ share cases")
    for nm, f in (("ALL ALERTS", lambda e: True), ("🚀 RUNNING UP", lambda e: e["dir"] > 0), ("🔻 FALLING FAST", lambda e: e["dir"] < 0),
                  ("30-minute run", lambda e: e["win"] == 30), ("15-minute burst", lambda e: e["win"] == 15),
                  ("09:45-10:30", lambda e: e["t"] <= "10:30"), ("10:35-12:30", lambda e: "10:35" <= e["t"] <= "12:30"), ("after 12:30", lambda e: e["t"] > "12:30"),
                  ("already 1.5%+ on the day", lambda e: e["dayc"] >= 1.5), ("under 1.5% on the day", lambda e: e["dayc"] < 1.5),
                  ("many shares (no ⚠)", lambda e: e["one"] is False), ("⚠ one company", lambda e: e["one"] is True)):
        X = [e for e in EV if f(e)]
        if len(X) < 10:
            print("    %-26s %4d alerts - too few" % (nm, len(X))); continue
        F_ = [(e["d"], v) for e in X for _, v in e["fo"]]
        f0, f1, f2 = av([v for _, v in F_]), av([v for d_, v in F_ if d_ < mid]), av([v for d_, v in F_ if d_ >= mid])
        ok = len(F_) >= 100 and f1 - b1 >= 0.1 and f2 - b2 >= 0.1
        print("    %-26s %4d alerts │ sector went on %+.2f%% (%2.0f%% its way) · over middle %+.2f%% │ F&O shares %5d cases %+.2f%% %2.0f%% its way (halves %+.2f%% / %+.2f%%) %s" % (
            nm, len(X), av([e["went"] for e in X]), 100 * av([1 if e["went"] > 0 else 0 for e in X]), av([e["rel"] for e in X]), len(F_), f0,
            100 * av([1 if v > 0 else 0 for _, v in F_]), f1, f2, "✔" if ok else "✘"))
    print("  the last 10 alerts:")
    for e in EV[-10:]:
        print("    %s %s %s %s · sector then went on %+.2f%%" % (dt.date.fromordinal(e["d"]), e["t"], "🚀" if e["dir"] > 0 else "🔻", e["sec"], e["went"]))


if __name__ == "__main__":
    if sys.argv[1:2] == ["study"]:
        study()
    elif sys.argv[1:2] == ["backtest"]:
        backtest()
    else:
        day = str(dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).date()); _load(day)
        print("🚀 SECTOR RUN ALERTS %s - %d" % (day, len(_S["ev"])))
        for e in _S["ev"]:
            print("  " + line(e) + (("  → went on %+.2f%% to 15:10" % e["went"]) if "went" in e else ""))
