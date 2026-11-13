# GIR — handover note (as of 13 Nov 2026)

Read this first in any new chat about GIR. It says what GIR is, how changes reach the server, Rama's standing rules,
what the recent patches did, and what is still open.

## 1. What GIR is

- **GIR** is Rama's F&O intraday alert and trading system: alerts to Telegram, a website at https://girtrader.com.
- **Server:** a DigitalOcean droplet (address: ask Rama), code in `/home/globalbot/intraday`.
  Resized on 12 Nov 2026 to **4 vCPU / 16 GB RAM** (was 8 GB; swap was 65–78%, now 0%).
- **Main services** (systemd): `gir-intraday` (the engine, engine2.py), `gir-exchange` (NSE/BSE filings, results),
  `gir-dash` (page server, dashserve.py, 127.0.0.1:8090), `gir-desk`, `gir-newsroom`, `gir-newshunt` (15-s loop: news hunt,
  profit booking, push/pull, exit watch, results reaction), `gir-tvwatch`.
  Timers: `gir-govwatch` (2 min), `gir-digest`, `gir-pushstudy`, `gir-fullaudit`, `gir-preopen` and others — all enabled.
- **Not GIR's:** the `gir-crypto-*` services (a separate project, left off) and `gir-telegram-cmd` (off, unused for 3+ days).
- **Telegram channels:** GIR TRADE NOW (P1 calls and exits, ambulance sound), GIR Box Picks (critical, nee-naw sound),
  the GIR group topics, and a System channel (audits).
- **AI reader:** Anthropic API. GIR's own daily cap: `data/llm_budget.json` = $10/day (raised 13 Nov).
  The API credit currently comes from a promotional grant that expires at the end of November; a reminder is set in the original
  chat for 28 Nov 19:00 IST to check whether a December grant appears.

## 2. How changes reach the server

- Patches are self-testing installers on branch **`ccr-67e340f1-sko8xd`** of `krishnut85-stack/my-first-site`, folder `intraday_patches/`.
- Rama runs one with:
  ```
  cd /root/sectorbot && git fetch origin ccr-67e340f1-sko8xd && git show origin/ccr-67e340f1-sko8xd:intraday_patches/install_pNNN.sh > /tmp/install_pNNN.sh && bash /tmp/install_pNNN.sh
  ```
- **Every installer:** backs files up (`.bakTS`), applies anchored edits (refuses if an anchor is not found exactly once),
  compiles, runs its own tests, checks the page JS with `node --check`, restarts only what it must, and **puts the old files
  back on any failure**. A re-run says "already in".
- Installers that restart senders refuse **09:00–15:35 IST** unless given `now`. Page-only patches are safe any time.
- Before giving a patch: test it locally on copies of the server files (scratchpad), dry-run the installer twice.
- **Read-only tools** in `intraday_patches/` (change nothing): `alertaudit.sh` (a day's rings, repeats, contradictions, P1 right/wrong,
  calls the vote turned down), `pushaudit.sh` (who-is-pushing measured), `livecheck.sh` (services, memory, live files),
  `resultline.sh SYM` (one share's day: filing → alerts → price), `resultsnight.sh` (after-hours results with numbers + tomorrow's
  results), `circuitcheck.sh`, `whylate.sh`, `storycheck.sh`, `tvbench.sh`.

## 3. Rama's standing rules (verbatim intent — always follow)

- `/home/globalbot/.env` — read, never copy. Never paste keys into a chat; point at the server's `.env`.
- `TG_CHAT_FO` belongs to NEWSHAWK — never used. `TG_CHAT_OI` belongs to another program — don't touch it.
- **Nothing muted without Rama's word.** Any change that makes something stop ringing is his decision — ask first.
- Never send the YouTube cookie file or the site password in chat.
- Don't touch `gir-watchdog` or `paper_exit_monitor` without his word.
- No model identifiers in commits or artifacts.
- **Only F&O stocks** in alerts and lists.
- **Rama is not an F&O expert.** Make the F&O judgement calls yourself, explain in plain words, and only ask him what is truly his:
  money/risk, whether he wants something, or a trade-off. Don't call GIR's pattern alerts "your rules". If a request could hurt
  him (e.g. ring the moment something starts), say so before building.
- **No pause on new work.** Review every evening; anything critical is fixed immediately.
- **Every evening review starts with a regulator & policy watch** (IRDAI / SEBI / RBI drafts or final rules pending for F&O shares,
  what each could do, expected dates) — he asked for this on 13 Nov.

## 4. What the recent patches did (207–248)

| Patch | What |
|---|---|
| 207 / 207b | Compact SECTORS; IMPORTANT one row per share; ALERTS box P1/P2/P3; phone fold line |
| 208 | PUSH WATCH: 12 pushers, push kinds (NEW MONEY / FORCED OUT / BOTH / TIDE ONLY), push study |
| 209b–d | News hunt (sector jumps, the reason hunt, policy lane); India / foreign filter |
| 210 | Govt watch reads PIB's Hindi; Cabinet / ₹5,000 cr+ = critical |
| 211 / 212 | Alert rows link to share + story; news "about it" matcher; AI credit-out alarm |
| 213 | PROFIT BOOKING / SHORT COVERING; 🌐 FOREIGN label |
| 214 / 215 | Push/pull strip on every share screen; /pushpull; PUSH / PULL STARTED alerts; 🧲 list; F&O only |
| 216 | Checklist says 🟢 LIVE / 🟠 NOT LIVE (age) |
| 217 | 🧩 OI reading is P1 only when measured (55%+ of 50+); 14:00 study's NIFTY |
| 218 | Pre-open (09:00–09:15) index boxes show today's values marked PRE-OPEN; no flip back to yesterday |
| 219 | Push: the market's FII/DII figure no longer shown as every share's; 🔵 OWN MOVE vs ⚪ TIDE ONLY |
| 220 | Chart ACT mark in its side's colour (CE green, PE red) |
| 221 | Push/pull box "IN SIMPLE WORDS"; share window says "off live ticks", not "market closed", in market hours |
| 222 | EXIT WATCH: every P1 followed — 🎯 BOOK HALF, 🛑 EXIT (stop / turned / the rest), ⏰ TIME EXIT 15:05 |
| 223 | Results-day watch: 🚨 RESULTS REACTION (P1, ~1 min after a filing that moves the share; the price is the verdict); profit booking on results shares waits for a real turn; 🧱 CIRCUIT NEAR / BAND WIDENED |
| 224 | P1 + exits → GIR TRADE NOW (ambulance sound); critical → Box Picks (nee-naw); page sounds; files in `intraday_patches/sounds/` |
| 225 | The P1 VOTE: 4 of 6 checks (desk, futures, VWAP, push, NIFTY, not late); opening 09:15–09:25 needs 5 of 6, max 3; else P2. Results reactions never voted down |
| 226 | IRDAI in the govt watch (its pages + news search; insurance shares); exit watch default stop 1% |
| 227 | Profit booking / short covering only on a real turn (5 min no new extreme; volume proof only on a candle against the move) — all shares |
| 228 | Ring rules: one ring a share / 15 min; contradiction guard (opposite way within 30 min rings only if a 5-min candle confirms → ⚠ REVERSAL). Always ring: P1, results reaction, exits, 🧱 circuit, GIR alarms. Held alerts arrive silently marked 🔕 |
| 229 | Pattern alerts ring only when a GIR alert on the share agrees |
| 230 | "📜 YOUR RULE" renamed "📜 PATTERN" (wording only; readers accept both) |
| 231 | Every result reaches Telegram with its numbers + "plain read" (STRONG / STEADY / MIXED / FLAT / WEAK); IN LINE without sound; results desk drops filed shares |
| 232 | FII/DII from every named deal (not the top 12); 5 days = push, 30 days = context; delivery labelled "FII or DII — not named" |
| 233 | WRITERS pushes only on a change (a wall forming is context); ALGOS neutral. Writers pushing 214 → 28, ALGOS 209 → 0 |
| 234 | COMPANY only for news naming the company, from the last 18 h. COMPANY pushing 129 → 77 |
| 236 / 237 | The "special force": `gir-eventwatch` (eventwatch.py + eventbrain.py) watches results shares a week before / after; strong events or a 2% move; AI read; max 40 shares; insurers as peers. Eye-power alerts (nee-naw), not buy calls |
| 238 | Share window: tab name (⌂ GIR HOME / SYM ₹px), RSI pane kept in the box + daily RSI tag, sticky name/price, OI marks explained on hover, one refresh chain |
| 240 | Self-check opens the OI BUILD-UP tab on a narrow window (it read the price chart and said FAIL) |
| 241 | SECTORS = the F&O shares' average (as ROTATION; NSE index on hover only where it is the group); ROTATION fits its box |
| 242 | 📅 THE WEEK at 08:30 after the brief: last 5 sessions · today · next 7 days · plain reminders |
| 243 | Pre-open 09:08-09:15: every F&O share shows NSE's pre-open price (live tick wins) |
| 244 | Who is pushing: earlier evidence (deals, delivery, news, filings, broker notes) against today's price (0.7%+) is shown, not counted |
| 245 | The push dot shows for every reading (OWN MOVE with nobody named was blank) |
| 246 | Ubuntu updates Saturdays 09:00 IST only, never auto-restart services (13 Nov 11:46 libc update restarted all GIR); prices flow during a mid-day catch-up; 🚨 LIVE FEED DOWN / 🔌 SOCKET BACK |
| 247 | 🏦 MACRO WARNING: rates / Fed / crude / rupee / tariffs -> the sectors that move first; 08:30 + live when prices confirm; scored at the close |
| 248 | The share window's top line: its sector and the sector's move today, the same numbers as SECTORS |
| 239 | News filed under the right share: everyday-word symbols (AMBER, OIL, IDEA, ETERNAL, TRENT, TITAN …) need the full name or "SYM shares / Q2 / results"; false phrases refused (AMBER Alert, oil prices, BSE Sensex, MCX gold prices, Olympics, Trent Boult); searched headlines stored only when about the company; 4-day clean-up (undo: `p239clean.py DIR --undo`) |

Replay of 12 Nov through 228 + 229: rings **325 → 192**, none of the 48 always-ring alerts held.

## 5a. 13 Nov evening - the batch and the list (after 15:35)

**Run in this order:** 246 (no surprise restarts + LIVE FEED DOWN) · 242 (📅 THE WEEK at 08:30) · 243 (all shares in the pre-open) ·
244 (earlier evidence against today's price is not a push) · 247 (🏦 MACRO WARNING). Already installed today: 239, 240, 241, 245. Ready, page only: 248 (the share's sector on its top line).

**Then review (regulator watch first):** alertaudit.sh + pushaudit.sh outputs · Rama's screenshots of wrong alarms · the P1 vote · PUSH/PULL STARTED accuracy.

**Decisions waiting for Rama:**
1. Results-window shares speak with ONE voice (the special force, 📑 RESULTS tag, "the number decides"): GIR's generic early alerts (PUSH / PULL STARTED,
   writers) on those shares go silent 🔕 - his call (muting rule).
2. A separate Telegram channel "GIR Results Agent" for its own phone tone (he creates it, adds the bot); a third tone on the page.

**To investigate / fix:**
- The F&O checklist said "RESULTS: none soon" for ABB on its results day (13 Nov) - must say RESULTS TODAY and fail the check.
- ABB desk "confirmation reading due 12:38" still showing at 12:42 (desk restarted 11:46 with everything) - the confirmation must resolve or say not confirmed.
- Why the special force (eventwatch) did not flag ABB before GIR's PUSH STARTED (12:36).
- GVT&D: GIR said OWN MOVE while the chain showed call writers covering 4200/4300 and put writers building 4400 - the writers' reader missed it.
- "IN SIMPLE WORDS - its whole sector is -0.7%" (whymove) must use the same sector figure as SECTORS / the new sector tag.
- IndiGo / LIC (MSCI) headlines marked 🌐 foreign (the older foreign rule).
- Rama's GVT&D 4400 CE trade (-₹49.5k) - review if he wants.
- Weekend: one planned reboot Saturday after 09:30 ("System restart required" after the 13 Nov libc update).

## 5. Open items (in order)

1. **13 Nov evening:** Rama runs `bash /tmp/alertaudit.sh` and `bash /tmp/pushaudit.sh` after 15:35. First full day with 217–234 together.
   Judge: rings per day, P1 right %, what the vote turned down, PUSH/PULL STARTED right % (was 52 of 134 = 39% on the old reading).
   If PUSH/PULL STARTED stays under 50% → propose making it silent (Rama's call).
2. **News reader marks index-inclusion news as foreign:** `newsalert.about_it("LICI", "LIC makes the cut in the MSCI Global Standard Index")`
   returns `"foreign"` (so does "IndiGo cancels 200 flights …" — a short name with no India word). Fix the foreign filter (newshunt FOREIGN_RX / about_it) so MSCI / index inclusion of an Indian share is Indian.
3. **Build the automatic evening self-check** (after 15:45, to Telegram System): every "results just filed" got numbers within 5 min;
   every P1 got its exits; news lag; contradictions; results verdicts the price disagreed with; rings and right %.
4. **Step 2 of the ring governor** (Rama to decide after the audit): a daily cap on non-trade 🚨 critical lines.
5. **paper_exit_monitor is down** (watchdog fails every 5 min) — ask Rama before looking (standing rule).
6. **p163test fails** ("IRDAI order on Policybazaar → ⚠️ SHOCK WATCH") in the full audit — read its full failure.
7. WHY lines / "WHY IT IS MOVING" box may still show unrelated hunt headlines — apply patch 234's rule there if seen.
8. Optional, discussed: a "watch this share" list (ring on any new build-up for a few chosen shares).
9. **28 Nov:** check the promotional AI credit renews for December; else a small auto-reload (Rama's decision).

## 6. Useful facts

- PAGEIND 12 Nov: results 14:29:53, −2% at 14:30:30, −10% band 14:36:45, −13.2% after the band widened. Profit +4%, margin 21.7 → 20.8%,
  volume +5.5% vs a double-digit target. GIR's old reader said "IN LINE" — the reason for 223 / 231.
- POLICYBZR: IRDAI's 23 Sep **draft** (commission caps, expense limits, dark-pattern ban) is still a draft; final rules expected for April at
  the earliest. Final rules softer than the draft → relief rally possible; as harsh → another fall. GIR's IRDAI watch rings on it.
- NSE publishes no per-share FII/DII figure in the day; only bulk/block deals (rare on F&O shares) and delivery (unnamed).
