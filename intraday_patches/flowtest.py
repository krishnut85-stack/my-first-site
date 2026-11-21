#!/usr/bin/env python3
"""flowtest.py - READ ONLY. CAN WE SEE THE MONEY BEFORE THE MOVE? (Rama, 16 Nov: "institutions cannot move in a single day - they need time to
invest and pull out. There has to be information where we can find which sector is building and which is losing, maybe a few days before."
And on whydesk: "You just read the news. That's it." - right: a reason after the move is not an edge.)
The one footprint big money cannot hide is DELIVERY - the shares actually taken home, in NSE's file every evening. This tests, on every day GIR
has stored (data/extra.db) against Kite's daily prices, whether that footprint comes BEFORE the price:
  A) SECTORS    a sector's shares taken home over the last 5 days against the 20 days before, compared with the whole market the same days
                ("building"), split by what its price did in those 5 days: QUIET (price flat) · WITH A RISE · ON A FALL · and DRYING UP.
                Then: the sector over the next 1 / 3 / 5 / 10 days against the market, entered at the NEXT MORNING'S OPEN (the file comes in the
                evening - nobody can buy at that day's close).
  B) F&O SHARES the same for each F&O share, and the ONE-DAY SPIKE (taken home 3x its normal, with a much higher delivery %), by the day's direction
  C) WHO        FII stock-futures positions (NSE's participant file): after FIIs add / cut over 5 days, what does the market do next?
  D) TODAY      the sectors and F&O shares standing in each state tonight - with what the test says that state has been worth
Every state is measured against the yardstick (every case of that table) and in the first and second half of the history separately: an edge
that is there in only one half is luck. For shares, "price alone, no building" is shown too - so delivery is not credited for what the price did.
Shares taken home = Kite's day volume x NSE's delivery % (so splits and bonuses do not look like buying). Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 flowtest.py [trading days=500]  -> prints, saves data/flowtest.txt
If the stored NSE files do not reach that far back, the missing days are fetched first (once; about a second a day)."""
import os, re, sys, time, sqlite3, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
CACHE = os.path.join(D, "data", "secdaily")
L = []
HZ = (1, 3, 5, 10)
pc = lambda v: "  n/a " if v is None or np.isnan(v) else "%+.2f%%" % (100 * v)


def say(s=""):
    L.append(s); print(s, flush=True)


def daily(kite, syms, ndays):
    """{sym: array [day ordinal, open, high, low, close, volume]} - the files sectortime.py keeps in data/secdaily (not older than 4 days),
    the rest fetched from Kite the same way (kite: a function that gives the Kite connection - asked only when something is missing)"""
    out = {}; best = {}
    if os.path.isdir(CACHE):
        for f in os.listdir(CACHE):
            m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)_(\d+)\.npy$", f)
            if m and int(m.group(3)) >= ndays and time.time() - os.path.getmtime(os.path.join(CACHE, f)) < 4 * 86400:
                k = (m.group(2), int(m.group(3)))
                if m.group(1) not in best or k > best[m.group(1)][0]:
                    best[m.group(1)] = (k, f)
    miss = []
    for s in sorted(set(syms)):
        b = best.get(re.sub(r"[^A-Z0-9]", "_", s))
        if b:
            out[s] = np.load(os.path.join(CACHE, b[1]))
        else:
            miss.append(s)
    if miss:
        say("  prices: %d shares on disk, fetching %d from Kite (about %d minutes) ..." % (len(out), len(miss), len(miss) * 0.4 / 60 + 1))
        import sectortime
        out.update(sectortime.fetch(kite(), miss, ndays))
    return out


def stored(first):
    """how many days of each NSE file data/extra.db holds from `first` on"""
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=10)
        r = {t: c.execute("select count(distinct d), min(d), max(d) from %s where d>=?" % t, (str(first),)).fetchone() for t in ("deliv", "part")}
        c.close(); return r
    except Exception:
        return {"deliv": (0, None, None), "part": (0, None, None)}


def backfill(first, today, want):
    st = stored(first)
    if st["deliv"][0] >= 0.93 * want and st["part"][0] >= 0.93 * want:
        return
    say("  NSE's delivery / participant files: %d / %d days stored of about %d wanted - fetching the missing days (resumes if stopped) ..." % (st["deliv"][0], st["part"][0], want))
    try:
        import nsextra
        c = nsextra.db(); c.execute("delete from fetched where d=? and status='none'", (str(today),)); c.commit(); c.close()
        try:
            n = nsextra.fetch_extra(first, today, quiet=False, sources=("deliv", "part"))
        except TypeError:
            n = nsextra.fetch_extra(first, today, quiet=False)
        say("  %d files stored" % n)
    except Exception as ex:
        say("  could not fetch (%s) - the test runs on what is stored" % str(ex)[:90])


def rollmean(X, a, b):
    """mean of X over rows i-a .. i-b (a >= b >= 0), ignoring gaps; a row needs at least 60% of the window"""
    V = ~np.isnan(X); Z = np.where(V, X, 0.0)
    cs = np.vstack([np.zeros((1, X.shape[1])), np.cumsum(Z, 0)]); cn = np.vstack([np.zeros((1, X.shape[1])), np.cumsum(V, 0)])
    n = X.shape[0]; out = np.full(X.shape, np.nan); w = a - b + 1
    for i in range(a, n):
        s = cs[i - b + 1] - cs[i - a]; k = cn[i - b + 1] - cn[i - a]
        out[i] = np.where(k >= 0.6 * w, s / np.maximum(k, 1), np.nan)
    return out


def fwd(first, rest, h):
    """the next h days entered at the next morning's open: day i+1 open->close (`first`), then close->close (`rest`) for i+2 .. i+h"""
    n = first.shape[0]; out = np.full(first.shape, np.nan)
    for i in range(n - h):
        out[i] = first[i + 1] + (rest[i + 2:i + h + 1].sum(0) if h > 1 else 0)
    return out


def line(name, mask, F, half, base=None):
    """one row: cases, days, the average and the % of cases above zero for each horizon, then the 5-day EDGE (against `base` - every case of
    the same table on the same footing) in each half of the history; -> (5-day edge, verdict)"""
    k = int(mask.sum()); h2 = half[:, None] if mask.ndim == 2 else half
    if k < 30:
        say("    %-34s %5d cases - too few to say" % (name, k)); return None, "too few cases"
    cells = []
    for h in HZ:
        x = F[h][mask]; x = x[~np.isnan(x)]
        cells.append("%s %3.0f%%" % (pc(x.mean()), 100 * (x > 0).mean()) if len(x) else "    n/a    ")
    days = int(mask.any(1).sum()) if mask.ndim == 2 else k
    if base is None:
        say("    %-34s %5d cases %4d days │ %s │ (the yardstick)" % (name, k, days, " │ ".join(cells))); return None, ""
    x5 = F[5]

    def edge(sel):
        a, b = x5[mask & sel], x5[base & sel]; a, b = a[~np.isnan(a)], b[~np.isnan(b)]
        return (a.mean() - b.mean()) if len(a) >= 15 and len(b) >= 15 else np.nan
    e, ea, eb = edge(np.ones_like(h2, bool)), edge(h2), edge(~h2)
    v = "✔ both halves" if not np.isnan(ea) and not np.isnan(eb) and ea * eb > 0 and min(abs(ea), abs(eb)) >= 0.002 and abs(e) >= 0.003 else "✘ no steady edge"
    say("    %-34s %5d cases %4d days │ %s │ 5d edge %s (halves %s / %s) %s" % (name, k, days, " │ ".join(cells), pc(e), pc(ea), pc(eb), v))
    return e, v


def head(what):
    say("    %-34s %-21s │ %s │" % (what, "", " │ ".join("%2dd avg   up " % h for h in HZ)))


def main():
    import seclive as SL
    ndays = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 500
    today = SL.now().date(); first = today - dt.timedelta(days=int(ndays * 1.47) + 45)
    say("📊 THE MONEY BEFORE THE MOVE · delivery (shares taken home) and FII positions against the next days' prices · about %d trading days" % ndays)
    backfill(first, today, ndays + 25)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights()
    try:
        RAW = daily(SL.get_kite, list(SEC), ndays)
    except Exception as ex:
        say("  ❌ prices: %s" % ex); return
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W)); sj = {s: j for j, s in enumerate(syms)}
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]})[-(ndays + 30):]
    di = {d: i for i, d in enumerate(days)}; n, m = len(days), len(syms)
    O = np.full((n, m), np.nan); Cl = O.copy(); V = O.copy(); DP = O.copy(); NQ = O.copy()
    for j, s in enumerate(syms):
        for r in RAW[s]:
            i = di.get(int(r[0]))
            if i is not None:
                O[i, j], Cl[i, j], V[i, j] = r[1], r[4], r[5]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=20)
        for d, s, q, dp in c.execute("select d, sym, qty, dp from deliv where d>=?", (str(dt.date.fromordinal(days[0])),)):
            j = sj.get(s); i = di.get(dt.date.fromisoformat(d).toordinal())
            if j is not None and i is not None and dp is not None:
                DP[i, j] = dp; NQ[i, j] = q or np.nan
        PART = {}
        for d, who, fil, fis, fsl, fss in c.execute("select d, who, fi_l, fi_s, fs_l, fs_s from part where d>=?", (str(dt.date.fromordinal(days[0])),)):
            if str(who).upper() == "FII" and None not in (fil, fis, fsl, fss):
                PART[dt.date.fromisoformat(d).toordinal()] = (fil, fis, fsl, fss)
        c.close()
    except Exception as ex:
        say("  ❌ data/extra.db: %s" % str(ex)[:100]); return
    have = ~np.isnan(DP).all(1)
    if have.sum() < 60:
        say("  ❌ only %d days of delivery data - not enough to test" % have.sum()); return
    i0 = int(np.argmax(have)); sl = slice(i0, n); days = days[i0:]; O, Cl, V, DP, NQ = O[sl], Cl[sl], V[sl], DP[sl], NQ[sl]; n = len(days)
    DP[(DP < 0) | (DP > 100)] = np.nan
    DQ = V * DP / 100.0                                   # shares taken home, on Kite's split-adjusted volume
    rq = NQ / np.where(V > 0, V, np.nan); adj = int((((rq < 0.7) | (rq > 1.4)).sum(0) >= 10).sum())
    pcl = np.vstack([np.full((1, m), np.nan), Cl[:-1]])
    cc = Cl / pcl - 1; intr = Cl / O - 1; bad = np.isnan(cc) | (np.abs(cc) > 0.25); cc[bad] = np.nan; intr[bad | (np.abs(intr) > 0.25)] = np.nan
    Wv = np.array([W.get(s) or 1.0 for s in syms])
    half = np.arange(n) < n // 2
    say("  %d shares (%d F&O) · %d days with NSE's delivery file (%s to %s) · sizes: %s" % (m, sum(1 for s in syms if s in FO), int(have.sum()), dt.date.fromordinal(days[0]), dt.date.fromordinal(days[-1]), wsrc))
    say("  (%d shares where NSE's quantity and Kite's volume differ over the period - splits / bonuses; Kite's adjusted volume is used)" % adj)
    say("  how to read: 'avg' = the average result over the next days, entered at the next morning's open · 'up' = how often it was above zero")
    say("  'edge' = the 5-day result against the yardstick row (every case of that table) · ✔ = the edge has the same sign in both halves of the\n  history and is at least 0.3% · ✘ = it is not steady - treat as no edge")

    def wm(X, idx):
        x = X[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x); s = w.sum(1); s[s == 0] = np.nan
        return np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / s
    allj = np.arange(m)
    M_cc, M_in = np.nan_to_num(wm(cc, allj)), np.nan_to_num(wm(intr, allj))
    m5, m20 = rollmean(DQ, 4, 0), rollmean(DQ, 24, 5)
    P = np.nan_to_num(Cl)
    ok = ~np.isnan(m5) & ~np.isnan(m20) & (m20 > 0) & (P > 0)

    def build(idx):
        o = ok[:, idx]; num = (np.where(o, m5[:, idx], 0) * P[:, idx]).sum(1); den = (np.where(o, m20[:, idx], 0) * P[:, idx]).sum(1)
        return np.where(den > 0, num / np.where(den > 0, den, 1), np.nan)
    b_all = build(allj)
    secs = sorted({SEC[s] for s in syms}); sidx = {k: np.array([j for j, s in enumerate(syms) if SEC[s] == k]) for k in secs}
    secs = [k for k in secs if len(sidx[k]) >= 5]
    B = np.column_stack([build(sidx[k]) for k in secs]) / b_all[:, None]
    R = np.column_stack([wm(cc, sidx[k]) for k in secs]) - M_cc[:, None]; IN = np.column_stack([wm(intr, sidx[k]) for k in secs]) - M_in[:, None]
    R, IN = np.nan_to_num(R), np.nan_to_num(IN)
    P5 = np.full(R.shape, np.nan)
    for i in range(5, n):
        P5[i] = R[i - 4:i + 1].sum(0)
    F = {h: fwd(IN, R, h) for h in HZ}
    say("")
    say("A) SECTORS - taken home in the last 5 days against the 20 before, compared with the whole market · then the sector AGAINST THE MARKET")
    head("state on the evening")
    hi, lo = B >= 1.3, B <= 0.75; allA = ~np.isnan(B) & ~np.isnan(P5)
    VA = {}
    line("every sector, every day", allA, F, half)
    VA["quiet"] = line("BUILDING, price flat (quiet)", hi & (np.abs(P5) < 0.015), F, half, allA)
    VA["rise"] = line("BUILDING with a rise (+1.5%)", hi & (P5 >= 0.015), F, half, allA)
    VA["fall"] = line("BUILDING on a fall (-1.5%)", hi & (P5 <= -0.015), F, half, allA)
    VA["dry"] = line("DRYING UP (0.75x or less)", lo & allA, F, half, allA)
    say("    each evening, the 3 sectors with the most building against the 3 with the least:")
    rk = np.argsort(np.argsort(-np.where(np.isnan(B), -9, B), 1), 1); valid = ~np.isnan(B)
    line("  the 3 most building", (rk < 3) & valid, F, half, allA)
    line("  the 3 least", (rk >= valid.sum(1)[:, None] - 3) & valid, F, half, allA)

    say("")
    say("B) F&O SHARES - the same for each F&O share · the share's own move (not against the market: an option buyer needs the share to move)")
    fj = np.array([j for j, s in enumerate(syms) if s in FO])
    if len(fj) < 20:
        say("    too few F&O shares in the data")
        VB = {}
    else:
        bs = np.where(ok[:, fj], m5[:, fj] / np.where(ok[:, fj], m20[:, fj], 1), np.nan) / b_all[:, None]
        c_f, i_f = np.nan_to_num(cc[:, fj]), np.nan_to_num(intr[:, fj])
        p5 = np.full(c_f.shape, np.nan)
        for i in range(5, n):
            p5[i] = c_f[i - 4:i + 1].sum(0) - M_cc[i - 4:i + 1].sum()
        Fs = {h: fwd(i_f, c_f, h) for h in HZ}
        head("state on the evening"); VB = {}
        hi_s = (bs >= 1.5) & (bs < 6); allB = ~np.isnan(bs) & ~np.isnan(p5)
        line("every F&O share, every day", allB, Fs, half)
        VB["quiet"] = line("BUILDING 1.5x, price flat", hi_s & (np.abs(p5) < 0.02), Fs, half, allB)
        VB["rise"] = line("BUILDING 1.5x with a rise (+3%)", hi_s & (p5 >= 0.03), Fs, half, allB)
        VB["fall"] = line("BUILDING 1.5x on a fall (-3%)", hi_s & (p5 <= -0.03), Fs, half, allB)
        say("    for comparison - price alone, no building (is it the delivery, or just the price move?):")
        lo_s = (bs < 1.2)
        line("  no building, with a rise (+3%)", lo_s & (p5 >= 0.03), Fs, half, allB)
        line("  no building, on a fall (-3%)", lo_s & (p5 <= -0.03), Fs, half, allB)
        say("    ONE-DAY SPIKE - taken home 3x its 20-day normal, delivery % at least 10 points above its normal:")
        d20, dp20 = rollmean(DQ, 20, 1)[:, fj], rollmean(DP, 20, 1)[:, fj]
        sp = (DQ[:, fj] >= 3 * d20) & (DP[:, fj] >= dp20 + 10) & (d20 > 0)
        VB["sp_up"] = line("  spike on an up day (+1%)", sp & (cc[:, fj] >= 0.01), Fs, half, allB)
        VB["sp_dn"] = line("  spike on a down day (-1%)", sp & (cc[:, fj] <= -0.01), Fs, half, allB)
        VB["sp_fl"] = line("  spike on a flat day", sp & (np.abs(cc[:, fj]) < 0.01), Fs, half, allB)

    say("")
    say("C) WHO - FII stock futures (NSE's participant file): after FIIs add or cut over 5 days, the whole market over the next days")
    pd_ = [d for d in days if d in PART]
    if len(pd_) < 80:
        say("    only %d days of the participant file - too few to say" % len(pd_))
    else:
        net = np.full(n, np.nan); tot = np.full(n, np.nan); ils = np.full(n, np.nan)
        for i, d in enumerate(days):
            if d in PART:
                fil, fis, fsl, fss = PART[d]; net[i] = fsl - fss; tot[i] = fsl + fss; ils[i] = fil / (fil + fis) if fil + fis else np.nan
        ch = np.full(n, np.nan); ch[5:] = (net[5:] - net[:-5]) / tot[5:]
        FM = {h: fwd(M_in[:, None], M_cc[:, None], h)[:, 0] for h in HZ}
        head("FIIs over the last 5 days")
        v = ch[~np.isnan(ch)]; q1, q4 = np.quantile(v, 0.2), np.quantile(v, 0.8)
        allC = ~np.isnan(ch) & ~np.isnan(ils)
        line("every day", allC, FM, half)
        line("ADDED the most (top fifth)", (ch >= q4) & allC, FM, half, allC)
        line("CUT the most (bottom fifth)", (ch <= q1) & allC, FM, half, allC)
        v = ils[~np.isnan(ils)]; t1, t2 = np.quantile(v, 0.2), np.quantile(v, 0.8)
        line("index fut. very short (≤%d%% long)" % round(100 * t1), (ils <= t1) & allC, FM, half, allC)
        line("index fut. very long (≥%d%% long)" % round(100 * t2), (ils >= t2) & allC, FM, half, allC)

    say("")
    last = n - 1
    say("D) TONIGHT (%s) - where each sector stands · what the test above says that state has been worth over 5 days" % dt.date.fromordinal(days[last]).strftime("%d %b"))
    vt = lambda key, tab: "5d edge %s, %s" % (pc(tab[key][0]), tab[key][1]) if tab.get(key) and tab[key][0] is not None else "too few cases to say"
    for k in np.argsort(-np.where(np.isnan(B[last]), -9, B[last])):
        b, p = B[last, k], P5[last, k]
        if np.isnan(b):
            continue
        st = ("quiet", "BUILDING, price flat") if b >= 1.3 and abs(p) < 0.015 else ("rise", "BUILDING with a rise") if b >= 1.3 and p >= 0.015 else ("fall", "BUILDING on a fall") if b >= 1.3 else ("dry", "DRYING UP") if b <= 0.75 else (None, "")
        say("    %-26s taken home %.2fx the market's pace · its price over 5 days %s against the market%s" % (secs[k], b, pc(p), ("  → %s (tested: %s)" % (st[1], vt(st[0], VA))) if st[0] else ""))
    if len(fj) >= 20:
        say("    F&O shares building the most tonight (1.5x or more):")
        for key, name, cond in (("quiet", "price flat", lambda b, p: abs(p) < 0.02), ("rise", "with a rise", lambda b, p: p >= 0.03), ("fall", "on a fall", lambda b, p: p <= -0.03)):
            it = sorted(((bs[last, x], syms[fj[x]], p5[last, x]) for x in range(len(fj)) if not np.isnan(bs[last, x]) and 1.5 <= bs[last, x] < 6 and not np.isnan(p5[last, x]) and cond(bs[last, x], p5[last, x])), reverse=True)[:12]
            say("      %-12s (tested: %s): %s" % (name, vt(key, VB), " · ".join("%s %.1fx %s" % (s, b, pc(p)) for b, s, p in it) or "none"))
    say("")
    say("  A state marked ✘ is NOT a reason to trade - it is listed so you can see the test, not follow it.")
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", "flowtest.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/flowtest.txt")


if __name__ == "__main__":
    main()
