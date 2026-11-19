| # | control | what was done | result | note |
|---|---|---|---|---|
| 1 | 1366: open list layout | Banks open at load: next sector row below the block, member rows never overprint | PASS | pushed=true overlaps=0 |
| 2 | 1366: row cap | whole share rows in first view (need 8) | PASS | visible=8 · next sector row visible=true · "+n more" shown=true |
| 3 | share row click | click AXISBANK row | PASS |  |
| 4 | share row click (2) | click ICICIBANK row | PASS |  |
| 5 | J / ↓ / K / ↑ | press J, ↓, K, ↑ from ICICIBANK | PASS | AXISBANK → BANKBARODA → AXISBANK → ICICIBANK · pane follows |
| 6 | W (why) + Esc | press W, then Esc | PASS |  |
| 7 | Space (plan card) | press Space, then Esc | PASS |  |
| 8 | P (pin) | press P twice | PASS | pinned 1/5 + PIN tag, then unpinned |
| 9 | sector list scrollbar thumb | mouse down on thumb, drag 60 px down, release; drag up, release | PASS | scrollTop 0 → 106 → 0 |
| 10 | sector list track click | click the track below / above the thumb | PASS | 0 → 215 → 0 |
| 11 | sector list ▲ ▼ buttons | click ▼ then ▲ | PASS | 0 → 52 → 0 |
| 12 | mouse wheel | wheel down over the list, wheel up over the scrollbar | PASS | 0 → 215 → 95 |
| 13 | PageDown / End / PageUp / Home | focus the list, press each | PASS | 95 → 213 → 215 → 1 → 0 |
| 14 | share pane scrollbar thumb | drag the pane thumb 80 px down | PASS | 0 → 152 |
| 15 | share pane keys (focus) | focus the pane, ↓ ↓ then PageDown | PASS | 0 → 80 → 400 |
| 16 | share pane wheel | wheel up over the pane | PASS | → 0 |
| 17 | "+n more ▾" / "less ▴" | click +6 more, then less | PASS | rows 14 → 8 |
| 18 | "27 more listed, not F&O" line | click it (context list), click again | PASS |  |
| 19 | basis › | click basis ›, then ✕ | PASS |  |
| 20 | "re-ranked · R apply" chip | click the chip | PASS | AXISBANK moves above ICICIBANK, ▲1 and chip gone |
| 21 | R key (apply re-rank) | press R | PASS |  |
| 22 | window chip 15M | click it | PASS | flow range 10:50-11:05 |
| 23 | window chip 1H | click it | PASS | flow range 10:05-11:05 |
| 24 | window chip TODAY | click it | PASS | flow range 09:15-11:05 |
| 25 | window chip 30M | click it | PASS | flow range 10:35-11:05 |
| 26 | RUN CLOCK chip + run row click | click RUN CLOCK, click the IT run row | PASS | 7 run rows · IT opened, table view back |
| 27 | TABLE chip | click TABLE | PASS |  |
| 28 | falling sector mirror | IT open: groups read COMING DOWN NOW with PE strikes | PASS |  |
| 29 | sector row click (open) | click Metals | PASS | only one open, rows below pushed down |
| 30 | sector row click (close) | click the open Metals row | PASS |  |
| 31 | key 3 (pick sector) | press 3 | PASS |  |
| 32 | key 1 (pick sector) | press 1 | PASS |  |
| 33 | Esc step by step | Why open → Esc ×3 | PASS | closes Why → clears the share (pane shows the compare table) → closes the list |
| 34 | flow arrow label click | click NBFC in the flow picture | PASS |  |
| 35 | headline word click | click IT in the hero line | PASS |  |
| 36 | "moving, not this rotation" click | click Realty | PASS |  |
| 37 | new-entrant chip | click BAJFINANCE | PASS | opens NBFC and loads BAJFINANCE |
| 38 | compare table row | Esc, then click the first share in the compare table | PASS |  |
| 39 | pane button W why | click it, then ✕ | PASS |  |
| 40 | pane button P pin | click twice | PASS |  |
| 41 | Copy contract | click it | PASS |  |
| 42 | ALL SECTORS chip | click it | PASS |  |
| 43 | pinned chip | click it | PASS |  |
| 44 | double-click share → F7, Back | double-click ICICIBANK, then browser Back | PASS | went to share.html#ICICIBANK · Back → Banks / ICICIBANK |
| 45 | Enter → F7, Back | press Enter, then Back | PASS | went to share.html#ICICIBANK · Back → Banks / ICICIBANK |
| 46 | O → option chain, Back | press O, then Back | PASS | went to chain.html#ICICIBANK-1460CE-29DEC · Back → Banks / ICICIBANK |
| 47 | pane button Enter F7 | click it, then Back | PASS | went to share.html#ICICIBANK · Back → Banks / ICICIBANK |
| 48 | pane button O chain | click it, then Back | PASS | went to chain.html#ICICIBANK-1460CE-29DEC · Back → Banks / ICICIBANK |
| 49 | build-up chip link (F10) | click the LB chip, then Back | PASS | went to futures-oi.html#bu=LB · Back → Banks / ICICIBANK |
| 50 | tab F2 Sectors | click it, then Back | PASS | sectors.html |
| 51 | tab F7 Share | click it, then Back | PASS | share.html |
| 52 | tab ⇧F1 Morning | click it, then Back | PASS | morning.html |
| 53 | tab F3 Rotation | click it, then Back | PASS | rotation.html |
| 54 | P&L strip → F6 | click it, then Back | PASS | positions.html |
| 55 | footer health link | click it, then Back | PASS | health.html |
| 56 | pointer leaves list → re-rank applies | hover the list, move the pointer out | PASS |  |
| 57 | page errors | console / page errors during all of the above | PASS |  |
| 58 | 1600: open list layout | Banks open at load: next sector row below the block, member rows never overprint | PASS | pushed=true overlaps=0 |
| 59 | 1600: row cap | whole share rows in first view (need 12) | PASS | visible=12 · next sector row visible=true · "+n more" shown=true |
PASS 59 FAIL 0
