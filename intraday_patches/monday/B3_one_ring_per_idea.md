# B3 - one ring per share per idea

**What changed** (`core._ring_gov`, the last word on every ring, plus `core._emit`)
- One ring per share + side per idea. A second ring only after that idea was cancelled and 60 min passed.
- An idea stays ONE idea (same idea_id, same strike) while it is live.
- No cancel and no "moved to WATCH" within 10 min of a ring. A hard block (ban, stale data, read-only) still shows at once.
- No re-issue of a cancelled share + side within 15 min.
- No new GO NOW because the day's high or low moved: a "levels moved" update never rings.
- Never a ring for:
  - a card whose final lane is not MUST SEE / CRITICAL (limiter or opening hold);
  - a card with 0 lots or no strike;
  - the 15-min window's pick unless it is still MUST SEE.
- Limits: 50 rings a day and 6 in any 15 min. The trader's own EXIT / BOOK HALF always ring and are counted.

**Tests**
    test_day_replay_no_rering_no_quick_cancel ... ok
    test_limits_and_one_per_idea ... ok

**Before / after (captured frames, rules only)**

| day | rings before -> after | busiest 15 min before -> after | published cancels before -> after |
|---|---|---|---|
| 16 Nov | 7 -> 3 | 3 -> 3 | 1 -> 0 |
| 18 Nov | 12 -> 3 | 4 -> 2 | 1 -> 0 |
| 19 Nov | 32 -> 3 | 3 -> 2 | 4 -> 2 |

On 19 Nov the old engine rang PAYTM PE 15 times on "levels moved" between 10:51 and 14:00. After: one ring. Ring notes after: "no ring: this idea already rang at 09:31", "no ring: not tradable (no premium...)".

## J2 check - today's live market (20 Nov), engine 0.2 vs engine 0.3
**Before (J2 report, live engine 0.2 with the AI, whole day):** 75 rings against the limit of 50, and 7 in the 10:30 window.
- 66 were CRITICAL: 45 TV hold-offs, 10 repeated Max Healthcare / Vedanta news, 5 thesis cancels, 6 stops / locks.
- The rest: 9 window ideas, 1 GO NOW, 4 EXIT / BOOK HALF.

**What 0.3 changes:**
- A TV hold-off on a share he does not hold is a silent card note, once per share per day, never a ring. On a share he holds it still rings.
- Repeated news on the same share + side never re-rings (one ring per idea).
- THESIS CANCELLED rings only if one of its calls had rung today.
- A tradable new GO NOW rings at once; new GET READY cards keep the 15-min ranking.
- Rules mode: MUST SEE hysteresis, and a published live card stays 10 min, so no MUST SEE / WATCH flapping.

**Same frames, rules only** (the light live capture 08:58-10:28, with today's TV calls and news map passed in):

| engine | rings 08:58-10:28 | busiest 15 min | TV rings | thesis-cancel rings |
|---|---|---|---|---|
| 0.2 (v2/engine.prev-1120) | 15 | 7 | 8 | 4 |
| 0.3 | 8 (7 GO NOW, 1 GET READY) | 6 | 0 | 0 (4 silenced: "no call of this thesis had rung") |

The capture stopped at 10:28 (its time limit), so the full-day count for 0.3 comes from Monday's live run. The governor keeps 0.3 at <= 50 / day and <= 6 / 15 min whatever the day brings (tests above).

**Replays (rules only, the Nov premium proxy on):**

| day | rings | busiest 15 min | by side |
|---|---|---|---|
| 18 Nov | 12 | 6 | 11 PE / 1 CE; one more was held by the 6-in-15 limit |
| 19 Nov | 4 | 2 | 2 CE / 2 PE |

Tests:
    test_tv_note_silent_and_thesis_cancel_rule ... ok
    test_tv_rows_once_per_share_per_day ... ok
