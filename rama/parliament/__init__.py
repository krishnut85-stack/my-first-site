"""Parliament — a SEPARATE, advisory AI audit panel for Rama.

Fully isolated subpackage (analyst -> panel -> executor). It plugs into Rama's
audit hook ONLY when you call enable() — which the engine does automatically iff
config.USE_PARLIAMENT_AUDIT is on. Nothing in Rama's core imports Parliament
otherwise, so it stays cleanly separable.

  analyst.py   — rules lenses + optional Gemini/Claude analyst (with fallback)
  panel.py     — gathers verdicts, reaches a cautious consensus
  executor.py  — turns consensus into Rama's (ok, reason) audit decision + logs

Advisory only: it can veto a weak candidate; it never forces or places a trade.
API keys are read from the environment at runtime and never committed.
"""

from .executor import audit_hook
from .panel import deliberate

__all__ = ["enable", "disable", "audit_hook", "deliberate"]


def enable() -> None:
    """Install Parliament as Rama's external auditor (both must pass to trade)."""
    from .. import audit
    audit.external_auditor = audit_hook


def disable() -> None:
    """Remove Parliament, reverting Rama to the built-in rule auditor only."""
    from .. import audit
    audit.external_auditor = None
