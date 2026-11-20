# DESK PROMPT ISSUES - found by the code validators in tonight's shadows (20 Nov 20:16 IST). For the desk; I do not edit prompts.

1. **Trigger enum.** Seat 8 wrote trigger_ref GAP_HOLD and ORB5_LOW. CONTRACTS.md marks ORB5_HIGH / ORB5_LOW / GAP_HOLD as PROPOSED ("code
   rejects them until the engine enum ships"), but the CONTRACTS trigger enum still lists them, so a model reading the schema uses them.
   Proposal: drop them from the CONTRACTS enum (or ship them in the engine enum). The retry message now lists the allowed triggers.
2. **Digits that are not figures.** The 4.5 whitelist (FY26, Q2, December) rejected "US 10-year yield", "First Seat 11 card", "no seat 35
   theme card", dates like "17 Nov". These are names, not numbers. Code now also allows: bond tenors (10-year / 2y), seat references
   (seat 11, seats 35 and 36, R1-R6), calendar dates (17 Nov), years (2026). Please confirm or narrow it in CONTRACTS 0 / DESK_TEAM 4.5.
3. **Real counts in prose.** Seats 9 / 10 / 36 wrote "27 of 34 up", "Hang Seng 5, 9", "six of twenty" style counts with digits. Those stay
   rejected (a count not in the snapshot keys is an invented number). The prompts could say: counts go in words, figures only as {num:key}
   from the NUMBERS list in the input.
4. **Headline length.** Seats 8 and 36 wrote headlines over 25 words. Retry message now gives the count.
5. **Invented ids.** The Devil targeted "banks_theme_draft". The input now lists IDS YOU MAY TARGET; the prompt could say target_card_id must
   be copied from that list.
6. **Placeholder keys the prompts use but code does not fill yet:** story.stats.* / story.<row>.*, sc.* (scorecard), opt.*, deal.*, cal.*,
   rbi.*, mkt.NIFTY.pct_open, hist.*, tr.* - a model that uses one gets a retry ("not a snapshot number"). Code fills: idx. world. cmdty. fx.
   flows.FII.* sec.<KEY> sh. tech.<SYM>.rsi14 pos. story.<EM id>.n / .abn_d0 / .abn_d1 item.n<k>.
7. **Seat file stem.** CONTRACTS asks for seat = file stem; code sets it after the answer (no model error possible).
