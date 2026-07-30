#!/usr/bin/env bash
#
# Run RAMA's paper portfolio on the droplet using REAL Kite prices, then
# refresh the live Rama·Quant dashboard. Separate from run_on_droplet.sh, so
# Rama and sectorbot keep entirely independent track records.
#
# It reuses the Kite credentials your main bot already manages:
#   • API key      from /home/globalbot/.env
#   • access token from the kite_token.json your main bot refreshes daily (TOTP)
# so there is NO second login and NO Kite/TOTP secret in this repo.
#
# SEBI note: Rama must run on an INDIAN server. Keep LIVE_TRADING off (paper)
# until the scorecard proves an edge; going live also needs a Kite Connect
# subscription, your broker's Algo-ID (export RAMA_ALGO_ID=...), and static-IP
# whitelisting. `python -m rama trade` regenerates the dashboard automatically.
set -euo pipefail

# Go to the repo root (this script lives in scripts/).
cd "$(dirname "$0")/.."

# --- Kite credentials (adjust paths if yours differ) -----------------------
if [ -f /home/globalbot/.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /home/globalbot/.env
  set +a
fi
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

# --- Optional: email + Telegram alerts (set on the droplet, not in the repo)-
# export SMTP_HOST=smtp.gmail.com SMTP_PORT=465
# export SMTP_USER=krishnut85@gmail.com SMTP_PASSWORD=app_password EMAIL_TO=krishnut85@gmail.com
# export TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=...

# --- Optional: broker Algo-ID for eventual live routing (stays DRY_RUN until
#     you also flip config.LIVE_DRY_RUN off). Leave unset while paper trading. -
# export RAMA_ALGO_ID=YOUR_BROKER_ALGO_ID

# (Optional) pull fresh CSVs if you push them from elsewhere:
# git pull --rebase --autostash || true

# Runs the paper session AND refreshes rama_dashboard.html at the end.
python3 -m rama trade
