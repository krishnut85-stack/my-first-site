# D1 - drill-down clean-up (20 Nov 2026, after the close) - /preview only

**R51 re-run (inside + outside, 1366 / 1600 / phone 390 + rules): 12 NOT RUN · 871 PASS.** FAIL rows: none. Table: girdata/review/drilldown/R51_controls.md (+ .json); shots: girdata/review/drilldown/shots/.

| # | asked | done |
|---|---|---|
| 1 | no "..." at 1366 except prose with a tooltip | Drill list: short fixed words (group sub-labels "pullback if EXT", "reason in row"; roles LDR / FOL / DEP / LAG with a legend line; state "EXT ↩ 982.3", "trig > 176.4", "✕ RVOL 1.2 +2" with the full sentence in the tooltip; AI cell only GO NOW / GET READY, else "AI silent"; heads "Dec strike · prem · spr", "B/U · OI"); three fixed column layouts by the list's own width (full at 1600 / room + wt into the pane at 1366 / narrow with group header rows on the F1 Desk); the pane trade box with ATM / ITM on their own row and bid, ask, spread split. Host lists: F3 table cell padding 4 px, name one size down, TODAY # folds away while no sector is open, head words "#DAY" / "RS DAY", the day-% bar no longer overflows its cell, the open list's spanning row follows the visible columns; F2 board driver column folds away while no sector is open, wider rank / build-up / breadth / state; F1 breadth column 106 px. 8 whole share rows at 1366 and 12 at 1600 still hold (R51 "row cap" rows PASS). |
| 2 | THE FLOW "not known" | The flow reads sec.rot over all listed shares; a window with no values yet (15 / 30 / 60 min empty before the window has passed or in the pre-open) falls back to TODAY with a TODAY chip saying why; an empty side reads "none" with a tooltip, never a dash. |
| 3 | footer names the real GO NOW model | The footer already reads eng.v2 ai.chain (nothing hard-coded): it shows "Haiku 5.5 triage, Opus 5.5 GO NOW" since the 15:38 swap; it now also takes the first model when the chain is a list (FINAL_CHAIN). |
| 4 | P&L mask dark grey, labelled | Playwright mask + mask_color #2b3038 on every P&L value, one "P&L hidden" label. |
| 5 | r51 cut check + full re-run | Added (see R51_controls.md notes); full suite re-run inside and outside. |

Flake: the first outside phone run stopped at its first finger tap on the F3 Banks row (the page under the finger left the drill page); the re-run at 17:47 passed 52 / 52 and is the one in the table.

Also fixed tonight: closing a sector did not finish its clean-up (a comment I had put mid-line cut off the sheet close / hash / pane-host lines - found by the phone Back test, fixed); phone Back now follows the history entry; after 15:30 the label reads "closed - not live · 20 Nov 15:30 close" (before the open "pre-open - not live"); the December-chain gap is named once (list + pane) instead of n/k in every cell.

**For the coordinator:** gir-preview leaks about 10 MB per page load (one SSE client each; 414 -> 470 MB over 6 loads, not given back; MemoryMax 600M) and was OOM-killed twice this evening (15:44, 16:31). I did not change the server or its unit: a MALLOC_ARENA_MAX=2 drop-in, or not keeping the per-client snapshot, would need your yes. I restarted gir-preview under the edit lock before each test run instead. girtrader.com/login stayed 0.03-0.09 s, except one 1.30 s reading at 16:17 during the engine replays (0.035 s on re-check).

Files changed (all backed up, logged in v2/BUILD_LOG.md and v2/pages/LOG.md): static/sector-drill.js / .css (.bak1545), static/rotation.js (.bak1547, .bak1618), static/rotation-v2.css (.bak1547), static/sectors-v2.css (.bak1548), static/desk-hunt-v2.css (.bak1549), static/shell.js (.bak1552). No git push.
