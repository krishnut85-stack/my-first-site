import shutil, ast, subprocess, datetime, sys
F="/home/globalbot/gir.py"
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak=f"{F}.bak.guard_{ts}"; shutil.copy2(F,bak); print(f"[backup] {bak}")
src=open(F).read()
OLD="                    _v212_elev = _v212_today_high / _v212_today_open"
NEW=("                    # PATCH_FNOTIMING: block on CURRENT price vs open, not today's HIGH.\n"
     "                    _v212_now = _v212_q.get(\"last_price\", 0) or _v212_today_high\n"
     "                    _v212_elev = _v212_now / _v212_today_open")
c=src.count(OLD)
if c!=1:
    print(f"[FAIL] guard anchor count={c} - aborting. Run: grep -n '_v212_elev = _v212_today_high' /home/globalbot/gir.py"); sys.exit(1)
src=src.replace(OLD,NEW)
open(F,"w").write(src)
try: ast.parse(open(F).read()); print("[ok] AST valid")
except SyntaxError as e: shutil.copy2(bak,F); print(f"[ROLLBACK] {e}"); sys.exit(1)
print("[ok] guard: high -> current price")
print("[restart] globaleye.service")
r=subprocess.run(["systemctl","restart","globaleye.service"])
print("[DONE] both F&O timing fixes applied" if r.returncode==0 else "[WARN] check service status")
