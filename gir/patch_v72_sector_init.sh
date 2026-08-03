#!/bin/bash
# PATCH_V72_SECTOR_INIT
# Bug: PATCH_V70_AUDIT_CLEANUP wrongly removed _last_refresh_minute from
#      SectorRotation.__init__ (it removed the SectorRotation init line,
#      mistaking it for the genuinely-dead EquityModule one).
# Effect: gir.py:9289 reads self._sector_rotation._last_refresh_minute
#         on first F&O tick post-restart -> AttributeError every tick
#         until... never. Recovers only on next 15-min boundary if lucky.
# Fix: restore the attribute init in SectorRotation.__init__.

set -e
FILE=/home/globalbot/gir.py
BACKUP=/home/globalbot/gir.py.bak_v72_$(date +%Y%m%d_%H%M%S)

cp "$FILE" "$BACKUP"
echo "Backup: $BACKUP"

python3 << 'PYEOF'
import re, sys

path = "/home/globalbot/gir.py"
with open(path) as f:
    code = f.read()

# Anchor: the V70 cleanup comment line in SectorRotation.__init__
old = '        self.ranking_file = DATA_DIR / "sector_ranking.json"\n        # PATCH_V70_AUDIT_CLEANUP: removed unused self._last_refresh_minute (different attr on _sector_rotation)\n        self._ranking = {}'

new = '        self.ranking_file = DATA_DIR / "sector_ranking.json"\n        # PATCH_V72_SECTOR_INIT: restore _last_refresh_minute that V70 wrongly removed.\n        # Used by FnoModule.tick() at gir.py L9289 to throttle refresh to once per 15min.\n        self._last_refresh_minute = -1\n        self._ranking = {}'

if old not in code:
    print("ANCHOR NOT FOUND — aborting. Inspect manually.")
    sys.exit(1)

# Verify only ONE occurrence (uniqueness check before mutation)
if code.count(old) != 1:
    print(f"ANCHOR matched {code.count(old)} times — must be exactly 1. Aborting.")
    sys.exit(1)

code = code.replace(old, new)

# Verify no double-init (defensive)
sr_init_count = code.count("self._last_refresh_minute = -1")
if sr_init_count != 1:
    print(f"WARN: _last_refresh_minute init count = {sr_init_count} (expected 1).")
    # Don't abort if extra — could be FnoModule init too. Just inform.

with open(path, "w") as f:
    f.write(code)

# Compile check
import py_compile
try:
    py_compile.compile(path, doraise=True)
    print("SYNTAX: CLEAN")
except py_compile.PyCompileError as e:
    print(f"SYNTAX ERROR: {e}")
    sys.exit(1)

print("PATCH_V72_SECTOR_INIT: applied successfully")
PYEOF

# Verify the patch is in the file
echo ""
echo "=== Verification ==="
grep -n "PATCH_V72_SECTOR_INIT\|_last_refresh_minute" /home/globalbot/gir.py | head -10

echo ""
echo "=== Restarting service ==="
systemctl restart globaleye
sleep 5
systemctl status globaleye --no-pager | head -10

echo ""
echo "=== Watching for SectorRotation errors (30s) ==="
timeout 30 journalctl -u globaleye -f --no-pager | grep -iE "SectorRotation|_last_refresh|FNO tick error" || echo "No SectorRotation errors in 30s window — good"
