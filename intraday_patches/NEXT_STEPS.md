# NEXT STEPS - make the GIR analyst fully automatic (17 Nov, after patches 383-388)

For the Claude session running ON the GIR server (/home/globalbot/intraday). Do these in order. Test each step on a copy first (as the
patches do), keep backups, and ask Rama only before restarting a service. The market is closed in the evening, so restarts then are allowed;
never restart the engine 09:00-15:35 on a weekday without his "now".

Rama's requirement, in his words: "The analyst should be automatic. It should tell me what is happening, what will happen and what action to
take. I should not sit, watch and type." And: "First my GIR should ring, then the Telegram."

Standing rules: never use TG_CHAT_FO or TG_CHAT_OI · never print or copy .env · do not touch gir-watchdog or paper_exit_monitor · nothing muted
without Rama's word · no made-up data (if GIR does not know, it says so) · F&O shares only.

## 1. GIR rings first, Telegram second - for EVERY alert
- Today the older alerts reach the page only after Telegram sent them (desk.tg_box logs to tomorrow.db in tgq's on_ok; check engine2.tg_fo
  too). Change every sender to: write the alert to the page's alert log first, then send to Telegram about 5 seconds later. A Telegram
  failure still marks the page line "NOT SENT to Telegram", as now.
- New parts (analyst.py, readyfile.py, girdecide.py if installed): they already write their page file first - add the same ~5 s wait
  before their Telegram send.
- The page: check for new alerts every 2 seconds (the ALERTS list, the 🧠 GIR ANALYST box, the ⚡ BE READY box) instead of 8-10 s.
- Test on today's alert log: for each alert, the page has it before Telegram.

## 2. Every analyst message in three parts
Change analyst.py (SYSTEM prompt, parse(), text_of(), and the page box) so every call is:

    🧠 GIR ANALYST ▼ ANGELONE · PE · ACT NOW · 13:01
    📍 HAPPENING: the facts now (news with the AI's reading, the price, the sector, the money)
    🔮 WHAT NEXT: what is likely and on what condition (and what would turn it)
    ✅ ACTION: BUY CE / BUY PE now - or WAIT with the exact trigger - plus a stop and an exit (book near X, or by 15:10)

- Every level (trigger, stop, target) only from GIR's real numbers: day high / low, last close, 20-day high / low, the option roof /
  floor, the ready file's levels. Drop any level that is not in the facts (as readyfile.write() validates triggers).
- Labels: ACT NOW (rings loud - a trade alert), GET READY (rings - "something is happening"), INFO (silent). Check alertword.tier for the
  new first lines: patch 385 added "🧠 GIR ANALYST .*· NOW" - keep ACT NOW ringing as "act", GET READY as "move", INFO as "read".
- The ASK answers on the page: render **bold** as bold (they show the ** markers now).

## 3. The analyst follows up its own calls
Every reading, for each open CE / PE call of the day: "✅ HOLD - the reason is intact" (page only, quiet) or "🛑 EXIT NOW" /
"🎯 BOOK HALF" with why (rings loud). Only when the verdict changes - not every minute. At 15:10: "⏹ exit what is left" for open calls.

## 4. Night and morning: GIR tells, even when the market is shut
- Outside 09:15-15:30, the analyst reacts to the same triggers it uses in the day (an important AI-read news item, a 🧭 policy story):
  read at once and send "🌙 BE READY TOMORROW · SHARE · CE/PE" with 📍 / 🔮 / ✅.
- Ring between 06:30 and 22:30. Between 22:30 and 06:30 stay quiet and put those into the 07:15 "⚡ BE READY TODAY" (readyfile.wake).

## 5. Heartbeat - a dead agent must never be a silent miss
Ring Rama (Telegram + the page) when any GIR service stops: gir-intraday, gir-desk, gir-dash, gir-analyst, gir-ready, gir-policymap,
gir-newsroom, gir-newshunt, gir-seclive, gir-futlive, gir-headsup. In market hours also when data goes stale: quotes_live.json older than
2 min, data/desk.json, data/analyst.json, data/seclive.json older than 5 min. Once per problem, and again when it recovers.

## 6. Daily miss audit at 15:45
Every F&O share that moved 2%+ (either way) today: when did the move begin (minute data, data/oihist or Kite), and did GIR tell Rama
before it began - ⚡ BE READY, 🧠 analyst, the early alerts (OPENING / FIRST MOVE / SPEED)? If not, why: no data, a late source, a rule,
the AI, or a service down. Show it on the page and send a quiet Telegram summary; keep the list to fix the next morning.

## When done
Show Rama one short summary: what changed, what was tested, and what rings tomorrow, in plain words.
