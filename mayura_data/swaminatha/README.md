# 📜 Swaminatha — filings-driven (the Guru)

*Swaminathaswami of **Swamimalai** — the form of Muruga who became the **Guru**
and taught the meaning of "Om" to Lord Shiva himself.* This face is the one who
**reads the news**: it watches **NSE/BSE corporate filings & announcements** and
only places a (paper) buy when the filing is **bullish / materially positive**.

## How it will work
1. Start from a base watchlist (a Trendlyne quality screen, saved here as
   `universe.csv` — same format as Senthil).
2. For each candidate, fetch its **latest NSE/BSE filings** (last 1–2 days).
3. Judge the filing: **bullish → buy**, **negative/red-flag → skip**, nothing
   material → no action. (Free keyword rules first; AI only for gray cases.)
4. Apply the same exit rules (stop / trailing / time stop) as the other faces.

> ⚙️ The filings engine is the next build step. Until then this face stays
> dormant (no screen = skipped, never trades).

## Trendlyne base screen → save export here as `universe.csv`
Use a clean **quality** screen (like Senthil): durable, fairly-priced companies.
Columns: **NSE Code, Durability/Valuation/Momentum, ROCE, PEG, PE, PBV**, plus
**Day SMA50/200** for the extension guard.

## Exit personality (event-driven, medium)
−10% stop · trail +12%/10% · NO failed-breakout exit · 15-day hold · skip if
>40% above 200-DMA. Edit in mayura.py → STRATEGIES["swaminatha"].
