#!/bin/bash
# NO set -e — we handle errors explicitly via trap
GIR=/home/globalbot/gir.py
NB=/home/globalbot/news_brain.py
TS=$(date +%Y%m%d_%H%M%S)
GIR_BAK=${GIR}.bak_v75v2_${TS}
NB_BAK=${NB}.bak_v75v2_${TS}

rollback() {
  echo ""
  echo "!!! ROLLBACK TRIGGERED !!!"
  cp $GIR_BAK $GIR 2>/dev/null
  cp $NB_BAK  $NB  2>/dev/null
  systemctl reset-failed globaleye 2>/dev/null
  systemctl restart globaleye 2>/dev/null
  sleep 8
  echo "Service after rollback: $(systemctl is-active globaleye)"
  exit 1
}
trap rollback ERR

echo "=== PATCH_V75_FINAL_V2 (Python-based, safe) ==="
echo "Timestamp: $TS"
echo ""

# Backups
cp $GIR $GIR_BAK || rollback
cp $NB  $NB_BAK  || rollback
echo "[1/5] Backups: $GIR_BAK, $NB_BAK"
ls -lh $GIR_BAK $NB_BAK
echo ""

# Apply patches via Python — exact string match, no regex
python3 << 'PYEOF'
import sys

GIR = "/home/globalbot/gir.py"
NB  = "/home/globalbot/news_brain.py"

# Define patches as (file, old_string, new_string)
PATCHES = [
    # 1. Chase block in gir.py (line 5448 area)
    (GIR,
     "_chase_limit = 5.0 if _high_conv else 3.0",
     "_chase_limit = 10.0 if _high_conv else 6.0  # V75: relaxed 5/3 -> 10/6"),

    # 2. Turnover floor line 3917 (1cr -> 50L) — preserve trailing comment context
    (GIR,
     "if volume <= 0 or volume * ltp < 10000000:",
     "if volume <= 0 or volume * ltp < 5000000:  # V75: 1cr -> 50L"),

    # 3. Turnover floor line 3979 (2cr -> 1cr)
    (GIR,
     "if volume <= 0 or volume * ltp < 20000000:",
     "if volume <= 0 or volume * ltp < 10000000:  # V75: 2cr -> 1cr"),

    # 4. FNO_MAX_SPREAD 0.05 -> 0.08
    (GIR,
     "FNO_MAX_SPREAD = 0.05",
     "FNO_MAX_SPREAD = 0.08  # V75: 5% -> 8%"),

    # 5. NewsBrain MOMENTUM_MIN_PCT 5.0 -> 2.0 (BIG WIN)
    (NB,
     "MOMENTUM_MIN_PCT = 5.0",
     "MOMENTUM_MIN_PCT = 2.0  # V75: 5% -> 2% catch early momentum"),

    # 6. NewsBrain MOMENTUM_MIN_VOL_RATIO 2.0 -> 1.5
    (NB,
     "MOMENTUM_MIN_VOL_RATIO = 2.0",
     "MOMENTUM_MIN_VOL_RATIO = 1.5  # V75: 2x -> 1.5x"),

    # 7. NewsBrain volume floor 500000 -> 200000
    (NB,
     "if volume < 500000:",
     "if volume < 200000:  # V75: 5L -> 2L shares"),

    # 8. CROSS_VERIFY_MAX_FEEDS_TO_CHECK 10 -> 20
    (NB,
     "CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 10",
     "CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 20  # V75: increased depth"),
]

# Apply each patch with safety
files_to_write = {}
for path, old, new in PATCHES:
    if path not in files_to_write:
        with open(path, 'r') as f:
            files_to_write[path] = f.read()
    
    if old not in files_to_write[path]:
        print(f"  [FAIL] String not found in {path}: {old[:60]!r}")
        sys.exit(1)
    
    count = files_to_write[path].count(old)
    files_to_write[path] = files_to_write[path].replace(old, new, 1)
    print(f"  [OK] Replaced ({count} match): {old[:60]!r}")

# Validate syntax IN MEMORY before writing
import ast
for path, content in files_to_write.items():
    try:
        ast.parse(content)
        print(f"  [SYNTAX OK] {path}")
    except SyntaxError as e:
        print(f"  [SYNTAX FAIL] {path}: {e}")
        sys.exit(1)

# All syntax OK — now write to disk
for path, content in files_to_write.items():
    with open(path, 'w') as f:
        f.write(content)
    print(f"  [WRITTEN] {path}")

print("ALL PATCHES APPLIED IN MEMORY + SYNTAX VALIDATED + WRITTEN")
PYEOF

PYRESULT=$?
if [ $PYRESULT -ne 0 ]; then
    echo ""
    echo "Python patch script failed — restoring backups"
    rollback
fi

echo ""
echo "[2/5] Patches applied. Verifying on-disk syntax once more..."
python3 -c "import ast; ast.parse(open('$GIR').read())" || rollback
python3 -c "import ast; ast.parse(open('$NB').read())" || rollback
echo "  Both files: SYNTAX OK"
echo ""

echo "[3/5] Restarting service..."
systemctl reset-failed globaleye
systemctl restart globaleye
sleep 12

STATUS=$(systemctl is-active globaleye)
echo "[4/5] Service status: $STATUS"

if [ "$STATUS" != "active" ]; then
    echo "  Service did not start — rolling back"
    rollback
fi

echo ""
echo "[5/5] Recent logs:"
journalctl -u globaleye --since "30 seconds ago" --no-pager | tail -15
echo ""
echo "=== ✅ V75 APPLIED SUCCESSFULLY ==="
echo ""
echo "8 fixes applied (V74 + V75 = 17 total relaxations):"
echo "  1. Chase block:           3%/5%   -> 6%/10%"
echo "  2. Scanner turnover:      1cr     -> 50L"
echo "  3. Momentum turnover:     2cr     -> 1cr"
echo "  4. FNO_MAX_SPREAD:        5%      -> 8%"
echo "  5. MOMENTUM_MIN_PCT:      5.0     -> 2.0  ⭐"
echo "  6. MOMENTUM_MIN_VOL_RATIO: 2.0    -> 1.5"
echo "  7. News momentum volume:  5L      -> 2L"
echo "  8. CROSS_VERIFY feeds:    10      -> 20"
echo ""
echo "Backups:"
echo "  $GIR_BAK"
echo "  $NB_BAK"
