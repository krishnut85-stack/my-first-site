# J4 FAKE-CLOCK MONDAY - Mon 23 Nov 2026 on a fake clock (previous session Fri 20, next Wed 25; Tue 24 holiday)

Made by `python3 -m analyst.j4fakeclock --md` (no Telegram, no AI, fake Kite, temp stores). Test: analyst/tests/test_j4fakeclock.py.

| job | check | expected | got | result |
|---|---|---|---|---|
| calendar | trading days Sat 21 / Sun 22 / Mon 23 / Tue 24 / Wed 25 | False False True False True | False False True False True | PASS |
| calendar | previous session of Mon 23 | 2026-11-20 | 2026-11-20 | PASS |
| calendar | next session after Mon 23 | 2026-11-25 | 2026-11-25 | PASS |
| calendar | next session after Sun 22 | 2026-11-23 | 2026-11-23 | PASS |
| calendar | previous session of Wed 25 | 2026-11-23 | 2026-11-23 | PASS |
| calendar | jobs Sun 22 (evening briefs for Mon) | C22=2026-11-23 N19=2026-11-23 | C22=2026-11-23 N19=2026-11-23 | PASS |
| calendar | jobs Mon 23 | C22=2026-11-25 LIVE=2026-11-23 N19=2026-11-25 P09=2026-11-23 SCORE=2026-11-23 U07=2026-11-23 | C22=2026-11-25 LIVE=2026-11-23 N19=2026-11-25 P09=2026-11-23 SCORE=2026-11-23 U07=2026-11-23 | PASS |
| calendar | jobs Tue 24 (holiday: nothing) |  |  | PASS |
| 07:15 brief | slot due at Mon 07:17 | 07:15 | 07:15 | PASS |
| 07:15 brief | brief session at Mon 07:17 | 2026-11-23 | 2026-11-23 | PASS |
| evening brief | Sun 20:00 -> next brief | Sun 22:45 | Sun 22:45 | PASS |
| evening brief | Sun 19:47 brief is for | 2026-11-23 | 2026-11-23 | PASS |
| evening brief | Mon 16:00 -> next brief (for Wed) | Mon 19:45 | Mon 19:45 | PASS |
| evening brief | Mon 19:47 brief is for | 2026-11-25 | 2026-11-25 | PASS |
| evening brief | Mon 23:00 -> next brief | Wed 07:15 | Wed 07:15 | PASS |
| 07:15 brief | gap line: India's last close before Mon 07:15 | 2026-11-20 | 2026-11-20 | PASS |
| 07:15 brief | gap line: India's last close before Wed 07:15 | 2026-11-23 | 2026-11-23 | PASS |
| 07:40 Kite login | trading day on the fake Monday | True | True | PASS |
| 07:40 Kite login | login allowed 07:40 | (True, '') | (True, '') | PASS |
| 07:40 Kite login | login refused 09:30 (market hours) | False | False | PASS |
| 07:40 Kite login | Tue 24 07:40 (holiday) | (False, 'not an NSE trading day') | (False, 'not an NSE trading day') | PASS |
| 08:20 key check | run_check (key 3 fails twice) | 1 | 1 | PASS |
| 08:20 key check | failed keys in the failover note | [3] | [3] | PASS |
| 08:20 account read | his account read OK, dated | True 2026-11-23 | True 2026-11-23 | PASS |
| 08:20 room-bars probe | probe session (previous session) + key used | 2026-11-20 4 | 2026-11-20 4 | PASS |
| 08:25 retry | retry runs; key 3 left alone after it | False | False | PASS |
| 08:35 retry | retry runs; key 3 left alone after it | False | False | PASS |
| 08:45 retry | retry runs; key 3 left alone after it | True | True | PASS |
| 08:00 health | status.json market at 08:00 | CLOSED | CLOSED | PASS |
| 08:00 health | status.json market at 09:20 | OPEN | OPEN | PASS |
| 08:00 ban list | Friday's ban file is not used as Monday's | True | True | PASS |
| 08:30 READY | READY line once, with the probe word | GIR READY 08:30/room bars: key 4 OK/1 | GIR READY 08:30/room bars: key 4 OK/1 | PASS |
| 08:30 READY | no second READY at 08:40 | None | None | PASS |
| heartbeat | first heartbeat slot on Monday | 09:30 | 09:30 | PASS |
| heartbeat | no heartbeat on Tue 24 | None | None | PASS |
| 08:45 flip watch | no flip reason before 09:00 | [] | [] | PASS |
| 09:05 carried position | Friday's carry is carried into Monday | SBIN26DEC1160CE | SBIN26DEC1160CE | PASS |
| 09:05 carried position | ONE 'CARRIED POSITION' card at 09:06 | CARRY/CARRIED POSITION 09:06 | CARRY/CARRIED POSITION 09:06 | PASS |
| 09:08 brief | slot due at Mon 09:10 | 09:08 | 09:08 | PASS |
| 09:08 brief | risk gates (account read at 08:20) | None | None | PASS |
| expiry | SBIN Nov monthly expires on Mon 23 (Tue 24 holiday) | 2026-11-23 | 2026-11-23 | PASS |
| expiry | option feed card series for SBIN on Mon 23 | 2026-12-29 | 2026-12-29 | PASS |
| expiry | option feed: sessions left in the Nov series on Mon 23 | 1 | 1 | PASS |
| expiry | index series measured on Mon 23 skip today's expiry | True | True | PASS |
| expiry | engine E0 on Mon 23: expiry day, December series | EXPIRY 2026-12-29 | EXPIRY 2026-12-29 | PASS |
| expiry | index desk NIFTY option expiry on Mon 23 (after today) | 2026-12-01 | 2026-12-01 | PASS |
| expiry | index desk futures on Mon 23 (> 5 days to expiry) | NFO:NIFTY26DECFUT | NFO:NIFTY26DECFUT | PASS |
| index desk | Monday rules | {'risk_pct': 0.5, 'max_index': 1, 'last_entry': '13:30', 'exit': '15:10', 'carry': False} | {'risk_pct': 0.5, 'max_index': 1, 'last_entry': '13:30', 'exit': '15:10', 'carry': False} | PASS |
| 14:45 carry warning | two-night line on Mon 23 | 2 nights to the next session (Wed 25 Nov) - Tue 24 Nov is a holiday | 2 nights to the next session (Wed 25 Nov) - Tue 24 Nov is a holiday | PASS |
| 14:45 carry warning | no two-night line on Wed 25 | None | None | PASS |
| 14:45 gap card | Monday card names the 2 nights | True | True | PASS |
| 14:45 gap card | card's next session | True | True | PASS |
| 20:40 m2prep | Sun 22 evening prepares | 2026-11-23 | 2026-11-23 | PASS |
| 20:40 m2prep | Mon 23 evening prepares | 2026-11-25 | 2026-11-25 | PASS |
| 20:40 m2prep | Tue 24 (holiday) evening prepares | 2026-11-25 | 2026-11-25 | PASS |
| 20:40 m2prep | Wed 25 prep reads the previous session | 2026-11-23 | 2026-11-23 | PASS |
| Wed 25 07:15 brief | WEEKEND RISK GAUGE slot after the holiday (wording says 'since Fri 15:30') | False | True | FAIL |

57 checks, 56 PASS, 1 FAIL.

## Notes
- FIXED during the run: kitelogin.py's account read stamped the real clock instead of the job's own clock (a fake-clock run dated it Sat 21; on the real Monday both agree). It now uses kitelogin's now() (kitelogin.py.bak1730j).
- NAMED, not fixed (news builder's file analyst/gauges.py): on Wed 25 07:15 (after the Tue 24 holiday) weekend_slot() is True, so the WEEKEND RISK GAUGE prints 'Bitcoin ... since Fri 15:30 IST' - the field is pct_since_fri_1530 from p_gauges. On Wed it should be 'since Mon 15:30' (or the gauge skipped). Not a Monday 23 problem.
- FOUND (no change needed, for the desk): Mon 23 Nov is the NOVEMBER MONTHLY EXPIRY (moved from the Tue 24 holiday). The engine's E0 reads it as an EXPIRY day: half size (1 lot minimum), A setups only, the December series (29 Dec), the expiry-day entry cut-off. The option feed's card series and the index desk both skip today's expiry (NIFTY options -> the next weekly 1 Dec; futures -> December).
- Previous session = Fri 20 everywhere it is computed (calendar, gap line, carry, room-bars probe); next session = Wed 25 (calendar, evening brief 19:45 for Wed, gap / carry cards, m2prep).
