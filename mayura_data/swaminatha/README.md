# 📜 Swaminatha — filings-driven (the Guru)

*Swaminathaswami of **Swamimalai** — the form of Muruga who became the **Guru**
and taught the meaning of "Om" to Lord Shiva himself.* This face is the one who
**reads the news**: it watches **NSE/BSE corporate filings & announcements** and
only places a (paper) buy when the filing is **bullish / materially positive**.

## How it works  ✅ (engine built — sectorbot/filings.py)
1. Start from a base watchlist (a Trendlyne quality screen, saved here as
   `universe.csv` — same format as Senthil).
2. For the top `FILINGS_SCAN_TOP` (25) candidates, fetch their **latest
   NSE filings** (last `FILINGS_DAYS_BACK`, default 7, days).
3. Judge each filing with keyword rules: **bullish → buy**, **red-flag → block**
   (SEBI/default/auditor exit/pledge…), nothing material → no action.
4. Buys ONLY the bullish names; applies the same exit rules (stop / trailing /
   time stop) as the other faces. **Fail-safe: a filing it can't read = no buy.**

Dry-run anytime (no trading):  `python mayura.py filings swaminatha`

> 🤖 An AI judge (Gemini) for the "gray/neutral" filings can be slotted in
> later at sectorbot/filings.py → assess_symbol(). Not wired yet, by design.

## Trendlyne base screen → save export here as `universe.csv`
Use a clean **quality** screen (like Senthil): durable, fairly-priced companies.
Columns: **NSE Code, Durability/Valuation/Momentum, ROCE, PEG, PE, PBV**, plus
**Day SMA50/200** for the extension guard.

## Exit personality (event-driven, medium)
−10% stop · trail +12%/10% · NO failed-breakout exit · 15-day hold · skip if
>40% above 200-DMA. Edit in mayura.py → STRATEGIES["swaminatha"].
