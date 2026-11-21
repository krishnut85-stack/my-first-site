# GIR MODE - the trader's fallback switch on the Settings page (MONDAY_READY J7)

Run 21 Nov 2026 10:26 IST. **R51: 1 NOTE · 61 PASS** (inside: real gir-preview for refusals and read-only status, plus a TEST COPY for every flip; outside through the login), at 1366x768 / 1600x900 (mouse) and 390x844 (CDP taps). The real switch was never flipped: /home/globalbot/gir_mode still does not exist ("new, default, never flipped").

## Server (gir-preview, restarted 10:14 and 10:29 IST Saturday under the edit lock; undo below)
- **GET /preview/api/gir/status:** runs exactly `/usr/local/bin/gir status` and returns {ok, text, status {mode, muted "n of 12", old_ai, desk_lines, last[]}}. Without a valid website session it returns {ok: false, signed_in: false} with NO status data (HTTP 200, so the page logs no console error).
- **POST /preview/api/gir/mode** {"mode": "old"|"new", "confirm": "OLD"|"NEW"}: runs exactly `gir mode old` or `gir mode new`.
  - The argument list is fixed: no request text reaches the command, and no shell is used.
  - It refuses with 403 without a valid session, and 403 without the header `X-GIR-Switch: 1` (a cross-site form cannot send it).
  - It refuses with 400 for any other mode or a missing confirm word, and with 429 within 5 s of the last flip.
- **The session check is gir-preview's own:** intraday/sitelogin.py cookie_ok, the website's own check. The switch is never usable without the sign-in, even from this machine.
- **Log:** every web request, refused ones too, is written to /home/globalbot/gir_mode.log with who / when ("by the signed-in website session from <ip>"); the gir script adds its own "mode OLD (by root)" line.

## Page (Settings, Ctrl+,): GIR MODE panel at the top of the middle column
- **Status:** the mode chip (NEW desk green / OLD alerts amber), old senders muted n of 12, old AI ON / OFF, desk trade lines ON / OFF, the last flip.
- **Buttons:** "Switch to OLD alerts" and "Back to NEW desk"; the current mode's button is disabled.
- **Built-in confirm step:** a click shows what will change plus "CONFIRM · OLD / NEW" and Cancel. It closes by itself after 20 s and nothing is sent before CONFIRM.
- **Reasons, always shown:** Flip to OLD when: no card 15 min after 09:15 · more than 6 rings in 15 min · a wrong-side ring.

## OPEN - needs a yes: the website does not reach the switch yet
girtrader.com goes Caddy -> dashserve (8090, old engine, not touched). dashserve forwards GET /preview/* to gir-preview without the cookie, and forwards no POST except /api/ask. So, signed in on the website, the panel shows "mode not known · website route pending · for now on the server: gir mode old · gir mode new" (the NOTE row).
- **Proposed fix (not applied):** one Caddy `handle /preview/api/gir/*` block that sends only these two paths straight to 127.0.0.1:8100; everything else stays on dashserve. gir-preview checks the session itself.
- The draft is validated (`caddy validate`): pages agent scratchpad girmode/Caddyfile.DRAFT.
- **To apply:** copy it to /etc/caddy/Caddyfile, then `systemctl reload caddy` (graceful).
- **The alternative** is 2 forwarding lines in dashserve.py (old engine). Either needs his yes.

## Tests (never a real flip)
- **Flips:** only against a test copy of gir-preview (127.0.0.1:8105, now stopped) whose GIR_BIN is a copy of /usr/local/bin/gir with every flag path moved to a scratchpad folder; the flags were checked file by file.
- **Refusals:** on the real server (GET / POST without a session, forged cookie). A signed-in GET of the real status is read only.
- **Real page:** the button was clicked only to open the confirm step, then Cancel.

## Undo
`cp -p v2/server/preview.py.bak1011 v2/server/preview.py` + `systemctl restart gir-preview` (after hours, edit lock); `cd v2/pages && cp -p settings.html.bak1013 settings.html && cp -p static/settings.js.bak1013 static/settings.js && cp -p static/settings-v2.css.bak1013 static/settings-v2.css`.

Shots (P&L masked): girdata/review/monday/D_gir_mode_shots/ (real, test copy before / after OLD) and outside/.

## Rows
| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| real gir-preview 8100: refuses without the website session (GET status gives no data, POST flip 403, forged cookie both ways) | GIR MODE API | - | inside | PASS | 200 {"ok": false, "signed_in": false, "why": / 403 / 403 / 200 |
| test copy 8105: refuses without the website session (GET status gives no data, POST flip 403, forged cookie both ways) | GIR MODE API | - | inside | PASS | 200 {"ok": false, "signed_in": false, "why": / 403 / 403 / 200 |
| the real mode never changed by the refusals | GIR MODE API | - | inside | PASS | never flipped |
| real 8100, signed in: GET status reads the real mode (read only) | GIR MODE API | - | inside | PASS | {'mode': 'new', 'never_flipped': True, 'muted': '12 of 12', 'old_ai': 'OFF', 'desk_lines': 'ON', 'last': ['2026-11-21 10:20:59 IST web REFUSED mode request: no valid website session (from 127.0.0.1)', '2026-11-21 10:23:54 IST web REFUSED mode request: no valid |
| signed in but no switch header / a shell-text mode / no confirm word -> refused | GIR MODE API | - | inside | PASS | 403 / 400 / 400 |
| test copy: POST mode old runs the (test) script: mode old, 0 of 12 muted, old AI ON, desk lines OFF | GIR MODE API | - | inside | PASS | 200 · {'mode': 'old', 'muted': '0 of 12', 'old_ai': 'ON', 'desk_lines': 'OFF'} · flags muted 0 |
| test copy: POST mode new -> 12 of 12 muted; the log has who / when for each web flip | GIR MODE API | - | inside | PASS | ['2026-11-21 10:24:05 IST web request: mode NEW by the signed-in website session from 127.0.0.1 (gir-preview Settings button)', '2026-11-21 10:24:05 IST mode NEW (by root)'] |
| the real mode is still unchanged after the test flips | GIR MODE API | - | inside | PASS | never flipped |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:24:05 IST mode NEW (by root) Switch to OLD alerts Back to NEW des |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE test copy) | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| click "Switch to OLD alerts": the confirm step shows (what changes) and NOTHING is sent yet | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | Switch to OLD alerts now? The old senders and the old AI come back at once; the desk's tra · test mode still new |
| CONFIRM · OLD (test copy): the panel reads OLD alerts, 0 of 12 muted, old AI ON; the test flags flipped | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | GIR MODE fallback switch · instant · no backlog OLD alerts old senders muted 0 of 12 old AI ON desk trade lines OFF last: 2026-11-21 10:24:18 IST mode OLD (by r |
| no cut text (Settings GIR MODE after OLD) | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| Back to NEW desk + CONFIRM (test copy): NEW desk, 12 of 12 muted | Settings GIR MODE (test copy) | 1366x768 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:24:27 |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (real) | 1366x768 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:23:54 IST web REFUSED mode request: no valid website session (fro |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (real) | 1366x768 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE real) | Settings GIR MODE (real) | 1366x768 | inside | PASS | 0 cut · prose with a tooltip: 1 |
| real page: the button only opens the built-in confirm step; Cancel closes it and nothing changed | Settings GIR MODE (real) | 1366x768 | inside | PASS | True -> False · mode never flipped |
| 0 page errors | Settings GIR MODE (real) | 1366x768 | inside | PASS | none |
| no sideways scroll | Settings GIR MODE (real) | 1366x768 | inside | PASS | 1366 px |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:24:27 IST mode NEW (by root) Switch to OLD alerts Back to NEW des |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE test copy) | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| click "Switch to OLD alerts": the confirm step shows (what changes) and NOTHING is sent yet | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | Switch to OLD alerts now? The old senders and the old AI come back at once; the desk's tra · test mode still new |
| CONFIRM · OLD (test copy): the panel reads OLD alerts, 0 of 12 muted, old AI ON; the test flags flipped | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | GIR MODE fallback switch · instant · no backlog OLD alerts old senders muted 0 of 12 old AI ON desk trade lines OFF last: 2026-11-21 10:24:48 IST mode OLD (by r |
| no cut text (Settings GIR MODE after OLD) | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| Back to NEW desk + CONFIRM (test copy): NEW desk, 12 of 12 muted | Settings GIR MODE (test copy) | 1600x900 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:24:56 |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (real) | 1600x900 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:23:54 IST web REFUSED mode request: no valid website session (fro |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (real) | 1600x900 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE real) | Settings GIR MODE (real) | 1600x900 | inside | PASS | 0 cut · prose with a tooltip: 1 |
| real page: the button only opens the built-in confirm step; Cancel closes it and nothing changed | Settings GIR MODE (real) | 1600x900 | inside | PASS | True -> False · mode never flipped |
| 0 page errors | Settings GIR MODE (real) | 1600x900 | inside | PASS | none |
| no sideways scroll | Settings GIR MODE (real) | 1600x900 | inside | PASS | 1600 px |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (test copy) | 390x844 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:24:56 IST mode NEW (by root) Switch to OLD alerts Back to NEW des |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (test copy) | 390x844 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE test copy) | Settings GIR MODE (test copy) | 390x844 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| click "Switch to OLD alerts": the confirm step shows (what changes) and NOTHING is sent yet | Settings GIR MODE (test copy) | 390x844 | inside | PASS | Switch to OLD alerts now? The old senders and the old AI come back at once; the desk's tra · test mode still new |
| CONFIRM · OLD (test copy): the panel reads OLD alerts, 0 of 12 muted, old AI ON; the test flags flipped | Settings GIR MODE (test copy) | 390x844 | inside | PASS | GIR MODE fallback switch · instant · no backlog OLD alerts old senders muted 0 of 12 old AI ON desk trade lines OFF last: 2026-11-21 10:25:23 IST mode OLD (by r |
| no cut text (Settings GIR MODE after OLD) | Settings GIR MODE (test copy) | 390x844 | inside | PASS | 0 cut · prose with a tooltip: 0 |
| Back to NEW desk + CONFIRM (test copy): NEW desk, 12 of 12 muted | Settings GIR MODE (test copy) | 390x844 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:25:31 |
| GIR MODE panel: the mode + old senders muted n of 12 + old AI + desk trade lines + the 3 reasons to flip | Settings GIR MODE (real) | 390x844 | inside | PASS | GIR MODE fallback switch · instant · no backlog NEW desk old senders muted 12 of 12 old AI OFF desk trade lines ON last: 2026-11-21 10:23:54 IST web REFUSED mode request: no valid website session (fro |
| two buttons; the one for the current mode is disabled | Settings GIR MODE (real) | 390x844 | inside | PASS | NEW desk [['Switch to OLD alerts', False], ['Back to NEW desk', True]] |
| no cut text (Settings GIR MODE real) | Settings GIR MODE (real) | 390x844 | inside | PASS | 0 cut · prose with a tooltip: 1 |
| real page: the button only opens the built-in confirm step; Cancel closes it and nothing changed | Settings GIR MODE (real) | 390x844 | inside | PASS | True -> False · mode never flipped |
| 0 page errors | Settings GIR MODE (real) | 390x844 | inside | PASS | none |
| no sideways scroll | Settings GIR MODE (real) | 390x844 | inside | PASS | 390 px |
| outside, not signed in: the status path ends at the login page (never the switch) | GIR MODE API | - | outside | PASS | 200 https://girtrader.com/login |
| outside, not signed in: POST refused | GIR MODE API | - | outside | PASS | 403 |
| outside, signed in: the website does not pass the session to the switch yet (route pending) | GIR MODE API | - | outside | NOTE | 200 {"ok": false, "signed_in": false, "why": "sign in on the website first"} |
| outside: the panel renders with both buttons, the reasons, and (route pending) says to use the server; buttons disabled | Settings GIR MODE (outside) | 1366x768 | outside | PASS | GIR MODE fallback switch · instant · no backlog mode not known website route pending for now on the server: gir mode old · gir mode new Switch to OLD alerts Back to NEW desk Flip to OLD when: no card  |
| no cut text (Settings GIR MODE outside) | Settings GIR MODE (outside) | 1366x768 | outside | PASS | 0 cut · prose with a tooltip: 0 |
| 0 page errors | Settings GIR MODE (outside) | 1366x768 | outside | PASS | none |
| no sideways scroll | Settings GIR MODE (outside) | 1366x768 | outside | PASS | 1366 px |
| outside: the panel renders with both buttons, the reasons, and (route pending) says to use the server; buttons disabled | Settings GIR MODE (outside) | 1600x900 | outside | PASS | GIR MODE fallback switch · instant · no backlog mode not known website route pending for now on the server: gir mode old · gir mode new Switch to OLD alerts Back to NEW desk Flip to OLD when: no card  |
| no cut text (Settings GIR MODE outside) | Settings GIR MODE (outside) | 1600x900 | outside | PASS | 0 cut · prose with a tooltip: 0 |
| 0 page errors | Settings GIR MODE (outside) | 1600x900 | outside | PASS | none |
| no sideways scroll | Settings GIR MODE (outside) | 1600x900 | outside | PASS | 1600 px |
| outside: the panel renders with both buttons, the reasons, and (route pending) says to use the server; buttons disabled | Settings GIR MODE (outside) | 390x844 | outside | PASS | GIR MODE fallback switch · instant · no backlog mode not known website route pending for now on the server: gir mode old · gir mode new Switch to OLD alerts Back to NEW desk Flip to OLD when: no card  |
| no cut text (Settings GIR MODE outside) | Settings GIR MODE (outside) | 390x844 | outside | PASS | 0 cut · prose with a tooltip: 0 |
| 0 page errors | Settings GIR MODE (outside) | 390x844 | outside | PASS | none |
| no sideways scroll | Settings GIR MODE (outside) | 390x844 | outside | PASS | 390 px |
