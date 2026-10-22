#!/usr/bin/env python3
"""llm.py - one small door to a language model for the JUDGE and REVIEW agents.

Provider is picked from the environment (.env):
  ANTHROPIC_API_KEY  -> Claude (default model claude-haiku-4-5)
  GEMINI_API_KEY     -> Gemini (default model gemini-2.0-flash)
Neither key            -> ask() returns None and the agents step aside (nothing is blocked).

Every call is bounded: a short timeout, a daily call budget, and answers cached by prompt.
"""
import os, json, time, hashlib, threading
import core

_lock = threading.Lock()
_calls = {"day": "", "n": 0}
_cache = {}
LOG = os.path.join(core.BASE, "llm_calls.jsonl")


def provider():
    if os.environ.get("LLM_FAKE"):
        return "fake"
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("GEMINI_API_KEY"):
        return "gemini"
    return None


def model_name():
    m = (core.cfg().get("v2") or {}).get("llm_model")
    if m:
        return m
    return {"anthropic": "claude-haiku-4-5", "gemini": "gemini-2.0-flash", "fake": "fake"}.get(provider() or "", "")


def budget_left():
    day = core.ist_now().strftime("%Y-%m-%d")
    with _lock:
        if _calls["day"] != day:
            _calls["day"], _calls["n"] = day, 0
        mx = int((core.cfg().get("v2") or {}).get("llm_max_calls", 200))
        return mx - _calls["n"]


def ask(prompt, system="", max_tokens=200, timeout=8.0, tag=""):
    """Return the model's text, or None (no key, over budget, timeout, error). Never raises."""
    prov = provider()
    if not prov:
        return None
    key = hashlib.sha1((system + "\n" + prompt).encode()).hexdigest()
    if key in _cache:
        return _cache[key]
    if budget_left() <= 0:
        return None
    t0 = time.time()
    out, err = None, None
    try:
        if prov == "fake":
            out = os.environ.get("LLM_FAKE_REPLY", "GO - fake model: looks fine")
        elif prov == "anthropic":
            import requests
            r = requests.post("https://api.anthropic.com/v1/messages",
                              headers={"x-api-key": os.environ["ANTHROPIC_API_KEY"], "anthropic-version": "2023-06-01",
                                       "content-type": "application/json"},
                              json={"model": model_name(), "max_tokens": max_tokens, "system": system or "You are a concise trading desk assistant.",
                                    "messages": [{"role": "user", "content": prompt}]}, timeout=timeout)
            r.raise_for_status()
            out = "".join(b.get("text", "") for b in r.json().get("content", [])).strip()
        elif prov == "gemini":
            import requests
            r = requests.post("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % (
                                  model_name(), os.environ["GEMINI_API_KEY"]),
                              json={"system_instruction": {"parts": [{"text": system or "You are a concise trading desk assistant."}]},
                                    "contents": [{"parts": [{"text": prompt}]}],
                                    "generationConfig": {"maxOutputTokens": max_tokens, "temperature": 0.2}}, timeout=timeout)
            r.raise_for_status()
            j = r.json()
            out = "".join(p.get("text", "") for p in j["candidates"][0]["content"]["parts"]).strip()
    except Exception as ex:
        err = str(ex)[:200]
    with _lock:
        _calls["n"] += 1
    try:
        with open(LOG, "a") as f:
            f.write(json.dumps({"t": core.ist_now().strftime("%Y-%m-%d %H:%M:%S"), "tag": tag, "ms": int((time.time() - t0) * 1000),
                                "ok": out is not None, "err": err, "reply": (out or "")[:300]}) + "\n")
    except Exception:
        pass
    if out is not None:
        _cache[key] = out
    return out


JUDGE_SYSTEM = ("You are JUDGE, the last check on an NSE equity intraday desk. The desk only BUYS, holds minutes to hours, "
                "and squares off at 15:15 IST. A rules engine has already found a setup; you decide whether to let the buy go. "
                "Be strict about chasing extended moves, buying into a weak market, thin liquidity, and news that is stale, "
                "negative, or merely a roundup. Reply with exactly one line: GO or NO, then ' - ' and a reason of at most 20 words.")


def judge(card_text, tag="judge"):
    """Returns (verdict, reason): verdict 'GO', 'NO', or None when no model answered."""
    txt = ask(card_text, system=JUDGE_SYSTEM, max_tokens=60, timeout=10.0, tag=tag)
    if not txt:
        return None, None
    head = txt.strip().split("\n")[0]
    word = head.strip().upper().split(" ")[0].strip(".:-")
    reason = head.split("-", 1)[1].strip() if "-" in head else head
    if word.startswith("GO"):
        return "GO", reason[:140]
    if word.startswith("NO"):
        return "NO", reason[:140]
    return None, head[:140]


REVIEW_SYSTEM = ("You are REVIEW, the end-of-day coach of an NSE intraday paper-trading desk (buys only, 15:15 square-off). "
                 "You get today's trades with entry type, times, exit reason and net P&L, plus the market context. "
                 "Write a post-mortem in plain English for the owner, under 220 words, with exactly these headings: "
                 "WHAT WORKED, WHAT FAILED, TIGHTEN (3 concrete rule changes with numbers), KEEP. No fluff, no disclaimers.")


def review(day_text, tag="review"):
    return ask(day_text, system=REVIEW_SYSTEM, max_tokens=450, timeout=25.0, tag=tag)
