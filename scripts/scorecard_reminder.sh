#!/usr/bin/env bash
#
# One-off reminder: Telegram a nudge to check the Mayura scorecard.
# Schedule it via cron for ~3 weeks after you start (see the crontab line below).
#
#   30 10 17 7 * /root/sectorbot/scripts/scorecard_reminder.sh >> /root/sectorbot/reminder.log 2>&1
#   (17 July, 10:30 UTC = 16:00 IST). Delete that crontab line after it fires.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
if [ -f "$REPO/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO/.venv/bin/activate"
fi
if [ -f "$REPO/.env" ]; then
  set -a; . "$REPO/.env"; set +a
fi

python - <<'PY'
from sectorbot.telegram import send_telegram
send_telegram(
    "\U0001F4CA\U0001F99A <b>Mayura reminder</b>\n"
    "3 weeks of paper trading done — time to check the scorecard.\n\n"
    "Run on the droplet:\n"
    "<code>cd /root/sectorbot &amp;&amp; source .venv/bin/activate</code>\n"
    "<code>python mayura.py scorecard</code>\n"
    "<code>python mayura.py status</code>\n\n"
    "It tells you honestly: TOO EARLY / LOSING / LAGGING INDEX / PROMISING. "
    "(A full verdict needs ~30 trading days, so it may still say TOO EARLY.) "
    "Vel Muruga! \U0001F99A"
)
PY
