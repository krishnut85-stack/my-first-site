# B6 - the GO NOW check on known bad cards (AI proof, 20 Nov after the close)

Engine 0.3 (swapped 15:38). 15 cards: 7 real bad cards from 16 / 18 Nov, 6 synthetic faults, 2 clean controls. Each card read three ways: the written rules alone (code), the AI WITH the rule-check line, and the AI BLIND (rule line removed - it judges the numbers alone). 30 AI calls on the GO NOW model, $0.19 from the replay ledger (day key b6-proof).

```
rules    with     blind    expected            card
REJECT   REJECT   REJECT   want REJECT/WAIT    KAYNES PE 16 Nov 09:40 - rang after a 9% fall, T1 2892 with the share
REJECT   REJECT   REJECT   want REJECT         SAIL PE 190 with the share at 167.0 (18 Nov 09:30)
REJECT   REJECT   REJECT   want REJECT         PGEL PE 490 with the share at 542.25 (16 Nov 09:30)
REJECT   REJECT   REJECT   want REJECT         SUPREMEIND PE with no premium (18 Nov 10:50)
REJECT   REJECT   REJECT   want REJECT/WAIT    TATAELXSI PE 14:25 breakout, sector confirmed since 13:53 (16 Nov)
REJECT   REJECT   REJECT   want REJECT/WAIT    BSE CE 09:31 opening-range breakout, R:R 1.0 before costs (18 Nov)
REJECT   REJECT   REJECT   want REJECT/WAIT    JINDALSTEL PE 14:00 day-low break, R:R 1.0 before costs (16 Nov)
REJECT   REJECT   REJECT   want REJECT         SYNTHETIC: spread 8% of the premium
REJECT   REJECT   CONFIRM  want REJECT         SYNTHETIC: open interest at the strike 5 lots
REJECT   REJECT   REJECT   want REJECT         SYNTHETIC: fresh longs (LB) on a PE
REJECT   REJECT   REJECT   want REJECT         SYNTHETIC: the contract expires today
WAIT     WAIT     WAIT     want REJECT/WAIT    SYNTHETIC: IV 78% at the strike
WAIT     WAIT     WAIT     want REJECT/WAIT    SYNTHETIC: no volume surge (RVOL 1.1, RVOL5 0.9)
CONFIRM  CONFIRM  CONFIRM  want CONFIRM        CONTROL: clean CE - yesterday's-high break, RVOL 2.8, fresh longs, 6 m
CONFIRM  CONFIRM  CONFIRM  want CONFIRM        CONTROL: clean PE mirror
rules: 13 of 13 bad cards WAIT / REJECT
with_rules: 13 of 13 bad cards WAIT / REJECT
blind: 12 of 13 bad cards WAIT / REJECT
```

PASS: the AI never confirmed a card the rules reject (with the rule line: 13 of 13 bad cards WAIT / REJECT, both clean controls CONFIRM); all 7 real bad cards REJECT in every read. The only miss is BLIND on the synthetic 'open interest at the strike 5 lots' card (it confirmed) - with the rule line, and in code, that card is rejected, and the code reject runs before the AI, so a live card like it never reaches the AI.

Raw answers: B6_ai_proof.jsonl (one row per card and read), B6_ai_raw.jsonl.
