#!/usr/bin/env python3
"""Apr 23, 2026 news-catalyst backtest — 6 real stocks, NewsBrain + Panel."""
import os, sys, time
sys.path.insert(0, "/home/globalbot")
os.chdir("/home/globalbot")

print("="*78)
print("BACKTEST: NewsBrain + Panel on Apr 23, 2026 real news")
print("="*78)

try:
    from news_brain import NewsBrain
    print("[OK] news_brain imported")
except Exception as e:
    print(f"[FAIL] news_brain import: {e}"); sys.exit(1)

try:
    import gir
    print("[OK] gir imported")
except Exception as e:
    print(f"[FAIL] gir import: {e}"); sys.exit(1)

TEST_CASES = [
    {
        "id": "T1_INFY", "symbol": "INFY", "catalyst": "EARNINGS_BEAT",
        "title": "Infosys Q4 Results: Net profit rises 21% YoY to Rs 8,501 crore, revenue up 13.4% to Rs 46,402 cr, dividend announced",
        "body": """Infosys Limited announced Q4 FY26 results after market hours on April 23, 2026.
Net profit increased 20.87% to Rs 8,501 crore in Q4 FY26, compared to Rs 7,033 crore in the year-ago period.
Sequentially, profit rose 27.75%.
Consolidated revenue from operations surged 13.4% to Rs 46,402 crore as against Rs 40,925 crore in the year-ago quarter.
The Board of Directors declared a final dividend. Record date is June 10, 2026 and dividend will be paid on June 25, 2026.""",
        "source": "FILING", "direction": "BULLISH",
    },
    {
        "id": "T2_TRENT", "symbol": "TRENT", "catalyst": "BONUS_DIVIDEND",
        "title": "Trent Q4 Results: PAT Rises 30% YoY to Rs 455 Crore; Announces 1:2 Bonus Issue and Rs 6 Per Share Dividend",
        "body": """Trent Ltd announced Q4 FY26 results with profit after tax rising 30% year-on-year to Rs 455 crore.
The company announced a 1:2 bonus share issue along with a final dividend of Rs 6 per share.
The strong results come amid store expansion strategy driving sales growth.
Margin expansion was seen as expected by analysts.""",
        "source": "FILING", "direction": "BULLISH",
    },
    {
        "id": "T3_OFSS", "symbol": "OFSS", "catalyst": "EARNINGS_BEAT",
        "title": "Oracle Financial Services Software Jumps 5% After Q4 Results; PAT Rises 31% YoY, Declares Rs 400 Per Share Dividend",
        "body": """Oracle Financial Services Software reported Q4 FY26 results with profit after tax rising 31% year-on-year.
The company declared a final dividend of Rs 400 per share for FY26.
Shares jumped over 5% following the announcement.""",
        "source": "FILING", "direction": "BULLISH",
    },
    {
        "id": "T4_AUROPHARMA", "symbol": "AUROPHARMA", "catalyst": "FDA_BREAKOUT",
        "title": "Aurobindo Pharma hits 52-week high on strong volume after positive US FDA inspection",
        "body": """Aurobindo Pharma gained on positive US FDA inspection news and strong Q4 FY26 earnings expectations.
The stock hit a 52-week high breakout on 2.1x average volume.
Institutional participation confirmed with delivery volumes significantly elevated.
US generics revenue visibility improved following the FDA observations and inspection clearances.""",
        "source": "BROKERAGE", "direction": "BULLISH",
    },
    {
        "id": "T5_DATAPATTNS", "symbol": "DATAPATTNS", "catalyst": "SECTOR_MOMENTUM",
        "title": "Data Patterns hits all-time high Rs 4,193 surging 10% on defence sector boom",
        "body": """Data Patterns (India) Ltd shares surged 10 per cent on BSE to hit a new 52-week and all-time high of Rs 4,193.
In past two trading days the stock price has soared 19 per cent while BSE Sensex was down 1 per cent.
The company is a defence and aerospace electronics firm.
FII holdings increased to 12.47%. DII stake rose to 11.68%.
Order book at all-time high Rs 1,868 crore. Defence budget Rs 7.85 lakh crore for FY27.""",
        "source": "NEWS", "direction": "BULLISH",
    },
    {
        "id": "T6_IRMENERGY", "symbol": "IRMENERGY", "catalyst": "VOLUME_SURGE",
        "title": "IRM Energy stock surges 20% in pre-market trading with volume 44x average",
        "body": """IRM Energy Limited stock climbed 20% in pre-market session on April 23, 2026 reaching Rs 252.66.
Stock jumped Rs 42.11 from previous close Rs 210.55 with volume reaching 7.49 million shares (44x average).
IRM Energy is a city gas distribution company based in Ahmedabad.
Operating income grew 77.89% recently.""",
        "source": "MOMENTUM", "direction": "BULLISH",
    },
]

print()
print("[SETUP] Building test NewsBrain (Groups 1+2 config)")
TEST_UNIVERSE = {"INFY", "TRENT", "OFSS", "AUROPHARMA", "DATAPATTNS", "IRMENERGY",
                 "RELIANCE", "TCS", "HDFCBANK", "ICICIBANK", "SBIN", "BHARTIARTL",
                 "KOTAKBANK", "AXISBANK", "LT", "ITC", "HINDUNILVR", "BAJFINANCE",
                 "WIPRO", "MARUTI", "ASIANPAINT", "SUNPHARMA", "TATASTEEL", "ULTRACEMCO",
                 "BPCL", "IOC", "GAIL", "ONGC", "NTPC", "HCLTECH", "TECHM", "TITAN",
                 "ADANIPORTS", "CIPLA", "DRREDDY", "DIVISLAB", "HEROMOTOCO", "BAJAJ-AUTO",
                 "M&M", "TATAMOTORS", "EICHERMOT", "GRASIM", "COALINDIA", "JSWSTEEL",
                 "HINDALCO", "BRITANNIA", "DABUR", "SHRIRAMFIN", "TATACONSUM", "BEL", "HAL"}
try:
    nb = NewsBrain(
        universe_stocks=TEST_UNIVERSE, news_feeds={},
        module_name="BACKTEST", direction_mode="BULLISH_ONLY",
        min_conviction=60, require_cross_sources=1,
        require_sentence_citation=True, max_article_age_hours=0,
    )
    print(f"[OK] NewsBrain ready: universe={len(TEST_UNIVERSE)}")
except Exception as e:
    print(f"[FAIL] NewsBrain init: {e}")
    import traceback; traceback.print_exc(); sys.exit(1)

print()
print("[SETUP] Building ExpertPanel")
try:
    trendlyne = gir.TrendlyneScorer() if hasattr(gir, 'TrendlyneScorer') else None
    sector_rot = None
    try:
        sector_rot = gir.SectorRotation() if hasattr(gir, 'SectorRotation') else None
    except Exception:
        pass
    panel = gir.ExpertPanel(trendlyne, sector_rot, nb)
    print(f"[OK] Panel ready: trendlyne={'yes' if trendlyne else 'no'}")
except Exception as e:
    print(f"[FAIL] Panel init: {e}")
    import traceback; traceback.print_exc(); sys.exit(1)

print()
print("="*78)
print("RUNNING 6 BACKTEST CASES")
print("="*78)

results = []
for tc in TEST_CASES:
    print()
    print("-"*78)
    print(f"TEST {tc['id']}: {tc['symbol']} — {tc['catalyst']}")
    print(f"  Title: {tc['title'][:76]}")
    print("-"*78)

    candidate = {"symbol": tc["symbol"], "direction": tc["direction"],
                 "source": tc["source"], "catalyst": tc["title"][:80]}
    news_item = {"title": tc["title"], "summary": tc["body"], "link": "",
                 "source_feed": "BACKTEST"}

    print(f"[STAGE 1] NewsBrain validation...")
    t0 = time.time()
    try:
        validated = nb.validate_scout_candidate(candidate, news_item)
        elapsed = time.time() - t0
        if validated:
            v = validated[0]
            print(f"  [PASS] validated={v.get('validated')} conv={v.get('score')} "
                  f"conf={v.get('confidence')} dir={v.get('direction')} ({elapsed:.1f}s)")
            print(f"  reasoning: {str(v.get('reasoning', ''))[:200]}")
            news_validated = True; scout_data = v
        else:
            print(f"  [FAIL] NewsBrain rejected (check logs above for reason) ({elapsed:.1f}s)")
            news_validated = False; scout_data = {"validated": False}
    except Exception as e:
        print(f"  [ERROR] {e}")
        import traceback; traceback.print_exc()
        news_validated = False; scout_data = {"validated": False}; elapsed = 0

    print(f"[STAGE 2] Panel scoring...")
    panel_result = None
    try:
        kite = gir.KiteSession.kite() if hasattr(gir, 'KiteSession') else None
        if kite is None:
            print(f"  [SKIP] No Kite session in test context")
        else:
            panel_result = panel.evaluate_equity(kite, tc["symbol"], tc["direction"], scout_data)
            total = panel_result.get("total", 0)
            allow = panel_result.get("allow", False)
            print(f"  [{'PASS' if allow else 'FAIL'}] total={total} allow={allow}")
            for k, v in panel_result.get("components", {}).items():
                print(f"      {k}: {v}")
    except Exception as e:
        print(f"  [ERROR] {e}")

    results.append({"id": tc["id"], "symbol": tc["symbol"], "catalyst": tc["catalyst"],
                    "validated": news_validated, "panel": panel_result})

print()
print("="*78)
print("SUMMARY")
print("="*78)
print(f"{'Test':<18} {'Catalyst':<18} {'Validated':<10} {'Panel':<8} {'Trade':<6}")
print("-"*78)
for r in results:
    p = r.get("panel") or {}
    total = p.get("total", "-"); allow = p.get("allow", False)
    trade = "YES" if (r["validated"] and allow) else "NO"
    print(f"{r['id']:<18} {r['catalyst']:<18} {str(r['validated']):<10} {str(total):<8} {trade:<6}")

print()
print("="*78)
print("DONE")
print("="*78)
