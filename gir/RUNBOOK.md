# GIR runbook — what to check, where to get it, and the exact commands

Everything below is copy-pasteable on the droplet. Set this once per SSH
session so the paths work:

```bash
REPO=~/my-first-site          # wherever you cloned it; adjust if different
LIVE=/home/globalbot          # where GIR actually runs
```

---

## 1. Deploy the current branch (do this once)

```bash
cd $REPO
git fetch origin
git checkout claude/garuda-integration-edja30
git pull

# the two shared modules must sit beside gir.py, or it will not start
cp gir/market_session.py  $LIVE/
cp gir/macro_cycle.py     $LIVE/
cp gir/macro_signals.json $LIVE/

# the strategy files that changed
cp gir/gir.py                    $LIVE/
cp gir/fno_paper_study.py        $LIVE/
cp gir/raven/raven.py            $LIVE/raven/
cp gir/falcon/falcon.py          $LIVE/falcon/
cp gir/hunter/market_calendar.py $LIVE/hunter/
cp gir/paper/paper_exit_monitor.py $LIVE/paper/

# check it imports before restarting anything
cd $LIVE && python3 -c "import market_session, macro_cycle; print('imports OK')"
python3 -m py_compile gir.py && echo "gir.py compiles"

sudo systemctl restart globaleye && sleep 3 && systemctl is-active globaleye
sudo systemctl restart raven     && sleep 3 && systemctl is-active raven
```

Rollback is `git checkout main` on the repo, re-copy, restart.

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

**What "healthy" looks like:** `MACRO L1` appears once a morning and usually
says `holding`; `MACRO L2` appears rarely, because eleven months of the year
it multiplies by exactly 1.0; and after 15:35 the session clock reads
`F&O ONLY` rather than `MARKET OPEN`.
