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
