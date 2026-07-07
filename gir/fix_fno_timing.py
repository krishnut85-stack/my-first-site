import shutil, ast, subprocess, datetime, sys
F = "/home/globalbot/gir.py"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = f"{F}.bak.fnotiming_{ts}"
shutil.copy2(F, bak); print(f"[backup] {bak}")
src = open(F).read()

# ---- PATCH 1: scan interval 15 -> 3 ----
OLD1 = "FNO_SCAN_INTERVAL_MIN = 15        # Scan every 15 minutes"
NEW1 = "FNO_SCAN_INTERVAL_MIN = 3        # PATCH_FNOTIMING: 15->3, act on signals within 3min (was entering after 15min runup)"
if src.count(OLD1) != 1:
    # tolerate spacing variance
    import re
    m = re.search(r"FNO_SCAN_INTERVAL_MIN\s*=\s*15\b[^\n]*", src)
    if not m:
        print(f"[FAIL] PATCH1 anchor not found"); sys.exit(1)
    OLD1 = m.group(0)
    NEW1 = "FNO_SCAN_INTERVAL_MIN = 3        # PATCH_FNOTIMING: 15->3, act on signals within 3min (was entering after 15min runup)"
src = src.replace(OLD1, NEW1, 1)
print("[ok] PATCH1 applied (interval 15->3)")

# ---- PATCH 2: guard uses CURRENT price, not today's HIGH ----
OLD2 = '''            _v212_today_open = _v212_ohlc.get("open", 0) or 0
            _v212_today_high = _v212_ohlc.get("high", 0) or 0
            if _v212_today_open > 0 and _v212_today_high > 0:
                _v212_elev = _v212_today_high / _v212_today_open'''
NEW2 = '''            _v212_today_open = _v212_ohlc.get("open", 0) or 0
            _v212_today_high = _v212_ohlc.get("high", 0) or 0
            # PATCH_FNOTIMING: block on CURRENT price vs open, not today's HIGH vs open.
            # Old logic blocked options that merely spiked earlier and reversed; this
            # blocks only options expensive RIGHT NOW. last_price already in _v212_q.
            _v212_now = _v212_q.get("last_price", 0) or _v212_today_high
            if _v212_today_open > 0 and _v212_now > 0:
                _v212_elev = _v212_now / _v212_today_open'''
if src.count(OLD2) != 1:
    print(f"[FAIL] PATCH2 anchor count={src.count(OLD2)} - aborting, no change written"); sys.exit(1)
src = src.replace(OLD2, NEW2)
print("[ok] PATCH2 applied (guard: high->current price)")

# ---- write + AST validate + auto-rollback ----
open(F, "w").write(src)
try:
    ast.parse(open(F).read()); print("[ok] AST valid")
except SyntaxError as e:
    shutil.copy2(bak, F); print(f"[ROLLBACK] syntax error: {e}"); sys.exit(1)

print("[restart] globaleye.service")
r = subprocess.run(["systemctl","restart","globaleye.service"])
if r.returncode != 0:
    print("[WARN] restart nonzero - check: systemctl status globaleye.service")
print(f"[DONE] F&O timing fix applied. backup: {bak}")
