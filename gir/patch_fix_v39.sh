#!/bin/bash
# FIX_V39_SCOUT_VALIDATION — route scouts through NewsBrain v3 validator
set -e
cd /home/globalbot

echo "=== FIX_V39_SCOUT_VALIDATION patch ==="
wc -l gir.py

if grep -q "FIX_V39_SCOUT_VALIDATION" gir.py; then
    echo "ABORT: already applied"
    exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v39_${TS}"
cp gir.py "$BACKUP"
echo "Backup: $BACKUP"

python3 <<'PYEOF'
with open("gir.py", "r") as f:
    src = f.read()

PATCHES = []

OLD_1 = '''                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"{feed_name}: {title[:80]}",
                            "source": "NEWS",
                            "timestamp": _now_iso,
                        })'''

NEW_1 = '''                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"{feed_name}: {title[:80]}",
                            "source": "NEWS",
                            "timestamp": _now_iso,
                            # FIX_V39_SCOUT_VALIDATION
                            "title": title,
                            "summary": summary_clean,
                            "link": link,
                            "source_feed": feed_name,
                        })'''

PATCHES.append(("NewsScanner", OLD_1, NEW_1))

OLD_2 = '''                candidates.append({
                    "symbol": symbol,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"FILING {matched_type}: {subject[:80]}",
                    "source": "FILING",
                    "filing_type": matched_type,
                })'''

NEW_2 = '''                candidates.append({
                    "symbol": symbol,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"FILING {matched_type}: {subject[:80]}",
                    "source": "FILING",
                    "filing_type": matched_type,
                    # FIX_V39_SCOUT_VALIDATION
                    "title": _desc[:200] if _desc else f"FILING {matched_type} {symbol}",
                    "summary": _body[:4000] if _body else _desc[:2000],
                    "link": "",
                    "source_feed": "NSE_FILINGS",
                })'''

PATCHES.append(("FilingMonitor", OLD_2, NEW_2))

OLD_3 = '''                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"BROKERAGE {'T1 ' if is_tier1 else ''}{title[:80]}",
                            "source": "BROKERAGE",
                        })'''

NEW_3 = '''                    for sym in symbols:
                        candidates.append({
                            "symbol": sym,
                            "direction": direction,
                            "score": score,
                            "catalyst": f"BROKERAGE {'T1 ' if is_tier1 else ''}{title[:80]}",
                            "source": "BROKERAGE",
                            # FIX_V39_SCOUT_VALIDATION
                            "title": title,
                            "summary": "",
                            "link": link,
                            "source_feed": feed_name,
                        })'''

PATCHES.append(("BrokerageMonitor", OLD_3, NEW_3))

OLD_4 = '''    def scan(self):
        """Scan RSS feeds for macro themes, return candidates."""
        candidates = []

        for feed_name, feed_url in NEWS_FEEDS.items():
            try:
                parsed = feedparser.parse(feed_url)
                for entry in parsed.entries[:15]:
                    title = entry.get("title", "")
                    title_lower = title.lower()
                    link = entry.get("link", "")

                    h = hashlib.md5(f"macro_{title}".encode()).hexdigest()[:12]
                    if h in self._seen:
                        continue

                    for theme, config in self.MACRO_MAP.items():
                        if theme in title_lower:
                            self._seen.add(h)
                            for stock in config["stocks"]:
                                if not self.valid_symbols or stock in self.valid_symbols:
                                    candidates.append({
                                        "symbol": stock,
                                        "direction": config["direction"],
                                        "score": config["score"],
                                        "catalyst": f"MACRO {theme.upper()}: {title[:60]}",
                                        "source": "MACRO",
                                    })
                            break  # One theme per headline

            except Exception:
                pass

        if candidates:
            log.info(f"Macro {self.name}: {len(candidates)} macro-driven candidates")
        return candidates'''

NEW_4 = '''    def scan(self):
        """FIX_V39_SCOUT_VALIDATION: scout only; real validation via NewsBrain v3."""
        import re as _re
        candidates = []

        for feed_name, feed_url in NEWS_FEEDS.items():
            try:
                parsed = feedparser.parse(feed_url)
                for entry in parsed.entries[:15]:
                    title = entry.get("title", "")
                    title_lower = title.lower()
                    link = entry.get("link", "")

                    summary = entry.get("summary", "") or entry.get("description", "") or ""
                    summary_clean = _re.sub(r"<[^>]+>", " ", summary)

                    h = hashlib.md5(f"macro_{title}".encode()).hexdigest()[:12]
                    if h in self._seen:
                        continue

                    for theme, config in self.MACRO_MAP.items():
                        if theme in title_lower:
                            self._seen.add(h)
                            for stock in config["stocks"]:
                                if not self.valid_symbols or stock in self.valid_symbols:
                                    candidates.append({
                                        "symbol": stock,
                                        "direction": config["direction"],
                                        "score": config["score"],
                                        "catalyst": f"MACRO {theme.upper()}: {title[:60]}",
                                        "source": "MACRO",
                                        # FIX_V39_SCOUT_VALIDATION
                                        "title": title,
                                        "summary": summary_clean,
                                        "link": link,
                                        "source_feed": feed_name,
                                        "theme_matched": theme,
                                    })
                            break

            except Exception:
                pass

        if candidates:
            log.info(f"Macro {self.name}: {len(candidates)} scout candidates (will be validated)")
        return candidates'''

PATCHES.append(("MacroDetector", OLD_4, NEW_4))

OLD_5 = '''            # V27 Stage 2: initialize LLM news brain
            self.news_brain = None
            if USE_LLM_NEWS and _NEWS_BRAIN_AVAILABLE and NewsBrain:
                try:
                    self.news_brain = NewsBrain(fno_stocks=self.fno_stocks)
                    log.info(f"FNO: NewsBrain initialized (DRY_RUN={LLM_DRY_RUN})")
                except Exception as _nbe2:
                    log.error(f"FNO: NewsBrain init failed: {_nbe2}")
            else:
                log.info(f"FNO: NewsBrain disabled (USE_LLM_NEWS={USE_LLM_NEWS} available={_NEWS_BRAIN_AVAILABLE})")'''

NEW_5 = '''            # FIX_V39_SCOUT_VALIDATION: init NewsBrain v3 with RSS feeds
            self.news_brain = None
            if USE_LLM_NEWS and _NEWS_BRAIN_AVAILABLE and NewsBrain:
                try:
                    try:
                        self.news_brain = NewsBrain(fno_stocks=self.fno_stocks, news_feeds=NEWS_FEEDS)
                        log.info(f"FNO: NewsBrain v3 initialized with {len(NEWS_FEEDS)} RSS feeds (DRY_RUN={LLM_DRY_RUN})")
                    except TypeError:
                        self.news_brain = NewsBrain(fno_stocks=self.fno_stocks)
                        log.warning(f"FNO: NewsBrain v2 fallback (DRY_RUN={LLM_DRY_RUN})")
                except Exception as _nbe2:
                    log.error(f"FNO: NewsBrain init failed: {_nbe2}")
            else:
                log.info(f"FNO: NewsBrain disabled (USE_LLM_NEWS={USE_LLM_NEWS} available={_NEWS_BRAIN_AVAILABLE})")'''

PATCHES.append(("NewsBrain init", OLD_5, NEW_5))

OLD_6 = '''        # Gather candidates from ALL sources
        candidates = []

        # Source 1: News RSS
        if self.news:
            candidates.extend(self.news.scan())

        # Source 2: NSE Filings
        if self.filings:
            candidates.extend(self.filings.scan())

        # Source 3: Brokerage calls
        if self.brokerage:
            candidates.extend(self.brokerage.scan())

        # Source 4: Macro events (most important for F&O)
        if self.macro:
            candidates.extend(self.macro.scan())'''

NEW_6 = '''        # FIX_V39_SCOUT_VALIDATION: scouts -> validator -> trade list
        scout_candidates = []

        if self.news:
            scout_candidates.extend(self.news.scan())
        if self.filings:
            scout_candidates.extend(self.filings.scan())
        if self.brokerage:
            scout_candidates.extend(self.brokerage.scan())
        if self.macro:
            scout_candidates.extend(self.macro.scan())

        candidates = []
        _use_v3 = os.getenv("USE_V3_VALIDATION", "True").lower() in ("true", "1", "yes")
        if _use_v3 and getattr(self, "news_brain", None) and hasattr(self.news_brain, "validate_scout_candidate"):
            _validated = 0
            _rejected = 0
            _corrected = 0
            for sc in scout_candidates:
                news_item = {
                    "title": sc.get("title", ""),
                    "summary": sc.get("summary", ""),
                    "link": sc.get("link", ""),
                    "source_feed": sc.get("source_feed", sc.get("source", "")),
                }
                try:
                    validated = self.news_brain.validate_scout_candidate(sc, news_item)
                except Exception as _ve:
                    log.error(f"FIX_V39: validator exception for {sc.get('symbol','?')}: {_ve}")
                    validated = []
                if not validated:
                    _rejected += 1
                    continue
                for v in validated:
                    if v.get("corrected"):
                        _corrected += 1
                    candidates.append(v)
                    _validated += 1
            log.info(f"FIX_V39: scouts={len(scout_candidates)} -> validated={_validated}, rejected={_rejected}, corrected={_corrected}")
        else:
            log.warning(f"FIX_V39: v3 validation UNAVAILABLE (use_v3={_use_v3}) - fallback to raw scouts")
            candidates = scout_candidates'''

PATCHES.append(("scan_signals main loop", OLD_6, NEW_6))

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

print("\nPatch results:")
for a in applied: print(a)
for e in errors: print(e)

if errors:
    print("\nABORT")
    raise SystemExit(1)

with open("gir.py", "w") as f:
    f.write(src)

print("\nAll 6 patches applied")
PYEOF

echo ""
echo "=== VERIFICATION ==="
wc -l gir.py
python3 -m py_compile gir.py && echo "compile OK"
echo ""
echo "Markers: $(grep -c 'FIX_V39_SCOUT_VALIDATION' gir.py)"
echo "validate_scout_candidate: $(grep -c 'validate_scout_candidate' gir.py)"
echo "news_feeds=NEWS_FEEDS: $(grep -c 'news_feeds=NEWS_FEEDS' gir.py)"
echo ""
echo "Backup: $BACKUP"
echo "Rollback: cp $BACKUP gir.py && systemctl restart globaleye"
