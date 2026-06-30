#!/bin/bash
set -e

GIR=/home/globalbot/gir.py
NB=/home/globalbot/news_brain.py
TS=$(date +%Y%m%d_%H%M%S)

echo "=== PATCH_V74_ALPHA_UNLEASH ==="
echo "Timestamp: $TS"
echo ""

# 1. Backups
cp $GIR ${GIR}.bak_v74_${TS}
cp $NB  ${NB}.bak_v74_${TS}
echo "[1/12] Backups created:"
ls -lh ${GIR}.bak_v74_${TS} ${NB}.bak_v74_${TS}
echo ""

# 2. Pre-patch line counts
echo "[2/12] Pre-patch line counts:"
wc -l $GIR $NB
echo ""

# 3. SITE 1: mcap range 500-5000 -> 300-50000 (Hidden Gem mcap window)
echo "[3/12] Patching mcap range 500-5000 -> 300-50000 (Hidden Gem)..."
sed -i 's|if not (500 <= mcap <= 5000): continue|if not (300 <= mcap <= 50000): continue  # V74: widened from 500-5000|' $GIR
grep -c "300 <= mcap <= 50000" $GIR
echo ""

# 4. SITE 2: durability 60 -> 50 (Hidden Gem)
echo "[4/12] Patching durability < 60 -> < 50..."
sed -i 's|if d.get("durability", 0) < 60: continue|if d.get("durability", 0) < 50: continue  # V74: relaxed from 60|' $GIR
grep -c 'durability", 0) < 50: continue' $GIR
echo ""

# 5. SITE 3: promoter/FII/MF gate: 0.3 / 2 -> 0.1 / 1
echo "[5/12] Patching institutional flow gate: sum(>=0.3)<2 -> sum(>=0.1)<1..."
sed -i 's|if sum(1 for x in \[pc, fc, mc\] if x >= 0.3) < 2: continue|if sum(1 for x in [pc, fc, mc] if x >= 0.1) < 1: continue  # V74: relaxed 0.3/2 -> 0.1/1|' $GIR
grep -c "x >= 0.1) < 1" $GIR
echo ""

# 6. SITE 4: vol_ratio < 1.5 -> < 1.3 (Hidden Gem)
echo "[6/12] Patching vol_ratio < 1.5 -> < 1.3..."
sed -i 's|if vol_ratio < 1.5: continue|if vol_ratio < 1.3: continue  # V74: relaxed from 1.5|' $GIR
grep -c "vol_ratio < 1.3: continue" $GIR
echo ""

# 7. SITE 5: min_score tiers (3 occurrences: lines 3713, 3921, 3987)
echo "[7/12] Patching min_score tiers: 60/50/40 -> 45/40/35..."
sed -i 's|_min_score = 40 if _mcap > 20000 else (50 if _mcap > 5000 else 60)|_min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35|g' $GIR
grep -c "_min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)" $GIR
echo ""

# 8. SITE 6: EQUITY_THRESHOLD 60 -> 55, FNO_THRESHOLD 72 -> 65
echo "[8/12] Patching EQUITY_THRESHOLD 60 -> 55..."
sed -i 's|^    EQUITY_THRESHOLD = 60$|    EQUITY_THRESHOLD = 55  # V74: relaxed from 60|' $GIR
grep -c "EQUITY_THRESHOLD = 55" $GIR

echo "[9/12] Patching FNO_THRESHOLD 72 -> 65..."
sed -i 's|^    FNO_THRESHOLD = 72$|    FNO_THRESHOLD = 65  # V74: relaxed from 72|' $GIR
grep -c "FNO_THRESHOLD = 65" $GIR
echo ""

# 9. SITE 7: NewsBrain min_conviction 70/60 -> 55/50
echo "[10/12] Patching NewsBrain min_conviction 70/60 -> 55/50..."
sed -i 's|self.min_conviction = 70 if self.module == "EQUITY" else 60|self.min_conviction = 55 if self.module == "EQUITY" else 50  # V74: relaxed 70/60 -> 55/50|' $NB
grep -c "self.min_conviction = 55 if self.module" $NB
echo ""

# 10. SITE 8: Citation overlap < 0.50 -> < 0.30 (both occurrences)
echo "[11/12] Patching citation overlap < 0.50 -> < 0.30..."
sed -i 's|if _overlap_ratio < 0.50:|if _overlap_ratio < 0.30:  # V74: relaxed from 0.50|g' $NB
grep -c "_overlap_ratio < 0.30" $NB
echo ""

# 11. Syntax checks
echo "[12/12] Syntax validation..."
python3 -c "import ast; ast.parse(open('$GIR').read())" && echo "  gir.py: SYNTAX OK"
python3 -c "import ast; ast.parse(open('$NB').read())" && echo "  news_brain.py: SYNTAX OK"
echo ""

# 12. Restart and verify
echo "=== RESTARTING SERVICE ==="
systemctl restart globaleye
sleep 8
STATUS=$(systemctl is-active globaleye)
echo "Service status: $STATUS"
echo ""

if [ "$STATUS" = "active" ]; then
    echo "=== PATCH_V74 APPLIED SUCCESSFULLY ==="
    echo ""
    echo "Last 15 log lines:"
    journalctl -u globaleye --since "30 seconds ago" --no-pager | tail -15
else
    echo "=== !!! SERVICE FAILED TO START — ROLLING BACK !!! ==="
    cp ${GIR}.bak_v74_${TS} $GIR
    cp ${NB}.bak_v74_${TS} $NB
    systemctl restart globaleye
    sleep 5
    echo "Rollback status: $(systemctl is-active globaleye)"
    echo ""
    echo "Recent error logs:"
    journalctl -u globaleye --since "1 minute ago" --no-pager | tail -30
    exit 1
fi

echo ""
echo "=== V74 SUMMARY ==="
echo "  Hidden Gem mcap window:    500-5000   -> 300-50000"
echo "  Hidden Gem durability:     <60        -> <50"
echo "  Hidden Gem institutional:  >=0.3/2    -> >=0.1/1"
echo "  Hidden Gem vol_ratio:      <1.5       -> <1.3"
echo "  min_score tiers:           60/50/40   -> 45/40/35"
echo "  EQUITY_THRESHOLD:          60         -> 55"
echo "  FNO_THRESHOLD:             72         -> 65"
echo "  NewsBrain min_conviction:  70/60      -> 55/50"
echo "  Citation overlap:          <0.50      -> <0.30"
echo ""
echo "Backups: ${GIR}.bak_v74_${TS}"
echo "         ${NB}.bak_v74_${TS}"
echo "To rollback: cp <backup> <original> && systemctl restart globaleye"
