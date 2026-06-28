# 📜 Swaminatha — news-driven (Gemini reads the full filing)

*Swaminathaswami of **Swamimalai** — the form of Muruga who became the **Guru**
and taught the meaning of "Om" to Lord Shiva.* The face that **reads the news**:
it scans today's NSE corporate announcements **market-wide**, lets **Gemini read
the full text** and judge whether it's a genuine, **MATERIAL bullish catalyst**
(e.g. "Transrail Lighting secures ~Rs 459 cr MENA order" — is that big vs its
revenue?), runs basic safety checks, and only then places a (paper) buy.

## How it works (sectorbot/gemini.py + sectorbot/filings.py)
1. **Fetch** today's NSE announcements across ALL companies (last 2 days).
2. **Pre-filter** (free keywords) to potential catalysts — order wins, approvals,
   buybacks, contracts… — so Gemini is only called on the promising few.
3. **Safety gate** (before spending a Gemini call): real, tradeable stock,
   price ≥ `NEWS_MIN_PRICE` (no penny stocks), avg daily turnover ≥
   `NEWS_MIN_TURNOVER_CR` (liquid enough to exit).
4. **Gemini judges** the full news (with Google Search grounding for context):
   bullish? material vs company size? one-off or strategic? already priced in?
   → `{verdict, material, confidence, reason}`.
5. **Buy** only if **bullish + material + confidence ≥ `NEWS_MIN_CONFIDENCE`**.
   Same exit rules (tight stop, trailing) as the other faces.

## Setup — you need a Gemini API key (one time)
Get a key from Google AI Studio, then add it to the droplet's `.env`:
```
GEMINI_API_KEY=your_key_here
```
That's it — **no pool/CSV needed.** Swaminatha reacts to live market news.

Test it (no trading):  `python mayura.py filings swaminatha`
Verify the key:        `python mayura.py check`

## Tuning (config.py)
- `GEMINI_MODEL` (default gemini-2.5-flash), `GEMINI_USE_SEARCH`
- `NEWS_MIN_CONFIDENCE` (0.6) · `NEWS_MAX_GEMINI_CALLS` (40/day cost cap)
- `NEWS_MIN_PRICE` (20) · `NEWS_MIN_TURNOVER_CR` (1.0) — safety gate

## Exit personality (event-driven, tight)
−8% stop · trail +10%/10% · 15-day hold. News can reverse fast, so the stop is
tighter than the other faces. Edit in mayura.py → STRATEGIES["swaminatha"].
Paper only. 🦚
