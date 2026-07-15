"""LAB EDGES — two edge families from OUTSIDE the momentum/quality pot.

Everything validated so far lives in two families (trend-following and
mean-reversion on price, quality on fundamentals). This exam tests two
edges Garuda has never touched, both with decades of academic evidence and
both computable from data already on the droplet:

  LOWVOL   The low-volatility anomaly. Lottery-ticket preference makes wild
           stocks chronically overpriced and boring stocks underpriced, so a
           basket of the CALMEST names tends to beat the wildest — the
           opposite of intuition. Machinery: monthly rotation, top-20 by
           LOWEST 63-bar realised volatility, equal weight; judged against
           its mirror (top-20 HIGHEST vol) and a plain 189-bar momentum
           baseline on the untouched TEST window.

  LEADLAG  Industry lead-lag (economic-links momentum). News lands on the
           sector GIANT first; the small siblings in the same industry
           reprice with a delay. Signal: an industry leader (largest by
           market cap) ignites +10% over 21 bars — buy the SIBLINGS next
           close, hold 21 bars, costs both sides. Judged per-trade on
           TRAIN / SELECT / untouched TEST vs the siblings' unconditional
           drift (the spread is the edge, not the raw return).

    python3 -m garuda.lab_edges --csv strength_history.csv \
        --lists smallcap_list.csv micro.csv next50_list.csv \
        --mcap marketcap.csv

Caveats, fixed a priori: today's constituents (survivor-flattered both
legs); the leader is chosen by TODAY's market cap (mild hindsight — a
2021 midcap that became today's leader was smaller then). PAPER / research.
"""

import argparse
import csv as _csv
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_discover import three_way_split
from .lab_portfolio import metrics
from .lab_tournament import judge_window_start, window_metrics

VOL_BARS = 63
ROT_TOP = 20
MOM_BARS = 189
LEAD_LOOK = 21          # leader ignition lookback
LEAD_MIN = 0.10         # leader must be up 10%+ over LEAD_LOOK bars
HOLD = 21               # sibling holding period (bars)
MIN_SIBS = 3            # industries smaller than this are skipped


# --------------------------- shared preparation ---------------------------

def prep_prices(dated_series, min_len=260):
    out = {}
    for sym, dv in dated_series.items():
        if len(dv) < min_len:
            continue
        out[sym] = {"dates": [d for d, _ in dv], "closes": [v for _, v in dv],
                    "px": dict(dv)}
    return out


def _vol(closes, i, bars=VOL_BARS):
    if i < bars + 1:
        return None
    rets = [closes[j] / closes[j - 1] - 1.0
            for j in range(i - bars + 1, i + 1) if closes[j - 1] > 0]
    if len(rets) < bars // 2:
        return None
    m = sum(rets) / len(rets)
    return (sum((r - m) ** 2 for r in rets) / len(rets)) ** 0.5


# ------------------------------ LOWVOL exam ------------------------------

def score_lowvol(closes, i):
    v = _vol(closes, i)
    return -v if v is not None else None


def score_highvol(closes, i):
    return _vol(closes, i)


def score_momentum(closes, i):
    if i < MOM_BARS or closes[i - MOM_BARS] <= 0:
        return None
    return closes[i] / closes[i - MOM_BARS] - 1.0


def book_rotate(prep, capital, cost, score_fn, top=ROT_TOP):
    """Generic monthly rotation book: first calendar day seen each month,
    rotate into the top-`top` names by score_fn, equal weight."""
    calendar = sorted({d for p in prep.values() for d in p["px"]})
    dindex = {sym: {d: i for i, d in enumerate(p["dates"])}
              for sym, p in prep.items()}
    cash, held, last, curve = capital, {}, {}, []
    for t, d in enumerate(calendar):
        for sym in held:
            px = prep[sym]["px"].get(d)
            if px and px > 0:
                last[sym] = px
        if t == 0 or d[:7] != calendar[t - 1][:7]:
            ranked = []
            for sym, p in prep.items():
                i = dindex[sym].get(d)
                if i is None:
                    continue
                s = score_fn(p["closes"], i)
                if s is not None:
                    ranked.append((s, sym))
            ranked.sort(reverse=True)
            target = {s for _v, s in ranked[:top]}
            for sym in list(held):
                if sym not in target:
                    px = last.get(sym)
                    if px:
                        cash += held.pop(sym) * px * (1 - cost)
            equity = cash + sum(q * last.get(s, 0) for s, q in held.items())
            per = equity / top if top else 0.0
            for _v, sym in ranked[:top]:
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
    return curve


def run_lowvol(prep, capital, cost, log=print):
    dated = {s: list(zip(p["dates"], p["closes"])) for s, p in prep.items()}
    start = judge_window_start(dated)
    out = {}
    for name, fn in (("LOWVOL", score_lowvol), ("HIGHVOL", score_highvol),
                     ("MOMENTUM", score_momentum)):
        log(f"[edges] rotating {name} ...")
        curve = book_rotate(prep, capital, cost, fn)
        out[name] = {"test": window_metrics(curve, start),
                     "full": metrics(curve, capital)}
    return out, start


# ------------------------------ LEADLAG exam ------------------------------

def load_industries(paths):
    """{industry: [symbols]} from NSE constituent CSVs (Symbol + Industry)."""
    ind = {}
    for p in paths:
        with open(p, newline="", encoding="utf-8-sig") as f:
            for r in _csv.DictReader(f):
                sym = (r.get("Symbol") or r.get("symbol") or "").strip()
                sec = (r.get("Industry") or r.get("industry") or "").strip()
                if sym and sec:
                    ind.setdefault(sec, [])
                    if sym not in ind[sec]:
                        ind[sec].append(sym)
    return ind


def load_mcap(path):
    out = {}
    with open(path, newline="", encoding="utf-8") as f:
        for r in _csv.DictReader(f):
            try:
                out[(r.get("symbol") or "").strip()] = float(r.get("marketcap"))
            except (TypeError, ValueError):
                continue
    return out


def leadlag_trades(prep, industries, mcap, splits,
                   look=LEAD_LOOK, thresh=LEAD_MIN, hold=HOLD,
                   cost=LAB_COST_PER_SIDE, min_sibs=MIN_SIBS):
    """Signal trades AND the unconditional baseline, bucketed per window.
    Returns {window: {"sig": [rets], "base": [rets]}}."""
    s1, s2 = splits
    buckets = {w: {"sig": [], "base": []} for w in ("train", "select", "test")}
    win_of = lambda d: ("train" if d < s1 else            # noqa: E731
                        "select" if d < s2 else "test")
    for sector, syms in industries.items():
        have = [s for s in syms if s in prep and mcap.get(s)]
        if len(have) < min_sibs + 1:
            continue
        leader = max(have, key=lambda s: mcap[s])
        sibs = [s for s in have if s != leader]
        lc = prep[leader]["closes"]
        ld = prep[leader]["dates"]
        # fresh ignition days: condition true today, false yesterday
        fire = []
        for i in range(look + 1, len(lc)):
            if lc[i - look] <= 0 or lc[i - 1 - look] <= 0:
                continue
            now = lc[i] / lc[i - look] - 1.0 >= thresh
            prev = lc[i - 1] / lc[i - 1 - look] - 1.0 >= thresh
            if now and not prev:
                fire.append(ld[i])
        fire_set = set(fire)
        for sym in sibs:
            c, d = prep[sym]["closes"], prep[sym]["dates"]
            idx = {dd: i for i, dd in enumerate(d)}
            n = len(c)
            # baseline: unconditional forward return sampled every `hold` bars
            for i in range(1, n - hold, hold):
                if c[i] > 0 and c[i + hold] > 0:
                    buckets[win_of(d[i])]["base"].append(
                        (c[i + hold] / c[i] - 1.0) - 2 * cost)
            # signal: buy next close after the leader ignites
            pos = 0
            for fd in fire:
                i = idx.get(fd)
                if i is None or i + 1 >= n or i + 1 < pos:
                    continue
                e = i + 1
                x = min(e + hold, n - 1)
                if c[e] <= 0 or c[x] <= 0:
                    continue
                buckets[win_of(d[e])]["sig"].append(
                    (c[x] / c[e] - 1.0) - 2 * cost)
                pos = x
        del fire_set
    return buckets


def _stats(rets):
    if not rets:
        return None
    wins = [r for r in rets if r > 0]
    loss = sum(-r for r in rets if r <= 0)
    return {"n": len(rets), "avg": sum(rets) / len(rets) * 100,
            "win": len(wins) / len(rets) * 100,
            "pf": (sum(wins) / loss) if loss > 0 else float("inf")}


# -------------------------------- report --------------------------------

def format_edges(rot, rot_start, ll):
    w = 100
    lines = ["=" * w,
             "  Garuda · LAB EDGES   (two edge families from outside the "
             "momentum/quality pot)",
             "  Survivor universe + today's-leader hindsight: relative "
             "comparisons honest, absolutes flattered",
             "=" * w,
             f"  LOWVOL — monthly top-{ROT_TOP} rotation by 63-bar realised "
             f"volatility · TEST from {rot_start}",
             f"  {'basket':<12}{'TEST CAGR':>11}{'TEST DD':>9}"
             f"{'full FINAL':>16}{'full CAGR':>11}"]
    for name in ("LOWVOL", "HIGHVOL", "MOMENTUM"):
        st, fm = rot[name]["test"], rot[name]["full"]
        lines.append(
            f"  {name:<12}"
            + (f"{st['cagr_pct']:>+10.1f}%{st['max_dd_pct']:>8.1f}%" if st
               else f"{'—':>11}{'—':>9}")
            + (f"₹{fm['final']:>14,.0f}{fm['cagr_pct']:>+10.1f}%" if fm
               else f"{'—':>16}{'—':>11}"))
    lv, hv = rot["LOWVOL"]["test"], rot["HIGHVOL"]["test"]
    if lv and hv:
        verdict = ("LOWVOL beats HIGHVOL on unseen data — the anomaly is "
                   "alive in our waters" if lv["cagr_pct"] > hv["cagr_pct"]
                   else "no low-vol edge here — wild names paid better "
                        "(momentum regime dominates)")
        lines.append(f"  LOWVOL verdict: {verdict}")
    lines += ["-" * w,
              f"  LEADLAG — industry leader up {LEAD_MIN * 100:.0f}%+ in "
              f"{LEAD_LOOK} bars -> buy the siblings, hold {HOLD} bars "
              "(costs both sides)",
              f"  {'window':<10}{'signal n':>9}{'avg':>8}{'win':>7}{'PF':>7}"
              f"{'baseline avg':>14}{'SPREAD':>9}"]
    for wname in ("train", "select", "test"):
        sig, base = _stats(ll[wname]["sig"]), _stats(ll[wname]["base"])
        if sig and base:
            lines.append(f"  {wname:<10}{sig['n']:>9}{sig['avg']:>+8.2f}"
                         f"{sig['win']:>6.0f}%{sig['pf']:>7.2f}"
                         f"{base['avg']:>+13.2f}%"
                         f"{sig['avg'] - base['avg']:>+9.2f}")
        else:
            lines.append(f"  {wname:<10}{'too thin — nothing to conclude':>40}")
    ts, tb = _stats(ll["test"]["sig"]), _stats(ll["test"]["base"])
    if ts and tb:
        lines.append("  LEADLAG verdict: "
                     + ("siblings DO drift after the giant moves — a real "
                        "spillover edge on unseen data"
                        if ts["avg"] > tb["avg"] and ts["n"] >= 30
                        else "no exploitable spillover after costs — the "
                             "siblings reprice too fast (or too randomly)"))
    lines += ["  Spread = signal minus the siblings' own unconditional drift "
              "— survivorship cancels across the two.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB EDGES")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--lists", nargs="+",
                    default=["smallcap_list.csv", "micro.csv",
                             "next50_list.csv"])
    ap.add_argument("--mcap", default="marketcap.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    prep = prep_prices(dated)
    print(f"[edges] {len(prep)} symbols with history")
    rot, rot_start = run_lowvol(prep, a.capital, a.cost)
    lists = [q for q in a.lists if Path(q).exists()]
    if not lists:
        sys.exit("no constituent lists found for industries")
    industries = load_industries(lists)
    mcap = load_mcap(a.mcap) if Path(a.mcap).exists() else {}
    if not mcap:
        sys.exit(f"{a.mcap} not found — LEADLAG needs market caps for leaders")
    print(f"[edges] {len(industries)} industries · "
          f"{sum(len(v) for v in industries.values())} mapped symbols")
    splits = three_way_split(dated)
    ll = leadlag_trades(prep, industries, mcap, splits, cost=a.cost)
    print(format_edges(rot, rot_start, ll))


if __name__ == "__main__":
    main()
