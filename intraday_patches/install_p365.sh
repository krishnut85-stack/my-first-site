#!/bin/bash
# PATCH 365 - KEEP EACH MORNING'S PRE-OPEN (Rama, 17 Nov, on the pre-open board: "ALKEM - why the strongest buy, 7.2 times?" "360ONE the strongest
#   sell"). Whether the pre-open's buy-vs-sell order ratio says anything about the share after 09:15 has never been tested - and cannot be:
#   GIR writes data/preopen.json afresh every morning and keeps no past day. From now on the final reading of each morning is kept:
#   · gir-prerec.timer, Monday-Friday 09:09 IST: data/preopen.json -> data/preopen_hist/<day>.json (a few KB a day)
#   After about 20 mornings the ratio can be tested against what each share did from the open.
#   Copies one file. Touches no page and no running service. Safe at any hour.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system
[ -f $D/data/preopen.json ] || { echo "data/preopen.json not found - nothing done"; exit 1; }
if [ -f $U/gir-prerec.timer ]; then echo "patch 365 - already in"; else
cat > $U/gir-prerec.service <<'UNIT'
[Unit]
Description=GIR pre-open recorder - keeps each morning's final pre-open reading (patch 365)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot/intraday && mkdir -p data/preopen_hist && cp data/preopen.json "data/preopen_hist/$(TZ=Asia/Kolkata date +%%F).json"'
UNIT
cat > $U/gir-prerec.timer <<'UNIT'
[Unit]
Description=GIR pre-open recorder, 09:09 IST Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 09:09:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-prerec.timer >/dev/null 2>&1 && systemctl start gir-prerec.timer
fi
echo "  the timer: $(systemctl is-active gir-prerec.timer)"
# today's reading is kept now if the file is from this morning's pre-open (written between 09:00 and 09:15 IST today)
python3 - $D <<'PY'
import os, sys, json, shutil, datetime as dt
D = sys.argv[1]; f = os.path.join(D, "data", "preopen.json"); IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
m = dt.datetime.fromtimestamp(os.path.getmtime(f), IST); now = dt.datetime.now(IST)
if m.date() == now.date() and "09:00" <= m.strftime("%H:%M") <= "09:20" and now.strftime("%H:%M") >= "09:08":
    os.makedirs(os.path.join(D, "data", "preopen_hist"), exist_ok=True); shutil.copy(f, os.path.join(D, "data", "preopen_hist", "%s.json" % now.date())); print("  today's pre-open (written %s) kept" % m.strftime("%H:%M:%S"))
else:
    print("  today's file was written %s - not a finished pre-open of today, not kept now" % m.strftime("%d %b %H:%M"))
try:                                                       # what the file holds, so the test can be written against it
    j = json.load(open(f)); print("  preopen.json: %s" % (", ".join("%s (%s%s)" % (k, type(v).__name__, " %d" % len(v) if hasattr(v, "__len__") else "") for k, v in list(j.items())[:12]) if isinstance(j, dict) else type(j).__name__))
    rows = next((v for v in (j.values() if isinstance(j, dict) else [j]) if isinstance(v, list) and v and isinstance(v[0], dict)), None)
    if rows is None and isinstance(j, dict):
        d_ = next((v for v in j.values() if isinstance(v, dict) and v and isinstance(next(iter(v.values())), (dict, list))), None)
        rows = [dict(sym=k, v=v) for k, v in list(d_.items())[:1]] if d_ else None
    if rows: print("  one row: %s" % json.dumps(rows[0], ensure_ascii=False)[:300])
except Exception as ex:
    print("  (could not read the file's layout: %s)" % str(ex)[:80])
PY
n=$(ls $D/data/preopen_hist 2>/dev/null | wc -l)
echo "✅ patch 365 done - $n morning(s) kept so far. Each market morning at 09:09 one more is added."
echo "   undo: systemctl disable --now gir-prerec.timer; rm -f $U/gir-prerec.*; systemctl daemon-reload"
