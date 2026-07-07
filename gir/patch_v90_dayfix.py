"""V90: Fix realized P&L to be DAY contribution only, not lifetime gain on closes.

For sold-from-holdings, lifetime gain ≠ today's profit. The correct day P&L is:
- For intraday round-trips: (sell - buy) × qty
- For sold-holdings: that day's price move only — captured by Kite's day_change on holdings
- So: do NOT compute realized on sold-holdings separately. The day_change × qty
  on the holding (BEFORE the sell) already accounts for it.

Simplest correct approach: realized = sum over intraday round-trips ONLY.
Plus sum of day_change × qty for currently-held holdings.
Plus F&O pnl from positions.
This matches Kite's Day's P&L exactly.
"""
import shutil, ast
from pathlib import Path

GIR = Path('/home/globalbot/gir.py')
shutil.copy(GIR, GIR.with_suffix('.py.bak_v90'))
src = GIR.read_text()

# Replace the sold-holdings branch with a no-op (don't double-count)
old = '''                    elif _sq and not _bq:
                        # SELL of existing holding (CNC sold-holding) — realized vs avg cost
                        _hold = next((h for h in kite.holdings() if h['tradingsymbol']==_sym), None)
                        if _hold:
                            _cost = _hold.get('average_price', 0)
                            _sv = sum(q*p for q,p in _t['s'])
                            _as_ = _sv/_sq
                            _r = (_as_ - _cost) * _sq
                            realized_total += _r
                            realized_lines.append(f"  {_sym[:18]:18s} {_sq:>4} @ {_cost:.2f}->{_as_:.2f} = Rs.{_r:+,.0f}")'''

new = '''                    elif _sq and not _bq:
                        # PATCH_V90: SOLD-HOLDING (sold what we held from before).
                        # The day P&L for this is ALREADY in Kite's day_change×qty on the
                        # holding for the period before the sell. Showing lifetime gain
                        # here would double-count and inflate "today's profit".
                        # Just record the trade for visibility, don't add to realized total.
                        _sv = sum(q*p for q,p in _t['s'])
                        _as_ = _sv/_sq
                        realized_lines.append(f"  {_sym[:18]:18s} sold {_sq} @ {_as_:.2f} (lifetime gain not counted as day profit)")'''

if old not in src:
    print("V90 anchor not found — V89 sold-holding block missing or modified")
    exit(1)

src2 = src.replace(old, new, 1)
ast.parse(src2)
GIR.write_text(src2)
print("V90 applied — realized calc now matches Kite's Day's P&L definition")
