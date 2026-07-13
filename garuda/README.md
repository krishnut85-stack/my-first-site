# Garuda — the screenshot's fast model, on Indian equity 🦅

**Garuda** is a SEPARATE bot (its own package; nothing shared with `sectorbot`
or `rama`). It is the **actual core model** from the viral "Claude × Quant"
screenshot — a **Markov next-move predictor that self-learns**, with Kelly
sizing — but applied to **legal NSE instruments on short (5-minute) bars**, long
and short, instead of the screenshot's India-illegal crypto binaries.

> Rama borrowed the screenshot's *tools and dashboard* onto a slow momentum
> engine. Garuda is the screenshot's *fast predict-the-next-move brain*.

## The model

1. **State** = the last few bar-directions (up/down).
2. **Predict** = for that state, P(next bar up) from learned transition counts
   (Laplace-smoothed; unseen states → neutral 50/50).
3. **Act** = only if the edge clears `MIN_EDGE`, take a **Kelly-sized** long or
   short for the next bar.
4. **Self-learn** = update the counts from what actually happened (no lookahead).

## Backtest FIRST (this is the honest part)

A fast strategy that can't clear its own costs is worthless. So before any
execution is built, Garuda measures itself — net return **after costs** vs simply
buying and holding the same series:

```bash
python -m garuda backtest                 # synthetic demo (no real edge by design)
python -m garuda backtest --csv bars.csv  # YOUR exported 5-min NSE bars
python -m garuda backtest --order 4       # try a different Markov order
```

Export real 5-minute bars from Kite's historical API into a CSV (a `close`
column, or one price per line) and point `--csv` at it. The verdict is blunt:
`NO EDGE`, `WEAK`, `LOSING`, or `EDGE (on this data)`.

**On random-walk synthetic data it loses — correctly.** Only real NSE data can
tell you whether this model has a genuine edge. If it doesn't, that is a finding,
not a failure — and far cheaper to learn here than with real money.

## Strategy LAB — discovering the NEXT edge (walk-forward)

There is no secret strategy nobody knows; the edge is in the **process**. The
LAB (`garuda/lab.py`) tests a library of genuinely different candidate ideas
(calendar effects, panic reversals, volatility squeezes, leader pullbacks,
52-week-high drift…) with fixed rules — no parameter sweeping — and judges each
one **walk-forward**: backtested on the older ~70% of history, then validated on
the newest ~30% it has *never seen*, after full delivery costs both sides.

```bash
python3 -m garuda.lab --csv strength_daily.csv    # run on the top-1500 universe
```

Verdicts: **PROMOTED** (profitable in BOTH periods → candidate for a new paper
book) · **OVERFIT** (made money on the past, lost on unseen data — the trap that
eats most retail backtests) · **WEAK** / **THIN** (marginal / too few trades).
Results are written to `data/garuda_lab_results.json` and rendered live on the
dashboard's **LAB** tab. A PROMOTED verdict means *survived honest validation*,
never *guaranteed money*.

## Swaminatha — the news-driven book (its own tab) 📜

Ported from Mayura's "Guru" face, **Swaminatha** is Garuda's 8th paper book and
renders in its **own dashboard tab** (next to OPTIONS). It reacts to *events*, not
price patterns: it scans market-wide NSE/BSE corporate announcements, and lets
**Gemini read the full filing** to judge whether it is a genuine, **MATERIAL
bullish catalyst on a financially-sound company** before placing a (paper) buy.

Cost is controlled by a funnel where Gemini is the **last, most-filtered** step:

```
fetch market-wide announcements
  → keyword pre-filter (free)        # order wins, approvals, buybacks, mergers…
  → dedupe (seen)                    # judge each filing once, never every poll
  → ₹-value floor (free regex)       # drop small orders below NEWS_MIN_ORDER_CR
  → safety gate (real, not a penny)  # price ≥ NEWS_MIN_PRICE via the Kite feed
  → 🤖 Gemini reads the full text    # material? sound? priced in?  (daily-capped)
  → BUY  (material + sound + confidence ≥ NEWS_MIN_CONFIDENCE)
```

Exits are event-driven and **tight** (news reverses fast): −8% hard stop, a
trailing lock that arms after +10% then gives 10% back from the peak, and a
15-day time exit. The book persists to `data/garuda_swaminatha_book.json` and is
folded into the grand-total P&L like every other book.

```bash
export GEMINI_API_KEY=...                 # from Google AI Studio (one time)
python3 -m garuda.swaminatha --news       # dry-run the funnel (needs a Kite token too)
```

Config lives in `config.py` (`SWAMINATHA_*`, `NEWS_*`, `GEMINI_*`). It **degrades
safely**: with no `GEMINI_API_KEY` it never buys (no confident read = no trade)
and the tab shows a clear *"NEWS OFF"* badge; with no Kite feed it still renders
(holdings marked at their entry price). **Paper only** — no real order is placed.

## Status

Paper / research only. **No live-order path in this package.** Execution is worth
building only *after* a real-data backtest shows an edge that survives costs.

*Not investment advice. Paper simulation only.*
