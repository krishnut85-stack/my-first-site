# 📜 Swaminatha — news-driven (Gemini reads the full filing)

*Swaminathaswami of **Swamimalai** — the form of Muruga who became the **Guru**
and taught the meaning of "Om" to Lord Shiva.* The face that **reads the news**:
it scans today's NSE corporate announcements **market-wide**, lets **Gemini read
the full text** and judge whether it's a genuine, **MATERIAL bullish catalyst**
(e.g. "Transrail Lighting secures ~Rs 459 cr MENA order" — is that big vs its
revenue?), runs basic safety checks, and only then places a (paper) buy.

## How it works — INTRADAY, every 30 min during market hours
News breaks any time, so Swaminatha **polls every 30 min (9:30–16:00 IST)** and
reacts within ~30 min — it does NOT wait for the close. Cost is controlled by a
funnel where Gemini is the LAST, most-filtered step:
1. **Fetch** today's NSE announcements market-wide.
2. **Keyword pre-filter** (free) → catalysts only (order wins, approvals, buybacks,
   mergers).
3. **Dedupe** (free) → skip filings already read in an earlier poll
   (`seen_news.json`), so **each filing is judged ONCE**, not every 30 min.
4. **Order-value floor** (free regex) → skip small orders (< `NEWS_MIN_ORDER_CR`,
   default ₹100 cr). This is the big cost cut.
5. **Hard daily Gemini cap** (`NEWS_MAX_GEMINI_CALLS_DAILY`, default 30) →
   absolute cost ceiling across all of today's polls (`gemini_count.json`).
6. **Safety gate** (Kite) → real, tradeable, price ≥ `NEWS_MIN_PRICE`, liquid
   enough (avg turnover ≥ `NEWS_MIN_TURNOVER_CR`).
7. **🤖 Gemini** reads the full news (Google Search grounding): bullish? material
   vs company size? one-off or strategic? priced in? → verdict + confidence.
8. **Buy** only if **bullish + material + confidence ≥ `NEWS_MIN_CONFIDENCE`**.
   Tight stop / trailing like the other faces. Only Telegrams when it BUYS.

→ Net effect: typically only a handful of big, fresh, liquid catalysts reach
Gemini per day — a few cents — and the daily cap guarantees the ceiling.

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
