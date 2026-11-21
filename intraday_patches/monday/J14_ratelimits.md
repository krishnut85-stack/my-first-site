# J14 KITE RATE LIMITS AT COLD START - Mon 23 Nov 07:40-09:30 (per key, per second)

Limits: Kite Connect v3 docs, Exceptions page (kite.trade/docs/connect/v3/exceptions, read 21 Nov 2026): Quote 1 req/s, Historical candle 3 req/s, Order placement 10 req/s, all other endpoints 10 req/s. The page does not say whether a limit is per API key or per user; GIR's four keys are four apps on ONE Zerodha user - the model counts per key, the live 08:30-09:30 check must watch for 429 'Too many requests' on any key.

Model: every caller's own code constants, worst-case phases (every loop starts on the same second); `python3 -m analyst.j14ratelimits`. Not a live trace. Includes gir-intraday (engine2.py, kept ON by the 16:55 park): pre-open / open gap quotes, sector indices every 15 s, the index quote every 60 s, idxdesk.kick every 60 s (4 quote calls back to back), idxclose's 29 previous-close historical calls once a day; engine2's other Kite users (chains, flow, getdata top-up, enternow) are covered by the same spacer but not counted here.

## BEFORE (each process spaces only itself)

| key | endpoint | calls 07:40-09:30 | max per second | limit | seconds over | first burst |
|---|---|---|---|---|---|---|
| 1 | historical | 30 | 10 | 3 | 3 | 08:58:00 engine2 idxclose prev close |
| 1 | other | 328 | 3 | 10 | 0 | - |
| 1 | quote | 565 | 8 | 1 | 64 | 09:08:30 engine2 pre-open gap quotes |
| 2 | other | 3 | 2 | 10 | 0 | - |
| 2 | quote | 1402 | 1 | 1 | 0 | - |
| 3 | other | 7 | 2 | 10 | 0 | - |
| 3 | quote | 1642 | 1 | 1 | 0 | - |
| 4 | historical | 4 | 3 | 3 | 0 | - |
| 4 | other | 3 | 2 | 10 | 0 | - |
| 4 | quote | 379 | 2 | 1 | 1 | 09:15:00 kquote + optdec |

## AFTER (intraday/kiterl.py: one spacer per key + endpoint across processes; quote 1.05 s, historical 0.34 s, other 0.11 s)

| key | endpoint | calls | max per second | limit | seconds over | longest added wait (s) |
|---|---|---|---|---|---|---|
| 1 | historical | 30 | 3 | 3 | 0 | 6.7 |
| 1 | other | 328 | 3 | 10 | 0 | 0.0 |
| 1 | quote | 565 | 1 | 1 | 0 | 7.3 |
| 2 | other | 3 | 2 | 10 | 0 | 0.0 |
| 2 | quote | 1402 | 1 | 1 | 0 | 0.0 |
| 3 | other | 7 | 2 | 10 | 0 | 0.0 |
| 3 | quote | 1642 | 1 | 1 | 0 | 0.0 |
| 4 | historical | 4 | 3 | 3 | 0 | 0.0 |
| 4 | other | 3 | 2 | 10 | 0 | 0.0 |
| 4 | quote | 379 | 1 | 1 | 0 | 1.1 |

## engine2's TICK LOOP (non-blocking spacer, coordinator 21 Nov)

engine2's trade_loop thread (sector indices every 15 s, index quote every 60 s, idxclose) runs the spacer in NON-BLOCKING mode: a wait longer than 1.5 s raises kiterl.Busy, the loop's own try / except skips that round and tries on the next tick. Background threads (idxdesk, enternow, gap quotes, chains, other processes) keep waiting.

| measure (07:40-09:30 model, worst case) | value |
|---|---|
| longest block of the tick loop | 1.50 s (limit 1.5 s) |
| tick-loop rounds skipped (retried next tick) | 48 |
| longest wait of a background call | 6.2 s |
| longest delay of the idxclose prev close round (skips retried after 5 s) | 1.5 s |
| longest delay of the index quote round (skips retried after 5 s) | 20.1 s |
| longest delay of the sector indices round (skips retried after 5 s) | 0.0 s |

idxclose's daily candles are asked only outside 09:00-15:30 (in session it takes the quote's own close): a skipped call there falls back to the tick feed's close and is asked again after 10 min (its own rule).

## Bursts found and fixed
- KEY 1 quote: gir-intraday (engine2.py - kept ON by the 16:55 park: the page reads its quotes_live.json / pins_live.json) + seclive (ohlc every 3 s) +
  futlive (2 calls every 15 s). engine2 alone sends calls back to back: 2 pre-open gap batches 09:08:30, 2 pre-open news batches 09:09, 2 open gap
  batches 09:15:05, the sector indices every 15 s, the index quote every 60 s, idxdesk.kick 4 calls every 60 s - up to 8 calls in one second.
- KEY 1 historical: engine2's idxclose.prev_close - 29 previous-close calls (25 sector + 4 index) back to back once a day (10 in one second; limit 3).
- KEY 4 quote: gir-v2kq (every 5 s) + gir-v2optdec (5 calls 2 s apart at 09:15 and every 15 min) in the same second at 09:15:00.
- FIX 1 (17:31): NEW intraday/kiterl.py - one file-lock spacer per key + endpoint across processes (/dev/shm/gir_kiterl_<key>_<class>), fail-open,
  longest wait 10 s; a one-line _rl(key) before every Kite quote call in seclive.py, futlive.py, kitelogin.py (check quote + room-bars probe),
  v2/feeds/kquote.py, v2/recorders/optdec.py, v2/feeds/optquote.py (3 sites), v2/recorders/wsrec.py, models/predict.py kite_bars (historical).
  Restarted 17:35 IST: gir-seclive, gir-futlive, gir-v2kq, gir-v2optdec, gir-v2opt, gir-v2wsrec, gir-v2desk.
- FIX 2 (17:39): kiterl.install() wraps EVERY KiteConnect REST method (quote / ohlc / ltp -> quote; historical_data -> historical; instruments,
  positions, orders, margins, holdings, profile, trades -> other) for the whole engine2 process - all threads and modules (the loop, idxdesk,
  idxclose, gap_thread, _preopen_news, chains, flow, getdata top-up, enternow ...); the key number comes from matching the api_key against the
  .env NAMES KITE_API_KEY / KITE2..4_API_KEY (the value is never printed or stored). engine2.py imports it at start (.bak1739e).
  gir-intraday RESTARTED 17:40:32 IST Saturday with /usr/local/bin/gir-restart (active, no traceback; old senders still muted 14 of 14).
- After both fixes the model shows 0 seconds over any limit. The 09:15 key-1 backlog peaks near 7 s (the spacer holds a call at most 10 s).

## Calls per source (07:40-09:30, model)
- 07:40 kitelogin login: keys 1-4, 35 s apart, session + profile (other endpoints).
- 08:20 check: per key profile + quote; a failed key retried after 60 s; his account (positions, orders, margins on the first OK key); the room-bars
  probe (1 historical call on key 4, then key 1). Retries 08:25 / 08:35 / 08:45: failed keys only.
- pnlwatch key 1: margins + holdings every 30 min before 09:15; positions every 3 s + margins every 60 s from 09:15 (other endpoints).
- wsrec key 2 from 08:55: 2 quote calls per 3 s (1.1 s apart). optquote key 3 from 09:00: 1 quote per 1.1 s. kquote key 4 from 08:59: 1 per 5 s.
- engine2 key 1 as listed above. room_live: at most one historical call per GO card. Instrument lists from api.kite.trade/instruments are public files.

## Websockets (the question asked)
- Kite allows 3 websocket connections per app (key). engine2 holds its main tick feed on key 1 and the ws2 / x2b / x2c, x3a-c, x4a-c feeds on keys 2-4.
  With globaleye (gir.py) parked and the newshawk tape / option watch not running, key 1's other slots are free; no other process opens a websocket
  on Monday (gir-v2wsrec runs in REST mode; the depth recorder is in 'tail' mode with ws_slot_free false). Websockets do not count against the REST
  limits. No conflict.

## Corrections (coordinator 21 Nov)
- globaleye cannot start Monday: parked 16:55 (stopped + disabled) and its 08:55 restart cron line is commented '#PARK1127'. (My first version of this
  file said otherwise - wrong.)
- gir-intraday is NOT paused Monday (the Sun 21:00 pause cron is disabled, '#PARKFIX1127'); it is now inside the model and spaced (fix 2).

## Live check Monday 08:30-09:30
- grep every feed log for '429' / 'Too many requests' (engine2 log, kquote.log, optquote.log, wsrec.log, optdec.log, seclive, futlive, pnlwatch.log).
- The Kite page does not say whether limits are per key or per user (the four keys are one Zerodha user); the counts above are per key.

## engine2 tick loop - no stall (coordinator 21 Nov, after fix 2)
- Which engine2 calls run in the tick-loop thread (trade_loop, the main thread): the sector indices quote (every 15 s), the index quote (every 60 s),
  idxclose.prev_close inside them (daily candles only outside 09:00-15:30; in session it uses the quote's own close - no call), and the REST
  prices of open paper trades only when the websocket feed is dead (slow mode). In their OWN threads: idxdesk.kick, enternow.kick, movealert
  (its own thread), gap_thread (pre-open / open / circuit quotes), the futures-OI baseline (_base), chain_worker (chains), the getdata top-up.
  bookpress (every 10 s) reads the websocket feed only.
- quotes_live.json is written by quotes_write(feed) from the WEBSOCKET ticks (feed.ltp / feed.pclose) in its own thread (focus_ticks_loop,
  ~1 s; the 'quotes246' catch-up thread after a late start) - never from REST, never from the tick-loop thread.
- FIX 3 (17:43): kiterl.set_nonblocking(1.5) for engine2's tick-loop thread (around both trade_loop calls): a Kite call there that would wait
  more than 1.5 s raises kiterl.Busy instead of waiting; the loop's own try / except skips that round and retries 5 s later (sidx / vix ticks
  reset, engine2.py .bak1743n). Background threads keep waiting. gir-intraday RESTARTED 17:47:19 IST via gir-restart.
- The table above: the tick loop never blocks more than 1.5 s; the index quote round is at most ~20 s late in the worst-case model.
