# C3 - LIVE NEWS CALLS - proof

Code: `v2/predict/newscall.py` (call + labels + the C5 price confirm), driven by `live.py` on every 5-second poll of the v2 reader's
verdict file (newsread.jsonl: filings, wires, publishers, TV speech-to-text), so a card is on the page within one poll (~5 s) of the reader's
verdict; the reader's own latency comes before that. Company match = the engine builder's rules (engine_next/newsmatch.py, read-only).
One line, both sides: "NEWS hh:mm · source · NEW / REPEAT / DENIAL / OFFICIAL · VERIFIED / UNVERIFIED - TV ONLY / SOURCES SAY -> can go UP: A, B
/ can go DOWN: C · GO NOW only if A above the first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrower".
Impact 4-5 makes a call (3 = silent row); REPEAT = silent "repeat - fade only"; TV-only capped at weight 3 unless it touches a predicted or
held share, and never a GO NOW; readers disagreeing / still checking = never a GO NOW; MARKET DISAGREES (0.5% the other way in 5 min);
"already moved before the news" (1 ATR or 1.5% in the 15 min before); expires silently after 10 min; merged into a predicted share's card as
NEWS AGREES / NEWS AGAINST. Source time: the reader's rows carry GIR's first-seen time only, so 'seconds after the first source' is shown
as 'not known' until the reader stores the source time.

## 2026-11-20 replay by first-seen minute: 16 items (0 CALL, 16 silent rows)
- seen 09:15 · silent row (impact 3 < 4) · NEWS 09:00 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: VEDL · GO NOW only if VEDL below first-seen price by 0.3 ATR with RVOL
- seen 09:21 · silent row (impact 3 < 4) · NEWS 09:20 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class B) -> can go UP: SYRMA, AMBER / can go DOWN: KAYNES · GO NOW only if SYRMA above first-seen price
- seen 10:09 · silent row (impact 3 < 4) · NEWS 10:08 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: MUTHOOTFIN, KALYANKJIL · GO NOW only if MUTHOOTFIN below first-seen pr
- seen 10:24 · silent row (impact 3 < 4) · NEWS 10:23 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MAXHEALTH / can go DOWN: - · GO NOW only if MAXHEALTH above first-seen price by 0.3 ATR
- seen 10:29 · silent row (impact 3 < 4) · NEWS 10:28 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: BDL / can go DOWN: - · GO NOW only if BDL above first-seen price by 0.3 ATR with
- seen 10:30 · silent row (impact 3 < 4) · NEWS 10:29 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MAXHEALTH, APOLLOHOSP / can go DOWN: - · GO NOW only if MAXHEALTH above first-seen pric
- seen 10:38 · silent row (impact 3 < 4) · NEWS 10:37 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MUTHOOTFIN, MANAPPURAM / can go DOWN: KALYANKJIL · GO NOW only if MUTHOOTFIN above firs
- seen 10:41 · silent row (impact 3 < 4) · NEWS 10:40 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: LUPIN / can go DOWN: - · GO NOW only if LUPIN above first-seen price by 0.3 ATR 
- seen 11:04 · silent row (impact 3 < 4) · NEWS 11:03 · TV CNBC-TV18 (speech-to-text) · NEW · UNVERIFIED - TV ONLY -> can go UP: - / can go DOWN: VEDL · GO NOW only if VEDL below first-seen price by 0.3 
- seen 11:12 · silent row (impact 3 < 4) · NEWS 11:11 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: PAYTM · GO NOW only if PAYTM below first-seen price by 0.3 ATR 
- right at +30 min (abnormal vs NIFTY): 7 of 16

## 2026-11-16 replay by first-seen minute: 0 items (0 CALL, 0 silent rows)
- right at +30 min (abnormal vs NIFTY): 0 of 0

## 2026-11-18 replay by first-seen minute: 0 items (0 CALL, 0 silent rows)
- right at +30 min (abnormal vs NIFTY): 0 of 0

## 2026-11-19 replay by first-seen minute: 0 items (0 CALL, 0 silent rows)
- right at +30 min (abnormal vs NIFTY): 0 of 0

## 2026-10-29 replay by first-seen minute: 0 items (0 CALL, 0 silent rows)
- right at +30 min (abnormal vs NIFTY): 0 of 0

## 2026-10-27 replay by first-seen minute: 0 items (0 CALL, 0 silent rows)
- right at +30 min (abnormal vs NIFTY): 0 of 0

## Fri 20 Nov LIVE shadow run: 25 news items
- 10:08 · ROW · NEWS 10:08 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: MUTHOOTFIN, KALYANKJIL · GO NOW only if MUTHOOTFIN below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: deni
- 10:23 · ROW · NEWS 10:23 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MAXHEALTH / can go DOWN: - · GO NOW only if MAXHEALTH above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope nar
- 10:28 · ROW · NEWS 10:28 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: BDL / can go DOWN: - · GO NOW only if BDL above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrower
- 10:29 · ROW · NEWS 10:29 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MAXHEALTH, APOLLOHOSP / can go DOWN: - · GO NOW only if MAXHEALTH above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial
- 10:37 · ROW · NEWS 10:37 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: MUTHOOTFIN, MANAPPURAM / can go DOWN: KALYANKJIL · GO NOW only if MUTHOOTFIN above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel
- 10:40 · ROW · NEWS 10:40 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: LUPIN / can go DOWN: - · GO NOW only if LUPIN above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narr
- 11:03 · ROW · NEWS 11:03 · TV CNBC-TV18 (speech-to-text) · NEW · UNVERIFIED - TV ONLY -> can go UP: - / can go DOWN: VEDL · GO NOW only if VEDL below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope 
- 11:11 · ROW · NEWS 11:11 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: PAYTM · GO NOW only if PAYTM below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narr
- 11:36 · ROW · NEWS 11:36 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: NHPC / can go DOWN: - · GO NOW only if NHPC above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrow
- 11:53 · ROW · NEWS 11:53 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: EICHERMOT / can go DOWN: - · GO NOW only if EICHERMOT above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / sc
- 12:01 · ROW · NEWS 12:01 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: BAJFINANCE, SHRIRAMFIN, PAYTM, CHOLAFIN, JIOFIN, PFC (sector nbfc & finance) · GO NOW only if BAJFINANCE below first-seen price by
- 12:17 · ROW · NEWS 12:17 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: BIOCON / can go DOWN: - · GO NOW only if BIOCON above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope na
- 12:32 · ROW · NEWS 12:32 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: TATASTEEL · GO NOW only if TATASTEEL below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope nar
- 13:05 · ROW · NEWS 13:05 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: VEDL · GO NOW only if VEDL below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrow
- 13:14 · ROW · NEWS 13:14 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: ADANIPOWER, POWERGRID, ADANIGREEN, NTPC, TATAPOWER, ADANIENSOL / can go DOWN: - (sector power) · GO NOW only if ADANIPOWER above first-seen price b
- 13:18 · ROW · NEWS 13:18 · WIRE · NEW · VERIFIED -> can go UP: POLYCAB / can go DOWN: - · GO NOW only if POLYCAB above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrower
- 13:27 · ROW · NEWS 13:27 · WIRE · NEW · UNVERIFIED (one source, class B) -> can go UP: - / can go DOWN: MUTHOOTFIN · GO NOW only if MUTHOOTFIN below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope n
- 13:32 · ROW · NEWS 13:32 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: VEDL, HINDZINC · GO NOW only if VEDL below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / sc
- 13:44 · ROW · NEWS 13:44 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: IDEA / can go DOWN: - · GO NOW only if IDEA above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrow
- 13:47 · ROW · NEWS 13:47 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: INOXWIND · GO NOW only if INOXWIND below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scop
- 14:23 · ROW · NEWS 14:23 · GOOGLE NEWS · NEW · VERIFIED -> can go UP: TCS / can go DOWN: - · GO NOW only if TCS above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narrower
- 14:28 · ROW · NEWS 14:28 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: AMBER · GO NOW only if AMBER below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narr
- 14:49 · ROW · NEWS 14:49 · WIRE · NEW · UNVERIFIED (one source, class C) -> can go UP: ASHOKLEY / can go DOWN: - · GO NOW only if ASHOKLEY above first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope narro
- 14:52 · ROW · NEWS 14:52 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: POWERINDIA, HAL, BEL, BHEL, CUMMINSIND, GVT&D / can go DOWN: - (sector capital goods) · GO NOW only if POWERINDIA above first-seen price by 
- 15:02 · ROW · NEWS 15:02 · GOOGLE NEWS · NEW · UNVERIFIED (one source, class C) -> can go UP: - / can go DOWN: FORTIS · GO NOW only if FORTIS below first-seen price by 0.3 ATR with RVOL5 3x within 10 min · cancel if: denial / scope na
