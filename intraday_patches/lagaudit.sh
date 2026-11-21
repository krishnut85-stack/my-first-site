#!/bin/bash
# lagaudit.sh - READ ONLY. HOW LATE ARE GIR'S ALERTS? (Rama, 13 Nov: "most of the alerts are coming late").
#   For every alert of the day: the time written in the alert (when GIR saw the signal) vs the time Telegram accepted it (tomorrow.db alerts,
#   logged the second the message is on the phone). Shows the delay by kind and by hour, the worst 20, and Telegram's "too many requests"
#   waits in the logs. Changes nothing, sends nothing.   bash lagaudit.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$DAY" <<'PY'
import sys, re, sqlite3, collections
day = sys.argv[1]
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, kind, sym, text from alerts where day=? order by t", (day,)).fetchall()
c.close()
sec = lambda t: int(t[:2]) * 3600 + int(t[3:5]) * 60 + (int(t[6:8]) if len(t) >= 8 else 0)
L = []
for t, k, s, tx in rows:
    head = (tx or "").split("\n")[0]
    m = re.search(r"(?<![\d:])([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?![\d:])", head)
    if not m or not t:
        continue
    st = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3) or 0)
    lag = sec(str(t)) - st
    if -120 <= lag <= 3 * 3600:
        L.append((lag, str(t)[:8], k or "?", s or "", head[:110], m.group(3) is not None))
print("=== %s · %d alerts · %d carry their own signal time" % (day, len(rows), len(L)))
if not L:
    sys.exit()
def summ(v):
    v = sorted(v); n = len(v)
    return "median %3ds · 90%% under %4ds · worst %4ds · over 2 min: %d of %d" % (v[n // 2], v[min(n - 1, int(n * 0.9))], v[-1], sum(x > 120 for x in v), n)
print("   all: " + summ([x[0] for x in L]))
print("   (an alert whose time is a 5-min candle's START and that waits for the close shows ~5 min by design)")
print("=== by kind")
K = collections.defaultdict(list)
for x in L:
    K[x[2]].append(x[0])
for k, v in sorted(K.items(), key=lambda kv: -sorted(kv[1])[len(kv[1]) // 2])[:20]:
    print("   %-14s %s" % (k[:14], summ(v)))
print("=== by hour (market hours)")
H = collections.defaultdict(list)
for x in L:
    H[x[1][:2]].append(x[0])
for h in sorted(H):
    if "09" <= h <= "15":
        print("   %s:00  %s" % (h, summ(H[h])))
print("=== the 20 latest")
for lag, t, k, s, head, has_s in sorted(L, reverse=True)[:20]:
    print("   %4ds  sent %s  %-10s %s" % (lag, t, s[:10], head[:90]))
PY
echo "=== Telegram 'too many requests' (429) waits today, by service"
for s in gir-intraday gir-desk gir-newshunt gir-newsroom gir-exchange gir-eventwatch gir-tvwatch; do
  n=$(journalctl -u $s --since "$DAY 03:30" --until "$DAY 10:05" --no-pager 2>/dev/null | grep -ciE "429|too many requests|retry_after")
  echo "   $s: $n"
done
echo "=== done - nothing was changed"
