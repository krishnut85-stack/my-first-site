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
