"""Stock-level smart scoring from a Trendlyne *stock* export.

This lets Mayura use MUCH more of your Trendlyne data. Until now the bot ranked
INDUSTRIES and mapped each to a fixed list of representative stocks. If you drop
a per-stock Trendlyne screener export in as the universe file (any CSV with a
symbol + Industry column), Mayura will instead rank the ACTUAL stocks inside each
top industry by a per-stock smart score built from whatever Trendlyne columns
are present:

  • DVM Scores        — Durability / Valuation / Momentum  (Trendlyne's flagship)
  • Checklist Score   — Trendlyne's overall stock-quality checklist
  • Technicals        — RSI, MFI, delivery volume %, multi-timeframe returns
  • Valuation         — PE, Price/Book  (cheaper scores higher)

Every column is optional. Missing ones are skipped and the surviving weights
re-normalised, so a lean export still works and a rich one is used in full.
Nothing here predicts the future — it only ranks the data you exported.
"""

from typing import Optional

from . import config
from .smart import _blend, _high, _low

# Canonical field -> the Trendlyne header names we accept for it (lower-cased,
# whitespace-collapsed). Add aliases freely; matching is forgiving.
_ALIASES: dict[str, tuple[str, ...]] = {
    "durability": ("durability", "durability score", "durability score (d)"),
    "valuation": ("valuation", "valuation score", "valuation score (v)"),
    "momentum": ("momentum", "momentum score", "momentum score (m)"),
    "checklist": ("trendlyne checklist score", "checklist score", "stock score",
                  "trendlyne score", "checklist"),
    "pe": ("pe ttm", "pe", "pe ratio", "p/e", "price to earnings"),
    "pbv": ("price to book ttm", "price to book", "pb", "pbv", "p/b",
            "price to book value"),
    "rsi": ("rsi", "day rsi", "rsi(14)", "rsi 14"),
    "mfi": ("mfi", "mfi(14)", "mfi 14", "money flow index"),
    "delivery": ("delivery volume %", "delivery %", "deliverable %",
                 "delivery percentage", "delivery volume percentage",
                 "delivery qty %"),
    "day_change": ("day change %", "day change%", "1day change %", "change %",
                   "change%"),
    "week_change": ("week change %", "1week change %", "weekly change %"),
    "month_change": ("month change %", "1month change %", "monthly change %"),
    "qtr_change": ("qtr change %", "quarter change %", "3month change %",
                   "3m change %", "quarterly change %"),
    "year_change": ("1yr change %", "year change %", "1year change %",
                    "12month change %", "yearly change %"),
}


def _norm(s: str) -> str:
    return " ".join((s or "").lower().split())


def resolve_columns(fieldnames) -> dict[str, str]:
    """Map each canonical field to the actual CSV header present (if any)."""
    have = {_norm(c): c for c in (fieldnames or [])}
    out: dict[str, str] = {}
    for field, aliases in _ALIASES.items():
        for a in aliases:
            if a in have:
                out[field] = have[a]
                break
    return out


def has_signals(colmap: dict[str, str]) -> bool:
    """True if the CSV carries ANY column we can score a stock on."""
    return bool(colmap)


def _num(value) -> Optional[float]:
    if value is None:
        return None
    value = str(value).replace(",", "").replace("%", "").strip()
    if value in ("", "-", "na", "nan", "none"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _get(row, colmap, field) -> Optional[float]:
    col = colmap.get(field)
    return _num(row.get(col)) if col else None


# --- Breakout watchlist (direct stock list, no Industry column needed) ------
# Aliases for a Trendlyne "early-breakout" stock export (the columns the Easy
# Mode screener produces). Used by load_breakout_watchlist below.
_BREAKOUT_ALIASES: dict[str, tuple[str, ...]] = {
    "symbol": ("nse code", "nsecode", "symbol", "ticker", "tradingsymbol"),
    "name": ("stock", "stock name", "company", "name"),
    "dist52": ("% distance from 52w high", "distance from 52w high",
               "% distance from 52 week high", "away from 52w high",
               "% away from 52 week high"),
    "sma50": ("day sma50", "sma50", "day sma 50", "sma 50"),
    "sma200": ("day sma200", "sma200", "day sma 200", "sma 200"),
    "deliv_month": ("delivery% vol avg month", "delivery % vol avg month",
                    "delivery% volume avg month"),
    "deliv_6m": ("delivery% vol avg 6m", "delivery % vol avg 6m",
                 "delivery% volume avg 6m"),
    "rs_qtr": ("returns vs nifty500 quarter%", "return vs nifty500 quarter%",
               "returns vs nifty500 quarter", "returns vs nifty 500 quarter%"),
    "rs_ind_week": ("returns vs industry week%", "return vs industry week%"),
    "rsi": ("rsi", "day rsi"),
}

_ETF_HINTS = ("ETF", "GSEC", "BENCHMARK", "LIQUIDBEES", "GILT")


def _resolve(fieldnames, aliases) -> dict[str, str]:
    have = {_norm(c): c for c in (fieldnames or [])}
    out = {}
    for field, names in aliases.items():
        for a in names:
            if a in have:
                out[field] = have[a]
                break
    return out


def breakout_score(row, cm: dict[str, str]) -> Optional[float]:
    """0–100 breakout score for one stock from the Trendlyne screener columns.

    Two models (config.BREAKOUT_EARLY_STAGE):
      • EARLY-STAGE (default): reward a FRESH golden cross (SMA50 just above
        SMA200) and DEMOTE already-extended/parabolic trends — catch the move
        as it begins, not after a 3-6x run.
      • Continuation: the older 'buy strength near the 52-week high' model.
    Uses whatever columns are present (graceful degrade)."""
    def g(f):
        c = cm.get(f)
        return _num(row.get(c)) if c else None

    dist = g("dist52")          # % below the 52-week high; smaller = closer
    sma50, sma200 = g("sma50"), g("sma200")
    # SMA50-over-SMA200 gap, in PERCENT. ~0% = a brand-new cross; large = mature.
    gap = ((sma50 - sma200) / sma200 * 100) if (sma50 and sma200 and sma200 > 0) else None
    dm, d6 = g("deliv_month"), g("deliv_6m")
    spike = (dm / d6) if (dm and d6 and d6 > 0) else None   # accumulation ratio
    rsq = g("rs_qtr")           # relative strength vs Nifty500 (quarter)
    rsi = g("rsi")

    if not config.BREAKOUT_EARLY_STAGE:
        # Continuation model — buys stocks already running near their highs.
        return _blend([
            (_low(dist, 0, 25), 0.35),
            (_high(rsq, 0, 80), 0.30),
            (_high(spike, 1.0, 2.5), 0.20),
            (_high(gap, 0, 50), 0.10),
            (_high(rsi, 45, 70), 0.05),
        ])

    # EARLY-STAGE model.
    # 1) Fresh-cross sweet spot: 100 while SMA50 is 0..FRESH_CROSS_MAX_PCT above
    #    SMA200 (just crossed), fading as the trend matures, 0 if no cross yet.
    fresh = config.FRESH_CROSS_MAX_PCT
    if gap is None:
        cross = None
    elif gap < 0:
        cross = 0.0                                   # SMA50 below SMA200: no cross
    elif gap <= fresh:
        cross = 100.0                                 # ⭐ brand-new golden cross
    else:
        cross = max(0.0, 100.0 - (gap - fresh) * 2.0)  # mature/extended -> lower
    # 2) Position vs 52-week high: room to run is good; AT the high = late.
    if dist is None:
        pos = None
    elif dist < 5:
        pos = 50.0                                    # right at the top: late-ish
    elif dist <= 45:
        pos = 100.0                                   # healthy room above the base
    else:
        pos = max(0.0, 100.0 - (dist - 45) * 2.0)     # too deep below high
    return _blend([
        (cross, 0.45),                    # ⭐ FRESH golden cross = early entry
        (_high(spike, 1.0, 2.5), 0.20),   # delivery accumulation starting
        (_high(rsq, 0, 40), 0.20),        # some relative strength (modest)
        (pos, 0.10),                      # not already at the very top
        (_high(rsi, 45, 65), 0.05),       # rising, not yet overbought
    ])


def load_breakout_watchlist(path) -> list[tuple[str, float]]:
    """Load a flat Trendlyne breakout export as [(NSE symbol, score)] ranked
    best-first. Skips rows with no NSE symbol and ETFs/GSec funds. Returns []
    if the file isn't a recognizable breakout export (no symbol + no signals)."""
    import csv
    try:
        with open(path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            cm = _resolve(reader.fieldnames, _BREAKOUT_ALIASES)
            if "symbol" not in cm:
                return []
            signal_fields = {"dist52", "sma50", "rs_qtr", "deliv_month"}
            if not (signal_fields & cm.keys()):
                return []   # no breakout signals -> not this kind of file
            out: list[tuple[str, float]] = []
            seen = set()
            for r in reader:
                sym = (r.get(cm["symbol"]) or "").strip().upper()
                nm = (r.get(cm.get("name", "")) or "").upper()
                if not sym or sym in seen:
                    continue
                if any(h in nm or h in sym for h in _ETF_HINTS):
                    continue   # skip bond ETFs / GSec funds that slip in
                sc = breakout_score(r, cm)
                if sc is None:
                    continue
                seen.add(sym)
                out.append((sym, round(sc, 1)))
    except OSError:
        return []
    out.sort(key=lambda t: t[1], reverse=True)
    return out


def score_row(row, colmap: dict[str, str]) -> Optional[float]:
    """A 0–100 smart score for one stock row, from whatever columns exist.

    Returns None if the row has no usable signal (caller then falls back to a
    liquidity sort / insertion order)."""
    # DVM pillars are already 0–100 in Trendlyne; clamp to be safe.
    dvm = _blend([
        (_high(_get(row, colmap, "durability"), 0, 100), config.SMART_WEIGHTS["durability"]),
        (_high(_get(row, colmap, "valuation"), 0, 100), config.SMART_WEIGHTS["valuation"]),
        (_high(_get(row, colmap, "momentum"), 0, 100), config.SMART_WEIGHTS["momentum"]),
    ])
    checklist = _high(_get(row, colmap, "checklist"), 0, 100)
    technical = _blend([
        (_high(_get(row, colmap, "rsi"), 30, 70), 0.25),
        (_high(_get(row, colmap, "mfi"), 30, 70), 0.15),
        (_high(_get(row, colmap, "delivery"), 20, 70), 0.20),   # real accumulation
        (_high(_get(row, colmap, "week_change"), -5, 10), 0.10),
        (_high(_get(row, colmap, "month_change"), -10, 20), 0.15),
        (_high(_get(row, colmap, "qtr_change"), -10, 40), 0.15),
    ])
    valuation = _blend([
        (_low(_get(row, colmap, "pe"), 10, 70), 0.5),           # cheaper = higher
        (_low(_get(row, colmap, "pbv"), 1, 12), 0.5),
    ])
    # Blend the pillars that are present. DVM (Trendlyne's own composite) leads.
    return _blend([
        (dvm, 0.55),
        (checklist, 0.20),
        (technical, 0.15),
        (valuation, 0.10),
    ])
