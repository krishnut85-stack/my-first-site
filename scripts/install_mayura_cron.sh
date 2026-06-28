#!/usr/bin/env bash
#
# Install Mayura's staggered daily cron WITHOUT opening nano (or any editor).
# Just run:   bash /root/sectorbot/scripts/install_mayura_cron.sh
#
# Idempotent: it removes any previous Mayura cron lines first, then adds the five
# faces at staggered times (so they never hit Kite together). Re-run any time to
# refresh — it never duplicates lines. To change times, edit the minutes below
# and re-run this script (still no nano needed).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SH="$REPO/scripts/mayura_cron.sh"
LOG="$REPO/mayura_cron.log"
chmod +x "$SH"

# Mon–Fri, after the 15:30 IST close. Times are UTC (IST = UTC + 5:30).
NEW="$(cat <<CRON
20 10 * * 1-5 $SH dandapani  >> $LOG 2>&1
30 10 * * 1-5 $SH senthil    >> $LOG 2>&1
40 10 * * 1-5 $SH subramanya >> $LOG 2>&1
50 10 * * 1-5 $SH thanikesa  >> $LOG 2>&1
10 11 * * 1-5 $SH solaimalai >> $LOG 2>&1
CRON
)"

# Keep every existing cron line EXCEPT old Mayura ones, then append the new set.
{ crontab -l 2>/dev/null | grep -v 'mayura_cron.sh' || true; echo "$NEW"; } | crontab -

echo "✅ Mayura cron installed (no nano used). Mayura's scheduled faces:"
crontab -l | grep 'mayura_cron.sh'
echo
echo "🦚 Each face runs at its own time, 15:50–16:40 IST, Mon–Fri."
