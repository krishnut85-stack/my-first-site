#!/usr/bin/env bash
#
# Mayura 🦚 daily paper-trading run (for cron on the droplet).
#
# Loads the venv + Kite/Telegram secrets, then runs ONE Mayura paper session on
# REAL Kite prices and Telegrams you the result. PAPER ONLY — never a real order.
#
# Usage:
#   mayura_cron.sh                 -> run ALL faces (one burst; simple, heavier)
#   mayura_cron.sh <face>          -> run ONLY that face (back-compat = "run <face>")
#   mayura_cron.sh <cmd> [face]    -> any command, e.g.  report dandapani
#                                     (faces: dandapani/senthil/subramanya/
#                                      thanikesa/solaimalai/swaminatha)
#
# STAGGER each face at its OWN cron time so they never hit the Kite API at the
# same moment — and don't fight your OTHER bots that share the same Kite token.
# Thanikesa is heaviest (~200 live OHLC fetches, ~2-3 min) so give it room.
#
# EASIEST: run  bash scripts/install_mayura_cron.sh  (writes the schedule, no nano).
# The 5 EOD faces run JUST AFTER THE OPEN (~9:20–9:45 IST): they decide on the
# last settled close (yesterday) and buy at today's open — the professional
# "signal on close, execute next open" model. Swaminatha (news) is intraday.
# Times are UTC; IST = UTC + 5:30. Thanikesa/Solaimalai are heavy (live OHLC).
set -euo pipefail

# Repo root (this script lives in scripts/).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# 1) Python venv (created during your first setup; see RESTART.md).
if [ -f "$REPO/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO/.venv/bin/activate"
fi

# 2) Secrets, loaded at runtime (NEVER copied into this repo). ORDER MATTERS:
#    load the SHARED bot .env FIRST (KITE_API_KEY/SECRET, GEMINI_API_KEY …), then
#    Mayura's OWN .env LAST so Mayura's TELEGRAM_BOT_TOKEN / CHAT_ID / TOPIC_* win.
#    (If loaded the other way round, the main bot's Telegram clobbers Mayura's and
#    alerts go to the WRONG group — do not change this order.)
SHARED_ENV="${MAYURA_SHARED_ENV:-/home/globalbot/.env}"
if [ -f "$SHARED_ENV" ]; then
  set -a; # shellcheck disable=SC1091
  . "$SHARED_ENV"; set +a
fi
if [ -f "$REPO/.env" ]; then
  set -a; # shellcheck disable=SC1091
  . "$REPO/.env"; set +a
fi

# 3) Daily Kite access token your main bot refreshes via TOTP.
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

# 4) Run Mayura (paper session/report + Telegram). Python resolves to the venv's.
#    Args are flexible so cron can stagger BOTH the daily run AND the EOD report:
#      $SH dandapani          -> "run dandapani"  (back-compat: bare face = run)
#      $SH run dandapani      -> "run dandapani"
#      $SH report dandapani   -> "report dandapani"  (EOD P&L to its topic)
#      $SH report             -> EOD report for ALL faces
#    No args = run all faces, sequentially.
ARG1="${1:-}"
ARG2="${2:-}"
case "$ARG1" in
  run|report|rank|status|scorecard|data|rules|universe|filings|health|check|regime|telegram-setup|heal|lessons|weather)
    CMD="$ARG1"; FACE="$ARG2" ;;          # explicit command (+ optional face)
  "")
    CMD="run"; FACE="" ;;                  # no args -> run all faces
  *)
    CMD="run"; FACE="$ARG1" ;;             # bare face -> run that face
esac
echo "===== Mayura cron ${CMD} ${FACE:-(all)}: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="
python mayura.py "$CMD" ${FACE}
