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
