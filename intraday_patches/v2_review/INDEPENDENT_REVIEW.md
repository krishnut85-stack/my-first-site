# Independent review of the v2 test runs (16 and 18 Nov 2026, real AI)

Three independent reviewers: a senior F&O dealer, a quant and an AI engineer. They worked from the raw files in this folder
(calls, AI log, the observer's log, flags and scorecards), not from the scorecards alone. Review date: 19 Nov 2026, evening.

## Verdict
**Not ready for the 5-day replay (15-19 Nov).** The AI side is cheap and reliable: $0.54-0.57 per replayed day, no errors and
no fallbacks. But the engine still does not warn BEFORE the move, it rings far too often, it gives almost only PE ideas, and the
AI's GO NOW check approves every card. The scorecard's arithmetic is sound, but two of its measures overstate the engine.

## Scores (senior dealer)
| run | score | cards: before / late / missed / wrong (2%+ movers) | rings |
|---|---|---|---|
| TEST_ai_full_1116 (v1) | 2/10 | 0 / 6 / 48 / 0 | 12 |
| TEST_ai_full_1118 (v1) | 1/10 | 0 / 0 / 53 / 0 | 7 |
| TEST_ai_full2_1116 (v2) | 3/10 | 1 / 30 / 22 / 1 | 132 |
| TEST_ai_full2_1118 (v2) | 3/10 | 0 / 38 / 15 / 0 | 163 |
| old system, same days | | 22 / 21 / 10 / 1 and 35 / 18 / 0 / 0 | |

## The main problems
1. **Late, not before.** Before the move: 1 and 0 calls (the old system: 22 and 35).
   - TMPV gapped −7.85% at 09:16 and the first ring came at 12:40.
   - KAYNES rang at 09:40, after a 9% fall. It bounced, and the call was WRONG by −4.99% after 60 minutes.
   - TITAN started at 09:17 and rang at 11:00. LAURUSLABS (−8.4%) and SWIGGY never rang. FORTIS (+5.1%) and NAVINFLUOR (+4.7%) got nothing.
2. **Almost only PE.**
   - Setups: 623 and 1,018 "day-low break" against 3 and 4 "day-high break".
   - Rings: 131 PE / 1 CE and 162 PE / 1 CE. All 57 GO NOW calls were PE.
   - 16 Nov had 13 shares up 3% or more with no timely CE.
   - The quant found that every call's side matched the sector's direction so far (100%). The small edge is simply "falling shares kept falling" on two weak days. The AI adds nothing: cards did no better than the silent WATCH list.
3. **Noise.**
   - 132 and 163 rings (the limit is 50). Up to 13 rings in 15 minutes (the limit is 6).
   - Cancel then re-issue within 15 minutes: 55 and 95 times. Ring then cancel within 5 minutes: 18 and 25.
   - HINDZINC rang at 10:50 and was cancelled at 10:51. TATASTEEL rang 9 times. KEI got 5 GO NOWs.
   - The observer's NOISE flag always says "7 rings" and so understates this.
4. **The trade plans cannot be traded as written.**
   - Reward/risk is a flat 2.0 on 93% of rows. Target 1 was reached within 60 minutes only 11 of 132 and 15 of 162 times.
   - Some strikes make no sense: SAIL PE 190 with the share at 166.8; PGEL PE 490 with the share at 543.6; JINDALSTEL's strike changed 15 times.
   - Levels were already stale when issued: KAYNES at 09:40 had target 1 at 2892 with the share at 2800.
   - About 18% of ringing cards had no premium.
   - After an estimated 1.5–3% round-trip cost on the premium, the average result is negative.
   - December expiry was used correctly.
5. **The GO NOW check is a rubber stamp.**
   - 57 of 57 CONFIRM, all in the same "not a chase" template. Contrary news is noted and then waved away.
   - It runs on Fable 5.2, not Opus 5.5 as planned. It is never shown the option premium, IV, spread, OI at the strike or days to expiry.
   - It takes 77–89% of the AI cost.
6. **The rate limiter, not the AI, picks what reaches the trader.**
   - It demoted 570 (18 Nov) and 247 (16 Nov) of the AI's MUST SEE cards by order of arrival, but those rows are still logged as "AI".
   - 24 GO NOW calls on 18 Nov sat hidden in WATCH with no AI check; 12 were wrong at 30 minutes.
   - The phone rang for 5 cards that were demoted in the same minute.
7. **AI second readings.**
   - 55 of 66 said DISAGREE, mostly because of junk news matched by ticker name ("KEI: Toyota's KEI-01 pickup", "TITAN: Ford vs Stellantis").
   - DISAGREE was right 10, wrong 10 and flat 3 times: a coin flip. Nothing uses the second reading.

## Scorecard check (quant)
- **Reproduced:** right/wrong/flat at 30 and 60 minutes, average move, before/late on the 2%+ movers, rings by hour and the 3% table.
- **Small differences:**
  - full_1118 judges one more row (VOLTAS PE 09:26) than calls.jsonl has.
  - "Rings 09:15–09:45" leaves out 09:45 itself.
- **The 3%-mover "in time" counts WATCH rows the trader never sees** (publish=false). That is why v1 and v2 show the same 21/4/12 and 24/1/5. Counting only cards, in time / late / missed:

  | | v1 | v2 |
  |---|---|---|
  | 16 Nov | 0/4/33 | 10/12/15 |
  | 18 Nov | 0/0/30 | 13/8/9 |

- **"LATE" is measured against the minute the move was later found to have begun.** 69 of 213 and 120 of 267 "late" rows came before the share had moved 2%.
- **Gap opens are dated 09:15 in one place and 09:16 in another,** so AMBER, KAYNES and MUTHOOTFIN at 09:16 are labelled BEFORE.
- **Flags:**
  - None fired wrongly under its own rule. The CE/PE sign is correct; the wording "−0.88% against it" is a confusing double negative.
  - YESBANK at 14:58 on 16 Nov was not flagged.
  - "NEWS DIRECTION WRONG" mixes news calls with the AI critic's misses and never credits the critic's hits.
  - The COST SPIKE 10-minute limit uses wall time, which means little in a fast replay.
- **No look-ahead leak found** in what the engine saw. Not checked: whether the history stats and the 07:15 daily watch leave out the replayed day itself.
- **v1 and v2 had the same candidates** (757 of 800 identical). Only the lanes changed: more cards, more rings, more cancels, the same quality per call.

## Cost (AI engineer)
| kind | model | calls per day | $ per day |
|---|---|---|---|
| triage | Haiku 5.5 | 182–264 | 0.06–0.12 |
| GO NOW check | Fable 5.2 | 21–26 | 0.41–0.51 |
| second reading | Haiku 5.5 | 16–17 | about 0.004 |

- **Live day projection:** about $0.9 on Fable, about $0.5 on Opus 5.5, and about $0.25 with Opus plus no repeat checks.
- **5-day replay:** about $1.5–2.8, far under the $25 budget.
- **Live caching:** checks about 15 minutes apart will miss a 5-minute cache, so use the 1-hour cache.
- **No secrets** were found in the logs.

## Fix before the 5-day replay (in order)
1. **One ring per share per idea.**
   - No cancel within 10 minutes of a ring, no re-issue within 15 minutes, and no new GO NOW just because the day's low moved.
   - Never ring a card that the rate limiter or the opening hold demotes.
   - Keep to 50 rings a day and 6 in 15 minutes.
2. **CE on equal terms with PE.**
   - Day-high break, VWAP reclaim, long build-up and sector-up setups, so that both sides are found.
   - Test on an up day as well (20 Nov or an October up day), not only on two down days.
3. **Warn before, not after.**
   - Use the pre-open, the 19:45 evening watch and the 07:15 drivers to put GET READY cards on the page before 09:15, with trigger levels.
   - No GO NOW after a share has already moved more than about 1.5 times its normal daily range, unless it is a pullback entry.
4. **Real trade plans.**
   - Strike near the money: ATM or 1 ITM December. Fix one strike per idea.
   - Check levels are not stale against the current price.
   - Reward/risk from real levels, not a fixed 2.0.
   - Show the premium or say "no premium - not tradable".
5. **A GO NOW check that can say no.**
   - Run it on Opus 5.5.
   - Give it the premium, IV, spread, OI at the strike and days to expiry, plus explicit reject rules.
   - Prove it says WAIT or REJECT on known bad cards.
   - Re-check only when something important changes.
6. **Triage ranks candidates** so the limiter keeps the best ones. Log the AI's lane and the final lane separately.
7. **News and the second reading.**
   - Match news by company and context, not by ticker text.
   - Split the second reading into "direction wrong" and "evidence weak", then use it or drop it.
8. **Scorecard.**
   - Count only cards the trader saw, and rings.
   - Score from the trigger fill, not from the call minute.
   - Stop the windows at 15:10.
   - Report the result after costs on the premium.
   - Show the real peak noise.
   - Rename the critic flag and credit the critic's hits.
   - Use one gap-open minute.
9. **Fault test once before the replay:** a timeout, a 429, a truncated answer and the budget cap.

**Pass mark for the 5-day replay to start:** on both 16 and 18 Nov plus one up day:
- cards before the move: at least 10 per day;
- CE calls appear on the up day;
- 50 rings a day or fewer, and 6 in any 15 minutes or fewer;
- the GO NOW check rejects at least some cards;
- the result after costs is not negative.
