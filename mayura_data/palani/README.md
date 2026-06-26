# 🌄 Palani — breakout / momentum

*"The hill-climber."* Buys stocks **just as a new uptrend begins** (the fresh
golden cross), rides the run, and cuts failures fast.

## Trendlyne screen to build → save export here as `universe.csv`
Easy Mode filters:
- **Moving Averages → Golden Cross 50 day over 200 day**
- **Distance from 52-week high → 10–40%** (room to run, not extended)
- **Delivery % → Monthly > 1.5× 6-Month** (accumulation)
- **Relative Comparison → Return vs Nifty500 (3M) > 0**

Columns to include: **NSE Code, Day SMA50, Day SMA200, % Distance from 52W high,
Delivery% Vol Avg Month + 6M, Returns vs Nifty500 quarter%** (RSI optional).

## Exit personality (aggressive)
−8% stop · trail armed +10% / 10% giveback · failed-breakout exit ON ·
10-day dead-money cut. Edit in `mayura.py` → STRATEGIES["palani"].
