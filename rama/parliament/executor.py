"""The executor — turns the panel's consensus into Rama's audit decision.

This is the single function Rama's engine ever touches (via the external_auditor
hook). It is ADVISORY: it can VETO a candidate (a strong AVOID consensus) but it
never forces a buy — sizing and the rest of the decision stay with Rama's own
engine. Every verdict carries a human-readable reason, and the full deliberation
is logged to config.DATA_DIR/parliament_log.jsonl for later audit.
"""

import json

from . import panel
from .. import config


def _log(record: dict) -> None:
    try:
        path = config.DATA_DIR / "parliament_log.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:  # noqa: BLE001 — logging must never block trading
        pass


def audit_hook(symbol, industry, context):
    """Signature required by rama.audit.external_auditor:
    (symbol, industry, context_dict) -> (ok: bool, reason: str)."""
    result = panel.deliberate(symbol, industry, context)
    _log(result)

    if (result["vote"] == "AVOID"
            and result["confidence"] >= config.PARLIAMENT_MIN_CONFIDENCE):
        why = "; ".join(result["reasons"][:2]) or "panel consensus AVOID"
        return (False, f"Parliament AVOID @{result['confidence']:.0%} — {why}")

    return (True, f"Parliament {result['vote']} @{result['confidence']:.0%}")
