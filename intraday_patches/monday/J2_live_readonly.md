# J2 - v2 feed + engine READ-ONLY on the live session, 2026-11-20

Made 2026-11-20 15:40 IST. Read-only: no rings, no Telegram, no orders. Machine numbers in J2_live_readonly.json (same folder).

## Summary

- **Feed:** one REST connection on key 2, polling 665 instruments every 3 s from 09:04:30 to 15:40. 0 quote errors, 0 gaps over 10 s (largest 3.8 s), 0 reconnects. On average 164 instruments changed per second, peaking at 190 at 09:16, and 660 of 665 instruments ticked each minute. **No websocket was used:** every key's 3 slots are taken by the live system. **09:00-09:04 pre-open is missing from this feed:** no key 2/3/4 token existed before the live engine's 09:04 login. It is covered only by v2rec preopen (30 s) and preopen_fast (10 s).
- **FULL fields:** 5-level depth on 98.3% of items (the maximum is 99.25%, because the 5 index rows carry none), OI on 100% of futures, average_price on 98.3% of traded items.
- **Rings the engine would have sent: 75, against the 50-a-day limit (OVER).** 66 of the 75 are CRITICAL rows: 45 are "TV call on X - CE/PE held off 60 min", 10 are OWN NEWS (the same Max Healthcare and Vedanta stories ringing again every few minutes), 5 are THESIS CANCELLED and 6 are stops, time stops or locks. **Without the TV hold-off rings the day would be 30 rings.** Only 9 are 15-min best ideas, 1 is a GO NOW (KALYANKJIL PE 09:45) and 4 are EXIT / BOOK HALF. One 15-min window went over 6: 10:30, with 7.
- **AI today (live ledger):** the v2 analyst made 173 calls costing $0.18; the v2 news reader $2.38; all GIR parts $6.36.
- **December options:** gir-v2optdec, 2,160 contracts every 15 min from 09:34 to 15:24, 0 errors. The A5 check found the December chains LIVE in the store.
- **Test observer on the live day (scored after the close):** of 39 movers past 3%, 12 were in time, 12 late and 15 missed, including INDUSINDBK +8.7%. Flags: NEWS DIRECTION WRONG 40, NOISE 4.
- **Live page:** 11 of 787 market-hour samples were >= 1 s (worst 3.9 s). These are not from J2: the recorders used about 3.5% of one CPU, while the box ran at load average about 6 on 4 CPUs (dashserve and engine2 each at 100%).

## 1. Feed: how it was read

- **No websocket was opened.** Every Kite key's 3 websocket slots are taken by the live system (19 / 20 Nov engine log: key 2 = ws2 + x2b + x2c, key 3 = x3a-c, key 4 = x4a-c standby; key 1 = engine2 main + globaleye V101A + newshawk tape + optionwatch). A 4th connection would be refused or would block a live socket's reconnect, so the recorder used **Kite REST quote()** instead, which returns the same fields as FULL mode (5-level depth, OI, average_price, exchange timestamp, last trade time).
- Connection: REST on key 2 (today's token from the live engine's own 09:04 login; one profile() check; never logs in), 665 instruments (218 F&O spot + 442 near / next futures (IEX, IREDA have only Nov) + NIFTY / BANKNIFTY / FINNIFTY / MIDCPNIFTY spot + futures + INDIA VIX), 2 calls every 3 s.
- Recording: 09:05 to 15:40 IST, 396 minutes. **09:00-09:04:30 is NOT in the REST file**: no key 2 / 3 / 4 token for 20 Nov existed before the live engine logged key 2 in at 09:04 (keys 3 / 4 at 09:21-09:22); key 1 was not used so as not to load the live system's own key.

## 2. Rates (one REST connection)

| measure | value |
|---|---|
| items polled per s (avg) | 221.6 |
| items that CHANGED per s (avg) - the REST equivalent of ticks/s | 164.1 |
| peak changed per s (minute) | 190.2 at 09:16 |
| instruments ticking per minute (avg of 665) | 659.8 |
| quote errors | 0 |
| largest gap between good polls | 3.8 s |
| gaps > 10 s | 0  |
| reconnects | 0 (REST: none apply) |

09:15-09:20 burst (per minute):

| min | polled/s | changed/s | ticking | errors | max gap s |
|---|---|---|---|---|---|
| 09:15 | 220.5 | 32.7 | 497 | 0 | 3.1 |
| 09:16 | 221.6 | 190.2 | 665 | 0 | 3.1 |
| 09:17 | 221.4 | 161.3 | 665 | 0 | 3.2 |
| 09:18 | 222.3 | 166.1 | 665 | 0 | 3.1 |
| 09:19 | 221.1 | 164.2 | 665 | 0 | 3.2 |

Per minute: the `per_minute` list in the JSON (also girdata/rec/2026-11-20/wsrec_stats.jsonl). Note a REST poll sees at most one state per instrument every 3 s; a websocket would show every exchange tick, so ticks/s here is a floor, not the true tick rate.

## 3. FULL-mode proof (share of polled items carrying the field)

| field | share |
|---|---|
| 5-level depth (buy + sell, a price > 0) | 0.9827 (the 5 index / VIX rows never carry depth: 660 / 665 = 0.9925 is the maximum) |
| OI on futures items | 1.0 |
| average_price > 0 on shares + futures | 0.983 (0 before the first trade: pre-open minutes pull it down) |

## 4. Rings the engine WOULD have sent (it sent none)

**75 rings** today vs the limit of 50 a day (OVER). Limit 6 per 15 min: windows over it: {'10:30': 7}.

By kind: {'15-min best idea': 9, 'CRITICAL': 66, 'GO NOW': 1, 'EXIT / BOOK HALF': 4}

Per hour: {'08': 4, '09': 12, '10': 12, '11': 17, '12': 8, '13': 9, '14': 9, '15': 4}

Per 15 min: {'08:45': 4, '09:00': 3, '09:15': 3, '09:30': 4, '09:45': 2, '10:00': 1, '10:15': 2, '10:30': 7, '10:45': 2, '11:00': 6, '11:15': 4, '11:30': 5, '11:45': 2, '12:00': 3, '12:30': 2, '12:45': 3, '13:00': 6, '13:30': 2, '13:45': 1, '14:00': 3, '14:15': 1, '14:30': 3, '14:45': 2, '15:00': 3, '15:15': 1}

| time | share | side | action | lane | why |
|---|---|---|---|---|---|
| 08:45 | RELIANCE | PE | NOTHING | CRITICAL | TV BUY call on RELIANCE at 08:09 - PE on it held off 60 min |
| 08:45 | RELIANCE | CE | NOTHING | CRITICAL | TV SELL call on RELIANCE at 08:09 - CE on it held off 60 min |
| 08:45 | COALINDIA | CE | NOTHING | CRITICAL | TV SELL call on COALINDIA at 08:29 - CE on it held off 60 min |
| 08:45 | PAYTM | CE | NOTHING | CRITICAL | TV SELL call on PAYTM at 08:45 - CE on it held off 60 min |
| 09:08 | RELIANCE | PE | NOTHING | CRITICAL | TV BUY call on RELIANCE (Motilal) at 09:08 - PE on it held off 60 min |
| 09:09 | BANKBARODA | PE | NOTHING | CRITICAL | TV BUY call on BANKBARODA (Motilal) at 09:09 - PE on it held off 60 min |
| 09:10 | BANKBARODA | CE | NOTHING | CRITICAL | TV SELL call on BANKBARODA at 09:09 - CE on it held off 60 min |
| 09:15 | THESIS | CE | CANCEL | CRITICAL | THESIS CANCELLED: 19:45 line 'CE JEWELLERS' at 09:15 - basket -2.42% (2 shares, 100% the wrong way); leaders TITAN -2.33% / 19:45 line 'CE CABLES' at  |
| 09:15 | BANKINDIA | PE | NOTHING | CRITICAL | TV BUY call on BANKINDIA (Goldman) at 08:20 - PE on it held off 60 min |
| 09:20 | THESIS | PE | CANCEL | CRITICAL | THESIS CANCELLED: 19:45 line 'PE AUTOS' at 09:20 - basket +0.82% (1 shares, 100% the wrong way); leaders BAJAJ-AUTO +0.82% · their calls are stopped |
| 09:30 | HINDPETRO | PE | GET READY | MUST SEE | rings: best new idea of the 09:15 window (AI routine-tier model ranked it first of 8; 8 new) |
| 09:33 | VEDL | PE | GET READY | CRITICAL | OWN NEWS DOWN - Vedanta share price target cut by its biggest bear - Here's are the concerns highlighted (08:43) · LEADER (DIVERGENT on its own news ( |
| 09:36 | VEDL | PE | GET READY | CRITICAL | OWN NEWS DOWN - Vedanta share price target cut by its biggest bear - Here's are the concerns highlighted (08:43) · LEADER (DIVERGENT on its own news ( |
| 09:39 | VEDL | PE | GET READY | CRITICAL | OWN NEWS DOWN - Vedanta share price target cut by its biggest bear - Here's are the concerns highlighted (08:43) · LEADER (DIVERGENT on its own news ( |
| 09:45 | KALYANKJIL | PE | GO NOW | MUST SEE | rings: best new idea of the 09:30 window (AI routine-tier model ranked it first of 4; 4 new) |
| 09:54 | THESIS | PE | CANCEL | CRITICAL | THESIS CANCELLED: 19:45 line 'PE ELECTRONICS' at 09:54 - basket +0.53% (1 shares, 100% the wrong way); leaders SYRMA +0.53% · their calls are stopped |
| 10:00 | INFY | CE | GET READY | MUST SEE | rings: best new idea of the 09:45 window (AI routine-tier model ranked it first of 4; 4 new) |
| 10:15 | COFORGE | CE | GET READY | MUST SEE | rings: best new idea of the 10:00 window (AI routine-tier model ranked it first of 6; 6 new) |
| 10:27 | THESIS | CE | CANCEL | CRITICAL | THESIS CANCELLED: 19:45 line 'CE OIL PRODUCERS' at 10:27 - basket -0.54% (1 shares, 100% the wrong way); leaders ONGC -0.54% · their calls are stopped |
| 10:30 | PERSISTENT | CE | GET READY | MUST SEE | rings: best new idea of the 10:15 window (AI routine-tier model ranked it first of 5; 5 new) |
| 10:31 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 10:31 - PE on it held off 60 min |
| 10:31 | APOLLOHOSP | CE | NOTHING | CRITICAL | TV SELL call on APOLLOHOSP (Macquarie) at 10:31 - CE on it held off 60 min |
| 10:31 | VEDL | CE | NOTHING | CRITICAL | TV SELL call on VEDL (Macquarie) at 10:31 - CE on it held off 60 min |
| 10:32 | VEDL | PE | NOTHING | CRITICAL | TV BUY call on VEDL (HSBC) at 10:32 - PE on it held off 60 min |
| 10:42 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 10:42 - PE on it held off 60 min |
| 10:42 | MAXHEALTH | PE | NOTHING | CRITICAL | TV BUY call on MAXHEALTH (Macquarie) at 10:42 - PE on it held off 60 min |
| 10:45 | PERSISTENT | CE | GET READY | MUST SEE | rings: best new idea of the 10:30 window (AI routine-tier model ranked it first of 3; 3 new) |
| 10:45 | VEDL | CE | NOTHING | CRITICAL | TV SELL call on VEDL (Citi) at 10:45 - CE on it held off 60 min |
| 11:02 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 11:02 - PE on it held off 60 min |
| 11:03 | TCS | CE | NOTHING | CRITICAL | TV SELL call on TCS (Macquarie) at 11:02 - CE on it held off 60 min |
| 11:03 | VEDL | CE | NOTHING | CRITICAL | TV SELL call on VEDL (Macquarie) at 11:03 - CE on it held off 60 min |
| 11:07 | HDFCBANK | PE | NOTHING | CRITICAL | TV BUY call on HDFCBANK (Macquarie) at 11:06 - PE on it held off 60 min |
| 11:09 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:12 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:15 | RVNL | PE | GET READY | MUST SEE | rings: best new idea of the 11:00 window (rules: highest rank score; 1 new) |
| 11:15 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:19 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:22 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:30 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:30 | MAXHEALTH | CE | GET READY | MUST SEE | rings: best new idea of the 11:15 window (AI routine-tier model ranked it first of 2; 2 new) |
| 11:36 | COFORGE | PE | NOTHING | CRITICAL | TV BUY call on COFORGE at 11:36 - PE on it held off 60 min |
| 11:38 | MAXHEALTH | CE | GET READY | CRITICAL | OWN NEWS UP - Max Healthcare Jumps - Stock Stats / Max Healthcare Institute shares rose over 4.3% at market open.G (10:22) · LEADER (DIVERGENT on its  |
| 11:41 | UNIONBANK | PE | EXIT | CRITICAL | stop hit: UNIONBANK 214.70 vs stop 209.17 (v2 call 09:21) · Kite: MODIFY SL-L -> LIMIT bid - 1 tick (fallback: cancel, then sell) |
| 11:45 | PERSISTENT | CE | GET READY | MUST SEE | rings: best new idea of the 11:30 window (AI routine-tier model ranked it first of 2; 2 new) |
| 11:47 | LOCK |  | NOTHING | CRITICAL | PROFIT LOCK: day P&L hidden (give-back of the peak; amounts not shown) (rule: stop at 40%) |
| 12:06 | TATAELXSI | PE | NOTHING | CRITICAL | TV BUY call on TATAELXSI (Macquarie) at 12:05 - PE on it held off 60 min |
| 12:06 | COFORGE | CE | NOTHING | CRITICAL | TV SELL call on COFORGE (Macquarie) at 12:06 - CE on it held off 60 min |
| 12:10 | MAXHEALTH | PE | NOTHING | CRITICAL | TV BUY call on MAXHEALTH (Macquarie) at 12:10 - PE on it held off 60 min |
| 12:31 | PERSISTENT | CE | NOTHING | CRITICAL | TV SELL call on PERSISTENT at 12:31 - CE on it held off 60 min |
| 12:33 | FEDERALBNK | PE | NOTHING | CRITICAL | TV BUY call on FEDERALBNK at 12:33 - PE on it held off 60 min |
| 12:53 | BANKNIFTY | PE | HOLD | CRITICAL | BANKNIFTY on the right side of VWAP, sector not tracked |
| 12:57 | CUB | PE | NOTHING | CRITICAL | TV BUY call on CUB at 12:29 - PE on it held off 60 min |
| 12:57 | RVNL | PE | NOTHING | CRITICAL | TV BUY call on RVNL (Motilal) at 12:46 - PE on it held off 60 min |
| 13:03 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 13:03 - PE on it held off 60 min |
| 13:04 | KALYANKJIL | CE | NOTHING | CRITICAL | TV SELL call on KALYANKJIL (Macquarie) at 13:03 - CE on it held off 60 min |
| 13:04 | MUTHOOTFIN | CE | NOTHING | CRITICAL | TV SELL call on MUTHOOTFIN (Macquarie) at 13:04 - CE on it held off 60 min |
| 13:05 | HDFCBANK | PE | NOTHING | CRITICAL | TV BUY call on HDFCBANK (Kotak) at 13:05 - PE on it held off 60 min |
| 13:08 | COFORGE | PE | NOTHING | CRITICAL | TV BUY call on COFORGE (Kotak) at 13:08 - PE on it held off 60 min |
| 13:13 | MOTILALOFS | PE | EXIT | CRITICAL | premium stop hit: 40.40 <= 52.70 · Kite: MODIFY SL-L -> LIMIT bid - 1 tick (fallback: cancel, then sell) |
| 13:32 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 13:32 - PE on it held off 60 min |
| 13:43 | BANKNIFTY | PE | EXIT | CRITICAL | time stop: 50 min without +0.5R (R not known: P&L not above zero) · Kite: MODIFY SL-L -> LIMIT bid - 1 tick (fallback: cancel, then sell) |
| 13:53 | GODREJPROP | PE | NOTHING | CRITICAL | TV BUY call on GODREJPROP (Motilal) at 12:47 - PE on it held off 60 min |
| 14:05 | YESBANK | PE | NOTHING | CRITICAL | TV BUY call on YESBANK at 14:05 - PE on it held off 60 min |
| 14:10 | HDFCBANK | PE | EXIT | CRITICAL | premium stop hit: 13.05 <= 22.96 · Kite: MODIFY SL-L -> LIMIT bid - 1 tick (fallback: cancel, then sell) |
| 14:10 | THESIS | PE | CANCEL | CRITICAL | THESIS CANCELLED: 19:45 line 'PE METALS' at 14:10 - basket +1.19% (2 shares, 100% the wrong way); leaders HINDALCO +1.90%, JINDALSTEL +0.48% · their c |
| 14:28 | APOLLOHOSP | PE | NOTHING | CRITICAL | TV BUY call on APOLLOHOSP (Macquarie) at 14:27 - PE on it held off 60 min |
| 14:32 | ITC | PE | NOTHING | CRITICAL | TV BUY call on ITC (Macquarie) at 14:32 - PE on it held off 60 min |
| 14:33 | ITC | CE | NOTHING | CRITICAL | TV SELL call on ITC at 14:32 - CE on it held off 60 min |
| 14:35 | MAXHEALTH | PE | NOTHING | CRITICAL | TV BUY call on MAXHEALTH (Macquarie) at 14:35 - PE on it held off 60 min |
| 14:45 | HDFCBANK | CE | NOTHING | CRITICAL | TV SELL call on HDFCBANK at 14:44 - you HOLD it: bounce / drop risk, book or trail now |
| 14:57 | HDFCBANK | CE | NOTHING | CRITICAL | TV SELL call on HDFCBANK at 14:57 - you HOLD it: bounce / drop risk, book or trail now |
| 15:12 | NTPC | CE | NOTHING | CRITICAL | TV SELL call on NTPC at 15:11 - CE on it held off 60 min |
| 15:13 | MAXHEALTH | PE | NOTHING | CRITICAL | TV BUY call on MAXHEALTH at 15:13 - PE on it held off 60 min |
| 15:13 | MAXHEALTH | CE | NOTHING | CRITICAL | TV SELL call on MAXHEALTH at 15:13 - CE on it held off 60 min |
| 15:16 | ITC | PE | NOTHING | CRITICAL | TV BUY call on ITC at 15:16 - PE on it held off 60 min |

Engine rows today: 2794 (published 206); actions {'NOTHING': 1857, 'CANCEL': 5, 'GET READY': 922, 'GO NOW': 5, 'EXIT': 4, 'HOLD': 1}. GO NOW rows: 5; CRITICAL rows: 66.

## 5. AI calls and cost today (live ledger intraday/data/aispend.json)

- v2 analyst (the engine): {'calls': 173, 'usd': 0.17758000000000002}
- all v2 parts: {'v2 news reader': {'calls': 2260, 'usd': 2.37649}, 'v2 analyst': {'calls': 173, 'usd': 0.17758000000000002}}
- all GIR parts today: $6.3646
- engine raw AI log rows (v2/data/ai_raw.jsonl): 173 by kind {'triage': 146, 'second': 15, 'rank': 8, 'final': 4}, by model {'routine-tier model': 169, 'top-tier final model': 4}
- engine AI status: {'enabled': True, 'mode': 'live', 'part': 'v2 analyst', 'run_usd': 0.0, 'run_cap': None, 'calls': 0, 'errors': 0, 'model': None, 'models': [], 'chain': {'triage': 'routine-tier model', 'final': 'final-tier model'}, 'since': '20 Nov 15:38', 'why_off': None}

## 6. December options recorder (desk ask 09:25)

- gir-v2optdec, key 4, 24 refreshes 09:34:29-15:24:22, 2160 contracts each (216 shares x ATM +-2 x CE / PE; IEX, IREDA have no December chain), 120 calls, 0 errors, fewest returned 2160.
- A5 check (store vs recorder vs direct Kite, 5 shares): girdata/review/monday/A5_dec_chain_check.md - December chains are LIVE in the store.

## 6b. Test observer on the LIVE day (scored after the close)

gir-v2testobs only watches playback / test folders (girdata/replay/out), **not the live engine**, so today's live rows were not scored during the day. I did not change it: its scorecards are pushed automatically by gir-v2reviewpush. Instead, after 15:40, the day's live rows (206 published, 2,588 silent, 173 AI answers; copied to girdata/rec/2026-11-20/live_engine_src/) were scored with `observer.py --once`. The output is in girdata/review/monday/J2_testobs/LIVE_2026-11-20/scorecard.md.

- Movers past 3%: 39. The engine was in time on 12, late on 12 and missed 15. Missed include INDUSINDBK +8.7% (crossed 09:46), CUB +6.6%, AXISBANK +4.9%, UNIONBANK +4.3%, ANGELONE and MARUTI.
- Flags: MISSED MOVER 27, NEWS DIRECTION WRONG 40, NOISE 4 (the ring counts).
- The AI decided 917 of 917 rows.

## 7. Gaps, errors, the live page - honestly

- girtrader.com (gir-v2pagewatch, market hours): 787 samples, max 3.935 s; samples >= 1 s: [{'t': '11:21:03', 's': 3.568, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '12:36:22', 's': 3.228, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '12:42:26', 's': 1.021, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '12:58:29', 's': 1.021, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '13:05:01', 's': 1.517, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '13:12:34', 's': 1.096, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '14:20:25', 's': 3.935, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '14:51:30', 's': 1.032, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '14:55:33', 's': 1.556, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '15:00:35', 's': 1.868, 'url': 'https://girtrader.com/login', 'code': 200}, {'t': '15:18:39', 's': 1.128, 'url': 'https://girtrader.com/login', 'code': 200}]
- recorder log problems: ['2026-11-20 08:55:10 REST: no usable key yet (key 2: no token for 2026-11-20 yet; key 4: no token for 2026-11-20 yet; key 3: no token for 2026-11-20 yet) - checking every 20 s; kquote / v2rec still rec', '2026-11-20 15:40:01 REST mode stopped (0 gaps, 0 errors)']
- December recorder problems: none (24 refreshes, 120 calls, 0 errors; every refresh returned 2160 of 2160)
- kquote log problems today: ['2026-11-20 09:22:08 key 4 token of 2026-11-20 in use']
- engine log errors today (5 lines, all 'step failed (1)' reading the v2 store at 127.0.0.1:8100 - IncompleteRead / RemoteDisconnected; the next 10-s step ran): 13:35:11 step failed (1): IncompleteRead: IncompleteRead(2565888 bytes read, 25; 14:10:02 step failed (1): RemoteDisconnected: Remote end closed connection with; 14:45:12 step failed (1): RemoteDisconnected: Remote end closed connection with; 15:38:36 AI analyst: {"enabled": true, "mode": "live", "part": "v2 analyst", "r; 15:38:52 AI analyst: {"enabled": true, "mode": "live", "part": "v2 analyst", "r

## 8. 09:00-09:30 raw frames kept (for J9 / J4 on Saturday)

| file | rows 09:00-09:30 | first | last |
|---|---|---|---|
| engine_state.jsonl.gz | 30 | 09:00:53 | 09:29:54 |
| kquote.jsonl.gz | 91 | 09:22:14 | 09:29:59 |
| preopen_fast.jsonl.gz | 20 | 09:00:13 | 09:19:14 |
| preopen.jsonl.gz | 12 | 09:00:00 | 09:10:30 |
| quotes.jsonl.gz | 16 | 09:10:00 | 09:29:00 |
| rest_full.09.jsonl.gz | 186215 | 09:04:30 |  |

## 9. Raw files

| path | bytes |
|---|---|
| /home/globalbot/girdata/rec/2026-11-20/board.jsonl.gz | 2049507 |
| /home/globalbot/girdata/rec/2026-11-20/engine_state.jsonl.gz | 11610142 |
| /home/globalbot/girdata/rec/2026-11-20/futoi.jsonl.gz | 4882262 |
| /home/globalbot/girdata/rec/2026-11-20/heartbeat.jsonl.gz | 122645 |
| /home/globalbot/girdata/rec/2026-11-20/kquote.jsonl.gz | 13097961 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.09.jsonl.gz | 582327 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.10.jsonl.gz | 1189297 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.11.jsonl.gz | 1196580 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.12.jsonl.gz | 1200168 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.13.jsonl.gz | 1203751 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.14.jsonl.gz | 1203208 |
| /home/globalbot/girdata/rec/2026-11-20/opt_dec.15.jsonl.gz | 603001 |
| /home/globalbot/girdata/rec/2026-11-20/optdec_runs.jsonl | 8088 |
| /home/globalbot/girdata/rec/2026-11-20/preopen.jsonl.gz | 83341 |
| /home/globalbot/girdata/rec/2026-11-20/preopen_fast.jsonl.gz | 68930 |
| /home/globalbot/girdata/rec/2026-11-20/quotes.jsonl.gz | 6332561 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.09.jsonl.gz | 71684007 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.10.jsonl.gz | 92079275 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.11.jsonl.gz | 94181925 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.12.jsonl.gz | 94428097 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.13.jsonl.gz | 93734065 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.14.jsonl.gz | 92971782 |
| /home/globalbot/girdata/rec/2026-11-20/rest_full.15.jsonl.gz | 44924108 |
| /home/globalbot/girdata/rec/2026-11-20/sectors.jsonl.gz | 303623 |
| /home/globalbot/girdata/rec/2026-11-20/strikes.jsonl.gz | 32626318 |
| /home/globalbot/girdata/rec/2026-11-20/wsrec_instruments.json | 57932 |
| /home/globalbot/girdata/rec/2026-11-20/wsrec_stats.jsonl | 102098 |
