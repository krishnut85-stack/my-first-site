"""Garuda news ticker — market headlines + Swaminatha's filings, stdlib only.

Fetches Indian market RSS feeds (best-effort, each independently) and merges in
the filings Swaminatha actually traded on, for the dashboard's bottom ticker.
No API keys, no pip installs; failures degrade to an empty/stale ticker, never
an exception in the server loop.
"""

import time
import urllib.request
import xml.etree.ElementTree as ET

FEEDS = [
    ("ET Markets", "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms"),
    ("Moneycontrol", "https://www.moneycontrol.com/rss/buzzingstocks.xml"),
    ("Mint", "https://www.livemint.com/rss/markets"),
]
UA = {"User-Agent": "Mozilla/5.0 (Garuda paper dashboard)"}
MAX_ITEMS = 30
REFRESH_SECS = 600            # one fetch round every ~10 minutes


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
        title = ""
        for ch in item:
            if ch.tag.split("}")[-1] == "title":
                title = (ch.text or "").strip()
                break
        if title:
            out.append({"src": src, "title": title[:180]})
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
    seen, out = set(), []
    for n in items:
        k = n["title"].lower()
        if k in seen:
            continue
        seen.add(k)
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
        # Swaminatha's filings lead the ticker — the news the fleet actually acted on
        for t in (swami_trades or [])[:5]:
            if t.get("side") == "BUY" and t.get("reason"):
                out.insert(0, {"src": "📜 SWAMINATHA BUY " + str(t.get("symbol", "")),
                               "title": str(t["reason"])[:180]})
        return out[:MAX_ITEMS]
