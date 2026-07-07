"""LAB MOVERS — the big-move PRECURSOR hunter (be there BEFORE the pop, honestly).

Every evening the gainers list shows stocks that jumped 10-20%. Buying THOSE is
chasing — the move already happened. The only honest version of "catch it
before" is a probability question:

    Which conditions, visible at today's close, make a >= +10% pop over the
    next H days MEANINGFULLY more likely than the baseline chance?

MOVERS measures exactly that. For every bar of every stock it computes a set of
candidate precursor conditions (volatility squeezes, 52-week-high proximity,
momentum ignition, dips-in-uptrends, quiet streaks...) and the LABEL: did the
stock's close gain >= `pop` within the next `horizon` days? Then, per condition:

    HIT%  = P(pop | condition)         LIFT = HIT% / baseline HIT%

and — because a probability edge is worthless if it can't be traded — the
after-cost return of the mechanical trade "buy the condition at close, exit at
the first close >= +pop or after H days".

Same anti-overfitting gauntlet as DISCOVER: measured on TRAIN (oldest 50%),
must repeat on SELECT (middle 20%), judged once on untouched TEST (newest 30%).
VALIDATED = lift >= 1.25 with a real sample in ALL THREE windows AND the trade
is profitable after costs on TEST.

Big single-day movers are mostly NEWS (results, orders, circuits) — price
history cannot see news coming. Expect modest, honest lifts, not crystal balls.

    python3 -m garuda.lab_movers --csv strength_history.csv
    python3 -m garuda.lab_movers --csv strength_history.csv --pop 0.10 --horizon 5

Results: data/garuda_lab_movers.json -> the dashboard LAB tab's MOVERS RADAR,
which also lists the stocks matching validated precursors TODAY (the "before"
list). PAPER / research only.
"""

import argparse
import json
import sys
from pathlib import Path

from . import config
from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_discover import _features, _indices, _masks, three_way_split

MIN_TRAIN_N = 200
MIN_SELECT_N = 60
MIN_TEST_N = 60
MIN_LIFT = 1.25

# Precursor vocabulary: atomic conditions from the DISCOVER mask set, plus
# curated pairs that encode "coiled spring" stories. (key, label, [mask keys])
PRECURSORS = [
    ("squeeze",       "Volatility squeeze breakout",             ["squeeze"]),
    ("near52",        "Within 2% of the 52-week high",           ["near52"]),
    ("brk20",         "Fresh 20-day-high breakout",              ["brk20"]),
    ("mom25",         "3-month momentum > +25%",                 ["mom25"]),
    ("mom50",         "3-month momentum > +50%",                 ["mom50"]),
    ("rsi2lt5",       "RSI-2 < 5 (deep oversold)",               ["rsi2lt5"]),
    ("down3",         "3+ consecutive red closes",               ["down3"]),
    ("day_dn5",       "1-day drop <= -5%",                       ["day_dn5"]),
    ("wk_dn8",        "5-day return <= -8%",                     ["wk_dn8"]),
    ("rsi14band",     "RSI-14 in 55-70 (strong, not stretched)", ["rsi14band"]),
    # coiled-spring pairs
    ("squeeze_52w",   "Squeeze while within 10% of the 52w high", ["squeeze", "near52w10"]),
    ("brk20_mom",     "20-day breakout + momentum > +25%",        ["brk20", "mom25"]),
    ("dip_leader",    "Deep RSI-2 dip on a +25% momentum leader", ["rsi2lt5", "mom25"]),
    ("panic_uptrend", "1-day -5% panic above the 200-DMA",        ["day_dn5", "gt200"]),
    ("down3_leader",  "3 red closes on a +25% momentum leader",   ["down3", "mom25"]),
    ("near52_quiet",  "At the 52w high AND in a squeeze",         ["near52", "squeeze"]),
]


def _event_stats(dates, closes, entry_idx, pop, horizon, cost, s1, s2, out):
    """For each (cooled-down) entry bar: did a close gain >= pop within horizon?
    Also the mechanical trade's after-cost return (exit at first pop close, else
    at the horizon close). Appends (hit, ret) into out[window]."""
    n = len(closes)
    pos = 0
    for i in entry_idx:
        if i < pos or i >= n - 1 or closes[i] <= 0:
            continue
        end = min(i + horizon, n - 1)
        hit, j_exit = 0, end
        for j in range(i + 1, end + 1):
            if closes[j] / closes[i] - 1.0 >= pop:
                hit, j_exit = 1, j
                break
        ret = (closes[j_exit] / closes[i] - 1.0) - 2.0 * cost
        d = dates[i]
        key = "train" if d < s1 else ("select" if d < s2 else "test")
        out[key].append((hit, ret))
        pos = j_exit                       # cooldown: no overlapping event windows


def _window_stats(pairs):
    if not pairs:
        return {"n": 0, "hit": None, "avg": None}
    hits = sum(h for h, _ in pairs)
    rets = [r for _, r in pairs]
    return {"n": len(pairs), "hit": round(hits / len(pairs) * 100, 1),
            "avg": round(sum(rets) / len(rets) * 100, 3)}


def run_movers(dated_series, pop=0.10, horizon=5, cost=LAB_COST_PER_SIDE,
               log=print):
    s1, s2 = three_way_split(dated_series)
    log(f"[movers] pop >= {pop*100:.0f}% within {horizon}d · windows: "
        f"TRAIN < {s1} <= SELECT < {s2} <= TEST")

    prep = {}
    for sym, dv in dated_series.items():
        if len(dv) < 300:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        prep[sym] = (dates, closes, _masks(_features(closes)))
    log(f"[movers] features ready for {len(prep)} symbols")

    # baseline: EVERY bar (same cooldown mechanics) — the chance any random
    # day is followed by a +pop within the horizon
    base = {"train": [], "select": [], "test": []}
    for _sym, (dates, closes, m) in prep.items():
        _event_stats(dates, closes, _indices(m["any"]), pop, horizon, cost, s1, s2, base)
    baseline = {k: _window_stats(v) for k, v in base.items()}
    log(f"[movers] baseline hit%: train {baseline['train']['hit']}% · "
        f"select {baseline['select']['hit']}% · test {baseline['test']['hit']}%")

    results = []
    for key, label, mask_keys in PRECURSORS:
        out = {"train": [], "select": [], "test": []}
        for _sym, (dates, closes, m) in prep.items():
            em = m[mask_keys[0]]
            for mk in mask_keys[1:]:
                em &= m[mk]
            if em:
                _event_stats(dates, closes, _indices(em), pop, horizon, cost,
                             s1, s2, out)
        st = {k: _window_stats(v) for k, v in out.items()}
        lifts = {}
        for k in ("train", "select", "test"):
            b, h = baseline[k]["hit"], st[k]["hit"]
            lifts[k] = round(h / b, 2) if (b and h is not None) else None
        enough = (st["train"]["n"] >= MIN_TRAIN_N and st["select"]["n"] >= MIN_SELECT_N
                  and st["test"]["n"] >= MIN_TEST_N)
        lifted = all(lifts[k] is not None and lifts[k] >= MIN_LIFT
                     for k in ("train", "select", "test"))
        tradeable = st["test"]["avg"] is not None and st["test"]["avg"] > 0
        verdict = ("VALIDATED" if (enough and lifted and tradeable)
                   else "THIN" if not enough else "FAILED")
        results.append({"key": key, "label": label, "masks": mask_keys,
                        "train": st["train"], "select": st["select"],
                        "test": st["test"], "lift": lifts, "verdict": verdict})
    results.sort(key=lambda r: (r["verdict"] != "VALIDATED",
                                -(r["lift"]["test"] or 0)))
    return {"pop": pop, "horizon": horizon, "cost_per_side": cost,
            "split_train_end": s1, "split_select_end": s2,
            "universe": len(prep), "baseline": baseline, "results": results}


# --------------------------------------------------------------------------
# TODAY's radar — which stocks sit on a VALIDATED precursor right now
# --------------------------------------------------------------------------

def scan_today(series_by_sym, validated, max_bars=320):
    """{precursor key: [symbols matching at the LATEST bar]} for the validated
    precursors. Uses each symbol's most recent `max_bars` closes (enough for
    every mask's 252-bar warmup) so it stays cheap to run once per day."""
    if not validated:
        return {}
    out = {v["key"]: [] for v in validated}
    for sym, closes in series_by_sym.items():
        c = closes[-max_bars:]
        if len(c) < 260:
            continue
        m = _masks(_features(c))
        top = 1 << (len(c) - 1)                  # the latest bar's bit
        for v in validated:
            em = m[v["masks"][0]]
            for mk in v["masks"][1:]:
                em &= m[mk]
            if em & top:
                out[v["key"]].append(sym)
    return out


# --------------------------------------------------------------------------
# Persistence + report
# --------------------------------------------------------------------------

def results_path() -> Path:
    return config.DATA_DIR / "garuda_lab_movers.json"


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


def format_movers(res: dict, source: str) -> str:
    w = 100
    b = res["baseline"]
    lines = ["=" * w,
             f"  {config.BOT_NAME} · LAB MOVERS   (big-move precursors — what makes a "
             f"+{res['pop']*100:.0f}% pop in {res['horizon']}d more likely?)",
             f"  Data: {source} · {res['universe']} symbols · baseline hit% "
             f"train {b['train']['hit']}% / select {b['select']['hit']}% / test "
             f"{b['test']['hit']}% · cost {res['cost_per_side']*100:.2f}%/side",
             "=" * w,
             f"  {'PRECURSOR':<42}{'TEST n':>7}{'hit%':>7}{'lift':>6}"
             f"{'avg%/t':>8}{'tr-lift':>8}{'sel-lift':>9}{'VERDICT':>11}",
             "-" * w]
    fm = lambda v, s: "—" if v is None else (s % v)  # noqa: E731
    for r in res["results"]:
        t = r["test"]
        lines.append(f"  {r['label']:<42}{t['n']:>7}{fm(t['hit'], '%.1f'):>7}"
                     f"{fm(r['lift']['test'], '%.2fx'):>6}{fm(t['avg'], '%+.2f'):>8}"
                     f"{fm(r['lift']['train'], '%.2fx'):>8}"
                     f"{fm(r['lift']['select'], '%.2fx'):>9}{r['verdict']:>11}")
    lines += ["-" * w,
              "  LIFT = how many times likelier the pop is vs any random day. VALIDATED needs",
              f"  lift >= {MIN_LIFT}x in ALL THREE windows AND a profitable after-cost trade on TEST.",
              "  Big one-day movers are mostly NEWS — expect honest tilts, not crystal balls.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB MOVERS (big-move precursors)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="long CSV (symbol,date,close) — use the DEEP history file")
    ap.add_argument("--pop", type=float, default=0.10,
                    help="the move to hunt, as a fraction (default 0.10 = +10%%)")
    ap.add_argument("--horizon", type=int, default=5,
                    help="days allowed to reach the pop (default 5)")
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE,
                    help="per-side cost fraction (default %.4f)" % LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first (it builds the "
                 f"deep-history CSV)")
    long = _load_long(p)
    dated = {s: sorted(dv.items()) for s, dv in long.items()}
    res = run_movers(dated, pop=a.pop, horizon=a.horizon, cost=a.cost)
    print(format_movers(res, p.name))
    out = save_results(res, p.name)
    print(f"\nWrote {out} — the dashboard LAB tab's MOVERS RADAR is live now.")


if __name__ == "__main__":
    main()
