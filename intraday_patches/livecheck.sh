#!/bin/bash
# livecheck.sh - READ ONLY. Why did GIR say "market closed" on BDL at 14:07 and NIFTY 25,255.1 (+0.00%) at 14:15 during the market?
# Shows: did the engine / page server restart today, was anything killed for memory, are the live files fresh, what the index strip holds.
# Changes nothing. Usage: bash livecheck.sh
D=/home/globalbot/intraday
echo "=== now: $(TZ=Asia/Kolkata date '+%d %b %H:%M:%S IST')"
echo "=== services: up since · restarts"
for s in gir-intraday gir-exchange gir-dash gir-desk gir-newsroom gir-newshunt gir-tvwatch gir-watchdog; do
  printf "   %-13s %-9s since %s · restarts %s\n" $s "$(systemctl is-active $s 2>/dev/null)" \
    "$(TZ=Asia/Kolkata systemctl show $s -p ActiveEnterTimestamp --value 2>/dev/null | cut -c5-23)" "$(systemctl show $s -p NRestarts --value 2>/dev/null)"
done
echo "=== killed for memory today?"
journalctl -k --since today --no-pager 2>/dev/null | grep -iE "out of memory|oom-kill|killed process" | tail -5 | cut -c1-160
[ "${PIPESTATUS[1]}" = "1" ] && echo "   none"
echo "=== memory now"; free -m | sed 's/^/   /'
echo "   biggest:"; ps -eo rss,etime,args --sort=-rss | head -6 | awk '{printf "   %6.0f MB  up %-11s %s %s %s\n", $1/1024, $2, $3, $4, $5}'
echo "=== the engine's log 13:55-14:20 (starts, stops, feed, errors)"
journalctl -u gir-intraday --since "$(date +%F) 08:25" --until "$(date +%F) 08:50" --no-pager -o short-iso 2>/dev/null \
  | grep -iE "start|stop|feed|socket|error|fail|traceback|reconnect|killed|closed" | tail -25 | cut -c1-170
echo "=== the watchdog's log today (did it restart anything?)"
journalctl -u gir-watchdog --since today --no-pager 2>/dev/null | grep -iE "restart|down|stale|kill" | tail -8 | cut -c1-170
echo "=== the live files"
python3 - $D <<'PY'
import sys, os, json, time
D = sys.argv[1]
for f in ("dash_state.json", "quotes_live.json", "charts.json", "data/focus_chk.json"):
    p = os.path.join(D, f)
    try:
        print("   %-18s written %4.0f s ago" % (f, time.time() - os.path.getmtime(p)))
    except Exception as ex:
        print("   %-18s %s" % (f, ex))
try:
    st = json.load(open(os.path.join(D, "dash_state.json")))
    print("   engine: day %s · ts %s · feed %s · closed %s · %s t/s" % (st.get("day"), st.get("ts"), st.get("feed"), st.get("closed"), st.get("ticks_s")))
    for k, v in (st.get("idx") or {}).items():
        print("   idx %-9s %s (%s%%) prev close %s" % (k, v.get("last"), v.get("chg"), v.get("pc")))
    b = next((f for f in st.get("fo_paths") or [] if f.get("s") == "BDL"), None)
    print("   BDL in the engine: %s" % ({k: b.get(k) for k in ("chg", "bu", "oi")} if b else "not there"))
    q = json.load(open(os.path.join(D, "quotes_live.json")))
    print("   ticks: BDL %s · NIFTY %s · %d shares" % ((q.get("q") or {}).get("BDL"), (q.get("q") or {}).get("NIFTY50"), len(q.get("q") or {})))
except Exception as ex:
    print("   not read:", ex)
PY
TK=$(tr -d '[:space:]' < $D/dash_token.txt 2>/dev/null)
echo "=== what the page gets for the index strip right now"
curl -s "http://127.0.0.1:8090/home?k=$TK" | python3 -c "
import sys, json
try:
    j = json.load(sys.stdin)
except Exception as ex:
    print('   not read:', ex); sys.exit(0)
print('   t %s · closed %s' % (j.get('t'), j.get('closed')))
for k, v in (j.get('idx') or {}).items():
    print('   %-9s %s (%s%%)' % (k, v.get('last'), v.get('chg')))
"
echo "=== done - nothing was changed"
