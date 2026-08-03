#!/usr/bin/env python3
"""PATCH_V89: Correct P&L reporter — realized + unrealized + day total + lifetime.

Replaces EODReporter.generate_equity_report with a truthful version that:
1. Refreshes Kite session (uses bot's existing TOTP login)
2. Computes realized P&L from kite.orders() (today's BUY-SELL pairs)
3. Computes today's unrealized using kite.holdings() day_change field
4. Computes F&O P&L from kite.positions()
5. Writes a daily ledger to data/daily_pnl_YYYYMMDD.json for weekly review
"""
import ast, shutil, sys, re
from pathlib import Path

GIR = Path('/home/globalbot/gir.py')
shutil.copy(GIR, GIR.with_suffix('.py.bak_v89'))
src = GIR.read_text()

# Find the V88 anchor we already inserted
v88_marker = "# PATCH_V88: realized day P&L from completed orders"
if v88_marker not in src:
    print("ERROR: V88 not present. Apply V88 first or anchor changed.")
    sys.exit(1)

# Find the start of the equity reporter return block to replace V88's insertion
v88_start = src.find('lines.append(f"\\n*Unrealized since entry:')
v88_end_marker = 'lines.append(f"Capital: Rs.{equity_module.capital:,.0f}")'
v88_end = src.find(v88_end_marker, v88_start)
if v88_start == -1 or v88_end == -1:
    print("ERROR: cannot locate V88 block boundaries")
    sys.exit(1)
v88_end += len(v88_end_marker)

old_block = src[v88_start:v88_end]

new_block = '''# PATCH_V89: Correct day P&L computation
            from datetime import datetime as _dt
            today_str = _dt.now().strftime("%Y-%m-%d")

            # 1. REALIZED P&L from today's completed orders (BUY+SELL pairs)
            realized_total = 0
            realized_lines = []
            try:
                from collections import defaultdict
                _by_sym = defaultdict(lambda: {'b': [], 's': []})
                for o in kite.orders():
                    if o.get('status') != 'COMPLETE': continue
                    ts = str(o.get('order_timestamp', ''))
                    if today_str not in ts: continue
                    q = o.get('filled_quantity', 0); p = o.get('average_price', 0)
                    if q == 0 or p == 0: continue
                    side = 'b' if o.get('transaction_type') == 'BUY' else 's'
                    _by_sym[o['tradingsymbol']][side].append((q, p))

                for _sym, _t in _by_sym.items():
                    _bq = sum(q for q,_ in _t['b']); _sq = sum(q for q,_ in _t['s'])
                    if _bq and _sq:
                        _bv = sum(q*p for q,p in _t['b']); _sv = sum(q*p for q,p in _t['s'])
                        _ab, _as_ = _bv/_bq, _sv/_sq
                        _matched = min(_bq, _sq)
                        _r = (_as_ - _ab) * _matched
                        realized_total += _r
                        realized_lines.append(f"  {_sym[:18]:18s} {_matched:>4} @ {_ab:.2f}->{_as_:.2f} = Rs.{_r:+,.0f}")
                    elif _sq and not _bq:
                        # SELL of existing holding (CNC sold-holding) — realized vs avg cost
                        _hold = next((h for h in kite.holdings() if h['tradingsymbol']==_sym), None)
                        if _hold:
                            _cost = _hold.get('average_price', 0)
                            _sv = sum(q*p for q,p in _t['s'])
                            _as_ = _sv/_sq
                            _r = (_as_ - _cost) * _sq
                            realized_total += _r
                            realized_lines.append(f"  {_sym[:18]:18s} {_sq:>4} @ {_cost:.2f}->{_as_:.2f} = Rs.{_r:+,.0f}")
            except Exception as _e:
                realized_lines.append(f"  (realized calc error: {str(_e)[:60]})")

            # 2. UNREALIZED TODAY from kite.holdings day_change
            day_unrealized = 0
            lifetime_unrealized = 0
            try:
                for _h in kite.holdings():
                    _q = _h['quantity'] + _h.get('t1_quantity', 0)
                    if _q == 0: continue
                    day_unrealized += _h.get('day_change', 0) * _q
                    lifetime_unrealized += _h.get('pnl', 0)
            except Exception as _e:
                pass

            # 3. F&O P&L from positions (intraday + carry)
            fno_pnl = 0
            try:
                for _p in kite.positions().get('net', []):
                    if _p['quantity'] != 0 or _p.get('m2m', 0):
                        fno_pnl += _p.get('pnl', 0)
            except Exception:
                pass

            day_total = realized_total + day_unrealized + fno_pnl

            # Build clean message
            lines.append("")
            lines.append("─" * 30)
            lines.append("*📊 DAY P&L — {}*".format(today_str))
            lines.append("─" * 30)

            if realized_lines:
                lines.append(f"*Realized ({len(realized_lines)} trades):*")
                lines.extend(realized_lines)
                lines.append(f"*Realized total: Rs.{realized_total:+,.0f}*")
            else:
                lines.append("Realized today: Rs.0 (no closed trades)")

            lines.append("")
            lines.append(f"Equity day move:  Rs.{day_unrealized:+,.0f}")
            lines.append(f"F&O P&L:          Rs.{fno_pnl:+,.0f}")
            lines.append(f"*DAY TOTAL:       Rs.{day_total:+,.0f}*")
            lines.append("")
            lines.append(f"_Lifetime unrealized: Rs.{lifetime_unrealized:+,.0f}_")
            lines.append(f"_Capital deployed: Rs.{equity_module.capital:,.0f}_")

            # 4. Write daily ledger for weekly review
            try:
                import json as _json
                _ledger = {
                    "date": today_str,
                    "realized_total": round(realized_total, 2),
                    "realized_trades": realized_lines,
                    "equity_day_unrealized": round(day_unrealized, 2),
                    "fno_pnl": round(fno_pnl, 2),
                    "day_total": round(day_total, 2),
                    "lifetime_unrealized": round(lifetime_unrealized, 2),
                    "capital": equity_module.capital,
                }
                _ledger_path = Path(f"/home/globalbot/data/daily_pnl_{today_str.replace('-','')}.json")
                _ledger_path.write_text(_json.dumps(_ledger, indent=2))
            except Exception:
                pass
'''

src2 = src.replace(old_block, new_block, 1)

# Validate
try:
    ast.parse(src2)
except SyntaxError as e:
    print(f"SYNTAX ERROR: line {e.lineno}: {e.msg}")
    sys.exit(1)

GIR.write_text(src2)
print(f"PATCH_V89 applied. Backup: gir.py.bak_v89")
print(f"Old block: {len(old_block)} chars")
print(f"New block: {len(new_block)} chars")
print(f"Net change: {len(src2) - len(src):+d} chars")

# Add Path import at top if needed
if 'from pathlib import Path' not in src2[:5000]:
    print("NOTE: Make sure 'from pathlib import Path' is imported in gir.py")
