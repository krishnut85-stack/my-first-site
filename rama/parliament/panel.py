"""The panel — gathers every analyst's verdict and reaches a consensus.

Runs the rules lenses always, then (if a provider is configured) adds the LLM
analyst. If the LLM errors, times out, or has no key, it is silently dropped and
the rules lenses decide — that is the fallback chain. The consensus weighs BUY
confidence against AVOID confidence; ties break toward caution (AVOID), because
this is a risk auditor and capital preservation comes first.

Returns a plain dict so the whole deliberation is JSON-serialisable / auditable.
"""

from . import analyst
from .. import config


def deliberate(symbol, industry, ctx) -> dict:
    verdicts = [lens(symbol, industry, ctx) for lens in analyst.RULES_LENSES]

    used_llm = False
    if config.PARLIAMENT_PROVIDER and config.PARLIAMENT_PROVIDER != "rules":
        try:
            verdicts.append(analyst.llm_analyst(symbol, industry, ctx))
            used_llm = True
        except Exception:  # noqa: BLE001 — fallback chain: rules carry on
            used_llm = False

    # Caution-first consensus: the STRONGEST single objection matters most (one
    # confident "market is falling" outweighs three mild "looks fine" votes).
    avoid_confs = [v.confidence for v in verdicts if v.vote == "AVOID"]
    buy_confs = [v.confidence for v in verdicts if v.vote == "BUY"]
    max_avoid = max(avoid_confs, default=0.0)
    max_buy = max(buy_confs, default=0.0)

    if avoid_confs and (max_avoid >= max_buy or sum(avoid_confs) >= sum(buy_confs)):
        vote = "AVOID"
        confidence = max_avoid
        reasons = [f"{v.lens}: {v.reason}" for v in verdicts if v.vote == "AVOID"]
    elif buy_confs:
        vote = "BUY"
        confidence = max_buy
        reasons = [f"{v.lens}: {v.reason}" for v in verdicts if v.vote == "BUY"]
    else:
        vote = "HOLD"
        confidence = 0.0
        reasons = [f"{v.lens}: {v.reason}" for v in verdicts]

    return {
        "symbol": symbol,
        "vote": vote,
        "confidence": round(confidence, 3),
        "reasons": reasons,
        "used_llm": used_llm,
        "provider": config.PARLIAMENT_PROVIDER,
        "verdicts": [v.as_dict() for v in verdicts],
    }
