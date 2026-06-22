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
python -m sectorbot backtest    # replay data/snapshots/*.csv (needs 2+ days)
python -m sectorbot email       # email today's picks/exits to you
python -m sectorbot trade       # run the PERSISTENT paper portfolio + email
```

## Paper trading on REAL Kite prices (persistent portfolio)

`python -m sectorbot trade` maintains a real **forward track record**: it keeps a
portfolio in `data/portfolio.json` (cash, positions, realised P&L, equity
history) that **carries across runs**. Each run prices every holding, applies
the exit rules (SL / TP / trailing / ATR), books realised P&L, then buys new top
picks with spare cash. Capital is **₹10 lakh** (`config.PAPER_CAPITAL`,
`CAPITAL_MODE="fixed"`, max 15% per name).

- **It is still PAPER** — no real orders are ever placed.
- With Kite keys set (`USE_KITE_DATA=True`, default) it trades on **real market
  prices**, so the track record is meaningful. Without keys it falls back to
  **synthetic** prices (clearly flagged "NOT real") so it still runs.
- Going live later = set `LIVE_TRADING=True` and implement order placement; the
  paper portfolio is your evidence before that.

### Recommended: run on your server (droplet), reuse the daily token

If you already run another bot that logs into Kite daily via TOTP and writes the
access token to a file (e.g. `/home/globalbot/data/kite_token.json`), the safest
setup is to run SectorBot **on that same machine** and reuse that token. No
second login, and **no Kite/TOTP secrets in GitHub**.

```bash
# one-time on the droplet
git clone <your repo> ~/sectorbot && cd ~/sectorbot
pip install -r requirements.txt
export KITE_API_KEY=...                       # from /home/globalbot/.env
export KITE_TOKEN_FILE=/home/globalbot/data/kite_token.json
python -m sectorbot token-check               # verifies real data (token hidden)

# daily, after market close (server is UTC; 10:15 UTC = 15:45 IST)
crontab -e
# 15 10 * * 1-5  /home/YOU/sectorbot/scripts/run_on_droplet.sh >> ~/sectorbot.log 2>&1
```

`scripts/run_on_droplet.sh` loads the creds and runs `python -m sectorbot trade`.
`portfolio.json` persists on the droplet's disk across runs — no git needed.
Upload your daily CSVs straight to the droplet's `sectorbot/data/` (e.g. via
Termius SFTP).

> 🔒 **Security:** `KITE_TOTP_SECRET` is your 2FA seed and `ZERODHA_PASSWORD` is
> your password. Keep them only in the droplet's private `.env` (gitignored).
> Never commit them and never store them in GitHub. `token-check` prints only the
> token's length + last 4 chars, never the token itself.

### Alternative: GitHub Actions (more fragile)
You *can* run on GitHub with `KITE_API_KEY`/`KITE_API_SECRET`/`KITE_ACCESS_TOKEN`
as repo secrets, but the access token **expires daily** and GitHub runners are
ephemeral, so you'd need to regenerate and re-store it every day. The droplet
avoids all of this — prefer it.

⚠️ Even on real prices, **paper results overstate live results** — they ignore
brokerage, STT/GST, slippage, spread and market impact. Treat this as a research
track record, not a profit promise.

## Email alerts

`python -m sectorbot email` emails the day's picks + simulated exits to
**krishnut85@gmail.com** (change via the `EMAIL_TO` env var). With no SMTP
credentials it does a safe **dry-run** (prints the email instead of sending).

To actually send via Gmail: enable 2-step verification, create an **App
password**, then set:

```bash
export SMTP_HOST=smtp.gmail.com SMTP_PORT=465
export SMTP_USER=krishnut85@gmail.com
export SMTP_PASSWORD=your_16_char_app_password
python -m sectorbot email
```

Automate it daily with cron, e.g. `30 16 * * 1-5 cd /path/to/my-first-site &&
python -m sectorbot email` (after your Termius upload).

### Automated daily email via GitHub Actions

`.github/workflows/daily-email.yml` runs `python -m sectorbot email` on a
schedule (10:15 UTC ≈ 15:45 IST, Mon–Fri) and can also be run on demand from
the **Actions** tab.

Setup:
1. **Merge PR #3 into `main`.** Scheduled runs only fire from the default
   branch, so the daily job won't start until this is on `main`.
2. In GitHub: **Settings → Secrets and variables → Actions → New repository
   secret**, add:
   - `SMTP_HOST` = `smtp.gmail.com`
   - `SMTP_PORT` = `465`
   - `SMTP_USER` = `krishnut85@gmail.com`
   - `SMTP_PASSWORD` = your Gmail **App password**
   - `EMAIL_TO` = `krishnut85@gmail.com` (optional; defaults to this)
3. Test it: Actions tab → *SectorBot daily email* → **Run workflow**.

Without the secrets the job still succeeds but only **dry-runs** (prints the
email in the logs instead of sending).

The workflow also **auto-saves a dated snapshot** (`python -m sectorbot
snapshot`) of the day's CSV into `sectorbot/data/snapshots/` and commits it
back to the repo, so your backtest history builds itself over time. Re-running
on the same day overwrites that day's snapshot (no duplicates). Because the
Action commits to the repo, **pull before you push** from Working Copy.

⚠️ The Action uses the CSV **committed in the repo** — it cannot see files you
upload only to your laptop. To email on fresh data, commit/push the day's CSV
into `sectorbot/data/` (e.g. via Working Copy) before the run.

## Tests

```bash
pip install pytest
pytest            # 29 tests covering scoring, risk rules, broker, backtest, email
```

Open `dashboard.html` in any browser (or link it from `index.html`) to see the
rankings and simulated P&L.

## Daily CSV workflow (Termius)

Just upload today's file into `sectorbot/data/` with **any name ending in
`.csv`** (e.g. `2026-06-22.csv`). The bot **auto-selects the newest file** — no
flags needed. You can also force a file with `--csv path/to/file.csv` or the
`SECTORBOT_CSV` env var. To build backtest history, also copy each day's file
into `sectorbot/data/snapshots/` (see the README there).

## Two data files: fundamentals + sector breadth (blended)

SectorBot can blend two Trendlyne CSVs:

1. **Fundamentals** (industry level) — PE, ROE, returns, Industry Score. This is
   the primary file (`sectors.csv` / your dated upload).
2. **Breadth** — Momentum Score, RSI>50, MFI>50, LTP>SMA20/50/200,
   SMA50>SMA200, day/week gainers. Export from Trendlyne's "bullish/bearish
   breadth" page. You can supply **sector-level and/or industry-level** breadth
   files (same columns; the NAME column is sectors or industries). All breadth
   files in `data/` are merged; each industry is matched by its **own name
   first** (industry-level file), then by its **sector** (sector-level file).

The bot **auto-detects each file by its headers**, so just drop both into
`sectorbot/data/` (any names ending in `.csv`; date them to control recency).

**Recommended daily set (just 2 files):**
1. **Fundamentals** (industry level).
2. **Industry breadth — equi-weighted** (Trendlyne Industry breadth page, set the
   toggle to *Equi-weighted* before Export). Equi-weighted counts every stock
   equally, so it measures true breadth; market-cap weighting can look bullish
   just because one mega-cap is up. The industry-level file already covers every
   industry, so you don't also need the sector-level or market-cap versions.
Each industry's score becomes:

```
score = fundamental_score * BLEND_FUNDAMENTAL_WEIGHT
      + sector_breadth_score (0-100) * BLEND_BREADTH_WEIGHT
```

matched by sector name (`&`/`and`, commas and casing are normalised). Weights
and the `USE_BREADTH_BLEND` toggle live in `config.py`. If no breadth file is
present, the bot just uses fundamentals. The CLI `rank` and the daily email show
the `Fund` and `Breadth` components alongside the blended score.

## Rotation with BUFFER BANDS (`REBALANCE` in `config.py`)

The default minimises churn and taxes — it trades only when a holding genuinely
deteriorates, not on daily noise:

- **`REBALANCE = True`** (default, buffer bands):
  - **Buy** to fill up to `MAX_POSITIONS` (8) from the best-ranked names you
    don't already hold.
  - **Sell** a holding **only when it drops out of the top `SELL_RANK_BUFFER`
    (15)** — it is *not* sold for slipping a place or two. A hard stop-loss is the
    floor. → typically a few trades a *month*, not daily. Lower cost, and longer
    holds are more tax-efficient (LTCG vs STCG).
- **`REBALANCE = False`** — pure exit-rule hold (SL / TP / trailing / ATR); buy
  new leaders only with spare cash.

Tune `MAX_POSITIONS` (how many to hold) and `SELL_RANK_BUFFER` (how sticky) to
trade off responsiveness vs churn. A wider buffer = fewer trades.

## Over-extended guard (`AVOID_OVEREXTENDED`)

Momentum's worst failure is the "momentum crash" — buying a stock that has gone
**parabolic** right before it reverses. To reduce this, the bot **skips
industries whose recent quarter run-up exceeds `MAX_QTR_RUNUP_PCT` (60%)**. It
keeps normal momentum but drops the blow-off names (e.g. an industry up 200% in a
quarter). Turn off with `AVOID_OVEREXTENDED = False`.

## Capital & exit rules (all in `config.py`)

- **Capital mode** — `"unlimited"` (invest `NOTIONAL_PER_NAME` in every pick, no
  cash cap) or `"fixed"` (spread `PAPER_CAPITAL`, cash-constrained).
- **Hard stop-loss / take-profit** — fixed % from entry.
- **Trailing stop ("trailing profit")** — arms after `TRAILING_ACTIVATE_PCT`
  profit, then exits on a `TRAILING_SL_PCT` drop from the peak, locking gains.
- **ATR stop** — volatility-adaptive stop at `entry − ATR_MULT × ATR`
  (Wilder's ATR over `ATR_PERIOD` bars). In paper mode ATR uses synthetic
  history; live mode uses Kite historical data.

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
