# NSE F&O Algo Trading Framework

A Python framework for algorithmic trading of NSE futures and options, with a
backtester, paper-trading mode, and a Zerodha Kite Connect live adapter.

> **Risk warning.** Derivatives trading is high risk: a SEBI study found ~90%
> of retail F&O traders lose money. Nothing here is investment advice. Always
> backtest, then paper trade for weeks, before risking capital — and only
> capital you can afford to lose. Algo orders through broker APIs must comply
> with SEBI's algo-trading regulations (your broker handles exchange approval
> for API orders; check their current terms).

## Architecture

```
algotrade/
├── instruments.py      # expiries, lot sizes, option/future symbol building
├── options.py          # Black-Scholes pricing, Greeks, implied volatility
├── risk.py             # position sizing, trailing stops, daily loss kill switch
├── engine.py           # live/paper polling loop with EOD square-off (IST clocks)
├── backtest.py         # bar-based backtester (reuses the same strategy code)
├── notify.py           # Telegram alerts (entries, exits, kill switch, daily P&L)
├── timeutils.py        # IST helpers (the server runs UTC)
├── brokers/
│   ├── base.py         # Broker/Order/Position abstractions
│   ├── paper.py        # simulated fills + slippage + cost model
│   ├── kite_auth.py    # unattended TOTP login + daily token cache
│   └── zerodha.py      # Kite Connect adapter (quotes, orders, historical bars)
└── strategies/
    ├── ema_crossover.py    # trend-following on index futures (backtestable)
    └── short_straddle.py   # intraday ATM straddle seller with per-leg SL
scripts/
├── run_fno.py          # THE entry point: --strategy straddle|trend, --mode paper|live
├── run_backtest.py     # backtest EMA crossover on CSV bars (--demo for smoke test)
└── kite_login.py       # manual fallback for minting a Kite access token
deploy/                 # systemd service + timer for the trading server
```

The same `Strategy` code runs in all three modes — backtest, paper, live —
because strategies only talk to a `Context` (quotes, history, positions,
risk-gated orders), never to a broker directly.

## Built-in safety rails

- **Kill switch**: trading halts and all positions are squared off when the
  daily loss limit is hit; it stays latched for the rest of the session.
- **Position sizing**: lots are sized so a stop-loss hit costs
  `risk_per_trade_pct` of capital (default 1%).
- **Lot-multiple and quantity caps** on every order; entries blocked outside
  the 09:20–15:00 window; everything squared off at 15:12.
- **Exits are never blocked** by risk checks.
- **Paper broker models slippage and transaction costs** so paper results
  aren't fantasy fills.

## Quick start

```bash
pip install -r requirements.txt
pytest                                   # run the test suite
python scripts/run_backtest.py --demo    # smoke-test the pipeline (synthetic data)
```

Backtest with real data (export 5-min NIFTY futures bars to CSV with columns
`datetime,open,high,low,close`):

```bash
python scripts/run_backtest.py data/nifty_fut_5min.csv
```

Paper trade during market hours (live quotes, fake fills). Credentials go in
`~/.env` — same variable names as the previous server setup (`KITE_API_KEY`,
`KITE_API_SECRET`, `ZERODHA_USER_ID`, `ZERODHA_PASSWORD`, `KITE_TOTP_SECRET`);
login is automatic via TOTP, no morning token ritual:

```bash
python scripts/run_fno.py --strategy straddle --mode paper --lots 1
```

Live trading (only after weeks of successful paper trading):

```bash
python scripts/run_fno.py --mode live --lots 1 --max-daily-loss 5000 \
    --i-understand-the-risks
```

Server deployment (systemd + Telegram alerts): see DEPLOY.md.
Why the previous bot lost money daily: see POSTMORTEM.md.

## Writing your own strategy

Subclass `Strategy` and implement `on_bar(ctx)`:

```python
from algotrade.strategies.base import Strategy

class MyStrategy(Strategy):
    name = "my_strategy"

    def on_bar(self, ctx):
        bars = ctx.history("NIFTYFUT", 50)   # pandas OHLC DataFrame
        if some_signal(bars):
            lots = ctx.risk.position_size_lots(stop_distance_points=30)
            ctx.buy("NIFTYFUT", lots * 75, tag="my-entry")
```

`ctx.now` is the current bar time in backtests and wall-clock time live, so
time-of-day logic works identically in both.

## Things the framework does NOT do (yet)

- Options backtesting (needs historical option-chain data; the straddle
  strategy can only be validated in paper mode).
- Websocket tick data (the engine polls LTP; fine for minute-level logic,
  not for HFT — which retail infrastructure can't compete in anyway).
- Multi-leg margin/basket order optimization.
- Exchange holiday calendar (expiry helpers assume no holiday shifts).

## Keeping exchange parameters current

Lot sizes, strike steps, and expiry weekdays change via NSE/SEBI circulars.
They live in `algotrade/instruments.py` as plain dicts — verify them against
the NSE website before trading. As of mid-2026: NIFTY lot 75, weekly expiry
Tuesday; BANKNIFTY lot 35, monthly only.
