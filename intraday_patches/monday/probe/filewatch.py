#!/usr/bin/env python3
"""filewatch.py - read-only: every 10 s reads the OLD engine's small state files and notes the first time each new item id appears
(macro.json items = the wires' market headlines; regwatch.json / govwatch.json seen ids = regulator / PIB items). These files keep
no seen time per item, so this is the only way to know when GIR first had them. Writes probe/file_seen.jsonl. Stops at 16:30 IST."""
import json, time, os, datetime as dt
D = "/home/globalbot/intraday/data"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "file_seen.jsonl")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
known = {}
mt = {}
f = open(OUT, "a")
while dt.datetime.now(IST).strftime("%H:%M") < "16:30":
    for name in ("macro.json", "regwatch.json", "govwatch.json", "worldnews.json"):
        p = os.path.join(D, name)
        try:
            m = os.stat(p).st_mtime
            if mt.get(name) == m:
                continue
            mt[name] = m
            j = json.load(open(p))
        except Exception:
            continue
        first = name not in known
        s = known.setdefault(name, set())
        rows = []
        if name in ("macro.json", "worldnews.json"):
            for it in j.get("items") or []:
                k = it.get("k") or it.get("link") or it.get("h")
                if k and k not in s:
                    s.add(k); rows.append({"id": k, "t_item": it.get("t"), "h": (it.get("h") or "")[:200], "src": it.get("src"), "link": it.get("link")})
        else:
            for k in j.get("seen") or []:
                if k not in s:
                    s.add(k); rows.append({"id": k})
        now = time.time()
        for r in rows:
            r.update({"file": name, "seen": round(now, 2), "file_mtime": round(m, 2), "pre": first})
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
        f.flush()
    time.sleep(10)
