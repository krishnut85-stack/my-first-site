# FREE UPGRADES 2-8 (DESK_REVIEW 21 Nov 13:30) - status after the first studies (21 Nov 2026, second builder)

Rule used everywhere: an effect counts only if it shows the same sign with |t| >= 2 in the DISCOVERY years AND again in later UNSEEN years.
Nothing below is on any card. "testing" = study built and run, result below; the code is in v2/models/studies/.

| # | upgrade | state | first result (unseen data) | files |
|---|---|---|---|---|
| 2 | trust score per source | testing (scorer built) | old desk's 13,404 scored calls, 10 days (6 learn / 4 unseen): trust ranking carries over (corr 0.75, 11 sources) but top third 51.0% vs bottom third 48.5% right, z 1.75 < 2 -> not beating random yet. v2 seats: not enough history yet (scorecard starts Mon 23 Nov). | v2/models/trust.py, u2_trust.md |
| 3 | FII participant-wise OI | testing | 1,706 days (2020-2026): FII index-futures change, FII long share, client change -> NIFTY gap / 1 / 3 days: nothing holds (FII long share looked good 2020-23, t 2.99, flips on 2024-26). | u3_participant.md |
| 4 | event library (NSE archives) | testing (ban list only) | 595 F&O ban entries / exits 2023-2026: discovery effects (exit gap +0.37%, entry day -0.55%) vanish on 2025-26 -> nothing holds. Results-day, bulk / block, broker calls, index inclusion: not started (no free archive without a session cookie). | u4_events.md |
| 5 | GDELT news history | testing (backfill running) | DOC API refuses this server (HTTP 429). Raw daily event files used, filtered to India (one row a day, zips deleted, folder < 1 MB). See u5_gdelt.md for the latest run: no tone / volume / conflict signal holds; company news spike -> bigger next move held in discovery only. | u5_gdelt.md, girdata/ext/gdelt_backfill/raw |
| 6 | options signals | testing - 3 signals HOLD | ATM IV history (272 days, 52k share-days): IV jump top fifth -> next-day move 0.60 vs 0.53 ATR (t 8.0 unseen); same on QUIET days (control, t 6.1); IV crush -> smaller next move (t -8.2); IV jump + share fell -> next day +0.11% vs 0.00% (t 2.5). PCR / OI walls / max pain: chain store has 1 day - not enough history. | u6_options.md |
| 7 | market regime | testing - no rule holds | rules fixed first (HIGHVOL / TREND_UP / TREND_DOWN / RANGE). "No breakout CE in a range regime" is NOT supported: 2024-26 breakouts in RANGE +0.08% vs TREND_UP -0.20% over 3 days (n 5,767 / 1,179). HIGHVOL -> bigger next-week moves holds on unseen only (t 3.0) - discovery had n 37. Last close 20 Nov: HIGHVOL. | u7_regime.md, artifacts/regime_rules.json |
| 8 | calendar effects | testing - size effects only | no DIRECTION effect holds (expiry week / day, pre-holiday, month start, results season, budget, weekdays, AUTO month start, RBI MPC days). SIZE effects that hold: day after an NSE holiday bigger moves (t 2.9) and bigger gaps (t 2.6); Wednesday quieter (t -2.4). | u8_calendar.md |

Ready for a card LATER (only as size / room, never as direction): IV jump -> bigger next-day move; IV crush -> smaller; day after a holiday -> bigger move / gap.
