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


def _load_grouped_csv(path) -> Optional[dict[str, list[str]]]:
    """Build industry -> [symbols] from any CSV with a symbol + Industry column.

    Sorts each industry's names by a liquidity column if one is present.
    Returns None if the file lacks the required columns.
    """
    try:
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            cols = {(c or "").lower().strip(): c for c in (reader.fieldnames or [])}
            sym_col = next((cols[c] for c in _SYMBOL_COLS if c in cols), None)
            ind_col = next((cols[c] for c in _INDUSTRY_COLS if c in cols), None)
            liq_col = next((cols[c] for c in _LIQUIDITY_COLS if c in cols), None)
            if not sym_col or not ind_col:
                return None
            rows = []
            for r in reader:
                sym = (r.get(sym_col) or "").strip().upper()
                ind = (r.get(ind_col) or "").strip()
                if sym and ind:
                    rows.append((ind, sym, _num(r.get(liq_col)) if liq_col else None))
    except OSError:
        return None

    grouped: dict[str, list[tuple[str, Optional[float]]]] = {}
    for ind, sym, liq in rows:
        grouped.setdefault(ind, []).append((sym, liq))

    out: dict[str, list[str]] = {}
    for ind, lst in grouped.items():
        if any(liq is not None for _, liq in lst):
            lst.sort(key=lambda t: (t[1] is not None, t[1] or 0.0), reverse=True)
        seen, syms = set(), []
        for sym, _ in lst:
            if sym not in seen:
                seen.add(sym)
                syms.append(sym)
        out[ind] = syms
    return out or None


def _build_universe() -> dict[str, list[str]]:
    global _source
    for path, label in ((config.UNIVERSE_CSV, "universe.csv"),
                        (config.INDUSTRY_SYMBOLS_CSV, "industry_symbols.csv")):
        if path.exists():
            loaded = _load_grouped_csv(path)
            if loaded:
                _source = label
                return loaded
    _source = "in-code map"
    return INDUSTRY_SYMBOLS


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
    rows = []
    coverage_holes = []
    for ind in top_industries(n=top_n):
        syms = symbols_for(ind.name)
        if not syms:
            coverage_holes.append(ind.name)
        checked = []
        if ds is not None:
            for s in syms:
                try:
                    p = ds.last_price(s)
                    ok = bool(p and p > 0)
                except Exception:  # noqa: BLE001
                    ok = False
                checked.append({"symbol": s, "alive": ok})
        rows.append({"industry": ind.name, "mapped": len(syms),
                     "symbols": syms, "checked": checked})
    return {"source": universe_source(), "industries": rows,
            "coverage_holes": coverage_holes}
