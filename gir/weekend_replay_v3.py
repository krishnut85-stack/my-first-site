#!/usr/bin/env python3
import os, sys, json, time, random, re
from datetime import datetime
sys.path.insert(0, '/home/globalbot')
import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
from news_brain import NewsBrain

DATA_DIR = "/home/globalbot/data"
FILINGS_CACHE = f"{DATA_DIR}/filings_cache.json"
NEWS_CACHE = f"{DATA_DIR}/news_cache.json"
SAMPLE_SIZE = 100
TS = datetime.now().strftime("%Y%m%d_%H%M%S")
OUTPUT_FILE = f"{DATA_DIR}/replay_v3_results_{TS}.jsonl"

def load_universe():
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
        print(f"  universe: {len(universe)} symbols")
    except Exception as e:
        print(f"  universe load failed: {e}")
    return universe

def parse_ts(ts_str):
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
    except Exception:
        return None

def find_matching_news(symbol, filing_ts, news_alerts, window_hours=48):
    if not symbol or not filing_ts:
        return None
    sym_upper = symbol.upper()
    candidates = []
    for alert in news_alerts:
        alert_ts = parse_ts(alert.get('ts', ''))
        if not alert_ts:
            continue
        try:
            delta = abs((alert_ts - filing_ts).total_seconds())
        except TypeError:
            delta = abs((alert_ts.replace(tzinfo=None) - filing_ts.replace(tzinfo=None)).total_seconds())
        if delta > window_hours * 3600:
            continue
        text = (alert.get('title', '') + ' ' + alert.get('summary', '')).upper()
        if re.search(r'\b' + re.escape(sym_upper) + r'\b', text):
            summary_len = len(alert.get('summary', ''))
            if summary_len >= 100:
                candidates.append((alert, summary_len, delta))
    if not candidates:
        return None
    candidates.sort(key=lambda c: (-c[1], c[2]))
    return candidates[0][0]

def main():
    print(f"=== Weekend Replay v3 ===")
    print(f"Output: {OUTPUT_FILE}")
    universe = load_universe()
    if not universe:
        sys.exit(1)
    with open(FILINGS_CACHE) as f:
        filings = json.load(f).get('filings', [])
    with open(NEWS_CACHE) as f:
        alerts = json.load(f).get('alerts', [])
    print(f"  filings: {len(filings)}, alerts: {len(alerts)}")
    matched = []
    for filing in filings:
        sym = (filing.get('symbol') or '').strip().upper()
        if not sym or sym not in universe:
            continue
        filing_ts = parse_ts(filing.get('timestamp', ''))
        if not filing_ts:
            continue
        match = find_matching_news(sym, filing_ts, alerts, window_hours=48)
        if match:
            matched.append({
                'symbol': sym,
                'filing_sentiment': filing.get('sentiment', ''),
                'filing_type': filing.get('type', ''),
                'filing_subject': filing.get('subject', '')[:200],
                'filing_ts': filing_ts.isoformat(),
                'news_title': match.get('title', ''),
                'news_summary': match.get('summary', ''),
                'news_source': match.get('source', ''),
            })
    print(f"  matched: {len(matched)}")
    if len(matched) < 10:
        print(f"FATAL: only {len(matched)} matches")
        sys.exit(1)
    random.seed(42)
    sample = random.sample(matched, min(SAMPLE_SIZE, len(matched)))
    print(f"  sample: {len(sample)}")
    nb = NewsBrain(
        universe_stocks=universe,
        module_name="REPLAY",
        direction_mode="BULLISH",
        min_conviction=60,
        require_cross_sources=1,
        require_sentence_citation=True,
        max_article_age_hours=0,
    )
    print(f"Validating {len(sample)} candidates with REAL Gemini calls...")
    validated = 0
    rejected = 0
    for i, m in enumerate(sample, 1):
        sentiment = (m['filing_sentiment'] or '').upper()
        direction = 'BULLISH' if 'BULL' in sentiment else ('BEARISH' if 'BEAR' in sentiment else 'BULLISH')
        candidate = {
            'symbol': m['symbol'],
            'direction': direction,
            'source': 'FILING_REPLAY',
            'catalyst': m['filing_subject'] or m['news_title'][:200],
            'score': 70,
        }
        news_item = {
            'title': m['news_title'],
            'link': '',
            'summary': m['news_summary'],
            'source_feed': m['news_source'] or 'FILING_REPLAY',
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
                'i': i, 'symbol': m['symbol'], 'direction': direction,
                'filing_type': m['filing_type'],
                'news_title_preview': m['news_title'][:100],
                'news_chars': len(m['news_summary']),
                'verdict': verdict,
                'gemini_seconds': round(elapsed, 2),
            }
            if outcome:
                row['n_candidates'] = len(outcome) if isinstance(outcome, list) else 1
            with open(OUTPUT_FILE, 'a') as f:
                f.write(json.dumps(row) + '\n')
            marker = 'Y' if elapsed > 0.5 else '!'
            print(f"  {marker} [{i:3d}/{len(sample)}] {m['symbol']:15s} {verdict:10s} ({elapsed:5.1f}s)")
        except Exception as e:
            row = {'i': i, 'symbol': m['symbol'], 'verdict': 'ERROR', 'error': str(e)[:200]}
            with open(OUTPUT_FILE, 'a') as f:
                f.write(json.dumps(row) + '\n')
            print(f"  X [{i:3d}/{len(sample)}] {m['symbol']:15s} ERROR: {e}")
    print()
    print(f"Validated: {validated}, Rejected: {rejected}")
    if validated + rejected > 0:
        print(f"Pass rate: {100*validated/(validated+rejected):.1f}%")
    print(f"Output: {OUTPUT_FILE}")

if __name__ == '__main__':
    main()
