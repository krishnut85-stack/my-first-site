# B2 - CE equal to PE

**What changed:** new share-led setups. Every F&O share is judged on BOTH sides on its own signs, mirrored exactly (`core._signs` / `core._share_led`).

Triggers:
- yesterday's high / low (girdata/history daily bars, the session before the day);
- the day's high / low, with the old extreme at least 15 min old, from 09:30;
- the 09:16-09:20 opening range (09:21-10:00);
- VWAP reclaim / loss: 10 of 15 one-minute closes on the wrong side, then 2 closes over.

Backing signs: RVOL >= 2, RVOL5 >= 3, fresh build-up its way, its sector moving its way (the sector-up setup).

Rules:
- A candidate needs a trigger plus a backing sign. A share in the red needs the VWAP turn for a CE, and the mirror for a PE.
- At most 25 share-led candidates at once, strongest first.

**Tests**
    test_exact_mirror ... ok
    test_vwap_reclaim_and_loss_both_exist ... ok

test_exact_mirror runs a synthetic up day and its exact mirror around 100. Both give the same calls at the same minutes with the same setups, the sides swapped (CE on the up day, PE on the mirror).

**Up-day check, 19 Nov (NIFTY up), captured frames, rules only**

| | CE | PE |
|---|---|---|
| GO NOW-ready cards (only the missing premium holds them) | 76 | 24 |

- Setups on 19 Nov: opening-range breakout CE 32, first VWAP pullback CE 25, day-high break CE 10, yesterday's-high break CE 4, VWAP reclaim CE (see after2_2026-11-19.txt).
- 16 Nov: CE 37 / PE 26. 18 Nov (down day): CE 11 / PE 72.
- Old engine on the same frames, published + log GO NOW: 16 Nov CE 10 / PE 183; 18 Nov CE 2 / PE 294 (before_*.txt).

An October up day needs the player (October has no captured frames). It is in the coordinator's E1 replays.

**By design, still not mirrored** (the trader's / broker's own rules):
- the short-covering CE window (09:30-11:00, above VWAP, with its sector);
- the VIX kill on CE;
- the cost-relief CE price rule.
