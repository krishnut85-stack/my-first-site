#!/bin/bash
set -e

GIR=/home/globalbot/gir.py
NB=/home/globalbot/news_brain.py
TS=$(date +%Y%m%d_%H%M%S)

echo "=== PATCH_V75_FINAL — completing the unfinished V74 work ==="
echo "Timestamp: $TS"
echo ""

# Backups
cp $GIR ${GIR}.bak_v75_${TS}
cp $NB  ${NB}.bak_v75_${TS}
echo "[1/13] Backups created:"
ls -lh ${GIR}.bak_v75_${TS} ${NB}.bak_v75_${TS}
echo ""

# 1. Chase block: 3%/5% -> 6%/10%
echo "[2/13] Patching chase_limit 3.0/5.0 -> 6.0/10.0..."
sed -i 's|_chase_limit = 5.0 if _high_conv else 3.0|_chase_limit = 10.0 if _high_conv else 6.0  # V75: relaxed 5/3 -> 10/6|' $GIR
grep -c "_chase_limit = 10.0 if _high_conv else 6.0" $GIR
echo ""

# 2. Turnover floor: line 3917 ₹1cr -> ₹50L (consistency)
echo "[3/13] Patching turnover ₹1cr -> ₹50L (line 3917 consistency)..."
sed -i 's|if volume <= 0 or volume \* ltp < 10000000|if volume <= 0 or volume * ltp < 5000000  # V75: relaxed 1cr -> 50L|' $GIR
grep -c "volume \* ltp < 5000000  # V75" $GIR
echo ""

# 3. Turnover floor: line 3979 ₹2cr -> ₹1cr (momentum scanner)
echo "[4/13] Patching momentum scanner turnover ₹2cr -> ₹1cr..."
sed -i 's|if volume <= 0 or volume \* ltp < 20000000|if volume <= 0 or volume * ltp < 10000000  # V75: relaxed 2cr -> 1cr|' $GIR
grep -c "volume \* ltp < 10000000  # V75" $GIR
echo ""

# 4. F&O spread filter: 0.05 -> 0.08
echo "[5/13] Patching FNO_MAX_SPREAD 0.05 -> 0.08..."
sed -i 's|^FNO_MAX_SPREAD = 0.05|FNO_MAX_SPREAD = 0.08  # V75: relaxed 5% -> 8%|' $GIR
grep -c "^FNO_MAX_SPREAD = 0.08" $GIR
echo ""

# 5. F&O delta windows: relax 0.30-0.60 to 0.20-0.70 (broader OTM/ATM window)
echo "[6/13] Patching F&O delta range 0.30-0.60 -> 0.20-0.70..."
sed -i 's|if 0.30 <= delta <= 0.60:|if 0.20 <= delta <= 0.70:  # V75: widened|' $GIR
grep -c "if 0.20 <= delta <= 0.70" $GIR
echo ""

# 6. F&O delta windows: 0.20-0.30 elif relaxed to 0.15-0.20
echo "[7/13] Patching F&O delta elif 0.20-0.30 -> 0.15-0.20..."
sed -i 's|elif 0.20 <= approx_delta < 0.30:|elif 0.15 <= approx_delta < 0.20:  # V75: widened|' $GIR
grep -c "elif 0.15 <= approx_delta < 0.20" $GIR
echo ""

# 7. NewsBrain MOMENTUM_MIN_PCT: 5.0 -> 2.0
echo "[8/13] Patching MOMENTUM_MIN_PCT 5.0 -> 2.0 (BIG WIN — early momentum unlock)..."
sed -i 's|^MOMENTUM_MIN_PCT = 5.0|MOMENTUM_MIN_PCT = 2.0  # V75: relaxed 5% -> 2% (catch early momentum)|' $NB
grep -c "^MOMENTUM_MIN_PCT = 2.0" $NB
echo ""

# 8. NewsBrain MOMENTUM_MIN_VOL_RATIO: 2.0 -> 1.5
echo "[9/13] Patching MOMENTUM_MIN_VOL_RATIO 2.0 -> 1.5..."
sed -i 's|^MOMENTUM_MIN_VOL_RATIO = 2.0|MOMENTUM_MIN_VOL_RATIO = 1.5  # V75: relaxed 2x -> 1.5x|' $NB
grep -c "^MOMENTUM_MIN_VOL_RATIO = 1.5" $NB
echo ""

# 9. NewsBrain momentum volume floor: 500000 -> 200000
echo "[10/13] Patching news_brain momentum volume floor 500000 -> 200000..."
sed -i 's|if volume < 500000:|if volume < 200000:  # V75: relaxed 5L -> 2L shares|' $NB
grep -c "if volume < 200000:" $NB
echo ""

# 10. CROSS_VERIFY_MAX_FEEDS_TO_CHECK: 10 -> 20
echo "[11/13] Patching CROSS_VERIFY_MAX_FEEDS_TO_CHECK 10 -> 20..."
sed -i 's|^CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 10|CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 20  # V75: increased verification depth|' $NB
grep -c "^CROSS_VERIFY_MAX_FEEDS_TO_CHECK = 20" $NB
echo ""

# 11. Syntax check
echo "[12/13] Syntax validation..."
python3 -c "import ast; ast.parse(open('$GIR').read())" && echo "  gir.py: SYNTAX OK"
python3 -c "import ast; ast.parse(open('$NB').read())" && echo "  news_brain.py: SYNTAX OK"
echo ""

# 12. Restart
echo "[13/13] Restarting service..."
systemctl restart globaleye
sleep 8
STATUS=$(systemctl is-active globaleye)
echo "Service status: $STATUS"
echo ""

if [ "$STATUS" = "active" ]; then
    echo "=== ✅ PATCH_V75 APPLIED SUCCESSFULLY ==="
    echo ""
    echo "Recent logs (15 lines):"
    journalctl -u globaleye --since "30 seconds ago" --no-pager | tail -15
else
    echo "=== ❌ SERVICE FAILED — ROLLING BACK ==="
    cp ${GIR}.bak_v75_${TS} $GIR
    cp ${NB}.bak_v75_${TS} $NB
    systemctl restart globaleye
    sleep 5
    echo "Rollback status: $(systemctl is-active globaleye)"
    echo ""
    journalctl -u globaleye --since "1 minute ago" --no-pager | tail -30
    exit 1
fi

echo ""
echo "=== V75 SUMMARY (10 fixes) ==="
echo "  1. Chase block:              3%/5%      -> 6%/10%"
echo "  2. Scanner turnover (3917):  ₹1cr       -> ₹50L"
echo "  3. Momentum turnover (3979): ₹2cr       -> ₹1cr"
echo "  4. F&O spread:               5%         -> 8%"
echo "  5. F&O delta range:          0.30-0.60  -> 0.20-0.70"
echo "  6. F&O delta elif:           0.20-0.30  -> 0.15-0.20"
echo "  7. MOMENTUM_MIN_PCT:         5.0        -> 2.0  ⭐ BIG WIN"
echo "  8. MOMENTUM_MIN_VOL_RATIO:   2.0        -> 1.5"
echo "  9. News momentum volume:     5L         -> 2L"
echo " 10. Cross-verify feeds:       10         -> 20"
echo ""
echo "=== TOTAL OF V74 + V75 = 19 RELAXATIONS APPLIED ==="
echo ""
echo "Decisions made (NOT changed, with reasoning):"
echo "  - is_quality(min_score=40): kept — 40 is already low, real DVM bottom"
echo "  - ₹50L turnover floor: kept — fair liquidity gate"
echo "  - FNO_MAX_DTE=45 / FNO_DTE_CUT_LOSERS=15: kept — was already raised in V28"
echo "  - Upper-circuit reject: kept — can't fill at upper circuit anyway"
echo "  - 'no article body' fallback: NOT applied — code already uses rss_summary fallback at line 737"
echo "  - MACRO false positive logic: NOT applied — would need careful redesign, defer to backtest data"
echo ""
echo "Backups:"
echo "  ${GIR}.bak_v75_${TS}"
echo "  ${NB}.bak_v75_${TS}"
echo ""
echo "Rollback: cp <backup> <original> && systemctl restart globaleye"
