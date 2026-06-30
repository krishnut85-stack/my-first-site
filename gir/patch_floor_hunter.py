import ast, shutil, sys
from datetime import datetime
T = "/home/globalbot/gir_eq_floor.py"
if "_hunter_held" in open(T).read():
    print("Already de-conflicted with Hunter."); sys.exit(0)
src = open(T).read()

a1 = 'def _is_open(trades, sym):\n    return any(t["symbol"] == sym for t in _floor_open(trades))'
if src.count(a1) != 1: print(f"ABORT a1 count {src.count(a1)}"); sys.exit(1)
src = src.replace(a1, a1 + '\ndef _hunter_held(trades):\n    return {t["symbol"] for t in trades if (t.get("strategy") or "").upper().startswith("HUNTER")}', 1)

a2 = '    trades = get_open_paper_trades()\n    floor_n, deployed = len(_floor_open(trades)), _deployed(trades)'
if src.count(a2) != 1: print(f"ABORT a2 count {src.count(a2)}"); sys.exit(1)
src = src.replace(a2, a2 + '\n    blocked = _hunter_held(trades)', 1)

a3 = '        if sym not in instr or _is_open(trades, sym): continue'
if src.count(a3) != 1: print(f"ABORT a3 count {src.count(a3)}"); sys.exit(1)
src = src.replace(a3, '        if sym not in instr or _is_open(trades, sym) or sym in blocked: continue', 1)

try: ast.parse(src)
except SyntaxError as e: print(f"ABORT AST: {e}"); sys.exit(1)
bak = f"{T}.bak_{datetime.now():%Y%m%d_%H%M%S}"
shutil.copy2(T, bak); open(T,"w").write(src)
print(f"Hunter de-confliction added. Backup: {bak}")
