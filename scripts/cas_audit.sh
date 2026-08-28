#!/usr/bin/env bash
# Find session-timing assumptions that CAS (live 2026-08-03) invalidated.
#
#   bash scripts/cas_audit.sh /path/to/garuda
#
# Reports only; changes nothing. Run it on the droplet against any bot's source
# tree and paste the output back into the chat - it is enough to write the patch.
set -uo pipefail

ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "no such directory: $ROOT" >&2; exit 2; }

RG=(grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__
    --exclude-dir=.venv --exclude-dir=archive --exclude-dir=downloads --exclude='*.bak*' --exclude='*backup*')

hits=0
section() {
  local title="$1" why="$2" pattern="$3"
  local out
  out="$("${RG[@]}" "$pattern" "$ROOT" 2>/dev/null)" || true
  [ -z "$out" ] && return 0
  hits=$((hits + 1))
  printf '\n=== %s ===\n%s\n\n%s\n' "$title" "$why" "$out"
}

cat <<'HDR'
CAS audit - what the Closing Auction Session broke
==================================================
Since 2026-08-03:
  * Category I stocks (F&O on both exchanges) stop continuous trading at 15:15
    and close via auction; the closing price is published at 15:35.
  * Category II stocks still trade to 15:30 on the old VWAP close.
  * Equity derivatives now run to 15:40.
Each hit below is a line that assumed the old single 09:15-15:30 day.
HDR

section "Hardcoded 15:30 close" \
  "15:30 is no longer any instrument's close: cash CAS stocks stop at 15:15, F&O at 15:40." \
  '15:30|15[[:space:]]*,[[:space:]]*30|(^|[^_[:alnum:]])hour[[:space:]]*==?[[:space:]]*15'

section "Square-off / exit windows" \
  "A 15:20-15:30 square-off now runs entirely inside the auction, with the underlying frozen. Exit by 15:10." \
  'square[_ -]?off|squareoff|SQUARE_OFF|exit_all|force_exit|hard_exit'

section "Market-open gates" \
  "These decide whether to trade or read a quote; they must distinguish continuous trading from the auction." \
  'is_market_(open|hours)|market_open_now|_market_open|MARKET_CLOSE|MARKET_OPEN|is_open\(|market_status'

section "EOD snapshots and reports" \
  "Anything at 15:25/15:30/15:35 fires before the close is final (15:35) or while F&O still trades (to 15:40). Use 15:41+." \
  '15[:,][[:space:]]*(2[0-9]|3[0-9])|eod|EOD|end_of_day|daily_summary|snapshot'

section "Closing-price / VWAP computations" \
  "The close is no longer a last-30-minute VWAP for Category I stocks - it is the auction equilibrium price." \
  'vwap|VWAP|closing_price|close_price|last_30|prev_close'

section "Cron / systemd schedules" \
  "A job at 10:00 UTC (15:30 IST) now runs mid-auction. Shift to 10:11 UTC (15:41 IST) or later." \
  'crontab|cron|OnCalendar|schedule|10:0[0-9] |0 10 '

if [ "$hits" -eq 0 ]; then
  echo
  echo "No timing assumptions found - either already CAS-aware, or the logic lives elsewhere."
fi

cat <<'FTR'

----------------------------------------------------------------------
Fix: import the shared calendar instead of hardcoding times.

    import market_session as ms

    ms.is_cash_open()          # continuous trading only - False in auction
    ms.is_derivatives_open()   # to 15:40
    ms.status_label()          # "AUCTION - ORDER ENTRY", for the header badge
    ms.closing_price_final()   # gate EOD snapshots on this
    ms.eod_safe()              # True from 15:41
    ms.recommended_squareoff() # 15:10
    ms.is_cas_security(sym, fno_underlyings)
FTR
