#!/usr/bin/env bash
#
# Garuda daily refresh — run each trading morning (after the Kite token refresh,
# before 9:15 IST open). Fetches fresh daily bars for both universes, then
# restarts the dashboard server with a new scan so the day's signals are live.
#
# Cron (droplet is UTC; 8:50 IST = 03:20 UTC), Mon-Fri:
#   crontab -e
#   20 3 * * 1-5 /home/globalbot/my-first-site/scripts/run_garuda.sh >> /home/globalbot/garuda_cron.log 2>&1
#
# Set your dashboard token once:  export GARUDA_TOKEN=yoursecret   (or edit below)
set -uo pipefail
cd /home/globalbot/my-first-site

set -a; . /home/globalbot/.env; set +a
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"
TOKEN="${GARUDA_TOKEN:-garudaLIVE2026}"
UA="Mozilla/5.0"

echo "=== Garuda refresh $(date -u) ==="

# 1. refresh the constituent lists (best-effort; keep old file if the download fails)
curl -s -A "$UA" "https://archives.nseindia.com/content/indices/ind_niftysmallcap250list.csv" -o smallcap_list.new && \
  grep -qi symbol smallcap_list.new && mv smallcap_list.new smallcap_list.csv || rm -f smallcap_list.new
curl -s -A "$UA" "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv" -o micro.new && \
  grep -qi symbol micro.new && mv micro.new micro.csv || rm -f micro.new

# 2. fetch fresh daily bars (rolling window ending today)
[ -f smallcap_list.csv ] && python3 -m garuda.fetch_daily --symbols-file smallcap_list.csv --out niftysmallcap250_daily.csv --fresh
[ -f micro.csv ]         && python3 -m garuda.fetch_daily --symbols-file micro.csv         --out microcap_daily.csv       --fresh

# 3. restart the dashboard with a fresh scan (portfolio persists on disk, so
#    positions carry over; the scan just books today's exits + new entries)
pkill -f "garuda.server" 2>/dev/null || true
sleep 2
nohup python3 -m garuda.server --token "$TOKEN" --scan > garuda_server.log 2>&1 &
sleep 3
echo "Garuda restarted. Dashboard: http://64.227.155.177:8501/?token=$TOKEN"
tail -4 garuda_server.log
