# GIR_SPEC - what GIR must be (the single source of truth, 18 Nov)

For the Claude session running ON the GIR server (/home/globalbot/intraday). Build GIR exactly to this file. When the trader adds
something, this file is updated and you are told to re-read it.

## 0. How to work and report (no shortcuts)

- Read the WHOLE file before starting. Every numbered item is a requirement, not a suggestion.
- Keep a checklist table: item number -> done / not done -> what you changed -> screenshot or test output. Update it after each item.
- **Never report "complete" until every item is done and tested.** If an item cannot be done, say so plainly with the reason.
- Test every change on real recorded data (replay a past day) before switching it on, and check the page at 1600x900, 1366x768 and
  phone width (390). Keep a backup of every file you change and one undo line per change.
- Page changes are tested for 30 minutes on replayed data before they go live. No page change during market hours (09:00-15:35 on
  weekdays) unless the trader says "now".
- Standing rules: never use TG_CHAT_FO or TG_CHAT_OI; never print or copy .env; do not touch gir-watchdog or paper_exit_monitor;
  no made-up data (if GIR does not know, it says so); F&O shares only for calls (sector measures use all NSE shares).
- When the trader asks a question, answer it first, each part separately, before doing more work.

## 1. The method - this is GIR's brain (every sector, both directions)

The trader's method, in his words: "It's sector-driven. Find which sector goes up or down from the macro, Indian and market news,
study every share in it, pick the ones in position, tell me GO NOW, and give it time."

1.1 **Know the map.** Every F&O share, its sector, and what drives that sector:
    banks - rates, RBI, bond yields · IT - the rupee, US markets · metals - global metal prices, China · oil & gas, paints - crude ·
    jewellers, gold loans - gold · cables & wires - copper · auto - monthly sales, input costs · pharma - US FDA, the rupee ·
    realty - rates · capital markets - SEBI · FMCG - rural demand, input costs · and so on for every sector. Use the knowledge base.
1.2 **Step 1 - confirm the sector's direction:** a steady move one way from the open to about 10:00 (not a spike); the futures
    build-up agrees (short build-up down, long build-up up); the news confirms (CNBC-TV18, Economic Times, Moneycontrol, or the
    driver itself). Then: "SECTOR DOWN / UP - confirmed since HH:MM · driver · news · build-up".
1.3 **Step 2 - list every F&O share in that sector**, each with: zone (overbought / oversold / neutral: daily and 5-min RSI, distance
    from the 20-day high and low), speed (beta to the sector, usual day range), size (large / mid / small cap), already moved today,
    room left to the next support or resistance (option floor / roof, 20-day low / high), futures money (fresh shorts / longs).
1.4 **Step 3 - rank them by potential.**
    - Falling sector -> PE. First: the overbought share still holding up (the laggard - it catches down), fast-moving, with room to
      fall and fresh shorts. Then the leaders falling with short build-up, and the dependents (gold -> jewellers and gold loans).
    - Rising sector -> CE. First: the oversold share still lagging (it catches up), fast-moving, with room to rise and fresh longs.
      Then the leaders and dependents.
    - Skip shares that have already used their room. **No "top 3" limit** - every share in position is listed.
1.5 **Step 4 - one line per share:** GET READY / GO NOW · PE or CE · strike (at or near the money, this expiry) · trigger · stop ·
    target · hold until. GET READY when the price nears the trigger; GO NOW when the price confirms. The trader decides to buy or sell.
1.6 **Step 5 - patience and follow-up.** Every call says how long to hold. Follow-ups only when something changes: BOOK HALF when the
    move stalls or hits the target, EXIT on a real reversal, the 15:10 exit for what is left. No exit messages for trades the trader
    did not take.
1.7 **Evening (19:45) and 07:15 watch list.** For every driver that moved (gold, silver, copper, steel and iron ore, aluminium, crude,
    the rupee, US markets, bond yields, China, big Indian and world news): which sectors are likely up or down today and why, every
    F&O share they affect, its zone, and which are most likely to move next. Example: "Gold down -> watch PE: TITAN, KALYANKJIL,
    MANAPPURAM, MUTHOOTFIN... KALYANKJIL overbought and still holding - likely to catch down, PE below X".
1.8 **09:08 pre-open:** check the pre-open prices against the watch list; a met trigger becomes GO NOW at the open.
1.9 **Every analyst output ends in an action per share** - GO NOW / GET READY / HOLD / BOOK HALF / EXIT / nothing to do. Never just a
    list of news. A summary like "fresh shorts in jewellers, metals, cables; pharma long build-up" must come with the calls.

### Proof case - 18 Nov (the test every change must pass)
Gold -2%, copper -4%, silver -3%; CNBC-TV18 discussed gold, steel and copper all morning. The sector run said "09:51 METALS & MINING
down"; the sector board (built later) shows "JEWELLERS & GOLD LOANS DOWN - confirmed since 09:20" and "CABLES & WIRES DOWN - confirmed
since 09:20". Shares: KALYANKJIL (overbought, held near -2%, then -5%), TITAN -5.3%, MANAPPURAM -4.6%, MUTHOOTFIN -4%, POLYCAB -5.1%
(copper 5-month low), SAIL -4.4%, NATIONALUM -3.7%, MOTHERSON -4.4%; pharma the only real long build-up. On the day GIR gave no GO NOW
on any of them. **The finished system, replayed on 18 Nov from 09:15, must call these at about 09:20, with the time, price and result
at the close for each, against the old alerts' late list (OPENING 6-11 min late, FIRST MOVE 12-63 min late).**

## 2. The agents - each must feed the analyst, and each must be accounted for

2.1 Agents: news reader, global / world news, world prices, sector, sector rotation, money (futures OI build-up), options (sudden PE /
    CE buying in one strike), pre-open, theme (driver -> sector -> shares), TV watcher, X (off until credits are added).
2.2 Each agent wakes the analyst when it finds something; the analyst answers with an action (1.9).
2.3 Daily (15:45) report per agent: did it run, what did it find, did it wake the analyst, what reached the trader. An agent that ran
    all day and produced nothing is reported, with the reason.
2.4 Must wake the analyst at once, with the shares and direction: a driver moving sharply; a sector confirming (1.2); clarifications,
    denials and "no decision yet" (e.g. SEBI on the MTF limit -> brokers and exchanges); management on TV ("not affecting us");
    broker calls in live blogs (upgrade / downgrade / target price); results and promoter actions.

## 3. News

3.1 Read every new entry of the CNBC-TV18, Economic Times and Moneycontrol live blogs every minute, plus every feed already set up
    (wires, NSE filings, publisher feeds, Google News, the world feed).
3.2 Every F&O share knows its other names (brands, parent, subsidiaries, old names - Zomato -> ETERNAL). Sector stories map to their
    shares (gold loans -> MUTHOOTFIN, MANAPPURAM). No wrong tags (word clashes such as "Force" -> FORCEMOT, "Nippon" -> NAM-INDIA).
3.3 Read correctly: lower commodity margins = more trading = good for MCX; promoter selling, block deals, "below estimates" and
    guidance cuts outweigh a big headline number; "minimal impact" / "priced in" is not a sell signal; a fine is weighed against the
    company's size (a small fine never rings); old news retold is old news.
3.4 Every news item gets a weight 1-5 using the company's size; only 4-5 can ring; night weight-3 stories get conditional calls for
    the morning.
3.5 Weigh votes by each voter's measured hit rate; a voter with no edge counts zero; show "vote against" on a card when it is.
3.6 No duplicates. One news list on the page.

## 4. Alarms and notifications

4.1 **One sound per alert** - the old alarm layer is switched off underneath the new one.
4.2 **Only these ring:** GO NOW, GET READY on a sector call, and the trader's own exits (STOP, BOOK HALF, EXIT, 15:10). Everything
    else is silent on the page (INFO). No PROFIT BOOKING / MOVING / EARLY / RUNNING / "WATCH, not a trade yet" / briefs as alerts.
4.3 Sounds by meaning: CE = notes up, PE = notes down, GET READY = soft chime, EXIT / STOP = low tone, BOOK HALF = bright chime,
    15:10 = gong, GIR DOWN = three beeps.
4.4 Telegram: one decisions channel (GO NOW, GET READY, the trader's exits). Every other topic is off by default. Held "no ring"
    lines go to the page only.
4.5 Browser "ALERT" tabs do not open by themselves unless the trader turns them on.
4.6 The page shows an alert before Telegram (about 5 s earlier).

## 5. The page - organised in tabs, nothing lost, clean look

5.1 **Top bar, always visible:** NIFTY, BANKNIFTY, SENSEX, VIX, expiry and days left, PCR, FII / DII, the ban pill, search with
    suggestions as you type, sounds on/off, live time and data age, AI spend today.
5.2 **Tabs** (each with a one-line purpose at its top):
    1. **SECTOR BOARD** (opens first) - falling sectors with PE plans on the left, rising sectors with CE plans on the right; each
       sector: confirmed or not, since when, driver, news, build-up; all its F&O shares with role, zone, speed, size, room, money and
       plan (section 1). **The GIR ANALYST's latest decision in big text beside the board.**
    2. **SECTOR ROTATION** - where the money is moving (15M / 30M / 1H / TODAY), sectors gaining and losing, the sector run times,
       with real details inside.
    3. **ANALYST** - every decision today, newest first, each ending in an action, with its follow-ups; ASK in a side drawer; the
       19:45 and 07:15 watch lists.
    4. **MY TRADES** - positions, live P&L, their exits.
    5. **NEWS** - one list: time, share, headline, the AI's direction and weight, source; filters (all / my shares / policy /
       critical / market).
    6. **MONEY & OI** - F&O money, BIG MONEY, futures by month, long / short build-up (LB / SB / SC / LU), option chains, OI scenarios.
    7. **MARKET** - NIFTY / BANKNIFTY chart, F&O movers, results, the EARLY list, the F&O tape.
5.3 **Every feature of the old page is kept** in one of the tabs. Give a table: old place -> new tab, for the trader's approval
    before switching. The old page stays at /old.
5.4 **Must work:** a share name anywhere opens that share's own page (chart, levels, option chain, futures, WHY) with a LIVE price and
    chart; sector click opens in place with live numbers at once; the analyst box shows the latest decision on top and does not blink;
    the PRE-OPEN screen never blocks the page; the ALL SECTORS dropdown filters the page; every list scrolls with a visible bar and
    up / down buttons.
5.5 **The look - a professional trading app:** dark background; big clear text (share names and % at least 14-16 px); space between
    rows; one colour meaning (green = up / CE, red = down / PE, amber = GET READY, grey = info); no walls of tiny text, no boxes
    squeezed together, nothing overlapping or cut off; the sector board and the analyst's latest decision biggest and at the top.
    Show a screenshot of the new layout before switching it on.

## 6. Cost - $10 a day, used wisely, never silent

6.1 Hard cap in the code: **$10 a day**, split across 24 hours (about $3 night and morning prep, $6 market hours, $1 reserve for big
    news). It must really stop at the cap (on 18 Nov it spent $27.24 against a $5 cap - find and fix why).
6.2 Models: Fable only for the final GO NOW check and the 07:15 sector plan; Sonnet for the board's reasoning and follow-ups; Haiku
    for reading every news item. Prompt caching on every call (target 80%+ cached); send only the facts each call needs.
6.3 When the cap is reached: the board keeps making calls from the numbers, Haiku keeps reading, one message to the trader.
6.4 Show the spend on the page, and daily at 15:45: spend by model and by hour, and what it bought (calls made, right or wrong,
    cost per useful call).

## 7. Daily checks

7.1 07:15 - the watch list (1.7). 09:08 - the pre-open check (1.8). 10:00 - the number checker on live data.
7.2 15:45 - the miss audit: every F&O share that moved 2%+, when the move began, whether GIR called it before (and which agent), and
    why not if it did not; the agents' report (2.3); the cost report (6.4); the calls' results.
7.3 Heartbeat: ring when any GIR service stops or data goes stale (prices > 2 min, sector / analyst / desk data > 5 min in market
    hours), once per problem and again on recovery.

## 8. Open decisions for the trader (remind, do not act)

- The X agent: switch on only after X credits are added (X search reaches back 7 days).
- gir-watchdog fails every 5 minutes because paper_exit_monitor is off.
