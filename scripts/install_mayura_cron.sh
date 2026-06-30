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

# Times are UTC (IST = UTC + 5:30). The 5 EOD faces run JUST AFTER THE OPEN: they
# decide on the last settled close (yesterday) and buy at today's open — the
# professional "signal on close, execute next open" model (no look-ahead bias).
# Swaminatha (news) is intraday + a Sunday preview. The EOD report (read-only
# P&L per face → each topic) fires once after the 15:30 IST close (10:10 UTC).
NEW="$(cat <<CRON
50 3 * * 1-5 $SH dandapani  >> $LOG 2>&1
55 3 * * 1-5 $SH senthil    >> $LOG 2>&1
0 4 * * 1-5 $SH subramanya >> $LOG 2>&1
5 4 * * 1-5 $SH thanikesa  >> $LOG 2>&1
15 4 * * 1-5 $SH solaimalai >> $LOG 2>&1
25 4 * * 1-5 $SH livermore  >> $LOG 2>&1
*/30 4-10 * * 1-5 $SH swaminatha >> $LOG 2>&1
0 5 * * 0 $SH swaminatha >> $LOG 2>&1
10 10 * * 1-5 $SH report >> $LOG 2>&1
CRON
)"

# Keep every existing cron line EXCEPT old Mayura ones, then append the new set.
{ crontab -l 2>/dev/null | grep -v 'mayura_cron.sh' || true; echo "$NEW"; } | crontab -

echo "✅ Mayura cron installed (no nano used). Mayura's scheduled faces:"
crontab -l | grep 'mayura_cron.sh'
echo
echo "🦚 5 faces decide on settled close + buy at the open (9:20–9:45 IST); Swaminatha polls news every 30 min, Mon–Fri; EOD report + P&L per face at 15:40 IST."
