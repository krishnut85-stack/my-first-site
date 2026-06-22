# SectorBot 🇮🇳

A transparent **sector-momentum screener + paper-trading bot** for the Indian
stock market, built around the data you provided. It ranks industries, picks the
strongest ones, maps them to NSE symbols tradeable on **Zerodha Kite**, and
simulates investing in them.

> ⚠️ **Read this first.**
> - **This is NOT investment advice and NOT a profit guarantee.**
> - Nobody — including this bot — can predict which sector will "boom". The
>   ranking only summarises the historical data in `data/sectors.csv`.
> - It runs in **PAPER (simulation) mode** by default: **fake money, zero risk.**
> - Live trading is OFF and must be deliberately enabled. You can lose real
>   money fast with automated trading. Test for a long time first, and
>   understand that high momentum often means a stock is already expensive.

## Quick start (no keys, no internet needed)

```bash
cd my-first-site

python -m sectorbot rank        # ranked industries from your data
python -m sectorbot sim         # run the paper-trading simulation
python -m sectorbot dashboard   # write ../dashboard.html to view in a browser
```

Open `dashboard.html` in any browser (or link it from `index.html`) to see the
rankings and simulated P&L.

## How the ranking works

A plain weighted blend (see `config.py → WEIGHTS`) of:
momentum (quarter / half-year / 1-year change), the provider's Industry Score,
ROE, revenue growth, and market breadth (advances/declines). Industries with a
PE above `MAX_PORTFOLIO_PE` (default 60) are flagged 🔥 and skipped as
"overheated". Everything is tweakable in `config.py`.

## Project layout

| File | Purpose |
|------|---------|
| `config.py` | All settings + risk limits + the live-trading safety switch |
| `screener.py` | Loads the CSV and scores/ranks industries |
| `instruments.py` | Maps industries → representative NSE symbols (illustrative) |
| `datasource.py` | Price feed: synthetic (paper) or Kite live |
| `paper_broker.py` | Simulated broker — virtual cash, positions, P&L |
| `bot.py` | Orchestrates screen → allocate → simulate → report |
| `report.py` | Generates `dashboard.html` |

## Going live later (only when you fully understand the risk)

Programmatic trading on Zerodha needs **Kite Connect** — a paid developer API
(~₹2,000/month), separate from the normal Kite app. SEBI also regulates retail
algo trading, so automated order placement must be registered through your
broker.

When you're ready:

1. `pip install kiteconnect`
2. Set environment variables `KITE_API_KEY`, `KITE_API_SECRET`,
   `KITE_ACCESS_TOKEN` (never commit real keys).
3. Build a `LiveBroker` mirroring `PaperBroker` using `kite.place_order(...)`.
4. Replace the illustrative `instruments.py` map with the full instruments dump
   from `kite.instruments()`.
5. Flip `LIVE_TRADING = True` — and start with tiny amounts.

The trading logic talks only to the `DataSource`/broker interfaces, so swapping
in the live versions does not require rewriting the strategy.
