"""Tests for the news ticker — RSS parsing + Swaminatha filings merge."""

from garuda.news import NewsTicker, parse_rss

RSS = b"""<?xml version="1.0"?><rss><channel>
<item><title>Nifty ends flat as IT drags</title></item>
<item><title>Smallcap index up 1.2%</title></item>
<item><title></title></item>
</channel></rss>"""


def test_parse_rss():
    items = parse_rss(RSS, "ET")
    assert [i["title"] for i in items] == ["Nifty ends flat as IT drags",
                                           "Smallcap index up 1.2%"]
    assert all(i["src"] == "ET" for i in items)
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
    assert items[1]["title"] == "Nifty ends flat as IT drags"
    # SELLs never enter the ticker
    assert not any("SELL" in i["src"] for i in items)
