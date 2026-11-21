# ANALYST step 3 - the BRIEF (v2/analyst/brief.py) - 20 Nov 2026 evening

- Slots on the ONE NSE calendar (predict.common.job_plan): 19:45 + 22:45 on the evening before a session (a trading day, or a Sat / Sun whose
  next day is a session: Sun 22 Nov for Mon 23; Mon 23 for Wed 25; nothing on Sat 21 or the holiday Tue 24), 07:15 and 09:08 on trading days.
  The service runs them 2 minutes after the prediction loop's own job (19:47, 22:46, 07:17, 09:10) so its newest C1 list is in the snapshot.
  A slot never runs twice (board looks); a slot found more than 25 min late is skipped and named, never run stale.
- 19:45: the head writes the market-day view (lean + reason ids) and at most 5 ideas per side; code attaches contract, share stop / target,
  size ("lots at the open" - that day's lock room and trades decide). 22:45: a CODE check first, no AI money - only a weight >= 4 item since
  19:45 or a world driver past its threshold (Nasdaq 1%, SOX 2%, Brent 2%, GIFT 0.8%, USDINR 0.5%, gold / copper / Hang Seng 2%) wakes the head;
  otherwise "22:45 - nothing broke since 19:45: the evening brief stands". 07:15 / 09:08 lead with what changed; 09:08 freezes the list and
  every idea says the live confirmation it waits for.
- The C1 candidate table enters as INPUT in the snapshot ("code lists, no better than random before the open"), never the answer.
- Each idea is printed in the BUY format of ANALYST.md 1: BUY <contract> · WHY (claims with evidence ids) · AGAINST · ENTER only if ·
  CANCEL if · STOP (share) · TARGET (share) · SIZE · CONFIDENCE <grade>, NOT PROVEN. Written to <out>/<session>/brief_<session>_<slot>.{json,md}
  and into state.json (key brief) for the Morning page.

## Dry-run output (FAKE head - plumbing only, NOT the analyst; live store 20 Nov after the close, his trades not shown)
```
GIR ANALYST BRIEF 19:45 for 2026-11-23 (made 2026-11-20 18:52 IST) - NOT PROVEN
MARKET DAY: MIXED - FAKE dry run (AI off) at 18:52 - plumbing test, not the analyst.

CALLS (CE):
1. BUY CUMMINSIND Dec 4100 CE (ATM, exp 2026-12-29) · WHY: FAKE: a weight-3 news item names the share · AGAINST: FAKE dry run - no reasoning · ENTER only if FAKE: price confirms · CANCEL if FAKE: price fails · STOP share 4048.14 · TARGET share 4328.22 · SIZE lots at the open - premium not known yet · CONFIDENCE LOW, NOT 

PUTS (PE):
1. BUY JSWSTEEL Dec 1340 PE (ATM, exp 2026-12-29) · WHY: FAKE: a weight-4 news item names the share · AGAINST: FAKE dry run - no reasoning · ENTER only if FAKE: price confirms · CANCEL if FAKE: price fails · STOP share 1316.63 · TARGET share 1275.73 · SIZE lots at the open - premium not known yet · CONFIDENCE LOW, NOT PR
```

## Honest limits
- The brief has never been written by the real model yet (no key in my session). The first real one is Sunday 19:47 for Monday, if the
  coordinator starts gir-v2analyst (unit not installed by me - permission).
- Premiums in the evening are yesterday's; the brief's size line says so instead of guessing lots.
- "What changed since 19:45" lists ideas CHANGED / CANCELLED in the last 12 h; a market-level diff (US close, GIFT) is in the head's words only.
