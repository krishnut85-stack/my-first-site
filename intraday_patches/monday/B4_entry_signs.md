# B4 - the entry signs from the study (+ J9 09:15 print)

**What changed**

RVOL is measured against the time of day:
- today's volume so far / (20-session average volume x the normal share of a day's volume by this minute);
- the curve is pooled from 300 share-days (the 5 sessions before the day, girdata/minute; never the day itself).
- RVOL5 = the last 5 minutes / the normal 5 minutes at this minute.

Volume source:
- `sh.vol` (the adapter patch after 15:35 today); until then it is recovered from the live `sh.rvol` (same formula, the same history file).
- The playback frames carry no volume, so there it says "volume not known" and does not block.

GO NOW needs a volume sign whenever volume is known: "no volume surge yet (RVOL x, RVOL5 y; needs RVOL >= 2 or RVOL5 >= 3 on its side of VWAP)".

Yesterday's high / low break is a trigger (B2) and a target level (B5).

No GO NOW once half the move is done:
- the onset is the study's rule: the minute after the last bar within 0.3% of the day's base; the 09:15 bar counts at its close;
- 20 min after the onset only a pullback entry may GO NOW;
- the card says "half the move is likely done: it started HH:MM (n min ago, +x% from the base)".

J9, the 09:15 print:
- it never seeds the day's high / low, the opening range (09:16-09:20), the first-15-min range or the morning range;
- RVOL5 never spans it (the first window starts at 09:16);
- the engine keeps its own VWAP from 09:16 (`vwap_src` on the card) when its count started by 09:20; otherwise the store's VWAP is used and labelled as including the print.

**Tests**
    test_0915_print_excluded ... ok
    test_half_done_blocks_late_go_now ... ok
    test_no_volume_surge_no_go_now ... ok
    test_surge_gives_go_now_with_rvol ... ok
