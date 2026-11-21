#!/usr/bin/env python3
"""mfsec.py - READ ONLY. WHO, PART 2: INDIAN MUTUAL FUNDS' MONEY BY SECTOR, EVERY MONTH (Rama, 17 Nov: "we are talking only about FII - what about
DII and the other investors, where are they investing, where is the net flow?"). Mutual funds are the biggest part of DII. SEBI publishes each
month what all mutual funds together HOLD in shares of each industry (AMFI's industry list, ₹ crore and % of their equity money).
  1) WHERE THEY ARE   each sector: what the funds hold now and its share of their equity money - against 3 and 6 months ago (the share going up =
                      they are leaning into it, whatever the price did to everybody)
  2) THE NET FLOW     SEBI gives holdings, not purchases. Estimated buying = the change in the holding MINUS what the sector's price move alone
                      explains (Kite daily prices, all NSE shares of the sector). An estimate - marked "est." everywhere.
  3) FUNDS AGAINST FOREIGNERS   the same month, sector by sector: mutual funds' estimated buying next to the foreign funds' (fpisec.py, NSDL).
                      Do the Indian funds buy what the foreigners sell? Where are BOTH buying, where are BOTH selling?
  4) DOES IT LEAD     the sectors the funds bought most / sold most in a month (est.): the sector against the market over the NEXT 20 trading days,
                      from 15 trading days after the month's end (SEBI's page is out by then). Both halves shown.
  5) NOW              the newest month: both buying · both selling · funds buy what foreigners sell · foreigners buy what funds sell
Insurers (LIC), pension money, retail and promoters are NOT in any monthly or daily sector file - only in each company's quarterly shareholding.
Orders nothing, sends nothing; keeps the months in data/mfsec.json.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 mfsec.py [months=24]
  python3 mfsec.py probe     fetch the newest month and print its first rows (to check the reader against SEBI's page)
  python3 mfsec.py update    only fetch the months that are new
  python3 mfsec.py newest    which is the newest month SEBI's site has (17 Nov: its index stops at May 2025 - the 2026 pages answer "not found")
  -> prints, saves data/mfsec.txt"""
import os, re, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
STORE = os.path.join(D, "data", "mfsec.json")
URL = "https://www.sebi.gov.in/statistics/mutual-fund/deployment/%d/equity%s%02d.html"
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", "Accept": "text/html,*/*"}
LAG, HOLD = 15, 20
L = []
# AMFI's industry (a word in its name, the first that matches) -> the sector name NSDL uses for the foreign funds (so the two can be put side by side)
AMFI = (("bank", "Financial Services"), ("insurance", "Financial Services"), ("capital market", "Financial Services"), ("financ", "Financial Services"),
        ("software", "Information Technology"), ("it -", "Information Technology"), ("it-", "Information Technology"), ("pharma", "Healthcare"), ("health", "Healthcare"),
        ("auto", "Automobile and Auto Components"), ("petrol", "Oil, Gas & Consumable Fuels"), ("oil", "Oil, Gas & Consumable Fuels"), ("gas", "Oil, Gas & Consumable Fuels"),
        ("fuel", "Oil, Gas & Consumable Fuels"), ("power", "Power"), ("cement", "Construction Materials"), ("construction", "Construction"),
        ("consumer durable", "Consumer Durables"), ("consumer non", "Fast Moving Consumer Goods"), ("food", "Fast Moving Consumer Goods"), ("beverage", "Fast Moving Consumer Goods"),
        ("personal product", "Fast Moving Consumer Goods"), ("household product", "Fast Moving Consumer Goods"), ("fmcg", "Fast Moving Consumer Goods"), ("cigarette", "Fast Moving Consumer Goods"),
        ("tobacco", "Fast Moving Consumer Goods"), ("metal", "Metals & Mining"), ("mineral", "Metals & Mining"), ("mining", "Metals & Mining"), ("telecom", "Telecommunication"),
        ("media", "Media, Entertainment & Publication"), ("entertainment", "Media, Entertainment & Publication"), ("retail", "Consumer Services"), ("leisure", "Consumer Services"),
        ("hotel", "Consumer Services"), ("chemical", "Chemicals"), ("fertili", "Chemicals"), ("pesticide", "Chemicals"), ("industrial", "Capital Goods"),
        ("electrical", "Capital Goods"), ("aerospace", "Capital Goods"), ("defen", "Capital Goods"), ("engineering", "Capital Goods"), ("manufactur", "Capital Goods"),
        ("textile", "Textiles"), ("transport", "Services"), ("logistic", "Services"), ("commercial serv", "Services"), ("shipping", "Services"), ("airline", "Services"),
        ("realty", "Realty"), ("paper", "Forest Materials"), ("forest", "Forest Materials"), ("diversified", "Diversified"))
pc = lambda v: "  n/a " if v is None or v != v else "%+.2f%%" % (100 * v)
cr = lambda v: "     ?" if v is None else "%+.0f" % v


def say(s=""):
    L.append(s); print(s, flush=True)


def macro(name):
    n = name.lower()
    return next((m for k, m in AMFI if k in n), None)


def parse(html):
    """SEBI's monthly page -> {AMFI industry: (₹ crore, % of equity money)}: every table row that is a name followed by an amount and a percentage"""
    import fpisec
    g = fpisec.Grid(); g.feed(html); out = {}
    for rows in g.tables:
        for r in fpisec.expand(rows):
            name = next((x for x in r if re.search(r"[A-Za-z]{3}", x) and fpisec.num(x) is None), None)
            nums = [fpisec.num(x.rstrip("%")) for x in r if fpisec.num(x.rstrip("%")) is not None]
            if not name or len(nums) < 2 or re.search(r"total|derivative|sector classification|amount|sr\.? *no", name, re.I):
                continue
            amt, pct = nums[-2], nums[-1]
            if amt > 0 and 0 <= pct <= 100:
                out[re.sub(r"\s+", " ", name).strip().upper()] = (amt, pct)
    return out if len(out) >= 15 else {}


def months(today, n):
    """the last n month ends before today, newest first: (year, month)"""
    out, y, m = [], today.year, today.month
    while len(out) < n:
        m -= 1
        if m == 0:
            y, m = y - 1, 12
        out.append((y, m))
    return out


def get(y, m, quiet=True):
    import requests
    mon = dt.date(y, m, 1).strftime("%b").lower()
    for u in (URL % (y, mon, y % 100), URL % (y, dt.date(y, m, 1).strftime("%B").lower(), y % 100), (URL % (y, mon, y % 100)).replace("www.sebi.gov.in/", "www.sebi.gov.in/hindi/")):
        try:
            r = requests.get(u, headers=UA, timeout=30)
            if r.status_code == 200 and "<table" in r.text.lower() and len(r.text) > 3000:
                return r.text, u
            if not quiet:
                print("    %s -> %s (%d bytes)" % (u.rsplit("/", 2)[-2] + "/" + u.rsplit("/", 1)[1], r.status_code, len(r.content)), flush=True)
        except Exception as ex:
            if not quiet:
                print("    %s -> %s" % (u.rsplit("/", 1)[1], str(ex)[:70]), flush=True)
    return None, None


def load(all_=False):
    """the months kept. For the page (all_=False) an old record is NOT given: SEBI's page stopped in 2025 (probe, 17 Nov) - holdings more than
    4 months old must not be shown as where the funds are now."""
    try:
        j = json.load(open(STORE))
    except Exception:
        return {"m": {}, "files": {}}
    if not all_ and j.get("m"):
        k = max(j["m"]); t = dt.date.today()
        if (t.year * 12 + t.month) - (int(k[:4]) * 12 + int(k[5:])) > 4:
            return {"m": {}, "files": j.get("files", {}), "stale": k}
    return j


def update(today, n):
    S = load(True); new = fails = 0
    for i, (y, m) in enumerate(months(today, n)):
        k = "%04d-%02d" % (y, m)
        st = S["files"].get(k) or ""
        if st and not st.startswith("none") or st == "none:%s" % today and i > 2:      # kept · or looked for today already (the newest 3: always again)
            continue
        html, u = get(y, m)
        P = parse(html) if html else {}
        if not P:
            S["files"][k] = "none:%s" % today; fails += 1
            if html:
                say("  %s: fetched, but the table was not recognised - run `python3 mfsec.py probe`" % k)
            if fails >= 5 and not new and not S["m"]:
                say("  ❌ SEBI did not give the last %d months - run `python3 mfsec.py probe` and send the screen" % fails); break
            continue
        S["m"][k] = {a: list(v) for a, v in P.items()}; S["files"][k] = u; new += 1; time.sleep(0.4)
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    json.dump(S, open(STORE + ".tmp", "w")); os.replace(STORE + ".tmp", STORE)
    return S, new


def probe(today):
    import fpisec, requests
    for name, u in (("a 2025 page known to exist", URL % (2025, "may", 25)), ("SEBI's index page", "https://www.sebi.gov.in/statistics/mutual-fund/deployment-of-funds-by-all-mutual-funds.html")):
        try:
            r = requests.get(u, headers=UA, timeout=30)
            print("%s: %s (%d bytes)%s" % (name, r.status_code, len(r.content), " · %d industries read" % len(parse(r.text)) if "2025" in u and r.status_code == 200 else ""), flush=True)
            if "index" in name and r.status_code == 200:
                L_ = sorted(set(re.findall(r'href="([^"]*(?:deployment|equity)[^"]*)"', r.text, re.I)))
                print("  links on it (%d): %s" % (len(L_), " · ".join(x[-70:] for x in L_[-14:])))
                for m_ in re.findall(r"<option[^>]*value=\"([^\"]+)\"", r.text)[:14]:
                    print("  option:", m_[:90])
        except Exception as ex:
            print("%s: %s" % (name, str(ex)[:90]), flush=True)
    for y, m in months(today, 4):
        print("month %04d-%02d:" % (y, m), flush=True)
        html, u = get(y, m, quiet=False)
        if not html:
            print("  not there (yet)"); continue
        print("  got %s (%d bytes)" % (u, len(html)))
        g = fpisec.Grid(); g.feed(html); print("  tables: %s" % ", ".join("%d rows" % len(t) for t in g.tables))
        for i, r in enumerate(fpisec.expand(max(g.tables, key=len))[:8] if g.tables else []):
            print("  row %d (%d cells): %s" % (i, len(r), " ¦ ".join(x[:30] for x in r[:6])))
        P = parse(html); print("  the reader: %d industries%s" % (len(P), "" if P else " - NOT recognised"))
        for a, (amt, p) in sorted(P.items(), key=lambda kv: -kv[1][0])[:8]:
            print("    %-40s ₹%12.0f cr  %5.2f%%  -> %s" % (a[:40], amt, p, macro(a) or "(others)"))
        un = [a for a in P if not macro(a)]
        print("  not matched to a sector (%d): %s" % (len(un), ", ".join(un)[:400]))
        return
    print("SEBI gave none of the last 4 months from this server.")


def by_macro(P):
    """{AMFI industry: (cr, pct)} -> {sector: [cr, pct]}"""
    out = {}
    for a, (amt, p) in P.items():
        k = macro(a)
        if k:
            o = out.setdefault(k, [0.0, 0.0]); o[0] += amt; o[1] += p
    return out


def main():
    import seclive as SL
    today = SL.now().date()
    if sys.argv[1:2] == ["probe"]:
        return probe(today)
    if sys.argv[1:2] == ["newest"]:                       # which is the newest month SEBI's site has at all (looks back 3 years)
        found = []
        for y, m in months(today, 36):
            html, u = get(y, m)
            if html and parse(html):
                found.append("%04d-%02d" % (y, m))
                if len(found) >= 3:
                    break
            time.sleep(0.2)
        print("SEBI's newest months with the industry table: %s" % (", ".join(found) or "none in the last 3 years")); return
    if sys.argv[1:2] == ["update"]:
        S, new = update(today, 4); print("mfsec: %d new month(s) · %d kept · the newest is %s" % (new, len(S["m"]), max(S["m"]) if S["m"] else "none")); return
    nm = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 24
    say("📊 WHO, PART 2: INDIAN MUTUAL FUNDS' MONEY BY SECTOR · SEBI's monthly page · the last %d months" % nm)
    S, new = update(today, nm)
    M = sorted(S["m"])[-nm:]
    if len(M) < 4:
        say("  ❌ only %d months read - not enough. Run `python3 mfsec.py probe` and send the screen." % len(M)); return
    H = {k: by_macro({a: tuple(v) for a, v in S["m"][k].items()}) for k in M}
    secs = sorted(H[M[-1]], key=lambda s: -H[M[-1]][s][0])
    matched = sum(v[1] for v in H[M[-1]].values())
    say("  %d months kept (%s to %s) · %d fetched now · %d sectors · %.0f%% of the funds' equity money is matched to a sector (the rest: SEBI's 'others' and small industries)" % (
        len(M), M[0], M[-1], new, len(secs), matched))
    say("")
    say("1) WHERE THEY ARE - what all mutual funds hold, and each sector's share of their equity money now against 3 and 6 months ago")
    say("    %-34s %11s │ %7s │ %9s %9s" % ("sector", "they hold", "share", "vs 3 mo", "vs 6 mo"))
    mb = lambda k, n: (lambda t: "%04d-%02d" % (t // 12, t % 12 + 1))(int(k[:4]) * 12 + int(k[5:]) - 1 - n)       # the month n months before k
    back = lambda s, n: (H[M[-1]][s][1] - H[mb(M[-1], n)][s][1]) if mb(M[-1], n) in H and s in H[mb(M[-1], n)] else None
    for s in sorted(secs, key=lambda s: -(back(s, 3) or 0)):
        b3, b6 = back(s, 3), back(s, 6)
        say("    %-34s %11.0f │ %6.2f%% │ %9s %9s%s" % (s[:34], H[M[-1]][s][0], H[M[-1]][s][1], ("%+.2f pt" % b3) if b3 is not None else "?", ("%+.2f pt" % b6) if b6 is not None else "?",
            "   ▲ leaning in" if (b3 or 0) >= 0.3 else "   ▼ leaning out" if (b3 or 0) <= -0.3 else ""))
    # prices -> the estimate of the net flow
    try:
        import numpy as np, flowtest, fpisec
        SEC, _ = SL.universe(); W, _w = SL.nse_weights(); RAW = flowtest.daily(SL.get_kite, list(SEC), 500)
    except Exception as ex:
        say(""); say("  (prices not read: %s - parts 2 to 5 need them)" % str(ex)[:90]); return done()
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W))
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]}); di = {d: i for i, d in enumerate(days)}; n, m_ = len(days), len(syms)
    Cl = np.full((n, m_), np.nan)
    for j, s in enumerate(syms):
        for r in RAW[s]:
            Cl[di[int(r[0])], j] = r[4]
    cc = Cl[1:] / Cl[:-1] - 1; cc[np.isnan(cc) | (np.abs(cc) > 0.25)] = np.nan; cc = np.vstack([np.full((1, m_), np.nan), cc])
    Wv = np.array([W.get(s) or 1.0 for s in syms])

    def wm(idx):
        x = cc[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x); sm = w.sum(1); sm[sm == 0] = np.nan
        return np.nan_to_num(np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / sm)
    mk = wm(np.arange(m_)); ABS = {}
    for s in secs:
        g = fpisec.gir_groups(s); idx = np.array([j for j, y in enumerate(syms) if g and SEC[y] in g])
        if len(idx) >= 4:
            ABS[s] = wm(idx)
    pos = lambda d: max((i for i, x in enumerate(days) if x <= d.toordinal()), default=None)
    mend = lambda k: (dt.date(int(k[:4]) + (k[5:] == "12"), int(k[5:]) % 12 + 1, 1) - dt.timedelta(days=1))
    EST = {}                                                  # {(month, sector): (est. net ₹ cr, as a share of the holding before)}
    for i in range(1, len(M)):
        a, b = pos(mend(M[i - 1])), pos(mend(M[i]))
        if a is None or b is None or b <= a or M[i - 1] != mb(M[i], 1):          # a missing month: no estimate across the gap
            continue
        for s in ABS:
            if s in H[M[i]] and s in H[M[i - 1]] and H[M[i - 1]][s][0] > 0:
                ret = float(np.prod(1 + ABS[s][a + 1:b + 1]) - 1); h0 = H[M[i - 1]][s][0]
                e = H[M[i]][s][0] - h0 * (1 + ret); EST[(M[i], s)] = (e, e / h0, a, b)
    say("")
    say("2) THE NET FLOW (est.) - the change in what they hold minus what the sector's price move alone explains, ₹ crore, the newest month first")
    last = [k for k in M[::-1] if any((k, s) in EST for s in ABS)][:5]
    say("    %-34s │ %s │ last 3 months" % ("sector", " ".join("%8s" % k for k in last)))
    T3 = {s: sum(EST[(k, s)][0] for k in last[:3] if (k, s) in EST) for s in ABS}
    for s in sorted(ABS, key=lambda s: -T3[s] / H[M[-1]][s][0]):
        say("    %-34s │ %s │ %+9.0f cr = %s of holding" % (s[:34], " ".join("%8s" % (cr(EST[(k, s)][0]) if (k, s) in EST else "?") for k in last), T3[s], pc(T3[s] / H[M[-1]][s][0])))
    say("    (an estimate: the funds' own shares do not move exactly like the whole sector, and SEBI re-labels industries now and then)")
    # mutual funds against the foreign funds, the same month
    FP = {}
    try:
        j = json.load(open(os.path.join(D, "data", "fpisec.json")))
        for k, v in j["net"].items():
            for s, x in v.items():
                FP[(k[:7], s)] = FP.get((k[:7], s), 0.0) + x
        fheld = lambda s: next((j["auc"][a].get(s) for a in sorted(j["auc"], reverse=True) if j["auc"][a].get(s)), None)
    except Exception:
        fheld = lambda s: None
    say("")
    if not FP:
        say("3) FUNDS AGAINST FOREIGNERS - the foreign funds' record (data/fpisec.json) is not there: run `python3 fpisec.py` once")
    else:
        say("3) FUNDS AGAINST FOREIGNERS - the same month, sector by sector: do the Indian funds buy what the foreigners sell?")
        opp = same = 0; pairs = []
        for (k, s), (e, es, a, b) in EST.items():
            f = FP.get((k, s))
            if f is None or abs(f) < 50 or abs(e) < 50:
                continue
            pairs.append((k, s, e, f)); opp += e * f < 0; same += e * f > 0
        if len(pairs) < 30:
            say("    only %d sector-months with both - too few to say" % len(pairs))
        else:
            fs_ = [p for p in pairs if p[3] < 0]; fb_ = [p for p in pairs if p[3] > 0]
            say("    %d sector-months · opposite sides in %d (%d%%) · the same side in %d" % (len(pairs), opp, 100 * opp / len(pairs), same))
            say("    when foreigners SOLD a sector (%d): the funds bought it %d%% of the time · when foreigners BOUGHT (%d): the funds bought it %d%%" % (
                len(fs_), 100 * sum(1 for p in fs_ if p[2] > 0) / max(1, len(fs_)), len(fb_), 100 * sum(1 for p in fb_ if p[2] > 0) / max(1, len(fb_))))
    # does the funds' buying lead the price
    say("")
    say("4) DOES IT LEAD? - the sectors the funds bought most / sold most in a month (est.), then the sector against the market over the next %d" % HOLD)
    say("   trading days, from %d trading days after the month's end" % LAG)
    rel = {s: ABS[s] - mk for s in ABS}; diffs = []; allv = []
    for k in M:
        R = sorted(((EST[(k, s)][1], s, EST[(k, s)][3]) for s in ABS if (k, s) in EST), reverse=True)
        if len(R) < 10 or R[0][2] + LAG + HOLD >= n:
            continue
        b = R[0][2]; nx = lambda s: float(rel[s][b + LAG + 1:b + LAG + HOLD + 1].sum())
        t, bt = sum(nx(s) for _, s, _ in R[:4]) / 4, sum(nx(s) for _, s, _ in R[-4:]) / 4; diffs.append((t, bt)); allv.append(k)
    if len(diffs) < 8:
        say("    only %d months with the next period complete - too few to say" % len(diffs))
    else:
        av = lambda x: sum(x) / len(x); d_ = [t - b for t, b in diffs]; h = len(d_) // 2
        ok = av(d_[:h]) * av(d_[h:]) > 0 and abs(av(d_)) >= 0.004
        say("    the 4 most bought %s · the 4 most sold %s · difference %s · the bought beat the sold in %d of %d months" % (pc(av([t for t, _ in diffs])), pc(av([b for _, b in diffs])), pc(av(d_)), sum(1 for x in d_ if x > 0), len(d_)))
        say("    by half of the history: %s / %s → %s   (%d months is a small sample)" % (pc(av(d_[:h])), pc(av(d_[h:])), "✔ steady in both halves" if ok else "✘ not steady - no edge", len(d_)))
    # now
    say("")
    k = last[0] if last else None
    if k:
        say("5) NOW (%s) - the funds' estimated buying next to the foreign funds' for the same month, as a %% of what each holds" % k)
        G = {"BOTH BUYING": [], "BOTH SELLING": [], "FUNDS BUY what FOREIGNERS SELL": [], "FOREIGNERS BUY what FUNDS SELL": []}
        for s in ABS:
            if (k, s) not in EST:
                continue
            e, es = EST[(k, s)][:2]; f = FP.get((k, s)); fh = fheld(s); fs_ = (f / fh) if f is not None and fh else None
            if fs_ is None or abs(es) < 0.002 or abs(fs_) < 0.001:
                continue
            key = "BOTH BUYING" if es > 0 and fs_ > 0 else "BOTH SELLING" if es < 0 and fs_ < 0 else "FUNDS BUY what FOREIGNERS SELL" if es > 0 else "FOREIGNERS BUY what FUNDS SELL"
            G[key].append((abs(es) + abs(fs_), "%s (funds %s est. · foreigners %s)" % (s, pc(es), pc(fs_))))
        if not any(G.values()):
            say("    the foreign funds' record does not cover %s yet (run `python3 fpisec.py update`), or nothing is big enough to list" % k)
        for name, v in G.items():
            if v:
                say("    %-32s %s" % (name + ":", " · ".join(x for _, x in sorted(v, reverse=True)[:6])))
    done()


def done():
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "mfsec.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/mfsec.txt")


if __name__ == "__main__":
    main()
