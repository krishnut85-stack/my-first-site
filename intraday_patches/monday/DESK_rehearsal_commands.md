# DESK REHEARSAL - the exact commands (my session has no model key; the coordinator runs the paid layers)

All from the server, after hours, under nice. Each layer writes its own folder under /home/globalbot/girdata/review/monday/DESK_rehearsal/<name>/
(one sub-folder per replayed day: ideas.jsonl in the edge.py contract, run.json, deskboard.db, brief_*.md / .json, would_send.jsonl,
state_last.json; plus ai_raw.jsonl, rehearsal.log and REHEARSAL.md with the EDGE line per day). Nothing touches the live board, the live
store, the page, Telegram or gir-v2replay. The v2 engine runs inside the player for its roles / zones, with ITS OWN AI switched off.

## 0. Before any paid layer
- The prompts must be in /home/globalbot/preview_src/intraday_patches/desk/prompts/ (copy from the branch). Check what the desk will load:
  `cd /home/globalbot/intraday/v2 && python3 -m analyst.promptload && python3 -m analyst.service --status`
- Tests: `cd /home/globalbot/intraday/v2 && python3 -m pytest -q analyst/tests`   (must say "14 passed" or more)

## 1. Stub layer (free; every brain FAKE - plumbing, timing, budget accounting; I run this myself)
```
cd /home/globalbot/intraday/v2 && nice -n 15 python3 -m analyst.rehearsal --days 2026-11-18,2026-11-19,2026-11-20 --layer stub --name STUB3
```

## 2. Haiku layer (readers R1-R6 / 29 with a prompt file real, every other seat + the head FAKE; about $1-3)
```
cd /home/globalbot && set -a && . ./.env && set +a && cd intraday/v2 && \
  nice -n 15 python3 -m analyst.rehearsal --days 2026-11-18,2026-11-19,2026-11-20 --layer haiku --name HAIKU1 --cap 3
```

## 3. Full layer (every seat WITH a prompt file real + the head real if H*.md exists; the trader's one-off $15 line)
```
cd /home/globalbot && set -a && . ./.env && set +a && cd intraday/v2 && \
  nice -n 15 python3 -m analyst.rehearsal --days 2026-11-18,2026-11-19,2026-11-20 --layer full --name FULL1 --cap 15
```
- The $15 is a hard line in code (gate.py run cap, counted from the run's own ledger), on top of the J11 buckets per replayed budget day
  (MEET 1.50 / LIVE 1.30 / READ 1.00 / SEATS 0.90 / ASK 0.30, $5.00 total), so the rehearsal also shows whether the desk fits $5 a day.
- Run the 20 Nov head 2-3 times for stability (DESK_TEAM 7): `--days 2026-11-20 --layer full --name FULL_20b --cap 6` (repeat with _20c).
- Score again without re-running: add `--score-only --name <the same name>`.

## 4. What to read after a run
- `<folder>/REHEARSAL.md` - per day: looks, cards, AI calls and $ by seat (refused calls named), briefs, the EDGE line (top 5 first).
- `<folder>/<day>/edge.json` + the E1-style review md that edge.py writes - precision >= 1% / >= 2% to the close and the next close vs the
  base rate, earliness, wrong side, BY SOURCE, the top 5, names per day.
- `<folder>/<day>/brief_<day>_1945.md`, `_0715.md`, `_0908.md` - the briefs as he would read them.
- The cost per seat (for Sunday noon): `python3 -c "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); print(db.execute('select seat, bucket, count(*), round(sum(usd),4), sum(ok) from ai_calls group by seat, bucket').fetchall())" <folder>/<day>/deskboard.db`

## Known limits of the replay data (honest)
- 18 Nov: no v2 recording (Kite minute + oihist), no gir-v2filings log (it starts 19 Nov 15:23), no news-reader rows (they start
  19 Nov evening), TV from the old whisper reader. 19 Nov: recordings from 11:40. 20 Nov: full day.
- World drivers in replays are the KB daily closes (LATE), not intraday - the 22:45 code check can fire on a stale daily move.
- FII 5-day sum: only 18 / 19 / 20 Nov exist -> "not known (3 days)".
- Point-in-time knowledge: rows naming a Nov 2026 date on/after the evening before are dropped from the knowledge pack; the trader's read
  record is left out (later reads). The desk's prompt files themselves were written on 20 Nov and may hold 20 Nov examples (e.g. R1 section 6)
  - a leakage risk the desk must judge; I do not edit prompts.
