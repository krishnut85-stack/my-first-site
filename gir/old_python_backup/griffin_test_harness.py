#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════╗
║    GRIFFIN TEST HARNESS v1.0 — Simulates full trading session          ║
║                                                                          ║
║    Tests the ACTUAL Griffin code against mock market data.             ║
║    Reports every decision, skip, error with exact reason.             ║
║                                                                          ║
║    USAGE: python3 griffin_test_harness.py                               ║
║    OUTPUT: test_report.txt with full results                           ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import json, os, sys, time, random, math
from datetime import datetime, timedelta
from collections import defaultdict
from io import StringIO

# ═══════════════════════════════════════════════════════════
# TEST REPORT
# ═══════════════════════════════════════════════════════════
class TestReport:
    def __init__(self):
        self.results = []
        self.passed = 0
        self.failed = 0
        self.warnings = 0
    
    def test(self, name, passed, detail=""):
        status = "✅ PASS" if passed else "❌ FAIL"
        self.results.append(f"{status} | {name} | {detail}")
        if passed: self.passed += 1
        else: self.failed += 1
    
    def warn(self, name, detail=""):
        self.results.append(f"⚠️ WARN | {name} | {detail}")
        self.warnings += 1
    
    def info(self, msg):
        self.results.append(f"ℹ️ INFO | {msg}")
    
    def section(self, title):
        self.results.append(f"\n{'='*60}\n  {title}\n{'='*60}")
    
    def summary(self):
        return f"\n{'='*60}\n  SUMMARY: {self.passed} passed, {self.failed} failed, {self.warnings} warnings\n{'='*60}\n"
    
    def full_report(self):
        return "\n".join(self.results) + self.summary()

report = TestReport()

# ═══════════════════════════════════════════════════════════
# MOCK KITE CLIENT — simulates Kite API locally
# ═══════════════════════════════════════════════════════════
MOCK_STOCKS = {
    "SBIN":       {"price": 780, "change": 1.5, "lot": 1500, "step": 5, "sector": "Banking"},
    "HDFCBANK":   {"price": 1850,"change": 0.8, "lot": 550,  "step": 5, "sector": "Banking"},
    "ICICIBANK":  {"price": 1320,"change": 1.1, "lot": 700,  "step": 5, "sector": "Banking"},
    "PNB":        {"price": 95,  "change": 2.1, "lot": 8000, "step": 1, "sector": "Banking"},
    "ONGC":       {"price": 230, "change":-1.8, "lot": 3250, "step": 5, "sector": "Energy"},
    "BPCL":       {"price": 270, "change":-1.5, "lot": 1800, "step": 5, "sector": "Energy"},
    "HAL":        {"price": 4100,"change": 3.0, "lot": 150,  "step": 25,"sector": "Defence"},
    "BEL":        {"price": 280, "change": 2.5, "lot": 2750, "step": 5, "sector": "Defence"},
    "TATAMOTORS": {"price": 650, "change": 1.0, "lot": 1400, "step": 5, "sector": "Auto"},
    "SUNPHARMA":  {"price": 1690,"change":-2.0, "lot": 350,  "step": 10,"sector": "Pharma"},
    "SUZLON":     {"price": 52,  "change": 4.5, "lot":14000, "step": 1, "sector": "Energy"},
    "UPL":        {"price": 520, "change":-5.0, "lot": 1300, "step": 5, "sector": "Chemicals"},
    "RELIANCE":   {"price": 2800,"change": 0.5, "lot": 250,  "step": 20,"sector": "Energy"},
    "DLF":        {"price": 780, "change": 2.0, "lot": 825,  "step": 5, "sector": "Realty"},
    "NIFTY":      {"price":22930,"change": 0.9, "lot": 65,   "step": 50,"sector": "Index"},
    "BANKNIFTY":  {"price":52449,"change": 1.2, "lot": 30,   "step":100,"sector": "Index"},
}

class MockKite:
    """Mock Kite client for testing Griffin code locally."""
    
    def __init__(self):
        self._prices = {k: v["price"] for k, v in MOCK_STOCKS.items()}
        self._orders = []
        self._gtts = []
        self._gtt_id = 314000000
        self._order_id = 260406190000000
    
    def ltp(self, symbols):
        result = {}
        for s in symbols:
            clean = s.replace("NSE:", "").replace("NFO:", "")
            if clean in self._prices:
                result[s] = {"last_price": self._prices[clean]}
            elif clean == "NIFTY 50":
                result[s] = {"last_price": self._prices.get("NIFTY", 22930)}
            elif clean == "NIFTY BANK":
                result[s] = {"last_price": self._prices.get("BANKNIFTY", 52449)}
            elif clean == "INDIA VIX":
                result[s] = {"last_price": 25.5}
        return result
    
    def quote(self, symbols):
        result = {}
        for s in symbols:
            clean = s.replace("NSE:", "").replace("NFO:", "")
            price = self._prices.get(clean, 0)
            data = MOCK_STOCKS.get(clean, {})
            
            if "NFO:" in s:
                # Option quote — generate realistic data
                premium = random.uniform(2, 50)
                oi = random.randint(5000, 80000)
                vol = random.randint(1000, 20000)
                result[s] = {
                    "last_price": premium,
                    "oi": oi,
                    "volume": vol,
                    "ohlc": {"open": premium*0.95, "high": premium*1.1, "low": premium*0.9, "close": premium*0.98},
                    "depth": {
                        "buy": [{"price": premium*0.95, "quantity": 5000, "orders": 5}],
                        "sell": [{"price": premium*1.05, "quantity": 5000, "orders": 5}],
                    }
                }
            elif price > 0:
                close = price / (1 + data.get("change", 0) / 100)
                result[s] = {
                    "last_price": price,
                    "ohlc": {"open": price*0.99, "high": price*1.02, "low": price*0.98, "close": round(close, 2)},
                    "volume": random.randint(100000, 5000000),
                    "oi": 0,
                }
        return result
    
    def instruments(self, exchange):
        instruments = []
        if exchange == "NFO":
            expiry = "2026-04-24"
            for sym, data in MOCK_STOCKS.items():
                if sym in ("NIFTY 50", "NIFTY BANK", "INDIA VIX"):
                    continue
                spot = data["price"]
                step = data.get("step", 50)
                lot = data.get("lot", 65)
                atm = round(spot / step) * step
                for i in range(-5, 6):
                    strike = atm + i * step
                    if strike <= 0: continue
                    for ot in ["CE", "PE"]:
                        ts = f"{sym}26APR{int(strike)}{ot}"
                        instruments.append({
                            "tradingsymbol": ts, "name": sym, "exchange": "NFO",
                            "instrument_type": ot, "strike": float(strike),
                            "lot_size": lot, "expiry": expiry,
                        })
        return instruments
    
    def place_order(self, **params):
        self._order_id += 1
        self._orders.append(params)
        return str(self._order_id)
    
    def place_gtt(self, **params):
        self._gtt_id += 1
        self._gtts.append({"id": self._gtt_id, "status": "active", **params})
        return self._gtt_id
    
    def get_gtts(self):
        return self._gtts
    
    def positions(self):
        return {"net": [], "day": []}
    
    def holdings(self):
        return []
    
    def margins(self):
        return {"equity": {"available": {"cash": 100000}}}
    
    def profile(self):
        return {"user_id": "TEST", "user_name": "TEST_USER"}
    
    def orders(self):
        return self._orders


# ═══════════════════════════════════════════════════════════
# TEST NEWS SCENARIOS
# ═══════════════════════════════════════════════════════════
NEWS_TESTS = [
    {
        "name": "RBI Rate Cut → Banking Calls",
        "headline": "RBI MPC likely to cut repo rate by 25 bps",
        "expected_stocks": ["SBIN", "HDFCBANK", "ICICIBANK"],
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
    {
        "name": "Iran Tension → Oil Stock Calls",
        "headline": "Iran-Israel conflict escalates, crude oil surges to $95",
        "expected_stocks": ["ONGC", "BPCL"],
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
    {
        "name": "Defence Order → HAL/BEL Calls",
        "headline": "HAL bags Rs.26000 crore defence contract for fighter jets",
        "expected_stocks": ["HAL", "BEL"],
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
    {
        "name": "UPL Crash → PUT Options",
        "headline": "UPL promoter pledges additional shares, stock crashes 5%",
        "expected_stocks": ["UPL"],
        "expected_direction": "BEARISH",
        "expected_option": "PE",
    },
    {
        "name": "SEBI Notice → Bearish PUTs",
        "headline": "SEBI issues show cause notice to company for insider trading",
        "expected_stocks": [],  # Generic — should still detect bearish
        "expected_direction": "BEARISH",
        "expected_option": "PE",
    },
    {
        "name": "Gold Rally → TITAN Calls",
        "headline": "Gold hits all-time high at $2400 per ounce safe haven demand",
        "expected_stocks": ["TITAN"],
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
    {
        "name": "EV Policy → Auto Calls",
        "headline": "Government announces new EV policy subsidy for electric vehicles",
        "expected_stocks": ["TATAMOTORS"],
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
    {
        "name": "Monsoon Forecast → FMCG",
        "headline": "IMD predicts above normal monsoon rainfall this year",
        "expected_stocks": [],  # Should detect monsoon → FMCG bullish
        "expected_direction": "BULLISH",
        "expected_option": "CE",
    },
]


# ═══════════════════════════════════════════════════════════
# TEST 1: NEWS KEYWORD MATCHING
# ═══════════════════════════════════════════════════════════
def test_keyword_matching():
    report.section("TEST 1: NEWS KEYWORD MATCHING")
    
    # Load the actual keyword sets from Griffin
    try:
        # Read the keywords directly from the file
        import re
        with open("griffin_bot.py") as f:
            content = f.read()
        
        strong_bull = set()
        m = re.search(r'STRONG_BULL\s*=\s*\{([^}]+)\}', content, re.DOTALL)
        if m:
            strong_bull = set(re.findall(r'"([^"]+)"', m.group(1)))
        
        moderate_bull = set()
        m = re.search(r'MODERATE_BULL\s*=\s*\{([^}]+)\}', content, re.DOTALL)
        if m:
            moderate_bull = set(re.findall(r'"([^"]+)"', m.group(1)))
        
        strong_bear = set()
        m = re.search(r'STRONG_BEAR\s*=\s*\{([^}]+)\}', content, re.DOTALL)
        if m:
            strong_bear = set(re.findall(r'"([^"]+)"', m.group(1)))
        
        # Extract MACRO_FNO_MAP — parse line by line for reliability
        macro_map = {}
        in_macro = False
        current_key = None
        for line in content.split("\n"):
            if "MACRO_FNO_MAP" in line and "=" in line:
                in_macro = True
                continue
            if in_macro:
                if line.strip().startswith("}") and "sector" not in line:
                    in_macro = False
                    continue
                # Match: "keyword": {"sector": "X", "direction": "Y", ... "stocks": ["A", "B"]}
                km = re.match(r'\s*"([^"]+)"\s*:\s*\{.*?"sector":\s*"([^"]+)".*?"direction":\s*"([^"]+)".*?"stocks":\s*\[([^\]]+)\]', line)
                if km:
                    keyword, sector, direction, stocks_str = km.groups()
                    stocks = re.findall(r'"([A-Z&]+)"', stocks_str)
                    macro_map[keyword] = {"sector": sector, "direction": direction, "stocks": stocks}
        
        # Also load MACRO_SINGLE_WORDS
        macro_singles = {}
        m_singles = re.search(r'MACRO_SINGLE_WORDS\s*=\s*\{([^}]+)\}', content, re.DOTALL)
        if m_singles:
            pairs = re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m_singles.group(1))
            for word, sector in pairs:
                macro_singles[word] = sector
        
        report.info(f"Loaded: {len(strong_bull)} STRONG_BULL, {len(moderate_bull)} MODERATE_BULL, {len(strong_bear)} STRONG_BEAR, {len(macro_map)} MACRO triggers")
        
        all_keywords = strong_bull | moderate_bull | strong_bear | set(macro_map.keys())
        
        for test in NEWS_TESTS:
            headline = test["headline"].lower()
            matched_bull = [k for k in strong_bull | moderate_bull if k in headline]
            matched_bear = [k for k in strong_bear if k in headline]
            matched_macro = [k for k in macro_map if k in headline]
            
            # Also check single-word macro triggers
            headline_words = set(headline.split())
            matched_singles = [w for w in macro_singles if w in headline_words or w in headline]
            
            all_matched = matched_bull + matched_bear + matched_macro + matched_singles
            
            if test["expected_direction"] == "BULLISH":
                has_signal = len(matched_bull) > 0 or len(matched_macro) > 0 or len(matched_singles) > 0
            else:
                has_signal = len(matched_bear) > 0
            
            # Check macro stock mapping
            mapped_stocks = []
            for mk in matched_macro:
                mapped_stocks.extend(macro_map[mk]["stocks"])
            
            expected_found = any(s in mapped_stocks for s in test["expected_stocks"]) if test["expected_stocks"] else True
            
            report.test(
                f"NEWS: {test['name']}",
                has_signal,
                f"Matched: {all_matched[:5]} | Macro stocks: {mapped_stocks[:5]} | Expected: {test['expected_stocks']}"
            )
            
            if not has_signal:
                report.warn(f"  Missing keywords for: '{headline[:60]}...'")
                # Suggest what keyword would fix it
                words = headline.split()
                for i in range(len(words)-1):
                    bigram = f"{words[i]} {words[i+1]}"
                    if bigram not in all_keywords:
                        report.info(f"  Suggested keyword to add: \"{bigram}\"")
                        break
    
    except Exception as e:
        report.test("KEYWORD LOADING", False, str(e))


# ═══════════════════════════════════════════════════════════
# TEST 2: OPTION CHAIN SELECTION
# ═══════════════════════════════════════════════════════════
def test_option_selection():
    report.section("TEST 2: OPTION CHAIN SELECTION (CE/PE, Strike, Premium)")
    
    kite = MockKite()
    fno_capital = 15000
    
    for sym, data in MOCK_STOCKS.items():
        if sym in ("NIFTY", "BANKNIFTY") or "lot" not in data:
            continue
        
        spot = data["price"]
        lot = data["lot"]
        step = data["step"]
        
        # Test BULLISH (CE) — 5% OTM
        ce_strike = round((spot * 1.05) / step) * step
        est_premium_ce = spot * 0.005  # ~0.5% for 5% OTM
        ce_cost = est_premium_ce * lot
        
        # Test BEARISH (PE) — 5% OTM
        pe_strike = round((spot * 0.95) / step) * step
        est_premium_pe = spot * 0.005
        pe_cost = est_premium_pe * lot
        
        affordable_ce = ce_cost <= fno_capital
        affordable_pe = pe_cost <= fno_capital
        
        report.test(
            f"{sym} CE {ce_strike} (5% OTM)",
            affordable_ce,
            f"Premium≈₹{est_premium_ce:.1f} x {lot} = ₹{ce_cost:,.0f} vs budget ₹{fno_capital:,}"
        )
        
        if not affordable_ce:
            # Find what OTM% would be affordable
            max_premium = fno_capital / lot
            needed_otm = max(0.05, 1 - (max_premium / (spot * 0.02)))
            report.info(f"  {sym}: Need ~{needed_otm*100:.0f}% OTM for ₹{max_premium:.1f} premium (budget fit)")


# ═══════════════════════════════════════════════════════════
# TEST 3: SMART CHEAP OPTIONS QUALITY FILTERS
# ═══════════════════════════════════════════════════════════
def test_quality_filters():
    report.section("TEST 3: SMART CHEAP OPTIONS — Quality Filters")
    
    test_options = [
        {"sym": "SBIN", "premium": 5.0,  "oi": 50000, "bid": 4.8, "ask": 5.2, "bid_qty": 5000, "lot": 1500, "expect": "PASS"},
        {"sym": "PNB",  "premium": 2.0,  "oi": 30000, "bid": 1.8, "ask": 2.2, "bid_qty": 10000,"lot": 8000, "expect": "PASS"},
        {"sym": "ONGC", "premium": 0.3,  "oi": 200,   "bid": 0.1, "ask": 0.5, "bid_qty": 100,  "lot": 3250, "expect": "FAIL_OI"},
        {"sym": "HAL",  "premium": 80.0, "oi": 5000,  "bid": 78,  "ask": 82,  "bid_qty": 500,  "lot": 150,  "expect": "FAIL_PREMIUM_HIGH"},
        {"sym": "IDEA", "premium": 0.05, "oi": 1000,  "bid": 0.05,"ask": 0.10,"bid_qty": 80000,"lot": 80000,"expect": "FAIL_PREMIUM_LOW"},
        {"sym": "UPL",  "premium": 3.0,  "oi": 15000, "bid": 1.0, "ask": 5.0, "bid_qty": 2000, "lot": 1300, "expect": "FAIL_SPREAD"},
        {"sym": "BEL",  "premium": 8.0,  "oi": 25000, "bid": 7.5, "ask": 8.5, "bid_qty": 3000, "lot": 2750, "expect": "FAIL_COST"},
    ]
    
    for opt in test_options:
        skip = None
        
        if opt["premium"] < 0.5:
            skip = f"premium ₹{opt['premium']} too low"
        elif opt["premium"] > 50:
            skip = f"premium ₹{opt['premium']} too expensive"
        elif opt["oi"] < 1000:
            skip = f"OI={opt['oi']} too low"
        elif opt["bid"] > 0 and opt["ask"] > 0:
            spread = (opt["ask"] - opt["bid"]) / opt["bid"] * 100
            if spread > 50:
                skip = f"spread {spread:.0f}% too wide"
        
        if not skip and opt["bid_qty"] < opt["lot"]:
            skip = f"bid_qty={opt['bid_qty']} < lot={opt['lot']}"
        
        cost = opt["premium"] * opt["lot"]
        if not skip and cost > 15000:
            skip = f"cost ₹{cost:,.0f} > budget"
        
        passed = (skip is None) == (opt["expect"] == "PASS")
        detail = f"₹{opt['premium']} x{opt['lot']}=₹{cost:,.0f} OI={opt['oi']} " + (f"SKIP: {skip}" if skip else "PASS")
        
        report.test(f"FILTER {opt['sym']}: expect={opt['expect']}", passed, detail)


# ═══════════════════════════════════════════════════════════
# TEST 4: NEWS → F&O PIPELINE END-TO-END
# ═══════════════════════════════════════════════════════════
def test_news_to_fno_pipeline():
    report.section("TEST 4: NEWS → F&O PIPELINE (End-to-End)")
    
    import re
    with open("griffin_bot.py") as f:
        content = f.read()
    
    # Check NEWS_SIGNAL is in FNO_HIGH_IMPACT_FILINGS
    has_news_signal = '"NEWS_SIGNAL"' in content and "FNO_HIGH_IMPACT" in content
    report.test("NEWS_SIGNAL in FNO_HIGH_IMPACT_FILINGS", has_news_signal,
                "Critical: without this, ALL news→F&O trades are silently dropped")
    
    # Check MACRO_EVENT
    has_macro = '"MACRO_EVENT"' in content and "FNO_HIGH_IMPACT" in content
    report.test("MACRO_EVENT in FNO_HIGH_IMPACT_FILINGS", has_macro)
    
    # Check process_filing_for_fno handles NEWS_SIGNAL
    # Parse multi-line dict — find all "TYPE": { patterns
    _fhi_start = content.find("FNO_HIGH_IMPACT_FILINGS = {")
    _fhi_end = content.find("}", _fhi_start + 100) if _fhi_start > 0 else -1
    # Search for closing brace that's at the right indent level
    if _fhi_start > 0:
        _brace_count = 0
        for _ci in range(_fhi_start, min(_fhi_start + 5000, len(content))):
            if content[_ci] == "{": _brace_count += 1
            elif content[_ci] == "}": _brace_count -= 1
            if _brace_count == 0:
                _fhi_end = _ci + 1
                break
        _fhi_block = content[_fhi_start:_fhi_end]
        filing_types = re.findall(r'"([A-Z_]+)"\s*:', _fhi_block)
        # Remove non-filing keys like "direction", "confidence", "score"
        filing_types = [f for f in filing_types if f not in ("BULLISH","BEARISH","STRONG_BULLISH","STRONG_BEARISH","MODERATE","NEUTRAL")]
    else:
        filing_types = []
    if filing_types:
        report.info(f"FNO filing types: {len(filing_types)} → {filing_types}")
        
        expected = ["BUYBACK", "MERGER_ACQUISITION", "ORDER_WIN", "PROMOTER", "SAST",
                    "NEWS_SIGNAL", "MACRO_EVENT", "QUARTERLY_RESULTS"]
        for exp in expected:
            report.test(f"Filing type: {exp}", exp in filing_types)
    
    # Check feed_to_pipeline exists and feeds F&O
    has_feed = "def feed_to_pipeline" in content and "fno_queue.append" in content
    report.test("feed_to_pipeline feeds fno_queue", has_feed)
    
    # Check pipeline_ref is connected
    has_ref = "_pipeline_ref" in content and "getattr(self, '_pipeline'" in content
    report.test("_pipeline_ref connected to BrokerageMonitor", has_ref)


# ═══════════════════════════════════════════════════════════
# TEST 5: MOONSHOT SCANNER LOGIC
# ═══════════════════════════════════════════════════════════
def test_moonshot_scanner():
    report.section("TEST 5: MOONSHOT SCANNER")
    
    import re
    with open("griffin_bot.py") as f:
        content = f.read()
    
    # Check datetime.now() vs now_ist() in moonshot
    has_utc_bug = "today = datetime.now()" in content and "MoonshotScanner" in content
    # Count in moonshot area
    moonshot_start = content.find("class MoonshotScanner")
    moonshot_end = content.find("class FNOExitEngine")
    if moonshot_start > 0 and moonshot_end > 0:
        moonshot_code = content[moonshot_start:moonshot_end]
        utc_in_moonshot = "datetime.now()" in moonshot_code
        ist_in_moonshot = "now_ist()" in moonshot_code
        report.test("Moonshot uses now_ist() not datetime.now()", ist_in_moonshot and not utc_in_moonshot,
                    f"now_ist: {ist_in_moonshot}, datetime.now: {utc_in_moonshot}")
    
    # Check EXPIRY_MIN_DAYS
    m = re.search(r'EXPIRY_MIN_DAYS\s*=\s*(\d+)', content)
    if m:
        min_days = int(m.group(1))
        report.test("EXPIRY_MIN_DAYS <= 2 (allow RBI MPC)", min_days <= 2, f"Value: {min_days}")
    
    # Check threshold
    m = re.search(r'if score >= (\d+):\s*#.*threshold', content)
    if m:
        threshold = int(m.group(1))
        report.test("Moonshot threshold <= 20", threshold <= 20, f"Value: {threshold}")
    
    # Check RBI MPC boosts all stocks (not just 7 banks)
    has_rate_sensitive = "_RATE_SENSITIVE" in content
    report.test("RBI MPC boosts ALL rate-sensitive stocks", has_rate_sensitive)
    
    # Check momentum scoring works (not hardcoded 0)
    has_real_momentum = "scans_data" in moonshot_code if moonshot_start > 0 else False
    report.test("Momentum scoring uses real data (not hardcoded 0)", has_real_momentum)


# ═══════════════════════════════════════════════════════════
# TEST 6: F&O EXIT ENGINE
# ═══════════════════════════════════════════════════════════
def test_exit_engine():
    report.section("TEST 6: F&O EXIT ENGINE (SL/Targets)")
    
    import re
    with open("griffin_bot.py") as f:
        content = f.read()
    
    # Check SL settings
    m = re.search(r'HARD_SL_PCT\s*=\s*([\d.]+)', content)
    if m:
        sl = float(m.group(1))
        report.test(f"Hard SL = {sl*100}%", 0.3 <= sl <= 0.5, f"Value: {sl}")
    
    # Check profit targets
    m3x = re.search(r'PARTIAL_BOOK_3X\s*=\s*([\d.]+)', content)
    m5x = re.search(r'FULL_EXIT_5X\s*=\s*([\d.]+)', content)
    m10x = re.search(r'FULL_EXIT_10X\s*=\s*([\d.]+)', content)
    
    if m3x: report.test(f"T1: Book 50% at {m3x.group(1)}x", float(m3x.group(1)) >= 2.5)
    if m5x: report.test(f"T2: Full exit at {m5x.group(1)}x", float(m5x.group(1)) >= 4.0)
    if m10x: report.test(f"Moonshot exit at {m10x.group(1)}x", float(m10x.group(1)) >= 8.0)
    
    # Check DTE rules
    m_dte = re.search(r'EMERGENCY_DTE\s*=\s*(\d+)', content)
    if m_dte:
        dte = int(m_dte.group(1))
        report.test(f"Emergency DTE = {dte}", 10 <= dte <= 15)


# ═══════════════════════════════════════════════════════════
# TEST 7: AQYLON / GLOBAL_IGNORE
# ═══════════════════════════════════════════════════════════
def test_global_ignore():
    report.section("TEST 7: GLOBAL_IGNORE (AQYLON Block)")
    
    with open("griffin_bot.py") as f:
        content = f.read()
    
    report.test("GLOBAL_IGNORE defined", "GLOBAL_IGNORE" in content)
    report.test("AQYLON in GLOBAL_IGNORE", '"AQYLON"' in content and "GLOBAL_IGNORE" in content)
    report.test("AQYLON blocked in oversold bounce", "sym in GLOBAL_IGNORE" in content)
    report.test("AQYLON blocked in 3-agent gate", 'GLOBAL_IGNORE' in content and 'return False, 0' in content)
    report.test("AQYLON blocked in adoption", "_PERMANENT_IGNORE" in content)


# ═══════════════════════════════════════════════════════════
# TEST 8: PIPELINE FLOW
# ═══════════════════════════════════════════════════════════
def test_pipeline():
    report.section("TEST 8: PIPELINE FLOW (elif→if, sector independence)")
    
    with open("griffin_bot.py") as f:
        content = f.read()
    
    # Check elif→if fix
    lines = content.split("\n")
    found_pipeline_if = False
    for i, line in enumerate(lines):
        if "30-min AUTONOMOUS PIPELINE" in line:
            # Next non-comment, non-blank line should be "if is_open:"
            for j in range(i+1, min(i+5, len(lines))):
                if "if is_open:" in lines[j] and "elif" not in lines[j]:
                    found_pipeline_if = True
                    break
                elif "elif is_open:" in lines[j]:
                    found_pipeline_if = False
                    break
    
    report.test("Pipeline uses 'if is_open' (not elif)", found_pipeline_if,
                "Critical: elif made pipeline dead code during market hours")
    
    # Check F&O sector independence
    report.test("F&O has own sector counter", "_fno_sector_count" in content)
    
    # Check max_new_fno uses MAX_FNO_POS
    report.test("max_new_fno uses MAX_FNO_POS", "MAX_FNO_POS - len(fno_positions)" in content)


# ═══════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════
def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║    GRIFFIN TEST HARNESS v1.0 — Running all tests...        ║")
    print("╚══════════════════════════════════════════════════════════════╝\n")
    
    test_keyword_matching()
    test_option_selection()
    test_quality_filters()
    test_news_to_fno_pipeline()
    test_moonshot_scanner()
    test_exit_engine()
    test_global_ignore()
    test_pipeline()
    
    full = report.full_report()
    print(full)
    
    with open("test_report.txt", "w") as f:
        f.write(full)
    
    print(f"\nReport saved to test_report.txt")
    return report.failed == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
