# 🕊️ Thanikesa — small-cap momentum (PURE technicals)

*Thanikesa of **Thiruttani** — the calm, contented victor.* This face hunts
**small-cap** winners using **pure technicals only** — price, trend, relative
strength and volume. **No fundamentals** (no DVM / ROCE / PEG / PE). It rides
momentum but refuses to chase a stock that has already gone parabolic.

## What it rewards (sectorbot/stocks.py → technical_score)
- **Uptrend gate**: must have SMA50 > SMA200 (golden cross). Below = rejected.
- **52-week-high proximity**: nearer the high = stronger momentum (George & Hwang).
- **Relative strength** vs Nifty500 (quarter).
- **Healthy RSI** (50–70 — momentum, not overbought).
- **Volume/delivery confirmation** + money-flow (MFI).
- Already-parabolic names (huge SMA50-over-SMA200 gap) are demoted.

## Trendlyne screen to build → save export here as `universe.csv`
Easy Mode filters:
- **Market Cap → Small Cap** (this is what makes it the small-cap face)
- **Day SMA50 > Day SMA200** (uptrend)
- **% Distance from 52-week high** small (e.g. within 25%)
- **Return vs Nifty500 (3M / Quarter) > 0** (relative strength)
- **Day RSI 50–75**, optional **Volume Shockers**

Columns to include: **NSE Code, Day SMA50, Day SMA200, % Distance from 52week
high, Returns vs Nifty500 quarter%, Day RSI, Day MFI, Delivery% volume Avg
Month + 6Month** (the more technical columns, the better the score).

## Exit personality (fast, small-cap aware)
−10% stop · trail arms at +10%, gives back 12% · **failed-breakout exit ON**
(exits if price falls back below SMA50) · 20-day hold · skip if >30% above the
200-DMA. Edit in mayura.py → STRATEGIES["thanikesa"].

> Small caps are volatile and illiquid — the firm stop + failed-breakout exit
> are deliberate. Paper only.
