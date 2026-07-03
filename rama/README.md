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

## Tests

```bash
pytest tests/test_rama.py     # Kelly math, catalyst signal, audit gate, e2e run
```

*Not investment advice. Paper simulation only.*
