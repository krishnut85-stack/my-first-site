#!/usr/bin/env python3
"""crosscheck.py - patch 376: GIR CHECKS ITS OWN NUMBERS (Rama, 17 Nov: "all these values decide the trade - I have been telling you to check all
the values on all the pages, each point and decimal; you run and come back in seconds saying OK, but I find the mistake" - NAM-INDIA in two
sectors, IDEA's futures OI -73.5% in one place and +29.7% in another, yesterday's news shown as today's reason).
Every check compares the SAME value wherever GIR keeps it - mistakes are found by GIR, not by Rama. READ ONLY: it changes nothing.
  LIVE (every 5 minutes in market hours)
    C1 DAY CHANGE   each F&O share's % today: the live price feed (quotes_live.json) · the movers list (dash_state.json) · the sector reader
                    (seclive.json) - they must agree within 0.3 points
    C2 FUTURES OI   the movers list's OI % and build-up word against FUTURES BY MONTH (futlive.json, all months): a near-month contract flagged as a
                    data mismatch must not drive a word (IDEA's LU against the real SHORT BUILD-UP); the two words must agree
    C3 SECTOR       each F&O share's sector: the SECTORS box (seclive) against the page's sector list (nsesec.page_map, the movers filter)
    C4 STALE        each feed's age against its promise: live prices 1 min · sectors 1 min · movers 1 min · futures by month 6 min · heads-up 6 min
    C5 OPPOSITE     the same share called CE and PE within 30 minutes (GIR's alert log)
    C6 NEWS SIDE    a headline whose word-reading direction is the opposite of the AI's full-story reading (the 12:42 LAURUSLABS story: -1 vs BULLISH)
  AFTER THE CLOSE (--eod, from about 18:30 when NSE publishes it)
    C7 NSE FILE     NSE's own end-of-day file (sec_bhavdata_full): each F&O share's previous close (the base of every "% today" on GIR) and its last
                    price - against what GIR used; the base must agree within 0.05%
Writes data/crosscheck.json (the page's ⚠ CHECK) and data/crosscheck.txt; keeps each evening's report in data/crosscheck/<day>.txt.
  python3 crosscheck.py          one live pass, printed
  python3 crosscheck.py --eod    the after-close check against NSE's file"""
import os, re, sys, io, csv, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "crosscheck.json")
STALE = (("quotes_live.json", 60, "live prices"), ("data/seclive.json", 60, "sectors"), ("dash_state.json", 60, "movers / F&O desk"),
         ("data/futlive.json", 360, "futures by month"), ("data/headsup.json", 360, "heads-up"))


def _j(*p):
    for b in (D, os.path.join(D, "data")):
        try:
            return json.load(open(os.path.join(b, *p)))
        except Exception:
            pass
    return {}


def _path(rel):
    for b in (D,):
        p = os.path.join(b, rel)
        if os.path.exists(p):
            return p
    p = os.path.join(D, "data", os.path.basename(rel))
    return p if os.path.exists(p) else None


def now():
    return dt.datetime.now(IST)


def fo_set():
    try:
        import seclive
        return seclive.fo_set()
    except Exception:
        return set()


def live(n=None):
    n = n or now(); F = []; info = {}
    add = lambda lvl, chk, sym, a, b, note: F.append({"lvl": lvl, "chk": chk, "s": sym, "a": a, "b": b, "note": note})
    FO = fo_set()
    ql = _j("quotes_live.json"); Q = ql.get("q") or {}
    st = _j("dash_state.json"); FP = {f.get("s"): f for f in (st.get("fo_paths") or []) if f.get("s")}
    sl = _j("seclive.json"); SLF = {}
    for x in sl.get("sectors") or []:
        for f in x.get("fol") or []:
            SLF[f[0]] = (f[1], x["name"])
    fl = _j("futlive.json"); FR = fl.get("rows") or fl.get("r") or {}
    # C1 DAY CHANGE
    n1 = 0
    for s in sorted(FO or set(Q)):
        vals = []
        if s in Q and len(Q[s]) > 1 and Q[s][1] is not None:
            vals.append(("live price feed", float(Q[s][1])))
        if s in FP and FP[s].get("chg") is not None:
            vals.append(("movers list", float(FP[s]["chg"])))
        if s in SLF and SLF[s][0] is not None:
            vals.append(("sectors box", float(SLF[s][0])))
        if len(vals) >= 2:
            n1 += 1; lo, hi = min(vals, key=lambda v: v[1]), max(vals, key=lambda v: v[1])
            if hi[1] - lo[1] > 0.3:
                add("⚠", "C1 day change", s, "%s %+.2f%%" % (hi[0], hi[1]), "%s %+.2f%%" % (lo[0], lo[1]), "%.2f points apart" % (hi[1] - lo[1]))
    info["C1"] = "%d shares compared" % n1
    # C2 FUTURES OI
    n2 = 0
    for s, r in FR.items():
        f = FP.get(s)
        if not f:
            continue
        n2 += 1; mov_oi = f.get("foi") if f.get("foi") is not None else f.get("oi"); mov_bu = str(f.get("bu") or "").upper().replace("_", " ")
        tot = (r.get("total") or {}).get("pc"); fbu = str(r.get("bu") or "").upper()
        if r.get("odd"):
            near = next((m for m in r.get("months") or [] if m.get("odd")), {})
            if mov_oi is not None and tot is not None and abs(float(mov_oi) - float(tot)) > 5:
                add("⚠", "C2 futures OI", s, "movers list OI %+.1f%%%s" % (float(mov_oi), (" · " + mov_bu) if mov_bu else ""),
                    "futures by month TOTAL %+.1f%% · %s" % (float(tot), fbu or "-"), "the near month (%s) is a data mismatch - the movers list uses it" % (near.get("m") or "near"))
        elif mov_oi is not None and tot is not None and abs(float(mov_oi) - float(tot)) > 3 and abs(float(mov_oi)) > 2:
            add("·", "C2 futures OI", s, "movers list OI %+.1f%%" % float(mov_oi), "futures by month TOTAL %+.1f%%" % float(tot), "near month against all months (rollover?)")
        if mov_bu and fbu and mov_bu != fbu and "BUILD" in mov_bu + fbu and not r.get("rollover"):
            add("⚠", "C2 build-up word", s, "movers list %s" % mov_bu, "futures by month %s" % fbu, "two different words for the same share")
    info["C2"] = "%d shares compared" % n2
    # C3 SECTOR
    try:
        import seclive, nsesec
        SEC, _ = seclive.universe()
        pm = nsesec.page_map(sorted(FO)) if FO else {}
        PS = {s: name for name, syms in (pm or {}).items() for s in syms}
        n3 = 0
        for s in sorted(FO):
            a, b = SEC.get(s), PS.get(s)
            if a and b:
                n3 += 1
                if a.lower() != str(b).lower():
                    add("⚠", "C3 sector", s, "SECTORS box: %s" % a, "page sector list / movers filter: %s" % b, "the same share in two sectors")
            elif a and not b:
                add("·", "C3 sector", s, "SECTORS box: %s" % a, "page sector list: missing", "")
        info["C3"] = "%d shares compared" % n3
    except Exception as ex:
        info["C3"] = "not read: %s" % str(ex)[:60]
    # C4 STALE (market hours only)
    if n.weekday() < 5 and "09:20" <= n.strftime("%H:%M") <= "15:30":
        for rel, mx, nm in STALE:
            p = _path(rel)
            if not p:
                add("⚠", "C4 stale", "-", nm, "file missing", rel); continue
            age = time.time() - os.path.getmtime(p)
            if age > mx * 3:
                add("⚠", "C4 stale", "-", nm, "last written %d min ago" % (age // 60), "it should refresh every %s" % ("%d s" % mx if mx < 120 else "%d min" % (mx // 60)))
        info["C4"] = "%d feeds" % len(STALE)
    # C5 OPPOSITE CALLS and C6 NEWS SIDE - GIR's alert log
    day = str(n.date())
    try:
        p = _path("tomorrow.db")
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=10)
        A = c.execute("select t, sym, side, text from alerts where day=? and sym is not null and sym != 'MARKET' order by t", (day,)).fetchall(); c.close()
        calls = {}
        for t, s, side, text in A:
            first = (text or "").split("\n")[0]
            if side in ("CE", "PE") and re.search(r"BUY|TRADE ALERT|ENTER NOW|MOVE CARD|TRADE CARD|HEADS-UP", first):
                calls.setdefault(s, []).append((t[:5], side, first[:70]))
        n5 = 0
        for s, L_ in calls.items():
            for i in range(1, len(L_)):
                t0, s0, f0 = L_[i - 1]; t1, s1, f1 = L_[i]
                m0, m1 = int(t0[:2]) * 60 + int(t0[3:]), int(t1[:2]) * 60 + int(t1[3:])
                if s0 != s1 and m1 - m0 <= 30:
                    n5 += 1; add("⚠", "C5 opposite calls", s, "%s %s: %s" % (t0, s0, f0), "%s %s: %s" % (t1, s1, f1), "%d min apart" % (m1 - m0))
        info["C5"] = "%d calls read" % sum(len(v) for v in calls.values())
        n6 = 0
        try:
            import newsroom
            for t, s, side, text in A:
                m = re.search(r"CLAUDE read the full story: (BULLISH|BEARISH)", text or "")
                if not m:
                    continue
                ai = 1 if m.group(1) == "BULLISH" else -1
                for it in newsroom.items_for(s, 12, 0) or []:
                    h = str(it.get("h") or "")
                    if h and h[:40] in (text or "") and it.get("side") in (1, -1) and it.get("side") != ai:
                        n6 += 1; add("⚠", "C6 news side", s, "headline words: %s" % ("UP" if it["side"] > 0 else "DOWN"), "AI read the story: %s" % m.group(1), h[:90])
                        break
        except Exception:
            pass
        info["C6"] = "%d disagreements" % n6
    except Exception as ex:
        info["C5"] = "not read: %s" % str(ex)[:60]
    return F, info


def eod(n=None):
    """C7: NSE's own end-of-day file against the base GIR used for '% today'"""
    n = n or now(); F = []; info = {}
    d = n.date() if n.strftime("%H:%M") >= "18:00" else n.date() - dt.timedelta(days=1)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    url = "https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_%s.csv" % d.strftime("%d%m%Y")
    try:
        import requests
        r = requests.get(url, timeout=30, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", "Referer": "https://www.nseindia.com/"})
        if not r.ok or "SYMBOL" not in r.text[:300]:
            info["C7"] = "NSE's file for %s not available yet (%s)" % (d, r.status_code); return F, info
        rows = list(csv.DictReader(io.StringIO(r.text)))
    except Exception as ex:
        info["C7"] = "NSE's file not read: %s" % str(ex)[:60]; return F, info
    N = {}
    for x in rows:
        x = {k.strip(): (v or "").strip() for k, v in x.items()}
        if x.get("SERIES") == "EQ":
            try:
                N[x["SYMBOL"]] = (float(x["PREV_CLOSE"]), float(x["LAST_PRICE"]), float(x["CLOSE_PRICE"]))
            except Exception:
                pass
    FO = fo_set(); Q = (_j("quotes_live.json").get("q") or {}); n7 = 0
    for s in sorted(FO):
        if s not in N or s not in Q or len(Q[s]) < 2 or not Q[s][0]:
            continue
        px, chg = float(Q[s][0]), float(Q[s][1])
        base = px / (1 + chg / 100.0) if chg > -99 else None
        pc_, last_, close_ = N[s]; n7 += 1
        if base and abs(base / pc_ - 1) > 0.0005:
            F.append({"lvl": "⚠", "chk": "C7 NSE file", "s": s, "a": "GIR's base for %% today ₹%.2f" % base, "b": "NSE's previous close ₹%.2f" % pc_,
                      "note": "%.2f%% apart - every %% today on this share is off" % (100 * (base / pc_ - 1))})
        if abs(px / last_ - 1) > 0.003:
            F.append({"lvl": "·", "chk": "C7 NSE file", "s": s, "a": "GIR's last price ₹%.2f" % px, "b": "NSE's last price ₹%.2f (close ₹%.2f)" % (last_, close_),
                      "note": "GIR's feed stopped before the close?"})
    info["C7"] = "%d F&O shares against NSE's file for %s" % (n7, d)
    return F, info


def run(mode="live"):
    n = now()
    F, info = live(n) if mode == "live" else eod(n)
    F.sort(key=lambda x: (x["lvl"] != "⚠", x["chk"], x["s"]))
    o = {"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": str(n.date()), "mode": mode, "n": sum(1 for x in F if x["lvl"] == "⚠"), "items": F[:300], "info": info}
    try:
        prev = _j("crosscheck.json")
        if mode == "eod":
            o["live"] = prev if prev.get("mode") == "live" else prev.get("live")
        os.makedirs(os.path.join(D, "data", "crosscheck"), exist_ok=True)
        json.dump(o, open(OUT + ".tmp", "w"), ensure_ascii=False); os.replace(OUT + ".tmp", OUT)
        txt = ["GIR CROSS-CHECK %s %s (%s) · %d to look at" % (o["day"], o["at"], mode, o["n"])] + ["  %s: %s" % (k, v) for k, v in info.items()] + \
              ["  %s %-18s %-12s %s  ≠  %s  %s" % (x["lvl"], x["chk"], x["s"], x["a"], x["b"], ("(" + x["note"] + ")") if x["note"] else "") for x in F]
        open(os.path.join(D, "data", "crosscheck.txt"), "w").write("\n".join(txt) + "\n")
        if mode == "eod" or n.strftime("%H:%M") >= "15:25":
            with open(os.path.join(D, "data", "crosscheck", "%s.txt" % o["day"]), "a") as fh:
                fh.write("\n".join(txt) + "\n\n")
    except Exception as ex:
        print("not saved: %s" % ex)
    return o


if __name__ == "__main__":
    o = run("eod" if "--eod" in sys.argv else "live")
    print(open(os.path.join(D, "data", "crosscheck.txt")).read() if os.path.exists(os.path.join(D, "data", "crosscheck.txt")) else json.dumps(o)[:2000])
