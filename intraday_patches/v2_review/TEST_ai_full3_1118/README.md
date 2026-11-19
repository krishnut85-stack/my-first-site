# Review bundle - test run TEST_ai_full3_1118

A playback (replay) of one past NSE trading day through the GIR v2 trading-ideas engine with the real AI. The engine gives ideas only
(stock options, CE = call / PE = put, intraday); it never places orders. Times are the REPLAYED day's clock (IST), not the time the test ran,
unless a field says "wall". Made by v2/testobs/review_export.py. Server paths are shown as `<server>/...`; long ids are replaced by
"[long id removed]". Nothing here is personal: no keys, no chat ids, no contact details and no data of the trader's own trading.

## Files
| file | what it is |
|---|---|
| calls.jsonl / calls.csv | one row per call the engine made (307 rows): every row outside the LOG lane plus every GO NOW / GET READY, in time order |
| ai_log.jsonl | every AI call of the run (115 rows): what was asked (short digest) and the raw answer |
| test_log.jsonl | the TEST OBSERVER's log (534 rows): every engine row and every AI call, with cost, latency and the outcome |
| flags.jsonl | the observer's flags, raised at the moment they became known on the replay clock |
| scorecard.json / scorecard.md | the observer's scorecard at the run's end (the .md is the same in plain words) |
| run_report.txt | the output of v2/engine/tools/run_report.py on this run (the engine builder's own score) |

## calls.jsonl / calls.csv fields
- day, t: replayed day and time HH:MM. s: the share (NSE F&O name). side: CE (expects the share up) or PE (down).
- action: GO NOW (enter now) / GET READY (be ready; enter at the trigger) / NOTHING (cancel or no call) / BOOK HALF / EXIT.
- lane: CRITICAL / MUST SEE (shown as a card, may ring the phone) / WATCH (list only) / LOG (not shown).
- lane_by: "AI <model>" = the AI chose the lane; "rules" = the engine's rules did. fallback_reason: why rules decided (gates, cancels and
  the critical lane are by design; "AI error", "AI budget cap", "no key / AI off", "no lane" mean the AI failed).
- strike, exp, series: the option suggested (strike may be empty = not chosen). setup, role, sector, sector_state: why the share was picked.
- trigger, stop, t1, t2: SHARE price levels (trigger = entry, stop = exit if wrong, t1 / t2 = targets). trigger_prem, stop_prem, t1_prem,
  t2_prem: the same levels as OPTION PREMIUMS when the engine had a premium (prem_basis says how); empty = not known.
- rr: reward / risk. ring: the phone would ring. publish: false = kept off the page.
- ai_check: the AI's last check on a GO NOW card (CONFIRM / WAIT / REJECT + reason + model). lane_why: the reason for the lane (AI or rules).
- reason: the engine's full why + the trigger text. wrong_if: what proves the idea wrong.
- o30, o60: the observer's outcome 30 and 60 replayed minutes after the call (or cut at the run's end): result RIGHT / WRONG / FLAT
  (the share moved the option's way / against it / under 0.15%), move_pct at the end of the window, max_fav_pct / max_adv_pct = the best and
  worst move the call's way inside the window, px0 / px = share price at the call and at the end. "from the open" = called before 09:15.
- early_late: on the day's 2%+ movers (v2/replay/score.py rule, whole day): BEFORE = called at or before the minute the move began; LATE =
  after; "WRONG way" = the share moved 2%+ the other way; "no 2% move" = it did not move 2% by the close.
- outcome_note: why a row has no outcome (a repeat of the same call is judged once, at its first row).

## ai_log.jsonl fields
at (wall clock IST when the call ended), day (replayed day), kind (triage = choose lanes for a batch of candidates; final = the GO NOW check;
second = second reading of a sector thesis / news direction; ask = a question), model, usage (tokens: in, out, cr = cache read, cw = cache
write), usd (cost in US dollars), stop_reason, ms (latency in milliseconds; "latency not logged" in runs before it was added), read (a
short digest of what the AI was shown, when logged), fallback / error (why there was no answer), text (the AI's answer, JSON).

## test_log.jsonl
type "decision" = one engine row: vt (time), s, side, decision (GO NOW / GET READY / nothing), lane, by (AI / rules), model, fallback_reason
and fallback_kind (by design / AI failure), read (what it read: sector state, news headline, why, trigger), usd (its share of the AI call
behind it), ms, repeat (true = same decision as the share's previous row), news_driven, o30 / o60 / early_late (as above).
type "ai" = one AI call (as ai_log, with its replayed time: from the engine row it decided, else estimated from its wall clock).

## flags.jsonl
MISSED MOVER (an F&O share crossed +-3% from the previous close with no CE / PE call that way in MUST SEE / CRITICAL or GO NOW /
GET READY by then); NOISE (more than 6 rings in 15 replayed minutes or 50 in the day); NEWS DIRECTION WRONG (a news-driven call the price
went 0.5% against in 30 / 60 min, or an AI second reading that called the direction wrong while the price went the thesis way); AI
FALLBACK (rules decided because the AI failed); COST SPIKE (one call over $0.05, over $0.50 in 10 wall minutes, or 80 / 95% of the
replay's $5 day / $20 run cap). vt = replayed time the flag became known.

## Prices and definitions
Share minutes from GIR's own data (Kite 1-minute candles, then the old system's minute files); previous close from Kite daily. 2%+ movers,
"began" and BEFORE / LATE / MISSED / WRONG are v2/replay/score.py's rules, the same as run_report.txt. Only the 218 F&O shares are used.
