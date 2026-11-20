# B1 - the sector state is a grade, never a gate (v2/engine_next, 20 Nov 2026)

**What changed**
- The triage definition's condition (1) "sector must be CONFIRMED" is removed. Condition (1) is now "a real entry": a price trigger broken or near, plus at least one backing sign (RVOL >= 2 or RVOL5 >= 3, yesterday's high / low, fresh build-up its way, or its sector moving its way). The sector state is a GRADE that only raises or lowers priority. AGAINST its own sector still fails (veto d).
- Removed from the engine:
  - the "sector FORMING and not a leader / not on the watch" skip;
  - the "GO NOW needs CONFIRMED" wait;
  - the 09:20-09:30 hold on share ideas whose sector is not confirmed. A confirmed sector's names still go out as its one sector line; other ideas keep their lane, up to the opening cap of 6, best AI priority first.
- Each card carries `sector_grade` (CONFIRMED / FORMING / FADING / NONE) and `grade_sector`.
- The score and rank use the larger of the sector grade and the share's own signs, so a missing sector never pushes a card under the floor.

**Tests (engine_next, synthetic stores)**
    test_desk_definition_has_no_confirmed_gate ... ok
    test_no_sector_is_not_silence ... ok

**Before / after on the captured playback frames, rules only**

These are GO NOW-ready cards; on these frames the only thing holding them back is the missing December premium (see B5). Grades:

| day | NONE | FORMING | CONFIRMED |
|---|---|---|---|
| 16 Nov | 31 | 19 | 13 |
| 18 Nov | 25 | 25 | 32 |
| 19 Nov | 45 | 25 | 30 |

Before this change a card with grade NONE could not exist, and FORMING cards waited for CONFIRMED.

**Undo:** `v2/engine.prev-1120` is the engine before B1-B9 (restore it and restart gir-v2engine).
