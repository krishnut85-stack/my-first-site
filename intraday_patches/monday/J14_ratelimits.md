# J14 KITE RATE LIMITS AT COLD START - Mon 23 Nov 07:40-09:30 (per key, per second)

Limits: Kite Connect v3 docs, Exceptions page (kite.trade/docs/connect/v3/exceptions, read 21 Nov 2026): Quote 1 req/s, Historical candle 3 req/s, Order placement 10 req/s, all other endpoints 10 req/s. The page does not say whether a limit is per API key or per user; GIR's four keys are four apps on ONE Zerodha user - the model counts per key, the live 08:30-09:30 check must watch for 429 'Too many requests' on any key.

Model: every caller's own code constants, worst-case phases (every loop starts on the same second); `python3 -m analyst.j14ratelimits`. Not a live trace.

## BEFORE (each process spaces only itself)

| key | endpoint | calls 07:40-09:30 | max per second | limit | seconds over | first burst |
|---|---|---|---|---|---|---|
| 1 | historical | 1 | 1 | 3 | 0 | - |
| 1 | other | 328 | 3 | 10 | 0 | - |
| 1 | quote | 423 | 2 | 1 | 61 | 09:15:00 futlive quote + seclive ohlc |
| 2 | other | 3 | 2 | 10 | 0 | - |
| 2 | quote | 1402 | 1 | 1 | 0 | - |
| 3 | other | 7 | 2 | 10 | 0 | - |
| 3 | quote | 1642 | 1 | 1 | 0 | - |
| 4 | historical | 4 | 3 | 3 | 0 | - |
| 4 | other | 3 | 2 | 10 | 0 | - |
| 4 | quote | 379 | 2 | 1 | 1 | 09:15:00 kquote + optdec |

## AFTER (intraday/kiterl.py: one spacer per key + endpoint across processes; quote 1.05 s, historical 0.34 s, other 0.11 s)

| key | endpoint | calls | max per second | limit | seconds over |
|---|---|---|---|---|---|
| 1 | historical | 1 | 1 | 3 | 0 |
| 1 | other | 328 | 3 | 10 | 0 |
| 1 | quote | 423 | 1 | 1 | 0 |
| 2 | other | 3 | 2 | 10 | 0 |
| 2 | quote | 1402 | 1 | 1 | 0 |
| 3 | other | 7 | 2 | 10 | 0 |
| 3 | quote | 1642 | 1 | 1 | 0 |
| 4 | historical | 4 | 3 | 3 | 0 |
| 4 | other | 3 | 2 | 10 | 0 |
| 4 | quote | 379 | 1 | 1 | 0 |

## Bursts found and fixed
- KEY 1 quote: seclive (ohlc every 3 s) + futlive (2 quote calls every 15 s) land in the same second from 09:15 - 61 seconds over 1 req/s in the worst-case model.
- KEY 4 quote: gir-v2kq (every 5 s) + gir-v2optdec (5 calls 2 s apart at 09:15 and every 15 min) - same second at 09:15:00.
- FIX: NEW intraday/kiterl.py - one file-lock spacer per key + endpoint across processes (/dev/shm/gir_kiterl_<key>_<class>), fail-open; a one-line
  _rl(key) before every Kite quote call in seclive.py, futlive.py, kitelogin.py (check quote + room-bars probe), v2/feeds/kquote.py, v2/recorders/optdec.py,
  v2/feeds/optquote.py (3 sites), v2/recorders/wsrec.py, and models/predict.py kite_bars (historical). Backups .bak1731k. Services restarted 17:35 IST Sat:
  gir-seclive, gir-futlive, gir-v2kq, gir-v2optdec, gir-v2opt, gir-v2wsrec, gir-v2desk.

## Calls per source (07:40-09:30, model)
- 07:40 kitelogin login: keys 1-4, 35 s apart, session + profile (other endpoints).
- 08:20 check: per key profile + quote; a failed key retried after 60 s; his account (positions, orders, margins on the first OK key, other endpoints);
  the room-bars probe (1 historical call on key 4, then key 1, 0.5 s apart). Retries 08:25 / 08:35 / 08:45: failed keys only.
- pnlwatch key 1: margins + holdings every 30 min before 09:15; positions every 3 s + margins every 60 s from 09:15 (other endpoints, well under 10/s).
- wsrec key 2 from 08:55: 2 quote calls per 3 s (1.1 s apart). optquote key 3 from 09:00: 1 quote per 1.1 s. kquote key 4 from 08:59: 1 per 5 s.
- room_live: at most one historical call per GO card (key 4 or 1, >= 0.4 s apart); instrument lists (api.kite.trade/instruments) are public files, not keyed calls.

## Not modelled - for the coordinator
- globaleye (gir.py, ~80 Kite REST call sites on key 1) is disabled but root's crontab line '25 3 * * * systemctl restart globaleye' STARTS it daily at
  08:55 IST - it ran on Fri 20. If it runs Monday it adds unspaced key-1 quote / ltp calls on top of seclive + futlive (it does not use kiterl.py).
  Decide: keep it, or remove that cron line for Monday.
- gir-intraday (engine2) is paused Sun 21:00 by gir-cpu-option-a (the trader's decision); if it runs, it is another unspaced key 1-4 user.
- dashserve (gir-dash) makes Kite calls only on page requests.
- LIVE CHECK Monday 08:30-09:30: grep every feed log for '429' / 'Too many requests' (kquote.log, optquote.log, wsrec.log, optdec.log, seclive, futlive,
  pnlwatch.log) and the J1 report; the Kite page does not say whether limits are per key or per user (four keys = one Zerodha user).
