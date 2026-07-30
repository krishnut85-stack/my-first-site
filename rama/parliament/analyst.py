"""Analysts — each returns a structured verdict on one candidate.

Two kinds:
  • RULES LENSES — fast, deterministic, offline. Each looks at ONE dimension
    (trend, insiders, valuation, strength) and votes. Always available.
  • LLM ANALYST — optional; asks Gemini or Claude for a JSON verdict. If the
    provider is unset, has no key, errors, or times out, the caller drops it and
    the rules lenses carry the decision (the "fallback chain").

A verdict is a small, JSON-serialisable record so the whole panel is auditable.
Advisory only — nothing here places or forces a trade.
"""

from dataclasses import dataclass, asdict

from .. import config


@dataclass
class Verdict:
    vote: str          # "BUY" | "HOLD" | "AVOID"
    confidence: float  # 0..1
    reason: str
    lens: str = ""

    def as_dict(self) -> dict:
        return asdict(self)


def _f(context, key, default=None):
    return (context or {}).get(key, default)


# --- rules lenses ----------------------------------------------------------

def trend_lens(symbol, industry, ctx) -> Verdict:
    if _f(ctx, "uptrend") is False:
        return Verdict("AVOID", 0.80, "market regime is a downtrend", "trend")
    return Verdict("BUY", 0.55, "market regime is not a downtrend", "trend")


def insider_lens(symbol, industry, ctx) -> Verdict:
    cs = _f(ctx, "catalyst_score")
    if cs is None:
        return Verdict("HOLD", 0.40, "no insider/catalyst signal", "insider")
    if cs <= config.AUDIT_MAX_NEGATIVE_CATALYST:
        return Verdict("AVOID", 0.85, f"insiders net SELLING ({cs:+.2f})", "insider")
    if cs >= 0.30:
        return Verdict("BUY", 0.70, f"insiders net BUYING ({cs:+.2f})", "insider")
    return Verdict("HOLD", 0.50, f"weak insider signal ({cs:+.2f})", "insider")


def valuation_lens(symbol, industry, ctx) -> Verdict:
    pe = getattr(industry, "pe", None)
    if pe is None:
        return Verdict("HOLD", 0.40, "no PE available", "valuation")
    if pe > config.AUDIT_MAX_PE:
        return Verdict("AVOID", 0.65, f"overheated PE {pe:.0f}", "valuation")
    return Verdict("BUY", 0.50, f"valuation acceptable (PE {pe:.0f})", "valuation")


def strength_lens(symbol, industry, ctx) -> Verdict:
    score = getattr(industry, "score", 0.0) or 0.0
    if score <= config.AUDIT_MIN_SCORE:
        return Verdict("AVOID", 0.70, f"weak rank score {score:.1f}", "strength")
    conf = max(0.5, min(0.9, 0.5 + score / 200.0))
    return Verdict("BUY", conf, f"rank score {score:.1f}", "strength")


RULES_LENSES = [trend_lens, insider_lens, valuation_lens, strength_lens]


# --- optional LLM analyst (Gemini / Claude) with a hard fallback -----------

def _prompt(symbol, industry, ctx) -> str:
    pe = getattr(industry, "pe", None)
    return (
        "You are a conservative Indian-equity risk auditor. Given ONE candidate "
        "stock, reply with ONLY a JSON object: "
        '{"vote":"BUY|HOLD|AVOID","confidence":0..1,"reason":"short"}.\n'
        f"Symbol: {symbol}\n"
        f"Industry: {getattr(industry, 'name', '?')} (rank score "
        f"{getattr(industry, 'score', 0):.1f}, PE {pe})\n"
        f"Market uptrend: {_f(ctx, 'uptrend')}\n"
        f"Insider/catalyst score (-1..+1): {_f(ctx, 'catalyst_score')}\n"
        "Vote AVOID if the market is down, insiders are selling, or valuation is "
        "extreme. Be strict; capital preservation first."
    )


def llm_analyst(symbol, industry, ctx) -> Verdict:
    """Ask the configured LLM for a verdict. Raises on any problem so the panel
    can fall back to the rules lenses. Never returns a malformed verdict."""
    provider = config.PARLIAMENT_PROVIDER
    prompt = _prompt(symbol, industry, ctx)
    if provider == "gemini":
        raw = _call_gemini(prompt)
    elif provider == "claude":
        raw = _call_claude(prompt)
    else:
        raise RuntimeError(f"unknown provider {provider!r}")
    data = _parse_json(raw)
    vote = str(data.get("vote", "")).upper()
    if vote not in ("BUY", "HOLD", "AVOID"):
        raise ValueError(f"bad vote {vote!r}")
    conf = float(data.get("confidence", 0.5))
    conf = max(0.0, min(1.0, conf))
    return Verdict(vote, conf, str(data.get("reason", ""))[:160], f"llm:{provider}")


def _parse_json(text: str) -> dict:
    import json
    import re
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if not m:
        raise ValueError("no JSON object in LLM reply")
    return json.loads(m.group(0))


def _http_json(url: str, payload: dict, headers: dict) -> dict:
    import json
    import urllib.request
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(), headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=config.PARLIAMENT_TIMEOUT) as r:  # noqa: S310
        return json.loads(r.read().decode())


def _call_gemini(prompt: str) -> str:
    if not config.GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY not set")
    url = ("https://generativelanguage.googleapis.com/v1beta/models/"
           "gemini-1.5-flash:generateContent?key=" + config.GEMINI_API_KEY)
    body = {"contents": [{"parts": [{"text": prompt}]}]}
    data = _http_json(url, body, {"Content-Type": "application/json"})
    return data["candidates"][0]["content"]["parts"][0]["text"]


def _call_claude(prompt: str) -> str:
    if not config.ANTHROPIC_API_KEY:
        raise RuntimeError("ANTHROPIC_API_KEY not set")
    url = "https://api.anthropic.com/v1/messages"
    body = {"model": "claude-haiku-4-5-20251001", "max_tokens": 200,
            "messages": [{"role": "user", "content": prompt}]}
    headers = {"Content-Type": "application/json",
               "x-api-key": config.ANTHROPIC_API_KEY,
               "anthropic-version": "2023-06-01"}
    data = _http_json(url, body, headers)
    return data["content"][0]["text"]
