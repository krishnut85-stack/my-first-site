#!/usr/bin/env bash
#
# Run SectorBot's paper portfolio on the droplet using REAL Kite prices.
#
# It reuses the Kite credentials your main bot already manages:
#   • API key   from /home/globalbot/.env
#   • access token from the kite_token.json your main bot refreshes daily (TOTP)
# so there is NO second login and NO Kite/TOTP secret in this repo.
#
# Set it up once, then add to cron (see sectorbot/README.md).
set -euo pipefail

# Go to the repo root (this script lives in scripts/).
cd "$(dirname "$0")/.."

# --- Kite credentials (adjust paths if yours differ) -----------------------
# Load the main bot's environment (provides KITE_API_KEY etc.). This file stays
# ONLY on the droplet and must never be committed anywhere.
if [ -f /home/globalbot/.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /home/globalbot/.env
  set +a
fi

# Where the main bot writes the daily access token (JSON, refreshed via TOTP).
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

# --- Email (optional): set these in the droplet environment, not in the repo -
# export SMTP_HOST=smtp.gmail.com SMTP_PORT=465
# export SMTP_USER=krishnut85@gmail.com SMTP_PASSWORD=app_password
# export EMAIL_TO=krishnut85@gmail.com

# --- Run -------------------------------------------------------------------
# (Optional) refresh CSVs from git first, if you push them from elsewhere:
# git pull --rebase --autostash || true

python3 -m sectorbot trade
