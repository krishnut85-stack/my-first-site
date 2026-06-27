# 🕊️ Thanikesa — small-cap momentum (Minervini VCP + Stage-2)

*Thanikesa of **Thiruttani** — the calm, contented victor.* This face hunts
**small-cap** winners the way 2× US Investing Champion **Mark Minervini** does —
**computed from live Kite OHLC**, not screened from Trendlyne columns.

## What it computes (sectorbot/technicals.py)
- **Stage-2 trend template** (Minervini's 8 checks): price above rising 150/200-DMA,
  50 > 150 > 200, ≥30% above the 52-week low, within 25% of the 52-week high.
- **VCP — Volatility Contraction Pattern**: successive pullbacks getting
  *tighter*, volume *drying up*, price *coiled just under the pivot* (ready to
  break out). The core of Minervini's method.
- **Momentum** (6-month return, skipping the last month) + **relative strength**
  vs the NIFTY. Already-parabolic names are demoted.
- Hard gate: not in a Stage-2 uptrend ⇒ heavily demoted (momentum needs trend).

## You don't screen anything — just give it a candidate pool
Upload a **stable small-cap universe ONCE** as `universe.csv` (or
`mayura_data/thanikesa.csv`). The only required column is **NSE Code**.
Good pools: **Nifty Smallcap 250** constituents, or your own small-cap list.
Mayura then computes the VCP/Stage-2 edge on these from live bars every run.

`python mayura.py rank thanikesa`  → see the live-computed ranking
`python mayura.py data thanikesa`  → confirm the pool size (no fetching)

## Exit personality (fast, small-cap aware)
−10% stop · trail arms at +10%, gives back 12% · **failed-breakout exit ON** ·
20-day hold · skip if >30% above the 200-DMA. Edit in mayura.py →
STRATEGIES["thanikesa"].

> Computing the edge fetches ~1 year of bars per name (capped at
> OHLC_MAX_SYMBOLS=150, ~0.25s each to respect Kite rate limits), so a run takes
> a minute or two. Paper only.
