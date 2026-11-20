# DESK REVIEW - answers to the server's STATUS.md (newest first)

## 20 Nov 07:55 IST - on STATUS 07:38
1. **PREDICTION_LOOP.md is FINAL and pushed** (commit dee16ff) with R52-R56. C1-C5 can start. Decisions are inside it (Departures,
   decided under his order): live from Monday with the NOT PROVEN label; 09:17 earliest for predicted shares (09:17-09:30 only the
   09:08 top 5); index line on the next weekly; ONE $5 AI cap replacing every $20 in BUILD_PLAN.
2. **Websocket slots (A1 / J2 risk): the NEW system gets the websocket slots on Monday.** The silent old system must NOT hold them.
   Its comparison runs from the new recorder's data (or REST quotes), or by replaying its logic on the recorded day after 15:35 -
   your choice, whichever is safer. The fallback switch `gir mode old` must hand the slots back to the old system and `gir mode new`
   take them again - test both ways on Sunday with real reconnects (F2 / J7). Today J2 on REST every 3 s is accepted.
3. **Kite logins (J1 risk): all four keys must be logged in by the automatic login before 08:00 on Monday**, not by the old engine at
   09:04 / 09:21. Move keys 2 / 3 / 4 to the same early auto-login as key 1; Sunday dry run of all four; 08:20 check.
4. **New: TRADER_CALLS.md** (design_v3). After 15:35 today score his pre-open reads: defence F&O shares UP; DIXON and its group UP;
   the aerospace / defence share that jumped 4% on a 2.51% FII + DII bulk deal (find it in Thursday's NSE bulk / block file). From
   the 09:15 open and from Thursday's close, vs NIFTY and vs sector. His reads become a scored source ("TRADER READ") in EVENT_MEMORY.
5. **preopenstudy.py**: still being checked by the desk; it lands this afternoon. G1 waits for it.

## 20 Nov 08:30 IST - TRADER_CALLS.md now holds 33 of his past reads
After 15:35 (light job), score every row marked "TO SCORE (server)" from the minute store / NSE closes: the move from the time he
said it to that day's close and the next day's close, right side or not, vs NIFTY and vs sector. Also score today's 07:45 reads and
his 19 Nov call (consumer and auto down on 20 Nov). Push the filled table. His reads go into EVENT_MEMORY as source "TRADER READ"
with this hit rate, CE and PE kept apart (so far his PE reads have been right far more often than his CE reads).
