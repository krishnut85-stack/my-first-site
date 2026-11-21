#!/usr/bin/env python3
"""sectortime.py - READ ONLY. WHEN DOES A SECTOR MOVE, AND DOES IT KEEP MOVING OVER DAYS? (Rama, 16 Nov: "the sector does not move on its own -
someone is pushing and pulling every day; 90% of its shares move together; every day a different sector. We are missing something.")
The thought to test: institutions trade a sector as one basket, on information that arrives overnight, and they build over several days - so the
move may be (1) mostly in the gap between yesterday's close and today's open, and (2) a trend across days, not inside one morning.
Kite's DAILY candles for every share of NSE's Nifty Total Market (~750) for about two years, in NSE's sectors (seclive.py), weighted by size:
  1) WHEN       each sector's daily move split into OVERNIGHT (yesterday's close -> today's open) and DAYTIME (open -> close). On the day a sector is
                the day's best / worst: how much of that was already there at the open? After a big gap, does the day go on or come back?
  2) THE TREND  the 3 strongest / weakest sectors of the last 1 / 3 / 5 / 10 / 20 days: over the next 1 / 3 / 5 days, better or worse than the
                average sector? And is the next day's part overnight or daytime?
  3) THE CLOSE  a sector (and an F&O share) that closes strong - up, near its high, on volume: the next morning's gap and the next day
  4) THE THEMES the same trend test on the 41 tight themes (themestudy.py), F&O shares only
% = the size-weighted move. "edge" = against the average sector over the same days. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 sectortime.py [trading days=500]   -> prints, saves data/sectortime.txt
The first run fetches ~750 shares (one request each, about 6 minutes) and keeps them in data/secdaily/."""
import os, re, sys, time, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
CACHE = os.path.join(D, "data", "secdaily")
L = []


def say(s=""):
    L.append(s); print(s, flush=True)


def fetch(kite, syms, ndays):
    """{sym: array [day ordinal, open, high, low, close, volume]} - Kite day candles (adjusted for splits and bonuses), kept on disk"""
    import getdata, seclive as SL
    os.makedirs(CACHE, exist_ok=True)
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    today = dt.datetime.now(SL.IST).date(); frm = dt.datetime.combine(today - dt.timedelta(days=int(ndays * 1.5) + 10), dt.time(9, 15)); to = dt.datetime.combine(today, dt.time(15, 30))
    out = {}; got = fails = 0
    for s in sorted(set(syms)):
        f = os.path.join(CACHE, "%s_%s_%d.npy" % (re.sub(r"[^A-Z0-9]", "_", s), today, ndays))
        if os.path.exists(f):
            out[s] = np.load(f); continue
        if s not in tok:
            continue
        try:
            rows = kite.historical_data(tok[s], frm, to, "day"); time.sleep(0.36)
        except Exception as ex:
            fails += 1; print("  %s: %s" % (s, str(ex)[:60]), flush=True)
            if fails >= 25 and not got:
                raise RuntimeError("Kite refused the first 25 shares (%s)" % str(ex)[:80])
            continue
        a = np.array([[r["date"].date().toordinal(), r["open"], r["high"], r["low"], r["close"], r["volume"]] for r in rows if r["close"]], dtype=np.float64)
        if len(a) > 30:
            np.save(f, a); out[s] = a; got += 1
            if got % 150 == 0:
                print("  fetched %d ..." % got, flush=True)
    return out


def wmean(X, Wv, idx):
    """size-weighted mean of X[:, idx] over the shares that have a value -> one number a day"""
    x = X[:, idx]; w = np.broadcast_to(Wv[idx], x.shape) * ~np.isnan(x)
    s = w.sum(1); s[s == 0] = np.nan
    return np.nansum(np.where(np.isnan(x), 0, x) * w, 1) / s


def pc(v):
    return "%+.2f%%" % (100 * v)


def trend_table(R, OV, IN, names, title, top=3):
    """R: [day, group] close-to-close. The strongest / weakest groups of the last Lb days against the average group over the next H days."""
    say("  %s" % title)
    n, k = R.shape; top = min(top, max(1, k // 4))
    cum = np.cumsum(np.log1p(np.nan_to_num(R)), 0)
    for Lb in (1, 3, 5, 10, 20):
        for H in (1, 3, 5):
            a, b = [], []
            for t in range(Lb, n - H):
                past = cum[t] - cum[t - Lb]; fwd = np.expm1(cum[t + H] - cum[t])
                o = np.argsort(-past); avg = fwd.mean()
                a.append(fwd[o[:top]].mean() - avg); b.append(fwd[o[-top:]].mean() - avg)
            a, b = np.array(a), np.array(b)
            say("    last %2d days → next %d: strongest %s (ahead %2.0f%% of days) · weakest %s (ahead %2.0f%%) · gap between them %s" % (
                Lb, H, pc(a.mean()), 100 * (a > 0).mean(), pc(b.mean()), 100 * (b > 0).mean(), pc(a.mean() - b.mean())))
    if OV is not None:
        for Lb in (1, 5):
            a, b, c, d_ = [], [], [], []
            for t in range(Lb, n - 1):
                past = cum[t] - cum[t - Lb]; o = np.argsort(-past)
                a.append(OV[t + 1, o[:top]].mean() - np.nanmean(OV[t + 1])); b.append(IN[t + 1, o[:top]].mean() - np.nanmean(IN[t + 1]))
                c.append(OV[t + 1, o[-top:]].mean() - np.nanmean(OV[t + 1])); d_.append(IN[t + 1, o[-top:]].mean() - np.nanmean(IN[t + 1]))
            say("    the strongest of the last %d day(s), the NEXT day: overnight %s · daytime %s    the weakest: overnight %s · daytime %s" % (
                Lb, pc(np.nanmean(a)), pc(np.nanmean(b)), pc(np.nanmean(c)), pc(np.nanmean(d_))))


def main():
    import seclive as SL
    ndays = int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 500
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights(); kite = SL.get_kite()
    say("📊 WHEN A SECTOR MOVES · overnight or daytime · does it trend over days · Kite daily prices, about %d trading days" % ndays)
    try:
        RAW = fetch(kite, list(SEC), ndays)
    except Exception as ex:
        say("  ❌ %s" % ex); return
    syms = sorted(s for s in RAW if s in SEC and (W.get(s) or not W))
    days = sorted({int(x) for s in syms for x in RAW[s][:, 0]})[-(ndays + 1):]
    di = {d: i for i, d in enumerate(days)}; n, m = len(days), len(syms)
    O = np.full((n, m), np.nan); H = O.copy(); Lo = O.copy(); Cl = O.copy(); V = O.copy()
    for j, s in enumerate(syms):
        for r in RAW[s]:
            i = di.get(int(r[0]))
            if i is not None:
                O[i, j], H[i, j], Lo[i, j], Cl[i, j], V[i, j] = r[1], r[2], r[3], r[4], r[5]
    Wv = np.array([W.get(s) or 1.0 for s in syms])
    pcl = np.vstack([np.full((1, m), np.nan), Cl[:-1]])
    cc = Cl / pcl - 1; ov = O / pcl - 1; intr = Cl / O - 1
    bad = np.isnan(cc) | (np.abs(cc) > 0.25) | (np.abs(ov) > 0.25)
    cc[bad] = np.nan; ov[bad] = np.nan; intr[bad] = np.nan
    pos = (Cl - Lo) / np.where(H > Lo, H - Lo, np.nan); pos[bad] = np.nan
    secs = sorted({SEC[s] for s in syms}); sidx = {k: np.array([j for j, s in enumerate(syms) if SEC[s] == k]) for k in secs}
    secs = [k for k in secs if len(sidx[k]) >= 5]
    R = np.column_stack([wmean(cc, Wv, sidx[k]) for k in secs])[1:]; OV = np.column_stack([wmean(ov, Wv, sidx[k]) for k in secs])[1:]
    IN = np.column_stack([wmean(intr, Wv, sidx[k]) for k in secs])[1:]; PS = np.column_stack([wmean(pos, Wv, sidx[k]) for k in secs])[1:]
    ok = ~np.isnan(R).any(1); R, OV, IN, PS = R[ok], OV[ok], IN[ok], PS[ok]; nd = len(R)
    say("  %d shares · %d sectors · %d days (%s to %s) · weights: %s" % (m, len(secs), nd, dt.date.fromordinal(days[1]), dt.date.fromordinal(days[-1]), wsrc))
    say("")
    say("1) WHEN - a sector's day split into OVERNIGHT (yesterday's close → today's open) and DAYTIME (open → close)")
    aov, ain = np.abs(OV).mean(0), np.abs(IN).mean(0)
    say("    all sectors together: a normal overnight move %.2f%% · a normal daytime move %.2f%% → %2.0f%% of the movement happens overnight" % (100 * aov.mean(), 100 * ain.mean(), 100 * aov.mean() / (aov.mean() + ain.mean())))
    for k in np.argsort(-aov / (aov + ain)):
        say("      %-26s overnight %.2f%% · daytime %.2f%% · %2.0f%% overnight" % (secs[k], 100 * aov[k], 100 * ain[k], 100 * aov[k] / (aov[k] + ain[k])))
    b = R.argmax(1); w_ = R.argmin(1); ix = np.arange(nd)
    say("    on the day a sector is the day's BEST: its day %s = overnight %s + daytime %s → %2.0f%% of it was already there at the open" % (
        pc(R[ix, b].mean()), pc(OV[ix, b].mean()), pc(IN[ix, b].mean()), 100 * OV[ix, b].mean() / R[ix, b].mean()))
    say("    on the day a sector is the day's WORST: its day %s = overnight %s + daytime %s → %2.0f%% of it was already there at the open" % (
        pc(R[ix, w_].mean()), pc(OV[ix, w_].mean()), pc(IN[ix, w_].mean()), 100 * OV[ix, w_].mean() / R[ix, w_].mean()))
    g = OV.argmax(1); gd = OV.argmin(1)
    say("    the sector with the biggest GAP UP at the open (%s on average): the rest of its day %s · it went on up on %2.0f%% of days" % (pc(OV[ix, g].mean()), pc(IN[ix, g].mean()), 100 * (IN[ix, g] > 0).mean()))
    say("    the sector with the biggest GAP DOWN at the open (%s): the rest of its day %s · it went on down on %2.0f%% of days" % (pc(OV[ix, gd].mean()), pc(IN[ix, gd].mean()), 100 * (IN[ix, gd] < 0).mean()))
    big = np.abs(OV[ix, g]) >= 0.01
    if big.sum() >= 10:
        say("      when that gap up is 1%%+ (%d days): the rest of the day %s · went on up on %2.0f%%" % (big.sum(), pc(IN[ix, g][big].mean()), 100 * (IN[ix, g][big] > 0).mean()))
    big = np.abs(OV[ix, gd]) >= 0.01
    if big.sum() >= 10:
        say("      when that gap down is 1%%+ (%d days): the rest of the day %s · went on down on %2.0f%%" % (big.sum(), pc(IN[ix, gd][big].mean()), 100 * (IN[ix, gd][big] < 0).mean()))
    say("")
    say("2) THE TREND - the 3 strongest / 3 weakest sectors of the last days, against the average sector, over the next days")
    say("   (a + for the strongest and a - for the weakest = sectors TREND; the other way round = they come back)")
    trend_table(R, OV, IN, secs, "NSE sectors (%d), size-weighted" % len(secs))
    say("")
    say("3) THE CLOSE - a strong / weak close, and the next morning")
    for nm, cond in (("a sector up 1%+ and closing in the top 30% of its day's range", (R >= 0.01) & (PS >= 0.7)), ("a sector down 1%+ and closing in the bottom 30% of its range", (R <= -0.01) & (PS <= 0.3))):
        c = cond[:-1]; sgn = 1 if "up" in nm else -1
        if c.sum() >= 10:
            o1, i1, r1 = OV[1:][c], IN[1:][c], R[1:][c]
            say("    %-62s %4d times · next morning's gap %s (%2.0f%% that way) · next daytime %s · next day %s (the average sector that day %s)" % (
                nm, c.sum(), pc(o1.mean()), 100 * (o1 * sgn > 0).mean(), pc(i1.mean()), pc(r1.mean()), pc(np.broadcast_to(R[1:].mean(1)[:, None], R[1:].shape)[c].mean())))
    fo = np.array([j for j, s in enumerate(syms) if s in FO])
    if len(fo) >= 20:
        v20 = np.full(V.shape, np.nan)
        for i in range(20, n):
            v20[i] = np.nanmean(V[i - 20:i], 0)
        for nm, cond, sgn in (("an F&O share up 2%+, closing in the top 10% of its range, volume 1.5x", (cc >= 0.02) & (pos >= 0.9) & (V >= 1.5 * v20), 1),
                              ("an F&O share down 2%+, closing in the bottom 10% of its range, volume 1.5x", (cc <= -0.02) & (pos <= 0.1) & (V >= 1.5 * v20), -1),
                              ("an F&O share up 2%+ (any close)", (cc >= 0.02), 1), ("an F&O share down 2%+ (any close)", (cc <= -0.02), -1)):
            c = cond[:-1][:, fo]; o1, i1, r1 = ov[1:][:, fo][c], intr[1:][:, fo][c], cc[1:][:, fo][c]; keep = ~np.isnan(o1) & ~np.isnan(i1)
            if keep.sum() >= 30:
                o1, i1, r1 = o1[keep], i1[keep], r1[keep]
                say("    %-72s %5d times · next gap %s (%2.0f%% that way) · next daytime %s (%2.0f%% that way) · next day %s" % (
                    nm, keep.sum(), pc(o1.mean()), 100 * (o1 * sgn > 0).mean(), pc(i1.mean()), 100 * (i1 * sgn > 0).mean(), pc(r1.mean())))
    say("")
    try:
        import themestudy as TH
        tn, tr, to_, ti = [], [], [], []
        eq = np.ones(m)
        for t, (f_, also, why) in TH.THEMES.items():
            idx = np.array([j for j, s in enumerate(syms) if s in f_.split()])
            if len(idx) >= 3:
                tn.append(t); tr.append(wmean(cc, eq, idx)); to_.append(wmean(ov, eq, idx)); ti.append(wmean(intr, eq, idx))
        if len(tn) >= 8:
            TR = np.column_stack(tr)[1:]; TO = np.column_stack(to_)[1:]; TI = np.column_stack(ti)[1:]; okt = ~np.isnan(TR).any(1)
            say("4) THE THEMES - the same trend test on the tight themes (F&O shares, each one vote)")
            trend_table(TR[okt], TO[okt], TI[okt], tn, "%d themes" % len(tn), top=5)
    except Exception as ex:
        say("4) themes: %s" % str(ex)[:100])
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "sectortime.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/sectortime.txt")


if __name__ == "__main__":
    main()
