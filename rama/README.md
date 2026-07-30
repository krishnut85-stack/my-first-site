# Rama — Indian-equity paper-trading bot 🇮🇳

**Rama** is a standalone paper-trading engine for Indian equities on Zerodha
Kite. It is a **separate bot** from `sectorbot` — its own package, its own data,
its own portfolio and reports. Running Rama never touches sectorbot's track
record.

Rama is the honest, legal, India-adapted version of the viral "AI Claude quant"
dashboard. It keeps the proven momentum + breadth + regime + risk engine and
adds **three new pillars**:

| Pillar | Module | What it does |
|--------|--------|--------------|
| **Fractional Kelly sizing** | `sizing.py` | Sizes each position by the Kelly criterion computed from Rama's **own** measured win-rate & reward/risk. Half-Kelly, hard-capped, and **falls back to a flat cap until 20 closed trades exist** — so it only sizes up after proving an edge. |
| **Pre-trade audit gate** | `audit.py` | Before any entry, a rule auditor can **veto** the trade (bad regime, overheated PE, no price, or insiders net selling). An optional hook lets **Claude** act as a second auditor via the MCP bridge. |
| **Insider / catalyst signal** | `catalysts.py` | India's legal equivalent of "checking Form 4 filings": SEBI insider (PIT/SAST) disclosures + NSE/BSE bulk & block deals. Buys tilt a name up, sells tilt it down — feeding both the ranking and the audit gate. |

Everything is **paper-only** — Rama cannot place a real order (`LIVE_TRADING`
is off and there is no order-placement path). The plan is: **prove it on paper,
let the honest scorecard decide (does it beat a Nifty index fund after costs?),
and only then consider going live.**

## Run it

```bash
python -m rama rank        # ranked industries (now catalyst-tilted)
python -m rama sim         # quick synthetic simulation
python -m rama trade       # persistent paper portfolio (real Kite prices if keys set)
python -m rama scorecard   # honest verdict: working? beating the index?
python -m rama status      # saved equity curve, trades, holdings
```

With Kite keys set (see `../.env.example`), `trade` runs against **real market
prices** but still places **no real orders**.

## Feed Rama the insider/catalyst data

Drop a CSV at `rama/data/catalysts.csv` (same workflow as the daily sector CSV).
See `rama/data/catalysts.sample.csv` for the format:

```csv
Symbol,Signal,Party,Date,Value
KEI,BUY,Promoter,2026-07-01,12500000
SUZLON,SELL,Promoter,2026-06-28,
```

`BUY / ACQUIRE` push a name up; `SELL / DISPOSE` push it down. Without this file
the catalyst pillar is a no-op — the rest of Rama runs unchanged.

## Config

All knobs live in `rama/config.py`. Rama defaults `SIZING_MODE = "kelly"`
(sectorbot stays on flat sizing). Toggle any pillar with `USE_AUDIT_GATE`,
`USE_CATALYST_SIGNAL`, or `SIZING_MODE = "fixed"`.

## Parliament — a separate, advisory AI audit panel (optional)

`rama/parliament/` is a **fully isolated** subpackage (`analyst → panel →
executor`) that plugs into Rama's `external_auditor` hook **only** when
`USE_PARLIAMENT_AUDIT = True`. Nothing in Rama's core imports it otherwise.

- **Advisory-only:** it can VETO a weak candidate; it never forces a buy.
- **Fallback chain:** with `PARLIAMENT_PROVIDER = "gemini"` or `"claude"` it asks
  an LLM for a JSON verdict; if the provider errors, times out, or has no key,
  it silently drops to the deterministic **rules** lenses. So it always decides,
  even offline. Keys (`GEMINI_API_KEY` / `ANTHROPIC_API_KEY`) are read from the
  environment at runtime and never committed.
- **Auditable:** every deliberation is logged to `data/parliament_log.jsonl`.

Enable it: set `USE_PARLIAMENT_AUDIT = True` (and optionally a provider + key).
It then runs as a second opinion after the built-in rule auditor — both must
pass for Rama to size a trade.

## Live dashboard + daily cron (droplet)

`python -m rama trade` runs the paper session **and regenerates the live
dashboard** (`rama_dashboard.html`) at the end — so a single scheduled run keeps
the wall-board current. Use the ready-made runner and a cron line:

```bash
# once, on your Indian server (SEBI requires Indian hosting):
chmod +x scripts/run_rama.sh
scripts/run_rama.sh                 # paper run on real Kite prices + dashboard

# daily after close (10:15 UTC ≈ 15:45 IST, Mon–Fri):
crontab -e
15 10 * * 1-5 /path/to/my-first-site/scripts/run_rama.sh >> ~/rama.log 2>&1
```

The dashboard auto-refreshes every 30s; point a browser (or a kiosk screen) at
`rama_dashboard.html` and it stays live between runs.

## Going live (only after the scorecard earns it)

Rama already contains the SEBI-compliant execution path (`live_broker.py`):
orders are rate-limited **under 10 OPS**, guarded by a **kill switch**
(`touch rama/KILL_SWITCH` to halt everything), and **fully logged**. When
`LIVE_TRADING` is on, the engine routes every entry/exit through it — but it
stays a **logged DRY_RUN** until you deliberately turn off every safety latch:

1. Prove the edge: `python -m rama scorecard` must beat a Nifty index fund after
   costs, over a real track record — not a few days.
2. Broker side (Rama can't do these): a **Kite Connect** subscription, your
   broker's **algo approval / Algo-ID**, and **static-IP whitelisting**.
3. Then, and only then: `export RAMA_ALGO_ID=...`, set `LIVE_TRADING = True`,
   and finally `LIVE_DRY_RUN = False`. Start with tiny size.

**Kill switch:** `touch rama/KILL_SWITCH` stops all order placement instantly;
delete the file to resume.

## Tests

```bash
pytest tests/test_rama.py tests/test_rama_live.py   # sizing, catalysts, audit,
                                                    # rate limit, kill switch, routing
```

*Not investment advice. Paper simulation only.*
