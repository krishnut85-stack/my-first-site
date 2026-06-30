#!/usr/bin/env python3
"""
PATCH_V100A — Fix exit reason taxonomy
═══════════════════════════════════════════════════════════════════════════════

PROBLEM:
  Line 7305 hardcodes "SL_BREACHED" when GTT trail-stop fires, regardless of
  whether the fire was profitable (trail caught a peak) or losing (real SL hit).
  This corrupts every analysis — ABCAPITAL closed Friday at +Rs.228 was tagged
  SL_BREACHED, identical tag to a true loss.

FIX:
  In _record_trade (the single point where pnl is computed AND reason is written),
  re-classify "SL_BREACHED" based on actual pnl sign:
    pnl > 0  →  "SL_TRAIL_TAKE"   (trail stop caught a profitable move)
    pnl <= 0 →  "SL_LOSS"         (real stop-loss hit)
  Other reasons (TARGET_HIT, MANUAL_SELL, SOLD_EXTERNAL, V85_PARTIAL_TAKE, etc.)
  pass through unchanged.

METHOD:
  - Read gir.py
  - Locate exact anchor: pnl computation + trade dict construction in _record_trade
  - Insert reclassification block between pnl calc and trade dict
  - AST-validate
  - Backup, write, restart, verify

  Read-only on JSONs. Single anchor. Single change. Reversible via backup.

  Standing rules respected:
    #14: Pre-code audit done — _record_trade is single write point, source bug
         is separate (deferred to V100B which needs its own grep).
    #16: Mapped overlapping paths — only _record_trade writes "reason" to JSON.
         Line 7305 sets the inbound reason string; reclassifying at the write
         point catches all paths (equity SL, F&O SL, manual exits) in one place.
    #24: No "just add it" — anchor matches once, asserted in patch.
"""

import ast, shutil, sys, time
from pathlib import Path

GIR     = Path("/home/globalbot/gir.py")
BACKUP  = Path(f"/home/globalbot/bak_pre_v100a_{time.strftime('%Y%m%d_%H%M%S')}.py")

src = GIR.read_text()

# ── Anchor: exact lines from _record_trade body, before V83_EXIT_HOOK try block ──
OLD = '''        entry = pos.get("entry_price", 0)
        qty   = pos.get("qty", 0)
        pnl   = (exit_price - entry) * qty if exit_price > 0 else 0
        # V83_EXIT_HOOK: record EVERY exit (loss/breakeven/win/external) for 24h cooldown.'''

NEW = '''        entry = pos.get("entry_price", 0)
        qty   = pos.get("qty", 0)
        pnl   = (exit_price - entry) * qty if exit_price > 0 else 0

        # ── V100A: split SL_BREACHED into trail-take vs real-loss based on pnl sign ──
        # Bot was tagging every GTT-trail trigger as "SL_BREACHED" regardless of pnl.
        # ABCAPITAL closed +Rs.228 was logged identical to a real loss. Fixed here.
        if reason == "SL_BREACHED":
            if pnl > 0:
                reason = "SL_TRAIL_TAKE"   # trail stop caught a profitable peak
            else:
                reason = "SL_LOSS"         # real stop-loss firing in loss territory
            log.info(f"[V100A] {symbol} reclassified SL_BREACHED -> {reason} (pnl={pnl:.2f})")

        # V83_EXIT_HOOK: record EVERY exit (loss/breakeven/win/external) for 24h cooldown.'''

# ── Verify exactly one match (rule #24: anchor must be unique) ──
n = src.count(OLD)
if n == 0:
    print("[V100A] FATAL: anchor not found. Aborting — no change made.")
    print("        Probable cause: gir.py edited since last grep. Re-grep and re-derive anchor.")
    sys.exit(1)
if n > 1:
    print(f"[V100A] FATAL: anchor matched {n} times (expected 1). Aborting.")
    sys.exit(1)

# ── Build patched source ──
patched = src.replace(OLD, NEW, 1)

# ── AST validate (rule #14: verify effectiveness before deploy) ──
try:
    ast.parse(patched)
except SyntaxError as e:
    print(f"[V100A] FATAL: patched source has syntax error: {e}")
    sys.exit(1)

# ── Backup & write ──
shutil.copy(GIR, BACKUP)
GIR.write_text(patched)

print(f"[V100A] OK")
print(f"        Backup : {BACKUP}")
print(f"        Patched: {GIR}  ({len(patched.splitlines())} lines)")
print(f"        Restart: systemctl restart globaleye")
print(f"        Verify : journalctl -u globaleye -n 100 --no-pager | grep V100A")
