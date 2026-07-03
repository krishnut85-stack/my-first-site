# Daily snapshots for backtesting

Drop one CSV per day here, named by date so they sort chronologically:

```
2026-06-20.csv
2026-06-21.csv
2026-06-22.csv
```

Your Termius workflow each day:

```bash
# 1. upload today's file into the data folder (the live bot auto-uses the newest)
#    e.g. with scp / Working Copy / Termius file transfer ->  sectorbot/data/2026-06-22.csv

# 2. ALSO copy it into snapshots/ to grow your backtest history
cp sectorbot/data/2026-06-22.csv sectorbot/data/snapshots/2026-06-22.csv

# 3. run
python -m sectorbot rank
python -m sectorbot sim
python -m sectorbot backtest      # works once you have 2+ days here
```

The backtest ranks industries on each day and measures the picks' realized
next-day move (from the next snapshot's "Day Change %"), comparing against a
buy-everything benchmark. More days = more meaningful results.
