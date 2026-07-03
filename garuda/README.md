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

## Status

Paper / research only. **No live-order path in this package.** Execution is worth
building only *after* a real-data backtest shows an edge that survives costs.

*Not investment advice. Paper simulation only.*
