# A5 - December chains read LIVE? (5 shares, ATM CE + PE, 2026-11-20)

Made 09:35 IST. Three readings of the same December (29 Dec) contracts: (1) the v2 store `oc.<SYM>` rows2 (gir-v2opt, Kite key 3 REST; per-contract time from v2/data/optquote.json exps[1]), (2) the new J2 December recorder gir-v2optdec (key 4, opt_dec.HH.jsonl.gz, last refresh), (3) one direct Kite quote() now (key 4, 09:35:36 IST). Read only.

**Result: YES - December chains are read LIVE.** All 10 contracts (5 shares, ATM CE + PE) are in the store with bid / ask / OI; gir-v2opt's quote for them was 8-102 s old (median about 30 s) against a direct Kite quote at 09:35:35. Store bid / ask equal the direct quote on SBIN, TATASTEEL, RELIANCE PE; HDFCBANK / INFY differ by a few ticks where the price moved in the 50-100 s between readings. OI store vs direct within 0-1.5% (INFY CE 7.8%: 104,400 vs 113,200 - the store reading was 51 s older, during a fast move). Gap: the store's rows2 carry no time per row (the engine cannot tell a stale December row from a fresh one without optquote.json).

| share | contract | source | bid | ask | LTP | OI | time (IST) |
|---|---|---|---|---|---|---|---|
| RELIANCE | RELIANCE26DEC1370CE | store oc rows2 (key 3) | 41.6 | 41.9 | 42.05 | 1334000 | 09:35:13 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 41.3 | 41.7 | 41.6 | 1330000 | exch 09:34:17, rx 09:34:26 |
| | | direct Kite now | 41.4 | 41.75 | 41.6 | 1335500 | exch 09:35:35 |
| RELIANCE | RELIANCE26DEC1370PE | store oc rows2 (key 3) | 40.8 | 41 | 40.95 | 1102000 | 09:35:05 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 41 | 41.2 | 40.75 | 1100500 | exch 09:34:24, rx 09:34:26 |
| | | direct Kite now | 41 | 41.2 | 41.15 | 1105500 | exch 09:35:35 |
| HDFCBANK | HDFCBANK26DEC830CE | store oc rows2 (key 3) | 23 | 23.1 | 23.4 | 2462850 | 09:34:42 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 23 | 23.1 | 23.15 | 2420600 | exch 09:34:19, rx 09:34:21 |
| | | direct Kite now | 23.15 | 23.35 | 24.2 | 2460250 | exch 09:35:34 |
| HDFCBANK | HDFCBANK26DEC830PE | store oc rows2 (key 3) | 27.6 | 27.8 | 27.15 | 1023750 | 09:34:42 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 27.6 | 27.8 | 27.25 | 1026350 | exch 09:34:17, rx 09:34:21 |
| | | direct Kite now | 27.2 | 27.4 | 26.3 | 1031550 | exch 09:35:34 |
| SBIN | SBIN26DEC1150CE | store oc rows2 (key 3) | 34.55 | 34.95 | 34.7 | 1853250 | 09:35:16 (store seen 09:35:06, state LIVE) |
| | | J2 recorder (key 4) | 34.55 | 34.7 | 34.45 | 1849500 | exch 09:34:20, rx 09:34:26 |
| | | direct Kite now | 34.55 | 34.95 | 34.5 | 1857750 | exch 09:35:34 |
| SBIN | SBIN26DEC1150PE | store oc rows2 (key 3) | 29.5 | 29.8 | 29.35 | 956250 | 09:35:16 (store seen 09:35:06, state LIVE) |
| | | J2 recorder (key 4) | 29.85 | 30.05 | 29.7 | 945000 | exch 09:34:22, rx 09:34:26 |
| | | direct Kite now | 29.5 | 29.8 | 29.45 | 956250 | exch 09:35:34 |
| INFY | INFY26DEC1114CE | store oc rows2 (key 3) | 45.05 | 45.35 | 45.65 | 104400 | 09:34:45 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 45.05 | 45.35 | 45.7 | 101600 | exch 09:34:15, rx 09:34:21 |
| | | direct Kite now | 46.25 | 46.7 | 47.4 | 113200 | exch 09:35:35 |
| INFY | INFY26DEC1114PE | store oc rows2 (key 3) | 43.85 | 44.5 | 44.2 | 57200 | 09:33:54 (store seen 09:35:05, state LIVE) |
| | | J2 recorder (key 4) | 43.85 | 44.5 | 44.2 | 57200 | exch 09:33:54, rx 09:34:21 |
| | | direct Kite now | 42.9 | 43.45 | 43.15 | 58000 | exch 09:35:31 |
| TATASTEEL | TATASTEEL26DEC177.5CE | store oc rows2 (key 3) | 6.01 | 6.12 | 6.07 | 525250 | 09:35:28 (store seen 09:35:35, state LIVE) |
| | | J2 recorder (key 4) | 5.94 | 6.04 | 5.9 | 522500 | exch 09:34:18, rx 09:34:26 |
| | | direct Kite now | 6.01 | 6.12 | 6.07 | 525250 | exch 09:35:34 |
| TATASTEEL | TATASTEEL26DEC177.5PE | store oc rows2 (key 3) | 6.64 | 6.73 | 6.74 | 836000 | 09:35:24 (store seen 09:35:35, state LIVE) |
| | | J2 recorder (key 4) | 6.73 | 6.82 | 6.86 | 825000 | exch 09:34:18, rx 09:34:26 |
| | | direct Kite now | 6.64 | 6.73 | 6.74 | 836000 | exch 09:35:34 |

## Verdict per contract

- RELIANCE CE RELIANCE26DEC1370CE: store has the row (age 23 s), recorder has it, OI store/direct 1334000/1335500
- RELIANCE PE RELIANCE26DEC1370PE: store has the row (age 31 s), recorder has it, OI store/direct 1102000/1105500
- HDFCBANK CE HDFCBANK26DEC830CE: store has the row (age 54 s), recorder has it, OI store/direct 2462850/2460250
- HDFCBANK PE HDFCBANK26DEC830PE: store has the row (age 54 s), recorder has it, OI store/direct 1023750/1031550
- SBIN CE SBIN26DEC1150CE: store has the row (age 20 s), recorder has it, OI store/direct 1853250/1857750
- SBIN PE SBIN26DEC1150PE: store has the row (age 20 s), recorder has it, OI store/direct 956250/956250
- INFY CE INFY26DEC1114CE: store has the row (age 51 s), recorder has it, OI store/direct 104400/113200
- INFY PE INFY26DEC1114PE: store has the row (age 102 s), recorder has it, OI store/direct 57200/58000
- TATASTEEL CE TATASTEEL26DEC177.5CE: store has the row (age 8 s), recorder has it, OI store/direct 525250/525250
- TATASTEEL PE TATASTEEL26DEC177.5PE: store has the row (age 12 s), recorder has it, OI store/direct 836000/836000

Notes: the store's rows2 carry no per-row time; the time shown is gir-v2opt's own per-contract quote time (optquote.json, the file the store reads). The J2 recorder refreshes every 15 min, so its prices are up to 15 min older than the direct quote; OI changes slowly. ATM strike = the store's exp2_info.atm_k.
