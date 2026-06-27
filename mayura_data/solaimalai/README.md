# 🍃 Solaimalai — out-of-the-box (quant multi-factor + special situations)

*Solaimalai Murugan of **Pazhamudircholai** — the hill of ripe fruits,
abundance.* The most sophisticated face: it thinks like a **quant fund** and a
**special-situations hedge fund** at once. Everything is **computed from live
Kite OHLC + NSE/BSE filings** — you don't screen anything.

## Three edges, combined
1. **Quant multi-factor (AQR-style)** — each stock in the pool is scored on
   five factors, **z-scored across the whole universe**, then percentile-ranked:
   - Momentum (12-1) · Low-volatility · Stage-2 trend quality · VCP coil ·
     Relative strength vs NIFTY
2. **Minervini VCP + Stage-2** — the volatility-contraction structure feeds the
   `vcp` and `trend` factors above (shared engine with Thanikesa).
3. **Greenblatt special situations** — recent filings are scanned for
   **buybacks, demergers, spin-offs, promoter buying, open offers**. A match
   **boosts** the score (+SOLAIMALAI_SPECIAL_BOOST). A **red-flag** filing
   (SEBI/default/auditor exit…) **zeroes** it. Filings are a conviction overlay,
   not a gate — if they can't be read, the quant score stands (fail-open).

## You don't screen — just give it a candidate pool
Upload a **stable universe ONCE** as `universe.csv` (or
`mayura_data/solaimalai.csv`); only the **NSE Code** column is required.
Good pools: a broad index list (Nifty 500), or your own watch-universe.

`python mayura.py rank solaimalai` → live multi-factor ranking (⭐ = special
situation, 🚫 = red flag blocked).

## Tuning (config.py)
- `SOLAIMALAI_FACTOR_WEIGHTS` — the factor blend (momentum/vcp/trend/lowvol/rs)
- `SOLAIMALAI_SPECIAL_BOOST` — how much a special situation lifts the score
- `OHLC_MAX_SYMBOLS` / `OHLC_FETCH_DELAY` — pool cap & rate-limit pacing

## Exit personality (medium, multi-factor)
−10% stop · trail +12%/12% · 30-day hold · skip if >40% above the 200-DMA.
Edit in mayura.py → STRATEGIES["solaimalai"]. Paper only.
