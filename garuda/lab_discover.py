"""LAB DISCOVER — reverse strategy search: start from the DATA and work backwards.

The curated LAB tests a handful of hand-picked ideas. DISCOVER goes the other
way, the way you'd retrace a wrong road: it enumerates EVERY combination of

    TREND filter   x   ENTRY setup   x   EXTRA control   x   EXIT rule

(a grid of ~1000+ rule combinations built from the classic screener vocabulary —
RSI dips, breakouts, 52-week highs, momentum, volatility squeezes, pullbacks,
streaks...) and lets five years of real NSE closes decide which roads made
money. Nothing is assumed; everything is measured, after full delivery costs.

Mining a grid this size WILL find lucky garbage — best-of-1000 is practically
guaranteed to look brilliant on the data it was mined from. So the history is
cut into THREE windows, strictly by calendar:

    TRAIN  (oldest 50%)  — every combo is backtested here; the top performers
                           with a real trade count are shortlisted.
    SELECT (middle 20%)  — the shortlist must ALSO be profitable here; this
                           absorbs the best-of-many selection bias.
    TEST   (newest 30%)  — judged ONCE, only for the finalists. Data that no
                           part of the search ever touched. The only verdict
                           that counts.

VALIDATED = profitable after costs in all three windows, including the untouched
TEST. FAILED = looked great mined, died on unseen data (expected for most!).

    python3 -m garuda.lab_discover --csv strength_history.csv        # ~5-10 min
    python3 -m garuda.lab_discover --csv strength_history.csv --top 15

Results go to data/garuda_lab_discover.json and render on the dashboard's LAB
tab under DISCOVERED. PAPER / research only — VALIDATED means "survived an
honest three-window search", never "guaranteed money".
"""

import argparse
import json
import sys
from pathlib import Path

from . import config
from .cross import _load_long
from .lab import LAB_COST_PER_SIDE, _bucket_stats
from .setups import rsi, sma

# statistical floors — a mined combo below these proves nothing
MIN_TRAIN_TRADES = 300
MIN_SELECT_TRADES = 80
MIN_TEST_TRADES = 80
SHORTLIST = 25            # top combos carried from TRAIN into SELECT


# --------------------------------------------------------------------------
# The rule vocabulary. Each part is (key, human label, needs) — conditions are
# evaluated per bar per symbol into BITMASKS (one int per symbol, bit i = bar i
# qualifies), so ANDing a whole combo is a single big-int operation.
# --------------------------------------------------------------------------

TRENDS = [
    ("any",      "no trend filter"),
    ("gt200",    "above 200-DMA"),
    ("gt50",     "above 50-DMA"),
    ("50gt200",  "50-DMA above 200-DMA"),
]

SETUPS = [
    ("rsi2lt5",   "RSI-2 < 5 (deep dip)"),
    ("rsi2lt10",  "RSI-2 < 10 (dip)"),
    ("down3",     "3+ consecutive red closes"),
    ("wk_dn8",    "5-day return <= -8%"),
    ("day_dn5",   "1-day drop <= -5%"),
    ("brk20",     "fresh 20-day-high breakout"),
    ("near52",    "within 2% of the 52-week high"),
    ("mom25",     "3-month momentum > +25%"),
    ("mom50",     "3-month momentum > +50%"),
    ("rsi14band", "RSI-14 in 55-70 (strong, not overbought)"),
    ("squeeze",   "volatility squeeze (10-day range < 40% of normal)"),
]

EXTRAS = [
    ("any",      "no extra control"),
    ("belowma20", "pulled back under the 20-DMA"),
    ("abovema20", "holding above the 20-DMA"),
    ("near52w10", "within 10% of the 52-week high"),
]

EXITS = [
    ("green7",    "first green close or 7 days"),
    ("rsi65_30",  "RSI-2 > 65 or 30 days"),
    ("trail10_60", "10% trailing stop or 60 days"),
    ("trail15_120", "15% trailing stop or 120 days"),
    ("tgt5_stop10_10", "+5% target, -10% stop, 10 days"),
    ("hold20",    "fixed 20-day hold"),
]


def _features(closes):
    """Per-symbol indicator arrays computed ONCE (the expensive part)."""
    n = len(closes)
    f = {"c": closes, "sma20": sma(closes, 20), "sma50": sma(closes, 50),
         "sma200": sma(closes, 200), "rsi2": rsi(closes, 2), "rsi14": rsi(closes, 14)}
    hi20 = [None] * n
    hi252 = [None] * n
    for i in range(19, n):
        hi20[i] = max(closes[i - 19:i + 1])
    for i in range(251, n):
        hi252[i] = max(closes[i - 251:i + 1])
    f["hi20"], f["hi252"] = hi20, hi252
    streak = [0] * n                                   # consecutive red closes
    for i in range(1, n):
        streak[i] = streak[i - 1] + 1 if closes[i] < closes[i - 1] else 0
    f["down"] = streak
    rng10 = [None] * n                                 # 10-day close-range fraction
    for i in range(9, n):
        w = closes[i - 9:i + 1]
        rng10[i] = (max(w) - min(w)) / closes[i] if closes[i] > 0 else None
    avg60 = [None] * n                                 # its 60-day average
    run, cnt = 0.0, 0
    for i in range(n):
        if rng10[i] is not None:
            run += rng10[i]
            cnt += 1
            if cnt > 60:
                run -= rng10[i - 60]
            if cnt >= 60:
                avg60[i] = run / 60.0
    f["rng10"], f["avgrng"] = rng10, avg60
    return f


def _masks(f):
    """Every atomic condition as a bitmask over the bars (bit i = bar i true)."""
    c, n = f["c"], len(f["c"])
    m = {k: 0 for k in ("gt200", "gt50", "50gt200", "rsi2lt5", "rsi2lt10", "down3",
                        "wk_dn8", "day_dn5", "brk20", "near52", "mom25", "mom50",
                        "rsi14band", "squeeze", "belowma20", "abovema20", "near52w10")}
    s20, s50, s200 = f["sma20"], f["sma50"], f["sma200"]
    r2, r14, hi20, hi252 = f["rsi2"], f["rsi14"], f["hi20"], f["hi252"]
    down, rng10, avgrng = f["down"], f["rng10"], f["avgrng"]
    for i in range(n):
        b = 1 << i
        ci = c[i]
        if ci <= 0:
            continue
        if s200[i] is not None and ci > s200[i]:
            m["gt200"] |= b
        if s50[i] is not None and ci > s50[i]:
            m["gt50"] |= b
        if s50[i] is not None and s200[i] is not None and s50[i] > s200[i]:
            m["50gt200"] |= b
        if r2[i] is not None:
            if r2[i] < 5:
                m["rsi2lt5"] |= b
            if r2[i] < 10:
                m["rsi2lt10"] |= b
        if down[i] >= 3:
            m["down3"] |= b
        if i >= 5 and c[i - 5] > 0 and ci / c[i - 5] - 1 <= -0.08:
            m["wk_dn8"] |= b
        if i >= 1 and c[i - 1] > 0 and ci / c[i - 1] - 1 <= -0.05:
            m["day_dn5"] |= b
        if hi20[i] is not None and ci >= hi20[i]:
            m["brk20"] |= b
        if hi252[i] is not None and ci >= 0.98 * hi252[i]:
            m["near52"] |= b
        if i >= 63 and c[i - 63] > 0:
            mom = ci / c[i - 63] - 1
            if mom > 0.25:
                m["mom25"] |= b
            if mom > 0.50:
                m["mom50"] |= b
        if r14[i] is not None and 55 <= r14[i] <= 70:
            m["rsi14band"] |= b
        if (rng10[i] is not None and avgrng[i] is not None and avgrng[i] > 0
                and rng10[i] < 0.40 * avgrng[i] and hi20[i] is not None and ci >= hi20[i]):
            m["squeeze"] |= b
        if s20[i] is not None:
            if ci < s20[i]:
                m["belowma20"] |= b
            else:
                m["abovema20"] |= b
        if hi252[i] is not None and ci >= 0.90 * hi252[i]:
            m["near52w10"] |= b
    m["any"] = (1 << n) - 1
    return m


def _indices(mask):
    out = []
    while mask:
        lsb = mask & -mask
        out.append(lsb.bit_length() - 1)
        mask ^= lsb
    return out


def _exit_index(exit_key, closes, r2, i):
    """Exit bar for an entry at closes[i] under the named exit rule."""
    n = len(closes)
    entry = closes[i]
    if exit_key == "green7":
        j = i + 1
        while j < n - 1 and (j - i) < 7 and closes[j] <= closes[j - 1]:
            j += 1
        return min(j, n - 1)
    if exit_key == "rsi65_30":
        for j in range(i + 1, n):
            if (r2[j] is not None and r2[j] > 65) or (j - i) >= 30:
                return j
        return n - 1
    if exit_key == "hold20":
        return min(i + 20, n - 1)
    if exit_key == "tgt5_stop10_10":
        for j in range(i + 1, n):
            if closes[j] >= entry * 1.05 or closes[j] <= entry * 0.90 or (j - i) >= 10:
                return j
        return n - 1
    trail, hold = (0.10, 60) if exit_key == "trail10_60" else (0.15, 120)
    peak = entry
    for j in range(i + 1, n):
        peak = max(peak, closes[j])
        if closes[j] <= peak * (1 - trail) or (j - i) >= hold:
            return j
    return n - 1


# --------------------------------------------------------------------------
# The search
# --------------------------------------------------------------------------

def three_way_split(dated_series):
    """Two calendar cut dates: TRAIN < s1 <= SELECT < s2 <= TEST (50/20/30)."""
    all_dates = sorted({d for dv in dated_series.values() for d, _ in dv})
    n = len(all_dates)
    return all_dates[int(n * 0.50)], all_dates[int(n * 0.70)]


def run_discover(dated_series, cost=LAB_COST_PER_SIDE, top=10, log=print):
    """Mine the full rule grid. Returns the shortlist judged on TEST."""
    s1, s2 = three_way_split(dated_series)
    log(f"[discover] windows: TRAIN < {s1} <= SELECT < {s2} <= TEST")

    # 1. per-symbol features + condition bitmasks (computed once)
    prep = {}
    for sym, dv in dated_series.items():
        if len(dv) < 300:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        f = _features(closes)
        prep[sym] = (dates, closes, f["rsi2"], _masks(f))
    log(f"[discover] features ready for {len(prep)} symbols")

    # 2. entry masks per (trend, setup, extra); trades bucketed per exit
    combos = []
    n_entry = 0
    for tk, tlabel in TRENDS:
        for sk, slabel in SETUPS:
            for ek, elabel in EXTRAS:
                n_entry += 1
                per_exit = {xk: {"train": [], "select": [], "test": []} for xk, _ in EXITS}
                for _sym, (dates, closes, r2, m) in prep.items():
                    em = m[tk] & m[sk] & m[ek]
                    if not em:
                        continue
                    entries = _indices(em)
                    nlast = len(closes) - 1
                    for xk, _ in EXITS:
                        bucket = per_exit[xk]
                        pos = 0
                        for i in entries:
                            if i < pos or i >= nlast or closes[i] <= 0:
                                continue
                            j = _exit_index(xk, closes, r2, i)
                            if j <= i or closes[j] <= 0:
                                continue
                            ret = (closes[j] / closes[i] - 1.0) - 2.0 * cost
                            d = dates[i]
                            key = "train" if d < s1 else ("select" if d < s2 else "test")
                            bucket[key].append(ret)
                            pos = j                    # no overlapping trades
                for xk, xlabel in EXITS:
                    b = per_exit[xk]
                    combos.append({
                        "trend": tk, "setup": sk, "extra": ek, "exit": xk,
                        "rules": f"Buy {slabel}"
                                 + (f" · {tlabel}" if tk != "any" else "")
                                 + (f" · {elabel}" if ek != "any" else "")
                                 + f" · Sell: {xlabel}",
                        "_train": b["train"], "_select": b["select"], "_test": b["test"],
                    })
                if n_entry % 30 == 0:
                    log(f"[discover] {n_entry}/{len(TRENDS)*len(SETUPS)*len(EXTRAS)} "
                        f"entry grids mined ...")

    # 3. rank on TRAIN only (the mining step)
    scored = []
    for cmb in combos:
        tr = _bucket_stats(cmb["_train"])
        if tr["trades"] < MIN_TRAIN_TRADES or tr["avg"] is None or tr["avg"] <= 0:
            continue
        scored.append((tr, cmb))
    scored.sort(key=lambda x: -x[0]["avg"])
    log(f"[discover] {len(combos)} combos mined · {len(scored)} profitable on TRAIN")

    # 4. shortlist must ALSO be profitable on SELECT (absorbs selection bias)
    finalists = []
    for tr, cmb in scored[:SHORTLIST]:
        se = _bucket_stats(cmb["_select"])
        if se["trades"] >= MIN_SELECT_TRADES and se["avg"] is not None and se["avg"] > 0:
            finalists.append((tr, se, cmb))
    log(f"[discover] shortlist {min(len(scored), SHORTLIST)} -> "
        f"{len(finalists)} survived SELECT")

    # 5. the one look at TEST — the only verdict that counts
    results = []
    for tr, se, cmb in finalists:
        te = _bucket_stats(cmb["_test"])
        ok = (te["trades"] >= MIN_TEST_TRADES and te["avg"] is not None
              and te["avg"] > 0 and (te["pf"] or 0) >= 1.1)
        results.append({"rules": cmb["rules"], "trend": cmb["trend"],
                        "setup": cmb["setup"], "extra": cmb["extra"],
                        "exit": cmb["exit"], "train": tr, "select": se, "test": te,
                        "verdict": "VALIDATED" if ok else "FAILED"})
    results.sort(key=lambda r: (r["verdict"] != "VALIDATED",
                                -(r["test"]["avg"] if r["test"]["avg"] is not None else -999)))
    return {"split_train_end": s1, "split_select_end": s2, "cost_per_side": cost,
            "universe": len(prep), "combos_tested": len(combos),
            "train_profitable": len(scored), "results": results[:top]}


# --------------------------------------------------------------------------
# Persistence + report
# --------------------------------------------------------------------------

def results_path() -> Path:
    return config.DATA_DIR / "garuda_lab_discover.json"


def save_results(res: dict, source: str, path: Path | None = None) -> Path:
    from datetime import datetime, timezone, timedelta
    p = path or results_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    ist = datetime.now(timezone(timedelta(hours=5, minutes=30)))
    p.write_text(json.dumps({**res, "source": source,
                             "generated": ist.strftime("%Y-%m-%d %H:%M IST")}, indent=2))
    return p


def load_results(path: Path | None = None):
    p = path or results_path()
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except (OSError, ValueError):
        return None


def format_discover(res: dict, source: str) -> str:
    w = 104
    lines = ["=" * w,
             f"  {config.BOT_NAME} · LAB DISCOVER   (reverse strategy search — "
             f"mined on TRAIN, filtered on SELECT, judged on TEST)",
             f"  Data: {source} · {res['universe']} symbols · "
             f"{res['combos_tested']} rule combos tested · "
             f"{res['train_profitable']} profitable on TRAIN · cost "
             f"{res['cost_per_side']*100:.2f}%/side",
             f"  TRAIN < {res['split_train_end']} <= SELECT < {res['split_select_end']} "
             f"<= TEST (untouched until the final verdict)",
             "=" * w]
    fm = lambda v, s: "—" if v is None else (s % v)  # noqa: E731
    for k, r in enumerate(res["results"], 1):
        a, b, c = r["train"], r["select"], r["test"]
        lines += ["-" * w,
                  f"  #{k} [{r['verdict']}]  {r['rules']}",
                  f"      TRAIN {a['trades']}t {fm(a['win'], '%.0f%%')} "
                  f"{fm(a['avg'], '%+.2f%%')}/t PF {fm(a['pf'], '%.2f')}   ·   "
                  f"SELECT {b['trades']}t {fm(b['avg'], '%+.2f%%')}/t   ·   "
                  f"TEST {c['trades']}t {fm(c['win'], '%.0f%%')} "
                  f"{fm(c['avg'], '%+.2f%%')}/t PF {fm(c['pf'], '%.2f')}"]
    if not res["results"]:
        lines += ["-" * w,
                  "  No combo survived TRAIN + SELECT with enough trades — on this data the",
                  "  grid found no robust edge. That is a finding, not a failure."]
    lines += ["-" * w,
              "  VALIDATED = profitable after costs in ALL THREE windows, including untouched TEST.",
              "  FAILED    = mined brilliantly, died on unseen data — expected for most of a big grid.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB DISCOVER (reverse strategy search)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="long CSV (symbol,date,close) — use the DEEP history file")
    ap.add_argument("--top", type=int, default=10, help="finalists to report (default 10)")
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE,
                    help="per-side cost fraction (default %.4f)" % LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first (it builds the "
                 f"deep-history CSV)")
    long = _load_long(p)
    dated = {s: sorted(dv.items()) for s, dv in long.items()}
    res = run_discover(dated, cost=a.cost, top=a.top)
    print(format_discover(res, p.name))
    out = save_results(res, p.name)
    print(f"\nWrote {out} — the dashboard's LAB tab shows the DISCOVERED section now.")


if __name__ == "__main__":
    main()
