# SECTOR DRILL-DOWN - "which F&O shares are coming up in this sector" (R50)

The trader's words, 19 Nov: "When I see some sector moving up I want to know which F&O shares are coming up, and in that list I
should click the share I want and see the details. I know the AI is doing the checking, but we still need this facility."
It was agreed by two panels: the desk (a senior F&O dealer, an options buyer and an options specialist) and the review panel (a
quant, a risk/SEBI officer and the design authority). The trader's own view must NOT depend on the engine: the independent review
found the engine late and PE-biased, so the up-side (CE) shares must be visible to him directly.

## 1. One behaviour everywhere (one component: SectorMembers + SharePane)
- **Where it opens:** clicking a sector **anywhere** opens its F&O shares in place. Only one sector is open at a time. The places are:
  - the F2 board row and heat-map tile
  - the F3 table row and the money-flow band (the flow band opens that sector in the table below it, not as a tooltip)
  - the F3 "moving, but not this rotation" list
  - the F1 Desk sector chip
  - the Morning page (pre-open version, labelled "pre-open - not live")
- **Clicking a share** loads it into the right-column share pane (the existing TITAN pane). The sector list stays visible.
  **Double-click** or **Enter** opens the full F7 Share page. The pane and F7 use the same numbers.
- **Keyboard:**
  - **1-9** picks a sector, and **Enter** on a sector row opens it.
  - **↑ ↓ / J K** move from share to share, and the pane follows.
  - **O** opens the option chain at the suggested December strike.
  - **W** opens Why, **Space** opens the Plan card, and **P** pins the share.
  - **Esc** closes step by step.
  - **Back** returns to the same sector, the same open list and the same row.
- **Layout:** the open list sits in normal page flow. It pushes the rows below it down and never draws over them (this fixes the
  live F3 bug). Every line is a single line with "…" for overflow, and the long BASIS text goes behind a "basis ›" link.
  At least 8 whole share rows fit at 1366x768 and 12 at 1600x900, then "+n more ▾". The sector line stays pinned at the top.
- **Live updates:** numbers keep ticking in fixed-width cells. The **order never changes under the mouse or keyboard focus.**
  A rank change shows as ▲2 / ▼1 with a 1-second outline, and a "re-ranked · R to apply" chip appears; the new order applies when
  the pointer leaves the list, or after 30 s. A new entrant is added at the bottom marked NEW.
- **Speed:** opens in under 100 ms from cached values, then goes live. Every row shows its quote age.
- **Phone:** the list becomes a full-screen sheet. Tapping a share opens the share sheet, and Back returns to the list.

## 2. The sector line (pinned above the list)
`Metals ▲ +1.12% · NIFTY METAL index · breadth ▲19 ▼23 all 42 listed · F&O ▲6 ▼6 · RS30 +0.60 · CONFIRMED 09:45 · up since 10:05
(55m, typical 1h40 n=28) · WHY: LME copper +2.1% (live) · [NARROW]`
- The move and breadth come from all listed shares (R49), with the basis named. The F&O list is the tradable part.
- WHY gives the driver with its live move and the story with its age, or "UNEXPLAINED".

## 3. The list: every F&O member, in groups (never hidden)
**Groups, in this order:**
1. **COMING UP NOW**
2. **LEADER** (even if extended, with its pullback trigger)
3. **LAGGARD - may catch up**
4. **AGAINST THE SECTOR (n)**, with the opposite side's strike
5. **NOT TRADABLE**, dimmed, with the reason

**Rules for the groups:**
- A rising sector shows CE strikes on the first three groups. A falling sector mirrors this with "coming down" and PE strikes.
- Before 09:30 the list reads "forming".
- After 14:30 it reads "manage only - no new entries".
- The non-F&O shares of the sector fold into one grey line, for example "10 more listed, not F&O · ▲7 ▼2 · wt 13%". Clicking it
  shows them for context only. They never get a strike.

**Columns, in order:**
1. share + role chip (LEADER / FOLLOWER / DEPENDENT / LAGGARD)
2. day %
3. vs sector (RS30) with a 15-min slope arrow
4. RVOL with an arrow showing whether it is rising
5. VWAP / OR side (above / below / reclaiming)
6. room (ATR used · ATR left)
7. build-up, all months (LB / SB / SC / LU + OI chg %)
8. weight % (thin bar)
9. December strike CE/PE + premium + spread %
10. state / gate (a failing share shows the gate that failed, e.g. "RVOL 0.9", "below VWAP")
11. AI chip (GO NOW / GET READY / AI silent)

**Formula (quant):**
- **Inputs** are taken on closed 1-minute bars:
  - RS15 / RS30 = (share return − sector return) / the share's 20-day stdev of 15 / 30-min returns
  - RVOL = volume since 09:15 / the 20-session median of volume up to the same minute
  - side: 1 = above both VWAP and the OR high, 0.5 = above one of them, 0 = above neither
  - build-up: LB 1, SC 0.5 (labelled "covering - fades fast"), none 0, SB/LU −1
  - EXT = |price − VWAP| / ATR14
- **Score** = 0.30·RS30 + 0.20·RS15 + 0.20·min(RVOL,3)/3 + 0.15·build-up + 0.15·side. It is smoothed over 5 min and re-ranked at
  most every 30 s.
- **COMING UP NOW** needs all four gates to pass:
  - RS15 > 0 and RS30 ≥ +0.5
  - RVOL ≥ 1.5
  - above VWAP for 2 closed 5-min bars
  - no SB / LU

  The tag switches on at a score of 0.60 and off below 0.45, so it does not flicker.
- **EXTENDED - don't chase:** EXT > 1.0 or range used > 0.8 ATR. The share stays on the list with the words "enter on the
  pullback to VWAP 3,421 / first higher low, half size".
- **LAGGARD - may catch up:** the share is flat while the sector's breadth is 70% or more one way, with no bad news of its own and a
  build-up that does not go against the sector. It shows its own trigger price and is never ranked above the leader.
- Each threshold is a starting point. The scorecard keeps the hit rate of COMING UP (+R after 30 / 60 min, with n), and thresholds
  are re-tuned only when n ≥ 30.

## 4. The share pane (opens on a click; the sector list stays visible)
**First view, in order:**
1. Price and quote age; VWAP / OR side and the distance in ATR; % vs sector; RVOL; build-up by month and combined.
2. **The trade box** for the suggested **December** CE/PE, ATM and one strike in the money, showing:
   - bid / ask and the spread in Rs per lot
   - depth at the bid for his lots
   - delta and theta in Rs per hour
   - IV vs its 20-day level
   - lot cost (= the most he can lose)
   - the break-even share price at 15:10
3. Trigger / stop / target in both the share price and the premium. Rs risk against the lock room, giving the lots that fit
   ("0 lots" is shown, never hidden). Trades n of 3, and the 15:10 countdown.
4. A mini 5-min chart: VWAP, opening range, the nearest CE wall above and PE wall below, and a premium pane under it.
5. The AI's view (its call and time), or "AI silent - your read".
6. Event chips: results date / time ("IV crush"), ex-date, MWPL %.
7. The top 2 news items, each with its age.

**One click deeper:** the full option chain (O), futures by month and rollover, OI by strike, IV history and the crush record at
past results, the share's history stats, all news, and his own record on this share.

## 5. Risk and compliance
- **Hard blocks (only these three):**
  - F&O ban: the row stays, dimmed and sorted last, "BAN - only close existing".
  - Loss lock: "LOCKED - no new trades today".
  - Stale quote: "STALE 12s", and no GO NOW.
- **Warnings in plain words, each with the fix:**
  - "SPREAD 1.6% = Rs 900 lost on entry; 1,060 CE has 0.6%"
  - THIN depth
  - MWPL ≥ 80% amber, ≥ 90% red ("near ban")
  - "RESULTS hh:mm - IV crush"
  - ex-date
  - "Expiry week · physical settlement - December only"
  - "you already hold this driver / sector"
- **Signal only:** "GIR never places orders - you place the order in Kite." There is no buy button. "Copy contract" is allowed.
- Every list snapshot is logged with its time, for the journal and the scorecard.

## 6. Also important (ranked)
1. **Up-side guarantee:** rising sectors are never collapsed or pushed to a side note. Each sector row shows its CE count, and an
   "engine today PE / CE 57 / 0" counter shows the engine's bias.
2. **"Why moving" line** per sector (driver, live move, story age, or UNEXPLAINED).
3. **One-key alert on a pinned share:** "tell me when X crosses 3,414 / reclaims VWAP". One sound, pinned shares only.
4. **Pin (P)** up to 5 shares to the Desk watchlist. GIR raises GET READY on a pinned share when its gates pass.
5. **Compare 2-3 shares side by side on the option itself:** spread, delta, premium per lot, room, IV. This picks the best
   option, not just the best share.
6. **Sector run clock and fading flag:** "up since 10:05, 55m, typical 1h40 (n=28); breadth slipping 11→8".
7. **The leader's December ATM premium mini-chart:** is the premium confirming, or is IV bleeding?
8. **"New entrants" strip:** shares that turned COMING UP in the last 15 min across all sectors. It does not ring.

## 7. Live faults seen 19 Nov evening (F2 / F3 photos), fixed by this
1. Expanded rows overprint the rows below on F3. Only 4 member rows show, with no "+n more".
2. The basis is "5 named members" / "rebuilt from F&O members only", which breaks R49.
3. Yesterday's move is shown as today's in the pre-open ("mixed day - jewellers lead the fall"), and there are two clocks.
4. Real up-moves are hidden. Electronics +2.37% and durables +2.18% sit in a side note, while the "money OUT of Hospitals → INTO
   Banks" headline rests on −0.13% / −0.02%, and realty +0.59% contradicts it. Every row is tagged SC.
5. TITAN (−5.3%, the day's biggest faller) is tagged "follower". The pane suggests a November expiry, but it should be December.
6. Dashes and "not known" everywhere. The reason should be shown once.
7. The orange replay bar covers part of the market strip.
