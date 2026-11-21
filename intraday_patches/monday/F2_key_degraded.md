# F2 - a Kite key down on Monday: DEGRADED, its quotes STALE (desk decision 20 Nov 16:40) - built 20 Nov after the close

Desk rule for Monday: **no automatic move of a key's feed**. If a key fails, the page marks the feeds on that key "DEGRADED - key n
down", the engine treats those quotes as STALE (no GO NOW on them), and the phone alarm says so (a WOULD RING line until Sunday's ring
test). Full failover stays a week-1 item.

## The signal

`intraday/kitelogin.py` (J1) writes `intraday/data/kite_failover.json` at the 08:20 check and rewrites it at the 08:25 / 08:35 / 08:45
retries (`failed` = the keys still failing), plus `kite_login_status.json` (per key: login time, profile / quote result, reason,
would_ring). gir-preview reads both every 10 s (NEW `KiteKeysAdapter`, id `kite_keys`) and puts the store fact **`health.kite.keys`**
`{day, down: {"3": reason}, keys: {...}, check_run, retry_run, hard_stop, would_ring}`.

A key counts as down when it is in today's `failed` list, until a retry passes it (the list is rewritten) or its token file is written
**after** that check (a new login - only the file time is read, never the token). Another day's file counts for nothing.

## What each key's "down" does

| key | feeds marked DEGRADED (health line, Health page) | store / engine effect |
|---|---|---|
| 1 | `quotes` (share prices: quotes_live.json from the old engine's main feed) | every `sh.<S>` and `idx.NIFTY` fact STALE with why "DEGRADED - key 1 down (...)"; the engine's DATA AGE gate fails (hard block "stale data"), NIFTY STALE = read-only session. The engine also checks health.kite.keys itself. |
| 2 | `pins` (part of the pinned strikes, old engine x2b / x2c) | marked only; gir-v2wsrec already falls to key 4 by itself |
| 3 | `optquote` (gir-v2opt: option bid / ask / IV) and `pins` (x3a-c part) | every `oc.<S>` chain STALE with why "DEGRADED - key 3 down (...)"; `oc.<S>.opt.degraded` set; the engine's QUOTE AGE gate fails "STALE: DEGRADED - key 3 down (...) - the <exp> <strike> <side> premium is not used (no GO NOW on key-3 option quotes)", the GO NOW rule R4 rejects "R4 the premium is STALE: DEGRADED - key 3 down (...)"; a kept strike the same |
| 4 | `kq_mcx_cds` (gir-v2kq) and `pins` (x4a-c part) | `kq()` answers nothing: VWAP / volume / RVOL from gir-v2kq, GIFT NIFTY, MCX / CDS read "not known" |

## The pages

- **Footer health line (every page, shell.js):** `health LIMITED · DEGRADED - key 3 down (pins, optquote, kite_keys)` in red, the
  feeds' reasons on hover.
- **Health page (health.js):** the KITE KEYS tile reads `K3 DOWN · STALE` (DOWN chip; the reason on hover); the KITE KEYS panel lists
  K1-K4 problem first: `K3 DEGRADED - key 3 down` with its feeds, login time, retried, reason; then the WOULD RING lines of the day.
  The DEGRADED feeds sit at the top of PROBLEMS NOW (red dot), like MISSING.
- Screenshot (a TEST copy of gir-preview on port 8199 fed a simulated key-3 failure, live data otherwise; the live server was not
  touched): `v2/shots/f2/health_key3_down_1366_TEST.png`. The live Health page today (all keys OK): tile `4/4 OK check 16:01:17`, no
  page errors.

## The phone text (WOULD RING until Sunday's ring test wires ring() in kitelogin.py)

`WOULD RING: Kite key 3 failed: profile(): TokenException: ... - GIR is running without it (retries 08:25 / 08:35 / 08:45). DEGRADED -
key 3 down: option bid / ask / IV (gir-v2opt) + part of the pinned strikes treated as STALE, no GO NOW on them.`
(see J1_kite_check.md, "J1 additions" for when it is written).

## Tests

- engine (`v2/engine/tests/test_monday.py`, class `B9PremiumLoadingAndKeyDown`, synthetic stores): key 3 down -> QUOTE AGE fails with
  "DEGRADED - key 3 down", R4 rejects; another day's check or another key -> no effect; key 1 down -> the share's price not fresh
  ("DEGRADED - key 1 down"). Full suite **111 passed**.
- gir-preview (on the installed file, temp files, no server): key 3 down -> health row DEGRADED with the feed's words, `oc.<S>` STALE on
  both paths (with / without a pinned chain); key 4 down -> kq() None; a token file written after the check -> not down; another
  day's failover file -> nothing down. All OK.
- Page render: test server (port 8199) with a simulated key-3 failure + the live Health page: no page errors.

## Files changed (backups, undo)

| file | backup | undo |
|---|---|---|
| v2/server/preview.py (under the edit lock) | preview.py.bak1658 | `cp v2/server/preview.py.bak1658 v2/server/preview.py; systemctl restart gir-preview` |
| v2/engine/gates.py, core.py, config.py, tests/test_monday.py | *.bak1657 | `cd v2/engine; for f in gates.py core.py config.py tests/test_monday.py; do cp $f.bak1657 $f; done; systemctl restart gir-v2engine` |
| v2/engine_next/ (same four files, kept in step with v2/engine) | *.bak1658 | `cd v2/engine_next; for f in gates.py core.py config.py tests/test_monday.py; do cp $f.bak1658 $f; done` |
| v2/pages/static/shell.js, health.js, sector-drill.js | *.bak1659 | `cd v2/pages/static; for f in shell.js health.js sector-drill.js; do cp $f.bak1659 $f; done` |

Restarts after the close, one at a time: gir-v2opt 16:56 / 17:04, gir-v2engine 16:58, gir-preview 16:59; girtrader.com/login
0.04-0.07 s after each.
