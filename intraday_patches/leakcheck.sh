#!/bin/bash
# LEAK CHECK (patch 182) - did someone know before the news? From GIR's own 3-year data: the sessions before and after a news day -
#   price, volume, futures OI and build-up, CE / PE OI, each against what is normal for that share; the last 75 minutes before the news
#   and the first 30 after. Reads only - nothing is changed, nothing restarts.
#   bash leakcheck.sh                       Policybazaar (IRDAI paper, 23 Sep 2026 after the close) + IndusInd (10 Mar 2025)
#   python3 leakcheck.py SYMBOL YYYY-MM-DD [after|during]     any share, any day
set -u
D=/home/globalbot/intraday
[ -f $D/study3y.py ] && [ -f $D/data/h3/fut.db ] || { echo "the 3-year data is not there (h3.sh)"; exit 1; }
cat > $D/leakcheck.py <<'LEAKCHECK_PY'
#!/usr/bin/env python3
"""leakcheck.py - patch 182: DID SOMEONE KNOW BEFORE? For one share and the day the news came out, from GIR's own 3-year data
(data/h3: daily candles, 5-min candles, NSE's daily F&O file): the 10 sessions before and 3 after - price, volume against its own
20-day normal, futures OI change and the build-up, total CE / PE open interest - each against how unusual it is for THAT share
(compared with its previous 60 sessions). Then the last 75 minutes before the news and the first 30 minutes after.
  python3 leakcheck.py POLICYBZR 2026-09-23 [after]     'after' = the news came after the close that day (the default), 'during' = in the session
Reads only."""
import os, sys, sqlite3, statistics as st, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import study3y as S


def fut(sym):
    c = sqlite3.connect("file:%s?mode=ro" % os.path.join(S.H3, "fut.db"), uri=True)
    out = {d: (foi, fchg, fvol, ce, pe, cech, pech) for d, foi, fchg, fvol, ce, pe, cech, pech in
           c.execute("select d, foi, fchg, fvol, ce_oi, pe_oi, ce_chg, pe_chg from fut where sym=?", (sym,))}
    c.close()
    return out


def z(v, hist):
    h = [x for x in hist if x is not None]
    if v is None or len(h) < 20:
        return None
    sd = st.pstdev(h) or 1e-9
    return (v - st.mean(h)) / sd


def flag(zv):
    return "" if zv is None else ("  ◀◀ VERY UNUSUAL" if abs(zv) >= 3 else "  ◀ unusual" if abs(zv) >= 2 else "")


def bu(p, o):
    if p is None or o is None:
        return "-"
    return ("LONG BUILD-UP" if o > 0 else "SHORT COVERING") if p > 0 else ("SHORT BUILD-UP" if o > 0 else "LONG UNWINDING")


def main(sym, news, when="after"):
    D = S.daily(sym)
    if not D:
        print("no daily candles for %s in data/h3" % sym); return
    F = fut(sym)
    ks = sorted(D)
    i0 = next((i for i, k in enumerate(ks) if k >= news), None)
    if i0 is None:
        print("no candles on / after %s" % news); return
    react = i0 + 1 if (when == "after" and ks[i0] == news) else i0          # the first session that could trade on the news
    rows = []
    for i in range(1, len(ks)):
        k = ks[i]; pc = D[ks[i - 1]][3]; o, h, l, c, v = D[k]
        v20 = S.avg([D[ks[j]][4] for j in range(max(0, i - 20), i)])
        f = F.get(k); pf = F.get(ks[i - 1])
        oi = (f[1] / (f[0] - f[1]) * 100) if f and f[0] and f[0] - f[1] > 0 else None
        ce = (f[5] / (f[3] - f[5]) * 100) if f and f[3] and f[3] - f[5] > 0 else None
        pe = (f[6] / (f[4] - f[6]) * 100) if f and f[4] and f[4] - f[6] > 0 else None
        rows.append({"k": k, "i": i, "chg": S.pct(c, pc), "vx": (v / v20) if v20 else None, "oi": oi, "ce": ce, "pe": pe,
                     "pcr": (f[4] / f[3]) if f and f[3] else None, "c": c})
    R = {r["k"]: r for r in rows}
    print("🔎 LEAK CHECK · %s · news %s (%s the session) · the first session that could trade on it: %s" % (sym, news, when, ks[react]))
    print("each figure against %s's own previous 60 sessions: ◀ unusual (2+ sd) · ◀◀ very unusual (3+ sd)\n" % sym)
    print("%-10s %8s %9s %8s %-15s %8s %8s %6s" % ("date", "price%", "vol x20d", "futOI%", "build-up", "CE OI%", "PE OI%", "PCR"))
    for i in range(max(1, react - 10), min(len(ks), react + 4)):
        r = R.get(ks[i])
        if not r:
            continue
        prev = [R[ks[j]] for j in range(max(1, i - 60), i) if ks[j] in R]
        zs = {m: z(r[m], [p[m] for p in prev]) for m in ("chg", "vx", "oi", "ce", "pe")}
        worst = max((abs(x) for x in zs.values() if x is not None), default=0)
        tag = " ◀◀" if worst >= 3 else " ◀" if worst >= 2 else ""
        mark = "  ← THE NEWS" if ks[i] == news else "  ← THE REACTION" if i == react else ""
        f_ = lambda v, n=1: ("%+.*f" % (n, v)) if v is not None else "-"
        print("%-10s %8s %9s %8s %-15s %8s %8s %6s%s%s" % (r["k"], f_(r["chg"]), ("%.1fx" % r["vx"]) if r["vx"] else "-", f_(r["oi"]), bu(r["chg"], r["oi"]),
                                                        f_(r["ce"]), f_(r["pe"]), ("%.2f" % r["pcr"]) if r["pcr"] else "-", tag, mark))
        if worst >= 2 and i < react:
            print("           ↳ unusual before the news: %s" % ", ".join("%s %.1f sd" % ({"chg": "price", "vx": "volume", "oi": "futures OI", "ce": "CE OI", "pe": "PE OI"}[m], x)
                                                                       for m, x in zs.items() if x is not None and abs(x) >= 2))
    M = S.intraday(sym)
    lastb = ks[react - 1] if when == "after" else ks[react]
    x = M.get(lastb)
    if x is not None:
        pc = D[ks[ks.index(lastb) - 1]][3]
        print("\nthe last 75 minutes of %s (before the news came out) - 15-min blocks: price vs the previous close · volume vs the day's own average block" % lastb)
        avgv = float(x[4].sum()) / 25 if x[4].sum() else 0
        for b in range(60, 75, 3):
            v = float(x[4][b:b + 3].sum())
            t = "%02d:%02d" % divmod(555 + b * 5, 60)
            print("   %s  %+.2f%%  volume %.1fx%s" % (t, S.pct(float(x[3][b + 2]), pc), v / avgv if avgv else 0, "  ◀ heavy" if avgv and v / avgv >= 2 else ""))
    y = M.get(ks[react])
    if y is not None:
        pc = D[ks[react - 1]][3]
        print("\nthe first 30 minutes of %s (after the news):" % ks[react])
        for b in range(0, 6):
            print("   %02d:%02d  %+.2f%%" % (divmod(555 + b * 5, 60) + (S.pct(float(y[3][b]), pc),)))
    print("\nhow to read it: a leak shows as UNUSUAL selling before the news - price falling, volume 2x+, futures OI rising with the price down"
          " (short build-up) or PE OI jumping - on the days before. Quiet days before and the whole move at the first open = the market learnt it"
          " with the news.")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    main(sys.argv[1].upper(), sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "after")
LEAKCHECK_PY
cat > $D/p182test.py <<'P182TEST_PY'
#!/usr/bin/env python3
"""p182test.py - the leak check on a made-up share: quiet for 60 days, heavy put buying 2 days before the news, a -30% gap after"""
import os, sys, io, sqlite3, tempfile, shutil, contextlib, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import study3y as S, leakcheck as L
T = tempfile.mkdtemp(); S.H3 = T
for d_ in ("day", "m5"):
    os.makedirs(os.path.join(T, d_))
IST = S.IST
days = []; d = dt.date(2026, 6, 1)
while len(days) < 90:
    if d.weekday() < 5:
        days.append(d)
    d += dt.timedelta(days=1)
news_i = 80
c = 1000.0; ts = []; O = []; H = []; Lw = []; C = []; V = []
f = sqlite3.connect(os.path.join(T, "fut.db"))
f.execute("create table fut(d text, sym text, fclose real, foi real, fchg real, fvol real, exp text, ce_oi real, pe_oi real, ce_chg real, pe_chg real)")
oi, ce, pe = 1e7, 5e6, 4e6
rng = np.random.default_rng(1)
for i, d in enumerate(days):
    pc = c
    mv = -0.30 if i == news_i + 1 else (-0.015 if i in (news_i - 1, news_i) else rng.normal(0, 0.008))
    c = pc * (1 + mv)
    ts.append(dt.datetime.combine(d, dt.time(0, 0), IST).timestamp()); O.append(pc if i != news_i + 1 else c); H.append(max(pc, c)); Lw.append(min(pc, c)); C.append(c)
    V.append(1e6 * (3.5 if i in (news_i - 1, news_i) else 6 if i == news_i + 1 else 1 + rng.normal(0, 0.1)))
    och = 0.15 if i in (news_i - 1, news_i) else rng.normal(0, 0.02); pch = 0.40 if i in (news_i - 1, news_i) else rng.normal(0, 0.03)
    ch = oi * och; oi += ch; pcd = pe * pch; pe += pcd; ccd = ce * rng.normal(0, 0.03); ce += ccd
    f.execute("insert into fut values(?,?,?,?,?,?,?,?,?,?,?)", (str(d), "TST", c, oi, ch, 1, "x", ce, pe, ccd, pcd))
f.commit(); f.close()
np.savez(os.path.join(T, "day", "TST.npz"), ts=np.array(ts), o=np.array(O), h=np.array(H), l=np.array(Lw), c=np.array(C), v=np.array(V))
b = io.StringIO()
with contextlib.redirect_stdout(b):
    L.main("TST", str(days[news_i]), "after")
out = b.getvalue(); print(out)
ok = "THE NEWS" in out and "THE REACTION" in out and out.count("unusual before the news") >= 2 and "PE OI 11.8 sd" in out
print("P182 TEST " + ("PASSED" if ok else "FAILED")); shutil.rmtree(T); sys.exit(0 if ok else 1)
P182TEST_PY
cd $D && python3 -m py_compile leakcheck.py && timeout 60 python3 p182test.py > /tmp/p182test.log 2>&1 && echo "p182test.py passed" || { echo "test failed"; tail -3 /tmp/p182test.log; exit 1; }
echo
timeout 300 nice -n 10 python3 leakcheck.py POLICYBZR 2026-09-23 after
echo; echo "=================================================================="; echo
timeout 300 nice -n 10 python3 leakcheck.py INDUSINDBK 2025-03-10 after
