# Deploying the F&O bot on the DigitalOcean server

This reuses your existing server setup: the `.env` credential file, TOTP
auto-login, and Telegram alerts all work with the **same variable names** the
old system used. You operate it from your phone with ConnectBot exactly as
before — the bot runs under systemd, so nothing depends on your SSH session
staying open.

## 0. Retire the old bot first

```bash
systemctl disable --now globaleye
systemctl disable --now raven raven-manage.timer raven-preopen.timer 2>/dev/null
```

Check the Kite positions page and close anything the old bot left open.

## 1. Install the new bot

```bash
cd /home/globalbot
git clone https://github.com/krishnut85-stack/my-first-site.git
cd my-first-site
git checkout claude/nse-fo-algo-trading-jaf5a6
pip3 install -r requirements.txt
python3 -m pytest tests/ -q        # should print: all passed
```

## 2. Credentials — your existing .env works as-is

The bot reads `/home/globalbot/.env` (via systemd `EnvironmentFile`) with the
same names the old system used:

```
KITE_API_KEY=...
KITE_API_SECRET=...
ZERODHA_USER_ID=...
ZERODHA_PASSWORD=...
KITE_TOTP_SECRET=...
TG_BOT_TOKEN=...          # optional, Telegram alerts
TELEGRAM_CHAT_ID=...      # optional
```

Keep it locked down: `chmod 600 /home/globalbot/.env`. The TOTP auto-login
mints and caches the day's access token automatically — no morning ritual.

## 3. Smoke-test by hand (during market hours)

```bash
cd /home/globalbot/my-first-site
set -a; source /home/globalbot/.env; set +a
python3 scripts/run_fno.py --strategy straddle --mode paper --lots 1
```

You should see the Kite login succeed, then entries/exits in the log (and on
Telegram if configured). `Ctrl+C` squares off the paper book and exits.

## 4. Install the systemd units

```bash
cp deploy/fno-bot.service deploy/fno-bot.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now fno-bot.timer
```

The timer starts the bot at 09:05 IST on weekdays; the engine waits for the
09:15 open, trades, squares off by 15:12, and exits after close. Edit
`ExecStart` in the service file to change strategy/lots.

## 5. Operating it from ConnectBot

```bash
journalctl -u fno-bot -f                  # watch it live
journalctl -u fno-bot --since today       # today's full log
systemctl status fno-bot                  # is it running?
systemctl stop fno-bot                    # emergency stop (squares off first)
systemctl start fno-bot                   # manual start (e.g. after a fix)
```

`systemctl stop` sends SIGTERM; the engine's shutdown path squares off all
open positions before exiting, and sends the day's P&L to Telegram.

## 6. Going live — later, not now

Run paper mode for **at least 2–4 weeks**, including one weekly expiry day
and ideally one high-volatility session. Judge it on the Telegram daily P&L
summaries. Only then change the service's `ExecStart`:

```
ExecStart=/usr/bin/python3 scripts/run_fno.py --strategy straddle --mode live \
    --lots 1 --max-daily-loss 5000 --i-understand-the-risks
```

Start with 1 lot regardless of capital. See POSTMORTEM.md for why the
previous bot lost money daily — every safety rail here exists because of a
specific failure in that system.

## Updating the bot

```bash
cd /home/globalbot/my-first-site
git pull
python3 -m pytest tests/ -q && systemctl restart fno-bot
```
