import shutil, ast, subprocess, datetime, re, sys
F="/home/globalbot/gir.py"
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak=f"{F}.bak.interval_{ts}"; shutil.copy2(F,bak); print(f"[backup] {bak}")
src=open(F).read()
m=re.search(r"^FNO_SCAN_INTERVAL_MIN\s*=\s*15\b.*$", src, re.M)
if not m: print("[FAIL] interval anchor not found"); sys.exit(1)
src=src[:m.start()]+"FNO_SCAN_INTERVAL_MIN = 3        # PATCH_FNOTIMING: 15->3, act on signals within 3min"+src[m.end():]
open(F,"w").write(src)
try: ast.parse(open(F).read()); print("[ok] AST valid")
except SyntaxError as e: shutil.copy2(bak,F); print(f"[ROLLBACK] {e}"); sys.exit(1)
print("[ok] interval -> 3")
