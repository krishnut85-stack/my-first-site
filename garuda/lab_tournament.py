"""LAB TOURNAMENT — five creative challengers fight the champion for seat 10.

The contenders (all close-only, all buildable from the same daily bars):

  CHAKRA    monthly momentum ROTATION: sell everything, buy the top-20 by
            6-month momentum above the 200-DMA, every month. Always invested.
  TRIVENI   CONFLUENCE: trade a stock only when >=2 independent signal
            families fire on it within 5 trading days.
  VIJAYA    HOT HAND: each month, put the whole book on whichever engine
            (crash / 52w-high / breakout+momentum) won the last 3 months.
  EKALAVYA  SELF-LEARNER: per-stock signal fitness — only take a signal on a
            stock where that same signal's PAST resolved trades (on that stock)
            were profitable. Learns each stock's personality, expanding window.
  CONVICTION the champion's signals (crash -8% over 50-DMA) but position size
            scales with panic depth: -8% -> 2%, -16%+ -> up to 5% of equity.

  CHAMPION  the reigning book: crash bounce, flat 2% sizing, 25% trail/180d.

JUDGMENT (fixed before the run): the full history is simulated, but the score
is the TEST WINDOW ONLY — the newest 30% of the calendar. Adaptive contenders
(VIJAYA, EKALAVYA) learn only from their own past by construction, so nothing
peeks ahead. A challenger takes seat 10 only if, on the TEST window, its CAGR
beats the CHAMPION's with max drawdown no worse than 1.25x the champion's.

    python3 -m garuda.lab_tournament --csv strength_history.csv

PAPER / research only. Expect most challengers to lose — that is the point.
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE, _trail_exit
from .lab_discover import _features, _indices, _masks
from .lab_portfolio import metrics

# signal families: key -> (mask expression keys ANDed, trail, hold, base alloc)
FAMILIES = {
    "crash":  (("wk_dn8", "gt50"), 0.25, 180, 0.02),
    "near52": (("near52",), 0.15, 120, 0.02),
    "brkmom": (("brk20", "mom25"), 0.15, 120, 0.02),
    "dip":    (("rsi2lt10", "gt200"), 0.25, 180, 0.02),
}


# --------------------------------------------------------------------------
# Shared prep: per-symbol prices, signal days per family, virtual outcomes
# --------------------------------------------------------------------------

def prepare(dated_series):
    prep = {}
    for sym, dv in dated_series.items():
        if len(dv) < 260:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        m = _masks(_features(closes))
        fam_idx = {}
        for fam, (mkeys, _t, _h, _a) in FAMILIES.items():
            em = m[mkeys[0]]
            for k in mkeys[1:]:
                em &= m[k]
            fam_idx[fam] = _indices(em)
        prep[sym] = {"dates": dates, "closes": closes, "px": dict(dv),
                     "fam_idx": fam_idx}
    return prep


def virtual_trades(prep, cost):
    """Per (sym, family): the signal's own would-be trades [(entry_i, exit_i,
    ret)], with cooldown — the raw material for confluence and self-learning."""
    out = {}
    for sym, p in prep.items():
        closes = p["closes"]
        n = len(closes)
        for fam, (_mk, trail, hold, _a) in FAMILIES.items():
            trades, pos = [], 0
            for i in p["fam_idx"][fam]:
                if i < pos or i >= n - 1 or closes[i] <= 0:
                    continue
                j = _trail_exit(closes, i, trail=trail, max_hold=hold)
                if j <= i or closes[j] <= 0:
                    continue
                trades.append((i, j, (closes[j] / closes[i] - 1) - 2 * cost))
                pos = j
            out[(sym, fam)] = trades
    return out


# --------------------------------------------------------------------------
# The generic signal-book engine (used by TRIVENI / EKALAVYA / CONVICTION /
# CHAMPION and VIJAYA's single-engine legs)
# --------------------------------------------------------------------------

def run_signal_book(prep, families, capital, cost, take=None, alloc=None):
    """Day-loop portfolio. take(sym, fam, i) -> bool gates entries;
    alloc(sym, fam, i, equity) -> rupee budget (default: family base alloc)."""
    sig_by_date = {}
    for sym, p in prep.items():
        for fam in families:
            for i in p["fam_idx"][fam]:
                if i >= len(p["closes"]) - 1:
                    continue
                sig_by_date.setdefault(p["dates"][i], []).append((sym, fam, i))
    calendar = sorted({d for p in prep.values() for d in p["px"]})
    cash, held, last, curve = capital, {}, {}, []
    trades = wins = 0
    for d in calendar:
        sold = set()
        for sym in list(held):
            px = prep[sym]["px"].get(d)
            if px is None or px <= 0:
                continue
            h = held[sym]
            last[sym] = px
            h["bars"] += 1
            h["peak"] = max(h["peak"], px)
            if px <= h["peak"] * (1 - h["trail"]) or h["bars"] >= h["hold"]:
                cash += h["qty"] * px * (1 - cost)
                trades += 1
                wins += px > h["entry"]
                sold.add(sym)
                del held[sym]
        equity = cash + sum(h["qty"] * last.get(s, h["entry"])
                            for s, h in held.items())
        for sym, fam, i in sig_by_date.get(d, []):
            if sym in held or sym in sold:
                continue
            px = prep[sym]["px"].get(d)
            if not px or px <= 0:
                continue
            if take and not take(sym, fam, i):
                continue
            _mk, trail, hold, base = FAMILIES[fam]
            budget = alloc(sym, fam, i, equity) if alloc else base * equity
            budget = min(budget, cash)
            qty = int(budget // (px * (1 + cost)))
            if qty <= 0:
                continue
            cash -= qty * px * (1 + cost)
            held[sym] = {"qty": qty, "peak": px, "bars": 0, "entry": px,
                         "trail": trail, "hold": hold}
            last[sym] = px
        curve.append((d, round(cash + sum(h["qty"] * last.get(s, h["entry"])
                                          for s, h in held.items()), 2)))
    return {"curve": curve, "trades": trades,
            "win": round(wins / trades * 100, 1) if trades else None}


# --------------------------------------------------------------------------
# The contenders
# --------------------------------------------------------------------------

def book_champion(prep, capital, cost):
    return run_signal_book(prep, ["crash"], capital, cost)


def book_conviction(prep, capital, cost):
    """Crash signals, but size scales with panic depth: 2% at -8% up to 5%."""
    def alloc(sym, fam, i, equity):
        c = prep[sym]["closes"]
        depth = -(c[i] / c[i - 5] - 1.0) if c[i - 5] > 0 else 0.08
        frac = min(0.05, 0.02 * (depth / 0.08))
        return frac * equity
    return run_signal_book(prep, ["crash"], capital, cost, alloc=alloc)


def book_triveni(prep, capital, cost, window=5):
    """Confluence: a family signal counts only if ANOTHER family fired on the
    same stock within the last `window` trading bars."""
    def take(sym, fam, i):
        for other, idxs in prep[sym]["fam_idx"].items():
            if other == fam:
                continue
            for j in idxs:
                if 0 <= i - j <= window:
                    return True
        return False
    return run_signal_book(prep, list(FAMILIES), capital, cost, take=take)


def book_ekalavya(prep, vtrades, capital, cost, min_n=2):
    """Self-learner: take a signal only when that family's PAST resolved trades
    on THAT stock (virtual, expanding window) exist and average > 0."""
    def take(sym, fam, i):
        past = [r for (e, x, r) in vtrades.get((sym, fam), []) if x < i]
        return len(past) >= min_n and sum(past) / len(past) > 0
    return run_signal_book(prep, list(FAMILIES), capital, cost, take=take)


def book_vijaya(prep, capital, cost, look=63):
    """Hot hand: three engine curves (crash / near52 / brkmom); at each month
    start, ride the engine with the best trailing `look`-bar return."""
    engines = {k: run_signal_book(prep, [k], capital, cost)["curve"]
               for k in ("crash", "near52", "brkmom")}
    calendar = [d for d, _ in engines["crash"]]
    vals = {k: [v for _, v in cv] for k, cv in engines.items()}
    equity, curve, pick = capital, [], "crash"
    for t, d in enumerate(calendar):
        if t and d[:7] != calendar[t - 1][:7]:            # month boundary
            if t > look:
                pick = max(vals, key=lambda k: vals[k][t - 1] / vals[k][t - 1 - look])
        if t:
            r = vals[pick][t] / vals[pick][t - 1] - 1.0   # ride the pick's day
            equity *= (1.0 + r)
        curve.append((d, round(equity, 2)))
    return {"curve": curve, "trades": None, "win": None, "picked": pick}


def book_chakra(prep, capital, cost, top=20, mom=126):
    """Monthly rotation: first trading day of each month, hold the top-`top`
    stocks by `mom`-bar momentum above the 200-DMA, equal weight."""
    calendar = sorted({d for p in prep.values() for d in p["px"]})
    dindex = {sym: {d: i for i, d in enumerate(p["dates"])}
              for sym, p in prep.items()}
    cash, held, last, curve = capital, {}, {}, []
    for t, d in enumerate(calendar):
        for sym in held:
            px = prep[sym]["px"].get(d)
            if px and px > 0:
                last[sym] = px
        if t == 0 or d[:7] != calendar[t - 1][:7]:        # rebalance day
            ranked = []
            for sym, p in prep.items():
                i = dindex[sym].get(d)
                c = p["closes"]
                if i is None or i < 200 or i < mom or c[i - mom] <= 0:
                    continue
                run = sum(c[i - 199:i + 1])
                if c[i] <= run / 200.0:
                    continue
                ranked.append((c[i] / c[i - mom] - 1.0, sym))
            ranked.sort(reverse=True)
            target = {s for _, s in ranked[:top]}
            for sym in list(held):                        # sell the dropped
                if sym not in target:
                    px = last.get(sym)
                    if px:
                        cash += held.pop(sym) * px * (1 - cost)
            equity = cash + sum(q * last.get(s, 0) for s, q in held.items())
            per = equity / top if top else 0
            for sym in target:
                if sym in held:
                    continue
                px = prep[sym]["px"].get(d)
                if not px or px <= 0:
                    continue
                qty = int(min(per, cash) // (px * (1 + cost)))
                if qty > 0:
                    cash -= qty * px * (1 + cost)
                    held[sym] = qty
                    last[sym] = px
        curve.append((d, round(cash + sum(q * last.get(s, 0)
                                          for s, q in held.items()), 2)))
    return {"curve": curve, "trades": None, "win": None}


# --------------------------------------------------------------------------
# Judgment
# --------------------------------------------------------------------------

def judge_window_start(dated_series, frac=0.30):
    all_dates = sorted({d for dv in dated_series.values() for d, _ in dv})
    return all_dates[int(len(all_dates) * (1 - frac))]


def window_metrics(curve, start):
    seg = [(d, v) for d, v in curve if d >= start]
    if len(seg) < 20:
        return None
    return metrics(seg, capital=seg[0][1])


def format_tournament(rows, start, capital):
    w = 104
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · LAB TOURNAMENT   (five challengers vs the champion — "
             "seat 10 on the line)",
             f"  Scored on the untouched TEST window (from {start}). Ship rule: "
             "beat the CHAMPION's TEST CAGR with",
             "  drawdown <= 1.25x the champion's. Full-period figures shown for "
             "context only.",
             "=" * w,
             f"  {'CONTENDER':<22}{'TEST CAGR':>10}{'TEST DD':>9}"
             f"{'TEST worst yr':>14}{'full FINAL':>14}{'full CAGR':>10}"
             f"{'trades':>8}{'win%':>6}",
             "-" * w]
    for name, sim, wm, fm in rows:
        wy = min(wm["yearly"].values()) if wm and wm["yearly"] else 0.0
        lines.append(
            f"  {name:<22}"
            + (f"{wm['cagr_pct']:>+9.1f}%{wm['max_dd_pct']:>8.1f}%{wy:>+13.1f}%"
               if wm else f"{'—':>10}{'—':>9}{'—':>14}")
            + f"{money(fm['final']):>14}{fm['cagr_pct']:>+9.1f}%"
            + f"{(sim.get('trades') if sim.get('trades') is not None else '—'):>8}"
            + f"{(str(sim['win']) if sim.get('win') is not None else '—'):>6}")
    lines += ["-" * w,
              "  Adaptive books (VIJAYA, EKALAVYA) learn only from their own "
              "past — no lookahead by construction.",
              "  Most challengers SHOULD lose. Whatever survives, survived "
              "honestly.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB TOURNAMENT (seat 10)")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    print(f"[tournament] {len(dated)} symbols · preparing signals ...")
    prep = prepare(dated)
    vt = virtual_trades(prep, a.cost)
    start = judge_window_start(dated)
    entries = [
        ("CHAKRA (rotation)", lambda: book_chakra(prep, a.capital, a.cost)),
        ("TRIVENI (confluence)", lambda: book_triveni(prep, a.capital, a.cost)),
        ("VIJAYA (hot hand)", lambda: book_vijaya(prep, a.capital, a.cost)),
        ("EKALAVYA (learner)", lambda: book_ekalavya(prep, vt, a.capital, a.cost)),
        ("CONVICTION (sizing)", lambda: book_conviction(prep, a.capital, a.cost)),
        ("CHAMPION (crash)", lambda: book_champion(prep, a.capital, a.cost)),
    ]
    rows = []
    for name, fn in entries:
        print(f"[tournament] running {name} ...")
        sim = fn()
        rows.append((name, sim, window_metrics(sim["curve"], start),
                     metrics(sim["curve"], a.capital)))
    print(format_tournament(rows, start, a.capital))


if __name__ == "__main__":
    main()
