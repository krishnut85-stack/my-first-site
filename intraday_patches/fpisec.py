#!/usr/bin/env python3
"""fpisec.py - READ ONLY. WHO: FOREIGN FUNDS' MONEY BY SECTOR, EVERY 15 DAYS (Rama, 17 Nov: "someone is moving the sector ... at least we can see
the trend and build from there"). The exchange does not say who is behind each order, but NSDL publishes, for every fortnight, how much foreign
portfolio investors (FPIs) bought or sold in EACH SECTOR and how much they hold. It is the one official record of who put money where.
  1) THE TREND   each sector: what FPIs hold, their net buying / selling in each of the last 6 fortnights, the run ("BUYING 4 in a row"), and the
                 last 3 months as a % of what they hold
  2) ARE THEY THE MOVERS?  in the SAME fortnight: did the sectors they bought most rise more than the ones they sold most? (prices: Kite's daily
                 candles, every NSE share of the sector, size-weighted, against the whole market)
  3) CAN IT BE USED?  the report comes out some days AFTER the fortnight ends. From 6 trading days after the end, over the next 10 trading days:
                 do the most-bought sectors keep beating the most-sold? And sectors bought / sold 3 fortnights in a row?
  4) NOW         the sectors with a run of buying or selling, and their biggest F&O shares
A result is shown for both halves of the history; "too few" is said when it is. Orders nothing, sends nothing; keeps the reports in data/fpisec.json.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 fpisec.py [fortnights=48]
  python3 fpisec.py update     only fetch the reports that are new (the evening timer)
  python3 fpisec.py probe      fetch the newest report and print its raw header rows and first lines (to check the reader against NSDL's layout)
  -> prints, saves data/fpisec.txt"""
import os, re, sys, json, time, datetime as dt
from html.parser import HTMLParser
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
STORE = os.path.join(D, "data", "fpisec.json")
BASE = "https://%s/web/StaticReports/Fortnightly_Sector_wise_FII_Investment_Data/FIIInvestSector_%s%d%d.%s"
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", "Accept": "text/html,*/*"}
MON = {m: i + 1 for i, m in enumerate(("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"))}
LAG, HOLD = 6, 10                                        # trading days after the fortnight's end before the report can be used · days then held
L = []
# NSDL's sector (a word in its name) -> the GIR page's sectors (seclive.py) that make it up
MAP = (("auto", ("auto",)), ("capital goods", ("capital goods", "electronics & hardware")), ("chemical", ("chemicals",)), ("construction material", ("cement & materials",)),
       ("construction", ("construction",)), ("consumer durable", ("consumer durables",)), ("consumer service", ("consumer services",)), ("diversified", ("diversified",)),
       ("fast moving", ("fmcg",)), ("financial", ("banks", "nbfc & finance", "insurance", "capital markets")), ("forest", ("forest materials",)),
       ("health", ("pharma", "hospitals & diagnostics")), ("information tech", ("it",)), ("media", ("media",)), ("metal", ("metals & mining",)), ("oil", ("oil & gas",)),
       ("power", ("power",)), ("realty", ("realty",)), ("telecom", ("telecom services", "telecom equipment")), ("textile", ("textiles",)), ("utilit", ("utilities",)),
       ("services", ("services",)))
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def gir_groups(name):
    n = name.lower()
    return next((g for k, g in MAP if k in n), None)


class Grid(HTMLParser):
    """every <table> of a page -> rows of (text, colspan, rowspan)"""
    def __init__(self):
        super().__init__(); self.tables = []; self.stack = []; self.cell = None

    def handle_starttag(self, tag, a):
        a = dict(a)
        if tag == "table":
            self.stack.append([])
        elif tag == "tr" and self.stack:
            self.stack[-1].append([])
        elif tag in ("td", "th") and self.stack and self.stack[-1]:
            n = lambda k: max(1, int(re.sub(r"\D", "", a.get(k) or "") or 1))
            self.cell = ["", n("colspan"), n("rowspan")]
        elif tag == "br" and self.cell is not None:
            self.cell[0] += " "

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None and self.stack and self.stack[-1]:
            self.cell[0] = re.sub(r"\s+", " ", self.cell[0].replace("\xa0", " ")).strip(); self.stack[-1][-1].append(tuple(self.cell)); self.cell = None
        elif tag == "table" and self.stack:
            self.tables.append(self.stack.pop())

    def handle_data(self, d):
        if self.cell is not None:
            self.cell[0] += d


def expand(rows):
    """rows of (text, colspan, rowspan) -> a rectangle of texts (a spanning cell repeats its text)"""
    out, hold = [], {}
    for r in rows:
        line, c, it = [], 0, iter(r)
        while True:
            if c in hold:
                t, left = hold[c]; line.append(t); hold[c] = (t, left - 1)
                if left - 1 <= 0:
                    del hold[c]
                c += 1; continue
            x = next(it, None)
            if x is None:
                if not any(k > c for k in hold):
                    break
                line.append(""); c += 1; continue
            t, cs, rs = x
            for _ in range(cs):
                line.append(t)
                if rs > 1:
                    hold[c] = (t, rs - 1)
                c += 1
        out.append(line)
    w = max((len(x) for x in out), default=0)
    return [x + [""] * (w - len(x)) for x in out]


def num(t):
    t = (t or "").replace(",", "").replace("−", "-").strip()
    if re.fullmatch(r"\(\s*[\d.]+\s*\)", t):
        t = "-" + t.strip("() ")
    try:
        return float(t)
    except ValueError:
        return None


def pdate(mon, day, year):
    m = MON.get(mon[:3].lower())
    return dt.date(int(year), m, int(day)) if m else None


def parse(html):
    """NSDL's report -> ({fortnight end: {sector: net equity ₹ cr}}, {date: {sector: equity held ₹ cr}}, note). The columns are found from the
    header text ("Net Investment <month> <d>-<d>, <year>" / "AUC as on <date>" over "Equity", in INR), not from fixed positions."""
    g = Grid(); g.feed(html)
    for rows in sorted(g.tables, key=lambda r: -len(r)):
        G = expand(rows)
        first = next((i for i, r in enumerate(G) if sum(1 for x in r if num(x) is not None) >= 5 and any(re.search(r"[A-Za-z]{4}", x) for x in r[:3])), None)
        if first is None or first == 0 or len(G) - first < 12:
            continue
        w = len(G[0]); H = []
        for c in range(w):
            seen = []
            for r in G[:first]:
                if r[c] and r[c] not in seen:
                    seen.append(r[c])
            H.append(" | ".join(seen).lower())
        sc = next((c for c in range(min(4, w)) if "sector" in H[c]), None)
        if sc is None:
            sc = next((c for c in range(min(4, w)) if sum(1 for r in G[first:] if re.search(r"[A-Za-z]{4}", r[c])) > 10), 1)
        eq = lambda h: re.search(r"\bequity\b", h) and not re.search(r"usd|mutual|hybrid|debt|aif|\bmf\b", h)
        net, auc = {}, {}
        for c in range(w):
            h = H[c]
            if not eq(h):
                continue
            m = re.search(r"net investment[^|]*?([a-z]{3,9})\.? +(\d{1,2}) *(?:-|–|to) *(?:[a-z]{3,9}\.? +)?(\d{1,2}),? *(\d{4})", h)
            a = re.search(r"auc as on[^|]*?([a-z]{3,9})\.? +(\d{1,2}),? *(\d{4})", h)
            key = pdate(m.group(1), m.group(3), m.group(4)) if m else pdate(a.group(1), a.group(2), a.group(3)) if a else None
            if key and (m or a):
                (net if m else auc).setdefault(str(key), c)                    # the first matching column = the INR one
        if not net:
            continue
        N, A = {k: {} for k in net}, {k: {} for k in auc}
        for r in G[first:]:
            name = r[sc].strip()
            if not re.search(r"[A-Za-z]{4}", name) or re.match(r"(grand )?total", name, re.I):
                continue
            for k, c in net.items():
                v = num(r[c])
                if v is not None:
                    N[k][name] = v
            for k, c in auc.items():
                v = num(r[c])
                if v is not None:
                    A[k][name] = v
        if max(len(v) for v in N.values()) >= 12:
            return N, A, "%d sectors, columns: %s" % (max(len(v) for v in N.values()), ", ".join("net %s" % k for k in sorted(net)))
    return {}, {}, "the layout was not recognised"


HIT = []                                                 # the (month style, host, extension) that worked last - tried first for the next date


def urls(d):
    """NSDL's file names are not uniform (Dec152023 · July312024 · JUL152023 · .htm in old years): every spelling, the one that worked last first"""
    b, B = d.strftime("%b"), d.strftime("%B")
    mons = list(dict.fromkeys((b, B, b.upper(), B.upper(), "Sept" if b == "Sep" else b)))
    combos = [(i, host, ext) for ext in ("html", "htm") for i in range(len(mons)) for host in ("www.fpi.nsdl.co.in", "fpi.nsdl.co.in")]
    for i, host, ext in sorted(combos, key=lambda c: c not in HIT[-1:]):
        yield (i, host, ext), BASE % (host, mons[i], d.day, d.year, ext)


def ends(today, n):
    """the last n fortnight ends (the 15th and the month's last day) before today, newest first"""
    out, d = [], today
    while len(out) < n:
        d -= dt.timedelta(days=1)
        if d.day == 15 or (d + dt.timedelta(days=1)).day == 1:
            out.append(d)
    return out


def get(d, quiet=True):
    """one fortnight's report -> html or None"""
    import requests
    for combo, u in urls(d):
        try:
            r = requests.get(u, headers=UA, timeout=25)
            if r.status_code == 200 and "<table" in r.text.lower() and len(r.text) > 3000:
                HIT.append(combo); return r.text, u
            if not quiet:
                print("    %s -> %s (%d bytes)" % (u.rsplit("/", 1)[1], r.status_code, len(r.content)), flush=True)
        except Exception as ex:
            if not quiet:
                print("    %s -> %s" % (u.rsplit("/", 1)[1], str(ex)[:70]), flush=True)
            if "resolve" in str(ex).lower() or "timed out" in str(ex).lower():
                break
    return None, None


def load():
    try:
        return json.load(open(STORE))
    except Exception:
        return {"net": {}, "auc": {}, "files": {}}


def update(today, n):
    """fetch the reports not yet kept (the newest two are always tried again: NSDL publishes late) -> the store"""
    S = load(); E = ends(today, n); new = fails = 0
    for i, d in enumerate(E):
        k = str(d)
        st = S["files"].get(k) or ""
        if st and not st.startswith("none") or st == "none:%s" % today and i > 2:      # kept · or looked for today already (the newest 3: always again)
            continue
        html, u = get(d)
        if not html:
            S["files"][k] = "none:%s" % today; fails += 1
            if fails >= 6 and not new and not S["net"]:
                say("  ❌ NSDL did not give the last %d reports - run `python3 fpisec.py probe` and send the screen" % fails); break
            continue
        N, A, note = parse(html)
        if not N:
            S["files"][k] = "none:%s" % today; say("  %s: fetched, but %s - run `python3 fpisec.py probe`" % (d, note)); continue
        for kk, v in N.items():
            if len(v) >= len(S["net"].get(kk, {})):
                S["net"][kk] = v
        for kk, v in A.items():
            S["auc"][kk] = v
        S["files"][k] = u; new += 1; time.sleep(0.4)
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    json.dump(S, open(STORE + ".tmp", "w")); os.replace(STORE + ".tmp", STORE)
    return S, new


def probe(today):
    for d in ends(today, 4):
        print("fortnight ending %s:" % d, flush=True)
        html, u = get(d, quiet=False)
        if not html:
            print("  not there (yet)"); continue
        print("  got %s (%d bytes)" % (u, len(html)))
        g = Grid(); g.feed(html); print("  tables: %s" % ", ".join("%d rows" % len(t) for t in g.tables))
        G = expand(max(g.tables, key=len)) if g.tables else []
        for i, r in enumerate(G[:9]):
            print("  row %d (%d cells): %s" % (i, len(r), " ¦ ".join(x[:22] for x in r[:14])))
        N, A, note = parse(html); print("  the reader: %s" % note)
        for k in sorted(N):
            print("  net %s: %s" % (k, " · ".join("%s %+.0f" % (s[:18], v) for s, v in list(N[k].items())[:6])))
        for k in sorted(A):
            print("  held %s: %s" % (k, " · ".join("%s %.0f" % (s[:18], v) for s, v in list(A[k].items())[:4])))
        return
    print("NSDL gave none of the last 4 reports from this server.")


def main():
    import seclive as SL
    today = SL.now().date()
    if sys.argv[1:2] == ["probe"]:
        return probe(today)
    if sys.argv[1:2] == ["update"]:                      # the evening timer (patch 356): only fetch what is new - no prices, no test
        S, new = update(today, 8); F = sorted(k for k, v in S["net"].items() if len(v) >= 12)
        print("fpisec: %d new report(s) · %d fortnights kept · the newest ends %s" % (new, len(F), F[-1] if F else "none")); return
    nf = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 48
    say("📊 WHO: FOREIGN FUNDS' MONEY BY SECTOR · NSDL's fortnightly report · the last %d fortnights" % nf)
    S, new = update(today, nf)
    F = sorted(k for k, v in S["net"].items() if len(v) >= 12)[-nf:]
    if len(F) < 3:
        say("  ❌ only %d fortnights read - not enough. Run `python3 fpisec.py probe` and send the screen." % len(F)); return
    say("  %d fortnights kept (%s to %s) · %d fetched now · the newest report is for the fortnight ending %s" % (len(F), F[0], F[-1], new, dt.date.fromisoformat(F[-1]).strftime("%d %b")))
    secs = [s for s in S["net"][F[-1]] if gir_groups(s)]
    other = [s for s in S["net"][F[-1]] if not gir_groups(s)]
    held = lambda s, k: next((S["auc"][a].get(s) for a in sorted(S["auc"], reverse=True) if a <= k and S["auc"][a].get(s)), None)

    def run(s, upto):
        """(direction, length) of the unbroken run of buying / selling ending at fortnight index `upto`"""
        v0 = S["net"][F[upto]].get(s)
        if not v0:
            return 0, 0
        sg, n = (1 if v0 > 0 else -1), 0
        for i in range(upto, -1, -1):
            v = S["net"][F[i]].get(s)
            if v is None or v * sg <= 0:
                break
            n += 1
        return sg, n
    say("")
    say("1) THE TREND - FPIs' net buying (+) / selling (-) of shares in each sector, ₹ crore, the newest fortnight first")
    say("    %-34s %9s │ %s │ %-22s │ last 3 months" % ("sector (NSDL)", "they hold", " ".join("%7s" % dt.date.fromisoformat(k).strftime("%d%b") for k in F[::-1][:6]), "run"))
    T = []
    for s in secs:
        h = held(s, F[-1]); last6 = [S["net"][k].get(s) for k in F[::-1][:6]]; sg, n = run(s, len(F) - 1)
        tot = sum(v for v in last6 if v is not None)
        T.append((tot / h if h else 0, s, h, last6, sg, n, tot))
    for share, s, h, last6, sg, n, tot in sorted(T, reverse=True):
        say("    %-34s %9s │ %s │ %-22s │ %+8.0f cr = %s of holding" % (s[:34], ("%.0f" % h) if h else "?", " ".join("%7s" % ("%+.0f" % v if v is not None else "?") for v in last6),
            ("%s %d in a row" % ("BUYING" if sg > 0 else "SELLING", n)) if n >= 2 else "mixed", tot, pc(share) if h else "?"))
    if other:
        say("    (not matched to a GIR sector, left out: %s)" % ", ".join(other))

    # prices: every NSE share of the sector, size-weighted, against the whole market
    try:
        import numpy as np, flowtest
        SEC, _ = SL.universe(); FO = SL.fo_set(); W, _w = SL.nse_weights()
        RAW = flowtest.daily(SL.get_kite, list(SEC), 500)
    except Exception as ex:
        say(""); say("  (prices not read: %s - the trend above stands on its own)" % str(ex)[:90]); return finish()
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W))
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]}); di = {d: i for i, d in enumerate(days)}; n, m = len(days), len(syms)
    Cl = np.full((n, m), np.nan)
    for j, s in enumerate(syms):
        for r in RAW[s]:
            Cl[di[int(r[0])], j] = r[4]
    cc = Cl[1:] / Cl[:-1] - 1; cc[np.isnan(cc) | (np.abs(cc) > 0.25)] = np.nan; cc = np.vstack([np.full((1, m), np.nan), cc])
    Wv = np.array([W.get(s) or 1.0 for s in syms])

    def wm(idx):
        x = cc[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x); sm = w.sum(1); sm[sm == 0] = np.nan
        return np.nan_to_num(np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / sm)
    mk = wm(np.arange(m)); REL = {}
    for s in secs:
        idx = np.array([j for j, y in enumerate(syms) if SEC[y] in gir_groups(s)])
        if len(idx) >= 4:
            REL[s] = wm(idx) - mk
    pos = lambda d: max((i for i, x in enumerate(days) if x <= d.toordinal()), default=None)     # the last trading day on or before d
    span = lambda s, a, b: float(REL[s][a + 1:b + 1].sum()) if a is not None and b is not None and b > a else None
    rows = []                                                                                      # per fortnight: sector, flow %, same, next, run
    for i, k in enumerate(F):
        e = dt.date.fromisoformat(k); st = (e.replace(day=1) if e.day == 15 else e.replace(day=16)) - dt.timedelta(days=1)
        a, b = pos(st), pos(e)
        if a is None or b is None or b <= a:
            continue
        for s in REL:
            v, h = S["net"][k].get(s), held(s, k)
            if v is None or not h:
                continue
            nx = span(s, b + LAG, b + LAG + HOLD) if b + LAG + HOLD < n else None
            fw = lambda k_: span(s, b + LAG, b + LAG + k_) if b + LAG + k_ < n else None
            rows.append({"f": i, "s": s, "flow": v / h, "same": span(s, a, b), "next": nx, "run": run(s, i), "before": run(s, i - 1) if i else (0, 0),
                         "prior": span(s, b - 60, b) if b >= 60 else None, "n20": fw(20), "n40": fw(40)})
    nfp = len({r["f"] for r in rows})
    say("")
    if nfp < 8:
        say("2) and 3): only %d fortnights have both the report and prices - too few to test. The trend above is still the official record." % nfp); return finish(secs, T, SEC, FO, W)

    def versus(key, title):
        d_, wins, tops, bots, fs = [], 0, [], [], []
        for f in sorted({r["f"] for r in rows}):
            R = sorted((r for r in rows if r["f"] == f and r[key] is not None), key=lambda r: -r["flow"])
            if len(R) < 8:
                continue
            k = 5 if len(R) >= 14 else 3
            t, b = sum(r[key] for r in R[:k]) / k, sum(r[key] for r in R[-k:]) / k
            d_.append(t - b); tops.append(t); bots.append(b); fs.append(f); wins += t > b
        if len(d_) < 8:
            say("    %s: only %d fortnights - too few to say" % (title, len(d_))); return
        h = len(d_) // 2; av = lambda x: sum(x) / len(x)
        ok = av(d_[:h]) * av(d_[h:]) > 0 and abs(av(d_)) >= 0.003
        say("    %s" % title)
        say("      the most bought sectors %s · the most sold %s · difference %s · the bought beat the sold in %d of %d fortnights (%d%%)" % (pc(av(tops)), pc(av(bots)), pc(av(d_)), wins, len(d_), 100 * wins / len(d_)))
        say("      by half of the history: %s / %s → %s" % (pc(av(d_[:h])), pc(av(d_[h:])), "✔ steady in both halves" if ok else "✘ not steady - no edge"))
    say("2) ARE THEY THE MOVERS? - the SAME fortnight, each sector against the whole market")
    versus("same", "sectors ranked by FPI buying as a % of what they hold (the top 5 against the bottom 5):")
    say("")
    say("3) CAN IT BE USED? - from %d trading days after the fortnight ends (the report is out), over the next %d trading days" % (LAG, HOLD))
    versus("next", "the same ranking, the NEXT period:")
    for sg, name in ((1, "bought 3+ fortnights in a row"), (-1, "sold 3+ fortnights in a row")):
        X = [r["next"] for r in rows if r["next"] is not None and r["run"][0] == sg and r["run"][1] >= 3]
        if len(X) < 20:
            say("    sectors %s: %d cases - too few to say" % (name, len(X)))
        else:
            h = len(X) // 2
            say("    sectors %s: %d cases · next period %s against the market · up %d%% · halves %s / %s" % (name, len(X), pc(sum(X) / len(X)), 100 * sum(1 for x in X if x > 0) / len(X), pc(sum(X[:h]) / h), pc(sum(X[h:]) / (len(X) - h))))
    say("    (a fortnight is one case: %d cases is a small sample - read the halves, not the average)" % nfp)
    say("")
    say("3b) WHAT THEY BUY, AND WHEN IT PAYS (Rama, 17 Nov: \"they are buying IT, which was hit hardest in the last months\") - the buying split by")
    say("    what the sector had done in the 3 months before · then the next 10 / 20 / 40 trading days against the market, from %d days after the fortnight" % LAG)
    P = {}
    for f in sorted({r["f"] for r in rows}):
        R = sorted((r for r in rows if r["f"] == f and r["prior"] is not None), key=lambda r: r["prior"]); k = len(R) // 3
        if k >= 2:
            for r in R[:k]:
                P[(f, r["s"])] = "fall"
            for r in R[-k:]:
                P[(f, r["s"])] = "rise"

    def grp(name, X):
        X = [r for r in X if r["n20"] is not None]
        if len(X) < 15:
            say("    %-46s %3d cases - too few to say" % (name, len(X))); return
        av = lambda key, Y=X: (lambda v: sum(v) / len(v) if v else float("nan"))([r[key] for r in Y if r[key] is not None])
        h = len(X) // 2; a, b = av("n20", X[:h]), av("n20", X[h:])
        ok = a * b > 0 and min(abs(a), abs(b)) >= 0.003
        say("    %-46s %3d cases │ 10d %s │ 20d %s up %2d%% │ 40d %s │ 20d by half %s / %s %s" % (name, len(X), pc(av("next")), pc(av("n20")), 100 * sum(1 for r in X if r["n20"] > 0) / len(X),
            pc(av("n40")), pc(a), pc(b), "✔ steady" if ok else "✘ not steady"))
    bought = [r for r in rows if r["flow"] >= 0.001]; sold = [r for r in rows if r["flow"] <= -0.001]
    grp("every sector, every fortnight (the yardstick)", rows)
    grp("BOUGHT after a FALL (its worst third)", [r for r in bought if P.get((r["f"], r["s"])) == "fall"])
    grp("BOUGHT after a RISE (its best third)", [r for r in bought if P.get((r["f"], r["s"])) == "rise"])
    grp("SOLD after a FALL", [r for r in sold if P.get((r["f"], r["s"])) == "fall"])
    grp("SOLD after a RISE", [r for r in sold if P.get((r["f"], r["s"])) == "rise"])
    grp("not touched (under 0.1%) after a FALL", [r for r in rows if abs(r["flow"]) < 0.001 and P.get((r["f"], r["s"])) == "fall"])
    grp("THE TURN: first buying after 3+ selling", [r for r in bought if r["before"][0] < 0 and r["before"][1] >= 3])
    grp("THE TURN: first selling after 3+ buying", [r for r in sold if r["before"][0] > 0 and r["before"][1] >= 3])
    say("    bought / sold = at least 0.1% of what they hold in that fortnight · fall / rise = the sector's 3 months before, against the other sectors")
    now3 = {s: float(REL[s][-60:].sum()) for s in REL}
    finish(secs, T, SEC, FO, W, now3, F[-1], S)


def finish(secs=None, T=None, SEC=None, FO=None, W=None, now3=None, last=None, S=None):
    if T and SEC:
        say("")
        say("4) NOW - the sectors with a run of 3 or more fortnights, and their biggest F&O shares")
        any_ = False
        for share, s, h, last6, sg, n, tot in sorted(T, key=lambda x: -x[5] * x[4]):
            if n < 3:
                continue
            any_ = True; g = gir_groups(s)
            fo = sorted((y for y in SEC if SEC[y] in g and y in FO), key=lambda y: -(W.get(y) or 0))[:8]
            say("    %s %-30s %d fortnights in a row · last 3 months %+.0f cr · F&O: %s" % ("▲ BUYING " if sg > 0 else "▼ SELLING", s[:30], n, tot, " ".join(fo) or "none"))
        if not any_:
            say("    none - no sector has 3 fortnights in a row one way")
        if now3 and last and S:
            say("")
            say("    the newest fortnight (to %s) against each sector's last 3 months (60 trading days to today, against the market):" % dt.date.fromisoformat(last).strftime("%d %b"))
            order = sorted(now3, key=lambda k: now3[k]); k3 = max(2, len(order) // 3); low, high = set(order[:k3]), set(order[-k3:])
            for share, s, h, last6, sg, n, tot in sorted(T, key=lambda x: -((x[3][0] or 0) / x[2] if x[2] else 0)):
                if s not in now3 or last6[0] is None or not h:
                    continue
                fl = last6[0] / h
                tag = ("BOUGHT" if fl >= 0.001 else "SOLD" if fl <= -0.001 else "not touched") + (" after a FALL" if s in low else " after a RISE" if s in high else "")
                say("      %-34s %+8.0f cr (%s of holding) · its 3 months %s → %s" % (s[:34], last6[0], pc(fl), pc(now3[s]), tag))
        say("    The states above are scored in 3b - read a state's line there before leaning on it.")
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "fpisec.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/fpisec.txt")


if __name__ == "__main__":
    main()
