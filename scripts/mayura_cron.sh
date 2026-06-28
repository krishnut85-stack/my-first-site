#!/usr/bin/env bash
#
# Mayura 🦚 daily paper-trading run (for cron on the droplet).
#
# Loads the venv + Kite/Telegram secrets, then runs ONE Mayura paper session on
# REAL Kite prices and Telegrams you the result. PAPER ONLY — never a real order.
#
# Usage:
#   mayura_cron.sh            -> run ALL faces (one burst; simple, but heavier)
#   mayura_cron.sh <face>     -> run ONLY that face (dandapani/senthil/subramanya/
#                                thanikesa/solaimalai/swaminatha)
#
# STAGGER each face at its OWN cron time so they never hit the Kite API at the
# same moment — and don't fight your OTHER bots that share the same Kite token.
# Thanikesa is heaviest (~200 live OHLC fetches, ~2-3 min) so give it room.
#
# Install (one time, on the droplet) — times are UTC; IST = UTC + 5:30:
#   chmod +x /root/sectorbot/scripts/mayura_cron.sh
#   crontab -e     # add (Mon–Fri, after the 15:30 IST close), staggered:
#   20 10 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh dandapani  >> /root/sectorbot/mayura_cron.log 2>&1  # 15:50 IST
#   30 10 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh senthil    >> /root/sectorbot/mayura_cron.log 2>&1  # 16:00 IST
#   40 10 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh subramanya >> /root/sectorbot/mayura_cron.log 2>&1  # 16:10 IST
#   50 10 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh thanikesa  >> /root/sectorbot/mayura_cron.log 2>&1  # 16:20 IST (heavy)
#   10 11 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh solaimalai >> /root/sectorbot/mayura_cron.log 2>&1  # 16:40 IST
# Pick minutes that fall in GAPS when your other Kite bots are idle.
set -euo pipefail

# Repo root (this script lives in scripts/).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# 1) Python venv (created during your first setup; see RESTART.md).
if [ -f "$REPO/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO/.venv/bin/activate"
fi

# 2) Secrets, loaded at runtime (NEVER copied into this repo):
#    a) Mayura's OWN .env  -> Telegram token + per-topic ids
#    b) the SHARED bot .env -> API keys your main bot already holds
#       (KITE_API_KEY/SECRET, GEMINI_API_KEY, …). Mayura's own values win.
if [ -f "$REPO/.env" ]; then
  set -a; # shellcheck disable=SC1091
  . "$REPO/.env"; set +a
fi
SHARED_ENV="${MAYURA_SHARED_ENV:-/home/globalbot/.env}"
if [ -f "$SHARED_ENV" ]; then
  set -a; # shellcheck disable=SC1091
  . "$SHARED_ENV"; set +a
fi

# 3) Daily Kite access token your main bot refreshes via TOTP.
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

# 4) Run Mayura (paper session + Telegram). Python resolves to the venv's.
#    Optional $1 = a single face, so each can be cron-scheduled at its own time
#    (staggered Kite access). No arg = all faces, sequentially.
FACE="${1:-}"
echo "===== Mayura cron run ${FACE:-(all)}: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="
python mayura.py run ${FACE}
