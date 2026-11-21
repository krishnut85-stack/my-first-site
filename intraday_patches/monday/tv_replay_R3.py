"""$0 replay of Fri 20 Nov TV text through R3's code path (tv_items + run_reader batching), OLD seats.py (.bak1428) vs NEW.
No AI call (stub batch), temp copy of tv.db, temp desk folder."""
import os, sys, tempfile, sqlite3, random, importlib.util, json
os.environ["GIR_DESK_DATA"] = tempfile.mkdtemp(prefix="tvreplay_")
sys.path.insert(0, "/home/globalbot/intraday/v2")
import analyst.common  # noqa
from analyst import seats as NEW
from analyst.common import ep
from importlib.machinery import SourceFileLoader
_ld = SourceFileLoader("analyst.seats_old", "/home/globalbot/intraday/v2/analyst/seats.py.bak1428")
spec = importlib.util.spec_from_loader("analyst.seats_old", _ld)
OLD = importlib.util.module_from_spec(spec); sys.modules["analyst.seats_old"] = OLD; spec.loader.exec_module(OLD)

day, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
t0, t1 = ep(day, a), ep(day, b)
src = sqlite3.connect("file:/home/globalbot/intraday/data/tv.db?mode=ro", uri=True)
rows = src.execute("select ts,ch,text,secs,took,level from tv where ts between ? and ?", (t0 - 400, t1 + 400)).fetchall()
db = os.path.join(tempfile.mkdtemp(), "tv.db"); c = sqlite3.connect(db)
c.execute("CREATE TABLE tv(ts real, ch text, text text, secs real, took real, level real)"); c.executemany("insert into tv values (?,?,?,?,?,?)", rows); c.commit()
segs = [(ts, ch, tx.strip()) for ts, ch, tx, *_ in rows if t0 <= ts < t1 - 300 and tx and tx.strip()]
tot_chars = sum(len(x[2]) for x in segs)

def run(M, slow, step):
    M.TV_DB = db
    M.status_of = lambda sid, prompts=None: ("on", "replay")
    M.GT.slow_mode = (lambda now: True) if slow else (lambda now: False)
    class D:
        run_reader = M.Desk.run_reader; READ_KINDS = M.Desk.READ_KINDS
        def __init__(s): s.read, s.last_run, s.fails, s.b = set(), {}, {}, []
        def _read_batch(s, sid, seat, batch, snap, now, retry_of=None):
            for k in batch: s.read.add(sid + k["id"])
            s.b.append((now, [dict(k) for k in batch])); return {"ran": True}
    d = D(); now = t0; random.seed(7)
    while now < t1:
        d.run_reader("R3", {}, now, {"id": "x", "knowledge": []}); now += step * random.uniform(0.8, 1.2)
    got = {}
    for _, bt in d.b:
        for k in bt: got[k["id"]] = k["h"]
    reached = 0; rchars = 0
    for ts, ch, tx in segs:
        h = got.get("TV:%s:%d" % (ch.replace(" ", ""), int(ts // 60)), "")
        if tx[:40] in h: reached += 1; rchars += len(tx)
    return {"R3 calls (chunks)": len(d.b), "items": sum(len(x[1]) for x in d.b), "segments reaching R3": "%d of %d (%.0f%%)" % (reached, len(segs), 100 * reached / len(segs)),
            "text reaching R3": "%.0f%%" % (100 * rchars / tot_chars)}

print("Fri TV %s %s-%s: %d text segments (CNBC-TV18 + ET NOW), %d chars" % (day, a, b, len(segs), tot_chars))
for slow in (False, True):
    for name, M in (("OLD", OLD), ("NEW", NEW)):
        print(("holiday/weekend slow mode" if slow else "trading day"), name, json.dumps(run(M, slow, 8)))
