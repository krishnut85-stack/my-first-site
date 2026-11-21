# DECISION SHEET - built 22 Nov 00:05 order (proof)

The trader's order: "make money - MAKE DECISIONS". From Sun 22 Nov 19:45 the brief on GIR Trade now is a DECISION SHEET (code: `v2/analyst/sheet.py`, wired into `service.py` and `rehearsal.py`). Cost of this proof: **$0** (recorded model answers + recorded one-minute candles; no AI call, no Telegram).

## What runs, and when (IST)

| time | what | Telegram |
|---|---|---|
| 19:45 (evening before) | BUILD: market call (gap + session, GIFT NIFTY vs the Nasdaq-futures line and which wins - from the world builder's `analyst/gapsignals.py`), top 3 CE + top 3 PE, AVOID | only after the 18:30 ring test passed (else WOULD SEND; sent once if the test passes before 23:00) |
| 07:15, 09:08 | UPDATE the same sheet: KEEP / DROP / NEW, each with its why | same |
| 09:30-14:30 | a sheet trigger fires (price through the level + RVOL >= 1.5): grade A -> the live BUY NOW chain (contract gates -> chain check with the Devil -> safety gate) -> BUY NOW; grade B, or an A whose non-Devil checks fail -> READY - YOUR CALL; Devil not answered -> NOT TAKING | BUY NOW: from Mon 09:15 (existing rule); READY / NO TRADE / SUMMARY: trade-time check + ring test + 50 a day / 6 per 15 min |
| 10:30, 13:00 | no BUY NOW yet -> NO TRADE YET - why - next look 11:30 / 14:00 | same |
| 15:15 | one-line day summary | same |
| 15:45 | every call scored (sheet rows, BUY NOW, READY, NOT TAKING) -> `sheet_scores.jsonl`; week-1 scorecard (Mon 23 - Fri 27 Nov) rewritten daily -> `sheet_week.json / .md` | page only |

Rules enforced in code:
- A row without trigger price / stop / target / why / grade A-B is **refused** (`SheetRowError`) and never printed. Levels must sit on the correct side (CE: stop < trigger < target).
- Only ideas that already pass the desk's gates go on: the evidence grade (grade.py), anti-chase (an idea that is only "it moved yesterday" -> AVOID "only the last move"), the Devil (NOT TAKING -> AVOID "Devil not answered"). Grade C never reaches Telegram, not even as an AVOID name. An idea with no grade on record is graded before the sheet is built.
- Fewer than 3 a side -> the sheet says "Only 1 CE passed the checks" / "No PE passed the checks".
- Only a grade-A row may say "BUY above ..." (send-gate rule for kind SHEET: only under a header ending "· A"); a B row says "READY above ...".
- Idea with no price trigger from the brief (09:20-confirmation type): code attaches yesterday's high (CE) / low (PE) break; still none -> "NO TRIGGER PRICE YET".

## Layout: how "one line each" maps to the 43-character rule

One idea = one compact block in the 13:00 layout; every fact is BUILT short by code, never cut into a second bullet:

```
TITAN CE 3412 DEC · A
• BUY above 3,412 + RVOL 1.5 after 09:30
• Stop 3,371 · Target 3,494
• Why: Results beat estimates (results)
```

The "why" is compressed to fit 43 characters with its source: company name (already in the header) and filler words dropped, cut at a clause or a whole word, no dangling "and / that / with". A grade-B block adds "• Grade B - your call when it hits". On an update, the header starts KEEP / NEW and a KEEP adds "• Kept: <why>". Longest line in every test and dry-run text: <= 45 characters ("• " + 43); the hard send gate passes on every text.

## Dry run: Friday 20 Nov (the sheet that would have gone Thu 19:45)

Inputs: the FULL3 rehearsal's recorded real-model brief answers for session Fri 20 Nov (its board copied read-only), regraded with today's gates using that board's cards and Thursday's recorded close; Nasdaq-futures line from the recorded 5-minute bars; Friday one-minute candles (price, VWAP, RVOL vs the 5 sessions before at the same minute). GIFT NIFTY: no recorded value for that night. Outputs: `girdata/review/monday/DESK_rehearsal/SHEET_DRY/`.

### Pass 1 - today's gates (what really would have gone out)

All three Thursday ideas grade **C** under today's evidence gate (no tested history with 30+ cases, the Devil filed only a theme objection - no answer per idea); BANKBARODA CE was also anti-chase (up about 4% on Thursday, no fresh reason). Thu 19:45 sheet:

```
DECISION SHEET - FRI 20 NOV

MARKET CALL
• Gap: FLAT · Session: MIXED
• Nasdaq fut since close: +0.1%
• GIFT NIFTY: not known yet

CE IDEAS
• No CE passed the checks

PE IDEAS
• No PE passed the checks

AVOID
• BANKBARODA CE - only the last move

NOT PROVEN
• Ideas only - your trade, your choice
```

07:15 / 09:08 updates: market call turned to "Gap: DOWN" (Nasdaq futures -4.6% / -4.7% since Thursday's close; the gap followed 80% on 1%+ moves, 148 cases); PNB CE joined AVOID (only the last move); still no idea passed. Lines that would have gone out during the day:

```
NO TRADE YET 10:30
• no idea passed the checks
• Next look 11:30

NO TRADE YET 13:00
• no idea passed the checks
• Next look 14:00

DAY: 0 CALLED · 0 FIRED · 0 BUY · 0 READY
• No sheet trigger fired today
```

### Pass 2 - WHAT-IF (labelled): grade-C ideas that were not anti-chase treated as B

Shows the trigger mechanics on Friday's real prices. Thu 19:45 sheet:

```
PE IDEAS
• Only 2 PE passed the checks

HEROMOTOCO PE 5550 DEC · B
• READY below 5,556 + RVOL 1.5 after 09:30
• Stop 5,621 · Target 5,426
• Why: Sharp fall in profit (results)
• Grade B - your call when it hits

TCS PE 2340 DEC · B
• READY below 2,343 + RVOL 1.5 after 09:30
• Stop 2,371 · Target 2,286
• Why: IT closed lower (news)
• Grade B - your call when it hits
```

07:15: KEEP HEROMOTOCO PE, KEEP TCS PE, NEW ALKEM PE 5200 DEC · B (below 5,145; USFDA warning-letter news); 09:08: all three kept.

Which triggers fired: **none**.
- HEROMOTOCO: price was below 5,556 for 155 minutes between 09:30 and 14:30, but RVOL never passed 1.17 (needs 1.5) -> not fired; closed 5,520 (0.65% past the trigger, target 5,426 not reached) -> scored RIGHTLY WAITED (note: price hit the trigger without volume).
- TCS: never below 2,343 (rallied to 2,415) -> a PE would have lost -> RIGHTLY WAITED.
- ALKEM: below 5,145 for 41 minutes on RVOL <= 0.40, closed 5,172 -> RIGHTLY WAITED.

Lines that would have gone out: "NO TRADE YET 10:30 / • gap fade, no volume / • Next look 11:30", the same at 13:00 (next look 14:00), and "DAY: 3 CALLED · 0 FIRED · 0 BUY · 0 READY / • No sheet trigger fired today". 15:45 score: 3 calls, 0 fired, 0 missed moves.

BUY NOW / READY / NOT TAKING on a fire are proven by the unit tests (below), not by this day - Friday gave no trigger with volume.

## Tests

`v2/analyst/tests/test_sheet.py` - 18 tests, all pass (under the GIR_TEST_ROOT guard):
sheet from a fixture book (3 CE + 3 PE + AVOID, every row with trigger / stop / target / why / grade, gate-clean, longest line <= 45, grade C absent), "fewer than 3" said plainly, refusal of a row with no trigger / stop / target / why / wrong-side levels, why shortened never wrapped, 07:15 keep / drop / new, trigger fire -> BUY NOW for A and READY for B (not before 09:30, not without RVOL 1.5, never twice), Devil unanswered -> NOT TAKING, A with failed checks -> READY (never silent), NO TRADE YET at 10:30 / 13:00 (once; none after a BUY NOW), 15:15 summary, 15:45 score rows + week scorecard, the SHEET send-gate rule, ring-test detection + ring limits, a replay never sends, the market call (GIFT outranks NQ; the world builder's verdict), after_brief with the real board (ungraded idea graded first; 07:15 update).

NOT PROVEN - the sheet earns trust only through the week-1 scorecard.

## Reviewer's fixes 5-10 (DESK_REVIEW 22 Nov 00:50) - in the sheet code

| fix | status | what the code does | proof |
|---|---|---|---|
| 5 anti-chase on the evening list | DONE | at sheet time every open idea is graded again by grade.py with the store as it is then; a CE after a 3%+ rise / PE after a 3%+ fall with no catalyst dated after the move -> WATCH only -> AVOID "only the last move" (never a row) | tests (POLYCAB fixture); Friday dry run: BANKBARODA CE (+4.1% Thu) and PNB CE -> AVOID; Monday preview: INDUSINDBK CE, PERSISTENT CE -> AVOID |
| 6 both legs per driver | DONE (sheet) | "BOTH SIDES: <driver> <move since India's close> (<time>)" + the two legs with the sign the tape shows (copper down: cables PE + AC / EMS CE; gold down: lenders PE + jewellers PE; chips, Nasdaq, Brent, Bitcoin); the 3 biggest movers >= 1% | test_fix6; Monday preview below. The head's own D-lines are the head prompt (desk-owned) - not changed here |
| 7 Monday lean | DONE | market call from gapsignals.signals(now): when GIFT and the NQ line disagree: "SIGNALS DISAGREE" + "No pre-set side - decide at 09:30"; GIFT, Nasdaq futures and Bitcoin each with its time; a CORRECTION block on the Sun 19:45 sheet for msgs 640-641 / 644 (gap DOWN said while GIFT was +0.14% after the US close; an untested ALKEM PE shown; "93% (20 cases)" -> 14 of 15; DIXON demoted) | test_world_builder_verdict, test_sheet_3_3 (CORRECTION) |
| 8 open positions first | DONE | every sheet starts with "YOUR <share> <side> <strike> DEC" + HOLD while / EXIT if the share crosses the last session's high (PE) / low (CE), no amounts; an idea on the same share or sector on the other side is flagged "Against your ... - your call" and can never be a desk BUY (A -> B) | test_fix8 (SBIN CE vs a bank PE); Monday preview |
| 9 Monday PE list from the chip-shock study | DONE | for session Mon 23 Nov the PE rows are the study's 2026 laggers in order (CGPOWER, POWERINDIA, GVT&D, KAYNES, KPITTECH, PGEL; n = 12, NOT PROVEN, grade B with "Study: lagged k of 12"), levels by code (break of Friday's low); DIXON demoted to last | test_fix9; Monday preview (GVT&D had no code levels -> KAYNES next) |
| 10 one message per idea / balanced levels / untested label | DONE | 07:15 / 09:08 updates show only NEW or CHANGED ideas; unchanged ones = one "STILL ON - NO CHANGE" line; live READY / BUY NOW / NOT TAKING ring once per idea per day; a row with reward / risk below 1.0 is refused (INDUSINDBK +0.6% vs -3.4% could not be printed); an idea without a tested base rate prints "Story only - not tested by history" | test_0715, test_fix10, tests of ring-once |

### Monday 23 Nov preview (live board + live store at 00:2x Sun, not sent)

```
YOUR HDFCBANK PE 820 DEC
• HOLD while share below 850.4
• EXIT if share above 850.4 after 09:30
(MOTILALOFS PE 1160 DEC: 1,215 · UNIONBANK PE 210 DEC: 219.1)

CORRECTION (SAT MESSAGES)
• 640 / 644 said gap DOWN: GIFT was +0.14%
• after the US close (Sat 02:44) - no pre-set
• 641 showed an untested idea (ALKEM PE)
• 644 '93% (20 cases)' was wrong: 14 of 15
• DIXON PE demoted: lagged least in 2026

MARKET CALL
• SIGNALS DISAGREE · Session: DOWN
• GIFT NIFTY 25,836 at Sat 02:44 IST
• +35 pts (+0.14%) vs NIFTY close
• Nasdaq fut -4.0% since close (Sat 03:25)
• Bitcoin -2.7% since close (Sun 00:14)
• No pre-set side - decide at 09:30

BOTH SIDES: CHIPS (SOX) -10.7% (SAT 02:30)
• power / EMS PE (CGPOWER, KAYNES)
• IT services held better in 2026

CE IDEAS
• No CE passed the checks

PE IDEAS
CGPOWER PE 800 DEC · B
• READY below 785.1 + RVOL 1.5 after 09:30
• Stop 799.3 · Target 756.7
• Study: lagged 8 of 12, -2.5 vs NIFTY
(then POWERINDIA PE, KAYNES PE)

AVOID
• INDUSINDBK CE - only the last move
• PERSISTENT CE - only the last move
```

The real 19:45 sheet is built from the head's 19:45 ideas on top of this.

## Replay / dress rehearsal

`rehearsal.py` (and so `mock.py` and the dress rehearsal) now runs the sheet after each brief slot, the sheet's live step (triggers, NO TRADE YET 10:30 / 13:00, 15:15 summary) and the 15:45 score, all inside the run folder; every line goes to the run's `would_send.jsonl` (the capture) - a replay never sends. Checked on a stub mock dry run of Fri 20 Nov (`DESK_rehearsal/MOCK_DRY_SHEET1`): sheets at 19:47 / 07:17 / 09:10 in the capture.
