# J1 - Kite keys: automatic login and 08:20 check

Day 2026-11-20 · login job 16:01:13 (dry run) · check 16:01:17 · written 16:01:17 IST. No tokens, keys or user id in this file.

| Key | Carries | Login time (IST) | How | profile() | quote(NIFTY 50) | Note |
|---|---|---|---|---|---|---|
| 1 | underlyings + drivers (old engine main, RAVEN, gir.py) | 10:17:05 | reused today's token | OK | OK |  |
| 2 | options in play (old engine ws2 / x2b / x2c) | 09:04:12 | reused today's token | OK | OK |  |
| 3 | full chains (old engine x3a-c, gir-v2opt) | 09:21:59 | reused today's token | OK | OK |  |
| 4 | standby + REST (old engine x4a-c, gir-v2kq, gir-v2optdec, gir-v2wsrec) | 09:22:00 | reused today's token | OK | OK |  |

## Rings

- none (every key passed)

The phone ring is NOT wired yet: a failed key is written as a WOULD RING line (log intraday/data/kitelogin.log and here) until the Sunday ring test.

## Failover (key 4 takes a failed key's lists)

- none needed

Written to intraday/data/kite_failover.json. What happens today without new wiring: gir-v2wsrec and gir-v2optdec already take the first key with a working token of today (wsrec 2 -> 4 -> 3, optdec 4 -> 2); the old engine skips a key that is not logged in and runs on the rest. NOT automatic yet: gir-v2opt is fixed on key 3 and gir-v2kq on key 4 (no fallback key), and the old engine does not move key 2's / key 3's websocket lists onto key 4.

## Rules the jobs keep

- 07:40 login and 08:20 check on NSE trading days only (explicit dates from the J3 calendar; no Tue 24 Nov).
- A key whose token file is already from today and answers profile() is NOT logged in again (a new login would kill the token every other service already holds).
- No login 09:00-15:35 on a trading day; automatic logins only 06:00-08:55; at most 4 attempts per key per day; never two attempts of a key within 3 min; a wrong-password / captcha / blocked answer stops all logins for the day.
- No 07:15 job needs a Monday token: the 07:15 prediction update reads no Kite token (its GIFT NIFTY line says 'not known' when the key-4 quote file is old).

## Sunday dry run (for the coordinator - run on Sun 22 Nov after 16:00, ONCE)

All four keys share one Zerodha account. Do not run the login twice within a few minutes, and never on a trading day 09:00-15:35.
The job reads the keys by variable name from the environment file (systemd EnvironmentFile); nothing secret is printed.

```
# 0. what is scheduled (expect Mon 23 Nov 07:40 + 08:20, NO Tue 24 Nov, then Wed 25 Nov)
systemctl list-timers gir-kitelogin.timer gir-kitecheck.timer gir-kitecal.timer --no-pager

# 1. optional: see what the login WOULD do (calls profile() only, no login)
systemd-run --wait --pipe --collect -p EnvironmentFile=/home/globalbot/.env \
    /usr/bin/python3 -u /home/globalbot/intraday/kitelogin.py login --any-day --dry-run

# 2. the real login for all four keys (each one only if its token file is not already from today; ~30 s apart; 2 retries 2 min apart)
systemd-run --wait --pipe --collect -p EnvironmentFile=/home/globalbot/.env \
    /usr/bin/python3 -u /home/globalbot/intraday/kitelogin.py login --any-day

# 3. the check: one profile() + one quote("NSE:NIFTY 50") per key; rewrites this file with the table
systemd-run --wait --pipe --collect -p EnvironmentFile=/home/globalbot/.env \
    /usr/bin/python3 -u /home/globalbot/intraday/kitelogin.py check --any-day

# 4. the result to push (no tokens, no user id in either)
cat /home/globalbot/girdata/review/monday/J1_kite_check.md
python3 /home/globalbot/intraday/kitelogin.py status
tail -30 /home/globalbot/intraday/data/kitelogin.log
```

Expected on Sunday: key 1 shows "reused today's token" (RAVEN logs key 1 in by itself every morning; the job does not log in over a
working token); keys 2, 3, 4 show "new login HH:MM" (their files are from Friday). Sunday's tokens are dated Sunday, so on Monday
07:40 keys 2-4 log in again by themselves (the Monday login is the one that counts). After the Sunday ring test, replace the
"WOULD RING" log line with the real ring (one place: run_check() in kitelogin.py).

## J1 additions (20 Nov after the close, for Sunday's dry run) - retries, the phone message, the key-down rule

Built in `intraday/kitelogin.py` (backup `kitelogin.py.bak1656`); every rule above is kept. From the next check this report carries the
same sections by itself.

**(a) Retries.** A key that fails the 08:20 check is checked again at **08:25, 08:35 and 08:45** (NEW `gir-kiteretry.service` +
`gir-kiteretry.timer`, written by `kitelogin.py timers` with explicit NSE trading dates: Mon 23 Nov, no Tue 24, Wed 25 ...; the nightly
gir-kitecal keeps it). Each retry: one profile() + one quote("NSE:NIFTY 50") on that key only; a fresh login only when the token is
missing or refused AND every login rule allows it (06:00-08:55, never 09:00-15:35, at most 4 attempts a key a day counting the 07:40
job and the 08:20 check, the gap between attempts, nothing after a stop-all). A key that passes leaves the failed list
(kite_failover.json is rewritten). Still failing at 08:45 = **left alone** for the rest of the day (`gave_up` in the status file). The
retry job never runs 09:00-15:35 and does nothing when today's check left no key failed.

**(b) The phone message** (one place: `ring()` in kitelogin.py; today it only writes the WOULD RING line to data/kitelogin.log,
kite_login_status.json `would_ring` and this report - NOTHING is sent until Sunday's ring test wires it):
- a wrong-password / captcha / blocked stop (at once, for the key that got that answer):
  `WOULD RING: Kite key 2 failed: Zerodha said: Invalid password - GIR is running without it (all logins stopped for today). DEGRADED - key 2 down: ... treated as STALE, no GO NOW on them.`
- an 08:20 failure (at once - the desk's 16:40 wording; switch `RING_AT_FIRST = False` for final-only):
  `WOULD RING: Kite key 3 failed: profile(): TokenException: ... - GIR is running without it (retries 08:25 / 08:35 / 08:45). DEGRADED - key 3 down: option bid / ask / IV (gir-v2opt) + part of the pinned strikes treated as STALE, no GO NOW on them.`
- the final failure at 08:45: the same words with `(still failing after the 08:25 / 08:35 / 08:45 retries)`;
- a key that passes a retry: `WOULD RING: Kite key 3 is back at 08:35 - GIR has it again (DEGRADED mark cleared).`
At most one line per key and kind a day. The reason is scrubbed (no key, token or user id; a test with a token-shaped value in the
reason shows `<hidden>`).

**(c) Key down = DEGRADED (desk decision for Monday).** No automatic move of a key's feed. gir-preview reads kite_failover.json: the
feeds on the key read "DEGRADED - key n down" (footer + Health page), its quotes are STALE and the v2 engine gives no GO NOW on them.
Details and tests: `F2_key_degraded.md`.

**Tests (mocked Kite, temp files, no login, no network):** 08:20 failure -> the message once; 08:25 / 08:35 still failing -> no second
line, a login asked only through the guarded path; 08:45 -> the final line, then left alone (08:50: nothing tried); a key passing at
08:35 -> off the failed list + the "back" line, no login; a wrong password at 07:40 -> stop-all + the final line at once, the next key
makes no attempt; the timers file: 3 retry times per trading day, the 07:40 / 08:20 timers unchanged. All OK.

**Sunday dry run - add after step 3:** `systemctl list-timers gir-kiteretry.timer --no-pager` (expect Mon 23 Nov 08:25); the retry job
can be run by hand with `kitelogin.py retry --any-day` (it does nothing unless today's check left a key failed).
