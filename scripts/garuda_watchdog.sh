#!/usr/bin/env bash
#
# Garuda watchdog — keeps the dashboard alive with zero babysitting. Runs every
# 5 minutes from cron; if the server isn't answering /health, it restarts it
# (without re-fetching data). The paper book persists on disk, so positions and
# the equity curve carry across restarts.
#
#   */5 * * * * /home/globalbot/my-first-site/scripts/garuda_watchdog.sh >> /home/globalbot/garuda_watch.log 2>&1
set -uo pipefail
cd /home/globalbot/my-first-site

set -a; . /home/globalbot/.env; set +a
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"
TOKEN="${GARUDA_TOKEN:-garudaLIVE2026}"

if curl -sf "http://127.0.0.1:8501/health" >/dev/null 2>&1; then
  exit 0                                   # healthy — nothing to do
fi

echo "=== $(date -u) server down — restarting ==="
pkill -f "garuda.server" 2>/dev/null || true
sleep 2
nohup python3 -m garuda.server --token "$TOKEN" --csv-dir /home/globalbot/my-first-site > garuda_server.log 2>&1 &
sleep 3
tail -4 garuda_server.log
