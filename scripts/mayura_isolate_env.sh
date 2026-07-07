#!/usr/bin/env bash
#
# Mayura 🦚 — one-command Telegram ISOLATION. NO nano, no copying, no pasting.
# Just run:   bash /root/sectorbot/scripts/mayura_isolate_env.sh
#
# WHAT IT DOES (and why):
#   Mayura must NEVER share a Telegram bot/group with your main equity bot. The
#   new code reads Mayura's OWN vars first — MAYURA_BOT_TOKEN / MAYURA_CHAT_ID /
#   MAYURA_TOPIC_<FACE> — and only falls back to the generic TELEGRAM_* ones.
#   This script simply COPIES your existing, already-working Telegram settings
#   out of Mayura's .env into those MAYURA_* names, so the isolation is real and
#   the two bots can never collide again. It touches ONLY Mayura's repo .env,
#   never the shared /home/globalbot/.env, and never your token values.
#
# Safe to re-run: it replaces the MAYURA_* lines in place (idempotent) and keeps
# every other line untouched. If MAYURA_* are already set, those are preserved.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ENV="$REPO/.env"

if [ ! -f "$ENV" ]; then
  echo "❌ No .env found at $ENV"
  echo "   Run  python mayura.py telegram-setup  first (it writes the ids), then"
  echo "   re-run this script. Until then Mayura uses the generic TELEGRAM_* vars."
  exit 1
fi

# Read ONLY Mayura's repo .env (never the shared bot .env) so we copy Mayura's
# own bot/group — not the main bot's. Sourcing in a subshell-safe way.
set -a
# shellcheck disable=SC1090
. "$ENV"
set +a

# Replace (or append) one KEY=VALUE line, leaving every other line untouched.
upsert() {
  local key="$1" val="$2" tmp
  [ -z "${val:-}" ] && return 0          # nothing to copy for this one — skip
  tmp="$(mktemp)"
  # drop any existing line for this key (with or without a leading 'export ')
  grep -vE "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV" > "$tmp" || true
  printf '%s=%s\n' "$key" "$val" >> "$tmp"
  cat "$tmp" > "$ENV"
  rm -f "$tmp"
}

mask() {  # show only the last 4 chars of a secret
  local v="$1"
  if [ -z "$v" ]; then echo "(empty)"; elif [ "${#v}" -le 4 ]; then echo "****";
  else echo "…${v: -4}"; fi
}

# Prefer an already-set MAYURA_* value; else copy from the matching TELEGRAM_* one.
upsert MAYURA_BOT_TOKEN "${MAYURA_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
upsert MAYURA_CHAT_ID   "${MAYURA_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
for F in DANDAPANI SENTHIL SUBRAMANYA SWAMINATHA THANIKESA SOLAIMALAI; do
  dst="MAYURA_TOPIC_$F"; src="TELEGRAM_TOPIC_$F"
  upsert "$dst" "${!dst:-${!src:-}}"
done

echo "✅ Mayura Telegram isolation done (no nano used). Written into $ENV:"
echo "     MAYURA_BOT_TOKEN = $(mask "${MAYURA_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}")"
echo "     MAYURA_CHAT_ID   = ${MAYURA_CHAT_ID:-${TELEGRAM_CHAT_ID:-(empty)}}"
for F in DANDAPANI SENTHIL SUBRAMANYA SWAMINATHA THANIKESA SOLAIMALAI; do
  dst="MAYURA_TOPIC_$F"; src="TELEGRAM_TOPIC_$F"
  v="${!dst:-${!src:-}}"
  [ -n "$v" ] && echo "     MAYURA_TOPIC_$F = $v"
done
echo
echo "🦚 Mayura now uses its OWN vars — it can never post to the main bot's group."
echo "   Verify any time with:  python mayura.py check"
