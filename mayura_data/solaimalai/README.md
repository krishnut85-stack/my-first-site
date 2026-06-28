# 🍃 Solaimalai — large/mid-cap VALUE + QUALITY quant + special situations

*Solaimalai Murugan of **Pazhamudircholai** — the hill of ripe fruits,
abundance.* Deliberately the **opposite of Thanikesa**: instead of chasing
expensive small-cap momentum, it buys **durable, fairly-priced large & mid-caps**
and tilts toward **event-driven (Greenblatt) special situations**. So the two
faces hold *different* stocks.

## Three edges, combined (cross-sectional z-score)
1. **VALUE (45%)** — Trendlyne Valuation Score (cheap = high) + low PE + low P/B.
   This is why it **avoids "Getting Expensive" names** like RR Kabel.
2. **QUALITY (40%)** — Durability score + Trendlyne checklist (strong balance
   sheets, consistent businesses).
3. **TREND (15%)** — a little momentum so we don't buy value traps.
Each factor is z-scored across the whole universe (the "quant" step), then
**Greenblatt special situations** from filings **boost** the score
(buyback / demerger / spin-off / promoter buying) and **red-flags block** it.

## Universe — LARGE/MID cap (so it never overlaps small-cap Thanikesa)
Upload a **Trendlyne export** as `solaimalai.csv` (or
`mayura_data/solaimalai/universe.csv`) built from a large/mid index — e.g.
**Nifty 200** or **Nifty LargeMidcap 250** — with these columns:
**NSE Code, Trendlyne Durability Score, Trendlyne Valuation Score, PE TTM,
PBV, Trendlyne Momentum Score** (and Day SMA50/SMA200 for the exit guards).

> Unlike Thanikesa (bare symbol list + live OHLC), Solaimalai needs the
> fundamental columns — value & quality can't be computed from price alone.

`python mayura.py rank solaimalai`  → value+quality ranking (⭐ special
situation, 🚫 red flag, 💰 cheap-quality leaders rise to the top).

## Tuning (config.py)
- `SOLAIMALAI_FUND_WEIGHTS` — value / quality / trend blend
- `SOLAIMALAI_SPECIAL_BOOST` — how much a special situation lifts the score

## Exit personality (patient, large/mid)
−12% stop · trail +15%/12% · 45-day hold · skip if >50% above the 200-DMA.
Edit in mayura.py → STRATEGIES["solaimalai"]. Paper only.
