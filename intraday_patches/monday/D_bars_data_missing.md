# Intraday bars on the level charts + "data missing" (coordinator 20 Nov 23:30)

Run 21 Nov 2026 01:36 IST. /preview pages only. gir-preview NOT restarted, server code unchanged (its ChartAdapter already serves ch.<SYM> on request).

**Bars R51: 4 NOTE · 198 PASS** (inside 3 NOTE · 144 PASS · outside 1 NOTE · 54 PASS), at 1366x768 / 1600x900 (mouse) and 390x844 (CDP finger taps + swipes).

## What changed
- **Bars:** the level chart now asks gir-preview for the selected share's ch.<SYM> (`api/state?prefix=ch.<SYM>`).
  - It asks again every 30 s while the market is open and every 5 min when it is closed.
  - Requests go to the same origin, so the outside login cookie carries them.
  - The chart draws 5-minute candles under the level lines. 1m / 5m / 15m is a working toggle where the toggle already existed (F1 chart head, F7 share toolbar).
  - Charts with bars: F1 desk-hunt (its own chart copy), F7 share (D.levelChart) and desk-trade (its own chart; 5-min, no toggle there).
  - The old "price bars: not known - the store has no intraday bars" line is gone from all three.
- **Gaps:** gaps come from the 1-minute samples: a late start, any hole longer than 3 min, or an early end.
  - A gap reads "data missing hh:mm-hh:mm", with a grey band over that stretch of the plot.
  - A share with no samples for the session reads "data missing 09:15-15:30 · no <SYM> samples in the v2 recorder for <day>".
  - On narrow charts a shorter form is used; the full line is always in the tooltip.
  - On a weekend the bars are labelled with their day (e.g. "5-min bars · Fri 20 Nov").
- **No % from an old price:**
  - **Rule:** sh.<SYM>.src_ts is when that price first appeared. If it is older than the session's 09:08 pre-open price, the share shows "data missing" in place of its %, with the old price's time in the tooltip.
  - **Which session:** today from 09:15 on a trading day; on a weekend or holiday, the day of the last quotes file.
  - **Where:** the F1 chart head, F1 MOVERS, F1 MEMBERS, desk-trade F&O MOVERS and its chart head, and the F7 hero.
  - The prev-close line is not drawn, because it would be computed from the old %.
  - D.shares() drops such a share's % everywhere, so it is in neither the UP nor the DOWN rank on any page (F1, F2, desk-trade, phone, morning, scorecard ...).
- **Phone taps on F1 (a fix of my R50 drill-down code, sector-drill.js):**
  - The finger handler of a shell drawn scroll track sat on the track's parent, which on F1 is the whole panel (SECTORS / MOVERS / MEMBERS / ACTION).
  - So every touch in those panels was preventDefault'ed: no tap, no native scroll, and a touch made the list jump.
  - It now sits on the track only. Drill-down R51 re-run: 390 inside 52 PASS, 390 outside 52 PASS, 1366 inside 186 PASS (3 NOT RUN, as before).
- **F1 NO CARD (found by the desk-web re-run after midnight):** with no engine card in the store, F1 did not say the head analyst is not running. It now shows the grey chip + "no engine card either" (desk-hunt.js .bak0052).
- **desk-trade at phone width (found by the 390 test):**
  - The market header (SECTORS / F&O MOVERS / MONEY + DN / UP / ALL) was a sideways strip with ALL off-screen at 390. It now wraps like the positions header.
  - The F&O MOVERS rows printed names over the % (the fixed columns left the name column 0 px). They get a phone grid: ROLE hidden on the phone only, sector line with an ellipsis + tooltip (desk-trade-v2.css .bak0106, desk-trade.js).
- **WHY "more" (found by the desk-web re-run):** on the phone CALL card (and the F1 card), "more" opened the WHY lines, but the page's one-second redraw folded them back. desk-fill.js now remembers the opened call (.bak0125).
- **Tap-safe redraws:** the F1 chip rows (MOVERS tabs and chips, ACTION chips), the F1 chart head and the desk-trade chip rows are now rewritten only when their HTML changes. A rewrite every second could replace the node under a finger between touch and click.

## Fixture (inside only, a TEST COPY of gir-preview on 127.0.0.1:8103; live files only read)
- **Recorder file:** a copy of v2/data/rec/2026-11-20/quotes.jsonl.gz.
  - KALYANKJIL samples before 11:40 removed: the 19 Nov case (recorder started 11:40).
  - MCX removed, so a share with no bars.
- **Quotes file:** a copy of quotes_live.json, first written with t = 08:50 and every price x0.999 except MCX, then the real file. So MCX's price was first seen at 08:50 (an old price), and every other share's at 15:30.
- **Share with bars:** ITC (fixture and live, inside and outside).

## Other suites re-run on the final code
- **desk-web R51 (items 1-8):** inside 102 PASS · outside 42 PASS (fixture copy on 8104).
- **drill-down R51:** see above.

## Notes
- F7 share's toolbar at 390 is a sideways scroll strip (overflow-x: auto, unchanged); listed as NOTE, not cut text.
- **19 Nov itself cannot be shown live:** ChartAdapter serves today's recorder file only. The fixture reproduces that day's shape.
- **Not done (server side, not needed for this job):** sh.<SYM> carries no per-share last-trade time; kquote.json has `ltt`. Passing it into sh.<SYM> would make the old-price check exact even right after a gir-preview restart.

## Undo
`cd v2/pages/static && cp -p desk-common.js.bak2338 desk-common.js && cp -p desk-hunt.js.bak2338 desk-hunt.js && cp -p desk-trade.js.bak2338 desk-trade.js && cp -p share.js.bak2338 share.js && cp -p sector-drill.js.bak0004 sector-drill.js && cp -p desk-trade-v2.css.bak0106 desk-trade-v2.css && cp -p desk-fill.js.bak0125 desk-fill.js` (pages only, no restart).

Shots (P&L masked grey "P&L hidden"): girdata/review/monday/D_bars_shots/ (inside, fixture + live) and D_bars_shots/outside/.

## R51-style rows
| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 416px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 137px of 416px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| F1 chart KALYANKJIL (no samples 09:15-11:39): bars from 11:40, "data missing 09:15-11:39", grey band over the gap | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | candles 47 · line 0 · gaps [[34, 164]] · note "data missing 09:15-11:39 · 5-min bars · Fri 20 Nov" (302px of 416px) · under the levels True |
| F1 chart head: KALYANKJIL % stays (its quote is from 15:30 today; the gap is in the bars only) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | CHART KALYANKJIL 638.70 −3.37% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, KALYANKJIL) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| F1 chart MCX (no samples): "data missing 09:15-15:30", the gap band over the whole plot, no candles | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | candles 0 · line 0 · gaps [[34, 453]] · note "data missing 09:15-15:30 · no samples" (234px of 445px) · under the levels None · tooltip: data missing 09:15-15:30 · no MCX samples in the v2 recorder for Fri 20 Nov |
| F1 chart head: MCX price first seen 08:50 (before the open) -> "data missing", no %, no prev close line | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | CHART MCX 3,535.00 data missing 1m 5m 15m VWAP OR LVL 16h / data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price |
| F1 MOVERS: MCX not ranked in DOWN; in ALL its row says "data missing" (tooltip: the time of the old price) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | DOWN 84 · MCX in DOWN False · ALL row ['MCX data missing SB +24.1%', "data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price"] |
| no cut text (F1 desk, MCX + MOVERS ALL) | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt (fixture) | 1366x768 | inside | PASS | 1366 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share (fixture) | 1366x768 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 352px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share (fixture) | 1366x768 | inside | PASS | 125px of 352px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share (fixture) | 1366x768 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share (fixture) | 1366x768 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| F7 share chart KALYANKJIL: "data missing 09:15-11:39" + bars from 11:40 | F7 share (fixture) | 1366x768 | inside | PASS | candles 47 · line 0 · gaps [[34, 139]] · note "data missing 09:15-11:39 · 5-min bars · Fri 20 Nov" (277px of 352px) · under the levels True |
| F7 share MCX: chart "data missing 09:15-15:30"; hero "data missing" in place of the % | F7 share (fixture) | 1366x768 | inside | PASS | candles 0 · line 0 · gaps [[34, 389]] · note "data missing 09:15-15:30 · no samples" (215px of 381px) · under the levels None · hero 3,535.00 data missing 16h · data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price |
| no cut text (F7 share, MCX) | F7 share (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share (fixture) | 1366x768 | inside | PASS | none |
| no sideways scroll | F7 share (fixture) | 1366x768 | inside | PASS | 1366 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade (fixture) | 1366x768 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 365px) · under the levels True |
| no cut text (desk-trade) | desk-trade (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| desk-trade F&O MOVERS ALL: MCX row "data missing", not -3.02% | desk-trade (fixture) | 1366x768 | inside | PASS | ▼ DN 84 · ▲ UP 133 · ALL 218 · 218 MCX capital markets data missing +24.1% SB |
| no cut text (desk-trade F&O MOVERS ALL) | desk-trade (fixture) | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade (fixture) | 1366x768 | inside | PASS | none |
| no sideways scroll | desk-trade (fixture) | 1366x768 | inside | PASS | 1366 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 1366x768 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 416px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 1366x768 | inside | PASS | 137px of 416px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 1366x768 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 1366x768 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 1366x768 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt | 1366x768 | inside | PASS | 1366 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 1366x768 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 352px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 1366x768 | inside | PASS | 125px of 352px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 1366x768 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 1366x768 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share | 1366x768 | inside | PASS | none |
| no sideways scroll | F7 share | 1366x768 | inside | PASS | 1366 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 1366x768 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 365px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 1366x768 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 1366x768 | inside | PASS | none |
| no sideways scroll | desk-trade | 1366x768 | inside | PASS | 1366 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 532px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 137px of 532px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| F1 chart KALYANKJIL (no samples 09:15-11:39): bars from 11:40, "data missing 09:15-11:39", grey band over the gap | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | candles 47 · line 0 · gaps [[34, 209]] · note "data missing 09:15-11:39 · 5-min bars · Fri 20 Nov" (302px of 532px) · under the levels True |
| F1 chart head: KALYANKJIL % stays (its quote is from 15:30 today; the gap is in the bars only) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | CHART KALYANKJIL 638.70 −3.37% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, KALYANKJIL) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| F1 chart MCX (no samples): "data missing 09:15-15:30", the gap band over the whole plot, no candles | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | candles 0 · line 0 · gaps [[34, 569]] · note "data missing 09:15-15:30 · no MCX samples in the v2 recorder for Fri 20 Nov" (461px of 561px) · under the levels None · tooltip: data missing 09:15-15:30 · no MCX samples in the v2 recorder for Fri 20 Nov |
| F1 chart head: MCX price first seen 08:50 (before the open) -> "data missing", no %, no prev close line | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | CHART MCX 3,535.00 data missing 1m 5m 15m VWAP OR LVL 17h / data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price |
| F1 MOVERS: MCX not ranked in DOWN; in ALL its row says "data missing" (tooltip: the time of the old price) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | DOWN 84 · MCX in DOWN False · ALL row ['MCX data missing SB +24.1% capital markets', "data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price"] |
| no cut text (F1 desk, MCX + MOVERS ALL) | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt (fixture) | 1600x900 | inside | PASS | 1600 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share (fixture) | 1600x900 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 502px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share (fixture) | 1600x900 | inside | PASS | 125px of 502px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share (fixture) | 1600x900 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share (fixture) | 1600x900 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| F7 share chart KALYANKJIL: "data missing 09:15-11:39" + bars from 11:40 | F7 share (fixture) | 1600x900 | inside | PASS | candles 47 · line 0 · gaps [[34, 197]] · note "data missing 09:15-11:39 · 5-min bars · Fri 20 Nov" (277px of 502px) · under the levels True |
| F7 share MCX: chart "data missing 09:15-15:30"; hero "data missing" in place of the % | F7 share (fixture) | 1600x900 | inside | PASS | candles 0 · line 0 · gaps [[34, 539]] · note "data missing 09:15-15:30 · no MCX samples in the v2 recorder for Fri 20 Nov" (423px of 531px) · under the levels None · hero 3,535.00 data missing 17h · data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old  |
| no cut text (F7 share, MCX) | F7 share (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share (fixture) | 1600x900 | inside | PASS | none |
| no sideways scroll | F7 share (fixture) | 1600x900 | inside | PASS | 1600 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade (fixture) | 1600x900 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 426px) · under the levels True |
| no cut text (desk-trade) | desk-trade (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| desk-trade F&O MOVERS ALL: MCX row "data missing", not -3.02% | desk-trade (fixture) | 1600x900 | inside | PASS | ▼ DN 84 · ▲ UP 133 · ALL 218 · 218 MCX capital markets data missing +24.1% SB |
| no cut text (desk-trade F&O MOVERS ALL) | desk-trade (fixture) | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade (fixture) | 1600x900 | inside | PASS | none |
| no sideways scroll | desk-trade (fixture) | 1600x900 | inside | PASS | 1600 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 1600x900 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 532px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 1600x900 | inside | PASS | 137px of 532px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 1600x900 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 1600x900 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 1600x900 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt | 1600x900 | inside | PASS | 1600 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 1600x900 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 502px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 1600x900 | inside | PASS | 125px of 502px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 1600x900 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 1600x900 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share | 1600x900 | inside | PASS | none |
| no sideways scroll | F7 share | 1600x900 | inside | PASS | 1600 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 1600x900 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 426px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 1600x900 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 1600x900 | inside | PASS | none |
| no sideways scroll | desk-trade | 1600x900 | inside | PASS | 1600 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt (fixture) | 390x844 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 190px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 137px of 190px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt (fixture) | 390x844 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 0 cut cells |
| F1 chart KALYANKJIL (no samples 09:15-11:39): bars from 11:40, "data missing 09:15-11:39", grey band over the gap | F1 desk-hunt (fixture) | 390x844 | inside | PASS | candles 47 · line 0 · gaps [[34, 77]] · note "data missing 09:15-11:39" (154px of 190px) · under the levels True |
| F1 chart head: KALYANKJIL % stays (its quote is from 15:30 today; the gap is in the bars only) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | CHART KALYANKJIL 638.70 −3.37% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, KALYANKJIL) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 0 cut cells |
| F1 chart MCX (no samples): "data missing 09:15-15:30", the gap band over the whole plot, no candles | F1 desk-hunt (fixture) | 390x844 | inside | PASS | candles 0 · line 0 · gaps [[34, 227]] · note "data missing 09:15-15:30" (154px of 219px) · under the levels None · tooltip: data missing 09:15-15:30 · no MCX samples in the v2 recorder for Fri 20 Nov |
| F1 chart head: MCX price first seen 08:50 (before the open) -> "data missing", no %, no prev close line | F1 desk-hunt (fixture) | 390x844 | inside | PASS | CHART MCX 3,535.00 data missing 1m 5m 15m VWAP OR LVL 17h / data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price |
| F1 MOVERS: MCX not ranked in DOWN; in ALL its row says "data missing" (tooltip: the time of the old price) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | DOWN 84 · MCX in DOWN False · ALL row ['MCX data missing SB +24.1%', "data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price"] |
| no cut text (F1 desk, MCX + MOVERS ALL) | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt (fixture) | 390x844 | inside | PASS | 390 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share (fixture) | 390x844 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 190px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share (fixture) | 390x844 | inside | PASS | 125px of 190px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share (fixture) | 390x844 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share (fixture) | 390x844 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| sideways scroll strips, not cut text (F7 share, ITC) | F7 share (fixture) | 390x844 | inside | NOTE | #tbar2 "1m 5m 15m VWAP OR LEVELS PREMIUM vs NIFT" 513>372 (overflow-x auto, unchanged by this job) |
| no cut text (F7 share, ITC) | F7 share (fixture) | 390x844 | inside | PASS | 0 cut cells |
| F7 share chart KALYANKJIL: "data missing 09:15-11:39" + bars from 11:40 | F7 share (fixture) | 390x844 | inside | PASS | candles 47 · line 0 · gaps [[34, 77]] · note "data missing 09:15-11:39" (141px of 190px) · under the levels True |
| F7 share MCX: chart "data missing 09:15-15:30"; hero "data missing" in place of the % | F7 share (fixture) | 390x844 | inside | PASS | candles 0 · line 0 · gaps [[34, 227]] · note "data missing 09:15-15:30" (141px of 219px) · under the levels None · hero 3,535.00 data missing 17h · data missing: the last price 3,535.00 is from 08:50 IST, before Fri 20 Nov's open - no % from an old price |
| sideways scroll strips, not cut text (F7 share, MCX) | F7 share (fixture) | 390x844 | inside | NOTE | #tbar2 "1m 5m 15m VWAP OR LEVELS PREMIUM vs NIFT" 513>372 (overflow-x auto, unchanged by this job) |
| no cut text (F7 share, MCX) | F7 share (fixture) | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | F7 share (fixture) | 390x844 | inside | PASS | 390 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade (fixture) | 390x844 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 242px) · under the levels True |
| no cut text (desk-trade) | desk-trade (fixture) | 390x844 | inside | PASS | 0 cut cells |
| desk-trade F&O MOVERS ALL: MCX row "data missing", not -3.02% | desk-trade (fixture) | 390x844 | inside | PASS | ▼ DN 84 · ▲ UP 133 · ALL 218 · 218 MCX capital markets data missing +24.1% SB |
| no cut text (desk-trade F&O MOVERS ALL) | desk-trade (fixture) | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | desk-trade (fixture) | 390x844 | inside | PASS | 390 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 390x844 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 190px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 390x844 | inside | PASS | 137px of 190px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 390x844 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 390x844 | inside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 390x844 | inside | PASS | none |
| no sideways scroll | F1 desk-hunt | 390x844 | inside | PASS | 390 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 390x844 | inside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 190px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 390x844 | inside | PASS | 125px of 190px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 390x844 | inside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 390x844 | inside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| sideways scroll strips, not cut text (F7 share, ITC) | F7 share | 390x844 | inside | NOTE | #tbar2 "1m 5m 15m VWAP OR LEVELS PREMIUM vs NIFT" 513>372 (overflow-x auto, unchanged by this job) |
| no cut text (F7 share, ITC) | F7 share | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | F7 share | 390x844 | inside | PASS | none |
| no sideways scroll | F7 share | 390x844 | inside | PASS | 390 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 390x844 | inside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 242px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 390x844 | inside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 390x844 | inside | PASS | none |
| no sideways scroll | desk-trade | 390x844 | inside | PASS | 390 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 1366x768 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 416px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 1366x768 | outside | PASS | 137px of 416px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 1366x768 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 1366x768 | outside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 1366x768 | outside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 1366x768 | outside | PASS | none |
| no sideways scroll | F1 desk-hunt | 1366x768 | outside | PASS | 1366 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 1366x768 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 352px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 1366x768 | outside | PASS | 125px of 352px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 1366x768 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 1366x768 | outside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share | 1366x768 | outside | PASS | 0 cut cells |
| 0 page errors | F7 share | 1366x768 | outside | PASS | none |
| no sideways scroll | F7 share | 1366x768 | outside | PASS | 1366 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 1366x768 | outside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 365px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 1366x768 | outside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 1366x768 | outside | PASS | none |
| no sideways scroll | desk-trade | 1366x768 | outside | PASS | 1366 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 1600x900 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 532px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 1600x900 | outside | PASS | 137px of 532px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 1600x900 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 1600x900 | outside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 1600x900 | outside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 1600x900 | outside | PASS | none |
| no sideways scroll | F1 desk-hunt | 1600x900 | outside | PASS | 1600 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 1600x900 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 502px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 1600x900 | outside | PASS | 125px of 502px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 1600x900 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 1600x900 | outside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| no cut text (F7 share, ITC) | F7 share | 1600x900 | outside | PASS | 0 cut cells |
| 0 page errors | F7 share | 1600x900 | outside | PASS | none |
| no sideways scroll | F7 share | 1600x900 | outside | PASS | 1600 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 1600x900 | outside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 426px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 1600x900 | outside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 1600x900 | outside | PASS | none |
| no sideways scroll | desk-trade | 1600x900 | outside | PASS | 1600 px |
| F1 chart: ITC 5-min bars drawn under the level lines, never "not known" | F1 desk-hunt | 390x844 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (137px of 190px) · under the levels True |
| F1 chart: the chart line fits the plot (ITC) | F1 desk-hunt | 390x844 | outside | PASS | 137px of 190px |
| F1 chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F1 desk-hunt | 390x844 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F1 chart head: ITC %% from today's quote | F1 desk-hunt | 390x844 | outside | PASS | CHART ITC 299.10 −0.63% 1m 5m 15m VWAP OR LVL 10h |
| no cut text (F1 desk, ITC) | F1 desk-hunt | 390x844 | outside | PASS | 0 cut cells |
| 0 page errors | F1 desk-hunt | 390x844 | outside | PASS | none |
| no sideways scroll | F1 desk-hunt | 390x844 | outside | PASS | 390 px |
| F7 share chart: ITC 5-min bars drawn under the level lines, never "not known" | F7 share | 390x844 | outside | PASS | candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (125px of 190px) · under the levels True |
| F7 share chart: the chart line fits the plot (ITC) | F7 share | 390x844 | outside | PASS | 125px of 190px |
| F7 share chart: 1m / 5m / 15m toggle redraws the bars (ITC) | F7 share | 390x844 | outside | PASS | 5m 76 · 15m 26 · 1m line 1 · back to 5m 76 |
| F7 share hero: ITC %% from today's quote | F7 share | 390x844 | outside | PASS | 299.10 ▼ −1.90 −0.63% 10h |
| sideways scroll strips, not cut text (F7 share, ITC) | F7 share | 390x844 | outside | NOTE | #tbar2 "1m 5m 15m VWAP OR LEVELS PREMIUM vs NIFT" 513>372 (overflow-x auto, unchanged by this job) |
| no cut text (F7 share, ITC) | F7 share | 390x844 | outside | PASS | 0 cut cells |
| 0 page errors | F7 share | 390x844 | outside | PASS | none |
| no sideways scroll | F7 share | 390x844 | outside | PASS | 390 px |
| desk-trade chart: the open position's 5-min bars under its levels, never "not known" | desk-trade | 390x844 | outside | PASS | HDFCBANK 820 PE · candles 76 · line 0 · gaps [] · note "5-min bars · Fri 20 Nov" (161px of 242px) · under the levels True |
| no cut text (desk-trade) | desk-trade | 390x844 | outside | PASS | 0 cut cells |
| 0 page errors | desk-trade | 390x844 | outside | PASS | none |
| no sideways scroll | desk-trade | 390x844 | outside | PASS | 390 px |
