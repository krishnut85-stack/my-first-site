#!/bin/bash
set -e
cd /home/globalbot
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_nbg2_${STAMP}"
echo "=== Backup ==="
cp gir.py "$BACKUP"
wc -l "$BACKUP"

python3 << 'PYEOF'
import sys
PATH = "gir.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

def must_replace(old, new, tag):
    global src
    n = src.count(old)
    if n != 1:
        print(f"  [{tag}] FAIL: found {n}"); sys.exit(1)
    src = src.replace(old, new, 1)
    print(f"  [{tag}] OK")

# G2 equity: relax filters
must_replace(
    '''                    self.news_brain = NewsBrain(
                        universe_stocks=self.all_symbols,
                        news_feeds=NEWS_FEEDS,
                        module_name="EQUITY",
                        direction_mode="BULLISH_ONLY",
                        min_conviction=70,
                        require_cross_sources=2,
                        require_sentence_citation=True,
                        max_article_age_hours=24,
                    )
                    log.info(f"EQUITY: NewsBrain v4 initialized - BULLISH_ONLY, min_conv=70, cross>=2, cite=yes, max_age=24h")''',
    '''                    # FIX_NB_G2: relaxed filters — conv 70->60, cross 2->1, age 24h->72h
                    self.news_brain = NewsBrain(
                        universe_stocks=self.all_symbols,
                        news_feeds=NEWS_FEEDS,
                        module_name="EQUITY",
                        direction_mode="BULLISH_ONLY",
                        min_conviction=60,
                        require_cross_sources=1,
                        require_sentence_citation=True,
                        max_article_age_hours=72,
                    )
                    log.info(f"EQUITY: NewsBrain v4 [FIX_NB_G2] - BULLISH_ONLY, min_conv=60, cross>=1, cite=yes, max_age=72h")''',
    "G2 equity config"
)

# G2 F&O: upgrade to v4 BOTH
must_replace(
    '''                        self.news_brain = NewsBrain(fno_stocks=self.fno_stocks, news_feeds=NEWS_FEEDS)
                        log.info(f"FNO: NewsBrain v3 initialized with {len(NEWS_FEEDS)} RSS feeds (DRY_RUN={LLM_DRY_RUN})")''',
    '''                        # FIX_NB_G2: upgrade F&O to v4 BOTH directions, relaxed filters
                        try:
                            self.news_brain = NewsBrain(
                                universe_stocks=self.fno_stocks,
                                news_feeds=NEWS_FEEDS,
                                module_name="FNO",
                                direction_mode="BOTH",
                                min_conviction=55,
                                require_cross_sources=1,
                                require_sentence_citation=False,
                                max_article_age_hours=48,
                            )
                            log.info(f"FNO: NewsBrain v4 [FIX_NB_G2] - BOTH, min_conv=55, cross>=1, no-cite, max_age=48h (DRY_RUN={LLM_DRY_RUN})")
                        except TypeError:
                            self.news_brain = NewsBrain(fno_stocks=self.fno_stocks, news_feeds=NEWS_FEEDS)
                            log.warning(f"FNO: NewsBrain v3 fallback (DRY_RUN={LLM_DRY_RUN})")''',
    "G2 fno upgrade"
)

with open(PATH, "w") as f:
    f.write(src)
print(f"\nWrote gir.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Compile ==="
python3 -c "import ast; ast.parse(open('gir.py').read()); print('syntax OK')"

echo ""
echo "=== Markers ==="
echo "FIX_NB_G2: $(grep -c 'FIX_NB_G2' gir.py)"
grep -n "FIX_NB_G2" gir.py | head -5

echo ""
wc -l gir.py "$BACKUP"

echo ""
echo "=== DONE GROUP 2 ==="
echo "DO NOT RESTART YET"
echo "Rollback: cp $BACKUP gir.py"
