# J10 - expiry-day mode for Mon 23 Nov

- **Stock options December only:** on the expiry day (and from E-4) the current series is blocked; plans use December (2026-12-29). Tested.
- **Index options:** on an index's expiry day GIR suggests the NEXT expiry. NIFTY: the 1 Dec weekly; BANKNIFTY: 29 Dec. The expiring contract is shown as "information only - expires today 15:30". The state file's `index_options` carries the ATM strike with CE / PE premium, spread, IV and OI from the store. Config `INDEX_EXPIRY_SERIES = "next"` can be set back to "expiring" at any time. Tested on the live 19 Nov store with the clock set to Mon 23 Nov 10:00.
- **Build-up from OI across ALL months:** in the expiry week / day the engine names the build-up itself from total OI (all months) and price (|total OI| >= 0.5%). The rollover empties the near month and can fool a near-month word. The feed's word is kept as `bu_feed` when it differs, and the card shows `bu_src`. Tested: feed "LU" with total OI +2.4% and price +1.0% reads LB.
- **Pinning:** from 13:30 on the contract's expiry day, a price within 0.3% of the expiring series' biggest-OI strike puts a WARNING on the card. The AI must overrule it for MUST SEE. Tested at 13:00 (no flag) and 13:45 (flag).
- `expiry_mode` line in the state file: "EXPIRY DAY: stock options in the next month only ...; no new entry after 14:00".
- 27 Oct (the last expiry day) is in the coordinator's E1 list. It needs the player (no captured frames).

**Tests**
    test_buildup_from_all_months_in_rollover ... ok
    test_index_next_weekly_expiring_is_info ... /home/globalbot/intraday/v2/engine_next/tests/test_monday.py:547: ResourceWarning: unclosed file <_io.TextIOWrapper name='/home/globalbot/intraday/v2/engine_next/tests/fixtures/store_20261119_1518.json' mode='r' encoding='UTF-8'>
    test_pinning_from_1330 ... ok
    test_stock_options_december_only ... ok
