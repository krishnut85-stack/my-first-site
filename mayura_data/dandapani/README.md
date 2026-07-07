# 🌄 Dandapani — breakout / momentum

*Dandayuthapani of **Palani** — the lord whose weapon strikes.* Buys stocks
**just as a new uptrend begins** (the fresh golden cross), rides the run, and
cuts failures fast. Never chases a stock already >30% above its 200-DMA.

## Trendlyne screen to build → save export here as `universe.csv`
Easy Mode filters:
- **Moving Averages → Golden Cross 50 day over 200 day**
- **Distance from 52-week high → 10–40%** (room to run, not extended)
- **Delivery % → Monthly > 1.5× 6-Month** (accumulation)
- **Relative Comparison → Return vs Nifty500 (3M) > 0**

Columns: **NSE Code, Day SMA50, Day SMA200, % Distance from 52W high,
Delivery% Vol Avg Month + 6M, Returns vs Nifty500 quarter%** (RSI optional).

## Exit personality (aggressive)
−8% stop · trail +10%/10% · failed-breakout exit ON · 10-day cut · skip if
>30% above 200-DMA. Edit in mayura.py → STRATEGIES["dandapani"].
