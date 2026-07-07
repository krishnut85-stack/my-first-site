#!/bin/bash
# FIX_V40_EQUITY_LLM - independent LLM validation for EquityModule
set -e
cd /home/globalbot

echo "=== FIX_V40_EQUITY_LLM patch ==="
wc -l gir.py

if grep -q "FIX_V40_EQUITY_LLM" gir.py; then
    echo "ABORT: already applied"
    exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v40_${TS}"
cp gir.py "$BACKUP"
echo "Backup: $BACKUP"

python3 <<'PYEOF'
with open("gir.py", "r") as f:
    src = f.read()

PATCHES = []

OLD_1 = '''    def __init__(self):
        self.positions = {}     # symbol -> position dict
        self.gtt = GTTManager("EQUITY")
        self.risk = None        # Initialized after capital is known
        self.telegram = TelegramThrottle("EQUITY", max_per_hour=15)
        self.news = None        # Initialized after symbols are loaded
        self.filings = None     # FilingMonitor
        self.brokerage = None   # BrokerageMonitor
        self.macro = None       # MacroDetector
        self.trendlyne = TrendlyneScorer()
        self.amo = AMOEngine("EQUITY")'''

NEW_1 = '''    def __init__(self):
        self.positions = {}     # symbol -> position dict
        self.gtt = GTTManager("EQUITY")
        self.risk = None        # Initialized after capital is known
        self.telegram = TelegramThrottle("EQUITY", max_per_hour=15)
        self.news = None        # Initialized after symbols are loaded
        self.filings = None     # FilingMonitor
        self.brokerage = None   # BrokerageMonitor
        self.macro = None       # MacroDetector
        self.trendlyne = TrendlyneScorer()
        self.amo = AMOEngine("EQUITY")
        self.news_brain = None  # FIX_V40_EQUITY_LLM'''

PATCHES.append(("EquityModule __init__", OLD_1, NEW_1))

OLD_2 = '''        # Init macro detector
        self.macro = MacroDetector("EQUITY", self.all_symbols)

        # PATCH_V28_KITE_ONLY_EQUITY: DO NOT load from JSON. Kite is the only source of truth.'''

NEW_2 = '''        # Init macro detector
        self.macro = MacroDetector("EQUITY", self.all_symbols)

        # FIX_V40_EQUITY_LLM: independent NewsBrain for equity
        self.news_brain = None
        if USE_LLM_NEWS and _NEWS_BRAIN_AVAILABLE and NewsBrain:
            try:
                try:
                    self.news_brain = NewsBrain(
                        universe_stocks=self.all_symbols,
                        news_feeds=NEWS_FEEDS,
                        module_name="EQUITY",
                        direction_mode="BULLISH_ONLY",
                        min_conviction=70,
                        require_cross_sources=2,
                        require_sentence_citation=True,
                        max_article_age_hours=24,
                    )
                    log.info(f"EQUITY: NewsBrain v4 initialized - BULLISH_ONLY, min_conv=70, cross>=2, cite=yes, max_age=24h")
                except TypeError:
                    self.news_brain = NewsBrain(fno_stocks=self.all_symbols)
                    log.warning("EQUITY: NewsBrain v3 fallback - safety layers NOT active")
            except Exception as _nbe:
                log.error(f"EQUITY: NewsBrain init failed: {_nbe}")
        else:
            log.info(f"EQUITY: NewsBrain disabled (USE_LLM_NEWS={USE_LLM_NEWS})")

        # PATCH_V28_KITE_ONLY_EQUITY: DO NOT load from JSON. Kite is the only source of truth.'''

PATCHES.append(("EquityModule init - NewsBrain creation", OLD_2, NEW_2))

OLD_3 = '''        # Gather candidates from ALL sources
        candidates = []

        # Source 1: News RSS
        if self.news:
            candidates.extend(self.news.scan())

        # Source 2: NSE Filings (promoter buying, buybacks, order wins)
        if self.filings:
            candidates.extend(self.filings.scan())

        # Source 3: Brokerage calls (analyst upgrades/downgrades)
        if self.brokerage:
            candidates.extend(self.brokerage.scan())

        # Source 4: Macro events (RBI, war, oil)
        if self.macro:
            candidates.extend(self.macro.scan())

        if not candidates:
            return'''

NEW_3 = '''        # FIX_V40_EQUITY_LLM: news scouts -> LLM; technical scanners pass through
        news_scout_candidates = []
        if self.news:
            news_scout_candidates.extend(self.news.scan())
        if self.filings:
            news_scout_candidates.extend(self.filings.scan())
        if self.brokerage:
            news_scout_candidates.extend(self.brokerage.scan())
        if self.macro:
            news_scout_candidates.extend(self.macro.scan())

        candidates = []
        _use_v4_eq = os.getenv("USE_V4_EQUITY_VALIDATION", "True").lower() in ("true", "1", "yes")
        if _use_v4_eq and getattr(self, "news_brain", None) and hasattr(self.news_brain, "validate_scout_candidate"):
            _val = 0
            _rej = 0
            _cor = 0
            for sc in news_scout_candidates:
                news_item = {
                    "title": sc.get("title", ""),
                    "summary": sc.get("summary", ""),
                    "link": sc.get("link", ""),
                    "source_feed": sc.get("source_feed", sc.get("source", "")),
                }
                try:
                    validated = self.news_brain.validate_scout_candidate(sc, news_item)
                except Exception as _ve:
                    log.error(f"FIX_V40: equity validator exception for {sc.get('symbol','?')}: {_ve}")
                    validated = []
                if not validated:
                    _rej += 1
                    continue
                for v in validated:
                    if v.get("corrected"):
                        _cor += 1
                    candidates.append(v)
                    _val += 1
            log.info(f"FIX_V40 EQUITY news scouts: total={len(news_scout_candidates)} -> validated={_val}, rejected={_rej}, corrected={_cor}")
        else:
            log.warning(f"FIX_V40: equity v4 validation UNAVAILABLE - fallback to raw scouts")
            candidates = news_scout_candidates

        if not candidates:
            candidates = []'''

PATCHES.append(("EquityModule scan_and_trade - LLM routing", OLD_3, NEW_3))

errors = []
applied = []
for name, old, new in PATCHES:
    c = src.count(old)
    if c == 0:
        errors.append(f"  {name}: NOT FOUND")
        continue
    if c > 1:
        errors.append(f"  {name}: ambiguous ({c})")
        continue
    src = src.replace(old, new, 1)
    applied.append(f"  {name}: OK")

print("Patch results:")
for a in applied: print(a)
for e in errors: print(e)

if errors:
    print("ABORT")
    raise SystemExit(1)

with open("gir.py", "w") as f:
    f.write(src)

print("All 3 patches applied")
PYEOF

echo ""
echo "=== VERIFICATION ==="
wc -l gir.py
python3 -m py_compile gir.py && echo "compile OK"
echo ""
echo "Markers: $(grep -c 'FIX_V40_EQUITY_LLM' gir.py)"
echo "validate_scout_candidate calls: $(grep -c 'validate_scout_candidate' gir.py)"
echo "module_name EQUITY: $(grep -c 'module_name=\"EQUITY\"' gir.py)"
echo "BULLISH_ONLY: $(grep -c 'BULLISH_ONLY' gir.py)"
echo ""
echo "Backup: $BACKUP"
echo "Rollback: cp $BACKUP gir.py && systemctl restart globaleye"
