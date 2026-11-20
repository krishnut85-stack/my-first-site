# B6 - a GO NOW check that can say no

**What changed**

The chain and the call:
- The GO NOW check runs first on the strongest model of the GO NOW chain (config: FINAL_CHAIN; ids in code only), then falls back.
- Effort medium, structured output (verdict / reason / go_now_when), server-side refusal fallback.
- The slice rule no longer cuts it to the small model (J11); only the whole day's budget stops it.

What the check is given: premium, bid / ask, spread %, IV, delta, OI at the strike, days to expiry, lot, one-lot risk against 1R, R:R share and premium after charges, the entry signs, RVOL / RVOL5, the onset of the move, money, the sector grade, news, and the engine's waits and warnings.

Written rules, in the prompt AND in code (`core.final_precheck`):
- **REJECT** R1 no premium / strike not ATM or 1 ITM; R2 levels stale (through the stop or past T1); R3 R:R < 1 after costs or one lot > 1R; R4 spread > 3% or OI at the strike < 20 lots; R5 money against the price, against its own sector, or own news the other way; R6 the contract expires today.
- **WAIT** W1 the move started 20+ min ago and the entry is not a pullback; W2 chase (more than 0.3 ATR past the trigger); W3 no volume surge; W4 IV >= 60% or a spread of 1.5-3%; W5 NIFTY / sector turning.
- A REJECT rule never reaches the AI and never rings.
- The AI may not CONFIRM a card whose rule check says REJECT.

Re-check: only when something important changes (premium about 10%, spread band, strike, sector grade, money, the price's position against the trigger, the onset, 0 lots, warnings); otherwise the verdict stands up to 30 min.

**Known bad cards** (tools/b6_cards.py: INDEPENDENT_REVIEW + TEST_ai_full2/3/4 runs, plus SYNTHETIC faults and 2 clean controls). The written rules:

| card | pass if | rules say | why |
|---|---|---|---|
| KAYNES PE 16 Nov 09:40 - rang after a 9% fall, T1 2892 with the share at 2800 | REJECT/WAIT | REJECT | R2 the share 2800.00 is already past T1 2892.07; R3 R:R -0.66 below 1 |
| SAIL PE 190 with the share at 167.0 (18 Nov 09:30) | REJECT | REJECT | R1 strike 190.0 is 14% from the share 167.00 - not ATM / 1 ITM; R3 R:R 0.85 below 1 |
| PGEL PE 490 with the share at 542.25 (16 Nov 09:30) | REJECT | REJECT | R1 strike 490.0 is 10% from the share 542.00 - not ATM / 1 ITM; R3 R:R 0.95 below 1 |
| SUPREMEIND PE with no premium (18 Nov 10:50) | REJECT | REJECT | R1 no strike / no premium in the chain - not tradable; R3 R:R 0.90 below 1 |
| TATAELXSI PE 14:25 breakout, sector confirmed since 13:53 (16 Nov) - WRONG at 30 | REJECT/WAIT | REJECT | R3 R:R 0.93 below 1; W1 the move started 13:53 (32 min ago) - half is likely done; pullback entry only |
| BSE CE 09:31 opening-range breakout, R:R 1.0 before costs (18 Nov) - WRONG -1.44 | REJECT/WAIT | REJECT | R3 R:R 0.92 below 1; R3 one lot risks Rs 5,259 > 1R Rs 5,000 |
| JINDALSTEL PE 14:00 day-low break, R:R 1.0 before costs (16 Nov) - WRONG at 30 a | REJECT/WAIT | REJECT | R3 R:R 0.92 below 1; W1 the move started 13:40 (20 min ago) - half is likely done; pullback entry only |
| SYNTHETIC: spread 8% of the premium | REJECT | REJECT | R4 spread 8.0% of the premium > 3% |
| SYNTHETIC: open interest at the strike 5 lots | REJECT | REJECT | R4 open interest at the strike 5000 (5 lots < 20) - illiquid |
| SYNTHETIC: fresh longs (LB) on a PE | REJECT | REJECT | R5 futures money against the price (LB on a PE) |
| SYNTHETIC: the contract expires today | REJECT | REJECT | R6 the contract expires today - use the next series |
| SYNTHETIC: IV 78% at the strike | REJECT/WAIT | WAIT | W4 IV 78% at the strike (>= 60%): premium rich, IV-crush risk |
| SYNTHETIC: no volume surge (RVOL 1.1, RVOL5 0.9) | REJECT/WAIT | WAIT | W3 no volume surge |
| CONTROL: clean CE - yesterday's-high break, RVOL 2.8, fresh longs, 6 min into th | CONFIRM | CONFIRM |  |
| CONTROL: clean PE mirror | CONFIRM | CONFIRM |  |

Result: 13 of 13 bad cards WAIT / REJECT; 2 of 2 controls CONFIRM.

**The AI on the same cards:** `engine/tools/b6_prove.py`, run by the coordinator under the service environment after the swap. Each card is read twice: with the rule line, and BLIND (the rule line removed, so the model judges the numbers alone). Results go to B6_ai_proof.jsonl in this folder.

**Tests**
    test_chain_and_prompt ... ok
    test_reject_rule_never_reaches_the_ai_and_recheck_only_on_change ... ok
    test_rules_say_no_on_the_known_bad_cards ... ok
