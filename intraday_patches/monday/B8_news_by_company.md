# B8 - news matched by company and context; the second reading split and used

**What changed**

`engine/newsmatch.py`: a news item counts as a share's OWN news only when the headline is about that company in context.
- **N1** the company must be named by its distinctive name or a known alias. A short or common-word name (KEI, TITAN, TRENT, ADANI...) needs the full name or the ticker in capitals.
- **N2** a product code ("KEI-01") is not the company.
- **N3** another company sharing the name word ("Waaree ESS", "Muthoot Microfin") is not it.
- **N4** the company as a counterparty ("... gets $4 Million From Bajaj Finance").
- **N5** baskets, "stocks to watch" and strategy notes are not one company's news.
- **N6** personal stories ("techie") are not company news.
- Filings always pass.
- A dropped item stays in the market news. It only stops being the share's own news (no E12 / DIVERGENT / own-news vote / sector-line news). The state file lists every drop with its reason (`news_dropped`). Sector-wide policy rules (POLICY_SIGNS) still read every headline.

The second reading now answers **AGREE / DIRECTION WRONG / EVIDENCE WEAK**:
- DIRECTION WRONG is USED: no GO NOW on that sector thesis, and a basket shock becomes WATCH only.
- EVIDENCE WEAK is shown on the card and changes nothing. On 16 / 18 Nov "DISAGREE" was right 10, wrong 10, flat 3; most of it came from junk news, now removed before the reading.

**The two named cases:** "KEI: What it's like to drive Toyota's new KEI-01 pickup" is dropped (N1/N2). "TITAN: Ford Motor vs. Stellantis: Which Automaker Titan Stock..." is dropped (N1).

**On the replay days** (the share-matched items of the day's news.list; full list in B8_news_drops_16-19nov.txt):

- 2026-11-16: share-matched items 150 - kept 132, dropped 18 {'N1': 12, 'N3': 1, 'N4': 2, 'N5': 3}
- 2026-11-18: share-matched items 149 - kept 111, dropped 38 {'N1': 30, 'N4': 1, 'N5': 6, 'N6': 1}
- 2026-11-19: share-matched items 150 - kept 130, dropped 20 {'N1': 13, 'N3': 1, 'N4': 2, 'N5': 3, 'N6': 1}

Dropped examples: Severn Trent results on TRENT, "Scion by Toyota KEI-01", Citizen "Kei" watches, "Muthoot FinCorp Q2" on MUTHOOTFIN, the "Government reviews LTCG / STT" policy item copied onto every capital-markets share, "The Sky Today: Titan south".

Kept examples: "Alkem Labs shares fall 2% as US FDA issues warning letter", "SBI Q2 FY27: Profit...", "Hyundai October 2026 Sales Hit Record", "Puneet Anand bids adieu to Hyundai Motor India".

**Tests** (29 real headlines with their right answer, plus the split)
    test_filing_always_passes ... ok
    test_real_headlines ... ok
    test_second_reading_is_split ... ok
