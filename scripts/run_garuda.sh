#!/usr/bin/env bash
#
# Garuda daily refresh — FULLY AUTOMATIC. Run once each trading morning before
# the 09:15 IST open. It:
#   0. auto-logs in to Kite and writes a fresh access_token (no manual login)
#   1. refreshes the full Nifty Smallcap 250 + Microcap 250 constituent lists
#   2. fetches fresh daily bars for ALL ~500 names
#   3. restarts the dashboard server
# The server then auto-runs the scan the moment the market opens (09:15 IST) and
# books entries/exits live — so nothing is traded on a closed market.
#
# Install both cron jobs once (droplet clock is UTC; 08:45 IST = 03:15 UTC):
#   crontab -e
#   15 3 * * 1-5 /home/globalbot/my-first-site/scripts/run_garuda.sh      >> /home/globalbot/garuda_cron.log 2>&1
#   */5 * * * *  /home/globalbot/my-first-site/scripts/garuda_watchdog.sh >> /home/globalbot/garuda_watch.log 2>&1
set -uo pipefail
cd /home/globalbot/my-first-site

set -a; . /home/globalbot/.env; set +a
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"
TOKEN="${GARUDA_TOKEN:-garudaLIVE2026}"
UA="Mozilla/5.0"

echo "=== Garuda refresh $(date -u) ==="

# 0. Kite token: the existing system refreshes it each morning, so just READ it.
#    Only fall back to a fresh auto-login if today's token isn't there yet.
TODAY_IST="$(TZ=Asia/Kolkata date +%F)"
if [ -f "$KITE_TOKEN_FILE" ] && grep -q "\"$TODAY_IST\"" "$KITE_TOKEN_FILE"; then
  echo "[ok] using today's Kite token from $KITE_TOKEN_FILE"
else
  echo "[info] today's token not found — running fallback auto-login"
  python3 -m garuda.kite_login || echo "[warn] fallback login failed — will try the existing token"
fi

# 1. refresh the constituent lists (best-effort; keep the old file on failure)
curl -s -A "$UA" "https://archives.nseindia.com/content/indices/ind_niftysmallcap250list.csv" -o smallcap_list.new && \
  grep -qi symbol smallcap_list.new && mv smallcap_list.new smallcap_list.csv || rm -f smallcap_list.new
curl -s -A "$UA" "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv" -o micro.new && \
  grep -qi symbol micro.new && mv micro.new micro.csv || rm -f micro.new
curl -s -A "$UA" "https://archives.nseindia.com/content/indices/ind_niftynext50list.csv" -o next50.new && \
  grep -qi symbol next50.new && mv next50.new next50_list.csv || rm -f next50.new

# 2. fetch fresh daily bars for the FULL universe (smallcap 250 + microcap 250 + next 50)
[ -f smallcap_list.csv ] && python3 -m garuda.fetch_daily --symbols-file smallcap_list.csv --out niftysmallcap250_daily.csv --fresh
[ -f micro.csv ]         && python3 -m garuda.fetch_daily --symbols-file micro.csv         --out microcap_daily.csv       --fresh
[ -f next50_list.csv ]   && python3 -m garuda.fetch_daily --symbols-file next50_list.csv   --out next50_daily.csv         --fresh

# 2b. market caps from Yahoo (best-effort; the dashboard shows what it gets)
python3 -m garuda.fetch_marketcap --symbols-file smallcap_list.csv micro.csv next50_list.csv --out marketcap.csv || \
  echo "[warn] market cap fetch failed — MCAP column will show —"

# 3. restart the server (it auto-scans + trades live at 09:15 IST on its own)
pkill -f "garuda.server" 2>/dev/null || true
sleep 2
nohup python3 -m garuda.server --token "$TOKEN" --csv-dir /home/globalbot/my-first-site > garuda_server.log 2>&1 &
sleep 3
echo "Garuda restarted. Dashboard: http://64.227.155.177:8501/?token=$TOKEN"
tail -6 garuda_server.log
