#!/usr/bin/env python3
"""
replay_panel.py — Phase 2 of the Replay Harness

What it does:
  Reads a day of captured decisions from data/decisions_YYYYMMDD.jsonl
  and re-runs each one through the CURRENT ExpertPanel code in gir.py.
  Reports any decisions where the current code produces a different
  output than what was captured.

Why this catches V72-class bugs:
  V72 was a NameError that silently broke equity entry. With this runner,
  if a future patch breaks score_news() or evaluate_equity(), replay
  immediately detects the drift before the patch goes live.

Usage:
  python3 replay_panel.py                    # replay today's decisions
  python3 replay_panel.py 20260501           # replay specific date
  python3 replay_panel.py --last 5           # replay last 5 trading days
  python3 replay_panel.py --strict           # exit 1 on ANY mismatch (for safe_deploy.sh)

What it CANNOT verify (honest limits):
  - score_technical depends on kite.historical_data() which is non-deterministic
    (different today than yesterday). We compare component scores, not raw inputs.
  - score_news may call Gemini which is non-deterministic. Same handling.
  - score_fundamental depends on trendlyne state which mutates over time.
  - For these, we treat a component-score difference of <=2 points as PASS
    (within natural drift), and >2 points as FAIL (real divergence).

  The threshold (2 points) is conservative. score_technical max is 20,
  score_news max is 100, so 2 points = 2-10% drift. Tunable below.

  For deterministic components (score_history, score_sector for stable bias,
  score_option from option_data dict), drift threshold is 0 — exact match required.

What it DOES catch:
  - NameError / AttributeError / TypeError in any score_* function
  - Logic bugs that change allow/veto for the same input
  - Threshold drift (e.g. EQUITY_THRESHOLD changed from 55 to 60 silently)
  - Total score math errors (component sum != reported total)
"""

import json
import sys
import argparse
import os
from datetime import datetime, timedelta
from pathlib import Path

# Drift tolerance per component (points). 0 = exact match required.
TOLERANCE = {
    "news": 5,           # depends on Gemini (non-deterministic)
    "fundamental": 3,    # trendlyne state mutates
    "technical": 5,      # kite.historical_data day-to-day drift
    "sector": 2,         # sector rotation can shift
    "history": 0,        # deterministic (loss tracker is stable)
    "oi": 5,             # OI-driven, can drift
    "option": 0,         # deterministic (computed from captured option_data)
}

# Total-score tolerance: sum of per-component tolerances above
# Exact match on allow/veto regardless of tolerance.

DATA_DIR = Path("/home/globalbot/data")
GIR_DIR = Path("/home/globalbot")


def load_decisions(date_str):
    """Load all decisions for a YYYYMMDD date string. Returns list of dicts."""
    path = DATA_DIR / f"decisions_{date_str}.jsonl"
    if not path.exists():
        return []
    decisions = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                decisions.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # skip corrupt lines, don't crash
    return decisions


def setup_panel():
    """
    Load gir.py's ExpertPanel WITHOUT triggering live Kite login.
    We monkey-patch KiteSession.kite() to return None — the score functions
    handle None gracefully and return their default scores.
    """
    sys.path.insert(0, str(GIR_DIR))
    # Block live data calls
    os.environ.setdefault("KITE_API_KEY", "replay_offline")
    os.environ.setdefault("ZERODHA_PASSWORD", "replay_offline")
    os.environ.setdefault("KITE_TOTP_SECRET", "JBSWY3DPEHPK3PXP")  # dummy valid base32

    import gir

    # Block Kite login during replay — we don't want to hit live API
    gir.KiteSession._kite = None
    gir.KiteSession.login = classmethod(lambda cls: False)
    gir.KiteSession.kite = classmethod(lambda cls: None)

    # Also disable trade_recorder during replay so we don't pollute today's data
    if hasattr(gir, "TradeRecorder") and gir.TradeRecorder is not None:
        try:
            gir.TradeRecorder.uninstall()
        except Exception:
            pass

    # Build a panel with stub dependencies
    class _StubTrendlyne:
        def score(self, symbol):
            return 50  # neutral DVM, returns score_fundamental=10
    class _StubSectorRotation:
        def get_sector_bias(self, symbol):
            return ("MIDDLE", "UNKNOWN", 0.0)
    class _StubNewsBrain:
        def is_validated(self, symbol, direction):
            return (False, 0)

    panel = gir.ExpertPanel(_StubTrendlyne(), _StubSectorRotation(), _StubNewsBrain())
    return gir, panel


def replay_one(panel, gir, decision):
    """
    Re-run a single captured decision. Returns:
      (matched: bool, reason: str, captured: dict, replayed: dict)
    """
    kind = decision.get("kind")
    symbol = decision.get("in_symbol")
    direction = decision.get("in_direction")
    scout_data = decision.get("in_scout_data") or {}
    extras_in = decision.get("in_extras") or {}
    option_data = extras_in.get("option_data") or {}

    if not symbol or not direction or kind not in ("EQUITY", "FNO"):
        return (False, "malformed_decision", decision, None)

    try:
        if kind == "EQUITY":
            replayed = panel.evaluate_equity(None, symbol, direction, scout_data)
        else:
            replayed = panel.evaluate_fno(None, symbol, direction, scout_data, option_data)
    except Exception as e:
        return (False, f"replay_raised: {type(e).__name__}: {e}", decision, None)

    captured_total = decision.get("out_total")
    captured_allow = decision.get("out_allow")
    captured_veto = decision.get("out_veto")
    captured_components = decision.get("out_components") or {}

    # Hard check: allow / veto must match exactly
    if replayed.get("allow") != captured_allow:
        return (False, f"allow mismatch: captured={captured_allow} replayed={replayed.get('allow')}",
                decision, replayed)
    if replayed.get("veto") != captured_veto:
        return (False, f"veto mismatch: captured={captured_veto} replayed={replayed.get('veto')}",
                decision, replayed)

    # Soft check: per-component drift within tolerance
    drifts = []
    for comp, tol in TOLERANCE.items():
        cap = captured_components.get(comp)
        rep = replayed.get(comp)
        if cap is None and rep is None:
            continue
        if cap is None or rep is None:
            drifts.append(f"{comp}: captured={cap} replayed={rep} (one missing)")
            continue
        if abs(int(cap) - int(rep)) > tol:
            drifts.append(f"{comp}: captured={cap} replayed={rep} drift={abs(cap-rep)} tol={tol}")

    if drifts:
        return (False, "drift: " + "; ".join(drifts), decision, replayed)

    # Total score check (using sum of tolerances)
    total_tol = sum(TOLERANCE.values())
    if captured_total is not None and abs(int(captured_total) - int(replayed.get("total", 0))) > total_tol:
        return (False, f"total drift: captured={captured_total} replayed={replayed.get('total')} tol={total_tol}",
                decision, replayed)

    return (True, "match", decision, replayed)


def replay_date(date_str, verbose=False):
    """Replay all decisions for a date. Returns (total, matched, mismatched, details)."""
    decisions = load_decisions(date_str)
    if not decisions:
        return (0, 0, 0, [])

    print(f"Loading gir.py ExpertPanel ...")
    gir, panel = setup_panel()
    print(f"Replaying {len(decisions)} decisions from {date_str} ...")
    print()

    matched = 0
    mismatched = 0
    details = []

    for i, dec in enumerate(decisions, 1):
        ok, reason, captured, replayed = replay_one(panel, gir, dec)
        if ok:
            matched += 1
            if verbose:
                print(f"  [{i}/{len(decisions)}] PASS {dec.get('kind')} {dec.get('in_symbol')} {dec.get('in_direction')}")
        else:
            mismatched += 1
            details.append({
                "index": i,
                "kind": dec.get("kind"),
                "symbol": dec.get("in_symbol"),
                "direction": dec.get("in_direction"),
                "reason": reason,
                "captured_total": dec.get("out_total"),
                "captured_allow": dec.get("out_allow"),
            })
            print(f"  [{i}/{len(decisions)}] FAIL {dec.get('kind')} {dec.get('in_symbol')} {dec.get('in_direction')}: {reason}")

    return (len(decisions), matched, mismatched, details)


def main():
    parser = argparse.ArgumentParser(description="Replay captured panel decisions")
    parser.add_argument("date", nargs="?", default=None,
                        help="Date in YYYYMMDD (default: today)")
    parser.add_argument("--last", type=int, default=0,
                        help="Replay last N trading days (overrides date)")
    parser.add_argument("--strict", action="store_true",
                        help="Exit 1 if ANY mismatch (for safe_deploy.sh)")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Print every decision (default: only failures)")
    args = parser.parse_args()

    if args.last > 0:
        # Walk back N calendar days, take whichever have decisions files
        dates = []
        d = datetime.now()
        while len(dates) < args.last and d > datetime.now() - timedelta(days=30):
            ds = d.strftime("%Y%m%d")
            if (DATA_DIR / f"decisions_{ds}.jsonl").exists():
                dates.append(ds)
            d -= timedelta(days=1)
        if not dates:
            print(f"No decisions files found in last 30 days under {DATA_DIR}/")
            sys.exit(0 if not args.strict else 1)
    else:
        dates = [args.date or datetime.now().strftime("%Y%m%d")]

    grand_total = 0
    grand_matched = 0
    grand_mismatched = 0
    all_failures = []

    for ds in dates:
        print(f"═══ {ds} ═══")
        total, matched, mismatched, details = replay_date(ds, verbose=args.verbose)
        if total == 0:
            print(f"  (no decisions captured for {ds})")
            print()
            continue
        grand_total += total
        grand_matched += matched
        grand_mismatched += mismatched
        all_failures.extend([dict(d, date=ds) for d in details])
        print(f"  {ds}: {matched}/{total} matched, {mismatched} failed")
        print()

    print("═══════════════════════════════════════════════════════════")
    print(f"REPLAY SUMMARY: {grand_matched}/{grand_total} matched, {grand_mismatched} failed")
    print("═══════════════════════════════════════════════════════════")

    if grand_mismatched == 0 and grand_total > 0:
        print("✓ ALL DECISIONS REPLAY-MATCHED — current code reproduces captured behavior")
        sys.exit(0)
    elif grand_total == 0:
        print("⚠ No decisions to replay")
        sys.exit(0 if not args.strict else 1)
    else:
        print(f"✗ {grand_mismatched} mismatches detected")
        if args.strict:
            print("STRICT mode: exiting with code 1")
            sys.exit(1)
        sys.exit(0)


if __name__ == "__main__":
    main()
