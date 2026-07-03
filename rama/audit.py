"""Pre-trade audit gate — the "Validate" step in Rama's pipeline.

Before Rama opens a NEW paper position, every candidate is run past an auditor
that can VETO the trade. This is the safety valve the viral dashboard drew as
"AGENT SWARM // OPUS AUDIT": a second opinion between "this ranked well" and
"actually buy it".

Two auditors:
  • RuleAuditor  — fast, offline, deterministic. Checks market regime, valuation
                   (PE), price sanity, and — most usefully — the insider/catalyst
                   signal (it refuses to buy a name insiders are net SELLING).
                   Always available, no keys, no network.
  • external_auditor — an optional hook. Set audit.external_auditor to any
                   callable(symbol, industry, context) -> (ok: bool, reason: str)
                   to let Claude (via the MCP bridge) act as a second reviewer.
                   Both must pass for the trade to proceed (veto wins).

Every decision is returned with a human reason so the report can show WHY Rama
skipped a name. PAPER ONLY — this only gates the simulation.
"""

from dataclasses import dataclass

from . import config

# Optional plug-in: callable(symbol, industry, context_dict) -> (bool, str).
# Left None by default; the MCP bridge / a notebook can assign a Claude-backed
# reviewer here without touching the engine.
external_auditor = None


@dataclass
class AuditResult:
    ok: bool
    reason: str

    def __bool__(self) -> bool:  # so `if audit_candidate(...):` reads naturally
        return self.ok


def _rule_audit(symbol, industry, ltp, uptrend, catalyst_score) -> AuditResult:
    # 1. market regime — don't open new risk into a downtrend
    if config.AUDIT_REQUIRE_UPTREND and uptrend is False:
        return AuditResult(False, "market regime is a downtrend")

    # 2. price sanity — never size against a missing/zero price
    if ltp is None or ltp <= 0:
        return AuditResult(False, "no valid live price")

    # 3. valuation + strength (when we know the industry)
    if industry is not None:
        if industry.score <= config.AUDIT_MIN_SCORE:
            return AuditResult(False, f"weak rank score {industry.score:.1f}")
        pe = getattr(industry, "pe", None)
        if pe is not None and pe > config.AUDIT_MAX_PE:
            return AuditResult(False, f"overheated PE {pe:.0f}")

    # 4. insider/catalyst — the key new check: don't buy what insiders dump
    if (config.USE_CATALYST_SIGNAL and catalyst_score is not None
            and catalyst_score <= config.AUDIT_MAX_NEGATIVE_CATALYST):
        return AuditResult(False,
                           f"insiders net SELLING (catalyst {catalyst_score:+.2f})")

    return AuditResult(True, "passed")


def audit_candidate(symbol, industry, ltp, uptrend=None,
                    catalyst_score=None) -> AuditResult:
    """Return an AuditResult for one candidate. If the gate is off, always OK.
    Runs the rule auditor, then the optional external (Claude) auditor; a veto
    from either blocks the trade."""
    if not config.USE_AUDIT_GATE:
        return AuditResult(True, "audit gate off")

    res = _rule_audit(symbol, industry, ltp, uptrend, catalyst_score)
    if not res.ok:
        return res

    if external_auditor is not None:
        try:
            ok, reason = external_auditor(
                symbol, industry,
                {"ltp": ltp, "uptrend": uptrend, "catalyst_score": catalyst_score},
            )
            # surface the external auditor's own reason on BOTH veto and accept
            return AuditResult(bool(ok), reason)
        except Exception as exc:  # noqa: BLE001 — a broken hook must never trade
            return AuditResult(False, f"auditor error ({exc})")

    return AuditResult(True, res.reason)
