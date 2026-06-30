#!/usr/bin/env python3
"""
Weekend Replay v2 — V64 NewsBrain validation test on cached news alerts.

DATA SOURCE: /home/globalbot/data/news_cache.json -> d['alerts']
  - 1000 cached news alerts with title + summary + sentiment
  - Real news the bot saw in past ~38 days
  - Has actual article body (summary field, RSS feed body)

WHAT THIS DOES:
- Filters alerts to those with usable summary (>100 chars)
- Extracts NSE symbol from title using word-boundary regex against universe
- Discards alerts where no symbol can be matched
- Picks 100 random alerts that pass the filter
- For each, calls validate_scout_candidate() with REAL Gemini API call
- Logs each result to JSONL with verdict + reasoning

SAFETY:
- Uses module_name="REPLAY" so cache file is news_brain_scout_cache_REPLAY.json
- Does NOT touch live EQUITY/FNO scout caches
- Does NOT touch gir.py service
- Does NOT call Kite API
"""

import os
import sys
import json
import time
import random
import re
from datetime import datetime

sys.path.insert(0, '/home/globalbot')

import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

try:
    from news_brain import NewsBrain
except ImportError as e:
    print(f"FATAL: cannot import news_brain.py — {e}")
    sys.exit(1)

# ─── Constants ──────────────────────────────────────────────────────────────
DATA_DIR = "/home/globalbot/data"
NEWS_CACHE = f"{DATA_DIR}/news_cache.json"
SAMPLE_SIZE = 100
MIN_SUMMARY_CHARS = 100  # NewsBrain rejects below this anyway

TS = datetime.now().strftime("%Y%m%d_%H%M%S")
OUTPUT_FILE = f"{DATA_DIR}/replay_v2_results_{TS}.jsonl"


def load_universe():
    """Load NSE tradeable symbols from Trendlyne xlsx."""
    universe = set()
    try:
        import openpyxl
        wb = openpyxl.load_workbook(f"{DATA_DIR}/trendlyne_data.xlsx", read_only=True)
        ws = wb.active
        rows = list(ws.iter_rows(values_only=True))
        headers = [str(h).strip() if h else "" for h in rows[0]]
        if "NSE Code" in headers:
            idx = headers.index("NSE Code")
            for row in rows[1:]:
                code = row[idx]
                if code and isinstance(code, str):
                    universe.add(code.strip().upper())
        wb.close()
        print(f"  Trendlyne universe: {len(universe)} symbols")
    except Exception as e:
        print(f"  Trendlyne load failed: {e}")
    return universe


# Hard-coded common company-name -> NSE-symbol map (subset of gir.py NAME_MAP)
NAME_MAP = {
    "TATA CONSULTANCY": "TCS", "HDFC BANK": "HDFCBANK",
    "INFOSYS": "INFY", "RELIANCE INDUSTRIES": "RELIANCE",
    "STATE BANK": "SBIN", "ICICI BANK": "ICICIBANK",
    "AXIS BANK": "AXISBANK", "KOTAK MAHINDRA": "KOTAKBANK",
    "LARSEN": "LT", "BAJAJ FINANCE": "BAJFINANCE",
    "HINDUSTAN UNILEVER": "HINDUNILVR", "TITAN COMPANY": "TITAN",
    "POWER FINANCE": "PFC", "BHARTI AIRTEL": "BHARTIARTL",
    "TATA MOTORS": "TATAMOTORS", "TATA STEEL": "TATASTEEL",
    "TATA POWER": "TATAPOWER", "MARUTI SUZUKI": "MARUTI",
    "SUN PHARMA": "SUNPHARMA", "TECH MAHINDRA": "TECHM",
    "JSW STEEL": "JSWSTEEL", "ADANI PORTS": "ADANIPORTS",
    "ULTRA TECH": "ULTRACEMCO", "POWER GRID": "POWERGRID",
    "COAL INDIA": "COALINDIA", "INDIAN OIL": "IOC",
    "SWAN DEFENCE": "SWANENERGY",  # observed in sample
    "BAJAJ AUTO": "BAJAJ-AUTO", "BAJAJ FINSERV": "BAJAJFINSV",
    "HCL TECHNOLOGIES": "HCLTECH",
}


def extract_symbol(text, universe):
    """Match a NSE symbol in text using word-boundary regex + name map."""
    if not text:
        return None
    text_upper = text.upper()
    # Try exact symbol match first (word boundary)
    for sym in sorted(universe, key=len, reverse=True):  # longest first
        if len(sym) < 3:
            continue
        if re.search(r'\b' + re.escape(sym) + r'\b', text_upper):
            return sym
    # Fall back to name map
    for name, sym in NAME_MAP.items():
        if name in text_upper and sym in universe:
            return sym
    return None


def sentiment_to_direction(sentiment):
    """Convert RSS sentiment to NewsBrain direction."""
    s = (sentiment or "").upper()
    if "BULL" in s:
        return "BULLISH"
    if "BEAR" in s:
        return "BEARISH"
    return "BULLISH"  # default for NEUTRAL — let NewsBrain decide


def load_alerts():
    """Load cached news alerts."""
    if not os.path.exists(NEWS_CACHE):
        print(f"FATAL: {NEWS_CACHE} not found")
        sys.exit(1)
    with open(NEWS_CACHE) as f:
        d = json.load(f)
    alerts = d.get('alerts', [])
    print(f"  news_cache.json alerts: {len(alerts)} total")
    return alerts


def filter_usable(alerts, universe):
    """Keep only alerts with usable summary AND extractable symbol."""
    usable = []
    no_symbol = 0
    short_body = 0
    for a in alerts:
        summary = a.get('summary', '') or ''
        title = a.get('title', '') or ''
        if len(summary.strip()) < MIN_SUMMARY_CHARS:
            short_body += 1
            continue
        sym = extract_symbol(title + " " + summary, universe)
        if not sym:
            no_symbol += 1
            continue
        usable.append({
            **a,
            '_extracted_symbol': sym,
        })
    print(f"  filtered: {len(usable)} usable | rejected: {short_body} short body, {no_symbol} no symbol")
    return usable


def main():
    print(f"=== Weekend Replay v2 — News Alerts ===")
    print(f"Timestamp: {TS}")
    print(f"Output:    {OUTPUT_FILE}")
    print()

    print("Step 1: Loading universe...")
    universe = load_universe()
    if not universe:
        print("FATAL: empty universe")
        sys.exit(1)

    print()
    print("Step 2: Loading news alerts...")
    alerts = load_alerts()

    print()
    print("Step 3: Filtering for usable bodies + extractable symbols...")
    usable = filter_usable(alerts, universe)
    if len(usable) < 10:
        print(f"FATAL: only {len(usable)} usable alerts — too few to test")
        sys.exit(1)

    random.seed(42)
    sample = random.sample(usable, min(SAMPLE_SIZE, len(usable)))
    print(f"  sample: {len(sample)} (random.seed=42)")
    print()

    print("Step 4: Instantiating REPLAY NewsBrain (separate cache)...")
    nb = NewsBrain(
        universe_stocks=universe,
        module_name="REPLAY",
        direction_mode="BULLISH",
        min_conviction=60,
        require_cross_sources=1,
        require_sentence_citation=True,
        max_article_age_hours=0,  # disabled — alerts are weeks old
    )
    print()

    print(f"Step 5: Validating {len(sample)} candidates with real Gemini calls...")
    print(f"  (each call ~0.5-3s, expect ~5-10 min total)")
    print()

    validated = 0
    rejected = 0

    for i, alert in enumerate(sample, 1):
        sym = alert['_extracted_symbol']
        direction = sentiment_to_direction(alert.get('sentiment'))
        title = alert.get('title', '')
        summary = alert.get('summary', '')
        source = alert.get('source', 'NEWS')

        candidate = {
            'symbol': sym,
            'direction': direction,
            'source': 'NEWS',
            'catalyst': title[:200],
            'score': 70,
        }
        news_item = {
            'title': title,
            'link': '',  # forces summary as body
            'summary': summary,
            'source_feed': source,
        }

        try:
            t0 = time.time()
            outcome = nb.validate_scout_candidate(candidate, news_item)
            elapsed = time.time() - t0

            verdict = 'VALIDATED' if outcome else 'REJECTED'
            if verdict == 'VALIDATED':
                validated += 1
            else:
                rejected += 1

            row = {
                'i': i,
                'symbol': sym,
                'direction': direction,
                'source': source,
                'title_preview': title[:100],
                'summary_chars': len(summary),
                'verdict': verdict,
                'n_candidates': len(outcome) if outcome else 0,
                'gemini_seconds': round(elapsed, 2),
            }
            if outcome:
                row['validated_payload'] = outcome[0] if isinstance(outcome, list) else outcome

            with open(OUTPUT_FILE, 'a') as f:
                f.write(json.dumps(row) + '\n')

            print(f"  [{i:3d}/{len(sample)}] {sym:15s} {verdict:10s} ({elapsed:5.1f}s)")

        except Exception as e:
            row = {'i': i, 'symbol': sym, 'verdict': 'ERROR', 'error': str(e)[:200]}
            with open(OUTPUT_FILE, 'a') as f:
                f.write(json.dumps(row) + '\n')
            print(f"  [{i:3d}/{len(sample)}] {sym:15s} ERROR: {e}")

    print()
    print("=" * 60)
    print(f"REPLAY COMPLETE")
    print("=" * 60)
    print(f"Validated:  {validated}")
    print(f"Rejected:   {rejected}")
    if validated + rejected > 0:
        print(f"Pass rate:  {100*validated/(validated+rejected):.1f}%")
    print(f"Full results: {OUTPUT_FILE}")


if __name__ == '__main__':
    main()
