# GIR PHONE RUNBOOK (one page, for the trader)

GIR never places orders. If anything below happens, your own trading is not affected - only GIR's messages.

## WHERE TO LOOK FIRST
- The page: girtrader.com
- The health check (no login): girtrader.com/preview/api/gir/status.json
  - "overall": "OK" = all well; "PROBLEM" = it lists what is wrong
- Your phone alarm app (ntfy): P1 alarms only (server, Kite, AI credit, Telegram, disk, backup)

## NO MESSAGES FROM GIR
- GIR sends a HEARTBEAT line every 30 min (09:30 to 15:30) to the System topic
- No heartbeat for 35 min = something is wrong
- Type in the System topic: /gir status
- If no answer in 2 min: open the health check link above
- If the desk is down and you want alerts now: /gir mode old (see below)

## THE PAGE IS DOWN
- Telegram still works without the page
- Your phone alarm says "page server down" if it is down
- Nothing to type - the server restarts it by itself
- If still down after 10 min: call (below)

## KITE KEY "DEGRADED"
- One of the 4 Kite keys failed the 08:20 check
- Its prices are marked STALE: GIR gives no GO NOW on them
- GIR retries it at 08:25, 08:35 and 08:45 by itself
- "Risk gates blind" = GIR could not read your positions / orders / funds
  - then GIR gives NO BUY at all - your Kite app is the truth

## AI PROBLEMS - THREE DIFFERENT MESSAGES
- "AI CREDIT EMPTY" = the money ran out
  - fix: top up at console.anthropic.com
- "AI KEY REFUSED" = the key was refused, not the money
  - fix: check the key at console.anthropic.com
- "AI PROVIDER DOWN" = Anthropic is not answering, not the money
  - fix: nothing - wait; GIR retries by itself
- In all three: GIR runs on rules; shock alerts stay on

## TELEGRAM DEAD
- GIR retries every message once; 3 failures in 10 min = a phone alarm (ntfy)
- Check the page and the health link - they still work
- If Telegram itself is down, wait; GIR keeps working on the page

## WHAT TO TYPE
- In the GIR group, System topic:
  - /gir status = shows the mode and the reasons to flip
  - /gir mode old = COLD fallback: the parked old programs start again (about 2-5 minutes), then the old alerts speak
  - /gir mode new = back to the new desk (Monday default)
- On the server (or ask the helper): gir mode old / gir mode new / gir status
- The website Settings page has the same GIR MODE switch
- WEEK 1 NOTE (21 Nov 16:50 order): the old programs are PARKED (stopped) until Fri 27 Nov
  - "gir mode old" starts them again: a cold start, about 2-5 minutes, then check with /gir status
  - the old price engine stays ON (the new desk reads its prices), silent; falcon is parked
- When to flip: the 6 reasons GIR sends as "FLIP REASON n is TRUE"
  - flip back to NEW when the cause is fixed

## CARRY (ONLY IF YOU CHOOSE TO)
- NO CARRY by default; GIR never carries for you
- Declare it (helper on the server): python3 -m analyst.carry declare <symbol> --stop <price>
- Max 1 carry, 0.5% risk; 09:08 next day GIR sends EXIT / HOLD / STOP
- Mon 23 -> Wed 25: two nights (Tue 24 is a holiday)

## WHO TO CALL
- Name: ______________________
- Phone: ______________________
- Second person: ______________________
