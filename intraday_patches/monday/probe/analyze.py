#!/usr/bin/env python3
"""analyze.py - I1-I8 external delays for one day (default today, IST): source time -> GIR first seen -> page (SSE probe) in seconds.
Reads only: v2 data files, the old engine's news.db / tv.db (mode=ro), and the probe files next to this script.
  python3 analyze.py [--day YYYY-MM-DD] [--from HH:MM] [--to HH:MM] [--tag label]
Writes <out>/external_delays.json (+ the per-item tables used by the .md)."""
import json, os, sys, time, sqlite3, statistics, datetime as dt, collections, re, argparse

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
P = os.path.dirname(os.path.abspath(__file__))
V2D = "/home/globalbot/intraday/v2/data"
OLD = "/home/globalbot/intraday"

ap = argparse.ArgumentParser()
ap.add_argument("--day", default=dt.datetime.now(IST).strftime("%Y-%m-%d"))
ap.add_argument("--from", dest="hfrom", default="09:00")
ap.add_argument("--to", dest="hto", default="15:35")
ap.add_argument("--out", default=os.path.join(P, "out"))
ap.add_argument("--tag", default="")
A = ap.parse_args()
os.makedirs(A.out, exist_ok=True)


def ep(day, hm):
    return dt.datetime.strptime(day + " " + hm, "%Y-%m-%d %H:%M").replace(tzinfo=IST).timestamp()


T0, T1 = ep(A.day, A.hfrom), ep(A.day, A.hto)


def hms(t):
    return dt.datetime.fromtimestamp(t, IST).strftime("%H:%M:%S") if isinstance(t, (int, float)) and t else None


def iso_ep(s):
    if s in (None, ""):
        return None
    if isinstance(s, (int, float)):
        return float(s)
    try:
        return dt.datetime.fromisoformat(str(s)).timestamp()
    except Exception:
        return None


def jl(path):
    out = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    out.append(json.loads(line))
                except Exception:
                    pass
    except FileNotFoundError:
        pass
    return out


def stats(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    if not xs:
        return {"n": 0, "median": None, "p90": None, "worst": None}
    xs = sorted(xs)
    return {"n": len(xs), "median": round(statistics.median(xs), 1), "p90": round(xs[min(len(xs) - 1, int(0.9 * len(xs)))], 1), "worst": round(xs[-1], 1)}


def spread(rows, k=5, key=lambda r: r["src_t"]):
    """k rows spread over the window (first, then evenly by time)"""
    rows = sorted(rows, key=key)
    if len(rows) <= k:
        return rows
    step = (len(rows) - 1) / (k - 1)
    return [rows[round(i * step)] for i in range(k)]


# ---------------------------------------------------------------- page probe (first SSE delta carrying each item)
PAGE = collections.defaultdict(dict)          # fact -> key -> page_ts (non-pre only; earliest)
PAGE_ITEMS = collections.defaultdict(list)
for r in jl(os.path.join(P, "page_seen.jsonl")):
    if r.get("pre"):
        PAGE[r["fact"]].setdefault("__pre__" + r["key"], r["page_ts"])
        continue
    d = PAGE[r["fact"]]
    if r["key"] not in d or r["page_ts"] < d[r["key"]]:
        d[r["key"]] = r["page_ts"]
        PAGE_ITEMS[r["fact"]].append(r)


def page_of(fact, key):
    return PAGE[fact].get(key)


def page_by(fact, pred):
    best = None
    for r in PAGE_ITEMS[fact]:
        if pred(r["item"]):
            if best is None or r["page_ts"] < best:
                best = r["page_ts"]
    return best


RES = {"day": A.day, "window": [A.hfrom, A.hto], "made": dt.datetime.now(IST).isoformat(timespec="seconds"), "tag": A.tag, "sources": {}}


def verdict(d, target):
    if d is None:
        return "NOT MEASURED"
    return "OK" if d <= target else "LATE"


def add(src, target, items, extra=None, dead=None):
    for it in items:
        d = it.get("delay_s")
        it["verdict"] = verdict(d, target)
    ds = [it.get("delay_s") for it in items]
    RES["sources"][src] = dict({"target_s": target, "items": items, "stats5": stats(ds)}, **(extra or {}))
    if dead:
        RES["sources"][src]["dead_or_missing"] = dead


# ---------------------------------------------------------------- I1 filings
def i1():
    rows = [r for r in jl(os.path.join(V2D, "filings.jsonl")) if T0 <= (r.get("first_seen") or 0) <= T1]
    lag = [r for r in jl(os.path.join(V2D, "filings_lag.jsonl")) if T0 <= (r.get("t") or 0) <= T1 and r.get("lag_s") is not None]
    cand = []
    for r in rows:
        k = "%s|%s|%s|%s" % (r.get("exch"), r.get("sym"), r.get("exch_time"), (r.get("subject") or "")[:60])
        pg = page_of("news.filings", k)
        if not r.get("exch_time"):
            continue
        cand.append({"src_t": r["exch_time"], "source": "%s filing" % r["exch"], "item": "%s - %s" % (r["sym"], (r.get("subject") or "")[:70]),
                     "source_time": hms(r["exch_time"]), "gir_seen": hms(r["first_seen"]), "page_seen": hms(pg),
                     "gir_lag_s": round(r["first_seen"] - r["exch_time"], 1), "page_after_gir_s": round(pg - r["first_seen"], 1) if pg else None,
                     "delay_s": round(pg - r["exch_time"], 1) if pg else None, "time_from": "exchange dissemination time (exchdisstime / DissemDT)"})
    pick = []
    for ex in ("NSE", "BSE"):
        pick += spread([c for c in cand if c["source"].startswith(ex) and c["page_seen"]], 3 if ex == "NSE" else 2)
    pick = sorted(pick, key=lambda c: c["src_t"])
    by = {}
    for ex in ("NSE", "BSE"):
        by[ex] = {"all_filings_gir_lag": stats([r["lag_s"] for r in lag if r["exch"] == ex]),
                  "fo_filings_page_delay": stats([c["delay_s"] for c in cand if c["source"].startswith(ex)]),
                  "fo_filings_gir_lag": stats([c["gir_lag_s"] for c in cand if c["source"].startswith(ex)])}
    st = {}
    try:
        st = json.load(open(os.path.join(V2D, "filings_state.json")))
    except Exception:
        pass
    add("I1 filings (NSE + BSE)", 15, pick, {"by_exchange": by, "fo_rows": len(cand), "all_rows": len(lag), "state": st.get("sites")})


# ---------------------------------------------------------------- I3 wires (news.db WIRE = F&O company headlines; macro.json = market headlines)
PUBS = [("ET", r"economictimes|etnownews"), ("Moneycontrol", r"moneycontrol"), ("CNBC-TV18", r"cnbctv18"), ("Business Standard", r"business-standard"),
        ("NDTV Profit", r"ndtvprofit"), ("Mint", r"livemint"), ("BusinessLine / Hindu", r"thehindu"), ("Business Today", r"businesstoday"),
        ("TradingView", r"tradingview"), ("Reuters", r"reuters")]


def pub_of(dom):
    for n, rx in PUBS:
        if re.search(rx, dom or ""):
            return n
    return dom or "?"


def i3():
    c = sqlite3.connect("file:%s?mode=ro" % os.path.join(OLD, "news.db"), uri=True, timeout=5)
    rows = c.execute("select sym, src, domain, t_pub, t_seen, h, l from items where t_seen between ? and ?", (T0, T1)).fetchall()
    c.close()
    cand, allw, gn = [], collections.defaultdict(list), []
    for sym, src, dom, tp, ts, h, l in rows:
        if not tp or not ts:
            continue
        lag = ts - tp
        if src == "GOOGLE NEWS":
            gn.append(lag); continue
        if src != "WIRE":
            continue
        p = pub_of(dom)
        allw[p].append(lag)
        pg = page_by("news.list", lambda it, l=l, h=h, sym=sym: (l and it.get("link") == l) or (it.get("s") == sym and (it.get("h") or "")[:60] == (h or "")[:60]))
        cand.append({"src_t": tp, "source": "wire %s" % p, "pub": p, "item": "%s - %s" % (sym, (h or "")[:80]), "source_time": hms(tp), "gir_seen": hms(ts),
                     "page_seen": hms(pg), "gir_lag_s": round(lag, 1), "page_after_gir_s": round(pg - ts, 1) if pg else None,
                     "delay_s": round(pg - tp, 1) if pg else None, "time_from": "the publisher's RSS pubDate / article time", "link": l})
    # macro (market headlines): GIR seen = first time the item was in data/macro.json (probe/filewatch, file mtime)
    mac = []
    for r in jl(os.path.join(P, "file_seen.jsonl")):
        if r.get("file") != "macro.json" or r.get("pre") or not r.get("t_item"):
            continue
        gs = r.get("file_mtime") or r.get("seen")
        if not (T0 <= gs <= T1):
            continue
        pg = page_by("news.list", lambda it, r=r: it.get("s") == "MARKET" and ((r.get("link") and it.get("link") == r.get("link")) or (it.get("h") or "")[:60] == (r.get("h") or "")[:60]))
        mac.append({"src_t": r["t_item"], "source": "wire (market headline) %s" % (r.get("src") or "?"), "pub": r.get("src"), "item": (r.get("h") or "")[:90],
                    "source_time": hms(r["t_item"]), "gir_seen": hms(gs), "page_seen": hms(pg), "gir_lag_s": round(gs - r["t_item"], 1),
                    "page_after_gir_s": round(pg - gs, 1) if pg else None, "delay_s": round(pg - r["t_item"], 1) if pg else None,
                    "time_from": "the publisher's RSS pubDate"})
    want = ["ET", "Moneycontrol", "CNBC-TV18", "Business Standard", "NDTV Profit"]
    pick = []
    for p in want:
        L = sorted([x for x in cand if x["pub"] == p and x["page_seen"]], key=lambda x: x["src_t"])
        if not L:
            L = sorted([x for x in mac if p.split()[0].lower() in (x["pub"] or "").lower() and x["page_seen"]], key=lambda x: x["src_t"])
        if L:
            pick.append(L[len(L) // 2])
    for x in sorted(cand + mac, key=lambda x: x["src_t"]):
        if len(pick) >= 5:
            break
        if x["page_seen"] and x not in pick:
            pick.append(x)
    per = {p: stats(v) for p, v in allw.items()}
    status = {}
    try:
        ms = json.load(open(os.path.join(OLD, "data", "macro_status.json")))
        status = {k: {"code": v.get("code"), "n": v.get("n")} for k, v in ms.items() if isinstance(v, dict)}
    except Exception:
        pass
    dead = [k for k, v in status.items() if v.get("n") == 0 or str(v.get("code")) not in ("200", "304")]
    add("I3 wires / publishers", 30, sorted(pick, key=lambda x: x["src_t"]),
        {"wire_fo_by_publisher_gir_lag": per, "wire_fo_page_delay": stats([x["delay_s"] for x in cand]), "wire_fo_gir_lag": stats([x["gir_lag_s"] for x in cand]),
         "market_headline_page_delay": stats([x["delay_s"] for x in mac]), "market_headline_gir_lag": stats([x["gir_lag_s"] for x in mac]),
         "google_news_gir_lag": stats(gn), "feed_status": status, "n_wire_fo": len(cand), "n_market": len(mac)},
        dead=["feed returns 0 items or an error: " + ", ".join(sorted(dead))] if dead else None)
    json.dump({"wire_fo": cand, "market": mac}, open(os.path.join(A.out, "i3_all.json"), "w"), ensure_ascii=False, indent=0, default=str)


# ---------------------------------------------------------------- I2 TV (tv.db -> newsmap signal -> news.map on the page; newsread reading)
def i2():
    c = sqlite3.connect("file:%s?mode=ro" % os.path.join(OLD, "data", "tv.db"), uri=True, timeout=5)
    tv = c.execute("select ts, ch, secs, took, length(text) from tv where ts between ? and ?", (T0, T1)).fetchall()
    c.close()
    by = collections.defaultdict(list)
    for r in tv:
        by[r[1]].append(r)
    chans = {}
    for ch, L in by.items():
        L.sort()
        gaps = [(b[0] - a[0], a[0]) for a, b in zip(L, L[1:])]
        holes = [{"from": hms(t), "secs": round(g)} for g, t in gaps if g > 60]
        chans[ch] = {"chunks": len(L), "empty_text": sum(1 for x in L if not x[4]), "reader_s": stats([x[3] for x in L]),
                     "holes_over_60s": holes[:20], "n_holes": len(holes), "first": hms(L[0][0]), "last": hms(L[-1][0])}
    sig = [r for r in jl(os.path.join(V2D, "newsmap_signals.jsonl")) if T0 <= (iso_ep(r.get("t")) or 0) <= T1]
    cand = []
    for r in sig:
        tvi = [x for x in (r.get("inputs") or []) if x.get("via") == "tv.db"]
        if not tvi:
            continue
        names = (r.get("ce") or []) + (r.get("pe") or [])
        ts = iso_ep(tvi[0].get("t_seen"))
        st = iso_ep(r.get("t"))
        pg = page_by("news.map", lambda it, r=r: it.get("t") == r.get("t") and (it.get("event") or "")[:60] == (r.get("event") or "")[:60])
        cand.append({"src_t": ts - 12, "source": tvi[0].get("src"), "item": "%s -> %s" % ((tvi[0].get("h") or "")[:70], ",".join(names[:4]) or "no share"),
                     "source_time": "%s-%s (spoken in this 10 s segment)" % (hms(ts - 14), hms(ts)), "gir_seen": hms(st), "page_seen": hms(pg),
                     "tv_text_at": hms(ts), "gir_lag_s": round(st - (ts - 12), 1), "page_after_gir_s": round(pg - st, 1) if pg else None,
                     "delay_s": round(pg - (ts - 12), 1) if pg else None, "named": bool(names),
                     "time_from": "speech segment (tv.db ts = segment read start; speech = ts-14..ts); YouTube's own delay behind the broadcast not measurable",
                     "label_on_page": r.get("sure")})
    named = [x for x in cand if x["named"] and x["page_seen"]]
    pick = spread(named, 5)
    rd = [r for r in jl(os.path.join(V2D, "newsread.jsonl")) if r.get("via") == "tv.db" and T0 <= (iso_ep(r.get("t")) or 0) <= T1]
    rlag = []
    for r in rd:
        try:
            t_tv = float(str(r.get("key")).rsplit(":", 1)[1])
            rlag.append(iso_ep(r["t"]) - t_tv)
        except Exception:
            pass
    calls = [r for r in jl(os.path.join(V2D, "tvcalls.jsonl")) if T0 <= (r.get("t") or 0) <= T1]
    add("I2 TV speech-to-text", 60, pick, {"channels": chans, "newsmap_tv_signals": len(cand), "newsmap_tv_page_delay": stats([x["delay_s"] for x in cand]),
                                           "newsread_tv_readings": len(rd), "newsread_tv_lag": stats(rlag), "tvcalls_rows": len(calls),
                                           "tvcalls_sample": [{k: x.get(k) for k in ("at", "ch", "sym", "call", "house", "words")} for x in calls[:8]]})


# ---------------------------------------------------------------- I4 world (Trump, FinancialJuice, Fed Register = ext rows; quotes from probe/world.jsonl)
def ext_rows(name):
    out = []
    for r in jl(os.path.join(V2D, "ext", name + ".jsonl")):
        fs = iso_ep(r.get("first_seen"))
        if fs and T0 - 8 * 3600 <= fs <= T1:
            out.append(r)
    return out


def ext_items(name, label, lo=None):
    lo = lo or T0
    cand = []
    for r in ext_rows(name):
        fs, stt = iso_ep(r.get("first_seen")), iso_ep(r.get("src_time"))
        if not (lo <= fs <= T1):
            continue
        pg = page_of("ext.recent", r.get("id"))
        cand.append({"src_t": stt or fs, "source": label, "item": (r.get("title") or "")[:90], "source_time": hms(stt) if stt else "not given by the source",
                     "gir_seen": hms(fs), "page_seen": hms(pg), "gir_lag_s": round(fs - stt, 1) if stt else None,
                     "page_after_gir_s": round(pg - fs, 1) if pg else None, "delay_s": round(pg - stt, 1) if (pg and stt) else None})
    return cand


def i4():
    tr = ext_items("trump", "Trump posts / White House (trumpstruth.org RSS)", T0 - 8 * 3600)
    fj = ext_items("fjuice", "FinancialJuice free RSS", T0 - 8 * 3600)
    fr = ext_items("fedreg", "US Federal Register", T0 - 8 * 3600)
    pick = spread([x for x in tr if x["page_seen"] and x["delay_s"] is not None], 2) + spread([x for x in fj if x["page_seen"] and x["delay_s"] is not None], 3)
    # quotes
    W = jl(os.path.join(P, "world.jsonl"))
    W = [w for w in W if T0 - 3 * 3600 <= w["t"] <= T1]
    q = {}
    ylag = collections.defaultdict(list)
    for w in W:
        for s, y in (w.get("yahoo") or {}).items():
            if y.get("rmt"):
                ylag[s].append(y["got"] - y["rmt"])
    gift = []
    for w in W:
        g = (w.get("kq") or {}).get("NSEIX:GIFT NIFTY") or {}
        pg = ((w.get("page") or {}).get("drv.gift") or {})
        if g.get("ts"):
            gift.append({"t": w["t"], "quote_ts": g["ts"], "age_at_gir_s": round(w["t"] - g["ts"], 1), "page_state": pg.get("state"), "page_src_ts": pg.get("src_ts")})
    gift_age = stats([g["age_at_gir_s"] for g in gift if T0 <= g["t"] <= T1])
    pre = [g for g in gift if g["t"] < ep(A.day, "09:00")]
    q["yahoo_quote_age_s (source time vs fetch; free Yahoo is delayed by the exchange)"] = {s: stats(v) for s, v in ylag.items()}
    q["gift_nifty_kite_age_s (market hours)"] = gift_age
    q["gift_nifty_before_09_00"] = {"samples": len(pre), "first_fresh_at": next((hms(g["t"]) for g in pre if g["age_at_gir_s"] < 120), None),
                                    "stale_samples": sum(1 for g in pre if g["age_at_gir_s"] > 300)}
    for s, nm in (("drv.copper", "COMEX copper (Yahoo HG=F)"), ("drv.brent", "Brent (Yahoo BZ=F)"), ("drv.nasdaq", "Nasdaq futures (Yahoo NQ=F)"),
                  ("drv.us10y", "US 10y (Yahoo ^TNX)"), ("drv.mcx_copper", "MCX copper (Kite)"), ("drv.mcx_aluminium", "MCX aluminium (Kite)")):
        ages = []
        for w in W:
            pg = (w.get("page") or {}).get(s) or {}
            if pg.get("src_ts") and T0 <= w["t"] <= T1:
                ages.append(w["t"] - pg["src_ts"])
        q["page %s age_s (page time - the value's own time)" % nm] = stats(ages)
    add("I4 world news + cues", 60, pick, {"trump": {"n": len(tr), "gir_lag": stats([x["gir_lag_s"] for x in tr]), "page_delay": stats([x["delay_s"] for x in tr])},
                                         "fjuice": {"n": len(fj), "gir_lag": stats([x["gir_lag_s"] for x in fj]), "page_delay": stats([x["delay_s"] for x in fj])},
                                         "fedreg": {"n": len(fr), "gir_lag": stats([x["gir_lag_s"] for x in fr])}, "quotes": q})


# ---------------------------------------------------------------- I5 regulators (v2: bonds RBI rows + circulars; old: regwatch / govwatch ids via filewatch)
def i5():
    cand = []
    for r in ext_rows("bonds"):
        if r.get("kind") != "rbi":
            continue
        fs, stt = iso_ep(r.get("first_seen")), iso_ep(r.get("src_time"))
        if not (T0 <= fs <= T1):
            continue
        pg = page_of("ext.recent", r.get("id"))
        cand.append({"src_t": stt or fs, "source": "RBI press release (v2 bonds, RSS)", "item": (r.get("title") or "")[:90], "source_time": hms(stt) if stt else "not given",
                     "gir_seen": hms(fs), "page_seen": hms(pg), "gir_lag_s": round(fs - stt, 1) if stt else None,
                     "page_after_gir_s": round(pg - fs, 1) if pg else None, "delay_s": round(pg - stt, 1) if (pg and stt) else None})
    for r in ext_rows("circulars"):
        fs, stt = iso_ep(r.get("first_seen")), iso_ep(r.get("src_time"))
        if not (T0 <= fs <= T1):
            continue
        pg = page_of("ext.recent", r.get("id"))
        cand.append({"src_t": stt or fs, "source": "exchange circular (v2 circulars)", "item": (r.get("title") or "")[:90], "source_time": hms(stt) if stt else "not given",
                     "gir_seen": hms(fs), "page_seen": hms(pg), "gir_lag_s": round(fs - stt, 1) if stt else None,
                     "page_after_gir_s": round(pg - fs, 1) if pg else None, "delay_s": round(pg - stt, 1) if (pg and stt) else None})
    for name in ("regs",):                                      # the new v2 regulator poller (after 15:35 install)
        for r in ext_rows(name):
            fs, stt = iso_ep(r.get("first_seen")), iso_ep(r.get("src_time"))
            if not (T0 <= fs <= T1):
                continue
            pg = page_of("ext.recent", r.get("id"))
            cand.append({"src_t": stt or fs, "source": "%s (v2 regs)" % r.get("kind"), "item": (r.get("title") or "")[:90],
                         "source_time": hms(stt) if stt else "not given", "gir_seen": hms(fs), "page_seen": hms(pg),
                         "gir_lag_s": round(fs - stt, 1) if stt else None, "page_after_gir_s": round(pg - fs, 1) if pg else None,
                         "delay_s": round(pg - stt, 1) if (pg and stt) else None})
    old = collections.Counter()
    oldrows = []
    for r in jl(os.path.join(P, "file_seen.jsonl")):
        if r.get("file") in ("regwatch.json", "govwatch.json") and not r.get("pre") and T0 <= (r.get("file_mtime") or 0) <= T1:
            old[r["id"].split(":", 1)[0]] += 1
            oldrows.append({"file": r["file"], "id": r["id"][:160], "gir_seen_old": hms(r["file_mtime"])})
    pick = spread([x for x in cand if x["delay_s"] is not None], 5) or spread(cand, 5)
    add("I5 regulators / Parliament / PIB", 60, pick, {"v2_rows": len(cand), "old_engine_new_ids": dict(old), "old_engine_rows": oldrows[:40]},
        dead=["no v2 poller (page shows nothing) for: SEBI, IRDAI, TRAI, CCI, DGCA, PIB, sansad.in - only the OLD regwatch / govwatch (every 2 min, Telegram, no page)"
              if not ext_rows("regs") else None, "SEBI RSS sebirss.xml returns 0 items (checked 20 Nov 07:40)"])


for fn in (i1, i3, i2, i4, i5):
    try:
        fn()
    except Exception as ex:
        import traceback
        RES["sources"][fn.__name__] = {"error": "%s: %s" % (type(ex).__name__, ex), "tb": traceback.format_exc(limit=3)}

json.dump(RES, open(os.path.join(A.out, "external_delays%s.json" % (("_" + A.tag) if A.tag else "")), "w"), ensure_ascii=False, indent=1, default=str)
for s, v in RES["sources"].items():
    print("==", s, v.get("stats5"), v.get("error") or "")
    for it in v.get("items", []):
        print("   %-28s %-60s src %-10s gir %-9s page %-9s delay %-7s %s" % (it["source"][:28], it["item"][:60], str(it["source_time"])[:10], it["gir_seen"], it["page_seen"], it["delay_s"], it["verdict"]))
