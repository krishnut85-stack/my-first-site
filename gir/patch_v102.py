#!/usr/bin/env python3
"""PATCH_V102: F&O P&L double-count fix.

Bug: generate_equity_report sums kite.positions().net.pnl across ALL exchanges.
NSE CNC sells of held shares create NSE entries in positions.net with
lifetime gains as pnl. These get summed into "F&O P&L", double-counting
with equity day_move from kite.holdings().

Today (2026-05-07): Telegram showed Rs.+514, Kite truth Rs.+171.
Diff +343 = NSE entries in positions.net wrongly summed as F&O.

Fix: restrict the F&O loop to NFO/BFO/MCX/CDS exchanges only.
"""
import ast, shutil, sys
from datetime import datetime
from pathlib import Path

GIR = Path("/home/globalbot/gir.py")
TS = datetime.now().strftime("%Y%m%d_%H%M%S")
BACKUP = Path(f"/home/globalbot/gir.py.bak_v102_{TS}")

src = GIR.read_text()
print(f"[1/4] Read gir.py: {len(src)} chars")
shutil.copy2(GIR, BACKUP)
print(f"[2/4] Backup: {BACKUP}")

OLD = '''            # 3. F&O P&L from positions (intraday + carry)
            fno_pnl = 0
            try:
                for _p in kite.positions().get('net', []):
                    if _p['quantity'] != 0 or _p.get('m2m', 0):
                        fno_pnl += _p.get('pnl', 0)
            except Exception:
                pass'''

NEW = '''            # 3. F&O P&L from positions (intraday + carry)
            # PATCH_V102: filter to derivatives exchanges ONLY. Without this filter,
            # NSE CNC sells of held shares create NSE entries in positions.net whose
            # lifetime pnl gets summed here AND in equity day_move => double count.
            # 2026-05-07 incident: Telegram +514 vs Kite truth +171 (diff +343 = NSE
            # entries wrongly counted as F&O).
            fno_pnl = 0
            _FNO_EXCHANGES = ("NFO", "BFO", "MCX", "CDS", "BCD")
            try:
                for _p in kite.positions().get('net', []):
                    if _p.get('exchange') not in _FNO_EXCHANGES:
                        continue
                    if _p['quantity'] != 0 or _p.get('m2m', 0):
                        fno_pnl += _p.get('pnl', 0)
            except Exception:
                pass'''

c = src.count(OLD)
if c != 1:
    print(f"FATAL: anchor matched {c} times (expected 1)")
    sys.exit(2)
src = src.replace(OLD, NEW)
print(f"[3/4] Patch applied")

try:
    ast.parse(src)
except SyntaxError as e:
    print(f"FATAL AST: {e.lineno}: {e.text}")
    sys.exit(3)

GIR.write_text(src)
print(f"[4/4] AST OK, written")
print(f"")
print(f"=== PATCH_V102 DEPLOYED ===")
print(f"Backup:   {BACKUP}")
print(f"Rollback: cp {BACKUP} {GIR} && systemctl restart globaleye")
print(f"Activate: systemctl restart globaleye")
