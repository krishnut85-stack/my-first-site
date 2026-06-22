"""Map ranked industries to a few representative NSE symbols tradeable on Kite.

IMPORTANT: this is a small, ILLUSTRATIVE mapping so the paper bot has concrete
tickers to simulate with. It is NOT investment advice and NOT exhaustive. Before
any real use you should replace this with the full Kite instruments dump
(kite.instruments()) and your own filtered universe.
"""

# industry name (as in the CSV) -> list of example NSE trading symbols
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


def symbols_for(industry_name: str) -> list[str]:
    """Return representative symbols for an industry (empty list if unmapped)."""
    return INDUSTRY_SYMBOLS.get(industry_name, [])
