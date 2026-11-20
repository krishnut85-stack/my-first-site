#!/usr/bin/env python3
"""pageprobe.py - read-only: ONE local SSE connection to gir-preview (127.0.0.1:8100) filtered to news.*, ext.*, newsmap.*.
Records, for every item that appears in news.filings / news.list / news.map / news.top / ext.recent, the server time of the
first delta that carried it (= when an open page received it). Writes probe/page_seen.jsonl. Stops itself at 16:30 IST."""
import json, time, urllib.request, datetime as dt, os, sys
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "page_seen.jsonl")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
FACTS = ("news.filings", "news.list", "news.map", "news.top", "ext.recent")
STOP = "16:30"

def key(fk, r):
    if fk == "news.filings":
        return "%s|%s|%s|%s" % (r.get("exch"), r.get("s"), r.get("exch_time"), (r.get("subject") or "")[:60])
    if fk in ("news.list", "news.top"):
        return "%s|%s|%s" % (r.get("t"), r.get("s"), (r.get("h") or "")[:80])
    if fk == "news.map":
        return "%s|%s" % (r.get("t"), (r.get("event") or "")[:80])
    return r.get("id") or "%s|%s|%s" % (r.get("source"), r.get("src_time"), (r.get("title") or "")[:80])

def slim(fk, r):
    keep = ("t", "exch", "s", "subject", "exch_time", "lag_s", "h", "src", "link", "hm", "event", "first_seen", "src_time", "source", "title", "id", "url", "kind", "tier_name")
    return {k: (str(r[k])[:200] if isinstance(r[k], str) else r[k]) for k in keep if k in r}

def run():
    seen = {}
    primed = set()
    url = "http://127.0.0.1:8100/preview/api/stream?only=news.,ext.,newsmap."
    r = urllib.request.urlopen(url, timeout=60)
    ev, data = None, []
    f = open(OUT, "a")
    for raw in r:
        if dt.datetime.now(IST).strftime("%H:%M") >= STOP:
            return True
        line = raw.decode("utf-8", "replace").rstrip("\n")
        if line.startswith("event:"):
            ev = line[6:].strip(); continue
        if line.startswith("data:"):
            data.append(line[5:].strip()); continue
        if line == "" and data:
            try:
                d = json.loads("".join(data))
            except Exception:
                d = {}
            data = []
            facts = d.get("store") if ev == "snap" else d.get("set") if ev == "delta" else None
            if not facts:
                continue
            ts, rt = d.get("ts"), time.time()
            for fk in FACTS:
                fv = facts.get(fk)
                if not fv or not isinstance(fv.get("v"), list):
                    continue
                s = seen.setdefault(fk, set())
                first = fk not in primed
                for it in fv["v"]:
                    if not isinstance(it, dict):
                        continue
                    k = key(fk, it)
                    if k in s:
                        continue
                    s.add(k)
                    f.write(json.dumps({"fact": fk, "key": k, "page_ts": ts, "recv": round(rt, 3), "pre": first or ev == "snap",
                                        "item": slim(fk, it)}, ensure_ascii=False) + "\n")
                primed.add(fk)
            f.flush()
    return False

while True:
    try:
        if run():
            break
    except Exception as ex:
        sys.stderr.write("%s probe error %s\n" % (time.strftime("%H:%M:%S"), ex)); sys.stderr.flush()
    if dt.datetime.now(IST).strftime("%H:%M") >= STOP:
        break
    time.sleep(5)
