# PAGE CHECK - the reviewer's 22 Nov 00:20 lines, looked at as the trader would

Run 22 Nov 00:40 IST (Sun 22 Nov, market closed) on the LIVE gir-preview (127.0.0.1:8100, read only). All 24 pages at 1366x768 and 390x844: the page facts are read from the DOM first, then the shot is taken with maskshot.shoot() (header P&L strip + phone P&L box + every digit masked, verified, stamped) into FINAL_shots/. Tool: v2/shots/tools/pagecheck_0020.py (re-run after any later change).

**17 PASS / 0 FAIL** of 17 lines · page errors: none

| # | reviewer line | result | evidence (read from the page) | shot |
|---|---|---|---|---|
| 1 | World drivers frozen at Fri 15:29 / "live 0 / late 10"; World headline "CE side" after the SOX crash | **PASS** | found: none of "live 0 / late", "CE side" | world_1366.png, world_390.png |
| 2 | GIFT NIFTY "not known" in the header / stale 25,862 on the Phone - must be 25,836 (02:44 Sat) everywhere | **PASS** | header: GIFT NIFTY prem +35 · closed ; phone has 25,862: False; phone has 25,836: False | desk-hunt_1366.png, phone_390.png |
| 3 | Friday's 'CALL day on AUTOS' (Morning, Analyst L1), Friday's 'MAXHEALTH CE' prediction and Friday's SHOCK lines shown as TODAY | **PASS** | morning: 'CALL day on AUTOS' under OLD PLAN / was; analyst: no 'CALL day on AUTOS' | morning_1366.png, analyst_1366.png, desk-hunt_1366.png, phone_390.png |
| 4 | Sectors 'CE day' / Rotation 'TODAY' = Friday's verdicts with Saturday stamps; Market rotation strip REVERSED vs the Rotation page | **PASS** | sectors: CE day (Fri 20 Nov) ; rotation INTO: HOSPITALS & DIAGNOSTICS CONFIR; market strip: no OUT -> IN strip; reversed: False | sectors_1366.png, rotation_1366.png, market_1366.png |
| 5 | Footer 'health DOWN / MISSING / LATE' on a weekend -> 'Market closed - next session Mon 09:15' (one wording everywhere) | **PASS** | pages still saying DOWN / MISSING / LATE in the footer: none; footers with 'Market closed': 44 of 46; e.g. 'Market closed - next session Mon 09:15 · desk ON - next brief Sun 19:45 / search ? help Sp' | desk-hunt_1366.png, news_1366.png |
| 6 | Expiry box 'next 2026-12-29' over 'Mon 23 Nov - 1 sessions left'; Market '3 days to 23 NOV' | **PASS** | header expiry: 'EXPIRY then Tue 29 Dec Mon 23 Nov · 1 session left F&O BAN BAN 1'; market: 'no n days to 23 NOV' | desk-hunt_1366.png, market_1366.png |
| 7 | Raw developer text on pages (premium.path..., money.big [{...}], idx.NIFTY.spark, calls.feed, kq_mcx_cds, sectorplan GROU...) | **PASS** | none of the 6 patterns visible on any of the 48 page views | (all) |
| 8 | News: the US crash in no visible story; 'today's heaviest' = a PIB cinema story / an unverified rumour | **PASS** | hero: 'TODAY'S HEAVIEST WORLD SHOCK first seen 03:25 · AI weight not read · TP checked against live prices (map rung PRICE) WORLD SHOCK: Nasdaq -5.54% (Sat 03:25) - do' | news_1366.png, news_390.png |
| 9 | Calendar: RBI Rs 50,000 cr VRR Mon and the Tue 24 holiday not visible; 'cannot add' shown as if banned | **PASS** | header: '7 events ahead · next: Mon 23 Nov expiry · RBI Mon 23 Nov Rs 75,010 cr 3-day VRR reverses · new repo that day: Rs 50,000 cr · HOLIDAY Tue 24 Nov NSE holiday - no trading · day NORMAL 00:34:49'; 'cannot add' on the page: False | calendar_1366.png, calendar_390.png |
| 10 | Held PEs under 'CE side / CONFIRMED' labels with no conflict warning; 'Banks -> PE CONFIRMED' vs Banks +1.90% | **PASS** | no 'BANKS -> PE CONFIRMED' on F1 in a trade; no conflict word on the page | desk-trade_1366.png, sectors_1366.png |
| 11 | Desk hunt: CALL tags on falling drivers (silver -4.74%, Hang Seng -3.79%) | **PASS** | THEME lines: ['THEME SOX chip index −10.73% -', 'Silver (COMEX) −7.41% PUT AGAINST']; against the driver: none | desk-hunt_1366.png |
| 12 | Share page 'LAST CALL 2026-10-23' -> rename 'LAST EARNINGS CALL' | **PASS** | 'LAST EARNINGS CALL' on the page: True; a bare 'LAST CALL' left: False | share_1366.png |
| 13 | Chain opens on 360ONE / Nov expiry -> open on a held position and its expiry (his PEs are December) | **PASS** | expiry buttons: ['2026-11-23', '2026-12-29*', '2027-01-25']; share on screen: HDFCBANK (held) | chain_1366.png |
| 14 | Morning card text overlaps / cut | **PASS** | cut cells on the page (shell strip + search box excluded): 1366 0, 390 0 | morning_1366.png, morning_390.png |
| 15 | Phone P&L box pushes the content below the fold (his trades / drivers) | **PASS** | first position card at y 382 of the 578 px NOW list (was ~5,140: the prediction board sat above the cards) | phone_390.png |
| 16 | NAV: 'F3 not used' -> Shift+F3 'Money map' (world funds, bonds, gold, dollar, BTC; every number with its time, closed markets grey, sort bar) | **PASS** | tab bar: Shift+F3 Money map; rows 21 (with their session time 21, grey because closed 20); sort bar True; 'not used' on the tab bar: False | moneymap_1366.png, moneymap_390.png |
| 17 | NAV: 'F5 off / no reload' shown only in Help, not as a button | **PASS** | F5 on the tab bar: False; F5 explained in Help: True | desk-hunt_1366.png, help_1366.png |

Owners: lines 1, 2 (and the GIFT / World parts of 3) = WORLD builder; 3, 4, 5, 6, 7, 10 = FRESHNESS builder; 8, 9, 11-17 = pages builder (22 Nov 00:04-00:40, BUILD_LOG).
