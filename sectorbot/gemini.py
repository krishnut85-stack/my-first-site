"""Gemini news judge for the Swaminatha face.

Swaminatha reads the FULL text of a corporate announcement and asks Gemini (with
Google Search grounding for real-world context) one disciplined question:

    Is this a genuine, MATERIAL, bullish catalyst worth buying the stock today?

Gemini weighs the event SIZE against the company's scale (e.g. a Rs 459 cr order
vs the company's revenue), whether it's one-off or recurring, and whether it's
likely already priced in. It returns a structured verdict that the bot acts on.

Network is isolated in _http_post so the parsing/judgment logic is unit-tested
offline (inject `_post`). FAIL-SAFE: any error or missing key returns None, and
the caller then does NOT buy (no confident read = no trade).
"""

from __future__ import annotations

import json
import re
import urllib.request
from typing import Optional

from . import config

_ENDPOINT = ("https://generativelanguage.googleapis.com/v1beta/models/"
             "{model}:generateContent?key={key}")

_PROMPT = """You are a disciplined Indian equity analyst. A corporate \
announcement just came for {company} (NSE: {symbol}).

ANNOUNCEMENT:
\"\"\"{news}\"\"\"

Decide whether this is a GENUINE, MATERIAL, BULLISH catalyst worth buying the \
stock today for a short-to-medium swing. Think hard about:
- the SIZE of the order/event vs the company's annual revenue and market cap \
(a small order for a big company is NOT material),
- whether it is one-off or recurring/strategic,
- whether it is likely already known/priced in,
- any red flags or caveats in the text.
Use web search to check the company's scale and recent price action if useful.

Respond with ONLY compact JSON, no prose:
{{"verdict":"bullish|neutral|bearish","material":true|false,\
"confidence":0.0,"reason":"one short sentence"}}"""


def configured() -> bool:
    return bool(config.GEMINI_API_KEY)


def _http_post(payload: dict) -> dict:  # pragma: no cover (network)
    url = _ENDPOINT.format(model=config.GEMINI_MODEL, key=config.GEMINI_API_KEY)
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=config.GEMINI_TIMEOUT) as r:
        return json.loads(r.read())


def _extract_text(resp: dict) -> str:
    """Pull the model's text out of a Gemini generateContent response."""
    try:
        parts = resp["candidates"][0]["content"]["parts"]
        return " ".join(p.get("text", "") for p in parts)
    except (KeyError, IndexError, TypeError):
        return ""


def _extract_json(text: str) -> Optional[dict]:
    """Find the JSON object in the model's reply (it may wrap it in prose/```)."""
    if not text:
        return None
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except ValueError:
        return None


def judge_news(symbol: str, company: str, news: str, _post=None) -> Optional[dict]:
    """Ask Gemini to judge one announcement. Returns
    {verdict, material, confidence, reason} or None on any failure (-> no buy).
    `_post` is injectable for tests (a callable payload -> response dict)."""
    if not config.GEMINI_API_KEY:
        return None
    prompt = _PROMPT.format(company=company or symbol, symbol=symbol,
                            news=(news or "")[:6000])
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2},
    }
    if config.GEMINI_USE_SEARCH:
        payload["tools"] = [{"google_search": {}}]
    try:
        resp = (_post or _http_post)(payload)
        data = _extract_json(_extract_text(resp))
        if not data:
            return None
        return {
            "verdict": str(data.get("verdict", "neutral")).strip().lower(),
            "material": bool(data.get("material", False)),
            "confidence": float(data.get("confidence", 0) or 0),
            "reason": str(data.get("reason", "")).strip()[:160],
        }
    except Exception:  # noqa: BLE001
        return None


def is_buy(verdict: Optional[dict]) -> bool:
    """A confident, material, bullish read is the only thing we act on."""
    return bool(verdict and verdict["verdict"] == "bullish"
                and verdict["material"]
                and verdict["confidence"] >= config.NEWS_MIN_CONFIDENCE)
