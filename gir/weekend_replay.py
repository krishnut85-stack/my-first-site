#!/usr/bin/env python3
"""
Weekend Replay Script — V64 NewsBrain validation test on cached NSE filings.

WHAT THIS DOES:
- Loads 100 random filings from /home/globalbot/data/filings_cache.json
- Instantiates a separate "REPLAY" NewsBrain instance (module_name="REPLAY")
  so it writes to news_brain_scout_cache_REPLAY.json — NOT touching live cache
- For each filing, builds a scout candidate and calls validate_scout_candidate()
- Each call makes a real Gemini API request (Tier 1 paid plan)
- Logs results to /home/globalbot/data/replay_results_{timestamp}.jsonl
- Prints summary at end

WHAT THIS DOES NOT TOUCH:
- gir.py running service (no impact, runs as separate process)
- Live caches (news_brain_scout_cache_EQUITY.json, news_brain_scout_cache_FNO.json)
- Kite API (no orders placed, no positions modified)
- Any state file gir.py reads
"""

import os
import sys
import json
import time
import random
from datetime import datetime
from pathlib import Path

# Setup paths so we can import news_brain.py from /home/globalbot
sys.path.insert(0, '/home/globalbot')

# Suppress noisy logs to make output readable
import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

# ─── Imports from live news_brain.py ────────────────────────────────────────
try:
    from news_brain import NewsBrain
except ImportError as e:
    print(f"FATAL: cannot import news_brain.py — {e}")
    print("Are you running from /home/globalbot/ directory?")
    sys.exit(1)

# ─── Constants ──────────────────────────────────────────────────────────────
DATA_DIR = "/home/globalbot/data"
FILINGS_CACHE = f"{DATA_DIR}/filings_cache.json"
SAMPLE_SIZE = 100  # Number of filings to replay

TS = datetime.now().strftime("%Y%m%d_%H%M%S")
OUTPUT_FILE = f"{DATA_DIR}/replay_results_{TS}.jsonl"

# ─── Universe (load from same source the live bot uses) ─────────────────────
def load_universe():
    """Load NSE tradeable symbols. Try Trendlyne xlsx first, fallback to filings symbols."""
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
        print(f"  universe loaded from Trendlyne: {len(universe)} symbols")
    except Exception as e:
        print(f"  Trendlyne load failed: {e}")
    return universe


def load_filings(n_sample):
    """Load filings from cache, return random sample."""
    if not os.path.exists(FILINGS_CACHE):
        print(f"FATAL: {FILINGS_CACHE} not found")
        sys.exit(1)
    with open(FILINGS_CACHE) as f:
        data = json.load(f)
    filings = data.get('filings', [])
    print(f"  filings_cache.json: {len(filings)} total filings")
    if not filings:
        print("FATAL: no filings in cache")
        sys.exit(1)
    # Random sample for unbiased test
    random.seed(42)  # reproducible
    sample = random.sample(filings, min(n_sample, len(filings)))
    print(f"  sample size: {len(sample)} (random.seed=42)")
    return sample


def build_candidate(filing):
    """Build a scout candidate dict in the format NewsBrain expects."""
    # Normalize sentiment to direction
    sentiment = (filing.get('sentiment') or '').upper()
    if 'BULL' in sentiment:
        direction = 'BULLISH'
    elif 'BEAR' in sentiment:
        direction = 'BEARISH'
    else:
        direction = 'BULLISH'  # default for filings; NewsBrain will validate or reject

    return {
        'symbol': (filing.get('symbol') or '').strip().upper(),
        'direction': direction,
        'source': 'FILING',
        'catalyst': filing.get('subject', '')[:200],
        'score': 70,  # initial scout score
    }


def build_news_item(filing):
    """Build the news_item dict NewsBrain expects."""
    return {
        'title': filing.get('subject', '')[:120],
        'link': '',  # no URL — forces use of summary as article body
        'summary': filing.get('subject', ''),  # the SEBI filing IS the article
        'source_feed': 'FILING_REPLAY',
    }


# ─── Main ───────────────────────────────────────────────────────────────────
def main():
    print(f"=== Weekend Replay Script ===")
    print(f"Timestamp: {TS}")
    print(f"Output:    {OUTPUT_FILE}")
    print()

    print("Step 1: Loading universe...")
    universe = load_universe()
    if not universe:
        print("FATAL: empty universe, cannot validate symbols")
        sys.exit(1)

    print()
    print("Step 2: Loading filings sample...")
    sample = load_filings(SAMPLE_SIZE)

    print()
    print("Step 3: Instantiating REPLAY NewsBrain (module='REPLAY' — separate cache)...")
    # Use module_name="REPLAY" so cache file is news_brain_scout_cache_REPLAY.json
    # — does not touch live EQUITY/FNO scout caches.
    # Settings mirror EQUITY (the strict end of the spectrum):
    nb = NewsBrain(
        universe_stocks=universe,
        module_name="REPLAY",
        direction_mode="BULLISH",  # filings are mostly bullish-side; this is the equity setting
        min_conviction=60,         # equity threshold
        require_cross_sources=1,   # equity setting
        require_sentence_citation=True,  # equity setting
        max_article_age_hours=0,   # disable age check (cached filings are weeks old)
    )
    print()

    print(f"Step 4: Validating {len(sample)} candidates...")
    print(f"  (each = 1 Gemini call, ~0.5-3s, expect ~5-10 min total)")
    print()

    results = []
    validated_count = 0
    rejected_count = 0
    rejection_reasons = {}

    start_time = time.time()
    for i, filing in enumerate(sample, 1):
        candidate = build_candidate(filing)
        news_item = build_news_item(filing)

        if not candidate['symbol']:
            continue

        # Skip non-NSE since we use NSE universe
        if filing.get('exchange') == 'BSE' and candidate['symbol'] not in universe:
            results.append({
                'i': i,
                'symbol': candidate['symbol'],
                'exchange': filing.get('exchange'),
                'verdict': 'SKIP_NON_NSE',
                'filing_type': filing.get('type'),
            })
            continue

        try:
            t0 = time.time()
            outcome = nb.validate_scout_candidate(candidate, news_item)
            elapsed = time.time() - t0

            verdict = 'VALIDATED' if outcome else 'REJECTED'
            if verdict == 'VALIDATED':
                validated_count += 1
            else:
                rejected_count += 1

            row = {
                'i': i,
                'symbol': candidate['symbol'],
                'direction': candidate['direction'],
                'filing_type': filing.get('type'),
                'urgency': filing.get('urgency'),
                'subject_preview': filing.get('subject', '')[:100],
                'verdict': verdict,
                'n_candidates': len(outcome),
                'gemini_seconds': round(elapsed, 2),
            }
            if outcome:
                row['validated_payload'] = outcome[0] if isinstance(outcome, list) else outcome

            results.append(row)
            print(f"  [{i:3d}/{len(sample)}] {candidate['symbol']:15s} {verdict:10s} ({elapsed:.1f}s)")

        except Exception as e:
            results.append({
                'i': i,
                'symbol': candidate['symbol'],
                'verdict': 'ERROR',
                'error': str(e)[:200],
            })
            print(f"  [{i:3d}/{len(sample)}] {candidate['symbol']:15s} ERROR: {e}")

        # Save incrementally so partial results survive any crash
        with open(OUTPUT_FILE, 'a') as f:
            f.write(json.dumps(results[-1]) + '\n')

    elapsed_total = time.time() - start_time

    # ─── Summary ────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print(f"REPLAY COMPLETE — {elapsed_total:.0f}s ({elapsed_total/60:.1f} min)")
    print("=" * 60)
    print(f"Total processed:   {len(results)}")
    print(f"  Validated:       {validated_count}")
    print(f"  Rejected:        {rejected_count}")
    print(f"  Skipped/Error:   {len(results) - validated_count - rejected_count}")
    if validated_count + rejected_count > 0:
        rate = 100 * validated_count / (validated_count + rejected_count)
        print(f"  Pass rate:       {rate:.1f}% ({validated_count}/{validated_count + rejected_count})")
    print()
    print(f"Full results: {OUTPUT_FILE}")
    print()
    print("To analyze later:")
    print(f"  cat {OUTPUT_FILE} | python3 -c \"")
    print(f"    import sys, json")
    print(f"    rows = [json.loads(l) for l in sys.stdin]")
    print(f"    from collections import Counter")
    print(f"    print('Verdicts:', Counter(r['verdict'] for r in rows))\"")


if __name__ == '__main__':
    main()
