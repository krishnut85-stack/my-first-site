#!/usr/bin/env python3
"""
news_brain.py v4.0 — MULTI-MODULE LLM news validation for GIR

V4 CHANGES (Apr 21, 2026):
  1. Independent instances per module (EQUITY + FNO separate)
  2. Per-module cache files (no cross-contamination)
  3. Per-module direction rules:
     - FNO: BULLISH or BEARISH (options go both ways)
     - EQUITY: BULLISH only (CNC is buy-only)
  4. Safety layers for EQUITY (stricter):
     - Layer A: min 2 cross-sources required
     - Layer B: Gemini must cite specific article sentences
     - Layer C: article max 24 hours old (if date extractable)
     - Confidence >= 70 for equity (vs 60 for F&O)
  5. Instance-level _recent_candidates (fixes shared-state bug from v3)
  6. Backwards compatible: accepts old fno_stocks param as alias for universe_stocks
"""

import os
import json
import time
import logging
import hashlib
import re as _re
import requests
from datetime import datetime, timedelta
from pathlib import Path
from io import BytesIO

# ============================================================================
# PAPER MODE (Phase 4A 2026-05-21) — wrap Gemini calls for cost/latency tracking
# ============================================================================
import sys as _sys
_sys.path.insert(0, '/home/globalbot/paper')
try:
    from paper_trader import PAPER_MODE, paper_gemini_call, record_event
except Exception as _paper_e:
    PAPER_MODE = False
    print(f"[NEWS_BRAIN WARNING] paper_trader import failed: {_paper_e}", file=_sys.stderr)
    def paper_gemini_call(**kwargs): pass
    def record_event(**kwargs): pass

try:
    import trafilatura
    _TRAFILATURA_AVAILABLE = True
except ImportError:
    _TRAFILATURA_AVAILABLE = False

try:
    import PyPDF2
    _PYPDF2_AVAILABLE = True
except ImportError:
    _PYPDF2_AVAILABLE = False

try:
    from bs4 import BeautifulSoup
    _BS4_AVAILABLE = True
except ImportError:
    _BS4_AVAILABLE = False

try:
    import feedparser
    _FEEDPARSER_AVAILABLE = True
except ImportError:
    _FEEDPARSER_AVAILABLE = False

log = logging.getLogger("NewsBrain")

# FIX_V54_FINBERT: lazy-loaded local sentiment model for pre-filtering before Gemini
_FINBERT_MODEL = None
_FINBERT_TOKENIZER = None
_FINBERT_AVAILABLE = None  # None=untried, True=loaded, False=failed

def _finbert_load():
    """Lazy-load FinBERT. Returns True if available."""
    global _FINBERT_MODEL, _FINBERT_TOKENIZER, _FINBERT_AVAILABLE
    if _FINBERT_AVAILABLE is not None:
        return _FINBERT_AVAILABLE
    try:
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        import torch
        log.info("FIX_V54_FINBERT: loading ProsusAI/finbert (first-time ~500MB download)...")
        _FINBERT_TOKENIZER = AutoTokenizer.from_pretrained("ProsusAI/finbert")
        _FINBERT_MODEL = AutoModelForSequenceClassification.from_pretrained("ProsusAI/finbert")
        _FINBERT_MODEL.eval()
        _FINBERT_AVAILABLE = True
        log.info("FIX_V54_FINBERT: loaded OK")
        return True
    except Exception as e:
        log.warning(f"FIX_V54_FINBERT: load failed ({e}) — falling back to Gemini-only")
        _FINBERT_AVAILABLE = False
        return False

def _finbert_score(text):
    """Returns (label, confidence) or (None, 0.0) on failure. Local, free, ~50ms."""
    if not _finbert_load():
        return None, 0.0
    try:
        import torch
        # FIX_NB_B8: 512 CHARS → 3000 chars, tokenizer handles real token truncation
        text = (text or "")[:3000]
        if not text.strip():
            return None, 0.0
        inputs = _FINBERT_TOKENIZER(text, return_tensors="pt", truncation=True, max_length=512)
        with torch.no_grad():
            logits = _FINBERT_MODEL(**inputs).logits
        probs = torch.softmax(logits, dim=1)[0]
        labels = ["positive", "negative", "neutral"]
        idx = int(probs.argmax().item())
        return labels[idx], float(probs[idx].item())
    except Exception as e:
        log.warning(f"FIX_V54_FINBERT: scoring failed: {e}")
        return None, 0.0


GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-2.5-flash"  # Primary
GEMINI_FALLBACK_MODEL = "gemini-2.5-flash-lite"  # FIX_V52: fallback when primary 503s
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
GEMINI_FALLBACK_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_FALLBACK_MODEL}:generateContent"

GEMINI_TIMEOUT_SEC = 30

MOMENTUM_MIN_PCT = 2.0  # V75: 5% -> 2% catch early momentum
MOMENTUM_MIN_VOL_RATIO = 1.5  # V75: 2x -> 1.5x

ARTICLE_FETCH_TIMEOUT_SEC = 10
PDF_MAX_SIZE_MB = 10
PDF_MAX_PAGES = 30
FULL_ARTICLE_MAX_CHARS = 8000
ARTICLE_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 NewsBrainBot/4.0"

CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 20  # V75: increased depth
CROSS_VERIFY_KEYWORD_OVERLAP = 3

_CACHE_DIR = "/home/globalbot"
_CACHE_MAX_AGE_HOURS = 6


class NewsBrain:
    """V4: multi-module LLM validator. Each module gets its own instance with own cache/rules."""

    def __init__(self, universe_stocks=None, news_feeds=None,
                 module_name="FNO", direction_mode="BOTH",
                 min_conviction=None, require_cross_sources=0,
                 require_sentence_citation=False, max_article_age_hours=0,
                 fno_stocks=None):
        if universe_stocks is None and fno_stocks is not None:
            universe_stocks = fno_stocks

        self.universe = set(universe_stocks) if universe_stocks else set()
        self.news_feeds = news_feeds or {}
        self.module = module_name.upper()
        self.direction_mode = direction_mode.upper()
        self.require_cross_sources = int(require_cross_sources)
        self.require_sentence_citation = bool(require_sentence_citation)
        self.max_article_age_hours = int(max_article_age_hours)

        if min_conviction is None:
            self.min_conviction = 55 if self.module == "EQUITY" else 50  # V74: relaxed 70/60 -> 55/50
        else:
            self.min_conviction = int(min_conviction)

        self._cache_file = f"{_CACHE_DIR}/news_brain_cache_{self.module}.json"
        self._scout_cache_file = f"{_CACHE_DIR}/news_brain_scout_cache_{self.module}.json"

        self._cache = self._load_cache()
        self._scout_cache = self._load_scout_cache()
        self._feed_cache = {}
        self._feed_cache_ttl = 300
        self._recent_candidates = []

        # PATCH_V62_PARALLEL: locks for thread-safe concurrent validation
        # Four shared mutable states need protection:
        #   _cache, _scout_cache (dicts), _gemini_call_times (list), _recent_candidates (list)
        import threading as _th_mod
        self._cache_lock = _th_mod.Lock()
        self._scout_cache_lock = _th_mod.Lock()
        self._gemini_rate_lock = _th_mod.Lock()
        self._recent_lock = _th_mod.Lock()
        self._finbert_lock = _th_mod.Lock()  # PyTorch inference not guaranteed thread-safe

        log.info(
            f"NewsBrain v4 [{self.module}]: "
            f"trafilatura={'OK' if _TRAFILATURA_AVAILABLE else 'MISSING'}, "
            f"PyPDF2={'OK' if _PYPDF2_AVAILABLE else 'MISSING'}, "
            f"bs4={'OK' if _BS4_AVAILABLE else 'MISSING'}, "
            f"feedparser={'OK' if _FEEDPARSER_AVAILABLE else 'MISSING'}, "
            f"universe={len(self.universe)}, feeds={len(self.news_feeds)}, "
            f"direction={self.direction_mode}, min_conviction={self.min_conviction}, "
            f"cross_req={self.require_cross_sources}, citation={self.require_sentence_citation}, "
            f"max_age_hrs={self.max_article_age_hours}"
        )

    def _load_cache(self):
        try:
            if not Path(self._cache_file).exists():
                return {}
            data = json.loads(Path(self._cache_file).read_text())
            cutoff = time.time() - (_CACHE_MAX_AGE_HOURS * 3600)
            return {k: v for k, v in data.items() if v.get("ts", 0) > cutoff}
        except Exception:
            return {}

    def _save_cache(self):
        try:
            Path(self._cache_file).write_text(json.dumps(self._cache))
        except Exception as e:
            log.warning(f"NewsBrain [{self.module}]: cache save failed: {e}")

    def _load_scout_cache(self):
        try:
            if not Path(self._scout_cache_file).exists():
                return {}
            data = json.loads(Path(self._scout_cache_file).read_text())
            cutoff = time.time() - (_CACHE_MAX_AGE_HOURS * 3600)
            return {k: v for k, v in data.items() if v.get("ts", 0) > cutoff}
        except Exception:
            return {}

    def _save_scout_cache(self):
        try:
            Path(self._scout_cache_file).write_text(json.dumps(self._scout_cache))
        except Exception as e:
            log.warning(f"NewsBrain [{self.module}]: scout cache save failed: {e}")

    def _hash_news(self, title, summary):
        return hashlib.md5(f"{title}|{summary[:200]}".encode()).hexdigest()

    def _hash_scout(self, candidate, article_body):
        key = f"{candidate.get('symbol','')}|{candidate.get('direction','')}|{candidate.get('source','')}|{article_body[:200]}"
        return hashlib.md5(key.encode()).hexdigest()

    def _fetch_full_article(self, url):
        if not url or not url.startswith(("http://", "https://")):
            return None, None
        try:
            resp = requests.get(
                url,
                timeout=ARTICLE_FETCH_TIMEOUT_SEC,
                headers={"User-Agent": ARTICLE_USER_AGENT},
                allow_redirects=True,
            )
            if resp.status_code != 200:
                return None, None
            content_type = resp.headers.get("content-type", "").lower()
            if "application/pdf" in content_type or url.lower().endswith(".pdf"):
                return self._extract_pdf_text_from_bytes(resp.content), None
            html = resp.text
            pub_date = self._extract_publish_date(html)

            if _TRAFILATURA_AVAILABLE:
                extracted = trafilatura.extract(
                    html, include_comments=False, include_tables=False, favor_precision=True,
                )
                if extracted and len(extracted.strip()) > 100:
                    return extracted[:FULL_ARTICLE_MAX_CHARS], pub_date

            if _BS4_AVAILABLE:
                soup = BeautifulSoup(html, "html.parser")
                for tag in soup(["script", "style", "nav", "header", "footer", "aside", "form"]):
                    tag.decompose()
                article = soup.find("article")
                text = article.get_text(separator=" ", strip=True) if article else soup.get_text(separator=" ", strip=True)
                text = " ".join(text.split())
                if len(text) > 200:
                    return text[:FULL_ARTICLE_MAX_CHARS], pub_date
            return None, None
        except Exception as e:
            log.debug(f"NewsBrain v4 [{self.module}]: article fetch failed: {e}")
            return None, None

    def _extract_publish_date(self, html):
        if not html:
            return None
        patterns = [
            r'<meta[^>]*property="article:published_time"[^>]*content="([^"]+)"',
            r'<meta[^>]*name="publish_date"[^>]*content="([^"]+)"',
            r'<meta[^>]*name="pubdate"[^>]*content="([^"]+)"',
            r'<meta[^>]*itemprop="datePublished"[^>]*content="([^"]+)"',
            r'<time[^>]*datetime="([^"]+)"',
        ]
        # FIX_NB_A4: proper date format handling
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
        return None

    def _is_article_fresh(self, pub_date):
        if self.max_article_age_hours == 0:
            return True
        if pub_date is None:
            return True
        try:
            if hasattr(pub_date, 'tzinfo') and pub_date.tzinfo:
                pub_date = pub_date.replace(tzinfo=None)
            age_hours = (datetime.utcnow() - pub_date).total_seconds() / 3600
            return age_hours <= self.max_article_age_hours
        except Exception:
            return True

    def _extract_pdf_text_from_bytes(self, pdf_bytes):
        if not _PYPDF2_AVAILABLE or not pdf_bytes:
            return None
        size_mb = len(pdf_bytes) / (1024 * 1024)
        if size_mb > PDF_MAX_SIZE_MB:
            return None
        try:
            reader = PyPDF2.PdfReader(BytesIO(pdf_bytes))
            pages_to_read = min(len(reader.pages), PDF_MAX_PAGES)
            text_parts = []
            for i in range(pages_to_read):
                try:
                    page_text = reader.pages[i].extract_text() or ""
                    if page_text.strip():
                        text_parts.append(page_text.strip())
                except Exception:
                    continue
            if not text_parts:
                return None
            combined = " ".join(text_parts)
            combined = " ".join(combined.split())
            return combined[:FULL_ARTICLE_MAX_CHARS] if combined else None
        except Exception as e:
            log.debug(f"NewsBrain [{self.module}]: PDF extract failed: {e}")
            return None

    def _extract_keywords(self, text, min_length=4):
        if not text:
            return set()
        stopwords = {
            "the","and","for","are","but","not","you","all","can","had","her","was",
            "one","our","out","day","get","has","him","his","how","man","new","now",
            "old","see","two","way","who","boy","did","its","let","put","say","she",
            "too","use","with","from","this","that","they","have","will","been","were",
            "what","when","your","said","each","which","their","there","would","about",
            "could","first","after","other","more","some","like","than","into","also",
            "over","only","time","year","india","indian","says",
        }
        text_lower = text.lower()
        words = _re.findall(r"[a-z0-9\-]+", text_lower)
        return {w for w in words if len(w) >= min_length and w not in stopwords}

    def _parse_feed_cached(self, feed_url):
        if not _FEEDPARSER_AVAILABLE:
            return []
        now = time.time()
        if feed_url in self._feed_cache:
            cached_ts, cached_entries = self._feed_cache[feed_url]
            if (now - cached_ts) < self._feed_cache_ttl:
                return cached_entries
        try:
            parsed = feedparser.parse(feed_url)
            entries = list(parsed.entries[:30])
            self._feed_cache[feed_url] = (now, entries)
            return entries
        except Exception as e:
            log.debug(f"NewsBrain [{self.module}]: feed parse failed: {e}")
            return []

    def _cross_verify_rss(self, title, body, exclude_feed=None):
        if not self.news_feeds:
            return []
        origin_keywords = self._extract_keywords(f"{title} {body[:1500]}")
        if len(origin_keywords) < 5:
            return []
        matches = []
        feeds_checked = 0
        for feed_name, feed_url in self.news_feeds.items():
            if feeds_checked >= CROSS_VERIFY_MAX_FEEDS_TO_CHECK:
                break
            if exclude_feed and feed_name == exclude_feed:
                continue
            entries = self._parse_feed_cached(feed_url)
            feeds_checked += 1
            for entry in entries[:15]:
                cand_title = entry.get("title", "")
                cand_summary = entry.get("summary", "") or entry.get("description", "")
                if _BS4_AVAILABLE and cand_summary:
                    try:
                        cand_summary = BeautifulSoup(cand_summary, "html.parser").get_text(separator=" ", strip=True)
                    except Exception:
                        pass
                cand_keywords = self._extract_keywords(f"{cand_title} {cand_summary[:1500]}")
                overlap = len(origin_keywords & cand_keywords)
                if overlap >= CROSS_VERIFY_KEYWORD_OVERLAP:
                    matches.append({
                        "feed": feed_name,
                        "title": cand_title,
                        "snippet": cand_summary[:1500],
                        "link": entry.get("link", ""),
                        "overlap": overlap,
                    })
        matches.sort(key=lambda m: m["overlap"], reverse=True)
        seen_titles = set()
        unique_matches = []
        for m in matches:
            t_key = m["title"][:100].lower()
            if t_key in seen_titles:
                continue
            seen_titles.add(t_key)
            unique_matches.append(m)
            if len(unique_matches) >= 4:
                break
        return unique_matches

    def _call_gemini(self, prompt):
        # Paper-trader telemetry capture
        _pt_start = time.time()
        _pt_prompt_hash = hashlib.md5(prompt.encode("utf-8", errors="replace")).hexdigest()[:16] if prompt else "empty"
        _pt_prompt_tokens = max(1, len(prompt) // 4) if prompt else 0
        _pt_model_used = GEMINI_MODEL
        _key = os.getenv("GEMINI_API_KEY", "") or GEMINI_API_KEY
        if not _key:
            log.error(f"NewsBrain [{self.module}]: GEMINI_API_KEY not set")
            return None
        # FIX_NB_A6 + PATCH_V62_PARALLEL: rate limiter 120/min, thread-safe
        with self._gemini_rate_lock:
            if not hasattr(self, '_gemini_call_times'):
                self._gemini_call_times = []
            _now = time.time()
            self._gemini_call_times = [t for t in self._gemini_call_times if _now - t < 60]
            if len(self._gemini_call_times) >= 120:  # PATCH_V62: 30->120 (paid Tier 1, 1000 RPM cap)
                _wait = 60 - (_now - self._gemini_call_times[0]) + 0.5
                _do_sleep = _wait > 0
            else:
                _do_sleep = False
                _wait = 0
            self._gemini_call_times.append(_now)
        # Sleep OUTSIDE the lock so other threads can proceed
        if _do_sleep:
            log.warning(f"NewsBrain [{self.module}]: rate limit guard sleeping {_wait:.1f}s")
            time.sleep(min(_wait, 10))
        body = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 8000,  # FIX_NB_A1_PARSER
                "responseMimeType": "application/json",
                "thinkingConfig": {"thinkingBudget": 0},  # PATCH_V68_NO_THINK: cuts cost ~70%
            }
        }
        _max_retries = 2  # FIX_V52: reduced from 3, fallback model is faster recovery
        _backoff = 3
        resp = None
        for _attempt in range(_max_retries):
            try:
                resp = requests.post(GEMINI_URL, params={"key": _key}, json=body, timeout=GEMINI_TIMEOUT_SEC)
                if resp.status_code == 200:
                    break
                if resp.status_code in (429, 500, 502, 503, 504):
                    log.warning(f"NewsBrain [{self.module}]: Gemini HTTP {resp.status_code}, retry in {_backoff}s")
                    time.sleep(_backoff)
                    _backoff *= 2
                    continue
                log.warning(f"NewsBrain [{self.module}]: Gemini HTTP {resp.status_code}: {resp.text[:200]}")
                return None
            except requests.exceptions.Timeout:
                time.sleep(_backoff)
                _backoff *= 2
                continue
            except Exception as _re2:
                time.sleep(_backoff)
                _backoff *= 2
                continue
        # FIX_V52: Fallback chain - switch to lighter model if primary fails
        if not resp or resp.status_code != 200:
            log.warning(f"NewsBrain [{self.module}]: primary {GEMINI_MODEL} failed, trying fallback {GEMINI_FALLBACK_MODEL}")
            try:
                resp = requests.post(GEMINI_FALLBACK_URL, params={"key": _key}, json=body, timeout=GEMINI_TIMEOUT_SEC)
                if resp.status_code == 200:
                    log.info(f"NewsBrain [{self.module}]: fallback {GEMINI_FALLBACK_MODEL} succeeded")
                    _pt_model_used = GEMINI_FALLBACK_MODEL
                else:
                    log.error(f"NewsBrain [{self.module}]: both primary and fallback failed ({resp.status_code})")
                    return None
            except Exception as _fe:
                log.error(f"NewsBrain [{self.module}]: fallback exception: {_fe}")
                return None
        try:
            data = resp.json()
            cands = data.get("candidates", [])
            if not cands:
                return None
            parts = cands[0].get("content", {}).get("parts", [])
            if not parts:
                return None
            text = parts[0].get("text", "").strip()
            if text.startswith("```"):
                _parts = text.split("```")
                if len(_parts) >= 2:
                    text = _parts[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            # FIX_NB_A1_PARSER: hardened JSON parsing (replaces A2)
            parsed = self._robust_json_parse(text)
            if parsed is not None:
                try:
                    paper_gemini_call(
                        call_site=f"news_brain.{getattr(self, 'module', 'unknown')}",
                        model=_pt_model_used,
                        tokens_in=_pt_prompt_tokens,
                        tokens_out=max(1, len(text) // 4) if text else 0,
                        latency_ms=int((time.time() - _pt_start) * 1000),
                        cached=False,
                        prompt_hash=_pt_prompt_hash,
                        response_excerpt=(text[:500] if text else ""),
                        meta={"outcome": "success_primary_parse"},
                    )
                except Exception:
                    pass
                return parsed
            _retry_text = self._gemini_retry_shorter(prompt, _key)
            if _retry_text:
                parsed = self._robust_json_parse(_retry_text)
                if parsed is not None:
                    log.info(f"NewsBrain [{self.module}]: A1 retry-shorter recovered JSON")
                    try:
                        paper_gemini_call(
                            call_site=f"news_brain.{getattr(self, 'module', 'unknown')}",
                            model=_pt_model_used,
                            tokens_in=_pt_prompt_tokens,
                            tokens_out=max(1, len(_retry_text) // 4) if _retry_text else 0,
                            latency_ms=int((time.time() - _pt_start) * 1000),
                            cached=False,
                            prompt_hash=_pt_prompt_hash,
                            response_excerpt=(_retry_text[:500] if _retry_text else ""),
                            meta={"outcome": "success_retry_shorter"},
                        )
                    except Exception:
                        pass
                    return parsed
            log.error(f"NewsBrain [{self.module}]: Gemini JSON parse failed (len={len(text)}) after all repairs")
            try:
                paper_gemini_call(
                    call_site=f"news_brain.{getattr(self, 'module', 'unknown')}",
                    model=_pt_model_used,
                    tokens_in=_pt_prompt_tokens,
                    tokens_out=max(1, len(text) // 4) if text else 0,
                    latency_ms=int((time.time() - _pt_start) * 1000),
                    cached=False,
                    prompt_hash=_pt_prompt_hash,
                    response_excerpt=(text[:500] if text else ""),
                    error="json_parse_failed_after_repairs",
                    meta={"outcome": "fail_parse"},
                )
            except Exception:
                pass
            return None
        except Exception as e:
            log.error(f"NewsBrain [{self.module}]: Gemini response processing failed: {e}")
            try:
                paper_gemini_call(
                    call_site=f"news_brain.{getattr(self, 'module', 'unknown')}",
                    model=_pt_model_used,
                    tokens_in=_pt_prompt_tokens,
                    tokens_out=0,
                    latency_ms=int((time.time() - _pt_start) * 1000),
                    cached=False,
                    prompt_hash=_pt_prompt_hash,
                    response_excerpt="",
                    error=str(e)[:300],
                    meta={"outcome": "fail_exception"},
                )
            except Exception:
                pass
            return None

    def _robust_json_parse(self, text):
        """FIX_NB_A1_PARSER: multi-strategy JSON parser. Returns dict or None."""
        if not text:
            return None
        import re as _nbre
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        _m = _nbre.search(r'\{[\s\S]*\}', text)
        candidate = _m.group(0) if _m else text
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass
        repaired = self._repair_truncated_string(candidate)
        if repaired:
            try:
                return json.loads(repaired)
            except json.JSONDecodeError:
                pass
        _tc = _nbre.sub(r',(\s*[\}\]])', r'\1', candidate)
        try:
            return json.loads(_tc)
        except json.JSONDecodeError:
            pass
        source = repaired or candidate
        for _suffix in ('"', '",', '"}', '"}}', '"]', '"]}', '"}]}', '",}', '",]', '"}}}'):
            try:
                return json.loads(source + _suffix)
            except json.JSONDecodeError:
                continue
        try:
            _balanced = self._balance_brackets(source)
            if _balanced and _balanced != source:
                return json.loads(_balanced)
        except json.JSONDecodeError:
            pass
        return None

    def _repair_truncated_string(self, s):
        """FIX_NB_A1_PARSER: close unterminated string at end of JSON."""
        if not s:
            return None
        in_string = False
        escape = False
        for ch in s:
            if escape:
                escape = False
                continue
            if ch == '\\':
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
        if in_string:
            return self._balance_brackets(s + '"')
        return None

    def _balance_brackets(self, s):
        """FIX_NB_A1_PARSER: balance braces and brackets at end."""
        if not s:
            return None
        in_string = False
        escape = False
        stack = []
        for ch in s:
            if escape:
                escape = False
                continue
            if ch == '\\':
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch in '{[':
                stack.append(ch)
            elif ch in '}]':
                if stack and ((ch == '}' and stack[-1] == '{') or (ch == ']' and stack[-1] == '[')):
                    stack.pop()
        closers = ''
        for opener in reversed(stack):
            closers += '}' if opener == '{' else ']'
        return s + closers

    def _gemini_retry_shorter(self, original_prompt, key):
        """FIX_NB_A1_PARSER: retry with VALID JSON ONLY directive."""
        try:
            _retry_prompt = original_prompt + "\n\n---\nCRITICAL: Previous response had invalid JSON. Respond ONLY with valid compact JSON. Keep reasoning under 200 chars. No markdown. Just the object."
            body = {
                "contents": [{"parts": [{"text": _retry_prompt}]}],
                "generationConfig": {
                    "temperature": 0.1,
                    "maxOutputTokens": 2000,
                    "responseMimeType": "application/json",
                    "thinkingConfig": {"thinkingBudget": 0},  # PATCH_V68_NO_THINK
                }
            }
            resp = requests.post(GEMINI_FALLBACK_URL, params={"key": key}, json=body, timeout=GEMINI_TIMEOUT_SEC)
            if resp.status_code != 200:
                return None
            data = resp.json()
            cands = data.get("candidates", [])
            if not cands:
                return None
            parts = cands[0].get("content", {}).get("parts", [])
            if not parts:
                return None
            text = parts[0].get("text", "").strip()
            if text.startswith("```"):
                _parts = text.split("```")
                if len(_parts) >= 2:
                    text = _parts[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            return text
        except Exception as e:
            log.warning(f"NewsBrain [{self.module}]: A1 retry-shorter exception: {e}")
            return None

    def _build_scout_validation_prompt(self, candidate, article_body, cross_sources):
        # FIX_NB_A1
        _univ_list = sorted(list(self.universe))
        _univ_size = len(_univ_list)
        # PATCH_V64_FULL_UNIVERSE: send ALL symbols to Gemini, not first 200 alphabetical.
        # Old code was [:200] which truncated at AAATECH..ADFFOODS, causing Gemini to
        # falsely reject RELIANCE/ONGC/TECHM/etc as "not in tradeable universe".
        # Universe ~3000 symbols ≈ 18K chars ≈ 5K tokens — trivial in Gemini's 1M context.
        sample = ", ".join(_univ_list)
        body_safe = article_body[:FULL_ARTICLE_MAX_CHARS] if article_body else "[NO FULL ARTICLE AVAILABLE]"
        scout_symbol = candidate.get("symbol", "UNKNOWN")
        scout_direction = candidate.get("direction", "UNKNOWN")
        scout_source = candidate.get("source", "UNKNOWN")
        scout_catalyst = candidate.get("catalyst", "")

        if cross_sources:
            cross_block = ""
            for i, src in enumerate(cross_sources, 1):
                cross_block += f"\nSource {i} ({src['feed']}):\nTitle: {src['title']}\nSnippet: {src['snippet'][:800]}\n"
        else:
            cross_block = "\n[NO CROSS-SOURCES FOUND]\n"

        if self.direction_mode == "BULLISH_ONLY":
            direction_rules = """DIRECTION RULES (EQUITY CNC delivery — buy only):
- Return ONLY BULLISH candidates (we cannot short in CNC).
- If the article is BEARISH for a stock, return validated=false with reasoning.
- Do not flag stocks as BEARISH — they cannot be actioned."""
            trade_context = "Indian NSE equity CNC delivery (buy and hold)"
        else:
            direction_rules = """DIRECTION RULES (F&O options):
- Return BULLISH (for CE) or BEARISH (for PE).
- Both directions are actionable."""
            trade_context = "Indian NSE F&O (options trading, CE/PE)"

        citation_rule = ""
        citation_json = ""
        if self.require_sentence_citation:
            citation_rule = """
- SENTENCE CITATION REQUIRED: For each recommended stock, quote the EXACT sentence
  from the original article that justifies your direction. If you cannot find a
  specific sentence, return validated=false. No vibes-based decisions."""
            citation_json = ',\n      "justifying_sentence": "exact quote from article"'

        return f"""You are a senior Indian {trade_context} analyst. A keyword scout flagged a candidate. VALIDATE or REJECT with rigor.

SCOUT CLAIM:
- Source: {scout_source}
- Symbol: {scout_symbol}
- Direction: {scout_direction}
- Catalyst: {scout_catalyst}

ORIGINAL ARTICLE:
{body_safe}

CROSS-SOURCE EVIDENCE:
{cross_block}

YOUR JOB:
1. Read the full article. Understand the ACTUAL story.
2. Cross-check other sources. Do they confirm?
3. Is the scout's keyword-match correct, OR a false positive?
4. If scout is WRONG, suggest correct stocks (if any).
5. Tradeable universe sample (may be partial — trust symbol if it looks like a valid NSE stock): {sample}

{direction_rules}{citation_rule}

RESPOND IN PURE JSON:
{{
  "validated": true,
  "confidence": "HIGH",
  "cross_sources_agree": 2,
  "actual_stocks": [
    {{"symbol": "SYM", "direction": "BULLISH", "conviction": 75, "rationale": "why"{citation_json}}}
  ],
  "reasoning": "2-3 sentences"
}}

Rules:
- validated=true ONLY IF scout's claim (or corrected version) is supported by article AND cross-source.
- confidence: HIGH if 2+ cross-sources agree, MEDIUM if 1, LOW if 0.
- If not tradeable, return validated=false.
- Be skeptical. When in doubt, REJECT."""

    def validate_scout_candidate(self, candidate, news_item=None):
        if not candidate:
            return []

        scout_symbol = candidate.get("symbol", "")
        scout_direction = candidate.get("direction", "")
        scout_source = candidate.get("source", "")

        if news_item is None:
            news_item = {}
        title = news_item.get("title") or candidate.get("catalyst", "")
        link = news_item.get("link", "")
        rss_summary = news_item.get("summary", "")
        source_feed = news_item.get("source_feed", scout_source)

        article_body = rss_summary
        fetched_full = False
        pub_date = None
        if link:
            full, pub_date = self._fetch_full_article(link)
            if full and len(full) > len(rss_summary or ""):
                article_body = full
                fetched_full = True

        if self.max_article_age_hours > 0 and not self._is_article_fresh(pub_date):
            age_note = f"age > {self.max_article_age_hours}h" if pub_date else "no date"
            log.info(f"NewsBrain v4 [{self.module}]: REJECT {scout_source} {scout_symbol} — stale article ({age_note})")
            return []

        cache_key = self._hash_scout(candidate, article_body or "")
        # FIX_NB_A5: enforce cache TTL on read
        if cache_key in self._scout_cache:
            _entry = self._scout_cache[cache_key]
            _entry_ts = _entry.get("ts", 0)
            if time.time() - _entry_ts < _CACHE_MAX_AGE_HOURS * 3600:
                return _entry.get("candidates", [])
            with self._scout_cache_lock:  # PATCH_V62
                self._scout_cache.pop(cache_key, None)

        if not article_body or len(article_body) < 100:
            log.warning(
                f"NewsBrain v4 [{self.module}]: REJECT {scout_source} {scout_symbol} {scout_direction} — "
                f"no article body (link={link[:60] if link else 'NONE'})"
            )
            with self._scout_cache_lock:  # PATCH_V62
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        cross_sources = self._cross_verify_rss(title, article_body, exclude_feed=source_feed)

        # FIX_NB_C1 + PATCH_V64_AUTHORITATIVE_EXPAND: source-authority bypass
        # Authoritative sources (BSE/NSE filings, SEBI, macro) ARE ground truth
        # V64 added: BROKERAGE (tier-1 analyst calls = authoritative single-source),
        #            PROMOTER_BUY (insider filing already authoritative).
        # NEWS still requires cross-source as spam guard.
        _AUTHORITATIVE = ("FILING", "SEBI", "MACRO", "EARNINGS", "RESULT",
                          "BONUS", "DIVIDEND", "BUYBACK", "FOMC", "RBI", "BSE", "NSE",
                          "BROKERAGE", "PROMOTER_BUY", "PROMOTER")
        _source_upper = (scout_source or "").upper()
        _is_authoritative = any(tag in _source_upper for tag in _AUTHORITATIVE)
        _required_cross = 0 if _is_authoritative else self.require_cross_sources

        if _required_cross > 0 and len(cross_sources) < _required_cross:
            log.info(
                f"NewsBrain v4 [{self.module}]: REJECT {scout_source} {scout_symbol} — "
                f"only {len(cross_sources)} cross-sources (need {_required_cross})"
            )
            with self._scout_cache_lock:  # PATCH_V62
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []
        if _is_authoritative and len(cross_sources) == 0:
            log.info(
                f"NewsBrain v4 [{self.module}]: FIX_NB_C1 {scout_source} {scout_symbol} "
                f"authoritative source — cross-verify skipped"
            )

        log.info(
            f"NewsBrain v4 [{self.module}]: validating {scout_source} ({scout_symbol} {scout_direction}) — "
            f"full={'yes' if fetched_full else 'no'}, cross={len(cross_sources)}, "
            f"pub_date={'yes' if pub_date else 'no'}"
        )

        # FIX_V54_FINBERT + PATCH_V62_PARALLEL: local sentiment (locked, PyTorch not thread-safe)
        with self._finbert_lock:
            _fb_label, _fb_conf = _finbert_score(article_body)
        if _fb_label is not None:
            log.info(f"NewsBrain v5 [{self.module}]: FinBERT {scout_symbol} "
                     f"label={_fb_label} conf={_fb_conf:.2f}")
            # FIX_NB_A3: only reject hard NEGATIVE; neutrals go to Gemini
            if self.direction_mode == "BULLISH_ONLY":
                if _fb_label == "negative" and _fb_conf >= 0.85:
                    log.info(f"NewsBrain v5 [{self.module}]: FIX_NB_A3_FINBERT_REJECT {scout_symbol} "
                             f"— hard negative {_fb_conf:.2f} (Gemini SKIPPED)")
                    with self._scout_cache_lock:  # V77_FIX3a
                        self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                        self._save_scout_cache()
                    return []
            # V71 FINBERT_CALIBRATION: do NOT reject on NEUTRAL, send to Gemini instead
            #   NEUTRAL high-conf = "FinBERT cannot decide" not "stock is bad"
            # F&O (BOTH): only veto on extreme confidence + low-quality scout + non-index
            else:
                _is_index = scout_symbol in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY")
                _high_quality_scout = (len(cross_sources) >= 3 and pub_date and fetched_full)
                # NEUTRAL no longer rejects — Gemini gets to decide
                # Contradiction only with very high confidence AND low-quality scout AND non-index
                if (scout_direction == "BULLISH"
                    and _fb_label == "negative"
                    and _fb_conf >= 0.92
                    and not _high_quality_scout
                    and not _is_index):
                    log.info(f"NewsBrain v5 [{self.module}]: V71_FINBERT_CONTRADICT {scout_symbol} "
                             f"— scout BULLISH but FinBERT negative {_fb_conf:.2f} (low-quality scout)")
                    with self._scout_cache_lock:  # V77_FIX3b
                        self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                        self._save_scout_cache()
                    return []

        prompt = self._build_scout_validation_prompt(candidate, article_body, cross_sources)
        result = self._call_gemini(prompt)

        if not result:
            log.warning(f"NewsBrain v4 [{self.module}]: Gemini failed for {scout_symbol} — REJECTING")
            with self._scout_cache_lock:  # PATCH_V62
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        # PATCH_V72_LIST_UNWRAP: Gemini wraps verdicts in list-of-1; recover instead of reject
        if isinstance(result, list):
            if len(result) == 1 and isinstance(result[0], dict):
                log.info(f"NewsBrain v4 [{self.module}]: V72 unwrapped list-of-1 for {scout_symbol}")
                result = result[0]
            else:
                log.warning(f"NewsBrain v4 [{self.module}]: V72 unhandled list-of-{len(result)} for {scout_symbol} — REJECTING. Sample: {str(result)[:150]}")
                with self._scout_cache_lock:  # V77_FIX3c
                    self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                    self._save_scout_cache()
                return []
        # PATCH_V71_RESILIENCE: guard against Gemini returning a list/string instead of dict.
        if not isinstance(result, dict):
            log.warning(f"NewsBrain v4 [{self.module}]: Gemini returned {type(result).__name__} not dict for {scout_symbol} — REJECTING. Sample: {str(result)[:150]}")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        validated_flag = result.get("validated", False)
        confidence = result.get("confidence", "LOW")
        cross_agree = int(result.get("cross_sources_agree", 0))
        reasoning = result.get("reasoning", "")

        if not validated_flag:
            log.info(f"NewsBrain v4 [{self.module}]: REJECTED {scout_source} {scout_symbol} — {reasoning[:150]}")
            with self._scout_cache_lock:  # PATCH_V62
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        validated_list = []
        for s in result.get("actual_stocks", []):
            # PATCH_V67: guard against Gemini returning malformed list (strings vs dicts)
            if not isinstance(s, dict):
                log.warning(f"NewsBrain v4 [{self.module}]: skipping non-dict actual_stocks entry: {type(s).__name__}={str(s)[:80]}")
                continue
            sym = s.get("symbol", "").strip().upper()
            direction = s.get("direction", "").upper()
            conviction = int(s.get("conviction", 0))
            rationale = s.get("rationale", "")
            citation = s.get("justifying_sentence", "")

            if self.universe and sym not in self.universe:
                log.warning(f"NewsBrain v4 [{self.module}]: REJECTED hallucination '{sym}' not in universe")
                continue

            if self.direction_mode == "BULLISH_ONLY" and direction != "BULLISH":
                log.info(f"NewsBrain v4 [{self.module}]: skipping {sym} {direction} — equity bullish only")
                continue
            if direction not in ("BULLISH", "BEARISH"):
                continue

            if conviction < self.min_conviction:
                log.info(f"NewsBrain v4 [{self.module}]: skipping {sym} — conviction {conviction} < {self.min_conviction}")
                continue

            if self.require_sentence_citation:
                if not citation or len(citation.strip()) < 20:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — no justifying sentence cited")
                    continue
                # FIX_NB_B4: word-overlap match instead of brittle prefix match
                _cit_words = set(_re.findall(r'\w+', citation.lower()))
                _body_words = set(_re.findall(r'\w+', article_body.lower()))
                _overlap = len(_cit_words & _body_words)
                _cit_total = max(1, len(_cit_words))
                _overlap_ratio = _overlap / _cit_total
                if len(_cit_words) < 4:
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — citation too short ({len(_cit_words)} words)")
                    continue
                if _overlap_ratio < 0.30:  # V74: relaxed from 0.50
                    log.warning(f"NewsBrain v4 [{self.module}]: REJECT {sym} — citation overlap {_overlap_ratio:.0%} < 30%")  # V77_FIX4
                    continue

            corrected = (sym != scout_symbol or direction != scout_direction)
            vc = {
                "symbol": sym,
                "direction": direction,
                "score": conviction,
                "catalyst": f"VALIDATED_{scout_source}: {title[:80]}",
                "source": f"VALIDATED_{scout_source}",
                "scout_source": scout_source,
                "scout_symbol": scout_symbol,
                "scout_direction": scout_direction,
                "corrected": corrected,
                "validated": True,
                "confidence": confidence,
                "cross_sources_count": cross_agree,
                "reasoning": rationale,
                "gemini_reasoning": reasoning,
                "justifying_sentence": citation if self.require_sentence_citation else "",
                "timestamp": datetime.now().isoformat(),
                "article_fetched": fetched_full,
                "module": self.module,
                "is_index": sym in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"),
            }
            validated_list.append(vc)
            with self._recent_lock:  # PATCH_V62
                self._recent_candidates.append((time.time(), sym, direction, f"VALIDATED_{scout_source}"))
            tag = "CORRECTED" if corrected else "CONFIRMED"
            log.info(
                f"NewsBrain v4 [{self.module}]: [{tag}] {scout_source}->{sym} {direction} "
                f"conv={conviction} conf={confidence} src={cross_agree}"
            )

        with self._scout_cache_lock:  # PATCH_V62
            self._scout_cache[cache_key] = {"ts": time.time(), "candidates": validated_list}
            self._save_scout_cache()
        return validated_list

    # ================================================================
    # PATCH_V62_PARALLEL: batch validation with ThreadPoolExecutor
    # Existing validate_scout_candidate() stays unchanged (backward compat).
    # New method accepts list of (candidate, news_item) tuples and processes
    # them in parallel. 5 workers default - safe below Tier 1 1000 RPM cap.
    # ================================================================
    def validate_scout_candidates_parallel(self, candidate_news_pairs, max_workers=5):
        """Parallel validation of multiple scout candidates.
        Args:
            candidate_news_pairs: list of (candidate_dict, news_item_dict) tuples
            max_workers: concurrent Gemini calls (default 5, max safe 10 at Tier 1)
        Returns:
            flat list of validated candidates (same format as validate_scout_candidate)
        """
        if not candidate_news_pairs:
            return []
        try:
            from concurrent.futures import ThreadPoolExecutor, as_completed
        except ImportError:
            log.error(f"NewsBrain [{self.module}]: concurrent.futures unavailable - falling back to sequential")
            results = []
            for cand, news in candidate_news_pairs:
                try:
                    results.extend(self.validate_scout_candidate(cand, news))
                except Exception as _se:
                    log.error(f"NewsBrain [{self.module}]: sequential fallback error: {_se}")
            return results

        log.info(f"NewsBrain [{self.module}]: PATCH_V62 parallel validation of {len(candidate_news_pairs)} items with {max_workers} workers")
        results = []
        _start = time.time()
        with ThreadPoolExecutor(max_workers=max_workers, thread_name_prefix="NBValidator") as executor:
            futures = {
                executor.submit(self.validate_scout_candidate, cand, news): (cand, news)
                for cand, news in candidate_news_pairs
            }
            for future in as_completed(futures):
                cand, news = futures[future]
                _sym = cand.get("symbol", "?")
                try:
                    validated = future.result(timeout=120)  # hard timeout per candidate
                    if validated:
                        results.extend(validated)
                except Exception as _fe:
                    log.error(f"NewsBrain [{self.module}]: parallel validation failed for {_sym}: {_fe}")
        _elapsed = time.time() - _start
        log.info(f"NewsBrain [{self.module}]: PATCH_V62 parallel done in {_elapsed:.1f}s, {len(results)} validated from {len(candidate_news_pairs)} scouts")
        return results

    # ─────────────────────────────────────────────────────────────────────────
    # PATCH_V68_LLM_FIRST_DECISION
    # ─────────────────────────────────────────────────────────────────────────
    # New decision-mode flow. LLM reads full article and decides which stocks
    # to trade, in which direction, with what conviction. NO pre-decision from
    # keyword scout. Keyword scout becomes a discovery filter only.
    # Reuses everything from validate_scout_candidate() except the prompt:
    #   - Same article fetcher (trafilatura)
    #   - Same FinBERT prescreen
    #   - Same cross-source verification
    #   - Same universe filter / citation requirement / cache
    #   - Same parallel executor
    # ─────────────────────────────────────────────────────────────────────────

    def _build_decision_prompt(self, hints, article_body, cross_sources, title, source_tag):
        """PATCH_V68: LLM is decider, not validator.
        hints = list of stock symbols the keyword scout thinks MIGHT be affected.
                LLM is FREE to ignore them, override, or add others.
        """
        _univ_list = sorted(list(self.universe))
        sample = ", ".join(_univ_list)
        body_safe = article_body[:FULL_ARTICLE_MAX_CHARS] if article_body else "[NO FULL ARTICLE AVAILABLE]"

        if cross_sources:
            cross_block = ""
            for i, src in enumerate(cross_sources, 1):
                cross_block += f"\nSource {i} ({src['feed']}):\nTitle: {src['title']}\nSnippet: {src['snippet'][:800]}\n"
        else:
            cross_block = "\n[NO CROSS-SOURCES FOUND]\n"

        if hints:
            hint_block = ", ".join(hints[:30])
            hint_note = f"DISCOVERY HINTS (keyword scout flagged these stocks as possibly relevant — you may agree, override, ignore, or expand):\n  {hint_block}"
        else:
            hint_note = "DISCOVERY HINTS: [none — pick stocks freely from article]"

        if self.direction_mode == "BULLISH_ONLY":
            direction_rules = """DIRECTION RULES (EQUITY CNC delivery — buy only):
- Return ONLY BULLISH candidates (we cannot short in CNC).
- If article is BEARISH for a stock, do NOT include it (no actionable trade).
- Multiple bullish stocks per article are allowed."""
            trade_context = "Indian NSE equity CNC delivery (buy and hold, long-only)"
        else:
            direction_rules = """DIRECTION RULES (F&O options):
- Return BOTH BULLISH (-> buy CE) and BEARISH (-> buy PE) candidates.
- BEARISH is fully tradeable via puts — do NOT skip bearish stocks."""
            trade_context = "Indian NSE F&O (options trading, CE for bullish PE for bearish)"

        citation_rule = ""
        citation_json = ""
        if self.require_sentence_citation:
            citation_rule = """
- SENTENCE CITATION REQUIRED: For each stock you recommend, quote the EXACT sentence
  from the original article that justifies the direction. No vibes-based decisions."""
            citation_json = ',\n      "justifying_sentence": "exact quote from article"'

        return f"""You are a senior Indian {trade_context} analyst. Read this article carefully and decide which trades make sense. You are the DECIDER — there is no scout claim to rubber-stamp. Form your own independent opinion based on the article content.

ARTICLE TITLE: {title}
SOURCE: {source_tag}

FULL ARTICLE BODY:
{body_safe}

CROSS-SOURCE EVIDENCE (other outlets covering same story):
{cross_block}

{hint_note}

YOUR JOB:
1. READ the full article. Understand the actual story, not the headline.
2. Identify which Indian NSE-listed stocks are GENUINELY affected by this news.
3. For each affected stock, decide direction (BULLISH or BEARISH) based on what the article says.
4. Conviction score 0-100 reflects how confident you are AND how strong the price impact will be.
5. Cross-check other sources. Higher cross-source agreement = higher conviction.
6. If article is irrelevant, gossipy, speculative, or doesn't actually move stock prices, return decided=false.
7. Discovery hints are SUGGESTIONS only — feel free to ignore them, override their direction, add stocks they missed, drop stocks the article doesn't actually mention.

Tradeable universe (sample): {sample}
Only return symbols that exist in NSE/F&O. Hallucinated symbols will be silently dropped.

{direction_rules}{citation_rule}

RESPOND IN PURE JSON:
{{
  "decided": true,
  "confidence": "HIGH",
  "cross_sources_agree": 2,
  "stocks": [
    {{"symbol": "SYM", "direction": "BULLISH", "conviction": 75, "rationale": "why"{citation_json}}}
  ],
  "reasoning": "2-3 sentences summarizing your decision"
}}

Rules:
- decided=true ONLY IF article actually has tradeable implications (not gossip/rumour/speculation).
- confidence: HIGH if 2+ cross-sources agree, MEDIUM if 1, LOW if 0.
- conviction: scale 0-100. 80+ = strong; 60-79 = moderate; <60 = weak (probably skip).
- Be skeptical of speculative or unsourced claims. When article quality is poor, return decided=false.
- Do NOT invent stocks. If unsure whether a symbol is correct, omit it.
- Multiple stocks per article OK if all genuinely affected."""

    def read_and_decide(self, news_item, hints=None, source_tag="NEWS"):
        """PATCH_V68_LLM_FIRST_DECISION: LLM reads article and decides trades."""
        if not news_item:
            return []

        title = news_item.get("title", "")
        link = news_item.get("link", "")
        rss_summary = news_item.get("summary", "")
        source_feed = news_item.get("source_feed", source_tag)
        hints = hints or []

        article_body = rss_summary
        fetched_full = False
        pub_date = None
        if link:
            full, pub_date = self._fetch_full_article(link)
            if full and len(full) > len(rss_summary or ""):
                article_body = full
                fetched_full = True

        if self.max_article_age_hours > 0 and not self._is_article_fresh(pub_date):
            age_note = f"age > {self.max_article_age_hours}h" if pub_date else "no date"
            log.info(f"NewsBrain v68 [{self.module}]: REJECT {source_tag} {title[:60]} — stale ({age_note})")
            return []

        _hint_str = ",".join(sorted(hints))[:100]
        _cache_payload = {"symbol": "DECISION", "direction": "BOTH",
                          "source": source_tag, "hints": _hint_str}
        cache_key = self._hash_scout(_cache_payload, article_body or "")
        if cache_key in self._scout_cache:
            _entry = self._scout_cache[cache_key]
            if time.time() - _entry.get("ts", 0) < _CACHE_MAX_AGE_HOURS * 3600:
                return _entry.get("candidates", [])
            with self._scout_cache_lock:
                self._scout_cache.pop(cache_key, None)

        if not article_body or len(article_body) < 100:
            log.warning(f"NewsBrain v68 [{self.module}]: REJECT {source_tag} — no article body (link={link[:60] if link else 'NONE'})")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        cross_sources = self._cross_verify_rss(title, article_body, exclude_feed=source_feed)

        if self.require_cross_sources > 0 and len(cross_sources) < self.require_cross_sources:
            log.info(f"NewsBrain v68 [{self.module}]: REJECT {source_tag} — only {len(cross_sources)} cross-sources (need {self.require_cross_sources})")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        log.info(f"NewsBrain v68 [{self.module}]: deciding {source_tag} '{title[:60]}' — full={'yes' if fetched_full else 'no'}, cross={len(cross_sources)}, hints={len(hints)}")

        with self._finbert_lock:
            _fb_label, _fb_conf = _finbert_score(article_body)
        if _fb_label is not None:
            log.info(f"NewsBrain v68 [{self.module}]: FinBERT article label={_fb_label} conf={_fb_conf:.2f}")
            if _fb_label == "neutral" and _fb_conf >= 0.95 and not hints:
                log.info(f"NewsBrain v68 [{self.module}]: SKIP — FinBERT very-confident neutral, no hints")
                with self._scout_cache_lock:
                    self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                    self._save_scout_cache()
                return []

        prompt = self._build_decision_prompt(hints, article_body, cross_sources, title, source_tag)
        result = self._call_gemini(prompt)

        if not result:
            log.warning(f"NewsBrain v68 [{self.module}]: Gemini failed for '{title[:60]}'")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        # PATCH_V72_LIST_UNWRAP: Gemini wraps verdicts in list-of-1; recover instead of reject
        if isinstance(result, list):
            if len(result) == 1 and isinstance(result[0], dict):
                log.info(f"NewsBrain v68 [{self.module}]: V72 unwrapped list-of-1 for {title[:60]}")
                result = result[0]
            else:
                log.warning(f"NewsBrain v68 [{self.module}]: V72 unhandled list-of-{len(result)} for {title[:60]} — REJECTING. Sample: {str(result)[:150]}")
                with self._scout_cache_lock:
                    self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
                return []
        # PATCH_V71_RESILIENCE: guard against Gemini returning a list/string instead of dict.
        if not isinstance(result, dict):
            log.warning(f"NewsBrain v68 [{self.module}]: Gemini returned {type(result).__name__} not dict for '{title[:60]}' — skipping. Sample: {str(result)[:150]}")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        decided_flag = result.get("decided", False)
        confidence = result.get("confidence", "LOW")
        cross_agree = int(result.get("cross_sources_agree", 0))
        reasoning = result.get("reasoning", "")

        if not decided_flag:
            log.info(f"NewsBrain v68 [{self.module}]: NO_DECISION {source_tag} — {reasoning[:150]}")
            with self._scout_cache_lock:
                self._scout_cache[cache_key] = {"ts": time.time(), "candidates": []}
                self._save_scout_cache()
            return []

        decided_list = []
        for s in result.get("stocks", []):
            if not isinstance(s, dict):
                log.warning(f"NewsBrain v68 [{self.module}]: skipping non-dict stocks entry: {type(s).__name__}={str(s)[:80]}")
                continue
            sym = s.get("symbol", "").strip().upper()
            direction = s.get("direction", "").upper()
            conviction = int(s.get("conviction", 0))
            rationale = s.get("rationale", "")
            citation = s.get("justifying_sentence", "")

            if self.universe and sym not in self.universe:
                log.warning(f"NewsBrain v68 [{self.module}]: REJECTED hallucination '{sym}' not in universe")
                continue

            if self.direction_mode == "BULLISH_ONLY" and direction != "BULLISH":
                log.info(f"NewsBrain v68 [{self.module}]: skipping {sym} {direction} — equity bullish only")
                continue
            if direction not in ("BULLISH", "BEARISH"):
                continue

            if conviction < self.min_conviction:
                log.info(f"NewsBrain v68 [{self.module}]: skipping {sym} — conviction {conviction} < {self.min_conviction}")
                continue

            if self.require_sentence_citation:
                if not citation or len(citation.strip()) < 20:
                    log.warning(f"NewsBrain v68 [{self.module}]: REJECT {sym} — no justifying sentence cited")
                    continue
                _cit_words = set(_re.findall(r'\w+', citation.lower()))
                _body_words = set(_re.findall(r'\w+', article_body.lower()))
                _overlap = len(_cit_words & _body_words)
                _cit_total = max(1, len(_cit_words))
                _overlap_ratio = _overlap / _cit_total
                if len(_cit_words) < 4:
                    log.warning(f"NewsBrain v68 [{self.module}]: REJECT {sym} — citation too short ({len(_cit_words)} words)")
                    continue
                if _overlap_ratio < 0.30:  # V74: relaxed from 0.50
                    log.warning(f"NewsBrain v68 [{self.module}]: REJECT {sym} — citation overlap {_overlap_ratio:.0%} < 30%")  # V77_FIX4
                    continue

            in_hints = sym in hints
            vc = {
                "symbol": sym,
                "direction": direction,
                "score": conviction,
                "catalyst": f"V68_{source_tag}: {title[:80]}",
                "source": f"V68_{source_tag}",
                "scout_source": source_tag,
                "scout_symbol": "",
                "scout_direction": "",
                "corrected": False,
                "validated": True,
                "decided": True,
                "in_hints": in_hints,
                "confidence": confidence,
                "cross_sources_count": cross_agree,
                "reasoning": rationale,
                "gemini_reasoning": reasoning,
                "justifying_sentence": citation if self.require_sentence_citation else "",
                "timestamp": datetime.now().isoformat(),
                "article_fetched": fetched_full,
                "module": self.module,
            }
            decided_list.append(vc)
            with self._recent_lock:
                self._recent_candidates.append((time.time(), sym, direction, f"V68_{source_tag}"))
            tag = "AGREED" if in_hints else "INDEPENDENT"
            log.info(f"NewsBrain v68 [{self.module}]: [{tag}] {source_tag}->{sym} {direction} conv={conviction} conf={confidence} src={cross_agree}")

        with self._scout_cache_lock:
            self._scout_cache[cache_key] = {"ts": time.time(), "candidates": decided_list}
            self._save_scout_cache()
        return decided_list

    def read_and_decide_parallel(self, news_items_with_hints, max_workers=5):
        """PATCH_V68_LLM_FIRST_DECISION parallel version."""
        if not news_items_with_hints:
            return []
        try:
            from concurrent.futures import ThreadPoolExecutor, as_completed
        except ImportError:
            log.error(f"NewsBrain v68 [{self.module}]: concurrent.futures unavailable — sequential fallback")
            results = []
            for news, hints, tag in news_items_with_hints:
                try:
                    results.extend(self.read_and_decide(news, hints, tag))
                except Exception as _e:
                    log.error(f"NewsBrain v68 [{self.module}]: sequential error: {_e}")
            return results

        log.info(f"NewsBrain v68 [{self.module}]: parallel decision on {len(news_items_with_hints)} articles, {max_workers} workers")
        results = []
        _start = time.time()
        with ThreadPoolExecutor(max_workers=max_workers, thread_name_prefix="NBDecider") as executor:
            future_to_item = {
                executor.submit(self.read_and_decide, news, hints, tag): (news, hints, tag)
                for news, hints, tag in news_items_with_hints
            }
            for fut in as_completed(future_to_item):
                try:
                    results.extend(fut.result())
                except Exception as _e:
                    news, hints, tag = future_to_item[fut]
                    log.error(f"NewsBrain v68 [{self.module}]: decision error for {tag} {news.get('title','')[:60]}: {_e}")
        _dur = time.time() - _start
        log.info(f"NewsBrain v68 [{self.module}]: parallel decision done in {_dur:.1f}s, {len(results)} candidates")
        return results

    # ─── END PATCH_V68_LLM_FIRST_DECISION ───

    # ─── V83: read-only helpers for entry-time guards ────────────────────────
    # Used by gir.enter() for V83_CONTRADICT and V83_REFLEX guards.
    # Read-only access to _scout_cache (no modification, respects lock).
    def get_recent_decisions(self, symbol, hours=4):
        try:
            import time as _t
            cutoff = _t.time() - hours * 3600
            out = []
            with self._scout_cache_lock:
                for _k, _entry in self._scout_cache.items():
                    if _entry.get("ts", 0) < cutoff:
                        continue
                    for c in _entry.get("candidates", []):
                        if c.get("symbol") == symbol:
                            out.append(c)
            return out
        except Exception:
            return []

    def get_candidates_by_catalyst(self, catalyst_prefix, hours=4):
        try:
            import time as _t
            if not catalyst_prefix:
                return []
            cutoff = _t.time() - hours * 3600
            out = []
            cp = catalyst_prefix[:80]
            with self._scout_cache_lock:
                for _k, _entry in self._scout_cache.items():
                    if _entry.get("ts", 0) < cutoff:
                        continue
                    for c in _entry.get("candidates", []):
                        if c.get("catalyst", "")[:80] == cp:
                            out.append(c)
            return out
        except Exception:
            return []

    def is_validated(self, symbol, direction=None, max_age_hours=6):
        """V68: lookup whether symbol+direction was recently validated."""
        if not symbol:
            return False, 0
        symbol = symbol.strip().upper()
        cutoff = time.time() - (max_age_hours * 3600)
        best_conviction = 0
        found = False
        try:
            with self._recent_lock:
                for ts, sym, d, src in self._recent_candidates:
                    if ts < cutoff:
                        continue
                    if sym == symbol:
                        if direction and d != direction.upper():
                            continue
                        found = True
                        break
        except Exception:
            pass
        try:
            with self._scout_cache_lock:
                for _ck, _cv in self._scout_cache.items():
                    if not isinstance(_cv, dict):
                        continue
                    if _cv.get("ts", 0) < cutoff:
                        continue
                    for cand in _cv.get("candidates", []):
                        if not isinstance(cand, dict):
                            continue
                        if cand.get("symbol", "").upper() == symbol:
                            _cd = cand.get("direction", "").upper()
                            if direction and _cd != direction.upper():
                                continue
                            _conv = int(cand.get("score", cand.get("conviction", 0)))
                            if _conv > best_conviction:
                                best_conviction = _conv
                                found = True
        except Exception:
            pass
        return found, best_conviction

    def analyze_news_item(self, title, summary, source_label="NEWS", link=None):
        cand = {
            "symbol": "",
            "direction": "",
            "catalyst": title,
            "source": source_label,
        }
        news_item = {"title": title, "summary": summary, "link": link or "", "source_feed": source_label}
        return self.validate_scout_candidate(cand, news_item)

    def analyze_news_batch(self, news_items):
        all_candidates = []
        for item in news_items:
            title = item.get("title") or item.get("catalyst", "")
            summary = item.get("summary") or item.get("description", "")
            source = item.get("source_feed") or item.get("source", "NEWS")
            link = item.get("link") or item.get("url", "")
            cands = self.analyze_news_item(title, summary, source, link=link)
            all_candidates.extend(cands)
        return all_candidates

    def scan_momentum(self, kite, fno_stocks=None):
        universe = fno_stocks or self.universe
        if not universe or not kite:
            return []
        candidates = []
        symbols = list(universe)
        for i in range(0, len(symbols), 100):
            chunk = symbols[i:i+100]
            quote_keys = [f"NSE:{s}" for s in chunk]
            try:
                quotes = kite.quote(quote_keys)
            except Exception as e:
                continue
            for sym in chunk:
                q = quotes.get(f"NSE:{sym}", {})
                if not q:
                    continue
                ohlc = q.get("ohlc", {})
                close_prev = ohlc.get("close", 0)
                ltp = q.get("last_price", 0)
                volume = q.get("volume", 0)
                if close_prev <= 0 or ltp <= 0:
                    continue
                pct_change = ((ltp - close_prev) / close_prev) * 100
                if abs(pct_change) < MOMENTUM_MIN_PCT:
                    continue
                if volume < 200000:  # V75: 5L -> 2L shares
                    continue
                direction = "BULLISH" if pct_change > 0 else "BEARISH"
                if self.direction_mode == "BULLISH_ONLY" and direction != "BULLISH":
                    continue
                score = min(90, 60 + int(abs(pct_change)))
                candidates.append({
                    "symbol": sym, "direction": direction, "score": score,
                    "catalyst": f"MOMENTUM: {sym} {pct_change:+.1f}% on vol={volume:,}",
                    "source": "MOMENTUM",
                    "reasoning": f"Price action: {pct_change:+.1f}% move with volume {volume:,}",
                    "timestamp": datetime.now().isoformat(),
                })
        return candidates

    def get_candidates(self, news_items=None, kite=None, include_momentum=True):
        all_cands = []
        if news_items:
            all_cands.extend(self.analyze_news_batch(news_items))
        if include_momentum and kite:
            all_cands.extend(self.scan_momentum(kite))
        seen = {}
        for c in all_cands:
            k = (c["symbol"], c["direction"])
            if k not in seen or c["score"] > seen[k]["score"]:
                seen[k] = c
        result = sorted(seen.values(), key=lambda x: x["score"], reverse=True)
        return result
