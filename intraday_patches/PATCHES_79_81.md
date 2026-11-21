# Patches 79–81 — speed and timeliness, on top of patch 78 (the gates)

Paste in order, after 15:35 IST (or with `now`): `install_p78.sh` → `install_p79.sh` → `install_p80.sh` → `install_p81.sh`.
Each one refuses to run twice, refuses out of order, applies exact anchored edits (nothing written if one anchor does not
match), backs up `*.bak$TS`, runs its own test plus the earlier tests, and rolls everything back on any failure.
Nothing deploys itself. No new socket, no new Kite app, no login spent.

## 79 — the money within 5 seconds
- `engine2.py`: `pins_live.json` every 5 s on its own thread (`pins_loop`), from the ATM±N strikes the engine already
  pins on GIR Live 2/3/4. Before: written from inside the REST sweep, so once per 1.5–2-minute pass — not once a minute as
  the docstring said. The spot in it is now the share's live price from the equity socket, not the last sweep's.
- `desk.py`: reads every 5 s (stale after 40 s). Readings are kept by time (2 min in full, one a minute before that,
  30 min back), so the 15-minute window, the open+30 reference, the 5-minute confirmation and the rules' windows are
  unchanged. Own REST pull stays once a minute. Results map once a minute. A reading slower than 4 s is logged.
- Test: 20 minutes of 5-s readings through the desk give the same meter, the same side and a 300-second confirmation as
  1-minute readings; the history stays under 60 entries a share; a 14-minute-old reading is still there.

## 80 — Telegram off the working threads
- `tgq.py` (new): one sender queue and thread. `send()` returns at once; posts in order; one retry (not on a 4xx), 10 s a
  try; `on_ok` / `on_fail` callbacks; drains at exit so command-line runs still deliver.
- `engine2.tg_fo`, `desk.tg_box`, `core.tg` all use it. A line that fails twice is written to the NOW list marked
  `⚠ NOT SENT`. The chain sweep, the desk's 5-s reading and the tick agents never wait for Telegram again.
- `p78test.py` is adjusted (sending is queued). Restarts every service that imports `core.tg`.

## 81 — the push stream
- `dashserve.py`: `/events` (Server-Sent Events). `now` the same second a line lands in the alerts table, `idx` every ~3 s,
  `secs` when the desk writes a new picture. One connection per open page; ends after an hour, the browser reconnects.
- `home.html`: listens and renders with the same code (`render()`); the tape and the news stay on the poll (gzip): 15 s
  while the stream is up, 5 s when it is not. No change to the look. Verified in a headless browser: stream connected,
  NOW updated live without a refresh, no script errors.

## What stays as it was, on purpose
- The 5-minute SUDDEN confirmation (one thin reading is not a trade). Shorten it from Monday's audit numbers, not from feel.
- The full-chain REST sweep (BREWING and the deep walls) at 1.5–2 min a pass.
- FIRST MOVE and ORDER BOOK as bare WATCH lines; the caps; `risk_rs` still to be set.

## After Monday's open, three checks
```
ls -l --time-style=full-iso /home/globalbot/intraday/pins_live.json     # changes every 5 s
journalctl -u gir-desk -f                                                # no "tick took" lines
curl -s -N --max-time 4 "http://127.0.0.1:8090/events?k=$(cat /home/globalbot/intraday/dash_token.txt)" | head -c 600
```
