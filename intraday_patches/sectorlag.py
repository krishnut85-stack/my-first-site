#!/usr/bin/env python3
"""sectorlag.py - READ ONLY. "The last time metal shares were down after the auto sector, which sector moved up - and which shares?"
(the trader, 20 Nov). Looks at every day in the minute store (/root/hist, or GIR_HIST) and answers from history, CE and PE both:

  E1  metal sector down (median of its F&O shares <= -1.0%) on a day the auto sector is UP (>= +0.5%)   - metal falls, auto gains
  E2  metal sector down <= -1.0% (whatever auto did)
  E3  auto sector up >= +1.0% (auto led) - what moved the NEXT days
For each event set: every sector's median move on the day (D) and the next 1 / 2 / 3 days (close to close), how often it was up, and
the same against ALL days (the baseline) - so "beats normal" is visible; then the shares that most often rose (CE) and fell (PE) on
D and D+1, with n; then the LAST 12 event days with the day's and the next day's top 5 risers and fallers ("the last time").

  python3 sectorlag.py                    after 15:35 (or add --force to run now; it is light: one pass, nice 19)
  python3 sectorlag.py --a metal --b auto --down 1.0 --up 0.5      the sector name patterns and thresholds (defaults shown)
Reads only STORE/min/SYM.npz and STORE/sectors.json ({sector: [shares]}). Writes only STORE/sectorlag_report.txt. numpy only."""
import os, sys, json, datetime as dt
import numpy as np

STORE = os.environ.get("GIR_HIST", "/root/hist")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOT_SHARES = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50", "SENSEX", "BANKEX"}


def arg(name, default):
    if name in sys.argv:
        i = sys.argv.index(name)
        return type(default)(sys.argv[i + 1])
    return default


def daily(path):
    """-> {date_ordinal: (open, close)} from minute candles; days with < 200 minutes are dropped"""
    z = np.load(path)
    ts = z["ts"].astype(np.int64); o = z["o"].astype(float); c = z["c"].astype(float)
    if not len(ts):
        return {}
    loc = ts + 19800
    day = loc // 86400
    mins = (loc % 86400) // 60
    keep = (mins >= 9 * 60 + 15) & (mins <= 15 * 60 + 29)
    day, o, c = day[keep], o[keep], c[keep]
    out = {}
    if not len(day):
        return out
    cut = np.flatnonzero(np.diff(day)) + 1
    starts = np.r_[0, cut]; ends = np.r_[cut, len(day)]
    for a, b in zip(starts, ends):
        if b - a >= 200 and o[a] > 0 and c[b - 1] > 0:
            out[int(day[a])] = (o[a], c[b - 1])
    return out


def fmtd(d):
    return (dt.date(1970, 1, 1) + dt.timedelta(days=int(d))).strftime("%a %d %b %Y")


def main():
    now = dt.datetime.now(IST)
    if now.weekday() < 5 and (9, 0) <= (now.hour, now.minute) <= (15, 35) and "--force" not in sys.argv:
        print("market hours: run after 15:35, or add --force (it is light)"); return
    try:
        os.nice(19)
    except Exception:
        pass
    A, B = arg("--a", "metal").lower(), arg("--b", "auto").lower()
    DOWN, UP = arg("--down", 1.0), arg("--up", 0.5)
    sec = json.load(open(os.path.join(STORE, "sectors.json")))
    mdir = os.path.join(STORE, "min")
    names = sorted(f[:-4] for f in os.listdir(mdir) if f.endswith(".npz") and f[:-4] not in NOT_SHARES)
    D = {}
    for s in names:
        try:
            D[s] = daily(os.path.join(mdir, s + ".npz"))
        except Exception:
            pass
    days = sorted({d for v in D.values() for d in v})
    di = {d: i for i, d in enumerate(days)}
    S = sorted(D); si = {s: i for i, s in enumerate(S)}
    C = np.full((len(S), len(days)), np.nan)
    for s, v in D.items():
        for d, (o_, c_) in v.items():
            C[si[s], di[d]] = c_
    R = np.full_like(C, np.nan)
    R[:, 1:] = (C[:, 1:] / C[:, :-1] - 1) * 100          # close to close, %
    R[np.abs(R) > 20] = np.nan                           # split / bonus jumps out
    secs = {k: [x for x in v if x in si] for k, v in sec.items()}
    secs = {k: v for k, v in secs.items() if len(v) >= 3 and not any(w in k.lower() for w in ("other", "misc", "divers", "conglomer"))}
    SR = {k: np.nanmedian(R[[si[x] for x in v]], axis=0) for k, v in secs.items()}
    ka = [k for k in secs if A in k.lower()]; kb = [k for k in secs if B in k.lower()]
    L = []
    P = L.append
    P("=== SECTOR LAG (sectorlag.py) · %s -> %s · %d market days · %d shares · %d sectors (3+ F&O shares)" % (fmtd(days[0]), fmtd(days[-1]), len(days), len(S), len(secs)))
    P("    sector move = median close-to-close %% of its F&O shares in the store (sectors.json = today's members). '%s' = %s · '%s' = %s"
      % (A, ", ".join(ka) or "NONE FOUND", B, ", ".join(kb) or "NONE FOUND"))
    if not ka or not kb:
        P("!! a sector name was not found: run with --a / --b set to a word in these names: " + ", ".join(sorted(secs)))
        out(L); return
    ma = np.nanmedian(np.vstack([SR[k] for k in ka]), axis=0); mb = np.nanmedian(np.vstack([SR[k] for k in kb]), axis=0)
    ev = {
        "E1 %s down <= -%.1f%% AND %s up >= +%.1f%% the same day" % (A, DOWN, B, UP): np.flatnonzero((ma <= -DOWN) & (mb >= UP)),
        "E2 %s down <= -%.1f%%" % (A, DOWN): np.flatnonzero(ma <= -DOWN),
        "E3 %s up >= +1.0%% (it led)" % B: np.flatnonzero(mb >= 1.0),
    }
    T = len(days)

    def fwd(row, idx, k):
        j = idx + k
        j = j[j < T]
        if k == 0:
            return row[idx]
        # cumulative D+1..D+k (close of D to close of D+k)
        out_ = []
        for i in idx:
            if i + k < T:
                seg = row[i + 1:i + k + 1]
                out_.append((np.prod(1 + seg / 100) - 1) * 100 if np.all(np.isfinite(seg)) else np.nan)
        return np.array(out_)

    allidx = np.arange(1, T - 3)
    for name, idx in ev.items():
        idx = idx[idx >= 1]
        P(""); P("=== %s · %d days" % (name, len(idx)))
        if len(idx) < 3:
            P("    too few days to say anything"); continue
        P("    SECTORS - median move % (how often up) on the day D and from D's close to D+1 / D+2 / D+3; [baseline over all days]")
        rows = []
        for k, r in SR.items():
            cells = []
            for kk in (0, 1, 2, 3):
                x = fwd(r, idx, kk); x = x[np.isfinite(x)]
                b = fwd(r, allidx, kk); b = b[np.isfinite(b)]
                cells.append((np.median(x) if len(x) else np.nan, (x > 0).mean() * 100 if len(x) else np.nan, len(x),
                              np.median(b) if len(b) else np.nan, (b > 0).mean() * 100 if len(b) else np.nan))
            rows.append((k, cells))
        rows.sort(key=lambda t: -(t[1][1][0] - t[1][1][3]) if np.isfinite(t[1][1][0]) else 9)
        for k, cells in rows:
            P("    %-28s " % k[:28] + " · ".join("%s %+5.2f (%3.0f%% up) [%+5.2f %3.0f%%]" % (lab, c[0], c[1], c[3], c[4])
                                                for lab, c in zip(("D", "D+1", "D+2", "D+3"), cells)))
        P("    (sorted by D+1 move above its baseline: the top rows are the NEXT-DAY beneficiaries, the bottom rows the next-day losers)")
        for kk, lab in ((0, "ON THE DAY (D)"), (1, "THE NEXT DAY (D+1)")):
            st = []
            for s in S:
                x = fwd(R[si[s]], idx, kk); x = x[np.isfinite(x)]
                if len(x) >= max(3, len(idx) // 3):
                    st.append((s, np.median(x), (x > 0).mean() * 100, len(x)))
            st.sort(key=lambda t: -t[1])
            P("    SHARES %s - most often UP (CE): " % lab + " · ".join("%s %+.2f%% (%.0f%% up, n=%d)" % t for t in st[:10]))
            P("    SHARES %s - most often DOWN (PE): " % lab + " · ".join("%s %+.2f%% (%.0f%% up, n=%d)" % t for t in st[::-1][:10]))
        P("    THE LAST 12 TIMES - the day's and the next day's top 5 risers / fallers (F&O shares in the store):")
        for i in idx[-12:][::-1]:
            def top(col):
                v = [(S[j], R[j, col]) for j in range(len(S)) if np.isfinite(R[j, col])]
                v.sort(key=lambda t: -t[1])
                return v
            d0 = top(i); d1 = top(i + 1) if i + 1 < T else []
            P("    %s  %s %+.2f%% / %s %+.2f%%" % (fmtd(days[i]), A, ma[i], B, mb[i]))
            P("        day up:   " + ", ".join("%s %+.1f" % t for t in d0[:5]) + "   day down: " + ", ".join("%s %+.1f" % t for t in d0[::-1][:5]))
            if d1:
                P("        next up:  " + ", ".join("%s %+.1f" % t for t in d1[:5]) + "   next down: " + ", ".join("%s %+.1f" % t for t in d1[::-1][:5]))
    P(""); P("LIMITS: close-to-close only (no intraday timing); sectors are today's members; F&O shares only; a median hides one big mover -")
    P("the share lists and 'the last 12 times' show them. History is a guide, not a promise: confirm live (sector breadth, leader above")
    P("yesterday's high and VWAP with volume) before any CE / PE.")
    out(L)


def out(L):
    txt = "\n".join(L)
    print(txt)
    try:
        open(os.path.join(STORE, "sectorlag_report.txt"), "w").write(txt + "\n")
    except Exception as e:
        print("could not write the report:", e)


if __name__ == "__main__":
    main()
