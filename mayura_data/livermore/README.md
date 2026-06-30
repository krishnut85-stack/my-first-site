# 📈 Livermore — trend-following breakout leaders (guest face)

A 7th Mayura face built on **Jesse Livermore's** classic rules (not one of the six
temple faces — a tribute edge). PAPER ONLY, like all of Mayura.

## What it does
Scores candidates from **live Kite OHLC** (no Trendlyne columns needed) and buys
only the strongest **breakout leaders**, the Livermore way:

- **Trade WITH the trend** — only stocks in a confirmed Stage-2 uptrend (hard gate).
- **Enter at the pivotal point** — a fresh breakout above a recent pivot high.
- **Buy leaders** — within 15% of the 52-week high.
- **Confirm with the tape** — momentum, relative strength vs NIFTY, volume surge.
- **Cut losses fast, let winners run** — 7% stop, trailing lock arms at +5% then
  rides with a wide 15% leash for up to 120 days; exits a failed breakout quickly.

It is **strict on purpose**: if nothing is trending or breaking out, it buys
nothing (Livermore: *"It was never my thinking that made the big money. It was my
sitting."*).

## What to upload
Drop a **candidate universe** here (liquid large/mid-cap leaders work best —
Livermore traded the leaders, not laggards), as either:
- `mayura_data/livermore.csv`, or
- one or more CSVs inside `mayura_data/livermore/` (they're merged).

Minimum column: an **NSE symbol** column (e.g. `NSE Code` or `Symbol`). No DVM /
valuation columns are required — the edge is computed from price/volume.

## Telegram
Set `MAYURA_TOPIC_LIVERMORE=<topic id>` (create a "Livermore" topic in your Mayura
group, then run `python mayura.py telegram-setup`).

## Run it
```
python mayura.py rank livermore     # see today's scored breakout leaders
python mayura.py run  livermore     # paper session + Telegram (once a universe is uploaded)
```
