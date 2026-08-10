#!/usr/bin/env bash
#
# Write mayura_status.json (all six faces: paper P&L + each holding's
# trailing-stop state) and push it to GitHub, so a remote session — Claude on
# the web, or you on your phone — can read Mayura's live performance without
# SSH. Paper numbers only; no token or key ever goes in the file.
#
# Installed by install_mayura_cron.sh to run once each trading day after the
# EOD report. Safe to run by hand any time:  bash scripts/push_mayura_status.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# venv + secrets, same load order as mayura_cron.sh (shared first, own last).
if [ -f "$REPO/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO/.venv/bin/activate"
fi
SHARED_ENV="${MAYURA_SHARED_ENV:-/home/globalbot/.env}"
if [ -f "$SHARED_ENV" ]; then
  set -a; # shellcheck disable=SC1091
  . "$SHARED_ENV"; set +a
fi
if [ -f "$REPO/.env" ]; then
  set -a; # shellcheck disable=SC1091
  . "$REPO/.env"; set +a
fi
export KITE_TOKEN_FILE="${KITE_TOKEN_FILE:-/home/globalbot/data/kite_token.json}"

echo "===== Mayura status push: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="
python mayura.py statusfile

git add mayura_status.json
if git diff --cached --quiet; then
  echo "status unchanged — nothing to push"
  exit 0
fi
git commit -m "Mayura status: $(date -u '+%Y-%m-%d %H:%M UTC')"
# Don't fight other pushes (auto-snapshots): rebase on top, then push (1 retry).
git pull --rebase --autostash || true
git push || { sleep 5; git push; }
