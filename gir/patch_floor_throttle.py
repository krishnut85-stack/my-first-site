import ast, shutil, sys
from datetime import datetime
T = "/home/globalbot/gir_eq_floor.py"
MARK = "RATE_SLEEP throttle"
src = open(T).read()
if MARK in src:
    print("Already throttled."); sys.exit(0)
# add config constant after HIST_BARS
anchor1 = "HIST_BARS       = 80"
if src.count(anchor1) != 1:
    print(f"ABORT: HIST_BARS anchor count {src.count(anchor1)}"); sys.exit(1)
src = src.replace(anchor1, anchor1 + "\nRATE_SLEEP      = 0.5         # secs between Kite calls (2/sec; limit ~3/sec)  # RATE_SLEEP throttle", 1)
# add sleep+import inside daily_ohlc, right after the function's first line
anchor2 = "def daily_ohlc(kite, token, bars=HIST_BARS):\n    to = datetime.now()"
if src.count(anchor2) != 1:
    print(f"ABORT: daily_ohlc anchor count {src.count(anchor2)}"); sys.exit(1)
src = src.replace(anchor2,
    "def daily_ohlc(kite, token, bars=HIST_BARS):\n    import time as _t; _t.sleep(RATE_SLEEP)\n    to = datetime.now()", 1)
try: ast.parse(src)
except SyntaxError as e: print(f"ABORT AST: {e}"); sys.exit(1)
bak = f"{T}.bak_{datetime.now():%Y%m%d_%H%M%S}"
shutil.copy2(T, bak); open(T,"w").write(src)
print(f"Throttle added (0.5s/call). Backup: {bak}")
