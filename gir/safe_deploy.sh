#!/bin/bash
# safe_deploy.sh — Phase 3 of the Replay Harness
#
# Wraps `systemctl restart globaleye` with a replay safety check.
# Refuses to restart the bot if replay against the last 5 trading days fails.
#
# Usage:
#   bash safe_deploy.sh                # standard: replay last 5 days, then restart
#   bash safe_deploy.sh --force        # skip replay, restart anyway (use only if replay is broken)
#   bash safe_deploy.sh --dry-run      # run replay only, don't restart
#
# Exit codes:
#   0  — restart succeeded (or dry-run completed cleanly)
#   1  — replay failed, restart blocked
#   2  — restart command itself failed
#   3  — pre-flight check failed (gir.py syntax, missing files)

set -e
set -u

GIR_PATH="/home/globalbot/gir.py"
REPLAY_PATH="/home/globalbot/replay_panel.py"
SERVICE="globaleye"
LAST_N_DAYS=5

FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Unknown flag: $arg"; exit 3 ;;
    esac
done

echo "═══════════════════════════════════════════════════════════"
echo "  SAFE DEPLOY — pre-restart safety gate"
echo "═══════════════════════════════════════════════════════════"
echo

# ─── Pre-flight 1: gir.py exists and parses ──────────────────────────────
echo "[1/4] Verifying gir.py syntax ..."
if [ ! -f "$GIR_PATH" ]; then
    echo "  ✗ $GIR_PATH not found"
    exit 3
fi
if ! python3 -c "import ast; ast.parse(open('$GIR_PATH').read())" 2>/dev/null; then
    echo "  ✗ gir.py has syntax errors. Fix before deploying."
    python3 -c "import ast; ast.parse(open('$GIR_PATH').read())" || true
    exit 3
fi
echo "  ✓ gir.py syntax OK"
echo

# ─── Pre-flight 2: replay_panel.py exists and imports ────────────────────
echo "[2/4] Verifying replay_panel.py ..."
if [ ! -f "$REPLAY_PATH" ]; then
    echo "  ✗ $REPLAY_PATH not found — replay harness missing"
    if [ "$FORCE" -eq 1 ]; then
        echo "  ⚠ --force given, proceeding without replay"
    else
        echo "  Run with --force to bypass."
        exit 3
    fi
fi
echo "  ✓ replay_panel.py present"
echo

# ─── Pre-flight 3: trade_recorder.py exists ──────────────────────────────
echo "[3/4] Verifying trade_recorder.py ..."
if [ ! -f "/home/globalbot/trade_recorder.py" ]; then
    echo "  ✗ trade_recorder.py not found — recording will be disabled"
    if [ "$FORCE" -eq 0 ]; then
        echo "  Run with --force to bypass."
        exit 3
    fi
fi
echo "  ✓ trade_recorder.py present"
echo

# ─── Replay check ────────────────────────────────────────────────────────
if [ "$FORCE" -eq 1 ]; then
    echo "[4/4] Replay check SKIPPED (--force)"
else
    echo "[4/4] Running replay against last $LAST_N_DAYS trading days ..."
    echo
    if python3 "$REPLAY_PATH" --last "$LAST_N_DAYS" --strict; then
        echo
        echo "  ✓ Replay PASSED — current gir.py reproduces historical decisions"
    else
        echo
        echo "  ✗ Replay FAILED — current gir.py would change historical decisions"
        echo "  Restart BLOCKED."
        echo
        echo "  Options:"
        echo "    1. Fix the regression in gir.py and try again"
        echo "    2. If the change is intentional, run: bash safe_deploy.sh --force"
        echo "    3. Roll back to the most recent gir.py.bak_* file"
        exit 1
    fi
fi
echo

# ─── Restart ─────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "  DRY RUN — bot NOT restarted"
    echo "═══════════════════════════════════════════════════════════"
    exit 0
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Restarting $SERVICE ..."
echo "═══════════════════════════════════════════════════════════"
if systemctl restart "$SERVICE"; then
    sleep 5
    if systemctl is-active --quiet "$SERVICE"; then
        echo "  ✓ $SERVICE is active"
        echo
        echo "Last 20 log lines:"
        journalctl -u "$SERVICE" -n 20 --no-pager
        exit 0
    else
        echo "  ✗ $SERVICE restarted but is not active"
        journalctl -u "$SERVICE" -n 30 --no-pager
        exit 2
    fi
else
    echo "  ✗ systemctl restart failed"
    exit 2
fi
