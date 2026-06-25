# How to start the Kite bridge again (droplet quick-start)

You already did the full setup once. To get the **Claude Code ⇄ Kite** bridge
running again after a reboot, a new SSH session, or just coming back later —
follow these four lines. (Setup details live in [MCP_BRIDGE.md](MCP_BRIDGE.md).)

```bash
cd /root/sectorbot                       # the repo
source .venv/bin/activate                # turn the venv back on  -> prompt shows (.venv)
set -a; source /root/sectorbot/.env; set +a   # load Kite + Telegram keys
claude                                    # launch Claude Code with the bridge
```

Then inside Claude Code:

1. Type `/mcp` → confirm **`claude-code-kite`** shows **✓ connected · 8 tools**.
2. Press **Esc**, then just talk:
   - `What's the LTP of RELIANCE?`
   - `Rank the top 8 industries and show their symbols.`
   - `Run a paper session and send me a Telegram summary.`

To leave: type `/exit`.

---

## If something looks wrong

| Symptom | Fix |
|---------|-----|
| `claude: command not found` | `export PATH="$HOME/.local/bin:$PATH"` (it's in `~/.bashrc`; open a fresh shell) |
| `/mcp` shows **failed** | You launched `claude` without sourcing `.env`. Quit, run the 4 lines above in order, relaunch. |
| Prices say `synthetic_demo` | Same cause — the `.env` wasn't loaded, so there's no Kite key. Re-source `.env`. |
| `token-check` not REAL | The daily Kite token may have expired. Your main bot's TOTP login refreshes `/home/globalbot/data/kite_token.json` each morning; re-run it, then retry. |
| Telegram silent | `python -m sectorbot.telegram` to test; it prints the reason if it can't send. |

## Keys — where they live (never commit these)

- **Kite access token** (daily, auto-refreshed): `/home/globalbot/data/kite_token.json`
- **`KITE_API_KEY`**: copied into `/root/sectorbot/.env` (gitignored, `chmod 600`)
- **`TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`**: in `/root/sectorbot/.env`
- The permanent account secrets (`KITE_API_SECRET`, `KITE_TOTP_SECRET`,
  `ZERODHA_PASSWORD`) stay **only** in `/home/globalbot/.env` — the bridge never
  needs them.

## Daily auto-run (optional)

To get the paper-portfolio summary on Telegram every weekday without logging in:

```bash
crontab -e
# market close ~3:45pm IST = 10:15 UTC:
15 10 * * 1-5 cd /root/sectorbot && set -a && . /root/sectorbot/.env && set +a && /root/sectorbot/.venv/bin/python -m sectorbot trade >> /root/sectorbot/cron.log 2>&1
```

Everything here is **paper + read-only** — the bridge cannot place a real order.
