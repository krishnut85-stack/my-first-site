# Mayura's private data inbox 🦚

This folder is **Mayura's own**, separate from `sectorbot/data/` (the equity bot).
Mayura reads ONLY from here, keeps its OWN portfolio here, and never touches the
other bot's data or track record.

## What to drop here (your FRESH Trendlyne exports)

Each trading day, export from Trendlyne and drop the files in **this** folder
(any name ending `.csv` — Mayura auto-detects each by its column headers and uses
the newest):

1. **Fundamentals** (industry level) — from the **Sector Dashboard** / a
   **Real-time Screener** → has columns like `Industry Score`, `PE TTM`,
   `Qtr Change %`, `Return on Equity Annual`, `PE to Growth TTM`,
   `Price to Book TTM`, `Net Profit growth Qtr YoY%`. Name it e.g.
   `fundamentals-2026-06-26.csv`.
2. **Industry breadth — equi-weighted** — from **Market Breadth Analysis** → has
   `MOMENTUM SCORE`, `RSI > 50`, `LTP > SMA200`, `SMA50 > SMA200`. Name it e.g.
   `industry-breadth-equi-2026-06-26.csv`.

That's it — just those 2 files. Date them in the filename so Mayura always trades
on the newest one. Old files can stay; Mayura ignores all but the latest.

## What's here now

The two files currently here are **seed copies** so Mayura runs out of the box.
Replace them with your own fresh exports going forward.

## Files Mayura writes here (don't edit)

- `mayura_portfolio.json` — Mayura's own paper track record (cash, holdings, P&L).
- `snapshots/` — dated copies for Mayura's backtest history.

Mayura is **paper only** — nothing here ever places a real order.
