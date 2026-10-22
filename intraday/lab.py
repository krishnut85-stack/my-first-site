#!/usr/bin/env python3
"""lab.py - the Strategy Lab.

Builds every combination of entry x side x timeframe x filter x time-window x stop x exit
(about 4,800), backtests each on the downloaded 5-minute history with real costs, and
approves only strategies that survive three separate stretches of time:

  TRAIN   (oldest 50% of days)  - where strategies are compared
  CHECK   (next 25%)            - must also be profitable here
  UNSEEN  (newest 25%)          - looked at ONLY for the few finalists; decides approval

  python3 lab.py           run and send the report to Telegram
  python3 lab.py --dry     run, print the report, send nothing
"""
import os, sys, json, time, sqlite3, itertools
import numpy as np
import core
import getdata

DB = os.path.join(core.BASE, "lab.db")
APPROVED = os.path.join(core.BASE, "approved.json")
FINALISTS = 12
T_UNSEEN = 1.65


def combos():
    out = []
    for entry, side, tf, f, stopm, ex in itertools.product(core.ENTRIES, (1, -1), core.TFS, core.FILTERS,
                                                         core.STOPS, core.EXITS):
        wins = ["W1"] if entry in core.GAP_ENTRIES else list(core.WINDOWS)
        for w in wins:
            out.append({"entry": entry, "side": side, "tf": tf, "filt": f, "window": w,
                        "stopm": stopm, "exit": ex})
    return out


CHUNK = 100


def load_stack(tf, uni, verbose=True, lo=0, hi=None):
    """Stack shares uni[lo:hi]. The share number (= liquidity rank) stays global."""
    nif_raw = core.load_npz("NIFTY50")
    nif = core.prep_nifty(nif_raw, tf) if nif_raw is not None else None
    hi = len(uni) if hi is None else min(hi, len(uni))

    def gen():
        for si in range(lo, hi):
            a = core.load_npz(uni[si]["sym"])
            if a is None or len(a["ts"]) < 75 * 60:
                continue
            yield si, core.prep(a, nif, tf)
    M = core.stack(gen())
    if verbose and M is not None:
        print("  %dm shares %d-%d: %d share-days" % (tf, lo, hi, len(M["day"])))
    return M


def stats(net):
    n = len(net)
    if n == 0:
        return 0, 0.0, 0.0, 0.0, 0.0
    m = float(net.mean())
    w = float((net > 0).mean())
    gain, loss = net[net > 0].sum(), -net[net < 0].sum()
    pf = float(gain / loss) if loss > 0 else 9.99
    sd = float(net.std())
    t = m / sd * np.sqrt(n) if sd > 0 and n > 1 else 0.0
    return n, m, w, min(pf, 9.99), float(t)


def run_tf(tf, uni, c, cp, cut_a, cut_b, chunk=None):
    """Backtest every combination at one timeframe.

    The universe is processed CHUNK shares at a time. The rule "take the first
    max_trades_day entries of the day" is applied inside each chunk and then again across
    chunks - the overall first-k is always inside the union of the per-chunk first-k, so the
    result is identical to processing everything at once."""
    chunk = chunk or CHUNK
    K = c["max_trades_day"]
    SE = [(st, ex) for st in core.STOPS for ex in core.EXITS]
    groups, shares = {}, 0
    for lo in range(0, len(uni), chunk):
        M = load_stack(tf, uni, True, lo, lo + chunk)
        if M is None:
            continue
        shares += len(np.unique(M["sym"]))
        for side in (1, -1):
            V = core.side_view(M, side)
            fl = {f: core.filt(V, f, c) for f in core.FILTERS}
            for entry in core.ENTRIES:
                base = core.signal(V, entry, tf, c)
                for f in core.FILTERS:
                    sig = base if fl[f] is None else (base & fl[f])
                    for w in (["W1"] if entry in core.GAP_ENTRIES else list(core.WINDOWS)):
                        e_all = core.first_entry(sig, tf, w)
                        rows = core.first_k(M["day"], e_all, M["sym"], K)
                        if len(rows) == 0:
                            continue
                        e = e_all[rows]
                        R = np.empty((len(rows), len(SE)), np.float32)
                        OK = np.empty((len(rows), len(SE)), bool)
                        for n, (st, ex) in enumerate(SE):
                            R[:, n], OK[:, n] = core.simulate(V, rows, e, st, ex, tf, c)
                        groups.setdefault((entry, side, f, w), []).append(
                            (M["day"][rows], e.astype(np.int32), M["sym"][rows], R, OK))
        del M, V, fl
    res = []
    for (entry, side, f, w), parts in groups.items():
        day = np.concatenate([p[0] for p in parts])
        e = np.concatenate([p[1] for p in parts])
        sym = np.concatenate([p[2] for p in parts])
        R = np.concatenate([p[3] for p in parts])
        OK = np.concatenate([p[4] for p in parts])
        keep = core.first_k(day, e, sym, K)
        day, R, OK = day[keep], R[keep], OK[keep]
        month = day.astype("datetime64[D]").astype("datetime64[M]").astype(np.int64)
        for n, (st, ex) in enumerate(SE):
            ok = OK[:, n]
            net = R[ok, n].astype(float) - cp
            d, mo = day[ok], month[ok]
            tr, va, te = d < cut_a, (d >= cut_a) & (d < cut_b), d >= cut_b
            pre = ~te
            if pre.any():
                um, inv = np.unique(mo[pre], return_inverse=True)
                mpos = float((np.bincount(inv, weights=net[pre]) > 0).mean())
            else:
                mpos = 0.0
            res.append({"s": {"entry": entry, "side": side, "tf": tf, "filt": f, "window": w,
                              "stopm": st, "exit": ex},
                        "tr": stats(net[tr]), "va": stats(net[va]), "te": stats(net[te]), "mpos": mpos,
                        "pre_mean": float(net[pre].mean()) if pre.any() else 0.0})
    return res, shares


def choose(res, c):
    # neighbour check: brothers = same idea with other stop/exit settings
    fam = {}
    for r in res:
        s = r["s"]
        fam.setdefault((s["entry"], s["side"], s["tf"], s["filt"], s["window"]), []).append(r)
    for rs in fam.values():
        frac = sum(1 for r in rs if r["pre_mean"] > 0) / float(len(rs))
        for r in rs:
            r["nb"] = frac
    stage1 = []
    for r in res:
        tr, va = r["tr"], r["va"]
        if (tr[0] >= 100 and va[0] >= 40 and tr[1] > 0 and va[1] > 0 and tr[3] >= 1.15
                and va[3] >= 1.05 and r["nb"] >= 0.6 and r["mpos"] >= 0.55):
            r["score"] = min(tr[4], va[4])
            stage1.append(r)
    stage1.sort(key=lambda r: -r["score"])
    finals, per = [], {}
    for r in stage1:
        k = (r["s"]["entry"], r["s"]["side"])
        if per.get(k, 0) >= 1:
            continue
        per[k] = per.get(k, 0) + 1
        finals.append(r)
        if len(finals) >= FINALISTS:
            break
    approved = []
    for r in finals:
        te = r["te"]
        r["pass"] = bool(te[0] >= 30 and te[1] > 0 and te[3] >= 1.1 and te[4] >= T_UNSEEN)
        if r["pass"] and len(approved) < c["max_strategies"]:
            approved.append(r)
    return stage1, finals, approved


def hm(x):
    return "%02d:%02d" % divmod(x, 100)


def describe(s):
    w = core.WINDOWS[s["window"]]
    return "%s · %s · %s · %d-min candles · entries %s-%s · stop %sx ATR · %s" % (
        "BUY" if s["side"] == 1 else "SELL short",
        (core.ENTRY_TEXT_L if s["side"] == 1 else core.ENTRY_TEXT_S)[s["entry"]],
        core.FILTER_TEXT[s["filt"]] if s["side"] == 1 or s["filt"] in ("NONE", "VOL") else
        {"TREND": "with 20-day downtrend", "MKT": "with Nifty falling"}[s["filt"]],
        s["tf"], hm(w[0]), hm(w[1]), s["stopm"],
        {"TP15": "target 1.5x stop", "TP25": "target 2.5x stop", "TIME": "hold to 15:15",
         "TRAIL": "trailing stop"}[s["exit"]])


def pack(r, label):
    te, tr, va = r["te"], r["tr"], r["va"]
    n = tr[0] + va[0] + te[0]
    return {"id": core.strat_id(r["s"]), "label": label, "desc": describe(r["s"]),
            "trades": n, "win": round((tr[2] * tr[0] + va[2] * va[0] + te[2] * te[0]) / max(n, 1) * 100, 1),
            "exp": round((tr[1] * tr[0] + va[1] * va[0] + te[1] * te[0]) / max(n, 1), 3),
            "unseen_trades": te[0], "unseen_win": round(te[2] * 100, 1), "unseen_exp": round(te[1], 3),
            "unseen_pf": round(te[3], 2), **r["s"]}


def save_db(res):
    if os.path.exists(DB):
        os.remove(DB)
    con = sqlite3.connect(DB)
    con.execute("create table results(id text, entry text, side int, tf int, filt text, win text, stopm real,"
                " exit text, n_tr int, exp_tr real, win_tr real, pf_tr real, t_tr real, n_va int, exp_va real,"
                " win_va real, pf_va real, t_va real, n_te int, exp_te real, win_te real, pf_te real, t_te real,"
                " months_pos real, neighbours real)")
    con.executemany("insert into results values(%s)" % ",".join("?" * 25), [
        (core.strat_id(r["s"]), r["s"]["entry"], r["s"]["side"], r["s"]["tf"], r["s"]["filt"], r["s"]["window"],
         r["s"]["stopm"], r["s"]["exit"]) + tuple(r["tr"]) + tuple(r["va"]) + tuple(r["te"])
        + (r["mpos"], r.get("nb", 0.0)) for r in res])
    con.commit()
    con.close()


def main():
    dry = "--dry" in sys.argv
    c = core.cfg()
    uni = getdata.load_universe()
    if not uni:
        print("no universe.json - run getdata.py first")
        sys.exit(1)
    cp = core.cost_pct(c["position_rs"], c)
    t0 = time.time()
    nif = core.load_npz("NIFTY50")
    days = np.unique(core.to_matrix(nif, min_bars=60)["days"])
    if len(days) < 120:
        print("only %d days of data - need at least 120" % len(days))
        sys.exit(1)
    cut_a, cut_b = days[int(len(days) * 0.5)], days[int(len(days) * 0.75)]
    print("data: %s to %s (%d trading days). cost per trade %.3f%%" % (
        core.ord_date(days[0]), core.ord_date(days[-1]), len(days), cp))
    res, shares = [], 0
    for tf in core.TFS:
        r, shares = run_tf(tf, uni, c, cp, cut_a, cut_b)
        res += r
    stage1, finals, approved = choose(res, c)
    save_db(res)
    out = [pack(r, "APPROVED") for r in approved]
    if not out and c.get("paper_unproven"):
        pool = finals[:3]
        if not pool:   # nothing even passed TRAIN + CHECK: take the least-bad ideas that were positive in both
            cand = [r for r in res if r["tr"][0] >= 100 and r["va"][0] >= 40 and r["tr"][1] > 0 and r["va"][1] > 0]
            cand.sort(key=lambda r: -min(r["tr"][4], r["va"][4]))
            seen = set()
            for r in cand:
                k = (r["s"]["entry"], r["s"]["side"])
                if k not in seen:
                    seen.add(k)
                    pool.append(r)
                if len(pool) >= 3:
                    break
        out = [pack(r, "UNPROVEN") for r in pool]
    json.dump({"run": str(core.ist_now())[:16], "tested": len(res), "stage1": len(stage1),
               "finalists": len(finals), "cost_pct": round(cp, 3),
               "unseen_from": str(core.ord_date(cut_b)), "strategies": out}, open(APPROVED, "w"), indent=1)
    L = ["🧪 STRATEGY LAB result",
         "Data %s → %s, %d days, %d shares" % (core.ord_date(days[0]), core.ord_date(days[-1]), len(days), shares),
         "Tested %d strategies with costs (%.2f%% per trade)" % (len(res), cp),
         "Passed TRAIN + CHECK: %d" % len(stage1),
         "Finalists shown the UNSEEN data (from %s): %d" % (core.ord_date(cut_b), len(finals)),
         "Passed UNSEEN → APPROVED: %d" % len(approved),
         "(by luck alone about %.1f of the finalists would pass)" % (0.05 * len(finals)), ""]
    for i, s in enumerate(out, 1):
        L.append("S%d [%s] %s" % (i, s["label"], s["desc"]))
        L.append("   all data: %d trades, %s%% wins, %+.2f%%/trade after costs" % (s["trades"], s["win"], s["exp"]))
        L.append("   unseen: %d trades, %s%% wins, %+.2f%%/trade, PF %s" % (
            s["unseen_trades"], s["unseen_win"], s["unseen_exp"], s["unseen_pf"]))
    if not approved:
        L.append("❗ No strategy passed the unseen-data test." + (
            " The %d least-bad ideas above will be PAPER traded, marked UNPROVEN - expect them to roughly"
            " break even or lose; they are there to collect evidence, not to follow with money." % len(out) if out else
            " Nothing will be traded: not one rule was profitable after costs in both TRAIN and CHECK."))
    if not approved:
        top = sorted([r for r in res if r["tr"][0] >= 100], key=lambda r: -r["tr"][4])[:3]
        if top:
            L.append("")
            L.append("Best 3 in TRAIN and what they did next (per trade, after costs):")
            for r in top:
                L.append("  %s: train %+.2f%% → check %+.2f%% (%d trades)" % (
                    core.strat_id(r["s"]), r["tr"][1], r["va"][1], r["va"][0]))
    L.append("")
    L.append("Paper trading only. Lab took %.0f s." % (time.time() - t0))
    msg = "\n".join(L)
    print(msg)
    if not dry:
        core.tg(msg)


if __name__ == "__main__":
    main()
