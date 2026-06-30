"""Pro-grade technical analysis computed from real OHLC bars (not screened).

This is the engine behind Thanikesa (small-cap momentum) and part of Solaimalai.
Everything here is a PURE function over a list of Bar(high, low, close, volume),
so it is fully unit-tested offline; the live OHLC comes from Kite at run time.

What it computes:
  • trend_template()  — Minervini's Stage-2 "trend template" (8 checks)
  • vcp()             — Volatility Contraction Pattern (tightening pullbacks +
                        volume dry-up + price coiled near the pivot)
  • momentum()        — classic price momentum (skip the most recent month)
  • volatility_pct()  — daily-return volatility (low-vol factor; lower = better)
  • relative_strength()— stock vs index performance
  • thanikesa_score() — the composite small-cap momentum score (0–100)

None of these "predict" — they measure structure in the price you give them.
"""

from __future__ import annotations

from statistics import pstdev
from typing import Optional

from .indicators import Bar


def _closes(bars: list[Bar]) -> list[float]:
    return [b.close for b in bars]


def drop_today(bars: list[Bar], today_iso: str) -> list[Bar]:
    """Drop a trailing PARTIAL bar dated today, so morning signals are computed
    on the last SETTLED session (yesterday's close), not today's half-formed
    candle. No-op if the last bar isn't today's."""
    if bars and getattr(bars[-1], "date", "") == today_iso:
        return bars[:-1]
    return bars


def sma(values: list[float], period: int) -> Optional[float]:
    if len(values) < period or period <= 0:
        return None
    return sum(values[-period:]) / period


def _ret(bars: list[Bar], lookback: int) -> Optional[float]:
    """Simple price return over `lookback` bars, as a fraction (0.10 = +10%)."""
    if len(bars) <= lookback or lookback <= 0:
        return None
    old = bars[-1 - lookback].close
    if old <= 0:
        return None
    return bars[-1].close / old - 1.0


# --- Minervini trend template (Stage-2 confirmation) -----------------------
def trend_template(bars: list[Bar]) -> dict:
    """Minervini's 8-point trend template. Returns {score 0..100, met, checks}.

    Needs ~200+ daily bars for the 200-DMA and 52-week range. With less history
    the missing checks simply fail (lower score) rather than crash."""
    closes = _closes(bars)
    c = closes[-1] if closes else None
    s50, s150, s200 = sma(closes, 50), sma(closes, 150), sma(closes, 200)
    # 200-DMA must be trending up: compare to its value ~20 bars ago.
    s200_prev = sma(closes[:-20], 200) if len(closes) > 220 else None
    win = closes[-252:] if len(closes) >= 252 else closes
    hi52 = max(win) if win else None
    lo52 = min(win) if win else None

    checks = {
        "above_150_200": c is not None and s150 is not None and s200 is not None
                          and c > s150 and c > s200,
        "150_above_200": s150 is not None and s200 is not None and s150 > s200,
        "200_rising": s200 is not None and s200_prev is not None and s200 > s200_prev,
        "50_above_150_200": s50 is not None and s150 is not None and s200 is not None
                            and s50 > s150 > s200,
        "above_50": c is not None and s50 is not None and c > s50,
        "30pct_above_low": c is not None and lo52 is not None and lo52 > 0
                           and c >= 1.30 * lo52,
        "within_25pct_high": c is not None and hi52 is not None and hi52 > 0
                             and c >= 0.75 * hi52,
    }
    met = sum(1 for v in checks.values() if v)
    return {"score": round(met / len(checks) * 100, 1), "met": met, "checks": checks}


def is_stage2(bars: list[Bar]) -> bool:
    """A pragmatic Stage-2 gate: the core uptrend checks all pass."""
    ch = trend_template(bars)["checks"]
    return (ch["above_150_200"] and ch["150_above_200"]
            and ch["above_50"] and ch["200_rising"])


# --- Volatility Contraction Pattern (VCP) ----------------------------------
def _max_drawdown_pct(bars: list[Bar]) -> float:
    """Largest peak-to-trough drop within a segment, as a positive fraction."""
    peak = bars[0].high
    worst = 0.0
    for b in bars:
        peak = max(peak, b.high)
        if peak > 0:
            worst = max(worst, (peak - b.low) / peak)
    return worst


def vcp(bars: list[Bar], base: int = 45, segments: int = 3) -> dict:
    """Detect a Volatility Contraction Pattern over the last `base` bars.

    A textbook VCP is a series of pullbacks that get progressively SHALLOWER
    (volatility contracting) on DRYING-UP volume, leaving price coiled just under
    a pivot, ready to break out. We approximate it by splitting the recent base
    into `segments` equal windows and checking that each window's max drawdown is
    tighter than the one before, the latest is tight, price sits near the base
    high, and recent volume is below earlier volume.

    Returns {is_vcp, score 0..100, contractions, tightness, near_pivot, vol_dryup}.
    """
    if len(bars) < base:
        return {"is_vcp": False, "score": 0.0, "contractions": [],
                "tightness": None, "near_pivot": False, "vol_dryup": False}
    window = bars[-base:]
    seg_len = base // segments
    segs = [window[i * seg_len:(i + 1) * seg_len] for i in range(segments)]
    contractions = [round(_max_drawdown_pct(s), 4) for s in segs if s]
    if len(contractions) < 2:
        return {"is_vcp": False, "score": 0.0, "contractions": contractions,
                "tightness": None, "near_pivot": False, "vol_dryup": False}

    # 1) Each contraction tighter than the previous (allow tiny noise).
    decreasing = all(contractions[i] <= contractions[i - 1] + 0.005
                     for i in range(1, len(contractions)))
    # 2) Latest contraction is tight (the coil).
    tightness = contractions[-1]
    tight = tightness <= 0.10           # last pullback within ~10%
    # 3) Price coiled near the base high (ready to break out).
    base_high = max(b.high for b in window)
    c = window[-1].close
    near_pivot = base_high > 0 and (base_high - c) / base_high <= 0.08
    # 4) Volume dry-up: recent third's avg volume below the first third's.
    v_first = [b.volume for b in segs[0] if b.volume]
    v_last = [b.volume for b in segs[-1] if b.volume]
    if v_first and v_last:
        vol_dryup = (sum(v_last) / len(v_last)) < (sum(v_first) / len(v_first))
    else:
        vol_dryup = False               # unknown volume -> don't claim dry-up

    is_vcp = decreasing and tight and near_pivot
    # Score: reward the structure even when not a perfect textbook VCP.
    score = 0.0
    if decreasing:
        score += 35
    if tight:
        score += 25 * max(0.0, 1 - tightness / 0.10)   # tighter -> closer to 25
    if near_pivot:
        score += 25
    if vol_dryup:
        score += 15
    return {"is_vcp": is_vcp, "score": round(min(score, 100.0), 1),
            "contractions": contractions, "tightness": round(tightness, 4),
            "near_pivot": near_pivot, "vol_dryup": vol_dryup}


# --- Factors ----------------------------------------------------------------
def momentum(bars: list[Bar], lookback: int = 126, skip: int = 21) -> Optional[float]:
    """Classic momentum: return over `lookback` bars, EXCLUDING the most recent
    `skip` bars (the '12-1' idea — last month is noisy/mean-reverting). Fraction."""
    if len(bars) <= lookback + skip:
        # fall back to whatever history we have
        return _ret(bars, max(1, len(bars) - 1))
    recent = bars[:-skip] if skip else bars
    return _ret(recent, lookback)


def volatility_pct(bars: list[Bar], period: int = 63) -> Optional[float]:
    """Daily-return volatility over `period` bars (std-dev of returns). LOWER is
    better for the low-vol factor. Returns a fraction (0.02 = 2% daily)."""
    closes = _closes(bars)
    if len(closes) < period + 1:
        if len(closes) < 3:
            return None
        period = len(closes) - 1
    rets = [closes[i] / closes[i - 1] - 1 for i in range(len(closes) - period, len(closes))
            if closes[i - 1] > 0]
    return pstdev(rets) if len(rets) >= 2 else None


def relative_strength(stock: list[Bar], index: list[Bar],
                      lookback: int = 126) -> Optional[float]:
    """Stock return minus index return over `lookback` bars (fraction). >0 means
    the stock is outperforming the market — the relative-strength edge."""
    sr = _ret(stock, min(lookback, len(stock) - 1)) if len(stock) > 1 else None
    ir = _ret(index, min(lookback, len(index) - 1)) if len(index) > 1 else None
    if sr is None or ir is None:
        return None
    return sr - ir


def _scale(value: Optional[float], lo: float, hi: float) -> Optional[float]:
    """Map value in [lo,hi] -> [0,100], clamped. None passes through."""
    if value is None or hi == lo:
        return None
    return max(0.0, min(100.0, (value - lo) / (hi - lo) * 100.0))


def _blend(parts: list[tuple[Optional[float], float]]) -> Optional[float]:
    """Weighted average over the non-None parts (weights re-normalised)."""
    num = den = 0.0
    for val, w in parts:
        if val is not None:
            num += val * w
            den += w
    return (num / den) if den > 0 else None


def levels(bars: list[Bar]) -> tuple[Optional[float], Optional[float], Optional[float]]:
    """(sma50, sma200, % below 52-week high) computed from OHLC — the same
    fields load_watchlist returns from a CSV, so the engine's failed-breakout
    and extension guards work unchanged for OHLC strategies."""
    closes = _closes(bars)
    s50, s200 = sma(closes, 50), sma(closes, 200)
    win = bars[-252:] if len(bars) >= 252 else bars
    hi = max((b.high for b in win), default=None)
    c = closes[-1] if closes else None
    dist = ((hi - c) / hi * 100.0) if (hi and hi > 0 and c is not None) else None
    return s50, s200, dist


def thanikesa_score(bars: list[Bar], index: list[Bar] | None = None) -> Optional[float]:
    """Composite small-cap momentum score (0–100), Minervini-grade:
    Stage-2 trend template + VCP coil + momentum + relative strength.
    Pure technicals from OHLC. Returns None if there isn't enough history."""
    if len(bars) < 50:
        return None
    tt = trend_template(bars)["score"]
    v = vcp(bars)["score"]
    mom = _scale(momentum(bars), 0.0, 0.60)            # 0..+60% -> 0..100
    rs = _scale(relative_strength(bars, index), 0.0, 0.30) if index else None
    base = _blend([
        (tt, 0.40),     # is it a genuine Stage-2 uptrend? (the gate)
        (v, 0.30),      # is it coiled in a VCP, ready to break out?
        (mom, 0.20),    # raw momentum
        (rs, 0.10),     # beating the market
    ])
    # Hard gate: not in a Stage-2 uptrend => heavily demote (momentum needs trend).
    if base is not None and not is_stage2(bars):
        base *= 0.4
    return round(base, 1) if base is not None else None


def _new_high_breakout(bars: list[Bar], lookback: int = 30, recent: int = 3):
    """Livermore 'pivotal point': did today's close break ABOVE the highest high
    of the prior `lookback` bars (excluding the last `recent`)? Returns
    (broke: bool, strength: float) where strength = close/pivot - 1."""
    if len(bars) < lookback + recent + 1:
        return False, 0.0
    prior = bars[-(lookback + recent):-recent]
    pivot = max((b.high for b in prior), default=0.0)
    c = bars[-1].close
    if pivot <= 0:
        return False, 0.0
    return c > pivot, (c / pivot - 1.0)


def _volume_surge(bars: list[Bar], period: int = 50) -> Optional[float]:
    """Latest bar's volume vs its recent average (breakout confirmation — the
    'tape'). 1.0 = average, 2.0 = double. None if volume data is missing."""
    vols = [b.volume for b in bars[-period:] if b.volume]
    if len(vols) < 10 or not bars[-1].volume:
        return None
    avg = sum(vols) / len(vols)
    return (bars[-1].volume / avg) if avg > 0 else None


def livermore_score(bars: list[Bar], index: list[Bar] | None = None) -> Optional[float]:
    """Jesse Livermore breakout-leader score (0–100) — his principles in code:
      • trade WITH the trend  — hard Stage-2 gate (None otherwise; he stood aside)
      • enter at the PIVOTAL POINT — a fresh breakout above a recent pivot high
      • buy LEADERS near their highs — within 15% of the 52-week high
      • confirm with momentum, relative strength and a volume surge (the 'tape')
    Strict by design: returns None for anything not trending or far from a
    breakout, so it trades rarely and only the strongest setups (no overtrading)."""
    if len(bars) < 60:
        return None
    if not is_stage2(bars):                       # only with the trend
        return None
    _, _, dist = levels(bars)
    if dist is None or dist > 15.0:               # must be a leader near its highs
        return None
    broke, strength = _new_high_breakout(bars)    # the pivotal point
    breakout = 100.0 if broke else _scale(strength, -0.06, 0.0)  # at/near the pivot
    prox = _scale(15.0 - dist, 0.0, 15.0)         # closer to highs = stronger leader
    mom = _scale(momentum(bars), 0.0, 0.60)
    rs = _scale(relative_strength(bars, index), 0.0, 0.30) if index else None
    vol = _scale(_volume_surge(bars), 1.0, 2.0)   # 1x..2x average -> 0..100
    base = _blend([
        (breakout, 0.35),   # the breakout itself (pivotal point)
        (prox, 0.20),       # leadership: near the highs
        (mom, 0.20),        # momentum
        (rs, 0.15),         # beating the market
        (vol, 0.10),        # volume confirmation (the tape)
    ])
    return round(base, 1) if base is not None else None


# OHLC scorers (symbol-level, computed from live bars). Each takes
# (stock_bars, index_bars) and returns 0..100 or None.
SCORERS_OHLC = {
    "thanikesa": thanikesa_score,
    "livermore": livermore_score,
}


# --- Quant multi-factor model (Solaimalai) ---------------------------------
def raw_factors(bars: list[Bar], index: list[Bar] | None = None) -> Optional[dict]:
    """Raw (un-normalised) factor values for the AQR-style multi-factor model.
    Higher is better for every factor (low-vol is negated). None if too short."""
    if len(bars) < 50:
        return None
    vol = volatility_pct(bars)
    return {
        "momentum": momentum(bars),                       # 12-1 price momentum
        "lowvol": (-vol if vol is not None else None),    # less vol = higher
        "trend": trend_template(bars)["score"],           # Stage-2 quality 0..100
        "vcp": vcp(bars)["score"],                         # coiled-base 0..100
        "rs": relative_strength(bars, index) if index else None,  # vs market
    }


def composite_zscore(rows: list[dict], weights: dict[str, float]) -> dict[str, float]:
    """Cross-sectional multi-factor compositing — the core 'quant' step.

    rows: [{"symbol":.., "factors": {factor: value|None}}]. For each factor we
    z-score across the whole universe (so factors on different scales combine
    fairly), take a weighted average of the available z-scores, then map every
    stock to a 0..100 PERCENTILE rank (robust to outliers). Returns {symbol: 0..100}.
    """
    import bisect
    from statistics import pstdev

    keys = list(weights)
    stats: dict[str, Optional[tuple[float, float]]] = {}
    for k in keys:
        vals = [r["factors"].get(k) for r in rows if r["factors"].get(k) is not None]
        if len(vals) >= 2:
            mean = sum(vals) / len(vals)
            sd = pstdev(vals)
            stats[k] = (mean, sd) if sd > 0 else None
        else:
            stats[k] = None

    composites: dict[str, float] = {}
    for r in rows:
        num = den = 0.0
        for k in keys:
            st, v = stats[k], r["factors"].get(k)
            if st and v is not None:
                z = (v - st[0]) / st[1]
                num += weights[k] * z
                den += weights[k]
        composites[r["symbol"]] = (num / den) if den > 0 else 0.0

    ordered = sorted(composites.values())
    n = len(ordered)
    return {sym: round(bisect.bisect_right(ordered, c) / n * 100, 1) if n else 0.0
            for sym, c in composites.items()}
