# GIR Intraday — gate review of the 7 Nov source (after patch 77i)

Reviewed: the bundle `gir_intraday_src_2026-11-07.tgz` (152 files), against the rules in "What Rama is trying to achieve".
Line numbers are the bundle's (= the live files before patch 78). Nothing on the server was touched.
The fixes are in `install_p78.sh` (self-testing, backs up, rolls back). Items marked **decision** are left for Rama's word.

## 1. Calls that reach Box Picks without all the gates — most serious first

| # | Where | What goes out | Gates missing (side · strike · stop · size · measured · roof/floor · 09:30 · ban · liquidity) | Patch 78 |
|---|-------|---------------|------------------------------------------------------------------------------------------------|----------|
| 1 | `engine2.py:1839` BOX PICK | "BUY 2600 CE at about ₹90" | **measured** (the box edge exists in `edges.box()` but is never shown — the line says BUY with no number) · **size** (only "1 lot ₹") · **ban list** (the engine never reads it) · **liquidity** (no ₹2 premium check; the LIQUIDITY item only fails under 50 lots) | BUY only when `edges.box` measures 55%/50, else WATCH · size line · ban in `tg_gate` · premium ₹2+ |
| 2 | `engine2.py:1763` MOVER | "▶ 2600 CE ~₹90 · stop … · the box says WAIT" | a **ticket is sent even when the box says WAIT** (it only needs money *or* chart) · no **roof/floor** gate of its own · no **measured** number · no **size** · no **ban** · no **liquidity** | ticket only when the box says BUY on that side and the strike is liquid, else "WATCH — the box says WAIT (why)" · word WATCH (not measured) · size · ban |
| 3 | `engine2.py:1787` NEWS SHOCK | "▶ BUY 2600 PE ~₹90" | starts at **09:20** (`:1744`, inside the first 15 min) · no **roof/floor** · no **ban** · no **liquidity** · no **measured** · no **size** · exempt from the cap | 09:30 · word WATCH (not measured) · size · thin-strike warning · ban |
| 4 | `engine2.py:2499` BREAKING NOW | "▶ BUY CE (ATM) … signal under test — scored from today" | **BUY with no number** (it says so itself) · no **ban** · no **size** · liquidity only through the 5/7 score, not a hard gate | word WATCH · size · thin-strike warning · ban |
| 5 | `engine2.py:2855` WALL FLIP | "▶ 2600 CE ₹0.85 · new floor …" | ticket strike needs only a non-zero premium (`:2829`) — a ₹0.85 strike with 3,000 OI qualifies · fires from **09:25** (`:2783`) · no **ban** · no **size** | strike needs OI 20,000+ and ₹2+ · word from the flip edge · size · 09:30 and ban in `tg_gate` |
| 6 | `engine2.py:2370` THE THREE 14:30 | three rows to Box Picks | sent with `tg_fo` **directly — bypasses `tg_gate`** · no **ban** check · no **size** (rows do carry edge, stop, 1-lot cost) | size on every row · "⛔ in the F&O ban list" when it is |
| 7 | `desk.py:855` YOUR RULE | "📜 YOUR RULE … share price going UP → CE side" | **no ban check** (`your_rules` never looks at `self.ban`) · **no strike, stop or size** although the desk has them in `self.shares[sym]` · futures/share rules have no **liquidity** at all | banned shares skipped · ticket + stop + size on the line, or "no liquid ticket yet — WATCH" |
| 8 | `desk.py:926` SUDDEN | the best-gated line (09:45, ban, liquidity, confirmation, size) | the auditor (`desk.py:728-782`) has **no "CE under a roof" check**: a +2 vote goes out with the roof 0.5% above the price — the RECLTD case | the box's own 2% room rule in `audit()`: CE held under a roof < 2% above, PE held over a floor < 2% below |
| 9 | `engine2.py:273/289` FIRST MOVE · ORDER BOOK | "WATCH — not a trade yet" | side only: **no strike, stop, size**; **no ban**; exempt from the cap. They are labelled WATCH, so rule 5 allows them on the phone, but they do not meet the "conditions a call must meet" list | ban + 09:30 through `tg_gate` · **decision**: keep them on Box Picks as WATCH, or add the ATM ticket/stop/size from the checklist |
| 10 | `engine2.py:176,189-192` the day cap (12) and the 2-hour repeat rule · `:1834` PK 12/day · `:2493` BREAKING 15/day · `:1897` YOUR TRADE 30/day · `desk.py:916` 2 SUDDEN per share · `:1829` BOX PICK only if the share is in THE THREE | lines "kept on the page" | these are **mutes** — silent, log only; "nothing muted without Rama's word" | the cap now says so ONCE on Box Picks; the rest are **decision** |
| 11 | `engine2.py:1836,1758,2495` · `desk.py:918,853` | a call marked "sent" before Telegram answers | **one Telegram timeout = the call is gone for the day** (never retried, log only) | `tg_fo` retries once; a line that still fails is written to the NOW list marked "⚠ NOT SENT" |

Gates that are right today: BOX PICK's 09:45 window and roof/floor room (checklist), SUDDEN's whole chain, FIRST MOVE's 09:30 (`engine.py:407`), the desk's OI call not before open+30, the 20,000 OI / ₹2 liquidity in the desk's strike reader (`desk.py:192`).

## 2. Loops, polls or sleeps between an event and tg_fo / tg_box

Nothing added by patches 75–77i is a regression; the waits below are the design, listed so they are known:

- **FIRST MOVE / ORDER BOOK**: on the tick (`engine.py:555-636`) → `fm_event` → sender thread wakes within 1 s (`engine2.py:256`). ≤ 1 s. Good.
- **MOVER · NEWS SHOCK · BREAKING NOW · BOX PICK · WALL FLIP** run once per chain sweep (`engine2.py:2569-2591`). A sweep is a REST pass over ~17,000 strikes at 200 per call, one call a second (`chains.py:611-613, 640-681`): **1.5–2 minutes per pass**. The chain worker's own sleep is 5 s (`engine2.py:3253`), but these agents only see a move when the sweep comes round. BREAKING NOW ("+1.5% in 15 min") can therefore be up to ~2 min late. WALL FLIP is further held to once per 60 s (`:2777`). This is the REST design, not a loop; the only way faster is reading these strikes from the socket (as FIRST MOVE does).
- **SUDDEN**: engine writes `pins_live.json` every 60 s (`engine2.py:2752`), the desk reads once a minute on the clock (`desk.py:1101`), accepts a file up to 150 s old (`desk.py:98`), then the 5-min confirmation. 0–2 min behind the tick before the confirmation clock starts — the 60-s reading by design.
- **One real stall**: `tg_fo` posts to Telegram synchronously **inside the sweep thread** with a 15 s timeout (`engine2.py:164`). A slow Telegram holds the whole sweep and every alert behind it for up to 15 s (up to ~31 s with the retry). FIRST MOVE is on its own thread and is not affected. **decision**: move `tg_fo` to a one-line sender queue like FIRST MOVE's, or cut the timeout to 8 s.
- newsroom (5 s loop, 60-s rounds), exchange (15 s), desk rules re-read (120 s): by design, not on the acting path.

## 3. Exceptions swallowed on paths that matter

| Where | Effect when it fires | Patch 78 |
|-------|----------------------|----------|
| `desk.py:566,570,574` `ban_list()` | an NSE fetch failure returns an **empty set and caches it as `data/ban_<date>.txt` (`:573`) — the ban gate is off for the whole day, silently** | failures logged; the day file is written only after a successful fetch; `data/ban.txt` still counts; retried on the next call |
| `desk.py:864` (YOUR RULE) · `:932` (SUDDEN) | a `desk_calls` write that fails is lost — the 15:45 audit and every "measured N% of M" miss that call | logged |
| `engine.py:341` `first_move_norms` | a share whose normal volume cannot be built gets NaN — **FIRST MOVE never fires on it**, nobody knows | the shares are named in the log |
| `exchange.py:689` `results_map` | the desk's news reader and THE THREE get `{}` — results days are read as if nothing was filed | logged |
| `desk.py:544` `eval_rules` | a rule that throws on one share never fires there (syntax is checked by `load_rules`, runtime is not) | not patched — **decision**; would log once per rule |
| `engine2.py:2289` `three_list` room check | `wait_` stays unset — a THREE row can keep a BUY verdict when the wall check itself failed | not patched — note |
| `desk.py:332` `Futures.refresh` | `dash_state.json` unreadable → the futures agent silently keeps yesterday's build-up | not patched — note |
| `engine2.py:1722` lights news · `:276` dash.event · `dashserve.py` (22) · `desk.py:666` lots | page or wording only ("nothing audited", "lot size unknown") — visible | fine |

## 4. Pages or links outside home.html still offered

- `engine2.py:2398` — THE THREE Telegram text: "others on /expert: …". **Fixed**: "others (type the share on the home page)".
- `home.html:148` — the dead `openBoxOld()` still builds "full box: chain, walls, story →" to `/expert`. **Fixed**: link removed.
- `desk.py:944` — the desk summary on GIR Intraday: "the board has every share's counting". **Fixed**: "on the home page (type the share)".
- `dashserve.py:887, 911, 917` — `/tomorrow`, `/expert`, `/sectors` still served: allowed (old pages served, not linked). `board.html:42`, `three.html:49,124` link among themselves: unlinked pages, left alone.

## What install_p78.sh does

Edits `engine2.py engine.py desk.py exchange.py home.html` in place with exact anchors (26 edits; if one anchor does not match this server's files, nothing is written). Backs up `*.bak$TS`. Compiles. Runs the new `p78test.py` (gate: 09:30, ban list, cap notice, retry, NOT SENT, BUY/WATCH word, size, ban-list caching, the auditor's roof/floor, no links out), then `desk.py --test` and `fmtest.py`. Any failure rolls every file back. Restarts gir-intraday, gir-desk, gir-dash and checks the home page. Run after 15:35 IST or with `now`.

Tested here on the bundle: 26/26 anchors matched, compile clean, gate test 33/33, desk self-test PASSED, FIRST MOVE test PASSED, every rewritten Telegram line formatted with sample values.

## Decisions for Rama (not changed by the patch)

1. FIRST MOVE / ORDER BOOK on Box Picks as WATCH lines without a ticket — keep, or add the ATM ticket, stop and size?
2. The caps (12 a day, 15 BREAKING, 30 YOUR TRADE, 2 SUDDEN per share, picks only from THE THREE) — keep, raise, or drop? They are mutes.
3. `tg_fo` inside the sweep thread — move to a sender queue (≤ 1 s, no stall) in a follow-up?
4. `risk_rs` is still `null` in `data/desk_config.json` — every size line says "set risk_rs" until it is set.
