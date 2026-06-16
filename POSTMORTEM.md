# Post-mortem: why the previous F&O bot (GIR) lost money daily

Analysis of the `gir_backup_20260610.tar.gz` server backup. Recorded here so
the same mistakes are never rebuilt. The new framework's safety rails each
map to a specific failure below.

## Findings

1. **Structurally negative-edge strategy.** The F&O module bought CE/PE
   options *after* news broke (keyword matching on news feeds). By detection
   time the move had happened and IV had spiked — it systematically bought
   peak premium, then bled theta and IV crush. It also accepted up to 8%
   bid-ask spreads on stock options and originally ran 5% "market
   protection" slippage (a patch comment calls it a "silent 5% bleed").

2. **Catastrophic position sizing.** `FNO_CAP_PER_TRADE_FN` allocated
   **50–95% of the entire F&O book to a single trade**, with a stop at
   25–30% of premium. Every routine stop-out cost 12–25% of the book.
   (Sane sizing risks 1–2% of capital per trade — this was 10–50x over.)

3. **Risk limits were relaxed when they fired.** The daily-loss brake was
   widened from 5% to 15% (`FIX_V29: relaxed for small F&O capital`) so the
   bot could keep trading. A kill switch you loosen when it trips is not a
   kill switch.

4. **All tuning happened on live money.** 100+ patch annotations
   (V28→V231) each react to the previous week's real losses; the header
   says "ZERO paper trading. Every order is real Kite or nothing." A
   threading bug froze all trailing stops for two days (Apr 23–24) before
   being found. There was never a backtest.

5. **Fragile safety wiring.** If the `paper_trader` module failed to
   import, `PAPER_MODE` silently defaulted to **live** with only a stderr
   print. A missing file flipped simulation into real-money trading.

## How this repo answers each failure

| GIR failure | This framework |
|---|---|
| 50–95% of book per trade | Sizing capped so one stop-out ≈ 1% of capital; lot-multiple checks |
| Loss limit relaxed to keep trading | Kill switch latches for the day, squares off everything, blocks new entries |
| Tuned on live money, no backtest | Backtest → paper → live pipeline; identical strategy code in all three |
| Silent fallback to live mode | Paper is the default; live requires `--mode live --i-understand-the-risks` |
| 14k-line monolith, frozen-stop bug | Small modules, exits never blocked by risk checks, 19+ unit tests |
| Bought options post-news (negative edge) | Strategy not ported; included strategies must earn their way through backtest + paper |
