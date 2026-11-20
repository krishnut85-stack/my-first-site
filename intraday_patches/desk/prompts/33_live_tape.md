# SEAT 33 - LIVE TAPE (Market-internal bench - LIVE ON MONDAY; CODE ONLY - no model call. This file = the rules code applies and the card text)

## 1. ROLE
This seat is the desk's tape reader, written as code: the senior dealer who never takes his eyes off the sector screens and says
one thing at the right moment - "banks are holding VWAP while NIFTY is red: the money is really moving" - or "IT has lost VWAP: the
theme is fading". It turns the whole-sector baskets (R49), breadth, RVOL, VWAP side and relative strength into short ALERT cards that
are the LIVE PROOF (or the live failure) of a theme or idea other seats named. Relative strength against a red tape is the proof the
money is moving (DESK_TEAM 2.5). It is a GRADE input and a wake-up call, never a reason by itself.
It must NEVER: place or suggest an order; output any number not computed from the minute store at that bar; speak to the trader (only
the HEAD does); fire on stale data; fire a confirmation before 09:20.

## 2. WATCHES
- Every 5 minutes from 09:20 (and on each closed 1-minute bar for the wake rules): R49 whole-sector basket % from the open and over the
  last 15 / 30 minutes, the basket's VWAP side, breadth inside the basket (members up / all, members above VWAP), relative strength vs
  NIFTY (basket % minus NIFTY %), RVOL per member (section 0 definition), leaders / laggards by contribution.
- Market: NIFTY and BANKNIFTY % from the open and VWAP side, broad advance / decline, India VIX %.
- F27 basket shock: 3+ shares of one basket moving the same way past a threshold inside 60 s. E11 rotation alarm.
- The live themes and ideas from the board (sector, side, named shares) so each alert can be linked to the card it proves or breaks.
- Data age per input; anything older than its limit (quote age 60 s) is named and that sector gets no alert.

## 3. KNOWLEDGE (the rules code applies)
From SECTOR_LINKS D, PREDICTION_LOOP 0 / B2 / B4, DESK_TEAM 2.3 rule 3 and 4.3, LINK_BOOK C1 / C11 / C19. Thresholds marked [G] are to
be tuned on the replay and the first live days; all alerts are NOT PROVEN.
- **T1 THEME LIVE (confirm):** a theme's sector basket (a) holds its VWAP side, (b) beats NIFTY over 15-30 minutes, (c) breadth in the
  basket agrees (at least 60% of members the same way), (d) basket % from the open the same sign and at least 0.3%. If NIFTY is red
  and the sector holds all four, the card says "holds VWAP on a red NIFTY" - the strongest form.
- **T2 THEME FADING / BROKEN:** a sector that met T1 closes two 5-minute bars on the wrong side of its VWAP, or most members drop below
  their own VWAP, or relative strength turns negative over 30 minutes -> FADING; the head's cancel_ref met -> BROKEN.
- **T3 SECTOR MOVE (wake):** basket move of 1% or more in 15 minutes, or E11 rotation alarm -> wake that sector seat (min gap 10 min).
- **T4 BASKET SHOCK (wake):** F27 fires -> wake the sector seat and the news desks to find the cause; card says "cause unknown" until found.
- **T5 NARROW RALLY / NARROW FALL:** index up with broad breadth negative (or the mirror) for 30+ minutes -> "leaders only, no laggard
  chase" (supports the DEVIL; LINK_BOOK C1).
- **Grade, not gate (movestudy):** waiting for sector CONFIRMED caught only 19% (CE) / 29% (PE) of moves early vs 46-48% for ORB5 - so T1
  raises an idea's grade (A when the sector is CONFIRMED, B when it only agrees); a share moving alone is grade C, silent.
- **No confirmation before 09:20** (DESK_TEAM 2.4); 09:17-09:20 states are logged, never alerted. After 11:00 a first T1 is "late".
- **C19:** "sector A today -> sector B tomorrow" without a driver is about a coin flip - the tape proves TODAY, it does not forecast.

## 4. HOW IT DECIDES (code, in order, every 5 minutes)
1. Drop any sector whose inputs are stale; list them in `not_seeing`.
2. For each live theme / idea sector: test T1, then T2. A state change only (NEW -> LIVE, LIVE -> FADING -> BROKEN) writes a card.
3. For every basket: T3 and T4 wake rules (merged with any wake inside 60 s, DESK_TEAM 4.3).
4. Market check: T5 once per 30 minutes while it holds.
5. Link each card to the theme / idea it proves or breaks (`linked_card_ids`); name the two or three leaders by contribution.
6. Silence otherwise: no change = no card.

## 5. OUTPUT
Kinds: ALERT (T1-T5 state changes), QUIET (written once per 30 minutes if nothing changed, so the roster shows the seat alive).
```json
{"seat": "33_live_tape", "kind": "ALERT", "rule": "T1_THEME_LIVE",
 "headline": "Banks hold VWAP on a red NIFTY and beat it over thirty minutes; breadth agrees - live proof of the flows theme",
 "strength": 3,
 "claims": [
  {"text": "Bank basket {num:sec.BANKS_PVT.pct_open} from the open vs NIFTY {num:idx.NIFTY.pct_open}; above VWAP", "type": "FACT", "evidence_ids": ["tape:<snap>"]},
  {"text": "Members up {num:sec.BANKS_PVT.breadth_up} of {num:sec.BANKS_PVT.n}; relative strength {num:sec.BANKS_PVT.rs30}", "type": "FACT", "evidence_ids": ["tape:<snap>"]}],
 "ideas": [], "winners": [{"target": "BANKS_PVT", "side": "CE", "strength": 3, "horizon": "TODAY", "role": "theme sector", "why": "holds VWAP and beats a red NIFTY"}],
 "losers": [{"target": "none", "side": "PE", "strength": 1, "horizon": "TODAY", "role": "-", "why": "none: tape proof covers the theme sector only"}],
 "leaders": ["AXISBANK", "ICICIBANK", "KOTAKBANK"], "grade": "A", "not_seeing": [],
 "evidence": [{"id": "tape:<snap>", "source": "GIR minute store / R49 baskets", "first_seen": "<copied>", "grade": "OFFICIAL"}],
 "new_since_last": "State changed from NEW to LIVE", "proof": "NOT PROVEN", "expires": "15:10", "linked_card_ids": ["<theme card>"], "links": ["SL-D"]}
```
**One-line card texts (code fills the placeholders):**
- T1: "LIVE: {sector} holds VWAP on a {red|green} NIFTY, beats it by {num:sec.<KEY>.rs30} over 30 min, breadth {num:sec.<KEY>.breadth_up}/{num:sec.<KEY>.n} - proves {theme}."
- T2: "FADING: {sector} lost VWAP ({num:sec.<KEY>.below_vwap}/{num:sec.<KEY>.n} members below their VWAP) - {theme} weakening." / "BROKEN: {theme} cancel met."
- T3: "MOVE: {sector} {num:sec.<KEY>.pct15} in 15 min - sector seat woken." T4: "SHOCK: {num:sec.<KEY>.shock_n} {sector} shares {up|down} together in 60 s - cause unknown."
- T5: "NARROW: NIFTY {num:idx.NIFTY.pct_open} but breadth {num:mkt.breadth.adv}/{num:mkt.breadth.dec} - leaders only, no laggard chase."
- `<KEY>` is the sector key (CONTRACTS sections 4 and 6). Seat-33 blocks: `rule` T1_THEME_LIVE / T2_THEME_FADING / T2_THEME_BROKEN /
  T3_SECTOR_MOVE / T4_BASKET_SHOCK / T5_NARROW; `grade` A / B / C is the tape grade (not an evidence grade); `leaders`; `not_seeing`.

## 6. EXAMPLE (Fri 20 Nov 2026, from DESK_TEAM 2.5 and monday/OUTSIDE_WATCH_2026-11-20.md; exact minutes to check in the replay)
- **Morning:** NIFTY opened red (about -0.66% near the open); Nifty IT led, up to +1.3-1.6% (TCS, Tech Mahindra, HCL Tech, Infosys) while
  US tech had fallen -> T1 "IT holds VWAP on a red NIFTY" = the AI-adopter theme live, inside the 09:45 CE window.
- **09:57:** BANKNIFTY recovered about 600 points and turned green; ICICI Bank and Kotak at records -> banks T1 once breadth agreed.
- **10:15-13:20:** broad breadth stayed negative (1,144 / 2,032 at about 10:15; 1,454 / 2,397 at 13:01) while the index rose -> T5 NARROW.
- **14:27:** all ten IT shares below their VWAP (Infosys +0.10% from +1.14%) -> T2 IT FADING; at the same time every bank heavyweight
  traded above its own VWAP (HDFC Bank, ICICI) -> banks stay LIVE. BANKNIFTY closed at a record 64,635, +2.49%.

## 7. RED LINES
- No alert on stale data; no confirmation alert before 09:20.
- The tape proves or breaks a theme TODAY; it never forecasts tomorrow and is never the reason for an idea by itself.
- A share moving alone (grade C) is silent; a sector is a GRADE, not a gate.
- Speak only on a state change; never two cards for the same state.
- Never output a number the minute store did not compute at that bar; never a strike, stop or target.
