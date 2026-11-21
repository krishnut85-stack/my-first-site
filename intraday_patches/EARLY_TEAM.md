# THE EARLY-SIGNAL TEAM (17 Nov night) - for the Claude session running ON the GIR server

Rama, in his words: "Build everything - AI agents for special forces. Monitor the global news, sector investment, sector rotation and so on -
all inclusive - to get an early signal." The 15:45 miss audit on 17 Nov showed why: 39 F&O shares moved 2%+, only 10 had an early call;
5 of the 8 "in the news, no call" shares had their news in GIR before 09:15, but it was never AI-read, so the analyst never woke.

**Build the whole team tonight, in one go, without waiting for Rama between steps.** The analyst (analyst.py) is the hub; each part below is
an agent that wakes it, and every wake ends in ONE 📍 HAPPENING / 🔮 WHAT NEXT / ✅ ACTION call - or "nothing to do", kept quiet on the page.
Levels only from GIR's real numbers (as NEXT_STEPS step 2). F&O shares only.

1. **News agent:** every news item on an F&O share is AI-read the moment it arrives, 24 hours (the quick model); a clear direction and
   strength wakes the analyst at once - ⚡ BE READY in the day, 🌙 BE READY TOMORROW at night (between 22:30 and 06:30 kept for the 07:15
   message).
2. **Global agent:** crude, USD/INR, US futures, gold, copper and the US 10-year watched live, day and night; a sharp move wakes the analyst
   with the shares from knowledge.who_reacts. Global news AI-read and mapped to F&O shares, as policymap does for India.
3. **Sector agent:** sector rotation turning (money in / out of a sector) wakes the analyst with that sector's F&O shares.
4. **Money agent:** a big futures OI build-up on a share wakes the analyst.
5. **Pre-open agent:** at 09:08, the NSE pre-open prices of F&O shares gapping 1%+, matched with the night's news, go to the analyst for a
   call before 09:15.
6. **Ring rule for F&O (ringgov.gate, patch 228):** every exit, book half, stop, 15:10 exit and every 🧠 GIR ANALYST / ⚡ BE READY / 🌙 line
   always rings, whatever its wording. A repeat on the same share is silent only if it is the same direction and type, within 5 minutes, and
   the price moved under 1% since the last ring - otherwise it rings. A call the other way rings at once if the price moved 1% against the
   first call; otherwise keep the 5-min candle check. The patch 387 quiet types stay quiet (SUDDEN may wake the analyst but does not ring).
7. **Miss audit:** an ENTER NOW before the move counts as early; for each 2%+ move, show which agent was first.

## Test, replay, install
- Test each part on copies. Then **replay 17 Nov**: for each of the 39 movers, the time GIR would now call it vs. the time the move began
  (ASHOKLEY 09:21, KAYNES 09:15 gap, GODREJPROP 09:16, BANKINDIA 09:15, AMBUJACEM 09:15 are the ones to beat).
- **If every test passes and the replay is better than 17 Nov, install and restart before 08:30 on 18 Nov** (never 09:00-15:35 on a weekday).
  If a part fails, do not install that part - install the rest and say what failed and why.
- Keep backups and one undo line. Standing rules: never TG_CHAT_FO / TG_CHAT_OI · never print or copy .env · do not touch gir-watchdog or
  paper_exit_monitor · nothing muted without Rama's word · no made-up data.

## In the morning
One short summary for Rama: the replay table, what was installed, what rings today. Then the layout job (LAYOUT.md, step 0 first).
