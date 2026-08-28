#!/usr/bin/env bash
#
# Strategy LAB deep-history run — fetch ~5 years of daily bars for the top-1500
# universe into strength_history.csv (a SEPARATE file the morning cron never
# overwrites), then run the walk-forward LAB on it.
#
# Why a separate file: the live books only need ~400 days, and run_garuda.sh
# re-fetches their CSVs fresh each morning at that depth. The LAB needs years —
# most candidates warm up a 200-day average before their first trade, so on a
# 400-day file the in-sample bucket ends up empty and every verdict is THIN.
#
#   bash scripts/run_lab.sh          # 2000 calendar days (~5.5 years, Kite's max per call)
#   bash scripts/run_lab.sh 1200     # or a custom depth
#
# Re-run whenever you want a fresh verdict (weekly is plenty — daily bars only
# add one row per stock per day). Results land in data/garuda_lab_results.json
# and the dashboard's LAB tab picks them up on the next refresh.
set -uo pipefail
cd "$(dirname "$0")/.."

set -a; . /home/globalbot/.env 2>/dev/null || true; set +a
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"
DAYS="${1:-2000}"

[ -f strength_list.csv ] || { echo "missing strength_list.csv — run scripts/build_strength_universe.sh first"; exit 1; }

echo "1/2  fetching ${DAYS}d of daily bars for the top-1500 universe (one-off, ~a few minutes) ..."
python3 -m garuda.fetch_daily --symbols-file strength_list.csv \
    --out strength_history.csv --days "$DAYS" --fresh --workers 5

echo "2/2  running the walk-forward LAB ..."
python3 -m garuda.lab --csv strength_history.csv
