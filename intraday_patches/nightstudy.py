#!/usr/bin/env python3
"""nightstudy.py - READ ONLY. DO THE OVERNIGHT MARKET LINKS PAY AFTER THE OPEN? (Rama, 17 Nov 17:10: "what are we going to build now to have the
perfect market prediction for tomorrow"). The 07:00 morning list (patch 380) maps each overnight market to the Indian F&O shares it usually moves
(morningmkts.LINKS) - written from experience, not tested. This tests every link on every past day GIR keeps 5-minute prices for (data/secstudy):
  THE NIGHT     each market's move over its last session before the Indian open (Yahoo's daily history, 1 year): the US and its sector funds,
                the ADRs, crude, gas, gold, silver, copper, aluminium, the US 10-year yield, the dollar, the rupee. Asia is left out: it is
                still trading at 09:15, so its close would be hindsight.
  THE SHARES    for each link's F&O shares, in the link's direction: the OPENING GAP, 09:30 -> 10:30 and 09:30 -> 15:10 - each against the
                average F&O share that day (so a whole-market day does not count as the link working). "whole market" links: the average F&O
                share itself.
  ON BIG NIGHTS the market moved at least the list's own "big" size; and HALF-SIZE nights (more days, a weaker test)
  CORRELATION   over ALL days, the market's move against the shares' gap and their 09:30 -> 15:10 (beyond the average share)
✔ = after the open (09:30 -> 15:10, beyond the average) +0.10% or more in BOTH halves of the days, 8+ nights, and "sure" 2.5+ (the night-by-night
average over its standard error - one number per night, since a night's shares move together). The gap is shown but cannot be
traded. -> data/nightstudy.txt and data/nightstudy.json (each link's verdict, for the morning list). Orders nothing, no Kite call.
  cd /home/globalbot/intraday && nice -n 15 python3 nightstudy.py      (the 67 days GIR keeps)
  cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && nice -n 15 python3 nightstudy.py fetch
        first fetches about a YEAR (250 trading days) of Kite's 5-minute prices for the F&O shares (~10 minutes, kept in data/nightstudy/,
        one small row a day per share), then runs the study on it. ↺ = a link that reversed after the open, the same test the other way."""
import os, re, sys, json, time, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
B930, B1030, END = 2, 14, 70                                  # the 5-minute bars that close at 09:30, 10:30, 15:10
ASIA = {"^N225", "^HSI", "^KS11", "000001.SS"}


def say(s=""):
    L.append(s); print(s, flush=True)


def history(sym, get=None):
    """[(local date, close)] for about two years of daily bars - the exchange's own date (Yahoo's gmtoffset)"""
    import requests
    get = get or requests.get
    for host in ("query1", "query2"):
        try:
            r = get("https://%s.finance.yahoo.com/v8/finance/chart/%s?range=2y&interval=1d" % (host, sym), timeout=20,
                    headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"})
            if r.status_code != 200:
                continue
            res = (r.json().get("chart") or {}).get("result") or []
            if not res:
                continue
            off = int((res[0].get("meta") or {}).get("gmtoffset") or 0); ts = res[0].get("timestamp") or []
            cl = ((res[0].get("indicators") or {}).get("quote") or [{}])[0].get("close") or []
            out = {}
            for t, c in zip(ts, cl):
                if c is not None:
                    out[(dt.datetime(1970, 1, 1) + dt.timedelta(seconds=t + off)).date()] = float(c)
            return sorted(out.items())
        except Exception:
            continue
    return []


def night_move(H, day, pts):
    """the move of the market's last session before the Indian day `day` (its local date before day): % (or points for the yield)"""
    i = [k for k, (d_, _) in enumerate(H) if d_ < day]
    if len(i) < 2:
        return None
    a, b = H[i[-2]][1], H[i[-1]][1]
    if (day - H[i[-1]][0]).days > 4:                          # the market was shut for days - no fresh night
        return None
    return (b - a) if pts else 100.0 * (b / a - 1)


LONG = os.path.join(D, "data", "nightstudy")


def day_points(A):
    """5-minute rows [ord, minute, o, h, l, c, v] -> [[ord, open, c0930, c1030, c1510, last close]] one row a day"""
    out = []
    for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
        cl = np.full(72, np.nan); op = None
        for row in p:
            k = int(row[1]) // 5
            if 0 <= k < 72:
                cl[k] = row[5]
                if k == 0:
                    op = float(row[2])
        for k in range(1, 72):
            if cl[k] != cl[k]:
                cl[k] = cl[k - 1]
        fin = np.isfinite(cl)
        if op and fin[[B930, B1030, END]].all() and fin.sum() >= 60:
            out.append([float(p[0, 0]), op, cl[B930], cl[B1030], cl[END], float(cl[fin][-1])])
    return np.array(out, dtype=np.float64)


def fetch(ndays=250):
    """Kite 5-minute prices of the F&O shares for about `ndays` trading days -> data/nightstudy/<SYM>.npy (one row a day, small).
    A share fetched today is skipped. Kite gives at most 100 days of 5-minute candles a request: pieces of 80 days."""
    import seclive as SL, getdata
    os.makedirs(LONG, exist_ok=True); kite = SL.get_kite()
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    today = dt.date.today(); frm = dt.datetime.combine(today - dt.timedelta(days=int(ndays * 1.45) + 5), dt.time(9, 15)); to = dt.datetime.combine(today, dt.time(15, 30))
    got = fails = 0
    for s in sorted(SL.fo_set()):
        f = os.path.join(LONG, re.sub(r"[^A-Z0-9]", "_", s) + ".npy")
        if os.path.exists(f) and dt.date.fromtimestamp(os.path.getmtime(f)) == today:
            continue
        if s not in tok:
            continue
        rows = []; x0 = frm; bad = None
        while x0 < to:
            x1 = min(x0 + dt.timedelta(days=80), to)
            for k in range(2):
                try:
                    rows.extend(kite.historical_data(tok[s], x0, x1, "5minute")); time.sleep(0.36); bad = None; break
                except Exception as ex:
                    bad = ex; time.sleep(2.5)
            x0 = x1 + dt.timedelta(seconds=1)
        if not rows:
            fails += 1; print("  %s: %s" % (s, str(bad)[:60]), flush=True)
            if fails >= 25 and not got:
                raise RuntimeError("Kite refused the first 25 shares - stopped")
            continue
        A = np.array([[r["date"].date().toordinal(), r["date"].hour * 60 + r["date"].minute - 555, r["open"], r["high"], r["low"], r["close"], r["volume"]] for r in rows], dtype=np.float64)
        np.save(f, day_points(A)); got += 1
        if got % 25 == 0:
            print("  fetched %d shares ..." % got, flush=True)
    print("  fetched %d shares, %d failed -> %s" % (got, fails, LONG), flush=True)


def load_long(FO):
    """{day ordinal: {sym: (prev close, open, c0930, c1030, c1510)}} from data/nightstudy/ (the year fetched by `fetch`)"""
    P = {}
    for s in FO:
        f = os.path.join(LONG, re.sub(r"[^A-Z0-9]", "_", s) + ".npy")
        try:
            A = np.load(f)
        except Exception:
            continue
        for i in range(1, len(A)):
            if A[i, 0] - A[i - 1, 0] <= 5:
                P.setdefault(int(A[i, 0]), {})[s] = (float(A[i - 1, 5]), float(A[i, 1]), float(A[i, 2]), float(A[i, 3]), float(A[i, 4]))
    return {d: v for d, v in P.items() if len(v) >= 120}


def load_india():
    """{day ordinal: {sym: (prev close, open, c0930, c1030, c1510)}} for the F&O shares"""
    import seclive as SL
    FO = SL.fo_set(); C = os.path.join(D, "data", "secstudy"); best = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    P = {}
    for s in FO:
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if not b:
            continue
        try:
            A = np.load(os.path.join(C, b[1]))
        except Exception:
            continue
        if A.ndim != 2 or A.shape[1] < 7 or not len(A):
            continue
        prev = None
        for p in np.split(A, np.flatnonzero(np.diff(A[:, 0])) + 1):
            day = int(p[0, 0]); cl = np.full(72, np.nan); op = None
            for row in p:
                k = int(row[1]) // 5
                if 0 <= k < 72:
                    cl[k] = row[5]
                    if k == 0:
                        op = float(row[2])
            for k in range(1, 72):
                if cl[k] != cl[k]:
                    cl[k] = cl[k - 1]
            if prev is not None and day - prev[0] <= 5 and op and np.isfinite(cl[[B930, B1030, END]]).all():
                P.setdefault(day, {})[s] = (prev[1], op, float(cl[B930]), float(cl[B1030]), float(cl[END]))
            if np.isfinite(cl).sum() >= 60:
                prev = (day, float(cl[np.isfinite(cl)][-1]))
    return {d: v for d, v in P.items() if len(v) >= 120}


def measures(v):
    pc, op, a, b, e = v
    return (op / pc - 1, b / a - 1, e / a - 1)              # the gap, 09:30 -> 10:30, 09:30 -> 15:10


def main():
    import morningmkts as MM
    import seclive as SL
    SEC, _ = SL.universe(); FO = SL.fo_set()
    P = load_india(); src = "data/secstudy"
    PL = load_long(FO)
    if len(PL) > len(P):
        P, src = PL, "data/nightstudy (the year fetched)"
    days = sorted(P)
    if len(days) < 20:
        say("❌ 5-minute prices for only %d days in data/secstudy - run sectorstudy.py once" % len(days)); return
    say("📊 DO THE OVERNIGHT MARKET LINKS PAY AFTER THE OPEN? · %d Indian days (%s to %s, %s) · the links of the 07:00 morning list (morningmkts.py)" % (
        len(days), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), src))
    AV = {d: np.mean([measures(v) for v in P[d].values()], axis=0) for d in days}     # the average F&O share each day
    mid = days[len(days) // 2]; av = lambda x: float(np.mean(x)) if len(x) else float("nan")
    say("  how to read: each number is in the link's direction and beyond the average F&O share that day ('whole market': the average share itself)")
    say("  · 'gap' = the opening gap (not tradable) · '9:30→10:30', '9:30→15:10' = after the open · 'right' = % of share-days the right way · 'sure' = the night-by-night average / its error (2.5+ needed: about 40 links and sizes are tested, so 2 would pass one by luck most runs)")
    say("  ✔ = 9:30→15:10 +0.10%+ in both halves of the days, sure 2.5+, 8+ nights")
    say("  Asia (Japan, Hong Kong, Korea, Shanghai) is not tested: it is still trading at 09:15, its close would be hindsight")
    OUT = {}; H = {}
    for sym, name, big, links in MM.LINKS:
        if sym in ASIA:
            continue
        H[sym] = history(sym); time.sleep(0.4)
        if len(H[sym]) < 30:
            say(""); say("%s: Yahoo's history not read (%d days) - not tested" % (name, len(H[sym]))); continue
        pts = sym == "^TNX"
        NM = {d: night_move(H[sym], dt.date.fromordinal(d), pts) for d in days}
        NM = {d: x for d, x in NM.items() if x is not None and x == x}
        say(""); say("%s · big = %s%s · %d nights read, %d big, %d half-size+" % (name, big, " pts" if pts else "%", len(NM), sum(1 for x in NM.values() if abs(x) >= big),
                                                                             sum(1 for x in NM.values() if abs(x) >= big / 2)))
        for sec, shares, sign, why in links:
            key = "%s|%s" % (sym, sec)
            if sign == 0:
                say("    %-22s (direction unclear in the list - not tested)" % sec); continue
            sh = list(shares) or ([s for s in sorted(FO) if SEC.get(s) == sec] if sec != "whole market" else [])   # an empty list: GIR's shares of that sector
            if sec != "whole market" and not sh:
                say("    %-22s (no F&O share in GIR's sector of that name - not tested)" % sec); continue
            rows = {"big": [], "half": []}; cx, cg, ca = [], [], []
            for d, x in NM.items():
                y = sign * (1 if x > 0 else -1)
                if sh:
                    M_ = [np.array(measures(P[d][s])) - AV[d] for s in sh if s in P[d]]     # each beyond the average F&O share that day
                    if not M_:
                        continue
                else:
                    M_ = [AV[d]]
                cx.append(sign * x); cg.append(float(np.mean([m[0] for m in M_]))); ca.append(float(np.mean([m[2] for m in M_])))
                for k, lim in (("big", big), ("half", big / 2)):
                    if abs(x) >= lim:
                        for m in M_:
                            rows[k].append((d, y * m[0], y * m[1], y * m[2]))
            def corr(a, b):
                return float(np.corrcoef(a, b)[0, 1]) if len(a) >= 10 and np.std(a) > 0 and np.std(b) > 0 else float("nan")
            v = {"sec": sec, "shares": sh, "corr_gap": round(corr(cx, cg), 2), "corr_after": round(corr(cx, ca), 2)}
            for k in ("big", "half"):
                R = rows[k]; nd = len({r[0] for r in R})
                if nd < 3:
                    v[k] = {"nights": nd}; continue
                h1 = [r[3] for r in R if r[0] < mid]; h2 = [r[3] for r in R if r[0] >= mid]
                pn = [av([r[3] for r in R if r[0] == d_]) for d_ in sorted({r[0] for r in R})]      # one number a night - a night's shares move together
                tt = float(np.mean(pn) / (np.std(pn, ddof=1) / np.sqrt(len(pn)))) if len(pn) >= 3 and np.std(pn, ddof=1) > 0 else 0.0
                ok = nd >= 8 and len(h1) and len(h2) and av(h1) >= 0.001 and av(h2) >= 0.001 and tt >= 2.5
                v[k] = {"nights": nd, "cases": len(R), "gap": round(100 * av([r[1] for r in R]), 2), "gap_right": round(100 * av([1 if r[1] > 0 else 0 for r in R])),
                        "a1030": round(100 * av([r[2] for r in R]), 2), "a1510": round(100 * av([r[3] for r in R]), 2),
                        "right": round(100 * av([1 if r[3] > 0 else 0 for r in R])), "t": round(tt, 1), "h1": round(100 * av(h1), 2) if h1 else None, "h2": round(100 * av(h2), 2) if h2 else None, "ok": bool(ok)}
            OUT[key] = v
            lab = ("/".join(sh[:4]) + ("…" if len(sh) > 4 else "")) if sh else "the average F&O share"
            say("    %-22s %-34s corr: gap %+.2f · after the open %+.2f" % (sec, lab[:34], v["corr_gap"], v["corr_after"]))
            for k, nm in (("big", "big nights"), ("half", "half-size+")):
                z = v.get(k) or {}
                if z.get("nights", 0) < 3:
                    say("        %-11s %d nights - too few" % (nm, z.get("nights", 0))); continue
                say("        %-11s %2d nights %4d cases │ gap %+.2f%% (right %3d%%) │ 9:30→10:30 %+.2f%% · 9:30→15:10 %+.2f%% (right %3d%%, halves %s / %s, sure %.1f) %s" % (
                    nm, z["nights"], z["cases"], z["gap"], z["gap_right"], z["a1030"], z["a1510"], z["right"],
                    "%+.2f" % z["h1"] if z["h1"] is not None else "-", "%+.2f" % z["h2"] if z["h2"] is not None else "-", z["t"], "✔" if z["ok"] else "✘"))
    for v in OUT.values():                                   # the link's verdict: ✔ on its big nights AND holding on the half-size nights too
        bg, hf = v.get("big") or {}, v.get("half") or {}
        v["ok"] = bool(bg.get("ok") and (hf.get("t") or 0) >= 2.0 and (hf.get("h1") or 0) > 0 and (hf.get("h2") or 0) > 0)
        v["fade"] = bool((bg.get("nights") or 0) >= 8 and (bg.get("t") or 0) <= -2.5 and (bg.get("h1") or 0) <= -0.1 and (bg.get("h2") or 0) <= -0.1
                         and (hf.get("t") or 0) <= -2.0 and (hf.get("h1") or 0) < 0 and (hf.get("h2") or 0) < 0)
    ok = [k for k, v in OUT.items() if v["ok"]]; fd = [k for k, v in OUT.items() if v["fade"]]
    say(""); say("✔ LINKS THAT PAID AFTER THE OPEN (✔ on the big nights, and holding on the half-size nights): %s" % (", ".join(ok) if ok else "none"))
    say("↺ LINKS THAT REVERSED AFTER THE OPEN (the same test the other way - the gap went with the night, then the shares gave it back): %s" % (", ".join(fd) if fd else "none"))
    say("  on made-up prices with NO real link, this rule passed a link by luck in 1 run of 12 - a ✔ is evidence, not proof; it is re-run as days add up")
    say("  (a link can still be right about the GAP - that is in the price before anyone can trade; the 07:00 list shows it as information)")
    try:
        json.dump({"at": time.strftime("%Y-%m-%d %H:%M"), "days": len(days), "links": OUT}, open(os.path.join(D, "data", "nightstudy.json"), "w"), ensure_ascii=False)
        open(os.path.join(D, "data", "nightstudy.txt"), "w").write("\n".join(L) + "\n"); say("  saved: data/nightstudy.txt and data/nightstudy.json")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    if sys.argv[1:2] == ["fetch"]:                           # needs Kite: cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 nightstudy.py fetch
        fetch(int(sys.argv[2]) if sys.argv[2:] and sys.argv[2].isdigit() else 250)
    main()
