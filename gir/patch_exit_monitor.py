#!/usr/bin/env python3
# =============================================================================
#  patch_exit_monitor.py  —  make paper_exit_monitor.py SKIP GIR_EQ_FLOOR trades
#  so its equity-trail branch never touches them (gir_eq_floor.py owns those
#  exits via a fixed target). Additive, idempotent, AST-validated, backed up.
#  Run:  cd /home/globalbot && python3 patch_exit_monitor.py
# =============================================================================
import ast, shutil, sys, re
from datetime import datetime

TARGET = "/home/globalbot/paper/paper_exit_monitor.py"
ANCHOR = 'strategy = t["strategy"]'          # per grep: paper_exit_monitor.py:231
GUARD_MARK = "GIR_EQ_FLOOR exits owned by gir_eq_floor.py"

src = open(TARGET).read()

if GUARD_MARK in src:
    print("Already patched — nothing to do."); sys.exit(0)

n = src.count(ANCHOR)
if n != 1:
    print(f"ABORT: anchor found {n} times (need exactly 1).")
    print("Anchor:", repr(ANCHOR))
    print("Lines containing 'strategy =':")
    for i, ln in enumerate(src.splitlines(), 1):
        if re.search(r"strategy\s*=", ln):
            print(f"  {i}: {ln}")
    sys.exit(1)

# match the anchor line's indentation, indent the continue one level deeper
line = next(l for l in src.splitlines() if ANCHOR in l)
indent = line[:len(line) - len(line.lstrip())]
guard = (f"{line}\n"
         f"{indent}if (strategy or \"\").upper().startswith(\"GIR_EQ_FLOOR\"):\n"
         f"{indent}    continue  # {GUARD_MARK} — monitor must not trail these\n")
patched = src.replace(line + "\n", guard, 1)

# validate before writing
try:
    ast.parse(patched)
except SyntaxError as e:
    print(f"ABORT: patched source fails AST parse: {e}"); sys.exit(1)

backup = f"{TARGET}.bak_{datetime.now():%Y%m%d_%H%M%S}"
shutil.copy2(TARGET, backup)
open(TARGET, "w").write(patched)
print(f"Patched OK. Backup: {backup}")
print("Inserted skip-guard right after the strategy lookup in the per-trade loop.")
