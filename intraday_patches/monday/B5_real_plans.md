# B5 - real trade plans

**What changed**

Series and strike:
- December ATM, or 1 ITM before 09:45.
- The December chain is read from `oc.<S>.exps[]` (live: bid, ask, IV, greeks) or `rows2` (the player).
- Checked on the 19 Nov 15:18 live store: BANDHANBNK Dec 175 PE 7.48, bid 7.37 / ask 7.48, spread 1.5%, IV 36.3, delta -0.44; COFORGE Dec 2040 CE 77.4, spread 0.8%, IV 31.7, delta 0.50.
- A strike is never offered when the chain's strikes do not cover the price (the SAIL PE 190 at 166.8 case).
- One strike per idea: the strike chosen at issue is kept while the idea lives, and changed only when the price moves more than 2 strikes away (the change is named on the card).

Targets come from REAL levels beyond the entry, nearest first, at least 0.5R away:
- yesterday's high / low / close, the day's high / low, the opening range, the first 15 min, the morning, the option wall.
- An ATR projection only when no real level is there, labelled "projection".
- The card says where T1 and T2 come from.

Levels are checked against the price now:
- price already through the stop = plan void;
- price already past T1 = "T1 reached - not a new entry" (it may step back from GO NOW at once).
- R:R uses the share levels against the price now, and the premium after estimated charges.

Premium and size:
- Premium shown as "premium X (ask Y, spread Z%)", or "no premium - not tradable".
- **0 lots, with the reason,** when there is no premium, R:R is below 1, or one lot risks more than 1R (Rs 5,000, design_v3/CONFERENCE). A 0-lot card never goes GO NOW and never rings.

**Tests**
    test_no_premium_zero_lots_no_go_now ... ok
    test_one_lot_above_1r_is_zero_lots ... ok
    test_rr_below_1_is_zero_lots ... ok
    test_strike_grid_must_cover_the_price ... ok
    test_targets_from_real_levels_and_premium_shown ... ok

**Before / after (captured frames)**
- R:R values: before {2.0: 1233, None: 16} on 16 Nov (flat 2.0 on every card); after 245 distinct values.
- Rings without premium: before 2 / 6 / 24 (16 / 18 / 19 Nov); after 0 / 0 / 0.
- On these frames (captured 19 Nov, before the player carried the December chain) nearly every card is "no premium - not tradable", which is correct for that data. The current player fills rows2 from girdata/minute/<day>/opt (16, 18, 19 Nov and 27, 29 Oct have option minutes), so the E1 replays will price the cards.

## With and without the replay-only "premium: Nov proxy" (desk order 20 Nov; switch GIR_PREM_PROXY=nov, removed by the live service at start)
Captured frames, rules only, final engine 0.3. "GO NOW tradable" = GO NOW rows with lots >= 1.

| day | proxy | priced cards | 0 lots | GO NOW tradable CE / PE | published side cards | rings |
|---|---|---|---|---|---|---|
| 18 Nov | off | 0 of 1,048 | 1,048 | 0 / 0 | 0 | 0 |
| 18 Nov | on | 936 of 1,080 | 623 (408 still no premium, rest R:R < 1) | 5 / 96 | 12 (11 PE GO NOW, 1 CE GO NOW) | 12 |
| 19 Nov | off | 0 of 1,160 | 1,160 | 0 / 0 | 3 | 0 |
| 19 Nov | on | 533 of 1,175 | 940 | 6 / 4 | 10 (4 CE GO NOW, 3 PE GO NOW, 3 PE GET READY) | 4 |

- 16 Nov frames carry no November chain rows, so the proxy cannot price them.
- Where the frames have a share's chain, the proxy prices it. Shares with no recorded chain still read "no premium - not tradable".
- The card always says "premium: Nov proxy X (replay only ...)".

Today's live frames (real December chain from oc rows2 / exps, no proxy): 288 tradable cards; GO NOW tradable 9 CE / 7 PE.
