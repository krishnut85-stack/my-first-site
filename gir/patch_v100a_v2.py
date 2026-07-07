#!/usr/bin/env python3
"""
PATCH_V100A_v2 — Fix exit reason taxonomy (equity + F&O)
═══════════════════════════════════════════════════════════════════════════════

PROBLEM:
  "SL_BREACHED" is hardcoded at exit-detection sites without checking pnl sign.
  ABCAPITAL closed Friday at +Rs.228 was tagged "SL_BREACHED" identically to a
  real loss. Every analysis based on exit_reason has been wrong.

  Two _record_trade functions exist (line 6466 equity, line 7383 F&O).
  Both write trade records and both need the fix.

FIX:
  In each _record_trade, after pnl is computed and before the trade dict is built,
  reclassify reason = "SL_BREACHED" based on pnl sign:
    pnl > 0  →  "SL_TRAIL_TAKE"   (trail caught a profitable peak)
    pnl <= 0 →  "SL_LOSS"         (real stop hit in loss territory)
  All other reason values pass through unchanged.

ANCHORING STRATEGY (rule #14 — verify, rule #24 — pre-code audit done):
  Anchor on the unique signature line of each function definition + first 3 body
  lines. Function signature `def _record_trade(self, symbol, pos, exit_price, reason):`
  appears exactly twice in gir.py (once equity, once F&O). We patch each in turn,
  asserting count==1 each time after the previous replacement consumes one.

  This is safer than anchoring on body internals (which differ between the two
  copies and may evolve).
"""

import ast, shutil, sys, time, re
from pathlib import Path

GIR    = Path("/home/globalbot/gir.py")
BACKUP = Path(f"/home/globalbot/bak_pre_v100a_{time.strftime('%Y%m%d_%H%M%S')}.py")

src = GIR.read_text()

# ── Sanity: function signature appears exactly twice ──
SIG = "    def _record_trade(self, symbol, pos, exit_price, reason):"
n_sig = src.count(SIG)
if n_sig != 2:
    print(f"[V100A_v2] FATAL: expected 2 _record_trade definitions, found {n_sig}.")
    print(f"           Cannot proceed safely. Investigate gir.py manually.")
    sys.exit(1)

# ── The reclassifier block: identical injection for both functions ──
RECLASSIFIER = '''
        # ── V100A: split SL_BREACHED into trail-take vs real-loss based on pnl ──
        # Bot was tagging every GTT-trail trigger "SL_BREACHED" regardless of pnl sign.
        # ABCAPITAL closed +Rs.228 was logged identical to a real loss. Fixed here.
        if reason == "SL_BREACHED":
            if pnl > 0:
                reason = "SL_TRAIL_TAKE"
            else:
                reason = "SL_LOSS"
            log.info(f"[V100A] {symbol} reclassified SL_BREACHED -> {reason} (pnl={pnl:.2f})")
'''

# ── Anchor: pnl computation line. Appears at top of EACH _record_trade body. ──
# We replace it with itself + the reclassifier injected immediately after.
PNL_LINE = '        pnl   = (exit_price - entry) * qty if exit_price > 0 else 0'

n_pnl = src.count(PNL_LINE)
if n_pnl < 2:
    print(f"[V100A_v2] FATAL: pnl-line anchor matched {n_pnl} times (expected ≥2).")
    print(f"           File likely changed since last grep. Re-derive anchor.")
    sys.exit(1)

# ── Replace the FIRST occurrence (equity _record_trade at line 6466) ──
patched = src.replace(PNL_LINE, PNL_LINE + RECLASSIFIER, 1)

# After first replace, the second occurrence is now still PNL_LINE alone,
# because the replacement string still STARTS with PNL_LINE. So count goes
# from 2 → 2 (one consumed at index N, one still pristine at index >N).
# Wait — that's wrong. str.replace with count=1 replaces the FIRST match.
# The replacement string CONTAINS PNL_LINE as prefix → so replace count
# stays the same after the first replace. Need a different strategy:
#   Approach: replace BOTH in one pass by using a unique marker first.

# Reset — better approach:
src1 = src

# Use a placeholder to mark the first one consumed
MARKER1 = "__V100A_MARKER_EQUITY__"
MARKER2 = "__V100A_MARKER_FNO__"

# Find both occurrences by index
i1 = src1.find(PNL_LINE)
i2 = src1.find(PNL_LINE, i1 + len(PNL_LINE))
if i1 == -1 or i2 == -1:
    print("[V100A_v2] FATAL: could not locate two distinct pnl-line positions.")
    sys.exit(1)

# Build patched source by splicing: keep [0:i1] + line + reclassifier + [i1+len:i2] + line + reclassifier + [i2+len:]
end1 = i1 + len(PNL_LINE)
end2 = i2 + len(PNL_LINE)
patched = (
    src1[:end1] + RECLASSIFIER +
    src1[end1:end2] + RECLASSIFIER +
    src1[end2:]
)

# Verify both injections present
if patched.count("[V100A]") < 2:
    print(f"[V100A_v2] FATAL: post-patch injection count {patched.count('[V100A]')} < 2")
    sys.exit(1)

# AST validate
try:
    ast.parse(patched)
except SyntaxError as e:
    print(f"[V100A_v2] FATAL: patched source has syntax error at line {e.lineno}: {e.msg}")
    sys.exit(1)

# Backup & write
shutil.copy(GIR, BACKUP)
GIR.write_text(patched)

# Verify on-disk
written = GIR.read_text()
n_v100a = written.count("[V100A]")
n_lines = len(written.splitlines())

print(f"[V100A_v2] OK")
print(f"           Backup       : {BACKUP}")
print(f"           Patched file : {GIR}  ({n_lines} lines)")
print(f"           V100A markers: {n_v100a}  (expected ≥2)")
print(f"           Restart      : systemctl restart globaleye")
print(f"           Verify       : journalctl -u globaleye -n 200 --no-pager | grep V100A")
print(f"           Rollback     : cp {BACKUP} {GIR} && systemctl restart globaleye")
