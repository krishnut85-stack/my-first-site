#!/bin/bash
set -e
cd /home/globalbot
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="news_brain.py.bak_pre_g1_${STAMP}"
echo "=== Backup ==="
cp news_brain.py "$BACKUP"
wc -l "$BACKUP"

python3 << 'PYEOF'
import sys
PATH = "news_brain.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

def must_replace(old, new, tag):
    global src
    n = src.count(old)
    if n != 1:
        print(f"  [{tag}] FAIL: expected 1, found {n}"); sys.exit(1)
    src = src.replace(old, new, 1)
    print(f"  [{tag}] OK")

# A1
must_replace(
    'sample = ", ".join(sorted(list(self.universe))[:80])',
    '''# FIX_NB_A1
        _univ_list = sorted(list(self.universe))
        _univ_size = len(_univ_list)
        sample = ", ".join(_univ_list[:200]) + (f" ... ({_univ_size} total symbols in universe)" if _univ_size > 200 else "")''',
    "A1 universe"
)
must_replace(
    '5. Valid universe (only these are tradeable): {sample}',
    '5. Tradeable universe sample (may be partial — trust symbol if it looks like a valid NSE stock): {sample}',
    "A1b prompt"
)

# A2
must_replace(
    '''            text = parts[0].get("text", "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            return json.loads(text)
        except Exception as e:
            log.error(f"NewsBrain [{self.module}]: Gemini parse failed: {e}")
            return None''',
    '''            text = parts[0].get("text", "").strip()
            if text.startswith("```"):
                _parts = text.split("```")
                if len(_parts) >= 2:
                    text = _parts[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            # FIX_NB_A2: robust JSON parsing
            try:
                return json.loads(text)
            except json.JSONDecodeError as _je:
                import re as _nbre
                _m = _nbre.search(r'\\{[\\s\\S]*\\}', text)
                if _m:
                    _candidate = _m.group(0)
                    try:
                        return json.loads(_candidate)
                    except json.JSONDecodeError:
                        pass
                    for _suffix in ('"}', '"}}', '"]}', '"}]}'):
                        try:
                            return json.loads(_candidate + _suffix)
                        except json.JSONDecodeError:
                            continue
                log.error(f"NewsBrain [{self.module}]: Gemini JSON parse failed (len={len(text)}): {_je}")
                return None
        except Exception as e:
            log.error(f"NewsBrain [{self.module}]: Gemini response processing failed: {e}")
            return None''',
    "A2 gemini parse"
)

# A4
must_replace(
    '''        for pat in patterns:
            m = _re.search(pat, html, _re.IGNORECASE)
            if m:
                try:
                    date_str = m.group(1)
                    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%SZ",
                                "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
                        try:
                            dt = datetime.strptime(date_str[:19] + ("Z" if "Z" in date_str else ""), fmt[:len(date_str[:19])+1])
                            return dt
                        except Exception:
                            continue
                except Exception:
                    continue
        return None''',
    '''        # FIX_NB_A4: proper date format handling
        for pat in patterns:
            m = _re.search(pat, html, _re.IGNORECASE)
            if m:
                try:
                    date_str = m.group(1).strip()
                    _try_formats = [
                        "%Y-%m-%dT%H:%M:%S%z",
                        "%Y-%m-%dT%H:%M:%S.%f%z",
                        "%Y-%m-%dT%H:%M:%SZ",
                        "%Y-%m-%dT%H:%M:%S.%fZ",
                        "%Y-%m-%dT%H:%M:%S",
                        "%Y-%m-%d %H:%M:%S",
                        "%Y-%m-%d",
                    ]
                    for fmt in _try_formats:
                        try:
                            return datetime.strptime(date_str, fmt)
                        except (ValueError, TypeError):
                            continue
                    try:
                        _ds = date_str.rstrip("Z").split("+")[0].split(".")[0]
                        return datetime.fromisoformat(_ds)
                    except (ValueError, TypeError):
                        continue
                except Exception:
                    continue
        return None''',
    "A4 date parse"
)

# A5
must_replace(
    '''        cache_key = self._hash_scout(candidate, article_body or "")
        if cache_key in self._scout_cache:
            return self._scout_cache[cache_key].get("candidates", [])''',
    '''        cache_key = self._hash_scout(candidate, article_body or "")
        # FIX_NB_A5: enforce cache TTL on read
        if cache_key in self._scout_cache:
            _entry = self._scout_cache[cache_key]
            _entry_ts = _entry.get("ts", 0)
            if time.time() - _entry_ts < _CACHE_MAX_AGE_HOURS * 3600:
                return _entry.get("candidates", [])
            del self._scout_cache[cache_key]''',
    "A5 cache TTL"
)

# A6
must_replace(
    '''    def _call_gemini(self, prompt):
        _key = os.getenv("GEMINI_API_KEY", "") or GEMINI_API_KEY
        if not _key:
            log.error(f"NewsBrain [{self.module}]: GEMINI_API_KEY not set")
            return None''',
    '''    def _call_gemini(self, prompt):
        _key = os.getenv("GEMINI_API_KEY", "") or GEMINI_API_KEY
        if not _key:
            log.error(f"NewsBrain [{self.module}]: GEMINI_API_KEY not set")
            return None
        # FIX_NB_A6: rate limiter 30/min
        if not hasattr(self, '_gemini_call_times'):
            self._gemini_call_times = []
        _now = time.time()
        self._gemini_call_times = [t for t in self._gemini_call_times if _now - t < 60]
        if len(self._gemini_call_times) >= 30:
            _wait = 60 - (_now - self._gemini_call_times[0]) + 0.5
            if _wait > 0:
                log.warning(f"NewsBrain [{self.module}]: rate limit guard sleeping {_wait:.1f}s")
                time.sleep(min(_wait, 10))
        self._gemini_call_times.append(_now)''',
    "A6 rate limiter"
)

# A3
must_replace(
    '''            # EQUITY (BULLISH_ONLY): reject if FinBERT says bearish/neutral with high conviction
            if self.direction_mode == "BULLISH_ONLY":
                if _fb_label in ("negative", "neutral") and _fb_conf >= 0.80:
                    log.info(f"NewsBrain v5 [{self.module}]: FIX_V54_FINBERT_REJECT {scout_symbol} "
                             f"— {_fb_label} {_fb_conf:.2f} (Gemini SKIPPED, saved cost)")
                    self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                    self._save_scout_cache()
                    return []''',
    '''            # FIX_NB_A3: only reject hard NEGATIVE; neutrals go to Gemini
            if self.direction_mode == "BULLISH_ONLY":
                if _fb_label == "negative" and _fb_conf >= 0.85:
                    log.info(f"NewsBrain v5 [{self.module}]: FIX_NB_A3_FINBERT_REJECT {scout_symbol} "
                             f"— hard negative {_fb_conf:.2f} (Gemini SKIPPED)")
                    self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                    self._save_scout_cache()
                    return []''',
    "A3 finbert threshold"
)

# B4
must_replace(
    '''            if self.require_sentence_citation:
                if not citation or len(citation.strip()) < 20:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — no justifying sentence cited")
                    continue
                citation_stripped = _re.sub(r'[^\\w\\s]', '', citation.lower())[:80]
                body_stripped = _re.sub(r'[^\\w\\s]', '', article_body.lower())
                if len(citation_stripped) > 20 and citation_stripped[:40] not in body_stripped:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — citation not in article")
                    continue''',
    '''            if self.require_sentence_citation:
                if not citation or len(citation.strip()) < 20:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — no justifying sentence cited")
                    continue
                # FIX_NB_B4: word-overlap match instead of brittle prefix match
                _cit_words = set(_re.findall(r'\\w+', citation.lower()))
                _body_words = set(_re.findall(r'\\w+', article_body.lower()))
                _overlap = len(_cit_words & _body_words)
                _cit_total = max(1, len(_cit_words))
                _overlap_ratio = _overlap / _cit_total
                if len(_cit_words) < 4:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — citation too short ({len(_cit_words)} words)")
                    continue
                if _overlap_ratio < 0.50:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — citation overlap {_overlap_ratio:.0%} < 50%")
                    continue''',
    "B4 citation match"
)

# B8
must_replace(
    '''        text = (text or "")[:512]
        if not text.strip():
            return None, 0.0
        inputs = _FINBERT_TOKENIZER(text, return_tensors="pt", truncation=True, max_length=512)''',
    '''        # FIX_NB_B8: 512 CHARS → 3000 chars, tokenizer handles real token truncation
        text = (text or "")[:3000]
        if not text.strip():
            return None, 0.0
        inputs = _FINBERT_TOKENIZER(text, return_tensors="pt", truncation=True, max_length=512)''',
    "B8 finbert tokens"
)

with open(PATH, "w") as f:
    f.write(src)
print(f"\nWrote news_brain.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Compile ==="
python3 -c "import ast; ast.parse(open('news_brain.py').read()); print('syntax OK')"

echo ""
echo "=== Markers ==="
for M in A1 A2 A3 A4 A5 A6 B4 B8; do
    echo "FIX_NB_$M: $(grep -c "FIX_NB_$M" news_brain.py)"
done

echo ""
wc -l news_brain.py "$BACKUP"
echo ""
echo "=== DONE GROUP 1 ==="
echo "DO NOT RESTART YET"
echo "Rollback: cp $BACKUP news_brain.py"
