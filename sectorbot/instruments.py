"""Map ranked industries to tradeable NSE symbols.

The universe is now DATA, not buried code. It is loaded once, in priority order
(see config): a stock-level `universe.csv` you can export from your data
provider, else the editable `industry_symbols.csv` shipped with the bot, else
the in-code fallback below. This lets you grow/clean the universe via the same
Termius CSV-upload workflow you already use — no code changes.

`universe.csv` may be a full stock export: any CSV with a symbol column
(Symbol / NSE Code / Tradingsymbol / Ticker) and an `Industry` column. If it
also has a liquidity column (Market Cap / Volume / Traded Value / Turnover),
the names in each industry are sorted most-liquid first.

Run `python -m sectorbot universe-check` to audit which symbols are actually
live on Kite and which top industries have no stocks mapped (coverage holes).
"""

import csv
from typing import Optional

from . import config

# In-code fallback (used only if no CSV is present). Kept identical to the
# original curated map so behaviour is unchanged when data files are absent.
INDUSTRY_SYMBOLS: dict[str, list[str]] = {
    "Telecom Cables": ["UNIVCABLES", "PARACABLES"],
    "Wires & Cables": ["POLYCAB", "KEI", "RRKABEL", "HAVELLS"],
    "Heavy Electrical Equipment": ["BHEL", "SIEMENS", "ABB", "CGPOWER"],
    "Other Electrical Equipment/Products": ["THERMAX", "TRIVENI", "VOLTAMP"],
    "Power - Electric Utilities": ["NTPC", "POWERGRID", "TATAPOWER", "JSWENERGY"],
    "Industrial Machinery": ["LMW", "ELGIEQUIP", "TIMKEN", "SKFINDIA"],
    "Compressors & Pumps": ["KIRLOSENG", "KSB", "ELGIEQUIP", "KIRLOSBROS"],
    "Castings & Forgings": ["BHARATFORG", "RAMKRISHNA", "MMFL"],
    "Other Industrial Products": ["AIAENG", "GRINDWELL", "CARBORUNIV"],
    "Aluminium and Aluminium Products": ["HINDALCO", "NATIONALUM"],
    "Copper": ["HINDCOPPER", "VEDL"],
    "Iron & Steel Products": ["TATASTEEL", "JSWSTEEL", "SAIL", "JINDALSTEL"],
    "Computer Hardware": ["HCLTECH", "DIXON", "AMBER"],
    "Electronic Components": ["DIXON", "AMBER", "KAYNES", "SYRMA"],
    "Shipping": ["GESHIP", "SCI", "COCHINSHIP"],
    "Green & Renewable Energy": ["SUZLON", "INOXWIND", "JSWENERGY"],
    "Capital Markets": ["BSE", "ANGELONE", "MCX", "CDSL"],
    "Asset Management Cos.": ["HDFCAMC", "NAM-INDIA", "UTIAMC"],
    "Household Products": ["GODREJCP", "JYOTHYLAB"],
    "Fibres & Plastics": ["SUPREMEIND", "FINPIPE"],
    "Commodity Trading  & Distribution": ["ADANIENT", "REDINGTON"],
    "Other Industrial Goods": ["CUMMINSIND", "INGERRAND"],
    "Containers & Packaging": ["EPL", "TIMETECHNO", "UFLEX"],
}

_SYMBOL_COLS = ("symbol", "nse code", "nsecode", "nse symbol",
                "tradingsymbol", "ticker")
_INDUSTRY_COLS = ("industry",)
_LIQUIDITY_COLS = ("market cap", "mcap", "traded value", "turnover", "volume")

_universe_cache: Optional[dict[str, list[str]]] = None
_source: str = "in-code map"


def _num(value) -> Optional[float]:
    if value is None:
        return None
    value = str(value).replace(",", "").strip()
    if value in ("", "-"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


# Per-stock smart scores from the last stock-level universe load, so reports
# (and the engine) can show WHY a stock ranks where it does. {symbol: 0-100}.
_stock_scores: dict[str, float] = {}
_has_stock_signals: bool = False


def _load_grouped_csv(path) -> Optional[dict[str, list[str]]]:
    """Build industry -> [symbols] from any CSV with a symbol + Industry column.

    Ranking inside each industry, best first:
      1. by a per-stock SMART score, if the export carries DVM / checklist /
         technical columns (Mayura's stock brain — see stocks.py); else
      2. by a liquidity column (Market Cap / Volume / ...), if present; else
      3. by the order they appear in the file.
    Returns None if the file lacks the required symbol + Industry columns.
    """
    from . import stocks
    global _stock_scores, _has_stock_signals
    try:
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames or []
            cols = {(c or "").lower().strip(): c for c in fieldnames}
            sym_col = next((cols[c] for c in _SYMBOL_COLS if c in cols), None)
            ind_col = next((cols[c] for c in _INDUSTRY_COLS if c in cols), None)
            liq_col = next((cols[c] for c in _LIQUIDITY_COLS if c in cols), None)
            if not sym_col or not ind_col:
                return None
            signal_cols = stocks.resolve_columns(fieldnames)
            rows = []
            scores: dict[str, float] = {}
            for r in reader:
                sym = (r.get(sym_col) or "").strip().upper()
                ind = (r.get(ind_col) or "").strip()
                if not (sym and ind):
                    continue
                liq = _num(r.get(liq_col)) if liq_col else None
                sc = stocks.score_row(r, signal_cols) if signal_cols else None
                if sc is not None:
                    scores[sym] = round(sc, 1)
                rows.append((ind, sym, liq, sc))
    except OSError:
        return None

    _stock_scores = scores
    _has_stock_signals = bool(scores)

    grouped: dict[str, list[tuple[str, Optional[float], Optional[float]]]] = {}
    for ind, sym, liq, sc in rows:
        grouped.setdefault(ind, []).append((sym, liq, sc))

    out: dict[str, list[str]] = {}
    for ind, lst in grouped.items():
        if any(sc is not None for _, _, sc in lst):
            # smart score first (None sinks to the bottom)
            lst.sort(key=lambda t: (t[2] is not None, t[2] or 0.0), reverse=True)
        elif any(liq is not None for _, liq, _ in lst):
            lst.sort(key=lambda t: (t[1] is not None, t[1] or 0.0), reverse=True)
        seen, syms = set(), []
        for sym, _liq, _sc in lst:
            if sym not in seen:
                seen.add(sym)
                syms.append(sym)
        out[ind] = syms
    return out or None


def stock_score(symbol: str) -> Optional[float]:
    """The per-stock smart score (0-100) from the loaded stock universe, if any."""
    _universe()  # ensure loaded
    return _stock_scores.get(symbol.strip().upper())


def has_stock_signals() -> bool:
    """True when the active universe came from a stock export with DVM/technical
    columns (so picks are ranked by real per-stock data, not a static list)."""
    _universe()
    return _has_stock_signals


def _build_universe() -> dict[str, list[str]]:
    """Merge the sources so a PARTIAL stock export never shrinks coverage.

    Lowest -> highest priority: in-code map, then industry_symbols.csv, then the
    stock-level universe.csv. Each layer overrides an industry the layer below
    also has, but industries only in a lower layer are KEPT. So you can drop a
    Trendlyne stock export covering just a few industries and the rest still
    trade off the shipped map."""
    global _source, _stock_scores, _has_stock_signals
    _stock_scores, _has_stock_signals = {}, False
    merged: dict[str, list[str]] = {k: list(v) for k, v in INDUSTRY_SYMBOLS.items()}
    _source = "in-code map"
    if config.INDUSTRY_SYMBOLS_CSV.exists():
        loaded = _load_grouped_csv(config.INDUSTRY_SYMBOLS_CSV)
        if loaded:
            merged.update(loaded)
            _source = "industry_symbols.csv"
    if config.UNIVERSE_CSV.exists():
        loaded = _load_grouped_csv(config.UNIVERSE_CSV)  # sets _stock_scores
        if loaded:
            merged.update(loaded)
            _source = "universe.csv"
    return merged


def _universe() -> dict[str, list[str]]:
    global _universe_cache
    if _universe_cache is None:
        _universe_cache = _build_universe()
    return _universe_cache


def reload_universe() -> None:
    """Drop the cache so the next call re-reads the CSVs (used in tests)."""
    global _universe_cache
    _universe_cache = None


def universe_source() -> str:
    """Which source the active universe came from (for reporting)."""
    _universe()
    return _source


def symbols_for(industry_name: str) -> list[str]:
    """Return tradeable symbols for an industry (empty list if unmapped)."""
    return _universe().get(industry_name, [])


def audit_universe(ds=None, top_n: Optional[int] = None) -> dict:
    """Coverage + liveness report for the top-ranked industries.

    For each top industry: how many symbols are mapped, and (if `ds` is given)
    which of them return a valid live price on Kite vs which look dead. Flags
    industries with NO mapped stocks — the bot simply cannot trade those, so
    they are blind spots worth filling in your universe CSV.
    """
    from .screener import top_industries
    inds = top_industries(n=top_n)

    # Gather every unique symbol and price them in ONE batched call, so a live
    # ticker is never falsely flagged 'dead' just because a fast sequence of
    # per-symbol requests tripped Kite's rate limit.
    prices: dict[str, float] = {}
    if ds is not None:
        all_syms: list[str] = []
        for ind in inds:
            for s in symbols_for(ind.name):
                if s not in all_syms:
                    all_syms.append(s)
        prices = _batch_prices(ds, all_syms)

    rows = []
    coverage_holes = []
    for ind in inds:
        syms = symbols_for(ind.name)
        if not syms:
            coverage_holes.append(ind.name)
        checked = ([{"symbol": s, "alive": bool(prices.get(s, 0.0) > 0)}
                    for s in syms] if ds is not None else [])
        rows.append({"industry": ind.name, "mapped": len(syms),
                     "symbols": syms, "checked": checked})
    return {"source": universe_source(), "industries": rows,
            "coverage_holes": coverage_holes}


def _batch_prices(ds, symbols: list[str]) -> dict[str, float]:
    """Price many symbols at once, using ds.last_prices when available (one Kite
    call) and falling back to per-symbol calls otherwise."""
    if not symbols:
        return {}
    batch = getattr(ds, "last_prices", None)
    if callable(batch):
        try:
            return batch(symbols)
        except Exception:  # noqa: BLE001
            pass
    out: dict[str, float] = {}
    for s in symbols:
        try:
            p = ds.last_price(s)
            out[s] = float(p) if p else 0.0
        except Exception:  # noqa: BLE001
            out[s] = 0.0
    return out
