"""Garuda news ticker — market headlines + Swaminatha's filings, stdlib only.

Fetches Indian market RSS feeds (best-effort, each independently) and merges in
the filings Swaminatha actually traded on, for the dashboard's bottom ticker.
No API keys, no pip installs; failures degrade to an empty/stale ticker, never
an exception in the server loop.
"""

import time
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

FEEDS = [
    ("ET Markets", "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms"),
    ("Moneycontrol", "https://www.moneycontrol.com/rss/latestnews.xml"),
    ("Mint", "https://www.livemint.com/rss/markets"),
    ("Biz Standard", "https://www.business-standard.com/rss/markets-106.rss"),
]
UA = {"User-Agent": "Mozilla/5.0 (Garuda paper dashboard)"}
MAX_ITEMS = 30
MAX_AGE_SECS = 3 * 86400      # a LIVE ticker: drop anything older than 3 days
REFRESH_SECS = 300            # one fetch round every ~5 minutes


def _ts(text):
    """RFC-822 or ISO date string -> epoch seconds; unparsable -> 0."""
    t = (text or "").strip()
    if not t:
        return 0
    try:
        return parsedate_to_datetime(t).timestamp()
    except (TypeError, ValueError):
        pass
    try:
        from datetime import datetime
        return datetime.fromisoformat(t.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return 0


def _age(ts, now=None):
    if not ts:
        return ""
    d = max(0, (now or time.time()) - ts)
    if d < 3600:
        return f"{int(d // 60)}m"
    if d < 86400:
        return f"{int(d // 3600)}h"
    return f"{int(d // 86400)}d"


def parse_rss(xml_bytes, src, limit=12):
    """[{src, title}] from one RSS/Atom payload; bad XML -> []."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return []
    out = []
    for item in root.iter():
        if item.tag.split("}")[-1] != "item" and item.tag.split("}")[-1] != "entry":
            continue
        title, link, ts = "", "", 0
        for ch in item:
            tag = ch.tag.split("}")[-1]
            if tag == "title" and not title:
                title = (ch.text or "").strip()
            elif tag == "link" and not link:
                link = (ch.text or ch.get("href") or "").strip()
            elif tag in ("pubDate", "updated", "published") and not ts:
                ts = _ts(ch.text)
        if title:
            out.append({"src": src, "title": title[:180], "link": link[:400],
                        "ts": ts})
        if len(out) >= limit:
            break
    return out


def fetch_feeds(feeds=None, timeout=6):
    """Best-effort fetch of every feed; a dead feed just contributes nothing."""
    items = []
    for src, url in (feeds or FEEDS):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                items += parse_rss(r.read(), src)
        except Exception:  # noqa: BLE001 — the ticker must never kill the loop
            continue
    # LIVE means live: drop stale items (some feeds serve archive pages), then
    # newest first; undated items go last rather than masquerading as fresh
    now = time.time()
    items = [n for n in items if n["ts"] == 0 or now - n["ts"] <= MAX_AGE_SECS]
    items.sort(key=lambda n: -(n["ts"] or 0))
    seen, out = set(), []
    for n in items:
        k = n["title"].lower()
        if k in seen:
            continue
        seen.add(k)
        n["age"] = _age(n["ts"], now)
        out.append(n)
    return out[:MAX_ITEMS]


class NewsTicker:
    """Rate-limited cache: .items() returns the latest headlines, refreshing at
    most once per REFRESH_SECS (the network round happens inline in the caller's
    thread — the server's background refresh loop, never a request handler)."""

    def __init__(self, feeds=None):
        self.feeds = feeds or FEEDS
        self._items = []
        self._at = 0.0

    def items(self, swami_trades=None):
        now = time.time()
        if now - self._at >= REFRESH_SECS:
            self._at = now                     # even on failure, wait a full cycle
            fresh = fetch_feeds(self.feeds)
            if fresh:
                self._items = fresh
        out = list(self._items)
        # Swaminatha's filings lead the ticker — the news the fleet actually acted
        # on; clicking one searches the filing (no canonical NSE URL in the log)
        from urllib.parse import quote_plus
        for t in (swami_trades or [])[:5]:
            if t.get("side") == "BUY" and t.get("reason"):
                q = quote_plus(f"{t.get('symbol', '')} {str(t['reason'])[:80]}")
                out.insert(0, {"src": "📜 SWAMINATHA BUY " + str(t.get("symbol", "")),
                               "title": str(t["reason"])[:180],
                               "link": "https://www.google.com/search?q=" + q,
                               "ts": 0, "age": str(t.get("date", ""))})
        return out[:MAX_ITEMS]
