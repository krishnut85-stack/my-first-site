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
- **AI reader:** Anthropic API. GIR's own daily cap: `data/llm_budget.json` = $5/day.
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

## 4. What the recent patches did (207–234)

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

Replay of 12 Nov through 228 + 229: rings **325 → 192**, none of the 48 always-ring alerts held.

## 5. Open items (in order)

1. **13 Nov evening:** Rama runs `bash /tmp/alertaudit.sh` and `bash /tmp/pushaudit.sh` after 15:35. First full day with 217–234 together.
   Judge: rings per day, P1 right %, what the vote turned down, PUSH/PULL STARTED right % (was 52 of 134 = 39% on the old reading).
   If PUSH/PULL STARTED stays under 50% → propose making it silent (Rama's call).
2. **News reader marks index-inclusion news as foreign:** `newsalert.about_it("LICI", "LIC makes the cut in the MSCI Global Standard Index")`
   returns `"foreign"`. Fix the foreign filter (newshunt FOREIGN_RX / about_it) so MSCI / index inclusion of an Indian share is Indian.
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
