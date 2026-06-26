#!/usr/bin/env bash
#
# Mayura 🦚 daily paper-trading run (for cron on the droplet).
#
# Loads the venv + Kite/Telegram secrets, then runs ONE Mayura paper session on
# REAL Kite prices and Telegrams you the result. PAPER ONLY — never a real order.
#
# It trades the newest data in mayura_data/:
#   • mayura_data/universe.csv present  -> BREAKOUT WATCHLIST mode (your Trendlyne
#                                          early-breakout export)
#   • otherwise                         -> industry DVM ranking (fundamentals CSV)
#
# So for the breakout list to be used, upload a fresh mayura_data/universe.csv
# before this runs. If you don't, Mayura reuses the last universe.csv you left.
#
# Install (one time, on the droplet):
#   chmod +x /root/sectorbot/scripts/mayura_cron.sh
#   crontab -e
#   # 10:15 UTC ≈ 15:45 IST, Mon–Fri (just after market close):
#   15 10 * * 1-5 /root/sectorbot/scripts/mayura_cron.sh >> /root/sectorbot/mayura_cron.log 2>&1
set -euo pipefail

# Repo root (this script lives in scripts/).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# 1) Python venv (created during your first setup; see RESTART.md).
if [ -f "$REPO/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO/.venv/bin/activate"
fi

# 2) Secrets: Kite API key + Telegram token/chat id. Stay ONLY on the droplet.
if [ -f "$REPO/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO/.env"
  set +a
fi

# 3) Daily Kite access token your main bot refreshes via TOTP.
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

# 4) Run Mayura (paper session + Telegram). Python resolves to the venv's.
echo "===== Mayura cron run: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="
python mayura.py run
