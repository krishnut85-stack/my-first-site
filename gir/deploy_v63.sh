#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  GIR V63 DEPLOYMENT SCRIPT (CLEANED — duplicate index logic removed)
#
#  Cumulative patches over original gir.py:
#  ── V62 input quality ──
#    1. PATCH_V62_GLOBAL_FEEDS    — 5 global RSS feeds added
#    2. PATCH_V62_INDENT_FIX      — _NAME_MAP indentation bug
#    3. PATCH_V62_FILING_RETRY    — NSE 403 retry with cookie refresh
#    4. PATCH_V62_BROKERAGE_DOC   — signature documentation
#    5. PATCH_V62_MACRO_BODY      — title+summary matching
#    6. PATCH_V62_ECON_CALENDAR   — F&O event-window block
#    7. PATCH_V62_PREMARKET       — overnight global bias log
#  ── V63 decision quality ──
#    8. PATCH_V63_INDEX_ROUTING   — IndexMacroDetector class for index trades
#    9. PATCH_V63_INDEX_NEWS_SCORE — boost news score for IndexMacroDetector candidates
#   10. PATCH_V63_STRICT_DIR      — strict CE/PE direction match
#   11. PATCH_V63_PANEL_TRACKER   — daily JSONL of every panel decision
#
#  USAGE (on droplet, in /home/globalbot):
#    1. Upload gir_v63.py to /home/globalbot/gir_v63.py
#    2. bash deploy_v63.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -e

cd /home/globalbot

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v63_${TS}"

echo "=== GIR V63 DEPLOYMENT (CLEANED) ==="
echo "Timestamp: $TS"
echo ""

if [ ! -f "gir_v63.py" ]; then
    echo "ERROR: gir_v63.py not found in /home/globalbot/"
    exit 1
fi

echo "[1/7] Compile-checking gir_v63.py..."
python3 -c "import py_compile; py_compile.compile('gir_v63.py', doraise=True)" || {
    echo "FATAL: gir_v63.py does not compile. Aborting."
    exit 1
}
echo "      OK"

echo "[2/7] Backing up current gir.py to $BACKUP"
cp gir.py "$BACKUP"
echo "      $(ls -lh $BACKUP | awk '{print $5, $9}')"

echo "[3/7] Verifying patch markers..."
V62=$(grep -c "PATCH_V62" gir_v63.py)
V63=$(grep -c "PATCH_V63" gir_v63.py)
echo "      V62 markers: $V62 (expect ~19)"
echo "      V63 markers: $V63 (expect ~23)"
if [ "$V62" -lt 15 ] || [ "$V63" -lt 18 ]; then
    echo "FATAL: marker counts too low. Aborting."
    exit 1
fi

echo "[4/7] Verifying NO duplicate index logic..."
DUP1=$(grep -c "_compute_index_directions" gir_v63.py)
DUP2=$(grep -c "PATCH_V63_INDEX_DIRECTIONAL" gir_v63.py)
if [ "$DUP1" -ne 0 ] || [ "$DUP2" -ne 0 ]; then
    echo "FATAL: duplicate index logic detected (compute=$DUP1 directional=$DUP2). Aborting."
    exit 1
fi
echo "      Clean: no duplicate index logic"

OLD_LINES=$(wc -l < gir.py)
NEW_LINES=$(wc -l < gir_v63.py)
DIFF=$((NEW_LINES - OLD_LINES))
echo "[5/7] Line count: old=$OLD_LINES new=$NEW_LINES diff=+$DIFF (expect ~547)"
if [ "$DIFF" -lt 300 ] || [ "$DIFF" -gt 800 ]; then
    echo "WARN: Diff=$DIFF lines is outside expected range (300-800)."
    read -p "      Continue anyway? (y/n): " yn
    [ "$yn" = "y" ] || exit 1
fi

echo "[6/7] Replacing gir.py with gir_v63.py"
mv gir_v63.py gir.py
python3 -c "import py_compile; py_compile.compile('gir.py', doraise=True)" || {
    echo "FATAL: Post-move compile failed. Restoring backup."
    cp "$BACKUP" gir.py
    exit 1
}

# Verify all critical components present
for marker in "IndexMacroDetector" "EconCalendar" "GlobalPreMarket" "_record_panel_decision" "PATCH_V63_STRICT_DIR" "PATCH_V63_INDEX_NEWS_SCORE" "PATCH_V62_MACRO_BODY"; do
    if ! grep -q "$marker" gir.py; then
        echo "FATAL: Marker $marker missing. Rolling back."
        cp "$BACKUP" gir.py
        exit 1
    fi
done
echo "      All critical markers present"

echo "[7/7] Restarting globaleye service"
systemctl restart globaleye
sleep 3
systemctl is-active globaleye && echo "      Service ACTIVE" || {
    echo "FATAL: Service failed to start."
    echo "       journalctl -u globaleye -n 50 --no-pager"
    cp "$BACKUP" gir.py
    systemctl restart globaleye
    exit 1
}

echo ""
echo "=== V63 DEPLOYMENT COMPLETE ==="
echo "Backup: $BACKUP"
echo ""
echo "Verify with:"
echo "  journalctl -u globaleye -f | grep -E 'PATCH_V62|PATCH_V63|INDEX|PANEL_TRACKER'"
echo ""
echo "Expected new log lines:"
echo "  - [PATCH_V63] IndexMacroDetector initialized (tradeable=...)"
echo "  - INDEX_MACRO candidates appearing in scout list (when matching news fires)"
echo "  - [PATCH_V62_PREMARKET] overnight bias=... (08:55 IST mornings)"
echo "  - File: data/panel_decisions_YYYYMMDD.jsonl (every panel evaluation)"
echo ""
echo "Friday review query:"
echo "  cat /home/globalbot/data/panel_decisions_\$(date +%Y%m%d).jsonl | python3 -c \\"
echo "    \"import sys,json; rows=[json.loads(l) for l in sys.stdin]; \\"
echo "     print('Total:',len(rows),'TRADE:',sum(1 for r in rows if r['allow']),\\"
echo "           'BLOCK:',sum(1 for r in rows if not r['allow']))\""
echo ""
echo "ROLLBACK if needed:"
echo "  cp $BACKUP gir.py && systemctl restart globaleye"
