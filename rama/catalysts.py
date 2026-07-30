"""Event / catalyst signals for Indian equities.

This is the legal, India-specific equivalent of the viral dashboard's "checking
insider trades vs Form 4 filings". In the US, insiders file Form 4 with the SEC.
In India the same information is public and filed with the exchanges:

  • SEBI (Prohibition of Insider Trading) & SAST disclosures — promoters and
    designated persons must report their buys/sells. Published by NSE/BSE.
  • NSE / BSE BULK & BLOCK DEALS — large trades (>0.5% of shares / big blocks)
    by named participants, published end-of-day.

Rama turns these into a per-symbol *catalyst score* in [-1, +1]:
  BUY  / ACQUIRE / ACQUISITION / PLEDGE-RELEASE  -> pushes the score UP
  SELL / DISPOSE / DISPOSAL   / PLEDGE-CREATE    -> pushes the score DOWN
The score then (a) tilts the industry ranking (config.CATALYST_WEIGHT) so
insider-accumulated groups rank higher, and (b) feeds the audit gate so Rama
refuses to buy a name that insiders are actively dumping.

INPUT (same drop-in workflow as your daily sector CSV): put a file at
data/catalysts.csv with, at minimum, a symbol column and a signal column:

    Symbol,Signal,Party,Date,Value
    KEI,BUY,Promoter,2026-07-01,12500000
    POLYCAB,ACQUIRE,HDFC MF,2026-06-30,
    SUZLON,SELL,Promoter,2026-06-28,

Column names are matched loosely (Symbol/NSE Code/Ticker; Signal/Type/
Transaction; Party/Client/Name; Date; Value/Qty/Quantity). Rows older than
config.CATALYST_LOOKBACK_DAYS (when a parseable date is present) are ignored.

Live best-effort fetch from NSE/BSE is scaffolded (config.CATALYST_FETCH_LIVE)
but OFF by default — those endpoints are rate-limited and bot-hostile, so the
reliable path is the CSV drop.
"""

import csv
import math
from pathlib import Path

from . import config

# How many "score points" a full +1/-1 catalyst adds to an industry's rank
# score before the CATALYST_WEIGHT multiplier. Industry scores sit in the tens,
# so 20 makes a strong insider signal a meaningful (but not dominating) tilt.
CATALYST_POINTS = 20.0

_BUY_WORDS = ("buy", "acquire", "acquisition", "purchase", "bought",
              "increase", "addition", "pledge-release", "release", "invest")
_SELL_WORDS = ("sell", "sold", "dispose", "disposal", "reduce", "reduction",
               "offload", "pledge-create", "pledge", "exit")

_SYMBOL_COLS = ("symbol", "nse code", "nsecode", "nse symbol", "tradingsymbol",
                "ticker", "security")
_SIGNAL_COLS = ("signal", "type", "transaction", "transaction type", "action",
                "acquisition/disposal", "buy/sell", "deal type")
_DATE_COLS = ("date", "deal date", "disclosure date", "broadcast date")

_cache: dict | None = None
_cache_key: tuple | None = None


def _pick(row: dict, names) -> str | None:
    low = {k.lower().strip(): v for k, v in row.items() if k}
    for n in names:
        if n in low and low[n] not in (None, ""):
            return str(low[n]).strip()
    return None


def _signal_direction(text: str) -> int:
    """+1 for a buy-type signal, -1 for a sell-type, 0 if unclear."""
    t = text.lower()
    # check sell words first so "pledge-create/sell" isn't caught by "buy"
    if any(w in t for w in _SELL_WORDS):
        return -1
    if any(w in t for w in _BUY_WORDS):
        return 1
    return 0


def _within_lookback(date_str: str | None) -> bool:
    """True if the row is recent enough (or has no parseable date)."""
    if not date_str:
        return True  # undated rows are kept (better to include than silently drop)
    from datetime import datetime
    from .data_loader import IST
    for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%d-%b-%Y", "%d %b %Y"):
        try:
            d = datetime.strptime(date_str.strip(), fmt).date()
            break
        except ValueError:
            continue
    else:
        return True  # unparseable -> keep
    today = datetime.now(IST).date()
    return (today - d).days <= config.CATALYST_LOOKBACK_DAYS


def load_catalyst_scores(path=None) -> dict[str, float]:
    """Return {SYMBOL: score in [-1, 1]} from the catalyst CSV.

    The raw per-row signals (+1/-1) are summed per symbol, then squashed with
    tanh so a single filing gives a moderate tilt and many filings saturate
    toward ±1 (diminishing returns — ten insider buys isn't ten times one)."""
    scores, _ = load_catalysts(path)
    return scores


def load_catalysts(path=None) -> tuple[dict[str, float], dict[str, dict]]:
    """Return ({symbol: score}, {symbol: {buys, sells}}) with caching keyed on
    the file's path+mtime so repeated calls in one run are cheap."""
    global _cache, _cache_key
    p = Path(path or config.CATALYST_CSV)
    key = (str(p), p.stat().st_mtime if p.exists() else 0)
    if _cache is not None and _cache_key == key:
        return _cache

    net: dict[str, float] = {}
    meta: dict[str, dict] = {}
    if p.exists():
        with open(p, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                sym = _pick(row, _SYMBOL_COLS)
                sig = _pick(row, _SIGNAL_COLS)
                if not sym or not sig:
                    continue
                if not _within_lookback(_pick(row, _DATE_COLS)):
                    continue
                direction = _signal_direction(sig)
                if direction == 0:
                    continue
                sym = sym.upper()
                net[sym] = net.get(sym, 0.0) + direction
                m = meta.setdefault(sym, {"buys": 0, "sells": 0})
                m["buys" if direction > 0 else "sells"] += 1

    scores = {s: math.tanh(v / 2.0) for s, v in net.items()}
    _cache, _cache_key = (scores, meta), key
    return _cache


def clear_cache() -> None:
    """Reset the memo (used by tests that write temp CSVs)."""
    global _cache, _cache_key
    _cache = _cache_key = None


def apply_catalyst_tilt(industries: list) -> list:
    """Tilt each industry's rank score by the average catalyst score of its
    member symbols, then re-sort. Also stamps `industry.catalyst_score` for the
    report. Returns the (re-sorted) list. No-op if there is no catalyst data."""
    if not config.USE_CATALYST_SIGNAL:
        return industries
    scores = load_catalyst_scores()
    if not scores:
        return industries
    from .instruments import symbols_for
    for ind in industries:
        member_scores = [scores[s] for s in symbols_for(ind.name) if s in scores]
        cs = sum(member_scores) / len(member_scores) if member_scores else 0.0
        ind.catalyst_score = cs
        ind.score += config.CATALYST_WEIGHT * cs * CATALYST_POINTS
    return sorted(industries, key=lambda i: i.score, reverse=True)
