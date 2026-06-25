# Claude Code ⇄ Zerodha Kite — local MCP bridge

This is the Kite version of the viral *"Claude can now control TradingView &
run backtesting through a local MCP bridge"* idea. Instead of TradingView, it
bridges Claude Code to **your own SectorBot engine, which already speaks to
Zerodha Kite**. You chat; Claude calls the tools; the engine fetches quotes,
ranks industries, backtests, and runs the paper portfolio for you.

It is **read + paper only by design** — there is deliberately *no* live-order
tool (see [Safety](#safety)).

---

## How it works (the concept)

```
  You ───▶ Claude Code ───▶ MCP (stdio) ───▶ kite_mcp_server.py ───▶ SectorBot ──▶ Kite API
   "rank top 10 industries"        tool call         get_datasource()/screener      live LTP
```

**MCP (Model Context Protocol)** is Anthropic's open standard for connecting
Claude to external tools. An MCP *server* advertises a list of tools; Claude
Code is the *client*. When you ask a question, Claude picks a tool, calls it
locally over stdio, and uses the JSON it returns. Nothing about your Kite keys
leaves your machine — the server runs locally and reads keys from your `.env`.

`kite_mcp_server.py` is that server. It reuses the existing
`sectorbot.datasource.get_datasource()`, so:

- **With Kite keys set** → real LTP / historical data.
- **Without keys** → clearly-flagged synthetic prices, so everything still
  works offline for testing.

## Tools exposed

| Tool | What it does |
|------|--------------|
| `kite_status` | Is the bridge on real Kite data or synthetic? What's configured? **Start here.** |
| `get_quote(symbol)` | Last traded price for an NSE symbol (e.g. `RELIANCE`). |
| `get_history(symbol, bars=60)` | Recent daily OHLC bars + ATR (volatility). |
| `rank_industries(top=10)` | Top-ranked industries + representative symbols. |
| `run_backtest()` | Walk-forward backtest over `sectorbot/data/snapshots/`. |
| `portfolio_status()` | Current paper portfolio: holdings, cash, P&L. |
| `run_paper_session()` | Run one paper session (apply exits, buy top picks). **Paper only.** |
| `send_telegram_alert(message)` | Push a message to your Telegram chat. |

## Setup

```bash
# 1. Install deps (adds the 'mcp' package; kiteconnect is already listed)
pip install -r requirements.txt

# 2. Configure secrets locally (NEVER commit the real .env)
cp .env.example .env
#   edit .env -> KITE_API_KEY + KITE_TOKEN_FILE (or KITE_ACCESS_TOKEN)
#                TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID  (optional)

# 3. Smoke-test the server on its own (Ctrl-C to stop)
python3 kite_mcp_server.py
```

### Register it with Claude Code

This repo ships a project-scoped [`.mcp.json`](.mcp.json), so if you run
`claude` **from this folder** the `claude-code-kite` server is offered
automatically — approve it once. Otherwise add it explicitly:

```bash
claude mcp add claude-code-kite -- python3 kite_mcp_server.py
```

Verify inside Claude Code with `/mcp` — you should see `claude-code-kite`
connected with its 8 tools.

> Load secrets into the shell before launching Claude Code (e.g.
> `set -a; source .env; set +a`) so the server inherits your Kite/Telegram env.

## Using it

Just talk to Claude Code in plain English:

- *"Use kite_status — am I on real data?"*
- *"What's the LTP of INFY and TCS?"*
- *"Rank the top 8 industries and show their symbols."*
- *"Run the backtest and tell me the edge vs benchmark."*
- *"Run a paper session, then Telegram me a one-line summary."*

## Telegram alerts

Telegram is wired into the normal bot flow too, not just the bridge. Any
`send_portfolio()` run (e.g. `python -m sectorbot trade`) now also pushes a
short summary to Telegram — handy because the Bot API is plain HTTPS and works
on hosts that block outbound SMTP (DigitalOcean blocks 25/465/587 by default).

Test it directly:

```bash
python -m sectorbot.telegram     # sends a test message (or dry-runs to console)
```

## Safety

- **No live orders.** This bridge exposes only data, backtest, paper-trading
  and alert tools. `LIVE_TRADING` stays `False`; there is no tool that calls
  `kite.place_order`. Placing real money trades from an LLM chat is out of
  scope for this basic bridge — add it yourself, behind your own explicit
  confirmations, only once you fully trust the setup.
- **Secrets stay local.** Keys are read from your gitignored `.env`. Never
  commit real tokens; `.env.example` holds placeholders only.
- **Synthetic fallback is labelled.** If Kite is unavailable, every tool tells
  you the prices are `synthetic_demo`, so you never mistake them for real data.
