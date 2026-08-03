#!/usr/bin/env python3
"""
PANEL BACKTEST v1.0 — the judges' exam.
Replays the cached 400-day history with NO LOOKAHEAD: at each historical
evaluation point, every judge votes using only data available up to that
point; we then check the ACTUAL forward 5-day and 20-day returns.

Output: report card per judge (edge vs baseline, hit rate), a FIRE LIST of
the weakest judges, and panel-level signal performance (mean>=7 & agree>=70%).

Honest exclusions:
 - 'insti' family is NOT graded (FII/DII/bulk/delivery stores only build
   forward from deployment day; backtesting them would be fake).
 - Alignment across stocks is offset-from-end of each series; stocks with
   missing sessions drift by a day or two. Fine for RANKING judges, not for
   precise PnL claims.

Usage:  python3 panel_backtest.py            (~15-25 min on droplet)
        python3 panel_backtest.py --quick    (500-stock sample, ~5 min)
"""
import os, sys, time, pickle, sqlite3
import numpy as np
import panel  # JUDGES, VETOES, features, score_stock, market_context

CACHE = panel.CACHE
DB_PATH = panel.DB_PATH
REPORT = os.path.join(panel.BASE, "panel_backtest_report.txt")

EXCLUDE_FAMILIES = {"insti"}
OFFSETS = list(range(25, 206, 5))   # bars-before-end eval points (k>=25 so fwd20 exists)
HIGH, LOW = 8.0, 3.0                # vote buckets


def truncate(d, k):
    return {key: arr[: len(arr) - k] for key, arr in d.items()}


def run(quick=False):
    hp = os.path.join(CACHE, "hist.pkl")
    if not os.path.exists(hp):
        raise SystemExit("[BT] No candle cache. Run: python3 panel.py warmup")
    hist = pickle.load(open(hp, "rb"))
    nifty = hist.get("__NIFTY__")
    syms = [s for s in hist if s != "__NIFTY__" and len(hist[s]["c"]) >= max(OFFSETS) + 60]
    if quick:
        rng = np.random.default_rng(42)
        syms = list(rng.choice(syms, size=min(500, len(syms)), replace=False))
    print(f"[BT] {len(syms)} stocks x {len(OFFSETS)} eval points "
          f"(skipped {len(hist)-1-len(syms)} with short history)")

    jstats = {}   # judge -> dict(high=[f5,f20,...], low=[...])
    fams = {}
    for fam, name, _ in panel.JUDGES:
        fams[name] = fam
        if fam not in EXCLUDE_FAMILIES:
            jstats[name] = {"h5": [], "h20": [], "l5": [], "l20": []}
    base5, base20 = [], []
    sig5, sig20, nsig = [], [], 0
    t0 = time.time()

    for ei, k in enumerate(OFFSETS, 1):
        sub = {}
        for s in syms:
            sub[s] = truncate(hist[s], k)
        if nifty is not None and len(nifty["c"]) > k:
            sub["__NIFTY__"] = {"c": nifty["c"][: len(nifty["c"]) - k]}
        mkt = panel.market_context(sub, {})  # empty FII store: insti votes neutral, excluded anyway
        for s in syms:
            full_c = hist[s]["c"]
            n = len(full_c)
            i = n - k - 1                      # index of last known close
            px = full_c[i]
            if px <= 0 or i + 20 >= n:
                continue
            f5 = full_c[i + 5] / px - 1.0
            f20 = full_c[i + 20] / px - 1.0
            base5.append(f5); base20.append(f20)
            f = panel.features(s, sub[s], mkt)
            f["deliv"] = None
            f["bulk"] = {}
            vetoed, mean, agree, votes = panel.score_stock(f)
            if not vetoed and mean >= panel.SIGNAL_MEAN and agree >= panel.SIGNAL_AGREE:
                nsig += 1; sig5.append(f5); sig20.append(f20)
            for jname, (fam, sc) in votes.items():
                if fam in EXCLUDE_FAMILIES:
                    continue
                st = jstats[jname]
                if sc >= HIGH:
                    st["h5"].append(f5); st["h20"].append(f20)
                elif sc <= LOW:
                    st["l5"].append(f5); st["l20"].append(f20)
        print(f"[BT] eval point {ei}/{len(OFFSETS)} done ({time.time()-t0:.0f}s)")

    b5 = float(np.mean(base5)) * 100
    b20 = float(np.mean(base20)) * 100
    lines = []
    lines.append(f"PANEL BACKTEST REPORT — {len(syms)} stocks, {len(OFFSETS)} eval points, "
                 f"{len(base5)} observations")
    lines.append(f"BASELINE (all stocks, all dates): fwd5 {b5:+.2f}%  fwd20 {b20:+.2f}%")
    lines.append("")
    if nsig:
        s5 = float(np.mean(sig5)) * 100; s20 = float(np.mean(sig20)) * 100
        wr = float(np.mean([1 if x > 0 else 0 for x in sig20])) * 100
        lines.append(f"PANEL SIGNALS (mean>=7 & agree>=70%): {nsig} signals | "
                     f"fwd5 {s5:+.2f}% fwd20 {s20:+.2f}% | 20d win-rate {wr:.0f}% | "
                     f"edge vs baseline {s20-b20:+.2f}%")
    else:
        lines.append("PANEL SIGNALS: none fired in backtest window (panel is strict — expected).")
    lines.append("")
    rows = []
    for jname, st in jstats.items():
        if len(st["h20"]) < 30:
            rows.append((jname, fams[jname], len(st["h20"]), None, None, None, None))
            continue
        h5 = float(np.mean(st["h5"])) * 100
        h20 = float(np.mean(st["h20"])) * 100
        hit = float(np.mean([1 if x > 0 else 0 for x in st["h20"]])) * 100
        edge = h20 - b20
        rows.append((jname, fams[jname], len(st["h20"]), h5, h20, hit, edge))
    graded = [r for r in rows if r[6] is not None]
    ungraded = [r for r in rows if r[6] is None]
    graded.sort(key=lambda r: -r[6])
    lines.append(f"{'JUDGE':<26}{'FAMILY':<12}{'N_HIGH':>7}{'F5%':>8}{'F20%':>8}{'HIT%':>6}{'EDGE':>8}")
    for jname, fam, nh, h5, h20, hit, edge in graded:
        lines.append(f"{jname:<26}{fam:<12}{nh:>7}{h5:>8.2f}{h20:>8.2f}{hit:>6.0f}{edge:>8.2f}")
    lines.append("")
    lines.append("=== TOP 10 (keep & maybe up-weight) ===")
    for r in graded[:10]:
        lines.append(f"  {r[0]} ({r[1]}): edge {r[6]:+.2f}% on {r[2]} high votes")
    lines.append("=== FIRE LIST — bottom 10 (negative/zero edge) ===")
    for r in graded[-10:]:
        lines.append(f"  {r[0]} ({r[1]}): edge {r[6]:+.2f}% on {r[2]} high votes")
    if ungraded:
        lines.append(f"=== UNGRADED (too few high votes <30): "
                     f"{', '.join(r[0] for r in ungraded)} ===")
    report = "\n".join(lines)
    open(REPORT, "w").write(report)
    con = sqlite3.connect(DB_PATH)
    con.executescript("""CREATE TABLE IF NOT EXISTS judge_stats(
        ts TEXT, judge TEXT, family TEXT, n_high INTEGER,
        fwd5 REAL, fwd20 REAL, hit REAL, edge REAL);""")
    import datetime as dt
    ts = dt.datetime.now().isoformat()
    for jname, fam, nh, h5, h20, hit, edge in rows:
        con.execute("INSERT INTO judge_stats VALUES(?,?,?,?,?,?,?,?)",
                    (ts, jname, fam, nh, h5, h20, hit, edge))
    con.commit(); con.close()
    print("\n" + report[:4000])
    print(f"\n[BT] Full report: {REPORT} | judge_stats table updated | "
          f"{time.time()-t0:.0f}s total")


if __name__ == "__main__":
    run(quick="--quick" in sys.argv)
