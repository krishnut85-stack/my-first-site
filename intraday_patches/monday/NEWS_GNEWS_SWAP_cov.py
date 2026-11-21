"""per-share coverage BEFORE (Google News) / AFTER (publisher feeds + NSE / BSE filings) for the 218 F&O names. Read only."""
import sys, json, time, sqlite3, statistics, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday/v2/server")
import news_gate as G
V2 = "/home/globalbot/intraday/v2"
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
A = json.load(open(V2 + "/newsread/ref/aliases.json"))["shares"]
FO = set(A)
BSE = {r["bse_code"]: s for s, r in A.items() if r.get("bse_code")}
NOW = time.time()


def ep(x):
    try:
        return dt.datetime.fromisoformat(str(x)).timestamp()
    except Exception:
        return None


def named(h):
    return {s for s, _ in G.names_in(h or "")}


# ---- rows: (t_seen, sym, delay_s, source_family)
gn, pub = [], []
c = sqlite3.connect("file:/home/globalbot/intraday/news.db?mode=ro", uri=True)
for sym, src, dom, tp, ts, h, l in c.execute("select sym, src, domain, t_pub, t_seen, h, l from items where t_seen > ?", (NOW - 7 * 86400,)):
    d = (ts - tp) if tp and ts and 0 <= ts - tp < 7 * 86400 else None
    isgn = "news.google.com" in (l or "") or src == "GOOGLE NEWS"
    if isgn:
        gn.append((ts, sym, d, "confirmed" if sym in named(h) else "query only"))
    else:
        for s in ({sym} & FO) | named(h):
            pub.append((ts, s, d, "filing (news.db)" if src == "EXCHANGE" else "publisher RSS (macro.py)"))
for ln in open(V2 + "/data/ext/wires.jsonl"):
    try:
        r = json.loads(ln)
    except Exception:
        continue
    ts = ep(r.get("first_seen"))
    for s in (set(r.get("syms") or []) & FO) | named(r.get("title")):
        pub.append((ts, s, r.get("lag_s"), "publisher sitemap (v2 wires: %s)" % r.get("kind")))
for ln in open(V2 + "/data/filings_lag.jsonl"):
    try:
        r = json.loads(ln)
    except Exception:
        continue
    s = r.get("sym") or ""
    s = BSE.get(s.split(":", 1)[1]) if s.startswith("BSE:") else s
    if s in FO:
        pub.append((r.get("t"), s, r.get("lag_s"), "filing %s" % r.get("exch")))

W_START = min(ep(json.loads(l)["first_seen"]) for l in open(V2 + "/data/ext/wires.jsonl") if l.strip())
F_START = min(r[0] for r in pub if r[3].startswith("filing ") and r[0])


def cov(rows, t0, fam=None):
    S = {}
    for ts, s, d, f in rows:
        if ts and ts >= t0 and s in FO and (fam is None or fam(f)):
            S.setdefault(s, []).append(d)
    return S


def med(S):
    D = [d for v in S.values() for d in v if isinstance(d, (int, float)) and d >= 0]
    return (round(statistics.median(D) / 60, 1), len(D)) if D else (None, 0)


def fmt(t):
    return dt.datetime.fromtimestamp(t, IST).strftime("%d %b %H:%M IST")


L = ["# NEWS GNEWS SWAP - per-share coverage before / after (DESK_REVIEW 21 Nov 22:05 item 4)", "",
     "Made %s by GIR code (read only over news.db, v2/data/ext/wires.jsonl, v2/data/filings_lag.jsonl). Universe: the %d F&O names in "
     "v2/newsread/ref/aliases.json. A share counts as covered when at least one item in the window names it. 'confirmed' = the headline "
     "really names the company (the news reader's alias table + ambiguous-name rules, server/news_gate.names_in); Google News per-share "
     "queries also return lines that only matched the query (e.g. 'Attack on Titan' for TITAN)." % (fmt(NOW), len(FO)), ""]
for label, t0 in (("7 days (news.db only goes back 7 days for Google News; filings from %s; v2 sitemaps from %s)" % (fmt(F_START), fmt(W_START)), NOW - 7 * 86400),
                  ("common window since the v2 publisher sitemaps started (%s, %.0f h)" % (fmt(W_START), (NOW - W_START) / 3600), W_START)):
    g_all, g_conf = cov(gn, t0), cov(gn, t0, lambda f: f == "confirmed")
    p_all = cov(pub, t0)
    p_pubs = cov(pub, t0, lambda f: f.startswith("publisher"))
    p_fil = cov(pub, t0, lambda f: f.startswith("filing"))
    lost = sorted(set(g_conf) - set(p_all))
    gained = sorted(set(p_all) - set(g_all))
    L += ["## Window: " + label, "",
          "| path | shares covered (of %d) | items | median delay min (n) |" % len(FO), "|---|---|---|---|",
          "| BEFORE: Google News per-share queries (any line) | %d | %d | %s (%d) |" % ((len(g_all), sum(map(len, g_all.values()))) + med(g_all)),
          "| BEFORE: Google News, headline confirms the company | %d | %d | %s (%d) |" % ((len(g_conf), sum(map(len, g_conf.values()))) + med(g_conf)),
          "| AFTER: publisher feeds only (RSS + sitemaps) | %d | %d | %s (%d) |" % ((len(p_pubs), sum(map(len, p_pubs.values()))) + med(p_pubs)),
          "| AFTER: NSE / BSE filings only | %d | %d | %s (%d) |" % ((len(p_fil), sum(map(len, p_fil.values()))) + med(p_fil)),
          "| AFTER: publisher feeds + filings | %d | %d | %s (%d) |" % ((len(p_all), sum(map(len, p_all.values()))) + med(p_all)), "",
          "Delay = seen by GIR minus the source's own publish / exchange time (Google News: t_seen - t_pub in news.db; sitemaps: lag_s; "
          "filings: lag_s; macro.py RSS: t_seen - t_pub).", "",
          "Shares with a CONFIRMED Google News item but NO publisher / filing item in this window (lose all coverage): **%d**" % len(lost), "",
          (", ".join(lost) or "none"), "",
          "Shares covered AFTER that Google News never had: %d%s" % (len(gained), (" - " + ", ".join(gained)) if gained else ""), ""]
    if t0 == NOW - 7 * 86400:
        none_at_all = sorted(FO - set(g_all) - set(p_all))
        L += ["No item from either path in 7 days: %d%s" % (len(none_at_all), (" - " + ", ".join(none_at_all)) if none_at_all else ""), ""]
fam = {}
for ts, s, d, f in pub:
    if ts and ts >= NOW - 7 * 86400:
        fam.setdefault(f.split(" (")[0] if f.startswith("filing") else f, set()).add(s)
L += ["## AFTER, shares per source family (7 days)", "", "| source | shares |", "|---|---|"] + \
     ["| %s | %d |" % (k, len(v)) for k, v in sorted(fam.items(), key=lambda kv: -len(kv[1]))] + [""]
print("\n".join(L))
