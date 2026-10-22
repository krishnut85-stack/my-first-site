#!/usr/bin/env bash
#
# Copy the live intraday desk (/home/globalbot/intraday) into this repo under
# intraday/ and push it, so a Claude Code cloud session can read the real code
# and test results. Run it ON THE DROPLET from inside the repo clone:
#
#   cd /root/sectorbot && git fetch origin ccr-0769adba-ubk6t5 \
#     && git checkout ccr-0769adba-ubk6t5 && bash scripts/push_intraday_source.sh
#
# What is copied:   *.py, *.html, *.md, config.json, universe.json, the test
#                   result .txt files and reviews.txt, plus trades.db exported
#                   to CSV (paper trades only).
# What is NEVER copied: .env files, tokens, *.bak* backups, data/ (5-min
#                   history), the raw .db, logs. A secret scan runs before the
#                   commit and aborts if anything key-like is found.
set -euo pipefail

SRC="${INTRADAY_SRC:-/home/globalbot/intraday}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/intraday"
BRANCH="${PUSH_BRANCH:-ccr-0769adba-ubk6t5}"

[ -d "$SRC" ] || { echo "No folder at $SRC"; exit 1; }
cd "$REPO"

rm -rf "$DEST"
mkdir -p "$DEST"

# 1. Copy only allowed file types, top level and sub-folders, skipping data/.
( cd "$SRC" && find . \
    -path ./data -prune -o -path '*/__pycache__' -prune -o -path './.*' -prune -o -path '*/.*' -prune -o \
    -type f \( -name '*.py' -o -name '*.html' -o -name '*.md' \
               -o -name 'config.json' -o -name 'universe.json' -o -name '*.txt' \) \
    ! -name '*.bak*' ! -name '*token*' ! -name '*secret*' ! -name '*.log' \
    -print0 ) | while IFS= read -r -d '' f; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$SRC/$f" "$DEST/$f"
done

# 2. Paper trade log: export every table of trades.db to CSV.
if [ -f "$SRC/trades.db" ]; then
  mkdir -p "$DEST/trades_export"
  python3 - "$SRC/trades.db" "$DEST/trades_export" <<'PY'
import csv, sqlite3, sys
db, out = sys.argv[1], sys.argv[2]
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
tables = [r[0] for r in con.execute("select name from sqlite_master where type='table'")]
for t in tables:
    cur = con.execute(f'select * from "{t}"')
    with open(f"{out}/{t}.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow([d[0] for d in cur.description])
        w.writerows(cur)
    print(f"exported table {t}")
PY
fi

# 3. Folder listing (names and sizes only) so the cloud session sees the layout.
( cd "$SRC" && find . -path ./data -prune -o -type f -printf '%s\t%p\n' | sort -k2 ) \
  > "$DEST/FILE_LIST.txt"
du -sh "$SRC/data" 2>/dev/null | sed 's/^/data folder size: /' >> "$DEST/FILE_LIST.txt" || true

# 4. Secret scan. Abort before committing if anything looks like a key.
PATTERN='([0-9]{8,10}:[A-Za-z0-9_-]{35})|((api_?key|api_?secret|access_?token|totp|password|passwd|bot_?token)["'"'"' ]*[:=][ ]*["'"'"'][A-Za-z0-9_\-]{12,})|(sk-[A-Za-z0-9]{20,})|(AIza[0-9A-Za-z_-]{35})'
if grep -rInE -i "$PATTERN" "$DEST" >/tmp/intraday_secret_hits.txt 2>/dev/null; then
  echo "STOP: possible secrets found. Nothing was committed."
  echo "Files and line numbers (values hidden, safe to share):"
  sed "s#^$DEST/##" /tmp/intraday_secret_hits.txt | cut -d: -f1,2
  echo "Remove them from the source (move to .env), then run this again."
  rm -f /tmp/intraday_secret_hits.txt
  rm -rf "$DEST"
  exit 2
fi

# 5. Commit and push.
git add intraday
if git diff --cached --quiet; then
  echo "intraday copy unchanged, nothing to push"
  exit 0
fi
git commit -m "Intraday desk source snapshot $(date -u '+%Y-%m-%d %H:%M UTC')"
git pull --rebase --autostash origin "$BRANCH" || true
git push -u origin "HEAD:$BRANCH" || { sleep 5; git push -u origin "HEAD:$BRANCH"; }
echo "Done. Pushed intraday/ to branch $BRANCH."
