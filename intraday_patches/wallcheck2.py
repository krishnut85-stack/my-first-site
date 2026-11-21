#!/usr/bin/env python3
"""wallcheck2.py - READ ONLY (changes nothing in GIR, sends nothing, asks Zerodha nothing). THE CHECKLIST FOR TOMORROW, done properly (Rama, 15 Nov:
"for MFSL the number of contracts is very less, and LICHSGFIN is not in your list - you have to see 3 things: the density of the OI contracts and their
percentage increase or decrease for resistance and support, the market pattern, and any specific news driving it up or down").

From NSE's own end-of-day F&O file (every strike of every F&O share, with the day's OI change - not just 11 strikes), GIR's 3-year price store
(/root/hist - the share's and NIFTY's trend), GIR's delivery reading (big hands buying / selling) and GIR's news alerts (tomorrow.db):
  ROOF / FLOOR  the biggest call OI above / put OI below (within 15%) - its size in ₹ crore (OI x strike), DENSE / MEDIUM / THIN against all
                F&O shares, and how much the writers ADDED (stronger wall) or CUT (weaker - may break) that day
  SCORE /10     PE: the roof close (3% or less) · the roof dense · the roof writers adding · new futures sellers · room to the floor (3%+) ·
                the share's trend down · its sector down · NIFTY's 5 days down · big hands selling (delivery) · news ▼   (CE: the mirror)
  BREAKOUT      at the roof (1% or less) with the roof writers CUTTING and new buyers -> ▲ the roof may break (the mirror at the floor ▼)
  THIN          the option chain too small (the bottom quarter of all F&O shares in ₹) - the walls mean little, the options hard to trade
python3 wallcheck2.py                 tomorrow's checklist (NSE's last file - fetched once, kept in /root/hist)
python3 wallcheck2.py SYM SYM         only those shares, every detail
python3 wallcheck2.py --file F.zip    use a downloaded NSE file
python3 wallcheck2.py --json F.json   also write the lists for GIR's 📋 CHECKLIST page (patch 301: every market evening at 19:15 and 20:30)
ALREADY MOVED (patch 301): a share that moved 60%+ of ITS OWN typical day (the average of its last 14 days' ranges) - CIPLA (±1.6% a day) after a
2% fall is late, ABB (±5% a day) after a 1.9% rise is not - is flagged "don't chase, wait for the retest" and loses a point. No history: 1.5%."""
import os, io, re, sys, csv, json, time, zipfile, sqlite3, datetime as dt
GIR = os.environ.get("GIR_BASE", "/home/globalbot/intraday")
HIST = os.environ.get("GIR_HIST", "/root/hist")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
URL = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36", "Accept": "*/*", "Referer": "https://www.nseindia.com/"}
NEAR, ROOM, AT, ADD = 3.0, 3.0, 1.0, 10.0


def fetch(path=None):
    """-> (the trading day, the CSV rows) from NSE's last end-of-day F&O file (kept on disk)"""
    if path:
        z = zipfile.ZipFile(path); return os.path.basename(path), list(csv.DictReader(io.StringIO(z.read(z.namelist()[0]).decode("utf-8", "replace"))))
    import requests
    d = dt.datetime.now(IST).date() - dt.timedelta(days=0 if dt.datetime.now(IST).strftime("%H:%M") >= "19:00" else 1)
    os.makedirs(HIST, exist_ok=True)
    for _ in range(10):
        while d.weekday() > 4:
            d -= dt.timedelta(days=1)
        f = os.path.join(HIST, "fo_%s.csv.zip" % d.strftime("%Y%m%d"))
        if not os.path.exists(f):
            r = requests.get(URL % d.strftime("%Y%m%d"), headers=HDR, timeout=40)
            if r.status_code == 404:
                d -= dt.timedelta(days=1); continue
            r.raise_for_status(); open(f, "wb").write(r.content)
        z = zipfile.ZipFile(f)
        return str(d), list(csv.DictReader(io.StringIO(z.read(z.namelist()[0]).decode("utf-8", "replace"))))
    raise SystemExit("no NSE file found in the last 10 days")


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def chains(rows):
    """-> {sym: {spot, ex, ce: {K: (oi, chg)}, pe: {...}, fut: [oi, chg, close, prev]}}"""
    S = {}
    for r in rows:
        r = {(k or "").strip(): (v or "").strip() for k, v in r.items()}
        tp = r.get("FinInstrmTp"); s = r.get("TckrSymb")
        if tp not in ("STO", "STF", "IDF", "IDO") or not s:
            continue
        a = S.setdefault(s, {"spot": None, "ex": None, "opt": {}, "fut": {}})
        ex = r.get("XpryDt") or ""
        if tp in ("STF", "IDF"):
            a["fut"].setdefault(ex, [0.0, 0.0, num(r.get("ClsPric")), num(r.get("PrvsClsgPric")), num(r.get("HghPric")), num(r.get("LwPric"))])
            f = a["fut"][ex]; f[0] += num(r.get("OpnIntrst")); f[1] += num(r.get("ChngInOpnIntrst"))
        else:
            if num(r.get("UndrlygPric")):
                a["spot"] = num(r.get("UndrlygPric"))
            a["opt"].setdefault(ex, {"CE": {}, "PE": {}})
            kd = r.get("OptnTp")
            if kd in ("CE", "PE"):
                a["opt"][ex][kd][num(r.get("StrkPric"))] = (num(r.get("OpnIntrst")), num(r.get("ChngInOpnIntrst")))
    out = {}
    for s, a in S.items():
        if not a["opt"] or not a["spot"]:
            continue
        ex = min(a["opt"]); o = a["opt"][ex]
        fx = sorted(a["fut"]); f = [sum(a["fut"][e][0] for e in fx), sum(a["fut"][e][1] for e in fx)] + (a["fut"][fx[0]][2:6] if fx else [0, 0, 0, 0])
        out[s] = {"spot": a["spot"], "ex": ex, "ce": o["CE"], "pe": o["PE"], "fut": f}
    return out


def daily(sym):
    """-> (5-day %, close vs its 20-day average %, daily RSI 14, its typical day's range %) from GIR's minute store, or None"""
    try:
        import numpy as np
        z = np.load(os.path.join(HIST, "min", sym + ".npz"))
        ts = np.asarray(z["ts"], np.int64); c = np.asarray(z["c"], float)
        h = np.asarray(z["h"], float) if "h" in z.files else c; l = np.asarray(z["l"], float) if "l" in z.files else c
        dn = (ts + 19800) // 86400; last = np.r_[np.nonzero(np.diff(dn))[0], len(dn) - 1]; first = np.r_[0, last[:-1] + 1]
        C = c[last][-40:]
        rng = [(h[a:b + 1].max() - l[a:b + 1].min()) / c[b] * 100 for a, b in zip(first[-14:], last[-14:])]
        typ = round(float(sum(rng) / len(rng)), 2) if rng else None
        if len(C) < 21:
            return None
        d5 = (C[-1] / C[-6] - 1) * 100; sma = (C[-1] / C[-20:].mean() - 1) * 100
        ch = np.diff(C[-15:]); up = ch[ch > 0].sum() / 14; dw = -ch[ch < 0].sum() / 14
        rsi = 100 - 100 / (1 + up / dw) if dw > 0 else 100.0
        return round(d5, 1), round(sma, 1), round(rsi), typ
    except Exception:
        return None


def delivery():
    try:
        sys.path.insert(0, GIR)
        import moneylink
        return moneylink.deliv_all()[1] or {}
    except Exception:
        return {}


def news(day):
    """{sym: (n ▲, n ▼, the latest headline)} from GIR's news alerts that day"""
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(GIR, "tomorrow.db"), uri=True, timeout=5)
        for t, s, tx in c.execute("select t, sym, text from alerts where day=? and text like '%NEWS%' order by t", (day,)):
            if not s:
                continue
            h = (tx or "").split("\n")[0]
            a = out.setdefault(s, [0, 0, ""])
            a[0] += "▲" in h; a[1] += "▼" in h; a[2] = h[:90]
        c.close()
    except Exception:
        pass
    return out


def sectors():
    try:
        return json.load(open(os.path.join(HIST, "sectors.json")))
    except Exception:
        return {}


def main():
    a = sys.argv[1:]; fpath = jpath = None
    if "--file" in a:
        i = a.index("--file"); fpath = a[i + 1]; a = a[:i] + a[i + 2:]
    if "--json" in a:
        i = a.index("--json"); jpath = a[i + 1]; a = a[:i] + a[i + 2:]
    only = [x.upper() for x in a]
    day, rows = fetch(fpath)
    m_ = re.search(r"(20\d\d)-?(\d\d)-?(\d\d)", day)
    day = "%s-%s-%s" % m_.groups() if m_ else day
    CH = chains(rows); DL = delivery(); NW = news(day); SEC = sectors()
    of = {x: k for k, v in SEC.items() for x in v}
    nif = daily("NIFTY")
    R = []
    for s, c in CH.items():
        if s in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50"):
            continue
        px = c["spot"]
        ce = [(oi, k, ch) for k, (oi, ch) in c["ce"].items() if px < k <= px * 1.15 and oi > 0]
        pe = [(oi, k, ch) for k, (oi, ch) in c["pe"].items() if px * 0.85 <= k < px and oi > 0]
        roof = max(ce) if ce else None; floor = max(pe) if pe else None
        tot = sum(oi * k for oi, k, _ in ce + pe) / 1e7
        f = c["fut"]; fchg = ((f[2] / f[3] - 1) * 100) if f[3] else 0.0; foi = (f[1] / (f[0] - f[1]) * 100) if f[0] - f[1] > 0 else 0.0
        bu = "" if abs(fchg) < 0.3 or abs(foi) < 0.5 else ("LONG BUILD-UP" if fchg > 0 and foi > 0 else "SHORT COVERING" if fchg > 0 else "SHORT BUILD-UP" if foi > 0 else "LONG UNWINDING")
        def wall(w):
            if not w:
                return None
            oi, k, ch = w; before = oi - ch
            return {"k": k, "oi": oi, "cr": oi * k / 1e7, "add": (ch / before * 100) if before > 0 else (999.0 if ch > 0 else 0.0), "dist": abs(k / px - 1) * 100}
        hi_, lo_ = f[4], f[5]
        fell = ((hi_ - f[2]) / hi_ * 100) if hi_ else 0.0; rose = ((f[2] - lo_) / lo_ * 100) if lo_ else 0.0
        R.append({"s": s, "px": px, "chg": fchg, "fell": fell, "rose": rose, "hi": hi_ * px / f[2] if f[2] else None, "lo": lo_ * px / f[2] if f[2] else None, "roof": wall(roof), "floor": wall(floor), "tot": tot, "bu": bu, "foi": foi, "fcr": f[1] * px / 1e7,
                  "pat": daily(s), "dl": DL.get(s) or {}, "nw": NW.get(s), "sec": of.get(s)})
    if not R:
        print("no F&O shares read from the NSE file"); return
    # density: each wall's ₹ size against all F&O shares (top third DENSE, bottom third THIN); the whole chain's size: the bottom quarter THIN
    def tiers(key):
        v = sorted(x[key]["cr"] for x in R if x[key])
        lo, hi = v[len(v) // 3], v[2 * len(v) // 3]
        for x in R:
            if x[key]:
                x[key]["den"] = "DENSE" if x[key]["cr"] >= hi else "THIN" if x[key]["cr"] < lo else "MEDIUM"
    tiers("roof"); tiers("floor")
    tv = sorted(x["tot"] for x in R); q1 = tv[len(tv) // 4]
    for x in R:
        x["thin"] = x["tot"] < q1
    # sector today: the average futures price move of its shares
    sec_chg = {}
    for x in R:
        if x["sec"]:
            sec_chg.setdefault(x["sec"], []).append(x["chg"])
    sec_chg = {k: sum(v) / len(v) for k, v in sec_chg.items()}
    nd = nif[0] if nif else None
    for x in R:
        r_, f_, p_, dl, nw = x["roof"], x["floor"], x["pat"], x["dl"], x["nw"]
        sc = sec_chg.get(x["sec"])
        pe = [("roof close", bool(r_ and r_["dist"] <= NEAR)), ("roof dense", bool(r_ and r_["den"] == "DENSE")), ("writers adding at the roof", bool(r_ and r_["add"] >= ADD)),
              ("new futures sellers", x["bu"] == "SHORT BUILD-UP"), ("room to the floor", bool((f_ and f_["dist"] >= ROOM) or not f_)),
              ("trend down", bool(p_ and (p_[0] < 0 and p_[1] < 0))), ("sector down", bool(sc is not None and sc < -0.3)), ("NIFTY 5 days down", bool(nd is not None and nd < 0)),
              ("big hands selling", bool(dl.get("x", 0) >= 1.5 and dl.get("chg", 0) < 0)), ("news ▼", bool(nw and nw[1] > nw[0]))]
        ce = [("floor close", bool(f_ and f_["dist"] <= NEAR)), ("floor dense", bool(f_ and f_["den"] == "DENSE")), ("writers adding at the floor", bool(f_ and f_["add"] >= ADD)),
              ("new futures buyers", x["bu"] == "LONG BUILD-UP"), ("room to the roof", bool((r_ and r_["dist"] >= ROOM) or not r_)),
              ("trend up", bool(p_ and (p_[0] > 0 and p_[1] > 0))), ("sector up", bool(sc is not None and sc > 0.3)), ("NIFTY 5 days up", bool(nd is not None and nd > 0)),
              ("big hands buying", bool(dl.get("x", 0) >= 1.5 and dl.get("chg", 0) > 0)), ("news ▲", bool(nw and nw[0] > nw[1]))]
        x["pe"], x["ce"] = pe, ce
        typ = (p_[3] if p_ and len(p_) > 3 and p_[3] else None)            # patch 301: its own typical day
        lim = 0.6 * typ if typ else 1.5
        x["typ"], x["lim"] = typ, round(lim, 2)
        x["pe_moved"], x["ce_moved"] = max(x["fell"], -x["chg"]), max(x["rose"], x["chg"])
        x["pe_done"] = x["pe_moved"] >= lim                                # the fall already used most of a normal day - don't sell at the low
        x["ce_done"] = x["ce_moved"] >= lim
        x["pes_raw"], x["ces_raw"] = sum(1 for _, v in pe if v), sum(1 for _, v in ce if v)        # before the 'already moved' point
        x["pes"] = x["pes_raw"] - (1 if x["pe_done"] else 0)
        x["ces"] = x["ces_raw"] - (1 if x["ce_done"] else 0)
        x["sc"] = sc
    def w(v, kd, up):
        if not v:
            return "%s none within 15%% → room" % ("roof" if up else "floor")
        return "%s %g %s %.1f%% %s (₹%s cr %s, %s%s)" % ("roof" if up else "floor", v["k"], kd, v["dist"], "↑" if up else "↓", "{:,.0f}".format(v["cr"]), v["den"],
                                                    ("writers %+.0f%%" % v["add"]) if v["add"] < 999 else "new today", " - may break" if v["add"] <= -ADD else "")
    def tags(x):
        p_, dl, nw = x["pat"], x["dl"], x["nw"]
        t = ["futures %s OI %+.1f%%" % (x["bu"].lower() or "flat", x["foi"])]
        if p_:
            t.append("5d %+.1f%% · RSI %d" % (p_[0], p_[2]))
        if x["sc"] is not None:
            t.append("sector %+.1f%%" % x["sc"])
        if dl.get("x", 0) >= 1.5:
            t.append("delivery %.1fx (big hands %s)" % (dl["x"], "buying" if dl.get("chg", 0) > 0 else "selling"))
        if nw:
            t.append("news %s" % ("▲" * min(nw[0], 3) + "▼" * min(nw[1], 3)))
        return " · ".join(t)
    def plan(x, side):
        r_, f_ = x["roof"], x["floor"]
        if side == "PE":
            t = "      ▼ entry: a bounce to the roof %s that fails (👀 / 🧱 ring) · or a break under the day's low ₹%s · out over %s" % (
                "%g" % r_["k"] if r_ else "-", "{:,.2f}".format(x["lo"]) if x["lo"] else "-", "%g" % r_["k"] if r_ else "the day's high")
            if x["pe_done"]:
                t += "\n      ⚠ ALREADY FELL %.1f%% from the day's high (%+.1f%% on the day; its typical day ±%s) - don't chase at the open" % (
                    x["fell"], x["chg"], ("%.1f%%" % x["typ"]) if x["typ"] else "not known - 1.5% used")
        else:
            t = "      ▲ entry: a dip to the floor %s that holds (👀 / 🧱 ring) · or a break over the day's high ₹%s · out under %s" % (
                "%g" % f_["k"] if f_ else "-", "{:,.2f}".format(x["hi"]) if x["hi"] else "-", "%g" % f_["k"] if f_ else "the day's low")
            if x["ce_done"]:
                t += "\n      ⚠ ALREADY ROSE %.1f%% from the day's low (%+.1f%% on the day; its typical day ±%s) - don't chase at the open" % (
                    x["rose"], x["chg"], ("%.1f%%" % x["typ"]) if x["typ"] else "not known - 1.5% used")
        return t

    def line(x, side):
        return "  %-11s ₹%-9s %+.1f%% · %s/10 · %s · %s · %s" % (x["s"], "{:,.2f}".format(x["px"]), x["chg"], x["pes"] if side == "PE" else x["ces"],
                                                         w(x["roof"], "CE", True), w(x["floor"], "PE", False), tags(x))
    sel = [x for x in R if (not only or x["s"] in only)]
    print("=== TOMORROW'S CHECKLIST · NSE's end-of-day F&O file %s · %d F&O shares · every strike · NIFTY 5 days %s" % (day, len(R), ("%+.1f%%" % nd) if nd is not None else "-"))
    print("    score /10: wall close · wall dense · writers adding · futures · room · trend · sector · NIFTY · delivery · news · -1 if the move already happened")
    print("    (THIN chains left out of 1-2) · a list of LEVELS for tomorrow - the trade is the live entry at those levels, not a buy at the open")
    if only:
        for x in sel:
            print(line(x, "PE").replace(" · %d/10 · " % x["pes"], " · PE %d/10 · CE %d/10 · " % (x["pes"], x["ces"]), 1)); print("      PE: " + " · ".join(("✅ " if v else "· ") + n for n, v in x["pe"]))
            print("      CE: " + " · ".join(("✅ " if v else "· ") + n for n, v in x["ce"]))
            print(plan(x, "PE")); print(plan(x, "CE"))
            if x["thin"]:
                print("      ⚠ THIN option chain - the walls mean little, the options hard to trade")
            if x["nw"]:
                print("      news: " + x["nw"][2])
        return
    good = [x for x in sel if not x["thin"]]
    if jpath:
        write_json(jpath, day, nd, R, good)
    print("\n1 ▼ PE - the best scores (a dense roof close above, writers adding, new sellers, room below, the trend / sector / NIFTY / news down):")
    for x in sorted(good, key=lambda x: (-x["pes"], x["roof"]["dist"] if x["roof"] else 99))[:12]:
        if x["pes"] >= 5:
            print(line(x, "PE")); print(plan(x, "PE"))
    print("\n2 ▲ CE - the best scores (a dense floor close below, writers adding, new buyers, room above, the trend / sector / NIFTY / news up):")
    for x in sorted(good, key=lambda x: (-x["ces"], x["floor"]["dist"] if x["floor"] else 99))[:12]:
        if x["ces"] >= 5:
            print(line(x, "CE")); print(plan(x, "CE"))
    bo = [x for x in good if x["roof"] and x["roof"]["dist"] <= AT and x["roof"]["add"] <= -ADD and x["bu"] in ("LONG BUILD-UP", "SHORT COVERING")]
    bd = [x for x in good if x["floor"] and x["floor"]["dist"] <= AT and x["floor"]["add"] <= -ADD and x["bu"] in ("SHORT BUILD-UP", "LONG UNWINDING")]
    print("\n3 ▲ BREAKOUT WATCH - at the roof, the roof writers CUTTING, buyers in (the roof may break): %d" % len(bo))
    for x in bo:
        print(line(x, "CE"))
    print("  ▼ BREAKDOWN WATCH - at the floor, the floor writers CUTTING, sellers in: %d" % len(bd))
    for x in bd:
        print(line(x, "PE"))
    th = sorted([x for x in sel if x["thin"]], key=lambda x: x["tot"])
    print("\n4 ⚠ THIN OPTION CHAINS - skip or tiny size (%d): %s" % (len(th), ", ".join("%s ₹%s cr" % (x["s"], "{:,.0f}".format(x["tot"])) for x in th[:40])))
    print("\nREAD: the score lines up the reasons - it does not predict. Tomorrow: PE only once it is under VWAP after 09:30 with the sellers still adding (CE: the")
    print("mirror); out if it closes back past the wall. GIR rings 👀 / 🧱 live. Detail on any share:  python3 /root/wallcheck2.py SYMBOL")


def item(x, side, kind=None):
    """one share for the 📋 CHECKLIST page (kind: "breakout" / "breakdown" for the wall-break watch)"""
    r_, f_, p_, dl, nw = x["roof"], x["floor"], x["pat"], x["dl"], x["nw"]
    W_ = lambda v: {"k": v["k"], "dist": round(v["dist"], 2), "cr": round(v["cr"]), "den": v["den"], "add": round(v["add"]) if v["add"] < 999 else None} if v else None
    lo_t = (" ₹" + "{:,.2f}".format(x["lo"])) if x["lo"] else ""; hi_t = (" ₹" + "{:,.2f}".format(x["hi"])) if x["hi"] else ""
    if kind == "breakout":
        entry = "only once it holds over the roof %g with its writers leaving" % r_["k"]; out = "back under %g" % r_["k"]
    elif kind == "breakdown":
        entry = "only once it holds under the floor %g with its writers leaving" % f_["k"]; out = "back over %g" % f_["k"]
    elif side == "PE":
        entry = "fails at the roof %s · or a break under the day's low%s" % ("%g" % r_["k"] if r_ else "-", lo_t)
        out = "over %s" % ("%g" % r_["k"] if r_ else "the day's high")
    else:
        entry = "holds at the floor %s · or a break over the day's high%s" % ("%g" % f_["k"] if f_ else "-", hi_t)
        out = "under %s" % ("%g" % f_["k"] if f_ else "the day's low")
    return {"s": x["s"], "side": side, "px": round(x["px"], 2), "chg": round(x["chg"], 2), "score": x["pes"] if side == "PE" else x["ces"],
            "roof": W_(r_), "floor": W_(f_), "bu": x["bu"], "foi": round(x["foi"], 1), "d5": p_[0] if p_ else None, "rsi": p_[2] if p_ else None,
            "sec": None if x["sc"] is None else round(x["sc"], 1), "dlx": dl.get("x"), "dlbuy": (dl.get("chg", 0) > 0) if dl else None,
            "news": [nw[0], nw[1]] if nw else None, "done": False if kind else (x["pe_done"] if side == "PE" else x["ce_done"]), "kind": kind,
            "moved": round(x["pe_moved"] if side == "PE" else x["ce_moved"], 1), "typ": x["typ"], "entry": entry, "out": out,
            "why": [[n, bool(v)] for n, v in (x["pe"] if side == "PE" else x["ce"])], "lo": x["lo"], "hi": x["hi"]}


def write_json(path, day, nd, R, good):
    pe = [x for x in sorted(good, key=lambda x: (-x["pes_raw"], x["roof"]["dist"] if x["roof"] else 99)) if x["pes_raw"] >= 5]     # a retest qualifies on its
    ce = [x for x in sorted(good, key=lambda x: (-x["ces_raw"], x["floor"]["dist"] if x["floor"] else 99)) if x["ces_raw"] >= 5]   # score before the -1
    J = {"day": day, "made": dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M"), "nifty5": nd, "n": len(R),
         "pe": [item(x, "PE") for x in pe if not x["pe_done"]][:10], "ce": [item(x, "CE") for x in ce if not x["ce_done"]][:10],
         "retest": ([item(x, "PE") for x in pe if x["pe_done"]] + [item(x, "CE") for x in ce if x["ce_done"]])[:10],
         "breakout": [item(x, "CE", "breakout") for x in good if x["roof"] and x["roof"]["dist"] <= AT and x["roof"]["add"] <= -ADD and x["bu"] in ("LONG BUILD-UP", "SHORT COVERING")],
         "breakdown": [item(x, "PE", "breakdown") for x in good if x["floor"] and x["floor"]["dist"] <= AT and x["floor"]["add"] <= -ADD and x["bu"] in ("SHORT BUILD-UP", "LONG UNWINDING")],
         "thin": [[x["s"], round(x["tot"])] for x in sorted([x for x in R if x["thin"]], key=lambda x: x["tot"])]}
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    json.dump(J, open(path + ".tmp", "w"), separators=(",", ":")); os.replace(path + ".tmp", path)


if __name__ == "__main__":
    main()
