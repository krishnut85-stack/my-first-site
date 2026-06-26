# Mayura 🦚 — paper trading in the name of Lord Muruga

> **Mayura** (the divine peacock, vahana of Lord Muruga) is a **paper-trading-only**
> companion. It simulates buying and selling Indian stocks against **real Kite
> market prices** so you can prove whether the strategy works — with fake money,
> **zero risk** — before you ever risk a rupee.
>
> ⚠️ **This is NOT investment advice and NOT a profit guarantee.** No real order
> is ever placed. Markets fall. Test for months. Vel Muruga 🙏

```bash
python mayura.py run        # ⭐ daily paper session + Telegram alert
python mayura.py rank       # today's top-ranked industries (no trading)
python mayura.py status     # your saved track record
python mayura.py scorecard  # honest verdict: beating the Nifty index?
python mayura.py check      # is Kite + Telegram wired up?
python mayura.py universe   # which stocks can Mayura actually trade?
```

---

## The two APIs Mayura uses (from our earlier setup)

| API | What it does in Mayura | Where it's wired |
|-----|------------------------|------------------|
| **Kite Connect (Zerodha)** | Real NSE last-traded prices + history. **Read-only** — Mayura has NO order-placing tool. | `KITE_API_KEY`, `KITE_TOKEN_FILE` (or `KITE_ACCESS_TOKEN`) |
| **Telegram Bot API** | Pushes the daily result to your phone. Plain HTTPS, works even where SMTP is blocked. | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |

Set them in a private `.env` on your server (see `.env.example`) — **never commit
real keys**. Run `python mayura.py check` to confirm both are live.

---

## Trendlyne features — all of them, and which Mayura actually needs

Your Trendlyne screenshots list ~40 features across 7 groups. Mayura does **not**
need most of them. It only needs the handful that produce the **CSV it reads** and
that define **what to trade**. Here is the full map.

### ✅ REQUIRED to make Mayura trade (the must-haves)

These are what you export from Trendlyne and drop into `sectorbot/data/`:

| Trendlyne feature | Group | Plan | Why Mayura needs it |
|-------------------|-------|------|---------------------|
| **Real-time Screeners** | Analyze | Free | The core stock/industry list Mayura ranks. |
| **Sector Dashboard (30+ sectors)** | Dashboards | Free | Industry fundamentals (PE, ROE, Qtr/Half/1Yr change) → the **fundamentals CSV**. |
| **Market Breadth Analysis** | Analyze | Freemium | % of stocks bullish on RSI/MFI/SMA20/50/200, golden cross → the **breadth CSV** Mayura blends in. |
| **Screener Creation Parameters** | Analyze | Free (1000+) | Lets you build the screen that defines the universe. |

> **In practice you only export 2 CSVs daily:** (1) **industry fundamentals** and
> (2) **industry breadth — equi-weighted**. Drop both into `sectorbot/data/` with
> any name ending `.csv`. Mayura auto-detects each by its column headers and uses
> the newest file. That is the entire daily input.

### 👍 STRONGLY HELPS (makes Mayura smarter / safer — optional)

| Trendlyne feature | Group | Plan | How it helps |
|-------------------|-------|------|--------------|
| **DVM Scores (Durability, Valuation, Momentum)** | Analyze | Freemium | A quality filter — avoid weak/over-valued names among the momentum leaders. |
| **Buy Sell Zone** | Analyze | Freemium | PE/PBV bands showing under/over-valuation — sanity-check entries. |
| **Stock Technicals (5min→monthly)** | Analyze | Premium | RSI/MFI/SMA per stock — finer entry/exit timing than the daily CSV. |
| **Backtesting** | Check Returns | Premium | Validate a screen's past behaviour (Mayura also has its own `backtest`). |
| **Stock Data Downloader** | Download & Connect | Premium | Bulk/automated CSV export instead of manual download. |
| **FII/DII Activity** | Dashboards | Free | Institutional flow context for the market-regime read. |
| **AlphaAlerts / Screener Alerts** | Track & Stay Updated | Freemium/Premium | Real-time nudges; Mayura's own Telegram already covers daily alerts. |

### ➖ NOT needed for Mayura (good for manual research, not the bot)

US Stocks Data · Global Indices · Forecaster (analyst estimates) · ETF Dashboard ·
ASM & GSM · SmartOptions F&O · Superstars' Portfolio · Insider + SAST Alerts ·
Deals Alert · Multiple Watchlists · Research Reports / Live PDF · Conference Call
AI Summary · SWOT · Portfolio Report/Analysis · Delivery Volume · Excel Connect ·
F&O Data Downloader · **Basket Execution** (this places **real** orders — Mayura
is paper-only and deliberately does not use it).

---

## 🧠 The SMART brain — DVM scoring (now LIVE)

Mayura no longer ranks on momentum alone. It now computes a **Trendlyne-style
DVM score** for every industry, straight from the columns already in your CSV —
so it actively *uses* the data behind Trendlyne's flagship **DVM Scores** feature:

| Pillar | What it measures | Trendlyne columns it reads |
|--------|------------------|-----------------------------|
| **D — Durability** | Is the business financially strong? | ROE, ROA, Net Profit growth YoY, Revenue growth, Industry Score |
| **V — Valuation** | Is it reasonably priced? (cheaper = higher) | PE-to-Growth (PEG), PE, Price/Book, Dividend yield |
| **M — Momentum** | Strong *and consistent* trend? | Week/Month/Qtr/Half/Year change + market breadth, with an alignment bonus when every timeframe is positive |

`Smart score = 0.35·D + 0.20·V + 0.45·M` (tunable in `config.SMART_WEIGHTS`).
It's momentum-led (we still chase trend) but **Durability stops Mayura buying
junk** and **Valuation stops it paying any price** for that trend. Missing
columns are skipped and weights re-normalised, so a leaner CSV still works.

See the live D/V/M breakdown any time with `python mayura.py rank`. Turn the
brain off with `USE_SMART_SCORE = False` to fall back to the old momentum+breadth
score. Logic + tests live in `sectorbot/smart.py` and `tests/test_smart.py`.

## How Mayura turns those features into a paper trade

```
Trendlyne CSVs (fundamentals + breadth)          Kite API
   │  Real-time Screeners                            │  real NSE prices + history
   │  Sector Dashboard                               │
   │  Market Breadth Analysis                        │
   ▼                                                 ▼
  RANK industries  ──►  pick top 8 (skip high-PE & parabolic)  ──►  size positions
   (momentum + quality + breadth blend)                              (₹10L paper, ≤15%/name)
                                                                          │
        manage holdings with exit rules ◄─────────────────────────────────┘
        (stop-loss / take-profit / trailing / ATR / regime filter)
                                                                          │
                                                                          ▼
                                    save track record  +  Telegram you (paper P&L)
```

Every number is **simulated**. The point is the **track record**: run it daily for
weeks, then `python mayura.py scorecard` tells you honestly whether it would have
**beaten a Nifty index fund after costs**. If it doesn't beat the index, the
honest answer is to keep it on paper.

---

## Relationship to `sectorbot`

Mayura is a clean, peacock-branded **launcher** on top of the existing, tested
`sectorbot` engine — same ranking, risk rules, Kite feed and Telegram. It does
**not** fork or duplicate the strategy (one tested engine = one thing to trust),
and it **hard-locks to paper mode**: if `LIVE_TRADING` were ever turned on,
`mayura.py` refuses to run. 🦚 Vel Muruga.
