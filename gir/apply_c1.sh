#!/bin/bash
set -e
cd /home/globalbot

echo "=== Pre-check: current state ==="
echo "FIX_NB_C1 markers before: $(grep -c 'FIX_NB_C1' news_brain.py)"
echo "Target pattern check: $(grep -c 'if self.require_cross_sources > 0 and len(cross_sources)' news_brain.py)"

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="news_brain.py.bak_pre_c1real_${STAMP}"
echo ""
echo "=== Backup ==="
cp news_brain.py "$BACKUP"
wc -l "$BACKUP"

echo ""
echo "=== Apply C1 patch ==="
python3 << 'PYEOF'
import sys
PATH = "news_brain.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

OLD = '''        cross_sources = self._cross_verify_rss(title, article_body, exclude_feed=source_feed)

        if self.require_cross_sources > 0 and len(cross_sources) < self.require_cross_sources:
            log.info(
                f"NewsBrain v4 [{self.module}]: REJECT {scout_source} {scout_symbol} — "
                f"only {len(cross_sources)} cross-sources (need {self.require_cross_sources})"
            )
            self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
            self._save_scout_cache()
            return []'''

NEW = '''        cross_sources = self._cross_verify_rss(title, article_body, exclude_feed=source_feed)

        # FIX_NB_C1: source-authority-based cross-source requirement
        # Authoritative sources (BSE/NSE filings, SEBI, macro) ARE ground truth
        _AUTHORITATIVE = ("FILING", "SEBI", "MACRO", "EARNINGS", "RESULT",
                          "BONUS", "DIVIDEND", "BUYBACK", "FOMC", "RBI", "BSE", "NSE")
        _source_upper = (scout_source or "").upper()
        _is_authoritative = any(tag in _source_upper for tag in _AUTHORITATIVE)
        _required_cross = 0 if _is_authoritative else self.require_cross_sources

        if _required_cross > 0 and len(cross_sources) < _required_cross:
            log.info(
                f"NewsBrain v4 [{self.module}]: REJECT {scout_source} {scout_symbol} — "
                f"only {len(cross_sources)} cross-sources (need {_required_cross})"
            )
            self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
            self._save_scout_cache()
            return []
        if _is_authoritative and len(cross_sources) == 0:
            log.info(
                f"NewsBrain v4 [{self.module}]: FIX_NB_C1 {scout_source} {scout_symbol} "
                f"authoritative source — cross-verify skipped"
            )'''

n = src.count(OLD)
print(f"Target occurrences found: {n}")
if n != 1:
    print(f"FAIL: expected exactly 1 match, got {n}")
    sys.exit(1)

src = src.replace(OLD, NEW, 1)

with open(PATH, "w") as f:
    f.write(src)
print(f"Wrote news_brain.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Syntax check ==="
python3 -c "import ast; ast.parse(open('news_brain.py').read()); print('syntax OK')"

echo ""
echo "=== Post-check: markers ==="
echo "FIX_NB_C1 markers after: $(grep -c 'FIX_NB_C1' news_brain.py)"
echo "_AUTHORITATIVE found: $(grep -c '_AUTHORITATIVE' news_brain.py)"
grep -n "FIX_NB_C1\|_AUTHORITATIVE" news_brain.py

echo ""
echo "=== Line count ==="
wc -l news_brain.py "$BACKUP"

echo ""
echo "=== DONE ==="
echo "Restart bot to activate: sudo systemctl restart globaleye"
echo "Rollback if needed: cp $BACKUP news_brain.py"
