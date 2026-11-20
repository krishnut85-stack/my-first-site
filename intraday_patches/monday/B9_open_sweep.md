# B9 - the 09:15 December sweep: design, tests and the after-hours dry test (20 Nov 2026, after the close)

Built in gir-v2opt (`v2/feeds/optquote.py`), the v2 engine (`v2/engine/gates.py`, `core.py`, `config.py`) and gir-preview
(`v2/server/preview.py`, `v2/pages/static/sector-drill.js`, `shell.js`). Read-only; nothing places an order; nothing sends a message.

## 0. What really happened on 20 Nov 09:15-09:30 (found while building)

gir-v2opt's own log: the key-3 token of 20 Nov reached it only at **09:22:27** (`key 3 token of 2026-11-20 in use`). The J1 check shows
key 3 logged in at 09:21:59. So from 09:15 to 09:22 gir-v2opt made **no quote call at all** (it waits for a token of today) and the
store kept Thursday's quotes (63,500 s old). From 09:22 its normal rotation needed ~5-8 more minutes to reach every December name. So the
main cause was the late key-3 login, not the order of the sweep. From Monday the 07:40 automatic login (J1) gives key 3 its token
before the open. The sweep below fixes the second part: who is asked first, and how fast, once the token is there.

## 1. The sweep (gir-v2opt)

- **When:** the first pass at or after **09:15:00** on an NSE trading day (J3 calendar, no Tue 24 Nov). gir-v2opt holds its normal
  calls for the last <= 3 s before 09:15:00, so the key's 1-call-a-second budget is free at 09:15:00. If the token arrives late, the
  sweep still runs when it arrives (until 15:00). After a restart in market hours the sweep runs once at once (the fresh process has
  no chains).
- **Order:**
  1. **Index options**: NIFTY and BANKNIFTY, the full plan (every expiry gir-v2opt carries: on 23 Nov NIFTY 23 Nov / 1 Dec weekly /
     29 Dec monthly, BANKNIFTY 23 Nov / 29 Dec; ATM +-5, CE and PE, + the futures). If no index price is known yet (a fresh start),
     the first answer learns it and the index is asked again at once with strikes.
  2. **The 09:08 list** (`v2/data/predict/latest_<day>_P09.json`: lists CE / PE, watch CE / PE, movers, the idea shares; 19 names on
     20 Nov) + the engine's `v2/data/opt_priority.json` names (with their own strike / expiry): the **card series ATM +-2**, CE and PE
     (covers ATM and 1 ITM on both sides) + that series' future (Black-76's F).
  3. **Every other F&O share**: the card series ATM +-2 + its future.
- **Card series** = the expiry the engine's cards use (engine config E7): the current month while more than 7 sessions are left, else
  the next month. On Fri 20 Nov and Mon 23 Nov that is **December (29 Dec)**; from Wed 25 Nov December is the current month. A share
  with only the expiring series listed (20 Nov: IEX, IREDA) has no card series and is not swept.
- **Size and pace:** ~2,400 instruments on today's contract list = **9 calls of <= 288** (the existing MAX_PER_CALL 300 batching; 500
  with depth timed out on 19 Nov), one call per 1.1 s (Kite: 1 quote call a second per key). Key 3 only (REST, as before).
- **Yesterday's quote at 09:15:00:** a swept leg whose quote time is still before 09:15:00 (the first ticks arrive over a few seconds)
  is asked again: tiers 1-2 after 4 s, **ahead of tier 3** (at most 4 asks a name); everything else in up to 2 re-ask passes 8 s apart.
  After tiers 1-2 every third call goes to the normal rotation, so the HOT names (positions, GO NOW, NIFTY, BANKNIFTY) keep their 6 s.
- **Merge, not replace:** a swept answer replaces only its own strikes in the name's chain; the other strikes and the other expiry keep
  their own quotes and their own quote times (the engine reads each leg's own time). The name's place in the normal rotation is kept.
- **Kept (already applied):** the engine's GO NOW / MUST SEE names -> HOT tier (opt_priority.json, every pass).
- **New in the normal rotation:** the 09:08 list names are PRI (target 20 s) for the whole day, so the card strikes stay fresh after
  the sweep too.

## 2. "premium loading" instead of red STALE (engine + pages)

- The engine still never uses an old premium: QUOTE AGE fails, GO NOW is impossible, the written rule R4 rejects.
- Only the words change, and only when the premium's quote is **from before today's 09:15:00** and the time is **before 09:25**
  (`OPT_LOADING_TO`): the gate reads `premium loading (09:15 sweep): the 2026-12-29 1240 CE premium is from before today's 09:15
  (15:29) - no GO NOW until today's first quote`; R4 reads `R4 premium loading (09:15 sweep) - no premium of today yet`; a kept strike
  the same. A quote of today that is merely old is STALE as before; after 09:25 a yesterday's quote is STALE as before.
- gir-preview: a chain whose newest quote is from before 09:15, between 09:15 and 09:25 on a trading day, is LATE (amber) with the why
  `premium loading (09:15 sweep)` (not STALE red); `oc.<S>.opt.loading = true`.
- Pages: the plan card on Desk-Hunt / Rotation / Morning (sector-drill.js) shows the block `premium loading` with the why
  `premium loading (09:15 sweep) - today's first December quote is not in yet; no GO NOW until it arrives` instead of
  `OPTION STALE 63500s`; the shared state tag (shell.js) reads `premium loading`.

## 3. The Monday measurement (written automatically)

gir-v2opt writes `girdata/review/monday/B9_open_sweep_<date>.md` on every trading day, at 09:20 (interim) and 09:30 (final):
seconds after 09:15:00 until 50 / 90 / 100 % of
- the 09:08 list has a card-series (December) **ATM CE and ATM PE quote younger than 60 s and from today's session** (and a strict
  line that also needs both 1-ITM legs), and
- the index series (NIFTY / BANKNIFTY expiries except one expiring that day) has its ATM CE + PE fresh;
plus the sweep's own log (calls, call time, re-asks, tier times) and a timeline every ~10 s to 09:20, then every minute, with the
names still loading. If gir-v2opt has no token by 09:20 the file says NOT MEASURED and why. Ages use the exchange quote time Kite
returns (the same time the engine's QUOTE AGE gate reads). Nothing is sent anywhere.

## 4. Tests

| test | result |
|---|---|
| `v2/feeds/test_optquote_sweep.py` (synthetic Kite answers, the real cached 20 Nov contract list): card series Dec on 20 / 23 Nov, NIFTY series on 23 Nov = 1 Dec + 29 Dec; order NIFTY, BANKNIFTY, the 09:08 list, VOLTAS (engine priority with its own strike), then the rest; <= 300 per call, <= 14 calls; an old leg asked again then left alone; the merge keeps the November rows and the outer strikes with their own (old) times and leaves the rotation time alone; an index with no price is asked again with one; IREDA (no December) not swept; the measurement file has the 50 / 90 / 100 % table | 5 / 5 OK |
| `v2/feeds/test_optquote_open_sim.py` (SIMULATED clock 09:14:58-09:21 and a fake Kite whose first ticks arrive 2 s after 09:15:00, every 7th contract only at 09:15:40): the hold before 09:15:00, the sweep, fast re-asks, the normal rotation in between, the 09:30 file | 09:08 list 90 % fresh at ~43-50 s, index at ~7 s, 50 % of the list at ~7 s - **simulated; the real numbers come from Monday's file** |
| engine `python3 -m pytest -q engine/tests` (v2/engine, after the change) | **111 passed** (108 before + 3 new: loading until 09:25 then STALE, R4 loading, key 3 down, key 1 down) |
| gir-preview checks (`scratchpad test_preview_f2.py` on the installed file): loading LATE at 09:17 Mon, not at 09:26, not on Tue 24 Nov (holiday) | all OK |

## 5. The dry test (Fri 20 Nov, 16:47 IST, after the close - ONE read-only quote call on key 3)

`python3 v2/feeds/optquote.py --sweep-dry --one-batch --out <scratch>` (the dry mode never writes optquote.json; it logs its lines with the prefix "B9 DRY"; my run of it logged to a scratch file):
- plan from today's real contract list and the real 09:08 list: tier 1 = 2 names, tier 2 = 19 names (the 09:08 list; engine priority
  file absent after the close), tier 3 = 199 names; **2,404 instruments in 9 calls** (before IEX / IREDA were dropped as having no
  December series; now ~2,380);
- the ONE call (the sweep's first batch: NIFTY, BANKNIFTY, all 19 list names, 6 tier-3 names): **281 instruments asked, 281 answered,
  140 ms**; 250 December option legs back, 250 with an IV (Black-76 on the December future, e.g. KALYANKJIL F 643.50, VOLTAS F
  1,240.75, TMPV F 269.18); quote ages 10-314 s at 16:47 (the last quote updates of the session);
- the two index plans had no strikes in the dry run (a fresh process with no index price) - which is why the "ask again with the
  learned price" step was added and tested; in the live process the index price is known from the 09:00-09:15 passes.

## 6. Installed (20 Nov after the close) and how to undo

- `v2/feeds/optquote.py` (backups `.bak1656` = before B9, `.bak1704` = first B9 version); gir-v2opt restarted 16:56 and 17:04
  (idle until Monday 09:00). Undo: `cp v2/feeds/optquote.py.bak1656 v2/feeds/optquote.py; systemctl restart gir-v2opt`.
- Engine: see F2_key_degraded.md (same change). Pages / preview: see F2_key_degraded.md.
- girtrader.com/login after each restart: 0.04-0.07 s.
