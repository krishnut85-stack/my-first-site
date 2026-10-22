#!/usr/bin/env python3
"""stats2.py - which intraday BUY strategies actually make money on this server's 5-minute history.

Every strategy is simulated the way the desk trades: enter on a 5-min close, stop below a level,
SIP-style trail (at +2R the stop moves to entry, then trails 2R below the high), +15% cap, exit 15:15.
Costs 0.10% round trip. News: NEWSHAWK headlines that name the company (overnight = after 15:30 the
previous day until 09:15). Read-only.

  python3 stats2.py            all shares        python3 stats2.py --max=400   faster
"""
import os, sys, time, sqlite3, datetime as dt
import numpy as np
import core, getdata

COST = 0.10
EXIT_BAR = 71           # 15:15 candle close
T0 = time.time()


def series(sym):
    a = core.load_npz(sym)
    if a is None:
        return None
    m = core.to_matrix(a)
    if m is None or len(m["days"]) < 30:
        return None
    return m


def sim(H, L, C, j, entry, stop, target=None, trail=True):
    """One trade entered at the close of bar j. Returns (R net, % net)."""
    risk = entry - stop
    if not (risk > 0 and np.isfinite(entry)):
        return None
    if risk / entry > 0.04 or risk / entry < 0.002:
        return None
    hi = entry
    st = stop
    ex = None
    for b in range(j + 1, EXIT_BAR + 1):
        lo_b, hi_b = L[b], H[b]
        if not np.isfinite(lo_b):
            continue
        if lo_b <= st:
            ex = st
            break
        if target is not None and hi_b >= target:
            ex = target
            break
        if hi_b >= entry * 1.15:
            ex = entry * 1.15
            break
        hi = max(hi, hi_b)
        if trail and hi >= entry + 2 * risk:
            st = max(st, entry, hi - 2 * risk)
    if ex is None:
        ex = C[EXIT_BAR]
        if not np.isfinite(ex):
            return None
    c = entry * COST / 100
    return (ex - entry - c) / risk, (ex - entry - c) / entry * 100


def load_news(uni):
    """{(sym, day_number): +1/-1} for headlines naming one or two companies."""
    try:
        import engine2
    except Exception as ex:
        print("news: engine2 import failed (%s) - news splits skipped" % ex)
        return {}, {}
    c = engine2.cfg2()
    nw = engine2.News(c, uni)
    if not os.path.exists(nw.path):
        print("news: ledger not found - news splits skipped")
        return {}, {}
    con = sqlite3.connect("file:%s?mode=ro" % nw.path, uri=True, timeout=5)
    nw._detect(con)
    t, lk, ts = nw.cols["text"], nw.cols["link"], nw.cols["ts"]
    rows = con.execute("select %s, %s, %s from live_news" % (t, lk or "''", ts or "0")).fetchall()
    con.close()
    over, intra = {}, {}
    seen = set()
    now = time.time()
    for text, link, when in rows:
        if not text:
            continue
        text = nw.clean(text)
        if text in seen:
            continue
        seen.add(text)
        tsec = nw._epoch(when, now)
        nm = nw.names(text)
        if not nm or len(nm) > 2:
            continue
        try:
            pts, side, fact = nw.classify(text, link, fetch=False)
        except TypeError:
            pts, side, fact = nw.classify(text, link)
        if not pts or not side:
            continue
        loc = tsec + core.IST_OFF
        day = int(loc // 86400)
        mins = int((loc % 86400) // 60)
        for s in nm:
            if mins >= 15 * 60 + 30:
                over[(s, day + 1)] = over.get((s, day + 1), 0) + side       # next calendar day; weekends handled below
            elif mins < 9 * 60 + 15:
                over[(s, day)] = over.get((s, day), 0) + side
            else:
                intra[(s, day)] = intra.get((s, day), 0) + side
    print("news: %d headlines read, %d overnight share-days, %d intraday share-days (%.0f s)" % (len(rows), len(over), len(intra), time.time() - T0))
    return over, intra


def main():
    mx = None
    for x in sys.argv[1:]:
        if x.startswith("--max="):
            mx = int(x[6:])
    uni = getdata.load_universe() or []
    syms = [e["sym"] for e in uni][:mx] if mx else [e["sym"] for e in uni]
    nif = series("NIFTY50")
    if nif is None:
        print("no NIFTY50 history")
        return
    ndays = [int(d) for d in nif["days"]]
    nday = {d: i for i, d in enumerate(ndays)}
    nprev = np.r_[np.nan, nif["C"][:-1, -1]]
    n_gap = (nif["O"][:, 0] / nprev - 1) * 100
    n_930 = (nif["C"][:, 2] / nif["O"][:, 0] - 1) * 100
    last5 = set(ndays[-5:])
    over, intra = load_news(uni)
    # weekend / holiday overnight news belongs to the next trading day
    nxt = {}
    for d in range(min(ndays) - 5, max(ndays) + 6):
        k = next((x for x in ndays if x >= d), None)
        nxt[d] = k
    over2 = {}
    for (s, d), v in over.items():
        k = nxt.get(d)
        if k is not None:
            over2[(s, k)] = over2.get((s, k), 0) + v
    over = over2

    res = {}

    def add(name, r, day, extra=()):
        if r is None:
            return
        for key in (name,) + tuple(name + " · " + e for e in extra):
            res.setdefault(key, []).append((r[0], r[1], day in last5))

    used = 0
    for s in syms:
        m = series(s)
        if m is None:
            continue
        O, H, L, C, V = m["O"], m["H"], m["L"], m["C"], m["V"]
        days = [int(d) for d in m["days"]]
        prev = np.r_[np.nan, C[:-1, -1]]
        gap = (O[:, 0] / prev - 1) * 100
        tp = (H + L + C) / 3.0
        v = np.nan_to_num(V)
        with np.errstate(invalid="ignore", divide="ignore"):
            vw = np.cumsum(tp * v, 1) / np.cumsum(v, 1)
        v0 = v[:, 0]
        barv = np.nanmean(v, 1)
        drng = np.nanmax(H, 1) - np.nanmin(L, 1)                       # daily range
        pdh = np.r_[np.nan, np.nanmax(H, 1)[:-1]]                       # previous day high
        # 20-period EMA on 5-min closes, per day (Raschke "Holy Grail" uses a 20 EMA pullback)
        ema = np.full(C.shape, np.nan)
        k20 = 2.0 / 21
        for dd in range(len(C)):
            e = np.nan
            for bb in range(C.shape[1]):
                x = C[dd, bb]
                if np.isfinite(x):
                    e = x if not np.isfinite(e) else e + k20 * (x - e)
                ema[dd, bb] = e
        for d in range(1, len(days)):
            day = days[d]
            ni = nday.get(day)
            if ni is None or not np.isfinite(prev[d]) or prev[d] <= 0:
                continue
            g = gap[d]
            onews = over.get((s, day), 0)
            pos_news = onews > 0
            neg_news = onews < 0
            med5 = np.median(v0[max(0, d - 20):d]) if d >= 5 else np.nan
            rvol5 = v0[d] / med5 if med5 and med5 > 0 else 0.0
            sip = rvol5 >= 2.0 and C[d, 0] > O[d, 0]
            ng, n9 = n_gap[ni], n_930[ni]
            nifty_tag = ("Nifty gap-up faded by 09:30" if (ng >= 0.5 and n9 < 0) else
                         "Nifty gap-up held" if (ng >= 0.5 and n9 >= 0) else
                         "Nifty gap-down" if ng <= -0.5 else "Nifty flat open")
            h, l, c_ = H[d], L[d], C[d]
            # S1 opening 5-min breakout, stocks in play
            if sip:
                rh, rl = h[0], l[0]
                for b in range(1, 13):
                    if h[b] > rh * 1.0005:
                        add("S1 09:20 breakout, stocks in play", sim(h, l, c_, b, max(rh * 1.0005, O[d, b]), rl), day,
                            ("WITH overnight +news" if pos_news else "no news", nifty_tag))
                        break
            # S2 gap-up with positive overnight news: buy the 09:20 close if the first candle is green
            if pos_news and g >= 1.0 and c_[0] > O[d, 0]:
                add("S2 +news gap-up, buy 09:20 close", sim(h, l, c_, 0, c_[0], l[0]), day,
                    ("gap ≥3%" if g >= 3 else "gap 1-3%", nifty_tag))
            # S3 gap-down reversal: first strong green candle before 10:15, stop day low, target prev close
            if g <= -2.0:
                for b in range(1, 13):
                    if c_[b] > O[d, b] and c_[b] > h[b - 1]:
                        lo = np.nanmin(l[:b + 1])
                        tag = ("gap ≤-4%" if g <= -4 else "gap -2..-4%")
                        nn = "with −news" if neg_news else "no −news"
                        add("S3 gap-down reversal → prev close", sim(h, l, c_, b, c_[b], lo, target=prev[d], trail=False), day, (tag, nn, nifty_tag))
                        add("S3b gap-down reversal → trail", sim(h, l, c_, b, c_[b], lo), day, (tag, nn))
                        break
            # S4 gap-down VWAP reclaim (before 11:00)
            if g <= -2.0:
                for b in range(2, 21):
                    if c_[b - 1] < vw[d, b - 1] and c_[b] > vw[d, b]:
                        lo = np.nanmin(l[:b + 1])
                        add("S4 gap-down VWAP reclaim", sim(h, l, c_, b, c_[b], lo, target=prev[d], trail=False), day,
                            ("with −news" if neg_news else "no −news",))
                        break
            # S5 late day-high breakout (11:00-14:00) on 2x bar volume
            for b in range(21, 58):
                dh = np.nanmax(h[:b])
                if h[b] > dh * 1.0005 and v[d, b] >= 2 * barv[d] and c_[b] > vw[d, b]:
                    lo3 = np.nanmin(l[b - 2:b + 1])
                    add("S5 late day-high break (11-14h, 2x vol)", sim(h, l, c_, b, c_[b], lo3), day, (nifty_tag,))
                    break
            # S6 pullback to VWAP in an uptrend (share ≥+1.5% and above VWAP at 10:30)
            if (c_[15] / prev[d] - 1) * 100 >= 1.5 and c_[15] > vw[d, 15]:
                for b in range(16, 52):
                    if l[b] <= vw[d, b] * 1.002 and c_[b] > vw[d, b] and c_[b] > O[d, b]:
                        add("S6 VWAP pullback in uptrend", sim(h, l, c_, b, c_[b], min(l[b], vw[d, b] * 0.995)), day, (nifty_tag,))
                        break
            # S7 intraday flush & bounce: down ≥3% from prev close (no big gap), first higher-low green candle 10:00-13:00
            if g > -1.5:
                for b in range(9, 46):
                    if (np.nanmin(l[:b + 1]) / prev[d] - 1) * 100 <= -3 and c_[b] > O[d, b] and l[b] > l[b - 1] and c_[b] > h[b - 1]:
                        add("S7 intraday flush & bounce", sim(h, l, c_, b, c_[b], np.nanmin(l[:b + 1]), target=None), day, (nifty_tag,))
                        break
            # S9 Toby Crabel: opening-range breakout only after a NARROW-RANGE day (NR7: smallest range of the last 7)
            if d >= 7 and np.isfinite(drng[d - 1]) and drng[d - 1] <= np.nanmin(drng[d - 7:d]):
                rh, rl = np.nanmax(h[:3]), np.nanmin(l[:3])            # 15-min range
                for b in range(3, 24):
                    if h[b] > rh * 1.0005:
                        add("S9 Crabel NR7 + 15-min range breakout", sim(h, l, c_, b, max(rh * 1.0005, O[d, b]), rl), day, (nifty_tag,))
                        break
            # S10 15-min opening range breakout, stocks in play (entry from 09:30)
            if sip:
                rh, rl = np.nanmax(h[:3]), np.nanmin(l[:3])
                for b in range(3, 24):
                    if h[b] > rh * 1.0005:
                        add("S10 15-min range breakout, stocks in play", sim(h, l, c_, b, max(rh * 1.0005, O[d, b]), rl), day,
                            ("WITH overnight +news" if pos_news else "no news",))
                        break
            # S11 gap-and-go: gap-up ≥2%, breaks the PREVIOUS DAY HIGH after 09:30 while above VWAP (Ross Cameron style)
            if g >= 2.0 and np.isfinite(pdh[d]) and O[d, 0] < pdh[d]:
                for b in range(3, 30):
                    if h[b] > pdh[d] * 1.0005 and c_[b] > vw[d, b]:
                        add("S11 gap-and-go: break prev-day high", sim(h, l, c_, b, c_[b], max(np.nanmin(l[b - 2:b + 1]), vw[d, b] * 0.995)), day,
                            ("WITH overnight +news" if pos_news else "no news",))
                        break
            # S12 opening drive + first pullback (Andrew Aziz "ABCD"): up ≥2% from open in the first 30 min,
            #     pulls back but holds above VWAP, buy the break of the pullback bar's high
            if np.nanmax(h[:6]) >= O[d, 0] * 1.02:
                top = int(np.nanargmax(h[:6]))
                for b in range(top + 2, 30):
                    if l[b - 1] > vw[d, b - 1] and h[b] > h[b - 1] and c_[b] > vw[d, b] and np.nanmax(h[top:b]) > h[b - 1]:
                        add("S12 opening drive → first pullback (ABCD)", sim(h, l, c_, b, max(h[b - 1] * 1.0005, O[d, b]), l[b - 1]), day,
                            ("WITH overnight +news" if pos_news else "no news",))
                        break
            # S13 Raschke Holy Grail on 5-min: strong up-move (≥+2% vs prev close, above rising 20-EMA), first pullback to the EMA,
            #     buy the break of that bar's high
            for b in range(12, 55):
                if (c_[b] / prev[d] - 1) * 100 >= 2 and ema[d, b] > ema[d, b - 6] and l[b] <= ema[d, b] * 1.001 and c_[b] > ema[d, b]:
                    if b + 1 <= 70 and h[b + 1] > h[b] * 1.0005:
                        add("S13 Raschke Holy Grail (20-EMA pullback)", sim(h, l, c_, b + 1, max(h[b] * 1.0005, O[d, b + 1]), l[b]), day, (nifty_tag,))
                    break
            # S8 positive INTRADAY news: buy the first 5-min close after the headline's bar is unknown here,
            #    so: share with +news during the session that is above VWAP at 12:00 -> buy 12:00 close
            if intra.get((s, day), 0) > 0 and c_[33] > vw[d, 33]:
                add("S8 +news intraday, above VWAP at 12:00", sim(h, l, c_, 33, c_[33], vw[d, 33] * 0.99), day)
        used += 1
        if used % 200 == 0:
            print("  %d shares · %.0f s" % (used, time.time() - T0))

    import datetime as _dt
    d0 = _dt.date.fromordinal(ndays[0] + 719163)
    d1 = _dt.date.fromordinal(ndays[-1] + 719163)
    out = ["STATS2 — %d shares · %s to %s (%d sessions) · costs %.2f%% · desk exits (stop, 2R trail, 15:15)" % (used, d0, d1, len(ndays), COST),
           "%-58s %6s %5s %7s %8s | last 5 sessions" % ("strategy", "trades", "win", "avg R", "avg %")]
    for k in sorted(res, key=lambda x: (x.split(" · ")[0], x)):
        a = np.array(res[k], dtype=float)
        n = len(a)
        if n < 15 and " · " in k:
            continue
        r, p, l5 = a[:, 0], a[:, 1], a[:, 2] > 0
        s5 = ("%3d tr %+.2fR" % (l5.sum(), r[l5].mean())) if l5.sum() else "  -"
        ind = "   " if " · " in k else ""
        out.append("%-58s %6d %4.0f%% %+6.2fR %+7.2f%% | %s" % ((ind + k.split(" · ", 1)[1]) if " · " in k else k, n, 100 * (r > 0).mean(), r.mean(), p.mean(), s5))
    txt = "\n".join(out)
    print("\n" + txt)
    open(os.path.join(core.BASE, "stats2.txt"), "w").write(txt + "\n")
    print("\nsaved stats2.txt · %.0f s" % (time.time() - T0))


if __name__ == "__main__":
    main()
