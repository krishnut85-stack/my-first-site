#!/usr/bin/env python3
"""sitemapwatch.py - I3 cross-check: the publishers' own news sitemaps (Google-News sitemaps: the article's publication time as the
publisher states it). ET (ETag) / CNBC-TV18 / Business Standard (ETag) every 10 min, Moneycontrol (800 KB) every 30 min. Keeps
url -> publication time + when this probe first saw it in the sitemap. Writes probe/sitemap.jsonl. Stops 16:30 IST."""
import re, time, json, os, datetime as dt, urllib.request
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sitemap.jsonl")
S = [("ET", "https://economictimes.indiatimes.com/etstatic/sitemaps/et/news/sitemap-today.xml", 600),
     ("CNBC-TV18", "https://www.cnbctv18.com/commonfeeds/v1/cne/sitemap/google-news.xml", 600),
     ("Business Standard", "https://www.business-standard.com/sitemap/news-sitemap.xml", 600),
     ("Moneycontrol", "https://www.moneycontrol.com/news/news-sitemap.xml", 1800)]
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
seen, nxt, cond = set(), {n: 0 for n, _, _ in S}, {}
f = open(OUT, "a")
while dt.datetime.now(IST).strftime("%H:%M") < "16:30":
    for n, u, iv in S:
        if time.time() < nxt[n]:
            continue
        nxt[n] = time.time() + iv
        try:
            h = {"User-Agent": UA}
            if cond.get(n):
                h["If-None-Match"] = cond[n]
            r = urllib.request.urlopen(urllib.request.Request(u, headers=h), timeout=20)
            cond[n] = r.headers.get("ETag")
            x = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code != 304:
                f.write(json.dumps({"pub": n, "err": e.code, "t": time.time()}) + "\n")
            continue
        except Exception as e:
            f.write(json.dumps({"pub": n, "err": str(e)[:80], "t": time.time()}) + "\n"); continue
        now = time.time()
        for blk in re.findall(r"<url>(.*?)</url>", x, re.S):
            loc = re.search(r"<loc>\s*([^<\s]+)", blk)
            pd = re.search(r"<news:publication_date>([^<]+)<", blk) or re.search(r"<lastmod>([^<]+)<", blk)
            ti = re.search(r"<news:title>(?:<!\[CDATA\[)?([^<\]]+)", blk)
            if not loc or not pd or loc.group(1) in seen:
                continue
            seen.add(loc.group(1))
            try:
                tp = dt.datetime.fromisoformat(pd.group(1).strip().replace("Z", "+00:00")).timestamp()
            except Exception:
                tp = None
            f.write(json.dumps({"pub": n, "url": loc.group(1), "t_pub": tp, "title": (ti.group(1) if ti else "")[:160], "first": round(now, 1)}, ensure_ascii=False) + "\n")
        f.flush()
        time.sleep(2)
    time.sleep(20)
