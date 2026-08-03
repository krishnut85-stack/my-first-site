#!/bin/bash
# ============================================================================
# FNO_PAPER_STUDY hook installer  (additive, idempotent, reversible)
# Inserts ONE block into gir.py that writes each scored F&O signal to a new
# fno_signals table in events.db. Does NOT touch any other logic.
# Standing-rule compliant: backup -> insert -> ast.parse -> show diff.
# ============================================================================
set -euo pipefail
cd /home/globalbot
G=gir.py
TS=$(date +%Y%m%d_%H%M%S)

# ---- idempotency guard: refuse to double-insert ----
if grep -q "FNO_PAPER_STUDY_HOOK" "$G"; then
  echo "HOOK ALREADY PRESENT — nothing to do. (grep FNO_PAPER_STUDY_HOOK $G)"
  exit 0
fi

cp "$G" "$G.bak_fnostudy_$TS"
echo "backup: $G.bak_fnostudy_$TS"

# ---- locate the candidates.append block we audited (the OI builder) ----
# Anchor on the unique dedup comment that immediately FOLLOWS the append.
ANCHOR=$(grep -n "PATCH_V74A_OI_DEDUP: skip if same sym/direction/score" "$G" | head -1 | cut -d: -f1)
if [ -z "${ANCHOR:-}" ]; then
  echo "ERROR: anchor not found — aborting, no change made."; exit 1
fi
echo "anchor (dedup comment) at line: $ANCHOR"

# The candidate dict is appended just ABOVE the anchor. We insert our writer
# right before the dedup comment, so it runs for every appended candidate,
# using the variables already in scope: sym, direction, score, pattern, _src,
# spot_change_pct, ce_oi_change_pct, pe_oi_change_pct, _tag.
# Indentation: SPACES, matched to the dedup comment line.
INDENT=$(sed -n "${ANCHOR}p" "$G" | sed -E 's/^([[:space:]]*).*/\1/')
echo "indent width: ${#INDENT} spaces"

HOOK_FILE=$(mktemp)
cat > "$HOOK_FILE" <<PYEOF
${INDENT}# FNO_PAPER_STUDY_HOOK (additive 2026-06-17): persist signal for paper study.
${INDENT}# Never raises — wrapped so a logging failure can never block the scanner.
${INDENT}try:
${INDENT}    import sqlite3 as _fps_sql, time as _fps_time
${INDENT}    _fps_db = "/home/globalbot/paper/events.db"
${INDENT}    _fps_c = _fps_sql.connect(_fps_db, timeout=2)
${INDENT}    _fps_c.execute("CREATE TABLE IF NOT EXISTS fno_signals ("
${INDENT}        "id INTEGER PRIMARY KEY AUTOINCREMENT, ts_utc TEXT, symbol TEXT, "
${INDENT}        "direction TEXT, pattern TEXT, score REAL, spot_change_pct REAL, "
${INDENT}        "ce_oi_change_pct REAL, pe_oi_change_pct REAL, mode TEXT, "
${INDENT}        "consumed INTEGER DEFAULT 0)")
${INDENT}    _fps_c.execute("CREATE INDEX IF NOT EXISTS idx_fps_consumed ON fno_signals(consumed)")
${INDENT}    _fps_c.execute("INSERT INTO fno_signals "
${INDENT}        "(ts_utc,symbol,direction,pattern,score,spot_change_pct,"
${INDENT}        "ce_oi_change_pct,pe_oi_change_pct,mode,consumed) "
${INDENT}        "VALUES (?,?,?,?,?,?,?,?,?,0)",
${INDENT}        (_fps_time.strftime('%Y-%m-%dT%H:%M:%S', _fps_time.gmtime()),
${INDENT}         sym, direction, pattern, score, spot_change_pct,
${INDENT}         ce_oi_change_pct, pe_oi_change_pct, mode))
${INDENT}    _fps_c.commit(); _fps_c.close()
${INDENT}except Exception as _fps_e:
${INDENT}    try: log.debug(f"[FNO_PAPER_STUDY_HOOK] persist skipped: {_fps_e}")
${INDENT}    except Exception: pass
PYEOF

# ---- insert the hook block immediately BEFORE the anchor line ----
sed -i "${ANCHOR}r /dev/stdin" "$G" < /dev/null  # no-op guard
# Use awk to splice precisely before the anchor:
awk -v n="$ANCHOR" -v f="$HOOK_FILE" '
  NR==n { while ((getline line < f) > 0) print line }
  { print }
' "$G" > "$G.tmp" && mv "$G.tmp" "$G"
rm -f "$HOOK_FILE"

# ---- syntax check; auto-rollback on failure ----
if python3 -c "import ast; ast.parse(open('$G').read())" 2>/tmp/fps_ast.err; then
  echo "AST OK"
else
  echo "AST FAILED — rolling back:"; cat /tmp/fps_ast.err
  cp "$G.bak_fnostudy_$TS" "$G"
  echo "rolled back to backup. No change applied."; exit 1
fi

echo "=== inserted block (context) ==="
grep -n "FNO_PAPER_STUDY_HOOK" "$G"
NEWLINE=$(grep -n "FNO_PAPER_STUDY_HOOK (additive" "$G" | head -1 | cut -d: -f1)
sed -n "$((NEWLINE-3)),$((NEWLINE+24))p" "$G"
echo ""
echo "=== DONE. Restart to activate, then signals will persist to fno_signals: ==="
echo "    systemctl restart globaleye && sleep 3 && systemctl is-active globaleye"
