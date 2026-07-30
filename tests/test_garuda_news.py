"""Tests for the news ticker — RSS parsing, freshness filter, filings merge."""

import time
from email.utils import formatdate

from garuda.news import NewsTicker, parse_rss

RSS = b"""<?xml version="1.0"?><rss><channel>
<item><title>Nifty ends flat as IT drags</title><link>https://x.in/a1</link></item>
<item><title>Smallcap index up 1.2%</title><link>https://x.in/a2</link></item>
<item><title></title></item>
</channel></rss>"""


def test_parse_rss():
    items = parse_rss(RSS, "ET")
    assert [i["title"] for i in items] == ["Nifty ends flat as IT drags",
                                           "Smallcap index up 1.2%"]
    assert all(i["src"] == "ET" for i in items)
    assert items[0]["link"] == "https://x.in/a1"


def test_fetch_freshness_filter_and_age():
    from garuda.news import MAX_AGE_SECS, _age, _ts
    now = time.time()
    fresh = formatdate(now - 7200)               # 2h old
    stale = formatdate(now - 40 * 86400)         # 40 days old (the "2024 news" bug)
    assert now - _ts(fresh) < 7300
    assert now - _ts(stale) > MAX_AGE_SECS
    assert _ts("") == 0 and _ts("garbage") == 0
    assert _age(now - 120, now) == "2m"
    assert _age(now - 7200, now) == "2h"
    assert _age(now - 3 * 86400, now) == "3d"
    assert _age(0) == ""
    assert parse_rss(b"not xml at all", "X") == []


def test_ticker_merges_swami_filings_without_network():
    t = NewsTicker(feeds=[])                 # no feeds -> no network at all
    t._items = parse_rss(RSS, "ET")
    t._at = 9e12                             # far future: skip refresh entirely
    trades = [{"side": "BUY", "symbol": "LUPIN",
               "reason": "Lupin gets USFDA approval for gTolvaptan"},
              {"side": "SELL", "symbol": "X", "reason": "exit"}]
    items = t.items(trades)
    assert items[0]["src"].startswith("📜 SWAMINATHA BUY LUPIN")
    assert "USFDA" in items[0]["title"]
    assert items[0]["link"].startswith("https://www.google.com/search?q=")
    assert items[1]["title"] == "Nifty ends flat as IT drags"
    # SELLs never enter the ticker
    assert not any("SELL" in i["src"] for i in items)
