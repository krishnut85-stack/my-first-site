#!/bin/bash
# PATCH 302 - THE CHECKLIST IN PLAIN WORDS (Rama, 15 Nov: "what is this - some kind of pseudo code? Make a tab inside the checklist and list them as
#   per the ranking, give filters for big and low, and give a detailed description for 'writers 12%' for the roof and floor").
#   girtrader.com/checklist now: tabs ▼ PE · ▲ CE · ⏳ Wait for the retest · ⚡ Breakout / breakdown · ⚠ Small chains · ⓘ How to read; each tab a ranked
#   list (#1, #2 ...); sort by rank / biggest wall / closest wall; show all walls / big walls only; every share in sentences: the CEILING and the FLOOR
#   ("Call sellers added 12% more contracts here today - they are betting harder that TECHM stays below ₹1,800. The ceiling got stronger."), the
#   futures in words, WHAT TO DO, and "why 7/10" - the 10 checks one by one. Replaces checklist.html and wallcheck2.py (both from patch 301) and
#   makes the checklist again. Tested: 6. No restart needed - Ctrl + Shift + R.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 302" $D/checklist.html 2>/dev/null; then echo "patch 302 - already in"; exit 0; fi
grep -q "patch 301" $D/checklist.html 2>/dev/null || { echo "patch 301 first"; exit 1; }
F="checklist.html wallcheck2.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/wallcheck2.py <<'PY_WC'
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
PY_WC
cat > $W/checklist.html <<'HTML_CL'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Checklist</title>
<style>
:root{--bg:#07090d;--panel:#0e131b;--panel2:#141b26;--line:#1f2a38;--text:#e6edf3;--dim:#8b98a8;--up:#3ddc84;--dn:#ff5c5c;--am:#ffb347;--hi:#ffffff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header{position:sticky;top:0;z-index:5;background:#0b1018;border-bottom:1px solid var(--line);padding:10px 14px}
.title{font-weight:700;font-size:16px}.sub{color:var(--dim);font-size:12.5px}
.tabs{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.tabs a{cursor:pointer;padding:6px 12px;border:1px solid var(--line);border-radius:999px;background:var(--panel2);font-weight:600;font-size:13px}
.tabs a.on{background:var(--am);color:#1a1205;border-color:var(--am)}
.ctl{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;align-items:center;font-size:13px;color:var(--dim)}
.ctl select{background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:6px;padding:4px 6px;font:inherit}
main{padding:10px 14px 30px;max-width:1100px}
.row{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-bottom:10px}
.top{display:flex;justify-content:space-between;gap:10px;align-items:baseline;flex-wrap:wrap}
.rank{color:var(--am);font-weight:700;margin-right:6px}.name{font-weight:700;font-size:16px;color:inherit}.px{color:var(--dim)}
.sc{display:inline-block;padding:1px 8px;border-radius:6px;background:var(--panel2);font-weight:700;margin-left:6px}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}b{color:var(--hi)}
.lv{margin-top:6px}.lv .k{font-weight:700}.lv .why{color:var(--dim);font-size:13px;margin-left:14px}
.todo{margin-top:6px;padding:6px 8px;border-radius:6px;background:#101a26}.warn{margin-top:6px;color:var(--am)}
details{margin-top:6px}summary{cursor:pointer;color:var(--dim);font-size:13px}.ok{color:var(--up)}.no{color:var(--dim)}
.w{background:#1a2230;border:1px solid var(--line);color:var(--text);border-radius:6px;padding:4px 10px;cursor:pointer;font:inherit;font-size:13px}.w.on{background:#0f3d24;border-color:var(--up)}
.help p{margin:6px 0}.help h3{margin:14px 0 4px;font-size:15px}
</style></head><body>
<header id="top"><span class="dim">📋 GIR CHECKLIST · loading…</span></header>
<main id="m"></main>
<script>
/* patch 302: 📋 THE CHECKLIST IN PLAIN WORDS - tabs, a ranked list, big-wall filter, every number explained (data: wallcheck2.py, patch 301) */
const Q=location.search;
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const rs=v=>v==null?"—":"₹"+Number(v).toLocaleString("en-IN",{minimumFractionDigits:0,maximumFractionDigits:2});
const pc=v=>v==null?"":(v>0?"+":"")+v+"%";
function shareURL(s){ const u=new URLSearchParams(location.search); u.set("w",s); return "./?"+u.toString(); }
let D=null, TAB="pe", SORT="rank", BIG="all", WATCHED=new Set();
try{ TAB=localStorage.getItem("gir_cl_tab")||"pe"; SORT=localStorage.getItem("gir_cl_sort")||"rank"; BIG=localStorage.getItem("gir_cl_big")||"all"; }catch(e){}
function setv(k,v){ if(k==="tab") TAB=v; else if(k==="sort") SORT=v; else BIG=v; try{ localStorage.setItem("gir_cl_"+k,v); }catch(e){} paint(); }
async function watch(s,side,btn){ try{ const u=new URLSearchParams(location.search); u.set("w",s); u.set("d",side==="PE"?"down":"up");
  const j=await (await fetch("checklistwatch?"+u.toString(),{cache:"no-store"})).json(); if(j.ok){ WATCHED.add(s); btn.classList.add("on"); btn.textContent="✓ on your watch list"; } }catch(e){} }
const SIZE={DENSE:"BIG wall",MEDIUM:"medium wall",THIN:"small wall"};
function writers(w,isRoof,s){ const who=isRoof?"Call sellers":"Put sellers", keep=isRoof?"stays below":"stays above", what=isRoof?"ceiling":"floor";
  if(w.add==null) return `New sellers opened this strike today - a fresh ${what}.`;
  if(w.add>=10) return `${who} added ${w.add}% more contracts here today - they are betting harder that ${esc(s)} ${keep} ${rs(w.k)}. The ${what} got stronger.`;
  if(w.add>0) return `${who} added a little (${w.add}%) - the ${what} is holding.`;
  if(w.add>-10) return `${who} cut ${Math.abs(w.add)}% - the ${what} is about the same.`;
  return `${who} took back ${Math.abs(w.add)}% here today - they are giving up. ⚠ The ${what} may break${isRoof?" (good for a CE if it does)":" (good for a PE if it does)"}.`; }
function level(w,isRoof,s){ if(!w) return `<div class="lv"><span class="k">${isRoof?"CEILING (resistance)":"FLOOR (support)"}:</span> none within 15% - open room ${isRoof?"to rise":"to fall"}</div>`;
  return `<div class="lv"><span class="k">${isRoof?"CEILING (resistance)":"FLOOR (support)"}: ${rs(w.k)}</span> · ${w.dist}% ${isRoof?"above":"below"} · <b>${SIZE[w.den]||w.den}</b> (₹${Number(w.cr).toLocaleString("en-IN")} cr of ${isRoof?"calls":"puts"} sold)
    <div class="why">→ ${writers(w,isRoof,s)}</div></div>`; }
const FUT={"LONG BUILD-UP":"new buyers are betting on a rise (long build-up)","SHORT BUILD-UP":"new sellers are betting on a fall (short build-up)",
  "SHORT COVERING":"sellers are closing their bets (short covering) - a rise without new money","LONG UNWINDING":"buyers are leaving (long unwinding) - a fall without new money"};
const WHY={"roof close":"the ceiling is within 3% above","roof dense":"the ceiling is a big wall","writers adding at the roof":"call sellers are adding at the ceiling",
  "new futures sellers":"new futures sellers","room to the floor":"room to fall (the floor is 3%+ below)","trend down":"the 5-day trend is down","sector down":"its sector is down",
  "NIFTY 5 days down":"NIFTY's 5 days are down","big hands selling":"big investors are selling (high delivery)","news ▼":"the latest news is bad",
  "floor close":"the floor is within 3% below","floor dense":"the floor is a big wall","writers adding at the floor":"put sellers are adding at the floor",
  "new futures buyers":"new futures buyers","room to the roof":"room to rise (the ceiling is 3%+ above)","trend up":"the 5-day trend is up","sector up":"its sector is up",
  "NIFTY 5 days up":"NIFTY's 5 days are up","big hands buying":"big investors are buying (high delivery)","news ▲":"the latest news is good"};
function todo(x){ const pe=x.side==="PE", r=x.roof, f=x.floor;
  if(x.kind==="breakout") return `▲ CE only once it holds above the ceiling ${rs(r&&r.k)} while the call sellers keep leaving. Exit if it falls back below ${rs(r&&r.k)}.`;
  if(x.kind==="breakdown") return `▼ PE only once it holds below the floor ${rs(f&&f.k)} while the put sellers keep leaving. Exit if it climbs back above ${rs(f&&f.k)}.`;
  return pe?`▼ PE if it bounces up to the ceiling ${rs(r&&r.k)} and fails there, or breaks below the day's low ${rs(x.lo)}. Exit if it closes above ${rs(r?r.k:x.hi)}.`
           :`▲ CE if it dips to the floor ${rs(f&&f.k)} and holds there, or breaks above the day's high ${rs(x.hi)}. Exit if it closes below ${rs(f?f.k:x.lo)}.`; }
function row(x,i){ const pe=x.side==="PE";
  const why=(x.why||[]).map(w=>`<div class="${w[1]?"ok":"no"}">${w[1]?"✅":"·"} ${esc(WHY[w[0]]||w[0])}</div>`).join("");
  const extra=[x.d5!=null?`5 days ${pc(x.d5)}`:"", x.rsi!=null?`RSI ${x.rsi}${x.rsi>=75?" (stretched up)":x.rsi<=30?" (stretched down)":""}`:"", x.sec!=null?`its sector ${pc(x.sec)} today`:"",
    x.dlx>=1.5?`big investors ${x.dlbuy?"bought":"sold"} (delivery ${x.dlx}× normal)`:"", x.news?`news: ${x.news[0]} good / ${x.news[1]} bad`:""].filter(Boolean).join(" · ");
  return `<div class="row"><div class="top"><span><span class="rank">#${i+1}</span><span class="${pe?"dn":"up"}">${pe?"▼ PE":"▲ CE"}</span> <a class="name" href="${shareURL(x.s)}" target="_blank">${esc(x.s)}</a>
      <span class="px">${rs(x.px)} (${pc(x.chg)} on the day)</span>${x.kind?"":`<span class="sc">score ${x.score}/10</span>`}</span>
      <button class="w${WATCHED.has(x.s)?" on":""}" onclick="watch('${esc(x.s)}','${x.side}',this)">${WATCHED.has(x.s)?"✓ on your watch list":"➕ watch"}</button></div>
    ${pe||x.kind==="breakout"?level(x.roof,true,x.s)+level(x.floor,false,x.s):level(x.floor,false,x.s)+level(x.roof,true,x.s)}
    <div class="lv"><span class="k">FUTURES:</span> ${esc(FUT[x.bu]||"no clear futures bet")}${x.bu?` · open interest ${pc(x.foi)}`:""}</div>
    <div class="todo"><b>WHAT TO DO:</b> ${todo(x)}</div>
    ${x.done?`<div class="warn">⚠ It already moved ${x.moved}% (${x.typ?"a normal day for it is about ±"+x.typ+"%":"its normal day is not known - 1.5% used"}) - don't chase at the open; wait for it to come back to the level.</div>`:""}
    ${x.kind?"":`<details><summary>why ${x.score}/10 - the 10 checks${extra?" · "+esc(extra):""}</summary>${why}</details>`}</div>`; }
function mainWall(x){ return (x.side==="PE"||x.kind==="breakout")?x.roof:x.floor; }
function list(L){ let A=(L||[]).slice();
  if(BIG==="big") A=A.filter(x=>{ const w=mainWall(x); return w&&w.den==="DENSE"; });
  if(SORT==="big") A.sort((a,b)=>((mainWall(b)||{}).cr||0)-((mainWall(a)||{}).cr||0));
  else if(SORT==="near") A.sort((a,b)=>((mainWall(a)||{}).dist??99)-((mainWall(b)||{}).dist??99));
  return A.length?A.map(row).join(""):'<div class="dim">nothing here with these filters</div>'; }
function help(){ return `<div class="help">
  <h3>The ceiling and the floor</h3><p><b>CEILING (resistance)</b> = the price above the share where the most CALL options are sold. Call sellers lose money if the share goes above it, so they defend it - the share often stops there.</p>
  <p><b>FLOOR (support)</b> = the price below where the most PUT options are sold. Put sellers lose money if the share falls below it, so they defend it - the share often bounces there.</p>
  <h3>"Call sellers added 12%"</h3><p>Today, 12% more call contracts were sold at that ceiling than yesterday. More sellers = they are betting harder the share will NOT go above it = <b>a stronger ceiling</b>.</p>
  <p>"Call sellers took back 33%" = they bought back a third of their calls - they are giving up = <b>the ceiling may break</b>. The same for the floor with put sellers.</p>
  <h3>BIG / medium / small wall</h3><p>The wall's size in rupees (contracts × the strike), compared with every F&O share: the top third = BIG, the bottom third = small. A big wall is strong; a small wall means little.</p>
  <h3>Futures</h3><p><b>Long build-up</b> = new buyers betting on a rise · <b>short build-up</b> = new sellers betting on a fall · <b>short covering</b> = sellers running (a rise without new money) · <b>long unwinding</b> = buyers leaving (a fall without new money).</p>
  <h3>Score /10</h3><p>How many of 10 checks agree for that side (the wall close, big, sellers adding, the futures, room to move, the trend, the sector, NIFTY, big investors, news). It lines up the reasons - it does not predict. One point is taken off when the move already happened.</p>
  <h3>Wait for the retest</h3><p>The share already moved most of a normal day for it - selling at the low (or buying at the high) is late. Wait for it to come back to the level and fail there.</p>
  <h3>Small option chains</h3><p>So few options that the walls mean little and the options are hard to trade - skip, or a tiny size.</p>
  <h3>Every share</h3><p>This list is levels for the day. The trade is the live entry at the level after 09:30 - GIR rings 👀 near a wall and 🧱 on the rejection. Half size, out by 15:15.</p></div>`; }
function paint(){ if(!D) return;
  const T=[["pe","▼ PE",D.pe],["ce","▲ CE",D.ce],["retest","⏳ Wait for the retest",D.retest],["bo","⚡ Breakout / breakdown",(D.breakout||[]).concat(D.breakdown||[])],["thin","⚠ Small chains",D.thin],["help","ⓘ How to read",null]];
  document.getElementById("top").innerHTML=`<div class="title">📋 Tomorrow's checklist</div>
    <div class="sub">from NSE's end-of-day file of ${esc(D.day)} · made ${esc(D.made)} · ${D.n} F&amp;O shares · NIFTY 5 days ${D.nifty5!=null?pc(D.nifty5):"-"} · levels for the day: trade the live entry after 09:30, half size, out by 15:15</div>
    <div class="tabs">${T.map(t=>`<a class="${TAB===t[0]?"on":""}" onclick="setv('tab','${t[0]}')">${t[1]}${t[2]?" · "+t[2].length:""}</a>`).join("")}</div>
    ${["pe","ce","retest","bo"].includes(TAB)?`<div class="ctl">sort <select onchange="setv('sort',this.value)"><option value="rank"${SORT==="rank"?" selected":""}>by rank (score)</option><option value="big"${SORT==="big"?" selected":""}>biggest wall first</option><option value="near"${SORT==="near"?" selected":""}>closest wall first</option></select>
      show <select onchange="setv('big',this.value)"><option value="all"${BIG==="all"?" selected":""}>all walls</option><option value="big"${BIG==="big"?" selected":""}>big walls only</option></select></div>`:""}`;
  const m=document.getElementById("m");
  if(TAB==="help") m.innerHTML=help();
  else if(TAB==="thin") m.innerHTML=`<p class="dim">These F&amp;O shares have so few options that their walls mean little and the options are hard to trade - skip them, or a tiny size. Smallest first (the whole option chain in ₹ crore):</p><div>${(D.thin||[]).map(x=>`<a href="${shareURL(x[0])}" target="_blank" style="color:inherit">${esc(x[0])}</a> <span class="dim">₹${x[1]} cr</span>`).join(" · ")}</div>`;
  else m.innerHTML=list(TAB==="pe"?D.pe:TAB==="ce"?D.ce:TAB==="retest"?D.retest:(D.breakout||[]).concat(D.breakdown||[])); }
async function pull(){ try{ const r=await fetch("checklistdata"+Q,{cache:"no-store"}); if(r.ok){ const d=await r.json(); if(d&&d.day){ D=d; paint(); }
  else document.getElementById("top").innerHTML='<div class="title">📋 Tomorrow\'s checklist</div><div class="sub">not made yet - GIR makes it every market evening at 19:15</div>'; } }catch(e){} }
pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000);
</script></body></html>
HTML_CL
cat > $W/p301test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p301test.py - 📋 THE CHECKLIST PAGE: wallcheck2 --json, the per-share 'already moved', ➕ watch (made-up NSE file, temp folder, nothing sent)"""
import os, io, csv, sys, json, shutil, zipfile, tempfile, subprocess, datetime as dt
import numpy as np
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); G = os.path.join(T, "gir"); H = os.path.join(T, "hist"); os.makedirs(os.path.join(G, "data")); os.makedirs(os.path.join(H, "min"))
for f in ("wallcheck2.py", "checklistwatch.py"):
    shutil.copy(os.path.join(WK, f), G)
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:600]))
cols = "TradDt,FinInstrmTp,TckrSymb,XpryDt,StrkPric,OptnTp,ClsPric,PrvsClsgPric,HghPric,LwPric,UndrlygPric,OpnIntrst,ChngInOpnIntrst".split(",")
rows = []
def opt(s, spot, gap, ce, pe, base):
    k0 = round(spot / gap) * gap
    for i in range(-10, 11):
        k = k0 + i * gap
        for kd, w in (("CE", ce), ("PE", pe)):
            oi, ch = w.get(k, (base, 0)); rows.append({"FinInstrmTp": "STO", "TckrSymb": s, "XpryDt": "2026-11-23", "StrkPric": k, "OptnTp": kd, "UndrlygPric": spot, "OpnIntrst": oi, "ChngInOpnIntrst": ch})
def fut(s, c, p, hi, lo, oi, ch):
    rows.append({"FinInstrmTp": "STF", "TckrSymb": s, "XpryDt": "2026-11-27", "ClsPric": c, "PrvsClsgPric": p, "HghPric": hi, "LwPric": lo, "OpnIntrst": oi, "ChngInOpnIntrst": ch})
opt("SLOWCO", 1391.8, 20, {1400: (7_800_000, 2_000_000)}, {1300: (7_100_000, 500_000)}, 1_000_000); fut("SLOWCO", 1390, 1407, 1418.7, 1390, 10_000_000, 620_000)    # a ±1.6% share, fell 2% - late
opt("WILDCO", 7054, 100, {7500: (250_000, 50_000)}, {7000: (180_000, 60_000)}, 100_000); fut("WILDCO", 7054, 6918, 7120, 6922, 3_000_000, 200_000)       # a ±5% share, rose 1.9% - not late
for i in range(10):
    opt("FILL%d" % i, 200 + 10 * i, 5, {}, {}, 2_000_000); fut("FILL%d" % i, 200 + 10 * i, 200 + 10 * i, 201 + 10 * i, 199 + 10 * i, 1_000_000, 0)
out = io.StringIO(); w = csv.DictWriter(out, fieldnames=cols); w.writeheader()
for r in rows:
    w.writerow({c: r.get(c, "") for c in cols})
zp = os.path.join(T, "BhavCopy_NSE_FO_0_0_0_20261113_F_0000.csv.zip"); z = zipfile.ZipFile(zp, "w"); z.writestr("f.csv", out.getvalue()); z.close()
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
for sym, rng in (("SLOWCO", 0.016), ("WILDCO", 0.052)):                 # 30 days of minute candles with that typical daily range
    ts, o, h, l, c = [], [], [], [], []; px = 1000.0; d = dt.date(2026, 10, 1)
    while d <= dt.date(2026, 11, 13):
        if d.weekday() < 5:
            b = dt.datetime.combine(d, dt.time(9, 15), IST).timestamp()
            for m in range(0, 375, 75):
                ts.append(b + m * 60); c.append(px); o.append(px); h.append(px * (1 + rng / 2)); l.append(px * (1 - rng / 2))
        d += dt.timedelta(days=1)
    f32 = lambda a: np.array(a, np.float32)
    np.savez(os.path.join(H, "min", sym + ".npz"), ts=np.array(ts, np.int64), o=f32(o), h=f32(h), l=f32(l), c=f32(c), v=f32([1] * len(c)))
env = dict(os.environ, GIR_BASE=G, GIR_HIST=H)
jp = os.path.join(G, "data", "checklist.json")
r = subprocess.run([sys.executable, os.path.join(G, "wallcheck2.py"), "--file", zp, "--json", jp], env=env, capture_output=True, text=True, timeout=120)
chk("wallcheck2 --json runs and writes data/checklist.json", r.returncode == 0 and os.path.exists(jp), r.stderr[-400:])
J = json.load(open(jp)) if os.path.exists(jp) else {}
chk("the page's data: the day, when made, the sections (pe / ce / retest / breakout / breakdown / thin)", J.get("day") == "2026-11-13" and all(k in J for k in ("pe", "ce", "retest", "breakout", "breakdown", "thin")), list(J))
allx = {x["s"] + x["side"]: x for k in ("pe", "ce", "retest") for x in J.get(k, [])}
sl = allx.get("SLOWCOPE"); wd = allx.get("WILDCOCE")
chk("SLOWCO (a ±1.6%% share) fell 2.0%% -> 'already moved', in WAIT FOR THE RETEST (typical %s%%)" % (sl or {}).get("typ"), sl and sl["done"] and any(x["s"] == "SLOWCO" for x in J["retest"]), sl)
chk("WILDCO (a ±5%% share) rose 1.9%% -> NOT late (60%% of its day = 3.1%%), in the fresh CE list (typical %s%%)" % (wd or {}).get("typ"), wd and not wd["done"] and any(x["s"] == "WILDCO" for x in J["ce"]), wd)
chk("each share: the entry and the exit ('fails at the roof 1400 ...' · 'out over 1400')", sl and sl["entry"].startswith("fails at the roof 1400") and sl["out"] == "over 1400", sl)
sys.path.insert(0, G)
import checklistwatch as CW
CW.F = os.path.join(G, "data", "myview.json")
chk("➕ watch: a good share goes onto the 👁 view list (down = -1), a bad name is refused", CW.add("slowco", "down") and CW.add("../x", "up") is False and json.load(open(CW.F))["v"] == {"SLOWCO": -1})
print("THE PATCH 301 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/checklistwatch.py <<'PY_CW'
"""checklistwatch.py - patch 301: ➕ watch on the 📋 CHECKLIST page -> the share onto GIR's 👁 view list (data/myview.json, the same file as
'python3 windwatch.py view SYM up|down'); the wind watcher reads it every 3 s."""
import os, re, json
BASE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(BASE, "data", "myview.json")


def add(sym, how):
    s = (sym or "").upper().strip()
    if not re.fullmatch(r"[A-Z0-9&\-]{1,20}", s) or how not in ("up", "down"):
        return False
    try:
        j = json.load(open(F))
    except Exception:
        j = {}
    v = j.get("v") or {}
    v[s] = 1 if how == "up" else -1
    j["v"] = v
    os.makedirs(os.path.dirname(F), exist_ok=True)
    json.dump(j, open(F + ".tmp", "w")); os.replace(F + ".tmp", F)
    return True
PY_CW
echo "=== test"
python3 $W/p301test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
cp $W/wallcheck2.py $D/wallcheck2.py; cp $W/checklist.html $D/checklist.html
cd $D && python3 -m py_compile wallcheck2.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/checklist.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the checklist page's code checked ✓"
fi
echo "=== making the checklist again (with the reasons)"
systemctl start gir-checklist.service
python3 - $D/data/checklist.json <<'PY_SUM'
import json, sys
try:
    j = json.load(open(sys.argv[1]))
    print("  checklist of %s: PE %d · CE %d · retest %d · reasons in it: %s" % (j["day"], len(j["pe"]), len(j["ce"]), len(j["retest"]), "yes" if (j["pe"] or j["ce"]) and "why" in (j["pe"] + j["ce"])[0] else "-"))
except Exception:
    print("  ⚠ not made now - the timer makes it at 19:15 / 20:30")
PY_SUM
echo "✅ patch 302 done - girtrader.com/checklist in plain words: tabs, a ranked list, sort / big-wall filter, every number explained. Ctrl + Shift + R."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done"
