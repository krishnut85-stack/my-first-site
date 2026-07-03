# Rama — broker setup & operating constraints (read before any live work)

This is the standing brief for Rama's broker side. It exists so every session
works from the same picture and **nobody re-does things that already exist** or
makes the two silent-failure mistakes noted below. **No secrets live in this
file** — only facts, paths and constraints. Secrets are read at runtime.

## Already in place — DO NOT re-do

- **Kite Connect API is active and paid** (₹500/month) on this Zerodha account.
- **Static IP `64.227.155.177`** (the DigitalOcean droplet where the bot runs)
  is **already registered** on the Zerodha developer IP whitelist. SEBI's
  Apr-2026 static-IP requirement is **satisfied**. A **second IP slot** is
  available on the dashboard if ever needed (Zerodha allows 2).
- **Historical Data API** and **WebSocket** (3,000 instruments) are included.
- Credentials live in **`/home/globalbot/.env`**: `KITE_API_KEY`,
  `KITE_API_SECRET`, `KITE_TOTP_SECRET`, `ZERODHA_USER_ID`, `ZERODHA_PASSWORD`.
  **Never copy these into the repo or commit them** — read at runtime via
  `source /home/globalbot/.env` (the `scripts/run_rama.sh` runner already does).
- The **daily access token** is at **`/home/globalbot/data/kite_token.json`**,
  refreshed each morning (~08:30 IST) by the main bot via automatic TOTP login.
  **Prefer reading this file** (`KITE_TOKEN_FILE`) over doing a fresh login.

## Hard constraints (two silent-failure traps)

1. **Live orders must run from the droplet `64.227.155.177`.** It is the only
   whitelisted IP; an order from any other host (GitHub Actions, a laptop,
   another server) is **silently rejected by Zerodha**. → Live execution
   **cannot** run on GitHub. Rama now enforces this in code: `live_broker.py`
   checks its public IP before any real send and refuses a non-whitelisted host
   (`config.LIVE_ENFORCE_IP`, `LIVE_ALLOWED_IPS`).
2. **Never commit the credentials** in `/home/globalbot/.env`. They are read at
   runtime only.

## Current status: PAPER ONLY — do not enable live without explicit instruction

All strategies are in **paper mode**. **Do not enable live/real orders** without
an explicit, deliberate instruction. The default state is safe by construction:
`LIVE_TRADING = False`, and even when on, `LIVE_DRY_RUN = True` and a missing
`RAMA_ALGO_ID` both keep it a logged dry-run.

### Current P&L reality (the honest picture)

**The broker being ready is NOT the same as the strategy being ready.** As of
now the strategies have **not proven a positive edge on paper** — measured
results are paper-negative / unproven. The single source of truth is:

```bash
python -m rama scorecard      # is it positive AND beating a Nifty index fund?
```

Until that verdict is **PROMISING** (net positive, index-beating, after costs)
over a multi-week track record — not a few days — Rama stays on paper. Let the
clean paper data accumulate, watch whether the strategies turn genuinely green,
and only then consider live. **The infrastructure will still be there when the
edge is proven; there is no cost to waiting and real cost to rushing.**

## The go-live sequence (only after the scorecard earns it)

1. `python -m rama scorecard` shows a positive, index-beating edge over weeks.
2. On the droplet: `export RAMA_ALGO_ID=<your broker algo id>`.
3. Set `LIVE_TRADING = True` (routing on, still dry-run).
4. Finally `LIVE_DRY_RUN = False` — real orders begin. Start with tiny size.
5. Kill switch any time: `touch rama/KILL_SWITCH` (delete the file to resume).
