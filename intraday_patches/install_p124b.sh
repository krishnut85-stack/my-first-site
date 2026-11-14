#!/bin/bash
# PATCH 124b - GIR's two new channels get their OWN names in .env (on top of patch 124), then connects them.
#   TG_CHAT_OI was already in /home/globalbot/.env before patch 124 - another program's channel. GIR must never use it,
#   and must never overwrite it. GIR now uses TG_CHAT_GIROI and TG_CHAT_GIRMOVES; TG_CHAT_OI is left exactly as it is.
#   Then: GIR OI = @GIROIALERT, GIR Moves & News = @GIRMOVESNEWS (a test message to each; the bot must be an admin).
#   tglanes.py, tg_lane_setup.py, p124test.py. Restarts gir-intraday, gir-desk, gir-newsroom, gir-exchange.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p124b.sh now"; exit 1; fi
grep -q "def sock_check" $D/engine2.py 2>/dev/null || { echo "patch 124 is not installed yet - paste patch 124 first"; exit 1; }
grep -q "TG_CHAT_GIROI" $D/tglanes.py && { echo "patch 124b is already installed"; exit 1; }
F="tglanes.py tg_lane_setup.py p124test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-intraday gir-desk gir-newsroom gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cd $D && sed -i 's/TG_CHAT_OI\b/TG_CHAT_GIROI/g; s/TG_CHAT_MOVES\b/TG_CHAT_GIRMOVES/g' $F
grep -q "TG_CHAT_OI\b\|TG_CHAT_MOVES\b" $F && { echo "the old names are still there"; back; }
python3 -m py_compile tglanes.py tg_lane_setup.py p124test.py || back
timeout 120 python3 p124test.py >/dev/null 2>&1 && echo "    p124test.py passed" || { echo "the test failed"; back; }
systemctl restart gir-intraday gir-desk gir-newsroom gir-exchange && sleep 15
for u in gir-intraday gir-desk gir-newsroom gir-exchange; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo "PATCH 124b APPLIED - GIR uses TG_CHAT_GIROI / TG_CHAT_GIRMOVES; TG_CHAT_OI (the other program's) is untouched."
echo
echo "== GIR OI =="; python3 $D/tg_lane_setup.py oi @GIROIALERT
echo "== GIR Moves & News =="; python3 $D/tg_lane_setup.py moves @GIRMOVESNEWS
echo
python3 $D/tg_lane_setup.py status
