#!/bin/bash
# patch 161c is now inside install_p162.sh - run that instead (this file stays so the old command does no harm)
echo "161c is included in install_p162.sh - run:"
echo "cd /root/sectorbot && git fetch origin ccr-67e340f1-sko8xd && git show origin/ccr-67e340f1-sko8xd:intraday_patches/install_p162.sh > /tmp/p162.sh && bash /tmp/p162.sh"
