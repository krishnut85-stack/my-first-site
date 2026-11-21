"""PROOF overlay ($0): the stub rehearsal's calls (FULL3 per-seat costs, rules 2220, the NEW split) re-run through the REAL gate in time
order, with the TV reader R3 replaced by its NEW cadence on Friday's real TV tape (2 complete minutes a call outside 09:15-15:30, 4 inside,
1,600 chars a minute). R3 cost per call from its real token counts (Haiku prices fitted on 1,005 recorded calls: in $0.10 / out $0.50 /
cache read $0.01 / cache write $0.125 per M tokens; FULL3: ~193 output tokens per item, 15,505-token cached prefix). Temp folders only."""
import os, sys, tempfile, sqlite3, json, random
os.environ["GIR_DESK_DATA"] = tempfile.mkdtemp(prefix="proofov_")
sys.path.insert(0, "/home/globalbot/intraday/v2")
import analyst.common  # noqa
from analyst import seats as S, gate as GT, board as BD, config as K
from analyst.common import ep, hm
RUN = sys.argv[1]
t0, t1 = ep("2026-11-19", "15:40"), ep("2026-11-20", "15:40")
# 1. R3 at the new cadence on the real tape
src = sqlite3.connect("file:/home/globalbot/intraday/data/tv.db?mode=ro", uri=True)
rows = src.execute("select ts,ch,text,secs,took,level from tv where ts between ? and ?", (t0 - 600, t1 + 600)).fetchall()
db = os.path.join(tempfile.mkdtemp(), "tv.db"); c = sqlite3.connect(db)
c.execute("CREATE TABLE tv(ts real, ch text, text text, secs real, took real, level real)"); c.executemany("insert into tv values (?,?,?,?,?,?)", rows); c.commit()
S.TV_DB = db
S.status_of = lambda sid, prompts=None: ("on", "proof")
class D:
    run_reader = S.Desk.run_reader; READ_KINDS = S.Desk.READ_KINDS
    def __init__(s): s.read, s.last_run, s.fails, s.b = set(), {}, {}, []
    def _read_batch(s, sid, seat, batch, snap, now, retry_of=None):
        for k in batch: s.read.add(sid + k["id"])
        s.b.append((now, batch)); return {"ran": True}
d = D(); now = t0; random.seed(3)
while now < t1:
    d.run_reader("R3", {}, now, {"id": "x", "knowledge": []}); now += 8 * random.uniform(0.8, 1.2)
r3, last = [], None
for t, b in d.b:
    chars = sum(len(k["h"]) for k in b)
    tin, tout = 700 + chars / 3.6 + 40 * len(b), 193 * len(b)
    warm = last is not None and t - last <= 300
    usd = tin * 0.10e-6 + tout * 0.50e-6 + (15505 * 0.01e-6 if warm else 15505 * 0.125e-6)
    r3.append((t, "R3", "READ", "reader", round(usd, 6), round(usd * 1.3, 6)))
    last = t
# 2. the rehearsal's other calls
rb = sqlite3.connect("file:/home/globalbot/girdata/review/monday/DESK_rehearsal/%s/2026-11-20/deskboard.db?mode=ro" % RUN, uri=True)
other = [(ts, seat, bucket, kind, float(usd or 0) or float(est or 0), float(est or 0)) for ts, seat, bucket, kind, usd, est in
         rb.execute("select ts, seat, bucket, kind, usd, est_usd from ai_calls where ts between ? and ? and seat != 'R3'", (t0, t1))]
# a refused call in the rehearsal has usd 0: charge it its estimate if it now passes
calls = sorted(other + r3, key=lambda x: x[0])
b = BD.Board(os.path.join(tempfile.mkdtemp(), "b.db")); g = GT.Gate(b, mode="replay")
first, spent, refused, r3m = {}, {}, {}, {"calls": 0, "refused": 0, "refused_0700_0915": 0, "usd": 0.0}
briefs = {}
for t, seat, bucket, kind, usd, est in calls:
    ok, why = g.check(seat, bucket, est or usd, t, event=(bucket == "SHOCK"))
    if seat == "R3":
        r3m["calls"] += 1
    if ok:
        g.record(t, seat, bucket, kind, "SIM", usd, est, True, "ok")
        spent[bucket] = spent.get(bucket, 0) + usd
        if seat == "R3": r3m["usd"] += usd
        if seat == "H" and bucket == "MEET": briefs[hm(t)] = "delivered"
    else:
        refused[bucket] = refused.get(bucket, 0) + 1
        first.setdefault(bucket, (hm(t), why[:120]))
        if seat == "R3":
            r3m["refused"] += 1
            if "07:00" <= hm(t) < "09:15" and t > ep("2026-11-20", "06:00"): r3m["refused_0700_0915"] += 1
        if seat == "H" and bucket == "MEET": briefs.setdefault(hm(t), "REFUSED: " + why[:80])
print("PROOF overlay on %s (budget day 19 Nov 15:40 -> 20 Nov 15:40, NEW split %s)" % (RUN, json.dumps(K.BUCKETS)))
print("total $%.2f" % sum(spent.values()), "| by bucket", {k: round(v, 2) for k, v in sorted(spent.items())})
print("refused calls by bucket", refused)
for k, v in sorted(first.items()): print("first refusal %s at %s: %s" % (k, v[0], v[1]))
print("R3 (new cadence, real tape): %d calls, %d refused, %d refused 07:00-09:15, $%.3f; calls 07:00-09:15: %d, 09:15-15:30: %d" % (
    r3m["calls"], r3m["refused"], r3m["refused_0700_0915"], r3m["usd"],
    sum(1 for t, *_ in r3 if ep("2026-11-20", "07:00") <= t < ep("2026-11-20", "09:15")), sum(1 for t, *_ in r3 if ep("2026-11-20", "09:15") <= t < ep("2026-11-20", "15:30"))))
print("head brief calls (MEET):", json.dumps(briefs))
