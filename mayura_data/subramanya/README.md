# 🛕 Subramanya — accumulation

*Subramanya Swamy of **Thirupparankundram (Madurai)**.* Buys stocks where **big
players are quietly accumulating** — delivery spikes, money-flow, FII buying,
relative strength. Never chases a stock already >40% above its 200-DMA.

## Trendlyne screen to build → save export here as `universe.csv`
Easy Mode filters:
- **Delivery % → Monthly > 1.5× 6-Month** (real delivery-based buying)
- **Volume Shockers** (unusual volume)
- **MFI > 50** and **RSI 50–70**
- **FII Holding → increasing** (Popular tab → FII Holding), if available
- **Return vs Nifty500 (3M) > 0**

Columns: **NSE Code, Delivery% Vol Avg Month + 6M, MFI, RSI, Returns vs
Nifty500 quarter%, FII Holding Change%** (Day SMA50/200 for the guard).

## Exit personality (medium)
−10% stop · trail +12%/10% · NO failed-breakout exit · 20-day hold · skip if
>40% above 200-DMA. Edit in mayura.py → STRATEGIES["subramanya"].
