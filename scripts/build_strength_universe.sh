#!/usr/bin/env bash
#
# ONE-TIME: build the STRENGTH book's universe — the top ~1500 liquid NSE names
# (ranked by market cap) — from an already-fetched whole-market CSV.
#
#   1. extract the unique symbols from allstocks_daily.csv
#   2. fetch market caps (Yahoo, best-effort)
#   3. strength_list.csv  = the top N by market cap  (default 1500)
#   4. strength_daily.csv = those names' daily bars  (subset — no re-fetch)
#
# Run once on the droplet AFTER fetching the whole market:
#   python3 -m garuda.fetch_daily --exchange NSE --all --out allstocks_daily.csv --fresh --workers 5
#   bash scripts/build_strength_universe.sh          # or: ... build_strength_universe.sh 1500
# Then restart the server. The daily cron (run_garuda.sh) refreshes the bars from
# strength_list.csv each morning; re-run this script when you want to re-rank.
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; . /home/globalbot/.env 2>/dev/null || true; set +a
TOP="${1:-1500}"
SRC="${2:-allstocks_daily.csv}"

[ -f "$SRC" ] || { echo "missing $SRC — run fetch_daily --exchange NSE --all first"; exit 1; }

echo "1/4  extracting symbols from $SRC ..."
python3 - "$SRC" <<'PY'
import csv, sys
syms = sorted({r["symbol"] for r in csv.DictReader(open(sys.argv[1]))})
with open("allstocks_syms.csv", "w") as f:
    f.write("Symbol\n" + "\n".join(syms))
print(f"     {len(syms)} unique symbols")
PY

echo "2/4  fetching market caps (Yahoo, best-effort) ..."
python3 -m garuda.fetch_marketcap --symbols-file allstocks_syms.csv --out allstocks_mcap.csv || \
  echo "     [warn] mcap fetch incomplete — ranking on what we got"

echo "3/4  building strength_list.csv (top $TOP by market cap) ..."
python3 - "$TOP" <<'PY'
import csv, sys
top_n = int(sys.argv[1])
rows = [r for r in csv.DictReader(open("allstocks_mcap.csv")) if r.get("marketcap")]
rows.sort(key=lambda r: float(r["marketcap"]), reverse=True)
top = rows[:top_n]
with open("strength_list.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(["Symbol"])
    for r in top:
        w.writerow([r["symbol"]])
if top:
    print(f"     top {len(top)}: {top[0]['symbol']} {top[0]['marketcap']}cr "
          f"... {top[-1]['symbol']} {top[-1]['marketcap']}cr")
PY

echo "4/4  subsetting $SRC -> strength_daily.csv ..."
python3 - "$SRC" <<'PY'
import csv, sys
keep = {r["Symbol"] for r in csv.DictReader(open("strength_list.csv"))}
n = 0
with open(sys.argv[1]) as fi, open("strength_daily.csv", "w", newline="") as fo:
    r = csv.reader(fi); w = csv.writer(fo); w.writerow(next(r))
    for row in r:
        if row and row[0] in keep:
            w.writerow(row); n += 1
print(f"     wrote strength_daily.csv: {n} rows")
PY

echo "done — restart the server to load the STRENGTH book."
