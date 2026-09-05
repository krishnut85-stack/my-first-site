# GIR runbook — what to check, where to get it, and the exact commands

Everything below is copy-pasteable on the droplet. Set this once per SSH
session so the paths work:

```bash
REPO=~/my-first-site          # wherever you cloned it; adjust if different
LIVE=/home/globalbot          # where GIR actually runs
```

---

## 1. Deploy (first time)

You need the repo on the droplet — there is no clone there yet:

```bash
git clone https://github.com/krishnut85-stack/my-first-site ~/my-first-site
cd ~/my-first-site && git checkout claude/garuda-integration-edja30
bash gir/deploy.sh
```

After that, every future deploy is just:

```bash
cd ~/my-first-site && bash gir/deploy.sh
```

`deploy.sh` is all-or-nothing on purpose. It checks every source file exists
**before** touching `/home/globalbot`, backs up what it replaces, copies, then
proves the result imports and compiles — and if that fails it restores the
backup and stops **without restarting anything**. Services are restarted only
once the new code has been shown to work. It prints a one-line rollback command
at the end.

Look before you leap:

```bash
bash gir/deploy.sh --dry-run
```

If your clone lives somewhere else, or GIR does, override either:

```bash
REPO=/path/to/clone LIVE=/home/globalbot bash gir/deploy.sh
```

---

## 2. Every month — the macro check (about five minutes)

**Where each number comes from** — the command prints this too
(`python3 macro_cycle.py where`):

| What | Where to get it | What to type |
|---|---|---|
| Repo direction | RBI MPC statement — rbi.org.in → Press Releases, or any broker app's rate page | `cut` / `hold` / `hike` (`hold` = holding after cuts) |
| 10-year G-sec, 3-month slope | ccilindia.com, or NSE's 10-year benchmark yield. Today's yield **minus** the yield three months ago | the change in **basis points**, e.g. `-8` |
| Bank credit growth YoY | rbi.org.in → Statistics → Weekly Statistical Supplement, "Scheduled Commercial Banks — Bank Credit" YoY % | `up` / `down` / `flat` (`up` = accelerating vs last month) |

**How to check where things stand:**

```bash
cd $LIVE && python3 macro_cycle.py
```

That prints the three signals, what each one votes for, the phase GIR is
actually trading, and whether the file has gone stale.

Run it from `/home/globalbot`, where the files live:

```bash
cd /home/globalbot && python3 macro_cycle.py
```

`GIR is trading: UNKNOWN` until the first 08:05 check on a trading day —
that is when the bot first writes the phase file. To activate a reading
immediately instead of waiting:

```bash
cd /home/globalbot && python3 macro_cycle.py apply
```

That does exactly what the 08:05 hook does. No restart needed — the running
bot re-reads the file on its next scored symbol.

**How to update it:**

```bash
cd $LIVE && python3 macro_cycle.py set hold -8 up
```

Three values, in the order of the table above. It re-stamps the date and
prints the new reading. **Nothing else to do** — GIR re-reads the file at
08:05 each morning and rotates only if two of the three signals agree. A
phase change is pushed to Telegram; most mornings it will simply log
`holding`, which is the design working.

If you leave it more than 45 days, the signals stop being able to change the
phase and the log says so. GIR keeps trading its last known phase rather than
acting on a stale read.

---

## 3. After every RBI MPC meeting

Same command as above — the repo decision is the one input that moves on the
MPC calendar (every ~2 months). The other two are worth a monthly glance.

---

## 4. After every NSE F&O review — refresh the auction list

The Closing Auction Session applies to stocks with F&O contracts, and that
list changes at each exchange review. Regenerate it from Kite:

```bash
cd $REPO && python3 scripts/refresh_cas_stocks.py --out $LIVE/cas_stocks.txt
```

Needs `KITE_API_KEY` and `KITE_TOKEN_FILE` in the environment. Until you run
it, both bots fall back to `fno_stocks.txt` (a curated ~50 names), which means
the other F&O stocks are treated as if they still close at 15:30 instead of
going into the auction at 15:15. It fails safe — GIR under-trades rather than
filling against auction quotes — but the list should be complete.

---

## 5. Is it actually working?

```bash
# the session clock agrees with the wall clock
cd $LIVE && python3 -c "import market_session as m; print(m.market_status())"

# what the macro layer thinks, in one line
python3 -c "import macro_cycle as c; p=c.load_phase('$LIVE/data/macro_phase.json'); print(c.describe(p))"

# the morning macro read, in the log
journalctl -u globaleye --since today | grep 'MACRO L1'

# seasonal sizing, when it fires (only March, and auto in Oct/Nov)
journalctl -u globaleye --since today | grep 'MACRO L2'

# anything still assuming the old 09:15-15:30 day
cd $REPO && bash scripts/cas_audit.sh $LIVE
```

**Did the running bot actually pick up the deploy?** A copied file does
nothing until the service restarts — so check the process is younger than the
files it loaded:

```bash
systemctl show -p ActiveEnterTimestamp --value globaleye   # when it restarted
stat -c '%y %n' /home/globalbot/gir.py                     # when the file landed
```

The service timestamp must be the later of the two. `deploy.sh` prints both
sides of this itself and shouts if a service did not come back.

**What "healthy" looks like:** `MACRO L1` appears once a morning and usually
says `holding`; `MACRO L2` appears rarely, because eleven months of the year
it multiplies by exactly 1.0; and after 15:35 the session clock reads
`F&O ONLY` rather than `MARKET OPEN`.
