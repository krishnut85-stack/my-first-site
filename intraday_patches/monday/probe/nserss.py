#!/usr/bin/env python3
"""nserss.py - I1 test of a second NSE path: nsearchives.nseindia.com/content/RSS/Online_announcements.xml (static file with ETag /
Last-Modified; conditional GET every 10 s = mostly 304). Notes the first time each item appears + the file's Last-Modified.
Writes probe/nserss.jsonl. 09:00-15:35 only."""
import re, time, json, os, html, datetime as dt, urllib.request, urllib.error
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nserss.jsonl")
U = "https://nsearchives.nseindia.com/content/RSS/Online_announcements.xml"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
seen, et, first = set(), None, True
f = open(OUT, "a")
while True:
    hm = dt.datetime.now(IST).strftime("%H:%M")
    if hm >= "15:35":
        break
    if hm < "09:00":
        time.sleep(30); continue
    t0 = time.time()
    try:
        h = {"User-Agent": UA, "Accept": "application/xml,text/xml,*/*"}
        if et:
            h["If-None-Match"] = et
        r = urllib.request.urlopen(urllib.request.Request(U, headers=h), timeout=10)
        et, lm = r.headers.get("ETag"), r.headers.get("Last-Modified")
        x = r.read().decode("utf-8", "replace")
        now = time.time()
        n = 0
        for it in re.findall(r"<item>(.*?)</item>", x, re.S):
            ti = html.unescape((re.search(r"<title>(.*?)</title>", it, re.S) or [None, ""])[1] if re.search(r"<title>", it) else "")
            pd = (re.search(r"<pubDate>(.*?)</pubDate>", it) or [None, ""])[1] if re.search(r"<pubDate>", it) else ""
            de = html.unescape((re.search(r"<description>(.*?)</description>", it, re.S) or [None, ""])[1] if re.search(r"<description>", it) else "")
            k = "%s|%s|%s" % (ti, pd, de[:80])
            if k in seen:
                continue
            seen.add(k); n += 1
            try:
                tp = dt.datetime.strptime(pd.strip(), "%d-%b-%Y %H:%M:%S").replace(tzinfo=IST).timestamp()
            except Exception:
                tp = None
            f.write(json.dumps({"name": ti[:120], "t_pub": tp, "first": round(now, 2), "lm": lm, "pre": first, "desc": de[:160]}, ensure_ascii=False) + "\n")
        first = False
        f.flush()
    except urllib.error.HTTPError as e:
        if e.code != 304:
            f.write(json.dumps({"err": e.code, "t": time.time()}) + "\n"); f.flush(); time.sleep(60)
    except Exception as e:
        f.write(json.dumps({"err": str(e)[:80], "t": time.time()}) + "\n"); f.flush(); time.sleep(30)
    time.sleep(max(1, 10 - (time.time() - t0)))
