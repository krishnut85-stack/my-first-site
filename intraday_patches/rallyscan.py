#!/usr/bin/env python3
"""rallyscan.py - READ ONLY. The trader, 20 Nov: "NIFTY went from about 22,000 to 25,500. Which sectors pushed it from the bottom to the
top, and which F&O shares are now overbought / extremely overbought?" From the minute store (/root/hist or GIR_HIST):

  1 THE RALLY   NIFTY's lowest close in the last 365 days (or --from YYYY-MM-DD) to the last day in the store
  2 SECTORS     every sector's move over the rally (median of its F&O shares), breadth (how many members rose), its top 3 shares -
                ranked; the top 5 are "who pushed it" (no index weights in the store, so this is the sector's own move, not points)
  3 OVERBOUGHT  every F&O share with daily RSI(14) >= 70, EXTREMELY OVERBOUGHT at RSI >= 80 or >= 10% above its 20-day average;
                with % above the 20 / 50-day averages and distance from its 52-week high - the CE side's "late / don't chase" list
                and the PE side's "watch for a turn" list
  4 OVERSOLD    the mirror (RSI <= 30), for balance
  5 MARKET CAP  if STORE/shares_outstanding.json exists ({"SBIN": 8925961185, ...} = number of shares issued, from NSE's quote
                "issuedSize" or the company's filing): market cap at the NIFTY low and now (Rs crore), the value added, and per sector the
                total added and its share of all value added - this is the weighted answer to "which sector pushed NIFTY"
  python3 rallyscan.py [--from 2026-03-02] [--force]      light, one pass, nice 19; --force to run in market hours
Writes only STORE/rallyscan_report.txt and STORE/rallyscan.csv (every share, every number). numpy only. Not advice: RSI says how far it ran, not when it turns - confirm with price."""
import os, sys, json, datetime as dt
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sectorlag import daily, fmtd, STORE, IST, NOT_SHARES


def rsi(c, n=14):
    d = np.diff(c)
    if len(d) < n + 1:
        return np.nan
    up = np.where(d > 0, d, 0.0); dn = np.where(d < 0, -d, 0.0)
    au, ad = up[:n].mean(), dn[:n].mean()
    for i in range(n, len(d)):
        au = (au * (n - 1) + up[i]) / n; ad = (ad * (n - 1) + dn[i]) / n
    return 100.0 if ad == 0 else 100 - 100 / (1 + au / ad)


def main():
    now = dt.datetime.now(IST)
    if now.weekday() < 5 and (9, 0) <= (now.hour, now.minute) <= (15, 35) and "--force" not in sys.argv:
        print("market hours: add --force (it is light)"); return
    try:
        os.nice(19)
    except Exception:
        pass
    mdir = os.path.join(STORE, "min")
    nif = daily(os.path.join(mdir, "NIFTY.npz"))
    nd = sorted(nif)
    last = nd[-1]
    if "--from" in sys.argv:
        f = dt.date.fromisoformat(sys.argv[sys.argv.index("--from") + 1])
        start = min((d for d in nd if d >= (f - dt.date(1970, 1, 1)).days), default=nd[0])
    else:
        win = [d for d in nd if d >= last - 365]
        start = min(win, key=lambda d: nif[d][1])
    n0, n1 = nif[start][1], nif[last][1]
    sec = json.load(open(os.path.join(STORE, "sectors.json")))
    OF = {x: k for k, v in sec.items() for x in v}
    names = sorted(f[:-4] for f in os.listdir(mdir) if f.endswith(".npz") and f[:-4] not in NOT_SHARES)
    rows = []
    for s in names:
        try:
            D = daily(os.path.join(mdir, s + ".npz"))
        except Exception:
            continue
        ds = sorted(D)
        if not ds or ds[-1] < last - 5:
            continue
        c = np.array([D[d][1] for d in ds])
        j = [i for i, d in enumerate(ds) if d >= start]
        if not j:
            continue
        r = (c[-1] / c[j[0]] - 1) * 100 if len(j) else np.nan
        sma20 = c[-20:].mean() if len(c) >= 20 else np.nan
        sma50 = c[-50:].mean() if len(c) >= 50 else np.nan
        hi52 = c[-250:].max()
        k = int(np.argmin(c[-250:])); lo52 = c[-250:][k]; lo52d = ds[len(ds) - min(250, len(ds)) + k]
        rows.append(dict(s=s, sec=OF.get(s, "-"), ret=r, rsi=rsi(c[-120:]), e20=(c[-1] / sma20 - 1) * 100, e50=(c[-1] / sma50 - 1) * 100,
                         off=(c[-1] / hi52 - 1) * 100, last=c[-1], at_low=c[j[0]], lo52=lo52, lo52d=lo52d, hi52=hi52,
                         from_lo52=(c[-1] / lo52 - 1) * 100))
    L = []
    P = L.append
    P("=== RALLY SCAN (rallyscan.py) · data to %s · %d F&O shares" % (fmtd(last), len(rows)))
    P("1 THE RALLY: NIFTY %s close %.0f -> %s close %.0f = %+.1f%%" % (fmtd(start), n0, fmtd(last), n1, (n1 / n0 - 1) * 100))
    P("")
    P("2 SECTORS over the rally (median move of the sector's F&O shares · members up / all · top 3 shares) - ranked:")
    bys = {}
    for r in rows:
        if r["sec"] != "-" and np.isfinite(r["ret"]):
            bys.setdefault(r["sec"], []).append(r)
    st = []
    for k, v in bys.items():
        if len(v) < 3:
            continue
        rs = np.array([x["ret"] for x in v])
        top = sorted(v, key=lambda x: -x["ret"])[:3]
        st.append((k, np.median(rs), (rs > 0).sum(), len(v), top))
    st.sort(key=lambda t: -t[1])
    for i, (k, med, up, n, top) in enumerate(st):
        P("  %s%-22s %+6.1f%%  up %2d/%-2d  top: %s" % ("*" if i < 5 else " ", k[:22], med, up, n,
                                                       ", ".join("%s %+.0f%%" % (x["s"], x["ret"]) for x in top)))
    P("  (* = the top 5 that pushed hardest by their own move; the store has no index weights, so banks' big NIFTY weight is not")
    P("   counted here - a bank move of +15% adds far more NIFTY points than a small sector's +40%)")
    P("")
    ob = sorted([r for r in rows if np.isfinite(r["rsi"]) and r["rsi"] >= 70], key=lambda r: -r["rsi"])
    P("3 OVERBOUGHT F&O shares (daily RSI14 >= 70) - %d shares; EXTREME = RSI >= 80 or >= 10%% above the 20-day average:" % len(ob))
    P("  %-12s %-18s %5s %7s %7s %8s %9s %s" % ("share", "sector", "RSI", ">20dma", ">50dma", "off 52wH", "rally", ""))
    for r in ob:
        ex = "EXTREME" if (r["rsi"] >= 80 or r["e20"] >= 10) else ""
        P("  %-12s %-18s %5.1f %+6.1f%% %+6.1f%% %+7.1f%% %+8.1f%% %s" % (r["s"], r["sec"][:18], r["rsi"], r["e20"], r["e50"], r["off"], r["ret"], ex))
    shp = os.path.join(STORE, "shares_outstanding.json")
    SH = json.load(open(shp)) if os.path.exists(shp) else {}
    for r in rows:
        n_ = SH.get(r["s"])
        r["mc_low"] = r["at_low"] * n_ / 1e7 if n_ else np.nan
        r["mc_now"] = r["last"] * n_ / 1e7 if n_ else np.nan
        r["mc_add"] = r["mc_now"] - r["mc_low"]
    if SH:
        P("")
        tot = np.nansum([r["mc_add"] for r in rows])
        P("5 MARKET CAP since the NIFTY low (Rs crore; shares issued x price; %d of %d shares have a share count):" % (
            sum(1 for r in rows if np.isfinite(r["mc_add"])), len(rows)))
        P("  value added by all F&O shares: Rs %s cr" % format(int(round(tot)), ","))
        agg = {}
        for r in rows:
            if np.isfinite(r["mc_add"]):
                a = agg.setdefault(r["sec"], [0.0, 0.0, 0.0]); a[0] += r["mc_low"]; a[1] += r["mc_now"]; a[2] += r["mc_add"]
        for k, (lo_, now_, add_) in sorted(agg.items(), key=lambda t: -t[1][2]):
            P("  %-22s at low %12s  now %12s  added %+11s  (%4.1f%% of all value added)" % (k[:22], format(int(lo_), ","), format(int(now_), ","),
                                                                                       format(int(add_), ","), add_ / tot * 100 if tot else 0))
        P("  NOTE: market cap added is the rise in value, not money actually put in; shares issued are today's count (a split or")
        P("  bonus since the low would distort it - check any share with a jump).")
    import csv
    with open(os.path.join(STORE, "rallyscan.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["share", "sector", "nifty_low_date", "close_at_nifty_low", "last_date", "last_close", "move_since_nifty_low_pct",
                    "own_52w_low", "own_52w_low_date", "move_from_own_52w_low_pct", "own_52w_high", "pct_from_52w_high", "rsi14",
                    "pct_above_20dma", "pct_above_50dma", "shares_issued", "mcap_at_nifty_low_cr", "mcap_now_cr", "mcap_added_cr"])
        for r in sorted(rows, key=lambda r: (r["sec"], r["s"])):
            w.writerow([r["s"], r["sec"], str(dt.date(1970, 1, 1) + dt.timedelta(days=int(start))), round(r["at_low"], 2),
                        str(dt.date(1970, 1, 1) + dt.timedelta(days=int(last))), round(r["last"], 2), round(r["ret"], 2),
                        round(r["lo52"], 2), str(dt.date(1970, 1, 1) + dt.timedelta(days=int(r["lo52d"]))), round(r["from_lo52"], 2),
                        round(r["hi52"], 2), round(r["off"], 2), round(r["rsi"], 1) if np.isfinite(r["rsi"]) else "",
                        round(r["e20"], 2), round(r["e50"], 2), SH.get(r["s"], ""),
                        round(r["mc_low"], 0) if np.isfinite(r["mc_low"]) else "", round(r["mc_now"], 0) if np.isfinite(r["mc_now"]) else "",
                        round(r["mc_add"], 0) if np.isfinite(r["mc_add"]) else ""])
    os_ = sorted([r for r in rows if np.isfinite(r["rsi"]) and r["rsi"] <= 30], key=lambda r: r["rsi"])
    P("")
    P("4 OVERSOLD F&O shares (RSI14 <= 30) - %d: " % len(os_) + ", ".join("%s %.0f (%s)" % (r["s"], r["rsi"], r["sec"]) for r in os_))
    P("")
    P("READ: overbought is not a sell signal by itself - strong shares stay overbought in a rally. CE: avoid chasing EXTREME names; buy")
    P("pullbacks to VWAP / the 20-day average. PE: only when an overbought share breaks yesterday's low below VWAP with volume.")
    txt = "\n".join(L)
    print(txt)
    try:
        open(os.path.join(STORE, "rallyscan_report.txt"), "w").write(txt + "\n")
    except Exception as e:
        print("could not write the report:", e)


if __name__ == "__main__":
    main()
