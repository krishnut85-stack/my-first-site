#!/usr/bin/env python3
"""seclive.py - patch 354: READ ONLY. THE SECTORS FROM ALL THEIR SHARES, LIVE (Rama, 16 Nov: "sector performance is the performance of ALL its
stocks - only the F&O ones gives me wrong information. Healthcare is no.1 on Trendlyne and 9th in GIR. The rotation is not updating").
  · the shares   every share of NSE's Nifty Total Market (about 750 - about 95% of the market's value), in NSE's OWN sector (data/nse_sectors.json,
                 the same list GIR's page already uses; Financial Services split into banks / nbfc & finance / insurance / capital markets as before)
  · the weight   each share's MARKET CAP from NSE's own daily file (mcap<date>.csv in the PR zip of NSE's archives - fetched once a day, kept in
                 data/seclive_w.json); equal weight only if NSE never answered
  · the price    Kite: every share's last price and yesterday's close in ONE request, every 3 seconds in market hours (every 5 minutes outside)
  · TODAY        a sector's % = the size-weighted average of all its shares' % since yesterday's close (like Trendlyne / NSE's indices)
  · ROTATION     the same, over the last 15 / 30 / 60 minutes - from a per-minute record kept HERE on the server (data/seclive_hist.json), so
                 every screen shows the same numbers, from 09:15, however late the page was opened
  -> data/seclive.json (the page reads it through dashserve /seclive). Orders nothing, sends nothing.
  python3 seclive.py once     one pass now, prints the ranking"""
import os, re, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "seclive.json")
WF = os.path.join(D, "data", "seclive_w.json")
HF = os.path.join(D, "data", "seclive_hist.json")
FAST_S, SLOW_S = 3, 300
WINS = (15, 30, 60)
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept": "application/json,text/html,*/*", "Accept-Language": "en-US,en;q=0.9"}


def now():
    return dt.datetime.now(IST)


def log(*a):
    print(now().strftime("%H:%M:%S"), *a, flush=True)


def market_open(n):
    if n.weekday() > 4:
        return False
    try:
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return "09:15" <= n.strftime("%H:%M") <= "15:35"


# patch 354c: three of NSE's sectors hold two different businesses that move opposite ways (16 Nov: hospitals +2%, pharma -1.2%; electronics makers
# -3.9% inside capital goods / consumer durables; telecom equipment -3.7% inside telecom) - split the way Trendlyne shows them
HOSP = set("MAXHEALTH APOLLOHOSP FORTIS NH MEDANTA ASTERDM KIMS RAINBOW LALPATHLAB METROPOLIS VIJAYA THYROCARE JLHL YATHARTH HCG SHALBY AGARWALEYE INDRAMEDCO "
           "KRSNAA SURAKSHA MEDIASSIST POLYMED".split())
HOSP_RE = re.compile(r"hospital|healthcare institute|hrudayalaya|medical sciences|path ?labs|diagnos|health care ltd|healthcare global|life line|eye ?care", re.I)
NOT_HOSP = set("SHILPAMED".split())                                         # 354d: Shilpa Medicare is a pharma company
EMS = set("KAYNES SYRMA DIXON AMBER PGEL CYIENTDLM AVALON NETWEB DATAPATTNS CENTUM ELIN".split())
EMS_RE = re.compile(r"electronics manufactur|electronic manufactur|technologies \(india\) .*ems", re.I)
TEL_SERV = set("BHARTIARTL BHARTIHEXA IDEA INDUSTOWER TATACOMM RAILTEL TTML MTNL ROUTE TANLA".split())   # 354d: Route Mobile / Tanla are services


def refine(sym, sec, name=""):
    """NSE's sector -> the finer one where one sector holds two businesses"""
    if sec == "healthcare":
        return "hospitals & diagnostics" if (sym not in NOT_HOSP and (sym in HOSP or HOSP_RE.search(name or ""))) else "pharma"
    if sym in EMS or (sec in ("capital goods", "consumer durables") and EMS_RE.search(name or "")):
        return "electronics & hardware"
    if sec == "telecom":
        return "telecom services" if sym in TEL_SERV else "telecom equipment"
    return sec


def universe():
    """{SYMBOL: GIR page sector} for every share in NSE's list, + {SYMBOL: company name}"""
    import nsesec
    j = nsesec.load_map() or {}
    nse, names = j.get("map") or {}, j.get("names") or {}
    try:
        import sectors
        hand = sectors.hand_map()
    except Exception:
        hand = {}
    out = {}
    for s in nse:
        if not nsesec.not_a_share(s):
            out[s] = refine(s, nsesec.sector_of(s, nse, hand, names), names.get(s, ""))
    return out, names


def fo_set():
    try:
        import sqlite3
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        r = {x[0] for x in c.execute("select sym from fo_list")}; c.close(); return r
    except Exception:
        return set()


def parse_mcap(text):
    """NSE's mcap<ddmmyyyy>.csv (in the daily PR zip): Trade Date, Symbol, Series, Security Name, Category, Last Trade Date, Face Value,
    Issue Size, Close Price, Market Cap(Rs.) -> {SYMBOL: market cap}"""
    import csv, io
    w = {}
    rd = csv.reader(io.StringIO(text))
    head = [h.strip().lower() for h in next(rd, [])]
    try:
        si = head.index("symbol"); mi = next(k for k, h in enumerate(head) if h.startswith("market cap"))
    except Exception:
        return w
    for row in rd:
        try:
            s = row[si].strip().upper(); v = float(row[mi].strip().replace(",", ""))
        except Exception:
            continue
        if s and v > 0:
            w[s] = max(v, w.get(s, 0.0))
    return w


def nse_weights():
    """{SYMBOL: market cap} - NSE's own daily market-cap file (mcap<ddmmyyyy>.csv inside the PR zip in NSE's archives; the newest of the
    last 8 days - in the morning that is yesterday's close). Fetched once a day, kept in data/seclive_w.json. (patch 354b: NSE's website API
    answers 403 to this server - the archive does answer.)"""
    try:
        j = json.load(open(WF))
        if j.get("day") == str(now().date()) and len(j.get("w") or {}) > 300:
            return j["w"], j.get("src", "NSE")
    except Exception:
        j = None
    try:
        import requests, io, zipfile
        s = requests.Session()
        for i in range(9):
            x = now().date() - dt.timedelta(days=i)
            for host in ("nsearchives.nseindia.com", "archives.nseindia.com"):
                try:
                    r = s.get("https://%s/archives/equities/bhavcopy/pr/PR%s.zip" % (host, x.strftime("%d%m%y")), headers=dict(UA, Accept="*/*"), timeout=25)
                    if not (r.ok and r.content[:2] == b"PK"):
                        continue
                    z = zipfile.ZipFile(io.BytesIO(r.content))
                    f = next((n for n in z.namelist() if "mcap" in n.lower()), None)
                    w = parse_mcap(z.read(f).decode("latin-1")) if f else {}
                    if len(w) > 300:
                        src = "NSE market cap %s" % x.strftime("%d %b")
                        json.dump({"day": str(now().date()), "src": src, "w": w}, open(WF + ".tmp", "w")); os.replace(WF + ".tmp", WF)
                        log("weights: %d shares - %s (%s)" % (len(w), src, f))
                        return w, src
                except Exception as ex:
                    log("weights: %s %s: %s" % (host, x, str(ex)[:60]))
    except Exception as ex:
        log("weights: NSE's archive did not answer (%s)" % str(ex)[:80])
    if j and len(j.get("w") or {}) > 300:
        return j["w"], j.get("src", "NSE") + " (kept from " + str(j.get("day")) + ")"
    return {}, "EQUAL (NSE's sizes not available)"


def quotes(kite, syms):
    """{SYMBOL: (last, yesterday's close)} - Kite's ohlc, up to 1000 shares a request"""
    import getdata
    out = {}
    L = sorted(syms)
    for i in range(0, len(L), 900):
        q = getdata.call(kite.ohlc, ["NSE:" + s for s in L[i:i + 900]]) or {}
        for k, v in q.items():
            lp = float(v.get("last_price") or 0); pc = float((v.get("ohlc") or {}).get("close") or 0)
            if lp > 0 and pc > 0:
                out[k.split(":", 1)[1]] = (lp, pc)
    return out


def compute(SEC, W, Q, hist, FO, wsrc, n=None):
    """the sectors: today's % and the 15 / 30 / 60-minute rotation, size-weighted, from every share"""
    n = n or now(); mn = n.hour * 60 + n.minute
    base = {}
    for w in WINS:
        b = None
        for h in hist:
            if h["m"] <= mn - w:
                b = h
        base[w] = b
    G = {}
    for s, sec in SEC.items():
        if s not in Q:
            continue
        lp, pc = Q[s]; wt = W.get(s) or (0.0 if W else 1.0)
        if W and not wt:
            wt = 0.0
        g = G.setdefault(sec, {"a": 0.0, "w": 0.0, "n": 0, "up": 0, "dn": 0, "rows": [], "r": {k: [0.0, 0.0] for k in WINS}, "rr": {k: [] for k in WINS}, "eq": 0.0, "cw": []})
        c = (lp / pc - 1) * 100; g["n"] += 1; g["eq"] += c; g["up"] += c > 0; g["dn"] += c < 0
        g["rows"].append((c, s))
        if wt > 0:
            g["a"] += c * wt; g["w"] += wt; g["cw"].append((c * wt, s))
        for k in WINS:
            b = base[k]; p0 = b and b["p"].get(s)
            if p0:
                g["rr"][k].append(((lp / p0 - 1) * 100, s))
                if wt > 0:
                    g["r"][k][0] += (lp / p0 - 1) * 100 * wt; g["r"][k][1] += wt
    out = []
    for sec, g in G.items():
        if g["n"] < 2:
            continue
        chg = g["a"] / g["w"] if g["w"] else g["eq"] / g["n"]
        rows = sorted(g["rows"], reverse=True)
        # patch 369: ONE SHARE - when one share makes half or more of the sector's by-size move. rankstudy.py (66 days, 17 Nov): at 10:00 the
        # OTHER F&O shares of such a top sector went on -0.29% to 15:10 (38% its way) against -0.06% (44%) for a sector moved by many shares -
        # worse in both halves of the days. The sector's figure is then mostly that one company, not the sector.
        one = None
        if g["cw"] and g["a"] and abs(chg) >= 0.10 and g["w"]:
            sg = 1 if g["a"] > 0 else -1; lc, ls = max(g["cw"], key=lambda r: r[0] * sg)
            if lc / g["a"] >= 0.5:
                one = [ls, round(100 * lc / g["a"]), ls in FO]
        # patch 369: the sector card - each F&O share of the sector: [share, % today, its size in the sector %, its part of the sector's move %]
        cw = {x: v for v, x in g["cw"]}
        fol = [[x, round(c, 2), round(100 * cw[x] / c / g["w"], 1) if x in cw and c and g["w"] else None,
                round(100 * cw[x] / g["a"]) if x in cw and g["a"] and abs(chg) >= 0.10 else None] for c, x in rows if x in FO]
        out.append({"name": sec, "chg": round(chg, 2), "n": g["n"], "up": g["up"], "dn": g["dn"], "fo": sum(1 for _, s in rows if s in FO), "fos": sorted(s for _, s in rows if s in FO),   # 354e: its F&O shares - a tap on the sector lists them
                    "eqw": round(g["eq"] / g["n"], 2), "one": one, "fol": fol,
                    "rot": {str(k): (round(g["r"][k][0] / g["r"][k][1], 2) if g["r"][k][1] else None) for k in WINS},
                    "rotx": {str(k): {"up": sum(1 for c, _ in g["rr"][k] if c > 0), "dn": sum(1 for c, _ in g["rr"][k] if c < 0), "n": len(g["rr"][k]),
                                      "top": [[s, round(c, 2), s in FO] for c, s in sorted(g["rr"][k], reverse=True)[:3]],
                                      "bot": [[s, round(c, 2), s in FO] for c, s in sorted(g["rr"][k])[:3]]} for k in WINS},
                    "top": [[s, round(c, 2), s in FO] for c, s in rows[:3]], "bot": [[s, round(c, 2), s in FO] for c, s in rows[-3:][::-1]]})
    out.sort(key=lambda x: -x["chg"])
    since = {str(k): (("%02d:%02d" % divmod(base[k]["m"], 60)) if base[k] else None) for k in WINS}
    return {"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": str(n.date()), "shares": len(Q), "weights": wsrc, "since": since, "sectors": out}


def load_hist(day):
    try:
        j = json.load(open(HF))
        if j.get("day") == day:
            return j.get("h") or []
    except Exception:
        pass
    return []


def save(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path + ".tmp", "w"), ensure_ascii=False, separators=(",", ":")); os.replace(path + ".tmp", path)


def get_kite():
    import core
    k = core.get_kite()
    try:
        k.timeout = 7
    except Exception:
        pass
    return k


def main():
    once = sys.argv[1:2] == ["once"]
    kite = None; SEC = {}; W = {}; wsrc = ""; FO = set(); day = None; hist = []; last_min = None
    while True:
        n = now(); live = market_open(n)
        try:
            if day != str(n.date()) or not SEC:
                day = str(n.date()); SEC, _ = universe(); FO = fo_set(); W, wsrc = nse_weights(); hist = load_hist(day)
                log("%d shares in %d sectors · weights: %s" % (len(SEC), len(set(SEC.values())), wsrc))
            if kite is None:
                kite = get_kite()
            Q = quotes(kite, SEC)
            mn = n.hour * 60 + n.minute
            if live and mn != last_min and Q:                                 # the per-minute record for ROTATION
                last_min = mn; hist.append({"m": mn, "p": {s: v[0] for s, v in Q.items()}}); hist = [h for h in hist if h["m"] >= mn - 75]
                save({"day": day, "h": hist}, HF)
            V = compute(SEC, W, Q, hist, FO, wsrc, n); V["live"] = live
            if live and not once:                                             # patch 372: 🚀 a sector running - never stops the sectors
                try:
                    import secsurge
                    for e in secsurge.check(V, n):
                        log("surge: " + secsurge.line(e))
                except Exception as ex:
                    log("secsurge: %s" % str(ex)[:120])
            save(V, OUT)
            if not once:                                                      # patch 355: the sector candidates (a paper test) - never stops the sectors
                try:
                    import seccand
                    if live:
                        seccand.tick(n, SEC, W, Q, FO, kite)
                    else:
                        seccand.prefetch(n, FO, kite)                         # patch 367: the day's levels before the open, not at it
                        seccand.after_close(n)
                except Exception as ex:
                    log("seccand: %s" % str(ex)[:120])
            if once:
                print("SECTORS from %d shares · weights: %s · %s" % (V["shares"], V["weights"], V["at"]))
                for x in V["sectors"]:
                    print("  %-24s %+6.2f%%  (%3d shares, %2d F&O · %3d up %3d down · equal-weight %+.2f%%)  best %s %+.1f%%  worst %s %+.1f%%" % (
                        x["name"], x["chg"], x["n"], x["fo"], x["up"], x["dn"], x["eqw"], x["top"][0][0], x["top"][0][1], x["bot"][0][0], x["bot"][0][1]))
                for g in ("hospitals & diagnostics", "electronics & hardware", "telecom services", "telecom equipment"):   # patch 354c: who is in the new groups
                    m = sorted(s for s, v in SEC.items() if v == g); line = "  = %s (%d):" % (g, len(m))
                    for s in m:
                        if len(line) + len(s) > 66:
                            print(line); line = "     "
                        line += " " + s + ("*" if s in FO else "")
                    print(line)
                print("  (* = F&O)")
                return
        except Exception as ex:
            log("seclive: %s" % str(ex)[:160])
            if "token" in str(ex).lower():
                kite = None
            if once:
                return
            time.sleep(20)
        time.sleep(FAST_S if live else SLOW_S)


if __name__ == "__main__":
    main()
