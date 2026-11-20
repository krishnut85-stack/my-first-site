# R50 sector drill-down on /preview + R51 controls test

- `sector-drill.js` / `.css`: the ONE openSector component (groups, gates, lots, share pane), used by F3 rotation, F2 sectors (board row + heat tile), F1 desk chip and Morning (pre-open, "not live").
- `R51_controls.md` / `.json`: PASS / FAIL for every control, inside (127.0.0.1:8100/preview) and outside (girtrader.com/preview, logged in), desk 1366x768 + 1600x900 and phone 390x844. Real mouse / keyboard / scrollbar drags and CDP finger touches, no forced states. Totals: 841 PASS, 0 FAIL, 12 NOT RUN (need a live market: re-rank / NEW / ticks, STALE, LOCKED - their rules pass in the rules rows).
- `R51_recheck_after_label_fix_inside.json`: re-run after two label fixes (20 Nov ~06:00 IST): 234 PASS, 0 FAIL, 3 NOT RUN.
- `shots/`: /preview screenshots (outside, logged in; the P&L strip is masked).
- `r51.py`, `rules.py`, `shots.py`, `mkreport.py`: the test scripts.
Data: the 19 Nov close (market closed). Not built yet: spec 6.3 / 6.5 / 6.7 / 6.8 and the list-snapshot log (5).
