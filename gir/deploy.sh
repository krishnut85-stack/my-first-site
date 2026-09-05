#!/usr/bin/env bash
#
# Deploy GIR from this repo onto the droplet — all of it, or none of it.
#
#   bash deploy.sh              find/clone the repo, deploy, restart
#   bash deploy.sh --dry-run    show what would happen, change nothing
#
# Why a script and not a list of cp commands: a loose `cp` list half-applies
# when one path is wrong, and then restarts the bot on a mixed tree. This
# verifies every source file first, backs up what it replaces, import-checks
# the result, and rolls back automatically if that fails. It restarts the
# services only once the new code has been proven to import.
#
# Overridable:  REPO=/path/to/clone  LIVE=/home/globalbot  BRANCH=...
#               GARUDA=/path/whose/garuda/server.py runs the dashboard
set -euo pipefail

BRANCH="${BRANCH:-claude/garuda-integration-edja30}"
LIVE="${LIVE:-/home/globalbot}"
CLONE_URL="${CLONE_URL:-https://github.com/krishnut85-stack/my-first-site}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then echo "  would: $*"; else "$@"; fi; }

# --- 1. find the repo, or clone it -------------------------------------------
find_repo() {
  local c
  for c in "${REPO:-}" "$HOME/my-first-site" /root/my-first-site \
           /home/globalbot/my-first-site /opt/my-first-site; do
    [ -n "$c" ] && [ -d "$c/.git" ] && [ -d "$c/gir" ] && { echo "$c"; return; }
  done
  return 1
}

if REPO="$(find_repo)"; then
  say "repo: $REPO"
else
  REPO="$HOME/my-first-site"
  say "no clone found — cloning into $REPO"
  run git clone "$CLONE_URL" "$REPO"
  [ "$DRY" = 1 ] && { echo "  (dry run stops here: nothing to deploy from)"; exit 0; }
fi

say "fetching $BRANCH"
run git -C "$REPO" fetch origin "$BRANCH"
run git -C "$REPO" checkout "$BRANCH"
run git -C "$REPO" pull --ff-only origin "$BRANCH"
[ "$DRY" = 0 ] && git -C "$REPO" log --oneline -1

# --- 2. what goes where ------------------------------------------------------
# "<source under $REPO>  <destination dir under $LIVE>"
FILES="
gir/market_session.py            .
gir/macro_cycle.py               .
gir/macro_signals.json           .
gir/gir.py                       .
gir/fno_paper_study.py           .
gir/raven/raven.py               raven
gir/falcon/falcon.py             falcon
gir/hunter/market_calendar.py    hunter
gir/paper/paper_exit_monitor.py  paper
"

say "checking every source file exists before touching anything"
missing=0
while read -r src _dst; do
  [ -z "$src" ] && continue
  if [ -f "$REPO/$src" ]; then echo "  ok      $src"
  else echo "  MISSING $src"; missing=$((missing + 1)); fi
done <<< "$FILES"
[ "$missing" -gt 0 ] && { echo "refusing to deploy: $missing file(s) missing"; exit 1; }

# --- 3. back up, then copy ---------------------------------------------------
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$LIVE/backup_pre_deploy_$STAMP"
say "backing up current files -> $BACKUP"
run mkdir -p "$BACKUP"
while read -r src dst; do
  [ -z "$src" ] && continue
  base="$(basename "$src")"
  live_path="$LIVE/${dst#.}"; live_path="${live_path%/}/$base"
  live_path="$(echo "$live_path" | tr -s /)"
  if [ -f "$live_path" ]; then
    run mkdir -p "$BACKUP/$dst"
    run cp -p "$live_path" "$BACKUP/$dst/$base"
  fi
done <<< "$FILES"

say "copying into $LIVE"
while read -r src dst; do
  [ -z "$src" ] && continue
  target="$(echo "$LIVE/${dst#.}" | tr -s /)"
  run mkdir -p "$target"
  run cp "$REPO/$src" "$target/"
  echo "  $src -> $target"
done <<< "$FILES"

if [ "$DRY" = 1 ]; then say "dry run complete — nothing was changed"; exit 0; fi

# --- 4. prove it works, or put it back ---------------------------------------
say "verifying"
rollback() {
  echo "  VERIFY FAILED — restoring from $BACKUP"
  ( cd "$BACKUP" && find . -type f \( -name '*.py' -o -name '*.json' \) ) | while read -r f; do
    cp "$BACKUP/${f#./}" "$LIVE/${f#./}"
  done
  echo "  restored. The bot's files are as they were; nothing was restarted."
  exit 1
}
( cd "$LIVE" && python3 -c "import market_session, macro_cycle" ) || rollback
echo "  shared modules import"
for f in gir.py fno_paper_study.py raven/raven.py falcon/falcon.py \
         hunter/market_calendar.py paper/paper_exit_monitor.py; do
  python3 -m py_compile "$LIVE/$f" || rollback
  echo "  compiles: $f"
done
( cd "$LIVE" && python3 -c "
import market_session as m, macro_cycle as c
print('  session clock says:', m.market_status())
print('  macro signals  say:', c.advance(c.UNKNOWN, c.read_signals())[0])
" ) || rollback

# --- 5. restart ---------------------------------------------------------------
restarted=""
skipped=""
if command -v systemctl >/dev/null 2>&1; then
  for svc in globaleye raven; do
    # ALWAYS attempt the restart. An earlier version gated this on
    # `systemctl list-unit-files | grep ^$svc.service`, which did not list
    # globaleye — the main bot — so a successful deploy silently left it
    # running the old code. A failed restart is loud; a skipped one is not,
    # and for a trading bot the silent case is the dangerous one.
    state="$(systemctl show -p LoadState --value "$svc" 2>/dev/null || true)"
    say "restarting $svc  (LoadState=${state:-unknown})"
    if sudo systemctl restart "$svc" 2>&1; then
      sleep 3
      if systemctl is-active "$svc"; then
        restarted="$restarted $svc"
      else
        echo "  WARNING: $svc did not come back — journalctl -u $svc -n 50"
        skipped="$skipped $svc"
      fi
    else
      echo "  WARNING: could not restart $svc — systemctl status $svc"
      skipped="$skipped $svc"
    fi
  done
else
  echo "  (no systemctl here — skipping restarts)"
  skipped=" globaleye raven"
fi

# --- 6. Garuda (the dashboard) -----------------------------------------------
# Garuda is a separate install from GIR's flat tree, and its server reads
# dashboard_live.html fresh on every request — so a stale tab means the FILE
# was never updated, not that the browser cached it. Find where it actually
# runs rather than assuming a path.
find_garuda() {
  local pid d c
  if [ -n "${GARUDA:-}" ]; then [ -f "$GARUDA/garuda/server.py" ] && { echo "$GARUDA"; return; }; fi
  for pid in $(pgrep -f "garuda" 2>/dev/null || true); do
    d="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
    [ -n "$d" ] && [ -f "$d/garuda/server.py" ] && { echo "$d"; return; }
  done
  for c in /home/globalbot /root /opt "$HOME"; do
    [ -f "$c/garuda/server.py" ] && { echo "$c"; return; }
  done
  return 1
}

if GARUDA_ROOT="$(find_garuda)"; then
  say "Garuda found at $GARUDA_ROOT — updating its package"
  GBACKUP="$GARUDA_ROOT/garuda_backup_pre_deploy_$STAMP"
  run mkdir -p "$GBACKUP"
  for f in "$REPO"/garuda/*.py "$REPO"/garuda/*.html; do
    base="$(basename "$f")"
    [ -f "$GARUDA_ROOT/garuda/$base" ] && run cp -p "$GARUDA_ROOT/garuda/$base" "$GBACKUP/"
    run cp "$f" "$GARUDA_ROOT/garuda/"
  done
  echo "  copied $(ls -1 "$REPO"/garuda/*.py "$REPO"/garuda/*.html | wc -l) files (data/ untouched)"
  if [ "$DRY" = 0 ]; then
    if ( cd "$GARUDA_ROOT" && python3 -c "
import garuda.macro as m, garuda.market, garuda.live
st = m.state()
print('  garuda imports; macro reads phase =', st['phase'], '/ suggested', st['suggested'])
" ); then
      grep -q "data-f=cycle" "$GARUDA_ROOT/garuda/dashboard_live.html" \
        && echo "  CYCLE tab present in the served HTML" \
        || echo "  WARNING: CYCLE tab missing from the copied HTML"
    else
      echo "  VERIFY FAILED — restoring Garuda from $GBACKUP"
      cp "$GBACKUP"/* "$GARUDA_ROOT/garuda/" 2>/dev/null || true
      echo "  restored; Garuda not restarted."
      exit 1
    fi
  fi
  gsvc="$(systemctl list-units --type=service --all 2>/dev/null \
          | grep -oE '^[^ ]*garuda[^ ]*\.service' | head -1 || true)"
  if [ -n "$gsvc" ]; then
    say "restarting $gsvc"
    sudo systemctl restart "$gsvc" && sleep 3 && systemctl is-active "$gsvc" \
      && restarted="$restarted ${gsvc%.service}"
  else
    echo "  No garuda systemd unit found. Restart it however you run it —"
    echo "  the dashboard needs a restart for /data to include the macro block"
    echo "  (the HTML itself is re-read per request)."
    skipped="$skipped garuda"
  fi
else
  echo
  echo "  Garuda install not found. If the CYCLE tab is missing, set GARUDA to"
  echo "  the directory that CONTAINS garuda/server.py and re-run:"
  echo "    GARUDA=/path/to/app bash gir/deploy.sh"
fi

say "done"
echo "restarted:${restarted:- none}"
for svc in $restarted; do
  echo "  $svc up since $(systemctl show -p ActiveEnterTimestamp --value "$svc" 2>/dev/null)"
done
[ -n "$skipped" ] && echo "NOT RUNNING NEW CODE:${skipped} — these still hold the old code in memory"
echo "rollback:  cp -r $BACKUP/. $LIVE/ && sudo systemctl restart globaleye"
