#!/usr/bin/env python3
"""PATCH_V88: EOD reporter shows true day P&L (realized buy/sell + unrealized)."""
import ast, shutil, sys, re
from pathlib import Path

GIR = Path('/home/globalbot/gir.py')
shutil.copy(GIR, GIR.with_suffix('.py.bak_v88'))
src = GIR.read_text()

# Find anchor: the 3 lines before "return \"\\n\".join(lines)" in generate_equity_report
anchor = re.search(
    r'(            lines\.append\(f"\\n\*Total P&L: Rs\.\{total_pnl:,\.0f\}\*"\)\n'
    r'            lines\.append\(f"Capital: Rs\.\{equity_module\.capital:,\.0f\}"\)\n)',
    src
)
if not anchor:
    print("Anchor not found. Showing reporter return area:")
    idx = src.find("Total P&L: Rs.{total_pnl")
    print(src[max(0,idx-200):idx+400])
    sys.exit(1)

replacement = '''            lines.append(f"\\n*Unrealized since entry: Rs.{total_pnl:,.0f}*")

            # PATCH_V88: realized day P&L from completed orders
            realized_today = 0
            closed_count = 0
            try:
                from collections import defaultdict
                _by_sym = defaultdict(lambda: {'b': [], 's': []})
                for o in kite.orders():
                    if o.get('status') != 'COMPLETE': continue
                    q = o.get('filled_quantity', 0); p = o.get('average_price', 0)
                    if q == 0: continue
                    side = 'b' if o['transaction_type'] == 'BUY' else 's'
                    _by_sym[o['tradingsymbol']][side].append((q, p))
                for _sym, _t in _by_sym.items():
                    _bq = sum(q for q,_ in _t['b']); _sq = sum(q for q,_ in _t['s'])
                    if _bq and _sq:
                        _bv = sum(q*p for q,p in _t['b']); _sv = sum(q*p for q,p in _t['s'])
                        realized_today += (_sv/_sq - _bv/_bq) * min(_bq, _sq)
                        closed_count += 1
            except Exception as _e:
                lines.append(f"_(realized calc skipped: {_e})_")

            lines.append(f"*Realized today: Rs.{realized_today:+,.0f}* ({closed_count} closed)")
            lines.append(f"*DAY TOTAL: Rs.{total_pnl + realized_today:+,.0f}*")
            lines.append(f"Capital: Rs.{equity_module.capital:,.0f}")
'''

src2 = src.replace(anchor.group(1), replacement, 1)

try:
    ast.parse(src2)
except SyntaxError as e:
    print(f"SYNTAX ERROR: {e}"); sys.exit(1)

GIR.write_text(src2)
print(f"PATCH_V88 applied. Backup: gir.py.bak_v88")
print(f"Lines added: {src2.count(chr(10)) - src.count(chr(10))}")
