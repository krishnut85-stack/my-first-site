#!/usr/bin/env python3
"""
PATCH_V100A_v3 — Fix exit reason taxonomy
═══════════════════════════════════════════════════════════════════════════════

CORRECTED UNDERSTANDING:
  Earlier scripts assumed two _record_trade definitions. Verified with cat -A:
  there is exactly ONE definition (line 6466). Line 7383 is a call site, not
  a definition. Equity and F&O close paths both flow through the same function.
  One patch covers both.

PROBLEM:
  Exit detection sites pass reason="SL_BREACHED" without checking pnl sign.
  ABCAPITAL closed Friday at +Rs.228 was tagged identical to a real loss.

FIX:
  In _record_trade, immediately after pnl is computed, reclassify SL_BREACHED:
    pnl > 0  →  "SL_TRAIL_TAKE"   (trail caught a profitable peak)
    pnl <= 0 →  "SL_LOSS"         (real stop hit in loss territory)
  All other reason values pass through unchanged.

ANCHORING:
  Anchor on the single pnl computation line. Verified to appear exactly ONCE
  in gir.py (because there's only one _record_trade and the line is unique).
"""

import ast, shutil, sys, time
from pathlib import Path

GIR    = Path("/home/globalbot/gir.py")
BACKUP = Path(f"/home/globalbot/bak_pre_v100a_{time.strftime('%Y%m%d_%H%M%S')}.py")

src = GIR.read_text()

# ── Verify exactly one _record_trade definition exists ──
SIG = "    def _record_trade(self, symbol, pos, exit_price, reason):"
n_sig = src.count(SIG)
if n_sig != 1:
    print(f"[V100A_v3] FATAL: expected 1 _record_trade definition, found {n_sig}.")
    print(f"           gir.py structure differs from grep evidence. Investigate.")
    sys.exit(1)

# ── Anchor: pnl computation line. Should appear exactly once. ──
PNL_LINE = '        pnl   = (exit_price - entry) * qty if exit_price > 0 else 0'
n_pnl = src.count(PNL_LINE)
if n_pnl != 1:
    print(f"[V100A_v3] FATAL: pnl-line anchor matched {n_pnl} times (expected 1).")
    print(f"           Re-grep gir.py for the exact line and re-derive anchor.")
    sys.exit(1)

# ── Reclassifier injection: appended after the pnl line ──
INJECTION = '''

        # ── V100A: split SL_BREACHED into trail-take vs real-loss based on pnl ──
        # Before this, every GTT-trail trigger logged "SL_BREACHED" regardless of
        # pnl sign. ABCAPITAL +Rs.228 was tagged identically to a real loss.
        if reason == "SL_BREACHED":
            if pnl > 0:
                reason = "SL_TRAIL_TAKE"
            else:
                reason = "SL_LOSS"
            log.info(f"[V100A] {symbol} reclassified SL_BREACHED -> {reason} (pnl={pnl:.2f})")'''

NEW_LINE = PNL_LINE + INJECTION

# ── Apply replacement (count=1 because anchor is unique) ──
patched = src.replace(PNL_LINE, NEW_LINE, 1)

# ── Verify injection landed ──
n_marker = patched.count("[V100A]")
if n_marker < 1:
    print(f"[V100A_v3] FATAL: post-patch [V100A] marker count = {n_marker} (expected ≥1)")
    sys.exit(1)

# ── AST validate the entire patched source ──
try:
    ast.parse(patched)
except SyntaxError as e:
    print(f"[V100A_v3] FATAL: patched source has syntax error.")
    print(f"           Line {e.lineno}: {e.msg}")
    sys.exit(1)

# ── Backup, write, verify on disk ──
shutil.copy(GIR, BACKUP)
GIR.write_text(patched)

written = GIR.read_text()
n_v100a_disk = written.count("[V100A]")
n_lines      = len(written.splitlines())

print(f"[V100A_v3] OK")
print(f"           Backup       : {BACKUP}")
print(f"           Patched file : {GIR}  ({n_lines} lines)")
print(f"           V100A markers: {n_v100a_disk}  (expected ≥1)")
print(f"")
print(f"           Restart  : systemctl restart globaleye")
print(f"           Verify   : journalctl -u globaleye -n 200 --no-pager | grep -E 'V100A|started|error|traceback'")
print(f"           Rollback : cp {BACKUP} {GIR} && systemctl restart globaleye")
